/* ============================================================
   ANSWER KEY - Subqueries + CTEs Combined (EASY LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* SECTION A: SYNTHESIS / CONCEPTUAL (25) - text answers, no queries to run */

/* Q1.  Use a CTE when the logic is reused, needs a name for readability, or is referenced more than once; use a plain subquery for a small one-off filter or computation. */
/* Q2.  Use a subquery when you only need a value/set to filter or compare against; use a JOIN when you need columns from both tables in the final result. */
/* Q3.  A CTE (WITH x AS (...)) is named and can be referenced multiple times and is easier to read top-to-bottom; a derived table (a subquery in FROM) is inline and scoped to just that one usage. */
/* Q4.  Use LATERAL when the subquery in FROM needs to reference columns from a preceding table in the same FROM clause (e.g. top-N per row); use a plain correlated subquery when you just need a single scalar value per outer row. */
/* Q5.  Use RECURSIVE when the hierarchy/depth is unknown or data-driven inside the database; use iterative app code when the logic is complex business logic better expressed outside SQL or the recursion depth is tiny and fixed. */
/* Q6.  Pre-aggregating in a CTE before joining avoids fanning out rows across a one-to-many join and re-counting/re-summing duplicated rows - aggregate first, then join the smaller summarized result. */
/* Q7.  Run EXPLAIN ANALYZE on both versions (subquery vs CTE vs JOIN) and pick whichever the planner executes with lower actual cost/time, rather than guessing based on syntax alone. */
/* Q8.  Prefer whichever form reads more clearly to the team as a first pass, but verify with EXPLAIN ANALYZE that readability didn't come at an unacceptable performance cost on large tables. */
/* Q9.  Breaking a long query into named CTEs lets each step be understood, tested, and reused independently, turning one dense query into a readable, modular pipeline. */
/* Q10. A subquery is handy for a quick inline computation (e.g. a scalar subquery in SELECT) that doesn't need its own name or reuse elsewhere in the query. */
/* Q11. A subquery filters candidate rows, a CTE pre-aggregates them, and a window function then ranks or computes a running value over that pre-aggregated CTE - each technique handling one stage of the pipeline. */
/* Q12. A CTE can prepare a clean set of outer rows (e.g. one row per customer), and a LATERAL subquery then pulls the top related rows (e.g. their 3 most recent orders) for each of those CTE rows. */
/* Q13. A RECURSIVE CTE builds a hierarchy or sequence, and its result can then be joined or filtered in a following CTE in the same WITH chain, keeping the pipeline readable in ordered steps. */
/* Q14. A scalar subquery inside SELECT can pull one related value per row (e.g. a customer's order count) alongside a JOIN that brings in other related table's columns in the same query. */
/* Q15. A subquery inside HAVING can filter groups based on a computed threshold, while a window function in the SELECT list can show a per-row rank alongside that same grouped result. */
/* Q16. Materialize (as a materialized view or temp table) when the same expensive computation is queried repeatedly and the underlying data doesn't change every second. */
/* Q17. Inline a CTE/subquery when it's cheap to compute and only used once per query - materializing it would add overhead with no reuse benefit. */
/* Q18. Use a plain VIEW when you always want the latest live data computed on each query; use a MATERIALIZED VIEW when the query is expensive and slightly-stale, periodically refreshed results are acceptable. */
/* Q19. Refactor a subquery into a CTE when it becomes deeply nested, is repeated in multiple places, or hurts readability - giving it a name clarifies intent. */
/* Q20. Refactor a CTE into a materialized view when the same CTE logic is recomputed by many different queries/reports and the cost of recomputing every time becomes too high. */
/* Q21. Denormalize when read performance for a specific, frequent query pattern matters more than avoiding redundancy, and you can tolerate/manage the sync risk. */
/* Q22. Partition a table when it has grown very large and queries commonly filter on the partition key (like a date range), letting Postgres scan only relevant partitions. */
/* Q23. Add an index when a column is frequently used in WHERE, JOIN, or ORDER BY clauses on a large table and sequential scans are measurably slow. */
/* Q24. Write a stored procedure when a multi-step operation (with control flow, multiple statements, or transactions) needs to run atomically and repeatedly inside the database itself. */
/* Q25. Push computation to the database when it involves filtering/aggregating large volumes of data (SQL does this efficiently); push to the app when the logic is complex business rules, external API calls, or presentation formatting. */

/* SECTION B: KPI REPORTS (25) */

/* Q26. */
WITH monthly_revenue AS (
  SELECT DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS revenue
  FROM sales.orders
  WHERE order_status NOT IN ('Cancelled', 'Failed')
  GROUP BY 1
)
SELECT month, revenue AS approx_mrr
FROM monthly_revenue
ORDER BY month;

/* Q27. */
WITH last_12mo AS (
  SELECT SUM(net_total) AS revenue_12mo
  FROM sales.orders
  WHERE order_status NOT IN ('Cancelled', 'Failed')
    AND order_date >= (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '12 months'
)
SELECT revenue_12mo AS approx_arr
FROM last_12mo;

/* Q28. */
WITH monthly_spend AS (
  SELECT DATE_TRUNC('month', spend_date) AS month, SUM(amount) AS spend
  FROM marketing.ads_spend
  GROUP BY 1
),
monthly_new_cust AS (
  SELECT DATE_TRUNC('month', registration_date) AS month, COUNT(*) AS new_customers
  FROM customers.customers
  GROUP BY 1
)
SELECT s.month, s.spend, c.new_customers,
       ROUND(s.spend / NULLIF(c.new_customers, 0), 2) AS cac
FROM monthly_spend s
JOIN monthly_new_cust c ON c.month = s.month
ORDER BY s.month;

/* Q29. */
WITH customer_revenue AS (
  SELECT cust_id, SUM(net_total) AS total_spend
  FROM sales.orders
  WHERE order_status NOT IN ('Cancelled', 'Failed')
  GROUP BY cust_id
)
SELECT ROUND(AVG(total_spend), 2) AS avg_ltv
FROM customer_revenue;

/* Q30. */
WITH customer_revenue AS (
  SELECT cust_id, SUM(net_total) AS total_spend
  FROM sales.orders
  WHERE order_status NOT IN ('Cancelled', 'Failed')
  GROUP BY cust_id
),
ltv AS (
  SELECT AVG(total_spend) AS avg_ltv FROM customer_revenue
),
cac AS (
  SELECT SUM(amount) / NULLIF((SELECT COUNT(*) FROM customers.customers), 0) AS avg_cac
  FROM marketing.ads_spend
)
SELECT ROUND(ltv.avg_ltv, 2) AS avg_ltv,
       ROUND(cac.avg_cac, 2) AS avg_cac,
       ROUND(ltv.avg_ltv / NULLIF(cac.avg_cac, 0), 2) AS ltv_cac_ratio
FROM ltv, cac;

/* Q31. */
SELECT ROUND(AVG(net_total), 2) AS avg_order_value
FROM sales.orders
WHERE order_status NOT IN ('Cancelled', 'Failed');

/* Q32. */
WITH visitors AS (
  SELECT COUNT(DISTINCT customer_id) AS visiting_customers
  FROM web_events.page_views
  WHERE customer_id IS NOT NULL
),
buyers AS (
  SELECT COUNT(DISTINCT cust_id) AS ordering_customers
  FROM sales.orders
)
SELECT v.visiting_customers, b.ordering_customers,
       ROUND(100.0 * b.ordering_customers / NULLIF(v.visiting_customers, 0), 2) AS conversion_rate_pct
FROM visitors v, buyers b;

/* Q33. */
WITH order_counts AS (
  SELECT cust_id, COUNT(*) AS orders
  FROM sales.orders
  WHERE order_status NOT IN ('Cancelled', 'Failed')
  GROUP BY cust_id
)
SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE orders > 1) / NULLIF(COUNT(*), 0), 2) AS repeat_purchase_rate_pct
FROM order_counts;

/* Q34. */
WITH totals AS (
  SELECT (SELECT SUM(net_total) FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed')) AS total_revenue,
         (SELECT SUM(refund_amount) FROM sales.returns) AS total_refunds
)
SELECT total_revenue, total_refunds,
       ROUND(100.0 * total_refunds / NULLIF(total_revenue, 0), 2) AS refund_rate_pct
FROM totals;

/* Q35. */
SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE order_status = 'Cancelled') / COUNT(*), 2) AS cancellation_rate_pct
FROM sales.orders;

/* Q36. */
WITH resolved AS (
  SELECT ticket_id, resolved_date - created_date AS resolution_time
  FROM support.tickets
  WHERE resolved_date IS NOT NULL
)
SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE resolution_time <= INTERVAL '48 hours') / COUNT(*), 2) AS sla_compliance_pct
FROM resolved;

/* Q37. */
SELECT ROUND(AVG(rating), 2) AS avg_rating,
       ROUND(100.0 * COUNT(*) FILTER (WHERE rating >= 4) / COUNT(*), 2) AS csat_pct
FROM customers.reviews;

/* Q38. */
WITH scored AS (
  SELECT rating,
         CASE WHEN rating = 5 THEN 'promoter'
              WHEN rating = 4 THEN 'passive'
              ELSE 'detractor' END AS category
  FROM customers.reviews
)
SELECT ROUND(100.0 * (COUNT(*) FILTER (WHERE category = 'promoter') - COUNT(*) FILTER (WHERE category = 'detractor')) / COUNT(*), 2) AS nps
FROM scored;

/* Q39. */
SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE resolved_date::date = created_date::date) / COUNT(*) FILTER (WHERE resolved_date IS NOT NULL), 2) AS fcr_pct
FROM support.tickets;

/* Q40. */
SELECT ROUND(AVG(call_duration_seconds), 1) AS avg_handle_time_seconds
FROM call_center.calls;

/* Q41. */
WITH campaign_spend AS (
  SELECT campaign_id, SUM(amount) AS spend
  FROM marketing.ads_spend
  GROUP BY campaign_id
),
campaign_leads AS (
  SELECT campaign_id, SUM(emails_clicked) AS leads
  FROM marketing.email_clicks
  GROUP BY campaign_id
)
SELECT s.campaign_id, s.spend, l.leads,
       ROUND(s.spend / NULLIF(l.leads, 0), 2) AS cost_per_lead
FROM campaign_spend s
JOIN campaign_leads l ON l.campaign_id = s.campaign_id
ORDER BY cost_per_lead DESC NULLS LAST
LIMIT 20;

/* Q42. */
WITH campaign_spend AS (
  SELECT campaign_id, SUM(amount) AS spend
  FROM marketing.ads_spend
  GROUP BY campaign_id
),
campaign_clicks AS (
  SELECT campaign_id, SUM(emails_clicked) AS clicks
  FROM marketing.email_clicks
  GROUP BY campaign_id
)
SELECT s.campaign_id, s.spend, c.clicks,
       ROUND(s.spend / NULLIF(c.clicks, 0), 4) AS cost_per_click
FROM campaign_spend s
JOIN campaign_clicks c ON c.campaign_id = s.campaign_id
ORDER BY cost_per_click DESC NULLS LAST
LIMIT 20;

/* Q43. */
WITH campaign_spend AS (
  SELECT campaign_id, SUM(amount) AS spend
  FROM marketing.ads_spend
  GROUP BY campaign_id
),
campaign_revenue AS (
  SELECT c.campaign_id, SUM(o.net_total) AS revenue
  FROM marketing.campaigns c
  JOIN sales.orders o ON o.order_date BETWEEN c.start_date AND c.end_date
  WHERE o.order_status NOT IN ('Cancelled', 'Failed')
  GROUP BY c.campaign_id
)
SELECT s.campaign_id, s.spend, COALESCE(r.revenue, 0) AS attributed_revenue,
       ROUND(COALESCE(r.revenue, 0) / NULLIF(s.spend, 0), 2) AS roas
FROM campaign_spend s
LEFT JOIN campaign_revenue r ON r.campaign_id = s.campaign_id
ORDER BY roas DESC NULLS LAST
LIMIT 20;

/* Q44. */
WITH campaign_spend AS (
  SELECT campaign_id, SUM(amount) AS spend
  FROM marketing.ads_spend
  GROUP BY campaign_id
),
campaign_revenue AS (
  SELECT c.campaign_id, SUM(o.net_total) AS revenue
  FROM marketing.campaigns c
  JOIN sales.orders o ON o.order_date BETWEEN c.start_date AND c.end_date
  WHERE o.order_status NOT IN ('Cancelled', 'Failed')
  GROUP BY c.campaign_id
)
SELECT s.campaign_id, s.spend, COALESCE(r.revenue, 0) AS attributed_revenue,
       ROUND(100.0 * (COALESCE(r.revenue, 0) - s.spend) / NULLIF(s.spend, 0), 2) AS roi_pct
FROM campaign_spend s
LEFT JOIN campaign_revenue r ON r.campaign_id = s.campaign_id
ORDER BY roi_pct DESC NULLS LAST
LIMIT 20;

/* Q45. */
WITH cogs AS (
  SELECT SUM(oi.quantity * p.cost_price) AS total_cogs
  FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  JOIN products.products p ON p.product_id = oi.prod_id
  WHERE o.order_status NOT IN ('Cancelled', 'Failed')
    AND o.order_date >= (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '12 months'
),
avg_inv AS (
  SELECT AVG(i.quantity_on_hand * p.cost_price) AS avg_inventory_value
  FROM products.inventory i
  JOIN products.products p ON p.product_id = i.product_id
)
SELECT c.total_cogs, a.avg_inventory_value,
       ROUND(c.total_cogs / NULLIF(a.avg_inventory_value, 0), 2) AS inventory_turnover
FROM cogs c, avg_inv a;

/* Q46. */
WITH order_to_pay AS (
  SELECT o.order_id, (p.payment_date - o.order_date) AS days_to_pay
  FROM sales.orders o
  JOIN sales.payments p ON p.order_id = o.order_id
)
SELECT ROUND(AVG(days_to_pay), 2) AS avg_dso_days
FROM order_to_pay;

/* Q47. */
WITH cogs AS (
  SELECT SUM(oi.quantity * p.cost_price) AS total_cogs
  FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  JOIN products.products p ON p.product_id = oi.prod_id
  WHERE o.order_status NOT IN ('Cancelled', 'Failed')
    AND o.order_date >= (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '12 months'
),
avg_inv AS (
  SELECT AVG(i.quantity_on_hand * p.cost_price) AS avg_inventory_value
  FROM products.inventory i
  JOIN products.products p ON p.product_id = i.product_id
)
SELECT ROUND(365.0 / NULLIF(c.total_cogs / NULLIF(a.avg_inventory_value, 0), 0), 2) AS avg_dio_days
FROM cogs c, avg_inv a;

/* Q48. */
WITH item_econ AS (
  SELECT oi.net_amount, oi.quantity * p.cost_price AS item_cost
  FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  JOIN products.products p ON p.product_id = oi.prod_id
  WHERE o.order_status NOT IN ('Cancelled', 'Failed')
)
SELECT SUM(net_amount) AS revenue, SUM(item_cost) AS cogs,
       ROUND(100.0 * (SUM(net_amount) - SUM(item_cost)) / NULLIF(SUM(net_amount), 0), 2) AS gross_margin_pct
FROM item_econ;

/* Q49. */
WITH revenue AS (
  SELECT SUM(net_total) AS total_revenue FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed')
),
cogs AS (
  SELECT SUM(oi.quantity * p.cost_price) AS total_cogs
  FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  JOIN products.products p ON p.product_id = oi.prod_id
  WHERE o.order_status NOT IN ('Cancelled', 'Failed')
),
expenses AS (
  SELECT SUM(amount) AS total_expenses FROM finance.expenses
)
SELECT r.total_revenue, c.total_cogs, e.total_expenses,
       ROUND(100.0 * (r.total_revenue - c.total_cogs - e.total_expenses) / NULLIF(r.total_revenue, 0), 2) AS net_margin_pct
FROM revenue r, cogs c, expenses e;

/* Q50. */
WITH revenue AS (
  SELECT SUM(net_total) AS total_revenue FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed')
),
cogs AS (
  SELECT SUM(oi.quantity * p.cost_price) AS total_cogs
  FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  JOIN products.products p ON p.product_id = oi.prod_id
  WHERE o.order_status NOT IN ('Cancelled', 'Failed')
),
opex AS (
  SELECT SUM(amount) AS total_opex FROM stores.expenses
)
SELECT r.total_revenue, c.total_cogs, o.total_opex,
       ROUND(100.0 * (r.total_revenue - c.total_cogs - o.total_opex) / NULLIF(r.total_revenue, 0), 2) AS operating_margin_pct
FROM revenue r, cogs c, opex o;

/* SECTION C: COHORT & FUNNEL REPORTS (25) */

/* Q51. */
WITH cohorts AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date) AS cohort_month
  FROM customers.customers
),
cohort_size AS (
  SELECT cohort_month, COUNT(*) AS customers
  FROM cohorts
  GROUP BY cohort_month
),
active_next_month AS (
  SELECT c.cohort_month, COUNT(DISTINCT o.cust_id) AS active_customers
  FROM cohorts c
  JOIN sales.orders o ON o.cust_id = c.customer_id
    AND DATE_TRUNC('month', o.order_date) = c.cohort_month + INTERVAL '1 month'
  GROUP BY c.cohort_month
)
SELECT s.cohort_month, s.customers, COALESCE(a.active_customers, 0) AS retained_month_1,
       ROUND(100.0 * COALESCE(a.active_customers, 0) / s.customers, 2) AS retention_pct
FROM cohort_size s
LEFT JOIN active_next_month a ON a.cohort_month = s.cohort_month
ORDER BY s.cohort_month;

/* Q52. */
WITH first_order AS (
  SELECT cust_id, MIN(DATE_TRUNC('month', order_date)) AS cohort_month
  FROM sales.orders
  GROUP BY cust_id
),
cohort_size AS (
  SELECT cohort_month, COUNT(*) AS customers
  FROM first_order
  GROUP BY cohort_month
),
active_next_month AS (
  SELECT f.cohort_month, COUNT(DISTINCT o.cust_id) AS active_customers
  FROM first_order f
  JOIN sales.orders o ON o.cust_id = f.cust_id
    AND DATE_TRUNC('month', o.order_date) = f.cohort_month + INTERVAL '1 month'
  GROUP BY f.cohort_month
)
SELECT s.cohort_month, s.customers, COALESCE(a.active_customers, 0) AS retained_month_1,
       ROUND(100.0 * COALESCE(a.active_customers, 0) / s.customers, 2) AS retention_pct
FROM cohort_size s
LEFT JOIN active_next_month a ON a.cohort_month = s.cohort_month
ORDER BY s.cohort_month;

/* Q53. */
WITH cohorts AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date) AS cohort_month
  FROM customers.customers
),
customer_spend AS (
  SELECT cust_id, SUM(net_total) AS total_spend
  FROM sales.orders
  WHERE order_status NOT IN ('Cancelled', 'Failed')
  GROUP BY cust_id
)
SELECT c.cohort_month, ROUND(AVG(COALESCE(s.total_spend, 0)), 2) AS avg_cohort_ltv
FROM cohorts c
LEFT JOIN customer_spend s ON s.cust_id = c.customer_id
GROUP BY c.cohort_month
ORDER BY c.cohort_month;

/* Q54. */
WITH cohorts AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date) AS cohort_month
  FROM customers.customers
),
recent_orders AS (
  SELECT DISTINCT cust_id
  FROM sales.orders
  WHERE order_date >= (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '6 months'
)
SELECT c.cohort_month, COUNT(*) AS cohort_size,
       COUNT(*) FILTER (WHERE r.cust_id IS NULL) AS churned,
       ROUND(100.0 * COUNT(*) FILTER (WHERE r.cust_id IS NULL) / COUNT(*), 2) AS churn_rate_pct
FROM cohorts c
LEFT JOIN recent_orders r ON r.cust_id = c.customer_id
GROUP BY c.cohort_month
ORDER BY c.cohort_month;

/* Q55. */
WITH gaps AS (
  SELECT cust_id, order_date,
         order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date) AS gap
  FROM sales.orders
)
SELECT COUNT(DISTINCT cust_id) AS customers_with_winback
FROM gaps
WHERE gap > 180;

/* Q56. */
WITH gaps AS (
  SELECT cust_id, order_date,
         order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date) AS gap
  FROM sales.orders
)
SELECT DATE_TRUNC('month', order_date) AS reactivation_month, COUNT(DISTINCT cust_id) AS reactivated_customers
FROM gaps
WHERE gap > 90
GROUP BY 1
ORDER BY 1;

/* Q57. */
WITH visitors AS (
  SELECT COUNT(DISTINCT session_id) AS total_sessions
  FROM web_events.page_views
),
signups AS (
  SELECT COUNT(*) AS total_customers FROM customers.customers
)
SELECT v.total_sessions, s.total_customers,
       ROUND(100.0 * s.total_customers / NULLIF(v.total_sessions, 0), 2) AS visitor_to_signup_pct
FROM visitors v, signups s;

/* Q58. */
WITH signups AS (
  SELECT COUNT(*) AS total_customers FROM customers.customers
),
buyers AS (
  SELECT COUNT(DISTINCT cust_id) AS customers_with_order FROM sales.orders
)
SELECT s.total_customers, b.customers_with_order,
       ROUND(100.0 * b.customers_with_order / NULLIF(s.total_customers, 0), 2) AS signup_to_order_pct
FROM signups s, buyers b;

/* Q59. */
WITH clicks AS (
  SELECT COUNT(DISTINCT view_id) AS cart_clicks FROM web_events.events WHERE event_type = 'click'
),
orders AS (
  SELECT COUNT(*) AS checkouts FROM sales.orders
),
paid AS (
  SELECT COUNT(DISTINCT order_id) AS paid_orders FROM sales.payments
)
SELECT c.cart_clicks, o.checkouts, p.paid_orders
FROM clicks c, orders o, paid p;

/* Q60. */
SELECT c.campaign_id, c.campaign_name,
       COUNT(o.order_id) AS orders_during_campaign,
       ROUND(SUM(o.net_total), 2) AS revenue_during_campaign
FROM marketing.campaigns c
LEFT JOIN sales.orders o ON o.order_date BETWEEN c.start_date AND c.end_date
  AND o.order_status NOT IN ('Cancelled', 'Failed')
GROUP BY c.campaign_id, c.campaign_name
ORDER BY orders_during_campaign DESC
LIMIT 20;

/* Q61. */
SELECT SUM(emails_sent) AS sent, SUM(emails_opened) AS opened, SUM(emails_clicked) AS clicked,
       ROUND(100.0 * SUM(emails_opened) / NULLIF(SUM(emails_sent), 0), 2) AS open_rate_pct,
       ROUND(100.0 * SUM(emails_clicked) / NULLIF(SUM(emails_opened), 0), 2) AS click_through_rate_pct
FROM marketing.email_clicks;

/* Q62. */
SELECT order_status, COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM sales.orders
GROUP BY order_status
ORDER BY orders DESC;

/* Q63. */
SELECT status, COUNT(*) AS tickets,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM support.tickets
GROUP BY status
ORDER BY tickets DESC;

/* Q64. */
WITH signups AS (SELECT COUNT(*) AS n FROM customers.customers),
first_order AS (SELECT COUNT(DISTINCT cust_id) AS n FROM sales.orders),
first_review AS (SELECT COUNT(DISTINCT customer_id) AS n FROM customers.reviews)
SELECT s.n AS signed_up, f.n AS ordered, r.n AS reviewed
FROM signups s, first_order f, first_review r;

/* Q65. */
WITH order_ranks AS (
  SELECT cust_id, ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date) AS rn
  FROM sales.orders
)
SELECT COUNT(DISTINCT cust_id) FILTER (WHERE rn = 1) AS first_order_customers,
       COUNT(DISTINCT cust_id) FILTER (WHERE rn = 2) AS second_order_customers
FROM order_ranks;

/* Q66. */
WITH order_counts AS (
  SELECT cust_id, COUNT(*) AS orders
  FROM sales.orders
  GROUP BY cust_id
)
SELECT COUNT(*) FILTER (WHERE orders = 1) AS one_time_customers,
       COUNT(*) AS total_customers_with_orders,
       ROUND(100.0 * COUNT(*) FILTER (WHERE orders = 1) / COUNT(*), 2) AS one_and_done_pct
FROM order_counts;

/* Q67. */
SELECT ROUND(AVG(s.shipped_date - o.order_date), 2) AS avg_days_order_to_ship,
       ROUND(AVG(s.delivered_date - s.shipped_date), 2) AS avg_days_ship_to_deliver
FROM sales.orders o
JOIN sales.shipments s ON s.order_id = o.order_id
WHERE s.delivered_date IS NOT NULL;

/* Q68. */
SELECT courier_name, ROUND(AVG(delivered_date - shipped_date), 2) AS avg_delivery_days, COUNT(*) AS shipments
FROM sales.shipments
WHERE delivered_date IS NOT NULL
GROUP BY courier_name
ORDER BY avg_delivery_days DESC;

/* Q69. */
WITH cohort_size AS (
  SELECT DATE_TRUNC('month', registration_date) AS cohort_month, COUNT(*) AS customers
  FROM customers.customers
  GROUP BY 1
)
SELECT ROUND(AVG(customers), 2) AS avg_cohort_size, ROUND(STDDEV(customers), 2) AS stddev_cohort_size
FROM cohort_size;

/* Q70. */
WITH cohorts AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date) AS cohort_month
  FROM customers.customers
),
cohort_size AS (
  SELECT cohort_month, COUNT(*) AS customers FROM cohorts GROUP BY cohort_month
),
monthly_activity AS (
  SELECT c.cohort_month,
         DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), c.cohort_month)) AS months_since_signup,
         COUNT(DISTINCT o.cust_id) AS active_customers
  FROM cohorts c
  JOIN sales.orders o ON o.cust_id = c.customer_id
  GROUP BY c.cohort_month, 2
)
SELECT m.cohort_month, m.months_since_signup, m.active_customers, s.customers,
       ROUND(100.0 * m.active_customers / s.customers, 2) AS retention_pct
FROM monthly_activity m
JOIN cohort_size s ON s.cohort_month = m.cohort_month
WHERE m.months_since_signup BETWEEN 0 AND 3
ORDER BY m.cohort_month, m.months_since_signup;

/* Q71. */
WITH daily AS (
  SELECT AVG(daily_active) AS avg_dau FROM (
    SELECT view_timestamp::date AS d, COUNT(DISTINCT customer_id) AS daily_active
    FROM web_events.page_views
    WHERE customer_id IS NOT NULL
    GROUP BY 1
  ) x
),
monthly AS (
  SELECT AVG(monthly_active) AS avg_mau FROM (
    SELECT DATE_TRUNC('month', view_timestamp) AS m, COUNT(DISTINCT customer_id) AS monthly_active
    FROM web_events.page_views
    WHERE customer_id IS NOT NULL
    GROUP BY 1
  ) y
)
SELECT ROUND(d.avg_dau, 2) AS avg_dau, ROUND(m.avg_mau, 2) AS avg_mau,
       ROUND(100.0 * d.avg_dau / NULLIF(m.avg_mau, 0), 2) AS stickiness_pct
FROM daily d, monthly m;

/* Q72. */
SELECT ROUND(AVG(view_count), 2) AS avg_views_per_session
FROM (
  SELECT session_id, COUNT(*) AS view_count
  FROM web_events.page_views
  GROUP BY session_id
) x;

/* Q73. */
WITH gaps AS (
  SELECT cust_id,
         ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date) AS order_seq,
         order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date) AS gap_days
  FROM sales.orders
)
SELECT order_seq, ROUND(AVG(gap_days), 2) AS avg_gap_days
FROM gaps
WHERE gap_days IS NOT NULL
GROUP BY order_seq
ORDER BY order_seq
LIMIT 10;

/* Q74. */
WITH gaps AS (
  SELECT cust_id, order_date,
         order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date) AS gap
  FROM sales.orders
)
SELECT COUNT(DISTINCT cust_id) AS reactivated_last_month
FROM gaps
WHERE gap > 90
  AND DATE_TRUNC('month', order_date) = DATE_TRUNC('month', (SELECT MAX(order_date) FROM sales.orders));

/* Q75. */
WITH cohorts AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date) AS cohort_month
  FROM customers.customers
)
SELECT c.cohort_month, ROUND(SUM(o.net_total), 2) AS cohort_revenue
FROM cohorts c
JOIN sales.orders o ON o.cust_id = c.customer_id AND o.order_status NOT IN ('Cancelled', 'Failed')
GROUP BY c.cohort_month
ORDER BY c.cohort_month;

/* SECTION D: DASHBOARDS (25) */

/* Q76. */
WITH rev AS (SELECT SUM(net_total) AS total_revenue, COUNT(*) AS total_orders FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed')),
cust AS (SELECT COUNT(*) AS total_customers FROM customers.customers)
SELECT rev.total_revenue, rev.total_orders, cust.total_customers,
       ROUND(rev.total_revenue / NULLIF(rev.total_orders, 0), 2) AS aov
FROM rev, cust;

/* Q77. */
SELECT s.store_id, s.store_name, COUNT(o.order_id) AS orders,
       ROUND(SUM(o.net_total), 2) AS revenue,
       ROUND(AVG(o.net_total), 2) AS aov
FROM stores.stores s
JOIN sales.orders o ON o.store_id = s.store_id AND o.order_status NOT IN ('Cancelled', 'Failed')
GROUP BY s.store_id, s.store_name
ORDER BY revenue DESC
LIMIT 20;

/* Q78. */
WITH spend AS (
  SELECT platform, SUM(amount) AS spend FROM marketing.ads_spend GROUP BY platform
)
SELECT platform, spend
FROM spend
ORDER BY spend DESC;

/* Q79. */
SELECT courier_name, COUNT(*) AS shipments,
       ROUND(100.0 * COUNT(*) FILTER (WHERE delivered_date - shipped_date <= 3) / COUNT(*) FILTER (WHERE delivered_date IS NOT NULL), 2) AS on_time_pct
FROM sales.shipments
GROUP BY courier_name
ORDER BY shipments DESC;

/* Q80. */
SELECT priority, status, COUNT(*) AS tickets
FROM support.tickets
GROUP BY priority, status
ORDER BY priority, status;

/* Q81. */
SELECT d.dept_name, COUNT(e.employee_id) AS headcount, ROUND(AVG(e.salary), 2) AS avg_salary
FROM core.dim_department d
JOIN stores.employees e ON e.dept_id = d.dept_id
GROUP BY d.dept_name
ORDER BY headcount DESC;

/* Q82. */
WITH monthly_rev AS (
  SELECT DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS revenue
  FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed')
  GROUP BY 1
),
monthly_exp AS (
  SELECT DATE_TRUNC('month', expense_date) AS month, SUM(amount) AS expenses
  FROM finance.expenses
  GROUP BY 1
)
SELECT r.month, r.revenue, COALESCE(e.expenses, 0) AS expenses,
       ROUND(r.revenue - COALESCE(e.expenses, 0), 2) AS net_income
FROM monthly_rev r
LEFT JOIN monthly_exp e ON e.month = r.month
ORDER BY r.month;

/* Q83. */
SELECT st.store_name, p.product_name, i.quantity_on_hand, i.reorder_level
FROM products.inventory i
JOIN stores.stores st ON st.store_id = i.store_id
JOIN products.products p ON p.product_id = i.product_id
WHERE i.quantity_on_hand < i.reorder_level
ORDER BY (i.reorder_level - i.quantity_on_hand) DESC
LIMIT 30;

/* Q84. */
SELECT w.name AS warehouse_name, s.status, COUNT(*) AS shipments
FROM supply_chain.shipments s
JOIN supply_chain.warehouses w ON w.warehouse_id = s.warehouse_id
GROUP BY w.name, s.status
ORDER BY w.name, shipments DESC;

/* Q85. */
SELECT payment_mode, COUNT(*) AS payments, ROUND(SUM(amount), 2) AS total_amount
FROM sales.payments
GROUP BY payment_mode
ORDER BY total_amount DESC;

/* Q86. */
SELECT a.state, COUNT(DISTINCT o.order_id) AS orders, ROUND(SUM(o.net_total), 2) AS revenue
FROM sales.orders o
JOIN customers.addresses a ON a.customer_id = o.cust_id AND a.is_default = true
WHERE o.order_status NOT IN ('Cancelled', 'Failed')
GROUP BY a.state
ORDER BY revenue DESC
LIMIT 20;

/* Q87. */
SELECT t.tier_name, COUNT(m.customer_id) AS members, ROUND(AVG(m.points_balance), 2) AS avg_points
FROM loyalty.tiers t
JOIN loyalty.members m ON m.tier_id = t.tier_id
GROUP BY t.tier_name
ORDER BY avg_points DESC;

/* Q88. */
SELECT device_type, COUNT(*) AS page_views, COUNT(DISTINCT session_id) AS sessions
FROM web_events.page_views
GROUP BY device_type
ORDER BY page_views DESC;

/* Q89. */
WITH order_ranks AS (
  SELECT order_id, cust_id, ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date) AS rn
  FROM sales.orders
)
SELECT CASE WHEN rn = 1 THEN 'new' ELSE 'returning' END AS customer_type, COUNT(*) AS orders
FROM order_ranks
GROUP BY 1;

/* Q90. */
WITH active_months AS (
  SELECT cust_id, COUNT(DISTINCT DATE_TRUNC('month', order_date)) AS months_active
  FROM sales.orders
  GROUP BY cust_id
)
SELECT COUNT(*) FILTER (WHERE months_active >= 3) AS recurring_like_customers,
       COUNT(*) AS total_customers_with_orders
FROM active_months;

/* Q91. */
SELECT o.order_id, o.net_total, SUM(r.refund_amount) AS total_refunded
FROM sales.orders o
JOIN sales.returns r ON r.order_id = o.order_id
GROUP BY o.order_id, o.net_total
HAVING SUM(r.refund_amount) > o.net_total
ORDER BY total_refunded DESC
LIMIT 20;

/* Q92. */
SELECT COUNT(*) AS orders_without_payment
FROM sales.orders o
WHERE NOT EXISTS (SELECT 1 FROM sales.payments p WHERE p.order_id = o.order_id);

/* Q93. */
SELECT priority,
       ROUND(AVG(EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600), 2) AS avg_resolution_hours,
       ROUND(100.0 * COUNT(*) FILTER (WHERE resolved_date - created_date <= INTERVAL '48 hours') / COUNT(*), 2) AS sla_pct
FROM support.tickets
WHERE resolved_date IS NOT NULL
GROUP BY priority
ORDER BY priority;

/* Q94. */
WITH reviews AS (SELECT COUNT(*) AS n FROM customers.reviews),
tickets AS (SELECT COUNT(*) AS n FROM support.tickets),
custs AS (SELECT COUNT(*) AS n FROM customers.customers)
SELECT ROUND(reviews.n::numeric / custs.n, 3) AS avg_reviews_per_customer,
       ROUND(tickets.n::numeric / custs.n, 3) AS avg_tickets_per_customer
FROM reviews, tickets, custs;

/* Q95. */
WITH cohorts AS (
  SELECT customer_id, DATE_PART('year', registration_date) AS signup_year
  FROM customers.customers
)
SELECT c.signup_year, COUNT(DISTINCT c.customer_id) AS customers,
       ROUND(SUM(o.net_total), 2) AS revenue
FROM cohorts c
LEFT JOIN sales.orders o ON o.cust_id = c.customer_id AND o.order_status NOT IN ('Cancelled', 'Failed')
GROUP BY c.signup_year
ORDER BY c.signup_year;

/* Q96. */
WITH daily AS (
  SELECT order_date, COUNT(*) AS orders
  FROM sales.orders
  GROUP BY order_date
),
avg_daily AS (
  SELECT AVG(orders) AS avg_orders FROM daily
)
SELECT d.order_date, d.orders
FROM daily d, avg_daily a
WHERE d.orders > 2 * a.avg_orders
ORDER BY d.orders DESC
LIMIT 20;

/* Q97. */
SELECT e.employee_id, e.first_name, e.last_name, e.store_id, ROUND(SUM(o.net_total), 2) AS store_revenue
FROM stores.employees e
JOIN sales.orders o ON o.store_id = e.store_id AND o.order_status NOT IN ('Cancelled', 'Failed')
GROUP BY e.employee_id, e.first_name, e.last_name, e.store_id
ORDER BY store_revenue DESC
LIMIT 10;

/* Q98. */
WITH refund AS (
  SELECT (SELECT SUM(refund_amount) FROM sales.returns) AS refunds,
         (SELECT SUM(net_total) FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed')) AS revenue
),
cancel AS (
  SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE order_status = 'Cancelled') / COUNT(*), 2) AS cancel_pct FROM sales.orders
),
sla AS (
  SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE resolved_date - created_date <= INTERVAL '48 hours') / COUNT(*), 2) AS sla_pct
  FROM support.tickets WHERE resolved_date IS NOT NULL
)
SELECT ROUND(100.0 * refund.refunds / NULLIF(refund.revenue, 0), 2) AS refund_rate_pct,
       cancel.cancel_pct, sla.sla_pct
FROM refund, cancel, sla;

/* Q99. */
SELECT b.brand_name, ROUND(AVG(r.rating), 2) AS avg_rating,
       COUNT(*) FILTER (WHERE r.rating <= 2) AS low_ratings,
       COUNT(*) AS total_reviews
FROM customers.reviews r
JOIN products.products p ON p.product_id = r.product_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
GROUP BY b.brand_name
ORDER BY total_reviews DESC
LIMIT 20;

/* Q100. */
WITH rev AS (SELECT SUM(net_total) AS total_revenue, COUNT(*) AS total_orders FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed')),
cust AS (SELECT COUNT(*) AS total_customers FROM customers.customers),
refund AS (SELECT SUM(refund_amount) AS total_refunds FROM sales.returns),
cancel AS (SELECT COUNT(*) FILTER (WHERE order_status = 'Cancelled') AS cancelled, COUNT(*) AS all_orders FROM sales.orders)
SELECT rev.total_revenue, rev.total_orders, cust.total_customers,
       ROUND(rev.total_revenue / NULLIF(rev.total_orders, 0), 2) AS aov,
       ROUND(100.0 * refund.total_refunds / NULLIF(rev.total_revenue, 0), 2) AS refund_rate_pct,
       ROUND(100.0 * cancel.cancelled / NULLIF(cancel.all_orders, 0), 2) AS cancellation_rate_pct
FROM rev, cust, refund, cancel;

/* ============================================================
   END OF ANSWER KEY - EASY LEVEL (100/100)
============================================================ */
