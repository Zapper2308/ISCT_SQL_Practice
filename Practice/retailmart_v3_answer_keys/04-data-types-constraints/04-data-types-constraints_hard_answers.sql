/* ============================================================
   ANSWER KEY - Constraints & DML (HARD LEVEL)
   Curriculum: RetailMart V3
   Topic: 04-data-types-constraints
   ============================================================ */

/* ============================================================
   SECTION A: ADVANCED DML - CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1. UPSERT means "insert, or update if the row already exists." INSERT ... ON CONFLICT (key) DO UPDATE implements it atomically in one statement: PostgreSQL attempts the insert, and if it violates a unique/PK constraint listed in the conflict target, it switches to an UPDATE of the existing row instead - no separate SELECT-then-branch needed, and no race condition between concurrent sessions. */
/* Q2. DO NOTHING silently skips the row when a conflict occurs (useful for idempotent imports where duplicates should just be ignored). DO UPDATE actually merges new data into the existing row (useful when the incoming row carries fresher values, e.g. re-syncing a customer record). Use DO NOTHING for pure dedup; DO UPDATE for "latest wins" sync. */
/* Q3. EXCLUDED is a pseudo-table available only inside the DO UPDATE SET/WHERE clause that holds the row values that were proposed for insertion (i.e. what you tried to INSERT), as opposed to the table's own column names which refer to the existing row already in the table. It lets you write things like SET qty = t.qty + EXCLUDED.qty to combine old and new values. */
/* Q4. MERGE (PostgreSQL 15+) is a single statement that joins a target table to a source (table, view or subquery) and, per matched/unmatched condition, can INSERT, UPDATE, or DELETE rows - all three actions in one statement. This enables true three-way sync: new rows in source get inserted, changed rows get updated, and (with WHEN NOT MATCHED BY SOURCE, PG17+ only) rows missing from source could be deleted. */
/* Q5. INSERT ... ON CONFLICT only ever inserts or updates the SAME table it targets, based on a unique violation. MERGE wins when you need multiple actions (insert AND update AND delete) against a target based on an arbitrary join condition to a separate source table/subquery - e.g. full staging-table reconciliation - rather than just a single unique-key conflict. */
/* Q6. A writeable CTE is a WITH clause whose subquery is itself an INSERT, UPDATE, or DELETE (with RETURNING) instead of a plain SELECT. A real RetailMart use case: WITH archived AS (DELETE FROM old_orders RETURNING *) INSERT INTO orders_archive SELECT * FROM archived - move rows from one table to another in a single atomic statement. */
/* Q7. RETURNING captures the rows affected by the write (including server-generated values like SERIAL ids or defaults) as an in-memory result set; wrapping that INSERT in a WITH lets a following SELECT/INSERT/UPDATE reference those exact rows via the CTE name, so the read of "what I just wrote" and the follow-on action happen inside the same statement/transaction - no round trip, no race with concurrent writers. */
/* Q8. All CTEs in a single WITH clause see the same snapshot of the database as it stood BEFORE the statement began (like a single top-level statement) - they do NOT see each other's writes unless there's an explicit data dependency (one CTE selects FROM the RETURNING output of another, e.g. INSERT ... SELECT FROM first_cte). PostgreSQL evaluates writeable CTEs in an unspecified order otherwise, but the "second CTE selects from the first's RETURNING" pattern IS guaranteed to see that data because it's a direct dependency, not a query against the underlying table. */
/* Q9. COPY streams rows in binary/text/csv format directly into the table with minimal per-row parsing/planning overhead, making it dramatically faster for bulk loads (often 5-10x plain INSERT for large batches); INSERT (especially single-row) pays full statement-parse/plan cost each time. Both are equally transactional - COPY inside a transaction rolls back like any other DML; multi-row INSERT ... VALUES sits in between COPY and single-row INSERT for speed. */
/* Q10. WITH (NULL '') tells COPY to treat empty-string fields as an explicit empty string rather than as NULL (the default NULL marker is the literal string "\N" for text format, or nothing for CSV with default settings - NULL '' overrides that for CSV). Other handy COPY options: FORMAT csv/text/binary, HEADER true (skip/emit header row), DELIMITER, QUOTE, ESCAPE, ENCODING, FORCE_NOT_NULL(cols), FREEZE. */
/* Q11. SELECT ... FOR UPDATE locks the selected rows and makes any other session's own FOR UPDATE on those same rows BLOCK until the first transaction commits/rolls back. SELECT ... FOR UPDATE SKIP LOCKED instead immediately skips any row that's already locked by another transaction and returns only the rows it could lock - essential for building a multi-worker queue where workers must never block each other. */
/* Q12. An UPDATE (or SELECT FOR UPDATE) takes a row-level lock on each row it touches, held until COMMIT/ROLLBACK. If two concurrent transactions update the same two rows in opposite order (Tx1: row A then row B; Tx2: row B then row A), each can end up waiting on a lock the other holds - a deadlock, which PostgreSQL detects and resolves by aborting one transaction. Always locking/updating rows in a consistent order (e.g. ORDER BY id) across all transactions prevents this because no cycle of waits can form. */
/* Q13. A queue table pattern stores work items as rows with a status column (e.g. 'pending'/'processing'/'done'). Each worker runs SELECT * FROM jobs WHERE status='pending' ORDER BY id FOR UPDATE SKIP LOCKED LIMIT N in its own transaction, immediately marks the claimed rows 'processing', and commits - because SKIP LOCKED skips rows another worker already has locked, many workers can safely pull from the same table in parallel with zero contention or double-processing. */
/* Q14. If a BEFORE INSERT trigger's function itself performs an INSERT into the SAME table the trigger is defined on, that new INSERT will fire the BEFORE INSERT trigger again, which inserts again, which fires again... - infinite recursion until PostgreSQL hits stack depth limits and errors out. The fix is to have the trigger function insert into a DIFFERENT table, or guard with a condition/flag that prevents the nested insert from re-triggering the same logic. */
/* Q15. A BEFORE trigger function that returns NEW allows the (possibly modified) row to proceed to be actually written to the table. One that returns NULL silently cancels the operation for that row - the INSERT/UPDATE/DELETE simply does not happen for that row, with no error raised (useful for conditionally skipping rows, e.g. "don't insert if a business rule fails silently" vs RAISE EXCEPTION which aborts the whole statement). */
/* Q16. An INSTEAD OF trigger replaces the default action entirely rather than running before/after it, and it applies ONLY to VIEWS (specifically non-updatable views, or views you want custom write logic on) - never to plain tables. It lets you make an otherwise-non-updatable view (e.g. one joining multiple tables) support INSERT/UPDATE/DELETE by writing custom logic that distributes the operation to the underlying base tables. */
/* Q17. BEFORE triggers run before the triggering operation is applied to the row/table, so they can inspect and modify NEW (or cancel the operation by returning NULL) before anything is written. AFTER triggers run once the row change has already been applied (and is visible within the transaction), so they're used for side effects that depend on the change already existing - logging, cascading updates to other tables, notifications - and cannot modify the row being written. */
/* Q18. A ROW-level trigger (FOR EACH ROW) fires once per affected row, with NEW/OLD bound to that specific row - use it when the logic genuinely needs per-row data (e.g. auto-set updated_at on each row). A STATEMENT-level trigger (FOR EACH STATEMENT, the default) fires exactly once per triggering SQL statement regardless of how many rows it touched (even zero) - use it for statement-wide bookkeeping like "log that a bulk insert happened" where per-row detail isn't needed, or with a transition table when you need all affected rows at once but only one pass. */
/* Q19. REFERENCING NEW TABLE AS transition_name (on an AFTER STATEMENT trigger) exposes ALL the rows that were inserted/updated by that single statement as a queryable pseudo-table (a "transition table") inside the trigger function - e.g. SELECT count(*) FROM transition_name - letting one statement-level trigger invocation process an entire batch of rows efficiently instead of firing per-row. */
/* Q20. ON CONFLICT (key1, key2) WHERE pred targets a PARTIAL unique index (one created with a WHERE clause, e.g. UNIQUE INDEX ... ON t(email) WHERE deleted_at IS NULL) as the conflict arbiter - the ON CONFLICT clause's own WHERE pred must exactly match the partial index's predicate so Postgres knows which partial unique constraint to use for conflict detection. This lets you upsert against "logically unique among active rows" semantics, e.g. email unique only among non-deleted customers. */
/* Q21. TRUNCATE deallocates the table's data pages directly (like a fast DDL-style operation) and does not scan/log individual row deletions, making it near-instant regardless of row count; DELETE WHERE 1=1 scans and deletes every row individually, is fully MVCC-logged (each row versioned), fires row-level triggers, and leaves dead tuples for autovacuum to clean up - far slower on large tables. Both are transactional and can be rolled back in PostgreSQL (unlike some other RDBMSes where TRUNCATE auto-commits), but TRUNCATE takes an ACCESS EXCLUSIVE lock on the table. */
/* Q22. RESTART IDENTITY resets any SERIAL/IDENTITY sequence(s) owned by the truncated table's columns back to their starting value, so the next inserted row gets id=1 again (the default, CONTINUE IDENTITY, leaves the sequence counter wherever it was). */
/* Q23. A DELETE ... RETURNING inside a WITH clause captures the exact rows that were removed as an in-memory result set at the moment of deletion (including all their column values before they were gone) - a following part of the same statement (e.g. an INSERT INTO archive SELECT * FROM that CTE) can then consume those rows for further processing, e.g. archiving deleted data, all within one atomic statement rather than doing a SELECT then a separate DELETE (which risks a race between the two). */
/* Q24. Soft delete sets a deleted_at (or is_deleted) column instead of physically removing the row. Pros: data is recoverable, foreign keys referencing the row stay intact, audit/history is preserved, "undelete" is trivial. Cons: every query touching that table must remember to filter WHERE deleted_at IS NULL (easy to forget and leak "deleted" data), unique constraints need partial-index tricks to allow reuse of a value after soft-delete, table bloat grows unbounded without a separate purge job, and storage/index size never shrinks from the deletes themselves. */
/* Q25. A plain SQL statement (including DML executed inside a PL/pgSQL function called by a client) does NOT commit on its own - it participates in whatever transaction is currently open (implicit single-statement autocommit transaction if the client issued no explicit BEGIN, or the client's explicit transaction if one is open). A function body itself cannot issue COMMIT/ROLLBACK for a transaction it didn't start (except PostgreSQL 11+ procedures called via CALL, which may commit/rollback internally) - the actual commit happens only when the enclosing transaction ends, i.e. when the client sends COMMIT or, for autocommit mode, immediately after the single top-level statement finishes successfully. */

/* ============================================================
   SECTION B: UPSERT, MERGE, ADVANCED CONFLICTS (25)
   Scaffolding: builds day_03_practice tables used through Section D.
   ------------------------------------------------------------ */
DROP SCHEMA IF EXISTS day_03_practice CASCADE;
CREATE SCHEMA IF NOT EXISTS day_03_practice;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE day_03_practice.customers (
    cust_id SERIAL PRIMARY KEY,
    email VARCHAR(100) UNIQUE,
    full_name VARCHAR(100),
    tier_id INT,
    tier INT,
    last_seen TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ
);
CREATE UNIQUE INDEX idx_customers_email_active ON day_03_practice.customers(email) WHERE deleted_at IS NULL;

CREATE TABLE day_03_practice.inventory_snapshot (
    warehouse_id INT,
    product_id INT,
    snapshot_date DATE,
    quantity_on_hand INT,
    PRIMARY KEY (warehouse_id, product_id, snapshot_date)
);
CREATE TABLE day_03_practice.loyalty_members (
    customer_id INT PRIMARY KEY,
    tier INT,
    points_balance INT NOT NULL DEFAULT 0,
    points INT DEFAULT 0
);
CREATE TABLE day_03_practice.ad_spend (
    campaign_id INT,
    spend_date DATE,
    amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    PRIMARY KEY (campaign_id, spend_date)
);
CREATE TABLE day_03_practice.page_view_sessions (
    session_id VARCHAR(50) PRIMARY KEY,
    view_count INT NOT NULL DEFAULT 0
);
CREATE TABLE day_03_practice.tickets_demo (
    ticket_id SERIAL PRIMARY KEY,
    status VARCHAR(20),
    last_updated TIMESTAMPTZ
);
CREATE TABLE day_03_practice.suppliers_demo (
    supplier_id SERIAL PRIMARY KEY,
    supplier_status VARCHAR(20)
);
CREATE TABLE day_03_practice.counters (
    counter_name VARCHAR(50) PRIMARY KEY,
    value BIGINT NOT NULL DEFAULT 0
);
CREATE TABLE day_03_practice.staging_customers (
    cust_id INT,
    email VARCHAR(100),
    full_name VARCHAR(100)
);
INSERT INTO day_03_practice.staging_customers VALUES (1,'a@example.com','A One'),(2,'b@example.com','B Two');

CREATE TABLE day_03_practice.products_upsert (
    product_id SERIAL PRIMARY KEY,
    name VARCHAR(150),
    price NUMERIC(12,2)
);
INSERT INTO day_03_practice.products_upsert (name, price) VALUES ('Widget', 100);

CREATE TABLE day_03_practice.price_updates (
    product_id INT,
    new_price NUMERIC(12,2)
);
INSERT INTO day_03_practice.price_updates VALUES (1, 150);

CREATE TABLE day_03_practice.inventory_upsert (
    product_id INT PRIMARY KEY,
    quantity INT NOT NULL DEFAULT 0
);
INSERT INTO day_03_practice.inventory_upsert VALUES (1, 50);

CREATE TABLE day_03_practice.inventory_delta (
    product_id INT,
    delta INT
);
INSERT INTO day_03_practice.inventory_delta VALUES (1, -5);

CREATE TABLE day_03_practice.orders_upsert (
    order_id INT PRIMARY KEY,
    order_status VARCHAR(20)
);
INSERT INTO day_03_practice.orders_upsert VALUES (1,'Shipped');

CREATE TABLE day_03_practice.refund_set (
    order_id INT PRIMARY KEY
);
INSERT INTO day_03_practice.refund_set VALUES (1);

/* Q26. */
INSERT INTO day_03_practice.customers (email, full_name) VALUES ('a@example.com','A One')
ON CONFLICT (email) DO UPDATE SET full_name = EXCLUDED.full_name;

/* Q27. */
INSERT INTO day_03_practice.customers (email, full_name) VALUES ('c@example.com','C Three')
ON CONFLICT (email) DO NOTHING;

/* Q28. */
INSERT INTO day_03_practice.customers (email, full_name) VALUES ('a@example.com','A One Updated')
ON CONFLICT (email) WHERE deleted_at IS NULL DO UPDATE SET full_name = EXCLUDED.full_name;

/* Q29. */
INSERT INTO day_03_practice.inventory_snapshot (warehouse_id, product_id, snapshot_date, quantity_on_hand)
VALUES (1, 100, CURRENT_DATE, 50)
ON CONFLICT (warehouse_id, product_id, snapshot_date) DO UPDATE SET quantity_on_hand = EXCLUDED.quantity_on_hand;

/* Q30. */
INSERT INTO day_03_practice.loyalty_members (customer_id, points_balance) VALUES (1, 20)
ON CONFLICT (customer_id) DO UPDATE SET points_balance = day_03_practice.loyalty_members.points_balance + EXCLUDED.points_balance;

/* Q31. */
INSERT INTO day_03_practice.ad_spend (campaign_id, spend_date, amount) VALUES (1, CURRENT_DATE, 500)
ON CONFLICT (campaign_id, spend_date) DO UPDATE SET amount = day_03_practice.ad_spend.amount + EXCLUDED.amount;

/* Q32. */
INSERT INTO day_03_practice.page_view_sessions (session_id, view_count) VALUES ('sess1', 1)
ON CONFLICT (session_id) DO UPDATE SET view_count = day_03_practice.page_view_sessions.view_count + 1;

/* Q33. */
INSERT INTO day_03_practice.tickets_demo (ticket_id, status, last_updated) VALUES (1, 'Open', NOW())
ON CONFLICT (ticket_id) DO UPDATE SET last_updated = NOW();

/* Q34. */
INSERT INTO day_03_practice.suppliers_demo (supplier_id, supplier_status) VALUES (1, 'Active')
ON CONFLICT (supplier_id) DO UPDATE SET supplier_status = EXCLUDED.supplier_status
WHERE EXCLUDED.supplier_status <> day_03_practice.suppliers_demo.supplier_status;

/* Q35. */
INSERT INTO day_03_practice.counters (counter_name, value) VALUES ('page_hits', 1)
ON CONFLICT (counter_name) DO UPDATE SET value = day_03_practice.counters.value + 1;

/* Q36. */
MERGE INTO day_03_practice.customers c
USING day_03_practice.staging_customers s
ON c.cust_id = s.cust_id
WHEN MATCHED THEN UPDATE SET email = s.email, full_name = s.full_name
WHEN NOT MATCHED THEN INSERT (cust_id, email, full_name) VALUES (s.cust_id, s.email, s.full_name);

/* Q37. */
MERGE INTO day_03_practice.products_upsert p
USING day_03_practice.price_updates u
ON p.product_id = u.product_id
WHEN MATCHED THEN UPDATE SET price = u.new_price;

/* Q38. */
MERGE INTO day_03_practice.inventory_upsert i
USING day_03_practice.inventory_delta d
ON i.product_id = d.product_id
WHEN MATCHED THEN UPDATE SET quantity = i.quantity + d.delta;

/* Q39. */
MERGE INTO day_03_practice.loyalty_members m
USING (SELECT 2 AS customer_id, 30 AS pts) s
ON m.customer_id = s.customer_id
WHEN NOT MATCHED THEN INSERT (customer_id, points_balance) VALUES (s.customer_id, s.pts)
WHEN MATCHED THEN UPDATE SET points_balance = m.points_balance + s.pts;

/* Q40. */
MERGE INTO day_03_practice.orders_upsert o
USING day_03_practice.refund_set r
ON o.order_id = r.order_id
WHEN MATCHED THEN UPDATE SET order_status = 'Refunded';

/* Q41. */
INSERT INTO day_03_practice.products_upsert (name, price) VALUES ('Gadget', 250) RETURNING *;

/* Q42. */
INSERT INTO day_03_practice.customers (email, full_name) VALUES ('d@example.com','D Four'), ('e@example.com','E Five')
RETURNING cust_id;

/* Q43. */
SELECT price AS old_price FROM day_03_practice.products_upsert WHERE product_id = 1;
UPDATE day_03_practice.products_upsert SET price = price * 1.1 WHERE product_id = 1 RETURNING price AS new_price;

/* Q44. */
WITH inserted AS (
  INSERT INTO day_03_practice.products_upsert (name, price) VALUES ('Thing', 60) RETURNING *
)
SELECT * FROM inserted;

/* Q45. */
CREATE TABLE day_03_practice.customers_archive (LIKE day_03_practice.customers INCLUDING ALL);
WITH deleted AS (
  DELETE FROM day_03_practice.customers WHERE email = 'e@example.com' RETURNING *
)
INSERT INTO day_03_practice.customers_archive SELECT * FROM deleted;

/* Q46. */
INSERT INTO day_03_practice.staging_customers (cust_id, email, full_name)
SELECT n + 100, 'batch' || n || '@example.com', 'Batch ' || n FROM generate_series(1,100) n;
INSERT INTO day_03_practice.customers (cust_id, email, full_name)
SELECT cust_id, email, full_name FROM day_03_practice.staging_customers
ON CONFLICT (cust_id) DO UPDATE SET email = EXCLUDED.email, full_name = EXCLUDED.full_name;

/* Q47. */
INSERT INTO day_03_practice.customers (cust_id, email, full_name) VALUES (1, 'a@example.com', NULL)
ON CONFLICT (cust_id) DO UPDATE SET full_name = COALESCE(EXCLUDED.full_name, day_03_practice.customers.full_name);

/* Q48. */
INSERT INTO day_03_practice.customers (cust_id, email, last_seen) VALUES (1, 'a@example.com', NOW())
ON CONFLICT (cust_id) DO UPDATE SET last_seen = EXCLUDED.last_seen
WHERE EXCLUDED.last_seen > day_03_practice.customers.last_seen OR day_03_practice.customers.last_seen IS NULL;

/* Q49. */
INSERT INTO day_03_practice.customers (cust_id, email, tier_id) VALUES (1, 'a@example.com', 2)
ON CONFLICT (cust_id) DO UPDATE SET tier_id = GREATEST(EXCLUDED.tier_id, day_03_practice.customers.tier_id);

/* Q50. */
MERGE INTO day_03_practice.products_upsert p
USING (SELECT product_id FROM day_03_practice.products_upsert WHERE FALSE) s
ON p.product_id = s.product_id
WHEN NOT MATCHED THEN DO NOTHING;

/* ============================================================
   SECTION C: WRITEABLE CTE + RETURNING (25)
   Scaffolding: additional day_03_practice tables for this section.
   ------------------------------------------------------------ */
CREATE TABLE day_03_practice.old_orders (order_id SERIAL PRIMARY KEY, cust_id INT, total NUMERIC(12,2));
CREATE TABLE day_03_practice.orders_archive (LIKE day_03_practice.old_orders INCLUDING ALL);
INSERT INTO day_03_practice.old_orders (cust_id, total) VALUES (1,100),(2,200);

CREATE TABLE day_03_practice.inventory (product_id INT PRIMARY KEY, qty INT);
INSERT INTO day_03_practice.inventory VALUES (1, 100), (2, 50);
CREATE TABLE day_03_practice.audit_log (product_id INT, changed_at TIMESTAMPTZ);

CREATE TABLE day_03_practice.active_rows (id SERIAL PRIMARY KEY, val TEXT, moved BOOLEAN DEFAULT FALSE);
CREATE TABLE day_03_practice.history_rows (LIKE day_03_practice.active_rows INCLUDING ALL);
INSERT INTO day_03_practice.active_rows (val) VALUES ('a'),('b');

CREATE TABLE day_03_practice.a_tbl (id SERIAL PRIMARY KEY, val TEXT);
CREATE TABLE day_03_practice.b_tbl (id SERIAL PRIMARY KEY, val TEXT);

CREATE TABLE day_03_practice.orders_ci (order_id SERIAL PRIMARY KEY, cust_id INT, total NUMERIC(12,2));
CREATE TABLE day_03_practice.order_items_ci (item_id SERIAL PRIMARY KEY, order_id INT, product_id INT, qty INT);

CREATE TABLE day_03_practice.customers_tier_log (cust_id INT, old_tier INT, new_tier INT, changed_at TIMESTAMPTZ DEFAULT NOW());
UPDATE day_03_practice.customers SET tier = 1 WHERE cust_id = 1;

CREATE TABLE day_03_practice.customers_soft (cust_id SERIAL PRIMARY KEY, email VARCHAR(100), deleted_at TIMESTAMPTZ);
INSERT INTO day_03_practice.customers_soft (email, deleted_at) VALUES ('old@example.com', NOW() - INTERVAL '100 days');
CREATE TABLE day_03_practice.customers_backup (LIKE day_03_practice.customers_soft INCLUDING ALL);

CREATE TABLE day_03_practice.products_stock (product_id SERIAL PRIMARY KEY, stock INT);
INSERT INTO day_03_practice.products_stock (stock) VALUES (20), (5);

CREATE TABLE day_03_practice.counter_tbl (id INT PRIMARY KEY, value BIGINT DEFAULT 0);
INSERT INTO day_03_practice.counter_tbl VALUES (1, 0);

CREATE TABLE day_03_practice.staging_move (id SERIAL PRIMARY KEY, val TEXT);
INSERT INTO day_03_practice.staging_move (val) VALUES ('x'),('y');
CREATE TABLE day_03_practice.live_move (LIKE day_03_practice.staging_move INCLUDING ALL);

CREATE TABLE day_03_practice.ranked_tbl (id SERIAL PRIMARY KEY, score INT, rank INT);
INSERT INTO day_03_practice.ranked_tbl (score) VALUES (90),(70),(80);

CREATE TABLE day_03_practice.audit_events (event_id SERIAL PRIMARY KEY, action TEXT, logged_at TIMESTAMPTZ DEFAULT NOW());

CREATE TABLE day_03_practice.archive_final (LIKE day_03_practice.staging_move INCLUDING ALL);

CREATE TABLE day_03_practice.child_tbl (id SERIAL PRIMARY KEY, val TEXT);

/* Q51. */
WITH archived AS (
  DELETE FROM day_03_practice.old_orders RETURNING *
)
INSERT INTO day_03_practice.orders_archive SELECT * FROM archived;

/* Q52. */
WITH new_c AS (
  INSERT INTO day_03_practice.customers (email, tier) VALUES ('new@example.com', 1) RETURNING cust_id
)
INSERT INTO day_03_practice.loyalty_members (customer_id, tier, points)
SELECT cust_id, 1, 0 FROM new_c;

/* Q53. */
WITH up AS (
  UPDATE day_03_practice.inventory SET qty = qty - 1 WHERE product_id = 1 RETURNING product_id
)
INSERT INTO day_03_practice.audit_log SELECT product_id, now() FROM up;

/* Q54. */
WITH ins AS (
  INSERT INTO day_03_practice.child_tbl (val) VALUES ('c1') RETURNING id
)
UPDATE day_03_practice.counter_tbl SET value = value + 1 WHERE id IN (SELECT 1 FROM ins);

/* Q55. */
WITH del AS (
  DELETE FROM day_03_practice.active_rows WHERE val = 'b' RETURNING *
)
INSERT INTO day_03_practice.audit_events (action) SELECT 'deleted:' || val FROM del;

/* Q56. */
WITH split1 AS (
  INSERT INTO day_03_practice.a_tbl (val) VALUES ('x') RETURNING id
), split2 AS (
  INSERT INTO day_03_practice.b_tbl (val) VALUES ('y') RETURNING id
)
SELECT 1;

/* Q57. */
WITH new_order AS (
  INSERT INTO day_03_practice.orders_ci (cust_id, total) VALUES (1, 999) RETURNING order_id
)
INSERT INTO day_03_practice.order_items_ci (order_id, product_id, qty)
SELECT order_id, p, 1 FROM new_order, (VALUES (1),(2)) AS t(p);

/* Q58. */
WITH moved AS (
  DELETE FROM day_03_practice.active_rows WHERE val = 'a' RETURNING *
)
INSERT INTO day_03_practice.history_rows SELECT * FROM moved;

/* Q59. */
UPDATE day_03_practice.customers SET tier = 2 WHERE cust_id = 1;
WITH changed AS (
  SELECT 1 AS cust_id, 1 AS old_tier, 2 AS new_tier
)
INSERT INTO day_03_practice.customers_tier_log (cust_id, old_tier, new_tier)
SELECT cust_id, old_tier, new_tier FROM changed;

/* Q60. */
WITH old_deleted AS (
  DELETE FROM day_03_practice.customers_soft WHERE deleted_at < now() - INTERVAL '90 days' RETURNING *
)
INSERT INTO day_03_practice.customers_backup SELECT * FROM old_deleted;

/* Q61. */
WITH stats AS (
  UPDATE day_03_practice.products_stock SET stock = stock - 5 RETURNING product_id, stock
)
SELECT * FROM stats WHERE stock < 10;

/* Q62. */
WITH ins AS (
  INSERT INTO day_03_practice.a_tbl (val) VALUES ('lateral_demo') RETURNING id, val
)
SELECT i.id, i.val, upper(i.val) AS derived FROM ins i;

/* Q63. */
WITH up AS (
  INSERT INTO day_03_practice.counter_tbl (id, value) VALUES (2, 1)
  ON CONFLICT (id) DO UPDATE SET value = day_03_practice.counter_tbl.value + 1
  RETURNING id, value, (xmax = 0) AS was_insert
)
SELECT * FROM up;

/* Q64. */
DELETE FROM day_03_practice.staging_move WHERE id IN (SELECT id FROM day_03_practice.staging_move LIMIT 1000);

/* Q65. */
WITH incr AS (
  UPDATE day_03_practice.counter_tbl SET value = value + 1 WHERE id = 1 RETURNING value AS new_value
)
SELECT new_value FROM incr;

/* Q66. */
WITH old AS (
  SELECT id FROM day_03_practice.a_tbl WHERE val = 'x' FOR UPDATE
)
UPDATE day_03_practice.a_tbl SET val = 'x-locked' WHERE id IN (SELECT id FROM old);

/* Q67. */
WITH new_row AS (
  INSERT INTO day_03_practice.live_move (val) VALUES ('z') RETURNING id
)
DELETE FROM day_03_practice.staging_move WHERE id IN (SELECT id FROM new_row);

/* Q68. */
WITH t1 AS (
  INSERT INTO day_03_practice.a_tbl (val) VALUES ('multi1') RETURNING id
), t2 AS (
  INSERT INTO day_03_practice.b_tbl (val) VALUES ('multi2') RETURNING id
), t3 AS (
  INSERT INTO day_03_practice.child_tbl (val) VALUES ('multi3') RETURNING id
)
SELECT (SELECT count(*) FROM t1) + (SELECT count(*) FROM t2) + (SELECT count(*) FROM t3) AS total_inserted;

/* Q69. */
WITH dedup AS (
  SELECT DISTINCT ON (val) id, val FROM day_03_practice.staging_move ORDER BY val, id
)
INSERT INTO day_03_practice.live_move (id, val) SELECT id, val FROM dedup
ON CONFLICT (id) DO NOTHING;

/* Q70. */
WITH ranks AS (
  SELECT id, RANK() OVER (ORDER BY score DESC) AS rnk FROM day_03_practice.ranked_tbl
)
UPDATE day_03_practice.ranked_tbl t SET rank = ranks.rnk FROM ranks WHERE t.id = ranks.id;

/* Q71. */
WITH ins AS (
  INSERT INTO day_03_practice.a_tbl (val) VALUES ('logged') RETURNING id
)
INSERT INTO day_03_practice.audit_events (action) SELECT 'inserted a_tbl id=' || id FROM ins;

/* Q72. */
WITH d AS (
  DELETE FROM day_03_practice.staging_move WHERE val = 'y' RETURNING *
)
INSERT INTO day_03_practice.archive_final SELECT * FROM d;

/* Q73. "Shift IDs" (DELETE the old-id row, INSERT a new row at a different id, in one transaction) is a controversial pattern: it breaks any existing foreign keys pointing at the old id (unless cascaded/rewritten), defeats the purpose of a stable surrogate key, and creates a window (even inside one transaction) where concurrent readers relying on that id for identity can see it vanish and reappear differently. It's generally considered an anti-pattern - prefer UPDATE the existing row in place, or add a new row with a new id and mark the old one superseded, rather than deleting and re-inserting under a different id. */

/* Q74. */
UPDATE day_03_practice.customers SET tier = 3 WHERE cust_id IN (SELECT cust_id FROM day_03_practice.customers LIMIT 100);

/* Q75. */
BEGIN;
TRUNCATE day_03_practice.b_tbl;
INSERT INTO day_03_practice.b_tbl (val) SELECT val FROM day_03_practice.a_tbl;
COMMIT;

/* ============================================================
   SECTION D: BULK LOAD, CONCURRENCY, TRIGGERS (25)
   Scaffolding: additional day_03_practice tables for this section.
   Requires /tmp/products_staging.csv with header "id,name,price"
   and two data rows (e.g. 1,Widget,100 / 2,Gadget,200).
   ------------------------------------------------------------ */
CREATE TABLE day_03_practice.products_staging (id INT, name TEXT, price NUMERIC(12,2));
CREATE TABLE day_03_practice.jobs (job_id SERIAL PRIMARY KEY, status VARCHAR(20) DEFAULT 'pending', payload TEXT);
INSERT INTO day_03_practice.jobs (payload) SELECT 'job' || n FROM generate_series(1,20) n;

CREATE TABLE day_03_practice.audit_table (id SERIAL PRIMARY KEY, action TEXT, row_id INT, logged_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE day_03_practice.rows_tbl (id SERIAL PRIMARY KEY, val TEXT, created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ, immutable_key TEXT);
CREATE TABLE day_03_practice.deleted_archive (LIKE day_03_practice.rows_tbl INCLUDING ALL);

CREATE TABLE day_03_practice.parent_totals (parent_id INT PRIMARY KEY, total NUMERIC(12,2) DEFAULT 0);
CREATE TABLE day_03_practice.child_amounts (id SERIAL PRIMARY KEY, parent_id INT, amount NUMERIC(12,2));
INSERT INTO day_03_practice.parent_totals VALUES (1, 0);

/* Q76. */
\copy day_03_practice.products_staging FROM '/tmp/products_staging.csv' WITH (FORMAT csv, HEADER true)

/* Q77. */
BEGIN;
CREATE TABLE day_03_practice.freeze_demo (id INT, name TEXT, price NUMERIC(12,2));
\copy day_03_practice.freeze_demo FROM '/tmp/products_staging.csv' WITH (FORMAT csv, HEADER true, FREEZE true)
COMMIT;

/* Q78. */
INSERT INTO day_03_practice.rows_tbl (val, created_at)
SELECT 'row' || n, NOW() FROM generate_series(1,50) n LIMIT 10000;

/* Q79. */
SELECT * FROM day_03_practice.jobs WHERE status = 'pending' FOR UPDATE SKIP LOCKED LIMIT 5;

/* Q80. */
SELECT * FROM day_03_practice.jobs FOR NO KEY UPDATE LIMIT 1;

/* Q81. */
UPDATE day_03_practice.jobs SET status = 'done' WHERE job_id IN (SELECT job_id FROM day_03_practice.jobs ORDER BY job_id LIMIT 3);

/* Q82. Two transactions deadlock when Tx1 updates row A then tries to update row B, while Tx2 (concurrently) has already updated row B and now tries to update row A: Tx1 waits on Tx2's lock on B, Tx2 waits on Tx1's lock on A - a cycle. PostgreSQL's deadlock detector (checked periodically, deadlock_timeout) finds the cycle and aborts one transaction with ERROR: deadlock detected, letting the other proceed. The fix is always locking/updating rows in the same order (e.g. ORDER BY id) across every transaction that touches them. */

/* Q83. */
UPDATE day_03_practice.jobs SET status = 'claimed' WHERE job_id IN (
  SELECT job_id FROM day_03_practice.jobs WHERE status = 'pending' FOR UPDATE SKIP LOCKED LIMIT 1
) RETURNING job_id;

/* Q84. */
CREATE OR REPLACE FUNCTION day_03_practice.set_created_at() RETURNS TRIGGER AS $$
BEGIN
  NEW.created_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_set_created_at BEFORE INSERT ON day_03_practice.rows_tbl
FOR EACH ROW EXECUTE FUNCTION day_03_practice.set_created_at();

/* Q85. */
CREATE OR REPLACE FUNCTION day_03_practice.log_insert() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO day_03_practice.audit_table (action, row_id) VALUES ('INSERT', NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_log_insert AFTER INSERT ON day_03_practice.rows_tbl
FOR EACH ROW EXECUTE FUNCTION day_03_practice.log_insert();

/* Q86. */
CREATE OR REPLACE FUNCTION day_03_practice.prevent_immutable_change() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.immutable_key IS DISTINCT FROM OLD.immutable_key THEN
    RAISE EXCEPTION 'immutable_key cannot be changed';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_prevent_immutable_change BEFORE UPDATE ON day_03_practice.rows_tbl
FOR EACH ROW EXECUTE FUNCTION day_03_practice.prevent_immutable_change();

/* Q87. */
CREATE OR REPLACE FUNCTION day_03_practice.archive_deleted() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO day_03_practice.deleted_archive SELECT (OLD).*;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_archive_deleted AFTER DELETE ON day_03_practice.rows_tbl
FOR EACH ROW EXECUTE FUNCTION day_03_practice.archive_deleted();

/* Q88. */
CREATE VIEW day_03_practice.jobs_view AS SELECT job_id, status, payload FROM day_03_practice.jobs;
CREATE OR REPLACE FUNCTION day_03_practice.jobs_view_insert() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO day_03_practice.jobs (status, payload) VALUES (NEW.status, NEW.payload);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_jobs_view_instead_insert INSTEAD OF INSERT ON day_03_practice.jobs_view
FOR EACH ROW EXECUTE FUNCTION day_03_practice.jobs_view_insert();

/* Q89. */
CREATE OR REPLACE FUNCTION day_03_practice.log_statement_insert() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO day_03_practice.audit_table (action) VALUES ('STATEMENT_INSERT');
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_log_statement_insert AFTER INSERT ON day_03_practice.jobs
FOR EACH STATEMENT EXECUTE FUNCTION day_03_practice.log_statement_insert();

/* Q90. */
CREATE OR REPLACE FUNCTION day_03_practice.inspect_new_rows() RETURNS TRIGGER AS $$
DECLARE
  cnt INT;
BEGIN
  SELECT count(*) INTO cnt FROM new_rows;
  INSERT INTO day_03_practice.audit_table (action) VALUES ('BULK_INSERT_COUNT:' || cnt);
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_inspect_new_rows AFTER INSERT ON day_03_practice.jobs
REFERENCING NEW TABLE AS new_rows
FOR EACH STATEMENT EXECUTE FUNCTION day_03_practice.inspect_new_rows();

/* Q91. */
CREATE OR REPLACE FUNCTION day_03_practice.limit_single_row_update() RETURNS TRIGGER AS $$
DECLARE
  cnt INT;
BEGIN
  SELECT count(*) INTO cnt FROM updated_rows;
  IF cnt > 1 THEN
    RAISE EXCEPTION 'Only single-row UPDATEs are allowed on this table (got %)', cnt;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_limit_single_row_update AFTER UPDATE ON day_03_practice.jobs
REFERENCING NEW TABLE AS updated_rows
FOR EACH STATEMENT EXECUTE FUNCTION day_03_practice.limit_single_row_update();

/* Q92. */
CREATE OR REPLACE FUNCTION day_03_practice.touch_updated_at() RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_touch_updated_at BEFORE UPDATE ON day_03_practice.rows_tbl
FOR EACH ROW EXECUTE FUNCTION day_03_practice.touch_updated_at();

/* Q93. */
CREATE OR REPLACE FUNCTION day_03_practice.recompute_parent_total() RETURNS TRIGGER AS $$
BEGIN
  UPDATE day_03_practice.parent_totals
  SET total = (SELECT COALESCE(SUM(amount),0) FROM day_03_practice.child_amounts WHERE parent_id = COALESCE(NEW.parent_id, OLD.parent_id))
  WHERE parent_id = COALESCE(NEW.parent_id, OLD.parent_id);
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_recompute_parent_total AFTER INSERT OR UPDATE OR DELETE ON day_03_practice.child_amounts
FOR EACH ROW EXECUTE FUNCTION day_03_practice.recompute_parent_total();

/* Q94. */
CREATE OR REPLACE FUNCTION day_03_practice.check_amount_positive() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.amount <= 0 THEN
    RAISE EXCEPTION 'amount must be positive';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE CONSTRAINT TRIGGER trg_check_amount_positive AFTER INSERT OR UPDATE ON day_03_practice.child_amounts
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION day_03_practice.check_amount_positive();

/* Q95. */
ALTER TABLE day_03_practice.parent_totals ADD COLUMN child_count INT DEFAULT 0;
CREATE OR REPLACE FUNCTION day_03_practice.maintain_child_count() RETURNS TRIGGER AS $$
BEGIN
  UPDATE day_03_practice.parent_totals
  SET child_count = (SELECT count(*) FROM day_03_practice.child_amounts WHERE parent_id = COALESCE(NEW.parent_id, OLD.parent_id))
  WHERE parent_id = COALESCE(NEW.parent_id, OLD.parent_id);
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_maintain_child_count AFTER INSERT OR DELETE ON day_03_practice.child_amounts
FOR EACH ROW EXECUTE FUNCTION day_03_practice.maintain_child_count();

/* Q96. Safely COPYing into a hot (actively-written) table: COPY itself takes only a ROW EXCLUSIVE lock (same as INSERT), so it does not block concurrent reads or other inserts - it's safe by default. To avoid contention/bloat under heavy concurrent write load: batch the COPY into smaller chunks rather than one giant transaction (shorter lock/txn duration, less risk of long-running-transaction bloat), avoid disabling/rebuilding indexes on a live table (do that only for true offline bulk loads), and consider loading into an UNLOGGED or separate staging table first, then MERGE/INSERT SELECT into the hot table in controlled batches during low-traffic windows. */

/* Q97. */
CREATE UNLOGGED TABLE day_03_practice.fast_staging (id INT, name TEXT, price NUMERIC(12,2));
\copy day_03_practice.fast_staging FROM '/tmp/products_staging.csv' WITH (FORMAT csv, HEADER true)

/* Q98. For loading roughly 1 million rows, COPY is fastest (single bulk-parsed stream, minimal per-row overhead, can use FREEZE on a fresh table for extra speed); a multi-row INSERT ... VALUES (batched, e.g. 1,000 rows per statement) is a distant second (still avoids most per-statement overhead); and 1 million separate single-row INSERT statements is by far the slowest, since each pays full parse/plan/executor/WAL-flush overhead and (without batching) commonly runs 10-50x+ slower than COPY. */

/* Q99. */
INSERT INTO day_03_practice.fast_staging (id, name)
SELECT n, 'row' || n FROM generate_series(1, 1000) n;

/* Q100. The "ETL stage -> upsert" pattern: (1) COPY the raw file into an UNLOGGED or plain staging table with no constraints (fast, unconstrained bulk load); (2) run MERGE INTO target USING staging ON <key match> WHEN MATCHED THEN UPDATE ... WHEN NOT MATCHED THEN INSERT ... (or INSERT ... ON CONFLICT DO UPDATE) to reconcile staging data into the real target table, applying business rules/constraints only during this merge step; (3) DROP (or TRUNCATE, if the staging table is reused) the staging table to reclaim space and prepare for the next load. Wrapping steps 1-3 in one transaction keeps the whole ETL cycle atomic. */
