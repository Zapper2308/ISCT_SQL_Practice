/* ============================================================
   ANSWER KEY - Aggregate Functions & Grouping (HARD LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: AGGREGATES - CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1.  PERCENTILE_CONT interpolates between the two nearest data points to produce a value that may not exist in the data; PERCENTILE_DISC always returns an actual value from the data set - so PERCENTILE_CONT is the one that interpolates. */
/* Q2.  Because a percentile is defined relative to a specific ORDER of the values (you must know the rank order to find "the value at the 50th position"), so PostgreSQL requires WITHIN GROUP (ORDER BY col) to state that ordering explicitly. */
/* Q3.  An ordered-set aggregate is an aggregate function whose result depends on the ORDER of input rows within each group (not just their values) - PERCENTILE_CONT, PERCENTILE_DISC, and MODE are all ordered-set aggregates using WITHIN GROUP (ORDER BY ...). */
/* Q4.  For an even-count group, the 50th percentile falls exactly between the two middle values, so PERCENTILE_CONT(0.5) returns their linear average (interpolated), rather than picking one or the other. */
/* Q5.  MODE() WITHIN GROUP (ORDER BY col) returns the single most-frequent value directly and concisely; a CASE + COUNT approach requires manually counting each candidate value and picking the max - MODE() is shorter and lets the engine do the work. */
/* Q6.  ROLLUP(a,b,c) produces the full (a,b,c) grouped rows, plus subtotals for (a,b), then (a), then a grand total - a hierarchical drill-up, not every combination. */
/* Q7.  CUBE(a,b,c) produces every possible combination of the three columns being grouped or rolled up - 2^3 = 8 distinct groupings, including the grand total. */
/* Q8.  GROUPING SETS is more flexible when you need independent, non-hierarchical groupings in one query (e.g. "by region" AND "by tier" with nothing in between) - CUBE/ROLLUP only give hierarchical or full cross-product subsets. */
/* Q9.  GROUPING(col) returns 1 for a subtotal/grand-total row where col has been "rolled up" to NULL (not a real value), and 0 when col holds an actual group value - it disambiguates a real NULL from a rollup NULL. */
/* Q10. ARRAY_AGG(col ORDER BY sort_col) stores the group's values in that explicit order inside the array; without ORDER BY, the array's element order is whatever order rows happened to arrive in (not guaranteed/deterministic). */
/* Q11. Without ORDER BY, STRING_AGG concatenates rows in an arbitrary, plan-dependent order that can change between runs - non-deterministic means the same query can produce a different string each time unless you add ORDER BY. */
/* Q12. Use JSON_AGG when you need standard JSON text output (e.g. for logging/display); use JSONB_AGG when the result will be stored/queried further in PostgreSQL, since JSONB is binary, indexable, and faster to process. */
/* Q13. JSONB_OBJECT_AGG(key_col, value_col) builds a single JSON object per group mapping each key value to its corresponding value - e.g. {platform: total_spend} from marketing.ads_spend rows. */
/* Q14. ARRAY_AGG(DISTINCT col) matters when you want each unique value only once in the resulting array (e.g. distinct brand names touched by a category) instead of one array element per raw row. */
/* Q15. SUM(DISTINCT col) is valid but uncommon - it sums each unique value in the group only once, useful only when duplicate values represent the "same fact" repeated (rare for money columns like order amounts). */
/* Q16. FILTER (WHERE cond) is cleaner than CASE WHEN...THEN...END inside every aggregate because it separates "what to aggregate" from "which rows count," reads more like natural SQL, and avoids repeating the aggregate's expression. */
/* Q17. COUNT(*) FILTER (WHERE a) AS count_a, COUNT(*) FILTER (WHERE b) AS count_b in one SELECT computes two independently-filtered counts from the same row set without scanning the table twice. */
/* Q18. BIT_AND/BIT_OR aggregate integer columns bitwise across a group - useful when each row stores a set of boolean flags packed into an integer (permission bits, feature flags) and you want the combined AND/OR across the group. */
/* Q19. BOOL_AND(col) is true only if every row in the group is true (an "all must satisfy" check); BOOL_OR(col) is true if at least one row is true (an "any satisfies" check) - both used for group-level all-or-any business rules. */
/* Q20. Yes - HAVING can reference the outer query's GROUP BY columns and aggregates in its subquery's correlation, letting you filter groups based on a comparison computed in a correlated subquery. */
/* Q21. Because GROUPING SETS((a),(b)) tells PostgreSQL to compute two SEPARATE, independent groupings in a single scan of the table and UNION them into one result set - functionally like two GROUP BY queries combined with UNION ALL, but computed together. */
/* Q22. DISTINCT ON (col) ORDER BY col, tiebreaker picks exactly one row per distinct value of col (e.g. the latest row per customer) - it's a row-selection tool that pairs naturally with pre-aggregated or joined data, not a true aggregate function itself. */
/* Q23. AVG(NULL, NULL, 5) is not literal syntax, but AVG over a column containing NULL, NULL, 5 returns 5 - NULLs are excluded from both the sum and the count of values averaged. */
/* Q24. SUM() over zero rows has nothing to add, so SQL defines it as NULL (unknown), while COUNT() is defined as counting rows and correctly reports 0 rows found - they follow different mathematical conventions by design. */
/* Q25. ARRAY_AGG(col ORDER BY sort_col) sorts the group's rows by sort_col FIRST, then appends each col value into the array in that sorted order - the ORDER BY is local to the aggregate, independent of any outer query ORDER BY. */

/* ============================================================
   SECTION B: PERCENTILES & STATISTICAL AGGREGATES (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total) AS median_net_total
FROM sales.orders;

/* Q27. */
SELECT PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY net_total) AS p90_net_total
FROM sales.orders;

/* Q28. */
SELECT PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY net_total) AS p99_net_total
FROM sales.orders;

/* Q29. */
SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total)  AS median_net_total,
       PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY net_total)  AS p90_net_total,
       PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY net_total) AS p99_net_total
FROM sales.orders;

/* Q30. */
SELECT priority,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (resolved_date - created_date))/3600.0) AS median_resolution_hours
FROM support.tickets
WHERE resolved_date IS NOT NULL
GROUP BY priority;

/* Q31. */
SELECT courier_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY (delivered_date - shipped_date)) AS median_days_to_deliver
FROM sales.shipments
WHERE delivered_date IS NOT NULL AND shipped_date IS NOT NULL
GROUP BY courier_name;

/* Q32. */
SELECT call_reason,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY call_duration_seconds) AS p95_call_duration
FROM call_center.calls
GROUP BY call_reason;

/* Q33. Page_views has no stored dwell-time column, so dwell time is derived as the gap to the NEXT page_view in the same session. */
WITH dwell AS (
  SELECT device_type, session_id,
         LEAD(view_timestamp) OVER (PARTITION BY session_id ORDER BY view_timestamp) - view_timestamp AS dwell_time
  FROM web_events.page_views
)
SELECT device_type,
       PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM dwell_time)) AS p99_dwell_seconds
FROM dwell
WHERE dwell_time IS NOT NULL
GROUP BY device_type;

/* Q34. */
SELECT b.brand_id,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY p.price) AS median_price
FROM products.products p
JOIN core.dim_brand b ON p.brand_id = b.brand_id
GROUP BY b.brand_id;

/* Q35. */
SELECT e.dept_id,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ps.gross_salary) AS median_gross_salary
FROM payroll.pay_slips ps
JOIN stores.employees e ON ps.employee_id = e.employee_id
GROUP BY e.dept_id;

/* Q36. */
SELECT dept_id, STDDEV(salary) AS salary_stddev
FROM stores.employees GROUP BY dept_id;

/* Q37. */
SELECT platform, STDDEV(amount) AS spend_stddev
FROM marketing.ads_spend GROUP BY platform;

/* Q38. */
SELECT order_status, VARIANCE(net_total) AS net_total_variance
FROM sales.orders GROUP BY order_status;

/* Q39. */
SELECT store_id,
       MIN(net_total) AS min_total, MAX(net_total) AS max_total, AVG(net_total) AS avg_total,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total) AS median_total
FROM sales.orders GROUP BY store_id;

/* Q40. */
SELECT r.region_name,
       PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY o.net_total) AS p25,
       PERCENTILE_CONT(0.5)  WITHIN GROUP (ORDER BY o.net_total) AS p50,
       PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY o.net_total) AS p75
FROM sales.orders o
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY r.region_name;

/* Q41. */
SELECT MODE() WITHIN GROUP (ORDER BY order_status) AS most_frequent_status
FROM sales.orders;

/* Q42. */
SELECT c.tier, MODE() WITHIN GROUP (ORDER BY a.city) AS most_frequent_city
FROM customers.customers c
JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = TRUE
GROUP BY c.tier;

/* Q43. */
SELECT order_id, net_total, pr
FROM (
  SELECT order_id, net_total, PERCENT_RANK() OVER (ORDER BY net_total DESC) AS pr
  FROM sales.orders
) ranked
WHERE pr <= 0.10
ORDER BY net_total DESC;

/* Q44. */
SELECT order_id, net_total, CUME_DIST() OVER (ORDER BY net_total) AS cume_dist
FROM sales.orders
ORDER BY net_total
LIMIT 50;

/* Q45. */
SELECT r.region_name, MAX(o.net_total) - MIN(o.net_total) AS range_net_total
FROM sales.orders o
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY r.region_name;

/* Q46. */
SELECT order_status, STDDEV(net_total) / NULLIF(AVG(net_total), 0) AS coefficient_of_variation
FROM sales.orders GROUP BY order_status;

/* Q47. */
SELECT category,
       AVG(EXTRACT(EPOCH FROM (resolved_date - created_date))/3600.0) AS avg_resolution_hours,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (resolved_date - created_date))/3600.0) AS median_resolution_hours
FROM support.tickets
WHERE resolved_date IS NOT NULL
GROUP BY category;

/* Q48. */
SELECT courier_name,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY (delivered_date - shipped_date)) AS p95_days,
       MAX(delivered_date - shipped_date) AS max_days
FROM sales.shipments
WHERE delivered_date IS NOT NULL AND shipped_date IS NOT NULL
GROUP BY courier_name;

/* Q49. */
SELECT EXTRACT(QUARTER FROM order_date) AS fiscal_quarter,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total) AS median_revenue
FROM sales.orders
GROUP BY EXTRACT(QUARTER FROM order_date)
ORDER BY fiscal_quarter;

/* Q50. */
SELECT PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY net_total) AS median_disc,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total) AS median_cont
FROM sales.orders;

/* ============================================================
   SECTION C: GROUPING SETS / CUBE / ROLLUP (25)
   ------------------------------------------------------------ */
/* Q51. */
SELECT r.region_name, o.order_status, COUNT(*) AS order_count
FROM sales.orders o
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY ROLLUP(r.region_name, o.order_status)
ORDER BY r.region_name, o.order_status;

/* Q52. */
SELECT device_type, os, COUNT(*) AS view_count
FROM web_events.page_views
GROUP BY CUBE(device_type, os)
ORDER BY device_type, os;

/* Q53. */
SELECT priority, status, COUNT(*) AS ticket_count
FROM support.tickets
GROUP BY GROUPING SETS ((priority), (status))
ORDER BY priority, status;

/* Q54. */
SELECT EXTRACT(YEAR FROM order_date) AS yr, EXTRACT(MONTH FROM order_date) AS mo, SUM(net_total) AS revenue
FROM sales.orders
GROUP BY ROLLUP(EXTRACT(YEAR FROM order_date), EXTRACT(MONTH FROM order_date))
ORDER BY yr, mo;

/* Q55. */
SELECT b.brand_id, b.category_id, COUNT(*) AS product_count
FROM products.products p
JOIN core.dim_brand b ON p.brand_id = b.brand_id
GROUP BY CUBE(b.brand_id, b.category_id)
ORDER BY b.brand_id, b.category_id;

/* Q56. */
SELECT c.tier, r.region_name, SUM(o.net_total) AS revenue
FROM sales.orders o
JOIN customers.customers c ON o.cust_id = c.customer_id
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY GROUPING SETS ((c.tier, r.region_name), (c.tier), ())
ORDER BY c.tier, r.region_name;

/* Q57. */
SELECT dept_id, role, COUNT(*) AS employee_count
FROM stores.employees
GROUP BY ROLLUP(dept_id, role)
ORDER BY dept_id, role;

/* Q58. */
SELECT dept_id, role, COUNT(*) AS employee_count,
       GROUPING(dept_id) AS dept_is_subtotal, GROUPING(role) AS role_is_subtotal
FROM stores.employees
GROUP BY ROLLUP(dept_id, role)
ORDER BY dept_id, role;

/* Q59. */
SELECT dept_id, role, COUNT(*) AS employee_count
FROM stores.employees
GROUP BY ROLLUP(dept_id, role)
HAVING GROUPING(role) = 1
ORDER BY dept_id;

/* Q60. */
SELECT r.region_name, s.store_name, COUNT(*) AS order_count
FROM sales.orders o
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY ROLLUP(r.region_name, s.store_name)
ORDER BY r.region_name, s.store_name;

/* Q61. */
SELECT sp.payment_mode, o.order_status, COUNT(*) AS combo_count
FROM sales.orders o
JOIN sales.payments sp ON sp.order_id = o.order_id
GROUP BY CUBE(sp.payment_mode, o.order_status)
ORDER BY sp.payment_mode, o.order_status;

/* Q62. */
SELECT c.campaign_name, a.platform, SUM(a.amount) AS total_spend
FROM marketing.ads_spend a
JOIN marketing.campaigns c ON a.campaign_id = c.campaign_id
GROUP BY GROUPING SETS ((c.campaign_name), (a.platform), ())
ORDER BY c.campaign_name, a.platform;

/* Q63. */
SELECT p.supplier_id, i.product_id, SUM(i.quantity_on_hand) AS total_on_hand
FROM products.inventory i
JOIN products.products p ON i.product_id = p.product_id
GROUP BY ROLLUP(p.supplier_id, i.product_id)
ORDER BY p.supplier_id, i.product_id;

/* Q64. */
SELECT EXTRACT(YEAR FROM order_date) AS yr, EXTRACT(QUARTER FROM order_date) AS qtr, SUM(net_total) AS revenue
FROM sales.orders
GROUP BY ROLLUP(EXTRACT(YEAR FROM order_date), EXTRACT(QUARTER FROM order_date))
ORDER BY yr, qtr;

/* Q65. */
SELECT b.brand_id, r.region_name, cat.category_name, SUM(oi.net_amount) AS revenue
FROM sales.order_items oi
JOIN sales.orders o ON oi.order_id = o.order_id
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
JOIN products.products p ON oi.prod_id = p.product_id
JOIN core.dim_brand b ON p.brand_id = b.brand_id
JOIN core.dim_category cat ON b.category_id = cat.category_id
GROUP BY CUBE(b.brand_id, r.region_name, cat.category_name)
ORDER BY b.brand_id, r.region_name, cat.category_name;

/* Q66. */
SELECT tier, COUNT(*) AS customer_count
FROM customers.customers
GROUP BY GROUPING SETS ((tier), ())
ORDER BY tier;

/* Q67. */
SELECT dept_id, COUNT(*) AS employee_count
FROM stores.employees
GROUP BY ROLLUP(dept_id)
ORDER BY GROUPING(dept_id), dept_id;

/* Q68. */
SELECT cat.category_name, b.brand_name, SUM(oi.net_amount) AS revenue
FROM sales.order_items oi
JOIN products.products p ON oi.prod_id = p.product_id
JOIN core.dim_brand b ON p.brand_id = b.brand_id
JOIN core.dim_category cat ON b.category_id = cat.category_id
GROUP BY ROLLUP(cat.category_name, b.brand_name)
ORDER BY cat.category_name, b.brand_name;

/* Q69. warehouses/regions don't map to "channel"; payment_mode is used as a channel proxy. */
SELECT r.region_name, sp.payment_mode, SUM(o.net_total) AS revenue
FROM sales.orders o
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
JOIN sales.payments sp ON sp.order_id = o.order_id
GROUP BY CUBE(r.region_name, sp.payment_mode)
ORDER BY r.region_name, sp.payment_mode;

/* Q70. */
SELECT tier, EXTRACT(YEAR FROM registration_date) AS reg_year, COUNT(*) AS customer_count
FROM customers.customers
GROUP BY GROUPING SETS ((tier), (EXTRACT(YEAR FROM registration_date)))
ORDER BY tier, reg_year;

/* Q71. */
SELECT r.region_name, c.tier, o.order_status, SUM(o.net_total) AS revenue
FROM sales.orders o
JOIN customers.customers c ON o.cust_id = c.customer_id
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY GROUPING SETS ((r.region_name), (c.tier), (o.order_status))
ORDER BY r.region_name, c.tier, o.order_status;

/* Q72. */
SELECT device_type, os, COUNT(*) AS view_count, GROUPING(device_type, os) AS grouping_id
FROM web_events.page_views
GROUP BY CUBE(device_type, os)
ORDER BY grouping_id, device_type, os;

/* Q73. */
WITH rolled AS (
  SELECT r.region_name, o.order_status, SUM(o.net_total) AS revenue
  FROM sales.orders o
  JOIN stores.stores s ON o.store_id = s.store_id
  JOIN core.dim_region r ON s.region_id = r.region_id
  GROUP BY ROLLUP(r.region_name, o.order_status)
)
SELECT region_name, order_status, revenue,
       RANK() OVER (PARTITION BY region_name ORDER BY revenue DESC) AS rnk_within_region
FROM rolled
WHERE order_status IS NOT NULL
ORDER BY region_name, rnk_within_region;

/* Q74. */
SELECT dept_id, role, COUNT(*) AS employee_count,
       CASE WHEN GROUPING(role) = 1 AND GROUPING(dept_id) = 1 THEN 'GRAND TOTAL'
            WHEN GROUPING(role) = 1 THEN 'DEPT SUBTOTAL'
            ELSE 'DETAIL' END AS row_type
FROM stores.employees
GROUP BY ROLLUP(dept_id, role)
ORDER BY dept_id, role;

/* Q75. */
SELECT r.region_name, EXTRACT(QUARTER FROM o.order_date) AS qtr, COUNT(*) AS order_count
FROM sales.orders o
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY ROLLUP(r.region_name, EXTRACT(QUARTER FROM o.order_date))
ORDER BY r.region_name, qtr;

/* ============================================================
   SECTION D: ARRAY/STRING/JSON_AGG + custom aggregates (25)
   ------------------------------------------------------------ */
/* Q76. */
SELECT cat.category_name, ARRAY_AGG(p.product_name) AS products
FROM products.products p
JOIN core.dim_brand b ON p.brand_id = b.brand_id
JOIN core.dim_category cat ON b.category_id = cat.category_id
GROUP BY cat.category_name;

/* Q77. */
SELECT r.region_name, ARRAY_AGG(s.store_name ORDER BY s.store_name) AS stores
FROM stores.stores s
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY r.region_name;

/* Q78. */
SELECT cust_id, ARRAY_AGG(order_id ORDER BY order_date DESC) AS order_ids
FROM sales.orders GROUP BY cust_id;

/* Q79. */
SELECT dept_id, STRING_AGG(first_name || ' ' || last_name, ', ' ORDER BY joining_date) AS employee_names
FROM stores.employees GROUP BY dept_id;

/* Q80. */
SELECT priority, STRING_AGG(subject, ' | ' ORDER BY created_date DESC) AS subjects
FROM (
  SELECT priority, subject, created_date,
         ROW_NUMBER() OVER (PARTITION BY priority ORDER BY created_date DESC) AS rn
  FROM support.tickets
) t
WHERE rn <= 5
GROUP BY priority;

/* Q81. */
SELECT courier_name, JSON_AGG(JSON_BUILD_OBJECT('shipment_id', shipment_id, 'date', shipped_date)) AS shipments
FROM sales.shipments GROUP BY courier_name;

/* Q82. */
SELECT c.campaign_name, JSONB_OBJECT_AGG(a.platform, a.amount) AS platform_spend
FROM marketing.ads_spend a
JOIN marketing.campaigns c ON a.campaign_id = c.campaign_id
GROUP BY c.campaign_name;

/* Q83. */
SELECT cust_id, JSON_AGG(order_id ORDER BY order_date DESC) AS orders
FROM sales.orders GROUP BY cust_id;

/* Q84. */
SELECT cat.category_name, ARRAY_AGG(DISTINCT b.brand_name) AS brand_names
FROM core.dim_brand b
JOIN core.dim_category cat ON b.category_id = cat.category_id
GROUP BY cat.category_name;

/* Q85. */
SELECT agent_id, JSONB_AGG(JSONB_BUILD_OBJECT('ticket', ticket_id, 'status', status)) AS tickets
FROM support.tickets
WHERE agent_id IS NOT NULL
GROUP BY agent_id;

/* Q86. employees has no "active" flag, so every current row is treated as active. */
SELECT store_id, ARRAY_AGG(role) AS roles
FROM stores.employees GROUP BY store_id;

/* Q87. */
SELECT session_id, ARRAY_AGG(page_url ORDER BY view_timestamp) AS clickstream
FROM web_events.page_views GROUP BY session_id;

/* Q88. */
SELECT warehouse_id, ARRAY_AGG(product_id) FILTER (WHERE quantity_on_hand < 10) AS low_stock_products
FROM supply_chain.inventory_snapshots
WHERE snapshot_date = (SELECT MAX(snapshot_date) FROM supply_chain.inventory_snapshots)
GROUP BY warehouse_id;

/* Q89. */
SELECT c.call_reason, STRING_AGG(t.transcript_text, ' --- ' ORDER BY c.call_start_time DESC) AS transcripts
FROM call_center.transcripts t
JOIN call_center.calls c ON t.call_id = c.call_id
GROUP BY c.call_reason;

/* Q90. */
SELECT lt.tier_name, ARRAY_AGG(c.email) AS member_emails
FROM loyalty.members lm
JOIN loyalty.tiers lt ON lm.tier_id = lt.tier_id
JOIN customers.customers c ON lm.customer_id = c.customer_id
GROUP BY lt.tier_name;

/* Q91. products.products has no native bit-flag column, so "is_premium" (price > 1000) is cast to an integer bit and combined with BIT_OR. */
SELECT brand_id, BIT_OR((price > 1000)::int) AS any_premium_flag
FROM products.products GROUP BY brand_id;

/* Q92. */
SELECT a.city, BOOL_OR(c.tier IN ('Gold','Platinum')) AS has_premium_customer
FROM customers.customers c
JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = TRUE
GROUP BY a.city;

/* Q93. */
SELECT cust_id, BOOL_AND(status = 'Completed') AS all_payments_completed
FROM finance.payments GROUP BY cust_id;

/* Q94. */
SELECT store_id,
       SUM(CASE WHEN order_status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS pct_cancelled
FROM sales.orders GROUP BY store_id;

/* Q95. */
SELECT cust_id, ARRAY_AGG(running_total ORDER BY order_date) AS running_totals
FROM (
  SELECT cust_id, order_date,
         SUM(net_total) OVER (PARTITION BY cust_id ORDER BY order_date) AS running_total
  FROM sales.orders
  WHERE cust_id IN (SELECT customer_id FROM customers.customers ORDER BY customer_id LIMIT 20)
) t
GROUP BY cust_id;

/* Q96. */
SELECT brand_id, MD5(STRING_AGG(product_name, ',' ORDER BY product_name)) AS product_set_hash
FROM products.products GROUP BY brand_id;

/* Q97. */
SELECT brand_id,
       ARRAY(SELECT unnest(all_products) EXCEPT SELECT unnest(ordered_products)) AS never_ordered_products
FROM (
  SELECT p.brand_id,
         ARRAY_AGG(DISTINCT p.product_id) AS all_products,
         COALESCE(ARRAY_AGG(DISTINCT oi.prod_id) FILTER (WHERE oi.prod_id IS NOT NULL), ARRAY[]::int[]) AS ordered_products
  FROM products.products p
  LEFT JOIN sales.order_items oi ON oi.prod_id = p.product_id
  GROUP BY p.brand_id
) t;

/* Q98. */
SELECT cust_id, position_no, order_id
FROM (
  SELECT cust_id, ARRAY_AGG(order_id ORDER BY order_date) AS ordered_ids
  FROM sales.orders
  WHERE cust_id IN (SELECT customer_id FROM customers.customers ORDER BY customer_id LIMIT 5)
  GROUP BY cust_id
) t
CROSS JOIN LATERAL UNNEST(t.ordered_ids) WITH ORDINALITY AS u(order_id, position_no)
ORDER BY cust_id, position_no;

/* Q99. */
SELECT store_id, JSON_AGG(JSON_BUILD_OBJECT('employee_id', employee_id, 'role', role, 'first_name', first_name)) AS employees
FROM stores.employees GROUP BY store_id;

/* Q100. */
SELECT c.customer_id,
       JSONB_BUILD_OBJECT(
         'orders',  (SELECT JSON_AGG(o.order_id) FROM sales.orders o WHERE o.cust_id = c.customer_id),
         'reviews', (SELECT JSON_AGG(r.review_id) FROM customers.reviews r WHERE r.customer_id = c.customer_id)
       ) AS customer_card
FROM customers.customers c
ORDER BY c.customer_id
LIMIT 50;

/* ============================================================
   END OF ANSWER KEY - Aggregate Functions & Grouping - HARD LEVEL (100/100)
============================================================ */
