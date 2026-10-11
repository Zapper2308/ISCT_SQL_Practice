/* ============================================================
   ANSWER KEY - JOINs Part 1 (Foundations) (CRAZY LEVEL)
   Curriculum:   RetailMart V3
   Note: this practice database has NO indexes on foreign-key
   columns, so large correlated/LATERAL patterns are bounded with a
   LIMIT or a small sample where noted. Some questions describe
   concepts RetailMart V3 has no data for (A/B tests, channel/source
   attribution, schema-version history) - those get a short
   conceptual note instead of a fabricated query.
   ============================================================ */

/* ============================================================
   SECTION A: MEGA TABLE CHAINS (25)
   ------------------------------------------------------------ */
/* Q1. */
SELECT o.order_id, p.product_name, b.brand_name, cat.category_name, sup.supplier_name,
       w.name AS warehouse_name, w.region
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
JOIN products.products p ON oi.prod_id = p.product_id
JOIN core.dim_brand b ON p.brand_id = b.brand_id
JOIN core.dim_category cat ON b.category_id = cat.category_id
JOIN products.suppliers sup ON p.supplier_id = sup.supplier_id
LEFT JOIN LATERAL (
  SELECT sh.warehouse_id FROM supply_chain.shipments sh
  WHERE sh.supplier_id = sup.supplier_id AND sh.product_id = p.product_id
  ORDER BY sh.shipped_date DESC LIMIT 1
) latest_ship ON TRUE
LEFT JOIN supply_chain.warehouses w ON w.warehouse_id = latest_ship.warehouse_id
LIMIT 200;

/* Q2. Full lifecycle for a bounded sample of customers (10-table correlated fan-out is not practical for all 50,000 customers without FK indexes). */
SELECT c.customer_id, c.tier,
       oc.order_count, oc.total_spend,
       rc.review_count, tc.ticket_count, cc.call_count,
       lm.tier_id AS loyalty_tier_id, lr.redemption_count,
       pay.payment_count
FROM customers.customers c
LEFT JOIN (SELECT cust_id, COUNT(*) AS order_count, SUM(net_total) AS total_spend FROM sales.orders GROUP BY cust_id) oc ON oc.cust_id = c.customer_id
LEFT JOIN (SELECT customer_id, COUNT(*) AS review_count FROM customers.reviews GROUP BY customer_id) rc ON rc.customer_id = c.customer_id
LEFT JOIN (SELECT customer_id, COUNT(*) AS ticket_count FROM support.tickets GROUP BY customer_id) tc ON tc.customer_id = c.customer_id
LEFT JOIN (SELECT customer_id, COUNT(*) AS call_count FROM call_center.calls GROUP BY customer_id) cc ON cc.customer_id = c.customer_id
LEFT JOIN loyalty.members lm ON lm.customer_id = c.customer_id
LEFT JOIN (SELECT customer_id, COUNT(*) AS redemption_count FROM loyalty.redemptions GROUP BY customer_id) lr ON lr.customer_id = c.customer_id
LEFT JOIN (SELECT cust_id, COUNT(*) AS payment_count FROM finance.payments GROUP BY cust_id) pay ON pay.cust_id = c.customer_id
WHERE c.customer_id <= 200
ORDER BY c.customer_id;

/* Q3. */
WITH order_item_agg AS (
  SELECT order_id, SUM(net_amount) AS items_total, COUNT(*) AS item_count
  FROM sales.order_items GROUP BY order_id
)
SELECT c.customer_id, c.tier, COUNT(o.order_id) AS order_count, SUM(oia.items_total) AS total_spend
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
JOIN order_item_agg oia ON oia.order_id = o.order_id
GROUP BY c.customer_id, c.tier;

/* Q4. */
SELECT r.region_name, cat.category_name, SUM(oi.net_amount) AS revenue
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
JOIN products.products p ON oi.prod_id = p.product_id
JOIN core.dim_brand b ON p.brand_id = b.brand_id
JOIN core.dim_category cat ON b.category_id = cat.category_id
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY r.region_name, cat.category_name
ORDER BY r.region_name, revenue DESC;

/* Q5. */
SELECT c.campaign_name, a.platform, SUM(a.amount) AS spend,
       SUM(ec.emails_sent) AS emails_sent, SUM(ec.emails_clicked) AS emails_clicked
FROM marketing.campaigns c
LEFT JOIN marketing.ads_spend a ON a.campaign_id = c.campaign_id
LEFT JOIN marketing.email_clicks ec ON ec.campaign_id = c.campaign_id
GROUP BY c.campaign_name, a.platform;

/* Q6. */
SELECT r.region_name, d.dept_name, COUNT(DISTINCT e.employee_id) AS employee_count,
       SUM(ps.gross_salary) AS total_payroll
FROM core.dim_region r
JOIN stores.stores s ON s.region_id = r.region_id
JOIN stores.employees e ON e.store_id = s.store_id
JOIN core.dim_department d ON e.dept_id = d.dept_id
LEFT JOIN payroll.pay_slips ps ON ps.employee_id = e.employee_id
GROUP BY r.region_name, d.dept_name;

/* Q7. */
SELECT r.region_name, d.dept_name, COUNT(*) AS ticket_count
FROM support.tickets t
JOIN stores.employees e ON t.agent_id = e.employee_id
JOIN core.dim_department d ON e.dept_id = d.dept_id
JOIN stores.stores s ON e.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY r.region_name, d.dept_name;

/* Q8. */
SELECT w.name AS warehouse_name, p.product_name, b.brand_name, sup.supplier_name,
       SUM(isn.quantity_on_hand) AS total_on_hand
FROM supply_chain.inventory_snapshots isn
JOIN supply_chain.warehouses w ON isn.warehouse_id = w.warehouse_id
JOIN products.products p ON isn.product_id = p.product_id
JOIN core.dim_brand b ON p.brand_id = b.brand_id
JOIN products.suppliers sup ON p.supplier_id = sup.supplier_id
WHERE isn.snapshot_date = (SELECT MAX(snapshot_date) FROM supply_chain.inventory_snapshots)
GROUP BY w.name, p.product_name, b.brand_name, sup.supplier_name
LIMIT 200;

/* Q9. */
SELECT c.customer_id,
       COALESCE(oc.order_count, 0) AS order_count,
       COALESCE(oc.total_spend, 0) AS total_spend,
       COALESCE(cc.call_count, 0) AS call_count,
       COALESCE(tc.ticket_count, 0) AS ticket_count
FROM customers.customers c
LEFT JOIN (SELECT cust_id, COUNT(*) AS order_count, SUM(net_total) AS total_spend FROM sales.orders GROUP BY cust_id) oc ON oc.cust_id = c.customer_id
LEFT JOIN (SELECT customer_id, COUNT(*) AS call_count FROM call_center.calls GROUP BY customer_id) cc ON cc.customer_id = c.customer_id
LEFT JOIN (SELECT customer_id, COUNT(*) AS ticket_count FROM support.tickets GROUP BY customer_id) tc ON tc.customer_id = c.customer_id;

/* Q10. */
SELECT r.region_name,
       COUNT(DISTINCT e.employee_id) AS employee_count,
       COUNT(DISTINCT o.order_id) AS order_count,
       COUNT(DISTINCT c.customer_id) AS customer_count
FROM core.dim_region r
LEFT JOIN stores.stores s ON s.region_id = r.region_id
LEFT JOIN stores.employees e ON e.store_id = s.store_id
LEFT JOIN sales.orders o ON o.store_id = s.store_id
LEFT JOIN customers.customers c ON c.customer_id = o.cust_id
GROUP BY r.region_name;

/* Q11. */
SELECT o.order_id, pay.payment_mode, sh.courier_name, sh.status AS shipment_status,
       r.rating AS review_rating
FROM sales.orders o
LEFT JOIN sales.payments pay ON pay.order_id = o.order_id
LEFT JOIN sales.shipments sh ON sh.order_id = o.order_id
LEFT JOIN sales.order_items oi ON oi.order_id = o.order_id
LEFT JOIN customers.reviews r ON r.customer_id = o.cust_id AND r.product_id = oi.prod_id
LIMIT 200;

/* Q12. */
WITH first_order AS (
  SELECT cust_id, MIN(order_date) AS first_order_date FROM sales.orders GROUP BY cust_id
),
first_review AS (
  SELECT customer_id, MIN(review_date) AS first_review_date FROM customers.reviews GROUP BY customer_id
)
SELECT c.customer_id, c.registration_date, fo.first_order_date, c.tier_updated_at, fr.first_review_date
FROM customers.customers c
LEFT JOIN first_order fo ON fo.cust_id = c.customer_id
LEFT JOIN first_review fr ON fr.customer_id = c.customer_id
WHERE c.customer_id <= 200
ORDER BY c.customer_id;

/* Q13. */
SELECT o.order_id, oi.order_item_id, r.return_id, r.reason, af.refund_id, af.amount AS refund_amount
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
JOIN sales.returns r ON r.order_id = o.order_id AND r.prod_id = oi.prod_id
LEFT JOIN audit.refund_log af ON af.order_id = o.order_id
LIMIT 200;

/* Q14. */
SELECT a.spend_id, c.campaign_name, a.amount AS spend,
       o.order_id, o.net_total, cust.customer_id, r.rating
FROM marketing.ads_spend a
JOIN marketing.campaigns c ON a.campaign_id = c.campaign_id
LEFT JOIN sales.orders o ON o.order_date BETWEEN c.start_date AND c.end_date
LEFT JOIN customers.customers cust ON cust.customer_id = o.cust_id
LEFT JOIN customers.reviews r ON r.customer_id = cust.customer_id
LIMIT 200;

/* Q15. */
SELECT t.ticket_id, c.first_name AS customer_name, p.product_name, o.order_id, t.resolved_date
FROM support.tickets t
JOIN customers.customers c ON t.customer_id = c.customer_id
LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
LEFT JOIN sales.order_items oi ON oi.order_id = o.order_id
LEFT JOIN products.products p ON p.product_id = oi.prod_id
LIMIT 200;

/* Q16. */
SELECT cl.call_id, c.first_name AS customer_name,
       po.order_count AS past_orders, tc.ticket_count
FROM call_center.calls cl
JOIN customers.customers c ON cl.customer_id = c.customer_id
LEFT JOIN (SELECT cust_id, COUNT(*) AS order_count FROM sales.orders GROUP BY cust_id) po ON po.cust_id = c.customer_id
LEFT JOIN (SELECT customer_id, COUNT(*) AS ticket_count FROM support.tickets GROUP BY customer_id) tc ON tc.customer_id = c.customer_id
LIMIT 200;

/* Q17. RetailMart has no cart/checkout event labels, so page_view -> order (by customer) is the closest traceable web-to-order path. */
SELECT pv.view_id, pv.session_id, pv.page_url, o.order_id
FROM web_events.page_views pv
LEFT JOIN sales.orders o ON o.cust_id = pv.customer_id AND o.order_date = pv.view_timestamp::date
WHERE pv.customer_id IS NOT NULL
LIMIT 200;

/* Q18. */
SELECT sup.supplier_name, p.product_name, isn.quantity_on_hand, sh.shipment_id, oi.order_item_id
FROM products.suppliers sup
JOIN products.products p ON p.supplier_id = sup.supplier_id
LEFT JOIN supply_chain.inventory_snapshots isn ON isn.product_id = p.product_id
LEFT JOIN supply_chain.shipments sh ON sh.supplier_id = sup.supplier_id AND sh.product_id = p.product_id
LEFT JOIN sales.order_items oi ON oi.prod_id = p.product_id
LIMIT 200;

/* Q19. RetailMart has no bank-account table for employees, so the chain stops at pay_slips. */
SELECT e.employee_id, a.attendance_date, ps.pay_slip_id, ps.net_salary
FROM stores.employees e
LEFT JOIN hr.attendance a ON a.employee_id = e.employee_id
LEFT JOIN payroll.pay_slips ps ON ps.employee_id = e.employee_id
LIMIT 200;

/* Q20. */
SELECT r.region_name, COUNT(DISTINCT e.employee_id) AS employee_count,
       COUNT(DISTINCT o.order_id) AS order_count, COUNT(DISTINCT c.customer_id) AS customer_count
FROM core.dim_region r
LEFT JOIN stores.stores s ON s.region_id = r.region_id
LEFT JOIN stores.employees e ON e.store_id = s.store_id
LEFT JOIN sales.orders o ON o.store_id = s.store_id
LEFT JOIN customers.customers c ON c.customer_id = o.cust_id
GROUP BY r.region_name;

/* Q21. */
SELECT b.brand_name, r.region_name, SUM(oi.net_amount) AS revenue
FROM core.dim_brand b
JOIN products.products p ON p.brand_id = b.brand_id
JOIN sales.order_items oi ON oi.prod_id = p.product_id
JOIN sales.orders o ON oi.order_id = o.order_id
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY b.brand_name, r.region_name;

/* Q22. */
SELECT c.customer_id, lt.tier_name, lm.points_balance, lr.reward_name
FROM customers.customers c
JOIN loyalty.members lm ON lm.customer_id = c.customer_id
JOIN loyalty.tiers lt ON lm.tier_id = lt.tier_id
LEFT JOIN loyalty.redemptions lr ON lr.customer_id = c.customer_id;

/* Q23. RetailMart's schema has no A/B test / experiment tables (no variant, experiment_id, or assignment columns), so this chain cannot be built from the available data. */

/* Q24. */
SELECT o.order_id, al.log_id, al.message, ar.request_id, ar.status_code
FROM sales.orders o
LEFT JOIN audit.record_changes rc ON rc.table_name = 'sales.orders' AND rc.record_id = o.order_id
LEFT JOIN audit.application_logs al ON al.trace_id = rc.change_id::text
LEFT JOIN audit.api_requests ar ON ar.request_id = al.trace_id
LIMIT 200;

/* Q25. */
SELECT o.order_id, c.first_name AS customer_name, s.store_name, r.region_name,
       oi.order_item_id, p.product_name, b.brand_name, cat.category_name, sup.supplier_name, pay.payment_mode
FROM sales.orders o
JOIN customers.customers c ON o.cust_id = c.customer_id
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
JOIN sales.order_items oi ON oi.order_id = o.order_id
JOIN products.products p ON oi.prod_id = p.product_id
JOIN core.dim_brand b ON p.brand_id = b.brand_id
JOIN core.dim_category cat ON b.category_id = cat.category_id
JOIN products.suppliers sup ON p.supplier_id = sup.supplier_id
LEFT JOIN sales.payments pay ON pay.order_id = o.order_id
LIMIT 200;

/* ============================================================
   SECTION B: BI DASHBOARDS (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS revenue, COUNT(*) AS orders,
       COUNT(DISTINCT cust_id) AS customers, AVG(net_total) AS aov
FROM sales.orders GROUP BY DATE_TRUNC('month', order_date) ORDER BY month;

/* Q27. */
SELECT region_name, store_name, revenue
FROM (
  SELECT r.region_name, s.store_name, SUM(o.net_total) AS revenue,
         RANK() OVER (PARTITION BY r.region_name ORDER BY SUM(o.net_total) DESC) AS rnk
  FROM sales.orders o
  JOIN stores.stores s ON o.store_id = s.store_id
  JOIN core.dim_region r ON s.region_id = r.region_id
  GROUP BY r.region_name, s.store_name
) ranked
WHERE rnk <= 5
ORDER BY region_name, rnk;

/* Q28. */
SELECT lt.tier_name, COUNT(DISTINCT lm.customer_id) AS members, SUM(lm.points_balance) AS total_points,
       COUNT(DISTINCT lr.redemption_id) AS redemptions, SUM(o.net_total) AS revenue
FROM loyalty.tiers lt
LEFT JOIN loyalty.members lm ON lm.tier_id = lt.tier_id
LEFT JOIN loyalty.redemptions lr ON lr.customer_id = lm.customer_id
LEFT JOIN sales.orders o ON o.cust_id = lm.customer_id
GROUP BY lt.tier_name;

/* Q29. */
SELECT c.campaign_name, SUM(a.amount) AS spend, COUNT(DISTINCT o.order_id) AS attributed_orders,
       SUM(o.net_total) AS attributed_revenue,
       SUM(o.net_total) / NULLIF(SUM(a.amount), 0) AS roi
FROM marketing.campaigns c
LEFT JOIN marketing.ads_spend a ON a.campaign_id = c.campaign_id
LEFT JOIN sales.orders o ON o.order_date BETWEEN c.start_date AND c.end_date
GROUP BY c.campaign_name;

/* Q30. */
SELECT
  (SELECT COUNT(*) FROM support.tickets) AS ticket_count,
  (SELECT COUNT(*) FROM call_center.calls) AS call_count,
  (SELECT AVG(EXTRACT(EPOCH FROM (resolved_date - created_date))/3600.0) FROM support.tickets WHERE resolved_date IS NOT NULL) AS avg_resolution_hours,
  (SELECT AVG(sentiment_score) FROM call_center.transcripts) AS avg_csat_proxy_sentiment;

/* Q31. */
SELECT w.name AS warehouse_name, SUM(isn.quantity_on_hand) AS total_stock,
       COUNT(*) FILTER (WHERE isn.quantity_on_hand < 10) AS low_stock_items
FROM supply_chain.inventory_snapshots isn
JOIN supply_chain.warehouses w ON isn.warehouse_id = w.warehouse_id
WHERE isn.snapshot_date = (SELECT MAX(snapshot_date) FROM supply_chain.inventory_snapshots)
GROUP BY w.name;

/* Q32. */
SELECT sup.supplier_name, COUNT(*) AS deliveries,
       COUNT(*) FILTER (WHERE sh.arrival_date > sh.shipped_date + 14) AS late_deliveries
FROM supply_chain.shipments sh
JOIN products.suppliers sup ON sh.supplier_id = sup.supplier_id
GROUP BY sup.supplier_name
ORDER BY deliveries DESC;

/* Q33. */
SELECT b.brand_name, SUM(oi.net_amount) AS revenue,
       COUNT(DISTINCT r.return_id) AS return_count, AVG(rv.rating) AS avg_rating
FROM core.dim_brand b
JOIN products.products p ON p.brand_id = b.brand_id
LEFT JOIN sales.order_items oi ON oi.prod_id = p.product_id
LEFT JOIN sales.returns r ON r.prod_id = p.product_id
LEFT JOIN customers.reviews rv ON rv.product_id = p.product_id
GROUP BY b.brand_name;

/* Q34. */
SELECT cat.category_name, DATE_TRUNC('month', o.order_date) AS month, SUM(oi.net_amount) AS revenue
FROM sales.order_items oi
JOIN sales.orders o ON oi.order_id = o.order_id
JOIN products.products p ON oi.prod_id = p.product_id
JOIN core.dim_brand b ON p.brand_id = b.brand_id
JOIN core.dim_category cat ON b.category_id = cat.category_id
GROUP BY cat.category_name, DATE_TRUNC('month', o.order_date)
ORDER BY cat.category_name, month;

/* Q35. RetailMart doesn't tag orders with acquisition channel, so payment_mode is used as the closest available "channel" split. */
SELECT payment_mode, COUNT(*) AS orders, SUM(amount) AS revenue
FROM sales.payments GROUP BY payment_mode;

/* Q36. */
SELECT cohort_month, order_month,
       COUNT(DISTINCT cust_id) AS active_customers
FROM (
  SELECT c.customer_id AS cust_id, DATE_TRUNC('month', c.registration_date) AS cohort_month,
         DATE_TRUNC('month', o.order_date) AS order_month
  FROM customers.customers c
  JOIN sales.orders o ON o.cust_id = c.customer_id
) x
GROUP BY cohort_month, order_month
ORDER BY cohort_month, order_month;

/* Q37. Churn defined as no order in the 90 days before the data's latest order date. */
WITH ref AS (SELECT MAX(order_date) AS today FROM sales.orders),
last_order AS (SELECT cust_id, MAX(order_date) AS last_order_date FROM sales.orders GROUP BY cust_id)
SELECT COUNT(*) AS churned_customers
FROM last_order, ref
WHERE last_order_date < ref.today - 90;

/* Q38. */
SELECT reason, COUNT(*) AS return_count, SUM(refund_amount) AS total_refund
FROM sales.returns
GROUP BY reason
ORDER BY total_refund DESC;

/* Q39. */
SELECT cust_id, SUM(net_total) AS ltv
FROM sales.orders
GROUP BY cust_id
ORDER BY ltv DESC
LIMIT 20;

/* Q40. */
SELECT p.product_id, p.product_name,
       SUM(oi.quantity) / NULLIF((MAX(o.order_date) - MIN(o.order_date)) + 1, 0) AS units_per_day
FROM sales.order_items oi
JOIN sales.orders o ON oi.order_id = o.order_id
JOIN products.products p ON oi.prod_id = p.product_id
GROUP BY p.product_id, p.product_name
ORDER BY units_per_day DESC
LIMIT 20;

/* Q41. */
SELECT e.employee_id, e.first_name, COUNT(DISTINCT t.ticket_id) AS tickets_handled,
       COUNT(DISTINCT cl.call_id) AS calls_handled
FROM stores.employees e
LEFT JOIN support.tickets t ON t.agent_id = e.employee_id
LEFT JOIN call_center.calls cl ON cl.agent_id = e.employee_id
GROUP BY e.employee_id, e.first_name
ORDER BY COUNT(DISTINCT t.ticket_id) + COUNT(DISTINCT cl.call_id) DESC
LIMIT 20;

/* Q42. */
SELECT w.name AS warehouse_name, COUNT(*) AS shipment_count, SUM(sh.quantity) AS total_quantity
FROM supply_chain.shipments sh
JOIN supply_chain.warehouses w ON sh.warehouse_id = w.warehouse_id
GROUP BY w.name;

/* Q43. */
SELECT courier_name, COUNT(*) AS shipment_count,
       AVG(delivered_date - shipped_date) AS avg_delivery_days
FROM sales.shipments
WHERE delivered_date IS NOT NULL
GROUP BY courier_name;

/* Q44. */
SELECT r.region_name, COUNT(*) AS order_count, SUM(o.net_total) AS revenue
FROM sales.orders o
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY r.region_name;

/* Q45. */
SELECT device_type, COUNT(*) AS view_count
FROM web_events.page_views GROUP BY device_type;

/* Q46. */
SELECT EXTRACT(HOUR FROM view_timestamp) AS hour_of_day, COUNT(*) AS view_count
FROM web_events.page_views GROUP BY EXTRACT(HOUR FROM view_timestamp) ORDER BY hour_of_day;

/* Q47. */
SELECT TO_CHAR(order_date, 'Day') AS day_of_week, COUNT(*) AS order_count, SUM(net_total) AS revenue
FROM sales.orders GROUP BY TO_CHAR(order_date, 'Day'), EXTRACT(DOW FROM order_date)
ORDER BY EXTRACT(DOW FROM order_date);

/* Q48. Holiday defined as a fixed list of major holiday dates falling within the data range. */
WITH holidays(holiday_date) AS (
  VALUES ('2024-01-01'::date), ('2024-12-25'::date), ('2025-01-01'::date), ('2025-12-25'::date), ('2026-01-01'::date)
)
SELECT CASE WHEN o.order_date IN (SELECT holiday_date FROM holidays) THEN 'Holiday' ELSE 'Non-Holiday' END AS day_type,
       COUNT(*) AS order_count, AVG(o.net_total) AS avg_order_value
FROM sales.orders o
GROUP BY day_type;

/* Q49. */
WITH first_order AS (SELECT cust_id, MIN(order_date) AS first_order_date FROM sales.orders GROUP BY cust_id)
SELECT CASE WHEN o.order_date = fo.first_order_date THEN 'New' ELSE 'Returning' END AS customer_type,
       COUNT(*) AS order_count, SUM(o.net_total) AS revenue
FROM sales.orders o
JOIN first_order fo ON fo.cust_id = o.cust_id
GROUP BY customer_type;

/* Q50. Representative executive 1-pager (a literal 30-metric single row is impractical to read - this consolidates the highest-value KPIs). */
SELECT
  (SELECT COUNT(*) FROM sales.orders) AS total_orders,
  (SELECT SUM(net_total) FROM sales.orders) AS total_revenue,
  (SELECT AVG(net_total) FROM sales.orders) AS aov,
  (SELECT COUNT(*) FROM customers.customers) AS total_customers,
  (SELECT COUNT(*) FROM sales.returns) AS total_returns,
  (SELECT COUNT(*) FROM support.tickets WHERE status = 'Open') AS open_tickets,
  (SELECT SUM(amount) FROM marketing.ads_spend) AS total_ad_spend,
  (SELECT COUNT(*) FROM stores.stores) AS total_stores,
  (SELECT COUNT(*) FROM stores.employees) AS total_employees,
  (SELECT SUM(net_salary) FROM payroll.pay_slips) AS total_payroll;

/* ============================================================
   SECTION C: PERFORMANCE TUNING (25)
   All DDL/session-setting demonstrations run inside BEGIN...ROLLBACK
   so they are safe to execute against this shared practice database
   without leaving indexes/config changes behind.
   ------------------------------------------------------------ */
/* Q51. */
EXPLAIN ANALYZE
SELECT o.order_id, c.first_name, s.store_name, oi.order_item_id, p.product_name, b.brand_name
FROM sales.orders o
JOIN customers.customers c ON o.cust_id = c.customer_id
JOIN stores.stores s ON o.store_id = s.store_id
JOIN sales.order_items oi ON oi.order_id = o.order_id
JOIN products.products p ON oi.prod_id = p.product_id
JOIN core.dim_brand b ON p.brand_id = b.brand_id
LIMIT 1000;

/* Q52. */
WITH order_item_agg AS (
  SELECT order_id, SUM(net_amount) AS items_total FROM sales.order_items GROUP BY order_id
)
SELECT o.order_id, o.net_total, oia.items_total
FROM sales.orders o JOIN order_item_agg oia ON oia.order_id = o.order_id;

/* Q53. */
BEGIN;
CREATE TEMP TABLE tmp_order_item_agg AS
  SELECT order_id, SUM(net_amount) AS items_total FROM sales.order_items GROUP BY order_id;
SELECT o.order_id, o.net_total, t.items_total
FROM sales.orders o JOIN tmp_order_item_agg t ON t.order_id = o.order_id
LIMIT 100;
ROLLBACK;

/* Q54. This database's tables aren't partitioned, so there is no partition-wise JOIN to force; the equivalent non-partitioned plan is shown instead. */
EXPLAIN (COSTS OFF)
SELECT o.order_id FROM sales.orders o JOIN sales.order_items oi ON oi.order_id = o.order_id LIMIT 10;

/* Q55. */
BEGIN;
CREATE INDEX idx_t09_orders_cust_id ON sales.orders (cust_id);
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE cust_id = 100;
ROLLBACK;

/* Q56. */
BEGIN;
CREATE INDEX idx_t09_orders_covering ON sales.orders (cust_id) INCLUDE (order_date, net_total, order_status);
EXPLAIN ANALYZE SELECT order_date, net_total, order_status FROM sales.orders WHERE cust_id = 100;
ROLLBACK;

/* Q57. */
BEGIN;
CREATE INDEX idx_t09_orders_cust_covering ON sales.orders (cust_id) INCLUDE (net_total);
ROLLBACK;

/* Q58. */
BEGIN;
CREATE INDEX idx_t09_orders_open_partial ON sales.orders (order_status) WHERE order_status IN ('Processing', 'Shipped');
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE order_status = 'Processing';
ROLLBACK;

/* Q59. DATE_TRUNC on a date argument is only STABLE (not IMMUTABLE, PostgreSQL's requirement for index expressions), so the equivalent IMMUTABLE year*100+month bucket expression is indexed instead. */
BEGIN;
CREATE INDEX idx_t09_orders_month_expr ON sales.orders ((EXTRACT(YEAR FROM order_date) * 100 + EXTRACT(MONTH FROM order_date)));
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE (EXTRACT(YEAR FROM order_date) * 100 + EXTRACT(MONTH FROM order_date)) = 202506;
ROLLBACK;

/* Q60. */
BEGIN;
CREATE INDEX idx_t09_orders_date_brin ON sales.orders USING BRIN (order_date);
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE order_date BETWEEN '2025-06-01' AND '2025-06-30';
ROLLBACK;

/* Q61. */
EXPLAIN (COSTS OFF)
SELECT c.customer_id FROM customers.customers c
WHERE NOT EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id);

/* Q62. */
EXPLAIN (COSTS OFF)
SELECT o.* FROM sales.orders o
JOIN (SELECT DISTINCT lm.customer_id FROM loyalty.members lm) m
  ON m.customer_id = o.cust_id;

/* Q63. */
EXPLAIN (COSTS OFF)
SELECT c.customer_id FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id;

/* Q64. */
SELECT c.customer_id, top_orders.order_id, top_orders.net_total
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT o.order_id, o.net_total FROM sales.orders o
  WHERE o.cust_id = c.customer_id
  ORDER BY o.net_total DESC LIMIT 3
) top_orders
WHERE c.customer_id <= 50;

/* Q65. */
EXPLAIN (COSTS OFF)
SELECT o.order_id, c.customer_id
FROM sales.orders o JOIN customers.customers c ON o.cust_id = c.customer_id
ORDER BY o.cust_id;

/* Q66. */
BEGIN;
SET LOCAL work_mem = '128MB';
SELECT order_id, net_total FROM sales.orders ORDER BY net_total DESC LIMIT 100;
ROLLBACK;

/* Q67. */
BEGIN;
CREATE INDEX idx_t09_orders_custid_sort ON sales.orders (cust_id);
EXPLAIN ANALYZE
SELECT o.order_id, c.customer_id FROM sales.orders o JOIN customers.customers c ON o.cust_id = c.customer_id
ORDER BY o.cust_id;
ROLLBACK;

/* Q68. */
ANALYZE sales.orders;

/* Q69. */
BEGIN;
ALTER TABLE sales.orders ALTER COLUMN order_status SET STATISTICS 500;
ANALYZE sales.orders;
ROLLBACK;

/* Q70. */
BEGIN;
CREATE STATISTICS t09_stat_store_status (dependencies) ON store_id, order_status FROM sales.orders;
ANALYZE sales.orders;
ROLLBACK;

/* Q71. */
BEGIN;
SET LOCAL enable_nestloop = off;
EXPLAIN (COSTS OFF)
SELECT o.order_id FROM sales.orders o JOIN customers.customers c ON o.cust_id = c.customer_id;
ROLLBACK;

/* Q72. */
BEGIN;
SET LOCAL enable_hashjoin = off;
EXPLAIN (COSTS OFF)
SELECT o.order_id FROM sales.orders o JOIN customers.customers c ON o.cust_id = c.customer_id;
ROLLBACK;

/* Q73. */
BEGIN;
SET LOCAL random_page_cost = 1.1;
EXPLAIN (COSTS OFF) SELECT * FROM sales.orders WHERE order_id = 5000;
ROLLBACK;

/* Q74. */
BEGIN;
SET LOCAL max_parallel_workers_per_gather = 4;
EXPLAIN (COSTS OFF) SELECT COUNT(*) FROM sales.orders;
ROLLBACK;

/* Q75. Requires the pg_stat_statements extension (not installed in this database), so before/after comparison uses EXPLAIN ANALYZE timings directly instead. */
EXPLAIN ANALYZE SELECT COUNT(*) FROM sales.orders o JOIN sales.order_items oi ON oi.order_id = o.order_id;

/* ============================================================
   SECTION D: MATERIALIZED VIEWS (25)
   All CREATE MATERIALIZED VIEW demos run inside BEGIN...ROLLBACK so
   this shared practice database is left unchanged after testing.
   ------------------------------------------------------------ */
/* Q76. */
BEGIN;
CREATE MATERIALIZED VIEW mv_t09_region_month_revenue AS
SELECT r.region_name, DATE_TRUNC('month', o.order_date) AS month, SUM(o.net_total) AS revenue
FROM sales.orders o JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY r.region_name, DATE_TRUNC('month', o.order_date);
SELECT * FROM mv_t09_region_month_revenue ORDER BY region_name, month LIMIT 20;
ROLLBACK;

/* Q77. */
BEGIN;
CREATE MATERIALIZED VIEW mv_t09_top_products_per_category AS
SELECT category_name, product_name, units_sold FROM (
  SELECT cat.category_name, p.product_name, SUM(oi.quantity) AS units_sold,
         RANK() OVER (PARTITION BY cat.category_name ORDER BY SUM(oi.quantity) DESC) AS rnk
  FROM sales.order_items oi
  JOIN products.products p ON oi.prod_id = p.product_id
  JOIN core.dim_brand b ON p.brand_id = b.brand_id
  JOIN core.dim_category cat ON b.category_id = cat.category_id
  GROUP BY cat.category_name, p.product_name
) ranked WHERE rnk <= 10;
SELECT * FROM mv_t09_top_products_per_category ORDER BY category_name LIMIT 20;
ROLLBACK;

/* Q78. */
BEGIN;
CREATE MATERIALIZED VIEW mv_t09_customer_360 AS
SELECT c.customer_id, c.tier,
       COALESCE(oc.order_count, 0) AS order_count, COALESCE(oc.total_spend, 0) AS total_spend,
       COALESCE(rc.review_count, 0) AS review_count, COALESCE(tc.ticket_count, 0) AS ticket_count
FROM customers.customers c
LEFT JOIN (SELECT cust_id, COUNT(*) AS order_count, SUM(net_total) AS total_spend FROM sales.orders GROUP BY cust_id) oc ON oc.cust_id = c.customer_id
LEFT JOIN (SELECT customer_id, COUNT(*) AS review_count FROM customers.reviews GROUP BY customer_id) rc ON rc.customer_id = c.customer_id
LEFT JOIN (SELECT customer_id, COUNT(*) AS ticket_count FROM support.tickets GROUP BY customer_id) tc ON tc.customer_id = c.customer_id;
SELECT * FROM mv_t09_customer_360 LIMIT 20;
ROLLBACK;

/* Q79. */
BEGIN;
CREATE MATERIALIZED VIEW mv_t09_product_360 AS
SELECT p.product_id, p.product_name,
       COALESCE(SUM(oi.quantity), 0) AS units_sold,
       COALESCE(SUM(oi.net_amount), 0) AS revenue,
       (SELECT COUNT(*) FROM customers.reviews r WHERE r.product_id = p.product_id) AS review_count,
       (SELECT AVG(rating) FROM customers.reviews r WHERE r.product_id = p.product_id) AS avg_rating
FROM products.products p
LEFT JOIN sales.order_items oi ON oi.prod_id = p.product_id
GROUP BY p.product_id, p.product_name;
SELECT * FROM mv_t09_product_360 LIMIT 20;
ROLLBACK;

/* Q80. */
BEGIN;
CREATE MATERIALIZED VIEW mv_t09_store_360 AS
SELECT s.store_id, s.store_name, r.region_name,
       COALESCE(emp.employee_count, 0) AS employee_count,
       COALESCE(ord.order_count, 0) AS order_count, COALESCE(ord.revenue, 0) AS revenue
FROM stores.stores s
JOIN core.dim_region r ON s.region_id = r.region_id
LEFT JOIN (SELECT store_id, COUNT(*) AS employee_count FROM stores.employees GROUP BY store_id) emp ON emp.store_id = s.store_id
LEFT JOIN (SELECT store_id, COUNT(*) AS order_count, SUM(net_total) AS revenue FROM sales.orders GROUP BY store_id) ord ON ord.store_id = s.store_id;
SELECT * FROM mv_t09_store_360 LIMIT 20;
ROLLBACK;

/* Q81. REFRESH ... CONCURRENTLY requires a unique index on the MV and cannot run inside a transaction block, so this is shown as the standalone command a scheduled job would run (not executed here). */
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_t09_region_month_revenue;

/* Q82. Scheduling itself is done outside SQL (cron / pg_cron); the SQL body it would run is the REFRESH statement below. */
-- 0 2 * * * psql -d isct_retailmart -c "REFRESH MATERIALIZED VIEW CONCURRENTLY mv_t09_region_month_revenue;"

/* Q83. */
BEGIN;
CREATE MATERIALIZED VIEW mv_t09_region_month_revenue AS
SELECT r.region_name, DATE_TRUNC('month', o.order_date) AS month, SUM(o.net_total) AS revenue
FROM sales.orders o JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY r.region_name, DATE_TRUNC('month', o.order_date);
CREATE UNIQUE INDEX idx_t09_mv_region_month ON mv_t09_region_month_revenue (region_name, month);
ROLLBACK;

/* Q84. */
BEGIN;
CREATE MATERIALIZED VIEW mv_t09_region_revenue AS
SELECT r.region_name, SUM(o.net_total) AS revenue
FROM sales.orders o JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id GROUP BY r.region_name;
CREATE MATERIALIZED VIEW mv_t09_region_customers AS
SELECT r.region_name, COUNT(DISTINCT c.customer_id) AS customer_count
FROM sales.orders o JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
JOIN customers.customers c ON c.customer_id = o.cust_id
GROUP BY r.region_name;
SELECT rr.region_name, rr.revenue, rc.customer_count
FROM mv_t09_region_revenue rr JOIN mv_t09_region_customers rc ON rr.region_name = rc.region_name;
ROLLBACK;

/* Q85. */
BEGIN;
CREATE MATERIALIZED VIEW mv_t09_region_revenue2 AS
SELECT r.region_name, SUM(o.net_total) AS revenue
FROM sales.orders o JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id GROUP BY r.region_name;
DROP MATERIALIZED VIEW mv_t09_region_revenue2;
CREATE MATERIALIZED VIEW mv_t09_region_revenue2 AS
SELECT r.region_name, SUM(o.net_total) AS revenue, COUNT(*) AS order_count
FROM sales.orders o JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id GROUP BY r.region_name;
ROLLBACK;

/* Q86. An MV is a plain PostgreSQL snapshot refreshed on demand/schedule; TimescaleDB's continuous aggregate is hypertable-specific and refreshes incrementally in the background automatically - RetailMart uses plain PostgreSQL (no TimescaleDB extension), so only manual/scheduled MV refresh is available here. */

/* Q87. An MV persists computed rows in the database (shared across every client, survives app restarts, queryable with SQL/indexes); UI-side caching stores results in the browser/app memory only for one session, is not queryable by other clients, and disappears on reload. */

/* Q88. */
BEGIN;
CREATE MATERIALIZED VIEW mv_t09_empty_shell AS
SELECT r.region_name, SUM(o.net_total) AS revenue
FROM sales.orders o JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id GROUP BY r.region_name
WITH NO DATA;
REFRESH MATERIALIZED VIEW mv_t09_empty_shell;
ROLLBACK;

/* Q89. */
BEGIN;
CREATE MATERIALIZED VIEW mv_t09_base_revenue AS
SELECT r.region_name, SUM(o.net_total) AS revenue
FROM sales.orders o JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id GROUP BY r.region_name;
CREATE MATERIALIZED VIEW mv_t09_top_regions AS
SELECT region_name, revenue FROM mv_t09_base_revenue ORDER BY revenue DESC LIMIT 5;
SELECT * FROM mv_t09_top_regions;
ROLLBACK;

/* Q90. Incremental Materialized View Maintenance is not yet a built-in PostgreSQL 16 feature (the widely-discussed IMMV work is a third-party extension, and native support is still proposed for future releases) - RetailMart's MVs use full REFRESH. */

/* Q91. */
BEGIN;
CREATE TABLE tmp_t09_order_revenue_audit (region_name text, revenue numeric);
CREATE OR REPLACE FUNCTION tmp_t09_recompute_region_revenue() RETURNS trigger AS $$
BEGIN
  DELETE FROM tmp_t09_order_revenue_audit;
  INSERT INTO tmp_t09_order_revenue_audit
  SELECT r.region_name, SUM(o.net_total)
  FROM sales.orders o JOIN stores.stores s ON o.store_id = s.store_id
  JOIN core.dim_region r ON s.region_id = r.region_id GROUP BY r.region_name;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_t09_recompute AFTER INSERT ON sales.orders
FOR EACH STATEMENT EXECUTE FUNCTION tmp_t09_recompute_region_revenue();
ROLLBACK;

/* Q92. RetailMart's fact tables aren't partitioned, so partitioning the MV itself isn't directly supported (materialized views cannot be declared PARTITION BY in PostgreSQL 16) - the workaround is a parent table with partitioned child tables refreshed and swapped in, which is a larger structural change beyond a single MV statement. */

/* Q93. */
SELECT relname, pg_size_pretty(pg_total_relation_size(relid)) AS total_size
FROM pg_catalog.pg_statio_user_tables
WHERE relname LIKE 'orders%'
LIMIT 5;

/* Q94. Staleness is monitored by storing the refresh time as data and comparing it to now(). */
BEGIN;
CREATE MATERIALIZED VIEW mv_t09_region_revenue3 AS
SELECT r.region_name, SUM(o.net_total) AS revenue, NOW() AS refreshed_at
FROM sales.orders o JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id GROUP BY r.region_name;
SELECT region_name, revenue, refreshed_at, NOW() - refreshed_at AS staleness
FROM mv_t09_region_revenue3 LIMIT 5;
ROLLBACK;

/* Q95. PostgreSQL row-level security (RLS) policies can be applied to a materialized view's underlying base tables but NOT to the materialized view itself (RLS on MVs isn't supported) - access must instead be controlled via GRANT/REVOKE on the MV or a wrapping view with its own security_barrier. */

/* Q96. */
BEGIN;
CREATE MATERIALIZED VIEW mv_t09_cross_schema_report AS
SELECT r.region_name, COUNT(DISTINCT e.employee_id) AS employee_count,
       COUNT(DISTINCT o.order_id) AS order_count, SUM(o.net_total) AS revenue
FROM core.dim_region r
LEFT JOIN stores.stores s ON s.region_id = r.region_id
LEFT JOIN stores.employees e ON e.store_id = s.store_id
LEFT JOIN sales.orders o ON o.store_id = s.store_id
GROUP BY r.region_name;
SELECT * FROM mv_t09_cross_schema_report;
ROLLBACK;

/* Q97. RetailMart has no foreign data wrapper (postgres_fdw) configured to another database in this environment, so a cross-database MV cannot be built/tested here; the pattern is CREATE MATERIALIZED VIEW AS SELECT ... FROM foreign_schema.remote_table (via postgres_fdw) exactly like a local table. */

/* Q98. A logical-replication-friendly MV avoids UNLOGGED tables/temp objects and instead uses a normal (WAL-logged) materialized view, refreshed with REFRESH MATERIALIZED VIEW CONCURRENTLY so downstream replicas/read-replicas that subscribe to the publication receive consistent, non-blocking updates. */

/* Q99. */
BEGIN;
CREATE MATERIALIZED VIEW mv_t09_adhoc_exec AS
SELECT
  (SELECT COUNT(*) FROM sales.orders) AS total_orders,
  (SELECT SUM(net_total) FROM sales.orders) AS total_revenue,
  (SELECT COUNT(*) FROM customers.customers) AS total_customers;
SELECT * FROM mv_t09_adhoc_exec;
ROLLBACK;

/* Q100. */
BEGIN;
CREATE MATERIALIZED VIEW mv_t09_facts AS
SELECT o.order_id, o.cust_id, o.store_id, o.order_date, o.net_total, o.order_status FROM sales.orders o;
CREATE MATERIALIZED VIEW mv_t09_daily AS
SELECT order_date AS day, SUM(net_total) AS revenue, COUNT(*) AS order_count FROM mv_t09_facts GROUP BY order_date;
CREATE MATERIALIZED VIEW mv_t09_weekly AS
SELECT DATE_TRUNC('week', day) AS week, SUM(revenue) AS revenue, SUM(order_count) AS order_count FROM mv_t09_daily GROUP BY DATE_TRUNC('week', day);
CREATE MATERIALIZED VIEW mv_t09_monthly AS
SELECT DATE_TRUNC('month', week) AS month, SUM(revenue) AS revenue, SUM(order_count) AS order_count FROM mv_t09_weekly GROUP BY DATE_TRUNC('month', week);
CREATE MATERIALIZED VIEW mv_t09_exec AS
SELECT month, revenue, order_count, revenue / NULLIF(order_count, 0) AS aov FROM mv_t09_monthly;
SELECT * FROM mv_t09_exec ORDER BY month;
ROLLBACK;

/* ============================================================
   END OF ANSWER KEY - JOINs Part 1 (Foundations) - CRAZY LEVEL (100/100)
============================================================ */
