/* ============================================================
   ANSWER KEY - JOINs Part 2 (Advanced) (EASY LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: JOINS PART 2 - CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1.  A SELF JOIN joins a table to itself (using two aliases) to compare rows within the same table - needed for things like "pairs of employees in the same department" or "each order vs the same customer's other orders". */
/* Q2.  Because the same table appears twice in the FROM clause, so without distinct aliases (e1, e2) PostgreSQL cannot tell which occurrence any column reference belongs to - it would be ambiguous. */
/* Q3.  A FULL OUTER JOIN keeps every row from BOTH tables, filling NULLs wherever there's no match on the other side; both sides' unmatched rows matter when you need a complete reconciliation - e.g. "customers without loyalty membership" AND "loyalty rows with no matching customer" in one report. */
/* Q4.  INNER keeps only matched rows from both; LEFT keeps all left rows plus matches; RIGHT keeps all right rows plus matches; FULL keeps all rows from both sides, matched or not (NULLs where unmatched). */
/* Q5.  A CROSS JOIN pairs every row of one table with every row of another (no ON condition) - you want one when building every possible COMBINATION deliberately, like a (region x tier) grid for a report, or a calendar table via generate_series. */
/* Q6.  UNION removes duplicate rows across the combined result (implicitly sorting/deduping); UNION ALL keeps every row including duplicates - UNION ALL is faster because it skips the dedup/sort step entirely. */
/* Q7.  INTERSECT returns only rows that appear in BOTH result sets; it's more readable than an INNER JOIN when you're comparing two independently-built SELECTs on the SAME columns rather than joining on a key, e.g. "customers who ordered" INTERSECT "customers who reviewed". */
/* Q8.  EXCEPT returns rows in the first result set that do NOT appear in the second (whole-row comparison); an anti-join (LEFT JOIN + IS NULL or NOT EXISTS) instead compares on a JOIN KEY, not the whole row, and preserves other columns from the left side rather than collapsing to matching column lists. */
/* Q9.  Every SELECT in a UNION must have the SAME NUMBER of columns, and each corresponding column's data type must be compatible (implicitly castable) across all branches. */
/* Q10. UNION removes duplicates, which requires sorting/hashing the combined rows to find and drop repeats; UNION ALL just concatenates the result sets with no such step, so it's cheaper. */
/* Q11. A LATERAL JOIN lets a subquery in the FROM clause reference columns from tables that appear earlier in the same FROM clause, effectively running once per outer row. */
/* Q12. Same idea, different syntax - a LATERAL subquery in the FROM clause and a correlated subquery in the SELECT/WHERE clause both re-evaluate using the outer row's values, but LATERAL can return multiple columns and multiple rows naturally, joined like any other table. */
/* Q13. Yes - stores.employees has no self-referencing manager_id in this schema, but conceptually a SELF JOIN on employees e1 JOIN employees e2 ON e1.manager_id = e2.employee_id is the standard way to resolve "manager name" through a foreign key that points back to the same table. */
/* Q14. Because reconciliation needs to see BOTH "what's missing from the new system" and "what's missing from the old system" in one pass - FULL OUTER JOIN surfaces unmatched rows from either side simultaneously, which a one-directional LEFT/RIGHT JOIN cannot. */
/* Q15. CROSS JOIN with a numbers table (or generate_series) gives you N rows per original row - the standard trick for exploding one row into a sequence (building a date dimension, spreading an order into installments, or generating every (row, N) combination). */
/* Q16. ORDER BY in a UNION applies to the FINAL combined result, not to each branch individually - PostgreSQL only allows one ORDER BY, placed after the last SELECT, sorting the whole unioned output. */
/* Q17. LIMIT goes at the very end, after the last branch and any overall ORDER BY - it applies to the combined result, not per branch; to limit each branch separately you'd wrap each SELECT with its own LIMIT inside a subquery before unioning. */
/* Q18. Bag semantics allow duplicate rows in a result (like UNION ALL, or a plain table scan); set semantics treat the result as a true mathematical set with no duplicates (like UNION, INTERSECT, EXCEPT, or SELECT DISTINCT). */
/* Q19. Yes - unlike a normal equality comparison, INTERSECT (and EXCEPT) treat two NULLs in the same column position as "equal" for the purpose of matching/deduplicating rows, since they use IS NOT DISTINCT FROM semantics rather than plain `=`. */
/* Q20. Because OLTP queries (checking a single order, a single customer) rarely need to see "everything from both sides including orphans" - that's an analytical/auditing need; day-to-day transactional lookups almost always know which side they're querying FROM and use INNER/LEFT instead. */
/* Q21. Self-join the table to itself on the shared grouping column (e1.dept_id = e2.dept_id) plus a tie-breaker like e1.employee_id < e2.employee_id to avoid both (A,B) and (B,A) duplicate pairs and self-pairing (A,A). */
/* Q22. They are equivalent - CROSS JOIN b is just explicit syntax for the same Cartesian product that a comma-separated FROM a, b produces with no WHERE condition linking them. */
/* Q23. It usually ISN'T slower for equivalent logic - "single SELECT with OR" and "UNION of two SELECTs" often produce different plans (OR can prevent index use on either branch, while UNION lets each branch use its own index), so UNION can actually be FASTER, not slower, despite the extra dedup overhead in UNION (not UNION ALL). */
/* Q24. generate_series(start, stop) produces a virtual row set of sequential numbers/dates with no underlying table; paired with CROSS JOIN it lets you multiply any table by N synthetic rows - the standard way to build calendars, date grids, or repeat-N-times patterns without a real numbers table. */
/* Q25. EXCEPT ALL keeps row-count multiplicity (subtracting matching duplicates one-for-one, so if a row appears 3 times on the left and 1 time on the right, 2 copies remain); EXCEPT (implicitly EXCEPT DISTINCT) removes the row entirely if it exists on the right at all, regardless of how many times, and de-duplicates its own output too. */

/* ============================================================
   SECTION B: SELF JOIN BASICS (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT e1.employee_id AS emp1, e2.employee_id AS emp2, e1.dept_id
FROM stores.employees e1
JOIN stores.employees e2 ON e1.dept_id = e2.dept_id AND e1.employee_id < e2.employee_id
LIMIT 200;

/* Q27. */
SELECT c1.customer_id AS cust1, c2.customer_id AS cust2, a1.city
FROM customers.addresses a1
JOIN customers.addresses a2 ON a1.city = a2.city AND a1.customer_id < a2.customer_id
JOIN customers.customers c1 ON c1.customer_id = a1.customer_id
JOIN customers.customers c2 ON c2.customer_id = a2.customer_id
WHERE a1.is_default = TRUE AND a2.is_default = TRUE
LIMIT 200;

/* Q28. */
SELECT o1.order_id AS order1, o2.order_id AS order2, o1.cust_id, o1.order_date
FROM sales.orders o1
JOIN sales.orders o2 ON o1.cust_id = o2.cust_id AND o1.order_date = o2.order_date AND o1.order_id < o2.order_id
LIMIT 200;

/* Q29. */
SELECT p1.product_id AS product1, p2.product_id AS product2, p1.brand_id
FROM products.products p1
JOIN products.products p2 ON p1.brand_id = p2.brand_id AND p1.product_id < p2.product_id
LIMIT 200;

/* Q30. */
SELECT s1.store_id AS store1, s2.store_id AS store2, s1.region_id
FROM stores.stores s1
JOIN stores.stores s2 ON s1.region_id = s2.region_id AND s1.store_id < s2.store_id;

/* Q31. */
SELECT e1.employee_id AS emp1, e1.store_id AS store1, e2.employee_id AS emp2, e2.store_id AS store2, e1.role
FROM stores.employees e1
JOIN stores.employees e2 ON e1.role = e2.role AND e1.store_id <> e2.store_id AND e1.employee_id < e2.employee_id
LIMIT 200;

/* Q32. Restricted to a bounded slice of customers, since domains like gmail.com match thousands of rows and the full cross-product isn't useful output anyway. */
SELECT c1.customer_id AS cust1, c2.customer_id AS cust2, SPLIT_PART(c1.email, '@', 2) AS domain
FROM customers.customers c1
JOIN customers.customers c2
  ON SPLIT_PART(c1.email, '@', 2) = SPLIT_PART(c2.email, '@', 2)
 AND c1.customer_id < c2.customer_id
WHERE c1.customer_id <= 500
LIMIT 200;

/* Q33. */
SELECT p1.product_id AS product1, p2.product_id AS product2, b.category_id, p1.supplier_id
FROM products.products p1
JOIN products.products p2
  ON p1.supplier_id = p2.supplier_id AND p1.product_id < p2.product_id
JOIN core.dim_brand b ON p1.brand_id = b.brand_id
JOIN core.dim_brand b2 ON p2.brand_id = b2.brand_id AND b2.category_id = b.category_id
LIMIT 200;

/* Q34. */
SELECT t1.ticket_id AS ticket1, t2.ticket_id AS ticket2, t1.priority, t1.status
FROM support.tickets t1
JOIN support.tickets t2
  ON t1.priority = t2.priority AND t1.status = t2.status AND t1.ticket_id < t2.ticket_id
LIMIT 200;

/* Q35. */
SELECT c1.campaign_id AS campaign1, c2.campaign_id AS campaign2, a1.platform
FROM marketing.ads_spend a1
JOIN marketing.ads_spend a2 ON a1.platform = a2.platform AND a1.campaign_id < a2.campaign_id
JOIN marketing.campaigns c1 ON c1.campaign_id = a1.campaign_id
JOIN marketing.campaigns c2 ON c2.campaign_id = a2.campaign_id
LIMIT 200;

/* Q36. */
SELECT ps1.employee_id, ps1.salary_month AS month1, ps2.salary_month AS month2
FROM payroll.pay_slips ps1
JOIN payroll.pay_slips ps2
  ON ps1.employee_id = ps2.employee_id
 AND ps1.salary_month <> ps2.salary_month
 AND ps1.pay_slip_id < ps2.pay_slip_id
LIMIT 200;

/* Q37. */
SELECT o1.order_id AS order1, o2.order_id AS order2, o1.cust_id
FROM sales.orders o1
JOIN sales.orders o2
  ON o1.cust_id = o2.cust_id AND o1.store_id <> o2.store_id AND o1.order_id < o2.order_id
LIMIT 200;

/* Q38. */
SELECT r1.review_id AS review1, r2.review_id AS review2, r1.customer_id
FROM customers.reviews r1
JOIN customers.reviews r2
  ON r1.customer_id = r2.customer_id AND r1.product_id <> r2.product_id AND r1.review_id < r2.review_id
LIMIT 200;

/* Q39. */
SELECT p1.product_id AS product1, p2.product_id AS product2,
       WIDTH_BUCKET(p1.price, 0, 50000, 10) AS price_band
FROM products.products p1
JOIN products.products p2
  ON WIDTH_BUCKET(p1.price, 0, 50000, 10) = WIDTH_BUCKET(p2.price, 0, 50000, 10)
 AND p1.product_id < p2.product_id
LIMIT 200;

/* Q40. supply_chain.warehouses has a text "region" column but no region_id FK, so region name is used directly. */
SELECT w1.warehouse_id AS warehouse1, w2.warehouse_id AS warehouse2, w1.region
FROM supply_chain.warehouses w1
JOIN supply_chain.warehouses w2 ON w1.region = w2.region AND w1.warehouse_id < w2.warehouse_id;

/* Q41. */
SELECT c1.customer_id AS cust1, c2.customer_id AS cust2, c1.tier, a1.city
FROM customers.customers c1
JOIN customers.customers c2 ON c1.tier = c2.tier AND c1.customer_id < c2.customer_id
JOIN customers.addresses a1 ON a1.customer_id = c1.customer_id AND a1.is_default = TRUE
JOIN customers.addresses a2 ON a2.customer_id = c2.customer_id AND a2.is_default = TRUE AND a2.city = a1.city
LIMIT 200;

/* Q42. */
SELECT b1.brand_id AS brand1, b2.brand_id AS brand2, b1.category_id
FROM core.dim_brand b1
JOIN core.dim_brand b2 ON b1.category_id = b2.category_id AND b1.brand_id < b2.brand_id;

/* Q43. */
SELECT o1.order_id AS order1, o2.order_id AS order2, o1.cust_id
FROM sales.orders o1
JOIN sales.orders o2
  ON o1.cust_id = o2.cust_id
 AND o1.order_id < o2.order_id
 AND o1.order_date = o2.order_date
LIMIT 200;

/* Q44. */
SELECT s1.shipment_id AS shipment1, s2.shipment_id AS shipment2, s1.courier_name, s1.shipped_date
FROM sales.shipments s1
JOIN sales.shipments s2
  ON s1.courier_name = s2.courier_name AND s1.shipped_date = s2.shipped_date AND s1.shipment_id < s2.shipment_id
LIMIT 200;

/* Q45. */
SELECT p1.view_id AS view1, p2.view_id AS view2, p1.session_id
FROM web_events.page_views p1
JOIN web_events.page_views p2 ON p1.session_id = p2.session_id AND p1.view_id < p2.view_id
LIMIT 200;

/* Q46. */
SELECT e1.employee_id AS emp1, e2.employee_id AS emp2, e1.joining_date
FROM stores.employees e1
JOIN stores.employees e2 ON e1.joining_date = e2.joining_date AND e1.employee_id < e2.employee_id
LIMIT 200;

/* Q47. */
SELECT ps1.pay_slip_id AS payslip1, ps2.pay_slip_id AS payslip2, ps1.gross_salary
FROM payroll.pay_slips ps1
JOIN payroll.pay_slips ps2
  ON ps1.gross_salary = ps2.gross_salary AND ps1.employee_id <> ps2.employee_id AND ps1.pay_slip_id < ps2.pay_slip_id
LIMIT 200;

/* Q48. */
SELECT t1.ticket_id AS ticket1, t2.ticket_id AS ticket2, t1.customer_id
FROM support.tickets t1
JOIN support.tickets t2
  ON t1.customer_id = t2.customer_id AND t1.ticket_id < t2.ticket_id
LIMIT 200;

/* Q49. */
SELECT p1.product_id AS product1, p2.product_id AS product2, p1.supplier_id
FROM products.products p1
JOIN products.products p2
  ON p1.supplier_id = p2.supplier_id AND p1.brand_id <> p2.brand_id AND p1.product_id < p2.product_id
LIMIT 200;

/* Q50. */
SELECT c1.campaign_id AS campaign1, c2.campaign_id AS campaign2, c1.budget
FROM marketing.campaigns c1
JOIN marketing.campaigns c2
  ON c1.budget = c2.budget AND c1.campaign_id < c2.campaign_id;

/* ============================================================
   SECTION C: FULL OUTER + CROSS JOIN (25)
   ------------------------------------------------------------ */
/* Q51. */
SELECT c.customer_id, m.customer_id AS member_customer_id
FROM customers.customers c
FULL OUTER JOIN loyalty.members m ON c.customer_id = m.customer_id
WHERE c.customer_id IS NULL OR m.customer_id IS NULL;

/* Q52. */
SELECT o.order_id, sh.shipment_id
FROM sales.orders o
FULL OUTER JOIN sales.shipments sh ON o.order_id = sh.order_id
WHERE o.order_id IS NULL OR sh.shipment_id IS NULL;

/* Q53. */
SELECT e.employee_id, ps.pay_slip_id
FROM stores.employees e
FULL OUTER JOIN payroll.pay_slips ps ON e.employee_id = ps.employee_id
WHERE e.employee_id IS NULL OR ps.pay_slip_id IS NULL;

/* Q54. */
SELECT r.region_id, s.store_id
FROM core.dim_region r
FULL OUTER JOIN stores.stores s ON r.region_id = s.region_id
WHERE r.region_id IS NULL OR s.store_id IS NULL;

/* Q55. */
SELECT cat.category_id, b.brand_id
FROM core.dim_category cat
FULL OUTER JOIN core.dim_brand b ON cat.category_id = b.category_id
WHERE cat.category_id IS NULL OR b.brand_id IS NULL;

/* Q56. */
SELECT p.product_id, oi.order_item_id
FROM products.products p
FULL OUTER JOIN sales.order_items oi ON p.product_id = oi.prod_id
WHERE p.product_id IS NULL OR oi.order_item_id IS NULL;

/* Q57. */
SELECT w.warehouse_id, isn.product_id
FROM supply_chain.warehouses w
FULL OUTER JOIN supply_chain.inventory_snapshots isn ON w.warehouse_id = isn.warehouse_id
WHERE w.warehouse_id IS NULL OR isn.warehouse_id IS NULL;

/* Q58. RetailMart has no support.agents table; support.tickets.agent_id references stores.employees directly. */
SELECT t.ticket_id, e.employee_id
FROM support.tickets t
FULL OUTER JOIN stores.employees e ON t.agent_id = e.employee_id
WHERE t.ticket_id IS NULL OR e.employee_id IS NULL
LIMIT 200;

/* Q59. */
SELECT c.campaign_id, a.spend_id
FROM marketing.campaigns c
FULL OUTER JOIN marketing.ads_spend a ON c.campaign_id = a.campaign_id
WHERE c.campaign_id IS NULL OR a.spend_id IS NULL;

/* Q60. */
SELECT r.review_id, o.order_id
FROM customers.reviews r
FULL OUTER JOIN sales.orders o ON r.customer_id = o.cust_id AND r.product_id = ANY(
  SELECT prod_id FROM sales.order_items oi WHERE oi.order_id = o.order_id
)
WHERE r.review_id IS NULL OR o.order_id IS NULL
LIMIT 200;

/* Q61. */
SELECT r.region_name, tr.tier_name
FROM core.dim_region r
CROSS JOIN loyalty.tiers tr;

/* Q62. */
SELECT DISTINCT DATE_TRUNC('month', order_date) AS month, cat.category_name
FROM sales.orders
CROSS JOIN core.dim_category cat
ORDER BY month, cat.category_name;

/* Q63. */
SELECT DISTINCT device_type, os
FROM web_events.page_views
ORDER BY device_type, os;

/* Q64. */
SELECT DISTINCT platform, DATE_TRUNC('month', spend_date) AS month
FROM marketing.ads_spend
ORDER BY platform, month;

/* Q65. */
SELECT r.region_name, b.brand_name
FROM core.dim_region r
CROSS JOIN core.dim_brand b
LIMIT 200;

/* Q66. */
SELECT gs.month_num, s.store_id
FROM GENERATE_SERIES(1, 12) AS gs(month_num)
CROSS JOIN stores.stores s
ORDER BY s.store_id, gs.month_num
LIMIT 200;

/* Q67. */
SELECT DISTINCT o.order_status, s.store_id
FROM sales.orders o
CROSS JOIN stores.stores s
ORDER BY s.store_id, o.order_status
LIMIT 200;

/* Q68. */
SELECT p.priority, s.status
FROM (SELECT DISTINCT priority FROM support.tickets) p
CROSS JOIN (SELECT DISTINCT status FROM support.tickets) s
ORDER BY p.priority, s.status;

/* Q69. */
SELECT r.region_name, c.campaign_name
FROM core.dim_region r
CROSS JOIN marketing.campaigns c
LIMIT 200;

/* Q70. */
SELECT gs.yr, d.dept_name
FROM GENERATE_SERIES(2024, 2026) AS gs(yr)
CROSS JOIN core.dim_department d
ORDER BY gs.yr, d.dept_name;

/* Q71. */
SELECT gs::date AS date_key
FROM GENERATE_SERIES('2024-01-01'::date, '2026-12-31'::date, '1 day') AS gs
LIMIT 200;

/* Q72. */
SELECT gs::date AS calendar_date
FROM GENERATE_SERIES('2024-01-01'::date, CURRENT_DATE, '1 day') AS gs;

/* Q73. */
SELECT cat.category_name, tr.tier_name
FROM core.dim_category cat
CROSS JOIN loyalty.tiers tr;

/* Q74. */
SELECT DISTINCT sh.courier_name, DATE_TRUNC('month', sh.shipped_date) AS month
FROM sales.shipments sh
ORDER BY sh.courier_name, month;

/* Q75. */
SELECT 'RetailMart V3' AS report_label, c.customer_id
FROM customers.customers c
LIMIT 20;

/* ============================================================
   SECTION D: UNION / INTERSECT / EXCEPT (25)
   ------------------------------------------------------------ */
/* Q76. */
SELECT email, 'customer' AS source FROM customers.customers
UNION ALL
SELECT email, 'employee' FROM stores.employees;

/* Q77. */
SELECT order_id::text AS event_id, 'order' AS event_type, order_date AS event_date FROM sales.orders
UNION ALL
SELECT review_id::text, 'review', review_date FROM customers.reviews
UNION ALL
SELECT ticket_id::text, 'ticket', created_date::date FROM support.tickets;

/* Q78. */
SELECT city FROM customers.addresses
UNION
SELECT city FROM stores.stores;

/* Q79. RetailMart's order_status has no literal 'International' value, so 'Cancelled' is used as the proxy split named in the question. */
SELECT order_id, 'Domestic' AS order_class FROM sales.orders WHERE order_status <> 'Cancelled'
UNION ALL
SELECT order_id, 'International' FROM sales.orders WHERE order_status = 'Cancelled';

/* Q80. */
SELECT shipment_id::text AS event_id, 'shipped' AS event_type, shipped_date AS event_date FROM sales.shipments WHERE shipped_date IS NOT NULL
UNION ALL
SELECT shipment_id::text, 'delivered', delivered_date FROM sales.shipments WHERE delivered_date IS NOT NULL;

/* Q81. */
SELECT agent_id, 'ticket' AS source, ticket_id AS activity_id FROM support.tickets WHERE agent_id IS NOT NULL
UNION ALL
SELECT agent_id, 'call', call_id FROM call_center.calls WHERE agent_id IS NOT NULL;

/* Q82. */
SELECT cust_id AS customer_id FROM sales.orders
INTERSECT
SELECT customer_id FROM customers.reviews;

/* Q83. */
SELECT customer_id FROM loyalty.members
INTERSECT
SELECT cust_id FROM sales.orders;

/* Q84. */
SELECT prod_id AS product_id FROM sales.order_items
INTERSECT
SELECT product_id FROM customers.reviews;

/* Q85. */
SELECT store_id FROM stores.employees
INTERSECT
SELECT store_id FROM sales.orders;

/* Q86. */
SELECT cust_id AS customer_id FROM sales.orders
EXCEPT
SELECT customer_id FROM loyalty.members;

/* Q87. */
SELECT prod_id AS product_id FROM sales.order_items
EXCEPT
SELECT product_id FROM customers.reviews;

/* Q88. */
SELECT employee_id FROM stores.employees
EXCEPT
SELECT employee_id FROM payroll.pay_slips;

/* Q89. */
SELECT store_id FROM stores.employees
EXCEPT
SELECT store_id FROM sales.orders;

/* Q90. */
SELECT b.brand_id FROM core.dim_brand b JOIN products.products p ON p.brand_id = b.brand_id
EXCEPT
SELECT p.brand_id FROM products.products p JOIN sales.order_items oi ON oi.prod_id = p.product_id;

/* Q91. */
(SELECT product_id, product_name, price, 'top5' AS label FROM products.products ORDER BY price DESC LIMIT 5)
UNION ALL
(SELECT product_id, product_name, price, 'bottom5' FROM products.products ORDER BY price ASC LIMIT 5);

/* Q92. */
SELECT 'this_month' AS period, COUNT(*) AS order_count FROM sales.orders
WHERE DATE_TRUNC('month', order_date) = DATE_TRUNC('month', (SELECT MAX(order_date) FROM sales.orders))
UNION ALL
SELECT 'last_month', COUNT(*) FROM sales.orders
WHERE DATE_TRUNC('month', order_date) = DATE_TRUNC('month', (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '1 month')
UNION ALL
SELECT 'ytd', COUNT(*) FROM sales.orders
WHERE EXTRACT(YEAR FROM order_date) = EXTRACT(YEAR FROM (SELECT MAX(order_date) FROM sales.orders));

/* Q93. */
SELECT r.region_name, SUM(o.net_total) AS revenue
FROM sales.orders o
JOIN stores.stores s ON o.store_id = s.store_id
JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY r.region_name
UNION ALL
SELECT 'GRAND TOTAL', SUM(net_total) FROM sales.orders;

/* Q94. */
SELECT ticket_id, 'Critical' AS priority_label FROM support.tickets WHERE priority = 'Critical'
UNION ALL
SELECT ticket_id, 'High' FROM support.tickets WHERE priority = 'High'
UNION ALL
SELECT ticket_id, 'Medium' FROM support.tickets WHERE priority = 'Medium';

/* Q95. */
SELECT order_id, cust_id, 'Registered' AS checkout_type FROM sales.orders WHERE cust_id IS NOT NULL
UNION ALL
SELECT order_id, cust_id, 'Guest' FROM sales.orders WHERE cust_id IS NULL;

/* Q96. */
SELECT order_status FROM sales.orders WHERE cust_id = 1
INTERSECT ALL
SELECT order_status FROM sales.orders WHERE cust_id = 2;

/* Q97. */
SELECT customer_id, first_name FROM customers.customers WHERE tier = 'Platinum'
UNION
SELECT customer_id, first_name FROM customers.customers WHERE tier = 'Gold'
ORDER BY first_name;

/* Q98. */
(SELECT order_id, net_total FROM sales.orders ORDER BY net_total DESC LIMIT 3)
UNION ALL
(SELECT order_id, net_total FROM sales.orders ORDER BY net_total ASC LIMIT 3);

/* Q99. */
WITH ref AS (SELECT MAX(order_date) AS today FROM sales.orders)
SELECT 'last_week' AS bucket, COUNT(*) FROM sales.orders, ref WHERE order_date >= today - 7
UNION ALL
SELECT 'last_month', COUNT(*) FROM sales.orders, ref WHERE order_date >= today - 30
UNION ALL
SELECT 'last_quarter', COUNT(*) FROM sales.orders, ref WHERE order_date >= today - 90;

/* Q100. */
SELECT customer_id, 'ticket' AS source, created_date::date AS created_at FROM support.tickets
UNION ALL
SELECT customer_id, 'review', review_date FROM customers.reviews
UNION ALL
SELECT customer_id, 'call', call_start_time::date FROM call_center.calls;

/* ============================================================
   END OF ANSWER KEY - JOINs Part 2 (Advanced) - EASY LEVEL (100/100)
============================================================ */
