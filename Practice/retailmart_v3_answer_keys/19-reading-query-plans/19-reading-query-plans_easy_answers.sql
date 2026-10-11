/* ============================================================
   ANSWER KEY - Reading Query Plans (EASY LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1.  EXPLAIN shows the planner's chosen plan with estimated costs and row counts without running the query; EXPLAIN ANALYZE actually executes the query and adds real elapsed time and actual row counts for every plan node. */
/* Q2.  No - plain EXPLAIN only asks the planner to produce and print its chosen plan; it never executes the query or touches any rows. */
/* Q3.  Yes, EXPLAIN ANALYZE really runs the query (including any side effects), so on an INSERT/UPDATE/DELETE it actually performs the write - wrap it in a transaction you ROLLBACK if you don't want the change to persist. */
/* Q4.  A Seq Scan reads every row of a table in physical (heap) order; the planner picks it when there's no useful index, or when the query is expected to return a large fraction of the table's rows, making a full scan cheaper than many random index lookups. */
/* Q5.  An Index Scan walks a B-tree index to find matching rows and then fetches each matching row from the table's heap; the planner picks it when a predicate is selective enough that reading the index plus a handful of heap rows beats scanning the whole table. */
/* Q6.  A Bitmap Index Scan builds an in-memory bitmap of matching row locations from an index, and the paired Bitmap Heap Scan fetches those heap pages in physical order - a middle ground efficient for a moderate number of matches, more than a plain Index Scan wants but fewer than a full Seq Scan. */
/* Q7.  The first number is the estimated startup cost (work needed before the first row can be returned) and the second is the estimated total cost to return all rows, both in the planner's arbitrary cost units (roughly disk-page-fetches). */
/* Q8.  Estimated rows is what the planner predicted from table statistics before running the query; actual rows (only in EXPLAIN ANALYZE) is what really came out of that node when the query ran - they can differ widely if statistics are stale or the predicate is hard to estimate. */
/* Q9.  Because the planner chose its join algorithm, join order and memory allocation based on the estimate - if the estimate is very wrong, those choices (e.g. a Nested Loop expecting 1 row that actually gets thousands) can be badly wrong too, causing a slow plan. */
/* Q10. "rows" is the average number of rows produced per execution of that node; "loops" is how many times the node was executed (e.g. once per outer row in a Nested Loop's inner side) - true total rows produced is rows x loops. */
/* Q11. For each row from the outer input, a Nested Loop rescans (or index-probes) the entire inner input looking for matches - efficient when the outer side is small or the inner side has a good index to probe. */
/* Q12. A Hash Join builds an in-memory hash table from the smaller input keyed on the join column, then streams the larger input through it probing for matches - efficient for large, unsorted inputs with no useful index. */
/* Q13. A Merge Join walks two inputs that are both already sorted on the join key side by side, advancing whichever pointer is behind - efficient when both inputs are cheaply available in sorted order (e.g. via an index). */
/* Q14. It forces PostgreSQL to fetch and transfer every column (including large text/jsonb ones you may not need) and prevents an Index Only Scan, when a narrower column list could often be satisfied from a smaller index alone. */
/* Q15. A B-tree index is sorted by the column's leading characters, so it can only jump straight to matches when the pattern's prefix is fixed; a leading wildcard means any row could match, so every entry must be checked, forcing a full scan. */
/* Q16. A plain B-tree index on email is built from the raw column values, not UPPER(email), so the index has no entry matching the transformed expression - the planner must scan every row and apply UPPER() to check it, unless a matching expression index exists. */
/* Q17. LIMIT lets the planner (and the executor) stop as soon as enough rows are found, avoiding a full scan/sort of a huge table just to eyeball a handful of sample rows. */
/* Q18. "actual time=start..end" gives that node's real startup and total elapsed milliseconds (averaged per loop), and "rows=N" is the real number of rows it produced per execution - together they show exactly where time was spent. */
/* Q19. ANALYZE (no EXPLAIN) samples a table's data and updates the planner's statistics (pg_statistic) so future plans are based on current data; EXPLAIN ANALYZE runs one query and reports its actual plan/timing - they're unrelated commands that happen to share a keyword. */
/* Q20. BUFFERS adds shared/local buffer hit, read, dirtied and written counts per node, showing how much of the work was served from cache (hits) versus read from disk (reads). */
/* Q21. It returns the same plan tree as structured JSON instead of plain text, which is much easier for a tool/script to parse programmatically (e.g. to extract the most expensive node automatically). */
/* Q22. Because each node's input comes from the node(s) indented further below it - the plan executes leaves first and feeds their output upward, so reading bottom-up follows the actual order of execution and data flow. */
/* Q23. The node's own "rows=" figure (rows produced per execution) multiplied by "loops=" (how many times it executed) gives the true total number of rows that node processed across the whole query. */
/* Q24. When the query is expected to return a large fraction of the table (low selectivity), reading the whole table sequentially is cheaper than the random I/O of following an index for that many matches - the planner compares real costs, not just "index exists or not". */
/* Q25. A Seq Scan on a huge table feeding a tiny final result (missing/ineffective filter), and a Sort or Hash node reporting "external merge"/"Batches > 1" (spilled to disk, indicating the query needs more work_mem or a narrower row set). */

/* ============================================================
   SECTION B: RUN EXPLAIN (25)
   ------------------------------------------------------------ */
/* Q26. */
EXPLAIN SELECT * FROM sales.orders WHERE cust_id = 12345;

/* Q27. */
EXPLAIN SELECT * FROM sales.orders WHERE order_date BETWEEN '2025-01-01' AND '2025-01-31';

/* Q28. */
EXPLAIN SELECT COUNT(*) FROM sales.orders;

/* Q29. */
EXPLAIN SELECT o.order_id, c.first_name FROM sales.orders o JOIN customers.customers c ON c.customer_id = o.cust_id;

/* Q30. */
EXPLAIN ANALYZE SELECT o.order_id, c.first_name FROM sales.orders o JOIN customers.customers c ON c.customer_id = o.cust_id;

/* Q31. */
EXPLAIN SELECT * FROM products.products WHERE price > 5000;

/* Q32. */
EXPLAIN SELECT * FROM sales.orders ORDER BY net_total DESC LIMIT 10;

/* Q33. */
EXPLAIN SELECT cust_id, SUM(net_total) FROM sales.orders GROUP BY cust_id;

/* Q34. */
EXPLAIN ANALYZE SELECT * FROM customers.customers WHERE email LIKE 'a%';

/* Q35. */
EXPLAIN ANALYZE SELECT * FROM customers.customers WHERE email LIKE '%gmail.com';

/* Q36. */
EXPLAIN SELECT * FROM customers.customers WHERE UPPER(email) = 'X@Y.COM';

/* Q37. */
EXPLAIN SELECT o.order_id, oi.quantity, p.product_name
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
JOIN products.products p ON p.product_id = oi.prod_id;

/* Q38. */
EXPLAIN (ANALYZE, BUFFERS) SELECT tier, COUNT(*) FROM customers.customers GROUP BY tier;

/* Q39. */
EXPLAIN SELECT * FROM web_events.page_views LIMIT 100;

/* Q40. */
EXPLAIN ANALYZE SELECT * FROM web_events.page_views;

/* Q41. */
EXPLAIN SELECT * FROM sales.orders WHERE order_status = 'Cancelled' OR payment_mode_id = 1;

/* Q42. */
EXPLAIN SELECT * FROM sales.orders WHERE cust_id IN (SELECT customer_id FROM customers.customers WHERE tier = 'Platinum');

/* Q43. */
EXPLAIN SELECT * FROM sales.orders o WHERE EXISTS (SELECT 1 FROM sales.returns r WHERE r.order_id = o.order_id);

/* Q44. */
EXPLAIN SELECT DISTINCT order_status FROM sales.orders;

/* Q45. */
EXPLAIN ANALYZE SELECT cust_id, COUNT(*) FROM sales.orders GROUP BY cust_id HAVING COUNT(*) > 5;

/* Q46. */
EXPLAIN SELECT o.order_id FROM sales.orders o
WHERE o.net_total > (SELECT AVG(net_total) FROM sales.orders o2 WHERE o2.cust_id = o.cust_id);

/* Q47. */
EXPLAIN SELECT c.customer_id FROM customers.customers c
LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
WHERE o.order_id IS NULL;

/* Q48. */
EXPLAIN (FORMAT JSON) SELECT * FROM products.products WHERE price > 10000;

/* Q49. */
EXPLAIN SELECT * FROM sales.orders ORDER BY net_total - discount_amount DESC;

/* Q50. */
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE order_status = 'Delivered';

/* ============================================================
   SECTION C: READ THE PLAN (25)
   ------------------------------------------------------------ */
/* Q51. */
EXPLAIN SELECT * FROM sales.orders WHERE order_id = 500;

/* Q52. */
EXPLAIN SELECT * FROM sales.orders o JOIN customers.customers c ON c.customer_id = o.cust_id;

/* Q53. */
EXPLAIN SELECT * FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
JOIN products.products p ON p.product_id = oi.prod_id;

/* Q54. */
EXPLAIN ANALYZE SELECT * FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
JOIN products.products p ON p.product_id = oi.prod_id;

/* Q55. */
EXPLAIN ANALYZE SELECT * FROM customers.customers WHERE UPPER(email) LIKE '%GMAIL%';

/* Q56. */
EXPLAIN SELECT * FROM sales.orders WHERE net_total > 50000;

/* Q57. */
EXPLAIN ANALYZE SELECT * FROM sales.orders ORDER BY net_total;

/* Q58. */
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE order_status = 'Cancelled';

/* Q59. */
EXPLAIN ANALYZE SELECT c.customer_id, o.order_id
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
WHERE c.tier = 'Platinum';

/* Q60. */
EXPLAIN ANALYZE SELECT order_id FROM sales.orders WHERE order_id BETWEEN 1 AND 1000;

/* Q61. */
EXPLAIN ANALYZE SELECT * FROM sales.orders ORDER BY order_id LIMIT 5;

/* Q62. */
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE order_status IN ('Cancelled', 'Returned');

/* Q63. */
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM sales.orders WHERE cust_id = 500;

/* Q64. */
EXPLAIN ANALYZE SELECT COUNT(*) FROM sales.order_items;

/* Q65. */
EXPLAIN ANALYZE SELECT c.customer_id, o.order_id
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
WHERE c.customer_id < 100;

/* Q66. */
EXPLAIN ANALYZE SELECT * FROM stores.stores s
JOIN sales.orders o ON o.store_id = s.store_id
WHERE s.store_id = 5;

/* Q67. */
EXPLAIN ANALYZE SELECT * FROM sales.orders o JOIN customers.customers c ON c.customer_id = o.cust_id;

/* Q68. */
EXPLAIN ANALYZE SELECT * FROM sales.orders o
JOIN sales.returns r ON r.order_id = o.order_id AND r.refund_amount > 100;

/* Q69. */
EXPLAIN SELECT * FROM sales.orders ORDER BY order_id;

/* Q70. */
EXPLAIN SELECT order_status, COUNT(*) FROM sales.orders GROUP BY order_status;

/* Q71. */
EXPLAIN SELECT o.*, (SELECT COUNT(*) FROM sales.returns r WHERE r.order_id = o.order_id) AS return_count
FROM sales.orders o LIMIT 100;

/* Q72. */
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE order_id = 1;

/* Q73. */
EXPLAIN ANALYZE SELECT * FROM web_events.page_views WHERE device_type = 'Mobile';

/* Q74. */
EXPLAIN SELECT * FROM sales.orders WHERE cust_id = 100;

/* Q75. */
EXPLAIN SELECT order_id, net_total FROM sales.orders WHERE order_status = 'Delivered' ORDER BY net_total DESC LIMIT 10;

/* ============================================================
   SECTION D: SPOT THE SMELL (no index changes) (25)
   ------------------------------------------------------------ */
/* Q76. */
SELECT * FROM customers.customers WHERE email = lower('A@B.COM');

/* Q77. A suffix search like '%@gmail.com' has no fixed prefix, so a plain B-tree index (sorted left-to-right) can't jump to matches - every row must be checked. Without changing indexes, there is no fully-sargable rewrite for a true suffix match; the real fix (Day 20) is a trigram (pg_trgm) index or a reversed-text expression index. */
/* Q78. */
SELECT order_id, cust_id, order_date, net_total FROM sales.orders WHERE order_status = 'Delivered' LIMIT 100;

/* Q79. */
SELECT * FROM web_events.page_views ORDER BY view_timestamp DESC LIMIT 100;

/* Q80. */
SELECT * FROM sales.orders WHERE order_date >= DATE '2025-01-01' AND order_date < DATE '2026-01-01';

/* Q81. */
SELECT * FROM sales.orders WHERE order_status = 'Cancelled'
UNION ALL
SELECT * FROM sales.orders WHERE payment_mode_id = 1 AND order_status <> 'Cancelled';

/* Q82. */
SELECT * FROM sales.orders WHERE order_date >= DATE '2025-01-01' AND order_date < DATE '2026-01-01';

/* Q83. */
SELECT o.order_id, o.net_total, a.avg_total
FROM sales.orders o
JOIN (SELECT cust_id, AVG(net_total) AS avg_total FROM sales.orders GROUP BY cust_id) a ON a.cust_id = o.cust_id
WHERE o.net_total > a.avg_total;

/* Q84. */
SELECT c.customer_id FROM customers.customers c
WHERE NOT EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id AND o.order_status = 'Cancelled');

/* Q85. */
SELECT * FROM products.products WHERE price > 5000;

/* Q86. */
SELECT * FROM customers.customers WHERE phone IS NULL OR phone = '';

/* Q87. */
SELECT DISTINCT o.order_id, o.net_total FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id;

/* Q88. */
SELECT * FROM sales.orders ORDER BY net_total DESC;

/* Q89. */
EXPLAIN SELECT * FROM sales.orders o, sales.returns r WHERE o.order_id = r.order_id;

/* Q90. */
SELECT * FROM customers.customers WHERE email LIKE 'a%';

/* Q91. */
SELECT order_id, net_total FROM sales.orders ORDER BY net_total DESC LIMIT 10;

/* Q92. */
SELECT * FROM customers.customers WHERE email LIKE 'john%';

/* Q93. */
SELECT o.order_id, o.net_total FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
WHERE o.order_status = 'Delivered';

/* Q94. */
SELECT * FROM sales.orders WHERE order_date = DATE '2025-03-01';

/* Q95. */
SELECT o.* FROM sales.orders o
JOIN (VALUES (1),(2),(3),(4),(5)) AS v(store_id) ON v.store_id = o.store_id;

/* Q96. */
SELECT * FROM sales.orders ORDER BY net_total DESC LIMIT 100;

/* Q97. */
SELECT * FROM sales.orders WHERE cust_id = 123;

/* Q98. */
SELECT cust_id, total_spend FROM (
  SELECT cust_id, SUM(net_total) AS total_spend FROM sales.orders GROUP BY cust_id
) t
ORDER BY total_spend DESC LIMIT 20;

/* Q99. */
SELECT cust_id, COUNT(*) AS order_count FROM sales.orders
WHERE order_status <> 'Cancelled'
GROUP BY cust_id
HAVING COUNT(*) > 5;

/* Q100. Three analyst-level rewrites to try first, before touching any index: (1) make predicates sargable - move functions/casts off the indexed column onto the literal side (UPPER(col)=x -> col=lower(x), date functions -> range predicates); (2) trim the projection - replace SELECT * with only the needed columns, and add a LIMIT to exploratory queries; (3) replace correlated subqueries/OR-across-columns/NOT IN with JOIN-to-a-grouped-CTE, UNION ALL, or NOT EXISTS respectively. */

/* ============================================================
   END OF Reading Query Plans - EASY LEVEL (100 QUESTIONS)
============================================================ */
