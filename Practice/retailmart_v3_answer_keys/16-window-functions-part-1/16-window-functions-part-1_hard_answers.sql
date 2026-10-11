/* ============================================================
   ANSWER KEY - Window Functions Part 1: Ranking & Bucketing (HARD LEVEL)
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
/* Q1.  RANK() <= N includes every row tied for the Nth position, so it can return MORE than N rows whenever a tie straddles the boundary; ROW_NUMBER() <= N always returns exactly N rows, silently picking one tied row as "the last one in" and dropping the rest. */
/* Q2.  ROW_NUMBER() assigns a unique, gapless integer to every row regardless of ties, so filtering <= N mathematically can never keep more than N rows; RANK() intentionally repeats a rank across ties, so the count of rows with rank <= N grows by the tie-group size whenever a tie occurs at or before N. */
/* Q3.  Rank each customer's orders with ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date DESC, order_id DESC) - the order_id tie-break guarantees exactly one row is picked as "latest" even when two orders share the same order_date. */
/* Q4.  WHERE filters rows before any window function is evaluated (so a window alias isn't available there yet); window functions then run over the WHERE/GROUP BY/HAVING-filtered rows; only after that does the outer ORDER BY/LIMIT apply to the window functions' own output - each stage's result feeds the next. */
/* Q5.  Because a window function's result isn't computed until after WHERE (and GROUP BY/HAVING) have already run, so there's no column to reference yet inside that same clause - wrapping the ranked SELECT in a CTE/subquery materializes the rank as a plain output column the outer query's WHERE can then filter on normally. */
/* Q6.  In a CTE like SELECT *, ROW_NUMBER() OVER (PARTITION BY key ORDER BY tiebreak DESC) AS rn, changing the ORDER BY direction changes which specific row lands at rn=1 for each key - filtering WHERE rn=1 afterward proves the surviving row is exactly whichever one the ORDER BY placed first. */
/* Q7.  NTILE gives a simple row-COUNT-based bucket number (fast, easy to reason about, but coarse - ties can split oddly); PERCENT_RANK gives each row's relative standing as (rank-1)/(rows-1), continuous and comparable across differently-sized groups; CUME_DIST gives the fraction of rows <= the current row (inclusive), useful for "top X%" cutoffs - for RFM bucketing NTILE(5) is the standard choice since it guarantees exactly 5 evenly-sized quintiles per metric. */
/* Q8.  When N doesn't divide the group size evenly, NTILE assigns the extra rows to the LOWEST-numbered buckets first, so early buckets can have one more row than later ones. */
/* Q9.  Ranking the whole table then filtering forces a single full sort/window pass over every row before discarding most of them; a LATERAL top-N re-runs a small ORDER BY ... LIMIT N per outer row, which - especially with a supporting index on the correlated column - can be far cheaper than sorting the entire fact table once for a rank that's mostly thrown away. */
/* Q10. When two or more rows share identical values in every ORDER BY expression (no fully-unique key in the ORDER BY), ROW_NUMBER still must assign distinct numbers to them - which one gets which number is left to the query plan's internal row order, so the exact numbering can differ across runs/plans, hence "arbitrary". */
/* Q11. Compute both RANK() OVER (PARTITION BY group_col ORDER BY metric DESC) AS rank_in_group and RANK() OVER (ORDER BY metric DESC) AS rank_overall in the same SELECT - each OVER clause is independent, so one query yields both perspectives per row. */
/* Q12. SELECT DISTINCT is applied to the final row set AFTER window functions compute (including their per-row rank values), so if the window function makes every row's output unique (e.g. via ROW_NUMBER), DISTINCT does nothing useful; conversely, forgetting this and applying DISTINCT before intending to dedupe by the window value is a common source of unexpectedly all-rows-kept results. */
/* Q13. Rank with RANK() (not ROW_NUMBER) so ties share the top-N position, then in the outer query also compute COUNT(*) FILTER (WHERE rnk = N) OVER (PARTITION BY group_col) or a separate aggregate to report how many rows tied for the boundary rank. */
/* Q14. DATE_TRUNC('month', d) collapses every timestamp in the same calendar month to one identical value, so PARTITION BY that expression groups rows by month directly without needing a separate month column - it's a computed grouping key evaluated per row. */
/* Q15. DENSE_RANK() = 2 selects every row whose value is the SECOND-DISTINCT value in the ordering (regardless of how many rows tie for 1st or 2nd) - "exactly the 2nd highest" with proper tie handling means the true 2nd-place VALUE, not the 2nd physical row. */
/* Q16. DISTINCT ON (partition_cols) ORDER BY partition_cols, tiebreak_col DESC LIMIT-per-group-of-1 is a simpler, often faster Postgres-specific alternative to ROW_NUMBER()=1 specifically when you want exactly ONE row per group - it skips computing a rank number, going straight to "keep the first row in this sort order per group". */
/* Q17. NULLS FIRST puts NULL values in the ordering's earliest positions, so with an ascending ORDER BY, a row with NULL in the ranking column becomes rank 1; NULLS LAST pushes NULLs to the end, so rank 1 goes to the smallest non-NULL value instead - the choice directly decides whether NULL rows "win" the top rank. */
/* Q18. If the ORDER BY column used to pick "the survivor" isn't unique per group, multiple rows can tie for the position you're keeping, and which one Postgres actually assigns rn=1 among the tied rows is arbitrary - so the "kept" row (e.g. a customer's name/email combination) may not be the one you intended without an additional tie-breaker. */
/* Q19. Compute quartile boundaries with a fixed reference query (e.g. percentile values captured as of a snapshot date) and store them as static thresholds, or snapshot the NTILE assignment itself into a table - re-running NTILE fresh each time means membership shifts as new rows arrive, which breaks period-over-period comparisons. */
/* Q20. NTILE(100) OVER (ORDER BY value) gives each row a 1-100 bucket by ROW COUNT position, an approximation of percentile rank; its limitation is that with fewer than 100 rows in the partition, several bucket numbers are simply skipped, and ties near a bucket boundary can land in adjacent buckets somewhat arbitrarily - true percentile functions like PERCENT_RANK give a continuous, exact relative position instead. */
/* Q21. A RANK() over a huge, unpartitioned (or coarsely-partitioned) window forces Postgres to sort the entire input set at least once; without a supporting index on the ORDER BY column(s), that sort happens from scratch every execution (an external/on-disk sort for large data), which is exactly the class of cost an index on that column can eliminate by delivering pre-sorted input. */
/* Q22. Compute the composite score as a plain expression in the SELECT list (or a CTE), then reference that same expression inside RANK() OVER (ORDER BY composite_score DESC) - Postgres evaluates the expression once per row for the window function just like any other ORDER BY target. */
/* Q23. Nest two levels of ranking: rank stores within region in an inner CTE, filter to the top-N stores per region, then within THAT result rank/join to products for a second top-N per store - each level's filtered survivors become the driving set for the next level's window function. */
/* Q24. Emails are a natural, meaningful business key that legitimately should be unique but often isn't due to data-entry duplication, registration retries, or merges - "keep the most recent registration per email" combines a realistic dedup-key choice with the classic ROW_NUMBER()=1 pattern, making it a natural interview test of both concepts together. */
/* Q25. NTILE(10) OVER (ORDER BY spend DESC) puts the highest 10% of spend in bucket 1 - filtering WHERE bucket = 1 in an outer query directly gives "everyone in the top decile of spend" without needing to separately compute or hardcode a percentile cutoff value. */

/* ============================================================
   SECTION B: TOP-N / NTH PER GROUP (25)
   ------------------------------------------------------------ */
/* Q26. */
WITH ranked AS (
  SELECT employee_id, dept_id, first_name, last_name, salary,
         ROW_NUMBER() OVER (PARTITION BY dept_id ORDER BY salary DESC, employee_id) AS rn
  FROM stores.employees
)
SELECT dept_id, employee_id, first_name, last_name, salary
FROM ranked
WHERE rn <= 3
ORDER BY dept_id, salary DESC;

/* Q27. */
WITH product_revenue AS (
  SELECT p.product_id, p.product_name, p.brand_id, SUM(oi.quantity) * p.price AS revenue
  FROM products.products p
  JOIN sales.order_items oi ON oi.prod_id = p.product_id
  GROUP BY p.product_id, p.product_name, p.brand_id, p.price
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY brand_id ORDER BY revenue DESC, product_id) AS rn
  FROM product_revenue
)
SELECT brand_id, product_id, product_name, revenue
FROM ranked
WHERE rn <= 3
ORDER BY brand_id, revenue DESC;

/* Q28. */
WITH ranked AS (
  SELECT employee_id, store_id, first_name, last_name, salary,
         DENSE_RANK() OVER (PARTITION BY store_id ORDER BY salary DESC) AS drnk
  FROM stores.employees
)
SELECT store_id, employee_id, first_name, last_name, salary
FROM ranked
WHERE drnk = 2
ORDER BY store_id;

/* Q29. */
WITH customer_spend AS (
  SELECT c.customer_id, s.region_id, COALESCE(SUM(o.net_total),0) AS lifetime_spend
  FROM customers.customers c
  JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = TRUE
  JOIN stores.stores s ON s.city = a.city
  LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
  GROUP BY c.customer_id, s.region_id
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY region_id ORDER BY lifetime_spend DESC, customer_id) AS rn
  FROM customer_spend
)
SELECT region_id, customer_id, lifetime_spend
FROM ranked
WHERE rn <= 5
ORDER BY region_id, lifetime_spend DESC;

/* Q30. */
WITH ranked AS (
  SELECT o.*, ROW_NUMBER() OVER (PARTITION BY o.cust_id ORDER BY sh.delivered_date DESC NULLS LAST, o.order_id DESC) AS rn
  FROM sales.orders o
  JOIN sales.shipments sh ON sh.order_id = o.order_id
  WHERE sh.status = 'Delivered'
)
SELECT order_id, cust_id, store_id, order_date, order_status, net_total
FROM ranked
WHERE rn = 1
ORDER BY cust_id
LIMIT 200;

/* Q31. */
WITH returned_products AS (
  SELECT cat.category_id, p.product_id, COUNT(*) AS return_count
  FROM sales.returns r
  JOIN products.products p ON p.product_id = r.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
  GROUP BY cat.category_id, p.product_id
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY category_id ORDER BY return_count DESC, product_id) AS rn
  FROM returned_products
)
SELECT category_id, product_id, return_count
FROM ranked
WHERE rn <= 3
ORDER BY category_id, return_count DESC;

/* Q32. */
WITH ranked AS (
  SELECT product_id, product_name, supplier_id, (price - cost_price) AS margin,
         ROW_NUMBER() OVER (PARTITION BY supplier_id ORDER BY (price - cost_price) DESC, product_id) AS rn
  FROM products.products
)
SELECT supplier_id, product_id, product_name, margin
FROM ranked
WHERE rn = 1
ORDER BY supplier_id;

/* Q33. */
WITH agent_resolved AS (
  SELECT agent_id, category, COUNT(*) AS resolved_count
  FROM support.tickets
  WHERE status = 'Resolved' AND agent_id IS NOT NULL
  GROUP BY agent_id, category
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY category ORDER BY resolved_count DESC, agent_id) AS rn
  FROM agent_resolved
)
SELECT category, agent_id, resolved_count
FROM ranked
WHERE rn <= 3
ORDER BY category, resolved_count DESC;

/* Q34. */
WITH ranked AS (
  SELECT order_id, cust_id, order_date,
         ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date ASC, order_id ASC) AS rn
  FROM sales.orders
)
SELECT cust_id, order_id, order_date
FROM ranked
WHERE rn = 3
ORDER BY cust_id
LIMIT 200;

/* Q35. */
WITH store_revenue AS (
  SELECT s.store_id, s.region_id, SUM(o.net_total) AS revenue
  FROM stores.stores s
  JOIN sales.orders o ON o.store_id = s.store_id
  GROUP BY s.store_id, s.region_id
),
region_totals AS (
  SELECT region_id, SUM(revenue) AS region_total
  FROM store_revenue
  GROUP BY region_id
),
ranked AS (
  SELECT sr.*, ROW_NUMBER() OVER (PARTITION BY sr.region_id ORDER BY sr.revenue DESC) AS rn
  FROM store_revenue sr
)
SELECT r.region_id, r.store_id, r.revenue, rt.region_total
FROM ranked r
JOIN region_totals rt ON rt.region_id = r.region_id
WHERE r.rn <= 2
ORDER BY r.region_id, r.revenue DESC;

/* Q36. */
WITH ranked AS (
  SELECT product_id, product_name, brand_id, price,
         RANK() OVER (PARTITION BY brand_id ORDER BY price DESC) AS price_rank
  FROM products.products
)
SELECT brand_id, product_id, product_name, price
FROM ranked
WHERE price_rank = 1
ORDER BY brand_id
LIMIT 200;

/* Q37. */
WITH ranked AS (
  SELECT review_id, product_id, review_text, rating, review_date,
         ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY review_date DESC, review_id DESC) AS rn
  FROM customers.reviews
  WHERE rating <= 2
)
SELECT product_id, review_id, review_text, rating, review_date
FROM ranked
WHERE rn = 1
ORDER BY product_id
LIMIT 200;

/* Q38. */
WITH ranked AS (
  SELECT order_id, payment_mode_id, net_total,
         ROW_NUMBER() OVER (PARTITION BY payment_mode_id ORDER BY net_total DESC, order_id) AS rn
  FROM sales.orders
)
SELECT payment_mode_id, order_id, net_total
FROM ranked
WHERE rn <= 3
ORDER BY payment_mode_id, net_total DESC;

/* Q39. */
SELECT order_id, cust_id, order_date,
       ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date ASC, order_id ASC) AS earliest_rn,
       ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date DESC, order_id DESC) AS latest_rn
FROM sales.orders
ORDER BY cust_id
LIMIT 200;

/* Q40. */
WITH ranked AS (
  SELECT c.call_id, c.agent_id, c.customer_id, c.call_duration_seconds,
         ROW_NUMBER() OVER (PARTITION BY c.agent_id ORDER BY c.call_duration_seconds DESC, c.call_id) AS rn
  FROM call_center.calls c
)
SELECT r.agent_id, r.call_id, r.call_duration_seconds, cu.first_name, cu.last_name
FROM ranked r
JOIN customers.customers cu ON cu.customer_id = r.customer_id
WHERE r.rn <= 5
ORDER BY r.agent_id, r.call_duration_seconds DESC
LIMIT 200;

/* Q41. */
WITH product_units_cohort AS (
  SELECT p.brand_id, p.product_id, EXTRACT(YEAR FROM c.registration_date) AS buyer_reg_year, SUM(oi.quantity) AS units
  FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  JOIN customers.customers c ON c.customer_id = o.cust_id
  JOIN products.products p ON p.product_id = oi.prod_id
  GROUP BY p.brand_id, p.product_id, EXTRACT(YEAR FROM c.registration_date)
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY brand_id, buyer_reg_year ORDER BY units DESC, product_id) AS rn
  FROM product_units_cohort
)
SELECT brand_id, buyer_reg_year, product_id, units
FROM ranked
WHERE rn = 1
ORDER BY brand_id, buyer_reg_year
LIMIT 200;

/* Q42. */
WITH cohort_orders AS (
  SELECT c.customer_id, DATE_TRUNC('month', c.registration_date) AS cohort_month, COUNT(o.order_id) AS order_count
  FROM customers.customers c
  LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
  WHERE c.customer_id <= 5000
  GROUP BY c.customer_id, DATE_TRUNC('month', c.registration_date)
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY cohort_month ORDER BY order_count DESC, customer_id) AS rn
  FROM cohort_orders
)
SELECT cohort_month, customer_id, order_count
FROM ranked
WHERE rn <= 3
ORDER BY cohort_month, order_count DESC
LIMIT 200;

/* Q43. Restricted to a warehouse sample since inventory_snapshots has no supporting index for a per-warehouse latest-price lookup on this practice database. */
WITH latest_stock AS (
  SELECT isn.warehouse_id, isn.product_id, isn.quantity_on_hand,
         ROW_NUMBER() OVER (PARTITION BY isn.warehouse_id ORDER BY isn.snapshot_date DESC) AS snap_rn
  FROM supply_chain.inventory_snapshots isn
  WHERE isn.warehouse_id <= 20
),
in_stock AS (
  SELECT ls.warehouse_id, ls.product_id, p.price
  FROM latest_stock ls
  JOIN products.products p ON p.product_id = ls.product_id
  WHERE ls.snap_rn = 1 AND ls.quantity_on_hand > 0
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY warehouse_id ORDER BY price ASC, product_id) AS rn
  FROM in_stock
)
SELECT warehouse_id, product_id, price
FROM ranked
WHERE rn = 1
ORDER BY warehouse_id;

/* Q44. */
WITH campaign_spend AS (
  SELECT c.campaign_id, a.platform, SUM(a.amount) AS total_spend
  FROM marketing.campaigns c
  JOIN marketing.ads_spend a ON a.campaign_id = c.campaign_id
  GROUP BY c.campaign_id, a.platform
),
ranked AS (
  SELECT *, RANK() OVER (PARTITION BY platform ORDER BY total_spend DESC) AS spend_rank
  FROM campaign_spend
)
SELECT platform, campaign_id, total_spend, spend_rank
FROM ranked
WHERE spend_rank <= 3
ORDER BY platform, spend_rank;

/* Q45. Nth is parameterized here as N=4. */
WITH product_cat AS (
  SELECT p.product_id, p.price, cat.category_id
  FROM products.products p
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
),
ranked AS (
  SELECT *, DENSE_RANK() OVER (PARTITION BY category_id ORDER BY price DESC) AS drnk
  FROM product_cat
)
SELECT category_id, product_id, price
FROM ranked
WHERE drnk = 4
ORDER BY category_id
LIMIT 200;

/* Q46. */
WITH ranked AS (
  SELECT employee_id, store_id, role, salary, joining_date,
         ROW_NUMBER() OVER (PARTITION BY store_id, role ORDER BY salary DESC, joining_date ASC) AS rn
  FROM stores.employees
)
SELECT store_id, role, employee_id, salary, joining_date
FROM ranked
WHERE rn <= 2
ORDER BY store_id, role, salary DESC;

/* Q47. */
WITH ranked AS (
  SELECT p.payment_id, p.order_id, p.payment_date, o.order_status,
         ROW_NUMBER() OVER (PARTITION BY p.order_id ORDER BY p.payment_date DESC, p.payment_id DESC) AS rn
  FROM sales.payments p
  JOIN sales.orders o ON o.order_id = p.order_id
  WHERE o.order_status = 'Delivered'
)
SELECT order_id, payment_id, payment_date
FROM ranked
WHERE rn = 1
ORDER BY order_id
LIMIT 200;

/* Q48. */
WITH region_avg AS (
  SELECT s.region_id, AVG(o.net_total) AS avg_order_value
  FROM stores.stores s
  JOIN sales.orders o ON o.store_id = s.store_id
  GROUP BY s.region_id
),
ranked AS (
  SELECT *, RANK() OVER (ORDER BY avg_order_value DESC) AS region_rank
  FROM region_avg
)
SELECT region_id, avg_order_value, region_rank
FROM ranked
WHERE region_rank <= 3
ORDER BY region_rank;

/* Q49. */
WITH ranked AS (
  SELECT review_id, product_id, rating, review_date,
         ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY rating DESC, review_date DESC, review_id DESC) AS rn
  FROM customers.reviews
)
SELECT product_id, review_id, rating, review_date
FROM ranked
WHERE rn = 1
ORDER BY product_id
LIMIT 200;

/* Q50. */
WITH per_group_top AS (
  SELECT employee_id, dept_id, salary,
         ROW_NUMBER() OVER (PARTITION BY dept_id ORDER BY salary DESC, employee_id) AS rn_in_group
  FROM stores.employees
)
SELECT employee_id, dept_id, salary,
       ROW_NUMBER() OVER (ORDER BY salary DESC, employee_id) AS overall_rn
FROM per_group_top
WHERE rn_in_group <= 3
ORDER BY overall_rn
LIMIT 100;

/* ============================================================
   SECTION C: DEDUPLICATION & IDENTITY (25)
   ------------------------------------------------------------ */
/* Q51. */
WITH ranked AS (
  SELECT customer_id, email, registration_date,
         ROW_NUMBER() OVER (PARTITION BY email ORDER BY registration_date DESC, customer_id DESC) AS rn
  FROM customers.customers
)
SELECT customer_id, email, registration_date
FROM ranked
WHERE rn = 1
LIMIT 200;

/* Q52. */
WITH ranked AS (
  SELECT customer_id, email, registration_date,
         ROW_NUMBER() OVER (PARTITION BY email ORDER BY registration_date DESC, customer_id DESC) AS rn
  FROM customers.customers
)
SELECT customer_id, email, registration_date
FROM ranked
WHERE rn > 1
LIMIT 200;

/* Q53. */
WITH ranked AS (
  SELECT product_id, product_name, price,
         ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(product_name)) ORDER BY price ASC, product_id ASC) AS rn
  FROM products.products
)
SELECT product_id, product_name, price
FROM ranked
WHERE rn = 1
LIMIT 200;

/* Q54. */
WITH ranked AS (
  SELECT order_id, cust_id, order_date, net_total,
         ROW_NUMBER() OVER (PARTITION BY cust_id, order_date ORDER BY net_total DESC, order_id DESC) AS rn
  FROM sales.orders
)
SELECT cust_id, order_date, order_id, net_total
FROM ranked
WHERE rn = 1
LIMIT 200;

/* Q55. */
WITH ranked AS (
  SELECT address_id, customer_id, is_default, address_line,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY is_default DESC, address_id ASC) AS rn
  FROM customers.addresses
)
SELECT customer_id, address_id, is_default, address_line
FROM ranked
WHERE rn = 1
LIMIT 200;

/* Q56. */
WITH ranked AS (
  SELECT supplier_id, supplier_name,
         ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(supplier_name)) ORDER BY supplier_id ASC) AS rn
  FROM products.suppliers
)
SELECT supplier_id, supplier_name
FROM ranked
WHERE rn = 1;

/* Q57. */
WITH ranked AS (
  SELECT review_id, customer_id, product_id, review_date,
         ROW_NUMBER() OVER (PARTITION BY customer_id, product_id ORDER BY review_date DESC, review_id DESC) AS rn
  FROM customers.reviews
)
SELECT customer_id, product_id, review_id, review_date
FROM ranked
WHERE rn = 1
LIMIT 200;

/* Q58. */
WITH ranked AS (
  SELECT payment_id, order_id, payment_date,
         COUNT(*) OVER (PARTITION BY order_id) AS payment_count,
         ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY payment_date DESC, payment_id DESC) AS rn
  FROM sales.payments
)
SELECT order_id, payment_id, payment_date, payment_count,
       (payment_count > 1) AS multiple_payments_flag
FROM ranked
WHERE rn = 1
LIMIT 200;

/* Q59. */
WITH ranked AS (
  SELECT customer_id, phone, registration_date,
         ROW_NUMBER() OVER (PARTITION BY REGEXP_REPLACE(phone, '\D', '', 'g') ORDER BY registration_date DESC, customer_id DESC) AS rn
  FROM customers.customers
  WHERE phone IS NOT NULL
)
SELECT customer_id, phone, registration_date
FROM ranked
WHERE rn = 1
LIMIT 200;

/* Q60. */
WITH multi_brand_names AS (
  SELECT LOWER(TRIM(product_name)) AS norm_name
  FROM products.products
  GROUP BY LOWER(TRIM(product_name))
  HAVING COUNT(DISTINCT brand_id) > 1
),
ranked AS (
  SELECT p.product_id, p.product_name, p.brand_id,
         ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(p.product_name)) ORDER BY p.product_id ASC) AS rn
  FROM products.products p
  JOIN multi_brand_names m ON m.norm_name = LOWER(TRIM(p.product_name))
)
SELECT product_id, product_name, brand_id
FROM ranked
WHERE rn = 1
LIMIT 200;

/* Q61. */
WITH ranked AS (
  SELECT order_item_id, order_id, prod_id, net_amount,
         ROW_NUMBER() OVER (PARTITION BY order_id, prod_id ORDER BY net_amount DESC, order_item_id DESC) AS rn
  FROM sales.order_items
)
SELECT order_id, prod_id, order_item_id, net_amount
FROM ranked
WHERE rn = 1
LIMIT 200;

/* Q62. */
WITH email_groups AS (
  SELECT email, COUNT(*) AS duplicate_count
  FROM customers.customers
  GROUP BY email
  HAVING COUNT(*) >= 3
),
ranked AS (
  SELECT customer_id, c.email, c.registration_date,
         ROW_NUMBER() OVER (PARTITION BY c.email ORDER BY c.registration_date DESC, c.customer_id DESC) AS rn
  FROM customers.customers c
  JOIN email_groups eg ON eg.email = c.email
)
SELECT email, customer_id, registration_date, rn
FROM ranked
ORDER BY email, rn
LIMIT 200;

/* Q63. */
WITH ranked AS (
  SELECT warehouse_id, product_id, snapshot_date, quantity_on_hand,
         ROW_NUMBER() OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date DESC) AS rn
  FROM supply_chain.inventory_snapshots
)
SELECT warehouse_id, product_id, snapshot_date, quantity_on_hand
FROM ranked
WHERE rn = 1
LIMIT 200;

/* Q64. */
WITH ranked AS (
  SELECT customer_id, tier_id, points_balance,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY points_balance DESC) AS rn
  FROM loyalty.members
)
SELECT customer_id, tier_id, points_balance
FROM ranked
WHERE rn = 1
LIMIT 200;

/* Q65. */
WITH ranked AS (
  SELECT customer_id, email, registration_date,
         ROW_NUMBER() OVER (PARTITION BY email ORDER BY registration_date DESC, customer_id DESC) AS rn
  FROM customers.customers
),
merged_ids AS (
  SELECT email, STRING_AGG(customer_id::text, ',' ORDER BY customer_id) AS merged_customer_ids
  FROM customers.customers
  GROUP BY email
)
SELECT r.email, r.customer_id AS golden_customer_id, r.registration_date, m.merged_customer_ids
FROM ranked r
JOIN merged_ids m ON m.email = r.email
WHERE r.rn = 1
LIMIT 200;

/* Q66. */
WITH ranked AS (
  SELECT ticket_id, customer_id, subject, created_date,
         ROW_NUMBER() OVER (PARTITION BY customer_id, subject ORDER BY created_date DESC, ticket_id DESC) AS rn
  FROM support.tickets
)
SELECT customer_id, subject, ticket_id, created_date
FROM ranked
WHERE rn = 1
LIMIT 200;

/* Q67. */
WITH ranked AS (
  SELECT order_id, cust_id, order_date,
         ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date ASC, order_id ASC) AS rn
  FROM sales.orders
)
SELECT cust_id AS customer_id, order_id AS acquisition_order_id, order_date
FROM ranked
WHERE rn = 1
LIMIT 200;

/* Q68. */
WITH ranked AS (
  SELECT address_id, customer_id, pincode, is_default,
         ROW_NUMBER() OVER (PARTITION BY customer_id, pincode ORDER BY is_default DESC, address_id ASC) AS rn
  FROM customers.addresses
)
SELECT customer_id, pincode, address_id
FROM ranked
WHERE rn = 1
LIMIT 200;

/* Q69. */
SELECT c.customer_id, COUNT(DISTINCT a.city) AS distinct_cities
FROM customers.customers c
JOIN customers.addresses a ON a.customer_id = c.customer_id
GROUP BY c.customer_id
HAVING COUNT(DISTINCT a.city) > 1
LIMIT 200;

/* Q70. */
WITH ranked AS (
  SELECT product_id, brand_id, product_name, price,
         ROW_NUMBER() OVER (PARTITION BY brand_id, product_name ORDER BY price DESC, product_id ASC) AS rn
  FROM products.products
)
SELECT brand_id, product_name, product_id, price
FROM ranked
WHERE rn = 1
LIMIT 200;

/* Q71. */
WITH email_groups AS (
  SELECT email, COUNT(*) AS duplicate_count
  FROM customers.customers
  GROUP BY email
  HAVING COUNT(*) >= 2
)
SELECT email, duplicate_count,
       RANK() OVER (ORDER BY duplicate_count DESC) AS cluster_rank
FROM email_groups
ORDER BY cluster_rank
LIMIT 50;

/* Q72. */
WITH ranked AS (
  SELECT review_id, product_id, review_date, rating,
         ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY review_date DESC, review_id DESC) AS latest_rn,
         ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY rating DESC, review_id) AS rating_position
  FROM customers.reviews
)
SELECT product_id, review_id, review_date, rating, rating_position
FROM ranked
WHERE latest_rn = 1
ORDER BY product_id
LIMIT 200;

/* Q73. */
WITH ranked AS (
  SELECT call_id, customer_id, call_start_time::date AS call_date, call_duration_seconds,
         ROW_NUMBER() OVER (PARTITION BY customer_id, call_start_time::date ORDER BY call_duration_seconds DESC, call_id DESC) AS rn
  FROM call_center.calls
)
SELECT customer_id, call_date, call_id, call_duration_seconds
FROM ranked
WHERE rn = 1
LIMIT 200;

/* Q74. */
WITH ranked AS (
  SELECT customer_id, email, registration_date,
         ROW_NUMBER() OVER (PARTITION BY email ORDER BY registration_date DESC, customer_id DESC) AS rn
  FROM customers.customers
)
SELECT customer_id, email, registration_date
FROM ranked
WHERE rn = 1
ORDER BY customer_id
LIMIT 500;

/* Q75. */
WITH ranked AS (
  SELECT customer_id, email,
         ROW_NUMBER() OVER (PARTITION BY email ORDER BY registration_date DESC, customer_id DESC) AS rn
  FROM customers.customers
)
SELECT email,
       COUNT(*) AS before_count,
       COUNT(*) FILTER (WHERE rn = 1) AS after_count
FROM ranked
GROUP BY email
HAVING COUNT(*) > 1
ORDER BY before_count DESC
LIMIT 50;

/* ============================================================
   SECTION D: NTILE SEGMENTATION & PERCENTILES (25)
   ------------------------------------------------------------ */
/* Q76. */
WITH customer_spend AS (
  SELECT cust_id AS customer_id, SUM(net_total) AS total_spend
  FROM sales.orders
  GROUP BY cust_id
)
SELECT customer_id, total_spend,
       NTILE(4) OVER (ORDER BY total_spend DESC) AS spend_quartile,
       CASE NTILE(4) OVER (ORDER BY total_spend DESC)
         WHEN 1 THEN 'Q1' WHEN 2 THEN 'Q2' WHEN 3 THEN 'Q3' ELSE 'Q4' END AS quartile_label
FROM customer_spend
ORDER BY spend_quartile, total_spend DESC
LIMIT 200;

/* Q77. */
WITH region_spend AS (
  SELECT c.customer_id, s.region_id, COALESCE(SUM(o.net_total),0) AS total_spend
  FROM customers.customers c
  JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = TRUE
  JOIN stores.stores s ON s.city = a.city
  LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
  GROUP BY c.customer_id, s.region_id
),
bucketed AS (
  SELECT region_id, customer_id, total_spend,
         NTILE(10) OVER (PARTITION BY region_id ORDER BY total_spend) AS decile
  FROM region_spend
)
SELECT region_id, decile, MIN(total_spend) AS decile_floor, MAX(total_spend) AS decile_ceiling, COUNT(*) AS customers
FROM bucketed
GROUP BY region_id, decile
ORDER BY region_id, decile;

/* Q78. */
WITH customer_spend AS (
  SELECT cust_id AS customer_id, SUM(net_total) AS total_spend
  FROM sales.orders
  GROUP BY cust_id
)
SELECT customer_id, total_spend,
       NTILE(5) OVER (ORDER BY total_spend DESC) AS monetary_score
FROM customer_spend
ORDER BY monetary_score, total_spend DESC
LIMIT 200;

/* Q79. */
WITH customer_freq AS (
  SELECT cust_id AS customer_id, COUNT(*) AS order_count
  FROM sales.orders
  GROUP BY cust_id
)
SELECT customer_id, order_count,
       NTILE(5) OVER (ORDER BY order_count DESC) AS frequency_score
FROM customer_freq
ORDER BY frequency_score, order_count DESC
LIMIT 200;

/* Q80. */
WITH customer_recency AS (
  SELECT cust_id AS customer_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order
  FROM sales.orders
  GROUP BY cust_id
)
SELECT customer_id, days_since_last_order,
       NTILE(5) OVER (ORDER BY days_since_last_order ASC) AS recency_score
FROM customer_recency
ORDER BY recency_score, days_since_last_order ASC
LIMIT 200;

/* Q81. */
WITH cust_agg AS (
  SELECT cust_id AS customer_id,
         (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS days_since_last_order,
         COUNT(*) AS order_count,
         SUM(net_total) AS total_spend
  FROM sales.orders
  GROUP BY cust_id
),
scored AS (
  SELECT customer_id,
         NTILE(5) OVER (ORDER BY days_since_last_order ASC) AS r_score,
         NTILE(5) OVER (ORDER BY order_count DESC) AS f_score,
         NTILE(5) OVER (ORDER BY total_spend DESC) AS m_score
  FROM cust_agg
)
SELECT customer_id, r_score, f_score, m_score,
       r_score::text || '-' || f_score::text || '-' || m_score::text AS rfm_code
FROM scored
ORDER BY customer_id
LIMIT 200;

/* Q82. */
WITH customer_spend AS (
  SELECT cust_id AS customer_id, SUM(net_total) AS total_spend
  FROM sales.orders
  GROUP BY cust_id
),
bucketed AS (
  SELECT customer_id, total_spend, NTILE(4) OVER (ORDER BY total_spend DESC) AS spend_quartile
  FROM customer_spend
)
SELECT customer_id, total_spend, 'VIP' AS segment,
       ROW_NUMBER() OVER (ORDER BY total_spend DESC) AS rank_within_vip
FROM bucketed
WHERE spend_quartile = 1
ORDER BY total_spend DESC
LIMIT 200;

/* Q83. */
WITH product_margin AS (
  SELECT p.product_id, cat.category_id, (p.price - p.cost_price) AS margin
  FROM products.products p
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
),
bucketed AS (
  SELECT product_id, category_id, margin,
         NTILE(4) OVER (PARTITION BY category_id ORDER BY margin DESC) AS margin_quartile
  FROM product_margin
)
SELECT category_id, product_id, margin
FROM bucketed
WHERE margin_quartile = 1
ORDER BY category_id, margin DESC
LIMIT 200;

/* Q84. */
SELECT o.order_id, s.region_id, o.net_total,
       NTILE(100) OVER (PARTITION BY s.region_id ORDER BY o.net_total) AS percentile_bucket
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
ORDER BY s.region_id, percentile_bucket
LIMIT 200;

/* Q85. */
WITH dept_quartile AS (
  SELECT employee_id, dept_id, salary,
         NTILE(4) OVER (PARTITION BY dept_id ORDER BY salary) AS dept_quartile
  FROM stores.employees
),
company_quartile AS (
  SELECT employee_id, NTILE(4) OVER (ORDER BY salary) AS company_quartile
  FROM stores.employees
)
SELECT d.employee_id, d.dept_id, d.salary, d.dept_quartile, c.company_quartile
FROM dept_quartile d
JOIN company_quartile c ON c.employee_id = d.employee_id
ORDER BY d.dept_id, d.dept_quartile
LIMIT 200;

/* Q86. */
WITH store_revenue AS (
  SELECT store_id, SUM(net_total) AS revenue
  FROM sales.orders
  GROUP BY store_id
),
bucketed AS (
  SELECT store_id, revenue, NTILE(4) OVER (ORDER BY revenue DESC) AS revenue_tier
  FROM store_revenue
)
SELECT revenue_tier, COUNT(*) AS store_count, AVG(revenue) AS avg_revenue
FROM bucketed
GROUP BY revenue_tier
ORDER BY revenue_tier;

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
WITH bucketed AS (
  SELECT review_id, product_id, rating,
         NTILE(4) OVER (PARTITION BY product_id ORDER BY rating) AS rating_quartile
  FROM customers.reviews
)
SELECT product_id, review_id, rating
FROM bucketed
WHERE rating_quartile = 1
ORDER BY product_id
LIMIT 200;

/* Q89. */
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

/* Q90. */
WITH wh_totals AS (
  SELECT warehouse_id, SUM(quantity_on_hand) AS total_qty
  FROM supply_chain.inventory_snapshots
  GROUP BY warehouse_id
),
bucketed AS (
  SELECT warehouse_id, total_qty, NTILE(5) OVER (ORDER BY total_qty) AS quintile
  FROM wh_totals
)
SELECT warehouse_id, total_qty, quintile,
       (quintile = 1) AS flagged_for_audit
FROM bucketed
ORDER BY quintile, total_qty;

/* Q91. */
WITH delivery_days AS (
  SELECT courier_name, (delivered_date - shipped_date) AS days
  FROM sales.shipments
  WHERE delivered_date IS NOT NULL
),
bucketed AS (
  SELECT courier_name, days, NTILE(4) OVER (PARTITION BY courier_name ORDER BY days DESC) AS delay_quartile
  FROM delivery_days
)
SELECT courier_name, days
FROM bucketed
WHERE delay_quartile = 1
ORDER BY courier_name, days DESC
LIMIT 200;

/* Q92. */
WITH campaign_spend AS (
  SELECT campaign_id, platform, SUM(amount) AS total_spend
  FROM marketing.ads_spend
  GROUP BY campaign_id, platform
),
bucketed AS (
  SELECT campaign_id, platform, total_spend,
         NTILE(4) OVER (PARTITION BY platform ORDER BY total_spend DESC) AS spend_quartile
  FROM campaign_spend
)
SELECT platform, campaign_id, total_spend
FROM bucketed
WHERE spend_quartile = 1
ORDER BY platform, total_spend DESC;

/* Q93. */
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
SELECT spend_quartile, freq_quartile, COUNT(*) AS customer_count
FROM scored
GROUP BY spend_quartile, freq_quartile
ORDER BY spend_quartile, freq_quartile;

/* Q94. */
WITH bucketed AS (
  SELECT order_id, net_total, NTILE(10) OVER (ORDER BY net_total) AS decile
  FROM sales.orders
)
SELECT decile, MIN(net_total) AS decile_floor, MAX(net_total) AS decile_ceiling
FROM bucketed
WHERE decile = 9
GROUP BY decile;

/* Q95. */
WITH customer_spend AS (
  SELECT cust_id AS customer_id, SUM(net_total) AS total_spend,
         MAX(order_date) AS last_order_date
  FROM sales.orders
  GROUP BY cust_id
),
bucketed AS (
  SELECT customer_id, total_spend, last_order_date,
         NTILE(4) OVER (ORDER BY total_spend DESC) AS spend_quartile
  FROM customer_spend
)
SELECT customer_id, total_spend, spend_quartile,
       ROW_NUMBER() OVER (PARTITION BY spend_quartile ORDER BY last_order_date DESC) AS recency_rank_in_quartile
FROM bucketed
ORDER BY spend_quartile, recency_rank_in_quartile
LIMIT 200;

/* Q96. */
WITH bucketed AS (
  SELECT employee_id, store_id, joining_date,
         NTILE(4) OVER (PARTITION BY store_id ORDER BY joining_date DESC) AS tenure_quartile
  FROM stores.employees
)
SELECT store_id, employee_id, joining_date
FROM bucketed
WHERE tenure_quartile = 1
ORDER BY store_id, joining_date DESC
LIMIT 200;

/* Q97. */
WITH product_prices AS (
  SELECT product_id, brand_id, price
  FROM products.products
),
bucketed AS (
  SELECT product_id, brand_id, price,
         NTILE(100) OVER (PARTITION BY brand_id ORDER BY price) AS percentile_bucket,
         RANK() OVER (PARTITION BY brand_id ORDER BY price) AS price_rank
  FROM product_prices
)
SELECT brand_id, product_id, price, percentile_bucket, price_rank
FROM bucketed
ORDER BY brand_id, percentile_bucket
LIMIT 200;

/* Q98. */
WITH customer_reviews AS (
  SELECT customer_id, COUNT(*) AS review_count
  FROM customers.reviews
  GROUP BY customer_id
),
bucketed AS (
  SELECT customer_id, review_count, NTILE(4) OVER (ORDER BY review_count DESC) AS engagement_quartile
  FROM customer_reviews
)
SELECT customer_id, review_count
FROM bucketed
WHERE engagement_quartile = 1
ORDER BY review_count DESC
LIMIT 200;

/* Q99. Comparing NTILE(4) row-count-based buckets against RANK-derived quartiles on the same salary column; they differ whenever ties or uneven group sizes push a row into a different bucket under each scheme. */
WITH salary_data AS (
  SELECT employee_id, salary,
         NTILE(4) OVER (ORDER BY salary) AS ntile_bucket,
         CEIL(RANK() OVER (ORDER BY salary)::numeric / (SELECT COUNT(*) FROM stores.employees) * 4) AS rank_based_quartile
  FROM stores.employees
)
SELECT employee_id, salary, ntile_bucket, rank_based_quartile
FROM salary_data
WHERE ntile_bucket <> rank_based_quartile
ORDER BY salary
LIMIT 100;

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
         NTILE(5) OVER (ORDER BY total_spend DESC) AS m_score
  FROM cust_agg
),
segmented AS (
  SELECT customer_id, r_score, f_score, m_score,
         CASE
           WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'Champions'
           WHEN f_score <= 2 AND m_score <= 3 THEN 'Loyal'
           WHEN r_score >= 4 AND f_score >= 4 THEN 'Lost'
           WHEN r_score >= 3 THEN 'At-Risk'
           ELSE 'Potential'
         END AS segment
  FROM scored
)
SELECT segment, customer_id,
       ROW_NUMBER() OVER (PARTITION BY segment ORDER BY m_score, f_score, r_score) AS rank_within_segment
FROM segmented
ORDER BY segment, rank_within_segment
LIMIT 200;

/* ============================================================
   END OF ANSWER KEY - Window Functions Part 1 - HARD LEVEL (100/100)
============================================================ */
