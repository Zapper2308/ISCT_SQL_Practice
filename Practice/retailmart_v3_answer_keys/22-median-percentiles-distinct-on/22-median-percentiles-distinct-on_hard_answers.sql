/* ============================================================
   ANSWER KEY - Median, Percentiles & DISTINCT ON (HARD LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1. (1) PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY x) - correct, interpolated, one line, but scans/sorts the whole group; (2) NTILE(2) then pick the boundary row - approximate, count-based, can misrepresent value gaps; (3) manual: sort, take AVG of the middle one or two ordered rows via a windowed row-offset - fully explicit and portable but verbose and easy to get off-by-one on even/odd counts. PERCENTILE_CONT is the simplest and most exact for interview/production use. */
/* Q2. PERCENTILE_CONT must see the ordered VALUES of the whole group to interpolate a rank-based cut point, not just find one row - a plain B-tree index can speed up the ORDER BY/sort feeding it, but Postgres still has to materialize and rank the whole group's data, so at scale it means a full sort per group rather than a cheap index lookup. */
/* Q3. Strategies: random/systematic SAMPLING (compute the exact percentile on a smaller sample instead of the whole table), or streaming sketches like t-digest/HyperLogLog-style approximate structures that summarize the distribution in bounded memory in one pass and estimate percentiles from the sketch - neither requires sorting the full dataset. */
/* Q4. As a grouped aggregate, PERCENTILE_CONT ... WITHIN GROUP collapses each group to a single summary row (one median per group). PostgreSQL's ordered-set aggregates cannot be used with OVER() as a true per-row window function, so "median as a window value repeated on every row" must instead be computed as an aggregate in a CTE and joined back to each row. */
/* Q5. DISTINCT ON: concise, PostgreSQL-only, one row per group, needs a leading ORDER BY. ROW_NUMBER(): standard SQL, needs a wrapping CTE + WHERE rn=1, easy to get multiple ranks besides #1. Correlated subquery: standard SQL, conceptually simple but typically re-evaluates per outer row - slow without a great index. LATERAL: standard-ish, lets you pull back several columns (or a small top-N) per outer row efficiently when paired with an index, more flexible than a scalar correlated subquery. */
/* Q6. Without a supporting index, DISTINCT ON over 150k orders would typically produce a Sort (on cust_id, order_date DESC) followed by a Unique/Group step. With a composite index on (cust_id, order_date DESC), the planner can instead do an Index Scan that walks the index in the needed order and skip directly to each next group ("loose index scan" style), avoiding the full sort. */
/* Q7. A composite index on (group_key, ts DESC) - it matches DISTINCT ON's required ORDER BY exactly (group key first, tiebreak second, already in the needed direction), letting Postgres walk the index in order instead of sorting the whole table. */
/* Q8. A covering index (one that also INCLUDEs the other selected columns) lets Postgres answer the query using only the index's own pages, with no need to visit the heap (table) for each matching row - that Index-Only Scan is what makes latest-per-group very cheap even over large tables. */
/* Q9. Pitfalls: mixing raw event counts with percentiles of duration (not the same thing), forgetting to exclude in-progress/incomplete events which skew the tail, using AVG duration as a stand-in for P95 latency, and not accounting for timezone/clock-skew when timestamps come from different sources. */
/* Q10. NULLs in the ordering column are excluded from the sorted set before PERCENTILE_CONT computes rank positions and interpolates - they do not count toward the group's size or influence the result, the same NULL-exclusion behavior as SUM/AVG/COUNT(col). */
/* Q11. SQL's ordered-set aggregates rank rows by count/position only, with no built-in notion of a per-row "weight" (e.g. treat this row as if it appeared N times) - to approximate a weighted median you must manually expand/duplicate rows by their weight (or compute a cumulative-weight running total and find where it crosses 50%) before applying PERCENTILE_CONT. */
/* Q12. The median-of-medians first collapses each subgroup down to one number and then takes the median of those numbers, which is influenced by group sizes and internal spread, not by the true rank of every individual row; the true global median directly ranks all underlying rows together - the two can diverge substantially when group sizes or distributions are uneven. */
/* Q13. For fraction p over n sorted values (0-indexed), PERCENTILE_CONT computes the fractional rank position rn = p * (n - 1); if rn falls between integer indices i (floor) and i+1, the result is value[i] + (rn - i) * (value[i+1] - value[i]) - a straight linear interpolation between the two bracketing sorted values. */
/* Q14. Compute P5 and P95 with PERCENTILE_CONT, then AVG(x) FILTER (WHERE x BETWEEN p5 AND p95) (typically via a CTE holding the two cut points) to average only the middle 90% of values, discarding the top and bottom 5% tails. */
/* Q15. IQR fences flag anything beyond P25 - 1.5*IQR / P75 + 1.5*IQR (robust, distribution-shape-agnostic); z-score flags anything more than N standard deviations from the MEAN (assumes roughly-normal data, sensitive to the same outliers it's trying to detect); percentile clipping simply flags/truncates anything below Pk or above P(100-k) directly, with no assumption about shape but requires choosing k by judgment. */
/* Q16. P50 (median) equals AVG only for a perfectly symmetric distribution; when AVG > median the data is right-skewed (a few very high values pull the mean up), and when AVG < median it's left-skewed - the size and direction of the gap directly measures that skew. */
/* Q17. If the tiebreaker column is not unique per group (e.g. two rows share the exact same timestamp), DISTINCT ON can non-deterministically return either tied row on different runs/plans, silently changing which row counts as "latest" - this is a correctness bug, not just a cosmetic one. */
/* Q18. Add a final unique tiebreaker to the ORDER BY after the timestamp, such as the row's own primary key (e.g. ORDER BY cust_id, order_date DESC, order_id DESC), so that even exact timestamp ties always resolve to the same row every time the query runs. */
/* Q19. Streaming/online percentile estimation processes each new data point once, updating a compact summary structure (e.g. a t-digest, a reservoir sample, or a histogram of buckets) in roughly constant memory, so an approximate percentile can be read at any time without storing or re-sorting the full history. */
/* Q20. Precompute into a summary table/materialized view when the same group percentiles are queried repeatedly (e.g. a daily dashboard) and recomputing them from raw rows every time is too slow or too costly - refresh it on a schedule (e.g. nightly) rather than computing PERCENTILE_CONT live on every page load. */
/* Q21. Postgres must fully sort each group's values before it can pick percentile cut points; with many groups this means either one big sort keyed by (group, value) or a hash-based grouping strategy, and if the sort/hash data doesn't fit in work_mem it spills to disk, which is far slower - raising work_mem (within reason) can keep more of this in memory. */
/* Q22. PostgreSQL's ordered-set aggregates (PERCENTILE_CONT/DISC) cannot be combined with a window frame (ROWS/RANGE BETWEEN ...) directly - there is no "moving median" window function - so a sliding-window median must be computed with a correlated subquery or LATERAL join that re-runs PERCENTILE_CONT over each window's row range separately. */
/* Q23. GROUPING SETS ask Postgres to compute multiple different grouping levels (e.g. by region, by region+quarter, and a grand total) in one pass; pairing that with PERCENTILE_CONT means every one of those grouping levels must independently sort/rank its own subset of rows, multiplying the sorting cost by the number of grouping-set combinations. */
/* Q24. When the metric must correspond to an actual thing that really happened - e.g. "the P95 response time" for an SLA credit should be a real observed response time, not a number PERCENTILE_CONT interpolated that no single request ever actually experienced. */
/* Q25. Compute a rolling P95 (or P99) of the key latency/duration metric over a fixed recent window (e.g. the last 5-15 minutes), refresh it on a short interval, and fire an alert when that rolling P95 crosses a fixed SLA threshold for more than one consecutive evaluation (to avoid flapping on a single noisy spike). */

/* ============================================================
   SECTION B: DISTRIBUTION & PERCENTILE REPORTS (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT r.region_name,
       MIN(o.net_total) AS min_val,
       PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY o.net_total) AS p25,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS p50,
       PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY o.net_total) AS p75,
       MAX(o.net_total) AS max_val
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q27. */
WITH region_iqr AS (
    SELECT r.region_id, r.region_name,
           PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY o.net_total) AS p25,
           PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY o.net_total) AS p75
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_id, r.region_name
)
SELECT ri.region_name, ri.p25, ri.p75, (ri.p75 - ri.p25) AS iqr,
       ri.p25 - 1.5 * (ri.p75 - ri.p25) AS lower_fence,
       ri.p75 + 1.5 * (ri.p75 - ri.p25) AS upper_fence,
       COUNT(*) FILTER (WHERE o.net_total < ri.p25 - 1.5 * (ri.p75 - ri.p25)
                            OR o.net_total > ri.p75 + 1.5 * (ri.p75 - ri.p25)) AS outlier_count
FROM region_iqr ri
JOIN stores.stores s ON s.region_id = ri.region_id
JOIN sales.orders o ON o.store_id = s.store_id
GROUP BY ri.region_name, ri.p25, ri.p75
ORDER BY ri.region_name;
/* Q28. */
WITH region_bounds AS (
    SELECT r.region_id, r.region_name,
           PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY o.net_total) AS p5,
           PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_id, r.region_name
)
SELECT rb.region_name,
       ROUND(AVG(o.net_total) FILTER (WHERE o.net_total BETWEEN rb.p5 AND rb.p95), 2) AS trimmed_mean_net_total
FROM region_bounds rb
JOIN stores.stores s ON s.region_id = rb.region_id
JOIN sales.orders o ON o.store_id = s.store_id
GROUP BY rb.region_name
ORDER BY rb.region_name;
/* Q29. */
WITH region_pct AS (
    SELECT r.region_name,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS p50,
           PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY o.net_total) AS p90,
           PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95,
           PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY o.net_total) AS p99
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_name
)
SELECT region_name, p50, p90, p95, p99
FROM region_pct
ORDER BY p95 DESC;
/* Q30. */
SELECT w.warehouse_id, w.name AS warehouse_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sh.delivered_date - o.order_date) AS median_delivery_days,
       PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY sh.delivered_date - o.order_date) AS p90_delivery_days,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY sh.delivered_date - o.order_date) AS p95_delivery_days,
       MAX(sh.delivered_date - o.order_date) AS max_delivery_days
FROM sales.orders o
JOIN sales.shipments sh ON sh.order_id = o.order_id
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
JOIN supply_chain.warehouses w ON w.region = r.region_name
WHERE o.order_status = 'Delivered' AND sh.delivered_date IS NOT NULL
GROUP BY w.warehouse_id, w.name
ORDER BY w.warehouse_id;
/* Q31. */
SELECT priority,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600.0) AS median_resolution_hours,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600.0) AS p95_resolution_hours,
       COUNT(*) FILTER (WHERE EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600.0 > 48) AS sla_breaches_over_48h
FROM support.tickets
WHERE resolved_date IS NOT NULL
GROUP BY priority
ORDER BY priority;
/* Q32. */
WITH agent_pct AS (
    SELECT agent_id,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY call_duration_seconds) AS median_duration,
           PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY call_duration_seconds) AS p95_duration
    FROM call_center.calls
    GROUP BY agent_id
)
SELECT agent_id, median_duration, p95_duration,
       RANK() OVER (ORDER BY p95_duration DESC) AS worst_p95_rank
FROM agent_pct
ORDER BY worst_p95_rank;
/* Q33. */
SELECT d.dept_name,
       PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY ps.net_salary) AS p25_net_salary,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ps.net_salary) AS p50_net_salary,
       PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY ps.net_salary) AS p75_net_salary
FROM payroll.pay_slips ps
JOIN stores.employees e ON e.employee_id = ps.employee_id
JOIN core.dim_department d ON d.dept_id = e.dept_id
GROUP BY d.dept_name
ORDER BY d.dept_name;
/* Q34. */
SELECT c.category_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY 100.0 * (oi.unit_price - p.cost_price) / NULLIF(oi.unit_price, 0)) AS median_margin_pct,
       PERCENTILE_CONT(0.1) WITHIN GROUP (ORDER BY 100.0 * (oi.unit_price - p.cost_price) / NULLIF(oi.unit_price, 0)) AS p10_margin_pct
FROM sales.order_items oi
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category c ON c.category_id = b.category_id
GROUP BY c.category_name
ORDER BY c.category_name;
/* Q35. */
WITH basket AS (
    SELECT o.order_id, s.store_id, COUNT(oi.order_item_id) AS item_count
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN sales.order_items oi ON oi.order_id = o.order_id
    GROUP BY o.order_id, s.store_id
)
SELECT store_id,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY item_count) AS median_basket_size,
       PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY item_count) AS p90_basket_size
FROM basket
GROUP BY store_id
ORDER BY store_id;
/* Q36. */
WITH gaps AS (
    SELECT cust_id, order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date) AS gap_days
    FROM sales.orders
),
cust_median_gap AS (
    SELECT cust_id, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY gap_days) AS median_gap_days
    FROM gaps
    WHERE gap_days IS NOT NULL
    GROUP BY cust_id
)
SELECT PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY median_gap_days) AS p25_of_medians,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY median_gap_days) AS p50_of_medians,
       PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY median_gap_days) AS p75_of_medians
FROM cust_median_gap;
/* Q37. */
SELECT c.tier,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_order_value,
       ROUND(AVG(o.net_total), 2) AS mean_order_value,
       ROUND((AVG(o.net_total) - PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total))::numeric, 2) AS skew
FROM sales.orders o
JOIN customers.customers c ON c.customer_id = o.cust_id
GROUP BY c.tier
ORDER BY c.tier;
/* Q38. */
SELECT r.region_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS p50,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95,
       ROUND((PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total)
              / NULLIF(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total), 0))::numeric, 2) AS p95_p50_ratio
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q39. */
WITH quarterly AS (
    SELECT r.region_name, EXTRACT(YEAR FROM o.order_date) AS yr, EXTRACT(QUARTER FROM o.order_date) AS quarter,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_order_value
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_name, yr, quarter
)
SELECT region_name, yr, quarter, median_order_value,
       median_order_value - LAG(median_order_value) OVER (PARTITION BY region_name ORDER BY yr, quarter) AS qoq_change
FROM quarterly
ORDER BY region_name, yr, quarter;
/* Q40. */
WITH store_median AS (
    SELECT s.store_id,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_net_total
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    GROUP BY s.store_id
)
SELECT store_id, median_net_total,
       PERCENT_RANK() OVER (ORDER BY median_net_total) AS pct_rank_among_stores
FROM store_median
ORDER BY median_net_total DESC;
/* Q41. */
WITH region_p90 AS (
    SELECT r.region_id, r.region_name,
           PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY sh.delivered_date - o.order_date) AS p90_target
    FROM sales.orders o
    JOIN sales.shipments sh ON sh.order_id = o.order_id
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    WHERE o.order_status = 'Delivered' AND sh.delivered_date IS NOT NULL
    GROUP BY r.region_id, r.region_name
)
SELECT rp.region_name, rp.p90_target,
       ROUND(100.0 * COUNT(*) FILTER (WHERE sh.delivered_date - o.order_date <= rp.p90_target) / COUNT(*), 2) AS pct_within_target
FROM region_p90 rp
JOIN stores.stores s ON s.region_id = rp.region_id
JOIN sales.orders o ON o.store_id = s.store_id
JOIN sales.shipments sh ON sh.order_id = o.order_id
WHERE o.order_status = 'Delivered' AND sh.delivered_date IS NOT NULL
GROUP BY rp.region_name, rp.p90_target
ORDER BY rp.region_name;
/* Q42. */
SELECT priority,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600.0) AS median_resolution_hours
FROM support.tickets
WHERE resolved_date IS NOT NULL
GROUP BY priority
ORDER BY priority;
/* Q43. */
WITH dwell AS (
    SELECT device_type, session_id,
           LEAD(view_timestamp) OVER (PARTITION BY session_id ORDER BY view_timestamp) - view_timestamp AS dwell_interval
    FROM web_events.page_views
)
SELECT device_type,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM dwell_interval)) AS p95_dwell_seconds
FROM dwell
WHERE dwell_interval IS NOT NULL
GROUP BY device_type
ORDER BY device_type;
/* Q44. */
SELECT platform,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount) AS median_daily_spend,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY amount) AS p95_daily_spend
FROM marketing.ads_spend
GROUP BY platform
ORDER BY platform;
/* Q45. */
WITH cat_returns AS (
    SELECT c.category_name, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ret.refund_amount) AS median_refund,
           COUNT(*) AS return_count
    FROM sales.returns ret
    JOIN products.products p ON p.product_id = ret.prod_id
    JOIN core.dim_brand b ON b.brand_id = p.brand_id
    JOIN core.dim_category c ON c.category_id = b.category_id
    GROUP BY c.category_name
),
cat_items AS (
    SELECT c.category_name, COUNT(*) AS item_count
    FROM sales.order_items oi
    JOIN products.products p ON p.product_id = oi.prod_id
    JOIN core.dim_brand b ON b.brand_id = p.brand_id
    JOIN core.dim_category c ON c.category_id = b.category_id
    GROUP BY c.category_name
)
SELECT cr.category_name, cr.median_refund, cr.return_count,
       ROUND(100.0 * cr.return_count / ci.item_count, 2) AS refund_rate_pct
FROM cat_returns cr
JOIN cat_items ci ON ci.category_name = cr.category_name
ORDER BY cr.category_name;
/* Q46. */
SELECT EXTRACT(YEAR FROM c.registration_date) AS cohort_year,
       EXTRACT(YEAR FROM o.order_date) AS order_year,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_order_value
FROM sales.orders o
JOIN customers.customers c ON c.customer_id = o.cust_id
GROUP BY cohort_year, order_year
ORDER BY cohort_year, order_year;
/* Q47. */
WITH order_counts AS (
    SELECT cust_id, COUNT(*) AS order_count
    FROM sales.orders
    GROUP BY cust_id
)
SELECT r.region_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_order_value_repeat_customers
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
JOIN order_counts oc ON oc.cust_id = o.cust_id
WHERE oc.order_count > 1
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q48. */
WITH weekly AS (
    SELECT r.region_name, date_trunc('week', o.order_date)::date AS week_start, SUM(o.net_total) AS revenue
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_name, week_start
)
SELECT w1.region_name, w1.week_start, w1.revenue,
       (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY w2.revenue)
        FROM weekly w2
        WHERE w2.region_name = w1.region_name
          AND w2.week_start BETWEEN w1.week_start - INTERVAL '21 days' AND w1.week_start) AS moving_4wk_median
FROM weekly w1
ORDER BY w1.region_name, w1.week_start;
/* Q49. */
WITH cust_ltv AS (
    SELECT cust_id, SUM(net_total) AS lifetime_value
    FROM sales.orders
    GROUP BY cust_id
),
bucketed AS (
    SELECT cust_id, lifetime_value, NTILE(4) OVER (ORDER BY lifetime_value) AS ltv_quartile
    FROM cust_ltv
)
SELECT ltv_quartile, MIN(lifetime_value) AS bucket_min, MAX(lifetime_value) AS bucket_max, COUNT(*) AS customer_count
FROM bucketed
GROUP BY ltv_quartile
ORDER BY ltv_quartile;
/* Q50. */
WITH region_p99 AS (
    SELECT r.region_id, r.region_name,
           PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY o.net_total) AS p99_net_total
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_id, r.region_name
)
SELECT o.order_id, rp.region_name, o.net_total, rp.p99_net_total, c.first_name, c.last_name, s.store_name
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN region_p99 rp ON rp.region_id = s.region_id
JOIN customers.customers c ON c.customer_id = o.cust_id
WHERE o.net_total > rp.p99_net_total
ORDER BY rp.region_name, o.net_total DESC;

/* ============================================================
   SECTION C: LATEST-PER-GROUP AT SCALE (25)
   ------------------------------------------------------------ */
/* Q51. */
WITH via_distinct_on AS (
    SELECT DISTINCT ON (cust_id) cust_id, order_id, order_date, net_total
    FROM sales.orders
    ORDER BY cust_id, order_date DESC
),
via_row_number AS (
    SELECT cust_id, order_id, order_date, net_total FROM (
        SELECT cust_id, order_id, order_date, net_total,
               ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date DESC) AS rn
        FROM sales.orders
    ) ranked WHERE rn = 1
)
SELECT (SELECT COUNT(*) FROM via_distinct_on) AS distinct_on_rows,
       (SELECT COUNT(*) FROM via_row_number) AS row_number_rows,
       (SELECT COUNT(*) FROM via_distinct_on d JOIN via_row_number r
          ON r.cust_id = d.cust_id AND r.order_id = d.order_id AND r.order_date = d.order_date AND r.net_total = d.net_total) AS matching_rows;
/* Q52. */
SELECT DISTINCT ON (o.cust_id) o.cust_id, o.order_id, o.order_date,
       CURRENT_DATE - o.order_date AS days_since_order, s.store_name
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
WHERE o.order_status = 'Delivered'
ORDER BY o.cust_id, o.order_date DESC;
/* Q53. */
WITH latest_price AS (
    SELECT DISTINCT ON (p.product_id) p.product_id, oi.unit_price AS latest_price, p.cost_price
    FROM sales.order_items oi
    JOIN sales.orders o ON o.order_id = oi.order_id
    JOIN products.products p ON p.product_id = oi.prod_id
    ORDER BY p.product_id, o.order_date DESC
)
SELECT product_id, latest_price, cost_price,
       ROUND(100.0 * (latest_price - cost_price) / NULLIF(latest_price, 0), 2) AS current_margin_pct
FROM latest_price
ORDER BY product_id;
/* Q54. */
WITH latest_snap AS (
    SELECT DISTINCT ON (warehouse_id, product_id) warehouse_id, product_id, snapshot_date, quantity_on_hand
    FROM supply_chain.inventory_snapshots
    ORDER BY warehouse_id, product_id, snapshot_date DESC
),
reorder_ref AS (
    SELECT product_id, ROUND(AVG(reorder_level)) AS reorder_level
    FROM products.inventory
    GROUP BY product_id
)
SELECT ls.warehouse_id, ls.product_id, ls.quantity_on_hand, rr.reorder_level,
       (ls.quantity_on_hand < rr.reorder_level) AS needs_reorder
FROM latest_snap ls
LEFT JOIN reorder_ref rr ON rr.product_id = ls.product_id
ORDER BY ls.warehouse_id, ls.product_id;
/* Q55. */
WITH ranked AS (
    SELECT employee_id, amount, payment_date,
           ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY payment_date DESC) AS rn
    FROM hr.salary_history
)
SELECT cur.employee_id, cur.amount AS latest_amount, prev.amount AS previous_amount,
       ROUND(100.0 * (cur.amount - prev.amount) / NULLIF(prev.amount, 0), 2) AS pct_change
FROM ranked cur
LEFT JOIN ranked prev ON prev.employee_id = cur.employee_id AND prev.rn = 2
WHERE cur.rn = 1
ORDER BY cur.employee_id;
/* Q56. */
WITH latest_order AS (
    SELECT DISTINCT ON (cust_id) cust_id, order_id AS latest_order_id, order_date AS latest_order_date
    FROM sales.orders
    ORDER BY cust_id, order_date DESC
),
latest_ticket AS (
    SELECT DISTINCT ON (customer_id) customer_id, ticket_id AS latest_ticket_id, created_date AS latest_ticket_date
    FROM support.tickets
    ORDER BY customer_id, created_date DESC
)
SELECT lo.cust_id, lo.latest_order_id, lo.latest_order_date, lt.latest_ticket_id, lt.latest_ticket_date
FROM latest_order lo
LEFT JOIN latest_ticket lt ON lt.customer_id = lo.cust_id
ORDER BY lo.cust_id;
/* Q57. */
WITH running AS (
    SELECT product_id, review_id, review_date, rating,
           COUNT(*) OVER (PARTITION BY product_id ORDER BY review_date) AS running_review_count
    FROM customers.reviews
)
SELECT DISTINCT ON (product_id) product_id, review_id, review_date, rating, running_review_count
FROM running
ORDER BY product_id, review_date DESC;
/* Q58. */
SELECT DISTINCT ON (order_id) order_id, shipment_id, status, shipped_date,
       CURRENT_DATE - shipped_date AS age_days
FROM sales.shipments
ORDER BY order_id, shipped_date DESC;
/* Q59. */
WITH latest_order AS (
    SELECT DISTINCT ON (store_id) store_id, order_date AS latest_order_date
    FROM sales.orders
    ORDER BY store_id, order_date DESC
)
SELECT store_id, latest_order_date, CURRENT_DATE - latest_order_date AS recency_gap_days
FROM latest_order
ORDER BY recency_gap_days DESC;
/* Q60. */
WITH latest AS (
    SELECT DISTINCT ON (cust_id) cust_id, order_id, order_status, order_date
    FROM sales.orders
    ORDER BY cust_id, order_date DESC
)
SELECT cust_id, order_id, order_status, order_date
FROM latest
WHERE order_status IN ('Returned', 'Cancelled')
ORDER BY cust_id;
/* Q61. */
WITH latest AS (
    SELECT DISTINCT ON (cust_id) cust_id, order_date AS latest_order_date
    FROM sales.orders
    ORDER BY cust_id, order_date DESC
)
SELECT cust_id, latest_order_date,
       RANK() OVER (ORDER BY latest_order_date DESC) AS recency_rank
FROM latest
ORDER BY recency_rank;
/* Q62. */
SELECT DISTINCT ON (order_id) order_id, payment_id, amount, status,
       (status = 'Failed') AS latest_payment_failed
FROM finance.payments
ORDER BY order_id, payment_id DESC;
/* Q63. */
SELECT DISTINCT ON (employee_id) employee_id, attendance_date, check_in, check_out,
       (check_in IS NULL) AS is_absent
FROM hr.attendance
ORDER BY employee_id, attendance_date DESC;
/* Q64. */
SELECT DISTINCT ON (r.region_name) r.region_name, o.order_id, o.order_date, o.net_total, o.order_status, s.store_name
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
ORDER BY r.region_name, o.order_date DESC;
/* Q65. */
SELECT DISTINCT ON (rd.customer_id) rd.customer_id, rd.redemption_id, rd.points_redeemed, rd.redemption_date,
       m.points_balance AS points_remaining
FROM loyalty.redemptions rd
JOIN loyalty.members m ON m.customer_id = rd.customer_id
ORDER BY rd.customer_id, rd.redemption_date DESC;
/* Q66. */
WITH first_o AS (
    SELECT DISTINCT ON (cust_id) cust_id, order_date AS first_order_date
    FROM sales.orders
    ORDER BY cust_id, order_date ASC
),
latest_o AS (
    SELECT DISTINCT ON (cust_id) cust_id, order_date AS latest_order_date
    FROM sales.orders
    ORDER BY cust_id, order_date DESC
)
SELECT f.cust_id, f.first_order_date, l.latest_order_date,
       l.latest_order_date - f.first_order_date AS lifetime_span_days
FROM first_o f
JOIN latest_o l ON l.cust_id = f.cust_id
ORDER BY f.cust_id;
/* Q67. */
WITH call_pct AS (
    SELECT call_id, agent_id, call_start_time, call_duration_seconds,
           PERCENT_RANK() OVER (ORDER BY call_duration_seconds) AS duration_pct_rank
    FROM call_center.calls
)
SELECT DISTINCT ON (agent_id) agent_id, call_id, call_start_time, call_duration_seconds, duration_pct_rank
FROM call_pct
ORDER BY agent_id, call_start_time DESC;
/* Q68. */
SELECT DISTINCT ON (a.city) a.city, c.customer_id, c.first_name, c.last_name, c.registration_date, c.tier
FROM customers.customers c
JOIN customers.addresses a ON a.customer_id = c.customer_id
ORDER BY a.city, c.registration_date DESC;
/* Q69. */
WITH annual AS (
    SELECT store_id, EXTRACT(YEAR FROM expense_date) AS yr, SUM(amount) AS total_amount
    FROM stores.expenses
    GROUP BY store_id, yr
),
yoy AS (
    SELECT store_id, yr, total_amount,
           total_amount - LAG(total_amount) OVER (PARTITION BY store_id ORDER BY yr) AS yoy_change
    FROM annual
),
latest_expense AS (
    SELECT DISTINCT ON (store_id) store_id, expense_date, amount
    FROM stores.expenses
    ORDER BY store_id, expense_date DESC
)
SELECT le.store_id, le.expense_date, le.amount AS latest_expense_amount, y.yoy_change
FROM latest_expense le
JOIN yoy y ON y.store_id = le.store_id AND y.yr = EXTRACT(YEAR FROM le.expense_date)
ORDER BY le.store_id;
/* Q70. */
SELECT DISTINCT ON (line_id) line_id, work_order_id, start_timestamp, end_timestamp,
       end_timestamp - start_timestamp AS cycle_time
FROM manufacture.work_orders
WHERE end_timestamp IS NOT NULL
ORDER BY line_id, start_timestamp DESC;
/* Q71. */
WITH order_pct AS (
    SELECT cust_id, order_id, net_total,
           PERCENT_RANK() OVER (ORDER BY net_total) AS value_pct_rank
    FROM sales.orders
)
SELECT DISTINCT ON (cust_id) cust_id, order_id, net_total, value_pct_rank
FROM order_pct
ORDER BY cust_id, net_total DESC;
/* Q72. */
SELECT DISTINCT ON (pm.mode_name) pm.mode_name, o.order_id, o.order_date, o.net_total
FROM sales.orders o
JOIN finance.payment_modes pm ON pm.mode_id = o.payment_mode_id
ORDER BY pm.mode_name, o.order_date DESC;
/* Q73. */
SELECT DISTINCT ON (isn.warehouse_id, isn.product_id) isn.warehouse_id, isn.product_id, isn.snapshot_date,
       isn.quantity_on_hand, isn.quantity_on_hand * p.cost_price AS stock_value
FROM supply_chain.inventory_snapshots isn
JOIN products.products p ON p.product_id = isn.product_id
ORDER BY isn.warehouse_id, isn.product_id, isn.snapshot_date DESC;
/* Q74. */
SELECT DISTINCT ON (agent_id) agent_id, ticket_id, status, created_date, resolved_date
FROM support.tickets
WHERE agent_id IS NOT NULL
ORDER BY agent_id, created_date DESC;
/* Q75. */
SELECT DISTINCT ON (cust_id) cust_id, order_id, order_date, order_status, net_total
FROM sales.orders
ORDER BY cust_id, order_date DESC, order_id DESC;

/* ============================================================
   SECTION D: PRODUCTION KPI / EXEC DASHBOARDS (25)
   ------------------------------------------------------------ */
/* Q76. */
WITH latest AS (
    SELECT DISTINCT ON (r.region_name) r.region_name, o.order_date AS latest_order_date
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    ORDER BY r.region_name, o.order_date DESC
)
SELECT r.region_name, COUNT(*) AS order_count,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_aov,
       MAX(l.latest_order_date) AS latest_order_date
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
JOIN latest l ON l.region_name = r.region_name
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q77. */
WITH delivery AS (
    SELECT r.region_id, r.region_name,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sh.delivered_date - o.order_date) AS median_delivery_days,
           PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY sh.delivered_date - o.order_date) AS p90_delivery_days
    FROM sales.orders o
    JOIN sales.shipments sh ON sh.order_id = o.order_id
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    WHERE o.order_status = 'Delivered' AND sh.delivered_date IS NOT NULL
    GROUP BY r.region_id, r.region_name
)
SELECT d.region_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_aov,
       d.median_delivery_days,
       ROUND(100.0 * COUNT(*) FILTER (WHERE sh.delivered_date - o.order_date <= d.p90_delivery_days) / COUNT(*), 2) AS sla_pct
FROM delivery d
JOIN stores.stores s ON s.region_id = d.region_id
JOIN sales.orders o ON o.store_id = s.store_id
JOIN sales.shipments sh ON sh.order_id = o.order_id
WHERE o.order_status = 'Delivered' AND sh.delivered_date IS NOT NULL
GROUP BY d.region_name, d.median_delivery_days, d.p90_delivery_days
ORDER BY d.region_name;
/* Q78. */
WITH store_pct AS (
    SELECT s.store_id,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_net_total,
           PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_net_total
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    GROUP BY s.store_id
)
SELECT store_id, median_net_total, p95_net_total,
       RANK() OVER (ORDER BY median_net_total DESC) AS rnk,
       NTILE(10) OVER (ORDER BY median_net_total DESC) AS decile
FROM store_pct
ORDER BY rnk;
/* Q79. */
WITH latest_signup AS (
    SELECT DISTINCT ON (tier_id) tier_id, join_date AS latest_signup
    FROM loyalty.members
    ORDER BY tier_id, join_date DESC
)
SELECT t.tier_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov,
       PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY o.net_total) AS p90_aov,
       COUNT(DISTINCT c.customer_id) AS member_count,
       MAX(ls.latest_signup) AS latest_signup
FROM sales.orders o
JOIN customers.customers c ON c.customer_id = o.cust_id
JOIN loyalty.members m ON m.customer_id = c.customer_id
JOIN loyalty.tiers t ON t.tier_id = m.tier_id
JOIN latest_signup ls ON ls.tier_id = t.tier_id
GROUP BY t.tier_name
ORDER BY t.tier_name;
/* Q80. */
WITH deliv AS (
    SELECT w.warehouse_id, w.name AS warehouse_name, sh.delivered_date - o.order_date AS delivery_days
    FROM sales.orders o
    JOIN sales.shipments sh ON sh.order_id = o.order_id
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    JOIN supply_chain.warehouses w ON w.region = r.region_name
    WHERE o.order_status = 'Delivered' AND sh.delivered_date IS NOT NULL
)
SELECT warehouse_id, warehouse_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY delivery_days) AS median_delivery_days,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY delivery_days) AS p95_delivery_days,
       COUNT(*) FILTER (WHERE delivery_days > 7) AS breach_count_over_7d,
       ROUND(100.0 * COUNT(*) FILTER (WHERE delivery_days > 7) / COUNT(*), 2) AS breach_pct
FROM deliv
GROUP BY warehouse_id, warehouse_name
ORDER BY warehouse_id;
/* Q81. */
WITH latest_open AS (
    SELECT DISTINCT ON (priority) priority, ticket_id AS latest_open_ticket_id, created_date
    FROM support.tickets
    WHERE status IN ('Open', 'In Progress')
    ORDER BY priority, created_date DESC
)
SELECT t.priority,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (t.resolved_date - t.created_date)) / 3600.0) AS median_resolution_hours,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (t.resolved_date - t.created_date)) / 3600.0) AS p95_resolution_hours,
       ROUND(100.0 * COUNT(*) FILTER (WHERE EXTRACT(EPOCH FROM (t.resolved_date - t.created_date)) / 3600.0 > 48) / COUNT(*), 2) AS breach_pct,
       MAX(lo.latest_open_ticket_id) AS latest_open_ticket_id
FROM support.tickets t
LEFT JOIN latest_open lo ON lo.priority = t.priority
WHERE t.resolved_date IS NOT NULL
GROUP BY t.priority
ORDER BY t.priority;
/* Q82. */
WITH agent_pct AS (
    SELECT agent_id,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY call_duration_seconds) AS median_duration,
           PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY call_duration_seconds) AS p95_duration
    FROM call_center.calls
    GROUP BY agent_id
),
latest_call AS (
    SELECT DISTINCT ON (agent_id) agent_id, call_start_time AS latest_call_time
    FROM call_center.calls
    ORDER BY agent_id, call_start_time DESC
)
SELECT ap.agent_id, ap.median_duration, ap.p95_duration, lc.latest_call_time,
       RANK() OVER (ORDER BY ap.p95_duration DESC) AS worst_p95_rank
FROM agent_pct ap
JOIN latest_call lc ON lc.agent_id = ap.agent_id
ORDER BY worst_p95_rank;
/* Q83. */
WITH latest_price AS (
    SELECT DISTINCT ON (p.product_id) p.product_id, oi.unit_price AS latest_selling_price
    FROM sales.order_items oi
    JOIN sales.orders o ON o.order_id = oi.order_id
    JOIN products.products p ON p.product_id = oi.prod_id
    ORDER BY p.product_id, o.order_date DESC
)
SELECT c.category_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY 100.0 * (oi.unit_price - p.cost_price) / NULLIF(oi.unit_price, 0)) AS median_margin_pct,
       PERCENTILE_CONT(0.1) WITHIN GROUP (ORDER BY 100.0 * (oi.unit_price - p.cost_price) / NULLIF(oi.unit_price, 0)) AS p10_margin_pct,
       ROUND(AVG(lp.latest_selling_price), 2) AS avg_latest_selling_price
FROM sales.order_items oi
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category c ON c.category_id = b.category_id
JOIN latest_price lp ON lp.product_id = p.product_id
GROUP BY c.category_name
ORDER BY c.category_name;
/* Q84. */
SELECT EXTRACT(YEAR FROM c.registration_date) AS cohort_year,
       EXTRACT(YEAR FROM o.order_date) AS order_year,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov
FROM sales.orders o
JOIN customers.customers c ON c.customer_id = o.cust_id
GROUP BY cohort_year, order_year
ORDER BY cohort_year, order_year;
/* Q85. */
WITH region_p99 AS (
    SELECT r.region_id, r.region_name,
           PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY o.net_total) AS p99_net_total
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_id, r.region_name
)
SELECT rp.region_name, o.order_id, o.net_total, c.customer_id, c.first_name, c.last_name,
       CURRENT_DATE - o.order_date AS recency_days
FROM region_p99 rp
JOIN stores.stores s ON s.region_id = rp.region_id
JOIN sales.orders o ON o.store_id = s.store_id
JOIN customers.customers c ON c.customer_id = o.cust_id
WHERE o.net_total > rp.p99_net_total
ORDER BY rp.region_name, o.net_total DESC;
/* Q86. */
WITH latest AS (
    SELECT DISTINCT ON (cust_id) cust_id, order_status
    FROM sales.orders
    ORDER BY cust_id, order_date DESC
),
cust_median AS (
    SELECT cust_id, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total) AS lifetime_median_order
    FROM sales.orders
    GROUP BY cust_id
)
SELECT l.cust_id, cm.lifetime_median_order
FROM latest l
JOIN cust_median cm ON cm.cust_id = l.cust_id
WHERE l.order_status = 'Returned'
ORDER BY l.cust_id;
/* Q87. */
WITH monthly AS (
    SELECT r.region_name, date_trunc('month', o.order_date)::date AS month, SUM(o.net_total) AS revenue
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_name, month
),
quarterly AS (
    SELECT region_name, date_trunc('quarter', month)::date AS quarter_start,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY revenue) AS median_monthly_revenue
    FROM monthly
    GROUP BY region_name, quarter_start
)
SELECT region_name, quarter_start, median_monthly_revenue,
       median_monthly_revenue - LAG(median_monthly_revenue) OVER (PARTITION BY region_name ORDER BY quarter_start) AS qoq_trend
FROM quarterly
ORDER BY region_name, quarter_start;
/* Q88. */
WITH latest_price AS (
    SELECT DISTINCT ON (p.product_id) p.product_id, oi.unit_price AS latest_selling_price
    FROM sales.order_items oi
    JOIN sales.orders o ON o.order_id = oi.order_id
    JOIN products.products p ON p.product_id = oi.prod_id
    ORDER BY p.product_id, o.order_date DESC
),
median_price AS (
    SELECT prod_id, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY unit_price) AS median_historical_price
    FROM sales.order_items
    GROUP BY prod_id
)
SELECT lp.product_id, lp.latest_selling_price, mp.median_historical_price,
       ROUND((100.0 * (lp.latest_selling_price - mp.median_historical_price) / NULLIF(mp.median_historical_price, 0))::numeric, 2) AS drift_pct
FROM latest_price lp
JOIN median_price mp ON mp.prod_id = lp.product_id
ORDER BY lp.product_id;
/* Q89. */
WITH latest_snap AS (
    SELECT DISTINCT ON (warehouse_id, product_id) warehouse_id, product_id, snapshot_date, quantity_on_hand
    FROM supply_chain.inventory_snapshots
    ORDER BY warehouse_id, product_id, snapshot_date DESC
)
SELECT warehouse_id, product_id, snapshot_date,
       CURRENT_DATE - snapshot_date AS snapshot_age_days,
       (quantity_on_hand = 0) AS is_stockout
FROM latest_snap
ORDER BY warehouse_id, product_id;
/* Q90. */
SELECT r.region_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sh.shipped_date - o.order_date) AS median_order_to_ship_days,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sh.delivered_date - sh.shipped_date) AS median_ship_to_deliver_days
FROM sales.orders o
JOIN sales.shipments sh ON sh.order_id = o.order_id
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
WHERE sh.shipped_date IS NOT NULL AND sh.delivered_date IS NOT NULL
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q91. */
WITH matrix AS (
    SELECT r.region_name, EXTRACT(QUARTER FROM o.order_date) AS quarter,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_name, quarter
)
SELECT region_name,
       MAX(median_aov) FILTER (WHERE quarter = 1) AS q1,
       MAX(median_aov) FILTER (WHERE quarter = 2) AS q2,
       MAX(median_aov) FILTER (WHERE quarter = 3) AS q3,
       MAX(median_aov) FILTER (WHERE quarter = 4) AS q4,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY median_aov) AS row_median
FROM matrix
GROUP BY region_name
ORDER BY region_name;
/* Q92. */
WITH cust_ltv AS (
    SELECT cust_id, SUM(net_total) AS lifetime_value
    FROM sales.orders
    GROUP BY cust_id
),
cuts AS (
    SELECT PERCENTILE_CONT(0.1) WITHIN GROUP (ORDER BY lifetime_value) AS p10_cut,
           PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY lifetime_value) AS p90_cut
    FROM cust_ltv
)
SELECT cl.cust_id, cl.lifetime_value,
       CASE WHEN cl.lifetime_value >= cuts.p90_cut THEN 'top_decile'
            WHEN cl.lifetime_value <= cuts.p10_cut THEN 'bottom_decile'
       END AS segment,
       cuts.p10_cut, cuts.p90_cut
FROM cust_ltv cl, cuts
WHERE cl.lifetime_value >= cuts.p90_cut OR cl.lifetime_value <= cuts.p10_cut
ORDER BY cl.lifetime_value DESC;
/* Q93. */
WITH dwell AS (
    SELECT device_type, session_id,
           LEAD(view_timestamp) OVER (PARTITION BY session_id ORDER BY view_timestamp) - view_timestamp AS dwell_interval
    FROM web_events.page_views
),
latency AS (
    SELECT device_type,
           PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM dwell_interval)) AS p95_dwell_seconds
    FROM dwell
    WHERE dwell_interval IS NOT NULL
    GROUP BY device_type
),
hourly AS (
    SELECT device_type, EXTRACT(HOUR FROM view_timestamp) AS hr, COUNT(*) AS view_count
    FROM web_events.page_views
    GROUP BY device_type, hr
),
peak AS (
    SELECT DISTINCT ON (device_type) device_type, hr AS peak_hour, view_count AS peak_view_count
    FROM hourly
    ORDER BY device_type, view_count DESC
)
SELECT l.device_type, l.p95_dwell_seconds, p.peak_hour, p.peak_view_count
FROM latency l
JOIN peak p ON p.device_type = l.device_type
ORDER BY l.device_type;
/* Q94. */
SELECT d.dept_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ps.net_salary) AS median_net_salary,
       PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY ps.net_salary) AS p25_net_salary,
       PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY ps.net_salary) AS p75_net_salary,
       PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY ps.net_salary) - PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY ps.net_salary) AS iqr,
       COUNT(DISTINCT e.employee_id) AS headcount
FROM payroll.pay_slips ps
JOIN stores.employees e ON e.employee_id = ps.employee_id
JOIN core.dim_department d ON d.dept_id = e.dept_id
GROUP BY d.dept_name
ORDER BY d.dept_name;
/* Q95. */
WITH latest_order AS (
    SELECT DISTINCT ON (cust_id) cust_id, order_id AS latest_order_id, order_date AS latest_order_date
    FROM sales.orders ORDER BY cust_id, order_date DESC
),
latest_review AS (
    SELECT DISTINCT ON (customer_id) customer_id, review_id AS latest_review_id, review_date AS latest_review_date
    FROM customers.reviews ORDER BY customer_id, review_date DESC
),
latest_ticket AS (
    SELECT DISTINCT ON (customer_id) customer_id, ticket_id AS latest_ticket_id, created_date AS latest_ticket_date
    FROM support.tickets ORDER BY customer_id, created_date DESC
)
SELECT c.customer_id, lo.latest_order_id, lo.latest_order_date,
       lr.latest_review_id, lr.latest_review_date,
       lt.latest_ticket_id, lt.latest_ticket_date
FROM customers.customers c
LEFT JOIN latest_order lo ON lo.cust_id = c.customer_id
LEFT JOIN latest_review lr ON lr.customer_id = c.customer_id
LEFT JOIN latest_ticket lt ON lt.customer_id = c.customer_id
ORDER BY c.customer_id;
/* Q96. */
WITH region_median AS (
    SELECT r.region_id, r.region_name,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS region_median
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_id, r.region_name
),
store_median AS (
    SELECT s.store_id, s.region_id,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS store_median
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    GROUP BY s.store_id, s.region_id
)
SELECT sm.store_id, rm.region_name, sm.store_median, rm.region_median,
       sm.store_median - rm.region_median AS gap_to_region
FROM store_median sm
JOIN region_median rm ON rm.region_id = sm.region_id
ORDER BY gap_to_region DESC;
/* Q97. */
WITH region_bounds AS (
    SELECT r.region_id, r.region_name,
           PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY o.net_total) AS p5,
           PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_val
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_id, r.region_name
)
SELECT rb.region_name,
       ROUND(AVG(o.net_total), 2) AS raw_mean,
       ROUND(AVG(o.net_total) FILTER (WHERE o.net_total BETWEEN rb.p5 AND rb.p95), 2) AS trimmed_mean,
       MAX(rb.median_val) AS median_val
FROM region_bounds rb
JOIN stores.stores s ON s.region_id = rb.region_id
JOIN sales.orders o ON o.store_id = s.store_id
GROUP BY rb.region_name
ORDER BY rb.region_name;
/* Q98. */
WITH quarterly AS (
    SELECT r.region_name, EXTRACT(YEAR FROM o.order_date) AS yr, EXTRACT(QUARTER FROM o.order_date) AS quarter,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov,
           PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_aov
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_name, yr, quarter
),
latest_q AS (
    SELECT MAX(yr) AS max_yr FROM quarterly
)
SELECT q.region_name, q.yr, q.quarter, q.median_aov, q.p95_aov,
       (q.yr = (SELECT max_yr FROM latest_q) AND q.quarter = (SELECT MAX(quarter) FROM quarterly WHERE yr = (SELECT max_yr FROM latest_q))) AS is_latest_quarter
FROM quarterly q
ORDER BY q.region_name, q.yr, q.quarter;
/* Q99. */
WITH region_delivery AS (
    SELECT r.region_name, date_trunc('month', o.order_date)::date AS month,
           PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY sh.delivered_date - o.order_date) AS p95_delivery_days
    FROM sales.orders o
    JOIN sales.shipments sh ON sh.order_id = o.order_id
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    WHERE o.order_status = 'Delivered' AND sh.delivered_date IS NOT NULL
    GROUP BY r.region_name, month
)
SELECT region_name, month, p95_delivery_days
FROM region_delivery
WHERE month = (SELECT MAX(month) FROM region_delivery)
  AND p95_delivery_days > 7
ORDER BY region_name;
/* Q100. */
WITH delivery AS (
    SELECT r.region_id,
           PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY sh.delivered_date - o.order_date) AS p90_target
    FROM sales.orders o
    JOIN sales.shipments sh ON sh.order_id = o.order_id
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    WHERE o.order_status = 'Delivered' AND sh.delivered_date IS NOT NULL
    GROUP BY r.region_id
),
latest AS (
    SELECT DISTINCT ON (r.region_name) r.region_name, o.order_date AS latest_order_date
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    ORDER BY r.region_name, o.order_date DESC
)
SELECT r.region_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov,
       PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY o.net_total) AS p90_aov,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_aov,
       ROUND(100.0 * COUNT(*) FILTER (WHERE sh.delivered_date - o.order_date <= d.p90_target) / COUNT(*), 2) AS sla_pct,
       MAX(l.latest_order_date) AS latest_order_date,
       RANK() OVER (ORDER BY PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) DESC) AS rnk
FROM sales.orders o
JOIN sales.shipments sh ON sh.order_id = o.order_id
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
JOIN delivery d ON d.region_id = r.region_id
JOIN latest l ON l.region_name = r.region_name
WHERE o.order_status = 'Delivered' AND sh.delivered_date IS NOT NULL
GROUP BY r.region_name, d.p90_target
ORDER BY r.region_name;
