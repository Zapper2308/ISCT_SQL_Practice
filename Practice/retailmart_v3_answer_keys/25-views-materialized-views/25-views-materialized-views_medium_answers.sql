/* ============================================================
   ANSWER KEY - Views & Materialized Views (MEDIUM LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1. Raw holds a thin passthrough/rename of the base table with no filtering, cleaned applies type-casting/trimming/status filters to fix data quality, and metrics aggregates the cleaned layer into the KPIs consumers query - separating "what the source says" from "what's trustworthy" from "what's the answer" so each concern can change independently. */
/* Q2. A view enables an index-only scan on the base table when the view's SELECT list only needs columns that are all present in one covering index and the query has a WHERE/ORDER BY the planner can push down through the view into that index - the view itself adds no extra I/O, it's inlined away. */
/* Q3. View inlining substitutes the view's stored SELECT text directly into the outer query's plan tree (as if you'd pasted the view's SQL in place of its name) before optimization, so the planner can push outer WHERE clauses down into the view's joins/filters and pick indexes as if there were no view at all - this only works for simple views (no aggregates/LIMIT/set ops in the view itself). */
/* Q4. CREATE OR REPLACE VIEW requires the same column list shape (same number of output columns, same names, same order, and types must be assignment-compatible) because every existing consumer/dependent object was compiled against that exact output shape - changing it would silently break them, so Postgres refuses and you must DROP + CREATE instead if the shape must change. */
/* Q5. An updatable view is one Postgres can automatically translate INSERT/UPDATE/DELETE on into the single underlying base table (simple SELECT, one table, no aggregates/DISTINCT/GROUP BY/window functions); a non-updatable view (joins, aggregates, set operations) cannot be written through automatically and needs an INSTEAD OF trigger if write-through is required. */
/* Q6. WITH CHECK OPTION on a view enforces that any row inserted/updated through the view must still satisfy the view's own WHERE clause; LOCAL only checks that view's own condition, while CASCADED (the default) also re-checks the WHERE conditions of every view underneath it in the stack, so a row can't be written that would immediately vanish from any layer's filter. */
/* Q7. A view is best for freshness-critical, cheap logic; an MV is best for expensive aggregates that tolerate periodic staleness; a plain summary table is best when the data needs to be independently loaded/mutated by a pipeline (not derived live from a query) or needs its own indexes/constraints unrelated to any single source query. */
/* Q8. REFRESH MATERIALIZED VIEW CONCURRENTLY computes the new result set into a separate temporary space and then diffs it row-by-row against the existing MV using its unique index to match "the same logical row" - without that unique index Postgres has no way to know which old row corresponds to which new row, so it would have to swap the whole table under an exclusive lock instead. */
/* Q9. Primary lookup index: a UNIQUE INDEX on the MV's natural key (the column(s) queries filter/join on most, and the prerequisite for CONCURRENTLY refresh); secondary indexes: additional non-unique B-tree indexes on other frequently-filtered columns (e.g. a date range, a status) to avoid a sequential scan on large MVs. */
/* Q10. Refresh MVs in dependency order - any MV that reads from another MV (or from a view built on an MV) must be refreshed only after its upstream MV has finished refreshing, otherwise it computes its own result from stale or half-updated upstream data; independent MVs with no shared dependency can refresh in any order (or in parallel). */
/* Q11. Query pg_depend joined to pg_rewrite (ev_class) and pg_class to find every object whose rule references a given view's OID as refobjid - this lists all direct dependents; recursing the same join from each dependent finds transitive dependents, or simply query information_schema.view_table_usage for a friendlier one-hop view. */
/* Q12. Before DROP ... CASCADE, run the pg_depend/pg_class dependency query to inventory every object that would be dropped as a side effect, review that list against what's actually safe to lose, and only then run the CASCADE drop (or drop each listed dependent explicitly first so nothing unexpected disappears). */
/* Q13. Namespacing views under a dedicated schema (e.g. analytics.v_*) keeps generated/derived objects visibly separate from source tables, lets you grant blanket SELECT on the whole analytics schema instead of naming individual views, and avoids name collisions with base tables or other teams' objects in the default schema. */
/* Q14. A view runs with privileges resolved at creation time against its owner's access to the underlying tables (by default, SECURITY DEFINER-like behavior for views), and it resolves unqualified object names using search_path at query time - if search_path changes or another schema has a same-named object earlier in the path, the view can silently start reading the wrong table. */
/* Q15. Inlining hurts when many small views are nested/joined together and the planner has to re-derive a good join order and predicate pushdown across the fully expanded, very large combined query tree - past a certain depth/complexity the planner's search can time out into a worse plan than if the intermediate results had simply been materialized. */
/* Q16. A percentile MV pays the expensive PERCENTILE_CONT sort/group cost once per REFRESH instead of once per query, so the refresh cost is amortized across every read between refreshes - worthwhile when the percentile is read far more often than the underlying data changes. */
/* Q17. A daily-grain time-series MV is cheap to refresh and enough for day-level reporting/trend dashboards; an hourly-grain MV costs more storage and more frequent refreshes but is needed when stakeholders need same-day, intraday visibility (e.g. an ops monitor) rather than yesterday's numbers. */
/* Q18. A pivot MV (one row per key, one column per category) suits a fixed, small set of categories consumed directly by a dashboard grid; a long MV (one row per key+category) suits an unbounded or changing category set and is easier to aggregate/filter/join downstream - convert to a pivot only at the final presentation layer. */
/* Q19. EXPLAIN ANALYZE on an MV-backed query should show a plain Index Scan or Index-Only Scan directly against the MV's physical storage with no re-execution of the original expensive joins/aggregates; on the underlying view it shows the full inlined join/aggregate plan re-run live - the MV plan should be dramatically cheaper. */
/* Q20. Stale-data tolerance is set by how the consumer uses the number: an exec KPI checked once a day tolerates a stale-until-tomorrow MV, an intraday ops dashboard needs hourly refresh, and a live fraud/inventory alert may need a view (or a very short refresh interval) - the consumer's own decision cadence sets the ceiling on acceptable staleness. */
/* Q21. Views combining objects from many schemas should live in a clearly-owned analytics/reporting schema (not scattered across the source schemas they read from), named consistently (v_/mv_ prefixes) with a documented owner, so it's clear who's responsible for fixing them when an underlying source schema changes. */
/* Q22. COMMENT ON MATERIALIZED VIEW mv_name IS 'refresh cadence, owner, grain' stores the refresh contract directly in the catalog next to the object it describes, so anyone inspecting the MV (via \d+ or pg_description) sees the operational contract without needing separate external documentation that can drift out of sync. */
/* Q23. A view becomes a performance crutch when it's used to "hide" a genuinely expensive query behind a friendly name and gets called repeatedly in hot paths without anyone materializing it - the view doesn't make the query cheaper, it just makes the cost less visible, until it should have been an MV or indexed summary table long ago. */
/* Q24. Versioning views (v_orders_enriched_v2 alongside v_orders_enriched) lets you roll out a changed shape/definition to new consumers while old consumers keep working unmodified against v1, then deprecate and drop v1 once every consumer has migrated to v2 - avoiding a breaking CREATE OR REPLACE that changes the column shape underneath still-active consumers. */
/* Q25. Deeply nested views (a view built on a view built on a view, several layers deep) hurt because each layer re-inlines and re-optimizes the whole expanded tree, increasing planning time and risking a bad plan; past 2-3 layers it's usually better to materialize an intermediate layer as an MV or flatten the logic into fewer views. */

/* ============================================================
   SECTION B: LAYERED STACKS (25)
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
       s.store_id, s.store_name
FROM v_orders_clean oc
JOIN customers.customers c ON c.customer_id = oc.cust_id
JOIN stores.stores s ON s.store_id = oc.store_id;
/* Q27. */
CREATE OR REPLACE VIEW v_orders_clean AS
SELECT order_id, cust_id, store_id, order_date, INITCAP(TRIM(order_status)) AS order_status, net_total
FROM v_orders_raw
WHERE order_status <> 'Failed';
/* Q28. */
CREATE OR REPLACE VIEW v_orders_enriched AS
SELECT oc.order_id, oc.order_date, oc.order_status, oc.net_total,
       c.customer_id, c.first_name || ' ' || c.last_name AS customer_name,
       s.store_id, s.store_name, r.region_name, pm.mode_name AS payment_mode
FROM v_orders_clean oc
JOIN sales.orders o ON o.order_id = oc.order_id
JOIN customers.customers c ON c.customer_id = oc.cust_id
JOIN stores.stores s ON s.store_id = oc.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
LEFT JOIN finance.payment_modes pm ON pm.mode_id = o.payment_mode_id;
/* Q29. */
CREATE OR REPLACE VIEW v_revenue_by_region_month AS
SELECT region_name, date_trunc('month', order_date)::date AS month, SUM(net_total) AS revenue, COUNT(*) AS order_count
FROM v_orders_enriched
GROUP BY region_name, month;
/* Q30. */
CREATE OR REPLACE VIEW v_returns_raw AS
SELECT return_id, order_id, prod_id, return_date, reason, refund_amount FROM sales.returns;

CREATE OR REPLACE VIEW v_returns_clean AS
SELECT * FROM v_returns_raw WHERE refund_amount IS NOT NULL AND refund_amount > 0;

CREATE OR REPLACE VIEW v_returns_by_category AS
SELECT cat.category_name, COUNT(*) AS return_count, SUM(rc.refund_amount) AS total_refund
FROM v_returns_clean rc
JOIN products.products p ON p.product_id = rc.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
GROUP BY cat.category_name;
/* Q31. */
CREATE OR REPLACE VIEW v_tickets_clean AS
SELECT ticket_id, customer_id, agent_id, priority, status, created_date, resolved_date
FROM support.tickets
WHERE priority IS NOT NULL;

CREATE OR REPLACE VIEW v_ticket_sla AS
SELECT priority,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600.0) AS median_hours,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600.0) AS p95_hours
FROM v_tickets_clean
WHERE resolved_date IS NOT NULL
GROUP BY priority;
/* Q32. */
CREATE OR REPLACE VIEW v_customers_clean AS
SELECT c.customer_id, c.first_name || ' ' || c.last_name AS full_name, c.tier, c.registration_date,
       (SELECT a.city FROM customers.addresses a WHERE a.customer_id = c.customer_id ORDER BY a.is_default DESC NULLS LAST, a.address_id DESC LIMIT 1) AS primary_city
FROM customers.customers c;
/* Q33. */
CREATE OR REPLACE VIEW v_employees_clean AS
SELECT employee_id, store_id, first_name || ' ' || last_name AS full_name, role, dept_id, joining_date, salary
FROM stores.employees;

CREATE OR REPLACE VIEW v_employee_with_dept AS
SELECT ec.employee_id, ec.full_name, ec.role, d.dept_name, ec.salary
FROM v_employees_clean ec
JOIN core.dim_department d ON d.dept_id = ec.dept_id;
/* Q34. */
CREATE OR REPLACE VIEW v_products_clean AS
SELECT product_id, TRIM(product_name) AS product_name, brand_id, supplier_id, price, cost_price
FROM products.products
WHERE price IS NOT NULL;

CREATE OR REPLACE VIEW v_products_with_brand_category AS
SELECT pc.product_id, pc.product_name, pc.price, pc.cost_price, b.brand_name, cat.category_name
FROM v_products_clean pc
JOIN core.dim_brand b ON b.brand_id = pc.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id;
/* Q35. */
CREATE OR REPLACE VIEW v_inventory_latest AS
SELECT DISTINCT ON (warehouse_id, product_id) warehouse_id, product_id, snapshot_date, quantity_on_hand
FROM supply_chain.inventory_snapshots
ORDER BY warehouse_id, product_id, snapshot_date DESC;
/* Q36. */
CREATE OR REPLACE VIEW v_customer_latest_order AS
SELECT DISTINCT ON (cust_id) cust_id, order_id, order_date, net_total
FROM sales.orders
ORDER BY cust_id, order_date DESC;

CREATE OR REPLACE VIEW v_customer_first_order AS
SELECT DISTINCT ON (cust_id) cust_id, order_id, order_date, net_total
FROM sales.orders
ORDER BY cust_id, order_date ASC;
/* Q37. */
CREATE OR REPLACE VIEW v_orders_with_basket AS
SELECT o.order_id, o.cust_id, o.order_date, o.net_total, COUNT(oi.order_item_id) AS item_count
FROM sales.orders o
LEFT JOIN sales.order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id, o.cust_id, o.order_date, o.net_total;
/* Q38. */
CREATE OR REPLACE VIEW v_orders_with_payment AS
SELECT o.order_id, o.order_date, o.net_total, lp.status AS latest_payment_status, lp.amount AS latest_payment_amount
FROM sales.orders o
LEFT JOIN LATERAL (
    SELECT status, amount FROM finance.payments p WHERE p.order_id = o.order_id ORDER BY p.payment_id DESC LIMIT 1
) lp ON TRUE;
/* Q39. */
CREATE OR REPLACE VIEW v_revenue_by_region_quarter AS
SELECT region_name, date_trunc('quarter', order_date)::date AS quarter, SUM(net_total) AS revenue
FROM v_orders_enriched
GROUP BY region_name, quarter;
/* Q40. */
CREATE OR REPLACE VIEW v_region_aov_percentiles AS
SELECT region_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total) AS median_aov,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY net_total) AS p95_aov
FROM v_orders_enriched
GROUP BY region_name;
/* Q41. */
CREATE OR REPLACE VIEW v_top_customers_per_region AS
SELECT region_name, customer_id, customer_name, total_spend, rnk
FROM (
    SELECT region_name, customer_id, customer_name, SUM(net_total) AS total_spend,
           RANK() OVER (PARTITION BY region_name ORDER BY SUM(net_total) DESC) AS rnk
    FROM v_orders_enriched
    GROUP BY region_name, customer_id, customer_name
) ranked
WHERE rnk <= 10;
/* Q42. */
CREATE OR REPLACE VIEW v_daily_revenue AS
SELECT d.day::date AS d, COALESCE(SUM(o.net_total), 0) AS revenue
FROM generate_series((SELECT MIN(order_date) FROM sales.orders), (SELECT MAX(order_date) FROM sales.orders), INTERVAL '1 day') AS d(day)
LEFT JOIN sales.orders o ON o.order_date = d.day::date
GROUP BY d.day;
/* Q43. */
CREATE OR REPLACE VIEW v_region_x_month_revenue AS
SELECT region_name,
       SUM(net_total) FILTER (WHERE EXTRACT(MONTH FROM order_date) = 1) AS jan,
       SUM(net_total) FILTER (WHERE EXTRACT(MONTH FROM order_date) = 2) AS feb,
       SUM(net_total) FILTER (WHERE EXTRACT(MONTH FROM order_date) = 3) AS mar
FROM v_orders_enriched
GROUP BY region_name;
/* Q44. */
CREATE OR REPLACE VIEW v_customer_360 AS
SELECT c.customer_id, c.first_name || ' ' || c.last_name AS full_name, c.tier,
       lo.order_id AS latest_order_id, lo.order_date AS latest_order_date,
       agg.lifetime_order_count, agg.lifetime_revenue
FROM customers.customers c
LEFT JOIN v_customer_latest_order lo ON lo.cust_id = c.customer_id
LEFT JOIN (
    SELECT cust_id, COUNT(*) AS lifetime_order_count, SUM(net_total) AS lifetime_revenue
    FROM sales.orders
    GROUP BY cust_id
) agg ON agg.cust_id = c.customer_id;
/* Q45. */
CREATE OR REPLACE VIEW v_orders_with_customer AS
SELECT oc.order_id, oc.order_date, oc.order_status, oc.net_total, cc.customer_id, cc.full_name, cc.tier
FROM v_orders_clean oc
JOIN v_customers_clean cc ON cc.customer_id = oc.cust_id;
/* Q46. */
SELECT DISTINCT dep_view.relname AS dependent_view
FROM pg_depend d
JOIN pg_rewrite r ON r.oid = d.objid
JOIN pg_class dep_view ON dep_view.oid = r.ev_class
JOIN pg_class base_view ON base_view.oid = d.refobjid
WHERE base_view.relname = 'v_orders_raw' AND dep_view.relname <> 'v_orders_raw';
/* Q47. */
CREATE OR REPLACE VIEW v_orders_clean AS
SELECT order_id, cust_id, store_id, order_date, INITCAP(TRIM(order_status)) AS order_status, net_total
FROM v_orders_raw
WHERE order_status <> 'Failed';
-- column list (order_id, cust_id, store_id, order_date, order_status, net_total) is unchanged from the original definition, so CREATE OR REPLACE succeeds.
/* Q48. */
CREATE OR REPLACE VIEW v_orders_clean AS
SELECT order_id, cust_id, store_id, order_date, INITCAP(TRIM(order_status)) AS order_status, net_total,
       (order_status = 'Returned') AS is_returned
FROM v_orders_raw
WHERE order_status <> 'Failed';
-- v_orders_enriched and downstream views that SELECT * (or explicitly list is_returned) now see the new column automatically once they're re-created against the wider v_orders_clean.
/* Q49. */
SELECT COUNT(*) AS dependents
FROM pg_depend d
JOIN pg_rewrite r ON r.oid = d.objid
JOIN pg_class c ON c.oid = r.ev_class
WHERE d.refobjid = 'v_top_customers_per_region'::regclass AND c.relname <> 'v_top_customers_per_region';
-- 0 dependents confirmed, so it's safe to drop:
DROP VIEW IF EXISTS v_top_customers_per_region;
/* Q50. */
DROP VIEW IF EXISTS v_orders_enriched CASCADE;
DROP VIEW IF EXISTS v_orders_clean CASCADE;
DROP VIEW IF EXISTS v_orders_raw CASCADE;
CREATE OR REPLACE VIEW v_orders_raw AS
SELECT order_id, cust_id, store_id, order_date, order_status, net_total, payment_mode_id
FROM sales.orders;
CREATE OR REPLACE VIEW v_orders_clean AS
SELECT order_id, cust_id, store_id, order_date, INITCAP(TRIM(order_status)) AS order_status, net_total,
       (order_status = 'Returned') AS is_returned
FROM v_orders_raw
WHERE order_status <> 'Failed';
CREATE OR REPLACE VIEW v_orders_enriched AS
SELECT oc.order_id, oc.order_date, oc.order_status, oc.net_total,
       c.customer_id, c.first_name || ' ' || c.last_name AS customer_name,
       s.store_id, s.store_name, r.region_name, pm.mode_name AS payment_mode
FROM v_orders_clean oc
JOIN sales.orders o ON o.order_id = oc.order_id
JOIN customers.customers c ON c.customer_id = oc.cust_id
JOIN stores.stores s ON s.store_id = oc.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
LEFT JOIN finance.payment_modes pm ON pm.mode_id = o.payment_mode_id;
-- every statement uses CREATE OR REPLACE VIEW, so re-running this script top-to-bottom is idempotent.

/* ============================================================
   SECTION C: MV MAINTENANCE & INDEXING (25)
   ------------------------------------------------------------ */
/* Q51. */
DROP MATERIALIZED VIEW IF EXISTS mv_monthly_revenue;
CREATE MATERIALIZED VIEW mv_monthly_revenue AS
SELECT date_trunc('month', order_date)::date AS month, SUM(net_total) AS total_revenue, COUNT(*) AS order_count
FROM sales.orders
GROUP BY 1;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_monthly_revenue_month ON mv_monthly_revenue(month);
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_revenue;
/* Q52. */
DROP MATERIALIZED VIEW IF EXISTS mv_revenue_by_region_month;
CREATE MATERIALIZED VIEW mv_revenue_by_region_month AS
SELECT r.region_id, r.region_name, date_trunc('month', o.order_date)::date AS month, SUM(o.net_total) AS revenue
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_id, r.region_name, 3;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_revenue_by_region_month ON mv_revenue_by_region_month(region_id, month);
CREATE INDEX IF NOT EXISTS ix_mv_revenue_by_region_month_month ON mv_revenue_by_region_month(month);
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
/* Q55. */
DROP MATERIALIZED VIEW IF EXISTS mv_product_sales;
CREATE MATERIALIZED VIEW mv_product_sales AS
SELECT oi.prod_id AS product_id, cat.category_name, SUM(oi.quantity) AS units_sold, SUM(oi.net_amount) AS revenue
FROM sales.order_items oi
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
GROUP BY oi.prod_id, cat.category_name;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_product_sales ON mv_product_sales(product_id);
CREATE INDEX IF NOT EXISTS ix_mv_product_sales_category ON mv_product_sales(category_name);
/* Q56. */
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
/* Q57. */
DROP MATERIALIZED VIEW IF EXISTS mv_ticket_sla;
CREATE MATERIALIZED VIEW mv_ticket_sla AS
SELECT priority,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600.0) AS median_hours,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600.0) AS p95_hours
FROM support.tickets
WHERE resolved_date IS NOT NULL
GROUP BY priority;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_ticket_sla ON mv_ticket_sla(priority);
/* Q58. */
DROP MATERIALIZED VIEW IF EXISTS mv_calls_hourly;
CREATE MATERIALIZED VIEW mv_calls_hourly AS
SELECT EXTRACT(HOUR FROM call_start_time)::int AS hour_of_day, COUNT(*) AS calls,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY call_duration_seconds) AS median_duration_sec
FROM call_center.calls
GROUP BY 1;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_calls_hourly ON mv_calls_hourly(hour_of_day);
/* Q59. */
DROP MATERIALIZED VIEW IF EXISTS mv_inventory_latest;
CREATE MATERIALIZED VIEW mv_inventory_latest AS
SELECT DISTINCT ON (warehouse_id, product_id) warehouse_id, product_id, snapshot_date, quantity_on_hand
FROM supply_chain.inventory_snapshots
ORDER BY warehouse_id, product_id, snapshot_date DESC;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_inventory_latest ON mv_inventory_latest(warehouse_id, product_id);
/* Q60. */
DROP MATERIALIZED VIEW IF EXISTS mv_daily_revenue;
CREATE MATERIALIZED VIEW mv_daily_revenue AS
SELECT d.day::date AS d, COALESCE(SUM(o.net_total), 0) AS revenue
FROM generate_series((SELECT MIN(order_date) FROM sales.orders), (SELECT MAX(order_date) FROM sales.orders), INTERVAL '1 day') AS d(day)
LEFT JOIN sales.orders o ON o.order_date = d.day::date
GROUP BY d.day;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_daily_revenue ON mv_daily_revenue(d);
/* Q61. */
DROP MATERIALIZED VIEW IF EXISTS mv_revenue_quarterly;
CREATE MATERIALIZED VIEW mv_revenue_quarterly AS
SELECT r.region_id, date_trunc('quarter', o.order_date)::date AS quarter, SUM(o.net_total) AS revenue
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_id, 2;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_revenue_quarterly ON mv_revenue_quarterly(region_id, quarter);
/* Q62. */
DROP MATERIALIZED VIEW IF EXISTS mv_returns_by_category;
CREATE MATERIALIZED VIEW mv_returns_by_category AS
SELECT cat.category_name, COUNT(*) AS returns, SUM(r.refund_amount) AS refund_total
FROM sales.returns r
JOIN products.products p ON p.product_id = r.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
GROUP BY cat.category_name;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_returns_by_category ON mv_returns_by_category(category_name);
/* Q63. */
DROP MATERIALIZED VIEW IF EXISTS mv_pay_slip_monthly;
CREATE MATERIALIZED VIEW mv_pay_slip_monthly AS
SELECT employee_id, to_date(salary_month || ' ' || salary_year, 'FMMonth YYYY') AS period, SUM(net_salary) AS net_salary
FROM payroll.pay_slips
GROUP BY employee_id, period;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_pay_slip_monthly ON mv_pay_slip_monthly(employee_id, period);
/* Q64. */
DROP MATERIALIZED VIEW IF EXISTS mv_employee_salary_latest;
CREATE MATERIALIZED VIEW mv_employee_salary_latest AS
SELECT DISTINCT ON (employee_id) employee_id, amount, payment_date
FROM hr.salary_history
ORDER BY employee_id, payment_date DESC;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_employee_salary_latest ON mv_employee_salary_latest(employee_id);
/* Q65. */
DROP MATERIALIZED VIEW IF EXISTS mv_orders_clean;
CREATE MATERIALIZED VIEW mv_orders_clean AS
SELECT o.order_id, o.cust_id, o.store_id, o.order_date, INITCAP(TRIM(o.order_status)) AS order_status, o.net_total,
       s.region_id
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
WHERE o.order_status <> 'Failed';
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_orders_clean ON mv_orders_clean(order_id);
CREATE INDEX IF NOT EXISTS ix_mv_orders_clean_status ON mv_orders_clean(order_status);
CREATE INDEX IF NOT EXISTS ix_mv_orders_clean_region_date ON mv_orders_clean(region_id, order_date);
/* Q66. */
DROP MATERIALIZED VIEW IF EXISTS mv_page_view_hourly;
CREATE MATERIALIZED VIEW mv_page_view_hourly AS
SELECT EXTRACT(HOUR FROM view_timestamp)::int AS hour_of_day, device_type, COUNT(*) AS page_views
FROM web_events.page_views
GROUP BY 1, 2;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_page_view_hourly ON mv_page_view_hourly(hour_of_day, device_type);
/* Q67. */
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
/* Q68. */
DROP MATERIALIZED VIEW IF EXISTS mv_top_customers_year;
CREATE MATERIALIZED VIEW mv_top_customers_year AS
SELECT yr, cust_id, total_spend, rnk FROM (
    SELECT yr, cust_id, total_spend, ROW_NUMBER() OVER (PARTITION BY yr ORDER BY total_spend DESC) AS rnk
    FROM (
        SELECT EXTRACT(YEAR FROM order_date)::int AS yr, cust_id, SUM(net_total) AS total_spend
        FROM sales.orders
        GROUP BY 1, 2
    ) yearly
) ranked
WHERE rnk <= 100;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_top_customers_year ON mv_top_customers_year(yr, rnk);
/* Q69. */
DROP MATERIALIZED VIEW IF EXISTS mv_customer_360_summary;
CREATE MATERIALIZED VIEW mv_customer_360_summary AS
SELECT c.customer_id, c.tier, COUNT(o.order_id) AS order_count, MAX(o.order_date) AS latest_order_date
FROM customers.customers c
LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY c.customer_id, c.tier;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_customer_360_summary ON mv_customer_360_summary(customer_id);
/* Q70. */
/* Refresh order (dependency-driven): mv_orders_clean and mv_customer_lifetime read directly from base tables so they refresh first/independently; mv_revenue_by_region_month, mv_store_kpis, mv_region_x_month_revenue, mv_revenue_quarterly, mv_top_customers_year and mv_top_customers_per_region also read only base tables and can refresh in any order alongside them; none of these MVs in this set are built on top of another MV, so there is currently no strict inter-MV ordering requirement - each can refresh independently, but grouping them by shared source table (orders-derived vs tickets-derived vs calls-derived) reduces contention on the same base table during a refresh window. */
/* Q71. */
/* Q71 refresh script (dependency order): */
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_revenue;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_revenue_by_region_month;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_customer_lifetime;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_store_kpis;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_product_sales;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_ticket_sla;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_calls_hourly;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_inventory_latest;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_daily_revenue;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_customer_360_summary;
/* Q72. */
SELECT c.relname AS mv_name,
       EXISTS (SELECT 1 FROM pg_index i JOIN pg_class ic ON ic.oid = i.indexrelid WHERE i.indrelid = c.oid AND i.indisunique) AS has_unique_index
FROM pg_class c
WHERE c.relkind = 'm'
ORDER BY c.relname;
/* Q73. */
/* REFRESH MATERIALIZED VIEW takes an ACCESS EXCLUSIVE lock and blocks all reads on the MV until it finishes - simplest and fastest to run, best for small MVs or maintenance windows with no live readers; REFRESH MATERIALIZED VIEW CONCURRENTLY never blocks readers (they keep seeing the old data until the swap) but requires a UNIQUE INDEX, does more work (builds a full new copy + diffs it), and is slower - best for MVs that dashboards query live during business hours. */
/* Q74. */
EXPLAIN ANALYZE SELECT * FROM mv_customer_lifetime WHERE customer_id = 100;
/* Q75. */
/* mv_monthly_revenue / mv_revenue_by_region_month / mv_store_kpis / mv_revenue_quarterly: daily refresh (month/quarter-grain numbers don't need to move intraday). mv_calls_hourly / mv_ticket_sla / mv_inventory_latest / mv_daily_revenue: hourly refresh where an ops team checks them same-day. mv_customer_lifetime / mv_customer_360_summary / mv_product_sales / mv_top_customers_per_region / mv_top_customers_year: daily refresh (lifetime/summary metrics move slowly). */

/* ============================================================
   SECTION D: COMPOSED ANALYTICS VIEWS (25)
   ------------------------------------------------------------ */
/* Q76. */
CREATE OR REPLACE VIEW v_region_dashboard AS
SELECT r.region_name, COUNT(*) AS orders, SUM(o.net_total) AS revenue,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_aov
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name;
/* Q77. */
DROP MATERIALIZED VIEW IF EXISTS mv_region_dashboard;
CREATE MATERIALIZED VIEW mv_region_dashboard AS
SELECT r.region_id, r.region_name, COUNT(*) AS orders, SUM(o.net_total) AS revenue,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_aov
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_id, r.region_name;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_region_dashboard ON mv_region_dashboard(region_id);
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_region_dashboard;
/* Q78. */
CREATE OR REPLACE VIEW v_cohort_retention AS
SELECT date_trunc('month', c.registration_date)::date AS cohort_month,
       date_trunc('month', o.order_date)::date AS activity_month,
       COUNT(DISTINCT c.customer_id) AS active_customers
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY cohort_month, activity_month;
/* Q79. */
CREATE OR REPLACE VIEW v_funnel_stage_counts AS
SELECT 'page_view' AS stage, COUNT(DISTINCT view_id) AS event_count FROM web_events.page_views
UNION ALL
SELECT event_type, COUNT(*) FROM web_events.events GROUP BY event_type;
/* Q80. */
CREATE OR REPLACE VIEW v_delivery_sla AS
SELECT r.region_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sh.delivered_date - o.order_date) AS median_days,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY sh.delivered_date - o.order_date) AS p95_days
FROM sales.orders o
JOIN sales.shipments sh ON sh.order_id = o.order_id
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
WHERE o.order_status = 'Delivered' AND sh.delivered_date IS NOT NULL
GROUP BY r.region_name;
/* Q81. */
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
/* Q82. */
CREATE OR REPLACE VIEW v_customer_rfm AS
SELECT cust_id,
       NTILE(5) OVER (ORDER BY MAX(order_date) DESC) AS recency_score,
       NTILE(5) OVER (ORDER BY COUNT(*) DESC) AS frequency_score,
       NTILE(5) OVER (ORDER BY SUM(net_total) DESC) AS monetary_score
FROM sales.orders
GROUP BY cust_id;
/* Q83. */
CREATE OR REPLACE VIEW v_anomaly_daily AS
WITH bounds AS (
    SELECT PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY revenue) AS p95_revenue FROM mv_daily_revenue
)
SELECT d, revenue FROM mv_daily_revenue, bounds WHERE revenue > bounds.p95_revenue;
/* Q84. */
CREATE OR REPLACE VIEW v_top_products_per_category AS
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

DROP MATERIALIZED VIEW IF EXISTS mv_top_products_per_category;
CREATE MATERIALIZED VIEW mv_top_products_per_category AS
SELECT * FROM v_top_products_per_category;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_top_products_per_category ON mv_top_products_per_category(category_name, product_id);
/* Q85. */
DROP MATERIALIZED VIEW IF EXISTS mv_heatmap_weekday_hour;
CREATE MATERIALIZED VIEW mv_heatmap_weekday_hour AS
SELECT EXTRACT(DOW FROM view_timestamp)::int AS weekday, EXTRACT(HOUR FROM view_timestamp)::int AS hour_of_day, COUNT(*) AS view_count
FROM web_events.page_views
GROUP BY 1, 2;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_heatmap_weekday_hour ON mv_heatmap_weekday_hour(weekday, hour_of_day);
/* Q86. */
CREATE OR REPLACE VIEW v_audit_change_summary AS
SELECT table_name, action, COUNT(*) AS change_count, COUNT(DISTINCT changed_by) AS distinct_actors
FROM audit.record_changes
GROUP BY table_name, action;
/* Q87. */
CREATE OR REPLACE VIEW v_customer_360_relational AS
SELECT c.customer_id,
       ARRAY(SELECT order_id FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY o.order_date DESC LIMIT 5) AS recent_order_ids,
       ARRAY(SELECT ticket_id FROM support.tickets t WHERE t.customer_id = c.customer_id ORDER BY t.created_date DESC LIMIT 5) AS recent_ticket_ids
FROM customers.customers c;
/* Q88. */
CREATE OR REPLACE VIEW v_pay_slip_summary AS
SELECT d.dept_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ps.net_salary) AS median_net_salary,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY ps.net_salary) AS p95_net_salary
FROM payroll.pay_slips ps
JOIN stores.employees e ON e.employee_id = ps.employee_id
JOIN core.dim_department d ON d.dept_id = e.dept_id
GROUP BY d.dept_name;
/* Q89. */
CREATE OR REPLACE VIEW v_inventory_value AS
SELECT ls.warehouse_id, SUM(ls.quantity_on_hand * p.cost_price) AS inventory_value
FROM v_inventory_latest ls
JOIN products.products p ON p.product_id = ls.product_id
GROUP BY ls.warehouse_id;
/* Q90. */
CREATE OR REPLACE VIEW v_revenue_decomposition AS
WITH first_order AS (
    SELECT cust_id, MIN(order_date) AS first_order_date FROM sales.orders GROUP BY cust_id
)
SELECT date_trunc('month', o.order_date)::date AS month,
       SUM(o.net_total) FILTER (WHERE o.order_date = fo.first_order_date) AS new_customer_revenue,
       SUM(o.net_total) FILTER (WHERE o.order_date <> fo.first_order_date) AS returning_customer_revenue
FROM sales.orders o
JOIN first_order fo ON fo.cust_id = o.cust_id
GROUP BY month;
/* Q91. */
CREATE OR REPLACE VIEW v_orders_with_filter_pivot AS
SELECT date_trunc('month', order_date)::date AS month,
       COUNT(*) FILTER (WHERE order_status = 'Delivered') AS delivered,
       COUNT(*) FILTER (WHERE order_status = 'Cancelled') AS cancelled,
       COUNT(*) FILTER (WHERE order_status = 'Returned') AS returned,
       COUNT(*) FILTER (WHERE order_status = 'Failed') AS failed
FROM sales.orders
GROUP BY month;
/* Q92. */
CREATE OR REPLACE VIEW v_region_x_quarter_median_aov AS
SELECT r.region_name, EXTRACT(YEAR FROM o.order_date) AS yr, EXTRACT(QUARTER FROM o.order_date) AS quarter,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name, yr, quarter;
/* Q93. */
CREATE OR REPLACE VIEW v_dynamic_sla AS
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
)
SELECT region_id, region_name, yr, quarter, p90_delivery_days,
       LAG(p90_delivery_days) OVER (PARTITION BY region_id ORDER BY yr, quarter) AS target_p90
FROM quarter_p90;
/* Q94. */
DROP MATERIALIZED VIEW IF EXISTS mv_customer_360_summary;
CREATE MATERIALIZED VIEW mv_customer_360_summary AS
SELECT c.customer_id, c.tier, COUNT(o.order_id) AS order_count, MAX(o.order_date) AS latest_order_date
FROM customers.customers c
LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY c.customer_id, c.tier;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_customer_360_summary ON mv_customer_360_summary(customer_id);
COMMENT ON MATERIALIZED VIEW mv_customer_360_summary IS 'Refresh cadence: nightly at 03:00 UTC. Grain: one row per customer. Owner: analytics team.';
/* Q95. */
CREATE OR REPLACE VIEW v_growth_metrics AS
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
/* Q96. */
DROP MATERIALIZED VIEW IF EXISTS mv_growth_metrics;
CREATE MATERIALIZED VIEW mv_growth_metrics AS
SELECT r.region_id, r.region_name, date_trunc('month', o.order_date)::date AS month, SUM(o.net_total) AS revenue
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_id, r.region_name, month;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_growth_metrics ON mv_growth_metrics(region_id, month);
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_growth_metrics;
/* Q97. */
COMMENT ON MATERIALIZED VIEW mv_monthly_revenue IS 'Refresh cadence: daily 02:00 UTC. Depends on: sales.orders. Dependents: none.';
COMMENT ON MATERIALIZED VIEW mv_revenue_by_region_month IS 'Refresh cadence: daily 02:15 UTC. Depends on: sales.orders, stores.stores, core.dim_region. Dependents: none.';
COMMENT ON MATERIALIZED VIEW mv_growth_metrics IS 'Refresh cadence: daily 02:30 UTC. Depends on: sales.orders, stores.stores, core.dim_region. Dependents: none.';
/* Q98. */
SELECT (SELECT SUM(net_total) FROM sales.orders) AS live_total,
       (SELECT SUM(total_revenue) FROM mv_monthly_revenue) AS mv_total;
/* Q99. */
DROP MATERIALIZED VIEW IF EXISTS mv_growth_metrics CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_customer_360_summary CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_heatmap_weekday_hour CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_top_products_per_category CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_region_dashboard CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_top_customers_year CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_page_view_hourly CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_orders_clean CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_employee_salary_latest CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_pay_slip_monthly CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_returns_by_category CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_revenue_quarterly CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_daily_revenue CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_inventory_latest CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_calls_hourly CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_ticket_sla CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_top_customers_per_region CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_product_sales CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_store_kpis CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_customer_lifetime CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_revenue_by_region_month CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_monthly_revenue CASCADE;
/* Q100. */
DROP VIEW IF EXISTS v_growth_metrics CASCADE;
DROP VIEW IF EXISTS v_dynamic_sla CASCADE;
DROP VIEW IF EXISTS v_region_x_quarter_median_aov CASCADE;
DROP VIEW IF EXISTS v_orders_with_filter_pivot CASCADE;
DROP VIEW IF EXISTS v_revenue_decomposition CASCADE;
DROP VIEW IF EXISTS v_inventory_value CASCADE;
DROP VIEW IF EXISTS v_pay_slip_summary CASCADE;
DROP VIEW IF EXISTS v_customer_360_relational CASCADE;
DROP VIEW IF EXISTS v_audit_change_summary CASCADE;
DROP VIEW IF EXISTS v_top_products_per_category CASCADE;
DROP VIEW IF EXISTS v_anomaly_daily CASCADE;
DROP VIEW IF EXISTS v_customer_rfm CASCADE;
DROP VIEW IF EXISTS v_pricing_corridor CASCADE;
DROP VIEW IF EXISTS v_delivery_sla CASCADE;
DROP VIEW IF EXISTS v_funnel_stage_counts CASCADE;
DROP VIEW IF EXISTS v_cohort_retention CASCADE;
DROP VIEW IF EXISTS v_region_dashboard CASCADE;
DROP VIEW IF EXISTS v_orders_with_customer CASCADE;
DROP VIEW IF EXISTS v_customer_360 CASCADE;
DROP VIEW IF EXISTS v_region_x_month_revenue CASCADE;
DROP VIEW IF EXISTS v_daily_revenue CASCADE;
DROP VIEW IF EXISTS v_top_customers_per_region CASCADE;
DROP VIEW IF EXISTS v_region_aov_percentiles CASCADE;
DROP VIEW IF EXISTS v_revenue_by_region_quarter CASCADE;
DROP VIEW IF EXISTS v_orders_with_payment CASCADE;
DROP VIEW IF EXISTS v_orders_with_basket CASCADE;
DROP VIEW IF EXISTS v_customer_first_order CASCADE;
DROP VIEW IF EXISTS v_customer_latest_order CASCADE;
DROP VIEW IF EXISTS v_inventory_latest CASCADE;
DROP VIEW IF EXISTS v_products_with_brand_category CASCADE;
DROP VIEW IF EXISTS v_products_clean CASCADE;
DROP VIEW IF EXISTS v_employee_with_dept CASCADE;
DROP VIEW IF EXISTS v_employees_clean CASCADE;
DROP VIEW IF EXISTS v_customers_clean CASCADE;
DROP VIEW IF EXISTS v_ticket_sla CASCADE;
DROP VIEW IF EXISTS v_tickets_clean CASCADE;
DROP VIEW IF EXISTS v_returns_by_category CASCADE;
DROP VIEW IF EXISTS v_returns_clean CASCADE;
DROP VIEW IF EXISTS v_returns_raw CASCADE;
DROP VIEW IF EXISTS v_revenue_by_region_month CASCADE;
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
       s.store_id, s.store_name, r.region_name, pm.mode_name AS payment_mode
FROM v_orders_clean oc
JOIN sales.orders o ON o.order_id = oc.order_id
JOIN customers.customers c ON c.customer_id = oc.cust_id
JOIN stores.stores s ON s.store_id = oc.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
LEFT JOIN finance.payment_modes pm ON pm.mode_id = o.payment_mode_id;
-- every CREATE uses OR REPLACE and every DROP uses IF EXISTS, so re-running this whole script is idempotent.

/* ============================================================
   END OF ANSWER KEY - MEDIUM LEVEL (100/100)
============================================================ */
