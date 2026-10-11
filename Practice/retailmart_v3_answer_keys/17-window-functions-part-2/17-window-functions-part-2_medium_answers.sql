/* ============================================================
   ANSWER KEY - Window Functions Part 2: Aggregation & Frames (MEDIUM LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1. PARTITION BY groups rows into separate windows, and a running total's frame (UNBOUNDED PRECEDING to CURRENT ROW) only looks back within that same partition, so the sum restarts at 0 whenever the partition key changes. */
/* Q2. They differ when the ORDER BY column has ties: RANGE UNBOUNDED PRECEDING treats all rows tied on that value as one peer group and sums them together for every tied row, while ROWS UNBOUNDED PRECEDING accumulates strictly row-by-row regardless of ties. */
/* Q3. Because RANGE's frame includes every row tied with the current row's ORDER BY value as a single peer group - if many rows share that value, the running sum jumps to include all of them at once instead of one row at a time. */
/* Q4. Pre-aggregate to one row per calendar day in a date-grouped subquery first, so each day appears exactly once and a fixed ROWS BETWEEN 6 PRECEDING AND CURRENT ROW window truly spans 7 calendar days. */
/* Q5. Because days with zero orders are simply absent from a GROUP BY result; a ROWS-based window would then average an uneven number of real calendar days - gap-filling with generate_series ensures every day is represented (0 where missing) before windowing. */
/* Q6. Exactly 7 rows: the 6 rows before the current row plus the current row itself. */
/* Q7. Partition the window by EXTRACT(YEAR FROM date_col) so the running total restarts at 0 on 1 January of each new year. */
/* Q8. Because the denominator (partition total) must be the same fixed value repeated on every row of that partition; SUM() OVER (PARTITION BY g) with no ORDER BY computes that whole-group total once and repeats it, so the per-row division is consistent. */
/* Q9. A trailing average looks only backward from the current row (n PRECEDING to CURRENT ROW); a centered average looks both backward and forward (n PRECEDING to n FOLLOWING), reflecting values on both sides of the point in time. */
/* Q10. Because ties or non-unique ordering let the engine order rows arbitrarily between runs, changing the computed running total - a stable ORDER BY (e.g. date plus a unique id tiebreaker) guarantees a reproducible result every time. */
/* Q11. The frame (ROWS/RANGE BETWEEN ...) only ever looks at rows within the same partition as the current row - it never reaches across a partition boundary regardless of the frame bounds. */
/* Q12. When the ORDER BY expression is a date or numeric column and the frame boundary should be a real elapsed amount (e.g. RANGE BETWEEN INTERVAL '7 days' PRECEDING AND CURRENT ROW) rather than a fixed count of physical rows. */
/* Q13. With one row per day, ROWS and RANGE usually agree, but if there are duplicate dates (several rows sharing a day) RANGE pulls all of them into the frame together while ROWS still counts by physical row position, giving a different average. */
/* Q14. Not directly - COUNT(DISTINCT x) is not supported as a window function in PostgreSQL; the workaround is a correlated subquery (or LATERAL join) that recomputes COUNT(DISTINCT x) over the relevant row range for each row. */
/* Q15. "Percent of running total" divides each row's cumulative running sum by the grand total (climbing toward 100%); "running percent" is easily confused with a row's own share of total - always state the denominator explicitly to avoid ambiguity. */
/* Q16. Because a fact table can have many rows per calendar period; pre-aggregating to the target grain first keeps a ROWS BETWEEN N PRECEDING frame meaningfully aligned with real periods instead of arbitrary transaction rows. */
/* Q17. Compute two window aggregates in the same SELECT: SUM(x) OVER (PARTITION BY g) for the fixed partition total and SUM(x) OVER (PARTITION BY g ORDER BY d) for the running total, side by side on every row. */
/* Q18. It needs an explicit frame that extends to UNBOUNDED FOLLOWING (e.g. ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) so it can see the partition's true last row, since the default ORDER BY frame stops at the current row. */
/* Q19. Because the default frame under ORDER BY only extends up to the current row, LAST_VALUE returns the current row's own value on every row except the actual last one - it looks "wrong" unless the frame is widened to the full partition. */
/* Q20. Use a frame like ROWS BETWEEN N PRECEDING AND 1 PRECEDING, ending one row before the current row instead of AND CURRENT ROW, so the current row's own value is excluded from the sum. */
/* Q21. A running max only replaces its value when a later row is strictly larger, so it can only stay flat or increase - by the same logic a running min can only stay flat or decrease, never reverse direction. */
/* Q22. Aggregate to the desired grain in an inner GROUP BY subquery/CTE first, then apply the window aggregate(s) over that already-aggregated result in an outer SELECT. */
/* Q23. RANGE with a date ORDER BY and a literal interval (e.g. RANGE BETWEEN INTERVAL '30 days' PRECEDING) reflects real elapsed time and handles irregular/missing dates better for financial running balances; ROWS is preferred when you want an exact count of transactions regardless of date gaps. */
/* Q24. Include multiple SUM() OVER (PARTITION BY ...) calls with different partition keys (e.g. by category and again with no partition) in the same SELECT, each row dividing its value by the matching denominator. */
/* Q25. Because one windowed SELECT keeps every original transaction row intact while attaching the matching subtotal/grand-total alongside it - exactly the "detail plus subtotal" shape a report needs, without a second aggregate query or self-join. */

/* ============================================================
   SECTION B: PARTITIONED RUNNING TOTALS (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT order_id, cust_id, order_date, net_total,
       SUM(net_total) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS customer_running_total
FROM sales.orders;

/* Q27. */
SELECT order_id, store_id, order_date,
       COUNT(*) OVER (PARTITION BY store_id ORDER BY order_date, order_id) AS store_running_count
FROM sales.orders;

/* Q28. */
SELECT store_id, month, monthly_revenue,
       SUM(monthly_revenue) OVER (PARTITION BY store_id ORDER BY month) AS cumulative_revenue
FROM (
    SELECT store_id, DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_revenue
    FROM sales.orders
    GROUP BY store_id, DATE_TRUNC('month', order_date)
) m
ORDER BY store_id, month;

/* Q29. */
SELECT expense_id, exp_cat_id, expense_date, amount,
       SUM(amount) OVER (PARTITION BY exp_cat_id ORDER BY expense_date, expense_id) AS running_total
FROM finance.expenses;

/* Q30. */
SELECT p.product_id, o.order_date, oi.quantity,
       SUM(oi.quantity) OVER (PARTITION BY p.product_id ORDER BY o.order_date, oi.order_item_id) AS cumulative_units_sold
FROM sales.order_items oi
JOIN sales.orders o ON oi.order_id = o.order_id
JOIN products.products p ON oi.prod_id = p.product_id;

/* Q31. */
SELECT customer_id, tier_id, join_date, points_balance,
       SUM(points_balance) OVER (PARTITION BY tier_id ORDER BY join_date, customer_id) AS tier_running_points
FROM loyalty.members;

/* Q32. */
SELECT r.region_id, t.reg_month, t.new_customers,
       SUM(t.new_customers) OVER (PARTITION BY r.region_id ORDER BY t.reg_month) AS cumulative_new_customers
FROM (
    SELECT a.state, DATE_TRUNC('month', c.registration_date) AS reg_month, COUNT(DISTINCT c.customer_id) AS new_customers
    FROM customers.customers c
    JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = true
    GROUP BY a.state, DATE_TRUNC('month', c.registration_date)
) t
JOIN core.dim_region r ON r.state = t.state
ORDER BY r.region_id, t.reg_month;

/* Q33. */
SELECT region_id, month, monthly_revenue,
       SUM(monthly_revenue) OVER (PARTITION BY region_id ORDER BY month) AS running_revenue
FROM (
    SELECT s.region_id, DATE_TRUNC('month', o.order_date) AS month, SUM(o.net_total) AS monthly_revenue
    FROM sales.orders o
    JOIN stores.stores s ON o.store_id = s.store_id
    GROUP BY s.region_id, DATE_TRUNC('month', o.order_date)
) t
ORDER BY region_id, month;

/* Q34. */
SELECT r.return_id, o.cust_id, r.return_date, r.refund_amount,
       SUM(r.refund_amount) OVER (PARTITION BY o.cust_id ORDER BY r.return_date, r.return_id) AS customer_running_refunds
FROM sales.returns r
JOIN sales.orders o ON r.order_id = o.order_id;

/* Q35. */
SELECT spend_id, platform, spend_date, amount,
       SUM(amount) OVER (PARTITION BY platform ORDER BY spend_date, spend_id) AS cumulative_spend
FROM marketing.ads_spend;

/* Q36. */
SELECT review_id, product_id, review_date,
       COUNT(*) OVER (PARTITION BY product_id ORDER BY review_date, review_id) AS running_review_count
FROM customers.reviews;

/* Q37. */
SELECT pay_slip_id, employee_id, payment_date, net_salary,
       SUM(net_salary) OVER (PARTITION BY employee_id ORDER BY payment_date, pay_slip_id) AS running_net_salary
FROM payroll.pay_slips;

/* Q38. */
SELECT order_id, cust_id, order_date,
       COUNT(*) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS purchase_number
FROM sales.orders;

/* Q39. */
SELECT pm.mode_name, t.month, t.monthly_revenue,
       SUM(t.monthly_revenue) OVER (PARTITION BY pm.mode_name ORDER BY t.month) AS running_revenue
FROM (
    SELECT payment_mode_id, DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_revenue
    FROM sales.orders
    GROUP BY payment_mode_id, DATE_TRUNC('month', order_date)
) t
JOIN finance.payment_modes pm ON pm.mode_id = t.payment_mode_id
ORDER BY pm.mode_name, t.month;

/* Q40. */
SELECT courier_name, week, weekly_shipments,
       SUM(weekly_shipments) OVER (PARTITION BY courier_name ORDER BY week) AS cumulative_shipments
FROM (
    SELECT courier_name, DATE_TRUNC('week', shipped_date) AS week, COUNT(*) AS weekly_shipments
    FROM sales.shipments
    GROUP BY courier_name, DATE_TRUNC('week', shipped_date)
) t
ORDER BY courier_name, week;

/* Q41. */
SELECT order_id, store_id, EXTRACT(YEAR FROM order_date) AS order_year, order_date, net_total,
       SUM(net_total) OVER (PARTITION BY store_id, EXTRACT(YEAR FROM order_date) ORDER BY order_date, order_id) AS running_total_ytd
FROM sales.orders;

/* Q42. */
SELECT agent_id, call_day, daily_minutes,
       SUM(daily_minutes) OVER (PARTITION BY agent_id ORDER BY call_day) AS cumulative_minutes
FROM (
    SELECT agent_id, call_start_time::date AS call_day, SUM(call_duration_seconds) / 60.0 AS daily_minutes
    FROM call_center.calls
    GROUP BY agent_id, call_start_time::date
) t
ORDER BY agent_id, call_day;

/* Q43. */
SELECT category_id, month, monthly_revenue,
       SUM(monthly_revenue) OVER (PARTITION BY category_id ORDER BY month) AS running_revenue
FROM (
    SELECT b.category_id, DATE_TRUNC('month', o.order_date) AS month, SUM(oi.net_amount) AS monthly_revenue
    FROM sales.order_items oi
    JOIN sales.orders o ON oi.order_id = o.order_id
    JOIN products.products p ON oi.prod_id = p.product_id
    JOIN core.dim_brand b ON p.brand_id = b.brand_id
    GROUP BY b.category_id, DATE_TRUNC('month', o.order_date)
) t
ORDER BY category_id, month;

/* Q44. */
SELECT cust_id, first_order_date,
       COUNT(*) OVER (PARTITION BY cust_id ORDER BY first_order_date) AS cumulative_distinct_products
FROM (
    SELECT o.cust_id, oi.prod_id, MIN(o.order_date) AS first_order_date
    FROM sales.order_items oi
    JOIN sales.orders o ON oi.order_id = o.order_id
    GROUP BY o.cust_id, oi.prod_id
) t
ORDER BY cust_id, first_order_date;

/* Q45. */
SELECT employee_id, dept_id, joining_date,
       COUNT(*) OVER (PARTITION BY dept_id ORDER BY joining_date, employee_id) AS running_headcount
FROM stores.employees
ORDER BY dept_id, joining_date;

/* Q46. */
SELECT cs.city, cs.month, cs.monthly_revenue,
       SUM(cs.monthly_revenue) OVER (PARTITION BY cs.city ORDER BY cs.month) AS cumulative_revenue
FROM (
    SELECT a.city, DATE_TRUNC('month', o.order_date) AS month, SUM(o.net_total) AS monthly_revenue
    FROM sales.orders o
    JOIN customers.addresses a ON a.customer_id = o.cust_id AND a.is_default = true
    GROUP BY a.city, DATE_TRUNC('month', o.order_date)
) cs
ORDER BY cs.city, cs.month;

/* Q47. */
SELECT order_id, order_item_id, net_amount,
       SUM(net_amount) OVER (PARTITION BY order_id ORDER BY order_item_id) AS running_total
FROM sales.order_items;

/* Q48. */
SELECT ticket_id, agent_id, created_date,
       COUNT(*) OVER (PARTITION BY agent_id ORDER BY created_date, ticket_id) AS cumulative_tickets
FROM support.tickets
ORDER BY agent_id, created_date;

/* Q49. */
SELECT brand_id, week, weekly_revenue,
       SUM(weekly_revenue) OVER (PARTITION BY brand_id ORDER BY week) AS running_revenue
FROM (
    SELECT p.brand_id, DATE_TRUNC('week', o.order_date) AS week, SUM(oi.net_amount) AS weekly_revenue
    FROM sales.order_items oi
    JOIN sales.orders o ON oi.order_id = o.order_id
    JOIN products.products p ON oi.prod_id = p.product_id
    GROUP BY p.brand_id, DATE_TRUNC('week', o.order_date)
) t
ORDER BY brand_id, week;

/* Q50. */
SELECT order_id, cust_id, order_date, net_total,
       SUM(net_total) OVER (PARTITION BY cust_id) AS customer_total,
       SUM(net_total) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS customer_running_total
FROM sales.orders;

/* ============================================================
   SECTION C: MOVING AVERAGES & FRAMES (25)
   ------------------------------------------------------------ */
/* Q51. */
SELECT order_date, daily_revenue,
       AVG(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7day
FROM (SELECT order_date, SUM(net_total) AS daily_revenue FROM sales.orders GROUP BY order_date) d
ORDER BY order_date;

/* Q52. */
SELECT order_date, daily_order_count,
       AVG(daily_order_count) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7day
FROM (SELECT order_date, COUNT(*) AS daily_order_count FROM sales.orders GROUP BY order_date) d
ORDER BY order_date;

/* Q53. */
SELECT store_id, month, monthly_revenue,
       AVG(monthly_revenue) OVER (PARTITION BY store_id ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS moving_avg_3mo
FROM (
    SELECT store_id, DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_revenue
    FROM sales.orders
    GROUP BY store_id, DATE_TRUNC('month', order_date)
) m
ORDER BY store_id, month;

/* Q54. */
SELECT order_id, cust_id, order_date, net_total,
       AVG(net_total) OVER (PARTITION BY cust_id ORDER BY order_date, order_id ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) AS trailing_5_order_avg
FROM sales.orders;

/* Q55. */
SELECT month, new_signups,
       AVG(new_signups) OVER (ORDER BY month ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING) AS centered_3mo_avg
FROM (SELECT DATE_TRUNC('month', registration_date) AS month, COUNT(*) AS new_signups FROM customers.customers GROUP BY 1) m
ORDER BY month;

/* Q56. */
SELECT region_id, week, weekly_revenue,
       AVG(weekly_revenue) OVER (PARTITION BY region_id ORDER BY week ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS moving_avg_4week
FROM (
    SELECT s.region_id, DATE_TRUNC('week', o.order_date) AS week, SUM(o.net_total) AS weekly_revenue
    FROM sales.orders o
    JOIN stores.stores s ON o.store_id = s.store_id
    GROUP BY s.region_id, DATE_TRUNC('week', o.order_date)
) t
ORDER BY region_id, week;

/* Q57. */
SELECT order_date, daily_revenue,
       SUM(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS trailing_30day_sum
FROM (SELECT order_date, SUM(net_total) AS daily_revenue FROM sales.orders GROUP BY order_date) d
ORDER BY order_date;

/* Q58. */
SELECT review_id, product_id, review_date, rating,
       AVG(rating) OVER (PARTITION BY product_id ORDER BY review_date, review_id ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) AS moving_avg_5review
FROM customers.reviews;

/* Q59. */
SELECT gs.d AS view_date, COALESCE(v.daily_views, 0) AS daily_views,
       AVG(COALESCE(v.daily_views, 0)) OVER (ORDER BY gs.d ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7day
FROM generate_series(
        (SELECT MIN(view_timestamp::date) FROM web_events.page_views),
        (SELECT MAX(view_timestamp::date) FROM web_events.page_views),
        INTERVAL '1 day'
     ) AS gs(d)
LEFT JOIN (SELECT view_timestamp::date AS view_date, COUNT(*) AS daily_views FROM web_events.page_views GROUP BY 1) v
  ON v.view_date = gs.d
ORDER BY gs.d;

/* Q60. */
SELECT exp_cat_id, month, monthly_amount,
       AVG(monthly_amount) OVER (PARTITION BY exp_cat_id ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS trailing_3mo_avg
FROM (
    SELECT exp_cat_id, DATE_TRUNC('month', expense_date) AS month, SUM(amount) AS monthly_amount
    FROM finance.expenses
    GROUP BY exp_cat_id, DATE_TRUNC('month', expense_date)
) t
ORDER BY exp_cat_id, month;

/* Q61. */
SELECT shipment_id, courier_name, shipped_date, (delivered_date - shipped_date) AS delivery_days,
       AVG(delivered_date - shipped_date) OVER (PARTITION BY courier_name ORDER BY shipped_date, shipment_id ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) AS moving_avg_10shipments
FROM sales.shipments;

/* Q62. */
SELECT order_id, cust_id, order_date, net_total,
       AVG(net_total) OVER (PARTITION BY cust_id ORDER BY order_date, order_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_avg_order_value
FROM sales.orders;

/* Q63. */
SELECT order_date, daily_revenue,
       AVG(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7day,
       daily_revenue - AVG(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS diff_from_ma
FROM (SELECT order_date, SUM(net_total) AS daily_revenue FROM sales.orders GROUP BY order_date) d
ORDER BY order_date;

/* Q64. */
SELECT prod_id, order_date, daily_units,
       SUM(daily_units) OVER (PARTITION BY prod_id ORDER BY order_date ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) AS moving_sum_5period
FROM (
    SELECT oi.prod_id, o.order_date, SUM(oi.quantity) AS daily_units
    FROM sales.order_items oi
    JOIN sales.orders o ON oi.order_id = o.order_id
    GROUP BY oi.prod_id, o.order_date
) t
ORDER BY prod_id, order_date;

/* Q65. */
SELECT employee_id, month, monthly_net_salary,
       AVG(monthly_net_salary) OVER (PARTITION BY employee_id ORDER BY month ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS trailing_6mo_avg
FROM (
    SELECT employee_id, DATE_TRUNC('month', payment_date) AS month, SUM(net_salary) AS monthly_net_salary
    FROM payroll.pay_slips
    GROUP BY employee_id, DATE_TRUNC('month', payment_date)
) t
ORDER BY employee_id, month;

/* Q66. */
SELECT call_id, agent_id, call_start_time, call_duration_seconds,
       AVG(call_duration_seconds) OVER (PARTITION BY agent_id ORDER BY call_start_time, call_id ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) AS moving_avg_20calls
FROM call_center.calls;

/* Q67. */
SELECT order_date, daily_revenue,
       AVG(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING) AS moving_avg_3row
FROM (SELECT order_date, SUM(net_total) AS daily_revenue FROM sales.orders GROUP BY order_date) d
ORDER BY order_date;

/* Q68. */
SELECT order_date, daily_revenue,
       SUM(daily_revenue) OVER (ORDER BY order_date RANGE BETWEEN INTERVAL '89 days' PRECEDING AND CURRENT ROW) AS rolling_90day_revenue
FROM (SELECT order_date, SUM(net_total) AS daily_revenue FROM sales.orders GROUP BY order_date) d
ORDER BY order_date;

/* Q69. */
SELECT review_id, customer_id, review_date, rating,
       AVG(rating) OVER (PARTITION BY customer_id ORDER BY review_date, review_id ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS trailing_3_avg_rating
FROM customers.reviews;

/* Q70. */
SELECT order_date, daily_revenue,
       AVG(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7day
FROM (SELECT order_date, SUM(net_total) AS daily_revenue FROM sales.orders GROUP BY order_date) d
ORDER BY order_date;

/* Q71. */
SELECT order_date, daily_revenue,
       AVG(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING) AS trailing_7_excl_current
FROM (SELECT order_date, SUM(net_total) AS daily_revenue FROM sales.orders GROUP BY order_date) d
ORDER BY order_date;

/* Q72. */
SELECT quarter, quarterly_revenue,
       AVG(quarterly_revenue) OVER (ORDER BY quarter ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS moving_avg_4q
FROM (SELECT DATE_TRUNC('quarter', order_date) AS quarter, SUM(net_total) AS quarterly_revenue FROM sales.orders GROUP BY 1) q
ORDER BY quarter;

/* Q73. */
SELECT oi.order_item_id, oi.prod_id, o.order_date,
       (oi.net_amount - p.cost_price * oi.quantity) AS margin,
       AVG(oi.net_amount - p.cost_price * oi.quantity) OVER (PARTITION BY oi.prod_id ORDER BY o.order_date, oi.order_item_id ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) AS trailing_10_avg_margin
FROM sales.order_items oi
JOIN sales.orders o ON oi.order_id = o.order_id
JOIN products.products p ON oi.prod_id = p.product_id;

/* Q74. */
SELECT d.order_date,
       (SELECT COUNT(DISTINCT o2.cust_id)
        FROM sales.orders o2
        WHERE o2.order_date BETWEEN d.order_date - INTERVAL '6 days' AND d.order_date) AS rolling_7day_distinct_customers
FROM (SELECT DISTINCT order_date FROM sales.orders) d
ORDER BY d.order_date;

/* Q75. */
SELECT order_date, daily_revenue,
       AVG(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS moving_avg_rows,
       AVG(daily_revenue) OVER (ORDER BY order_date RANGE BETWEEN INTERVAL '2 days' PRECEDING AND CURRENT ROW) AS moving_avg_range
FROM (SELECT order_date, SUM(net_total) AS daily_revenue FROM sales.orders GROUP BY order_date) d
ORDER BY order_date;

/* ============================================================
   SECTION D: SHARE-OF-TOTAL & RESET-AT-BOUNDARY (25)
   ------------------------------------------------------------ */
/* Q76. */
SELECT order_id, cust_id, net_total,
       ROUND(100.0 * net_total / SUM(net_total) OVER (PARTITION BY cust_id), 2) AS pct_of_customer_spend
FROM sales.orders;

/* Q77. */
SELECT p.product_id, p.brand_id, pu.units,
       ROUND(100.0 * pu.units / SUM(pu.units) OVER (PARTITION BY p.brand_id), 2) AS pct_of_brand_units
FROM products.products p
JOIN (SELECT prod_id, SUM(quantity) AS units FROM sales.order_items GROUP BY prod_id) pu
  ON pu.prod_id = p.product_id;

/* Q78. */
SELECT s.store_id, s.region_id, sr.total_revenue,
       ROUND(100.0 * sr.total_revenue / SUM(sr.total_revenue) OVER (PARTITION BY s.region_id), 2) AS pct_of_region
FROM stores.stores s
JOIN (SELECT store_id, SUM(net_total) AS total_revenue FROM sales.orders GROUP BY store_id) sr
  ON sr.store_id = s.store_id;

/* Q79. */
SELECT cat.category_name, cr.total_revenue,
       ROUND(100.0 * cr.total_revenue / SUM(cr.total_revenue) OVER (), 2) AS pct_of_grand_total
FROM (
    SELECT b.category_id, SUM(oi.net_amount) AS total_revenue
    FROM sales.order_items oi
    JOIN products.products p ON oi.prod_id = p.product_id
    JOIN core.dim_brand b ON p.brand_id = b.brand_id
    GROUP BY b.category_id
) cr
JOIN core.dim_category cat ON cat.category_id = cr.category_id;

/* Q80. */
SELECT employee_id, dept_id, salary,
       ROUND(100.0 * salary / SUM(salary) OVER (PARTITION BY dept_id), 2) AS pct_of_dept_payroll
FROM stores.employees;

/* Q81. */
SELECT order_id, EXTRACT(YEAR FROM order_date) AS order_year, order_date, net_total,
       SUM(net_total) OVER (PARTITION BY EXTRACT(YEAR FROM order_date) ORDER BY order_date, order_id) AS ytd_running_total
FROM sales.orders;

/* Q82. */
SELECT order_id, store_id, DATE_TRUNC('month', order_date) AS month, order_date, net_total,
       SUM(net_total) OVER (PARTITION BY store_id, DATE_TRUNC('month', order_date) ORDER BY order_date, order_id) AS mtd_running_total
FROM sales.orders;

/* Q83. */
SELECT year, month, monthly_revenue,
       ROUND(100.0 * monthly_revenue / SUM(monthly_revenue) OVER (PARTITION BY year), 2) AS pct_of_year
FROM (
    SELECT EXTRACT(YEAR FROM order_date) AS year, DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_revenue
    FROM sales.orders
    GROUP BY 1, 2
) m
ORDER BY year, month;

/* Q84. */
WITH cust_rev AS (
    SELECT cust_id, SUM(net_total) AS revenue FROM sales.orders GROUP BY cust_id
),
cum AS (
    SELECT cust_id, revenue,
           SUM(revenue) OVER (ORDER BY revenue DESC, cust_id) AS cum_revenue,
           SUM(revenue) OVER () AS total_revenue
    FROM cust_rev
)
SELECT cust_id, revenue, ROUND(100.0 * cum_revenue / total_revenue, 2) AS cumulative_pct
FROM cum
WHERE cum_revenue <= 0.2 * total_revenue
ORDER BY revenue DESC;

/* Q85. */
SELECT agent_id, category, resolved_count,
       ROUND(100.0 * resolved_count / SUM(resolved_count) OVER (PARTITION BY category), 2) AS pct_of_category
FROM (
    SELECT agent_id, category, COUNT(*) AS resolved_count
    FROM support.tickets
    WHERE status = 'Resolved'
    GROUP BY agent_id, category
) t;

/* Q86. */
SELECT p.product_id, p.brand_id, rc.review_count,
       ROUND(100.0 * rc.review_count / SUM(rc.review_count) OVER (PARTITION BY p.brand_id), 2) AS pct_of_brand_reviews
FROM products.products p
JOIN (SELECT product_id, COUNT(*) AS review_count FROM customers.reviews GROUP BY product_id) rc
  ON rc.product_id = p.product_id;

/* Q87. */
SELECT order_id, store_id, DATE_TRUNC('quarter', order_date) AS quarter, order_date, net_total,
       SUM(net_total) OVER (PARTITION BY store_id, DATE_TRUNC('quarter', order_date) ORDER BY order_date, order_id) AS qtd_running_total
FROM sales.orders;

/* Q88. */
SELECT campaign_id, platform, campaign_spend,
       ROUND(100.0 * campaign_spend / SUM(campaign_spend) OVER (PARTITION BY platform), 2) AS pct_of_platform
FROM (SELECT campaign_id, platform, SUM(amount) AS campaign_spend FROM marketing.ads_spend GROUP BY campaign_id, platform) t;

/* Q89. */
SELECT region_id, month, monthly_revenue,
       ROUND(100.0 * monthly_revenue / SUM(monthly_revenue) OVER (PARTITION BY month), 2) AS pct_of_month
FROM (
    SELECT s.region_id, DATE_TRUNC('month', o.order_date) AS month, SUM(o.net_total) AS monthly_revenue
    FROM sales.orders o
    JOIN stores.stores s ON o.store_id = s.store_id
    GROUP BY s.region_id, DATE_TRUNC('month', o.order_date)
) t
ORDER BY month, region_id;

/* Q90. */
WITH prod_units AS (
    SELECT b.category_id, p.product_id, SUM(oi.quantity) AS units
    FROM sales.order_items oi
    JOIN products.products p ON oi.prod_id = p.product_id
    JOIN core.dim_brand b ON p.brand_id = b.brand_id
    GROUP BY b.category_id, p.product_id
)
SELECT category_id, product_id, units,
       ROUND(100.0 * SUM(units) OVER (PARTITION BY category_id ORDER BY units DESC, product_id)
                    / SUM(units) OVER (PARTITION BY category_id), 2) AS cumulative_pct_units
FROM prod_units
ORDER BY category_id, units DESC;

/* Q91. */
SELECT cust_id, month, monthly_spend,
       ROUND(100.0 * monthly_spend / SUM(monthly_spend) OVER (PARTITION BY cust_id), 2) AS pct_of_lifetime_spend
FROM (SELECT cust_id, DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_spend FROM sales.orders GROUP BY cust_id, DATE_TRUNC('month', order_date)) t
ORDER BY cust_id, month;

/* Q92. */
SELECT employee_id, dept_id, joining_date,
       COUNT(*) OVER (PARTITION BY dept_id ORDER BY joining_date, employee_id) AS dept_running_headcount
FROM stores.employees
ORDER BY dept_id, joining_date;

/* Q93. */
SELECT order_item_id, order_id, net_amount,
       ROUND(100.0 * net_amount / SUM(net_amount) OVER (PARTITION BY order_id), 2) AS pct_of_order_total
FROM sales.order_items;

/* Q94. */
WITH city_spend AS (
    SELECT a.city, a.state, SUM(o.net_total) AS total_spend
    FROM sales.orders o
    JOIN customers.addresses a ON a.customer_id = o.cust_id AND a.is_default = true
    GROUP BY a.city, a.state
)
SELECT r.region_id, cs.city, cs.total_spend,
       ROUND(100.0 * cs.total_spend / SUM(cs.total_spend) OVER (PARTITION BY r.region_id), 2) AS pct_of_region
FROM city_spend cs
JOIN core.dim_region r ON r.state = cs.state
ORDER BY r.region_id, cs.city;

/* Q95. */
SELECT order_id, EXTRACT(YEAR FROM order_date) AS order_year, order_date, net_total,
       SUM(net_total) OVER (PARTITION BY EXTRACT(YEAR FROM order_date) ORDER BY order_date, order_id) AS ytd_running_total,
       ROUND(100.0 * SUM(net_total) OVER (PARTITION BY EXTRACT(YEAR FROM order_date) ORDER BY order_date, order_id)
                    / SUM(net_total) OVER (PARTITION BY EXTRACT(YEAR FROM order_date)), 2) AS pct_of_year
FROM sales.orders;

/* Q96. */
SELECT w.warehouse_id, w.region, snap.total_qty,
       ROUND(100.0 * snap.total_qty / SUM(snap.total_qty) OVER (PARTITION BY w.region), 2) AS pct_of_region_stock
FROM supply_chain.warehouses w
JOIN (SELECT warehouse_id, SUM(quantity_on_hand) AS total_qty FROM supply_chain.inventory_snapshots GROUP BY warehouse_id) snap
  ON snap.warehouse_id = w.warehouse_id;

/* Q97. */
SELECT tier_id, total_points,
       ROUND(100.0 * total_points / SUM(total_points) OVER (), 2) AS pct_of_all_points
FROM (SELECT tier_id, SUM(points_balance) AS total_points FROM loyalty.members GROUP BY tier_id) t;

/* Q98. */
SELECT iso_year, iso_week, day_date, daily_revenue,
       ROUND(100.0 * daily_revenue / SUM(daily_revenue) OVER (PARTITION BY iso_year, iso_week), 2) AS pct_of_week
FROM (
    SELECT EXTRACT(ISOYEAR FROM order_date) AS iso_year, EXTRACT(WEEK FROM order_date) AS iso_week,
           order_date AS day_date, SUM(net_total) AS daily_revenue
    FROM sales.orders
    GROUP BY EXTRACT(ISOYEAR FROM order_date), EXTRACT(WEEK FROM order_date), order_date
) t
ORDER BY iso_year, iso_week, day_date;

/* Q99. */
WITH cust_rev AS (
    SELECT cust_id, SUM(net_total) AS revenue FROM sales.orders GROUP BY cust_id
),
cum AS (
    SELECT cust_id, revenue,
           COUNT(*) OVER (ORDER BY revenue DESC, cust_id) AS cum_customer_count,
           COUNT(*) OVER () AS total_customers
    FROM cust_rev
)
SELECT cust_id, revenue
FROM cum
WHERE cum_customer_count <= 0.2 * total_customers
ORDER BY revenue DESC;

/* Q100. */
SELECT store_id, order_year, month, monthly_revenue,
       SUM(monthly_revenue) OVER (PARTITION BY store_id, order_year ORDER BY month) AS ytd_running_total,
       ROUND(100.0 * SUM(monthly_revenue) OVER (PARTITION BY store_id, order_year ORDER BY month)
                    / SUM(monthly_revenue) OVER (PARTITION BY store_id, order_year), 2) AS pct_of_year
FROM (
    SELECT store_id, EXTRACT(YEAR FROM order_date) AS order_year, DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_revenue
    FROM sales.orders
    GROUP BY store_id, EXTRACT(YEAR FROM order_date), DATE_TRUNC('month', order_date)
) t
ORDER BY store_id, order_year, month;

/* ============================================================
   END OF ANSWER KEY - Window Functions Part 2 - MEDIUM LEVEL (100/100)
============================================================ */
