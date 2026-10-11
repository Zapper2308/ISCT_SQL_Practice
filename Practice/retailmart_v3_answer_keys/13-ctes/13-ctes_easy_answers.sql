/* ============================================================
   ANSWER KEY - CTEs (WITH, non-recursive) (EASY LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CTE - CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1.  A CTE (Common Table Expression) is a named, temporary result set defined with a WITH clause that can be referenced like a table later in the same statement. */
/* Q2.  Both are inline named result sets - a CTE is declared once up front with WITH ... AS and can be referenced multiple times; a derived table is written inline inside FROM (...) AS alias and is normally written fresh each time it's needed. */
/* Q3.  Because a CTE is literally a SELECT (a subquery) that has been given a name via WITH name AS (...), so you reference it by name instead of repeating or nesting the subquery. */
/* Q4.  Yes - within the same statement a CTE can be joined to, selected from, or unioned multiple times without rewriting its SQL. */
/* Q5.  A CTE only exists for the duration of the single SQL statement its WITH clause is attached to; it is not visible to any other statement, transaction, or session. */
/* Q6.  PostgreSQL 12+ inlines (folds) a CTE into the outer query, like a plain subquery, when it is referenced exactly once and has no side effects or volatile functions; it materializes (computes once, buffers the result) when referenced more than once or when MATERIALIZED is forced. */
/* Q7.  WITH name AS MATERIALIZED (...) forces PostgreSQL 12+ to compute the CTE once into a temporary buffer and treat it as an optimization fence, even if it's only referenced once. */
/* Q8.  WITH name AS NOT MATERIALIZED (...) forces the planner to inline the CTE into the outer query (fold it like a subquery, allowing predicate pushdown) even if it is referenced more than once. */
/* Q9.  WITH a AS (...), b AS (...) SELECT ... defines several CTEs in one WITH clause separated by commas, each usable anywhere in the final query. */
/* Q10. A later CTE in the same WITH clause can reference any CTE defined earlier in that clause, e.g. WITH a AS (...), b AS (SELECT * FROM a ...) SELECT * FROM b. */
/* Q11. WITH RECURSIVE name AS (anchor SELECT UNION ALL recursive SELECT referencing name) SELECT ... - it runs the anchor once then repeatedly re-executes the recursive term against the previous iteration's rows until it returns none; covered in depth in a later topic. */
/* Q12. Use a CTE for a one-off, statement-scoped simplification you don't need elsewhere; use a VIEW when the same logic must be reused across many queries or exposed as a stable named object others can query. */
/* Q13. A CTE recomputes every time its statement runs and is never persisted to disk; a materialized view physically stores its result set and must be REFRESHed, so it's far cheaper to re-read repeatedly but can go stale. */
/* Q14. A CTE's WITH clause can live directly inside a CREATE VIEW ... AS SELECT ... definition; it re-executes each time the view is queried since the view itself isn't materialized. */
/* Q15. A SQL or PL/pgSQL function body can contain WITH ... AS (...) SELECT statements exactly as in ad-hoc SQL, scoped to that one statement inside the function. */
/* Q16. Yes - INSERT, UPDATE and DELETE statements can have a leading WITH clause providing named result sets the DML statement can SELECT FROM or join to (a "writeable CTE" when the WITH itself contains DML). */
/* Q17. WITH cte_name(col1, col2) AS (SELECT ...) lets you rename the CTE's output columns positionally, overriding whatever aliases the inner SELECT used. */
/* Q18. A CTE's SELECT list can include computed/derived expressions (e.g. net_total - discount_amount AS margin), and the outer query then references those computed columns by name as if they were stored. */
/* Q19. A CTE can perform its own GROUP BY internally, and the outer query then filters, joins, or orders the already-aggregated rows it exposes. */
/* Q20. A CTE can filter its own aggregated groups with HAVING before ever exposing rows to the outer query, which keeps the outer query's WHERE/logic simpler. */
/* Q21. PostgreSQL allows ORDER BY/LIMIT inside a CTE's inner SELECT, letting the CTE itself pick e.g. the top N rows to hand off to the outer query. */
/* Q22. A CTE can compute window functions like ROW_NUMBER()/RANK(), and the outer query can then filter on that computed column in WHERE - something you can't do directly to a window function in the same SELECT. */
/* Q23. The inner SELECT of a CTE can JOIN multiple tables exactly like any normal query; the CTE just gives the resulting joined (and optionally aggregated) rowset a name. */
/* Q24. A CTE's inner SELECT can be a UNION (or UNION ALL) combining rows from different sources into one named result that the outer query treats as a single table. */
/* Q25. A CTE can use INTERSECT to keep only rows common to two SELECTs, or EXCEPT to subtract one SELECT's rows from another's, exposing the set-operation's result under one name. */

/* ============================================================
   SECTION B: SINGLE-CTE QUERIES (25)
   ------------------------------------------------------------ */
/* Q26. */
WITH spend AS (
  SELECT cust_id, SUM(net_total) AS total_spend
  FROM sales.orders
  GROUP BY cust_id
)
SELECT cust_id, total_spend FROM spend ORDER BY total_spend DESC LIMIT 10;

/* Q27. */
WITH units AS (
  SELECT prod_id, SUM(quantity) AS units_sold
  FROM sales.order_items
  GROUP BY prod_id
)
SELECT prod_id, units_sold FROM units ORDER BY units_sold DESC LIMIT 10;

/* Q28. */
WITH store_rev AS (
  SELECT store_id, SUM(net_total) AS revenue
  FROM sales.orders
  GROUP BY store_id
)
SELECT store_id, revenue FROM store_rev ORDER BY revenue DESC LIMIT 10;

/* Q29. */
WITH brand_rev AS (
  SELECT p.brand_id, SUM(oi.net_amount) AS revenue
  FROM sales.order_items oi
  JOIN products.products p ON oi.prod_id = p.product_id
  GROUP BY p.brand_id
)
SELECT b.brand_name, r.revenue
FROM brand_rev r
JOIN core.dim_brand b ON b.brand_id = r.brand_id
ORDER BY r.revenue DESC LIMIT 5;

/* Q30. */
WITH cat_rev AS (
  SELECT cat.category_name, SUM(oi.net_amount) AS revenue
  FROM sales.order_items oi
  JOIN products.products p ON oi.prod_id = p.product_id
  JOIN core.dim_brand b ON p.brand_id = b.brand_id
  JOIN core.dim_category cat ON b.category_id = cat.category_id
  GROUP BY cat.category_name
)
SELECT category_name, revenue FROM cat_rev ORDER BY revenue DESC LIMIT 5;

/* Q31. */
WITH region_orders AS (
  SELECT r.region_name, COUNT(*) AS order_count
  FROM sales.orders o
  JOIN stores.stores s ON o.store_id = s.store_id
  JOIN core.dim_region r ON s.region_id = r.region_id
  GROUP BY r.region_name
)
SELECT * FROM region_orders ORDER BY order_count DESC;

/* Q32. */
WITH dept_count AS (
  SELECT d.dept_name, COUNT(*) AS employee_count
  FROM stores.employees e
  JOIN core.dim_department d ON e.dept_id = d.dept_id
  GROUP BY d.dept_name
)
SELECT * FROM dept_count ORDER BY employee_count DESC;

/* Q33. */
WITH tier_count AS (
  SELECT tr.tier_name, COUNT(*) AS member_count
  FROM loyalty.members m
  JOIN loyalty.tiers tr ON m.tier_id = tr.tier_id
  GROUP BY tr.tier_name
)
SELECT * FROM tier_count ORDER BY member_count DESC;

/* Q34. */
WITH wh_qty AS (
  SELECT warehouse_id, SUM(quantity_on_hand) AS total_qty
  FROM supply_chain.inventory_snapshots
  WHERE snapshot_date = (SELECT MAX(snapshot_date) FROM supply_chain.inventory_snapshots)
  GROUP BY warehouse_id
)
SELECT * FROM wh_qty ORDER BY total_qty DESC;

/* Q35. */
WITH courier_count AS (
  SELECT courier_name, COUNT(*) AS shipment_count
  FROM sales.shipments
  GROUP BY courier_name
)
SELECT * FROM courier_count ORDER BY shipment_count DESC;

/* Q36. */
WITH cust_orders AS (
  SELECT cust_id, COUNT(*) AS order_count
  FROM sales.orders
  GROUP BY cust_id
)
SELECT * FROM cust_orders WHERE order_count > 10 ORDER BY order_count DESC;

/* Q37. */
WITH prod_reviews AS (
  SELECT product_id, COUNT(*) AS review_count
  FROM customers.reviews
  GROUP BY product_id
)
SELECT * FROM prod_reviews WHERE review_count > 5 ORDER BY review_count DESC;

/* Q38. */
WITH order_avg AS (
  SELECT AVG(net_total) AS avg_total FROM sales.orders
)
SELECT o.order_id, o.net_total
FROM sales.orders o, order_avg a
WHERE o.net_total > a.avg_total
ORDER BY o.net_total DESC
LIMIT 100;

/* Q39. */
WITH median_val AS (
  SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY net_total) AS median_total
  FROM sales.orders
)
SELECT o.order_id, o.net_total
FROM sales.orders o, median_val m
WHERE o.net_total < m.median_total
ORDER BY o.net_total
LIMIT 100;

/* Q40. */
WITH stats AS (
  SELECT AVG(net_total) AS mean_total, STDDEV(net_total) AS sd_total FROM sales.orders
)
SELECT o.order_id, o.net_total, (o.net_total - s.mean_total) / s.sd_total AS z_score
FROM sales.orders o, stats s
WHERE ABS((o.net_total - s.mean_total) / s.sd_total) > 3
ORDER BY z_score DESC
LIMIT 100;

/* Q41. */
WITH latest_order AS (
  SELECT DISTINCT ON (cust_id) cust_id, order_id, order_date
  FROM sales.orders
  ORDER BY cust_id, order_date DESC
)
SELECT * FROM latest_order ORDER BY cust_id LIMIT 100;

/* Q42. */
WITH ranked AS (
  SELECT product_id, review_id, review_date,
         ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY review_date DESC) AS rn
  FROM customers.reviews
)
SELECT product_id, review_id, review_date FROM ranked WHERE rn = 1 LIMIT 100;

/* Q43. */
WITH ranked AS (
  SELECT employee_id, pay_slip_id, payment_date,
         ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY payment_date DESC) AS rn
  FROM payroll.pay_slips
)
SELECT employee_id, pay_slip_id, payment_date FROM ranked WHERE rn = 1 LIMIT 100;

/* Q44. */
WITH ranked AS (
  SELECT warehouse_id, product_id, snapshot_date, quantity_on_hand,
         ROW_NUMBER() OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date DESC) AS rn
  FROM supply_chain.inventory_snapshots
)
SELECT warehouse_id, product_id, snapshot_date, quantity_on_hand FROM ranked WHERE rn = 1 LIMIT 100;

/* Q45. */
WITH ranked AS (
  SELECT courier_name, shipment_id, shipped_date,
         ROW_NUMBER() OVER (PARTITION BY courier_name ORDER BY shipped_date DESC) AS rn
  FROM sales.shipments
  WHERE shipped_date IS NOT NULL
)
SELECT courier_name, shipment_id, shipped_date FROM ranked WHERE rn = 1;

/* Q46. */
WITH first_order AS (
  SELECT cust_id, MIN(order_date) AS first_order_date
  FROM sales.orders
  GROUP BY cust_id
)
SELECT * FROM first_order ORDER BY cust_id LIMIT 100;

/* Q47. */
WITH first_review AS (
  SELECT product_id, MIN(review_date) AS first_review_date
  FROM customers.reviews
  GROUP BY product_id
)
SELECT * FROM first_review ORDER BY product_id LIMIT 100;

/* Q48. */
WITH recent_orders AS (
  SELECT DISTINCT cust_id
  FROM sales.orders
  WHERE order_date >= (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '30 days'
)
SELECT * FROM recent_orders LIMIT 100;

/* Q49. */
WITH this_month AS (
  SELECT customer_id, registration_date
  FROM customers.customers
  WHERE date_trunc('month', registration_date) =
        date_trunc('month', (SELECT MAX(registration_date) FROM customers.customers))
)
SELECT * FROM this_month LIMIT 100;

/* Q50. */
WITH last_order AS (
  SELECT cust_id, MAX(order_date) AS last_order_date
  FROM sales.orders
  GROUP BY cust_id
)
SELECT cust_id, last_order_date
FROM last_order
WHERE last_order_date < (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '90 days'
ORDER BY last_order_date
LIMIT 100;

/* ============================================================
   SECTION C: MULTI-CTE QUERIES (25)
   ------------------------------------------------------------ */
/* Q51. */
WITH orders_agg AS (
  SELECT cust_id, COUNT(*) AS order_count, SUM(net_total) AS total_spend
  FROM sales.orders GROUP BY cust_id
),
revs_agg AS (
  SELECT customer_id, COUNT(*) AS review_count, AVG(rating) AS avg_rating
  FROM customers.reviews GROUP BY customer_id
)
SELECT c.customer_id, c.first_name, c.last_name, o.order_count, o.total_spend, r.review_count, r.avg_rating
FROM customers.customers c
JOIN orders_agg o ON o.cust_id = c.customer_id
LEFT JOIN revs_agg r ON r.customer_id = c.customer_id
ORDER BY o.total_spend DESC
LIMIT 100;

/* Q52. */
WITH orders_agg AS (
  SELECT cust_id, COUNT(*) AS order_count, SUM(net_total) AS total_spend
  FROM sales.orders GROUP BY cust_id
),
tickets_agg AS (
  SELECT customer_id, COUNT(*) AS ticket_count
  FROM support.tickets GROUP BY customer_id
)
SELECT c.customer_id, c.first_name, c.last_name, o.order_count, o.total_spend, COALESCE(t.ticket_count, 0) AS ticket_count
FROM customers.customers c
JOIN orders_agg o ON o.cust_id = c.customer_id
LEFT JOIN tickets_agg t ON t.customer_id = c.customer_id
ORDER BY o.total_spend DESC
LIMIT 100;

/* Q53. */
WITH spend_per_cust AS (
  SELECT cust_id, SUM(net_total) AS total_spend
  FROM sales.orders GROUP BY cust_id
),
tier_lookup AS (
  SELECT customer_id, tier FROM customers.customers
)
SELECT t.tier, COUNT(*) AS customers, SUM(s.total_spend) AS segment_spend, AVG(s.total_spend) AS avg_spend
FROM spend_per_cust s
JOIN tier_lookup t ON t.customer_id = s.cust_id
GROUP BY t.tier
ORDER BY segment_spend DESC;

/* Q54. */
WITH revenue_per_region AS (
  SELECT s.region_id, SUM(o.net_total) AS revenue
  FROM sales.orders o JOIN stores.stores s ON o.store_id = s.store_id
  GROUP BY s.region_id
)
SELECT rd.region_name, rd.country, r.revenue
FROM revenue_per_region r
JOIN core.dim_region rd ON rd.region_id = r.region_id
ORDER BY r.revenue DESC;

/* Q55. */
WITH revenue_per_brand AS (
  SELECT p.brand_id, SUM(oi.net_amount) AS revenue
  FROM sales.order_items oi JOIN products.products p ON oi.prod_id = p.product_id
  GROUP BY p.brand_id
)
SELECT bd.brand_name, r.revenue
FROM revenue_per_brand r
JOIN core.dim_brand bd ON bd.brand_id = r.brand_id
ORDER BY r.revenue DESC
LIMIT 20;

/* Q56. */
WITH inventory_levels AS (
  SELECT product_id, SUM(quantity_on_hand) AS total_on_hand
  FROM products.inventory GROUP BY product_id
)
SELECT p.product_name, i.total_on_hand
FROM inventory_levels i
JOIN products.products p ON p.product_id = i.product_id
ORDER BY i.total_on_hand DESC
LIMIT 20;

/* Q57. */
WITH agent_workload AS (
  SELECT agent_id, COUNT(*) AS ticket_count
  FROM support.tickets GROUP BY agent_id
)
SELECT e.employee_id, e.first_name, e.last_name, a.ticket_count
FROM agent_workload a
JOIN stores.employees e ON e.employee_id = a.agent_id
ORDER BY a.ticket_count DESC
LIMIT 20;

/* Q58. */
WITH courier_perf AS (
  SELECT courier_name, COUNT(*) AS shipment_count,
         AVG(delivered_date - shipped_date) AS avg_delivery_days
  FROM sales.shipments
  WHERE delivered_date IS NOT NULL
  GROUP BY courier_name
)
SELECT * FROM courier_perf ORDER BY avg_delivery_days;

/* Q59. */
WITH cohort_signup AS (
  SELECT customer_id, date_trunc('month', registration_date) AS signup_month
  FROM customers.customers
),
cohort_first_order AS (
  SELECT cust_id, MIN(order_date) AS first_order_date
  FROM sales.orders GROUP BY cust_id
)
SELECT cs.signup_month, COUNT(*) AS customers, COUNT(fo.cust_id) AS converted_to_order
FROM cohort_signup cs
LEFT JOIN cohort_first_order fo ON fo.cust_id = cs.customer_id
GROUP BY cs.signup_month
ORDER BY cs.signup_month;

/* Q60. */
WITH churned_customers AS (
  SELECT cust_id, MAX(order_date) AS last_order_date
  FROM sales.orders
  GROUP BY cust_id
  HAVING MAX(order_date) < (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '90 days'
),
win_back_targets AS (
  SELECT c.cust_id, c.last_order_date
  FROM churned_customers c
  JOIN sales.orders o ON o.cust_id = c.cust_id
  GROUP BY c.cust_id, c.last_order_date
  HAVING SUM(o.net_total) > 10000
)
SELECT * FROM win_back_targets ORDER BY last_order_date LIMIT 100;

/* Q61. */
WITH monthly_rev AS (
  SELECT date_trunc('month', order_date) AS month, SUM(net_total) AS revenue
  FROM sales.orders GROUP BY date_trunc('month', order_date)
),
monthly_cost AS (
  SELECT date_trunc('month', expense_date) AS month, SUM(amount) AS cost
  FROM stores.expenses GROUP BY date_trunc('month', expense_date)
)
SELECT r.month, r.revenue, COALESCE(c.cost, 0) AS cost, r.revenue - COALESCE(c.cost, 0) AS profit
FROM monthly_rev r
LEFT JOIN monthly_cost c ON c.month = r.month
ORDER BY r.month;

/* Q62. */
WITH monthly_orders AS (
  SELECT date_trunc('month', order_date) AS month, COUNT(*) AS order_count
  FROM sales.orders GROUP BY date_trunc('month', order_date)
),
monthly_signups AS (
  SELECT date_trunc('month', registration_date) AS month, COUNT(*) AS new_customers
  FROM customers.customers GROUP BY date_trunc('month', registration_date)
)
SELECT o.month, o.order_count, COALESCE(s.new_customers, 0) AS new_customers
FROM monthly_orders o
LEFT JOIN monthly_signups s ON s.month = o.month
ORDER BY o.month;

/* Q63. */
WITH top_products AS (
  SELECT prod_id, SUM(quantity) AS units_sold
  FROM sales.order_items GROUP BY prod_id
  ORDER BY units_sold DESC LIMIT 10
)
SELECT p.product_name, b.brand_name, t.units_sold
FROM top_products t
JOIN products.products p ON p.product_id = t.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
ORDER BY t.units_sold DESC;

/* Q64. */
WITH top_customers AS (
  SELECT cust_id, SUM(net_total) AS total_spend
  FROM sales.orders GROUP BY cust_id
  ORDER BY total_spend DESC LIMIT 10
)
SELECT tc.cust_id, tc.total_spend, o.order_id, o.order_date, o.net_total
FROM top_customers tc
JOIN sales.orders o ON o.cust_id = tc.cust_id
ORDER BY tc.total_spend DESC, o.order_date DESC;

/* Q65. */
WITH top_brands AS (
  SELECT p.brand_id, SUM(oi.net_amount) AS revenue
  FROM sales.order_items oi JOIN products.products p ON oi.prod_id = p.product_id
  GROUP BY p.brand_id ORDER BY revenue DESC LIMIT 10
)
SELECT b.brand_name, cat.category_name, tb.revenue
FROM top_brands tb
JOIN core.dim_brand b ON b.brand_id = tb.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
ORDER BY tb.revenue DESC;

/* Q66. */
WITH agent_stats AS (
  SELECT agent_id, COUNT(*) AS tickets_handled
  FROM support.tickets GROUP BY agent_id
),
customer_stats AS (
  SELECT customer_id, COUNT(*) AS tickets_raised
  FROM support.tickets GROUP BY customer_id
)
SELECT e.employee_id, e.first_name, a.tickets_handled, c.customer_id, c.tickets_raised
FROM agent_stats a
JOIN stores.employees e ON e.employee_id = a.agent_id
JOIN support.tickets t ON t.agent_id = a.agent_id
JOIN customer_stats c ON c.customer_id = t.customer_id
ORDER BY a.tickets_handled DESC
LIMIT 100;

/* Q67. */
WITH supplier_stats AS (
  SELECT supplier_id, COUNT(*) AS product_count
  FROM products.products GROUP BY supplier_id
),
product_stats AS (
  SELECT product_id, supplier_id, price
  FROM products.products
)
SELECT sup.supplier_name, s.product_count, AVG(p.price) AS avg_price
FROM supplier_stats s
JOIN products.suppliers sup ON sup.supplier_id = s.supplier_id
JOIN product_stats p ON p.supplier_id = s.supplier_id
GROUP BY sup.supplier_name, s.product_count
ORDER BY s.product_count DESC
LIMIT 20;

/* Q68. */
WITH warehouse_stats AS (
  SELECT warehouse_id, SUM(quantity_on_hand) AS total_qty
  FROM supply_chain.inventory_snapshots
  WHERE snapshot_date = (SELECT MAX(snapshot_date) FROM supply_chain.inventory_snapshots)
  GROUP BY warehouse_id
),
inventory_stats AS (
  SELECT warehouse_id, COUNT(DISTINCT product_id) AS distinct_products
  FROM supply_chain.inventory_snapshots
  WHERE snapshot_date = (SELECT MAX(snapshot_date) FROM supply_chain.inventory_snapshots)
  GROUP BY warehouse_id
)
SELECT w.name, ws.total_qty, ist.distinct_products
FROM warehouse_stats ws
JOIN inventory_stats ist ON ist.warehouse_id = ws.warehouse_id
JOIN supply_chain.warehouses w ON w.warehouse_id = ws.warehouse_id
ORDER BY ws.total_qty DESC;

/* Q69. */
WITH region_stats AS (
  SELECT s.region_id, SUM(o.net_total) AS region_revenue
  FROM sales.orders o JOIN stores.stores s ON o.store_id = s.store_id
  GROUP BY s.region_id
),
city_stats AS (
  SELECT s.region_id, s.city, SUM(o.net_total) AS city_revenue
  FROM sales.orders o JOIN stores.stores s ON o.store_id = s.store_id
  GROUP BY s.region_id, s.city
)
SELECT rd.region_name, cs.city, cs.city_revenue, rr.region_revenue
FROM city_stats cs
JOIN region_stats rr ON rr.region_id = cs.region_id
JOIN core.dim_region rd ON rd.region_id = cs.region_id
ORDER BY rr.region_revenue DESC, cs.city_revenue DESC;

/* Q70. */
WITH tier_stats AS (
  SELECT tier, COUNT(*) AS customer_count
  FROM customers.customers GROUP BY tier
),
lifecycle_stats AS (
  SELECT tier, AVG(CURRENT_DATE - registration_date) AS avg_tenure_days
  FROM customers.customers GROUP BY tier
)
SELECT t.tier, t.customer_count, l.avg_tenure_days
FROM tier_stats t
JOIN lifecycle_stats l ON l.tier = t.tier
ORDER BY t.customer_count DESC;

/* Q71. */
WITH a AS (
  SELECT cust_id, net_total FROM sales.orders
),
b AS (
  SELECT cust_id, SUM(net_total) AS total_spend FROM a GROUP BY cust_id
),
c AS (
  SELECT cust_id, total_spend FROM b WHERE total_spend > 50000
)
SELECT * FROM c ORDER BY total_spend DESC LIMIT 100;

/* Q72. */
WITH a AS (
  SELECT cust_id, net_total, order_date FROM sales.orders
),
b AS (
  SELECT cust_id, SUM(net_total) AS total_spend, COUNT(*) AS order_count FROM a GROUP BY cust_id
),
c AS (
  SELECT cust_id, total_spend, order_count, total_spend / order_count AS avg_order_value FROM b
),
d AS (
  SELECT * FROM c WHERE avg_order_value > 3000
)
SELECT * FROM d ORDER BY avg_order_value DESC LIMIT 100;

/* Q73. */
WITH a AS (
  SELECT cust_id, net_total FROM sales.orders
),
b AS (
  SELECT cust_id, SUM(net_total) AS total_spend FROM a GROUP BY cust_id
),
c AS (
  SELECT cust_id, total_spend FROM b WHERE total_spend > 0
),
d AS (
  SELECT c.cust_id, c.total_spend, cu.tier FROM c JOIN customers.customers cu ON cu.customer_id = c.cust_id
),
e AS (
  SELECT tier, COUNT(*) AS customers, SUM(total_spend) AS tier_spend FROM d GROUP BY tier
)
SELECT * FROM e ORDER BY tier_spend DESC;

/* Q74. */
WITH a AS (
  SELECT product_id, price FROM products.products
),
b AS (
  SELECT product_id, price FROM a WHERE price > (SELECT AVG(price) FROM a)
),
c AS (
  SELECT product_id, price FROM b WHERE price < (SELECT MAX(price) FROM b)
)
SELECT * FROM c ORDER BY price DESC LIMIT 100;

/* Q75. */
WITH high_value_orders AS (
  SELECT order_id, cust_id, net_total, 'high_value' AS flag FROM sales.orders WHERE net_total > 40000
),
returned_orders AS (
  SELECT DISTINCT o.order_id, o.cust_id, o.net_total, 'returned' AS flag
  FROM sales.orders o JOIN sales.returns r ON r.order_id = o.order_id
),
combined AS (
  SELECT * FROM high_value_orders
  UNION
  SELECT * FROM returned_orders
)
SELECT * FROM combined ORDER BY net_total DESC LIMIT 100;

/* ============================================================
   SECTION D: WRITEABLE CTEs (DML) (25)
   NOTE: All DML in this section runs against session-local TEMP
   tables seeded from the real tables, so the writeable-CTE syntax
   is genuinely tested with no side effects on the shared database.
   ------------------------------------------------------------ */
CREATE TEMP TABLE tmp_orders AS SELECT * FROM sales.orders LIMIT 500;
CREATE TEMP TABLE tmp_order_archive (LIKE sales.orders INCLUDING ALL);
CREATE TEMP TABLE tmp_customers AS SELECT * FROM customers.customers LIMIT 500;
CREATE TEMP TABLE tmp_audit_log (log_id SERIAL PRIMARY KEY, action TEXT, ref_id INT, logged_at TIMESTAMP DEFAULT now());
CREATE TEMP TABLE tmp_loyalty_members AS SELECT * FROM loyalty.members LIMIT 500;
ALTER TABLE tmp_loyalty_members ADD PRIMARY KEY (customer_id);
CREATE TEMP TABLE tmp_campaigns AS SELECT * FROM marketing.campaigns LIMIT 100;
CREATE TEMP TABLE tmp_refunds AS SELECT * FROM audit.refund_log LIMIT 200;
CREATE TEMP TABLE tmp_refund_archive (LIKE audit.refund_log INCLUDING ALL);
CREATE TEMP TABLE tmp_inventory AS SELECT * FROM products.inventory LIMIT 500;
CREATE TEMP TABLE tmp_shipments AS SELECT * FROM sales.shipments LIMIT 500;
CREATE TEMP TABLE tmp_delivery_log (log_id SERIAL PRIMARY KEY, shipment_id INT, delivered_at TIMESTAMP DEFAULT now());
CREATE TEMP TABLE tmp_email_welcome (log_id SERIAL PRIMARY KEY, customer_id INT, sent_at TIMESTAMP DEFAULT now());

/* Q76. */
WITH d AS (
  DELETE FROM tmp_orders WHERE order_status = 'Cancelled' RETURNING *
)
INSERT INTO tmp_order_archive SELECT * FROM d;

/* Q77. */
WITH ins AS (
  INSERT INTO tmp_audit_log (action, ref_id) VALUES ('order_created', 12345) RETURNING *
)
SELECT * FROM ins;

/* Q78. */
WITH upd AS (
  UPDATE tmp_orders SET order_status = 'Shipped' WHERE order_status = 'Processing' RETURNING order_id, order_status
)
SELECT * FROM upd LIMIT 50;

/* Q79. */
WITH a AS (
  INSERT INTO tmp_audit_log (action, ref_id) VALUES ('batch_start', 0) RETURNING log_id, action
),
b AS (
  DELETE FROM tmp_orders WHERE order_status = 'Failed' RETURNING order_id AS log_id, order_status AS action
)
SELECT log_id, action FROM a
UNION ALL
SELECT log_id, action FROM b;

/* Q80. */
WITH new_row AS (
  INSERT INTO tmp_audit_log (action, ref_id) VALUES ('signup', 999) RETURNING log_id
)
SELECT log_id FROM new_row;

/* Q81. */
WITH new_member AS (
  INSERT INTO tmp_loyalty_members (customer_id, tier_id, points_balance, join_date)
  SELECT customer_id, 1, 0, CURRENT_DATE
  FROM tmp_customers
  WHERE customer_id NOT IN (SELECT customer_id FROM tmp_loyalty_members)
  LIMIT 10
  RETURNING customer_id, join_date
)
SELECT * FROM new_member;

/* Q82. */
WITH flagged AS (
  UPDATE tmp_orders SET order_status = 'Cancelled' WHERE net_total > 100000 RETURNING order_id
)
INSERT INTO tmp_audit_log (action, ref_id) SELECT 'high_value_cancel', order_id FROM flagged;

/* Q83. */
WITH r AS (
  DELETE FROM tmp_refunds WHERE status = 'Failed' RETURNING *
)
INSERT INTO tmp_refund_archive SELECT * FROM r;

/* Q84. */
WITH new_signup AS (
  SELECT customer_id FROM tmp_customers ORDER BY registration_date DESC LIMIT 5
)
INSERT INTO tmp_email_welcome (customer_id) SELECT customer_id FROM new_signup RETURNING customer_id, sent_at;

/* Q85. */
WITH cancelled AS (
  UPDATE tmp_orders SET order_status = 'Cancelled' WHERE order_status = 'Processing' RETURNING order_id
)
INSERT INTO tmp_audit_log (action, ref_id) SELECT 'order_cancelled', order_id FROM cancelled;

/* Q86. */
WITH batch AS (
  SELECT order_id FROM tmp_orders WHERE order_status = 'Returned' LIMIT 100
)
DELETE FROM tmp_orders WHERE order_id IN (SELECT order_id FROM batch);

/* Q87. */
WITH batch AS (
  SELECT order_id FROM tmp_orders WHERE order_status = 'Shipped' LIMIT 100
)
UPDATE tmp_orders SET order_status = 'Delivered' WHERE order_id IN (SELECT order_id FROM batch);

/* Q88. */
WITH batch AS (
  SELECT customer_id FROM tmp_customers WHERE tier = 'Platinum' LIMIT 50
)
INSERT INTO tmp_audit_log (action, ref_id) SELECT 'platinum_review', customer_id FROM batch;

/* Q89. */
WITH dedup AS (
  SELECT DISTINCT ON (customer_id) customer_id, tier FROM tmp_customers ORDER BY customer_id
)
INSERT INTO tmp_audit_log (action, ref_id) SELECT 'dedup_customer', customer_id FROM dedup LIMIT 20;

/* Q90. */
WITH upsert AS (
  SELECT c.customer_id, t.tier_id
  FROM tmp_customers c, (SELECT tier_id FROM loyalty.tiers WHERE tier_name = 'Bronze') t
  WHERE c.customer_id NOT IN (SELECT customer_id FROM tmp_loyalty_members)
  LIMIT 5
)
INSERT INTO tmp_loyalty_members (customer_id, tier_id, points_balance, join_date)
SELECT customer_id, tier_id, 0, CURRENT_DATE FROM upsert
ON CONFLICT (customer_id) DO UPDATE SET tier_id = EXCLUDED.tier_id;

/* Q91. */
WITH soft_deleted AS (
  UPDATE tmp_orders SET order_status = 'Cancelled'
  WHERE order_id IN (SELECT order_id FROM tmp_orders ORDER BY order_id LIMIT 5)
  RETURNING order_id
)
INSERT INTO tmp_audit_log (action, ref_id) SELECT 'soft_delete', order_id FROM soft_deleted;

/* Q92. */
WITH transitioned AS (
  UPDATE tmp_orders SET order_status = 'Shipped' WHERE order_status = 'Processing' RETURNING order_id, order_status
)
INSERT INTO tmp_audit_log (action, ref_id) SELECT 'status_to_' || order_status, order_id FROM transitioned;

/* Q93. */
WITH upgrade AS (
  UPDATE tmp_loyalty_members SET tier_id = 3 WHERE points_balance > 5000 RETURNING customer_id, tier_id
)
SELECT * FROM upgrade LIMIT 50;

/* Q94. */
WITH redeemed AS (
  UPDATE tmp_loyalty_members SET points_balance = points_balance - 500 WHERE points_balance >= 500 RETURNING customer_id, points_balance
)
SELECT * FROM redeemed LIMIT 20;

/* Q95. */
WITH suspicious AS (
  SELECT order_id FROM tmp_orders WHERE net_total > 120000
)
INSERT INTO tmp_audit_log (action, ref_id) SELECT 'fraud_flag', order_id FROM suspicious;

/* Q96. */
WITH decremented AS (
  UPDATE tmp_inventory SET quantity_on_hand = quantity_on_hand - 1
  WHERE quantity_on_hand > 0
    AND (store_id, product_id) IN (SELECT store_id, product_id FROM tmp_inventory ORDER BY store_id, product_id LIMIT 5)
  RETURNING product_id, quantity_on_hand
)
INSERT INTO tmp_audit_log (action, ref_id) SELECT 'stock_decrement', product_id FROM decremented;

/* Q97. */
WITH delivered AS (
  UPDATE tmp_shipments SET status = 'Delivered' WHERE status = 'Shipped' RETURNING shipment_id
)
INSERT INTO tmp_delivery_log (shipment_id) SELECT shipment_id FROM delivered;

/* Q98. */
WITH returned AS (
  UPDATE tmp_orders SET order_status = 'Returned'
  WHERE order_id IN (SELECT order_id FROM tmp_orders ORDER BY order_id LIMIT 3)
  RETURNING order_id, net_total
)
INSERT INTO tmp_refund_archive (payment_id, order_id, amount, reason, refunded_at, status)
SELECT NULL, order_id, net_total, 'auto refund on return', now(), 'Pending' FROM returned;

/* Q99. */
WITH closed AS (
  UPDATE tmp_campaigns SET end_date = CURRENT_DATE WHERE end_date > CURRENT_DATE RETURNING campaign_id
)
INSERT INTO tmp_audit_log (action, ref_id) SELECT 'campaign_closed', campaign_id FROM closed;

/* Q100. */
WITH new_order AS (
  UPDATE tmp_orders SET order_status = 'Processing'
  WHERE order_id = (SELECT order_id FROM tmp_orders ORDER BY order_id LIMIT 1)
  RETURNING order_id, net_total
),
paid AS (
  INSERT INTO tmp_audit_log (action, ref_id) SELECT 'payment_recorded', order_id FROM new_order RETURNING ref_id
),
stock_adj AS (
  UPDATE tmp_inventory SET quantity_on_hand = quantity_on_hand - 1
  WHERE (store_id, product_id) = (SELECT store_id, product_id FROM tmp_inventory ORDER BY store_id, product_id LIMIT 1)
  RETURNING product_id
),
shipped AS (
  INSERT INTO tmp_audit_log (action, ref_id) SELECT 'shipment_created', ref_id FROM paid RETURNING ref_id
)
SELECT * FROM shipped;

/* ============================================================
   END OF CTEs (WITH, non-recursive) - EASY LEVEL (100 QUESTIONS)
============================================================ */
