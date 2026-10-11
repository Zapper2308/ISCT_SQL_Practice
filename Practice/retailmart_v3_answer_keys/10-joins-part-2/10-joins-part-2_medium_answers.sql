/* ============================================================
   ANSWER KEY - JOINs Part 2 (Advanced) (MEDIUM LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: SET OPS + SELF JOIN - CONCEPTUAL DEEPER (25)
   ------------------------------------------------------------ */
/* Q1.  A self-join + GROUP BY re-derives per-row relationships (like "previous order") by joining the whole table to itself and filtering/aggregating, scanning combinations; a window function (LAG/LEAD) computes the same thing in a single ordered pass with no join at all - much less work for the same answer. */
/* Q2.  A self-join without a selective equality condition scales roughly with N^2 (every row potentially compared to every other row); it's avoided once N gets into the hundreds of thousands unless the join has an equality key that lets PostgreSQL hash/index it down to near-linear. */
/* Q3.  It doesn't inherently produce duplicates by itself, but combined with a LEFT/RIGHT-style fan-out on either side (one row matching many), you can get repeated key values in the output; COALESCE(left.key, right.key) collapses the two "could be NULL" key columns into one clean, single reconciled key column. */
/* Q4.  Because a real calendar has no gaps, but your data only has rows for dates that had activity - CROSS JOIN generate_series(start,end,'1 day') against your dimension gives every date, then LEFT JOIN the real data onto it so missing dates show up with 0/NULL instead of vanishing. */
/* Q5.  Whenever the "join" condition is really just "rows from A OR rows from B, stacked", not a row-to-row match - e.g. combining ticket events and call events into one timeline is naturally a UNION ALL, while combining an order and its customer info by key is naturally a JOIN; they express different relationships. */
/* Q6.  Because removing duplicates requires comparing every row to every other row, which PostgreSQL implements via a full sort (or hash) of the combined result before it can drop repeats - that extra Sort/HashAggregate step is exactly what UNION ALL skips. */
/* Q7.  EXCEPT does whole-row set subtraction (handles NULLs via IS NOT DISTINCT FROM); NOT IN silently returns NO rows at all if the subquery contains even one NULL value (a classic gotcha); NOT EXISTS is a correlated per-row check that handles NULLs correctly and is usually the safest and often fastest of the three. */
/* Q8.  A NULL vs NULL is treated as "equal" for INTERSECT's matching purposes (unlike normal `=` where NULL never equals NULL) - so two rows that are identical except both have NULL in the same column WILL be considered the same row and collapsed. */
/* Q9.  Because reconciliation inherently needs "what's only on the left" AND "what's only on the right" AND "what matches" all at once, and FULL OUTER JOIN is the only single join type that surfaces all three categories in one pass. */
/* Q10. LATERAL lets a subquery in the FROM clause see and use columns from tables listed earlier in that same FROM clause (re-evaluating per outer row); a normal subquery in FROM is computed once, independently, and cannot reference anything from sibling FROM items. */
/* Q11. Because LATERAL is explicitly flagged to PostgreSQL as "this subquery is correlated to an earlier FROM item" - without that flag, a subquery in FROM is planned as an independent, non-correlated derived table and referencing an outer column would be a plain error. */
/* Q12. Hash Join when the self-join's equality key lets one copy be hashed efficiently (common case, e.g. e1.dept_id=e2.dept_id); Merge Join when the table is already sorted/indexed on that key; Nested Loop when the outer side is small enough that a per-row lookup on the inner copy is cheap. */
/* Q13. LEFT JOIN LATERAL keeps the outer row even when the LATERAL subquery returns zero rows (columns come back NULL); INNER JOIN LATERAL drops the outer row entirely if the subquery returns nothing. */
/* Q14. A tiny table (say, loyalty.tiers with 4 rows) self-joined is only 16 combinations - trivial; the same self-join pattern on a table with millions of rows and no selective join key can produce trillions of comparisons, which is computationally disastrous. */
/* Q15. Because PostgreSQL only allows ONE ORDER BY for the entire UNION statement, placed after the final SELECT - an ORDER BY inside an individual branch (without wrapping that branch in parentheses as a subquery) is a syntax error or gets reinterpreted as belonging to the whole union. */
/* Q16. GROUP BY 1 (positional) inside one branch of a UNION applies ONLY to that branch's own SELECT - PostgreSQL runs each SELECT independently before combining them, so grouping logic never crosses branch boundaries. */
/* Q17. Because CROSS JOIN LATERAL generate_series(...) needs to generate a DIFFERENT series per outer row (e.g., a different date range per order), which plain CROSS JOIN generate_series(fixed_args) cannot do since its arguments would be the same fixed values for every row. */
/* Q18. They're functionally equivalent for a simple array column, but CROSS JOIN unnest(array_col) treats it as an independent FROM item (works fine when there's nothing outer-row-specific to reference); LATERAL unnest(array_col) is needed when the array expression itself depends on an outer-row column (e.g., unnest(t.tags) referencing t from earlier in the FROM list) - technically CROSS JOIN LATERAL is implied automatically for a function call that references an earlier FROM item. */
/* Q19. UNION ALL keeps every row from every branch untouched, including exact duplicates - that's exactly right for a "stacked timeline" of events (an order, a call, a review) where each row is a distinct real-world event even if two events happen to look identical on the surface. */
/* Q20. Before window functions existed, a self-join like `e1 JOIN e2 ON e1.key=e2.key AND e2.event_time > e1.event_time` combined with a MIN/NOT EXISTS filter to keep only the closest one was the standard (if clunky) way to find "the next event per row" - LEAD()/LAG() now do the same thing far more simply and efficiently. */
/* Q21. Because the two sides' join-key columns can independently be NULL for unmatched rows (whichever side had no partner), so downstream code that wants "the effective key regardless of which side matched" needs COALESCE(left.key, right.key) to get a single non-NULL value when either side has one. */
/* Q22. They're equivalent only when you're comparing on EVERY column of both tables (full row equality) and there are no duplicate rows to worry about - INTERSECT does whole-row set matching, while INNER JOIN ON all-columns explicitly names each column pair; for a subset of columns or with duplicates present, they diverge. */
/* Q23. EXCEPT does one clean set-subtraction in a single readable statement; LEFT JOIN ... IS NULL requires writing out the join condition and remembering to filter on the right side's key being NULL - EXCEPT is often preferred purely for its declarative "just subtract these rows" clarity, especially when comparing on many columns at once. */
/* Q24. It's when a UNION (not UNION ALL) silently collapses two DIFFERENT real-world rows into one because they happen to look identical on every selected column - if you actually needed to keep both (e.g., two separate $50 orders on the same day), a plain UNION would quietly drop one without any error or warning. */
/* Q25. Because FULL OUTER JOIN is the one join type built exactly for "show me every row from source A, every row from source B, and clearly mark where they don't line up" - which is the literal definition of an audit/reconciliation mismatch report. */

/* ============================================================
   SECTION B: SELF JOIN - DEEPER PATTERNS (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT o1.order_id, o1.order_date,
       (SELECT o2.order_id FROM sales.orders o2
        WHERE o2.cust_id = o1.cust_id AND o2.order_date < o1.order_date
        ORDER BY o2.order_date DESC LIMIT 1) AS previous_order_id
FROM sales.orders o1
WHERE o1.cust_id <= 200
ORDER BY o1.cust_id, o1.order_date;

/* Q27. */
SELECT s1.shipment_id, s1.courier_name, s1.shipped_date,
       (SELECT s2.shipment_id FROM sales.shipments s2
        WHERE s2.courier_name = s1.courier_name AND s2.shipped_date > s1.shipped_date
        ORDER BY s2.shipped_date ASC LIMIT 1) AS next_shipment_id
FROM sales.shipments s1
LIMIT 200;

/* Q28. */
SELECT ps1.employee_id, ps1.salary_year, ps1.salary_month,
       (SELECT ps2.pay_slip_id FROM payroll.pay_slips ps2
        WHERE ps2.employee_id = ps1.employee_id AND ps2.pay_slip_id < ps1.pay_slip_id
        ORDER BY ps2.pay_slip_id DESC LIMIT 1) AS prior_pay_slip_id
FROM payroll.pay_slips ps1
LIMIT 200;

/* Q29. */
SELECT t1.ticket_id, t1.customer_id,
       (SELECT t2.ticket_id FROM support.tickets t2
        WHERE t2.customer_id = t1.customer_id AND t2.created_date < t1.created_date
        ORDER BY t2.created_date DESC LIMIT 1) AS prior_ticket_id
FROM support.tickets t1
LIMIT 200;

/* Q30. */
SELECT c1.call_id, c1.agent_id,
       (SELECT c2.call_id FROM call_center.calls c2
        WHERE c2.agent_id = c1.agent_id AND c2.call_start_time < c1.call_start_time
        ORDER BY c2.call_start_time DESC LIMIT 1) AS prior_call_id
FROM call_center.calls c1
LIMIT 200;

/* Q31. */
SELECT r1.review_id, r1.customer_id, r1.product_id,
       (SELECT r2.review_id FROM customers.reviews r2
        WHERE r2.customer_id = r1.customer_id AND r2.product_id = r1.product_id AND r2.review_date < r1.review_date
        ORDER BY r2.review_date DESC LIMIT 1) AS prior_review_id
FROM customers.reviews r1
LIMIT 200;

/* Q32. */
SELECT pv1.view_id, pv1.session_id,
       (SELECT pv2.view_id FROM web_events.page_views pv2
        WHERE pv2.session_id = pv1.session_id AND pv2.view_timestamp < pv1.view_timestamp
        ORDER BY pv2.view_timestamp DESC LIMIT 1) AS prior_view_id
FROM web_events.page_views pv1
LIMIT 200;

/* Q33. Counted combinatorially (n choose 2 per city+tier group) instead of a literal self-join, which would need a non-selective tier-only join step first. */
SELECT SUM(cnt * (cnt - 1) / 2) AS pair_count
FROM (
  SELECT c.tier, a.city, COUNT(*) AS cnt
  FROM customers.customers c
  JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = TRUE
  GROUP BY c.tier, a.city
) grp;

/* Q34. */
SELECT o1.order_id AS order1, o2.order_id AS order2
FROM sales.orders o1
JOIN sales.orders o2
  ON o1.cust_id = o2.cust_id AND o1.order_id < o2.order_id AND o1.order_date = o2.order_date
LIMIT 200;

/* Q35. */
SELECT COUNT(DISTINCT cust_id) AS repeat_day_customers
FROM (
  SELECT cust_id, order_date, COUNT(*) AS orders_same_day
  FROM sales.orders GROUP BY cust_id, order_date
  HAVING COUNT(*) > 1
) x;

/* Q36. */
SELECT c1.campaign_id AS campaign1, c1.budget AS budget1, c2.campaign_id AS campaign2, c2.budget AS budget2
FROM marketing.campaigns c1
JOIN marketing.ads_spend a1 ON a1.campaign_id = c1.campaign_id
JOIN marketing.campaigns c2
  ON a1.platform = (SELECT platform FROM marketing.ads_spend a2 WHERE a2.campaign_id = c2.campaign_id LIMIT 1)
 AND c2.budget > c1.budget AND c2.campaign_id <> c1.campaign_id
LIMIT 200;

/* Q37. */
SELECT p1.product_id AS product1, p2.product_id AS product2, p1.brand_id
FROM products.products p1
JOIN products.products p2 ON p1.brand_id = p2.brand_id AND p2.price > p1.price
LIMIT 200;

/* Q38. */
SELECT e1.employee_id AS emp1, e2.employee_id AS emp2, e1.role
FROM stores.employees e1
JOIN stores.employees e2 ON e1.role = e2.role AND e2.salary > e1.salary
LIMIT 200;

/* Q39. */
SELECT s1.store_id AS store1, s2.store_id AS store2
FROM (SELECT st.store_id, st.region_id, COUNT(*) AS order_count FROM sales.orders o JOIN stores.stores st ON o.store_id = st.store_id GROUP BY st.store_id, st.region_id) s1
JOIN (SELECT st.store_id, st.region_id, COUNT(*) AS order_count FROM sales.orders o JOIN stores.stores st ON o.store_id = st.store_id GROUP BY st.store_id, st.region_id) s2
  ON s1.region_id = s2.region_id AND s2.order_count > s1.order_count AND s2.store_id <> s1.store_id
LIMIT 200;

/* Q40. */
WITH wh_latest AS (
  SELECT warehouse_id, SUM(quantity_on_hand) AS total_qty
  FROM supply_chain.inventory_snapshots
  WHERE snapshot_date = (SELECT MAX(snapshot_date) FROM supply_chain.inventory_snapshots)
  GROUP BY warehouse_id
)
SELECT w1.warehouse_id AS warehouse1, w2.warehouse_id AS warehouse2
FROM wh_latest w1
JOIN wh_latest w2 ON w2.total_qty > w1.total_qty;

/* Q41. */
SELECT e1.employee_id AS emp1, e2.employee_id AS emp2, e2.joining_date - e1.joining_date AS days_apart
FROM stores.employees e1
JOIN stores.employees e2 ON e2.joining_date = e1.joining_date + INTERVAL '30 days'
LIMIT 200;

/* Q42. */
SELECT cust_id, COUNT(*) AS orders_in_7_days
FROM (
  SELECT o1.cust_id, o1.order_id
  FROM sales.orders o1
  JOIN sales.orders o2
    ON o1.cust_id = o2.cust_id AND o1.order_id <> o2.order_id
   AND o2.order_date BETWEEN o1.order_date AND o1.order_date + 7
) x
GROUP BY cust_id
HAVING COUNT(*) >= 2;

/* Q43. */
SELECT DISTINCT t1.customer_id
FROM support.tickets t1
JOIN support.tickets t2
  ON t1.customer_id = t2.customer_id AND t1.ticket_id <> t2.ticket_id
 AND DATE_TRUNC('week', t1.created_date) = DATE_TRUNC('week', t2.created_date);

/* Q44. */
SELECT r1.customer_id, r1.review_id AS review1, r2.review_id AS review2, r1.rating
FROM customers.reviews r1
JOIN customers.reviews r2
  ON r1.customer_id = r2.customer_id AND r1.product_id <> r2.product_id
 AND r1.rating = r2.rating AND r1.review_id < r2.review_id
LIMIT 200;

/* Q45. */
SELECT i1.product_id, i1.warehouse_id AS warehouse1, i2.warehouse_id AS warehouse2, i1.quantity_on_hand
FROM supply_chain.inventory_snapshots i1
JOIN supply_chain.inventory_snapshots i2
  ON i1.product_id = i2.product_id AND i1.warehouse_id < i2.warehouse_id
 AND i1.quantity_on_hand = i2.quantity_on_hand
 AND i1.snapshot_date = (SELECT MAX(snapshot_date) FROM supply_chain.inventory_snapshots)
 AND i2.snapshot_date = i1.snapshot_date
LIMIT 200;

/* Q46. */
SELECT c1.customer_id AS cust1, c2.customer_id AS cust2, a1.city
FROM customers.customers c1
JOIN customers.addresses a1 ON a1.customer_id = c1.customer_id AND a1.is_default = TRUE
JOIN customers.customers c2 ON c2.tier <> c1.tier AND c2.customer_id > c1.customer_id
JOIN customers.addresses a2 ON a2.customer_id = c2.customer_id AND a2.is_default = TRUE AND a2.city = a1.city
WHERE c1.customer_id <= 500
LIMIT 200;

/* Q47. */
SELECT cust_id, order_date, COUNT(*) AS same_day_orders
FROM sales.orders
GROUP BY cust_id, order_date
HAVING COUNT(*) >= 3;

/* Q48. */
SELECT pv1.session_id, pv1.page_url, COUNT(*) AS visits_to_same_url
FROM web_events.page_views pv1
GROUP BY pv1.session_id, pv1.page_url
HAVING COUNT(*) >= 2
LIMIT 200;

/* Q49. */
SELECT t1.customer_id, t1.ticket_id AS critical_ticket, t2.ticket_id AS low_ticket
FROM support.tickets t1
JOIN support.tickets t2
  ON t1.customer_id = t2.customer_id AND t1.priority = 'Critical' AND t2.priority = 'Low'
LIMIT 200;

/* Q50. */
SELECT p1.product_id AS product1, p2.product_id AS product2, p1.supplier_id, b1.category_id
FROM products.products p1
JOIN core.dim_brand b1 ON p1.brand_id = b1.brand_id
JOIN products.products p2 ON p2.supplier_id = p1.supplier_id AND p2.product_id > p1.product_id
JOIN core.dim_brand b2 ON p2.brand_id = b2.brand_id AND b2.category_id = b1.category_id
LIMIT 200;

/* ============================================================
   SECTION C: FULL OUTER + CROSS JOIN GRIDS (25)
   ------------------------------------------------------------ */
/* Q51. */
SELECT
  CASE WHEN c.customer_id IS NOT NULL AND o.cust_id IS NOT NULL THEN 'both'
       WHEN c.customer_id IS NOT NULL THEN 'customer_only'
       WHEN o.cust_id IS NOT NULL THEN 'order_only'
       ELSE 'neither' END AS bucket,
  COUNT(*) AS row_count
FROM customers.customers c
FULL OUTER JOIN (SELECT DISTINCT cust_id FROM sales.orders) o ON o.cust_id = c.customer_id
GROUP BY bucket;

/* Q52. */
SELECT ps.pay_slip_id, ps.employee_id
FROM payroll.pay_slips ps
FULL OUTER JOIN stores.employees e ON ps.employee_id = e.employee_id
WHERE e.employee_id IS NULL;

/* Q53. */
SELECT
  CASE WHEN o.order_id IS NOT NULL AND p.order_id IS NOT NULL THEN 'both'
       WHEN o.order_id IS NOT NULL THEN 'order_only'
       ELSE 'payment_only' END AS bucket,
  COUNT(*) AS row_count
FROM sales.orders o
FULL OUTER JOIN sales.payments p ON o.order_id = p.order_id
GROUP BY bucket;

/* Q54. */
SELECT
  CASE WHEN o.order_id IS NOT NULL AND sh.order_id IS NOT NULL THEN 'both'
       WHEN o.order_id IS NOT NULL THEN 'order_only'
       ELSE 'shipment_only' END AS bucket,
  COUNT(*) AS row_count
FROM sales.orders o
FULL OUTER JOIN sales.shipments sh ON o.order_id = sh.order_id
GROUP BY bucket;

/* Q55. */
SELECT m.customer_id, c.customer_id AS matched_customer_id
FROM loyalty.members m
FULL OUTER JOIN customers.customers c ON m.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

/* Q56. */
SELECT r.region_name, mon.order_month, COALESCE(SUM(o.net_total), 0) AS revenue
FROM core.dim_region r
CROSS JOIN (SELECT DISTINCT DATE_TRUNC('month', order_date) AS order_month FROM sales.orders) mon
LEFT JOIN stores.stores s ON s.region_id = r.region_id
LEFT JOIN sales.orders o ON o.store_id = s.store_id AND DATE_TRUNC('month', o.order_date) = mon.order_month
GROUP BY r.region_name, mon.order_month
ORDER BY r.region_name, mon.order_month;

/* Q57. */
SELECT p.platform, mon.spend_month, COALESCE(SUM(a.amount), 0) AS total_spend
FROM (SELECT DISTINCT platform FROM marketing.ads_spend) p
CROSS JOIN (SELECT DISTINCT DATE_TRUNC('month', spend_date) AS spend_month FROM marketing.ads_spend) mon
LEFT JOIN marketing.ads_spend a ON a.platform = p.platform AND DATE_TRUNC('month', a.spend_date) = mon.spend_month
GROUP BY p.platform, mon.spend_month
ORDER BY p.platform, mon.spend_month;

/* Q58. */
SELECT pr.priority, mon.ticket_month, COALESCE(COUNT(t.ticket_id), 0) AS ticket_count
FROM (SELECT DISTINCT priority FROM support.tickets) pr
CROSS JOIN (SELECT DISTINCT DATE_TRUNC('month', created_date) AS ticket_month FROM support.tickets) mon
LEFT JOIN support.tickets t ON t.priority = pr.priority AND DATE_TRUNC('month', t.created_date) = mon.ticket_month
GROUP BY pr.priority, mon.ticket_month
ORDER BY pr.priority, mon.ticket_month;

/* Q59. */
SELECT dt.device_type, wk.view_week, COALESCE(COUNT(pv.view_id), 0) AS view_count
FROM (SELECT DISTINCT device_type FROM web_events.page_views) dt
CROSS JOIN (SELECT DISTINCT DATE_TRUNC('week', view_timestamp) AS view_week FROM web_events.page_views) wk
LEFT JOIN web_events.page_views pv ON pv.device_type = dt.device_type AND DATE_TRUNC('week', pv.view_timestamp) = wk.view_week
GROUP BY dt.device_type, wk.view_week
ORDER BY dt.device_type, wk.view_week;

/* Q60. */
WITH customer_category AS (
  SELECT DISTINCT o.cust_id, cat.category_name
  FROM sales.orders o
  JOIN sales.order_items oi ON oi.order_id = o.order_id
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON p.brand_id = b.brand_id
  JOIN core.dim_category cat ON b.category_id = cat.category_id
)
SELECT cat.category_name, t.tier, COUNT(DISTINCT cc.cust_id) AS distinct_customers
FROM core.dim_category cat
CROSS JOIN (SELECT DISTINCT tier FROM customers.customers) t
LEFT JOIN customer_category cc ON cc.category_name = cat.category_name
LEFT JOIN customers.customers cu ON cu.customer_id = cc.cust_id AND cu.tier = t.tier
GROUP BY cat.category_name, t.tier
ORDER BY cat.category_name, t.tier;

/* Q61. */
SELECT cr.courier_name, mon.ship_month, COALESCE(COUNT(sh.shipment_id), 0) AS shipment_count
FROM (SELECT DISTINCT courier_name FROM sales.shipments) cr
CROSS JOIN (SELECT DISTINCT DATE_TRUNC('month', shipped_date) AS ship_month FROM sales.shipments) mon
LEFT JOIN sales.shipments sh ON sh.courier_name = cr.courier_name AND DATE_TRUNC('month', sh.shipped_date) = mon.ship_month
GROUP BY cr.courier_name, mon.ship_month
ORDER BY cr.courier_name, mon.ship_month;

/* Q62. */
SELECT w.warehouse_id, d.day, COALESCE(isn.quantity_on_hand, 0) AS quantity_on_hand
FROM supply_chain.warehouses w
CROSS JOIN GENERATE_SERIES((SELECT MAX(snapshot_date) FROM supply_chain.inventory_snapshots) - 6,
                            (SELECT MAX(snapshot_date) FROM supply_chain.inventory_snapshots), '1 day') AS d(day)
LEFT JOIN supply_chain.inventory_snapshots isn ON isn.warehouse_id = w.warehouse_id AND isn.snapshot_date = d.day
ORDER BY w.warehouse_id, d.day
LIMIT 200;

/* Q63. */
SELECT d.dept_name, mon.salary_year, mon.salary_month, COALESCE(SUM(ps.gross_salary), 0) AS total_payroll
FROM core.dim_department d
CROSS JOIN (SELECT DISTINCT salary_year, salary_month FROM payroll.pay_slips) mon
LEFT JOIN stores.employees e ON e.dept_id = d.dept_id
LEFT JOIN payroll.pay_slips ps ON ps.employee_id = e.employee_id AND ps.salary_year = mon.salary_year AND ps.salary_month = mon.salary_month
GROUP BY d.dept_name, mon.salary_year, mon.salary_month
LIMIT 200;

/* Q64. */
SELECT r.region_name, cat.category_name, COALESCE(SUM(oi.net_amount), 0) AS revenue
FROM core.dim_region r
CROSS JOIN core.dim_category cat
LEFT JOIN stores.stores s ON s.region_id = r.region_id
LEFT JOIN sales.orders o ON o.store_id = s.store_id
LEFT JOIN sales.order_items oi ON oi.order_id = o.order_id
LEFT JOIN products.products p ON p.product_id = oi.prod_id
LEFT JOIN core.dim_brand b ON p.brand_id = b.brand_id AND b.category_id = cat.category_id
GROUP BY r.region_name, cat.category_name;

/* Q65. */
SELECT st.order_status, mon.order_month, COALESCE(COUNT(o.order_id), 0) AS order_count
FROM (SELECT DISTINCT order_status FROM sales.orders) st
CROSS JOIN (SELECT DISTINCT DATE_TRUNC('month', order_date) AS order_month FROM sales.orders) mon
LEFT JOIN sales.orders o ON o.order_status = st.order_status AND DATE_TRUNC('month', o.order_date) = mon.order_month
GROUP BY st.order_status, mon.order_month
ORDER BY st.order_status, mon.order_month;

/* Q66. */
SELECT r.region_name, gs.month_start
FROM core.dim_region r
CROSS JOIN GENERATE_SERIES('2024-01-01'::date, '2026-02-26'::date, '1 month') AS gs(month_start);

/* Q67. */
SELECT tr.tier_name, d.dept_name
FROM loyalty.tiers tr
CROSS JOIN core.dim_department d;

/* Q68. */
SELECT b.brand_name, r.region_name, COALESCE(SUM(oi.net_amount), 0) AS revenue
FROM core.dim_brand b
CROSS JOIN core.dim_region r
LEFT JOIN products.products p ON p.brand_id = b.brand_id
LEFT JOIN sales.order_items oi ON oi.prod_id = p.product_id
LEFT JOIN sales.orders o ON oi.order_id = o.order_id
LEFT JOIN stores.stores s ON o.store_id = s.store_id AND s.region_id = r.region_id
GROUP BY b.brand_name, r.region_name
LIMIT 200;

/* Q69. */
SELECT cr.courier_name, st.order_status, COUNT(*) AS shipment_count
FROM (SELECT DISTINCT courier_name FROM sales.shipments) cr
CROSS JOIN (SELECT DISTINCT order_status FROM sales.orders) st
LEFT JOIN sales.shipments sh ON sh.courier_name = cr.courier_name
LEFT JOIN sales.orders o ON o.order_id = sh.order_id AND o.order_status = st.order_status
GROUP BY cr.courier_name, st.order_status;

/* Q70. */
SELECT lv.level, sv.service_name, COALESCE(COUNT(al.log_id), 0) AS log_count
FROM (SELECT DISTINCT level FROM audit.application_logs) lv
CROSS JOIN (SELECT DISTINCT service_name FROM audit.application_logs) sv
LEFT JOIN audit.application_logs al ON al.level = lv.level AND al.service_name = sv.service_name
GROUP BY lv.level, sv.service_name
ORDER BY lv.level, sv.service_name;

/* Q71. */
SELECT gs::date AS calendar_date,
       EXTRACT(WEEK FROM gs) AS week_of_year,
       (EXTRACT(DOW FROM gs) IN (0, 6)) AS is_weekend
FROM GENERATE_SERIES('2024-01-01'::date, '2026-02-26'::date, '1 day') AS gs
LIMIT 200;

/* Q72. */
SELECT c.customer_id, camp.campaign_id
FROM customers.customers c
CROSS JOIN marketing.campaigns camp
WHERE c.customer_id <= 20
LIMIT 200;

/* Q73. */
SELECT r.region_name, tr.tier_name, mon.month_start
FROM core.dim_region r
CROSS JOIN loyalty.tiers tr
CROSS JOIN GENERATE_SERIES('2025-01-01'::date, '2025-12-01'::date, '1 month') AS mon(month_start)
LIMIT 200;

/* Q74. */
SELECT sup.supplier_id, p.product_id
FROM products.suppliers sup
CROSS JOIN products.products p
WHERE NOT EXISTS (SELECT 1 FROM products.products p2 WHERE p2.product_id = p.product_id AND p2.supplier_id = sup.supplier_id)
LIMIT 200;

/* Q75. */
SELECT o.order_id, gs.installment_no
FROM sales.orders o
CROSS JOIN GENERATE_SERIES(1, 3) AS gs(installment_no)
WHERE o.order_id <= 20
ORDER BY o.order_id, gs.installment_no;

/* ============================================================
   SECTION D: UNION / INTERSECT / EXCEPT / LATERAL (25)
   ------------------------------------------------------------ */
/* Q76. */
SELECT cust_id AS customer_id, 'order' AS touchpoint, order_id::text AS ref_id, order_date AS touch_date FROM sales.orders
UNION ALL
SELECT customer_id, 'review', review_id::text, review_date FROM customers.reviews
UNION ALL
SELECT customer_id, 'ticket', ticket_id::text, created_date::date FROM support.tickets
UNION ALL
SELECT customer_id, 'call', call_id::text, call_start_time::date FROM call_center.calls;

/* Q77. */
SELECT COUNT(DISTINCT customer_id) AS distinct_customers
FROM (
  SELECT cust_id AS customer_id FROM sales.orders
  UNION ALL
  SELECT customer_id FROM customers.reviews
  UNION ALL
  SELECT customer_id FROM support.tickets
) x;

/* Q78. */
SELECT DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS amount, 'revenue' AS stream FROM sales.orders GROUP BY DATE_TRUNC('month', order_date)
UNION ALL
SELECT DATE_TRUNC('month', spend_date), -SUM(amount), 'ad_spend' FROM marketing.ads_spend GROUP BY DATE_TRUNC('month', spend_date)
ORDER BY month;

/* Q79. */
WITH cat_revenue AS (
  SELECT cat.category_name, SUM(oi.net_amount) AS revenue
  FROM sales.order_items oi
  JOIN products.products p ON oi.prod_id = p.product_id
  JOIN core.dim_brand b ON p.brand_id = b.brand_id
  JOIN core.dim_category cat ON b.category_id = cat.category_id
  GROUP BY cat.category_name
)
(SELECT category_name, revenue, 'top5' AS label FROM cat_revenue ORDER BY revenue DESC LIMIT 5)
UNION ALL
(SELECT category_name, revenue, 'bottom5' FROM cat_revenue ORDER BY revenue ASC LIMIT 5);

/* Q80. */
SELECT cust_id AS customer_id FROM sales.orders
INTERSECT
SELECT customer_id FROM customers.reviews
INTERSECT
SELECT customer_id FROM support.tickets;

/* Q81. */
SELECT DISTINCT product_id FROM supply_chain.inventory_snapshots
EXCEPT
SELECT DISTINCT prod_id FROM sales.order_items;

/* Q82. */
SELECT cust_id AS customer_id FROM sales.orders
EXCEPT
SELECT customer_id FROM customers.reviews;

/* Q83. */
SELECT employee_id FROM stores.employees
EXCEPT
SELECT employee_id FROM payroll.pay_slips;

/* Q84. supply_chain.inventory_snapshots has no store_id (it tracks warehouse_id); products.inventory is the store-level inventory table used instead. */
SELECT store_id FROM stores.employees
INTERSECT
SELECT store_id FROM sales.orders
INTERSECT
SELECT store_id FROM products.inventory;

/* Q85. */
SELECT cust_id FROM sales.orders WHERE cust_id = 1
EXCEPT ALL
SELECT cust_id FROM sales.orders WHERE cust_id = 2;

/* Q86. */
SELECT DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS revenue, COUNT(*) AS order_count, 'monthly' AS grain
FROM sales.orders GROUP BY DATE_TRUNC('month', order_date)
UNION ALL
SELECT NULL, SUM(net_total), COUNT(*), 'grand_total' FROM sales.orders
ORDER BY month;

/* Q87. */
SELECT order_id, cust_id, 'Registered' AS checkout_type FROM sales.orders WHERE cust_id IS NOT NULL
UNION ALL
SELECT order_id, cust_id, 'Guest' FROM sales.orders WHERE cust_id IS NULL;

/* Q88. */
WITH weekly_revenue AS (
  SELECT DATE_TRUNC('week', order_date) AS wk, SUM(net_total) AS revenue
  FROM sales.orders GROUP BY DATE_TRUNC('week', order_date)
)
SELECT wk, revenue FROM weekly_revenue ORDER BY wk LIMIT 12;

/* Q89. */
SELECT ticket_id::text AS event_id, 'ticket' AS source, created_date::date AS event_date FROM support.tickets
UNION ALL
SELECT call_id::text, 'call', call_start_time::date FROM call_center.calls;

/* Q90. */
SELECT customer_id, 'ticket' AS source, created_date::date AS event_date FROM support.tickets
UNION ALL
SELECT customer_id, 'call', call_start_time::date FROM call_center.calls
ORDER BY customer_id, event_date;

/* Q91. */
SELECT c.customer_id, lo.order_id, lo.order_date, lo.net_total
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT o.order_id, o.order_date, o.net_total
  FROM sales.orders o
  WHERE o.cust_id = c.customer_id
  ORDER BY o.order_date DESC
  LIMIT 3
) lo
WHERE c.customer_id <= 100;

/* Q92. */
SELECT p.product_id, lr.review_id, lr.rating, lr.review_date
FROM products.products p
CROSS JOIN LATERAL (
  SELECT r.review_id, r.rating, r.review_date
  FROM customers.reviews r
  WHERE r.product_id = p.product_id
  ORDER BY r.review_date DESC
  LIMIT 1
) lr;

/* Q93. */
SELECT r.region_name, top_stores.store_name, top_stores.revenue
FROM core.dim_region r
CROSS JOIN LATERAL (
  SELECT s.store_name, SUM(o.net_total) AS revenue
  FROM stores.stores s
  JOIN sales.orders o ON o.store_id = s.store_id
  WHERE s.region_id = r.region_id
  GROUP BY s.store_name
  ORDER BY SUM(o.net_total) DESC
  LIMIT 5
) top_stores;

/* Q94. */
SELECT cat.category_name, top_products.product_name, top_products.units_sold
FROM core.dim_category cat
CROSS JOIN LATERAL (
  SELECT p.product_name, SUM(oi.quantity) AS units_sold
  FROM products.products p
  JOIN core.dim_brand b ON p.brand_id = b.brand_id
  JOIN sales.order_items oi ON oi.prod_id = p.product_id
  WHERE b.category_id = cat.category_id
  GROUP BY p.product_name
  ORDER BY SUM(oi.quantity) DESC
  LIMIT 3
) top_products;

/* Q95. */
SELECT o.order_id, gs.installment_no
FROM sales.orders o
CROSS JOIN LATERAL GENERATE_SERIES(1, 3) AS gs(installment_no)
WHERE o.order_id <= 20
ORDER BY o.order_id, gs.installment_no;

/* Q96. */
SELECT c.customer_id, dp.distinct_products
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT COUNT(DISTINCT oi.prod_id) AS distinct_products
  FROM sales.orders o
  JOIN sales.order_items oi ON oi.order_id = o.order_id
  WHERE o.cust_id = c.customer_id
) dp
WHERE c.customer_id <= 200;

/* Q97. */
SELECT s.store_id, top_emp.employee_id, top_emp.salary
FROM stores.stores s
CROSS JOIN LATERAL (
  SELECT e.employee_id, e.salary
  FROM stores.employees e
  WHERE e.store_id = s.store_id
  ORDER BY e.salary DESC
  LIMIT 1
) top_emp;

/* Q98. */
SELECT cr.courier_name, recent.shipment_id, recent.shipped_date
FROM (SELECT DISTINCT courier_name FROM sales.shipments) cr
CROSS JOIN LATERAL (
  SELECT sh.shipment_id, sh.shipped_date
  FROM sales.shipments sh
  WHERE sh.courier_name = cr.courier_name
  ORDER BY sh.shipped_date DESC
  LIMIT 5
) recent;

/* Q99. */
SELECT cust_id AS customer_id, 'order' AS source, order_id AS ref_id FROM sales.orders
UNION ALL
SELECT customer_id, 'review', review_id FROM customers.reviews
UNION ALL
SELECT customer_id, 'ticket', ticket_id FROM support.tickets
UNION ALL
SELECT customer_id, 'call', call_id FROM call_center.calls
LIMIT 500;

/* Q100. */
SELECT DISTINCT o.cust_id
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
WHERE NOT EXISTS (
  SELECT 1 FROM customers.reviews r WHERE r.customer_id = o.cust_id AND r.product_id = oi.prod_id
)
LIMIT 200;

/* ============================================================
   END OF ANSWER KEY - JOINs Part 2 (Advanced) - MEDIUM LEVEL (100/100)
============================================================ */
