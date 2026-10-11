/* ============================================================
   ANSWER KEY - CTEs (WITH, non-recursive) (HARD LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: INLINING vs MATERIALIZED (25)
   ------------------------------------------------------------ */
/* Q1.  Since PG12, a CTE referenced exactly once with no side effects is auto-inlined into the outer query like a plain subquery; one referenced more than once, or containing DML/volatile constructs, is auto-materialized. */
/* Q2.  WITH name AS NOT MATERIALIZED (...) forces the planner to fold the CTE into the outer query even if referenced multiple times, enabling predicate pushdown at the cost of recomputing it per reference. */
/* Q3.  WITH name AS MATERIALIZED (...) forces the planner to compute the CTE once into a buffered result and treat it as an optimization fence, even if referenced only once. */
/* Q4.  Inlining wins when the CTE is cheap to recompute, referenced once, and the outer query has selective predicates that can be pushed into it to avoid scanning rows the CTE would otherwise materialize in full. */
/* Q5.  Materialization wins when the CTE is expensive (heavy aggregation/joins) and referenced multiple times, or when you deliberately want an optimization fence to stabilize a plan. */
/* Q6.  Yes - by default (PG12+) a CTE referenced two or more times is automatically materialized unless explicitly marked NOT MATERIALIZED. */
/* Q7.  With 5 references, materializing pays the CTE's cost once instead of five times, so the planner (and a human overriding it) should almost always prefer MATERIALIZED here. */
/* Q8.  A CTE containing INSERT/UPDATE/DELETE (a writeable CTE) is always materialized/executed exactly once, since inlining it would risk running the side-effecting statement multiple times. */
/* Q9.  A CTE calling a VOLATILE function (e.g. random(), nextval()) is always materialized, because inlining could call the function once per outer-row reference and silently change the result. */
/* Q10. If a CTE using random() is materialized, every reference sees the same fixed random values computed once; inlining it could instead produce different random values per reference - materialization is what guarantees consistency, which is why Postgres forces it. */
/* Q11. now() is STABLE (fixed for the whole transaction), so materializing vs inlining a CTE using it doesn't change the value returned; unlike volatile functions, now() doesn't force materialization by itself. */
/* Q12. A CTE with an inner LIMIT can still be inlined if referenced once, and PostgreSQL preserves the LIMIT's semantics; it only inlines when doing so remains safe for that LIMIT. */
/* Q13. A writeable CTE (INSERT/UPDATE/DELETE) is always executed once as its own step and its RETURNING rows are then exposed to the outer query - inlining a DML CTE isn't safe or even meaningful. */
/* Q14. A WITH RECURSIVE term is always evaluated iteratively and materialized (its working table is built up incrementally); inlining wouldn't make sense since the recursive term must re-read its own accumulated results. */
/* Q15. A CTE inside a view definition follows the same inline/materialize rules as any query - PostgreSQL decides based on reference count and side effects each time the view is queried, since the view itself isn't materialized. */
/* Q16. A CTE inside a function body follows the same planner rules as ad-hoc SQL; each execution applies the same inline/materialize logic, whether using a cached generic plan or a fresh custom one. */
/* Q17. In a prepared statement, the inline/materialize decision is made when the plan is generated (generic or custom), and can be re-evaluated if PostgreSQL later switches between generic and custom plans. */
/* Q18. A CTE referencing a bound parameter is planned the same way as any parameterized query - the inline/materialize choice doesn't change because a parameter is involved, though a custom plan may pick different scans per value. */
/* Q19. A "CTE Scan" node in EXPLAIN ANALYZE means that CTE was materialized; its own cost/actual-time figures show the cost of computing and buffering it, separate from the cost of scanning it afterward. */
/* Q20. Run EXPLAIN (ANALYZE) once with the default WITH name AS (...) and once with the opposite MATERIALIZED/NOT MATERIALIZED hint, then compare whether a "CTE Scan" node appears and whether outer predicates were pushed down in the inlined version. */
/* Q21. If a CTE is inlined, an outer WHERE filter on one of its columns can be pushed down into the CTE's own scan, letting an index or a smaller scan satisfy both at once instead of materializing every row first. */
/* Q22. With NOT MATERIALIZED (or auto-inline), outer predicates get pushed into the CTE before it runs; with MATERIALIZED, the CTE computes its full result first and the predicate is applied afterward as a separate filter step. */
/* Q23. An ORDER BY inside a CTE's own SELECT is preserved for that CTE's result, but the outer query still needs its own ORDER BY if it needs a guaranteed order on the final output. */
/* Q24. A LIMIT inside a CTE limits that CTE's own result set before it's exposed to the outer query; when the CTE is inlined, PostgreSQL can sometimes combine that with an outer LIMIT to stop scanning early. */
/* Q25. PostgreSQL has no query-hint comment syntax like Oracle/MySQL's inline optimizer hints - the only "hint"-like levers for CTEs are the MATERIALIZED/NOT MATERIALIZED keywords themselves; everything else is left to the cost-based planner. */

/* ============================================================
   SECTION B: MATERIALIZED MV vs CTE (25)
   ------------------------------------------------------------ */
/* Q26. Use a CTE for a one-off query that needs the intermediate result only within that statement; use a materialized view when many different queries/dashboards repeatedly need the same expensive aggregate and can tolerate periodically-refreshed data. */
/* Q27. A dashboard hit by many users running the same expensive aggregate benefits from a materialized view because the heavy computation runs once per REFRESH, and every dashboard load is then a fast read of pre-computed rows. */
/* Q28. A CTE is the right tool for a one-off analyst query because it needs no DDL, no refresh schedule, and always reflects live data - there's no persistence overhead to manage for a query you'll run once. */
/* Q29. A materialized view is refreshed on a schedule (e.g. via pg_cron or an external job) or on demand with REFRESH MATERIALIZED VIEW [CONCURRENTLY], trading data freshness for read speed between refreshes. */
/* Q30. A regular (non-materialized) VIEW can contain a WITH clause; it recomputes the CTE's logic on every query against the view since the view itself stores no data. */
/* Q31. A view can also be built to SELECT from a materialized view, layering a friendly interface on top of pre-computed, refreshable data - common when several views need to share the same expensive base aggregate. */
/* Q32. Refactor a nested subquery into a CTE when the logic is reused, when naming the intermediate step would make the query self-documenting, or when you want to reason about/debug that step in isolation. */
/* Q33. Naming a step as a CTE lets you temporarily change the final SELECT to "SELECT * FROM cte_name" to inspect its intermediate output while debugging, which is far harder with a deeply nested subquery. */
/* Q34. A CTE chain reads top-to-bottom in the order a human reasons about a problem (raw -> filtered -> aggregated -> ranked), rather than the inside-out reading order a nested subquery forces. */
/* Q35. A materialized view turns an expensive repeated computation into a one-time cost (at refresh time) plus cheap reads afterward, which a CTE can never do since it always recomputes live. */
/* Q36. EXPLAIN on a query using WITH name AS MATERIALIZED (...) shows an explicit "CTE Scan" node for that CTE, with its own Startup/Total cost representing the one-time computation, separate from scans of it afterward. */
/* Q37. A CTE that itself builds a Hash Join or HashAggregate internally is bound by work_mem for that node just like anywhere else in a plan; materializing the CTE doesn't change the memory used by nodes inside it. */
/* Q38. If a CTE's inner SELECT does a large ORDER BY that exceeds work_mem, its Sort node spills to disk (external merge) exactly as it would in a non-CTE query - materializing doesn't exempt the CTE's own nodes from spilling. */
/* Q39. EXPLAIN ANALYZE shows "Sort Method: external merge  Disk: NNkB" when a CTE's internal sort spills; raising work_mem (per-session or per-query) lets more of that sort happen in memory instead. */
/* Q40. pg_stat_statements tracks normalized query text and aggregate timing/row stats per statement, including queries built from CTEs, letting you see which CTE-containing statements are heaviest across many executions. */
/* Q41. A CTE with a window function recomputes the ranking/aggregate on every run against live data; a materialized view with an index on the pre-computed rank column serves the same "top-N" answer far faster but only as fresh as the last refresh. */
/* Q42. A query can define a CTE that SELECTs from a materialized view and further filters/joins it, combining the MV's precomputed speed with the CTE's readability for the remaining live logic. */
/* Q43. CREATE MATERIALIZED VIEW mv_name AS WITH ... SELECT ... lets the view definition itself use CTEs internally; they're evaluated once at CREATE/REFRESH time and their result is what gets persisted. */
/* Q44. REFRESH MATERIALIZED VIEW CONCURRENTLY rebuilds the MV without locking out concurrent readers (it requires a unique index on the MV first), unlike a plain REFRESH which briefly blocks reads. */
/* Q45. You can CREATE INDEX on a materialized view's columns just like a real table, since an MV physically stores rows - this is often exactly what makes MV reads fast enough to replace a repeated CTE. */
/* Q46. A materialized view itself can't be partitioned in PostgreSQL, but its underlying query can source from partitioned tables, and very large MVs are sometimes replaced with a partitioned regular table refreshed by a scheduled job instead. */
/* Q47. You check an MV's staleness by comparing its last REFRESH time (tracked externally, since pg_matviews doesn't store it) against how fresh the business need requires, often via a metadata/audit table updated by the refresh job. */
/* Q48. A plain materialized view must be fully (or CONCURRENTLY) refreshed on a schedule; a continuous aggregate (a TimescaleDB feature, not built into core PostgreSQL) incrementally updates itself as new rows arrive, avoiding full recomputation. */
/* Q49. BI dashboards commonly query materialized views instead of raw fact tables because the MV precomputes the heavy joins/aggregates once, so many dashboard users get sub-second reads instead of each one re-running the expensive query. */
/* Q50. A reporting layer often stacks several materialized views (e.g. daily_sales_mv feeding monthly_sales_mv) refreshed in dependency order by a scheduler, giving analysts fast, stable numbers without hitting live transactional tables. */

/* ============================================================
   SECTION C: ETL PRODUCTION (25)
   ------------------------------------------------------------ */
/* Q51. Multi-stage ETL pipelines chain CTEs (raw -> cleansed -> enriched -> loaded), writing one row to an audit/log table after each writeable-CTE stage so every stage's outcome and row count stays traceable. */
/* Q52. Incremental load with checkpoint stores the last-loaded watermark (e.g. MAX(loaded_at) or an id) in a checkpoint table; the next run's CTE filters source rows WHERE ts > watermark, then advances the checkpoint after a successful load. */
/* Q53. A CDC consumer with state tracks the last-processed LSN/sequence/id in a state table, reads new change events since that point, applies them via a writeable CTE, and advances the state only after a successful commit. */
/* Q54. Stream-to-batch ETL buffers a continuous stream of events into micro-batches (e.g. by arrival-time window) and periodically runs one batched INSERT/UPDATE CTE over the accumulated buffer instead of processing row by row. */
/* Q55. SCD Type 2 keeps full history by closing the current row (SET valid_to = now(), is_current = false) and inserting a fresh row with the new attribute values and is_current = true, both via one writeable-CTE statement. */
/* Q56. Snapshot generation periodically INSERTs the full current state of a table (e.g. inventory) into a dated snapshot table, giving point-in-time queryability without altering the source. */
/* Q57. Dimension load upserts (INSERT ... ON CONFLICT DO UPDATE) the latest attribute values for each dimension key, so downstream fact tables always see current, deduplicated dimension rows. */
/* Q58. Fact load appends new transactional rows (typically append-only, rarely updated) keyed by a natural or surrogate key, usually guarded with ON CONFLICT DO NOTHING to make re-runs idempotent. */
/* Q59. The data-quality stage checks each row against rules (not-null, range, referential) in a CTE and either drops/quarantines failing rows or flags them with a dq_flag column before they reach the load stage. */
/* Q60. Deduplication stage uses DISTINCT ON (natural_key) ORDER BY natural_key, updated_at DESC inside a CTE to keep only the latest version of each duplicated row before loading. */
/* Q61. Cleanse stage trims whitespace, normalizes case, fixes obvious type errors and replaces blanks with NULL/defaults inside a CTE, isolating "data hygiene" logic from business logic. */
/* Q62. Enrich stage JOINs the staged rows to reference/dimension tables inside a CTE to attach descriptive attributes (region name, category, tier) the raw source didn't carry. */
/* Q63. Aggregate stage GROUP BYs the enriched rows into the grain the target fact/report needs (e.g. daily per-store revenue) before the final load CTE writes it. */
/* Q64. Publish stage is the final writeable CTE that INSERTs/UPSERTs the finished rows into the production/reporting table, typically the only stage allowed to touch that table. */
/* Q65. Archive stage moves rows being retired (old, cancelled, expired) out of the live table into a history/archive table via a DELETE ... RETURNING CTE feeding an INSERT. */
/* Q66. An ETL step is retry-safe when re-running it after a partial failure produces the same end state rather than duplicating or corrupting data - achieved with idempotent upserts and watermark checks rather than blind appends. */
/* Q67. An ETL step is idempotent when running it twice with the same input leaves the database in the same state as running it once, typically via ON CONFLICT DO UPDATE/DO NOTHING keyed on a natural key instead of a blind INSERT. */
/* Q68. An ETL step is parallel-safe when multiple workers can run it concurrently on disjoint row ranges without contending for or double-processing the same rows, often achieved with FOR UPDATE SKIP LOCKED or partitioned key ranges. */

CREATE TEMP TABLE tmp3_orders AS SELECT * FROM sales.orders LIMIT 500;
CREATE TEMP TABLE tmp3_order_archive (LIKE sales.orders INCLUDING ALL);

/* Q69. */
WITH claimed AS (
  SELECT order_id FROM tmp3_orders WHERE order_status = 'Processing' ORDER BY order_id FOR UPDATE SKIP LOCKED LIMIT 50
)
UPDATE tmp3_orders o SET order_status = 'Shipped' FROM claimed c WHERE o.order_id = c.order_id
RETURNING o.order_id;

/* Q70. */
SELECT pg_try_advisory_lock(424242) AS lock_acquired, pg_advisory_unlock(424242) AS lock_released;

/* Q71. */
WITH batch AS (
  SELECT order_id FROM tmp3_orders WHERE order_status = 'Cancelled' ORDER BY order_id LIMIT 200
)
DELETE FROM tmp3_orders WHERE order_id IN (SELECT order_id FROM batch);

/* Q72. */
WITH batch AS (
  SELECT * FROM sales.orders WHERE order_status = 'Returned' ORDER BY order_id LIMIT 200
)
INSERT INTO tmp3_order_archive SELECT * FROM batch
ON CONFLICT (order_id) DO NOTHING;

/* Q73. */
WITH daily AS (
  SELECT order_date, SUM(net_total) AS revenue FROM sales.orders GROUP BY order_date
)
SELECT order_date, revenue,
       AVG(revenue) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS rolling_7d_avg
FROM daily ORDER BY order_date LIMIT 200;

/* Q74. */
WITH late_shipments AS (
  SELECT o.order_id, o.order_date, s.shipped_date, s.shipped_date - o.order_date AS delay_days
  FROM sales.orders o JOIN sales.shipments s ON s.order_id = o.order_id
  WHERE s.shipped_date - o.order_date > 10
)
SELECT * FROM late_shipments ORDER BY delay_days DESC LIMIT 100;

/* Q75. */
WITH backfill_range AS (
  SELECT generate_series('2024-01-01'::date, '2024-01-31'::date, interval '1 day')::date AS order_date
)
SELECT br.order_date, COALESCE(SUM(o.net_total), 0) AS revenue
FROM backfill_range br
LEFT JOIN sales.orders o ON o.order_date = br.order_date
GROUP BY br.order_date
ORDER BY br.order_date;

/* ============================================================
   SECTION D: REAL REPORTS (25)
   ------------------------------------------------------------ */
/* Q76. */
WITH cohort AS (
  SELECT customer_id, date_trunc('month', registration_date) AS cohort_month FROM customers.customers
),
activity AS (
  SELECT cust_id, date_trunc('month', order_date) AS order_month FROM sales.orders
),
cohort_activity AS (
  SELECT c.cohort_month, a.order_month, COUNT(DISTINCT a.cust_id) AS active_customers,
         (EXTRACT(YEAR FROM age(a.order_month, c.cohort_month)) * 12
          + EXTRACT(MONTH FROM age(a.order_month, c.cohort_month)))::int AS months_since_signup
  FROM cohort c JOIN activity a ON a.cust_id = c.customer_id
  GROUP BY c.cohort_month, a.order_month
),
cohort_size AS (
  SELECT cohort_month, COUNT(*) AS cohort_customers FROM cohort GROUP BY cohort_month
)
SELECT ca.cohort_month, ca.months_since_signup, ca.active_customers, cs.cohort_customers,
       ROUND(ca.active_customers::numeric / cs.cohort_customers, 3) AS retention_rate
FROM cohort_activity ca
JOIN cohort_size cs ON cs.cohort_month = ca.cohort_month
ORDER BY ca.cohort_month, ca.months_since_signup
LIMIT 200;

/* Q77. */
WITH rfm_base AS (
  SELECT cust_id,
         (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS recency_days,
         COUNT(*) AS frequency,
         SUM(net_total) AS monetary
  FROM sales.orders GROUP BY cust_id
),
rfm_scored AS (
  SELECT *,
         NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
         NTILE(5) OVER (ORDER BY frequency) AS f_score,
         NTILE(5) OVER (ORDER BY monetary) AS m_score
  FROM rfm_base
)
SELECT cust_id, recency_days, frequency, monetary, r_score, f_score, m_score,
       (r_score + f_score + m_score) AS rfm_total
FROM rfm_scored
ORDER BY rfm_total DESC
LIMIT 100;

/* Q78. */
WITH viewed AS (
  SELECT DISTINCT customer_id FROM web_events.page_views WHERE customer_id IS NOT NULL
),
clicked AS (
  SELECT DISTINCT pv.customer_id
  FROM web_events.events e JOIN web_events.page_views pv ON pv.view_id = e.view_id
  WHERE e.event_type = 'click' AND pv.customer_id IS NOT NULL
),
ordered AS (
  SELECT DISTINCT cust_id AS customer_id FROM sales.orders
)
SELECT
  (SELECT COUNT(*) FROM viewed) AS stage_viewed,
  (SELECT COUNT(*) FROM clicked) AS stage_clicked,
  (SELECT COUNT(*) FROM ordered) AS stage_ordered;

/* Q79. */
WITH scored AS (
  SELECT review_id, rating,
         CASE WHEN rating >= 4 THEN 'promoter' WHEN rating = 3 THEN 'passive' ELSE 'detractor' END AS nps_bucket
  FROM customers.reviews
)
SELECT
  ROUND(100.0 * COUNT(*) FILTER (WHERE nps_bucket = 'promoter') / COUNT(*), 1)
  - ROUND(100.0 * COUNT(*) FILTER (WHERE nps_bucket = 'detractor') / COUNT(*), 1) AS nps_score
FROM scored;

/* Q80. */
WITH last_order AS (
  SELECT cust_id, MAX(order_date) AS last_order_date FROM sales.orders GROUP BY cust_id
),
churn_flag AS (
  SELECT cust_id, last_order_date,
         CASE WHEN last_order_date < (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '90 days' THEN TRUE ELSE FALSE END AS is_churned
  FROM last_order
)
SELECT is_churned, COUNT(*) AS customer_count FROM churn_flag GROUP BY is_churned;

/* Q81. */
WITH ranked AS (
  SELECT cat.category_name, p.product_id, p.product_name, SUM(oi.net_amount) AS revenue,
         ROW_NUMBER() OVER (PARTITION BY cat.category_name ORDER BY SUM(oi.net_amount) DESC) AS rn
  FROM sales.order_items oi
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
  GROUP BY cat.category_name, p.product_id, p.product_name
)
SELECT * FROM ranked WHERE rn <= 3 ORDER BY category_name, rn;

/* Q82. */
WITH store_metrics AS (
  SELECT s.store_id, s.store_name, COUNT(o.order_id) AS order_count, SUM(o.net_total) AS revenue, AVG(o.net_total) AS avg_order_value
  FROM stores.stores s JOIN sales.orders o ON o.store_id = s.store_id
  GROUP BY s.store_id, s.store_name
)
SELECT *, RANK() OVER (ORDER BY revenue DESC) AS revenue_rank, RANK() OVER (ORDER BY order_count DESC) AS volume_rank
FROM store_metrics
ORDER BY revenue_rank
LIMIT 20;

/* Q83. */
WITH order_status_by_region AS (
  SELECT r.region_name, o.order_status, COUNT(*) AS cnt
  FROM sales.orders o JOIN stores.stores s ON o.store_id = s.store_id JOIN core.dim_region r ON r.region_id = s.region_id
  GROUP BY r.region_name, o.order_status
)
SELECT region_name,
       SUM(cnt) FILTER (WHERE order_status = 'Delivered') AS delivered,
       SUM(cnt) FILTER (WHERE order_status = 'Cancelled') AS cancelled,
       SUM(cnt) FILTER (WHERE order_status = 'Returned') AS returned
FROM order_status_by_region
GROUP BY region_name
ORDER BY region_name;

/* Q84. */
WITH wide AS (
  SELECT tier, COUNT(*) AS customer_count FROM customers.customers GROUP BY tier
),
unpivoted AS (
  SELECT 'Bronze' AS tier_label, (SELECT customer_count FROM wide WHERE tier = 'Bronze') AS cnt
  UNION ALL
  SELECT 'Silver', (SELECT customer_count FROM wide WHERE tier = 'Silver')
  UNION ALL
  SELECT 'Gold', (SELECT customer_count FROM wide WHERE tier = 'Gold')
  UNION ALL
  SELECT 'Platinum', (SELECT customer_count FROM wide WHERE tier = 'Platinum')
)
SELECT * FROM unpivoted ORDER BY tier_label;

/* Q85. */
WITH tier_status AS (
  SELECT c.tier, o.order_status, COUNT(*) AS cnt
  FROM sales.orders o JOIN customers.customers c ON c.customer_id = o.cust_id
  GROUP BY c.tier, o.order_status
)
SELECT tier,
       SUM(cnt) FILTER (WHERE order_status = 'Delivered') AS delivered,
       SUM(cnt) FILTER (WHERE order_status = 'Cancelled') AS cancelled,
       SUM(cnt) FILTER (WHERE order_status = 'Returned') AS returned,
       SUM(cnt) AS total
FROM tier_status
GROUP BY tier
ORDER BY tier;

/* Q86. */
WITH daily AS (
  SELECT order_date, SUM(net_total) AS revenue FROM sales.orders GROUP BY order_date
)
SELECT date_trunc('month', order_date) AS month, SUM(revenue) AS monthly_revenue
FROM daily GROUP BY date_trunc('month', order_date) ORDER BY month;

/* Q87. */
WITH yearly AS (
  SELECT EXTRACT(YEAR FROM order_date)::int AS yr, SUM(net_total) AS revenue FROM sales.orders GROUP BY EXTRACT(YEAR FROM order_date)
)
SELECT yr, revenue, LAG(revenue) OVER (ORDER BY yr) AS prev_year_revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY yr)) / LAG(revenue) OVER (ORDER BY yr), 1) AS yoy_pct_change
FROM yearly ORDER BY yr;

/* Q88. */
WITH quarterly AS (
  SELECT date_trunc('quarter', order_date) AS qtr, SUM(net_total) AS revenue FROM sales.orders GROUP BY date_trunc('quarter', order_date)
)
SELECT qtr, revenue, LAG(revenue) OVER (ORDER BY qtr) AS prev_qtr_revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY qtr)) / LAG(revenue) OVER (ORDER BY qtr), 1) AS qoq_pct_change
FROM quarterly ORDER BY qtr;

/* Q89. */
WITH monthly AS (
  SELECT date_trunc('month', order_date) AS mo, SUM(net_total) AS revenue FROM sales.orders GROUP BY date_trunc('month', order_date)
)
SELECT mo, revenue, LAG(revenue) OVER (ORDER BY mo) AS prev_mo_revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY mo)) / LAG(revenue) OVER (ORDER BY mo), 1) AS mom_pct_change
FROM monthly ORDER BY mo;

/* Q90. */
WITH daily AS (
  SELECT order_date, SUM(net_total) AS revenue FROM sales.orders GROUP BY order_date
)
SELECT order_date, revenue, LAG(revenue) OVER (ORDER BY order_date) AS prev_day_revenue,
       revenue - LAG(revenue) OVER (ORDER BY order_date) AS dod_change
FROM daily ORDER BY order_date LIMIT 200;

/* Q91. */
WITH cohort AS (
  SELECT customer_id, date_trunc('month', registration_date) AS cohort_month FROM customers.customers
),
spend AS (
  SELECT cust_id, SUM(net_total) AS total_spend FROM sales.orders GROUP BY cust_id
)
SELECT c.cohort_month, COUNT(*) AS cohort_size, SUM(COALESCE(s.total_spend, 0)) AS cohort_total_ltv,
       ROUND(AVG(COALESCE(s.total_spend, 0)), 2) AS avg_ltv_per_customer
FROM cohort c
LEFT JOIN spend s ON s.cust_id = c.customer_id
GROUP BY c.cohort_month
ORDER BY c.cohort_month;

/* Q92. */
WITH orders_agg AS (
  SELECT cust_id, COUNT(*) AS orders, SUM(net_total) AS spend FROM sales.orders GROUP BY cust_id
),
reviews_agg AS (
  SELECT customer_id, COUNT(*) AS reviews, AVG(rating) AS avg_rating FROM customers.reviews GROUP BY customer_id
),
tickets_agg AS (
  SELECT customer_id, COUNT(*) AS tickets FROM support.tickets GROUP BY customer_id
),
loyalty_agg AS (
  SELECT customer_id, points_balance FROM loyalty.members
)
SELECT c.customer_id, c.first_name, c.last_name, c.tier,
       COALESCE(o.orders, 0) AS orders, COALESCE(o.spend, 0) AS spend,
       COALESCE(r.reviews, 0) AS reviews, r.avg_rating,
       COALESCE(t.tickets, 0) AS tickets, l.points_balance
FROM customers.customers c
LEFT JOIN orders_agg o ON o.cust_id = c.customer_id
LEFT JOIN reviews_agg r ON r.customer_id = c.customer_id
LEFT JOIN tickets_agg t ON t.customer_id = c.customer_id
LEFT JOIN loyalty_agg l ON l.customer_id = c.customer_id
ORDER BY spend DESC NULLS LAST
LIMIT 100;

/* Q93. */
WITH sales_agg AS (
  SELECT prod_id, SUM(quantity) AS units_sold, SUM(net_amount) AS revenue FROM sales.order_items GROUP BY prod_id
),
reviews_agg AS (
  SELECT product_id, COUNT(*) AS reviews, AVG(rating) AS avg_rating FROM customers.reviews GROUP BY product_id
),
inventory_agg AS (
  SELECT product_id, SUM(quantity_on_hand) AS stock_on_hand FROM products.inventory GROUP BY product_id
)
SELECT p.product_id, p.product_name, p.price,
       COALESCE(s.units_sold, 0) AS units_sold, COALESCE(s.revenue, 0) AS revenue,
       COALESCE(r.reviews, 0) AS reviews, r.avg_rating,
       COALESCE(i.stock_on_hand, 0) AS stock_on_hand
FROM products.products p
LEFT JOIN sales_agg s ON s.prod_id = p.product_id
LEFT JOIN reviews_agg r ON r.product_id = p.product_id
LEFT JOIN inventory_agg i ON i.product_id = p.product_id
ORDER BY revenue DESC NULLS LAST
LIMIT 100;

/* Q94. */
WITH sales_agg AS (
  SELECT store_id, COUNT(*) AS orders, SUM(net_total) AS revenue FROM sales.orders GROUP BY store_id
),
employee_agg AS (
  SELECT store_id, COUNT(*) AS employee_count FROM stores.employees GROUP BY store_id
),
expense_agg AS (
  SELECT store_id, SUM(amount) AS total_expense FROM stores.expenses GROUP BY store_id
)
SELECT s.store_id, s.store_name, s.city,
       COALESCE(sa.orders, 0) AS orders, COALESCE(sa.revenue, 0) AS revenue,
       COALESCE(e.employee_count, 0) AS employee_count, COALESCE(ex.total_expense, 0) AS total_expense
FROM stores.stores s
LEFT JOIN sales_agg sa ON sa.store_id = s.store_id
LEFT JOIN employee_agg e ON e.store_id = s.store_id
LEFT JOIN expense_agg ex ON ex.store_id = s.store_id
ORDER BY revenue DESC NULLS LAST;

/* Q95. */
WITH sales_agg AS (
  SELECT s.region_id, COUNT(*) AS orders, SUM(o.net_total) AS revenue
  FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id
  GROUP BY s.region_id
),
store_agg AS (
  SELECT region_id, COUNT(*) AS store_count FROM stores.stores GROUP BY region_id
)
SELECT r.region_id, r.region_name, r.country, COALESCE(sa.orders, 0) AS orders, COALESCE(sa.revenue, 0) AS revenue, COALESCE(st.store_count, 0) AS store_count
FROM core.dim_region r
LEFT JOIN sales_agg sa ON sa.region_id = r.region_id
LEFT JOIN store_agg st ON st.region_id = r.region_id
ORDER BY revenue DESC NULLS LAST;

/* Q96. */
WITH spend_agg AS (
  SELECT campaign_id, SUM(amount) AS total_spend FROM marketing.ads_spend GROUP BY campaign_id
),
email_agg AS (
  SELECT campaign_id, SUM(emails_sent) AS emails_sent, SUM(emails_opened) AS emails_opened, SUM(emails_clicked) AS emails_clicked
  FROM marketing.email_clicks GROUP BY campaign_id
)
SELECT c.campaign_id, c.campaign_name, c.budget,
       COALESCE(s.total_spend, 0) AS total_spend,
       COALESCE(e.emails_sent, 0) AS emails_sent, COALESCE(e.emails_opened, 0) AS emails_opened, COALESCE(e.emails_clicked, 0) AS emails_clicked
FROM marketing.campaigns c
LEFT JOIN spend_agg s ON s.campaign_id = c.campaign_id
LEFT JOIN email_agg e ON e.campaign_id = c.campaign_id
ORDER BY c.campaign_id
LIMIT 100;

/* Q97. */
WITH product_agg AS (
  SELECT supplier_id, COUNT(*) AS product_count, AVG(price) AS avg_price FROM products.products GROUP BY supplier_id
),
shipment_agg AS (
  SELECT supplier_id, COUNT(*) AS shipment_count, SUM(quantity) AS total_qty_shipped FROM supply_chain.shipments GROUP BY supplier_id
)
SELECT s.supplier_id, s.supplier_name, s.city,
       COALESCE(p.product_count, 0) AS product_count, p.avg_price,
       COALESCE(sh.shipment_count, 0) AS shipment_count, COALESCE(sh.total_qty_shipped, 0) AS total_qty_shipped
FROM products.suppliers s
LEFT JOIN product_agg p ON p.supplier_id = s.supplier_id
LEFT JOIN shipment_agg sh ON sh.supplier_id = s.supplier_id
ORDER BY s.supplier_id
LIMIT 100;

/* Q98. */
WITH product_agg AS (
  SELECT brand_id, COUNT(*) AS product_count FROM products.products GROUP BY brand_id
),
sales_agg AS (
  SELECT p.brand_id, SUM(oi.quantity) AS units_sold, SUM(oi.net_amount) AS revenue
  FROM sales.order_items oi JOIN products.products p ON p.product_id = oi.prod_id
  GROUP BY p.brand_id
)
SELECT b.brand_id, b.brand_name,
       COALESCE(pa.product_count, 0) AS product_count,
       COALESCE(sa.units_sold, 0) AS units_sold, COALESCE(sa.revenue, 0) AS revenue
FROM core.dim_brand b
LEFT JOIN product_agg pa ON pa.brand_id = b.brand_id
LEFT JOIN sales_agg sa ON sa.brand_id = b.brand_id
ORDER BY revenue DESC NULLS LAST
LIMIT 100;

/* Q99. */
WITH revenue AS (
  SELECT SUM(net_total) AS total_revenue, COUNT(*) AS total_orders, AVG(net_total) AS avg_order_value FROM sales.orders
),
customers_kpi AS (
  SELECT COUNT(*) AS total_customers FROM customers.customers
),
returns_kpi AS (
  SELECT COUNT(*) AS total_returns, SUM(refund_amount) AS total_refunded FROM sales.returns
),
support_kpi AS (
  SELECT COUNT(*) AS total_tickets, COUNT(*) FILTER (WHERE status = 'Open') AS open_tickets FROM support.tickets
)
SELECT r.total_revenue, r.total_orders, r.avg_order_value, c.total_customers,
       rt.total_returns, rt.total_refunded, s.total_tickets, s.open_tickets
FROM revenue r, customers_kpi c, returns_kpi rt, support_kpi s;

/* Q100. */
WITH step1_raw AS (
  SELECT * FROM sales.orders
),
step2_filtered AS (
  SELECT * FROM step1_raw WHERE order_status <> 'Cancelled'
),
step3_store AS (
  SELECT o.*, s.region_id, s.city FROM step2_filtered o JOIN stores.stores s ON s.store_id = o.store_id
),
step4_region AS (
  SELECT s3.*, r.region_name FROM step3_store s3 JOIN core.dim_region r ON r.region_id = s3.region_id
),
step5_customer AS (
  SELECT s4.*, c.tier FROM step4_region s4 JOIN customers.customers c ON c.customer_id = s4.cust_id
),
step6_monthly AS (
  SELECT region_name, tier, date_trunc('month', order_date) AS month, COUNT(*) AS order_count, SUM(net_total) AS revenue
  FROM step5_customer GROUP BY region_name, tier, date_trunc('month', order_date)
),
step7_ranked AS (
  SELECT *, RANK() OVER (PARTITION BY region_name, month ORDER BY revenue DESC) AS tier_rank_in_region
  FROM step6_monthly
),
step8_top_tier AS (
  SELECT * FROM step7_ranked WHERE tier_rank_in_region = 1
),
step9_region_totals AS (
  SELECT region_name, SUM(revenue) AS region_total_revenue FROM step6_monthly GROUP BY region_name
),
step10_labeled AS (
  SELECT t.*, rt.region_total_revenue,
         ROUND(100.0 * t.revenue / rt.region_total_revenue, 1) AS pct_of_region_revenue
  FROM step8_top_tier t JOIN step9_region_totals rt ON rt.region_name = t.region_name
),
step11_flagged AS (
  SELECT *, CASE WHEN pct_of_region_revenue > 40 THEN 'Concentrated' ELSE 'Diversified' END AS concentration_flag
  FROM step10_labeled
),
step12_final AS (
  SELECT region_name, month, tier, order_count, revenue, pct_of_region_revenue, concentration_flag
  FROM step11_flagged
)
SELECT * FROM step12_final ORDER BY region_name, month;

/* ============================================================
   END OF CTEs (WITH, non-recursive) - HARD LEVEL (100 QUESTIONS)
============================================================ */
