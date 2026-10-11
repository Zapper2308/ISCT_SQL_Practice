/* ============================================================
   ANSWER KEY - Views & Materialized Views (HARD LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1. At scale, "raw" is a thin renamed passthrough (decouples consumers from source schema churn), "cleaned" absorbs every data-quality fix (types, trims, status filters, dedup) in exactly one place so it's fixed once, and "metrics" is the only layer allowed to aggregate/join across domains into the numbers dashboards actually read - each layer owns one responsibility so a bug or a schema change is isolated to a single layer to fix. */
/* Q2. The planner cannot push a predicate through a view when the view itself contains an aggregate, DISTINCT, LIMIT/OFFSET, a set operation (UNION/EXCEPT), or a window function - in those cases the view boundary becomes an optimization fence and the outer WHERE is applied only after the view's own result is fully computed, not pushed down into its base-table scan. */
/* Q3. Materialize when the same expensive computation is read far more often than the source data changes (query:write ratio high, staleness tolerable); keep it a live view when freshness must be exact on every read, the underlying query is cheap, or the audience is small/ad-hoc enough that paying live cost each time is fine. */
/* Q4. REFRESH CONCURRENTLY needs a UNIQUE INDEX covering all rows (no partial WHERE) so Postgres can compute an old-vs-new row diff instead of an exclusive-lock swap; at scale this diff itself costs CPU/IO proportional to the MV's size, so a very large MV can still have a slow (though non-blocking) concurrent refresh, and the unique index adds ongoing write overhead on every refresh's insert/delete pass. */
/* Q5. Refresh choreography for a DAG of MVs means topologically sorting the MVs by their read-dependencies (an MV built from another MV can only refresh after its source MV is done) and running each level of the DAG only once every MV it depends on has completed - independent branches of the DAG can refresh in parallel, but no MV may start before all of its upstream MVs finish. */
/* Q6. MV indexing at scale: one UNIQUE INDEX on the natural key (required for CONCURRENTLY, also the fastest point-lookup path), one or more secondary range indexes on frequently-filtered columns (a date column, a status), and expression indexes when queries filter on a computed value (e.g. EXTRACT(year FROM ...)) rather than a raw stored column. */
/* Q7. On an MV-backed dashboard query, EXPLAIN ANALYZE should show a direct Index Scan or Index-Only Scan against the MV's own storage with near-zero rows examined beyond what's returned - any sign of a Seq Scan on a large MV, or (worse) the original base-table joins re-appearing in the plan, means the query bypassed the MV or the MV lacks the index the query needs. */
/* Q8. Mitigate DROP CASCADE blast radius by always running the pg_depend/pg_class dependency query first to get the full list of everything that would cascade-drop, reviewing that list against a known-safe set, and preferring targeted DROP of each listed dependent (or CREATE OR REPLACE where the shape allows it) over a blind CASCADE in production. */
/* Q9. Backward-compatible view evolution creates v_thing_v2 with the new shape alongside the existing v_thing (v1), migrates consumers to v2 on their own schedule, monitors (via pg_stat_user_tables or query logs) until v1 shows no more traffic, then drops v1 - so no single deploy simultaneously changes the contract for every consumer. */
/* Q10. Stale-data SLAs are set by how a consumer decides with the number: a real-time fraud check needs near-zero staleness (live view or very frequent refresh), an intraday ops board needs hourly, and a monthly exec report tolerates a full day - map each consumer's decision cadence to the MV's refresh interval, don't pick one global cadence for every MV. */
/* Q11. A hybrid live view UNIONs a materialized historical MV (e.g. mv_daily_revenue up through yesterday) with a live aggregate over just the last N minutes/hours from the base table - giving near-real-time freshness for the recent tail while the bulk of the historical data stays cheap to read from the MV. */
/* Q12. Multi-grain MVs (day, week, month) must each independently aggregate from the same base table (not roll one up from another, which would double-apply any rounding/definition drift) and a reconciliation query (SUM of daily = the matching week/month total) should be run after every refresh to catch any definitional inconsistency between grains. */
/* Q13. A partial MV filters its defining query to only the "hot" subset actually queried live (e.g. WHERE order_date >= CURRENT_DATE - 90) so both the refresh cost and the index size stay small, at the cost of not serving historical queries beyond the window - those fall back to a separate full-history MV or the base table. */
/* Q14. View security & search_path at scale means every view should reference base tables with explicit schema qualification (never relying on search_path resolution) and views intended to expose only summarized/derived data should live in a schema whose grants are managed separately from the raw source schemas, so a consumer can be granted SELECT on the view without ever getting direct table access. */
/* Q15. Deeply nested views force the planner to re-inline and re-plan the whole expanded query tree on every execution; past a few layers, planning time grows and the planner's join-order search can degrade into a worse plan than if an intermediate layer had simply been materialized - the fix is flattening logic or materializing a mid-stack MV. */
/* Q16. True row-level incremental MV refresh isn't natively supported in Postgres - REFRESH always recomputes the whole defining query; the practical incremental strategy is a partial/windowed MV (only refresh the most recent N days' worth by re-running the query with a narrower date filter into a staging table, then swap) rather than a full-table recompute every time. */
/* Q17. Chunked rebuild for a huge percentile MV: partition the aggregation by a natural key (e.g. region or month), compute PERCENTILE_CONT for one chunk at a time into a staging table via repeated INSERT, and only swap/rename the staging table into place once every chunk has completed - avoiding one single enormous sort/group operation that could exceed work_mem or run for a very long time uninterruptibly. */
/* Q18. Ship a JSON-export MV when an external API/consumer needs a stable, pre-shaped payload (nested objects/arrays) served with minimal per-request compute, and that payload doesn't need per-request freshness - the MV pre-builds the JSON once per refresh instead of running json_build_object/jsonb_agg on every API call. */
/* Q19. A wide/pivot MV (one row per key, fixed named columns per category) is easy for a BI tool to consume directly but its schema must change (ALTER/rebuild) whenever the category set changes; a long MV (one row per key+category) has a stable schema regardless of how many categories exist and is easier to aggregate/filter, converting to a pivot shape only at the final presentation layer. */
/* Q20. Validation-as-contract means every MV should have a companion assertion query (its own total vs. the equivalent live aggregate over the base tables) run after each refresh; a mismatch beyond a tiny rounding tolerance should fail the refresh job/alert an operator, catching a silent definitional drift between the MV's SQL and the source of truth before a dashboard shows a wrong number. */
/* Q21. Per-MV documentation (via COMMENT ON MATERIALIZED VIEW) should record: owner/team, grain (one row per what), refresh cadence, and known dependents (what reads from it) - so anyone touching the base tables or considering dropping the MV can immediately see who and what would be affected without archaeology. */
/* Q22. Consistent naming/namespacing (raw_/clean_/v_ for views, mv_ for materialized views) at a glance tells a reader whether an object is live or a snapshot and roughly where in the stack it sits - stack hygiene also means capping nesting depth and not letting a "mv_" object secretly be built from another "mv_" without that being obvious from naming or documentation. */
/* Q23. Every REFRESH replaces the MV's data but its indexes survive a plain REFRESH (only CONCURRENTLY's diff-based approach touches index rows incrementally too) - for very large MVs with several indexes, DROP INDEX before a non-concurrent REFRESH and recreate afterward can be faster than maintaining the indexes row-by-row during the bulk rewrite, at the cost of the MV being unindexed (and reads correspondingly slow) during that window. */
/* Q24. Multi-tenant view layering filters each tenant-facing view by the tenant/region key (e.g. v_region_orders_south AS SELECT ... WHERE region_name = 'South', or better a parameterized security-barrier view combined with row-level security) so each tenant only ever sees their own slice, with the filter enforced once in the view rather than trusted to every downstream query. */
/* Q25. Don't materialize small tables (a handful of rows, cheap to scan directly), cheap queries (no expensive join/aggregate to amortize), or highly volatile data where the MV would be stale again almost immediately after every refresh - in all three cases the operational overhead of scheduling and monitoring a refresh outweighs any query-time savings. */

/* ============================================================
   SECTION B: PRODUCTION VIEW STACKS (25)
   ------------------------------------------------------------ */
/* Q26. */
CREATE OR REPLACE VIEW v_orders_raw AS
SELECT order_id, cust_id, store_id, order_date, order_status, net_total, payment_mode_id
FROM sales.orders;

CREATE OR REPLACE VIEW v_orders_clean AS
SELECT order_id, cust_id, store_id, order_date, INITCAP(TRIM(order_status)) AS order_status, net_total
FROM v_orders_raw
WHERE order_status <> 'Failed';

CREATE OR REPLACE VIEW v_orders_enriched AS
SELECT oc.order_id, oc.order_date, oc.order_status, oc.net_total,
       c.customer_id, c.first_name || ' ' || c.last_name AS customer_name,
       s.store_id, s.store_name, r.region_name
FROM v_orders_clean oc
JOIN customers.customers c ON c.customer_id = oc.cust_id
JOIN stores.stores s ON s.store_id = oc.store_id
JOIN core.dim_region r ON r.region_id = s.region_id;

CREATE OR REPLACE VIEW v_orders_metrics AS
SELECT region_name, date_trunc('month', order_date)::date AS month, SUM(net_total) AS revenue, COUNT(*) AS order_count
FROM v_orders_enriched
GROUP BY region_name, month;
/* Q27. */
CREATE OR REPLACE VIEW v_customers_raw AS
SELECT customer_id, first_name, last_name, email, tier, registration_date FROM customers.customers;

CREATE OR REPLACE VIEW v_customers_clean AS
SELECT cr.customer_id, cr.first_name || ' ' || cr.last_name AS full_name, cr.tier, cr.registration_date,
       (SELECT a.city FROM customers.addresses a WHERE a.customer_id = cr.customer_id ORDER BY a.is_default DESC NULLS LAST, a.address_id DESC LIMIT 1) AS primary_city
FROM v_customers_raw cr;

CREATE OR REPLACE VIEW v_customers_enriched AS
SELECT cc.customer_id, cc.full_name, cc.tier, cc.primary_city, lo.order_id AS latest_order_id, lo.order_date AS latest_order_date
FROM v_customers_clean cc
LEFT JOIN (
    SELECT DISTINCT ON (cust_id) cust_id, order_id, order_date FROM sales.orders ORDER BY cust_id, order_date DESC
) lo ON lo.cust_id = cc.customer_id;
/* Q28. */
CREATE OR REPLACE VIEW v_products_raw AS
SELECT product_id, product_name, brand_id, supplier_id, price, cost_price FROM products.products;

CREATE OR REPLACE VIEW v_products_clean AS
SELECT product_id, TRIM(product_name) AS product_name, brand_id, supplier_id, price, cost_price
FROM v_products_raw
WHERE price IS NOT NULL;

CREATE OR REPLACE VIEW v_products_enriched AS
SELECT pc.product_id, pc.product_name, pc.price, pc.cost_price, b.brand_name, cat.category_name,
       EXISTS (SELECT 1 FROM products.promotions pr WHERE pr.active AND pr.start_date <= CURRENT_DATE AND pr.end_date >= CURRENT_DATE) AS has_active_promo_context
FROM v_products_clean pc
JOIN core.dim_brand b ON b.brand_id = pc.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id;
/* Q29. */
CREATE OR REPLACE VIEW v_inventory_raw AS
SELECT warehouse_id, product_id, snapshot_date, quantity_on_hand FROM supply_chain.inventory_snapshots;

CREATE OR REPLACE VIEW v_inventory_latest AS
SELECT DISTINCT ON (warehouse_id, product_id) warehouse_id, product_id, snapshot_date, quantity_on_hand
FROM v_inventory_raw
ORDER BY warehouse_id, product_id, snapshot_date DESC;

CREATE OR REPLACE VIEW v_inventory_value AS
SELECT il.warehouse_id, SUM(il.quantity_on_hand * p.cost_price) AS inventory_value
FROM v_inventory_latest il
JOIN products.products p ON p.product_id = il.product_id
GROUP BY il.warehouse_id;
/* Q30. */
CREATE OR REPLACE VIEW v_tickets_raw AS
SELECT ticket_id, customer_id, agent_id, priority, status, created_date, resolved_date FROM support.tickets;

CREATE OR REPLACE VIEW v_tickets_clean AS
SELECT * FROM v_tickets_raw WHERE priority IS NOT NULL;

CREATE OR REPLACE VIEW v_ticket_sla AS
SELECT priority,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600.0) AS median_hours,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600.0) AS p95_hours
FROM v_tickets_clean
WHERE resolved_date IS NOT NULL
GROUP BY priority;
/* Q31. */
CREATE OR REPLACE VIEW v_pay_slip_raw AS
SELECT pay_slip_id, employee_id, salary_month, salary_year, net_salary FROM payroll.pay_slips;

CREATE OR REPLACE VIEW v_pay_slip_clean AS
SELECT pay_slip_id, employee_id, to_date(salary_month || ' ' || salary_year, 'FMMonth YYYY') AS period, net_salary
FROM v_pay_slip_raw;

CREATE OR REPLACE VIEW v_pay_slip_summary AS
SELECT d.dept_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ps.net_salary) AS median_net_salary,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY ps.net_salary) AS p95_net_salary
FROM v_pay_slip_clean ps
JOIN stores.employees e ON e.employee_id = ps.employee_id
JOIN core.dim_department d ON d.dept_id = e.dept_id
GROUP BY d.dept_name;
/* Q32. */
CREATE OR REPLACE VIEW v_returns_enriched AS
SELECT r.return_id, r.order_id, r.refund_amount, r.reason, o.cust_id, c.first_name, c.last_name, c.tier
FROM sales.returns r
JOIN sales.orders o ON o.order_id = r.order_id
JOIN customers.customers c ON c.customer_id = o.cust_id;

CREATE OR REPLACE VIEW v_returns_metrics_by_category AS
SELECT cat.category_name, COUNT(*) AS return_count, SUM(r.refund_amount) AS total_refund
FROM sales.returns r
JOIN products.products p ON p.product_id = r.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
GROUP BY cat.category_name;
/* Q33. */
CREATE OR REPLACE VIEW v_audit_raw AS
SELECT change_id, table_name, record_id, column_name, old_value, new_value, changed_by, changed_at, action
FROM audit.record_changes;

CREATE OR REPLACE VIEW v_audit_typed AS
SELECT change_id, table_name, record_id, column_name,
       NULLIF(old_value, '')::text AS old_value, NULLIF(new_value, '')::text AS new_value,
       changed_by, changed_at, action
FROM v_audit_raw;

CREATE OR REPLACE VIEW v_audit_change_summary AS
SELECT table_name, action, COUNT(*) AS change_count, COUNT(DISTINCT changed_by) AS distinct_actors
FROM v_audit_typed
GROUP BY table_name, action;
/* Q34. */
CREATE OR REPLACE VIEW v_page_views_raw AS
SELECT view_id, session_id, customer_id, page_url, view_timestamp, device_type, os FROM web_events.page_views;

CREATE OR REPLACE VIEW v_page_views_clean AS
SELECT * FROM v_page_views_raw WHERE session_id IS NOT NULL;

CREATE OR REPLACE VIEW v_page_views_hourly AS
SELECT EXTRACT(HOUR FROM view_timestamp)::int AS hour_of_day, device_type, COUNT(*) AS page_views
FROM v_page_views_clean
GROUP BY 1, 2;
/* Q35. */
CREATE OR REPLACE VIEW v_calls_enriched AS
SELECT c.call_id, c.agent_id, c.customer_id, c.call_duration_seconds, c.call_start_time, d.dept_name
FROM call_center.calls c
JOIN stores.employees e ON e.employee_id = c.agent_id
JOIN core.dim_department d ON d.dept_id = e.dept_id;

CREATE OR REPLACE VIEW v_calls_sla_hourly AS
SELECT EXTRACT(HOUR FROM call_start_time)::int AS hour_of_day, dept_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY call_duration_seconds) AS median_duration_sec,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY call_duration_seconds) AS p95_duration_sec
FROM v_calls_enriched
GROUP BY 1, 2;
/* Q36. */
CREATE OR REPLACE VIEW v_orders_with_customer AS
SELECT oc.order_id, oc.order_date, oc.order_status, oc.net_total, cc.customer_id, cc.full_name, cc.tier
FROM v_orders_clean oc
JOIN v_customers_clean cc ON cc.customer_id = oc.cust_id;
/* Q37. */
CREATE OR REPLACE VIEW v_orders_with_payment AS
SELECT o.order_id, o.order_date, o.net_total, lp.status AS latest_payment_status, lp.amount AS latest_payment_amount
FROM sales.orders o
LEFT JOIN LATERAL (
    SELECT status, amount FROM finance.payments p WHERE p.order_id = o.order_id ORDER BY p.payment_id DESC LIMIT 1
) lp ON TRUE;
/* Q38. */
CREATE OR REPLACE VIEW v_orders_with_delivery AS
SELECT o.order_id, o.order_date, sh.shipped_date, sh.delivered_date,
       (sh.shipped_date - o.order_date) AS days_to_ship,
       (sh.delivered_date - sh.shipped_date) AS days_ship_to_deliver,
       (sh.delivered_date - o.order_date) AS total_delivery_days
FROM sales.orders o
JOIN sales.shipments sh ON sh.order_id = o.order_id;
/* Q39. */
CREATE OR REPLACE VIEW v_returns_tier_metrics AS
SELECT c.tier, COUNT(*) AS return_count, SUM(r.refund_amount) AS total_refund,
       ROUND(AVG(r.refund_amount), 2) AS avg_refund
FROM sales.returns r
JOIN sales.orders o ON o.order_id = r.order_id
JOIN customers.customers c ON c.customer_id = o.cust_id
GROUP BY c.tier;
/* Q40. */
CREATE OR REPLACE VIEW v_region_quarter_rollup AS
SELECT r.region_name, date_trunc('quarter', o.order_date)::date AS quarter, SUM(o.net_total) AS revenue, COUNT(*) AS order_count
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name, quarter;
/* Q41. */
CREATE OR REPLACE VIEW v_region_aov_percentiles AS
SELECT region_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total) AS median_aov,
       PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY net_total) AS p90_aov,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY net_total) AS p95_aov
FROM v_orders_enriched
GROUP BY region_name;
/* Q42. */
CREATE OR REPLACE VIEW v_top_customers_per_region AS
SELECT region_name, customer_id, total_spend, rnk
FROM (
    SELECT r.region_name, o.cust_id AS customer_id, SUM(o.net_total) AS total_spend,
           RANK() OVER (PARTITION BY r.region_name ORDER BY SUM(o.net_total) DESC) AS rnk
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_name, o.cust_id
) ranked
WHERE rnk <= 10;
/* Q43. */
CREATE OR REPLACE VIEW v_cohort_period AS
WITH first_order AS (
    SELECT cust_id, date_trunc('month', MIN(order_date))::date AS cohort_month FROM sales.orders GROUP BY cust_id
)
SELECT fo.cohort_month, o.cust_id,
       (EXTRACT(YEAR FROM o.order_date) - EXTRACT(YEAR FROM fo.cohort_month)) * 12
         + (EXTRACT(MONTH FROM o.order_date) - EXTRACT(MONTH FROM fo.cohort_month)) AS period_index
FROM sales.orders o
JOIN first_order fo ON fo.cust_id = o.cust_id;
/* Q44. */
CREATE OR REPLACE VIEW v_customer_rfm AS
SELECT cust_id,
       NTILE(5) OVER (ORDER BY MAX(order_date) DESC) AS recency_score,
       NTILE(5) OVER (ORDER BY COUNT(*) DESC) AS frequency_score,
       NTILE(5) OVER (ORDER BY SUM(net_total) DESC) AS monetary_score
FROM sales.orders
GROUP BY cust_id;
/* Q45. */
CREATE OR REPLACE VIEW v_customer_360 AS
SELECT c.customer_id, c.first_name || ' ' || c.last_name AS full_name,
       ARRAY(SELECT order_id FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY o.order_date DESC LIMIT 5) AS recent_order_ids,
       ARRAY(SELECT review_id FROM customers.reviews rv WHERE rv.customer_id = c.customer_id ORDER BY rv.review_date DESC LIMIT 5) AS recent_review_ids,
       ARRAY(SELECT ticket_id FROM support.tickets t WHERE t.customer_id = c.customer_id ORDER BY t.created_date DESC LIMIT 5) AS recent_ticket_ids
FROM customers.customers c;
/* Q46. */
CREATE OR REPLACE VIEW v_anomaly_daily AS
WITH daily AS (
    SELECT order_date, SUM(net_total) AS revenue FROM sales.orders GROUP BY order_date
),
bounds AS (
    SELECT PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY revenue) AS p95_revenue FROM daily
)
SELECT d.order_date, d.revenue, b.p95_revenue
FROM daily d, bounds b
WHERE d.revenue > b.p95_revenue;
/* Q47. */
CREATE OR REPLACE VIEW v_funnel_stage_counts AS
WITH stages AS (
    SELECT 'page_view' AS stage, COUNT(DISTINCT view_id) AS event_count, 1 AS stage_order FROM web_events.page_views
    UNION ALL
    SELECT event_type, COUNT(*), 2 FROM web_events.events GROUP BY event_type
)
SELECT stage, event_count, stage_order,
       ROUND((100.0 * event_count / FIRST_VALUE(event_count) OVER (ORDER BY stage_order))::numeric, 2) AS pct_of_first_stage
FROM stages;
/* Q48. */
CREATE OR REPLACE VIEW v_pricing_corridor AS
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
SELECT l.product_id, b.p25_price, b.p75_price, l.latest_price
FROM latest l
JOIN band b ON b.prod_id = l.product_id;
/* Q49. */
CREATE OR REPLACE VIEW v_sales_trend_region AS
WITH monthly AS (
    SELECT r.region_name, date_trunc('month', o.order_date)::date AS month, SUM(o.net_total) AS revenue
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_name, month
)
SELECT region_name, month, revenue,
       revenue - LAG(revenue) OVER (PARTITION BY region_name ORDER BY month) AS mom_change,
       revenue - LAG(revenue, 12) OVER (PARTITION BY region_name ORDER BY month) AS yoy_change
FROM monthly;
/* Q50. */
CREATE OR REPLACE VIEW v_exec_metrics AS
SELECT rd.region_name, rd.median_aov, rd.p95_aov, tc.customer_id AS top_customer_id, tc.total_spend AS top_customer_spend
FROM v_region_aov_percentiles rd
LEFT JOIN v_top_customers_per_region tc ON tc.region_name = rd.region_name AND tc.rnk = 1;

/* ============================================================
   SECTION C: MV REFRESH CHOREOGRAPHY (25)
   ------------------------------------------------------------ */
/* Q51. */
DROP MATERIALIZED VIEW IF EXISTS mv_orders_metrics;
CREATE MATERIALIZED VIEW mv_orders_metrics AS
SELECT r.region_id, r.region_name, date_trunc('month', o.order_date)::date AS month, SUM(o.net_total) AS revenue, COUNT(*) AS order_count
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
WHERE o.order_status <> 'Failed'
GROUP BY r.region_id, r.region_name, month;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_orders_metrics ON mv_orders_metrics(region_id, month);
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_orders_metrics;
/* Q52. */
DROP MATERIALIZED VIEW IF EXISTS mv_revenue_by_region_month;
CREATE MATERIALIZED VIEW mv_revenue_by_region_month AS
SELECT r.region_id, r.region_name, date_trunc('month', o.order_date)::date AS month, SUM(o.net_total) AS revenue
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_id, r.region_name, month;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_revenue_by_region_month ON mv_revenue_by_region_month(region_id, month);
CREATE INDEX IF NOT EXISTS ix_mv_revenue_by_region_month_range ON mv_revenue_by_region_month(month);
/* Q53. */
DROP MATERIALIZED VIEW IF EXISTS mv_customer_lifetime;
CREATE MATERIALIZED VIEW mv_customer_lifetime AS
WITH latest_region AS (
    SELECT DISTINCT ON (o.cust_id) o.cust_id, s.region_id
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    ORDER BY o.cust_id, o.order_date DESC
)
SELECT o.cust_id AS customer_id, c.tier, lr.region_id, COUNT(*) AS total_orders, SUM(o.net_total) AS total_revenue, MAX(o.order_date) AS latest_order
FROM sales.orders o
JOIN customers.customers c ON c.customer_id = o.cust_id
JOIN latest_region lr ON lr.cust_id = o.cust_id
GROUP BY o.cust_id, c.tier, lr.region_id;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_customer_lifetime ON mv_customer_lifetime(customer_id);
CREATE INDEX IF NOT EXISTS ix_mv_customer_lifetime_tier ON mv_customer_lifetime(tier);
CREATE INDEX IF NOT EXISTS ix_mv_customer_lifetime_region ON mv_customer_lifetime(region_id);
/* Q54. */
DROP MATERIALIZED VIEW IF EXISTS mv_store_kpis;
CREATE MATERIALIZED VIEW mv_store_kpis AS
SELECT store_id, date_trunc('month', order_date)::date AS month, SUM(net_total) AS revenue, COUNT(*) AS order_count
FROM sales.orders
GROUP BY store_id, 2;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_store_kpis ON mv_store_kpis(store_id, month);
COMMENT ON MATERIALIZED VIEW mv_store_kpis IS 'Refresh cadence: daily 02:00 UTC. Grain: one row per store per month.';
/* Q55. */
DROP MATERIALIZED VIEW IF EXISTS mv_ticket_sla;
CREATE MATERIALIZED VIEW mv_ticket_sla AS
SELECT priority,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600.0) AS median_hours,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600.0) AS p95_hours
FROM support.tickets
WHERE resolved_date IS NOT NULL
GROUP BY priority;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_ticket_sla ON mv_ticket_sla(priority);
EXPLAIN ANALYZE SELECT * FROM mv_ticket_sla WHERE priority = 'High';
/* Q56. */
DROP MATERIALIZED VIEW IF EXISTS mv_daily_revenue;
CREATE MATERIALIZED VIEW mv_daily_revenue AS
SELECT d.day::date AS d, COALESCE(SUM(o.net_total), 0) AS revenue
FROM generate_series((SELECT MIN(order_date) FROM sales.orders), (SELECT MAX(order_date) FROM sales.orders), INTERVAL '1 day') AS d(day)
LEFT JOIN sales.orders o ON o.order_date = d.day::date
GROUP BY d.day;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_daily_revenue ON mv_daily_revenue(d);
EXPLAIN ANALYZE SELECT * FROM mv_daily_revenue WHERE d = '2025-06-01';
/* Q57. */
DROP MATERIALIZED VIEW IF EXISTS mv_inventory_latest;
CREATE MATERIALIZED VIEW mv_inventory_latest AS
SELECT DISTINCT ON (warehouse_id, product_id) warehouse_id, product_id, snapshot_date, quantity_on_hand
FROM supply_chain.inventory_snapshots
ORDER BY warehouse_id, product_id, snapshot_date DESC;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_inventory_latest ON mv_inventory_latest(warehouse_id, product_id);
/* Q58. */
DROP MATERIALIZED VIEW IF EXISTS mv_top_customers_per_region;
CREATE MATERIALIZED VIEW mv_top_customers_per_region AS
SELECT region_name, customer_id, total_spend, rnk
FROM (
    SELECT r.region_name, o.cust_id AS customer_id, SUM(o.net_total) AS total_spend,
           RANK() OVER (PARTITION BY r.region_name ORDER BY SUM(o.net_total) DESC) AS rnk
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_name, o.cust_id
) ranked
WHERE rnk <= 10;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_top_customers_per_region ON mv_top_customers_per_region(region_name, customer_id);
/* Q59. */
DROP MATERIALIZED VIEW IF EXISTS mv_region_percentiles;
CREATE MATERIALIZED VIEW mv_region_percentiles AS
SELECT r.region_id, r.region_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov,
       PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY o.net_total) AS p90_aov,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_aov
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_id, r.region_name;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_region_percentiles ON mv_region_percentiles(region_id);
/* Q60. */
DROP MATERIALIZED VIEW IF EXISTS mv_region_x_month_revenue;
CREATE MATERIALIZED VIEW mv_region_x_month_revenue AS
SELECT r.region_id, r.region_name,
       SUM(o.net_total) FILTER (WHERE EXTRACT(MONTH FROM o.order_date) = 1) AS jan,
       SUM(o.net_total) FILTER (WHERE EXTRACT(MONTH FROM o.order_date) = 2) AS feb,
       SUM(o.net_total) FILTER (WHERE EXTRACT(MONTH FROM o.order_date) = 3) AS mar
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_id, r.region_name;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_region_x_month_revenue ON mv_region_x_month_revenue(region_id);
/* Q61. */
DROP MATERIALIZED VIEW IF EXISTS mv_funnel_counts;
CREATE MATERIALIZED VIEW mv_funnel_counts AS
SELECT 'page_view' AS stage, COUNT(DISTINCT view_id) AS event_count FROM web_events.page_views
UNION ALL
SELECT event_type, COUNT(*) FROM web_events.events GROUP BY event_type;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_funnel_counts ON mv_funnel_counts(stage);
/* Q62. */
DROP MATERIALIZED VIEW IF EXISTS mv_cohort_retention;
CREATE MATERIALIZED VIEW mv_cohort_retention AS
WITH first_order AS (
    SELECT cust_id, date_trunc('month', MIN(order_date))::date AS cohort_month FROM sales.orders GROUP BY cust_id
),
activity AS (
    SELECT fo.cohort_month, o.cust_id,
           (EXTRACT(YEAR FROM o.order_date) - EXTRACT(YEAR FROM fo.cohort_month)) * 12
             + (EXTRACT(MONTH FROM o.order_date) - EXTRACT(MONTH FROM fo.cohort_month)) AS period_index
    FROM sales.orders o
    JOIN first_order fo ON fo.cust_id = o.cust_id
)
SELECT cohort_month, period_index::int AS period_index, COUNT(DISTINCT cust_id) AS active_customers
FROM activity
GROUP BY cohort_month, period_index;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_cohort_retention ON mv_cohort_retention(cohort_month, period_index);
/* Q63. */
DROP MATERIALIZED VIEW IF EXISTS mv_rfm_scores;
CREATE MATERIALIZED VIEW mv_rfm_scores AS
SELECT cust_id AS customer_id,
       NTILE(5) OVER (ORDER BY MAX(order_date) DESC) AS recency_score,
       NTILE(5) OVER (ORDER BY COUNT(*) DESC) AS frequency_score,
       NTILE(5) OVER (ORDER BY SUM(net_total) DESC) AS monetary_score
FROM sales.orders
GROUP BY cust_id;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_rfm_scores ON mv_rfm_scores(customer_id);
/* Q64. */
DROP MATERIALIZED VIEW IF EXISTS mv_customer_360_summary;
CREATE MATERIALIZED VIEW mv_customer_360_summary AS
SELECT c.customer_id, c.tier, COUNT(o.order_id) AS order_count, MAX(o.order_date) AS latest_order_date
FROM customers.customers c
LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY c.customer_id, c.tier;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_customer_360_summary ON mv_customer_360_summary(customer_id);
/* Q65. */
/* Dependency graph / refresh order: mv_orders_metrics, mv_revenue_by_region_month, mv_customer_lifetime, mv_store_kpis, mv_ticket_sla, mv_daily_revenue, mv_inventory_latest, mv_top_customers_per_region, mv_region_percentiles, mv_region_x_month_revenue, mv_funnel_counts, mv_cohort_retention, mv_rfm_scores and mv_customer_360_summary all read only base tables directly - none is built from another MV in this set, so there is no strict inter-MV ordering requirement here; they can all refresh independently/in parallel, grouped only by which base table they read (orders-derived MVs vs tickets/calls/web_events-derived MVs) to spread I/O load rather than by dependency. */
/* Q66. */
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_orders_metrics;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_revenue_by_region_month;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_customer_lifetime;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_store_kpis;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_ticket_sla;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_daily_revenue;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_inventory_latest;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_top_customers_per_region;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_region_percentiles;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_region_x_month_revenue;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_funnel_counts;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_cohort_retention;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_rfm_scores;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_customer_360_summary;
/* Q67. */
SELECT c.relname AS mv_name
FROM pg_class c
WHERE c.relkind = 'm'
  AND NOT EXISTS (SELECT 1 FROM pg_index i WHERE i.indrelid = c.oid AND i.indisunique)
ORDER BY c.relname;
/* Q68. */
/* REFRESH MATERIALIZED VIEW takes an ACCESS EXCLUSIVE lock: it's faster to run (no diff computation) but blocks all reads on the MV for its duration - fine for small MVs or maintenance windows. REFRESH MATERIALIZED VIEW CONCURRENTLY never blocks readers but is slower (builds a full new result set separately, then diffs and merges row-by-row against the unique index) - the right pick for any MV a live dashboard queries during the refresh. Measuring: wrap each in \timing and compare wall-clock on a representative MV; CONCURRENTLY is typically 1.5-3x slower but with zero read blocking. */
/* Q69. */
CREATE OR REPLACE VIEW v_daily_revenue_hybrid AS
SELECT d, revenue FROM mv_daily_revenue
UNION ALL
SELECT CURRENT_DATE, COALESCE(SUM(net_total), 0)
FROM sales.orders
WHERE order_date = CURRENT_DATE
  AND CURRENT_DATE NOT IN (SELECT d FROM mv_daily_revenue);
/* Q70. */
DROP MATERIALIZED VIEW IF EXISTS mv_daily_revenue_90d;
CREATE MATERIALIZED VIEW mv_daily_revenue_90d AS
SELECT d.day::date AS d, COALESCE(SUM(o.net_total), 0) AS revenue
FROM generate_series(CURRENT_DATE - INTERVAL '90 days', CURRENT_DATE, INTERVAL '1 day') AS d(day)
LEFT JOIN sales.orders o ON o.order_date = d.day::date
GROUP BY d.day;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_daily_revenue_90d ON mv_daily_revenue_90d(d);
/* Q71. */
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
/* Q72. */
SELECT 'mv_orders_metrics' AS mv_name,
       (SELECT SUM(revenue) FROM mv_orders_metrics) AS mv_total,
       (SELECT SUM(net_total) FROM sales.orders WHERE order_status <> 'Failed') AS live_total
UNION ALL
SELECT 'mv_daily_revenue', (SELECT SUM(revenue) FROM mv_daily_revenue), (SELECT SUM(net_total) FROM sales.orders);
/* Q73. */
/* Concept: for an MV with several secondary indexes that's only refreshed via plain REFRESH (not CONCURRENTLY), it can be faster overall to DROP the secondary indexes, run REFRESH MATERIALIZED VIEW (a bulk rewrite with nothing else to maintain), then CREATE INDEX again in bulk - versus letting a non-concurrent REFRESH implicitly rebuild the table and leaving index maintenance to happen incrementally; the tradeoff is a window where the MV is completely unindexed (acceptable only during an off-hours maintenance job, never for a live-queried MV). */
/* Q74. */
/* 5-minute SLO tier: none of these MVs are cheap enough at full-table PERCENTILE_CONT/DISTINCT ON scale to safely fit a 5-minute refresh under load - reserve that tier for small partial/windowed MVs (e.g. mv_daily_revenue_90d). Hourly tier: mv_ticket_sla, mv_inventory_latest, mv_daily_revenue (ops-facing, same-day freshness needed). Daily tier: mv_orders_metrics, mv_revenue_by_region_month, mv_customer_lifetime, mv_store_kpis, mv_top_customers_per_region, mv_region_percentiles, mv_region_x_month_revenue, mv_cohort_retention, mv_rfm_scores, mv_customer_360_summary (slow-moving lifetime/summary metrics). */
/* Q75. */
COMMENT ON MATERIALIZED VIEW mv_orders_metrics IS 'Owner: analytics team. Grain: one row per region per month. Refresh: daily 02:00 UTC. Dependents: none.';
COMMENT ON MATERIALIZED VIEW mv_customer_lifetime IS 'Owner: analytics team. Grain: one row per customer. Refresh: daily 02:10 UTC. Dependents: none.';
COMMENT ON MATERIALIZED VIEW mv_ticket_sla IS 'Owner: support ops. Grain: one row per priority. Refresh: hourly. Dependents: none.';
COMMENT ON MATERIALIZED VIEW mv_daily_revenue IS 'Owner: analytics team. Grain: one row per calendar day (gap-filled). Refresh: hourly. Dependents: none.';

/* ============================================================
   SECTION D: COMPOSED ANALYTICS MVS (25)
   ------------------------------------------------------------ */
/* Q76. */
DROP MATERIALIZED VIEW IF EXISTS mv_region_dashboard;
CREATE MATERIALIZED VIEW mv_region_dashboard AS
WITH latest AS (
    SELECT DISTINCT ON (r.region_name) r.region_name, o.order_date AS latest_order_date
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    ORDER BY r.region_name, o.order_date DESC
)
SELECT r.region_id, r.region_name, COUNT(*) AS orders,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov,
       PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY o.net_total) AS p90_aov,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_aov,
       MAX(l.latest_order_date) AS latest_order_date,
       RANK() OVER (ORDER BY PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) DESC) AS rnk
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
JOIN latest l ON l.region_name = r.region_name
GROUP BY r.region_id, r.region_name;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_region_dashboard ON mv_region_dashboard(region_id);
/* Q77. */
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
/* Q78. */
DROP MATERIALIZED VIEW IF EXISTS mv_delivery_sla;
CREATE MATERIALIZED VIEW mv_delivery_sla AS
SELECT r.region_id, r.region_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sh.delivered_date - o.order_date) AS median_days,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY sh.delivered_date - o.order_date) AS p95_days,
       ROUND((100.0 * COUNT(*) FILTER (WHERE sh.delivered_date - o.order_date > 7) / COUNT(*))::numeric, 2) AS breach_pct
FROM sales.orders o
JOIN sales.shipments sh ON sh.order_id = o.order_id
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
WHERE o.order_status = 'Delivered' AND sh.delivered_date IS NOT NULL
GROUP BY r.region_id, r.region_name;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_delivery_sla ON mv_delivery_sla(region_id);
/* Q79. */
DROP MATERIALIZED VIEW IF EXISTS mv_ticket_sla_extended;
CREATE MATERIALIZED VIEW mv_ticket_sla_extended AS
SELECT priority, date_trunc('month', created_date)::date AS month,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600.0) AS median_hours,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600.0) AS p95_hours
FROM support.tickets
WHERE resolved_date IS NOT NULL
GROUP BY priority, month;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_ticket_sla_extended ON mv_ticket_sla_extended(priority, month);
/* Q80. */
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
SELECT l.product_id, b.p25_price, b.p75_price, l.latest_price,
       (l.latest_price < b.p25_price OR l.latest_price > b.p75_price) AS drift_flag
FROM latest l
JOIN band b ON b.prod_id = l.product_id;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_pricing_corridor ON mv_pricing_corridor(product_id);
/* Q81. */
DROP MATERIALIZED VIEW IF EXISTS mv_inventory_value;
CREATE MATERIALIZED VIEW mv_inventory_value AS
WITH snap_diffs AS (
    SELECT warehouse_id, product_id, snapshot_date, quantity_on_hand,
           quantity_on_hand - LAG(quantity_on_hand) OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date) AS qty_change
    FROM supply_chain.inventory_snapshots
),
depletion AS (
    SELECT warehouse_id, product_id, AVG(-qty_change) AS avg_daily_depletion
    FROM snap_diffs WHERE qty_change < 0
    GROUP BY warehouse_id, product_id
),
latest_snap AS (
    SELECT DISTINCT ON (warehouse_id, product_id) warehouse_id, product_id, quantity_on_hand
    FROM supply_chain.inventory_snapshots
    ORDER BY warehouse_id, product_id, snapshot_date DESC
)
SELECT ls.warehouse_id, SUM(ls.quantity_on_hand * p.cost_price) AS inventory_value,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ls.quantity_on_hand / NULLIF(d.avg_daily_depletion, 0)) AS median_days_of_cover
FROM latest_snap ls
JOIN products.products p ON p.product_id = ls.product_id
LEFT JOIN depletion d ON d.warehouse_id = ls.warehouse_id AND d.product_id = ls.product_id
GROUP BY ls.warehouse_id;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_inventory_value ON mv_inventory_value(warehouse_id);
/* Q82. */
DROP MATERIALIZED VIEW IF EXISTS mv_anomaly_daily;
CREATE MATERIALIZED VIEW mv_anomaly_daily AS
WITH region_daily AS (
    SELECT r.region_id, r.region_name, o.order_date, SUM(o.net_total) AS revenue
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_id, r.region_name, o.order_date
),
bounds AS (
    SELECT region_id, PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY revenue) AS p95_revenue
    FROM region_daily
    GROUP BY region_id
)
SELECT rd.region_id, rd.region_name, rd.order_date, rd.revenue, b.p95_revenue
FROM region_daily rd
JOIN bounds b ON b.region_id = rd.region_id
WHERE rd.revenue > b.p95_revenue;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_anomaly_daily ON mv_anomaly_daily(region_id, order_date);
/* Q83. */
DROP MATERIALIZED VIEW IF EXISTS mv_funnel_drop_off;
CREATE MATERIALIZED VIEW mv_funnel_drop_off AS
SELECT event_type AS stage, EXTRACT(HOUR FROM event_timestamp)::int AS hour_of_day, COUNT(*) AS event_count
FROM web_events.events
GROUP BY event_type, hour_of_day;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_funnel_drop_off ON mv_funnel_drop_off(stage, hour_of_day);
/* Q84. */
DROP MATERIALIZED VIEW IF EXISTS mv_customer_rfm_segments;
CREATE MATERIALIZED VIEW mv_customer_rfm_segments AS
SELECT cust_id AS customer_id,
       NTILE(5) OVER (ORDER BY MAX(order_date) DESC) AS recency_score,
       NTILE(5) OVER (ORDER BY COUNT(*) DESC) AS frequency_score,
       NTILE(5) OVER (ORDER BY SUM(net_total) DESC) AS monetary_score
FROM sales.orders
GROUP BY cust_id;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_customer_rfm_segments ON mv_customer_rfm_segments(customer_id);
/* Q85. */
DROP MATERIALIZED VIEW IF EXISTS mv_audit_change_jumps;
CREATE MATERIALIZED VIEW mv_audit_change_jumps AS
SELECT change_id, table_name, column_name, old_value, new_value, changed_by, changed_at
FROM audit.record_changes
WHERE column_name IN ('price', 'net_total', 'amount')
  AND old_value ~ '^[0-9.]+$' AND new_value ~ '^[0-9.]+$'
  AND old_value::numeric > 0
  AND ABS(new_value::numeric - old_value::numeric) / old_value::numeric > 0.5;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_audit_change_jumps ON mv_audit_change_jumps(change_id);
/* Q86. */
DROP MATERIALIZED VIEW IF EXISTS mv_heatmap_weekday_hour;
CREATE MATERIALIZED VIEW mv_heatmap_weekday_hour AS
SELECT EXTRACT(DOW FROM view_timestamp)::int AS weekday, EXTRACT(HOUR FROM view_timestamp)::int AS hour_of_day, COUNT(*) AS view_count
FROM web_events.page_views
GROUP BY 1, 2;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_heatmap_weekday_hour ON mv_heatmap_weekday_hour(weekday, hour_of_day);
/* Q87. */
DROP MATERIALIZED VIEW IF EXISTS mv_region_x_quarter_median_aov;
CREATE MATERIALIZED VIEW mv_region_x_quarter_median_aov AS
SELECT r.region_id, r.region_name, EXTRACT(YEAR FROM o.order_date)::int AS yr, EXTRACT(QUARTER FROM o.order_date)::int AS quarter,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_id, r.region_name, yr, quarter;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_region_x_quarter_median_aov ON mv_region_x_quarter_median_aov(region_id, yr, quarter);
/* Q88. */
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
       revenue - LAG(revenue, 12) OVER (PARTITION BY region_id ORDER BY month) AS yoy_change
FROM monthly;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_growth_metrics ON mv_growth_metrics(region_id, month);
/* Q89. */
DROP MATERIALIZED VIEW IF EXISTS mv_customer_360_summary;
CREATE MATERIALIZED VIEW mv_customer_360_summary AS
SELECT c.customer_id, c.tier, COUNT(o.order_id) AS order_count, MAX(o.order_date) AS latest_order_date
FROM customers.customers c
LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY c.customer_id, c.tier;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_customer_360_summary ON mv_customer_360_summary(customer_id);
COMMENT ON MATERIALIZED VIEW mv_customer_360_summary IS 'Refresh cadence: nightly 03:00 UTC. Grain: one row per customer. Owner: analytics team.';
/* Q90. */
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
/* Q91. */
DROP MATERIALIZED VIEW IF EXISTS mv_top_products_per_category;
CREATE MATERIALIZED VIEW mv_top_products_per_category AS
SELECT category_name, product_id, units_sold, rnk
FROM (
    SELECT cat.category_name, oi.prod_id AS product_id, SUM(oi.quantity) AS units_sold,
           RANK() OVER (PARTITION BY cat.category_name ORDER BY SUM(oi.quantity) DESC) AS rnk
    FROM sales.order_items oi
    JOIN products.products p ON p.product_id = oi.prod_id
    JOIN core.dim_brand b ON b.brand_id = p.brand_id
    JOIN core.dim_category cat ON cat.category_id = b.category_id
    GROUP BY cat.category_name, oi.prod_id
) ranked
WHERE rnk <= 5;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_top_products_per_category ON mv_top_products_per_category(category_name, product_id);
/* Q92. */
DROP MATERIALIZED VIEW IF EXISTS mv_revenue_decomposition;
CREATE MATERIALIZED VIEW mv_revenue_decomposition AS
WITH first_order AS (
    SELECT cust_id, MIN(order_date) AS first_order_date FROM sales.orders GROUP BY cust_id
)
SELECT r.region_id, r.region_name, date_trunc('month', o.order_date)::date AS month,
       SUM(o.net_total) FILTER (WHERE o.order_date = fo.first_order_date) AS new_customer_revenue,
       SUM(o.net_total) FILTER (WHERE o.order_date <> fo.first_order_date) AS returning_customer_revenue
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
JOIN first_order fo ON fo.cust_id = o.cust_id
GROUP BY r.region_id, r.region_name, month;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_revenue_decomposition ON mv_revenue_decomposition(region_id, month);
/* Q93. */
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
/* Q94. */
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
/* Q95. */
DROP MATERIALIZED VIEW IF EXISTS mv_calls_hourly_by_agent;
CREATE MATERIALIZED VIEW mv_calls_hourly_by_agent AS
SELECT agent_id, EXTRACT(HOUR FROM call_start_time)::int AS hour_of_day,
       COUNT(*) AS calls,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY call_duration_seconds) AS median_duration_sec
FROM call_center.calls
GROUP BY agent_id, hour_of_day;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_calls_hourly_by_agent ON mv_calls_hourly_by_agent(agent_id, hour_of_day);
/* Q96. */
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
/* Q97. */
DROP MATERIALIZED VIEW IF EXISTS mv_executive_strip;
CREATE MATERIALIZED VIEW mv_executive_strip AS
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
       ROUND((100.0 * COUNT(*) FILTER (WHERE o.order_status = 'Delivered') / COUNT(*))::numeric, 2) AS sla_pct,
       COALESCE(MAX(ch.churn_risk_count), 0) AS churn_risk_count,
       RANK() OVER (ORDER BY PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) DESC) AS rnk
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
LEFT JOIN churn ch ON ch.region_name = r.region_name
GROUP BY r.region_id, r.region_name;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_executive_strip ON mv_executive_strip(region_id);
/* Q98. */
SELECT 'mv_orders_metrics' AS mv_name, (SELECT SUM(revenue) FROM mv_orders_metrics) AS mv_total, (SELECT SUM(net_total) FROM sales.orders WHERE order_status <> 'Failed') AS live_total
UNION ALL
SELECT 'mv_customer_lifetime', (SELECT SUM(total_revenue) FROM mv_customer_lifetime), (SELECT SUM(net_total) FROM sales.orders)
UNION ALL
SELECT 'mv_daily_revenue', (SELECT SUM(revenue) FROM mv_daily_revenue), (SELECT SUM(net_total) FROM sales.orders)
UNION ALL
SELECT 'mv_executive_strip', (SELECT SUM(orders) FROM mv_executive_strip), (SELECT COUNT(*) FROM sales.orders);
/* Q99. */
SELECT DISTINCT dep.relname AS dependent_object, base.relname AS base_mv
FROM pg_depend d
JOIN pg_rewrite r ON r.oid = d.objid
JOIN pg_class dep ON dep.oid = r.ev_class
JOIN pg_class base ON base.oid = d.refobjid
WHERE base.relkind = 'm' AND dep.relname <> base.relname
ORDER BY base_mv;

DROP MATERIALIZED VIEW IF EXISTS mv_executive_strip CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_returns_root_cause CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_calls_hourly_by_agent CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_dynamic_sla_attainment CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_inventory_stockout_streaks CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_revenue_decomposition CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_top_products_per_category CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_pay_slip_dept_summary CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_customer_360_summary CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_growth_metrics CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_region_x_quarter_median_aov CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_heatmap_weekday_hour CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_audit_change_jumps CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_customer_rfm_segments CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_funnel_drop_off CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_anomaly_daily CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_inventory_value CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_pricing_corridor CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_ticket_sla_extended CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_delivery_sla CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_region_dashboard CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_customer_360_summary CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_rfm_scores CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_cohort_retention CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_cohort_triangle_with_ltv CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_funnel_counts CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_region_x_month_revenue CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_region_percentiles CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_top_customers_per_region CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_inventory_latest CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_daily_revenue_90d CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_daily_revenue CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_revenue_daily CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_revenue_weekly CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_revenue_monthly CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_ticket_sla CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_store_kpis CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_customer_lifetime CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_revenue_by_region_month CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_orders_metrics CASCADE;
/* Q100. */
DROP VIEW IF EXISTS v_exec_metrics CASCADE;
DROP VIEW IF EXISTS v_sales_trend_region CASCADE;
DROP VIEW IF EXISTS v_pricing_corridor CASCADE;
DROP VIEW IF EXISTS v_funnel_stage_counts CASCADE;
DROP VIEW IF EXISTS v_anomaly_daily CASCADE;
DROP VIEW IF EXISTS v_customer_360 CASCADE;
DROP VIEW IF EXISTS v_customer_rfm CASCADE;
DROP VIEW IF EXISTS v_cohort_period CASCADE;
DROP VIEW IF EXISTS v_top_customers_per_region CASCADE;
DROP VIEW IF EXISTS v_region_aov_percentiles CASCADE;
DROP VIEW IF EXISTS v_region_quarter_rollup CASCADE;
DROP VIEW IF EXISTS v_returns_tier_metrics CASCADE;
DROP VIEW IF EXISTS v_orders_with_delivery CASCADE;
DROP VIEW IF EXISTS v_orders_with_payment CASCADE;
DROP VIEW IF EXISTS v_orders_with_customer CASCADE;
DROP VIEW IF EXISTS v_calls_sla_hourly CASCADE;
DROP VIEW IF EXISTS v_calls_enriched CASCADE;
DROP VIEW IF EXISTS v_page_views_hourly CASCADE;
DROP VIEW IF EXISTS v_page_views_clean CASCADE;
DROP VIEW IF EXISTS v_page_views_raw CASCADE;
DROP VIEW IF EXISTS v_audit_change_summary CASCADE;
DROP VIEW IF EXISTS v_audit_typed CASCADE;
DROP VIEW IF EXISTS v_audit_raw CASCADE;
DROP VIEW IF EXISTS v_returns_metrics_by_category CASCADE;
DROP VIEW IF EXISTS v_returns_enriched CASCADE;
DROP VIEW IF EXISTS v_pay_slip_summary CASCADE;
DROP VIEW IF EXISTS v_pay_slip_clean CASCADE;
DROP VIEW IF EXISTS v_pay_slip_raw CASCADE;
DROP VIEW IF EXISTS v_ticket_sla CASCADE;
DROP VIEW IF EXISTS v_tickets_clean CASCADE;
DROP VIEW IF EXISTS v_tickets_raw CASCADE;
DROP VIEW IF EXISTS v_inventory_value CASCADE;
DROP VIEW IF EXISTS v_inventory_latest CASCADE;
DROP VIEW IF EXISTS v_inventory_raw CASCADE;
DROP VIEW IF EXISTS v_products_enriched CASCADE;
DROP VIEW IF EXISTS v_products_clean CASCADE;
DROP VIEW IF EXISTS v_products_raw CASCADE;
DROP VIEW IF EXISTS v_customers_enriched CASCADE;
DROP VIEW IF EXISTS v_customers_clean CASCADE;
DROP VIEW IF EXISTS v_customers_raw CASCADE;
DROP VIEW IF EXISTS v_orders_metrics CASCADE;
DROP VIEW IF EXISTS v_orders_enriched CASCADE;
DROP VIEW IF EXISTS v_orders_clean CASCADE;
DROP VIEW IF EXISTS v_orders_raw CASCADE;

CREATE OR REPLACE VIEW v_orders_raw AS
SELECT order_id, cust_id, store_id, order_date, order_status, net_total, payment_mode_id
FROM sales.orders;
CREATE OR REPLACE VIEW v_orders_clean AS
SELECT order_id, cust_id, store_id, order_date, INITCAP(TRIM(order_status)) AS order_status, net_total
FROM v_orders_raw
WHERE order_status <> 'Failed';
CREATE OR REPLACE VIEW v_orders_enriched AS
SELECT oc.order_id, oc.order_date, oc.order_status, oc.net_total,
       c.customer_id, c.first_name || ' ' || c.last_name AS customer_name,
       s.store_id, s.store_name, r.region_name
FROM v_orders_clean oc
JOIN customers.customers c ON c.customer_id = oc.cust_id
JOIN stores.stores s ON s.store_id = oc.store_id
JOIN core.dim_region r ON r.region_id = s.region_id;
CREATE OR REPLACE VIEW v_orders_metrics AS
SELECT region_name, date_trunc('month', order_date)::date AS month, SUM(net_total) AS revenue, COUNT(*) AS order_count
FROM v_orders_enriched
GROUP BY region_name, month;
DROP MATERIALIZED VIEW IF EXISTS mv_orders_metrics;
CREATE MATERIALIZED VIEW mv_orders_metrics AS
SELECT region_name, month, revenue, order_count FROM v_orders_metrics;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_orders_metrics ON mv_orders_metrics(region_name, month);
-- idempotent: every view uses CREATE OR REPLACE, every MV/index uses DROP IF EXISTS/IF NOT EXISTS first.

/* ============================================================
   END OF ANSWER KEY - HARD LEVEL (100/100)
============================================================ */
