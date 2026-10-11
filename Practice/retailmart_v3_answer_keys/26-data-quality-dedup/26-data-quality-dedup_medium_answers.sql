/* ============================================================
   ANSWER KEY - Data Quality, Deduplication & Cleansing (MEDIUM LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* Q1.  A single-column key is right when one field is truly unique to an entity (a verified email); a composite key is right when uniqueness only holds across a combination (customer_id + order_date + amount for a double-submit check). */
/* Q2.  Canonicalize first (LOWER, TRIM, collapse internal whitespace) then GROUP BY the canonical form - otherwise cosmetic differences hide real duplicates from the grouping. */
/* Q3.  Both give the same "keep most recent" result; DISTINCT ON is usually more concise and lets Postgres use an index-backed skip scan, while ROW_NUMBER is more flexible when you need every row's rank, not just the winner. */
/* Q4.  Without a deterministic secondary ORDER BY column (like a numeric id), rows tied on the primary sort key can be returned in a different order each run, making "which row survives" non-repeatable. */
/* Q5.  IS DISTINCT FROM returns true only when two values are genuinely different, treating NULL = NULL as not-distinct; IS NOT DISTINCT FROM is its inverse, true when values match (including NULL = NULL). */
/* Q6.  COALESCE(a.x,'') = COALESCE(b.x,'') lets NULL keys match each other, catching more potential matches, at the cost of possibly creating false-positive joins between two genuinely-missing values. */
/* Q7.  A soft-delete tag (a status/flag column) keeps the row and its history for audit while hiding it from normal queries; a hard DELETE removes it permanently and is irreversible without a backup. */
/* Q8.  Instead of deleting or silently fixing bad rows, a quarantine query SELECTs them into a reviewable result set so a human can confirm the fix before anything is changed. */
/* Q9.  A baseline-driven anomaly compares a value to the median, a percentile (P95), or an IQR fence computed from the data itself, rather than to a number picked out of thin air. */
/* Q10. A fixed threshold like ">100k" stops being meaningful as prices/revenue naturally grow over time or differ across regions; a benchmark relative to a rolling percentile adapts automatically. */
/* Q11. ^ anchors a match to the start of the string and $ to the end, so the whole string (not just a substring anywhere in it) must satisfy the pattern. */
/* Q12. [] defines a set of allowed characters at that position; *, +, ? mean "0 or more", "1 or more", "0 or 1" repetitions of the preceding token; {m,n} means between m and n repetitions. */
/* Q13. A greedy quantifier matches as much text as possible before backtracking; a lazy quantifier (with a trailing ?) matches as little as possible - relevant when a pattern could match multiple lengths. */
/* Q14. Parentheses capture part of a match into a numbered group, and \1, \2 (or backreferences) in the replacement text can reuse that captured text. */
/* Q15. Some "space-like" Unicode characters (non-breaking space U+00A0, various Unicode space separators) are not stripped by a plain TRIM, which only removes ASCII spaces by default. */
/* Q16. Lowercase the address, trim it, and strip a "+tag" segment before the @ (e.g. "user+promo@x.com" -> "user@x.com") so tagged variants of the same mailbox are treated as one. */
/* Q17. Strip all non-digit characters, keep the last 10 digits (the local number), then prefix the country code - this normalizes numbers written with different separators/prefixes to one form. */
/* Q18. FULL OUTER JOIN two lists on their canonical key so you see matches, left-only rows, and right-only rows in one pass - exactly what's needed to reconcile two near-duplicate sources. */
/* Q19. A scorecard pivots (rule x dimension) so each cell shows the pass rate for that rule in that segment, making it easy to spot which dimension is driving failures for a given rule. */
/* Q20. A single global threshold either misses anomalies in low-value groups or over-flags normal values in high-value groups; a per-group baseline (e.g. per-region P95) judges each group by its own normal range. */
/* Q21. Group NULL rates by a time or region dimension - a spike in NULLs concentrated in one month or one region points to a specific upstream cause (a form change, a broken feed) rather than general noise. */
/* Q22. Free text captured by different users/systems often uses non-standard spellings for the same real-world value ("Maharastra" vs "Maharashtra"), which breaks exact-match joins and groupings. */
/* Q23. Fixing bad data once at ETL/load time means every downstream query automatically gets clean data, instead of every analyst repeating the same cleansing logic (and risking inconsistency) in every query. */
/* Q24. A cleaned view/materialized view is worth building once source data is stable and the same cleansing logic is reused by many downstream queries - covered fully on Day 25. */
/* Q25. Cohort/RFM/funnel metrics (Day 27) are only as trustworthy as the customers/orders rows feeding them - duplicate customers or bad order dates directly distort retention and RFM scores. */

/* Q26. */
WITH ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY registration_date DESC) AS rn
  FROM customers.customers
)
SELECT * FROM ranked WHERE rn = 1;

/* Q27. */
WITH order_counts AS (
  SELECT cust_id, COUNT(*) AS order_ct FROM sales.orders GROUP BY cust_id
),
ranked AS (
  SELECT c.*, COALESCE(oc.order_ct,0) AS order_ct,
         ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(c.email)), c.phone ORDER BY COALESCE(oc.order_ct,0) DESC) AS rn
  FROM customers.customers c
  LEFT JOIN order_counts oc ON oc.cust_id = c.customer_id
)
SELECT * FROM ranked WHERE rn = 1;

/* Q28. */
WITH revenue AS (
  SELECT prod_id, SUM(net_amount) AS revenue FROM sales.order_items GROUP BY prod_id
),
ranked AS (
  SELECT p.*, COALESCE(r.revenue,0) AS revenue,
         ROW_NUMBER() OVER (PARTITION BY p.brand_id, LOWER(p.product_name) ORDER BY COALESCE(r.revenue,0) DESC) AS rn
  FROM products.products p
  LEFT JOIN revenue r ON r.prod_id = p.product_id
)
SELECT * FROM ranked WHERE rn = 1;

/* Q29. (suppliers have no activity-date column, so "most recently active" is approximated by most recent shipment) */
WITH last_active AS (
  SELECT supplier_id, MAX(shipped_date) AS last_ship
  FROM supply_chain.shipments GROUP BY supplier_id
),
ranked AS (
  SELECT s.*, la.last_ship,
         ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(s.supplier_name)) ORDER BY la.last_ship DESC NULLS LAST) AS rn
  FROM products.suppliers s
  LEFT JOIN last_active la ON la.supplier_id = s.supplier_id
)
SELECT * FROM ranked WHERE rn = 1;

/* Q30. */
WITH ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY customer_id, product_id ORDER BY review_date DESC) AS rn
  FROM customers.reviews
)
SELECT * FROM ranked WHERE rn = 1;

/* Q31. */
WITH ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY customer_id, subject, created_date::date ORDER BY created_date) AS rn
  FROM support.tickets
)
SELECT * FROM ranked WHERE rn = 1;

/* Q32. */
WITH ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY cust_id, order_date, net_total ORDER BY order_id) AS rn
  FROM sales.orders
)
SELECT * FROM ranked WHERE rn = 1;

/* Q33. */
WITH ranked AS (
  SELECT *, ROW_NUMBER() OVER (
    PARTITION BY customer_id, session_id, page_url
    ORDER BY view_timestamp
  ) AS rn,
  LAG(view_timestamp) OVER (PARTITION BY customer_id, session_id, page_url ORDER BY view_timestamp) AS prev_ts
  FROM web_events.page_views
)
SELECT * FROM ranked
WHERE rn = 1 OR view_timestamp - prev_ts > INTERVAL '1 second';

/* Q34. */
WITH ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY customer_id, LOWER(TRIM(address_line)) ORDER BY address_id DESC) AS rn
  FROM customers.addresses
)
SELECT * FROM ranked WHERE rn = 1;

/* Q35. */
SELECT warehouse_id, product_id, snapshot_date, COUNT(*) AS n
FROM supply_chain.inventory_snapshots
GROUP BY warehouse_id, product_id, snapshot_date
HAVING COUNT(*) > 1;

/* Q36. */
WITH canon AS (
  SELECT brand_id, LOWER(REGEXP_REPLACE(TRIM(brand_name), '\s+', ' ', 'g')) AS canon_name
  FROM core.dim_brand
)
SELECT canon_name, COUNT(*) AS n, array_agg(brand_id) AS brand_ids
FROM canon
GROUP BY canon_name
HAVING COUNT(*) > 1;

/* Q37. */
SELECT DISTINCT ON (LOWER(TRIM(email))) *
FROM customers.customers
ORDER BY LOWER(TRIM(email)), registration_date DESC;

/* Q38. */
WITH order_counts AS (
  SELECT cust_id, COUNT(*) AS order_ct FROM sales.orders GROUP BY cust_id
)
SELECT c.*, COALESCE(oc.order_ct,0) AS order_ct,
       ROW_NUMBER() OVER (
         PARTITION BY LOWER(TRIM(c.email))
         ORDER BY COALESCE(oc.order_ct,0) DESC, c.registration_date DESC
       ) AS quality_rank
FROM customers.customers c
LEFT JOIN order_counts oc ON oc.cust_id = c.customer_id
ORDER BY LOWER(TRIM(c.email));

/* Q39. */
WITH ranked AS (
  SELECT customer_id, email, ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY registration_date DESC) AS rn
  FROM customers.customers
)
SELECT * FROM ranked WHERE rn > 1;

/* Q40. */
WITH grp AS (
  SELECT LOWER(TRIM(email)) AS canon_email, COUNT(*) AS raw_ct
  FROM customers.customers GROUP BY LOWER(TRIM(email))
),
deduped AS (
  SELECT LOWER(TRIM(email)) AS canon_email, COUNT(*) AS dedup_ct
  FROM (
    SELECT DISTINCT ON (LOWER(TRIM(email))) email FROM customers.customers
  ) x
  GROUP BY LOWER(TRIM(email))
)
SELECT g.canon_email, g.raw_ct, d.dedup_ct
FROM grp g JOIN deduped d ON d.canon_email = g.canon_email
WHERE g.raw_ct > 1;

/* Q41. (no order date-of-first-order column exists on customers; it is derived from sales.orders) */
WITH first_order AS (
  SELECT cust_id, MIN(order_date) AS first_order_date FROM sales.orders GROUP BY cust_id
)
SELECT c.first_name, c.last_name, fo.first_order_date, COUNT(*) AS n
FROM customers.customers c
JOIN first_order fo ON fo.cust_id = c.customer_id
GROUP BY c.first_name, c.last_name, fo.first_order_date
HAVING COUNT(*) > 1;

/* Q42. */
SELECT brand_id, product_name, supplier_id, COUNT(*) AS n
FROM products.products
GROUP BY brand_id, product_name, supplier_id
HAVING COUNT(*) > 1;

/* Q43. */
SELECT LOWER(email) AS email_lc, COUNT(DISTINCT store_id) AS store_ct, COUNT(*) AS n
FROM stores.employees
WHERE email IS NOT NULL
GROUP BY LOWER(email)
HAVING COUNT(*) > 1;

/* Q44. */
SELECT city, LOWER(TRIM(store_name)) AS canon_name, COUNT(*) AS n
FROM stores.stores
GROUP BY city, LOWER(TRIM(store_name))
HAVING COUNT(*) > 1;

/* Q45. */
WITH ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY registration_date ASC) AS rn
  FROM customers.customers
)
SELECT * FROM ranked WHERE rn = 1;

/* Q46. */
WITH ranked AS (
  SELECT *, ROW_NUMBER() OVER (
    PARTITION BY customer_id, subject, DATE_TRUNC('month', created_date)
    ORDER BY created_date
  ) AS rn
  FROM support.tickets
)
SELECT * FROM ranked WHERE rn = 1;

/* Q47. */
WITH spend AS (
  SELECT cust_id, SUM(net_total) AS total_spend FROM sales.orders GROUP BY cust_id
),
ranked AS (
  SELECT c.*, COALESCE(s.total_spend,0) AS total_spend,
         ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(c.email)) ORDER BY COALESCE(s.total_spend,0) DESC) AS rn
  FROM customers.customers c
  LEFT JOIN spend s ON s.cust_id = c.customer_id
)
SELECT * FROM ranked WHERE rn = 1;

/* Q48. */
SELECT c.customer_id, LOWER(TRIM(a.city)) AS canon_city, a.pincode
FROM customers.customers c
JOIN customers.addresses a ON a.customer_id = c.customer_id
ORDER BY c.customer_id;

/* Q49. */
WITH canon AS (
  SELECT customer_id, LOWER(TRIM(email)) AS canon_email FROM customers.customers
),
deduped AS (
  SELECT DISTINCT ON (canon_email) customer_id, canon_email
  FROM canon ORDER BY canon_email, customer_id
)
SELECT (SELECT COUNT(*) FROM canon) AS raw_count,
       (SELECT COUNT(*) FROM deduped) AS deduped_count,
       (SELECT COUNT(DISTINCT canon_email) FROM canon) AS expected_canon_count;

/* Q50. */
WITH ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY registration_date DESC) AS rn
  FROM customers.customers
)
SELECT customer_id, first_name, last_name, LOWER(TRIM(email)) AS canon_email, phone, registration_date, tier
FROM ranked WHERE rn = 1;

/* Q51. (COALESCE-based null-safe join is used instead of the literal IS NOT DISTINCT FROM operator, since that operator disables hash/merge join planning and forces a nested loop on these table sizes) */
SELECT o.order_id, c.customer_id
FROM sales.orders o
JOIN customers.customers c ON COALESCE(o.cust_id, -1) = COALESCE(c.customer_id, -1)
LIMIT 100;

/* Q52. */
SELECT o.order_id, p.order_id AS payment_order_id
FROM sales.orders o
JOIN sales.payments p ON COALESCE(o.order_id::text,'') = COALESCE(p.order_id::text,'')
LIMIT 100;

/* Q53. (COALESCE keys keep this hash-joinable; a literal IS NOT DISTINCT FROM here forces a nested loop over 150k x 142k rows) */
SELECT o.order_id
FROM sales.orders o
LEFT JOIN sales.payments p ON COALESCE(p.order_id, -1) = COALESCE(o.order_id, -1)
WHERE p.payment_id IS NULL;

/* Q54. (concept illustrated on employees with a NULL store_id, grouped under a sentinel value) */
SELECT COALESCE(store_id, -1) AS store_group, COUNT(*) AS n
FROM stores.employees
GROUP BY COALESCE(store_id, -1);

/* Q55. */
SELECT r.region_name,
       EXTRACT(YEAR FROM c.registration_date)::int AS reg_year,
       ROUND(100.0 * COUNT(*) FILTER (WHERE c.phone IS NULL) / COUNT(*), 2) AS pct_null_phone
FROM customers.customers c
JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = true
JOIN core.dim_region r ON r.state = a.state
GROUP BY r.region_name, EXTRACT(YEAR FROM c.registration_date)
ORDER BY r.region_name, reg_year;

/* Q56. */
SELECT c.customer_id, COALESCE(a.city, 'Unknown') AS derived_city
FROM customers.customers c
LEFT JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = true;

/* Q57. */
SELECT review_id, NULLIF(TRIM(review_text), '') AS review_text_normalized
FROM customers.reviews;

/* Q58. */
WITH cleaned AS (
  SELECT customer_id, LOWER(TRIM(email)) AS canon_email FROM customers.customers
)
SELECT c1.customer_id, c1.canon_email
FROM cleaned c1
LEFT JOIN cleaned c2 ON c2.canon_email = c1.canon_email AND c2.customer_id <> c1.customer_id
WHERE c2.customer_id IS NULL;

/* Q59. */
WITH canon AS (
  SELECT product_name, LOWER(TRIM(product_name)) AS canon_name FROM products.products
),
grp AS (
  SELECT canon_name, COUNT(*) AS row_ct, COUNT(DISTINCT product_name) AS variant_ct
  FROM canon GROUP BY canon_name
)
SELECT canon_name, row_ct, variant_ct
FROM grp
WHERE variant_ct > 1;

/* Q60. */
SELECT LOWER(REGEXP_REPLACE(TRIM(brand_name), '\s+', ' ', 'g')) AS canon_name, COUNT(*) AS n
FROM core.dim_brand
GROUP BY LOWER(REGEXP_REPLACE(TRIM(brand_name), '\s+', ' ', 'g'))
ORDER BY n DESC;

/* Q61. */
WITH normalized AS (
  SELECT customer_id, RIGHT(REGEXP_REPLACE(phone, '\D', '', 'g'), 10) AS phone_last10
  FROM customers.customers
  WHERE phone IS NOT NULL
)
SELECT phone_last10, COUNT(*) AS n
FROM normalized
GROUP BY phone_last10
HAVING COUNT(*) > 1;

/* Q62. */
SELECT DISTINCT priority, TRIM(priority) AS trimmed
FROM support.tickets
WHERE priority <> TRIM(priority);

/* Q63. */
SELECT 'customers' AS tbl, COUNT(*) AS raw_row_ct FROM customers.customers
UNION ALL
SELECT 'customers_after_email_dedup', COUNT(*) FROM (SELECT DISTINCT LOWER(TRIM(email)) FROM customers.customers) x;

/* Q64. */
SELECT c1.customer_id AS id_a, c2.customer_id AS id_b, c1.email AS email_a, c2.email AS email_b
FROM customers.customers c1
JOIN customers.customers c2
  ON LOWER(TRIM(c1.email)) = LOWER(TRIM(c2.email))
 AND c1.email <> c2.email
 AND c1.customer_id < c2.customer_id;

/* Q65. */
SELECT customer_id,
       LOWER(TRIM(email)) AS clean_email,
       COALESCE(RIGHT(REGEXP_REPLACE(phone, '\D', '', 'g'), 10), 'unknown') AS clean_phone,
       TRIM(first_name) AS clean_first_name,
       TRIM(last_name) AS clean_last_name
FROM customers.customers;

/* Q66. */
SELECT product_id, REGEXP_REPLACE(TRIM(product_name), '\s+', ' ', 'g') AS clean_name
FROM products.products;

/* Q67. */
SELECT address_id,
       LOWER(TRIM(city)) AS clean_city,
       REGEXP_REPLACE(pincode, '\D', '', 'g') AS clean_pincode
FROM customers.addresses;

/* Q68. */
SELECT r.region_name,
       ROUND(100.0 * COUNT(*) FILTER (WHERE c.phone IS NULL) / COUNT(*), 2) AS pct_null_phone,
       ROUND(100.0 * COUNT(*) FILTER (WHERE c.tier IS NULL) / COUNT(*), 2) AS pct_null_tier
FROM customers.customers c
JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = true
JOIN core.dim_region r ON r.state = a.state
GROUP BY r.region_name
ORDER BY r.region_name;

/* Q69. */
SELECT review_id
FROM customers.reviews
WHERE review_text IS NOT NULL AND LENGTH(TRIM(review_text)) = 0;

/* Q70. */
SELECT customer_id, first_name
FROM customers.customers
WHERE first_name = UPPER(first_name) OR first_name = LOWER(first_name);

/* Q71. */
SELECT product_id, product_name
FROM products.products
WHERE product_name ~ '[0-9]' AND product_name ~ '[A-Za-z]';

/* Q72. */
SELECT customer_id, email
FROM customers.customers
WHERE email ~ '[^A-Za-z0-9@._+\-]';

/* Q73. */
SELECT address_id, pincode
FROM customers.addresses
WHERE pincode !~ '^\d{6}$';

/* Q74. */
SELECT customer_id,
       LOWER(TRIM(email)) AS clean_email,
       COALESCE(phone, 'unknown') AS clean_phone,
       INITCAP(TRIM(first_name)) AS clean_first_name,
       INITCAP(TRIM(last_name)) AS clean_last_name,
       registration_date, tier
FROM customers.customers;

/* Q75. */
SELECT customer_id, 'bad_email_format' AS rule
FROM customers.customers
WHERE email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
UNION ALL
SELECT customer_id, 'first_name_has_padding'
FROM customers.customers
WHERE first_name <> TRIM(first_name);

/* Q76. */
WITH regional_baseline AS (
  SELECT r.region_id, PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  JOIN core.dim_region r ON r.region_id = s.region_id
  GROUP BY r.region_id
)
SELECT o.order_id, s.region_id, o.net_total, rb.p95
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN regional_baseline rb ON rb.region_id = s.region_id
WHERE o.net_total > rb.p95;

/* Q77. */
WITH margin AS (
  SELECT p.product_id, dc.category_name,
         (p.price - p.cost_price) / NULLIF(p.price,0) AS margin_pct
  FROM products.products p
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category dc ON dc.category_id = b.category_id
),
cat_median AS (
  SELECT category_name, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY margin_pct) AS median_margin
  FROM margin GROUP BY category_name
)
SELECT m.product_id, m.category_name, m.margin_pct, cm.median_margin
FROM margin m
JOIN cat_median cm ON cm.category_name = m.category_name
WHERE m.margin_pct < cm.median_margin;

/* Q78. */
SELECT change_id, record_id, old_value, new_value,
       (new_value::numeric - old_value::numeric) / NULLIF(old_value::numeric,0) AS ratio
FROM audit.record_changes
WHERE table_name = 'products' AND column_name = 'price'
  AND ABS((new_value::numeric - old_value::numeric) / NULLIF(old_value::numeric,0)) > 0.5;

/* Q79. */
SELECT change_id, record_id, old_value, new_value,
       (new_value::numeric - old_value::numeric) / NULLIF(old_value::numeric,0) AS ratio
FROM audit.record_changes
WHERE table_name = 'employees' AND column_name = 'salary'
  AND ABS((new_value::numeric - old_value::numeric) / NULLIF(old_value::numeric,0)) > 0.3;

/* Q80. */
WITH resolution AS (
  SELECT ticket_id, priority, EXTRACT(EPOCH FROM (resolved_date - created_date))/3600 AS resolution_hours
  FROM support.tickets WHERE resolved_date IS NOT NULL
),
baseline AS (
  SELECT priority, PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY resolution_hours) AS p95
  FROM resolution GROUP BY priority
)
SELECT r.ticket_id, r.priority, r.resolution_hours, b.p95
FROM resolution r JOIN baseline b ON b.priority = r.priority
WHERE r.resolution_hours > b.p95;

/* Q81. */
WITH monthly AS (
  SELECT store_id, DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS revenue
  FROM sales.orders GROUP BY store_id, DATE_TRUNC('month', order_date)
),
with_prev AS (
  SELECT store_id, month, revenue,
         LAG(revenue) OVER (PARTITION BY store_id ORDER BY month) AS prev_revenue
  FROM monthly
)
SELECT store_id, month, revenue, prev_revenue,
       (revenue - prev_revenue) / NULLIF(prev_revenue,0) AS pct_change
FROM with_prev
WHERE prev_revenue IS NOT NULL AND (revenue - prev_revenue) / NULLIF(prev_revenue,0) < -0.5;

/* Q82. */
WITH session_len AS (
  SELECT customer_id, session_id, COUNT(*) AS views
  FROM web_events.page_views GROUP BY customer_id, session_id
),
scored AS (
  SELECT *, NTILE(100) OVER (ORDER BY views) AS pct_bucket FROM session_len
)
SELECT * FROM scored WHERE pct_bucket = 99;

/* Q83. (rating deviation vs product mean, expressed via STDDEV) */
WITH stats AS (
  SELECT product_id, AVG(rating) AS avg_rating, STDDEV(rating) AS sd_rating
  FROM customers.reviews GROUP BY product_id
)
SELECT r.review_id, r.product_id, r.rating, s.avg_rating, s.sd_rating
FROM customers.reviews r
JOIN stats s ON s.product_id = r.product_id
WHERE s.sd_rating > 0 AND ABS(r.rating - s.avg_rating) > 2 * s.sd_rating;

/* Q84. */
WITH dept_baseline AS (
  SELECT e.dept_id,
         PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY ps.net_salary) AS p5,
         PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY ps.net_salary) AS p95
  FROM payroll.pay_slips ps
  JOIN stores.employees e ON e.employee_id = ps.employee_id
  GROUP BY e.dept_id
)
SELECT ps.pay_slip_id, e.dept_id, ps.net_salary, db.p5, db.p95
FROM payroll.pay_slips ps
JOIN stores.employees e ON e.employee_id = ps.employee_id
JOIN dept_baseline db ON db.dept_id = e.dept_id
WHERE ps.net_salary < db.p5 OR ps.net_salary > db.p95;

/* Q85. */
WITH wh_median AS (
  SELECT warehouse_id, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY quantity_on_hand) AS median_qty
  FROM supply_chain.inventory_snapshots GROUP BY warehouse_id
)
SELECT s.warehouse_id, s.product_id, s.snapshot_date, s.quantity_on_hand, m.median_qty
FROM supply_chain.inventory_snapshots s
JOIN wh_median m ON m.warehouse_id = s.warehouse_id
WHERE m.median_qty > 0 AND s.quantity_on_hand > 5 * m.median_qty;

/* Q86. */
WITH platform_p95 AS (
  SELECT platform, PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY amount) AS p95
  FROM marketing.ads_spend GROUP BY platform
)
SELECT a.spend_id, a.platform, a.amount, p.p95
FROM marketing.ads_spend a
JOIN platform_p95 p ON p.platform = a.platform
WHERE a.amount > p.p95;

/* Q87. */
SELECT o.order_id
FROM sales.orders o
LEFT JOIN sales.payments p ON p.order_id = o.order_id
WHERE p.payment_id IS NULL;

/* Q88. */
SELECT shipment_id, shipped_date, delivered_date
FROM sales.shipments
WHERE shipped_date > delivered_date;

/* Q89. */
SELECT t.ticket_id, t.customer_id, t.created_date, c.registration_date
FROM support.tickets t
JOIN customers.customers c ON c.customer_id = t.customer_id
WHERE c.registration_date > t.created_date::date;

/* Q90. */
SELECT o.order_id
FROM sales.orders o
LEFT JOIN customers.customers c ON c.customer_id = o.cust_id
WHERE o.cust_id IS NOT NULL AND c.customer_id IS NULL;

/* Q91. */
SELECT COALESCE(f.order_id, s.order_id) AS order_id,
       COALESCE(f.total, 0) AS finance_total, COALESCE(s.total, 0) AS sales_total
FROM (SELECT order_id, SUM(amount) AS total FROM finance.payments GROUP BY order_id) f
FULL JOIN (SELECT order_id, SUM(amount) AS total FROM sales.payments GROUP BY order_id) s
  ON s.order_id = f.order_id
WHERE COALESCE(f.total,0) IS DISTINCT FROM COALESCE(s.total,0);

/* Q92. */
SELECT o.order_id, o.net_total, SUM(oi.net_amount) AS items_total
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id, o.net_total
HAVING o.net_total IS DISTINCT FROM SUM(oi.net_amount);

/* Q93. Inventory snapshots track warehouse stock over time while order_items track store-level sales - there is no shared warehouse/store key in this schema, so movement can only be reconciled at the product level (total snapshot delta vs total units sold), not exactly per warehouse. */

/* Q94. */
SELECT 'orders_missing_payment' AS rule, COUNT(*) AS fail_ct
FROM sales.orders o LEFT JOIN sales.payments p ON p.order_id = o.order_id
WHERE p.payment_id IS NULL
UNION ALL
SELECT 'shipment_delivered_before_shipped', COUNT(*)
FROM sales.shipments WHERE delivered_date < shipped_date
UNION ALL
SELECT 'order_items_mismatch_net_total', COUNT(*)
FROM (
  SELECT o.order_id FROM sales.orders o JOIN sales.order_items oi ON oi.order_id = o.order_id
  GROUP BY o.order_id, o.net_total HAVING o.net_total IS DISTINCT FROM SUM(oi.net_amount)
) x;

/* Q95. */
SELECT r.region_name,
       COUNT(*) FILTER (WHERE o.discount_amount > o.gross_total) AS discount_gt_gross_ct,
       COUNT(*) FILTER (WHERE o.gross_total > 100000) AS high_value_ct,
       COUNT(*) AS total_orders
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;

/* Q96. */
SELECT DATE_TRUNC('month', order_date)::date AS month,
       ROUND(100.0 * COUNT(*) FILTER (WHERE discount_amount > gross_total) / COUNT(*), 3) AS pct_discount_gt_gross
FROM sales.orders
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY month;

/* Q97. */
SELECT customer_id,
       LOWER(TRIM(email)) AS clean_email,
       TRIM(first_name) AS clean_first_name,
       TRIM(last_name) AS clean_last_name,
       COALESCE(phone, 'unknown') AS clean_phone,
       tier
FROM customers.customers;

/* Q98. */
SELECT p.product_id,
       REGEXP_REPLACE(TRIM(p.product_name), '\s+', ' ', 'g') AS clean_name,
       LOWER(TRIM(b.brand_name)) AS canonical_brand
FROM products.products p
JOIN core.dim_brand b ON b.brand_id = p.brand_id;

/* Q99. */
WITH regional AS (
  SELECT r.region_name,
         COUNT(*) FILTER (WHERE o.net_total > 100000) AS anomaly_ct,
         COUNT(*) AS total_ct
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  JOIN core.dim_region r ON r.region_id = s.region_id
  GROUP BY r.region_name
)
SELECT region_name, anomaly_ct, total_ct, ROUND(100.0 * anomaly_ct / total_ct, 3) AS pct_anomaly
FROM regional
ORDER BY region_name;

/* Q100. */
WITH scorecard AS (
  SELECT 'orders_missing_payment' AS rule, COUNT(*) AS fail_ct, (SELECT COUNT(*) FROM sales.orders) AS total_ct
  FROM sales.orders o LEFT JOIN sales.payments p ON p.order_id = o.order_id WHERE p.payment_id IS NULL
  UNION ALL
  SELECT 'discount_gt_gross', COUNT(*), (SELECT COUNT(*) FROM sales.orders)
  FROM sales.orders WHERE discount_amount > gross_total
  UNION ALL
  SELECT 'net_total_mismatch_items', COUNT(*), (SELECT COUNT(*) FROM sales.orders)
  FROM (
    SELECT o.order_id FROM sales.orders o JOIN sales.order_items oi ON oi.order_id = o.order_id
    GROUP BY o.order_id, o.net_total HAVING o.net_total IS DISTINCT FROM SUM(oi.net_amount)
  ) x
),
quarantine_sample AS (
  SELECT order_id, gross_total, discount_amount, net_total
  FROM sales.orders WHERE discount_amount > gross_total LIMIT 20
)
SELECT rule, fail_ct, total_ct, ROUND(100.0*fail_ct/total_ct,3) AS pct_failed FROM scorecard;
