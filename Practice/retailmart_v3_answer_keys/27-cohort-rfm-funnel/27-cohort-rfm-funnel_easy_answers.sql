/* ============================================================
   ANSWER KEY - Cohort, RFM & Funnel Queries (EASY LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* Q1.  A cohort is a group of customers grouped together because they share a common starting event, usually the same signup month - each cohort is then tracked over time as a unit. */
/* Q2.  It measures retention: for a cohort that signed up in a given month, what share of them is still active N months later. */
/* Q3.  period_index is the number of months elapsed since a customer's signup month, where 0 means "the signup month itself". */
/* Q4.  Month-1 retention is the percentage of a cohort that was still active (placed an order) exactly one month after they signed up. */
/* Q5.  Future (cohort_month, period) cells simply haven't happened yet (a customer who signed up last month can't have a "6 months later" data point), so the table naturally forms a triangle, not a full rectangle. */
/* Q6.  RFM stands for Recency, Frequency, and Monetary - three dimensions used to score how valuable and engaged a customer is. */
/* Q7.  NTILE(5) divides customers, ordered by a metric, into 5 equally-sized buckets and labels each row with its bucket number 1 through 5. */
/* Q8.  Because a customer who ordered yesterday (few days since last order) is more valuable than one who ordered a year ago, so ordering by "-days" (or DESC) makes the smallest day-count map to score 5. */
/* Q9.  A 555 score means the customer is in the best bucket on all three dimensions - very recent, very frequent, and very high spend: a "Champion". */
/* Q10. A 111 score means the customer is in the worst bucket on all three dimensions - long inactive, rarely ordered, and low spend: effectively "Lost". */
/* Q11. A funnel is a sequence of steps a customer must pass through (view -> cart -> order), with a count of how many distinct customers reached each step. */
/* Q12. Drop-off is the percentage of customers who reached one step but did not reach the next step in the sequence. */
/* Q13. CLV is the total revenue (or profit) a single customer has generated over their entire relationship with the business, summarized as one number per customer. */
/* Q14. MRR-style CLV looks at recurring revenue aggregated across the whole customer base per period; per-customer CLV is the lifetime total attributed to one individual, used for segmentation and targeting. */
/* Q15. MoM compares this month to last month, QoQ compares this quarter to last quarter, and YoY compares this period to the same period a year ago - each measures growth over a different time distance. */
/* Q16. Because it groups customers by signup date and tracks the same group's activity every month after, directly showing whether newer signups keep coming back or fall off. */
/* Q17. Because segments like "Champions" or "At-Risk" tell marketing exactly who to reward, who to win back, and who to ignore, instead of blasting the same message to everyone. */
/* Q18. Because it shows the exact step where the largest share of users disengages, pointing straight at the part of the flow that needs the most attention. */
/* Q19. The anchor is typically either the customer's registration_date (signup-based cohorts) or their first order date (purchase-based cohorts). */
/* Q20. A date spine guarantees every (cohort, period) combination exists as a row - even ones with zero activity - so a pivot or chart doesn't silently skip a period just because no orders happened. */
/* Q21. Because one customer can place several orders in the same period, and retention should measure "how many unique people were active", not "how many orders happened". */
/* Q22. It means the customer placed at least one qualifying order (or event) sometime during that calendar period. */
/* Q23. Percentages let you compare cohorts of very different sizes fairly (a 50-person cohort and a 5,000-person cohort), whereas raw counts would make the bigger cohort look artificially "better". */
/* Q24. Because NTILE needs to know the sort order of rows before it can divide them evenly into buckets - without ORDER BY there's no defined way to split the data. */
/* Q25. A view -> cart -> checkout purchase funnel, a registration -> first-order activation funnel, and a support-ticket-opened -> resolved funnel are all worth measuring at RetailMart. */

/* Q26. */
SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month
FROM customers.customers;

/* Q27. */
SELECT order_id, cust_id, DATE_TRUNC('month', order_date)::date AS order_month
FROM sales.orders;

/* Q28. (months-since-signup is computed exactly with age(), not day/30 division - see Q29) */
SELECT o.order_id, o.cust_id,
       DATE_TRUNC('month', o.order_date)::date AS order_month,
       DATE_TRUNC('month', c.registration_date)::date AS signup_month,
       (EXTRACT(YEAR FROM o.order_date) - EXTRACT(YEAR FROM c.registration_date)) * 12
         + (EXTRACT(MONTH FROM o.order_date) - EXTRACT(MONTH FROM c.registration_date)) AS period_index_concept
FROM sales.orders o
JOIN customers.customers c ON c.customer_id = o.cust_id;

/* Q29. */
SELECT o.order_id, o.cust_id,
       (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), DATE_TRUNC('month', c.registration_date))) * 12
        + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), DATE_TRUNC('month', c.registration_date))))::int AS period_index
FROM sales.orders o
JOIN customers.customers c ON c.customer_id = o.cust_id;

/* Q30. */
SELECT DATE_TRUNC('month', registration_date)::date AS signup_month, COUNT(DISTINCT customer_id) AS cohort_size
FROM customers.customers
GROUP BY DATE_TRUNC('month', registration_date)
ORDER BY signup_month;

/* Q31. */
WITH cohort AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month
  FROM customers.customers
)
SELECT co.signup_month, COUNT(DISTINCT o.cust_id) AS active_at_period_0
FROM cohort co
JOIN sales.orders o ON o.cust_id = co.customer_id
  AND DATE_TRUNC('month', o.order_date)::date = co.signup_month
GROUP BY co.signup_month
ORDER BY co.signup_month;

/* Q32. */
WITH cohort AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month
  FROM customers.customers
),
activity AS (
  SELECT co.signup_month, o.cust_id,
    (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
     + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)))::int AS period_index
  FROM cohort co
  JOIN sales.orders o ON o.cust_id = co.customer_id
)
SELECT signup_month, period_index, COUNT(DISTINCT cust_id) AS active_customers
FROM activity
GROUP BY signup_month, period_index
ORDER BY signup_month, period_index;

/* Q33. */
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
SELECT g.signup_month, g.period_index, g.active_customers, cs.cohort_size,
       ROUND(100.0 * g.active_customers / cs.cohort_size, 2) AS retention_pct
FROM grid g JOIN cohort_size cs ON cs.signup_month = g.signup_month
ORDER BY g.signup_month, g.period_index;

/* Q34. */
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
SELECT g.signup_month, g.period_index, g.active_customers, cs.cohort_size,
       ROUND(100.0 * g.active_customers / cs.cohort_size, 2) AS retention_pct
FROM grid g JOIN cohort_size cs ON cs.signup_month = g.signup_month
ORDER BY g.signup_month, g.period_index;

/* Q35. */
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
),
retention AS (
  SELECT g.signup_month, g.period_index, ROUND(100.0 * g.active_customers / cs.cohort_size, 2) AS retention_pct
  FROM grid g JOIN cohort_size cs ON cs.signup_month = g.signup_month
)
SELECT signup_month,
  MAX(retention_pct) FILTER (WHERE period_index = 0) AS m0,
  MAX(retention_pct) FILTER (WHERE period_index = 1) AS m1,
  MAX(retention_pct) FILTER (WHERE period_index = 2) AS m2,
  MAX(retention_pct) FILTER (WHERE period_index = 3) AS m3,
  MAX(retention_pct) FILTER (WHERE period_index = 6) AS m6,
  MAX(retention_pct) FILTER (WHERE period_index = 12) AS m12
FROM retention
GROUP BY signup_month
ORDER BY signup_month;

/* Q36. (same pivot as Q35 - retention_pct is already expressed as a percentage) */
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
  ROUND(100.0 * MAX(g.active_customers) FILTER (WHERE g.period_index = 0) / cs.cohort_size, 2) AS pct_m0,
  ROUND(100.0 * MAX(g.active_customers) FILTER (WHERE g.period_index = 1) / cs.cohort_size, 2) AS pct_m1,
  ROUND(100.0 * MAX(g.active_customers) FILTER (WHERE g.period_index = 3) / cs.cohort_size, 2) AS pct_m3
FROM grid g JOIN cohort_size cs ON cs.signup_month = g.signup_month
GROUP BY g.signup_month, cs.cohort_size
ORDER BY g.signup_month;

/* Q37. */
WITH cohort_size AS (
  SELECT DATE_TRUNC('month', registration_date)::date AS signup_month, COUNT(DISTINCT customer_id) AS cohort_size
  FROM customers.customers GROUP BY DATE_TRUNC('month', registration_date)
),
active_m1 AS (
  SELECT DATE_TRUNC('month', c.registration_date)::date AS signup_month, COUNT(DISTINCT c.customer_id) AS active_ct
  FROM customers.customers c
  JOIN sales.orders o ON o.cust_id = c.customer_id
  WHERE (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), DATE_TRUNC('month', c.registration_date))) * 12
       + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), DATE_TRUNC('month', c.registration_date)))) = 1
  GROUP BY DATE_TRUNC('month', c.registration_date)
)
SELECT cs.signup_month, ROUND(100.0 * COALESCE(a.active_ct,0) / cs.cohort_size, 2) AS month1_retention_pct
FROM cohort_size cs LEFT JOIN active_m1 a ON a.signup_month = cs.signup_month
ORDER BY cs.signup_month;

/* Q38. */
WITH cohort_size AS (
  SELECT DATE_TRUNC('month', registration_date)::date AS signup_month, COUNT(DISTINCT customer_id) AS cohort_size
  FROM customers.customers GROUP BY DATE_TRUNC('month', registration_date)
),
active_m3 AS (
  SELECT DATE_TRUNC('month', c.registration_date)::date AS signup_month, COUNT(DISTINCT c.customer_id) AS active_ct
  FROM customers.customers c
  JOIN sales.orders o ON o.cust_id = c.customer_id
  WHERE (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), DATE_TRUNC('month', c.registration_date))) * 12
       + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), DATE_TRUNC('month', c.registration_date)))) = 3
  GROUP BY DATE_TRUNC('month', c.registration_date)
)
SELECT cs.signup_month, ROUND(100.0 * COALESCE(a.active_ct,0) / cs.cohort_size, 2) AS month3_retention_pct
FROM cohort_size cs LEFT JOIN active_m3 a ON a.signup_month = cs.signup_month
ORDER BY cs.signup_month;

/* Q39. */
WITH cohort_size AS (
  SELECT DATE_TRUNC('month', registration_date)::date AS signup_month, COUNT(DISTINCT customer_id) AS cohort_size
  FROM customers.customers GROUP BY DATE_TRUNC('month', registration_date)
),
active_m6 AS (
  SELECT DATE_TRUNC('month', c.registration_date)::date AS signup_month, COUNT(DISTINCT c.customer_id) AS active_ct
  FROM customers.customers c
  JOIN sales.orders o ON o.cust_id = c.customer_id
  WHERE (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), DATE_TRUNC('month', c.registration_date))) * 12
       + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), DATE_TRUNC('month', c.registration_date)))) = 6
  GROUP BY DATE_TRUNC('month', c.registration_date)
)
SELECT cs.signup_month, ROUND(100.0 * COALESCE(a.active_ct,0) / cs.cohort_size, 2) AS month6_retention_pct
FROM cohort_size cs LEFT JOIN active_m6 a ON a.signup_month = cs.signup_month
ORDER BY cs.signup_month;

/* Q40. */
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
       ROUND(AVG(100.0 * COALESCE(a.active_ct,0) / cs.cohort_size), 2) AS avg_month1_retention_pct
FROM cohort_size cs LEFT JOIN active_m1 a ON a.signup_month = cs.signup_month
WHERE EXTRACT(YEAR FROM cs.signup_month) IN (2024, 2025)
GROUP BY EXTRACT(YEAR FROM cs.signup_month)
ORDER BY signup_year;

/* Q41. */
WITH cohort AS (
  SELECT c.customer_id, DATE_TRUNC('month', c.registration_date)::date AS signup_month, r.region_name
  FROM customers.customers c
  JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = true
  JOIN core.dim_region r ON r.state = a.state
),
cohort_size AS (
  SELECT region_name, signup_month, COUNT(DISTINCT customer_id) AS cohort_size
  FROM cohort GROUP BY region_name, signup_month
),
active_m1 AS (
  SELECT co.region_name, co.signup_month, COUNT(DISTINCT o.cust_id) AS active_ct
  FROM cohort co
  JOIN sales.orders o ON o.cust_id = co.customer_id
  WHERE (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
       + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month))) = 1
  GROUP BY co.region_name, co.signup_month
)
SELECT cs.region_name, cs.signup_month, ROUND(100.0 * COALESCE(a.active_ct,0) / cs.cohort_size, 2) AS month1_retention_pct
FROM cohort_size cs LEFT JOIN active_m1 a ON a.region_name = cs.region_name AND a.signup_month = cs.signup_month
ORDER BY cs.region_name, cs.signup_month;

/* Q42. */
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
SELECT cs.tier, cs.signup_month, ROUND(100.0 * COALESCE(a.active_ct,0) / cs.cohort_size, 2) AS month1_retention_pct
FROM cohort_size cs LEFT JOIN active_m1 a ON a.tier = cs.tier AND a.signup_month = cs.signup_month
ORDER BY cs.tier, cs.signup_month;

/* Q43. */
SELECT
  (SELECT SUM(cohort_size) FROM (SELECT COUNT(DISTINCT customer_id) AS cohort_size FROM customers.customers
    GROUP BY DATE_TRUNC('month', registration_date)) x) AS sum_of_cohort_sizes,
  (SELECT COUNT(*) FROM customers.customers) AS total_customers;

/* Q44. */
WITH spine AS (
  SELECT DISTINCT DATE_TRUNC('month', registration_date)::date AS signup_month FROM customers.customers
),
periods AS (
  SELECT generate_series(0,11) AS period_index
),
full_grid AS (
  SELECT s.signup_month, p.period_index FROM spine s CROSS JOIN periods p
)
SELECT COUNT(*) AS expected_cells FROM full_grid;

/* Q45. */
WITH cohort AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month
  FROM customers.customers
),
activity AS (
  SELECT co.signup_month, o.cust_id,
    (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
     + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)))::int AS period_index
  FROM cohort co JOIN sales.orders o ON o.cust_id = co.customer_id
)
SELECT signup_month, period_index, COUNT(DISTINCT cust_id) AS active_customers
FROM activity
WHERE period_index >= 0 AND signup_month + (period_index || ' months')::interval <= CURRENT_DATE
GROUP BY signup_month, period_index
ORDER BY signup_month, period_index;

/* Q46. */
WITH cohort AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month
  FROM customers.customers
)
SELECT co.signup_month,
    (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)) * 12
     + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), co.signup_month)))::int AS period_index,
    SUM(o.net_total) AS cohort_revenue
FROM cohort co
JOIN sales.orders o ON o.cust_id = co.customer_id
GROUP BY co.signup_month, period_index
ORDER BY co.signup_month, period_index;

/* Q47. */
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
FROM period_rev
ORDER BY signup_month, period_index;

/* Q48. */
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
SELECT signup_month, period_index, ROUND(AVG(cust_revenue), 2) AS avg_revenue_per_active_customer
FROM period_data
GROUP BY signup_month, period_index
ORDER BY signup_month, period_index;

/* Q49. */
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
SELECT cs.signup_month, ROUND(100.0 * COALESCE(a.active_ct,0) / cs.cohort_size, 2) AS month3_retention_pct
FROM cohort_size cs LEFT JOIN active_m3 a ON a.signup_month = cs.signup_month
ORDER BY month3_retention_pct DESC NULLS LAST
LIMIT 1;

/* Q50. */
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
SELECT cs.signup_month, ROUND(100.0 * COALESCE(a.active_ct,0) / cs.cohort_size, 2) AS month3_retention_pct
FROM cohort_size cs LEFT JOIN active_m3 a ON a.signup_month = cs.signup_month
ORDER BY month3_retention_pct ASC NULLS FIRST
LIMIT 1;

/* Q51. */
SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order
FROM sales.orders
GROUP BY cust_id;

/* Q52. */
SELECT cust_id, COUNT(*) AS frequency
FROM sales.orders
GROUP BY cust_id;

/* Q53. */
SELECT cust_id, SUM(net_total) AS monetary
FROM sales.orders
GROUP BY cust_id;

/* Q54. */
WITH recency AS (
  SELECT cust_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order
  FROM sales.orders GROUP BY cust_id
)
SELECT cust_id, days_since_last_order, NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r_score
FROM recency;

/* Q55. */
WITH frequency AS (
  SELECT cust_id, COUNT(*) AS order_count FROM sales.orders GROUP BY cust_id
)
SELECT cust_id, order_count, NTILE(5) OVER (ORDER BY order_count) AS f_score
FROM frequency;

/* Q56. */
WITH monetary AS (
  SELECT cust_id, SUM(net_total) AS lifetime_revenue FROM sales.orders GROUP BY cust_id
)
SELECT cust_id, lifetime_revenue, NTILE(5) OVER (ORDER BY lifetime_revenue) AS m_score
FROM monetary;

/* Q57. */
WITH rfm_raw AS (
  SELECT cust_id,
    (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
    COUNT(*) AS order_count,
    SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
)
SELECT cust_id, r, f, m, (r::text || f::text || m::text) AS rfm_string
FROM scored;

/* Q58. */
WITH rfm_raw AS (
  SELECT cust_id,
    (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
    COUNT(*) AS order_count,
    SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
)
SELECT cust_id, r, f, m, (r + f + m) AS rfm_total
FROM scored;

/* Q59. */
WITH rfm_raw AS (
  SELECT cust_id,
    (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
    COUNT(*) AS order_count,
    SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
)
SELECT cust_id, r, f, m, (r + f + m) AS rfm_total
FROM scored
ORDER BY rfm_total DESC
LIMIT 20;

/* Q60. */
WITH rfm_raw AS (
  SELECT cust_id,
    (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
    COUNT(*) AS order_count,
    SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
)
SELECT cust_id FROM scored WHERE r = 5 AND f = 5 AND m = 5;

/* Q61. */
WITH rfm_raw AS (
  SELECT cust_id,
    (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
    COUNT(*) AS order_count,
    SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
)
SELECT cust_id FROM scored WHERE r <= 2 AND (f >= 4 OR m >= 4);

/* Q62. */
WITH rfm_raw AS (
  SELECT cust_id,
    (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
    COUNT(*) AS order_count,
    SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
)
SELECT cust_id FROM scored WHERE r = 5 AND f = 1 AND m = 1;

/* Q63. */
WITH rfm_raw AS (
  SELECT cust_id,
    (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
    COUNT(*) AS order_count,
    SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
)
SELECT cust_id FROM scored WHERE r = 1 AND f = 1 AND m = 1;

/* Q64. */
WITH rfm_raw AS (
  SELECT cust_id,
    (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
    COUNT(*) AS order_count,
    SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
)
SELECT (r::text || f::text || m::text) AS rfm_string, COUNT(*) AS customer_ct
FROM scored
GROUP BY rfm_string
ORDER BY rfm_string;

/* Q65. */
WITH rfm_raw AS (
  SELECT cust_id,
    (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
    COUNT(*) AS order_count,
    SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
)
SELECT 'R' AS dim, r AS score, COUNT(*) AS n FROM scored GROUP BY r
UNION ALL
SELECT 'F', f, COUNT(*) FROM scored GROUP BY f
UNION ALL
SELECT 'M', m, COUNT(*) FROM scored GROUP BY m
ORDER BY dim, score;

/* Q66. */
WITH rfm_raw AS (
  SELECT o.cust_id,
    (SELECT MAX(order_date) FROM sales.orders) - MAX(o.order_date) AS days_since_last_order,
    COUNT(*) AS order_count,
    SUM(o.net_total) AS lifetime_revenue
  FROM sales.orders o GROUP BY o.cust_id
),
scored AS (
  SELECT cust_id,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
)
SELECT reg.region_name, (s.r::text || s.f::text || s.m::text) AS rfm_string, COUNT(*) AS n
FROM scored s
JOIN customers.addresses a ON a.customer_id = s.cust_id AND a.is_default = true
JOIN core.dim_region reg ON reg.state = a.state
GROUP BY reg.region_name, rfm_string
ORDER BY reg.region_name, rfm_string;

/* Q67. */
WITH rfm_raw AS (
  SELECT o.cust_id,
    (SELECT MAX(order_date) FROM sales.orders) - MAX(o.order_date) AS days_since_last_order,
    COUNT(*) AS order_count,
    SUM(o.net_total) AS lifetime_revenue
  FROM sales.orders o GROUP BY o.cust_id
),
scored AS (
  SELECT cust_id,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
)
SELECT DATE_TRUNC('month', c.registration_date)::date AS signup_month,
       (s.r::text || s.f::text || s.m::text) AS rfm_string, COUNT(*) AS n
FROM scored s
JOIN customers.customers c ON c.customer_id = s.cust_id
GROUP BY signup_month, rfm_string
ORDER BY signup_month, rfm_string;

/* Q68. */
WITH rfm_raw AS (
  SELECT cust_id,
    (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
    COUNT(*) AS order_count,
    SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id, lifetime_revenue,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
)
SELECT (r::text || f::text || m::text) AS rfm_string,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY lifetime_revenue) AS median_lifetime_spend
FROM scored
GROUP BY rfm_string
ORDER BY rfm_string;

/* Q69. */
WITH rfm_raw AS (
  SELECT cust_id,
    (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
    COUNT(*) AS order_count,
    SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id, order_count,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
)
SELECT (r::text || f::text || m::text) AS rfm_string, ROUND(AVG(order_count), 2) AS avg_orders
FROM scored
GROUP BY rfm_string
ORDER BY rfm_string;

/* Q70. */
WITH rfm_raw AS (
  SELECT cust_id,
    (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
    COUNT(*) AS order_count,
    SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id, lifetime_revenue,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
)
SELECT cust_id, lifetime_revenue
FROM scored
WHERE r = 5 AND f = 5 AND m = 5
ORDER BY lifetime_revenue DESC
LIMIT 10;

/* Q71. */
WITH rfm_raw AS (
  SELECT cust_id,
    (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
    COUNT(*) AS order_count,
    SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
)
SELECT c.tier, ROUND(AVG(s.r + s.f + s.m), 2) AS avg_rfm_total
FROM scored s JOIN customers.customers c ON c.customer_id = s.cust_id
GROUP BY c.tier
ORDER BY avg_rfm_total DESC;

/* Q72. */
WITH rfm_raw AS (
  SELECT cust_id,
    (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
    COUNT(*) AS order_count,
    SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
)
SELECT (s.r::text || s.f::text || s.m::text) AS rfm_string,
       COUNT(*) FILTER (WHERE reg.region_name = 'North') AS north_ct,
       COUNT(*) FILTER (WHERE reg.region_name = 'South') AS south_ct,
       COUNT(*) FILTER (WHERE reg.region_name = 'East') AS east_ct,
       COUNT(*) FILTER (WHERE reg.region_name = 'West') AS west_ct,
       COUNT(*) FILTER (WHERE reg.region_name = 'Central') AS central_ct,
       COUNT(*) FILTER (WHERE reg.region_name = 'North East') AS northeast_ct
FROM scored s
JOIN customers.addresses a ON a.customer_id = s.cust_id AND a.is_default = true
JOIN core.dim_region reg ON reg.state = a.state
GROUP BY rfm_string
ORDER BY rfm_string;

/* Q73. */
WITH rfm_raw AS (
  SELECT cust_id,
    (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
    COUNT(*) AS order_count,
    SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id,
    CASE WHEN NTILE(5) OVER (ORDER BY days_since_last_order DESC) = 5
          AND NTILE(5) OVER (ORDER BY order_count) = 5
          AND NTILE(5) OVER (ORDER BY lifetime_revenue) = 5 THEN 'Champions' ELSE 'Other' END AS segment
  FROM rfm_raw
)
SELECT c.tier, ROUND(100.0 * COUNT(*) FILTER (WHERE s.segment = 'Champions') / COUNT(*), 2) AS pct_champions
FROM scored s JOIN customers.customers c ON c.customer_id = s.cust_id
GROUP BY c.tier
ORDER BY c.tier;

/* Q74. Comparing current Champions to At-Risk against last quarter requires point-in-time RFM scoring (recomputing R/F/M as of a past cutoff date) - a full worked version of this is the medium/hard files' quarter-over-quarter drift queries; at easy level this is a design question, not a single runnable query. */

/* Q75. */
WITH rfm_raw AS (
  SELECT cust_id,
    (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
    COUNT(*) AS order_count,
    SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
)
SELECT COUNT(*) AS scored_customers,
       (SELECT COUNT(DISTINCT cust_id) FROM sales.orders) AS customers_with_orders
FROM scored;

/* Q76. */
SELECT COUNT(DISTINCT customer_id) AS viewers FROM web_events.page_views;

/* Q77. */
SELECT COUNT(DISTINCT cust_id) AS orderers FROM sales.orders;

/* Q78. */
WITH viewers AS (SELECT COUNT(DISTINCT customer_id) AS n FROM web_events.page_views WHERE customer_id IS NOT NULL),
orderers AS (
  SELECT COUNT(DISTINCT p.customer_id) AS n
  FROM web_events.page_views p
  JOIN sales.orders o ON o.cust_id = p.customer_id
)
SELECT v.n AS viewers, o.n AS viewer_orderers, ROUND(100.0*o.n/v.n, 2) AS pct_converted
FROM viewers v, orderers o;

/* Q79. */
SELECT COUNT(DISTINCT customer_id) AS product_page_viewers
FROM web_events.page_views
WHERE page_url LIKE '%product%';

/* Q80. */
SELECT COUNT(DISTINCT customer_id) AS cart_viewers
FROM web_events.page_views
WHERE page_url LIKE '%cart%';

/* Q81. */
SELECT COUNT(DISTINCT customer_id) AS checkout_viewers
FROM web_events.page_views
WHERE page_url LIKE '%checkout%';

/* Q82. */
SELECT
  (SELECT COUNT(DISTINCT customer_id) FROM web_events.page_views WHERE page_url LIKE '%product%') AS step1_product,
  (SELECT COUNT(DISTINCT customer_id) FROM web_events.page_views WHERE page_url LIKE '%cart%') AS step2_cart,
  (SELECT COUNT(DISTINCT customer_id) FROM web_events.page_views WHERE page_url LIKE '%checkout%') AS step3_checkout;

/* Q83. */
WITH steps AS (
  SELECT
    (SELECT COUNT(DISTINCT customer_id) FROM web_events.page_views WHERE page_url LIKE '%product%') AS product,
    (SELECT COUNT(DISTINCT customer_id) FROM web_events.page_views WHERE page_url LIKE '%cart%') AS cart,
    (SELECT COUNT(DISTINCT customer_id) FROM web_events.page_views WHERE page_url LIKE '%checkout%') AS checkout
)
SELECT product, cart, checkout,
       ROUND(100.0 * cart / NULLIF(product,0), 2) AS pct_product_to_cart,
       ROUND(100.0 * checkout / NULLIF(cart,0), 2) AS pct_cart_to_checkout
FROM steps;

/* Q84. */
SELECT session_id,
  MAX(CASE WHEN page_url LIKE '%product%' THEN 1 ELSE 0 END) AS reached_product,
  MAX(CASE WHEN page_url LIKE '%cart%' THEN 1 ELSE 0 END) AS reached_cart,
  MAX(CASE WHEN page_url LIKE '%checkout%' THEN 1 ELSE 0 END) AS reached_checkout
FROM web_events.page_views
GROUP BY session_id;

/* Q85. */
SELECT device_type,
  COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%product%') AS product,
  COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%cart%') AS cart,
  COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%checkout%') AS checkout
FROM web_events.page_views
GROUP BY device_type
ORDER BY device_type;

/* Q86. */
SELECT DATE_TRUNC('month', view_timestamp)::date AS month,
  COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%product%') AS product,
  COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%cart%') AS cart,
  COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%checkout%') AS checkout
FROM web_events.page_views
GROUP BY DATE_TRUNC('month', view_timestamp)
ORDER BY month;

/* Q87. */
SELECT cust_id, SUM(net_total) AS clv
FROM sales.orders
WHERE order_status = 'Delivered'
GROUP BY cust_id;

/* Q88. */
WITH clv AS (
  SELECT o.cust_id, SUM(o.net_total) AS clv
  FROM sales.orders o WHERE o.order_status = 'Delivered' GROUP BY o.cust_id
)
SELECT r.region_name, ROUND(AVG(clv.clv), 2) AS avg_clv,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY clv.clv)::numeric, 2) AS median_clv
FROM clv
JOIN customers.addresses a ON a.customer_id = clv.cust_id AND a.is_default = true
JOIN core.dim_region r ON r.state = a.state
GROUP BY r.region_name
ORDER BY r.region_name;

/* Q89. */
WITH clv AS (
  SELECT o.cust_id, SUM(o.net_total) AS clv
  FROM sales.orders o WHERE o.order_status = 'Delivered' GROUP BY o.cust_id
)
SELECT DATE_TRUNC('month', c.registration_date)::date AS signup_month, ROUND(AVG(clv.clv), 2) AS avg_clv
FROM clv JOIN customers.customers c ON c.customer_id = clv.cust_id
GROUP BY signup_month
ORDER BY signup_month;

/* Q90. */
WITH clv AS (
  SELECT o.cust_id, SUM(o.net_total) AS clv
  FROM sales.orders o WHERE o.order_status = 'Delivered' GROUP BY o.cust_id
),
rfm_raw AS (
  SELECT cust_id,
    (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
    COUNT(*) AS order_count,
    SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
)
SELECT (s.r::text || s.f::text || s.m::text) AS rfm_string, ROUND(AVG(clv.clv), 2) AS avg_clv
FROM scored s
JOIN clv ON clv.cust_id = s.cust_id
GROUP BY rfm_string
ORDER BY rfm_string;

/* Q91. */
WITH monthly AS (
  SELECT r.region_id, DATE_TRUNC('month', o.order_date) AS month, SUM(o.net_total) AS revenue
  FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id JOIN core.dim_region r ON r.region_id = s.region_id
  GROUP BY r.region_id, DATE_TRUNC('month', o.order_date)
)
SELECT region_id, month, revenue,
       LAG(revenue) OVER (PARTITION BY region_id ORDER BY month) AS prev_month_revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (PARTITION BY region_id ORDER BY month))
             / NULLIF(LAG(revenue) OVER (PARTITION BY region_id ORDER BY month),0), 2) AS mom_growth_pct
FROM monthly
ORDER BY region_id, month;

/* Q92. */
WITH monthly AS (
  SELECT DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS revenue
  FROM sales.orders GROUP BY DATE_TRUNC('month', order_date)
)
SELECT month, revenue,
       LAG(revenue, 12) OVER (ORDER BY month) AS same_month_last_year,
       ROUND(100.0 * (revenue - LAG(revenue,12) OVER (ORDER BY month))
             / NULLIF(LAG(revenue,12) OVER (ORDER BY month),0), 2) AS yoy_growth_pct
FROM monthly
ORDER BY month;

/* Q93. */
WITH quarterly AS (
  SELECT dc.category_name, DATE_TRUNC('quarter', o.order_date) AS quarter, SUM(oi.net_amount) AS revenue
  FROM sales.orders o
  JOIN sales.order_items oi ON oi.order_id = o.order_id
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category dc ON dc.category_id = b.category_id
  GROUP BY dc.category_name, DATE_TRUNC('quarter', o.order_date)
)
SELECT category_name, quarter, revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (PARTITION BY category_name ORDER BY quarter))
             / NULLIF(LAG(revenue) OVER (PARTITION BY category_name ORDER BY quarter),0), 2) AS qoq_growth_pct
FROM quarterly
ORDER BY category_name, quarter;

/* Q94. */
WITH monthly_active AS (
  SELECT r.region_id, DATE_TRUNC('month', o.order_date) AS month, COUNT(DISTINCT o.cust_id) AS active_customers
  FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id JOIN core.dim_region r ON r.region_id = s.region_id
  GROUP BY r.region_id, DATE_TRUNC('month', o.order_date)
)
SELECT region_id, month, active_customers,
       active_customers - LAG(active_customers) OVER (PARTITION BY region_id ORDER BY month) AS change_vs_prev_month
FROM monthly_active
ORDER BY region_id, month;

/* Q95. */
WITH first_order AS (
  SELECT cust_id, DATE_TRUNC('month', MIN(order_date)) AS first_order_month
  FROM sales.orders GROUP BY cust_id
),
monthly_new AS (
  SELECT first_order_month, COUNT(*) AS new_customers
  FROM first_order GROUP BY first_order_month
)
SELECT first_order_month, new_customers,
       new_customers - LAG(new_customers) OVER (ORDER BY first_order_month) AS change_vs_prev_month
FROM monthly_new
ORDER BY first_order_month;

/* Q96. */
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
FROM period_rev
ORDER BY signup_month, period_index;

/* Q97. */
WITH clv AS (
  SELECT cust_id, SUM(net_total) AS clv FROM sales.orders WHERE order_status = 'Delivered' GROUP BY cust_id
),
monetary AS (
  SELECT cust_id, SUM(net_total) AS lifetime_revenue FROM sales.orders GROUP BY cust_id
)
SELECT CORR(clv.clv, m.lifetime_revenue) AS clv_monetary_correlation
FROM clv JOIN monetary m ON m.cust_id = clv.cust_id;

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
  FROM activity WHERE period_index BETWEEN 0 AND 11
  GROUP BY signup_month, period_index
)
SELECT g.signup_month,
  ROUND(100.0 * MAX(g.active_customers) FILTER (WHERE g.period_index = 0) / cs.cohort_size, 2) AS m0,
  ROUND(100.0 * MAX(g.active_customers) FILTER (WHERE g.period_index = 1) / cs.cohort_size, 2) AS m1,
  ROUND(100.0 * MAX(g.active_customers) FILTER (WHERE g.period_index = 3) / cs.cohort_size, 2) AS m3,
  ROUND(100.0 * MAX(g.active_customers) FILTER (WHERE g.period_index = 6) / cs.cohort_size, 2) AS m6
FROM grid g JOIN cohort_size cs ON cs.signup_month = g.signup_month
GROUP BY g.signup_month, cs.cohort_size
ORDER BY g.signup_month;

/* Q99. */
WITH rfm_raw AS (
  SELECT cust_id,
    (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
    COUNT(*) AS order_count,
    SUM(net_total) AS lifetime_revenue
  FROM sales.orders GROUP BY cust_id
),
scored AS (
  SELECT cust_id, lifetime_revenue,
    NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r,
    NTILE(5) OVER (ORDER BY order_count) AS f,
    NTILE(5) OVER (ORDER BY lifetime_revenue) AS m
  FROM rfm_raw
)
SELECT (r::text || f::text || m::text) AS rfm_string, COUNT(*) AS n,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY lifetime_revenue)::numeric, 2) AS median_clv
FROM scored
GROUP BY rfm_string
ORDER BY n DESC
LIMIT 10;

/* Q100. (uses the dataset's own max order_date as "today" instead of CURRENT_DATE, since the data does not extend to the real calendar date) */
WITH ref AS (SELECT DATE_TRUNC('month', MAX(order_date)) AS this_month FROM sales.orders)
SELECT
  (SELECT ROUND(100.0 * COUNT(DISTINCT c.customer_id) /
       NULLIF((SELECT COUNT(DISTINCT customer_id) FROM customers.customers
               WHERE DATE_TRUNC('month', registration_date) = (SELECT this_month - INTERVAL '1 month' FROM ref)), 0), 2)
     FROM customers.customers c JOIN sales.orders o ON o.cust_id = c.customer_id
     WHERE DATE_TRUNC('month', c.registration_date) = (SELECT this_month - INTERVAL '1 month' FROM ref)
       AND DATE_TRUNC('month', o.order_date) = (SELECT this_month FROM ref)) AS last_cohort_month1_retention_pct,
  (SELECT COUNT(*) FROM (
     SELECT cust_id FROM sales.orders GROUP BY cust_id HAVING COUNT(*) >= (
       SELECT PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY order_count) FROM (
         SELECT COUNT(*) AS order_count FROM sales.orders GROUP BY cust_id) y)
   ) top_seg) AS top_rfm_segment_size,
  (SELECT ROUND(100.0 * COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%checkout%')
       / NULLIF(COUNT(DISTINCT customer_id) FILTER (WHERE page_url LIKE '%cart%'),0), 2)
     FROM web_events.page_views) AS cart_to_checkout_conversion_pct,
  (SELECT ROUND(100.0 * (SUM(net_total) FILTER (WHERE order_date >= (SELECT this_month FROM ref))
        - SUM(net_total) FILTER (WHERE order_date >= (SELECT this_month - INTERVAL '1 month' FROM ref)
                                    AND order_date < (SELECT this_month FROM ref)))
       / NULLIF(SUM(net_total) FILTER (WHERE order_date >= (SELECT this_month - INTERVAL '1 month' FROM ref)
                                    AND order_date < (SELECT this_month FROM ref)),0), 2)
     FROM sales.orders) AS mom_revenue_growth_pct;
