/* ============================================================
   ANSWER KEY - Window Functions Part 3: LAG / LEAD (EASY LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1. LAG(x) returns the value of x from the row immediately before the current row, within the same partition, in the given order. */
/* Q2. LEAD(x) returns the value of x from the row immediately after the current row, within the same partition, in the given order. */
/* Q3. "Previous"/"next" only has meaning relative to a defined row order - without ORDER BY inside OVER(), there is no well-defined previous or next row to fetch. */
/* Q4. It returns the value from two rows back (offset 2) instead of the immediately preceding row. */
/* Q5. It returns the previous value, but substitutes the literal 0 (the third argument) instead of NULL when there is no previous row - i.e. on the first row of the partition. */
/* Q6. NULL - there is no row before the first row of a partition, so LAG returns NULL by default when no explicit default is given. */
/* Q7. Each partition is treated independently, so LAG/LEAD "reset" to NULL at the start/end of every partition instead of reaching into the next customer's or group's rows. */
/* Q8. (current_value - LAG(current_value) OVER (ORDER BY month)) / LAG(current_value) OVER (ORDER BY month) * 100. */
/* Q9. Because if the previous value is 0 (or the row doesn't exist), dividing by LAG(x) directly raises a divide-by-zero error; NULLIF(LAG(x), 0) turns that 0 into NULL first, so the division returns NULL instead of erroring. */
/* Q10. LAG/LEAD compute the previous/next row's value in a single windowed pass over the data; a self-join instead requires joining the table to itself on a shifted key, which is more verbose and typically slower. */
/* Q11. Comparing each period's metric (day, month, quarter) to the immediately preceding period of the same length, to see how the value has changed over time. */
/* Q12. order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date). */
/* Q13. No - like every window function, LAG/LEAD execute after WHERE is applied; the workaround is to compute LAG in a subquery/CTE and filter its result in an outer WHERE. */
/* Q14. LEAD(order_date, 1) OVER (...) minus the current row's order_date gives the number of days until the next event, directly from the current row. */
/* Q15. Without a deterministic ORDER BY, tied rows could be sequenced differently on different runs, making "the previous row" ambiguous and the LAG/LEAD result non-reproducible. */
/* Q16. The same data type as the column being shifted (e.g. numeric stays numeric, date stays date) - LAG never changes the underlying column type. */
/* Q17. Compare the current value to LAG(value) with <>, e.g. current_value <> LAG(value) OVER (...), typically filtered afterward in an outer query. */
/* Q18. current_value > LAG(value) OVER (...) evaluated (typically in an outer SELECT/WHERE, since window functions can't sit directly in WHERE). */
/* Q19. Because a GROUP BY over raw transaction data skips months with zero activity, so LAG would fetch the wrong "previous" month by skipping the true prior calendar month; a gap-filled monthly series avoids that. */
/* Q20. (value of the 2nd order) - LAG(value) OVER (...), read off the row that corresponds to a customer's 2nd order in their ordered sequence. */
/* Q21. NULL - there is no row after the last row of a partition, so LEAD returns NULL by default when no explicit default is given. */
/* Q22. current_value - LAG(current_value) OVER (ORDER BY ...), applied on every row to get the row-to-row change (delta) series. */
/* Q23. LAG looks at exactly one specific prior row (a single offset back); a window frame aggregate (e.g. AVG() OVER (ROWS BETWEEN N PRECEDING AND CURRENT ROW)) summarizes several prior rows at once. */
/* Q24. LAG(value, 12) OVER (ORDER BY month) on a monthly series, then (value - that lag value) / that lag value * 100, to compare against the same month one year earlier. */
/* Q25. LAG: comparing this month's revenue to last month's; LEAD: computing days until a customer's next purchase; period-over-period growth: reporting month-over-month revenue growth % to management. */

/* ============================================================
   SECTION B: LAG BASICS (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT order_id, cust_id, order_date, net_total,
       LAG(net_total) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS prev_order_net_total
FROM sales.orders;

/* Q27. */
SELECT order_id, cust_id, order_date,
       LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS prev_order_date
FROM sales.orders;

/* Q28. */
SELECT month, monthly_revenue,
       LAG(monthly_revenue) OVER (ORDER BY month) AS prev_month_revenue
FROM (SELECT DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_revenue FROM sales.orders GROUP BY 1) m
ORDER BY month;

/* Q29. */
SELECT product_id, price,
       LAG(price) OVER (ORDER BY price, product_id) AS prev_product_price
FROM products.products;

/* Q30. */
SELECT review_id, product_id, review_date, rating,
       LAG(rating) OVER (PARTITION BY product_id ORDER BY review_date, review_id) AS prev_review_rating
FROM customers.reviews;

/* Q31. */
SELECT call_id, agent_id, call_start_time, call_duration_seconds,
       LAG(call_duration_seconds) OVER (PARTITION BY agent_id ORDER BY call_start_time, call_id) AS prev_call_duration
FROM call_center.calls;

/* Q32. */
SELECT shipment_id, courier_name, shipped_date, (delivered_date - shipped_date) AS delivery_days,
       LAG(delivered_date - shipped_date) OVER (PARTITION BY courier_name ORDER BY shipped_date, shipment_id) AS prev_delivery_days
FROM sales.shipments;

/* Q33. */
SELECT pay_slip_id, employee_id, payment_date, net_salary,
       LAG(net_salary) OVER (PARTITION BY employee_id ORDER BY payment_date, pay_slip_id) AS prev_month_net_salary
FROM payroll.pay_slips;

/* Q34. */
SELECT order_id, store_id, order_date, net_total,
       LAG(net_total) OVER (PARTITION BY store_id ORDER BY order_date, order_id) AS prev_order_value
FROM sales.orders;

/* Q35. */
SELECT order_id, cust_id, order_date, net_total,
       LAG(net_total, 2) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS order_two_before
FROM sales.orders;

/* Q36. */
SELECT order_id, cust_id, order_date, net_total,
       LAG(net_total, 1, 0) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS prev_net_total_or_zero
FROM sales.orders;

/* Q37. */
SELECT month, new_signups,
       LAG(new_signups) OVER (ORDER BY month) AS prev_month_signups
FROM (SELECT DATE_TRUNC('month', registration_date) AS month, COUNT(*) AS new_signups FROM customers.customers GROUP BY 1) m
ORDER BY month;

/* Q38. */
SELECT warehouse_id, product_id, snapshot_date, quantity_on_hand,
       LAG(quantity_on_hand) OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date) AS prev_quantity
FROM supply_chain.inventory_snapshots;

/* Q39. */
SELECT order_id, cust_id, order_date,
       LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS previous_order_date
FROM sales.orders;

/* Q40. */
SELECT order_date, daily_revenue,
       LAG(daily_revenue) OVER (ORDER BY order_date) AS prev_day_revenue
FROM (SELECT order_date, SUM(net_total) AS daily_revenue FROM sales.orders GROUP BY order_date) d
ORDER BY order_date;

/* Q41. */
SELECT spend_id, campaign_id, spend_date, amount,
       LAG(amount) OVER (PARTITION BY campaign_id ORDER BY spend_date, spend_id) AS prev_spend_amount
FROM marketing.ads_spend;

/* Q42. */
SELECT ticket_id, agent_id, created_date,
       LAG(created_date) OVER (PARTITION BY agent_id ORDER BY created_date, ticket_id) AS prev_ticket_created_date
FROM support.tickets;

/* Q43. */
SELECT product_id, brand_id, price,
       LAG(price) OVER (PARTITION BY brand_id ORDER BY price DESC, product_id) AS next_cheaper_price
FROM products.products;

/* Q44. */
SELECT week, weekly_order_count,
       LAG(weekly_order_count) OVER (ORDER BY week) AS prev_week_order_count
FROM (SELECT DATE_TRUNC('week', order_date) AS week, COUNT(*) AS weekly_order_count FROM sales.orders GROUP BY 1) w
ORDER BY week;

/* Q45. */
SELECT loyalty_id, customer_id, date_earned, points_earned,
       LAG(points_earned) OVER (PARTITION BY customer_id ORDER BY date_earned, loyalty_id) AS prev_points_earned
FROM customers.loyalty_points;

/* Q46. */
SELECT order_id, cust_id, order_date, order_status,
       LAG(order_status) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS prior_order_status
FROM sales.orders;

/* Q47. */
SELECT quarter, quarterly_revenue,
       LAG(quarterly_revenue) OVER (ORDER BY quarter) AS prev_quarter_revenue
FROM (SELECT DATE_TRUNC('quarter', order_date) AS quarter, SUM(net_total) AS quarterly_revenue FROM sales.orders GROUP BY 1) q
ORDER BY quarter;

/* Q48. */
SELECT order_item_id, order_id, net_amount,
       LAG(net_amount) OVER (PARTITION BY order_id ORDER BY order_item_id) AS prev_line_net_amount
FROM sales.order_items;

/* Q49. */
SELECT exp_cat_id, month, monthly_amount,
       LAG(monthly_amount) OVER (PARTITION BY exp_cat_id ORDER BY month) AS prev_month_expenses
FROM (SELECT exp_cat_id, DATE_TRUNC('month', expense_date) AS month, SUM(amount) AS monthly_amount FROM finance.expenses GROUP BY exp_cat_id, DATE_TRUNC('month', expense_date)) t
ORDER BY exp_cat_id, month;

/* Q50. */
SELECT order_id, cust_id, order_date, net_total,
       LAG(net_total, 1) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS prev_1,
       LAG(net_total, 2) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS prev_2
FROM sales.orders;

/* ============================================================
   SECTION C: LEAD BASICS (25)
   ------------------------------------------------------------ */
/* Q51. */
SELECT order_id, cust_id, order_date, net_total,
       LEAD(net_total) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS next_order_net_total
FROM sales.orders;

/* Q52. */
SELECT order_id, cust_id, order_date,
       LEAD(order_date) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS next_order_date
FROM sales.orders;

/* Q53. */
SELECT order_id, cust_id, order_date,
       LEAD(order_date) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) - order_date AS days_until_next_order
FROM sales.orders;

/* Q54. */
SELECT review_id, product_id, review_date, rating,
       LEAD(rating) OVER (PARTITION BY product_id ORDER BY review_date, review_id) AS next_review_rating
FROM customers.reviews;

/* Q55. */
SELECT call_id, customer_id, call_start_time,
       LEAD(call_start_time) OVER (PARTITION BY customer_id ORDER BY call_start_time, call_id) - call_start_time AS time_until_next_call
FROM call_center.calls;

/* Q56. */
SELECT month, monthly_revenue,
       LEAD(monthly_revenue) OVER (ORDER BY month) AS next_month_revenue
FROM (SELECT DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_revenue FROM sales.orders GROUP BY 1) m
ORDER BY month;

/* Q57. */
SELECT product_id, price,
       LEAD(price) OVER (ORDER BY price, product_id) AS next_product_price
FROM products.products;

/* Q58. */
SELECT shipment_id, courier_name, shipped_date,
       LEAD(shipped_date) OVER (PARTITION BY courier_name ORDER BY shipped_date, shipment_id) AS next_shipment_shipped_date
FROM sales.shipments;

/* Q59. */
SELECT order_id, cust_id, order_date, net_total,
       LEAD(net_total, 2) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS order_two_after
FROM sales.orders;

/* Q60. */
SELECT order_id, cust_id, order_date, net_total,
       LEAD(net_total, 1, 0) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS next_net_total_or_zero
FROM sales.orders;

/* Q61. */
SELECT view_id, session_id, view_timestamp,
       LEAD(view_timestamp) OVER (PARTITION BY session_id ORDER BY view_timestamp, view_id) AS next_view_timestamp
FROM web_events.page_views;

/* Q62. */
SELECT pay_slip_id, employee_id, payment_date, net_salary,
       LEAD(net_salary) OVER (PARTITION BY employee_id ORDER BY payment_date, pay_slip_id) AS next_month_net_salary
FROM payroll.pay_slips;

/* Q63. */
SELECT ticket_id, agent_id, created_date,
       LEAD(created_date) OVER (PARTITION BY agent_id ORDER BY created_date, ticket_id) - created_date AS gap_to_next_ticket
FROM support.tickets;

/* Q64. */
SELECT warehouse_id, product_id, snapshot_date, quantity_on_hand,
       LEAD(quantity_on_hand) OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date) AS next_day_quantity
FROM supply_chain.inventory_snapshots;

/* Q65. */
SELECT order_id, cust_id, order_date AS first_order_date, second_order_date
FROM (
    SELECT order_id, cust_id, order_date,
           LEAD(order_date) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS second_order_date,
           MIN(order_date) OVER (PARTITION BY cust_id) AS first_order_date
    FROM sales.orders
) t
WHERE order_date = first_order_date
ORDER BY cust_id;

/* Q66. */
SELECT week, weekly_order_count,
       LEAD(weekly_order_count) OVER (ORDER BY week) AS next_week_order_count
FROM (SELECT DATE_TRUNC('week', order_date) AS week, COUNT(*) AS weekly_order_count FROM sales.orders GROUP BY 1) w
ORDER BY week;

/* Q67. */
SELECT order_id, store_id, order_date, net_total,
       LEAD(net_total) OVER (PARTITION BY store_id ORDER BY order_date, order_id) AS next_order_value
FROM sales.orders;

/* Q68. */
SELECT review_id, customer_id, review_date,
       LEAD(review_date) OVER (PARTITION BY customer_id ORDER BY review_date, review_id) - review_date AS gap_to_next_review
FROM customers.reviews;

/* Q69. */
SELECT spend_id, campaign_id, spend_date, amount,
       LEAD(amount) OVER (PARTITION BY campaign_id ORDER BY spend_date, spend_id) AS next_spend_amount,
       LEAD(spend_date) OVER (PARTITION BY campaign_id ORDER BY spend_date, spend_id) AS next_spend_date
FROM marketing.ads_spend;

/* Q70. */
SELECT quarter, quarterly_revenue,
       LEAD(quarterly_revenue) OVER (ORDER BY quarter) AS next_quarter_revenue
FROM (SELECT DATE_TRUNC('quarter', order_date) AS quarter, SUM(net_total) AS quarterly_revenue FROM sales.orders GROUP BY 1) q
ORDER BY quarter;

/* Q71. */
SELECT loyalty_id, customer_id, date_earned, points_earned,
       LEAD(points_earned) OVER (PARTITION BY customer_id ORDER BY date_earned, loyalty_id) AS next_points_earned
FROM customers.loyalty_points;

/* Q72. */
SELECT order_id, cust_id, order_date,
       LEAD(order_date) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) - order_date AS days_until_next_purchase
FROM sales.orders;

/* Q73. */
SELECT order_item_id, order_id, net_amount,
       LEAD(net_amount) OVER (PARTITION BY order_id ORDER BY order_item_id) AS next_line_net_amount
FROM sales.order_items;

/* Q74. */
SELECT order_date, daily_revenue,
       LEAD(daily_revenue) OVER (ORDER BY order_date) AS next_day_revenue
FROM (SELECT order_date, SUM(net_total) AS daily_revenue FROM sales.orders GROUP BY order_date) d
ORDER BY order_date;

/* Q75. */
SELECT order_id, cust_id, order_date, net_total,
       LEAD(net_total, 1) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS next_1,
       LEAD(net_total, 2) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS next_2
FROM sales.orders;

/* ============================================================
   SECTION D: DELTAS & PERIOD-OVER-PERIOD (25)
   ------------------------------------------------------------ */
/* Q76. */
SELECT month, monthly_revenue,
       LAG(monthly_revenue) OVER (ORDER BY month) AS prev_month_revenue,
       ROUND(100.0 * (monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY month)) / NULLIF(LAG(monthly_revenue) OVER (ORDER BY month), 0), 2) AS mom_growth_pct
FROM (SELECT DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_revenue FROM sales.orders GROUP BY 1) m
ORDER BY month;

/* Q77. */
SELECT order_date, daily_order_count,
       daily_order_count - LAG(daily_order_count) OVER (ORDER BY order_date) AS dod_change
FROM (SELECT order_date, COUNT(*) AS daily_order_count FROM sales.orders GROUP BY order_date) d
ORDER BY order_date;

/* Q78. */
SELECT order_id, cust_id, order_date,
       order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS gap_days
FROM sales.orders;

/* Q79. */
SELECT order_id, cust_id, order_date AS first_order_date, delta_to_second_order
FROM (
    SELECT order_id, cust_id, order_date, net_total,
           LEAD(net_total) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) - net_total AS delta_to_second_order,
           MIN(order_date) OVER (PARTITION BY cust_id) AS first_order_date
    FROM sales.orders
) t
WHERE order_date = first_order_date
ORDER BY cust_id;

/* Q80. */
SELECT product_id, price,
       LAG(price) OVER (ORDER BY product_id) AS prev_price,
       (price <> LAG(price) OVER (ORDER BY product_id)) AS price_changed_flag
FROM products.products
ORDER BY product_id;

/* Q81. */
SELECT order_date, daily_revenue,
       LAG(daily_revenue) OVER (ORDER BY order_date) AS prev_day_revenue,
       (daily_revenue > 1.2 * LAG(daily_revenue) OVER (ORDER BY order_date)) AS is_up_over_20pct
FROM (SELECT order_date, SUM(net_total) AS daily_revenue FROM sales.orders GROUP BY order_date) d
ORDER BY order_date;

/* Q82. */
SELECT store_id, week, weekly_orders,
       ROUND(100.0 * (weekly_orders - LAG(weekly_orders) OVER (PARTITION BY store_id ORDER BY week)) / NULLIF(LAG(weekly_orders) OVER (PARTITION BY store_id ORDER BY week), 0), 2) AS wow_growth_pct
FROM (SELECT store_id, DATE_TRUNC('week', order_date) AS week, COUNT(*) AS weekly_orders FROM sales.orders GROUP BY store_id, DATE_TRUNC('week', order_date)) t
ORDER BY store_id, week;

/* Q83. */
SELECT region_id, quarter, quarterly_revenue,
       quarterly_revenue - LAG(quarterly_revenue) OVER (PARTITION BY region_id ORDER BY quarter) AS qoq_change
FROM (SELECT s.region_id, DATE_TRUNC('quarter', o.order_date) AS quarter, SUM(o.net_total) AS quarterly_revenue FROM sales.orders o JOIN stores.stores s ON o.store_id = s.store_id GROUP BY s.region_id, DATE_TRUNC('quarter', o.order_date)) t
ORDER BY region_id, quarter;

/* Q84. */
SELECT pay_slip_id, employee_id, payment_date, net_salary,
       net_salary - LAG(net_salary) OVER (PARTITION BY employee_id ORDER BY payment_date, pay_slip_id) AS change_vs_prev_month
FROM payroll.pay_slips;

/* Q85. */
SELECT loyalty_id, customer_id, date_earned, points_earned,
       points_earned - LAG(points_earned) OVER (PARTITION BY customer_id ORDER BY date_earned, loyalty_id) AS delta_vs_prev
FROM customers.loyalty_points;

/* Q86. */
SELECT month, new_signups,
       ROUND(100.0 * (new_signups - LAG(new_signups) OVER (ORDER BY month)) / NULLIF(LAG(new_signups) OVER (ORDER BY month), 0), 2) AS mom_growth_pct
FROM (SELECT DATE_TRUNC('month', registration_date) AS month, COUNT(*) AS new_signups FROM customers.customers GROUP BY 1) m
ORDER BY month;

/* Q87. */
SELECT shipment_id, courier_name, shipped_date, (delivered_date - shipped_date) AS delivery_days,
       (delivered_date - shipped_date) - LAG(delivered_date - shipped_date) OVER (PARTITION BY courier_name ORDER BY shipped_date, shipment_id) AS diff_vs_prev_shipment
FROM sales.shipments;

/* Q88. */
SELECT session_id, view_id, view_timestamp,
       MAX(view_timestamp) OVER (PARTITION BY session_id) - MIN(view_timestamp) OVER (PARTITION BY session_id) AS session_duration
FROM web_events.page_views;

/* Q89. */
SELECT month, monthly_revenue,
       LAG(monthly_revenue, 12) OVER (ORDER BY month) AS same_month_last_year_revenue
FROM (SELECT DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_revenue FROM sales.orders GROUP BY 1) m
ORDER BY month;

/* Q90. */
SELECT review_id, product_id, review_date, rating,
       LAG(rating) OVER (PARTITION BY product_id ORDER BY review_date, review_id) AS prev_rating,
       (rating < LAG(rating) OVER (PARTITION BY product_id ORDER BY review_date, review_id)) AS is_rating_drop
FROM customers.reviews;

/* Q91. */
SELECT warehouse_id, product_id, snapshot_date, quantity_on_hand,
       LAG(quantity_on_hand) OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date) AS prev_quantity,
       (quantity_on_hand = 0 AND LAG(quantity_on_hand) OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date) > 0) AS is_stockout_event
FROM supply_chain.inventory_snapshots;

/* Q92. */
SELECT order_id, cust_id, order_date, net_total,
       net_total - LAG(net_total) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS abs_delta,
       ROUND(100.0 * (net_total - LAG(net_total) OVER (PARTITION BY cust_id ORDER BY order_date, order_id)) / NULLIF(LAG(net_total) OVER (PARTITION BY cust_id ORDER BY order_date, order_id), 0), 2) AS pct_delta
FROM sales.orders;

/* Q93. */
SELECT exp_cat_id, month, monthly_amount,
       ROUND(100.0 * (monthly_amount - LAG(monthly_amount) OVER (PARTITION BY exp_cat_id ORDER BY month)) / NULLIF(LAG(monthly_amount) OVER (PARTITION BY exp_cat_id ORDER BY month), 0), 2) AS mom_change_pct
FROM (SELECT exp_cat_id, DATE_TRUNC('month', expense_date) AS month, SUM(amount) AS monthly_amount FROM finance.expenses GROUP BY exp_cat_id, DATE_TRUNC('month', expense_date)) t
ORDER BY exp_cat_id, month;

/* Q94. */
SELECT order_id, cust_id, order_date AS first_order_date, days_to_second_order
FROM (
    SELECT order_id, cust_id, order_date,
           LEAD(order_date) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) - order_date AS days_to_second_order,
           MIN(order_date) OVER (PARTITION BY cust_id) AS first_order_date
    FROM sales.orders
) t
WHERE order_date = first_order_date
ORDER BY cust_id;

/* Q95. */
SELECT month, monthly_revenue,
       ROUND(100.0 * (monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY month)) / NULLIF(LAG(monthly_revenue) OVER (ORDER BY month), 0), 2) AS mom_growth_pct,
       (monthly_revenue < LAG(monthly_revenue) OVER (ORDER BY month)) AS is_negative_growth
FROM (SELECT DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_revenue FROM sales.orders GROUP BY 1) m
ORDER BY month;

/* Q96. */
SELECT order_date, daily_revenue,
       (daily_revenue > LAG(daily_revenue) OVER (ORDER BY order_date)) AS beat_previous_day
FROM (SELECT order_date, SUM(net_total) AS daily_revenue FROM sales.orders GROUP BY order_date) d
ORDER BY order_date;

/* Q97. */
SELECT product_id, price,
       LAG(price) OVER (ORDER BY product_id) AS prev_price,
       (price > 1.5 * LAG(price) OVER (ORDER BY product_id)) AS is_price_jump_over_50pct
FROM products.products
ORDER BY product_id;

/* Q98. */
SELECT cust_id, MAX(gap_days) AS longest_gap_days
FROM (
    SELECT cust_id, order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS gap_days
    FROM sales.orders
) t
GROUP BY cust_id
ORDER BY longest_gap_days DESC NULLS LAST;

/* Q99. */
SELECT category_id, month, monthly_revenue,
       LAG(monthly_revenue) OVER (PARTITION BY category_id ORDER BY month) AS prev_month_revenue,
       ROUND(100.0 * (monthly_revenue - LAG(monthly_revenue) OVER (PARTITION BY category_id ORDER BY month)) / NULLIF(LAG(monthly_revenue) OVER (PARTITION BY category_id ORDER BY month), 0), 2) AS mom_change_pct
FROM (
    SELECT b.category_id, DATE_TRUNC('month', o.order_date) AS month, SUM(oi.net_amount) AS monthly_revenue
    FROM sales.order_items oi
    JOIN sales.orders o ON oi.order_id = o.order_id
    JOIN products.products p ON oi.prod_id = p.product_id
    JOIN core.dim_brand b ON p.brand_id = b.brand_id
    GROUP BY b.category_id, DATE_TRUNC('month', o.order_date)
) t
ORDER BY category_id, month;

/* Q100. */
SELECT store_id, month, monthly_revenue,
       LAG(monthly_revenue) OVER (PARTITION BY store_id ORDER BY month) AS prev_revenue,
       ROUND(100.0 * (monthly_revenue - LAG(monthly_revenue) OVER (PARTITION BY store_id ORDER BY month)) / NULLIF(LAG(monthly_revenue) OVER (PARTITION BY store_id ORDER BY month), 0), 2) AS growth_pct,
       CASE WHEN monthly_revenue > LAG(monthly_revenue) OVER (PARTITION BY store_id ORDER BY month) THEN 'UP'
            WHEN monthly_revenue < LAG(monthly_revenue) OVER (PARTITION BY store_id ORDER BY month) THEN 'DOWN'
            ELSE 'FLAT' END AS trend_flag
FROM (SELECT store_id, DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_revenue FROM sales.orders GROUP BY store_id, DATE_TRUNC('month', order_date)) m
ORDER BY store_id, month;

/* ============================================================
   END OF ANSWER KEY - Window Functions Part 3 - EASY LEVEL (100/100)
============================================================ */
