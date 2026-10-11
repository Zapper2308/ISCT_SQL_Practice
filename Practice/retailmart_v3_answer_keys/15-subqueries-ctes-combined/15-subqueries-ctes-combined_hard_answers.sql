/* ============================================================
   ANSWER KEY - Subqueries + CTEs Combined (HARD LEVEL)
   Curriculum:   RetailMart V3
   Note: RetailMart V3 has NO self-referencing hierarchy columns
   anywhere (no employee.manager_id, no category.parent_id, no BOM,
   no accounts/permissions/referral/subscription tables). Where a
   question asks about a structure that genuinely does not exist in
   this schema, the answer below is a short conceptual note instead
   of an invented query, per the assignment's instructions.
   ============================================================ */

/* SECTION A: HIERARCHICAL REPORTS (25) */

/* Q1. */
WITH RECURSIVE hierarchy AS (
  SELECT 'cat_' || category_id::text AS node_id, NULL::text AS parent_id, category_name::text AS node_name, 0 AS lvl
  FROM core.dim_category
  UNION ALL
  SELECT 'brand_' || b.brand_id::text, 'cat_' || b.category_id::text, b.brand_name::text, h.lvl + 1
  FROM core.dim_brand b
  JOIN hierarchy h ON h.node_id = 'cat_' || b.category_id::text
),
brand_revenue AS (
  SELECT p.brand_id, SUM(oi.net_amount) AS revenue
  FROM sales.order_items oi
  JOIN products.products p ON p.product_id = oi.prod_id
  GROUP BY p.brand_id
)
SELECT h.node_id, h.parent_id, h.node_name, h.lvl, COALESCE(br.revenue, 0) AS revenue
FROM hierarchy h
LEFT JOIN brand_revenue br ON h.node_id = 'brand_' || br.brand_id::text
ORDER BY h.lvl, h.node_id
LIMIT 50;

/* Q2. */
SELECT r.region_id, r.region_name, COUNT(DISTINCT s.store_id) AS stores,
       ROUND(SUM(o.net_total), 2) AS region_revenue
FROM core.dim_region r
LEFT JOIN stores.stores s ON s.region_id = r.region_id
LEFT JOIN sales.orders o ON o.store_id = s.store_id AND o.order_status NOT IN ('Cancelled', 'Failed')
GROUP BY r.region_id, r.region_name
ORDER BY region_revenue DESC NULLS LAST;

/* Q3. RetailMart's stores.employees table has no manager_id (no self-referencing foreign key), so there is no org hierarchy to recurse over; if it existed, a RECURSIVE CTE anchored on employees with manager_id IS NULL and joined recursively on manager_id would roll up headcount/salary by level. */

/* Q4. There is no account-hierarchy table in RetailMart - finance.accounts is a flat list (account_id, account_holder, account_type, balance) with no parent_account_id; an account hierarchy would need a self-referencing FK added before a RECURSIVE CTE could traverse it. */

/* Q5. RetailMart has no bill-of-materials table - manufacture.work_orders records finished-goods production runs (product_id, line_id, quantities) but not a components/sub-assemblies breakdown, so there is no cost structure to recursively roll up. */

/* Q6. RetailMart has no folder/file table at all, so there is nothing to compute a folder-size rollup over. */

/* Q7. RetailMart has no comments/threads table, so there is no comment-thread structure to roll up. */

/* Q8. RetailMart has no approval-workflow table, so there is no approval chain to model or roll up. */

/* Q9. */
SELECT e.employee_id, e.first_name, e.last_name, e.salary, tb.tax_rate,
       ROUND(e.salary * tb.tax_rate, 2) AS approx_tax
FROM stores.employees e
JOIN payroll.tax_brackets tb ON e.salary BETWEEN tb.min_salary AND tb.max_salary
ORDER BY e.salary DESC
LIMIT 30;

/* Q10. */
SELECT a.promo_id AS promo_a, a.promo_name AS name_a, a.discount_percent AS discount_a,
       b.promo_id AS promo_b, b.promo_name AS name_b, b.discount_percent AS discount_b,
       a.discount_percent + b.discount_percent AS stacked_discount_pct
FROM products.promotions a
JOIN products.promotions b ON b.promo_id > a.promo_id
  AND a.start_date <= b.end_date AND b.start_date <= a.end_date
WHERE a.active = true AND b.active = true
ORDER BY stacked_discount_pct DESC
LIMIT 20;

/* Q11. RetailMart's loyalty schema (loyalty.members, loyalty.redemptions) has no referrer_id or referred_by column, so there is no referral relationship to trace between members. */

/* Q12. RetailMart has no affiliates table or affiliate_id linkage anywhere in the schema, so there is no affiliate chain to query. */

/* Q13. */
SELECT r.region_name, s.store_name, COUNT(o.order_id) AS orders, ROUND(SUM(o.net_total), 2) AS revenue
FROM core.dim_region r
JOIN stores.stores s ON s.region_id = r.region_id
LEFT JOIN sales.orders o ON o.store_id = s.store_id AND o.order_status NOT IN ('Cancelled', 'Failed')
GROUP BY r.region_name, s.store_name
ORDER BY r.region_name, revenue DESC NULLS LAST;

/* Q14. RetailMart has no distributor or reseller table - products flow supplier -> products -> store inventory directly, with no multi-tier distribution network to model recursively. */

/* Q15. RetailMart has no refer-a-friend column or table (no referring_customer_id), so there is no refer-a-friend chain to query. */

/* Q16. RetailMart has no roles/permissions tables at all (it is an analytics teaching schema, not an application's auth system), so there is no permission-inheritance structure to model. */

/* Q17. */
SELECT r.country, r.state, a.city, COUNT(DISTINCT a.customer_id) AS customers,
       ROUND(SUM(o.net_total), 2) AS revenue
FROM customers.addresses a
JOIN core.dim_region r ON r.state = a.state
LEFT JOIN sales.orders o ON o.cust_id = a.customer_id AND o.order_status NOT IN ('Cancelled', 'Failed')
WHERE a.is_default = true
GROUP BY r.country, r.state, a.city
ORDER BY r.country, r.state, revenue DESC NULLS LAST
LIMIT 30;

/* Q18. */
SELECT cat.category_name, b.brand_name, COUNT(p.product_id) AS product_count,
       ROUND(SUM(oi.net_amount), 2) AS revenue
FROM core.dim_category cat
JOIN core.dim_brand b ON b.category_id = cat.category_id
LEFT JOIN products.products p ON p.brand_id = b.brand_id
LEFT JOIN sales.order_items oi ON oi.prod_id = p.product_id
GROUP BY cat.category_name, b.brand_name
ORDER BY cat.category_name, revenue DESC NULLS LAST
LIMIT 30;

/* Q19. */
SELECT b.brand_id, b.brand_name, COUNT(p.product_id) AS family_size,
       ROUND(SUM(oi.net_amount), 2) AS family_revenue
FROM core.dim_brand b
JOIN products.products p ON p.brand_id = b.brand_id
LEFT JOIN sales.order_items oi ON oi.prod_id = p.product_id
GROUP BY b.brand_id, b.brand_name
ORDER BY family_revenue DESC NULLS LAST
LIMIT 20;

/* Q20. */
SELECT w.warehouse_id, w.name AS warehouse_name, sup.supplier_name,
       COUNT(sh.shipment_id) AS shipments, SUM(sh.quantity) AS total_quantity
FROM supply_chain.warehouses w
JOIN supply_chain.shipments sh ON sh.warehouse_id = w.warehouse_id
JOIN products.suppliers sup ON sup.supplier_id = sh.supplier_id
GROUP BY w.warehouse_id, w.name, sup.supplier_name
ORDER BY total_quantity DESC
LIMIT 20;

/* Q21. RetailMart's customers.customers table has no referred_by_customer_id column, so there is no customer referral tree to traverse. */

/* Q22. */
SELECT camp.campaign_id, camp.campaign_name, camp.budget,
       COALESCE(SUM(a.amount), 0) AS total_spend,
       COALESCE(SUM(ec.emails_clicked), 0) AS total_clicks
FROM marketing.campaigns camp
LEFT JOIN marketing.ads_spend a ON a.campaign_id = camp.campaign_id
LEFT JOIN marketing.email_clicks ec ON ec.campaign_id = camp.campaign_id
GROUP BY camp.campaign_id, camp.campaign_name, camp.budget
ORDER BY total_spend DESC
LIMIT 20;

/* Q23. */
SELECT a.promo_id, a.promo_name, a.discount_percent, a.start_date, a.end_date,
       COUNT(b.promo_id) AS overlapping_active_promos
FROM products.promotions a
LEFT JOIN products.promotions b ON b.promo_id <> a.promo_id AND b.active = true
  AND a.start_date <= b.end_date AND b.start_date <= a.end_date
WHERE a.active = true
GROUP BY a.promo_id, a.promo_name, a.discount_percent, a.start_date, a.end_date
ORDER BY overlapping_active_promos DESC
LIMIT 20;

/* Q24. RetailMart has no subscription table or product/plan hierarchy - it models one-off retail orders, not recurring subscriptions, so there is no subscription tree to build. */

/* Q25. */
SELECT r.region_name, s.store_name,
       ROUND(SUM(o.net_total), 2) AS store_revenue,
       ROUND(SUM(SUM(o.net_total)) OVER (PARTITION BY r.region_name), 2) AS region_revenue,
       ROUND(SUM(SUM(o.net_total)) OVER (), 2) AS company_revenue
FROM core.dim_region r
JOIN stores.stores s ON s.region_id = r.region_id
JOIN sales.orders o ON o.store_id = s.store_id AND o.order_status NOT IN ('Cancelled', 'Failed')
GROUP BY r.region_name, s.store_name
ORDER BY r.region_name, store_revenue DESC;

/* SECTION B: FUNNEL + ATTRIBUTION (25) */

/* Q26. */
WITH date_campaign AS (
  SELECT dd.date_key,
         (SELECT c.campaign_id FROM marketing.campaigns c WHERE dd.date_key BETWEEN c.start_date AND c.end_date ORDER BY c.start_date LIMIT 1) AS campaign_id
  FROM core.dim_date dd
),
touches AS (
  SELECT pv.customer_id, dc.campaign_id, COUNT(*) AS touch_count
  FROM web_events.page_views pv
  JOIN date_campaign dc ON dc.date_key = pv.view_timestamp::date
  WHERE pv.customer_id IS NOT NULL AND dc.campaign_id IS NOT NULL
  GROUP BY pv.customer_id, dc.campaign_id
),
touches_per_cust AS (SELECT customer_id, SUM(touch_count) AS total_touches FROM touches GROUP BY customer_id),
cust_revenue AS (SELECT cust_id, SUM(net_total) AS revenue FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed') GROUP BY cust_id)
SELECT t.campaign_id, ROUND(SUM(r.revenue * t.touch_count / tc.total_touches), 2) AS attributed_revenue
FROM touches t
JOIN touches_per_cust tc ON tc.customer_id = t.customer_id
JOIN cust_revenue r ON r.cust_id = t.customer_id
GROUP BY t.campaign_id
ORDER BY attributed_revenue DESC;

/* Q27. */
WITH date_campaign AS (
  SELECT dd.date_key,
         (SELECT c.campaign_id FROM marketing.campaigns c WHERE dd.date_key BETWEEN c.start_date AND c.end_date ORDER BY c.start_date LIMIT 1) AS campaign_id
  FROM core.dim_date dd
),
first_touch AS (
  SELECT DISTINCT ON (pv.customer_id) pv.customer_id, dc.campaign_id
  FROM web_events.page_views pv
  JOIN date_campaign dc ON dc.date_key = pv.view_timestamp::date
  WHERE pv.customer_id IS NOT NULL AND dc.campaign_id IS NOT NULL
  ORDER BY pv.customer_id, pv.view_timestamp ASC
),
cust_revenue AS (SELECT cust_id, SUM(net_total) AS revenue FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed') GROUP BY cust_id)
SELECT f.campaign_id, ROUND(SUM(r.revenue), 2) AS attributed_revenue
FROM first_touch f
JOIN cust_revenue r ON r.cust_id = f.customer_id
GROUP BY f.campaign_id
ORDER BY attributed_revenue DESC;

/* Q28. */
WITH date_campaign AS (
  SELECT dd.date_key,
         (SELECT c.campaign_id FROM marketing.campaigns c WHERE dd.date_key BETWEEN c.start_date AND c.end_date ORDER BY c.start_date LIMIT 1) AS campaign_id
  FROM core.dim_date dd
),
last_touch AS (
  SELECT DISTINCT ON (pv.customer_id) pv.customer_id, dc.campaign_id
  FROM web_events.page_views pv
  JOIN date_campaign dc ON dc.date_key = pv.view_timestamp::date
  WHERE pv.customer_id IS NOT NULL AND dc.campaign_id IS NOT NULL
  ORDER BY pv.customer_id, pv.view_timestamp DESC
),
cust_revenue AS (SELECT cust_id, SUM(net_total) AS revenue FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed') GROUP BY cust_id)
SELECT l.campaign_id, ROUND(SUM(r.revenue), 2) AS attributed_revenue
FROM last_touch l
JOIN cust_revenue r ON r.cust_id = l.customer_id
GROUP BY l.campaign_id
ORDER BY attributed_revenue DESC;

/* Q29. */
WITH date_campaign AS (
  SELECT dd.date_key,
         (SELECT c.campaign_id FROM marketing.campaigns c WHERE dd.date_key BETWEEN c.start_date AND c.end_date ORDER BY c.start_date LIMIT 1) AS campaign_id
  FROM core.dim_date dd
),
touches AS (
  SELECT pv.customer_id, dc.campaign_id, COUNT(*) AS touch_count
  FROM web_events.page_views pv
  JOIN date_campaign dc ON dc.date_key = pv.view_timestamp::date
  WHERE pv.customer_id IS NOT NULL AND dc.campaign_id IS NOT NULL
  GROUP BY pv.customer_id, dc.campaign_id
),
touches_per_cust AS (SELECT customer_id, SUM(touch_count) AS total_touches FROM touches GROUP BY customer_id),
cust_revenue AS (SELECT cust_id, SUM(net_total) AS revenue FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed') GROUP BY cust_id)
SELECT t.campaign_id, ROUND(SUM(r.revenue * t.touch_count / tc.total_touches), 2) AS linear_attributed_revenue
FROM touches t
JOIN touches_per_cust tc ON tc.customer_id = t.customer_id
JOIN cust_revenue r ON r.cust_id = t.customer_id
GROUP BY t.campaign_id
ORDER BY linear_attributed_revenue DESC;

/* Q30. */
WITH date_campaign AS (
  SELECT dd.date_key,
         (SELECT c.campaign_id FROM marketing.campaigns c WHERE dd.date_key BETWEEN c.start_date AND c.end_date ORDER BY c.start_date LIMIT 1) AS campaign_id
  FROM core.dim_date dd
),
ranked AS (
  SELECT pv.customer_id, dc.campaign_id, pv.view_timestamp,
         ROW_NUMBER() OVER (PARTITION BY pv.customer_id ORDER BY pv.view_timestamp DESC) AS recency_rank
  FROM web_events.page_views pv
  JOIN date_campaign dc ON dc.date_key = pv.view_timestamp::date
  WHERE pv.customer_id IS NOT NULL AND dc.campaign_id IS NOT NULL
),
weighted AS (SELECT customer_id, campaign_id, POWER(0.5, recency_rank - 1) AS weight FROM ranked),
weight_totals AS (SELECT customer_id, SUM(weight) AS total_weight FROM weighted GROUP BY customer_id),
cust_revenue AS (SELECT cust_id, SUM(net_total) AS revenue FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed') GROUP BY cust_id)
SELECT w.campaign_id, ROUND(SUM(r.revenue * w.weight / wt.total_weight), 2) AS time_decay_attributed_revenue
FROM weighted w
JOIN weight_totals wt ON wt.customer_id = w.customer_id
JOIN cust_revenue r ON r.cust_id = w.customer_id
GROUP BY w.campaign_id
ORDER BY time_decay_attributed_revenue DESC;

/* Q31. */
WITH date_campaign AS (
  SELECT dd.date_key,
         (SELECT c.campaign_id FROM marketing.campaigns c WHERE dd.date_key BETWEEN c.start_date AND c.end_date ORDER BY c.start_date LIMIT 1) AS campaign_id
  FROM core.dim_date dd
),
positions AS (
  SELECT pv.customer_id, dc.campaign_id,
         ROW_NUMBER() OVER (PARTITION BY pv.customer_id ORDER BY pv.view_timestamp) AS rn,
         COUNT(*) OVER (PARTITION BY pv.customer_id) AS total_touches
  FROM web_events.page_views pv
  JOIN date_campaign dc ON dc.date_key = pv.view_timestamp::date
  WHERE pv.customer_id IS NOT NULL AND dc.campaign_id IS NOT NULL
),
weighted AS (
  SELECT customer_id, campaign_id,
         CASE WHEN total_touches = 1 THEN 1.0
              WHEN rn = 1 THEN 0.4 WHEN rn = total_touches THEN 0.4
              ELSE 0.2 / NULLIF(total_touches - 2, 0) END AS weight
  FROM positions
),
cust_revenue AS (SELECT cust_id, SUM(net_total) AS revenue FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed') GROUP BY cust_id)
SELECT w.campaign_id, ROUND(SUM(r.revenue * w.weight), 2) AS position_attributed_revenue
FROM weighted w
JOIN cust_revenue r ON r.cust_id = w.customer_id
GROUP BY w.campaign_id
ORDER BY position_attributed_revenue DESC;

/* Q32. */
WITH date_campaign AS (
  SELECT dd.date_key,
         (SELECT c.campaign_id FROM marketing.campaigns c WHERE dd.date_key BETWEEN c.start_date AND c.end_date ORDER BY c.start_date LIMIT 1) AS campaign_id
  FROM core.dim_date dd
),
first_touch AS (
  SELECT DISTINCT ON (pv.customer_id) pv.customer_id, dc.campaign_id
  FROM web_events.page_views pv JOIN date_campaign dc ON dc.date_key = pv.view_timestamp::date
  WHERE pv.customer_id IS NOT NULL AND dc.campaign_id IS NOT NULL ORDER BY pv.customer_id, pv.view_timestamp ASC
),
last_touch AS (
  SELECT DISTINCT ON (pv.customer_id) pv.customer_id, dc.campaign_id
  FROM web_events.page_views pv JOIN date_campaign dc ON dc.date_key = pv.view_timestamp::date
  WHERE pv.customer_id IS NOT NULL AND dc.campaign_id IS NOT NULL ORDER BY pv.customer_id, pv.view_timestamp DESC
),
cust_revenue AS (SELECT cust_id, SUM(net_total) AS revenue FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed') GROUP BY cust_id),
ft_rev AS (SELECT f.campaign_id, SUM(r.revenue) AS ft_revenue FROM first_touch f JOIN cust_revenue r ON r.cust_id = f.customer_id GROUP BY f.campaign_id),
lt_rev AS (SELECT l.campaign_id, SUM(r.revenue) AS lt_revenue FROM last_touch l JOIN cust_revenue r ON r.cust_id = l.customer_id GROUP BY l.campaign_id)
SELECT COALESCE(ft.campaign_id, lt.campaign_id) AS campaign_id,
       ROUND(COALESCE(ft.ft_revenue, 0), 2) AS first_touch_revenue,
       ROUND(COALESCE(lt.lt_revenue, 0), 2) AS last_touch_revenue
FROM ft_rev ft
FULL OUTER JOIN lt_rev lt ON lt.campaign_id = ft.campaign_id
ORDER BY first_touch_revenue DESC NULLS LAST;

/* Q33. */
SELECT a.platform AS source, SUM(a.amount) AS spend
FROM marketing.ads_spend a
GROUP BY a.platform
ORDER BY spend DESC;

/* Q34. */
SELECT device_type AS medium, COUNT(*) AS page_views, COUNT(DISTINCT customer_id) FILTER (WHERE customer_id IS NOT NULL) AS unique_customers
FROM web_events.page_views
GROUP BY device_type
ORDER BY page_views DESC;

/* Q35. */
SELECT c.campaign_id, c.campaign_name, COUNT(o.order_id) AS orders, ROUND(SUM(o.net_total), 2) AS revenue
FROM marketing.campaigns c
LEFT JOIN sales.orders o ON o.order_date BETWEEN c.start_date AND c.end_date AND o.order_status NOT IN ('Cancelled', 'Failed')
GROUP BY c.campaign_id, c.campaign_name
ORDER BY revenue DESC NULLS LAST
LIMIT 20;

/* Q36. */
SELECT rg.region_name, COUNT(DISTINCT o.order_id) AS orders, ROUND(SUM(o.net_total), 2) AS revenue
FROM sales.orders o
JOIN customers.addresses a ON a.customer_id = o.cust_id AND a.is_default = true
JOIN core.dim_region rg ON rg.state = a.state
WHERE o.order_status NOT IN ('Cancelled', 'Failed')
GROUP BY rg.region_name
ORDER BY revenue DESC;

/* Q37. */
WITH device_visits AS (
  SELECT customer_id, MODE() WITHIN GROUP (ORDER BY device_type) AS device
  FROM web_events.page_views WHERE customer_id IS NOT NULL GROUP BY customer_id
)
SELECT dv.device, COUNT(DISTINCT o.order_id) AS orders, ROUND(SUM(o.net_total), 2) AS revenue
FROM device_visits dv
JOIN sales.orders o ON o.cust_id = dv.customer_id AND o.order_status NOT IN ('Cancelled', 'Failed')
GROUP BY dv.device
ORDER BY revenue DESC;

/* Q38. */
SELECT c.tier, COUNT(o.order_id) AS orders, ROUND(SUM(o.net_total), 2) AS revenue
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id AND o.order_status NOT IN ('Cancelled', 'Failed')
GROUP BY c.tier
ORDER BY revenue DESC;

/* Q39. */
WITH first_visit AS (SELECT customer_id, MIN(view_timestamp) AS first_view FROM web_events.page_views WHERE customer_id IS NOT NULL GROUP BY customer_id),
first_order AS (SELECT cust_id, MIN(order_date) AS first_order_date FROM sales.orders GROUP BY cust_id)
SELECT ROUND(AVG(fo.first_order_date - fv.first_view::date), 2) AS avg_days_to_conversion
FROM first_visit fv
JOIN first_order fo ON fo.cust_id = fv.customer_id;

/* Q40. */
WITH steps AS (
  SELECT (SELECT COUNT(DISTINCT customer_id) FROM web_events.page_views WHERE customer_id IS NOT NULL) AS visitors,
         (SELECT COUNT(DISTINCT cust_id) FROM sales.orders) AS buyers
)
SELECT visitors, buyers, ROUND(100.0 * (visitors - buyers) / NULLIF(visitors, 0), 2) AS dropoff_rate_pct
FROM steps;

/* Q41. */
WITH steps AS (
  SELECT
    (SELECT COUNT(DISTINCT session_id) FROM web_events.page_views) AS visits,
    (SELECT COUNT(*) FROM sales.orders) AS orders,
    (SELECT COUNT(*) FROM sales.payments) AS payments,
    (SELECT COUNT(*) FROM sales.orders WHERE order_status = 'Delivered') AS delivered
),
drops AS (
  SELECT 'visit_to_order' AS step, ROUND(100.0 * (visits - orders) / NULLIF(visits, 0), 2) AS dropoff_pct FROM steps
  UNION ALL SELECT 'order_to_payment', ROUND(100.0 * (orders - payments) / NULLIF(orders, 0), 2) FROM steps
  UNION ALL SELECT 'payment_to_delivered', ROUND(100.0 * (payments - delivered) / NULLIF(payments, 0), 2) FROM steps
)
SELECT step, dropoff_pct FROM drops ORDER BY dropoff_pct DESC LIMIT 1;

/* Q42. */
WITH spend AS (SELECT campaign_id, SUM(amount) AS spend FROM marketing.ads_spend GROUP BY campaign_id),
revenue AS (
  SELECT c.campaign_id, SUM(o.net_total) AS revenue
  FROM marketing.campaigns c JOIN sales.orders o ON o.order_date BETWEEN c.start_date AND c.end_date AND o.order_status NOT IN ('Cancelled', 'Failed')
  GROUP BY c.campaign_id
)
SELECT s.campaign_id, s.spend, COALESCE(r.revenue, 0) AS revenue,
       ROUND(100.0 * (COALESCE(r.revenue, 0) - s.spend) / NULLIF(s.spend, 0), 2) AS roi_pct
FROM spend s LEFT JOIN revenue r ON r.campaign_id = s.campaign_id
ORDER BY roi_pct DESC NULLS LAST
LIMIT 20;

/* Q43. */
WITH spend AS (SELECT campaign_id, SUM(amount) AS spend FROM marketing.ads_spend GROUP BY campaign_id),
new_cust AS (
  SELECT c.campaign_id, COUNT(*) AS new_customers
  FROM marketing.campaigns c
  JOIN customers.customers cu ON cu.registration_date BETWEEN c.start_date AND c.end_date
  GROUP BY c.campaign_id
)
SELECT s.campaign_id, s.spend, COALESCE(n.new_customers, 0) AS new_customers,
       ROUND(s.spend / NULLIF(n.new_customers, 0), 2) AS cac
FROM spend s LEFT JOIN new_cust n ON n.campaign_id = s.campaign_id
ORDER BY cac DESC NULLS LAST
LIMIT 20;

/* Q44. */
WITH campaign_new_cust AS (
  SELECT c.campaign_id, cu.customer_id
  FROM marketing.campaigns c
  JOIN customers.customers cu ON cu.registration_date BETWEEN c.start_date AND c.end_date
),
cust_spend AS (SELECT cust_id, SUM(net_total) AS spend FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed') GROUP BY cust_id)
SELECT cnc.campaign_id, ROUND(AVG(COALESCE(cs.spend, 0)), 2) AS avg_ltv
FROM campaign_new_cust cnc
LEFT JOIN cust_spend cs ON cs.cust_id = cnc.customer_id
GROUP BY cnc.campaign_id
ORDER BY avg_ltv DESC
LIMIT 20;

/* Q45. */
WITH cohorts AS (SELECT customer_id, DATE_TRUNC('month', registration_date) AS cohort_month FROM customers.customers),
visits AS (SELECT DISTINCT customer_id FROM web_events.page_views WHERE customer_id IS NOT NULL),
orders AS (SELECT DISTINCT cust_id FROM sales.orders)
SELECT c.cohort_month,
       COUNT(*) FILTER (WHERE v.customer_id IS NOT NULL) AS visited,
       COUNT(*) FILTER (WHERE o.cust_id IS NOT NULL) AS ordered,
       ROUND(100.0 * COUNT(*) FILTER (WHERE o.cust_id IS NOT NULL) / NULLIF(COUNT(*) FILTER (WHERE v.customer_id IS NOT NULL), 0), 2) AS conversion_pct
FROM cohorts c
LEFT JOIN visits v ON v.customer_id = c.customer_id
LEFT JOIN orders o ON o.cust_id = c.customer_id
GROUP BY c.cohort_month
ORDER BY c.cohort_month;

/* Q46. */
WITH daily_funnel AS (
  SELECT order_date, COUNT(*) AS orders
  FROM sales.orders GROUP BY order_date
),
avg_daily AS (SELECT AVG(orders) AS avg_orders, STDDEV(orders) AS stddev_orders FROM daily_funnel)
SELECT d.order_date, d.orders
FROM daily_funnel d, avg_daily a
WHERE ABS(d.orders - a.avg_orders) > 2 * a.stddev_orders
ORDER BY d.orders DESC
LIMIT 20;

/* Q47. RetailMart has no experiment/variant table or A/B test flag anywhere in the schema, so there is no test-group split to query - this would require an experiments table assigning customers to control/treatment groups. */

/* Q48. */
WITH steps AS (
  SELECT
    (SELECT COUNT(DISTINCT session_id) FROM web_events.page_views) AS visits,
    (SELECT COUNT(*) FROM sales.orders) AS orders,
    (SELECT COUNT(*) FROM sales.payments) AS payments,
    (SELECT COUNT(*) FROM sales.orders WHERE order_status = 'Delivered') AS delivered
)
SELECT 'visit_to_order' AS weakest_step, ROUND(100.0 * orders / NULLIF(visits, 0), 2) AS conversion_pct FROM steps
UNION ALL
SELECT 'order_to_payment', ROUND(100.0 * payments / NULLIF(orders, 0), 2) FROM steps
UNION ALL
SELECT 'payment_to_delivered', ROUND(100.0 * delivered / NULLIF(payments, 0), 2) FROM steps
ORDER BY conversion_pct ASC
LIMIT 1;

/* Q49. */
SELECT session_id, customer_id, page_url, view_timestamp
FROM web_events.page_views
WHERE customer_id IS NOT NULL
ORDER BY RANDOM()
LIMIT 20;

/* Q50. */
WITH session_path AS (
  SELECT session_id, customer_id, STRING_AGG(page_url, ' -> ' ORDER BY view_timestamp) AS path
  FROM web_events.page_views
  WHERE customer_id IS NOT NULL
  GROUP BY session_id, customer_id
),
cust_revenue AS (SELECT cust_id, SUM(net_total) AS revenue FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed') GROUP BY cust_id)
SELECT sp.path, COUNT(*) AS sessions, ROUND(SUM(COALESCE(r.revenue, 0)), 2) AS associated_revenue
FROM session_path sp
LEFT JOIN cust_revenue r ON r.cust_id = sp.customer_id
GROUP BY sp.path
ORDER BY associated_revenue DESC
LIMIT 20;

/* SECTION C: MULTI-STAGE ETL (25) */

/* Q51. */
WITH order_stats AS (SELECT cust_id, COUNT(*) AS orders, SUM(net_total) AS revenue FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed') GROUP BY cust_id),
loyalty_stats AS (SELECT customer_id, points_balance FROM loyalty.members)
SELECT c.customer_id, c.first_name, c.last_name, c.email, c.tier, c.registration_date,
       COALESCE(o.orders, 0) AS lifetime_orders, COALESCE(o.revenue, 0) AS lifetime_revenue,
       l.points_balance
FROM customers.customers c
LEFT JOIN order_stats o ON o.cust_id = c.customer_id
LEFT JOIN loyalty_stats l ON l.customer_id = c.customer_id
ORDER BY c.customer_id
LIMIT 50;

/* Q52. */
SELECT o.order_id, o.cust_id, o.store_id, o.order_date, o.order_status,
       o.net_total, COUNT(oi.order_item_id) AS line_items, SUM(oi.quantity) AS total_units
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id, o.cust_id, o.store_id, o.order_date, o.order_status, o.net_total
ORDER BY o.order_id
LIMIT 50;

/* Q53. */
SELECT p.product_id, p.product_name, p.price, p.cost_price,
       b.brand_name, cat.category_name, s.supplier_name
FROM products.products p
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
JOIN products.suppliers s ON s.supplier_id = p.supplier_id
ORDER BY p.product_id
LIMIT 50;

/* Q54. */
SELECT warehouse_id, product_id, snapshot_date, quantity_on_hand
FROM supply_chain.inventory_snapshots
WHERE snapshot_date = (SELECT MAX(snapshot_date) FROM supply_chain.inventory_snapshots)
ORDER BY warehouse_id, product_id
LIMIT 50;

/* Q55. */
SELECT c.campaign_id, c.campaign_name, c.start_date, c.end_date,
       COALESCE(SUM(a.amount), 0) AS total_spend,
       COALESCE(SUM(ec.emails_clicked), 0) AS total_clicks
FROM marketing.campaigns c
LEFT JOIN marketing.ads_spend a ON a.campaign_id = c.campaign_id
LEFT JOIN marketing.email_clicks ec ON ec.campaign_id = c.campaign_id
GROUP BY c.campaign_id, c.campaign_name, c.start_date, c.end_date
ORDER BY c.campaign_id
LIMIT 50;

/* Q56. */
SELECT customer_id, source, points_earned, date_earned
FROM customers.loyalty_points
ORDER BY date_earned DESC
LIMIT 50;

/* Q57. */
SELECT event_id, view_id, event_type, element_id, event_timestamp
FROM web_events.events
ORDER BY event_timestamp DESC
LIMIT 50;

/* Q58. */
SELECT ticket_id, customer_id, agent_id, category, priority, status, created_date, resolved_date
FROM support.tickets
ORDER BY created_date DESC
LIMIT 50;

/* Q59. */
SELECT call_id, customer_id, agent_id, call_start_time, call_duration_seconds, call_reason, status
FROM call_center.calls
ORDER BY call_start_time DESC
LIMIT 50;

/* Q60. */
SELECT change_id, table_name, record_id, column_name, old_value, new_value, changed_by, changed_at, action
FROM audit.record_changes
ORDER BY changed_at DESC
LIMIT 50;

/* Q61. */
SELECT customer_id, tier
FROM customers.customers
WHERE customer_id IN (SELECT DISTINCT customer_id FROM customers.customers ORDER BY customer_id LIMIT 20)
ORDER BY customer_id;

/* Q62. */
SELECT customer_id, tier, tier_updated_at,
       LAG(tier) OVER (PARTITION BY customer_id ORDER BY tier_updated_at) AS previous_tier
FROM customers.customers
WHERE tier_updated_at IS NOT NULL
ORDER BY customer_id
LIMIT 50;

/* Q63. */
SELECT customer_id, tier AS current_tier, NULL::varchar AS previous_tier
FROM customers.customers
ORDER BY customer_id
LIMIT 50;

/* Q64. */
SELECT change_id, table_name, record_id, column_name, old_value, new_value, changed_at
FROM audit.record_changes
WHERE table_name = 'employees'
ORDER BY changed_at DESC
LIMIT 50;

/* Q65. */
SELECT customer_id, first_name, last_name, registration_date
FROM customers.customers
WHERE registration_date >= (SELECT MAX(registration_date) FROM customers.customers) - INTERVAL '7 days'
ORDER BY registration_date DESC;

/* Q66. */
SELECT COUNT(*) AS total_customers FROM customers.customers;

/* Q67. */
SELECT order_date, COUNT(*) AS orders
FROM sales.orders
WHERE order_date BETWEEN '2024-01-01' AND '2024-01-31'
GROUP BY order_date
ORDER BY order_date;

/* Q68. */
SELECT o.order_id, o.order_date, p.payment_date, p.payment_date - o.order_date AS days_late
FROM sales.orders o
JOIN sales.payments p ON p.order_id = o.order_id
WHERE p.payment_date - o.order_date > 7
ORDER BY days_late DESC
LIMIT 30;

/* Q69. */
WITH ranked AS (
  SELECT customer_id, email, registration_date,
         ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY registration_date DESC) AS rn
  FROM customers.customers
)
SELECT customer_id, email, registration_date
FROM ranked
WHERE rn > 1
LIMIT 30;

/* Q70. */
SELECT LOWER(TRIM(supplier_name)) AS clean_name, city, email
FROM products.suppliers
ORDER BY clean_name
LIMIT 30;

/* Q71. */
SELECT o.order_id, o.order_date, c.tier, r.region_name
FROM sales.orders o
JOIN customers.customers c ON c.customer_id = o.cust_id
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
ORDER BY o.order_id
LIMIT 30;

/* Q72. */
SELECT DATE_TRUNC('month', order_date) AS month, COUNT(*) AS orders, ROUND(SUM(net_total), 2) AS revenue
FROM sales.orders
WHERE order_status NOT IN ('Cancelled', 'Failed')
GROUP BY 1
ORDER BY 1;

/* Q73. */
WITH monthly_summary AS (
  SELECT DATE_TRUNC('month', order_date) AS month, COUNT(*) AS orders, ROUND(SUM(net_total), 2) AS revenue
  FROM sales.orders
  WHERE order_status NOT IN ('Cancelled', 'Failed')
  GROUP BY 1
)
SELECT month, orders, revenue
FROM monthly_summary
ORDER BY month;

/* Q74. */
SELECT order_id, order_date
FROM sales.orders
WHERE order_date < (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '18 months'
ORDER BY order_date
LIMIT 30;

/* Q75. */
SELECT 'orphan_order_items' AS check_name, COUNT(*) AS bad_rows
FROM sales.order_items oi WHERE NOT EXISTS (SELECT 1 FROM sales.orders o WHERE o.order_id = oi.order_id)
UNION ALL
SELECT 'orphan_reviews', COUNT(*)
FROM customers.reviews r WHERE NOT EXISTS (SELECT 1 FROM products.products p WHERE p.product_id = r.product_id)
UNION ALL
SELECT 'negative_quantities', COUNT(*)
FROM sales.order_items WHERE quantity < 0
UNION ALL
SELECT 'null_customer_orders', COUNT(*)
FROM sales.orders WHERE cust_id IS NULL;

/* SECTION D: REAL BI REPORTS (25) */

/* Q76. */
WITH rev AS (SELECT SUM(net_total) AS total_revenue, COUNT(*) AS total_orders FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed')),
cust AS (SELECT COUNT(*) AS total_customers FROM customers.customers),
refund AS (SELECT SUM(refund_amount) AS total_refunds FROM sales.returns),
tickets AS (SELECT COUNT(*) AS total_tickets, COUNT(*) FILTER (WHERE status IN ('Resolved','Closed')) AS resolved FROM support.tickets),
reviews AS (SELECT ROUND(AVG(rating), 2) AS avg_rating, COUNT(*) AS review_count FROM customers.reviews),
spend AS (SELECT SUM(amount) AS total_ad_spend FROM marketing.ads_spend),
emp AS (SELECT COUNT(*) AS headcount, ROUND(AVG(salary), 2) AS avg_salary FROM stores.employees),
stores_c AS (SELECT COUNT(*) AS store_count FROM stores.stores)
SELECT rev.total_revenue, rev.total_orders, cust.total_customers,
       ROUND(rev.total_revenue / NULLIF(rev.total_orders, 0), 2) AS aov,
       refund.total_refunds, tickets.total_tickets, tickets.resolved,
       reviews.avg_rating, reviews.review_count, spend.total_ad_spend,
       emp.headcount, emp.avg_salary, stores_c.store_count
FROM rev, cust, refund, tickets, reviews, spend, emp, stores_c;

/* Q77. */
WITH rev AS (SELECT SUM(net_total) AS total_revenue FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed')),
exp AS (SELECT SUM(amount) AS total_expenses FROM finance.expenses),
cust AS (SELECT COUNT(*) AS total_customers FROM customers.customers)
SELECT rev.total_revenue, exp.total_expenses, ROUND(rev.total_revenue - exp.total_expenses, 2) AS net_income, cust.total_customers
FROM rev, exp, cust;

/* Q78. */
WITH latest AS (SELECT MAX(order_date) AS d FROM sales.orders)
SELECT latest.d AS report_date,
       (SELECT COUNT(*) FROM sales.orders WHERE order_date = latest.d) AS orders_today,
       (SELECT ROUND(SUM(net_total), 2) FROM sales.orders WHERE order_date = latest.d) AS revenue_today,
       (SELECT COUNT(*) FROM support.tickets WHERE created_date::date = latest.d) AS tickets_today
FROM latest;

/* Q79. */
WITH latest AS (SELECT MAX(order_date) AS d FROM sales.orders),
this_week AS (SELECT COUNT(*) AS orders, SUM(net_total) AS revenue FROM sales.orders, latest WHERE order_date BETWEEN latest.d - INTERVAL '6 days' AND latest.d),
prior_week AS (SELECT COUNT(*) AS orders, SUM(net_total) AS revenue FROM sales.orders, latest WHERE order_date BETWEEN latest.d - INTERVAL '13 days' AND latest.d - INTERVAL '7 days')
SELECT tw.orders AS this_week_orders, tw.revenue AS this_week_revenue,
       pw.orders AS prior_week_orders, pw.revenue AS prior_week_revenue
FROM this_week tw, prior_week pw;

/* Q80. */
WITH monthly_rev AS (SELECT DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS revenue FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed') GROUP BY 1),
monthly_cogs AS (
  SELECT DATE_TRUNC('month', o.order_date) AS month, SUM(oi.quantity * p.cost_price) AS cogs
  FROM sales.order_items oi JOIN sales.orders o ON o.order_id = oi.order_id JOIN products.products p ON p.product_id = oi.prod_id
  WHERE o.order_status NOT IN ('Cancelled', 'Failed') GROUP BY 1
)
SELECT r.month, r.revenue, c.cogs, ROUND(r.revenue - c.cogs, 2) AS gross_profit
FROM monthly_rev r LEFT JOIN monthly_cogs c ON c.month = r.month
ORDER BY r.month;

/* Q81. */
SELECT DATE_TRUNC('quarter', order_date) AS quarter, COUNT(*) AS orders, ROUND(SUM(net_total), 2) AS revenue
FROM sales.orders
WHERE order_status NOT IN ('Cancelled', 'Failed')
GROUP BY 1
ORDER BY 1;

/* Q82. */
SELECT DATE_PART('year', order_date) AS year, COUNT(*) AS orders, ROUND(SUM(net_total), 2) AS revenue,
       COUNT(DISTINCT cust_id) AS active_customers
FROM sales.orders
WHERE order_status NOT IN ('Cancelled', 'Failed')
GROUP BY 1
ORDER BY 1;

/* Q83. */
WITH monthly_rev AS (SELECT DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS revenue FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed') GROUP BY 1)
SELECT month, revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month)) / NULLIF(LAG(revenue) OVER (ORDER BY month), 0), 2) AS mom_growth_pct
FROM monthly_rev
ORDER BY month;

/* Q84. */
WITH first_order AS (SELECT cust_id, MIN(DATE_TRUNC('month', order_date)) AS cohort_month FROM sales.orders GROUP BY cust_id),
cust_revenue AS (SELECT cust_id, SUM(net_total) AS revenue FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed') GROUP BY cust_id)
SELECT f.cohort_month, ROUND(AVG(COALESCE(r.revenue, 0)), 2) AS cohort_avg_ltv
FROM first_order f
LEFT JOIN cust_revenue r ON r.cust_id = f.cust_id
GROUP BY f.cohort_month
ORDER BY f.cohort_month;

/* Q85. */
WITH cust_metrics AS (
  SELECT c.customer_id,
         (SELECT MAX(order_date) FROM sales.orders) - MAX(o.order_date) AS recency_days,
         COUNT(o.order_id) AS frequency, COALESCE(SUM(o.net_total), 0) AS monetary
  FROM customers.customers c
  LEFT JOIN sales.orders o ON o.cust_id = c.customer_id AND o.order_status NOT IN ('Cancelled', 'Failed')
  GROUP BY c.customer_id
),
scored AS (
  SELECT customer_id,
         NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,
         NTILE(5) OVER (ORDER BY frequency DESC) AS f_score,
         NTILE(5) OVER (ORDER BY monetary DESC) AS m_score
  FROM cust_metrics
)
SELECT r_score, f_score, m_score, COUNT(*) AS customers, ROUND(AVG(cm.monetary), 2) AS avg_spend
FROM scored s JOIN cust_metrics cm ON cm.customer_id = s.customer_id
GROUP BY r_score, f_score, m_score
ORDER BY m_score DESC, f_score DESC, r_score DESC
LIMIT 30;

/* Q86. */
WITH scored AS (SELECT CASE WHEN rating = 5 THEN 'promoter' WHEN rating = 4 THEN 'passive' ELSE 'detractor' END AS category FROM customers.reviews)
SELECT ROUND(100.0 * (COUNT(*) FILTER (WHERE category = 'promoter') - COUNT(*) FILTER (WHERE category = 'detractor')) / COUNT(*), 2) AS nps
FROM scored;

/* Q87. */
SELECT ROUND(AVG(rating), 2) AS avg_rating, ROUND(100.0 * COUNT(*) FILTER (WHERE rating >= 4) / COUNT(*), 2) AS csat_pct
FROM customers.reviews;

/* Q88. */
WITH last_order AS (SELECT cust_id, MAX(order_date) AS last_order_date FROM sales.orders GROUP BY cust_id)
SELECT c.customer_id, c.first_name, c.last_name, l.last_order_date,
       (SELECT MAX(order_date) FROM sales.orders) - l.last_order_date AS days_since_last_order
FROM customers.customers c
JOIN last_order l ON l.cust_id = c.customer_id
WHERE l.last_order_date < (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '90 days'
ORDER BY days_since_last_order DESC
LIMIT 30;

/* Q89. */
WITH orders_cnt AS (SELECT cust_id, COUNT(*) AS n FROM sales.orders GROUP BY cust_id),
reviews_cnt AS (SELECT customer_id, COUNT(*) AS n FROM customers.reviews GROUP BY customer_id)
SELECT c.tier, ROUND(AVG(COALESCE(o.n, 0)), 2) AS avg_orders, ROUND(AVG(COALESCE(r.n, 0)), 2) AS avg_reviews
FROM customers.customers c
LEFT JOIN orders_cnt o ON o.cust_id = c.customer_id
LEFT JOIN reviews_cnt r ON r.customer_id = c.customer_id
GROUP BY c.tier
ORDER BY avg_orders DESC;

/* Q90. */
SELECT t.tier_name, COUNT(m.customer_id) AS members, ROUND(AVG(m.points_balance), 2) AS avg_points,
       COUNT(rd.redemption_id) AS redemptions
FROM loyalty.tiers t
JOIN loyalty.members m ON m.tier_id = t.tier_id
LEFT JOIN loyalty.redemptions rd ON rd.customer_id = m.customer_id
GROUP BY t.tier_name
ORDER BY avg_points DESC;

/* Q91. */
WITH spend AS (SELECT SUM(amount) AS total_spend FROM marketing.ads_spend),
rev AS (SELECT SUM(net_total) AS total_revenue FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed'))
SELECT spend.total_spend, rev.total_revenue, ROUND(rev.total_revenue / NULLIF(spend.total_spend, 0), 2) AS marketing_roas
FROM spend, rev;

/* Q92. */
SELECT DATE_TRUNC('month', order_date) AS month, COUNT(*) AS orders,
       ROUND(COUNT(*)::numeric / EXTRACT(DAY FROM (DATE_TRUNC('month', order_date) + INTERVAL '1 month - 1 day')), 2) AS avg_orders_per_day
FROM sales.orders
GROUP BY 1
ORDER BY 1;

/* Q93. */
WITH cogs AS (
  SELECT SUM(oi.quantity * p.cost_price) AS total_cogs
  FROM sales.order_items oi JOIN sales.orders o ON o.order_id = oi.order_id JOIN products.products p ON p.product_id = oi.prod_id
  WHERE o.order_status NOT IN ('Cancelled', 'Failed')
),
avg_inv AS (SELECT AVG(i.quantity_on_hand * p.cost_price) AS avg_inventory_value FROM products.inventory i JOIN products.products p ON p.product_id = i.product_id)
SELECT c.total_cogs, a.avg_inventory_value, ROUND(c.total_cogs / NULLIF(a.avg_inventory_value, 0), 2) AS inventory_turnover
FROM cogs c, avg_inv a;

/* Q94. */
WITH sup_sales AS (
  SELECT p.supplier_id, SUM(oi.net_amount) AS revenue, SUM(oi.quantity) AS units
  FROM sales.order_items oi JOIN products.products p ON p.product_id = oi.prod_id GROUP BY p.supplier_id
)
SELECT s.supplier_id, s.supplier_name, s.city, COALESCE(ss.revenue, 0) AS revenue, COALESCE(ss.units, 0) AS units
FROM products.suppliers s
LEFT JOIN sup_sales ss ON ss.supplier_id = s.supplier_id
ORDER BY revenue DESC NULLS LAST
LIMIT 20;

/* Q95. */
SELECT courier_name, COUNT(*) AS shipments,
       ROUND(AVG(delivered_date - shipped_date), 2) AS avg_delivery_days,
       COUNT(*) FILTER (WHERE status = 'Returned') AS returned_shipments
FROM sales.shipments
GROUP BY courier_name
ORDER BY avg_delivery_days;

/* Q96. */
SELECT c.agent_id, COUNT(*) AS calls, ROUND(AVG(c.call_duration_seconds), 2) AS avg_duration,
       ROUND(AVG(t.sentiment_score), 3) AS avg_sentiment
FROM call_center.calls c
JOIN call_center.transcripts t ON t.call_id = c.call_id
GROUP BY c.agent_id
ORDER BY calls DESC
LIMIT 20;

/* Q97. */
SELECT s.store_id, s.store_name, COUNT(o.order_id) AS orders, ROUND(SUM(o.net_total), 2) AS revenue
FROM stores.stores s
JOIN sales.orders o ON o.store_id = s.store_id AND o.order_status NOT IN ('Cancelled', 'Failed')
GROUP BY s.store_id, s.store_name
ORDER BY revenue DESC
LIMIT 20;

/* Q98. */
SELECT r.region_name, COUNT(DISTINCT s.store_id) AS stores, ROUND(SUM(o.net_total), 2) AS revenue,
       ROUND(SUM(o.net_total) / NULLIF(COUNT(DISTINCT s.store_id), 0), 2) AS revenue_per_store
FROM core.dim_region r
JOIN stores.stores s ON s.region_id = r.region_id
JOIN sales.orders o ON o.store_id = s.store_id AND o.order_status NOT IN ('Cancelled', 'Failed')
GROUP BY r.region_name
ORDER BY revenue DESC;

/* Q99. */
SELECT b.brand_id, b.brand_name, COUNT(DISTINCT p.product_id) AS products,
       ROUND(SUM(oi.net_amount), 2) AS revenue, ROUND(AVG(r.rating), 2) AS avg_rating
FROM core.dim_brand b
JOIN products.products p ON p.brand_id = b.brand_id
LEFT JOIN sales.order_items oi ON oi.prod_id = p.product_id
LEFT JOIN customers.reviews r ON r.product_id = p.product_id
GROUP BY b.brand_id, b.brand_name
ORDER BY revenue DESC NULLS LAST
LIMIT 20;

/* Q100. */
WITH RECURSIVE hierarchy AS (
  SELECT 'cat_' || category_id::text AS node_id, NULL::text AS parent_id, category_name::text AS node_name, 0 AS lvl
  FROM core.dim_category
  UNION ALL
  SELECT 'brand_' || b.brand_id::text, 'cat_' || b.category_id::text, b.brand_name::text, h.lvl + 1
  FROM core.dim_brand b
  JOIN hierarchy h ON h.node_id = 'cat_' || b.category_id::text
),
brand_revenue AS (
  SELECT p.brand_id, SUM(oi.net_amount) AS revenue
  FROM sales.order_items oi JOIN products.products p ON p.product_id = oi.prod_id
  GROUP BY p.brand_id
),
ranked_brands AS (
  SELECT h.node_name AS brand_name, COALESCE(br.revenue, 0) AS revenue,
         RANK() OVER (ORDER BY COALESCE(br.revenue, 0) DESC) AS revenue_rank
  FROM hierarchy h
  LEFT JOIN brand_revenue br ON h.node_id = 'brand_' || br.brand_id::text
  WHERE h.lvl = 1
),
top_products AS (
  SELECT p.product_id, p.product_name, p.brand_id, oi.net_amount,
         ROW_NUMBER() OVER (PARTITION BY p.brand_id ORDER BY oi.net_amount DESC) AS rn
  FROM sales.order_items oi
  JOIN products.products p ON p.product_id = oi.prod_id
),
top_and_bottom AS (
  SELECT brand_name, revenue, revenue_rank, 'top' AS bucket FROM ranked_brands WHERE revenue_rank <= 3
  UNION
  SELECT brand_name, revenue, revenue_rank, 'bottom' AS bucket FROM ranked_brands WHERE revenue_rank > (SELECT MAX(revenue_rank) FROM ranked_brands) - 3
)
SELECT tb.bucket, tb.brand_name, tb.revenue, tb.revenue_rank,
       lp.product_name AS top_product_in_brand
FROM top_and_bottom tb
LEFT JOIN LATERAL (
  SELECT p.product_name
  FROM products.products p
  WHERE p.brand_id = (SELECT brand_id FROM core.dim_brand WHERE brand_name = tb.brand_name LIMIT 1)
  ORDER BY p.price DESC
  LIMIT 1
) lp ON true
ORDER BY tb.bucket, tb.revenue_rank;

/* ============================================================
   END OF ANSWER KEY - HARD LEVEL (100/100)
============================================================ */
