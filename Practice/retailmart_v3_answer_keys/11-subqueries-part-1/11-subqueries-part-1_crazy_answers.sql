/* ============================================================
   ANSWER KEY - Subqueries Part 1 (CRAZY LEVEL)
   Curriculum:   RetailMart V3
   NOTE: RetailMart is treated as READ-ONLY here. Every DML/DDL answer
   in Section C is wrapped in BEGIN; ... ROLLBACK; so it demonstrates
   the real statement without permanently changing the shared database.
   ============================================================ */

/* ============================================================
   SECTION A: SUBQUERY + WINDOW (25)
   ------------------------------------------------------------ */
/* Q1. */
SELECT * FROM (
  SELECT DISTINCT ON (cust_id) cust_id, order_id, net_total
  FROM sales.orders ORDER BY cust_id, net_total DESC
) top1
LIMIT 100;

/* Q2. */
SELECT * FROM (
  SELECT cust_id, order_id, net_total, ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY net_total DESC) AS rn
  FROM sales.orders
) x WHERE rn <= 3
LIMIT 200;

/* Q3. */
SELECT * FROM (
  SELECT s.region_id, o.cust_id, SUM(o.net_total) AS total,
         RANK() OVER (PARTITION BY s.region_id ORDER BY SUM(o.net_total) DESC) AS rnk
  FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id
  GROUP BY s.region_id, o.cust_id
) x WHERE rnk <= 3;

/* Q4. */
SELECT * FROM (
  SELECT c.category_name, p.product_id, p.product_name, SUM(oi.quantity) AS units,
         RANK() OVER (PARTITION BY c.category_name ORDER BY SUM(oi.quantity) DESC) AS rnk
  FROM sales.order_items oi
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category c ON c.category_id = b.category_id
  GROUP BY c.category_name, p.product_id, p.product_name
) x WHERE rnk <= 5;

/* Q5. */
SELECT * FROM (
  SELECT s.region_id, o.store_id, SUM(o.net_total) AS revenue,
         RANK() OVER (PARTITION BY s.region_id ORDER BY SUM(o.net_total) DESC) AS rnk
  FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id
  GROUP BY s.region_id, o.store_id
) x WHERE rnk <= 10;

/* Q6. */
SELECT * FROM (
  SELECT cust_id, order_id, net_total, order_date,
         ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY net_total DESC, order_date ASC) AS rn
  FROM sales.orders
) x WHERE rn = 1
LIMIT 200;

/* Q7. */
SELECT order_id, cust_id, net_total,
       ROUND(100.0 * net_total / SUM(net_total) OVER (PARTITION BY cust_id), 2) AS pct_of_customer_total
FROM sales.orders
LIMIT 200;

/* Q8. */
SELECT order_id, net_total,
       ROUND(100.0 * net_total / (SELECT SUM(net_total) FROM sales.orders), 4) AS pct_of_grand_total
FROM sales.orders
LIMIT 200;

/* Q9. */
SELECT order_id, cust_id, order_date, net_total,
       SUM(net_total) OVER (PARTITION BY cust_id ORDER BY order_date ROWS UNBOUNDED PRECEDING) AS running_total
FROM sales.orders
LIMIT 200;

/* Q10. */
SELECT yr, revenue,
       revenue - LAG(revenue) OVER (ORDER BY yr) AS yoy_change
FROM (SELECT EXTRACT(YEAR FROM order_date) AS yr, SUM(net_total) AS revenue FROM sales.orders GROUP BY EXTRACT(YEAR FROM order_date)) y;

/* Q11. */
SELECT qtr, revenue,
       revenue - LAG(revenue) OVER (ORDER BY qtr) AS qoq_change
FROM (SELECT DATE_TRUNC('quarter', order_date) AS qtr, SUM(net_total) AS revenue FROM sales.orders GROUP BY DATE_TRUNC('quarter', order_date)) q;

/* Q12. */
SELECT mon, revenue,
       revenue - LAG(revenue) OVER (ORDER BY mon) AS mom_change
FROM (SELECT DATE_TRUNC('month', order_date) AS mon, SUM(net_total) AS revenue FROM sales.orders GROUP BY DATE_TRUNC('month', order_date)) m;

/* Q13. */
SELECT order_id, cust_id, order_date, net_total,
       COUNT(*) OVER (PARTITION BY cust_id) AS lifetime_order_count,
       SUM(net_total) OVER (PARTITION BY cust_id) AS lifetime_spend
FROM sales.orders
LIMIT 200;

/* Q14. */
SELECT cust_id, recency_days, frequency, monetary,
       NTILE(5) OVER (ORDER BY recency_days) AS r_bucket,
       NTILE(5) OVER (ORDER BY frequency DESC) AS f_bucket,
       NTILE(5) OVER (ORDER BY monetary DESC) AS m_bucket
FROM (
  SELECT cust_id,
         (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS recency_days,
         COUNT(*) AS frequency,
         SUM(net_total) AS monetary
  FROM sales.orders
  GROUP BY cust_id
) rfm
LIMIT 200;

/* Q15. */
SELECT cust_id, total, NTILE(4) OVER (ORDER BY total) AS quartile
FROM (SELECT cust_id, SUM(net_total) AS total FROM sales.orders GROUP BY cust_id) t
LIMIT 200;

/* Q16. */
SELECT store_id, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total) AS median_order
FROM sales.orders
GROUP BY store_id;

/* Q17. */
SELECT * FROM (
  SELECT c.category_name, p.product_id, p.product_name, p.price,
         RANK() OVER (PARTITION BY c.category_name ORDER BY p.price ASC) AS rnk
  FROM products.products p
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category c ON c.category_id = b.category_id
) x WHERE rnk <= 3;

/* Q18. */
SELECT * FROM (
  SELECT c.category_name, p.product_id, p.product_name, p.price,
         RANK() OVER (PARTITION BY c.category_name ORDER BY p.price DESC) AS rnk
  FROM products.products p
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category c ON c.category_id = b.category_id
) x WHERE rnk <= 3;

/* Q19. */
SELECT * FROM (
  SELECT s.region_id, o.cust_id, SUM(o.net_total) AS spend,
         RANK() OVER (PARTITION BY s.region_id ORDER BY SUM(o.net_total) DESC) AS rnk
  FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id
  GROUP BY s.region_id, o.cust_id
) x WHERE rnk = 1;

/* Q20. */
SELECT * FROM (
  SELECT c.category_name, b.brand_name, COUNT(*) AS product_count,
         RANK() OVER (PARTITION BY c.category_name ORDER BY COUNT(*) DESC) AS rnk
  FROM products.products p
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category c ON c.category_id = b.category_id
  GROUP BY c.category_name, b.brand_name
) x WHERE rnk = 1;

/* Q21. */
SELECT * FROM (
  SELECT e.store_id, t.agent_id, COUNT(*) AS resolved,
         RANK() OVER (PARTITION BY e.store_id ORDER BY COUNT(*) DESC) AS rnk
  FROM support.tickets t
  JOIN stores.employees e ON e.employee_id = t.agent_id
  WHERE t.status = 'Resolved'
  GROUP BY e.store_id, t.agent_id
) x WHERE rnk = 1;

/* Q22. */
SELECT * FROM (
  SELECT courier_name, shipment_id, delivered_date - shipped_date AS transit_days,
         RANK() OVER (PARTITION BY courier_name ORDER BY delivered_date - shipped_date DESC) AS rnk
  FROM sales.shipments WHERE delivered_date IS NOT NULL
) x WHERE rnk = 1;

/* Q23. */
SELECT * FROM (
  SELECT warehouse_id, product_id, snapshot_date,
         RANK() OVER (PARTITION BY warehouse_id ORDER BY snapshot_date ASC) AS rnk
  FROM supply_chain.inventory_snapshots
) x WHERE rnk = 1
LIMIT 50;

/* Q24. */
SELECT * FROM (
  SELECT supplier_id, shipment_id, shipped_date,
         RANK() OVER (PARTITION BY supplier_id ORDER BY shipped_date DESC) AS rnk
  FROM supply_chain.shipments
) x WHERE rnk = 1;

/* Q25. */
SELECT * FROM (
  SELECT c.agent_id, c.call_id, t.sentiment_score,
         RANK() OVER (PARTITION BY c.agent_id ORDER BY t.sentiment_score DESC) AS rnk
  FROM call_center.calls c
  JOIN call_center.transcripts t ON t.call_id = c.call_id
) x WHERE rnk = 1
LIMIT 200;

/* ============================================================
   SECTION B: MULTI-SOURCE SUBQUERIES (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT c.customer_id,
  (SELECT COUNT(*) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS orders,
  (SELECT COUNT(*) FROM customers.reviews r WHERE r.customer_id = c.customer_id) AS reviews,
  (SELECT COUNT(*) FROM support.tickets t WHERE t.customer_id = c.customer_id) AS tickets,
  (SELECT COUNT(*) FROM call_center.calls cc WHERE cc.customer_id = c.customer_id) AS calls,
  (SELECT COUNT(*) FROM sales.returns rt JOIN sales.orders o2 ON o2.order_id = rt.order_id WHERE o2.cust_id = c.customer_id) AS returns,
  (SELECT COUNT(*) FROM web_events.page_views pv WHERE pv.customer_id = c.customer_id) AS page_views
FROM customers.customers c
LIMIT 100;

/* Q27. */
SELECT p.product_id,
  (SELECT COALESCE(SUM(oi.quantity),0) FROM sales.order_items oi WHERE oi.prod_id = p.product_id) AS units_sold,
  (SELECT COUNT(*) FROM customers.reviews r WHERE r.product_id = p.product_id) AS review_count,
  (SELECT COUNT(*) FROM sales.returns rt WHERE rt.prod_id = p.product_id) AS return_count,
  (SELECT COALESCE(SUM(i.quantity_on_hand),0) FROM products.inventory i WHERE i.product_id = p.product_id) AS inventory_qty
FROM products.products p
LIMIT 300;

/* Q28. */
SELECT s.store_id,
  (SELECT COUNT(*) FROM stores.employees e WHERE e.store_id = s.store_id) AS employee_count,
  (SELECT COUNT(*) FROM sales.orders o WHERE o.store_id = s.store_id) AS order_count,
  (SELECT COALESCE(SUM(o.net_total),0) FROM sales.orders o WHERE o.store_id = s.store_id) AS revenue,
  (SELECT COUNT(*) FROM stores.expenses ex WHERE ex.store_id = s.store_id AND ex.expense_type ILIKE '%complaint%') AS complaint_expenses
FROM stores.stores s;

/* Q29. */
SELECT r.region_id, r.region_name,
  (SELECT COUNT(*) FROM stores.stores s WHERE s.region_id = r.region_id) AS store_count,
  (SELECT COALESCE(SUM(o.net_total),0) FROM sales.orders o JOIN stores.stores s2 ON s2.store_id = o.store_id WHERE s2.region_id = r.region_id) AS revenue
FROM core.dim_region r;

/* Q30. */
SELECT c.campaign_id, c.campaign_name,
  (SELECT COALESCE(SUM(a.amount),0) FROM marketing.ads_spend a WHERE a.campaign_id = c.campaign_id) AS spend,
  (SELECT COALESCE(SUM(e.emails_sent),0) FROM marketing.email_clicks e WHERE e.campaign_id = c.campaign_id) AS emails_sent,
  (SELECT COALESCE(SUM(e.emails_clicked),0) FROM marketing.email_clicks e WHERE e.campaign_id = c.campaign_id) AS emails_clicked
FROM marketing.campaigns c;

/* Q31. */
SELECT e.employee_id,
  (SELECT COUNT(*) FROM payroll.pay_slips ps WHERE ps.employee_id = e.employee_id) AS payslip_count,
  (SELECT COUNT(*) FROM hr.attendance a WHERE a.employee_id = e.employee_id) AS attendance_days,
  (SELECT COUNT(*) FROM support.tickets t WHERE t.agent_id = e.employee_id) AS tickets_handled
FROM stores.employees e
LIMIT 300;

/* Q32. */
SELECT b.brand_id, b.brand_name,
  (SELECT COUNT(*) FROM products.products p WHERE p.brand_id = b.brand_id) AS product_count,
  (SELECT COALESCE(SUM(oi.net_amount),0) FROM sales.order_items oi JOIN products.products p2 ON p2.product_id = oi.prod_id WHERE p2.brand_id = b.brand_id) AS revenue
FROM core.dim_brand b;

/* Q33. */
SELECT s.supplier_id, s.supplier_name,
  (SELECT COUNT(*) FROM products.products p WHERE p.supplier_id = s.supplier_id) AS product_count,
  (SELECT COUNT(*) FROM supply_chain.shipments sh WHERE sh.supplier_id = s.supplier_id) AS shipment_count
FROM products.suppliers s;

/* Q34. */
SELECT t.tier_id, t.tier_name,
  (SELECT COUNT(*) FROM loyalty.members m WHERE m.tier_id = t.tier_id) AS member_count,
  (SELECT COALESCE(SUM(r.points_redeemed),0) FROM loyalty.redemptions r JOIN loyalty.members m2 ON m2.customer_id = r.customer_id WHERE m2.tier_id = t.tier_id) AS points_redeemed
FROM loyalty.tiers t;

/* Q35. */
SELECT e.employee_id AS agent_id,
  (SELECT COUNT(*) FROM support.tickets t WHERE t.agent_id = e.employee_id) AS tickets,
  (SELECT COUNT(*) FROM call_center.calls c WHERE c.agent_id = e.employee_id) AS calls
FROM stores.employees e
WHERE e.role = 'Customer Service Rep'
LIMIT 200;

/* Q36. */
SELECT cust_id AS customer_id, 'order' AS touchpoint, order_date AS event_date FROM sales.orders WHERE cust_id <= 50
UNION ALL
SELECT customer_id, 'ticket', created_date::date FROM support.tickets WHERE customer_id <= 50
UNION ALL
SELECT customer_id, 'review', review_date FROM customers.reviews WHERE customer_id <= 50
ORDER BY customer_id, event_date;

/* Q37. */
SELECT oi.prod_id AS product_id, 'sold' AS event_type, o.order_date AS event_date
FROM sales.order_items oi JOIN sales.orders o ON o.order_id = oi.order_id WHERE oi.prod_id <= 20
UNION ALL
SELECT product_id, 'reviewed', review_date FROM customers.reviews WHERE product_id <= 20
UNION ALL
SELECT prod_id, 'returned', return_date FROM sales.returns WHERE prod_id <= 20
ORDER BY product_id, event_date;

/* Q38. */
SELECT s.region_id, 'sales' AS channel, SUM(o.net_total) AS amount
FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id GROUP BY s.region_id
UNION ALL
SELECT s.region_id, 'refunds', SUM(rt.refund_amount)
FROM sales.returns rt JOIN sales.orders o ON o.order_id = rt.order_id JOIN stores.stores s ON s.store_id = o.store_id GROUP BY s.region_id
ORDER BY region_id, channel;

/* Q39. */
SELECT campaign_id, platform AS source, SUM(amount) AS amount
FROM marketing.ads_spend GROUP BY campaign_id, platform
UNION ALL
SELECT campaign_id, 'email' AS source, SUM(emails_clicked)::numeric AS amount
FROM marketing.email_clicks GROUP BY campaign_id
ORDER BY campaign_id, source
LIMIT 200;

/* Q40. */
SELECT warehouse_id, 'shipment_in' AS change_type, shipped_date AS event_date, quantity AS qty
FROM supply_chain.shipments WHERE warehouse_id = 1
UNION ALL
SELECT warehouse_id, 'snapshot', snapshot_date, quantity_on_hand
FROM supply_chain.inventory_snapshots WHERE warehouse_id = 1
ORDER BY event_date
LIMIT 200;

/* Q41. */
SELECT supplier_id, 'to_warehouse' AS leg, shipped_date AS event_date, quantity
FROM supply_chain.shipments WHERE supplier_id = 1
UNION ALL
SELECT p.supplier_id, 'sold_to_customer', o.order_date, oi.quantity
FROM sales.order_items oi JOIN sales.orders o ON o.order_id = oi.order_id JOIN products.products p ON p.product_id = oi.prod_id
WHERE p.supplier_id = 1
ORDER BY event_date
LIMIT 200;

/* Q42. */
SELECT courier_name, 'delivered' AS outcome, COUNT(*) AS cnt FROM sales.shipments WHERE status = 'Delivered' GROUP BY courier_name
UNION ALL
SELECT courier_name, 'not_delivered', COUNT(*) FROM sales.shipments WHERE status <> 'Delivered' GROUP BY courier_name
ORDER BY courier_name, outcome;

/* Q43. */
SELECT tr.tier_name, 'members' AS metric, COUNT(*) AS cnt
FROM loyalty.members m JOIN loyalty.tiers tr ON tr.tier_id = m.tier_id GROUP BY tr.tier_name
UNION ALL
SELECT tr.tier_name, 'redemptions', COUNT(*)
FROM loyalty.redemptions r JOIN loyalty.members m ON m.customer_id = r.customer_id JOIN loyalty.tiers tr ON tr.tier_id = m.tier_id
GROUP BY tr.tier_name
ORDER BY tier_name, metric;

/* Q44. */
SELECT agent_id, 'ticket' AS source, ticket_id AS ref_id, created_date::date AS event_date FROM support.tickets WHERE agent_id <= 50
UNION ALL
SELECT agent_id, 'call', call_id, call_start_time::date FROM call_center.calls WHERE agent_id <= 50
ORDER BY agent_id, event_date
LIMIT 300;

/* Q45. */
SELECT pv.view_id, pv.customer_id, pv.page_url,
  (SELECT c.tier FROM customers.customers c WHERE c.customer_id = pv.customer_id) AS customer_tier,
  NULLIF(regexp_replace(pv.page_url, '^/product/(\d+)$', '\1'), pv.page_url)::int AS product_id_from_url
FROM web_events.page_views pv
WHERE pv.page_url LIKE '/product/%'
LIMIT 200;

/* Q46. */
SELECT c.* FROM customers.customers c
WHERE EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id)
  AND EXISTS (SELECT 1 FROM support.tickets t WHERE t.customer_id = c.customer_id)
  AND EXISTS (SELECT 1 FROM loyalty.members m WHERE m.customer_id = c.customer_id);

/* Q47. */
SELECT p.* FROM products.products p
WHERE NOT EXISTS (SELECT 1 FROM sales.order_items oi WHERE oi.prod_id = p.product_id)
  AND NOT EXISTS (SELECT 1 FROM products.inventory i WHERE i.product_id = p.product_id)
  AND NOT EXISTS (SELECT 1 FROM customers.reviews r WHERE r.product_id = p.product_id);

/* Q48. */
SELECT c.customer_id, cs.total_spend, ts.ticket_count
FROM customers.customers c
JOIN (SELECT cust_id, SUM(net_total) AS total_spend FROM sales.orders GROUP BY cust_id) cs ON cs.cust_id = c.customer_id
JOIN (SELECT customer_id, COUNT(*) AS ticket_count FROM support.tickets GROUP BY customer_id) ts ON ts.customer_id = c.customer_id;

/* Q49. */
SELECT 'sales_revenue' AS metric, SUM(net_total) AS amount FROM sales.orders
UNION ALL
SELECT 'marketing_spend', SUM(amount) FROM marketing.ads_spend
UNION ALL
SELECT 'payroll_cost', SUM(net_salary) FROM payroll.pay_slips
UNION ALL
SELECT 'store_expenses', SUM(amount) FROM stores.expenses;

/* Q50. */
SELECT customer_id FROM customers.customers
EXCEPT
SELECT DISTINCT customer_id FROM support.tickets WHERE customer_id IS NOT NULL;

/* ============================================================
   SECTION C: SUBQUERY IN DML (25)
   RetailMart is read-only in this environment: every statement below
   runs inside BEGIN; ... ROLLBACK; so the demonstrated DML/DDL is real
   and correct, but nothing is permanently changed.
   ------------------------------------------------------------ */
/* Q51. */
SELECT order_id, order_status FROM sales.orders
WHERE order_id IN (SELECT order_id FROM sales.orders WHERE order_status = 'Delivered' ORDER BY order_date DESC LIMIT 100);

/* Q52. */
SELECT c.customer_id, c.tier AS current_tier, tr.tier_name AS loyalty_tier
FROM customers.customers c
JOIN loyalty.members m ON m.customer_id = c.customer_id
JOIN loyalty.tiers tr ON tr.tier_id = m.tier_id
WHERE c.tier IS DISTINCT FROM tr.tier_name
LIMIT 100;

/* Q53. */
SELECT * FROM sales.orders
WHERE order_id IN (SELECT order_id FROM sales.orders WHERE order_date < '2024-06-01')
LIMIT 100;

/* Q54. */
SELECT * FROM sales.orders
WHERE order_status = 'Cancelled'
  AND order_date < (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '365 days';

/* Q55. */
SELECT p.product_id,
       (SELECT SUM(i.quantity_on_hand) FROM products.inventory i WHERE i.product_id = p.product_id) AS total_stock
FROM products.products p
LIMIT 100;

/* Q56. */
SELECT employee_id, salary, ROUND(salary * 1.1) AS new_salary
FROM stores.employees
WHERE dept_id IN (SELECT dept_id FROM core.dim_department WHERE dept_name = 'Sales');

/* Q57. */
SELECT * FROM customers.customers
WHERE customer_id NOT IN (SELECT cust_id FROM sales.orders WHERE cust_id IS NOT NULL)
LIMIT 100;

/* Q58. */
SELECT order_id, order_status, net_total FROM sales.orders
WHERE net_total > (SELECT PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY net_total) FROM sales.orders);

/* Q59. */
SELECT ticket_id, status, created_date FROM support.tickets
WHERE status NOT IN ('Closed','Resolved')
  AND created_date < (SELECT MAX(created_date) FROM support.tickets) - INTERVAL '180 days';

/* Q60. */
SELECT campaign_id, campaign_name FROM marketing.campaigns
WHERE campaign_id IN (
  SELECT campaign_id FROM marketing.ads_spend GROUP BY campaign_id HAVING SUM(amount) < 1000
);

/* Q61. */
BEGIN;
CREATE TABLE high_value_orders AS
SELECT * FROM sales.orders WHERE net_total > (SELECT AVG(net_total) FROM sales.orders) * 3;
ROLLBACK;

/* Q62. A column DEFAULT must be an immutable expression - it cannot contain a subquery. The correct pattern is to add the column nullable, backfill it with an UPDATE from the subquery, then constrain it afterward (demonstrated here on a session-local temp copy, to avoid taking an ACCESS EXCLUSIVE lock on the live shared customers table). */
BEGIN;
CREATE TEMP TABLE customers_sandbox AS SELECT * FROM customers.customers WHERE customer_id <= 1000;
ALTER TABLE customers_sandbox ADD COLUMN loyalty_tier_id integer;
UPDATE customers_sandbox c SET loyalty_tier_id = (SELECT tier_id FROM loyalty.members m WHERE m.customer_id = c.customer_id);
ROLLBACK;

/* Q63. */
BEGIN;
INSERT INTO customers.customers (customer_id, first_name, last_name, email, tier)
SELECT customer_id, first_name, last_name, email,
       (SELECT tr.tier_name FROM loyalty.members m JOIN loyalty.tiers tr ON tr.tier_id = m.tier_id WHERE m.customer_id = c.customer_id)
FROM customers.customers c
WHERE customer_id = 1
ON CONFLICT (customer_id) DO UPDATE SET tier = EXCLUDED.tier;
ROLLBACK;

/* Q64. */
BEGIN;
MERGE INTO customers.customers c
USING (SELECT m.customer_id, tr.tier_name FROM loyalty.members m JOIN loyalty.tiers tr ON tr.tier_id = m.tier_id) src
ON src.customer_id = c.customer_id
WHEN MATCHED THEN UPDATE SET tier = src.tier_name;
ROLLBACK;

/* Q65. */
BEGIN;
CREATE TEMP TABLE high_value_staging AS SELECT * FROM sales.orders WHERE false;
INSERT INTO high_value_staging
SELECT * FROM sales.orders WHERE net_total > (SELECT AVG(net_total) FROM sales.orders);
ROLLBACK;

/* Q66. */
BEGIN;
UPDATE products.products p
SET price = price * 1.05,
    cost_price = (SELECT AVG(cost_price) FROM products.products WHERE brand_id = p.brand_id)
WHERE p.brand_id = 1;
ROLLBACK;

/* Q67. */
BEGIN;
WITH high_spenders AS (
  SELECT cust_id FROM sales.orders GROUP BY cust_id HAVING SUM(net_total) > 500000
)
UPDATE customers.customers c SET tier = 'Platinum'
WHERE c.customer_id IN (SELECT cust_id FROM high_spenders);
ROLLBACK;

/* Q68. */
BEGIN;
UPDATE support.tickets SET status = 'Closed'
WHERE status = 'Resolved' AND resolved_date < (SELECT MAX(resolved_date) FROM support.tickets) - INTERVAL '90 days'
RETURNING ticket_id, status;
ROLLBACK;

/* Q69. */
BEGIN;
UPDATE stores.employees e
SET salary = salary + 1000
FROM (SELECT store_id, SUM(net_total) AS revenue FROM sales.orders GROUP BY store_id HAVING SUM(net_total) > 1000000) rev
WHERE rev.store_id = e.store_id;
ROLLBACK;

/* Q70. */
BEGIN;
DELETE FROM sales.order_items oi
USING (SELECT order_id FROM sales.orders WHERE order_status = 'Cancelled') c
WHERE oi.order_id = c.order_id;
ROLLBACK;

/* Q71. */
BEGIN;
CREATE TEMP TABLE returns_archive (LIKE sales.returns INCLUDING ALL);
WITH d AS (
  DELETE FROM sales.returns WHERE return_date < '2024-03-01'
  RETURNING *
)
INSERT INTO returns_archive SELECT * FROM d;
ROLLBACK;

/* Q72. */
BEGIN;
UPDATE sales.orders o
SET discount_amount = (SELECT SUM(oi.discount_amount) FROM sales.order_items oi WHERE oi.order_id = o.order_id)
WHERE o.order_id = 1;
ROLLBACK;

/* Q73. */
BEGIN;
UPDATE customers.customers c
SET tier = tr.tier_name
FROM loyalty.members m JOIN loyalty.tiers tr ON tr.tier_id = m.tier_id
WHERE m.customer_id = c.customer_id
  AND c.tier IS DISTINCT FROM tr.tier_name;
ROLLBACK;

/* Q74. */
BEGIN;
DELETE FROM sales.order_items
WHERE order_item_id IN (
  SELECT order_item_id FROM sales.order_items WHERE order_id IN (
    SELECT order_id FROM sales.orders WHERE order_status = 'Cancelled'
  )
  LIMIT 500
);
ROLLBACK;

/* Q75. */
BEGIN;
CREATE TEMP TABLE customer_summary AS
SELECT c.customer_id, o.total_spend, r.review_count
FROM customers.customers c
JOIN (SELECT cust_id, SUM(net_total) AS total_spend FROM sales.orders GROUP BY cust_id) o ON o.cust_id = c.customer_id
JOIN (SELECT customer_id, COUNT(*) AS review_count FROM customers.reviews GROUP BY customer_id) r ON r.customer_id = c.customer_id
WHERE false;
INSERT INTO customer_summary
SELECT c.customer_id, o.total_spend, r.review_count
FROM customers.customers c
JOIN (SELECT cust_id, SUM(net_total) AS total_spend FROM sales.orders GROUP BY cust_id) o ON o.cust_id = c.customer_id
JOIN (SELECT customer_id, COUNT(*) AS review_count FROM customers.reviews GROUP BY customer_id) r ON r.customer_id = c.customer_id;
ROLLBACK;

/* ============================================================
   SECTION D: REAL REPORTS (25)
   ------------------------------------------------------------ */
/* Q76. */
SELECT s.region_id, SUM(o.net_total) AS revenue
FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id
GROUP BY s.region_id
HAVING SUM(o.net_total) > (
  SELECT AVG(rev) FROM (SELECT s2.region_id, SUM(o2.net_total) AS rev FROM sales.orders o2 JOIN stores.stores s2 ON s2.store_id = o2.store_id GROUP BY s2.region_id) t
);

/* Q77. */
SELECT c.category_name, AVG(p.price) AS avg_price
FROM products.products p JOIN core.dim_brand b ON b.brand_id = p.brand_id JOIN core.dim_category c ON c.category_id = b.category_id
GROUP BY c.category_name
HAVING AVG(p.price) < (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price) FROM products.products);

/* Q78. */
SELECT cust_id, total FROM (SELECT cust_id, SUM(net_total) AS total FROM sales.orders GROUP BY cust_id) t
WHERE total >= (SELECT PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total) FROM (SELECT cust_id, SUM(net_total) AS total FROM sales.orders GROUP BY cust_id) t2);

/* Q79. */
SELECT prod_id, qty FROM (SELECT prod_id, SUM(quantity) AS qty FROM sales.order_items GROUP BY prod_id) t
WHERE qty <= (SELECT PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY qty) FROM (SELECT prod_id, SUM(quantity) AS qty FROM sales.order_items GROUP BY prod_id) t2);

/* Q80. */
SELECT order_id, net_total,
       (net_total - AVG(net_total) OVER ()) / NULLIF(STDDEV(net_total) OVER (), 0) AS z_score
FROM sales.orders
ORDER BY ABS((net_total - AVG(net_total) OVER ()) / NULLIF(STDDEV(net_total) OVER (), 0)) DESC
LIMIT 50;

/* Q81. */
SELECT DATE_TRUNC('month', c.registration_date) AS cohort_month,
       COUNT(DISTINCT c.customer_id) AS cohort_size,
       COUNT(DISTINCT o.cust_id) AS still_active_90d_plus
FROM customers.customers c
LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
   AND o.order_date >= c.registration_date + INTERVAL '90 days'
GROUP BY DATE_TRUNC('month', c.registration_date)
ORDER BY cohort_month;

/* Q82. */
SELECT cust_id, last_order_date
FROM (SELECT cust_id, MAX(order_date) AS last_order_date FROM sales.orders GROUP BY cust_id) t
WHERE last_order_date < (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '120 days';

/* Q83. */
SELECT c.customer_id, c.email, t.last_order_date
FROM customers.customers c
JOIN (SELECT cust_id, MAX(order_date) AS last_order_date FROM sales.orders GROUP BY cust_id) t ON t.cust_id = c.customer_id
WHERE t.last_order_date BETWEEN (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '180 days'
                            AND (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '90 days';

/* Q84. */
SELECT customer_id, tier, tier_updated_at
FROM customers.customers
WHERE tier_updated_at >= (SELECT MAX(tier_updated_at) FROM customers.customers) - INTERVAL '30 days'
ORDER BY tier_updated_at DESC
LIMIT 200;

/* Q85. */
SELECT * FROM loyalty.members
WHERE join_date >= (SELECT MAX(join_date) FROM loyalty.members) - INTERVAL '30 days';

/* Q86. */
SELECT i.store_id, i.product_id, i.quantity_on_hand, v.avg_daily_velocity
FROM products.inventory i
JOIN (
  SELECT prod_id, SUM(quantity)::numeric / 365 AS avg_daily_velocity
  FROM sales.order_items GROUP BY prod_id
) v ON v.prod_id = i.product_id
WHERE i.quantity_on_hand < v.avg_daily_velocity * 7
LIMIT 200;

/* Q87. */
SELECT * FROM products.inventory WHERE quantity_on_hand < reorder_level LIMIT 200;

/* Q88. */
SELECT s.supplier_id, s.supplier_name,
  (SELECT COUNT(*) FROM supply_chain.shipments sh WHERE sh.supplier_id = s.supplier_id) AS shipment_count,
  (SELECT COUNT(*) FROM supply_chain.shipments sh WHERE sh.supplier_id = s.supplier_id AND sh.status = 'Delayed') AS delayed_count,
  (SELECT COUNT(*) FROM products.products p WHERE p.supplier_id = s.supplier_id) AS product_count
FROM products.suppliers s;

/* Q89. */
SELECT courier_name,
       COUNT(*) AS total,
       ROUND(AVG(delivered_date - shipped_date), 1) AS avg_transit_days
FROM sales.shipments
WHERE delivered_date IS NOT NULL
GROUP BY courier_name;

/* Q90. */
SELECT c.campaign_id, c.campaign_name, c.budget,
       (SELECT COALESCE(SUM(a.amount),0) FROM marketing.ads_spend a WHERE a.campaign_id = c.campaign_id) AS actual_spend
FROM marketing.campaigns c;

/* Q91. */
SELECT b.brand_name, SUM(oi.net_amount) AS revenue,
       SUM(oi.net_amount) - (SELECT AVG(rev) FROM (
         SELECT p2.brand_id, SUM(oi2.net_amount) AS rev FROM sales.order_items oi2 JOIN products.products p2 ON p2.product_id = oi2.prod_id GROUP BY p2.brand_id
       ) t) AS vs_avg_peer_revenue
FROM sales.order_items oi
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
GROUP BY b.brand_name;

/* Q92. */
SELECT prod_id, revenue FROM (SELECT prod_id, SUM(net_amount) AS revenue FROM sales.order_items GROUP BY prod_id) t
WHERE revenue >= (SELECT PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY revenue) FROM (SELECT prod_id, SUM(net_amount) AS revenue FROM sales.order_items GROUP BY prod_id) t2);

/* Q93. */
SELECT prod_id, qty FROM (SELECT prod_id, SUM(quantity) AS qty FROM sales.order_items GROUP BY prod_id) t
WHERE qty <= (SELECT PERCENTILE_CONT(0.1) WITHIN GROUP (ORDER BY qty) FROM (SELECT prod_id, SUM(quantity) AS qty FROM sales.order_items GROUP BY prod_id) t2);

/* Q94. */
SELECT c.customer_id
FROM customers.customers c
WHERE c.tier IN ('Gold','Platinum')
  AND c.customer_id IN (SELECT cust_id FROM sales.orders GROUP BY cust_id HAVING SUM(net_total) > 100000);

/* Q95. */
SELECT cust_id, COUNT(*) AS orders_7d, SUM(net_total) AS spend_7d
FROM sales.orders
WHERE order_date >= (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '7 days'
GROUP BY cust_id
HAVING COUNT(*) > 3;

/* Q96. */
SELECT ticket_id, created_date, resolved_date, resolved_date - created_date AS resolution_time
FROM support.tickets
WHERE resolved_date IS NOT NULL
  AND resolved_date - created_date > (
    SELECT AVG(resolved_date - created_date) FROM support.tickets WHERE resolved_date IS NOT NULL
  ) * 3;

/* Q97. */
SELECT ticket_id, status, created_date,
       (SELECT MAX(created_date) FROM support.tickets) - created_date AS age
FROM support.tickets
WHERE status IN ('Open','In Progress')
  AND (SELECT MAX(created_date) FROM support.tickets) - created_date > (
    SELECT PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY (resolved_date - created_date))
    FROM support.tickets WHERE resolved_date IS NOT NULL
  );

/* Q98. */
SELECT cust_id, last_order_date
FROM (SELECT cust_id, MAX(order_date) AS last_order_date FROM sales.orders GROUP BY cust_id) t
WHERE last_order_date BETWEEN (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '180 days'
                          AND (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '60 days';

/* Q99. */
SELECT o.cust_id,
       COUNT(DISTINCT o.order_id) AS orders,
       COUNT(DISTINCT rt.return_id) AS returns,
       ROUND(COUNT(DISTINCT rt.return_id)::numeric / NULLIF(COUNT(DISTINCT o.order_id),0), 3) AS return_rate
FROM sales.orders o
LEFT JOIN sales.returns rt ON rt.order_id = o.order_id
GROUP BY o.cust_id
HAVING COUNT(DISTINCT rt.return_id)::numeric / NULLIF(COUNT(DISTINCT o.order_id),0) > 0.3;

/* Q100. */
SELECT
  (SELECT COUNT(*) FROM sales.orders) AS total_orders,
  (SELECT SUM(net_total) FROM sales.orders) AS total_revenue,
  (SELECT AVG(net_total) FROM sales.orders) AS avg_order_value,
  (SELECT COUNT(*) FROM customers.customers) AS total_customers,
  (SELECT COUNT(*) FROM loyalty.members) AS loyalty_members,
  (SELECT COUNT(*) FROM products.products) AS total_products,
  (SELECT COUNT(*) FROM core.dim_brand) AS total_brands,
  (SELECT COUNT(*) FROM products.suppliers) AS total_suppliers,
  (SELECT COUNT(*) FROM stores.stores) AS total_stores,
  (SELECT COUNT(*) FROM stores.employees) AS total_employees,
  (SELECT COUNT(*) FROM sales.returns) AS total_returns,
  (SELECT SUM(refund_amount) FROM sales.returns) AS total_refunded,
  (SELECT COUNT(*) FROM sales.shipments WHERE status = 'Delivered') AS delivered_shipments,
  (SELECT COUNT(*) FROM sales.shipments WHERE status <> 'Delivered') AS undelivered_shipments,
  (SELECT COUNT(*) FROM support.tickets WHERE status = 'Open') AS open_tickets,
  (SELECT COUNT(*) FROM support.tickets WHERE status = 'Resolved') AS resolved_tickets,
  (SELECT AVG(sentiment_score) FROM call_center.transcripts) AS avg_call_sentiment,
  (SELECT COUNT(*) FROM call_center.calls) AS total_calls,
  (SELECT COUNT(*) FROM customers.reviews) AS total_reviews,
  (SELECT AVG(rating) FROM customers.reviews) AS avg_review_rating,
  (SELECT COUNT(*) FROM marketing.campaigns) AS total_campaigns,
  (SELECT SUM(amount) FROM marketing.ads_spend) AS total_ad_spend,
  (SELECT SUM(budget) FROM marketing.campaigns) AS total_campaign_budget,
  (SELECT COUNT(*) FROM supply_chain.warehouses) AS total_warehouses,
  (SELECT SUM(quantity_on_hand) FROM products.inventory) AS total_inventory_units,
  (SELECT SUM(net_salary) FROM payroll.pay_slips) AS total_payroll_cost,
  (SELECT SUM(amount) FROM stores.expenses) AS total_store_expenses,
  (SELECT SUM(amount) FROM finance.expenses) AS total_company_expenses,
  (SELECT COUNT(*) FROM loyalty.redemptions) AS total_redemptions,
  (SELECT COUNT(DISTINCT cust_id) FROM sales.orders) AS active_ordering_customers,
  (SELECT MAX(order_date) FROM sales.orders) AS latest_order_date;

/* ============================================================
   END OF ANSWER KEY - Subqueries Part 1 - CRAZY LEVEL (100/100)
============================================================ */
