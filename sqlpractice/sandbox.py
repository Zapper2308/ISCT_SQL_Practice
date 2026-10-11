"""Runs student SQL against the practice Postgres database safely, and grades it.

Every run happens inside ONE transaction that is always rolled back, so
INSERT/UPDATE/DDL practice never changes the shared database:

  * BEGIN / START TRANSACTION / COMMIT / END are ignored (we already own the transaction).
  * ROLLBACK / ABORT are emulated by rolling back to a savepoint taken at the start.
  * Statements that could escape the sandbox or its timeout are refused.
  * statement_timeout + lock_timeout are set per run, with a client-side cancel as backstop.
"""
import datetime
import decimal
import json
import re
import threading
import time
import uuid
from collections import Counter

import psycopg
from psycopg_pool import ConnectionPool

SANDBOX_SAVEPOINT = "__sandbox_start"

_DOLLAR_RE = re.compile(r"\$([A-Za-z_][A-Za-z0-9_]*)?\$")
_LEADING_JUNK_RE = re.compile(r"^(?:\s+|--[^\n]*(?:\n|$)|/\*.*?\*/|\()*", re.S)
_BLOCKED_SET_RE = re.compile(
    r"^(SET|RESET)\s+(?:(?:SESSION|LOCAL)\s+)?"
    r"(statement_timeout|lock_timeout|idle_in_transaction_session_timeout|transaction_timeout"
    r"|role|session\s+authorization|all)\b",
    re.I,
)
_BLOCKED_FUNC_RE = re.compile(
    r"set_config\s*\(\s*'(statement_timeout|lock_timeout|role|session_authorization"
    r"|idle_in_transaction_session_timeout|transaction_timeout)'",
    re.I,
)
_ROW_RETURNING_FIRST_WORDS = {"SELECT", "WITH", "VALUES", "TABLE"}


class QueryRejected(Exception):
    pass


# --------------------------------------------------------------------------- parsing

def split_statements(sql):
    """Splits SQL on top-level semicolons, respecting quotes, comments and $$ bodies."""
    stmts, start, i, n = [], 0, 0, len(sql)
    while i < n:
        c = sql[i]
        if c == "-" and sql.startswith("--", i):
            j = sql.find("\n", i)
            i = n if j == -1 else j + 1
            continue
        if c == "/" and sql.startswith("/*", i):
            depth, i = 1, i + 2
            while i < n and depth:
                if sql.startswith("/*", i):
                    depth, i = depth + 1, i + 2
                elif sql.startswith("*/", i):
                    depth, i = depth - 1, i + 2
                else:
                    i += 1
            continue
        if c == "'":
            backslash_escapes = i > 0 and sql[i - 1] in "eE" and (i < 2 or not (sql[i - 2].isalnum() or sql[i - 2] == "_"))
            i += 1
            while i < n:
                if backslash_escapes and sql[i] == "\\":
                    i += 2
                    continue
                if sql[i] == "'":
                    if i + 1 < n and sql[i + 1] == "'":
                        i += 2
                        continue
                    i += 1
                    break
                i += 1
            continue
        if c == '"':
            j = i + 1
            while j < n:
                if sql[j] == '"':
                    if j + 1 < n and sql[j + 1] == '"':
                        j += 2
                        continue
                    break
                j += 1
            i = j + 1
            continue
        if c == "$" and not (i > 0 and (sql[i - 1].isalnum() or sql[i - 1] == "_")):
            m = _DOLLAR_RE.match(sql, i)
            if m:
                j = sql.find(m.group(0), m.end())
                i = n if j == -1 else j + len(m.group(0))
                continue
        if c == ";":
            stmts.append(sql[start:i])
            start = i + 1
        i += 1
    stmts.append(sql[start:])
    return [s.strip() for s in stmts if _strip_leading(s)]


def _strip_leading(stmt):
    return _LEADING_JUNK_RE.sub("", stmt, count=1).strip()


def _words(stmt, k=3):
    return [w.upper() for w in re.findall(r"[A-Za-z_]+", _strip_leading(stmt))[:k]]


def classify(stmt):
    """Returns 'skip', 'rollback', 'run' or raises QueryRejected."""
    words = _words(stmt)
    first = words[0] if words else ""
    second = words[1] if len(words) > 1 else ""
    body = _strip_leading(stmt)

    if first in ("BEGIN", "START", "COMMIT", "END"):
        if first == "COMMIT" and second == "PREPARED":
            raise QueryRejected("COMMIT PREPARED is not allowed in the practice sandbox.")
        return "skip"
    if first in ("ROLLBACK", "ABORT"):
        if second == "PREPARED":
            raise QueryRejected("ROLLBACK PREPARED is not allowed in the practice sandbox.")
        return "run" if second == "TO" else "rollback"
    if first == "PREPARE" and second == "TRANSACTION":
        raise QueryRejected("PREPARE TRANSACTION is not allowed in the practice sandbox.")
    if _BLOCKED_SET_RE.match(body):
        raise QueryRejected("Changing timeouts, roles or resetting the session is not allowed in the practice sandbox.")
    if _BLOCKED_FUNC_RE.search(stmt):
        raise QueryRejected("set_config() on timeouts/roles is not allowed in the practice sandbox.")
    return "run"


# --------------------------------------------------------------------------- values

def display_value(v):
    if v is None or isinstance(v, (bool, int, float, str)):
        return v
    if isinstance(v, decimal.Decimal):
        return str(v)
    if isinstance(v, (datetime.datetime, datetime.date, datetime.time)):
        return v.isoformat(sep=" ") if isinstance(v, datetime.datetime) else v.isoformat()
    if isinstance(v, (dict, list)):
        return json.dumps(v, default=str)
    if isinstance(v, (bytes, memoryview)):
        return "\\x" + bytes(v).hex()
    return str(v)


def _grade_value(v):
    """Normalises a value so equivalent results compare equal (e.g. 1.50 vs 1.5)."""
    if v is None:
        return None
    if isinstance(v, bool):
        return v
    if isinstance(v, (int, float, decimal.Decimal)):
        try:
            return round(float(v), 4) + 0.0
        except (OverflowError, ValueError):
            return str(v)
    if isinstance(v, datetime.datetime):
        return v.isoformat()
    if isinstance(v, (dict, list)):
        return json.dumps(v, sort_keys=True, default=str)
    return str(v)


# --------------------------------------------------------------------------- sandbox

class Sandbox:
    def __init__(self, dsn, timeout_s=15, max_display_rows=500, grade_row_limit=5000, pool_max=10):
        self.dsn = dsn
        self.timeout_s = timeout_s
        self.max_display_rows = max_display_rows
        self.grade_row_limit = grade_row_limit
        self.pool_max = pool_max
        self._pool = None
        self._pool_lock = threading.Lock()
        self._expected_cache = {}
        self._schema_cache = (0, None)

    @property
    def configured(self):
        return bool(self.dsn) and "YOUR-" not in self.dsn

    def _get_pool(self):
        with self._pool_lock:
            if self._pool is None:
                self._pool = ConnectionPool(
                    self.dsn, min_size=1, max_size=self.pool_max, open=True,
                    kwargs={"autocommit": False, "prepare_threshold": None,
                            "application_name": "sql-practice-sandbox"},
                    reset=self._reset_connection, timeout=30,
                )
            return self._pool

    @staticmethod
    def _reset_connection(conn):
        # Clears session state that survives ROLLBACK (prepared statements, advisory locks, ...)
        conn.autocommit = True
        try:
            conn.execute("DISCARD ALL")
        finally:
            conn.autocommit = False

    def run(self, sql, row_limit=None):
        """Executes SQL in a rolled-back transaction.

        Returns dict: ok, columns, rows (raw values), truncated, messages, error, elapsed_ms.
        `rows` holds up to `row_limit` rows of the LAST statement that returned rows.
        """
        row_limit = row_limit or self.max_display_rows
        result = {"ok": True, "columns": None, "rows": [], "truncated": False,
                  "messages": [], "error": None, "elapsed_ms": 0, "statements": 0}
        if not self.configured:
            result.update(ok=False, error={"message": "PRACTICE_DATABASE_URL is not configured in .env"})
            return result

        statements = split_statements(sql or "")
        if not statements:
            result.update(ok=False, error={"message": "Nothing to run - the editor is empty."})
            return result
        try:
            plan = [(s, classify(s)) for s in statements]
        except QueryRejected as e:
            result.update(ok=False, error={"message": str(e)})
            return result
        result["statements"] = len(statements)

        started = time.perf_counter()
        try:
            with self._get_pool().connection() as conn:
                notices = []
                handler = lambda diag: notices.append(f"{diag.severity}: {diag.message_primary}")
                conn.add_notice_handler(handler)
                watchdog = threading.Timer(self.timeout_s + 5, self._cancel, args=(conn,))
                watchdog.start()
                try:
                    self._execute_plan(conn, plan, row_limit, result)
                finally:
                    watchdog.cancel()
                    try:
                        conn.rollback()
                    finally:
                        conn.remove_notice_handler(handler)
                result["messages"] = notices + result["messages"]
        except psycopg.OperationalError as e:
            result.update(ok=False, error={"message": f"Could not reach the practice database: {e}"})
        except Exception as e:  # pool timeout etc.
            result.update(ok=False, error={"message": f"{type(e).__name__}: {e}"})
        result["elapsed_ms"] = int((time.perf_counter() - started) * 1000)
        return result

    @staticmethod
    def _cancel(conn):
        try:
            conn.cancel()
        except Exception:
            pass

    def _execute_plan(self, conn, plan, row_limit, result):
        ms = int(self.timeout_s * 1000)
        with conn.cursor() as cur:
            cur.execute(f"SET LOCAL statement_timeout = {ms}")
            cur.execute(f"SET LOCAL lock_timeout = {min(ms, 5000)}")
            cur.execute(f"SAVEPOINT {SANDBOX_SAVEPOINT}")

        for idx, (stmt, action) in enumerate(plan, start=1):
            label = f"[{idx}] " if len(plan) > 1 else ""
            if action == "skip":
                result["messages"].append(f"{label}{_words(stmt, 1)[0]} ignored - the sandbox manages the transaction.")
                continue
            if action == "rollback":
                conn.execute(f"ROLLBACK TO SAVEPOINT {SANDBOX_SAVEPOINT}")
                result["messages"].append(f"{label}ROLLBACK (changes made so far in this run were undone)")
                continue
            try:
                status = self._execute_one(conn, stmt, row_limit, result)
                result["messages"].append(f"{label}{status}")
            except psycopg.Error as e:
                diag = e.diag
                msg = diag.message_primary or str(e).strip()
                if isinstance(e, psycopg.errors.QueryCanceled):
                    msg = f"Query cancelled - it exceeded the {self.timeout_s}s time limit."
                result.update(ok=False, error={
                    "message": msg,
                    "detail": diag.message_detail,
                    "hint": diag.message_hint,
                    "sqlstate": diag.sqlstate,
                    "statement_index": idx,
                    "position": diag.statement_position,
                })
                return

    def _execute_one(self, conn, stmt, row_limit, result):
        """Runs one statement; large SELECTs stream through a server-side cursor."""
        if _words(stmt, 1)[0] in _ROW_RETURNING_FIRST_WORDS:
            conn.execute("SAVEPOINT __sandbox_stmt")
            try:
                with conn.cursor(name=f"c_{uuid.uuid4().hex[:12]}") as cur:
                    cur.execute(stmt)
                    self._capture(cur, row_limit, result)
                    status = f"SELECT {len(result['rows'])}{'+' if result['truncated'] else ''}"
                conn.execute("RELEASE SAVEPOINT __sandbox_stmt")
                return status
            except psycopg.errors.FeatureNotSupported:
                # e.g. data-modifying CTE or SELECT INTO cannot be DECLAREd - run it normally.
                conn.execute("ROLLBACK TO SAVEPOINT __sandbox_stmt")
            except psycopg.Error as e:
                if e.sqlstate in ("42601", "0A000") or "DECLARE" in (e.diag.message_primary or ""):
                    conn.execute("ROLLBACK TO SAVEPOINT __sandbox_stmt")
                else:
                    raise

        with conn.cursor() as cur:
            cur.execute(stmt)
            if cur.description is not None:
                self._capture(cur, row_limit, result)
            return cur.statusmessage or "OK"

    @staticmethod
    def _capture(cur, row_limit, result):
        result["columns"] = [d.name for d in cur.description]
        if row_limit and row_limit > 0:
            rows = cur.fetchmany(row_limit + 1)
            result["truncated"] = len(rows) > row_limit
            result["rows"] = [tuple(r) for r in rows[:row_limit]]
        else:
            rows = cur.fetchall()
            result["truncated"] = False
            result["rows"] = [tuple(r) for r in rows]

    # ------------------------------------------------------------------ grading

    def expected_result(self, question):
        cached = self._expected_cache.get(question.id)
        if cached and time.time() - cached[0] < 3600:
            return cached[1]
        res = self.run(question.answer_sql, row_limit=self.grade_row_limit)
        self._expected_cache[question.id] = (time.time(), res)
        return res

    def grade(self, question, student):
        """Compares the student's run with the answer key's run.

        Returns {"verdict": correct|incorrect|self_check, "reason": str}.
        """
        if not question.is_sql:
            return {"verdict": "self_check", "reason": "Conceptual question - write your answer and click Submit to have it checked."}
        first = _words(question.answer_sql, 1)
        if first and first[0] == "EXPLAIN":
            return {"verdict": "self_check", "reason": "Query plans differ from run to run, so this can't be compared automatically - Submit to have it checked."}

        expected = self.expected_result(question)
        if not expected["ok"] or expected["columns"] is None:
            return {"verdict": "self_check", "reason": "There's no result set to compare automatically - Submit to have your query checked."}
        if expected["truncated"] or student["truncated"]:
            return {"verdict": "self_check", "reason": "The result is too large to compare automatically - Submit to have your query checked."}
        if student["columns"] is None:
            return {"verdict": "incorrect", "reason": "Your query didn't return a result set."}

        exp_cols, got_cols = len(expected["columns"]), len(student["columns"])
        if exp_cols != got_cols:
            return {"verdict": "incorrect", "reason": f"Expected {exp_cols} column(s), your result has {got_cols}."}
        exp_n, got_n = len(expected["rows"]), len(student["rows"])
        if exp_n != got_n:
            return {"verdict": "incorrect", "reason": f"Expected {exp_n} row(s), your result has {got_n}."}

        exp_rows = [tuple(_grade_value(v) for v in r) for r in expected["rows"]]
        got_rows = [tuple(_grade_value(v) for v in r) for r in student["rows"]]
        if Counter(map(repr, exp_rows)) == Counter(map(repr, got_rows)):
            return {"verdict": "correct", "reason": "Your result matches the answer key."}
        # Same data but columns in a different order?
        sort_row = lambda r: repr(sorted(r, key=repr))
        if Counter(map(sort_row, exp_rows)) == Counter(map(sort_row, got_rows)):
            return {"verdict": "correct", "reason": "Your result matches the answer key (column order differs)."}
        return {"verdict": "incorrect", "reason": "Row/column counts match, but some values differ from the answer key."}

    # ------------------------------------------------------------------ schema browser

    def schema(self, exclude=None, refresh=False):
        ts, cached = self._schema_cache
        if not refresh and cached is not None and time.time() - ts < 600:
            return cached
        if not self.configured:
            return {"error": "PRACTICE_DATABASE_URL is not configured in .env"}

        exclude_list = list(exclude or [])
        try:
            with self._get_pool().connection() as conn:
                with conn.cursor() as cur:
                    cur.execute("SELECT current_database();")
                    db_name = cur.fetchone()[0]

                    cur.execute("""
                        SELECT n.nspname AS schema_name,
                               c.relname AS rel_name,
                               CASE c.relkind 
                                 WHEN 'r' THEN 'table' 
                                 WHEN 'p' THEN 'table' 
                                 WHEN 'v' THEN 'view' 
                                 WHEN 'm' THEN 'view' 
                                 ELSE 'table'
                               END AS rel_type
                        FROM pg_class c
                        JOIN pg_namespace n ON n.oid = c.relnamespace
                        WHERE LEFT(n.nspname, 3) != 'pg_' 
                          AND NOT (n.nspname = ANY(%s))
                          AND c.relkind IN ('r', 'p', 'v', 'm')
                        ORDER BY n.nspname, c.relname;
                    """, (exclude_list,))
                    relations = cur.fetchall()

                    cur.execute("""
                        SELECT 
                            c.table_schema,
                            c.table_name,
                            c.column_name,
                            CASE 
                                WHEN c.data_type = 'character varying' THEN 
                                    CASE WHEN c.character_maximum_length IS NOT NULL 
                                         THEN 'varchar(' || c.character_maximum_length || ')' 
                                         ELSE 'varchar' END
                                WHEN c.data_type = 'character' THEN 'char(' || c.character_maximum_length || ')'
                                WHEN c.data_type = 'numeric' THEN 
                                    CASE WHEN c.numeric_precision IS NOT NULL 
                                         THEN 'numeric(' || c.numeric_precision || COALESCE(',' || c.numeric_scale, '') || ')'
                                         ELSE 'numeric' END
                                ELSE c.udt_name
                            END AS formatted_type,
                            c.is_nullable = 'YES' AS is_nullable,
                            c.column_default,
                            CASE WHEN pk.column_name IS NOT NULL THEN true ELSE false END AS is_pk
                        FROM information_schema.columns c
                        LEFT JOIN (
                            SELECT ku.table_schema, ku.table_name, ku.column_name
                            FROM information_schema.table_constraints tc
                            JOIN information_schema.key_column_usage ku
                              ON tc.constraint_name = ku.constraint_name
                              AND tc.table_schema = ku.table_schema
                            WHERE tc.constraint_type = 'PRIMARY KEY'
                        ) pk ON c.table_schema = pk.table_schema 
                            AND c.table_name = pk.table_name 
                            AND c.column_name = pk.column_name
                        WHERE LEFT(c.table_schema, 3) != 'pg_'
                          AND NOT (c.table_schema = ANY(%s))
                        ORDER BY c.table_schema, c.table_name, c.ordinal_position;
                    """, (exclude_list,))
                    cols = cur.fetchall()

                    cur.execute("""
                        SELECT 
                            n.nspname AS schema_name,
                            c.relname AS table_name,
                            con.conname AS constraint_name,
                            CASE con.contype
                                WHEN 'p' THEN 'PRIMARY KEY'
                                WHEN 'f' THEN 'FOREIGN KEY'
                                WHEN 'u' THEN 'UNIQUE'
                                WHEN 'c' THEN 'CHECK'
                                WHEN 'x' THEN 'EXCLUSION'
                                ELSE con.contype::text
                            END AS constraint_type,
                            pg_get_constraintdef(con.oid, true) AS definition
                        FROM pg_constraint con
                        JOIN pg_class c ON c.oid = con.conrelid
                        JOIN pg_namespace n ON n.oid = c.relnamespace
                        WHERE LEFT(n.nspname, 3) != 'pg_'
                          AND NOT (n.nspname = ANY(%s))
                        ORDER BY n.nspname, c.relname, con.conname;
                    """, (exclude_list,))
                    constraints = cur.fetchall()

                    cur.execute("""
                        SELECT 
                            n.nspname AS schema_name,
                            t.relname AS table_name,
                            i.relname AS index_name,
                            ix.indisunique AS is_unique,
                            ix.indisprimary AS is_primary,
                            pg_get_indexdef(ix.indexrelid, 0, true) AS definition
                        FROM pg_index ix
                        JOIN pg_class t ON t.oid = ix.indrelid
                        JOIN pg_class i ON i.oid = ix.indexrelid
                        JOIN pg_namespace n ON n.oid = t.relnamespace
                        WHERE LEFT(n.nspname, 3) != 'pg_'
                          AND NOT (n.nspname = ANY(%s))
                        ORDER BY n.nspname, t.relname, i.relname;
                    """, (exclude_list,))
                    indexes = cur.fetchall()

                    cur.execute("""
                        SELECT 
                            schemaname AS schema_name,
                            tablename AS table_name,
                            rulename AS rule_name,
                            definition
                        FROM pg_rules
                        WHERE LEFT(schemaname, 3) != 'pg_'
                          AND NOT (schemaname = ANY(%s))
                        ORDER BY schemaname, tablename, rulename;
                    """, (exclude_list,))
                    rules = cur.fetchall()

                    cur.execute("""
                        SELECT 
                            n.nspname AS schema_name,
                            c.relname AS table_name,
                            t.tgname AS trigger_name,
                            pg_get_triggerdef(t.oid, true) AS definition,
                            t.tgenabled AS enabled
                        FROM pg_trigger t
                        JOIN pg_class c ON c.oid = t.tgrelid
                        JOIN pg_namespace n ON n.oid = c.relnamespace
                        WHERE NOT t.tgisinternal
                          AND LEFT(n.nspname, 3) != 'pg_'
                          AND NOT (n.nspname = ANY(%s))
                        ORDER BY n.nspname, c.relname, t.tgname;
                    """, (exclude_list,))
                    triggers = cur.fetchall()

            tree = {
                "database": db_name,
                "schemas": {}
            }

            cols_map = {}
            for s, t, col, ty, null, default, pk in cols:
                cols_map.setdefault((s, t), []).append({
                    "name": col, "type": ty, "nullable": null, "default": default, "is_pk": pk
                })

            cons_map = {}
            for s, t, cname, ctype, cdef in constraints:
                cons_map.setdefault((s, t), []).append({
                    "name": cname, "type": ctype, "definition": cdef
                })

            idx_map = {}
            for s, t, iname, uniq, prim, idef in indexes:
                idx_map.setdefault((s, t), []).append({
                    "name": iname, "is_unique": uniq, "is_primary": prim, "definition": idef
                })

            rule_map = {}
            for s, t, rname, rdef in rules:
                rule_map.setdefault((s, t), []).append({
                    "name": rname, "definition": rdef
                })

            trig_map = {}
            for s, t, tgname, tgdef, tgen in triggers:
                trig_map.setdefault((s, t), []).append({
                    "name": tgname, "definition": tgdef, "enabled": tgen
                })

            for s, rel, rtype in relations:
                schema_node = tree["schemas"].setdefault(s, {"tables": {}, "views": {}})
                target = schema_node["views"] if rtype == "view" else schema_node["tables"]
                target[rel] = {
                    "columns": cols_map.get((s, rel), []),
                    "constraints": cons_map.get((s, rel), []),
                    "indexes": idx_map.get((s, rel), []),
                    "rules": rule_map.get((s, rel), []),
                    "triggers": trig_map.get((s, rel), []),
                }

            self._schema_cache = (time.time(), tree)
            return tree
        except Exception as e:
            return {"error": f"Could not load schema: {e}"}
