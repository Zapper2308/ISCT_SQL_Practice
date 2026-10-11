/* ============================================================
   ANSWER KEY - Date/Time Mastery for Time-Series (MEDIUM LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1. date_trunc returns a proper date/timestamp value, so ORDER BY / index range-scans sort chronologically; to_char returns text, which sorts alphabetically and loses type information. */
/* Q2. Grouping by to_char(d,'Month') sorts 'April' before 'January' alphabetically; the fix is to group by date_trunc('month', d) (or add EXTRACT(month) as a secondary sort key). */
/* Q3. Present rows only show periods that had activity; a generated calendar guarantees every expected period appears, even ones with zero rows, so trends and averages aren't silently biased. */
/* Q4. The calendar (generated series) drives via LEFT JOIN so every period survives; COALESCE(count,0) is needed because unmatched periods return NULL from the aggregate, not 0. */
/* Q5. ISO week matters whenever a report crosses a year boundary in late Dec/early Jan - the calendar week number resets on Jan 1 but the ISO week can still belong to the prior year. */
/* Q6. EXTRACT(week) uses the ISO week rule too in Postgres, but to_char('IW') is explicitly the ISO week-of-year, so subtle differences appear mainly in how the associated year label ('IYYY') is derived at the boundary. */
/* Q7. A fiscal year starting in April is built by shifting the calendar month: fiscal_month = ((month - 4 + 12) % 12) + 1, then bucketing that shifted month into quarters. */
/* Q8. Store every timestamp in UTC (TIMESTAMP or TIMESTAMPTZ); when displaying, apply `ts AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Kolkata'` to convert the UTC wall-clock value into IST for presentation. */
/* Q9. `ts AT TIME ZONE 'UTC'` interprets/attaches UTC and returns a timestamptz; `ts AT TIME ZONE 'Asia/Kolkata'` shifts a timestamptz into IST local wall-clock time - chaining both converts UTC-naive data to IST. */
/* Q10. DATE columns store no time-of-day, so EXTRACT(HOUR FROM a_date) is always 0 - "peak hour" requires a genuine TIMESTAMP column like view_timestamp or call_start_time. */
/* Q11. INTERVAL '1 month' adds a calendar month (Jan 31 + 1 month = Feb 28/29), while INTERVAL '30 days' always adds exactly 30 days - they diverge in months that aren't 30 days long. */
/* Q12. generate_series(start_ts, end_ts, interval '1 hour') steps through timestamps by the given interval, producing one row per hour (or whatever step is given) between the bounds. */
/* Q13. Arbitrary-width buckets: floor(extract(epoch from ts) / bucket_seconds) * bucket_seconds, converted back with to_timestamp(...), groups timestamps into fixed-width windows of any size. */
/* Q14. A persistent date-dimension table avoids recomputing date_trunc/EXTRACT logic on every query and can be indexed/joined cheaply, which is much faster than generating and computing on the fly for repeated dashboards. */
/* Q15. Build one calendar spine (date range) and LEFT JOIN it separately to each fact table (orders, returns, payments, ...) on their date columns, so all facts share one zero-filled, aligned timeline. */
/* Q16. Gaps/islands: number the rows of a customer's ordering dates, subtract the row number (as days) from the date - equal results share a "run", identifying consecutive-day streaks and the breaks between them. */
/* Q17. RANGE frames include every row whose ORDER BY value falls within a logical range (e.g. all rows within 7 days), which handles duplicate/missing dates correctly; ROWS frames count a fixed number of physical rows regardless of date gaps. */
/* Q18. Without gap-filling, a 7-day moving average silently averages over fewer than 7 real days whenever a day has no data, understating or skewing the trend - the spine must be complete first. */
/* Q19. Cohort timelines anchor each customer's "day 0" to their registration_date (or first order date), then express every subsequent event as an offset (days/months since that anchor). */
/* Q20. LAG(order_date) OVER (PARTITION BY customer ORDER BY order_date) fetches the previous order's date per customer, so order_date - LAG(order_date) gives days since the previous order. */
/* Q21. date_trunc('month', d) + interval '1 month' - interval '1 day' takes the first of the month, jumps a full month ahead, then steps back one day to land on the correct month-end regardless of month length. */
/* Q22. DST shifts wall-clock time forward/backward, which can make a local time ambiguous or nonexistent twice a year; India's IST has no DST, so Asia/Kolkata conversions are always a fixed +5:30 offset. */
/* Q23. age() can look "short" or "long" depending on month lengths (e.g. age('2025-03-01','2025-02-01') = 1 month even though only 28 days apart), unlike a flat day-count which is always exact. */
/* Q24. date_trunc('week', d) anchors to Monday (ISO); to anchor Sunday-start weeks instead you'd shift the date by a day before truncating, or use to_char with a custom offset. */
/* Q25. A time series that's queried repeatedly and changes slowly (e.g. daily revenue by region) is a strong materialized-view candidate - precompute once, REFRESH on a schedule, avoid recomputation per dashboard load. */

/* ============================================================
   SECTION B: BUCKETING & AGGREGATION (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT date_trunc('month', order_date)::date AS month,
       sum(net_total) AS revenue,
       count(*) AS orders,
       round(sum(net_total) / count(*), 2) AS aov
FROM sales.orders
WHERE extract(year FROM order_date) = 2025
GROUP BY 1
ORDER BY 1;

/* Q27. */
SELECT date_trunc('quarter', o.order_date)::date AS quarter, r.region_name, sum(o.net_total) AS revenue
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY 1, 2
ORDER BY 1, 2;

/* Q28. */
SELECT o.store_id, to_char(o.order_date, 'IYYY-IW') AS iso_week, count(*) AS orders
FROM sales.orders o
GROUP BY 1, 2
ORDER BY 1, 2;

/* Q29. */
SELECT o.store_id,
       sum(o.net_total) FILTER (WHERE extract(dow FROM o.order_date) = 0) AS sun,
       sum(o.net_total) FILTER (WHERE extract(dow FROM o.order_date) = 1) AS mon,
       sum(o.net_total) FILTER (WHERE extract(dow FROM o.order_date) = 2) AS tue,
       sum(o.net_total) FILTER (WHERE extract(dow FROM o.order_date) = 3) AS wed,
       sum(o.net_total) FILTER (WHERE extract(dow FROM o.order_date) = 4) AS thu,
       sum(o.net_total) FILTER (WHERE extract(dow FROM o.order_date) = 5) AS fri,
       sum(o.net_total) FILTER (WHERE extract(dow FROM o.order_date) = 6) AS sat
FROM sales.orders o
GROUP BY o.store_id
ORDER BY o.store_id
LIMIT 50;

/* Q30. */
SELECT extract(hour FROM view_timestamp)::int AS hour_of_day, device_type, count(*) AS page_views
FROM web_events.page_views
GROUP BY 1, 2
ORDER BY 1, 2;

/* Q31. */
SELECT month,
       count(*) FILTER (WHERE is_new) AS new_customers,
       count(*) FILTER (WHERE NOT is_new) AS returning_customers
FROM (
  SELECT o.order_id,
         date_trunc('month', o.order_date)::date AS month,
         o.order_date = first_order.first_order_date AS is_new
  FROM sales.orders o
  JOIN (SELECT cust_id, min(order_date) AS first_order_date FROM sales.orders GROUP BY cust_id) first_order
    ON first_order.cust_id = o.cust_id
) x
GROUP BY month
ORDER BY month;

/* Q32. */
SELECT extract(year FROM order_date)::int AS calendar_year,
       CASE WHEN extract(month FROM order_date) IN (4,5,6) THEN 1
            WHEN extract(month FROM order_date) IN (7,8,9) THEN 2
            WHEN extract(month FROM order_date) IN (10,11,12) THEN 3
            ELSE 4 END AS fiscal_quarter,
       sum(net_total) AS revenue
FROM sales.orders
GROUP BY 1, 2
ORDER BY 1, 2;

/* Q33. */
SELECT extract(month FROM order_date)::int AS month_num, to_char(order_date, 'Month') AS month_name, sum(net_total) AS revenue
FROM sales.orders
GROUP BY 1, 2
ORDER BY 1;

/* Q34. */
SELECT to_char(order_date, 'IYYY') AS iso_year, to_char(order_date, 'IW') AS iso_week, count(*) AS orders
FROM sales.orders
GROUP BY 1, 2
ORDER BY 1, 2;

/* Q35. */
SELECT r.region_name, date_trunc('month', o.order_date)::date AS month, sum(o.net_total) AS revenue
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
WHERE extract(year FROM o.order_date) = 2025
GROUP BY 1, 2
ORDER BY 1, 2;

/* Q36. */
SELECT date_trunc('month', o.order_date)::date AS month, avg(sh.delivered_date - o.order_date) AS avg_delivery_days
FROM sales.orders o
JOIN sales.shipments sh ON sh.order_id = o.order_id
WHERE sh.delivered_date IS NOT NULL
GROUP BY 1
ORDER BY 1;

/* Q37. */
SELECT to_char(created_date, 'Day') AS weekday, priority, count(*) AS tickets
FROM support.tickets
GROUP BY 1, priority, extract(dow FROM created_date)
ORDER BY extract(dow FROM created_date), priority;

/* Q38. */
SELECT extract(hour FROM call_start_time)::int AS hour_of_day,
       count(*) AS calls,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY call_duration_seconds) AS median_duration_sec
FROM call_center.calls
GROUP BY 1
ORDER BY 1;

/* Q39. */
SELECT month, new_customers,
       sum(new_customers) OVER (ORDER BY month) AS cumulative_customers
FROM (
  SELECT date_trunc('month', registration_date)::date AS month, count(*) AS new_customers
  FROM customers.customers
  GROUP BY 1
) m
ORDER BY month;

/* Q40. */
SELECT day, revenue,
       avg(revenue) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7day
FROM (
  SELECT d.day::date, coalesce(sum(o.net_total), 0) AS revenue
  FROM generate_series('2025-01-01'::date, '2025-12-31'::date, interval '1 day') AS d(day)
  LEFT JOIN sales.orders o ON o.order_date = d.day
  GROUP BY d.day
) daily
ORDER BY day;

/* Q41. */
SELECT date_trunc('month', o.order_date)::date AS month,
       count(DISTINCT r.return_id) AS returns,
       round(100.0 * count(DISTINCT r.return_id) / NULLIF(count(DISTINCT o.order_id), 0), 2) AS return_rate_pct
FROM sales.orders o
LEFT JOIN sales.returns r ON r.order_id = o.order_id
GROUP BY 1
ORDER BY 1;

/* Q42. */
SELECT slot_start, count(*) AS page_views
FROM (
  SELECT date_trunc('hour', view_timestamp) + floor(extract(minute FROM view_timestamp) / 15) * interval '15 min' AS slot_start
  FROM web_events.page_views
) x
GROUP BY slot_start
ORDER BY page_views DESC
LIMIT 10;

/* Q43. */
SELECT r.region_name,
       CASE WHEN extract(month FROM o.order_date) <= 6 THEN 'H1' ELSE 'H2' END AS half_year,
       sum(o.net_total) AS revenue
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY 1, 2
ORDER BY 1, 2;

/* Q44. */
SELECT date_trunc('month', order_date)::date AS month,
       count(*) FILTER (WHERE extract(dow FROM order_date) NOT IN (0,6)) AS weekday_orders,
       count(*) FILTER (WHERE extract(dow FROM order_date) IN (0,6)) AS weekend_orders
FROM sales.orders
GROUP BY 1
ORDER BY 1;

/* Q45. */
SELECT cat.category_name, extract(month FROM o.order_date)::int AS month_num, sum(oi.quantity) AS units_sold
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
WHERE extract(year FROM o.order_date) = 2025
GROUP BY 1, 2
ORDER BY 1, 2;

/* Q46. */
SELECT date_trunc('quarter', o.order_date)::date AS quarter, avg(item_counts.items_in_order) AS avg_basket_size
FROM (
  SELECT order_id, sum(quantity) AS items_in_order
  FROM sales.order_items
  GROUP BY order_id
) item_counts
JOIN sales.orders o ON o.order_id = item_counts.order_id
GROUP BY 1
ORDER BY 1;

/* Q47. */
SELECT r.region_name, date_trunc('month', o.order_date)::date AS month,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_order_value
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY 1, 2
ORDER BY 1, 2;

/* Q48. */
SELECT coalesce(a.month, o.month) AS month, coalesce(a.ad_spend, 0) AS ad_spend, coalesce(o.revenue, 0) AS revenue
FROM (SELECT date_trunc('month', spend_date)::date AS month, sum(amount) AS ad_spend FROM marketing.ads_spend GROUP BY 1) a
FULL OUTER JOIN (SELECT date_trunc('month', order_date)::date AS month, sum(net_total) AS revenue FROM sales.orders GROUP BY 1) o
  ON o.month = a.month
ORDER BY 1;

/* Q49. */
SELECT month_num, avg(monthly_revenue) AS avg_revenue_across_years
FROM (
  SELECT extract(year FROM order_date)::int AS yr, extract(month FROM order_date)::int AS month_num, sum(net_total) AS monthly_revenue
  FROM sales.orders
  GROUP BY 1, 2
) x
GROUP BY month_num
ORDER BY month_num;

/* Q50. */
SELECT month, revenue,
       lag(revenue, 12) OVER (ORDER BY month) AS revenue_prior_year,
       round(100.0 * (revenue - lag(revenue, 12) OVER (ORDER BY month)) / NULLIF(lag(revenue, 12) OVER (ORDER BY month), 0), 2) AS yoy_pct
FROM (
  SELECT date_trunc('month', order_date)::date AS month, sum(net_total) AS revenue
  FROM sales.orders
  GROUP BY 1
) m
ORDER BY month;

/* ============================================================
   SECTION C: GENERATE_SERIES, SPINES & GAP-FILL (25)
   ------------------------------------------------------------ */
/* Q51. */
SELECT d::date AS day,
       extract(dow FROM d)::int AS dow,
       extract(week FROM d)::int AS iso_week,
       extract(month FROM d)::int AS month,
       extract(quarter FROM d)::int AS quarter,
       (extract(dow FROM d) IN (0,6)) AS is_weekend
FROM generate_series('2024-01-01'::date, '2026-12-31'::date, interval '1 day') AS d;

/* Q52. */
SELECT d.day::date, coalesce(sum(o.net_total), 0) AS revenue
FROM generate_series((SELECT max(order_date) FROM sales.orders) - interval '89 days',
                      (SELECT max(order_date) FROM sales.orders), interval '1 day') AS d(day)
LEFT JOIN sales.orders o ON o.order_date = d.day::date
GROUP BY d.day
ORDER BY d.day;

/* Q53. */
SELECT s.store_id, d.day::date, coalesce(count(o.order_id), 0) AS orders
FROM stores.stores s
CROSS JOIN generate_series('2025-06-01'::date, '2025-06-30'::date, interval '1 day') AS d(day)
LEFT JOIN sales.orders o ON o.store_id = s.store_id AND o.order_date = d.day
GROUP BY s.store_id, d.day
ORDER BY s.store_id, d.day
LIMIT 200;

/* Q54. */
SELECT w.week_start::date, coalesce(sum(o.net_total), 0) AS revenue
FROM generate_series('2025-01-06'::date, '2025-12-29'::date, interval '7 days') AS w(week_start)
LEFT JOIN sales.orders o ON date_trunc('week', o.order_date) = w.week_start
GROUP BY w.week_start
ORDER BY w.week_start;

/* Q55. */
SELECT m.month::date, r.region_name, coalesce(sum(o.net_total), 0) AS revenue
FROM generate_series('2025-01-01'::date, '2025-12-01'::date, interval '1 month') AS m(month)
CROSS JOIN core.dim_region r
LEFT JOIN stores.stores s ON s.region_id = r.region_id
LEFT JOIN sales.orders o ON o.store_id = s.store_id AND date_trunc('month', o.order_date) = m.month
GROUP BY m.month, r.region_name
ORDER BY m.month, r.region_name
LIMIT 200;

/* Q56. */
SELECT h.hour, pv.device_type, coalesce(count(pv2.view_id), 0) AS page_views
FROM generate_series(0, 23) AS h(hour)
CROSS JOIN (SELECT DISTINCT device_type FROM web_events.page_views) pv
LEFT JOIN web_events.page_views pv2 ON pv2.device_type = pv.device_type AND extract(hour FROM pv2.view_timestamp) = h.hour
GROUP BY h.hour, pv.device_type
ORDER BY h.hour, pv.device_type;

/* Q57. */
SELECT week_start, revenue, lag(revenue) OVER (ORDER BY week_start) AS prev_week_revenue,
       revenue - lag(revenue) OVER (ORDER BY week_start) AS wow_change
FROM (
  SELECT w.week_start::date, coalesce(sum(o.net_total), 0) AS revenue
  FROM generate_series('2025-01-06'::date, '2025-12-29'::date, interval '7 days') AS w(week_start)
  LEFT JOIN sales.orders o ON date_trunc('week', o.order_date) = w.week_start
  GROUP BY w.week_start
) weekly
ORDER BY week_start;

/* Q58. */
SELECT c.customer_id, (c.registration_date + d)::date AS cohort_day, d AS day_index
FROM customers.customers c
CROSS JOIN generate_series(0, 29) AS d
WHERE c.customer_id IN (SELECT customer_id FROM customers.customers ORDER BY customer_id LIMIT 5)
ORDER BY c.customer_id, day_index;

/* Q59. */
SELECT day, active_customers,
       avg(active_customers) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7day
FROM (
  SELECT d.day::date, coalesce(count(DISTINCT o.cust_id), 0) AS active_customers
  FROM generate_series((SELECT max(order_date) FROM sales.orders) - interval '89 days',
                        (SELECT max(order_date) FROM sales.orders), interval '1 day') AS d(day)
  LEFT JOIN sales.orders o ON o.order_date = d.day::date
  GROUP BY d.day
) daily
ORDER BY day;

/* Q60. */
SELECT d.day::date,
       coalesce(o.orders, 0) AS orders,
       coalesce(r.returns, 0) AS returns,
       coalesce(p.payments, 0) AS payments
FROM generate_series('2025-06-01'::date, '2025-06-30'::date, interval '1 day') AS d(day)
LEFT JOIN (SELECT order_date, count(*) AS orders FROM sales.orders GROUP BY order_date) o ON o.order_date = d.day
LEFT JOIN (SELECT return_date, count(*) AS returns FROM sales.returns GROUP BY return_date) r ON r.return_date = d.day
LEFT JOIN (SELECT payment_date, count(*) AS payments FROM sales.payments GROUP BY payment_date) p ON p.payment_date = d.day
ORDER BY d.day;

/* Q61. */
SELECT q.quarter::date, coalesce(sum(o.net_total), 0) AS revenue
FROM generate_series('2024-01-01'::date, '2026-10-01'::date, interval '3 months') AS q(quarter)
LEFT JOIN sales.orders o ON date_trunc('quarter', o.order_date) = q.quarter
GROUP BY q.quarter
ORDER BY q.quarter;

/* Q62. */
SELECT day, new_customers,
       sum(new_customers) OVER (ORDER BY day) AS cumulative_customers
FROM (
  SELECT d.day::date, coalesce(count(c.customer_id), 0) AS new_customers
  FROM generate_series('2025-01-01'::date, '2025-12-31'::date, interval '1 day') AS d(day)
  LEFT JOIN customers.customers c ON c.registration_date = d.day
  GROUP BY d.day
) x
ORDER BY day;

/* Q63. */
SELECT slot.slot_start, pv.device_type, coalesce(count(pv2.view_id), 0) AS page_views
FROM generate_series('2025-06-02 00:00:00'::timestamp, '2025-06-02 23:45:00'::timestamp, interval '15 min') AS slot(slot_start)
CROSS JOIN (SELECT DISTINCT device_type FROM web_events.page_views) pv
LEFT JOIN web_events.page_views pv2 ON pv2.device_type = pv.device_type
  AND pv2.view_timestamp >= slot.slot_start AND pv2.view_timestamp < slot.slot_start + interval '15 min'
GROUP BY slot.slot_start, pv.device_type
ORDER BY page_views DESC
LIMIT 20;

/* Q64. */
SELECT r.region_name, d.day::date, coalesce(sum(o.net_total), 0) AS revenue,
       (coalesce(sum(o.net_total), 0) = 0) AS is_zero_revenue
FROM core.dim_region r
CROSS JOIN generate_series('2025-06-01'::date, '2025-06-30'::date, interval '1 day') AS d(day)
LEFT JOIN stores.stores s ON s.region_id = r.region_id
LEFT JOIN sales.orders o ON o.store_id = s.store_id AND o.order_date = d.day
GROUP BY r.region_name, d.day
ORDER BY r.region_name, d.day
LIMIT 200;

/* Q65. */
SELECT month, revenue,
       lag(revenue) OVER (ORDER BY month) AS prev_month_revenue,
       round(100.0 * (revenue - lag(revenue) OVER (ORDER BY month)) / NULLIF(lag(revenue) OVER (ORDER BY month), 0), 2) AS mom_growth_pct
FROM (
  SELECT m.month::date, coalesce(sum(o.net_total), 0) AS revenue
  FROM generate_series('2025-01-01'::date, '2025-12-01'::date, interval '1 month') AS m(month)
  LEFT JOIN sales.orders o ON date_trunc('month', o.order_date) = m.month
  GROUP BY m.month
) monthly
ORDER BY month;

/* Q66. */
SELECT d::date AS day,
       CASE WHEN extract(month FROM d) >= 4 THEN extract(year FROM d)::int ELSE extract(year FROM d)::int - 1 END AS fiscal_year,
       CASE WHEN extract(month FROM d) IN (4,5,6) THEN 1
            WHEN extract(month FROM d) IN (7,8,9) THEN 2
            WHEN extract(month FROM d) IN (10,11,12) THEN 3
            ELSE 4 END AS fiscal_quarter
FROM generate_series('2024-01-01'::date, '2026-12-31'::date, interval '1 day') AS d;

/* Q67. */
SELECT c.customer_id, m AS months_since_registration,
       date_trunc('month', c.registration_date)::date + (m || ' months')::interval AS activity_month
FROM customers.customers c
CROSS JOIN generate_series(0, 11) AS m
WHERE c.customer_id IN (SELECT customer_id FROM customers.customers ORDER BY customer_id LIMIT 5)
ORDER BY c.customer_id, m;

/* Q68. */
SELECT w.week_start::date, coalesce(sum(o.net_total), 0) AS revenue
FROM generate_series('2025-01-06'::date, '2025-12-29'::date, interval '7 days') AS w(week_start)
LEFT JOIN sales.orders o ON o.order_date >= w.week_start AND o.order_date < w.week_start + interval '7 days'
GROUP BY w.week_start
ORDER BY w.week_start;

/* Q69. */
SELECT day, refund_total,
       avg(refund_total) OVER (ORDER BY day ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) AS moving_avg_14day
FROM (
  SELECT d.day::date, coalesce(sum(r.refund_amount), 0) AS refund_total
  FROM generate_series('2025-01-01'::date, '2025-12-31'::date, interval '1 day') AS d(day)
  LEFT JOIN sales.returns r ON r.return_date = d.day
  GROUP BY d.day
) daily
ORDER BY day;

/* Q70. */
SELECT s.store_id, d.day::date
FROM stores.stores s
CROSS JOIN generate_series('2025-06-01'::date, '2025-06-30'::date, interval '1 day') AS d(day)
LEFT JOIN sales.orders o ON o.store_id = s.store_id AND o.order_date = d.day
WHERE o.order_id IS NULL
ORDER BY s.store_id, d.day
LIMIT 200;

/* Q71. */
SELECT c.customer_id, m::date AS activity_month
FROM customers.customers c
CROSS JOIN LATERAL generate_series(
  date_trunc('month', (SELECT min(order_date) FROM sales.orders o WHERE o.cust_id = c.customer_id)),
  date_trunc('month', (SELECT min(order_date) FROM sales.orders o WHERE o.cust_id = c.customer_id)) + interval '11 months',
  interval '1 month'
) AS m
WHERE c.customer_id IN (SELECT customer_id FROM customers.customers ORDER BY customer_id LIMIT 5)
  AND EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id)
ORDER BY c.customer_id, activity_month;

/* Q72. */
SELECT h.hour, wd.weekday_num, coalesce(count(pv.view_id), 0) AS page_views
FROM generate_series(0, 23) AS h(hour)
CROSS JOIN generate_series(0, 6) AS wd(weekday_num)
LEFT JOIN web_events.page_views pv ON extract(hour FROM pv.view_timestamp) = h.hour AND extract(dow FROM pv.view_timestamp) = wd.weekday_num
GROUP BY h.hour, wd.weekday_num
ORDER BY wd.weekday_num, h.hour;

/* Q73. */
SELECT d::date AS day,
       extract(dow FROM d)::int AS dow,
       to_char(d, 'IYYY-IW') AS iso_week,
       CASE WHEN extract(month FROM d) >= 4 THEN extract(year FROM d)::int ELSE extract(year FROM d)::int - 1 END AS fiscal_year,
       CASE WHEN extract(month FROM d) IN (4,5,6) THEN 1
            WHEN extract(month FROM d) IN (7,8,9) THEN 2
            WHEN extract(month FROM d) IN (10,11,12) THEN 3
            ELSE 4 END AS fiscal_quarter,
       extract(week FROM d)::int AS week_num
FROM generate_series('2020-01-01'::date, '2030-12-31'::date, interval '1 day') AS d
LIMIT 1000;

/* Q74. */
SELECT s.store_id, date_trunc('month', d.day)::date AS month, count(DISTINCT d.day) FILTER (WHERE o.order_id IS NOT NULL) AS active_days
FROM stores.stores s
CROSS JOIN generate_series('2025-06-01'::date, '2025-06-30'::date, interval '1 day') AS d(day)
LEFT JOIN sales.orders o ON o.store_id = s.store_id AND o.order_date = d.day
GROUP BY s.store_id, date_trunc('month', d.day)
ORDER BY s.store_id
LIMIT 50;

/* Q75. */
WITH order_days AS (
  SELECT DISTINCT store_id, order_date FROM sales.orders
),
grp AS (
  SELECT store_id, order_date,
         order_date - (row_number() OVER (PARTITION BY store_id ORDER BY order_date))::int AS grp_key
  FROM order_days
)
SELECT store_id, min(order_date) AS streak_start, max(order_date) AS streak_end, count(*) AS streak_len
FROM grp
GROUP BY store_id, grp_key
ORDER BY streak_len DESC
LIMIT 20;

/* ============================================================
   SECTION D: TIMEZONES, INTERVALS & TIME-SERIES (25)
   ------------------------------------------------------------ */
/* Q76. */
SELECT extract(hour FROM view_timestamp AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Kolkata')::int AS ist_hour, count(*) AS page_views
FROM web_events.page_views
GROUP BY 1
ORDER BY 1;

/* Q77. */
SELECT device_type, extract(hour FROM view_timestamp AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Kolkata')::int AS ist_hour, count(*) AS page_views
FROM web_events.page_views
GROUP BY 1, 2
ORDER BY 1, page_views DESC;

/* Q78. */
SELECT extract(hour FROM call_start_time AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Kolkata')::int AS ist_hour,
       count(*) AS calls,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY call_duration_seconds) AS median_duration_sec
FROM call_center.calls
GROUP BY 1
ORDER BY 1;

/* Q79. */
SELECT r.region_name,
       avg(sh.shipped_date - o.order_date) AS avg_days_to_ship,
       avg(sh.delivered_date - o.order_date) AS avg_days_to_deliver
FROM sales.orders o
JOIN sales.shipments sh ON sh.order_id = o.order_id
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;

/* Q80. */
SELECT date_trunc('month', o.order_date)::date AS month,
       round(100.0 * count(*) FILTER (WHERE sh.delivered_date - o.order_date <= 3) / NULLIF(count(*), 0), 2) AS pct_within_sla
FROM sales.orders o
JOIN sales.shipments sh ON sh.order_id = o.order_id
WHERE sh.delivered_date IS NOT NULL
GROUP BY 1
ORDER BY 1;

/* Q81. */
SELECT priority, date_trunc('month', created_date)::date AS month,
       round(100.0 * count(*) FILTER (WHERE resolved_date - created_date <= interval '24 hours') / NULLIF(count(*) FILTER (WHERE resolved_date IS NOT NULL), 0), 2) AS pct_within_24h
FROM support.tickets
GROUP BY 1, 2
ORDER BY 1, 2;

/* Q82. */
SELECT tier,
       CASE WHEN age(current_date, registration_date) < interval '1 year' THEN '<1yr'
            WHEN age(current_date, registration_date) < interval '2 years' THEN '1-2yr'
            ELSE '2yr+' END AS tenure_bucket,
       count(*) AS customers
FROM customers.customers
GROUP BY 1, 2
ORDER BY 1, 2;

/* Q83. */
SELECT month, avg(days_between) AS avg_days_between_orders
FROM (
  SELECT cust_id,
         date_trunc('month', order_date)::date AS month,
         order_date - lag(order_date) OVER (PARTITION BY cust_id ORDER BY order_date) AS days_between
  FROM sales.orders
) x
WHERE days_between IS NOT NULL
GROUP BY month
ORDER BY month;

/* Q84. */
SELECT r.region_name, month, revenue,
       round(100.0 * (revenue - lag(revenue) OVER (PARTITION BY r.region_name ORDER BY month)) / NULLIF(lag(revenue) OVER (PARTITION BY r.region_name ORDER BY month), 0), 2) AS mom_pct,
       round(100.0 * (revenue - lag(revenue, 12) OVER (PARTITION BY r.region_name ORDER BY month)) / NULLIF(lag(revenue, 12) OVER (PARTITION BY r.region_name ORDER BY month), 0), 2) AS yoy_pct
FROM (
  SELECT s.region_id, date_trunc('month', o.order_date)::date AS month, sum(o.net_total) AS revenue
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  GROUP BY 1, 2
) m
JOIN core.dim_region r ON r.region_id = m.region_id
ORDER BY r.region_name, month;

/* Q85. */
SELECT r.region_name, day, revenue,
       avg(revenue) OVER (PARTITION BY r.region_name ORDER BY day RANGE BETWEEN interval '27 days' PRECEDING AND CURRENT ROW) AS rolling_28day_revenue
FROM (
  SELECT s.region_id, d.day::date, coalesce(sum(o.net_total), 0) AS revenue
  FROM core.dim_region rg
  CROSS JOIN generate_series('2025-06-01'::date, '2025-08-31'::date, interval '1 day') AS d(day)
  JOIN stores.stores s ON s.region_id = rg.region_id
  LEFT JOIN sales.orders o ON o.store_id = s.store_id AND o.order_date = d.day
  GROUP BY s.region_id, d.day
) x
JOIN core.dim_region r ON r.region_id = x.region_id
ORDER BY r.region_name, day
LIMIT 200;

/* Q86. */
SELECT session_id, view_timestamp,
       view_timestamp - lag(view_timestamp) OVER (PARTITION BY session_id ORDER BY view_timestamp) AS inter_arrival
FROM web_events.page_views
ORDER BY session_id, view_timestamp
LIMIT 100;

/* Q87. */
SELECT r.region_name, date_trunc('quarter', o.order_date)::date AS quarter,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY sh.delivered_date - o.order_date) AS median_delivery_days
FROM sales.orders o
JOIN sales.shipments sh ON sh.order_id = o.order_id
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
WHERE sh.delivered_date IS NOT NULL
GROUP BY 1, 2
ORDER BY 1, 2;

/* Q88. */
SELECT to_char(order_date, 'IYYY-"W"IW') AS iso_year_week, sum(net_total) AS revenue
FROM sales.orders
GROUP BY 1
ORDER BY 1;

/* Q89. */
SELECT slot.dow, slot.slot_start, count(*) AS page_views
FROM (
  SELECT extract(dow FROM view_timestamp)::int AS dow,
         date_trunc('hour', view_timestamp) + floor(extract(minute FROM view_timestamp) / 15) * interval '15 min' AS slot_start
  FROM web_events.page_views
) slot
GROUP BY slot.dow, slot.slot_start
ORDER BY page_views DESC
LIMIT 10;

/* Q90. */
SELECT c.customer_id, min(o.order_date) - c.registration_date AS days_to_first_purchase
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY c.customer_id, c.registration_date
ORDER BY days_to_first_purchase
LIMIT 100;

/* Q91. */
SELECT cohort_month, count(DISTINCT customer_id) AS cohort_size,
       count(DISTINCT customer_id) FILTER (WHERE months_since = 1) AS month1_retained
FROM (
  SELECT c.customer_id,
         date_trunc('month', c.registration_date)::date AS cohort_month,
         date_trunc('month', o.order_date)::date AS order_month,
         (extract(year FROM o.order_date) - extract(year FROM c.registration_date)) * 12
         + (extract(month FROM o.order_date) - extract(month FROM c.registration_date)) AS months_since
  FROM customers.customers c
  JOIN sales.orders o ON o.cust_id = c.customer_id
) x
GROUP BY cohort_month
ORDER BY cohort_month;

/* Q92. Conceptual: page_views don't record revenue, so an hour-of-day revenue "proxy" needs to join orders to the customer's browsing session/timestamp (e.g. nearest page_view before the order) rather than a direct revenue column on events. */

/* Q93. */
SELECT event_type, extract(hour FROM event_timestamp)::int AS hour_of_day, count(*) AS events
FROM web_events.events
GROUP BY 1, 2
ORDER BY 1, 2;

/* Q94. */
SELECT day, revenue, revenue > p95.p95_revenue AS is_anomaly
FROM (
  SELECT d.day::date, coalesce(sum(o.net_total), 0) AS revenue
  FROM generate_series('2025-01-01'::date, '2025-12-31'::date, interval '1 day') AS d(day)
  LEFT JOIN sales.orders o ON o.order_date = d.day
  GROUP BY d.day
) daily
CROSS JOIN (
  SELECT percentile_cont(0.95) WITHIN GROUP (ORDER BY revenue) AS p95_revenue
  FROM (
    SELECT d.day::date, coalesce(sum(o.net_total), 0) AS revenue
    FROM generate_series('2025-01-01'::date, '2025-12-31'::date, interval '1 day') AS d(day)
    LEFT JOIN sales.orders o ON o.order_date = d.day
    GROUP BY d.day
  ) daily2
) p95
ORDER BY day;

/* Q95. */
SELECT month_num, revenue, annual_avg, round(revenue / NULLIF(annual_avg, 0), 3) AS seasonal_index
FROM (
  SELECT extract(month FROM order_date)::int AS month_num,
         sum(net_total) AS revenue,
         avg(sum(net_total)) OVER () AS annual_avg
  FROM sales.orders
  WHERE extract(year FROM order_date) = 2025
  GROUP BY 1
) x
ORDER BY month_num;

/* Q96. */
SELECT c.customer_id,
       greatest(coalesce(max(o.order_date)::timestamp, '-infinity'), coalesce(max(pv.view_timestamp), '-infinity')) AS latest_activity
FROM customers.customers c
LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
LEFT JOIN web_events.page_views pv ON pv.customer_id = c.customer_id
GROUP BY c.customer_id
HAVING max(o.order_date) IS NOT NULL OR max(pv.view_timestamp) IS NOT NULL
ORDER BY c.customer_id
LIMIT 100;

/* Q97. */
SELECT day, active_customers,
       avg(active_customers) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS rolling_7day_active
FROM (
  SELECT d.day::date, coalesce(count(DISTINCT o.cust_id), 0) AS active_customers
  FROM generate_series((SELECT max(order_date) FROM sales.orders) - interval '89 days',
                        (SELECT max(order_date) FROM sales.orders), interval '1 day') AS d(day)
  LEFT JOIN sales.orders o ON o.order_date = d.day::date
  GROUP BY d.day
) daily
ORDER BY day;

/* Q98. */
SELECT date_trunc('month', order_date)::date AS month,
       sum(net_total) FILTER (WHERE extract(day FROM order_date) <= 5) AS month_start_revenue,
       sum(net_total) FILTER (WHERE order_date >= date_trunc('month', order_date) + interval '1 month' - interval '5 days') AS month_end_revenue
FROM sales.orders
GROUP BY 1
ORDER BY 1;

/* Q99. */
SELECT r.region_name, month, revenue,
       round(100.0 * (revenue - lag(revenue) OVER (PARTITION BY r.region_name ORDER BY month)) / NULLIF(lag(revenue) OVER (PARTITION BY r.region_name ORDER BY month), 0), 2) AS mom_pct
FROM (
  SELECT s.region_id, date_trunc('month', o.order_date)::date AS month, sum(o.net_total) AS revenue
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  WHERE extract(year FROM o.order_date) = 2025
  GROUP BY 1, 2
) m
JOIN core.dim_region r ON r.region_id = m.region_id
ORDER BY r.region_name, month;

/* Q100. */
SELECT month, orders, revenue, aov,
       round(100.0 * (revenue - lag(revenue) OVER (ORDER BY month)) / NULLIF(lag(revenue) OVER (ORDER BY month), 0), 2) AS mom_pct,
       round(100.0 * (revenue - lag(revenue, 12) OVER (ORDER BY month)) / NULLIF(lag(revenue, 12) OVER (ORDER BY month), 0), 2) AS yoy_pct
FROM (
  SELECT date_trunc('month', order_date)::date AS month, count(*) AS orders, sum(net_total) AS revenue,
         round(sum(net_total) / count(*), 2) AS aov
  FROM sales.orders
  WHERE extract(year FROM order_date) = 2025
  GROUP BY 1
) m
ORDER BY month;

/* ============================================================
   END OF ANSWER KEY - MEDIUM LEVEL (100/100)
============================================================ */
