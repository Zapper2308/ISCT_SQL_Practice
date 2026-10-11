/* ============================================================
   ANSWER KEY - Reading Query Plans (MEDIUM LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1.  A plan is "bad" when its actual time is far higher than a simple equivalent query would need, when estimated and actual row counts diverge wildly at some node, or when a node reports a disk spill (external merge / Batches>1) that a smaller working set wouldn't need. */
/* Q2.  A wrong row estimate at one join level feeds directly into the next join's cost model, so if the planner thinks a join will produce 10 rows but it actually produces 100,000, the next join (sized for 10 rows) may pick a Nested Loop that's catastrophic at the real volume. */
/* Q3.  The planner prefers Hash Join when at least one input is too large to be efficiently probed row-by-row but fits (or nearly fits) in work_mem as a hash table, and there's no already-sorted input or useful index making a Merge/Nested Loop cheaper. */
/* Q4.  A Merge Join is chosen when both inputs are already sorted on the join key (or an index provides that order cheaply) - it needs sorted inputs, and if neither side is naturally sorted, the planner would have to add explicit Sort nodes, which often makes Hash Join cheaper instead. */
/* Q5.  A Sort spills to disk when the data to be sorted exceeds work_mem; the plan shows "Sort Method: external merge  Disk: NNkB" instead of "Sort Method: quicksort  Memory: NNkB" in EXPLAIN ANALYZE output. */
/* Q6.  "Batches > 1" in a Hash node means the build-side input didn't fit in work_mem as a single in-memory hash table, so PostgreSQL split it into multiple batches written to and read back from disk - each extra batch adds I/O overhead. */
/* Q7.  A leading-wildcard LIKE forces a Seq Scan because a B-tree index is sorted by leading characters and can't jump to matches when the pattern's start is unknown - every row's value must be checked individually. */
/* Q8.  Wrapping an indexed column in a function or cast (e.g. UPPER(col), CAST(col AS text)) makes the predicate non-sargable because the index stores raw column values, not the transformed result; the general fix is to move the transformation onto the literal instead (col = lower('X')) or use a matching expression index. */
/* Q9.  "Rows Removed by Filter" shows how many rows a node examined but discarded because they failed a non-index-pushed condition - a large number relative to rows returned means the predicate is being applied late (after a broad scan) rather than narrowing the scan itself. */
/* Q10. LIMIT lets the planner favor a plan that can produce the first few rows cheaply (e.g. an Index Scan that stops early) over one with a lower total cost but higher startup cost, since only startup cost plus a fraction of total cost actually needs to be paid. */
/* Q11. OR across different columns often can't use a single index efficiently (or forces a Bitmap Or of two separate index scans, which still means reading everything derived from either condition); UNION ALL of two separately-indexed single-condition queries can let each half use its own efficient index scan. */
/* Q12. SELECT * pulls in every column, so PostgreSQL must visit the heap page for each row (an Index Only Scan requires all needed columns to be present in the index itself, all-visible per the visibility map) - once you need columns outside the index, the Index Only Scan optimization is unavailable. */
/* Q13. A high loop count on a Nested Loop's inner side means the inner scan was re-executed once per outer row - if that inner scan itself isn't cheap (e.g. not index-backed), the total work is inner-cost x loops, which can explode even when each individual loop looks fast. */
/* Q14. An underestimate (planner expects few rows, gets many) is the dangerous direction for nested-loop blowups, since the planner picks Nested Loop believing the inner side will be probed only a few times, then it's actually probed far more often than planned. */
/* Q15. ANALYZE refreshes the planner's statistics (histograms, most-common-values, row counts) without changing the query at all - if those statistics were stale (e.g. after a large bulk load), a fresh ANALYZE alone can make the planner choose a much better plan. */
/* Q16. BUFFERS "shared hit" counts pages already in PostgreSQL's shared_buffers cache (fast, no disk I/O); "shared read" counts pages that had to be fetched from disk (or the OS cache) - a high read/hit ratio signals the query is working against cold data. */
/* Q17. A Bitmap scan's sweet spot is moderate selectivity - selective enough that a plain Seq Scan would waste time on irrelevant rows, but returning too many matches for an efficient one-row-at-a-time Index Scan; the bitmap batches heap-page visits in physical order to amortize the I/O. */
/* Q18. SELECT DISTINCT after a fan-out join hides the real problem (the join multiplied rows) behind an expensive Sort/HashAggregate that discards the duplicates it just created - it's usually cheaper and clearer to pre-aggregate the many-side before joining, or use EXISTS instead of the join. */
/* Q19. A correlated subquery typically appears as a "SubPlan" node nested inside another node, with loops equal to the number of outer rows it was re-evaluated for - its own cost is multiplied by that loop count to get its real total contribution. */
/* Q20. EXISTS only checks for at least one match and stops as soon as it finds one (short-circuits), and it's unaffected by NULLs in the subquery's result; IN treats a NULL in the subquery's result specially and, combined with NOT, can silently return zero rows - EXISTS/NOT EXISTS avoids that trap. */
/* Q21. GroupAggregate expects its input pre-sorted by the GROUP BY columns (often via an upstream Sort node) and processes groups in that order; HashAggregate builds an in-memory hash table of groups and needs no sorted input - seeing GroupAggregate paired with a Sort usually means no useful index/order was available for HashAggregate to skip that Sort. */
/* Q22. Parallelism shows up as a Gather (or Gather Merge) node with one or more parallel-aware child nodes beneath it running in separate worker processes; it helps most on large Seq Scans/aggregates where the per-worker portion of work is big enough to outweigh the fixed cost of launching workers. */
/* Q23. For a trivial query run thousands of times per second, even a few milliseconds of planning time repeated on every execution can dominate total load - such queries benefit most from prepared statements (plan caching) rather than from further execution-time tuning. */
/* Q24. Compare plans with a warm cache (run each query at least once before timing), always use EXPLAIN ANALYZE (not just EXPLAIN) so you're comparing real execution, and run each variant more than once to smooth out noise from concurrent activity on the shared server. */
/* Q25. Check first: (1) does WHERE use sargable predicates (no function/cast on the indexed column), (2) is the projection trimmed (no unnecessary SELECT *) and is there a LIMIT if only a sample is needed, and (3) are joins/subqueries structured to avoid accidental fan-out or per-row correlated re-execution. */

/* ============================================================
   SECTION B: DIAGNOSE THE BOTTLENECK (25)
   ------------------------------------------------------------ */
/* Q26. */
EXPLAIN ANALYZE
SELECT cust_id, SUM(net_total) AS lifetime_spend, COUNT(*) AS order_count
FROM sales.orders
GROUP BY cust_id;

/* Q27. */
EXPLAIN ANALYZE
SELECT o.order_id, c.first_name FROM sales.orders o JOIN customers.customers c ON c.customer_id = o.cust_id;

/* Q28. */
EXPLAIN ANALYZE SELECT * FROM sales.orders ORDER BY net_total DESC LIMIT 10;

/* Q29. */
EXPLAIN ANALYZE SELECT * FROM customers.customers WHERE email LIKE '%gmail.com';

/* Q30. */
EXPLAIN ANALYZE
SELECT o.order_id, oi.quantity, p.product_name
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
JOIN products.products p ON p.product_id = oi.prod_id;

/* Q31. */
EXPLAIN ANALYZE
SELECT cust_id, COUNT(*) FROM sales.orders GROUP BY cust_id HAVING COUNT(*) > 8;

/* Q32. */
EXPLAIN ANALYZE SELECT * FROM sales.orders ORDER BY net_total - discount_amount;

/* Q33. */
EXPLAIN ANALYZE
SELECT o.order_id FROM (SELECT * FROM sales.orders ORDER BY order_id LIMIT 300) o
WHERE o.net_total > (SELECT AVG(net_total) FROM sales.orders o2 WHERE o2.cust_id = o.cust_id);

/* Q34. */
EXPLAIN ANALYZE
SELECT o.order_id FROM sales.orders o
JOIN (SELECT cust_id, AVG(net_total) AS avg_total FROM sales.orders GROUP BY cust_id) a ON a.cust_id = o.cust_id
WHERE o.net_total > a.avg_total;

/* Q35. */
EXPLAIN ANALYZE SELECT * FROM customers.customers WHERE UPPER(email) LIKE '%GMAIL.COM';

/* Q36. */
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM web_events.page_views WHERE device_type = 'Mobile';

/* Q37. */
EXPLAIN ANALYZE
SELECT DISTINCT o.order_id, o.net_total FROM sales.orders o JOIN sales.order_items oi ON oi.order_id = o.order_id;

/* Q38. */
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE order_date BETWEEN '2025-06-01' AND '2025-06-30';

/* Q39. */
EXPLAIN ANALYZE
SELECT c.customer_id FROM customers.customers c
WHERE c.customer_id NOT IN (SELECT cust_id FROM sales.orders WHERE cust_id IS NOT NULL);

/* Q40. */
EXPLAIN ANALYZE
SELECT o.order_id FROM sales.orders o
WHERE o.net_total > (SELECT AVG(net_total) FROM sales.orders);

/* Q41. */
EXPLAIN ANALYZE
SELECT r.review_id, p.product_name, b.brand_name
FROM customers.reviews r
JOIN products.products p ON p.product_id = r.product_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id;

/* Q42. */
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE order_status = 'Delivered';

/* Q43. */
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE order_status = 'Cancelled' OR payment_mode_id = 2;

/* Q44. */
EXPLAIN ANALYZE
SELECT * FROM sales.orders WHERE order_status = 'Cancelled'
UNION ALL
SELECT * FROM sales.orders WHERE payment_mode_id = 2 AND order_status <> 'Cancelled';

/* Q45. */
EXPLAIN ANALYZE
SELECT cust_id, COUNT(*) FROM sales.orders WHERE order_status <> 'Cancelled' GROUP BY cust_id HAVING COUNT(*) > 5;

/* Q46. */
EXPLAIN ANALYZE SELECT order_status, COUNT(*) FROM sales.orders GROUP BY order_status;

/* Q47. */
EXPLAIN ANALYZE SELECT * FROM sales.orders o, sales.returns r WHERE o.order_id = r.order_id;

/* Q48. */
EXPLAIN ANALYZE SELECT * FROM customers.customers WHERE UPPER(email) = 'TEST@RETAILMART.COM';

/* Q49. */
EXPLAIN ANALYZE SELECT * FROM customers.customers WHERE email = lower('TEST@RETAILMART.COM');

/* Q50. */
EXPLAIN ANALYZE SELECT * FROM sales.orders ORDER BY order_id OFFSET 100000 LIMIT 50;

/* ============================================================
   SECTION C: REWRITE FOR SARGABILITY (25)
   ------------------------------------------------------------ */
/* Q51. */
SELECT * FROM customers.customers WHERE email = lower('TEST@RETAILMART.COM');

/* Q52. */
SELECT * FROM sales.orders WHERE order_date >= DATE '2025-01-01' AND order_date < DATE '2026-01-01';

/* Q53. */
SELECT * FROM sales.orders WHERE order_date >= DATE '2025-03-01' AND order_date < DATE '2025-04-01';

/* Q54. */
SELECT * FROM sales.orders WHERE order_date >= DATE '2025-03-01' AND order_date < DATE '2025-04-01';

/* Q55. */
SELECT * FROM sales.orders WHERE cust_id = 123;

/* Q56. */
SELECT * FROM products.products WHERE price > 5000;

/* Q57. */
SELECT * FROM customers.customers WHERE email LIKE 'a%';

/* Q58. */
SELECT * FROM sales.orders WHERE net_total > 0;

/* Q59. */
SELECT * FROM sales.orders WHERE order_status IN ('Processing', 'Shipped');

/* Q60. */
SELECT * FROM sales.orders WHERE order_status = 'Cancelled'
UNION ALL
SELECT * FROM sales.orders WHERE payment_mode_id = 1 AND order_status <> 'Cancelled';

/* Q61. */
SELECT c.customer_id FROM customers.customers c
WHERE NOT EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id);

/* Q62. */
WITH brand_avg AS (
  SELECT p.brand_id, AVG(p.price) AS avg_price FROM products.products p GROUP BY p.brand_id
)
SELECT p.product_id, p.price
FROM products.products p
JOIN brand_avg a ON a.brand_id = p.brand_id
WHERE p.price > a.avg_price;

/* Q63. */
SELECT order_id, cust_id, net_total FROM sales.orders ORDER BY order_id LIMIT 20;

/* Q64. */
SELECT * FROM customers.customers WHERE email LIKE 'john%';

/* Q65. */
SELECT * FROM customers.customers WHERE registration_date <= CURRENT_DATE - INTERVAL '1 year';

/* Q66. */
SELECT * FROM stores.stores WHERE city = 'Mumbai';

/* Q67. */
SELECT o.* FROM sales.orders o
JOIN (VALUES (1),(2),(3),(4),(5),(10),(20)) AS v(store_id) ON v.store_id = o.store_id;

/* Q68. */
WITH prev_order AS (
  SELECT order_id, cust_id, net_total,
         LAG(net_total) OVER (PARTITION BY cust_id ORDER BY order_date) AS prev_net_total
  FROM sales.orders
)
SELECT * FROM prev_order WHERE prev_net_total IS NOT NULL LIMIT 100;

/* Q69. */
SELECT order_id FROM sales.order_items WHERE quantity > 0 AND net_amount > 100 * quantity;

/* Q70. */
SELECT cust_id, SUM(net_total) AS total_spend
FROM sales.orders
WHERE order_status <> 'Cancelled'
GROUP BY cust_id
HAVING SUM(net_total) > 20000;

/* Q71. */
SELECT o.order_id, o.net_total FROM sales.orders o
WHERE EXISTS (SELECT 1 FROM sales.order_items oi WHERE oi.order_id = o.order_id);

/* Q72. */
SELECT * FROM sales.orders WHERE order_date >= DATE '2025-01-01' AND order_date < DATE '2025-02-01';

/* Q73. */
SELECT * FROM products.products TABLESAMPLE SYSTEM (5) LIMIT 20;

/* Q74. */
SELECT * FROM sales.orders WHERE order_id > 100000 ORDER BY order_id LIMIT 50;

/* Q75. */
SELECT * FROM customers.customers WHERE first_name ILIKE '%x%' OR last_name ILIKE '%x%';

/* ============================================================
   SECTION D: JOIN & SORT TUNING (read/rewrite only) (25)
   ------------------------------------------------------------ */
/* Q76. */
EXPLAIN ANALYZE
SELECT o.order_id FROM sales.orders o
JOIN (SELECT cust_id, AVG(net_total) AS avg_total FROM sales.orders GROUP BY cust_id) a ON a.cust_id = o.cust_id
WHERE o.net_total > a.avg_total;

/* Q77. */
EXPLAIN ANALYZE
SELECT c.customer_id, o.order_id FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
WHERE c.tier = 'Platinum';

/* Q78. */
EXPLAIN ANALYZE
WITH order_totals AS (
  SELECT order_id, SUM(net_amount) AS items_total FROM sales.order_items GROUP BY order_id
)
SELECT o.order_id, o.net_total, t.items_total
FROM sales.orders o JOIN order_totals t ON t.order_id = o.order_id;

/* Q79. */
EXPLAIN ANALYZE
SELECT o.order_id, oi.quantity
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
WHERE o.order_status = 'Delivered';

/* Q80. */
EXPLAIN ANALYZE
SELECT o.order_id FROM sales.orders o
WHERE EXISTS (SELECT 1 FROM sales.order_items oi WHERE oi.order_id = o.order_id);

/* Q81. */
EXPLAIN ANALYZE
SELECT c.customer_id FROM customers.customers c
WHERE NOT EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id);

/* Q82. */
EXPLAIN SELECT DISTINCT order_status FROM sales.orders;

/* Q83. */
EXPLAIN ANALYZE
WITH region_rev AS (
  SELECT s.region_id, SUM(o.net_total) AS revenue
  FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id
  GROUP BY s.region_id
)
SELECT r.region_name, rr.revenue FROM region_rev rr JOIN core.dim_region r ON r.region_id = rr.region_id;

/* Q84. */
EXPLAIN ANALYZE
SELECT tier, COUNT(*) FROM customers.customers GROUP BY tier;

/* Q85. */
EXPLAIN ANALYZE
SELECT o.order_id, p.product_name, c.first_name
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN customers.customers c ON c.customer_id = o.cust_id;

/* Q86. */
EXPLAIN ANALYZE SELECT o.order_id, oi.quantity FROM sales.order_items oi JOIN sales.orders o ON o.order_id = oi.order_id;

/* Q87. */
SELECT cust_id, total_spend FROM (
  SELECT cust_id, SUM(net_total) AS total_spend FROM sales.orders GROUP BY cust_id
) t
ORDER BY total_spend DESC LIMIT 20;

/* Q88. */
EXPLAIN SELECT DISTINCT cust_id FROM sales.orders;

/* Q89. */
EXPLAIN ANALYZE SELECT * FROM sales.orders ORDER BY order_id LIMIT 5;

/* Q90. */
EXPLAIN SELECT * FROM sales.orders WHERE order_status = 'Cancelled'
UNION
SELECT * FROM sales.orders WHERE payment_mode_id = 1;

/* Q91. */
EXPLAIN SELECT * FROM sales.orders o, sales.returns r WHERE o.order_id = r.order_id;

/* Q92. */
EXPLAIN ANALYZE
SELECT * FROM sales.orders
WHERE cust_id IN (SELECT customer_id FROM customers.customers WHERE tier = 'Platinum');

/* Q93. */
EXPLAIN SELECT order_id FROM sales.orders WHERE order_id BETWEEN 1 AND 1000;

/* Q94. */
EXPLAIN ANALYZE
SELECT o.order_id FROM sales.orders o
WHERE EXISTS (SELECT 1 FROM sales.returns r WHERE r.order_id = o.order_id);

/* Q95. */
EXPLAIN SELECT order_status, COUNT(*) FROM sales.orders GROUP BY order_status ORDER BY order_status;

/* Q96. */
WITH ranked AS (
  SELECT cust_id, order_id, net_total, ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY net_total DESC) AS rn
  FROM sales.orders
)
SELECT * FROM ranked WHERE rn = 1 ORDER BY cust_id LIMIT 100;

/* Q97. */
EXPLAIN ANALYZE
WITH cte AS MATERIALIZED (SELECT cust_id, SUM(net_total) AS total_spend FROM sales.orders GROUP BY cust_id)
SELECT * FROM cte WHERE total_spend > 50000;

/* Q98. */
SELECT cust_id, COUNT(*) AS order_count, SUM(net_total) AS total_spend
FROM sales.orders GROUP BY cust_id ORDER BY total_spend DESC LIMIT 20;

/* Q99. */
EXPLAIN ANALYZE
SELECT o.order_id, p.product_name, c.first_name, s.store_name
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN customers.customers c ON c.customer_id = o.cust_id
JOIN stores.stores s ON s.store_id = o.store_id;

/* Q100. Prioritized rewrite plan for a slow 4-table analyst report (no indexes): (1) pre-aggregate the highest-fan-out table (e.g. order_items) in its own CTE before joining it to the others, so the join sizes stay small; (2) push every WHERE filter as early as possible (onto the smallest/most selective table first) rather than filtering after all four joins; (3) trim the SELECT list to only the columns the report actually needs; (4) re-run EXPLAIN ANALYZE after each change and compare actual time and row counts to confirm the rewrite actually helped before moving to the next one. */

/* ============================================================
   END OF Reading Query Plans - MEDIUM LEVEL (100 QUESTIONS)
============================================================ */
