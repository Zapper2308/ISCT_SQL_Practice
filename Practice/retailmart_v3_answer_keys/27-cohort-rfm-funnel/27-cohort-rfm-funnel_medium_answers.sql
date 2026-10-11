/* ============================================================
   ANSWER KEY - Cohort, RFM & Funnel Queries (MEDIUM LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* Q1.  registration_date anchors every customer to a cohort even if they never buy (good for activation analysis); first_order_date only anchors buyers, so silent browsers never appear - the choice changes what "Month 0" means. */
/* Q2.  Monthly cohorts smooth out day-to-day noise and are easy to read; weekly cohorts react faster to changes but each cohort is smaller, so retention percentages get noisier. */
/* Q3.  Without a spine, a (cohort, period) combination with zero active customers simply never appears as a row, silently making a pivot or chart look like data is missing instead of showing a true 0%. */
/* Q4.  A cohort that signed up this month cannot yet have a "6 months later" row, so every cell above the diagonal (period > months elapsed since signup) is structurally empty, forming a triangle. */
/* Q5.  The denominator is fixed at the cohort's size on day one (period 0) for every period after, so retention % always answers "what fraction of the ORIGINAL group is still active" - a rolling denominator would hide real decay. */
/* Q6.  A retention cohort's denominator is "customers in the cohort"; a revenue cohort's denominator is often "total possible revenue" or is left as an absolute number - mixing the two definitions makes cohorts incomparable. */
/* Q7.  Cumulative LTV (a running SUM by period) shows total value banked so far; per-period LTV shows revenue generated in just that one period - cumulative is for "value to date", per-period is for "is engagement fading". */
/* Q8.  Recency must be ordered so the smallest day-count gets the highest NTILE score - ordering ascending by days would incorrectly give the least-recent customers a 5. */
/* Q9.  Postgres's NTILE distributes tied rows arbitrarily among adjacent buckets to keep bucket sizes equal, so two customers with the identical metric value can still land in different R/F/M buckets. */
/* Q10. Champions (best on all three), Loyal (high F, decent R), At-Risk (used to be good, gone quiet), Hibernating (low on everything), and similar labels turn a 3-digit score into an actionable marketing category. */
/* Q11. Segment drift is tracked by scoring the same customers at two points in time (e.g. end of Q1 and end of Q2) and comparing which segment each customer fell into at each point. */
/* Q12. Customer-level funnels answer "did this person ever reach step N" (good for lifetime behavior); session-level funnels answer "did this visit reach step N" (good for UX/conversion-rate analysis of a single browsing session). */
/* Q13. Drop-off ratio (lost/prior-step-count) is clearer for comparing steps of very different absolute size than the raw count lost, since a 50% drop from 100 users reads the same severity as a 50% drop from 100,000. */
/* Q14. Splitting a funnel by device/channel/region (a pivot) reveals that one channel might convert far worse than the blended average, a signal a single overall funnel would hide. */
/* Q15. A percentile of CLV per segment (e.g. median or P90) is more robust than a plain average, since a handful of very large orders can otherwise drag the segment's mean far above what a typical member actually spent. */
/* Q16. DISTINCT ON (cust_id) ORDER BY cust_id, order_date DESC returns exactly one row per customer - their latest order - which is precisely the raw value Recency needs. */
/* Q17. A date spine of months (or weeks) joined against actual signup/activity data guarantees every cohort has a row for every period, even periods before the business existed or after data ends, keeping cross-cohort comparisons aligned. */
/* Q18. Cohort tables that are queried repeatedly by a dashboard (rather than recomputed ad hoc) are prime materialized-view candidates on Day 25, since the underlying orders table changes far less often than the table is read. */
/* Q19. If customers.customers has duplicate rows for the same person (bad email variants), cohort sizes are inflated - deduping first (Day 26) is a prerequisite for a trustworthy cohort denominator. */
/* Q20. SELECT SUM(cohort_size) FROM (per-signup-month counts) should equal SELECT COUNT(*) FROM customers.customers - if not, some registration_date values fell outside the grouping logic. */
/* Q21. An RFM segment x tier matrix lets marketing see, for example, whether "Gold" tier customers are mostly Champions or mostly At-Risk, connecting the loyalty program's own labels to actual current behavior. */
/* Q22. A spine of the expected steps (view, cart, checkout, order) joined against actual event data ensures a step with zero reaches still shows up as 0 in the funnel instead of silently disappearing from the result. */
/* Q23. CLV can be defined on gross_total (before discounts/returns) or net_total (after); and can include only Delivered orders or every order regardless of status - each choice changes the number meaningfully, so it must be stated explicitly. */
/* Q24. Dividing by a denominator that can be zero (a month with no prior-period revenue) throws a division-by-zero error unless the denominator is wrapped in NULLIF(denominator, 0), which returns NULL instead of erroring. */
/* Q25. A single Month-1-retention-per-cohort line (Day 23) turns a whole 2D triangle into one easy-to-scan trend, answering "are newer cohorts sticking better or worse than older ones" at a glance. */

/* Q26. */
SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month
FROM customers.customers;

/* Q27. */
SELECT o.order_id, o.cust_id,
       DATE_TRUNC('month', o.order_date)::date AS order_month,
       (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), DATE_TRUNC('month', c.registration_date))) * 12
        + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), DATE_TRUNC('month', c.registration_date))))::int AS period_index
FROM sales.orders o
JOIN customers.customers c ON c.customer_id = o.cust_id;

/* Q28. */
SELECT DATE_TRUNC('month', registration_date)::date AS signup_month, COUNT(DISTINCT customer_id) AS cohort_size
FROM customers.customers
GROUP BY DATE_TRUNC('month', registration_date)
ORDER BY signup_month;

/* Q29. */
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
FROM activity GROUP BY signup_month, period_index
ORDER BY signup_month, period_index;

/* Q30. */
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
  FROM activity GROUP BY signup_month, period_index
)
SELECT g.signup_month, g.period_index, ROUND(100.0 * g.active_customers / cs.cohort_size, 2) AS retention_pct
FROM grid g JOIN cohort_size cs ON cs.signup_month = g.signup_month
ORDER BY g.signup_month, g.period_index;

/* Q31. */
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
  FROM activity WHERE period_index BETWEEN 0 AND 11
  GROUP BY signup_month, period_index
)
SELECT g.signup_month,
  MAX(ROUND(100.0*g.active_customers/cs.cohort_size,2)) FILTER (WHERE g.period_index=0) AS m0,
  MAX(ROUND(100.0*g.active_customers/cs.cohort_size,2)) FILTER (WHERE g.period_index=1) AS m1,
  MAX(ROUND(100.0*g.active_customers/cs.cohort_size,2)) FILTER (WHERE g.period_index=2) AS m2,
  MAX(ROUND(100.0*g.active_customers/cs.cohort_size,2)) FILTER (WHERE g.period_index=3) AS m3,
  MAX(ROUND(100.0*g.active_customers/cs.cohort_size,2)) FILTER (WHERE g.period_index=6) AS m6,
  MAX(ROUND(100.0*g.active_customers/cs.cohort_size,2)) FILTER (WHERE g.period_index=12) AS m12
FROM grid g JOIN cohort_size cs ON cs.signup_month = g.signup_month
GROUP BY g.signup_month ORDER BY g.signup_month;

/* Q32. */
WITH spine AS (
  SELECT DISTINCT DATE_TRUNC('month', registration_date)::date AS signup_month FROM customers.customers
),
periods AS (SELECT generate_series(0,11) AS period_index),
full_grid AS (SELECT s.signup_month, p.period_index FROM spine s CROSS JOIN periods p),
cohort_size AS (
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
  FROM activity GROUP BY signup_month, period_index
)
SELECT fg.signup_month, fg.period_index, COALESCE(g.active_customers,0) AS active_customers,
       ROUND(100.0 * COALESCE(g.active_customers,0) / cs.cohort_size, 2) AS retention_pct
FROM full_grid fg
JOIN cohort_size cs ON cs.signup_month = fg.signup_month
LEFT JOIN grid g ON g.signup_month = fg.signup_month AND g.period_index = fg.period_index
ORDER BY fg.signup_month, fg.period_index;

/* Q33. */
WITH cohort AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month FROM customers.customers
)
SELECT co.signup_month,
    (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
     + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)))::int AS period_index,
    SUM(o.net_total) AS cohort_revenue
FROM cohort co JOIN sales.orders o ON o.cust_id = co.customer_id
GROUP BY co.signup_month, period_index
ORDER BY co.signup_month, period_index;

/* Q34. */
WITH cohort AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month FROM customers.customers
),
period_rev AS (
  SELECT co.signup_month,
    (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
     + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)))::int AS period_index,
    SUM(o.net_total) AS revenue
  FROM cohort co JOIN sales.orders o ON o.cust_id = co.customer_id
  GROUP BY co.signup_month, period_index
)
SELECT signup_month, period_index, revenue,
       SUM(revenue) OVER (PARTITION BY signup_month ORDER BY period_index) AS cumulative_revenue
FROM period_rev ORDER BY signup_month, period_index;

/* Q35. */
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
SELECT signup_month, period_index, ROUND(AVG(cust_revenue),2) AS avg_revenue_per_active_customer
FROM period_data GROUP BY signup_month, period_index
ORDER BY signup_month, period_index;

/* Q36. */
WITH cohort_size AS (
  SELECT DATE_TRUNC('month', registration_date)::date AS signup_month, COUNT(DISTINCT customer_id) AS cohort_size
  FROM customers.customers GROUP BY DATE_TRUNC('month', registration_date)
),
cohort AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month FROM customers.customers
),
cum_rev AS (
  SELECT co.signup_month,
    (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
     + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)))::int AS period_index,
    SUM(o.net_total) AS revenue
  FROM cohort co JOIN sales.orders o ON o.cust_id = co.customer_id
  GROUP BY co.signup_month, period_index
),
running AS (
  SELECT signup_month, period_index, SUM(revenue) OVER (PARTITION BY signup_month ORDER BY period_index) AS cum_revenue
  FROM cum_rev
)
SELECT r.signup_month, r.period_index, r.cum_revenue, cs.cohort_size,
       ROUND(r.cum_revenue / cs.cohort_size, 2) AS ltv_per_cohort_customer
FROM running r JOIN cohort_size cs ON cs.signup_month = r.signup_month
ORDER BY r.signup_month, r.period_index;

/* Q37. */
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
FROM cohort_size cs LEFT JOIN active_m3 a ON a.signup_month = cs.signup_month
ORDER BY month3_retention_pct DESC NULLS LAST
LIMIT 5;

/* Q38. */
WITH cohort_size AS (
  SELECT DATE_TRUNC('month', registration_date)::date AS signup_month, COUNT(DISTINCT customer_id) AS cohort_size
  FROM customers.customers GROUP BY DATE_TRUNC('month', registration_date)
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
       + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month))) <= 12
  GROUP BY co.signup_month, period_index
),
ltv12 AS (
  SELECT signup_month, SUM(revenue) AS ltv_12mo FROM period_rev GROUP BY signup_month
)
SELECT l.signup_month, l.ltv_12mo, cs.cohort_size, ROUND(l.ltv_12mo/cs.cohort_size,2) AS ltv_per_customer
FROM ltv12 l JOIN cohort_size cs ON cs.signup_month = l.signup_month
ORDER BY ltv_per_customer DESC
LIMIT 5;

/* Q39. */
WITH cohort_size AS (
  SELECT r.region_name, DATE_TRUNC('month', c.registration_date)::date AS signup_month, COUNT(DISTINCT c.customer_id) AS cohort_size
  FROM customers.customers c
  JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = true
  JOIN core.dim_region r ON r.state = a.state
  GROUP BY r.region_name, DATE_TRUNC('month', c.registration_date)
),
cohort AS (
  SELECT c.customer_id, DATE_TRUNC('month', c.registration_date)::date AS signup_month, r.region_name
  FROM customers.customers c
  JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = true
  JOIN core.dim_region r ON r.state = a.state
),
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
WITH cohort_size AS (
  SELECT tier, DATE_TRUNC('month', registration_date)::date AS signup_month, COUNT(DISTINCT customer_id) AS cohort_size
  FROM customers.customers GROUP BY tier, DATE_TRUNC('month', registration_date)
),
active_m1 AS (
  SELECT c.tier, DATE_TRUNC('month', c.registration_date)::date AS signup_month, COUNT(DISTINCT c.customer_id) AS active_ct
  FROM customers.customers c JOIN sales.orders o ON o.cust_id = c.customer_id
  WHERE (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), DATE_TRUNC('month', c.registration_date))) * 12
       + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), DATE_TRUNC('month', c.registration_date)))) = 1
  GROUP BY c.tier, DATE_TRUNC('month', c.registration_date)
)
SELECT cs.tier, cs.signup_month, ROUND(100.0*COALESCE(a.active_ct,0)/cs.cohort_size,2) AS month1_retention_pct
FROM cohort_size cs LEFT JOIN active_m1 a ON a.tier=cs.tier AND a.signup_month=cs.signup_month
ORDER BY cs.tier, cs.signup_month;

/* Q41. RetailMart has no signup-channel column on customers.customers, so a real channel-proxy split is not possible with this schema - the closest available proxy is customer tier at signup, already covered by Q40. */

/* Q42. */
WITH clv AS (
  SELECT o.cust_id, SUM(o.net_total) AS clv FROM sales.orders o WHERE o.order_status='Delivered' GROUP BY o.cust_id
)
SELECT r.region_name, ROUND(AVG(clv.clv),2) AS avg_clv
FROM clv
JOIN customers.addresses a ON a.customer_id = clv.cust_id AND a.is_default = true
JOIN core.dim_region r ON r.state = a.state
GROUP BY r.region_name ORDER BY r.region_name;

/* Q43. */
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
SELECT signup_month, period_index, ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY cust_revenue)::numeric,2) AS median_spend
FROM period_data GROUP BY signup_month, period_index
ORDER BY signup_month, period_index;

/* Q44. */
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
SELECT signup_month, period_index, ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY cust_revenue)::numeric,2) AS p95_spend
FROM period_data GROUP BY signup_month, period_index
ORDER BY signup_month, period_index;

/* Q45. */
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
  FROM activity WHERE period_index BETWEEN 0 AND 11
  GROUP BY signup_month, period_index
)
SELECT g.signup_month,
  MAX(ROUND(100.0*g.active_customers/cs.cohort_size,2)) FILTER (WHERE g.period_index=0) AS p0,
  MAX(ROUND(100.0*g.active_customers/cs.cohort_size,2)) FILTER (WHERE g.period_index=1) AS p1,
  MAX(ROUND(100.0*g.active_customers/cs.cohort_size,2)) FILTER (WHERE g.period_index=2) AS p2,
  MAX(ROUND(100.0*g.active_customers/cs.cohort_size,2)) FILTER (WHERE g.period_index=3) AS p3,
  MAX(ROUND(100.0*g.active_customers/cs.cohort_size,2)) FILTER (WHERE g.period_index=6) AS p6,
  MAX(ROUND(100.0*g.active_customers/cs.cohort_size,2)) FILTER (WHERE g.period_index=9) AS p9,
  MAX(ROUND(100.0*g.active_customers/cs.cohort_size,2)) FILTER (WHERE g.period_index=11) AS p11
FROM grid g JOIN cohort_size cs ON cs.signup_month=g.signup_month
GROUP BY g.signup_month ORDER BY g.signup_month;

/* Q46. */
WITH cohort_size AS (
  SELECT DATE_TRUNC('month', registration_date)::date AS signup_month, COUNT(DISTINCT customer_id) AS cohort_size
  FROM customers.customers GROUP BY DATE_TRUNC('month', registration_date)
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
       + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month))) BETWEEN 0 AND 11
  GROUP BY co.signup_month, period_index
),
running AS (
  SELECT signup_month, period_index, SUM(revenue) OVER (PARTITION BY signup_month ORDER BY period_index) AS cum_revenue
  FROM period_rev
)
SELECT r.signup_month,
  MAX(r.cum_revenue) FILTER (WHERE r.period_index=0) AS p0,
  MAX(r.cum_revenue) FILTER (WHERE r.period_index=3) AS p3,
  MAX(r.cum_revenue) FILTER (WHERE r.period_index=6) AS p6,
  MAX(r.cum_revenue) FILTER (WHERE r.period_index=11) AS p11
FROM running r GROUP BY r.signup_month ORDER BY r.signup_month;

/* Q47. */
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
FROM cohort_size cs LEFT JOIN active_m1 a ON a.signup_month = cs.signup_month
WHERE EXTRACT(YEAR FROM cs.signup_month) IN (2024,2025)
GROUP BY signup_year ORDER BY signup_year;

/* Q48. */
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
ltv AS (
  SELECT signup_month, SUM(revenue) AS ltv_12mo FROM period_rev GROUP BY signup_month
)
SELECT EXTRACT(YEAR FROM signup_month)::int AS signup_year, ROUND(AVG(ltv_12mo),2) AS avg_12mo_ltv
FROM ltv WHERE EXTRACT(YEAR FROM signup_month) IN (2024,2025)
GROUP BY signup_year ORDER BY signup_year;

/* Q49. */
SELECT
  (SELECT SUM(cohort_size) FROM (SELECT COUNT(DISTINCT customer_id) AS cohort_size FROM customers.customers
    GROUP BY DATE_TRUNC('month', registration_date)) x) AS sum_of_cohort_sizes,
  (SELECT COUNT(*) FROM customers.customers) AS total_customers;

/* Q50. */
WITH cohort_size AS (
  SELECT DATE_TRUNC('month', registration_date)::date AS signup_month, COUNT(DISTINCT customer_id) AS cohort_size
  FROM customers.customers GROUP BY DATE_TRUNC('month', registration_date)
),
cohort AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month FROM customers.customers
),
period_data AS (
  SELECT co.signup_month,
    (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
     + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)))::int AS period_index,
    COUNT(DISTINCT o.cust_id) AS active_customers, SUM(o.net_total) AS revenue
  FROM cohort co JOIN sales.orders o ON o.cust_id = co.customer_id
  GROUP BY co.signup_month, period_index
)
SELECT pd.signup_month, pd.period_index, pd.active_customers, cs.cohort_size,
       ROUND(100.0*pd.active_customers/cs.cohort_size,2) AS retention_pct,
       pd.revenue, SUM(pd.revenue) OVER (PARTITION BY pd.signup_month ORDER BY pd.period_index) AS cumulative_ltv
FROM period_data pd JOIN cohort_size cs ON cs.signup_month = pd.signup_month
ORDER BY pd.signup_month, pd.period_index;

/* Q51. */
SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order
FROM sales.orders GROUP BY cust_id;

/* Q52. */
SELECT cust_id, COUNT(*) AS frequency FROM sales.orders GROUP BY cust_id;

/* Q53. */
SELECT cust_id, SUM(net_total) AS monetary FROM sales.orders GROUP BY cust_id;

/* Q54. */
WITH recency AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order
  FROM sales.orders GROUP BY cust_id
)
SELECT cust_id, NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r_score FROM recency;

/* Q55. */
WITH frequency AS (SELECT cust_id, COUNT(*) AS order_count FROM sales.orders GROUP BY cust_id)
SELECT cust_id, NTILE(5) OVER (ORDER BY order_count) AS f_score FROM frequency;

/* Q56. */
WITH monetary AS (SELECT cust_id, SUM(net_total) AS lifetime_revenue FROM sales.orders GROUP BY cust_id)
SELECT cust_id, NTILE(5) OVER (ORDER BY lifetime_revenue) AS m_score FROM monetary;

/* Q57. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
)
SELECT cust_id, r, f, m, (r::text||f::text||m::text) AS rfm_string, (r+f+m) AS rfm_total
FROM scored;

/* Q58. Named RFM segments (Champions, Loyal Customers, Potential Loyalists, New Customers, Promising, Need Attention, About to Sleep, At Risk, Hibernating, Lost) each map to a range of R/F/M score combinations - the mapping used here is implemented as the CASE expression in Q59. */

/* Q59. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
)
SELECT cust_id, r, f, m,
  CASE
    WHEN r >= 4 AND f >= 4 AND m >= 4 THEN 'Champions'
    WHEN r >= 3 AND f >= 4 THEN 'Loyal Customers'
    WHEN r >= 4 AND f BETWEEN 2 AND 3 THEN 'Potential Loyalists'
    WHEN r = 5 AND f = 1 THEN 'New Customers'
    WHEN r >= 3 AND f <= 2 AND m <= 2 THEN 'Promising'
    WHEN r = 3 AND f = 3 THEN 'Need Attention'
    WHEN r = 2 AND f <= 2 THEN 'About to Sleep'
    WHEN r <= 2 AND f >= 3 THEN 'At Risk'
    WHEN r <= 2 AND f <= 2 AND m <= 2 AND r > 1 THEN 'Hibernating'
    WHEN r = 1 AND f = 1 AND m = 1 THEN 'Lost'
    ELSE 'Other'
  END AS segment
FROM scored;

/* Q60. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
),
segmented AS (
  SELECT cust_id,
  CASE
    WHEN r >= 4 AND f >= 4 AND m >= 4 THEN 'Champions'
    WHEN r >= 3 AND f >= 4 THEN 'Loyal Customers'
    WHEN r >= 4 AND f BETWEEN 2 AND 3 THEN 'Potential Loyalists'
    WHEN r = 5 AND f = 1 THEN 'New Customers'
    WHEN r >= 3 AND f <= 2 AND m <= 2 THEN 'Promising'
    WHEN r = 3 AND f = 3 THEN 'Need Attention'
    WHEN r = 2 AND f <= 2 THEN 'About to Sleep'
    WHEN r <= 2 AND f >= 3 THEN 'At Risk'
    WHEN r <= 2 AND f <= 2 AND m <= 2 AND r > 1 THEN 'Hibernating'
    WHEN r = 1 AND f = 1 AND m = 1 THEN 'Lost'
    ELSE 'Other'
  END AS segment
  FROM scored
)
SELECT segment, COUNT(*) AS customer_ct FROM segmented GROUP BY segment ORDER BY customer_ct DESC;

/* Q61. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id, lifetime_revenue,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
),
segmented AS (
  SELECT cust_id, lifetime_revenue,
  CASE
    WHEN r >= 4 AND f >= 4 AND m >= 4 THEN 'Champions'
    WHEN r >= 3 AND f >= 4 THEN 'Loyal Customers'
    WHEN r >= 4 AND f BETWEEN 2 AND 3 THEN 'Potential Loyalists'
    WHEN r = 5 AND f = 1 THEN 'New Customers'
    WHEN r >= 3 AND f <= 2 AND m <= 2 THEN 'Promising'
    WHEN r = 3 AND f = 3 THEN 'Need Attention'
    WHEN r = 2 AND f <= 2 THEN 'About to Sleep'
    WHEN r <= 2 AND f >= 3 THEN 'At Risk'
    WHEN r <= 2 AND f <= 2 AND m <= 2 AND r > 1 THEN 'Hibernating'
    WHEN r = 1 AND f = 1 AND m = 1 THEN 'Lost'
    ELSE 'Other'
  END AS segment
  FROM scored
)
SELECT segment, ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY lifetime_revenue)::numeric,2) AS median_clv
FROM segmented GROUP BY segment ORDER BY median_clv DESC;

/* Q62. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id, lifetime_revenue,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
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
SELECT segment, ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY lifetime_revenue)::numeric,2) AS p95_clv
FROM segmented GROUP BY segment ORDER BY p95_clv DESC;

/* Q63. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
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
GROUP BY reg.region_name, s.segment
ORDER BY reg.region_name, s.segment;

/* Q64. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
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
SELECT c.tier, s.segment, COUNT(*) AS n
FROM segmented s JOIN customers.customers c ON c.customer_id = s.cust_id
GROUP BY c.tier, s.segment ORDER BY c.tier, s.segment;

/* Q65. Comparing a customer's segment "this quarter" to "last quarter" requires point-in-time RFM scoring (recomputing R/F/M using only orders up to each quarter-end cutoff) - the full runnable version of this drift query is in the hard file's Q60/Q61 (transition matrix + movers report). */

/* Q66. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id, lifetime_revenue,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
)
SELECT cust_id, lifetime_revenue FROM scored WHERE r <= 2 AND m >= 4;

/* Q67. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id, order_count,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
)
SELECT cust_id, order_count FROM scored WHERE r <= 2 AND f <= 2 AND order_count > 5;

/* Q68. */
SELECT DATE_TRUNC('month', registration_date)::date AS reg_month, COUNT(*) AS new_customers
FROM customers.customers
GROUP BY DATE_TRUNC('month', registration_date)
ORDER BY reg_month;

/* Q69. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id, days_since_last_order,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
),
segmented AS (
  SELECT days_since_last_order,
  CASE WHEN r>=4 AND f>=4 AND m>=4 THEN 'Champions' WHEN r>=3 AND f>=4 THEN 'Loyal Customers'
       WHEN r>=4 AND f BETWEEN 2 AND 3 THEN 'Potential Loyalists' WHEN r=5 AND f=1 THEN 'New Customers'
       WHEN r>=3 AND f<=2 AND m<=2 THEN 'Promising' WHEN r=3 AND f=3 THEN 'Need Attention'
       WHEN r=2 AND f<=2 THEN 'About to Sleep' WHEN r<=2 AND f>=3 THEN 'At Risk'
       WHEN r<=2 AND f<=2 AND m<=2 AND r>1 THEN 'Hibernating' WHEN r=1 AND f=1 AND m=1 THEN 'Lost'
       ELSE 'Other' END AS segment
  FROM scored
)
SELECT segment, ROUND(AVG(days_since_last_order),2) AS avg_days_since_last_order
FROM segmented GROUP BY segment ORDER BY avg_days_since_last_order;

/* Q70. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id, order_count,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
),
segmented AS (
  SELECT order_count,
  CASE WHEN r>=4 AND f>=4 AND m>=4 THEN 'Champions' WHEN r>=3 AND f>=4 THEN 'Loyal Customers'
       WHEN r>=4 AND f BETWEEN 2 AND 3 THEN 'Potential Loyalists' WHEN r=5 AND f=1 THEN 'New Customers'
       WHEN r>=3 AND f<=2 AND m<=2 THEN 'Promising' WHEN r=3 AND f=3 THEN 'Need Attention'
       WHEN r=2 AND f<=2 THEN 'About to Sleep' WHEN r<=2 AND f>=3 THEN 'At Risk'
       WHEN r<=2 AND f<=2 AND m<=2 AND r>1 THEN 'Hibernating' WHEN r=1 AND f=1 AND m=1 THEN 'Lost'
       ELSE 'Other' END AS segment
  FROM scored
)
SELECT segment, ROUND(AVG(order_count),2) AS avg_orders
FROM segmented GROUP BY segment ORDER BY avg_orders DESC;

/* Q71. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id, lifetime_revenue,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
),
segmented AS (
  SELECT lifetime_revenue,
  CASE WHEN r>=4 AND f>=4 AND m>=4 THEN 'Champions' WHEN r>=3 AND f>=4 THEN 'Loyal Customers'
       WHEN r>=4 AND f BETWEEN 2 AND 3 THEN 'Potential Loyalists' WHEN r=5 AND f=1 THEN 'New Customers'
       WHEN r>=3 AND f<=2 AND m<=2 THEN 'Promising' WHEN r=3 AND f=3 THEN 'Need Attention'
       WHEN r=2 AND f<=2 THEN 'About to Sleep' WHEN r<=2 AND f>=3 THEN 'At Risk'
       WHEN r<=2 AND f<=2 AND m<=2 AND r>1 THEN 'Hibernating' WHEN r=1 AND f=1 AND m=1 THEN 'Lost'
       ELSE 'Other' END AS segment
  FROM scored
)
SELECT segment, ROUND(AVG(lifetime_revenue),2) AS avg_lifetime_revenue
FROM segmented GROUP BY segment ORDER BY avg_lifetime_revenue DESC;

/* Q72. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
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
SELECT reg.region_name,
  COUNT(*) FILTER (WHERE s.segment = 'Champions') AS champions,
  COUNT(*) FILTER (WHERE s.segment = 'Loyal Customers') AS loyal,
  COUNT(*) FILTER (WHERE s.segment = 'At Risk') AS at_risk,
  COUNT(*) FILTER (WHERE s.segment = 'Hibernating') AS hibernating,
  COUNT(*) FILTER (WHERE s.segment = 'Lost') AS lost
FROM segmented s
JOIN customers.addresses a ON a.customer_id = s.cust_id AND a.is_default = true
JOIN core.dim_region reg ON reg.state = a.state
GROUP BY reg.region_name ORDER BY reg.region_name;

/* Q73. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
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
SELECT c.tier,
  COUNT(*) FILTER (WHERE s.segment = 'Champions') AS champions,
  COUNT(*) FILTER (WHERE s.segment = 'At Risk') AS at_risk,
  COUNT(*) FILTER (WHERE s.segment = 'Lost') AS lost
FROM segmented s JOIN customers.customers c ON c.customer_id = s.cust_id
GROUP BY c.tier ORDER BY c.tier;

/* Q74. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id, lifetime_revenue,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
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
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY segment ORDER BY lifetime_revenue DESC) AS rk
  FROM segmented
)
SELECT segment, cust_id, lifetime_revenue FROM ranked WHERE rk <= 5
ORDER BY segment, rk;

/* Q75. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
)
SELECT COUNT(*) AS scored_customers, (SELECT COUNT(DISTINCT cust_id) FROM sales.orders) AS customers_with_orders
FROM scored;

/* Q76. */
SELECT
  COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%product%') AS product,
  COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%cart%') AS cart,
  COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%checkout%') AS checkout
FROM web_events.page_views;

/* Q77. */
WITH steps AS (
  SELECT
    COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%product%') AS product,
    COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%cart%') AS cart,
    COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%checkout%') AS checkout
  FROM web_events.page_views
),
ordered AS (
  SELECT (SELECT COUNT(DISTINCT cust_id) FROM sales.orders) AS ordered
)
SELECT s.product, s.cart, s.checkout, o.ordered FROM steps s, ordered o;

/* Q78. */
WITH steps AS (
  SELECT
    COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%product%') AS product,
    COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%cart%') AS cart,
    COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%checkout%') AS checkout
  FROM web_events.page_views
)
SELECT product, cart, checkout,
  ROUND(100.0*(product-cart)/NULLIF(product,0),2) AS pct_lost_product_to_cart,
  ROUND(100.0*(cart-checkout)/NULLIF(cart,0),2) AS pct_lost_cart_to_checkout
FROM steps;

/* Q79. */
SELECT session_id,
  MAX(CASE WHEN page_url LIKE '%product%' THEN 1 ELSE 0 END) AS reached_product,
  MAX(CASE WHEN page_url LIKE '%cart%' THEN 1 ELSE 0 END) AS reached_cart,
  MAX(CASE WHEN page_url LIKE '%checkout%' THEN 1 ELSE 0 END) AS reached_checkout
FROM web_events.page_views
GROUP BY session_id;

/* Q80. */
SELECT device_type,
  COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%product%') AS product,
  COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%cart%') AS cart,
  COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%checkout%') AS checkout
FROM web_events.page_views
GROUP BY device_type ORDER BY device_type;

/* Q81. */
SELECT DATE_TRUNC('month', view_timestamp)::date AS month,
  COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%product%') AS product,
  COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%cart%') AS cart,
  COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%checkout%') AS checkout
FROM web_events.page_views
GROUP BY DATE_TRUNC('month', view_timestamp) ORDER BY month;

/* Q82. */
SELECT r.region_name,
  COUNT(DISTINCT p.customer_id) FILTER (WHERE p.page_url LIKE '%product%') AS product,
  COUNT(DISTINCT p.customer_id) FILTER (WHERE p.page_url LIKE '%cart%') AS cart,
  COUNT(DISTINCT p.customer_id) FILTER (WHERE p.page_url LIKE '%checkout%') AS checkout
FROM web_events.page_views p
JOIN customers.addresses a ON a.customer_id = p.customer_id AND a.is_default = true
JOIN core.dim_region r ON r.state = a.state
GROUP BY r.region_name ORDER BY r.region_name;

/* Q83. */
SELECT DATE_TRUNC('month', c.registration_date)::date AS signup_month,
  COUNT(DISTINCT p.customer_id) FILTER (WHERE p.page_url LIKE '%product%') AS product,
  COUNT(DISTINCT p.customer_id) FILTER (WHERE p.page_url LIKE '%cart%') AS cart,
  COUNT(DISTINCT p.customer_id) FILTER (WHERE p.page_url LIKE '%checkout%') AS checkout
FROM web_events.page_views p
JOIN customers.customers c ON c.customer_id = p.customer_id
GROUP BY signup_month ORDER BY signup_month;

/* Q84. */
WITH steps AS (
  SELECT customer_id,
    MIN(view_timestamp) FILTER (WHERE page_url LIKE '%product%') AS t_product,
    MIN(view_timestamp) FILTER (WHERE page_url LIKE '%cart%') AS t_cart,
    MIN(view_timestamp) FILTER (WHERE page_url LIKE '%checkout%') AS t_checkout
  FROM web_events.page_views GROUP BY customer_id
)
SELECT ROUND(EXTRACT(EPOCH FROM PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY t_cart - t_product))/60.0,2) AS median_minutes_product_to_cart,
       ROUND(EXTRACT(EPOCH FROM PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY t_checkout - t_cart))/60.0,2) AS median_minutes_cart_to_checkout
FROM steps
WHERE t_cart > t_product AND t_checkout > t_cart;

/* Q85. */
WITH funnel AS (
  SELECT device_type, DATE_TRUNC('month', view_timestamp) AS month,
    COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%checkout%') AS checkout,
    COUNT(DISTINCT customer_id) AS visitors
  FROM web_events.page_views GROUP BY device_type, DATE_TRUNC('month', view_timestamp)
)
SELECT device_type, month, ROUND(100.0*checkout/NULLIF(visitors,0),2) AS conversion_rate_pct
FROM funnel ORDER BY device_type, month;

/* Q86. */
WITH cohort AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month FROM customers.customers
),
clv AS (
  SELECT cust_id, SUM(net_total) AS clv FROM sales.orders WHERE order_status='Delivered' GROUP BY cust_id
)
SELECT co.signup_month, ROUND(AVG(clv.clv),2) AS avg_clv
FROM cohort co JOIN clv ON clv.cust_id = co.customer_id
GROUP BY co.signup_month ORDER BY co.signup_month;

/* Q87. */
WITH monthly AS (
  SELECT r.region_id, DATE_TRUNC('month', o.order_date) AS month, SUM(o.net_total) AS revenue
  FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id JOIN core.dim_region r ON r.region_id = s.region_id
  GROUP BY r.region_id, DATE_TRUNC('month', o.order_date)
)
SELECT region_id, month, revenue,
  ROUND(100.0*(revenue - LAG(revenue) OVER (PARTITION BY region_id ORDER BY month))
    / NULLIF(LAG(revenue) OVER (PARTITION BY region_id ORDER BY month),0),2) AS mom_growth_pct
FROM monthly ORDER BY region_id, month;

/* Q88. */
WITH monthly AS (
  SELECT r.region_id, DATE_TRUNC('month', o.order_date) AS month, SUM(o.net_total) AS revenue
  FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id JOIN core.dim_region r ON r.region_id = s.region_id
  GROUP BY r.region_id, DATE_TRUNC('month', o.order_date)
)
SELECT region_id, month, revenue,
  ROUND(100.0*(revenue - LAG(revenue,12) OVER (PARTITION BY region_id ORDER BY month))
    / NULLIF(LAG(revenue,12) OVER (PARTITION BY region_id ORDER BY month),0),2) AS yoy_growth_pct
FROM monthly ORDER BY region_id, month;

/* Q89. */
WITH quarterly AS (
  SELECT r.region_id, DATE_TRUNC('quarter', o.order_date) AS quarter, SUM(o.net_total) AS revenue
  FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id JOIN core.dim_region r ON r.region_id = s.region_id
  GROUP BY r.region_id, DATE_TRUNC('quarter', o.order_date)
)
SELECT region_id, quarter, revenue,
  ROUND(100.0*(revenue - LAG(revenue) OVER (PARTITION BY region_id ORDER BY quarter))
    / NULLIF(LAG(revenue) OVER (PARTITION BY region_id ORDER BY quarter),0),2) AS qoq_growth_pct
FROM quarterly ORDER BY region_id, quarter;

/* Q90. */
WITH monthly_active AS (
  SELECT r.region_id, DATE_TRUNC('month', o.order_date) AS month, COUNT(DISTINCT o.cust_id) AS active_customers
  FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id JOIN core.dim_region r ON r.region_id = s.region_id
  GROUP BY r.region_id, DATE_TRUNC('month', o.order_date)
)
SELECT region_id, month, active_customers,
  active_customers - LAG(active_customers) OVER (PARTITION BY region_id ORDER BY month) AS change_vs_prev
FROM monthly_active ORDER BY region_id, month;

/* Q91. */
WITH first_order AS (
  SELECT cust_id, DATE_TRUNC('month', MIN(order_date)) AS first_order_month FROM sales.orders GROUP BY cust_id
),
monthly_new AS (
  SELECT first_order_month, COUNT(*) AS new_customers FROM first_order GROUP BY first_order_month
)
SELECT first_order_month, new_customers,
       new_customers - LAG(new_customers) OVER (ORDER BY first_order_month) AS change_vs_prev
FROM monthly_new ORDER BY first_order_month;

/* Q92. */
WITH first_order AS (
  SELECT cust_id, MIN(order_date) AS first_order_date FROM sales.orders GROUP BY cust_id
),
monthly_orders AS (
  SELECT o.cust_id, DATE_TRUNC('month', o.order_date) AS month,
    (o.order_date = fo.first_order_date) AS is_first_order
  FROM sales.orders o JOIN first_order fo ON fo.cust_id = o.cust_id
)
SELECT month, COUNT(DISTINCT cust_id) FILTER (WHERE is_first_order) AS reactivated_proxy_new
FROM monthly_orders GROUP BY month ORDER BY month;

/* Q93. */
WITH first_order AS (
  SELECT cust_id, DATE_TRUNC('week', MIN(order_date)) AS week FROM sales.orders GROUP BY cust_id
)
SELECT week, COUNT(*) AS new_customers
FROM first_order GROUP BY week ORDER BY week;

/* Q94. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id, lifetime_revenue,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
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
SELECT segment, ROUND(AVG(lifetime_revenue),2) AS avg_clv, COUNT(*) AS n
FROM segmented GROUP BY segment ORDER BY avg_clv DESC;

/* Q95. */
WITH cohort AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month FROM customers.customers
),
clv AS (SELECT cust_id, SUM(net_total) AS clv FROM sales.orders WHERE order_status='Delivered' GROUP BY cust_id)
SELECT co.signup_month, ROUND(AVG(clv.clv),2) AS avg_clv, COUNT(*) AS customers_with_delivered_orders
FROM cohort co JOIN clv ON clv.cust_id = co.customer_id
GROUP BY co.signup_month ORDER BY co.signup_month;

/* Q96. */
WITH rfm_raw AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count, SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
)
SELECT reg.region_name, (s.r::text||s.f::text||s.m::text) AS rfm_string, COUNT(*) AS n
FROM scored s
JOIN customers.addresses a ON a.customer_id = s.cust_id AND a.is_default = true
JOIN core.dim_region reg ON reg.state = a.state
GROUP BY reg.region_name, rfm_string
ORDER BY reg.region_name, rfm_string;

/* Q97. */
WITH steps AS (
  SELECT
    COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%product%') AS product,
    COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%cart%') AS cart,
    COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%checkout%') AS checkout
  FROM web_events.page_views
)
SELECT jsonb_build_object('product', product, 'cart', cart, 'checkout', checkout,
       'drop_product_to_cart_pct', ROUND(100.0*(product-cart)/NULLIF(product,0),2),
       'drop_cart_to_checkout_pct', ROUND(100.0*(cart-checkout)/NULLIF(cart,0),2)) AS funnel_json
FROM steps;

/* Q98. */
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
  FROM activity WHERE period_index BETWEEN 0 AND 6
  GROUP BY signup_month, period_index
)
SELECT jsonb_agg(jsonb_build_object('signup_month', g.signup_month, 'period_index', g.period_index,
       'retention_pct', ROUND(100.0*g.active_customers/cs.cohort_size,2))) AS cohort_triangle_json
FROM grid g JOIN cohort_size cs ON cs.signup_month = g.signup_month;

/* Q99. */
WITH cohort AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month FROM customers.customers
),
cohort_rev AS (
  SELECT SUM(o.net_total) AS total_cohort_revenue
  FROM cohort co JOIN sales.orders o ON o.cust_id = co.customer_id
  WHERE o.order_status = 'Delivered'
)
SELECT (SELECT total_cohort_revenue FROM cohort_rev) AS cohort_revenue_total,
       (SELECT SUM(net_total) FROM sales.orders WHERE order_status='Delivered') AS orders_revenue_total,
       (SELECT total_cohort_revenue FROM cohort_rev) IS NOT DISTINCT FROM
         (SELECT SUM(net_total) FROM sales.orders WHERE order_status='Delivered') AS reconciled;

/* Q100. */
WITH ref AS (SELECT DATE_TRUNC('month', MAX(order_date)) AS this_month FROM sales.orders),
cohort_size AS (
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
  SELECT cs.signup_month, ROUND(100.0*COALESCE(a.active_ct,0)/cs.cohort_size,2) AS m1_retention_pct
  FROM cohort_size cs LEFT JOIN active_m1 a ON a.signup_month = cs.signup_month
),
monthly_rev AS (
  SELECT r.region_id, DATE_TRUNC('month', o.order_date) AS month, SUM(o.net_total) AS revenue
  FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id JOIN core.dim_region r ON r.region_id = s.region_id
  GROUP BY r.region_id, DATE_TRUNC('month', o.order_date)
)
SELECT
  (SELECT jsonb_agg(jsonb_build_object('signup_month', signup_month, 'm1_retention_pct', m1_retention_pct)) FROM retention) AS month1_retention_by_cohort,
  (SELECT ROUND(100.0*(product-cart)/NULLIF(product,0),2) FROM (
     SELECT COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%product%') AS product,
            COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%cart%') AS cart
     FROM web_events.page_views) x) AS funnel_dropoff_product_to_cart_pct,
  (SELECT ROUND(100.0*(revenue - LAG(revenue) OVER (PARTITION BY region_id ORDER BY month))
        / NULLIF(LAG(revenue) OVER (PARTITION BY region_id ORDER BY month),0),2)
     FROM monthly_rev WHERE month = (SELECT this_month FROM ref) ORDER BY region_id LIMIT 1) AS sample_region_mom_revenue_pct;
