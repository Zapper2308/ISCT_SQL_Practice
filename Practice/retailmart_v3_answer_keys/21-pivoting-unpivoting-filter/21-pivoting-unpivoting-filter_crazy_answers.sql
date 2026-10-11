/* ============================================================
   ANSWER KEY - Pivoting, Unpivoting & FILTER (CRAZY LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1.  Pre-aggregate to the row grain in a CTE, then in the outer SELECT compute COUNT(*), SUM(revenue), AVG(revenue) alongside window SUM(...) OVER(PARTITION BY row) and SUM(...) OVER() for row%/grand-total%, all reading the same CTE once. */
/* Q2.  GROUPING SETS lists exactly the grouping combinations you name; ROLLUP(a,b) is shorthand for GROUPING SETS((a,b),(a),()) - a strict hierarchy; CUBE(a,b) is shorthand for every combination, GROUPING SETS((a,b),(a),(b),()) - independent subtotals on every axis. */
/* Q3.  GROUPING(col) returns 1 if that column was aggregated away (a subtotal row) and 0 if it's real detail; GROUPING_ID(a,b) packs multiple GROUPING() bits into one integer (a 2-bit value here) so you can sort/filter subtotal levels with a single comparison instead of checking each GROUPING() separately. */
/* Q4.  crosstab() (tablefunc) builds pivot columns from a runtime category query; jsonb_object_agg(key,value) builds one dynamic key->value object per group without any extension; app-side pivoting fetches long-format rows and reshapes them in the application/BI layer. */
/* Q5.  A SELECT list is parsed and its column count/names fixed before any row is read, so a column whose name would only be known after scanning the data (an unknown category value) simply cannot exist in that plan - Postgres needs every output column nailed down at parse time. */
/* Q6.  jsonb_object_agg(status, cnt) returns one JSON object per group like {"Delivered": 120, "Cancelled": 8}, giving a dynamic, self-describing "pivot" whose keys come straight from the data (full JSON operators are covered in Day 24). */
/* Q7.  Pre-aggregate each fact table to its natural grain in its own CTE before joining into the pivot, so a one-to-many join (e.g. orders to order_items) never gets aggregated a second time and silently multiplies counts/sums. */
/* Q8.  Compute the pivot's raw cells as before, then add ROUND(100.0 * cell / SUM(cell) OVER (PARTITION BY row_key), 2) AS share columns in the same SELECT - window functions run after the GROUP BY, so they can safely reference the already-aggregated cell values. */
/* Q9.  Long format is canonical for storage/general-purpose analysis (works with any BI tool, any downstream re-slicing); wide format is canonical for a specific human-facing report (finance sheet, dashboard matrix) - build long once, then pivot it however each consumer needs. */
/* Q10. Aggregate raw fact rows down to (row_key, category, value) grain in a CTE first, so the pivot's FILTERed aggregates scan a small pre-summarized set instead of re-deriving every group from millions of raw rows. */
/* Q11. NULL in a pivot cell usually means "no matching rows" (missing data); an explicit 0 means "we checked and the count/sum truly is zero" - AVG treats NULL as absent from the average (ignored), while AVG over a 0 counts it as a real zero value, changing the result. */
/* Q12. A correct set of subtotals guarantees SUM(detail rows) = the matching subtotal row = the grand-total row, at every level GROUPING SETS/ROLLUP/CUBE produced - reconciling these sums is the standard check that no row was double-counted or dropped. */
/* Q13. Always bucket the raw timestamp with the same function/granularity everywhere in a query (e.g. always date_trunc('hour', ts) or always EXTRACT(hour FROM ts)) so the same moment always lands in the same bucket, regardless of which column or CTE computes it. */
/* Q14. The BI tool should pivot when the categories are high-cardinality, viewer-specific, or change per session; SQL should pivot when the category set is small, fixed, and the same shaped report is reused by many consumers who all need the identical columns. */
/* Q15. Flattening region x status x month into one table means picking one axis for rows (e.g. region x month) and turning the other into columns (status) - or producing a fully long (region, month, status, value) table and letting the BI layer choose its own flattening. */
/* Q16. EAV (entity-attribute-value, i.e. long format) is flexible for a growing/unknown attribute set and avoids sparse wide tables, but every read needs a pivot/join to reconstruct one row; wide format is fast and simple to query but requires a schema change (or NULL columns) whenever a new attribute appears. */
/* Q17. Wrap every ratio's denominator in NULLIF(denominator, 0) so a zero-row group returns NULL instead of raising a division-by-zero error, keeping "no data to compute a rate from" visually distinct from "the rate genuinely is 0". */
/* Q18. CUBE(a,b,c,...) grows combinatorially (2^N grouping sets for N columns), so CUBE over high-cardinality dimensions can produce an enormous, mostly-useless result - reserve CUBE for a small number of genuinely low-cardinality dimensions. */
/* Q19. A pivot recomputed identically for every dashboard refresh, expensive to build from raw facts, and tolerant of being slightly stale is a strong materialized-view candidate (Day 25) - refresh it on a schedule instead of paying the aggregation cost on every page load. */
/* Q20. Build the full set of expected category values (e.g. via a calendar/category dimension table) and LEFT JOIN the actual pivot onto it, so every category always appears as a column/row even in periods where it had zero matching source rows. */
/* Q21. Compute one FILTERed aggregate for the base period (e.g. SUM(x) FILTER (WHERE period = 'base')), then divide every period's value by that same base figure x100 - no LAG needed since the base is a fixed reference computed once per row group, not the previous row. */
/* Q22. Add PERCENTILE_CONT(...) WITHIN GROUP (ORDER BY ...) (Day 22) alongside the pivot's regular aggregates in the same GROUP BY, producing median/P90/etc as extra columns in the same one-row-per-group KPI strip. */
/* Q23. Two-step: first run SELECT DISTINCT category FROM table to get the actual category list, then programmatically (app code, or a generated SQL string) build a SELECT with one FILTERed column per discovered category - crosstab() automates roughly this same two-query pattern. */
/* Q24. Validate a reshape pipeline by confirming SUM(long-form values) equals SUM(original wide-form values) (no rows lost/duplicated) and, for a pivot->unpivot->pivot round trip, that the final wide result exactly matches the original. */
/* Q25. Checklist: correct grain before pivoting; every category covered (including zero-row ones); ratios safely NULLIF-guarded; row/column/grand totals reconcile; and the result is refreshed on a cadence appropriate to how stale the dashboard can tolerably be. */

/* ============================================================
   SECTION B: MULTI-METRIC MATRICES (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT r.region_name, date_trunc('month', o.order_date)::date AS month,
       SUM(o.net_total) AS revenue,
       COUNT(*) AS orders,
       ROUND(AVG(o.net_total), 2) AS aov,
       ROUND(100.0 * SUM(o.net_total) / SUM(SUM(o.net_total)) OVER (PARTITION BY r.region_name), 2) AS pct_of_region,
       ROUND(100.0 * SUM(o.net_total) / SUM(SUM(o.net_total)) OVER (), 2) AS pct_of_grand_total
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name, month
ORDER BY r.region_name, month;
/* Q27. */
SELECT store_id, EXTRACT(QUARTER FROM order_date) AS quarter,
       SUM(net_total) AS revenue,
       COUNT(*) AS orders,
       COUNT(*) FILTER (WHERE order_status = 'Returned') AS returned_orders,
       ROUND(100.0 * COUNT(*) FILTER (WHERE order_status = 'Returned') / COUNT(*), 2) AS return_rate_pct
FROM sales.orders
WHERE EXTRACT(YEAR FROM order_date) = 2025
GROUP BY store_id, quarter
ORDER BY store_id, quarter;
/* Q28. */
SELECT cat.category_name, EXTRACT(MONTH FROM o.order_date) AS month,
       SUM(oi.net_amount) AS revenue,
       ROUND(100.0 * SUM(oi.net_amount) / SUM(SUM(oi.net_amount)) OVER (), 2) AS pct_of_grand_total
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
WHERE EXTRACT(YEAR FROM o.order_date) = 2025
GROUP BY cat.category_name, month
ORDER BY cat.category_name, month;
/* Q29. */
SELECT r.region_name, o.order_status,
       COUNT(*) AS order_count,
       SUM(o.net_total) AS revenue,
       ROUND(SUM(o.net_total) / COUNT(*), 2) AS revenue_per_order
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name, o.order_status
ORDER BY r.region_name, o.order_status;
/* Q30. */
SELECT b.brand_name, c.tier,
       SUM(oi.net_amount) AS revenue,
       COUNT(DISTINCT c.customer_id) AS customer_count,
       ROUND(SUM(oi.net_amount) / NULLIF(COUNT(DISTINCT c.customer_id), 0), 2) AS revenue_per_customer
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
JOIN customers.customers c ON c.customer_id = o.cust_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
GROUP BY b.brand_name, c.tier
ORDER BY b.brand_name, c.tier;
/* Q31. */
SELECT agent_id, priority,
       COUNT(*) AS ticket_count,
       ROUND(AVG(EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600), 2) AS avg_resolution_hrs,
       ROUND(100.0 * COUNT(*) FILTER (WHERE resolved_date - created_date > INTERVAL '48 hours') / COUNT(*), 2) AS sla_breach_pct
FROM support.tickets
WHERE resolved_date IS NOT NULL
GROUP BY agent_id, priority
ORDER BY agent_id, priority;
/* Q32. */
SELECT p.product_id, EXTRACT(MONTH FROM o.order_date) AS month,
       SUM(oi.quantity) AS units,
       SUM(oi.net_amount) AS revenue,
       SUM(oi.quantity * (p.price - p.cost_price)) AS margin
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
JOIN products.products p ON p.product_id = oi.prod_id
WHERE EXTRACT(YEAR FROM o.order_date) = 2025
GROUP BY p.product_id, month
ORDER BY p.product_id, month;
/* Q33. */
SELECT courier_name, EXTRACT(MONTH FROM shipped_date) AS month,
       COUNT(*) AS shipments,
       ROUND(100.0 * COUNT(*) FILTER (WHERE delivered_date - shipped_date <= 3) / COUNT(*), 2) AS pct_on_time,
       ROUND(AVG(delivered_date - shipped_date), 2) AS avg_delivery_days
FROM sales.shipments
WHERE delivered_date IS NOT NULL AND shipped_date IS NOT NULL
GROUP BY courier_name, month
ORDER BY courier_name, month;
/* Q34. */
SELECT dept_id, role,
       COUNT(*) AS headcount,
       ROUND(AVG(salary), 2) AS avg_salary,
       ROUND(100.0 * SUM(salary) / SUM(SUM(salary)) OVER (), 2) AS payroll_share_pct
FROM stores.employees
GROUP BY dept_id, role
ORDER BY dept_id, role;
/* Q35. */
SELECT r.region_name,
       CASE WHEN EXTRACT(MONTH FROM o.order_date) IN (3,4,5) THEN 'Spring'
            WHEN EXTRACT(MONTH FROM o.order_date) IN (6,7,8) THEN 'Summer'
            WHEN EXTRACT(MONTH FROM o.order_date) IN (9,10,11) THEN 'Autumn'
            ELSE 'Winter' END AS season,
       SUM(o.net_total) AS revenue,
       COUNT(*) AS orders,
       ROUND(100.0 * SUM(o.net_total) FILTER (WHERE EXTRACT(YEAR FROM o.order_date) = 2024)
             / NULLIF(SUM(o.net_total) FILTER (WHERE EXTRACT(YEAR FROM o.order_date) = 2025), 0), 2) AS y2024_to_y2025_base_ratio
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name, season
ORDER BY r.region_name, season;
/* Q36. */
SELECT platform, EXTRACT(QUARTER FROM spend_date) AS quarter,
       SUM(amount) AS spend,
       ROUND(100.0 * SUM(amount) / SUM(SUM(amount)) OVER (), 2) AS share_pct,
       SUM(SUM(amount)) OVER (PARTITION BY platform ORDER BY EXTRACT(QUARTER FROM spend_date)) AS cumulative_spend
FROM marketing.ads_spend
GROUP BY platform, quarter
ORDER BY platform, quarter;
/* Q37. */
SELECT ws.warehouse_id, cat.category_name,
       SUM(s.quantity_on_hand) AS stock,
       ROUND(100.0 * SUM(s.quantity_on_hand) / SUM(SUM(s.quantity_on_hand)) OVER (PARTITION BY ws.warehouse_id), 2) AS pct_of_warehouse
FROM supply_chain.inventory_snapshots s
JOIN supply_chain.warehouses ws ON ws.warehouse_id = s.warehouse_id
JOIN products.products p ON p.product_id = s.product_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
GROUP BY ws.warehouse_id, cat.category_name
ORDER BY ws.warehouse_id, cat.category_name;
/* Q38. */
WITH cohort AS (
  SELECT c.customer_id, EXTRACT(YEAR FROM c.registration_date) AS cohort_year
  FROM customers.customers c
)
SELECT co.cohort_year, EXTRACT(MONTH FROM o.order_date) AS month_since,
       COUNT(DISTINCT o.cust_id) AS customers,
       SUM(o.net_total) AS revenue
FROM sales.orders o
JOIN cohort co ON co.customer_id = o.cust_id
WHERE EXTRACT(YEAR FROM o.order_date) = co.cohort_year
GROUP BY co.cohort_year, month_since
ORDER BY co.cohort_year, month_since;
/* Q39. */
SELECT c.customer_id, a.city, c.tier,
       COUNT(o.order_id) AS orders,
       SUM(o.net_total) AS spend,
       ROUND(SUM(o.net_total) / NULLIF(COUNT(o.order_id), 0), 2) AS spend_per_order
FROM customers.customers c
JOIN customers.addresses a ON a.customer_id = c.customer_id
LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY c.customer_id, a.city, c.tier
ORDER BY c.customer_id
LIMIT 1000;
/* Q40. */
SELECT date_trunc('month', order_date)::date AS month, order_status, SUM(net_total) AS revenue,
       GROUPING(order_status) AS is_month_subtotal
FROM sales.orders
GROUP BY ROLLUP (month, order_status)
ORDER BY month NULLS LAST, order_status NULLS LAST;
/* Q41. */
SELECT r.region_name, pm.mode_name, SUM(o.net_total) AS revenue,
       GROUPING(r.region_name) AS region_rolled_up,
       GROUPING(pm.mode_name) AS mode_rolled_up
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
JOIN finance.payment_modes pm ON pm.mode_id = o.payment_mode_id
GROUP BY CUBE (r.region_name, pm.mode_name)
ORDER BY r.region_name NULLS LAST, pm.mode_name NULLS LAST;
/* Q42. */
SELECT cat.category_name, b.brand_name, SUM(oi.net_amount) AS revenue,
       ROUND(100.0 * SUM(oi.net_amount) / SUM(SUM(oi.net_amount)) OVER (PARTITION BY cat.category_name), 2) AS pct_of_category
FROM sales.order_items oi
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
GROUP BY ROLLUP (cat.category_name, b.brand_name)
ORDER BY cat.category_name NULLS LAST, b.brand_name NULLS LAST;
/* Q43. */
SELECT store_id,
       CASE WHEN EXTRACT(DOW FROM order_date) IN (0,6) THEN 'weekend' ELSE 'weekday' END AS day_type,
       SUM(net_total) AS revenue,
       COUNT(*) AS orders
FROM sales.orders
GROUP BY GROUPING SETS ((store_id, CASE WHEN EXTRACT(DOW FROM order_date) IN (0,6) THEN 'weekend' ELSE 'weekday' END), (store_id))
ORDER BY store_id, day_type NULLS LAST;
/* Q44. */
SELECT r.region_name, c.tier,
       SUM(o.net_total) AS revenue,
       ROUND(100.0 * SUM(o.net_total) / SUM(SUM(o.net_total)) OVER (PARTITION BY r.region_name), 2) AS pct_of_region,
       ROUND(100.0 * SUM(o.net_total) / SUM(SUM(o.net_total)) OVER (), 2) AS pct_of_company
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
JOIN customers.customers c ON c.customer_id = o.cust_id
GROUP BY r.region_name, c.tier
ORDER BY r.region_name, c.tier;
/* Q45. */
SELECT product_id,
       ROUND(AVG(rating), 2) AS avg_rating,
       ROUND(100.0 * COUNT(*) FILTER (WHERE rating <= 2) / COUNT(*), 2) AS negative_review_pct
FROM customers.reviews
GROUP BY product_id;
/* Q46. */
SELECT region_name, month, revenue,
       LAG(revenue) OVER (PARTITION BY region_name ORDER BY month) AS prev_month_revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (PARTITION BY region_name ORDER BY month))
             / NULLIF(LAG(revenue) OVER (PARTITION BY region_name ORDER BY month), 0), 2) AS mom_growth_pct
FROM (
    SELECT r.region_name, date_trunc('month', o.order_date)::date AS month,
           SUM(o.net_total) AS revenue
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_name, month
) monthly
ORDER BY region_name, month;
/* Q47. */
SELECT brand_id,
       CASE WHEN price < 1000 THEN 'value' WHEN price BETWEEN 1000 AND 5000 THEN 'mid' ELSE 'premium' END AS price_band,
       COUNT(*) AS product_count,
       SUM(price) AS band_revenue_potential,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY brand_id), 2) AS contribution_pct
FROM products.products
GROUP BY brand_id, price_band
ORDER BY brand_id, price_band;
/* Q48. */
SELECT r.region_name, EXTRACT(QUARTER FROM o.order_date) AS quarter,
       SUM(o.net_total) AS revenue,
       SUM(oi.quantity * p.cost_price) AS cost,
       ROUND(100.0 * (SUM(o.net_total) - SUM(oi.quantity * p.cost_price)) / NULLIF(SUM(o.net_total), 0), 2) AS margin_pct
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
WHERE EXTRACT(YEAR FROM o.order_date) = 2025
GROUP BY r.region_name, quarter
ORDER BY r.region_name, quarter;
/* Q49. */
WITH matrix AS (
  SELECT r.region_name, EXTRACT(QUARTER FROM o.order_date) AS quarter, SUM(o.net_total) AS revenue
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  JOIN core.dim_region r ON r.region_id = s.region_id
  WHERE EXTRACT(YEAR FROM o.order_date) = 2025
  GROUP BY r.region_name, quarter
)
SELECT (SELECT SUM(revenue) FROM matrix) AS sum_of_cells,
       (SELECT SUM(net_total) FROM sales.orders WHERE EXTRACT(YEAR FROM order_date) = 2025) AS true_total,
       (SELECT SUM(revenue) FROM matrix) = (SELECT SUM(net_total) FROM sales.orders WHERE EXTRACT(YEAR FROM order_date) = 2025) AS reconciled;
/* Q50. */
SELECT r.region_name, date_trunc('month', o.order_date)::date AS month,
       SUM(o.net_total) AS revenue,
       COUNT(*) AS orders,
       ROUND(AVG(o.net_total), 2) AS aov,
       ROUND(100.0 * SUM(o.net_total) / SUM(SUM(o.net_total)) OVER (PARTITION BY r.region_name), 2) AS pct_of_region
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY GROUPING SETS ((r.region_name, month), (r.region_name), ())
ORDER BY r.region_name NULLS LAST, month NULLS LAST;

/* ============================================================
   SECTION C: DYNAMIC-PIVOT STRATEGY (25)
   ------------------------------------------------------------ */
/* Q51. Since payment_mode values could grow over time, a durable dashboard should either build its FILTER columns from a query against finance.payment_modes at report-generation time (regenerating the SQL text), or use jsonb_object_agg(mode_name, revenue) so new modes just appear as new JSON keys with no query change. */
/* Q52. Two-step: (1) SELECT DISTINCT mode_name FROM finance.payment_modes ORDER BY mode_name to get the live column list, then (2) generate a SUM(...) FILTER (WHERE mode_name = '<value>') column for each discovered value and assemble/execute that SQL text (application code or crosstab()). */
/* Q53. (accio_NN) crosstab('SELECT region_name, order_status, cnt FROM ... ORDER BY 1,2') with a category query listing distinct order_status values would produce one column per status, discovered from the data rather than hardcoded. */
/* Q54. */
SELECT r.region_name, jsonb_object_agg(o.order_status, status_cnt) AS status_counts
FROM (
  SELECT s.region_id, o.order_status, COUNT(*) AS status_cnt
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  GROUP BY s.region_id, o.order_status
) o
JOIN core.dim_region r ON r.region_id = o.region_id
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q55. The static FILTER pivot needs every status column named in advance and always returns the same fixed column set (NULL/0 for missing ones); the jsonb result is self-describing and grows automatically with new statuses, but every consumer then has to unpack the JSON (jsonb_each, ->>) instead of reading plain columns. */
/* Q56. */
SELECT jsonb_object_agg(month, revenue) AS monthly_revenue
FROM (
  SELECT to_char(order_date, 'YYYY-MM') AS month, SUM(net_total) AS revenue
  FROM sales.orders
  WHERE EXTRACT(YEAR FROM order_date) = 2025
  GROUP BY month
) m;
/* Q57. A dynamic brand pivot needs app-side or crosstab() generation because core.dim_brand has 117 distinct brands that can grow or be renamed - hand-writing 117 FILTER columns in SQL is both impractical and fragile the moment a new brand is added. */
/* Q58. (accio_NN) crosstab() takes a "source" query returning (row_key, category, value) and a "category" query returning the distinct categories in display order, then builds the wide result with one column per category value returned by the category query. */
/* Q59. */
SELECT b.brand_name, jsonb_object_agg(p.product_id, units_sold) AS product_units
FROM (
  SELECT prod_id, SUM(quantity) AS units_sold FROM sales.order_items GROUP BY prod_id
) oi
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
GROUP BY b.brand_name
ORDER BY b.brand_name
LIMIT 50;
/* Q60. A static FILTER pivot's column list is frozen at query-writing time, so a genuinely new category value (a new order_status the business introduces later) simply never appears in any column; a jsonb_object_agg result automatically grows a new key the moment such a row exists, no query change required. */
/* Q61. */
SELECT customer_id, jsonb_build_object('email', email, 'phone', phone, 'tier', tier) AS profile
FROM customers.customers
LIMIT 50;
/* Q62. crosstab() is best when the output truly must be plain SQL columns (e.g. feeding a tool that can't parse JSON); jsonb_object_agg is best when the consumer can handle JSON and the category set is volatile; app-side pivoting is best when the categories are numerous, user-chosen, or need custom formatting the database shouldn't own. */
/* Q63. */
SELECT date_trunc('month', order_date)::date AS month, jsonb_object_agg(order_status, cnt) AS status_json
FROM (
  SELECT order_date, order_status, COUNT(*) AS cnt
  FROM sales.orders
  GROUP BY order_date, order_status
) x
GROUP BY month
ORDER BY month;
/* Q64. */
SELECT jsonb_object_agg(region_name, revenue) AS revenue_by_region
FROM (
  SELECT r.region_name, SUM(o.net_total) AS revenue
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  JOIN core.dim_region r ON r.region_id = s.region_id
  GROUP BY r.region_name
) x;
/* Q65. */
SELECT r.region_name,
       (j.status_json ->> 'Delivered')::int AS delivered,
       (j.status_json ->> 'Cancelled')::int AS cancelled
FROM (
  SELECT s.region_id, jsonb_object_agg(o.order_status, cnt) AS status_json
  FROM (SELECT store_id, order_status, COUNT(*) AS cnt FROM sales.orders GROUP BY store_id, order_status) o
  JOIN stores.stores s ON s.store_id = o.store_id
  GROUP BY s.region_id
) j
JOIN core.dim_region r ON r.region_id = j.region_id
ORDER BY r.region_name;
/* Q66. (accio_NN) crosstab('SELECT agent_id, priority, cnt FROM (...) ORDER BY 1,2', 'SELECT DISTINCT priority FROM support.tickets ORDER BY 1') would produce agent_id rows with one column per priority value, built from a live category query. */
/* Q67. */
SELECT r.region_name, jsonb_object_agg(c.tier, tier_cnt) AS tier_counts, SUM(tier_cnt) AS total_customers
FROM (
  SELECT a.state, c.tier, COUNT(*) AS tier_cnt
  FROM customers.customers c
  JOIN customers.addresses a ON a.customer_id = c.customer_id
  GROUP BY a.state, c.tier
) c
JOIN core.dim_region r ON r.state = c.state
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q68. Push a dynamic pivot to the BI tool once the category set is large, changes often, or different viewers want different columns - keep it in SQL (static FILTER or jsonb) only while the categories are small, stable, and shared identically by every consumer. */
/* Q69. */
SELECT r.region_name, jsonb_object_agg(COALESCE(o.order_status, 'Unknown'), COALESCE(cnt, 0)) AS status_json
FROM core.dim_region r
LEFT JOIN (
  SELECT s.region_id, o.order_status, COUNT(*) AS cnt
  FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id
  GROUP BY s.region_id, o.order_status
) o ON o.region_id = r.region_id
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q70. Two-query approach outline: query 1 (SELECT DISTINCT <category> ORDER BY 1) returns the live column list; a driver script then interpolates one SUM(...) FILTER (WHERE <category> = '<value>') per row of query 1's result into a generated SELECT, which is query 2, executed to get the final pivot. */
/* Q71. */
SELECT jsonb_object_agg(month, revenue ORDER BY month) AS rolling_12mo
FROM (
  SELECT to_char(order_date, 'YYYY-MM') AS month, SUM(net_total) AS revenue
  FROM sales.orders
  WHERE order_date >= (CURRENT_DATE - INTERVAL '12 months')
  GROUP BY month
) m;
/* Q72. Static FILTER pivots are easy to read and index-friendly but need a code change every time a category is added or renamed; dynamic crosstab() needs no query change for new categories but is harder to read/debug and depends on the tablefunc extension being installed and maintained. */
/* Q73. */
SELECT s.store_id, jsonb_object_agg(o.order_status, cnt) AS status_json
FROM (SELECT store_id, order_status, COUNT(*) AS cnt FROM sales.orders GROUP BY store_id, order_status) o
JOIN stores.stores s ON s.store_id = o.store_id
GROUP BY s.store_id
ORDER BY s.store_id;
/* Q74. */
WITH dyn AS (
  SELECT jsonb_object_agg(order_status, cnt) AS status_json, SUM(cnt) AS dyn_total
  FROM (SELECT order_status, COUNT(*) AS cnt FROM sales.orders GROUP BY order_status) x
),
stat AS (
  SELECT COUNT(*) AS static_total FROM sales.orders
)
SELECT d.dyn_total, s.static_total, d.dyn_total = s.static_total AS matches
FROM dyn d, stat s;
/* Q75. Recommend static FILTER pivots for the handful of small, stable, shared dashboards (order_status, payment_mode, tier); jsonb_object_agg for flexible internal APIs where the consumer already speaks JSON; and crosstab()/tablefunc (accio_NN) only when a tool genuinely needs plain dynamic columns and the extension can be installed. */

/* ============================================================
   SECTION D: RESHAPE PIPELINES (25)
   ------------------------------------------------------------ */
/* Q76. */
WITH wide AS (
  SELECT store_id,
         SUM(net_total) FILTER (WHERE EXTRACT(QUARTER FROM order_date) = 1) AS q1,
         SUM(net_total) FILTER (WHERE EXTRACT(QUARTER FROM order_date) = 2) AS q2,
         SUM(net_total) FILTER (WHERE EXTRACT(QUARTER FROM order_date) = 3) AS q3,
         SUM(net_total) FILTER (WHERE EXTRACT(QUARTER FROM order_date) = 4) AS q4
  FROM sales.orders WHERE EXTRACT(YEAR FROM order_date) = 2025
  GROUP BY store_id
),
tidy AS (
  SELECT store_id, 'revenue' AS metric, 'Q1' AS period, q1 AS value FROM wide
  UNION ALL SELECT store_id, 'revenue', 'Q2', q2 FROM wide
  UNION ALL SELECT store_id, 'revenue', 'Q3', q3 FROM wide
  UNION ALL SELECT store_id, 'revenue', 'Q4', q4 FROM wide
)
SELECT store_id,
       SUM(value) FILTER (WHERE metric = 'revenue') AS revenue
FROM tidy
GROUP BY store_id
ORDER BY store_id;
/* Q77. */
WITH components AS (
  SELECT pay_slip_id, employee_id, payment_date, 'basic_salary' AS component, basic_salary AS amount, gross_salary FROM payroll.pay_slips
  UNION ALL SELECT pay_slip_id, employee_id, payment_date, 'hra', hra, gross_salary FROM payroll.pay_slips
  UNION ALL SELECT pay_slip_id, employee_id, payment_date, 'other_allowances', other_allowances, gross_salary FROM payroll.pay_slips
),
validated AS (
  SELECT pay_slip_id, SUM(amount) = MAX(gross_salary) AS matches_gross FROM components GROUP BY pay_slip_id
)
SELECT date_trunc('month', c.payment_date)::date AS month, SUM(c.amount) AS total_components
FROM components c
GROUP BY month
ORDER BY month;
/* Q78. */
WITH tidy AS (
  SELECT summary_date, 'total_revenue' AS metric, total_revenue AS value FROM finance.revenue_summary
  UNION ALL SELECT summary_date, 'total_orders', total_orders::numeric FROM finance.revenue_summary
)
SELECT metric, date_trunc('month', summary_date)::date AS month, SUM(value) AS value
FROM tidy
GROUP BY metric, month
ORDER BY metric, month;
/* Q79. */
WITH funnel AS (
  SELECT campaign_id, 'email' AS platform_hint, 'sent' AS stage, emails_sent AS cnt FROM marketing.email_clicks
  UNION ALL SELECT campaign_id, 'email', 'opened', emails_opened FROM marketing.email_clicks
  UNION ALL SELECT campaign_id, 'email', 'clicked', emails_clicked FROM marketing.email_clicks
)
SELECT c.campaign_name,
       SUM(f.cnt) FILTER (WHERE f.stage = 'sent') AS sent,
       SUM(f.cnt) FILTER (WHERE f.stage = 'opened') AS opened,
       SUM(f.cnt) FILTER (WHERE f.stage = 'clicked') AS clicked
FROM funnel f
JOIN marketing.campaigns c ON c.campaign_id = f.campaign_id
GROUP BY c.campaign_name
ORDER BY c.campaign_name;
/* Q80. */
WITH piv AS (
  SELECT r.region_name, o.order_status, COUNT(*) AS cnt
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  JOIN core.dim_region r ON r.region_id = s.region_id
  GROUP BY r.region_name, o.order_status
),
long_form AS (
  SELECT region_name, order_status, cnt FROM piv
),
re_wide AS (
  SELECT region_name,
         SUM(cnt) FILTER (WHERE order_status = 'Delivered') AS delivered,
         SUM(cnt) FILTER (WHERE order_status = 'Cancelled') AS cancelled
  FROM long_form
  GROUP BY region_name
)
SELECT * FROM re_wide ORDER BY region_name;
/* Q81. */
WITH eav AS (
  SELECT customer_id, 'tier' AS attribute, tier AS value FROM customers.customers
  UNION ALL SELECT customer_id, 'email', email FROM customers.customers
  UNION ALL SELECT customer_id, 'phone', phone FROM customers.customers
)
SELECT customer_id,
       MAX(value) FILTER (WHERE attribute = 'tier') AS tier,
       MAX(value) FILTER (WHERE attribute = 'email') AS email
FROM eav
GROUP BY customer_id
ORDER BY customer_id
LIMIT 100;
/* Q82. */
WITH long_form AS (
  SELECT order_id, order_date, 'gross_total' AS kind, gross_total AS amount FROM sales.orders
  UNION ALL SELECT order_id, order_date, 'discount_amount', discount_amount FROM sales.orders
  UNION ALL SELECT order_id, order_date, 'net_total', net_total FROM sales.orders
)
SELECT date_trunc('month', order_date)::date AS month,
       SUM(amount) FILTER (WHERE kind = 'gross_total') AS gross,
       SUM(amount) FILTER (WHERE kind = 'discount_amount') AS discount,
       SUM(amount) FILTER (WHERE kind = 'net_total') AS net
FROM long_form
GROUP BY month
ORDER BY month;
/* Q83. */
WITH wide AS (
  SELECT store_id,
    SUM(net_total) FILTER (WHERE EXTRACT(MONTH FROM order_date) = 1) AS m1,
    SUM(net_total) FILTER (WHERE EXTRACT(MONTH FROM order_date) = 2) AS m2,
    SUM(net_total) FILTER (WHERE EXTRACT(MONTH FROM order_date) = 3) AS m3
  FROM sales.orders WHERE EXTRACT(YEAR FROM order_date) = 2025
  GROUP BY store_id
),
tidy AS (
  SELECT w.store_id, v.month_num, v.revenue
  FROM wide w
  CROSS JOIN LATERAL (VALUES (1, w.m1), (2, w.m2), (3, w.m3)) AS v(month_num, revenue)
)
SELECT store_id, CEIL(month_num / 3.0) AS quarter, SUM(revenue) AS revenue
FROM tidy
GROUP BY store_id, quarter
ORDER BY store_id, quarter;
/* Q84. */
WITH ads_long AS (
  SELECT campaign_id, 'amount' AS metric, amount AS value, platform FROM marketing.ads_spend
)
SELECT platform,
       SUM(value) FILTER (WHERE metric = 'amount') AS total_spend
FROM ads_long
GROUP BY platform
ORDER BY platform;
/* Q85. */
WITH tidy AS (
  SELECT tier_id, 'min_points' AS field, min_points AS value FROM loyalty.tiers
  UNION ALL SELECT tier_id, 'max_points', max_points FROM loyalty.tiers
)
SELECT * FROM tidy ORDER BY tier_id, field;
/* Q86. */
WITH store_kpis AS (
  SELECT store_id, 'revenue' AS metric, SUM(net_total) AS value FROM sales.orders GROUP BY store_id
  UNION ALL SELECT store_id, 'order_count', COUNT(*) FROM sales.orders GROUP BY store_id
  UNION ALL SELECT store_id, 'aov', ROUND(AVG(net_total), 2) FROM sales.orders GROUP BY store_id
)
SELECT store_id, metric, value,
       RANK() OVER (PARTITION BY metric ORDER BY value DESC) AS rank_within_metric
FROM store_kpis
ORDER BY metric, rank_within_metric;
/* Q87. */
WITH tidy AS (
  SELECT min_salary, 'min_salary' AS field, min_salary AS value FROM payroll.tax_brackets
  UNION ALL SELECT min_salary, 'max_salary', max_salary FROM payroll.tax_brackets
  UNION ALL SELECT min_salary, 'tax_rate', tax_rate FROM payroll.tax_brackets
)
SELECT min_salary AS bracket,
       MAX(value) FILTER (WHERE field = 'tax_rate') AS tax_rate,
       CASE WHEN MAX(value) FILTER (WHERE field = 'tax_rate') < 0.1 THEN 'low' WHEN MAX(value) FILTER (WHERE field = 'tax_rate') < 0.2 THEN 'mid' ELSE 'high' END AS rate_band
FROM tidy
GROUP BY bracket
ORDER BY bracket;
/* Q88. */
WITH j AS (
  SELECT jsonb_object_agg(order_status, cnt) AS pivot_json
  FROM (SELECT order_status, COUNT(*) AS cnt FROM sales.orders GROUP BY order_status) x
)
SELECT kv.key AS order_status, kv.value::int AS cnt
FROM j, jsonb_each_text(j.pivot_json) AS kv(key, value)
ORDER BY order_status;
/* Q89. */
WITH agg AS (
  SELECT r.region_name, o.order_status, COUNT(*) AS cnt
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  JOIN core.dim_region r ON r.region_id = s.region_id
  GROUP BY r.region_name, o.order_status
),
piv AS (
  SELECT region_name,
         SUM(cnt) FILTER (WHERE order_status = 'Delivered') AS delivered,
         SUM(cnt) FILTER (WHERE order_status = 'Cancelled') AS cancelled,
         SUM(cnt) AS total
  FROM agg GROUP BY region_name
)
SELECT region_name, delivered, cancelled,
       ROUND(100.0 * delivered / NULLIF(total, 0), 2) AS pct_delivered
FROM piv
ORDER BY region_name;
/* Q90. */
WITH funnel AS (
  SELECT 'page_view' AS stage, COUNT(*) AS cnt, 1 AS stage_order FROM web_events.page_views
  UNION ALL SELECT 'click_event', COUNT(*), 2 FROM web_events.events
)
SELECT stage, cnt,
       ROUND(100.0 * cnt / NULLIF(FIRST_VALUE(cnt) OVER (ORDER BY stage_order), 0), 2) AS pct_of_first_stage
FROM funnel
ORDER BY stage_order;
/* Q91. */
WITH long_form AS (
  SELECT product_id, 'price' AS kind, price AS amount FROM products.products
  UNION ALL SELECT product_id, 'cost_price', cost_price FROM products.products
  UNION ALL SELECT product_id, 'margin', price - cost_price FROM products.products
)
SELECT kind, ROUND(AVG(amount), 2) AS avg_amount, SUM(amount) AS total_amount
FROM long_form
GROUP BY kind
ORDER BY kind;
/* Q92. */
WITH orders_tidy AS (
  SELECT store_id::text AS entity, 'orders' AS metric, date_trunc('month', order_date)::date AS period, COUNT(*)::numeric AS value
  FROM sales.orders GROUP BY store_id, period
),
revenue_tidy AS (
  SELECT store_id::text, 'revenue', date_trunc('month', order_date)::date, SUM(net_total)
  FROM sales.orders GROUP BY store_id, date_trunc('month', order_date)::date
),
ads_tidy AS (
  SELECT platform, 'ad_spend', date_trunc('month', spend_date)::date, SUM(amount)
  FROM marketing.ads_spend GROUP BY platform, date_trunc('month', spend_date)::date
)
SELECT entity, metric, period, value FROM orders_tidy
UNION ALL SELECT * FROM revenue_tidy
UNION ALL SELECT * FROM ads_tidy
ORDER BY entity, metric, period
LIMIT 1000;
/* Q93. */
WITH piv AS (
  SELECT store_id, SUM(net_total) AS revenue FROM sales.orders GROUP BY store_id
),
long_form AS (
  SELECT store_id, 'revenue' AS metric, revenue AS value FROM piv
),
re_piv AS (
  SELECT store_id, SUM(value) FILTER (WHERE metric = 'revenue') AS revenue FROM long_form GROUP BY store_id
)
SELECT p.store_id, p.revenue = r.revenue AS round_trip_matches
FROM piv p JOIN re_piv r ON r.store_id = p.store_id
ORDER BY p.store_id;
/* Q94. */
WITH by_store_month AS (
  SELECT store_id, date_trunc('month', order_date)::date AS month, SUM(net_total) AS revenue
  FROM sales.orders GROUP BY store_id, month
)
SELECT store_id,
       SUM(revenue) FILTER (WHERE EXTRACT(QUARTER FROM month) = 1) AS q1,
       SUM(revenue) FILTER (WHERE EXTRACT(QUARTER FROM month) = 2) AS q2
FROM by_store_month
WHERE EXTRACT(YEAR FROM month) = 2025
GROUP BY store_id
ORDER BY store_id;
/* Q95. */
WITH region_month AS (
  SELECT r.region_name, date_trunc('month', o.order_date)::date AS month, SUM(o.net_total) AS revenue
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  JOIN core.dim_region r ON r.region_id = s.region_id
  GROUP BY r.region_name, month
)
SELECT region_name, EXTRACT(YEAR FROM month) AS year, SUM(revenue) AS annual_revenue
FROM region_month
GROUP BY region_name, year
ORDER BY region_name, year;
/* Q96. */
WITH tidy AS (
  SELECT tier_id, tier_name, 'min_points' AS field, min_points AS value FROM loyalty.tiers
  UNION ALL SELECT tier_id, tier_name, 'max_points', max_points FROM loyalty.tiers
),
piv AS (
  SELECT tier_id, tier_name,
         MAX(value) FILTER (WHERE field = 'min_points') AS min_points,
         MAX(value) FILTER (WHERE field = 'max_points') AS max_points
  FROM tidy GROUP BY tier_id, tier_name
)
SELECT tier_name, min_points, max_points,
       min_points - LAG(max_points) OVER (ORDER BY min_points) AS gap_from_prev_tier
FROM piv
ORDER BY min_points;
/* Q97. */
WITH source AS (
  SELECT store_id, date_trunc('month', order_date)::date AS month, order_status, net_total
  FROM sales.orders
),
tidy AS (
  SELECT store_id, month, order_status, SUM(net_total) AS revenue FROM source GROUP BY store_id, month, order_status
),
pivoted AS (
  SELECT store_id, month,
         SUM(revenue) FILTER (WHERE order_status = 'Delivered') AS delivered_revenue,
         SUM(revenue) FILTER (WHERE order_status = 'Cancelled') AS cancelled_revenue
  FROM tidy GROUP BY store_id, month
)
SELECT * FROM pivoted ORDER BY store_id, month;
/* Q98. */
WITH matrix AS (
  SELECT r.region_name, date_trunc('month', o.order_date)::date AS month,
         SUM(o.net_total) AS revenue, COUNT(*) AS orders
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  JOIN core.dim_region r ON r.region_id = s.region_id
  GROUP BY r.region_name, month
),
tidy AS (
  SELECT region_name, month, 'revenue' AS metric, revenue AS value FROM matrix
  UNION ALL SELECT region_name, month, 'orders', orders FROM matrix
)
SELECT region_name, metric, value FROM tidy ORDER BY region_name, metric;
/* Q99. Documentation: source facts are sales.orders (+ FK joins for region/tier/category), the pipeline pre-aggregates to (row_key, period, metric) grain in a CTE, tidies via UNION ALL into (entity, metric, period, value), then re-pivots per consumer - re-running this script against the live database at any time reproduces identical output since every step is a deterministic aggregation, no random sampling. */
/* Q100. */
WITH facts AS (
  SELECT r.region_name, date_trunc('month', o.order_date)::date AS month, o.order_status, o.net_total
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  JOIN core.dim_region r ON r.region_id = s.region_id
),
tidy AS (
  SELECT region_name, month, 'revenue' AS metric, SUM(net_total) AS value FROM facts GROUP BY region_name, month
  UNION ALL SELECT region_name, month, 'orders', COUNT(*) FROM facts GROUP BY region_name, month
  UNION ALL SELECT region_name, month, 'delivered_orders', COUNT(*) FILTER (WHERE order_status = 'Delivered') FROM facts GROUP BY region_name, month
),
curated_pivot AS (
  SELECT region_name, month,
         SUM(value) FILTER (WHERE metric = 'revenue') AS revenue,
         SUM(value) FILTER (WHERE metric = 'orders') AS orders,
         SUM(value) FILTER (WHERE metric = 'delivered_orders') AS delivered_orders
  FROM tidy GROUP BY region_name, month
)
SELECT 'pivot' AS output_kind, region_name, month::text AS period, revenue::text AS col1, orders::text AS col2, delivered_orders::text AS col3
FROM curated_pivot
UNION ALL
SELECT 'tidy', region_name, month::text, metric, value::text, NULL
FROM tidy
ORDER BY output_kind, region_name, period;

/* ============================================================
   END OF ANSWER KEY - Pivoting, Unpivoting & FILTER - CRAZY LEVEL (100/100)
   ============================================================ */
