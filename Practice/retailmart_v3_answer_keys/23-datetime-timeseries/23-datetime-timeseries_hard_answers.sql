/* ============================================================
   ANSWER KEY - Date/Time Mastery for Time-Series (HARD LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1. A reusable date dimension needs date_key (PK, grain = 1 day), plus day/month/year/quarter, day_name/month_name, iso_week, fiscal_year/quarter, and is_weekend flags; index the PK and any commonly-filtered flag column. */
/* Q2. generate_series(start,end,'1 day') produces the whole spine in one set-based scan the planner can pipeline; recursive CTEs iterate row-by-row and are typically slower and harder for the optimizer to reason about at scale. */
/* Q3. Number each row within a partition (e.g. per customer, ordered by date), then compute date - (row_number as days); rows in the same unbroken run share the same result, so grouping by that value isolates each island. */
/* Q4. ROWS frames count a fixed number of physical rows (works even with gaps, but can include the "wrong" days if some are missing); RANGE frames span a logical date/value window (e.g. 7 days back), which is correct for calendars with gaps but requires ORDER BY on the range column. */
/* Q5. Use to_char(d,'IYYY') (not EXTRACT(year)) paired with to_char(d,'IW') so the year label matches the ISO week itself - late-Dec dates in week 1 of the next ISO year get IYYY = next year, avoiding a mismatched label. */
/* Q6. Shift the month by an offset (fiscal_month = ((month - offset - 1 + 12) % 12) + 1) before bucketing into quarters/periods, and label fiscal_year based on whether the calendar month is on/after the fiscal start month. */
/* Q7. Store all timestamps in UTC (or TIMESTAMPTZ) at write time; convert to each viewer's zone only at display/report time using AT TIME ZONE; since India has no DST, Asia/Kolkata conversions are a fixed, always-correct +5:30 offset. */
/* Q8. Peak-hour analysis needs true time-of-day, which only genuine TIMESTAMP columns carry - in RetailMart that's page_views.view_timestamp, calls.call_start_time, tickets.created_date/resolved_date, and audit tables' timestamp columns. */
/* Q9. floor(extract(epoch from ts) / bucket_seconds) * bucket_seconds gives the bucket's epoch start for ANY bucket width (60s, 900s, 3600s, ...); to_timestamp() converts that back to a timestamp - a single generalized formula. */
/* Q10. Cohort analysis anchors each entity to an event date (registration/first order = period 0), buckets subsequent activity into period offsets (months/weeks since anchor), then arranges cohort x period counts into a triangle (later cohorts have fewer observed periods). */
/* Q11. A sparse series has real gaps where no aggregate row exists; averaging window functions over it silently skip those days instead of treating them as zero, understating the moving average - gap-filling with a spine first makes every day present. */
/* Q12. LAG(metric) OVER (ORDER BY period) on a COMPLETE spine gives the true prior period's value (0 or real), so (metric - LAG(metric))/LAG(metric) is a correct growth rate even across zero-activity periods. */
/* Q13. A period with truly zero orders should show 0% growth math correctly as long as the denominator isn't also zero; NULLIF(prior,0) avoids a divide-by-zero error, and the result should be NULL (undefined growth), not silently coerced to 0, when there's nothing to compare against. */
/* Q14. Detect streaks with the row_number-minus-date trick per entity, then find where a run ends and the next run's start date jumps by more than 1 day - that boundary is the break. */
/* Q15. A btree index on the raw timestamp supports equality and simple range scans (WHERE ts BETWEEN a AND b) efficiently; for dashboards filtering by date ranges this is usually the right primary index. */
/* Q16. date_trunc(ts) in a WHERE clause prevents the planner from using a plain btree index on ts, since the index is built on raw values, not truncated ones; an expression index (CREATE INDEX ON tbl (date_trunc('day', ts))) fixes it by indexing the exact expression used in the query. */
/* Q17. Sessionize by ordering events per customer/session key by timestamp, computing the gap to the previous event via LAG, and starting a new session whenever that gap exceeds the inactivity threshold (e.g. 30 minutes) - a running SUM of "new session" flags gives session ids. */
/* Q18. Time-weighted averages multiply each value by the DURATION it held that value (a step function), sum those products, and divide by total elapsed time - simple row averages overweight brief spikes and underweight long stable periods. */
/* Q19. A calendar heatmap needs one row per (weekday, hour) with a count/metric - built by EXTRACT(dow) and EXTRACT(hour) as the two grouping keys, ideally cross-joined against a full weekday x hour spine so empty cells still render as 0. */
/* Q20. Idempotent backfill means re-running the same date range's computation always produces the identical result - typically DELETE the target date range then INSERT the recomputed rows (or use an upsert), so reruns never double-count. */
/* Q21. Median is robust to outliers and reflects the "typical" delivery experience; the mean can be dragged upward by a few very slow deliveries, making the SLA look worse (or better, if skew is asymmetric) than what most customers actually experienced. */
/* Q22. Choose day grain for operational dashboards needing daily drill-down, week grain to smooth day-of-week noise for trend-watching, and month grain for executive/seasonal reporting - finer grain always costs more compute/storage for marginal insight at higher levels. */
/* Q23. EXTRACT(epoch FROM interval) gives raw seconds assuming a fixed-length day; across a DST transition a "24-hour" local day can actually be 23 or 25 real hours, so epoch-based duration math can misstate elapsed wall-clock time in DST-observing zones (not a concern for IST, which has none). */
/* Q24. A materialized daily-revenue table precomputes the expensive spine+join+aggregate once; dashboards then do a cheap SELECT against it instead of re-scanning millions of order rows on every page load, at the cost of needing a periodic REFRESH. */
/* Q25. An as-of join picks, for each spine date, the latest fact row with a timestamp <= that date (commonly via LATERAL + ORDER BY ts DESC LIMIT 1, or DISTINCT ON), reconstructing what the "current" state was at that point in time. */

/* ============================================================
   SECTION B: TIME-SERIES REPORTS (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT day, revenue,
       avg(revenue) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS ma_7day,
       avg(revenue) OVER (ORDER BY day ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) AS ma_28day
FROM (
  SELECT d.day::date, coalesce(sum(o.net_total), 0) AS revenue
  FROM generate_series((SELECT max(order_date) FROM sales.orders) - interval '89 days',
                        (SELECT max(order_date) FROM sales.orders), interval '1 day') AS d(day)
  LEFT JOIN sales.orders o ON o.order_date = d.day::date
  GROUP BY d.day
) daily
ORDER BY day;

/* Q27. */
SELECT region_name, month, revenue,
       round(100.0 * (revenue - lag(revenue) OVER (PARTITION BY region_name ORDER BY month)) / NULLIF(lag(revenue) OVER (PARTITION BY region_name ORDER BY month), 0), 2) AS mom_pct,
       round(100.0 * (revenue - lag(revenue, 12) OVER (PARTITION BY region_name ORDER BY month)) / NULLIF(lag(revenue, 12) OVER (PARTITION BY region_name ORDER BY month), 0), 2) AS yoy_pct
FROM (
  SELECT r.region_name, m.month::date,
         coalesce(sum(o.net_total), 0) AS revenue
  FROM core.dim_region r
  CROSS JOIN generate_series('2024-01-01'::date, '2026-01-01'::date, interval '1 month') AS m(month)
  LEFT JOIN stores.stores s ON s.region_id = r.region_id
  LEFT JOIN sales.orders o ON o.store_id = s.store_id AND date_trunc('month', o.order_date) = m.month
  GROUP BY r.region_name, m.month
) x
ORDER BY region_name, month;

/* Q28. */
WITH order_days AS (
  SELECT DISTINCT store_id, order_date FROM sales.orders
),
grp AS (
  SELECT store_id, order_date,
         order_date - (row_number() OVER (PARTITION BY store_id ORDER BY order_date))::int AS grp_key
  FROM order_days
)
SELECT store_id, max(streak_len) AS longest_streak
FROM (
  SELECT store_id, grp_key, count(*) AS streak_len
  FROM grp
  GROUP BY store_id, grp_key
) s
GROUP BY store_id
ORDER BY longest_streak DESC
LIMIT 20;

/* Q29. */
WITH ordered AS (
  SELECT customer_id, view_timestamp,
         lag(view_timestamp) OVER (PARTITION BY customer_id ORDER BY view_timestamp) AS prev_ts
  FROM web_events.page_views
  WHERE customer_id IS NOT NULL
),
flagged AS (
  SELECT customer_id, view_timestamp,
         CASE WHEN prev_ts IS NULL OR view_timestamp - prev_ts > interval '30 min' THEN 1 ELSE 0 END AS new_session
  FROM ordered
),
sessioned AS (
  SELECT customer_id, view_timestamp,
         sum(new_session) OVER (PARTITION BY customer_id ORDER BY view_timestamp) AS session_num
  FROM flagged
)
SELECT customer_id, count(DISTINCT session_num) AS sessions
FROM sessioned
GROUP BY customer_id
ORDER BY sessions DESC
LIMIT 20;

/* Q30. */
SELECT day, active_customers,
       avg(active_customers) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS ma_7day,
       round(100.0 * (active_customers - lag(active_customers, 7) OVER (ORDER BY day)) / NULLIF(lag(active_customers, 7) OVER (ORDER BY day), 0), 2) AS wow_pct
FROM (
  SELECT d.day::date, coalesce(count(DISTINCT o.cust_id), 0) AS active_customers
  FROM generate_series((SELECT max(order_date) FROM sales.orders) - interval '89 days',
                        (SELECT max(order_date) FROM sales.orders), interval '1 day') AS d(day)
  LEFT JOIN sales.orders o ON o.order_date = d.day::date
  GROUP BY d.day
) daily
ORDER BY day;

/* Q31. */
SELECT iso_year_week, revenue, rank() OVER (ORDER BY revenue DESC) AS revenue_rank
FROM (
  SELECT to_char(order_date, 'IYYY-IW') AS iso_year_week, sum(net_total) AS revenue
  FROM sales.orders
  WHERE order_date BETWEEN '2024-01-01' AND '2026-12-31'
  GROUP BY 1
) w
ORDER BY iso_year_week;

/* Q32. */
SELECT region_name, fiscal_year, fiscal_quarter, revenue,
       round(100.0 * (revenue - lag(revenue) OVER (PARTITION BY region_name ORDER BY fiscal_year, fiscal_quarter)) / NULLIF(lag(revenue) OVER (PARTITION BY region_name ORDER BY fiscal_year, fiscal_quarter), 0), 2) AS qoq_pct
FROM (
  SELECT r.region_name,
         CASE WHEN extract(month FROM o.order_date) >= 4 THEN extract(year FROM o.order_date)::int ELSE extract(year FROM o.order_date)::int - 1 END AS fiscal_year,
         CASE WHEN extract(month FROM o.order_date) IN (4,5,6) THEN 1
              WHEN extract(month FROM o.order_date) IN (7,8,9) THEN 2
              WHEN extract(month FROM o.order_date) IN (10,11,12) THEN 3
              ELSE 4 END AS fiscal_quarter,
         sum(o.net_total) AS revenue
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  JOIN core.dim_region r ON r.region_id = s.region_id
  GROUP BY 1, 2, 3
) x
ORDER BY region_name, fiscal_year, fiscal_quarter;

/* Q33. */
SELECT dow, hour_of_day, revenue_proxy_views
FROM (
  SELECT extract(dow FROM view_timestamp)::int AS dow, extract(hour FROM view_timestamp)::int AS hour_of_day, count(*) AS revenue_proxy_views
  FROM web_events.page_views
  GROUP BY 1, 2
) h
ORDER BY revenue_proxy_views DESC
LIMIT 15;

/* Q34. */
SELECT day, active_base, active_in_window,
       round(100.0 * active_in_window / NULLIF(active_base, 0), 2) AS retention_pct
FROM (
  SELECT d.day::date AS day,
         (SELECT count(DISTINCT cust_id) FROM sales.orders o WHERE o.order_date <= d.day::date) AS active_base,
         (SELECT count(DISTINCT cust_id) FROM sales.orders o WHERE o.order_date > d.day::date - 28 AND o.order_date <= d.day::date) AS active_in_window
  FROM generate_series((SELECT max(order_date) FROM sales.orders) - interval '29 days',
                        (SELECT max(order_date) FROM sales.orders), interval '1 day') AS d(day)
) x
ORDER BY day;

/* Q35. */
SELECT month,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY delivery_days) AS median_days,
       percentile_cont(0.95) WITHIN GROUP (ORDER BY delivery_days) AS p95_days
FROM (
  SELECT date_trunc('month', o.order_date)::date AS month, sh.delivered_date - o.order_date AS delivery_days
  FROM sales.orders o
  JOIN sales.shipments sh ON sh.order_id = o.order_id
  WHERE sh.delivered_date IS NOT NULL
) x
GROUP BY month
ORDER BY month;

/* Q36. */
SELECT month,
       sum(net_total) FILTER (WHERE is_first_order) AS new_revenue,
       sum(net_total) FILTER (WHERE NOT is_first_order) AS returning_revenue
FROM (
  SELECT o.order_id, o.net_total, date_trunc('month', o.order_date)::date AS month,
         o.order_date = f.first_order_date AS is_first_order
  FROM sales.orders o
  JOIN (SELECT cust_id, min(order_date) AS first_order_date FROM sales.orders GROUP BY cust_id) f
    ON f.cust_id = o.cust_id
) x
GROUP BY month
ORDER BY month;

/* Q37. */
SELECT cohort_month, months_since, count(DISTINCT customer_id) AS orderers
FROM (
  SELECT c.customer_id,
         date_trunc('month', c.registration_date)::date AS cohort_month,
         (extract(year FROM o.order_date) - extract(year FROM c.registration_date)) * 12
         + (extract(month FROM o.order_date) - extract(month FROM c.registration_date)) AS months_since
  FROM customers.customers c
  JOIN sales.orders o ON o.cust_id = c.customer_id
) t
WHERE months_since BETWEEN 0 AND 11
GROUP BY cohort_month, months_since
ORDER BY cohort_month, months_since;

/* Q38. */
SELECT dow, slot_start, orders, page_views
FROM (
  SELECT extract(dow FROM ts)::int AS dow,
         date_trunc('hour', ts) + floor(extract(minute FROM ts) / 15) * interval '15 min' AS slot_start,
         count(*) FILTER (WHERE src = 'order') AS orders,
         count(*) FILTER (WHERE src = 'view') AS page_views
  FROM (
    SELECT order_date::timestamp AS ts, 'order' AS src FROM sales.orders
    UNION ALL
    SELECT view_timestamp AS ts, 'view' AS src FROM web_events.page_views
  ) combined
  GROUP BY 1, 2
) x
ORDER BY orders DESC, page_views DESC
LIMIT 15;

/* Q39. */
SELECT day, revenue, p95.p95_revenue, revenue > p95.p95_revenue AS is_anomaly
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

/* Q40. */
SELECT month, revenue,
       avg(revenue) OVER (ORDER BY month ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS trailing_12mo_avg
FROM (
  SELECT date_trunc('month', order_date)::date AS month, sum(net_total) AS revenue
  FROM sales.orders
  GROUP BY 1
) m
ORDER BY month;

/* Q41. */
SELECT cohort_month,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY days_to_first_order) AS median_days,
       percentile_cont(0.9) WITHIN GROUP (ORDER BY days_to_first_order) AS p90_days
FROM (
  SELECT c.customer_id, date_trunc('month', c.registration_date)::date AS cohort_month,
         min(o.order_date) - c.registration_date AS days_to_first_order
  FROM customers.customers c
  JOIN sales.orders o ON o.cust_id = c.customer_id
  GROUP BY c.customer_id, c.registration_date
) x
GROUP BY cohort_month
ORDER BY cohort_month;

/* Q42. */
SELECT tier,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY gap_days) AS median_gap,
       percentile_cont(0.9) WITHIN GROUP (ORDER BY gap_days) AS p90_gap
FROM (
  SELECT c.tier, o.order_date - lag(o.order_date) OVER (PARTITION BY o.cust_id ORDER BY o.order_date) AS gap_days
  FROM sales.orders o
  JOIN customers.customers c ON c.customer_id = o.cust_id
) x
WHERE gap_days IS NOT NULL
GROUP BY tier
ORDER BY tier;

/* Q43. */
SELECT iso_year_week, refund_rate,
       avg(refund_rate) OVER (ORDER BY iso_year_week ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS ma_4week
FROM (
  SELECT to_char(o.order_date, 'IYYY-IW') AS iso_year_week,
         round(100.0 * count(DISTINCT r.return_id) / NULLIF(count(DISTINCT o.order_id), 0), 2) AS refund_rate
  FROM sales.orders o
  LEFT JOIN sales.returns r ON r.order_id = o.order_id
  GROUP BY 1
) w
ORDER BY iso_year_week;

/* Q44. */
SELECT priority, date_trunc('month', created_date)::date AS month,
       round(100.0 * count(*) FILTER (WHERE resolved_date - created_date <= interval '24 hours') / NULLIF(count(*) FILTER (WHERE resolved_date IS NOT NULL), 0), 2) AS sla_attainment_pct
FROM support.tickets
GROUP BY 1, 2
ORDER BY 1, 2;

/* Q45. */
SELECT w.warehouse_id, m.month_end,
       (SELECT s.quantity_on_hand
        FROM supply_chain.inventory_snapshots s
        WHERE s.warehouse_id = w.warehouse_id AND s.snapshot_date <= m.month_end
        ORDER BY s.snapshot_date DESC
        LIMIT 1) AS latest_qty
FROM supply_chain.warehouses w
CROSS JOIN (
  SELECT (date_trunc('month', d)::date + interval '1 month - 1 day')::date AS month_end
  FROM generate_series('2025-01-01'::date, '2025-12-01'::date, interval '1 month') AS d
) m
ORDER BY w.warehouse_id, m.month_end;

/* Q46. */
SELECT ist_hour, hour_revenue,
       round(100.0 * hour_revenue / sum(hour_revenue) OVER (), 2) AS pct_of_total
FROM (
  SELECT extract(hour FROM pv.view_timestamp AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Kolkata')::int AS ist_hour,
         count(*) AS hour_revenue
  FROM web_events.page_views pv
  GROUP BY 1
) h
ORDER BY ist_hour;

/* Q47. */
SELECT region_name, iso_week, revenue_this_year, revenue_last_year,
       round(100.0 * (revenue_this_year - revenue_last_year) / NULLIF(revenue_last_year, 0), 2) AS yoy_pct
FROM (
  SELECT r.region_name, to_char(o.order_date, 'IW') AS iso_week,
         sum(o.net_total) FILTER (WHERE extract(year FROM o.order_date) = 2025) AS revenue_this_year,
         sum(o.net_total) FILTER (WHERE extract(year FROM o.order_date) = 2024) AS revenue_last_year
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  JOIN core.dim_region r ON r.region_id = s.region_id
  WHERE extract(year FROM o.order_date) IN (2024, 2025)
  GROUP BY 1, 2
) x
ORDER BY region_name, iso_week;

/* Q48. */
SELECT cust_id, month, active_days,
       avg(active_days) OVER (PARTITION BY cust_id ORDER BY month) AS trend_avg
FROM (
  SELECT cust_id, date_trunc('month', order_date)::date AS month, count(DISTINCT order_date) AS active_days
  FROM sales.orders
  GROUP BY 1, 2
) x
ORDER BY cust_id, month
LIMIT 200;

/* Q49. */
SELECT s.store_id, m.month::date, coalesce(sum(o.net_total), 0) AS revenue,
       sum(coalesce(sum(o.net_total), 0)) OVER (PARTITION BY s.store_id) AS row_total,
       sum(coalesce(sum(o.net_total), 0)) OVER (PARTITION BY m.month) AS col_total
FROM stores.stores s
CROSS JOIN generate_series('2025-01-01'::date, '2025-12-01'::date, interval '1 month') AS m(month)
LEFT JOIN sales.orders o ON o.store_id = s.store_id AND date_trunc('month', o.order_date) = m.month
GROUP BY s.store_id, m.month
ORDER BY s.store_id, m.month
LIMIT 200;

/* Q50. */
WITH order_dates AS (
  SELECT cust_id, order_date, lag(order_date) OVER (PARTITION BY cust_id ORDER BY order_date) AS prev_date
  FROM sales.orders
)
SELECT cust_id, order_date AS reactivated_on, order_date - prev_date AS dormant_days
FROM order_dates
WHERE order_date - prev_date > 90
ORDER BY dormant_days DESC
LIMIT 50;

/* ============================================================
   SECTION C: CALENDAR DIMENSIONS & GAP-FILL ENGINES (25)
   ------------------------------------------------------------ */
/* Q51. */
SELECT d::date AS date,
       extract(dow FROM d)::int AS dow,
       extract(isodow FROM d)::int AS iso_dow,
       extract(week FROM d)::int AS week,
       to_char(d, 'IYYY-IW') AS iso_week,
       extract(month FROM d)::int AS month,
       to_char(d, 'Month') AS month_name,
       extract(quarter FROM d)::int AS quarter,
       CASE WHEN extract(month FROM d) >= 4 THEN extract(year FROM d)::int ELSE extract(year FROM d)::int - 1 END AS fiscal_year,
       CASE WHEN extract(month FROM d) IN (4,5,6) THEN 1 WHEN extract(month FROM d) IN (7,8,9) THEN 2
            WHEN extract(month FROM d) IN (10,11,12) THEN 3 ELSE 4 END AS fiscal_quarter,
       (extract(dow FROM d) IN (0,6)) AS is_weekend,
       (d = (date_trunc('month', d) + interval '1 month - 1 day')::date) AS is_month_end
FROM generate_series('2020-01-01'::date, '2030-12-31'::date, interval '1 day') AS d
LIMIT 1000;

/* Q52. */
SELECT s.store_id, d.day::date, coalesce(sum(o.net_total), 0) AS revenue
FROM stores.stores s
CROSS JOIN generate_series('2025-06-01'::date, '2025-06-30'::date, interval '1 day') AS d(day)
LEFT JOIN sales.orders o ON o.store_id = s.store_id AND o.order_date = d.day
GROUP BY s.store_id, d.day
ORDER BY s.store_id, d.day
LIMIT 200;

/* Q53. */
SELECT r.region_name, m.month::date, coalesce(sum(o.net_total), 0) AS revenue
FROM core.dim_region r
CROSS JOIN generate_series('2025-01-01'::date, '2025-12-01'::date, interval '1 month') AS m(month)
LEFT JOIN stores.stores s ON s.region_id = r.region_id
LEFT JOIN sales.orders o ON o.store_id = s.store_id AND date_trunc('month', o.order_date) = m.month
GROUP BY r.region_name, m.month
ORDER BY r.region_name, m.month
LIMIT 200;

/* Q54. */
SELECT c.customer_id, p AS period_index,
       count(o.order_id) AS orders_in_period
FROM customers.customers c
CROSS JOIN generate_series(0, 11) AS p
LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
  AND (extract(year FROM o.order_date) - extract(year FROM c.registration_date)) * 12
    + (extract(month FROM o.order_date) - extract(month FROM c.registration_date)) = p
WHERE c.customer_id IN (SELECT customer_id FROM customers.customers ORDER BY customer_id LIMIT 5)
GROUP BY c.customer_id, p
ORDER BY c.customer_id, p;

/* Q55. */
SELECT fiscal_year, fiscal_quarter, revenue,
       round(100.0 * (revenue - lag(revenue) OVER (ORDER BY fiscal_year, fiscal_quarter)) / NULLIF(lag(revenue) OVER (ORDER BY fiscal_year, fiscal_quarter), 0), 2) AS qoq_pct
FROM (
  SELECT CASE WHEN extract(month FROM order_date) >= 4 THEN extract(year FROM order_date)::int ELSE extract(year FROM order_date)::int - 1 END AS fiscal_year,
         CASE WHEN extract(month FROM order_date) IN (4,5,6) THEN 1 WHEN extract(month FROM order_date) IN (7,8,9) THEN 2
              WHEN extract(month FROM order_date) IN (10,11,12) THEN 3 ELSE 4 END AS fiscal_quarter,
         sum(net_total) AS revenue
  FROM sales.orders
  GROUP BY 1, 2
) x
ORDER BY fiscal_year, fiscal_quarter;

/* Q56. */
WITH view_durations AS (
  SELECT device_type, view_timestamp,
         extract(hour FROM view_timestamp)::int AS hour_of_day,
         extract(epoch FROM (lead(view_timestamp) OVER (PARTITION BY session_id ORDER BY view_timestamp) - view_timestamp)) AS duration
  FROM web_events.page_views
)
SELECT h.hour, c.device_type,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY vd.duration) AS median_duration_sec
FROM generate_series(0, 23) AS h(hour)
CROSS JOIN (SELECT DISTINCT device_type FROM web_events.page_views) c
LEFT JOIN view_durations vd ON vd.device_type = c.device_type AND vd.hour_of_day = h.hour
GROUP BY h.hour, c.device_type
ORDER BY h.hour, c.device_type;

/* Q57. */
SELECT slot.slot_start, count(pv.view_id) AS page_views,
       rank() OVER (ORDER BY count(pv.view_id) DESC) AS slot_rank
FROM generate_series('2025-06-02 00:00:00'::timestamp, '2025-06-08 23:45:00'::timestamp, interval '15 min') AS slot(slot_start)
LEFT JOIN web_events.page_views pv ON pv.view_timestamp >= slot.slot_start AND pv.view_timestamp < slot.slot_start + interval '15 min'
GROUP BY slot.slot_start
ORDER BY slot_rank
LIMIT 20;

/* Q58. */
SELECT m.month_end, sn.product_id, sn.quantity_on_hand
FROM (
  SELECT (date_trunc('month', d)::date + interval '1 month - 1 day')::date AS month_end
  FROM generate_series('2025-01-01'::date, '2025-12-01'::date, interval '1 month') AS d
) m
CROSS JOIN LATERAL (
  SELECT DISTINCT ON (product_id) product_id, quantity_on_hand
  FROM supply_chain.inventory_snapshots s
  WHERE s.snapshot_date <= m.month_end
  ORDER BY product_id, snapshot_date DESC
) sn
ORDER BY m.month_end, sn.product_id
LIMIT 200;

/* Q59. */
SELECT d.day::date,
       coalesce(o.orders, 0) AS orders,
       coalesce(r.returns, 0) AS returns,
       coalesce(p.payments, 0) AS payments
FROM generate_series('2025-06-01'::date, '2025-06-30'::date, interval '1 day') AS d(day)
LEFT JOIN (SELECT order_date, count(*) AS orders FROM sales.orders GROUP BY order_date) o ON o.order_date = d.day
LEFT JOIN (SELECT return_date, count(*) AS returns FROM sales.returns GROUP BY return_date) r ON r.return_date = d.day
LEFT JOIN (SELECT payment_date, count(*) AS payments FROM sales.payments GROUP BY payment_date) p ON p.payment_date = d.day
ORDER BY d.day;

/* Q60. */
SELECT week_start, revenue,
       revenue - lag(revenue) OVER (ORDER BY week_start) AS wow_change,
       avg(revenue) OVER (ORDER BY week_start ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS ma_4week
FROM (
  SELECT w::date AS week_start, coalesce(sum(o.net_total), 0) AS revenue
  FROM generate_series('2024-01-01'::date, '2026-12-31'::date, interval '7 days') AS w
  LEFT JOIN sales.orders o ON date_trunc('week', o.order_date) = w
  GROUP BY w
) weekly
ORDER BY week_start;

/* Q61. */
SELECT d.day::date, metric_value,
       coalesce(metric_value, lag(metric_value) OVER (ORDER BY d.day)) AS locf_value
FROM generate_series('2025-06-01'::date, '2025-06-30'::date, interval '1 day') AS d(day)
LEFT JOIN (SELECT DISTINCT ON (spend_date) spend_date, amount AS metric_value FROM marketing.ads_spend ORDER BY spend_date, spend_id) a
  ON a.spend_date = d.day
ORDER BY d.day;

/* Q62. */
SELECT o.order_id,
       (SELECT count(*) FROM generate_series(o.order_date, sh.delivered_date, interval '1 day') g(d)
        WHERE extract(isodow FROM g.d) < 6) AS business_days_to_deliver
FROM sales.orders o
JOIN sales.shipments sh ON sh.order_id = o.order_id
WHERE sh.delivered_date IS NOT NULL
ORDER BY o.order_id
LIMIT 100;

/* Q63. */
SELECT month_num, revenue, annual_mean, round(revenue / NULLIF(annual_mean, 0), 3) AS seasonal_index
FROM (
  SELECT extract(month FROM order_date)::int AS month_num,
         sum(net_total) AS revenue,
         avg(sum(net_total)) OVER () AS annual_mean
  FROM sales.orders
  WHERE extract(year FROM order_date) = 2025
  GROUP BY 1
) x
ORDER BY month_num;

/* Q64. */
WITH order_days AS (
  SELECT DISTINCT cust_id, order_date FROM sales.orders
),
grp AS (
  SELECT cust_id, order_date,
         order_date - (row_number() OVER (PARTITION BY cust_id ORDER BY order_date))::int AS grp_key
  FROM order_days
)
SELECT cust_id, max(streak_len) AS longest_active_streak
FROM (
  SELECT cust_id, grp_key, count(*) AS streak_len
  FROM grp
  GROUP BY cust_id, grp_key
) s
GROUP BY cust_id
ORDER BY longest_active_streak DESC
LIMIT 20;

/* Q65. */
SELECT c.customer_id, m.month::date,
       m.month::date - (SELECT max(o2.order_date) FROM sales.orders o2 WHERE o2.cust_id = c.customer_id AND o2.order_date <= m.month) AS months_since_last_order_days
FROM customers.customers c
CROSS JOIN generate_series('2025-06-01'::date, '2025-12-01'::date, interval '1 month') AS m(month)
WHERE c.customer_id IN (SELECT customer_id FROM customers.customers ORDER BY customer_id LIMIT 5)
ORDER BY c.customer_id, m.month;

/* Q66. */
SELECT extract(dow FROM view_timestamp)::int AS weekday, extract(hour FROM view_timestamp)::int AS hour, count(*) AS page_views
FROM web_events.page_views
GROUP BY 1, 2
ORDER BY 1, 2;

/* Q67. */
SELECT s.store_id, d.day::date, coalesce(sum(o.net_total), 0) AS revenue,
       (coalesce(sum(o.net_total), 0) = 0) AS is_zero_day,
       (coalesce(sum(o.net_total), 0) = max(coalesce(sum(o.net_total), 0)) OVER (PARTITION BY s.store_id)) AS is_record_high
FROM stores.stores s
CROSS JOIN generate_series('2025-06-01'::date, '2025-06-30'::date, interval '1 day') AS d(day)
LEFT JOIN sales.orders o ON o.store_id = s.store_id AND o.order_date = d.day
GROUP BY s.store_id, d.day
ORDER BY s.store_id, d.day
LIMIT 200;

/* Q68. */
SELECT r.region_name, o.order_date,
       sum(o.net_total) OVER (PARTITION BY r.region_name,
           CASE WHEN extract(month FROM o.order_date) >= 4 THEN extract(year FROM o.order_date)::int ELSE extract(year FROM o.order_date)::int - 1 END
           ORDER BY o.order_date) AS fytd_revenue
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
ORDER BY r.region_name, o.order_date
LIMIT 200;

/* Q69. */
SELECT r.region_name, m.month::date,
       sum(coalesce(sub.revenue,0)) OVER (PARTITION BY r.region_name ORDER BY m.month ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS rolling_12mo_revenue
FROM core.dim_region r
CROSS JOIN generate_series('2025-01-01'::date, '2026-01-01'::date, interval '1 month') AS m(month)
LEFT JOIN (
  SELECT s.region_id, date_trunc('month', o.order_date)::date AS month, sum(o.net_total) AS revenue
  FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id
  GROUP BY 1, 2
) sub ON sub.region_id = r.region_id AND sub.month = m.month
ORDER BY r.region_name, m.month
LIMIT 200;

/* Q70. */
SELECT o.order_id, o.cust_id, c.registration_date, o.order_date,
       extract(year FROM age(o.order_date, c.registration_date))::int AS customer_age_years_at_order
FROM sales.orders o
JOIN customers.customers c ON c.customer_id = o.cust_id
ORDER BY o.order_id
LIMIT 100;

/* Q71. */
SELECT p.product_id, m.month_end, oi.unit_price AS as_of_price
FROM products.products p
CROSS JOIN (
  SELECT (date_trunc('month', d)::date + interval '1 month - 1 day')::date AS month_end
  FROM generate_series('2025-01-01'::date, '2025-12-01'::date, interval '1 month') AS d
) m
CROSS JOIN LATERAL (
  SELECT oi.unit_price
  FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  WHERE oi.prod_id = p.product_id AND o.order_date <= m.month_end
  ORDER BY o.order_date DESC
  LIMIT 1
) oi
LIMIT 200;

/* Q72. */
SELECT day, pct_within_sla,
       avg(pct_within_sla) OVER (ORDER BY day ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS ma_30day
FROM (
  SELECT o.order_date AS day,
         round(100.0 * count(*) FILTER (WHERE sh.delivered_date - o.order_date <= 3) / NULLIF(count(*), 0), 2) AS pct_within_sla
  FROM sales.orders o
  JOIN sales.shipments sh ON sh.order_id = o.order_id
  WHERE sh.delivered_date IS NOT NULL
  GROUP BY o.order_date
) x
ORDER BY day;

/* Q73. */
SELECT w.warehouse_id, d.day::date
FROM supply_chain.warehouses w
CROSS JOIN generate_series('2025-06-01'::date, '2025-06-30'::date, interval '1 day') AS d(day)
LEFT JOIN supply_chain.inventory_snapshots s ON s.warehouse_id = w.warehouse_id AND s.snapshot_date = d.day
WHERE s.warehouse_id IS NULL
ORDER BY w.warehouse_id, d.day
LIMIT 200;

/* Q74. */
SELECT c.customer_id,
       least(coalesce(min(o.order_date)::timestamp, 'infinity'), coalesce(min(pv.view_timestamp), 'infinity')) AS first_activity,
       greatest(coalesce(max(o.order_date)::timestamp, '-infinity'), coalesce(max(pv.view_timestamp), '-infinity')) AS last_activity
FROM customers.customers c
LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
LEFT JOIN web_events.page_views pv ON pv.customer_id = c.customer_id
GROUP BY c.customer_id
HAVING max(o.order_date) IS NOT NULL OR max(pv.view_timestamp) IS NOT NULL
ORDER BY c.customer_id
LIMIT 100;

/* Q75. */
SELECT d.day::date,
       coalesce(o.orders, 0) AS orders,
       coalesce(sum(o2.net_total), 0) AS revenue,
       coalesce(count(DISTINCT o2.cust_id), 0) AS active_customers
FROM generate_series((SELECT max(order_date) FROM sales.orders) - interval '89 days',
                      (SELECT max(order_date) FROM sales.orders), interval '1 day') AS d(day)
LEFT JOIN (SELECT order_date, count(*) AS orders FROM sales.orders GROUP BY order_date) o ON o.order_date = d.day
LEFT JOIN sales.orders o2 ON o2.order_date = d.day
GROUP BY d.day, o.orders
ORDER BY d.day;

/* ============================================================
   SECTION D: PRODUCTION TIME-SERIES SYSTEMS (25)
   ------------------------------------------------------------ */
/* Q76. */
SELECT day, revenue,
       avg(revenue) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS ma_7day,
       avg(revenue) OVER (ORDER BY day ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) AS ma_28day,
       round(100.0 * (revenue - lag(revenue) OVER (ORDER BY day)) / NULLIF(lag(revenue) OVER (ORDER BY day), 0), 2) AS mom_daily_pct,
       revenue > p95.p95_revenue AS is_anomaly
FROM (
  SELECT d.day::date, coalesce(sum(o.net_total), 0) AS revenue
  FROM generate_series((SELECT max(order_date) FROM sales.orders) - interval '89 days',
                        (SELECT max(order_date) FROM sales.orders), interval '1 day') AS d(day)
  LEFT JOIN sales.orders o ON o.order_date = d.day::date
  GROUP BY d.day
) daily
CROSS JOIN (
  SELECT percentile_cont(0.95) WITHIN GROUP (ORDER BY revenue) AS p95_revenue
  FROM (
    SELECT d.day::date, coalesce(sum(o.net_total), 0) AS revenue
    FROM generate_series((SELECT max(order_date) FROM sales.orders) - interval '89 days',
                          (SELECT max(order_date) FROM sales.orders), interval '1 day') AS d(day)
    LEFT JOIN sales.orders o ON o.order_date = d.day::date
    GROUP BY d.day
  ) daily2
) p95
ORDER BY day;

/* Q77. */
SELECT cohort_month, months_since, cohort_size, retained, round(100.0 * retained / NULLIF(cohort_size, 0), 2) AS retention_pct
FROM (
  SELECT cohort_month, months_since, count(DISTINCT customer_id) AS retained,
         max(count(DISTINCT customer_id)) OVER (PARTITION BY cohort_month) AS cohort_size
  FROM (
    SELECT c.customer_id,
           date_trunc('month', c.registration_date)::date AS cohort_month,
           (extract(year FROM o.order_date) - extract(year FROM c.registration_date)) * 12
           + (extract(month FROM o.order_date) - extract(month FROM c.registration_date)) AS months_since
    FROM customers.customers c
    JOIN sales.orders o ON o.cust_id = c.customer_id
  ) t
  WHERE months_since BETWEEN 0 AND 11
  GROUP BY cohort_month, months_since
) x
ORDER BY cohort_month, months_since;

/* Q78. */
SELECT region_name, month, revenue,
       round(100.0 * (revenue - lag(revenue) OVER w) / NULLIF(lag(revenue) OVER w, 0), 2) AS mom_pct,
       round(100.0 * (revenue - lag(revenue, 12) OVER w) / NULLIF(lag(revenue, 12) OVER w, 0), 2) AS yoy_pct,
       avg(revenue) OVER (PARTITION BY region_name ORDER BY month ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS rolling_12m,
       rank() OVER (PARTITION BY month ORDER BY revenue DESC) AS region_rank
FROM (
  SELECT r.region_name, m.month::date, coalesce(sum(o.net_total), 0) AS revenue
  FROM core.dim_region r
  CROSS JOIN generate_series('2024-01-01'::date, '2026-01-01'::date, interval '1 month') AS m(month)
  LEFT JOIN stores.stores s ON s.region_id = r.region_id
  LEFT JOIN sales.orders o ON o.store_id = s.store_id AND date_trunc('month', o.order_date) = m.month
  GROUP BY r.region_name, m.month
) x
WINDOW w AS (PARTITION BY region_name ORDER BY month)
ORDER BY region_name, month;

/* Q79. */
SELECT month,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY delivery_days) AS median_days,
       percentile_cont(0.95) WITHIN GROUP (ORDER BY delivery_days) AS p95_days,
       round(100.0 * count(*) FILTER (WHERE delivery_days > 3) / NULLIF(count(*), 0), 2) AS breach_pct
FROM (
  SELECT date_trunc('month', o.order_date)::date AS month, sh.delivered_date - o.order_date AS delivery_days
  FROM sales.orders o
  JOIN sales.shipments sh ON sh.order_id = o.order_id
  WHERE sh.delivered_date IS NOT NULL
) x
GROUP BY month
ORDER BY month;

/* Q80. */
WITH ordered AS (
  SELECT customer_id, view_timestamp,
         lag(view_timestamp) OVER (PARTITION BY customer_id ORDER BY view_timestamp) AS prev_ts
  FROM web_events.page_views
  WHERE customer_id IS NOT NULL
),
flagged AS (
  SELECT customer_id, view_timestamp,
         CASE WHEN prev_ts IS NULL OR view_timestamp - prev_ts > interval '30 min' THEN 1 ELSE 0 END AS new_session
  FROM ordered
),
sessioned AS (
  SELECT customer_id, view_timestamp,
         sum(new_session) OVER (PARTITION BY customer_id ORDER BY view_timestamp) AS session_num
  FROM flagged
),
session_lengths AS (
  SELECT customer_id, session_num, max(view_timestamp) - min(view_timestamp) AS session_length, count(*) AS pages_viewed
  FROM sessioned
  GROUP BY customer_id, session_num
)
SELECT count(DISTINCT customer_id || '-' || session_num) AS sessions_per_customer_denom,
       count(*) AS total_sessions,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY extract(epoch FROM session_length)) AS median_session_sec,
       round(100.0 * count(*) FILTER (WHERE pages_viewed = 1) / count(*), 2) AS bounce_pct
FROM session_lengths;

/* Q81. */
SELECT dow, slot_start, page_views,
       CASE WHEN page_views > 100 THEN 'Add staff' WHEN page_views > 30 THEN 'Normal staffing' ELSE 'Light staffing' END AS staffing_hint
FROM (
  SELECT extract(dow FROM view_timestamp)::int AS dow,
         date_trunc('hour', view_timestamp) + floor(extract(minute FROM view_timestamp) / 15) * interval '15 min' AS slot_start,
         count(*) AS page_views
  FROM web_events.page_views
  GROUP BY 1, 2
) x
ORDER BY page_views DESC
LIMIT 20;

/* Q82. */
SELECT priority, month,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY resolution_hours) AS median_hours,
       percentile_cont(0.95) WITHIN GROUP (ORDER BY resolution_hours) AS p95_hours,
       round(100.0 * count(*) FILTER (WHERE resolution_hours <= 24) / NULLIF(count(*), 0), 2) AS attainment_pct
FROM (
  SELECT priority, date_trunc('month', created_date)::date AS month,
         extract(epoch FROM (resolved_date - created_date)) / 3600.0 AS resolution_hours
  FROM support.tickets
  WHERE resolved_date IS NOT NULL
) x
GROUP BY priority, month
ORDER BY priority, month;

/* Q83. */
WITH order_dates AS (
  SELECT cust_id, order_date, lag(order_date) OVER (PARTITION BY cust_id ORDER BY order_date) AS prev_date
  FROM sales.orders
),
reactivations AS (
  SELECT date_trunc('month', order_date)::date AS month, cust_id
  FROM order_dates
  WHERE order_date - prev_date > 90
)
SELECT month, count(*) AS reactivated_customers
FROM reactivations
GROUP BY month
ORDER BY month;

/* Q84. */
SELECT cat.category_name, extract(month FROM o.order_date)::int AS month_num,
       sum(oi.quantity) AS units,
       round(sum(oi.quantity) / NULLIF(avg(sum(oi.quantity)) OVER (PARTITION BY cat.category_name), 0), 3) AS seasonal_index
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
WHERE extract(year FROM o.order_date) = 2025
GROUP BY cat.category_name, month_num
ORDER BY cat.category_name, month_num;

/* Q85. */
SELECT r.region_name, o.order_date,
       sum(o.net_total) OVER (PARTITION BY r.region_name,
           CASE WHEN extract(month FROM o.order_date) >= 4 THEN extract(year FROM o.order_date)::int ELSE extract(year FROM o.order_date)::int - 1 END
           ORDER BY o.order_date) AS fytd_revenue
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
ORDER BY r.region_name, o.order_date
LIMIT 200;

/* Q86. */
SELECT w.warehouse_id, m.month_end,
       sn.quantity_on_hand AS month_end_value,
       sn.quantity_on_hand / NULLIF((SELECT avg(quantity_on_hand) FROM supply_chain.inventory_snapshots s2 WHERE s2.warehouse_id = w.warehouse_id AND date_trunc('month', s2.snapshot_date) = date_trunc('month', m.month_end)), 0) AS days_of_cover_proxy
FROM supply_chain.warehouses w
CROSS JOIN (
  SELECT (date_trunc('month', d)::date + interval '1 month - 1 day')::date AS month_end
  FROM generate_series('2025-01-01'::date, '2025-12-01'::date, interval '1 month') AS d
) m
CROSS JOIN LATERAL (
  SELECT sum(quantity_on_hand) AS quantity_on_hand
  FROM supply_chain.inventory_snapshots s
  WHERE s.warehouse_id = w.warehouse_id AND s.snapshot_date <= m.month_end
    AND s.snapshot_date = (SELECT max(snapshot_date) FROM supply_chain.inventory_snapshots s3 WHERE s3.warehouse_id = w.warehouse_id AND s3.snapshot_date <= m.month_end)
) sn
ORDER BY w.warehouse_id, m.month_end;

/* Q87. */
SELECT month,
       sum(net_total) FILTER (WHERE is_first_order) AS new_revenue,
       sum(net_total) FILTER (WHERE NOT is_first_order) AS returning_revenue,
       round(100.0 * sum(net_total) FILTER (WHERE is_first_order) / NULLIF(sum(net_total), 0), 2) AS new_pct
FROM (
  SELECT o.order_id, o.net_total, date_trunc('month', o.order_date)::date AS month,
         o.order_date = f.first_order_date AS is_first_order
  FROM sales.orders o
  JOIN (SELECT cust_id, min(order_date) AS first_order_date FROM sales.orders GROUP BY cust_id) f
    ON f.cust_id = o.cust_id
) x
GROUP BY month
ORDER BY month;

/* Q88. */
SELECT region_id, day, revenue, p95.p95_revenue, p99.p99_revenue,
       revenue > p95.p95_revenue AS beyond_p95,
       revenue > p99.p99_revenue AS beyond_p99
FROM (
  SELECT r.region_id, d.day::date, coalesce(sum(o.net_total), 0) AS revenue
  FROM core.dim_region r
  CROSS JOIN generate_series('2025-06-01'::date, '2025-08-31'::date, interval '1 day') AS d(day)
  LEFT JOIN stores.stores s ON s.region_id = r.region_id
  LEFT JOIN sales.orders o ON o.store_id = s.store_id AND o.order_date = d.day
  GROUP BY r.region_id, d.day
) daily
JOIN LATERAL (
  SELECT percentile_cont(0.95) WITHIN GROUP (ORDER BY revenue) AS p95_revenue
  FROM (
    SELECT coalesce(sum(o2.net_total), 0) AS revenue
    FROM stores.stores s2 LEFT JOIN sales.orders o2 ON o2.store_id = s2.store_id
    WHERE s2.region_id = daily.region_id
    GROUP BY o2.order_date
  ) t
) p95 ON true
JOIN LATERAL (
  SELECT percentile_cont(0.99) WITHIN GROUP (ORDER BY revenue) AS p99_revenue
  FROM (
    SELECT coalesce(sum(o2.net_total), 0) AS revenue
    FROM stores.stores s2 LEFT JOIN sales.orders o2 ON o2.store_id = s2.store_id
    WHERE s2.region_id = daily.region_id
    GROUP BY o2.order_date
  ) t
) p99 ON true
ORDER BY region_id, day
LIMIT 200;

/* Q89. */
SELECT weekday, hour, page_views,
       round(100.0 * page_views / sum(page_views) OVER (PARTITION BY weekday), 2) AS pct_of_weekday
FROM (
  SELECT extract(dow FROM view_timestamp)::int AS weekday, extract(hour FROM view_timestamp)::int AS hour, count(*) AS page_views
  FROM web_events.page_views
  GROUP BY 1, 2
) x
ORDER BY weekday, hour;

/* Q90. */
SELECT p.product_id, m.month_end, oi.unit_price AS as_of_price,
       oi.unit_price - lag(oi.unit_price) OVER (PARTITION BY p.product_id ORDER BY m.month_end) AS price_drift
FROM products.products p
CROSS JOIN (
  SELECT (date_trunc('month', d)::date + interval '1 month - 1 day')::date AS month_end
  FROM generate_series('2025-01-01'::date, '2025-12-01'::date, interval '1 month') AS d
) m
CROSS JOIN LATERAL (
  SELECT oi.unit_price
  FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  WHERE oi.prod_id = p.product_id AND o.order_date <= m.month_end
  ORDER BY o.order_date DESC
  LIMIT 1
) oi
WHERE p.product_id IN (SELECT product_id FROM products.products ORDER BY product_id LIMIT 5)
ORDER BY p.product_id, m.month_end;

/* Q91. */
SELECT c.customer_id, c.registration_date AS registered,
       min(o.order_date) AS first_order,
       max(o.order_date) AS latest_order,
       min(o.order_date) - c.registration_date AS days_to_first,
       max(o.order_date) - min(o.order_date) AS active_span_days
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY c.customer_id, c.registration_date
ORDER BY c.customer_id
LIMIT 100;

/* Q92. */
SELECT r.region_name, d.day::date,
       (SELECT count(DISTINCT o.cust_id) FROM sales.orders o JOIN stores.stores s2 ON s2.store_id = o.store_id
        WHERE s2.region_id = r.region_id AND o.order_date > d.day::date - 28 AND o.order_date <= d.day::date) AS active_28day,
       (SELECT count(DISTINCT o.cust_id) FROM sales.orders o JOIN stores.stores s2 ON s2.store_id = o.store_id
        WHERE s2.region_id = r.region_id AND o.order_date > d.day::date - 56 AND o.order_date <= d.day::date - 28) AS base_prior_28day
FROM core.dim_region r
CROSS JOIN generate_series((SELECT max(order_date) FROM sales.orders) - interval '29 days',
                            (SELECT max(order_date) FROM sales.orders), interval '1 day') AS d(day)
ORDER BY r.region_name, d.day
LIMIT 200;

/* Q93. */
SELECT date_trunc('month', o.order_date)::date AS month,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY sh.shipped_date - o.order_date) AS median_to_ship,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY sh.delivered_date - sh.shipped_date) AS median_ship_to_deliver
FROM sales.orders o
JOIN sales.shipments sh ON sh.order_id = o.order_id
WHERE sh.shipped_date IS NOT NULL AND sh.delivered_date IS NOT NULL
GROUP BY 1
ORDER BY 1;

/* Q94. */
SELECT r.region_name, iso_year_week, revenue_this_year, revenue_last_year,
       round(100.0 * (revenue_this_year - revenue_last_year) / NULLIF(revenue_last_year, 0), 2) AS yoy_pct
FROM (
  SELECT s.region_id, to_char(o.order_date, 'IW') AS iso_year_week,
         sum(o.net_total) FILTER (WHERE extract(year FROM o.order_date) = 2025) AS revenue_this_year,
         sum(o.net_total) FILTER (WHERE extract(year FROM o.order_date) = 2024) AS revenue_last_year
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  WHERE extract(year FROM o.order_date) IN (2024, 2025)
  GROUP BY 1, 2
) x
JOIN core.dim_region r ON r.region_id = x.region_id
ORDER BY r.region_name, iso_year_week;

/* Q95. */
SELECT s.store_id, m.month::date, coalesce(sum(o.net_total), 0) AS revenue,
       (coalesce(sum(o.net_total), 0) = 0) AS zero_month
FROM stores.stores s
CROSS JOIN generate_series('2025-01-01'::date, '2025-12-01'::date, interval '1 month') AS m(month)
LEFT JOIN sales.orders o ON o.store_id = s.store_id AND date_trunc('month', o.order_date) = m.month
GROUP BY s.store_id, m.month
ORDER BY s.store_id, m.month
LIMIT 200;

/* Q96. */
SELECT r.region_name,
       (SELECT coalesce(sum(o.net_total), 0) FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id
        WHERE s.region_id = r.region_id AND o.order_date = (SELECT max(order_date) FROM sales.orders)) AS yesterday_revenue,
       (SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY daily_rev) FROM (
           SELECT coalesce(sum(o.net_total), 0) AS daily_rev
           FROM generate_series((SELECT max(order_date) FROM sales.orders) - interval '28 days',
                                 (SELECT max(order_date) FROM sales.orders) - interval '1 day', interval '1 day') AS d(day)
           LEFT JOIN sales.orders o ON o.order_date = d.day::date
             AND o.store_id IN (SELECT store_id FROM stores.stores WHERE region_id = r.region_id)
           GROUP BY d.day
       ) t) AS trailing_28day_median
FROM core.dim_region r
ORDER BY r.region_name;

/* Q97. */
SELECT cohort_month, months_since, sum(revenue) OVER (PARTITION BY cohort_month ORDER BY months_since) AS cumulative_ltv
FROM (
  SELECT date_trunc('month', c.registration_date)::date AS cohort_month,
         (extract(year FROM o.order_date) - extract(year FROM c.registration_date)) * 12
         + (extract(month FROM o.order_date) - extract(month FROM c.registration_date)) AS months_since,
         sum(o.net_total) AS revenue
  FROM customers.customers c
  JOIN sales.orders o ON o.cust_id = c.customer_id
  GROUP BY 1, 2
) x
WHERE months_since BETWEEN 0 AND 11
ORDER BY cohort_month, months_since;

/* Q98. */
SELECT d.day::date,
       coalesce(o.orders, 0) AS orders,
       coalesce(r.returns, 0) AS returns,
       coalesce(p.payments, 0) AS payments,
       coalesce(v.views, 0) AS page_views
FROM generate_series('2025-06-01'::date, '2025-06-30'::date, interval '1 day') AS d(day)
LEFT JOIN (SELECT order_date, count(*) AS orders FROM sales.orders GROUP BY order_date) o ON o.order_date = d.day
LEFT JOIN (SELECT return_date, count(*) AS returns FROM sales.returns GROUP BY return_date) r ON r.return_date = d.day
LEFT JOIN (SELECT payment_date, count(*) AS payments FROM sales.payments GROUP BY payment_date) p ON p.payment_date = d.day
LEFT JOIN (SELECT view_timestamp::date AS vd, count(*) AS views FROM web_events.page_views GROUP BY 1) v ON v.vd = d.day
ORDER BY d.day;

/* Q99. */
WITH order_dates AS (
  SELECT cust_id, order_date, lag(order_date) OVER (PARTITION BY cust_id ORDER BY order_date) AS prev_date
  FROM sales.orders
)
SELECT count(*) FILTER (WHERE order_date - prev_date > 90) AS reactivations,
       count(DISTINCT cust_id) FILTER (WHERE order_date - prev_date > 90) AS reactivated_customers
FROM order_dates;

/* Q100. Capstone: build one daily spine over the trailing 90 days, LEFT JOIN sales.orders for revenue/order counts, compute 7- and 28-day moving averages, MoM%% via LAG, and flag days beyond the P95 percentile (as in Q76/Q39) - a materialized view (Day 25) would precompute this exact spine+join+window pipeline so dashboards hit a plain SELECT instead of recomputing it live. */

/* ============================================================
   END OF ANSWER KEY - HARD LEVEL (100/100)
============================================================ */
