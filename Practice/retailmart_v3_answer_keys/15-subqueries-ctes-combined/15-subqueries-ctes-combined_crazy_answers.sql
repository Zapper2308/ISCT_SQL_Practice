/* ============================================================
   ANSWER KEY - Subqueries + CTEs Combined (CRAZY LEVEL)
   Curriculum:   RetailMart V3
   Note: "N metrics" / "50 KPIs" style prompts are answered with a
   representative, genuinely-joined multi-source report rather than
   padded to a literal metric count. Where a prompt names a structure
   RetailMart has no data for (subscriptions, A/B tests, permissions,
   referral trees, DML against the shared live database), the answer
   is a short conceptual note instead of an invented/unsafe query.
   ============================================================ */

/* SECTION A: MULTI-DOMAIN MEGA (25) */

/* Q1. */
WITH order_stats AS (SELECT cust_id, COUNT(*) AS orders, SUM(net_total) AS revenue, MAX(order_date) AS last_order FROM sales.orders WHERE order_status NOT IN ('Cancelled','Failed') GROUP BY cust_id),
review_stats AS (SELECT customer_id, COUNT(*) AS reviews, AVG(rating) AS avg_rating FROM customers.reviews GROUP BY customer_id),
ticket_stats AS (SELECT customer_id, COUNT(*) AS tickets FROM support.tickets GROUP BY customer_id),
call_stats AS (SELECT customer_id, COUNT(*) AS calls FROM call_center.calls GROUP BY customer_id),
loyalty_stats AS (SELECT customer_id, points_balance FROM loyalty.members),
wallet_stats AS (SELECT cust_id, balance FROM customers.wallets),
web_stats AS (SELECT customer_id, COUNT(*) AS page_views FROM web_events.page_views WHERE customer_id IS NOT NULL GROUP BY customer_id)
SELECT c.customer_id, c.first_name, c.last_name, c.tier, c.registration_date,
       COALESCE(o.orders,0) AS orders, COALESCE(o.revenue,0) AS revenue, o.last_order,
       COALESCE(r.reviews,0) AS reviews, r.avg_rating,
       COALESCE(t.tickets,0) AS tickets, COALESCE(cl.calls,0) AS calls,
       l.points_balance, w.balance AS wallet_balance, COALESCE(wb.page_views,0) AS page_views
FROM customers.customers c
LEFT JOIN order_stats o ON o.cust_id = c.customer_id
LEFT JOIN review_stats r ON r.customer_id = c.customer_id
LEFT JOIN ticket_stats t ON t.customer_id = c.customer_id
LEFT JOIN call_stats cl ON cl.customer_id = c.customer_id
LEFT JOIN loyalty_stats l ON l.customer_id = c.customer_id
LEFT JOIN wallet_stats w ON w.cust_id = c.customer_id
LEFT JOIN web_stats wb ON wb.customer_id = c.customer_id
ORDER BY o.revenue DESC NULLS LAST
LIMIT 25;

/* Q2. */
WITH sales_stats AS (SELECT prod_id, SUM(quantity) AS units_sold, SUM(net_amount) AS revenue FROM sales.order_items GROUP BY prod_id),
review_stats AS (SELECT product_id, COUNT(*) AS reviews, AVG(rating) AS avg_rating FROM customers.reviews GROUP BY product_id),
inv_stats AS (SELECT product_id, SUM(quantity_on_hand) AS total_stock FROM products.inventory GROUP BY product_id),
return_stats AS (SELECT prod_id, COUNT(*) AS returns, SUM(refund_amount) AS refunded FROM sales.returns GROUP BY prod_id),
production_stats AS (SELECT product_id, SUM(quantity_produced) AS produced, SUM(rejected_quantity) AS rejected FROM manufacture.work_orders GROUP BY product_id)
SELECT p.product_id, p.product_name, b.brand_name, cat.category_name, s.supplier_name,
       COALESCE(ss.units_sold,0) AS units_sold, COALESCE(ss.revenue,0) AS revenue,
       COALESCE(rs.reviews,0) AS reviews, rs.avg_rating,
       COALESCE(iv.total_stock,0) AS total_stock,
       COALESCE(rt.returns,0) AS returns, COALESCE(rt.refunded,0) AS refunded,
       COALESCE(pr.produced,0) AS produced, COALESCE(pr.rejected,0) AS rejected
FROM products.products p
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
JOIN products.suppliers s ON s.supplier_id = p.supplier_id
LEFT JOIN sales_stats ss ON ss.prod_id = p.product_id
LEFT JOIN review_stats rs ON rs.product_id = p.product_id
LEFT JOIN inv_stats iv ON iv.product_id = p.product_id
LEFT JOIN return_stats rt ON rt.prod_id = p.product_id
LEFT JOIN production_stats pr ON pr.product_id = p.product_id
ORDER BY ss.revenue DESC NULLS LAST
LIMIT 25;

/* Q3. */
WITH order_stats AS (SELECT store_id, COUNT(*) AS orders, SUM(net_total) AS revenue FROM sales.orders WHERE order_status NOT IN ('Cancelled','Failed') GROUP BY store_id),
emp_stats AS (SELECT store_id, COUNT(*) AS headcount, AVG(salary) AS avg_salary FROM stores.employees GROUP BY store_id),
exp_stats AS (SELECT store_id, SUM(amount) AS total_expenses FROM stores.expenses GROUP BY store_id),
inv_stats AS (SELECT store_id, SUM(quantity_on_hand) AS total_stock FROM products.inventory GROUP BY store_id),
delivery_stats AS (
  SELECT o.store_id, ROUND(AVG(sh.delivered_date - sh.shipped_date), 2) AS avg_delivery_days
  FROM sales.orders o JOIN sales.shipments sh ON sh.order_id = o.order_id
  WHERE sh.delivered_date IS NOT NULL GROUP BY o.store_id
)
SELECT s.store_id, s.store_name, r.region_name,
       COALESCE(o.orders,0) AS orders, COALESCE(o.revenue,0) AS revenue,
       COALESCE(e.headcount,0) AS headcount, ROUND(e.avg_salary,2) AS avg_salary,
       COALESCE(x.total_expenses,0) AS total_expenses, COALESCE(i.total_stock,0) AS total_stock,
       d.avg_delivery_days
FROM stores.stores s
JOIN core.dim_region r ON r.region_id = s.region_id
LEFT JOIN order_stats o ON o.store_id = s.store_id
LEFT JOIN emp_stats e ON e.store_id = s.store_id
LEFT JOIN exp_stats x ON x.store_id = s.store_id
LEFT JOIN inv_stats i ON i.store_id = s.store_id
LEFT JOIN delivery_stats d ON d.store_id = s.store_id
ORDER BY o.revenue DESC NULLS LAST
LIMIT 25;

/* Q4. */
WITH order_stats AS (
  SELECT s.region_id, COUNT(*) AS orders, SUM(o.net_total) AS revenue
  FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id
  WHERE o.order_status NOT IN ('Cancelled','Failed') GROUP BY s.region_id
),
store_stats AS (SELECT region_id, COUNT(*) AS store_count FROM stores.stores GROUP BY region_id),
emp_stats AS (SELECT s.region_id, COUNT(*) AS headcount FROM stores.employees e JOIN stores.stores s ON s.store_id = e.store_id GROUP BY s.region_id),
warehouse_stats AS (SELECT region, COUNT(*) AS warehouse_count, SUM(capacity_sqft) AS total_capacity FROM supply_chain.warehouses GROUP BY region)
SELECT r.region_id, r.region_name,
       COALESCE(st.store_count,0) AS store_count, COALESCE(e.headcount,0) AS headcount,
       COALESCE(o.orders,0) AS orders, COALESCE(o.revenue,0) AS revenue,
       COALESCE(w.warehouse_count,0) AS warehouse_count, COALESCE(w.total_capacity,0) AS total_warehouse_capacity
FROM core.dim_region r
LEFT JOIN order_stats o ON o.region_id = r.region_id
LEFT JOIN store_stats st ON st.region_id = r.region_id
LEFT JOIN emp_stats e ON e.region_id = r.region_id
LEFT JOIN warehouse_stats w ON w.region = r.region_name
ORDER BY o.revenue DESC NULLS LAST;

/* Q5. */
WITH spend AS (SELECT campaign_id, SUM(amount) AS total_spend FROM marketing.ads_spend GROUP BY campaign_id),
clicks AS (SELECT campaign_id, SUM(emails_sent) AS sent, SUM(emails_opened) AS opened, SUM(emails_clicked) AS clicked FROM marketing.email_clicks GROUP BY campaign_id),
revenue AS (
  SELECT c.campaign_id, SUM(o.net_total) AS revenue, COUNT(DISTINCT o.cust_id) AS customers
  FROM marketing.campaigns c JOIN sales.orders o ON o.order_date BETWEEN c.start_date AND c.end_date AND o.order_status NOT IN ('Cancelled','Failed')
  GROUP BY c.campaign_id
)
SELECT c.campaign_id, c.campaign_name, c.budget, c.start_date, c.end_date,
       COALESCE(s.total_spend,0) AS total_spend, COALESCE(cl.sent,0) AS emails_sent,
       COALESCE(cl.clicked,0) AS emails_clicked, COALESCE(r.revenue,0) AS attributed_revenue,
       COALESCE(r.customers,0) AS customers_during_window
FROM marketing.campaigns c
LEFT JOIN spend s ON s.campaign_id = c.campaign_id
LEFT JOIN clicks cl ON cl.campaign_id = c.campaign_id
LEFT JOIN revenue r ON r.campaign_id = c.campaign_id
ORDER BY attributed_revenue DESC NULLS LAST
LIMIT 25;

/* Q6. */
WITH prod_stats AS (SELECT supplier_id, COUNT(*) AS product_count, ROUND(AVG(price),2) AS avg_price FROM products.products GROUP BY supplier_id),
sales_stats AS (SELECT p.supplier_id, SUM(oi.quantity) AS units_sold, SUM(oi.net_amount) AS revenue FROM sales.order_items oi JOIN products.products p ON p.product_id = oi.prod_id GROUP BY p.supplier_id),
shipment_stats AS (SELECT supplier_id, COUNT(*) AS shipments, SUM(quantity) AS total_shipped FROM supply_chain.shipments GROUP BY supplier_id)
SELECT s.supplier_id, s.supplier_name, s.city,
       COALESCE(ps.product_count,0) AS product_count, ps.avg_price,
       COALESCE(ss.units_sold,0) AS units_sold, COALESCE(ss.revenue,0) AS revenue,
       COALESCE(sh.shipments,0) AS shipments, COALESCE(sh.total_shipped,0) AS total_shipped
FROM products.suppliers s
LEFT JOIN prod_stats ps ON ps.supplier_id = s.supplier_id
LEFT JOIN sales_stats ss ON ss.supplier_id = s.supplier_id
LEFT JOIN shipment_stats sh ON sh.supplier_id = s.supplier_id
ORDER BY ss.revenue DESC NULLS LAST
LIMIT 25;

/* Q7. */
WITH prod_stats AS (SELECT brand_id, COUNT(*) AS product_count FROM products.products GROUP BY brand_id),
sales_stats AS (SELECT p.brand_id, SUM(oi.quantity) AS units_sold, SUM(oi.net_amount) AS revenue FROM sales.order_items oi JOIN products.products p ON p.product_id = oi.prod_id GROUP BY p.brand_id),
review_stats AS (SELECT p.brand_id, AVG(r.rating) AS avg_rating, COUNT(*) AS reviews FROM customers.reviews r JOIN products.products p ON p.product_id = r.product_id GROUP BY p.brand_id)
SELECT b.brand_id, b.brand_name, cat.category_name,
       COALESCE(ps.product_count,0) AS product_count, COALESCE(ss.units_sold,0) AS units_sold,
       COALESCE(ss.revenue,0) AS revenue, ROUND(rv.avg_rating,2) AS avg_rating, COALESCE(rv.reviews,0) AS reviews
FROM core.dim_brand b
JOIN core.dim_category cat ON cat.category_id = b.category_id
LEFT JOIN prod_stats ps ON ps.brand_id = b.brand_id
LEFT JOIN sales_stats ss ON ss.brand_id = b.brand_id
LEFT JOIN review_stats rv ON rv.brand_id = b.brand_id
ORDER BY ss.revenue DESC NULLS LAST
LIMIT 25;

/* Q8. */
WITH order_stats AS (SELECT c.tier, COUNT(*) AS orders, SUM(o.net_total) AS revenue FROM sales.orders o JOIN customers.customers c ON c.customer_id = o.cust_id WHERE o.order_status NOT IN ('Cancelled','Failed') GROUP BY c.tier),
review_stats AS (SELECT c.tier, AVG(r.rating) AS avg_rating FROM customers.reviews r JOIN customers.customers c ON c.customer_id = r.customer_id GROUP BY c.tier),
loyalty_stats AS (SELECT t.tier_name, AVG(m.points_balance) AS avg_points FROM loyalty.members m JOIN loyalty.tiers t ON t.tier_id = m.tier_id GROUP BY t.tier_name)
SELECT c.tier, COUNT(*) AS customers, COALESCE(o.orders,0) AS orders, COALESCE(o.revenue,0) AS revenue,
       ROUND(rv.avg_rating,2) AS avg_rating, ROUND(l.avg_points,2) AS avg_points
FROM customers.customers c
LEFT JOIN order_stats o ON o.tier = c.tier
LEFT JOIN review_stats rv ON rv.tier = c.tier
LEFT JOIN loyalty_stats l ON l.tier_name = c.tier
GROUP BY c.tier, o.orders, o.revenue, rv.avg_rating, l.avg_points
ORDER BY revenue DESC NULLS LAST;

/* Q9. */
WITH call_stats AS (SELECT agent_id, COUNT(*) AS calls, ROUND(AVG(call_duration_seconds),2) AS avg_duration FROM call_center.calls GROUP BY agent_id),
sentiment_stats AS (SELECT c.agent_id, ROUND(AVG(t.sentiment_score),3) AS avg_sentiment FROM call_center.calls c JOIN call_center.transcripts t ON t.call_id = c.call_id GROUP BY c.agent_id),
ticket_stats AS (SELECT agent_id, COUNT(*) AS tickets, COUNT(*) FILTER (WHERE status IN ('Resolved','Closed')) AS resolved FROM support.tickets GROUP BY agent_id)
SELECT c.agent_id, c.calls, c.avg_duration, s.avg_sentiment, COALESCE(t.tickets,0) AS tickets, COALESCE(t.resolved,0) AS resolved
FROM call_stats c
LEFT JOIN sentiment_stats s ON s.agent_id = c.agent_id
LEFT JOIN ticket_stats t ON t.agent_id = c.agent_id
ORDER BY c.calls DESC
LIMIT 25;

/* Q10. */
SELECT courier_name, COUNT(*) AS shipments,
       ROUND(AVG(delivered_date - shipped_date),2) AS avg_delivery_days,
       COUNT(*) FILTER (WHERE status = 'Delivered') AS delivered,
       COUNT(*) FILTER (WHERE status = 'Returned') AS returned
FROM sales.shipments
GROUP BY courier_name
ORDER BY shipments DESC;

/* Q11. */
WITH ship_stats AS (SELECT warehouse_id, COUNT(*) AS shipments, SUM(quantity) AS total_quantity FROM supply_chain.shipments GROUP BY warehouse_id),
snapshot_stats AS (SELECT warehouse_id, SUM(quantity_on_hand) AS current_stock FROM supply_chain.inventory_snapshots WHERE snapshot_date = (SELECT MAX(snapshot_date) FROM supply_chain.inventory_snapshots) GROUP BY warehouse_id)
SELECT w.warehouse_id, w.name, w.region, w.capacity_sqft, w.manager_name,
       COALESCE(s.shipments,0) AS shipments, COALESCE(s.total_quantity,0) AS total_shipped,
       COALESCE(sn.current_stock,0) AS current_stock,
       ROUND(100.0 * COALESCE(sn.current_stock,0) / NULLIF(w.capacity_sqft,0), 2) AS pct_capacity_used
FROM supply_chain.warehouses w
LEFT JOIN ship_stats s ON s.warehouse_id = w.warehouse_id
LEFT JOIN snapshot_stats sn ON sn.warehouse_id = w.warehouse_id
ORDER BY w.warehouse_id;

/* Q12. */
WITH emp_stats AS (SELECT dept_id, COUNT(*) AS headcount, ROUND(AVG(salary),2) AS avg_salary FROM stores.employees GROUP BY dept_id),
att_stats AS (SELECT e.dept_id, COUNT(*) AS attendance_records FROM hr.attendance a JOIN stores.employees e ON e.employee_id = a.employee_id GROUP BY e.dept_id)
SELECT d.dept_id, d.dept_name, COALESCE(e.headcount,0) AS headcount, e.avg_salary, COALESCE(a.attendance_records,0) AS attendance_records
FROM core.dim_department d
LEFT JOIN emp_stats e ON e.dept_id = d.dept_id
LEFT JOIN att_stats a ON a.dept_id = d.dept_id
ORDER BY headcount DESC NULLS LAST;

/* Q13. */
WITH att_stats AS (SELECT employee_id, COUNT(*) AS days_recorded FROM hr.attendance GROUP BY employee_id),
pay_stats AS (SELECT employee_id, ROUND(AVG(net_salary),2) AS avg_net_salary FROM payroll.pay_slips GROUP BY employee_id)
SELECT e.employee_id, e.first_name, e.last_name, e.role, e.salary, s.store_name, d.dept_name,
       COALESCE(a.days_recorded,0) AS days_recorded, p.avg_net_salary
FROM stores.employees e
JOIN stores.stores s ON s.store_id = e.store_id
JOIN core.dim_department d ON d.dept_id = e.dept_id
LEFT JOIN att_stats a ON a.employee_id = e.employee_id
LEFT JOIN pay_stats p ON p.employee_id = e.employee_id
ORDER BY e.salary DESC
LIMIT 25;

/* Q14. */
WITH sales_stats AS (
  SELECT b.category_id, SUM(oi.net_amount) AS revenue, SUM(oi.quantity) AS units_sold
  FROM sales.order_items oi JOIN products.products p ON p.product_id = oi.prod_id JOIN core.dim_brand b ON b.brand_id = p.brand_id
  GROUP BY b.category_id
),
review_stats AS (
  SELECT b.category_id, AVG(r.rating) AS avg_rating
  FROM customers.reviews r JOIN products.products p ON p.product_id = r.product_id JOIN core.dim_brand b ON b.brand_id = p.brand_id
  GROUP BY b.category_id
),
prod_count AS (SELECT b.category_id, COUNT(*) AS product_count FROM products.products p JOIN core.dim_brand b ON b.brand_id = p.brand_id GROUP BY b.category_id)
SELECT cat.category_id, cat.category_name, COALESCE(pc.product_count,0) AS product_count,
       COALESCE(ss.units_sold,0) AS units_sold, COALESCE(ss.revenue,0) AS revenue, ROUND(rv.avg_rating,2) AS avg_rating
FROM core.dim_category cat
LEFT JOIN sales_stats ss ON ss.category_id = cat.category_id
LEFT JOIN review_stats rv ON rv.category_id = cat.category_id
LEFT JOIN prod_count pc ON pc.category_id = cat.category_id
ORDER BY ss.revenue DESC NULLS LAST;

/* Q15. */
SELECT payment_mode AS channel, COUNT(*) AS payments, ROUND(SUM(amount),2) AS total_amount, ROUND(AVG(amount),2) AS avg_amount
FROM sales.payments
GROUP BY payment_mode
ORDER BY total_amount DESC;

/* Q16. */
SELECT r.country, r.state, COUNT(DISTINCT a.customer_id) AS customers, COUNT(DISTINCT s.store_id) AS stores,
       ROUND(SUM(o.net_total), 2) AS revenue
FROM core.dim_region r
LEFT JOIN customers.addresses a ON a.state = r.state AND a.is_default = true
LEFT JOIN stores.stores s ON s.region_id = r.region_id
LEFT JOIN sales.orders o ON o.cust_id = a.customer_id AND o.order_status NOT IN ('Cancelled','Failed')
GROUP BY r.country, r.state
ORDER BY revenue DESC NULLS LAST
LIMIT 25;

/* Q17. */
WITH member_stats AS (SELECT tier_id, COUNT(*) AS members, ROUND(AVG(points_balance),2) AS avg_points FROM loyalty.members GROUP BY tier_id),
redemption_stats AS (SELECT m.tier_id, COUNT(*) AS redemptions, SUM(rd.points_redeemed) AS points_redeemed
  FROM loyalty.redemptions rd JOIN loyalty.members m ON m.customer_id = rd.customer_id GROUP BY m.tier_id)
SELECT t.tier_id, t.tier_name, t.min_points, t.max_points,
       COALESCE(m.members,0) AS members, m.avg_points,
       COALESCE(r.redemptions,0) AS redemptions, COALESCE(r.points_redeemed,0) AS points_redeemed
FROM loyalty.tiers t
LEFT JOIN member_stats m ON m.tier_id = t.tier_id
LEFT JOIN redemption_stats r ON r.tier_id = t.tier_id
ORDER BY t.min_points;

/* Q18. RetailMart has no subscription/plan table, so there is no subscription 360 view to build - it models one-off orders, not recurring plans. */

/* Q19. */
SELECT session_id, MIN(customer_id) AS customer_id, COUNT(*) AS page_views,
       COUNT(DISTINCT page_url) AS unique_pages,
       MIN(view_timestamp) AS session_start, MAX(view_timestamp) AS session_end,
       MODE() WITHIN GROUP (ORDER BY device_type) AS device_type
FROM web_events.page_views
GROUP BY session_id
ORDER BY page_views DESC
LIMIT 25;

/* Q20. */
WITH resolution AS (SELECT ticket_id, resolved_date - created_date AS resolution_time FROM support.tickets WHERE resolved_date IS NOT NULL)
SELECT t.ticket_id, t.customer_id, t.agent_id, t.category, t.priority, t.status,
       t.created_date, t.resolved_date, r.resolution_time
FROM support.tickets t
LEFT JOIN resolution r ON r.ticket_id = t.ticket_id
ORDER BY t.created_date DESC
LIMIT 25;

/* Q21. */
SELECT c.call_id, c.customer_id, c.agent_id, c.call_start_time, c.call_duration_seconds, c.call_reason, c.status,
       t.sentiment_score
FROM call_center.calls c
LEFT JOIN call_center.transcripts t ON t.call_id = c.call_id
ORDER BY c.call_start_time DESC
LIMIT 25;

/* Q22. */
SELECT r.return_id, r.order_id, r.prod_id, p.product_name, r.return_date, r.reason, r.refund_amount,
       o.cust_id, o.order_date
FROM sales.returns r
JOIN products.products p ON p.product_id = r.prod_id
JOIN sales.orders o ON o.order_id = r.order_id
ORDER BY r.return_date DESC
LIMIT 25;

/* Q23. */
SELECT fp.payment_id, fp.order_id, fp.cust_id, fp.amount, fp.status, fp.refund_reason, fp.refunded_at
FROM finance.payments fp
WHERE fp.status = 'Refunded'
ORDER BY fp.refunded_at DESC
LIMIT 25;

/* Q24. */
SELECT 'record_changes' AS source, COUNT(*) AS row_count FROM audit.record_changes
UNION ALL
SELECT 'procedure_calls', COUNT(*) FROM audit.procedure_calls
UNION ALL
SELECT 'api_requests', COUNT(*) FROM audit.api_requests
UNION ALL
SELECT 'application_logs', COUNT(*) FROM audit.application_logs
UNION ALL
SELECT 'refund_log', COUNT(*) FROM audit.refund_log
UNION ALL
SELECT 'refund_failures', COUNT(*) FROM audit.refund_failures;

/* Q25. */
SELECT 'orphan_order_items' AS check_name, COUNT(*) AS flagged_rows
FROM sales.order_items oi WHERE NOT EXISTS (SELECT 1 FROM sales.orders o WHERE o.order_id = oi.order_id)
UNION ALL
SELECT 'orders_without_payment', COUNT(*) FROM sales.orders o WHERE NOT EXISTS (SELECT 1 FROM sales.payments p WHERE p.order_id = o.order_id)
UNION ALL
SELECT 'negative_quantities', COUNT(*) FROM sales.order_items WHERE quantity <= 0
UNION ALL
SELECT 'orders_null_customer', COUNT(*) FROM sales.orders WHERE cust_id IS NULL
UNION ALL
SELECT 'procedure_call_errors', COUNT(*) FROM audit.procedure_calls WHERE outcome <> 'Success'
UNION ALL
SELECT 'failed_api_requests', COUNT(*) FROM audit.api_requests WHERE status_code >= 400;

/* SECTION B: COHORT / RFM / NPS MEGA (25) */

/* Q26. */
WITH cohorts AS (SELECT customer_id, DATE_TRUNC('month', registration_date) AS cohort_month FROM customers.customers),
cohort_size AS (SELECT cohort_month, COUNT(*) AS customers FROM cohorts GROUP BY cohort_month),
activity AS (
  SELECT c.cohort_month,
         (DATE_PART('year', o.order_date) - DATE_PART('year', c.cohort_month)) * 12
           + (DATE_PART('month', o.order_date) - DATE_PART('month', c.cohort_month)) AS month_offset,
         COUNT(DISTINCT o.cust_id) AS active_customers
  FROM cohorts c JOIN sales.orders o ON o.cust_id = c.customer_id
  GROUP BY c.cohort_month, 2
)
SELECT a.cohort_month, a.month_offset, a.active_customers, s.customers,
       ROUND(100.0 * a.active_customers / s.customers, 2) AS retention_pct
FROM activity a JOIN cohort_size s ON s.cohort_month = a.cohort_month
WHERE a.month_offset BETWEEN 0 AND 24
ORDER BY a.cohort_month, a.month_offset;

/* Q27. */
WITH first_order AS (SELECT cust_id, MIN(DATE_TRUNC('month', order_date)) AS cohort_month FROM sales.orders GROUP BY cust_id),
cohort_size AS (SELECT cohort_month, COUNT(*) AS customers FROM first_order GROUP BY cohort_month),
revenue_by_offset AS (
  SELECT f.cohort_month,
         (DATE_PART('year', o.order_date) - DATE_PART('year', f.cohort_month)) * 12
           + (DATE_PART('month', o.order_date) - DATE_PART('month', f.cohort_month)) AS month_offset,
         SUM(o.net_total) AS revenue
  FROM first_order f JOIN sales.orders o ON o.cust_id = f.cust_id
  WHERE o.order_status NOT IN ('Cancelled','Failed')
  GROUP BY f.cohort_month, 2
)
SELECT r.cohort_month, r.month_offset,
       SUM(r.revenue) OVER (PARTITION BY r.cohort_month ORDER BY r.month_offset) / s.customers AS cumulative_ltv
FROM revenue_by_offset r
JOIN cohort_size s ON s.cohort_month = r.cohort_month
WHERE r.month_offset BETWEEN 0 AND 24
ORDER BY r.cohort_month, r.month_offset;

/* Q28. */
WITH cust_metrics AS (
  SELECT c.customer_id,
         (SELECT MAX(order_date) FROM sales.orders) - MAX(o.order_date) AS recency_days,
         COUNT(o.order_id) AS frequency, COALESCE(SUM(o.net_total), 0) AS monetary
  FROM customers.customers c
  LEFT JOIN sales.orders o ON o.cust_id = c.customer_id AND o.order_status NOT IN ('Cancelled','Failed')
  GROUP BY c.customer_id
),
scored AS (
  SELECT customer_id,
         NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,
         NTILE(5) OVER (ORDER BY frequency DESC) AS f_score,
         NTILE(5) OVER (ORDER BY monetary DESC) AS m_score
  FROM cust_metrics
)
SELECT customer_id, r_score, f_score, m_score,
       r_score::text || '-' || f_score::text || '-' || m_score::text AS rfm_code,
       CASE WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champion'
            WHEN f_score >= 4 AND m_score >= 4 THEN 'Loyal'
            WHEN r_score >= 4 AND f_score <= 2 THEN 'New'
            WHEN r_score <= 2 AND f_score >= 3 THEN 'At-Risk'
            WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost'
            ELSE 'Needs Attention' END AS segment_name
FROM scored
ORDER BY customer_id
LIMIT 50;

/* Q29. */
WITH recent_spend AS (
  SELECT cust_id, SUM(net_total) AS spend FROM sales.orders
  WHERE order_status NOT IN ('Cancelled','Failed') AND order_date >= (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '6 months'
  GROUP BY cust_id
),
prior_spend AS (
  SELECT cust_id, SUM(net_total) AS spend FROM sales.orders
  WHERE order_status NOT IN ('Cancelled','Failed')
    AND order_date < (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '6 months'
    AND order_date >= (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '12 months'
  GROUP BY cust_id
),
recent_q AS (SELECT cust_id, NTILE(5) OVER (ORDER BY spend DESC) AS q FROM recent_spend),
prior_q AS (SELECT cust_id, NTILE(5) OVER (ORDER BY spend DESC) AS q FROM prior_spend)
SELECT p.q AS prior_rfm_bucket, r.q AS current_rfm_bucket, COUNT(*) AS customers
FROM prior_q p JOIN recent_q r ON r.cust_id = p.cust_id
GROUP BY p.q, r.q
ORDER BY p.q, r.q;

/* Q30. */
WITH cust_metrics AS (
  SELECT c.customer_id,
         (SELECT MAX(order_date) FROM sales.orders) - MAX(o.order_date) AS recency_days,
         COUNT(o.order_id) AS frequency, COALESCE(SUM(o.net_total), 0) AS monetary
  FROM customers.customers c
  LEFT JOIN sales.orders o ON o.cust_id = c.customer_id AND o.order_status NOT IN ('Cancelled','Failed')
  GROUP BY c.customer_id
),
scored AS (
  SELECT customer_id, monetary,
         CASE WHEN NTILE(5) OVER (ORDER BY recency_days ASC) >= 4 AND NTILE(5) OVER (ORDER BY frequency DESC) >= 4 THEN 'Champion'
              ELSE 'Other' END AS segment_name
  FROM cust_metrics
)
SELECT segment_name, COUNT(*) AS customers, ROUND(SUM(monetary), 2) AS segment_revenue
FROM scored
GROUP BY segment_name
ORDER BY segment_revenue DESC;

/* Q31. */
WITH review_region AS (
  SELECT r.rating, c.tier, rg.region_name, b.brand_name, DATE_TRUNC('month', r.review_date) AS month
  FROM customers.reviews r
  JOIN customers.customers c ON c.customer_id = r.customer_id
  JOIN products.products p ON p.product_id = r.product_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  LEFT JOIN customers.addresses a ON a.customer_id = r.customer_id AND a.is_default = true
  LEFT JOIN core.dim_region rg ON rg.state = a.state
)
SELECT 'tier' AS dimension, tier AS value, ROUND(100.0 * (COUNT(*) FILTER (WHERE rating = 5) - COUNT(*) FILTER (WHERE rating <= 3)) / COUNT(*), 2) AS nps
FROM review_region GROUP BY tier
UNION ALL
SELECT 'region', region_name, ROUND(100.0 * (COUNT(*) FILTER (WHERE rating = 5) - COUNT(*) FILTER (WHERE rating <= 3)) / COUNT(*), 2)
FROM review_region GROUP BY region_name
UNION ALL
SELECT 'brand', brand_name, ROUND(100.0 * (COUNT(*) FILTER (WHERE rating = 5) - COUNT(*) FILTER (WHERE rating <= 3)) / COUNT(*), 2)
FROM review_region GROUP BY brand_name
ORDER BY dimension, nps DESC
LIMIT 40;

/* Q32. */
SELECT DATE_TRUNC('month', review_date) AS month,
       ROUND(100.0 * (COUNT(*) FILTER (WHERE rating = 5) - COUNT(*) FILTER (WHERE rating <= 3)) / COUNT(*), 2) AS nps
FROM customers.reviews
GROUP BY 1
ORDER BY 1;

/* Q33. */
SELECT DATE_PART('year', review_date) AS year,
       ROUND(100.0 * (COUNT(*) FILTER (WHERE rating = 5) - COUNT(*) FILTER (WHERE rating <= 3)) / COUNT(*), 2) AS nps
FROM customers.reviews
GROUP BY 1
ORDER BY 1;

/* Q34. */
WITH review_region AS (
  SELECT r.rating, c.tier, rg.region_name, b.brand_name
  FROM customers.reviews r
  JOIN customers.customers c ON c.customer_id = r.customer_id
  JOIN products.products p ON p.product_id = r.product_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  LEFT JOIN customers.addresses a ON a.customer_id = r.customer_id AND a.is_default = true
  LEFT JOIN core.dim_region rg ON rg.state = a.state
)
SELECT 'tier' AS dimension, tier AS value, ROUND(100.0 * COUNT(*) FILTER (WHERE rating >= 4) / COUNT(*), 2) AS csat_pct
FROM review_region GROUP BY tier
UNION ALL
SELECT 'region', region_name, ROUND(100.0 * COUNT(*) FILTER (WHERE rating >= 4) / COUNT(*), 2)
FROM review_region GROUP BY region_name
UNION ALL
SELECT 'brand', brand_name, ROUND(100.0 * COUNT(*) FILTER (WHERE rating >= 4) / COUNT(*), 2)
FROM review_region GROUP BY brand_name
ORDER BY dimension, csat_pct ASC
LIMIT 40;

/* Q35. */
SELECT p.product_id, p.product_name, b.brand_name, COUNT(*) AS review_count,
       ROUND(AVG(r.rating), 2) AS avg_rating,
       COUNT(*) FILTER (WHERE r.rating <= 2) AS low_ratings
FROM customers.reviews r
JOIN products.products p ON p.product_id = r.product_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
GROUP BY p.product_id, p.product_name, b.brand_name
HAVING COUNT(*) >= 5
ORDER BY avg_rating ASC
LIMIT 20;

/* Q36. */
WITH cohorts AS (SELECT customer_id, DATE_TRUNC('month', registration_date) AS cohort_month FROM customers.customers),
visits AS (SELECT DISTINCT customer_id FROM web_events.page_views WHERE customer_id IS NOT NULL),
orders AS (SELECT DISTINCT cust_id FROM sales.orders)
SELECT c.cohort_month,
       COUNT(*) FILTER (WHERE v.customer_id IS NOT NULL) AS visited,
       COUNT(*) FILTER (WHERE o.cust_id IS NOT NULL) AS ordered
FROM cohorts c
LEFT JOIN visits v ON v.customer_id = c.customer_id
LEFT JOIN orders o ON o.cust_id = c.customer_id
GROUP BY c.cohort_month
ORDER BY c.cohort_month;

/* Q37. */
WITH visits AS (SELECT DISTINCT customer_id FROM web_events.page_views WHERE customer_id IS NOT NULL),
orders AS (SELECT DISTINCT cust_id FROM sales.orders)
SELECT c.tier,
       COUNT(*) FILTER (WHERE v.customer_id IS NOT NULL) AS visited,
       COUNT(*) FILTER (WHERE o.cust_id IS NOT NULL) AS ordered,
       ROUND(100.0 * COUNT(*) FILTER (WHERE o.cust_id IS NOT NULL) / NULLIF(COUNT(*) FILTER (WHERE v.customer_id IS NOT NULL), 0), 2) AS conversion_pct
FROM customers.customers c
LEFT JOIN visits v ON v.customer_id = c.customer_id
LEFT JOIN orders o ON o.cust_id = c.customer_id
GROUP BY c.tier
ORDER BY conversion_pct DESC;

/* Q38. */
SELECT payment_mode AS channel, COUNT(*) AS payments, ROUND(SUM(amount), 2) AS revenue
FROM sales.payments
GROUP BY payment_mode
ORDER BY revenue DESC;

/* Q39. */
WITH date_campaign AS (
  SELECT dd.date_key,
         (SELECT c.campaign_id FROM marketing.campaigns c WHERE dd.date_key BETWEEN c.start_date AND c.end_date ORDER BY c.start_date LIMIT 1) AS campaign_id
  FROM core.dim_date dd
)
SELECT dc.campaign_id, COUNT(DISTINCT o.order_id) AS orders, ROUND(SUM(o.net_total), 2) AS revenue
FROM sales.orders o
JOIN date_campaign dc ON dc.date_key = o.order_date
WHERE dc.campaign_id IS NOT NULL AND o.order_status NOT IN ('Cancelled','Failed')
GROUP BY dc.campaign_id
ORDER BY revenue DESC
LIMIT 20;

/* Q40. */
WITH device_visits AS (SELECT customer_id, MODE() WITHIN GROUP (ORDER BY device_type) AS device FROM web_events.page_views WHERE customer_id IS NOT NULL GROUP BY customer_id)
SELECT dv.device, COUNT(DISTINCT o.order_id) AS orders, ROUND(SUM(o.net_total), 2) AS revenue
FROM device_visits dv
JOIN sales.orders o ON o.cust_id = dv.customer_id AND o.order_status NOT IN ('Cancelled','Failed')
GROUP BY dv.device
ORDER BY revenue DESC;

/* Q41. */
WITH date_campaign AS (
  SELECT dd.date_key,
         (SELECT c.campaign_id FROM marketing.campaigns c WHERE dd.date_key BETWEEN c.start_date AND c.end_date ORDER BY c.start_date LIMIT 1) AS campaign_id
  FROM core.dim_date dd
),
touches AS (
  SELECT pv.customer_id, dc.campaign_id, COUNT(*) AS touch_count,
         MIN(pv.view_timestamp) AS first_ts, MAX(pv.view_timestamp) AS last_ts
  FROM web_events.page_views pv
  JOIN date_campaign dc ON dc.date_key = pv.view_timestamp::date
  WHERE pv.customer_id IS NOT NULL AND dc.campaign_id IS NOT NULL
  GROUP BY pv.customer_id, dc.campaign_id
),
touches_per_cust AS (SELECT customer_id, SUM(touch_count) AS total_touches FROM touches GROUP BY customer_id),
cust_revenue AS (SELECT cust_id, SUM(net_total) AS revenue FROM sales.orders WHERE order_status NOT IN ('Cancelled','Failed') GROUP BY cust_id)
SELECT t.campaign_id,
       ROUND(SUM(r.revenue * t.touch_count / tc.total_touches), 2) AS linear_attributed_revenue,
       COUNT(DISTINCT t.customer_id) AS touched_customers
FROM touches t
JOIN touches_per_cust tc ON tc.customer_id = t.customer_id
JOIN cust_revenue r ON r.cust_id = t.customer_id
GROUP BY t.campaign_id
ORDER BY linear_attributed_revenue DESC
LIMIT 20;

/* Q42. */
SELECT platform, SUM(amount) AS spend
FROM marketing.ads_spend
GROUP BY platform
ORDER BY spend DESC;

/* Q43. */
WITH device_visits AS (SELECT customer_id, MODE() WITHIN GROUP (ORDER BY device_type) AS device FROM web_events.page_views WHERE customer_id IS NOT NULL GROUP BY customer_id)
SELECT dv.device AS source, COUNT(DISTINCT o.order_id) AS orders, ROUND(SUM(o.net_total), 2) AS revenue
FROM device_visits dv
JOIN sales.orders o ON o.cust_id = dv.customer_id AND o.order_status NOT IN ('Cancelled','Failed')
GROUP BY dv.device
ORDER BY revenue DESC;

/* Q44. */
SELECT device_type AS medium, COUNT(*) AS page_views, COUNT(DISTINCT customer_id) FILTER (WHERE customer_id IS NOT NULL) AS unique_customers
FROM web_events.page_views
GROUP BY device_type
ORDER BY page_views DESC;

/* Q45. */
WITH spend AS (SELECT campaign_id, SUM(amount) AS spend FROM marketing.ads_spend GROUP BY campaign_id),
revenue AS (
  SELECT c.campaign_id, SUM(o.net_total) AS revenue
  FROM marketing.campaigns c JOIN sales.orders o ON o.order_date BETWEEN c.start_date AND c.end_date AND o.order_status NOT IN ('Cancelled','Failed')
  GROUP BY c.campaign_id
)
SELECT s.campaign_id, s.spend, COALESCE(r.revenue,0) AS revenue, ROUND(COALESCE(r.revenue,0) / NULLIF(s.spend,0), 2) AS roas
FROM spend s LEFT JOIN revenue r ON r.campaign_id = s.campaign_id
ORDER BY roas DESC NULLS LAST
LIMIT 20;

/* Q46. */
WITH platform_spend AS (SELECT platform, SUM(amount) AS spend FROM marketing.ads_spend GROUP BY platform),
campaign_platform AS (SELECT DISTINCT campaign_id, platform FROM marketing.ads_spend),
campaign_revenue AS (
  SELECT c.campaign_id, SUM(o.net_total) AS revenue
  FROM marketing.campaigns c JOIN sales.orders o ON o.order_date BETWEEN c.start_date AND c.end_date AND o.order_status NOT IN ('Cancelled','Failed')
  GROUP BY c.campaign_id
),
platform_revenue AS (
  SELECT cp.platform, SUM(COALESCE(cr.revenue,0)) AS revenue
  FROM campaign_platform cp LEFT JOIN campaign_revenue cr ON cr.campaign_id = cp.campaign_id
  GROUP BY cp.platform
)
SELECT ps.platform, ps.spend, pr.revenue, ROUND(pr.revenue / NULLIF(ps.spend,0), 2) AS roas
FROM platform_spend ps JOIN platform_revenue pr ON pr.platform = ps.platform
ORDER BY roas DESC;

/* Q47. */
WITH campaign_platform AS (SELECT DISTINCT campaign_id, platform FROM marketing.ads_spend),
platform_spend AS (SELECT platform, SUM(amount) AS spend FROM marketing.ads_spend GROUP BY platform),
new_cust AS (
  SELECT cp.platform, COUNT(DISTINCT cu.customer_id) AS new_customers
  FROM campaign_platform cp
  JOIN marketing.campaigns c ON c.campaign_id = cp.campaign_id
  JOIN customers.customers cu ON cu.registration_date BETWEEN c.start_date AND c.end_date
  GROUP BY cp.platform
)
SELECT ps.platform, ps.spend, COALESCE(nc.new_customers,0) AS new_customers,
       ROUND(ps.spend / NULLIF(nc.new_customers,0), 2) AS cac
FROM platform_spend ps LEFT JOIN new_cust nc ON nc.platform = ps.platform
ORDER BY cac DESC NULLS LAST;

/* Q48. */
WITH campaign_platform AS (SELECT DISTINCT campaign_id, platform FROM marketing.ads_spend),
platform_spend AS (SELECT platform, SUM(amount) AS spend FROM marketing.ads_spend GROUP BY platform),
new_cust AS (
  SELECT cp.platform, cu.customer_id
  FROM campaign_platform cp
  JOIN marketing.campaigns c ON c.campaign_id = cp.campaign_id
  JOIN customers.customers cu ON cu.registration_date BETWEEN c.start_date AND c.end_date
),
cust_spend AS (SELECT cust_id, SUM(net_total) AS spend FROM sales.orders WHERE order_status NOT IN ('Cancelled','Failed') GROUP BY cust_id)
SELECT nc.platform, ROUND(AVG(COALESCE(cs.spend,0)), 2) AS avg_ltv,
       ps.spend / NULLIF(COUNT(DISTINCT nc.customer_id), 0) AS cac,
       ROUND(AVG(COALESCE(cs.spend,0)) / NULLIF(ps.spend / NULLIF(COUNT(DISTINCT nc.customer_id), 0), 0), 2) AS ltv_cac_ratio
FROM new_cust nc
JOIN platform_spend ps ON ps.platform = nc.platform
LEFT JOIN cust_spend cs ON cs.cust_id = nc.customer_id
GROUP BY nc.platform, ps.spend
ORDER BY ltv_cac_ratio DESC NULLS LAST;

/* Q49. */
WITH gaps AS (SELECT cust_id, order_date, order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date) AS gap FROM sales.orders),
reactivated_orders AS (
  SELECT g.cust_id, o.order_id, o.net_total
  FROM gaps g
  JOIN sales.orders o ON o.cust_id = g.cust_id AND o.order_date >= g.order_date
  WHERE g.gap > 90 AND o.order_status NOT IN ('Cancelled','Failed')
)
SELECT COUNT(DISTINCT cust_id) AS winback_customers, ROUND(SUM(net_total), 2) AS winback_revenue
FROM reactivated_orders;

/* Q50. */
WITH gaps AS (SELECT cust_id, order_date, order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date) AS gap FROM sales.orders),
reactivated_orders AS (
  SELECT g.cust_id, o.order_id, o.net_total
  FROM gaps g
  JOIN sales.orders o ON o.cust_id = g.cust_id AND o.order_date >= g.order_date
  WHERE g.gap > 90 AND o.order_status NOT IN ('Cancelled','Failed')
),
total_spend AS (SELECT SUM(amount) AS spend FROM marketing.ads_spend),
reactivation_total AS (SELECT SUM(net_total) AS revenue FROM reactivated_orders)
SELECT ROUND(rt.revenue, 2) AS reactivation_revenue, ts.spend AS total_marketing_spend,
       ROUND(rt.revenue / NULLIF(ts.spend, 0), 2) AS reactivation_roas
FROM reactivation_total rt, total_spend ts;

/* SECTION C: ETL PIPELINES (25) */

/* Q51. */
WITH order_stats AS (SELECT cust_id, COUNT(*) AS orders, SUM(net_total) AS revenue FROM sales.orders WHERE order_status NOT IN ('Cancelled','Failed') GROUP BY cust_id)
SELECT c.customer_id, c.first_name, c.last_name, c.email, c.tier, c.registration_date,
       COALESCE(o.orders, 0) AS lifetime_orders, COALESCE(o.revenue, 0) AS lifetime_revenue
FROM customers.customers c
LEFT JOIN order_stats o ON o.cust_id = c.customer_id
ORDER BY c.customer_id
LIMIT 50;

/* Q52. */
SELECT o.order_id, o.cust_id, o.store_id, o.order_date, o.order_status, o.net_total,
       COUNT(oi.order_item_id) AS line_items, SUM(oi.quantity) AS total_units
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id, o.cust_id, o.store_id, o.order_date, o.order_status, o.net_total
ORDER BY o.order_id
LIMIT 50;

/* Q53. */
SELECT warehouse_id, product_id, snapshot_date, quantity_on_hand
FROM supply_chain.inventory_snapshots
WHERE snapshot_date = (SELECT MAX(snapshot_date) FROM supply_chain.inventory_snapshots)
ORDER BY warehouse_id, product_id
LIMIT 50;

/* Q54. */
SELECT c.campaign_id, c.campaign_name,
       COALESCE(SUM(a.amount), 0) AS total_spend,
       COALESCE(SUM(ec.emails_clicked), 0) AS total_clicks
FROM marketing.campaigns c
LEFT JOIN marketing.ads_spend a ON a.campaign_id = c.campaign_id
LEFT JOIN marketing.email_clicks ec ON ec.campaign_id = c.campaign_id
GROUP BY c.campaign_id, c.campaign_name
ORDER BY c.campaign_id
LIMIT 50;

/* Q55. */
SELECT event_id, view_id, event_type, element_id, event_timestamp
FROM web_events.events
WHERE event_timestamp >= (SELECT MAX(event_timestamp) FROM web_events.events) - INTERVAL '1 day'
ORDER BY event_timestamp DESC
LIMIT 50;

/* Q56. */
SELECT loyalty_id, customer_id, source, points_earned, date_earned
FROM customers.loyalty_points
ORDER BY date_earned DESC
LIMIT 50;

/* Q57. */
SELECT ticket_id, customer_id, agent_id, category, priority, status, created_date, resolved_date
FROM support.tickets
WHERE created_date >= (SELECT MAX(created_date) FROM support.tickets) - INTERVAL '1 day'
ORDER BY created_date DESC
LIMIT 50;

/* Q58. */
SELECT call_id, customer_id, agent_id, call_start_time, call_duration_seconds, call_reason, status
FROM call_center.calls
WHERE call_start_time >= (SELECT MAX(call_start_time) FROM call_center.calls) - INTERVAL '1 day'
ORDER BY call_start_time DESC
LIMIT 50;

/* Q59. */
SELECT change_id, table_name, record_id, column_name, old_value, new_value, changed_at, action
FROM audit.record_changes
ORDER BY changed_at DESC
LIMIT 50;

/* Q60. */
SELECT customer_id, tier, tier_updated_at
FROM customers.customers
WHERE tier_updated_at IS NOT NULL
ORDER BY tier_updated_at DESC
LIMIT 50;

/* Q61. */
SELECT product_id, product_name, price
FROM products.products
ORDER BY product_id
LIMIT 50;

/* Q62. */
SELECT store_id, store_name, region_id, square_ft
FROM stores.stores
ORDER BY store_id
LIMIT 50;

/* Q63. */
SELECT employee_id, first_name, last_name, salary, joining_date
FROM stores.employees
ORDER BY employee_id
LIMIT 50;

/* Q64. */
SELECT supplier_id, supplier_name, city
FROM products.suppliers
ORDER BY supplier_id
LIMIT 50;

/* Q65. */
SELECT customer_id, first_name, last_name, registration_date
FROM customers.customers
WHERE registration_date >= (SELECT MAX(registration_date) FROM customers.customers) - INTERVAL '1 day'
ORDER BY registration_date DESC;

/* Q66. */
SELECT order_id, cust_id, order_date, net_total
FROM sales.orders
WHERE order_date = (SELECT MAX(order_date) FROM sales.orders)
ORDER BY order_id
LIMIT 50;

/* Q67. */
SELECT customer_id, COUNT(*) AS orders
FROM sales.orders o JOIN customers.customers c ON c.customer_id = o.cust_id
WHERE order_date BETWEEN '2024-01-01' AND '2024-01-31'
GROUP BY customer_id
ORDER BY orders DESC
LIMIT 20;

/* Q68. */
SELECT o.order_id, o.order_date, p.payment_date, p.payment_date - o.order_date AS days_late
FROM sales.orders o
JOIN sales.payments p ON p.order_id = o.order_id
WHERE p.payment_date - o.order_date > 3
ORDER BY days_late DESC
LIMIT 30;

/* Q69. */
WITH ranked AS (
  SELECT customer_id, email, registration_date,
         ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY registration_date DESC) AS rn
  FROM customers.customers
)
SELECT customer_id, email, registration_date FROM ranked WHERE rn > 1;

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
WHERE order_status NOT IN ('Cancelled','Failed')
GROUP BY 1
ORDER BY 1;

/* Q73. */
WITH monthly_summary AS (
  SELECT DATE_TRUNC('month', order_date) AS month, COUNT(*) AS orders, ROUND(SUM(net_total), 2) AS revenue
  FROM sales.orders WHERE order_status NOT IN ('Cancelled','Failed') GROUP BY 1
)
SELECT month, orders, revenue FROM monthly_summary ORDER BY month;

/* Q74. */
SELECT order_id, order_date
FROM sales.orders
WHERE order_date < (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '18 months'
ORDER BY order_date
LIMIT 30;

/* Q75. */
SELECT LOWER(TRIM(product_name)) AS clean_name, COUNT(*) AS raw_rows
FROM products.products
GROUP BY LOWER(TRIM(product_name))
HAVING COUNT(*) > 1
ORDER BY raw_rows DESC
LIMIT 20;

/* SECTION D: CAPSTONE (25) */

/* Q76. */
WITH RECURSIVE hierarchy AS (
  SELECT 'cat_' || category_id::text AS node_id, category_name::text AS node_name, 0 AS lvl
  FROM core.dim_category
  UNION ALL
  SELECT 'brand_' || b.brand_id::text, b.brand_name::text, h.lvl + 1
  FROM core.dim_brand b JOIN hierarchy h ON h.node_id = 'cat_' || b.category_id::text
),
brand_revenue AS (SELECT p.brand_id, SUM(oi.net_amount) AS revenue FROM sales.order_items oi JOIN products.products p ON p.product_id = oi.prod_id GROUP BY p.brand_id),
ranked_brands AS (
  SELECT h.node_name AS brand_name, COALESCE(br.revenue,0) AS revenue,
         RANK() OVER (ORDER BY COALESCE(br.revenue,0) DESC) AS revenue_rank
  FROM hierarchy h LEFT JOIN brand_revenue br ON h.node_id = 'brand_' || br.brand_id::text
  WHERE h.lvl = 1
),
top_brands AS (SELECT brand_name, revenue, revenue_rank, 'top' AS bucket FROM ranked_brands WHERE revenue_rank <= 3),
bottom_brands AS (SELECT brand_name, revenue, revenue_rank, 'bottom' AS bucket FROM ranked_brands WHERE revenue_rank > (SELECT MAX(revenue_rank) FROM ranked_brands) - 3),
combined AS (SELECT * FROM top_brands UNION SELECT * FROM bottom_brands)
SELECT c.bucket, c.brand_name, c.revenue, c.revenue_rank, lp.product_name AS flagship_product
FROM combined c
LEFT JOIN LATERAL (
  SELECT p.product_name FROM products.products p
  WHERE p.brand_id = (SELECT brand_id FROM core.dim_brand WHERE brand_name = c.brand_name LIMIT 1)
  ORDER BY p.price DESC LIMIT 1
) lp ON true
ORDER BY c.bucket, c.revenue_rank;

/* Q77. */
WITH rev AS (SELECT SUM(net_total) AS total_revenue, COUNT(*) AS total_orders FROM sales.orders WHERE order_status NOT IN ('Cancelled','Failed')),
cust AS (SELECT COUNT(*) AS total_customers FROM customers.customers),
exp AS (SELECT SUM(amount) AS total_expenses FROM finance.expenses),
refund AS (SELECT SUM(refund_amount) AS total_refunds FROM sales.returns)
SELECT rev.total_revenue, rev.total_orders, cust.total_customers,
       ROUND(rev.total_revenue / NULLIF(rev.total_orders, 0), 2) AS aov,
       exp.total_expenses, ROUND(rev.total_revenue - exp.total_expenses, 2) AS net_income,
       refund.total_refunds
FROM rev, cust, exp, refund;

/* Q78. */
WITH monthly_rev AS (SELECT DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS revenue FROM sales.orders WHERE order_status NOT IN ('Cancelled','Failed') GROUP BY 1),
monthly_cust AS (SELECT DATE_TRUNC('month', registration_date) AS month, COUNT(*) AS new_customers FROM customers.customers GROUP BY 1)
SELECT r.month, r.revenue,
       ROUND(100.0 * (r.revenue - LAG(r.revenue) OVER (ORDER BY r.month)) / NULLIF(LAG(r.revenue) OVER (ORDER BY r.month), 0), 2) AS mom_growth_pct,
       c.new_customers
FROM monthly_rev r JOIN monthly_cust c ON c.month = r.month
ORDER BY r.month;

/* Q79. */
SELECT DATE_TRUNC('quarter', order_date) AS quarter, COUNT(*) AS orders, ROUND(SUM(net_total), 2) AS revenue, COUNT(DISTINCT cust_id) AS active_customers
FROM sales.orders
WHERE order_status NOT IN ('Cancelled','Failed')
GROUP BY 1
ORDER BY 1;

/* Q80. */
SELECT DATE_PART('year', order_date) AS year, COUNT(*) AS orders, ROUND(SUM(net_total), 2) AS revenue, COUNT(DISTINCT cust_id) AS active_customers
FROM sales.orders
WHERE order_status NOT IN ('Cancelled','Failed')
GROUP BY 1
ORDER BY 1;

/* Q81. */
SELECT DATE_TRUNC('month', order_date) AS month, COUNT(*) AS orders, ROUND(SUM(net_total), 2) AS revenue
FROM sales.orders
WHERE order_status NOT IN ('Cancelled','Failed')
GROUP BY 1
ORDER BY 1;

/* Q82. */
WITH order_stats AS (SELECT cust_id, COUNT(*) AS orders, SUM(net_total) AS revenue, MAX(order_date) AS last_order FROM sales.orders WHERE order_status NOT IN ('Cancelled','Failed') GROUP BY cust_id),
ticket_stats AS (SELECT customer_id, COUNT(*) AS tickets FROM support.tickets GROUP BY customer_id),
review_stats AS (SELECT customer_id, AVG(rating) AS avg_rating FROM customers.reviews GROUP BY customer_id)
SELECT c.customer_id,
       COALESCE(o.orders,0) AS orders, COALESCE(o.revenue,0) AS revenue,
       (SELECT MAX(order_date) FROM sales.orders) - o.last_order AS days_since_last_order,
       COALESCE(t.tickets,0) AS tickets, r.avg_rating,
       (COALESCE(o.orders,0) * 2 - COALESCE(t.tickets,0) + COALESCE(r.avg_rating,0)) AS health_score
FROM customers.customers c
LEFT JOIN order_stats o ON o.cust_id = c.customer_id
LEFT JOIN ticket_stats t ON t.customer_id = c.customer_id
LEFT JOIN review_stats r ON r.customer_id = c.customer_id
ORDER BY health_score DESC NULLS LAST
LIMIT 30;

/* Q83. */
WITH order_gaps AS (
  SELECT cust_id, order_date,
         order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date) AS gap
  FROM sales.orders
),
gap_summary AS (SELECT cust_id, COUNT(*) AS orders, MAX(order_date) AS last_order, MAX(gap) AS max_gap FROM order_gaps GROUP BY cust_id),
latest AS (SELECT MAX(order_date) AS d FROM sales.orders)
SELECT c.customer_id,
       COALESCE(g.orders, 0) AS orders,
       latest.d - g.last_order AS days_since_last_order,
       g.max_gap AS longest_gap_days
FROM customers.customers c
LEFT JOIN gap_summary g ON g.cust_id = c.customer_id
CROSS JOIN latest
ORDER BY days_since_last_order DESC NULLS LAST
LIMIT 30;

/* Q84. */
SELECT o.order_id, o.cust_id, o.net_total, SUM(r.refund_amount) AS total_refunded
FROM sales.orders o
JOIN sales.returns r ON r.order_id = o.order_id
GROUP BY o.order_id, o.cust_id, o.net_total
HAVING SUM(r.refund_amount) > o.net_total * 0.8
ORDER BY total_refunded DESC
LIMIT 30;

/* Q85. */
WITH cust_category_spend AS (
  SELECT o.cust_id, cat.category_name, SUM(oi.net_amount) AS category_spend
  FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
  WHERE o.order_status NOT IN ('Cancelled','Failed')
  GROUP BY o.cust_id, cat.category_name
),
ranked AS (
  SELECT cust_id, category_name, category_spend,
         RANK() OVER (PARTITION BY cust_id ORDER BY category_spend DESC) AS category_rank
  FROM cust_category_spend
)
SELECT cust_id, category_name, category_spend, category_rank
FROM ranked
WHERE category_rank = 1
ORDER BY category_spend DESC
LIMIT 30;

/* Q86. */
WITH cust_category AS (
  SELECT r.customer_id, cat.category_name, COUNT(*) AS reviews_in_category
  FROM customers.reviews r
  JOIN products.products p ON p.product_id = r.product_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
  GROUP BY r.customer_id, cat.category_name
),
ranked AS (
  SELECT customer_id, category_name, reviews_in_category,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY reviews_in_category DESC) AS rn
  FROM cust_category
)
SELECT customer_id, category_name AS favorite_category, reviews_in_category
FROM ranked
WHERE rn = 1
LIMIT 30;

/* Q87. */
WITH demand AS (
  SELECT oi.prod_id, DATE_TRUNC('month', o.order_date) AS month, SUM(oi.quantity) AS units_sold
  FROM sales.order_items oi JOIN sales.orders o ON o.order_id = oi.order_id
  WHERE o.order_status NOT IN ('Cancelled','Failed')
  GROUP BY oi.prod_id, DATE_TRUNC('month', o.order_date)
)
SELECT prod_id, ROUND(AVG(units_sold), 2) AS avg_monthly_demand, ROUND(STDDEV(units_sold), 2) AS demand_stddev
FROM demand
GROUP BY prod_id
ORDER BY avg_monthly_demand DESC
LIMIT 30;

/* Q88. */
SELECT i.store_id, i.product_id, p.product_name, i.quantity_on_hand, i.reorder_level,
       (i.reorder_level - i.quantity_on_hand) AS units_to_reorder
FROM products.inventory i
JOIN products.products p ON p.product_id = i.product_id
WHERE i.quantity_on_hand < i.reorder_level
ORDER BY units_to_reorder DESC
LIMIT 30;

/* Q89. */
WITH campaign_roi AS (
  SELECT c.campaign_id, c.campaign_name, c.budget, SUM(a.amount) AS spend,
         COALESCE((SELECT SUM(o.net_total) FROM sales.orders o WHERE o.order_date BETWEEN c.start_date AND c.end_date AND o.order_status NOT IN ('Cancelled','Failed')), 0) AS revenue
  FROM marketing.campaigns c
  LEFT JOIN marketing.ads_spend a ON a.campaign_id = c.campaign_id
  GROUP BY c.campaign_id, c.campaign_name, c.budget
)
SELECT campaign_id, campaign_name, budget, spend, revenue,
       ROUND(revenue / NULLIF(spend, 0), 2) AS roas
FROM campaign_roi
ORDER BY roas DESC NULLS LAST
LIMIT 20;

/* Q90. */
SELECT r.region_name, COUNT(DISTINCT s.store_id) AS stores, ROUND(SUM(o.net_total), 2) AS revenue,
       ROUND(SUM(o.net_total) / NULLIF(COUNT(DISTINCT s.store_id), 0), 2) AS revenue_per_store
FROM core.dim_region r
JOIN stores.stores s ON s.region_id = r.region_id
JOIN sales.orders o ON o.store_id = s.store_id AND o.order_status NOT IN ('Cancelled','Failed')
GROUP BY r.region_name
ORDER BY revenue_per_store DESC;

/* Q91. */
SELECT d.dept_id, d.dept_name, COUNT(e.employee_id) AS headcount, ROUND(AVG(e.salary), 2) AS avg_salary
FROM core.dim_department d
JOIN stores.employees e ON e.dept_id = d.dept_id
GROUP BY d.dept_id, d.dept_name
ORDER BY headcount DESC;

/* Q92. */
SELECT t.tier_name, t.min_points, t.max_points, COUNT(m.customer_id) AS members, ROUND(AVG(m.points_balance), 2) AS avg_points
FROM loyalty.tiers t
JOIN loyalty.members m ON m.tier_id = t.tier_id
GROUP BY t.tier_name, t.min_points, t.max_points
ORDER BY t.min_points;

/* Q93. */
WITH product_margin AS (
  SELECT product_id, product_name, price, cost_price,
         ROUND(100.0 * (price - cost_price) / NULLIF(price, 0), 2) AS margin_pct
  FROM products.products
)
SELECT product_id, product_name, price, cost_price, margin_pct,
       NTILE(4) OVER (ORDER BY margin_pct DESC) AS margin_quartile
FROM product_margin
ORDER BY margin_pct DESC
LIMIT 30;

/* Q94. */
SELECT promo_id, promo_name, discount_percent, start_date, end_date, active,
       end_date - start_date AS duration_days
FROM products.promotions
WHERE active = true
ORDER BY discount_percent DESC
LIMIT 30;

/* Q95. */
SELECT payment_mode AS channel, COUNT(*) AS payments, ROUND(SUM(amount), 2) AS revenue,
       ROUND(100.0 * SUM(amount) / SUM(SUM(amount)) OVER (), 2) AS pct_of_total_revenue
FROM sales.payments
GROUP BY payment_mode
ORDER BY revenue DESC;

/* Q96. */
WITH recent_spend AS (
  SELECT cust_id, SUM(net_total) AS spend FROM sales.orders
  WHERE order_status NOT IN ('Cancelled','Failed') AND order_date >= (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '6 months'
  GROUP BY cust_id
),
prior_spend AS (
  SELECT cust_id, SUM(net_total) AS spend FROM sales.orders
  WHERE order_status NOT IN ('Cancelled','Failed')
    AND order_date < (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '6 months'
    AND order_date >= (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '12 months'
  GROUP BY cust_id
),
recent_q AS (SELECT cust_id, NTILE(4) OVER (ORDER BY spend DESC) AS q FROM recent_spend),
prior_q AS (SELECT cust_id, NTILE(4) OVER (ORDER BY spend DESC) AS q FROM prior_spend)
SELECT p.q AS prior_quartile, r.q AS current_quartile, COUNT(*) AS customers
FROM prior_q p JOIN recent_q r ON r.cust_id = p.cust_id
GROUP BY p.q, r.q
ORDER BY p.q, r.q;

/* Q97. */
WITH sales_stats AS (SELECT prod_id, SUM(quantity) AS units_sold, SUM(net_amount) AS revenue FROM sales.order_items GROUP BY prod_id)
SELECT b.category_id, cat.category_name, COUNT(p.product_id) AS product_count,
       COALESCE(SUM(ss.units_sold), 0) AS total_units_sold, COALESCE(SUM(ss.revenue), 0) AS total_revenue
FROM products.products p
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
LEFT JOIN sales_stats ss ON ss.prod_id = p.product_id
GROUP BY b.category_id, cat.category_name
ORDER BY total_revenue DESC;

/* Q98. */
WITH ship_stats AS (SELECT warehouse_id, COUNT(*) AS shipments, SUM(quantity) AS total_quantity FROM supply_chain.shipments GROUP BY warehouse_id)
SELECT w.warehouse_id, w.name, w.capacity_sqft, COALESCE(s.shipments, 0) AS shipments, COALESCE(s.total_quantity, 0) AS total_quantity,
       ROUND(100.0 * COALESCE(s.total_quantity, 0) / NULLIF(w.capacity_sqft, 0), 2) AS pct_capacity_shipped
FROM supply_chain.warehouses w
LEFT JOIN ship_stats s ON s.warehouse_id = w.warehouse_id
ORDER BY pct_capacity_shipped DESC NULLS LAST;

/* Q99. */
WITH rev AS (SELECT SUM(net_total) AS total_revenue, COUNT(*) AS total_orders FROM sales.orders WHERE order_status NOT IN ('Cancelled','Failed')),
cust AS (SELECT COUNT(*) AS total_customers FROM customers.customers),
refund AS (SELECT SUM(refund_amount) AS total_refunds FROM sales.returns),
tickets AS (SELECT COUNT(*) AS total_tickets FROM support.tickets)
SELECT rev.total_revenue, rev.total_orders, cust.total_customers,
       ROUND(rev.total_revenue / NULLIF(rev.total_orders, 0), 2) AS aov,
       refund.total_refunds, tickets.total_tickets
FROM rev, cust, refund, tickets;

/* Q100. Executing DML against RetailMart's shared, concurrently-used live database is unsafe here (other students'/agents' work relies on unmodified data), so this is answered as the read-only equivalent: a single SELECT combining a RECURSIVE CTE (category -> brand hierarchy), a LATERAL join (each brand's top product), window functions (RANK/SUM OVER), and a set operation (UNION of top and bottom brand buckets) - see Q76 for that exact combined query; in a sandboxed/non-shared environment the same result set would instead feed an INSERT ... SELECT into a reporting table inside one transaction. */

/* ============================================================
   END OF ANSWER KEY - CRAZY LEVEL (100/100)
============================================================ */
