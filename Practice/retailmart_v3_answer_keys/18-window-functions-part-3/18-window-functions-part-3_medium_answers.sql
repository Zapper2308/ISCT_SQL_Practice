/* ============================================================
   ANSWER KEY - Window Functions Part 3: LAG / LEAD (MEDIUM LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1. "Previous order for this customer" only makes sense within that customer's own row set; PARTITION BY cust_id resets the LAG lookup so it never crosses into another customer's orders. */
/* Q2. (current_value / LAG(current_value) OVER (...) - 1) * 100; NULLIF guards it because LAG can return 0 or NULL (no prior period), and dividing by either directly would error or misleadingly propagate, instead of a clean NULL growth value. */
/* Q3. Without a gap-filled series, months with zero activity are simply missing rows, so LAG(x,1) actually returns the value from the last month that DID have activity - not the true immediately-preceding calendar month - silently corrupting the comparison. */
/* Q4. First argument: the column/expression to shift; second (offset): how many rows back to look, default 1; third (default): the value to return when that row doesn't exist, default NULL. */
/* Q5. order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date, order_id). */
/* Q6. Compare the current value to LAG(value) OVER (...) with <>; wherever the two differ, that row marks a change-point from the previous value. */
/* Q7. Flag a row as starting a new session when its gap to the previous event (via LAG on the timestamp) exceeds N minutes; every event up to the next such flag belongs to the same session. */
/* Q8. Because LEAD looks forward to the very next row, so LEAD(timestamp) - timestamp directly gives the elapsed time until the next event, with no self-join or subquery needed. */
/* Q9. It requires a complete, gap-filled monthly series (all 12 months per year present) and a consistent, unique ORDER BY, since LAG(x,12) simply counts back 12 physical rows - a missing month silently shifts the comparison to the wrong year. */
/* Q10. LAG(...) IS NULL - the first row of each partition has no row before it, so LAG returns NULL there by default. */
/* Q11. Compute LAG(x) AS prev_value and LEAD(x) AS next_value in the same SELECT, each independently defined in its own OVER() clause. */
/* Q12. Because window functions (LAG/LEAD included) are evaluated after WHERE in the query's logical processing order, a LAG-based condition can't be referenced in that same SELECT's WHERE - it must first be computed in a subquery/CTE and filtered in the enclosing query. */
/* Q13. delta = current_value - LAG(current_value) OVER (...); pct_delta = ROUND(100.0 * delta / NULLIF(LAG(current_value) OVER (...), 0), 2) - both computed together in the same SELECT. */
/* Q14. Compare the current row's value to LAG(value); a run of consecutive rows where value = LAG(value) marks a streak, whose length can then be measured with a running count that resets whenever the comparison is false. */
/* Q15. Ties on the ORDER BY column alone leave row order ambiguous, so adding a unique tiebreaker (like the primary key) guarantees the LAG/LEAD sequence is identical and reproducible on every run. */
/* Q16. "Gap to previous" measures time since the most recent prior event (current_date - LAG(date)); "gap to next" measures time until the following event (LEAD(date) - current_date) - opposite directions along the same timeline. */
/* Q17. Build a complete list of expected periods (generate_series), LEFT JOIN the actual data onto it with COALESCE to 0 for missing periods, so LAG always compares against the true immediately-prior period instead of silently skipping gaps. */
/* Q18. Plain LAG only ever returns the immediately preceding row's value, even if it's NULL; getting the "previous non-null value" needs either a running MAX of a marker/flag column or a fill-forward technique layered on top of LAG. */
/* Q19. LAG(value, 3) OVER (...) - the offset argument directly controls how many rows back to compare against, so offset 3 gives "this row vs 3 rows earlier" in one call. */
/* Q20. Flag each row where the gap to the previous event exceeds the session threshold (a boolean "new session" flag), then take a running SUM() of that flag as the session id - it increments by 1 at each flag and stays constant until the next one. */
/* Q21. A raw transaction table typically has one row per event, not one row per calendar period; you must first GROUP BY the target grain (day/week/month) before applying LAG so "previous" means "previous period", not "previous individual transaction". */
/* Q22. The first order's date (MIN(order_date) OVER (PARTITION BY cust_id)) subtracted from LEAD(order_date) evaluated on that same first-order row - equivalently, the 2nd order's date minus the 1st order's date. */
/* Q23. Flag customers whose gap to the previous order (via LAG on order_date) exceeds 90 days, then check whether they placed a subsequent order after that gap - a straightforward LAG-based date-difference filter. */
/* Q24. Aggregate to (region, month) grain first, then compute LAG(revenue) OVER (PARTITION BY region ORDER BY month) so each region's month is only ever compared to that same region's own prior month, never another region's. */
/* Q25. LAG/LEAD beats a self-join whenever you need "the previous/next row" by position in an ordered sequence - it's a single pass, clearer to read, and avoids the extra join/aggregation overhead a self-join on a shifted key would require. */

/* ============================================================
   SECTION B: PERIOD-OVER-PERIOD (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT store_id, month, monthly_revenue,
       ROUND(100.0 * (monthly_revenue - LAG(monthly_revenue) OVER (PARTITION BY store_id ORDER BY month)) / NULLIF(LAG(monthly_revenue) OVER (PARTITION BY store_id ORDER BY month), 0), 2) AS mom_growth_pct
FROM (SELECT store_id, DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_revenue FROM sales.orders GROUP BY store_id, DATE_TRUNC('month', order_date)) m
ORDER BY store_id, month;

/* Q27. */
SELECT store_id, week, weekly_orders,
       ROUND(100.0 * (weekly_orders - LAG(weekly_orders) OVER (PARTITION BY store_id ORDER BY week)) / NULLIF(LAG(weekly_orders) OVER (PARTITION BY store_id ORDER BY week), 0), 2) AS wow_growth_pct
FROM (SELECT store_id, DATE_TRUNC('week', order_date) AS week, COUNT(*) AS weekly_orders FROM sales.orders GROUP BY store_id, DATE_TRUNC('week', order_date)) t
ORDER BY store_id, week;

/* Q28. */
SELECT region_id, quarter, quarterly_revenue,
       quarterly_revenue - LAG(quarterly_revenue) OVER (PARTITION BY region_id ORDER BY quarter) AS qoq_change
FROM (SELECT s.region_id, DATE_TRUNC('quarter', o.order_date) AS quarter, SUM(o.net_total) AS quarterly_revenue FROM sales.orders o JOIN stores.stores s ON o.store_id = s.store_id GROUP BY s.region_id, DATE_TRUNC('quarter', o.order_date)) t
ORDER BY region_id, quarter;

/* Q29. */
SELECT month, monthly_revenue,
       LAG(monthly_revenue, 12) OVER (ORDER BY month) AS same_month_last_year
FROM (SELECT DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_revenue FROM sales.orders GROUP BY 1) m
ORDER BY month;

/* Q30. */
SELECT region_id, month, new_signups,
       ROUND(100.0 * (new_signups - LAG(new_signups) OVER (PARTITION BY region_id ORDER BY month)) / NULLIF(LAG(new_signups) OVER (PARTITION BY region_id ORDER BY month), 0), 2) AS mom_growth_pct
FROM (
    SELECT r.region_id, DATE_TRUNC('month', c.registration_date) AS month, COUNT(DISTINCT c.customer_id) AS new_signups
    FROM customers.customers c
    JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = true
    JOIN core.dim_region r ON r.state = a.state
    GROUP BY r.region_id, DATE_TRUNC('month', c.registration_date)
) t
ORDER BY region_id, month;

/* Q31. */
SELECT exp_cat_id, month, monthly_amount,
       ROUND(100.0 * (monthly_amount - LAG(monthly_amount) OVER (PARTITION BY exp_cat_id ORDER BY month)) / NULLIF(LAG(monthly_amount) OVER (PARTITION BY exp_cat_id ORDER BY month), 0), 2) AS mom_change_pct
FROM (SELECT exp_cat_id, DATE_TRUNC('month', expense_date) AS month, SUM(amount) AS monthly_amount FROM finance.expenses GROUP BY exp_cat_id, DATE_TRUNC('month', expense_date)) t
ORDER BY exp_cat_id, month;

/* Q32. */
SELECT gs.d AS order_date, COALESCE(r.daily_revenue, 0) AS daily_revenue,
       COALESCE(r.daily_revenue, 0) - LAG(COALESCE(r.daily_revenue, 0)) OVER (ORDER BY gs.d) AS dod_change
FROM generate_series(
        (SELECT MIN(order_date) FROM sales.orders),
        (SELECT MAX(order_date) FROM sales.orders),
        INTERVAL '1 day'
     ) AS gs(d)
LEFT JOIN (SELECT order_date, SUM(net_total) AS daily_revenue FROM sales.orders GROUP BY order_date) r
  ON r.order_date = gs.d
ORDER BY gs.d;

/* Q33. */
SELECT employee_id, month, monthly_net_salary,
       monthly_net_salary - LAG(monthly_net_salary) OVER (PARTITION BY employee_id ORDER BY month) AS mom_change
FROM (SELECT employee_id, DATE_TRUNC('month', payment_date) AS month, SUM(net_salary) AS monthly_net_salary FROM payroll.pay_slips GROUP BY employee_id, DATE_TRUNC('month', payment_date)) t
ORDER BY employee_id, month;

/* Q34. */
SELECT prod_id, month, monthly_units,
       ROUND(100.0 * (monthly_units - LAG(monthly_units) OVER (PARTITION BY prod_id ORDER BY month)) / NULLIF(LAG(monthly_units) OVER (PARTITION BY prod_id ORDER BY month), 0), 2) AS mom_growth_pct
FROM (SELECT oi.prod_id, DATE_TRUNC('month', o.order_date) AS month, SUM(oi.quantity) AS monthly_units FROM sales.order_items oi JOIN sales.orders o ON oi.order_id = o.order_id GROUP BY oi.prod_id, DATE_TRUNC('month', o.order_date)) t
ORDER BY prod_id, month;

/* Q35. */
SELECT week, weekly_active_customers,
       weekly_active_customers - LAG(weekly_active_customers) OVER (ORDER BY week) AS wow_change
FROM (SELECT DATE_TRUNC('week', order_date) AS week, COUNT(DISTINCT cust_id) AS weekly_active_customers FROM sales.orders GROUP BY 1) w
ORDER BY week;

/* Q36. */
SELECT category_id, month, monthly_revenue,
       ROUND(100.0 * (monthly_revenue - LAG(monthly_revenue) OVER (PARTITION BY category_id ORDER BY month)) / NULLIF(LAG(monthly_revenue) OVER (PARTITION BY category_id ORDER BY month), 0), 2) AS mom_growth_pct
FROM (
    SELECT b.category_id, DATE_TRUNC('month', o.order_date) AS month, SUM(oi.net_amount) AS monthly_revenue
    FROM sales.order_items oi
    JOIN sales.orders o ON oi.order_id = o.order_id
    JOIN products.products p ON oi.prod_id = p.product_id
    JOIN core.dim_brand b ON p.brand_id = b.brand_id
    GROUP BY b.category_id, DATE_TRUNC('month', o.order_date)
) t
ORDER BY category_id, month;

/* Q37. */
SELECT store_id, quarter, quarterly_revenue,
       ROUND(100.0 * (quarterly_revenue - LAG(quarterly_revenue) OVER (PARTITION BY store_id ORDER BY quarter)) / NULLIF(LAG(quarterly_revenue) OVER (PARTITION BY store_id ORDER BY quarter), 0), 2) AS qoq_growth_pct,
       CASE WHEN quarterly_revenue > LAG(quarterly_revenue) OVER (PARTITION BY store_id ORDER BY quarter) THEN 'UP'
            WHEN quarterly_revenue < LAG(quarterly_revenue) OVER (PARTITION BY store_id ORDER BY quarter) THEN 'DOWN'
            ELSE 'FLAT' END AS flag
FROM (SELECT store_id, DATE_TRUNC('quarter', order_date) AS quarter, SUM(net_total) AS quarterly_revenue FROM sales.orders GROUP BY store_id, DATE_TRUNC('quarter', order_date)) t
ORDER BY store_id, quarter;

/* Q38. */
SELECT category_id, month, monthly_refunds,
       ROUND(100.0 * (monthly_refunds - LAG(monthly_refunds) OVER (PARTITION BY category_id ORDER BY month)) / NULLIF(LAG(monthly_refunds) OVER (PARTITION BY category_id ORDER BY month), 0), 2) AS mom_change_pct
FROM (
    SELECT b.category_id, DATE_TRUNC('month', r.return_date) AS month, SUM(r.refund_amount) AS monthly_refunds
    FROM sales.returns r
    JOIN products.products p ON r.prod_id = p.product_id
    JOIN core.dim_brand b ON p.brand_id = b.brand_id
    GROUP BY b.category_id, DATE_TRUNC('month', r.return_date)
) t
ORDER BY category_id, month;

/* Q39. */
SELECT platform, month, monthly_spend,
       ROUND(100.0 * (monthly_spend - LAG(monthly_spend) OVER (PARTITION BY platform ORDER BY month)) / NULLIF(LAG(monthly_spend) OVER (PARTITION BY platform ORDER BY month), 0), 2) AS mom_change_pct
FROM (SELECT platform, DATE_TRUNC('month', spend_date) AS month, SUM(amount) AS monthly_spend FROM marketing.ads_spend GROUP BY platform, DATE_TRUNC('month', spend_date)) t
ORDER BY platform, month;

/* Q40. */
SELECT region_id, quarter, quarterly_revenue,
       LAG(quarterly_revenue, 4) OVER (PARTITION BY region_id ORDER BY quarter) AS same_quarter_last_year
FROM (SELECT s.region_id, DATE_TRUNC('quarter', o.order_date) AS quarter, SUM(o.net_total) AS quarterly_revenue FROM sales.orders o JOIN stores.stores s ON o.store_id = s.store_id GROUP BY s.region_id, DATE_TRUNC('quarter', o.order_date)) t
ORDER BY region_id, quarter;

/* Q41. */
SELECT product_id, month, monthly_reviews,
       monthly_reviews - LAG(monthly_reviews) OVER (PARTITION BY product_id ORDER BY month) AS mom_change
FROM (SELECT product_id, DATE_TRUNC('month', review_date) AS month, COUNT(*) AS monthly_reviews FROM customers.reviews GROUP BY product_id, DATE_TRUNC('month', review_date)) t
ORDER BY product_id, month;

/* Q42. */
SELECT category, month, monthly_tickets,
       monthly_tickets - LAG(monthly_tickets) OVER (PARTITION BY category ORDER BY month) AS mom_change
FROM (SELECT category, DATE_TRUNC('month', created_date) AS month, COUNT(*) AS monthly_tickets FROM support.tickets GROUP BY category, DATE_TRUNC('month', created_date)) t
ORDER BY category, month;

/* Q43. */
SELECT device_type, month, monthly_views,
       monthly_views - LAG(monthly_views) OVER (PARTITION BY device_type ORDER BY month) AS mom_change
FROM (SELECT device_type, DATE_TRUNC('month', view_timestamp) AS month, COUNT(*) AS monthly_views FROM web_events.page_views GROUP BY device_type, DATE_TRUNC('month', view_timestamp)) t
ORDER BY device_type, month;

/* Q44. */
SELECT store_id, month, aov,
       ROUND(aov - LAG(aov) OVER (PARTITION BY store_id ORDER BY month), 2) AS mom_aov_change
FROM (SELECT store_id, DATE_TRUNC('month', order_date) AS month, AVG(net_total) AS aov FROM sales.orders GROUP BY store_id, DATE_TRUNC('month', order_date)) t
ORDER BY store_id, month;

/* Q45. */
SELECT city, month, new_customers,
       ROUND(100.0 * (new_customers - LAG(new_customers) OVER (PARTITION BY city ORDER BY month)) / NULLIF(LAG(new_customers) OVER (PARTITION BY city ORDER BY month), 0), 2) AS mom_growth_pct
FROM (
    SELECT a.city, DATE_TRUNC('month', c.registration_date) AS month, COUNT(DISTINCT c.customer_id) AS new_customers
    FROM customers.customers c
    JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = true
    GROUP BY a.city, DATE_TRUNC('month', c.registration_date)
) t
ORDER BY city, month;

/* Q46. */
WITH region_month AS (
    SELECT s.region_id, DATE_TRUNC('month', o.order_date) AS month, SUM(o.net_total) AS monthly_revenue
    FROM sales.orders o
    JOIN stores.stores s ON o.store_id = s.store_id
    GROUP BY s.region_id, DATE_TRUNC('month', o.order_date)
),
contrib AS (
    SELECT region_id, month, monthly_revenue,
           ROUND(100.0 * monthly_revenue / SUM(monthly_revenue) OVER (PARTITION BY month), 2) AS pct_of_company
    FROM region_month
)
SELECT region_id, month, pct_of_company,
       pct_of_company - LAG(pct_of_company) OVER (PARTITION BY region_id ORDER BY month) AS mom_contribution_change
FROM contrib
ORDER BY region_id, month;

/* Q47. */
SELECT month, monthly_revenue,
       ROUND(100.0 * (monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY month)) / NULLIF(LAG(monthly_revenue) OVER (ORDER BY month), 0), 2) AS mom_growth_pct,
       (monthly_revenue < LAG(monthly_revenue) OVER (ORDER BY month)) AS turned_negative
FROM (SELECT DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_revenue FROM sales.orders GROUP BY 1) m
ORDER BY month;

/* Q48. */
SELECT month, monthly_revenue,
       LAG(monthly_revenue, 2) OVER (ORDER BY month) AS revenue_2mo_ago,
       monthly_revenue - LAG(monthly_revenue, 2) OVER (ORDER BY month) AS change_vs_2mo_ago
FROM (SELECT DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_revenue FROM sales.orders GROUP BY 1) m
ORDER BY month;

/* Q49. */
WITH brand_rev AS (
    SELECT p.brand_id, DATE_TRUNC('month', o.order_date) AS month, SUM(oi.net_amount) AS monthly_revenue
    FROM sales.order_items oi
    JOIN sales.orders o ON oi.order_id = o.order_id
    JOIN products.products p ON oi.prod_id = p.product_id
    GROUP BY p.brand_id, DATE_TRUNC('month', o.order_date)
),
top5 AS (
    SELECT brand_id FROM (SELECT brand_id, SUM(monthly_revenue) AS total_revenue FROM brand_rev GROUP BY brand_id ORDER BY total_revenue DESC LIMIT 5) x
)
SELECT br.brand_id, br.month, br.monthly_revenue,
       ROUND(100.0 * (br.monthly_revenue - LAG(br.monthly_revenue) OVER (PARTITION BY br.brand_id ORDER BY br.month)) / NULLIF(LAG(br.monthly_revenue) OVER (PARTITION BY br.brand_id ORDER BY br.month), 0), 2) AS mom_growth_pct
FROM brand_rev br
JOIN top5 ON top5.brand_id = br.brand_id
ORDER BY br.brand_id, br.month;

/* Q50. */
SELECT store_id, month, monthly_revenue,
       LAG(monthly_revenue) OVER (PARTITION BY store_id ORDER BY month) AS prev_revenue,
       ROUND(100.0 * (monthly_revenue - LAG(monthly_revenue) OVER (PARTITION BY store_id ORDER BY month)) / NULLIF(LAG(monthly_revenue) OVER (PARTITION BY store_id ORDER BY month), 0), 2) AS growth_pct,
       CASE WHEN monthly_revenue > LAG(monthly_revenue) OVER (PARTITION BY store_id ORDER BY month) THEN 'UP'
            WHEN monthly_revenue < LAG(monthly_revenue) OVER (PARTITION BY store_id ORDER BY month) THEN 'DOWN'
            ELSE 'FLAT' END AS flag
FROM (SELECT store_id, DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_revenue FROM sales.orders GROUP BY store_id, DATE_TRUNC('month', order_date)) m
ORDER BY store_id, month;

/* ============================================================
   SECTION C: GAP ANALYSIS (25)
   ------------------------------------------------------------ */
/* Q51. */
SELECT order_id, cust_id, order_date,
       order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS gap_days
FROM sales.orders;

/* Q52. */
SELECT cust_id, AVG(gap_days) AS avg_gap_days
FROM (SELECT cust_id, order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS gap_days FROM sales.orders) t
WHERE gap_days IS NOT NULL
GROUP BY cust_id
ORDER BY cust_id;

/* Q53. */
SELECT cust_id, MAX(gap_days) AS longest_gap_days
FROM (SELECT cust_id, order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS gap_days FROM sales.orders) t
GROUP BY cust_id
ORDER BY longest_gap_days DESC NULLS LAST;

/* Q54. */
SELECT DISTINCT cust_id
FROM (SELECT cust_id, order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS gap_days FROM sales.orders) t
WHERE gap_days > 90;

/* Q55. */
SELECT cust_id, order_date AS first_order_date, next_order_date - order_date AS days_to_second_order
FROM (
    SELECT cust_id, order_date, LEAD(order_date) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS next_order_date,
           MIN(order_date) OVER (PARTITION BY cust_id) AS first_order_date
    FROM sales.orders
) t
WHERE order_date = first_order_date;

/* Q56. */
SELECT review_id, customer_id, review_date,
       LEAD(review_date) OVER (PARTITION BY customer_id ORDER BY review_date, review_id) - review_date AS gap_to_next_review
FROM customers.reviews;

/* Q57. */
SELECT call_id, customer_id, call_start_time,
       call_start_time - LAG(call_start_time) OVER (PARTITION BY customer_id ORDER BY call_start_time, call_id) AS gap_to_prev_call
FROM call_center.calls;

/* Q58. */
SELECT shipment_id, courier_name, shipped_date,
       shipped_date - LAG(shipped_date) OVER (PARTITION BY courier_name ORDER BY shipped_date, shipment_id) AS gap_days
FROM sales.shipments;

/* Q59. */
SELECT warehouse_id, product_id, snapshot_date,
       snapshot_date - LAG(snapshot_date) OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date) AS gap_days
FROM supply_chain.inventory_snapshots;

/* Q60. */
SELECT cust_id, MAX(order_date) - MIN(order_date) AS customer_lifespan_days
FROM sales.orders
GROUP BY cust_id
ORDER BY cust_id;

/* Q61. */
SELECT view_id, session_id, view_timestamp,
       view_timestamp - LAG(view_timestamp) OVER (PARTITION BY session_id ORDER BY view_timestamp, view_id) AS gap_to_prev_view
FROM web_events.page_views;

/* Q62. */
WITH gaps AS (
    SELECT cust_id, order_date, order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS gap_days,
           MAX(order_date) OVER (PARTITION BY cust_id) AS last_order_date
    FROM sales.orders
),
avg_gaps AS (
    SELECT cust_id, AVG(gap_days) AS avg_gap FROM gaps WHERE gap_days IS NOT NULL GROUP BY cust_id
)
SELECT g.cust_id, g.gap_days AS most_recent_gap, a.avg_gap
FROM gaps g
JOIN avg_gaps a ON a.cust_id = g.cust_id
WHERE g.order_date = g.last_order_date AND g.gap_days > a.avg_gap;

/* Q63. */
SELECT cust_id, gap_days,
       CASE WHEN gap_days <= 7 THEN '0-7d'
            WHEN gap_days <= 30 THEN '8-30d'
            WHEN gap_days <= 90 THEN '31-90d'
            ELSE '90d+' END AS gap_bucket
FROM (SELECT cust_id, order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS gap_days FROM sales.orders) t
WHERE gap_days IS NOT NULL
ORDER BY cust_id;

/* Q64. */
SELECT ticket_id, agent_id, created_date,
       LEAD(created_date) OVER (PARTITION BY agent_id ORDER BY created_date, ticket_id) - created_date AS gap_to_next_ticket
FROM support.tickets;

/* Q65. */
SELECT record_id AS product_id, changed_at,
       changed_at - LAG(changed_at) OVER (PARTITION BY record_id ORDER BY changed_at, change_id) AS days_since_prev_change
FROM audit.record_changes
WHERE table_name = 'products' AND column_name = 'price'
ORDER BY record_id, changed_at;

/* Q66. */
SELECT payment_id, order_id, payment_date,
       payment_date - LAG(payment_date) OVER (PARTITION BY order_id ORDER BY payment_date, payment_id) AS gap_days
FROM sales.payments;

/* Q67. */
WITH gaps AS (
    SELECT s.region_id, o.order_date - LAG(o.order_date) OVER (PARTITION BY o.cust_id ORDER BY o.order_date, o.order_id) AS gap_days
    FROM sales.orders o
    JOIN stores.stores s ON o.store_id = s.store_id
)
SELECT region_id, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY gap_days) AS median_gap_days
FROM gaps
WHERE gap_days IS NOT NULL
GROUP BY region_id
ORDER BY region_id;

/* Q68. */
WITH gaps AS (
    SELECT cust_id, order_date,
           order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS gap_days
    FROM sales.orders
),
gap_pairs AS (
    SELECT cust_id, order_date, gap_days,
           LAG(gap_days) OVER (PARTITION BY cust_id ORDER BY order_date) AS prev_gap_days
    FROM gaps
)
SELECT cust_id, order_date, gap_days, prev_gap_days
FROM gap_pairs
WHERE gap_days IS NOT NULL AND prev_gap_days IS NOT NULL AND gap_days < prev_gap_days
ORDER BY cust_id, order_date;

/* Q69. */
SELECT o.cust_id, c.registration_date, MIN(o.order_date) AS first_order_date,
       MIN(o.order_date) - c.registration_date AS days_to_first_order
FROM sales.orders o
JOIN customers.customers c ON o.cust_id = c.customer_id
GROUP BY o.cust_id, c.registration_date
ORDER BY o.cust_id;

/* Q70. */
SELECT promo_id, promo_name, start_date,
       start_date - LAG(start_date) OVER (ORDER BY start_date, promo_id) AS gap_to_prev_promo
FROM products.promotions
ORDER BY start_date;

/* Q71. */
WITH ret AS (
    SELECT r.return_id, o.cust_id, r.return_date FROM sales.returns r JOIN sales.orders o ON r.order_id = o.order_id
),
candidates AS (
    SELECT ret.return_id, o2.order_date
    FROM ret
    JOIN sales.orders o2 ON o2.cust_id = ret.cust_id AND o2.order_date > ret.return_date
)
SELECT ret.cust_id, ret.return_date,
       MIN(c.order_date) AS next_order_after_return,
       MIN(c.order_date) - ret.return_date AS days_to_next_order
FROM ret
LEFT JOIN candidates c ON c.return_id = ret.return_id
GROUP BY ret.return_id, ret.cust_id, ret.return_date
ORDER BY ret.cust_id, ret.return_date;

/* Q72. */
WITH daily AS (
    SELECT store_id, order_date, SUM(net_total) AS daily_revenue FROM sales.orders GROUP BY store_id, order_date
),
deltas AS (
    SELECT store_id, order_date, daily_revenue - LAG(daily_revenue) OVER (PARTITION BY store_id ORDER BY order_date) AS jump
    FROM daily
)
SELECT store_id, MAX(jump) AS largest_single_day_jump
FROM deltas
GROUP BY store_id
ORDER BY largest_single_day_jump DESC NULLS LAST;

/* Q73. */
SELECT cust_id, last_order_date, CURRENT_DATE - last_order_date AS days_dormant
FROM (SELECT cust_id, MAX(order_date) AS last_order_date FROM sales.orders GROUP BY cust_id) t
WHERE CURRENT_DATE - last_order_date > 180
ORDER BY days_dormant DESC;

/* Q74. */
SELECT product_id, AVG(gap_days) AS avg_gap_days
FROM (SELECT product_id, review_date - LAG(review_date) OVER (PARTITION BY product_id ORDER BY review_date, review_id) AS gap_days FROM customers.reviews) t
WHERE gap_days IS NOT NULL
GROUP BY product_id
ORDER BY product_id;

/* Q75. */
SELECT cust_id, AVG(gap_days) AS avg_gap, MIN(gap_days) AS min_gap, MAX(gap_days) AS max_gap
FROM (SELECT cust_id, order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS gap_days FROM sales.orders) t
WHERE gap_days IS NOT NULL
GROUP BY cust_id
ORDER BY cust_id;

/* ============================================================
   SECTION D: SESSIONIZATION & CHANGE DETECTION (25)
   ------------------------------------------------------------ */
/* Q76. */
SELECT view_id, session_id, view_timestamp,
       (view_timestamp - LAG(view_timestamp) OVER (PARTITION BY session_id ORDER BY view_timestamp, view_id) > INTERVAL '30 minutes'
        OR LAG(view_timestamp) OVER (PARTITION BY session_id ORDER BY view_timestamp, view_id) IS NULL) AS is_new_session
FROM web_events.page_views;

/* Q77. */
SELECT view_id, session_id, view_timestamp,
       SUM(CASE WHEN is_new_session THEN 1 ELSE 0 END) OVER (PARTITION BY session_id ORDER BY view_timestamp, view_id) AS derived_session_seq
FROM (
    SELECT view_id, session_id, view_timestamp,
           (view_timestamp - LAG(view_timestamp) OVER (PARTITION BY session_id ORDER BY view_timestamp, view_id) > INTERVAL '30 minutes'
            OR LAG(view_timestamp) OVER (PARTITION BY session_id ORDER BY view_timestamp, view_id) IS NULL) AS is_new_session
    FROM web_events.page_views
) t
ORDER BY session_id, view_timestamp;

/* Q78. */
SELECT session_id, MIN(view_timestamp) AS session_start, MAX(view_timestamp) AS session_end,
       MAX(view_timestamp) - MIN(view_timestamp) AS session_duration
FROM web_events.page_views
GROUP BY session_id
ORDER BY session_id;

/* Q79. */
SELECT session_id, COUNT(*) AS views_per_session
FROM web_events.page_views
GROUP BY session_id
ORDER BY session_id;

/* Q80. */
SELECT record_id AS product_id, changed_at, old_value, new_value
FROM audit.record_changes
WHERE table_name = 'products' AND column_name = 'price'
ORDER BY record_id, changed_at;

/* Q81. */
SELECT record_id AS product_id, changed_at, old_value, new_value,
       ROUND(100.0 * (new_value::numeric - old_value::numeric) / NULLIF(old_value::numeric, 0), 2) AS pct_change
FROM audit.record_changes
WHERE table_name = 'products' AND column_name = 'price'
  AND ABS(new_value::numeric - old_value::numeric) > 0.5 * old_value::numeric
ORDER BY record_id, changed_at;

/* Q82. */
WITH order_events AS (
    SELECT order_id, order_date AS event_date, 'Placed' AS status_event FROM sales.orders
    UNION ALL
    SELECT order_id, payment_date, 'Paid' FROM sales.payments
    UNION ALL
    SELECT order_id, shipped_date, 'Shipped' FROM sales.shipments WHERE shipped_date IS NOT NULL
    UNION ALL
    SELECT order_id, delivered_date, 'Delivered' FROM sales.shipments WHERE delivered_date IS NOT NULL
    UNION ALL
    SELECT order_id, return_date, 'Returned' FROM sales.returns
)
SELECT order_id, event_date, status_event,
       LAG(status_event) OVER (PARTITION BY order_id ORDER BY event_date) AS prior_status_event
FROM order_events
ORDER BY order_id, event_date;

/* Q83. */
SELECT customer_id, tier, tier_updated_at,
       LAG(tier) OVER (PARTITION BY customer_id ORDER BY tier_updated_at) AS prior_tier,
       (tier <> LAG(tier) OVER (PARTITION BY customer_id ORDER BY tier_updated_at)) AS is_tier_change
FROM customers.customers
ORDER BY customer_id;

/* Q84. */
SELECT warehouse_id, product_id, snapshot_date, quantity_on_hand,
       LAG(quantity_on_hand) OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date) AS prev_quantity,
       (quantity_on_hand = 0 AND LAG(quantity_on_hand) OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date) > 0) AS is_stockout
FROM supply_chain.inventory_snapshots;

/* Q85. */
SELECT review_id, product_id, review_date, rating,
       LAG(rating) OVER (PARTITION BY product_id ORDER BY review_date, review_id) AS prev_rating,
       (rating < LAG(rating) OVER (PARTITION BY product_id ORDER BY review_date, review_id)) AS is_rating_drop
FROM customers.reviews;

/* Q86. */
SELECT order_date, daily_revenue,
       MAX(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS prior_record_high,
       (daily_revenue > MAX(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING)) AS is_new_record
FROM (SELECT order_date, SUM(net_total) AS daily_revenue FROM sales.orders GROUP BY order_date) d
ORDER BY order_date;

/* Q87. */
SELECT cust_id, order_date, gap_days
FROM (SELECT cust_id, order_date, order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS gap_days FROM sales.orders) t
WHERE gap_days > 90
ORDER BY cust_id, order_date;

/* Q88. */
WITH mom AS (
    SELECT month, monthly_revenue,
           (monthly_revenue < LAG(monthly_revenue) OVER (ORDER BY month)) AS is_decline
    FROM (SELECT DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_revenue FROM sales.orders GROUP BY 1) m
),
flagged AS (
    SELECT month, monthly_revenue, is_decline,
           LAG(is_decline) OVER (ORDER BY month) AS prev_month_was_decline
    FROM mom
)
SELECT month, monthly_revenue, is_decline, prev_month_was_decline
FROM flagged
WHERE is_decline AND prev_month_was_decline
ORDER BY month;

/* Q89. */
WITH store_month AS (
    SELECT store_id, DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_revenue FROM sales.orders GROUP BY store_id, DATE_TRUNC('month', order_date)
),
flagged AS (
    SELECT store_id, month, monthly_revenue,
           LAG(monthly_revenue) OVER (PARTITION BY store_id ORDER BY month) AS prev_revenue
    FROM store_month
)
SELECT store_id, MIN(month) AS first_month_crossed_100k
FROM flagged
WHERE monthly_revenue >= 100000 AND (prev_revenue IS NULL OR prev_revenue < 100000)
GROUP BY store_id
ORDER BY store_id;

/* Q90. */
SELECT order_id, cust_id, order_date
FROM (
    SELECT order_id, cust_id, order_date, LEAD(order_date) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS next_order_date
    FROM sales.orders
) t
WHERE next_order_date IS NULL
ORDER BY cust_id;

/* Q91. */
SELECT customer_id, view_timestamp::date AS view_day, COUNT(DISTINCT session_id) AS distinct_sessions
FROM web_events.page_views
GROUP BY customer_id, view_timestamp::date
ORDER BY customer_id, view_day;

/* Q92. */
SELECT device_type, AVG(session_duration) AS avg_session_length
FROM (
    SELECT session_id, MAX(device_type) AS device_type, MAX(view_timestamp) - MIN(view_timestamp) AS session_duration
    FROM web_events.page_views
    GROUP BY session_id
) t
GROUP BY device_type
ORDER BY device_type;

/* Q93. */
SELECT order_id, cust_id, order_date, next_order_date
FROM (
    SELECT order_id, cust_id, order_date, LEAD(order_date) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS next_order_date
    FROM sales.orders
) t
WHERE next_order_date - order_date <= 1
ORDER BY cust_id, order_date;

/* Q94. */
SELECT employee_id, month, monthly_net_salary,
       LAG(monthly_net_salary) OVER (PARTITION BY employee_id ORDER BY month) AS prev_month_salary,
       (monthly_net_salary <> LAG(monthly_net_salary) OVER (PARTITION BY employee_id ORDER BY month)) AS is_salary_change
FROM (SELECT employee_id, DATE_TRUNC('month', payment_date) AS month, SUM(net_salary) AS monthly_net_salary FROM payroll.pay_slips GROUP BY employee_id, DATE_TRUNC('month', payment_date)) t
ORDER BY employee_id, month;

/* Q95. */
SELECT record_id AS product_id, COUNT(*) AS price_change_count
FROM audit.record_changes
WHERE table_name = 'products' AND column_name = 'price'
GROUP BY record_id
HAVING COUNT(*) > 3
ORDER BY price_change_count DESC;

/* Q96. */
WITH cust_months AS (
    SELECT DISTINCT cust_id, DATE_TRUNC('month', order_date) AS month FROM sales.orders
),
numbered AS (
    SELECT cust_id, month, (EXTRACT(YEAR FROM month) * 12 + EXTRACT(MONTH FROM month))::int AS month_num
    FROM cust_months
),
flagged AS (
    SELECT cust_id, month, month_num,
           (month_num - LAG(month_num) OVER (PARTITION BY cust_id ORDER BY month_num)) AS gap
    FROM numbered
),
streak_group AS (
    SELECT cust_id, month, month_num,
           SUM(CASE WHEN gap = 1 THEN 0 ELSE 1 END) OVER (PARTITION BY cust_id ORDER BY month_num) AS streak_id
    FROM flagged
)
SELECT cust_id, streak_id, COUNT(*) AS streak_length, MIN(month) AS streak_start, MAX(month) AS streak_end
FROM streak_group
GROUP BY cust_id, streak_id
ORDER BY cust_id, streak_length DESC;

/* Q97. */
WITH camp_month AS (
    SELECT campaign_id, DATE_TRUNC('month', spend_date) AS month, SUM(amount) AS monthly_spend
    FROM marketing.ads_spend
    GROUP BY campaign_id, DATE_TRUNC('month', spend_date)
)
SELECT campaign_id, month, monthly_spend,
       LAG(monthly_spend) OVER (PARTITION BY campaign_id ORDER BY month) AS prev_month_spend,
       (monthly_spend >= 2 * LAG(monthly_spend) OVER (PARTITION BY campaign_id ORDER BY month)) AS spend_doubled
FROM camp_month
ORDER BY campaign_id, month;

/* Q98. */
SELECT warehouse_id, product_id, snapshot_date, quantity_on_hand,
       LAG(quantity_on_hand) OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date) AS prev_quantity,
       (quantity_on_hand > LAG(quantity_on_hand) OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date)) AS is_replenishment
FROM supply_chain.inventory_snapshots;

/* Q99. */
SELECT call_id, customer_id, call_start_time,
       (call_start_time - LAG(call_start_time) OVER (PARTITION BY customer_id ORDER BY call_start_time, call_id) > INTERVAL '1 hour'
        OR LAG(call_start_time) OVER (PARTITION BY customer_id ORDER BY call_start_time, call_id) IS NULL) AS is_new_burst
FROM call_center.calls;

/* Q100. */
SELECT session_id, MIN(view_timestamp) AS session_start, MAX(view_timestamp) AS session_end,
       MAX(view_timestamp) - MIN(view_timestamp) AS session_duration, COUNT(*) AS view_count
FROM web_events.page_views
GROUP BY session_id
ORDER BY session_id;

/* ============================================================
   END OF ANSWER KEY - Window Functions Part 3 - MEDIUM LEVEL (100/100)
============================================================ */
