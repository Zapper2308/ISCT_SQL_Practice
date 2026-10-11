/* ============================================================
   ANSWER KEY - Data Quality, Deduplication & Cleansing (EASY LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* Q1.  A "duplicate" by logical key means two rows share the same business identity (e.g. same email); a duplicate "full row" means every column value matches exactly - the former is what dedup usually targets. */
/* Q2.  Grouping by the candidate key and filtering HAVING COUNT(*) > 1 directly surfaces every key value that has more than one row, which is the definition of a duplicate group. */
/* Q3.  It assigns a sequential rank (1, 2, 3...) to each row within each key partition, ordered by the recency column - the most recent row typically gets rn = 1. */
/* Q4.  Because you can order by whatever "best" means (latest date, highest value) and simply keep the row where rn = 1, discarding the rest as losers. */
/* Q5.  DISTINCT collapses fully-identical rows across all selected columns; DISTINCT ON (key) keeps exactly one row per key value, chosen by the ORDER BY - it does not require the whole row to match. */
/* Q6.  It returns the first non-NULL value in the argument list, left to right. */
/* Q7.  It returns NULL if a and b are equal, otherwise it returns a. */
/* Q8.  IS DISTINCT FROM treats two NULLs as equal (not distinct) and NULL vs a value as distinct, giving a proper boolean instead of <>'s NULL result when either side is NULL. */
/* Q9.  Drop the row/value, replace it with a default (COALESCE), or flag it in a separate quality column for review - each fits a different business need. */
/* Q10. Free text often differs only in surrounding whitespace or case (" Nike " vs "nike"), so TRIM removes padding and LOWER removes case sensitivity before any equality comparison. */
/* Q11. It returns the string s with every match of the regex pattern pat replaced by repl. */
/* Q12. ~ performs a case-sensitive POSIX regex match; ~* performs the same match ignoring case. */
/* Q13. Phone numbers arrive with different country-code prefixes, separators (spaces, dashes, brackets) and lengths depending on source system, so raw string equality rarely matches the same number. */
/* Q14. Email is meant to be unique per person but commonly has case differences, trailing spaces, or plus-tag variants, making it a natural (if imperfect) dedup key. */
/* Q15. A cluster of NULLs is a concentration of missing values in one column, often within a specific time window/segment - flagging it can reveal an upstream collection or ETL bug rather than random missingness. */
/* Q16. A suspicious value falls outside the range a business rule or historical distribution would predict (e.g. a negative price, or an order 100x the typical size). */
/* Q17. A price rarely legitimately doubles or halves overnight, so a >50% single-event jump is far more likely a fat-fingered entry than a real repricing decision. */
/* Q18. Canonicalization means transforming free text into one standard, comparable form (lowercase, trimmed, punctuation/space-normalized) so equivalent values compare equal. */
/* Q19. DISTINCT ON (key) ORDER BY key, <recency/quality columns> picks the first row per key in that sort order - so ordering recency DESC keeps the newest row per key automatically. */
/* Q20. Because DELETE permanently destroys rows on a table you don't own/can't restore, whereas a view or CTE simply presents the deduplicated result without touching the underlying (read-only) data. */
/* Q21. Cleansing actively fixes/transforms bad data (standardizing, deduping, backfilling); validation only checks whether data meets rules and reports pass/fail without changing anything. */
/* Q22. COUNT(*) counts all rows regardless of NULLs; COUNT(col) counts only rows where col is NOT NULL, so the two diverge whenever col has missing values. */
/* Q23. Reconciliation is comparing two near-duplicate lists (e.g. two systems' customer exports) to find records that represent the same entity but differ in representation. */
/* Q24. Without a baseline you have nothing to measure "far from normal" against - a fixed threshold can't tell a legitimately high-value region from an anomaly in a low-value one. */
/* Q25. Duplicate customer emails, orders with discount > gross_total, and shipments delivered before they were shipped are all worth automating per the RetailMart context. */

/* Q26. */
SELECT email, COUNT(*) AS n
FROM customers.customers
GROUP BY email
HAVING COUNT(*) > 1;

/* Q27. */
SELECT first_name, last_name, COUNT(*) AS n
FROM customers.customers
GROUP BY first_name, last_name
HAVING COUNT(*) > 1;

/* Q28. */
SELECT brand_id, product_name, COUNT(*) AS n
FROM products.products
GROUP BY brand_id, product_name
HAVING COUNT(*) > 1;

/* Q29. */
SELECT LOWER(supplier_name) AS name_lc, COUNT(*) AS n
FROM products.suppliers
GROUP BY LOWER(supplier_name)
HAVING COUNT(*) > 1;

/* Q30. (stores.stores has no separate address column, so city + store_name is used as the duplicate key) */
SELECT city, store_name, COUNT(*) AS n
FROM stores.stores
GROUP BY city, store_name
HAVING COUNT(*) > 1;

/* Q31. */
SELECT cust_id, order_date, net_total, COUNT(*) AS n
FROM sales.orders
GROUP BY cust_id, order_date, net_total
HAVING COUNT(*) > 1;

/* Q32. */
SELECT customer_id, product_id, COUNT(*) AS n
FROM customers.reviews
GROUP BY customer_id, product_id
HAVING COUNT(*) > 1;

/* Q33. */
SELECT customer_id, subject, COUNT(*) AS n
FROM support.tickets
GROUP BY customer_id, subject
HAVING COUNT(*) > 1;

/* Q34. */
SELECT order_id, amount, COUNT(*) AS n
FROM sales.payments
GROUP BY order_id, amount
HAVING COUNT(*) > 1;

/* Q35. */
SELECT customer_id, page_url, view_timestamp, COUNT(*) AS n
FROM web_events.page_views
GROUP BY customer_id, page_url, view_timestamp
HAVING COUNT(*) > 1;

/* Q36. */
SELECT brand_name
FROM core.dim_brand
WHERE brand_name <> RTRIM(brand_name);

/* Q37. */
SELECT LOWER(email) AS email_lc, COUNT(DISTINCT email) AS variant_ct
FROM customers.customers
GROUP BY LOWER(email)
HAVING COUNT(DISTINCT email) > 1;

/* Q38. */
SELECT c.customer_id, c.email, c.registration_date,
       ROW_NUMBER() OVER (PARTITION BY c.email ORDER BY c.registration_date DESC) AS rn
FROM customers.customers c
WHERE c.email IN (SELECT email FROM customers.customers GROUP BY email HAVING COUNT(*) > 1);

/* Q39. */
WITH ranked AS (
  SELECT c.*, ROW_NUMBER() OVER (PARTITION BY c.email ORDER BY c.registration_date DESC) AS rn
  FROM customers.customers c
  WHERE c.email IN (SELECT email FROM customers.customers GROUP BY email HAVING COUNT(*) > 1)
)
SELECT * FROM ranked WHERE rn = 1;

/* Q40. */
WITH order_counts AS (
  SELECT cust_id, COUNT(*) AS order_ct FROM sales.orders GROUP BY cust_id
),
ranked AS (
  SELECT c.customer_id, c.first_name, c.last_name, COALESCE(oc.order_ct,0) AS order_ct,
         ROW_NUMBER() OVER (PARTITION BY c.first_name, c.last_name ORDER BY COALESCE(oc.order_ct,0) DESC) AS rn
  FROM customers.customers c
  JOIN (SELECT first_name, last_name FROM customers.customers GROUP BY first_name, last_name HAVING COUNT(*) > 1) d
    ON d.first_name = c.first_name AND d.last_name = c.last_name
  LEFT JOIN order_counts oc ON oc.cust_id = c.customer_id
)
SELECT * FROM ranked WHERE rn = 1;

/* Q41. */
SELECT DISTINCT ON (email) *
FROM customers.customers
ORDER BY email, registration_date DESC;

/* Q42. */
SELECT
  (SELECT COUNT(*) FROM (SELECT email FROM customers.customers GROUP BY email HAVING COUNT(*) > 1) e) AS email_dupe_groups,
  (SELECT COUNT(*) FROM (SELECT phone FROM customers.customers WHERE phone IS NOT NULL GROUP BY phone HAVING COUNT(*) > 1) p) AS phone_dupe_groups;

/* Q43. */
SELECT product_name, brand_id, COUNT(DISTINCT supplier_id) AS supplier_ct
FROM products.products
GROUP BY product_name, brand_id
HAVING COUNT(DISTINCT supplier_id) > 1;

/* Q44. */
SELECT warehouse_id, product_id, snapshot_date, COUNT(*) AS n
FROM supply_chain.inventory_snapshots
GROUP BY warehouse_id, product_id, snapshot_date
HAVING COUNT(*) > 1;

/* Q45. */
SELECT line_id, start_timestamp, COUNT(*) AS n
FROM manufacture.work_orders
GROUP BY line_id, start_timestamp
HAVING COUNT(*) > 1;

/* Q46. */
SELECT customer_id, address_line, COUNT(*) AS n
FROM customers.addresses
GROUP BY customer_id, address_line
HAVING COUNT(*) > 1;

/* Q47. */
SELECT employee_id, salary_month, salary_year, COUNT(*) AS n
FROM payroll.pay_slips
GROUP BY employee_id, salary_month, salary_year
HAVING COUNT(*) > 1;

/* Q48. */
SELECT product_id, review_text, COUNT(*) AS n
FROM customers.reviews
WHERE review_text IS NOT NULL
GROUP BY product_id, review_text
HAVING COUNT(*) > 1;

/* Q49. */
SELECT product_id, LOWER(TRIM(review_text)) AS canon_text, COUNT(*) AS n
FROM customers.reviews
WHERE review_text IS NOT NULL
GROUP BY product_id, LOWER(TRIM(review_text))
HAVING COUNT(*) > 1;

/* Q50. */
WITH ranked AS (
  SELECT customer_id, email, ROW_NUMBER() OVER (PARTITION BY email ORDER BY registration_date DESC) AS rn
  FROM customers.customers
)
SELECT customer_id, email FROM ranked WHERE rn > 1;

/* Q51. */
SELECT review_id, COALESCE(review_text, '(no comment)') AS review_text
FROM customers.reviews;

/* Q52. (audit.record_changes has no error_message column - the closest real error_message field is on audit.procedure_calls) */
SELECT call_id, COALESCE(error_message, '(none)') AS error_message
FROM audit.procedure_calls;

/* Q53. */
SELECT review_id, NULLIF(review_text, '') AS review_text
FROM customers.reviews;

/* Q54. */
SELECT COUNT(*) AS not_delivered_null_safe
FROM sales.orders
WHERE order_status IS DISTINCT FROM 'Delivered';

/* Q55. */
SELECT review_id, LOWER(TRIM(review_text)) AS cleaned
FROM customers.reviews
WHERE review_text IS NOT NULL;

/* Q56. */
SELECT brand_id, TRIM(brand_name) AS cleaned
FROM core.dim_brand;

/* Q57. */
SELECT review_id, REGEXP_REPLACE(review_text, '\s+', ' ', 'g') AS cleaned
FROM customers.reviews
WHERE review_text IS NOT NULL;

/* Q58. */
SELECT review_id, REGEXP_REPLACE(review_text, '^[[:punct:]]+|[[:punct:]]+$', '', 'g') AS cleaned
FROM customers.reviews
WHERE review_text IS NOT NULL;

/* Q59. */
SELECT customer_id, email, LOWER(TRIM(email)) AS cleaned_email
FROM customers.customers
WHERE email <> LOWER(TRIM(email));

/* Q60. */
SELECT product_id, product_name
FROM products.products
WHERE product_name ~ '^iPhone';

/* Q61. */
SELECT brand_id, brand_name
FROM core.dim_brand
WHERE brand_name ~* 'samsung';

/* Q62. */
SELECT review_id, review_text
FROM customers.reviews
WHERE review_text ~ '^\s*$';

/* Q63. */
SELECT customer_id, email
FROM customers.customers
WHERE email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$';

/* Q64. */
SELECT review_id, REGEXP_REPLACE(review_text, '\d', '#', 'g') AS masked
FROM customers.reviews
WHERE review_text IS NOT NULL;

/* Q65. */
SELECT customer_id, REGEXP_REPLACE(phone, '\D', '', 'g') AS digits_only
FROM customers.customers
WHERE phone IS NOT NULL;

/* Q66. */
SELECT customer_id, '+91' || RIGHT(REGEXP_REPLACE(phone, '\D', '', 'g'), 10) AS phone_e164
FROM customers.customers
WHERE phone IS NOT NULL AND LENGTH(REGEXP_REPLACE(phone, '\D', '', 'g')) >= 10;

/* Q67. */
SELECT customer_id, first_name
FROM customers.customers
WHERE first_name <> TRIM(first_name);

/* Q68. */
SELECT EXTRACT(YEAR FROM registration_date)::int AS reg_year,
       COUNT(*) FILTER (WHERE phone IS NULL) AS null_phone_ct,
       COUNT(*) AS total_customers
FROM customers.customers
GROUP BY 1
ORDER BY 1;

/* Q69. (customers has no region column directly; region is derived by joining the default address's state to core.dim_region) */
SELECT a.customer_id, COALESCE(r.region_name, 'Unknown') AS region
FROM customers.addresses a
LEFT JOIN core.dim_region r ON r.state = a.state;

/* Q70. */
SELECT dc.category_name,
       COUNT(*) AS total_products,
       COUNT(p.price) AS priced_products
FROM products.products p
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category dc ON dc.category_id = b.category_id
GROUP BY dc.category_name
ORDER BY dc.category_name;

/* Q71. */
SELECT order_id, gross_total, net_total
FROM sales.orders
WHERE gross_total IS DISTINCT FROM net_total;

/* Q72. (stores.stores has no address column; store_name is standardized instead) */
SELECT store_id, LOWER(REGEXP_REPLACE(TRIM(store_name), '\s+', ' ', 'g')) AS cleaned_name
FROM stores.stores;

/* Q73. */
SELECT review_id,
       review_text AS original,
       LOWER(REGEXP_REPLACE(TRIM(review_text), '\s+', ' ', 'g')) AS cleaned
FROM customers.reviews
WHERE review_text IS NOT NULL;

/* Q74. */
SELECT customer_id, first_name
FROM customers.customers
WHERE first_name ~ '^[A-Z]+$';

/* Q75. */
SELECT product_id, product_name
FROM products.products
WHERE product_name ~ '[^\x00-\x7F]';

/* Q76. */
SELECT order_id, gross_total
FROM sales.orders
WHERE gross_total > 100000;

/* Q77. */
SELECT order_id, discount_amount, gross_total
FROM sales.orders
WHERE discount_amount > gross_total;

/* Q78. */
SELECT product_id, product_name, price, cost_price
FROM products.products
WHERE price < cost_price;

/* Q79. */
SELECT change_id, record_id, old_value, new_value,
       (new_value::numeric - old_value::numeric) / NULLIF(old_value::numeric, 0) AS pct_change
FROM audit.record_changes
WHERE table_name = 'products' AND column_name = 'price'
  AND ABS((new_value::numeric - old_value::numeric) / NULLIF(old_value::numeric, 0)) > 0.5;

/* Q80. */
SELECT change_id, record_id, old_value, new_value,
       (new_value::numeric - old_value::numeric) / NULLIF(old_value::numeric, 0) AS pct_change
FROM audit.record_changes
WHERE table_name = 'employees' AND column_name = 'salary'
  AND ABS((new_value::numeric - old_value::numeric) / NULLIF(old_value::numeric, 0)) > 0.3;

/* Q81. */
SELECT pay_slip_id, employee_id, net_salary
FROM payroll.pay_slips
WHERE net_salary < 1000 OR net_salary > 200000;

/* Q82. */
SELECT review_id, rating
FROM customers.reviews
WHERE rating NOT BETWEEN 1 AND 5;

/* Q83. */
SELECT ticket_id, created_date, resolved_date
FROM support.tickets
WHERE resolved_date < created_date;

/* Q84. */
SELECT shipment_id, shipped_date, delivered_date
FROM sales.shipments
WHERE delivered_date < shipped_date;

/* Q85. */
SELECT o.order_id, o.order_date, c.registration_date
FROM sales.orders o
JOIN customers.customers c ON c.customer_id = o.cust_id
WHERE o.order_date < c.registration_date;

/* Q86. */
SELECT 'gross_total_gt_100k' AS rule, COUNT(*) AS fail_ct FROM sales.orders WHERE gross_total > 100000
UNION ALL
SELECT 'discount_gt_gross', COUNT(*) FROM sales.orders WHERE discount_amount > gross_total
UNION ALL
SELECT 'price_lt_cost', COUNT(*) FROM products.products WHERE price < cost_price
UNION ALL
SELECT 'rating_out_of_range', COUNT(*) FROM customers.reviews WHERE rating NOT BETWEEN 1 AND 5
UNION ALL
SELECT 'ticket_resolved_before_created', COUNT(*) FROM support.tickets WHERE resolved_date < created_date
UNION ALL
SELECT 'shipment_delivered_before_shipped', COUNT(*) FROM sales.shipments WHERE delivered_date < shipped_date;

/* Q87. */
SELECT LOWER(TRIM(product_name)) AS canon_name, COUNT(DISTINCT product_name) AS variant_ct,
       array_agg(DISTINCT product_name) AS variants
FROM products.products
GROUP BY LOWER(TRIM(product_name))
HAVING COUNT(DISTINCT product_name) > 1;

/* Q88. */
SELECT LOWER(TRIM(brand_name)) AS canon_name, COUNT(DISTINCT brand_name) AS variant_ct,
       array_agg(DISTINCT brand_name) AS variants
FROM core.dim_brand
GROUP BY LOWER(TRIM(brand_name))
HAVING COUNT(DISTINCT brand_name) > 1;

/* Q89. */
SELECT LOWER(email) AS email_lc, phone, COUNT(*) AS n
FROM customers.customers
WHERE phone IS NOT NULL
GROUP BY LOWER(email), phone
HAVING COUNT(*) > 1;

/* Q90. */
SELECT r.region_name,
       ROUND(100.0 * COUNT(*) FILTER (WHERE c.phone IS NULL) / COUNT(*), 2) AS pct_null_phone
FROM customers.customers c
JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = true
JOIN core.dim_region r ON r.state = a.state
GROUP BY r.region_name
ORDER BY r.region_name;

/* Q91. (products.products has no description column; cost_price nulls are used as the closest analogous missing-value check) */
SELECT dc.category_name,
       ROUND(100.0 * COUNT(*) FILTER (WHERE p.cost_price IS NULL) / COUNT(*), 2) AS pct_missing_cost_price
FROM products.products p
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category dc ON dc.category_id = b.category_id
GROUP BY dc.category_name
ORDER BY dc.category_name;

/* Q92. */
SELECT rc.change_id, p.product_name, rc.old_value, rc.new_value,
       (rc.new_value::numeric - rc.old_value::numeric) / NULLIF(rc.old_value::numeric, 0) AS pct_change
FROM audit.record_changes rc
JOIN products.products p ON p.product_id = rc.record_id
WHERE rc.table_name = 'products' AND rc.column_name = 'price'
  AND ABS((rc.new_value::numeric - rc.old_value::numeric) / NULLIF(rc.old_value::numeric, 0)) > 0.5;

/* Q93. */
SELECT o.order_id
FROM sales.orders o
LEFT JOIN sales.payments p ON p.order_id = o.order_id
WHERE o.order_status = 'Delivered' AND p.payment_id IS NULL;

/* Q94. */
SELECT s.store_id, s.store_name
FROM stores.stores s
LEFT JOIN sales.orders o ON o.store_id = s.store_id
WHERE o.order_id IS NULL;

/* Q95. */
SELECT p.product_id, p.product_name
FROM products.products p
LEFT JOIN products.inventory i ON i.product_id = p.product_id
WHERE i.product_id IS NULL;

/* Q96. */
SELECT employee_id, first_name, last_name
FROM stores.employees
WHERE dept_id IS NULL;

/* Q97. */
SELECT o.order_id, o.net_total, SUM(oi.net_amount) AS items_net_total
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id, o.net_total
HAVING o.net_total IS DISTINCT FROM SUM(oi.net_amount);

/* Q98. */
SELECT COALESCE(f.order_id, s.order_id) AS order_id,
       COALESCE(f.finance_total, 0) AS finance_total,
       COALESCE(s.sales_total, 0) AS sales_total
FROM (SELECT order_id, SUM(amount) AS finance_total FROM finance.payments GROUP BY order_id) f
FULL JOIN (SELECT order_id, SUM(amount) AS sales_total FROM sales.payments GROUP BY order_id) s
  ON s.order_id = f.order_id
WHERE COALESCE(f.finance_total, 0) IS DISTINCT FROM COALESCE(s.sales_total, 0);

/* Q99. */
SELECT LOWER(TRIM(city)) AS canon_city, COUNT(DISTINCT city) AS variant_ct, array_agg(DISTINCT city) AS variants
FROM customers.addresses
GROUP BY LOWER(TRIM(city))
HAVING COUNT(DISTINCT city) > 1;

/* Q100. */
SELECT 'customers_null_phone_pct' AS rule,
       ROUND(100.0 * COUNT(*) FILTER (WHERE phone IS NULL) / COUNT(*), 2) AS pct_failed
FROM customers.customers
UNION ALL
SELECT 'orders_discount_gt_gross_pct',
       ROUND(100.0 * COUNT(*) FILTER (WHERE discount_amount > gross_total) / COUNT(*), 2)
FROM sales.orders
UNION ALL
SELECT 'orders_gross_gt_100k_pct',
       ROUND(100.0 * COUNT(*) FILTER (WHERE gross_total > 100000) / COUNT(*), 2)
FROM sales.orders;
