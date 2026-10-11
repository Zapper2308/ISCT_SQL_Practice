/* ============================================================
   ANSWER KEY - Reading Query Plans (CRAZY LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1.  The parser turns SQL text into a query tree, the planner explores possible execution strategies (scan types, join order/algorithm) and picks the cheapest by its cost model, then the executor runs that chosen plan node-by-node - EXPLAIN prints the plan the planner picked (and, with ANALYZE, lets the executor actually run it while it reports back real numbers). */
/* Q2.  seq_page_cost and random_page_cost set the assumed cost of sequential vs random disk-page reads (random is pricier by default, favoring index scans for selective predicates); cpu_tuple_cost/cpu_index_tuple_cost/cpu_operator_cost price the CPU work per row/index-entry/expression evaluation - the planner sums these across a candidate plan to get its total estimated cost. */
/* Q3.  effective_cache_size tells the planner how much RAM (shared_buffers plus OS cache) is realistically available for caching data; a higher value makes random-access index scans look cheaper (since repeat reads are assumed likely to hit cache), nudging the planner toward indexes over sequential scans. */
/* Q4.  Each join's row-count estimate is built from its inputs' estimates, so an error at the first join doesn't stay contained - it multiplies through every subsequent join's estimate, meaning a 5-table join's final estimate can be wildly wrong even from one bad starting assumption. */
/* Q5.  join_collapse_limit/from_collapse_limit cap how many tables the planner will exhaustively try every join order for (default 8); a large join with more tables than that switches to a cheaper heuristic (or GEQO), which may not find the truly optimal order. */
/* Q6.  The planner stops exhaustively trying every join order once the number of joined relations exceeds join_collapse_limit/from_collapse_limit (or geqo_threshold, where it switches to the Genetic Query Optimizer); you can influence it by raising those settings, or by writing explicit JOIN syntax/parentheses to hint an order. */
/* Q7.  work_mem applies per sort/hash-type operation node (not once per query), so a query with several such nodes running concurrently - and multiplied again by parallel workers - can use several times work_mem in total memory, which is why raising it globally must be done cautiously on a busy server. */
/* Q8.  A Hash spill shows as "Batches > 1" on a Hash node (the build side didn't fit work_mem and was partitioned to disk); a Sort spill shows as "Sort Method: external merge  Disk: NNkB" - both are diagnosed the same way (EXPLAIN ANALYZE) and both are relieved by more work_mem or a smaller row set feeding the operation. */
/* Q9.  Gather/Gather Merge helps when a scan or aggregate over a large table can be split into independent chunks worth more than the fixed cost of launching workers; it's blocked by parallel-unsafe operations - functions not marked PARALLEL SAFE, certain window functions, or operations that must see the whole result serially. */
/* Q10. GEQO (Genetic Query Optimizer) kicks in automatically for joins above geqo_threshold tables, using a randomized/heuristic search instead of exhaustive enumeration - it trades a guarantee of finding the optimal join order for planning time that stays reasonable as the number of tables grows. */
/* Q11. CREATE STATISTICS (extended statistics) is needed when two or more columns are correlated in a way the planner's per-column statistics can't capture (e.g. city and state are correlated, so filtering both together doesn't multiply their selectivities independently) - without it the combined-predicate row estimate can be badly wrong. */
/* Q12. If the planner estimates a join on a foreign key will match very few rows (skewed low) but the real data has heavy duplication on that key, it may pick a Nested Loop expecting a handful of inner-side probes, then the actual data forces thousands of probes - the classic estimate-skew nested-loop catastrophe. */
/* Q13. The "same" query can flip plans because table sizes grow, the data's value distribution changes (skewing selectivity), ANALYZE runs and updates statistics, a bind parameter's value changes what a custom plan looks like, or a Postgres/config upgrade changes cost constants or planner behavior. */
/* Q14. A materialized CTE fences the optimizer (fully computes before any outer predicate reaches it); since PG12, a CTE referenced exactly once with no side effects is auto-inlined like a subquery instead, removing the fence - MATERIALIZED/NOT MATERIALIZED let you force either behavior explicitly. */
/* Q15. An Index Only Scan needs every column the query touches to be present in the index itself (a "covering" index, possibly via INCLUDE), and it needs the relevant heap pages marked all-visible in the visibility map (recently VACUUMed) - otherwise it must still visit the heap to check row visibility. */
/* Q16. The planner can combine multiple single-column indexes with a BitmapAnd (AND of two conditions) or BitmapOr (OR of two conditions) when no single composite index covers the combined predicate but each condition has its own useful index and the combined selectivity still looks cheap enough. */
/* Q17. LATERAL with a per-group LIMIT (top-N-per-group) tends to plan as a Nested Loop that stops early per group, which can beat a window-function ROW_NUMBER() approach when the number of groups is small and each group's inner query is cheaply index-backed; the window approach instead sorts/partitions the whole input once, which can win when there's no useful per-group index. */
/* Q18. On a partitioned table, EXPLAIN shows which child partitions were actually scanned (partition pruning) - a well-pruned plan lists only the partitions matching the WHERE clause's partition key, while a poorly-pruned one shows every partition being scanned regardless of the filter. */
/* Q19. A tiny LIMIT shifts the planner's cost model toward minimizing startup cost (time to the first row) rather than total cost, so it may choose a plan with a cheap start but an expensive full scan if run to completion - fine for the LIMIT case, but a bad choice if that same plan were reused without the LIMIT. */
/* Q20. auto_explain automatically logs the plan (optionally with ANALYZE/BUFFERS) for any query exceeding a configured duration threshold, and pg_stat_statements aggregates timing/row/call statistics per normalized query text across all executions - together they catch slow queries in production without a human running EXPLAIN by hand (neither extension is installed in this teaching database). */
/* Q21. A "parallel-aware" node (e.g. Parallel Seq Scan) actively divides its own work across the launched workers; a "parallel-restricted" (non-parallel-aware) node above it, like the Gather itself or a HashAggregate finalizing partial results, runs once per worker's output but doesn't itself split further. */
/* Q22. The planner's cost is a model based on statistics and fixed constants, not a real timer - it can systematically misjudge cases like heavily correlated columns, unusual data skew, or expensive user-defined functions whose actual CPU cost isn't reflected in cpu_operator_cost, so estimated cost and actual time can diverge even with fresh statistics. */
/* Q23. Push work to a materialized view when the same expensive aggregate is read far more often than the underlying data changes and some staleness is acceptable; keep tuning the live query when freshness must be exact or the query pattern varies too much for one precomputed shape to serve everyone. */
/* Q24. A repeatable benchmark runs the same query multiple times with EXPLAIN (ANALYZE, BUFFERS) after a warm-up pass to eliminate cold-cache noise, on data of a known/fixed size, and records both estimated and actual figures each run so a later regression can be compared against this recorded baseline. */
/* Q25. In 60 seconds: read bottom-up for the node with the largest actual time; check its estimated-vs-actual row gap; note its scan type (Seq/Index/Bitmap) and whether that matches the predicate's real selectivity; note the join algorithm and loop counts one level up; and check for BUFFERS reads or spill (external merge/Batches>1) before concluding what the single biggest fix would be. */

/* ============================================================
   SECTION B: MULTI-JOIN FORENSICS (25)
   ------------------------------------------------------------ */
/* Q26. */
EXPLAIN ANALYZE
SELECT o.order_id, p.product_name, c.first_name, s.store_name, r.region_name, cat.category_name
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
JOIN customers.customers c ON c.customer_id = o.cust_id
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
WHERE o.order_status = 'Delivered';

/* Q27. */
EXPLAIN ANALYZE
SELECT o.order_id, p.product_name, c.first_name, s.store_name
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN customers.customers c ON c.customer_id = o.cust_id
JOIN stores.stores s ON s.store_id = o.store_id;

/* Q28. */
EXPLAIN ANALYZE
SELECT o.order_id FROM (SELECT * FROM sales.orders ORDER BY order_id LIMIT 200) o
WHERE o.net_total > (SELECT AVG(net_total) FROM sales.orders o2 WHERE o2.cust_id = o.cust_id);

/* Q29. */
EXPLAIN ANALYZE SELECT cust_id, array_agg(DISTINCT order_id) FROM sales.orders GROUP BY cust_id;

/* Q30. */
EXPLAIN ANALYZE SELECT * FROM sales.orders ORDER BY net_total, order_date, store_id, cust_id;

/* Q31. */
EXPLAIN ANALYZE
SELECT o.order_id, (SELECT COUNT(*) FROM sales.returns r WHERE r.order_id = o.order_id) AS return_count
FROM (SELECT * FROM sales.orders ORDER BY order_id LIMIT 300) o;

/* Q32. */
EXPLAIN SELECT * FROM sales.orders o, sales.order_items oi, products.products p, core.dim_brand b WHERE o.order_id = oi.order_id;

/* Q33. */
EXPLAIN ANALYZE
SELECT o.order_id, p.product_name, c.first_name
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN customers.customers c ON c.customer_id = o.cust_id
WHERE o.order_status = 'Cancelled';

/* Q34. */
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE order_id BETWEEN 1 AND 5000;

/* Q35. */
EXPLAIN ANALYZE SELECT COUNT(*), AVG(net_total) FROM sales.orders;

/* Q36. */
EXPLAIN ANALYZE
SELECT o.order_id, oi.quantity FROM sales.orders o JOIN sales.order_items oi ON oi.order_id = o.order_id;

/* Q37. */
EXPLAIN (ANALYZE, BUFFERS)
SELECT o.order_id, p.product_name, c.first_name
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN customers.customers c ON c.customer_id = o.cust_id;

/* Q38. */
EXPLAIN ANALYZE
SELECT o.order_id, p.product_name, c.first_name, s.store_name
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN customers.customers c ON c.customer_id = o.cust_id
JOIN stores.stores s ON s.store_id = o.store_id;

/* Q39. */
EXPLAIN ANALYZE
SELECT cust_id, order_id, net_total,
       LAG(net_total) OVER (PARTITION BY cust_id ORDER BY order_date) AS prev_net_total
FROM sales.orders;

/* Q40. */
EXPLAIN ANALYZE SELECT cust_id, COUNT(*) FROM sales.orders GROUP BY cust_id HAVING COUNT(*) > 3;

/* Q41. */
EXPLAIN ANALYZE
SELECT DISTINCT o.order_id, o.net_total FROM sales.orders o JOIN sales.order_items oi ON oi.order_id = o.order_id;

/* Q42. */
EXPLAIN ANALYZE
WITH ranked AS (
  SELECT cust_id, order_id, net_total, ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY net_total DESC) AS rn
  FROM sales.orders
)
SELECT * FROM ranked WHERE rn <= 5;

/* Q43. */
EXPLAIN ANALYZE
SELECT cust_id, COUNT(*) FILTER (WHERE order_status = 'Delivered') AS delivered,
       COUNT(*) FILTER (WHERE order_status = 'Cancelled') AS cancelled
FROM sales.orders GROUP BY cust_id;

/* Q44. */
EXPLAIN ANALYZE SELECT * FROM sales.orders ORDER BY order_id OFFSET 140000 LIMIT 20;

/* Q45. */
EXPLAIN SELECT * FROM stores.stores s, sales.orders o WHERE s.store_id = o.store_id;

/* Q46. */
EXPLAIN ANALYZE
SELECT c.customer_id, p.product_name, o.order_id
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
JOIN sales.order_items oi ON oi.order_id = o.order_id
JOIN products.products p ON p.product_id = oi.prod_id
WHERE c.tier = 'Platinum';

/* Q47. */
EXPLAIN ANALYZE SELECT cust_id, array_agg(order_id ORDER BY net_total DESC) FROM sales.orders GROUP BY cust_id;

/* Q48. */
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE order_status = 'Cancelled' AND UPPER(order_status) = 'CANCELLED';

/* Q49. */
EXPLAIN ANALYZE
SELECT o.order_id, c.first_name FROM sales.orders o JOIN customers.customers c ON c.customer_id = o.cust_id;

/* Q50. */
EXPLAIN ANALYZE
SELECT o.order_id, p.product_name, c.first_name, s.store_name, r.region_name, cat.category_name
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
JOIN customers.customers c ON c.customer_id = o.cust_id
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id;

/* ============================================================
   SECTION C: PLAN STABILITY & REGRESSION (25)
   ------------------------------------------------------------ */
/* Q51. Likely causes, ranked without touching the query: (1) stale planner statistics after heavy recent writes - re-run ANALYZE first; (2) data growth/skew changing a predicate's real selectivity since the last good plan; (3) a parameter value (if parameterized/prepared) now hitting a different, worse generic vs custom plan; each is checked by comparing today's EXPLAIN ANALYZE against a saved baseline. */
/* Q52. */
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE order_status = 'Delivered';
/* Q53. */
ANALYZE sales.orders;
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE order_status = 'Delivered';
/* Q54. */
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE order_date >= DATE '2025-01-01' AND order_date < DATE '2025-02-01';
/* Q55. A generic plan is built once from a parameterized statement's estimated (average-case) parameter value and reused for every execution; a custom plan is re-planned for each specific bound value - PostgreSQL only switches to caching the generic plan after several executions show it isn't meaningfully worse than the custom ones, so a skewed parameter value early on can pick a plan that's wrong for later, more typical values. */
/* Q56. */
EXPLAIN ANALYZE SELECT * FROM sales.orders ORDER BY net_total DESC LIMIT 5;
/* Q57. Extended statistics (CREATE STATISTICS ... (dependencies, ndistinct) ON col_a, col_b FROM tbl) tell the planner how two or more columns' values correlate, fixing cases (diagnose only here) where a combined WHERE col_a = x AND col_b = y is far more (or less) selective than multiplying each column's independent selectivity would suggest. */
/* Q58. */
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM sales.orders WHERE cust_id = 250;
/* Q59. A plan tuned against a small filtered slice (e.g. one store's orders) can look completely different, and be far worse, once applied to the full unfiltered table - always benchmark against a representative overall data volume, not just a convenient small subset. */
/* Q60. */
EXPLAIN ANALYZE
WITH cust_spend AS NOT MATERIALIZED (SELECT cust_id, SUM(net_total) AS total_spend FROM sales.orders GROUP BY cust_id)
SELECT * FROM cust_spend WHERE total_spend > 50000;
/* Q61. */
EXPLAIN ANALYZE SELECT * FROM sales.orders ORDER BY order_id LIMIT 10;
/* Q62. join_collapse_limit (default 8) caps how many explicitly JOINed tables the planner will exhaustively reorder; a many-table plan with more joins than that falls back to a cheaper heuristic search (or respects the written JOIN order more literally), which can miss a cheaper reordering that exhaustive search would have found. */
/* Q63. A row-estimate cliff happens right at a boundary value (e.g. a date range that just crosses into a month with very different order volume) - the planner's histogram-bucket estimate can jump sharply there, flipping the chosen plan even though the query text barely changed. */
/* Q64. */
EXPLAIN ANALYZE SELECT * FROM sales.orders ORDER BY net_total, order_date, cust_id, store_id;
/* Q65. A minimal repro fixes everything except the one variable under test - same session settings, same warm cache (run once to warm, then measure), same data snapshot - and runs EXPLAIN (ANALYZE, BUFFERS) several times, comparing medians rather than single runs, so noise from concurrent server activity doesn't get mistaken for a real difference. */
/* Q66. */
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE cust_id = 999;
/* Q67. A plan built around typical mid-month order volume can regress at month-end if volume spikes (e.g. end-of-quarter promotions) push a previously-safe Nested Loop's inner side far past its expected row count, or push a Sort past work_mem into a disk spill it never hit on a normal day. */
/* Q68. If a function used in a predicate is reclassified from IMMUTABLE/STABLE to VOLATILE (or a user redefines it that way), the planner must re-evaluate it for every row instead of once, and may lose eligibility for certain optimizations (like index usage or constant-folding) that assumed a stable result. */
/* Q69. */
EXPLAIN ANALYZE SELECT order_id FROM sales.orders WHERE order_id BETWEEN 1 AND 1000;
/* Q70. When a low-cardinality column gets a new, previously-rare value that suddenly becomes common (or vice versa), the planner's most-common-values (MCV) list - built from a past ANALYZE - no longer reflects reality, so its selectivity estimate for that value can be badly off until the next ANALYZE. */
/* Q71. */
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE order_date >= DATE '2024-01-01' AND order_date < DATE '2024-02-01';
/* Q72. A plan that assumes a foreign key is always populated, or that a status column only ever holds today's known values, can break silently once new NULLs or new status values appear in the data - the estimate for "how many rows match" was implicitly tied to an assumption about the domain of values that has since changed. */
/* Q73. A "good plan" baseline is a saved EXPLAIN (ANALYZE, BUFFERS) output (plus the query text, data volume, and date it was captured) kept alongside the query, so a future run's plan/timing can be diffed against it to catch a real regression rather than relying on someone's memory of "it used to be fast". */
/* Q74. */
SET enable_seqscan = off;
EXPLAIN SELECT * FROM sales.orders WHERE order_id = 500;
RESET enable_seqscan;
/* Q75. Regression-watch note: query = customer order lookup by cust_id; baseline plan = Seq Scan over sales.orders (no index on cust_id), ~150,000 rows scanned, actual time recorded from today's EXPLAIN ANALYZE; triggers to watch = table growth changing that scan's actual time meaningfully, or a future index on cust_id that should flip this to an Index Scan (re-verify then). */

/* ============================================================
   SECTION D: END-TO-END TUNING METHODOLOGY (25)
   ------------------------------------------------------------ */
/* Q76. Full tuning report for the revenue dashboard: diagnose (EXPLAIN ANALYZE identifies the top-3 costliest nodes - typically a Seq Scan feeding a join, plus a Sort/Aggregate); rewrite (sargable predicates, trimmed projection, pre-aggregating the fan-out side in a CTE, re-measured after each change); index recommendation for Day 20 (a composite index on the join/filter columns still showing a Seq Scan after all rewrites). */
/* Q77. */
EXPLAIN (ANALYZE, BUFFERS)
SELECT r.region_name, SUM(o.net_total) AS revenue
FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name;
/* Q78. */
EXPLAIN ANALYZE
WITH region_rev AS (
  SELECT s.region_id, SUM(o.net_total) AS revenue FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id GROUP BY s.region_id
)
SELECT r.region_name, rr.revenue FROM region_rev rr JOIN core.dim_region r ON r.region_id = rr.region_id;
/* Q79. */
ANALYZE sales.orders;
EXPLAIN ANALYZE
WITH region_rev AS (
  SELECT s.region_id, SUM(o.net_total) AS revenue FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id GROUP BY s.region_id
)
SELECT r.region_name, rr.revenue FROM region_rev rr JOIN core.dim_region r ON r.region_id = rr.region_id;
/* Q80. Index recommendations for Day 20: a B-tree index on sales.orders(store_id) to support the store->region join/aggregate this dashboard depends on, and a B-tree index on sales.orders(cust_id) for the customer-scoped lookups other dashboard panels use - both currently force Seq Scans per EXPLAIN ANALYZE above. */
/* Q81. The region-revenue rollup belongs in a materialized view (Day 25) since it's read by every dashboard refresh but the underlying orders only change gradually through the day - a nightly/hourly REFRESH keeps it fast without recomputing the full join on every page load. */
/* Q82. */
EXPLAIN ANALYZE
SELECT c.customer_id, c.tier,
       COALESCE(o.orders, 0) AS orders, COALESCE(o.spend, 0) AS spend, COALESCE(r.reviews, 0) AS reviews
FROM customers.customers c
LEFT JOIN (SELECT cust_id, COUNT(*) AS orders, SUM(net_total) AS spend FROM sales.orders GROUP BY cust_id) o ON o.cust_id = c.customer_id
LEFT JOIN (SELECT customer_id, COUNT(*) AS reviews FROM customers.reviews GROUP BY customer_id) r ON r.customer_id = c.customer_id;
/* Q83. */
EXPLAIN ANALYZE
WITH cohort AS (SELECT customer_id, date_trunc('month', registration_date) AS cohort_month FROM customers.customers),
activity AS (SELECT cust_id, date_trunc('month', order_date) AS order_month FROM sales.orders)
SELECT c.cohort_month, COUNT(DISTINCT a.cust_id) AS active_customers
FROM cohort c JOIN activity a ON a.cust_id = c.customer_id
GROUP BY c.cohort_month
ORDER BY c.cohort_month;
/* Q84. */
EXPLAIN ANALYZE
WITH ranked AS (
  SELECT cat.category_name, p.product_id, SUM(oi.net_amount) AS revenue,
         ROW_NUMBER() OVER (PARTITION BY cat.category_name ORDER BY SUM(oi.net_amount) DESC) AS rn
  FROM sales.order_items oi
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
  GROUP BY cat.category_name, p.product_id
)
SELECT * FROM ranked WHERE rn <= 3;
/* Q85. */
EXPLAIN ANALYZE
WITH monthly_rev AS (SELECT date_trunc('month', order_date) AS month, SUM(net_total) AS revenue FROM sales.orders GROUP BY date_trunc('month', order_date)),
monthly_exp AS (SELECT date_trunc('month', expense_date) AS month, SUM(amount) AS expense FROM stores.expenses GROUP BY date_trunc('month', expense_date))
SELECT r.month, r.revenue, COALESCE(e.expense, 0) AS expense, r.revenue - COALESCE(e.expense, 0) AS profit
FROM monthly_rev r LEFT JOIN monthly_exp e ON e.month = r.month
ORDER BY r.month;
/* Q86. */
EXPLAIN ANALYZE
WITH viewed AS (SELECT DISTINCT customer_id FROM web_events.page_views WHERE customer_id IS NOT NULL),
ordered AS (SELECT DISTINCT cust_id AS customer_id FROM sales.orders)
SELECT (SELECT COUNT(*) FROM viewed) AS viewed_n, (SELECT COUNT(*) FROM ordered) AS ordered_n;
/* Q87. */
EXPLAIN ANALYZE
WITH rfm_base AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS recency_days, COUNT(*) AS frequency, SUM(net_total) AS monetary
  FROM sales.orders GROUP BY cust_id
)
SELECT *, NTILE(5) OVER (ORDER BY monetary) AS m_score FROM rfm_base;
/* Q88. Diagnose only: a "contains" product-name search (e.g. WHERE product_name ILIKE '%wireless%') forces a Seq Scan regardless of any B-tree index, since the match can start anywhere in the string - the Day-20 fix is a pg_trgm GIN index on product_name, not an ordinary B-tree. */
/* Q89. */
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE order_id > 149000 ORDER BY order_id LIMIT 20;
/* Q90. */
EXPLAIN ANALYZE
WITH distinct_pairs AS (SELECT DISTINCT o.cust_id, oi.prod_id FROM sales.order_items oi JOIN sales.orders o ON o.order_id = oi.order_id)
SELECT COUNT(*) AS distinct_customer_product_pairs FROM distinct_pairs;
/* Q91. */
EXPLAIN ANALYZE
SELECT cust_id, order_id, net_total, LAG(net_total) OVER (PARTITION BY cust_id ORDER BY order_date) AS prev_net_total
FROM sales.orders;
/* Q92. */
EXPLAIN ANALYZE
SELECT * FROM sales.orders WHERE order_status = 'Cancelled'
UNION ALL
SELECT * FROM sales.orders WHERE payment_mode_id = 1 AND order_status <> 'Cancelled';
/* Q93. */
EXPLAIN ANALYZE
WITH item_totals AS (SELECT order_id, SUM(net_amount) AS items_total FROM sales.order_items GROUP BY order_id)
SELECT o.order_id, o.cust_id, t.items_total FROM sales.orders o JOIN item_totals t ON t.order_id = o.order_id;
/* Q94. A nightly metric that's read many times but only needs to reflect end-of-day data belongs in a materialized view refreshed once after the nightly batch completes; a metric that must reflect the current second (e.g. a live "orders today" counter) should stay a live query, since a materialized view would just be stale. */
/* Q95. */
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM sales.orders WHERE order_status = 'Delivered';
/* Q96. Document the tuning as: the exact original query, the baseline EXPLAIN ANALYZE output, each rewrite tried in order with its own EXPLAIN ANALYZE, and the final recommended query plus any Day-20 index recommendation - saved together so another analyst can re-run the same steps and get the same result without re-deriving the reasoning. */
/* Q97. Prioritize by expected time saved x how often each query runs, weighted down by how risky/large the rewrite is - a query run constantly that's currently doing a full Seq Scan on a huge table with a simple sargability fix available should sit above a rare report that would need a major restructure for a small gain. */
/* Q98. Set SLOs like "95% of dashboard queries return under 2 seconds, 99% under 5 seconds"; monitor by logging EXPLAIN ANALYZE timings (or pg_stat_statements' mean/percentile execution time once installed) per query and alerting when the rolling percentile crosses the SLO threshold. */
/* Q99. Stop tuning once further EXPLAIN ANALYZE improvements are marginal relative to user-perceived latency (e.g. shaving 20ms off a 150ms dashboard query rarely matters), or once the remaining gap can only be closed by an index/materialized view that belongs in a later, deliberate step rather than more query rewriting. */
/* Q100. One-page playbook: (1) EXPLAIN ANALYZE first, read bottom-up for the costliest node; (2) fix sargability, trim SELECT *, add LIMIT where appropriate; (3) replace correlated subqueries/OR-across-columns/NOT IN with JOIN-to-grouped-CTE/UNION ALL/NOT EXISTS; (4) re-run ANALYZE if stats look stale; (5) re-measure after every change; (6) only then recommend a specific index or materialized view for Day 20/25, backed by the EXPLAIN ANALYZE evidence collected along the way. */

/* ============================================================
   END OF Reading Query Plans - CRAZY LEVEL (100 QUESTIONS)
============================================================ */
