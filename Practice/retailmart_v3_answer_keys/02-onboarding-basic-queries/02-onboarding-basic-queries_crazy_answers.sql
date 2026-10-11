/* ============================================================
   ANSWER KEY - Installation & RetailMart Onboarding (CRAZY LEVEL)
   Curriculum:   RetailMart V3
   Note: This instance has no shared_preload_libraries loaded, so
   pg_stat_statements (needs a server restart to enable) is not
   available here - those questions are answered conceptually with
   the exact query pattern you'd run once the extension is enabled.
   ============================================================ */

/* Q1.  Pattern: SELECT query, calls, total_exec_time FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 10; - requires pg_stat_statements in shared_preload_libraries (not loaded on this instance). */
/* Q2.  Pattern: SELECT query, calls, mean_exec_time FROM pg_stat_statements WHERE calls > 50 ORDER BY mean_exec_time DESC LIMIT 10; - filters out one-off queries so the average isn't skewed by noise. */
/* Q3.  pg_stat_statements only exposes mean/stddev, not true percentiles; you'd approximate p95 as mean_exec_time + 1.645*stddev_exec_time, or better, pair it with auto_explain/log analysis for real percentiles. */
/* Q4.  Pattern: SELECT query, calls, temp_blks_written FROM pg_stat_statements ORDER BY temp_blks_written DESC LIMIT 10; - flags queries that spill sorts/hashes to disk because work_mem is too small. */
/* Q5.  Pattern: SELECT query, shared_blks_read FROM pg_stat_statements ORDER BY shared_blks_read DESC LIMIT 10; - high shared_blks_read relative to shared_blks_hit means the query is missing the buffer cache often. */
/* Q6.  Pattern: SELECT query, wal_bytes FROM pg_stat_statements ORDER BY wal_bytes DESC LIMIT 10; - surfaces the writes generating the most WAL (and hence replication/checkpoint load). */
/* Q7.  Pattern: SELECT query, rows / NULLIF(calls,0) AS rows_per_call FROM pg_stat_statements ORDER BY rows_per_call DESC LIMIT 10; - a query fetching huge row counts per call may be missing a WHERE/LIMIT it should have. */
/* Q8.  Filter pg_stat_statements by userid resolved to the role that runs autovacuum's ANALYZE-triggered statements, or more directly just exclude it and monitor autovacuum activity separately via pg_stat_user_tables. */
/* Q9.  pg_stat_statements_reset() zeroes the counters as a new baseline; running the same top-N query again after a period shows only activity accumulated since that reset, useful for before/after comparisons. */
/* Q10. Pattern: SELECT query, calls, total_exec_time, round(total_exec_time / NULLIF(calls,0),2) AS avg_ms FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 20; - grouped by application via pg_stat_statements.userid/dbid joined to pg_stat_activity if still connected. */
/* Q11. A per-query queryid staying the same but its plan changing shows up as a sudden jump in mean_exec_time for that queryid over time - you'd snapshot pg_stat_statements periodically and diff mean_exec_time trends per queryid to catch it. */
/* Q12. You'd need repeated snapshots (e.g. a cron job copying pg_stat_statements into a history table hourly) to compute calls-per-hour as the delta between consecutive snapshots. */
/* Q13. Pattern: SELECT query, calls, rows FROM pg_stat_statements WHERE calls > 1000000 AND rows / NULLIF(calls,0) < 2 ORDER BY calls DESC; - many tiny lookups is the signature of an N+1 query problem from the app layer. */
/* Q14. Pattern: SELECT query, rows / NULLIF(calls,0) AS rows_per_call FROM pg_stat_statements WHERE rows / NULLIF(calls,0) > 1000000 ORDER BY rows_per_call DESC; - a "kitchen sink" query pulls far more rows per call than any UI could reasonably render. */
/* Q15. Compare jit_functions/jit_generation_time/jit_inlining_time against total_exec_time in pg_stat_statements - if JIT compile time approaches the query's own runtime, JIT is adding overhead without payoff and should be disabled for that workload. */
/* Q16. SELECT pg_stat_statements_reset(); then let the app run for 24h, then re-query top-N - this gives a clean, uncontaminated window instead of stats accumulated since server start. */
/* Q17. Compute blk_read_time + blk_write_time (IO-bound) vs total_exec_time - (blk_read_time + blk_write_time) (CPU-bound, needs track_io_timing on) per query to classify which resource dominates. */
/* Q18. A "cliff" shows as the same queryid's mean_exec_time jumping ~10x between two consecutive snapshots - correlate the jump's timestamp with recent deploys, data growth, or a dropped/bloated index. */
/* Q19. Snapshot pg_stat_statements right before and right after each deploy; any queryid whose mean_exec_time regresses materially post-deploy flags a code or migration change (e.g. a lost index, a new N+1 pattern) worth reverting or fixing. */
/* Q20. Pattern: SELECT query, calls FROM pg_stat_statements WHERE temp_blks_written > 0 AND calls = temp_blks_written -- (or ratio near 1); every single call needs disk temp space, a strong signal work_mem is undersized for that query's sort/hash. */
/* Q21. Compute stddev_exec_time / NULLIF(mean_exec_time,0) per query - a high coefficient of variation means the same query sometimes runs fast and sometimes very slow (parameter sensitivity, lock waits, or cache-state dependence). */
/* Q22. pg_stat_statements itself has no application_name column - you'd join its userid/dbid to currently-connected pg_stat_activity rows, or better, log application_name alongside query text via log_line_prefix and aggregate from logs. */
/* Q23. Pattern: SELECT query, calls, total_exec_time / NULLIF(calls,0) AS avg_ms FROM pg_stat_statements WHERE calls > 10000 AND total_exec_time / NULLIF(calls,0) > 100 ORDER BY calls DESC; - frequent + slow queries are the ones most likely to exhaust a connection pool. */
/* Q24. Compare the set of queryids seen in pg_stat_statements against a known list of queries the application issues (from code/ORM logs); any queryid the app defines but that never appears in pg_stat_statements has effectively become dead code. */
/* Q25. Pattern: SELECT userid::regrole, query, calls FROM pg_stat_statements ORDER BY userid, calls DESC; then apply ROW_NUMBER() OVER (PARTITION BY userid ORDER BY calls DESC) and filter to rank <= 5. */

/* ============================================================
   SECTION B: LOCKING & CONTENTION (25)
   ------------------------------------------------------------ */

/* Q26. */
SELECT pid, usename, now() - xact_start AS xact_duration, query
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
ORDER BY xact_duration DESC;

/* Q27. */
SELECT l.pid, a.usename, a.query
FROM pg_locks l
JOIN pg_stat_activity a ON a.pid = l.pid
WHERE l.mode = 'AccessExclusiveLock' AND l.granted;

/* Q28. Pattern: WITH RECURSIVE chain AS (SELECT pid, pg_blocking_pids(pid) AS blockers FROM pg_stat_activity WHERE cardinality(pg_blocking_pids(pid)) > 0 UNION ALL SELECT c.pid, pg_blocking_pids(b) FROM chain c, unnest(c.blockers) b WHERE cardinality(pg_blocking_pids(b)) > 0) SELECT * FROM chain; - walks pg_blocking_pids() recursively from each blocked backend up to its root blocker. */

/* Q29. */
SELECT pid, usename, wait_event_type, wait_event, now() - query_start AS waiting_for
FROM pg_stat_activity
WHERE wait_event_type = 'Lock'
ORDER BY waiting_for DESC;

/* Q30. */
SELECT pid, usename, now() - state_change AS idle_in_txn_duration
FROM pg_stat_activity
WHERE state = 'idle in transaction' AND now() - state_change > interval '5 minutes';

/* Q31. */
SELECT l.relation::regclass AS table_name, count(*) AS lock_waiters
FROM pg_locks l
WHERE NOT l.granted AND l.relation IS NOT NULL
GROUP BY l.relation
ORDER BY lock_waiters DESC;

/* Q32. */
SELECT locktype, mode, granted, pid
FROM pg_locks
WHERE locktype = 'advisory';

/* Q33. */
SELECT pid, now() - xact_start AS running_for, query
FROM pg_stat_activity
WHERE query ILIKE 'autovacuum:%' AND now() - xact_start > interval '10 minutes';

/* Q34. */
SELECT datname, deadlocks
FROM pg_stat_database
WHERE datname = current_database();

/* Q35. Pattern: SELECT sender_host, status, sent_lsn, write_lsn, replay_lsn, sent_lsn - replay_lsn AS lag_bytes FROM pg_stat_replication; - a growing lag_bytes gap over successive checks means the WAL sender/receiver is falling behind (this instance has no replicas, so it returns 0 rows). */

/* Q36. */
SELECT application_name, pid, now() - state_change AS idle_duration
FROM pg_stat_activity
WHERE state = 'idle'
ORDER BY idle_duration DESC;

/* Q37. */
SELECT pid, usename, now() - query_start AS running_for, query
FROM pg_stat_activity
WHERE state = 'active' AND now() - query_start > interval '30 seconds';

/* Q38. Never call pg_terminate_backend() against a pid you don't own on a shared server without confirming it first. Safer wrapper: SELECT pid, query FROM pg_stat_activity WHERE pid = $1; -- confirm identity, then SELECT pg_terminate_backend($1) only after review, and prefer pg_cancel_backend() first (cancels the query, keeps the session alive) over the harder terminate. */
/* Q39. GRANT pg_signal_backend TO monitoring_role; lets a non-superuser role call pg_cancel_backend()/pg_terminate_backend() on backends owned by the same role, without granting full superuser just to kill runaway queries. */
/* Q40. Rule of thumb: AccessShareLock (plain SELECT) conflicts only with AccessExclusiveLock; RowExclusiveLock (INSERT/UPDATE/DELETE) conflicts with Share/ShareRowExclusive/Exclusive/AccessExclusive; AccessExclusiveLock (DROP/TRUNCATE/most ALTER TABLE) conflicts with every other mode, including plain SELECTs. */
/* Q41. Look for many short-lived subtransactions (heavy use of SAVEPOINT or exception-handling PL/pgSQL blocks) piling up faster than pg_subtrans can track efficiently - visible as SubtransControlLock waits in pg_stat_activity.wait_event. */
/* Q42. deadlock_timeout (default 1s) is how long a backend waits before checking for a deadlock cycle at all; lock_timeout is the hard cap after which it gives up and errors out - keep deadlock_timeout well below lock_timeout so real deadlocks get detected before the whole wait just times out anyway. */
/* Q43. */
SELECT l.relation::regclass, l.mode, a.pid, a.state, now() - a.xact_start AS xact_age
FROM pg_locks l
JOIN pg_stat_activity a ON a.pid = l.pid
WHERE l.mode LIKE '%RowExclusive%'
ORDER BY xact_age DESC;

/* Q44. */
SELECT pid, usename, now() - xact_start AS xact_age, backend_xmin
FROM pg_stat_activity
WHERE backend_xmin IS NOT NULL
ORDER BY xact_age DESC;

/* Q45. */
SELECT pid, age(backend_xid) AS xact_age_in_txns
FROM pg_stat_activity
WHERE backend_xid IS NOT NULL
ORDER BY xact_age_in_txns DESC;

/* Q46. */
SELECT pid, usename, query, now() - xact_start AS running_for
FROM pg_stat_activity
WHERE query ILIKE 'autovacuum:%'
ORDER BY running_for DESC;

/* Q47. Pattern: SELECT pid, query FROM pg_stat_activity WHERE wait_event = 'tuple' AND query ILIKE '%FOR UPDATE%'; - a queue table where many workers SELECT ... FOR UPDATE the same rows shows up as several backends waiting on the same tuple lock; SKIP LOCKED (see topic 04) is the fix. */
/* Q48. */
SELECT pid, usename, age(backend_xid) AS xact_age, query
FROM pg_stat_activity
WHERE backend_xid IS NOT NULL
ORDER BY xact_age DESC
LIMIT 1;

/* Q49. */
SELECT l.relation::regclass AS table_name, count(*) AS lock_count
FROM pg_locks l
WHERE l.relation IS NOT NULL
GROUP BY l.relation
ORDER BY lock_count DESC
LIMIT 10;

/* Q50. */
SELECT pid, query, (SELECT count(*) FROM pg_stat_get_backend_idset() b WHERE pg_stat_get_backend_pid(b) = a.pid) AS worker_hint
FROM pg_stat_activity a
WHERE backend_type = 'parallel worker';

/* ============================================================
   SECTION C: INDEX FORENSICS (25)
   ------------------------------------------------------------ */

/* Q51. */
SELECT n.nspname AS schema, c.relname AS table_name,
       pg_relation_size(c.oid) AS heap_bytes,
       pg_indexes_size(c.oid) AS index_bytes,
       round(pg_indexes_size(c.oid)::numeric / NULLIF(pg_relation_size(c.oid),0), 2) AS index_to_heap_ratio
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r' AND n.nspname NOT IN ('pg_catalog','information_schema')
ORDER BY index_to_heap_ratio DESC NULLS LAST;

/* Q52. */
SELECT indrelid::regclass AS table_name, array_agg(indexrelid::regclass) AS duplicate_indexes
FROM pg_index
GROUP BY indrelid, indkey, indclass
HAVING count(*) > 1;

/* Q53. */
SELECT a.indexrelid::regclass AS narrower_index, b.indexrelid::regclass AS covers_it
FROM pg_index a
JOIN pg_index b ON a.indrelid = b.indrelid AND a.indexrelid <> b.indexrelid
WHERE a.indkey::int2[] = (b.indkey::int2[])[1:array_length(a.indkey::int2[],1)]
AND array_length(a.indkey::int2[],1) < array_length(b.indkey::int2[],1);

/* Q54. */
SELECT s.schemaname, s.relname, s.indexrelname
FROM pg_stat_user_indexes s
WHERE s.idx_scan = 0;

/* Q55. */
SELECT schemaname, relname, indexrelname, idx_scan, idx_tup_fetch,
       round(idx_tup_fetch::numeric / NULLIF(idx_scan,0), 2) AS avg_tuples_per_scan
FROM pg_stat_user_indexes
WHERE idx_scan > 0
ORDER BY avg_tuples_per_scan ASC;

/* Q56. This needs the pgstattuple extension for real page-level bloat numbers. Pattern once enabled (CREATE EXTENSION pgstattuple;): SELECT indexrelid::regclass, avg_leaf_density FROM pgstatindex('schema.some_index_name'); - a low avg_leaf_density (well under 90) signals a bloated index worth REINDEXing. */
/* Q57. */
SELECT n.nspname AS schema, c.relname AS table_name, i.relname AS index_name
FROM pg_index ix
JOIN pg_class i ON i.oid = ix.indexrelid
JOIN pg_class c ON c.oid = ix.indrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE NOT ix.indisvalid;

/* Q58. Look for a predicate frequently reused in application WHERE clauses that matches the vast majority of rows in a table (e.g. order_status <> 'Cancelled' when only 5% of orders are cancelled) - the index isn't selective enough to help and should either be dropped or rebuilt as a partial index over the rare minority case instead. */
/* Q59. A BTREE index on a column mostly queried with equality/range predicates on scalar values is correct as-is; it should become GIST/GIN instead only if it's indexing full-text search (tsvector), JSONB containment (@>), array overlap, or geometric/range overlap queries that BTREE cannot support efficiently. */
/* Q60. */
SELECT n.nspname AS schema, c.relname AS table_name, i.relname AS index_name, a.attname AS column_name
FROM pg_index ix
JOIN pg_class i ON i.oid = ix.indexrelid
JOIN pg_class c ON c.oid = ix.indrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = ANY(ix.indkey)
WHERE a.atttypid = 'boolean'::regtype;

/* Q61. */
SELECT schemaname, relname, seq_scan, idx_scan
FROM pg_stat_user_tables
WHERE seq_scan > idx_scan AND seq_scan > 0
ORDER BY seq_scan DESC;

/* Q62. Reordering index columns is a design exercise, not a single query: put the highest-cardinality (most selective) equality-filtered column first, since a multi-column BTREE can only use a leading-column prefix efficiently - check per-column cardinality with SELECT attname, n_distinct FROM pg_stats WHERE schemaname='sales' AND tablename='orders'; to decide the order. */
/* Q63. Feed a slow query's WHERE/JOIN/ORDER BY columns into EXPLAIN (ANALYZE, BUFFERS) first; the "best index" is usually a composite BTREE with equality columns first, then the range/sort column last, e.g. CREATE INDEX ON sales.orders (cust_id, order_date) for a query filtering by customer and sorting by date. */
/* Q64. RetailMart V3 has no partitioned tables, so this is purely the pattern: a "local" index (created directly on one partition) only covers that partition's rows, while CREATE INDEX on the partitioned parent (PG11+) auto-propagates a matching local index to every existing and future partition, behaving like one logical "global" index. */
/* Q65. Pattern once pgstattuple is enabled: SELECT indexrelid::regclass, avg_leaf_density FROM pgstatindex('idx_name') ORDER BY avg_leaf_density ASC LIMIT 10; then REINDEX INDEX CONCURRENTLY idx_name; one at a time to avoid locking the table. */
/* Q66. */
SELECT schemaname, relname, indexrelname
FROM pg_stat_user_indexes
WHERE idx_scan = 0;

/* Q67. */
SELECT tc.table_schema, tc.table_name, kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
AND NOT EXISTS (
  SELECT 1 FROM pg_index ix
  JOIN pg_class c ON c.oid = ix.indrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
  JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = ix.indkey[0]
  WHERE n.nspname = tc.table_schema AND c.relname = tc.table_name AND a.attname = kcu.column_name
);

/* Q68. */
SELECT round(avg(idx_scan),1) AS avg_index_scan_count
FROM pg_stat_user_indexes;

/* Q69. */
SELECT schemaname, relname, indexrelname,
       idx_blks_hit + idx_blks_read AS total_io_blocks
FROM pg_statio_user_indexes
ORDER BY total_io_blocks DESC
LIMIT 10;

/* Q70. This needs the pgstattuple extension for a real drift comparison. Pattern: SELECT s.indexrelname, s.idx_scan, p.avg_leaf_density FROM pg_stat_user_indexes s, LATERAL pgstatindex(s.indexrelid) p; - compares Postgres's usage counters against pgstattuple's actual page-density measurement. */
/* Q71. */
SELECT schemaname, relname, seq_scan, idx_scan, pg_size_pretty(pg_relation_size(relid)) AS table_size
FROM pg_stat_user_tables
WHERE seq_scan > 100 AND idx_scan < seq_scan
ORDER BY seq_scan DESC;

/* Q72. */
SELECT n.nspname AS schema, c.relname AS index_name
FROM pg_class c
JOIN pg_am am ON am.oid = c.relam
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'i' AND am.amname = 'hash';

/* Q73. */
SELECT n.nspname AS schema, c.relname AS index_name, pg_get_indexdef(c.oid) AS index_def
FROM pg_class c
JOIN pg_am am ON am.oid = c.relam
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'i' AND am.amname = 'brin';

/* Q74. */
SELECT n.nspname AS schema, c.relname AS table_name, a.attname AS column_name, a.attstattarget
FROM pg_attribute a
JOIN pg_class c ON c.oid = a.attrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_index ix ON ix.indrelid = c.oid AND a.attnum = ANY(ix.indkey)
WHERE a.attstattarget >= 0
ORDER BY schema, table_name;

/* Q75. There's no catalog column recording "when an index was last rebuilt" - REINDEX doesn't stamp a timestamp anywhere by default. In practice teams track this themselves: log every REINDEX/CREATE INDEX CONCURRENTLY run (with the index name and timestamp) into their own ops audit table, since pg_stat_user_indexes only shows usage counters, not rebuild history. */

/* ============================================================
   SECTION D: AUTO-AUDIT SCRIPTS (25)
   ------------------------------------------------------------ */

/* Q76. */
SELECT n.nspname AS schema, c.relname AS table_name
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r' AND n.nspname NOT IN ('pg_catalog','information_schema')
AND NOT EXISTS (SELECT 1 FROM pg_constraint con WHERE con.conrelid = c.oid AND con.contype = 'p');

/* Q77. */
SELECT tc.table_schema, tc.table_name, kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
AND NOT EXISTS (
  SELECT 1 FROM pg_index ix
  JOIN pg_class c ON c.oid = ix.indrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
  JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = ix.indkey[0]
  WHERE n.nspname = tc.table_schema AND c.relname = tc.table_name AND a.attname = kcu.column_name
);

/* Q78. */
SELECT schemaname, relname, last_vacuum, last_autovacuum
FROM pg_stat_user_tables
WHERE GREATEST(last_vacuum, last_autovacuum) < now() - interval '30 days'
OR (last_vacuum IS NULL AND last_autovacuum IS NULL);

/* Q79. */
SELECT schemaname, relname, last_analyze, last_autoanalyze
FROM pg_stat_user_tables
WHERE GREATEST(last_analyze, last_autoanalyze) < now() - interval '7 days'
OR (last_analyze IS NULL AND last_autoanalyze IS NULL);

/* Q80. */
SELECT n.nspname AS schema, c.relname AS table_name, pg_size_pretty(pg_total_relation_size(c.oid)) AS size
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r' AND n.nspname NOT IN ('pg_catalog','information_schema')
ORDER BY pg_total_relation_size(c.oid) DESC
LIMIT 20;

/* Q81. This needs the pgstattuple extension for a real dead-space percentage. Pattern once enabled: SELECT relname, dead_tuple_percent FROM pgstattuple('schema.table') WHERE dead_tuple_percent > 30; run per table of interest (pgstattuple takes one relation at a time, so a full-database sweep needs a small wrapper function). */
/* Q82. This needs pg_stat_statements to know which indexes are actually queried by expensive statements; without it, use the proxy below (indexes over 1GB with zero scans since the last stats reset). */
SELECT n.nspname AS schema, c.relname AS index_name, pg_size_pretty(pg_relation_size(c.oid)) AS size
FROM pg_stat_user_indexes s
JOIN pg_class c ON c.oid = s.indexrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE s.idx_scan = 0 AND pg_relation_size(c.oid) > 1073741824;

/* Q83. */
SELECT schemaname, relname, seq_scan, idx_scan,
       round(seq_scan::numeric / NULLIF(seq_scan + idx_scan, 0), 4) AS seq_scan_ratio
FROM pg_stat_user_tables
WHERE seq_scan + idx_scan > 0
ORDER BY seq_scan_ratio DESC;

/* Q84. */
SELECT schemaname, relname, autovacuum_count, last_autovacuum
FROM pg_stat_user_tables
ORDER BY autovacuum_count DESC;

/* Q85. */
SELECT schemaname, relname, n_tup_upd + n_tup_del AS churn
FROM pg_stat_user_tables
ORDER BY churn DESC
LIMIT 20;

/* Q86. */
SELECT application_name, count(*) AS connections
FROM pg_stat_activity
GROUP BY application_name
ORDER BY connections DESC;

/* Q87. Needs pg_stat_statements. Pattern: SELECT query, calls, mean_exec_time FROM pg_stat_statements WHERE mean_exec_time > 1000 ORDER BY mean_exec_time DESC; (mean_exec_time is in milliseconds, so > 1000 means over 1 second). */
/* Q88. Needs pg_stat_statements. Pattern: SELECT query, calls, temp_blks_read + temp_blks_written AS temp_blocks FROM pg_stat_statements WHERE temp_blks_read > 0 OR temp_blks_written > 0 ORDER BY temp_blocks DESC; */
/* Q89. */
SELECT slot_name, active, restart_lsn
FROM pg_replication_slots;

/* Q90. */
SELECT schemaname, relname,
       round(heap_blks_hit::numeric / NULLIF(heap_blks_hit + heap_blks_read, 0), 4) AS cache_hit_ratio
FROM pg_statio_user_tables
WHERE round(heap_blks_hit::numeric / NULLIF(heap_blks_hit + heap_blks_read, 0), 4) < 0.95;

/* Q91. */
SELECT n.nspname AS schema, c.relname AS table_name, age(c.relfrozenxid) AS xid_age
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r' AND n.nspname NOT IN ('pg_catalog','information_schema')
ORDER BY xid_age DESC;

/* Q92. */
SELECT n.nspname AS schema, c.relname AS table_name, age(c.relfrozenxid) AS xid_age
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r' AND age(c.relfrozenxid) > 1000000000
ORDER BY xid_age DESC;

/* Q93. */
SELECT checkpoints_timed, checkpoints_req,
       round(checkpoints_req::numeric / NULLIF(checkpoints_timed + checkpoints_req, 0), 4) AS forced_ratio
FROM pg_stat_bgwriter;

/* Q94. Needs snapshotting WAL position over time (there's no single catalog column for "WAL volume in the last hour"). Pattern: capture SELECT pg_current_wal_lsn() every hour into a log table, then compute pg_wal_lsn_diff(current_lsn, previous_lsn) between consecutive snapshots to get bytes generated per hour. */
/* Q95. */
SELECT rolname FROM pg_roles WHERE rolsuper = true;

/* Q96. */
SELECT table_schema, table_name, privilege_type
FROM information_schema.table_privileges
WHERE grantee = 'PUBLIC';

/* Q97. */
SELECT table_schema, table_name, column_name
FROM information_schema.columns
WHERE is_nullable = 'NO'
ORDER BY table_schema, table_name;

/* Q98. */
SELECT 'sales.orders -> customers.customers' AS relationship, count(*) AS orphan_rows
FROM sales.orders o
WHERE o.cust_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM customers.customers c WHERE c.customer_id = o.cust_id)
UNION ALL
SELECT 'sales.order_items -> sales.orders', count(*)
FROM sales.order_items oi
WHERE oi.order_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sales.orders o WHERE o.order_id = oi.order_id);

/* Q99. */
SELECT extname, extversion FROM pg_extension ORDER BY extname;

/* Q100. */
SELECT
  (SELECT count(*) FROM pg_class WHERE relkind = 'r') AS total_tables,
  (SELECT count(*) FROM pg_class WHERE relkind = 'i') AS total_indexes,
  (SELECT count(*) FROM pg_class WHERE relkind = 'v') AS total_views,
  pg_size_pretty(pg_database_size(current_database())) AS db_size,
  (SELECT round(sum(blks_hit)::numeric / NULLIF(sum(blks_hit)+sum(blks_read),0),4) FROM pg_stat_database WHERE datname = current_database()) AS cache_hit_ratio,
  (SELECT count(*) FROM pg_stat_activity WHERE datname = current_database()) AS active_connections,
  (SELECT count(*) FROM pg_stat_user_tables WHERE n_dead_tup > 0) AS tables_with_dead_tuples,
  (SELECT count(*) FROM pg_stat_user_indexes WHERE idx_scan = 0) AS unused_indexes,
  (SELECT count(*) FROM pg_locks WHERE NOT granted) AS waiting_locks,
  (SELECT max(now() - query_start) FROM pg_stat_activity WHERE state = 'active') AS longest_active_query,
  (SELECT deadlocks FROM pg_stat_database WHERE datname = current_database()) AS deadlocks_since_reset,
  (SELECT max(age(relfrozenxid)) FROM pg_class WHERE relkind = 'r') AS oldest_xid_age;

/* ============================================================
   END OF ANSWER KEY - CRAZY LEVEL (100/100)
============================================================ */
