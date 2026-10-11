/* ============================================================
   ANSWER KEY - Filtering & Sorting (HARD LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* Q1.  "Sargable" (Search ARGument ABLE) means the predicate can use an index directly; `WHERE LOWER(email) = 'x'` wraps the column in a function, so a plain B-tree index on `email` can't be used - it defeats the index unless a functional index on `LOWER(email)` exists. */
/* Q2.  `col = NULL` always evaluates to UNKNOWN so it never matches, even for NULL rows; `col IS NULL` is a dedicated test that correctly finds them. */
/* Q3.  `IS DISTINCT FROM` is a NULL-safe comparison that treats two NULLs as "not distinct" (equal), so it never silently returns UNKNOWN like `=` does when a nullable column is involved. */
/* Q4.  `col BETWEEN x AND y` is equivalent to `col >= x AND col <= y` - both boundary values x and y are included in the result. */
/* Q5.  A composite index on (col1, col2) stores rows sorted first by col1 then col2, so a query filtering on both can seek directly using the index's leading columns instead of scanning; a single-column index could only help with one predicate at a time. */
/* Q6.  A composite index is only usable left-to-right: (a, b) speeds up queries filtering on `a` alone or `a AND b`, but not `b` alone; (b, a) is the mirror image - column order must match the most selective/most-queried leading predicate. */
/* Q7.  The range form lets the planner use a plain index range scan on `date_col`; `EXTRACT(year FROM date_col) = 2025` wraps the column in a function, forcing a full scan (non-sargable) unless a functional index on that expression exists. */
/* Q8.  `ILIKE 'abc%'` (prefix) can use a B-tree index (with the right operator class/collation) because it's a bounded range; `ILIKE '%abc'` (suffix) can't, since there's no fixed starting point to seek from - it forces a full scan. */
/* Q9.  LIMIT/OFFSET pagination skips OFFSET rows and returns the next LIMIT - the engine still has to fetch and discard every skipped row, so deep offsets (page 10,000) get progressively slower as the offset grows. */
/* Q10. Keyset pagination filters on the last row seen instead of counting offsets: `WHERE id > last_seen_id ORDER BY id LIMIT 50` - the index seeks straight to the next page regardless of how deep you are. */
/* Q11. ASC defaults to NULLS LAST, DESC defaults to NULLS FIRST - `ORDER BY ... NULLS LAST` overrides that placement explicitly. */
/* Q12. `DISTINCT` deduplicates whole rows with no guaranteed "which one" since there's nothing left to differ; `DISTINCT ON (col)` keeps exactly one row per distinct `col` value - specifically the first row in the given ORDER BY, so you control which one survives. */
/* Q13. They are semantically equivalent - `x IN (1,2,3)` and `x = ANY(ARRAY[1,2,3])` produce identical results; ANY additionally accepts a subquery or an actual array column. */
/* Q14. `x = ALL(subquery)` is TRUE only if x equals every value returned by the subquery - it's rarely used because it's almost never true unless the subquery returns one value or is empty (vacuously true), unlike `IN`/`= ANY` which are far more common. */
/* Q15. EXISTS stops at the first matching row and scales well because the planner can push the correlation into an index seek per outer row; IN materializes/hashes the whole subquery result first, which can be faster for small, cheap subqueries but worse for expensive correlated ones. */
/* Q16. If the subquery returns even one NULL, `NOT IN` becomes `col <> v1 AND col <> v2 AND ... AND col <> NULL`, and the NULL comparison makes the whole AND-chain UNKNOWN for every row - so `NOT IN` silently returns zero rows. */
/* Q17. Both perform an anti-join and are usually planned identically by PostgreSQL; NOT EXISTS is NULL-safe by construction, while `LEFT JOIN ... WHERE right.col IS NULL` needs the join column to actually be NULL-able-checked correctly, but both avoid the NOT IN NULL trap. */
/* Q18. `col @@ tsquery` is the full-text search match operator - it tests whether a `tsvector` document satisfies a parsed `tsquery`, supporting stemming, ranking, and GIN-index-accelerated text search, unlike LIKE which is a raw pattern match. */
/* Q19. A covering index includes every column the query needs (in the key or as INCLUDE columns), so PostgreSQL can answer the query entirely from the index (an "index-only scan") without visiting the heap/table at all, provided the visibility map allows it. */
/* Q20. `(a, b) > (1, 2)` compares tuples lexicographically - a > 1, OR (a = 1 AND b > 2); this is exactly the comparison keyset pagination needs to move past a compound (date, id) cursor in one clean expression instead of an OR/AND tree. */
/* Q21. `ORDER BY RANDOM()` forces PostgreSQL to compute a random value for and sort EVERY row in the table before applying LIMIT, which is an expensive full table sort even though you only want a handful of rows. */
/* Q22. `IN (subq)` accepts a subquery returning any number of rows; `= (subq scalar)` requires the subquery to return exactly one row/value or PostgreSQL raises a runtime error - use IN whenever the subquery could return more than one row. */
/* Q23. `SIMILAR TO` uses SQL-standard regex syntax (weaker, less familiar) and is anchored by default; most PostgreSQL users prefer the POSIX `~` operator because it supports the fuller, more common regex dialect and is not implicitly anchored. */
/* Q24. `WHERE 1=0` is a predicate that's always false, commonly used to create an empty result set with the right column shape (e.g. `SELECT * FROM t WHERE 1=0` to get zero rows but the full table structure for DDL/metadata purposes). */
/* Q25. SeqScan reads every row in table order (best for small tables or low-selectivity filters); IndexScan uses an index to fetch matching rows directly (good for high selectivity); BitmapIndexScan builds an in-memory bitmap of matching heap pages from one or more indexes and then does a single sorted heap pass - useful for medium selectivity or combining multiple indexes. */

/* Q26. */
SELECT * FROM sales.orders
WHERE order_date >= '2025-03-01' AND order_date < '2025-04-01';

/* Q27. */
SELECT * FROM customers.customers
WHERE email LIKE 'a%';

/* Q28. */
SELECT * FROM products.products
WHERE price BETWEEN 1000 AND 5000;

/* Q29. */
SELECT * FROM sales.orders
WHERE order_status IN ('Processing', 'Shipped');

/* Q30. */
SELECT * FROM products.products
WHERE supplier_id = 10 AND brand_id = 3;

/* Q31. */
SELECT * FROM support.tickets
WHERE priority = 'Critical' AND status = 'Open';

/* Q32. */
SELECT * FROM sales.shipments
WHERE courier_name = 'BlueDart' AND shipped_date >= now() - INTERVAL '7 days';

/* Q33. */
SELECT * FROM web_events.page_views
WHERE device_type = 'Mobile' AND os = 'iOS';

/* Q34. */
SELECT * FROM stores.employees
WHERE role = 'Store Manager' AND store_id IN (1, 2, 3);

/* Q35. */
SELECT * FROM sales.orders
WHERE net_total > 10000 AND order_date >= '2025-01-01';

/* Q36. */
SELECT * FROM sales.orders
WHERE order_date >= DATE_TRUNC('month', CURRENT_DATE)
  AND order_date < DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month';

/* Q37. */
SELECT * FROM audit.api_requests
WHERE timestamp >= now() - INTERVAL '7 days';

/* Q38. */
SELECT * FROM sales.orders
WHERE order_date >= '2025-01-01' AND order_date < '2026-01-01';

/* Q39. */
SELECT email FROM customers.customers
WHERE email LIKE 'a%';

/* Q40. */
SELECT * FROM support.tickets
WHERE resolved_date IS NULL;

/* Q41. */
SELECT * FROM sales.orders
WHERE order_status = 'Cancelled';

/* Q42. */
SELECT * FROM customers.customers
WHERE email = 'x@y.com';

/* Q43. */
SELECT * FROM payroll.pay_slips
WHERE salary_year = 2025 AND salary_month IN ('January', 'February', 'March');

/* Q44. */
SELECT * FROM customers.reviews
WHERE rating >= 4 AND review_date >= '2025-01-01';

/* Q45. */
SELECT * FROM supply_chain.inventory_snapshots
WHERE warehouse_id = 5 AND snapshot_date = '2025-04-15';

/* Q46. */
SELECT * FROM call_center.calls
WHERE call_reason = 'Return/Refund' AND call_duration_seconds > 300;

/* Q47. */
SELECT * FROM marketing.ads_spend
WHERE platform = 'Facebook' AND spend_date BETWEEN '2025-01-01' AND '2025-03-31';

/* Q48. */
SELECT * FROM web_events.page_views
WHERE page_url LIKE '/product/%';

/* Q49. */
SELECT * FROM loyalty.members
WHERE tier_id IN (3, 4);

/* Q50. */
SELECT * FROM supply_chain.shipments
WHERE supplier_id = 7 AND quantity > 100;

/* Q51. */
SELECT * FROM sales.orders ORDER BY order_id LIMIT 50 OFFSET 4950;

/* Q52. */
SELECT * FROM sales.orders
WHERE (order_date, order_id) < ('2025-06-01'::date, 100000)
ORDER BY order_date DESC, order_id DESC
LIMIT 50;

/* Q53. */
SELECT * FROM sales.orders ORDER BY net_total DESC NULLS LAST;

/* Q54. */
SELECT * FROM loyalty.members ORDER BY tier_id NULLS FIRST;

/* Q55. */
SELECT * FROM support.tickets
ORDER BY CASE priority
           WHEN 'Critical' THEN 1
           WHEN 'High' THEN 2
           WHEN 'Medium' THEN 3
           WHEN 'Low' THEN 4
           ELSE 5
         END;

/* Q56. */
SELECT cust_id, net_total FROM sales.orders
ORDER BY net_total DESC, cust_id ASC;

/* Q57. */
SELECT * FROM sales.orders
ORDER BY DATE_TRUNC('month', order_date), net_total DESC;

/* Q58. */
SELECT DISTINCT ON (cust_id) *
FROM sales.orders
ORDER BY cust_id, order_date DESC;

/* Q59. */
SELECT DISTINCT ON (product_id) *
FROM customers.reviews
ORDER BY product_id, review_date DESC;

/* Q60. */
SELECT DISTINCT ON (brand_id) *
FROM products.products
ORDER BY brand_id, price DESC;

/* Q61. Because rows can be deleted or inserted between pages, a fixed OFFSET can skip or repeat rows as the underlying row count shifts; a keyset cursor based on a stable, unique id always resumes exactly after the last row it actually returned, regardless of deletes elsewhere in the table. */

/* Q62. */
SELECT * FROM customers.customers ORDER BY first_name COLLATE "C";

/* Q63. */
SELECT * FROM customers.addresses ORDER BY pincode::int;

/* Q64. */
SELECT * FROM customers.customers ORDER BY SPLIT_PART(email, '@', 2);

/* Q65. */
SELECT ticket_id, priority FROM support.tickets
ORDER BY CASE priority
           WHEN 'Critical' THEN 1
           WHEN 'High' THEN 2
           WHEN 'Medium' THEN 3
           WHEN 'Low' THEN 4
           ELSE 5
         END;

/* Q66. */
SELECT * FROM support.tickets
WHERE (created_date, ticket_id) > ('2025-01-01 00:00:00'::timestamp, 1000)
ORDER BY created_date, ticket_id
LIMIT 50;

/* Q67. */
SELECT * FROM sales.orders
WHERE (order_date, order_id) > ('2025-06-01'::date, 100000)
ORDER BY order_date ASC, order_id ASC
LIMIT 20;

/* Q68. */
SELECT * FROM sales.orders ORDER BY order_id LIMIT 10 OFFSET 0;

/* Q69. */
SELECT * FROM sales.orders LIMIT 0;

/* Q70. */
SELECT order_id, cust_id, net_total FROM sales.orders ORDER BY 3 DESC;

/* Q71. */
SELECT email, COUNT(*) AS n
FROM customers.customers
GROUP BY email
HAVING COUNT(*) > 1
ORDER BY email;

/* Q72. */
SELECT * FROM sales.orders
WHERE (order_date, order_id) < ('2025-06-01'::date, 100000)
ORDER BY order_date DESC, order_id DESC
LIMIT 50;

/* Q73. `ORDER BY 1` is only appropriate for quick, throwaway/ad-hoc queries where the SELECT list is stable; in production code `ORDER BY full_name` (or any explicit column name) is safer because it survives someone reordering or adding columns to the SELECT list. */

/* Q74. */
SELECT * FROM products.products ORDER BY RANDOM() LIMIT 5;

/* Q75. */
SELECT * FROM sales.orders TABLESAMPLE BERNOULLI(1);

/* Q76. */
SELECT * FROM customers.customers c
WHERE EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id);

/* Q77. */
SELECT * FROM products.products p
WHERE EXISTS (SELECT 1 FROM customers.reviews r WHERE r.product_id = p.product_id AND r.rating = 5);

/* Q78. */
SELECT * FROM customers.customers c
WHERE NOT EXISTS (SELECT 1 FROM customers.reviews r WHERE r.customer_id = c.customer_id);

/* Q79. */
SELECT * FROM products.products p
WHERE NOT EXISTS (SELECT 1 FROM sales.order_items oi WHERE oi.prod_id = p.product_id);

/* Q80. */
SELECT * FROM sales.orders
WHERE cust_id IN (SELECT customer_id FROM customers.customers WHERE tier = 'Gold');

/* Q81. */
-- NOT IN version (risky if the subquery can return NULL):
SELECT * FROM customers.customers
WHERE customer_id NOT IN (SELECT customer_id FROM loyalty.members WHERE customer_id IS NOT NULL);
-- NULL-safe version:
SELECT * FROM customers.customers c
WHERE NOT EXISTS (SELECT 1 FROM loyalty.members m WHERE m.customer_id = c.customer_id);

/* Q82. */
SELECT * FROM sales.orders
WHERE order_status = ANY (ARRAY['Delivered', 'Shipped', 'Processing']);

/* Q83. */
SELECT * FROM products.products
WHERE price > ALL (SELECT price FROM products.products WHERE brand_id = 5);

/* Q84. */
SELECT * FROM loyalty.members
WHERE tier_id < ANY (SELECT tier_id FROM loyalty.tiers WHERE tier_name = 'Gold');

/* Q85. */
SELECT * FROM sales.orders
WHERE cust_id IN (
  SELECT cust_id FROM sales.orders GROUP BY cust_id ORDER BY SUM(net_total) DESC LIMIT 10
);

/* Q86. */
SELECT p.* FROM products.products p
JOIN core.dim_brand b ON b.brand_id = p.brand_id
WHERE b.category_id IN (
  SELECT b2.category_id
  FROM products.products p2
  JOIN core.dim_brand b2 ON b2.brand_id = p2.brand_id
  GROUP BY b2.category_id
  HAVING COUNT(*) > 100
);

/* Q87. */
SELECT * FROM support.tickets t
WHERE t.created_date::date IN (
  SELECT timestamp::date FROM audit.application_logs
  WHERE level = 'FATAL'
  GROUP BY timestamp::date
  HAVING COUNT(*) > 5
);

/* Q88. */
SELECT * FROM customers.customers c
WHERE EXISTS (
  SELECT 1 FROM customers.addresses a
  JOIN stores.stores s ON s.city = a.city
  WHERE a.customer_id = c.customer_id
);

/* Q89. */
SELECT * FROM sales.shipments s
WHERE DATE_TRUNC('month', s.shipped_date) IN (
  SELECT DATE_TRUNC('month', shipped_date)
  FROM sales.shipments
  WHERE delivered_date IS NOT NULL
  GROUP BY DATE_TRUNC('month', shipped_date)
  HAVING AVG(delivered_date - shipped_date) < 2
);

/* Q90. */
SELECT * FROM payroll.pay_slips p
WHERE (p.salary_year, p.salary_month) IN (
  SELECT salary_year, salary_month FROM payroll.pay_slips
  GROUP BY salary_year, salary_month
  HAVING SUM(net_salary) > 100000
);

/* Q91. */
SELECT DISTINCT o.* FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
JOIN products.products p ON p.product_id = oi.prod_id
WHERE p.brand_id = (
  SELECT p2.brand_id
  FROM sales.order_items oi2
  JOIN products.products p2 ON p2.product_id = oi2.prod_id
  GROUP BY p2.brand_id
  ORDER BY SUM(oi2.quantity) DESC
  LIMIT 1
);

/* Q92. */
SELECT * FROM marketing.campaigns c
WHERE EXISTS (
  SELECT 1 FROM customers.customers cu
  WHERE cu.registration_date BETWEEN c.start_date AND c.end_date
  GROUP BY cu.registration_date
  HAVING COUNT(*) > 100
);

/* Q93. */
SELECT c.* FROM customers.customers c
JOIN loyalty.members m ON m.customer_id = c.customer_id
JOIN loyalty.tiers t ON m.points_balance BETWEEN t.min_points AND t.max_points
WHERE c.tier = t.tier_name;

/* Q94. */
SELECT * FROM products.products p
WHERE (SELECT AVG(p2.price) FROM products.products p2 WHERE p2.brand_id = p.brand_id) > 5000;

/* Q95. */
SELECT * FROM stores.employees e
WHERE e.salary > (SELECT AVG(e2.salary) FROM stores.employees e2 WHERE e2.dept_id = e.dept_id);

/* Q96. */
SELECT * FROM customers.customers c
WHERE c.customer_id IN (
  SELECT o.cust_id FROM sales.orders o
  GROUP BY o.cust_id, DATE_TRUNC('week', o.order_date)
  HAVING COUNT(*) > 3
);

/* Q97. */
WITH product_units AS (
  SELECT p.product_id, COALESCE(SUM(oi.quantity), 0) AS units
  FROM products.products p
  LEFT JOIN sales.order_items oi ON oi.prod_id = p.product_id
  GROUP BY p.product_id
)
SELECT p.*
FROM products.products p
JOIN product_units pu ON pu.product_id = p.product_id
WHERE pu.units > (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY units) FROM product_units);

/* Q98. */
SELECT * FROM sales.orders o
WHERE o.order_date = (
  SELECT timestamp::date FROM audit.application_logs
  WHERE level IN ('ERROR', 'FATAL')
  GROUP BY timestamp::date
  ORDER BY COUNT(*) DESC
  LIMIT 1
);

/* Q99. */
SELECT * FROM call_center.calls c
WHERE c.agent_id IN (SELECT agent_id FROM support.tickets WHERE status = 'Resolved');

/* Q100. */
SELECT * FROM customers.customers c
WHERE EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id)
  AND EXISTS (SELECT 1 FROM customers.reviews r WHERE r.customer_id = c.customer_id)
  AND EXISTS (SELECT 1 FROM support.tickets t WHERE t.customer_id = c.customer_id)
  AND EXISTS (SELECT 1 FROM call_center.calls cc WHERE cc.customer_id = c.customer_id);

/* ============================================================
   END OF ANSWER KEY - HARD LEVEL (100/100)
============================================================ */
