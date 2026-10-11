/* ============================================================
   ANSWER KEY - Subqueries Part 2 (Correlated & LATERAL) (EASY LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CORRELATED & LATERAL - CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1.  A correlated subquery references a column from its enclosing (outer) query, so its result can differ for every outer row. */
/* Q2.  A correlated subquery depends on the outer row and is conceptually re-run per row; an uncorrelated subquery has no reference to the outer query and is computed once. */
/* Q3.  LATERAL lets a subquery (or set-returning function) in FROM reference columns from FROM items listed before it, effectively running once per row of those earlier items - a "for each row, run this query" join. */
/* Q4.  CROSS JOIN LATERAL drops the outer row entirely if the lateral subquery returns no rows (like an inner join); LEFT JOIN LATERAL keeps the outer row with NULLs for the lateral columns when it returns no rows. */
/* Q5.  LATERAL evaluates its subquery once per outer row using that row's values, so it can only see FROM items that appear earlier in the same FROM clause - forward-only visibility. */
/* Q6.  Because LATERAL conceptually runs once per row of the preceding FROM item, its per-execution cost multiplied by the outer row count dominates total cost - an index on the correlated join column keeps each execution cheap. */
/* Q7.  LATERAL is required whenever the FROM-clause subquery needs a value from an earlier FROM item AND must return more than one row/column per outer row (e.g. "top 3 orders per customer") - a scalar subquery can't return multiple rows, and a plain subquery in FROM can't see outer rows at all. */
/* Q8.  Combining LATERAL with ORDER BY + LIMIT inside the subquery gives exactly N rows per outer row - the standard top-N-per-group pattern. */
/* Q9.  A correlated scalar subquery in SELECT returns one value per outer row; LATERAL in FROM can return multiple rows/columns per outer row, naturally fanning the result out as a real join rather than just an extra column. */
/* Q10. LATERAL can wrap either a derived subquery or a set-returning function/table; the join mechanics are identical either way - only what's inside the LATERAL(...) differs. */
/* Q11. Yes - a CTE's body can contain a LATERAL join, and a CTE can also be referenced as the earlier FROM item that a later LATERAL subquery correlates against. */
/* Q12. LATERAL generate_series(1, n) lets each outer row generate its own series length, driven by one of its own columns. */
/* Q13. LATERAL unnest(array_column) expands an array column into one row per element, correlated to that specific outer row. */
/* Q14. LATERAL jsonb_array_elements(json_column) expands a JSONB array column into one row per element for that outer row. */
/* Q15. Before window functions existed, there was no way to fetch "top N per group" without either a correlated subquery capped at one row or a self-join; LATERAL + ORDER BY + LIMIT was the only way to pull more than one row per group directly in FROM. */
/* Q16. Yes - if the LATERAL subquery returns multiple rows for an outer row, that outer row is duplicated once per matching lateral row, exactly like any other join. */
/* Q17. With CROSS JOIN LATERAL, if the subquery returns zero rows for an outer row, that outer row is dropped from the result entirely (same as an inner join). */
/* Q18. With LEFT JOIN LATERAL, if the subquery returns zero rows for an outer row, the outer row is still kept once, with all lateral-sourced columns set to NULL. */
/* Q19. LATERAL isn't valid directly in a DML target list, but the FROM/USING clause of an UPDATE/DELETE can itself contain a LATERAL join, letting the modification pull per-row data from a correlated subquery. */
/* Q20. LATERAL performs a real per-row join producing separate output rows/columns; row_to_json() (often paired with a scalar subquery) packs multiple values into one JSON value in a single output column - different shapes for the same underlying data. */
/* Q21. Yes - since LATERAL runs once per outer row, an index on the correlated join/filter column inside the lateral subquery turns each execution into a fast index lookup instead of a full scan, which matters enormously at scale. */
/* Q22. LATERAL isn't inherently faster than a scalar subquery when only one value is needed; it becomes necessary (and comparably fast) specifically when more than one row/column is needed per outer row. */
/* Q23. LATERAL is often more readable than a deeply correlated subquery because the "per outer row" query is written as a normal, self-contained SELECT with its own FROM/WHERE/ORDER BY, instead of being buried inside a scalar expression. */
/* Q24. An aggregate inside a LATERAL subquery (e.g. SUM/COUNT filtered by the outer row) computes freshly for each outer row, the same result as a correlated scalar subquery, just expressed as a joinable derived table. */
/* Q25. Unlike a scalar subquery (exactly one value), LATERAL can return an entire result set - multiple columns and multiple rows - per outer row, which then behaves like any other joined table in the rest of the query. */

/* ============================================================
   SECTION B: CORRELATED SUBQUERIES (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT order_id, cust_id,
       (SELECT COUNT(*) FROM sales.orders o2 WHERE o2.cust_id = o.cust_id) AS same_customer_order_count
FROM sales.orders o
LIMIT 200;

/* Q27. */
SELECT customer_id,
       (SELECT COUNT(*) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS order_count
FROM customers.customers c
LIMIT 200;

/* Q28. */
SELECT product_id,
       (SELECT AVG(rating) FROM customers.reviews r WHERE r.product_id = p.product_id) AS avg_rating
FROM products.products p
LIMIT 500;

/* Q29. */
SELECT store_id,
       (SELECT COUNT(*) FROM stores.employees e WHERE e.store_id = s.store_id) AS employee_count
FROM stores.stores s;

/* Q30. */
SELECT campaign_id,
       (SELECT SUM(amount) FROM marketing.ads_spend a WHERE a.campaign_id = c.campaign_id) AS total_spend
FROM marketing.campaigns c;

/* Q31. */
SELECT customer_id,
       (SELECT MAX(order_date) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS last_order_date
FROM customers.customers c
LIMIT 200;

/* Q32. */
SELECT product_id,
       (SELECT MAX(review_date) FROM customers.reviews r WHERE r.product_id = p.product_id) AS last_review_date
FROM products.products p
LIMIT 500;

/* Q33. */
SELECT ticket_id, customer_id,
       (SELECT COUNT(*) FROM support.tickets t2 WHERE t2.customer_id = t.customer_id AND t2.ticket_id <> t.ticket_id) AS related_ticket_count
FROM support.tickets t
LIMIT 500;

/* Q34. */
SELECT employee_id,
       (SELECT ps.payment_date FROM payroll.pay_slips ps WHERE ps.employee_id = e.employee_id ORDER BY ps.payment_date DESC LIMIT 1) AS latest_payslip_date
FROM stores.employees e
LIMIT 300;

/* Q35. */
SELECT shipment_id,
       (SELECT c.email FROM sales.orders o JOIN customers.customers c ON c.customer_id = o.cust_id WHERE o.order_id = s.order_id) AS customer_email
FROM sales.shipments s
LIMIT 300;

/* Q36. */
SELECT c.* FROM customers.customers c
WHERE c.customer_id IN (SELECT cust_id FROM sales.orders GROUP BY cust_id HAVING COUNT(*) > 5);

/* Q37. */
SELECT c.* FROM customers.customers c
WHERE EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id);

/* Q38. */
SELECT p.* FROM products.products p
WHERE p.product_id IN (SELECT product_id FROM customers.reviews GROUP BY product_id HAVING AVG(rating) < 3);

/* Q39. */
SELECT * FROM (SELECT * FROM sales.orders LIMIT 300) o
WHERE o.net_total > (SELECT AVG(o2.net_total) FROM sales.orders o2 WHERE o2.cust_id = o.cust_id);

/* Q40. */
SELECT * FROM stores.employees e
WHERE e.salary > (SELECT AVG(e2.salary) FROM stores.employees e2 WHERE e2.dept_id = e.dept_id);

/* Q41. */
SELECT c.* FROM customers.customers c
WHERE c.customer_id IN (
  SELECT cust_id FROM sales.orders GROUP BY cust_id
  HAVING MAX(order_date) >= (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '30 days'
);

/* Q42. */
SELECT p.* FROM products.products p
WHERE p.product_id IN (
  SELECT product_id FROM customers.reviews GROUP BY product_id
  HAVING MAX(review_date) >= (SELECT MAX(review_date) FROM customers.reviews) - INTERVAL '30 days'
);

/* Q43. */
SELECT * FROM (SELECT * FROM support.tickets LIMIT 500) t
WHERE (SELECT COUNT(*) FROM support.tickets t2 WHERE t2.customer_id = t.customer_id AND t2.ticket_id <> t.ticket_id) = 0;

/* Q44. */
SELECT * FROM (SELECT * FROM customers.reviews LIMIT 500) r
WHERE r.rating < (SELECT AVG(r2.rating) FROM customers.reviews r2 WHERE r2.customer_id = r.customer_id);

/* Q45. */
SELECT * FROM (SELECT * FROM sales.orders LIMIT 300) o
WHERE o.net_total < (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total) FROM sales.orders o2 WHERE o2.store_id = o.store_id);

/* Q46. */
BEGIN;
UPDATE customers.customers c
SET tier = (SELECT tr.tier_name FROM loyalty.members m JOIN loyalty.tiers tr ON tr.tier_id = m.tier_id WHERE m.customer_id = c.customer_id)
WHERE c.customer_id = 1;
ROLLBACK;

/* Q47. */
BEGIN;
DELETE FROM sales.order_items oi
WHERE NOT EXISTS (SELECT 1 FROM sales.orders o WHERE o.order_id = oi.order_id);
ROLLBACK;

/* Q48. */
SELECT * FROM customers.customers c
WHERE EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id AND o.order_status = 'Cancelled');

/* Q49. */
SELECT * FROM customers.customers c
WHERE NOT EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id);

/* Q50. */
SELECT c.customer_id,
       (SELECT COALESCE(SUM(o.net_total),0) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS lifetime_spend
FROM customers.customers c
LIMIT 300;

/* ============================================================
   SECTION C: LATERAL BASICS (25)
   ------------------------------------------------------------ */
/* Q51. */
SELECT c.customer_id, oc.order_count
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT COUNT(*) AS order_count FROM sales.orders o WHERE o.cust_id = c.customer_id
) oc
LIMIT 300;

/* Q52. */
SELECT c.customer_id, lo.order_id, lo.order_date
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id, order_date FROM sales.orders o WHERE o.cust_id = c.customer_id
  ORDER BY order_date DESC LIMIT 1
) lo
LIMIT 300;

/* Q53. */
SELECT p.product_id, lr.review_id, lr.review_date
FROM products.products p
CROSS JOIN LATERAL (
  SELECT review_id, review_date FROM customers.reviews r WHERE r.product_id = p.product_id
  ORDER BY review_date DESC LIMIT 1
) lr
LIMIT 500;

/* Q54. */
SELECT s.store_id, ec.employee_count
FROM stores.stores s
CROSS JOIN LATERAL (
  SELECT COUNT(*) AS employee_count FROM stores.employees e WHERE e.store_id = s.store_id
) ec;

/* Q55. */
SELECT c.campaign_id, sp.total_spend
FROM marketing.campaigns c
CROSS JOIN LATERAL (
  SELECT COALESCE(SUM(amount),0) AS total_spend FROM marketing.ads_spend a WHERE a.campaign_id = c.campaign_id
) sp;

/* Q56. */
SELECT r.region_id, rv.total_revenue
FROM core.dim_region r
CROSS JOIN LATERAL (
  SELECT COALESCE(SUM(o.net_total),0) AS total_revenue
  FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id
  WHERE s.region_id = r.region_id
) rv;

/* Q57. */
SELECT e.employee_id AS agent_id, tc.ticket_count
FROM stores.employees e
CROSS JOIN LATERAL (
  SELECT COUNT(*) AS ticket_count FROM support.tickets t WHERE t.agent_id = e.employee_id
) tc
LIMIT 300;

/* Q58. */
SELECT w.warehouse_id, ls.snapshot_date
FROM supply_chain.warehouses w
CROSS JOIN LATERAL (
  SELECT snapshot_date FROM supply_chain.inventory_snapshots s WHERE s.warehouse_id = w.warehouse_id
  ORDER BY snapshot_date DESC LIMIT 1
) ls;

/* Q59. */
SELECT s.supplier_id, pc.product_count
FROM products.suppliers s
CROSS JOIN LATERAL (
  SELECT COUNT(*) AS product_count FROM products.products p WHERE p.supplier_id = s.supplier_id
) pc;

/* Q60. */
SELECT DISTINCT sh.courier_name, dt.avg_days
FROM sales.shipments sh
CROSS JOIN LATERAL (
  SELECT AVG(delivered_date - shipped_date) AS avg_days
  FROM sales.shipments sh2
  WHERE sh2.courier_name = sh.courier_name AND sh2.delivered_date IS NOT NULL
) dt;

/* Q61. */
SELECT c.customer_id, lo.order_id
FROM customers.customers c
LEFT JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY order_date DESC LIMIT 1
) lo ON TRUE
LIMIT 300;

/* Q62. */
SELECT c.customer_id, lo.order_id, lo.order_date, lo.net_total
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id, order_date, net_total FROM sales.orders o WHERE o.cust_id = c.customer_id
  ORDER BY order_date DESC LIMIT 1
) lo
LIMIT 300;

/* Q63. */
SELECT c.customer_id, big.order_id, big.net_total
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id, net_total FROM sales.orders o WHERE o.cust_id = c.customer_id AND o.net_total > 50000
) big
LIMIT 300;

/* Q64. */
SELECT c.customer_id, top.order_id, top.net_total
FROM (SELECT * FROM customers.customers LIMIT 50) c
CROSS JOIN LATERAL (
  SELECT order_id, net_total FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY net_total DESC
) top;

/* Q65. */
SELECT c.customer_id, top3.order_id, top3.net_total
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id, net_total FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY net_total DESC LIMIT 3
) top3
LIMIT 300;

/* Q66. */
SELECT c.customer_id, agg.total_spend
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT COALESCE(SUM(net_total),0) AS total_spend FROM sales.orders o WHERE o.cust_id = c.customer_id
) agg
LIMIT 300;

/* Q67. */
SELECT c.customer_id, lo.order_id
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.cust_id = c.customer_id AND o.order_status = 'Cancelled' LIMIT 1
) lo
LIMIT 300;

/* Q68. */
SELECT c.customer_id, gs.n
FROM (SELECT * FROM customers.customers LIMIT 5) c
CROSS JOIN LATERAL generate_series(1, 3) AS gs(n);

/* Q69. */
SELECT t.campaign_id, plat.platform
FROM (SELECT DISTINCT campaign_id FROM marketing.ads_spend LIMIT 5) t
CROSS JOIN LATERAL unnest(ARRAY['Google','Facebook','Instagram']) AS plat(platform);

/* Q70. */
SELECT x.id, elem.value
FROM (SELECT 1 AS id, '["a","b","c"]'::jsonb AS tags) x
CROSS JOIN LATERAL jsonb_array_elements_text(x.tags) AS elem(value);

/* Q71. */
SELECT c.customer_id, lo.order_id, li.prod_id
FROM (SELECT * FROM customers.customers LIMIT 50) c
CROSS JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY order_date DESC LIMIT 1
) lo
CROSS JOIN LATERAL (
  SELECT prod_id FROM sales.order_items oi WHERE oi.order_id = lo.order_id LIMIT 1
) li;

/* Q72. */
SELECT * FROM (
  SELECT c.customer_id, lo.order_id
  FROM customers.customers c
  CROSS JOIN LATERAL (
    SELECT order_id FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY order_date DESC LIMIT 1
  ) lo
) x
LIMIT 300;

/* Q73. */
SELECT c.customer_id, seg.segment
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT CASE WHEN SUM(o.net_total) > 100000 THEN 'VIP' ELSE 'Regular' END AS segment
  FROM sales.orders o WHERE o.cust_id = c.customer_id
) seg
LIMIT 300;

/* Q74. */
SELECT c.customer_id, ex.has_returns
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT EXISTS (
    SELECT 1 FROM sales.returns rt JOIN sales.orders o ON o.order_id = rt.order_id WHERE o.cust_id = c.customer_id
  ) AS has_returns
) ex
LIMIT 300;

/* Q75. */
WITH latest_orders AS (
  SELECT c.customer_id, lo.order_id, lo.order_date
  FROM customers.customers c
  CROSS JOIN LATERAL (
    SELECT order_id, order_date FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY order_date DESC LIMIT 1
  ) lo
)
SELECT * FROM latest_orders LIMIT 300;

/* ============================================================
   SECTION D: TOP-N PER GROUP (25)
   ------------------------------------------------------------ */
/* Q76. */
SELECT c.customer_id, t.order_id, t.net_total
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id, net_total FROM sales.orders o WHERE o.cust_id = c.customer_id
  ORDER BY net_total DESC LIMIT 3
) t
LIMIT 300;

/* Q77. */
SELECT c.customer_id, t.order_id, t.order_date
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id, order_date FROM sales.orders o WHERE o.cust_id = c.customer_id
  ORDER BY order_date DESC LIMIT 5
) t
LIMIT 300;

/* Q78. */
SELECT c.customer_id, t.order_id, t.order_date
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id, order_date FROM sales.orders o WHERE o.cust_id = c.customer_id
  ORDER BY order_date ASC LIMIT 3
) t
LIMIT 300;

/* Q79. */
SELECT r.region_id, t.store_id, t.revenue
FROM core.dim_region r
CROSS JOIN LATERAL (
  SELECT s.store_id, SUM(o.net_total) AS revenue
  FROM stores.stores s JOIN sales.orders o ON o.store_id = s.store_id
  WHERE s.region_id = r.region_id
  GROUP BY s.store_id
  ORDER BY revenue DESC LIMIT 5
) t;

/* Q80. */
SELECT cat.category_name, t.product_id, t.units
FROM core.dim_category cat
CROSS JOIN LATERAL (
  SELECT p.product_id, SUM(oi.quantity) AS units
  FROM products.products p
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN sales.order_items oi ON oi.prod_id = p.product_id
  WHERE b.category_id = cat.category_id
  GROUP BY p.product_id
  ORDER BY units DESC LIMIT 3
) t;

/* Q81. */
SELECT b.brand_id, t.product_id, t.revenue
FROM core.dim_brand b
CROSS JOIN LATERAL (
  SELECT p.product_id, SUM(oi.net_amount) AS revenue
  FROM products.products p JOIN sales.order_items oi ON oi.prod_id = p.product_id
  WHERE p.brand_id = b.brand_id
  GROUP BY p.product_id
  ORDER BY revenue DESC LIMIT 5
) t;

/* Q82. */
SELECT e.employee_id AS agent_id, t.ticket_id, t.priority
FROM stores.employees e
CROSS JOIN LATERAL (
  SELECT ticket_id, priority FROM support.tickets tk WHERE tk.agent_id = e.employee_id
  ORDER BY CASE priority WHEN 'Critical' THEN 1 WHEN 'High' THEN 2 WHEN 'Medium' THEN 3 ELSE 4 END
  LIMIT 3
) t
LIMIT 300;

/* Q83. */
SELECT plat.platform, t.campaign_id, t.spend
FROM (SELECT DISTINCT platform FROM marketing.ads_spend) plat
CROSS JOIN LATERAL (
  SELECT campaign_id, SUM(amount) AS spend
  FROM marketing.ads_spend a WHERE a.platform = plat.platform
  GROUP BY campaign_id
  ORDER BY spend DESC LIMIT 5
) t;

/* Q84. */
SELECT s.supplier_id, t.shipment_id, t.shipped_date
FROM products.suppliers s
CROSS JOIN LATERAL (
  SELECT shipment_id, shipped_date FROM supply_chain.shipments sh WHERE sh.supplier_id = s.supplier_id
  ORDER BY shipped_date DESC LIMIT 3
) t;

/* Q85. */
SELECT w.warehouse_id, t.product_id, t.quantity_on_hand
FROM supply_chain.warehouses w
CROSS JOIN LATERAL (
  SELECT product_id, quantity_on_hand FROM supply_chain.inventory_snapshots s
  WHERE s.warehouse_id = w.warehouse_id
  ORDER BY snapshot_date DESC, quantity_on_hand DESC LIMIT 5
) t;

/* Q86. */
SELECT d.dept_id, t.employee_id, t.salary
FROM core.dim_department d
CROSS JOIN LATERAL (
  SELECT employee_id, salary FROM stores.employees e WHERE e.dept_id = d.dept_id
  ORDER BY salary DESC LIMIT 3
) t;

/* Q87. */
SELECT s.store_id, t.employee_id, t.ticket_count
FROM stores.stores s
CROSS JOIN LATERAL (
  SELECT e.employee_id, COUNT(tk.ticket_id) AS ticket_count
  FROM stores.employees e
  LEFT JOIN support.tickets tk ON tk.agent_id = e.employee_id
  WHERE e.store_id = s.store_id
  GROUP BY e.employee_id
  ORDER BY ticket_count DESC LIMIT 1
) t;

/* Q88. */
SELECT r.call_reason, t.call_id, t.call_duration_seconds
FROM (SELECT DISTINCT call_reason FROM call_center.calls) r
CROSS JOIN LATERAL (
  SELECT call_id, call_duration_seconds FROM call_center.calls c WHERE c.call_reason = r.call_reason
  ORDER BY call_duration_seconds DESC LIMIT 1
) t;

/* Q89. */
SELECT sess.session_id, t.page_url, t.view_timestamp
FROM (SELECT DISTINCT session_id FROM web_events.page_views LIMIT 200) sess
CROSS JOIN LATERAL (
  SELECT page_url, view_timestamp FROM web_events.page_views pv WHERE pv.session_id = sess.session_id
  ORDER BY view_timestamp DESC LIMIT 1
) t;

/* Q90. */
SELECT coh.cohort_month, t.customer_id, t.ltv
FROM (SELECT DISTINCT DATE_TRUNC('month', registration_date) AS cohort_month FROM customers.customers) coh
CROSS JOIN LATERAL (
  SELECT c.customer_id, COALESCE(SUM(o.net_total),0) AS ltv
  FROM customers.customers c
  LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
  WHERE DATE_TRUNC('month', c.registration_date) = coh.cohort_month
  GROUP BY c.customer_id
  ORDER BY ltv DESC LIMIT 1
) t;

/* Q91. */
SELECT r.region_id, t.city, t.order_count
FROM core.dim_region r
CROSS JOIN LATERAL (
  SELECT s.city, COUNT(*) AS order_count
  FROM stores.stores s JOIN sales.orders o ON o.store_id = s.store_id
  WHERE s.region_id = r.region_id
  GROUP BY s.city
  ORDER BY order_count DESC LIMIT 3
) t;

/* Q92. */
SELECT tr.tier_name, t.customer_id, t.spend
FROM loyalty.tiers tr
CROSS JOIN LATERAL (
  SELECT m.customer_id, COALESCE(SUM(o.net_total),0) AS spend
  FROM loyalty.members m
  LEFT JOIN sales.orders o ON o.cust_id = m.customer_id
  WHERE m.tier_id = tr.tier_id
  GROUP BY m.customer_id
  ORDER BY spend DESC LIMIT 5
) t;

/* Q93. */
SELECT cat.category_name, t.brand_name, t.revenue
FROM core.dim_category cat
CROSS JOIN LATERAL (
  SELECT b.brand_name, SUM(oi.net_amount) AS revenue
  FROM core.dim_brand b
  JOIN products.products p ON p.brand_id = b.brand_id
  JOIN sales.order_items oi ON oi.prod_id = p.product_id
  WHERE b.category_id = cat.category_id
  GROUP BY b.brand_name
  ORDER BY revenue DESC LIMIT 3
) t;

/* Q94. */
SELECT w.warehouse_id, t.snapshot_date
FROM supply_chain.warehouses w
CROSS JOIN LATERAL (
  SELECT snapshot_date FROM supply_chain.inventory_snapshots s WHERE s.warehouse_id = w.warehouse_id
  ORDER BY snapshot_date ASC LIMIT 1
) t;

/* Q95. */
SELECT c.courier_name, t.shipment_id, t.transit_days
FROM (SELECT DISTINCT courier_name FROM sales.shipments) c
CROSS JOIN LATERAL (
  SELECT shipment_id, delivered_date - shipped_date AS transit_days
  FROM sales.shipments sh WHERE sh.courier_name = c.courier_name AND sh.delivered_date IS NOT NULL
  ORDER BY transit_days ASC LIMIT 1
) t;

/* Q96. */
SELECT c.campaign_id, t.sent_date, t.emails_clicked
FROM marketing.campaigns c
CROSS JOIN LATERAL (
  SELECT sent_date, emails_clicked FROM marketing.email_clicks e WHERE e.campaign_id = c.campaign_id
  ORDER BY emails_clicked DESC LIMIT 1
) t;

/* Q97. */
SELECT c.customer_id, t.source, t.event_date
FROM (SELECT * FROM customers.customers LIMIT 200) c
CROSS JOIN LATERAL (
  SELECT source, event_date FROM (
    SELECT 'order' AS source, order_date AS event_date FROM sales.orders o WHERE o.cust_id = c.customer_id
    UNION ALL
    SELECT 'ticket', created_date::date FROM support.tickets tk WHERE tk.customer_id = c.customer_id
    UNION ALL
    SELECT 'review', review_date FROM customers.reviews r WHERE r.customer_id = c.customer_id
  ) all_events
  ORDER BY event_date DESC LIMIT 1
) t;

/* Q98. */
SELECT p.product_id, t.cust_id, t.order_date
FROM (SELECT * FROM products.products LIMIT 300) p
CROSS JOIN LATERAL (
  SELECT o.cust_id, o.order_date
  FROM sales.order_items oi JOIN sales.orders o ON o.order_id = oi.order_id
  WHERE oi.prod_id = p.product_id
  ORDER BY o.order_date ASC LIMIT 1
) t;

/* Q99. */
SELECT e.employee_id AS agent_id, t.ticket_id, t.resolved_date
FROM stores.employees e
CROSS JOIN LATERAL (
  SELECT ticket_id, resolved_date FROM support.tickets tk
  WHERE tk.agent_id = e.employee_id AND tk.status = 'Resolved'
  ORDER BY resolved_date ASC LIMIT 1
) t
LIMIT 300;

/* Q100. */
SELECT r.region_id, mo.month, t.store_id, t.revenue
FROM core.dim_region r
CROSS JOIN LATERAL (SELECT DISTINCT DATE_TRUNC('month', order_date) AS month FROM sales.orders) mo
CROSS JOIN LATERAL (
  SELECT s.store_id, SUM(o.net_total) AS revenue
  FROM stores.stores s JOIN sales.orders o ON o.store_id = s.store_id
  WHERE s.region_id = r.region_id AND DATE_TRUNC('month', o.order_date) = mo.month
  GROUP BY s.store_id
  ORDER BY revenue DESC LIMIT 1
) t
LIMIT 200;

/* ============================================================
   END OF ANSWER KEY - Subqueries Part 2 (Correlated & LATERAL) - EASY LEVEL (100/100)
============================================================ */
