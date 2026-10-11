/* ============================================================
   ANSWER KEY - Window Functions Part 2: Aggregation & Frames (EASY LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1. SUM(x) OVER () computes the total across all rows while keeping every detail row, unlike GROUP BY which collapses rows into one row per group. */
/* Q2. It returns the sum of x across all rows sharing that row's partition value g, repeated on every row of the partition. */
/* Q3. Adding ORDER BY switches the default frame to "start of partition through current row", turning the sum into a running/cumulative total. */
/* Q4. RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW. */
/* Q5. RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING - the whole partition. */
/* Q6. A running total is a cumulative sum of values, in a given order, up to and including the current row. */
/* Q7. value / SUM(value) OVER () computed on every row. */
/* Q8. value / SUM(value) OVER (PARTITION BY g) computed on every row. */
/* Q9. It repeats g's group average on every row belonging to g, alongside that row's own individual values. */
/* Q10. Because you keep every original detail row while still seeing the group aggregate beside it, useful for ratios/flags without a second query or self-join. */
/* Q11. The number of rows in that row's partition, repeated on every row of the partition. */
/* Q12. It sums from the first row of the ordered partition through the current row - a running total. */
/* Q13. It sums only the current row plus the 6 rows immediately before it - a trailing 7-row window. */
/* Q14. ROWS counts physical rows by position; RANGE groups by logical ORDER BY value and can pull tied peer rows into the same frame step. */
/* Q15. Without a deterministic ORDER BY, ties can be ordered differently on each run, making the running total non-reproducible. */
/* Q16. No, not directly - a bare window aggregate and a GROUP BY aggregate operate at different stages; windows apply after GROUP BY, so you'd need every non-aggregated column grouped first. */
/* Q17. A moving (rolling) average recomputes the average over a fixed-size sliding window of the most recent N rows as you move down the ordered series. */
/* Q18. SUM() OVER() computes the group total directly on the same row set in one pass, instead of a self-join that separately re-aggregates and joins the group back. */
/* Q19. It repeats the maximum x within g on every row of that partition. */
/* Q20. A rank positions a row within its group (1st, 2nd, ...); "share of total" instead expresses the row's value as a fraction/percentage of a group's or grand sum. */
/* Q21. Ties in the ORDER BY column, under RANGE framing, pull all tied rows into the same frame step at once, so a "running" total can jump by more than one row's worth. */
/* Q22. A cumulative count that grows as rows are processed in order, built with COUNT(*) OVER (ORDER BY ... ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW). */
/* Q23. When you want a calendar-month grouping key applied inside a window (running totals or % of total per month) without a separate GROUP BY query. */
/* Q24. No - window functions run after WHERE is applied, so they can't be referenced there; the workaround is to compute the window in a subquery/CTE and filter on it in the outer WHERE. */
/* Q25. Running total: cumulative revenue on a finance dashboard; moving average: smoothing daily sales for a trend chart; % of total: each product's share of category revenue. */

/* ============================================================
   SECTION B: AGGREGATE OVER (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT order_id, cust_id, net_total,
       SUM(net_total) OVER () AS grand_total_net
FROM sales.orders;

/* Q27. */
SELECT order_id, cust_id, net_total,
       SUM(net_total) OVER (PARTITION BY cust_id) AS customer_total_spend
FROM sales.orders;

/* Q28. */
SELECT product_id, product_name, brand_id, price,
       AVG(price) OVER (PARTITION BY brand_id) AS brand_avg_price
FROM products.products;

/* Q29. */
SELECT employee_id, first_name, last_name, dept_id, salary,
       AVG(salary) OVER (PARTITION BY dept_id) AS dept_avg_salary
FROM stores.employees;

/* Q30. */
SELECT order_id, store_id,
       COUNT(*) OVER (PARTITION BY store_id) AS store_order_count
FROM sales.orders;

/* Q31. */
SELECT product_id, brand_id, price,
       MAX(price) OVER (PARTITION BY brand_id) AS brand_max_price
FROM products.products;

/* Q32. */
SELECT review_id, product_id, rating,
       AVG(rating) OVER (PARTITION BY product_id) AS product_avg_rating
FROM customers.reviews;

/* Q33. */
SELECT order_id, store_id, net_total,
       SUM(net_total) OVER (PARTITION BY store_id) AS store_total_revenue
FROM sales.orders;

/* Q34. */
SELECT employee_id, store_id, salary,
       MIN(salary) OVER (PARTITION BY store_id) AS store_min_salary,
       MAX(salary) OVER (PARTITION BY store_id) AS store_max_salary
FROM stores.employees;

/* Q35. */
SELECT order_item_id, order_id, net_amount,
       SUM(net_amount) OVER (PARTITION BY order_id) AS order_total_net_amount
FROM sales.order_items;

/* Q36. */
SELECT order_id, cust_id, order_date,
       COUNT(*) OVER (PARTITION BY cust_id) AS customer_order_count
FROM sales.orders;

/* Q37. */
SELECT p.product_id, p.product_name, b.category_id, p.price,
       AVG(p.price) OVER (PARTITION BY b.category_id) AS category_avg_price
FROM products.products p
JOIN core.dim_brand b ON p.brand_id = b.brand_id;

/* Q38. */
SELECT ticket_id, agent_id,
       COUNT(*) OVER (PARTITION BY agent_id) AS agent_ticket_count
FROM support.tickets;

/* Q39. */
SELECT call_id, agent_id, call_duration_seconds,
       AVG(call_duration_seconds) OVER (PARTITION BY agent_id) AS agent_avg_duration
FROM call_center.calls;

/* Q40. */
SELECT pay_slip_id, employee_id, net_salary,
       AVG(net_salary) OVER () AS company_avg_net_salary
FROM payroll.pay_slips;

/* Q41. */
SELECT shipment_id, courier_name, (delivered_date - shipped_date) AS delivery_days,
       AVG(delivered_date - shipped_date) OVER (PARTITION BY courier_name) AS courier_avg_delivery_days
FROM sales.shipments;

/* Q42. */
SELECT spend_id, platform, amount,
       SUM(amount) OVER (PARTITION BY platform) AS platform_total_spend
FROM marketing.ads_spend;

/* Q43. */
SELECT store_id, region_id, square_ft,
       SUM(square_ft) OVER (PARTITION BY region_id) AS region_total_square_ft
FROM stores.stores;

/* Q44. */
SELECT order_id, cust_id, net_total,
       AVG(net_total) OVER (PARTITION BY cust_id) AS customer_avg_order_value
FROM sales.orders;

/* Q45. */
SELECT product_id, supplier_id,
       COUNT(*) OVER (PARTITION BY supplier_id) AS supplier_product_count
FROM products.products;

/* Q46. */
SELECT customer_id, tier_id, points_balance,
       AVG(points_balance) OVER (PARTITION BY tier_id) AS tier_avg_points_balance
FROM loyalty.members;

/* Q47. */
SELECT order_id, store_id, net_total,
       SUM(net_total) OVER (PARTITION BY store_id) AS store_total,
       SUM(net_total) OVER () AS grand_total
FROM sales.orders;

/* Q48. */
SELECT review_id, customer_id,
       COUNT(*) OVER (PARTITION BY customer_id) AS customer_review_count
FROM customers.reviews;

/* Q49. */
SELECT employee_id, first_name, last_name,
       COUNT(*) OVER () AS company_headcount
FROM stores.employees;

/* Q50. */
SELECT product_id, brand_id, price,
       AVG(price) OVER (PARTITION BY brand_id) AS brand_avg_price,
       AVG(price) OVER () AS overall_avg_price
FROM products.products;

/* ============================================================
   SECTION C: RUNNING TOTALS & % OF TOTAL (25)
   ------------------------------------------------------------ */
/* Q51. */
SELECT order_id, order_date, net_total,
       SUM(net_total) OVER (ORDER BY order_date, order_id) AS running_total
FROM sales.orders;

/* Q52. */
SELECT order_id, cust_id, order_date, net_total,
       SUM(net_total) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS customer_running_total
FROM sales.orders;

/* Q53. */
SELECT order_id, store_id, order_date,
       COUNT(*) OVER (PARTITION BY store_id ORDER BY order_date, order_id) AS store_running_count
FROM sales.orders;

/* Q54. */
SELECT order_id, net_total,
       ROUND(100.0 * net_total / SUM(net_total) OVER (), 4) AS pct_of_grand_total
FROM sales.orders;

/* Q55. */
SELECT order_id, cust_id, net_total,
       ROUND(100.0 * net_total / SUM(net_total) OVER (PARTITION BY cust_id), 2) AS pct_of_customer_spend
FROM sales.orders;

/* Q56. */
SELECT product_id, brand_id, price,
       ROUND(100.0 * price / SUM(price) OVER (PARTITION BY brand_id), 2) AS pct_of_brand_catalog_price
FROM products.products;

/* Q57. */
SELECT month, monthly_revenue,
       SUM(monthly_revenue) OVER (ORDER BY month) AS cumulative_revenue
FROM (
    SELECT DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_revenue
    FROM sales.orders
    GROUP BY 1
) m
ORDER BY month;

/* Q58. */
SELECT expense_id, exp_cat_id, expense_date, amount,
       SUM(amount) OVER (PARTITION BY exp_cat_id ORDER BY expense_date, expense_id) AS running_total_by_category
FROM finance.expenses;

/* Q59. */
SELECT employee_id, dept_id, salary,
       ROUND(100.0 * salary / SUM(salary) OVER (PARTITION BY dept_id), 2) AS pct_of_dept_payroll
FROM stores.employees;

/* Q60. */
SELECT customer_id, tier_id, join_date, points_balance,
       SUM(points_balance) OVER (PARTITION BY tier_id ORDER BY join_date, customer_id) AS tier_running_points
FROM loyalty.members;

/* Q61. */
SELECT s.store_id, s.region_id, sr.total_revenue,
       ROUND(100.0 * sr.total_revenue / SUM(sr.total_revenue) OVER (PARTITION BY s.region_id), 2) AS pct_of_region
FROM stores.stores s
JOIN (SELECT store_id, SUM(net_total) AS total_revenue FROM sales.orders GROUP BY store_id) sr
  ON sr.store_id = s.store_id;

/* Q62. */
SELECT order_id, cust_id, order_date,
       COUNT(*) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS purchase_number
FROM sales.orders;

/* Q63. */
SELECT review_id, product_id, review_date, rating,
       SUM(rating) OVER (PARTITION BY product_id ORDER BY review_date, review_id) AS running_rating_sum
FROM customers.reviews;

/* Q64. */
SELECT spend_id, campaign_id, spend_date, amount,
       SUM(amount) OVER (PARTITION BY campaign_id ORDER BY spend_date, spend_id) AS campaign_running_spend
FROM marketing.ads_spend;

/* Q65. */
SELECT order_item_id, order_id, net_amount,
       ROUND(100.0 * net_amount / SUM(net_amount) OVER (PARTITION BY order_id), 2) AS pct_of_order_total
FROM sales.order_items;

/* Q66. */
SELECT week, weekly_revenue,
       SUM(weekly_revenue) OVER (ORDER BY week) AS cumulative_revenue
FROM (
    SELECT DATE_TRUNC('week', order_date) AS week, SUM(net_total) AS weekly_revenue
    FROM sales.orders
    GROUP BY 1
) w
ORDER BY week;

/* Q67. */
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

/* Q68. */
SELECT pay_slip_id, employee_id, payment_date, net_salary,
       SUM(net_salary) OVER (PARTITION BY employee_id ORDER BY payment_date, pay_slip_id) AS running_net_salary
FROM payroll.pay_slips;

/* Q69. */
SELECT p.product_id, p.brand_id, pu.units,
       ROUND(100.0 * pu.units / SUM(pu.units) OVER (PARTITION BY p.brand_id), 2) AS pct_of_brand_units
FROM products.products p
JOIN (SELECT prod_id, SUM(quantity) AS units FROM sales.order_items GROUP BY prod_id) pu
  ON pu.prod_id = p.product_id;

/* Q70. */
SELECT reg_month, new_customers,
       SUM(new_customers) OVER (ORDER BY reg_month) AS cumulative_customers
FROM (
    SELECT DATE_TRUNC('month', registration_date) AS reg_month, COUNT(*) AS new_customers
    FROM customers.customers
    GROUP BY 1
) m
ORDER BY reg_month;

/* Q71. */
SELECT r.return_id, o.cust_id, r.return_date, r.refund_amount,
       SUM(r.refund_amount) OVER (PARTITION BY o.cust_id ORDER BY r.return_date, r.return_id) AS customer_running_refunds
FROM sales.returns r
JOIN sales.orders o ON r.order_id = o.order_id;

/* Q72. */
SELECT region_id, store_count,
       ROUND(100.0 * store_count / SUM(store_count) OVER (), 2) AS pct_of_all_stores
FROM (SELECT region_id, COUNT(*) AS store_count FROM stores.stores GROUP BY region_id) t;

/* Q73. */
SELECT store_id, order_date, net_total,
       SUM(net_total) OVER (PARTITION BY store_id ORDER BY order_date, order_id) AS store_running_total,
       MIN(order_date) OVER (PARTITION BY store_id) AS store_first_order_date,
       MAX(order_date) OVER (PARTITION BY store_id) AS store_last_order_date
FROM sales.orders;

/* Q74. */
SELECT call_id, agent_id, call_duration_seconds,
       ROUND(100.0 * call_duration_seconds / SUM(call_duration_seconds) OVER (PARTITION BY agent_id), 2) AS pct_of_agent_talk_time
FROM call_center.calls;

/* Q75. */
SELECT cust_id, customer_revenue,
       SUM(customer_revenue) OVER (ORDER BY customer_revenue DESC, cust_id) AS cumulative_revenue,
       ROUND(100.0 * SUM(customer_revenue) OVER (ORDER BY customer_revenue DESC, cust_id) / SUM(customer_revenue) OVER (), 2) AS cumulative_pct
FROM (SELECT cust_id, SUM(net_total) AS customer_revenue FROM sales.orders GROUP BY cust_id) c
ORDER BY customer_revenue DESC;

/* ============================================================
   SECTION D: FRAME BASICS (ROWS BETWEEN) (25)
   ------------------------------------------------------------ */
/* Q76. */
SELECT order_date, daily_revenue,
       AVG(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING) AS moving_avg_3
FROM (SELECT order_date, SUM(net_total) AS daily_revenue FROM sales.orders GROUP BY order_date) d
ORDER BY order_date;

/* Q77. */
SELECT order_date, daily_order_count,
       AVG(daily_order_count) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7day
FROM (SELECT order_date, COUNT(*) AS daily_order_count FROM sales.orders GROUP BY order_date) d
ORDER BY order_date;

/* Q78. */
SELECT order_id, cust_id, order_date, net_total,
       AVG(net_total) OVER (PARTITION BY cust_id ORDER BY order_date, order_id ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS trailing_3_order_avg
FROM sales.orders;

/* Q79. */
SELECT order_id, cust_id, order_date, net_total,
       MAX(net_total) OVER (PARTITION BY cust_id ORDER BY order_date, order_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_max_net_total
FROM sales.orders;

/* Q80. */
SELECT product_id, brand_id, price,
       MIN(price) OVER (PARTITION BY brand_id ORDER BY product_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_min_price
FROM products.products;

/* Q81. */
SELECT order_id, cust_id, order_date, net_total,
       SUM(net_total) OVER (PARTITION BY cust_id ORDER BY order_date, order_id ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) AS moving_sum_last5
FROM sales.orders;

/* Q82. */
SELECT month, monthly_revenue,
       AVG(monthly_revenue) OVER (ORDER BY month ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING) AS centered_3mo_avg
FROM (SELECT DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_revenue FROM sales.orders GROUP BY 1) m
ORDER BY month;

/* Q83. */
SELECT order_date, daily_revenue,
       SUM(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS trailing_7day_sum
FROM (SELECT order_date, SUM(net_total) AS daily_revenue FROM sales.orders GROUP BY order_date) d
ORDER BY order_date;

/* Q84. */
SELECT order_date, daily_revenue,
       AVG(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING) AS moving_avg_3,
       daily_revenue - AVG(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING) AS diff_from_moving_avg
FROM (SELECT order_date, SUM(net_total) AS daily_revenue FROM sales.orders GROUP BY order_date) d
ORDER BY order_date;

/* Q85. */
SELECT review_id, product_id, review_date, rating,
       AVG(rating) OVER (PARTITION BY product_id ORDER BY review_date, review_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_avg_rating
FROM customers.reviews;

/* Q86. */
SELECT call_id, agent_id, call_start_time, call_duration_seconds,
       AVG(call_duration_seconds) OVER (PARTITION BY agent_id ORDER BY call_start_time, call_id ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS last3_avg_duration
FROM call_center.calls;

/* Q87. */
SELECT customer_id, join_date, points_balance,
       MAX(points_balance) OVER (ORDER BY join_date, customer_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_max_points_balance
FROM loyalty.members
ORDER BY join_date;

/* Q88. */
SELECT week, new_signups,
       AVG(new_signups) OVER (ORDER BY week ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS moving_avg_4week
FROM (SELECT DATE_TRUNC('week', registration_date) AS week, COUNT(*) AS new_signups FROM customers.customers GROUP BY 1) w
ORDER BY week;

/* Q89. */
SELECT expense_id, exp_cat_id, expense_date, amount,
       SUM(amount) OVER (PARTITION BY exp_cat_id ORDER BY expense_date, expense_id ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS trailing_30row_sum
FROM finance.expenses;

/* Q90. */
SELECT order_id, order_date, net_total,
       AVG(net_total) OVER (ORDER BY order_date, order_id ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING) AS moving_avg_5row
FROM sales.orders;

/* Q91. */
SELECT order_id, order_date, net_total,
       SUM(net_total) OVER (ORDER BY order_date, order_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total_explicit
FROM sales.orders;

/* Q92. */
SELECT order_id, order_date, net_total,
       SUM(net_total) OVER (ORDER BY order_date, order_id) AS default_frame_total,
       SUM(net_total) OVER (ORDER BY order_date, order_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS explicit_rows_total
FROM sales.orders;

/* Q93. */
SELECT store_id, month, monthly_revenue,
       AVG(monthly_revenue) OVER (PARTITION BY store_id ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS moving_avg_3mo
FROM (
    SELECT store_id, DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_revenue
    FROM sales.orders
    GROUP BY store_id, DATE_TRUNC('month', order_date)
) m
ORDER BY store_id, month;

/* Q94. */
SELECT shipment_id, courier_name, shipped_date, (delivered_date - shipped_date) AS delivery_days,
       AVG(delivered_date - shipped_date) OVER (PARTITION BY courier_name ORDER BY shipped_date, shipment_id ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) AS trailing10_avg_delivery_days
FROM sales.shipments;

/* Q95. */
SELECT view_date, daily_views,
       AVG(daily_views) OVER (ORDER BY view_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7day
FROM (SELECT view_timestamp::date AS view_date, COUNT(*) AS daily_views FROM web_events.page_views GROUP BY 1) v
ORDER BY view_date;

/* Q96. */
SELECT order_id, cust_id, order_date, net_total,
       SUM(net_total) OVER (PARTITION BY cust_id ORDER BY order_date, order_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS customer_running_sum
FROM sales.orders;

/* Q97. */
SELECT review_id, product_id, review_date, rating,
       AVG(rating) OVER (PARTITION BY product_id ORDER BY review_date, review_id ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) AS moving_avg_5review
FROM customers.reviews;

/* Q98. */
SELECT month, monthly_revenue,
       SUM(monthly_revenue) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS trailing_3mo_sum
FROM (SELECT DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_revenue FROM sales.orders GROUP BY 1) m
ORDER BY month;

/* Q99. */
SELECT p.product_id, o.order_date, oi.quantity,
       SUM(oi.quantity) OVER (PARTITION BY p.product_id ORDER BY o.order_date, oi.order_item_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_units_sold
FROM sales.order_items oi
JOIN sales.orders o ON oi.order_id = o.order_id
JOIN products.products p ON oi.prod_id = p.product_id;

/* Q100. */
SELECT order_date, daily_revenue,
       AVG(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7day,
       SUM(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_total
FROM (SELECT order_date, SUM(net_total) AS daily_revenue FROM sales.orders GROUP BY order_date) d
ORDER BY order_date;

/* ============================================================
   END OF ANSWER KEY - Window Functions Part 2 - EASY LEVEL (100/100)
============================================================ */
