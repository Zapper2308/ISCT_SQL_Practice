/* ============================================================
   ANSWER KEY - Date/Time Mastery for Time-Series (EASY LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1. DATE_TRUNC('month', d) rounds a date/timestamp DOWN to the first day of its month (00:00:00), keeping the same data type. */
/* Q2. EXTRACT(YEAR FROM d) returns the 4-digit year component of a date/timestamp as a numeric value. */
/* Q3. A DATE stores only a calendar day (year/month/day); a TIMESTAMP additionally stores time-of-day (hour/min/sec/fraction). */
/* Q4. Order/delivery events in RetailMart are only ever reported at day granularity, so storing DATE (not TIMESTAMP) saves space and keeps grouping/joins simple. */
/* Q5. `date - date` returns an integer number of days between the two dates. */
/* Q6. `date + integer` returns a new DATE that many days later. */
/* Q7. An INTERVAL represents a span of time (e.g. 7 days, 3 months) that can be added to or subtracted from a date/timestamp. */
/* Q8. generate_series(a, b, step) produces a set of rows stepping from a to b (inclusive) by step - works for integers, dates, and timestamps. */
/* Q9. generate_series('2025-01-01'::date, '2025-01-31'::date, interval '1 day') returns one row per calendar day, used as an artificial date dimension. */
/* Q10. Gap-filling means LEFT JOINing a generated date series to real data so days/periods with zero activity still appear as a row (with COALESCE(count,0)) instead of being silently missing. */
/* Q11. to_char(d, 'YYYY-MM') produces a text label like '2025-03' for that date's year and month. */
/* Q12. EXTRACT(DOW FROM d) returns 0-6 where 0 = Sunday and 6 = Saturday. */
/* Q13. DOW is 0(Sun)-6(Sat); ISODOW is 1(Mon)-7(Sun), so Sunday is 0 in DOW but 7 in ISODOW. */
/* Q14. An ISO week is a Mon-Sun week where week 1 contains the year's first Thursday; the week near Jan 1 can therefore belong to the previous or next ISO year. */
/* Q15. date_trunc('week', d) anchors to Monday (the ISO week start), regardless of locale. */
/* Q16. date_trunc('month', d) gives the first day of that date's month. */
/* Q17. (date_trunc('month', d) + interval '1 month - 1 day')::date gives the last day of that date's month. */
/* Q18. age(d1, d2) returns a symbolic interval broken into years/months/days; plain d1 - d2 returns a flat integer count of days. */
/* Q19. now() returns the current timestamp with time zone; current_date returns just today's date. */
/* Q20. AT TIME ZONE converts a timestamp into (or out of) a given time zone's local wall-clock representation. */
/* Q21. Hour-of-day analysis needs the time-of-day component, which a DATE column simply doesn't store (EXTRACT(HOUR FROM a_date) is always 0). */
/* Q22. web_events.page_views.view_timestamp, call_center.calls.call_start_time, and support.tickets.created_date all carry real time-of-day. */
/* Q23. A fiscal quarter is a company-defined 3-month reporting period; RetailMart's fiscal year starts in April, so its Q1 is Apr-Jun, unlike the calendar Q1 (Jan-Mar). */
/* Q24. Bucket into 15-minute slots by flooring the timestamp's epoch seconds to the nearest 900-second multiple, then converting back to a timestamp. */
/* Q25. make_date(y, m, d) builds a DATE value from separate integer year, month, and day arguments. */

/* ============================================================
   SECTION B: TRUNC / EXTRACT / FORMAT (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT date_trunc('month', order_date)::date AS month, count(*) AS orders
FROM sales.orders
GROUP BY 1
ORDER BY 1;

/* Q27. */
SELECT date_trunc('year', order_date)::date AS year, count(*) AS orders
FROM sales.orders
GROUP BY 1
ORDER BY 1;

/* Q28. */
SELECT date_trunc('quarter', order_date)::date AS quarter, sum(net_total) AS revenue
FROM sales.orders
GROUP BY 1
ORDER BY 1;

/* Q29. */
SELECT to_char(order_date, 'Day') AS dow_name, count(*) AS orders
FROM sales.orders
GROUP BY 1, extract(dow FROM order_date)
ORDER BY extract(dow FROM order_date);

/* Q30. */
SELECT to_char(order_date, 'Month') AS month_name, count(*) AS orders
FROM sales.orders
GROUP BY 1, extract(month FROM order_date)
ORDER BY extract(month FROM order_date);

/* Q31. */
SELECT extract(year FROM order_date)::int AS yr, extract(month FROM order_date)::int AS mon, count(*) AS orders
FROM sales.orders
GROUP BY 1, 2
ORDER BY 1, 2;

/* Q32. */
SELECT date_trunc('week', order_date)::date AS week_start, sum(net_total) AS revenue
FROM sales.orders
GROUP BY 1
ORDER BY 1;

/* Q33. */
SELECT extract(year FROM registration_date)::int AS reg_year, count(*) AS customers
FROM customers.customers
GROUP BY 1
ORDER BY 1;

/* Q34. */
SELECT extract(hour FROM view_timestamp)::int AS hour_of_day, count(*) AS page_views
FROM web_events.page_views
GROUP BY 1
ORDER BY 1;

/* Q35. */
SELECT extract(hour FROM call_start_time)::int AS hour_of_day, count(*) AS calls
FROM call_center.calls
GROUP BY 1
ORDER BY 1;

/* Q36. */
SELECT date_trunc('month', created_date)::date AS month, count(*) AS tickets
FROM support.tickets
GROUP BY 1
ORDER BY 1;

/* Q37. */
SELECT date_trunc('quarter', order_date)::date AS quarter, count(*) AS orders
FROM sales.orders
WHERE extract(year FROM order_date) = 2025
GROUP BY 1
ORDER BY 1;

/* Q38. */
SELECT date_trunc('month', order_date)::date AS month, avg(net_total) AS avg_net_total
FROM sales.orders
WHERE extract(year FROM order_date) = 2025
GROUP BY 1
ORDER BY 1;

/* Q39. */
SELECT to_char(order_date, 'YYYY-MM') AS month_label, sum(net_total) AS revenue
FROM sales.orders
GROUP BY 1
ORDER BY 1;

/* Q40. */
SELECT CASE WHEN extract(dow FROM order_date) IN (0, 6) THEN 'Weekend' ELSE 'Weekday' END AS day_type,
       count(*) AS orders
FROM sales.orders
GROUP BY 1;

/* Q41. */
SELECT to_char(order_date, 'IYYY-IW') AS iso_week, count(*) AS orders
FROM sales.orders
WHERE extract(year FROM order_date) = 2025
GROUP BY 1
ORDER BY 1;

/* Q42. */
SELECT min(order_date) AS earliest_order, max(order_date) AS latest_order
FROM sales.orders;

/* Q43. */
SELECT o.order_id, s.delivered_date - o.order_date AS delivery_days
FROM sales.orders o
JOIN sales.shipments s ON s.order_id = o.order_id
WHERE s.delivered_date IS NOT NULL
ORDER BY o.order_id
LIMIT 100;

/* Q44. */
SELECT CASE WHEN s.delivered_date - o.order_date <= 2 THEN '0-2 days' ELSE '3+ days' END AS delivery_bucket,
       count(*) AS orders
FROM sales.orders o
JOIN sales.shipments s ON s.order_id = o.order_id
WHERE s.delivered_date IS NOT NULL
GROUP BY 1;

/* Q45. */
SELECT customer_id, to_char(registration_date, 'Month') AS reg_month_name
FROM customers.customers
ORDER BY customer_id
LIMIT 100;

/* Q46. */
SELECT CASE WHEN extract(month FROM order_date) <= 6 THEN 'H1' ELSE 'H2' END AS half_year,
       extract(year FROM order_date)::int AS yr,
       sum(net_total) AS revenue
FROM sales.orders
GROUP BY 1, 2
ORDER BY 2, 1;

/* Q47. */
SELECT date_trunc('month', review_date)::date AS month, count(*) AS reviews
FROM customers.reviews
GROUP BY 1
ORDER BY 1;

/* Q48. */
SELECT date_trunc('month', spend_date)::date AS month, platform, sum(amount) AS ad_spend
FROM marketing.ads_spend
GROUP BY 1, 2
ORDER BY 1, 2;

/* Q49. */
SELECT employee_id, salary_month, salary_year,
       to_date(salary_month || ' ' || salary_year, 'FMMonth YYYY') AS pay_period
FROM payroll.pay_slips
ORDER BY pay_period
LIMIT 100;

/* Q50. */
SELECT extract(day FROM order_date)::int AS day_of_month, count(*) AS orders
FROM sales.orders
GROUP BY 1
ORDER BY 1;

/* ============================================================
   SECTION C: GENERATE_SERIES & GAP-FILLING (25)
   ------------------------------------------------------------ */
/* Q51. */
SELECT d::date AS day
FROM generate_series('2025-01-01'::date, '2025-01-31'::date, interval '1 day') AS d;

/* Q52. */
SELECT d::date AS month_start
FROM generate_series('2025-01-01'::date, '2025-12-01'::date, interval '1 month') AS d;

/* Q53. */
SELECT d::date AS day,
       to_char(d, 'Day') AS dow_name,
       extract(week FROM d)::int AS week_num,
       to_char(d, 'Month') AS month_name
FROM generate_series('2025-01-01'::date, '2025-12-31'::date, interval '1 day') AS d
ORDER BY 1;

/* Q54. */
SELECT d.day::date, coalesce(count(o.order_id), 0) AS orders
FROM generate_series('2025-01-01'::date, '2025-01-31'::date, interval '1 day') AS d(day)
LEFT JOIN sales.orders o ON o.order_date = d.day
GROUP BY d.day
ORDER BY d.day;

/* Q55. */
SELECT d.day::date, coalesce(sum(o.net_total), 0) AS revenue
FROM generate_series('2025-06-01'::date, '2025-06-30'::date, interval '1 day') AS d(day)
LEFT JOIN sales.orders o ON o.order_date = d.day
GROUP BY d.day
ORDER BY d.day;

/* Q56. */
SELECT m.month::date, coalesce(sum(o.net_total), 0) AS revenue
FROM generate_series('2025-01-01'::date, '2025-12-01'::date, interval '1 month') AS m(month)
LEFT JOIN sales.orders o ON date_trunc('month', o.order_date) = m.month
GROUP BY m.month
ORDER BY m.month;

/* Q57. */
SELECT d::date AS day
FROM generate_series((SELECT max(order_date) FROM sales.orders) - interval '89 days',
                      (SELECT max(order_date) FROM sales.orders), interval '1 day') AS d;

/* Q58. */
SELECT d.day::date, coalesce(sum(o.net_total), 0) AS revenue
FROM generate_series((SELECT max(order_date) FROM sales.orders) - interval '89 days',
                      (SELECT max(order_date) FROM sales.orders), interval '1 day') AS d(day)
LEFT JOIN sales.orders o ON o.order_date = d.day::date
GROUP BY d.day
ORDER BY d.day;

/* Q59. */
SELECT w.week_start::date, coalesce(count(o.order_id), 0) AS orders
FROM generate_series('2025-01-06'::date, '2025-12-29'::date, interval '7 days') AS w(week_start)
LEFT JOIN sales.orders o ON date_trunc('week', o.order_date) = w.week_start
GROUP BY w.week_start
ORDER BY w.week_start;

/* Q60. */
SELECT h.hour, coalesce(count(pv.view_id), 0) AS page_views
FROM generate_series(0, 23) AS h(hour)
LEFT JOIN web_events.page_views pv ON extract(hour FROM pv.view_timestamp) = h.hour
GROUP BY h.hour
ORDER BY h.hour;

/* Q61. */
SELECT d::date AS monday
FROM generate_series('2025-01-06'::date, '2025-12-31'::date, interval '7 days') AS d;

/* Q62. */
SELECT d::date AS quarter_start
FROM generate_series('2025-01-01'::date, '2025-10-01'::date, interval '3 months') AS d;

/* Q63. */
SELECT d::date AS day,
       CASE WHEN extract(month FROM d) IN (4,5,6) THEN 1
            WHEN extract(month FROM d) IN (7,8,9) THEN 2
            WHEN extract(month FROM d) IN (10,11,12) THEN 3
            ELSE 4 END AS fiscal_quarter
FROM generate_series('2025-01-01'::date, '2025-12-31'::date, interval '1 day') AS d;

/* Q64. */
SELECT w.week_start::date, coalesce(count(r.return_id), 0) AS returns
FROM generate_series('2025-01-06'::date, '2025-12-29'::date, interval '7 days') AS w(week_start)
LEFT JOIN sales.returns r ON date_trunc('week', r.return_date) = w.week_start
GROUP BY w.week_start
ORDER BY w.week_start;

/* Q65. */
SELECT d.day::date, coalesce(count(c.customer_id), 0) AS new_customers
FROM generate_series('2025-01-01'::date, '2025-01-31'::date, interval '1 day') AS d(day)
LEFT JOIN customers.customers c ON c.registration_date = d.day
GROUP BY d.day
ORDER BY d.day;

/* Q66. */
SELECT s.store_id, d.day::date, coalesce(count(o.order_id), 0) AS orders
FROM stores.stores s
CROSS JOIN generate_series('2025-03-01'::date, '2025-03-31'::date, interval '1 day') AS d(day)
LEFT JOIN sales.orders o ON o.store_id = s.store_id AND o.order_date = d.day
GROUP BY s.store_id, d.day
ORDER BY s.store_id, d.day
LIMIT 200;

/* Q67. */
SELECT d::date AS month_start
FROM generate_series('2025-01-01'::date, '2025-12-01'::date, interval '1 month') AS d;

/* Q68. */
SELECT d.day::date, coalesce(sum(r.refund_amount), 0) AS refund_total
FROM generate_series('2025-01-01'::date, '2025-01-31'::date, interval '1 day') AS d(day)
LEFT JOIN sales.returns r ON r.return_date = d.day
GROUP BY d.day
ORDER BY d.day;

/* Q69. */
SELECT d AS slot_start
FROM generate_series('2025-01-01 00:00:00'::timestamp, '2025-01-01 23:45:00'::timestamp, interval '15 min') AS d;

/* Q70. */
SELECT n AS week_num
FROM generate_series(1, 52) AS n;

/* Q71. */
SELECT d::date AS day, (extract(dow FROM d) IN (0, 6)) AS is_weekend
FROM generate_series('2025-01-01'::date, '2025-12-31'::date, interval '1 day') AS d;

/* Q72. */
SELECT d::date AS day, (extract(isodow FROM d) IN (6, 7)) AS is_indian_weekend
FROM generate_series('2025-01-01'::date, '2025-12-31'::date, interval '1 day') AS d;

/* Q73. */
SELECT d.day::date, coalesce(count(DISTINCT o.cust_id), 0) AS distinct_customers
FROM generate_series((SELECT max(order_date) FROM sales.orders) - interval '29 days',
                      (SELECT max(order_date) FROM sales.orders), interval '1 day') AS d(day)
LEFT JOIN sales.orders o ON o.order_date = d.day::date
GROUP BY d.day
ORDER BY d.day;

/* Q74. */
SELECT c.customer_id, (c.registration_date + d)::date AS series_date
FROM customers.customers c
CROSS JOIN generate_series(0, 29) AS d
WHERE c.customer_id = (SELECT min(customer_id) FROM customers.customers)
ORDER BY series_date;

/* Q75. */
SELECT d.day::date,
       coalesce(count(c.customer_id), 0) AS new_registrations,
       sum(coalesce(count(c.customer_id), 0)) OVER (ORDER BY d.day) AS cumulative_registrations
FROM generate_series('2025-01-01'::date, '2025-12-31'::date, interval '1 day') AS d(day)
LEFT JOIN customers.customers c ON c.registration_date = d.day
GROUP BY d.day
ORDER BY d.day
LIMIT 20;

/* ============================================================
   SECTION D: INTERVALS, TIMEZONES & BUCKETS (25)
   ------------------------------------------------------------ */
/* Q76. */
SELECT order_id, order_date, order_date + interval '7 days' AS order_date_plus_7
FROM sales.orders
ORDER BY order_id
LIMIT 100;

/* Q77. */
SELECT *
FROM sales.orders
WHERE order_date >= (SELECT max(order_date) FROM sales.orders) - interval '30 days'
ORDER BY order_date
LIMIT 100;

/* Q78. */
SELECT c.customer_id, c.registration_date, min(o.order_date) AS first_order
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY c.customer_id, c.registration_date
HAVING min(o.order_date) - c.registration_date > 365
ORDER BY c.customer_id
LIMIT 100;

/* Q79. */
SELECT view_id, view_timestamp,
       (view_timestamp AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Kolkata') AS view_timestamp_ist
FROM web_events.page_views
ORDER BY view_id
LIMIT 100;

/* Q80. */
SELECT extract(hour FROM view_timestamp AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Kolkata')::int AS ist_hour,
       count(*) AS page_views
FROM web_events.page_views
GROUP BY 1
ORDER BY 1;

/* Q81. */
SELECT extract(hour FROM view_timestamp AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Kolkata')::int AS ist_hour,
       count(*) AS page_views
FROM web_events.page_views
GROUP BY 1
ORDER BY page_views DESC
LIMIT 1;

/* Q82. */
SELECT extract(hour FROM call_start_time)::int AS hour_of_day, count(*) AS calls
FROM call_center.calls
GROUP BY 1
ORDER BY 1;

/* Q83. */
SELECT date_trunc('hour', view_timestamp) + floor(extract(minute FROM view_timestamp) / 15) * interval '15 min' AS slot_start,
       count(*) AS page_views
FROM web_events.page_views
GROUP BY 1
ORDER BY page_views DESC
LIMIT 10;

/* Q84. */
SELECT ticket_id, resolved_date, created_date,
       extract(epoch FROM (resolved_date - created_date)) / 3600.0 AS hours_to_resolve
FROM support.tickets
WHERE resolved_date IS NOT NULL
ORDER BY ticket_id
LIMIT 100;

/* Q85. */
SELECT CASE WHEN resolved_date - created_date <= interval '24 hours' THEN 'Within 24h' ELSE 'Longer' END AS sla_bucket,
       count(*) AS tickets
FROM support.tickets
WHERE resolved_date IS NOT NULL
GROUP BY 1;

/* Q86. */
SELECT o.order_id, s.shipped_date - o.order_date AS days_to_ship
FROM sales.orders o
JOIN sales.shipments s ON s.order_id = o.order_id
WHERE s.shipped_date IS NOT NULL AND s.shipped_date - o.order_date <= 1
ORDER BY o.order_id
LIMIT 100;

/* Q87. */
SELECT r.region_name, avg(s.delivered_date - o.order_date) AS avg_delivery_days
FROM sales.orders o
JOIN sales.shipments s ON s.order_id = o.order_id
JOIN stores.stores st ON st.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = st.region_id
WHERE s.delivered_date IS NOT NULL
GROUP BY r.region_name
ORDER BY r.region_name;

/* Q88. */
SELECT view_id, view_timestamp,
       CASE WHEN extract(hour FROM view_timestamp) BETWEEN 5 AND 11 THEN 'Morning'
            WHEN extract(hour FROM view_timestamp) BETWEEN 12 AND 16 THEN 'Afternoon'
            WHEN extract(hour FROM view_timestamp) BETWEEN 17 AND 20 THEN 'Evening'
            ELSE 'Night' END AS day_part
FROM web_events.page_views
ORDER BY view_id
LIMIT 100;

/* Q89. */
SELECT c.customer_id, current_date - max(o.order_date) AS days_since_last_order
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY c.customer_id
ORDER BY c.customer_id
LIMIT 100;

/* Q90. */
SELECT customer_id, age(current_date, registration_date) AS tenure
FROM customers.customers
ORDER BY customer_id
LIMIT 100;

/* Q91. */
SELECT to_char(order_date, 'IYYY-"W"IW') AS iso_year_week, sum(net_total) AS revenue
FROM sales.orders
GROUP BY 1
ORDER BY 1;

/* Q92. */
SELECT extract(year FROM order_date)::int AS calendar_year,
       CASE WHEN extract(month FROM order_date) IN (4,5,6) THEN 1
            WHEN extract(month FROM order_date) IN (7,8,9) THEN 2
            WHEN extract(month FROM order_date) IN (10,11,12) THEN 3
            ELSE 4 END AS fiscal_quarter,
       count(*) AS orders
FROM sales.orders
GROUP BY 1, 2
ORDER BY 1, 2;

/* Q93. */
SELECT month, revenue,
       round(100.0 * (revenue - lag(revenue) OVER (ORDER BY month)) / NULLIF(lag(revenue) OVER (ORDER BY month), 0), 2) AS mom_growth_pct
FROM (
  SELECT date_trunc('month', order_date)::date AS month, sum(net_total) AS revenue
  FROM sales.orders
  GROUP BY 1
) monthly
ORDER BY month;

/* Q94. */
SELECT day, orders,
       avg(orders) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS rolling_7day_orders
FROM (
  SELECT d.day::date, coalesce(count(o.order_id), 0) AS orders
  FROM generate_series('2025-01-01'::date, '2025-03-31'::date, interval '1 day') AS d(day)
  LEFT JOIN sales.orders o ON o.order_date = d.day
  GROUP BY d.day
) daily
ORDER BY day;

/* Q95. */
SELECT c.customer_id,
       least(min(o.order_date), min(pv.view_timestamp)::date) AS first_activity,
       greatest(max(o.order_date), max(pv.view_timestamp)::date) AS last_activity
FROM customers.customers c
LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
LEFT JOIN web_events.page_views pv ON pv.customer_id = c.customer_id
GROUP BY c.customer_id
HAVING min(o.order_date) IS NOT NULL OR min(pv.view_timestamp) IS NOT NULL
ORDER BY c.customer_id
LIMIT 100;

/* Q96. */
SELECT to_char(event_timestamp, 'Day') AS weekday, extract(hour FROM event_timestamp)::int AS hour_of_day, count(*) AS events
FROM web_events.events
GROUP BY 1, 2, extract(dow FROM event_timestamp)
ORDER BY extract(dow FROM event_timestamp), hour_of_day;

/* Q97. */
SELECT date_trunc('month', order_date)::date AS month,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY net_total) AS median_order_value
FROM sales.orders
GROUP BY 1
ORDER BY 1;

/* Q98. */
SELECT DISTINCT ON (o.cust_id) o.cust_id, o.order_id, o.order_date,
       current_date - o.order_date AS days_since
FROM sales.orders o
ORDER BY o.cust_id, o.order_date DESC;

/* Q99. */
SELECT day, revenue,
       avg(revenue) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7day
FROM (
  SELECT d.day::date, coalesce(sum(o.net_total), 0) AS revenue
  FROM generate_series((SELECT max(order_date) FROM sales.orders) - interval '89 days',
                        (SELECT max(order_date) FROM sales.orders), interval '1 day') AS d(day)
  LEFT JOIN sales.orders o ON o.order_date = d.day::date
  GROUP BY d.day
) daily
ORDER BY day;

/* Q100. */
SELECT month, orders, revenue,
       round(100.0 * (revenue - lag(revenue) OVER (ORDER BY month)) / NULLIF(lag(revenue) OVER (ORDER BY month), 0), 2) AS mom_pct
FROM (
  SELECT date_trunc('month', order_date)::date AS month, count(*) AS orders, sum(net_total) AS revenue
  FROM sales.orders
  WHERE extract(year FROM order_date) = 2025
  GROUP BY 1
) monthly
ORDER BY month;

/* ============================================================
   END OF ANSWER KEY - EASY LEVEL (100/100)
============================================================ */
