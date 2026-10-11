/* ============================================================
   ANSWER KEY - Views & Materialized Views (EASY LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1. A VIEW is a stored SELECT query saved under a name - it holds no data of its own, and every time it's queried, PostgreSQL runs the underlying SELECT live against the current base tables. */
/* Q2. A MATERIALIZED VIEW is a stored SELECT query PLUS its computed result set, physically saved on disk - reads are fast (no recomputation), but the data only updates when you explicitly REFRESH it. */
/* Q3. Sharing tested, verified logic as a view means every consumer runs the exact same correct join/filter, and a fix or improvement only has to be made once - copy-pasted SQL drifts out of sync and multiplies bugs. */
/* Q4. A materialized view trades freshness for speed: it serves a precomputed snapshot instantly instead of re-running an expensive query, at the cost of being stale until the next REFRESH; a plain view is always current but pays the full query cost every time. */
/* Q5. CREATE OR REPLACE VIEW redefines an existing view's query in place (keeping its OID and any dependent objects/permissions intact) as long as the new query returns the same column names, order, and types - it avoids the DROP+CREATE dance and its CASCADE risk. */
/* Q6. Views are ideal for a "metrics layer" because they let you define KPIs (revenue, AOV, SLA%) once in SQL, and every dashboard/report/analyst query just selects from the metric view, guaranteeing everyone sees the same definition. */
/* Q7. CREATE MATERIALIZED VIEW ... WITH NO DATA creates the MV's structure and stores its defining query, but does NOT run it yet - the MV holds zero rows and is marked unscannable until an explicit REFRESH populates it. */
/* Q8. REFRESH MATERIALIZED VIEW re-runs the MV's stored query and replaces its stored result set with the fresh output - by default it takes an exclusive lock, blocking reads on that MV until it completes. */
/* Q9. REFRESH MATERIALIZED VIEW CONCURRENTLY requires the MV to already have at least one UNIQUE INDEX (covering all rows, no WHERE clause) - Postgres uses it to diff old vs new rows and update in place instead of locking the whole MV. */
/* Q10. The unique index is what lets PostgreSQL identify "the same logical row" between the old and new result sets during a concurrent refresh, so it can compute a precise row-level diff (insert/update/delete) rather than swapping the entire table under an exclusive lock. */
/* Q11. In a layered stack, "raw" passes through source columns with light renaming, "cleaned" applies filtering/typing/trimming to fix data-quality issues, and "metrics" aggregates the cleaned layer into the KPIs consumers actually query. */
/* Q12. A "raw" view is a thin passthrough of a base table - selecting a minimal, renamed set of columns with no filtering or transformation, mainly to decouple downstream views from the base table's exact physical schema. */
/* Q13. A "cleaned" view sits on top of raw, applying type casts, trimming whitespace, standardizing text case, and filtering out known-bad or irrelevant rows (e.g. Cancelled orders) so downstream consumers get a trustworthy dataset. */
/* Q14. A "metrics" view sits on top of cleaned data and computes the actual aggregates/KPIs (SUM revenue, COUNT orders, AVG order value) that dashboards and reports consume directly. */
/* Q15. Views are read-only abstractions for downstream consumers because they hide the underlying tables' complexity/joins and enforce a single, tested SELECT - a consumer sees only the shaped output, never has to know (or accidentally break) the base schema. */
/* Q16. DROP VIEW ... CASCADE also drops every object that depends on that view (other views built on top of it, and in principle other things referencing it) - it's risky because it can silently take down a whole dependent stack without an explicit list of what's being removed. */
/* Q17. Query pg_depend (or the simpler pg_views/information_schema.view_table_usage) joined back to pg_rewrite/pg_class to find every object that references a given view before dropping it, so you know the full blast radius in advance. */
/* Q18. A view runs with the querying user's own privileges checked against the view definition (by default), but PostgreSQL evaluates the view owner's privileges on the underlying tables - so a view can grant access to summarized data without granting direct table access, inheriting and re-scoping the underlying security model. */
/* Q19. CREATE VIEW creates a permanent, catalog-registered view visible to any session with the right privileges; CREATE TEMP VIEW creates a view scoped to the current session only, automatically dropped when that session ends. */
/* Q20. An MV makes sense for slow analytics (heavy joins/aggregates over millions of rows) that consumers only need at hourly/daily freshness - paying the expensive computation once per refresh is far cheaper than recomputing it on every dashboard load. */
/* Q21. A normal view's freshness model is "always current" - every query sees live data because it re-runs the SELECT each time; an MV's freshness model is "as of the last REFRESH" - it can be minutes, hours, or days stale until refreshed again. */
/* Q22. Daily refresh suits reports consumed once a day (exec summaries, end-of-day KPIs) where overnight staleness is acceptable; hourly refresh is needed when a dashboard is checked intraday and stakeholders expect same-day numbers to update as the day progresses. */
/* Q23. Yes - a materialized view is a real physical table under the hood, so ordinary CREATE INDEX statements (btree, unique, GIN, etc., as covered on Day 20) work on it exactly as they would on any table. */
/* Q24. A view is a good place to enforce "one canonical join" because every consumer that needs orders+customers+stores just selects from the view instead of re-writing (and potentially getting wrong) the same multi-table join logic themselves. */
/* Q25. A "top customers this month" leaderboard (needs to be current, low cost to compute) fits a view; a "cohort retention triangle over 3 years of history" (expensive multi-join aggregate, doesn't change minute to minute) fits a materialized view. */

/* ============================================================
   SECTION B: PLAIN VIEWS (25)
   ------------------------------------------------------------ */
/* Q26. */
CREATE OR REPLACE VIEW v_delivered_orders AS
SELECT * FROM sales.orders WHERE order_status = 'Delivered';

/* Q27. */
CREATE OR REPLACE VIEW v_customer_full_name AS
SELECT customer_id, first_name || ' ' || last_name AS full_name
FROM customers.customers;

/* Q28. */
CREATE OR REPLACE VIEW v_orders_enriched AS
SELECT o.order_id, o.order_date, o.order_status, o.net_total,
       c.customer_id, c.first_name || ' ' || c.last_name AS customer_name,
       s.store_id, s.store_name
FROM sales.orders o
JOIN customers.customers c ON c.customer_id = o.cust_id
JOIN stores.stores s ON s.store_id = o.store_id;

/* Q29. */
CREATE OR REPLACE VIEW v_orders_clean AS
SELECT order_id, cust_id, store_id, order_date, initcap(order_status) AS order_status, net_total
FROM sales.orders
WHERE order_status NOT IN ('Failed', 'Cancelled');

/* Q30. */
SELECT count(*) AS delivered_order_count FROM v_delivered_orders;

/* Q31. */
CREATE OR REPLACE VIEW v_high_value_orders AS
SELECT * FROM sales.orders WHERE net_total > 5000;

/* Q32. */
CREATE OR REPLACE VIEW v_gold_platinum_customers AS
SELECT * FROM customers.customers WHERE tier IN ('Gold', 'Platinum');

/* Q33. */
CREATE OR REPLACE VIEW v_products_with_brand AS
SELECT p.product_id, p.product_name, p.price, b.brand_name, cat.category_name
FROM products.products p
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id;

/* Q34. */
CREATE OR REPLACE VIEW v_returns_with_customer AS
SELECT r.return_id, r.order_id, r.reason, r.refund_amount, c.customer_id, c.first_name, c.last_name
FROM sales.returns r
JOIN sales.orders o ON o.order_id = r.order_id
JOIN customers.customers c ON c.customer_id = o.cust_id;

/* Q35. */
CREATE OR REPLACE VIEW v_revenue_by_region AS
SELECT r.region_name, sum(o.net_total) AS total_revenue
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name;

/* Q36. */
CREATE OR REPLACE VIEW v_orders_2025 AS
SELECT * FROM sales.orders WHERE date_trunc('year', order_date) = '2025-01-01';

/* Q37. */
DROP VIEW IF EXISTS v_high_value_orders;

/* Q38. */
CREATE OR REPLACE VIEW v_orders_clean AS
SELECT order_id, cust_id, store_id, order_date, initcap(order_status) AS order_status, net_total
FROM sales.orders
WHERE order_status NOT IN ('Failed', 'Cancelled', 'Returned');

/* Q39. */
CREATE OR REPLACE VIEW v_employee_with_dept AS
SELECT e.employee_id, e.first_name, e.last_name, d.dept_name
FROM stores.employees e
JOIN core.dim_department d ON d.dept_id = e.dept_id;

/* Q40. */
CREATE OR REPLACE VIEW v_top_customers AS
SELECT cust_id, sum(net_total) AS lifetime_spend
FROM sales.orders
GROUP BY cust_id
ORDER BY lifetime_spend DESC
LIMIT 100;

/* Q41. */
CREATE OR REPLACE VIEW v_orders_with_items_count AS
SELECT o.order_id, count(oi.order_item_id) AS item_count
FROM sales.orders o
LEFT JOIN sales.order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id;

/* Q42. */
CREATE OR REPLACE VIEW v_active_stores AS
SELECT DISTINCT s.*
FROM stores.stores s
JOIN sales.orders o ON o.store_id = s.store_id;

/* Q43. */
CREATE OR REPLACE VIEW v_customer_latest_order AS
SELECT DISTINCT ON (cust_id) cust_id, order_id, order_date, net_total
FROM sales.orders
ORDER BY cust_id, order_date DESC;

/* Q44. */
CREATE OR REPLACE VIEW v_monthly_revenue AS
SELECT date_trunc('month', order_date)::date AS month, sum(net_total) AS revenue
FROM sales.orders
GROUP BY 1;

/* Q45. */
SELECT * FROM v_monthly_revenue WHERE extract(year FROM month) = 2025 ORDER BY month;

/* Q46. */
CREATE OR REPLACE VIEW v_tickets_open AS
SELECT * FROM support.tickets WHERE resolved_date IS NULL;

/* Q47. */
CREATE OR REPLACE VIEW v_pay_slip_clean AS
SELECT pay_slip_id, employee_id, to_date(salary_month || ' ' || salary_year, 'FMMonth YYYY') AS pay_period, net_salary
FROM payroll.pay_slips;

/* Q48. */
CREATE OR REPLACE VIEW v_reviews_clean AS
SELECT review_id, customer_id, product_id, rating, trim(review_text) AS review_text, review_date
FROM customers.reviews
WHERE rating IS NOT NULL;

/* Q49. */
SELECT 'v_delivered_orders' AS view_name, count(*) AS row_count FROM v_delivered_orders
UNION ALL SELECT 'v_orders_enriched', count(*) FROM v_orders_enriched
UNION ALL SELECT 'v_orders_clean', count(*) FROM v_orders_clean
UNION ALL SELECT 'v_gold_platinum_customers', count(*) FROM v_gold_platinum_customers
UNION ALL SELECT 'v_products_with_brand', count(*) FROM v_products_with_brand;

/* Q50. */
SELECT count(*) AS dependents
FROM pg_depend d
JOIN pg_rewrite r ON r.oid = d.objid
JOIN pg_class c ON c.oid = r.ev_class
WHERE d.refobjid = 'v_gold_platinum_customers'::regclass AND c.relname <> 'v_gold_platinum_customers';
-- 0 dependents confirmed, so it's safe to drop:
DROP VIEW IF EXISTS v_gold_platinum_customers;

/* ============================================================
   SECTION C: MATERIALIZED VIEWS (25)
   ------------------------------------------------------------ */
/* Q51. */
DROP MATERIALIZED VIEW IF EXISTS mv_monthly_revenue;
CREATE MATERIALIZED VIEW mv_monthly_revenue AS
SELECT date_trunc('month', order_date)::date AS month, sum(net_total) AS total_revenue, count(*) AS order_count
FROM sales.orders
GROUP BY 1;

/* Q52. */
REFRESH MATERIALIZED VIEW mv_monthly_revenue;

/* Q53. */
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_monthly_revenue_month ON mv_monthly_revenue(month);

/* Q54. */
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_revenue;

/* Q55. */
DROP MATERIALIZED VIEW IF EXISTS mv_revenue_by_region;
CREATE MATERIALIZED VIEW mv_revenue_by_region AS
SELECT r.region_id, r.region_name, sum(o.net_total) AS total_revenue
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_id, r.region_name;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_revenue_by_region ON mv_revenue_by_region(region_id);

/* Q56. */
DROP MATERIALIZED VIEW IF EXISTS mv_customer_lifetime;
CREATE MATERIALIZED VIEW mv_customer_lifetime AS
SELECT cust_id AS customer_id, count(*) AS total_orders, sum(net_total) AS total_revenue, max(order_date) AS latest_order
FROM sales.orders
GROUP BY cust_id;

/* Q57. */
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_customer_lifetime ON mv_customer_lifetime(customer_id);

/* Q58. */
DROP MATERIALIZED VIEW IF EXISTS mv_store_kpis;
CREATE MATERIALIZED VIEW mv_store_kpis AS
SELECT store_id, date_trunc('month', order_date)::date AS month, sum(net_total) AS revenue, count(*) AS order_count
FROM sales.orders
GROUP BY store_id, 2;

/* Q59. */
DROP MATERIALIZED VIEW IF EXISTS mv_product_sales;
CREATE MATERIALIZED VIEW mv_product_sales AS
SELECT prod_id AS product_id, sum(quantity) AS units_sold, sum(net_amount) AS revenue
FROM sales.order_items
GROUP BY prod_id;

/* Q60. */
DROP MATERIALIZED VIEW IF EXISTS mv_orders_with_items_count;
CREATE MATERIALIZED VIEW mv_orders_with_items_count AS
SELECT o.order_id, count(oi.order_item_id) AS item_count
FROM sales.orders o
LEFT JOIN sales.order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id;

/* Q61. */
DROP MATERIALIZED VIEW IF EXISTS mv_top_customers_by_year;
CREATE MATERIALIZED VIEW mv_top_customers_by_year AS
SELECT yr, cust_id, total_spend FROM (
  SELECT extract(year FROM order_date)::int AS yr, cust_id, sum(net_total) AS total_spend,
         row_number() OVER (PARTITION BY extract(year FROM order_date)::int ORDER BY sum(net_total) DESC) AS rn
  FROM sales.orders
  GROUP BY 1, 2
) ranked
WHERE rn <= 100;

/* Q62. */
DROP MATERIALIZED VIEW IF EXISTS mv_returns_by_category;
CREATE MATERIALIZED VIEW mv_returns_by_category AS
SELECT cat.category_name, count(*) AS returns, sum(r.refund_amount) AS refund_total
FROM sales.returns r
JOIN products.products p ON p.product_id = r.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
GROUP BY cat.category_name;

/* Q63. */
DROP MATERIALIZED VIEW IF EXISTS mv_calls_hourly;
CREATE MATERIALIZED VIEW mv_calls_hourly AS
SELECT extract(hour FROM call_start_time)::int AS hour_of_day, count(*) AS calls,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY call_duration_seconds) AS median_duration_sec
FROM call_center.calls
GROUP BY 1;

/* Q64. */
DROP MATERIALIZED VIEW IF EXISTS mv_page_views_hourly;
CREATE MATERIALIZED VIEW mv_page_views_hourly AS
SELECT extract(hour FROM view_timestamp)::int AS hour_of_day, device_type, count(*) AS page_views
FROM web_events.page_views
GROUP BY 1, 2;

/* Q65. */
DROP MATERIALIZED VIEW IF EXISTS mv_employee_salary_latest;
CREATE MATERIALIZED VIEW mv_employee_salary_latest AS
SELECT DISTINCT ON (employee_id) employee_id, amount, payment_date
FROM hr.salary_history
ORDER BY employee_id, payment_date DESC;

/* Q66. */
DROP MATERIALIZED VIEW IF EXISTS mv_inventory_latest;
CREATE MATERIALIZED VIEW mv_inventory_latest AS
SELECT DISTINCT ON (warehouse_id, product_id) warehouse_id, product_id, quantity_on_hand, snapshot_date
FROM supply_chain.inventory_snapshots
ORDER BY warehouse_id, product_id, snapshot_date DESC;

/* Q67. */
CREATE INDEX IF NOT EXISTS ix_mv_inventory_latest ON mv_inventory_latest(warehouse_id, product_id);

/* Q68. */
REFRESH MATERIALIZED VIEW mv_inventory_latest;
SELECT count(*) AS row_count FROM mv_inventory_latest;

/* Q69. */
DROP MATERIALIZED VIEW IF EXISTS mv_ticket_priority_counts;
CREATE MATERIALIZED VIEW mv_ticket_priority_counts AS
SELECT priority, count(*) AS tickets FROM support.tickets GROUP BY priority
WITH NO DATA;
REFRESH MATERIALIZED VIEW mv_ticket_priority_counts;

/* Q70. */
DROP MATERIALIZED VIEW IF EXISTS mv_ticket_priority_counts;

/* Q71. */
DROP MATERIALIZED VIEW IF EXISTS mv_revenue_quarterly;
CREATE MATERIALIZED VIEW mv_revenue_quarterly AS
SELECT r.region_id, date_trunc('quarter', o.order_date)::date AS quarter, sum(o.net_total) AS revenue
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_id, 2;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_revenue_quarterly ON mv_revenue_quarterly(region_id, quarter);

/* Q72. */
DROP MATERIALIZED VIEW IF EXISTS mv_ticket_sla;
CREATE MATERIALIZED VIEW mv_ticket_sla AS
SELECT priority,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY extract(epoch FROM (resolved_date - created_date)) / 3600.0) AS median_hours,
       percentile_cont(0.95) WITHIN GROUP (ORDER BY extract(epoch FROM (resolved_date - created_date)) / 3600.0) AS p95_hours
FROM support.tickets
WHERE resolved_date IS NOT NULL
GROUP BY priority;

/* Q73. */
DROP MATERIALIZED VIEW IF EXISTS mv_daily_revenue;
CREATE MATERIALIZED VIEW mv_daily_revenue AS
SELECT d.day::date AS d, coalesce(sum(o.net_total), 0) AS revenue
FROM generate_series((SELECT min(order_date) FROM sales.orders), (SELECT max(order_date) FROM sales.orders), interval '1 day') AS d(day)
LEFT JOIN sales.orders o ON o.order_date = d.day::date
GROUP BY d.day;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_daily_revenue ON mv_daily_revenue(d);

/* Q74. */
SELECT (SELECT sum(net_total) FROM sales.orders) AS live_total,
       (SELECT sum(total_revenue) FROM mv_monthly_revenue) AS mv_total;

/* Q75. */
EXPLAIN ANALYZE SELECT * FROM mv_monthly_revenue WHERE month = '2025-06-01';

/* ============================================================
   SECTION D: LAYERED STACK & MAINTENANCE (25)
   ------------------------------------------------------------ */
/* Q76. */
CREATE OR REPLACE VIEW v_orders_raw AS
SELECT order_id, cust_id AS customer_id, store_id, order_date, order_status AS status, net_total
FROM sales.orders;

/* Q77. */
CREATE OR REPLACE VIEW v_orders_clean_stack AS
SELECT order_id, customer_id, store_id, order_date, initcap(status) AS status, net_total
FROM v_orders_raw
WHERE status NOT IN ('Failed', 'Cancelled');

/* Q78. */
CREATE OR REPLACE VIEW v_monthly_revenue_kpis AS
SELECT date_trunc('month', order_date)::date AS month, sum(net_total) AS revenue, count(*) AS orders
FROM v_orders_clean_stack
GROUP BY 1;

/* Q79. */
SELECT DISTINCT dep_view.relname AS dependent_view
FROM pg_depend d
JOIN pg_rewrite r ON r.oid = d.objid
JOIN pg_class dep_view ON dep_view.oid = r.ev_class
JOIN pg_class base_view ON base_view.oid = d.refobjid
WHERE base_view.relname = 'v_orders_raw' AND dep_view.relname <> 'v_orders_raw';

/* Q80. */
DROP MATERIALIZED VIEW IF EXISTS mv_monthly_revenue_kpis;
CREATE MATERIALIZED VIEW mv_monthly_revenue_kpis AS
SELECT month, revenue, orders FROM v_monthly_revenue_kpis;

/* Q81. */
DROP VIEW IF EXISTS v_monthly_revenue_kpis;
DROP MATERIALIZED VIEW IF EXISTS v_monthly_revenue_kpis_mv;
CREATE MATERIALIZED VIEW v_monthly_revenue_kpis_mv AS
SELECT date_trunc('month', order_date)::date AS month, sum(net_total) AS revenue, count(*) AS orders
FROM v_orders_clean_stack
GROUP BY 1;

/* Q82. */
CREATE OR REPLACE VIEW v_returns_raw AS
SELECT return_id, order_id, prod_id AS product_id, return_date, reason, refund_amount FROM sales.returns;
CREATE OR REPLACE VIEW v_returns_clean AS
SELECT * FROM v_returns_raw WHERE refund_amount IS NOT NULL;
DROP MATERIALIZED VIEW IF EXISTS mv_returns_metrics;
CREATE MATERIALIZED VIEW mv_returns_metrics AS
SELECT cat.category_name, count(*) AS returns, sum(rc.refund_amount) AS refund_total
FROM v_returns_clean rc
JOIN products.products p ON p.product_id = rc.product_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
GROUP BY cat.category_name;

/* Q83. */
CREATE OR REPLACE VIEW v_tickets_raw AS
SELECT ticket_id, customer_id, priority, created_date, resolved_date FROM support.tickets;
CREATE OR REPLACE VIEW v_tickets_clean AS
SELECT * FROM v_tickets_raw WHERE priority IS NOT NULL;
DROP MATERIALIZED VIEW IF EXISTS mv_ticket_sla_dashboard;
CREATE MATERIALIZED VIEW mv_ticket_sla_dashboard AS
SELECT priority,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY extract(epoch FROM (resolved_date - created_date)) / 3600.0) AS median_hours,
       percentile_cont(0.95) WITHIN GROUP (ORDER BY extract(epoch FROM (resolved_date - created_date)) / 3600.0) AS p95_hours
FROM v_tickets_clean
WHERE resolved_date IS NOT NULL
GROUP BY priority;

/* Q84. The metrics layer (v_monthly_revenue_kpis) is the heaviest aggregate - it scans and GROUPs every order - so it's the best MV candidate; raw and cleaned layers are cheap passthrough/filter views best left live so they always reflect the current base data. */
/* Q85. Refresh bottom-up: an MV built on top of another MV (or a view chain) must have its upstream data settled first, so refresh the lowest-level MVs before the ones that aggregate from them - refreshing top-down risks the higher MV reading stale/incomplete upstream data. */
/* Q86. */
SELECT DISTINCT dep_view.relname AS dependent_view
FROM pg_depend d
JOIN pg_rewrite r ON r.oid = d.objid
JOIN pg_class dep_view ON dep_view.oid = r.ev_class
JOIN pg_class base_view ON base_view.oid = d.refobjid
WHERE base_view.relname = 'v_orders_clean_stack' AND dep_view.relname <> 'v_orders_clean_stack';

/* Q87. */
CREATE OR REPLACE VIEW v_scratch_test AS SELECT 1 AS x;
CREATE OR REPLACE VIEW v_scratch_test_dependent AS SELECT x FROM v_scratch_test;
DROP VIEW v_scratch_test CASCADE;
-- v_scratch_test_dependent was dropped too, since it depended on v_scratch_test; recreate both:
CREATE OR REPLACE VIEW v_scratch_test AS SELECT 1 AS x;
CREATE OR REPLACE VIEW v_scratch_test_dependent AS SELECT x FROM v_scratch_test;
DROP VIEW IF EXISTS v_scratch_test_dependent;
DROP VIEW IF EXISTS v_scratch_test;

/* Q88. monthly_revenue_kpis is consumed by an exec/monthly report, so a daily refresh (e.g. after the nightly ETL window) is sufficient - it doesn't need hourly refresh since month-to-date figures don't meaningfully change minute to minute for a monthly-grain metric. */
/* Q89. */
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_monthly_revenue_kpis ON mv_monthly_revenue_kpis(month);

/* Q90. A stale-but-fast MV read (skip REFRESH before every query) risks showing outdated numbers but never blocks readers; REFRESH CONCURRENTLY keeps the MV close to current with zero read-blocking, at the cost of needing a unique index and doing more work per refresh - the tradeoff is staleness tolerance vs refresh overhead. */
/* Q91. */
CREATE OR REPLACE VIEW v_customer_360 AS
SELECT c.customer_id, c.first_name || ' ' || c.last_name AS full_name, c.tier,
       (SELECT count(*) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS order_count,
       (SELECT max(order_date) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS latest_order
FROM customers.customers c;

/* Q92. */
DROP MATERIALIZED VIEW IF EXISTS mv_daily_revenue_ma;
CREATE MATERIALIZED VIEW mv_daily_revenue_ma AS
SELECT d, revenue, avg(revenue) OVER (ORDER BY d ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS ma_7day
FROM mv_daily_revenue;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_daily_revenue_ma ON mv_daily_revenue_ma(d);

/* Q93. */
DROP MATERIALIZED VIEW IF EXISTS mv_region_net_total_percentiles;
CREATE MATERIALIZED VIEW mv_region_net_total_percentiles AS
SELECT r.region_id,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_net_total,
       percentile_cont(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_net_total
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_id;

/* Q94. */
DROP MATERIALIZED VIEW IF EXISTS mv_region_month_revenue_pivot;
CREATE MATERIALIZED VIEW mv_region_month_revenue_pivot AS
SELECT r.region_id,
       sum(o.net_total) FILTER (WHERE extract(month FROM o.order_date) = 1) AS jan,
       sum(o.net_total) FILTER (WHERE extract(month FROM o.order_date) = 2) AS feb,
       sum(o.net_total) FILTER (WHERE extract(month FROM o.order_date) = 3) AS mar
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
WHERE extract(year FROM o.order_date) = 2025
GROUP BY r.region_id;

/* Q95. */
DROP MATERIALIZED VIEW IF EXISTS mv_exec_kpi_strip;
CREATE MATERIALIZED VIEW mv_exec_kpi_strip AS
SELECT count(*) AS orders,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY net_total) AS median_order_value,
       percentile_cont(0.95) WITHIN GROUP (ORDER BY net_total) AS p95_order_value,
       max(order_date) AS latest_order
FROM sales.orders;

/* Q96. COMMENT ON MATERIALIZED VIEW mv_monthly_revenue IS 'Refresh cadence: daily at 02:00 UTC after nightly ETL. Grain: one row per month. Owner: analytics team.'; */
COMMENT ON MATERIALIZED VIEW mv_monthly_revenue IS 'Refresh cadence: daily at 02:00 UTC after nightly ETL. Grain: one row per month. Owner: analytics team.';

/* Q97. */
SELECT (SELECT count(*) FROM v_delivered_orders) AS view_count,
       (SELECT count(*) FROM sales.orders WHERE order_status = 'Delivered') AS base_count;

/* Q98. */
SELECT matviewname FROM pg_matviews WHERE schemaname = 'public' ORDER BY matviewname;
DROP MATERIALIZED VIEW IF EXISTS mv_monthly_revenue CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_revenue_by_region CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_customer_lifetime CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_store_kpis CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_product_sales CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_orders_with_items_count CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_top_customers_by_year CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_returns_by_category CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_calls_hourly CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_page_views_hourly CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_employee_salary_latest CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_inventory_latest CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_revenue_quarterly CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_ticket_sla CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_daily_revenue CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_monthly_revenue_kpis CASCADE;
DROP MATERIALIZED VIEW IF EXISTS v_monthly_revenue_kpis_mv CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_returns_metrics CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_ticket_sla_dashboard CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_daily_revenue_ma CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_region_net_total_percentiles CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_region_month_revenue_pivot CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_exec_kpi_strip CASCADE;

/* Q99. */
DROP VIEW IF EXISTS v_customer_360 CASCADE;
DROP VIEW IF EXISTS v_tickets_clean CASCADE;
DROP VIEW IF EXISTS v_tickets_raw CASCADE;
DROP VIEW IF EXISTS v_returns_clean CASCADE;
DROP VIEW IF EXISTS v_returns_raw CASCADE;
DROP VIEW IF EXISTS v_monthly_revenue_kpis CASCADE;
DROP VIEW IF EXISTS v_orders_clean_stack CASCADE;
DROP VIEW IF EXISTS v_orders_raw CASCADE;
DROP VIEW IF EXISTS v_reviews_clean CASCADE;
DROP VIEW IF EXISTS v_pay_slip_clean CASCADE;
DROP VIEW IF EXISTS v_tickets_open CASCADE;
DROP VIEW IF EXISTS v_monthly_revenue CASCADE;
DROP VIEW IF EXISTS v_customer_latest_order CASCADE;
DROP VIEW IF EXISTS v_active_stores CASCADE;
DROP VIEW IF EXISTS v_orders_with_items_count CASCADE;
DROP VIEW IF EXISTS v_top_customers CASCADE;
DROP VIEW IF EXISTS v_employee_with_dept CASCADE;
DROP VIEW IF EXISTS v_orders_2025 CASCADE;
DROP VIEW IF EXISTS v_revenue_by_region CASCADE;
DROP VIEW IF EXISTS v_returns_with_customer CASCADE;
DROP VIEW IF EXISTS v_products_with_brand CASCADE;
DROP VIEW IF EXISTS v_orders_clean CASCADE;
DROP VIEW IF EXISTS v_orders_enriched CASCADE;
DROP VIEW IF EXISTS v_customer_full_name CASCADE;
DROP VIEW IF EXISTS v_delivered_orders CASCADE;

/* Q100. */
CREATE OR REPLACE VIEW v_orders_raw AS
SELECT order_id, cust_id AS customer_id, store_id, order_date, order_status AS status, net_total
FROM sales.orders;
CREATE OR REPLACE VIEW v_orders_clean_stack AS
SELECT order_id, customer_id, store_id, order_date, initcap(status) AS status, net_total
FROM v_orders_raw
WHERE status NOT IN ('Failed', 'Cancelled');
CREATE OR REPLACE VIEW v_monthly_revenue_kpis AS
SELECT date_trunc('month', order_date)::date AS month, sum(net_total) AS revenue, count(*) AS orders
FROM v_orders_clean_stack
GROUP BY 1;

/* ============================================================
   END OF ANSWER KEY - EASY LEVEL (100/100)
============================================================ */
