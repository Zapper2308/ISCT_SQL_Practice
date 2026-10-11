/* ============================================================
   ANSWER KEY - Cohort, RFM & Funnel Queries (CRAZY LEVEL)
   Curriculum:   RetailMart V3
   NOTE: Questions asking to build/refresh a production MV, index, or
     documentation are answered conceptually - persisting new schema
     objects is explicitly scoped to Day 25 in this curriculum and this
     is a shared live teaching database, so detection stays SELECT-only.
   ============================================================ */

/* Q1.  A growth analytics platform runs: Day-26 cleansed customers/orders/sessions feed cohort grids, RFM scoring and funnel counts, which roll up into named segments and an exec summary, finally exported as JSON for BI/marketing/product consumers. */
/* Q2.  Registration-anchored cohorts measure activation (including people who never buy); first-order-anchored cohorts measure post-purchase retention only - running both side by side answers two different business questions from the same data. */
/* Q3.  Weekly cohorts react fast to a recent change but each cohort is small and noisy; a rolling-12-week window smooths that noise while still being far more current than a monthly view. */
/* Q4.  Cumulative LTV per cohort is a running SUM(revenue) window function partitioned by cohort and ordered by period_index, ideally computed over a date-spine-completed grid (Day 23) so missing periods contribute a true zero, not a gap. */
/* Q5.  Point-in-time RFM recomputes R/F/M using only orders that existed as of a chosen historical cutoff; current-as-of always uses today's data - the two diverge whenever segment definitions are compared across time, which versioned segment definitions (v1 vs v2) make explicit. */
/* Q6.  Renaming a segment label safely means updating the display name in one place (a lookup or CASE mapping) while keeping the underlying score-range rule stable, so historical dashboards referencing the old name can be redirected without recomputing anything. */
/* Q7.  A transition matrix (segment in Q1 x segment in Q2, with a count) is read by scanning rows: the diagonal is customers who stayed in the same segment, and off-diagonal cells show exactly which segments gained or lost people to which other segments. */
/* Q8.  SQL has no native survival-curve function, but a cohort retention grid IS effectively a discrete survival curve already - % of the cohort still "alive" (active) at each period_index, which can be extended with hazard-rate (period-over-period drop) calculations. */
/* Q9.  Customer grain answers "did this person ever do X"; session grain answers "did this visit do X"; event grain counts every occurrence - choose customer for lifetime segmentation, session for UX conversion analysis, and event grain only when frequency itself is the metric. */
/* Q10. P50/P95 time-between-steps (Day 22) per funnel step shows not just whether users convert but how long it takes them to, per step - a slow-but-eventually-converting step is a different problem than a low-converting one. */
/* Q11. A pivot architecture (Day 21) puts one dimension (device/channel/region) as columns and metrics as rows (or vice versa); beyond 2-3 dimensions a wide pivot becomes unreadable, so a long/tidy table with a BI tool doing the pivoting is usually better past that point. */
/* Q12. Growth decomposition splits total revenue or active-customer change into new, returning, and reactivated contributions using each customer's first-order date and prior-activity gap, so the same headline growth number can be diagnosed by cause. */
/* Q13. PoP formulas must wrap the denominator in NULLIF(prior_period, 0) to avoid a division-by-zero error, and comparisons across regimes (pre/post a major promotion, a seasonal spike) need a note that PoP % alone can mislead without that context. */
/* Q14. A cohort x region x tier 3D slice quickly exceeds what a single 2D pivot can show cleanly - past two dimensions, a long/tidy result table (region, tier, cohort, metric) consumed by a BI tool's own pivot/filter UI works better than SQL pivoting further. */
/* Q15. A 12-month CLV horizon is comparable across cohorts of different ages; lifetime CLV keeps growing and is only "final" for cohorts old enough to have mostly churned - reporting both avoids misleadingly comparing a young cohort's partial lifetime total to an old cohort's near-complete one. */
/* Q16. A date/period spine (Day 23) joined to actual cohort or funnel activity guarantees every expected cell exists, so a zero-activity period shows as a true 0, not a silently missing row that a naive GROUP BY would never produce. */
/* Q17. mv_cohort_triangle and a per-month funnel mart are strong Day-25 candidates since dashboards re-read them far more often than the underlying orders/page_views tables change intra-day - a nightly refresh comfortably meets that freshness need. */
/* Q18. EXPLAIN ANALYZE on the cohort join (150k orders x 50k customers) reveals whether the planner used a Hash Join or fell back to Nested Loop; a covering index on orders(cust_id, order_date) lets the join and the date arithmetic both use one index scan. */
/* Q19. Exec JSON exports wrap the cohort triangle, RFM segment counts, and funnel result each as one jsonb array of objects, so a single API response or file can carry all three without three separate round trips or column-parsing logic. */
/* Q20. Deduped customers (Day 26) prevent inflated cohort sizes; deduped orders prevent double-counting the same transaction in monetary and frequency scores - both directly change the correctness of every number this file computes. */
/* Q21. An idempotent refresh DAG means rerunning cleanse -> cohort -> RFM -> funnel -> export on the same source data always reproduces the same published result, so a retry after a failure never doubles or corrupts anything. */
/* Q22. Freshness (how stale is the number), completeness (did every expected row make it through), and accuracy (does it reconcile against a source-of-truth total) are the three SLA dimensions that matter most for a growth-analytics insight. */
/* Q23. Marketing needs named segments to target campaigns; product needs funnel step counts to prioritize UX fixes - both are contractually promised outputs of the same underlying cleansed orders/events tables, just aggregated for different audiences. */
/* Q24. A cohort whose denominator (cohort_size) is recomputed fresh on every query run, rather than frozen at period 0, silently changes the meaning of "retention %" over time as new customers with that same signup_month are backfilled - the denominator must be fixed once. */
/* Q25. Every rule/definition (RFM cutoffs, funnel step URLs, cohort anchor) documented directly on its MV via COMMENT ON keeps the operational logic discoverable at the object itself instead of drifting out of sync with a separate wiki page. */

/* Q26. */
WITH cohort AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month FROM customers.customers
),
cohort_size AS (SELECT signup_month, COUNT(DISTINCT customer_id) AS cohort_size FROM cohort GROUP BY signup_month),
activity AS (
  SELECT co.signup_month, o.cust_id,
    (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
     + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)))::int AS period_index
  FROM cohort co JOIN sales.orders o ON o.cust_id = co.customer_id
),
grid AS (
  SELECT signup_month, period_index, COUNT(DISTINCT cust_id) AS active_customers
  FROM activity WHERE period_index BETWEEN 0 AND 11 GROUP BY signup_month, period_index
)
SELECT g.signup_month, g.period_index, ROUND(100.0*g.active_customers/cs.cohort_size,2) AS retention_pct
FROM grid g JOIN cohort_size cs ON cs.signup_month = g.signup_month
ORDER BY g.signup_month, g.period_index;

/* Q27. */
WITH cohort AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month FROM customers.customers
),
period_rev AS (
  SELECT co.signup_month,
    (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
     + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)))::int AS period_index,
    SUM(o.net_total) AS revenue
  FROM cohort co JOIN sales.orders o ON o.cust_id = co.customer_id
  WHERE (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
       + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month))) BETWEEN 0 AND 11
  GROUP BY co.signup_month, period_index
)
SELECT signup_month, period_index, revenue,
       SUM(revenue) OVER (PARTITION BY signup_month ORDER BY period_index) AS cumulative_ltv
FROM period_rev ORDER BY signup_month, period_index;

/* Q28. */
WITH cohort AS (
  SELECT c.customer_id, c.tier, DATE_TRUNC('month', c.registration_date)::date AS signup_month, r.region_name
  FROM customers.customers c
  JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = true
  JOIN core.dim_region r ON r.state = a.state
)
SELECT co.region_name, co.tier, co.signup_month,
  COUNT(DISTINCT o.cust_id) AS active_customers, SUM(o.net_total) AS revenue
FROM cohort co
JOIN sales.orders o ON o.cust_id = co.customer_id
GROUP BY co.region_name, co.tier, co.signup_month
ORDER BY co.region_name, co.tier, co.signup_month;

/* Q29. */
WITH cohort AS (
  SELECT customer_id, DATE_TRUNC('week', registration_date)::date AS signup_week FROM customers.customers
),
cohort_size AS (SELECT signup_week, COUNT(DISTINCT customer_id) AS cohort_size FROM cohort GROUP BY signup_week),
activity AS (
  SELECT co.signup_week, o.cust_id,
    (EXTRACT(EPOCH FROM (DATE_TRUNC('week', o.order_date) - co.signup_week))/604800)::int AS week_index
  FROM cohort co JOIN sales.orders o ON o.cust_id = co.customer_id
),
grid AS (
  SELECT signup_week, week_index, COUNT(DISTINCT cust_id) AS active_customers
  FROM activity WHERE week_index BETWEEN 0 AND 12 GROUP BY signup_week, week_index
)
SELECT g.signup_week, g.week_index, ROUND(100.0*g.active_customers/cs.cohort_size,2) AS retention_pct
FROM grid g JOIN cohort_size cs ON cs.signup_week = g.signup_week
ORDER BY g.signup_week, g.week_index;

/* Q30. */
WITH spine AS (SELECT DISTINCT DATE_TRUNC('month', registration_date)::date AS signup_month FROM customers.customers),
periods AS (SELECT generate_series(0,11) AS period_index),
full_grid AS (SELECT s.signup_month, p.period_index FROM spine s CROSS JOIN periods p),
cohort AS (SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month FROM customers.customers),
activity AS (
  SELECT co.signup_month, o.cust_id,
    (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
     + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)))::int AS period_index
  FROM cohort co JOIN sales.orders o ON o.cust_id = co.customer_id
),
grid AS (
  SELECT signup_month, period_index, COUNT(DISTINCT cust_id) AS active_customers
  FROM activity GROUP BY signup_month, period_index
)
SELECT fg.signup_month, fg.period_index,
       (g.active_customers IS NULL) AS is_missing_cell
FROM full_grid fg LEFT JOIN grid g ON g.signup_month=fg.signup_month AND g.period_index=fg.period_index
WHERE fg.signup_month + (fg.period_index || ' months')::interval <= (SELECT MAX(order_date) FROM sales.orders)
ORDER BY fg.signup_month, fg.period_index;

/* Q31. */
WITH cohort_size AS (
  SELECT DATE_TRUNC('month', registration_date)::date AS signup_month, COUNT(DISTINCT customer_id) AS cohort_size
  FROM customers.customers GROUP BY DATE_TRUNC('month', registration_date)
),
active_m1 AS (
  SELECT DATE_TRUNC('month', c.registration_date)::date AS signup_month, COUNT(DISTINCT c.customer_id) AS active_ct
  FROM customers.customers c JOIN sales.orders o ON o.cust_id = c.customer_id
  WHERE (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), DATE_TRUNC('month', c.registration_date))) * 12
       + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), DATE_TRUNC('month', c.registration_date)))) = 1
  GROUP BY DATE_TRUNC('month', c.registration_date)
),
retention AS (
  SELECT cs.signup_month, ROUND(100.0*COALESCE(a.active_ct,0)/cs.cohort_size,2) AS m1_pct,
         RANK() OVER (ORDER BY ROUND(100.0*COALESCE(a.active_ct,0)/cs.cohort_size,2) DESC) AS best_rank,
         RANK() OVER (ORDER BY ROUND(100.0*COALESCE(a.active_ct,0)/cs.cohort_size,2) ASC) AS worst_rank
  FROM cohort_size cs LEFT JOIN active_m1 a ON a.signup_month=cs.signup_month
)
SELECT * FROM retention WHERE best_rank = 1 OR worst_rank = 1;

/* Q32. */
WITH cohort_size AS (
  SELECT DATE_TRUNC('month', registration_date)::date AS signup_month, COUNT(DISTINCT customer_id) AS cohort_size
  FROM customers.customers GROUP BY DATE_TRUNC('month', registration_date)
),
active_m1 AS (
  SELECT DATE_TRUNC('month', c.registration_date)::date AS signup_month, COUNT(DISTINCT c.customer_id) AS active_ct
  FROM customers.customers c JOIN sales.orders o ON o.cust_id = c.customer_id
  WHERE (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), DATE_TRUNC('month', c.registration_date))) * 12
       + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), DATE_TRUNC('month', c.registration_date)))) = 1
  GROUP BY DATE_TRUNC('month', c.registration_date)
)
SELECT EXTRACT(YEAR FROM cs.signup_month)::int AS signup_year,
       ROUND(AVG(100.0*COALESCE(a.active_ct,0)/cs.cohort_size),2) AS avg_month1_retention_pct
FROM cohort_size cs LEFT JOIN active_m1 a ON a.signup_month=cs.signup_month
WHERE EXTRACT(YEAR FROM cs.signup_month) IN (2024,2025)
GROUP BY signup_year ORDER BY signup_year;

/* Q33. */
WITH cohort AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month FROM customers.customers
),
activity AS (
  SELECT co.signup_month, o.cust_id,
    (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
     + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)))::int AS period_index
  FROM cohort co JOIN sales.orders o ON o.cust_id = co.customer_id
),
distinct_periods AS (SELECT DISTINCT signup_month, cust_id, period_index FROM activity),
ordered AS (
  SELECT *, LAG(period_index) OVER (PARTITION BY signup_month, cust_id ORDER BY period_index) AS prev_period
  FROM distinct_periods
)
SELECT signup_month, period_index, COUNT(DISTINCT cust_id) AS reactivated_customers
FROM ordered WHERE period_index - prev_period > 1
GROUP BY signup_month, period_index ORDER BY signup_month, period_index;

/* Q34. */
WITH cohort AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month FROM customers.customers
),
period_data AS (
  SELECT co.signup_month,
    (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
     + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)))::int AS period_index,
    o.cust_id, SUM(o.net_total) AS cust_revenue
  FROM cohort co JOIN sales.orders o ON o.cust_id = co.customer_id
  GROUP BY co.signup_month, period_index, o.cust_id
)
SELECT signup_month, period_index, ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY cust_revenue)::numeric,2) AS median_revenue_per_active
FROM period_data GROUP BY signup_month, period_index ORDER BY signup_month, period_index;

/* Q35. */
WITH cohort AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month FROM customers.customers
),
first_order AS (SELECT cust_id, MIN(order_date) AS first_order_date FROM sales.orders GROUP BY cust_id),
period_rev AS (
  SELECT co.signup_month,
    (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
     + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)))::int AS period_index,
    SUM(o.net_total) FILTER (WHERE o.order_date = fo.first_order_date) AS new_revenue,
    SUM(o.net_total) FILTER (WHERE o.order_date <> fo.first_order_date) AS repeat_revenue
  FROM cohort co
  JOIN sales.orders o ON o.cust_id = co.customer_id
  JOIN first_order fo ON fo.cust_id = o.cust_id
  GROUP BY co.signup_month, period_index
)
SELECT * FROM period_rev ORDER BY signup_month, period_index;

/* Q36. RetailMart has no device/channel column on customers or orders directly - the closest proxy is web_events.page_views.device_type joined via customer_id, which is what Q80/Q81 in the hard file already compute per device per month. */

/* Q37. */
WITH cohort AS (
  SELECT c.customer_id, c.tier, DATE_TRUNC('month', c.registration_date)::date AS signup_month, r.region_name
  FROM customers.customers c
  JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = true
  JOIN core.dim_region r ON r.state = a.state
),
cohort_size AS (SELECT region_name, tier, signup_month, COUNT(DISTINCT customer_id) AS cohort_size FROM cohort GROUP BY region_name, tier, signup_month),
active_m1 AS (
  SELECT co.region_name, co.tier, co.signup_month, COUNT(DISTINCT o.cust_id) AS active_ct
  FROM cohort co JOIN sales.orders o ON o.cust_id = co.customer_id
  WHERE (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
       + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month))) = 1
  GROUP BY co.region_name, co.tier, co.signup_month
)
SELECT cs.region_name, cs.tier, cs.signup_month, ROUND(100.0*COALESCE(a.active_ct,0)/cs.cohort_size,2) AS month1_retention_pct
FROM cohort_size cs LEFT JOIN active_m1 a ON a.region_name=cs.region_name AND a.tier=cs.tier AND a.signup_month=cs.signup_month
ORDER BY cs.region_name, cs.tier, cs.signup_month;

/* Q38. */
WITH cohort_size AS (
  SELECT DATE_TRUNC('month', registration_date)::date AS signup_month, COUNT(DISTINCT customer_id) AS cohort_size
  FROM customers.customers GROUP BY DATE_TRUNC('month', registration_date)
),
activity AS (
  SELECT c.customer_id, DATE_TRUNC('month', c.registration_date)::date AS signup_month,
    (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), DATE_TRUNC('month', c.registration_date))) * 12
     + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), DATE_TRUNC('month', c.registration_date))))::int AS period_index
  FROM customers.customers c JOIN sales.orders o ON o.cust_id = c.customer_id
),
grid AS (
  SELECT signup_month, period_index, COUNT(DISTINCT customer_id) AS active_customers
  FROM activity WHERE period_index BETWEEN 0 AND 11 GROUP BY signup_month, period_index
)
SELECT jsonb_agg(jsonb_build_object('cohort', g.signup_month, 'period', g.period_index,
       'retention', ROUND(100.0*g.active_customers/cs.cohort_size,2))) AS cohort_triangle_json
FROM grid g JOIN cohort_size cs ON cs.signup_month = g.signup_month;

/* Q39. mv_cohort_triangle would need a UNIQUE INDEX on (cohort_month, period_index) so REFRESH MATERIALIZED VIEW CONCURRENTLY can run without locking readers out, refreshed nightly since registration/order dates only accumulate at daily granularity. */
/* Q40. mv_cohort_ltv follows the same shape and refresh cadence as mv_cohort_triangle - a UNIQUE INDEX on (cohort_month, period_index) again, since the two MVs share the exact same grain and could even be columns of one MV rather than two separate objects. */
/* Q41. A CONCURRENTLY refresh keeps both MVs queryable throughout the refresh (no exclusive lock), at the cost of needing roughly double the disk space during the swap and a slightly longer refresh time than a non-concurrent REFRESH; the read path afterward is a plain index scan on the unique index, checkable via EXPLAIN ANALYZE. */
/* Q42. An exec strip MV joining cohort and RFM would SELECT the Month-1 retention per cohort alongside that cohort's segment mix (JOIN cohort table to customers to the RFM scoring CTE, GROUP BY cohort_month, segment) - conceptually a join of Q26's grid to Q54's (hard file) scored/segmented table. */
/* Q43. Before sizing any cohort, Day-26's customer dedup engine (canonical LOWER(TRIM(email)), keep most-recent) must run first - an un-deduped cohort_size denominator overstates cohort size by exactly the number of duplicate customer rows for that signup month. */
/* Q44. */
WITH cohort_size AS (
  SELECT DATE_TRUNC('month', registration_date)::date AS signup_month, COUNT(DISTINCT customer_id) AS cohort_size
  FROM customers.customers GROUP BY DATE_TRUNC('month', registration_date)
)
SELECT
  (SELECT SUM(cohort_size) FROM cohort_size) AS sum_cohort_sizes,
  (SELECT COUNT(*) FROM customers.customers) AS total_customers,
  (SELECT SUM(net_total) FROM sales.orders WHERE order_status = 'Delivered') AS total_delivered_revenue;

/* Q45. */
WITH cohort AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month FROM customers.customers
),
active_months AS (
  SELECT co.signup_month, o.cust_id,
    (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
     + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)))::int AS period_index
  FROM cohort co JOIN sales.orders o ON o.cust_id = co.customer_id
),
repeat_rate AS (
  SELECT signup_month, cust_id, COUNT(DISTINCT period_index) FILTER (WHERE period_index BETWEEN 1 AND 6) AS active_months_1_6
  FROM active_months GROUP BY signup_month, cust_id
)
SELECT signup_month, ROUND(100.0*COUNT(*) FILTER (WHERE active_months_1_6 >= 1)/COUNT(*),2) AS repeat_rate_pct
FROM repeat_rate GROUP BY signup_month
ORDER BY repeat_rate_pct DESC LIMIT 5;

/* Q46. */
WITH cohort AS (
  SELECT c.customer_id, DATE_TRUNC('month', c.registration_date)::date AS signup_month, r.region_name
  FROM customers.customers c
  JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = true
  JOIN core.dim_region r ON r.state = a.state
),
period_rev AS (
  SELECT co.region_name,
    (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
     + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)))::int AS period_index,
    SUM(o.net_total) AS revenue
  FROM cohort co JOIN sales.orders o ON o.cust_id = co.customer_id
  WHERE (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
       + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month))) BETWEEN 0 AND 11
  GROUP BY co.region_name, period_index
)
SELECT region_name, period_index, SUM(revenue) OVER (PARTITION BY region_name ORDER BY period_index) AS cum_revenue
FROM period_rev ORDER BY region_name, period_index;

/* Q47. */
WITH cohort AS (
  SELECT c.customer_id, c.tier, DATE_TRUNC('month', c.registration_date)::date AS signup_month
  FROM customers.customers c
),
period_rev AS (
  SELECT co.tier, co.signup_month,
    (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
     + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)))::int AS period_index,
    SUM(o.net_total) AS revenue
  FROM cohort co JOIN sales.orders o ON o.cust_id = co.customer_id
  GROUP BY co.tier, co.signup_month, period_index
)
SELECT tier, signup_month, period_index, revenue
FROM period_rev
ORDER BY revenue DESC LIMIT 20;

/* Q48. RetailMart has no signup-channel column, so cohort x channel attribution is not directly possible with this schema - the closest available proxy is web_events.page_views.device_type joined via customer_id, already used for device-level cohort/funnel splits elsewhere in this set. */

/* Q49. */
WITH cohort AS (
  SELECT c.customer_id, DATE_TRUNC('month', c.registration_date)::date AS signup_month, r.region_name
  FROM customers.customers c
  JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = true
  JOIN core.dim_region r ON r.state = a.state
),
cohort_size AS (SELECT region_name, signup_month, COUNT(DISTINCT customer_id) AS cohort_size FROM cohort GROUP BY region_name, signup_month)
SELECT region_name, jsonb_agg(jsonb_build_object('signup_month', signup_month, 'cohort_size', cohort_size) ORDER BY signup_month) AS cohorts_json
FROM cohort_size GROUP BY region_name ORDER BY region_name;

/* Q50. */
WITH cohort AS (
  SELECT c.customer_id, c.tier, DATE_TRUNC('month', c.registration_date)::date AS signup_month, r.region_name
  FROM customers.customers c
  JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = true
  JOIN core.dim_region r ON r.state = a.state
),
period_data AS (
  SELECT co.region_name, co.tier, co.signup_month,
    (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
     + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)))::int AS period_index,
    COUNT(DISTINCT o.cust_id) AS active_customers, SUM(o.net_total) AS revenue
  FROM cohort co JOIN sales.orders o ON o.cust_id = co.customer_id
  WHERE (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
       + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month))) BETWEEN 0 AND 5
  GROUP BY co.region_name, co.tier, co.signup_month, period_index
)
SELECT region_name, tier, signup_month, period_index, active_customers, revenue
FROM period_data
ORDER BY region_name, tier, signup_month, period_index;

/* Q51. */
SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
       COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
FROM sales.orders GROUP BY cust_id;

/* Q52. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
)
SELECT cust_id,
  NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
  NTILE(5) OVER (ORDER BY order_count) AS f,
  NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
FROM rfm_raw;

/* Q53. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id, NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
         NTILE(5) OVER (ORDER BY order_count) AS f, NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
)
SELECT cust_id,
  CASE WHEN r>=4 AND f>=4 AND m>=4 THEN 'Champions' WHEN r>=3 AND f>=4 THEN 'Loyal Customers'
       WHEN r>=4 AND f BETWEEN 2 AND 3 THEN 'Potential Loyalists' WHEN r=5 AND f=1 THEN 'New Customers'
       WHEN r>=3 AND f<=2 AND m<=2 THEN 'Promising' WHEN r=3 AND f=3 THEN 'Need Attention'
       WHEN r=2 AND f<=2 THEN 'About to Sleep' WHEN r<=2 AND f>=3 THEN 'At Risk'
       WHEN r<=2 AND f<=2 AND m<=2 AND r>1 THEN 'Hibernating' WHEN r=1 AND f=1 AND m=1 THEN 'Lost'
       ELSE 'Other' END AS segment
FROM scored;

/* Q54. */
WITH rfm_raw AS (
  SELECT o.cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(o.order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(o.net_total) AS lifetime_revenue
  FROM sales.orders o GROUP BY o.cust_id
),
scored AS (
  SELECT cust_id, NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
         NTILE(5) OVER (ORDER BY order_count) AS f, NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
),
segmented AS (
  SELECT cust_id,
  CASE WHEN r>=4 AND f>=4 AND m>=4 THEN 'Champions' WHEN r<=2 AND f>=3 THEN 'At Risk' ELSE 'Other' END AS segment
  FROM scored
)
SELECT reg.region_name, c.tier, co.signup_month, s.segment, COUNT(*) AS n
FROM segmented s
JOIN customers.customers c ON c.customer_id = s.cust_id
JOIN customers.addresses a ON a.customer_id = s.cust_id AND a.is_default = true
JOIN core.dim_region reg ON reg.state = a.state
JOIN (SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month FROM customers.customers) co
  ON co.customer_id = s.cust_id
GROUP BY reg.region_name, c.tier, co.signup_month, s.segment
ORDER BY reg.region_name, c.tier, co.signup_month, s.segment;

/* Q55. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id, lifetime_revenue, NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
         NTILE(5) OVER (ORDER BY order_count) AS f, NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
),
segmented AS (
  SELECT lifetime_revenue,
  CASE WHEN r>=4 AND f>=4 AND m>=4 THEN 'Champions' WHEN r<=2 AND f>=3 THEN 'At Risk' WHEN r=1 AND f=1 AND m=1 THEN 'Lost' ELSE 'Other' END AS segment
  FROM scored
)
SELECT segment,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY lifetime_revenue)::numeric,2) AS median_clv,
  ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY lifetime_revenue)::numeric,2) AS p95_clv
FROM segmented GROUP BY segment ORDER BY median_clv DESC;

/* Q56. */
WITH cutoff AS (SELECT DATE '2025-06-30' AS as_of),
rfm_raw AS (
  SELECT cust_id, (SELECT as_of FROM cutoff) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders WHERE order_date <= (SELECT as_of FROM cutoff) GROUP BY cust_id
)
SELECT cust_id,
  NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
  NTILE(5) OVER (ORDER BY order_count) AS f,
  NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
FROM rfm_raw;

/* Q57. */
WITH q1_end AS (SELECT DATE '2025-03-31' AS cutoff), q2_end AS (SELECT DATE '2025-06-30' AS cutoff),
q1_scored AS (
  SELECT cust_id,
    CASE WHEN NTILE(5) OVER (ORDER BY days_since_last_order DESC) >= 4 AND NTILE(5) OVER (ORDER BY order_count) >= 4
         THEN 'Champions_or_Loyal' ELSE 'Other' END AS segment
  FROM (SELECT cust_id, (SELECT cutoff FROM q1_end) - MAX(order_date) AS days_since_last_order, COUNT(*) AS order_count
        FROM sales.orders WHERE order_date <= (SELECT cutoff FROM q1_end) GROUP BY cust_id) x
),
q2_scored AS (
  SELECT cust_id,
    CASE WHEN NTILE(5) OVER (ORDER BY days_since_last_order DESC) >= 4 AND NTILE(5) OVER (ORDER BY order_count) >= 4
         THEN 'Champions_or_Loyal' ELSE 'Other' END AS segment
  FROM (SELECT cust_id, (SELECT cutoff FROM q2_end) - MAX(order_date) AS days_since_last_order, COUNT(*) AS order_count
        FROM sales.orders WHERE order_date <= (SELECT cutoff FROM q2_end) GROUP BY cust_id) x
)
SELECT q1.segment AS q1_segment, q2.segment AS q2_segment, COUNT(*) AS n
FROM q1_scored q1 JOIN q2_scored q2 ON q2.cust_id = q1.cust_id
GROUP BY q1.segment, q2.segment ORDER BY q1.segment, q2.segment;

/* Q58. */
WITH q1_end AS (SELECT DATE '2025-03-31' AS cutoff), q2_end AS (SELECT DATE '2025-06-30' AS cutoff),
q1_scored AS (
  SELECT cust_id,
    CASE WHEN NTILE(5) OVER (ORDER BY days_since_last_order DESC) >= 4 AND NTILE(5) OVER (ORDER BY order_count) >= 4
          AND NTILE(5) OVER (ORDER BY lifetime_revenue) >= 4 THEN 'Champions' ELSE 'Other' END AS segment
  FROM (SELECT cust_id, (SELECT cutoff FROM q1_end) - MAX(order_date) AS days_since_last_order,
               COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
        FROM sales.orders WHERE order_date <= (SELECT cutoff FROM q1_end) GROUP BY cust_id) x
),
q2_scored AS (
  SELECT cust_id,
    CASE WHEN NTILE(5) OVER (ORDER BY days_since_last_order DESC) >= 4 AND NTILE(5) OVER (ORDER BY order_count) >= 4
          AND NTILE(5) OVER (ORDER BY lifetime_revenue) >= 4 THEN 'Champions'
         WHEN NTILE(5) OVER (ORDER BY days_since_last_order DESC) <= 2 AND NTILE(5) OVER (ORDER BY order_count) >= 3 THEN 'At Risk'
         ELSE 'Other' END AS segment
  FROM (SELECT cust_id, (SELECT cutoff FROM q2_end) - MAX(order_date) AS days_since_last_order,
               COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
        FROM sales.orders WHERE order_date <= (SELECT cutoff FROM q2_end) GROUP BY cust_id) x
)
SELECT q2.segment AS moved_to, COUNT(*) AS n
FROM q1_scored q1 JOIN q2_scored q2 ON q2.cust_id = q1.cust_id
WHERE q1.segment = 'Champions'
GROUP BY q2.segment ORDER BY n DESC;

/* Q59. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id, lifetime_revenue, order_count, NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
         NTILE(5) OVER (ORDER BY order_count) AS f, NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
)
SELECT cust_id, lifetime_revenue, 'promotion_candidate' AS tag FROM scored WHERE r <= 2 AND m >= 4
UNION ALL
SELECT cust_id, lifetime_revenue, 'reactivation_candidate' FROM scored WHERE r <= 2 AND f <= 2 AND order_count >= 5;

/* Q60. */
WITH q_end AS (SELECT DATE '2025-06-30' AS cutoff),
scored AS (
  SELECT cust_id, lifetime_revenue,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r, NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM (SELECT cust_id, (SELECT cutoff FROM q_end) - MAX(order_date) AS days_since_last_order,
               COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
        FROM sales.orders WHERE order_date <= (SELECT cutoff FROM q_end) GROUP BY cust_id) x
)
SELECT cust_id, lifetime_revenue FROM scored WHERE r>=4 AND f>=4 AND m>=4
ORDER BY lifetime_revenue DESC LIMIT 20;

/* Q61. */
WITH rfm_raw AS (
  SELECT c.cust_id, c.tier, c.region_name, a.days_since_last_order, a.order_count, a.lifetime_revenue
  FROM (SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
               COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
        FROM sales.orders GROUP BY cust_id) a
  JOIN (SELECT cu.customer_id AS cust_id, cu.tier, reg.region_name
        FROM customers.customers cu
        JOIN customers.addresses ad ON ad.customer_id = cu.customer_id AND ad.is_default = true
        JOIN core.dim_region reg ON reg.state = ad.state) c ON c.cust_id = a.cust_id
),
scored AS (
  SELECT cust_id, tier, region_name,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
)
SELECT region_name, tier, (r::text||f::text||m::text) AS rfm_string, COUNT(*) AS n
FROM scored GROUP BY region_name, tier, rfm_string
ORDER BY region_name, tier, rfm_string;

/* Q62. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
v1 AS (
  SELECT cust_id, CASE WHEN NTILE(5) OVER (ORDER BY days_since_last_order DESC) >= 4
          AND NTILE(5) OVER (ORDER BY order_count) >= 4 THEN 'Champions' ELSE 'Other' END AS segment
  FROM rfm_raw
),
v2 AS (
  SELECT cust_id, CASE WHEN NTILE(10) OVER (ORDER BY days_since_last_order DESC) >= 8
          AND NTILE(10) OVER (ORDER BY order_count) >= 8 THEN 'Champions' ELSE 'Other' END AS segment
  FROM rfm_raw
)
SELECT COUNT(*) FILTER (WHERE v1.segment IS DISTINCT FROM v2.segment) AS divergent_customers, COUNT(*) AS total_customers
FROM v1 JOIN v2 ON v2.cust_id = v1.cust_id;

/* Q63. */
WITH q1_end AS (SELECT DATE '2025-01-31' AS cutoff), q2_end AS (SELECT DATE '2025-04-30' AS cutoff),
     q3_end AS (SELECT DATE '2025-07-31' AS cutoff),
seg1 AS (SELECT cust_id, CASE WHEN NTILE(5) OVER (ORDER BY days_since_last_order DESC) >= 4 THEN 'High' ELSE 'Low' END AS s
  FROM (SELECT cust_id, (SELECT cutoff FROM q1_end)-MAX(order_date) AS days_since_last_order FROM sales.orders
        WHERE order_date <= (SELECT cutoff FROM q1_end) GROUP BY cust_id) x),
seg2 AS (SELECT cust_id, CASE WHEN NTILE(5) OVER (ORDER BY days_since_last_order DESC) >= 4 THEN 'High' ELSE 'Low' END AS s
  FROM (SELECT cust_id, (SELECT cutoff FROM q2_end)-MAX(order_date) AS days_since_last_order FROM sales.orders
        WHERE order_date <= (SELECT cutoff FROM q2_end) GROUP BY cust_id) x),
seg3 AS (SELECT cust_id, CASE WHEN NTILE(5) OVER (ORDER BY days_since_last_order DESC) >= 4 THEN 'High' ELSE 'Low' END AS s
  FROM (SELECT cust_id, (SELECT cutoff FROM q3_end)-MAX(order_date) AS days_since_last_order FROM sales.orders
        WHERE order_date <= (SELECT cutoff FROM q3_end) GROUP BY cust_id) x)
SELECT ROUND(100.0*COUNT(*) FILTER (WHERE seg1.s=seg2.s AND seg2.s=seg3.s)/COUNT(*),2) AS pct_stable_2plus_quarters
FROM seg1 JOIN seg2 ON seg2.cust_id=seg1.cust_id JOIN seg3 ON seg3.cust_id=seg1.cust_id;

/* Q64. */
WITH rfm_raw AS (
  SELECT o.cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(o.order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(o.net_total) AS lifetime_revenue
  FROM sales.orders o GROUP BY o.cust_id
),
scored AS (
  SELECT cust_id, NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
         NTILE(5) OVER (ORDER BY order_count) AS f, NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
),
segmented AS (
  SELECT cust_id,
  CASE WHEN r>=4 AND f>=4 AND m>=4 THEN 'Champions' WHEN r>=3 AND f>=4 THEN 'Loyal Customers'
       WHEN r<=2 AND f>=3 THEN 'At Risk' WHEN r=1 AND f=1 AND m=1 THEN 'Lost' ELSE 'Other' END AS segment
  FROM scored
)
SELECT reg.region_name, jsonb_agg(jsonb_build_object('segment', s.segment, 'customer_id', s.cust_id)) AS rfm_export_json
FROM segmented s
JOIN customers.addresses a ON a.customer_id = s.cust_id AND a.is_default = true
JOIN core.dim_region reg ON reg.state = a.state
GROUP BY reg.region_name ORDER BY reg.region_name;

/* Q65. mv_rfm_segments would need a UNIQUE INDEX on (customer_id) so each customer has exactly one current-segment row and REFRESH MATERIALIZED VIEW CONCURRENTLY can update it in place; refreshed daily since recency changes every time any customer orders. */
/* Q66. mv_rfm_drift_quarter would need a UNIQUE INDEX on (quarter, customer_id), since the same customer legitimately has one row per quarter - this MV only needs to be rebuilt once at each quarter's close, not on a daily cadence. */
/* Q67. mv_segment_ltv_summary would need a UNIQUE INDEX on (segment) since it holds exactly one aggregate row per named segment; refreshed daily alongside mv_rfm_segments so segment-level CLV stays consistent with current segment membership. */
/* Q68. CONCURRENTLY refreshing mv_rfm_segments and mv_segment_ltv_summary together (in that dependency order) avoids a window where segment_ltv_summary reflects a newer segment assignment than what mv_rfm_segments currently shows; EXPLAIN ANALYZE on the read path afterward should show a plain index scan on each unique index. */
/* Q69. */
WITH rfm_raw AS (
  SELECT o.cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(o.order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(o.net_total) AS lifetime_revenue
  FROM sales.orders o GROUP BY o.cust_id
),
scored AS (
  SELECT cust_id, NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
         NTILE(5) OVER (ORDER BY order_count) AS f, NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
),
segmented AS (
  SELECT cust_id, CASE WHEN r>=4 AND f>=4 AND m>=4 THEN 'Champions' WHEN r<=2 AND f>=3 THEN 'At Risk' ELSE 'Other' END AS segment
  FROM scored
),
sla AS (
  SELECT s.segment, (sh.delivered_date - sh.shipped_date) AS delivery_days
  FROM segmented s JOIN sales.orders o ON o.cust_id = s.cust_id
  JOIN sales.shipments sh ON sh.order_id = o.order_id
  WHERE sh.delivered_date IS NOT NULL AND sh.shipped_date IS NOT NULL
)
SELECT segment, ROUND(100.0*COUNT(*) FILTER (WHERE delivery_days > 5)/COUNT(*),2) AS pct_sla_breach
FROM sla GROUP BY segment ORDER BY segment;

/* Q70. */
WITH rfm_raw AS (
  SELECT o.cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(o.order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(o.net_total) AS lifetime_revenue
  FROM sales.orders o GROUP BY o.cust_id
),
scored AS (
  SELECT cust_id, NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
         NTILE(5) OVER (ORDER BY order_count) AS f, NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
),
segmented AS (
  SELECT cust_id, CASE WHEN r>=4 AND f>=4 AND m>=4 THEN 'Champions' WHEN r<=2 AND f>=3 THEN 'At Risk' ELSE 'Other' END AS segment
  FROM scored
)
SELECT s.segment, ROUND(AVG(t.ticket_ct),2) AS avg_tickets_per_customer
FROM segmented s
LEFT JOIN (SELECT customer_id, COUNT(*) AS ticket_ct FROM support.tickets GROUP BY customer_id) t
  ON t.customer_id = s.cust_id
GROUP BY s.segment ORDER BY s.segment;

/* Q71. */
WITH cohort_size AS (
  SELECT DATE_TRUNC('month', registration_date)::date AS signup_month, COUNT(DISTINCT customer_id) AS cohort_size
  FROM customers.customers GROUP BY DATE_TRUNC('month', registration_date)
),
active_m3 AS (
  SELECT DATE_TRUNC('month', c.registration_date)::date AS signup_month, COUNT(DISTINCT c.customer_id) AS active_ct
  FROM customers.customers c JOIN sales.orders o ON o.cust_id = c.customer_id
  WHERE (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), DATE_TRUNC('month', c.registration_date))) * 12
       + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), DATE_TRUNC('month', c.registration_date)))) = 3
  GROUP BY DATE_TRUNC('month', c.registration_date)
),
rfm_raw AS (
  SELECT o.cust_id, NTILE(5) OVER (ORDER BY (SELECT MAX(order_date) FROM sales.orders) - MAX(o.order_date) DESC) AS r
  FROM sales.orders o GROUP BY o.cust_id
)
SELECT DATE_TRUNC('month', c.registration_date)::date AS signup_month,
       ROUND(AVG(CASE WHEN r.r >= 4 THEN 1.0 ELSE 0.0 END),3) AS pct_high_recency,
       ROUND(100.0*COALESCE(a.active_ct,0)/cs.cohort_size,2) AS month3_retention_pct
FROM customers.customers c
JOIN rfm_raw r ON r.cust_id = c.customer_id
JOIN cohort_size cs ON cs.signup_month = DATE_TRUNC('month', c.registration_date)::date
LEFT JOIN active_m3 a ON a.signup_month = cs.signup_month
GROUP BY DATE_TRUNC('month', c.registration_date)::date, cs.cohort_size, a.active_ct
ORDER BY signup_month;

/* Q72. */
WITH rfm_raw AS (
  SELECT o.cust_id, r.region_name, (SELECT MAX(order_date) FROM sales.orders) - MAX(o.order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(o.net_total) AS lifetime_revenue
  FROM sales.orders o
  JOIN customers.addresses a ON a.customer_id = o.cust_id AND a.is_default = true
  JOIN core.dim_region r ON r.state = a.state
  GROUP BY o.cust_id, r.region_name
),
region_baseline AS (
  SELECT region_name, PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY lifetime_revenue) AS p95
  FROM rfm_raw GROUP BY region_name
)
SELECT rr.region_name, rr.cust_id, rr.lifetime_revenue, rb.p95
FROM rfm_raw rr JOIN region_baseline rb ON rb.region_name = rr.region_name
WHERE rr.lifetime_revenue > rb.p95;

/* Q73. */
WITH rfm_raw AS (
  SELECT o.cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(o.order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(o.net_total) AS lifetime_revenue
  FROM sales.orders o GROUP BY o.cust_id
),
scored AS (
  SELECT cust_id, lifetime_revenue, order_count, NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
         NTILE(5) OVER (ORDER BY order_count) AS f, NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
)
SELECT cust_id, lifetime_revenue, 'movers_or_promotion' AS list_type FROM scored WHERE r<=2 AND m>=4
UNION ALL
SELECT cust_id, lifetime_revenue, 'reactivation' FROM scored WHERE r<=2 AND f<=2 AND order_count>=5
ORDER BY lifetime_revenue DESC;

/* Q74. This is a plan-inspection exercise for the RFM engine over the full 150k-row orders table. */
EXPLAIN (ANALYZE, BUFFERS)
SELECT cust_id,
  NTILE(5) OVER (ORDER BY (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) DESC) AS r,
  NTILE(5) OVER (ORDER BY COUNT(*)) AS f,
  NTILE(5) OVER (ORDER BY SUM(net_total)) AS m
FROM sales.orders GROUP BY cust_id;

/* Q75. */
WITH rfm_raw AS (
  SELECT o.cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(o.order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(o.net_total) AS lifetime_revenue
  FROM sales.orders o GROUP BY o.cust_id
),
scored AS (
  SELECT cust_id, NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
         NTILE(5) OVER (ORDER BY order_count) AS f, NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
),
segmented AS (
  SELECT cust_id,
  CASE WHEN r>=4 AND f>=4 AND m>=4 THEN 'Champions' WHEN r>=3 AND f>=4 THEN 'Loyal Customers'
       WHEN r<=2 AND f>=3 THEN 'At Risk' WHEN r=1 AND f=1 AND m=1 THEN 'Lost' ELSE 'Other' END AS segment
  FROM scored
)
SELECT jsonb_build_object(
  'segment_counts', (SELECT jsonb_agg(jsonb_build_object('segment', segment, 'n', n)) FROM (SELECT segment, COUNT(*) AS n FROM segmented GROUP BY segment) x),
  'total_scored', (SELECT COUNT(*) FROM segmented)
) AS rfm_capstone_export;

/* Q76. */
SELECT
  COUNT(DISTINCT customer_id) AS viewers,
  COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%product%') AS product,
  COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%cart%') AS cart,
  COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%checkout%') AS checkout,
  (SELECT COUNT(DISTINCT cust_id) FROM sales.orders) AS ordered
FROM web_events.page_views;

/* Q77. */
SELECT session_id,
  MAX(CASE WHEN page_url LIKE '%product%' THEN 1 ELSE 0 END) AS reached_product,
  MAX(CASE WHEN page_url LIKE '%cart%' THEN 1 ELSE 0 END) AS reached_cart,
  MAX(CASE WHEN page_url LIKE '%checkout%' THEN 1 ELSE 0 END) AS reached_checkout
FROM web_events.page_views GROUP BY session_id;

/* Q78. */
WITH steps AS (
  SELECT
    COUNT(DISTINCT customer_id) AS viewers,
    COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%product%') AS product,
    COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%cart%') AS cart,
    COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%checkout%') AS checkout
  FROM web_events.page_views
)
SELECT viewers, product, cart, checkout,
  ROUND(100.0*(viewers-product)/NULLIF(viewers,0),2) AS drop_viewer_product,
  ROUND(100.0*(product-cart)/NULLIF(product,0),2) AS drop_product_cart,
  ROUND(100.0*(cart-checkout)/NULLIF(cart,0),2) AS drop_cart_checkout,
  viewers AS cumulative_step1, product AS cumulative_step2, cart AS cumulative_step3, checkout AS cumulative_step4
FROM steps;

/* Q79. */
WITH steps AS (
  SELECT customer_id,
    MIN(view_timestamp) FILTER (WHERE page_url LIKE '%product%') AS t_product,
    MIN(view_timestamp) FILTER (WHERE page_url LIKE '%cart%') AS t_cart,
    MIN(view_timestamp) FILTER (WHERE page_url LIKE '%checkout%') AS t_checkout
  FROM web_events.page_views GROUP BY customer_id
)
SELECT
  ROUND(EXTRACT(EPOCH FROM PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY t_cart-t_product))/60.0,2) AS median_min_product_cart,
  ROUND(EXTRACT(EPOCH FROM PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY t_cart-t_product))/60.0,2) AS p95_min_product_cart,
  ROUND(EXTRACT(EPOCH FROM PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY t_checkout-t_cart))/60.0,2) AS median_min_cart_checkout,
  ROUND(EXTRACT(EPOCH FROM PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY t_checkout-t_cart))/60.0,2) AS p95_min_cart_checkout
FROM steps WHERE t_cart > t_product AND t_checkout > t_cart;

/* Q80. */
SELECT device_type, DATE_TRUNC('month', view_timestamp)::date AS month,
  COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%product%') AS product,
  COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%checkout%') AS checkout
FROM web_events.page_views
GROUP BY device_type, DATE_TRUNC('month', view_timestamp) ORDER BY device_type, month;

/* Q81. */
WITH cohort AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month FROM customers.customers
)
SELECT reg.region_name, co.signup_month,
  COUNT(DISTINCT p.customer_id) FILTER (WHERE p.page_url LIKE '%checkout%') AS checkout
FROM web_events.page_views p
JOIN cohort co ON co.customer_id = p.customer_id
JOIN customers.addresses a ON a.customer_id = p.customer_id AND a.is_default = true
JOIN core.dim_region reg ON reg.state = a.state
GROUP BY reg.region_name, co.signup_month
ORDER BY reg.region_name, co.signup_month;

/* Q82. */
WITH monthly_funnel AS (
  SELECT device_type, DATE_TRUNC('month', view_timestamp) AS month,
    COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%checkout%') AS checkout
  FROM web_events.page_views GROUP BY device_type, DATE_TRUNC('month', view_timestamp)
)
SELECT device_type, month, checkout,
  checkout - LAG(checkout) OVER (PARTITION BY device_type ORDER BY month) AS mom_change,
  checkout - LAG(checkout,12) OVER (PARTITION BY device_type ORDER BY month) AS yoy_change
FROM monthly_funnel ORDER BY device_type, month;

/* Q83. */
WITH funnel AS (
  SELECT device_type, DATE_TRUNC('month', view_timestamp) AS month,
    COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%checkout%') AS checkout,
    COUNT(DISTINCT customer_id) AS visitors
  FROM web_events.page_views GROUP BY device_type, DATE_TRUNC('month', view_timestamp)
)
SELECT device_type, month, ROUND(100.0*checkout/NULLIF(visitors,0),2) AS conversion_rate_pct,
  AVG(ROUND(100.0*checkout/NULLIF(visitors,0),2)) OVER (PARTITION BY device_type ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS moving_3mo_avg_conversion
FROM funnel ORDER BY device_type, month;

/* Q84. */
WITH funnel AS (
  SELECT device_type, DATE_TRUNC('month', view_timestamp) AS month,
    COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%product%') AS product,
    COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%cart%') AS cart,
    COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%checkout%') AS checkout
  FROM web_events.page_views GROUP BY device_type, DATE_TRUNC('month', view_timestamp)
)
SELECT jsonb_agg(jsonb_build_object('device', device_type, 'month', month, 'product', product, 'cart', cart, 'checkout', checkout,
       'drop_product_cart_pct', ROUND(100.0*(product-cart)/NULLIF(product,0),2))) AS funnel_export_json
FROM funnel;

/* Q85. mv_funnel_steps_monthly would need a UNIQUE INDEX on (month, device) since exactly one funnel-step row exists per month per device; refreshed daily to stay current with new page_views inserted that day. */
/* Q86. mv_conversion_rates_monthly would need a UNIQUE INDEX on (device, month), refreshed on the same daily cadence as mv_funnel_steps_monthly and ideally in the same refresh transaction so the two never disagree mid-day. */
/* Q87. A growth-decomposition MV (new/returning/reactivated revenue per month per region) would need a UNIQUE INDEX on (month, region_id), refreshed daily since it depends on the same daily order stream as the other revenue MVs. */
/* Q88. */
WITH monthly AS (
  SELECT r.region_id, DATE_TRUNC('month', o.order_date) AS month, SUM(o.net_total) AS revenue
  FROM sales.orders o JOIN stores.stores s ON s.store_id=o.store_id JOIN core.dim_region r ON r.region_id=s.region_id
  GROUP BY r.region_id, DATE_TRUNC('month', o.order_date)
)
SELECT region_id, month, revenue,
  ROUND(100.0*(revenue-LAG(revenue) OVER (PARTITION BY region_id ORDER BY month))/NULLIF(LAG(revenue) OVER (PARTITION BY region_id ORDER BY month),0),2) AS mom_pct,
  ROUND(100.0*(revenue-LAG(revenue,12) OVER (PARTITION BY region_id ORDER BY month))/NULLIF(LAG(revenue,12) OVER (PARTITION BY region_id ORDER BY month),0),2) AS yoy_pct,
  ROUND(100.0*(revenue-LAG(revenue,3) OVER (PARTITION BY region_id ORDER BY month))/NULLIF(LAG(revenue,3) OVER (PARTITION BY region_id ORDER BY month),0),2) AS qoq_pct
FROM monthly ORDER BY region_id, month;

/* Q89. */
WITH cohort AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month FROM customers.customers
),
period_rev AS (
  SELECT co.signup_month,
    (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
     + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)))::int AS period_index,
    DATE_TRUNC('month', o.order_date) AS month, SUM(o.net_total) AS revenue
  FROM cohort co JOIN sales.orders o ON o.cust_id = co.customer_id
  GROUP BY co.signup_month, period_index, DATE_TRUNC('month', o.order_date)
)
SELECT signup_month, period_index, month, revenue,
  revenue - LAG(revenue) OVER (PARTITION BY signup_month ORDER BY month) AS mom_change_same_cohort
FROM period_rev ORDER BY signup_month, month;

/* Q90. */
WITH rfm_raw AS (
  SELECT o.cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(o.order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(o.net_total) AS lifetime_revenue
  FROM sales.orders o GROUP BY o.cust_id
),
scored AS (
  SELECT cust_id, NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
         NTILE(5) OVER (ORDER BY order_count) AS f, NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
),
segmented AS (SELECT cust_id, (r>=4 AND f>=4 AND m>=4) AS is_champion FROM scored),
funnel AS (
  SELECT s.is_champion,
    COUNT(DISTINCT p.customer_id) FILTER (WHERE p.page_url LIKE '%cart%') AS cart,
    COUNT(DISTINCT p.customer_id) FILTER (WHERE p.page_url LIKE '%checkout%') AS checkout
  FROM segmented s JOIN web_events.page_views p ON p.customer_id = s.cust_id
  GROUP BY s.is_champion
)
SELECT is_champion, cart, checkout, ROUND(100.0*checkout/NULLIF(cart,0),2) AS conversion_pct
FROM funnel;

/* Q91. */
SELECT
  (SELECT COUNT(DISTINCT customer_id) FROM web_events.page_views WHERE page_url LIKE '%checkout%') AS funnel_checkout_customers,
  (SELECT COUNT(DISTINCT cust_id) FROM sales.orders) AS orders_distinct_customers;

/* Q92. A reconciliation against a Day-25 mv_daily_revenue materialized view is not testable here since no such MV exists on this database yet - the reconciliation pattern itself is identical to the easy file's Q99 (comparing two independently-computed SUM(net_total) totals and asserting they match). */

/* Q93. */
WITH cohort_size AS (
  SELECT DATE_TRUNC('month', registration_date)::date AS signup_month, COUNT(DISTINCT customer_id) AS cohort_size
  FROM customers.customers GROUP BY DATE_TRUNC('month', registration_date)
),
active_m1 AS (
  SELECT DATE_TRUNC('month', c.registration_date)::date AS signup_month, COUNT(DISTINCT c.customer_id) AS active_ct
  FROM customers.customers c JOIN sales.orders o ON o.cust_id = c.customer_id
  WHERE (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), DATE_TRUNC('month', c.registration_date))) * 12
       + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), DATE_TRUNC('month', c.registration_date)))) = 1
  GROUP BY DATE_TRUNC('month', c.registration_date)
),
rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id, NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
         NTILE(5) OVER (ORDER BY order_count) AS f, NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
),
monthly_rev AS (
  SELECT r.region_id, DATE_TRUNC('month', o.order_date) AS month, SUM(o.net_total) AS revenue
  FROM sales.orders o JOIN stores.stores s ON s.store_id=o.store_id JOIN core.dim_region r ON r.region_id=s.region_id
  GROUP BY r.region_id, DATE_TRUNC('month', o.order_date)
),
monthly_rev_mom AS (
  SELECT region_id, month, revenue,
    ROUND(100.0*(revenue-LAG(revenue) OVER (PARTITION BY region_id ORDER BY month))/NULLIF(LAG(revenue) OVER (PARTITION BY region_id ORDER BY month),0),2) AS mom_pct
  FROM monthly_rev
)
SELECT
  (SELECT jsonb_agg(jsonb_build_object('cohort', cs.signup_month, 'm1_pct', ROUND(100.0*COALESCE(a.active_ct,0)/cs.cohort_size,2)))
     FROM cohort_size cs LEFT JOIN active_m1 a ON a.signup_month=cs.signup_month) AS month1_retention_per_cohort,
  (SELECT jsonb_agg(jsonb_build_object('segment', seg, 'n', n)) FROM (
      SELECT CASE WHEN r>=4 AND f>=4 AND m>=4 THEN 'Champions' WHEN r<=2 AND f>=3 THEN 'At Risk' ELSE 'Other' END AS seg,
             COUNT(*) AS n FROM scored GROUP BY seg) y) AS rfm_segment_counts,
  (SELECT jsonb_agg(jsonb_build_object('region_id', region_id, 'month', month, 'mom_pct', mom_pct)) FROM monthly_rev_mom) AS mom_revenue_by_region;

/* Q94. */
WITH cohort_size AS (
  SELECT DATE_TRUNC('month', registration_date)::date AS signup_month, COUNT(DISTINCT customer_id) AS cohort_size
  FROM customers.customers GROUP BY DATE_TRUNC('month', registration_date)
),
active_m1 AS (
  SELECT DATE_TRUNC('month', c.registration_date)::date AS signup_month, COUNT(DISTINCT c.customer_id) AS active_ct
  FROM customers.customers c JOIN sales.orders o ON o.cust_id = c.customer_id
  WHERE (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), DATE_TRUNC('month', c.registration_date))) * 12
       + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), DATE_TRUNC('month', c.registration_date)))) = 1
  GROUP BY DATE_TRUNC('month', c.registration_date)
),
rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id, NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
         NTILE(5) OVER (ORDER BY order_count) AS f, NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
),
funnel AS (
  SELECT COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%product%') AS product,
         COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%checkout%') AS checkout
  FROM web_events.page_views
),
monthly_rev AS (
  SELECT DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS revenue FROM sales.orders GROUP BY DATE_TRUNC('month', order_date)
),
monthly_rev_mom AS (
  SELECT month, revenue, ROUND(100.0*(revenue-LAG(revenue) OVER (ORDER BY month))/NULLIF(LAG(revenue) OVER (ORDER BY month),0),2) AS mom_pct
  FROM monthly_rev
)
SELECT jsonb_build_object(
  'cohort_triangle', (SELECT jsonb_agg(jsonb_build_object('cohort', cs.signup_month, 'm1_pct', ROUND(100.0*COALESCE(a.active_ct,0)/cs.cohort_size,2)))
     FROM cohort_size cs LEFT JOIN active_m1 a ON a.signup_month=cs.signup_month),
  'rfm_segments', (SELECT jsonb_agg(jsonb_build_object('segment', seg, 'n', n)) FROM (
      SELECT CASE WHEN r>=4 AND f>=4 AND m>=4 THEN 'Champions' WHEN r<=2 AND f>=3 THEN 'At Risk' ELSE 'Other' END AS seg,
             COUNT(*) AS n FROM scored GROUP BY seg) y),
  'funnel_dropoff_pct', (SELECT ROUND(100.0*(product-checkout)/NULLIF(product,0),2) FROM funnel),
  'pop_revenue', (SELECT jsonb_agg(jsonb_build_object('month', month, 'mom_pct', mom_pct)) FROM monthly_rev_mom)
) AS exec_dashboard_json;

/* Q95. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id, days_since_last_order, lifetime_revenue,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f
  FROM rfm_raw
)
SELECT jsonb_agg(jsonb_build_object('customer_id', cust_id, 'days_since_last_order', days_since_last_order, 'clv', lifetime_revenue)
       ORDER BY lifetime_revenue DESC) AS reactivation_candidates_json
FROM scored WHERE r <= 2 AND f >= 3;

/* Q96. */
WITH funnel AS (
  SELECT device_type, DATE_TRUNC('month', view_timestamp) AS month,
    COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%product%') AS product,
    COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%cart%') AS cart,
    COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%checkout%') AS checkout
  FROM web_events.page_views GROUP BY device_type, DATE_TRUNC('month', view_timestamp)
),
drop_rates AS (
  SELECT device_type, month,
    ROUND(100.0*(product-cart)/NULLIF(product,0),2) AS drop_product_cart,
    ROUND(100.0*(cart-checkout)/NULLIF(cart,0),2) AS drop_cart_checkout
  FROM funnel
)
SELECT jsonb_build_object(
  'worst_step_per_device', jsonb_agg(jsonb_build_object('device', device_type, 'month', month,
    'worst_step', CASE WHEN drop_product_cart >= drop_cart_checkout THEN 'product_to_cart' ELSE 'cart_to_checkout' END))
) AS funnel_diagnostic_json
FROM drop_rates;

/* Q97. */
WITH cohort AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month FROM customers.customers
),
period_rev AS (
  SELECT co.signup_month,
    (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
     + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)))::int AS period_index,
    SUM(o.net_total) AS revenue
  FROM cohort co JOIN sales.orders o ON o.cust_id = co.customer_id
  WHERE (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
       + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month))) BETWEEN 0 AND 11
  GROUP BY co.signup_month, period_index
)
SELECT jsonb_build_object(
  'curves', jsonb_agg(jsonb_build_object('signup_month', signup_month, 'period', period_index, 'revenue', revenue)),
  'meta', jsonb_build_object('horizon_months', 12, 'status_filter', 'all', 'currency', 'INR')
) AS finance_cohort_ltv_export
FROM period_rev;

/* Q98. Drift alerting compares each cohort's Month-1 retention (or each RFM segment's size) this period to last period and flags any shift beyond a threshold - the runnable pattern is exactly the hard file's Q93 (top-movers cohort report), generalized to any tracked metric. */
/* Q99. The refresh DAG runs strictly in dependency order: Day-26 cleansed customers/orders/sessions first, then cohort and RFM MVs (both depend only on cleansed inputs, so they can refresh in parallel), then funnel MVs (depend on cleansed sessions), and finally the JSON export step, which only reads the already-refreshed MVs. */
/* Q100. Capstone: cohort triangle (retention Q26, cumulative LTV Q27) + versioned RFM segments with named labels and drift (Q53/Q56-Q58, v1/v2 divergence Q62) + a 4/5-step funnel with drop-off and inter-step timing (Q78/Q79) + MoM/YoY/QoQ decomposition (Q88) - delivered together as the exec JSON export in Q94, with the MV refresh order documented in Q99. */
