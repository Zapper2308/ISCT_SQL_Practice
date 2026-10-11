/* ============================================================
   ANSWER KEY - Aggregate Functions & Grouping (MEDIUM LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: AGGREGATE DEEPER - CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1.  On rows (1,'A'),(2,'A'),(3,NULL): COUNT(*) = 3 (all rows); COUNT(col) = 2 (skips the NULL); COUNT(DISTINCT col) = 1 ('A' counted once, NULL ignored). */
/* Q2.  Because CASE evaluates per-row inside the aggregate (producing a value or NULL that SUM then adds/skips), while a WHERE clause would remove the non-matching rows from the WHOLE query, breaking any other aggregates computed in the same SELECT. */
/* Q3.  They differ whenever col has NULLs - AVG(col) excludes those rows from the denominator, while AVG(COALESCE(col,0)) treats them as 0 and drags the average down/up depending on the other values. */
/* Q4.  SUM(amount) adds every row's value including repeats; SUM(DISTINCT amount) adds each UNIQUE amount value only once, which is rarely what you want for money totals. */
/* Q5.  FILTER (WHERE cond) restricts which rows a specific aggregate sees, e.g. COUNT(*) FILTER (WHERE status='Delivered'); it's functionally equivalent to SUM(CASE WHEN cond THEN 1 ELSE 0 END) but reads cleaner and is PostgreSQL-native syntax. */
/* Q6.  It returns NULL for SUM/AVG/MIN/MAX (no rows to aggregate) but COUNT(*) returns 0, since COUNT is defined as "number of rows," which is a valid zero even with no rows. */
/* Q7.  Every row in a group could have a different value for that column, so the engine can't pick one deterministically - if you forget, PostgreSQL raises "column must appear in the GROUP BY clause or be used in an aggregate function". */
/* Q8.  Yes - GROUP BY DATE_TRUNC('month', order_date) groups rows by the truncated month expression, computed once per row before grouping. */
/* Q9.  GROUP BY col is safer (self-documenting, survives column reordering in SELECT); GROUP BY 1 (positional) is more compact but breaks silently if SELECT columns are reordered. */
/* Q10. WHERE order_status = 'Delivered' filters rows before grouping; HAVING SUM(CASE WHEN order_status='Delivered' THEN net_total END) > 100000 filters GROUPS after a conditional aggregate is computed - you cannot express the second one in WHERE. */
/* Q11. ROLLUP(a,b) adds subtotal rows for (a) alone and a grand-total row (NULL,NULL), on top of the normal (a,b) rows that GROUP BY a,b produces alone. */
/* Q12. CUBE produces every possible combination of subtotals (2^n groupings); ROLLUP only produces a hierarchical subset - CUBE always has >= as many rows as ROLLUP for the same columns. */
/* Q13. GROUPING SETS lets you list arbitrary, independent groupings (not just hierarchical or full cross-product ones) in a single query, e.g. GROUPING SETS((tier),(region)) - useful when you need unrelated summary levels together. */
/* Q14. GROUPING(col) returns 1 when that row is a subtotal/grand-total row where col was "rolled up" (not a real group value), and 0 when col holds an actual grouped value. */
/* Q15. Because col has one row per group's many raw rows, and SQL needs a single deterministic value per output row - without GROUP BY there's no grouping rule to collapse those many values into one. */
/* Q16. Yes, ORDER BY can reference an aggregate's column alias (e.g. ORDER BY order_count DESC); HAVING can also reference it in PostgreSQL, unlike WHERE which cannot use aliases from the same SELECT. */
/* Q17. PERCENTILE_CONT interpolates between the two closest values to return a continuous estimate; PERCENTILE_DISC returns an actual value that exists in the data set - no interpolation. */
/* Q18. Grouping by a raw TIMESTAMP produces one group per unique timestamp (often nearly one row per group), which is meaningless - the fix is to GROUP BY DATE_TRUNC('day'/'month', ts) to bucket into meaningful periods. */
/* Q19. ARRAY_AGG(col) collects every value in a group into a PostgreSQL array - useful for returning "all order_ids for this customer" as one array value per row. */
/* Q20. STRING_AGG returns one delimited TEXT string; ARRAY_AGG returns a native PostgreSQL array value that keeps individual elements typed and indexable. */
/* Q21. JSON_AGG(col) builds a JSON array from the group's rows/values - useful when the result needs to be consumed directly by an API/front-end as JSON instead of a flat table. */
/* Q22. COUNT(*) can be satisfied from index/row metadata without inspecting the column's value or NULL-ness for every row, while COUNT(col) must check each row's value for NULL. */
/* Q23. `SELECT 1 FROM t GROUP BY key` collapses each distinct key/combination down to one row cheaply, letting you COUNT(*) the result to get "number of distinct groups" without pulling any real columns. */
/* Q24. BOOL_AND(col) is true only if ALL rows in the group are true; BOOL_OR(col) is true if ANY row is true; BIT_AND/BIT_OR do the same bitwise on integer flag columns - e.g. BOOL_OR(is_premium) flags a group as "has at least one premium member". */
/* Q25. Because GROUP BY produces the summary, ORDER BY arranges it meaningfully (e.g. highest revenue first), and LIMIT trims it to a top-N list - together that's exactly what most dashboards/reports need in one query. */

/* ============================================================
   SECTION B: CONDITIONAL AGGREGATION (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT order_status, COUNT(*) AS order_count, SUM(net_total) AS total_revenue
FROM sales.orders GROUP BY order_status;

/* Q27. */
SELECT
  SUM(CASE WHEN order_status = 'Delivered' THEN 1 ELSE 0 END) AS delivered,
  SUM(CASE WHEN order_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled,
  SUM(CASE WHEN order_status = 'Returned'  THEN 1 ELSE 0 END) AS returned,
  SUM(CASE WHEN order_status = 'Shipped'   THEN 1 ELSE 0 END) AS shipped
FROM sales.orders;

/* Q28. */
SELECT
  SUM(CASE WHEN order_status = 'Delivered' THEN net_total ELSE 0 END) AS delivered_revenue,
  SUM(CASE WHEN order_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_count
FROM sales.orders;

/* Q29. */
SELECT tier, COUNT(*) AS customer_count,
       AVG(EXTRACT(YEAR FROM AGE(CURRENT_DATE, registration_date))) AS avg_tenure_years
FROM customers.customers GROUP BY tier;

/* Q30. */
SELECT priority, COUNT(*) AS ticket_count,
       AVG(EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600.0) AS avg_resolution_hours
FROM support.tickets GROUP BY priority;

/* Q31. */
SELECT device_type, COUNT(*) AS view_count, COUNT(DISTINCT customer_id) AS distinct_customers
FROM web_events.page_views GROUP BY device_type;

/* Q32. */
SELECT role, COUNT(*) AS employee_count, AVG(salary) AS avg_salary,
       MAX(salary) AS max_salary, MIN(salary) AS min_salary
FROM stores.employees GROUP BY role;

/* Q33. */
SELECT call_reason, COUNT(*) AS call_count, AVG(call_duration_seconds) AS avg_duration,
       COUNT(*) FILTER (WHERE call_duration_seconds > 300) AS long_calls
FROM call_center.calls GROUP BY call_reason;

/* Q34. */
SELECT brand_id, COUNT(*) AS product_count,
       COUNT(*) FILTER (WHERE price > 1000) AS premium_products,
       AVG(price) AS avg_price
FROM products.products GROUP BY brand_id;

/* Q35. */
SELECT category, COUNT(*) AS ticket_count,
       100.0 * COUNT(*) FILTER (WHERE status IN ('Resolved','Closed')) / COUNT(*) AS pct_resolved
FROM support.tickets GROUP BY category;

/* Q36. */
SELECT EXTRACT(YEAR FROM registration_date) AS reg_year, COUNT(*) AS new_customers,
       COUNT(*) FILTER (WHERE tier IN ('Gold','Platinum')) AS gold_platinum_count
FROM customers.customers GROUP BY EXTRACT(YEAR FROM registration_date) ORDER BY reg_year;

/* Q37. */
SELECT r.region_name, COUNT(*) AS store_count, COUNT(DISTINCT s.city) AS distinct_cities
FROM stores.stores s
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY r.region_name;

/* Q38. */
SELECT
  (SELECT COUNT(DISTINCT cust_id) FROM sales.orders) AS customers_with_orders,
  (SELECT COUNT(DISTINCT customer_id) FROM customers.reviews) AS customers_with_reviews,
  (SELECT COUNT(DISTINCT customer_id) FROM support.tickets) AS customers_with_tickets;

/* Q39. */
SELECT
  COUNT(*) FILTER (WHERE order_status = 'Delivered') AS delivered_count,
  COUNT(*) FILTER (WHERE order_status = 'Cancelled') AS cancelled_count,
  COUNT(*) FILTER (WHERE order_status = 'Processing') AS pending_count,
  COUNT(*) AS total_count
FROM sales.orders;

/* Q40. */
SELECT platform, SUM(amount) AS total_spend, COUNT(*) AS row_count, AVG(amount) AS avg_amount
FROM marketing.ads_spend GROUP BY platform;

/* Q41. */
SELECT DATE_TRUNC('month', start_date) AS campaign_month, SUM(budget) AS total_budget,
       COUNT(*) AS campaigns_active
FROM marketing.campaigns GROUP BY DATE_TRUNC('month', start_date) ORDER BY campaign_month;

/* Q42. */
SELECT exp_cat_id, SUM(amount) AS total_amount, COUNT(*) AS row_count,
       AVG(amount) AS avg_amount, STDDEV(amount) AS stddev_amount
FROM finance.expenses GROUP BY exp_cat_id;

/* Q43. */
SELECT salary_month, SUM(gross_salary) AS total_gross, SUM(net_salary) AS total_net,
       SUM(income_tax) AS total_income_tax
FROM payroll.pay_slips GROUP BY salary_month;

/* Q44. */
SELECT line_id, SUM(quantity_produced) AS total_produced, SUM(rejected_quantity) AS total_rejected,
       100.0 * SUM(rejected_quantity) / NULLIF(SUM(quantity_produced), 0) AS rejection_rate_pct
FROM manufacture.work_orders GROUP BY line_id;

/* Q45. */
SELECT warehouse_id, SUM(quantity_on_hand) AS total_on_hand
FROM supply_chain.inventory_snapshots
WHERE snapshot_date = (SELECT MAX(snapshot_date) FROM supply_chain.inventory_snapshots)
GROUP BY warehouse_id;

/* Q46. */
SELECT supplier_id, COUNT(*) AS product_count, AVG(price) AS avg_price,
       MAX(price) AS max_price, MIN(price) AS min_price
FROM products.products GROUP BY supplier_id;

/* Q47. */
SELECT tier_id, COUNT(*) AS member_count, AVG(points_balance) AS avg_points,
       MAX(points_balance) AS max_points
FROM loyalty.members GROUP BY tier_id;

/* Q48. */
SELECT category,
       100.0 * COUNT(*) FILTER (WHERE status = 'Open') / COUNT(*) AS pct_open
FROM support.tickets GROUP BY category;

/* Q49. */
SELECT page_url, COUNT(DISTINCT customer_id) AS distinct_customers, COUNT(DISTINCT session_id) AS distinct_sessions
FROM web_events.page_views GROUP BY page_url;

/* Q50. */
SELECT device_type, os, COUNT(*) AS view_count
FROM web_events.page_views GROUP BY device_type, os;

/* ============================================================
   SECTION C: MULTI-COLUMN GROUP BY + DATE BUCKETS (25)
   ------------------------------------------------------------ */
/* Q51. */
SELECT order_status, DATE_TRUNC('month', order_date) AS order_month,
       COUNT(*) AS order_count, SUM(net_total) AS total_revenue
FROM sales.orders GROUP BY order_status, DATE_TRUNC('month', order_date)
ORDER BY order_month, order_status;

/* Q52. */
SELECT tier, EXTRACT(YEAR FROM registration_date) AS reg_year, COUNT(*) AS customer_count
FROM customers.customers GROUP BY tier, EXTRACT(YEAR FROM registration_date)
ORDER BY reg_year, tier;

/* Q53. */
SELECT priority, status, COUNT(*) AS ticket_count
FROM support.tickets GROUP BY priority, status;

/* Q54. */
SELECT device_type, DATE_TRUNC('month', view_timestamp) AS view_month, COUNT(*) AS view_count
FROM web_events.page_views GROUP BY device_type, DATE_TRUNC('month', view_timestamp)
ORDER BY view_month, device_type;

/* Q55. */
SELECT platform, DATE_TRUNC('month', spend_date) AS spend_month, SUM(amount) AS total_amount
FROM marketing.ads_spend GROUP BY platform, DATE_TRUNC('month', spend_date)
ORDER BY spend_month, platform;

/* Q56. */
SELECT role, store_id, COUNT(*) AS employee_count, AVG(salary) AS avg_salary
FROM stores.employees GROUP BY role, store_id;

/* Q57. */
SELECT brand_id, (price > 1000) AS is_premium, COUNT(*) AS product_count
FROM products.products GROUP BY brand_id, (price > 1000);

/* Q58. */
SELECT call_reason, status, COUNT(*) AS call_count, SUM(call_duration_seconds) AS total_duration
FROM call_center.calls GROUP BY call_reason, status;

/* Q59. */
SELECT EXTRACT(YEAR FROM start_date) AS campaign_year, EXTRACT(QUARTER FROM start_date) AS campaign_quarter,
       SUM(budget) AS total_budget
FROM marketing.campaigns GROUP BY EXTRACT(YEAR FROM start_date), EXTRACT(QUARTER FROM start_date)
ORDER BY campaign_year, campaign_quarter;

/* Q60. */
SELECT courier_name, DATE_TRUNC('month', shipped_date) AS ship_month, COUNT(*) AS shipment_count
FROM sales.shipments GROUP BY courier_name, DATE_TRUNC('month', shipped_date)
ORDER BY ship_month, courier_name;

/* Q61. */
SELECT EXTRACT(YEAR FROM attendance_date) AS att_year, EXTRACT(MONTH FROM attendance_date) AS att_month,
       COUNT(*) AS record_count,
       SUM(EXTRACT(EPOCH FROM (check_out - check_in)) / 3600.0) AS total_hours
FROM hr.attendance GROUP BY EXTRACT(YEAR FROM attendance_date), EXTRACT(MONTH FROM attendance_date)
ORDER BY att_year, att_month;

/* Q62. */
SELECT order_status, store_id, COUNT(*) AS order_count, SUM(net_total) AS total_revenue
FROM sales.orders GROUP BY order_status, store_id;

/* Q63. */
SELECT a.city, c.tier, COUNT(*) AS customer_count
FROM customers.customers c
JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = TRUE
GROUP BY a.city, c.tier;

/* Q64. */
SELECT reason, DATE_TRUNC('month', return_date) AS return_month,
       COUNT(*) AS return_count, SUM(refund_amount) AS total_refunds
FROM sales.returns GROUP BY reason, DATE_TRUNC('month', return_date)
ORDER BY return_month, reason;

/* Q65. */
SELECT priority, DATE_TRUNC('week', created_date) AS created_week, COUNT(*) AS ticket_count
FROM support.tickets GROUP BY priority, DATE_TRUNC('week', created_date)
ORDER BY created_week, priority;

/* Q66. */
SELECT method,
       CASE WHEN status_code < 300 THEN '2xx'
            WHEN status_code < 400 THEN '3xx'
            WHEN status_code < 500 THEN '4xx'
            ELSE '5xx' END AS status_class,
       COUNT(*) AS request_count
FROM audit.api_requests GROUP BY method, status_class;

/* Q67. */
SELECT level, service_name, COUNT(*) AS log_count
FROM audit.application_logs GROUP BY level, service_name;

/* Q68. */
SELECT r.region_name, DATE_TRUNC('week', s.opening_date) AS open_week, COUNT(*) AS stores_opened
FROM stores.stores s
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY r.region_name, DATE_TRUNC('week', s.opening_date)
ORDER BY open_week, r.region_name;

/* Q69. products.products has no date column, so "fiscal quarter" is derived from each product's first sale date (earliest order_date in order_items/orders). */
SELECT b.brand_id,
       CASE WHEN EXTRACT(QUARTER FROM fs.first_order_date) = 1 THEN 'Q1'
            WHEN EXTRACT(QUARTER FROM fs.first_order_date) = 2 THEN 'Q2'
            WHEN EXTRACT(QUARTER FROM fs.first_order_date) = 3 THEN 'Q3'
            ELSE 'Q4' END AS fiscal_quarter,
       COUNT(*) AS product_count
FROM products.products p
JOIN core.dim_brand b ON p.brand_id = b.brand_id
JOIN (
  SELECT oi.prod_id, MIN(o.order_date) AS first_order_date
  FROM sales.order_items oi
  JOIN sales.orders o ON oi.order_id = o.order_id
  GROUP BY oi.prod_id
) fs ON fs.prod_id = p.product_id
GROUP BY b.brand_id, fiscal_quarter;

/* Q70. */
SELECT
  CASE WHEN EXTRACT(HOUR FROM call_start_time) BETWEEN 6 AND 11 THEN 'Morning'
       WHEN EXTRACT(HOUR FROM call_start_time) BETWEEN 12 AND 17 THEN 'Afternoon'
       WHEN EXTRACT(HOUR FROM call_start_time) BETWEEN 18 AND 22 THEN 'Evening'
       ELSE 'Night' END AS shift,
  TO_CHAR(call_start_time, 'Day') AS day_of_week,
  COUNT(*) AS call_count
FROM call_center.calls
GROUP BY shift, TO_CHAR(call_start_time, 'Day');

/* Q71. */
SELECT supplier_id, warehouse_id, SUM(quantity) AS total_quantity
FROM supply_chain.shipments GROUP BY supplier_id, warehouse_id;

/* Q72. */
SELECT line_id, status, COUNT(*) AS work_order_count, SUM(quantity_produced) AS total_produced
FROM manufacture.work_orders GROUP BY line_id, status;

/* Q73. */
SELECT exp_cat_id, DATE_TRUNC('month', expense_date) AS expense_month, SUM(amount) AS total_amount
FROM finance.expenses GROUP BY exp_cat_id, DATE_TRUNC('month', expense_date)
ORDER BY expense_month, exp_cat_id;

/* Q74. */
SELECT tier_id, DATE_TRUNC('month', join_date) AS join_month, COUNT(*) AS member_count
FROM loyalty.members GROUP BY tier_id, DATE_TRUNC('month', join_date)
ORDER BY join_month, tier_id;

/* Q75. */
SELECT salary_year, salary_month, SUM(gross_salary) AS total_gross_salary
FROM payroll.pay_slips GROUP BY salary_year, salary_month
ORDER BY salary_year, salary_month;

/* ============================================================
   SECTION D: HAVING / FILTER / GROUPING SETS (25)
   ------------------------------------------------------------ */
/* Q76. */
SELECT order_status, COUNT(*) AS order_count, SUM(net_total) AS total_revenue
FROM sales.orders GROUP BY order_status
HAVING COUNT(*) > 1000 AND SUM(net_total) > 5000000;

/* Q77. */
SELECT cust_id, COUNT(*) AS order_count
FROM sales.orders GROUP BY cust_id HAVING COUNT(*) > 10;

/* Q78. */
SELECT prod_id, SUM(quantity) AS total_quantity
FROM sales.order_items GROUP BY prod_id HAVING SUM(quantity) > 100;

/* Q79. */
SELECT employee_id, SUM(net_salary) AS total_pay
FROM payroll.pay_slips GROUP BY employee_id HAVING SUM(net_salary) > 1000000;

/* Q80. */
SELECT platform, AVG(amount) AS avg_amount, COUNT(*) AS row_count
FROM marketing.ads_spend GROUP BY platform HAVING AVG(amount) > 5000 AND COUNT(*) > 10;

/* Q81. */
SELECT brand_id, COUNT(*) AS product_count, AVG(price) AS avg_price
FROM products.products GROUP BY brand_id
HAVING COUNT(*) > 50 AND AVG(price) BETWEEN 1000 AND 10000;

/* Q82. */
SELECT city, COUNT(*) AS store_count
FROM stores.stores GROUP BY city HAVING COUNT(*) >= 3;

/* Q83. */
SELECT tier_id, COUNT(*) AS member_count, AVG(points_balance) AS avg_points
FROM loyalty.members GROUP BY tier_id
HAVING COUNT(*) > 1000 AND AVG(points_balance) > 500;

/* Q84. */
SELECT category, COUNT(*) AS ticket_count,
       100.0 * COUNT(*) FILTER (WHERE status IN ('Resolved','Closed')) / COUNT(*) AS resolution_rate_pct
FROM support.tickets GROUP BY category
HAVING COUNT(*) > 500
   AND 100.0 * COUNT(*) FILTER (WHERE status IN ('Resolved','Closed')) / COUNT(*) < 50;

/* Q85. */
SELECT DATE_TRUNC('month', order_date) AS order_month, COUNT(*) AS order_count, SUM(net_total) AS total_revenue
FROM sales.orders GROUP BY DATE_TRUNC('month', order_date)
HAVING COUNT(*) > 10000 AND SUM(net_total) > 50000000;

/* Q86. */
SELECT
  COUNT(*) FILTER (WHERE order_status = 'Delivered') AS delivered,
  COUNT(*) FILTER (WHERE order_status = 'Cancelled') AS cancelled,
  COUNT(*) FILTER (WHERE order_status = 'Processing') AS pending,
  COUNT(*) FILTER (WHERE order_status = 'Shipped')    AS shipped,
  COUNT(*) FILTER (WHERE order_status = 'Returned')   AS returned,
  COUNT(*) FILTER (WHERE order_status = 'Failed')     AS failed
FROM sales.orders;

/* Q87. */
SELECT
  COUNT(DISTINCT customer_id) FILTER (WHERE tier = 'Bronze')   AS bronze,
  COUNT(DISTINCT customer_id) FILTER (WHERE tier = 'Silver')   AS silver,
  COUNT(DISTINCT customer_id) FILTER (WHERE tier = 'Gold')     AS gold,
  COUNT(DISTINCT customer_id) FILTER (WHERE tier = 'Platinum') AS platinum
FROM customers.customers;

/* Q88. */
SELECT r.region_name, SUM(o.net_total) AS total_revenue
FROM sales.orders o
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY r.region_name;

/* Q89. */
SELECT order_status, DATE_TRUNC('month', order_date) AS order_month, SUM(net_total) AS total_revenue
FROM sales.orders
GROUP BY ROLLUP(order_status, DATE_TRUNC('month', order_date))
ORDER BY order_status, order_month;

/* Q90. */
SELECT device_type, os, COUNT(*) AS view_count
FROM web_events.page_views
GROUP BY CUBE(device_type, os)
ORDER BY device_type, os;

/* Q91. */
SELECT tier, EXTRACT(YEAR FROM registration_date) AS reg_year, COUNT(*) AS customer_count
FROM customers.customers
GROUP BY GROUPING SETS ((tier), (EXTRACT(YEAR FROM registration_date)))
ORDER BY tier, reg_year;

/* Q92. */
SELECT dept_id, role, COUNT(*) AS employee_count
FROM stores.employees
GROUP BY ROLLUP(dept_id, role)
ORDER BY dept_id, role;

/* Q93. */
SELECT dept_id, role, COUNT(*) AS employee_count,
       GROUPING(dept_id) AS is_dept_subtotal, GROUPING(role) AS is_role_subtotal
FROM stores.employees
GROUP BY ROLLUP(dept_id, role)
ORDER BY dept_id, role;

/* Q94. */
SELECT r.region_name,
       COUNT(*) FILTER (WHERE o.order_status = 'Delivered') AS delivered_count,
       COUNT(*) FILTER (WHERE o.order_status = 'Cancelled') AS cancelled_count
FROM sales.orders o
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY r.region_name;

/* Q95. */
SELECT platform, SUM(amount) FILTER (WHERE spend_date >= '2025-01-01') AS spend_since_2025
FROM marketing.ads_spend GROUP BY platform;

/* Q96. */
SELECT b.brand_id, COUNT(*) FILTER (WHERE r.rating = 5) AS five_star_reviews
FROM customers.reviews r
JOIN products.products p ON r.product_id = p.product_id
JOIN core.dim_brand b ON p.brand_id = b.brand_id
GROUP BY b.brand_id;

/* Q97. */
SELECT category, STRING_AGG(subject, ' | ' ORDER BY created_date DESC) AS latest_subjects
FROM (
  SELECT category, subject, created_date,
         ROW_NUMBER() OVER (PARTITION BY category ORDER BY created_date DESC) AS rn
  FROM support.tickets
) t
WHERE rn <= 5
GROUP BY category;

/* Q98. */
SELECT region_name, store_name, total_revenue
FROM (
  SELECT r.region_name, s.store_name, SUM(o.net_total) AS total_revenue,
         RANK() OVER (PARTITION BY r.region_name ORDER BY SUM(o.net_total) DESC) AS rnk
  FROM sales.orders o
  JOIN stores.stores s ON o.store_id = s.store_id
  JOIN core.dim_region r ON s.region_id = r.region_id
  GROUP BY r.region_name, s.store_name
) ranked
WHERE rnk <= 3
ORDER BY region_name, rnk;

/* Q99. */
SELECT tier_id, MAX(points_balance) AS max_points, MIN(points_balance) AS min_points, AVG(points_balance) AS avg_points
FROM loyalty.members GROUP BY tier_id;

/* Q100. */
SELECT category,
       100.0 * COUNT(*) FILTER (WHERE priority = 'High') / COUNT(*) AS pct_high,
       100.0 * COUNT(*) FILTER (WHERE priority = 'Critical') / COUNT(*) AS pct_critical
FROM support.tickets GROUP BY category;

/* ============================================================
   END OF ANSWER KEY - Aggregate Functions & Grouping - MEDIUM LEVEL (100/100)
============================================================ */
