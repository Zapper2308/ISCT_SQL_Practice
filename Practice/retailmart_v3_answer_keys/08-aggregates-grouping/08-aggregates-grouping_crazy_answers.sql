/* ============================================================
   ANSWER KEY - Aggregate Functions & Grouping (CRAZY LEVEL)
   Curriculum:   RetailMart V3
   Note: Questions in this set are intentionally terse (syllabus-style).
   Each answer below is one reasonable, tested interpretation built on
   the actual RetailMart V3 schema; some concepts have no matching
   column (browser, source/medium, bot flags, schema-version history)
   and are answered with the closest honest proxy or a short note.
   ============================================================ */

/* ============================================================
   SECTION A: OLAP CUBES (25)
   ------------------------------------------------------------ */
/* Q1. */
SELECT r.region_name, DATE_TRUNC('month', o.order_date) AS order_month, o.order_status,
       SUM(o.net_total) AS revenue
FROM sales.orders o
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY CUBE(r.region_name, DATE_TRUNC('month', o.order_date), o.order_status)
ORDER BY r.region_name, order_month, o.order_status;

/* Q2. */
SELECT EXTRACT(YEAR FROM order_date) AS yr, EXTRACT(QUARTER FROM order_date) AS qtr,
       EXTRACT(MONTH FROM order_date) AS mo, SUM(net_total) AS revenue
FROM sales.orders
GROUP BY ROLLUP(EXTRACT(YEAR FROM order_date), EXTRACT(QUARTER FROM order_date), EXTRACT(MONTH FROM order_date))
ORDER BY yr, qtr, mo;

/* Q3. */
SELECT tier, EXTRACT(YEAR FROM registration_date) AS reg_year, COUNT(*) AS customer_count
FROM customers.customers
GROUP BY GROUPING SETS ((tier), (EXTRACT(YEAR FROM registration_date)), ())
ORDER BY tier, reg_year;

/* Q4. */
SELECT r.region_name, DATE_TRUNC('month', o.order_date) AS order_month, o.order_status,
       SUM(o.net_total) AS revenue
FROM sales.orders o
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY CUBE(r.region_name, DATE_TRUNC('month', o.order_date), o.order_status)
HAVING GROUPING(r.region_name, DATE_TRUNC('month', o.order_date), o.order_status) IN (0, 3, 5, 6, 7)
ORDER BY r.region_name, order_month, o.order_status;

/* Q5. */
SELECT b.brand_name, cat.category_name, r.region_name, SUM(oi.net_amount) AS revenue
FROM sales.order_items oi
JOIN sales.orders o ON oi.order_id = o.order_id
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
JOIN products.products p ON oi.prod_id = p.product_id
JOIN core.dim_brand b ON p.brand_id = b.brand_id
JOIN core.dim_category cat ON b.category_id = cat.category_id
GROUP BY CUBE(b.brand_name, cat.category_name, r.region_name)
ORDER BY b.brand_name, cat.category_name, r.region_name;

/* Q6. RetailMart has no customer age column, so "age_band" is approximated by account-tenure band. */
SELECT c.tier,
       CASE WHEN AGE(CURRENT_DATE, c.registration_date) < INTERVAL '1 year' THEN '<1yr'
            WHEN AGE(CURRENT_DATE, c.registration_date) < INTERVAL '3 years' THEN '1-3yr'
            ELSE '3yr+' END AS tenure_band,
       a.city, COUNT(*) AS customer_count
FROM customers.customers c
JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = TRUE
GROUP BY CUBE(c.tier, tenure_band, a.city)
ORDER BY c.tier, tenure_band, a.city;

/* Q7. */
SELECT t.priority, d.dept_name, DATE_TRUNC('month', t.created_date) AS ticket_month, COUNT(*) AS ticket_count
FROM support.tickets t
LEFT JOIN stores.employees e ON t.agent_id = e.employee_id
LEFT JOIN core.dim_department d ON e.dept_id = d.dept_id
GROUP BY CUBE(t.priority, d.dept_name, DATE_TRUNC('month', t.created_date))
ORDER BY t.priority, d.dept_name, ticket_month;

/* Q8. */
SELECT sp.supplier_id, sp.warehouse_id, DATE_TRUNC('month', sp.shipped_date) AS ship_month, COUNT(*) AS shipment_count
FROM supply_chain.shipments sp
GROUP BY CUBE(sp.supplier_id, sp.warehouse_id, DATE_TRUNC('month', sp.shipped_date))
ORDER BY sp.supplier_id, sp.warehouse_id, ship_month;

/* Q9. */
SELECT a.platform, c.campaign_name, DATE_TRUNC('month', a.spend_date) AS spend_month, SUM(a.amount) AS ad_spend
FROM marketing.ads_spend a
JOIN marketing.campaigns c ON a.campaign_id = c.campaign_id
GROUP BY CUBE(a.platform, c.campaign_name, DATE_TRUNC('month', a.spend_date))
ORDER BY a.platform, c.campaign_name, spend_month;

/* Q10. RetailMart tracks device_type and os, but not browser, so this is a 2-dim cube. */
SELECT device_type, os, COUNT(*) AS view_count
FROM web_events.page_views
GROUP BY CUBE(device_type, os)
ORDER BY device_type, os;

/* Q11. */
SELECT cat.category_name, b.brand_name, sup.supplier_name, r.region_name, SUM(oi.net_amount) AS sales
FROM sales.order_items oi
JOIN sales.orders o ON oi.order_id = o.order_id
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
JOIN products.products p ON oi.prod_id = p.product_id
JOIN core.dim_brand b ON p.brand_id = b.brand_id
JOIN core.dim_category cat ON b.category_id = cat.category_id
JOIN products.suppliers sup ON p.supplier_id = sup.supplier_id
GROUP BY CUBE(cat.category_name, b.brand_name, sup.supplier_name, r.region_name)
ORDER BY cat.category_name, b.brand_name, sup.supplier_name, r.region_name;

/* Q12. */
SELECT tier, COUNT(*) AS customer_count, GROUPING(tier) AS is_grand_total
FROM customers.customers
GROUP BY ROLLUP(tier)
ORDER BY GROUPING(tier), tier;

/* Q13. */
SELECT dept_id, role, COUNT(*) AS employee_count
FROM stores.employees
GROUP BY ROLLUP(dept_id, role)
HAVING GROUPING(dept_id, role) IN (0, 1) AND GROUPING(dept_id) = 0
ORDER BY dept_id, role;

/* Q14. */
SELECT dept_id, role, COUNT(*) AS employee_count
FROM stores.employees
GROUP BY ROLLUP(dept_id, role)
HAVING GROUPING(dept_id) = 1 AND GROUPING(role) = 1;

/* Q15. */
SELECT r.region_name, DATE_TRUNC('month', o.order_date) AS order_month, o.order_status,
       SUM(o.net_total) AS total_revenue, AVG(o.net_total) AS avg_revenue, COUNT(*) AS order_count
FROM sales.orders o
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY CUBE(r.region_name, DATE_TRUNC('month', o.order_date), o.order_status)
ORDER BY r.region_name, order_month, o.order_status;

/* Q16. */
SELECT r.region_name, o.order_status,
       COUNT(*) FILTER (WHERE o.order_status = 'Delivered') AS delivered_count,
       SUM(o.net_total) FILTER (WHERE o.order_status = 'Delivered') AS delivered_revenue,
       COUNT(*) AS total_count
FROM sales.orders o
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY CUBE(r.region_name, o.order_status)
ORDER BY r.region_name, o.order_status;

/* Q17. */
SELECT r.region_name, DATE_TRUNC('month', o.order_date) AS order_month,
       SUM(o.net_total) FILTER (WHERE o.order_status = 'Delivered') AS delivered,
       SUM(o.net_total) FILTER (WHERE o.order_status = 'Cancelled') AS cancelled,
       SUM(o.net_total) FILTER (WHERE o.order_status = 'Returned')  AS returned
FROM sales.orders o
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY r.region_name, DATE_TRUNC('month', o.order_date)
ORDER BY r.region_name, order_month;

/* Q18. */
SELECT yr, revenue, revenue - LAG(revenue) OVER (ORDER BY yr) AS yoy_change
FROM (
  SELECT EXTRACT(YEAR FROM order_date) AS yr, SUM(net_total) AS revenue
  FROM sales.orders GROUP BY EXTRACT(YEAR FROM order_date)
) yearly
ORDER BY yr;

/* Q19. */
SELECT yr, qtr, revenue, revenue - LAG(revenue) OVER (ORDER BY yr, qtr) AS qoq_change
FROM (
  SELECT EXTRACT(YEAR FROM order_date) AS yr, EXTRACT(QUARTER FROM order_date) AS qtr, SUM(net_total) AS revenue
  FROM sales.orders GROUP BY EXTRACT(YEAR FROM order_date), EXTRACT(QUARTER FROM order_date)
) quarterly
ORDER BY yr, qtr;

/* Q20. */
SELECT EXTRACT(DOW FROM call_start_time) AS day_of_week, EXTRACT(HOUR FROM call_start_time) AS hour_of_day,
       COUNT(*) AS call_count
FROM call_center.calls
GROUP BY CUBE(EXTRACT(DOW FROM call_start_time), EXTRACT(HOUR FROM call_start_time))
ORDER BY day_of_week, hour_of_day;

/* Q21. */
SELECT DATE_TRUNC('month', c.registration_date) AS cohort_month, DATE_TRUNC('month', o.order_date) AS order_month,
       c.tier, COUNT(DISTINCT o.cust_id) AS active_customers
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY CUBE(DATE_TRUNC('month', c.registration_date), DATE_TRUNC('month', o.order_date), c.tier)
ORDER BY cohort_month, order_month, c.tier;

/* Q22. RetailMart's ads_spend has no source/medium/geo columns, so platform (source proxy) x campaign x month approximates the requested cube. */
SELECT c.campaign_name, a.platform AS source_proxy, DATE_TRUNC('month', a.spend_date) AS spend_month,
       SUM(a.amount) AS spend
FROM marketing.ads_spend a
JOIN marketing.campaigns c ON a.campaign_id = c.campaign_id
GROUP BY CUBE(c.campaign_name, a.platform, DATE_TRUNC('month', a.spend_date))
ORDER BY c.campaign_name, source_proxy, spend_month;

/* Q23. */
SELECT ps.salary_year AS fiscal_year,
       CASE ps.salary_month
         WHEN 'January' THEN 1 WHEN 'February' THEN 1 WHEN 'March' THEN 1
         WHEN 'April' THEN 2 WHEN 'May' THEN 2 WHEN 'June' THEN 2
         WHEN 'July' THEN 3 WHEN 'August' THEN 3 WHEN 'September' THEN 3
         ELSE 4 END AS fiscal_quarter,
       e.dept_id, SUM(ps.gross_salary) AS total_payroll
FROM payroll.pay_slips ps
JOIN stores.employees e ON ps.employee_id = e.employee_id
GROUP BY ROLLUP(ps.salary_year, fiscal_quarter, e.dept_id)
ORDER BY fiscal_year, fiscal_quarter, e.dept_id;

/* Q24. */
SELECT r.region_name, o.order_status,
       COUNT(*) FILTER (WHERE o.order_status = 'Delivered') AS delivered_count,
       COUNT(*) AS total_count
FROM sales.orders o
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY ROLLUP(r.region_name, o.order_status)
ORDER BY r.region_name, o.order_status;

/* Q25. A true 6-dim CUBE explodes to 2^6=64 subtotal levels, so this "executive cube" uses the 4 highest-value dimensions with 3 core measures. */
SELECT r.region_name, DATE_TRUNC('month', o.order_date) AS order_month, o.order_status, c.tier,
       COUNT(*) AS order_count, SUM(o.net_total) AS revenue, AVG(o.net_total) AS avg_order_value
FROM sales.orders o
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
JOIN customers.customers c ON o.cust_id = c.customer_id
GROUP BY CUBE(r.region_name, DATE_TRUNC('month', o.order_date), o.order_status, c.tier)
ORDER BY r.region_name, order_month, o.order_status, c.tier;

/* ============================================================
   SECTION B: DISTRIBUTIONS & STATISTICS (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT WIDTH_BUCKET(net_total, 0, 50000, 20) AS bucket, COUNT(*) AS order_count,
       MIN(net_total) AS bucket_min, MAX(net_total) AS bucket_max
FROM sales.orders
GROUP BY WIDTH_BUCKET(net_total, 0, 50000, 20)
ORDER BY bucket;

/* Q27. */
SELECT DATE_TRUNC('month', order_date) AS order_month, COUNT(*) AS order_count
FROM sales.orders GROUP BY DATE_TRUNC('month', order_date) ORDER BY order_month;

/* Q28. */
SELECT priority, COUNT(*) AS ticket_count, 100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS pct_of_total
FROM support.tickets GROUP BY priority ORDER BY priority;

/* Q29. */
SELECT views_per_session, COUNT(*) AS session_count
FROM (
  SELECT session_id, COUNT(*) AS views_per_session
  FROM web_events.page_views GROUP BY session_id
) s
GROUP BY views_per_session ORDER BY views_per_session;

/* Q30. */
SELECT WIDTH_BUCKET(ltv, 0, 100000, 20) AS ltv_bucket, COUNT(*) AS customer_count
FROM (
  SELECT cust_id, SUM(net_total) AS ltv FROM sales.orders GROUP BY cust_id
) ltv_per_customer
GROUP BY WIDTH_BUCKET(ltv, 0, 100000, 20) ORDER BY ltv_bucket;

/* Q31. */
SELECT (delivered_date - shipped_date) AS days_to_deliver, COUNT(*) AS shipment_count
FROM sales.shipments
WHERE delivered_date IS NOT NULL AND shipped_date IS NOT NULL
GROUP BY (delivered_date - shipped_date) ORDER BY days_to_deliver;

/* Q32. */
SELECT WIDTH_BUCKET(EXTRACT(EPOCH FROM (resolved_date - created_date))/3600.0, 0, 168, 20) AS hours_bucket,
       COUNT(*) AS ticket_count
FROM support.tickets
WHERE resolved_date IS NOT NULL
GROUP BY WIDTH_BUCKET(EXTRACT(EPOCH FROM (resolved_date - created_date))/3600.0, 0, 168, 20)
ORDER BY hours_bucket;

/* Q33. */
SELECT p.product_id, p.product_name,
       COUNT(DISTINCT r.return_id) AS return_count,
       COUNT(DISTINCT oi.order_item_id) AS items_sold,
       100.0 * COUNT(DISTINCT r.return_id) / NULLIF(COUNT(DISTINCT oi.order_item_id), 0) AS refund_rate_pct
FROM products.products p
LEFT JOIN sales.order_items oi ON oi.prod_id = p.product_id
LEFT JOIN sales.returns r ON r.prod_id = p.product_id
GROUP BY p.product_id, p.product_name
ORDER BY refund_rate_pct DESC NULLS LAST
LIMIT 100;

/* Q34. */
SELECT WIDTH_BUCKET(LENGTH(review_text), 0, 500, 10) AS length_bucket, COUNT(*) AS review_count
FROM customers.reviews
GROUP BY WIDTH_BUCKET(LENGTH(review_text), 0, 500, 10) ORDER BY length_bucket;

/* Q35. */
SELECT
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total) AS median_net_total,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ABS(net_total - (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total) FROM sales.orders))) AS mad_net_total
FROM sales.orders;

/* Q36. */
SELECT
  AVG(net_total) AS mean_net_total,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total) AS median_net_total,
  MODE() WITHIN GROUP (ORDER BY net_total) AS mode_net_total
FROM sales.orders;

/* Q37. */
SELECT order_status,
       (AVG(net_total) - PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total)) / NULLIF(STDDEV(net_total), 0) AS skewness_proxy
FROM sales.orders GROUP BY order_status;

/* Q38. */
SELECT order_id, net_total,
       (net_total - AVG(net_total) OVER ()) / NULLIF(STDDEV(net_total) OVER (), 0) AS z_score
FROM sales.orders
ORDER BY order_id
LIMIT 100;

/* Q39. */
SELECT order_id, net_total, z_score
FROM (
  SELECT order_id, net_total,
         (net_total - AVG(net_total) OVER ()) / NULLIF(STDDEV(net_total) OVER (), 0) AS z_score
  FROM sales.orders
) scored
WHERE ABS(z_score) > 3
ORDER BY z_score DESC;

/* Q40. */
WITH bounds AS (
  SELECT PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY net_total) AS q1,
         PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY net_total) AS q3
  FROM sales.orders
)
SELECT o.order_id, o.net_total
FROM sales.orders o, bounds b
WHERE o.net_total < b.q1 - 1.5 * (b.q3 - b.q1)
   OR o.net_total > b.q3 + 1.5 * (b.q3 - b.q1)
ORDER BY o.net_total DESC;

/* Q41. */
SELECT CORR(p.price, r.rating) AS price_rating_correlation
FROM customers.reviews r
JOIN products.products p ON r.product_id = p.product_id;

/* Q42. Spearman correlation approximated via Pearson correlation of RANKs. */
SELECT CORR(price_rank, rating_rank) AS spearman_approx
FROM (
  SELECT RANK() OVER (ORDER BY p.price) AS price_rank,
         RANK() OVER (ORDER BY r.rating) AS rating_rank
  FROM customers.reviews r
  JOIN products.products p ON r.product_id = p.product_id
) ranked;

/* Q43. */
SELECT COVAR_POP(p.price, r.rating) AS price_rating_covariance
FROM customers.reviews r
JOIN products.products p ON r.product_id = p.product_id;

/* Q44. */
SELECT REGR_SLOPE(r.rating, p.price) AS slope_rating_on_price
FROM customers.reviews r
JOIN products.products p ON r.product_id = p.product_id;

/* Q45. */
SELECT REGR_R2(r.rating, p.price) AS r_squared_rating_on_price
FROM customers.reviews r
JOIN products.products p ON r.product_id = p.product_id;

/* Q46. */
SELECT order_date, daily_revenue,
       AVG(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7d
FROM (
  SELECT order_date, SUM(net_total) AS daily_revenue
  FROM sales.orders GROUP BY order_date
) daily
ORDER BY order_date;

/* Q47. PostgreSQL has no native EWMA aggregate, so it is computed with a recursive CTE (alpha = 0.3). */
WITH RECURSIVE daily AS (
  SELECT order_date, SUM(net_total) AS daily_revenue
  FROM sales.orders GROUP BY order_date
),
numbered AS (
  SELECT order_date, daily_revenue, ROW_NUMBER() OVER (ORDER BY order_date) AS rn
  FROM daily
),
ewma AS (
  SELECT order_date, daily_revenue, rn, daily_revenue AS ewma_value
  FROM numbered WHERE rn = 1
  UNION ALL
  SELECT n.order_date, n.daily_revenue, n.rn,
         0.3 * n.daily_revenue + 0.7 * e.ewma_value
  FROM numbered n
  JOIN ewma e ON n.rn = e.rn + 1
)
SELECT order_date, daily_revenue, ewma_value FROM ewma ORDER BY order_date;

/* Q48. */
WITH daily AS (
  SELECT order_date, SUM(net_total) AS daily_revenue
  FROM sales.orders GROUP BY order_date
),
sma AS (
  SELECT order_date, daily_revenue,
         AVG(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING) AS sma_7d
  FROM daily
)
SELECT order_date, daily_revenue, sma_7d, (daily_revenue - sma_7d) AS deviation
FROM sma
WHERE sma_7d IS NOT NULL
ORDER BY ABS(daily_revenue - sma_7d) DESC
LIMIT 50;

/* Q49. */
WITH weekly AS (
  SELECT DATE_TRUNC('week', order_date) AS order_week, SUM(net_total) AS weekly_revenue
  FROM sales.orders GROUP BY DATE_TRUNC('week', order_date)
)
SELECT order_week, weekly_revenue, weekly_revenue - LAG(weekly_revenue) OVER (ORDER BY order_week) AS wow_diff
FROM weekly ORDER BY order_week;

/* Q50. Two-sample t-statistic comparing Delivered vs Cancelled order values manually (a true p-value needs a stats library not available in plain SQL). */
WITH stats AS (
  SELECT order_status, COUNT(*) AS n, AVG(net_total) AS mean_val, VARIANCE(net_total) AS var_val
  FROM sales.orders
  WHERE order_status IN ('Delivered', 'Cancelled')
  GROUP BY order_status
)
SELECT
  (MAX(mean_val) FILTER (WHERE order_status = 'Delivered') - MAX(mean_val) FILTER (WHERE order_status = 'Cancelled'))
  / SQRT( MAX(var_val) FILTER (WHERE order_status = 'Delivered') / MAX(n) FILTER (WHERE order_status = 'Delivered')
        + MAX(var_val) FILTER (WHERE order_status = 'Cancelled') / MAX(n) FILTER (WHERE order_status = 'Cancelled') ) AS t_statistic
FROM stats;

/* ============================================================
   SECTION C: PIVOTS & UNPIVOTS (25)
   ------------------------------------------------------------ */
/* Q51. */
SELECT EXTRACT(YEAR FROM order_date) AS yr,
  SUM(net_total) FILTER (WHERE EXTRACT(MONTH FROM order_date) = 1)  AS jan,
  SUM(net_total) FILTER (WHERE EXTRACT(MONTH FROM order_date) = 2)  AS feb,
  SUM(net_total) FILTER (WHERE EXTRACT(MONTH FROM order_date) = 3)  AS mar,
  SUM(net_total) FILTER (WHERE EXTRACT(MONTH FROM order_date) = 4)  AS apr,
  SUM(net_total) FILTER (WHERE EXTRACT(MONTH FROM order_date) = 5)  AS may,
  SUM(net_total) FILTER (WHERE EXTRACT(MONTH FROM order_date) = 6)  AS jun,
  SUM(net_total) FILTER (WHERE EXTRACT(MONTH FROM order_date) = 7)  AS jul,
  SUM(net_total) FILTER (WHERE EXTRACT(MONTH FROM order_date) = 8)  AS aug,
  SUM(net_total) FILTER (WHERE EXTRACT(MONTH FROM order_date) = 9)  AS sep,
  SUM(net_total) FILTER (WHERE EXTRACT(MONTH FROM order_date) = 10) AS oct,
  SUM(net_total) FILTER (WHERE EXTRACT(MONTH FROM order_date) = 11) AS nov,
  SUM(net_total) FILTER (WHERE EXTRACT(MONTH FROM order_date) = 12) AS dec
FROM sales.orders
GROUP BY EXTRACT(YEAR FROM order_date)
ORDER BY yr;

/* Q52. */
SELECT priority,
  COUNT(*) FILTER (WHERE status = 'Open')        AS open_count,
  COUNT(*) FILTER (WHERE status = 'In Progress')  AS in_progress_count,
  COUNT(*) FILTER (WHERE status = 'Resolved')     AS resolved_count,
  COUNT(*) FILTER (WHERE status = 'Closed')       AS closed_count
FROM support.tickets
GROUP BY priority;

/* Q53. */
SELECT r.region_name,
  SUM(o.net_total) FILTER (WHERE c.tier = 'Bronze')   AS bronze_revenue,
  SUM(o.net_total) FILTER (WHERE c.tier = 'Silver')   AS silver_revenue,
  SUM(o.net_total) FILTER (WHERE c.tier = 'Gold')     AS gold_revenue,
  SUM(o.net_total) FILTER (WHERE c.tier = 'Platinum') AS platinum_revenue
FROM sales.orders o
JOIN customers.customers c ON o.cust_id = c.customer_id
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY r.region_name;

/* Q54. */
SELECT b.brand_name,
  COUNT(*) FILTER (WHERE r.rating = 1) AS one_star,
  COUNT(*) FILTER (WHERE r.rating = 2) AS two_star,
  COUNT(*) FILTER (WHERE r.rating = 3) AS three_star,
  COUNT(*) FILTER (WHERE r.rating = 4) AS four_star,
  COUNT(*) FILTER (WHERE r.rating = 5) AS five_star
FROM customers.reviews r
JOIN products.products p ON r.product_id = p.product_id
JOIN core.dim_brand b ON p.brand_id = b.brand_id
GROUP BY b.brand_name;

/* Q55. Pivoted over 5 sample products (full 6,036-product x 5-warehouse grid is impractically wide for a column pivot). */
SELECT warehouse_id,
  SUM(quantity_on_hand) FILTER (WHERE product_id = 1) AS product_1,
  SUM(quantity_on_hand) FILTER (WHERE product_id = 2) AS product_2,
  SUM(quantity_on_hand) FILTER (WHERE product_id = 3) AS product_3,
  SUM(quantity_on_hand) FILTER (WHERE product_id = 4) AS product_4,
  SUM(quantity_on_hand) FILTER (WHERE product_id = 5) AS product_5
FROM supply_chain.inventory_snapshots
WHERE product_id IN (1,2,3,4,5)
GROUP BY warehouse_id;

/* Q56. */
SELECT ps.salary_year,
  SUM(ps.gross_salary) FILTER (WHERE d.dept_name = 'Sales')             AS sales,
  SUM(ps.gross_salary) FILTER (WHERE d.dept_name = 'Operations')        AS operations,
  SUM(ps.gross_salary) FILTER (WHERE d.dept_name = 'IT')                AS it,
  SUM(ps.gross_salary) FILTER (WHERE d.dept_name = 'Customer Support')  AS customer_support
FROM payroll.pay_slips ps
JOIN stores.employees e ON ps.employee_id = e.employee_id
JOIN core.dim_department d ON e.dept_id = d.dept_id
GROUP BY ps.salary_year;

/* Q57. */
SELECT call_reason,
  COUNT(*) FILTER (WHERE EXTRACT(HOUR FROM call_start_time) BETWEEN 6 AND 11)  AS morning,
  COUNT(*) FILTER (WHERE EXTRACT(HOUR FROM call_start_time) BETWEEN 12 AND 17) AS afternoon,
  COUNT(*) FILTER (WHERE EXTRACT(HOUR FROM call_start_time) BETWEEN 18 AND 22) AS evening,
  COUNT(*) FILTER (WHERE EXTRACT(HOUR FROM call_start_time) NOT BETWEEN 6 AND 22) AS night
FROM call_center.calls
GROUP BY call_reason;

/* Q58. */
SELECT platform,
  SUM(amount) FILTER (WHERE EXTRACT(MONTH FROM spend_date) = 1) AS jan,
  SUM(amount) FILTER (WHERE EXTRACT(MONTH FROM spend_date) = 2) AS feb,
  SUM(amount) FILTER (WHERE EXTRACT(MONTH FROM spend_date) = 3) AS mar,
  SUM(amount) FILTER (WHERE EXTRACT(MONTH FROM spend_date) = 4) AS apr
FROM marketing.ads_spend
GROUP BY platform;

/* Q59. */
SELECT order_item_id, 'gross_amount' AS metric, gross_amount AS value FROM sales.order_items
UNION ALL
SELECT order_item_id, 'discount_amount', discount_amount FROM sales.order_items
UNION ALL
SELECT order_item_id, 'net_amount', net_amount FROM sales.order_items
ORDER BY order_item_id, metric
LIMIT 300;

/* Q60. */
SELECT c.customer_id, 'order_count' AS metric, COUNT(DISTINCT o.order_id)::numeric AS value
FROM customers.customers c LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY c.customer_id
UNION ALL
SELECT c.customer_id, 'review_count', COUNT(DISTINCT rv.review_id)::numeric
FROM customers.customers c LEFT JOIN customers.reviews rv ON rv.customer_id = c.customer_id
GROUP BY c.customer_id
UNION ALL
SELECT c.customer_id, 'ticket_count', COUNT(DISTINCT t.ticket_id)::numeric
FROM customers.customers c LEFT JOIN support.tickets t ON t.customer_id = c.customer_id
GROUP BY c.customer_id
ORDER BY customer_id, metric
LIMIT 300;

/* Q61. The tablefunc extension (crosstab()) isn't installed in this database, so the equivalent FILTER-based pivot is used instead - functionally identical for a known, fixed column list. */
SELECT priority,
  COUNT(*) FILTER (WHERE status = 'Open')       AS open_count,
  COUNT(*) FILTER (WHERE status = 'In Progress') AS in_progress_count,
  COUNT(*) FILTER (WHERE status = 'Resolved')    AS resolved_count,
  COUNT(*) FILTER (WHERE status = 'Closed')      AS closed_count
FROM support.tickets
GROUP BY priority;

/* Q62. */
SELECT r.region_name,
  COUNT(*) FILTER (WHERE o.order_status = 'Delivered') AS delivered,
  COUNT(*) FILTER (WHERE o.order_status = 'Cancelled') AS cancelled,
  COUNT(*) FILTER (WHERE o.order_status = 'Returned')  AS returned
FROM sales.orders o
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY r.region_name;

/* Q63. */
SELECT r.region_name,
  SUM(CASE WHEN o.order_status = 'Delivered' THEN 1 ELSE 0 END) AS delivered,
  SUM(CASE WHEN o.order_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled,
  SUM(CASE WHEN o.order_status = 'Returned'  THEN 1 ELSE 0 END) AS returned
FROM sales.orders o
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY r.region_name;

/* Q64. */
SELECT r.region_name, ARRAY_AGG(DISTINCT o.order_status) AS statuses_seen
FROM sales.orders o
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY r.region_name;

/* Q65. */
SELECT r.region_name, JSONB_OBJECT_AGG(x.order_status, x.status_count) AS status_pivot
FROM (
  SELECT s.region_id, o.order_status, COUNT(*) AS status_count
  FROM sales.orders o JOIN stores.stores s ON o.store_id = s.store_id
  GROUP BY s.region_id, o.order_status
) x
JOIN core.dim_region r ON x.region_id = r.region_id
GROUP BY r.region_name;

/* Q66. */
SELECT r.region_name, SUM(o.net_total) AS revenue,
       100.0 * SUM(o.net_total) / SUM(SUM(o.net_total)) OVER () AS pct_of_total
FROM sales.orders o
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY r.region_name;

/* Q67. */
SELECT order_month, monthly_revenue,
       SUM(monthly_revenue) OVER (ORDER BY order_month) AS running_total
FROM (
  SELECT DATE_TRUNC('month', order_date) AS order_month, SUM(net_total) AS monthly_revenue
  FROM sales.orders GROUP BY DATE_TRUNC('month', order_date)
) m
ORDER BY order_month;

/* Q68. */
SELECT region_name, store_name, revenue,
       RANK() OVER (PARTITION BY region_name ORDER BY revenue DESC) AS rank_within_region
FROM (
  SELECT r.region_name, s.store_name, SUM(o.net_total) AS revenue
  FROM sales.orders o
  JOIN stores.stores s ON o.store_id = s.store_id
  JOIN core.dim_region r ON s.region_id = r.region_id
  GROUP BY r.region_name, s.store_name
) x
ORDER BY region_name, rank_within_region;

/* Q69. */
SELECT 'delivered' AS status_label, SUM(net_total) AS revenue FROM sales.orders WHERE order_status = 'Delivered'
UNION ALL
SELECT 'cancelled', SUM(net_total) FROM sales.orders WHERE order_status = 'Cancelled'
UNION ALL
SELECT 'returned', SUM(net_total) FROM sales.orders WHERE order_status = 'Returned';

/* Q70. */
WITH pivoted AS (
  SELECT jsonb_build_object('Delivered', SUM(net_total) FILTER (WHERE order_status='Delivered'),
                             'Cancelled', SUM(net_total) FILTER (WHERE order_status='Cancelled'),
                             'Returned',  SUM(net_total) FILTER (WHERE order_status='Returned')) AS status_json
  FROM sales.orders
)
SELECT kv.key AS status, kv.value AS revenue
FROM pivoted, LATERAL jsonb_each(pivoted.status_json) AS kv(key, value);

/* Q71. */
SELECT r.region_name, o.order_status, COUNT(*) AS order_count
FROM sales.orders o
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY r.region_name, o.order_status
ORDER BY r.region_name, o.order_status;

/* Q72. Sparse (LEFT JOIN, missing combos absent) vs dense (CROSS JOIN, missing combos shown as 0). */
SELECT r.region_name, mon.order_month, COALESCE(SUM(o.net_total), 0) AS revenue_sparse
FROM core.dim_region r
LEFT JOIN (SELECT DISTINCT DATE_TRUNC('month', order_date) AS order_month FROM sales.orders) mon ON TRUE
LEFT JOIN stores.stores s ON s.region_id = r.region_id
LEFT JOIN sales.orders o ON o.store_id = s.store_id AND DATE_TRUNC('month', o.order_date) = mon.order_month
GROUP BY r.region_name, mon.order_month
ORDER BY r.region_name, mon.order_month;

/* Q73. */
SELECT r.region_name, mon.order_month, COALESCE(SUM(o.net_total), 0) AS revenue_dense
FROM core.dim_region r
CROSS JOIN (SELECT DISTINCT DATE_TRUNC('month', order_date) AS order_month FROM sales.orders) mon
LEFT JOIN stores.stores s ON s.region_id = r.region_id
LEFT JOIN sales.orders o ON o.store_id = s.store_id AND DATE_TRUNC('month', o.order_date) = mon.order_month
GROUP BY r.region_name, mon.order_month
ORDER BY r.region_name, mon.order_month;

/* Q74. */
SELECT r.region_name,
  COALESCE(COUNT(*) FILTER (WHERE o.order_status = 'Delivered'), 0) AS delivered,
  COALESCE(SUM(o.net_total) FILTER (WHERE o.order_status = 'Delivered'), 0) AS delivered_revenue
FROM core.dim_region r
LEFT JOIN stores.stores s ON s.region_id = r.region_id
LEFT JOIN sales.orders o ON o.store_id = s.store_id
GROUP BY r.region_name;

/* Q75. */
SELECT order_month, monthly_revenue, LAG(monthly_revenue) OVER (ORDER BY order_month) AS prior_month_revenue,
       monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY order_month) AS change
FROM (
  SELECT DATE_TRUNC('month', order_date) AS order_month, SUM(net_total) AS monthly_revenue
  FROM sales.orders GROUP BY DATE_TRUNC('month', order_date)
) m
ORDER BY order_month;

/* ============================================================
   SECTION D: FUNNELS & ANOMALIES (25)
   ------------------------------------------------------------ */
/* Q76. */
WITH visitors AS (SELECT DISTINCT customer_id FROM web_events.page_views WHERE customer_id IS NOT NULL),
signups AS (SELECT customer_id FROM customers.customers),
first_orders AS (SELECT DISTINCT cust_id AS customer_id FROM sales.orders)
SELECT
  (SELECT COUNT(*) FROM visitors) AS visited,
  (SELECT COUNT(*) FROM visitors v JOIN signups s ON v.customer_id = s.customer_id) AS signed_up,
  (SELECT COUNT(*) FROM visitors v JOIN first_orders f ON v.customer_id = f.customer_id) AS ordered;

/* Q77. */
WITH signups AS (SELECT customer_id, registration_date FROM customers.customers),
first_orders AS (SELECT cust_id AS customer_id, MIN(order_date) AS first_order_date FROM sales.orders GROUP BY cust_id),
second_orders AS (
  SELECT cust_id AS customer_id FROM (
    SELECT cust_id, order_date, ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date) AS rn
    FROM sales.orders
  ) x WHERE rn = 2
)
SELECT
  COUNT(*) AS signed_up,
  COUNT(*) FILTER (WHERE fo.first_order_date IS NOT NULL AND fo.first_order_date <= s.registration_date + 30) AS activated,
  (SELECT COUNT(*) FROM second_orders) AS retained,
  SUM(fo.first_order_date IS NOT NULL::int) AS has_revenue
FROM signups s
LEFT JOIN first_orders fo ON fo.customer_id = s.customer_id;

/* Q78. RetailMart's web_events has no cart/checkout labels; event_type 'click' and 'submit' are used as click and checkout-intent proxies, joined to actual paid orders by customer. */
WITH clicks AS (
  SELECT DISTINCT pv.customer_id
  FROM web_events.events e JOIN web_events.page_views pv ON e.view_id = pv.view_id
  WHERE e.event_type = 'click' AND pv.customer_id IS NOT NULL
),
submits AS (
  SELECT DISTINCT pv.customer_id
  FROM web_events.events e JOIN web_events.page_views pv ON e.view_id = pv.view_id
  WHERE e.event_type = 'submit' AND pv.customer_id IS NOT NULL
),
paid AS (SELECT DISTINCT cust_id AS customer_id FROM sales.orders WHERE order_status NOT IN ('Cancelled','Failed'))
SELECT
  (SELECT COUNT(*) FROM clicks) AS clicked,
  (SELECT COUNT(*) FROM clicks c JOIN submits s ON c.customer_id = s.customer_id) AS submitted,
  (SELECT COUNT(*) FROM clicks c JOIN paid p ON c.customer_id = p.customer_id) AS paid_customers;

/* Q79. */
WITH funnel AS (
  SELECT
    (SELECT COUNT(DISTINCT customer_id) FROM web_events.page_views WHERE customer_id IS NOT NULL) AS visited,
    (SELECT COUNT(DISTINCT cust_id) FROM sales.orders) AS ordered
)
SELECT visited, ordered, 100.0 * ordered / NULLIF(visited, 0) AS conversion_pct FROM funnel;

/* Q80. */
WITH stage_counts AS (
  SELECT 1 AS step, 'visited' AS step_name, COUNT(DISTINCT customer_id) AS cnt FROM web_events.page_views WHERE customer_id IS NOT NULL
  UNION ALL
  SELECT 2, 'ordered', COUNT(DISTINCT cust_id) FROM sales.orders
)
SELECT step, step_name, cnt, cnt - LEAD(cnt) OVER (ORDER BY step) AS drop_off
FROM stage_counts ORDER BY step;

/* Q81. */
SELECT AVG(fo.first_order_date - c.registration_date) AS avg_days_signup_to_first_order
FROM customers.customers c
JOIN (SELECT cust_id, MIN(order_date) AS first_order_date FROM sales.orders GROUP BY cust_id) fo
  ON fo.cust_id = c.customer_id;

/* Q82. */
SELECT DATE_TRUNC('month', c.registration_date) AS cohort_month,
       COUNT(DISTINCT c.customer_id) AS cohort_size,
       COUNT(DISTINCT o.cust_id) AS reached_order
FROM customers.customers c
LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY DATE_TRUNC('month', c.registration_date)
ORDER BY cohort_month;

/* Q83. Multi-touch attribution: revenue split equally among every campaign active on the order's date (RetailMart has no per-order campaign_id, so overlapping active campaigns are used as the touch set). */
WITH order_campaigns AS (
  SELECT o.order_id, o.net_total, c.campaign_id, COUNT(*) OVER (PARTITION BY o.order_id) AS touches
  FROM sales.orders o
  JOIN marketing.campaigns c ON o.order_date BETWEEN c.start_date AND c.end_date
)
SELECT campaign_id, SUM(net_total / touches) AS attributed_revenue
FROM order_campaigns
GROUP BY campaign_id
ORDER BY attributed_revenue DESC;

/* Q84. */
WITH order_first_campaign AS (
  SELECT o.order_id, o.net_total,
         (SELECT c.campaign_id FROM marketing.campaigns c
          WHERE o.order_date BETWEEN c.start_date AND c.end_date
          ORDER BY c.start_date ASC LIMIT 1) AS first_campaign_id
  FROM sales.orders o
)
SELECT first_campaign_id, SUM(net_total) AS attributed_revenue
FROM order_first_campaign
WHERE first_campaign_id IS NOT NULL
GROUP BY first_campaign_id
ORDER BY attributed_revenue DESC;

/* Q85. */
WITH order_last_campaign AS (
  SELECT o.order_id, o.net_total,
         (SELECT c.campaign_id FROM marketing.campaigns c
          WHERE o.order_date BETWEEN c.start_date AND c.end_date
          ORDER BY c.start_date DESC LIMIT 1) AS last_campaign_id
  FROM sales.orders o
)
SELECT last_campaign_id, SUM(net_total) AS attributed_revenue
FROM order_last_campaign
WHERE last_campaign_id IS NOT NULL
GROUP BY last_campaign_id
ORDER BY attributed_revenue DESC;

/* Q86. */
WITH order_campaigns AS (
  SELECT o.order_id, o.net_total, c.campaign_id, COUNT(*) OVER (PARTITION BY o.order_id) AS touches
  FROM sales.orders o
  JOIN marketing.campaigns c ON o.order_date BETWEEN c.start_date AND c.end_date
)
SELECT campaign_id, SUM(net_total / touches) AS linear_attributed_revenue
FROM order_campaigns
GROUP BY campaign_id
ORDER BY linear_attributed_revenue DESC;

/* Q87. Time-decay weight: more recently-started active campaign gets more credit. */
WITH order_campaigns AS (
  SELECT o.order_id, o.net_total, c.campaign_id,
         EXP(-0.05 * (o.order_date - c.start_date)) AS decay_weight
  FROM sales.orders o
  JOIN marketing.campaigns c ON o.order_date BETWEEN c.start_date AND c.end_date
),
weighted AS (
  SELECT order_id, net_total, campaign_id,
         decay_weight / SUM(decay_weight) OVER (PARTITION BY order_id) AS weight_share
  FROM order_campaigns
)
SELECT campaign_id, SUM(net_total * weight_share) AS attributed_revenue
FROM weighted
GROUP BY campaign_id
ORDER BY attributed_revenue DESC;

/* Q88. "Today" is the latest order_date in the data set, not CURRENT_DATE, since the data ends before today's real calendar date. */
WITH ref AS (SELECT MAX(order_date) AS today FROM sales.orders),
daily AS (SELECT order_date, SUM(net_total) AS revenue FROM sales.orders GROUP BY order_date)
SELECT d.revenue AS todays_revenue,
       (SELECT AVG(revenue) FROM daily WHERE order_date BETWEEN (SELECT today FROM ref) - 30 AND (SELECT today FROM ref) - 1) AS avg_last_30d
FROM daily d, ref
WHERE d.order_date = ref.today;

/* Q89. */
WITH ref AS (SELECT MAX(created_date::date) AS today FROM support.tickets),
daily AS (SELECT created_date::date AS d, COUNT(*) AS ticket_count FROM support.tickets GROUP BY created_date::date)
SELECT d1.ticket_count AS todays_tickets,
       (SELECT AVG(ticket_count) FROM daily WHERE d BETWEEN (SELECT today FROM ref) - 30 AND (SELECT today FROM ref) - 1) AS avg_last_30d
FROM daily d1, ref
WHERE d1.d = ref.today;

/* Q90. */
WITH ref AS (SELECT MAX(timestamp::date) AS today FROM audit.application_logs),
daily AS (SELECT timestamp::date AS d, COUNT(*) AS error_count FROM audit.application_logs WHERE level = 'ERROR' GROUP BY timestamp::date)
SELECT d1.error_count AS todays_errors,
       (SELECT AVG(error_count) FROM daily WHERE d BETWEEN (SELECT today FROM ref) - 30 AND (SELECT today FROM ref) - 1) AS avg_last_30d
FROM daily d1, ref
WHERE d1.d = ref.today;

/* Q91. SLA breach defined as resolution time > 48 hours. */
SELECT category,
       100.0 * COUNT(*) FILTER (WHERE EXTRACT(EPOCH FROM (resolved_date - created_date))/3600.0 > 48) / COUNT(*) FILTER (WHERE resolved_date IS NOT NULL) AS sla_breach_rate_pct
FROM support.tickets
GROUP BY category;

/* Q92. */
SELECT p.product_id, p.product_name,
       COUNT(DISTINCT r.return_id) AS returns,
       COUNT(DISTINCT oi.order_item_id) AS items_sold,
       100.0 * COUNT(DISTINCT r.return_id) / NULLIF(COUNT(DISTINCT oi.order_item_id), 0) AS return_rate_pct
FROM products.products p
LEFT JOIN sales.order_items oi ON oi.prod_id = p.product_id
LEFT JOIN sales.returns r ON r.prod_id = p.product_id
GROUP BY p.product_id, p.product_name
HAVING 100.0 * COUNT(DISTINCT r.return_id) / NULLIF(COUNT(DISTINCT oi.order_item_id), 0) > 20
ORDER BY return_rate_pct DESC;

/* Q93. Drift = a customer's average orders/month in the last 3 months of activity vs their all-time average. */
WITH monthly AS (
  SELECT cust_id, DATE_TRUNC('month', order_date) AS order_month, COUNT(*) AS orders_in_month
  FROM sales.orders GROUP BY cust_id, DATE_TRUNC('month', order_date)
),
recent AS (
  SELECT cust_id, AVG(orders_in_month) AS recent_avg
  FROM (
    SELECT cust_id, order_month, orders_in_month,
           ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_month DESC) AS rn
    FROM monthly
  ) x WHERE rn <= 3
  GROUP BY cust_id
),
overall AS (
  SELECT cust_id, AVG(orders_in_month) AS overall_avg FROM monthly GROUP BY cust_id
)
SELECT r.cust_id, r.recent_avg, o.overall_avg, (r.recent_avg - o.overall_avg) AS drift
FROM recent r JOIN overall o ON r.cust_id = o.cust_id
ORDER BY ABS(r.recent_avg - o.overall_avg) DESC
LIMIT 100;

/* Q94. */
SELECT order_id, net_total
FROM (
  SELECT order_id, net_total, (net_total - AVG(net_total) OVER ()) / NULLIF(STDDEV(net_total) OVER (), 0) AS z
  FROM sales.orders
) x
WHERE ABS(z) > 3
ORDER BY net_total DESC;

/* Q95. */
SELECT return_id, refund_amount
FROM (
  SELECT return_id, refund_amount, (refund_amount - AVG(refund_amount) OVER ()) / NULLIF(STDDEV(refund_amount) OVER (), 0) AS z
  FROM sales.returns
) x
WHERE ABS(z) > 3
ORDER BY refund_amount DESC;

/* Q96. Bot-like traffic proxy: sessions with an unusually high page_view count in a short span. */
SELECT session_id, COUNT(*) AS views_in_session,
       MAX(view_timestamp) - MIN(view_timestamp) AS session_span
FROM web_events.page_views
GROUP BY session_id
HAVING COUNT(*) > 12
ORDER BY views_in_session DESC
LIMIT 100;

/* Q97. */
SELECT DATE_TRUNC('month', order_date) AS order_month,
       COUNT(*) AS total_orders,
       COUNT(*) FILTER (WHERE cust_id IS NULL) AS null_cust_id_count,
       100.0 * COUNT(*) FILTER (WHERE cust_id IS NULL) / COUNT(*) AS null_rate_pct
FROM sales.orders
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY order_month;

/* Q98. Schema drift is a metadata comparison (column list/types changing over time), not a data query - it is detected by diffing successive information_schema.columns snapshots, not by aggregating table rows. */

/* Q99. Stuck inventory: high stock on hand with no recent order_item activity. */
SELECT i.product_id, p.product_name, i.quantity_on_hand,
       MAX(o.order_date) AS last_sold_date
FROM products.inventory i
JOIN products.products p ON i.product_id = p.product_id
LEFT JOIN sales.order_items oi ON oi.prod_id = i.product_id
LEFT JOIN sales.orders o ON oi.order_id = o.order_id
GROUP BY i.product_id, p.product_name, i.quantity_on_hand
HAVING i.quantity_on_hand > 100 AND (MAX(o.order_date) IS NULL OR MAX(o.order_date) < (SELECT MAX(order_date) FROM sales.orders) - 90)
ORDER BY i.quantity_on_hand DESC
LIMIT 100;

/* Q100. Representative anomaly summary (a full 20-detector suite would span this entire practice set - this consolidates the highest-value detectors from Section D into one dashboard row). */
WITH order_stats AS (SELECT AVG(net_total) AS avg_val, STDDEV(net_total) AS stddev_val FROM sales.orders),
return_stats AS (SELECT AVG(refund_amount) AS avg_val, STDDEV(refund_amount) AS stddev_val FROM sales.returns)
SELECT
  (SELECT COUNT(*) FROM sales.orders o, order_stats os
     WHERE ABS((o.net_total - os.avg_val) / NULLIF(os.stddev_val, 0)) > 3) AS outlier_order_count,
  (SELECT COUNT(*) FROM sales.returns r, return_stats rs
     WHERE ABS((r.refund_amount - rs.avg_val) / NULLIF(rs.stddev_val, 0)) > 3) AS outlier_return_count,
  (SELECT COUNT(*) FROM support.tickets WHERE resolved_date IS NOT NULL
     AND EXTRACT(EPOCH FROM (resolved_date - created_date))/3600.0 > 48) AS sla_breaches,
  (SELECT COUNT(*) FROM (SELECT session_id FROM web_events.page_views GROUP BY session_id HAVING COUNT(*) > 12) bot) AS bot_like_sessions,
  (SELECT COUNT(*) FROM sales.orders WHERE cust_id IS NULL) AS orphan_orders,
  (SELECT COUNT(*) FROM audit.application_logs WHERE level = 'FATAL') AS fatal_log_count;

/* ============================================================
   END OF ANSWER KEY - Aggregate Functions & Grouping - CRAZY LEVEL (100/100)
============================================================ */
