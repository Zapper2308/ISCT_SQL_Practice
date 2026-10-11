/* ============================================================
   ANSWER KEY - Window Functions Part 3: LAG / LEAD (CRAZY LEVEL)
   Curriculum:   RetailMart V3
   Database:     isct_retailmart
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1. Compute LAG(x,1), LAG(x,3) and LAG(x,12) as sibling columns off one ordered window, then derive three growth percentages in the same SELECT - one pass over the data instead of three separate dashboards to reconcile. */
/* Q2. For each customer mark month_number = activity_month - signup_month via date math, then pivot/aggregate COUNT(DISTINCT customer) per (cohort_month, month_number); LAG/LEAD are used earlier to detect first activity and to confirm no gaps distort month 0. */
/* Q3. Number rows overall and again within each status group, subtract; the gap between the two counters is constant only inside one consecutive run. At scale this needs two ROW_NUMBER passes plus a GROUP BY on the difference, so it's O(n log n) for the sorts rather than O(n) - fine until the partition itself is huge, where a single ordered pass with a running counter is cheaper. */
/* Q4. Threshold (business rule) -> boolean new-session flag via LAG comparison -> SUM() of that boolean as a running total gives the session id -> GROUP BY the id to roll each session into one row with MIN/MAX timestamp and COUNT. */
/* Q5. An anomaly score standardizes the current value against its own recent history: z = (value - trailing_moving_average) / trailing_stddev, both computed with the same ROWS BETWEEN frame (Day 17); a |z| beyond a cutoff (e.g. 2) flags the point, which is more robust than a flat threshold since it adapts to each series' own volatility. */
/* Q6. Cross-join a generate_series month spine against the dimension, LEFT JOIN the real aggregate, COALESCE missing revenue to 0, then LAG on the always-present spine rows - this guarantees every LAG comparison is against a true adjacent period even when some periods had zero activity. */
/* Q7. Run a MAX() FILTER (WHERE x IS NOT NULL) OVER (... ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) - this "carries forward" the last known non-null value to every row, filling sparse gaps the same way LAG alone cannot. */
/* Q8. Churn is defined by elapsed time from the last known event to a fixed cutoff (CURRENT_DATE - MAX(event_date) > threshold); reactivation is defined by LAG - a gap between two consecutive events that itself exceeds the threshold. Both compare a computed gap to the same business rule, just anchored differently (open-ended vs. bounded by two real events). */
/* Q9. Run the same LAG/LEAD logic against several grouping grains (SKU, brand, category) as sibling CTEs that share the base fact table, then UNION ALL or join them together in one final SELECT rather than issuing a separate query - and separate connection round-trip - per grain. */
/* Q10. LEAD(event_timestamp) OVER (PARTITION BY entity ORDER BY event_timestamp) gives the next state's start time; subtracting the current timestamp gives the duration of the current state. Pivoting (current_status, next_status) pairs into a COUNT gives a state-transition matrix - all from one ordered event log. */
/* Q11. Simple subtraction of endpoints ((last/first)-1) is only correct if every intermediate period is included; if a period is skipped it silently drops a multiplicative term. Chaining via SUM(LN(1+g_i)) then EXP() (or a running PRODUCT) over an explicit window frame makes every step explicit and auditable, and naturally excludes/flags missing periods. */
/* Q12. Compute LEAD(next_step_timestamp) - current_timestamp per session to get step-to-step durations, then PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY duration) over all sessions gives the median time between funnel steps, robust to a few very slow sessions skewing a mean. */
/* Q13. Flag each period's delta sign with a CASE on (value - LAG(value)), then count the current run of matching signs via the reset-on-break running counter (or gaps-and-islands group length) - this generalizes "3 declining months" to any N and any metric without rewriting the logic. */
/* Q14. Anchor every cohort's timeline to its own first-activity date (MIN(date) per entity) rather than a fixed calendar date; because that anchor is recomputed from the data itself, re-running the query on a later refresh reproduces the same relative month-numbers for existing rows even as new data is appended. */
/* Q15. Compute the distribution (e.g. percentiles) of gaps between consecutive events first; a threshold set just above the "typical" gap (e.g. the 90th percentile of within-visit gaps) separates real session boundaries from noise, rather than guessing a fixed number like 30 minutes. */
/* Q16. A LAG-based change log is derived at query time directly from whatever "current" and "previous" rows exist, so it always reflects the live data and needs no separate audit infrastructure to maintain; a trigger-based audit table can drift, requires storage and maintenance, and analytics queries must join out to it. */
/* Q17. A fiscal calendar's month/quarter boundaries don't align with the ISO calendar's, so grouping by DATE_TRUNC (ISO) and comparing via LAG(x,12) silently compares the wrong periods for a fiscal business; the fix is to map dates to a fiscal-period key (via a calendar dimension) before grouping and lagging. */
/* Q18. LAG(x,12) on a monthly series isolates the YoY comparison; subtracting that ratio's implied trend from each month (or dividing by it) de-seasonalizes the series, revealing the underlying growth net of the repeating same-month-last-year pattern. */
/* Q19. Compute each entity's latest LAG-based growth % in a CTE, then apply NTILE(4) (or more buckets) OVER (ORDER BY that growth % DESC) in the outer query - LAG supplies the metric, NTILE buckets entities into ranked tiers from fastest to slowest movers. */
/* Q20. LEAD(next_order_date) - order_date per customer gives "days until next purchase" for every row that has a next order; rows with a NULL LEAD are right-censored (no next purchase observed yet) - exactly the shape a Kaplan-Meier-style survival table needs. */
/* Q21. Longest = MAX(run_length) per entity from the gaps-and-islands grouping; current = the run length of the entity's very last island (or 0 if it just broke); average = AVG(run_length) across all of an entity's islands - all three come from the same underlying island table, just aggregated differently. */
/* Q22. A funnel step is really just another kind of session event, so building the session id and the funnel-step ordering from two different event streams risks inconsistent timestamps/ordering; unioning all raw events into one ordered stream first guarantees the session boundaries and the funnel step sequence agree with each other. */
/* Q23. Treat any delta within +/- a small band (e.g. one trailing standard deviation, or a flat percentage) around the trailing average as normal noise rather than a real anomaly - only flag deltas that clear the band, which avoids constant false alarms from ordinary day-to-day variance. */
/* Q24. Take month_number-since-signup as the x-axis, retention_pct as the y-axis, and compute the delta between consecutive month_numbers via LAG partitioned by cohort - the sequence of deltas traces exactly how fast each cohort decays after acquisition. */
/* Q25. Precompute in a materialized view (Day 25) whenever the same expensive multi-CTE LAG/LEAD pipeline feeds a dashboard many users refresh often and the underlying data changes on a schedule (e.g. nightly ETL); compute on-the-fly when the result must reflect the absolute latest transaction or the query only runs rarely. */

/* ============================================================
   SECTION B: GROWTH & RETENTION SYSTEMS (25)
   ------------------------------------------------------------ */
/* Q26. */
WITH monthly AS (
    SELECT store_id, DATE_TRUNC('month', order_date)::date AS month, SUM(net_total) AS revenue
    FROM sales.orders GROUP BY store_id, DATE_TRUNC('month', order_date)
),
mg AS (
    SELECT store_id, month, revenue,
           LAG(revenue, 1) OVER (PARTITION BY store_id ORDER BY month) AS prev_m,
           LAG(revenue, 12) OVER (PARTITION BY store_id ORDER BY month) AS prev_y
    FROM monthly
),
quarterly AS (
    SELECT store_id, DATE_TRUNC('quarter', order_date)::date AS quarter, SUM(net_total) AS q_revenue
    FROM sales.orders GROUP BY store_id, DATE_TRUNC('quarter', order_date)
),
qg AS (
    SELECT store_id, quarter, q_revenue,
           LAG(q_revenue) OVER (PARTITION BY store_id ORDER BY quarter) AS prev_q
    FROM quarterly
)
SELECT mg.store_id, mg.month, mg.revenue,
       ROUND(100.0 * (mg.revenue - mg.prev_m) / NULLIF(mg.prev_m, 0), 2) AS mom_pct,
       ROUND(100.0 * (qg.q_revenue - qg.prev_q) / NULLIF(qg.prev_q, 0), 2) AS qoq_pct,
       ROUND(100.0 * (mg.revenue - mg.prev_y) / NULLIF(mg.prev_y, 0), 2) AS yoy_pct,
       CASE WHEN mg.revenue > mg.prev_m THEN 'UP' WHEN mg.revenue < mg.prev_m THEN 'DOWN' ELSE 'FLAT' END AS trend_flag
FROM mg
JOIN qg ON qg.store_id = mg.store_id AND qg.quarter = DATE_TRUNC('quarter', mg.month)::date
ORDER BY mg.store_id, mg.month;

/* Q27. */
WITH first_orders AS (
    SELECT cust_id, DATE_TRUNC('month', MIN(order_date))::date AS cohort_month FROM sales.orders GROUP BY cust_id
),
cohort_size AS (
    SELECT cohort_month, COUNT(*) AS cohort_customers FROM first_orders GROUP BY cohort_month
),
activity AS (
    SELECT o.cust_id, fo.cohort_month, DATE_TRUNC('month', o.order_date)::date AS activity_month,
           (EXTRACT(YEAR FROM DATE_TRUNC('month', o.order_date)) - EXTRACT(YEAR FROM fo.cohort_month)) * 12 +
           (EXTRACT(MONTH FROM DATE_TRUNC('month', o.order_date)) - EXTRACT(MONTH FROM fo.cohort_month)) AS months_since_signup
    FROM sales.orders o JOIN first_orders fo ON fo.cust_id = o.cust_id
),
retained AS (
    SELECT cohort_month, months_since_signup, COUNT(DISTINCT cust_id) AS active_customers
    FROM activity
    WHERE months_since_signup BETWEEN 1 AND 6
    GROUP BY cohort_month, months_since_signup
)
SELECT r.cohort_month, r.months_since_signup, r.active_customers, cs.cohort_customers,
       ROUND(100.0 * r.active_customers / NULLIF(cs.cohort_customers, 0), 2) AS retention_pct
FROM retained r JOIN cohort_size cs ON cs.cohort_month = r.cohort_month
ORDER BY r.cohort_month, r.months_since_signup;

/* Q28. */
WITH months AS (
    SELECT generate_series('2024-01-01'::date, '2026-02-01'::date, '1 month'::interval)::date AS month
),
base AS (
    SELECT r.region_id, r.region_name, m.month, COALESCE(SUM(o.net_total), 0) AS revenue
    FROM core.dim_region r CROSS JOIN months m
    LEFT JOIN stores.stores s ON s.region_id = r.region_id
    LEFT JOIN sales.orders o ON o.store_id = s.store_id AND DATE_TRUNC('month', o.order_date) = m.month
    GROUP BY r.region_id, r.region_name, m.month
)
SELECT region_id, region_name, month, revenue,
       LAG(revenue, 1) OVER (PARTITION BY region_id ORDER BY month) AS rev_1mo_ago,
       LAG(revenue, 3) OVER (PARTITION BY region_id ORDER BY month) AS rev_3mo_ago,
       LAG(revenue, 12) OVER (PARTITION BY region_id ORDER BY month) AS rev_12mo_ago
FROM base
ORDER BY region_id, month;

/* Q29. */
WITH monthly AS (
    SELECT store_id, DATE_TRUNC('month', order_date)::date AS month, SUM(net_total) AS revenue
    FROM sales.orders GROUP BY store_id, DATE_TRUNC('month', order_date)
),
g AS (
    SELECT store_id, month, revenue,
           revenue / NULLIF(LAG(revenue) OVER (PARTITION BY store_id ORDER BY month), 0) AS growth_ratio
    FROM monthly
),
ln_g AS (
    SELECT store_id, month, revenue,
           CASE WHEN growth_ratio > 0 THEN LN(growth_ratio) END AS ln_growth
    FROM g
),
compounded AS (
    SELECT store_id, month, revenue,
           SUM(ln_growth) OVER (PARTITION BY store_id ORDER BY month ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS sum_ln_6mo,
           COUNT(ln_growth) OVER (PARTITION BY store_id ORDER BY month ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS n_valid_months
    FROM ln_g
)
SELECT store_id, month, revenue, ROUND((EXP(sum_ln_6mo) - 1) * 100, 2) AS compounded_6mo_growth_pct
FROM compounded
WHERE n_valid_months = 6
ORDER BY store_id, month;

/* Q30. */
WITH first_orders AS (
    SELECT cust_id, MIN(order_date) AS first_order_date FROM sales.orders GROUP BY cust_id
),
tagged AS (
    SELECT o.cust_id, o.order_date, o.net_total,
           CASE WHEN o.order_date = fo.first_order_date THEN 'new' ELSE 'returning' END AS customer_type
    FROM sales.orders o JOIN first_orders fo ON fo.cust_id = o.cust_id
),
monthly AS (
    SELECT customer_type, DATE_TRUNC('month', order_date)::date AS month, SUM(net_total) AS revenue
    FROM tagged GROUP BY customer_type, DATE_TRUNC('month', order_date)
)
SELECT customer_type, month, revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (PARTITION BY customer_type ORDER BY month))
             / NULLIF(LAG(revenue) OVER (PARTITION BY customer_type ORDER BY month), 0), 2) AS mom_growth_pct
FROM monthly
ORDER BY customer_type, month;

/* Q31. */
WITH monthly AS (
    SELECT b.brand_name, DATE_TRUNC('month', o.order_date)::date AS month, SUM(oi.quantity * oi.unit_price) AS revenue
    FROM sales.order_items oi JOIN sales.orders o ON oi.order_id = o.order_id
    JOIN products.products p ON oi.prod_id = p.product_id JOIN core.dim_brand b ON p.brand_id = b.brand_id
    GROUP BY b.brand_name, DATE_TRUNC('month', o.order_date)
),
growth AS (
    SELECT brand_name, month,
           ROUND(100.0 * (revenue - LAG(revenue) OVER (PARTITION BY brand_name ORDER BY month))
                 / NULLIF(LAG(revenue) OVER (PARTITION BY brand_name ORDER BY month), 0), 2) AS mom_growth_pct
    FROM monthly
),
latest AS (
    SELECT brand_name, month, mom_growth_pct,
           ROW_NUMBER() OVER (PARTITION BY brand_name ORDER BY month DESC) AS rn
    FROM growth WHERE mom_growth_pct IS NOT NULL
)
SELECT brand_name, month, mom_growth_pct,
       NTILE(4) OVER (ORDER BY mom_growth_pct DESC) AS growth_tier
FROM latest WHERE rn = 1
ORDER BY growth_tier, mom_growth_pct DESC;

/* Q32. */
WITH first_orders AS (
    SELECT cust_id, MIN(order_date) AS first_order_date FROM sales.orders GROUP BY cust_id
),
channel AS (
    SELECT fo.cust_id, pm.mode_name AS acquisition_channel, DATE_TRUNC('month', fo.first_order_date)::date AS cohort_month
    FROM first_orders fo
    JOIN sales.orders o ON o.cust_id = fo.cust_id AND o.order_date = fo.first_order_date
    JOIN finance.payment_modes pm ON o.payment_mode_id = pm.mode_id
),
activity AS (
    SELECT cust_id, DATE_TRUNC('month', order_date)::date AS activity_month FROM sales.orders
),
combined AS (
    SELECT c.acquisition_channel, c.cohort_month,
           (EXTRACT(YEAR FROM a.activity_month) - EXTRACT(YEAR FROM c.cohort_month)) * 12 +
           (EXTRACT(MONTH FROM a.activity_month) - EXTRACT(MONTH FROM c.cohort_month)) AS months_since,
           a.cust_id
    FROM channel c JOIN activity a ON a.cust_id = c.cust_id
)
SELECT acquisition_channel, months_since, COUNT(DISTINCT cust_id) AS active_customers
FROM combined
WHERE months_since >= 0
GROUP BY acquisition_channel, months_since
ORDER BY acquisition_channel, months_since;

/* Q33. */
WITH monthly AS (
    SELECT c.category_name, EXTRACT(MONTH FROM o.order_date)::int AS month_num, EXTRACT(YEAR FROM o.order_date)::int AS year_num,
           SUM(o.net_total) AS revenue
    FROM sales.orders o
    JOIN sales.order_items oi ON oi.order_id = o.order_id
    JOIN products.products p ON oi.prod_id = p.product_id
    JOIN core.dim_brand b ON p.brand_id = b.brand_id
    JOIN core.dim_category c ON b.category_id = c.category_id
    GROUP BY c.category_name, EXTRACT(MONTH FROM o.order_date), EXTRACT(YEAR FROM o.order_date)
),
growth AS (
    SELECT category_name, month_num, year_num, revenue,
           LAG(revenue) OVER (PARTITION BY category_name, month_num ORDER BY year_num) AS revenue_last_year
    FROM monthly
)
SELECT category_name, month_num, year_num, revenue, revenue_last_year,
       ROUND(100.0 * (revenue - revenue_last_year) / NULLIF(revenue_last_year, 0), 2) AS yoy_growth_pct,
       CASE WHEN revenue_last_year IS NOT NULL AND revenue > revenue_last_year * 1.2 THEN 'SEASONAL_PEAK' ELSE 'NORMAL' END AS seasonality_flag
FROM growth
ORDER BY category_name, year_num, month_num;

/* Q34. */
WITH first_orders AS (
    SELECT cust_id, DATE_TRUNC('month', MIN(order_date))::date AS cohort_month FROM sales.orders GROUP BY cust_id
),
monthly AS (
    SELECT fo.cohort_month,
           (EXTRACT(YEAR FROM DATE_TRUNC('month', o.order_date)) - EXTRACT(YEAR FROM fo.cohort_month)) * 12 +
           (EXTRACT(MONTH FROM DATE_TRUNC('month', o.order_date)) - EXTRACT(MONTH FROM fo.cohort_month)) AS months_since,
           SUM(o.net_total) AS revenue
    FROM sales.orders o JOIN first_orders fo ON fo.cust_id = o.cust_id
    GROUP BY fo.cohort_month,
             (EXTRACT(YEAR FROM DATE_TRUNC('month', o.order_date)) - EXTRACT(YEAR FROM fo.cohort_month)) * 12 +
             (EXTRACT(MONTH FROM DATE_TRUNC('month', o.order_date)) - EXTRACT(MONTH FROM fo.cohort_month))
)
SELECT cohort_month, months_since, revenue,
       ROUND(100.0 * revenue / NULLIF(FIRST_VALUE(revenue) OVER (PARTITION BY cohort_month ORDER BY months_since), 0), 2) AS indexed_to_100
FROM monthly
WHERE months_since >= 0
ORDER BY cohort_month, months_since;

/* Q35. */
WITH monthly AS (
    SELECT c.category_name, DATE_TRUNC('month', o.order_date)::date AS month, SUM(oi.quantity * oi.unit_price) AS category_revenue
    FROM sales.order_items oi JOIN sales.orders o ON oi.order_id = o.order_id
    JOIN products.products p ON oi.prod_id = p.product_id JOIN core.dim_brand b ON p.brand_id = b.brand_id
    JOIN core.dim_category c ON b.category_id = c.category_id
    GROUP BY c.category_name, DATE_TRUNC('month', o.order_date)
),
totals AS (SELECT month, SUM(category_revenue) AS company_revenue FROM monthly GROUP BY month),
shares AS (
    SELECT m.category_name, m.month, 100.0 * m.category_revenue / NULLIF(t.company_revenue, 0) AS pct_of_company
    FROM monthly m JOIN totals t ON t.month = m.month
)
SELECT category_name, month, ROUND(pct_of_company, 2) AS pct_of_company,
       ROUND(pct_of_company - LAG(pct_of_company) OVER (PARTITION BY category_name ORDER BY month), 2) AS mom_share_shift_pts
FROM shares
ORDER BY category_name, month;

/* Q36. */
WITH months AS (
    SELECT generate_series('2024-04-01'::date, '2026-02-01'::date, '1 month'::interval)::date AS month
),
last_order_before AS (
    SELECT m.month, o.cust_id, MAX(o.order_date) AS last_order_before_month
    FROM months m JOIN sales.orders o ON o.order_date < m.month
    GROUP BY m.month, o.cust_id
),
churned_base AS (
    SELECT month, COUNT(*) AS churned_customers
    FROM last_order_before
    WHERE month - last_order_before_month > 90
    GROUP BY month
),
reactivations AS (
    SELECT DATE_TRUNC('month', order_date)::date AS month, COUNT(*) AS reactivated_count
    FROM (
        SELECT cust_id, order_date,
               order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date) AS gap_days
        FROM sales.orders
    ) g
    WHERE gap_days > 90
    GROUP BY DATE_TRUNC('month', order_date)
)
SELECT cb.month, cb.churned_customers, COALESCE(r.reactivated_count, 0) AS reactivated_count,
       ROUND(100.0 * COALESCE(r.reactivated_count, 0) / NULLIF(cb.churned_customers, 0), 2) AS reactivation_rate_pct
FROM churned_base cb LEFT JOIN reactivations r ON r.month = cb.month
ORDER BY cb.month;

/* Q37. */
WITH monthly AS (
    SELECT cust_id, DATE_TRUNC('month', order_date)::date AS month, SUM(net_total) AS monthly_spend
    FROM sales.orders GROUP BY cust_id, DATE_TRUNC('month', order_date)
)
SELECT cust_id, month, monthly_spend,
       SUM(monthly_spend) OVER (PARTITION BY cust_id ORDER BY month) AS cumulative_spend,
       monthly_spend - LAG(monthly_spend) OVER (PARTITION BY cust_id ORDER BY month) AS mom_delta
FROM monthly
ORDER BY cust_id, month;

/* Q38. */
WITH monthly AS (
    SELECT store_id, DATE_TRUNC('month', order_date)::date AS month, SUM(net_total) AS revenue
    FROM sales.orders GROUP BY store_id, DATE_TRUNC('month', order_date)
),
growth AS (
    SELECT store_id, month,
           ROUND(100.0 * (revenue - LAG(revenue) OVER (PARTITION BY store_id ORDER BY month))
                 / NULLIF(LAG(revenue) OVER (PARTITION BY store_id ORDER BY month), 0), 2) AS mom_pct
    FROM monthly
),
flagged AS (
    SELECT store_id, month, mom_pct, (mom_pct < 0) AS is_decline,
           ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY month) AS rn
    FROM growth WHERE mom_pct IS NOT NULL
),
grp AS (
    SELECT *, rn - ROW_NUMBER() OVER (PARTITION BY store_id, is_decline ORDER BY rn) AS grp_key
    FROM flagged
)
SELECT store_id, MIN(month) AS decline_start, MAX(month) AS decline_end, COUNT(*) AS consecutive_declining_months
FROM grp
WHERE is_decline
GROUP BY store_id, grp_key
HAVING COUNT(*) >= 3
ORDER BY store_id, decline_start;

/* Q39. */
WITH months AS (
    SELECT generate_series('2024-01-01'::date, '2026-02-01'::date, '1 month'::interval)::date AS month
),
base AS (
    SELECT r.region_id, r.region_name, m.month, COALESCE(SUM(o.net_total), 0) AS revenue
    FROM core.dim_region r CROSS JOIN months m
    LEFT JOIN stores.stores s ON s.region_id = r.region_id
    LEFT JOIN sales.orders o ON o.store_id = s.store_id AND DATE_TRUNC('month', o.order_date) = m.month
    GROUP BY r.region_id, r.region_name, m.month
)
SELECT region_id, region_name, month, revenue,
       LAG(revenue, 12) OVER (PARTITION BY region_id ORDER BY month) AS revenue_last_year,
       revenue - LAG(revenue, 12) OVER (PARTITION BY region_id ORDER BY month) AS yoy_abs_change,
       ROUND(100.0 * (revenue - LAG(revenue, 12) OVER (PARTITION BY region_id ORDER BY month))
             / NULLIF(LAG(revenue, 12) OVER (PARTITION BY region_id ORDER BY month), 0), 2) AS yoy_pct_change
FROM base
ORDER BY region_id, month;

/* Q40. */
WITH monthly AS (
    SELECT store_id, DATE_TRUNC('month', order_date)::date AS month,
           SUM(net_total) / COUNT(*) AS aov
    FROM sales.orders GROUP BY store_id, DATE_TRUNC('month', order_date)
),
growth AS (
    SELECT store_id, month, aov,
           (aov > LAG(aov) OVER (PARTITION BY store_id ORDER BY month)) AS is_up,
           ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY month) AS rn
    FROM monthly
),
grp AS (
    SELECT *, rn - ROW_NUMBER() OVER (PARTITION BY store_id, is_up ORDER BY rn) AS grp_key
    FROM growth
),
streaks AS (
    SELECT store_id, grp_key, is_up, COUNT(*) AS streak_length, MAX(month) AS streak_end
    FROM grp WHERE is_up IS NOT NULL
    GROUP BY store_id, grp_key, is_up
)
SELECT g.store_id, g.month, ROUND(g.aov, 2) AS aov,
       ROUND(100.0 * (g.aov - LAG(g.aov) OVER (PARTITION BY g.store_id ORDER BY g.month))
             / NULLIF(LAG(g.aov) OVER (PARTITION BY g.store_id ORDER BY g.month), 0), 2) AS mom_aov_growth_pct,
       s.streak_length AS current_streak_length, s.is_up AS streak_is_up
FROM growth g
LEFT JOIN streaks s ON s.store_id = g.store_id AND s.streak_end = g.month
ORDER BY g.store_id, g.month;

/* Q41. */
WITH numbered AS (
    SELECT cust_id, order_date,
           MIN(order_date) OVER (PARTITION BY cust_id) AS first_order_date,
           LEAD(order_date) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS second_order_date
    FROM sales.orders
),
first_rows AS (
    SELECT cust_id, first_order_date, second_order_date,
           DATE_TRUNC('month', first_order_date)::date AS cohort_month,
           second_order_date - first_order_date AS days_to_second_order
    FROM numbered WHERE order_date = first_order_date
)
SELECT cohort_month,
       CASE WHEN days_to_second_order IS NULL THEN 'never'
            WHEN days_to_second_order <= 30 THEN '0-30 days'
            WHEN days_to_second_order <= 90 THEN '31-90 days'
            WHEN days_to_second_order <= 180 THEN '91-180 days'
            ELSE '180+ days' END AS days_to_second_order_bucket,
       COUNT(*) AS customers
FROM first_rows
GROUP BY cohort_month, days_to_second_order_bucket
ORDER BY cohort_month, days_to_second_order_bucket;

/* Q42. */
WITH monthly_cat AS (
    SELECT c.category_name, DATE_TRUNC('month', o.order_date)::date AS month, SUM(oi.quantity * oi.unit_price) AS revenue
    FROM sales.order_items oi JOIN sales.orders o ON oi.order_id = o.order_id
    JOIN products.products p ON oi.prod_id = p.product_id JOIN core.dim_brand b ON p.brand_id = b.brand_id
    JOIN core.dim_category c ON b.category_id = c.category_id
    GROUP BY c.category_name, DATE_TRUNC('month', o.order_date)
),
deltas AS (
    SELECT category_name, month, revenue,
           revenue - LAG(revenue) OVER (PARTITION BY category_name ORDER BY month) AS category_delta
    FROM monthly_cat
),
company AS (SELECT month, SUM(category_delta) AS company_delta FROM deltas GROUP BY month)
SELECT d.category_name, d.month, d.category_delta, c.company_delta,
       ROUND(100.0 * d.category_delta / NULLIF(c.company_delta, 0), 2) AS pct_of_company_change
FROM deltas d JOIN company c ON c.month = d.month
WHERE d.category_delta IS NOT NULL
ORDER BY d.month, pct_of_company_change DESC;

/* Q43. */
WITH first_orders AS (
    SELECT cust_id, DATE_TRUNC('month', MIN(order_date))::date AS cohort_month FROM sales.orders GROUP BY cust_id
),
cohort_size AS (SELECT cohort_month, COUNT(*) AS cohort_customers FROM first_orders GROUP BY cohort_month),
snapshot AS (SELECT MAX(order_date) AS as_of_date FROM sales.orders),
last_orders AS (SELECT cust_id, MAX(order_date) AS last_order_date FROM sales.orders GROUP BY cust_id),
retention AS (
    SELECT fo.cohort_month,
           COUNT(*) FILTER (WHERE s.as_of_date - lo.last_order_date <= 30) AS active_30d,
           COUNT(*) FILTER (WHERE s.as_of_date - lo.last_order_date <= 60) AS active_60d,
           COUNT(*) FILTER (WHERE s.as_of_date - lo.last_order_date <= 90) AS active_90d
    FROM first_orders fo
    JOIN last_orders lo ON lo.cust_id = fo.cust_id
    CROSS JOIN snapshot s
    GROUP BY fo.cohort_month
)
SELECT r.cohort_month, cs.cohort_customers, r.active_30d, r.active_60d, r.active_90d,
       ROUND(100.0 * r.active_30d / NULLIF(cs.cohort_customers, 0), 2) AS retention_30d_pct,
       ROUND(100.0 * r.active_60d / NULLIF(cs.cohort_customers, 0), 2) AS retention_60d_pct,
       ROUND(100.0 * r.active_90d / NULLIF(cs.cohort_customers, 0), 2) AS retention_90d_pct
FROM retention r JOIN cohort_size cs ON cs.cohort_month = r.cohort_month
ORDER BY r.cohort_month;

/* Q44. */
WITH gaps AS (
    SELECT cust_id, order_date,
           LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date) AS prev_order_date,
           order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date) AS gap_days
    FROM sales.orders
),
churn_events AS (
    SELECT DATE_TRUNC('month', prev_order_date + 90)::date AS churn_month
    FROM gaps WHERE gap_days > 90
),
reactivation_events AS (
    SELECT DATE_TRUNC('month', order_date)::date AS reactivation_month
    FROM gaps WHERE gap_days > 90
),
churn_counts AS (SELECT churn_month AS month, COUNT(*) AS churn_count FROM churn_events GROUP BY churn_month),
react_counts AS (SELECT reactivation_month AS month, COUNT(*) AS reactivation_count FROM reactivation_events GROUP BY reactivation_month)
SELECT COALESCE(cc.month, rc.month) AS month, COALESCE(cc.churn_count, 0) AS churn_count, COALESCE(rc.reactivation_count, 0) AS reactivation_count
FROM churn_counts cc
FULL OUTER JOIN react_counts rc ON rc.month = cc.month
ORDER BY month;

/* Q45. */
WITH monthly AS (
    SELECT oi.prod_id AS product_id, DATE_TRUNC('month', o.order_date)::date AS month, SUM(oi.quantity) AS units
    FROM sales.order_items oi JOIN sales.orders o ON oi.order_id = o.order_id
    GROUP BY oi.prod_id, DATE_TRUNC('month', o.order_date)
),
growth AS (
    SELECT product_id, month, units,
           LAG(units, 12) OVER (PARTITION BY product_id ORDER BY month) AS units_last_year,
           ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY month DESC) AS rn
    FROM monthly
)
SELECT product_id, month, units, units_last_year,
       ROUND(100.0 * (units - units_last_year) / NULLIF(units_last_year, 0), 2) AS yoy_growth_pct
FROM growth
WHERE rn = 1 AND units_last_year IS NOT NULL
ORDER BY yoy_growth_pct DESC
LIMIT 10;

/* Q46. */
WITH first_orders AS (SELECT cust_id, DATE_TRUNC('month', MIN(order_date))::date AS cohort_month FROM sales.orders GROUP BY cust_id),
monthly AS (
    SELECT fo.cohort_month, DATE_TRUNC('month', o.order_date)::date AS month, SUM(o.net_total) AS revenue
    FROM sales.orders o JOIN first_orders fo ON fo.cust_id = o.cust_id
    GROUP BY fo.cohort_month, DATE_TRUNC('month', o.order_date)
)
SELECT cohort_month, month, revenue,
       ROUND(100.0 * revenue / NULLIF(LAG(revenue) OVER (PARTITION BY cohort_month ORDER BY month), 0), 2) AS nrr_proxy_pct
FROM monthly
ORDER BY cohort_month, month;

/* Q47. */
WITH monthly AS (
    SELECT o.store_id, DATE_TRUNC('month', o.order_date)::date AS month,
           SUM(oi.quantity * oi.unit_price) - SUM(oi.quantity * p.cost_price) AS profit
    FROM sales.order_items oi JOIN sales.orders o ON oi.order_id = o.order_id
    JOIN products.products p ON oi.prod_id = p.product_id
    GROUP BY o.store_id, DATE_TRUNC('month', o.order_date)
),
numbered AS (
    SELECT store_id, month, (profit > 0) AS profitable,
           (EXTRACT(YEAR FROM month) * 12 + EXTRACT(MONTH FROM month))::int AS month_num,
           ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY month) AS rn
    FROM monthly
),
grp AS (
    SELECT *, month_num - ROW_NUMBER() OVER (PARTITION BY store_id, profitable ORDER BY month_num) AS grp_key
    FROM numbered
),
islands AS (
    SELECT store_id, grp_key, MIN(month) AS island_start, MAX(month) AS island_end
    FROM grp WHERE profitable GROUP BY store_id, grp_key
),
latest_per_store AS (SELECT store_id, MAX(month) AS latest_month FROM monthly GROUP BY store_id)
SELECT i.store_id, i.island_start AS turned_profitable_month
FROM islands i
JOIN latest_per_store lp ON lp.store_id = i.store_id AND i.island_end = lp.latest_month
ORDER BY i.store_id;

/* Q48. */
WITH monthly AS (
    SELECT c.category_name, DATE_TRUNC('month', o.order_date)::date AS month, SUM(oi.quantity * oi.unit_price) AS revenue
    FROM sales.order_items oi JOIN sales.orders o ON oi.order_id = o.order_id
    JOIN products.products p ON oi.prod_id = p.product_id JOIN core.dim_brand b ON p.brand_id = b.brand_id
    JOIN core.dim_category c ON b.category_id = c.category_id
    GROUP BY c.category_name, DATE_TRUNC('month', o.order_date)
),
bounds AS (
    SELECT category_name,
           FIRST_VALUE(revenue) OVER (PARTITION BY category_name ORDER BY month) AS first_month_revenue,
           LAST_VALUE(revenue) OVER (PARTITION BY category_name ORDER BY month
               ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_month_revenue
    FROM monthly
)
SELECT DISTINCT category_name, first_month_revenue, last_month_revenue,
       ROUND(100.0 * (last_month_revenue - first_month_revenue) / NULLIF(first_month_revenue, 0), 2) AS total_growth_pct,
       RANK() OVER (ORDER BY (last_month_revenue - first_month_revenue) / NULLIF(first_month_revenue, 0) DESC) AS growth_rank
FROM bounds
ORDER BY growth_rank;

/* Q49. */
WITH monthly AS (
    SELECT cust_id, DATE_TRUNC('month', order_date)::date AS month, SUM(net_total) AS spend
    FROM sales.orders GROUP BY cust_id, DATE_TRUNC('month', order_date)
),
momentum AS (
    SELECT cust_id, month,
           SUM(spend) OVER (PARTITION BY cust_id ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS recent_3mo,
           SUM(spend) OVER (PARTITION BY cust_id ORDER BY month ROWS BETWEEN 5 PRECEDING AND 3 PRECEDING) AS prior_3mo
    FROM monthly
)
SELECT cust_id, month, recent_3mo, prior_3mo,
       ROUND(100.0 * (recent_3mo - prior_3mo) / NULLIF(prior_3mo, 0), 2) AS momentum_pct
FROM momentum
WHERE prior_3mo IS NOT NULL
ORDER BY cust_id, month;

/* Q50. */
WITH months AS (SELECT generate_series('2024-01-01'::date, '2026-02-01'::date, '1 month'::interval)::date AS month),
base AS (
    SELECT r.region_id, r.region_name, m.month,
           COALESCE(SUM(o.net_total), 0) AS revenue,
           COUNT(DISTINCT o.cust_id) AS active_customers,
           COUNT(o.order_id) AS order_count
    FROM core.dim_region r CROSS JOIN months m
    LEFT JOIN stores.stores s ON s.region_id = r.region_id
    LEFT JOIN sales.orders o ON o.store_id = s.store_id AND DATE_TRUNC('month', o.order_date) = m.month
    GROUP BY r.region_id, r.region_name, m.month
),
pack AS (
    SELECT region_id, region_name, month, revenue, active_customers, order_count,
           revenue / NULLIF(order_count, 0) AS aov,
           LAG(revenue) OVER (PARTITION BY region_id ORDER BY month) AS prev_m_revenue,
           LAG(revenue, 12) OVER (PARTITION BY region_id ORDER BY month) AS prev_y_revenue
    FROM base
)
SELECT region_id, region_name, month, revenue, active_customers, ROUND(aov, 2) AS aov,
       ROUND(100.0 * (revenue - prev_m_revenue) / NULLIF(prev_m_revenue, 0), 2) AS mom_growth_pct,
       ROUND(100.0 * (revenue - prev_y_revenue) / NULLIF(prev_y_revenue, 0), 2) AS yoy_growth_pct,
       CASE WHEN revenue > prev_m_revenue THEN 'UP' WHEN revenue < prev_m_revenue THEN 'DOWN' ELSE 'FLAT' END AS trend_flag
FROM pack
ORDER BY region_id, month;

/* ============================================================
   SECTION C: GAPS-AND-ISLANDS & SESSIONS AT SCALE (25)
   ------------------------------------------------------------ */
/* Q51. */
WITH ordered AS (
    SELECT customer_id, view_id, view_timestamp,
           EXTRACT(EPOCH FROM (view_timestamp - LAG(view_timestamp) OVER (PARTITION BY customer_id ORDER BY view_timestamp))) / 60 AS gap_minutes
    FROM web_events.page_views
    WHERE customer_id IS NOT NULL
),
flagged AS (
    SELECT *, (gap_minutes IS NULL OR gap_minutes > 30) AS new_session FROM ordered
),
sessioned AS (
    SELECT customer_id, view_id, view_timestamp,
           SUM(CASE WHEN new_session THEN 1 ELSE 0 END) OVER (PARTITION BY customer_id ORDER BY view_timestamp) AS session_id
    FROM flagged
)
SELECT customer_id, session_id,
       MIN(view_timestamp) AS session_start, MAX(view_timestamp) AS session_end,
       EXTRACT(EPOCH FROM (MAX(view_timestamp) - MIN(view_timestamp))) / 60 AS session_duration_minutes,
       COUNT(*) AS view_count
FROM sessioned
GROUP BY customer_id, session_id
ORDER BY customer_id, session_id;

/* Q52. */
WITH monthly AS (
    SELECT cust_id, DATE_TRUNC('month', order_date)::date AS month FROM sales.orders GROUP BY cust_id, DATE_TRUNC('month', order_date)
),
numbered AS (
    SELECT cust_id, month, (EXTRACT(YEAR FROM month) * 12 + EXTRACT(MONTH FROM month))::int AS month_num,
           ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY month) AS rn
    FROM monthly
),
lengths AS (
    SELECT cust_id, (month_num - rn) AS island_key, COUNT(*) AS streak_length
    FROM numbered GROUP BY cust_id, (month_num - rn)
)
SELECT cust_id, MAX(streak_length) AS longest_active_month_streak
FROM lengths GROUP BY cust_id
ORDER BY longest_active_month_streak DESC, cust_id;

/* Q53. */
WITH ordered AS (
    SELECT warehouse_id, product_id, snapshot_date, quantity_on_hand,
           (quantity_on_hand > 0) AS in_stock,
           ROW_NUMBER() OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date) AS rn
    FROM supply_chain.inventory_snapshots
),
grp AS (
    SELECT *, rn - ROW_NUMBER() OVER (PARTITION BY warehouse_id, product_id, in_stock ORDER BY rn) AS grp_key
    FROM ordered
)
SELECT warehouse_id, product_id, MIN(snapshot_date) AS period_start, MAX(snapshot_date) AS period_end, COUNT(*) AS days_in_stock
FROM grp
WHERE in_stock
GROUP BY warehouse_id, product_id, grp_key
ORDER BY warehouse_id, product_id, period_start;

/* Q54. */
WITH store_dates AS (
    SELECT DISTINCT store_id, order_date FROM sales.orders
),
numbered AS (
    SELECT store_id, order_date, ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY order_date) AS rn
    FROM store_dates
),
islands AS (
    SELECT store_id, order_date, order_date - (rn || ' days')::interval AS island_key FROM numbered
)
SELECT store_id, MIN(order_date) AS streak_start, MAX(order_date) AS streak_end, COUNT(*) AS streak_length_days
FROM islands
GROUP BY store_id, island_key
ORDER BY store_id, streak_start;

/* Q55. */
SELECT customer_id, tier,
       COALESCE(tier_updated_at::date, registration_date) AS interval_start,
       CURRENT_DATE AS interval_end,
       CURRENT_DATE - COALESCE(tier_updated_at::date, registration_date) AS interval_length_days
FROM customers.customers
ORDER BY customer_id;

/* Q56. */
WITH funnel AS (
    SELECT session_id, page_url, view_timestamp,
           CASE WHEN page_url LIKE '/product/%' THEN 'product'
                WHEN page_url = '/cart' THEN 'cart'
                WHEN page_url = '/checkout' THEN 'checkout' END AS funnel_step
    FROM web_events.page_views
    WHERE page_url LIKE '/product/%' OR page_url IN ('/cart', '/checkout')
),
ordered AS (
    SELECT session_id, funnel_step, view_timestamp,
           LEAD(funnel_step) OVER (PARTITION BY session_id ORDER BY view_timestamp) AS next_step,
           LEAD(view_timestamp) OVER (PARTITION BY session_id ORDER BY view_timestamp) AS next_time
    FROM funnel
),
steps AS (
    SELECT EXTRACT(EPOCH FROM (next_time - view_timestamp)) / 60 AS minutes_to_next_step
    FROM ordered
    WHERE (funnel_step = 'product' AND next_step = 'cart') OR (funnel_step = 'cart' AND next_step = 'checkout')
)
SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY minutes_to_next_step) AS median_minutes_page_to_checkout
FROM steps;

/* Q57. */
WITH ordered AS (
    SELECT cust_id, order_date,
           order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date) AS gap_days,
           ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date) AS rn
    FROM sales.orders
),
flagged AS (
    SELECT *, (gap_days IS NULL OR gap_days > 90) AS new_island FROM ordered
),
grp AS (
    SELECT *, SUM(CASE WHEN new_island THEN 1 ELSE 0 END) OVER (PARTITION BY cust_id ORDER BY rn) AS island_id
    FROM flagged
)
SELECT cust_id, COUNT(DISTINCT island_id) AS reactivation_islands
FROM grp
GROUP BY cust_id
ORDER BY reactivation_islands DESC, cust_id;

/* Q58. */
WITH monthly AS (
    SELECT o.store_id, DATE_TRUNC('month', o.order_date)::date AS month,
           SUM(oi.quantity * oi.unit_price) - SUM(oi.quantity * p.cost_price) AS profit
    FROM sales.order_items oi JOIN sales.orders o ON oi.order_id = o.order_id
    JOIN products.products p ON oi.prod_id = p.product_id
    GROUP BY o.store_id, DATE_TRUNC('month', o.order_date)
),
numbered AS (
    SELECT store_id, month, (profit > 0) AS profitable,
           (EXTRACT(YEAR FROM month) * 12 + EXTRACT(MONTH FROM month))::int AS month_num,
           ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY month) AS rn
    FROM monthly
),
grp AS (
    SELECT *, month_num - ROW_NUMBER() OVER (PARTITION BY store_id, profitable ORDER BY month_num) AS grp_key
    FROM numbered
),
lengths AS (
    SELECT store_id, grp_key, COUNT(*) AS run_length
    FROM grp WHERE profitable GROUP BY store_id, grp_key
)
SELECT store_id, MAX(run_length) AS longest_profitable_run_months
FROM lengths GROUP BY store_id
ORDER BY longest_profitable_run_months DESC, store_id;

/* Q59. */
WITH daily AS (
    SELECT product_id, snapshot_date, SUM(quantity_on_hand) AS total_qty
    FROM supply_chain.inventory_snapshots GROUP BY product_id, snapshot_date
),
numbered AS (
    SELECT product_id, snapshot_date, (total_qty = 0) AS out_of_stock,
           ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY snapshot_date) AS rn
    FROM daily
),
grp AS (
    SELECT *, rn - ROW_NUMBER() OVER (PARTITION BY product_id, out_of_stock ORDER BY rn) AS grp_key
    FROM numbered
)
SELECT product_id, MIN(snapshot_date) AS gap_start, MAX(snapshot_date) AS gap_end, COUNT(*) AS gap_length_days
FROM grp
WHERE out_of_stock
GROUP BY product_id, grp_key
ORDER BY product_id, gap_start;

/* Q60. */
WITH ordered AS (
    SELECT order_id, cust_id, order_date, order_status,
           ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS rn
    FROM sales.orders
),
grp AS (
    SELECT *, rn - ROW_NUMBER() OVER (PARTITION BY cust_id, order_status ORDER BY rn) AS grp_key
    FROM ordered
)
SELECT cust_id, order_status, MIN(order_date) AS run_start, MAX(order_date) AS run_end, COUNT(*) AS run_length
FROM grp
GROUP BY cust_id, order_status, grp_key
ORDER BY cust_id, run_start;

/* Q61. */
WITH cust_dates AS (
    SELECT DISTINCT customer_id, view_timestamp::date AS view_date FROM web_events.page_views WHERE customer_id IS NOT NULL
),
numbered AS (
    SELECT customer_id, view_date, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY view_date) AS rn
    FROM cust_dates
),
islands AS (
    SELECT customer_id, view_date, view_date - (rn || ' days')::interval AS island_key FROM numbered
),
lengths AS (
    SELECT customer_id, island_key, COUNT(*) AS streak_length FROM islands GROUP BY customer_id, island_key
)
SELECT customer_id, MAX(streak_length) AS longest_login_streak_days
FROM lengths GROUP BY customer_id
ORDER BY longest_login_streak_days DESC, customer_id;

/* Q62. */
WITH changes AS (
    SELECT record_id AS product_id, changed_at, new_value::numeric AS price,
           LEAD(changed_at) OVER (PARTITION BY record_id ORDER BY changed_at) AS next_change_at
    FROM audit.record_changes
    WHERE table_name = 'products' AND column_name = 'price'
)
SELECT product_id, price AS stable_price, changed_at AS period_start, next_change_at AS period_end,
       COALESCE(next_change_at::date, CURRENT_DATE) - changed_at::date AS days_stable
FROM changes
ORDER BY product_id, period_start;

/* Q63. */
WITH ordered AS (
    SELECT customer_id, call_id, call_start_time,
           EXTRACT(EPOCH FROM (call_start_time - LAG(call_start_time) OVER (PARTITION BY customer_id ORDER BY call_start_time))) / 3600 AS gap_hours
    FROM call_center.calls WHERE customer_id IS NOT NULL
),
flagged AS (SELECT *, (gap_hours IS NULL OR gap_hours > 1) AS new_burst FROM ordered),
bursts AS (
    SELECT customer_id, call_id,
           SUM(CASE WHEN new_burst THEN 1 ELSE 0 END) OVER (PARTITION BY customer_id ORDER BY call_start_time) AS burst_id
    FROM flagged
),
burst_sizes AS (SELECT customer_id, burst_id, COUNT(*) AS calls_in_burst FROM bursts GROUP BY customer_id, burst_id)
SELECT ROUND(AVG(calls_in_burst), 2) AS avg_burst_size FROM burst_sizes;

/* Q64. */
WITH months AS (
    SELECT generate_series('2024-01-01'::date, '2026-02-01'::date, '1 month'::interval)::date AS month
),
base AS (
    SELECT r.region_id, r.region_name, m.month, COALESCE(SUM(o.net_total), 0) AS revenue
    FROM core.dim_region r CROSS JOIN months m
    LEFT JOIN stores.stores s ON s.region_id = r.region_id
    LEFT JOIN sales.orders o ON o.store_id = s.store_id AND DATE_TRUNC('month', o.order_date) = m.month
    GROUP BY r.region_id, r.region_name, m.month
),
growth AS (
    SELECT region_id, region_name, month,
           (revenue > LAG(revenue) OVER (PARTITION BY region_id ORDER BY month)) AS is_positive,
           (EXTRACT(YEAR FROM month) * 12 + EXTRACT(MONTH FROM month))::int AS month_num
    FROM base
),
grp AS (
    SELECT *, month_num - ROW_NUMBER() OVER (PARTITION BY region_id, is_positive ORDER BY month_num) AS grp_key
    FROM growth
)
SELECT region_id, region_name, MIN(month) AS streak_start, MAX(month) AS streak_end, COUNT(*) AS streak_length_months
FROM grp
WHERE is_positive
GROUP BY region_id, region_name, grp_key
ORDER BY region_id, streak_start;

/* Q65. */
WITH events AS (
    SELECT o.order_id, o.order_date AS event_time, 'Placed' AS status FROM sales.orders o
    UNION ALL
    SELECT p.order_id, p.payment_date, 'Paid' FROM sales.payments p WHERE p.payment_date IS NOT NULL
    UNION ALL
    SELECT sh.order_id, sh.shipped_date, 'Shipped' FROM sales.shipments sh WHERE sh.shipped_date IS NOT NULL
    UNION ALL
    SELECT sh.order_id, sh.delivered_date, 'Delivered' FROM sales.shipments sh WHERE sh.delivered_date IS NOT NULL
    UNION ALL
    SELECT r.order_id, r.return_date, 'Returned' FROM sales.returns r WHERE r.return_date IS NOT NULL
),
ordered AS (
    SELECT order_id, event_time, status,
           LEAD(event_time) OVER (PARTITION BY order_id ORDER BY event_time) AS next_event_time
    FROM events
)
SELECT order_id, status, event_time AS status_start,
       COALESCE(next_event_time, CURRENT_DATE) - event_time AS days_in_status
FROM ordered
ORDER BY order_id, status_start;

/* Q66. */
WITH ordered AS (
    SELECT product_id, review_id, review_date, (rating = 5) AS is_five,
           ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY review_date, review_id) AS rn
    FROM customers.reviews
),
grp AS (
    SELECT *, rn - ROW_NUMBER() OVER (PARTITION BY product_id, is_five ORDER BY rn) AS grp_key
    FROM ordered
),
lengths AS (
    SELECT product_id, grp_key, COUNT(*) AS run_length
    FROM grp WHERE is_five GROUP BY product_id, grp_key
)
SELECT product_id, MAX(run_length) AS longest_five_star_run
FROM lengths GROUP BY product_id
ORDER BY longest_five_star_run DESC, product_id;

/* Q67. */
SELECT session_id, BOOL_OR(page_url = '/checkout') AS reached_checkout
FROM web_events.page_views
GROUP BY session_id
ORDER BY session_id;

/* Q68. */
WITH ordered AS (
    SELECT shipment_id, courier_name, shipped_date, delivered_date,
           (delivered_date - shipped_date <= 3) AS on_time,
           ROW_NUMBER() OVER (PARTITION BY courier_name ORDER BY shipped_date, shipment_id) AS rn
    FROM sales.shipments
    WHERE shipped_date IS NOT NULL AND delivered_date IS NOT NULL
),
grp AS (
    SELECT *, rn - ROW_NUMBER() OVER (PARTITION BY courier_name, on_time ORDER BY rn) AS grp_key
    FROM ordered
)
SELECT courier_name, MIN(shipped_date) AS streak_start, MAX(shipped_date) AS streak_end, COUNT(*) AS streak_length
FROM grp
WHERE on_time
GROUP BY courier_name, grp_key
ORDER BY courier_name, streak_start;

/* Q69. */
WITH ordered AS (
    SELECT customer_id, device_type, view_timestamp,
           EXTRACT(EPOCH FROM (view_timestamp - LAG(view_timestamp) OVER (PARTITION BY customer_id, device_type ORDER BY view_timestamp))) / 60 AS gap_minutes
    FROM web_events.page_views WHERE customer_id IS NOT NULL
),
flagged AS (SELECT *, (gap_minutes IS NULL OR gap_minutes > 30) AS new_session FROM ordered),
sessioned AS (
    SELECT customer_id, device_type, view_timestamp,
           SUM(CASE WHEN new_session THEN 1 ELSE 0 END) OVER (PARTITION BY customer_id, device_type ORDER BY view_timestamp) AS session_id
    FROM flagged
),
durations AS (
    SELECT device_type, customer_id, session_id,
           EXTRACT(EPOCH FROM (MAX(view_timestamp) - MIN(view_timestamp))) / 60 AS duration_minutes
    FROM sessioned GROUP BY device_type, customer_id, session_id
),
banded AS (
    SELECT device_type,
           CASE WHEN duration_minutes < 5 THEN '<5 min' WHEN duration_minutes < 15 THEN '5-15 min'
                WHEN duration_minutes < 30 THEN '15-30 min' ELSE '30+ min' END AS length_band
    FROM durations
),
counted AS (
    SELECT device_type, length_band, COUNT(*) AS session_count,
           RANK() OVER (PARTITION BY device_type ORDER BY COUNT(*) DESC) AS rnk
    FROM banded GROUP BY device_type, length_band
)
SELECT device_type, length_band AS dominant_band, session_count
FROM counted WHERE rnk = 1
ORDER BY device_type;

/* Q70. */
WITH slips AS (
    SELECT employee_id, salary_year,
           CASE salary_month WHEN 'January' THEN 1 WHEN 'February' THEN 2 WHEN 'March' THEN 3 WHEN 'April' THEN 4
                WHEN 'May' THEN 5 WHEN 'June' THEN 6 WHEN 'July' THEN 7 WHEN 'August' THEN 8
                WHEN 'September' THEN 9 WHEN 'October' THEN 10 WHEN 'November' THEN 11 ELSE 12 END AS month_num_raw
    FROM payroll.pay_slips
    GROUP BY employee_id, salary_year, salary_month
),
numbered AS (
    SELECT employee_id, (salary_year * 12 + month_num_raw) AS month_num,
           ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY salary_year, month_num_raw) AS rn
    FROM slips
),
lengths AS (
    SELECT employee_id, (month_num - rn) AS grp_key, COUNT(*) AS run_length
    FROM numbered GROUP BY employee_id, (month_num - rn)
)
SELECT employee_id, MAX(run_length) AS longest_employment_continuity_months
FROM lengths GROUP BY employee_id
ORDER BY longest_employment_continuity_months DESC, employee_id;

/* Q71. */
WITH ordered AS (
    SELECT customer_id, view_id, view_timestamp,
           EXTRACT(EPOCH FROM (view_timestamp - LAG(view_timestamp) OVER (PARTITION BY customer_id ORDER BY view_timestamp))) / 60 AS gap_minutes
    FROM web_events.page_views WHERE customer_id IS NOT NULL
),
flagged AS (SELECT *, (gap_minutes IS NULL OR gap_minutes > 30) AS new_session FROM ordered),
sessioned AS (
    SELECT customer_id, view_id, view_timestamp,
           SUM(CASE WHEN new_session THEN 1 ELSE 0 END) OVER (PARTITION BY customer_id ORDER BY view_timestamp) AS session_id
    FROM flagged
),
session_stats AS (
    SELECT customer_id, session_id, MIN(view_timestamp)::date AS day, COUNT(*) AS view_count
    FROM sessioned GROUP BY customer_id, session_id
)
SELECT day,
       COUNT(*) FILTER (WHERE view_count = 1) AS bounce_sessions,
       COUNT(*) FILTER (WHERE view_count >= 5) AS engaged_sessions
FROM session_stats
GROUP BY day
ORDER BY day;

/* Q72. */
WITH ordered AS (
    SELECT cust_id, order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date) AS gap_days
    FROM sales.orders
),
reactivations AS (SELECT gap_days FROM ordered WHERE gap_days > 90)
SELECT CASE WHEN gap_days <= 120 THEN '91-120 days' WHEN gap_days <= 180 THEN '121-180 days'
       WHEN gap_days <= 365 THEN '181-365 days' ELSE '365+ days' END AS latency_band,
       COUNT(*) AS reactivation_count
FROM reactivations
GROUP BY latency_band
ORDER BY latency_band;

/* Q73. */
WITH daily AS (
    SELECT store_id, order_date, SUM(net_total) AS revenue FROM sales.orders GROUP BY store_id, order_date
),
numbered AS (
    SELECT store_id, order_date,
           (revenue > LAG(revenue) OVER (PARTITION BY store_id ORDER BY order_date)) AS is_win,
           ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY order_date) AS rn
    FROM daily
),
grp AS (
    SELECT *, rn - ROW_NUMBER() OVER (PARTITION BY store_id, is_win ORDER BY rn) AS grp_key
    FROM numbered
),
lengths AS (
    SELECT store_id, grp_key, COUNT(*) AS streak_length
    FROM grp WHERE is_win GROUP BY store_id, grp_key
)
SELECT store_id, MAX(streak_length) AS longest_winning_streak_days
FROM lengths GROUP BY store_id
ORDER BY longest_winning_streak_days DESC, store_id;

/* Q74. */
WITH gaps AS (
    SELECT cust_id, order_date,
           order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date) AS gap_days
    FROM sales.orders
),
cadence AS (
    SELECT cust_id, order_date, gap_days,
           LAG(gap_days) OVER (PARTITION BY cust_id ORDER BY order_date) AS prev_gap_days
    FROM gaps
),
flagged AS (
    SELECT *, CASE WHEN gap_days IS NULL OR prev_gap_days IS NULL THEN NULL
                   WHEN gap_days BETWEEN prev_gap_days * 0.5 AND prev_gap_days * 1.5 THEN TRUE
                   ELSE FALSE END AS is_stable
    FROM cadence
)
SELECT cust_id, is_stable, COUNT(*) AS orders_in_period
FROM flagged
WHERE is_stable IS NOT NULL
GROUP BY cust_id, is_stable
ORDER BY cust_id, is_stable;

/* Q75. */
WITH ordered AS (
    SELECT customer_id, view_id, view_timestamp, device_type,
           EXTRACT(EPOCH FROM (view_timestamp - LAG(view_timestamp) OVER (PARTITION BY customer_id ORDER BY view_timestamp))) / 60 AS gap_minutes
    FROM web_events.page_views WHERE customer_id IS NOT NULL
),
flagged AS (SELECT *, (gap_minutes IS NULL OR gap_minutes > 30) AS new_session FROM ordered),
sessioned AS (
    SELECT customer_id, view_id, view_timestamp, device_type,
           SUM(CASE WHEN new_session THEN 1 ELSE 0 END) OVER (PARTITION BY customer_id ORDER BY view_timestamp) AS session_id
    FROM flagged
)
SELECT customer_id, session_id,
       MIN(view_timestamp) AS session_start, MAX(view_timestamp) AS session_end,
       EXTRACT(EPOCH FROM (MAX(view_timestamp) - MIN(view_timestamp))) / 60 AS session_duration_minutes,
       COUNT(*) AS view_count,
       MIN(device_type) AS device_type
FROM sessioned
GROUP BY customer_id, session_id
ORDER BY customer_id, session_id;

/* ============================================================
   SECTION D: ANOMALY & EXECUTIVE DASHBOARDS (25)
   ------------------------------------------------------------ */
/* Q76. */
WITH daily AS (
    SELECT order_date, SUM(net_total) AS revenue FROM sales.orders GROUP BY order_date
),
stats AS (
    SELECT order_date, revenue,
           AVG(revenue) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS ma_7day,
           STDDEV(revenue) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS stddev_7day,
           LAG(revenue, 30) OVER (ORDER BY order_date) AS revenue_30d_ago
    FROM daily
)
SELECT order_date, revenue, ROUND(ma_7day, 2) AS ma_7day,
       ROUND(100.0 * (revenue - revenue_30d_ago) / NULLIF(revenue_30d_ago, 0), 2) AS mom_pct,
       ROUND((revenue - ma_7day) / NULLIF(stddev_7day, 0), 2) AS z_score,
       CASE WHEN ABS((revenue - ma_7day) / NULLIF(stddev_7day, 0)) > 2 THEN 'ANOMALY' ELSE 'NORMAL' END AS flag
FROM stats
ORDER BY order_date;

/* Q77. */
WITH daily AS (SELECT order_date, SUM(net_total) AS revenue FROM sales.orders GROUP BY order_date),
stats AS (
    SELECT order_date, revenue,
           AVG(revenue) OVER (ORDER BY order_date ROWS BETWEEN 29 PRECEDING AND 1 PRECEDING) AS ma_30day,
           STDDEV(revenue) OVER (ORDER BY order_date ROWS BETWEEN 29 PRECEDING AND 1 PRECEDING) AS stddev_30day
    FROM daily
)
SELECT order_date, revenue, ROUND(ma_30day, 2) AS ma_30day,
       ROUND((revenue - ma_30day) / NULLIF(stddev_30day, 0), 2) AS z_score
FROM stats
WHERE ABS((revenue - ma_30day) / NULLIF(stddev_30day, 0)) > 2
ORDER BY order_date;

/* Q78. */
WITH changes AS (
    SELECT record_id AS product_id, changed_at, old_value::numeric AS old_price, new_value::numeric AS new_price,
           100.0 * (new_value::numeric - old_value::numeric) / NULLIF(old_value::numeric, 0) AS pct_change
    FROM audit.record_changes
    WHERE table_name = 'products' AND column_name = 'price'
)
SELECT product_id, changed_at, old_price, new_price, ROUND(pct_change, 2) AS pct_change,
       RANK() OVER (PARTITION BY product_id ORDER BY ABS(pct_change) DESC) AS change_rank
FROM changes
ORDER BY product_id, change_rank;

/* Q79. */
WITH gaps AS (
    SELECT cust_id, order_date,
           order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date) AS gap_to_prev
    FROM sales.orders
),
last_orders AS (SELECT cust_id, MAX(order_date) AS last_order_date FROM sales.orders GROUP BY cust_id),
prior_gap AS (
    SELECT g.cust_id, g.gap_to_prev AS prior_gap
    FROM gaps g JOIN last_orders lo ON lo.cust_id = g.cust_id AND g.order_date = lo.last_order_date
)
SELECT lo.cust_id, lo.last_order_date, CURRENT_DATE - lo.last_order_date AS days_since_last_order,
       pg.prior_gap, (CURRENT_DATE - lo.last_order_date > 90) AS churn_flag
FROM last_orders lo
LEFT JOIN prior_gap pg ON pg.cust_id = lo.cust_id
ORDER BY lo.cust_id;

/* Q80. */
WITH first_orders AS (
    SELECT cust_id, DATE_TRUNC('month', MIN(order_date))::date AS cohort_month FROM sales.orders GROUP BY cust_id
),
cohort_size AS (SELECT cohort_month, COUNT(*) AS cohort_customers FROM first_orders GROUP BY cohort_month),
activity AS (
    SELECT o.cust_id, fo.cohort_month,
           (EXTRACT(YEAR FROM DATE_TRUNC('month', o.order_date)) - EXTRACT(YEAR FROM fo.cohort_month)) * 12 +
           (EXTRACT(MONTH FROM DATE_TRUNC('month', o.order_date)) - EXTRACT(MONTH FROM fo.cohort_month)) AS months_since_signup
    FROM sales.orders o JOIN first_orders fo ON fo.cust_id = o.cust_id
),
retained AS (
    SELECT cohort_month, months_since_signup, COUNT(DISTINCT cust_id) AS active_customers
    FROM activity WHERE months_since_signup >= 0
    GROUP BY cohort_month, months_since_signup
)
SELECT r.cohort_month, r.months_since_signup, r.active_customers, cs.cohort_customers,
       ROUND(100.0 * r.active_customers / NULLIF(cs.cohort_customers, 0), 2) AS retention_pct
FROM retained r JOIN cohort_size cs ON cs.cohort_month = r.cohort_month
ORDER BY r.cohort_month, r.months_since_signup;

/* Q81. */
WITH funnel AS (
    SELECT session_id, page_url,
           CASE WHEN page_url LIKE '/product/%' THEN 'product'
                WHEN page_url = '/cart' THEN 'cart'
                WHEN page_url = '/checkout' THEN 'checkout' END AS funnel_step
    FROM web_events.page_views
    WHERE page_url LIKE '/product/%' OR page_url IN ('/cart', '/checkout')
),
session_flags AS (
    SELECT session_id,
           BOOL_OR(funnel_step = 'cart') AS saw_cart,
           BOOL_OR(funnel_step = 'checkout') AS saw_checkout
    FROM funnel GROUP BY session_id
),
timing AS (
    SELECT session_id, view_timestamp,
           LEAD(view_timestamp) OVER (PARTITION BY session_id ORDER BY view_timestamp) AS next_time,
           page_url,
           LEAD(page_url) OVER (PARTITION BY session_id ORDER BY view_timestamp) AS next_url
    FROM web_events.page_views
    WHERE page_url LIKE '/product/%' OR page_url IN ('/cart', '/checkout')
)
SELECT
    (SELECT COUNT(*) FROM session_flags) AS total_sessions,
    (SELECT COUNT(*) FROM session_flags WHERE saw_cart) AS sessions_with_cart,
    (SELECT COUNT(*) FROM session_flags WHERE saw_checkout) AS sessions_with_checkout,
    ROUND(100.0 * (SELECT COUNT(*) FROM session_flags WHERE saw_cart) / NULLIF((SELECT COUNT(*) FROM session_flags), 0), 2) AS cart_rate_pct,
    ROUND(100.0 * (SELECT COUNT(*) FROM session_flags WHERE saw_checkout) / NULLIF((SELECT COUNT(*) FROM session_flags), 0), 2) AS checkout_rate_pct,
    (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (next_time - view_timestamp)) / 60)
     FROM timing WHERE next_url IN ('cart', 'checkout') OR (page_url = '/cart' AND next_url = '/checkout')) AS median_step_minutes;

/* Q82. */
WITH monthly AS (
    SELECT store_id, DATE_TRUNC('month', order_date)::date AS month, SUM(net_total) AS revenue
    FROM sales.orders GROUP BY store_id, DATE_TRUNC('month', order_date)
),
mg AS (
    SELECT store_id, month, revenue,
           ROUND(100.0 * (revenue - LAG(revenue, 1) OVER (PARTITION BY store_id ORDER BY month)) / NULLIF(LAG(revenue, 1) OVER (PARTITION BY store_id ORDER BY month), 0), 2) AS mom_pct,
           ROUND(100.0 * (revenue - LAG(revenue, 12) OVER (PARTITION BY store_id ORDER BY month)) / NULLIF(LAG(revenue, 12) OVER (PARTITION BY store_id ORDER BY month), 0), 2) AS yoy_pct
    FROM monthly
),
quarterly AS (
    SELECT store_id, DATE_TRUNC('quarter', order_date)::date AS quarter, SUM(net_total) AS q_revenue
    FROM sales.orders GROUP BY store_id, DATE_TRUNC('quarter', order_date)
),
qg AS (
    SELECT store_id, quarter,
           ROUND(100.0 * (q_revenue - LAG(q_revenue) OVER (PARTITION BY store_id ORDER BY quarter)) / NULLIF(LAG(q_revenue) OVER (PARTITION BY store_id ORDER BY quarter), 0), 2) AS qoq_pct
    FROM quarterly
),
flagged AS (
    SELECT mg.store_id, mg.month, mg.mom_pct, mg.yoy_pct, qg.qoq_pct,
           (mg.mom_pct > 0) AS is_up,
           ROW_NUMBER() OVER (PARTITION BY mg.store_id ORDER BY mg.month) AS rn
    FROM mg JOIN qg ON qg.store_id = mg.store_id AND qg.quarter = DATE_TRUNC('quarter', mg.month)::date
    WHERE mg.mom_pct IS NOT NULL
),
grp AS (
    SELECT *, rn - ROW_NUMBER() OVER (PARTITION BY store_id, is_up ORDER BY rn) AS grp_key
    FROM flagged
),
streaks AS (
    SELECT store_id, grp_key, is_up, COUNT(*) AS streak_length, MAX(month) AS streak_end
    FROM grp GROUP BY store_id, grp_key, is_up
),
latest AS (
    SELECT store_id, month, mom_pct, qoq_pct, yoy_pct, ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY month DESC) AS rn2
    FROM flagged
)
SELECT l.store_id, l.month, l.mom_pct, l.qoq_pct, l.yoy_pct,
       s.streak_length AS current_streak_length, s.is_up AS streak_is_up,
       ROUND(PERCENT_RANK() OVER (ORDER BY l.mom_pct)::numeric, 2) AS growth_percentile
FROM latest l
LEFT JOIN streaks s ON s.store_id = l.store_id AND s.streak_end = l.month
WHERE l.rn2 = 1
ORDER BY growth_percentile DESC;

/* Q83. */
WITH daily AS (
    SELECT oi.prod_id AS product_id, o.order_date, SUM(oi.quantity) AS units
    FROM sales.order_items oi JOIN sales.orders o ON oi.order_id = o.order_id
    GROUP BY oi.prod_id, o.order_date
),
trailing_units AS (
    SELECT product_id, order_date, units,
           AVG(units) OVER (PARTITION BY product_id ORDER BY order_date ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING) AS trailing_7avg
    FROM daily
)
SELECT product_id, order_date, units, ROUND(trailing_7avg, 2) AS trailing_7avg
FROM trailing_units
WHERE trailing_7avg IS NOT NULL AND units > 3 * trailing_7avg
ORDER BY product_id, order_date;

/* Q84. */
WITH gaps AS (
    SELECT cust_id, order_date,
           LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date) AS prev_order_date,
           order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date) AS gap_days
    FROM sales.orders
),
churn_events AS (SELECT DATE_TRUNC('month', prev_order_date + 90)::date AS churn_month FROM gaps WHERE gap_days > 90),
reactivation_events AS (SELECT DATE_TRUNC('month', order_date)::date AS reactivation_month FROM gaps WHERE gap_days > 90),
churn_counts AS (SELECT churn_month AS month, COUNT(*) AS churned FROM churn_events GROUP BY churn_month),
react_counts AS (SELECT reactivation_month AS month, COUNT(*) AS reactivated FROM reactivation_events GROUP BY reactivation_month)
SELECT COALESCE(cc.month, rc.month) AS month, COALESCE(cc.churned, 0) AS churned, COALESCE(rc.reactivated, 0) AS reactivated,
       COALESCE(rc.reactivated, 0) - COALESCE(cc.churned, 0) AS net
FROM churn_counts cc
FULL OUTER JOIN react_counts rc ON rc.month = cc.month
ORDER BY month;

/* Q85. */
WITH monthly AS (
    SELECT courier_name, DATE_TRUNC('month', shipped_date)::date AS month, AVG(delivered_date - shipped_date) AS avg_delivery_days
    FROM sales.shipments
    WHERE shipped_date IS NOT NULL AND delivered_date IS NOT NULL
    GROUP BY courier_name, DATE_TRUNC('month', shipped_date)
),
flagged AS (
    SELECT courier_name, month, avg_delivery_days,
           (avg_delivery_days > LAG(avg_delivery_days) OVER (PARTITION BY courier_name ORDER BY month)) AS is_worse,
           ROW_NUMBER() OVER (PARTITION BY courier_name ORDER BY month) AS rn
    FROM monthly
),
grp AS (
    SELECT *, rn - ROW_NUMBER() OVER (PARTITION BY courier_name, is_worse ORDER BY rn) AS grp_key
    FROM flagged
)
SELECT courier_name, MIN(month) AS degradation_start, MAX(month) AS degradation_end, COUNT(*) AS consecutive_months_worse
FROM grp
WHERE is_worse
GROUP BY courier_name, grp_key
HAVING COUNT(*) >= 3
ORDER BY courier_name, degradation_start;

/* Q86. */
WITH ordered AS (
    SELECT product_id, warehouse_id, snapshot_date, quantity_on_hand,
           quantity_on_hand - LAG(quantity_on_hand) OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date) AS delta
    FROM supply_chain.inventory_snapshots
)
SELECT product_id,
       ROUND(STDDEV(delta), 2) AS delta_stddev,
       COUNT(*) FILTER (WHERE quantity_on_hand = 0) AS stockout_snapshots
FROM ordered
GROUP BY product_id
ORDER BY delta_stddev DESC NULLS LAST;

/* Q87. */
WITH monthly AS (
    SELECT cust_id, DATE_TRUNC('month', order_date)::date AS month, SUM(net_total) AS spend
    FROM sales.orders GROUP BY cust_id, DATE_TRUNC('month', order_date)
),
momentum AS (
    SELECT cust_id, month,
           SUM(spend) OVER (PARTITION BY cust_id ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS recent_3mo,
           SUM(spend) OVER (PARTITION BY cust_id ORDER BY month ROWS BETWEEN 5 PRECEDING AND 3 PRECEDING) AS prior_3mo,
           ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY month DESC) AS rn
    FROM monthly
),
last_orders AS (SELECT cust_id, MAX(order_date) AS last_order_date FROM sales.orders GROUP BY cust_id)
SELECT m.cust_id,
       ROUND(100.0 * (m.recent_3mo - m.prior_3mo) / NULLIF(m.prior_3mo, 0), 2) AS momentum_pct,
       lo.last_order_date, CURRENT_DATE - lo.last_order_date AS days_since_last_order,
       (CURRENT_DATE - lo.last_order_date > 90) AS churn_risk
FROM momentum m
JOIN last_orders lo ON lo.cust_id = m.cust_id
WHERE m.rn = 1
ORDER BY m.cust_id;

/* Q88. */
WITH monthly AS (
    SELECT c.category_name, DATE_TRUNC('month', o.order_date)::date AS month, SUM(oi.quantity * oi.unit_price) AS category_revenue
    FROM sales.order_items oi JOIN sales.orders o ON oi.order_id = o.order_id
    JOIN products.products p ON oi.prod_id = p.product_id JOIN core.dim_brand b ON p.brand_id = b.brand_id
    JOIN core.dim_category c ON b.category_id = c.category_id
    GROUP BY c.category_name, DATE_TRUNC('month', o.order_date)
),
totals AS (SELECT month, SUM(category_revenue) AS company_revenue FROM monthly GROUP BY month),
shares AS (
    SELECT m.category_name, m.month, 100.0 * m.category_revenue / NULLIF(t.company_revenue, 0) AS pct_of_company
    FROM monthly m JOIN totals t ON t.month = m.month
)
SELECT category_name, month, ROUND(pct_of_company, 2) AS pct_of_company,
       ROUND(pct_of_company - LAG(pct_of_company) OVER (PARTITION BY category_name ORDER BY month), 2) AS share_shift_pts,
       CASE WHEN pct_of_company > LAG(pct_of_company) OVER (PARTITION BY category_name ORDER BY month) THEN 'GAINED_SHARE'
            WHEN pct_of_company < LAG(pct_of_company) OVER (PARTITION BY category_name ORDER BY month) THEN 'LOST_SHARE'
            ELSE 'FLAT' END AS waterfall_direction
FROM shares
ORDER BY month, share_shift_pts DESC;

/* Q89. */
WITH daily AS (
    SELECT agent_id, resolved_date::date AS resolve_day, COUNT(*) AS resolved_count
    FROM support.tickets WHERE resolved_date IS NOT NULL
    GROUP BY agent_id, resolved_date::date
),
monthly AS (
    SELECT agent_id, DATE_TRUNC('month', resolve_day)::date AS month, SUM(resolved_count) AS resolved_total
    FROM daily GROUP BY agent_id, DATE_TRUNC('month', resolve_day)
),
growth AS (
    SELECT agent_id, month, resolved_total,
           (resolved_total > LAG(resolved_total) OVER (PARTITION BY agent_id ORDER BY month)) AS is_up,
           ROW_NUMBER() OVER (PARTITION BY agent_id ORDER BY month) AS rn
    FROM monthly
),
grp AS (
    SELECT *, rn - ROW_NUMBER() OVER (PARTITION BY agent_id, is_up ORDER BY rn) AS grp_key
    FROM growth
),
streaks AS (
    SELECT agent_id, grp_key, COUNT(*) AS streak_length, MAX(month) AS streak_end
    FROM grp WHERE is_up GROUP BY agent_id, grp_key
)
SELECT g.agent_id, g.month, g.resolved_total,
       ROUND(100.0 * (g.resolved_total - LAG(g.resolved_total) OVER (PARTITION BY g.agent_id ORDER BY g.month))
             / NULLIF(LAG(g.resolved_total) OVER (PARTITION BY g.agent_id ORDER BY g.month), 0), 2) AS mom_growth_pct,
       s.streak_length AS current_up_streak
FROM growth g
LEFT JOIN streaks s ON s.agent_id = g.agent_id AND s.streak_end = g.month
ORDER BY g.agent_id, g.month;

/* Q90. */
WITH ordered AS (
    SELECT cust_id, order_id, order_date, net_total,
           AVG(net_total) OVER (PARTITION BY cust_id ORDER BY order_date, order_id ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS trailing_avg
    FROM sales.orders
)
SELECT cust_id, order_id, order_date, net_total, ROUND(trailing_avg, 2) AS trailing_avg
FROM ordered
WHERE trailing_avg IS NOT NULL AND net_total > 2 * trailing_avg
ORDER BY cust_id, order_date;

/* Q91. */
WITH ordered AS (
    SELECT customer_id, device_type, view_id, view_timestamp,
           EXTRACT(EPOCH FROM (view_timestamp - LAG(view_timestamp) OVER (PARTITION BY customer_id, device_type ORDER BY view_timestamp))) / 60 AS gap_minutes
    FROM web_events.page_views WHERE customer_id IS NOT NULL
),
flagged AS (SELECT *, (gap_minutes IS NULL OR gap_minutes > 30) AS new_session FROM ordered),
sessioned AS (
    SELECT customer_id, device_type, view_timestamp,
           SUM(CASE WHEN new_session THEN 1 ELSE 0 END) OVER (PARTITION BY customer_id, device_type ORDER BY view_timestamp) AS session_id
    FROM flagged
),
sessions AS (
    SELECT device_type, MIN(view_timestamp)::date AS day, customer_id, session_id,
           EXTRACT(EPOCH FROM (MAX(view_timestamp) - MIN(view_timestamp))) / 60 AS duration_minutes
    FROM sessioned GROUP BY device_type, customer_id, session_id
),
daily AS (
    SELECT device_type, day, COUNT(*) AS sessions_per_day, AVG(duration_minutes) AS avg_duration_minutes
    FROM sessions GROUP BY device_type, day
)
SELECT device_type, day, sessions_per_day, ROUND(avg_duration_minutes, 2) AS avg_duration_minutes,
       ROUND(100.0 * (sessions_per_day - LAG(sessions_per_day) OVER (PARTITION BY device_type ORDER BY day))
             / NULLIF(LAG(sessions_per_day) OVER (PARTITION BY device_type ORDER BY day), 0), 2) AS dod_growth_pct
FROM daily
ORDER BY device_type, day;

/* Q92. */
WITH monthly AS (
    SELECT c.category_name, DATE_TRUNC('month', o.order_date)::date AS month,
           COUNT(DISTINCT r.return_id)::numeric / NULLIF(COUNT(DISTINCT oi.order_item_id), 0) AS refund_rate
    FROM sales.order_items oi
    JOIN sales.orders o ON oi.order_id = o.order_id
    JOIN products.products p ON oi.prod_id = p.product_id
    JOIN core.dim_brand b ON p.brand_id = b.brand_id
    JOIN core.dim_category c ON b.category_id = c.category_id
    LEFT JOIN sales.returns r ON r.order_id = o.order_id AND r.prod_id = oi.prod_id
    GROUP BY c.category_name, DATE_TRUNC('month', o.order_date)
),
growth AS (
    SELECT category_name, month, refund_rate,
           refund_rate - LAG(refund_rate) OVER (PARTITION BY category_name ORDER BY month) AS mom_refund_rate_change
    FROM monthly
)
SELECT category_name, month, ROUND(refund_rate, 4) AS refund_rate, ROUND(mom_refund_rate_change, 4) AS mom_refund_rate_change
FROM growth
WHERE mom_refund_rate_change > 0.02
ORDER BY category_name, month;

/* Q93. */
WITH monthly AS (
    SELECT r.region_name, EXTRACT(MONTH FROM o.order_date)::int AS month_num, EXTRACT(YEAR FROM o.order_date)::int AS year_num, SUM(o.net_total) AS revenue
    FROM sales.orders o
    JOIN stores.stores s ON o.store_id = s.store_id
    JOIN core.dim_region r ON s.region_id = r.region_id
    GROUP BY r.region_name, EXTRACT(MONTH FROM o.order_date), EXTRACT(YEAR FROM o.order_date)
)
SELECT region_name, month_num, year_num, revenue,
       ROUND(100.0 * revenue / NULLIF(FIRST_VALUE(revenue) OVER (PARTITION BY region_name, month_num ORDER BY year_num), 0), 2) AS yoy_index_to_100
FROM monthly
ORDER BY region_name, month_num, year_num;

/* Q94. */
WITH monthly AS (
    SELECT oi.prod_id AS product_id, DATE_TRUNC('month', o.order_date)::date AS month, SUM(oi.quantity) AS units
    FROM sales.order_items oi JOIN sales.orders o ON oi.order_id = o.order_id
    GROUP BY oi.prod_id, DATE_TRUNC('month', o.order_date)
),
growth AS (
    SELECT product_id, month, units,
           LAG(units, 12) OVER (PARTITION BY product_id ORDER BY month) AS units_last_year,
           ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY month DESC) AS rn
    FROM monthly
)
SELECT product_id, month, units, units_last_year,
       ROUND(100.0 * (units - units_last_year) / NULLIF(units_last_year, 0), 2) AS yoy_growth_pct
FROM growth
WHERE rn = 1 AND units_last_year IS NOT NULL
ORDER BY yoy_growth_pct ASC
LIMIT 10;

/* Q95. */
WITH first_orders AS (SELECT cust_id, MIN(order_date) AS first_order_date FROM sales.orders GROUP BY cust_id),
monthly AS (
    SELECT DATE_TRUNC('month', first_order_date)::date AS month, COUNT(*) AS new_customers
    FROM first_orders GROUP BY DATE_TRUNC('month', first_order_date)
)
SELECT month, new_customers,
       ROUND(100.0 * (new_customers - LAG(new_customers, 1) OVER (ORDER BY month)) / NULLIF(LAG(new_customers, 1) OVER (ORDER BY month), 0), 2) AS mom_growth_pct,
       ROUND(100.0 * (new_customers - LAG(new_customers, 12) OVER (ORDER BY month)) / NULLIF(LAG(new_customers, 12) OVER (ORDER BY month), 0), 2) AS yoy_growth_pct
FROM monthly
ORDER BY month;

/* Q96. */
WITH months AS (SELECT generate_series('2024-01-01'::date, '2026-02-01'::date, '1 month'::interval)::date AS month),
base AS (
    SELECT r.region_id, r.region_name, m.month, COALESCE(SUM(o.net_total), 0) AS revenue
    FROM core.dim_region r CROSS JOIN months m
    LEFT JOIN stores.stores s ON s.region_id = r.region_id
    LEFT JOIN sales.orders o ON o.store_id = s.store_id AND DATE_TRUNC('month', o.order_date) = m.month
    GROUP BY r.region_id, r.region_name, m.month
),
pack AS (
    SELECT region_id, region_name, month, revenue,
           LAG(revenue) OVER (PARTITION BY region_id ORDER BY month) AS prev_m_revenue,
           LAG(revenue, 12) OVER (PARTITION BY region_id ORDER BY month) AS prev_y_revenue,
           AVG(revenue) OVER (PARTITION BY region_id ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ma_3mo,
           STDDEV(revenue) OVER (PARTITION BY region_id ORDER BY month ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS stddev_6mo
    FROM base
)
SELECT region_id, region_name, month, revenue, ROUND(ma_3mo, 2) AS ma_3mo,
       ROUND(100.0 * (revenue - prev_m_revenue) / NULLIF(prev_m_revenue, 0), 2) AS mom_growth_pct,
       ROUND(100.0 * (revenue - prev_y_revenue) / NULLIF(prev_y_revenue, 0), 2) AS yoy_growth_pct,
       CASE WHEN ABS((revenue - ma_3mo) / NULLIF(stddev_6mo, 0)) > 2 THEN 'ANOMALY' ELSE 'NORMAL' END AS anomaly_flag
FROM pack
ORDER BY region_id, month;

/* Q97. */
WITH first_orders AS (SELECT cust_id, DATE_TRUNC('month', MIN(order_date))::date AS cohort_month FROM sales.orders GROUP BY cust_id),
cohort_size AS (SELECT cohort_month, COUNT(*) AS cohort_customers FROM first_orders GROUP BY cohort_month),
numbered AS (
    SELECT cust_id, order_date,
           MIN(order_date) OVER (PARTITION BY cust_id) AS first_order_date,
           LEAD(order_date) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS second_order_date
    FROM sales.orders
),
converted AS (
    SELECT n.cust_id, fo.cohort_month
    FROM numbered n
    JOIN first_orders fo ON fo.cust_id = n.cust_id
    WHERE n.order_date = n.first_order_date AND n.second_order_date IS NOT NULL
)
SELECT cs.cohort_month, cs.cohort_customers, COUNT(c.cust_id) AS converted_to_second_purchase,
       ROUND(100.0 * COUNT(c.cust_id) / NULLIF(cs.cohort_customers, 0), 2) AS conversion_pct
FROM cohort_size cs
LEFT JOIN converted c ON c.cohort_month = cs.cohort_month
GROUP BY cs.cohort_month, cs.cohort_customers
ORDER BY cs.cohort_month;

/* Q98. */
WITH monthly_changes AS (
    SELECT b.brand_name, DATE_TRUNC('month', rc.changed_at)::date AS month, COUNT(*) AS price_change_count
    FROM audit.record_changes rc
    JOIN products.products p ON rc.record_id = p.product_id
    JOIN core.dim_brand b ON p.brand_id = b.brand_id
    WHERE rc.table_name = 'products' AND rc.column_name = 'price'
    GROUP BY b.brand_name, DATE_TRUNC('month', rc.changed_at)
)
SELECT brand_name, month, price_change_count
FROM monthly_changes
WHERE price_change_count >= 5
ORDER BY price_change_count DESC, brand_name, month;

/* Q99. */
WITH funnel AS (
    SELECT session_id, page_url,
           CASE WHEN page_url LIKE '/product/%' THEN 'product'
                WHEN page_url = '/cart' THEN 'cart'
                WHEN page_url = '/checkout' THEN 'checkout' END AS funnel_step
    FROM web_events.page_views
    WHERE page_url LIKE '/product/%' OR page_url IN ('/cart', '/checkout')
),
session_flags AS (
    SELECT session_id,
           BOOL_OR(funnel_step = 'product') AS saw_product,
           BOOL_OR(funnel_step = 'cart') AS saw_cart,
           BOOL_OR(funnel_step = 'checkout') AS saw_checkout
    FROM funnel GROUP BY session_id
),
counts AS (
    SELECT COUNT(*) FILTER (WHERE saw_product) AS product_sessions,
           COUNT(*) FILTER (WHERE saw_product AND saw_cart) AS cart_sessions,
           COUNT(*) FILTER (WHERE saw_cart AND saw_checkout) AS checkout_sessions
    FROM session_flags
)
SELECT product_sessions, cart_sessions, checkout_sessions,
       ROUND(100.0 * (product_sessions - cart_sessions) / NULLIF(product_sessions, 0), 2) AS dropoff_product_to_cart_pct,
       ROUND(100.0 * (cart_sessions - checkout_sessions) / NULLIF(cart_sessions, 0), 2) AS dropoff_cart_to_checkout_pct
FROM counts;

/* Q100. */
WITH months AS (SELECT generate_series('2024-01-01'::date, '2026-02-01'::date, '1 month'::interval)::date AS month),
base AS (
    SELECT r.region_id, r.region_name, m.month,
           COALESCE(SUM(o.net_total), 0) AS revenue,
           COUNT(DISTINCT o.cust_id) AS active_customers
    FROM core.dim_region r CROSS JOIN months m
    LEFT JOIN stores.stores s ON s.region_id = r.region_id
    LEFT JOIN sales.orders o ON o.store_id = s.store_id AND DATE_TRUNC('month', o.order_date) = m.month
    GROUP BY r.region_id, r.region_name, m.month
),
pack AS (
    SELECT region_id, region_name, month, revenue, active_customers,
           LAG(revenue) OVER (PARTITION BY region_id ORDER BY month) AS prev_m_revenue,
           LAG(revenue, 12) OVER (PARTITION BY region_id ORDER BY month) AS prev_y_revenue,
           LAG(active_customers) OVER (PARTITION BY region_id ORDER BY month) AS prev_m_active_customers,
           AVG(revenue) OVER (PARTITION BY region_id ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ma_3mo,
           STDDEV(revenue) OVER (PARTITION BY region_id ORDER BY month ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS stddev_6mo
    FROM base
)
SELECT region_id, region_name, month, revenue, active_customers,
       ROUND(100.0 * (revenue - prev_m_revenue) / NULLIF(prev_m_revenue, 0), 2) AS mom_growth_pct,
       ROUND(100.0 * (revenue - prev_y_revenue) / NULLIF(prev_y_revenue, 0), 2) AS yoy_growth_pct,
       ROUND(ma_3mo, 2) AS ma_3mo,
       CASE WHEN ABS((revenue - ma_3mo) / NULLIF(stddev_6mo, 0)) > 2 THEN 'ANOMALY' ELSE 'NORMAL' END AS anomaly_flag,
       (active_customers < prev_m_active_customers) AS retention_declining_flag
FROM pack
ORDER BY region_id, month;

/* ============================================================
   END OF ANSWER KEY - Window Functions Part 3 - CRAZY LEVEL (100/100)
============================================================ */
