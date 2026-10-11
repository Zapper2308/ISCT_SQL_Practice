/* ============================================================
   ANSWER KEY - Window Functions Part 1: Ranking & Bucketing (CRAZY LEVEL)
   Curriculum:   RetailMart V3
   Note: this database has NO indexes on foreign-key columns, so
   per-row correlated-subquery patterns whose driving table is large
   (customers, orders) are restricted to a bounded sample where noted;
   the same pattern is correct unrestricted, just slower on this
   unindexed practice copy.
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1.  Order by a fully-unique tie-breaker last (e.g. ORDER BY score DESC, created_at DESC, id ASC), and paginate with WHERE (score, id) < (last_score, last_id) rather than OFFSET - this keeps ROW_NUMBER stable and cheap across pages even as new rows are inserted. */
/* Q2.  Each independent OVER() clause forces its own sort/partition pass unless they share identical PARTITION BY/ORDER BY, in which case the WINDOW clause (WINDOW w AS (...)) lets Postgres compute the sort once and reuse it for every function written as OVER w, cutting repeated sort cost. */
/* Q3.  Rank the same tied rows twice in separate query runs (or via two ROW_NUMBER columns with the same ORDER BY but no full tie-breaker) and show the assigned numbers can differ per row between runs - only adding a unique column to the ORDER BY pins down one deterministic answer. */
/* Q4.  A window-function filter (ROW_NUMBER<=N in an outer query) forces the whole partition to be computed/sorted, then discards most of it; LATERAL runs a small ORDER BY...LIMIT N query per outer row and can use an index per lookup; DISTINCT ON is a single-pass, Postgres-native "first row per group" that avoids materializing a rank column at all - at scale, LATERAL/DISTINCT ON usually win when there's a supporting index, while window-filter wins when you need N>1 or must avoid N separate small subquery calls. */
/* Q5.  When two rows have identical ORDER BY values, NTILE evaluates the underlying row order (which is otherwise unconstrained for ties) to assign sequential positions before cutting into N buckets - so two equal values can be split into different buckets purely based on that undefined tie order, unless a tie-breaker is added. */
/* Q6.  Ranking first and filtering to a small survivor set before joining keeps the fan-out (multiplication of rows from a one-to-many join) applied only to the already-small winner set; joining first and ranking after means the window function has to run over the full, already-fanned-out row count, and any subsequent aggregate could double-count. */
/* Q7.  RANK() OVER (ORDER BY (0.5*norm_spend + 0.3*freq_score + 0.2*recency_score) DESC) - compute the weighted composite as a plain arithmetic expression (built from normalized component scores) directly inside the ORDER BY of the window function, exactly like ranking on any other single computed value. */
/* Q8.  NTILE(100) buckets by ROW COUNT position only (an approximation, coarse when the partition has <100 rows, and ties can straddle bucket edges); PERCENT_RANK gives an exact continuous (rank-1)/(rows-1) value in [0,1]; CUME_DIST gives the exact fraction of rows with a value <= the current row (inclusive, so ties get the same cume_dist) - PERCENT_RANK/CUME_DIST are exact and continuous, NTILE is a discrete grouping convenience. */
/* Q9.  Choose a partition key that represents the real-world entity being deduplicated (e.g. normalized email, not raw customer_id) and an ORDER BY that encodes the authoritative "most trustworthy" record first (e.g. most recently verified, or most complete) - the golden record is then just rn=1 within that partition/order combination. */
/* Q10. DISTINCT ON (partition_cols) ORDER BY partition_cols, tiebreak skips computing an explicit rank number for every row - Postgres can often satisfy it with a single index-driven "skip scan" per group (especially with a matching index), whereas ROW_NUMBER()=1 must first compute and materialize a rank for every row in the partition before the outer filter discards all but one. */
/* Q11. PARTITION BY DATE_TRUNC('week'/'month', event_date) creates rolling cohort buckets, but rows right at a boundary (11:59pm vs 12:00am) land in different cohorts even though they're seconds apart, and a cohort that's still "open" (current, incomplete month) will look artificially small/incomplete compared to closed cohorts if not excluded. */
/* Q12. RANK()<=N with ties naturally returns >= N rows (ties widen the result); to guarantee EXACTLY N regardless of ties, use ROW_NUMBER()<=N with a full tie-breaker in the ORDER BY; to guarantee AT LEAST N (include every tied row at the boundary), use RANK()<=N. */
/* Q13. Nest window functions in stacked CTEs: first rank stores within region and filter to top-2, then within that filtered result rank products per surviving store and filter to top-3 - each stage's WHERE on the previous stage's rank column narrows the driving set before the next window function runs. */
/* Q14. Bucket boundaries computed fresh each run shift as new rows are added/removed, so the SAME customer can silently move from "Q1" to "Q2" between two reports even though their own metric didn't change - purely because everyone else's changed the cut points; storing/reporting is done from a query, not a stored table, deliberately to reflect current standing rather than stale history. */
/* Q15. All-equal frequency (e.g. everyone has exactly 1 order) makes NTILE(5) on frequency degenerate - ties get split arbitrarily across buckets with no real signal; single-order customers have no meaningful "average order value" or trend, so RFM scoring for them should fall back to a flag/default segment rather than trusting the raw NTILE bucket. */
/* Q16. Materializing the computed column in a CTE first means Postgres only evaluates the (possibly expensive) expression once per row before ranking, rather than potentially re-evaluating it multiple times if referenced repeatedly in the ORDER BY/SELECT of a single window function call - it also makes the ranking logic more readable and reusable. */
/* Q17. Text collation settings affect how string ties sort (case/locale-sensitive ordering can vary by server config), NULLS FIRST/LAST defaults differ between ASC/DESC, and without a fully-unique tail column in the ORDER BY, the exact ordering among ties is left to the query plan - all three must be pinned down explicitly for a truly reproducible rank across environments. */
/* Q18. Compute PERCENT_RANK() (or NTILE(100)) over the metric, then filter out rows below/above chosen percentile cutoffs (e.g. WHERE pct_rank BETWEEN 0.01 AND 0.99) before doing further ranking/aggregation on the remaining "trimmed" rows - keeps outlier removal declarative and reusable. */
/* Q19. Rank normally per group first, then also compute a GLOBAL ROW_NUMBER() OVER (ORDER BY the same metric DESC) across all rows; filter to rows where the per-group rank is <=3 AND the global rank is <=50, combining a local cap with an overall cap in the same result. */
/* Q20. DENSE_RANK gives the correct DISPLAY position (ties share a rank, no confusing skipped numbers on the visible leaderboard); ROW_NUMBER gives a strictly unique sequence needed for PAGINATION (so "page 2 starts at row 21" is unambiguous even when several leaderboard entries are tied) - a real leaderboard UI typically shows DENSE_RANK to the user while using ROW_NUMBER internally to slice pages. */
/* Q21. As new rows are added, NTILE recomputed fresh will re-cut the boundaries, so a customer whose own value never changed can drift into a different bucket purely because the population around them shifted; mitigation is to snapshot bucket assignments (or their cut-point values) at a point in time and hold them fixed for historical reporting instead of always recomputing live. */
/* Q22. Build a CASE expression that encodes the business tie-break priority as a sortable value (e.g. CASE priority WHEN 'Critical' THEN 1 WHEN 'High' THEN 2 ... END), then use that CASE expression as an ORDER BY key inside the window function exactly like any other column - letting arbitrary business logic drive the ranking order. */
/* Q23. Because a single query with 4 independent OVER() clauses lets Postgres plan/optimize all four window computations together against one consistent snapshot of the data, guaranteeing they all see the exact same row set; four separate self-joins each re-read/re-join the table independently, multiplying I/O and risking subtly different results if the underlying data changes between joins (or under concurrent writes). */
/* Q24. Compute the leader's value (rank=1) and the runner-up's value (rank=2) per group (e.g. via two FILTER'd MAX or a pivot from ranked rows), then divide leader_value / NULLIF(runner_up_value, 0) - a "dominance" ratio near 1 means a close race, a large ratio means the leader is far ahead. */
/* Q25. Snapshot the NTILE(4) cut-point VALUES (e.g. MAX(spend) per bucket) into a small reference table at a chosen point in time, then classify future rows against those fixed thresholds with a CASE/WIDTH_BUCKET instead of re-running NTILE - this keeps bucket membership reproducible even as the underlying population keeps changing. */

/* ============================================================
   SECTION B: MULTI-WINDOW RANKING (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT p.product_id, p.product_name, p.brand_id, p.price,
       RANK() OVER (PARTITION BY p.brand_id ORDER BY p.price DESC) AS rank_in_brand,
       RANK() OVER (ORDER BY p.price DESC) AS rank_overall
FROM products.products p
ORDER BY rank_overall
LIMIT 200;

/* Q27. */
SELECT e.employee_id, e.dept_id, e.store_id, e.salary,
       RANK() OVER (PARTITION BY e.dept_id ORDER BY e.salary DESC) AS rank_in_dept,
       RANK() OVER (PARTITION BY e.store_id ORDER BY e.salary DESC) AS rank_in_store,
       RANK() OVER (ORDER BY e.salary DESC) AS rank_company
FROM stores.employees e
ORDER BY rank_company
LIMIT 200;

/* Q28. */
WITH cust_spend AS (
  SELECT c.customer_id, c.tier, s.region_id, COALESCE(SUM(o.net_total),0) AS total_spend
  FROM customers.customers c
  JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = TRUE
  JOIN stores.stores s ON s.city = a.city
  LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
  GROUP BY c.customer_id, c.tier, s.region_id
)
SELECT customer_id, region_id, tier, total_spend,
       RANK() OVER (PARTITION BY region_id ORDER BY total_spend DESC) AS rank_in_region,
       RANK() OVER (PARTITION BY tier ORDER BY total_spend DESC) AS rank_in_tier
FROM cust_spend
ORDER BY region_id, rank_in_region
LIMIT 200;

/* Q29. */
WITH cust_agg AS (
  SELECT cust_id AS customer_id,
         (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS recency_days,
         COUNT(*) AS order_count,
         SUM(net_total) AS total_spend
  FROM sales.orders
  GROUP BY cust_id
),
norm AS (
  SELECT customer_id,
         (total_spend - MIN(total_spend) OVER ()) / NULLIF(MAX(total_spend) OVER () - MIN(total_spend) OVER (), 0) AS norm_spend,
         (order_count - MIN(order_count) OVER ())::numeric / NULLIF(MAX(order_count) OVER () - MIN(order_count) OVER (), 0) AS norm_freq,
         1 - (recency_days - MIN(recency_days) OVER ())::numeric / NULLIF(MAX(recency_days) OVER () - MIN(recency_days) OVER (), 0) AS norm_recency
  FROM cust_agg
),
scored AS (
  SELECT customer_id,
         (0.5 * COALESCE(norm_spend,0) + 0.3 * COALESCE(norm_freq,0) + 0.2 * COALESCE(norm_recency,0)) AS composite_score
  FROM norm
)
SELECT customer_id, composite_score,
       RANK() OVER (ORDER BY composite_score DESC) AS leaderboard_rank,
       ROW_NUMBER() OVER (ORDER BY composite_score DESC, customer_id) AS page_position
FROM scored
ORDER BY leaderboard_rank
LIMIT 200;

/* Q30. */
WITH product_units AS (
  SELECT p.product_id, SUM(oi.quantity) AS units_sold
  FROM products.products p
  JOIN sales.order_items oi ON oi.prod_id = p.product_id
  GROUP BY p.product_id
)
SELECT p.product_id, p.price, pu.units_sold,
       RANK() OVER (ORDER BY p.price DESC) AS price_rank,
       DENSE_RANK() OVER (ORDER BY pu.units_sold DESC) AS units_dense_rank
FROM products.products p
JOIN product_units pu ON pu.product_id = p.product_id
ORDER BY price_rank
LIMIT 200;

/* Q31. */
WITH region_revenue AS (
  SELECT s.region_id, SUM(o.net_total) AS revenue
  FROM stores.stores s
  JOIN sales.orders o ON o.store_id = s.store_id
  GROUP BY s.region_id
),
top_regions AS (
  SELECT region_id FROM region_revenue
  ORDER BY revenue DESC LIMIT 2
),
store_revenue AS (
  SELECT s.store_id, s.region_id, SUM(o.net_total) AS revenue
  FROM stores.stores s
  JOIN sales.orders o ON o.store_id = s.store_id
  WHERE s.region_id IN (SELECT region_id FROM top_regions)
  GROUP BY s.store_id, s.region_id
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY region_id ORDER BY revenue DESC) AS rn
  FROM store_revenue
)
SELECT region_id, store_id, revenue
FROM ranked
WHERE rn <= 3
ORDER BY region_id, revenue DESC;

/* Q32. */
SELECT oi.order_id, oi.order_item_id, oi.net_amount,
       RANK() OVER (PARTITION BY oi.order_id ORDER BY oi.net_amount DESC) AS line_rank_in_order,
       RANK() OVER (PARTITION BY o.cust_id ORDER BY o.net_total DESC) AS order_rank_for_customer
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
ORDER BY o.cust_id, order_rank_for_customer, line_rank_in_order
LIMIT 200;

/* Q33. */
WITH store_metrics AS (
  SELECT store_id, SUM(net_total) AS revenue, COUNT(*) AS order_count
  FROM sales.orders
  GROUP BY store_id
),
ranked AS (
  SELECT store_id, revenue, order_count,
         RANK() OVER (ORDER BY revenue DESC) AS revenue_rank,
         RANK() OVER (ORDER BY order_count DESC) AS order_count_rank
  FROM store_metrics
)
SELECT store_id, revenue, order_count, revenue_rank, order_count_rank,
       ABS(revenue_rank - order_count_rank) AS rank_disagreement
FROM ranked
WHERE revenue_rank <> order_count_rank
ORDER BY rank_disagreement DESC
LIMIT 100;

/* Q34. */
SELECT order_id, cust_id, net_total,
       RANK() OVER (PARTITION BY cust_id ORDER BY net_total DESC) AS value_rank,
       (RANK() OVER (PARTITION BY cust_id ORDER BY net_total DESC) = 1) AS is_largest_order
FROM sales.orders
ORDER BY cust_id, value_rank
LIMIT 200;

/* Q35. */
SELECT employee_id, dept_id, salary,
       ROW_NUMBER() OVER w AS rn,
       RANK() OVER w AS rnk,
       DENSE_RANK() OVER w AS drnk
FROM stores.employees
WINDOW w AS (PARTITION BY dept_id ORDER BY salary DESC)
ORDER BY dept_id, rnk
LIMIT 200;

/* Q36. */
WITH brand_revenue AS (
  SELECT cat.category_id, b.brand_id, SUM(oi.net_amount) AS revenue
  FROM core.dim_category cat
  JOIN core.dim_brand b ON b.category_id = cat.category_id
  JOIN products.products p ON p.brand_id = b.brand_id
  JOIN sales.order_items oi ON oi.prod_id = p.product_id
  GROUP BY cat.category_id, b.brand_id
),
category_revenue AS (
  SELECT category_id, SUM(revenue) AS revenue
  FROM brand_revenue
  GROUP BY category_id
)
SELECT br.category_id, br.brand_id, br.revenue AS brand_revenue,
       RANK() OVER (PARTITION BY br.category_id ORDER BY br.revenue DESC) AS brand_rank_in_category,
       cr.revenue AS category_revenue,
       RANK() OVER (ORDER BY cr.revenue DESC) AS category_rank_overall
FROM brand_revenue br
JOIN category_revenue cr ON cr.category_id = br.category_id
ORDER BY category_rank_overall, brand_rank_in_category;

/* Q37. */
WITH agent_metrics AS (
  SELECT agent_id, COUNT(*) AS resolved_count,
         AVG(resolved_date - created_date) AS avg_resolution
  FROM support.tickets
  WHERE status = 'Resolved' AND agent_id IS NOT NULL
  GROUP BY agent_id
)
SELECT agent_id, resolved_count, avg_resolution,
       RANK() OVER (ORDER BY resolved_count DESC) AS resolved_rank,
       RANK() OVER (ORDER BY avg_resolution ASC) AS speed_rank,
       (RANK() OVER (ORDER BY resolved_count DESC) + RANK() OVER (ORDER BY avg_resolution ASC)) AS combined_score
FROM agent_metrics
ORDER BY combined_score
LIMIT 100;

/* Q38. */
WITH product_units AS (
  SELECT p.product_id, p.brand_id, SUM(oi.quantity) AS units_sold
  FROM products.products p
  JOIN sales.order_items oi ON oi.prod_id = p.product_id
  GROUP BY p.product_id, p.brand_id
)
SELECT product_id, brand_id, units_sold,
       RANK() OVER (PARTITION BY brand_id ORDER BY units_sold DESC) AS brand_rank,
       RANK() OVER (ORDER BY units_sold DESC) AS global_rank,
       (RANK() OVER (ORDER BY units_sold DESC) <= 100) AS in_global_top_100
FROM product_units
ORDER BY brand_id, brand_rank
LIMIT 200;

/* Q39. */
WITH store_revenue AS (
  SELECT s.store_id, s.region_id, SUM(o.net_total) AS revenue
  FROM stores.stores s
  JOIN sales.orders o ON o.store_id = s.store_id
  GROUP BY s.store_id, s.region_id
),
store_reviews AS (
  SELECT s.store_id, AVG(r.rating) AS review_score
  FROM stores.stores s
  JOIN sales.orders o ON o.store_id = s.store_id
  JOIN sales.order_items oi ON oi.order_id = o.order_id
  JOIN customers.reviews r ON r.product_id = oi.prod_id
  GROUP BY s.store_id
)
SELECT sr.store_id, sr.region_id, sr.revenue, srv.review_score,
       RANK() OVER (PARTITION BY sr.region_id ORDER BY sr.revenue DESC) AS revenue_rank,
       RANK() OVER (PARTITION BY sr.region_id ORDER BY srv.review_score DESC) AS review_rank
FROM store_revenue sr
LEFT JOIN store_reviews srv ON srv.store_id = sr.store_id
ORDER BY sr.region_id, revenue_rank
LIMIT 200;

/* Q40. */
WITH group_revenue AS (
  SELECT store_id, net_total,
         RANK() OVER (PARTITION BY store_id ORDER BY net_total DESC) AS rnk
  FROM sales.orders
),
top2 AS (
  SELECT store_id,
         MAX(net_total) FILTER (WHERE rnk = 1) AS leader_value,
         MAX(net_total) FILTER (WHERE rnk = 2) AS runner_up_value
  FROM group_revenue
  WHERE rnk <= 2
  GROUP BY store_id
)
SELECT store_id, leader_value, runner_up_value,
       ROUND(leader_value / NULLIF(runner_up_value, 0), 2) AS dominance_ratio
FROM top2
ORDER BY dominance_ratio DESC NULLS LAST
LIMIT 100;

/* Q41. */
WITH cust_agg AS (
  SELECT cust_id AS customer_id,
         (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS recency_days,
         SUM(net_total) AS total_spend
  FROM sales.orders
  GROUP BY cust_id
),
scored AS (
  SELECT customer_id,
         NTILE(4) OVER (ORDER BY recency_days ASC) AS recency_quartile,
         NTILE(4) OVER (ORDER BY total_spend DESC) AS monetary_quartile
  FROM cust_agg
)
SELECT customer_id
FROM scored
WHERE recency_quartile = 1 AND monetary_quartile = 1
LIMIT 200;

/* Q42. */
WITH product_stock AS (
  SELECT isn.warehouse_id, isn.product_id, isn.quantity_on_hand
  FROM supply_chain.inventory_snapshots isn
  WHERE isn.snapshot_date = (SELECT MAX(snapshot_date) FROM supply_chain.inventory_snapshots)
),
product_turnover AS (
  SELECT prod_id, SUM(quantity) AS units_sold
  FROM sales.order_items
  GROUP BY prod_id
)
SELECT ps.warehouse_id, ps.product_id, ps.quantity_on_hand, COALESCE(pt.units_sold,0) AS units_sold,
       RANK() OVER (PARTITION BY ps.warehouse_id ORDER BY ps.quantity_on_hand DESC) AS stock_rank,
       RANK() OVER (PARTITION BY ps.warehouse_id ORDER BY COALESCE(pt.units_sold,0) DESC) AS turnover_rank
FROM product_stock ps
LEFT JOIN product_turnover pt ON pt.prod_id = ps.product_id
ORDER BY ps.warehouse_id, stock_rank
LIMIT 200;

/* Q43. */
SELECT pay_slip_id, employee_id, salary_year, salary_month, net_salary,
       RANK() OVER (PARTITION BY salary_year ORDER BY net_salary DESC) AS rank_in_year,
       RANK() OVER (PARTITION BY salary_year, salary_month ORDER BY net_salary DESC) AS rank_in_year_month
FROM payroll.pay_slips
ORDER BY salary_year, salary_month, rank_in_year_month
LIMIT 200;

/* Q44. */
SELECT ticket_id, priority, status, created_date,
       RANK() OVER (
         ORDER BY
           CASE priority WHEN 'Critical' THEN 1 WHEN 'High' THEN 2 WHEN 'Medium' THEN 3 ELSE 4 END,
           created_date ASC
       ) AS sla_priority_rank
FROM support.tickets
WHERE status = 'Open'
ORDER BY sla_priority_rank
LIMIT 200;

/* Q45. */
WITH product_metrics AS (
  SELECT p.product_id, cat.category_id, p.price, (p.price - p.cost_price) AS margin,
         SUM(oi.quantity) AS units_sold
  FROM products.products p
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
  LEFT JOIN sales.order_items oi ON oi.prod_id = p.product_id
  GROUP BY p.product_id, cat.category_id, p.price, p.cost_price
)
SELECT category_id, product_id, units_sold, margin,
       RANK() OVER (PARTITION BY category_id ORDER BY units_sold DESC) AS units_rank,
       RANK() OVER (PARTITION BY category_id ORDER BY margin DESC) AS margin_rank
FROM product_metrics
WHERE units_sold IS NOT NULL
ORDER BY category_id, units_rank
LIMIT 200;

/* Q46. */
WITH campaign_spend AS (
  SELECT campaign_id, platform, SUM(amount) AS spend
  FROM marketing.ads_spend
  GROUP BY campaign_id, platform
),
platform_spend AS (
  SELECT platform, SUM(spend) AS spend
  FROM campaign_spend
  GROUP BY platform
)
SELECT cs.platform, cs.campaign_id, cs.spend AS campaign_spend,
       RANK() OVER (PARTITION BY cs.platform ORDER BY cs.spend DESC) AS campaign_rank_in_platform,
       ps.spend AS platform_spend,
       RANK() OVER (ORDER BY ps.spend DESC) AS platform_rank_overall
FROM campaign_spend cs
JOIN platform_spend ps ON ps.platform = cs.platform
ORDER BY platform_rank_overall, campaign_rank_in_platform;

/* Q47. */
WITH order_positions AS (
  SELECT order_id, cust_id, net_total,
         ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date ASC, order_id ASC) AS purchase_seq,
         RANK() OVER (PARTITION BY cust_id ORDER BY net_total DESC) AS value_rank
  FROM sales.orders
)
SELECT cust_id, order_id, net_total, value_rank
FROM order_positions
WHERE purchase_seq = 1
ORDER BY cust_id
LIMIT 200;

/* Q48. */
WITH city_metrics AS (
  SELECT a.city, COUNT(DISTINCT c.customer_id) AS customer_count, COALESCE(SUM(o.net_total),0) AS total_spend
  FROM customers.customers c
  JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = TRUE
  LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
  GROUP BY a.city
)
SELECT city, customer_count, total_spend,
       RANK() OVER (ORDER BY customer_count DESC) AS customer_count_rank,
       RANK() OVER (ORDER BY total_spend DESC) AS spend_rank
FROM city_metrics
ORDER BY customer_count_rank
LIMIT 100;

/* Q49. */
SELECT p.product_id, p.brand_id,
       NTILE(100) OVER (PARTITION BY p.brand_id ORDER BY p.price) AS brand_percentile,
       NTILE(100) OVER (ORDER BY p.price) AS overall_percentile
FROM products.products p
ORDER BY p.brand_id, brand_percentile
LIMIT 200;

/* Q50. */
WITH product_cat AS (
  SELECT p.product_id, p.brand_id, cat.category_id, p.price
  FROM products.products p
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
)
SELECT product_id, brand_id, category_id, price,
       RANK() OVER (PARTITION BY brand_id ORDER BY price DESC) AS brand_rank,
       RANK() OVER (PARTITION BY category_id ORDER BY price DESC) AS category_rank,
       RANK() OVER (ORDER BY price DESC) AS global_rank
FROM product_cat
ORDER BY global_rank
LIMIT 200;

/* ============================================================
   SECTION C: DEDUP & TOP-N AT SCALE (25)
   ------------------------------------------------------------ */
/* Q51. */
WITH ranked AS (
  SELECT customer_id, email, registration_date,
         ROW_NUMBER() OVER (PARTITION BY email ORDER BY registration_date DESC, customer_id DESC) AS rn
  FROM customers.customers
),
merged AS (
  SELECT email, STRING_AGG(customer_id::text, ',' ORDER BY customer_id) AS merged_ids
  FROM customers.customers
  GROUP BY email
)
SELECT r.email, r.customer_id AS golden_id, r.registration_date, m.merged_ids
FROM ranked r
JOIN merged m ON m.email = r.email
WHERE r.rn = 1
ORDER BY r.email
LIMIT 200;

/* Q52. */
WITH ranked AS (
  SELECT customer_id, email,
         ROW_NUMBER() OVER (PARTITION BY email ORDER BY registration_date DESC, customer_id DESC) AS rn
  FROM customers.customers
)
SELECT COUNT(*) AS total_rows,
       COUNT(*) FILTER (WHERE rn = 1) AS kept_rows,
       COUNT(*) FILTER (WHERE rn > 1) AS removed_rows
FROM ranked;

/* Q53. */
WITH product_units AS (
  SELECT p.product_id, LOWER(TRIM(p.product_name)) AS norm_name, p.brand_id, p.price,
         COALESCE(SUM(oi.quantity), 0) AS units_sold
  FROM products.products p
  LEFT JOIN sales.order_items oi ON oi.prod_id = p.product_id
  GROUP BY p.product_id, LOWER(TRIM(p.product_name)), p.brand_id, p.price
),
ranked AS (
  SELECT product_id, norm_name, brand_id, price, units_sold,
         ROW_NUMBER() OVER (PARTITION BY norm_name ORDER BY units_sold DESC, product_id) AS rn
  FROM product_units
)
SELECT norm_name AS golden_name, product_id AS surviving_product_id, brand_id AS surviving_brand_id, price
FROM ranked
WHERE rn = 1
LIMIT 200;

/* Q54. */
WITH row_number_method AS (
  SELECT cust_id, order_id, order_date,
         ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date DESC, order_id DESC) AS rn
  FROM sales.orders
)
SELECT cust_id, order_id, order_date
FROM row_number_method
WHERE rn = 1
ORDER BY cust_id
LIMIT 200;
/* Note: DISTINCT ON (cust_id) SELECT cust_id, order_id, order_date FROM sales.orders ORDER BY cust_id, order_date DESC, order_id DESC produces the identical result set for this "latest per customer" case, typically with a simpler single-pass plan. */

/* Q55. */
WITH ranked AS (
  SELECT product_id, product_name, brand_id, price,
         ROW_NUMBER() OVER (PARTITION BY brand_id ORDER BY price DESC, product_id) AS rn
  FROM products.products
)
SELECT brand_id, product_id, product_name, price
FROM ranked
WHERE rn <= 3
ORDER BY brand_id, price DESC
LIMIT 300;

/* Q56. */
WITH ranked AS (
  SELECT supplier_id, supplier_name,
         ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(supplier_name)) ORDER BY supplier_id ASC) AS rn
  FROM products.suppliers
)
SELECT r.supplier_id AS canonical_supplier_id, r.supplier_name,
       ARRAY_AGG(s2.supplier_id ORDER BY s2.supplier_id) AS all_variant_ids
FROM ranked r
JOIN products.suppliers s2 ON LOWER(TRIM(s2.supplier_name)) = LOWER(TRIM(r.supplier_name))
WHERE r.rn = 1
GROUP BY r.supplier_id, r.supplier_name;

/* Q57. */
WITH ranked AS (
  SELECT review_id, customer_id, product_id, rating, review_date,
         ROW_NUMBER() OVER (PARTITION BY customer_id, product_id ORDER BY rating DESC, review_date DESC, review_id DESC) AS rn
  FROM customers.reviews
)
SELECT customer_id, product_id, review_id, rating, review_date
FROM ranked
WHERE rn = 1
LIMIT 200;

/* Q58. Global cap of 100 survivors overall: rank per group, then take the top 100 by that rank + a secondary global order. */
WITH product_units AS (
  SELECT p.product_id, p.brand_id, SUM(oi.quantity) AS units_sold
  FROM products.products p
  JOIN sales.order_items oi ON oi.prod_id = p.product_id
  GROUP BY p.product_id, p.brand_id
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY brand_id ORDER BY units_sold DESC, product_id) AS rn
  FROM product_units
)
SELECT product_id, brand_id, units_sold
FROM ranked
WHERE rn <= 3
ORDER BY units_sold DESC
LIMIT 100;

/* Q59. */
WITH email_groups AS (
  SELECT email, COUNT(*) AS cluster_size
  FROM customers.customers
  GROUP BY email
  HAVING COUNT(*) >= 2
)
SELECT email, cluster_size,
       RANK() OVER (ORDER BY cluster_size DESC) AS cluster_rank
FROM email_groups
ORDER BY cluster_rank
LIMIT 50;

/* Q60. */
WITH ranked AS (
  SELECT address_id, customer_id, is_default, address_line,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY is_default DESC, address_id ASC) AS rn,
         COUNT(*) OVER (PARTITION BY customer_id) AS address_count
  FROM customers.addresses
)
SELECT customer_id, address_id AS golden_address_id, is_default, address_count AS audit_total_addresses
FROM ranked
WHERE rn = 1
LIMIT 200;

/* Q61. */
WITH city_counts AS (
  SELECT a.city
  FROM customers.customers c
  JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = TRUE
  GROUP BY a.city
  HAVING COUNT(*) >= 100
),
city_spend AS (
  SELECT c.customer_id, a.city, COALESCE(SUM(o.net_total),0) AS spend
  FROM customers.customers c
  JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = TRUE
  JOIN city_counts cc ON cc.city = a.city
  LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
  GROUP BY c.customer_id, a.city
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY city ORDER BY spend DESC, customer_id) AS rn
  FROM city_spend
)
SELECT city, customer_id, spend
FROM ranked
WHERE rn <= 5
ORDER BY city, spend DESC
LIMIT 200;

/* Q62. */
WITH latest_snapshot AS (
  SELECT warehouse_id, product_id, quantity_on_hand,
         ROW_NUMBER() OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date DESC) AS rn
  FROM supply_chain.inventory_snapshots
)
SELECT warehouse_id, product_id, quantity_on_hand,
       RANK() OVER (PARTITION BY warehouse_id ORDER BY quantity_on_hand DESC) AS stock_rank
FROM latest_snapshot
WHERE rn = 1
ORDER BY warehouse_id, stock_rank
LIMIT 200;

/* Q63. */
WITH ranked AS (
  SELECT order_item_id, order_id, prod_id, net_amount,
         ROW_NUMBER() OVER (PARTITION BY order_id, prod_id ORDER BY net_amount DESC, order_item_id DESC) AS rn
  FROM sales.order_items
)
SELECT order_id, prod_id, order_item_id, net_amount
FROM ranked
WHERE rn = 1
LIMIT 200;

/* Q64. */
WITH ranked AS (
  SELECT order_id, cust_id, order_date, net_total,
         ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date ASC, order_id ASC) AS rn
  FROM sales.orders
)
SELECT cust_id, order_id AS first_touch_order_id, net_total,
       RANK() OVER (ORDER BY net_total DESC) AS customer_rank_by_first_order_value
FROM ranked
WHERE rn = 1
ORDER BY customer_rank_by_first_order_value
LIMIT 200;

/* Q65. */
WITH ranked AS (
  SELECT product_id, brand_id, price,
         RANK() OVER (PARTITION BY brand_id ORDER BY price DESC) AS price_rank
  FROM products.products
),
tie_counts AS (
  SELECT brand_id, COUNT(*) AS tied_at_rank3
  FROM ranked
  WHERE price_rank = 3
  GROUP BY brand_id
)
SELECT r.brand_id, r.product_id, r.price, r.price_rank, tc.tied_at_rank3
FROM ranked r
JOIN tie_counts tc ON tc.brand_id = r.brand_id
WHERE r.price_rank <= 3
ORDER BY r.brand_id, r.price_rank
LIMIT 200;

/* Q66. */
WITH ranked AS (
  SELECT payment_id, order_id, payment_date, amount,
         ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY payment_date DESC, payment_id DESC) AS rn,
         SUM(amount) OVER (PARTITION BY order_id) - amount AS other_payments_sum
  FROM sales.payments
)
SELECT order_id, payment_id AS kept_payment_id, payment_date, amount AS kept_amount,
       CASE WHEN rn = 1 THEN other_payments_sum ELSE 0 END AS summed_remaining_payments
FROM ranked
WHERE rn = 1
LIMIT 200;

/* Q67. */
WITH ranked AS (
  SELECT product_id, brand_id, product_name, price,
         ROW_NUMBER() OVER (PARTITION BY brand_id, product_name ORDER BY price DESC, product_id) AS rn,
         ROW_NUMBER() OVER (PARTITION BY brand_id, product_name ORDER BY product_id) AS dup_number
  FROM products.products
)
SELECT brand_id, product_name, product_id, price, dup_number
FROM ranked
WHERE rn = 1
ORDER BY brand_id, product_name
LIMIT 200;

/* Q68. */
WITH product_sold AS (
  SELECT prod_id, COUNT(*) AS sold_count FROM sales.order_items GROUP BY prod_id
),
product_returns AS (
  SELECT prod_id, COUNT(*) AS return_count FROM sales.returns GROUP BY prod_id
),
returned_products AS (
  SELECT cat.category_id, p.product_id, COALESCE(pr.return_count,0) AS return_count, COALESCE(ps.sold_count,0) AS sold_count
  FROM products.products p
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
  LEFT JOIN product_sold ps ON ps.prod_id = p.product_id
  LEFT JOIN product_returns pr ON pr.prod_id = p.product_id
),
ranked AS (
  SELECT *,
         (return_count::numeric / NULLIF(sold_count,0)) AS return_rate,
         ROW_NUMBER() OVER (PARTITION BY category_id ORDER BY return_count DESC, product_id) AS rn
  FROM returned_products
)
SELECT category_id, product_id, return_count, sold_count, ROUND(return_rate, 4) AS return_rate
FROM ranked
WHERE rn <= 3
ORDER BY category_id, return_count DESC;

/* Q69. */
SELECT c.customer_id, COUNT(DISTINCT c2.tier) AS distinct_tiers
FROM customers.customers c
JOIN customers.customers c2 ON c2.email = c.email
GROUP BY c.customer_id
HAVING COUNT(DISTINCT c2.tier) > 1
LIMIT 200;

/* Q70. */
WITH ranked AS (
  SELECT review_id, product_id, review_date, rating,
         ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY review_date DESC, review_id DESC) AS latest_rn,
         RANK() OVER (PARTITION BY product_id ORDER BY rating DESC) AS rating_position
  FROM customers.reviews
)
SELECT product_id, review_id, review_date, rating, rating_position
FROM ranked
WHERE latest_rn = 1
ORDER BY product_id
LIMIT 200;

/* Q71. */
WITH agent_metrics AS (
  SELECT agent_id, category, COUNT(*) AS resolved_count,
         AVG(resolved_date - created_date) AS avg_speed
  FROM support.tickets
  WHERE status = 'Resolved' AND agent_id IS NOT NULL
  GROUP BY agent_id, category
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY category ORDER BY resolved_count DESC, avg_speed ASC, agent_id) AS rn
  FROM agent_metrics
)
SELECT category, agent_id, resolved_count, avg_speed
FROM ranked
WHERE rn <= 3
ORDER BY category, rn;

/* Q72. */
WITH ranked AS (
  SELECT customer_id, email,
         ROW_NUMBER() OVER (PARTITION BY email ORDER BY registration_date DESC, customer_id DESC) AS rn
  FROM customers.customers
)
SELECT email, COUNT(*) AS total_in_partition,
       COUNT(*) FILTER (WHERE rn = 1) AS kept_count
FROM ranked
GROUP BY email
ORDER BY email
LIMIT 200;

/* Q73. */
WITH ranked AS (
  SELECT p.product_id, p.brand_id, c.tier, SUM(oi.quantity) AS units_sold,
         ROW_NUMBER() OVER (PARTITION BY p.brand_id, c.tier ORDER BY SUM(oi.quantity) DESC) AS rn
  FROM products.products p
  JOIN sales.order_items oi ON oi.prod_id = p.product_id
  JOIN sales.orders o ON o.order_id = oi.order_id
  JOIN customers.customers c ON c.customer_id = o.cust_id
  GROUP BY p.product_id, p.brand_id, c.tier
)
SELECT brand_id, tier, product_id, units_sold
FROM ranked
WHERE rn = 1
ORDER BY brand_id, tier
LIMIT 200;

/* Q74. */
WITH ranked AS (
  SELECT customer_id, phone, first_name, last_name, registration_date,
         ROW_NUMBER() OVER (PARTITION BY REGEXP_REPLACE(phone, '\D', '', 'g') ORDER BY registration_date DESC, customer_id DESC) AS rn
  FROM customers.customers
  WHERE phone IS NOT NULL
)
SELECT customer_id, phone, first_name, last_name, registration_date
FROM ranked
WHERE rn = 1
LIMIT 200;

/* Q75. */
WITH ranked AS (
  SELECT customer_id, email, registration_date,
         ROW_NUMBER() OVER (PARTITION BY email ORDER BY registration_date DESC, customer_id DESC) AS rn
  FROM customers.customers
),
merged AS (
  SELECT email, STRING_AGG(customer_id::text, ',' ORDER BY customer_id) AS merged_ids
  FROM customers.customers
  GROUP BY email
)
SELECT r.customer_id AS golden_id, r.email, r.registration_date, m.merged_ids
FROM ranked r
JOIN merged m ON m.email = r.email
WHERE r.rn = 1
ORDER BY r.customer_id
LIMIT 200;

/* ============================================================
   SECTION D: SEGMENTATION SYSTEMS (25)
   ------------------------------------------------------------ */
/* Q76. */
WITH cust_agg AS (
  SELECT cust_id AS customer_id,
         (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS recency_days,
         COUNT(*) AS order_count,
         SUM(net_total) AS total_spend
  FROM sales.orders
  GROUP BY cust_id
)
SELECT customer_id,
       NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,
       NTILE(5) OVER (ORDER BY order_count DESC) AS f_score,
       NTILE(5) OVER (ORDER BY total_spend DESC) AS m_score
FROM cust_agg
ORDER BY customer_id
LIMIT 200;

/* Q77. */
WITH cust_agg AS (
  SELECT cust_id AS customer_id,
         (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS recency_days,
         COUNT(*) AS order_count,
         SUM(net_total) AS total_spend
  FROM sales.orders
  GROUP BY cust_id
),
scored AS (
  SELECT customer_id,
         NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,
         NTILE(5) OVER (ORDER BY order_count DESC) AS f_score,
         NTILE(5) OVER (ORDER BY total_spend DESC) AS m_score
  FROM cust_agg
)
SELECT customer_id, r_score, f_score, m_score,
       CASE
         WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'Champions'
         WHEN f_score <= 2 AND m_score <= 3 THEN 'Loyal'
         WHEN r_score <= 3 THEN 'Potential'
         WHEN r_score >= 4 AND f_score >= 4 THEN 'Lost'
         ELSE 'At-Risk'
       END AS segment
FROM scored
ORDER BY customer_id
LIMIT 200;

/* Q78. */
WITH customer_spend AS (
  SELECT cust_id AS customer_id, SUM(net_total) AS total_spend
  FROM sales.orders
  GROUP BY cust_id
),
bucketed AS (
  SELECT customer_id, total_spend, NTILE(10) OVER (ORDER BY total_spend DESC) AS decile
  FROM customer_spend
),
totals AS (
  SELECT SUM(total_spend) AS grand_total FROM customer_spend
)
SELECT b.decile, SUM(b.total_spend) AS decile_revenue,
       ROUND(SUM(b.total_spend) / t.grand_total * 100, 2) AS pct_of_total_revenue
FROM bucketed b
CROSS JOIN totals t
GROUP BY b.decile, t.grand_total
ORDER BY b.decile;

/* Q79. */
WITH cust_agg AS (
  SELECT cust_id AS customer_id, COUNT(*) AS order_count, SUM(net_total) AS total_spend
  FROM sales.orders
  GROUP BY cust_id
),
scored AS (
  SELECT customer_id,
         NTILE(4) OVER (ORDER BY total_spend DESC) AS spend_quartile,
         NTILE(4) OVER (ORDER BY order_count DESC) AS freq_quartile
  FROM cust_agg
)
SELECT spend_quartile, freq_quartile, COUNT(*) AS cell_count
FROM scored
GROUP BY spend_quartile, freq_quartile
ORDER BY spend_quartile, freq_quartile;

/* Q80. */
WITH product_revenue AS (
  SELECT p.product_id, cat.category_id, SUM(oi.net_amount) AS revenue
  FROM products.products p
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
  JOIN sales.order_items oi ON oi.prod_id = p.product_id
  GROUP BY p.product_id, cat.category_id
)
SELECT category_id, product_id, revenue,
       NTILE(3) OVER (PARTITION BY category_id ORDER BY revenue DESC) AS abc_class,
       CASE NTILE(3) OVER (PARTITION BY category_id ORDER BY revenue DESC)
         WHEN 1 THEN 'A' WHEN 2 THEN 'B' ELSE 'C' END AS abc_label
FROM product_revenue
ORDER BY category_id, abc_class
LIMIT 200;

/* Q81. */
WITH store_revenue AS (
  SELECT s.store_id, s.region_id, SUM(o.net_total) AS revenue
  FROM stores.stores s
  JOIN sales.orders o ON o.store_id = s.store_id
  GROUP BY s.store_id, s.region_id
),
bucketed AS (
  SELECT store_id, region_id, revenue,
         NTILE(4) OVER (PARTITION BY region_id ORDER BY revenue DESC) AS quartile
  FROM store_revenue
)
SELECT region_id, quartile, COUNT(*) AS store_count, AVG(revenue) AS avg_revenue
FROM bucketed
GROUP BY region_id, quartile
ORDER BY region_id, quartile;

/* Q82. */
WITH customer_spend AS (
  SELECT cust_id AS customer_id, SUM(net_total) AS total_spend
  FROM sales.orders
  GROUP BY cust_id
),
bucketed AS (
  SELECT customer_id, total_spend, NTILE(100) OVER (ORDER BY total_spend) AS percentile_bucket
  FROM customer_spend
)
SELECT customer_id, total_spend, percentile_bucket,
       (percentile_bucket >= 95) AS is_p95_or_above
FROM bucketed
WHERE percentile_bucket >= 95
ORDER BY total_spend DESC
LIMIT 200;

/* Q83. */
WITH cust_agg AS (
  SELECT cust_id AS customer_id, COUNT(*) AS order_count, SUM(net_total) AS total_spend,
         (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS recency_days
  FROM sales.orders
  GROUP BY cust_id
)
SELECT customer_id, order_count, total_spend, recency_days,
       CASE WHEN order_count = 1 THEN NULL ELSE NTILE(5) OVER (ORDER BY order_count DESC) END AS f_score,
       NTILE(5) OVER (ORDER BY total_spend DESC) AS m_score,
       NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score
FROM cust_agg
ORDER BY customer_id
LIMIT 200;

/* Q84. */
WITH cust_agg AS (
  SELECT cust_id AS customer_id, COUNT(*) AS order_count, SUM(net_total) AS total_spend
  FROM sales.orders
  GROUP BY cust_id
),
scored AS (
  SELECT customer_id,
         NTILE(10) OVER (ORDER BY order_count DESC) AS freq_decile,
         NTILE(10) OVER (ORDER BY total_spend DESC) AS spend_decile
  FROM cust_agg
)
SELECT customer_id
FROM scored
WHERE freq_decile = 1 AND spend_decile = 1
LIMIT 200;

/* Q85. */
WITH delivery AS (
  SELECT courier_name, (delivered_date - shipped_date) AS days
  FROM sales.shipments
  WHERE delivered_date IS NOT NULL
)
SELECT courier_name, days,
       NTILE(4) OVER (PARTITION BY courier_name ORDER BY days DESC) AS delay_quartile,
       (NTILE(4) OVER (PARTITION BY courier_name ORDER BY days DESC) = 1) AS sla_risk
FROM delivery
ORDER BY courier_name, delay_quartile
LIMIT 200;

/* Q86. */
WITH dept_quartile AS (
  SELECT employee_id, dept_id, salary,
         NTILE(4) OVER (PARTITION BY dept_id ORDER BY salary DESC) AS dept_quartile
  FROM stores.employees
),
company_quartile AS (
  SELECT employee_id, NTILE(4) OVER (ORDER BY salary DESC) AS company_quartile
  FROM stores.employees
)
SELECT d.employee_id, d.dept_id, d.salary, d.dept_quartile, c.company_quartile,
       (d.dept_quartile = 1 AND c.company_quartile > 1) AS underpaid_top_performer_flag
FROM dept_quartile d
JOIN company_quartile c ON c.employee_id = d.employee_id
WHERE d.dept_quartile = 1 AND c.company_quartile > 1
ORDER BY d.dept_id;

/* Q87. */
WITH product_units AS (
  SELECT p.product_id, p.brand_id, SUM(oi.quantity) AS units_sold
  FROM products.products p
  JOIN sales.order_items oi ON oi.prod_id = p.product_id
  GROUP BY p.product_id, p.brand_id
)
SELECT product_id, brand_id, units_sold,
       NTILE(3) OVER (PARTITION BY brand_id ORDER BY units_sold) AS mover_tier,
       CASE NTILE(3) OVER (PARTITION BY brand_id ORDER BY units_sold)
         WHEN 1 THEN 'Slow' WHEN 2 THEN 'Medium' ELSE 'Fast' END AS mover_label
FROM product_units
ORDER BY brand_id, mover_tier
LIMIT 200;

/* Q88. */
WITH campaign_spend AS (
  SELECT campaign_id, platform, SUM(amount) AS spend
  FROM marketing.ads_spend
  GROUP BY campaign_id, platform
)
SELECT platform, campaign_id, spend,
       NTILE(4) OVER (PARTITION BY platform ORDER BY spend DESC) AS spend_quartile,
       (NTILE(4) OVER (PARTITION BY platform ORDER BY spend DESC) = 1) AS roi_watch
FROM campaign_spend
ORDER BY platform, spend_quartile;

/* Q89. */
WITH cust_engagement AS (
  SELECT c.customer_id,
         COALESCE((SELECT COUNT(*) FROM customers.reviews r WHERE r.customer_id = c.customer_id), 0) AS review_count,
         COALESCE((SELECT COUNT(*) FROM support.tickets t WHERE t.customer_id = c.customer_id), 0) AS ticket_count,
         COALESCE((SELECT COUNT(*) FROM sales.orders o WHERE o.cust_id = c.customer_id), 0) AS order_count
  FROM customers.customers c
  WHERE c.customer_id <= 3000
)
SELECT customer_id, (review_count + ticket_count + order_count) AS engagement_composite,
       NTILE(4) OVER (ORDER BY (review_count + ticket_count + order_count) DESC) AS engagement_quartile
FROM cust_engagement
ORDER BY engagement_composite DESC
LIMIT 200;

/* Q90. */
WITH region_revenue AS (
  SELECT s.region_id, SUM(o.net_total) AS revenue
  FROM stores.stores s
  JOIN sales.orders o ON o.store_id = s.store_id
  GROUP BY s.region_id
)
SELECT region_id, revenue,
       RANK() OVER (ORDER BY revenue DESC) AS region_rank,
       NTILE(4) OVER (ORDER BY revenue DESC) AS revenue_quartile
FROM region_revenue
ORDER BY region_rank;

/* Q91. */
WITH customer_spend AS (
  SELECT cust_id AS customer_id, SUM(net_total) AS total_spend
  FROM sales.orders
  GROUP BY cust_id
),
bucketed AS (
  SELECT customer_id, total_spend, NTILE(4) OVER (ORDER BY total_spend DESC) AS spend_quartile
  FROM customer_spend
)
SELECT spend_quartile, MIN(total_spend) AS quartile_floor, MAX(total_spend) AS quartile_ceiling, COUNT(*) AS customer_count
FROM bucketed
GROUP BY spend_quartile
ORDER BY spend_quartile;

/* Q92. */
WITH customer_spend AS (
  SELECT c.customer_id, a.city, COALESCE(SUM(o.net_total),0) AS total_spend
  FROM customers.customers c
  JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = TRUE
  LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
  GROUP BY c.customer_id, a.city
),
bucketed AS (
  SELECT city, customer_id, NTILE(4) OVER (ORDER BY total_spend DESC) AS spend_quartile
  FROM customer_spend
),
city_mode AS (
  SELECT city, spend_quartile, COUNT(*) AS cnt,
         ROW_NUMBER() OVER (PARTITION BY city ORDER BY COUNT(*) DESC) AS rn
  FROM bucketed
  GROUP BY city, spend_quartile
)
SELECT city, spend_quartile AS dominant_quartile, cnt
FROM city_mode
WHERE rn = 1
ORDER BY city
LIMIT 100;

/* Q93. */
WITH customer_spend AS (
  SELECT cust_id AS customer_id, SUM(net_total) AS total_spend
  FROM sales.orders
  GROUP BY cust_id
)
SELECT customer_id, total_spend,
       NTILE(10) OVER (ORDER BY total_spend DESC) AS spend_decile
FROM customer_spend
ORDER BY customer_id
LIMIT 200;

/* Q94. */
WITH cust_agg AS (
  SELECT cust_id AS customer_id, COUNT(*) AS order_count, SUM(net_total) AS total_spend
  FROM sales.orders
  GROUP BY cust_id
),
scored AS (
  SELECT customer_id,
         NTILE(4) OVER (ORDER BY order_count DESC) AS freq_quartile,
         NTILE(4) OVER (ORDER BY total_spend DESC) AS spend_quartile
  FROM cust_agg
)
SELECT customer_id, freq_quartile, spend_quartile
FROM scored
WHERE freq_quartile = 1 AND spend_quartile BETWEEN 2 AND 3
ORDER BY customer_id
LIMIT 200;

/* Q95. */
SELECT product_id, brand_id, price,
       NTILE(5) OVER (PARTITION BY brand_id ORDER BY price) AS price_band,
       CASE NTILE(5) OVER (PARTITION BY brand_id ORDER BY price)
         WHEN 1 THEN 'Budget' WHEN 2 THEN 'Value' WHEN 3 THEN 'Mid' WHEN 4 THEN 'Premium' ELSE 'Luxury' END AS band_label
FROM products.products
ORDER BY brand_id, price_band
LIMIT 200;

/* Q96. */
WITH wh_totals AS (
  SELECT warehouse_id, SUM(quantity_on_hand) AS total_qty
  FROM supply_chain.inventory_snapshots
  GROUP BY warehouse_id
)
SELECT warehouse_id, total_qty,
       NTILE(5) OVER (ORDER BY total_qty) AS stock_quintile,
       (NTILE(5) OVER (ORDER BY total_qty) = 1) AS flagged_for_replenishment
FROM wh_totals
ORDER BY stock_quintile, total_qty;

/* Q97. */
WITH customer_spend AS (
  SELECT cust_id AS customer_id, SUM(net_total) AS total_spend
  FROM sales.orders
  GROUP BY cust_id
),
scored AS (
  SELECT cs.customer_id, cs.total_spend, c.tier,
         NTILE(4) OVER (ORDER BY cs.total_spend DESC) AS spend_quartile
  FROM customer_spend cs
  JOIN customers.customers c ON c.customer_id = cs.customer_id
)
SELECT customer_id, tier, total_spend, spend_quartile
FROM scored
WHERE tier = 'Gold' AND spend_quartile = 4
ORDER BY total_spend
LIMIT 200;

/* Q98. */
WITH store_revenue AS (
  SELECT s.store_id, s.region_id, SUM(o.net_total) AS revenue
  FROM stores.stores s
  JOIN sales.orders o ON o.store_id = s.store_id
  GROUP BY s.store_id, s.region_id
),
ranked AS (
  SELECT *, RANK() OVER (PARTITION BY region_id ORDER BY revenue DESC) AS rnk
  FROM store_revenue
),
top2 AS (
  SELECT region_id,
         MAX(revenue) FILTER (WHERE rnk = 1) AS leader_value,
         MAX(revenue) FILTER (WHERE rnk = 2) AS runner_up_value
  FROM ranked
  WHERE rnk <= 2
  GROUP BY region_id
)
SELECT r.region_id, r.store_id, r.revenue, r.rnk,
       ROUND(t.leader_value / NULLIF(t.runner_up_value, 0), 2) AS dominance_ratio
FROM ranked r
JOIN top2 t ON t.region_id = r.region_id
WHERE r.rnk <= 3
ORDER BY r.region_id, r.rnk;

/* Q99. */
WITH cust_agg AS (
  SELECT cust_id AS customer_id,
         (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS recency_days,
         COUNT(*) AS order_count,
         SUM(net_total) AS total_spend
  FROM sales.orders
  GROUP BY cust_id
),
scored AS (
  SELECT customer_id, total_spend,
         NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,
         NTILE(5) OVER (ORDER BY order_count DESC) AS f_score,
         NTILE(5) OVER (ORDER BY total_spend DESC) AS m_score
  FROM cust_agg
),
segmented AS (
  SELECT customer_id, total_spend,
         CASE
           WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'Champions'
           WHEN f_score <= 2 AND m_score <= 3 THEN 'Loyal'
           WHEN r_score >= 4 AND f_score >= 4 THEN 'Lost'
           WHEN r_score >= 3 THEN 'At-Risk'
           ELSE 'Potential'
         END AS segment
  FROM scored
)
SELECT segment, COUNT(*) AS segment_size, ROUND(AVG(total_spend), 2) AS avg_monetary
FROM segmented
GROUP BY segment
ORDER BY segment_size DESC;

/* Q100. */
WITH cust_agg AS (
  SELECT cust_id AS customer_id,
         (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS recency_days,
         COUNT(*) AS order_count,
         SUM(net_total) AS total_spend
  FROM sales.orders
  GROUP BY cust_id
),
scored AS (
  SELECT customer_id,
         NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,
         NTILE(5) OVER (ORDER BY order_count DESC) AS f_score,
         NTILE(5) OVER (ORDER BY total_spend DESC) AS m_score,
         total_spend
  FROM cust_agg
),
segmented AS (
  SELECT customer_id, r_score, f_score, m_score, total_spend,
         CASE
           WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'Champions'
           WHEN f_score <= 2 AND m_score <= 3 THEN 'Loyal'
           WHEN r_score >= 4 AND f_score >= 4 THEN 'Lost'
           WHEN r_score >= 3 THEN 'At-Risk'
           ELSE 'Potential'
         END AS segment
  FROM scored
)
SELECT segment, customer_id, total_spend,
       ROW_NUMBER() OVER (PARTITION BY segment ORDER BY total_spend DESC) AS rank_within_segment
FROM segmented
ORDER BY segment, rank_within_segment
LIMIT 200;

/* ============================================================
   END OF ANSWER KEY - Window Functions Part 1 - CRAZY LEVEL (100/100)
============================================================ */
