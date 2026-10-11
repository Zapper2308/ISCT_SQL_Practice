/* ============================================================
   ANSWER KEY - Subqueries + CTEs Combined (MEDIUM LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* SECTION A: COHORT DEEP (25) */

/* Q1. */
WITH cohorts AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date) AS cohort_month
  FROM customers.customers
),
cohort_size AS (
  SELECT cohort_month, COUNT(*) AS customers FROM cohorts GROUP BY cohort_month
),
activity AS (
  SELECT c.cohort_month,
         (DATE_PART('year', o.order_date) - DATE_PART('year', c.cohort_month)) * 12
           + (DATE_PART('month', o.order_date) - DATE_PART('month', c.cohort_month)) AS month_offset,
         COUNT(DISTINCT o.cust_id) AS active_customers
  FROM cohorts c
  JOIN sales.orders o ON o.cust_id = c.customer_id
  GROUP BY c.cohort_month, 2
)
SELECT a.cohort_month, a.month_offset, a.active_customers, s.customers,
       ROUND(100.0 * a.active_customers / s.customers, 2) AS retention_pct
FROM activity a
JOIN cohort_size s ON s.cohort_month = a.cohort_month
WHERE a.month_offset BETWEEN 0 AND 6
ORDER BY a.cohort_month, a.month_offset;

/* Q2. */
WITH first_order AS (
  SELECT cust_id, MIN(DATE_TRUNC('month', order_date)) AS cohort_month
  FROM sales.orders
  GROUP BY cust_id
),
cohort_size AS (
  SELECT cohort_month, COUNT(*) AS customers FROM first_order GROUP BY cohort_month
),
activity AS (
  SELECT f.cohort_month,
         (DATE_PART('year', o.order_date) - DATE_PART('year', f.cohort_month)) * 12
           + (DATE_PART('month', o.order_date) - DATE_PART('month', f.cohort_month)) AS month_offset,
         COUNT(DISTINCT o.cust_id) AS active_customers
  FROM first_order f
  JOIN sales.orders o ON o.cust_id = f.cust_id
  GROUP BY f.cohort_month, 2
)
SELECT a.cohort_month, a.month_offset, a.active_customers, s.customers,
       ROUND(100.0 * a.active_customers / s.customers, 2) AS retention_pct
FROM activity a
JOIN cohort_size s ON s.cohort_month = a.cohort_month
WHERE a.month_offset BETWEEN 0 AND 6
ORDER BY a.cohort_month, a.month_offset;

/* Q3. */
WITH first_order AS (
  SELECT cust_id, MIN(DATE_TRUNC('month', order_date)) AS cohort_month
  FROM sales.orders
  GROUP BY cust_id
),
cohort_size AS (
  SELECT cohort_month, COUNT(*) AS customers FROM first_order GROUP BY cohort_month
),
revenue_by_offset AS (
  SELECT f.cohort_month,
         (DATE_PART('year', o.order_date) - DATE_PART('year', f.cohort_month)) * 12
           + (DATE_PART('month', o.order_date) - DATE_PART('month', f.cohort_month)) AS month_offset,
         SUM(o.net_total) AS revenue
  FROM first_order f
  JOIN sales.orders o ON o.cust_id = f.cust_id
  WHERE o.order_status NOT IN ('Cancelled', 'Failed')
  GROUP BY f.cohort_month, 2
)
SELECT r.cohort_month, r.month_offset, ROUND(r.revenue / s.customers, 2) AS avg_ltv_at_offset
FROM revenue_by_offset r
JOIN cohort_size s ON s.cohort_month = r.cohort_month
WHERE r.month_offset BETWEEN 0 AND 6
ORDER BY r.cohort_month, r.month_offset;

/* Q4. */
WITH cohorts AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date) AS cohort_month
  FROM customers.customers
)
SELECT c.cohort_month, ROUND(SUM(o.net_total), 2) AS cohort_revenue
FROM cohorts c
JOIN sales.orders o ON o.cust_id = c.customer_id AND o.order_status NOT IN ('Cancelled', 'Failed')
GROUP BY c.cohort_month
ORDER BY c.cohort_month;

/* Q5. */
WITH cohorts AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date) AS cohort_month
  FROM customers.customers
)
SELECT c.cohort_month, COUNT(o.order_id) AS cohort_orders
FROM cohorts c
JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY c.cohort_month
ORDER BY c.cohort_month;

/* Q6. */
WITH customer_device AS (
  SELECT customer_id,
         MODE() WITHIN GROUP (ORDER BY device_type) AS primary_device
  FROM web_events.page_views
  WHERE customer_id IS NOT NULL
  GROUP BY customer_id
)
SELECT DATE_TRUNC('month', c.registration_date) AS cohort_month,
       COALESCE(d.primary_device, 'Unknown') AS channel,
       COUNT(*) AS customers
FROM customers.customers c
LEFT JOIN customer_device d ON d.customer_id = c.customer_id
GROUP BY 1, 2
ORDER BY 1, 2;

/* Q7. */
WITH first_order AS (
  SELECT cust_id, MIN(order_date) AS first_order_date
  FROM sales.orders
  GROUP BY cust_id
)
SELECT camp.campaign_id, camp.campaign_name,
       DATE_TRUNC('month', f.first_order_date) AS cohort_month,
       COUNT(*) AS customers
FROM first_order f
JOIN marketing.campaigns camp ON f.first_order_date BETWEEN camp.start_date AND camp.end_date
GROUP BY camp.campaign_id, camp.campaign_name, DATE_TRUNC('month', f.first_order_date)
ORDER BY customers DESC
LIMIT 20;

/* Q8. */
WITH cust_region AS (
  SELECT c.customer_id, DATE_TRUNC('month', c.registration_date) AS cohort_month, r.region_name
  FROM customers.customers c
  LEFT JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = true
  LEFT JOIN core.dim_region r ON r.state = a.state
)
SELECT cohort_month, COALESCE(region_name, 'Unknown') AS region_name, COUNT(*) AS customers
FROM cust_region
GROUP BY cohort_month, region_name
ORDER BY cohort_month, customers DESC;

/* Q9. */
SELECT DATE_TRUNC('month', registration_date) AS cohort_month, tier, COUNT(*) AS customers
FROM customers.customers
GROUP BY 1, 2
ORDER BY 1, 2;

/* Q10. */
WITH customer_device AS (
  SELECT customer_id, MODE() WITHIN GROUP (ORDER BY device_type) AS primary_device
  FROM web_events.page_views
  WHERE customer_id IS NOT NULL
  GROUP BY customer_id
)
SELECT DATE_TRUNC('month', c.registration_date) AS cohort_month,
       COALESCE(d.primary_device, 'Unknown') AS device,
       COUNT(*) AS customers
FROM customers.customers c
LEFT JOIN customer_device d ON d.customer_id = c.customer_id
GROUP BY 1, 2
ORDER BY 1, 2;

/* Q11. */
WITH cohort_month_spend AS (
  SELECT DATE_TRUNC('month', spend_date) AS month, platform, SUM(amount) AS spend
  FROM marketing.ads_spend
  GROUP BY 1, 2
),
cohort_size AS (
  SELECT DATE_TRUNC('month', registration_date) AS cohort_month, COUNT(*) AS customers
  FROM customers.customers
  GROUP BY 1
)
SELECT s.cohort_month, m.platform, m.spend, s.customers
FROM cohort_size s
LEFT JOIN cohort_month_spend m ON m.month = s.cohort_month
ORDER BY s.cohort_month, m.spend DESC NULLS LAST;

/* Q12. */
WITH cohorts AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date) AS cohort_month
  FROM customers.customers
),
cohort_size AS (
  SELECT cohort_month, COUNT(*) AS customers FROM cohorts GROUP BY cohort_month
),
activity AS (
  SELECT c.cohort_month,
         (DATE_PART('year', o.order_date) - DATE_PART('year', c.cohort_month)) * 12
           + (DATE_PART('month', o.order_date) - DATE_PART('month', c.cohort_month)) AS month_offset,
         COUNT(DISTINCT o.cust_id) AS active_customers
  FROM cohorts c
  JOIN sales.orders o ON o.cust_id = c.customer_id
  GROUP BY c.cohort_month, 2
)
SELECT a.month_offset, ROUND(AVG(100.0 * a.active_customers / s.customers), 2) AS avg_retention_pct
FROM activity a
JOIN cohort_size s ON s.cohort_month = a.cohort_month
WHERE a.month_offset BETWEEN 0 AND 6
GROUP BY a.month_offset
ORDER BY a.month_offset;

/* Q13. */
WITH cohorts AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date) AS cohort_month
  FROM customers.customers
),
activity AS (
  SELECT c.cohort_month,
         (DATE_PART('year', o.order_date) - DATE_PART('year', c.cohort_month)) * 12
           + (DATE_PART('month', o.order_date) - DATE_PART('month', c.cohort_month)) AS month_offset,
         COUNT(DISTINCT o.cust_id) AS active_customers
  FROM cohorts c
  JOIN sales.orders o ON o.cust_id = c.customer_id
  GROUP BY c.cohort_month, 2
),
with_prev AS (
  SELECT cohort_month, month_offset, active_customers,
         LAG(active_customers) OVER (PARTITION BY cohort_month ORDER BY month_offset) AS prev_active
  FROM activity
)
SELECT cohort_month, month_offset, active_customers, prev_active,
       ROUND(100.0 * (prev_active - active_customers) / NULLIF(prev_active, 0), 2) AS dropoff_pct
FROM with_prev
WHERE prev_active IS NOT NULL AND month_offset BETWEEN 0 AND 6
ORDER BY cohort_month, month_offset;

/* Q14. */
WITH first_order AS (
  SELECT cust_id, MIN(DATE_TRUNC('month', order_date)) AS cohort_month
  FROM sales.orders
  GROUP BY cust_id
),
revenue_by_offset AS (
  SELECT f.cohort_month,
         (DATE_PART('year', o.order_date) - DATE_PART('year', f.cohort_month)) * 12
           + (DATE_PART('month', o.order_date) - DATE_PART('month', f.cohort_month)) AS month_offset,
         SUM(o.net_total) AS revenue
  FROM first_order f
  JOIN sales.orders o ON o.cust_id = f.cust_id
  WHERE o.order_status NOT IN ('Cancelled', 'Failed')
  GROUP BY f.cohort_month, 2
)
SELECT cohort_month, month_offset,
       SUM(revenue) OVER (PARTITION BY cohort_month ORDER BY month_offset) AS cumulative_revenue
FROM revenue_by_offset
WHERE month_offset BETWEEN 0 AND 6
ORDER BY cohort_month, month_offset;

/* Q15. */
WITH cohorts AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date) AS cohort_month
  FROM customers.customers
),
recent_orders AS (
  SELECT DISTINCT cust_id
  FROM sales.orders
  WHERE order_date >= (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '90 days'
)
SELECT c.cohort_month, COUNT(*) AS cohort_size,
       ROUND(100.0 * COUNT(*) FILTER (WHERE r.cust_id IS NULL) / COUNT(*), 2) AS churn_rate_pct
FROM cohorts c
LEFT JOIN recent_orders r ON r.cust_id = c.customer_id
GROUP BY c.cohort_month
ORDER BY c.cohort_month;

/* Q16. */
WITH cohorts AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date) AS cohort_month
  FROM customers.customers
),
gaps AS (
  SELECT cust_id, order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date) AS gap
  FROM sales.orders
),
reactivated AS (
  SELECT DISTINCT cust_id FROM gaps WHERE gap > 90
)
SELECT c.cohort_month, COUNT(*) AS cohort_size,
       COUNT(r.cust_id) AS reactivated_customers,
       ROUND(100.0 * COUNT(r.cust_id) / COUNT(*), 2) AS reactivation_pct
FROM cohorts c
LEFT JOIN reactivated r ON r.cust_id = c.customer_id
GROUP BY c.cohort_month
ORDER BY c.cohort_month;

/* Q17. */
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
SELECT c.cohort_month, ROUND(AVG(COALESCE(s.total_spend, 0)), 2) AS revenue_per_cohort_customer
FROM cohorts c
LEFT JOIN customer_spend s ON s.cust_id = c.customer_id
GROUP BY c.cohort_month
ORDER BY c.cohort_month;

/* Q18. */
WITH cohorts AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date) AS cohort_month
  FROM customers.customers
)
SELECT c.cohort_month, ROUND(AVG(o.net_total), 2) AS cohort_aov
FROM cohorts c
JOIN sales.orders o ON o.cust_id = c.customer_id AND o.order_status NOT IN ('Cancelled', 'Failed')
GROUP BY c.cohort_month
ORDER BY c.cohort_month;

/* Q19. */
WITH cohorts AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date) AS cohort_month
  FROM customers.customers
),
order_counts AS (
  SELECT cust_id, COUNT(*) AS orders FROM sales.orders GROUP BY cust_id
)
SELECT c.cohort_month, ROUND(AVG(COALESCE(o.orders, 0)), 2) AS avg_orders_per_customer
FROM cohorts c
LEFT JOIN order_counts o ON o.cust_id = c.customer_id
GROUP BY c.cohort_month
ORDER BY c.cohort_month;

/* Q20. */
WITH cohorts AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date) AS cohort_month
  FROM customers.customers
),
last_order AS (
  SELECT cust_id, MAX(order_date) AS last_order_date FROM sales.orders GROUP BY cust_id
)
SELECT c.cohort_month,
       ROUND(AVG((SELECT MAX(order_date) FROM sales.orders) - l.last_order_date), 2) AS avg_recency_days
FROM cohorts c
JOIN last_order l ON l.cust_id = c.customer_id
GROUP BY c.cohort_month
ORDER BY c.cohort_month;

/* Q21. */
WITH cohorts AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date) AS cohort_month
  FROM customers.customers
),
orders AS (SELECT cust_id, COUNT(*) AS n FROM sales.orders GROUP BY cust_id),
reviews AS (SELECT customer_id, COUNT(*) AS n FROM customers.reviews GROUP BY customer_id),
tickets AS (SELECT customer_id, COUNT(*) AS n FROM support.tickets GROUP BY customer_id)
SELECT c.cohort_month,
       ROUND(AVG(COALESCE(o.n, 0) + COALESCE(r.n, 0) + COALESCE(t.n, 0)), 2) AS avg_engagement_score
FROM cohorts c
LEFT JOIN orders o ON o.cust_id = c.customer_id
LEFT JOIN reviews r ON r.customer_id = c.customer_id
LEFT JOIN tickets t ON t.customer_id = c.customer_id
GROUP BY c.cohort_month
ORDER BY c.cohort_month;

/* Q22. */
WITH cohorts AS (
  SELECT customer_id, DATE_PART('year', registration_date) AS cohort_year, DATE_PART('month', registration_date) AS cohort_month_num
  FROM customers.customers
)
SELECT c.cohort_month_num, c.cohort_year, ROUND(SUM(o.net_total), 2) AS revenue
FROM cohorts c
JOIN sales.orders o ON o.cust_id = c.customer_id AND o.order_status NOT IN ('Cancelled', 'Failed')
GROUP BY c.cohort_month_num, c.cohort_year
ORDER BY c.cohort_month_num, c.cohort_year;

/* Q23. */
WITH cohorts AS (
  SELECT customer_id, DATE_PART('year', registration_date) AS cohort_year, DATE_PART('quarter', registration_date) AS cohort_quarter
  FROM customers.customers
)
SELECT c.cohort_quarter, c.cohort_year, ROUND(SUM(o.net_total), 2) AS revenue
FROM cohorts c
JOIN sales.orders o ON o.cust_id = c.customer_id AND o.order_status NOT IN ('Cancelled', 'Failed')
GROUP BY c.cohort_quarter, c.cohort_year
ORDER BY c.cohort_quarter, c.cohort_year;

/* Q24. */
WITH cohorts AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date) AS cohort_month
  FROM customers.customers
)
SELECT c.cohort_month,
       (DATE_PART('year', o.order_date) - DATE_PART('year', c.cohort_month)) * 12
         + (DATE_PART('month', o.order_date) - DATE_PART('month', c.cohort_month)) AS month_offset,
       COUNT(DISTINCT o.cust_id) AS active_customers
FROM cohorts c
JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY c.cohort_month, 2
ORDER BY c.cohort_month, month_offset;

/* Q25. */
WITH cohorts AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date) AS cohort_month
  FROM customers.customers
),
cohort_size AS (
  SELECT cohort_month, COUNT(*) AS customers FROM cohorts GROUP BY cohort_month
),
activity AS (
  SELECT c.cohort_month,
         (DATE_PART('year', o.order_date) - DATE_PART('year', c.cohort_month)) * 12
           + (DATE_PART('month', o.order_date) - DATE_PART('month', c.cohort_month)) AS month_offset,
         COUNT(DISTINCT o.cust_id) AS active_customers
  FROM cohorts c
  JOIN sales.orders o ON o.cust_id = c.customer_id
  GROUP BY c.cohort_month, 2
)
SELECT a.cohort_month, a.month_offset, ROUND(100.0 * a.active_customers / s.customers, 2) AS retention_pct
FROM activity a
JOIN cohort_size s ON s.cohort_month = a.cohort_month
WHERE a.month_offset BETWEEN 0 AND 6
ORDER BY a.cohort_month, a.month_offset;

/* SECTION B: FUNNEL DEEP (25) */

/* Q26. */
WITH camp_stats AS (SELECT COUNT(*) AS campaigns FROM marketing.campaigns),
clicks AS (SELECT SUM(emails_clicked) AS total_clicks FROM marketing.email_clicks),
visits AS (SELECT COUNT(DISTINCT session_id) AS total_visits FROM web_events.page_views),
signups AS (SELECT COUNT(*) AS total_signups FROM customers.customers),
orders AS (SELECT COUNT(*) AS total_orders FROM sales.orders)
SELECT camp_stats.campaigns, clicks.total_clicks, visits.total_visits, signups.total_signups, orders.total_orders
FROM camp_stats, clicks, visits, signups, orders;

/* Q27. */
SELECT
  (SELECT COUNT(DISTINCT session_id) FROM web_events.page_views) AS leads,
  COUNT(*) FILTER (WHERE order_status = 'Processing') AS opportunities,
  COUNT(*) FILTER (WHERE order_status IN ('Shipped', 'Out for Delivery')) AS quotes,
  COUNT(*) FILTER (WHERE order_status = 'Delivered') AS closed_won
FROM sales.orders;

/* Q28. */
WITH signups AS (SELECT COUNT(*) AS n FROM customers.customers),
activation AS (SELECT COUNT(DISTINCT cust_id) AS n FROM sales.orders),
first_action AS (SELECT COUNT(DISTINCT customer_id) AS n FROM customers.reviews)
SELECT signups.n AS signed_up, activation.n AS activated, first_action.n AS took_first_action
FROM signups, activation, first_action;

/* Q29. */
SELECT
  (SELECT COUNT(*) FROM web_events.events WHERE event_type = 'click') AS cart_clicks,
  (SELECT COUNT(*) FROM customers.addresses) AS addresses_on_file,
  (SELECT COUNT(*) FROM sales.payments) AS payments_made,
  (SELECT COUNT(*) FROM sales.orders WHERE order_status = 'Delivered') AS confirmed_orders;

/* Q30. */
WITH order_counts AS (SELECT cust_id, COUNT(*) AS n FROM sales.orders GROUP BY cust_id)
SELECT (SELECT COUNT(*) FROM customers.customers) AS registered,
       COUNT(*) FILTER (WHERE n = 1) AS trial_like,
       COUNT(*) FILTER (WHERE n >= 2) AS engaged_like,
       COUNT(*) FILTER (WHERE n >= 3) AS paid_like
FROM order_counts;

/* Q31. */
WITH gaps AS (
  SELECT cust_id, order_date, order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date) AS gap
  FROM sales.orders
),
dormant AS (
  SELECT DISTINCT cust_id, order_date AS dormant_start FROM gaps WHERE gap > 90
),
clicked_after AS (
  SELECT DISTINCT d.cust_id
  FROM dormant d
  JOIN web_events.page_views pv ON pv.customer_id = d.cust_id AND pv.view_timestamp::date > d.dormant_start
),
ordered_after AS (
  SELECT DISTINCT d.cust_id
  FROM dormant d
  JOIN sales.orders o ON o.cust_id = d.cust_id AND o.order_date > d.dormant_start
)
SELECT (SELECT COUNT(DISTINCT cust_id) FROM dormant) AS dormant_customers,
       (SELECT COUNT(*) FROM clicked_after) AS clicked_after_dormant,
       (SELECT COUNT(*) FROM ordered_after) AS ordered_after_dormant;

/* Q32. */
SELECT status,
       COUNT(*) AS tickets,
       COUNT(*) FILTER (WHERE agent_id IS NOT NULL) AS assigned
FROM support.tickets
GROUP BY status
ORDER BY tickets DESC;

/* Q33. */
SELECT COUNT(*) AS return_requests, SUM(refund_amount) AS total_issued
FROM sales.returns;

/* Q34. */
SELECT COUNT(*) AS returns_initiated, COUNT(*) AS returns_refunded, ROUND(SUM(refund_amount), 2) AS total_refunded
FROM sales.returns;

/* Q35. */
WITH steps AS (
  SELECT
    (SELECT COUNT(DISTINCT session_id) FROM web_events.page_views) AS visits,
    (SELECT COUNT(*) FROM sales.orders) AS orders,
    (SELECT COUNT(*) FROM sales.payments) AS payments,
    (SELECT COUNT(*) FROM sales.orders WHERE order_status = 'Delivered') AS delivered
)
SELECT visits, orders, payments, delivered,
       ROUND(100.0 * (visits - orders) / NULLIF(visits, 0), 2) AS dropoff_visit_to_order_pct,
       ROUND(100.0 * (orders - payments) / NULLIF(orders, 0), 2) AS dropoff_order_to_payment_pct,
       ROUND(100.0 * (payments - delivered) / NULLIF(payments, 0), 2) AS dropoff_payment_to_delivered_pct
FROM steps;

/* Q36. */
SELECT ROUND(AVG(s.shipped_date - o.order_date), 2) AS avg_days_order_to_ship,
       ROUND(AVG(s.delivered_date - s.shipped_date), 2) AS avg_days_ship_to_deliver
FROM sales.orders o
JOIN sales.shipments s ON s.order_id = o.order_id
WHERE s.delivered_date IS NOT NULL;

/* Q37. */
WITH steps AS (
  SELECT
    (SELECT COUNT(DISTINCT session_id) FROM web_events.page_views) AS visits,
    (SELECT COUNT(*) FROM sales.orders) AS orders,
    (SELECT COUNT(*) FROM sales.payments) AS payments,
    (SELECT COUNT(*) FROM sales.orders WHERE order_status = 'Delivered') AS delivered
)
SELECT ROUND(100.0 * orders / NULLIF(visits, 0), 2) AS visit_to_order_pct,
       ROUND(100.0 * payments / NULLIF(orders, 0), 2) AS order_to_payment_pct,
       ROUND(100.0 * delivered / NULLIF(payments, 0), 2) AS payment_to_delivered_pct
FROM steps;

/* Q38. */
WITH steps AS (
  SELECT
    (SELECT COUNT(DISTINCT session_id) FROM web_events.page_views) AS visits,
    (SELECT COUNT(*) FROM sales.orders) AS orders,
    (SELECT COUNT(*) FROM sales.payments) AS payments,
    (SELECT COUNT(*) FROM sales.orders WHERE order_status = 'Delivered') AS delivered
),
drops AS (
  SELECT 'visit_to_order' AS step, ROUND(100.0 * (visits - orders) / NULLIF(visits, 0), 2) AS dropoff_pct FROM steps
  UNION ALL
  SELECT 'order_to_payment', ROUND(100.0 * (orders - payments) / NULLIF(orders, 0), 2) FROM steps
  UNION ALL
  SELECT 'payment_to_delivered', ROUND(100.0 * (payments - delivered) / NULLIF(payments, 0), 2) FROM steps
)
SELECT step, dropoff_pct
FROM drops
ORDER BY dropoff_pct DESC
LIMIT 1;

/* Q39. */
WITH touches AS (
  SELECT customer_id, page_url, COUNT(*) AS touch_count
  FROM web_events.page_views
  WHERE customer_id IS NOT NULL
  GROUP BY customer_id, page_url
),
touches_per_cust AS (
  SELECT customer_id, SUM(touch_count) AS total_touches FROM touches GROUP BY customer_id
),
cust_revenue AS (
  SELECT cust_id, SUM(net_total) AS revenue FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed') GROUP BY cust_id
)
SELECT t.page_url, ROUND(SUM(r.revenue * t.touch_count / tc.total_touches), 2) AS attributed_revenue
FROM touches t
JOIN touches_per_cust tc ON tc.customer_id = t.customer_id
JOIN cust_revenue r ON r.cust_id = t.customer_id
GROUP BY t.page_url
ORDER BY attributed_revenue DESC
LIMIT 20;

/* Q40. */
WITH first_touch AS (
  SELECT DISTINCT ON (customer_id) customer_id, page_url
  FROM web_events.page_views
  WHERE customer_id IS NOT NULL
  ORDER BY customer_id, view_timestamp ASC
),
cust_revenue AS (
  SELECT cust_id, SUM(net_total) AS revenue FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed') GROUP BY cust_id
)
SELECT f.page_url, ROUND(SUM(r.revenue), 2) AS attributed_revenue
FROM first_touch f
JOIN cust_revenue r ON r.cust_id = f.customer_id
GROUP BY f.page_url
ORDER BY attributed_revenue DESC
LIMIT 20;

/* Q41. */
WITH last_touch AS (
  SELECT DISTINCT ON (customer_id) customer_id, page_url
  FROM web_events.page_views
  WHERE customer_id IS NOT NULL
  ORDER BY customer_id, view_timestamp DESC
),
cust_revenue AS (
  SELECT cust_id, SUM(net_total) AS revenue FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed') GROUP BY cust_id
)
SELECT l.page_url, ROUND(SUM(r.revenue), 2) AS attributed_revenue
FROM last_touch l
JOIN cust_revenue r ON r.cust_id = l.customer_id
GROUP BY l.page_url
ORDER BY attributed_revenue DESC
LIMIT 20;

/* Q42. */
WITH touches AS (
  SELECT customer_id, page_url, COUNT(*) AS touch_count
  FROM web_events.page_views
  WHERE customer_id IS NOT NULL
  GROUP BY customer_id, page_url
),
touches_per_cust AS (
  SELECT customer_id, SUM(touch_count) AS total_touches FROM touches GROUP BY customer_id
),
cust_revenue AS (
  SELECT cust_id, SUM(net_total) AS revenue FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed') GROUP BY cust_id
)
SELECT t.page_url, ROUND(SUM(r.revenue * t.touch_count / tc.total_touches), 2) AS linear_attributed_revenue
FROM touches t
JOIN touches_per_cust tc ON tc.customer_id = t.customer_id
JOIN cust_revenue r ON r.cust_id = t.customer_id
GROUP BY t.page_url
ORDER BY linear_attributed_revenue DESC
LIMIT 20;

/* Q43. */
WITH ranked_touches AS (
  SELECT customer_id, page_url, view_timestamp,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY view_timestamp DESC) AS recency_rank,
         POWER(0.5, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY view_timestamp DESC) - 1) AS decay_weight
  FROM web_events.page_views
  WHERE customer_id IS NOT NULL
),
weight_totals AS (
  SELECT customer_id, SUM(decay_weight) AS total_weight FROM ranked_touches GROUP BY customer_id
),
cust_revenue AS (
  SELECT cust_id, SUM(net_total) AS revenue FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed') GROUP BY cust_id
)
SELECT rt.page_url, ROUND(SUM(r.revenue * rt.decay_weight / wt.total_weight), 2) AS time_decay_attributed_revenue
FROM ranked_touches rt
JOIN weight_totals wt ON wt.customer_id = rt.customer_id
JOIN cust_revenue r ON r.cust_id = rt.customer_id
GROUP BY rt.page_url
ORDER BY time_decay_attributed_revenue DESC
LIMIT 20;

/* Q44. */
WITH touch_positions AS (
  SELECT customer_id, page_url, view_timestamp,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY view_timestamp) AS rn,
         COUNT(*) OVER (PARTITION BY customer_id) AS total_touches
  FROM web_events.page_views
  WHERE customer_id IS NOT NULL
),
weighted AS (
  SELECT customer_id, page_url,
         CASE WHEN total_touches = 1 THEN 1.0
              WHEN rn = 1 THEN 0.4
              WHEN rn = total_touches THEN 0.4
              ELSE 0.2 / NULLIF(total_touches - 2, 0) END AS weight
  FROM touch_positions
),
cust_revenue AS (
  SELECT cust_id, SUM(net_total) AS revenue FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed') GROUP BY cust_id
)
SELECT w.page_url, ROUND(SUM(r.revenue * w.weight), 2) AS position_based_attributed_revenue
FROM weighted w
JOIN cust_revenue r ON r.cust_id = w.customer_id
GROUP BY w.page_url
ORDER BY position_based_attributed_revenue DESC
LIMIT 20;

/* Q45. */
WITH session_path AS (
  SELECT session_id, STRING_AGG(page_url, ' -> ' ORDER BY view_timestamp) AS path
  FROM web_events.page_views
  GROUP BY session_id
)
SELECT path, COUNT(*) AS sessions
FROM session_path
GROUP BY path
ORDER BY sessions DESC
LIMIT 20;

/* Q46. */
WITH session_path AS (
  SELECT session_id, STRING_AGG(page_url, ' -> ' ORDER BY view_timestamp) AS path
  FROM web_events.page_views
  GROUP BY session_id
)
SELECT path, COUNT(*) AS sessions
FROM session_path
GROUP BY path
ORDER BY sessions DESC
LIMIT 10;

/* Q47. */
WITH session_path AS (
  SELECT session_id, STRING_AGG(page_url, ' -> ' ORDER BY view_timestamp) AS path
  FROM web_events.page_views
  GROUP BY session_id
),
path_counts AS (
  SELECT path, COUNT(*) AS sessions FROM session_path GROUP BY path
)
SELECT path, sessions
FROM path_counts
WHERE sessions = 1
LIMIT 20;

/* Q48. */
WITH session_path AS (
  SELECT session_id, customer_id, STRING_AGG(page_url, ' -> ' ORDER BY view_timestamp) AS path
  FROM web_events.page_views
  WHERE customer_id IS NOT NULL
  GROUP BY session_id, customer_id
),
cust_revenue AS (
  SELECT cust_id, SUM(net_total) AS revenue FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed') GROUP BY cust_id
)
SELECT sp.path, ROUND(SUM(r.revenue), 2) AS total_revenue
FROM session_path sp
JOIN cust_revenue r ON r.cust_id = sp.customer_id
GROUP BY sp.path
ORDER BY total_revenue DESC
LIMIT 20;

/* Q49. */
WITH session_span AS (
  SELECT session_id, customer_id,
         EXTRACT(EPOCH FROM (MAX(view_timestamp) - MIN(view_timestamp))) AS span_seconds
  FROM web_events.page_views
  WHERE customer_id IS NOT NULL
  GROUP BY session_id, customer_id
  HAVING COUNT(*) > 1
)
SELECT session_id, customer_id, span_seconds
FROM session_span
WHERE customer_id IN (SELECT DISTINCT cust_id FROM sales.orders)
ORDER BY span_seconds ASC
LIMIT 20;

/* Q50. */
WITH cohorts AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date) AS cohort_month
  FROM customers.customers
),
visits AS (
  SELECT DISTINCT customer_id FROM web_events.page_views WHERE customer_id IS NOT NULL
),
orders AS (
  SELECT DISTINCT cust_id FROM sales.orders
)
SELECT c.cohort_month,
       COUNT(*) FILTER (WHERE v.customer_id IS NOT NULL) AS visited,
       COUNT(*) FILTER (WHERE o.cust_id IS NOT NULL) AS ordered,
       ROUND(100.0 * COUNT(*) FILTER (WHERE o.cust_id IS NOT NULL) / NULLIF(COUNT(*) FILTER (WHERE v.customer_id IS NOT NULL), 0), 2) AS visit_to_order_pct
FROM cohorts c
LEFT JOIN visits v ON v.customer_id = c.customer_id
LEFT JOIN orders o ON o.cust_id = c.customer_id
GROUP BY c.cohort_month
ORDER BY c.cohort_month;

/* SECTION C: RFM / NPS / SEGMENTS (25) */

/* Q51. */
WITH cust_metrics AS (
  SELECT c.customer_id,
         (SELECT MAX(order_date) FROM sales.orders) - MAX(o.order_date) AS recency_days,
         COUNT(o.order_id) AS frequency,
         COALESCE(SUM(o.net_total), 0) AS monetary
  FROM customers.customers c
  LEFT JOIN sales.orders o ON o.cust_id = c.customer_id AND o.order_status NOT IN ('Cancelled', 'Failed')
  GROUP BY c.customer_id
)
SELECT customer_id,
       NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,
       NTILE(5) OVER (ORDER BY frequency DESC) AS f_score,
       NTILE(5) OVER (ORDER BY monetary DESC) AS m_score
FROM cust_metrics
ORDER BY customer_id
LIMIT 50;

/* Q52. */
WITH cust_metrics AS (
  SELECT c.customer_id,
         (SELECT MAX(order_date) FROM sales.orders) - MAX(o.order_date) AS recency_days,
         COUNT(o.order_id) AS frequency,
         COALESCE(SUM(o.net_total), 0) AS monetary
  FROM customers.customers c
  LEFT JOIN sales.orders o ON o.cust_id = c.customer_id AND o.order_status NOT IN ('Cancelled', 'Failed')
  GROUP BY c.customer_id
),
scored AS (
  SELECT customer_id,
         NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,
         NTILE(5) OVER (ORDER BY frequency DESC) AS f_score,
         NTILE(5) OVER (ORDER BY monetary DESC) AS m_score
  FROM cust_metrics
)
SELECT customer_id, r_score, f_score, m_score,
       CASE WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champion'
            WHEN f_score >= 4 AND m_score >= 4 THEN 'Loyal'
            WHEN r_score >= 4 AND f_score <= 2 THEN 'New'
            WHEN r_score <= 2 AND f_score >= 3 THEN 'At-Risk'
            WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost'
            ELSE 'Needs Attention' END AS segment_name
FROM scored
ORDER BY customer_id
LIMIT 50;

/* Q53. */
WITH cust_metrics AS (
  SELECT c.customer_id,
         (SELECT MAX(order_date) FROM sales.orders) - MAX(o.order_date) AS recency_days,
         COUNT(o.order_id) AS frequency,
         COALESCE(SUM(o.net_total), 0) AS monetary
  FROM customers.customers c
  LEFT JOIN sales.orders o ON o.cust_id = c.customer_id AND o.order_status NOT IN ('Cancelled', 'Failed')
  GROUP BY c.customer_id
),
scored AS (
  SELECT customer_id,
         NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,
         NTILE(5) OVER (ORDER BY frequency DESC) AS f_score,
         NTILE(5) OVER (ORDER BY monetary DESC) AS m_score
  FROM cust_metrics
)
SELECT customer_id, r_score, f_score, m_score,
       CASE WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Reward with VIP perks'
            WHEN f_score >= 4 AND m_score >= 4 THEN 'Upsell premium products'
            WHEN r_score >= 4 AND f_score <= 2 THEN 'Nurture with onboarding offers'
            WHEN r_score <= 2 AND f_score >= 3 THEN 'Send win-back discount'
            WHEN r_score <= 2 AND f_score <= 2 THEN 'Low-cost reactivation email only'
            ELSE 'Monitor' END AS next_best_action
FROM scored
ORDER BY customer_id
LIMIT 50;

/* Q54. */
WITH scored AS (
  SELECT CASE WHEN rating = 5 THEN 'promoter' WHEN rating = 4 THEN 'passive' ELSE 'detractor' END AS category
  FROM customers.reviews
)
SELECT ROUND(100.0 * (COUNT(*) FILTER (WHERE category = 'promoter') - COUNT(*) FILTER (WHERE category = 'detractor')) / COUNT(*), 2) AS nps
FROM scored;

/* Q55. */
WITH review_region AS (
  SELECT r.rating, rg.region_name
  FROM customers.reviews r
  JOIN customers.addresses a ON a.customer_id = r.customer_id AND a.is_default = true
  JOIN core.dim_region rg ON rg.state = a.state
)
SELECT region_name,
       ROUND(100.0 * (COUNT(*) FILTER (WHERE rating = 5) - COUNT(*) FILTER (WHERE rating <= 3)) / COUNT(*), 2) AS nps
FROM review_region
GROUP BY region_name
ORDER BY nps DESC;

/* Q56. */
SELECT p.product_id, p.product_name,
       ROUND(100.0 * (COUNT(*) FILTER (WHERE r.rating = 5) - COUNT(*) FILTER (WHERE r.rating <= 3)) / COUNT(*), 2) AS nps,
       COUNT(*) AS review_count
FROM customers.reviews r
JOIN products.products p ON p.product_id = r.product_id
GROUP BY p.product_id, p.product_name
HAVING COUNT(*) >= 5
ORDER BY nps DESC
LIMIT 20;

/* Q57. */
SELECT c.tier,
       ROUND(100.0 * (COUNT(*) FILTER (WHERE r.rating = 5) - COUNT(*) FILTER (WHERE r.rating <= 3)) / COUNT(*), 2) AS nps
FROM customers.reviews r
JOIN customers.customers c ON c.customer_id = r.customer_id
GROUP BY c.tier
ORDER BY nps DESC;

/* Q58. */
SELECT DATE_TRUNC('month', review_date) AS month,
       ROUND(100.0 * (COUNT(*) FILTER (WHERE rating = 5) - COUNT(*) FILTER (WHERE rating <= 3)) / COUNT(*), 2) AS nps
FROM customers.reviews
GROUP BY 1
ORDER BY 1;

/* Q59. */
SELECT COUNT(*) AS promoters FROM customers.reviews WHERE rating = 5;

/* Q60. */
SELECT COUNT(*) AS detractors FROM customers.reviews WHERE rating <= 3;

/* Q61. */
SELECT COUNT(*) AS passives FROM customers.reviews WHERE rating = 4;

/* Q62. */
SELECT ROUND(AVG(rating), 2) AS avg_rating,
       ROUND(100.0 * COUNT(*) FILTER (WHERE rating >= 4) / COUNT(*), 2) AS csat_pct
FROM customers.reviews;

/* Q63. */
SELECT c.agent_id,
       ROUND(AVG(t.sentiment_score), 3) AS avg_sentiment,
       COUNT(*) AS calls
FROM call_center.calls c
JOIN call_center.transcripts t ON t.call_id = c.call_id
GROUP BY c.agent_id
ORDER BY avg_sentiment DESC
LIMIT 20;

/* Q64. */
SELECT c.call_reason AS category,
       ROUND(AVG(t.sentiment_score), 3) AS avg_sentiment,
       COUNT(*) AS calls
FROM call_center.calls c
JOIN call_center.transcripts t ON t.call_id = c.call_id
GROUP BY c.call_reason
ORDER BY avg_sentiment DESC;

/* Q65. */
SELECT customer_id, first_name, last_name, tier
FROM customers.customers
WHERE tier = 'Platinum'
ORDER BY customer_id
LIMIT 50;

/* Q66. */
WITH active_months AS (
  SELECT cust_id, COUNT(DISTINCT DATE_TRUNC('month', order_date)) AS months_active
  FROM sales.orders
  GROUP BY cust_id
)
SELECT cust_id, months_active
FROM active_months
WHERE months_active >= 3
ORDER BY months_active DESC
LIMIT 50;

/* Q67. */
WITH last_order AS (
  SELECT cust_id, MAX(order_date) AS last_order_date FROM sales.orders GROUP BY cust_id
)
SELECT cust_id, last_order_date
FROM last_order
WHERE last_order_date < (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '90 days'
  AND last_order_date >= (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '180 days'
ORDER BY last_order_date DESC
LIMIT 50;

/* Q68. */
WITH last_order AS (
  SELECT cust_id, MAX(order_date) AS last_order_date FROM sales.orders GROUP BY cust_id
)
SELECT cust_id, last_order_date
FROM last_order
WHERE last_order_date < (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '180 days'
ORDER BY last_order_date ASC
LIMIT 50;

/* Q69. */
SELECT customer_id, first_name, last_name, registration_date
FROM customers.customers
WHERE registration_date >= (SELECT MAX(registration_date) FROM customers.customers) - INTERVAL '30 days'
ORDER BY registration_date DESC
LIMIT 50;

/* Q70. */
WITH recent_spend AS (
  SELECT cust_id, SUM(net_total) AS spend
  FROM sales.orders
  WHERE order_status NOT IN ('Cancelled', 'Failed')
    AND order_date >= (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '6 months'
  GROUP BY cust_id
),
prior_spend AS (
  SELECT cust_id, SUM(net_total) AS spend
  FROM sales.orders
  WHERE order_status NOT IN ('Cancelled', 'Failed')
    AND order_date < (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '6 months'
    AND order_date >= (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '12 months'
  GROUP BY cust_id
),
recent_q AS (SELECT cust_id, NTILE(4) OVER (ORDER BY spend DESC) AS q FROM recent_spend),
prior_q AS (SELECT cust_id, NTILE(4) OVER (ORDER BY spend DESC) AS q FROM prior_spend)
SELECT p.q AS prior_quartile, r.q AS recent_quartile, COUNT(*) AS customers
FROM prior_q p
JOIN recent_q r ON r.cust_id = p.cust_id
GROUP BY p.q, r.q
ORDER BY p.q, r.q;

/* Q71. */
SELECT c.tier, ROUND(AVG(spend.total_spend), 2) AS segment_ltv
FROM customers.customers c
JOIN (SELECT cust_id, SUM(net_total) AS total_spend FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed') GROUP BY cust_id) spend
  ON spend.cust_id = c.customer_id
GROUP BY c.tier
ORDER BY segment_ltv DESC;

/* Q72. */
SELECT c.tier, ROUND(AVG(oc.orders), 2) AS avg_orders
FROM customers.customers c
JOIN (SELECT cust_id, COUNT(*) AS orders FROM sales.orders GROUP BY cust_id) oc ON oc.cust_id = c.customer_id
GROUP BY c.tier
ORDER BY avg_orders DESC;

/* Q73. */
WITH recent AS (
  SELECT DISTINCT cust_id FROM sales.orders WHERE order_date >= (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '90 days'
)
SELECT c.tier, COUNT(*) AS customers,
       ROUND(100.0 * COUNT(*) FILTER (WHERE r.cust_id IS NOT NULL) / COUNT(*), 2) AS retention_pct
FROM customers.customers c
LEFT JOIN recent r ON r.cust_id = c.customer_id
GROUP BY c.tier
ORDER BY retention_pct DESC;

/* Q74. */
WITH segment_revenue AS (
  SELECT c.tier, SUM(o.net_total) AS revenue
  FROM customers.customers c
  JOIN sales.orders o ON o.cust_id = c.customer_id
  JOIN marketing.campaigns camp ON o.order_date BETWEEN camp.start_date AND camp.end_date
  WHERE o.order_status NOT IN ('Cancelled', 'Failed')
  GROUP BY c.tier
),
total_spend AS (
  SELECT SUM(amount) AS spend FROM marketing.ads_spend
)
SELECT sr.tier, sr.revenue, ts.spend,
       ROUND(100.0 * (sr.revenue - ts.spend) / NULLIF(ts.spend, 0), 2) AS roi_pct
FROM segment_revenue sr, total_spend ts
ORDER BY sr.revenue DESC;

/* Q75. */
WITH tier_product_sales AS (
  SELECT c.tier, p.product_id, p.product_name, SUM(oi.quantity) AS units_sold,
         ROW_NUMBER() OVER (PARTITION BY c.tier ORDER BY SUM(oi.quantity) DESC) AS rn
  FROM customers.customers c
  JOIN sales.orders o ON o.cust_id = c.customer_id
  JOIN sales.order_items oi ON oi.order_id = o.order_id
  JOIN products.products p ON p.product_id = oi.prod_id
  GROUP BY c.tier, p.product_id, p.product_name
)
SELECT tier, product_id, product_name, units_sold
FROM tier_product_sales
WHERE rn = 1
ORDER BY tier;

/* SECTION D: MULTI-SOURCE DASHBOARDS (25) */

/* Q76. */
WITH order_stats AS (
  SELECT cust_id, COUNT(*) AS orders, SUM(net_total) AS revenue
  FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed') GROUP BY cust_id
),
review_stats AS (SELECT customer_id, COUNT(*) AS reviews, AVG(rating) AS avg_rating FROM customers.reviews GROUP BY customer_id),
ticket_stats AS (SELECT customer_id, COUNT(*) AS tickets FROM support.tickets GROUP BY customer_id),
call_stats AS (SELECT customer_id, COUNT(*) AS calls FROM call_center.calls GROUP BY customer_id),
loyalty_stats AS (SELECT customer_id, points_balance FROM loyalty.members),
address_stats AS (SELECT customer_id, COUNT(*) AS addresses FROM customers.addresses GROUP BY customer_id)
SELECT c.customer_id, c.first_name, c.last_name, c.tier,
       COALESCE(o.orders, 0) AS orders, COALESCE(o.revenue, 0) AS revenue,
       COALESCE(r.reviews, 0) AS reviews, r.avg_rating,
       COALESCE(t.tickets, 0) AS tickets, COALESCE(cl.calls, 0) AS calls,
       l.points_balance, COALESCE(a.addresses, 0) AS addresses
FROM customers.customers c
LEFT JOIN order_stats o ON o.cust_id = c.customer_id
LEFT JOIN review_stats r ON r.customer_id = c.customer_id
LEFT JOIN ticket_stats t ON t.customer_id = c.customer_id
LEFT JOIN call_stats cl ON cl.customer_id = c.customer_id
LEFT JOIN loyalty_stats l ON l.customer_id = c.customer_id
LEFT JOIN address_stats a ON a.customer_id = c.customer_id
ORDER BY o.revenue DESC NULLS LAST
LIMIT 20;

/* Q77. */
WITH sales_stats AS (
  SELECT prod_id, SUM(quantity) AS units_sold, SUM(net_amount) AS revenue
  FROM sales.order_items GROUP BY prod_id
),
review_stats AS (SELECT product_id, COUNT(*) AS reviews, AVG(rating) AS avg_rating FROM customers.reviews GROUP BY product_id),
inv_stats AS (SELECT product_id, SUM(quantity_on_hand) AS total_stock FROM products.inventory GROUP BY product_id)
SELECT p.product_id, p.product_name, s.supplier_name,
       COALESCE(ss.units_sold, 0) AS units_sold, COALESCE(ss.revenue, 0) AS revenue,
       COALESCE(rs.reviews, 0) AS reviews, rs.avg_rating,
       COALESCE(iv.total_stock, 0) AS total_stock
FROM products.products p
JOIN products.suppliers s ON s.supplier_id = p.supplier_id
LEFT JOIN sales_stats ss ON ss.prod_id = p.product_id
LEFT JOIN review_stats rs ON rs.product_id = p.product_id
LEFT JOIN inv_stats iv ON iv.product_id = p.product_id
ORDER BY ss.revenue DESC NULLS LAST
LIMIT 20;

/* Q78. */
WITH order_stats AS (
  SELECT store_id, COUNT(*) AS orders, SUM(net_total) AS revenue
  FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed') GROUP BY store_id
),
emp_stats AS (SELECT store_id, COUNT(*) AS headcount FROM stores.employees GROUP BY store_id),
exp_stats AS (SELECT store_id, SUM(amount) AS total_expenses FROM stores.expenses GROUP BY store_id),
inv_stats AS (SELECT store_id, SUM(quantity_on_hand) AS total_stock FROM products.inventory GROUP BY store_id)
SELECT s.store_id, s.store_name, r.region_name,
       COALESCE(o.orders, 0) AS orders, COALESCE(o.revenue, 0) AS revenue,
       COALESCE(e.headcount, 0) AS headcount, COALESCE(x.total_expenses, 0) AS total_expenses,
       COALESCE(i.total_stock, 0) AS total_stock
FROM stores.stores s
JOIN core.dim_region r ON r.region_id = s.region_id
LEFT JOIN order_stats o ON o.store_id = s.store_id
LEFT JOIN emp_stats e ON e.store_id = s.store_id
LEFT JOIN exp_stats x ON x.store_id = s.store_id
LEFT JOIN inv_stats i ON i.store_id = s.store_id
ORDER BY o.revenue DESC NULLS LAST
LIMIT 20;

/* Q79. */
WITH order_stats AS (
  SELECT s.region_id, COUNT(*) AS orders, SUM(o.net_total) AS revenue
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  WHERE o.order_status NOT IN ('Cancelled', 'Failed')
  GROUP BY s.region_id
),
store_stats AS (SELECT region_id, COUNT(*) AS store_count FROM stores.stores GROUP BY region_id),
emp_stats AS (
  SELECT s.region_id, COUNT(*) AS headcount
  FROM stores.employees e JOIN stores.stores s ON s.store_id = e.store_id
  GROUP BY s.region_id
)
SELECT r.region_id, r.region_name,
       COALESCE(st.store_count, 0) AS store_count,
       COALESCE(e.headcount, 0) AS headcount,
       COALESCE(o.orders, 0) AS orders, COALESCE(o.revenue, 0) AS revenue
FROM core.dim_region r
LEFT JOIN order_stats o ON o.region_id = r.region_id
LEFT JOIN store_stats st ON st.region_id = r.region_id
LEFT JOIN emp_stats e ON e.region_id = r.region_id
ORDER BY o.revenue DESC NULLS LAST;

/* Q80. */
WITH spend AS (SELECT campaign_id, SUM(amount) AS total_spend FROM marketing.ads_spend GROUP BY campaign_id),
clicks AS (SELECT campaign_id, SUM(emails_sent) AS sent, SUM(emails_opened) AS opened, SUM(emails_clicked) AS clicked FROM marketing.email_clicks GROUP BY campaign_id),
revenue AS (
  SELECT c.campaign_id, SUM(o.net_total) AS revenue
  FROM marketing.campaigns c
  JOIN sales.orders o ON o.order_date BETWEEN c.start_date AND c.end_date AND o.order_status NOT IN ('Cancelled', 'Failed')
  GROUP BY c.campaign_id
)
SELECT c.campaign_id, c.campaign_name, c.budget,
       COALESCE(s.total_spend, 0) AS total_spend,
       COALESCE(cl.clicked, 0) AS clicked,
       COALESCE(r.revenue, 0) AS attributed_revenue
FROM marketing.campaigns c
LEFT JOIN spend s ON s.campaign_id = c.campaign_id
LEFT JOIN clicks cl ON cl.campaign_id = c.campaign_id
LEFT JOIN revenue r ON r.campaign_id = c.campaign_id
ORDER BY attributed_revenue DESC NULLS LAST
LIMIT 20;

/* Q81. */
WITH prod_stats AS (
  SELECT supplier_id, COUNT(*) AS product_count, AVG(price) AS avg_price
  FROM products.products GROUP BY supplier_id
),
sales_stats AS (
  SELECT p.supplier_id, SUM(oi.quantity) AS units_sold, SUM(oi.net_amount) AS revenue
  FROM sales.order_items oi
  JOIN products.products p ON p.product_id = oi.prod_id
  GROUP BY p.supplier_id
)
SELECT s.supplier_id, s.supplier_name, s.city,
       COALESCE(ps.product_count, 0) AS product_count, ROUND(ps.avg_price, 2) AS avg_price,
       COALESCE(ss.units_sold, 0) AS units_sold, COALESCE(ss.revenue, 0) AS revenue
FROM products.suppliers s
LEFT JOIN prod_stats ps ON ps.supplier_id = s.supplier_id
LEFT JOIN sales_stats ss ON ss.supplier_id = s.supplier_id
ORDER BY ss.revenue DESC NULLS LAST
LIMIT 20;

/* Q82. */
WITH prod_stats AS (SELECT brand_id, COUNT(*) AS product_count FROM products.products GROUP BY brand_id),
sales_stats AS (
  SELECT p.brand_id, SUM(oi.quantity) AS units_sold, SUM(oi.net_amount) AS revenue
  FROM sales.order_items oi JOIN products.products p ON p.product_id = oi.prod_id
  GROUP BY p.brand_id
),
review_stats AS (
  SELECT p.brand_id, AVG(r.rating) AS avg_rating, COUNT(*) AS reviews
  FROM customers.reviews r JOIN products.products p ON p.product_id = r.product_id
  GROUP BY p.brand_id
)
SELECT b.brand_id, b.brand_name, cat.category_name,
       COALESCE(ps.product_count, 0) AS product_count,
       COALESCE(ss.units_sold, 0) AS units_sold, COALESCE(ss.revenue, 0) AS revenue,
       ROUND(rs.avg_rating, 2) AS avg_rating, COALESCE(rs.reviews, 0) AS reviews
FROM core.dim_brand b
JOIN core.dim_category cat ON cat.category_id = b.category_id
LEFT JOIN prod_stats ps ON ps.brand_id = b.brand_id
LEFT JOIN sales_stats ss ON ss.brand_id = b.brand_id
LEFT JOIN review_stats rs ON rs.brand_id = b.brand_id
ORDER BY ss.revenue DESC NULLS LAST
LIMIT 20;

/* Q83. */
WITH order_stats AS (
  SELECT c.tier, COUNT(*) AS orders, SUM(o.net_total) AS revenue
  FROM sales.orders o JOIN customers.customers c ON c.customer_id = o.cust_id
  WHERE o.order_status NOT IN ('Cancelled', 'Failed')
  GROUP BY c.tier
),
review_stats AS (
  SELECT c.tier, AVG(r.rating) AS avg_rating
  FROM customers.reviews r JOIN customers.customers c ON c.customer_id = r.customer_id
  GROUP BY c.tier
),
loyalty_stats AS (
  SELECT t.tier_name, AVG(m.points_balance) AS avg_points
  FROM loyalty.members m JOIN loyalty.tiers t ON t.tier_id = m.tier_id
  GROUP BY t.tier_name
)
SELECT c.tier, COUNT(*) AS customers,
       COALESCE(o.orders, 0) AS orders, COALESCE(o.revenue, 0) AS revenue,
       ROUND(rv.avg_rating, 2) AS avg_rating, ROUND(l.avg_points, 2) AS avg_points
FROM customers.customers c
LEFT JOIN order_stats o ON o.tier = c.tier
LEFT JOIN review_stats rv ON rv.tier = c.tier
LEFT JOIN loyalty_stats l ON l.tier_name = c.tier
GROUP BY c.tier, o.orders, o.revenue, rv.avg_rating, l.avg_points
ORDER BY revenue DESC NULLS LAST;

/* Q84. */
WITH call_stats AS (
  SELECT agent_id, COUNT(*) AS calls, AVG(call_duration_seconds) AS avg_duration
  FROM call_center.calls GROUP BY agent_id
),
sentiment_stats AS (
  SELECT c.agent_id, AVG(t.sentiment_score) AS avg_sentiment
  FROM call_center.calls c JOIN call_center.transcripts t ON t.call_id = c.call_id
  GROUP BY c.agent_id
),
ticket_stats AS (
  SELECT agent_id, COUNT(*) AS tickets_resolved
  FROM support.tickets WHERE status IN ('Resolved', 'Closed') GROUP BY agent_id
)
SELECT c.agent_id, c.calls, ROUND(c.avg_duration, 2) AS avg_call_duration,
       ROUND(s.avg_sentiment, 3) AS avg_sentiment,
       COALESCE(t.tickets_resolved, 0) AS tickets_resolved
FROM call_stats c
LEFT JOIN sentiment_stats s ON s.agent_id = c.agent_id
LEFT JOIN ticket_stats t ON t.agent_id = c.agent_id
ORDER BY c.calls DESC
LIMIT 20;

/* Q85. */
SELECT courier_name, COUNT(*) AS shipments,
       ROUND(AVG(delivered_date - shipped_date), 2) AS avg_delivery_days,
       COUNT(*) FILTER (WHERE status = 'Delivered') AS delivered_count,
       COUNT(*) FILTER (WHERE status = 'Returned') AS returned_count
FROM sales.shipments
GROUP BY courier_name
ORDER BY shipments DESC;

/* Q86. */
WITH ship_stats AS (
  SELECT warehouse_id, COUNT(*) AS shipments, SUM(quantity) AS total_quantity
  FROM supply_chain.shipments GROUP BY warehouse_id
),
snapshot_stats AS (
  SELECT warehouse_id, SUM(quantity_on_hand) AS current_stock
  FROM supply_chain.inventory_snapshots
  WHERE snapshot_date = (SELECT MAX(snapshot_date) FROM supply_chain.inventory_snapshots)
  GROUP BY warehouse_id
)
SELECT w.warehouse_id, w.name, w.capacity_sqft,
       COALESCE(s.shipments, 0) AS shipments, COALESCE(s.total_quantity, 0) AS total_shipped_quantity,
       COALESCE(sn.current_stock, 0) AS current_stock
FROM supply_chain.warehouses w
LEFT JOIN ship_stats s ON s.warehouse_id = w.warehouse_id
LEFT JOIN snapshot_stats sn ON sn.warehouse_id = w.warehouse_id
ORDER BY w.warehouse_id;

/* Q87. */
WITH emp_stats AS (SELECT dept_id, COUNT(*) AS headcount, AVG(salary) AS avg_salary FROM stores.employees GROUP BY dept_id),
att_stats AS (
  SELECT e.dept_id, COUNT(*) AS attendance_records
  FROM hr.attendance a JOIN stores.employees e ON e.employee_id = a.employee_id
  GROUP BY e.dept_id
)
SELECT d.dept_id, d.dept_name,
       COALESCE(e.headcount, 0) AS headcount, ROUND(e.avg_salary, 2) AS avg_salary,
       COALESCE(a.attendance_records, 0) AS attendance_records
FROM core.dim_department d
LEFT JOIN emp_stats e ON e.dept_id = d.dept_id
LEFT JOIN att_stats a ON a.dept_id = d.dept_id
ORDER BY headcount DESC NULLS LAST;

/* Q88. */
WITH att_stats AS (SELECT employee_id, COUNT(*) AS days_recorded FROM hr.attendance GROUP BY employee_id)
SELECT e.employee_id, e.first_name, e.last_name, e.role, e.salary, s.store_name, d.dept_name,
       COALESCE(a.days_recorded, 0) AS days_recorded
FROM stores.employees e
JOIN stores.stores s ON s.store_id = e.store_id
JOIN core.dim_department d ON d.dept_id = e.dept_id
LEFT JOIN att_stats a ON a.employee_id = e.employee_id
ORDER BY e.salary DESC
LIMIT 20;

/* Q89. */
WITH sales_stats AS (
  SELECT b.category_id, SUM(oi.net_amount) AS revenue, SUM(oi.quantity) AS units_sold
  FROM sales.order_items oi
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  GROUP BY b.category_id
),
review_stats AS (
  SELECT b.category_id, AVG(r.rating) AS avg_rating
  FROM customers.reviews r
  JOIN products.products p ON p.product_id = r.product_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  GROUP BY b.category_id
),
prod_count AS (
  SELECT b.category_id, COUNT(*) AS product_count
  FROM products.products p JOIN core.dim_brand b ON b.brand_id = p.brand_id
  GROUP BY b.category_id
)
SELECT cat.category_id, cat.category_name,
       COALESCE(pc.product_count, 0) AS product_count,
       COALESCE(ss.units_sold, 0) AS units_sold, COALESCE(ss.revenue, 0) AS revenue,
       ROUND(rs.avg_rating, 2) AS avg_rating
FROM core.dim_category cat
LEFT JOIN sales_stats ss ON ss.category_id = cat.category_id
LEFT JOIN review_stats rs ON rs.category_id = cat.category_id
LEFT JOIN prod_count pc ON pc.category_id = cat.category_id
ORDER BY ss.revenue DESC NULLS LAST;

/* Q90. */
SELECT payment_mode AS channel, COUNT(*) AS payments, ROUND(SUM(amount), 2) AS total_amount,
       ROUND(AVG(amount), 2) AS avg_amount
FROM sales.payments
GROUP BY payment_mode
ORDER BY total_amount DESC;

/* Q91. */
WITH rev AS (SELECT SUM(net_total) AS total_revenue, COUNT(*) AS total_orders FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed')),
cust AS (SELECT COUNT(*) AS total_customers FROM customers.customers),
refund AS (SELECT SUM(refund_amount) AS total_refunds FROM sales.returns),
cancel AS (SELECT COUNT(*) FILTER (WHERE order_status = 'Cancelled') AS cancelled, COUNT(*) AS all_orders FROM sales.orders),
tickets AS (SELECT COUNT(*) AS total_tickets, COUNT(*) FILTER (WHERE status IN ('Resolved','Closed')) AS resolved_tickets FROM support.tickets),
reviews AS (SELECT ROUND(AVG(rating), 2) AS avg_rating FROM customers.reviews),
marketing_spend AS (SELECT SUM(amount) AS total_ad_spend FROM marketing.ads_spend),
shipments AS (SELECT COUNT(*) AS total_shipments, COUNT(*) FILTER (WHERE status = 'Delivered') AS delivered FROM sales.shipments)
SELECT rev.total_revenue, rev.total_orders, cust.total_customers,
       ROUND(rev.total_revenue / NULLIF(rev.total_orders, 0), 2) AS aov,
       refund.total_refunds,
       ROUND(100.0 * cancel.cancelled / cancel.all_orders, 2) AS cancellation_rate_pct,
       tickets.total_tickets, tickets.resolved_tickets,
       reviews.avg_rating, marketing_spend.total_ad_spend,
       shipments.total_shipments, shipments.delivered
FROM rev, cust, refund, cancel, tickets, reviews, marketing_spend, shipments;

/* Q92. */
WITH rev AS (SELECT SUM(net_total) AS total_revenue, COUNT(*) AS total_orders FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed')),
cust AS (SELECT COUNT(*) AS total_customers FROM customers.customers),
expenses AS (SELECT SUM(amount) AS total_expenses FROM finance.expenses),
refund AS (SELECT SUM(refund_amount) AS total_refunds FROM sales.returns)
SELECT rev.total_revenue, rev.total_orders, cust.total_customers,
       ROUND(rev.total_revenue / NULLIF(rev.total_orders, 0), 2) AS aov,
       expenses.total_expenses,
       ROUND(rev.total_revenue - expenses.total_expenses, 2) AS net_income,
       refund.total_refunds
FROM rev, cust, expenses, refund;

/* Q93. */
WITH latest_day AS (SELECT MAX(order_date) AS d FROM sales.orders)
SELECT ld.d AS report_date,
       (SELECT COUNT(*) FROM sales.orders WHERE order_date = ld.d) AS orders_today,
       (SELECT ROUND(SUM(net_total), 2) FROM sales.orders WHERE order_date = ld.d) AS revenue_today,
       (SELECT COUNT(*) FROM support.tickets WHERE created_date::date = ld.d) AS tickets_today,
       (SELECT COUNT(*) FROM sales.shipments WHERE shipped_date = ld.d) AS shipments_today
FROM latest_day ld;

/* Q94. */
WITH latest AS (SELECT MAX(order_date) AS d FROM sales.orders),
this_week AS (
  SELECT COUNT(*) AS orders, SUM(net_total) AS revenue
  FROM sales.orders, latest WHERE order_date BETWEEN latest.d - INTERVAL '6 days' AND latest.d
),
prior_week AS (
  SELECT COUNT(*) AS orders, SUM(net_total) AS revenue
  FROM sales.orders, latest WHERE order_date BETWEEN latest.d - INTERVAL '13 days' AND latest.d - INTERVAL '7 days'
)
SELECT tw.orders AS this_week_orders, tw.revenue AS this_week_revenue,
       pw.orders AS prior_week_orders, pw.revenue AS prior_week_revenue,
       ROUND(100.0 * (tw.revenue - pw.revenue) / NULLIF(pw.revenue, 0), 2) AS wow_revenue_change_pct
FROM this_week tw, prior_week pw;

/* Q95. */
WITH monthly_rev AS (
  SELECT DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS revenue
  FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed') GROUP BY 1
),
monthly_cogs AS (
  SELECT DATE_TRUNC('month', o.order_date) AS month, SUM(oi.quantity * p.cost_price) AS cogs
  FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  JOIN products.products p ON p.product_id = oi.prod_id
  WHERE o.order_status NOT IN ('Cancelled', 'Failed')
  GROUP BY 1
),
monthly_exp AS (
  SELECT DATE_TRUNC('month', expense_date) AS month, SUM(amount) AS expenses
  FROM finance.expenses GROUP BY 1
)
SELECT r.month, r.revenue, c.cogs, e.expenses,
       ROUND(r.revenue - c.cogs - e.expenses, 2) AS net_income
FROM monthly_rev r
LEFT JOIN monthly_cogs c ON c.month = r.month
LEFT JOIN monthly_exp e ON e.month = r.month
ORDER BY r.month;

/* Q96. */
WITH quarterly AS (
  SELECT DATE_TRUNC('quarter', order_date) AS quarter, COUNT(*) AS orders, SUM(net_total) AS revenue,
         COUNT(DISTINCT cust_id) AS active_customers
  FROM sales.orders
  WHERE order_status NOT IN ('Cancelled', 'Failed')
  GROUP BY 1
)
SELECT quarter, orders, revenue, active_customers
FROM quarterly
ORDER BY quarter;

/* Q97. */
WITH yearly AS (
  SELECT DATE_PART('year', order_date) AS year, COUNT(*) AS orders, SUM(net_total) AS revenue,
         COUNT(DISTINCT cust_id) AS active_customers
  FROM sales.orders
  WHERE order_status NOT IN ('Cancelled', 'Failed')
  GROUP BY 1
),
yearly_refunds AS (
  SELECT DATE_PART('year', return_date) AS year, SUM(refund_amount) AS refunds
  FROM sales.returns GROUP BY 1
)
SELECT y.year, y.orders, y.revenue, y.active_customers, COALESCE(r.refunds, 0) AS refunds
FROM yearly y
LEFT JOIN yearly_refunds r ON r.year = y.year
ORDER BY y.year;

/* Q98. */
WITH monthly_rev AS (
  SELECT DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS revenue
  FROM sales.orders WHERE order_status NOT IN ('Cancelled', 'Failed') GROUP BY 1
),
monthly_cust AS (
  SELECT DATE_TRUNC('month', registration_date) AS month, COUNT(*) AS new_customers
  FROM customers.customers GROUP BY 1
),
with_growth AS (
  SELECT month, revenue,
         ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month)) / NULLIF(LAG(revenue) OVER (ORDER BY month), 0), 2) AS revenue_growth_pct
  FROM monthly_rev
)
SELECT w.month, w.revenue, w.revenue_growth_pct, c.new_customers
FROM with_growth w
JOIN monthly_cust c ON c.month = w.month
ORDER BY w.month;

/* Q99. */
SELECT 'orphan_order_items' AS check_name, COUNT(*) AS flagged_rows
FROM sales.order_items oi WHERE NOT EXISTS (SELECT 1 FROM sales.orders o WHERE o.order_id = oi.order_id)
UNION ALL
SELECT 'orders_without_payment', COUNT(*)
FROM sales.orders o WHERE NOT EXISTS (SELECT 1 FROM sales.payments p WHERE p.order_id = o.order_id)
UNION ALL
SELECT 'negative_or_zero_quantity_items', COUNT(*)
FROM sales.order_items WHERE quantity <= 0
UNION ALL
SELECT 'orders_with_null_customer', COUNT(*)
FROM sales.orders WHERE cust_id IS NULL
UNION ALL
SELECT 'order_total_mismatch', COUNT(*)
FROM (
  SELECT o.order_id
  FROM sales.orders o
  JOIN (SELECT order_id, SUM(net_amount) AS items_total FROM sales.order_items GROUP BY order_id) i ON i.order_id = o.order_id
  WHERE ABS(o.net_total - i.items_total) > 1
) x;

/* Q100. */
WITH latest AS (SELECT MAX(order_date) AS d FROM sales.orders),
week_orders AS (
  SELECT COUNT(*) AS orders, SUM(net_total) AS revenue, COUNT(DISTINCT cust_id) AS active_customers
  FROM sales.orders, latest WHERE order_date BETWEEN latest.d - INTERVAL '6 days' AND latest.d
    AND order_status NOT IN ('Cancelled', 'Failed')
),
week_new_cust AS (
  SELECT COUNT(*) AS new_customers FROM customers.customers, latest
  WHERE registration_date BETWEEN latest.d - INTERVAL '6 days' AND latest.d
),
week_refunds AS (
  SELECT SUM(refund_amount) AS refunds FROM sales.returns, latest
  WHERE return_date BETWEEN latest.d - INTERVAL '6 days' AND latest.d
),
week_tickets AS (
  SELECT COUNT(*) FILTER (WHERE status IN ('Resolved','Closed')) AS resolved
  FROM support.tickets, latest WHERE created_date::date BETWEEN latest.d - INTERVAL '6 days' AND latest.d
)
SELECT wo.orders, wo.revenue, ROUND(wo.revenue / NULLIF(wo.orders, 0), 2) AS aov,
       wo.active_customers, wn.new_customers, COALESCE(wr.refunds, 0) AS refunds, wt.resolved AS tickets_resolved
FROM week_orders wo, week_new_cust wn, week_refunds wr, week_tickets wt;

/* ============================================================
   END OF ANSWER KEY - MEDIUM LEVEL (100/100)
============================================================ */
