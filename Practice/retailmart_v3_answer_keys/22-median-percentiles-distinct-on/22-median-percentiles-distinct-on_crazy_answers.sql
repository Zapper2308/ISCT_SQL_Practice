/* ============================================================
   ANSWER KEY - Median, Percentiles & DISTINCT ON (CRAZY LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1. CONCEPTUAL: a t-digest/sketch service ingests each value once, folding it into a compact set of weighted centroids (denser near the tails) in O(1) amortized update cost and bounded memory; percentile reads interpolate against the centroids instead of a full sort, and centroids from different shards/time-windows can be merged - trading exactness for scalability to billions of rows. */
/* Q2. Exact percentiles (PERCENTILE_CONT) are required when a number must be defensible/contractual (SLA credits, pricing floors, audits) and the dataset is small enough to sort affordably; approximate/sketch-based percentiles are acceptable for dashboards and alerting where a known error budget (e.g. t-digest's ~0.1-1% relative error near the tails) is fine and the win is avoiding a full sort over billions of rows. */
/* Q3. Streaming median maintenance keeps two balanced heaps (a max-heap of the lower half, a min-heap of the upper half); each new order's value is pushed into the correct heap and the heaps are rebalanced to differ in size by at most one, so the median is always the top of the larger heap (or the average of both tops) in O(log n) per insert with no re-sort. */
/* Q4. Reservoir sampling maintains a fixed-size sample (e.g. 10k rows) as the table streams past, replacing a random existing sample row with decreasing probability for each new row - PERCENTILE_CONT is then run only against the bounded sample, making query cost independent of total table size at the price of sampling error. */
/* Q5. Naive averaging of pre-computed per-shard percentiles ignores each shard's underlying value distribution and row count - two shards with very different data can have the same median yet very different spreads, so averaging their P95s produces a number that corresponds to no real global rank; correct merging requires combining the underlying sketches/centroids (or raw sorted data) before re-deriving the percentile. */
/* Q6. Histogram-bucket percentiles (pick the bucket whose cumulative count crosses the target rank, optionally interpolate within it) are fast and cheap at any scale since buckets are pre-aggregated, but accuracy is capped by bucket width - PERCENTILE_CONT sorts/ranks every actual value for exact interpolation, which is precise but requires scanning and sorting the full group. */
/* Q7. At 100M+ rows, latest-per-group needs a composite index on (group_key, ts DESC) so DISTINCT ON can walk it without a full sort; range/list partitioning by the group key or by date keeps each DISTINCT ON scan confined to relevant partitions; and a materialized view refreshed on a schedule (or CONCURRENTLY) avoids paying the full latest-per-group cost on every dashboard load. */
/* Q8. A trigger keeps the current-state table synchronously correct on every write but adds latency/lock contention to the OLTP path; an incrementally-maintained MV (or periodic REFRESH) decouples writes from reads but the current-state table is stale between refreshes; a full batch reload is simplest to reason about but the most expensive and slowest to reflect new data - the choice trades write-path cost, staleness tolerance, and operational complexity. */
/* Q9. DISTINCT ON with a supporting composite index typically plans as an Index Scan walking groups in order (cheapest); LATERAL Top-1 (CROSS JOIN LATERAL with a per-outer-row indexed subquery + LIMIT 1) plans as a nested-loop with an Index Scan per outer row, which is efficient when the outer set is small/already filtered; a plain window function (ROW_NUMBER() OVER (...)) forces materializing and ranking every row before filtering rn=1, which is usually the most expensive of the three at scale. */
/* Q10. Weighted-percentile sketch (SQL outline): expand each row into `weight` virtual copies (or compute a running SUM(weight) OVER (ORDER BY value) as cumulative weight), then find the smallest value whose cumulative weight fraction crosses the target percentile of the total weight - effectively a weighted PERCENTILE_DISC computed manually with window functions. */
/* Q11. Reliable P99/P99.9 estimates need enough tail observations to be stable - as a rule of thumb at least 100 observations per percentile point (so ~10,000+ rows for a meaningful P99, ~100,000+ for P99.9); below that, the reported tail value is dominated by sampling noise and shifts wildly between runs/windows. */
/* Q12. A sliding-window median for a real-time dashboard is best served by maintaining the balanced-heap structure (Q3) incrementally as the window advances - adding new points and removing points that fall out of the window - rather than re-running PERCENTILE_CONT from scratch on every tick, since ordered-set aggregates have no native windowed/incremental form in SQL. */
/* Q13. Guardrails: exclude NULLs explicitly with WHERE col IS NOT NULL before aggregating (they're silently dropped by PERCENTILE_CONT but a NULL flood can still starve a group down to too few real rows), enforce a minimum group size before trusting a percentile, and cap/investigate extreme skew (e.g. IQR-fence check) so one pathological group doesn't dominate a rolled-up view. */
/* Q14. PERCENTILE_DISC always returns one of the actual observed values in the dataset (never interpolated), so for a contractual SLA threshold ("95% of requests resolved within X") the reported cut point corresponds to a real request that really happened - defensible in an audit - whereas PERCENTILE_CONT can return a value no single observation ever had. */
/* Q15. Idempotent backfill: compute each historical period's percentile into a staging row keyed by (period, metric), then upsert (INSERT ... ON CONFLICT (period, metric) DO UPDATE) into the summary fact table rather than blind INSERT - re-running the backfill for the same period always converges to the same final row instead of duplicating it. */
/* Q16. Per-tenant percentile isolation means every percentile query (and any MV built on top of it) must GROUP BY the tenant key so PERCENTILE_CONT only ever ranks that tenant's own rows - a missing tenant filter/predicate on a shared table is a classic leak where one tenant's outliers silently pollute another's SLA numbers. */
/* Q17. PERCENTILE_CONT is implemented as a sort-based ordered-set aggregate - Postgres must fully sort each group's values (or use a hash aggregate keyed by group) before it can walk the ordered set to interpolate; if the sort/hash working set for a group (or all groups combined) exceeds work_mem it spills to disk, which is far slower, so raising work_mem for percentile-heavy sessions keeps more of the sort in memory. */
/* Q18. A percentile-drift alert compares this week's P95 for a metric against last week's P95 (or a rolling baseline), fires when the relative shift exceeds a threshold (e.g. >20%), and should require the shift to persist across more than one evaluation window to avoid flapping on a single noisy period - the metric is simply week-over-week %Δ in P95, the threshold is tuned to the metric's normal volatility. */
/* Q19. Trimmed mean (drop the top/bottom k% then average what remains) is preferred when you still want a mean-like "typical magnitude" number that's robust to a few extreme outliers; winsorized mean (clamp extremes to the P_k/P_(100-k) bounds rather than dropping them) is preferred when you want to keep every row represented (e.g. for a total that should still roughly reconcile) while limiting how much any single outlier can skew it. */
/* Q20. Median-of-group-medians collapses each group to one number first and then medians those numbers, so it is blind to how many rows or how skewed each group's own distribution was; the true global median ranks every underlying row together regardless of which group it came from - reconciling the two for a rollup usually means recomputing PERCENTILE_CONT directly over the union of underlying rows rather than aggregating pre-computed group medians. */
/* Q21. A percentile API contract for the BI layer should return one row/object per grouping key with named fields (p50, p90, p95, p99) rather than raw values without labels, document which column is being percentiled and any pre-filtering (e.g. Delivered orders only), and guarantee a stable output shape (SQL: SELECT group_key, PERCENTILE_CONT(0.5)... AS p50, ... AS p90, ... AS p95, ... AS p99 FROM ... GROUP BY group_key). */
/* Q22. An idempotent latest-snapshot pipeline tolerant of late-arriving data re-derives "latest per group" via DISTINCT ON (group_key ORDER BY group_key, event_time DESC) over the full history on each run (or an incrementally-maintained MV refreshed after the late data lands) rather than trusting an append-only "last write wins" pointer - so a late-arriving row with an older event_time never overwrites a truly newer one, and re-running the pipeline for the same data always produces the same result. */
/* Q23. An SCD type-2 read for "latest attribute per entity" (e.g. tier over time) is exactly DISTINCT ON (entity_id) ... ORDER BY entity_id, effective_date DESC (or tier_updated_at DESC) - each row change is a new version with its own timestamp, and DISTINCT ON picks the most recent version per entity in one pass without needing a separate "is_current" flag column. */
/* Q24. Percentile-based guardrails for dynamic pricing set a floor/ceiling from the product's own historical price distribution (e.g. never price below P10 or above P90 of trailing selling prices) so an automated pricing engine can't drift a price to an implausible extreme even if its underlying model misfires. */
/* Q25. Push percentile/latest computation into an MV when the same numbers are read repeatedly by dashboards/reports and the underlying data doesn't need second-by-second freshness (refresh hourly/daily is enough); compute live when the audience is small/ad-hoc, the underlying table is small, or true real-time freshness is required and a stale MV would be actively wrong. */

/* ============================================================
   SECTION B: MULTI-METRIC DISTRIBUTION ENGINES (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT r.region_name,
       COUNT(*) AS order_count,
       ROUND(AVG(o.net_total), 2) AS mean_net_total,
       PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY o.net_total) AS p25,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS p50,
       PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY o.net_total) AS p75,
       PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY o.net_total) AS p90,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95,
       PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY o.net_total) AS p99,
       PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY o.net_total) - PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY o.net_total) AS iqr,
       ROUND((AVG(o.net_total) - PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total))::numeric, 2) AS skew_mean_minus_median
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q27. */
WITH region_bounds AS (
    SELECT r.region_id, r.region_name,
           PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY o.net_total) AS p5,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS p50,
           PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95,
           PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY o.net_total) AS p25,
           PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY o.net_total) AS p75
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_id, r.region_name
)
SELECT rb.region_name,
       ROUND(AVG(o.net_total) FILTER (WHERE o.net_total BETWEEN rb.p5 AND rb.p95), 2) AS trimmed_mean,
       rb.p50 AS median_val,
       rb.p75 - rb.p25 AS spread_iqr,
       COUNT(*) FILTER (WHERE o.net_total < rb.p25 - 1.5 * (rb.p75 - rb.p25)
                            OR o.net_total > rb.p75 + 1.5 * (rb.p75 - rb.p25)) AS outlier_count
FROM region_bounds rb
JOIN stores.stores s ON s.region_id = rb.region_id
JOIN sales.orders o ON o.store_id = s.store_id
GROUP BY rb.region_name, rb.p50, rb.p75, rb.p25
ORDER BY rb.region_name;
/* Q28. */
WITH deliv AS (
    SELECT w.warehouse_id, w.name AS warehouse_name, sh.delivered_date - o.order_date AS delivery_days,
           date_trunc('month', o.order_date)::date AS month
    FROM sales.orders o
    JOIN sales.shipments sh ON sh.order_id = o.order_id
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    JOIN supply_chain.warehouses w ON w.region = r.region_name
    WHERE o.order_status = 'Delivered' AND sh.delivered_date IS NOT NULL
),
monthly AS (
    SELECT warehouse_id, warehouse_name, month,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY delivery_days) AS median_days,
           PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY delivery_days) AS p90_days,
           PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY delivery_days) AS p95_days,
           MAX(delivery_days) AS max_days,
           ROUND(100.0 * COUNT(*) FILTER (WHERE delivery_days > 7) / COUNT(*), 2) AS sla_breach_pct
    FROM deliv
    GROUP BY warehouse_id, warehouse_name, month
)
SELECT warehouse_id, warehouse_name, month, median_days, p90_days, p95_days, max_days, sla_breach_pct,
       median_days - LAG(median_days) OVER (PARTITION BY warehouse_id ORDER BY month) AS mom_median_change
FROM monthly
ORDER BY warehouse_id, month;
/* Q29. */
WITH cust_ltv AS (
    SELECT c.customer_id, c.tier, SUM(o.net_total) AS lifetime_value
    FROM customers.customers c
    JOIN sales.orders o ON o.cust_id = c.customer_id
    GROUP BY c.customer_id, c.tier
)
SELECT tier,
       PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY lifetime_value) AS p25,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY lifetime_value) AS p50,
       PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY lifetime_value) AS p75,
       PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY lifetime_value) AS p90,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY lifetime_value) AS p95,
       PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY lifetime_value) AS p99,
       ROUND((PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY lifetime_value)
              / NULLIF(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY lifetime_value), 0))::numeric, 2) AS p95_p50_concentration_ratio
FROM cust_ltv
GROUP BY tier
ORDER BY tier;
/* Q30. */
WITH margins AS (
    SELECT c.category_name, p.product_id, 100.0 * (oi.unit_price - p.cost_price) / NULLIF(oi.unit_price, 0) AS margin_pct
    FROM sales.order_items oi
    JOIN products.products p ON p.product_id = oi.prod_id
    JOIN core.dim_brand b ON b.brand_id = p.brand_id
    JOIN core.dim_category c ON c.category_id = b.category_id
)
SELECT category_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY margin_pct) AS median_margin_pct,
       PERCENTILE_CONT(0.1) WITHIN GROUP (ORDER BY margin_pct) AS p10_margin_pct,
       ROUND(100.0 * COUNT(*) FILTER (WHERE margin_pct < 20) / COUNT(*), 2) AS pct_below_20pct_margin_target
FROM margins
GROUP BY category_name
ORDER BY category_name;
/* Q31. */
WITH ticket_hours AS (
    SELECT priority, ticket_id, created_date, EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600.0 AS resolution_hours
    FROM support.tickets
    WHERE resolved_date IS NOT NULL
),
sla AS (
    SELECT priority,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY resolution_hours) AS median_hours,
           PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY resolution_hours) AS p95_hours,
           PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY resolution_hours) AS p99_hours,
           ROUND(100.0 * COUNT(*) FILTER (WHERE resolution_hours > 48) / COUNT(*), 2) AS breach_pct
    FROM ticket_hours
    GROUP BY priority
),
oldest_open AS (
    SELECT DISTINCT ON (priority) priority, ticket_id AS oldest_open_ticket_id, created_date AS oldest_open_created
    FROM support.tickets
    WHERE status IN ('Open', 'In Progress')
    ORDER BY priority, created_date ASC
)
SELECT sla.priority, sla.median_hours, sla.p95_hours, sla.p99_hours, sla.breach_pct,
       oo.oldest_open_ticket_id, oo.oldest_open_created
FROM sla
LEFT JOIN oldest_open oo ON oo.priority = sla.priority
ORDER BY sla.priority;
/* Q32. */
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
),
peak AS (
    SELECT DISTINCT ON (agent_id) agent_id, hr AS peak_hour, call_count
    FROM (
        SELECT agent_id, EXTRACT(HOUR FROM call_start_time) AS hr, COUNT(*) AS call_count
        FROM call_center.calls
        GROUP BY agent_id, hr
    ) h
    ORDER BY agent_id, call_count DESC
)
SELECT ap.agent_id, ap.median_duration, ap.p95_duration, lc.latest_call_time, pk.peak_hour,
       RANK() OVER (ORDER BY ap.median_duration DESC) AS recency_rank
FROM agent_pct ap
JOIN latest_call lc ON lc.agent_id = ap.agent_id
JOIN peak pk ON pk.agent_id = ap.agent_id
ORDER BY recency_rank;
/* Q33. */
WITH price_band AS (
    SELECT prod_id,
           PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY unit_price) AS p25_price,
           PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY unit_price) AS p75_price
    FROM sales.order_items
    GROUP BY prod_id
),
latest_price AS (
    SELECT DISTINCT ON (p.product_id) p.product_id, oi.unit_price AS latest_price, o.order_date AS latest_price_date
    FROM sales.order_items oi
    JOIN sales.orders o ON o.order_id = oi.order_id
    JOIN products.products p ON p.product_id = oi.prod_id
    ORDER BY p.product_id, o.order_date DESC
)
SELECT lp.product_id, pb.p25_price, pb.p75_price, lp.latest_price, lp.latest_price_date,
       ROUND((100.0 * (lp.latest_price - ((pb.p25_price + pb.p75_price) / 2))
              / NULLIF((pb.p25_price + pb.p75_price) / 2, 0))::numeric, 2) AS drift_from_corridor_mid_pct
FROM latest_price lp
JOIN price_band pb ON pb.prod_id = lp.product_id
ORDER BY lp.product_id;
/* Q34. */
WITH region_orders AS (
    SELECT r.region_name, o.order_id, o.net_total,
           NTILE(10) OVER (PARTITION BY r.region_name ORDER BY o.net_total) AS decile
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
)
SELECT region_name,
       ROUND(100.0 * SUM(net_total) FILTER (WHERE decile = 10) / SUM(net_total), 2) AS top_decile_revenue_share_pct,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total) AS median_order_value
FROM region_orders
GROUP BY region_name
ORDER BY region_name;
/* Q35. */
WITH basket AS (
    SELECT o.order_id, s.store_id, r.region_name, COUNT(oi.order_item_id) AS item_count
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    JOIN sales.order_items oi ON oi.order_id = o.order_id
    GROUP BY o.order_id, s.store_id, r.region_name
),
region_benchmark AS (
    SELECT region_name, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY item_count) AS region_median_basket
    FROM basket
    GROUP BY region_name
)
SELECT b.store_id, b.region_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY b.item_count) AS store_median_basket,
       PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY b.item_count) AS store_p90_basket,
       rb.region_median_basket,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY b.item_count) - rb.region_median_basket)::numeric, 2) AS gap_to_region
FROM basket b
JOIN region_benchmark rb ON rb.region_name = b.region_name
GROUP BY b.store_id, b.region_name, rb.region_median_basket
ORDER BY b.store_id;
/* Q36. */
WITH cohort AS (
    SELECT EXTRACT(YEAR FROM c.registration_date)::int AS cohort_year,
           EXTRACT(YEAR FROM o.order_date)::int AS order_year,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov
    FROM sales.orders o
    JOIN customers.customers c ON c.customer_id = o.cust_id
    GROUP BY cohort_year, order_year
)
SELECT cohort_year, order_year, median_aov,
       (order_year = cohort_year) AS is_signup_year,
       median_aov - LAG(median_aov) OVER (PARTITION BY cohort_year ORDER BY order_year) AS yoy_change_within_cohort
FROM cohort
ORDER BY cohort_year, order_year;
/* Q37. */
WITH region_iqr AS (
    SELECT r.region_id, r.region_name,
           PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY o.net_total) AS p25,
           PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY o.net_total) AS p75,
           PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY o.net_total) AS p99
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_id, r.region_name
)
SELECT ri.region_name, o.order_id, o.net_total, o.order_date, c.customer_id, c.first_name, c.last_name,
       ri.p25 - 1.5 * (ri.p75 - ri.p25) AS lower_fence, ri.p75 + 1.5 * (ri.p75 - ri.p25) AS upper_fence, ri.p99
FROM region_iqr ri
JOIN stores.stores s ON s.region_id = ri.region_id
JOIN sales.orders o ON o.store_id = s.store_id
JOIN customers.customers c ON c.customer_id = o.cust_id
WHERE o.net_total < ri.p25 - 1.5 * (ri.p75 - ri.p25) OR o.net_total > ri.p75 + 1.5 * (ri.p75 - ri.p25)
ORDER BY ri.region_name, o.net_total DESC;
/* Q38. */
WITH quarterly AS (
    SELECT r.region_name, EXTRACT(YEAR FROM o.order_date) AS yr, EXTRACT(QUARTER FROM o.order_date) AS quarter,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_name, yr, quarter
)
SELECT region_name, yr, quarter, median_aov,
       median_aov - LAG(median_aov) OVER (PARTITION BY region_name ORDER BY yr, quarter) AS qoq_change,
       median_aov - LAG(median_aov, 4) OVER (PARTITION BY region_name ORDER BY yr, quarter) AS yoy_change
FROM quarterly
ORDER BY region_name, yr, quarter;
/* Q39. */
WITH dept_salary AS (
    SELECT d.dept_name,
           PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY ps.net_salary) AS p25,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ps.net_salary) AS p50,
           PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY ps.net_salary) AS p75
    FROM payroll.pay_slips ps
    JOIN stores.employees e ON e.employee_id = ps.employee_id
    JOIN core.dim_department d ON d.dept_id = e.dept_id
    GROUP BY d.dept_name
),
org_median AS (
    SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ps.net_salary) AS org_median
    FROM payroll.pay_slips ps
)
SELECT ds.dept_name, ds.p25, ds.p50, ds.p75, ds.p75 - ds.p25 AS iqr,
       ROUND((ds.p50 - om.org_median)::numeric, 2) AS gap_to_org_median
FROM dept_salary ds, org_median om
ORDER BY ds.dept_name;
/* Q40. */
WITH dwell AS (
    SELECT device_type, session_id,
           LEAD(view_timestamp) OVER (PARTITION BY session_id ORDER BY view_timestamp) - view_timestamp AS dwell_interval,
           view_timestamp
    FROM web_events.page_views
)
SELECT device_type,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM dwell_interval)) AS p50_dwell_seconds,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM dwell_interval)) AS p95_dwell_seconds,
       PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM dwell_interval)) AS p99_dwell_seconds,
       (SELECT hr FROM (SELECT EXTRACT(HOUR FROM view_timestamp) AS hr, COUNT(*) AS c FROM web_events.page_views p2 WHERE p2.device_type = d.device_type GROUP BY hr ORDER BY c DESC LIMIT 1) peak) AS peak_hour
FROM dwell d
WHERE dwell_interval IS NOT NULL
GROUP BY device_type
ORDER BY device_type;
/* Q41. */
WITH snap_diffs AS (
    SELECT warehouse_id, product_id, snapshot_date, quantity_on_hand,
           quantity_on_hand - LAG(quantity_on_hand) OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date) AS qty_change
    FROM supply_chain.inventory_snapshots
),
depletion AS (
    SELECT warehouse_id, product_id, AVG(-qty_change) AS avg_daily_depletion
    FROM snap_diffs
    WHERE qty_change < 0
    GROUP BY warehouse_id, product_id
),
latest_snap AS (
    SELECT DISTINCT ON (warehouse_id, product_id) warehouse_id, product_id, snapshot_date, quantity_on_hand
    FROM supply_chain.inventory_snapshots
    ORDER BY warehouse_id, product_id, snapshot_date DESC
)
SELECT w.warehouse_id, w.name AS warehouse_name,
       ROUND(100.0 * COUNT(*) FILTER (WHERE ls.quantity_on_hand = 0) / COUNT(*), 2) AS stockout_pct,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ls.quantity_on_hand / NULLIF(d.avg_daily_depletion, 0)) AS median_days_of_cover
FROM latest_snap ls
JOIN supply_chain.warehouses w ON w.warehouse_id = ls.warehouse_id
LEFT JOIN depletion d ON d.warehouse_id = ls.warehouse_id AND d.product_id = ls.product_id
GROUP BY w.warehouse_id, w.name
ORDER BY w.warehouse_id;
/* Q42. */
WITH cat_returns AS (
    SELECT c.category_name, ret.return_id, ret.refund_amount, ret.return_date
    FROM sales.returns ret
    JOIN products.products p ON p.product_id = ret.prod_id
    JOIN core.dim_brand b ON b.brand_id = p.brand_id
    JOIN core.dim_category c ON c.category_id = b.category_id
),
cat_items AS (
    SELECT c.category_name, COUNT(*) AS item_count
    FROM sales.order_items oi
    JOIN products.products p ON p.product_id = oi.prod_id
    JOIN core.dim_brand b ON b.brand_id = p.brand_id
    JOIN core.dim_category c ON c.category_id = b.category_id
    GROUP BY c.category_name
),
cat_stats AS (
    SELECT category_name,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY refund_amount) AS median_refund,
           PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY refund_amount) AS p95_refund,
           COUNT(*) AS return_count,
           MAX(refund_amount) AS latest_spike_amount
    FROM cat_returns
    GROUP BY category_name
)
SELECT cs.category_name, cs.median_refund, cs.p95_refund,
       ROUND(100.0 * cs.return_count / ci.item_count, 2) AS refund_rate_pct,
       cs.latest_spike_amount
FROM cat_stats cs
JOIN cat_items ci ON ci.category_name = cs.category_name
ORDER BY cs.category_name;
/* Q43. */
SELECT r.region_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sh.shipped_date - o.order_date) AS median_order_to_ship_days,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY sh.shipped_date - o.order_date) AS p95_order_to_ship_days,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sh.delivered_date - sh.shipped_date) AS median_ship_to_deliver_days,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY sh.delivered_date - sh.shipped_date) AS p95_ship_to_deliver_days
FROM sales.orders o
JOIN sales.shipments sh ON sh.order_id = o.order_id
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
WHERE sh.shipped_date IS NOT NULL AND sh.delivered_date IS NOT NULL
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q44. */
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
SELECT PERCENTILE_CONT(0.1) WITHIN GROUP (ORDER BY median_gap_days) AS p10_of_cadences,
       PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY median_gap_days) AS p25_of_cadences,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY median_gap_days) AS p50_of_cadences,
       PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY median_gap_days) AS p75_of_cadences,
       PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY median_gap_days) AS p90_of_cadences,
       COUNT(*) AS repeat_customer_count
FROM cust_median_gap;
/* Q45. */
WITH region_quarter AS (
    SELECT r.region_id, r.region_name, EXTRACT(YEAR FROM o.order_date) AS yr, EXTRACT(QUARTER FROM o.order_date) AS quarter,
           sh.delivered_date - o.order_date AS delivery_days
    FROM sales.orders o
    JOIN sales.shipments sh ON sh.order_id = o.order_id
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    WHERE o.order_status = 'Delivered' AND sh.delivered_date IS NOT NULL
),
quarter_p90 AS (
    SELECT region_id, region_name, yr, quarter,
           PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY delivery_days) AS p90_delivery_days
    FROM region_quarter
    GROUP BY region_id, region_name, yr, quarter
),
targets AS (
    SELECT region_id, region_name, yr, quarter,
           LAG(p90_delivery_days) OVER (PARTITION BY region_id ORDER BY yr, quarter) AS target_p90
    FROM quarter_p90
)
SELECT rq.region_name, rq.yr, rq.quarter, t.target_p90,
       ROUND(100.0 * COUNT(*) FILTER (WHERE rq.delivery_days <= t.target_p90) / COUNT(*), 2) AS attainment_pct
FROM region_quarter rq
JOIN targets t ON t.region_id = rq.region_id AND t.yr = rq.yr AND t.quarter = rq.quarter
WHERE t.target_p90 IS NOT NULL
GROUP BY rq.region_name, rq.yr, rq.quarter, t.target_p90
ORDER BY rq.region_name, rq.yr, rq.quarter;
/* Q46. */
WITH priced AS (
    SELECT c.category_name, oi.unit_price,
           NTILE(5) OVER (PARTITION BY c.category_name ORDER BY oi.unit_price) AS price_band,
           oi.quantity
    FROM sales.order_items oi
    JOIN products.products p ON p.product_id = oi.prod_id
    JOIN core.dim_brand b ON b.brand_id = p.brand_id
    JOIN core.dim_category c ON c.category_id = b.category_id
)
SELECT category_name, price_band,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY unit_price) AS band_median_price,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY quantity) AS median_units_at_band
FROM priced
GROUP BY category_name, price_band
ORDER BY category_name, price_band;
/* Q47. */
WITH cust_median AS (
    SELECT cust_id, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total) AS cust_median_order
    FROM sales.orders
    GROUP BY cust_id
),
region_of_median AS (
    SELECT DISTINCT ON (o.cust_id) o.cust_id, r.region_name
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    ORDER BY o.cust_id, o.order_date DESC
),
region_median_of_medians AS (
    SELECT rm.region_name, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY cm.cust_median_order) AS median_of_customer_medians
    FROM cust_median cm
    JOIN region_of_median rm ON rm.cust_id = cm.cust_id
    GROUP BY rm.region_name
),
true_region_median AS (
    SELECT r.region_name, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS true_global_median
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_name
)
SELECT rmm.region_name, rmm.median_of_customer_medians, trm.true_global_median,
       ROUND((rmm.median_of_customer_medians - trm.true_global_median)::numeric, 2) AS reconciliation_gap
FROM region_median_of_medians rmm
JOIN true_region_median trm ON trm.region_name = rmm.region_name
ORDER BY rmm.region_name;
/* Q48. */
WITH weekly AS (
    SELECT r.region_name, date_trunc('week', o.order_date)::date AS week_start,
           PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_aov
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_name, week_start
),
shifted AS (
    SELECT region_name, week_start, p95_aov,
           LAG(p95_aov) OVER (PARTITION BY region_name ORDER BY week_start) AS prev_p95_aov
    FROM weekly
)
SELECT region_name, week_start, p95_aov, prev_p95_aov,
       ROUND((100.0 * (p95_aov - prev_p95_aov) / NULLIF(prev_p95_aov, 0))::numeric, 2) AS pct_change
FROM shifted
WHERE prev_p95_aov IS NOT NULL
  AND ABS(100.0 * (p95_aov - prev_p95_aov) / NULLIF(prev_p95_aov, 0)) > 20
ORDER BY region_name, week_start;
/* Q49. */
WITH region_bounds AS (
    SELECT r.region_id, r.region_name,
           PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY o.net_total) AS p1,
           PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY o.net_total) AS p99
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_id, r.region_name
)
SELECT rb.region_name,
       ROUND(SUM(o.net_total)::numeric, 2) AS raw_total,
       ROUND(SUM(LEAST(GREATEST(o.net_total, rb.p1), rb.p99))::numeric, 2) AS winsorized_total,
       ROUND((SUM(o.net_total) - SUM(LEAST(GREATEST(o.net_total, rb.p1), rb.p99)))::numeric, 2) AS outlier_contribution
FROM region_bounds rb
JOIN stores.stores s ON s.region_id = rb.region_id
JOIN sales.orders o ON o.store_id = s.store_id
GROUP BY rb.region_name
ORDER BY rb.region_name;
/* Q50. */
WITH matrix AS (
    SELECT r.region_name, EXTRACT(YEAR FROM o.order_date) AS yr, EXTRACT(QUARTER FROM o.order_date) AS quarter,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_name, yr, quarter
),
row_stats AS (
    SELECT region_name, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY median_aov) AS row_median
    FROM matrix
    GROUP BY region_name
),
col_stats AS (
    SELECT yr, quarter, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY median_aov) AS col_median
    FROM matrix
    GROUP BY yr, quarter
),
grand AS (
    SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY median_aov) AS grand_median FROM matrix
)
SELECT m.region_name, m.yr, m.quarter, m.median_aov, rs.row_median, cs.col_median, g.grand_median
FROM matrix m
JOIN row_stats rs ON rs.region_name = m.region_name
JOIN col_stats cs ON cs.yr = m.yr AND cs.quarter = m.quarter
CROSS JOIN grand g
ORDER BY m.region_name, m.yr, m.quarter;

/* ============================================================
   SECTION C: LATEST-STATE / SCD PIPELINES (25)
   ------------------------------------------------------------ */
/* Q51. */
WITH latest_order AS (
    SELECT DISTINCT ON (cust_id) cust_id, order_id AS latest_order_id, order_date AS latest_order_date, net_total AS latest_order_total
    FROM sales.orders ORDER BY cust_id, order_date DESC
),
latest_review AS (
    SELECT DISTINCT ON (customer_id) customer_id, review_id AS latest_review_id, rating AS latest_rating, review_date AS latest_review_date
    FROM customers.reviews ORDER BY customer_id, review_date DESC
),
latest_ticket AS (
    SELECT DISTINCT ON (customer_id) customer_id, ticket_id AS latest_ticket_id, status AS latest_ticket_status, created_date AS latest_ticket_date
    FROM support.tickets ORDER BY customer_id, created_date DESC
),
latest_payment AS (
    SELECT DISTINCT ON (cust_id) cust_id, payment_id AS latest_payment_id, status AS latest_payment_status
    FROM finance.payments ORDER BY cust_id, payment_id DESC
)
SELECT c.customer_id, c.first_name, c.last_name, c.tier,
       lo.latest_order_id, lo.latest_order_date, lo.latest_order_total,
       lr.latest_review_id, lr.latest_rating, lr.latest_review_date,
       lt.latest_ticket_id, lt.latest_ticket_status, lt.latest_ticket_date,
       lp.latest_payment_id, lp.latest_payment_status
FROM customers.customers c
LEFT JOIN latest_order lo ON lo.cust_id = c.customer_id
LEFT JOIN latest_review lr ON lr.customer_id = c.customer_id
LEFT JOIN latest_ticket lt ON lt.customer_id = c.customer_id
LEFT JOIN latest_payment lp ON lp.cust_id = c.customer_id
ORDER BY c.customer_id;
/* Q52. */
SELECT DISTINCT ON (customer_id) customer_id, tier, tier_updated_at
FROM customers.customers
ORDER BY customer_id, tier_updated_at DESC;
/* Q53. */
WITH latest_snap AS (
    SELECT DISTINCT ON (warehouse_id, product_id) warehouse_id, product_id, snapshot_date, quantity_on_hand
    FROM supply_chain.inventory_snapshots
    ORDER BY warehouse_id, product_id, snapshot_date DESC
),
reorder_ref AS (
    SELECT product_id, ROUND(AVG(reorder_level)) AS reorder_level
    FROM products.inventory
    GROUP BY product_id
),
value_ref AS (
    SELECT product_id, cost_price FROM products.products
)
SELECT ls.warehouse_id, ls.product_id, ls.snapshot_date, ls.quantity_on_hand, rr.reorder_level,
       (ls.quantity_on_hand < rr.reorder_level) AS needs_reorder,
       ROUND(ls.quantity_on_hand * vr.cost_price, 2) AS inventory_value
FROM latest_snap ls
LEFT JOIN reorder_ref rr ON rr.product_id = ls.product_id
LEFT JOIN value_ref vr ON vr.product_id = ls.product_id
ORDER BY ls.warehouse_id, ls.product_id;
/* Q54. */
WITH price_band AS (
    SELECT prod_id,
           PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY unit_price) AS p25_price,
           PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY unit_price) AS p75_price
    FROM sales.order_items
    GROUP BY prod_id
),
latest_price AS (
    SELECT DISTINCT ON (p.product_id) p.product_id, oi.unit_price AS latest_price, o.order_date AS price_date
    FROM sales.order_items oi
    JOIN sales.orders o ON o.order_id = oi.order_id
    JOIN products.products p ON p.product_id = oi.prod_id
    ORDER BY p.product_id, o.order_date DESC
)
SELECT lp.product_id, pb.p25_price, pb.p75_price, lp.latest_price,
       CURRENT_DATE - lp.price_date AS days_since_change
FROM latest_price lp
JOIN price_band pb ON pb.prod_id = lp.product_id
ORDER BY lp.product_id;
/* Q55. */
WITH latest_order AS (
    SELECT DISTINCT ON (cust_id) cust_id, order_status AS latest_status
    FROM sales.orders ORDER BY cust_id, order_date DESC
),
cust_median AS (
    SELECT cust_id, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total) AS lifetime_median_order
    FROM sales.orders GROUP BY cust_id
),
recency AS (
    SELECT cust_id, MAX(order_date) AS last_order_date,
           NTILE(10) OVER (ORDER BY MAX(order_date)) AS recency_decile
    FROM sales.orders GROUP BY cust_id
)
SELECT lo.cust_id, lo.latest_status, cm.lifetime_median_order, r.last_order_date, r.recency_decile
FROM latest_order lo
JOIN cust_median cm ON cm.cust_id = lo.cust_id
JOIN recency r ON r.cust_id = lo.cust_id
WHERE lo.latest_status IN ('Returned', 'Cancelled')
ORDER BY lo.cust_id;
/* Q56. */
WITH ranked AS (
    SELECT employee_id, amount, payment_date,
           ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY payment_date DESC) AS rn
    FROM hr.salary_history
),
latest_current AS (
    SELECT cur.employee_id, cur.amount AS latest_amount, prev.amount AS previous_amount,
           ROUND((100.0 * (cur.amount - prev.amount) / NULLIF(prev.amount, 0))::numeric, 2) AS pct_change
    FROM ranked cur
    LEFT JOIN ranked prev ON prev.employee_id = cur.employee_id AND prev.rn = 2
    WHERE cur.rn = 1
)
SELECT lc.employee_id, d.dept_name, lc.latest_amount, lc.previous_amount, lc.pct_change,
       ROUND((100.0 * PERCENT_RANK() OVER (PARTITION BY d.dept_name ORDER BY lc.latest_amount))::numeric, 2) AS pct_rank_within_dept
FROM latest_current lc
JOIN stores.employees e ON e.employee_id = lc.employee_id
JOIN core.dim_department d ON d.dept_id = e.dept_id
ORDER BY d.dept_name, pct_rank_within_dept DESC;
/* Q57. */
WITH cust_orders AS (
    SELECT cust_id, order_id, order_date, net_total,
           ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date) AS rn,
           COUNT(*) OVER (PARTITION BY cust_id) AS total_orders
    FROM sales.orders
),
first_o AS (SELECT cust_id, order_date AS first_date, net_total AS first_value FROM cust_orders WHERE rn = 1),
last_o AS (SELECT cust_id, order_date AS last_date, net_total AS last_value FROM cust_orders WHERE rn = total_orders),
freq AS (
    SELECT cust_id, COUNT(*) AS order_count,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY gap_days) AS median_gap
    FROM (
        SELECT cust_id, order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date) AS gap_days
        FROM sales.orders
    ) g
    WHERE gap_days IS NOT NULL
    GROUP BY cust_id
)
SELECT f.cust_id, f.first_date, l.last_date, l.last_date - f.first_date AS span_days,
       l.last_value - f.first_value AS value_growth,
       fr.order_count, fr.median_gap AS median_inter_order_gap_days
FROM first_o f
JOIN last_o l ON l.cust_id = f.cust_id
LEFT JOIN freq fr ON fr.cust_id = f.cust_id
ORDER BY f.cust_id;
/* Q58. */
WITH latest_order AS (
    SELECT DISTINCT ON (r.region_name) r.region_name, o.order_id, o.order_date, o.net_total, o.cust_id, s.store_name
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    ORDER BY r.region_name, o.order_date DESC
),
latest_payment AS (
    SELECT DISTINCT ON (order_id) order_id, status FROM finance.payments ORDER BY order_id, payment_id DESC
)
SELECT lo.region_name, lo.order_id, lo.order_date, lo.net_total, lo.store_name,
       c.customer_id, c.first_name, c.last_name,
       (SELECT COUNT(*) FROM sales.order_items oi WHERE oi.order_id = lo.order_id) AS item_count,
       lp.status AS latest_payment_status
FROM latest_order lo
JOIN customers.customers c ON c.customer_id = lo.cust_id
LEFT JOIN latest_payment lp ON lp.order_id = lo.order_id
ORDER BY lo.region_name;
/* Q59. */
WITH events AS (
    SELECT cust_id AS customer_id, order_date::timestamp AS activity_time, 'order' AS activity_type FROM sales.orders
    UNION ALL
    SELECT customer_id, review_date::timestamp, 'review' FROM customers.reviews
    UNION ALL
    SELECT customer_id, created_date, 'ticket' FROM support.tickets
    UNION ALL
    SELECT customer_id, call_start_time, 'call' FROM call_center.calls
)
SELECT DISTINCT ON (customer_id) customer_id, activity_time AS latest_activity_time, activity_type AS latest_activity_type
FROM events
ORDER BY customer_id, activity_time DESC;
/* Q60. */
WITH latest_store_order AS (
    SELECT DISTINCT ON (store_id) store_id, order_date AS latest_order_date
    FROM sales.orders
    ORDER BY store_id, order_date DESC
),
latest_agent_call AS (
    SELECT DISTINCT ON (agent_id) agent_id, call_start_time AS latest_call_time
    FROM call_center.calls
    WHERE agent_id IS NOT NULL
    ORDER BY agent_id, call_start_time DESC
)
SELECT 'store' AS entity_type, store_id::text AS entity_id, CURRENT_DATE - latest_order_date::date AS days_stale
FROM latest_store_order
UNION ALL
SELECT 'agent', agent_id::text, CURRENT_DATE - latest_call_time::date
FROM latest_agent_call
ORDER BY days_stale DESC;
/* Q61. */
WITH latest_pay AS (
    SELECT DISTINCT ON (order_id) order_id, payment_id, status
    FROM finance.payments
    ORDER BY order_id, payment_id DESC
)
SELECT lp.order_id, lp.status AS latest_payment_status, o.order_status, o.net_total
FROM latest_pay lp
JOIN sales.orders o ON o.order_id = lp.order_id
WHERE lp.status = 'Failed'
ORDER BY lp.order_id;
/* Q62. */
WITH latest_snap AS (
    SELECT DISTINCT ON (warehouse_id, product_id) warehouse_id, product_id, snapshot_date, quantity_on_hand
    FROM supply_chain.inventory_snapshots
    ORDER BY warehouse_id, product_id, snapshot_date DESC
)
SELECT ls.warehouse_id, ls.product_id, ls.quantity_on_hand, p.cost_price,
       ROUND(ls.quantity_on_hand * p.cost_price, 2) AS total_value
FROM latest_snap ls
JOIN products.products p ON p.product_id = ls.product_id
ORDER BY total_value DESC;
/* Q63. */
WITH latest_att AS (
    SELECT DISTINCT ON (employee_id) employee_id, attendance_date, check_in, check_out
    FROM hr.attendance
    ORDER BY employee_id, attendance_date DESC
)
SELECT la.employee_id, e.first_name, e.last_name, la.attendance_date, (la.check_in IS NULL) AS is_absent,
       CURRENT_DATE - e.joining_date AS tenure_days
FROM latest_att la
JOIN stores.employees e ON e.employee_id = la.employee_id
WHERE la.check_in IS NULL
ORDER BY la.employee_id;
/* Q64. */
WITH price_events AS (
    SELECT p.product_id, oi.unit_price, o.order_date,
           LAG(oi.unit_price) OVER (PARTITION BY p.product_id ORDER BY o.order_date) AS prev_price
    FROM sales.order_items oi
    JOIN sales.orders o ON o.order_id = oi.order_id
    JOIN products.products p ON p.product_id = oi.prod_id
),
changes AS (
    SELECT product_id, unit_price, order_date
    FROM price_events
    WHERE prev_price IS NULL OR unit_price <> prev_price
),
latest_change AS (
    SELECT DISTINCT ON (product_id) product_id, order_date AS latest_change_date
    FROM changes
    ORDER BY product_id, order_date DESC
)
SELECT c.product_id, c.unit_price, c.order_date,
       ROW_NUMBER() OVER (PARTITION BY c.product_id ORDER BY c.order_date) AS change_seq,
       (c.order_date = lc.latest_change_date) AS is_latest_price
FROM changes c
JOIN latest_change lc ON lc.product_id = c.product_id
ORDER BY c.product_id, c.order_date;
/* Q65. */
WITH order_pct AS (
    SELECT cust_id, order_id, order_date, net_total,
           PERCENT_RANK() OVER (PARTITION BY cust_id ORDER BY net_total) AS value_pct_rank_within_cust
    FROM sales.orders
)
SELECT DISTINCT ON (cust_id) cust_id, order_id, order_date, net_total,
       ROUND((value_pct_rank_within_cust * 100)::numeric, 2) AS pct_rank_vs_own_history
FROM order_pct
ORDER BY cust_id, order_date DESC;
/* Q66. */
WITH snap_diffs AS (
    SELECT warehouse_id, product_id, snapshot_date, quantity_on_hand,
           quantity_on_hand - LAG(quantity_on_hand) OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date) AS delta_qty,
           LAG(snapshot_date) OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date) AS prev_snapshot_date
    FROM supply_chain.inventory_snapshots
)
SELECT DISTINCT ON (warehouse_id, product_id) warehouse_id, product_id, snapshot_date, quantity_on_hand,
       prev_snapshot_date, delta_qty
FROM snap_diffs
ORDER BY warehouse_id, product_id, snapshot_date DESC;
/* Q67. */
WITH latest_spend AS (
    SELECT DISTINCT ON (platform) platform, campaign_id, spend_date, amount
    FROM marketing.ads_spend
    ORDER BY platform, spend_date DESC
),
spend_totals AS (
    SELECT platform, SUM(amount) AS total_spend
    FROM marketing.ads_spend
    GROUP BY platform
),
campaign_platform AS (
    SELECT DISTINCT platform, campaign_id FROM marketing.ads_spend
),
budget_totals AS (
    SELECT cp.platform, SUM(c.budget) AS total_budget
    FROM campaign_platform cp
    JOIN marketing.campaigns c ON c.campaign_id = cp.campaign_id
    GROUP BY cp.platform
)
SELECT ls.platform, ls.spend_date AS latest_spend_date, ls.amount AS latest_spend_amount,
       st.total_spend, bt.total_budget,
       ROUND((100.0 * st.total_spend / NULLIF(bt.total_budget, 0))::numeric, 2) AS pacing_pct
FROM latest_spend ls
JOIN spend_totals st ON st.platform = ls.platform
JOIN budget_totals bt ON bt.platform = ls.platform
ORDER BY ls.platform;
/* Q68. */
SELECT DISTINCT ON (agent_id) agent_id, ticket_id, status, created_date, resolved_date,
       CASE WHEN status IN ('Open', 'In Progress') THEN CURRENT_DATE - created_date::date END AS open_aging_days,
       (status IN ('Open', 'In Progress') AND CURRENT_DATE - created_date::date > 2) AS sla_breach_flag
FROM support.tickets
WHERE agent_id IS NOT NULL
ORDER BY agent_id, created_date DESC;
/* Q69. */
WITH web_last AS (
    SELECT customer_id, MAX(view_timestamp) AS last_web_ts
    FROM web_events.page_views
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
),
order_last AS (
    SELECT cust_id AS customer_id, MAX(order_date)::timestamp AS last_order_ts
    FROM sales.orders
    GROUP BY cust_id
)
SELECT c.customer_id,
       GREATEST(COALESCE(w.last_web_ts, '-infinity'::timestamp), COALESCE(o.last_order_ts, '-infinity'::timestamp)) AS last_seen
FROM customers.customers c
LEFT JOIN web_last w ON w.customer_id = c.customer_id
LEFT JOIN order_last o ON o.customer_id = c.customer_id
ORDER BY last_seen DESC NULLS LAST;
/* Q70. */
SELECT DISTINCT ON (rd.customer_id) rd.customer_id, rd.redemption_id, rd.points_redeemed, rd.redemption_date,
       m.points_balance AS points_remaining, t.tier_name, t.min_points,
       (m.points_balance >= t.min_points) AS meets_tier_min
FROM loyalty.redemptions rd
JOIN loyalty.members m ON m.customer_id = rd.customer_id
JOIN loyalty.tiers t ON t.tier_id = m.tier_id
ORDER BY rd.customer_id, rd.redemption_date DESC;
/* Q71. */
SELECT DISTINCT ON (customer_id) customer_id, address_id, address_line, city, state, pincode, is_default
FROM customers.addresses
ORDER BY customer_id, is_default DESC NULLS LAST, address_id DESC;
/* Q72. */
WITH latest_order AS (
    SELECT DISTINCT ON (store_id) store_id, order_id, order_date, net_total
    FROM sales.orders
    ORDER BY store_id, order_date DESC
)
SELECT lo.store_id, lo.order_id, lo.order_date, lo.net_total,
       (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o2.net_total)
        FROM sales.orders o2
        WHERE o2.store_id = lo.store_id
          AND o2.order_date BETWEEN lo.order_date - INTERVAL '30 days' AND lo.order_date) AS rolling_30d_median
FROM latest_order lo
ORDER BY lo.store_id;
/* Q73. */
WITH latest_order AS (
    SELECT DISTINCT ON (cust_id) cust_id, order_date AS latest_order_date
    FROM sales.orders
    ORDER BY cust_id, order_date DESC
)
SELECT cust_id, latest_order_date, CURRENT_DATE - latest_order_date AS days_since_last_order
FROM latest_order
WHERE CURRENT_DATE - latest_order_date > 180
ORDER BY days_since_last_order DESC;
/* Q74. */
WITH cycle AS (
    SELECT work_order_id, line_id, product_id, start_timestamp, end_timestamp,
           EXTRACT(EPOCH FROM (end_timestamp - start_timestamp)) / 3600.0 AS cycle_hours
    FROM manufacture.work_orders
    WHERE end_timestamp IS NOT NULL
),
line_pct AS (
    SELECT line_id, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY cycle_hours) AS median_cycle_hours,
           PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY cycle_hours) AS p90_cycle_hours
    FROM cycle
    GROUP BY line_id
)
SELECT DISTINCT ON (c.line_id) c.line_id, c.work_order_id, c.start_timestamp, c.end_timestamp, c.cycle_hours,
       lp.median_cycle_hours, lp.p90_cycle_hours
FROM cycle c
JOIN line_pct lp ON lp.line_id = c.line_id
ORDER BY c.line_id, c.start_timestamp DESC;
/* Q75. */
WITH region_stats AS (
    SELECT r.region_name, COUNT(*) AS total_orders, SUM(o.net_total) AS total_revenue,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov,
           MAX(o.order_date) AS latest_order_date
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_name
)
SELECT region_name, total_orders, total_revenue, median_aov, latest_order_date
FROM region_stats
ORDER BY region_name;

/* ============================================================
   SECTION D: PRODUCTION ANALYTICS SYSTEMS (25)
   ------------------------------------------------------------ */
/* Q76. */
WITH latest AS (
    SELECT DISTINCT ON (r.region_name) r.region_name, o.order_date AS latest_order_date
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    ORDER BY r.region_name, o.order_date DESC
),
churn AS (
    SELECT r.region_name, COUNT(DISTINCT c.customer_id) AS churn_risk_count
    FROM customers.customers c
    JOIN sales.orders o ON o.cust_id = c.customer_id
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    WHERE o.order_date < CURRENT_DATE - INTERVAL '180 days'
      AND NOT EXISTS (SELECT 1 FROM sales.orders o2 WHERE o2.cust_id = c.customer_id AND o2.order_date >= CURRENT_DATE - INTERVAL '180 days')
    GROUP BY r.region_name
),
deliv AS (
    SELECT r.region_id, PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY sh.delivered_date - o.order_date) AS p90_target
    FROM sales.orders o
    JOIN sales.shipments sh ON sh.order_id = o.order_id
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    WHERE o.order_status = 'Delivered' AND sh.delivered_date IS NOT NULL
    GROUP BY r.region_id
)
SELECT r.region_name, COUNT(*) AS order_count,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov,
       PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY o.net_total) AS p90_aov,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_aov,
       ROUND((100.0 * COUNT(*) FILTER (WHERE sh.delivered_date - o.order_date <= d.p90_target) / NULLIF(COUNT(sh.shipment_id), 0))::numeric, 2) AS sla_pct,
       MAX(l.latest_order_date) AS latest_order_date,
       COALESCE(MAX(ch.churn_risk_count), 0) AS churn_risk_count,
       RANK() OVER (ORDER BY PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) DESC) AS rnk
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
JOIN latest l ON l.region_name = r.region_name
LEFT JOIN sales.shipments sh ON sh.order_id = o.order_id
LEFT JOIN deliv d ON d.region_id = r.region_id
LEFT JOIN churn ch ON ch.region_name = r.region_name
GROUP BY r.region_name
ORDER BY rnk;
/* Q77. */
WITH deliv AS (
    SELECT w.warehouse_id, w.name AS warehouse_name, sh.delivered_date - o.order_date AS delivery_days
    FROM sales.orders o
    JOIN sales.shipments sh ON sh.order_id = o.order_id
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    JOIN supply_chain.warehouses w ON w.region = r.region_name
    WHERE o.order_status = 'Delivered' AND sh.delivered_date IS NOT NULL
),
latest_snap AS (
    SELECT DISTINCT ON (warehouse_id) warehouse_id, snapshot_date AS freshest_snapshot_date
    FROM supply_chain.inventory_snapshots
    ORDER BY warehouse_id, snapshot_date DESC
)
SELECT d.warehouse_id, d.warehouse_name,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY d.delivery_days) AS p95_delivery_days,
       ROUND((100.0 * COUNT(*) FILTER (WHERE d.delivery_days > 7) / COUNT(*))::numeric, 2) AS breach_pct,
       CURRENT_DATE - ls.freshest_snapshot_date AS snapshot_age_days
FROM deliv d
LEFT JOIN latest_snap ls ON ls.warehouse_id = d.warehouse_id
GROUP BY d.warehouse_id, d.warehouse_name, ls.freshest_snapshot_date
ORDER BY d.warehouse_id;
/* Q78. */
WITH price_band AS (
    SELECT prod_id,
           PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY unit_price) AS p25_price,
           PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY unit_price) AS p75_price
    FROM sales.order_items
    GROUP BY prod_id
),
latest_price AS (
    SELECT DISTINCT ON (p.product_id) p.product_id, oi.unit_price AS latest_price, o.order_date AS price_date
    FROM sales.order_items oi
    JOIN sales.orders o ON o.order_id = oi.order_id
    JOIN products.products p ON p.product_id = oi.prod_id
    ORDER BY p.product_id, o.order_date DESC
)
SELECT lp.product_id, pb.p25_price, pb.p75_price, lp.latest_price, lp.price_date,
       (lp.latest_price < pb.p25_price OR lp.latest_price > pb.p75_price) AS drift_flag
FROM latest_price lp
JOIN price_band pb ON pb.prod_id = lp.product_id
ORDER BY lp.product_id;
/* Q79. */
WITH latest_order AS (
    SELECT DISTINCT ON (cust_id) cust_id, order_status, order_date AS latest_order_date
    FROM sales.orders ORDER BY cust_id, order_date DESC
),
recency AS (
    SELECT cust_id, MAX(order_date) AS last_order_date,
           NTILE(10) OVER (ORDER BY MAX(order_date)) AS recency_decile
    FROM sales.orders GROUP BY cust_id
),
lifetime AS (
    SELECT cust_id, SUM(net_total) AS lifetime_value,
           PERCENT_RANK() OVER (ORDER BY SUM(net_total)) AS lifetime_pct_rank
    FROM sales.orders GROUP BY cust_id
)
SELECT lo.cust_id, r.recency_decile, ROUND((l.lifetime_pct_rank * 100)::numeric, 2) AS lifetime_pct_rank,
       (lo.order_status = 'Returned') AS latest_is_return,
       ROUND(((r.recency_decile::numeric / 10) * 50 + l.lifetime_pct_rank::numeric * 50
              - (CASE WHEN lo.order_status = 'Returned' THEN 10 ELSE 0 END)), 2) AS health_score
FROM latest_order lo
JOIN recency r ON r.cust_id = lo.cust_id
JOIN lifetime l ON l.cust_id = lo.cust_id
ORDER BY health_score DESC;
/* Q80. */
WITH ticket_hours AS (
    SELECT priority, resolved_date, created_date, EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600.0 AS resolution_hours,
           date_trunc('month', created_date)::date AS month
    FROM support.tickets
    WHERE resolved_date IS NOT NULL
),
monthly AS (
    SELECT priority, month, PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY resolution_hours) AS p95_hours
    FROM ticket_hours
    GROUP BY priority, month
),
w_change AS (
    SELECT priority, month, p95_hours,
           LAG(p95_hours) OVER (PARTITION BY priority ORDER BY month) AS prev_p95_hours
    FROM monthly
)
SELECT priority, month, p95_hours, prev_p95_hours,
       ROUND((100.0 * (p95_hours - prev_p95_hours) / NULLIF(prev_p95_hours, 0))::numeric, 2) AS pct_shift
FROM w_change
WHERE prev_p95_hours IS NOT NULL
ORDER BY priority, month;
/* Q81. */
WITH cohort AS (
    SELECT EXTRACT(YEAR FROM c.registration_date)::int AS cohort_year,
           EXTRACT(YEAR FROM o.order_date)::int AS order_year,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov,
           COUNT(DISTINCT c.customer_id) AS active_customers
    FROM sales.orders o
    JOIN customers.customers c ON c.customer_id = o.cust_id
    GROUP BY cohort_year, order_year
),
cohort_size AS (
    SELECT EXTRACT(YEAR FROM registration_date)::int AS cohort_year, COUNT(*) AS cohort_customers
    FROM customers.customers
    GROUP BY cohort_year
),
latest_cohort AS (
    SELECT MAX(cohort_year) AS latest_cohort_year FROM cohort
)
SELECT c.cohort_year, c.order_year, c.median_aov, c.active_customers, cs.cohort_customers,
       ROUND((100.0 * c.active_customers / NULLIF(cs.cohort_customers, 0))::numeric, 2) AS retention_pct,
       (c.cohort_year = (SELECT latest_cohort_year FROM latest_cohort)) AS is_latest_cohort
FROM cohort c
JOIN cohort_size cs ON cs.cohort_year = c.cohort_year
ORDER BY c.cohort_year, c.order_year;
/* Q82. */
WITH region_p99 AS (
    SELECT r.region_id, r.region_name,
           PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY o.net_total) AS p99_net_total
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_id, r.region_name
),
latest_order AS (
    SELECT DISTINCT ON (cust_id) cust_id, order_id, order_date, net_total, store_id
    FROM sales.orders
    ORDER BY cust_id, order_date DESC
)
SELECT rp.region_name, lo.cust_id, lo.order_id, lo.net_total, lo.order_date,
       c.first_name, c.last_name, rp.p99_net_total
FROM latest_order lo
JOIN stores.stores s ON s.store_id = lo.store_id
JOIN region_p99 rp ON rp.region_id = s.region_id
JOIN customers.customers c ON c.customer_id = lo.cust_id
WHERE lo.net_total > rp.p99_net_total
ORDER BY rp.region_name, lo.net_total DESC;
/* Q83. */
WITH snap_diffs AS (
    SELECT warehouse_id, product_id, snapshot_date, quantity_on_hand,
           quantity_on_hand - LAG(quantity_on_hand) OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date) AS qty_change
    FROM supply_chain.inventory_snapshots
),
depletion AS (
    SELECT warehouse_id, product_id, AVG(-qty_change) AS avg_daily_depletion
    FROM snap_diffs
    WHERE qty_change < 0
    GROUP BY warehouse_id, product_id
),
latest_snap AS (
    SELECT DISTINCT ON (warehouse_id, product_id) warehouse_id, product_id, snapshot_date, quantity_on_hand
    FROM supply_chain.inventory_snapshots
    ORDER BY warehouse_id, product_id, snapshot_date DESC
)
SELECT w.warehouse_id, w.name AS warehouse_name,
       ROUND((100.0 * COUNT(*) FILTER (WHERE ls.quantity_on_hand = 0) / COUNT(*))::numeric, 2) AS stockout_pct,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ls.quantity_on_hand / NULLIF(d.avg_daily_depletion, 0)) AS median_days_of_cover,
       COUNT(*) FILTER (WHERE ls.quantity_on_hand / NULLIF(d.avg_daily_depletion, 0) < 3) AS stockout_risk_count
FROM latest_snap ls
JOIN supply_chain.warehouses w ON w.warehouse_id = ls.warehouse_id
LEFT JOIN depletion d ON d.warehouse_id = ls.warehouse_id AND d.product_id = ls.product_id
GROUP BY w.warehouse_id, w.name
ORDER BY w.warehouse_id;
/* Q84. */
WITH dept_salary AS (
    SELECT d.dept_name,
           PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY ps.net_salary) AS p25,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ps.net_salary) AS p50,
           PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY ps.net_salary) AS p75
    FROM payroll.pay_slips ps
    JOIN stores.employees e ON e.employee_id = ps.employee_id
    JOIN core.dim_department d ON d.dept_id = e.dept_id
    GROUP BY d.dept_name
),
org_median AS (
    SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_salary) AS org_median FROM payroll.pay_slips
),
latest_hire AS (
    SELECT DISTINCT ON (d.dept_name) d.dept_name, e.employee_id, e.first_name, e.last_name, e.joining_date
    FROM stores.employees e
    JOIN core.dim_department d ON d.dept_id = e.dept_id
    ORDER BY d.dept_name, e.joining_date DESC
)
SELECT ds.dept_name, ds.p25, ds.p50, ds.p75, ds.p75 - ds.p25 AS iqr,
       ROUND((ds.p50 - om.org_median)::numeric, 2) AS gap_to_median,
       lh.first_name, lh.last_name, lh.joining_date AS latest_hire_date
FROM dept_salary ds
JOIN latest_hire lh ON lh.dept_name = ds.dept_name
CROSS JOIN org_median om
ORDER BY ds.dept_name;
/* Q85. */
WITH ticket_hours AS (
    SELECT priority, ticket_id, created_date, EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600.0 AS resolution_hours
    FROM support.tickets
    WHERE resolved_date IS NOT NULL
),
oldest_open AS (
    SELECT DISTINCT ON (priority) priority, ticket_id AS oldest_open_ticket_id, created_date AS oldest_open_created
    FROM support.tickets
    WHERE status IN ('Open', 'In Progress')
    ORDER BY priority, created_date ASC
)
SELECT th.priority,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY th.resolution_hours) AS median_hours,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY th.resolution_hours) AS p95_hours,
       PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY th.resolution_hours) AS p99_hours,
       ROUND((100.0 * COUNT(*) FILTER (WHERE th.resolution_hours > 48) / COUNT(*))::numeric, 2) AS breach_pct,
       oo.oldest_open_ticket_id, oo.oldest_open_created
FROM ticket_hours th
LEFT JOIN oldest_open oo ON oo.priority = th.priority
GROUP BY th.priority, oo.oldest_open_ticket_id, oo.oldest_open_created
ORDER BY th.priority;
/* Q86. */
WITH region_bounds AS (
    SELECT r.region_id, r.region_name,
           PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY o.net_total) AS p1,
           PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY o.net_total) AS p99,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_val,
           date_trunc('week', o.order_date)::date AS week_start
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_id, r.region_name, week_start
)
SELECT rb.region_name, rb.week_start,
       ROUND((rb.median_val - LAG(rb.median_val) OVER (PARTITION BY rb.region_name ORDER BY rb.week_start))::numeric, 2) AS wow_median_drift,
       rb.p1, rb.p99
FROM region_bounds rb
ORDER BY rb.region_name, rb.week_start;
/* Q87. */
WITH dwell AS (
    SELECT device_type, session_id,
           LEAD(view_timestamp) OVER (PARTITION BY session_id ORDER BY view_timestamp) - view_timestamp AS dwell_interval,
           view_timestamp
    FROM web_events.page_views
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
),
worst_session AS (
    SELECT DISTINCT ON (device_type) device_type, session_id, EXTRACT(EPOCH FROM dwell_interval) AS dwell_seconds
    FROM dwell
    WHERE dwell_interval IS NOT NULL
    ORDER BY device_type, dwell_interval DESC
)
SELECT d.device_type,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM d.dwell_interval)) AS p50,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM d.dwell_interval)) AS p95,
       PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM d.dwell_interval)) AS p99,
       p.peak_hour, ws.session_id AS worst_session_id, ws.dwell_seconds AS worst_session_seconds
FROM dwell d
JOIN peak p ON p.device_type = d.device_type
JOIN worst_session ws ON ws.device_type = d.device_type
WHERE d.dwell_interval IS NOT NULL
GROUP BY d.device_type, p.peak_hour, ws.session_id, ws.dwell_seconds
ORDER BY d.device_type;
/* Q88. */
WITH latest_price AS (
    SELECT DISTINCT ON (p.product_id) p.product_id, oi.unit_price AS latest_selling_price
    FROM sales.order_items oi
    JOIN sales.orders o ON o.order_id = oi.order_id
    JOIN products.products p ON p.product_id = oi.prod_id
    ORDER BY p.product_id, o.order_date DESC
),
margins AS (
    SELECT c.category_name, p.product_id, 100.0 * (oi.unit_price - p.cost_price) / NULLIF(oi.unit_price, 0) AS margin_pct
    FROM sales.order_items oi
    JOIN products.products p ON p.product_id = oi.prod_id
    JOIN core.dim_brand b ON b.brand_id = p.brand_id
    JOIN core.dim_category c ON c.category_id = b.category_id
)
SELECT m.category_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY m.margin_pct) AS median_margin_pct,
       PERCENTILE_CONT(0.1) WITHIN GROUP (ORDER BY m.margin_pct) AS p10_margin_pct,
       COUNT(DISTINCT m.product_id) FILTER (WHERE m.margin_pct < 20) AS products_below_floor,
       ROUND(AVG(lp.latest_selling_price), 2) AS avg_latest_selling_price
FROM margins m
JOIN latest_price lp ON lp.product_id = m.product_id
GROUP BY m.category_name
ORDER BY m.category_name;
/* Q89. */
SELECT r.region_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sh.shipped_date - o.order_date) AS median_order_to_ship,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY sh.shipped_date - o.order_date) AS p95_order_to_ship,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sh.delivered_date - sh.shipped_date) AS median_ship_to_deliver,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY sh.delivered_date - sh.shipped_date) AS p95_ship_to_deliver,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY sh.delivered_date - o.order_date) AS p95_end_to_end,
       ROUND((100.0 * COUNT(*) FILTER (WHERE sh.delivered_date - o.order_date > 10) / COUNT(*))::numeric, 2) AS breach_pct
FROM sales.orders o
JOIN sales.shipments sh ON sh.order_id = o.order_id
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
WHERE sh.shipped_date IS NOT NULL AND sh.delivered_date IS NOT NULL
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q90. */
WITH priced AS (
    SELECT c.category_name, oi.unit_price, oi.quantity,
           NTILE(5) OVER (PARTITION BY c.category_name ORDER BY oi.unit_price) AS price_band
    FROM sales.order_items oi
    JOIN products.products p ON p.product_id = oi.prod_id
    JOIN core.dim_brand b ON b.brand_id = p.brand_id
    JOIN core.dim_category c ON c.category_id = b.category_id
)
SELECT category_name,
       MAX(band_median_price) FILTER (WHERE price_band = 1) AS band1_price,
       MAX(band_median_units) FILTER (WHERE price_band = 1) AS band1_units,
       MAX(band_median_price) FILTER (WHERE price_band = 5) AS band5_price,
       MAX(band_median_units) FILTER (WHERE price_band = 5) AS band5_units
FROM (
    SELECT category_name, price_band,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY unit_price) AS band_median_price,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY quantity) AS band_median_units
    FROM priced
    GROUP BY category_name, price_band
) x
GROUP BY category_name
ORDER BY category_name;
/* Q91. */
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
),
cust_median AS (
    SELECT cust_id, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total) AS lifetime_median_order
    FROM sales.orders GROUP BY cust_id
)
SELECT c.customer_id, c.first_name, c.last_name, c.tier,
       lo.latest_order_id, lo.latest_order_date,
       lr.latest_review_id, lr.latest_review_date,
       lt.latest_ticket_id, lt.latest_ticket_date,
       cm.lifetime_median_order
FROM customers.customers c
LEFT JOIN latest_order lo ON lo.cust_id = c.customer_id
LEFT JOIN latest_review lr ON lr.customer_id = c.customer_id
LEFT JOIN latest_ticket lt ON lt.customer_id = c.customer_id
LEFT JOIN cust_median cm ON cm.cust_id = c.customer_id
ORDER BY c.customer_id;
/* Q92. */
WITH region_quarter AS (
    SELECT r.region_id, r.region_name, EXTRACT(YEAR FROM o.order_date) AS yr, EXTRACT(QUARTER FROM o.order_date) AS quarter,
           sh.delivered_date - o.order_date AS delivery_days
    FROM sales.orders o
    JOIN sales.shipments sh ON sh.order_id = o.order_id
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    WHERE o.order_status = 'Delivered' AND sh.delivered_date IS NOT NULL
),
quarter_p90 AS (
    SELECT region_id, region_name, yr, quarter,
           PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY delivery_days) AS p90_delivery_days
    FROM region_quarter
    GROUP BY region_id, region_name, yr, quarter
),
targets AS (
    SELECT region_id, region_name, yr, quarter,
           LAG(p90_delivery_days) OVER (PARTITION BY region_id ORDER BY yr, quarter) AS target_p90
    FROM quarter_p90
)
SELECT rq.region_name, rq.yr, rq.quarter, t.target_p90,
       ROUND((100.0 * COUNT(*) FILTER (WHERE rq.delivery_days <= t.target_p90) / COUNT(*))::numeric, 2) AS attainment_pct
FROM region_quarter rq
JOIN targets t ON t.region_id = rq.region_id AND t.yr = rq.yr AND t.quarter = rq.quarter
WHERE t.target_p90 IS NOT NULL
GROUP BY rq.region_name, rq.yr, rq.quarter, t.target_p90
ORDER BY rq.region_name, rq.yr, rq.quarter;
/* Q93. */
WITH weekly AS (
    SELECT r.region_name, date_trunc('week', o.order_date)::date AS week_start,
           PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_aov
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_name, week_start
),
shifted AS (
    SELECT region_name, week_start, p95_aov,
           LAG(p95_aov) OVER (PARTITION BY region_name ORDER BY week_start) AS prev_p95_aov
    FROM weekly
),
flagged AS (
    SELECT region_name, week_start, p95_aov, prev_p95_aov,
           ROUND((100.0 * (p95_aov - prev_p95_aov) / NULLIF(prev_p95_aov, 0))::numeric, 2) AS pct_change
    FROM shifted
    WHERE prev_p95_aov IS NOT NULL
)
SELECT f.region_name, f.week_start, f.p95_aov, f.pct_change,
       RANK() OVER (ORDER BY ABS(f.pct_change) DESC) AS shift_rank,
       (SELECT COUNT(*) FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id
        JOIN core.dim_region r ON r.region_id = s.region_id
        WHERE r.region_name = f.region_name AND o.order_date >= f.week_start AND o.order_date < f.week_start + 7
          AND o.net_total > f.p95_aov) AS orders_above_new_p95
FROM flagged f
ORDER BY shift_rank
LIMIT 20;
/* Q94. */
SELECT r.region_name,
       ARRAY[PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total),
             PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY o.net_total),
             PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total),
             PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY o.net_total)] AS aov_percentiles
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q95. */
WITH region_orders AS (
    SELECT r.region_name, o.order_id, o.net_total,
           NTILE(10) OVER (PARTITION BY r.region_name ORDER BY o.net_total) AS decile
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
)
SELECT region_name,
       ROUND((100.0 * SUM(net_total) FILTER (WHERE decile = 10) / SUM(net_total))::numeric, 2) AS top_decile_revenue_share_pct,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total) AS median_order_value,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY net_total) AS p95_order_value,
       ROUND((PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY net_total)
              / NULLIF(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total), 0))::numeric, 2) AS p95_p50_ratio
FROM region_orders
GROUP BY region_name
ORDER BY region_name;
/* Q96. */
WITH region_metrics AS (
    SELECT r.region_name,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS aov,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sh.delivered_date - o.order_date) AS delivery,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (t.resolved_date - t.created_date)) / 3600.0) AS resolution
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    LEFT JOIN sales.shipments sh ON sh.order_id = o.order_id AND sh.delivered_date IS NOT NULL
    LEFT JOIN support.tickets t ON t.customer_id = o.cust_id AND t.resolved_date IS NOT NULL
    GROUP BY r.region_name
),
unpivoted AS (
    SELECT region_name, 'aov' AS metric_name, aov AS metric_value FROM region_metrics
    UNION ALL
    SELECT region_name, 'delivery_days', delivery FROM region_metrics
    UNION ALL
    SELECT region_name, 'resolution_hours', resolution FROM region_metrics
)
SELECT region_name,
       MAX(metric_value) FILTER (WHERE metric_name = 'aov') AS aov,
       MAX(metric_value) FILTER (WHERE metric_name = 'delivery_days') AS delivery_days,
       MAX(metric_value) FILTER (WHERE metric_name = 'resolution_hours') AS resolution_hours
FROM unpivoted
GROUP BY region_name
ORDER BY region_name;
/* Q97. */
WITH latest AS (
    SELECT DISTINCT ON (r.region_name) r.region_name, o.order_date AS latest_order_date, o.order_id AS latest_order_id
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    ORDER BY r.region_name, o.order_date DESC
)
SELECT r.region_name, MAX(l.latest_order_id) AS latest_order_id, MAX(l.latest_order_date) AS latest_order_date,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_aov
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
JOIN latest l ON l.region_name = r.region_name
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q98. */
WITH store_level AS (
    SELECT s.store_id, r.region_name,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY GROUPING SETS ((s.store_id, r.region_name), (r.region_name), ())
)
SELECT store_id, region_name, median_aov,
       CASE WHEN store_id IS NULL AND region_name IS NULL THEN 'grand_total'
            WHEN store_id IS NULL THEN 'region_total'
            ELSE 'store_level' END AS grain
FROM store_level
ORDER BY region_name NULLS LAST, store_id NULLS LAST;
/* Q99. */
WITH latest AS (
    SELECT DISTINCT ON (r.region_name) r.region_name, o.order_date AS latest_order_date, o.order_id AS latest_order_id
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    ORDER BY r.region_name, o.order_date DESC
),
churn AS (
    SELECT r.region_name, COUNT(DISTINCT c.customer_id) AS churn_risk_count
    FROM customers.customers c
    JOIN sales.orders o ON o.cust_id = c.customer_id
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    WHERE o.order_date < CURRENT_DATE - INTERVAL '180 days'
      AND NOT EXISTS (SELECT 1 FROM sales.orders o2 WHERE o2.cust_id = c.customer_id AND o2.order_date >= CURRENT_DATE - INTERVAL '180 days')
    GROUP BY r.region_name
)
SELECT r.region_name, COUNT(*) AS order_count,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_aov,
       ROUND((100.0 * COUNT(*) FILTER (WHERE o.order_status = 'Delivered') / COUNT(*))::numeric, 2) AS sla_pct,
       COALESCE(MAX(ch.churn_risk_count), 0) AS churn_risk_count,
       MAX(l.latest_order_date) AS latest_order_date,
       RANK() OVER (ORDER BY PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) DESC) AS rnk
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
JOIN latest l ON l.region_name = r.region_name
LEFT JOIN churn ch ON ch.region_name = r.region_name
GROUP BY r.region_name
ORDER BY rnk;
/* Q100. */
WITH deliv AS (
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
),
region_orders AS (
    SELECT r.region_id, r.region_name, o.order_id, o.order_date, o.net_total,
           NTILE(10) OVER (PARTITION BY r.region_id ORDER BY o.net_total) AS decile
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
),
latest_decile AS (
    SELECT DISTINCT ON (region_id) region_id, decile AS latest_order_decile_rank
    FROM region_orders
    ORDER BY region_id, order_date DESC
)
SELECT ro.region_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ro.net_total) AS median_aov,
       PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY ro.net_total) AS p90_aov,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY ro.net_total) AS p95_aov,
       PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ro.net_total) AS p99_aov,
       PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY ro.net_total) - PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY ro.net_total) AS iqr,
       ROUND((100.0 * COUNT(*) FILTER (WHERE sh.delivered_date - o.order_date <= d.p90_target) / NULLIF(COUNT(sh.shipment_id), 0))::numeric, 2) AS sla_pct,
       MAX(l.latest_order_date) AS latest_order_date,
       MAX(ld.latest_order_decile_rank) AS latest_order_decile_rank
FROM region_orders ro
JOIN sales.orders o ON o.order_id = ro.order_id
JOIN stores.stores s ON s.store_id = o.store_id
LEFT JOIN sales.shipments sh ON sh.order_id = o.order_id
LEFT JOIN deliv d ON d.region_id = ro.region_id
LEFT JOIN latest l ON l.region_name = ro.region_name
LEFT JOIN latest_decile ld ON ld.region_id = ro.region_id
GROUP BY ro.region_name, ro.region_id
ORDER BY ro.region_name;

/* ============================================================
   END OF ANSWER KEY - CRAZY LEVEL (100/100)
============================================================ */
