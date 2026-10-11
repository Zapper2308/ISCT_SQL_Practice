/* ============================================================
   ANSWER KEY - Window Functions Part 1: Ranking & Bucketing (MEDIUM LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1.  A window function's alias isn't visible in its own SELECT's WHERE because WHERE runs before window functions are computed; wrap the SELECT in a subquery or CTE and filter on the alias in the outer query instead. */
/* Q2.  PARTITION BY a, b creates a separate window for every distinct COMBINATION of a and b (finer-grained groups, ranking restarts more often); PARTITION BY a alone groups only by a, so rows with the same a but different b still share one ranking sequence. */
/* Q3.  Without a unique tie-breaker column, rows with identical ORDER BY values get numbered in an arbitrary, plan-dependent order that can change between runs of the same query - a tie-breaker (like a primary key) makes the numbering deterministic and reproducible. */
/* Q4.  RANK() gives tied rows the same rank and then skips ahead by the tie count (e.g. two rows tied at rank 1, next row is rank 3); DENSE_RANK() gives tied rows the same rank but the next row continues at rank 2 with no gap. */
/* Q5.  ORDER BY ... DESC NULLS LAST keeps NULLs at the bottom even in a descending sort (default DESC puts NULLs first) - it changes which rows get the earliest rank numbers when NULLs are present in the ranking column. */
/* Q6.  NTILE(4) divides rows into 4 equal-COUNT groups regardless of the actual value range (quartiles by row count); WIDTH_BUCKET divides a fixed VALUE range into equal-width bins regardless of how many rows fall in each - pick NTILE for "even group sizes" segmentation, WIDTH_BUCKET for "even value ranges" like price bands. */
/* Q7.  GROUP BY collapses each group into one summary row, discarding row-level detail; "top-N per group" needs to keep the individual rows (just tagged with their rank) so a window function - which preserves every row - is required, not an aggregate that reduces row count. */
/* Q8.  Rank the rows with ROW_NUMBER() (or DENSE_RANK() if ties should share the position) per group in a CTE/subquery, then filter the outer query for rn = N exactly, instead of rn <= N for top-N. */
/* Q9.  The window's ORDER BY determines which row gets rn = 1 within each partition; since only the row with rn = 1 is kept when deduping, whichever sort order you choose (e.g. latest date first) directly decides which duplicate survives. */
/* Q10. Yes - a named WINDOW clause (WINDOW w AS (PARTITION BY ... ORDER BY ...)) lets multiple functions reference it via OVER w, avoiding repeating the same PARTITION BY/ORDER BY for ROW_NUMBER() OVER w, RANK() OVER w, DENSE_RANK() OVER w in one query. */
/* Q11. When a partition's row count is less than N in NTILE(N), some buckets simply end up empty (no rows assigned that bucket number) while the earlier buckets each get one row - not every bucket 1..N is guaranteed to appear. */
/* Q12. On a column with all-unique values, no ties ever occur, so RANK's "same rank for ties, skip ahead" behavior never triggers - it produces the exact same 1,2,3,... sequence as ROW_NUMBER since there's nothing to tie. */
/* Q13. PARTITION BY with no ORDER BY still splits rows into groups, but every row in a partition ties for the same ranking position (e.g. ROW_NUMBER becomes arbitrary/undefined per-row, RANK/DENSE_RANK assign 1 to every row) since there's no defined sequence to walk. */
/* Q14. List two ORDER BY expressions: ORDER BY primary_col DESC, tiebreak_col ASC - Postgres sorts by the first expression's direction, then uses the second expression (in its own specified direction) only to resolve ties in the first. */
/* Q15. Window functions run before the outer query's WHERE would see them, but a CTE/subquery computes rn as a normal output column first - the OUTER query's WHERE then filters on that already-materialized column like any other column, which is valid because window evaluation has already finished. */
/* Q16. Ranking all rows then filtering means Postgres must sort/rank the entire table before discarding most of it; adding a WHERE first (when the filter doesn't depend on the rank) shrinks the row set before the expensive sort, so cost is roughly proportional to filtered rows, not the whole table. */
/* Q17. DISTINCT is applied AFTER window functions compute their values, so DISTINCT SELECT rn, col will deduplicate on the combination including the window's own output - it does not affect what the window function sees when computing rn. */
/* Q18. When multiple rows tie on the ORDER BY expression, which one lands in bucket N vs N+1 in NTILE is decided by the underlying tie-order (itself non-deterministic without a tie-breaker), so identical values can be split across adjacent buckets differently across runs. */
/* Q19. NTILE(4) OVER (ORDER BY spend) assigns each row a bucket number 1-4 based on quartile position; wrapping that number in a CASE (1->'Q1', 2->'Q2', ...) turns the numeric bucket into a human-readable label for reporting/segmentation. */
/* Q20. RANK is the right choice whenever the business meaning of "tied" matters - e.g. a leaderboard where two salespeople who hit the exact same revenue should both display as "#1", with the next distinct value correctly showing as "#3" to reflect two people ahead of them. */
/* Q21. PARTITION BY itself is what causes the ranking sequence to reset at each new partition value - Postgres computes the window function independently within each partition, so the count/rank restarts from the beginning whenever the partition key changes. */
/* Q22. PARTITION BY DATE_TRUNC('month', order_date) groups rows into calendar-month buckets on the fly without needing a separate month column, letting you rank/window within each month directly - useful whenever the natural grouping key is a transformation of a raw column rather than the raw column itself. */
/* Q23. PERCENT_RANK adds a normalized 0-to-1 relative standing (rank-1)/(count-1) instead of RANK's raw integer position, so it's comparable across groups/partitions of very different sizes - "top 10%" means the same thing everywhere, unlike an absolute rank number. */
/* Q24. RANK() <= N naturally includes every row tied for the Nth position (so you can get MORE than N rows when there's a tie at the boundary); ROW_NUMBER() <= N always returns exactly N rows, arbitrarily picking one of the tied rows to be "the Nth" and excluding the rest. */
/* Q25. Computing the ranking in a CTE first means the (often expensive) sort/window pass runs once over the smaller pre-join row set; ranking after joining to other tables can force Postgres to compute the window function over a larger, fanned-out intermediate result, and can also change which rows tie. */

/* ============================================================
   SECTION B: RANKING WITHIN PARTITIONS (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT product_id, product_name, brand_id, price,
       RANK() OVER (PARTITION BY brand_id ORDER BY price DESC, product_id) AS price_rank
FROM products.products
ORDER BY brand_id, price_rank
LIMIT 100;

/* Q27. */
SELECT employee_id, store_id, first_name, last_name, salary, joining_date,
       RANK() OVER (PARTITION BY store_id ORDER BY salary DESC, joining_date ASC) AS salary_rank
FROM stores.employees
ORDER BY store_id, salary_rank
LIMIT 100;

/* Q28. */
SELECT order_id, store_id, DATE_TRUNC('month', order_date) AS order_month, net_total,
       RANK() OVER (PARTITION BY store_id, DATE_TRUNC('month', order_date) ORDER BY net_total DESC) AS revenue_rank
FROM sales.orders
ORDER BY store_id, order_month, revenue_rank
LIMIT 100;

/* Q29. */
SELECT m.customer_id, m.tier_id, m.points_balance,
       RANK() OVER (PARTITION BY m.tier_id ORDER BY m.points_balance DESC) AS points_rank
FROM loyalty.members m
ORDER BY m.tier_id, points_rank
LIMIT 100;

/* Q30. */
SELECT p.product_id, p.product_name, cat.category_id, cat.category_name, p.price,
       RANK() OVER (PARTITION BY cat.category_id ORDER BY p.price DESC) AS price_rank
FROM products.products p
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
ORDER BY cat.category_id, price_rank
LIMIT 100;

/* Q31. */
WITH store_revenue AS (
  SELECT s.store_id, s.region_id, s.store_name, SUM(o.net_total) AS revenue
  FROM stores.stores s
  JOIN sales.orders o ON o.store_id = s.store_id
  GROUP BY s.store_id, s.region_id, s.store_name
)
SELECT store_id, region_id, store_name, revenue,
       RANK() OVER (PARTITION BY region_id ORDER BY revenue DESC) AS revenue_rank
FROM store_revenue
ORDER BY region_id, revenue_rank;

/* Q32. */
SELECT review_id, product_id, rating, review_date,
       RANK() OVER (PARTITION BY product_id ORDER BY rating DESC, review_date DESC) AS rank_in_product
FROM customers.reviews
ORDER BY product_id, rank_in_product
LIMIT 100;

/* Q33. */
SELECT employee_id, store_id, role, salary,
       RANK() OVER (PARTITION BY store_id, role ORDER BY salary DESC) AS salary_rank
FROM stores.employees
ORDER BY store_id, role, salary_rank
LIMIT 100;

/* Q34. */
WITH brand_counts AS (
  SELECT b.brand_id, cat.category_id, COUNT(p.product_id) AS product_count
  FROM core.dim_brand b
  JOIN core.dim_category cat ON cat.category_id = b.category_id
  LEFT JOIN products.products p ON p.brand_id = b.brand_id
  GROUP BY b.brand_id, cat.category_id
)
SELECT category_id, brand_id, product_count,
       RANK() OVER (PARTITION BY category_id ORDER BY product_count DESC) AS brand_rank
FROM brand_counts
ORDER BY category_id, brand_rank;

/* Q35. */
WITH agent_resolved AS (
  SELECT agent_id, category, COUNT(*) AS resolved_count
  FROM support.tickets
  WHERE status = 'Resolved' AND agent_id IS NOT NULL
  GROUP BY agent_id, category
)
SELECT agent_id, category, resolved_count,
       RANK() OVER (PARTITION BY category ORDER BY resolved_count DESC) AS agent_rank
FROM agent_resolved
ORDER BY category, agent_rank
LIMIT 100;

/* Q36. */
SELECT order_id, cust_id, order_date, net_total,
       RANK() OVER (PARTITION BY cust_id ORDER BY net_total DESC, order_date DESC) AS order_rank
FROM sales.orders
ORDER BY cust_id, order_rank
LIMIT 100;

/* Q37. */
SELECT product_id, product_name, supplier_id, cost_price,
       DENSE_RANK() OVER (PARTITION BY supplier_id ORDER BY cost_price DESC) AS cost_dense_rank
FROM products.products
ORDER BY supplier_id, cost_dense_rank
LIMIT 100;

/* Q38. */
WITH courier_days AS (
  SELECT courier_name, delivered_date - shipped_date AS delivery_days
  FROM sales.shipments
  WHERE delivered_date IS NOT NULL
)
SELECT courier_name, delivery_days,
       RANK() OVER (PARTITION BY courier_name ORDER BY delivery_days DESC) AS days_rank
FROM courier_days
ORDER BY courier_name, days_rank
LIMIT 100;

/* Q39. */
SELECT pay_slip_id, employee_id, salary_year, salary_month, net_salary,
       RANK() OVER (PARTITION BY salary_year, salary_month ORDER BY net_salary DESC) AS salary_rank
FROM payroll.pay_slips
ORDER BY salary_year, salary_month, salary_rank
LIMIT 100;

/* Q40. */
WITH cohort_orders AS (
  SELECT c.customer_id, EXTRACT(YEAR FROM c.registration_date) AS reg_year,
         COUNT(o.order_id) AS order_count
  FROM customers.customers c
  LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
  GROUP BY c.customer_id, EXTRACT(YEAR FROM c.registration_date)
)
SELECT customer_id, reg_year, order_count,
       RANK() OVER (PARTITION BY reg_year ORDER BY order_count DESC) AS order_rank
FROM cohort_orders
ORDER BY reg_year, order_rank
LIMIT 100;

/* Q41. */
WITH product_reviews AS (
  SELECT p.product_id, p.brand_id, COUNT(r.review_id) AS review_count
  FROM products.products p
  LEFT JOIN customers.reviews r ON r.product_id = p.product_id
  GROUP BY p.product_id, p.brand_id
)
SELECT product_id, brand_id, review_count,
       RANK() OVER (PARTITION BY brand_id ORDER BY review_count DESC) AS review_rank
FROM product_reviews
ORDER BY brand_id, review_rank
LIMIT 100;

/* Q42. */
WITH wh_totals AS (
  SELECT w.warehouse_id, w.region, SUM(isn.quantity_on_hand) AS total_qty
  FROM supply_chain.warehouses w
  LEFT JOIN supply_chain.inventory_snapshots isn ON isn.warehouse_id = w.warehouse_id
  GROUP BY w.warehouse_id, w.region
)
SELECT warehouse_id, region, total_qty,
       RANK() OVER (PARTITION BY region ORDER BY total_qty DESC) AS qty_rank
FROM wh_totals
ORDER BY region, qty_rank;

/* Q43. */
WITH store_emp_counts AS (
  SELECT s.store_id, s.region_id, COUNT(e.employee_id) AS employee_count
  FROM stores.stores s
  LEFT JOIN stores.employees e ON e.store_id = s.store_id
  GROUP BY s.store_id, s.region_id
)
SELECT store_id, region_id, employee_count,
       RANK() OVER (PARTITION BY region_id ORDER BY employee_count DESC) AS emp_rank
FROM store_emp_counts
ORDER BY region_id, emp_rank;

/* Q44. */
SELECT order_item_id, order_id, prod_id, net_amount,
       RANK() OVER (PARTITION BY order_id ORDER BY net_amount DESC) AS amount_rank
FROM sales.order_items
ORDER BY order_id, amount_rank
LIMIT 100;

/* Q45. */
WITH campaign_spend AS (
  SELECT c.campaign_id, a.platform, SUM(a.amount) AS total_spend
  FROM marketing.campaigns c
  JOIN marketing.ads_spend a ON a.campaign_id = c.campaign_id
  GROUP BY c.campaign_id, a.platform
)
SELECT campaign_id, platform, total_spend,
       RANK() OVER (PARTITION BY platform ORDER BY total_spend DESC) AS spend_rank
FROM campaign_spend
ORDER BY platform, spend_rank;

/* Q46. */
WITH city_spend AS (
  SELECT c.customer_id, a.city, COALESCE(SUM(o.net_total), 0) AS lifetime_spend
  FROM customers.customers c
  JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = TRUE
  LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
  GROUP BY c.customer_id, a.city
)
SELECT customer_id, city, lifetime_spend,
       RANK() OVER (PARTITION BY city ORDER BY lifetime_spend DESC) AS spend_rank
FROM city_spend
ORDER BY city, spend_rank
LIMIT 100;

/* Q47. */
WITH product_units AS (
  SELECT p.product_id, p.brand_id, SUM(oi.quantity) AS units_sold
  FROM products.products p
  JOIN sales.order_items oi ON oi.prod_id = p.product_id
  GROUP BY p.product_id, p.brand_id
)
SELECT product_id, brand_id, units_sold,
       RANK() OVER (PARTITION BY brand_id ORDER BY units_sold DESC) AS units_rank
FROM product_units
ORDER BY brand_id, units_rank
LIMIT 100;

/* Q48. */
WITH ranked AS (
  SELECT employee_id, dept_id, first_name, last_name, salary,
         RANK() OVER (PARTITION BY dept_id ORDER BY salary DESC) AS salary_rank
  FROM stores.employees
)
SELECT dept_id, employee_id, first_name, last_name, salary, salary_rank
FROM ranked
WHERE salary_rank <= 5
ORDER BY dept_id, salary_rank;

/* Q49. */
SELECT ticket_id, agent_id, resolved_date - created_date::date AS resolution_days,
       RANK() OVER (PARTITION BY agent_id ORDER BY (resolved_date - created_date::date) DESC) AS resolution_rank
FROM support.tickets
WHERE resolved_date IS NOT NULL AND agent_id IS NOT NULL
ORDER BY agent_id, resolution_rank
LIMIT 100;

/* Q50. */
WITH region_avg AS (
  SELECT s.region_id, AVG(o.net_total) AS avg_order_value
  FROM stores.stores s
  JOIN sales.orders o ON o.store_id = s.store_id
  GROUP BY s.region_id
)
SELECT region_id, avg_order_value,
       RANK() OVER (ORDER BY avg_order_value DESC) AS region_rank
FROM region_avg
ORDER BY region_rank;

/* ============================================================
   SECTION C: TOP-N / NTH PER GROUP (25)
   ------------------------------------------------------------ */
/* Q51. */
WITH ranked AS (
  SELECT employee_id, dept_id, first_name, last_name, salary,
         ROW_NUMBER() OVER (PARTITION BY dept_id ORDER BY salary DESC, employee_id) AS rn
  FROM stores.employees
)
SELECT dept_id, employee_id, first_name, last_name, salary
FROM ranked
WHERE rn <= 3
ORDER BY dept_id, salary DESC;

/* Q52. */
WITH product_units AS (
  SELECT p.product_id, p.product_name, p.brand_id, SUM(oi.quantity) AS units_sold
  FROM products.products p
  JOIN sales.order_items oi ON oi.prod_id = p.product_id
  GROUP BY p.product_id, p.product_name, p.brand_id
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY brand_id ORDER BY units_sold DESC, product_id) AS rn
  FROM product_units
)
SELECT brand_id, product_id, product_name, units_sold
FROM ranked
WHERE rn <= 3
ORDER BY brand_id, units_sold DESC;

/* Q53. */
WITH ranked AS (
  SELECT o.*, ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date DESC, order_id DESC) AS rn
  FROM sales.orders o
)
SELECT order_id, cust_id, store_id, order_date, order_status, net_total
FROM ranked
WHERE rn <= 2
ORDER BY cust_id, order_date DESC
LIMIT 200;

/* Q54. */
WITH store_revenue AS (
  SELECT s.store_id, s.region_id, s.store_name, SUM(o.net_total) AS revenue
  FROM stores.stores s
  JOIN sales.orders o ON o.store_id = s.store_id
  GROUP BY s.store_id, s.region_id, s.store_name
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY region_id ORDER BY revenue DESC) AS rn
  FROM store_revenue
)
SELECT region_id, store_id, store_name, revenue
FROM ranked
WHERE rn <= 5
ORDER BY region_id, revenue DESC;

/* Q55. */
WITH ranked AS (
  SELECT employee_id, dept_id, first_name, last_name, salary,
         DENSE_RANK() OVER (PARTITION BY dept_id ORDER BY salary DESC) AS drnk
  FROM stores.employees
)
SELECT dept_id, employee_id, first_name, last_name, salary
FROM ranked
WHERE drnk = 2
ORDER BY dept_id;

/* Q56. */
WITH ranked AS (
  SELECT order_id, cust_id, order_date,
         ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date DESC, order_id DESC) AS rn
  FROM sales.orders
)
SELECT cust_id, order_id, order_date
FROM ranked
WHERE rn = 3
ORDER BY cust_id
LIMIT 100;

/* Q57. */
WITH ranked AS (
  SELECT review_id, product_id, review_text, rating, review_date,
         ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY review_date DESC, review_id DESC) AS rn
  FROM customers.reviews
)
SELECT product_id, review_id, review_text, rating, review_date
FROM ranked
WHERE rn = 1
ORDER BY product_id
LIMIT 100;

/* Q58. */
WITH city_spend AS (
  SELECT c.customer_id, a.city, COALESCE(SUM(o.net_total), 0) AS spend
  FROM customers.customers c
  JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = TRUE
  LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
  GROUP BY c.customer_id, a.city
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY city ORDER BY spend DESC, customer_id) AS rn
  FROM city_spend
)
SELECT city, customer_id, spend
FROM ranked
WHERE rn <= 3
ORDER BY city, spend DESC
LIMIT 200;

/* Q59. */
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

/* Q60. */
WITH ranked AS (
  SELECT order_id, store_id, net_total,
         ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY net_total DESC, order_id) AS rn
  FROM sales.orders
)
SELECT store_id, order_id, net_total
FROM ranked
WHERE rn = 1
ORDER BY store_id;

/* Q61. */
WITH open_tickets AS (
  SELECT ticket_id, agent_id, CURRENT_DATE - created_date::date AS days_open
  FROM support.tickets
  WHERE status = 'Open' AND agent_id IS NOT NULL
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY agent_id ORDER BY days_open DESC, ticket_id) AS rn
  FROM open_tickets
)
SELECT agent_id, ticket_id, days_open
FROM ranked
WHERE rn <= 3
ORDER BY agent_id, days_open DESC
LIMIT 200;

/* Q62. */
WITH product_margin AS (
  SELECT p.product_id, cat.category_id, (p.price - p.cost_price) AS margin
  FROM products.products p
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY category_id ORDER BY margin DESC, product_id) AS rn
  FROM product_margin
)
SELECT category_id, product_id, margin
FROM ranked
WHERE rn <= 2
ORDER BY category_id, margin DESC
LIMIT 200;

/* Q63. */
WITH ranked AS (
  SELECT order_id, cust_id, order_date,
         ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date ASC, order_id ASC) AS rn
  FROM sales.orders
)
SELECT cust_id, order_id, order_date
FROM ranked
WHERE rn = 1
ORDER BY cust_id
LIMIT 200;

/* Q64. */
WITH region_counts AS (
  SELECT region_id, COUNT(*) AS store_count
  FROM stores.stores
  GROUP BY region_id
),
ranked AS (
  SELECT region_id, store_count,
         RANK() OVER (ORDER BY store_count DESC) AS region_rank
  FROM region_counts
)
SELECT region_id, store_count, region_rank
FROM ranked
WHERE region_rank <= 3
ORDER BY region_rank;

/* Q65. */
WITH product_reviews AS (
  SELECT p.product_id, p.brand_id, COUNT(r.review_id) AS review_count
  FROM products.products p
  LEFT JOIN customers.reviews r ON r.product_id = p.product_id
  GROUP BY p.product_id, p.brand_id
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY brand_id ORDER BY review_count DESC, product_id) AS rn
  FROM product_reviews
)
SELECT brand_id, product_id, review_count
FROM ranked
WHERE rn <= 5
ORDER BY brand_id, review_count DESC
LIMIT 200;

/* Q66. */
WITH ranked AS (
  SELECT product_id, product_name, supplier_id, price,
         ROW_NUMBER() OVER (PARTITION BY supplier_id ORDER BY price DESC, product_id) AS rn
  FROM products.products
)
SELECT supplier_id, product_id, product_name, price
FROM ranked
WHERE rn = 1
ORDER BY supplier_id;

/* Q67. */
WITH agent_calls AS (
  SELECT agent_id, call_reason, COUNT(*) AS call_count
  FROM call_center.calls
  WHERE agent_id IS NOT NULL
  GROUP BY agent_id, call_reason
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY call_reason ORDER BY call_count DESC, agent_id) AS rn
  FROM agent_calls
)
SELECT call_reason, agent_id, call_count
FROM ranked
WHERE rn <= 3
ORDER BY call_reason, call_count DESC;

/* Q68. */
WITH ranked AS (
  SELECT review_id, customer_id, product_id, rating,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY rating DESC, review_id) AS rn
  FROM customers.reviews
)
SELECT customer_id, review_id, product_id, rating
FROM ranked
WHERE rn <= 2
ORDER BY customer_id, rating DESC
LIMIT 200;

/* Q69. */
WITH ranked AS (
  SELECT order_id, cust_id, order_date,
         ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date ASC, order_id ASC) AS rn
  FROM sales.orders
)
SELECT cust_id, order_id, order_date
FROM ranked
WHERE rn = 5
ORDER BY cust_id
LIMIT 200;

/* Q70. */
WITH ranked AS (
  SELECT warehouse_id, region, capacity_sqft,
         ROW_NUMBER() OVER (PARTITION BY region ORDER BY capacity_sqft DESC, warehouse_id) AS rn
  FROM supply_chain.warehouses
)
SELECT region, warehouse_id, capacity_sqft
FROM ranked
WHERE rn <= 3
ORDER BY region, capacity_sqft DESC;

/* Q71. */
WITH ranked AS (
  SELECT customer_id, tier,
         ROW_NUMBER() OVER (PARTITION BY tier ORDER BY registration_date ASC, customer_id ASC) AS rn
  FROM customers.customers
)
SELECT tier, customer_id
FROM ranked
WHERE rn = 1
ORDER BY tier;

/* Q72. */
WITH top_orders AS (
  SELECT order_id, store_id, net_total
  FROM sales.orders
  ORDER BY net_total DESC
  LIMIT 10
)
SELECT order_id, store_id, net_total,
       ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY net_total DESC) AS rn_in_store
FROM top_orders
ORDER BY net_total DESC;

/* Q73. */
WITH brand_revenue AS (
  SELECT cat.category_id, b.brand_id, SUM(oi.net_amount) AS revenue
  FROM core.dim_category cat
  JOIN core.dim_brand b ON b.category_id = cat.category_id
  JOIN products.products p ON p.brand_id = b.brand_id
  JOIN sales.order_items oi ON oi.prod_id = p.product_id
  GROUP BY cat.category_id, b.brand_id
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY category_id ORDER BY revenue DESC) AS rn
  FROM brand_revenue
)
SELECT category_id, brand_id, revenue
FROM ranked
WHERE rn <= 3
ORDER BY category_id, revenue DESC;

/* Q74. */
WITH ranked AS (
  SELECT payment_id, order_id, payment_date,
         ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY payment_date DESC, payment_id DESC) AS rn
  FROM sales.payments
)
SELECT order_id, payment_id, payment_date
FROM ranked
WHERE rn = 1
ORDER BY order_id
LIMIT 200;

/* Q75. */
WITH cohort_reviews AS (
  SELECT c.customer_id, EXTRACT(YEAR FROM c.registration_date) AS reg_year, COUNT(r.review_id) AS review_count
  FROM customers.customers c
  LEFT JOIN customers.reviews r ON r.customer_id = c.customer_id
  GROUP BY c.customer_id, EXTRACT(YEAR FROM c.registration_date)
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY reg_year ORDER BY review_count DESC, customer_id) AS rn
  FROM cohort_reviews
)
SELECT reg_year, customer_id, review_count
FROM ranked
WHERE rn <= 3
ORDER BY reg_year, review_count DESC;

/* ============================================================
   SECTION D: NTILE BUCKETING & DEDUP (25)
   ------------------------------------------------------------ */
/* Q76. */
WITH customer_spend AS (
  SELECT cust_id, SUM(net_total) AS total_spend
  FROM sales.orders
  GROUP BY cust_id
)
SELECT cust_id, total_spend,
       NTILE(4) OVER (ORDER BY total_spend) AS spend_quartile
FROM customer_spend
ORDER BY spend_quartile, total_spend
LIMIT 100;

/* Q77. */
SELECT product_id, product_name, brand_id, price,
       NTILE(10) OVER (PARTITION BY brand_id ORDER BY price) AS price_decile
FROM products.products
ORDER BY brand_id, price_decile
LIMIT 100;

/* Q78. */
SELECT order_id, store_id, net_total,
       NTILE(5) OVER (PARTITION BY store_id ORDER BY net_total) AS quintile
FROM sales.orders
ORDER BY store_id, quintile
LIMIT 100;

/* Q79. */
SELECT employee_id, dept_id, salary,
       NTILE(4) OVER (PARTITION BY dept_id ORDER BY salary) AS salary_quartile,
       CASE NTILE(4) OVER (PARTITION BY dept_id ORDER BY salary)
         WHEN 1 THEN 'Q1' WHEN 2 THEN 'Q2' WHEN 3 THEN 'Q3' ELSE 'Q4' END AS quartile_label
FROM stores.employees
ORDER BY dept_id, salary_quartile
LIMIT 100;

/* Q80. */
SELECT store_id, region_id, square_ft,
       NTILE(3) OVER (PARTITION BY region_id ORDER BY square_ft) AS size_tier,
       CASE NTILE(3) OVER (PARTITION BY region_id ORDER BY square_ft)
         WHEN 1 THEN 'Small' WHEN 2 THEN 'Mid' ELSE 'Large' END AS size_label
FROM stores.stores
ORDER BY region_id, size_tier;

/* Q81. */
WITH ranked AS (
  SELECT customer_id, email, registration_date,
         ROW_NUMBER() OVER (PARTITION BY email ORDER BY registration_date DESC, customer_id DESC) AS rn
  FROM customers.customers
)
SELECT customer_id, email, registration_date
FROM ranked
WHERE rn = 1
LIMIT 200;

/* Q82. */
WITH ranked AS (
  SELECT product_id, product_name, price,
         ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(product_name)) ORDER BY price ASC, product_id ASC) AS rn
  FROM products.products
)
SELECT product_id, product_name, price
FROM ranked
WHERE rn = 1
LIMIT 200;

/* Q83. */
WITH ranked AS (
  SELECT order_id, cust_id, order_date, net_total,
         ROW_NUMBER() OVER (PARTITION BY cust_id, order_date ORDER BY net_total DESC, order_id DESC) AS rn
  FROM sales.orders
)
SELECT cust_id, order_date, order_id, net_total
FROM ranked
WHERE rn = 1
LIMIT 200;

/* Q84. */
WITH ranked AS (
  SELECT address_id, customer_id, is_default, city,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY is_default DESC, address_id) AS rn
  FROM customers.addresses
)
SELECT customer_id, address_id, city
FROM ranked
WHERE rn = 1
LIMIT 200;

/* Q85. */
SELECT review_id, product_id, rating,
       NTILE(4) OVER (PARTITION BY product_id ORDER BY rating) AS rating_quartile
FROM customers.reviews
ORDER BY product_id, rating_quartile
LIMIT 100;

/* Q86. */
SELECT o.order_id, s.region_id, o.net_total,
       NTILE(100) OVER (PARTITION BY s.region_id ORDER BY o.net_total) AS percentile_bucket
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
ORDER BY s.region_id, percentile_bucket
LIMIT 100;

/* Q87. */
WITH customer_spend AS (
  SELECT cust_id AS customer_id, SUM(net_total) AS total_spend
  FROM sales.orders
  GROUP BY cust_id
)
SELECT customer_id, total_spend,
       NTILE(4) OVER (ORDER BY total_spend DESC) AS monetary_quartile
FROM customer_spend
ORDER BY monetary_quartile, total_spend DESC
LIMIT 100;

/* Q88. */
WITH customer_freq AS (
  SELECT cust_id AS customer_id, COUNT(*) AS order_count
  FROM sales.orders
  GROUP BY cust_id
)
SELECT customer_id, order_count,
       NTILE(4) OVER (ORDER BY order_count DESC) AS frequency_quartile
FROM customer_freq
ORDER BY frequency_quartile, order_count DESC
LIMIT 100;

/* Q89. */
WITH ranked AS (
  SELECT review_id, customer_id, product_id, review_date,
         ROW_NUMBER() OVER (PARTITION BY customer_id, product_id ORDER BY review_date DESC, review_id DESC) AS rn
  FROM customers.reviews
)
SELECT customer_id, product_id, review_id, review_date
FROM ranked
WHERE rn = 1
LIMIT 200;

/* Q90. */
WITH product_units AS (
  SELECT p.product_id, cat.category_id, SUM(oi.quantity) AS units_sold
  FROM products.products p
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
  JOIN sales.order_items oi ON oi.prod_id = p.product_id
  GROUP BY p.product_id, cat.category_id
)
SELECT product_id, category_id, units_sold,
       NTILE(4) OVER (PARTITION BY category_id ORDER BY units_sold) AS units_quartile
FROM product_units
ORDER BY category_id, units_quartile
LIMIT 100;

/* Q91. */
WITH ranked AS (
  SELECT supplier_id, supplier_name,
         ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(supplier_name)) ORDER BY supplier_id) AS rn
  FROM products.suppliers
)
SELECT supplier_id, supplier_name
FROM ranked
WHERE rn = 1;

/* Q92. */
SELECT employee_id, salary,
       NTILE(5) OVER (ORDER BY salary) AS salary_band
FROM stores.employees
ORDER BY salary_band, salary
LIMIT 100;

/* Q93. */
WITH ranked AS (
  SELECT payment_id, order_id, payment_date,
         ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY payment_date DESC, payment_id DESC) AS rn
  FROM sales.payments
)
SELECT order_id, payment_id, payment_date
FROM ranked
WHERE rn = 1
LIMIT 200;

/* Q94. */
WITH store_revenue AS (
  SELECT store_id, SUM(net_total) AS revenue
  FROM sales.orders
  GROUP BY store_id
),
bucketed AS (
  SELECT store_id, revenue, NTILE(4) OVER (ORDER BY revenue DESC) AS revenue_quartile
  FROM store_revenue
)
SELECT store_id, revenue, revenue_quartile,
       (revenue_quartile = 1) AS is_top_quartile
FROM bucketed
ORDER BY revenue_quartile, revenue DESC;

/* Q95. */
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

/* Q96. */
SELECT employee_id, dept_id, joining_date,
       NTILE(3) OVER (PARTITION BY dept_id ORDER BY joining_date) AS tenure_bucket
FROM stores.employees
ORDER BY dept_id, tenure_bucket
LIMIT 100;

/* Q97. */
WITH customer_spend AS (
  SELECT cust_id AS customer_id, SUM(net_total) AS total_spend
  FROM sales.orders
  GROUP BY cust_id
),
bucketed AS (
  SELECT customer_id, total_spend, NTILE(4) OVER (ORDER BY total_spend DESC) AS spend_quartile
  FROM customer_spend
)
SELECT customer_id, total_spend,
       ROW_NUMBER() OVER (ORDER BY total_spend DESC) AS rank_within_top_quartile
FROM bucketed
WHERE spend_quartile = 1
ORDER BY total_spend DESC
LIMIT 100;

/* Q98. */
WITH ranked AS (
  SELECT order_item_id, order_id, prod_id, net_amount,
         ROW_NUMBER() OVER (PARTITION BY order_id, prod_id ORDER BY net_amount DESC, order_item_id DESC) AS rn
  FROM sales.order_items
)
SELECT order_id, prod_id, order_item_id, net_amount
FROM ranked
WHERE rn = 1
LIMIT 200;

/* Q99. */
SELECT product_id, brand_id, (price - cost_price) AS margin,
       NTILE(4) OVER (PARTITION BY brand_id ORDER BY (price - cost_price)) AS margin_quartile
FROM products.products
ORDER BY brand_id, margin_quartile
LIMIT 100;

/* Q100. Restricted to a bounded sample of customers, since NTILE needs the whole partition materialized before any LIMIT applies, and a per-customer correlated triple-subquery over the unindexed 150,000-row orders table doesn't scale to all 50,000 customers on this practice database. */
WITH cust_metrics AS (
  SELECT c.customer_id,
         (SELECT MAX(order_date) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS last_order_date,
         (SELECT COUNT(*) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS order_count,
         (SELECT COALESCE(SUM(o.net_total),0) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS total_spend
  FROM customers.customers c
  WHERE c.customer_id <= 2000
)
SELECT customer_id,
       NTILE(4) OVER (ORDER BY last_order_date DESC NULLS LAST) AS recency_quartile,
       NTILE(4) OVER (ORDER BY order_count DESC) AS frequency_quartile,
       NTILE(4) OVER (ORDER BY total_spend DESC) AS monetary_quartile
FROM cust_metrics
LIMIT 200;

/* ============================================================
   END OF ANSWER KEY - Window Functions Part 1 - MEDIUM LEVEL (100/100)
============================================================ */
