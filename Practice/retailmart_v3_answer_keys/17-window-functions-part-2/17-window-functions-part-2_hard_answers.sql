/* ============================================================
   ANSWER KEY - Window Functions Part 2: Aggregation & Frames (HARD LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1. By default LAST_VALUE's frame only extends up to the current row (RANGE UNBOUNDED PRECEDING AND CURRENT ROW), so on every row but the true last one it just echoes the current row's own value; the fix is ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING so the frame covers the whole partition. */
/* Q2. ROWS counts by physical row position; RANGE groups rows that tie on the ORDER BY value into one logical peer group; GROUPS is like RANGE but counts distinct tied groups as units, so "N GROUPS PRECEDING" means N distinct peer values back regardless of how many rows share each. */
/* Q3. Because a plain GROUP BY over transaction rows skips any day with zero activity, so a fixed 7-row ROWS window could silently span more or fewer than 7 real calendar days; a gap-filled date series must exist before the frame is applied. */
/* Q4. Requires a single date/timestamp ORDER BY column (not a compound key) and the numeric/date type must support interval arithmetic; gotcha - duplicate timestamps on the exact same instant are all pulled in together as peers, inflating the sum for those rows. */
/* Q5. Just use the frame as written (e.g. ROWS BETWEEN 3 PRECEDING AND 3 FOLLOWING) - PostgreSQL automatically shrinks the frame to whatever rows actually exist near a partition edge instead of erroring or padding with NULLs, so edge rows average over fewer points. */
/* Q6. With a frame of ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING (covering the whole partition), FIRST_VALUE always returns the partition's very first row's value, so it acts as a fixed "anchor" repeated identically on every row. */
/* Q7. Use a frame like ROWS BETWEEN N PRECEDING AND 1 PRECEDING (ending one row before the current row) so the current row's own value never contributes to its own "peer" aggregate. */
/* Q8. Window functions have no COUNT(DISTINCT ...) support in PostgreSQL; the workaround is a correlated subquery or LATERAL join that recomputes COUNT(DISTINCT x) over the relevant row range for each output row. */
/* Q9. PARTITION BY period cleanly restarts the running calculation at each new partition value (year, month) with no extra logic; a frame trick instead needs bounds anchored to a computed "period start" row without a true partition boundary - PARTITION BY is simpler whenever the reset point is a clean grouping key. */
/* Q10. Because a fact table has many transaction rows per calendar period; pre-aggregating first means a ROWS BETWEEN N PRECEDING frame corresponds to exactly N real periods instead of an arbitrary, uneven number of transaction rows. */
/* Q11. Compare the current row's value to its trailing moving average (via AVG() OVER (... ROWS BETWEEN N PRECEDING AND CURRENT ROW)) and flag rows where the absolute or relative deviation from that average exceeds a chosen threshold. */
/* Q12. Include two SUM()/AVG() window calls with different PARTITION BY keys (e.g. one by region, one with no partition) in the same SELECT, each row's value divided by its own matching total. */
/* Q13. Because RANGE groups every row tied on the ORDER BY value into a single logical step - if many rows share the same value, all of them are summed together as one step in the running total instead of accumulating one row at a time. */
/* Q14. NTH_VALUE returns the value from the Nth row of the (ordered) frame, so it's used for "2nd order", "3rd-highest sale" and similar ranked-position lookups; it entirely depends on the frame bounds to know which rows are visible when counting to N. */
/* Q15. PostgreSQL has no windowed PERCENTILE_CONT/median equivalent, so a rolling median needs a correlated subquery or LATERAL join recomputing PERCENTILE_CONT() over the relevant row range for each row - far more expensive than a simple frame aggregate. */
/* Q16. Because the running total's denominator keeps changing as the frame grows with each row; the partition's fixed final total must instead come from SUM() OVER (PARTITION BY g) with no ORDER BY, which stays constant across every row. */
/* Q17. Compute two differently-scoped running sums in one SELECT: SUM(x) OVER (PARTITION BY month ORDER BY d) for month-to-date, and the same pattern partitioned by the prior month (or shifted with date arithmetic) for prior-month-to-date. */
/* Q18. It goes in an outer query's WHERE (or HAVING) applied to the result of the windowed SELECT/CTE, since window functions execute after WHERE and can't be filtered directly at the same SELECT level. */
/* Q19. A huge RANGE frame (many tied rows, or a wide interval) can force the engine to re-scan a large, growing row set for every output row instead of incrementally updating a running aggregate, which can scale close to O(n^2) in the worst case. */
/* Q20. generate_series() produces every expected date/period, a LEFT JOIN brings in the actual aggregated facts, and COALESCE fills gaps with 0 - guaranteeing a gap-free series before any window frame is applied. */
/* Q21. A centered average blends future values into "today's" smoothed number, so trend changes appear to happen earlier than they really did; a trailing average uses only past data, so shifts show up later but reflect information genuinely available at that point in time. */
/* Q22. Compute a running MAX() OVER (ORDER BY d ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as the running peak, then express the current value as a percentage of that peak to show how close the row is to its historical high. */
/* Q23. Sort rows descending by contribution, compute SUM(value) OVER (ORDER BY value DESC) for the cumulative contribution and SUM(value) OVER () for the grand total, then divide to get each row's running cumulative share. */
/* Q24. FILTER (WHERE ...) is defined for aggregate function calls but not for window function calls in PostgreSQL; the alternative is to embed the condition inside the aggregate with CASE WHEN ... THEN x ELSE NULL END, since AVG/SUM already ignore NULLs. */
/* Q25. Include two SUM()/AVG() window calls in the same SELECT with different ROWS BETWEEN bounds (e.g. 6 PRECEDING and 29 PRECEDING), each computed independently over its own frame in one pass. */

/* ============================================================
   SECTION B: ROLLING METRICS (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT gs.d AS order_date, COALESCE(r.daily_revenue, 0) AS daily_revenue,
       AVG(COALESCE(r.daily_revenue, 0)) OVER (ORDER BY gs.d ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7day
FROM generate_series(
        (SELECT MIN(order_date) FROM sales.orders),
        (SELECT MAX(order_date) FROM sales.orders),
        INTERVAL '1 day'
     ) AS gs(d)
LEFT JOIN (SELECT order_date, SUM(net_total) AS daily_revenue FROM sales.orders GROUP BY order_date) r
  ON r.order_date = gs.d
ORDER BY gs.d;

/* Q27. */
SELECT store_id, order_date, daily_revenue,
       SUM(daily_revenue) OVER (PARTITION BY store_id ORDER BY order_date RANGE BETWEEN INTERVAL '29 days' PRECEDING AND CURRENT ROW) AS rolling_30day_revenue
FROM (SELECT store_id, order_date, SUM(net_total) AS daily_revenue FROM sales.orders GROUP BY store_id, order_date) d
ORDER BY store_id, order_date;

/* Q28. */
SELECT d.order_date,
       (SELECT COUNT(DISTINCT o2.cust_id) FROM sales.orders o2
        WHERE o2.order_date BETWEEN d.order_date - INTERVAL '6 days' AND d.order_date) AS rolling_7day_distinct_customers
FROM (SELECT DISTINCT order_date FROM sales.orders) d
ORDER BY d.order_date;

/* Q29. */
SELECT store_id, month, monthly_revenue,
       SUM(monthly_revenue) OVER (PARTITION BY store_id ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS trailing_3mo_revenue
FROM (SELECT store_id, DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_revenue FROM sales.orders GROUP BY store_id, DATE_TRUNC('month', order_date)) m
ORDER BY store_id, month;

/* Q30. */
SELECT order_date, daily_order_count,
       SUM(daily_order_count) OVER (ORDER BY order_date ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) AS rolling_28day_order_count,
       AVG(daily_order_count) OVER (ORDER BY order_date ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) AS moving_avg_28day
FROM (SELECT order_date, COUNT(*) AS daily_order_count FROM sales.orders GROUP BY order_date) d
ORDER BY order_date;

/* Q31. */
SELECT shipment_id, courier_name, shipped_date, (delivered_date - shipped_date) AS delivery_days,
       AVG(delivered_date - shipped_date) OVER (PARTITION BY courier_name ORDER BY shipped_date, shipment_id ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) AS moving_avg_20shipments
FROM sales.shipments;

/* Q32. */
SELECT order_date, daily_revenue,
       AVG(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS trailing_7day_avg,
       (daily_revenue > 2 * AVG(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)) AS is_spike
FROM (SELECT order_date, SUM(net_total) AS daily_revenue FROM sales.orders GROUP BY order_date) d
ORDER BY order_date;

/* Q33. */
WITH region_days AS (
    SELECT r.region_id, gs.d AS order_date
    FROM core.dim_region r
    CROSS JOIN generate_series(
        (SELECT MIN(order_date) FROM sales.orders),
        (SELECT MAX(order_date) FROM sales.orders),
        INTERVAL '1 day'
    ) AS gs(d)
),
region_daily AS (
    SELECT s.region_id, o.order_date, SUM(o.net_total) AS daily_revenue
    FROM sales.orders o
    JOIN stores.stores s ON o.store_id = s.store_id
    GROUP BY s.region_id, o.order_date
)
SELECT rd.region_id, rd.order_date, COALESCE(dl.daily_revenue, 0) AS daily_revenue,
       SUM(COALESCE(dl.daily_revenue, 0)) OVER (PARTITION BY rd.region_id ORDER BY rd.order_date RANGE BETWEEN INTERVAL '89 days' PRECEDING AND CURRENT ROW) AS rolling_90day_revenue
FROM region_days rd
LEFT JOIN region_daily dl ON dl.region_id = rd.region_id AND dl.order_date = rd.order_date
ORDER BY rd.region_id, rd.order_date;

/* Q34. */
SELECT oi.order_item_id, oi.prod_id, o.order_date,
       (oi.net_amount - p.cost_price * oi.quantity) AS margin,
       AVG(oi.net_amount - p.cost_price * oi.quantity) OVER (PARTITION BY oi.prod_id ORDER BY o.order_date, oi.order_item_id ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) AS trailing_10_avg_margin,
       ((oi.net_amount - p.cost_price * oi.quantity) < AVG(oi.net_amount - p.cost_price * oi.quantity) OVER (PARTITION BY oi.prod_id ORDER BY o.order_date, oi.order_item_id ROWS BETWEEN 9 PRECEDING AND CURRENT ROW)) AS is_margin_drop
FROM sales.order_items oi
JOIN sales.orders o ON oi.order_id = o.order_id
JOIN products.products p ON oi.prod_id = p.product_id;

/* Q35. */
SELECT device_type, view_date, daily_views,
       AVG(daily_views) OVER (PARTITION BY device_type ORDER BY view_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7day
FROM (SELECT device_type, view_timestamp::date AS view_date, COUNT(*) AS daily_views FROM web_events.page_views GROUP BY device_type, view_timestamp::date) d
ORDER BY device_type, view_date;

/* Q36. */
SELECT dept_id, month, monthly_net_salary,
       AVG(monthly_net_salary) OVER (PARTITION BY dept_id ORDER BY month ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS rolling_6mo_avg
FROM (
    SELECT e.dept_id, DATE_TRUNC('month', ps.payment_date) AS month, SUM(ps.net_salary) AS monthly_net_salary
    FROM payroll.pay_slips ps
    JOIN stores.employees e ON ps.employee_id = e.employee_id
    GROUP BY e.dept_id, DATE_TRUNC('month', ps.payment_date)
) t
ORDER BY dept_id, month;

/* Q37. */
SELECT order_date, daily_revenue,
       SUM(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_revenue,
       SUM(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS trailing_30day_sum
FROM (SELECT order_date, SUM(net_total) AS daily_revenue FROM sales.orders GROUP BY order_date) d
ORDER BY order_date;

/* Q38. */
SELECT category, created_day, daily_tickets,
       SUM(daily_tickets) OVER (PARTITION BY category ORDER BY created_day ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) AS rolling_14day_volume,
       AVG(daily_tickets) OVER (PARTITION BY category ORDER BY created_day ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) AS moving_avg_14day
FROM (SELECT category, created_date::date AS created_day, COUNT(*) AS daily_tickets FROM support.tickets GROUP BY category, created_date::date) t
ORDER BY category, created_day;

/* Q39. */
WITH order_basket AS (
    SELECT o.order_id, o.cust_id, o.order_date, SUM(oi.quantity) AS basket_size
    FROM sales.orders o
    JOIN sales.order_items oi ON oi.order_id = o.order_id
    GROUP BY o.order_id, o.cust_id, o.order_date
)
SELECT order_id, cust_id, order_date, basket_size,
       AVG(basket_size) OVER (PARTITION BY cust_id ORDER BY order_date, order_id ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) AS trailing_5_avg_basket_size
FROM order_basket;

/* Q40. */
SELECT d.order_date,
       (SELECT COUNT(DISTINCT o2.cust_id) FROM sales.orders o2
        WHERE o2.order_date BETWEEN d.order_date - INTERVAL '6 days' AND d.order_date) AS rolling_weekly_active_customers
FROM (SELECT DISTINCT order_date FROM sales.orders) d
ORDER BY d.order_date;

/* Q41. */
SELECT review_id, product_id, review_date, rating,
       AVG(rating) OVER (PARTITION BY product_id ORDER BY review_date, review_id ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) AS moving_avg_10review
FROM customers.reviews;

/* Q42. */
SELECT o.cust_id, r.return_date, r.refund_amount,
       SUM(r.refund_amount) OVER (PARTITION BY o.cust_id ORDER BY r.return_date RANGE BETWEEN INTERVAL '29 days' PRECEDING AND CURRENT ROW) AS rolling_30day_refund_total
FROM sales.returns r
JOIN sales.orders o ON r.order_id = o.order_id
ORDER BY o.cust_id, r.return_date;

/* Q43. */
WITH cats AS (SELECT category_id FROM core.dim_category),
months AS (
    SELECT generate_series(
        DATE_TRUNC('month', (SELECT MIN(order_date) FROM sales.orders)),
        DATE_TRUNC('month', (SELECT MAX(order_date) FROM sales.orders)),
        INTERVAL '1 month'
    ) AS month
),
cat_months AS (SELECT c.category_id, m.month FROM cats c CROSS JOIN months m),
cat_rev AS (
    SELECT b.category_id, DATE_TRUNC('month', o.order_date) AS month, SUM(oi.net_amount) AS monthly_revenue
    FROM sales.order_items oi
    JOIN sales.orders o ON oi.order_id = o.order_id
    JOIN products.products p ON oi.prod_id = p.product_id
    JOIN core.dim_brand b ON p.brand_id = b.brand_id
    GROUP BY b.category_id, DATE_TRUNC('month', o.order_date)
)
SELECT cm.category_id, cm.month, COALESCE(cr.monthly_revenue, 0) AS monthly_revenue,
       AVG(COALESCE(cr.monthly_revenue, 0)) OVER (PARTITION BY cm.category_id ORDER BY cm.month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS moving_avg_3mo
FROM cat_months cm
LEFT JOIN cat_rev cr ON cr.category_id = cm.category_id AND cr.month = cm.month
ORDER BY cm.category_id, cm.month;

/* Q44. */
SELECT prod_id, order_date, daily_units,
       SUM(daily_units) OVER (PARTITION BY prod_id ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS trailing_7day_units
FROM (SELECT oi.prod_id, o.order_date, SUM(oi.quantity) AS daily_units FROM sales.order_items oi JOIN sales.orders o ON oi.order_id = o.order_id GROUP BY oi.prod_id, o.order_date) t
ORDER BY prod_id, order_date;

/* Q45. */
SELECT region_id, week, weekly_signups,
       AVG(weekly_signups) OVER (PARTITION BY region_id ORDER BY week ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS moving_avg_4week
FROM (
    SELECT r.region_id, DATE_TRUNC('week', c.registration_date) AS week, COUNT(DISTINCT c.customer_id) AS weekly_signups
    FROM customers.customers c
    JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = true
    JOIN core.dim_region r ON r.state = a.state
    GROUP BY r.region_id, DATE_TRUNC('week', c.registration_date)
) t
ORDER BY region_id, week;

/* Q46. */
SELECT call_id, agent_id, call_start_time, call_duration_seconds,
       AVG(call_duration_seconds) OVER (PARTITION BY agent_id ORDER BY call_start_time, call_id ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) AS trailing_20_avg_duration,
       (call_duration_seconds > AVG(call_duration_seconds) OVER (PARTITION BY agent_id ORDER BY call_start_time, call_id ROWS BETWEEN 19 PRECEDING AND CURRENT ROW)) AS above_trailing_avg_flag
FROM call_center.calls;

/* Q47. */
SELECT order_date, daily_gmv,
       SUM(daily_gmv) OVER (ORDER BY order_date RANGE BETWEEN INTERVAL '89 days' PRECEDING AND CURRENT ROW) AS rolling_90day_gmv,
       AVG(daily_gmv) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS smoothed_7day
FROM (SELECT order_date, SUM(gross_total) AS daily_gmv FROM sales.orders GROUP BY order_date) d
ORDER BY order_date;

/* Q48. */
SELECT order_id, cust_id, order_date, net_total,
       AVG(net_total) OVER (PARTITION BY cust_id ORDER BY order_date, order_id ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS peer_avg_excl_current
FROM sales.orders;

/* Q49. */
SELECT store_id, month, monthly_revenue,
       SUM(monthly_revenue) OVER (PARTITION BY store_id ORDER BY month ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS ttm_revenue
FROM (SELECT store_id, DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_revenue FROM sales.orders GROUP BY store_id, DATE_TRUNC('month', order_date)) m
ORDER BY store_id, month;

/* Q50. */
SELECT order_date, daily_revenue,
       AVG(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7day,
       AVG(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS moving_avg_30day
FROM (SELECT order_date, SUM(net_total) AS daily_revenue FROM sales.orders GROUP BY order_date) d
ORDER BY order_date;

/* ============================================================
   SECTION C: FIRST_VALUE / LAST_VALUE / NTH_VALUE (25)
   ------------------------------------------------------------ */
/* Q51. */
SELECT order_id, cust_id, order_date, net_total,
       FIRST_VALUE(net_total) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS first_order_value
FROM sales.orders;

/* Q52. */
SELECT order_id, cust_id, order_date, net_total,
       LAST_VALUE(net_total) OVER (PARTITION BY cust_id ORDER BY order_date, order_id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_order_value
FROM sales.orders;

/* Q53. */
SELECT order_id, cust_id, order_date, net_total,
       FIRST_VALUE(net_total) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS first_order_value,
       ROUND(net_total / NULLIF(FIRST_VALUE(net_total) OVER (PARTITION BY cust_id ORDER BY order_date, order_id), 0), 4) AS ratio_to_first_order
FROM sales.orders;

/* Q54. */
SELECT review_id, product_id, review_date, rating,
       FIRST_VALUE(rating) OVER (PARTITION BY product_id ORDER BY review_date, review_id) AS first_rating,
       LAST_VALUE(rating) OVER (PARTITION BY product_id ORDER BY review_date, review_id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_rating
FROM customers.reviews;

/* Q55. */
SELECT order_id, cust_id, order_date, net_total,
       NTH_VALUE(net_total, 2) OVER (PARTITION BY cust_id ORDER BY order_date, order_id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS second_order_value
FROM sales.orders;

/* Q56. */
SELECT product_id, brand_id, price,
       FIRST_VALUE(price) OVER (PARTITION BY brand_id ORDER BY price ASC, product_id) AS brand_cheapest_price
FROM products.products;

/* Q57. */
SELECT employee_id, dept_id, salary,
       FIRST_VALUE(salary) OVER (PARTITION BY dept_id ORDER BY salary DESC, employee_id) AS dept_top_salary
FROM stores.employees;

/* Q58. */
SELECT order_id, store_id, order_date, net_total,
       FIRST_VALUE(net_total) OVER (PARTITION BY store_id ORDER BY order_date, order_id) AS first_order_value,
       SUM(net_total) OVER (PARTITION BY store_id ORDER BY order_date, order_id) AS running_cumulative_revenue
FROM sales.orders;

/* Q59. */
SELECT year, month, monthly_revenue,
       ROUND(100.0 * monthly_revenue / FIRST_VALUE(monthly_revenue) OVER (PARTITION BY year ORDER BY month), 2) AS index_to_first_month
FROM (SELECT EXTRACT(YEAR FROM order_date) AS year, DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_revenue FROM sales.orders GROUP BY 1, 2) m
ORDER BY year, month;

/* Q60. */
SELECT shipment_id, courier_name, shipped_date, delivered_date,
       LAST_VALUE(delivered_date) OVER (PARTITION BY courier_name ORDER BY shipped_date, shipment_id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS courier_last_delivered_date
FROM sales.shipments;

/* Q61. */
SELECT call_id, agent_id, call_duration_seconds,
       FIRST_VALUE(call_duration_seconds) OVER (PARTITION BY agent_id ORDER BY call_duration_seconds DESC, call_id) AS agent_longest_call
FROM call_center.calls;

/* Q62. */
SELECT order_id, cust_id, order_date,
       FIRST_VALUE(order_date) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS first_purchase_date
FROM sales.orders;

/* Q63. */
SELECT order_id, store_id, net_total,
       FIRST_VALUE(net_total) OVER (PARTITION BY store_id ORDER BY net_total DESC, order_id) AS store_max_order_value
FROM sales.orders;

/* Q64. */
SELECT order_date, daily_revenue,
       MAX(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_max,
       ROUND(100.0 * daily_revenue / MAX(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2) AS pct_to_peak
FROM (SELECT order_date, SUM(net_total) AS daily_revenue FROM sales.orders GROUP BY order_date) d
ORDER BY order_date;

/* Q65. */
SELECT product_id, supplier_id, price,
       FIRST_VALUE(price) OVER (PARTITION BY supplier_id ORDER BY price DESC, product_id) AS supplier_max_price
FROM products.products;

/* Q66. */
SELECT warehouse_id, product_id, snapshot_date, quantity_on_hand,
       FIRST_VALUE(quantity_on_hand) OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date) AS first_snapshot_qty,
       LAST_VALUE(quantity_on_hand) OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_snapshot_qty
FROM supply_chain.inventory_snapshots;

/* Q67. */
SELECT campaign_id, platform, campaign_spend,
       FIRST_VALUE(campaign_spend) OVER (PARTITION BY platform ORDER BY campaign_spend DESC, campaign_id) AS platform_biggest_campaign_spend
FROM (SELECT campaign_id, platform, SUM(amount) AS campaign_spend FROM marketing.ads_spend GROUP BY campaign_id, platform) t;

/* Q68. */
SELECT order_id, cust_id, net_total,
       NTH_VALUE(net_total, 3) OVER (PARTITION BY cust_id ORDER BY net_total DESC, order_id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS third_highest_order_value
FROM sales.orders;

/* Q69. */
SELECT region_id, month, monthly_revenue,
       FIRST_VALUE(monthly_revenue) OVER (PARTITION BY region_id ORDER BY monthly_revenue DESC, month) AS region_best_month_revenue
FROM (
    SELECT s.region_id, DATE_TRUNC('month', o.order_date) AS month, SUM(o.net_total) AS monthly_revenue
    FROM sales.orders o
    JOIN stores.stores s ON o.store_id = s.store_id
    GROUP BY s.region_id, DATE_TRUNC('month', o.order_date)
) t;

/* Q70. */
SELECT customer_id, tier, tier_updated_at,
       FIRST_VALUE(tier) OVER (PARTITION BY customer_id ORDER BY tier_updated_at) AS first_recorded_tier,
       LAST_VALUE(tier) OVER (PARTITION BY customer_id ORDER BY tier_updated_at ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS latest_tier
FROM customers.customers;

/* Q71. */
SELECT pay_slip_id, employee_id, payment_date, net_salary,
       FIRST_VALUE(net_salary) OVER (PARTITION BY employee_id ORDER BY payment_date, pay_slip_id) AS first_recorded_net_salary
FROM payroll.pay_slips;

/* Q72. */
SELECT p.product_id, p.brand_id, pu.units,
       FIRST_VALUE(pu.units) OVER (PARTITION BY p.brand_id ORDER BY pu.units DESC, p.product_id) AS brand_bestseller_units
FROM products.products p
JOIN (SELECT prod_id, SUM(quantity) AS units FROM sales.order_items GROUP BY prod_id) pu
  ON pu.prod_id = p.product_id;

/* Q73. */
SELECT order_id, cust_id, order_date, net_total,
       FIRST_VALUE(net_total) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS first_order_value,
       LAST_VALUE(net_total) OVER (PARTITION BY cust_id ORDER BY order_date, order_id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_order_value
FROM sales.orders;

/* Q74. */
SELECT s.store_id, s.region_id, sr.total_revenue,
       FIRST_VALUE(sr.total_revenue) OVER (PARTITION BY s.region_id ORDER BY sr.total_revenue DESC, s.store_id) AS region_top_store_revenue
FROM stores.stores s
JOIN (SELECT store_id, SUM(net_total) AS total_revenue FROM sales.orders GROUP BY store_id) sr
  ON sr.store_id = s.store_id;

/* Q75. */
SELECT order_id, cust_id, order_date, net_total,
       FIRST_VALUE(net_total) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS first_value,
       LAST_VALUE(net_total) OVER (PARTITION BY cust_id ORDER BY order_date, order_id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_value,
       LAST_VALUE(net_total) OVER (PARTITION BY cust_id ORDER BY order_date, order_id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
         - FIRST_VALUE(net_total) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS span
FROM sales.orders;

/* ============================================================
   SECTION D: SHARE / RESET / REPORTS (25)
   ------------------------------------------------------------ */
/* Q76. */
SELECT region_id, year, month, monthly_revenue,
       SUM(monthly_revenue) OVER (PARTITION BY region_id, year ORDER BY month) AS ytd_revenue,
       ROUND(100.0 * SUM(monthly_revenue) OVER (PARTITION BY region_id, year ORDER BY month) / SUM(monthly_revenue) OVER (PARTITION BY region_id, year), 2) AS pct_of_year
FROM (
    SELECT s.region_id, EXTRACT(YEAR FROM o.order_date) AS year, DATE_TRUNC('month', o.order_date) AS month, SUM(o.net_total) AS monthly_revenue
    FROM sales.orders o
    JOIN stores.stores s ON o.store_id = s.store_id
    GROUP BY s.region_id, EXTRACT(YEAR FROM o.order_date), DATE_TRUNC('month', o.order_date)
) t
ORDER BY region_id, year, month;

/* Q77. */
WITH cust_rev AS (SELECT cust_id, SUM(net_total) AS revenue FROM sales.orders GROUP BY cust_id),
cum AS (
    SELECT cust_id, revenue,
           SUM(revenue) OVER (ORDER BY revenue DESC, cust_id) AS cum_revenue,
           SUM(revenue) OVER () AS total_revenue,
           COUNT(*) OVER (ORDER BY revenue DESC, cust_id) AS cum_count,
           COUNT(*) OVER () AS total_count
    FROM cust_rev
)
SELECT cust_id, revenue, ROUND(100.0 * cum_revenue / total_revenue, 2) AS cumulative_pct,
       (cum_count <= 0.2 * total_count) AS in_top_20pct_customers
FROM cum
ORDER BY revenue DESC;

/* Q78. */
WITH prod_units AS (
    SELECT b.category_id, p.product_id, SUM(oi.quantity) AS units
    FROM sales.order_items oi
    JOIN products.products p ON oi.prod_id = p.product_id
    JOIN core.dim_brand b ON p.brand_id = b.brand_id
    GROUP BY b.category_id, p.product_id
),
cum AS (
    SELECT category_id, product_id, units,
           SUM(units) OVER (PARTITION BY category_id ORDER BY units DESC, product_id) AS cum_units,
           SUM(units) OVER (PARTITION BY category_id) AS category_total
    FROM prod_units
)
SELECT category_id, product_id, units,
       ROUND(100.0 * cum_units / category_total, 2) AS cumulative_pct,
       CASE WHEN cum_units <= 0.8 * category_total THEN 'A'
            WHEN cum_units <= 0.95 * category_total THEN 'B'
            ELSE 'C' END AS abc_class
FROM cum
ORDER BY category_id, units DESC;

/* Q79. */
SELECT order_id, cust_id, store_id, net_total,
       ROUND(100.0 * net_total / SUM(net_total) OVER (PARTITION BY cust_id), 2) AS pct_of_customer_spend,
       ROUND(100.0 * net_total / SUM(net_total) OVER (PARTITION BY store_id), 2) AS pct_of_store_revenue
FROM sales.orders;

/* Q80. */
SELECT store_id, year, month, monthly_revenue,
       SUM(monthly_revenue) OVER (PARTITION BY store_id, year ORDER BY month) AS ytd_running_total,
       ROUND(100.0 * SUM(monthly_revenue) OVER (PARTITION BY store_id, year ORDER BY month) / SUM(monthly_revenue) OVER (PARTITION BY store_id, year), 2) AS pct_of_year
FROM (SELECT store_id, EXTRACT(YEAR FROM order_date) AS year, DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_revenue FROM sales.orders GROUP BY store_id, EXTRACT(YEAR FROM order_date), DATE_TRUNC('month', order_date)) t
ORDER BY store_id, year, month;

/* Q81. */
SELECT category_id, month, monthly_revenue,
       ROUND(100.0 * monthly_revenue / SUM(monthly_revenue) OVER (PARTITION BY month), 2) AS pct_of_company_month
FROM (
    SELECT b.category_id, DATE_TRUNC('month', o.order_date) AS month, SUM(oi.net_amount) AS monthly_revenue
    FROM sales.order_items oi
    JOIN sales.orders o ON oi.order_id = o.order_id
    JOIN products.products p ON oi.prod_id = p.product_id
    JOIN core.dim_brand b ON p.brand_id = b.brand_id
    GROUP BY b.category_id, DATE_TRUNC('month', o.order_date)
) t
ORDER BY month, category_id;

/* Q82. */
SELECT order_id, store_id, order_date, DATE_TRUNC('month', order_date) AS month, net_total,
       SUM(net_total) OVER (PARTITION BY store_id, DATE_TRUNC('month', order_date) ORDER BY order_date, order_id) AS mtd_revenue,
       SUM(net_total) OVER (PARTITION BY store_id, DATE_TRUNC('month', order_date)) AS full_month_revenue
FROM sales.orders;

/* Q83. */
SELECT employee_id, dept_id, salary,
       ROUND(100.0 * salary / SUM(salary) OVER (PARTITION BY dept_id), 2) AS pct_share_of_dept_payroll
FROM stores.employees;

/* Q84. */
SELECT order_date, daily_revenue,
       SUM(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS trailing_7day_revenue,
       SUM(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS trailing_30day_revenue,
       ROUND(100.0 * SUM(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)
                    / NULLIF(SUM(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW), 0), 2) AS pct_of_trailing_30day
FROM (SELECT order_date, SUM(net_total) AS daily_revenue FROM sales.orders GROUP BY order_date) d
ORDER BY order_date;

/* Q85. */
SELECT month, week, weekly_revenue,
       ROUND(100.0 * weekly_revenue / SUM(weekly_revenue) OVER (PARTITION BY month), 2) AS pct_of_month
FROM (SELECT DATE_TRUNC('month', order_date) AS month, DATE_TRUNC('week', order_date) AS week, SUM(net_total) AS weekly_revenue FROM sales.orders GROUP BY DATE_TRUNC('month', order_date), DATE_TRUNC('week', order_date)) t
ORDER BY month, week;

/* Q86. */
SELECT p.product_id, p.brand_id, o.order_date, oi.net_amount,
       SUM(oi.net_amount) OVER (PARTITION BY p.brand_id ORDER BY o.order_date, oi.order_item_id) AS brand_running_total,
       ROUND(100.0 * SUM(oi.net_amount) OVER (PARTITION BY p.product_id ORDER BY o.order_date, oi.order_item_id)
                    / NULLIF(SUM(oi.net_amount) OVER (PARTITION BY p.brand_id ORDER BY o.order_date, oi.order_item_id), 0), 2) AS product_running_share_of_brand
FROM sales.order_items oi
JOIN sales.orders o ON oi.order_id = o.order_id
JOIN products.products p ON oi.prod_id = p.product_id;

/* Q87. */
WITH monthly AS (
    SELECT cust_id, DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_spend
    FROM sales.orders
    GROUP BY cust_id, DATE_TRUNC('month', order_date)
),
cum AS (
    SELECT cust_id, month, SUM(monthly_spend) OVER (PARTITION BY cust_id ORDER BY month) AS cumulative_spend
    FROM monthly
)
SELECT cust_id, month, cumulative_spend,
       ROUND(100.0 * cumulative_spend / FIRST_VALUE(cumulative_spend) OVER (PARTITION BY cust_id ORDER BY month), 2) AS indexed_to_first_month
FROM cum
ORDER BY cust_id, month;

/* Q88. */
SELECT region_id, year, quarter, quarterly_revenue,
       ROUND(100.0 * quarterly_revenue / SUM(quarterly_revenue) OVER (PARTITION BY region_id, year), 2) AS pct_of_year
FROM (
    SELECT s.region_id, EXTRACT(YEAR FROM o.order_date) AS year, DATE_TRUNC('quarter', o.order_date) AS quarter, SUM(o.net_total) AS quarterly_revenue
    FROM sales.orders o
    JOIN stores.stores s ON o.store_id = s.store_id
    GROUP BY s.region_id, EXTRACT(YEAR FROM o.order_date), DATE_TRUNC('quarter', o.order_date)
) t
ORDER BY region_id, year, quarter;

/* Q89. */
SELECT month, monthly_revenue,
       AVG(monthly_revenue) OVER (ORDER BY month ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING) AS trailing_3mo_avg_excl_current,
       (monthly_revenue > 1.5 * AVG(monthly_revenue) OVER (ORDER BY month ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING)) AS is_anomaly
FROM (SELECT DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_revenue FROM sales.orders GROUP BY 1) m
ORDER BY month;

/* Q90. */
SELECT store_id, order_date, daily_revenue,
       SUM(daily_revenue) OVER (PARTITION BY store_id ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS trailing_7day_total,
       ROUND(100.0 * daily_revenue / NULLIF(SUM(daily_revenue) OVER (PARTITION BY store_id ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 0), 2) AS pct_of_trailing_7day
FROM (SELECT store_id, order_date, SUM(net_total) AS daily_revenue FROM sales.orders GROUP BY store_id, order_date) d
ORDER BY store_id, order_date;

/* Q91. */
WITH all_events AS (
    SELECT cust_id, order_date AS event_date, net_total AS amount, 'order' AS event_type
    FROM sales.orders
    UNION ALL
    SELECT o.cust_id, r.return_date AS event_date, r.refund_amount AS amount, 'return' AS event_type
    FROM sales.returns r
    JOIN sales.orders o ON r.order_id = o.order_id
),
running AS (
    SELECT cust_id, event_date, event_type,
           SUM(CASE WHEN event_type = 'order' THEN amount ELSE 0 END) OVER (PARTITION BY cust_id ORDER BY event_date, event_type) AS cum_revenue,
           SUM(CASE WHEN event_type = 'return' THEN amount ELSE 0 END) OVER (PARTITION BY cust_id ORDER BY event_date, event_type) AS cum_refunds
    FROM all_events
)
SELECT cust_id, event_date, cum_refunds, cum_revenue,
       ROUND(100.0 * cum_refunds / NULLIF(cum_revenue, 0), 2) AS pct_refunds_of_revenue
FROM running
WHERE event_type = 'return'
ORDER BY cust_id, event_date;

/* Q92. */
SELECT agent_id, created_day, daily_resolved,
       SUM(daily_resolved) OVER (PARTITION BY agent_id ORDER BY created_day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS trailing_week_total,
       ROUND(100.0 * daily_resolved / NULLIF(SUM(daily_resolved) OVER (PARTITION BY agent_id ORDER BY created_day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 0), 2) AS pct_of_trailing_week
FROM (SELECT agent_id, created_date::date AS created_day, COUNT(*) AS daily_resolved FROM support.tickets WHERE status = 'Resolved' GROUP BY agent_id, created_date::date) t
ORDER BY agent_id, created_day;

/* Q93. */
SELECT order_id, store_id, DATE_TRUNC('quarter', order_date) AS quarter, order_date, gross_total,
       SUM(gross_total) OVER (PARTITION BY store_id, DATE_TRUNC('quarter', order_date) ORDER BY order_date, order_id) AS qtd_gmv,
       ROUND(100.0 * SUM(gross_total) OVER (PARTITION BY store_id, DATE_TRUNC('quarter', order_date) ORDER BY order_date, order_id)
                    / SUM(gross_total) OVER (PARTITION BY store_id, DATE_TRUNC('quarter', order_date)), 2) AS pct_of_quarter
FROM sales.orders;

/* Q94. */
WITH prod_units AS (
    SELECT b.category_id, p.product_id, SUM(oi.quantity) AS units
    FROM sales.order_items oi
    JOIN products.products p ON oi.prod_id = p.product_id
    JOIN core.dim_brand b ON p.brand_id = b.brand_id
    GROUP BY b.category_id, p.product_id
),
ranked AS (
    SELECT category_id, product_id, units,
           COUNT(*) OVER (PARTITION BY category_id ORDER BY units DESC, product_id) AS cum_count,
           COUNT(*) OVER (PARTITION BY category_id) AS total_count
    FROM prod_units
)
SELECT category_id, product_id, units
FROM ranked
WHERE cum_count <= 0.2 * total_count
ORDER BY category_id, units DESC;

/* Q95. */
SELECT campaign_id, platform, spend_date, amount,
       SUM(amount) OVER (PARTITION BY platform ORDER BY spend_date, spend_id) AS platform_running_spend,
       ROUND(100.0 * SUM(amount) OVER (PARTITION BY campaign_id ORDER BY spend_date, spend_id)
                    / NULLIF(SUM(amount) OVER (PARTITION BY platform ORDER BY spend_date, spend_id), 0), 2) AS pct_of_platform_running
FROM marketing.ads_spend
ORDER BY platform, spend_date;

/* Q96. */
SELECT year, month, monthly_revenue,
       SUM(monthly_revenue) OVER (PARTITION BY year ORDER BY month) AS ytd_total,
       ROUND(100.0 * SUM(monthly_revenue) OVER (PARTITION BY year ORDER BY month) / SUM(monthly_revenue) OVER (PARTITION BY year), 2) AS pct_of_year
FROM (SELECT EXTRACT(YEAR FROM order_date) AS year, DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_revenue FROM sales.orders GROUP BY 1, 2) m
ORDER BY year, month;

/* Q97. */
SELECT order_id, cust_id, order_date, net_total,
       SUM(net_total) OVER (PARTITION BY cust_id ORDER BY order_date RANGE BETWEEN INTERVAL '89 days' PRECEDING AND CURRENT ROW) AS trailing_90day_spend,
       ROUND(100.0 * net_total / NULLIF(SUM(net_total) OVER (PARTITION BY cust_id ORDER BY order_date RANGE BETWEEN INTERVAL '89 days' PRECEDING AND CURRENT ROW), 0), 2) AS pct_of_trailing_90day
FROM sales.orders
ORDER BY cust_id, order_date;

/* Q98. */
WITH region_rev AS (
    SELECT s.region_id, SUM(o.net_total) AS revenue
    FROM sales.orders o
    JOIN stores.stores s ON o.store_id = s.store_id
    GROUP BY s.region_id
)
SELECT region_id, revenue,
       SUM(revenue) OVER (ORDER BY revenue DESC, region_id) AS cumulative_revenue,
       ROUND(100.0 * SUM(revenue) OVER (ORDER BY revenue DESC, region_id) / SUM(revenue) OVER (), 2) AS cumulative_pct
FROM region_rev
ORDER BY revenue DESC;

/* Q99. */
SELECT w.warehouse_id, w.region, snap.total_qty,
       ROUND(100.0 * snap.total_qty / SUM(snap.total_qty) OVER (PARTITION BY w.region), 2) AS pct_of_region_stock,
       ROUND(100.0 * snap.total_qty / SUM(snap.total_qty) OVER (), 2) AS pct_of_company_stock
FROM supply_chain.warehouses w
JOIN (SELECT warehouse_id, SUM(quantity_on_hand) AS total_qty FROM supply_chain.inventory_snapshots GROUP BY warehouse_id) snap
  ON snap.warehouse_id = w.warehouse_id;

/* Q100. */
SELECT region_id, year, month, monthly_revenue,
       SUM(monthly_revenue) OVER (PARTITION BY region_id, year ORDER BY month) AS ytd_revenue,
       ROUND(100.0 * SUM(monthly_revenue) OVER (PARTITION BY region_id, year ORDER BY month) / SUM(monthly_revenue) OVER (PARTITION BY region_id, year), 2) AS pct_of_year,
       AVG(monthly_revenue) OVER (PARTITION BY region_id ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS moving_avg_3mo
FROM (
    SELECT s.region_id, EXTRACT(YEAR FROM o.order_date) AS year, DATE_TRUNC('month', o.order_date) AS month, SUM(o.net_total) AS monthly_revenue
    FROM sales.orders o
    JOIN stores.stores s ON o.store_id = s.store_id
    GROUP BY s.region_id, EXTRACT(YEAR FROM o.order_date), DATE_TRUNC('month', o.order_date)
) t
ORDER BY region_id, year, month;

/* ============================================================
   END OF ANSWER KEY - Window Functions Part 2 - HARD LEVEL (100/100)
============================================================ */
