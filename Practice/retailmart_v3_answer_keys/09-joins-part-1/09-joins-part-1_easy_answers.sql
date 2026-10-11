/* ============================================================
   ANSWER KEY - JOINs Part 1 (Foundations) (EASY LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: JOIN CONCEPTUAL (10)
   ------------------------------------------------------------ */
/* Q1.  INNER JOIN keeps only rows that match in BOTH tables; LEFT JOIN keeps every row from the left table plus matches from the right (NULL when there's no match). */
/* Q2.  Whenever a left-table row has no matching row in the right table on the ON condition - every right-side column for that row comes back as NULL. */
/* Q3.  RIGHT JOIN B is exactly LEFT JOIN with the table order swapped (B LEFT JOIN A) - since you can always rewrite it as a LEFT JOIN, most teams standardize on LEFT JOIN for readability. */
/* Q4.  LEFT JOIN table_a a LEFT JOIN table_b b ON a.key = b.key WHERE b.key IS NULL - this keeps only left rows that had NO match in table_b, i.e. "rows in A with nothing in B". */
/* Q5.  Without ON, PostgreSQL doesn't know which columns relate the two tables, so JOIN with no ON/USING is rejected as a syntax error (except a true CROSS JOIN, which explicitly needs no condition). */
/* Q6.  JOIN ... ON lets you write any condition and keeps both tables' key columns separately in the result; JOIN ... USING(col) requires identical column names on both sides and collapses them into a single output column. */
/* Q7.  It silently turns the LEFT JOIN into an INNER JOIN, because WHERE runs after the join and discards any row where that right-side column is NULL (including the legitimate "no match" rows LEFT JOIN was meant to keep). */
/* Q8.  Because each left row can match multiple right rows, so COUNT(*) counts one row per MATCH, not per distinct left-side entity - a customer with 5 orders would be counted 5 times. */
/* Q9.  sales.order_items.prod_id -> products.products.product_id -> products.products.brand_id -> core.dim_brand.brand_id -> core.dim_brand.category_id -> core.dim_category.category_id. */
/* Q10. Qualifying every column avoids "ambiguous column" errors when multiple joined tables share a column name (like customer_id), and makes the query self-documenting about where each column comes from. */

/* ============================================================
   SECTION B: INNER JOIN - 2 TABLES (30)
   ------------------------------------------------------------ */
/* Q11. */
SELECT o.order_id, c.first_name
FROM sales.orders o
JOIN customers.customers c ON o.cust_id = c.customer_id;

/* Q12. */
SELECT o.order_id, s.store_name
FROM sales.orders o
JOIN stores.stores s ON o.store_id = s.store_id;

/* Q13. */
SELECT oi.order_item_id, p.product_name
FROM sales.order_items oi
JOIN products.products p ON oi.prod_id = p.product_id;

/* Q14. */
SELECT e.employee_id, d.dept_name
FROM stores.employees e
JOIN core.dim_department d ON e.dept_id = d.dept_id;

/* Q15. */
SELECT s.store_id, r.region_name
FROM stores.stores s
JOIN core.dim_region r ON s.region_id = r.region_id;

/* Q16. */
SELECT p.product_id, b.brand_name
FROM products.products p
JOIN core.dim_brand b ON p.brand_id = b.brand_id;

/* Q17. */
SELECT b.brand_id, cat.category_name
FROM core.dim_brand b
JOIN core.dim_category cat ON b.category_id = cat.category_id;

/* Q18. */
SELECT r.review_id, c.first_name || ' ' || c.last_name AS full_name
FROM customers.reviews r
JOIN customers.customers c ON r.customer_id = c.customer_id;

/* Q19. */
SELECT t.ticket_id, c.email
FROM support.tickets t
JOIN customers.customers c ON t.customer_id = c.customer_id;

/* Q20. */
SELECT t.ticket_id, e.first_name || ' ' || e.last_name AS agent_name
FROM support.tickets t
JOIN stores.employees e ON t.agent_id = e.employee_id;

/* Q21. */
SELECT m.customer_id, tr.tier_name
FROM loyalty.members m
JOIN loyalty.tiers tr ON m.tier_id = tr.tier_id;

/* Q22. */
SELECT lr.redemption_id, c.first_name || ' ' || c.last_name AS customer_name
FROM loyalty.redemptions lr
JOIN customers.customers c ON lr.customer_id = c.customer_id;

/* Q23. */
SELECT p.payment_id, o.order_status
FROM sales.payments p
JOIN sales.orders o ON p.order_id = o.order_id;

/* Q24. */
SELECT sh.shipment_id, o.net_total
FROM sales.shipments sh
JOIN sales.orders o ON sh.order_id = o.order_id;

/* Q25. */
SELECT r.return_id, o.order_date
FROM sales.returns r
JOIN sales.orders o ON r.order_id = o.order_id;

/* Q26. */
SELECT cl.call_id, c.first_name || ' ' || c.last_name AS customer_name
FROM call_center.calls cl
JOIN customers.customers c ON cl.customer_id = c.customer_id;

/* Q27. */
SELECT cl.call_id, e.first_name || ' ' || e.last_name AS agent_name
FROM call_center.calls cl
JOIN stores.employees e ON cl.agent_id = e.employee_id;

/* Q28. */
SELECT sh.shipment_id, w.name AS warehouse_name
FROM supply_chain.shipments sh
JOIN supply_chain.warehouses w ON sh.warehouse_id = w.warehouse_id;

/* Q29. */
SELECT sh.shipment_id, sup.supplier_name
FROM supply_chain.shipments sh
JOIN products.suppliers sup ON sh.supplier_id = sup.supplier_id;

/* Q30. */
SELECT isn.warehouse_id, w.name AS warehouse_name, isn.snapshot_date
FROM supply_chain.inventory_snapshots isn
JOIN supply_chain.warehouses w ON isn.warehouse_id = w.warehouse_id;

/* Q31. */
SELECT wo.work_order_id, pl.line_name
FROM manufacture.work_orders wo
JOIN manufacture.production_lines pl ON wo.line_id = pl.line_id;

/* Q32. */
SELECT tr.transcript_id, cl.call_reason
FROM call_center.transcripts tr
JOIN call_center.calls cl ON tr.call_id = cl.call_id;

/* Q33. */
SELECT ps.pay_slip_id, e.first_name
FROM payroll.pay_slips ps
JOIN stores.employees e ON ps.employee_id = e.employee_id;

/* Q34. */
SELECT a.attendance_id, e.role
FROM hr.attendance a
JOIN stores.employees e ON a.employee_id = e.employee_id;

/* Q35. */
SELECT ex.expense_id, ec.category_name
FROM finance.expenses ex
JOIN core.dim_expense_category ec ON ex.exp_cat_id = ec.exp_cat_id;

/* Q36. */
SELECT o.order_id, c.tier
FROM sales.orders o
JOIN customers.customers c ON o.cust_id = c.customer_id;

/* Q37. */
SELECT pv.view_id, c.first_name
FROM web_events.page_views pv
JOIN customers.customers c ON pv.customer_id = c.customer_id;

/* Q38. */
SELECT a.spend_id, c.campaign_name
FROM marketing.ads_spend a
JOIN marketing.campaigns c ON a.campaign_id = c.campaign_id;

/* Q39. */
SELECT o.order_id, s.city
FROM sales.orders o
JOIN stores.stores s ON o.store_id = s.store_id;

/* Q40. */
SELECT r.review_id, p.product_name
FROM customers.reviews r
JOIN products.products p ON r.product_id = p.product_id;

/* ============================================================
   SECTION C: LEFT JOIN (30)
   Topics: preserve all left rows; NULL for unmatched right; anti-joins
   ------------------------------------------------------------ */
/* Q41. */
SELECT c.customer_id, o.order_id
FROM customers.customers c
LEFT JOIN sales.orders o ON c.customer_id = o.cust_id;

/* Q42. */
SELECT p.product_id, oi.order_item_id,
       (oi.order_item_id IS NULL) AS never_ordered
FROM products.products p
LEFT JOIN sales.order_items oi ON p.product_id = oi.prod_id;

/* Q43. */
SELECT e.employee_id, t.ticket_id
FROM stores.employees e
LEFT JOIN support.tickets t ON e.employee_id = t.agent_id;

/* Q44. */
SELECT s.store_id, s.store_name
FROM stores.stores s
LEFT JOIN sales.orders o ON s.store_id = o.store_id
WHERE o.order_id IS NULL;

/* Q45. */
SELECT c.customer_id, r.review_id
FROM customers.customers c
LEFT JOIN customers.reviews r ON c.customer_id = r.customer_id
WHERE r.review_id IS NULL;

/* Q46. */
SELECT c.customer_id, t.ticket_id
FROM customers.customers c
LEFT JOIN support.tickets t ON c.customer_id = t.customer_id
WHERE t.ticket_id IS NULL;

/* Q47. */
SELECT c.customer_id, m.tier_id
FROM customers.customers c
LEFT JOIN loyalty.members m ON c.customer_id = m.customer_id;

/* Q48. */
SELECT o.order_id
FROM sales.orders o
LEFT JOIN sales.shipments sh ON o.order_id = sh.order_id
WHERE sh.shipment_id IS NULL;

/* Q49. */
SELECT o.order_id
FROM sales.orders o
LEFT JOIN sales.payments p ON o.order_id = p.order_id
WHERE p.payment_id IS NULL;

/* Q50. */
SELECT o.order_id
FROM sales.orders o
LEFT JOIN sales.returns r ON o.order_id = r.order_id
WHERE r.return_id IS NULL;

/* Q51. */
SELECT p.product_id
FROM products.products p
LEFT JOIN customers.reviews r ON p.product_id = r.product_id
WHERE r.review_id IS NULL;

/* Q52. */
SELECT e.employee_id
FROM stores.employees e
LEFT JOIN hr.attendance a ON e.employee_id = a.employee_id
WHERE a.attendance_id IS NULL;

/* Q53. */
SELECT w.warehouse_id
FROM supply_chain.warehouses w
LEFT JOIN supply_chain.inventory_snapshots isn ON w.warehouse_id = isn.warehouse_id
WHERE isn.warehouse_id IS NULL;

/* Q54. */
SELECT w.warehouse_id, sh.shipment_id
FROM supply_chain.warehouses w
LEFT JOIN supply_chain.shipments sh ON w.warehouse_id = sh.warehouse_id;

/* Q55. */
SELECT c.campaign_id
FROM marketing.campaigns c
LEFT JOIN marketing.ads_spend a ON c.campaign_id = a.campaign_id
WHERE a.spend_id IS NULL;

/* Q56. */
SELECT pl.line_id, wo.work_order_id
FROM manufacture.production_lines pl
LEFT JOIN manufacture.work_orders wo ON pl.line_id = wo.line_id;

/* Q57. */
SELECT d.dept_id
FROM core.dim_department d
LEFT JOIN stores.employees e ON d.dept_id = e.dept_id
WHERE e.employee_id IS NULL;

/* Q58. */
SELECT r.region_id
FROM core.dim_region r
LEFT JOIN stores.stores s ON r.region_id = s.region_id
WHERE s.store_id IS NULL;

/* Q59. */
SELECT b.brand_id
FROM core.dim_brand b
LEFT JOIN products.products p ON b.brand_id = p.brand_id
WHERE p.product_id IS NULL;

/* Q60. */
SELECT cat.category_id
FROM core.dim_category cat
LEFT JOIN core.dim_brand b ON cat.category_id = b.category_id
WHERE b.brand_id IS NULL;

/* Q61. */
SELECT tr.tier_id
FROM loyalty.tiers tr
LEFT JOIN loyalty.members m ON tr.tier_id = m.tier_id
WHERE m.customer_id IS NULL;

/* Q62. */
SELECT ec.exp_cat_id, ex.expense_id
FROM core.dim_expense_category ec
LEFT JOIN finance.expenses ex ON ec.exp_cat_id = ex.exp_cat_id;

/* Q63. */
SELECT sup.supplier_id
FROM products.suppliers sup
LEFT JOIN products.products p ON sup.supplier_id = p.supplier_id
WHERE p.product_id IS NULL;

/* Q64. */
SELECT p.product_id
FROM products.products p
LEFT JOIN sales.order_items oi ON p.product_id = oi.prod_id
WHERE oi.order_item_id IS NULL;

/* Q65. */
SELECT c.customer_id
FROM customers.customers c
LEFT JOIN sales.orders o ON c.customer_id = o.cust_id
WHERE o.order_id IS NULL;

/* Q66. */
SELECT c.customer_id
FROM customers.customers c
LEFT JOIN customers.reviews r ON c.customer_id = r.customer_id
WHERE r.review_id IS NULL;

/* Q67. */
SELECT o.order_id
FROM sales.orders o
LEFT JOIN sales.shipments sh ON o.order_id = sh.order_id
WHERE sh.shipment_id IS NULL;

/* Q68. */
SELECT c.customer_id
FROM customers.customers c
LEFT JOIN loyalty.members m ON c.customer_id = m.customer_id
WHERE m.customer_id IS NULL;

/* Q69. */
SELECT t.ticket_id
FROM support.tickets t
LEFT JOIN support.tickets t2 ON t.ticket_id = t2.ticket_id AND t2.resolved_date IS NOT NULL
WHERE t2.ticket_id IS NULL;

/* Q70. */
SELECT e.employee_id
FROM stores.employees e
LEFT JOIN support.tickets t ON e.employee_id = t.agent_id
WHERE t.ticket_id IS NULL;

/* ============================================================
   SECTION D: RIGHT JOIN + MULTI-TABLE (30)
   Topics: RIGHT JOIN basics, then 3-table INNER chains
   ------------------------------------------------------------ */
/* Q71. */
SELECT o.order_id, c.first_name, c.last_name
FROM customers.customers c
RIGHT JOIN sales.orders o ON c.customer_id = o.cust_id;

/* Q72. */
SELECT o.order_id, s.store_name
FROM stores.stores s
RIGHT JOIN sales.orders o ON s.store_id = o.store_id;

/* Q73. */
SELECT oi.order_item_id, p.product_name
FROM products.products p
RIGHT JOIN sales.order_items oi ON p.product_id = oi.prod_id;

/* Q74. */
SELECT o.order_id, c.first_name, c.last_name
FROM sales.orders o
LEFT JOIN customers.customers c ON o.cust_id = c.customer_id;

/* Q75. */
SELECT o.order_id, s.store_name
FROM sales.orders o
LEFT JOIN stores.stores s ON o.store_id = s.store_id;

/* Q76. */
SELECT o.order_id, c.first_name || ' ' || c.last_name AS customer_name, s.store_name
FROM sales.orders o
JOIN customers.customers c ON o.cust_id = c.customer_id
JOIN stores.stores s ON o.store_id = s.store_id;

/* Q77. */
SELECT oi.order_item_id, p.product_name, o.order_date
FROM sales.order_items oi
JOIN products.products p ON oi.prod_id = p.product_id
JOIN sales.orders o ON oi.order_id = o.order_id;

/* Q78. */
SELECT p.product_id, b.brand_name, cat.category_name
FROM products.products p
JOIN core.dim_brand b ON p.brand_id = b.brand_id
JOIN core.dim_category cat ON b.category_id = cat.category_id;

/* Q79. */
SELECT e.employee_id, s.store_name, r.region_name
FROM stores.employees e
JOIN stores.stores s ON e.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id;

/* Q80. */
SELECT e.employee_id, d.dept_name, s.store_name
FROM stores.employees e
JOIN core.dim_department d ON e.dept_id = d.dept_id
JOIN stores.stores s ON e.store_id = s.store_id;

/* Q81. */
SELECT c.first_name || ' ' || c.last_name AS member_name, tr.tier_name, m.points_balance
FROM loyalty.members m
JOIN customers.customers c ON m.customer_id = c.customer_id
JOIN loyalty.tiers tr ON m.tier_id = tr.tier_id;

/* Q82. */
SELECT o.order_id, c.first_name, a.city
FROM sales.orders o
JOIN customers.customers c ON o.cust_id = c.customer_id
JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = TRUE;

/* Q83. */
SELECT cl.call_id, c.first_name AS customer_name, e.first_name AS agent_name, cl.call_duration_seconds
FROM call_center.calls cl
JOIN customers.customers c ON cl.customer_id = c.customer_id
JOIN stores.employees e ON cl.agent_id = e.employee_id;

/* Q84. */
SELECT t.ticket_id, c.first_name AS customer_name, e.first_name AS agent_name, t.subject
FROM support.tickets t
JOIN customers.customers c ON t.customer_id = c.customer_id
JOIN stores.employees e ON t.agent_id = e.employee_id;

/* Q85. */
SELECT c.first_name AS customer_name, p.product_name, r.rating
FROM customers.reviews r
JOIN customers.customers c ON r.customer_id = c.customer_id
JOIN products.products p ON r.product_id = p.product_id;

/* Q86. */
SELECT rt.return_id, o.order_date, p.product_name
FROM sales.returns rt
JOIN sales.orders o ON rt.order_id = o.order_id
JOIN products.products p ON rt.prod_id = p.product_id;

/* Q87. */
SELECT sh.shipment_id, w.name AS warehouse_name, sup.supplier_name
FROM supply_chain.shipments sh
JOIN supply_chain.warehouses w ON sh.warehouse_id = w.warehouse_id
JOIN products.suppliers sup ON sh.supplier_id = sup.supplier_id;

/* Q88. */
SELECT wo.work_order_id, pl.line_name, p.product_name
FROM manufacture.work_orders wo
JOIN manufacture.production_lines pl ON wo.line_id = pl.line_id
JOIN products.products p ON wo.product_id = p.product_id;

/* Q89. */
SELECT ps.pay_slip_id, e.first_name AS employee_name, s.store_name
FROM payroll.pay_slips ps
JOIN stores.employees e ON ps.employee_id = e.employee_id
JOIN stores.stores s ON e.store_id = s.store_id;

/* Q90. */
SELECT a.attendance_id, e.first_name AS employee_name, d.dept_name
FROM hr.attendance a
JOIN stores.employees e ON a.employee_id = e.employee_id
JOIN core.dim_department d ON e.dept_id = d.dept_id;

/* Q91. */
SELECT a.spend_id, c.campaign_name
FROM marketing.ads_spend a
JOIN marketing.campaigns c ON a.campaign_id = c.campaign_id;

/* Q92. */
SELECT ex.expense_id, ec.category_name, ex.amount
FROM finance.expenses ex
JOIN core.dim_expense_category ec ON ex.exp_cat_id = ec.exp_cat_id
WHERE ex.amount > 50000;

/* Q93. */
SELECT request_id, endpoint, status_code, response_time_ms
FROM audit.api_requests
WHERE status_code >= 500;

/* Q94. */
SELECT tr.transcript_id, c.first_name AS customer_name, tr.sentiment_score
FROM call_center.transcripts tr
JOIN call_center.calls cl ON tr.call_id = cl.call_id
JOIN customers.customers c ON cl.customer_id = c.customer_id;

/* Q95. */
SELECT e.event_id, c.first_name AS customer_name, pv.page_url
FROM web_events.events e
JOIN web_events.page_views pv ON e.view_id = pv.view_id
JOIN customers.customers c ON pv.customer_id = c.customer_id;

/* Q96. */
SELECT c.first_name AS customer_name, tr.tier_name, lr.reward_name
FROM loyalty.redemptions lr
JOIN customers.customers c ON lr.customer_id = c.customer_id
JOIN loyalty.members m ON m.customer_id = c.customer_id
JOIN loyalty.tiers tr ON m.tier_id = tr.tier_id;

/* Q97. */
SELECT o.order_id, c.first_name AS customer_name, s.store_name, r.region_name
FROM sales.orders o
JOIN customers.customers c ON o.cust_id = c.customer_id
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id;

/* Q98. */
SELECT oi.order_item_id, p.product_name, b.brand_name, cat.category_name, o.order_date
FROM sales.order_items oi
JOIN products.products p ON oi.prod_id = p.product_id
JOIN core.dim_brand b ON p.brand_id = b.brand_id
JOIN core.dim_category cat ON b.category_id = cat.category_id
JOIN sales.orders o ON oi.order_id = o.order_id;

/* Q99. */
SELECT o.order_id, c.first_name AS customer_name, pay.payment_mode
FROM sales.orders o
JOIN customers.customers c ON o.cust_id = c.customer_id
JOIN sales.payments pay ON pay.order_id = o.order_id;

/* Q100. */
SELECT o.order_id, c.first_name AS customer_name, sh.courier_name, s.store_name
FROM sales.orders o
JOIN customers.customers c ON o.cust_id = c.customer_id
JOIN sales.shipments sh ON sh.order_id = o.order_id
JOIN stores.stores s ON o.store_id = s.store_id;

/* ============================================================
   END OF ANSWER KEY - JOINs Part 1 (Foundations) - EASY LEVEL (100/100)
============================================================ */
