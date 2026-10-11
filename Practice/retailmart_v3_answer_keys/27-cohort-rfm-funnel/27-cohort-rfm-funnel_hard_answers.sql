/* ============================================================
   ANSWER KEY - Cohort, RFM & Funnel Queries (HARD LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* Q1.  Registration-anchored cohorts include people who never bought anything (good for measuring activation), while first-order-anchored cohorts only include buyers and shift each customer's "Month 0" to whenever they actually converted - the two shapes are not directly comparable. */
/* Q2.  Weekly cohorts react faster to a change (a new onboarding flow, a bad release) but each cohort is much smaller, so the retention line is noisier; monthly cohorts are smoother but slower to reveal a problem. */
/* Q3.  Long format (one row per cohort+period) is easy to filter, join, and export as JSON; wide format (one row per cohort, one column per period) is what a human reads as a triangle - SQL naturally produces long, and a pivot (in SQL or the BI tool) produces wide. */
/* Q4.  Divide by the cohort's size at period 0 when you want "value per original signup" (a stable, comparable denominator); divide by the active size in that period when you want "value per currently-engaged customer" (a different, also useful, question). */
/* Q5.  NTILE forces exactly equal bucket sizes even when the underlying metric has ties at the boundary, arbitrarily splitting equal values into different buckets; PERCENTILE_CONT computes an exact interpolated cutoff value, which is more defensible when explaining "why is this customer a 4 and not a 5". */
/* Q6.  A segment rule book documents, for each named segment (Champions, At-Risk, ...), the exact R/F/M score ranges that define it, who owns changing it, and where it's implemented - without this, two teams' dashboards can silently disagree on who counts as a "Champion". */
/* Q7.  Drift accounting joins the same customer's segment from period 1 to period 2, producing a transition matrix (from-segment x to-segment counts) that shows exactly how many people moved where, not just that the aggregate segment sizes changed. */
/* Q8.  Customer reach counts each person once no matter how many times they revisited a step; session reach counts each browsing session once; event count counts every individual click/view, inflating totals when one person retries a step many times. */
/* Q9.  A ratio chain (each step's count divided by the prior step's count) shows relative loss at each transition, which is what matters for diagnosing where the flow breaks; absolute deltas are dominated by whichever step simply has the most total traffic. */
/* Q10. Time-between-steps (the median or P95 gap between reaching step N and step N+1) reveals friction even when the eventual conversion rate looks fine - a funnel that converts but takes days to do so still signals a problem. */
/* Q11. Splitting a funnel by channel/device/region in a pivot (Day 21) reveals that overall healthy conversion can be hiding one channel that converts far worse than the blended average. */
/* Q12. Survivor bias in cohort analysis means only customers who are still around get measured at later periods - a cohort's Month-6 metrics implicitly exclude everyone who already churned, which can make an aging cohort look artificially healthy on remaining-customer metrics. */
/* Q13. A 12-month CLV horizon is comparable across cohorts of different ages and useful for near-term forecasting; lifetime CLV captures total value but keeps growing for older cohorts, so reporting both avoids over- or under-stating value. */
/* Q14. PoP growth decomposition splits total revenue change into the contribution from brand-new customers, previously-active repeat customers, and reactivated dormant customers - the same total growth number can come from very different underlying causes. */
/* Q15. Per-cohort PoP compares a cohort's revenue this month to the same cohort's revenue at the equivalent age last time (aging curve); simple PoP compares total company revenue month to month, blending cohorts of very different ages together. */
/* Q16. A spine of all expected (cohort, period) or (funnel, step) combinations, left-joined to actual activity, guarantees completeness - a truly-zero cell shows 0, instead of silently vanishing from a GROUP BY that only sees rows that exist. */
/* Q17. Day 26's cleansed, deduped customers/orders/sessions feed directly into cohort sizing, RFM's monetary/frequency values, and funnel session counts - a duplicate customer or an orphan order silently distorts every metric built on top of it. */
/* Q18. Cohort/funnel results that are read repeatedly by a dashboard but change slowly relative to how often they're queried (daily cohort grid, monthly funnel) are the clearest MV candidates on Day 25. */
/* Q19. On a 150k-order join with cohort/RFM logic, EXPLAIN ANALYZE reveals whether the planner chose a Hash Join (fast, needs enough work_mem) or fell back to a slow Nested Loop, and whether actual vs estimated row counts are close (stale statistics otherwise). */
/* Q20. A btree PK on customer_id, a btree on orders(order_date) (or a composite (cust_id, order_date)), and a btree on page_views(view_timestamp) each support the exact filters/joins the cohort, RFM, and funnel queries above already use. */
/* Q21. A JSON export wraps a triangle or funnel result as one jsonb array of objects (cohort, period, retention, ltv), giving a BI tool or alerting job a single self-describing payload instead of a raw multi-column result set. */
/* Q22. Point-in-time scoring recomputes R/F/M using only orders that existed as of a specific historical cutoff date, letting you compare "what would this customer's segment have been last quarter" instead of always looking at current-day values. */
/* Q23. Changing RFM score cutoffs (e.g. moving from NTILE(5) breakpoints to new ones) without versioning silently reclassifies every customer and breaks any historical trend line that assumed the old definition - a v1/v2 split preserves both. */
/* Q24. Marketing wants named, actionable segments to target campaigns; product wants step-by-step funnel counts to fix UX - both come from the same underlying orders/events tables, just aggregated differently for two different audiences. */
/* Q25. A runbook documents the exact SQL/logic behind cohort anchoring, RFM cutoffs, and funnel step definitions, plus who owns changes - without it, "why did retention change" becomes a re-investigation instead of a five-minute lookup. */

/* Q26. */
WITH cohort AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month FROM customers.customers
),
activity AS (
  SELECT co.signup_month, o.cust_id,
    (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
     + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)))::int AS period_index
  FROM cohort co JOIN sales.orders o ON o.cust_id = co.customer_id
)
SELECT signup_month, period_index, COUNT(DISTINCT cust_id) AS active_customers
FROM activity WHERE period_index BETWEEN 0 AND 11
GROUP BY signup_month, period_index
ORDER BY signup_month, period_index;

/* Q27. */
WITH cohort_size AS (
  SELECT DATE_TRUNC('month', registration_date)::date AS signup_month, COUNT(DISTINCT customer_id) AS cohort_size
  FROM customers.customers GROUP BY DATE_TRUNC('month', registration_date)
),
cohort AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month FROM customers.customers
),
activity AS (
  SELECT co.signup_month, o.cust_id,
    (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
     + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)))::int AS period_index
  FROM cohort co JOIN sales.orders o ON o.cust_id = co.customer_id
),
grid AS (
  SELECT signup_month, period_index, COUNT(DISTINCT cust_id) AS active_customers
  FROM activity WHERE period_index BETWEEN 0 AND 11
  GROUP BY signup_month, period_index
)
SELECT g.signup_month, g.period_index, ROUND(100.0*g.active_customers/cs.cohort_size,2) AS retention_pct
FROM grid g JOIN cohort_size cs ON cs.signup_month = g.signup_month
ORDER BY g.signup_month, g.period_index;

/* Q28. */
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

/* Q29. */
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
),
running AS (
  SELECT signup_month, period_index, SUM(revenue) OVER (PARTITION BY signup_month ORDER BY period_index) AS cum_ltv
  FROM period_rev
)
SELECT signup_month,
  MAX(cum_ltv) FILTER (WHERE period_index=0) AS p0, MAX(cum_ltv) FILTER (WHERE period_index=1) AS p1,
  MAX(cum_ltv) FILTER (WHERE period_index=3) AS p3, MAX(cum_ltv) FILTER (WHERE period_index=6) AS p6,
  MAX(cum_ltv) FILTER (WHERE period_index=11) AS p11
FROM running GROUP BY signup_month ORDER BY signup_month;

/* Q30. */
WITH cohort AS (
  SELECT c.customer_id, DATE_TRUNC('month', c.registration_date)::date AS signup_month, r.region_name
  FROM customers.customers c
  JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = true
  JOIN core.dim_region r ON r.state = a.state
),
cohort_size AS (
  SELECT region_name, signup_month, COUNT(DISTINCT customer_id) AS cohort_size FROM cohort GROUP BY region_name, signup_month
),
activity AS (
  SELECT co.region_name, co.signup_month, o.cust_id,
    (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
     + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)))::int AS period_index
  FROM cohort co JOIN sales.orders o ON o.cust_id = co.customer_id
),
grid AS (
  SELECT region_name, signup_month, period_index, COUNT(DISTINCT cust_id) AS active_customers
  FROM activity WHERE period_index BETWEEN 0 AND 11 GROUP BY region_name, signup_month, period_index
)
SELECT g.region_name, g.signup_month, g.period_index, ROUND(100.0*g.active_customers/cs.cohort_size,2) AS retention_pct
FROM grid g JOIN cohort_size cs ON cs.region_name=g.region_name AND cs.signup_month=g.signup_month
ORDER BY g.region_name, g.signup_month, g.period_index;

/* Q31. */
WITH cohort AS (
  SELECT customer_id, tier, DATE_TRUNC('month', registration_date)::date AS signup_month FROM customers.customers
),
cohort_size AS (SELECT tier, signup_month, COUNT(DISTINCT customer_id) AS cohort_size FROM cohort GROUP BY tier, signup_month),
activity AS (
  SELECT co.tier, co.signup_month, o.cust_id,
    (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
     + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)))::int AS period_index
  FROM cohort co JOIN sales.orders o ON o.cust_id = co.customer_id
),
grid AS (
  SELECT tier, signup_month, period_index, COUNT(DISTINCT cust_id) AS active_customers
  FROM activity WHERE period_index BETWEEN 0 AND 11 GROUP BY tier, signup_month, period_index
)
SELECT g.tier, g.signup_month, g.period_index, ROUND(100.0*g.active_customers/cs.cohort_size,2) AS retention_pct
FROM grid g JOIN cohort_size cs ON cs.tier=g.tier AND cs.signup_month=g.signup_month
ORDER BY g.tier, g.signup_month, g.period_index;

/* Q32. */
WITH cohort AS (
  SELECT customer_id, DATE_TRUNC('week', registration_date)::date AS signup_week FROM customers.customers
),
cohort_size AS (SELECT signup_week, COUNT(DISTINCT customer_id) AS cohort_size FROM cohort GROUP BY signup_week),
activity AS (
  SELECT co.signup_week, o.cust_id,
    (EXTRACT(EPOCH FROM (DATE_TRUNC('week', o.order_date) - co.signup_week)) / 604800)::int AS week_index
  FROM cohort co JOIN sales.orders o ON o.cust_id = co.customer_id
),
grid AS (
  SELECT signup_week, week_index, COUNT(DISTINCT cust_id) AS active_customers
  FROM activity WHERE week_index BETWEEN 0 AND 12 GROUP BY signup_week, week_index
)
SELECT g.signup_week, g.week_index, ROUND(100.0*g.active_customers/cs.cohort_size,2) AS retention_pct
FROM grid g JOIN cohort_size cs ON cs.signup_week = g.signup_week
ORDER BY g.signup_week, g.week_index;

/* Q33. */
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
SELECT fg.signup_month, fg.period_index, COALESCE(g.active_customers,0) AS active_customers
FROM full_grid fg LEFT JOIN grid g ON g.signup_month=fg.signup_month AND g.period_index=fg.period_index
ORDER BY fg.signup_month, fg.period_index;

/* Q34. */
SELECT
  (SELECT SUM(cohort_size) FROM (SELECT COUNT(DISTINCT customer_id) AS cohort_size FROM customers.customers
    GROUP BY DATE_TRUNC('month', registration_date)) x) AS sum_across_grid,
  (SELECT COUNT(*) FROM customers.customers) AS total_customers;

/* Q35. */
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
SELECT cs.signup_month, ROUND(100.0*COALESCE(a.active_ct,0)/cs.cohort_size,2) AS month1_retention_pct
FROM cohort_size cs LEFT JOIN active_m1 a ON a.signup_month=cs.signup_month
ORDER BY month1_retention_pct DESC NULLS LAST LIMIT 1;

/* Q36. */
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
)
SELECT cs.signup_month, ROUND(100.0*COALESCE(a.active_ct,0)/cs.cohort_size,2) AS month3_retention_pct
FROM cohort_size cs LEFT JOIN active_m3 a ON a.signup_month=cs.signup_month
ORDER BY month3_retention_pct DESC NULLS LAST LIMIT 1;

/* Q37. */
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
       + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month))) <= 11
  GROUP BY co.signup_month, period_index
),
ltv AS (SELECT signup_month, SUM(revenue) AS ltv_12mo FROM period_rev GROUP BY signup_month)
SELECT signup_month, ltv_12mo FROM ltv ORDER BY ltv_12mo DESC LIMIT 1;

/* Q38. */
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
)
SELECT cs.signup_month, ROUND(100.0*COALESCE(a.active_ct,0)/cs.cohort_size,2) AS month3_retention_pct
FROM cohort_size cs LEFT JOIN active_m3 a ON a.signup_month=cs.signup_month
ORDER BY month3_retention_pct ASC NULLS FIRST LIMIT 1;

/* Q39. */
WITH cohort AS (
  SELECT c.customer_id, DATE_TRUNC('month', c.registration_date)::date AS signup_month, r.region_name
  FROM customers.customers c
  JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = true
  JOIN core.dim_region r ON r.state = a.state
),
cohort_size AS (SELECT region_name, signup_month, COUNT(DISTINCT customer_id) AS cohort_size FROM cohort GROUP BY region_name, signup_month),
active_m1 AS (
  SELECT co.region_name, co.signup_month, COUNT(DISTINCT o.cust_id) AS active_ct
  FROM cohort co JOIN sales.orders o ON o.cust_id = co.customer_id
  WHERE (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
       + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month))) = 1
  GROUP BY co.region_name, co.signup_month
)
SELECT cs.region_name, cs.signup_month, ROUND(100.0*COALESCE(a.active_ct,0)/cs.cohort_size,2) AS month1_retention_pct
FROM cohort_size cs LEFT JOIN active_m1 a ON a.region_name=cs.region_name AND a.signup_month=cs.signup_month
ORDER BY cs.region_name, cs.signup_month;

/* Q40. */
WITH cohort AS (
  SELECT customer_id, tier, DATE_TRUNC('month', registration_date)::date AS signup_month FROM customers.customers
),
period_rev AS (
  SELECT co.tier,
    (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
     + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)))::int AS period_index,
    SUM(o.net_total) AS revenue
  FROM cohort co JOIN sales.orders o ON o.cust_id = co.customer_id
  GROUP BY co.tier, period_index
)
SELECT tier, period_index, SUM(revenue) OVER (PARTITION BY tier ORDER BY period_index) AS cumulative_ltv
FROM period_rev ORDER BY tier, period_index;

/* Q41. */
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

/* Q42. */
WITH cohort AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month FROM customers.customers
),
activity AS (
  SELECT co.signup_month, o.cust_id,
    (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
     + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)))::int AS period_index
  FROM cohort co JOIN sales.orders o ON o.cust_id = co.customer_id
),
ordered AS (
  SELECT signup_month, cust_id, period_index,
    LAG(period_index) OVER (PARTITION BY signup_month, cust_id ORDER BY period_index) AS prev_period
  FROM (SELECT DISTINCT signup_month, cust_id, period_index FROM activity) x
)
SELECT signup_month, COUNT(DISTINCT cust_id) AS reactivated_customers
FROM ordered
WHERE period_index - prev_period > 1
GROUP BY signup_month ORDER BY signup_month;

/* Q43. */
WITH cohort AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month FROM customers.customers
),
active_months AS (
  SELECT co.signup_month, o.cust_id, COUNT(DISTINCT DATE_TRUNC('month', o.order_date)) AS active_month_ct
  FROM cohort co JOIN sales.orders o ON o.cust_id = co.customer_id
  GROUP BY co.signup_month, o.cust_id
)
SELECT signup_month, COUNT(*) FILTER (WHERE active_month_ct >= 3) AS survivors_3plus_months, COUNT(*) AS cohort_customers_with_orders
FROM active_months GROUP BY signup_month ORDER BY signup_month;

/* Q44. */
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

/* Q45. */
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
       + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month))) <= 11
  GROUP BY co.signup_month, period_index
),
ltv AS (SELECT signup_month, SUM(revenue) AS ltv_12mo FROM period_rev GROUP BY signup_month)
SELECT EXTRACT(YEAR FROM signup_month)::int AS signup_year, ROUND(AVG(ltv_12mo),2) AS avg_12mo_ltv
FROM ltv WHERE EXTRACT(YEAR FROM signup_month) IN (2024,2025)
GROUP BY signup_year ORDER BY signup_year;

/* Q46. */
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
SELECT jsonb_agg(jsonb_build_object('signup_month', g.signup_month, 'period', g.period_index,
       'retention', ROUND(100.0*g.active_customers/cs.cohort_size,2))) AS cohort_json
FROM grid g JOIN cohort_size cs ON cs.signup_month = g.signup_month;

/* Q47. A cohort x period retention/LTV MV is a strong Day-25 candidate given the query cost of recomputing AGE()-based period_index over 150k orders on every dashboard load - a nightly refresh cadence (registrations and orders both accumulate daily, not intra-day) is more than sufficient. */

/* Q48. This is a plan-inspection exercise over the full cohort join (150k orders x 50k customers). */
EXPLAIN (ANALYZE, BUFFERS)
SELECT co.signup_month, o.cust_id,
  (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
   + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)))::int AS period_index
FROM (SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month FROM customers.customers) co
JOIN sales.orders o ON o.cust_id = co.customer_id;

/* Q49. A composite btree index on sales.orders(cust_id, order_date) would let the cohort join both find each customer's orders and read order_date in sorted order in one index scan, instead of a full sort step after a plain hash join. */

/* Q50. */
WITH monthly_active AS (
  SELECT DATE_TRUNC('month', order_date) AS month, COUNT(DISTINCT cust_id) AS mau
  FROM sales.orders GROUP BY DATE_TRUNC('month', order_date)
),
cohort_active AS (
  SELECT c.customer_id, DATE_TRUNC('month', c.registration_date)::date AS signup_month,
    DATE_TRUNC('month', o.order_date) AS active_month
  FROM customers.customers c JOIN sales.orders o ON o.cust_id = c.customer_id
),
cohort_mau AS (
  SELECT active_month AS month, COUNT(DISTINCT customer_id) AS cohort_derived_mau
  FROM cohort_active GROUP BY active_month
)
SELECT m.month, m.mau, cm.cohort_derived_mau, (m.mau = cm.cohort_derived_mau) AS reconciled
FROM monthly_active m JOIN cohort_mau cm ON cm.month = m.month
ORDER BY m.month;

/* Q51. */
SELECT cust_id,
       (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
       COUNT(*) AS frequency, SUM(net_total) AS monetary
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
SELECT cust_id, (r::text||f::text||m::text) AS rfm_string, (r+f+m) AS rfm_total FROM scored;

/* Q54. */
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

/* Q55. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id, NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
         NTILE(5) OVER (ORDER BY order_count) AS f, NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
),
segmented AS (
  SELECT cust_id,
  CASE WHEN r>=4 AND f>=4 AND m>=4 THEN 'Champions' WHEN r>=3 AND f>=4 THEN 'Loyal Customers'
       WHEN r>=4 AND f BETWEEN 2 AND 3 THEN 'Potential Loyalists' WHEN r=5 AND f=1 THEN 'New Customers'
       WHEN r>=3 AND f<=2 AND m<=2 THEN 'Promising' WHEN r=3 AND f=3 THEN 'Need Attention'
       WHEN r=2 AND f<=2 THEN 'About to Sleep' WHEN r<=2 AND f>=3 THEN 'At Risk'
       WHEN r<=2 AND f<=2 AND m<=2 AND r>1 THEN 'Hibernating' WHEN r=1 AND f=1 AND m=1 THEN 'Lost'
       ELSE 'Other' END AS segment
  FROM scored
)
SELECT segment, COUNT(*) AS n, (SELECT COUNT(*) FROM segmented) AS total_customers
FROM segmented GROUP BY segment ORDER BY n DESC;

/* Q56. */
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
  SELECT cust_id, lifetime_revenue,
  CASE WHEN r>=4 AND f>=4 AND m>=4 THEN 'Champions' WHEN r>=3 AND f>=4 THEN 'Loyal Customers'
       WHEN r>=4 AND f BETWEEN 2 AND 3 THEN 'Potential Loyalists' WHEN r=5 AND f=1 THEN 'New Customers'
       WHEN r>=3 AND f<=2 AND m<=2 THEN 'Promising' WHEN r=3 AND f=3 THEN 'Need Attention'
       WHEN r=2 AND f<=2 THEN 'About to Sleep' WHEN r<=2 AND f>=3 THEN 'At Risk'
       WHEN r<=2 AND f<=2 AND m<=2 AND r>1 THEN 'Hibernating' WHEN r=1 AND f=1 AND m=1 THEN 'Lost'
       ELSE 'Other' END AS segment
  FROM scored
)
SELECT segment,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY lifetime_revenue)::numeric,2) AS median_clv,
  ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY lifetime_revenue)::numeric,2) AS p95_clv
FROM segmented GROUP BY segment ORDER BY median_clv DESC;

/* Q57. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id, NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
         NTILE(5) OVER (ORDER BY order_count) AS f, NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
),
segmented AS (
  SELECT cust_id,
  CASE WHEN r>=4 AND f>=4 AND m>=4 THEN 'Champions' WHEN r>=3 AND f>=4 THEN 'Loyal Customers'
       WHEN r>=4 AND f BETWEEN 2 AND 3 THEN 'Potential Loyalists' WHEN r=5 AND f=1 THEN 'New Customers'
       WHEN r>=3 AND f<=2 AND m<=2 THEN 'Promising' WHEN r=3 AND f=3 THEN 'Need Attention'
       WHEN r=2 AND f<=2 THEN 'About to Sleep' WHEN r<=2 AND f>=3 THEN 'At Risk'
       WHEN r<=2 AND f<=2 AND m<=2 AND r>1 THEN 'Hibernating' WHEN r=1 AND f=1 AND m=1 THEN 'Lost'
       ELSE 'Other' END AS segment
  FROM scored
)
SELECT reg.region_name, s.segment, COUNT(*) AS n
FROM segmented s
JOIN customers.addresses a ON a.customer_id = s.cust_id AND a.is_default = true
JOIN core.dim_region reg ON reg.state = a.state
GROUP BY reg.region_name, s.segment ORDER BY reg.region_name, s.segment;

/* Q58. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id, NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
         NTILE(5) OVER (ORDER BY order_count) AS f, NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
),
segmented AS (
  SELECT cust_id,
  CASE WHEN r>=4 AND f>=4 AND m>=4 THEN 'Champions' WHEN r>=3 AND f>=4 THEN 'Loyal Customers'
       WHEN r>=4 AND f BETWEEN 2 AND 3 THEN 'Potential Loyalists' WHEN r=5 AND f=1 THEN 'New Customers'
       WHEN r>=3 AND f<=2 AND m<=2 THEN 'Promising' WHEN r=3 AND f=3 THEN 'Need Attention'
       WHEN r=2 AND f<=2 THEN 'About to Sleep' WHEN r<=2 AND f>=3 THEN 'At Risk'
       WHEN r<=2 AND f<=2 AND m<=2 AND r>1 THEN 'Hibernating' WHEN r=1 AND f=1 AND m=1 THEN 'Lost'
       ELSE 'Other' END AS segment
  FROM scored
)
SELECT DATE_TRUNC('month', c.registration_date)::date AS signup_month, s.segment, COUNT(*) AS n
FROM segmented s JOIN customers.customers c ON c.customer_id = s.cust_id
GROUP BY signup_month, s.segment ORDER BY signup_month, s.segment;

/* Q59. Segment Q1 vs Q2 transition matrices require point-in-time RFM scoring at two historical cutoffs - the full runnable version is Q60/Q61 below, computed against the same order history truncated at each quarter-end. */

/* Q60. */
WITH q1_end AS (SELECT DATE '2025-03-31' AS cutoff),
     q2_end AS (SELECT DATE '2025-06-30' AS cutoff),
q1_rfm AS (
  SELECT cust_id, (SELECT cutoff FROM q1_end) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders WHERE order_date <= (SELECT cutoff FROM q1_end) GROUP BY cust_id
),
q1_scored AS (
  SELECT cust_id,
    CASE WHEN NTILE(5) OVER (ORDER BY days_since_last_order DESC) >= 4
          AND NTILE(5) OVER (ORDER BY order_count) >= 4 THEN 'Champions_or_Loyal' ELSE 'Other' END AS q1_segment
  FROM q1_rfm
),
q2_rfm AS (
  SELECT cust_id, (SELECT cutoff FROM q2_end) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders WHERE order_date <= (SELECT cutoff FROM q2_end) GROUP BY cust_id
),
q2_scored AS (
  SELECT cust_id,
    CASE WHEN NTILE(5) OVER (ORDER BY days_since_last_order DESC) >= 4
          AND NTILE(5) OVER (ORDER BY order_count) >= 4 THEN 'Champions_or_Loyal' ELSE 'Other' END AS q2_segment
  FROM q2_rfm
)
SELECT q1.q1_segment, q2.q2_segment, COUNT(*) AS customer_ct
FROM q1_scored q1 JOIN q2_scored q2 ON q2.cust_id = q1.cust_id
GROUP BY q1.q1_segment, q2.q2_segment
ORDER BY q1.q1_segment, q2.q2_segment;

/* Q61. */
WITH q1_end AS (SELECT DATE '2025-03-31' AS cutoff),
     q2_end AS (SELECT DATE '2025-06-30' AS cutoff),
q1_rfm AS (
  SELECT cust_id, (SELECT cutoff FROM q1_end) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders WHERE order_date <= (SELECT cutoff FROM q1_end) GROUP BY cust_id
),
q1_scored AS (
  SELECT cust_id,
    CASE WHEN NTILE(5) OVER (ORDER BY days_since_last_order DESC) >= 4
          AND NTILE(5) OVER (ORDER BY order_count) >= 4
          AND NTILE(5) OVER (ORDER BY lifetime_revenue) >= 4 THEN 'Champions' ELSE 'Other' END AS q1_segment
  FROM q1_rfm
),
q2_rfm AS (
  SELECT cust_id, (SELECT cutoff FROM q2_end) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders WHERE order_date <= (SELECT cutoff FROM q2_end) GROUP BY cust_id
),
q2_scored AS (
  SELECT cust_id,
    CASE WHEN NTILE(5) OVER (ORDER BY days_since_last_order DESC) >= 4
          AND NTILE(5) OVER (ORDER BY order_count) >= 4
          AND NTILE(5) OVER (ORDER BY lifetime_revenue) >= 4 THEN 'Champions'
         WHEN NTILE(5) OVER (ORDER BY days_since_last_order DESC) <= 2
          AND NTILE(5) OVER (ORDER BY order_count) >= 3 THEN 'At Risk'
         ELSE 'Other' END AS q2_segment
  FROM q2_rfm
)
SELECT q2.q2_segment, COUNT(*) AS former_champions_now
FROM q1_scored q1 JOIN q2_scored q2 ON q2.cust_id = q1.cust_id
WHERE q1.q1_segment = 'Champions'
GROUP BY q2.q2_segment ORDER BY former_champions_now DESC;

/* Q62. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id, lifetime_revenue, NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
         NTILE(5) OVER (ORDER BY order_count) AS f, NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
)
SELECT cust_id, lifetime_revenue FROM scored WHERE r <= 2 AND m >= 4;

/* Q63. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id, order_count, NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
         NTILE(5) OVER (ORDER BY order_count) AS f, NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
)
SELECT cust_id, order_count FROM scored WHERE r <= 2 AND f <= 2 AND order_count >= 5;

/* Q64. */
SELECT DATE_TRUNC('month', registration_date)::date AS reg_month, COUNT(*) AS new_customers
FROM customers.customers GROUP BY DATE_TRUNC('month', registration_date) ORDER BY reg_month;

/* Q65. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
)
SELECT ROUND(AVG(order_count),2) AS avg_orders, ROUND(AVG(lifetime_revenue),2) AS avg_lifetime_revenue
FROM rfm_raw;

/* Q66. */
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
  CASE WHEN r>=4 AND f>=4 AND m>=4 THEN 'Champions' WHEN r>=3 AND f>=4 THEN 'Loyal Customers'
       WHEN r<=2 AND f>=3 THEN 'At Risk' WHEN r=1 AND f=1 AND m=1 THEN 'Lost' ELSE 'Other' END AS segment
  FROM scored
)
SELECT segment,
  PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY lifetime_revenue) AS p25,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY lifetime_revenue) AS p50,
  PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY lifetime_revenue) AS p75
FROM segmented GROUP BY segment ORDER BY p50 DESC;

/* Q67. */
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
  SELECT cust_id, lifetime_revenue,
  CASE WHEN r>=4 AND f>=4 AND m>=4 THEN 'Champions' WHEN r>=3 AND f>=4 THEN 'Loyal Customers'
       WHEN r<=2 AND f>=3 THEN 'At Risk' WHEN r=1 AND f=1 AND m=1 THEN 'Lost' ELSE 'Other' END AS segment
  FROM scored
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY segment ORDER BY lifetime_revenue DESC) AS rk FROM segmented
)
SELECT segment, cust_id, lifetime_revenue FROM ranked WHERE rk <= 10 ORDER BY segment, rk;

/* Q68. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
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
),
sla AS (
  SELECT s.cust_id, s.segment,
    (sh.delivered_date - sh.shipped_date) AS delivery_days
  FROM segmented s
  JOIN sales.orders o ON o.cust_id = s.cust_id
  JOIN sales.shipments sh ON sh.order_id = o.order_id
  WHERE sh.delivered_date IS NOT NULL AND sh.shipped_date IS NOT NULL
)
SELECT segment, ROUND(100.0*COUNT(*) FILTER (WHERE delivery_days > 5)/COUNT(*),2) AS pct_sla_breach
FROM sla GROUP BY segment ORDER BY segment;

/* Q69. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
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
SELECT s.segment, ROUND(AVG(t.ticket_ct),2) AS avg_tickets_per_customer
FROM segmented s
LEFT JOIN (SELECT customer_id, COUNT(*) AS ticket_ct FROM support.tickets GROUP BY customer_id) t
  ON t.customer_id = s.cust_id
GROUP BY s.segment ORDER BY s.segment;

/* Q70. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
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
SELECT jsonb_agg(jsonb_build_object('segment', segment, 'customer_ct', n)) AS rfm_segment_json
FROM (SELECT segment, COUNT(*) AS n FROM segmented GROUP BY segment) x;

/* Q71. */
WITH quarter_end AS (SELECT DATE '2025-06-30' AS cutoff)
SELECT cust_id, (SELECT cutoff FROM quarter_end) - MAX(order_date) AS days_since_last_order,
       COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
FROM sales.orders
WHERE order_date <= (SELECT cutoff FROM quarter_end)
GROUP BY cust_id;

/* Q72. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
v1 AS (
  SELECT cust_id,
    CASE WHEN NTILE(5) OVER (ORDER BY days_since_last_order DESC) >= 4
          AND NTILE(5) OVER (ORDER BY order_count) >= 4 THEN 'Champions' ELSE 'Other' END AS segment_v1
  FROM rfm_raw
),
v2 AS (
  SELECT cust_id,
    CASE WHEN NTILE(10) OVER (ORDER BY days_since_last_order DESC) >= 8
          AND NTILE(10) OVER (ORDER BY order_count) >= 8 THEN 'Champions' ELSE 'Other' END AS segment_v2
  FROM rfm_raw
)
SELECT v1.segment_v1, v2.segment_v2, COUNT(*) AS n
FROM v1 JOIN v2 ON v2.cust_id = v1.cust_id
GROUP BY v1.segment_v1, v2.segment_v2
ORDER BY v1.segment_v1, v2.segment_v2;

/* Q73. */
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
month3_retention AS (
  SELECT cs.signup_month, ROUND(100.0*COALESCE(a.active_ct,0)/cs.cohort_size,2) AS month3_retention_pct
  FROM cohort_size cs LEFT JOIN active_m3 a ON a.signup_month = cs.signup_month
),
rfm_raw AS (
  SELECT o.cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(o.order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(o.net_total) AS lifetime_revenue
  FROM sales.orders o GROUP BY o.cust_id
),
scored AS (
  SELECT cust_id, NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r FROM rfm_raw
)
SELECT DATE_TRUNC('month', c.registration_date)::date AS signup_month,
       ROUND(AVG(CASE WHEN s.r >= 4 THEN 1.0 ELSE 0.0 END),3) AS pct_high_recency,
       m3.month3_retention_pct
FROM customers.customers c
JOIN scored s ON s.cust_id = c.customer_id
JOIN month3_retention m3 ON m3.signup_month = DATE_TRUNC('month', c.registration_date)::date
GROUP BY DATE_TRUNC('month', c.registration_date)::date, m3.month3_retention_pct
ORDER BY signup_month;

/* Q74. */
WITH region_metric AS (
  SELECT r.region_id, o.cust_id, SUM(o.net_total) AS revenue
  FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id JOIN core.dim_region r ON r.region_id = s.region_id
  GROUP BY r.region_id, o.cust_id
),
baseline AS (
  SELECT region_id, PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY revenue) AS p95 FROM region_metric GROUP BY region_id
)
SELECT rm.region_id, rm.cust_id, rm.revenue, b.p95
FROM region_metric rm JOIN baseline b ON b.region_id = rm.region_id
WHERE rm.revenue > b.p95;

/* Q75. */
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
SELECT COUNT(*) AS scored_customers, (SELECT COUNT(DISTINCT cust_id) FROM sales.orders) AS customers_with_orders
FROM scored;

/* Q76. */
SELECT
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
    COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%product%') AS product,
    COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%cart%') AS cart,
    COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%checkout%') AS checkout,
    (SELECT COUNT(DISTINCT cust_id) FROM sales.orders) AS ordered
  FROM web_events.page_views
)
SELECT ROUND(100.0*(product-cart)/NULLIF(product,0),2) AS pct_lost_product_cart,
       ROUND(100.0*(cart-checkout)/NULLIF(cart,0),2) AS pct_lost_cart_checkout,
       ROUND(100.0*(checkout-ordered)/NULLIF(checkout,0),2) AS pct_lost_checkout_order
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
  ROUND(EXTRACT(EPOCH FROM PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY t_cart-t_product))/60.0,2) AS median_min_product_to_cart,
  ROUND(EXTRACT(EPOCH FROM PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY t_cart-t_product))/60.0,2) AS p95_min_product_to_cart,
  ROUND(EXTRACT(EPOCH FROM PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY t_checkout-t_cart))/60.0,2) AS median_min_cart_to_checkout,
  ROUND(EXTRACT(EPOCH FROM PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY t_checkout-t_cart))/60.0,2) AS p95_min_cart_to_checkout
FROM steps WHERE t_cart > t_product AND t_checkout > t_cart;

/* Q80. */
SELECT device_type, DATE_TRUNC('month', view_timestamp)::date AS month,
  COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%product%') AS product,
  COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%cart%') AS cart,
  COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%checkout%') AS checkout
FROM web_events.page_views
GROUP BY device_type, DATE_TRUNC('month', view_timestamp)
ORDER BY device_type, month;

/* Q81. */
SELECT DATE_TRUNC('month', c.registration_date)::date AS signup_month, r.region_name,
  COUNT(DISTINCT p.customer_id) FILTER (WHERE p.page_url LIKE '%product%') AS product,
  COUNT(DISTINCT p.customer_id) FILTER (WHERE p.page_url LIKE '%checkout%') AS checkout
FROM web_events.page_views p
JOIN customers.customers c ON c.customer_id = p.customer_id
JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = true
JOIN core.dim_region r ON r.state = a.state
GROUP BY signup_month, r.region_name ORDER BY signup_month, r.region_name;

/* Q82. */
WITH funnel AS (
  SELECT device_type, DATE_TRUNC('month', view_timestamp) AS month,
    COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%checkout%') AS checkout,
    COUNT(DISTINCT customer_id) AS visitors
  FROM web_events.page_views GROUP BY device_type, DATE_TRUNC('month', view_timestamp)
)
SELECT device_type, month, ROUND(100.0*checkout/NULLIF(visitors,0),2) AS conversion_rate_pct
FROM funnel ORDER BY device_type, month;

/* Q83. */
WITH monthly_funnel AS (
  SELECT device_type, DATE_TRUNC('month', view_timestamp) AS month,
    COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%checkout%') AS checkout
  FROM web_events.page_views GROUP BY device_type, DATE_TRUNC('month', view_timestamp)
)
SELECT device_type, month, checkout,
  checkout - LAG(checkout) OVER (PARTITION BY device_type ORDER BY month) AS mom_change
FROM monthly_funnel ORDER BY device_type, month;

/* Q84. */
WITH monthly_funnel AS (
  SELECT device_type, DATE_TRUNC('month', view_timestamp) AS month,
    COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%checkout%') AS checkout
  FROM web_events.page_views GROUP BY device_type, DATE_TRUNC('month', view_timestamp)
)
SELECT device_type, month, checkout,
  checkout - LAG(checkout,12) OVER (PARTITION BY device_type ORDER BY month) AS yoy_change
FROM monthly_funnel ORDER BY device_type, month;

/* Q85. */
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

/* Q86. */
WITH first_order AS (
  SELECT cust_id, DATE_TRUNC('month', MIN(order_date)) AS first_order_month FROM sales.orders GROUP BY cust_id
),
monthly_orders AS (
  SELECT o.cust_id, DATE_TRUNC('month', o.order_date) AS month, o.net_total, fo.first_order_month
  FROM sales.orders o JOIN first_order fo ON fo.cust_id = o.cust_id
)
SELECT month,
  SUM(net_total) FILTER (WHERE month = first_order_month) AS new_customer_revenue,
  SUM(net_total) FILTER (WHERE month > first_order_month) AS returning_customer_revenue
FROM monthly_orders GROUP BY month ORDER BY month;

/* Q87. */
WITH first_order AS (
  SELECT cust_id, MIN(order_date) AS first_order_date FROM sales.orders GROUP BY cust_id
),
activity AS (
  SELECT o.cust_id, DATE_TRUNC('month', o.order_date) AS month,
    (o.order_date = fo.first_order_date) AS is_first_order
  FROM sales.orders o JOIN first_order fo ON fo.cust_id = o.cust_id
),
monthly_status AS (
  SELECT cust_id, month,
    LAG(month) OVER (PARTITION BY cust_id ORDER BY month) AS prev_active_month, is_first_order
  FROM (SELECT DISTINCT cust_id, month, is_first_order FROM activity) x
)
SELECT month,
  COUNT(DISTINCT cust_id) FILTER (WHERE is_first_order) AS new_customers,
  COUNT(DISTINCT cust_id) FILTER (WHERE NOT is_first_order AND prev_active_month = month - INTERVAL '1 month') AS returning_customers,
  COUNT(DISTINCT cust_id) FILTER (WHERE NOT is_first_order AND (prev_active_month IS NULL OR prev_active_month < month - INTERVAL '1 month')) AS reactivated_customers
FROM monthly_status GROUP BY month ORDER BY month;

/* Q88. */
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
  revenue - LAG(revenue) OVER (PARTITION BY signup_month ORDER BY month) AS mom_change
FROM period_rev ORDER BY signup_month, month;

/* Q89. */
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
  SELECT cust_id, (r>=4 AND f>=4 AND m>=4) AS is_champion FROM scored
),
funnel AS (
  SELECT s.is_champion,
    COUNT(DISTINCT p.customer_id) FILTER (WHERE p.page_url LIKE '%cart%') AS cart,
    COUNT(DISTINCT p.customer_id) FILTER (WHERE p.page_url LIKE '%checkout%') AS checkout
  FROM segmented s
  JOIN web_events.page_views p ON p.customer_id = s.cust_id
  GROUP BY s.is_champion
)
SELECT is_champion, cart, checkout, ROUND(100.0*checkout/NULLIF(cart,0),2) AS cart_to_checkout_pct
FROM funnel;

/* Q90. */
WITH steps AS (
  SELECT
    COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%product%') AS product,
    COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%cart%') AS cart,
    COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%checkout%') AS checkout
  FROM web_events.page_views
),
timing AS (
  SELECT customer_id,
    MIN(view_timestamp) FILTER (WHERE page_url LIKE '%product%') AS t_product,
    MIN(view_timestamp) FILTER (WHERE page_url LIKE '%cart%') AS t_cart
  FROM web_events.page_views GROUP BY customer_id
)
SELECT jsonb_build_object(
  'product', s.product, 'cart', s.cart, 'checkout', s.checkout,
  'drop_product_to_cart_pct', ROUND(100.0*(s.product-s.cart)/NULLIF(s.product,0),2),
  'median_minutes_product_to_cart',
    ROUND(EXTRACT(EPOCH FROM PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY t.t_cart - t.t_product))/60.0,2)
) AS funnel_json
FROM steps s, timing t
WHERE t.t_cart > t.t_product
GROUP BY s.product, s.cart, s.checkout;

/* Q91. */
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
  SELECT cust_id, lifetime_revenue,
  CASE WHEN r>=4 AND f>=4 AND m>=4 THEN 'Champions' WHEN r<=2 AND f>=3 THEN 'At Risk' ELSE 'Other' END AS segment
  FROM scored
),
clv_by_month AS (
  SELECT s.segment, DATE_TRUNC('month', o.order_date) AS month, SUM(o.net_total) AS revenue
  FROM segmented s JOIN sales.orders o ON o.cust_id = s.cust_id
  GROUP BY s.segment, DATE_TRUNC('month', o.order_date)
)
SELECT segment, month, revenue,
  ROUND(100.0*(revenue-LAG(revenue) OVER (PARTITION BY segment ORDER BY month))/NULLIF(LAG(revenue) OVER (PARTITION BY segment ORDER BY month),0),2) AS mom_pct
FROM clv_by_month ORDER BY segment, month;

/* Q92. */
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
  FROM activity WHERE period_index BETWEEN 0 AND 6 GROUP BY signup_month, period_index
)
SELECT jsonb_agg(jsonb_build_object('signup_month', g.signup_month, 'period', g.period_index,
       'retention', ROUND(100.0*g.active_customers/cs.cohort_size,2))) AS triangle_json
FROM grid g JOIN cohort_size cs ON cs.signup_month = g.signup_month;

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
retention AS (
  SELECT cs.signup_month, ROUND(100.0*COALESCE(a.active_ct,0)/cs.cohort_size,2) AS m1_pct
  FROM cohort_size cs LEFT JOIN active_m1 a ON a.signup_month=cs.signup_month
)
SELECT signup_month, m1_pct,
  m1_pct - LAG(m1_pct) OVER (ORDER BY signup_month) AS shift_vs_prev_cohort
FROM retention
ORDER BY ABS(m1_pct - LAG(m1_pct) OVER (ORDER BY signup_month)) DESC NULLS LAST
LIMIT 10;

/* Q94. This is a plan-inspection exercise for the heaviest funnel query. */
EXPLAIN (ANALYZE, BUFFERS)
SELECT device_type, DATE_TRUNC('month', view_timestamp)::date AS month,
  COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%checkout%') AS checkout
FROM web_events.page_views
GROUP BY device_type, DATE_TRUNC('month', view_timestamp);

/* Q95. A monthly-per-device funnel result and the monthly cohort retention grid are both read far more often than the underlying page_views/orders tables change intra-day, making both strong Day-25 materialized-view candidates with a nightly refresh. */

/* Q96. */
SELECT
  (SELECT COUNT(DISTINCT customer_id) FROM web_events.page_views WHERE page_url LIKE '%checkout%') AS funnel_ordered_customers,
  (SELECT COUNT(DISTINCT cust_id) FROM sales.orders) AS orders_distinct_customers;

/* Q97. Reconciling PoP MoM revenue against a Day-25 mv_daily_revenue materialized view is not testable here since no such MV exists yet on this database - the reconciliation pattern is identical to Q99 in the easy file (comparing SUM(net_total) computed two different ways and asserting they match). */

/* Q98. */
WITH cohort_size AS (
  SELECT DATE_TRUNC('month', registration_date)::date AS signup_month, COUNT(DISTINCT customer_id) AS cohort_size
  FROM customers.customers GROUP BY DATE_TRUNC('month', registration_date)
)
SELECT SUM(cohort_size) AS deduped_cohort_total, (SELECT COUNT(*) FROM customers.customers) AS raw_customer_count
FROM cohort_size;

/* Q99. */
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
)
SELECT
  (SELECT jsonb_agg(jsonb_build_object('signup_month', cs.signup_month,
       'm1_pct', ROUND(100.0*COALESCE(a.active_ct,0)/cs.cohort_size,2)))
     FROM cohort_size cs LEFT JOIN active_m1 a ON a.signup_month=cs.signup_month) AS month1_retention_per_cohort,
  (SELECT jsonb_agg(jsonb_build_object('segment', seg, 'n', n)) FROM (
      SELECT CASE WHEN r>=4 AND f>=4 AND m>=4 THEN 'Champions' WHEN r<=2 AND f>=3 THEN 'At Risk' ELSE 'Other' END AS seg,
             COUNT(*) AS n
      FROM scored GROUP BY seg) y) AS rfm_segment_counts,
  (SELECT ROUND(100.0*(product-checkout)/NULLIF(product,0),2) FROM funnel) AS funnel_dropoff_pct;

/* Q100. */
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
cohort AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month FROM customers.customers
),
period_rev AS (
  SELECT co.signup_month,
    (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
     + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)))::int AS period_index,
    SUM(o.net_total) AS revenue
  FROM cohort co JOIN sales.orders o ON o.cust_id = co.customer_id
  WHERE (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
       + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month))) <= 11
  GROUP BY co.signup_month, period_index
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
     FROM cohort_size cs LEFT JOIN active_m1 a ON a.signup_month=cs.signup_month) AS retention_triangle_m1,
  (SELECT jsonb_agg(jsonb_build_object('signup_month', signup_month, 'period', period_index, 'revenue', revenue)) FROM period_rev) AS cohort_ltv_curve,
  (SELECT jsonb_agg(jsonb_build_object('segment', seg, 'n', n)) FROM (
      SELECT CASE WHEN r>=4 AND f>=4 AND m>=4 THEN 'Champions' WHEN r<=2 AND f>=3 THEN 'At Risk' ELSE 'Other' END AS seg,
             COUNT(*) AS n FROM scored GROUP BY seg) y) AS rfm_segments,
  (SELECT jsonb_agg(jsonb_build_object('region_id', region_id, 'month', month, 'revenue', revenue, 'mom_pct', mom_pct))
     FROM monthly_rev_mom) AS revenue_by_region;
