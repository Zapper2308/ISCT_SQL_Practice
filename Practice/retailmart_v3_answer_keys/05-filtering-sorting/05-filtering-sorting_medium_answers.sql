/* ============================================================
   ANSWER KEY - Filtering & Sorting (MEDIUM LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* Q1.  AND is evaluated first (higher precedence than OR), so `A AND B OR C` is `(A AND B) OR C`. */
/* Q2.  `NOT (col = 5)` is UNKNOWN (excluded) when col is NULL, same as `col != 5`; both exclude NULL rows identically - the real difference only shows up with more complex expressions, where NOT can flip a three-valued result differently than negating the operator directly. */
/* Q3.  TRUE, FALSE, or UNKNOWN - any comparison involving NULL yields UNKNOWN, and WHERE only keeps rows that evaluate to TRUE. */
/* Q4.  `col = NULL` always evaluates to UNKNOWN (never TRUE) because NULL is "unknown", not a comparable value; `col IS NULL` is a dedicated NULL test that returns TRUE/FALSE. */
/* Q5.  `IS DISTINCT FROM` treats NULL as a comparable value (two NULLs are "not distinct"), so it never returns UNKNOWN; `!=` returns UNKNOWN whenever either side is NULL. */
/* Q6.  No - IN treats NULL like `col = NULL` for each candidate, so it never matches on the NULL entry (a NULL in the list can only ever contribute UNKNOWN, never TRUE). */
/* Q7.  If the list contains a NULL and the tested value doesn't match any listed value, the whole expression becomes UNKNOWN instead of TRUE, so `NOT IN` silently returns ZERO rows instead of the expected non-matches. */
/* Q8.  `IS TRUE` explicitly tests for TRUE and treats NULL as not-true (returns FALSE, not UNKNOWN); `= TRUE` returns UNKNOWN when the column is NULL, excluding that row from the result the same way but via three-valued logic rather than a direct boolean test. */
/* Q9.  `LIKE '%abc%'` is generally faster - it's a native pattern match the planner understands, while `position(...) > 0` is a function call that usually can't use any pattern-matching index either, so on very large tables they perform similarly, but LIKE is idiomatic and can leverage trigram indexes if present. */
/* Q10. `LOWER(col) = 'priya'` requires computing LOWER() on every row before comparing, so a normal B-tree index on `col` cannot be used (the indexed values are the raw, unlowered text) - a functional index on `LOWER(col)` is needed to make it sargable again. */
/* Q11. BETWEEN date bounds are inclusive of the literal values given, so `BETWEEN '2025-01-01' AND '2025-01-31'` only catches midnight of Jan 31 - any TIMESTAMP with a time-of-day later than 00:00:00 on the 31st is excluded, unlike a half-open `>= AND <` range which can safely include the whole day. */
/* Q12. ESCAPE designates a character (here '\') as the escape marker, so `\%` in the pattern is treated as a literal percent sign instead of the LIKE wildcard. */
/* Q13. `ORDER BY 1` sorts by column position, which silently breaks if the SELECT list is reordered; `ORDER BY col_name` is explicit and safer for production code. */
/* Q14. Yes - each column in a multi-column ORDER BY can have its own direction, e.g. `ORDER BY price DESC, product_name ASC`. */
/* Q15. NULLS FIRST/LAST explicitly control where NULL values are placed in the sort order, overriding the engine's default placement. */
/* Q16. By default, NULLs sort LAST in ASC order and FIRST in DESC order. */
/* Q17. They are functionally identical - `FETCH FIRST n ROWS ONLY` is the SQL-standard syntax, `LIMIT n` is PostgreSQL's traditional (Postgres/MySQL-style) shorthand. */
/* Q18. The engine still has to scan and discard the first 1,000,000 rows before returning results, which gets slower as the offset grows; keyset (cursor-based) pagination using a WHERE condition on the last-seen key is the faster alternative. */
/* Q19. `DISTINCT` deduplicates entire rows; `DISTINCT ON (col)` keeps only the first row (per the ORDER BY) for each distinct value of `col`, letting other columns differ. */
/* Q20. Because TIMESTAMP columns capture down to microseconds, two rows that look identical to the eye can differ in that hidden precision and both survive DISTINCT, appearing as unexpected "duplicates". */
/* Q21. Keyset pagination filters on the last-seen row's key (e.g. `WHERE id > last_id ORDER BY id LIMIT n`) instead of skipping rows with OFFSET - it's faster because the index seeks directly to the next page instead of scanning and discarding prior rows. */
/* Q22. AND binds tighter than OR, so `WHERE tier = 'Gold' OR tier = 'Platinum' AND registration_date >= '2025-01-01'` actually means "Gold customers of any date, OR Platinum customers registered after 2025" - not what was probably intended; explicit parentheses `(tier = 'Gold' OR tier = 'Platinum') AND registration_date >= '2025-01-01'` fix it. */
/* Q23. Yes, `<>` is the SQL-standard not-equal operator and is fully equivalent to `!=` in PostgreSQL. */
/* Q24. `col1 = col2` returns UNKNOWN (excluded) whenever either column is NULL, even if both are NULL; `col1 IS NOT DISTINCT FROM col2` treats two NULLs as equal, returning TRUE in that case - it's the NULL-safe version of `=`. */
/* Q25. Without ORDER BY, the database is free to return rows in whatever physical/scan order is convenient, which can change between runs (parallel workers, caching, vacuum, etc.) - LIMIT alone never guarantees a stable subset. */

/* Q26. */
SELECT c.*
FROM customers.customers c
JOIN customers.addresses a ON a.customer_id = c.customer_id
WHERE c.tier = 'Gold'
  AND (a.city = 'Mumbai' OR a.city = 'Delhi')
  AND c.registration_date BETWEEN '2024-01-01' AND '2024-12-31';

/* Q27. */
SELECT * FROM support.tickets
WHERE priority IN ('Critical', 'High') AND status = 'Open';

/* Q28. */
SELECT * FROM customers.customers
WHERE tier IN ('Gold', 'Platinum') AND phone LIKE '+91 9%';

/* Q29. */
SELECT * FROM sales.orders
WHERE order_status != 'Delivered'
  AND order_status != 'Cancelled'
  AND order_date >= '2025-01-01' AND order_date < '2026-01-01';

/* Q30. */
SELECT * FROM products.products
WHERE price > 1000 AND cost_price > 500 AND brand_id NOT IN (1, 2);

/* Q31. */
SELECT * FROM stores.employees
WHERE salary > 50000 AND (role LIKE '%Manager%' OR role LIKE '%Director%');

/* Q32. */
SELECT * FROM call_center.calls
WHERE call_duration_seconds > 600 AND call_reason IN ('Complaint', 'Inquiry');

/* Q33. */
SELECT * FROM sales.shipments
WHERE delivered_date IS NULL AND shipped_date < CURRENT_DATE - 7;

/* Q34. */
SELECT * FROM support.tickets
WHERE created_date >= CURRENT_DATE - 7
  AND priority IN ('High', 'Critical')
  AND resolved_date IS NULL;

/* Q35. */
SELECT * FROM web_events.page_views
WHERE customer_id IS NULL
  AND device_type = 'Mobile'
  AND view_timestamp >= CURRENT_DATE - 30;

/* Q36. */
SELECT * FROM finance.expenses
WHERE amount > 100000
  AND expense_date >= '2025-01-01' AND expense_date < '2026-01-01'
  AND exp_cat_id IN (1, 2, 3, 4, 5);

/* Q37. */
SELECT * FROM loyalty.members
WHERE points_balance BETWEEN 500 AND 5000
  AND join_date < CURRENT_DATE - INTERVAL '1 year';

/* Q38. */
SELECT * FROM sales.returns
WHERE refund_amount > 5000 OR reason LIKE '%Defective%';

/* Q39. */
SELECT * FROM audit.application_logs
WHERE level IN ('ERROR', 'FATAL') AND timestamp >= CURRENT_DATE - 1;

/* Q40. */
SELECT * FROM audit.api_requests
WHERE status_code = 500
  AND endpoint LIKE '/api/v2/%'
  AND response_time_ms > 1000;

/* Q41. */
SELECT * FROM products.products
WHERE price > 5000 AND (brand_id IS NULL OR brand_id IN (1, 2));

/* Q42. */
SELECT * FROM customers.customers
WHERE (tier = 'Gold' OR tier = 'Platinum')
  AND (EXTRACT(YEAR FROM registration_date) = 2024 OR EXTRACT(YEAR FROM registration_date) = 2025);

/* Q43. */
SELECT * FROM stores.employees
WHERE salary > 80000 AND role NOT LIKE '%Intern%' AND store_id IS NOT NULL;

/* Q44. */
SELECT * FROM sales.orders
WHERE EXTRACT(DOW FROM order_date) IN (0, 6) AND net_total > 10000;

/* Q45. */
SELECT * FROM support.tickets
WHERE status = 'Open'
  AND priority IN ('High', 'Critical')
  AND (CURRENT_TIMESTAMP - created_date) > INTERVAL '24 hours';

/* Q46. */
SELECT * FROM customers.reviews
WHERE rating BETWEEN 1 AND 2 AND review_date >= CURRENT_DATE - 30;

/* Q47. */
SELECT * FROM sales.shipments
WHERE status = 'Delivered' AND (delivered_date - shipped_date) > 7;

/* Q48. */
SELECT * FROM customers.customers
WHERE tier IS DISTINCT FROM 'Bronze';

/* Q49. */
SELECT * FROM stores.stores
WHERE (square_ft > 5000) IS NOT TRUE;

/* Q50. */
SELECT * FROM sales.orders
WHERE (CURRENT_DATE - order_date) BETWEEN 7 AND 30;

/* Q51. */
SELECT * FROM customers.customers
WHERE first_name ILIKE 'a%' OR first_name ILIKE 'b%' OR first_name ILIKE 'c%';

/* Q52. */
SELECT * FROM customers.customers
WHERE email LIKE '%@gmail.com' OR email LIKE '%@yahoo.com';

/* Q53. */
SELECT * FROM products.products
WHERE product_name LIKE '%Pro%' AND product_name NOT LIKE '%Pro';

/* Q54. */
SELECT * FROM customers.customers
WHERE LENGTH(first_name) = 4;

/* Q55. */
SELECT * FROM products.products
WHERE product_name LIKE '___%';

/* Q56. */
SELECT * FROM customers.customers
WHERE email LIKE '%\_%' ESCAPE '\';

/* Q57. */
SELECT * FROM customers.customers
WHERE phone LIKE '+91 90%' OR phone LIKE '+91 91%' OR phone LIKE '+91 99%';

/* Q58. */
SELECT * FROM products.products
WHERE product_name ILIKE '_a%';

/* Q59. */
SELECT * FROM stores.stores
WHERE city LIKE '% %' AND city NOT LIKE '% % %';

/* Q60. */
SELECT * FROM stores.employees
WHERE email ~ '^[a-z]+\.[a-z]+@retailmart\.com$';

/* Q61. */
SELECT * FROM customers.customers
WHERE email NOT LIKE '%@gmail.com' AND email NOT LIKE '%@yahoo.com';

/* Q62. */
SELECT * FROM products.products
WHERE product_name ~ '[0-9]';

/* Q63. */
SELECT * FROM customers.customers
WHERE (LENGTH(first_name) - LENGTH(REGEXP_REPLACE(first_name, '[aeiouAEIOU]', '', 'g'))) = 2;

/* Q64. */
SELECT * FROM sales.shipments
WHERE delivered_date IS NULL AND status != 'Cancelled';

/* Q65. */
SELECT * FROM support.tickets
WHERE resolved_date IS NULL AND priority = 'Critical' AND created_date < CURRENT_DATE - 2;

/* Q66. */
SELECT * FROM customers.customers
WHERE phone IS NOT NULL AND LENGTH(phone) != 14;

/* Q67. */
SELECT * FROM products.products
WHERE supplier_id IS NULL AND price > 5000;

/* Q68. */
SELECT * FROM web_events.page_views
WHERE customer_id IS NULL AND device_type = 'Mobile';

/* Q69. */
SELECT * FROM finance.payments
WHERE order_id IS NOT NULL AND amount IS NULL;

/* Q70. */
SELECT * FROM customers.customers
WHERE tier_updated_at IS DISTINCT FROM registration_date::timestamp;

/* Q71. */
SELECT * FROM sales.returns
WHERE refund_amount IS NULL;

/* Q72. */
SELECT * FROM stores.employees
WHERE store_id IS NULL OR dept_id IS NULL;

/* Q73. */
SELECT * FROM customers.customers
WHERE email LIKE '%@%.%';

/* Q74. */
SELECT * FROM products.products
WHERE product_name LIKE '%\%%' ESCAPE '\';

/* Q75. */
SELECT * FROM support.tickets
WHERE subject ~ '^[0-9]';

/* Q76. */
SELECT * FROM products.products ORDER BY price DESC, product_name ASC LIMIT 10;

/* Q77. */
SELECT * FROM stores.employees ORDER BY salary ASC, joining_date DESC LIMIT 10;

/* Q78. */
SELECT * FROM sales.orders ORDER BY order_date DESC NULLS LAST, net_total DESC;

/* Q79. */
SELECT * FROM customers.customers ORDER BY registration_date DESC LIMIT 20 OFFSET 60;

/* Q80. */
SELECT * FROM products.products ORDER BY price DESC LIMIT 20 OFFSET 120;

/* Q81. */
SELECT * FROM sales.orders
WHERE net_total > 5000
ORDER BY order_date DESC
LIMIT 25 OFFSET 0;

/* Q82. */
SELECT city, COUNT(*) AS store_count FROM stores.stores GROUP BY city ORDER BY store_count DESC LIMIT 5;

/* Q83. */
SELECT * FROM support.tickets ORDER BY created_date DESC LIMIT 10;

/* Q84. */
SELECT DISTINCT ON (device_type) *
FROM web_events.page_views
ORDER BY device_type, view_timestamp DESC;

/* Q85. */
SELECT DISTINCT ON (cust_id) *
FROM sales.orders
ORDER BY cust_id, order_date DESC;

/* Q86. */
SELECT * FROM products.products ORDER BY price DESC LIMIT 1 OFFSET 49;

/* Q87. */
SELECT * FROM customers.customers ORDER BY registration_date ASC LIMIT 1 OFFSET 99;

/* Q88. */
SELECT tier, COUNT(*) AS member_count FROM customers.customers GROUP BY tier ORDER BY member_count DESC LIMIT 3;

/* Q89. */
SELECT DISTINCT courier_name FROM sales.shipments ORDER BY courier_name;

/* Q90. */
SELECT * FROM call_center.calls
WHERE call_start_time >= CURRENT_DATE - 30
ORDER BY call_duration_seconds DESC
LIMIT 10;

/* Q91. */
SELECT * FROM sales.orders ORDER BY net_total DESC NULLS LAST;

/* Q92. */
SELECT * FROM products.products ORDER BY price DESC, product_id ASC;

/* Q93. */
SELECT * FROM stores.stores ORDER BY opening_date ASC LIMIT 10;

/* Q94. */
SELECT * FROM marketing.ads_spend ORDER BY platform ASC, spend_date DESC LIMIT 20;

/* Q95. */
SELECT * FROM web_events.page_views
WHERE device_type = 'Mobile'
ORDER BY view_timestamp DESC
LIMIT 5 OFFSET 0;

/* Q96. */
SELECT * FROM sales.orders
WHERE order_date < '2025-06-01'::date
ORDER BY order_date DESC
LIMIT 20;

/* Q97. */
SELECT brand_id, COUNT(*) AS product_count FROM products.products GROUP BY brand_id ORDER BY product_count DESC LIMIT 5;

/* Q98. */
SELECT * FROM customers.customers
WHERE first_name IS NOT NULL
ORDER BY registration_date DESC
LIMIT 10;

/* Q99. */
SELECT * FROM finance.expenses
WHERE expense_date >= '2025-01-01' AND expense_date < '2026-01-01'
ORDER BY amount DESC
LIMIT 10;

/* Q100. */
SELECT * FROM sales.shipments
WHERE shipped_date IS NOT NULL
ORDER BY shipped_date DESC
LIMIT 25;

/* ============================================================
   END OF ANSWER KEY - MEDIUM LEVEL (100/100)
============================================================ */
