/* ============================================================
   ANSWER KEY - Median, Percentiles & DISTINCT ON (EASY LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1. The median is the middle value of a sorted dataset (50th percentile) - half the values fall below it, half above. The mean (AVG) is the sum divided by the count, so it is pulled toward extreme values that the median ignores. */
/* Q2. A single very large or very small outlier shifts the sum (and thus the mean) a lot, but it can only shift the median by at most one rank position, so the median stays close to the "typical" value. */
/* Q3. It computes the 50th percentile (median) of x within each group, interpolating between the two middle values if the group has an even count. */
/* Q4. WITHIN GROUP (ORDER BY ...) tells an ordered-set aggregate (like PERCENTILE_CONT/PERCENTILE_DISC) which column and order to rank rows by before computing the percentile - it is required because these aggregates are order-sensitive, unlike SUM/AVG. */
/* Q5. PERCENTILE_CONT interpolates a value between the two nearest data points when the exact percentile falls between them (may return a value not in the data). PERCENTILE_DISC always returns an actual observed value from the dataset (the first value whose cumulative distribution meets the fraction). */
/* Q6. P90 is the value below which 90% of observations fall (the 90th percentile); P95 is the value below which 95% fall. */
/* Q7. P95 shows the experience of the worst 5% of cases (e.g. slow responses), which the average would mask by blending them in with many fast, typical cases - important for SLA guarantees. */
/* Q8. PERCENTILE_CONT(0.0) returns the minimum value; PERCENTILE_CONT(1.0) returns the maximum value. */
/* Q9. Yes - it is a built-in "ordered-set aggregate function", a special aggregate category that requires WITHIN GROUP (ORDER BY ...) instead of a plain argument list. */
/* Q10. Yes - GROUP BY still applies as normal, so PERCENTILE_CONT computes a separate percentile per group, just like AVG or SUM would. */
/* Q11. DISTINCT ON (col) keeps only the first row for each distinct value of col, based on the query's ORDER BY - it is PostgreSQL's shortcut for "one row per group". */
/* Q12. Without ORDER BY, DISTINCT ON would keep an arbitrary (unspecified) row per group instead of a deterministic one - ORDER BY must start with the DISTINCT ON column(s) and then define tie-breaking order for which row "wins". */
/* Q13. The row that sorts first per group according to the full ORDER BY clause (DISTINCT ON columns first, then any tie-breaker columns). */
/* Q14. GROUP BY collapses rows into aggregated summary values (counts, sums, etc.) per group; DISTINCT ON keeps one full, original row per group with all its original columns intact. */
/* Q15. Both return "one row per group", but ROW_NUMBER() = 1 requires a subquery/CTE with an explicit PARTITION BY and a WHERE filter, while DISTINCT ON does it directly in one SELECT with no extra wrapping - more concise for this specific pattern. */
/* Q16. "Latest record per group" means, for each entity (e.g. each customer), keeping only their single most recent row (e.g. their most recent order) instead of their whole history. */
/* Q17. DISTINCT ON is not part of the SQL standard - it is a PostgreSQL-only extension, so the same query would need ROW_NUMBER() or a correlated subquery on other database engines. */
/* Q18. Because the true percentile rank may fall between two adjacent sorted values (e.g. between the 5th and 6th of 10 rows), so PERCENTILE_CONT linearly interpolates between them to produce a continuous estimate. */
/* Q19. When the metric must be a value that actually occurred (e.g. reporting an actual transaction amount or an actual SKU price), not a mathematically interpolated number that was never really observed. */
/* Q20. mode() WITHIN GROUP (ORDER BY x) returns the most frequently occurring value of x in the group. */
/* Q21. percent_rank() and cume_dist() compute each individual row's percentile-rank position within its window, whereas PERCENTILE_CONT/DISC compute the value AT a given percentile - they are two directions of the same percentile concept. */
/* Q22. NTILE(100) divides the ordered rows into 100 roughly equal-sized buckets, so a row's bucket number approximates which percentile band it falls into. */
/* Q23. If a few orders have very long delivery times (e.g. logistics failures), the average delivery time is pulled up and looks worse than what most customers experience, while the median reflects the typical customer's actual wait. */
/* Q24. Yes - PERCENTILE_CONT(ARRAY[0.5,0.9,0.95]) WITHIN GROUP (ORDER BY x) returns an array of results, one percentile value per fraction, computed in a single aggregate call. */
/* Q25. Median household/order value (resistant to a few big-spender outliers) and median delivery/resolution time (resistant to a few extreme delays) are both better expressed as medians than as means. */

/* ============================================================
   SECTION B: MEDIAN & PERCENTILES (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total) AS median_net_total
FROM sales.orders;
/* Q27. */
SELECT ROUND(AVG(net_total), 2) AS avg_net_total,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total) AS median_net_total
FROM sales.orders;
/* Q28. */
SELECT PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY net_total) AS p90_net_total,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY net_total) AS p95_net_total
FROM sales.orders;
/* Q29. */
SELECT r.region_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_net_total
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q30. */
SELECT s.store_id, s.store_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_net_total
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
GROUP BY s.store_id, s.store_name
ORDER BY s.store_id;
/* Q31. */
SELECT r.region_name,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_net_total
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q32. */
SELECT pm.mode_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_order_value
FROM sales.orders o
JOIN finance.payment_modes pm ON pm.mode_id = o.payment_mode_id
GROUP BY pm.mode_name
ORDER BY pm.mode_name;
/* Q33. */
SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sh.delivered_date - o.order_date) AS median_delivery_days
FROM sales.orders o
JOIN sales.shipments sh ON sh.order_id = o.order_id
WHERE o.order_status = 'Delivered' AND sh.delivered_date IS NOT NULL;
/* Q34. */
SELECT PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY sh.delivered_date - o.order_date) AS p90_delivery_days
FROM sales.orders o
JOIN sales.shipments sh ON sh.order_id = o.order_id
WHERE o.order_status = 'Delivered' AND sh.delivered_date IS NOT NULL;
/* Q35. */
SELECT r.region_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sh.delivered_date - o.order_date) AS median_delivery_days
FROM sales.orders o
JOIN sales.shipments sh ON sh.order_id = o.order_id
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
WHERE o.order_status = 'Delivered' AND sh.delivered_date IS NOT NULL
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q36. */
SELECT product_id,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rating) AS median_rating
FROM customers.reviews
GROUP BY product_id
ORDER BY product_id;
/* Q37. */
SELECT agent_id,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY call_duration_seconds) AS median_call_duration_sec
FROM call_center.calls
GROUP BY agent_id
ORDER BY agent_id;
/* Q38. */
SELECT PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY call_duration_seconds) AS p95_call_duration_sec
FROM call_center.calls;
/* Q39. */
SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY refund_amount) AS median_refund_amount
FROM sales.returns;
/* Q40. */
SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_salary) AS median_net_salary
FROM payroll.pay_slips;
/* Q41. */
SELECT d.dept_name,
       PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY ps.net_salary) AS p90_net_salary
FROM payroll.pay_slips ps
JOIN stores.employees e ON e.employee_id = ps.employee_id
JOIN core.dim_department d ON d.dept_id = e.dept_id
GROUP BY d.dept_name
ORDER BY d.dept_name;
/* Q42. */
SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY quantity) AS median_line_quantity
FROM sales.order_items;
/* Q43. */
SELECT c.category_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY oi.unit_price) AS median_unit_price
FROM sales.order_items oi
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category c ON c.category_id = b.category_id
GROUP BY c.category_name
ORDER BY c.category_name;
/* Q44. */
SELECT platform,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount) AS median_daily_spend
FROM marketing.ads_spend
GROUP BY platform
ORDER BY platform;
/* Q45. */
SELECT t.tier_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY m.points_balance) AS median_points_balance
FROM loyalty.members m
JOIN loyalty.tiers t ON t.tier_id = m.tier_id
GROUP BY t.tier_name
ORDER BY t.tier_name;
/* Q46. */
SELECT c.tier,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_net_total
FROM sales.orders o
JOIN customers.customers c ON c.customer_id = o.cust_id
GROUP BY c.tier
ORDER BY c.tier;
/* Q47. */
SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600.0) AS median_resolution_hours
FROM support.tickets
WHERE resolved_date IS NOT NULL;
/* Q48. */
SELECT priority,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600.0) AS p95_resolution_hours
FROM support.tickets
WHERE resolved_date IS NOT NULL
GROUP BY priority
ORDER BY priority;
/* Q49. */
SELECT date_trunc('month', order_date)::date AS month,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total) AS median_order_value
FROM sales.orders
WHERE EXTRACT(YEAR FROM order_date) = 2025
GROUP BY month
ORDER BY month;
/* Q50. */
SELECT r.region_name,
       PERCENTILE_CONT(ARRAY[0.5, 0.95]) WITHIN GROUP (ORDER BY o.net_total) AS median_and_p95
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;

/* ============================================================
   SECTION C: DISTINCT ON - latest record per group (25)
   ------------------------------------------------------------ */
/* Q51. */
SELECT DISTINCT ON (cust_id) cust_id, order_id, order_date, net_total, order_status
FROM sales.orders
ORDER BY cust_id, order_date DESC;
/* Q52. */
SELECT DISTINCT ON (cust_id) cust_id, order_id, order_date, order_status
FROM sales.orders
ORDER BY cust_id, order_date DESC;
/* Q53. */
SELECT DISTINCT ON (customer_id) customer_id, review_id, product_id, rating, review_date
FROM customers.reviews
ORDER BY customer_id, review_date DESC;
/* Q54. */
SELECT DISTINCT ON (product_id) product_id, review_id, customer_id, rating, review_date
FROM customers.reviews
ORDER BY product_id, review_date DESC;
/* Q55. */
SELECT DISTINCT ON (customer_id) customer_id, ticket_id, category, priority, status, created_date
FROM support.tickets
ORDER BY customer_id, created_date DESC;
/* Q56. */
SELECT DISTINCT ON (order_id) order_id, payment_id, payment_date, payment_mode, amount
FROM sales.payments
ORDER BY order_id, payment_date DESC;
/* Q57. */
SELECT DISTINCT ON (order_id) order_id, shipment_id, courier_name, shipped_date, delivered_date, status
FROM sales.shipments
ORDER BY order_id, shipped_date DESC;
/* Q58. */
SELECT DISTINCT ON (warehouse_id, product_id) warehouse_id, product_id, snapshot_date, quantity_on_hand
FROM supply_chain.inventory_snapshots
ORDER BY warehouse_id, product_id, snapshot_date DESC;
/* Q59. */
SELECT DISTINCT ON (employee_id) employee_id, payment_id, amount, payment_date, status
FROM hr.salary_history
ORDER BY employee_id, payment_date DESC;
/* Q60. */
SELECT DISTINCT ON (oi.prod_id) oi.prod_id, o.order_date, oi.unit_price
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
ORDER BY oi.prod_id, o.order_date DESC;
/* Q61. */
SELECT DISTINCT ON (customer_id) customer_id, view_id, page_url, view_timestamp
FROM web_events.page_views
WHERE customer_id IS NOT NULL
ORDER BY customer_id, view_timestamp DESC;
/* Q62. */
SELECT DISTINCT ON (cust_id) cust_id, order_id, order_date, net_total
FROM sales.orders
ORDER BY cust_id, order_date ASC;
/* Q63. */
SELECT DISTINCT ON (cust_id) cust_id, order_id, order_date, net_total
FROM sales.orders
ORDER BY cust_id, net_total DESC;
/* Q64. */
SELECT DISTINCT ON (cust_id) cust_id, order_id, order_date, net_total
FROM sales.orders
ORDER BY cust_id, net_total ASC;
/* Q65. */
SELECT DISTINCT ON (agent_id) agent_id, call_id, call_start_time, call_duration_seconds
FROM call_center.calls
ORDER BY agent_id, call_start_time DESC;
/* Q66. */
SELECT DISTINCT ON (customer_id) customer_id, redemption_id, reward_name, points_redeemed, redemption_date
FROM loyalty.redemptions
ORDER BY customer_id, redemption_date DESC;
/* Q67. */
SELECT DISTINCT ON (store_id) store_id, order_id, order_date, net_total
FROM sales.orders
ORDER BY store_id, order_date DESC;
/* Q68. */
SELECT DISTINCT ON (r.region_name) r.region_name, o.order_id, o.order_date, o.net_total
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
ORDER BY r.region_name, o.order_date DESC;
/* Q69. */
SELECT DISTINCT ON (a.state) a.state, c.customer_id, c.first_name, c.last_name, c.registration_date
FROM customers.customers c
JOIN customers.addresses a ON a.customer_id = c.customer_id
ORDER BY a.state, c.registration_date DESC;
/* Q70. */
SELECT DISTINCT ON (platform) platform, spend_id, spend_date, amount
FROM marketing.ads_spend
ORDER BY platform, spend_date DESC;
/* Q71. */
SELECT DISTINCT ON (store_id) store_id, store_expense_id, expense_type, amount, expense_date
FROM stores.expenses
ORDER BY store_id, expense_date DESC;
/* Q72. */
SELECT DISTINCT ON (line_id) line_id, work_order_id, product_id, start_timestamp, status
FROM manufacture.work_orders
ORDER BY line_id, start_timestamp DESC;
/* Q73. */
SELECT DISTINCT ON (product_id) product_id, review_id, customer_id, rating, review_date
FROM customers.reviews
ORDER BY product_id, rating DESC;
/* Q74. */
SELECT DISTINCT ON (employee_id) employee_id, attendance_id, attendance_date, check_in, check_out
FROM hr.attendance
ORDER BY employee_id, attendance_date DESC;
/* Q75. */
SELECT DISTINCT ON (from_account) from_account, transfer_id, to_account, amount, transferred_at
FROM finance.transfer_log
ORDER BY from_account, transferred_at DESC;

/* ============================================================
   SECTION D: COMBINED / MIXED (25)
   ------------------------------------------------------------ */
/* Q76. */
WITH latest AS (
    SELECT DISTINCT ON (cust_id) cust_id, order_date AS latest_order_date
    FROM sales.orders
    ORDER BY cust_id, order_date DESC
)
SELECT o.cust_id,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_net_total,
       MAX(l.latest_order_date) AS latest_order_date
FROM sales.orders o
JOIN latest l ON l.cust_id = o.cust_id
GROUP BY o.cust_id
ORDER BY o.cust_id;
/* Q77. */
WITH latest AS (
    SELECT DISTINCT ON (r.region_name) r.region_name, o.order_id, o.order_date, o.net_total
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    ORDER BY r.region_name, o.order_date DESC
),
medians AS (
    SELECT r.region_name, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_order_value
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_name
)
SELECT m.region_name, m.median_order_value, l.order_id AS latest_order_id, l.order_date, l.net_total
FROM medians m
JOIN latest l ON l.region_name = m.region_name
ORDER BY m.region_name;
/* Q78. */
WITH latest AS (
    SELECT DISTINCT ON (store_id) store_id, order_status AS latest_status, order_date
    FROM sales.orders
    ORDER BY store_id, order_date DESC
)
SELECT o.store_id,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_net_total,
       MAX(l.latest_status) AS latest_status
FROM sales.orders o
JOIN latest l ON l.store_id = o.store_id
GROUP BY o.store_id
ORDER BY o.store_id;
/* Q79. */
SELECT w.warehouse_id, w.name AS warehouse_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sh.delivered_date - o.order_date) AS median_delivery_days
FROM sales.orders o
JOIN sales.shipments sh ON sh.order_id = o.order_id
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
JOIN supply_chain.warehouses w ON w.region = r.region_name
WHERE o.order_status = 'Delivered' AND sh.delivered_date IS NOT NULL
GROUP BY w.warehouse_id, w.name
ORDER BY w.warehouse_id;
/* Q80. */
WITH latest AS (
    SELECT DISTINCT ON (cust_id) cust_id, net_total
    FROM sales.orders
    ORDER BY cust_id, order_date DESC
)
SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total) AS median_of_latest_orders
FROM latest;
/* Q81. */
SELECT r.region_name,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_net_total
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY p95_net_total DESC;
/* Q82. */
WITH latest_review AS (
    SELECT DISTINCT ON (product_id) product_id, review_text AS latest_review_text, review_date
    FROM customers.reviews
    ORDER BY product_id, review_date DESC
)
SELECT r.product_id,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY r.rating) AS median_rating,
       MAX(lr.latest_review_text) AS latest_review_text
FROM customers.reviews r
JOIN latest_review lr ON lr.product_id = r.product_id
GROUP BY r.product_id
ORDER BY r.product_id;
/* Q83. */
WITH latest_call AS (
    SELECT DISTINCT ON (agent_id) agent_id, call_start_time AS latest_call_time
    FROM call_center.calls
    ORDER BY agent_id, call_start_time DESC
)
SELECT c.agent_id,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY c.call_duration_seconds) AS median_call_duration_sec,
       MAX(lc.latest_call_time) AS latest_call_time
FROM call_center.calls c
JOIN latest_call lc ON lc.agent_id = c.agent_id
GROUP BY c.agent_id
ORDER BY c.agent_id;
/* Q84. */
WITH latest_ticket AS (
    SELECT DISTINCT ON (customer_id) customer_id, ticket_id AS latest_ticket_id, created_date
    FROM support.tickets
    ORDER BY customer_id, created_date DESC
)
SELECT t.customer_id,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (t.resolved_date - t.created_date)) / 3600.0) AS median_resolution_hours,
       MAX(lt.latest_ticket_id) AS latest_ticket_id
FROM support.tickets t
JOIN latest_ticket lt ON lt.customer_id = t.customer_id
WHERE t.resolved_date IS NOT NULL
GROUP BY t.customer_id
ORDER BY t.customer_id;
/* Q85. */
SELECT c.tier,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_net_total,
       COUNT(DISTINCT c.customer_id) AS customer_count
FROM sales.orders o
JOIN customers.customers c ON c.customer_id = o.cust_id
GROUP BY c.tier
ORDER BY c.tier;
/* Q86. */
SELECT r.region_name,
       ROUND(AVG(o.net_total), 2) AS avg_net_total,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_net_total,
       ROUND((AVG(o.net_total) - PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total))::numeric, 2) AS gap
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q87. */
SELECT pm.mode_name,
       PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY o.net_total) AS p90_net_total
FROM sales.orders o
JOIN finance.payment_modes pm ON pm.mode_id = o.payment_mode_id
GROUP BY pm.mode_name
HAVING COUNT(*) > 100
ORDER BY pm.mode_name;
/* Q88. */
SELECT DISTINCT ON (cust_id) cust_id, order_id, order_date, order_status, net_total
FROM sales.orders
WHERE order_status = 'Delivered'
ORDER BY cust_id, order_date DESC;
/* Q89. */
WITH latest AS (
    SELECT DISTINCT ON (cust_id) cust_id, net_total
    FROM sales.orders
    ORDER BY cust_id, order_date DESC
)
SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total) AS median_net_total_of_latest_orders
FROM latest;
/* Q90. */
WITH latest_price AS (
    SELECT DISTINCT ON (p.product_id) p.product_id, oi.unit_price AS latest_selling_price
    FROM sales.order_items oi
    JOIN sales.orders o ON o.order_id = oi.order_id
    JOIN products.products p ON p.product_id = oi.prod_id
    ORDER BY p.product_id, o.order_date DESC
)
SELECT c.category_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY oi.unit_price) AS median_unit_price,
       ROUND(AVG(lp.latest_selling_price), 2) AS avg_latest_selling_price
FROM sales.order_items oi
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category c ON c.category_id = b.category_id
JOIN latest_price lp ON lp.product_id = p.product_id
GROUP BY c.category_name
ORDER BY c.category_name;
/* Q91. */
WITH latest_join AS (
    SELECT DISTINCT ON (m.tier_id) m.tier_id, m.join_date AS latest_join_date
    FROM loyalty.members m
    ORDER BY m.tier_id, m.join_date DESC
)
SELECT t.tier_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY m.points_balance) AS median_points_balance,
       MAX(lj.latest_join_date) AS latest_join_date
FROM loyalty.members m
JOIN loyalty.tiers t ON t.tier_id = m.tier_id
JOIN latest_join lj ON lj.tier_id = m.tier_id
GROUP BY t.tier_name
ORDER BY t.tier_name;
/* Q92. */
SELECT r.region_name,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY sh.delivered_date - o.order_date) AS p95_delivery_days
FROM sales.orders o
JOIN sales.shipments sh ON sh.order_id = o.order_id
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
WHERE o.order_status = 'Delivered' AND sh.delivered_date IS NOT NULL
GROUP BY r.region_name
HAVING COUNT(*) > 500
ORDER BY r.region_name;
/* Q93. */
SELECT r.region_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_order_value
FROM sales.orders o
JOIN customers.customers c ON c.customer_id = o.cust_id
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
WHERE c.tier IN ('Gold', 'Platinum')
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q94. */
WITH global_median AS (
    SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total) AS med FROM sales.orders
)
SELECT DISTINCT ON (o.cust_id) o.cust_id, o.order_id, o.order_date, o.net_total
FROM sales.orders o, global_median gm
WHERE o.net_total > gm.med
ORDER BY o.cust_id, o.order_date DESC;
/* Q95. */
SELECT s.store_id,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_net_total,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_net_total
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
GROUP BY s.store_id
ORDER BY s.store_id;
/* Q96. */
WITH monthly_latest AS (
    SELECT DISTINCT ON (date_trunc('month', order_date)) date_trunc('month', order_date)::date AS month,
           order_id AS latest_order_id, order_date, net_total
    FROM sales.orders
    ORDER BY date_trunc('month', order_date), order_date DESC
)
SELECT ml.month,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_net_total,
       MAX(ml.latest_order_id) AS latest_order_id
FROM sales.orders o
JOIN monthly_latest ml ON date_trunc('month', o.order_date)::date = ml.month
GROUP BY ml.month
ORDER BY ml.month;
/* Q97. */
WITH latest AS (
    SELECT DISTINCT ON (cust_id) cust_id, order_status
    FROM sales.orders
    ORDER BY cust_id, order_date DESC
)
SELECT cust_id
FROM latest
WHERE order_status = 'Returned'
ORDER BY cust_id;
/* Q98. */
SELECT r.region_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ret.refund_amount) AS median_refund_amount
FROM sales.returns ret
JOIN sales.orders o ON o.order_id = ret.order_id
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q99. */
SELECT r.region_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) FILTER (WHERE EXTRACT(QUARTER FROM o.order_date) = 1) AS median_q1,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) FILTER (WHERE EXTRACT(QUARTER FROM o.order_date) = 2) AS median_q2,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) FILTER (WHERE EXTRACT(QUARTER FROM o.order_date) = 3) AS median_q3,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) FILTER (WHERE EXTRACT(QUARTER FROM o.order_date) = 4) AS median_q4
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q100. */
SELECT r.region_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_order_value,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_order_value
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;
