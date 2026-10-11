/* ============================================================
   ANSWER KEY - Filtering & Sorting (CRAZY LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* Q1.  SQL logic has three truth values - TRUE, FALSE, and UNKNOWN (from any comparison touching NULL); WHERE only keeps rows where the predicate evaluates to TRUE, so UNKNOWN rows are silently dropped just like FALSE ones. */
/* Q2.  `x = NULL` always evaluates to UNKNOWN because NULL means "unknown value", not a comparable quantity - use `x IS NULL` instead, which is a dedicated existence test rather than a comparison. */
/* Q3.  `IS DISTINCT FROM` compares two values treating NULL as a normal, comparable value (two NULLs are "not distinct"/equal), so unlike `=` it never returns UNKNOWN - it is fully NULL-safe. */
/* Q4.  If the subquery's result set contains a NULL, `col NOT IN (...)` expands to a chain of `col <> each_value AND col <> NULL`; that last comparison is UNKNOWN, which poisons the whole AND chain to UNKNOWN for every row, so the query returns zero rows. */
/* Q5.  EXISTS checks row presence and can short-circuit on the first match, is always NULL-safe, and tends to scale better for correlated/large subqueries; IN materializes the subquery's values and is NULL-unsafe when negated (NOT IN) - planners often rewrite simple forms of both into the same semi-join plan. */
/* Q6.  De Morgan's laws: NOT (A AND B) = (NOT A) OR (NOT B), and NOT (A OR B) = (NOT A) AND (NOT B) - they matter because negating a compound predicate without applying them (or without parentheses) easily produces the wrong logic. */
/* Q7.  AND binds tighter than OR, so `a OR b AND c` parses as `a OR (b AND c)`. */
/* Q8.  Half-open ranges (`>= start AND < end`) unambiguously include every timestamp in the day/period regardless of time-of-day precision, while BETWEEN's inclusive upper bound (`<= '2025-01-31'`) silently excludes any time after midnight on the last day for TIMESTAMP columns. */
/* Q9.  Deep OFFSETs are slow because the engine must still fetch and discard every one of the skipped rows before it can return the requested page - work grows linearly with the offset even though the result set size stays constant. */
/* Q10. Keyset pagination filters `WHERE key > last_seen_key ORDER BY key LIMIT n` instead of counting past rows - it lets an index seek directly to the next page, so its cost stays roughly constant no matter how deep the page is, unlike OFFSET. */
/* Q11. ASC defaults NULLs to sort LAST; DESC defaults NULLs to sort FIRST; override either with an explicit `NULLS FIRST` / `NULLS LAST`. */
/* Q12. `DISTINCT` removes duplicate whole rows with no control over which duplicate "wins" (they're identical anyway); `DISTINCT ON (col)` keeps exactly one row per distinct value of `col` - specifically the first row per group according to the query's ORDER BY. */
/* Q13. `x IN (a,b,c)` is defined to be exactly equivalent to `x = ANY(ARRAY[a,b,c])` - both check if x matches any listed value. */
/* Q14. `x = ALL(subquery)` is TRUE only if x equals every row returned (so an empty subquery makes it vacuously TRUE); `x > ALL(subquery)` is TRUE only if x is greater than every returned value - equivalent to `x > MAX(subquery)`, and also vacuously TRUE for an empty subquery. */
/* Q15. `x < ANY(subquery)` is TRUE if x is less than AT LEAST ONE returned value - equivalent to `x < MAX(subquery)`; `x > ANY(subquery)` is TRUE if x exceeds at least one value - equivalent to `x > MIN(subquery)`. */
/* Q16. Relational division ("has ALL of a set") can be expressed either as `HAVING COUNT(DISTINCT match_col) = (total set size)` after joining/filtering to the set, or as a double NOT EXISTS: rows with NO set-member that the entity failed to match. */
/* Q17. Both implement an anti-join and PostgreSQL typically plans them identically; NOT EXISTS is inherently NULL-safe, while `LEFT JOIN ... WHERE right.col IS NULL` needs the join key itself to be checked for NULL to behave correctly - both avoid the NOT IN NULL trap when written carefully. */
/* Q18. A predicate is "sargable" when the engine can evaluate it directly against an index without transforming the indexed column first (no wrapping function, no leading wildcard) - it shapes WHERE-writing toward comparing raw columns to literals/ranges rather than `f(col) = value`. */
/* Q19. `(a, b) > (1, 2)` expands to `a > 1 OR (a = 1 AND b > 2)` - lexicographic tuple comparison, exactly the "move past the last seen composite key" condition keyset pagination needs. */
/* Q20. `COLLATE "C"` sorts by raw byte value (fast, locale-independent, uppercase before lowercase, ASCII order); a locale collation applies language-aware rules (accent-insensitive, culturally correct alphabetical order) which is typically what end users expect but is slower to compute. */
/* Q21. `ORDER BY RANDOM()` must compute a random key for and sort every row in the table before LIMIT trims it, making it an O(n log n) full-table operation; `TABLESAMPLE` reads only a random subset of pages/blocks up front, which is far cheaper on large tables. */
/* Q22. `col = (scalar subquery)` requires the subquery to return at most one row or PostgreSQL raises a runtime error; `col IN (subquery)` accepts any number of rows safely - use IN whenever the subquery could plausibly return more than one. */
/* Q23. `SIMILAR TO` uses SQL-standard regex syntax and is implicitly anchored to the whole string; POSIX `~` uses the fuller, more familiar regex dialect and is not anchored by default; `LIKE 'x%'` (prefix) can use a B-tree index, while `LIKE '%x'` (suffix) cannot. */
/* Q24. Without a unique tie-breaker, rows that share the same sort-key value can be returned in any order across pages, so identical-looking rows can be skipped or duplicated between page fetches - a unique column appended to ORDER BY guarantees a fully deterministic sequence. */
/* Q25. No - the order predicates are written in WHERE never changes the logical result (AND is commutative); it can, however, change the query PLAN, since the optimizer may evaluate cheaper/more selective predicates first regardless of how they're written. */

/* Q26. */
SELECT * FROM customers.customers
WHERE phone IS NULL OR phone = '';

/* Q27. */
SELECT * FROM sales.shipments
WHERE delivered_date IS DISTINCT FROM shipped_date;

/* Q28. */
SELECT * FROM sales.orders
WHERE (order_status = 'Returned' OR order_status = 'Cancelled') AND net_total > 5000;

/* Q29. */
SELECT * FROM sales.orders
WHERE order_status <> 'Delivered' OR net_total >= 1000;

/* Q30. */
SELECT * FROM sales.orders
WHERE order_date >= '2025-03-01' AND order_date < '2025-04-01';

/* Q31. */
SELECT * FROM products.promotions
WHERE start_date <= '2025-06-30' AND end_date >= '2025-06-01';

/* Q32. */
SELECT * FROM sales.orders
WHERE COALESCE(net_total, 0) = 0;

/* Q33. */
SELECT * FROM sales.orders
WHERE order_status NOT IN ('Delivered', 'Shipped', 'Out for Delivery');

/* Q34. */
SELECT * FROM customers.customers
WHERE email ILIKE 'a%';

/* Q35. */
SELECT * FROM customers.customers
WHERE SPLIT_PART(email, '@', 1) ~ '[0-9]';

/* Q36. */
SELECT * FROM customers.customers
WHERE first_name ~ '[^\x00-\x7F]';

/* Q37. */
SELECT * FROM customers.customers
WHERE tier IS NOT NULL AND tier_updated_at IS NULL;

/* Q38. */
SELECT * FROM products.products
WHERE price BETWEEN 1000 AND 5000 AND price <> 1999;

/* Q39. */
SELECT * FROM sales.orders
WHERE (gross_total - discount_amount) > 10000;

/* Q40. */
SELECT * FROM customers.customers
WHERE tier IS DISTINCT FROM 'Platinum';

/* Q41. */
SELECT * FROM customers.addresses
WHERE pincode ~ '^\d{6}$';

/* Q42. */
SELECT * FROM customers.reviews
WHERE rating IS NULL OR rating < 2;

/* Q43. */
SELECT * FROM customers.customers
WHERE email !~ '\.(com|in|net|org)$';

/* Q44. */
SELECT * FROM sales.orders
WHERE order_date >= '2025-01-01' AND net_total BETWEEN 2000 AND 8000;

/* Q45. */
SELECT * FROM sales.order_items
WHERE quantity > 0 AND net_amount <= 0;

/* Q46. */
SELECT * FROM support.tickets
WHERE resolved_date IS NULL AND created_date < CURRENT_TIMESTAMP - INTERVAL '30 days';

/* Q47. */
SELECT * FROM support.tickets
WHERE priority = ANY (ARRAY['Critical', 'High']);

/* Q48. */
SELECT * FROM customers.customers
WHERE first_name <> TRIM(first_name);

/* Q49. */
SELECT * FROM sales.orders
WHERE (order_status = 'Cancelled') <> (COALESCE(net_total, 0) = 0);

/* Q50. */
SELECT product_id, product_name,
       ROUND(100.0 * (price - cost_price) / NULLIF(price, 0), 2) AS margin_pct
FROM products.products
ORDER BY margin_pct DESC;

/* Q51. */
SELECT * FROM customers.customers c
WHERE EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id);

/* Q52. */
SELECT * FROM products.products p
WHERE NOT EXISTS (SELECT 1 FROM sales.order_items oi WHERE oi.prod_id = p.product_id);

/* Q53. */
SELECT * FROM customers.customers c
WHERE NOT EXISTS (SELECT 1 FROM loyalty.members m WHERE m.customer_id = c.customer_id);

/* Q54. */
SELECT * FROM sales.orders
WHERE cust_id IN (SELECT customer_id FROM customers.customers WHERE tier = 'Platinum');

/* Q55. */
SELECT * FROM products.products
WHERE price > ALL (SELECT price FROM products.products WHERE brand_id = 5);

/* Q56. */
SELECT * FROM loyalty.members m
WHERE m.tier_id < ANY (
  SELECT m2.tier_id
  FROM loyalty.members m2
  JOIN customers.addresses a ON a.customer_id = m2.customer_id
  WHERE a.city = 'Mumbai'
);

/* Q57. */
SELECT * FROM sales.orders
WHERE order_status = ANY (SELECT s FROM (VALUES ('Delivered'), ('Shipped'), ('Processing')) AS v(s));

/* Q58. */
SELECT * FROM products.products p
WHERE EXISTS (SELECT 1 FROM customers.reviews r WHERE r.product_id = p.product_id AND r.rating = 5);

/* Q59. */
SELECT * FROM customers.customers c
WHERE EXISTS (SELECT 1 FROM customers.reviews r WHERE r.customer_id = c.customer_id)
  AND NOT EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id);

/* Q60. */
SELECT DISTINCT o.*
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
JOIN products.products p ON p.product_id = oi.prod_id
WHERE p.brand_id IN (
  SELECT brand_id FROM products.products GROUP BY brand_id HAVING COUNT(*) > 100
);

/* Q61. */
SELECT c.customer_id
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
JOIN sales.order_items oi ON oi.order_id = o.order_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
WHERE b.category_id IN (1, 2, 3)
GROUP BY c.customer_id
HAVING COUNT(DISTINCT b.category_id) = 3;

/* Q62. */
SELECT * FROM customers.customers c
WHERE EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id)
  AND EXISTS (SELECT 1 FROM customers.reviews r WHERE r.customer_id = c.customer_id)
  AND EXISTS (SELECT 1 FROM support.tickets t WHERE t.customer_id = c.customer_id);

/* Q63. */
SELECT * FROM sales.orders
WHERE net_total > (SELECT AVG(net_total) FROM sales.orders);

/* Q64. */
SELECT * FROM products.products p
WHERE p.price > (SELECT AVG(p2.price) FROM products.products p2 WHERE p2.brand_id = p.brand_id);

/* Q65. */
SELECT * FROM sales.orders
WHERE cust_id IN (
  SELECT cust_id FROM sales.orders GROUP BY cust_id ORDER BY SUM(net_total) DESC LIMIT 10
);

/* Q66. */
SELECT * FROM stores.stores s
WHERE NOT EXISTS (
  SELECT 1 FROM sales.orders o WHERE o.store_id = s.store_id AND o.order_status = 'Returned'
);

/* Q67. */
SELECT * FROM support.tickets t
WHERE t.created_date::date IN (
  SELECT timestamp::date FROM audit.application_logs
  WHERE level IN ('ERROR', 'FATAL')
  GROUP BY timestamp::date
  HAVING COUNT(*) > 100
);

/* Q68. */
SELECT * FROM customers.customers c
WHERE EXISTS (
  SELECT 1 FROM customers.addresses a
  JOIN stores.stores s ON s.city = a.city
  WHERE a.customer_id = c.customer_id
);

/* Q69. */
SELECT * FROM products.products p
WHERE p.price > ANY (SELECT AVG(p2.price) FROM products.products p2 GROUP BY p2.brand_id);

/* Q70. */
SELECT * FROM customers.customers
WHERE customer_id NOT IN (SELECT cust_id FROM sales.orders WHERE cust_id IS NOT NULL);

/* Q71. */
SELECT * FROM customers.customers c
WHERE EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id AND o.net_total > 50000);

/* Q72. */
SELECT c.customer_id
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
JOIN sales.order_items oi ON oi.order_id = o.order_id
JOIN products.products p ON p.product_id = oi.prod_id
WHERE p.brand_id = 5
GROUP BY c.customer_id
HAVING COUNT(DISTINCT p.product_id) = (SELECT COUNT(*) FROM products.products WHERE brand_id = 5);

/* Q73. */
SELECT c.*
FROM customers.customers c
JOIN (
  SELECT cust_id, COUNT(*) AS n FROM sales.orders GROUP BY cust_id HAVING COUNT(*) >= 10
) t ON t.cust_id = c.customer_id;

/* Q74. */
SELECT * FROM customers.customers c
WHERE EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id)
  AND NOT EXISTS (
    SELECT 1 FROM sales.returns r
    JOIN sales.orders o2 ON o2.order_id = r.order_id
    WHERE o2.cust_id = c.customer_id
  );

/* Q75. */
SELECT brand_id FROM products.products GROUP BY brand_id HAVING MAX(price) < 20000;

/* Q76. */
SELECT * FROM sales.orders ORDER BY order_id LIMIT 50 OFFSET 4950;

/* Q77. */
SELECT * FROM sales.orders
WHERE order_id > 4950
ORDER BY order_id
LIMIT 50;

/* Q78. */
SELECT * FROM sales.orders
WHERE (order_date, order_id) > ('2025-06-01'::date, 5000)
ORDER BY order_date, order_id
LIMIT 50;

/* Q79. */
SELECT * FROM (
  SELECT * FROM sales.orders
  WHERE (order_date, order_id) < ('2025-06-01'::date, 5000)
  ORDER BY order_date DESC, order_id DESC
  LIMIT 50
) page
ORDER BY order_date, order_id;

/* Q80. */
SELECT * FROM sales.orders ORDER BY net_total DESC NULLS LAST;

/* Q81. */
SELECT * FROM support.tickets
ORDER BY CASE priority
           WHEN 'Critical' THEN 1
           WHEN 'High' THEN 2
           WHEN 'Medium' THEN 3
           WHEN 'Low' THEN 4
           ELSE 5
         END,
         created_date DESC;

/* Q82. */
SELECT cust_id, SUM(net_total) AS revenue
FROM sales.orders
GROUP BY cust_id
ORDER BY revenue DESC, cust_id ASC
LIMIT 20;

/* Q83. */
SELECT DISTINCT ON (cust_id) *
FROM sales.orders
ORDER BY cust_id, order_date DESC;

/* Q84. */
SELECT DISTINCT ON (product_id) *
FROM customers.reviews
ORDER BY product_id, review_date DESC;

/* Q85. */
SELECT * FROM customers.customers ORDER BY first_name COLLATE "C";

/* Q86. */
SELECT * FROM customers.customers
ORDER BY SPLIT_PART(email, '@', 2), email;

/* Q87. */
SELECT * FROM customers.customers ORDER BY phone::bigint;

/* Q88. */
SELECT o1.*
FROM sales.orders o1
LEFT JOIN sales.orders o2 ON o2.cust_id = o1.cust_id AND o2.net_total > o1.net_total
GROUP BY o1.order_id
HAVING COUNT(o2.order_id) < 3
ORDER BY o1.cust_id, o1.net_total DESC;

/* Q89. */
SELECT * FROM sales.orders o1
WHERE NOT EXISTS (
  SELECT 1 FROM sales.orders o2 WHERE o2.cust_id = o1.cust_id AND o2.net_total > o1.net_total
);

/* Q90. */
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

/* Q91. */
SELECT p1.*
FROM products.products p1
LEFT JOIN products.products p2 ON p2.brand_id = p1.brand_id AND p2.price > p1.price
GROUP BY p1.product_id
HAVING COUNT(p2.product_id) = 1;

/* Q92. */
SELECT * FROM customers.customers
WHERE (registration_date, customer_id) > ('2024-01-01'::date, 1000)
ORDER BY registration_date, customer_id
LIMIT 50;

/* Q93. */
SELECT * FROM customers.reviews
ORDER BY LENGTH(review_text) DESC;

/* Q94. */
SELECT s.store_id, s.store_name, SUM(o.net_total) AS revenue
FROM stores.stores s
JOIN sales.orders o ON o.store_id = s.store_id
GROUP BY s.store_id, s.store_name
ORDER BY revenue DESC, s.store_id ASC
LIMIT 10;

/* Q95. */
SELECT product_id, product_name,
       ROUND(100.0 * (price - cost_price) / NULLIF(price, 0), 2) AS margin_pct
FROM products.products
ORDER BY margin_pct ASC
LIMIT 10;

/* Q96. */
SELECT DISTINCT ON (store_id) *
FROM sales.orders
ORDER BY store_id, order_date ASC;

/* Q97. */
SELECT c.*
FROM customers.customers c
JOIN (
  SELECT cust_id, SUM(net_total) AS revenue
  FROM sales.orders
  GROUP BY cust_id
  HAVING SUM(net_total) > 50000
) t ON t.cust_id = c.customer_id
WHERE c.customer_id > 1000
ORDER BY c.customer_id
LIMIT 50;

/* Q98. */
SELECT * FROM support.tickets
WHERE status = 'Open' AND priority = 'Critical'
ORDER BY created_date DESC
LIMIT 50;

/* Q99. */
SELECT * FROM sales.orders TABLESAMPLE BERNOULLI(1);

/* Q100. */
SELECT DISTINCT ON (o.cust_id) o.*
FROM sales.orders o
WHERE o.order_status = 'Delivered' AND o.net_total > 5000
ORDER BY o.cust_id, o.order_date DESC;

/* ============================================================
   END OF ANSWER KEY - CRAZY LEVEL (100/100)
============================================================ */
