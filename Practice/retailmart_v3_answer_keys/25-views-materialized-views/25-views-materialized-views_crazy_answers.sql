/* ============================================================
   ANSWER KEY - Views & Materialized Views (CRAZY LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1. Semantic layer: raw (thin renamed passthrough, no logic), core (typed/cleaned/deduped, the single source of truth for each entity), marts (domain-specific aggregates - revenue, customer, inventory), exec (the small set of cross-domain KPI objects leadership actually reads) - each layer only reads the layer directly below it, never skips a layer or reaches back into raw source tables. */
/* Q2. View: freshness-critical, cheap-to-compute logic. MV: expensive aggregates/joins read far more often than the source changes, staleness tolerable. Summary table: needs independent write/load control (a pipeline populates it on its own schedule, not derived from one live query) or its own constraints/indexes unrelated to a single source query. */
/* Q3. DAG-driven orchestration models each MV as a node and each "reads from" relationship as an edge, refreshes in topological order (never before all of a node's upstream dependencies have completed), and each refresh step should be idempotent (safe to re-run without duplicating or corrupting state) so a failed/retried run converges to the same correct result rather than compounding an error. */
/* Q4. Ship v_thing_v2 alongside the existing v_thing (v1) with the new shape, migrate consumers to v2 on their own schedule, monitor for v1 traffic dropping to zero (via query logs or pg_stat_user_tables), then drop v1 - so no single deploy simultaneously changes the contract underneath every consumer at once. */
/* Q5. A partial MV filters to just the hot/recent window (e.g. WHERE order_date >= CURRENT_DATE - 90) to keep refresh and index size small; a hybrid live-tail UNIONs that MV with a live aggregate over the very latest slice (since the MV's last refresh) so the combined view is both fast (mostly MV) and near-real-time (small live tail). */
/* Q6. Multi-grain rollups (day/week/month) must each independently aggregate straight from the base table (never rolling one grain up from another, which would compound any rounding or definitional drift) - a reconciliation check (SUM of the daily grain within a week/month should equal the matching week/month-grain row) should run after every refresh to catch drift immediately. */
/* Q7. Postgres has no native incremental/delta MV refresh - REFRESH always recomputes the full defining query; the practical approximation is a partial/windowed MV refreshed on a short interval (re-running the query over just the recent window into a staging table, then swapping) rather than true row-level incremental maintenance. */
/* Q8. CONCURRENTLY builds the new result set separately, then uses the MV's UNIQUE INDEX to compute a row-level diff (insert/update/delete) against the existing data instead of taking an ACCESS EXCLUSIVE lock and swapping the whole table - readers keep seeing the old (consistent) data throughout, at the cost of more total work and requiring that unique index to exist. */
/* Q9. On an MV-backed dashboard, EXPLAIN ANALYZE should show a direct Index Scan/Index-Only Scan on the MV itself with rows examined close to rows returned; any reappearance of the MV's own defining joins/aggregates in the plan, or a Seq Scan on a large MV, signals the query isn't actually hitting the MV efficiently and needs an index matching its filter/order. */
/* Q10. Index strategy on MVs: one UNIQUE INDEX on the natural key (required for CONCURRENTLY, fastest point lookup), range/B-tree indexes on frequently filtered columns (dates, status), expression indexes for computed filters (EXTRACT(year FROM ...)), and INCLUDE-column covering indexes so common dashboard queries can be answered index-only with no heap fetch. */
/* Q11. Before any CASCADE drop, run the pg_depend/pg_class dependency query to get the complete list of everything that would cascade away, review it, and prefer dropping each listed dependent explicitly (or migrating it first) over a blind CASCADE - a documented rollback plan (the CREATE statements to restore each dropped object) should exist before the drop runs. */
/* Q12. SLA tiers: 5-minute for small/partial/windowed MVs feeding a live ops monitor; hourly for same-day dashboards (ticket SLA, inventory snapshots); daily for slow-moving lifetime/summary/exec metrics that nobody needs intraday - map cadence to how fast the consumer's own decision-making actually needs fresh numbers, not to what's technically achievable. */
/* Q13. Refresh cost scales with the size of data scanned/sorted and the complexity of any percentile/window computation in the MV's query; choose refresh windows (off-peak hours, staggered start times across MVs) to avoid every MV's refresh competing for the same CPU/IO/work_mem simultaneously, and budget each refresh tier's total time against the interval it must complete within. */
/* Q14. A deprecation period keeps both the old and new view/MV alive and functionally in sync for an agreed window, communicates a hard cutover date to consumers, and only removes the old object after confirmed zero traffic - never delete on the same deploy that introduces the replacement, since consumers migrate at different speeds. */
/* Q15. A JSON-export MV pre-builds a stable, nested payload (via jsonb_build_object/jsonb_agg) once per refresh so an API endpoint can serve it with a trivial SELECT instead of re-running expensive joins/aggregation and JSON construction on every request - the envelope's shape (field names, nesting) becomes a contract the MV's query must keep stable across refreshes. */
/* Q16. Multi-tenant filtered views scope every row by the tenant/region key in the view's own WHERE clause (or via row-level security policies) so a tenant querying the view can never see another tenant's rows regardless of what the downstream query asks for - the isolation is enforced once, centrally, rather than trusted to every consumer query. */
/* Q17. A latency-SLO MV computes P95/P99 of a duration/response-time metric on a schedule; burn-rate alerting compares how fast the SLO's error budget (the allowed fraction of requests over threshold) is being consumed against a target - a sudden spike in P95 that would exhaust the budget well before the review period ends triggers an earlier, louder alert than a slow steady drift would. */
/* Q18. Time-series MVs should be laid out at one row per fixed time bucket (day/hour) so queries filter by a simple range predicate on that bucket column; where the underlying base table itself is large and partitioned by date, the MV's own refresh query can be scoped to just the relevant partitions to avoid scanning the whole history every time. */
/* Q19. In-place changes (ALTER, adding a column via CREATE OR REPLACE where the shape allows) preserve the object's OID, permissions and dependents automatically; DROP-and-recreate is required whenever the column list shape changes (for a view) or for any MV at all (MVs have no ALTER ... AS), and it re-breaks every CASCADE-dependent object, so it should be scheduled and communicated like the versioned-view rollout in Q4/Q14. */
/* Q20. Every MV should have a companion assertion query - its own aggregate total vs. the equivalent live computation over the base tables - run immediately after refresh; a drift beyond a small rounding tolerance should fail the refresh job and alert, catching a silent SQL/definitional mismatch between the MV and the source of truth before any dashboard displays a wrong number. */
/* Q21. COMMENT ON MATERIALIZED VIEW/VIEW stores owner, grain (one row per what), refresh cadence and known dependents directly on the catalog object itself, so `\d+` or a catalog query surfaces the operational contract in place, without relying on external documentation that can silently drift out of sync with the actual object. */
/* Q22. Stack hygiene: cap nesting depth (2-3 layers max before materializing an intermediate layer), name consistently by layer (raw_/core_/mart_/exec_ prefixes, mv_ for anything materialized), and make ownership explicit (which team's responsibility) so anyone touching a source table can immediately see the blast radius without tracing an undocumented chain of views. */
/* Q23. Build the exec strip as its own MV that joins/unions the outputs of the underlying mart-level MVs (not the raw base tables directly), so the exec layer stays thin, refreshes fast (it's aggregating already-summarized marts, not re-scanning raw orders), and any single mart's definition can change without forcing a rewrite of the exec object's own query shape. */
/* Q24. The Day 26 (dedup) preview: the cleaned/core layer is exactly where dedup logic (e.g. DISTINCT ON keyed on a natural identity, or a fuzzy-match dedup pass) belongs, since "cleaned" already owns the job of turning messy raw rows into one trustworthy row per real-world entity - marts and exec layers should never see duplicate rows to begin with. */
/* Q25. Day 27 cohort/RFM: a mart view is fine when the cohort/RFM computation is cheap enough to run live and consumers need it fresh (e.g. a small customer base); once the customer/order volume makes NTILE/cohort-triangle computation expensive and it's queried repeatedly by a dashboard, materialize it as an MV with a daily (RFM moves slowly) or weekly (cohort curves settle slowly) refresh cadence. */

/* ============================================================
   SECTION B: SEMANTIC-LAYER ARCHITECTURES (25)
   ------------------------------------------------------------ */
/* Q26. */
CREATE OR REPLACE VIEW v_raw_orders AS
SELECT order_id, cust_id, store_id, order_date, order_status, net_total, payment_mode_id FROM sales.orders;
CREATE OR REPLACE VIEW v_raw_customers AS
SELECT customer_id, first_name, last_name, email, tier, registration_date FROM customers.customers;
CREATE OR REPLACE VIEW v_raw_products AS
SELECT product_id, product_name, brand_id, supplier_id, price, cost_price FROM products.products;
CREATE OR REPLACE VIEW v_raw_stores AS
SELECT store_id, store_name, region_id, city FROM stores.stores;
CREATE OR REPLACE VIEW v_raw_regions AS
SELECT region_id, region_name, country, state FROM core.dim_region;
/* Q27. */
CREATE OR REPLACE VIEW v_core_orders AS
SELECT order_id, cust_id, store_id, order_date, INITCAP(TRIM(order_status)) AS order_status, net_total
FROM v_raw_orders
WHERE order_status <> 'Failed';
CREATE OR REPLACE VIEW v_core_customers AS
SELECT customer_id, first_name || ' ' || last_name AS full_name, tier, registration_date
FROM v_raw_customers;
CREATE OR REPLACE VIEW v_core_products AS
SELECT product_id, TRIM(product_name) AS product_name, brand_id, supplier_id, price, cost_price
FROM v_raw_products
WHERE price IS NOT NULL;
/* Q28. */
CREATE OR REPLACE VIEW v_mart_revenue_by_region_month AS
SELECT r.region_name, date_trunc('month', o.order_date)::date AS month, SUM(o.net_total) AS revenue, COUNT(*) AS order_count
FROM v_core_orders o
JOIN v_raw_stores s ON s.store_id = o.store_id
JOIN v_raw_regions r ON r.region_id = s.region_id
GROUP BY r.region_name, month;

CREATE OR REPLACE VIEW v_mart_customer_lifetime AS
SELECT cust_id AS customer_id, COUNT(*) AS total_orders, SUM(net_total) AS total_revenue, MAX(order_date) AS latest_order
FROM v_core_orders
GROUP BY cust_id;
/* Q29. */
CREATE OR REPLACE VIEW v_exec_region_strip AS
SELECT r.region_name, COUNT(*) AS orders,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov,
       PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY o.net_total) AS p90_aov,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_aov,
       MAX(o.order_date) AS latest_order_date
FROM v_core_orders o
JOIN v_raw_stores s ON s.store_id = o.store_id
JOIN v_raw_regions r ON r.region_id = s.region_id
GROUP BY r.region_name;
/* Q30. */
CREATE OR REPLACE VIEW v_mart_customer_cross_domain AS
SELECT c.customer_id, c.full_name,
       lo.order_id AS latest_order_id, lo.order_date AS latest_order_date,
       lr.review_id AS latest_review_id, lr.review_date AS latest_review_date,
       lp.status AS latest_payment_status
FROM v_core_customers c
LEFT JOIN (SELECT DISTINCT ON (cust_id) cust_id, order_id, order_date FROM sales.orders ORDER BY cust_id, order_date DESC) lo ON lo.cust_id = c.customer_id
LEFT JOIN (SELECT DISTINCT ON (customer_id) customer_id, review_id, review_date FROM customers.reviews ORDER BY customer_id, review_date DESC) lr ON lr.customer_id = c.customer_id
LEFT JOIN (SELECT DISTINCT ON (order_id) order_id, status FROM finance.payments ORDER BY order_id, payment_id DESC) lp ON lp.order_id = lo.order_id;
/* Q31. */
CREATE OR REPLACE VIEW v_mart_product AS
WITH latest_price AS (
    SELECT DISTINCT ON (p.product_id) p.product_id, oi.unit_price AS latest_price
    FROM sales.order_items oi
    JOIN sales.orders o ON o.order_id = oi.order_id
    JOIN products.products p ON p.product_id = oi.prod_id
    ORDER BY p.product_id, o.order_date DESC
)
SELECT pc.product_id, pc.product_name, b.brand_name, cat.category_name,
       ROUND((100.0 * (pc.price - pc.cost_price) / NULLIF(pc.price, 0))::numeric, 2) AS margin_pct,
       lp.latest_price,
       EXISTS (SELECT 1 FROM products.promotions pr WHERE pr.active) AS has_any_active_promo
FROM v_core_products pc
JOIN core.dim_brand b ON b.brand_id = pc.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
LEFT JOIN latest_price lp ON lp.product_id = pc.product_id;
/* Q32. */
CREATE OR REPLACE VIEW v_mart_inventory AS
WITH latest_snap AS (
    SELECT DISTINCT ON (warehouse_id, product_id) warehouse_id, product_id, snapshot_date, quantity_on_hand
    FROM supply_chain.inventory_snapshots
    ORDER BY warehouse_id, product_id, snapshot_date DESC
),
snap_diffs AS (
    SELECT warehouse_id, product_id, quantity_on_hand - LAG(quantity_on_hand) OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date) AS qty_change
    FROM supply_chain.inventory_snapshots
),
depletion AS (
    SELECT warehouse_id, product_id, AVG(-qty_change) AS avg_daily_depletion
    FROM snap_diffs WHERE qty_change < 0
    GROUP BY warehouse_id, product_id
)
SELECT ls.warehouse_id, ls.product_id, ls.quantity_on_hand, ls.quantity_on_hand * p.cost_price AS inventory_value,
       ls.quantity_on_hand / NULLIF(d.avg_daily_depletion, 0) AS days_of_cover
FROM latest_snap ls
JOIN products.products p ON p.product_id = ls.product_id
LEFT JOIN depletion d ON d.warehouse_id = ls.warehouse_id AND d.product_id = ls.product_id;
/* Q33. */
CREATE OR REPLACE VIEW v_mart_web_sessions AS
SELECT session_id, customer_id, MIN(view_timestamp) AS session_start, MAX(view_timestamp) AS session_end, COUNT(*) AS page_views
FROM web_events.page_views
GROUP BY session_id, customer_id;

CREATE OR REPLACE VIEW v_mart_web_funnel AS
SELECT 'page_view' AS stage, COUNT(DISTINCT view_id) AS event_count FROM web_events.page_views
UNION ALL
SELECT event_type, COUNT(*) FROM web_events.events GROUP BY event_type;

CREATE OR REPLACE VIEW v_mart_web_heatmap AS
SELECT EXTRACT(DOW FROM view_timestamp)::int AS weekday, EXTRACT(HOUR FROM view_timestamp)::int AS hour_of_day, COUNT(*) AS view_count
FROM web_events.page_views
GROUP BY 1, 2;
/* Q34. */
CREATE OR REPLACE VIEW v_mart_sla AS
WITH deliv AS (
    SELECT r.region_name,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sh.delivered_date - o.order_date) AS median_delivery_days,
           PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY sh.delivered_date - o.order_date) AS p95_delivery_days
    FROM sales.orders o
    JOIN sales.shipments sh ON sh.order_id = o.order_id
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    WHERE o.order_status = 'Delivered' AND sh.delivered_date IS NOT NULL
    GROUP BY r.region_name
),
tick AS (
    SELECT priority,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600.0) AS median_resolution_hours
    FROM support.tickets
    WHERE resolved_date IS NOT NULL
    GROUP BY priority
)
SELECT d.region_name, NULL::text AS priority, d.median_delivery_days, NULL::numeric AS median_resolution_hours FROM deliv d
UNION ALL
SELECT NULL, t.priority, NULL, t.median_resolution_hours FROM tick t;
/* Q35. */
CREATE OR REPLACE VIEW v_mart_pricing AS
WITH band AS (
    SELECT prod_id,
           PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY unit_price) AS p25_price,
           PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY unit_price) AS p75_price
    FROM sales.order_items
    GROUP BY prod_id
),
latest AS (
    SELECT DISTINCT ON (p.product_id) p.product_id, oi.unit_price AS latest_price
    FROM sales.order_items oi
    JOIN sales.orders o ON o.order_id = oi.order_id
    JOIN products.products p ON p.product_id = oi.prod_id
    ORDER BY p.product_id, o.order_date DESC
)
SELECT l.product_id, b.p25_price, b.p75_price, l.latest_price,
       (l.latest_price < b.p25_price OR l.latest_price > b.p75_price) AS drift_flag
FROM latest l
JOIN band b ON b.prod_id = l.product_id;
/* Q36. */
CREATE OR REPLACE VIEW v_mart_cohort AS
WITH first_order AS (
    SELECT cust_id, date_trunc('month', MIN(order_date))::date AS cohort_month FROM sales.orders GROUP BY cust_id
),
activity AS (
    SELECT fo.cohort_month, o.cust_id, o.net_total,
           (EXTRACT(YEAR FROM o.order_date) - EXTRACT(YEAR FROM fo.cohort_month)) * 12
             + (EXTRACT(MONTH FROM o.order_date) - EXTRACT(MONTH FROM fo.cohort_month)) AS period_index
    FROM sales.orders o
    JOIN first_order fo ON fo.cust_id = o.cust_id
)
SELECT cohort_month, period_index::int AS period_index, COUNT(DISTINCT cust_id) AS active_customers,
       SUM(net_total) AS period_revenue,
       SUM(SUM(net_total)) OVER (PARTITION BY cohort_month ORDER BY period_index) AS cumulative_revenue
FROM activity
GROUP BY cohort_month, period_index;
/* Q37. */
CREATE OR REPLACE VIEW v_mart_rfm AS
SELECT cust_id AS customer_id,
       NTILE(5) OVER (ORDER BY MAX(order_date) DESC) AS recency_score,
       NTILE(5) OVER (ORDER BY COUNT(*) DESC) AS frequency_score,
       NTILE(5) OVER (ORDER BY SUM(net_total) DESC) AS monetary_score
FROM sales.orders
GROUP BY cust_id;
/* Q38. */
CREATE OR REPLACE VIEW v_mart_audit AS
SELECT change_id, table_name, column_name, old_value, new_value, changed_by, changed_at
FROM audit.record_changes
WHERE column_name IN ('price', 'net_total', 'amount')
  AND old_value ~ '^[0-9.]+$' AND new_value ~ '^[0-9.]+$'
  AND old_value::numeric > 0
  AND ABS(new_value::numeric - old_value::numeric) / old_value::numeric > 0.5;
/* Q39. */
CREATE OR REPLACE VIEW v_mart_region_rollup AS
SELECT r.region_name,
       PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY o.net_total) AS p25_aov,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS p50_aov,
       PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY o.net_total) AS p75_aov,
       SUM(o.net_total) AS total_revenue
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name;
/* Q40. */
CREATE OR REPLACE VIEW v_mart_multi_grain_revenue AS
SELECT 'day' AS grain, order_date::text AS bucket, SUM(net_total) AS revenue FROM sales.orders GROUP BY order_date
UNION ALL
SELECT 'week', date_trunc('week', order_date)::date::text, SUM(net_total) FROM sales.orders GROUP BY date_trunc('week', order_date)
UNION ALL
SELECT 'month', date_trunc('month', order_date)::date::text, SUM(net_total) FROM sales.orders GROUP BY date_trunc('month', order_date);
/* Q41. */
CREATE OR REPLACE VIEW v_mart_anomaly AS
WITH daily AS (
    SELECT r.region_name, o.order_date, SUM(o.net_total) AS revenue
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_name, o.order_date
),
bounds AS (
    SELECT region_name,
           PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY revenue) AS p95_revenue,
           PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY revenue) AS p99_revenue
    FROM daily
    GROUP BY region_name
)
SELECT d.region_name, d.order_date, d.revenue, b.p95_revenue, b.p99_revenue
FROM daily d
JOIN bounds b ON b.region_name = d.region_name
WHERE d.revenue > b.p95_revenue;
/* Q42. */
CREATE OR REPLACE VIEW v_mart_region_strip_json AS
SELECT region_name, jsonb_build_object(
    'region', region_name,
    'orders', orders,
    'median_aov', median_aov,
    'p90_aov', p90_aov,
    'p95_aov', p95_aov,
    'latest_order_date', latest_order_date
) AS doc
FROM v_exec_region_strip;
/* Q43. */
CREATE OR REPLACE VIEW v_mart_time_series AS
WITH daily AS (
    SELECT order_date AS d, SUM(net_total) AS revenue FROM sales.orders GROUP BY order_date
)
SELECT d, revenue,
       AVG(revenue) OVER (ORDER BY d ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS ma_7day,
       revenue - LAG(revenue, 7) OVER (ORDER BY d) AS wow_change,
       revenue - LAG(revenue, 365) OVER (ORDER BY d) AS yoy_change
FROM daily;
/* Q44. */
CREATE OR REPLACE VIEW v_mart_funnel_per_channel_hour AS
SELECT device_type, EXTRACT(HOUR FROM view_timestamp)::int AS hour_of_day, COUNT(*) AS page_views
FROM web_events.page_views
GROUP BY device_type, hour_of_day;
/* Q45. */
CREATE OR REPLACE VIEW v_mart_pricing_corridor_json AS
SELECT product_id, jsonb_build_object(
    'product_id', product_id,
    'p25_price', p25_price,
    'p75_price', p75_price,
    'latest_price', latest_price,
    'drift_flag', drift_flag
) AS doc
FROM v_mart_pricing;
/* Q46. */
CREATE OR REPLACE VIEW v_mart_customer_360_relational AS
SELECT c.customer_id,
       ARRAY(SELECT order_id FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY o.order_date DESC LIMIT 5) AS recent_order_ids,
       ARRAY(SELECT ticket_id FROM support.tickets t WHERE t.customer_id = c.customer_id ORDER BY t.created_date DESC LIMIT 5) AS recent_ticket_ids
FROM customers.customers c;
/* Q47. */
CREATE OR REPLACE VIEW v_mart_lifecycle_stage AS
WITH cust_orders AS (
    SELECT cust_id, order_date, ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date) AS order_seq
    FROM sales.orders
)
SELECT cust_id, date_trunc('month', order_date)::date AS month,
       CASE WHEN order_seq = 1 THEN 'new' ELSE 'returning' END AS lifecycle_stage
FROM cust_orders;
/* Q48. */
CREATE OR REPLACE VIEW v_mart_reactivation AS
WITH gaps AS (
    SELECT cust_id, order_date, order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date) AS gap_days
    FROM sales.orders
)
SELECT date_trunc('month', order_date)::date AS month, COUNT(*) AS reactivation_count
FROM gaps
WHERE gap_days > 180
GROUP BY month;
/* Q49. */
CREATE OR REPLACE VIEW v_mart_heatmap_device AS
SELECT device_type, EXTRACT(DOW FROM view_timestamp)::int AS weekday, EXTRACT(HOUR FROM view_timestamp)::int AS hour_of_day, COUNT(*) AS view_count
FROM web_events.page_views
GROUP BY device_type, weekday, hour_of_day;
/* Q50. */
CREATE OR REPLACE VIEW v_raw_orders AS
SELECT order_id, cust_id, store_id, order_date, order_status, net_total, payment_mode_id FROM sales.orders;
CREATE OR REPLACE VIEW v_core_orders AS
SELECT order_id, cust_id, store_id, order_date, INITCAP(TRIM(order_status)) AS order_status, net_total
FROM v_raw_orders
WHERE order_status <> 'Failed';
CREATE OR REPLACE VIEW v_mart_revenue_by_region_month AS
SELECT r.region_name, date_trunc('month', o.order_date)::date AS month, SUM(o.net_total) AS revenue, COUNT(*) AS order_count
FROM v_core_orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name, month;
CREATE OR REPLACE VIEW v_exec_region_strip AS
SELECT r.region_name, COUNT(*) AS orders,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov,
       PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY o.net_total) AS p90_aov,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_aov,
       MAX(o.order_date) AS latest_order_date
FROM v_core_orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name;
-- runnable script: every statement is CREATE OR REPLACE VIEW, so this composes the full semantic layer idempotently top-to-bottom.

/* ============================================================
   SECTION C: REFRESH ORCHESTRATION & MV PIPELINES (25)
   ------------------------------------------------------------ */
/* Q51. */
/* Refresh DAG for every MV created in this file (see Section D): mv_exec_strip, mv_customer_360, mv_anomaly_alerts, mv_funnel_stage_hourly and mv_pricing_corridor each read only base tables directly - no MV in this set is built from another MV, so the DAG here is a flat set of independent nodes with no edges; each can refresh in any order or in parallel, grouped only by shared source table to reduce refresh-time contention. */
/* Q52. */
/* Topological refresh script (flat DAG - order shown reflects source-table grouping, not a true dependency requirement). Bootstrap: full definitions for these 5 MVs live in Section D (Q70-Q74); created here first so this refresh script has something to refresh - REFRESH is a no-op data reload once each MV already exists, so re-running the Section D CREATE later in this file is just their (idempotent) structural redefinition. */
DROP MATERIALIZED VIEW IF EXISTS mv_exec_strip;
CREATE MATERIALIZED VIEW mv_exec_strip AS
WITH churn AS (
    SELECT r.region_name, COUNT(DISTINCT c.customer_id) AS churn_risk_count
    FROM customers.customers c
    JOIN sales.orders o ON o.cust_id = c.customer_id
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    WHERE o.order_date < CURRENT_DATE - INTERVAL '180 days'
      AND NOT EXISTS (SELECT 1 FROM sales.orders o2 WHERE o2.cust_id = c.customer_id AND o2.order_date >= CURRENT_DATE - INTERVAL '180 days')
    GROUP BY r.region_name
)
SELECT r.region_id, r.region_name, COUNT(*) AS orders,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_aov,
       COALESCE(MAX(ch.churn_risk_count), 0) AS churn_risk_count,
       RANK() OVER (ORDER BY PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) DESC) AS rnk
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
LEFT JOIN churn ch ON ch.region_name = r.region_name
GROUP BY r.region_id, r.region_name;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_exec_strip ON mv_exec_strip(region_id);
DROP MATERIALIZED VIEW IF EXISTS mv_customer_360;
CREATE MATERIALIZED VIEW mv_customer_360 AS
SELECT c.customer_id, c.tier, COUNT(o.order_id) AS order_count, MAX(o.order_date) AS latest_order_date
FROM customers.customers c
LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY c.customer_id, c.tier;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_customer_360 ON mv_customer_360(customer_id);
DROP MATERIALIZED VIEW IF EXISTS mv_anomaly_alerts;
CREATE MATERIALIZED VIEW mv_anomaly_alerts AS
WITH daily AS (
    SELECT r.region_id, r.region_name, o.order_date AS d, SUM(o.net_total) AS revenue
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_id, r.region_name, o.order_date
),
bounds AS (
    SELECT region_id, PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY revenue) AS p95_revenue
    FROM daily
    GROUP BY region_id
)
SELECT dl.region_id, dl.region_name, dl.d, dl.revenue, b.p95_revenue
FROM daily dl
JOIN bounds b ON b.region_id = dl.region_id
WHERE dl.revenue > b.p95_revenue;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_anomaly_alerts ON mv_anomaly_alerts(d, region_id);
DROP MATERIALIZED VIEW IF EXISTS mv_funnel_stage_hourly;
CREATE MATERIALIZED VIEW mv_funnel_stage_hourly AS
SELECT event_type AS stage, EXTRACT(HOUR FROM event_timestamp)::int AS hour, COUNT(*) AS event_count
FROM web_events.events
GROUP BY event_type, hour;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_funnel_stage_hourly ON mv_funnel_stage_hourly(stage, hour);
DROP MATERIALIZED VIEW IF EXISTS mv_pricing_corridor;
CREATE MATERIALIZED VIEW mv_pricing_corridor AS
WITH band AS (
    SELECT prod_id,
           PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY unit_price) AS p25_price,
           PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY unit_price) AS p75_price
    FROM sales.order_items
    GROUP BY prod_id
),
latest AS (
    SELECT DISTINCT ON (p.product_id) p.product_id, oi.unit_price AS latest_price
    FROM sales.order_items oi
    JOIN sales.orders o ON o.order_id = oi.order_id
    JOIN products.products p ON p.product_id = oi.prod_id
    ORDER BY p.product_id, o.order_date DESC
)
SELECT l.product_id AS prod_id, b.p25_price, b.p75_price, l.latest_price,
       (l.latest_price < b.p25_price OR l.latest_price > b.p75_price) AS drift_flag
FROM latest l
JOIN band b ON b.prod_id = l.product_id;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_pricing_corridor ON mv_pricing_corridor(prod_id);
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_exec_strip;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_customer_360;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_anomaly_alerts;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_funnel_stage_hourly;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_pricing_corridor;
/* Q53. */
SELECT c.relname AS mv_name,
       EXISTS (SELECT 1 FROM pg_index i WHERE i.indrelid = c.oid AND i.indisunique) AS concurrently_eligible
FROM pg_class c
WHERE c.relkind = 'm'
ORDER BY c.relname;
/* Q54. */
DROP MATERIALIZED VIEW IF EXISTS mv_daily_revenue;
CREATE MATERIALIZED VIEW mv_daily_revenue AS
SELECT order_date AS d, SUM(net_total) AS revenue FROM sales.orders GROUP BY order_date;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_daily_revenue ON mv_daily_revenue(d);
CREATE OR REPLACE VIEW v_daily_revenue_hybrid AS
SELECT d, revenue FROM mv_daily_revenue
UNION ALL
SELECT CURRENT_DATE, COALESCE(SUM(net_total), 0)
FROM sales.orders
WHERE order_date = CURRENT_DATE
  AND CURRENT_DATE NOT IN (SELECT d FROM mv_daily_revenue);
/* Q55. */
DROP MATERIALIZED VIEW IF EXISTS mv_daily_revenue_90d;
CREATE MATERIALIZED VIEW mv_daily_revenue_90d AS
SELECT d.day::date AS d, COALESCE(SUM(o.net_total), 0) AS revenue
FROM generate_series(CURRENT_DATE - INTERVAL '90 days', CURRENT_DATE, INTERVAL '1 day') AS d(day)
LEFT JOIN sales.orders o ON o.order_date = d.day::date
GROUP BY d.day;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_daily_revenue_90d ON mv_daily_revenue_90d(d);
/* Q56. */
/* Chunked refresh design for a huge percentile MV: partition the aggregation by a natural key (e.g. region_id), loop over each region, compute PERCENTILE_CONT for just that region's rows, and INSERT the result into a staging table; once every region-chunk has completed, swap the staging table into place (ALTER TABLE staging RENAME TO mv_name, or TRUNCATE + INSERT INTO the real MV from staging) so no single query has to sort the entire dataset's worth of values in one pass, and a failure partway through only needs to re-run the failed chunk. */
/* Q57. */
DROP MATERIALIZED VIEW IF EXISTS mv_revenue_daily;
CREATE MATERIALIZED VIEW mv_revenue_daily AS
SELECT order_date AS d, SUM(net_total) AS revenue FROM sales.orders GROUP BY order_date;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_revenue_daily ON mv_revenue_daily(d);

DROP MATERIALIZED VIEW IF EXISTS mv_revenue_weekly;
CREATE MATERIALIZED VIEW mv_revenue_weekly AS
SELECT date_trunc('week', order_date)::date AS week_start, SUM(net_total) AS revenue FROM sales.orders GROUP BY 1;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_revenue_weekly ON mv_revenue_weekly(week_start);

DROP MATERIALIZED VIEW IF EXISTS mv_revenue_monthly;
CREATE MATERIALIZED VIEW mv_revenue_monthly AS
SELECT date_trunc('month', order_date)::date AS month, SUM(net_total) AS revenue FROM sales.orders GROUP BY 1;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_revenue_monthly ON mv_revenue_monthly(month);

SELECT (SELECT SUM(revenue) FROM mv_revenue_daily WHERE d >= '2025-01-01' AND d < '2025-02-01') AS daily_rollup_jan2025,
       (SELECT revenue FROM mv_revenue_monthly WHERE month = '2025-01-01') AS monthly_jan2025;
/* Q58. */
/* Time-budget refresh planner (cadence tiers): 5-minute tier: mv_daily_revenue_90d (small, partial). hourly tier: mv_anomaly_alerts, mv_funnel_stage_hourly (ops-facing, same-day freshness). daily tier: mv_exec_strip, mv_customer_360, mv_pricing_corridor (slower-moving summary metrics) - each MV is assigned to exactly one tier based on how expensive its own refresh query is and how fresh its consumer actually needs it. */
/* Q59. */
DROP MATERIALIZED VIEW IF EXISTS mv_revenue_daily;
CREATE MATERIALIZED VIEW mv_revenue_daily AS
SELECT order_date AS d, SUM(net_total) AS revenue
FROM sales.orders
WHERE order_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY order_date;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_revenue_daily ON mv_revenue_daily(d);
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_revenue_daily;
-- idempotent rebuild for a date range: DROP + CREATE (scoped by the date filter) + REFRESH CONCURRENTLY; re-running this exact script always converges to the same 30-day window's data.
/* Q60. */
/* Detecting cycles in the view DAG (concept): walk pg_depend/pg_rewrite edges from each view/MV to what it reads, and flag any path that revisits a node already on the current traversal stack - Postgres itself refuses to CREATE a view/MV whose definition would directly or indirectly reference itself, so a true cycle can't actually exist in a live schema; the audit is really about catching accidental near-cycles (e.g. two views that both read a third and each other) that make refresh ordering ambiguous. */
/* Q61. */
CREATE OR REPLACE VIEW v_exec_region_strip_v2 AS
SELECT r.region_name, COUNT(*) AS orders,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_aov,
       PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY o.net_total) AS p99_aov,
       MAX(o.order_date) AS latest_order_date
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name;
-- v1 (v_exec_region_strip) stays untouched and serving existing consumers; v2 adds p99_aov. Drop v1 only once every consumer has migrated to v2.
/* Q62. */
EXPLAIN ANALYZE SELECT * FROM mv_exec_strip WHERE region_id = 1;
/* Q63. */
/* Index strategy per MV (concept): mv_exec_strip -> UNIQUE INDEX(region_id) [required, CONCURRENTLY-eligible]; mv_customer_360 -> UNIQUE INDEX(customer_id) [required] + INCLUDE (tier) for a covering point lookup; mv_anomaly_alerts -> UNIQUE INDEX(d, region_id) [composite natural key] + range index on (d) alone for date-range dashboard queries; mv_funnel_stage_hourly -> UNIQUE INDEX(stage, hour) [required]; mv_pricing_corridor -> UNIQUE INDEX(prod_id) [required] + partial index WHERE drift_flag for the drift-alert view. */
/* Q64. */
/* Drop-and-recreate is required for any MV structural change (column list, grouping) since MVs have no ALTER ... AS; ALTER MATERIALIZED VIEW itself only supports metadata-level changes (rename, owner, set schema, storage parameters) - so it's used for renaming/reassigning an MV without disturbing its data or dependents, while any change to what the MV actually computes always goes through DROP + CREATE (with CASCADE-aware cleanup of dependents first). */
/* Q65. */
/* Refresh failure handling: wrap each REFRESH in application-level try/catch (a scheduler job, not SQL itself, since a failed REFRESH doesn't corrupt the MV - Postgres leaves the previous successful data intact on a plain REFRESH failure, and CONCURRENTLY specifically never exposes a partial/half-updated result to readers); on failure, alert an operator with the failing MV's name and error, retry once after a backoff, and if it fails again leave the MV at its last-good state rather than retrying indefinitely and consuming resources. */
/* Q66. */
SELECT 'mv_exec_strip' AS mv_name, (SELECT SUM(orders) FROM mv_exec_strip) AS mv_total, (SELECT COUNT(*) FROM sales.orders) AS live_total
UNION ALL
SELECT 'mv_customer_360', (SELECT COUNT(*) FROM mv_customer_360), (SELECT COUNT(*) FROM customers.customers)
UNION ALL
SELECT 'mv_pricing_corridor', (SELECT COUNT(*) FROM mv_pricing_corridor), (SELECT COUNT(DISTINCT prod_id) FROM sales.order_items);
/* Q67. */
SELECT c.relname AS mv_name, pg_size_pretty(pg_total_relation_size(c.oid)) AS size,
       EXISTS (SELECT 1 FROM pg_index i WHERE i.indrelid = c.oid AND i.indisunique) AS has_unique_index
FROM pg_class c
WHERE c.relkind = 'm'
ORDER BY c.relname;
/* Q68. */
/* Cost forecasting per tier: 5-minute tier MVs must individually complete well under 5 minutes (target <60s) since the next refresh is queued almost immediately; hourly-tier MVs have a much larger budget (minutes) but should still finish before the next hourly trigger fires; daily-tier MVs (the slowest, often percentile/window-heavy) can run during an overnight maintenance window and are budgeted against that whole window rather than a tight per-refresh SLO. */
/* Q69. */
/* Refresh-window throttling (concept): stagger each MV's scheduled refresh time (rather than firing all of them at the same cron minute) so their I/O/CPU/work_mem usage doesn't all spike simultaneously and starve concurrent application queries; a simple approach is spacing same-tier MVs a few minutes apart, or running them through a job queue with a concurrency limit rather than firing every refresh job at once. */
/* Q70. */
DROP MATERIALIZED VIEW IF EXISTS mv_exec_strip;
CREATE MATERIALIZED VIEW mv_exec_strip AS
WITH churn AS (
    SELECT r.region_name, COUNT(DISTINCT c.customer_id) AS churn_risk_count
    FROM customers.customers c
    JOIN sales.orders o ON o.cust_id = c.customer_id
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    WHERE o.order_date < CURRENT_DATE - INTERVAL '180 days'
      AND NOT EXISTS (SELECT 1 FROM sales.orders o2 WHERE o2.cust_id = c.customer_id AND o2.order_date >= CURRENT_DATE - INTERVAL '180 days')
    GROUP BY r.region_name
)
SELECT r.region_id, r.region_name, COUNT(*) AS orders,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_aov,
       COALESCE(MAX(ch.churn_risk_count), 0) AS churn_risk_count,
       RANK() OVER (ORDER BY PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) DESC) AS rnk
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
LEFT JOIN churn ch ON ch.region_name = r.region_name
GROUP BY r.region_id, r.region_name;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_exec_strip ON mv_exec_strip(region_id);
/* Q71. */
DROP MATERIALIZED VIEW IF EXISTS mv_customer_360;
CREATE MATERIALIZED VIEW mv_customer_360 AS
SELECT c.customer_id, c.tier, COUNT(o.order_id) AS order_count, MAX(o.order_date) AS latest_order_date
FROM customers.customers c
LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY c.customer_id, c.tier;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_customer_360 ON mv_customer_360(customer_id);
COMMENT ON MATERIALIZED VIEW mv_customer_360 IS 'Owner: analytics team. Grain: one row per customer. Refresh: nightly 03:00 UTC.';
/* Q72. */
DROP MATERIALIZED VIEW IF EXISTS mv_anomaly_alerts;
CREATE MATERIALIZED VIEW mv_anomaly_alerts AS
WITH daily AS (
    SELECT r.region_id, r.region_name, o.order_date AS d, SUM(o.net_total) AS revenue
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_id, r.region_name, o.order_date
),
bounds AS (
    SELECT region_id, PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY revenue) AS p95_revenue
    FROM daily
    GROUP BY region_id
)
SELECT dl.region_id, dl.region_name, dl.d, dl.revenue, b.p95_revenue
FROM daily dl
JOIN bounds b ON b.region_id = dl.region_id
WHERE dl.revenue > b.p95_revenue;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_anomaly_alerts ON mv_anomaly_alerts(d, region_id);
/* Q73. */
DROP MATERIALIZED VIEW IF EXISTS mv_funnel_stage_hourly;
CREATE MATERIALIZED VIEW mv_funnel_stage_hourly AS
SELECT event_type AS stage, EXTRACT(HOUR FROM event_timestamp)::int AS hour, COUNT(*) AS event_count
FROM web_events.events
GROUP BY event_type, hour;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_funnel_stage_hourly ON mv_funnel_stage_hourly(stage, hour);
/* Q74. */
DROP MATERIALIZED VIEW IF EXISTS mv_pricing_corridor;
CREATE MATERIALIZED VIEW mv_pricing_corridor AS
WITH band AS (
    SELECT prod_id,
           PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY unit_price) AS p25_price,
           PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY unit_price) AS p75_price
    FROM sales.order_items
    GROUP BY prod_id
),
latest AS (
    SELECT DISTINCT ON (p.product_id) p.product_id, oi.unit_price AS latest_price
    FROM sales.order_items oi
    JOIN sales.orders o ON o.order_id = oi.order_id
    JOIN products.products p ON p.product_id = oi.prod_id
    ORDER BY p.product_id, o.order_date DESC
)
SELECT l.product_id AS prod_id, b.p25_price, b.p75_price, l.latest_price,
       (l.latest_price < b.p25_price OR l.latest_price > b.p75_price) AS drift_flag
FROM latest l
JOIN band b ON b.prod_id = l.product_id;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_pricing_corridor ON mv_pricing_corridor(prod_id);
/* Q75. */
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_exec_strip;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_customer_360;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_anomaly_alerts;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_funnel_stage_hourly;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_pricing_corridor;
-- idempotent: every DROP uses IF EXISTS and every CREATE INDEX uses IF NOT EXISTS, so this whole Section C script can be re-run safely; the flat dependency graph (Q51) means no ordering constraint beyond "run each once".

/* ============================================================
   SECTION D: PRODUCTION DELIVERY SYSTEMS (25)
   ------------------------------------------------------------ */
/* Q76. */
CREATE OR REPLACE VIEW v_exec_region_strip_json AS
SELECT region_id, jsonb_build_object(
    'region', region_name, 'orders', orders, 'median_aov', median_aov, 'p95_aov', p95_aov,
    'churn_risk_count', churn_risk_count, 'rank', rnk
) AS doc
FROM mv_exec_strip;
/* Q77. */
DROP MATERIALIZED VIEW IF EXISTS mv_delivery_sla;
CREATE MATERIALIZED VIEW mv_delivery_sla AS
SELECT r.region_id, r.region_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sh.delivered_date - o.order_date) AS median_days,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY sh.delivered_date - o.order_date) AS p95_days
FROM sales.orders o
JOIN sales.shipments sh ON sh.order_id = o.order_id
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
WHERE o.order_status = 'Delivered' AND sh.delivered_date IS NOT NULL
GROUP BY r.region_id, r.region_name;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_delivery_sla ON mv_delivery_sla(region_id);

DROP MATERIALIZED VIEW IF EXISTS mv_ticket_sla;
CREATE MATERIALIZED VIEW mv_ticket_sla AS
SELECT priority,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600.0) AS median_hours,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600.0) AS p95_hours
FROM support.tickets
WHERE resolved_date IS NOT NULL
GROUP BY priority;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_ticket_sla ON mv_ticket_sla(priority);
/* Q78. */
CREATE OR REPLACE VIEW v_pricing_drift_alerts AS
SELECT prod_id, p25_price, p75_price, latest_price
FROM mv_pricing_corridor
WHERE drift_flag;
/* Q79. */
DROP MATERIALIZED VIEW IF EXISTS mv_inventory_value;
CREATE MATERIALIZED VIEW mv_inventory_value AS
WITH latest_snap AS (
    SELECT DISTINCT ON (warehouse_id, product_id) warehouse_id, product_id, snapshot_date, quantity_on_hand
    FROM supply_chain.inventory_snapshots
    ORDER BY warehouse_id, product_id, snapshot_date DESC
),
snap_diffs AS (
    SELECT warehouse_id, product_id, quantity_on_hand - LAG(quantity_on_hand) OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date) AS qty_change
    FROM supply_chain.inventory_snapshots
),
depletion AS (
    SELECT warehouse_id, product_id, AVG(-qty_change) AS avg_daily_depletion
    FROM snap_diffs WHERE qty_change < 0
    GROUP BY warehouse_id, product_id
)
SELECT ls.warehouse_id, SUM(ls.quantity_on_hand * p.cost_price) AS inventory_value,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ls.quantity_on_hand / NULLIF(d.avg_daily_depletion, 0)) AS median_days_of_cover
FROM latest_snap ls
JOIN products.products p ON p.product_id = ls.product_id
LEFT JOIN depletion d ON d.warehouse_id = ls.warehouse_id AND d.product_id = ls.product_id
GROUP BY ls.warehouse_id;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_inventory_value ON mv_inventory_value(warehouse_id);

DROP MATERIALIZED VIEW IF EXISTS mv_inventory_stockout_streaks;
CREATE MATERIALIZED VIEW mv_inventory_stockout_streaks AS
WITH flagged AS (
    SELECT warehouse_id, product_id, snapshot_date, quantity_on_hand,
           (quantity_on_hand = 0) AS is_stockout,
           snapshot_date - (ROW_NUMBER() OVER (PARTITION BY warehouse_id, product_id, (quantity_on_hand = 0) ORDER BY snapshot_date) * INTERVAL '1 day') AS grp
    FROM supply_chain.inventory_snapshots
)
SELECT warehouse_id, product_id, MIN(snapshot_date) AS streak_start, MAX(snapshot_date) AS streak_end, COUNT(*) AS streak_days
FROM flagged
WHERE is_stockout
GROUP BY warehouse_id, product_id, grp;
CREATE INDEX IF NOT EXISTS ix_mv_inventory_stockout_streaks ON mv_inventory_stockout_streaks(warehouse_id, product_id);
/* Q80. */
DROP MATERIALIZED VIEW IF EXISTS mv_funnel_channel_breakdown;
CREATE MATERIALIZED VIEW mv_funnel_channel_breakdown AS
SELECT device_type, event_type AS stage, COUNT(*) AS event_count
FROM web_events.events e
JOIN web_events.page_views pv ON pv.view_id = e.view_id
GROUP BY device_type, stage;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_funnel_channel_breakdown ON mv_funnel_channel_breakdown(device_type, stage);
/* Q81. */
DROP MATERIALIZED VIEW IF EXISTS mv_cohort_triangle_with_ltv;
CREATE MATERIALIZED VIEW mv_cohort_triangle_with_ltv AS
WITH first_order AS (
    SELECT cust_id, date_trunc('month', MIN(order_date))::date AS cohort_month FROM sales.orders GROUP BY cust_id
),
activity AS (
    SELECT fo.cohort_month, o.cust_id, o.net_total,
           (EXTRACT(YEAR FROM o.order_date) - EXTRACT(YEAR FROM fo.cohort_month)) * 12
             + (EXTRACT(MONTH FROM o.order_date) - EXTRACT(MONTH FROM fo.cohort_month)) AS period_index
    FROM sales.orders o
    JOIN first_order fo ON fo.cust_id = o.cust_id
)
SELECT cohort_month, period_index::int AS period_index, COUNT(DISTINCT cust_id) AS active_customers,
       SUM(net_total) AS period_revenue,
       SUM(SUM(net_total)) OVER (PARTITION BY cohort_month ORDER BY period_index) AS cumulative_revenue
FROM activity
GROUP BY cohort_month, period_index;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_cohort_triangle_with_ltv ON mv_cohort_triangle_with_ltv(cohort_month, period_index);
/* Q82. */
DROP MATERIALIZED VIEW IF EXISTS mv_customer_rfm;
CREATE MATERIALIZED VIEW mv_customer_rfm AS
SELECT cust_id AS customer_id,
       NTILE(5) OVER (ORDER BY MAX(order_date) DESC) AS recency_score,
       NTILE(5) OVER (ORDER BY COUNT(*) DESC) AS frequency_score,
       NTILE(5) OVER (ORDER BY SUM(net_total) DESC) AS monetary_score
FROM sales.orders
GROUP BY cust_id;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_customer_rfm ON mv_customer_rfm(customer_id);

SELECT recency_score, frequency_score, monetary_score, COUNT(*) AS segment_size
FROM mv_customer_rfm
GROUP BY recency_score, frequency_score, monetary_score
ORDER BY segment_size DESC
LIMIT 10;
/* Q83. */
DROP MATERIALIZED VIEW IF EXISTS mv_anomaly_daily;
CREATE MATERIALIZED VIEW mv_anomaly_daily AS
WITH daily AS (
    SELECT r.region_id, r.region_name, o.order_date, SUM(o.net_total) AS revenue
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_id, r.region_name, o.order_date
),
bounds AS (
    SELECT region_id, PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY revenue) AS p95_revenue
    FROM daily
    GROUP BY region_id
)
SELECT dl.region_id, dl.region_name, dl.order_date, dl.revenue, b.p95_revenue
FROM daily dl
JOIN bounds b ON b.region_id = dl.region_id
WHERE dl.revenue > b.p95_revenue;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_anomaly_daily ON mv_anomaly_daily(region_id, order_date);

CREATE OR REPLACE VIEW v_anomaly_alert_payload AS
SELECT region_id, jsonb_build_object(
    'region', region_name, 'date', order_date, 'revenue', revenue, 'p95_threshold', p95_revenue
) AS alert
FROM mv_anomaly_daily;
/* Q84. */
DROP MATERIALIZED VIEW IF EXISTS mv_audit_change_jumps;
CREATE MATERIALIZED VIEW mv_audit_change_jumps AS
SELECT change_id, table_name, column_name, old_value, new_value, changed_by, changed_at
FROM audit.record_changes
WHERE column_name IN ('price', 'net_total', 'amount')
  AND old_value ~ '^[0-9.]+$' AND new_value ~ '^[0-9.]+$'
  AND old_value::numeric > 0
  AND ABS(new_value::numeric - old_value::numeric) / old_value::numeric > 0.5;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_audit_change_jumps ON mv_audit_change_jumps(change_id);

CREATE OR REPLACE VIEW v_audit_compliance_summary AS
SELECT table_name, changed_by AS actor, COUNT(*) AS large_jump_count
FROM mv_audit_change_jumps
GROUP BY table_name, changed_by;
/* Q85. */
DROP MATERIALIZED VIEW IF EXISTS mv_heatmap_weekday_hour;
CREATE MATERIALIZED VIEW mv_heatmap_weekday_hour AS
SELECT EXTRACT(DOW FROM view_timestamp)::int AS weekday, EXTRACT(HOUR FROM view_timestamp)::int AS hour_of_day, COUNT(*) AS view_count,
       ROUND((100.0 * COUNT(*) / SUM(COUNT(*)) OVER ())::numeric, 4) AS pct_of_total
FROM web_events.page_views
GROUP BY 1, 2;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_heatmap_weekday_hour ON mv_heatmap_weekday_hour(weekday, hour_of_day);
/* Q86. */
DROP MATERIALIZED VIEW IF EXISTS mv_growth_metrics;
CREATE MATERIALIZED VIEW mv_growth_metrics AS
WITH monthly AS (
    SELECT r.region_id, r.region_name, date_trunc('month', o.order_date)::date AS month, SUM(o.net_total) AS revenue
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_id, r.region_name, month
)
SELECT region_id, region_name, month, revenue,
       revenue - LAG(revenue) OVER (PARTITION BY region_id ORDER BY month) AS mom_change,
       revenue - LAG(revenue, 12) OVER (PARTITION BY region_id ORDER BY month) AS yoy_change,
       RANK() OVER (PARTITION BY month ORDER BY revenue DESC) AS rank_this_month
FROM monthly;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_growth_metrics ON mv_growth_metrics(region_id, month);
/* Q87. */
CREATE OR REPLACE VIEW v_customer_360_summary_json AS
SELECT customer_id, jsonb_build_object(
    'customer_id', customer_id, 'tier', tier, 'order_count', order_count, 'latest_order_date', latest_order_date
) AS doc
FROM mv_customer_360;
/* Q88. */
DROP MATERIALIZED VIEW IF EXISTS mv_pay_slip_dept_summary;
CREATE MATERIALIZED VIEW mv_pay_slip_dept_summary AS
SELECT d.dept_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ps.net_salary) AS median_net_salary,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY ps.net_salary) AS p95_net_salary
FROM payroll.pay_slips ps
JOIN stores.employees e ON e.employee_id = ps.employee_id
JOIN core.dim_department d ON d.dept_id = e.dept_id
GROUP BY d.dept_name;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_pay_slip_dept_summary ON mv_pay_slip_dept_summary(dept_name);
/* Q89. */
DROP MATERIALIZED VIEW IF EXISTS mv_returns_root_cause;
CREATE MATERIALIZED VIEW mv_returns_root_cause AS
SELECT cat.category_name, r.region_name, COUNT(*) AS return_count,
       ROUND((100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY cat.category_name))::numeric, 2) AS pct_of_category_returns
FROM sales.returns ret
JOIN sales.orders o ON o.order_id = ret.order_id
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
JOIN products.products p ON p.product_id = ret.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
GROUP BY cat.category_name, r.region_name;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_returns_root_cause ON mv_returns_root_cause(category_name, region_name);
/* Q90. */
DROP MATERIALIZED VIEW IF EXISTS mv_dynamic_sla_attainment;
CREATE MATERIALIZED VIEW mv_dynamic_sla_attainment AS
WITH deliv AS (
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
    FROM deliv
    GROUP BY region_id, region_name, yr, quarter
),
targets AS (
    SELECT region_id, region_name, yr, quarter,
           LAG(p90_delivery_days) OVER (PARTITION BY region_id ORDER BY yr, quarter) AS target_p90
    FROM quarter_p90
)
SELECT dv.region_id, dv.region_name, dv.yr::int, dv.quarter::int, t.target_p90,
       ROUND((100.0 * COUNT(*) FILTER (WHERE dv.delivery_days <= t.target_p90) / COUNT(*))::numeric, 2) AS attainment_pct
FROM deliv dv
JOIN targets t ON t.region_id = dv.region_id AND t.yr = dv.yr AND t.quarter = dv.quarter
WHERE t.target_p90 IS NOT NULL
GROUP BY dv.region_id, dv.region_name, dv.yr, dv.quarter, t.target_p90;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_dynamic_sla_attainment ON mv_dynamic_sla_attainment(region_id, yr, quarter);
/* Q91. */
/* Real-time-ish ops board (concept): serve the bulk of the board from an hourly-refreshed MV (e.g. mv_anomaly_alerts / mv_delivery_sla) for the historical view, UNIONed with a small live query scoped to just "since the MV's last refresh" (e.g. WHERE order_date >= (SELECT MAX(d) FROM the MV) or a rolling 15-minute window) - the live tail is cheap because it only scans a tiny recent slice, giving near-real-time freshness without paying the MV's full refresh cost on every page load. */
/* Q92. */
CREATE OR REPLACE VIEW v_region_orders_south AS
SELECT o.* FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
WHERE r.region_name = 'South';

CREATE OR REPLACE VIEW v_region_orders_north AS
SELECT o.* FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
WHERE r.region_name = 'North';
/* Q93. */
CREATE OR REPLACE VIEW v_exec_region_strip_v2 AS
SELECT r.region_name, COUNT(*) AS orders,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_aov,
       PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY o.net_total) AS p99_aov,
       MAX(o.order_date) AS latest_order_date
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name;
COMMENT ON VIEW v_exec_region_strip_v2 IS 'v2: adds p99_aov. Deprecation: v_exec_region_strip (v1) will be dropped once v1 query traffic reaches zero.';
-- v1 stays live and unchanged until deprecation completes.
/* Q94. */
SELECT 'mv_exec_strip' AS mv_name, (SELECT SUM(orders) FROM mv_exec_strip) AS mv_total, (SELECT COUNT(*) FROM sales.orders) AS live_total
UNION ALL
SELECT 'mv_delivery_sla', (SELECT COUNT(*) FROM mv_delivery_sla), (SELECT COUNT(DISTINCT r.region_id) FROM stores.stores s JOIN core.dim_region r ON r.region_id = s.region_id)
UNION ALL
SELECT 'mv_growth_metrics', (SELECT COUNT(*) FROM mv_growth_metrics), NULL;
/* Q95. */
SELECT c.relname AS mv_name, pg_size_pretty(pg_total_relation_size(c.oid)) AS size,
       (SELECT COUNT(*) FROM pg_depend d JOIN pg_rewrite rw ON rw.oid = d.objid JOIN pg_class dep ON dep.oid = rw.ev_class WHERE d.refobjid = c.oid AND dep.relname <> c.relname) AS dependent_count
FROM pg_class c
WHERE c.relkind = 'm'
ORDER BY c.relname;
/* Q96. */
CREATE OR REPLACE VIEW v_catalog_api_pricing_promo AS
SELECT pc.prod_id AS product_id, jsonb_build_object(
    'product_id', pc.prod_id,
    'corridor', jsonb_build_object('p25', pc.p25_price, 'p75', pc.p75_price),
    'latest_price', pc.latest_price,
    'active_promos', (SELECT jsonb_agg(jsonb_build_object('promo_name', pr.promo_name, 'discount_percent', pr.discount_percent))
                       FROM products.promotions pr WHERE pr.active)
) AS doc
FROM mv_pricing_corridor pc;
/* Q97. */
CREATE OR REPLACE VIEW v_region_dashboard_json AS
SELECT region_id, jsonb_build_object(
    'region', region_name, 'orders', orders, 'median_aov', median_aov, 'p95_aov', p95_aov,
    'churn_risk_count', churn_risk_count, 'rank', rnk
) AS doc
FROM mv_exec_strip;
/* Q98. */
CREATE OR REPLACE VIEW v_lifecycle_stage_monthly AS
WITH cust_orders AS (
    SELECT cust_id, order_date, ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date) AS order_seq
    FROM sales.orders
)
SELECT cust_id, date_trunc('month', order_date)::date AS month,
       CASE WHEN order_seq = 1 THEN 'new' ELSE 'returning' END AS lifecycle_stage
FROM cust_orders;
/* Q99. */
DROP VIEW IF EXISTS v_exec_region_strip_json CASCADE;
DROP VIEW IF EXISTS v_exec_region_strip CASCADE;
DROP VIEW IF EXISTS v_mart_revenue_by_region_month CASCADE;
DROP VIEW IF EXISTS v_core_orders CASCADE;
DROP VIEW IF EXISTS v_raw_orders CASCADE;
CREATE OR REPLACE VIEW v_raw_orders AS
SELECT order_id, cust_id, store_id, order_date, order_status, net_total, payment_mode_id FROM sales.orders;
CREATE OR REPLACE VIEW v_core_orders AS
SELECT order_id, cust_id, store_id, order_date, INITCAP(TRIM(order_status)) AS order_status, net_total
FROM v_raw_orders
WHERE order_status <> 'Failed';
CREATE OR REPLACE VIEW v_mart_revenue_by_region_month AS
SELECT r.region_name, date_trunc('month', o.order_date)::date AS month, SUM(o.net_total) AS revenue, COUNT(*) AS order_count
FROM v_core_orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name, month;
CREATE OR REPLACE VIEW v_exec_region_strip AS
SELECT r.region_name, COUNT(*) AS orders,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_aov,
       MAX(o.order_date) AS latest_order_date
FROM v_core_orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name;
CREATE OR REPLACE VIEW v_exec_region_strip_json AS
SELECT region_name, jsonb_build_object('region', region_name, 'orders', orders, 'median_aov', median_aov, 'p95_aov', p95_aov) AS doc
FROM v_exec_region_strip;
-- end-to-end script: raw -> core -> mart -> exec -> JSON export, every statement CREATE OR REPLACE VIEW so it's fully re-runnable.
/* Q100. */
DROP MATERIALIZED VIEW IF EXISTS mv_exec_strip CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_customer_360 CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_anomaly_alerts CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_funnel_stage_hourly CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_pricing_corridor CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_delivery_sla CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_ticket_sla CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_inventory_value CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_inventory_stockout_streaks CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_funnel_channel_breakdown CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_cohort_triangle_with_ltv CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_customer_rfm CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_anomaly_daily CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_audit_change_jumps CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_heatmap_weekday_hour CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_growth_metrics CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_pay_slip_dept_summary CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_returns_root_cause CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_dynamic_sla_attainment CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_daily_revenue_90d CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_revenue_daily CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_revenue_weekly CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_revenue_monthly CASCADE;

DROP VIEW IF EXISTS v_exec_region_strip_json CASCADE;
DROP VIEW IF EXISTS v_lifecycle_stage_monthly CASCADE;
DROP VIEW IF EXISTS v_region_dashboard_json CASCADE;
DROP VIEW IF EXISTS v_catalog_api_pricing_promo CASCADE;
DROP VIEW IF EXISTS v_exec_region_strip_v2 CASCADE;
DROP VIEW IF EXISTS v_region_orders_north CASCADE;
DROP VIEW IF EXISTS v_region_orders_south CASCADE;
DROP VIEW IF EXISTS v_audit_compliance_summary CASCADE;
DROP VIEW IF EXISTS v_anomaly_alert_payload CASCADE;
DROP VIEW IF EXISTS v_customer_360_summary_json CASCADE;
DROP VIEW IF EXISTS v_pricing_drift_alerts CASCADE;
DROP VIEW IF EXISTS v_daily_revenue_hybrid CASCADE;
DROP VIEW IF EXISTS v_mart_heatmap_device CASCADE;
DROP VIEW IF EXISTS v_mart_reactivation CASCADE;
DROP VIEW IF EXISTS v_mart_lifecycle_stage CASCADE;
DROP VIEW IF EXISTS v_mart_customer_360_relational CASCADE;
DROP VIEW IF EXISTS v_mart_pricing_corridor_json CASCADE;
DROP VIEW IF EXISTS v_mart_funnel_per_channel_hour CASCADE;
DROP VIEW IF EXISTS v_mart_time_series CASCADE;
DROP VIEW IF EXISTS v_mart_region_strip_json CASCADE;
DROP VIEW IF EXISTS v_mart_anomaly CASCADE;
DROP VIEW IF EXISTS v_mart_multi_grain_revenue CASCADE;
DROP VIEW IF EXISTS v_mart_region_rollup CASCADE;
DROP VIEW IF EXISTS v_mart_audit CASCADE;
DROP VIEW IF EXISTS v_mart_rfm CASCADE;
DROP VIEW IF EXISTS v_mart_cohort CASCADE;
DROP VIEW IF EXISTS v_mart_pricing CASCADE;
DROP VIEW IF EXISTS v_mart_sla CASCADE;
DROP VIEW IF EXISTS v_mart_web_heatmap CASCADE;
DROP VIEW IF EXISTS v_mart_web_funnel CASCADE;
DROP VIEW IF EXISTS v_mart_web_sessions CASCADE;
DROP VIEW IF EXISTS v_mart_inventory CASCADE;
DROP VIEW IF EXISTS v_mart_product CASCADE;
DROP VIEW IF EXISTS v_mart_customer_cross_domain CASCADE;
DROP VIEW IF EXISTS v_exec_region_strip CASCADE;
DROP VIEW IF EXISTS v_mart_customer_lifetime CASCADE;
DROP VIEW IF EXISTS v_mart_revenue_by_region_month CASCADE;
DROP VIEW IF EXISTS v_core_products CASCADE;
DROP VIEW IF EXISTS v_core_customers CASCADE;
DROP VIEW IF EXISTS v_core_orders CASCADE;
DROP VIEW IF EXISTS v_raw_regions CASCADE;
DROP VIEW IF EXISTS v_raw_stores CASCADE;
DROP VIEW IF EXISTS v_raw_products CASCADE;
DROP VIEW IF EXISTS v_raw_customers CASCADE;
DROP VIEW IF EXISTS v_raw_orders CASCADE;
-- capstone: the drop-all above plus Sections B/C's own CREATE OR REPLACE / DROP IF EXISTS statements together form the idempotent, dependency-safe recreate script for the full raw/core/mart/exec + MV refresh DAG, with unique indexes, CONCURRENTLY-eligible refreshes, reconciliation (Q66/Q94) and JSON exports (Q76/Q87/Q96/Q97) all documented via COMMENT ON where shown above.

/* ============================================================
   END OF ANSWER KEY - CRAZY LEVEL (100/100)
============================================================ */
