/* ============================================================
   ANSWER KEY - Window Functions Part 2: Aggregation & Frames (CRAZY LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1. Compute three window aggregates over the same gap-filled daily series in one SELECT: SUM/AVG with ROWS BETWEEN 6 PRECEDING for 7-day, ROWS BETWEEN 29 PRECEDING for 30-day, and SUM() PARTITION BY year ORDER BY date for YTD - each independent, applied to the same pre-aggregated, gap-filled row set. */
/* Q2. RANGE groups tied ORDER BY values into one peer step; ROWS counts strict physical row position; GROUPS counts distinct peer values as units - RANGE suits real date-based windows, ROWS suits exact row counts, GROUPS suits "N distinct periods back" even with an uneven number of rows per period. */
/* Q3. Because a fact table skips periods with no activity entirely, so a rolling window's row count would span an unpredictable number of actual calendar days; build the date spine with generate_series and LEFT JOIN the real data onto it (COALESCE to 0) before applying any window frame. */
/* Q4. Use ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING so LAST_VALUE/NTH_VALUE-from-the-end genuinely spans the whole partition, instead of stopping at the current row under the default ORDER BY frame. */
/* Q5. Windows can't do COUNT(DISTINCT) directly; approximate cheaply by summing per-period distinct counts (an overestimate that double-counts repeats), or solve exactly via a correlated subquery/LATERAL join recomputing COUNT(DISTINCT x) per row at higher cost. */
/* Q6. Compute PERCENTILE_CONT(0.5) inside a LATERAL subquery correlated to each row's window range, since there is no windowed median function - this runs the percentile calculation once per output row, so cost grows with row count times window size. */
/* Q7. Large literal RANGE INTERVAL frames can force repeated re-scans of a growing row set; mitigate by pre-aggregating to a coarser grain, using ROWS instead of RANGE where duplicate ORDER BY values aren't a concern, or precomputing rolling sums in a materialized view. */
/* Q8. Include separate SUM() OVER (PARTITION BY ...) calls for each grain (line, order, customer, grand total) in the same SELECT, each row dividing its value by the matching denominator computed at that partition level. */
/* Q9. Define the reset boundary as a derived, deterministic column (e.g. DATE_TRUNC('month', d)) and always order by a stable, unique tiebreaker so the same input reproduces the same cumulative sequence across refreshes. */
/* Q10. Compute (value - trailing_moving_avg) / trailing_stddev using AVG() and STDDEV() over the same ROWS BETWEEN frame, then flag rows where the absolute z-score exceeds a chosen threshold (e.g. 2 or 3). */
/* Q11. FILTER (WHERE ...) is only valid on aggregate function calls, not window function calls, in PostgreSQL; the alternative is to wrap the aggregate's input expression in CASE WHEN condition THEN value ELSE NULL END, since AVG/SUM already skip NULLs. */
/* Q12. Sort ascending by contribution rank, compute a running SUM() OVER (ORDER BY ...) and divide by the grand total via SUM() OVER () for cumulative share, then classify with CASE WHEN cumulative_share <= 0.8 THEN 'A' ... to mark A/B/C cut-points. */
/* Q13. Use nested CTEs: an inner CTE aggregates raw facts to the target grain with GROUP BY, and an outer CTE/SELECT applies window functions over that already-aggregated result - keeping each layer's grain explicit and easy to reason about. */
/* Q14. A centered MA smooths using both past and future values, so it looks smoother in hindsight but can't be computed live and shifts apparent turning points earlier; a trailing MA is usable in real time but lags real turning points - forecasting inputs typically need trailing-only data. */
/* Q15. Use a frame like ROWS BETWEEN N PRECEDING AND 1 PRECEDING, ending before the current row, so a row is never compared against a "peer average" that includes its own value. */
/* Q16. Divide every row's value by FIRST_VALUE(value) OVER (PARTITION BY g ORDER BY d) and multiply by 100; this is cheap at scale because FIRST_VALUE with the default ordered frame is effectively O(1) per row, needing no full frame re-scan. */
/* Q17. Compute a running MAX() OVER (ORDER BY d ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as the running peak-to-date, and divide the current value by it to see how far the metric has fallen from its all-time high (drawdown). */
/* Q18. Aggregate revenue to monthly grain, then apply ROWS BETWEEN 11 PRECEDING AND CURRENT ROW on the ordered monthly series to get a trailing-twelve-month sum recomputed on every month's row. */
/* Q19. Duplicate ORDER BY key values make RANGE treat all tied rows as a single peer step, inflating the frame's effective row count unpredictably at those points; ROWS instead uses strict physical row position regardless of value ties, giving a deterministic, reproducible frame size. */
/* Q20. Use GROUPING SETS (or a UNION ALL of a detail query, a subtotal query, and a grand-total query) so one result set carries detail rows plus subtotal rows plus a grand-total row, distinguished by a grouping indicator or NULL markers. */
/* Q21. Aggregate to (customer, month) grain with an "active that month" flag, then compare each customer's month number since their first active month using date-difference arithmetic on the month column to see whether they show up in month N. */
/* Q22. Pre-aggregate to a date spine per partition using generate_series CROSS JOIN partition keys with a LEFT JOIN to real facts (COALESCE to 0), so every partition has the same dense, gap-free date range before any frame is applied - otherwise sparse partitions get inconsistent-length windows. */
/* Q23. Materialize the gap-filled date spine plus joined facts into a CTE (or a temp table/materialized view) once, then run all window functions against that pre-built result instead of recomputing the generate_series/join logic on every pass. */
/* Q24. Order rows by the reporting dimension (region, month, etc), compute a running SUM() OVER (ORDER BY ...) as the cumulative contribution alongside each row's own share - the ordering is typically by descending individual contribution or a fixed business sequence. */
/* Q25. Push windowing to a materialized view (Day 25) when the same rolling/YTD metrics are queried repeatedly by many dashboards and can tolerate a refresh lag; compute on the fly when data must be real-time or the query runs too rarely to justify a refresh pipeline. */

/* ============================================================
   SECTION B: MULTI-FRAME ROLLING KPIs (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT gs.d AS order_date, COALESCE(r.daily_revenue, 0) AS daily_revenue,
       AVG(COALESCE(r.daily_revenue, 0)) OVER (ORDER BY gs.d ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7day,
       AVG(COALESCE(r.daily_revenue, 0)) OVER (ORDER BY gs.d ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS moving_avg_30day,
       SUM(COALESCE(r.daily_revenue, 0)) OVER (PARTITION BY EXTRACT(YEAR FROM gs.d) ORDER BY gs.d) AS ytd_revenue
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
       SUM(daily_revenue) OVER (PARTITION BY store_id ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS sum_7day,
       SUM(daily_revenue) OVER (PARTITION BY store_id ORDER BY order_date ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) AS sum_28day,
       SUM(daily_revenue) OVER (PARTITION BY store_id ORDER BY order_date ROWS BETWEEN 89 PRECEDING AND CURRENT ROW) AS sum_90day
FROM (SELECT store_id, order_date, SUM(net_total) AS daily_revenue FROM sales.orders GROUP BY store_id, order_date) d
ORDER BY store_id, order_date;

/* Q28. */
WITH cust_days AS (
    SELECT DISTINCT cust_id, order_date FROM sales.orders
),
daily_7 AS (
    SELECT order_date + off AS active_date, COUNT(DISTINCT cust_id) AS active_customers_7day
    FROM cust_days, LATERAL generate_series(0, 6) AS off
    GROUP BY order_date + off
),
daily_30 AS (
    SELECT order_date + off AS active_date, COUNT(DISTINCT cust_id) AS active_customers_30day
    FROM cust_days, LATERAL generate_series(0, 29) AS off
    GROUP BY order_date + off
)
SELECT d7.active_date AS order_date, d7.active_customers_7day, d30.active_customers_30day
FROM daily_7 d7
JOIN daily_30 d30 ON d30.active_date = d7.active_date
ORDER BY d7.active_date;

/* Q29. */
SELECT region_id, month, monthly_revenue,
       SUM(monthly_revenue) OVER (PARTITION BY region_id ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS trailing_3mo,
       SUM(monthly_revenue) OVER (PARTITION BY region_id ORDER BY month ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS trailing_12mo
FROM (SELECT s.region_id, DATE_TRUNC('month', o.order_date) AS month, SUM(o.net_total) AS monthly_revenue FROM sales.orders o JOIN stores.stores s ON o.store_id = s.store_id GROUP BY s.region_id, DATE_TRUNC('month', o.order_date)) t
ORDER BY region_id, month;

/* Q30. */
SELECT order_date, daily_order_count,
       AVG(daily_order_count) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7day,
       (daily_order_count > 2 * AVG(daily_order_count) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)) AS is_spike
FROM (SELECT order_date, COUNT(*) AS daily_order_count FROM sales.orders GROUP BY order_date) d
ORDER BY order_date;

/* Q31. */
SELECT order_date, daily_gmv,
       SUM(daily_gmv) OVER (ORDER BY order_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS rolling_30day_gmv,
       SUM(daily_gmv) OVER (ORDER BY order_date ROWS BETWEEN 89 PRECEDING AND CURRENT ROW) AS rolling_90day_gmv,
       ROUND(100.0 * SUM(daily_gmv) OVER (ORDER BY order_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW)
                    / NULLIF(SUM(daily_gmv) OVER (ORDER BY order_date ROWS BETWEEN 89 PRECEDING AND CURRENT ROW), 0), 2) AS pct_of_90day
FROM (SELECT order_date, SUM(gross_total) AS daily_gmv FROM sales.orders GROUP BY order_date) d
ORDER BY order_date;

/* Q32. */
SELECT prod_id, order_date, daily_units,
       AVG(daily_units) OVER (PARTITION BY prod_id ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS ma_7day,
       AVG(daily_units) OVER (PARTITION BY prod_id ORDER BY order_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS ma_30day
FROM (SELECT oi.prod_id, o.order_date, SUM(oi.quantity) AS daily_units FROM sales.order_items oi JOIN sales.orders o ON oi.order_id = o.order_id GROUP BY oi.prod_id, o.order_date) t
ORDER BY prod_id, order_date;

/* Q33. */
SELECT region_id, week, weekly_signups,
       AVG(weekly_signups) OVER (PARTITION BY region_id ORDER BY week ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS ma_4week,
       AVG(weekly_signups) OVER (PARTITION BY region_id ORDER BY week ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS ma_12week
FROM (
    SELECT r.region_id, DATE_TRUNC('week', c.registration_date) AS week, COUNT(DISTINCT c.customer_id) AS weekly_signups
    FROM customers.customers c
    JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = true
    JOIN core.dim_region r ON r.state = a.state
    GROUP BY r.region_id, DATE_TRUNC('week', c.registration_date)
) t
ORDER BY region_id, week;

/* Q34. */
SELECT shipment_id, courier_name, shipped_date, (delivered_date - shipped_date) AS delivery_days,
       AVG(delivered_date - shipped_date) OVER (PARTITION BY courier_name ORDER BY shipped_date, shipment_id ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) AS ma_20,
       AVG(delivered_date - shipped_date) OVER (PARTITION BY courier_name ORDER BY shipped_date, shipment_id ROWS BETWEEN 99 PRECEDING AND CURRENT ROW) AS ma_100
FROM sales.shipments;

/* Q35. */
SELECT agent_id, created_day, daily_resolved,
       SUM(daily_resolved) OVER (PARTITION BY agent_id ORDER BY created_day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS trailing_week,
       SUM(daily_resolved) OVER (PARTITION BY agent_id ORDER BY created_day ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS trailing_month
FROM (SELECT agent_id, created_date::date AS created_day, COUNT(*) AS daily_resolved FROM support.tickets WHERE status = 'Resolved' GROUP BY agent_id, created_date::date) t
ORDER BY agent_id, created_day;

/* Q36. */
SELECT return_date, daily_refunds,
       AVG(daily_refunds) OVER (ORDER BY return_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS ma_7day,
       (daily_refunds > 2 * AVG(daily_refunds) OVER (ORDER BY return_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)) AS is_spike
FROM (SELECT return_date, SUM(refund_amount) AS daily_refunds FROM sales.returns GROUP BY return_date) d
ORDER BY return_date;

/* Q37. */
WITH cats AS (SELECT category_id FROM core.dim_category),
days AS (
    SELECT generate_series(
        (SELECT MIN(order_date) FROM sales.orders),
        (SELECT MAX(order_date) FROM sales.orders),
        INTERVAL '1 day'
    ) AS d
),
cat_days AS (SELECT c.category_id, dd.d FROM cats c CROSS JOIN days dd),
cat_daily AS (
    SELECT b.category_id, o.order_date, SUM(oi.net_amount) AS daily_revenue
    FROM sales.order_items oi
    JOIN sales.orders o ON oi.order_id = o.order_id
    JOIN products.products p ON oi.prod_id = p.product_id
    JOIN core.dim_brand b ON p.brand_id = b.brand_id
    GROUP BY b.category_id, o.order_date
)
SELECT cd.category_id, cd.d AS order_date, COALESCE(cdl.daily_revenue, 0) AS daily_revenue,
       SUM(COALESCE(cdl.daily_revenue, 0)) OVER (PARTITION BY cd.category_id ORDER BY cd.d RANGE BETWEEN INTERVAL '89 days' PRECEDING AND CURRENT ROW) AS rolling_90day_revenue,
       AVG(COALESCE(cdl.daily_revenue, 0)) OVER (PARTITION BY cd.category_id ORDER BY cd.d ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS smoothed_7day
FROM cat_days cd
LEFT JOIN cat_daily cdl ON cdl.category_id = cd.category_id AND cdl.order_date = cd.d
ORDER BY cd.category_id, cd.d;

/* Q38. */
SELECT warehouse_id, snapshot_date, total_qty,
       AVG(total_qty) OVER (PARTITION BY warehouse_id ORDER BY snapshot_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS moving_avg_30day
FROM (SELECT warehouse_id, snapshot_date, SUM(quantity_on_hand) AS total_qty FROM supply_chain.inventory_snapshots GROUP BY warehouse_id, snapshot_date) t
ORDER BY warehouse_id, snapshot_date;

/* Q39. */
SELECT device_type, view_date, daily_views,
       AVG(daily_views) OVER (PARTITION BY device_type ORDER BY view_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS ma_7day,
       ROUND(100.0 * daily_views / SUM(daily_views) OVER (PARTITION BY view_date), 2) AS pct_of_daily_total
FROM (SELECT device_type, view_timestamp::date AS view_date, COUNT(*) AS daily_views FROM web_events.page_views GROUP BY device_type, view_timestamp::date) d
ORDER BY device_type, view_date;

/* Q40. */
SELECT dept_id, month, monthly_net_salary,
       AVG(monthly_net_salary) OVER (PARTITION BY dept_id ORDER BY month ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS ma_6mo,
       AVG(monthly_net_salary) OVER (PARTITION BY dept_id ORDER BY month ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS ma_12mo
FROM (SELECT e.dept_id, DATE_TRUNC('month', ps.payment_date) AS month, SUM(ps.net_salary) AS monthly_net_salary FROM payroll.pay_slips ps JOIN stores.employees e ON ps.employee_id = e.employee_id GROUP BY e.dept_id, DATE_TRUNC('month', ps.payment_date)) t
ORDER BY dept_id, month;

/* Q41. */
SELECT cust_id, order_date, net_total,
       SUM(net_total) OVER (PARTITION BY cust_id ORDER BY order_date RANGE BETWEEN INTERVAL '89 days' PRECEDING AND CURRENT ROW) AS trailing_90day_spend,
       SUM(net_total) OVER (PARTITION BY cust_id ORDER BY order_date RANGE BETWEEN INTERVAL '364 days' PRECEDING AND CURRENT ROW) AS trailing_365day_spend
FROM sales.orders
ORDER BY cust_id, order_date;

/* Q42. */
SELECT order_date, daily_revenue,
       AVG(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS trailing_30day_avg,
       STDDEV(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS trailing_30day_stddev,
       ROUND((daily_revenue - AVG(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW))
                / NULLIF(STDDEV(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW), 0), 2) AS z_score
FROM (SELECT order_date, SUM(net_total) AS daily_revenue FROM sales.orders GROUP BY order_date) d
ORDER BY order_date;

/* Q43. */
SELECT priority, created_day, daily_tickets,
       SUM(daily_tickets) OVER (PARTITION BY priority ORDER BY created_day ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) AS rolling_14day,
       AVG(daily_tickets) OVER (PARTITION BY priority ORDER BY created_day ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) AS ma_14day
FROM (SELECT priority, created_date::date AS created_day, COUNT(*) AS daily_tickets FROM support.tickets GROUP BY priority, created_date::date) t
ORDER BY priority, created_day;

/* Q44. */
SELECT brand_id, order_date, daily_revenue,
       SUM(daily_revenue) OVER (PARTITION BY brand_id ORDER BY order_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS trailing_30day,
       SUM(daily_revenue) OVER (PARTITION BY brand_id ORDER BY order_date ROWS BETWEEN 89 PRECEDING AND CURRENT ROW) AS trailing_90day,
       ROUND(100.0 * SUM(daily_revenue) OVER (PARTITION BY brand_id ORDER BY order_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW)
                    / NULLIF(SUM(daily_revenue) OVER (PARTITION BY brand_id ORDER BY order_date ROWS BETWEEN 89 PRECEDING AND CURRENT ROW), 0), 2) AS pct_of_trailing_90day
FROM (SELECT p.brand_id, o.order_date, SUM(oi.net_amount) AS daily_revenue FROM sales.order_items oi JOIN sales.orders o ON oi.order_id = o.order_id JOIN products.products p ON oi.prod_id = p.product_id GROUP BY p.brand_id, o.order_date) t
ORDER BY brand_id, order_date;

/* Q45. */
WITH order_basket AS (
    SELECT o.order_id, o.store_id, o.order_date, SUM(oi.quantity) AS basket_size
    FROM sales.orders o
    JOIN sales.order_items oi ON oi.order_id = o.order_id
    GROUP BY o.order_id, o.store_id, o.order_date
)
SELECT store_id, order_date, basket_size,
       AVG(basket_size) OVER (PARTITION BY store_id ORDER BY order_date, order_id ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS ma_7order,
       AVG(basket_size) OVER (PARTITION BY store_id ORDER BY order_date, order_id ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS ma_30order
FROM order_basket
ORDER BY store_id, order_date;

/* Q46. */
SELECT store_id, month, monthly_revenue,
       SUM(monthly_revenue) OVER (PARTITION BY store_id ORDER BY month ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS ttm_revenue
FROM (SELECT store_id, DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_revenue FROM sales.orders GROUP BY store_id, DATE_TRUNC('month', order_date)) m
ORDER BY store_id, month;

/* Q47. */
SELECT region_id, week, weekly_new_customers,
       AVG(weekly_new_customers) OVER (PARTITION BY region_id ORDER BY week ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS ma_4week,
       AVG(weekly_new_customers) OVER (PARTITION BY region_id ORDER BY week ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS ma_12week
FROM (
    SELECT r.region_id, DATE_TRUNC('week', c.registration_date) AS week, COUNT(DISTINCT c.customer_id) AS weekly_new_customers
    FROM customers.customers c
    JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = true
    JOIN core.dim_region r ON r.state = a.state
    GROUP BY r.region_id, DATE_TRUNC('week', c.registration_date)
) t
ORDER BY region_id, week;

/* Q48. */
WITH daily_distinct AS (
    SELECT o.store_id, o.order_date, COUNT(DISTINCT oi.prod_id) AS distinct_products_that_day
    FROM sales.orders o
    JOIN sales.order_items oi ON oi.order_id = o.order_id
    GROUP BY o.store_id, o.order_date
)
SELECT store_id, order_date, distinct_products_that_day,
       SUM(distinct_products_that_day) OVER (PARTITION BY store_id ORDER BY order_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS rolling_30day_distinct_products_approx
FROM daily_distinct
ORDER BY store_id, order_date;

/* Q49. */
SELECT store_id, order_date, daily_revenue,
       AVG(daily_revenue) OVER (PARTITION BY store_id ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS ma_7day,
       ROUND(100.0 * (daily_revenue - AVG(daily_revenue) OVER (PARTITION BY store_id ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW))
                    / NULLIF(AVG(daily_revenue) OVER (PARTITION BY store_id ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 0), 2) AS pct_deviation_from_ma
FROM (SELECT store_id, order_date, SUM(net_total) AS daily_revenue FROM sales.orders GROUP BY store_id, order_date) d
ORDER BY store_id, order_date;

/* Q50. */
SELECT store_id, order_date, daily_revenue,
       AVG(daily_revenue) OVER (PARTITION BY store_id ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS ma_7day,
       AVG(daily_revenue) OVER (PARTITION BY store_id ORDER BY order_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS ma_30day,
       SUM(daily_revenue) OVER (PARTITION BY store_id, EXTRACT(YEAR FROM order_date) ORDER BY order_date) AS ytd_revenue,
       ROUND(100.0 * SUM(daily_revenue) OVER (PARTITION BY store_id, EXTRACT(YEAR FROM order_date) ORDER BY order_date)
                    / SUM(daily_revenue) OVER (PARTITION BY store_id, EXTRACT(YEAR FROM order_date)), 2) AS pct_of_year
FROM (SELECT store_id, order_date, SUM(net_total) AS daily_revenue FROM sales.orders GROUP BY store_id, order_date) d
ORDER BY store_id, order_date;

/* ============================================================
   SECTION C: ANCHORED VALUES, PARETO & ABC (25)
   ------------------------------------------------------------ */
/* Q51. */
WITH prod_rev AS (
    SELECT b.category_id, p.product_id, SUM(oi.net_amount) AS revenue
    FROM sales.order_items oi
    JOIN products.products p ON oi.prod_id = p.product_id
    JOIN core.dim_brand b ON p.brand_id = b.brand_id
    GROUP BY b.category_id, p.product_id
),
cum AS (
    SELECT category_id, product_id, revenue,
           SUM(revenue) OVER (PARTITION BY category_id ORDER BY revenue DESC, product_id) AS cum_revenue,
           SUM(revenue) OVER (PARTITION BY category_id) AS category_total
    FROM prod_rev
)
SELECT category_id, product_id, revenue, ROUND(100.0 * cum_revenue / category_total, 2) AS cumulative_pct,
       CASE WHEN cum_revenue <= 0.8 * category_total THEN 'A'
            WHEN cum_revenue <= 0.95 * category_total THEN 'B'
            ELSE 'C' END AS abc_class
FROM cum
ORDER BY category_id, revenue DESC;

/* Q52. */
WITH cust_rev AS (SELECT cust_id, SUM(net_total) AS revenue FROM sales.orders GROUP BY cust_id),
ranked AS (
    SELECT cust_id, revenue,
           COUNT(*) OVER (ORDER BY revenue DESC, cust_id) AS cum_count, COUNT(*) OVER () AS total_count,
           SUM(revenue) OVER (ORDER BY revenue DESC, cust_id) AS cum_revenue, SUM(revenue) OVER () AS total_revenue
    FROM cust_rev
)
SELECT MAX(cum_count) AS top20pct_customer_count, MAX(cum_revenue) AS revenue_from_top20pct,
       ROUND(100.0 * MAX(cum_revenue) / MAX(total_revenue), 2) AS pct_of_revenue
FROM ranked
WHERE cum_count <= 0.2 * total_count;

/* Q53. */
SELECT store_id, month, monthly_revenue,
       ROUND(100.0 * monthly_revenue / FIRST_VALUE(monthly_revenue) OVER (PARTITION BY store_id ORDER BY month), 2) AS index_to_first_month
FROM (SELECT store_id, DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_revenue FROM sales.orders GROUP BY store_id, DATE_TRUNC('month', order_date)) m
ORDER BY store_id, month;

/* Q54. */
SELECT order_id, cust_id, order_date, net_total,
       FIRST_VALUE(net_total) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS first_order_value,
       LAST_VALUE(net_total) OVER (PARTITION BY cust_id ORDER BY order_date, order_id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_order_value
FROM sales.orders;

/* Q55. */
SELECT store_id, order_date, cum_revenue,
       MAX(cum_revenue) OVER (PARTITION BY store_id ORDER BY order_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_peak,
       ROUND(100.0 * (cum_revenue - MAX(cum_revenue) OVER (PARTITION BY store_id ORDER BY order_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW))
                    / NULLIF(MAX(cum_revenue) OVER (PARTITION BY store_id ORDER BY order_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 0), 2) AS pct_drawdown
FROM (
    SELECT store_id, order_date, SUM(net_total) OVER (PARTITION BY store_id ORDER BY order_date) AS cum_revenue
    FROM (SELECT store_id, order_date, SUM(net_total) AS net_total FROM sales.orders GROUP BY store_id, order_date) d
) c
ORDER BY store_id, order_date;

/* Q56. */
WITH prod_units AS (
    SELECT p.brand_id, p.product_id, SUM(oi.quantity) AS units
    FROM sales.order_items oi
    JOIN products.products p ON oi.prod_id = p.product_id
    GROUP BY p.brand_id, p.product_id
),
cum AS (
    SELECT brand_id, product_id, units,
           SUM(units) OVER (PARTITION BY brand_id ORDER BY units DESC, product_id) AS cum_units,
           SUM(units) OVER (PARTITION BY brand_id) AS brand_total
    FROM prod_units
)
SELECT brand_id, product_id, units, ROUND(100.0 * cum_units / brand_total, 2) AS cumulative_pct,
       CASE WHEN cum_units <= 0.8 * brand_total THEN 'A'
            WHEN cum_units <= 0.95 * brand_total THEN 'B'
            ELSE 'C' END AS abc_class
FROM cum
ORDER BY brand_id, units DESC;

/* Q57. */
SELECT region_id, month, monthly_revenue,
       FIRST_VALUE(monthly_revenue) OVER (PARTITION BY region_id ORDER BY monthly_revenue DESC, month) AS region_best_month
FROM (SELECT s.region_id, DATE_TRUNC('month', o.order_date) AS month, SUM(o.net_total) AS monthly_revenue FROM sales.orders o JOIN stores.stores s ON o.store_id = s.store_id GROUP BY s.region_id, DATE_TRUNC('month', o.order_date)) t;

/* Q58. */
WITH cat_rev AS (
    SELECT b.category_id, SUM(oi.net_amount) AS revenue
    FROM sales.order_items oi
    JOIN products.products p ON oi.prod_id = p.product_id
    JOIN core.dim_brand b ON p.brand_id = b.brand_id
    GROUP BY b.category_id
)
SELECT category_id, revenue,
       SUM(revenue) OVER (ORDER BY revenue DESC, category_id) AS cumulative_revenue,
       ROUND(100.0 * SUM(revenue) OVER (ORDER BY revenue DESC, category_id) / SUM(revenue) OVER (), 2) AS cumulative_pct
FROM cat_rev
ORDER BY revenue DESC;

/* Q59. */
SELECT order_id, cust_id, order_date, net_total,
       NTH_VALUE(net_total, 2) OVER (PARTITION BY cust_id ORDER BY order_date, order_id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS second_order_value,
       NTH_VALUE(net_total, 3) OVER (PARTITION BY cust_id ORDER BY order_date, order_id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS third_order_value
FROM sales.orders;

/* Q60. */
SELECT product_id, brand_id, price,
       FIRST_VALUE(price) OVER (PARTITION BY brand_id ORDER BY price ASC, product_id) AS brand_cheapest,
       LAST_VALUE(price) OVER (PARTITION BY brand_id ORDER BY price ASC, product_id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS brand_dearest
FROM products.products;

/* Q61. */
WITH monthly AS (
    SELECT o.cust_id, DATE_TRUNC('month', c.registration_date) AS cohort_month, DATE_TRUNC('month', o.order_date) AS month, SUM(o.net_total) AS monthly_spend
    FROM sales.orders o
    JOIN customers.customers c ON o.cust_id = c.customer_id
    GROUP BY o.cust_id, DATE_TRUNC('month', c.registration_date), DATE_TRUNC('month', o.order_date)
)
SELECT cust_id, cohort_month, month, monthly_spend,
       ROUND(100.0 * monthly_spend / FIRST_VALUE(monthly_spend) OVER (PARTITION BY cust_id ORDER BY month), 2) AS indexed_to_first_month
FROM monthly
ORDER BY cust_id, month;

/* Q62. */
WITH prod_rev AS (SELECT prod_id, SUM(net_amount) AS revenue FROM sales.order_items GROUP BY prod_id),
cum AS (
    SELECT prod_id, revenue,
           SUM(revenue) OVER (ORDER BY revenue DESC, prod_id) AS cum_revenue,
           SUM(revenue) OVER () AS total_revenue
    FROM prod_rev
)
SELECT prod_id, revenue, ROUND(100.0 * cum_revenue / total_revenue, 2) AS cumulative_pct
FROM cum
WHERE cum_revenue - revenue < 0.8 * total_revenue
ORDER BY revenue DESC;

/* Q63. */
SELECT campaign_id, platform, campaign_spend,
       FIRST_VALUE(campaign_spend) OVER (PARTITION BY platform ORDER BY campaign_spend DESC, campaign_id) AS platform_biggest_spend
FROM (SELECT campaign_id, platform, SUM(amount) AS campaign_spend FROM marketing.ads_spend GROUP BY campaign_id, platform) t;

/* Q64. */
WITH daily AS (
    SELECT order_date, SUM(gross_total) AS daily_gmv FROM sales.orders GROUP BY order_date
),
running AS (
    SELECT order_date, SUM(daily_gmv) OVER (ORDER BY order_date) AS cum_gmv FROM daily
),
dd AS (
    SELECT order_date, cum_gmv,
           MAX(cum_gmv) OVER (ORDER BY order_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_peak
    FROM running
)
SELECT MIN(ROUND(100.0 * (cum_gmv - running_peak) / NULLIF(running_peak, 0), 2)) AS max_drawdown_pct
FROM dd;

/* Q65. */
WITH prod_margin AS (
    SELECT b.category_id, p.product_id, SUM(oi.net_amount - p.cost_price * oi.quantity) AS margin
    FROM sales.order_items oi
    JOIN products.products p ON oi.prod_id = p.product_id
    JOIN core.dim_brand b ON p.brand_id = b.brand_id
    GROUP BY b.category_id, p.product_id
),
cum AS (
    SELECT category_id, product_id, margin,
           SUM(margin) OVER (PARTITION BY category_id ORDER BY margin DESC, product_id) AS cum_margin,
           SUM(margin) OVER (PARTITION BY category_id) AS category_total_margin
    FROM prod_margin
)
SELECT category_id, product_id, margin, ROUND(100.0 * cum_margin / NULLIF(category_total_margin, 0), 2) AS cumulative_pct,
       CASE WHEN cum_margin <= 0.8 * category_total_margin THEN 'A'
            WHEN cum_margin <= 0.95 * category_total_margin THEN 'B'
            ELSE 'C' END AS abc_class
FROM cum
ORDER BY category_id, margin DESC;

/* Q66. */
SELECT s.store_id, s.region_id, sr.total_revenue,
       FIRST_VALUE(sr.total_revenue) OVER (PARTITION BY s.region_id ORDER BY sr.total_revenue DESC, s.store_id) AS region_top_store,
       LAST_VALUE(sr.total_revenue) OVER (PARTITION BY s.region_id ORDER BY sr.total_revenue DESC, s.store_id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS region_bottom_store
FROM stores.stores s
JOIN (SELECT store_id, SUM(net_total) AS total_revenue FROM sales.orders GROUP BY store_id) sr
  ON sr.store_id = s.store_id;

/* Q67. */
WITH wh_units AS (
    SELECT warehouse_id, product_id, SUM(quantity_on_hand) AS total_qty
    FROM supply_chain.inventory_snapshots
    GROUP BY warehouse_id, product_id
),
ranked AS (
    SELECT warehouse_id, product_id, total_qty,
           COUNT(*) OVER (PARTITION BY warehouse_id ORDER BY total_qty DESC, product_id) AS cum_count,
           COUNT(*) OVER (PARTITION BY warehouse_id) AS total_count
    FROM wh_units
)
SELECT warehouse_id, product_id, total_qty
FROM ranked
WHERE cum_count <= 0.2 * total_count
ORDER BY warehouse_id, total_qty DESC;

/* Q68. */
SELECT employee_id, dept_id, joining_date, salary,
       FIRST_VALUE(salary) OVER (PARTITION BY dept_id ORDER BY joining_date, employee_id) AS dept_first_hire_salary,
       LAST_VALUE(salary) OVER (PARTITION BY dept_id ORDER BY joining_date, employee_id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS dept_last_hire_salary
FROM stores.employees;

/* Q69. */
WITH cust_refunds AS (
    SELECT o.cust_id, SUM(r.refund_amount) AS total_refunds
    FROM sales.returns r
    JOIN sales.orders o ON r.order_id = o.order_id
    GROUP BY o.cust_id
),
cum AS (
    SELECT cust_id, total_refunds,
           SUM(total_refunds) OVER (ORDER BY total_refunds DESC, cust_id) AS cum_refunds,
           SUM(total_refunds) OVER () AS grand_total_refunds
    FROM cust_refunds
)
SELECT cust_id, total_refunds, ROUND(100.0 * cum_refunds / grand_total_refunds, 2) AS cumulative_pct
FROM cum
ORDER BY total_refunds DESC;

/* Q70. */
SELECT region_id, year, month, monthly_revenue,
       ROUND(100.0 * monthly_revenue / FIRST_VALUE(monthly_revenue) OVER (PARTITION BY region_id, year ORDER BY month), 2) AS indexed_to_year_first_month
FROM (SELECT s.region_id, EXTRACT(YEAR FROM o.order_date) AS year, DATE_TRUNC('month', o.order_date) AS month, SUM(o.net_total) AS monthly_revenue FROM sales.orders o JOIN stores.stores s ON o.store_id = s.store_id GROUP BY s.region_id, EXTRACT(YEAR FROM o.order_date), DATE_TRUNC('month', o.order_date)) t
ORDER BY region_id, year, month;

/* Q71. */
WITH pm_rev AS (
    SELECT pm.mode_name, SUM(o.net_total) AS revenue
    FROM sales.orders o
    JOIN finance.payment_modes pm ON o.payment_mode_id = pm.mode_id
    GROUP BY pm.mode_name
)
SELECT mode_name, revenue,
       SUM(revenue) OVER (ORDER BY revenue DESC, mode_name) AS cumulative_revenue,
       ROUND(100.0 * SUM(revenue) OVER (ORDER BY revenue DESC, mode_name) / SUM(revenue) OVER (), 2) AS cumulative_pct
FROM pm_rev
ORDER BY revenue DESC;

/* Q72. */
SELECT warehouse_id, product_id, snapshot_date,
       FIRST_VALUE(quantity_on_hand) OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date) AS first_qty,
       LAST_VALUE(quantity_on_hand) OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_qty,
       LAST_VALUE(quantity_on_hand) OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
         - FIRST_VALUE(quantity_on_hand) OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date) AS net_change
FROM supply_chain.inventory_snapshots
ORDER BY warehouse_id, product_id, snapshot_date;

/* Q73. */
WITH agent_resolved AS (
    SELECT agent_id, COUNT(*) AS resolved_count FROM support.tickets WHERE status = 'Resolved' GROUP BY agent_id
)
SELECT agent_id, resolved_count,
       SUM(resolved_count) OVER (ORDER BY resolved_count DESC, agent_id) AS cumulative_resolved,
       ROUND(100.0 * SUM(resolved_count) OVER (ORDER BY resolved_count DESC, agent_id) / SUM(resolved_count) OVER (), 2) AS cumulative_pct
FROM agent_resolved
ORDER BY resolved_count DESC;

/* Q74. */
WITH cust_rev AS (SELECT cust_id, SUM(net_total) AS revenue FROM sales.orders GROUP BY cust_id),
cum AS (
    SELECT cust_id, revenue,
           SUM(revenue) OVER (ORDER BY revenue DESC, cust_id) AS cum_revenue,
           SUM(revenue) OVER () AS total_revenue
    FROM cust_rev
)
SELECT cust_id, revenue, ROUND(100.0 * cum_revenue / total_revenue, 2) AS cumulative_pct,
       CASE WHEN cum_revenue <= 0.8 * total_revenue THEN 'A'
            WHEN cum_revenue <= 0.95 * total_revenue THEN 'B'
            ELSE 'C' END AS abc_class
FROM cum
ORDER BY revenue DESC;

/* Q75. */
WITH monthly AS (
    SELECT p.brand_id, p.product_id, DATE_TRUNC('month', o.order_date) AS month, SUM(oi.net_amount) AS monthly_revenue
    FROM sales.order_items oi
    JOIN sales.orders o ON oi.order_id = o.order_id
    JOIN products.products p ON oi.prod_id = p.product_id
    GROUP BY p.brand_id, p.product_id, DATE_TRUNC('month', o.order_date)
),
shares AS (
    SELECT brand_id, product_id, month, monthly_revenue,
           ROUND(100.0 * monthly_revenue / SUM(monthly_revenue) OVER (PARTITION BY brand_id, month), 2) AS pct_of_brand_that_month
    FROM monthly
)
SELECT brand_id, product_id, month, monthly_revenue, pct_of_brand_that_month,
       FIRST_VALUE(month) OVER (PARTITION BY product_id ORDER BY pct_of_brand_that_month DESC, month) AS peak_share_month
FROM shares
ORDER BY brand_id, product_id, month;

/* ============================================================
   SECTION D: EXECUTIVE DASHBOARDS (25)
   ------------------------------------------------------------ */
/* Q76. */
SELECT region_id, year, month, monthly_revenue,
       SUM(monthly_revenue) OVER (PARTITION BY region_id, year ORDER BY month) AS ytd_revenue,
       ROUND(100.0 * SUM(monthly_revenue) OVER (PARTITION BY region_id, year ORDER BY month) / SUM(monthly_revenue) OVER (PARTITION BY region_id, year), 2) AS pct_of_year,
       AVG(monthly_revenue) OVER (PARTITION BY region_id ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ma_3mo,
       ROUND(100.0 * monthly_revenue / SUM(monthly_revenue) OVER (PARTITION BY month), 2) AS contribution_pct_of_company_month
FROM (SELECT s.region_id, EXTRACT(YEAR FROM o.order_date) AS year, DATE_TRUNC('month', o.order_date) AS month, SUM(o.net_total) AS monthly_revenue FROM sales.orders o JOIN stores.stores s ON o.store_id = s.store_id GROUP BY s.region_id, EXTRACT(YEAR FROM o.order_date), DATE_TRUNC('month', o.order_date)) t
ORDER BY region_id, year, month;

/* Q77. */
SELECT gs.d AS order_date, COALESCE(t.daily_revenue, 0) AS daily_revenue, COALESCE(t.daily_orders, 0) AS daily_orders,
       ROUND(COALESCE(t.daily_revenue, 0) / NULLIF(COALESCE(t.daily_orders, 0), 0), 2) AS aov,
       AVG(COALESCE(t.daily_revenue, 0)) OVER (ORDER BY gs.d ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS revenue_ma_7day,
       AVG(COALESCE(t.daily_orders, 0)) OVER (ORDER BY gs.d ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS orders_ma_7day
FROM generate_series(
        (SELECT MIN(order_date) FROM sales.orders),
        (SELECT MAX(order_date) FROM sales.orders),
        INTERVAL '1 day'
     ) AS gs(d)
LEFT JOIN (SELECT order_date, SUM(net_total) AS daily_revenue, COUNT(*) AS daily_orders FROM sales.orders GROUP BY order_date) t
  ON t.order_date = gs.d
ORDER BY gs.d;

/* Q78. */
SELECT store_id, region_id, order_date, daily_revenue,
       ROUND(100.0 * daily_revenue / SUM(daily_revenue) OVER (PARTITION BY region_id, order_date), 2) AS region_share_pct,
       SUM(daily_revenue) OVER (PARTITION BY store_id, EXTRACT(YEAR FROM order_date) ORDER BY order_date) AS ytd_revenue,
       AVG(daily_revenue) OVER (PARTITION BY store_id ORDER BY order_date ROWS BETWEEN 89 PRECEDING AND CURRENT ROW) AS trailing_90day_ma
FROM (SELECT s.store_id, s.region_id, o.order_date, SUM(o.net_total) AS daily_revenue FROM sales.orders o JOIN stores.stores s ON o.store_id = s.store_id GROUP BY s.store_id, s.region_id, o.order_date) d
ORDER BY store_id, order_date;

/* Q79. */
WITH prod_daily AS (
    SELECT p.product_id, p.brand_id, o.order_date, SUM(oi.quantity) AS daily_units
    FROM sales.order_items oi
    JOIN sales.orders o ON oi.order_id = o.order_id
    JOIN products.products p ON oi.prod_id = p.product_id
    GROUP BY p.product_id, p.brand_id, o.order_date
),
prod_total AS (
    SELECT product_id, brand_id, SUM(daily_units) AS total_units FROM prod_daily GROUP BY product_id, brand_id
),
prod_cum AS (
    SELECT product_id, brand_id, total_units,
           SUM(total_units) OVER (PARTITION BY brand_id ORDER BY total_units DESC, product_id) AS cum_units,
           SUM(total_units) OVER (PARTITION BY brand_id) AS brand_total_units
    FROM prod_total
)
SELECT pd.product_id, pd.brand_id, pd.order_date, pd.daily_units,
       ROUND(100.0 * pc.total_units / pc.brand_total_units, 2) AS brand_share_pct,
       CASE WHEN pc.cum_units <= 0.8 * pc.brand_total_units THEN 'A'
            WHEN pc.cum_units <= 0.95 * pc.brand_total_units THEN 'B'
            ELSE 'C' END AS abc_class,
       AVG(pd.daily_units) OVER (PARTITION BY pd.product_id ORDER BY pd.order_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS trailing_30day_ma
FROM prod_daily pd
JOIN prod_cum pc ON pc.product_id = pd.product_id
ORDER BY pd.brand_id, pd.product_id, pd.order_date;

/* Q80. */
SELECT cust_id, lifetime_spend,
       ROUND(100.0 * SUM(lifetime_spend) OVER (ORDER BY lifetime_spend) / SUM(lifetime_spend) OVER (), 2) AS cumulative_pct_rank,
       recency_days,
       trailing_90day_spend
FROM (
    SELECT o.cust_id, SUM(o.net_total) AS lifetime_spend,
           (CURRENT_DATE - MAX(o.order_date)) AS recency_days,
           SUM(o.net_total) FILTER (WHERE o.order_date >= CURRENT_DATE - INTERVAL '90 days') AS trailing_90day_spend
    FROM sales.orders o
    GROUP BY o.cust_id
) t
ORDER BY lifetime_spend DESC;

/* Q81. */
SELECT category_id, year, month, monthly_revenue,
       ROUND(100.0 * monthly_revenue / SUM(monthly_revenue) OVER (PARTITION BY month), 2) AS pct_of_company,
       SUM(monthly_revenue) OVER (PARTITION BY category_id, year ORDER BY month) AS ytd_revenue,
       AVG(monthly_revenue) OVER (PARTITION BY category_id ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ma_3mo
FROM (
    SELECT b.category_id, EXTRACT(YEAR FROM o.order_date) AS year, DATE_TRUNC('month', o.order_date) AS month, SUM(oi.net_amount) AS monthly_revenue
    FROM sales.order_items oi
    JOIN sales.orders o ON oi.order_id = o.order_id
    JOIN products.products p ON oi.prod_id = p.product_id
    JOIN core.dim_brand b ON p.brand_id = b.brand_id
    GROUP BY b.category_id, EXTRACT(YEAR FROM o.order_date), DATE_TRUNC('month', o.order_date)
) t
ORDER BY category_id, year, month;

/* Q82. */
SELECT courier_name, shipped_date, avg_delivery_days,
       AVG(avg_delivery_days) OVER (PARTITION BY courier_name ORDER BY shipped_date ROWS BETWEEN 99 PRECEDING AND CURRENT ROW) AS trailing_100_ma,
       pct_under_2days
FROM (
    SELECT courier_name, shipped_date, AVG(delivered_date - shipped_date) AS avg_delivery_days,
           ROUND(100.0 * SUM(CASE WHEN (delivered_date - shipped_date) < 2 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_under_2days
    FROM sales.shipments
    GROUP BY courier_name, shipped_date
) t
ORDER BY courier_name, shipped_date;

/* Q83. */
SELECT agent_id, category, created_day, daily_resolved,
       AVG(daily_resolved) OVER (PARTITION BY agent_id ORDER BY created_day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS trailing_week_ma,
       ROUND(100.0 * daily_resolved / SUM(daily_resolved) OVER (PARTITION BY category, created_day), 2) AS share_of_category_that_day
FROM (SELECT agent_id, category, created_date::date AS created_day, COUNT(*) AS daily_resolved FROM support.tickets WHERE status = 'Resolved' GROUP BY agent_id, category, created_date::date) t
ORDER BY agent_id, created_day;

/* Q84. */
WITH region_rev AS (
    SELECT s.region_id, SUM(o.net_total) AS revenue FROM sales.orders o JOIN stores.stores s ON o.store_id = s.store_id GROUP BY s.region_id
)
SELECT region_id, revenue,
       SUM(revenue) OVER (ORDER BY revenue DESC, region_id) AS cumulative_revenue,
       ROUND(100.0 * SUM(revenue) OVER (ORDER BY revenue DESC, region_id) / SUM(revenue) OVER (), 2) AS cumulative_pct
FROM region_rev
ORDER BY revenue DESC;

/* Q85. */
SELECT platform, spend_date, daily_spend,
       ROUND(100.0 * daily_spend / SUM(daily_spend) OVER (PARTITION BY spend_date), 2) AS share_pct_that_day,
       AVG(daily_spend) OVER (PARTITION BY platform ORDER BY spend_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS trailing_30day_ma,
       SUM(daily_spend) OVER (PARTITION BY platform ORDER BY spend_date) AS cumulative_spend
FROM (SELECT platform, spend_date, SUM(amount) AS daily_spend FROM marketing.ads_spend GROUP BY platform, spend_date) t
ORDER BY platform, spend_date;

/* Q86. */
SELECT warehouse_id, region, snapshot_date, total_qty,
       ROUND(100.0 * total_qty / SUM(total_qty) OVER (PARTITION BY region, snapshot_date), 2) AS region_share_pct,
       AVG(total_qty) OVER (PARTITION BY warehouse_id ORDER BY snapshot_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS trailing_30day_ma
FROM (
    SELECT w.warehouse_id, w.region, s.snapshot_date, SUM(s.quantity_on_hand) AS total_qty
    FROM supply_chain.inventory_snapshots s
    JOIN supply_chain.warehouses w ON s.warehouse_id = w.warehouse_id
    GROUP BY w.warehouse_id, w.region, s.snapshot_date
) t
ORDER BY warehouse_id, snapshot_date;

/* Q87. */
WITH cohort_monthly AS (
    SELECT DATE_TRUNC('month', c.registration_date) AS cohort_month, DATE_TRUNC('month', o.order_date) AS month, SUM(o.net_total) AS monthly_spend
    FROM sales.orders o
    JOIN customers.customers c ON o.cust_id = c.customer_id
    GROUP BY DATE_TRUNC('month', c.registration_date), DATE_TRUNC('month', o.order_date)
),
cum AS (
    SELECT cohort_month, month, SUM(monthly_spend) OVER (PARTITION BY cohort_month ORDER BY month) AS cumulative_spend
    FROM cohort_monthly
)
SELECT cohort_month, month, cumulative_spend,
       ROUND(100.0 * cumulative_spend / FIRST_VALUE(cumulative_spend) OVER (PARTITION BY cohort_month ORDER BY month), 2) AS indexed_to_100
FROM cum
ORDER BY cohort_month, month;

/* Q88. */
SELECT order_date, daily_revenue,
       AVG(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS ma_7day,
       ROUND((daily_revenue - AVG(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW))
                / NULLIF(STDDEV(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW), 0), 2) AS z_score,
       (ABS((daily_revenue - AVG(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW))
                / NULLIF(STDDEV(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW), 0)) > 2) AS is_flagged_spike
FROM (SELECT order_date, SUM(net_total) AS daily_revenue FROM sales.orders GROUP BY order_date) d
ORDER BY order_date;

/* Q89. */
WITH cust_rev AS (SELECT cust_id, SUM(net_total) AS revenue FROM sales.orders GROUP BY cust_id),
cum AS (
    SELECT cust_id, revenue,
           SUM(revenue) OVER (ORDER BY revenue DESC, cust_id) AS cum_revenue,
           SUM(revenue) OVER () AS total_revenue
    FROM cust_rev
)
SELECT cust_id, revenue, ROUND(100.0 * cum_revenue / total_revenue, 2) AS cumulative_pct,
       (cum_revenue <= 0.8 * total_revenue) AS within_80pct_line
FROM cum
ORDER BY revenue DESC;

/* Q90. */
WITH rev AS (
    SELECT s.region_id, DATE_TRUNC('month', o.order_date) AS month, SUM(o.net_total) AS revenue
    FROM sales.orders o
    JOIN stores.stores s ON o.store_id = s.store_id
    GROUP BY s.region_id, DATE_TRUNC('month', o.order_date)
),
exp AS (
    SELECT s.region_id, DATE_TRUNC('month', se.expense_date) AS month, SUM(se.amount) AS expenses
    FROM stores.expenses se
    JOIN stores.stores s ON se.store_id = s.store_id
    GROUP BY s.region_id, DATE_TRUNC('month', se.expense_date)
)
SELECT r.region_id, r.month, r.revenue, COALESCE(e.expenses, 0) AS expenses, r.revenue - COALESCE(e.expenses, 0) AS margin,
       SUM(r.revenue - COALESCE(e.expenses, 0)) OVER (PARTITION BY r.region_id ORDER BY r.month) AS running_margin
FROM rev r
LEFT JOIN exp e ON e.region_id = r.region_id AND e.month = r.month
ORDER BY r.region_id, r.month;

/* Q91. */
WITH weekly_active AS (
    SELECT DATE_TRUNC('week', order_date) AS week, COUNT(DISTINCT cust_id) AS weekly_active_customers
    FROM sales.orders
    GROUP BY DATE_TRUNC('week', order_date)
)
SELECT week, weekly_active_customers,
       AVG(weekly_active_customers) OVER (ORDER BY week ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS ma_4week
FROM weekly_active
ORDER BY week;

/* Q92. */
WITH brand_rev AS (
    SELECT b.category_id, p.brand_id, SUM(oi.net_amount) AS revenue
    FROM sales.order_items oi
    JOIN products.products p ON oi.prod_id = p.product_id
    JOIN core.dim_brand b ON p.brand_id = b.brand_id
    GROUP BY b.category_id, p.brand_id
),
cum AS (
    SELECT category_id, brand_id, revenue,
           SUM(revenue) OVER (PARTITION BY category_id ORDER BY revenue DESC, brand_id) AS cum_revenue,
           SUM(revenue) OVER (PARTITION BY category_id) AS category_total
    FROM brand_rev
),
ytd AS (
    SELECT p.brand_id, EXTRACT(YEAR FROM o.order_date) AS year, SUM(oi.net_amount) AS ytd_revenue
    FROM sales.order_items oi
    JOIN sales.orders o ON oi.order_id = o.order_id
    JOIN products.products p ON oi.prod_id = p.product_id
    GROUP BY p.brand_id, EXTRACT(YEAR FROM o.order_date)
)
SELECT c.category_id, c.brand_id, c.revenue AS total_revenue,
       ROUND(100.0 * c.revenue / c.category_total, 2) AS category_share_pct,
       y.year, y.ytd_revenue,
       CASE WHEN c.cum_revenue <= 0.8 * c.category_total THEN 'A'
            WHEN c.cum_revenue <= 0.95 * c.category_total THEN 'B'
            ELSE 'C' END AS abc_class
FROM cum c
JOIN ytd y ON y.brand_id = c.brand_id
ORDER BY c.category_id, c.revenue DESC, y.year;

/* Q93. */
WITH daily AS (
    SELECT s.store_id, s.region_id, o.order_date, SUM(o.net_total) AS daily_revenue
    FROM sales.orders o
    JOIN stores.stores s ON o.store_id = s.store_id
    GROUP BY s.store_id, s.region_id, o.order_date
),
trailing_rev AS (
    SELECT store_id, region_id, order_date,
           SUM(daily_revenue) OVER (PARTITION BY store_id ORDER BY order_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS trailing_30day_revenue
    FROM daily
)
SELECT region_id, order_date, store_id, trailing_30day_revenue,
       FIRST_VALUE(store_id) OVER (PARTITION BY region_id, order_date ORDER BY trailing_30day_revenue DESC, store_id) AS top_store_that_day
FROM trailing_rev
ORDER BY region_id, order_date, trailing_30day_revenue DESC;

/* Q94. */
WITH daily_cogs AS (
    SELECT oi.prod_id, o.order_date, SUM(oi.quantity * p.cost_price) AS daily_cogs
    FROM sales.order_items oi
    JOIN sales.orders o ON oi.order_id = o.order_id
    JOIN products.products p ON oi.prod_id = p.product_id
    GROUP BY oi.prod_id, o.order_date
),
daily_stock AS (
    SELECT product_id, snapshot_date, SUM(quantity_on_hand) AS total_stock
    FROM supply_chain.inventory_snapshots
    GROUP BY product_id, snapshot_date
)
SELECT dc.prod_id, dc.order_date,
       SUM(dc.daily_cogs) OVER (PARTITION BY dc.prod_id ORDER BY dc.order_date ROWS BETWEEN 89 PRECEDING AND CURRENT ROW) AS trailing_90day_cogs,
       AVG(ds.total_stock) OVER (PARTITION BY dc.prod_id ORDER BY dc.order_date ROWS BETWEEN 89 PRECEDING AND CURRENT ROW) AS trailing_90day_avg_stock,
       ROUND(SUM(dc.daily_cogs) OVER (PARTITION BY dc.prod_id ORDER BY dc.order_date ROWS BETWEEN 89 PRECEDING AND CURRENT ROW)
                / NULLIF(AVG(ds.total_stock) OVER (PARTITION BY dc.prod_id ORDER BY dc.order_date ROWS BETWEEN 89 PRECEDING AND CURRENT ROW), 0), 2) AS inventory_turns
FROM daily_cogs dc
LEFT JOIN daily_stock ds ON ds.product_id = dc.prod_id AND ds.snapshot_date = dc.order_date
ORDER BY dc.prod_id, dc.order_date;

/* Q95. */
WITH daily_views AS (
    SELECT device_type, view_timestamp::date AS d, COUNT(*) AS views
    FROM web_events.page_views
    GROUP BY device_type, view_timestamp::date
),
daily_submits AS (
    SELECT pv.device_type, e.event_timestamp::date AS d, COUNT(*) AS submits
    FROM web_events.events e
    JOIN web_events.page_views pv ON e.view_id = pv.view_id
    WHERE e.event_type = 'submit'
    GROUP BY pv.device_type, e.event_timestamp::date
)
SELECT dv.device_type, dv.d AS view_date, dv.views, COALESCE(ds.submits, 0) AS submits,
       ROUND(100.0 * COALESCE(ds.submits, 0) / dv.views, 2) AS conversion_proxy_pct,
       AVG(dv.views) OVER (PARTITION BY dv.device_type ORDER BY dv.d ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS views_ma_7day
FROM daily_views dv
LEFT JOIN daily_submits ds ON ds.device_type = dv.device_type AND ds.d = dv.d
ORDER BY dv.device_type, dv.d;

/* Q96. */
SELECT region_id, year, month, monthly_revenue,
       SUM(monthly_revenue) OVER (PARTITION BY region_id, year ORDER BY month) AS ytd_revenue,
       ROUND(100.0 * SUM(monthly_revenue) OVER (PARTITION BY region_id, year ORDER BY month) / SUM(monthly_revenue) OVER (PARTITION BY region_id, year), 2) AS pct_of_year,
       AVG(monthly_revenue) OVER (PARTITION BY region_id ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ma_3mo,
       ROUND(100.0 * monthly_revenue / SUM(monthly_revenue) OVER (PARTITION BY month), 2) AS contribution_pct,
       MAX(monthly_revenue) OVER (PARTITION BY region_id ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_peak,
       FIRST_VALUE(monthly_revenue) OVER (PARTITION BY region_id ORDER BY month) AS first_month_revenue,
       SUM(monthly_revenue) OVER (PARTITION BY region_id ORDER BY month ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS ttm_revenue
FROM (SELECT s.region_id, EXTRACT(YEAR FROM o.order_date) AS year, DATE_TRUNC('month', o.order_date) AS month, SUM(o.net_total) AS monthly_revenue FROM sales.orders o JOIN stores.stores s ON o.store_id = s.store_id GROUP BY s.region_id, EXTRACT(YEAR FROM o.order_date), DATE_TRUNC('month', o.order_date)) t
ORDER BY region_id, year, month;

/* Q97. */
SELECT year, month, monthly_revenue,
       SUM(monthly_revenue) OVER (PARTITION BY year ORDER BY month) AS ytd_revenue,
       ROUND(100.0 * SUM(monthly_revenue) OVER (PARTITION BY year ORDER BY month) / SUM(monthly_revenue) OVER (PARTITION BY year), 2) AS pct_of_year,
       SUM(monthly_revenue) OVER (ORDER BY month ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS ttm_revenue
FROM (SELECT EXTRACT(YEAR FROM order_date) AS year, DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS monthly_revenue FROM sales.orders GROUP BY 1, 2) m
ORDER BY year, month;

/* Q98. */
WITH cat_rev AS (
    SELECT b.category_id, SUM(oi.net_amount) AS revenue
    FROM sales.order_items oi
    JOIN products.products p ON oi.prod_id = p.product_id
    JOIN core.dim_brand b ON p.brand_id = b.brand_id
    GROUP BY b.category_id
)
SELECT category_id, revenue,
       ROUND(100.0 * revenue / SUM(revenue) OVER (), 2) AS pct_of_total,
       SUM(revenue) OVER (ORDER BY revenue DESC, category_id) AS cumulative_revenue,
       ROUND(100.0 * SUM(revenue) OVER (ORDER BY revenue DESC, category_id) / SUM(revenue) OVER (), 2) AS cumulative_pct
FROM cat_rev
ORDER BY revenue DESC;

/* Q99. */
WITH cat_refunds AS (
    SELECT b.category_id, r.return_date, SUM(r.refund_amount) AS daily_refunds
    FROM sales.returns r
    JOIN products.products p ON r.prod_id = p.product_id
    JOIN core.dim_brand b ON p.brand_id = b.brand_id
    GROUP BY b.category_id, r.return_date
),
cat_revenue AS (
    SELECT b.category_id, SUM(oi.net_amount) AS total_revenue
    FROM sales.order_items oi
    JOIN products.products p ON oi.prod_id = p.product_id
    JOIN core.dim_brand b ON p.brand_id = b.brand_id
    GROUP BY b.category_id
)
SELECT cr.category_id, cr.return_date, cr.daily_refunds,
       ROUND(100.0 * cr.daily_refunds / rv.total_revenue, 4) AS pct_of_category_revenue,
       AVG(cr.daily_refunds) OVER (PARTITION BY cr.category_id ORDER BY cr.return_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS trailing_30day_ma
FROM cat_refunds cr
JOIN cat_revenue rv ON rv.category_id = cr.category_id
ORDER BY cr.category_id, cr.return_date;

/* Q100. */
SELECT region_id, year, month, monthly_revenue,
       SUM(monthly_revenue) OVER (PARTITION BY region_id, year ORDER BY month) AS ytd_revenue,
       ROUND(100.0 * SUM(monthly_revenue) OVER (PARTITION BY region_id, year ORDER BY month) / SUM(monthly_revenue) OVER (PARTITION BY region_id, year), 2) AS pct_of_year,
       AVG(monthly_revenue) OVER (PARTITION BY region_id ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ma_3mo,
       ROUND(100.0 * monthly_revenue / SUM(monthly_revenue) OVER (PARTITION BY month), 2) AS contribution_pct,
       ROUND(100.0 * (monthly_revenue - MAX(monthly_revenue) OVER (PARTITION BY region_id ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW))
                    / NULLIF(MAX(monthly_revenue) OVER (PARTITION BY region_id ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 0), 2) AS pct_drawdown_from_peak
FROM (SELECT s.region_id, EXTRACT(YEAR FROM o.order_date) AS year, DATE_TRUNC('month', o.order_date) AS month, SUM(o.net_total) AS monthly_revenue FROM sales.orders o JOIN stores.stores s ON o.store_id = s.store_id GROUP BY s.region_id, EXTRACT(YEAR FROM o.order_date), DATE_TRUNC('month', o.order_date)) t
ORDER BY region_id, year, month;

/* ============================================================
   END OF ANSWER KEY - Window Functions Part 2 - CRAZY LEVEL (100/100)
============================================================ */
