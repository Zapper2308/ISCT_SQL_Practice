/* ============================================================
   ANSWER KEY - Reading Query Plans (HARD LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1.  Run EXPLAIN ANALYZE, scan bottom-up for the node with the largest actual-time contribution, check that node's estimated vs actual rows for a big mismatch, look for a Seq/Nested-Loop/Sort-spill smell, fix the cheapest highest-leverage issue first, then re-run and repeat. */
/* Q2.  A wrong row estimate at one node feeds the next join's planning; if the planner thinks a join's input will be small it may choose a Nested Loop, and if the real input is far larger, that Nested Loop re-executes its inner scan far more times than planned, multiplying the error into a huge blowup. */
/* Q3.  "shared hit" means the page was already in shared_buffers (fast, no I/O); "shared read" means it was fetched from disk/OS cache (slower); "shared dirtied" means the node modified a page that must eventually be written back - high reads relative to hits signal a cold-cache, I/O-bound query. */
/* Q4.  A Seq Scan is optimal when the query needs most or all of a table's rows (a full aggregate, or a low-selectivity predicate matching a large fraction of rows) - sequential I/O beats the random I/O of chasing an index for that many matches. */
/* Q5.  EXPLAIN ANALYZE shows "Sort Method: external merge  Disk: NNkB" (instead of quicksort/Memory) for a spilled Sort, or "Batches: N" > 1 for a spilled Hash - both mean the operation exceeded work_mem and had to write/read temp files, which raising work_mem can eliminate. */
/* Q6.  "rows" is the average produced per single execution, but a node under a Nested Loop's inner side executes once per outer row ("loops"); the real total rows processed by that node across the whole query is rows multiplied by loops, not rows alone. */
/* Q7.  Without current statistics, the planner's row-count and distribution estimates are based on old (or default) assumptions, so it can pick the wrong join algorithm or scan type for the data's actual current size/shape - a fresh ANALYZE alone can fix this with no query change. */
/* Q8.  Parallelism helps a large Seq Scan/aggregate over millions of rows where each worker's slice is substantial; it doesn't help a query that's already fast, returns via a cheap Index Scan, or is dominated by a parallel-unsafe/serial operation where launching workers only adds overhead. */
/* Q9.  LIMIT changes what the planner optimizes for - the cost of producing just the first few rows quickly (favoring an Index Scan that can stop early) rather than the cost of producing the entire result set, which can flip the chosen scan/join strategy entirely. */
/* Q10. Run both with EXPLAIN ANALYZE (not just EXPLAIN) against a warm cache, run each more than once to smooth out noise from concurrent server activity, and compare actual time/rows rather than estimated cost alone. */
/* Q11. A Seq Scan on a large table whose filter shows a high "Rows Removed by Filter" relative to rows kept, or a Sort node that exists purely to satisfy an ORDER BY that an index could provide directly. */
/* Q12. The query already touches most of the table (low selectivity, so an index scan would visit almost as many rows as a Seq Scan anyway), or the bottleneck node is a full aggregate/sort over the whole result set rather than a filtered scan. */
/* Q13. Very selective predicates (few matching rows) favor a plain Index Scan; moderately selective ones (a meaningful fraction, but not most, of the table) favor a Bitmap Index/Heap Scan; low selectivity (most of the table matches) favors a Seq Scan. */
/* Q14. An Index Only Scan can answer a query straight from the index's own stored columns only if every column the query needs is in that index; SELECT * needs every column, forcing a heap visit for the rest and ruling that optimization out. */
/* Q15. For a small number of tables (up to join_collapse_limit / from_collapse_limit, default 8) the planner exhaustively evaluates join orders to find the cheapest; beyond that it switches to a cheaper heuristic (or the Genetic Query Optimizer), so very large joins may not get the truly optimal order. */
/* Q16. When the planner badly underestimates a subquery/join's row count as effectively 1 (common with correlated subqueries or poorly-estimated filters), it picks a Nested Loop expecting to run the inner side just once or a few times - if the real count is thousands, that "cheap" choice becomes the bottleneck. */
/* Q17. A materialized CTE (forced, or auto-materialized because it's referenced multiple times) computes its full result before any outer predicate can be pushed into it; PG12+'s auto-inlining for singly-referenced CTEs removes this fence in that common case, but a MATERIALIZED CTE still fences deliberately. */
/* Q18. A Materialize node under a Nested Loop's inner side means PostgreSQL buffered that inner input's first pass so subsequent loops re-read it from memory instead of re-executing it - a sign the inner side isn't cheaply index-backed, so the planner is caching it to avoid repeating expensive work. */
/* Q19. Both are extremely common in hand-written analyst SQL (searching "contains X", filtering on UPPER(email) or EXTRACT(YEAR FROM date)) and both silently defeat a plain B-tree index, turning what looks like a simple filter into a full-table Seq Scan. */
/* Q20. When the number of distinct groups (and their accumulated state) exceeds work_mem, HashAggregate spills partial results to disk; the symptom in EXPLAIN ANALYZE (PG13+) is "Disk Usage: NNkB" reported on the HashAggregate node. */
/* Q21. The plan shows a Nested Loop (often with no join filter at all) whose row count is roughly the product of its two inputs' row counts (rows(A) x rows(B)) rather than anything close to either input alone - a telltale sign of a missing join condition. */
/* Q22. A rewrite (sargable predicate, trimmed projection, JOIN instead of correlated subquery) often removes the actual inefficiency for free and helps every future query with the same pattern, whereas an index is a standing cost (storage, write overhead) that may only serve one query shape. */
/* Q23. FORMAT JSON gives a machine-parseable plan tree, VERBOSE adds fully-qualified column/table names and output lists, BUFFERS adds I/O counters, and ANALYZE adds real timings - together they give an automated tool everything it needs to compute cost/row/I/O breakdowns without a human reading text output. */
/* Q24. Plan regression is when the same query starts using a worse plan than before (due to data growth, stale stats, a parameter value change, or a config change) even though the SQL text didn't change; you catch it by keeping a baseline EXPLAIN ANALYZE (or pg_stat_statements history) to compare against and alerting when actual time jumps. */
/* Q25. Before writing an index request: run EXPLAIN ANALYZE and read bottom-up for the costliest/slowest node; check for non-sargable predicates, unnecessary SELECT *, and missing LIMITs; replace correlated subqueries, OR-across-columns and NOT IN with JOINs/UNION ALL/NOT EXISTS where applicable; re-run ANALYZE if statistics look stale; only then recommend a specific index for Day 20. */

/* ============================================================
   SECTION B: PLAN FORENSICS (25)
   ------------------------------------------------------------ */
/* Q26. */
EXPLAIN ANALYZE
SELECT c.customer_id, c.tier,
       COALESCE(o.orders, 0) AS orders, COALESCE(o.spend, 0) AS spend,
       COALESCE(r.reviews, 0) AS reviews, COALESCE(t.tickets, 0) AS tickets
FROM customers.customers c
LEFT JOIN (SELECT cust_id, COUNT(*) AS orders, SUM(net_total) AS spend FROM sales.orders GROUP BY cust_id) o ON o.cust_id = c.customer_id
LEFT JOIN (SELECT customer_id, COUNT(*) AS reviews FROM customers.reviews GROUP BY customer_id) r ON r.customer_id = c.customer_id
LEFT JOIN (SELECT customer_id, COUNT(*) AS tickets FROM support.tickets GROUP BY customer_id) t ON t.customer_id = c.customer_id;

/* Q27. */
EXPLAIN ANALYZE
SELECT o.order_id, p.product_name, c.first_name
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN customers.customers c ON c.customer_id = o.cust_id
WHERE o.order_status = 'Delivered';

/* Q28. */
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM sales.orders WHERE net_total > 80000;

/* Q29. */
EXPLAIN ANALYZE SELECT * FROM sales.orders ORDER BY net_total, order_date, cust_id;

/* Q30. */
EXPLAIN ANALYZE SELECT o.order_id, oi.quantity FROM sales.orders o JOIN sales.order_items oi ON oi.order_id = o.order_id;

/* Q31. */
EXPLAIN ANALYZE
SELECT o.order_id FROM (SELECT * FROM sales.orders ORDER BY order_id LIMIT 200) o
WHERE EXISTS (SELECT 1 FROM sales.order_items oi WHERE oi.order_id = o.order_id AND oi.quantity > 0);

/* Q32. */
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE order_status = 'Failed';

/* Q33. */
EXPLAIN ANALYZE SELECT * FROM sales.orders ORDER BY order_id LIMIT 20;

/* Q34. */
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE order_id = 42;

/* Q35. */
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE order_status IN ('Delivered', 'Shipped', 'Processing');

/* Q36. */
EXPLAIN ANALYZE SELECT COUNT(*) FROM web_events.page_views;

/* Q37. */
EXPLAIN ANALYZE
SELECT o.order_id, r.reason FROM sales.orders o
JOIN sales.returns r ON r.order_id = o.order_id AND r.refund_amount > 50;

/* Q38. Extracting the most expensive subtree from a JSON plan programmatically means recursively walking the "Plans" array of each node, comparing each node's own "Total Cost" (or, for EXPLAIN ANALYZE, "Actual Total Time" x "Actual Loops") minus its children's costs, and keeping the node with the largest self-cost - exactly what a plan-visualizer tool automates instead of eyeballing indentation. */

/* Q39. */
EXPLAIN ANALYZE
SELECT o.order_id, (SELECT COUNT(*) FROM sales.returns r WHERE r.order_id = o.order_id) AS return_count
FROM (SELECT * FROM sales.orders ORDER BY order_id LIMIT 200) o;

/* Q40. */
EXPLAIN SELECT cust_id, COUNT(*) FROM sales.orders GROUP BY cust_id ORDER BY cust_id;

/* Q41. */
EXPLAIN ANALYZE SELECT * FROM sales.orders ORDER BY order_id OFFSET 140000 LIMIT 20;

/* Q42. */
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE order_id BETWEEN 1 AND 5000;

/* Q43. */
EXPLAIN SELECT * FROM sales.orders o, sales.order_items oi, products.products p WHERE o.order_id = oi.order_id;

/* Q44. */
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM sales.orders WHERE cust_id = 777;

/* Q45. */
EXPLAIN ANALYZE
SELECT o.order_id, oi.quantity, p.product_name
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
JOIN products.products p ON p.product_id = oi.prod_id
WHERE o.order_status = 'Cancelled';

/* Q46. */
EXPLAIN ANALYZE SELECT cust_id, array_agg(order_id) FROM sales.orders GROUP BY cust_id;

/* Q47. */
EXPLAIN ANALYZE
SELECT o.cust_id, SUM(oi.net_amount) FROM sales.orders o JOIN sales.order_items oi ON oi.order_id = o.order_id GROUP BY o.cust_id;

/* Q48. */
EXPLAIN ANALYZE
SELECT o.order_id, c.first_name FROM sales.orders o JOIN customers.customers c ON c.customer_id = o.cust_id LIMIT 10;

/* Q49. */
EXPLAIN SELECT * FROM (SELECT * FROM sales.orders ORDER BY order_id) sub ORDER BY order_id;

/* Q50. */
EXPLAIN ANALYZE
SELECT o.order_id, p.product_name, c.first_name, s.store_name, r.region_name
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN customers.customers c ON c.customer_id = o.cust_id
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id;

/* ============================================================
   SECTION C: REWRITES THAT CHANGE THE PLAN (25)
   ------------------------------------------------------------ */
/* Q51. */
EXPLAIN ANALYZE
SELECT o.order_id FROM sales.orders o
JOIN (SELECT cust_id, AVG(net_total) AS avg_total FROM sales.orders GROUP BY cust_id) a ON a.cust_id = o.cust_id
WHERE o.net_total > a.avg_total;

/* Q52. */
EXPLAIN ANALYZE
SELECT * FROM sales.orders WHERE order_status = 'Cancelled'
UNION ALL
SELECT * FROM sales.orders WHERE payment_mode_id = 1 AND order_status <> 'Cancelled';

/* Q53. */
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE order_date >= DATE '2025-01-01' AND order_date < DATE '2026-01-01';

/* Q54. */
EXPLAIN ANALYZE
SELECT c.customer_id FROM customers.customers c
WHERE NOT EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id);

/* Q55. */
EXPLAIN ANALYZE SELECT order_id FROM sales.orders WHERE order_id BETWEEN 1 AND 2000;

/* Q56. */
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE order_id > 140000 ORDER BY order_id LIMIT 20;

/* Q57. */
EXPLAIN ANALYZE
SELECT o.order_id, o.net_total FROM sales.orders o
WHERE EXISTS (SELECT 1 FROM sales.order_items oi WHERE oi.order_id = o.order_id);

/* Q58. */
EXPLAIN ANALYZE
WITH item_totals AS (SELECT order_id, SUM(quantity) AS total_qty FROM sales.order_items GROUP BY order_id)
SELECT o.order_id, t.total_qty FROM sales.orders o JOIN item_totals t ON t.order_id = o.order_id;

/* Q59. */
EXPLAIN ANALYZE
SELECT o.order_id, oi.quantity
FROM (SELECT * FROM sales.orders WHERE order_status = 'Delivered') o
JOIN sales.order_items oi ON oi.order_id = o.order_id;

/* Q60. */
EXPLAIN ANALYZE SELECT * FROM products.products TABLESAMPLE BERNOULLI (5) LIMIT 20;

/* Q61. */
EXPLAIN ANALYZE
SELECT o.* FROM sales.orders o JOIN (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10)) AS v(store_id) ON v.store_id = o.store_id;

/* Q62. */
EXPLAIN ANALYZE
SELECT cust_id, order_id, net_total,
       LAG(net_total) OVER (PARTITION BY cust_id ORDER BY order_date) AS prev_net_total
FROM sales.orders;

/* Q63. */
EXPLAIN ANALYZE SELECT * FROM customers.customers WHERE email LIKE 'j%';

/* Q64. */
EXPLAIN ANALYZE SELECT cust_id, COUNT(*) FROM sales.orders WHERE order_status <> 'Cancelled' GROUP BY cust_id;

/* Q65. */
EXPLAIN ANALYZE
SELECT * FROM sales.orders WHERE cust_id = 100
UNION ALL
SELECT * FROM sales.orders WHERE store_id = 5 AND cust_id <> 100;

/* Q66. */
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE order_date >= DATE '2025-03-01' AND order_date < DATE '2025-04-01';

/* Q67. */
EXPLAIN ANALYZE SELECT * FROM customers.customers WHERE first_name ILIKE '%an%' OR last_name ILIKE '%an%';

/* Q68. */
EXPLAIN ANALYZE
SELECT o.order_id FROM sales.orders o
WHERE EXISTS (SELECT 1 FROM sales.returns r WHERE r.order_id = o.order_id);

/* Q69. */
EXPLAIN ANALYZE
WITH item_totals AS (SELECT order_id, SUM(net_amount) AS items_total FROM sales.order_items GROUP BY order_id)
SELECT o.order_id, o.cust_id, t.items_total FROM sales.orders o JOIN item_totals t ON t.order_id = o.order_id;

/* Q70. */
EXPLAIN ANALYZE
WITH cust_spend AS MATERIALIZED (SELECT cust_id, SUM(net_total) AS total_spend FROM sales.orders GROUP BY cust_id)
SELECT a.cust_id, a.total_spend FROM cust_spend a WHERE a.total_spend > (SELECT AVG(total_spend) FROM cust_spend);

/* Q71. */
EXPLAIN ANALYZE
SELECT c.customer_id, COALESCE(r.review_count, 0) AS review_count
FROM customers.customers c
LEFT JOIN (SELECT customer_id, COUNT(*) AS review_count FROM customers.reviews GROUP BY customer_id) r ON r.customer_id = c.customer_id;

/* Q72. */
EXPLAIN ANALYZE
WITH distinct_products AS (
  SELECT DISTINCT o.cust_id, oi.prod_id FROM sales.order_items oi JOIN sales.orders o ON o.order_id = oi.order_id
)
SELECT cust_id, COUNT(*) AS distinct_products_bought FROM distinct_products GROUP BY cust_id;

/* Q73. */
EXPLAIN ANALYZE
WITH ranked AS (
  SELECT cust_id, order_id, net_total, ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY net_total DESC) AS rn
  FROM sales.orders
)
SELECT * FROM ranked WHERE rn <= 3;

/* Q74. */
EXPLAIN ANALYZE SELECT order_id, net_total FROM sales.orders ORDER BY net_total DESC;

/* Q75. */
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE order_date >= DATE '2025-01-01' AND order_date < DATE '2026-01-01';

/* ============================================================
   SECTION D: "WOULD AN INDEX HELP?" (diagnosis only - fix is Day 20) (25)
   ------------------------------------------------------------ */
/* Q76. Yes - EXPLAIN would show a Seq Scan on customers.customers filtering on email, since there's no index on that column; a point lookup (equality on essentially one row) is exactly the selective case a B-tree index is built for, so adding one (Day 20) would turn that Seq Scan into a fast Index Scan. */
/* Q77. Yes, if the range is a small fraction of the table's date span (e.g. one month out of roughly two years of data) - a B-tree index on order_date lets the planner jump straight to that range instead of scanning all 150,000 rows. */
/* Q78. No - the query must read every row to sum them regardless of any index, so an index on net_total (or anything else) can't reduce the amount of data visited; only an Index Only Scan avoids heap visits, and even then every row is still touched by the aggregate. */
/* Q79. The columns in both predicates together, with the more selective/most commonly equality-filtered column first - e.g. (cust_id, order_date) for "orders for this customer in this date range" - so the index narrows on both conditions in one lookup. */
/* Q80. Yes, if 'Cancelled' is a small minority of rows (roughly 1 of 7 order_status values here) and queries specifically and repeatedly filter on that status - a partial index stays small and fast for that narrow slice without indexing rows nobody filters that way. */
/* Q81. Yes - a B-tree index on net_total (DESC) would let the planner walk the index in already-sorted order and stop after 10 rows, avoiding a full Sort of the whole table. */
/* Q82. Yes - a plain B-tree can't help a '%text%' search at all; a pg_trgm GIN/GIST trigram index is the standard PostgreSQL tool that can accelerate arbitrary substring search (Day 20/extension). */
/* Q83. Yes if the app frequently filters WHERE lower(email) = ... (case-insensitive lookup) - a plain index on email can't help that predicate, but an expression index built ON (lower(email)) matches it exactly. */
/* Q84. Two indexes where one's leading columns are a prefix of the other's (e.g. an index on (cust_id) and another on (cust_id, order_date)) are redundant - the narrower one adds write/storage overhead while rarely being chosen over the wider one, which can already serve cust_id-only queries too. */
/* Q85. Yes - sales.orders.cust_id has no secondary index (only customers.customer_id, the PK it references, is indexed), so a join filtering or driving off cust_id falls back to a Seq Scan feeding a Hash Join rather than an Index/Nested Loop path. */
/* Q86. Yes - if a predicate matches most of the table (e.g. order_status <> 'Cancelled', which is 6 of 7 statuses), an index scan would still have to visit almost every row via random I/O, which is slower than just reading the table sequentially. */
/* Q87. As a rule of thumb, once a predicate matches more than roughly 5-10% of a table's rows, the random I/O of an index scan tends to cost more than a sequential scan of the whole table, so an index is worthwhile mainly below that selectivity threshold. */
/* Q88. Yes - adding the extra columns a query SELECTs (that aren't part of the search key) via INCLUDE lets the whole query be answered from the index alone, without a heap visit, as long as the table's visibility map marks those pages all-visible. */
/* Q89. A composite index on (cust_id, order_date) serves a query that filters on both together far better than two single-column indexes, since the composite narrows to exactly the matching rows in one lookup instead of requiring a BitmapAnd of two separate scans. */
/* Q90. Yes - BRIN indexes are ideal for large, naturally-ordered append-only columns like a monotonically increasing view_timestamp, since they're tiny (per-block min/max ranges) and work well when physical insert order correlates with the column's value. */
/* Q91. Usually not - GROUP BY still has to touch and aggregate every row in the table (or every row matching an earlier filter), so an index on the grouping column rarely reduces that work unless it also lets the planner skip a Sort by delivering rows pre-ordered by that key. */
/* Q92. Yes, generally - PostgreSQL does NOT automatically index foreign-key columns (unlike the primary key they reference), so a table frequently joined or filtered on its FK column (e.g. sales.orders.cust_id) benefits from an explicit index on that column. */
/* Q93. The one whose EXPLAIN ANALYZE shows a highly selective predicate (few matching rows) currently served by a Seq Scan with a large "Rows Removed by Filter" - that's the pattern an index turns from a full scan into a handful of targeted lookups. */
/* Q94. Sometimes - if the scan strategy is fine but the planner is choosing a bad join order/algorithm due to stale or correlated-column misestimates, refreshing ANALYZE (or adding CREATE STATISTICS for correlated columns) can fix the plan at zero storage cost, before reaching for an index. */
/* Q95. Yes, generally - a non-sargable predicate, SELECT *, or an avoidable correlated subquery can make even a well-indexed query slow, so fixing the query shape first (free) often removes the need for an index entirely or clarifies which index would actually help. */
/* Q96. Every index on a table must be updated on every INSERT/UPDATE/DELETE touching its columns, so a table with heavy write traffic (e.g. sales.orders at 150,000+ rows and growing) pays an ongoing write-amplification and storage cost per index, weighed against how much read time it saves. */
/* Q97. Yes - if queries almost always filter to a small "active" subset (e.g. WHERE order_status NOT IN ('Cancelled','Returned')) and also need a few extra columns, a partial index scoped to that condition with those columns as INCLUDE gives the smallest index that still avoids heap visits. */
/* Q98. Rank by (how often the query runs) x (its current cost/time) x (how selective its predicate is and how cleanly a single index could serve it) - a frequent, currently-slow query with one clear selective predicate ranks highest; a rare, already-fast, or low-selectivity query ranks lowest. */
/* Q99. Recommend a B-tree index on sales.orders(cust_id) to support the customer-scoped filter/join this report relies on, since EXPLAIN ANALYZE shows that predicate currently forcing a full Seq Scan with a large fraction of rows removed by the filter - to be created and measured in Day 20. */
/* Q100. Bottleneck: the Seq Scan/Nested Loop combination identified via EXPLAIN ANALYZE as the highest actual-time node; rewrites tried: sargable predicates, trimmed projection, JOIN instead of correlated subquery, pre-aggregation CTEs - each re-measured; remaining recommendation for Day 20: a B-tree (or composite/partial, as diagnosed above) index on the still-Seq-Scanned selective filter/join column, validated with a fresh EXPLAIN ANALYZE once created. */

/* ============================================================
   END OF Reading Query Plans - HARD LEVEL (100 QUESTIONS)
============================================================ */
