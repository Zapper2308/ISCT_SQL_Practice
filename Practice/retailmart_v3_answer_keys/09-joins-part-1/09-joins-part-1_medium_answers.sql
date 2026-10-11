/* ============================================================
   ANSWER KEY - JOINs Part 1 (Foundations) (MEDIUM LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: JOIN DEEPER - CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1.  Because WHERE runs AFTER the join is computed, so filtering on a right-table column there discards every "no match" row LEFT JOIN produced (where that column is NULL) - the same filter belongs in the ON clause to preserve LEFT JOIN semantics. */
/* Q2.  Fan-out is when a JOIN multiplies left rows because each matches multiple right rows (e.g. one order joined to its many order_items) - you detect it by comparing COUNT(*) after the join to COUNT(DISTINCT left.id), a mismatch signals fan-out. */
/* Q3.  Because each left row is repeated once per matching right row, so COUNT(*) counts (left rows x matches), not distinct left entities - it over-counts whenever the join is one-to-many. */
/* Q4.  COUNT(left.id) counts non-NULL matched rows (excludes unmatched left rows where right columns, and thus nothing tied to left.id via the join output, are NULL only if left.id itself could be NULL, which is rare); COUNT(DISTINCT left.id) counts unique left entities regardless of how many right matches they have; COUNT(*) counts every output row including fan-out duplicates. */
/* Q5.  No, JOIN order doesn't change the final RESULT for INNER JOINs (they're commutative/associative); it CAN change performance, since PostgreSQL's planner picks a join order based on cost, though explicit order is just a hint it may reorder anyway. */
/* Q6.  JOIN ... USING(col) automatically collapses the duplicate join-key column into one output column; JOIN ... ON a.col = b.col keeps both a.col and b.col as separate columns in the result. */
/* Q7.  JOIN orders ON 1 = 1 is literally a CROSS JOIN written with a redundant always-true ON clause - it still produces every combination of rows from both tables, identical to CROSS JOIN. */
/* Q8.  Three causes: (1) a NULL in the join key on either side never matches anything, (2) a typo/wrong column in the ON clause silently returns 0 or few matches, (3) filtering a nullable right-table column in WHERE after what was meant to be an outer join. */
/* Q9.  Each of the 3 left rows is paired with the 1 matching right row where applicable and the other 2 (if unmatched) get NULLs - so a LEFT JOIN with 3 left rows and 1 matching right row produces at least 3 output rows, one right-filled and up to two NULL-filled depending on which left rows matched. */
/* Q10. Because comma-separated FROM lists don't distinguish INNER from OUTER joins, make it easy to forget a join condition (accidental CROSS JOIN), and mix join logic with filter logic in WHERE - explicit JOIN syntax keeps join conditions separate and intentional. */
/* Q11. A Cartesian explosion happens when you join tables without a matching condition (or with one that matches far more rows than intended), producing rows(A) x rows(B) - easy to trigger accidentally with a missing/wrong ON clause or comma-join with no WHERE link. */
/* Q12. LEFT JOIN + WHERE right.key IS NULL is usually more readable to SQL beginners since it "looks like a normal join"; NOT EXISTS is often faster (short-circuits per row, no need to build/scan a full join) and reads more like the actual intent ("no such row exists"). */
/* Q13. The planner picks Hash Join when one side is much smaller (builds an in-memory hash table from it) and there's no useful sort order already; Nested Loop when one side is tiny or there's a good index to probe per outer row - it estimates costs from row-count statistics either way. */
/* Q14. INNER JOIN's row count equals the smaller table's row count only when the join is one-to-one AND every row on the smaller side has exactly one match; it's smaller/larger otherwise depending on unmatched rows (fewer) or duplicate matches (fan-out, more). */
/* Q15. Because c1.id != c2.id with no other constraint pairs every customer with every OTHER customer (a near-Cartesian product), producing a huge, mostly meaningless result set - a red flag that the join lacks a real business condition. */
/* Q16. Because a self-join references the SAME table twice in the FROM clause, and without distinct aliases (e1, e2) PostgreSQL cannot tell which occurrence a column reference belongs to - it would be ambiguous. */
/* Q17. INNER JOIN returns matched rows WITH columns from both tables; SEMI JOIN (what EXISTS effectively becomes) only checks "does at least one match exist" and returns each outer row ONCE, without ever pulling columns from the inner table. */
/* Q18. An anti semi join returns outer rows that have NO match in the inner set (the internal implementation of NOT EXISTS / LEFT JOIN...IS NULL); PostgreSQL uses it automatically when it recognizes a NOT EXISTS or a LEFT JOIN + IS NULL anti-join pattern. */
/* Q19. Because NULL is never equal to anything (not even another NULL) under standard SQL comparison semantics, so a.key = b.key is never TRUE when either side is NULL - such rows can never satisfy an equi-join condition. */
/* Q20. INNER JOINs can be freely reordered by the planner without changing results (associative), but OUTER JOINs are NOT associative in general - swapping the order of a chain of LEFT/RIGHT/FULL JOINs can change which rows get NULLs, so order (and explicit parentheses) matters more. */
/* Q21. An EQUI JOIN compares columns with = (e.g. a.id = b.id); a non-equi JOIN uses any other operator like <, >, or BETWEEN - a RetailMart example: joining pay_slips to payroll.tax_brackets ON gross_salary BETWEEN min_salary AND max_salary. */
/* Q22. Putting b.y = 5 in the ON clause still lets unmatched-on-b.y left rows survive (with NULL right columns); putting it in WHERE discards those left rows entirely if b.y isn't 5 or is NULL, turning the LEFT JOIN into something closer to an INNER JOIN for that condition. */
/* Q23. USING(col) still requires you to specify exactly which shared column(s) to join on; NATURAL JOIN automatically joins on ALL identically-named columns in both tables - dangerous because adding an unrelated same-named column later (e.g. "created_at" in both tables) silently changes the join's meaning. */
/* Q24. GROUP BY operates on the JOIN's output rows (post-join), so "a row" being grouped is one combined row spanning all joined tables - grouping by a left-table column while a right-table join fanned it out will aggregate across duplicated left values unless pre-aggregated first. */
/* Q25. Because mixing an aggregate JOIN with further filtering/joining in the same SELECT gets hard to reason about (which stage is the aggregate happening at?) - wrapping the JOIN + GROUP BY in a CTE gives the aggregated result a name, making the outer query simpler to read and debug. */

/* ============================================================
   SECTION B: INNER JOIN + FILTER + GROUP BY (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT r.region_name, COUNT(*) AS order_count, SUM(o.net_total) AS total_revenue
FROM sales.orders o
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY r.region_name;

/* Q27. */
SELECT cat.category_name, COUNT(*) AS product_count
FROM products.products p
JOIN core.dim_brand b ON p.brand_id = b.brand_id
JOIN core.dim_category cat ON b.category_id = cat.category_id
GROUP BY cat.category_name;

/* Q28. */
SELECT b.brand_name, COUNT(*) AS product_count, AVG(p.price) AS avg_price
FROM products.products p
JOIN core.dim_brand b ON p.brand_id = b.brand_id
GROUP BY b.brand_name;

/* Q29. */
SELECT d.dept_name, COUNT(*) AS employee_count, AVG(e.salary) AS avg_salary
FROM stores.employees e
JOIN core.dim_department d ON e.dept_id = d.dept_id
GROUP BY d.dept_name;

/* Q30. */
SELECT tr.tier_name, COUNT(*) AS member_count, AVG(m.points_balance) AS avg_points
FROM loyalty.members m
JOIN loyalty.tiers tr ON m.tier_id = tr.tier_id
GROUP BY tr.tier_name;

/* Q31. */
SELECT c.customer_id, COUNT(*) AS lifetime_orders, SUM(o.net_total) AS total_spend
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY c.customer_id;

/* Q32. */
SELECT t.agent_id, COUNT(*) AS tickets_resolved,
       AVG(EXTRACT(EPOCH FROM (t.resolved_date - t.created_date))/3600.0) AS avg_resolution_hours
FROM support.tickets t
WHERE t.resolved_date IS NOT NULL
GROUP BY t.agent_id;

/* Q33. */
SELECT oi.prod_id, SUM(oi.quantity) AS total_quantity_sold
FROM sales.order_items oi
GROUP BY oi.prod_id;

/* Q34. */
SELECT r.region_name, SUM(o.net_total) AS total_revenue
FROM sales.orders o
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY r.region_name;

/* Q35. */
SELECT warehouse_id, SUM(quantity_on_hand) AS total_on_hand
FROM supply_chain.inventory_snapshots
WHERE snapshot_date = (SELECT MAX(snapshot_date) FROM supply_chain.inventory_snapshots)
GROUP BY warehouse_id;

/* Q36. */
SELECT sh.supplier_id, SUM(sh.quantity) AS total_quantity_shipped
FROM supply_chain.shipments sh
GROUP BY sh.supplier_id;

/* Q37. */
SELECT cat.category_name, SUM(oi.net_amount) AS revenue
FROM sales.order_items oi
JOIN products.products p ON oi.prod_id = p.product_id
JOIN core.dim_brand b ON p.brand_id = b.brand_id
JOIN core.dim_category cat ON b.category_id = cat.category_id
GROUP BY cat.category_name;

/* Q38. */
SELECT r.region_name, DATE_TRUNC('month', o.order_date) AS order_month, SUM(o.net_total) AS total_revenue
FROM sales.orders o
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY r.region_name, DATE_TRUNC('month', o.order_date)
ORDER BY r.region_name, order_month;

/* Q39. */
SELECT sh.courier_name, AVG(sh.delivered_date - sh.shipped_date) AS avg_delivery_days
FROM sales.shipments sh
JOIN sales.orders o ON sh.order_id = o.order_id
WHERE sh.delivered_date IS NOT NULL
GROUP BY sh.courier_name;

/* Q40. */
SELECT cl.agent_id, SUM(cl.call_duration_seconds) AS total_call_duration
FROM call_center.calls cl
JOIN stores.employees e ON cl.agent_id = e.employee_id
GROUP BY cl.agent_id;

/* Q41. */
SELECT warehouse_id, product_id, quantity_on_hand
FROM (
  SELECT i.warehouse_id, i.product_id, i.quantity_on_hand,
         ROW_NUMBER() OVER (PARTITION BY i.warehouse_id ORDER BY i.quantity_on_hand DESC) AS rn
  FROM supply_chain.inventory_snapshots i
  WHERE i.snapshot_date = (SELECT MAX(snapshot_date) FROM supply_chain.inventory_snapshots)
) ranked
WHERE rn <= 3
ORDER BY warehouse_id, quantity_on_hand DESC;

/* Q42. */
SELECT e.dept_id, e.store_id, COUNT(*) AS employee_count, AVG(e.salary) AS avg_salary
FROM stores.employees e
GROUP BY e.dept_id, e.store_id;

/* Q43. */
SELECT pv.device_type, c.tier, COUNT(*) AS view_count
FROM web_events.page_views pv
JOIN customers.customers c ON pv.customer_id = c.customer_id
GROUP BY pv.device_type, c.tier;

/* Q44. */
SELECT c.campaign_name, DATE_TRUNC('month', a.spend_date) AS spend_month, SUM(a.amount) AS total_spend
FROM marketing.ads_spend a
JOIN marketing.campaigns c ON a.campaign_id = c.campaign_id
GROUP BY c.campaign_name, DATE_TRUNC('month', a.spend_date)
ORDER BY c.campaign_name, spend_month;

/* Q45. */
SELECT category, status, COUNT(*) AS ticket_count
FROM support.tickets
GROUP BY category, status;

/* Q46. */
SELECT category, TO_CHAR(created_date, 'Day') AS day_of_week, COUNT(*) AS ticket_count
FROM support.tickets
GROUP BY category, TO_CHAR(created_date, 'Day');

/* Q47. */
SELECT r.region_name, SUM(o.net_total) AS total_revenue
FROM sales.orders o
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY r.region_name
ORDER BY total_revenue DESC
LIMIT 10;

/* Q48. */
SELECT b.brand_name, SUM(oi.net_amount) AS total_revenue
FROM sales.order_items oi
JOIN products.products p ON oi.prod_id = p.product_id
JOIN core.dim_brand b ON p.brand_id = b.brand_id
GROUP BY b.brand_name;

/* Q49. */
SELECT cat.category_name, SUM(oi.net_amount) AS total_revenue
FROM sales.order_items oi
JOIN products.products p ON oi.prod_id = p.product_id
JOIN core.dim_brand b ON p.brand_id = b.brand_id
JOIN core.dim_category cat ON b.category_id = cat.category_id
GROUP BY cat.category_name;

/* Q50. */
SELECT r.region_name, c.tier, COUNT(DISTINCT c.customer_id) AS distinct_customers
FROM sales.orders o
JOIN customers.customers c ON o.cust_id = c.customer_id
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY r.region_name, c.tier;

/* ============================================================
   SECTION C: LEFT JOIN EDGE CASES + ANTI-JOIN (25)
   ------------------------------------------------------------ */
/* Q51. */
SELECT d.dept_name, COUNT(e.employee_id) AS employee_count
FROM core.dim_department d
LEFT JOIN stores.employees e ON d.dept_id = e.dept_id
GROUP BY d.dept_name;

/* Q52. */
SELECT b.brand_name, COUNT(p.product_id) AS product_count
FROM core.dim_brand b
LEFT JOIN products.products p ON b.brand_id = p.brand_id
GROUP BY b.brand_name;

/* Q53. */
SELECT s.store_id, s.store_name, COUNT(o.order_id) AS order_count
FROM stores.stores s
LEFT JOIN sales.orders o ON s.store_id = o.store_id
GROUP BY s.store_id, s.store_name;

/* Q54. */
SELECT c.customer_id, COUNT(o.order_id) AS order_count
FROM customers.customers c
LEFT JOIN sales.orders o ON c.customer_id = o.cust_id
GROUP BY c.customer_id;

/* Q55. */
SELECT p.product_id, COALESCE(SUM(oi.net_amount), 0) AS total_net_sales
FROM products.products p
LEFT JOIN sales.order_items oi ON p.product_id = oi.prod_id
GROUP BY p.product_id;

/* Q56. */
SELECT tr.tier_name, COUNT(m.customer_id) AS member_count
FROM loyalty.tiers tr
LEFT JOIN loyalty.members m ON tr.tier_id = m.tier_id
GROUP BY tr.tier_name;

/* Q57. */
SELECT e.employee_id, COUNT(t.ticket_id) AS resolved_ticket_count
FROM stores.employees e
LEFT JOIN support.tickets t ON e.employee_id = t.agent_id AND t.status IN ('Resolved','Closed')
GROUP BY e.employee_id;

/* Q58. */
SELECT c.customer_id, COUNT(r.review_id) AS review_count
FROM customers.customers c
LEFT JOIN customers.reviews r ON c.customer_id = r.customer_id
GROUP BY c.customer_id;

/* Q59. */
SELECT r.region_name, COALESCE(SUM(o.net_total), 0) AS total_revenue
FROM core.dim_region r
LEFT JOIN stores.stores s ON r.region_id = s.region_id
LEFT JOIN sales.orders o ON s.store_id = o.store_id
GROUP BY r.region_name;

/* Q60. */
SELECT w.warehouse_id, COALESCE(SUM(isn.quantity_on_hand), 0) AS total_quantity
FROM supply_chain.warehouses w
LEFT JOIN supply_chain.inventory_snapshots isn ON w.warehouse_id = isn.warehouse_id
GROUP BY w.warehouse_id;

/* Q61. */
SELECT c.campaign_id, c.campaign_name, COALESCE(SUM(a.amount), 0) AS total_spend
FROM marketing.campaigns c
LEFT JOIN marketing.ads_spend a ON c.campaign_id = a.campaign_id
GROUP BY c.campaign_id, c.campaign_name;

/* Q62. */
SELECT c.customer_id
FROM customers.customers c
LEFT JOIN sales.orders o ON c.customer_id = o.cust_id
WHERE o.order_id IS NULL;

/* Q63. */
SELECT p.product_id
FROM products.products p
LEFT JOIN sales.order_items oi ON p.product_id = oi.prod_id
WHERE oi.order_item_id IS NULL;

/* Q64. */
SELECT s.store_id
FROM stores.stores s
LEFT JOIN sales.orders o ON s.store_id = o.store_id
WHERE o.order_id IS NULL;

/* Q65. */
SELECT b.brand_id
FROM core.dim_brand b
LEFT JOIN products.products p ON b.brand_id = p.brand_id
WHERE p.product_id IS NULL;

/* Q66. */
SELECT DISTINCT sup.supplier_id
FROM products.suppliers sup
JOIN products.products p ON p.supplier_id = sup.supplier_id
LEFT JOIN sales.order_items oi ON oi.prod_id = p.product_id
WHERE oi.order_item_id IS NULL
  AND sup.supplier_id NOT IN (
    SELECT p2.supplier_id FROM products.products p2
    JOIN sales.order_items oi2 ON oi2.prod_id = p2.product_id
  );

/* Q67. */
SELECT e.employee_id
FROM stores.employees e
LEFT JOIN support.tickets t ON e.employee_id = t.agent_id
WHERE t.ticket_id IS NULL;

/* Q68. */
SELECT DISTINCT c.customer_id
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
LEFT JOIN customers.reviews r ON r.customer_id = c.customer_id
WHERE r.review_id IS NULL;

/* Q69. */
SELECT c.customer_id
FROM customers.customers c
LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
LEFT JOIN customers.reviews r ON r.customer_id = c.customer_id
LEFT JOIN support.tickets t ON t.customer_id = c.customer_id
LEFT JOIN call_center.calls cl ON cl.customer_id = c.customer_id
WHERE o.order_id IS NULL AND r.review_id IS NULL AND t.ticket_id IS NULL AND cl.call_id IS NULL;

/* Q70. */
SELECT o.order_id
FROM sales.orders o
LEFT JOIN sales.shipments sh ON o.order_id = sh.order_id
WHERE sh.shipment_id IS NULL;

/* Q71. */
SELECT o.order_id
FROM sales.orders o
LEFT JOIN sales.payments p ON o.order_id = p.order_id
WHERE p.payment_id IS NULL;

/* Q72. */
SELECT ticket_id
FROM support.tickets
WHERE agent_id IS NULL;

/* Q73. */
SELECT w.warehouse_id
FROM supply_chain.warehouses w
LEFT JOIN supply_chain.shipments sh ON w.warehouse_id = sh.warehouse_id
WHERE sh.shipment_id IS NULL;

/* Q74. */
SELECT DISTINCT isn.product_id
FROM supply_chain.inventory_snapshots isn
LEFT JOIN supply_chain.shipments sh
  ON sh.product_id = isn.product_id
  AND sh.shipped_date >= (SELECT MAX(shipped_date) FROM supply_chain.shipments) - 90
WHERE sh.shipment_id IS NULL;

/* Q75. */
SELECT m.customer_id
FROM loyalty.members m
LEFT JOIN loyalty.redemptions r ON m.customer_id = r.customer_id
WHERE r.redemption_id IS NULL;

/* ============================================================
   SECTION D: MULTI-TABLE CHAINS (4-5 TABLES) (25)
   ------------------------------------------------------------ */
/* Q76. */
SELECT o.order_id, c.first_name || ' ' || c.last_name AS customer_name, s.store_name,
       p.product_name, oi.quantity, oi.net_amount
FROM sales.order_items oi
JOIN sales.orders o ON oi.order_id = o.order_id
JOIN customers.customers c ON o.cust_id = c.customer_id
JOIN stores.stores s ON o.store_id = s.store_id
JOIN products.products p ON oi.prod_id = p.product_id;

/* Q77. */
SELECT c.customer_id, SUM(o.net_total) AS total_spend, COUNT(DISTINCT o.store_id) AS distinct_stores
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY c.customer_id;

/* Q78. */
SELECT r.region_name, COUNT(DISTINCT c.customer_id) AS distinct_customers,
       COUNT(DISTINCT s.store_id) AS distinct_stores, SUM(o.net_total) AS total_revenue
FROM sales.orders o
JOIN customers.customers c ON o.cust_id = c.customer_id
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY r.region_name;

/* Q79. */
SELECT category_name, product_name, units_sold
FROM (
  SELECT cat.category_name, p.product_name, SUM(oi.quantity) AS units_sold,
         RANK() OVER (PARTITION BY cat.category_name ORDER BY SUM(oi.quantity) DESC) AS rnk
  FROM sales.order_items oi
  JOIN products.products p ON oi.prod_id = p.product_id
  JOIN core.dim_brand b ON p.brand_id = b.brand_id
  JOIN core.dim_category cat ON b.category_id = cat.category_id
  GROUP BY cat.category_name, p.product_name
) ranked
WHERE rnk = 1;

/* Q80. */
SELECT t.ticket_id, c.first_name AS customer_name, e.first_name AS agent_name, s.store_name
FROM support.tickets t
JOIN customers.customers c ON t.customer_id = c.customer_id
JOIN stores.employees e ON t.agent_id = e.employee_id
JOIN stores.stores s ON e.store_id = s.store_id;

/* Q81. */
SELECT cl.call_id, c.first_name AS customer_name, e.first_name AS agent_name, s.store_name
FROM call_center.calls cl
JOIN customers.customers c ON cl.customer_id = c.customer_id
JOIN stores.employees e ON cl.agent_id = e.employee_id
JOIN stores.stores s ON e.store_id = s.store_id;

/* Q82. */
SELECT wo.work_order_id, p.product_name, pl.line_name,
       (wo.end_timestamp - wo.start_timestamp) AS time_to_complete
FROM manufacture.work_orders wo
JOIN products.products p ON wo.product_id = p.product_id
JOIN manufacture.production_lines pl ON wo.line_id = pl.line_id;

/* Q83. */
SELECT pv.view_id, c.first_name, pv.os, pv.device_type
FROM web_events.page_views pv
JOIN customers.customers c ON pv.customer_id = c.customer_id;

/* Q84. */
SELECT a.spend_id, c.campaign_name, DATE_TRUNC('month', a.spend_date) AS spend_month, a.platform
FROM marketing.ads_spend a
JOIN marketing.campaigns c ON a.campaign_id = c.campaign_id;

/* Q85. */
SELECT rt.return_id, o.order_date, c.first_name AS customer_name, p.product_name
FROM sales.returns rt
JOIN sales.orders o ON rt.order_id = o.order_id
JOIN customers.customers c ON o.cust_id = c.customer_id
JOIN products.products p ON rt.prod_id = p.product_id;

/* Q86. */
SELECT sh.shipment_id, sh.courier_name, c.first_name AS customer_name, s.city
FROM sales.shipments sh
JOIN sales.orders o ON sh.order_id = o.order_id
JOIN customers.customers c ON o.cust_id = c.customer_id
JOIN stores.stores s ON o.store_id = s.store_id;

/* Q87. */
SELECT ps.pay_slip_id, e.first_name AS employee_name, d.dept_name, s.store_name
FROM payroll.pay_slips ps
JOIN stores.employees e ON ps.employee_id = e.employee_id
JOIN core.dim_department d ON e.dept_id = d.dept_id
JOIN stores.stores s ON e.store_id = s.store_id;

/* Q88. */
SELECT m.customer_id, c.first_name AS customer_name, tr.tier_name, cnt.lifetime_orders
FROM loyalty.members m
JOIN customers.customers c ON m.customer_id = c.customer_id
JOIN loyalty.tiers tr ON m.tier_id = tr.tier_id
LEFT JOIN (SELECT cust_id, COUNT(*) AS lifetime_orders FROM sales.orders GROUP BY cust_id) cnt
  ON cnt.cust_id = m.customer_id;

/* Q89. */
SELECT ex.expense_id, ec.category_name, ex.amount, DATE_TRUNC('month', ex.expense_date) AS expense_month
FROM finance.expenses ex
JOIN core.dim_expense_category ec ON ex.exp_cat_id = ec.exp_cat_id;

/* Q90. */
SELECT isn.warehouse_id, w.name AS warehouse_name, p.product_name, b.brand_name, cat.category_name
FROM supply_chain.inventory_snapshots isn
JOIN supply_chain.warehouses w ON isn.warehouse_id = w.warehouse_id
JOIN products.products p ON isn.product_id = p.product_id
JOIN core.dim_brand b ON p.brand_id = b.brand_id
JOIN core.dim_category cat ON b.category_id = cat.category_id;

/* Q91. */
SELECT sup.supplier_id, sup.city AS supplier_city,
       (SELECT COUNT(*) FROM products.products p WHERE p.supplier_id = sup.supplier_id) AS product_count,
       (SELECT COALESCE(SUM(sh.quantity), 0) FROM supply_chain.shipments sh WHERE sh.supplier_id = sup.supplier_id) AS total_quantity_shipped
FROM products.suppliers sup;

/* Q92. */
SELECT c.customer_id, c.first_name || ' ' || c.last_name AS customer_name,
       COALESCE(o.lifetime_orders, 0) AS lifetime_orders,
       COALESCE(o.total_spend, 0) AS total_spend,
       COALESCE(r.review_count, 0) AS review_count,
       COALESCE(t.ticket_count, 0) AS ticket_count
FROM customers.customers c
LEFT JOIN (SELECT cust_id, COUNT(*) AS lifetime_orders, SUM(net_total) AS total_spend FROM sales.orders GROUP BY cust_id) o
  ON o.cust_id = c.customer_id
LEFT JOIN (SELECT customer_id, COUNT(*) AS review_count FROM customers.reviews GROUP BY customer_id) r
  ON r.customer_id = c.customer_id
LEFT JOIN (SELECT customer_id, COUNT(*) AS ticket_count FROM support.tickets GROUP BY customer_id) t
  ON t.customer_id = c.customer_id;

/* Q93. */
SELECT s.store_id, s.store_name, r.region_name,
       COALESCE(emp.employee_count, 0) AS employee_count,
       COALESCE(ord.order_count, 0) AS order_count,
       COALESCE(ord.revenue, 0) AS revenue
FROM stores.stores s
JOIN core.dim_region r ON s.region_id = r.region_id
LEFT JOIN (SELECT store_id, COUNT(*) AS employee_count FROM stores.employees GROUP BY store_id) emp
  ON emp.store_id = s.store_id
LEFT JOIN (SELECT store_id, COUNT(*) AS order_count, SUM(net_total) AS revenue FROM sales.orders GROUP BY store_id) ord
  ON ord.store_id = s.store_id;

/* Q94. */
SELECT agent_id, SUM(tickets_handled) AS tickets_handled, SUM(calls_handled) AS calls_handled
FROM (
  SELECT agent_id, COUNT(*) AS tickets_handled, 0 AS calls_handled FROM support.tickets WHERE agent_id IS NOT NULL GROUP BY agent_id
  UNION ALL
  SELECT agent_id, 0, COUNT(*) FROM call_center.calls WHERE agent_id IS NOT NULL GROUP BY agent_id
) combined
GROUP BY agent_id;

/* Q95. */
SELECT cat.category_name, SUM(oi.net_amount) AS revenue
FROM sales.order_items oi
JOIN products.products p ON oi.prod_id = p.product_id
JOIN core.dim_brand b ON p.brand_id = b.brand_id
JOIN core.dim_category cat ON b.category_id = cat.category_id
JOIN sales.orders o ON oi.order_id = o.order_id
GROUP BY cat.category_name
ORDER BY revenue DESC
LIMIT 10;

/* Q96. */
SELECT a.city, SUM(o.net_total) AS total_spend
FROM sales.orders o
JOIN customers.customers c ON o.cust_id = c.customer_id
JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = TRUE
GROUP BY a.city
ORDER BY total_spend DESC
LIMIT 10;

/* Q97. */
SELECT sup.supplier_name, SUM(sh.quantity) AS total_quantity_shipped
FROM supply_chain.shipments sh
JOIN products.suppliers sup ON sh.supplier_id = sup.supplier_id
GROUP BY sup.supplier_name
ORDER BY total_quantity_shipped DESC
LIMIT 10;

/* Q98. */
SELECT endpoint, COUNT(*) AS request_count, AVG(response_time_ms) AS avg_response_time_ms
FROM audit.api_requests
GROUP BY endpoint;

/* Q99. */
SELECT cl.call_reason, AVG(tr.sentiment_score) AS avg_sentiment
FROM call_center.calls cl
JOIN call_center.transcripts tr ON tr.call_id = cl.call_id
GROUP BY cl.call_reason;

/* Q100. */
WITH first_items AS (
  SELECT order_id, prod_id,
         ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY order_item_id) AS rn
  FROM sales.order_items
)
SELECT o.order_id, c.first_name || ' ' || c.last_name AS customer_name, s.store_name,
       pay.payment_mode, sh.courier_name, p.product_name AS first_item_product
FROM sales.orders o
JOIN customers.customers c ON o.cust_id = c.customer_id
JOIN stores.stores s ON o.store_id = s.store_id
LEFT JOIN sales.payments pay ON pay.order_id = o.order_id
LEFT JOIN sales.shipments sh ON sh.order_id = o.order_id
LEFT JOIN first_items fi ON fi.order_id = o.order_id AND fi.rn = 1
LEFT JOIN products.products p ON fi.prod_id = p.product_id;

/* ============================================================
   END OF ANSWER KEY - JOINs Part 1 (Foundations) - MEDIUM LEVEL (100/100)
============================================================ */
