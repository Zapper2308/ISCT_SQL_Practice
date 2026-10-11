/* ============================================================
   ANSWER KEY - Review & Interview Prep (HARD LEVEL)
   Curriculum:   RetailMart V3
   Database:     isct_retailmart
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL REVIEW (25)
   ------------------------------------------------------------ */
/* Q1. RANK() gives both rows tied at position 3 the rank 3, then skips to rank 5 for the next distinct value; DENSE_RANK() also gives both rows rank 3, but the next distinct value gets rank 4 - no gap is left. */

/* Q2. ROWS BETWEEN counts physical rows regardless of ties; RANGE BETWEEN groups all "peer" rows sharing the same ORDER BY value together as if they were on the current row. RANGE gives a different result whenever the ORDER BY column has ties - e.g. two orders on the exact same order_date get the same RANGE-based running total, but different ROWS-based running totals. */

/* Q3. NOT IN (subquery) is x <> a AND x <> b AND x <> NULL under the hood; comparing anything to NULL yields UNKNOWN, and UNKNOWN ANDed with the rest can never become definitively TRUE, so the whole predicate evaluates to UNKNOWN/FALSE for every row and NOT IN silently returns zero rows. Safe rewrite: use NOT EXISTS (correlated) or filter the subquery with WHERE col IS NOT NULL. */

/* Q4. A LATERAL join subquery can reference columns from preceding FROM items (like a correlated subquery) but lives in the FROM clause and can return multiple rows/columns per outer row; a correlated subquery is restricted to a single scalar value. LATERAL is more efficient for "top N rows per outer row" since the planner can use an index + LIMIT inside the LATERAL subquery instead of computing an aggregate over the whole partition. */

/* Q5. LIMIT 1 without an ORDER BY that matches an existing index forces Postgres to compute (and often sort) the full candidate result set before it can pick "row 1" in a stable way - if the WHERE clause isn't selective and there's no index giving the rows in the desired order, the planner falls back to a full scan. Adding an index on the ORDER BY column(s) (matching direction) lets Postgres walk the index and stop after the first row. */

/* Q6. A hash join builds an in-memory hash table from the smaller ("build") input and probes it with the larger input - chosen when inputs aren't already sorted and the build side fits in work_mem. A merge join requires both inputs already sorted (or explicitly sorted first) on the join key and streams matches in one pass - Postgres favors it when both sides are already ordered via an index, avoiding a hash build, or when a hash table would spill to disk. */

/* Q7. A covering index includes every column a query needs (WHERE predicate + SELECT list) as index key or INCLUDE columns, letting Postgres satisfy the query with an Index Only Scan that never touches the heap. Example: CREATE INDEX ON sales.orders(store_id) INCLUDE (order_id, net_total) covers "SELECT order_id, net_total FROM sales.orders WHERE store_id = X". */

/* Q8. ANALYZE scans a sample of a table's rows and refreshes pg_statistic (row count estimate, most-common values, histogram of value distribution, correlation) that the planner uses for cardinality estimation; it helps whenever the data distribution has materially changed (large INSERT/UPDATE/DELETE batches, bulk loads) since stale statistics lead the planner to misestimate row counts and pick a suboptimal join order or method. */

/* Q9. A partial index only indexes rows matching a WHERE condition, e.g. CREATE INDEX ON sales.orders(order_date) WHERE order_status = 'Processing' - since 'Processing' orders are a small slice of the 150k-row orders table, this index is dramatically smaller than a full index on order_date and is used only for queries filtering on that same (or a compatible, implied) condition. */

/* Q10. A Seq Scan means Postgres read every row of the table sequentially rather than via an index; it's perfectly fine (often the fastest option) when the query needs a large fraction of the table's rows anyway - a low-selectivity filter or no filter at all - since sequential I/O beats the overhead of many random index lookups in that case. */

/* Q11. A view has no storage of its own - the planner inlines/rewrites the view's defining query into the outer query and plans against the live base tables every time it's referenced, so it always reflects current data but pays the base query's full cost each time. A materialized view stores a physical result set as its own relation, so the planner just scans that pre-computed table directly (fast, no re-join to base tables) but the data is a stale snapshot until REFRESH runs. */

/* Q12. A BRIN index stores only the min/max value per block range rather than an entry per row, making it tiny; it's the right choice for a large, naturally insert-ordered column like sales.orders.order_date or web_events.page_views.view_timestamp, where physical row order already correlates with the indexed value, so a range query can prune whole block ranges cheaply. */

/* Q13. Wrapping an indexed column in a function (EXTRACT(YEAR FROM order_date)) means Postgres must evaluate that expression on every row's raw value before it can group/compare - the index on the raw order_date column stores raw values, not the function's output, so it can't drive an index-only scan for that grouped expression unless a matching functional/expression index on EXTRACT(YEAR FROM order_date) itself exists. */

/* Q14. PERCENTILE_CONT interpolates linearly between the two nearest ranked values, so its result may not equal any actual row's value (a continuous estimate); PERCENTILE_DISC always returns an actual value present in the data (the first value whose cumulative fraction meets or exceeds the requested percentile) - a discrete choice, never interpolated. */

/* Q15. A funnel with conversion handles skipped steps by measuring each stage's reach independently (COUNT DISTINCT customers who reached that stage at all, via LEFT JOIN/EXISTS to that stage's events) rather than requiring a customer to have completed every prior stage in strict sequence - a customer who skips step 2 but reaches step 3 is still counted at step 3, and each stage's conversion rate is computed against the immediately preceding stage's reach. */

/* Q16. The cohort triangle has rows = signup cohort (e.g. month) and columns = period_index (periods elapsed since signup); a future cell is one whose period_index would fall after today's date for that cohort - since that time period hasn't happened yet for that cohort, there is no data to compute a retention percentage from, so it's NULL rather than 0%. */

/* Q17. 3NF forbids transitive dependencies (a non-key column depending on another non-key column rather than directly on the primary key). finance.revenue_summary intentionally violates 3NF: total_revenue and avg_order_value are fully derivable from sales.orders, yet are stored directly as a denormalized daily summary row purely for fast reporting rather than being computed on demand. */

/* Q18. Optimistic locking checks that a row hasn't changed since it was read (typically via a version number or updated_at column compared at UPDATE time) instead of locking the row for the whole read-modify-write cycle; an analyst might care because a report built mid-transaction on optimistically-locked data could reflect a value that gets overwritten moments later, so "point in time" reporting queries need to be aware such in-flight changes exist. */

/* Q19. A Bitmap Index Scan first builds an in-memory bitmap of matching heap page locations from one or more indexes, then does a single pass visiting just those pages (rather than a random per-row index lookup); it shows up in EXPLAIN when a moderate fraction of the table matches - too many rows for an efficient plain Index Scan's per-row random I/O, but few enough that a full Seq Scan would waste work reading non-matching rows. */

/* Q20. DISTINCT ON (key) ORDER BY key, tiebreaker dedups to exactly one row per key directly in a single query and often lets Postgres avoid a separate window-function evaluation pass; ROW_NUMBER is more flexible - it can keep top-N (not just top-1), supports arbitrary PARTITION BY/ORDER BY logic, and exposes the rank itself - but requires wrapping the query in a subquery/CTE and filtering WHERE rn = 1 (or <= N) afterward. */

/* Q21. A correlated subquery in the SELECT list re-evaluates once per outer row (effectively a nested-loop pattern), which becomes O(n*m) and very slow against a large outer table; the standard rewrite replaces it with a LEFT JOIN to a pre-aggregated subquery/CTE (GROUP BY the join key) so the aggregate is computed once per group in a single pass instead of once per outer row. */

/* Q22. VACUUM reclaims the space used by dead tuples (row versions made obsolete by UPDATE/DELETE under MVCC) for reuse within the table, without necessarily returning it to the OS; AUTOVACUUM runs this automatically in the background based on dead-tuple thresholds. It matters after a bulk load/bulk update because unvacuumed dead tuples bloat the table and its indexes, and stale visibility-map bits block index-only scans until VACUUM (or ANALYZE for statistics) catches up. */

/* Q23. Cardinality estimation is the planner's predicted row count for each step of a query plan; since the planner picks the cheapest plan by estimated cost (which is a function of estimated rows), a badly wrong estimate at any join step can cause it to choose a much worse join order or join method (e.g. a nested loop over what turns out to be a huge intermediate result) than the truly cheapest plan. */

/* Q24. INTERSECT compares the full row-tuples of two queries' result sets and returns each distinct tuple present in both (deduplicated, and can compare any output columns, not just a declared key); an INNER JOIN on a specific key returns a combined row (columns from both sides) for every matching pair of rows and does not deduplicate - INTERSECT answers "which rows exist in both sets," while a JOIN answers "pair up matching rows and bring back both sides' data." */

/* Q25. A cumulative distribution gives, for a value v, the fraction of all rows whose value is less than or equal to v. CUME_DIST() computes it per row as (number of rows in the partition with a value <= the current row's peer-group value) / (total rows in the partition) - a value in [0,1] where 1.0 means the current row's value is the maximum. */

/* ============================================================
   SECTION B: ADVANCED JOINS, CTEs & SUBQUERIES (25)
   ------------------------------------------------------------ */
/* Q26. */
WITH order_cats AS (
  SELECT oi.order_id, COUNT(DISTINCT cat.category_id) AS category_count
  FROM sales.order_items oi
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
  GROUP BY oi.order_id
  HAVING COUNT(DISTINCT cat.category_id) >= 3
)
SELECT DISTINCT o.cust_id, oc.order_id, oc.category_count
FROM order_cats oc
JOIN sales.orders o ON o.order_id = oc.order_id
ORDER BY oc.category_count DESC, o.cust_id;

/* Q27. */
SELECT cust_id,
       COUNT(*) FILTER (WHERE EXTRACT(DOW FROM order_date) = 0) AS sun,
       COUNT(*) FILTER (WHERE EXTRACT(DOW FROM order_date) = 1) AS mon,
       COUNT(*) FILTER (WHERE EXTRACT(DOW FROM order_date) = 2) AS tue,
       COUNT(*) FILTER (WHERE EXTRACT(DOW FROM order_date) = 3) AS wed,
       COUNT(*) FILTER (WHERE EXTRACT(DOW FROM order_date) = 4) AS thu,
       COUNT(*) FILTER (WHERE EXTRACT(DOW FROM order_date) = 5) AS fri,
       COUNT(*) FILTER (WHERE EXTRACT(DOW FROM order_date) = 6) AS sat
FROM sales.orders
GROUP BY cust_id
ORDER BY cust_id;

/* Q28. */
WITH review_stats AS (
  SELECT product_id, COUNT(*) AS review_count, AVG(rating) AS avg_rating
  FROM customers.reviews
  GROUP BY product_id
  HAVING COUNT(*) >= 5 AND AVG(rating) >= 4.0
),
prod_rev AS (
  SELECT p.product_id, p.product_name, cat.category_id, cat.category_name,
         SUM(oi.quantity * oi.unit_price) AS revenue,
         ROW_NUMBER() OVER (PARTITION BY cat.category_id ORDER BY SUM(oi.quantity * oi.unit_price) DESC) AS rn
  FROM sales.order_items oi
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
  JOIN review_stats rs ON rs.product_id = p.product_id
  GROUP BY p.product_id, p.product_name, cat.category_id, cat.category_name
)
SELECT category_name, product_name, revenue
FROM prod_rev
WHERE rn <= 3
ORDER BY category_name, rn;

/* Q29. */
WITH monthly AS (
  SELECT store_id, DATE_TRUNC('month', order_date)::date AS mth, SUM(net_total) AS revenue
  FROM sales.orders
  GROUP BY store_id, DATE_TRUNC('month', order_date)
),
with_ma AS (
  SELECT store_id, mth, revenue,
         AVG(revenue) OVER (PARTITION BY store_id ORDER BY mth ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ma_3mo,
         ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY mth DESC) AS rn
  FROM monthly
)
SELECT store_id, mth, revenue, ROUND(ma_3mo, 2) AS ma_3mo, (revenue < ma_3mo) AS below_3mo_ma
FROM with_ma
WHERE rn = 1
ORDER BY store_id;

/* Q30. */
WITH avg_snap AS (
  SELECT warehouse_id, product_id, AVG(quantity_on_hand) AS avg_qty
  FROM supply_chain.inventory_snapshots
  GROUP BY warehouse_id, product_id
),
latest AS (
  SELECT DISTINCT ON (warehouse_id, product_id) warehouse_id, product_id, quantity_on_hand, snapshot_date
  FROM supply_chain.inventory_snapshots
  ORDER BY warehouse_id, product_id, snapshot_date DESC
)
SELECT l.warehouse_id, l.product_id, l.quantity_on_hand AS current_qty, ROUND(a.avg_qty, 2) AS historical_avg_qty
FROM latest l
JOIN avg_snap a ON a.warehouse_id = l.warehouse_id AND a.product_id = l.product_id
WHERE l.quantity_on_hand < a.avg_qty
ORDER BY l.warehouse_id, l.product_id;

/* Q31. */
WITH first_order AS (
  SELECT cust_id, MIN(order_date) AS first_order_date
  FROM sales.orders
  GROUP BY cust_id
)
SELECT c.customer_id, c.registration_date, fo.first_order_date,
       (fo.first_order_date - c.registration_date) AS days_to_first_order
FROM customers.customers c
JOIN first_order fo ON fo.cust_id = c.customer_id
WHERE (fo.first_order_date - c.registration_date) <= 7
ORDER BY days_to_first_order;

/* Q32. */
WITH monthly AS (
  SELECT DATE_TRUNC('month', order_date)::date AS mth, SUM(net_total) AS revenue
  FROM sales.orders
  WHERE order_date >= DATE '2025-01-01' AND order_date < DATE '2026-01-01'
  GROUP BY DATE_TRUNC('month', order_date)
)
SELECT mth, revenue,
       revenue - LAG(revenue) OVER (ORDER BY mth) AS mom_delta,
       SUM(revenue) OVER (ORDER BY mth) AS running_total
FROM monthly
ORDER BY mth;

/* Q33. -- no direct warehouse-to-store FK exists in the schema, so "the store" is interpreted as any store, i.e. products held in warehouse inventory that have had zero orders anywhere in the last 90 days. */
WITH latest_snap AS (
  SELECT DISTINCT ON (warehouse_id, product_id) warehouse_id, product_id, quantity_on_hand
  FROM supply_chain.inventory_snapshots
  ORDER BY warehouse_id, product_id, snapshot_date DESC
)
SELECT ls.warehouse_id, ls.product_id, ls.quantity_on_hand
FROM latest_snap ls
WHERE ls.quantity_on_hand > 0
  AND NOT EXISTS (
    SELECT 1 FROM sales.order_items oi
    JOIN sales.orders o ON o.order_id = oi.order_id
    WHERE oi.prod_id = ls.product_id
      AND o.order_date >= (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '90 days'
  )
ORDER BY ls.warehouse_id, ls.product_id;

/* Q34. */
WITH monthly AS (
  SELECT DATE_TRUNC('month', created_date)::date AS mth,
         COUNT(*) AS total_tickets,
         COUNT(*) FILTER (WHERE resolved_date IS NOT NULL AND resolved_date - created_date <= INTERVAL '48 hours') AS resolved_48h
  FROM support.tickets
  GROUP BY DATE_TRUNC('month', created_date)
),
rated AS (
  SELECT mth, total_tickets, resolved_48h,
         ROUND(100.0 * resolved_48h / NULLIF(total_tickets, 0), 2) AS resolution_rate_pct
  FROM monthly
),
with_change AS (
  SELECT mth, resolution_rate_pct,
         LAG(resolution_rate_pct) OVER (ORDER BY mth) AS prior_month_rate,
         resolution_rate_pct - LAG(resolution_rate_pct) OVER (ORDER BY mth) AS rate_change
  FROM rated
)
SELECT mth, resolution_rate_pct, prior_month_rate, rate_change
FROM with_change
WHERE rate_change < -10
ORDER BY mth;

/* Q35. -- no direct customer/campaign link exists, so revenue is attributed to a campaign as all order revenue placed anywhere in the 7 days following its start_date. */
SELECT mc.campaign_id, mc.campaign_name, mc.start_date,
       SUM(o.net_total) AS revenue_within_7d
FROM marketing.campaigns mc
JOIN sales.orders o ON o.order_date >= mc.start_date AND o.order_date < mc.start_date + 7
GROUP BY mc.campaign_id, mc.campaign_name, mc.start_date
ORDER BY revenue_within_7d DESC;

/* Q36. */
WITH last_order AS (
  SELECT cust_id, MAX(order_date) AS last_order_date
  FROM sales.orders
  GROUP BY cust_id
)
SELECT c.customer_id, c.registration_date, lo.last_order_date,
       CASE
         WHEN c.registration_date >= CURRENT_DATE - INTERVAL '6 months' THEN 'New'
         WHEN lo.last_order_date >= CURRENT_DATE - INTERVAL '30 days' THEN 'Active'
         WHEN lo.last_order_date >= CURRENT_DATE - INTERVAL '180 days' THEN 'Lapsed'
         ELSE 'Churned'
       END AS segment
FROM customers.customers c
LEFT JOIN last_order lo ON lo.cust_id = c.customer_id
ORDER BY c.customer_id;

/* Q37. -- "salary_history" is interpreted as each employee's yearly salary total from payroll.pay_slips (grouped by salary_year), checked for strict year-over-year increase via LAG. */
WITH yearly AS (
  SELECT employee_id, salary_year, SUM(gross_salary) AS yearly_gross
  FROM payroll.pay_slips
  GROUP BY employee_id, salary_year
),
with_lag AS (
  SELECT employee_id, salary_year, yearly_gross,
         LAG(yearly_gross) OVER (PARTITION BY employee_id ORDER BY salary_year) AS prev_yearly_gross
  FROM yearly
)
SELECT employee_id
FROM with_lag
GROUP BY employee_id
HAVING COUNT(*) > 1
   AND BOOL_AND(prev_yearly_gross IS NULL OR yearly_gross > prev_yearly_gross)
ORDER BY employee_id;

/* Q38. */
WITH store_returns AS (
  SELECT store_id,
         COUNT(*) FILTER (WHERE order_status = 'Returned') AS returned_count,
         COUNT(*) AS total_orders
  FROM sales.orders
  GROUP BY store_id
),
company_avg AS (
  SELECT SUM(returned_count)::numeric / NULLIF(SUM(total_orders), 0) AS company_return_rate
  FROM store_returns
)
SELECT sr.store_id,
       ROUND(100.0 * sr.returned_count / NULLIF(sr.total_orders, 0), 2) AS store_return_rate_pct,
       ROUND(100.0 * ca.company_return_rate, 2) AS company_return_rate_pct
FROM store_returns sr, company_avg ca
WHERE (sr.returned_count::numeric / NULLIF(sr.total_orders, 0)) > ca.company_return_rate
ORDER BY store_return_rate_pct DESC;

/* Q39. */
WITH order_cats AS (
  SELECT DISTINCT oi.order_id, cat.category_id, cat.category_name
  FROM sales.order_items oi
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
)
SELECT a.category_name AS category_a, b.category_name AS category_b,
       COUNT(DISTINCT a.order_id) AS orders_with_both
FROM order_cats a
JOIN order_cats b ON a.order_id = b.order_id AND a.category_id < b.category_id
GROUP BY a.category_name, b.category_name
ORDER BY orders_with_both DESC;

/* Q40. -- sales.orders/order_items have no secondary indexes beyond their primary keys, so a LATERAL join over all 50,000 customers would force a full 375k-row scan per customer; adding these two supporting indexes first turns each LATERAL call into a cheap indexed lookup. */
CREATE INDEX IF NOT EXISTS ix_orders_cust_id ON sales.orders(cust_id);
CREATE INDEX IF NOT EXISTS ix_order_items_order_id ON sales.order_items(order_id);
SELECT c.customer_id, top_items.order_item_id, top_items.prod_id, top_items.unit_price, top_items.quantity, top_items.line_total
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT oi.order_item_id, oi.prod_id, oi.unit_price, oi.quantity, (oi.unit_price * oi.quantity) AS line_total
  FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  WHERE o.cust_id = c.customer_id
  ORDER BY (oi.unit_price * oi.quantity) DESC
  LIMIT 3
) top_items
ORDER BY c.customer_id, top_items.line_total DESC;

/* Q41. */
WITH item_sums AS (
  SELECT order_id, SUM(unit_price * quantity) AS item_total
  FROM sales.order_items
  GROUP BY order_id
)
SELECT o.order_id, o.gross_total, i.item_total,
       ROUND(100.0 * (i.item_total - o.gross_total) / NULLIF(o.gross_total, 0), 2) AS pct_over
FROM sales.orders o
JOIN item_sums i ON i.order_id = o.order_id
WHERE i.item_total > o.gross_total * 1.01
ORDER BY pct_over DESC;

/* Q42. */
WITH daily_counts AS (
  SELECT view_timestamp::date AS view_date, customer_id
  FROM web_events.page_views
  WHERE customer_id IS NOT NULL
  GROUP BY view_timestamp::date, customer_id
),
daily_active AS (
  SELECT view_date, COUNT(DISTINCT customer_id) AS dau
  FROM daily_counts
  GROUP BY view_date
),
rolling_7d AS (
  SELECT da.view_date,
         (SELECT COUNT(DISTINCT customer_id) FROM daily_counts dc WHERE dc.view_date BETWEEN da.view_date - 6 AND da.view_date) AS rolling_7d_active
  FROM daily_active da
),
monthly_active AS (
  SELECT DATE_TRUNC('month', view_date)::date AS mth, COUNT(DISTINCT customer_id) AS mau
  FROM daily_counts
  GROUP BY DATE_TRUNC('month', view_date)
)
SELECT da.view_date, da.dau, r.rolling_7d_active, ma.mau,
       ROUND(da.dau::numeric / NULLIF(ma.mau, 0), 4) AS dau_mau_stickiness
FROM daily_active da
JOIN rolling_7d r ON r.view_date = da.view_date
JOIN monthly_active ma ON ma.mth = DATE_TRUNC('month', da.view_date)::date
ORDER BY da.view_date;

/* Q43. */
SELECT t.ticket_id, t.customer_id, t.created_date::date AS ticket_date, r.return_id, r.return_date
FROM support.tickets t
JOIN sales.returns r ON r.return_date = t.created_date::date
JOIN sales.orders o ON o.order_id = r.order_id AND o.cust_id = t.customer_id
WHERE t.resolved_date IS NOT NULL
  AND t.created_date::date = t.resolved_date::date
ORDER BY t.ticket_id;

/* Q44. */
WITH cust_metrics AS (
  SELECT cust_id, SUM(net_total) AS total_spend, COUNT(*) AS order_count
  FROM sales.orders
  GROUP BY cust_id
),
ranked AS (
  SELECT cust_id, total_spend, order_count,
         NTILE(10) OVER (ORDER BY total_spend) AS spend_decile,
         NTILE(10) OVER (ORDER BY order_count) AS freq_decile
  FROM cust_metrics
)
SELECT r.cust_id, r.total_spend, r.order_count
FROM ranked r
WHERE r.spend_decile = 10 AND r.freq_decile = 10
  AND EXISTS (SELECT 1 FROM customers.reviews rv WHERE rv.customer_id = r.cust_id)
ORDER BY r.total_spend DESC;

/* Q45. */
SELECT employee_id, joining_date, salary,
       DATE_PART('year', AGE(CURRENT_DATE, joining_date))::int AS tenure_years,
       ROUND(salary::numeric / NULLIF(DATE_PART('year', AGE(CURRENT_DATE, joining_date))::numeric, 0), 2) AS salary_per_tenure_year
FROM stores.employees
ORDER BY tenure_years DESC;

/* Q46. */
WITH cust_spend AS (
  SELECT cust_id, SUM(net_total) AS total_spend
  FROM sales.orders
  GROUP BY cust_id
),
ranked AS (
  SELECT cust_id, total_spend, NTILE(10) OVER (ORDER BY total_spend) AS decile
  FROM cust_spend
),
decile_totals AS (
  SELECT decile, COUNT(*) AS cust_count, SUM(total_spend) AS decile_spend
  FROM ranked
  GROUP BY decile
),
overall AS (
  SELECT SUM(cust_count) AS total_cust, SUM(decile_spend) AS total_spend FROM decile_totals
)
SELECT dt.decile,
       ROUND(100.0 * SUM(dt.cust_count) OVER (ORDER BY dt.decile) / o.total_cust, 2) AS cum_pct_customers,
       ROUND(100.0 * SUM(dt.decile_spend) OVER (ORDER BY dt.decile) / o.total_spend, 2) AS cum_pct_revenue
FROM decile_totals dt, overall o
ORDER BY dt.decile;

/* Q47. -- no store-to-warehouse FK exists, so "linked warehouse" inventory is interpreted as the store's own row in products.inventory. */
WITH store_sales_cats AS (
  SELECT DISTINCT o.store_id, cat.category_name, oi.prod_id
  FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
)
SELECT DISTINCT ssc.store_id, ssc.category_name
FROM store_sales_cats ssc
LEFT JOIN products.inventory inv ON inv.store_id = ssc.store_id AND inv.product_id = ssc.prod_id
WHERE COALESCE(inv.quantity_on_hand, 0) = 0
ORDER BY ssc.store_id, ssc.category_name;

/* Q48. */
WITH agent_avg AS (
  SELECT agent_id, AVG(call_duration_seconds) AS avg_handle_time
  FROM call_center.calls
  GROUP BY agent_id
)
SELECT agent_id, ROUND(avg_handle_time, 2) AS avg_handle_time,
       ROUND(PERCENT_RANK() OVER (ORDER BY avg_handle_time)::numeric, 4) AS percentile_rank
FROM agent_avg
ORDER BY avg_handle_time;

/* Q49. */
WITH order_counts AS (
  SELECT cust_id, COUNT(*) AS order_count, MAX(order_date) AS last_order_date
  FROM sales.orders
  GROUP BY cust_id
)
SELECT cust_id, last_order_date
FROM order_counts
WHERE order_count = 1
  AND last_order_date < (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '90 days'
ORDER BY last_order_date;

/* Q50. */
WITH cohorts AS (
  SELECT customer_id, DATE_TRUNC('week', registration_date)::date AS signup_week
  FROM customers.customers
),
activity AS (
  SELECT c.customer_id, c.signup_week,
         FLOOR(EXTRACT(EPOCH FROM (DATE_TRUNC('week', o.order_date) - c.signup_week)) / 604800)::int AS weeks_since_signup
  FROM cohorts c
  JOIN sales.orders o ON o.cust_id = c.customer_id
),
cohort_size AS (
  SELECT signup_week, COUNT(*) AS cohort_size FROM cohorts GROUP BY signup_week
)
SELECT a.signup_week, a.weeks_since_signup, cs.cohort_size,
       COUNT(DISTINCT a.customer_id) AS retained,
       ROUND(100.0 * COUNT(DISTINCT a.customer_id) / NULLIF(cs.cohort_size, 0), 2) AS retention_pct
FROM activity a
JOIN cohort_size cs ON cs.signup_week = a.signup_week
WHERE a.weeks_since_signup BETWEEN 0 AND 3
GROUP BY a.signup_week, a.weeks_since_signup, cs.cohort_size
ORDER BY a.signup_week, a.weeks_since_signup;

/* ============================================================
   SECTION C: ANALYTICS & WINDOW FUNCTIONS (25)
   ------------------------------------------------------------ */
/* Q51. -- PERCENTILE_CONT (an ordered-set aggregate) cannot be used with an OVER clause in Postgres, so the rolling 12-month median uses a correlated subquery instead of a window function. */
WITH monthly AS (
  SELECT DATE_TRUNC('month', order_date)::date AS mth, SUM(net_total) AS revenue
  FROM sales.orders
  GROUP BY DATE_TRUNC('month', order_date)
)
SELECT m1.mth, m1.revenue,
       SUM(m1.revenue) OVER (ORDER BY m1.mth ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS rolling_12mo_sum,
       (SELECT ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY m2.revenue)::numeric, 2)
        FROM monthly m2 WHERE m2.mth BETWEEN m1.mth - INTERVAL '11 months' AND m1.mth) AS rolling_12mo_median
FROM monthly m1
ORDER BY m1.mth;

/* Q52. */
WITH raw AS (
  SELECT cust_id,
         (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS recency_days,
         COUNT(*) AS frequency,
         SUM(net_total) AS monetary
  FROM sales.orders
  GROUP BY cust_id
),
scored AS (
  SELECT cust_id, recency_days, frequency, monetary,
         NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
         NTILE(5) OVER (ORDER BY frequency) AS f_score,
         NTILE(5) OVER (ORDER BY monetary) AS m_score
  FROM raw
)
SELECT cust_id, r_score, f_score, m_score,
       CASE
         WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
         WHEN f_score >= 4 AND m_score >= 3 THEN 'Loyal'
         WHEN r_score <= 2 AND (f_score >= 3 OR m_score >= 3) THEN 'At-Risk'
         WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'Lost'
         ELSE 'New'
       END AS segment
FROM scored
ORDER BY cust_id;

/* Q53. */
WITH monthly_custs AS (
  SELECT DISTINCT DATE_TRUNC('month', order_date)::date AS mth, cust_id
  FROM sales.orders
),
months AS (
  SELECT DISTINCT mth FROM monthly_custs
)
SELECT m.mth,
       (SELECT COUNT(*) FROM monthly_custs mc WHERE mc.mth = (m.mth - INTERVAL '1 month')::date) AS prior_month_active,
       COUNT(DISTINCT prior.cust_id) AS churned_customers,
       ROUND(100.0 * COUNT(DISTINCT prior.cust_id)
             / NULLIF((SELECT COUNT(*) FROM monthly_custs mc WHERE mc.mth = (m.mth - INTERVAL '1 month')::date), 0), 2) AS churn_rate_pct
FROM months m
LEFT JOIN monthly_custs prior ON prior.mth = (m.mth - INTERVAL '1 month')::date
  AND NOT EXISTS (SELECT 1 FROM monthly_custs cur WHERE cur.mth = m.mth AND cur.cust_id = prior.cust_id)
GROUP BY m.mth
ORDER BY m.mth;

/* Q54. */
WITH price_events AS (
  SELECT record_id AS product_id, old_value::numeric AS old_price, new_value::numeric AS new_price, changed_at
  FROM audit.record_changes
  WHERE table_name = 'products' AND column_name = 'price'
)
SELECT product_id, changed_at, old_price, new_price,
       ROUND(100.0 * (new_price - old_price) / NULLIF(old_price, 0), 2) AS pct_change
FROM price_events
ORDER BY product_id, changed_at;

/* Q55. */
WITH store_yearly AS (
  SELECT store_id, EXTRACT(YEAR FROM order_date)::int AS yr, SUM(net_total) AS store_revenue
  FROM sales.orders
  GROUP BY store_id, EXTRACT(YEAR FROM order_date)
),
yearly_total AS (
  SELECT yr, SUM(store_revenue) AS total_revenue FROM store_yearly GROUP BY yr
),
share AS (
  SELECT sy.store_id, sy.yr, sy.store_revenue,
         ROUND(100.0 * sy.store_revenue / yt.total_revenue, 2) AS market_share_pct
  FROM store_yearly sy
  JOIN yearly_total yt ON yt.yr = sy.yr
)
SELECT store_id, yr, market_share_pct,
       market_share_pct - LAG(market_share_pct) OVER (PARTITION BY store_id ORDER BY yr) AS share_change
FROM share
ORDER BY store_id, yr;

/* Q56. -- orders span multiple categories, so "net_total per category" is computed at the order_item line level (unit_price * quantity) grouped by category. */
WITH item_values AS (
  SELECT cat.category_id, cat.category_name, (oi.unit_price * oi.quantity) AS line_value
  FROM sales.order_items oi
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
),
iqr AS (
  SELECT category_id,
         PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY line_value)::numeric AS q1,
         PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY line_value)::numeric AS q3
  FROM item_values
  GROUP BY category_id
)
SELECT iv.category_name, iv.line_value, ROUND(iqr.q1, 2) AS q1, ROUND(iqr.q3, 2) AS q3
FROM item_values iv
JOIN iqr ON iqr.category_id = iv.category_id
WHERE iv.line_value < iqr.q1 - 1.5 * (iqr.q3 - iqr.q1)
   OR iv.line_value > iqr.q3 + 1.5 * (iqr.q3 - iqr.q1)
ORDER BY iv.category_name;

/* Q57. */
WITH daily AS (
  SELECT order_date, EXTRACT(DOW FROM order_date)::int AS dow, SUM(net_total) AS revenue
  FROM sales.orders
  GROUP BY order_date, EXTRACT(DOW FROM order_date)
)
SELECT dow,
       CASE dow WHEN 0 THEN 'Sunday' WHEN 1 THEN 'Monday' WHEN 2 THEN 'Tuesday' WHEN 3 THEN 'Wednesday'
                WHEN 4 THEN 'Thursday' WHEN 5 THEN 'Friday' WHEN 6 THEN 'Saturday' END AS day_name,
       ROUND(AVG(revenue), 2) AS avg_revenue
FROM daily
GROUP BY dow
ORDER BY avg_revenue DESC;

/* Q58. */
WITH last_order AS (
  SELECT cust_id, MAX(order_date) AS last_order_date FROM sales.orders GROUP BY cust_id
)
SELECT cust_id, last_order_date,
       (SELECT MAX(order_date) FROM sales.orders) - last_order_date AS days_since,
       CASE
         WHEN (SELECT MAX(order_date) FROM sales.orders) - last_order_date <= 30 THEN 5
         WHEN (SELECT MAX(order_date) FROM sales.orders) - last_order_date <= 60 THEN 4
         WHEN (SELECT MAX(order_date) FROM sales.orders) - last_order_date <= 90 THEN 3
         WHEN (SELECT MAX(order_date) FROM sales.orders) - last_order_date <= 180 THEN 2
         ELSE 1
       END AS recency_score
FROM last_order
ORDER BY recency_score DESC;

/* Q59. */
WITH recent_sales AS (
  SELECT oi.prod_id, SUM(oi.quantity) AS units_sold_30d
  FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  WHERE o.order_date >= (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '30 days'
  GROUP BY oi.prod_id
),
inv AS (
  SELECT product_id, SUM(quantity_on_hand) AS total_inventory
  FROM products.inventory
  GROUP BY product_id
)
SELECT i.product_id, COALESCE(rs.units_sold_30d, 0) AS units_sold_30d, i.total_inventory,
       ROUND(COALESCE(rs.units_sold_30d, 0)::numeric / NULLIF(i.total_inventory, 0), 4) AS sell_through_rate
FROM inv i
LEFT JOIN recent_sales rs ON rs.prod_id = i.product_id
ORDER BY sell_through_rate DESC NULLS LAST;

/* Q60. */
WITH emp_pay AS (
  SELECT e.employee_id, e.dept_id, SUM(ps.gross_salary) AS total_gross
  FROM stores.employees e
  JOIN payroll.pay_slips ps ON ps.employee_id = e.employee_id
  GROUP BY e.employee_id, e.dept_id
),
ranked AS (
  SELECT *, DENSE_RANK() OVER (PARTITION BY dept_id ORDER BY total_gross DESC) AS rnk
  FROM emp_pay
)
SELECT dept_id, employee_id, total_gross, rnk
FROM ranked
WHERE rnk <= 5
ORDER BY dept_id, rnk;

/* Q61. */
WITH monthly_spend AS (
  SELECT DATE_TRUNC('month', spend_date)::date AS mth, SUM(amount) AS total_spend
  FROM marketing.ads_spend
  GROUP BY DATE_TRUNC('month', spend_date)
),
monthly_new AS (
  SELECT DATE_TRUNC('month', registration_date)::date AS mth, COUNT(*) AS new_customers
  FROM customers.customers
  GROUP BY DATE_TRUNC('month', registration_date)
)
SELECT ms.mth, ms.total_spend, mn.new_customers,
       ROUND(ms.total_spend / NULLIF(mn.new_customers, 0), 2) AS cac
FROM monthly_spend ms
JOIN monthly_new mn ON mn.mth = ms.mth
ORDER BY ms.mth;

/* Q62. */
WITH cohorts AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month
  FROM customers.customers
),
activity AS (
  SELECT c.customer_id, c.signup_month,
         (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), c.signup_month)) * 12
          + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), c.signup_month)))::int AS period_index
  FROM cohorts c
  JOIN sales.orders o ON o.cust_id = c.customer_id
),
cohort_size AS (
  SELECT signup_month, COUNT(*) AS cohort_size FROM cohorts GROUP BY signup_month
)
SELECT a.signup_month, a.period_index, cs.cohort_size,
       COUNT(DISTINCT a.customer_id) AS retained,
       ROUND(100.0 * COUNT(DISTINCT a.customer_id) / NULLIF(cs.cohort_size, 0), 2) AS retention_pct
FROM activity a
JOIN cohort_size cs ON cs.signup_month = a.signup_month
WHERE a.period_index BETWEEN 0 AND 6
GROUP BY a.signup_month, a.period_index, cs.cohort_size
ORDER BY a.signup_month, a.period_index;

/* Q63. */
SELECT product_id, product_name, price,
       ROUND(CUME_DIST() OVER (ORDER BY price)::numeric, 4) AS cume_dist_pct
FROM products.products
ORDER BY price;

/* Q64. */
WITH basket AS (
  SELECT order_id, COUNT(DISTINCT prod_id) AS distinct_products
  FROM sales.order_items
  GROUP BY order_id
),
bucketed AS (
  SELECT order_id, distinct_products,
         CASE WHEN distinct_products = 1 THEN '1'
              WHEN distinct_products BETWEEN 2 AND 3 THEN '2-3'
              WHEN distinct_products BETWEEN 4 AND 6 THEN '4-6'
              ELSE '7+' END AS bucket
  FROM basket
)
SELECT bucket, COUNT(*) AS order_count,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_orders
FROM bucketed
GROUP BY bucket
ORDER BY CASE bucket WHEN '1' THEN 1 WHEN '2-3' THEN 2 WHEN '4-6' THEN 3 ELSE 4 END;

/* Q65. */
SELECT order_id, cust_id, order_date, net_total,
       FIRST_VALUE(net_total) OVER (PARTITION BY cust_id ORDER BY order_date ROWS BETWEEN 2 PRECEDING AND 2 PRECEDING) AS value_2_rows_before
FROM sales.orders
ORDER BY cust_id, order_date;

/* Q66. */
WITH recent AS (
  SELECT order_date, COUNT(*) AS order_count
  FROM sales.orders
  WHERE order_date >= (SELECT MAX(order_date) FROM sales.orders) - 30
  GROUP BY order_date
),
prior_year AS (
  SELECT order_date, COUNT(*) AS order_count
  FROM sales.orders
  WHERE order_date >= ((SELECT MAX(order_date) FROM sales.orders) - INTERVAL '1 year' - INTERVAL '30 days')::date
    AND order_date < ((SELECT MAX(order_date) FROM sales.orders) - INTERVAL '1 year')::date
  GROUP BY order_date
)
SELECT r.order_date, r.order_count AS current_count,
       (r.order_date - INTERVAL '1 year')::date AS prior_year_date,
       p.order_count AS prior_year_count
FROM recent r
LEFT JOIN prior_year p ON p.order_date = (r.order_date - INTERVAL '1 year')::date
ORDER BY r.order_date;

/* Q67. */
WITH cust_spend AS (
  SELECT cust_id, SUM(net_total) AS total_spend
  FROM sales.orders
  GROUP BY cust_id
),
ranked AS (
  SELECT cust_id, total_spend,
         ROW_NUMBER() OVER (ORDER BY total_spend) AS rn,
         COUNT(*) OVER () AS n,
         SUM(total_spend) OVER () AS grand_total
  FROM cust_spend
)
SELECT ROUND(
  (2.0 * SUM(rn::numeric * total_spend) / (MAX(n)::numeric * MAX(grand_total))) - (MAX(n) + 1)::numeric / MAX(n),
  4
) AS gini_coefficient
FROM ranked;

/* Q68. -- orders span multiple categories, so revenue contribution is computed at the order_item line level per category. */
WITH item_values AS (
  SELECT cat.category_name, (oi.unit_price * oi.quantity) AS line_value
  FROM sales.order_items oi
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
)
SELECT category_name,
       ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY line_value)::numeric, 2) AS p25_value,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY line_value)::numeric, 2) AS median_value,
       ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY line_value)::numeric, 2) AS p75_value,
       ROUND(SUM(line_value), 2) AS total_category_revenue
FROM item_values
GROUP BY category_name
ORDER BY category_name;

/* Q69. -- supply_chain.shipments has no expected_delivery_date column, so the 3-day shipped-to-arrival window is used directly as the SLA target. */
SELECT
  COUNT(*) AS total_shipments,
  COUNT(*) FILTER (WHERE arrival_date - shipped_date <= 3) AS within_3_days,
  ROUND(100.0 * COUNT(*) FILTER (WHERE arrival_date - shipped_date <= 3) / NULLIF(COUNT(*), 0), 2) AS sla_pct
FROM supply_chain.shipments
WHERE arrival_date IS NOT NULL AND shipped_date IS NOT NULL;

/* Q70. */
WITH monthly AS (
  SELECT DATE_TRUNC('month', order_date)::date AS mth, SUM(net_total) AS revenue
  FROM sales.orders
  GROUP BY DATE_TRUNC('month', order_date)
),
deltas AS (
  SELECT mth, revenue, revenue - LAG(revenue) OVER (ORDER BY mth) AS mom_delta
  FROM monthly
)
SELECT mth, revenue, mom_delta
FROM deltas
WHERE mom_delta IS NOT NULL
ORDER BY mom_delta ASC
LIMIT 1;

/* Q71. */
WITH cum_points AS (
  SELECT customer_id, date_earned,
         SUM(points_earned) OVER (PARTITION BY customer_id ORDER BY date_earned) AS cumulative_points
  FROM customers.loyalty_points
),
current_tier AS (
  SELECT m.customer_id, t.tier_name, t.min_points
  FROM loyalty.members m
  JOIN loyalty.tiers t ON t.tier_id = m.tier_id
)
SELECT ct.customer_id, ct.tier_name, MIN(cp.date_earned) AS tier_upgrade_date
FROM current_tier ct
JOIN cum_points cp ON cp.customer_id = ct.customer_id AND cp.cumulative_points >= ct.min_points
GROUP BY ct.customer_id, ct.tier_name
ORDER BY ct.customer_id;

/* Q72. */
SELECT EXTRACT(HOUR FROM call_start_time)::int AS call_hour, COUNT(*) AS call_count
FROM call_center.calls
GROUP BY EXTRACT(HOUR FROM call_start_time)
ORDER BY call_hour;

/* Q73. */
WITH cust_prod AS (
  SELECT DISTINCT oi.prod_id, o.cust_id, cat.category_id
  FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
),
pairs AS (
  SELECT a.category_id, a.prod_id AS product_a, b.prod_id AS product_b, COUNT(DISTINCT a.cust_id) AS customers_both
  FROM cust_prod a
  JOIN cust_prod b ON a.category_id = b.category_id AND a.cust_id = b.cust_id AND a.prod_id < b.prod_id
  GROUP BY a.category_id, a.prod_id, b.prod_id
)
SELECT category_id, product_a, product_b, customers_both,
       ROUND(100.0 * customers_both / (SELECT COUNT(DISTINCT cust_id) FROM cust_prod), 2) AS pct_of_customers
FROM pairs
ORDER BY customers_both DESC
LIMIT 100;

/* Q74. */
WITH viewers AS (
  SELECT DISTINCT customer_id FROM web_events.page_views WHERE customer_id IS NOT NULL
),
cart AS (
  SELECT DISTINCT pv.customer_id
  FROM web_events.events ev
  JOIN web_events.page_views pv ON pv.view_id = ev.view_id
  WHERE ev.event_type = 'add_to_cart' AND pv.customer_id IS NOT NULL
),
purchasers AS (
  SELECT DISTINCT cust_id AS customer_id FROM sales.orders
)
SELECT
  (SELECT COUNT(*) FROM viewers) AS step1_viewed,
  (SELECT COUNT(*) FROM cart) AS step2_added_to_cart,
  (SELECT COUNT(*) FROM purchasers p JOIN cart c ON c.customer_id = p.customer_id) AS step3_purchased,
  ROUND(100.0 * (SELECT COUNT(*) FROM cart) / NULLIF((SELECT COUNT(*) FROM viewers), 0), 2) AS view_to_cart_pct,
  ROUND(100.0 * (SELECT COUNT(*) FROM purchasers p JOIN cart c ON c.customer_id = p.customer_id)
        / NULLIF((SELECT COUNT(*) FROM cart), 0), 2) AS cart_to_purchase_pct;

/* Q75. */
SELECT r.region_name, s.store_name, SUM(o.net_total) AS revenue
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY ROLLUP (r.region_name, s.store_name)
ORDER BY r.region_name NULLS LAST, s.store_name NULLS LAST;

/* ============================================================
   SECTION D: PERFORMANCE & DESIGN (25)
   ------------------------------------------------------------ */
/* Q76. -- Wrapping order_date in EXTRACT(YEAR FROM order_date) forces Postgres to evaluate that expression on every row before comparing, so a plain B-tree index on the raw order_date column cannot drive the scan; rewritten as a direct range predicate it can: */
SELECT * FROM sales.orders WHERE order_date >= DATE '2025-01-01' AND order_date < DATE '2026-01-01';

/* Q77. -- prod_id as the leading (equality) key narrows to that product's rows via a range scan, and unit_price DESC as the second key lets Postgres walk the index already in the needed order, satisfying ORDER BY unit_price DESC LIMIT 10 without a separate Sort: */
CREATE INDEX IF NOT EXISTS ix_order_items_prod_price ON sales.order_items(prod_id, unit_price DESC);

/* Q78. EXPLAIN ANALYZE on a slow 3-table join would likely show a large gap between estimated and actual row counts on one join step (stale statistics), a Hash Join with multiple batches or a Nested Loop with a very high loop count (working set doesn't fit work_mem or a missing index turns it into a per-row lookup), and possibly an extra Sort before a Limit; the fixes are typically to run ANALYZE to refresh statistics, add an index on the columns actually used to join/filter (order_id on order_items, product_id on products), and confirm work_mem is large enough that hash/sort operations don't spill to disk. */

/* Q79. -- a functional (expression) index on LOWER(email) matches the WHERE LOWER(email) = ... predicate directly: */
CREATE INDEX IF NOT EXISTS ix_customers_lower_email ON customers.customers (LOWER(email));

/* Q80. COUNT(*) is slow on a large table because MVCC keeps multiple row versions and there is no single stored row-count - Postgres must visit every tuple and check its visibility to the current transaction; a fast approximate alternative is n_live_tup from pg_stat_user_tables (or reltuples in pg_class), both maintained by ANALYZE/autovacuum rather than counted live: */
SELECT relname, n_live_tup FROM pg_stat_user_tables WHERE schemaname = 'sales' AND relname = 'orders';

/* Q81. Refreshing a materialized view built on a 500k-row join re-runs the full underlying query every time, and a plain REFRESH takes an ACCESS EXCLUSIVE lock that blocks all reads of the MV until it completes; REFRESH MATERIALIZED VIEW CONCURRENTLY avoids that lock (readers keep seeing the old data until the new version is ready) but requires the MV to already have at least one UNIQUE index, so it is only usable once that index exists and is worth using whenever the refresh cadence is frequent enough that blocking readers for the full rebuild would be unacceptable. */

/* Q82. */
CREATE INDEX IF NOT EXISTS ix_orders_returned_date ON sales.orders (order_date) WHERE order_status = 'Returned';
SELECT * FROM sales.orders WHERE order_status = 'Returned' AND order_date >= DATE '2025-01-01';

/* Q83. Three reasons the optimizer may correctly choose a Seq Scan over an index: (1) the filter matches a large fraction of the table, so many random-I/O index lookups cost more than one sequential pass; (2) the table (or the matching portion) is small enough to fit in a handful of pages, making a Seq Scan trivially cheap regardless of an index; (3) the table's pages are already resident in shared_buffers, so sequential access is nearly free and the extra index-traversal cost isn't worth paying. */

/* Q84. */
CREATE INDEX IF NOT EXISTS ix_order_items_prod_order_price ON sales.order_items (prod_id, order_id, unit_price);
SELECT * FROM sales.order_items WHERE prod_id = 100 AND order_id > 1000 ORDER BY unit_price;

/* Q85. A LATERAL join executed once per outer row over all 50,000 customers pays the per-call cost (planning + an index range scan on order_items) 50,000 times, even for customers who contribute nothing to the result; bounding the outer set first (e.g. filtering to only customers with at least one qualifying order before the LATERAL) cuts the number of LATERAL invocations proportionally - the per-call cost of the subquery itself doesn't change, but it simply runs far fewer times. */

/* Q86. -- ORDER BY random() forces Postgres to compute a random key for and sort every row before taking the top 10, an O(n log n) full-table pass for a tiny result; TABLESAMPLE reads only a random subset of the table's physical blocks directly, without a full scan or sort: */
SELECT * FROM sales.orders TABLESAMPLE SYSTEM (1) LIMIT 10;

/* Q87. A B-tree index on view_timestamp supports the BETWEEN range predicate directly as a bounded index range scan; since web_events.page_views is large (500k rows, growing) and naturally insert-ordered by time, range-partitioning it by month on view_timestamp would additionally let date-range queries skip entire partitions outright (partition pruning), and would keep each partition's own index smaller and cheaper to vacuum/maintain independently. */

/* Q88. A layered view hierarchy - v_orders_enriched (orders joined to customers/stores/region), v_monthly_revenue (aggregated by month/store/region from the layer below), v_product_performance (order_items joined to products/category with revenue and margin), and v_customer_rfm (recency/frequency/monetary scores) - each reading only base tables or the layer directly beneath it; supporting indexes on the base tables would target the columns those views actually filter/join/group by: sales.orders(order_date), sales.orders(cust_id), sales.order_items(prod_id), stores.stores(region_id), customers.customers(customer_id). */

/* Q89. A Hash Aggregate builds an in-memory hash table keyed by the GROUP BY columns and can consume input in any order - Postgres prefers it when the input isn't already sorted by those columns and the expected number of distinct groups fits comfortably in work_mem. A Group Aggregate requires input already ordered by the grouping columns (via an index or an explicit Sort) and streams consecutive matching rows into each aggregate in one pass - Postgres prefers this when the input is already sorted or when there are too many distinct groups for a hash table to fit in memory. */

/* Q90. A high-cost Sort before a Limit means Postgres is materializing and sorting the entire result set before taking just the first N rows; adding a B-tree index on the ORDER BY column(s) in the matching direction lets Postgres instead walk the index in that order and stop as soon as it has N rows, eliminating the Sort node entirely. */

/* Q91. */
CREATE INDEX IF NOT EXISTS ix_page_views_view_timestamp_brin ON web_events.page_views USING BRIN (view_timestamp);
/* A BRIN index here outperforms a B-tree when rows are inserted roughly in view_timestamp order (so each physical block covers a narrow time range) and typical queries filter a wide date range rather than an exact timestamp - BRIN's tiny per-block min/max summary lets Postgres skip whole blocks cheaply, at a small fraction of a B-tree's storage cost, though it degrades if the table stops being well time-correlated (e.g. after heavy out-of-order UPDATEs). */

/* Q92. */
CREATE INDEX IF NOT EXISTS ix_page_views_customer_timestamp ON web_events.page_views (customer_id, view_timestamp);
SELECT * FROM web_events.page_views WHERE customer_id = 100 AND view_timestamp BETWEEN '2025-01-01' AND '2025-02-01';

/* Q93. -- DISTINCT ON (cust_id) ORDER BY cust_id, order_date DESC requires the rows physically ordered by (cust_id, order_date DESC) before Postgres can keep only the first row per cust_id; a composite index in that exact order eliminates the Sort by letting Postgres scan the index directly in the required sequence: */
CREATE INDEX IF NOT EXISTS ix_orders_cust_date_desc ON sales.orders (cust_id, order_date DESC);

/* Q94. A data-modifying CTE (UPDATE/DELETE ... RETURNING) executes exactly once as part of the surrounding statement with no separate confirmation step - a mistyped or overly broad WHERE clause modifies every matching row immediately, and unlike a SELECT preview there is no chance to review the affected rows first. Safeguards: always run the equivalent SELECT first to sanity-check the row count, wrap the statement in an explicit transaction (BEGIN, verify, then COMMIT or ROLLBACK), and use RETURNING to capture exactly what changed for audit purposes. */

/* Q95. Run each individual CTE's query on its own inside EXPLAIN ANALYZE (as a standalone SELECT) to see its actual runtime and row count versus the planner's estimate for that step in isolation; alternatively, EXPLAIN (ANALYZE, BUFFERS) on the full 5-level chain and inspecting each CTE Scan node's own "actual time" pinpoints the one node with disproportionate cost - in modern Postgres (12+) CTEs can be inlined by the planner, so the per-node breakdown in the full plan is usually the faster way to isolate the bottleneck. */

/* Q96. work_mem controls how much memory a single sort or hash-table operation may use before spilling to disk; if it's set too low, the planner assumes a hash join's build side won't comfortably fit in memory and costs it as more expensive than a nested loop, so it picks nested loops even on a large table - raising work_mem (session-level via SET work_mem, or globally) often lets the planner switch back to the cheaper hash join. */

/* Q97. A SQL result set is logically unordered unless the outermost query itself has an ORDER BY; Postgres is free to apply any optimization (reordering rows during a join, aggregation, or parallel scan merge) that changes row order, and a subquery's own ORDER BY only guarantees order for something order-dependent evaluated within that subquery (like its own LIMIT) - it does not propagate to the outer query. To guarantee final row order, the ORDER BY must be on the outermost SELECT. */

/* Q98. */
ALTER TABLE sales.orders SET (fillfactor = 90);
/* FILLFACTOR reserves a percentage of free space on each page at INSERT time so a later UPDATE can write the new row version into the same page as the old one (a HOT update) instead of a different page, avoiding extra index maintenance; a lower FILLFACTOR (e.g. 90) on a frequently-updated table like sales.orders trades a small amount of extra disk space for cheaper in-place updates. */

/* Q99. */
SELECT schemaname, tablename, attname, correlation
FROM pg_catalog.pg_stats
WHERE schemaname = 'sales' AND tablename = 'orders'
ORDER BY ABS(correlation) DESC;
/* A column with correlation near +1 or -1 (e.g. order_date, inserted roughly in chronological order) has its physical row order closely matching its logical/sorted order - a range-scan index on it visits mostly-sequential heap pages (cheap); a column near 0 correlation (e.g. a randomly-assigned id) forces the same index scan to jump around the heap unpredictably, which the planner costs as expensive random I/O and may avoid using the index for at all. */

/* Q100. The three MVs (product_performance, customer_segments, store_kpis) each read directly from base tables with no MV depending on another MV, so there is no ordering requirement between them - they can refresh in any order, or in parallel, to minimize total wall-clock refresh time. The only ordering that matters is refreshing each MV only after its own upstream base tables have finished loading for the period; refreshing early would capture partial data for that MV specifically, which is a correctness issue between the MV and its own ETL step, not between the three MVs themselves. */
