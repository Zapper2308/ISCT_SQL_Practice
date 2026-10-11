/* ============================================================
   ANSWER KEY - Review & Interview Prep (EASY LEVEL)
   Curriculum:   RetailMart V3
   Database:     isct_retailmart
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL REVIEW (25)
   ------------------------------------------------------------ */
/* Q1. WHERE filters individual rows before grouping/aggregation; HAVING filters groups after GROUP BY has produced aggregate values. WHERE cannot reference aggregate functions, HAVING can. */

/* Q2. Use LEFT JOIN when you need to keep every row from the left table even if there is no match on the right (e.g. all customers, including those with zero orders). Use INNER JOIN when a row is only meaningful if a match exists on both sides. */

/* Q3. GROUP BY collapses rows sharing the same value(s) in the grouping columns into a single output row per group, so any other selected column must be an aggregate or appear in the GROUP BY list. */

/* Q4. COUNT(*) counts all rows in the group including NULLs; COUNT(col) counts only rows where col is NOT NULL. */

/* Q5. DISTINCT removes duplicate rows from the result set based on all selected columns; GROUP BY also collapses rows but is designed to be paired with aggregate functions over each group, not just dedup the output. */

/* Q6. Without LIMIT, ORDER BY still has to sort the entire result set before returning it, which is O(n log n) work and can require a full table scan plus an expensive sort/spill to disk on large tables - it does not let Postgres stop early. */

/* Q7. A primary key uniquely identifies each row in a table and guarantees uniqueness and NOT NULL on the key column(s); Postgres also automatically builds a unique B-tree index on it. */

/* Q8. A foreign key enforces referential integrity: every value in the child column must exist in the referenced parent table's key column (or be NULL), preventing orphaned rows. */

/* Q9. NULL represents an unknown or missing value - it is not equal to anything, including another NULL, so comparisons involving NULL return UNKNOWN rather than TRUE or FALSE. */

/* Q10. COALESCE(a, b, c) returns the first argument that is NOT NULL, scanning left to right; if all are NULL it returns NULL. */

/* Q11. A CTE (WITH clause) names an intermediate result so it can be referenced later in the same query, improving readability and letting the same logic be reused multiple times without repeating the subquery text. */

/* Q12. ROW_NUMBER() OVER (PARTITION BY x ORDER BY y) assigns a unique, sequential integer (1, 2, 3, ...) to each row within each partition of x, ordered by y - ties get different consecutive numbers. */

/* Q13. ROW_NUMBER gives every row a unique sequential number even on ties; RANK gives tied rows the same rank but skips the next rank number(s) (e.g. 1,2,2,4); DENSE_RANK gives tied rows the same rank with no gap (1,2,2,3). */

/* Q14. LAG(col, 1) returns the value of col from the row 1 position before the current row within its window ordering (NULL if there is no such row), useful for period-over-period comparisons. */

/* Q15. An index is a separate data structure (typically a B-tree) that maps column values to row locations, letting Postgres find matching rows directly instead of scanning every row - it speeds up lookups, filters, joins and ORDER BY on the indexed column(s) at the cost of extra storage and slower writes. */

/* Q16. EXPLAIN alone shows the planner's estimated plan and costs without running the query; EXPLAIN ANALYZE actually executes the query and reports real elapsed time and real row counts per node, letting you see where the estimate was wrong. */

/* Q17. A materialized view stores its query result physically on disk like a table and must be explicitly refreshed (REFRESH MATERIALIZED VIEW) to pick up new data; a regular view is just a saved query that re-executes against live data every time it is selected from. */

/* Q18. Use PERCENTILE_CONT for a "central" metric when the data is skewed or has outliers, since the median (or another percentile) is not pulled around by extreme values the way AVG is. */

/* Q19. UNION combines two result sets and removes duplicate rows (implicit dedup pass); UNION ALL simply concatenates both result sets, keeping duplicates, and is faster because it skips the dedup step. */

/* Q20. A self-join joins a table to itself, typically to compare rows within the same table - e.g. joining stores.employees to itself to compare an employee's salary to another employee in the same store or department. */

/* Q21. EXISTS checks whether a correlated subquery returns at least one row and short-circuits as soon as it finds one; it is commonly used to test for the presence of related rows (e.g. "customers who have placed at least one order") without caring about the actual matched values. */

/* Q22. A correlated subquery references a column from the outer query in its WHERE clause, so it conceptually re-runs once per outer row rather than being evaluated independently. */

/* Q23. NULLIF(a, b) returns NULL if a equals b, otherwise it returns a - commonly used to avoid division-by-zero by turning a 0 denominator into NULL. */

/* Q24. 1NF (First Normal Form) requires that every column holds a single atomic value (no repeating groups or arrays packed into one field) and that each row is uniquely identifiable. */

/* Q25. ACID stands for Atomicity, Consistency, Isolation, Durability - the guarantees a transaction gives that a set of operations either fully commits or fully rolls back, leaves the database in a valid state, is isolated from concurrent transactions, and survives a crash once committed. This matters for order processing so a payment and an inventory decrement either both happen or neither does. */

/* ============================================================
   SECTION B: FOUNDATIONS DRILL (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT product_id, product_name, price
FROM products.products
ORDER BY price DESC
LIMIT 10;

/* Q27. */
SELECT tier, COUNT(*) AS customer_count
FROM customers.customers
GROUP BY tier
ORDER BY tier;

/* Q28. */
SELECT order_id, cust_id, order_date, order_status, net_total
FROM sales.orders
WHERE order_date >= DATE '2025-01-01' AND order_date < DATE '2025-02-01'
ORDER BY order_date;

/* Q29. */
SELECT first_name, last_name, email
FROM customers.customers
WHERE registration_date > DATE '2024-06-01'
ORDER BY registration_date;

/* Q30. */
SELECT order_status, COUNT(*) AS order_count
FROM sales.orders
GROUP BY order_status
ORDER BY order_count DESC;

/* Q31. */
SELECT ROUND(AVG(net_total), 2) AS avg_net_total_delivered
FROM sales.orders
WHERE order_status = 'Delivered';

/* Q32. */
SELECT p.product_id, p.product_name, p.price, c.category_name
FROM products.products p
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category c ON c.category_id = b.category_id
WHERE p.price > 5000 AND c.category_name = 'Electronics';

/* Q33. */
SELECT DISTINCT order_status
FROM sales.orders
ORDER BY order_status;

/* Q34. -- stores.employees has no "current_salary" column; salary is the only salary field, used as the equivalent here. */
SELECT employee_id, first_name, last_name, salary
FROM stores.employees
ORDER BY salary DESC
LIMIT 5;

/* Q35. */
SELECT priority, COUNT(*) AS ticket_count
FROM support.tickets
GROUP BY priority
ORDER BY
  CASE priority WHEN 'Critical' THEN 1 WHEN 'High' THEN 2 WHEN 'Medium' THEN 3 WHEN 'Low' THEN 4 ELSE 5 END;

/* Q36. -- products.products has no "description" column; substituting cost_price IS NULL as the nearest analogous "missing attribute" check on the table. */
SELECT product_id, product_name
FROM products.products
WHERE cost_price IS NULL;

/* Q37. */
SELECT s.store_id, s.store_name, COUNT(o.order_id) AS order_count
FROM stores.stores s
JOIN sales.orders o ON o.store_id = s.store_id
GROUP BY s.store_id, s.store_name
ORDER BY order_count DESC
LIMIT 10;

/* Q38. */
SELECT customer_id, first_name, last_name
FROM customers.customers
WHERE phone IS NULL;

/* Q39. */
SELECT device_type, COUNT(*) AS view_count
FROM web_events.page_views
GROUP BY device_type
ORDER BY view_count DESC;

/* Q40. */
SELECT DATE_TRUNC('month', return_date)::date AS return_month,
       SUM(refund_amount) AS total_refund_amount
FROM sales.returns
GROUP BY DATE_TRUNC('month', return_date)
ORDER BY return_month;

/* Q41. */
SELECT b.brand_id, b.brand_name, COUNT(*) AS product_count
FROM core.dim_brand b
JOIN products.products p ON p.brand_id = b.brand_id
GROUP BY b.brand_id, b.brand_name
HAVING COUNT(*) > 50
ORDER BY product_count DESC;

/* Q42. */
SELECT campaign_id, campaign_name, start_date, end_date
FROM marketing.campaigns
ORDER BY start_date ASC;

/* Q43. */
SELECT d.dept_name, COUNT(*) AS employee_count
FROM stores.employees e
JOIN core.dim_department d ON d.dept_id = e.dept_id
GROUP BY d.dept_name
ORDER BY employee_count DESC;

/* Q44. */
SELECT product_id, product_name, price, cost_price
FROM products.products
WHERE price < cost_price;

/* Q45. */
SELECT platform, SUM(amount) AS total_spend
FROM marketing.ads_spend
GROUP BY platform
ORDER BY total_spend DESC;

/* Q46. -- call_center.calls has no "call_type" column; call_reason is the equivalent categorical field. */
SELECT call_reason, COUNT(*) AS call_count
FROM call_center.calls
GROUP BY call_reason
ORDER BY call_count DESC;

/* Q47. */
SELECT work_order_id, product_id, line_id, status
FROM manufacture.work_orders
WHERE status = 'In Progress';

/* Q48. */
SELECT s.store_id, s.store_name, s.city
FROM stores.stores s
JOIN core.dim_region r ON r.region_id = s.region_id
WHERE r.region_name = 'North';

/* Q49. */
SELECT customer_id, tier_id, points_balance
FROM loyalty.members
WHERE points_balance > 10000
ORDER BY points_balance DESC;

/* Q50. */
SELECT level, COUNT(*) AS log_count
FROM audit.application_logs
GROUP BY level
ORDER BY log_count DESC;

/* ============================================================
   SECTION C: JOINS & AGGREGATES (25)
   ------------------------------------------------------------ */
/* Q51. */
SELECT c.customer_id, c.first_name, c.last_name, COUNT(o.order_id) AS total_orders
FROM customers.customers c
LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY total_orders DESC;

/* Q52. */
SELECT p.product_id, p.product_name, SUM(oi.quantity) AS total_units_sold
FROM sales.order_items oi
JOIN products.products p ON p.product_id = oi.prod_id
GROUP BY p.product_id, p.product_name
ORDER BY total_units_sold DESC
LIMIT 5;

/* Q53. */
SELECT s.store_id, s.store_name, ROUND(AVG(o.net_total), 2) AS avg_net_total
FROM stores.stores s
JOIN sales.orders o ON o.store_id = s.store_id
GROUP BY s.store_id, s.store_name
ORDER BY avg_net_total DESC;

/* Q54. */
SELECT b.brand_id, b.brand_name, COUNT(p.product_id) AS product_count, ROUND(AVG(p.price), 2) AS avg_price
FROM core.dim_brand b
JOIN products.products p ON p.brand_id = b.brand_id
GROUP BY b.brand_id, b.brand_name
ORDER BY product_count DESC;

/* Q55. */
SELECT DISTINCT c.customer_id, c.first_name, c.last_name
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
WHERE o.order_status = 'Returned';

/* Q56. */
SELECT cat.category_id, cat.category_name,
       SUM(oi.quantity * oi.unit_price) AS total_revenue
FROM sales.order_items oi
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
GROUP BY cat.category_id, cat.category_name
ORDER BY total_revenue DESC
LIMIT 3;

/* Q57. */
SELECT c.customer_id, c.first_name, c.last_name, COUNT(t.ticket_id) AS ticket_count
FROM customers.customers c
JOIN support.tickets t ON t.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY ticket_count DESC
LIMIT 10;

/* Q58. */
SELECT p.product_id, p.product_name
FROM products.products p
LEFT JOIN sales.order_items oi ON oi.prod_id = p.product_id
WHERE oi.order_item_id IS NULL;

/* Q59. */
SELECT s.store_id, s.store_name, COUNT(e.employee_id) AS employee_count
FROM stores.stores s
LEFT JOIN stores.employees e ON e.store_id = s.store_id
GROUP BY s.store_id, s.store_name
ORDER BY employee_count DESC;

/* Q60. */
SELECT c.campaign_id, c.campaign_name, SUM(a.amount) AS total_ads_spend
FROM marketing.campaigns c
JOIN marketing.ads_spend a ON a.campaign_id = c.campaign_id
GROUP BY c.campaign_id, c.campaign_name
ORDER BY total_ads_spend DESC;

/* Q61. */
SELECT r.customer_id, COUNT(DISTINCT r.product_id) AS products_reviewed
FROM customers.reviews r
GROUP BY r.customer_id
HAVING COUNT(DISTINCT r.product_id) >= 3
ORDER BY products_reviewed DESC;

/* Q62. */
SELECT courier_name, COUNT(*) AS shipment_count
FROM sales.shipments
GROUP BY courier_name
ORDER BY shipment_count DESC;

/* Q63. */
SELECT cat.category_id, cat.category_name,
       ROUND(AVG(p.price), 2) AS avg_price,
       ROUND(AVG(p.cost_price), 2) AS avg_cost_price
FROM products.products p
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
GROUP BY cat.category_id, cat.category_name
ORDER BY cat.category_name;

/* Q64. */
SELECT t.tier_name, COUNT(rd.redemption_id) AS total_redemptions
FROM loyalty.tiers t
JOIN loyalty.members m ON m.tier_id = t.tier_id
LEFT JOIN loyalty.redemptions rd ON rd.customer_id = m.customer_id
GROUP BY t.tier_name
ORDER BY total_redemptions DESC;

/* Q65. */
SELECT sh.employee_id, COUNT(DISTINCT sh.amount) AS distinct_salary_amounts
FROM hr.salary_history sh
GROUP BY sh.employee_id
HAVING COUNT(DISTINCT sh.amount) > 1
ORDER BY distinct_salary_amounts DESC;

/* Q66. */
SELECT page_url, COUNT(*) AS view_count
FROM web_events.page_views
GROUP BY page_url
ORDER BY view_count DESC
LIMIT 10;

/* Q67. */
SELECT DATE_TRUNC('month', order_date)::date AS order_month, SUM(net_total) AS total_revenue
FROM sales.orders
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY total_revenue DESC
LIMIT 1;

/* Q68. */
SELECT cat.category_id, cat.category_name, COUNT(r.return_id) AS return_count
FROM sales.returns r
JOIN products.products p ON p.product_id = r.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
GROUP BY cat.category_id, cat.category_name
ORDER BY return_count DESC;

/* Q69. */
SELECT s.warehouse_id, COUNT(DISTINCT s.product_id) AS distinct_products
FROM supply_chain.inventory_snapshots s
GROUP BY s.warehouse_id
ORDER BY s.warehouse_id;

/* Q70. */
SELECT c.campaign_id, c.campaign_name
FROM marketing.campaigns c
LEFT JOIN marketing.ads_spend a ON a.campaign_id = c.campaign_id
GROUP BY c.campaign_id, c.campaign_name
HAVING COALESCE(SUM(a.amount), 0) = 0;

/* Q71. */
SELECT pm.mode_name, SUM(p.amount) AS total_payment_amount
FROM sales.orders o
JOIN finance.payment_modes pm ON pm.mode_id = o.payment_mode_id
JOIN finance.payments p ON p.order_id = o.order_id
GROUP BY pm.mode_name
ORDER BY total_payment_amount DESC;

/* Q72. */
SELECT COUNT(*) AS calls_resolved_within_5min
FROM call_center.calls
WHERE call_duration_seconds <= 300;

/* Q73. */
SELECT c.customer_id, c.first_name, c.last_name, SUM(o.net_total) AS total_spend
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY total_spend DESC
LIMIT 5;

/* Q74. */
SELECT cat.category_id, cat.category_name, ROUND(AVG(r.rating), 2) AS avg_rating
FROM customers.reviews r
JOIN products.products p ON p.product_id = r.product_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
GROUP BY cat.category_id, cat.category_name
ORDER BY avg_rating DESC;

/* Q75. */
SELECT DISTINCT p.product_id, p.product_name
FROM products.products p
JOIN sales.order_items oi ON oi.prod_id = p.product_id
JOIN sales.orders o ON o.order_id = oi.order_id
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
WHERE r.region_name = 'South';

/* ============================================================
   SECTION D: WINDOW FUNCTIONS & CONDITIONALS (25)
   ------------------------------------------------------------ */
/* Q76. */
SELECT c.customer_id, c.first_name, c.last_name, SUM(o.net_total) AS total_spend,
       DENSE_RANK() OVER (ORDER BY SUM(o.net_total) DESC) AS spend_rank
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY spend_rank;

/* Q77. */
SELECT p.product_id, p.product_name, cat.category_name, p.price,
       RANK() OVER (PARTITION BY cat.category_id ORDER BY p.price DESC) AS price_rank_in_category
FROM products.products p
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
ORDER BY cat.category_name, price_rank_in_category;

/* Q78. */
WITH monthly AS (
  SELECT DATE_TRUNC('month', order_date)::date AS order_month, COUNT(*) AS order_count
  FROM sales.orders
  GROUP BY DATE_TRUNC('month', order_date)
)
SELECT order_month, order_count,
       order_count - LAG(order_count) OVER (ORDER BY order_month) AS mom_change
FROM monthly
ORDER BY order_month;

/* Q79. */
SELECT cust_id, order_id, order_date, net_total,
       SUM(net_total) OVER (PARTITION BY cust_id ORDER BY order_date
                             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total
FROM sales.orders
ORDER BY cust_id, order_date;

/* Q80. */
SELECT product_id, product_name, price,
       NTILE(4) OVER (ORDER BY price) AS price_quartile
FROM products.products
ORDER BY price_quartile, price;

/* Q81. */
WITH ranked AS (
  SELECT order_id, cust_id, order_date, net_total,
         ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date DESC) AS rn
  FROM sales.orders
)
SELECT order_id, cust_id, order_date, net_total
FROM ranked
WHERE rn = 1
ORDER BY cust_id;

/* Q82. */
SELECT DISTINCT employee_id,
       FIRST_VALUE(amount) OVER (PARTITION BY employee_id ORDER BY payment_date) AS first_salary
FROM hr.salary_history
ORDER BY employee_id;

/* Q83. */
SELECT product_id, product_name, price,
       CASE
         WHEN price > 10000 THEN 'Premium'
         WHEN price > 3000 THEN 'Mid'
         ELSE 'Budget'
       END AS price_tier
FROM products.products
ORDER BY price DESC;

/* Q84. */
SELECT customer_id, tier,
       CASE tier
         WHEN 'Platinum' THEN 'VIP - Platinum'
         WHEN 'Gold' THEN 'Preferred - Gold'
         WHEN 'Silver' THEN 'Standard - Silver'
         WHEN 'Bronze' THEN 'Entry - Bronze'
         ELSE 'Unclassified'
       END AS tier_label
FROM customers.customers
ORDER BY customer_id;

/* Q85. */
SELECT customer_id, COALESCE(phone, 'Not provided') AS phone
FROM customers.customers
ORDER BY customer_id;

/* Q86. */
SELECT review_id, customer_id, product_id, NULLIF(rating, 0) AS rating
FROM customers.reviews
ORDER BY review_id;

/* Q87. */
WITH daily AS (
  SELECT order_date, COUNT(*) AS order_count
  FROM sales.orders
  GROUP BY order_date
)
SELECT order_date, order_count,
       ROUND(AVG(order_count) OVER (ORDER BY order_date
                                     ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS moving_avg_3d
FROM daily
ORDER BY order_date;

/* Q88. */
SELECT cust_id, order_id, order_date, net_total,
       LAG(net_total) OVER (PARTITION BY cust_id ORDER BY order_date) AS prev_order_net_total
FROM sales.orders
ORDER BY cust_id, order_date;

/* Q89. */
SELECT employee_id, dept_id, salary,
       ROUND(AVG(salary) OVER (PARTITION BY dept_id), 2) AS dept_avg_salary
FROM stores.employees
ORDER BY dept_id, salary DESC;

/* Q90. */
SELECT p.product_id, p.product_name, b.brand_id, p.price,
       ROUND(PERCENT_RANK() OVER (PARTITION BY b.brand_id ORDER BY p.price)::numeric, 4) AS price_percent_rank
FROM products.products p
JOIN core.dim_brand b ON b.brand_id = p.brand_id
ORDER BY b.brand_id, price_percent_rank;

/* Q91. */
SELECT order_id, cust_id, order_date, net_total,
       SUM(net_total) OVER (ORDER BY order_date
                             RANGE BETWEEN INTERVAL '30 days' PRECEDING AND CURRENT ROW) AS trailing_30d_total
FROM sales.orders
ORDER BY order_date;

/* Q92. */
SELECT order_id, order_status,
       CASE
         WHEN order_status IN ('Processing', 'Shipped', 'Out for Delivery') THEN 'Active'
         WHEN order_status = 'Delivered' THEN 'Closed'
         WHEN order_status IN ('Returned', 'Cancelled', 'Failed') THEN 'Problem'
         ELSE 'Other'
       END AS status_category
FROM sales.orders
ORDER BY order_id;

/* Q93. */
WITH ranked AS (
  SELECT p.product_id, p.product_name, cat.category_id, cat.category_name, p.price,
         DENSE_RANK() OVER (PARTITION BY cat.category_id ORDER BY p.price DESC) AS price_rank
  FROM products.products p
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
)
SELECT product_id, product_name, category_name, price
FROM ranked
WHERE price_rank = 2
ORDER BY category_name;

/* Q94. */
SELECT call_id, agent_id, call_start_time, call_duration_seconds,
       LEAD(call_duration_seconds) OVER (PARTITION BY agent_id ORDER BY call_start_time) AS next_call_duration
FROM call_center.calls
ORDER BY agent_id, call_start_time;

/* Q95. */
SELECT customer_id, points_balance,
       CASE
         WHEN points_balance BETWEEN 0 AND 999 THEN '0-999'
         WHEN points_balance BETWEEN 1000 AND 4999 THEN '1000-4999'
         ELSE '5000+'
       END AS points_bucket
FROM loyalty.members
ORDER BY points_balance DESC;

/* Q96. */
WITH monthly AS (
  SELECT DATE_TRUNC('month', order_date)::date AS order_month, SUM(net_total) AS total_revenue
  FROM sales.orders
  GROUP BY DATE_TRUNC('month', order_date)
)
SELECT order_month, total_revenue,
       SUM(total_revenue) OVER (ORDER BY order_month) AS cumulative_revenue
FROM monthly
ORDER BY order_month;

/* Q97. */
SELECT
  COUNT(*) FILTER (WHERE order_status = 'Delivered') AS delivered_count,
  COUNT(*) FILTER (WHERE order_status = 'Returned') AS returned_count
FROM sales.orders;

/* Q98. */
WITH ranked AS (
  SELECT employee_id, first_name, last_name, salary,
         RANK() OVER (ORDER BY salary ASC) AS salary_rank
  FROM stores.employees
)
SELECT employee_id, first_name, last_name, salary, salary_rank
FROM ranked
WHERE salary_rank <= 5
ORDER BY salary_rank;

/* Q99. */
SELECT ticket_id, customer_id, created_date,
       LEAD(created_date) OVER (PARTITION BY customer_id ORDER BY created_date) - created_date AS gap_to_next_ticket
FROM support.tickets
ORDER BY customer_id, created_date;

/* Q100. */
WITH cust_orders AS (
  SELECT c.customer_id, c.tier,
         COUNT(o.order_id) AS total_orders,
         COALESCE(SUM(o.net_total), 0) AS total_spent
  FROM customers.customers c
  LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
  GROUP BY c.customer_id, c.tier
)
SELECT customer_id, total_orders, total_spent,
       RANK() OVER (ORDER BY total_spent DESC) AS spending_rank,
       CASE tier
         WHEN 'Platinum' THEN 'VIP - Platinum'
         WHEN 'Gold' THEN 'Preferred - Gold'
         WHEN 'Silver' THEN 'Standard - Silver'
         WHEN 'Bronze' THEN 'Entry - Bronze'
         ELSE 'Unclassified'
       END AS tier_label
FROM cust_orders
ORDER BY spending_rank;
