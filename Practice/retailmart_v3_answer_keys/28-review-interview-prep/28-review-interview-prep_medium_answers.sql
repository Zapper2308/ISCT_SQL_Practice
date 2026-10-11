/* ============================================================
   ANSWER KEY - Review & Interview Prep (MEDIUM LEVEL)
   Curriculum:   RetailMart V3
   Database:     isct_retailmart
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL REVIEW (25)
   ------------------------------------------------------------ */
/* Q1. INNER JOIN sales.orders to customers.customers returns only orders that have a matching customer row - fine since cust_id is required. LEFT JOIN customers.customers to sales.orders keeps every customer even those with zero orders, producing NULLs on the order columns for them - needed for "all customers including non-buyers" reports. */

/* Q2. A LEFT JOIN produces NULL on the right side whenever the left row has no matching right row - e.g. LEFT JOIN customers.customers to sales.orders returns NULL order columns for a customer who has never placed an order. */

/* Q3. A regular subquery is evaluated once, independently of the outer query; a correlated subquery references a column from the outer query and conceptually re-evaluates once per outer row, so it cannot be planned as a single independent step. */

/* Q4. Window functions are computed after the WHERE clause has already filtered rows (WHERE runs in the logical order: FROM/JOIN -> WHERE -> GROUP BY -> HAVING -> window functions -> SELECT), so a window function's result does not exist yet when WHERE is evaluated - you must filter it in an outer query or a QUALIFY-style CTE wrapper instead. */

/* Q5. ROW_NUMBER never ties - every row gets a distinct number even with identical ORDER BY values (broken arbitrarily); RANK gives tied rows the same rank and skips the following rank number(s) (e.g. 1,1,3). */

/* Q6. PARTITION BY divides the rows into independent groups the window function is computed separately over (like GROUP BY but without collapsing rows); ORDER BY sets the sequence within each partition that functions like ROW_NUMBER, LAG, or a running SUM use. */

/* Q7. FILTER (WHERE cond) restricts which rows an aggregate function considers, letting you compute several differently-filtered aggregates (e.g. COUNT(*) FILTER (WHERE order_status='Delivered')) in a single GROUP BY pass instead of separate CASE-wrapped SUMs or multiple queries. */

/* Q8. PERCENTILE_CONT(0.5) (the median) is not pulled toward extreme values the way AVG is, so on skewed data (e.g. a few very high-value orders) it better represents the "typical" order than the mean does. */

/* Q9. EXISTS only checks for the presence of at least one matching row and short-circuits, and is NULL-safe; IN materializes/compares against the full subquery result list and, if that list contains a NULL, NOT IN can silently return zero rows due to three-valued logic - EXISTS/NOT EXISTS avoids that trap. */

/* Q10. Top-N-per-group uses a window function (ROW_NUMBER, RANK, or DENSE_RANK) PARTITION BY the group column ORDER BY the ranking metric DESC inside a CTE or subquery, then filters the outer query WHERE rn <= N. */

/* Q11. A LATERAL join lets a subquery in the FROM clause reference columns from preceding FROM items, effectively running once per outer row (like a correlated subquery) but usable in the FROM clause and able to return multiple rows/columns per outer row - useful for "top N rows per outer row" instead of a scalar correlated subquery. */

/* Q12. A materialized view's main limitation is staleness: it holds a physical snapshot that only reflects the base tables as of the last REFRESH, so it can return outdated results until explicitly refreshed, unlike a regular view which always queries live data. */

/* Q13. Wrapping an indexed column in a function (e.g. LOWER(email) or EXTRACT(YEAR FROM order_date)) means Postgres must apply that function to every row before it can compare - a plain B-tree index on the raw column cannot be used unless a matching expression/functional index exists on that exact expression. */

/* Q14. Postgres has no separate "clustered index" storage mode (the heap is unordered by default) - CLUSTER can physically reorder a table once according to an index but does not keep it maintained; a BRIN index instead stores min/max value ranges per block and relies on the table already being naturally correlated with its indexed column (e.g. an insert-ordered timestamp) to prune blocks cheaply. */

/* Q15. LEFT JOIN ... IS NULL and NOT EXISTS are both valid anti-join patterns; NOT EXISTS is generally preferred because it is NULL-safe and lets the planner short-circuit per row, while LEFT JOIN ... IS NULL can be less efficient on wide joins and gives wrong results if the join key itself can be NULL. */

/* Q16. Use UNION ALL when you know the two result sets cannot contain duplicates you need removed, or duplicates are acceptable/expected - it skips the sort/hash dedup pass UNION performs, so it is cheaper and preserves all rows including true duplicates. */

/* Q17. 1NF requires atomic column values and unique rows; 2NF additionally requires every non-key column to depend on the whole primary key (no partial dependency on part of a composite key); 3NF additionally requires no transitive dependency (non-key columns depend only on the key, not on other non-key columns). RetailMart's core normalized tables (orders, order_items, customers, products) are designed to 3NF, with denormalized dimension/summary tables (e.g. finance.revenue_summary) as intentional exceptions for reporting speed. */

/* Q18. A transaction is a group of operations executed as one atomic unit; ACID guarantees that an order's status update, payment record, and inventory decrement either all commit together or all roll back together, preventing a half-completed order (e.g. payment charged but inventory not decremented) if something fails mid-way. */

/* Q19. A large gap between EXPLAIN ANALYZE's "actual rows" and the planner's estimated "rows" means the planner's statistics are stale or the predicate is hard to estimate (e.g. correlated filters) - this misestimate often causes the planner to pick a bad join strategy or join order, and running ANALYZE on the table is the usual first fix. */

/* Q20. A hash join can appear even when the smaller table fits in memory because Postgres builds an in-memory hash table from the smaller ("build") side and probes it with the larger side - this is often cheaper than a nested loop or merge join regardless of table size, as long as the build side comfortably fits within work_mem. */

/* Q21. A "funnel" query counts distinct users reaching successive stages of a process (e.g. viewed -> ordered -> reordered); it is implemented with COUNT(DISTINCT customer_id) FILTER (WHERE stage_condition) in one pass, or successive CTEs/anti-joins that narrow the population at each stage, then computed as % of the previous (or first) stage's count. */

/* Q22. An RFM score rates a customer 1-5 on Recency (days since last order, more recent = higher score), Frequency (order count), and Monetary (total spend), typically via NTILE(5) on each metric computed from sales.orders GROUP BY cust_id, then combined into a 3-digit or composite score to segment customers. */

/* Q23. Cohort retention groups customers by their signup period (the cohort) and tracks, for each subsequent period, what % of that specific cohort remained active - unlike total active users (a single number per period mixing all cohorts), retention isolates how a specific starting group decays over time, which is what reveals product/engagement trends. */

/* Q24. IS DISTINCT FROM treats two NULLs as equal (NOT DISTINCT) and compares NULL vs a value as unequal (DISTINCT), giving a proper TRUE/FALSE result; <> (and =) returns NULL (UNKNOWN) whenever either side is NULL, which WHERE then treats as "not matched" - so <> silently drops rows involving NULL while IS DISTINCT FROM handles them explicitly. */

/* Q25. Two common automated data-quality checks on customers.customers: (1) duplicate-email detection - GROUP BY email HAVING COUNT(*) > 1 to catch accidental re-registrations; (2) NULL/malformed contact-field checks - % of rows with phone IS NULL or email NOT LIKE '%@%' to flag incomplete or invalid records. */

/* ============================================================
   SECTION B: JOINS, CTEs & SUBQUERIES (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT cat.category_name, SUM(oi.quantity * oi.unit_price) AS total_revenue
FROM sales.order_items oi
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
GROUP BY cat.category_name
ORDER BY total_revenue DESC
LIMIT 5;

/* Q27. */
SELECT c.customer_id, c.first_name, c.last_name
FROM customers.customers c
WHERE EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id)
  AND NOT EXISTS (SELECT 1 FROM customers.reviews r WHERE r.customer_id = c.customer_id);

/* Q28. */
SELECT DATE_TRUNC('month', order_date)::date AS order_month,
       SUM(net_total) AS total_net_total,
       COUNT(*) AS order_count,
       ROUND(AVG(net_total), 2) AS avg_net_total
FROM sales.orders
WHERE order_status = 'Delivered'
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY order_month;

/* Q29. */
WITH store_sales AS (
  SELECT s.store_id, s.store_name, r.region_name, SUM(o.net_total) AS total_sales
  FROM stores.stores s
  JOIN core.dim_region r ON r.region_id = s.region_id
  JOIN sales.orders o ON o.store_id = s.store_id
  GROUP BY s.store_id, s.store_name, r.region_name
)
SELECT store_id, region_name, total_sales,
       RANK() OVER (PARTITION BY region_name ORDER BY total_sales DESC) AS rank_in_region
FROM store_sales
ORDER BY region_name, rank_in_region;

/* Q30. */
SELECT DISTINCT p.product_id, p.product_name
FROM products.inventory inv
JOIN products.products p ON p.product_id = inv.product_id
WHERE NOT EXISTS (
  SELECT 1 FROM sales.order_items oi WHERE oi.prod_id = p.product_id
);

/* Q31. */
SELECT c.customer_id, c.first_name, c.last_name, c.email, SUM(o.net_total) AS total_spend
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
WHERE o.order_date >= DATE '2025-01-01' AND o.order_date < DATE '2026-01-01'
GROUP BY c.customer_id, c.first_name, c.last_name, c.email
ORDER BY total_spend DESC
LIMIT 1;

/* Q32. */
WITH cust_order_counts AS (
  SELECT cust_id, COUNT(*) AS order_count
  FROM sales.orders
  GROUP BY cust_id
)
SELECT cust_id, order_count
FROM cust_order_counts
WHERE order_count > (SELECT AVG(order_count) FROM cust_order_counts)
ORDER BY order_count DESC;

/* Q33. */
WITH review_counts AS (
  SELECT r.product_id, cat.category_id, cat.category_name, COUNT(*) AS review_count,
         ROW_NUMBER() OVER (PARTITION BY cat.category_id ORDER BY COUNT(*) DESC) AS rn
  FROM customers.reviews r
  JOIN products.products p ON p.product_id = r.product_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
  GROUP BY r.product_id, cat.category_id, cat.category_name
)
SELECT product_id, category_name, review_count
FROM review_counts
WHERE rn <= 3
ORDER BY category_name, rn;

/* Q34. */
SELECT customer_id, COUNT(*) AS open_ticket_count
FROM support.tickets
WHERE status IN ('Open', 'In Progress')
GROUP BY customer_id
HAVING COUNT(*) > 3
ORDER BY open_ticket_count DESC;

/* Q35. */
SELECT e.employee_id, e.first_name, e.last_name, d.dept_name, e.salary,
       ROUND(AVG(e.salary) OVER (PARTITION BY e.dept_id), 2) AS dept_avg_salary,
       CASE WHEN e.salary > AVG(e.salary) OVER (PARTITION BY e.dept_id) THEN 'Above Average'
            WHEN e.salary < AVG(e.salary) OVER (PARTITION BY e.dept_id) THEN 'Below Average'
            ELSE 'At Average' END AS salary_vs_dept_avg
FROM stores.employees e
JOIN core.dim_department d ON d.dept_id = e.dept_id
ORDER BY d.dept_name, e.salary DESC;

/* Q36. */
WITH monthly AS (
  SELECT DATE_TRUNC('month', o.order_date)::date AS order_month, SUM(o.net_total) AS total_revenue
  FROM sales.orders o
  GROUP BY DATE_TRUNC('month', o.order_date)
),
monthly_returns AS (
  SELECT DATE_TRUNC('month', return_date)::date AS return_month, SUM(refund_amount) AS total_returns
  FROM sales.returns
  GROUP BY DATE_TRUNC('month', return_date)
)
SELECT m.order_month, m.total_revenue, COALESCE(r.total_returns, 0) AS total_returns
FROM monthly m
LEFT JOIN monthly_returns r ON r.return_month = m.order_month
WHERE COALESCE(r.total_returns, 0) > m.total_revenue * 1.05
ORDER BY m.order_month;

/* Q37. */
SELECT campaign_id,
       ROUND(SUM(emails_clicked)::numeric / NULLIF(SUM(emails_sent), 0), 4) AS click_through_rate
FROM marketing.email_clicks
GROUP BY campaign_id
ORDER BY click_through_rate DESC NULLS LAST
LIMIT 1;

/* Q38. */
WITH top_customers AS (
  SELECT cust_id
  FROM sales.orders
  GROUP BY cust_id
  ORDER BY SUM(net_total) DESC
  LIMIT 100
)
SELECT tc.cust_id, o.order_id, o.order_date, o.net_total
FROM top_customers tc
JOIN LATERAL (
  SELECT order_id, order_date, net_total
  FROM sales.orders o
  WHERE o.cust_id = tc.cust_id
  ORDER BY o.order_date DESC
  LIMIT 2
) o ON TRUE
ORDER BY tc.cust_id, o.order_date DESC;

/* Q39. */
SELECT a1.city, a1.address_line, a1.customer_id AS customer_1, a2.customer_id AS customer_2
FROM customers.addresses a1
JOIN customers.addresses a2
  ON a1.city = a2.city AND a1.address_line = a2.address_line AND a1.customer_id < a2.customer_id
ORDER BY a1.city, a1.address_line;

/* Q40. */
WITH store_orders AS (
  SELECT store_id, COUNT(*) AS total_orders, SUM(net_total) AS total_revenue,
         COUNT(DISTINCT cust_id) AS distinct_customers
  FROM sales.orders
  GROUP BY store_id
),
store_returns AS (
  SELECT o.store_id, COUNT(*) AS return_count
  FROM sales.returns r
  JOIN sales.orders o ON o.order_id = r.order_id
  GROUP BY o.store_id
)
SELECT so.store_id, so.total_orders, so.total_revenue, so.distinct_customers,
       ROUND(COALESCE(sr.return_count, 0)::numeric / NULLIF(so.total_orders, 0), 4) AS return_rate
FROM store_orders so
LEFT JOIN store_returns sr ON sr.store_id = so.store_id
ORDER BY so.store_id;

/* Q41. */
SELECT DISTINCT p.product_id, p.product_name
FROM products.products p
WHERE EXISTS (
  SELECT 1
  FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  JOIN customers.customers c ON c.customer_id = o.cust_id
  WHERE oi.prod_id = p.product_id AND c.tier = 'Gold'
);

/* Q42. -- sales.orders.cust_id has no index, so a true per-row correlated subquery against the raw 150k-row table (MIN(order_date) WHERE cust_id = c.customer_id) is extremely slow over 50k customers; correlating instead against a pre-aggregated CTE greatly cuts the per-row cost and still demonstrates the correlated-subquery-in-SELECT technique. LIMIT 500 caps runtime for this demo; remove it to run against all customers. */
WITH first_orders AS (
  SELECT cust_id, MIN(order_date) AS first_order_date
  FROM sales.orders
  GROUP BY cust_id
)
SELECT c.customer_id, c.first_name, c.last_name,
       (SELECT fo.first_order_date FROM first_orders fo WHERE fo.cust_id = c.customer_id) AS first_order_date
FROM customers.customers c
ORDER BY c.customer_id
LIMIT 500;

/* Q43. */
SELECT o.order_id, o.order_date, sh.shipment_id, sh.delivered_date
FROM sales.orders o
JOIN sales.shipments sh ON sh.order_id = o.order_id
WHERE sh.delivered_date < o.order_date;

/* Q44. */
WITH product_revenue AS (
  SELECT p.product_id, cat.category_id, cat.category_name,
         SUM(oi.quantity * oi.unit_price) AS product_revenue
  FROM sales.order_items oi
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
  GROUP BY p.product_id, cat.category_id, cat.category_name
),
category_revenue AS (
  SELECT category_id, SUM(product_revenue) AS category_total
  FROM product_revenue
  GROUP BY category_id
)
SELECT pr.product_id, pr.category_name, pr.product_revenue,
       ROUND(100.0 * pr.product_revenue / NULLIF(cr.category_total, 0), 2) AS pct_of_category_revenue
FROM product_revenue pr
JOIN category_revenue cr ON cr.category_id = pr.category_id
ORDER BY pr.category_name, pct_of_category_revenue DESC;

/* Q45. -- stores.employees has no manager_id column (no self-referencing hierarchy exists in the schema), so a literal manager self-join cannot be written. Conceptual answer: without a manager_id FK, "direct manager" comparisons are not derivable from the current schema; the closest achievable proxy is comparing an employee's salary to the average salary of employees with role = 'Store Manager' or 'Regional Manager' in the same store, but that is a role-based approximation, not a true reporting-line comparison, and would need a manager_id (or a reports_to) column added to stores.employees to answer this correctly. */

/* Q46. */
WITH monthly AS (
  SELECT DATE_TRUNC('month', order_date)::date AS order_month, SUM(net_total) AS total_revenue
  FROM sales.orders
  GROUP BY DATE_TRUNC('month', order_date)
)
SELECT order_month, total_revenue,
       SUM(total_revenue) OVER (ORDER BY order_month) AS cumulative_revenue
FROM monthly
ORDER BY order_month;

/* Q47. */
SELECT b.brand_id, b.brand_name
FROM core.dim_brand b
WHERE NOT EXISTS (
  SELECT 1 FROM products.products p WHERE p.brand_id = b.brand_id AND p.price > 10000
);

/* Q48. */
SELECT TRIM(TO_CHAR(order_date, 'Day')) AS day_of_week, ROUND(AVG(net_total), 2) AS avg_net_total
FROM sales.orders
GROUP BY TRIM(TO_CHAR(order_date, 'Day')), EXTRACT(ISODOW FROM order_date)
ORDER BY avg_net_total DESC
LIMIT 1;

/* Q49. */
SELECT cust_id
FROM sales.orders
WHERE order_date >= DATE '2025-01-01' AND order_date < DATE '2025-03-01'
GROUP BY cust_id
HAVING COUNT(DISTINCT DATE_TRUNC('month', order_date)) = 2;

/* Q50. */
SELECT s.warehouse_id, SUM(s.quantity_on_hand * p.price) AS inventory_value
FROM supply_chain.inventory_snapshots s
JOIN products.products p ON p.product_id = s.product_id
GROUP BY s.warehouse_id
ORDER BY inventory_value DESC;

/* ============================================================
   SECTION C: WINDOW FUNCTIONS & ANALYTICS (25)
   ------------------------------------------------------------ */
/* Q51. */
WITH monthly AS (
  SELECT DATE_TRUNC('month', order_date)::date AS order_month, SUM(net_total) AS total_revenue
  FROM sales.orders
  GROUP BY DATE_TRUNC('month', order_date)
)
SELECT order_month, total_revenue,
       ROUND(100.0 * (total_revenue - LAG(total_revenue) OVER (ORDER BY order_month))
             / NULLIF(LAG(total_revenue) OVER (ORDER BY order_month), 0), 2) AS mom_growth_pct
FROM monthly
ORDER BY order_month;

/* Q52. */
SELECT DISTINCT cust_id,
       FIRST_VALUE(order_id) OVER (PARTITION BY cust_id ORDER BY net_total DESC) AS highest_value_order_id,
       FIRST_VALUE(net_total) OVER (PARTITION BY cust_id ORDER BY net_total DESC) AS highest_net_total
FROM sales.orders
ORDER BY cust_id;

/* Q53. */
WITH daily AS (
  SELECT order_date, COUNT(*) AS order_count
  FROM sales.orders
  GROUP BY order_date
)
SELECT order_date, order_count,
       ROUND(AVG(order_count) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) AS rolling_7d_avg
FROM daily
ORDER BY order_date;

/* Q54. */
WITH units AS (
  SELECT p.product_id, p.product_name, cat.category_id, cat.category_name, SUM(oi.quantity) AS total_units
  FROM sales.order_items oi
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
  GROUP BY p.product_id, p.product_name, cat.category_id, cat.category_name
),
ranked AS (
  SELECT *, DENSE_RANK() OVER (PARTITION BY category_id ORDER BY total_units DESC) AS rnk
  FROM units
)
SELECT category_name, product_name, total_units, rnk
FROM ranked
WHERE rnk <= 3
ORDER BY category_name, rnk;

/* Q55. */
WITH cust_spend AS (
  SELECT cust_id, SUM(net_total) AS total_spend
  FROM sales.orders
  GROUP BY cust_id
)
SELECT cust_id, total_spend, NTILE(5) OVER (ORDER BY total_spend) AS spend_group
FROM cust_spend
ORDER BY spend_group, total_spend;

/* Q56. */
SELECT store_id,
       ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY net_total)::numeric, 2) AS p90_order_value
FROM sales.orders
GROUP BY store_id
ORDER BY store_id;

/* Q57. */
SELECT order_id, cust_id, order_date, net_total,
       LAG(net_total) OVER (PARTITION BY cust_id ORDER BY order_date) AS prev_net_total,
       net_total - LAG(net_total) OVER (PARTITION BY cust_id ORDER BY order_date) AS diff_from_prev
FROM sales.orders
ORDER BY cust_id, order_date;

/* Q58. */
SELECT store_id,
       COUNT(*) FILTER (WHERE TRUE) AS total_orders,
       COUNT(*) FILTER (WHERE order_status = 'Delivered') AS delivered_orders,
       COUNT(*) FILTER (WHERE order_status = 'Returned') AS returned_orders
FROM sales.orders
GROUP BY store_id
ORDER BY store_id;

/* Q59. */
SELECT EXTRACT(YEAR FROM order_date)::int AS order_year,
       COUNT(*) FILTER (WHERE order_status = 'Delivered') AS delivered_count,
       COUNT(*) FILTER (WHERE order_status = 'Returned') AS returned_count,
       COUNT(*) FILTER (WHERE order_status = 'Cancelled') AS cancelled_count
FROM sales.orders
GROUP BY EXTRACT(YEAR FROM order_date)
ORDER BY order_year;

/* Q60. */
SELECT store_id, order_date, net_total,
       SUM(net_total) OVER (PARTITION BY store_id ORDER BY order_date
                             ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS rolling_30d_sum
FROM sales.orders
ORDER BY store_id, order_date;

/* Q61. */
WITH price_events AS (
  SELECT record_id AS product_id, old_value::numeric AS old_price, new_value::numeric AS new_price, changed_at,
         LAG(new_value::numeric) OVER (PARTITION BY record_id ORDER BY changed_at) AS prev_new_price
  FROM audit.record_changes
  WHERE table_name = 'products' AND column_name = 'price'
)
SELECT product_id, changed_at, old_price, new_price,
       new_price - old_price AS price_change
FROM price_events
ORDER BY (new_price - old_price) DESC
LIMIT 1;

/* Q62. */
WITH last_order AS (
  SELECT cust_id, MAX(order_date) AS last_order_date
  FROM sales.orders
  GROUP BY cust_id
)
SELECT cust_id, last_order_date,
       (SELECT MAX(order_date) FROM sales.orders) - last_order_date AS days_since_last_order
FROM last_order
ORDER BY days_since_last_order DESC;

/* Q63. */
SELECT employee_id, dept_id, salary,
       RANK() OVER (PARTITION BY dept_id ORDER BY salary DESC) AS salary_rank_in_dept,
       NTILE(5) OVER (PARTITION BY dept_id ORDER BY salary) AS salary_quintile,
       CASE WHEN NTILE(5) OVER (PARTITION BY dept_id ORDER BY salary) = 1 THEN TRUE ELSE FALSE END AS bottom_20_pct
FROM stores.employees
ORDER BY dept_id, salary_rank_in_dept;

/* Q64. */
SELECT p.product_id, p.product_name, b.brand_id, p.price,
       ROUND(PERCENT_RANK() OVER (PARTITION BY b.brand_id ORDER BY p.price)::numeric, 4) AS price_percent_rank
FROM products.products p
JOIN core.dim_brand b ON b.brand_id = p.brand_id
ORDER BY b.brand_id, price_percent_rank;

/* Q65. -- COUNT(DISTINCT ...) is not supported as a window function in Postgres; a "running count of distinct customers ever ordered" is computed instead as a cumulative SUM of first-time customers per month (each customer counted exactly once, in their first order month). */
WITH first_order_month AS (
  SELECT cust_id, MIN(DATE_TRUNC('month', order_date))::date AS first_month
  FROM sales.orders
  GROUP BY cust_id
),
monthly_new AS (
  SELECT first_month, COUNT(*) AS new_customers
  FROM first_order_month
  GROUP BY first_month
)
SELECT first_month AS order_month, new_customers,
       SUM(new_customers) OVER (ORDER BY first_month) AS running_distinct_customers
FROM monthly_new
ORDER BY first_month;

/* Q66. */
SELECT customer_id, view_timestamp,
       EXTRACT(EPOCH FROM (view_timestamp - LAG(view_timestamp) OVER (PARTITION BY customer_id ORDER BY view_timestamp))) AS gap_seconds
FROM web_events.page_views
WHERE customer_id IS NOT NULL
ORDER BY customer_id, view_timestamp;

/* Q67. */
SELECT call_id, agent_id, call_start_time, call_duration_seconds,
       LEAD(call_duration_seconds) OVER (PARTITION BY agent_id ORDER BY call_start_time) AS next_call_duration,
       CASE
         WHEN LEAD(call_duration_seconds) OVER (PARTITION BY agent_id ORDER BY call_start_time) > call_duration_seconds THEN 'Longer'
         WHEN LEAD(call_duration_seconds) OVER (PARTITION BY agent_id ORDER BY call_start_time) < call_duration_seconds THEN 'Shorter'
         WHEN LEAD(call_duration_seconds) OVER (PARTITION BY agent_id ORDER BY call_start_time) IS NULL THEN NULL
         ELSE 'Same'
       END AS next_call_comparison
FROM call_center.calls
ORDER BY agent_id, call_start_time;

/* Q68. */
SELECT view_timestamp::date AS view_date, COUNT(DISTINCT customer_id) AS dau
FROM web_events.page_views
WHERE customer_id IS NOT NULL
GROUP BY view_timestamp::date
ORDER BY view_date;

/* Q69. */
WITH dau AS (
  SELECT DATE_TRUNC('month', view_timestamp)::date AS month, view_timestamp::date AS day, COUNT(DISTINCT customer_id) AS daily_active
  FROM web_events.page_views
  WHERE customer_id IS NOT NULL
  GROUP BY DATE_TRUNC('month', view_timestamp), view_timestamp::date
),
mau AS (
  SELECT DATE_TRUNC('month', view_timestamp)::date AS month, COUNT(DISTINCT customer_id) AS monthly_active
  FROM web_events.page_views
  WHERE customer_id IS NOT NULL
  GROUP BY DATE_TRUNC('month', view_timestamp)
)
SELECT d.month, ROUND(AVG(d.daily_active), 2) AS avg_dau, m.monthly_active AS mau,
       ROUND(AVG(d.daily_active) / NULLIF(m.monthly_active, 0), 4) AS stickiness_ratio
FROM dau d
JOIN mau m ON m.month = d.month
GROUP BY d.month, m.monthly_active
ORDER BY d.month;

/* Q70. */
SELECT dept_id, ROUND(AVG(salary), 2) AS dept_avg_salary,
       ROUND((SELECT AVG(salary) FROM stores.employees), 2) AS company_avg_salary
FROM stores.employees
GROUP BY dept_id
ORDER BY dept_id;

/* Q71. */
SELECT cat.category_name,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY p.price)::numeric, 2) AS median_price,
       ROUND(AVG(p.price), 2) AS avg_price
FROM products.products p
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
GROUP BY cat.category_name
ORDER BY cat.category_name;

/* Q72. */
WITH monthly AS (
  SELECT DATE_TRUNC('month', order_date)::date AS order_month, SUM(net_total) AS revenue
  FROM sales.orders
  GROUP BY DATE_TRUNC('month', order_date)
)
SELECT order_month, revenue,
       LAG(revenue, 3) OVER (ORDER BY order_month) AS revenue_3mo_ago,
       ROUND(100.0 * (revenue - LAG(revenue, 3) OVER (ORDER BY order_month))
             / NULLIF(LAG(revenue, 3) OVER (ORDER BY order_month), 0), 2) AS qoq_growth_pct
FROM monthly
ORDER BY order_month;

/* Q73. */
WITH cat_ratings AS (
  SELECT cat.category_id, cat.category_name, p.product_id, p.product_name,
         ROUND(AVG(r.rating), 2) AS avg_rating
  FROM customers.reviews r
  JOIN products.products p ON p.product_id = r.product_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
  GROUP BY cat.category_id, cat.category_name, p.product_id, p.product_name
)
SELECT DISTINCT category_name,
       FIRST_VALUE(product_name) OVER (PARTITION BY category_id ORDER BY avg_rating DESC) AS top_rated_product,
       FIRST_VALUE(product_name) OVER (PARTITION BY category_id ORDER BY avg_rating ASC) AS bottom_rated_product
FROM cat_ratings
ORDER BY category_name;

/* Q74. -- products.inventory is per-store (no reorder cadence/lead-time column), so "days to next reorder" is approximated as remaining_days = (quantity_on_hand - reorder_level) / avg_daily_units_sold for that product across all stores. */
WITH daily_sales AS (
  SELECT oi.prod_id, SUM(oi.quantity)::numeric / NULLIF((SELECT MAX(order_date) - MIN(order_date) FROM sales.orders), 0) AS avg_daily_sold
  FROM sales.order_items oi
  GROUP BY oi.prod_id
),
inv AS (
  SELECT product_id, SUM(quantity_on_hand) AS total_qty, SUM(reorder_level) AS total_reorder_level
  FROM products.inventory
  GROUP BY product_id
)
SELECT i.product_id, i.total_qty, i.total_reorder_level, ds.avg_daily_sold,
       ROUND((i.total_qty - i.total_reorder_level) / NULLIF(ds.avg_daily_sold, 0), 1) AS days_until_reorder
FROM inv i
LEFT JOIN daily_sales ds ON ds.prod_id = i.product_id
ORDER BY days_until_reorder NULLS LAST;

/* Q75. */
WITH yearly AS (
  SELECT EXTRACT(YEAR FROM order_date)::int AS order_year, SUM(net_total) AS revenue
  FROM sales.orders
  GROUP BY EXTRACT(YEAR FROM order_date)
),
bounds AS (
  SELECT MIN(order_year) AS first_year, MAX(order_year) AS last_year FROM yearly
)
SELECT
  ROUND(
    (POWER(
      (SELECT revenue FROM yearly y JOIN bounds b ON y.order_year = b.last_year)
      / NULLIF((SELECT revenue FROM yearly y JOIN bounds b ON y.order_year = b.first_year), 0),
      1.0 / NULLIF((SELECT last_year - first_year FROM bounds), 0)
    ) - 1) * 100, 2
  ) AS cagr_pct
FROM bounds;

/* ============================================================
   SECTION D: MIXED INTERVIEW PATTERNS (25)
   ------------------------------------------------------------ */
/* Q76. */
WITH cat_revenue AS (
  SELECT cat.category_name, p.product_id, p.product_name,
         SUM(oi.quantity * oi.unit_price) AS revenue,
         ROW_NUMBER() OVER (PARTITION BY cat.category_id ORDER BY SUM(oi.quantity * oi.unit_price) DESC) AS rn
  FROM sales.order_items oi
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
  GROUP BY cat.category_name, cat.category_id, p.product_id, p.product_name
)
SELECT category_name, product_name, revenue
FROM cat_revenue
WHERE rn <= 3
ORDER BY category_name, rn;

/* Q77. */
WITH ranked AS (
  SELECT customer_id, first_name, last_name, email, registration_date,
         ROW_NUMBER() OVER (PARTITION BY email ORDER BY registration_date DESC) AS rn
  FROM customers.customers
)
SELECT customer_id, first_name, last_name, email, registration_date
FROM ranked
WHERE rn = 1
ORDER BY email;

/* Q78. */
WITH item_sums AS (
  SELECT order_id, SUM(unit_price * quantity) AS item_total
  FROM sales.order_items
  GROUP BY order_id
)
SELECT o.order_id, o.net_total, i.item_total, o.net_total - i.item_total AS mismatch_amount
FROM sales.orders o
JOIN item_sums i ON i.order_id = o.order_id
WHERE ABS(o.net_total - i.item_total) > 0.01
ORDER BY ABS(o.net_total - i.item_total) DESC;

/* Q79. */
WITH viewers AS (
  SELECT DISTINCT customer_id FROM web_events.page_views WHERE customer_id IS NOT NULL
),
first_order AS (
  SELECT cust_id, COUNT(*) AS order_count FROM sales.orders GROUP BY cust_id
),
funnel AS (
  SELECT
    (SELECT COUNT(*) FROM viewers) AS step1_viewed,
    (SELECT COUNT(*) FROM viewers v JOIN first_order o ON o.cust_id = v.customer_id) AS step2_ordered,
    (SELECT COUNT(*) FROM viewers v JOIN first_order o ON o.cust_id = v.customer_id WHERE o.order_count >= 2) AS step3_reordered
)
SELECT step1_viewed, step2_ordered, step3_reordered,
       ROUND(100.0 * step2_ordered / NULLIF(step1_viewed, 0), 2) AS pct_viewed_to_ordered,
       ROUND(100.0 * step3_reordered / NULLIF(step2_ordered, 0), 2) AS pct_ordered_to_reordered
FROM funnel;

/* Q80. */
SELECT DISTINCT c.customer_id, c.first_name, c.last_name
FROM customers.customers c
WHERE EXISTS (
  SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id AND o.order_status = 'Returned'
);

/* Q81. */
SELECT
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total)::numeric, 2) AS median_net_total,
  ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY net_total)::numeric, 2) AS p90_net_total,
  ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY net_total)::numeric, 2) AS p95_net_total
FROM sales.orders;

/* Q82. -- sales.payments.payment_mode values are Cash/UPI/Credit Card/Debit Card/Net Banking/Wallet/EMI/Gift Card/Buy Now Pay Later (no literal 'COD'); pivoting on the four highest-volume modes as the closest match to UPI/Card/COD/Wallet, treating Cash as the COD proxy and combining both card types into "Card". */
SELECT DATE_TRUNC('month', payment_date)::date AS pay_month,
       SUM(amount) FILTER (WHERE payment_mode = 'UPI') AS upi_revenue,
       SUM(amount) FILTER (WHERE payment_mode IN ('Credit Card', 'Debit Card')) AS card_revenue,
       SUM(amount) FILTER (WHERE payment_mode = 'Cash') AS cod_cash_revenue,
       SUM(amount) FILTER (WHERE payment_mode = 'Wallet') AS wallet_revenue
FROM sales.payments
GROUP BY DATE_TRUNC('month', payment_date)
ORDER BY pay_month;

/* Q83. If a Seq Scan shows 50,000 rows scanned but only 10 rows match the filter, the table lacks a useful index on the filtered column(s) - you would add a B-tree index on that column (or a partial index if the filter targets a small, well-defined subset) so the planner can switch to an Index Scan / Bitmap Index Scan instead of reading every row. */

/* Q84. */
WITH stats AS (
  SELECT COUNT(*) AS total_rows,
         COUNT(*) FILTER (WHERE phone IS NULL) AS null_phone_count,
         COUNT(*) - COUNT(DISTINCT email) AS duplicate_email_rows
  FROM customers.customers
)
SELECT total_rows,
       ROUND(100.0 * null_phone_count / NULLIF(total_rows, 0), 2) AS pct_null_phone,
       ROUND(100.0 * duplicate_email_rows / NULLIF(total_rows, 0), 2) AS pct_duplicate_email
FROM stats;

/* Q85. */
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
       COUNT(DISTINCT a.customer_id) AS retained_customers,
       ROUND(100.0 * COUNT(DISTINCT a.customer_id) / NULLIF(cs.cohort_size, 0), 2) AS retention_pct
FROM activity a
JOIN cohort_size cs ON cs.signup_month = a.signup_month
WHERE a.period_index BETWEEN 0 AND 3
GROUP BY a.signup_month, a.period_index, cs.cohort_size
ORDER BY a.signup_month, a.period_index;

/* Q86. */
WITH raw AS (
  SELECT cust_id,
         (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS recency_days,
         COUNT(*) AS frequency,
         SUM(net_total) AS monetary
  FROM sales.orders
  GROUP BY cust_id
)
SELECT cust_id, recency_days, frequency, monetary,
       NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
       NTILE(5) OVER (ORDER BY frequency) AS f_score,
       NTILE(5) OVER (ORDER BY monetary) AS m_score
FROM raw
ORDER BY cust_id;

/* Q87. */
SELECT inv.store_id, inv.product_id, inv.quantity_on_hand
FROM products.inventory inv
WHERE inv.quantity_on_hand > 0
  AND NOT EXISTS (
    SELECT 1 FROM sales.order_items oi
    JOIN sales.orders o ON o.order_id = oi.order_id
    WHERE oi.prod_id = inv.product_id AND o.store_id = inv.store_id
      AND o.order_date >= (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '90 days'
  );

/* Q88. */
WITH monthly AS (
  SELECT EXTRACT(YEAR FROM order_date)::int AS yr, EXTRACT(MONTH FROM order_date)::int AS mo,
         SUM(net_total) AS revenue
  FROM sales.orders
  GROUP BY EXTRACT(YEAR FROM order_date), EXTRACT(MONTH FROM order_date)
)
SELECT yr, mo, revenue,
       LAG(revenue) OVER (ORDER BY yr, mo) AS prev_month_revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY yr, mo))
             / NULLIF(LAG(revenue) OVER (ORDER BY yr, mo), 0), 2) AS growth_pct
FROM monthly
ORDER BY yr, mo;

/* Q89. */
WITH raw AS (
  SELECT cust_id,
         (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS recency_days,
         COUNT(*) AS frequency,
         SUM(net_total) AS monetary
  FROM sales.orders
  GROUP BY cust_id
),
scored AS (
  SELECT cust_id,
         NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
         NTILE(5) OVER (ORDER BY frequency) AS f_score,
         NTILE(5) OVER (ORDER BY monetary) AS m_score
  FROM raw
)
SELECT cust_id, r_score, f_score, m_score
FROM scored
WHERE r_score = 5 AND f_score = 5 AND m_score = 5;

/* Q90. */
WITH store_rev AS (
  SELECT s.store_id, r.region_id, r.region_name, SUM(o.net_total) AS store_revenue
  FROM stores.stores s
  JOIN core.dim_region r ON r.region_id = s.region_id
  JOIN sales.orders o ON o.store_id = s.store_id
  GROUP BY s.store_id, r.region_id, r.region_name
),
region_rev AS (
  SELECT region_id, SUM(store_revenue) AS region_revenue
  FROM store_rev
  GROUP BY region_id
)
SELECT sr.store_id, sr.region_name, sr.store_revenue,
       ROUND(100.0 * sr.store_revenue / NULLIF(rr.region_revenue, 0), 2) AS pct_of_region_revenue
FROM store_rev sr
JOIN region_rev rr ON rr.region_id = sr.region_id
ORDER BY sr.region_name, pct_of_region_revenue DESC;

/* Q91. */
WITH monthly_reviews AS (
  SELECT product_id, DATE_TRUNC('month', review_date)::date AS review_month, COUNT(*) AS review_count
  FROM customers.reviews
  GROUP BY product_id, DATE_TRUNC('month', review_date)
),
bounds AS (
  SELECT MAX(review_date) AS max_date FROM customers.reviews
),
recent AS (
  SELECT mr.product_id, SUM(mr.review_count) AS recent_count
  FROM monthly_reviews mr, bounds b
  WHERE mr.review_month >= DATE_TRUNC('month', b.max_date) - INTERVAL '3 months'
  GROUP BY mr.product_id
),
prior AS (
  SELECT mr.product_id, SUM(mr.review_count) AS prior_count
  FROM monthly_reviews mr, bounds b
  WHERE mr.review_month >= DATE_TRUNC('month', b.max_date) - INTERVAL '6 months'
    AND mr.review_month < DATE_TRUNC('month', b.max_date) - INTERVAL '3 months'
  GROUP BY mr.product_id
)
SELECT COALESCE(r.product_id, p.product_id) AS product_id,
       COALESCE(r.recent_count, 0) AS recent_count,
       COALESCE(p.prior_count, 0) AS prior_count,
       ROUND(100.0 * (COALESCE(r.recent_count, 0) - COALESCE(p.prior_count, 0)) / NULLIF(p.prior_count, 0), 2) AS pct_change
FROM recent r
FULL OUTER JOIN prior p ON p.product_id = r.product_id
WHERE COALESCE(p.prior_count, 0) > 0
  AND (COALESCE(r.recent_count, 0) - COALESCE(p.prior_count, 0)) < -0.2 * p.prior_count
ORDER BY pct_change;

/* Q92. */
WITH daily_orders AS (
  SELECT order_date, COUNT(*) AS order_count, SUM(net_total) AS revenue
  FROM sales.orders
  GROUP BY order_date
),
monthly_totals AS (
  SELECT DATE_TRUNC('month', order_date)::date AS order_month,
         SUM(order_count) AS monthly_orders, SUM(revenue) AS monthly_revenue
  FROM daily_orders
  GROUP BY DATE_TRUNC('month', order_date)
),
yoy_growth AS (
  SELECT order_month, monthly_revenue,
         LAG(monthly_revenue, 12) OVER (ORDER BY order_month) AS revenue_last_year,
         ROUND(100.0 * (monthly_revenue - LAG(monthly_revenue, 12) OVER (ORDER BY order_month))
               / NULLIF(LAG(monthly_revenue, 12) OVER (ORDER BY order_month), 0), 2) AS yoy_growth_pct
  FROM monthly_totals
)
SELECT * FROM yoy_growth ORDER BY order_month;

/* Q93. */
SELECT o1.cust_id
FROM sales.orders o1
WHERE EXTRACT(YEAR FROM o1.order_date) = 2024
  AND EXISTS (
    SELECT 1 FROM sales.orders o2
    WHERE o2.cust_id = o1.cust_id AND EXTRACT(YEAR FROM o2.order_date) = 2025
  )
GROUP BY o1.cust_id;

/* Q94. */
SELECT record_id AS product_id, old_value::numeric AS old_price, new_value::numeric AS new_price,
       ROUND(100.0 * (new_value::numeric - old_value::numeric) / NULLIF(old_value::numeric, 0), 2) AS pct_change,
       changed_at
FROM audit.record_changes
WHERE table_name = 'products' AND column_name = 'price'
  AND ABS(new_value::numeric - old_value::numeric) > 0.5 * old_value::numeric
ORDER BY pct_change DESC;

/* Q95. Columns on sales.orders with low cardinality and no selective filtering benefit - like order_status (only 7 distinct values spread over 150k rows) - gain little from a plain B-tree index, since a query for one status still matches a large fraction of the table and the planner will prefer a Seq Scan; a B-tree also does not help columns only ever used inside a function/expression (e.g. EXTRACT(YEAR FROM order_date)) unless a matching expression index exists. */

/* Q96. */
WITH cohorts AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month
  FROM customers.customers
),
cust_spend AS (
  SELECT c.signup_month, o.cust_id, SUM(o.net_total) AS total_spend
  FROM cohorts c
  JOIN sales.orders o ON o.cust_id = c.customer_id
  GROUP BY c.signup_month, o.cust_id
)
SELECT signup_month, ROUND(AVG(total_spend), 2) AS avg_clv
FROM cust_spend
GROUP BY signup_month
ORDER BY signup_month;

/* Q97. */
SELECT shipment_id, order_id, shipped_date, delivered_date
FROM sales.shipments
WHERE delivered_date < shipped_date;

/* Q98. */
(
  SELECT cust_id, COUNT(*) AS order_count, NULL::numeric AS total_spend, 'top_by_count' AS source
  FROM sales.orders
  GROUP BY cust_id
  ORDER BY order_count DESC
  LIMIT 10
)
UNION
(
  SELECT cust_id, NULL::bigint AS order_count, SUM(net_total) AS total_spend, 'top_by_spend' AS source
  FROM sales.orders
  GROUP BY cust_id
  ORDER BY total_spend DESC
  LIMIT 10
);

/* Q99. LEFT JOIN + IS NULL keeps every left row and matches it to the right table; rows with no right-side match come back with all right-side columns NULL, so filtering WHERE right.key IS NULL isolates exactly the left rows that have no match - which is precisely what "does not exist" means. NOT EXISTS expresses that same intent directly via a correlated subquery, without materializing the join. Both forms below return products never ordered: */
SELECT p.product_id, p.product_name
FROM products.products p
LEFT JOIN sales.order_items oi ON oi.prod_id = p.product_id
WHERE oi.order_item_id IS NULL;

SELECT p.product_id, p.product_name
FROM products.products p
WHERE NOT EXISTS (SELECT 1 FROM sales.order_items oi WHERE oi.prod_id = p.product_id);

/* Q100. */
WITH cat_revenue AS (
  SELECT cat.category_id, cat.category_name, SUM(oi.quantity * oi.unit_price) AS total_revenue
  FROM sales.order_items oi
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
  GROUP BY cat.category_id, cat.category_name
),
overall AS (
  SELECT SUM(total_revenue) AS grand_total FROM cat_revenue
),
latest_month AS (
  SELECT DATE_TRUNC('month', o.order_date)::date AS mth, cat.category_id,
         SUM(oi.quantity * oi.unit_price) AS month_revenue
  FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
  GROUP BY DATE_TRUNC('month', o.order_date), cat.category_id
),
ranked_months AS (
  SELECT *, RANK() OVER (PARTITION BY category_id ORDER BY mth DESC) AS month_rank
  FROM latest_month
)
SELECT cr.category_name, cr.total_revenue,
       RANK() OVER (ORDER BY cr.total_revenue DESC) AS revenue_rank,
       ROUND(100.0 * cr.total_revenue / NULLIF(o.grand_total, 0), 2) AS pct_of_overall,
       cur.month_revenue AS latest_month_revenue, prev.month_revenue AS prior_month_revenue,
       ROUND(100.0 * (cur.month_revenue - prev.month_revenue) / NULLIF(prev.month_revenue, 0), 2) AS mom_growth_pct
FROM cat_revenue cr
CROSS JOIN overall o
LEFT JOIN ranked_months cur ON cur.category_id = cr.category_id AND cur.month_rank = 1
LEFT JOIN ranked_months prev ON prev.category_id = cr.category_id AND prev.month_rank = 2
ORDER BY revenue_rank;
