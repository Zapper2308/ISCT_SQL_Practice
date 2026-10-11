/* ============================================================
   ANSWER KEY - Window Functions Part 1: Ranking & Bucketing (EASY LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* SECTION A: CONCEPTUAL (25) */

/* Q1.  A window function computes a value across a set of related rows (its "window") while still returning one row per input row; GROUP BY collapses multiple rows into a single summary row per group, losing row-level detail. */
/* Q2.  OVER() tells Postgres to treat the preceding function as a window function instead of a regular aggregate; an empty OVER() means the window is the entire result set (or partition, if none specified) - no partitioning, no ordering. */
/* Q3.  PARTITION BY splits the rows into independent groups, and the window function restarts its calculation separately within each group, similar to how GROUP BY groups rows but without collapsing them. */
/* Q4.  ORDER BY inside OVER() defines the sequence the ranking function walks through each partition in, which directly determines the rank/row number assigned to each row. */
/* Q5.  ROW_NUMBER() assigns a unique, strictly increasing integer (1, 2, 3, ...) to each row in partition/order - it is never tied, even when the ORDER BY values are equal. */
/* Q6.  RANK() gives tied rows the same rank number, then skips the next rank(s) by the count of ties - e.g. two rows tied for rank 1 are both "1", and the next row gets rank 3. */
/* Q7.  DENSE_RANK() also gives tied rows the same rank, but does NOT skip any following rank numbers - after two rows tied at 1, the next row gets rank 2. */
/* Q8.  On ties: ROW_NUMBER keeps counting up with no ties (arbitrary order among equals); RANK repeats the rank and then skips; DENSE_RANK repeats the rank with no gap afterward. */
/* Q9.  NTILE(4) divides the rows in each partition as evenly as possible into 4 numbered buckets (1-4), commonly used for quartiles. */
/* Q10. Ranking functions need an ORDER BY to know what to rank by - without it, there's no defined sequence to assign row numbers/ranks against. */
/* Q11. No - window functions are computed after the WHERE clause is evaluated, so their result isn't available yet to filter on directly in the same query's WHERE. */
/* Q12. Wrap the window function in a CTE or subquery, then filter on its output column (e.g. WHERE rn = 1) in the outer query. */
/* Q13. No - window functions keep every input row in the result; they only add a computed column, unlike GROUP BY which reduces the row count. */
/* Q14. A partition is the group used only for window function calculations, still returning all individual rows; a GROUP BY group collapses its rows down into one aggregated row. */
/* Q15. The first row's ROW_NUMBER() is 1. */
/* Q16. By default in Postgres, NULLs sort last in ascending (ASC) order. */
/* Q17. It creates a two-level partition - rows are grouped by the combination of region AND category together, and ranking restarts within each unique (region, category) pair. */
/* Q18. No - when there are ties in the ORDER BY, which tied row gets which specific ROW_NUMBER value is arbitrary/non-deterministic; fix it by adding a unique tie-breaker column (like an id) to the ORDER BY. */
/* Q19. Rank rows within each group with a window function, then keep only the rows whose rank is <= N to get the top N rows per group. */
/* Q20. ROW_NUMBER always assigns exactly one distinct number per row, guaranteeing exactly one row survives a "keep rn = 1" filter even when there are ties, whereas RANK could keep multiple tied rows. */
/* Q21. NTILE distributes the remainder rows into the earliest buckets first, so some buckets end up with one more row than others when the total doesn't divide evenly. */
/* Q22. Yes - a single SELECT can have multiple window functions, each with its own independent OVER() clause (different PARTITION BY / ORDER BY). */
/* Q23. Window functions are evaluated after WHERE, GROUP BY, and HAVING, but before the final ORDER BY and LIMIT of the outer query. */
/* Q24. ROW_NUMBER always produces a dense, gapless sequence (1, 2, 3, ...) regardless of ties; RANK can produce gaps in its output values whenever ties occur. */
/* Q25. ROW_NUMBER: deduplicating rows (keep rn = 1); RANK: leaderboard-style ranking where ties should share a place and skip the next; NTILE: splitting customers into spend quartiles/deciles for segmentation. */

/* SECTION B: ROW_NUMBER (25) */

/* Q26. */
SELECT order_id, cust_id, order_date,
       ROW_NUMBER() OVER (ORDER BY order_date DESC) AS rn
FROM sales.orders
ORDER BY rn
LIMIT 50;

/* Q27. */
SELECT product_id, product_name, price,
       ROW_NUMBER() OVER (ORDER BY price DESC) AS rn
FROM products.products
ORDER BY rn
LIMIT 50;

/* Q28. */
SELECT customer_id, first_name, last_name, registration_date,
       ROW_NUMBER() OVER (ORDER BY registration_date ASC) AS rn
FROM customers.customers
ORDER BY rn
LIMIT 50;

/* Q29. */
SELECT employee_id, first_name, last_name, salary,
       ROW_NUMBER() OVER (ORDER BY salary DESC) AS rn
FROM stores.employees
ORDER BY rn
LIMIT 50;

/* Q30. */
SELECT order_id, cust_id, order_date,
       ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date) AS rn
FROM sales.orders
ORDER BY cust_id, rn
LIMIT 50;

/* Q31. */
SELECT product_id, product_name, brand_id, price,
       ROW_NUMBER() OVER (PARTITION BY brand_id ORDER BY price DESC) AS rn
FROM products.products
ORDER BY brand_id, rn
LIMIT 50;

/* Q32. */
SELECT review_id, product_id, review_date,
       ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY review_date DESC) AS rn
FROM customers.reviews
ORDER BY product_id, rn
LIMIT 50;

/* Q33. */
SELECT employee_id, store_id, first_name, last_name, salary,
       ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY salary DESC) AS rn
FROM stores.employees
ORDER BY store_id, rn
LIMIT 50;

/* Q34. */
WITH ranked AS (
  SELECT order_id, cust_id, order_date,
         ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date DESC) AS rn
  FROM sales.orders
)
SELECT cust_id, order_id, order_date
FROM ranked
WHERE rn = 1
ORDER BY cust_id
LIMIT 50;

/* Q35. */
WITH ranked AS (
  SELECT product_id, product_name, brand_id, price,
         ROW_NUMBER() OVER (PARTITION BY brand_id ORDER BY price ASC) AS rn
  FROM products.products
)
SELECT brand_id, product_id, product_name, price
FROM ranked
WHERE rn = 1
ORDER BY brand_id
LIMIT 50;

/* Q36. */
WITH ranked AS (
  SELECT review_id, customer_id, product_id, review_date,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY review_date DESC) AS rn
  FROM customers.reviews
)
SELECT customer_id, review_id, product_id, review_date
FROM ranked
WHERE rn = 1
ORDER BY customer_id
LIMIT 50;

/* Q37. */
SELECT ticket_id, priority, created_date,
       ROW_NUMBER() OVER (PARTITION BY priority ORDER BY created_date) AS rn
FROM support.tickets
ORDER BY priority, rn
LIMIT 50;

/* Q38. */
SELECT store_id, region_id, store_name, square_ft,
       ROW_NUMBER() OVER (PARTITION BY region_id ORDER BY square_ft DESC) AS rn
FROM stores.stores
ORDER BY region_id, rn
LIMIT 50;

/* Q39. */
SELECT call_id, customer_id, call_start_time,
       ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY call_start_time) AS rn
FROM call_center.calls
ORDER BY customer_id, rn
LIMIT 50;

/* Q40. */
WITH top_orders AS (
  SELECT order_id, cust_id, net_total
  FROM sales.orders
  ORDER BY net_total DESC
  LIMIT 50
)
SELECT order_id, cust_id, net_total,
       ROW_NUMBER() OVER (ORDER BY net_total DESC) AS rn
FROM top_orders
ORDER BY rn;

/* Q41. */
SELECT payment_id, order_id, payment_date,
       ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY payment_date) AS rn
FROM sales.payments
ORDER BY order_id, rn
LIMIT 50;

/* Q42. */
SELECT shipment_id, courier_name, shipped_date,
       ROW_NUMBER() OVER (PARTITION BY courier_name ORDER BY shipped_date) AS rn
FROM sales.shipments
ORDER BY courier_name, rn
LIMIT 50;

/* Q43. */
WITH ranked AS (
  SELECT order_id, store_id, order_date,
         ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY order_date ASC) AS rn
  FROM sales.orders
)
SELECT store_id, order_id, order_date
FROM ranked
WHERE rn = 1
ORDER BY store_id
LIMIT 50;

/* Q44. */
SELECT address_id, customer_id, is_default, city,
       ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY is_default DESC, address_id) AS rn
FROM customers.addresses
ORDER BY customer_id, rn
LIMIT 50;

/* Q45. */
SELECT spend_id, platform, amount,
       ROW_NUMBER() OVER (PARTITION BY platform ORDER BY amount DESC) AS rn
FROM marketing.ads_spend
ORDER BY platform, rn
LIMIT 50;

/* Q46. */
SELECT order_id, cust_id, order_date,
       ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date) AS purchase_number
FROM sales.orders
ORDER BY cust_id, purchase_number
LIMIT 50;

/* Q47. */
SELECT product_id, product_name, supplier_id,
       ROW_NUMBER() OVER (PARTITION BY supplier_id ORDER BY product_name) AS rn
FROM products.products
ORDER BY supplier_id, rn
LIMIT 50;

/* Q48. */
WITH ranked AS (
  SELECT employee_id, first_name, last_name, dept_id, salary,
         ROW_NUMBER() OVER (PARTITION BY dept_id ORDER BY salary DESC) AS rn
  FROM stores.employees
)
SELECT dept_id, employee_id, first_name, last_name, salary
FROM ranked
WHERE rn = 1
ORDER BY dept_id;

/* Q49. */
SELECT order_id, store_id, net_total,
       ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY net_total DESC) AS rn
FROM sales.orders
ORDER BY store_id, rn
LIMIT 50;

/* Q50. */
SELECT customer_id, email, registration_date,
       ROW_NUMBER() OVER (PARTITION BY email ORDER BY registration_date DESC) AS rn
FROM customers.customers
ORDER BY email, rn
LIMIT 50;

/* SECTION C: RANK / DENSE_RANK (25) */

/* Q51. */
SELECT product_id, product_name, price,
       RANK() OVER (ORDER BY price DESC) AS price_rank
FROM products.products
ORDER BY price_rank
LIMIT 50;

/* Q52. */
SELECT product_id, product_name, price,
       DENSE_RANK() OVER (ORDER BY price DESC) AS price_dense_rank
FROM products.products
ORDER BY price_dense_rank
LIMIT 50;

/* Q53. */
SELECT employee_id, dept_id, first_name, last_name, salary,
       RANK() OVER (PARTITION BY dept_id ORDER BY salary DESC) AS salary_rank
FROM stores.employees
ORDER BY dept_id, salary_rank
LIMIT 50;

/* Q54. */
SELECT order_id, cust_id, net_total,
       DENSE_RANK() OVER (PARTITION BY cust_id ORDER BY net_total DESC) AS order_rank
FROM sales.orders
ORDER BY cust_id, order_rank
LIMIT 50;

/* Q55. */
SELECT store_id, region_id, square_ft,
       RANK() OVER (PARTITION BY region_id ORDER BY square_ft DESC) AS size_rank
FROM stores.stores
ORDER BY region_id, size_rank
LIMIT 50;

/* Q56. */
SELECT product_id, product_name, price,
       ROW_NUMBER() OVER (ORDER BY price DESC) AS row_num,
       RANK() OVER (ORDER BY price DESC) AS rnk,
       DENSE_RANK() OVER (ORDER BY price DESC) AS dense_rnk
FROM products.products
ORDER BY price DESC
LIMIT 50;

/* Q57. */
SELECT customer_id, tier, registration_date,
       RANK() OVER (ORDER BY tier, registration_date) AS overall_rank
FROM customers.customers
ORDER BY overall_rank
LIMIT 50;

/* Q58. */
SELECT product_id, product_name, brand_id, price,
       DENSE_RANK() OVER (PARTITION BY brand_id ORDER BY price DESC) AS price_dense_rank
FROM products.products
ORDER BY brand_id, price_dense_rank
LIMIT 50;

/* Q59. */
SELECT review_id, product_id, rating,
       RANK() OVER (PARTITION BY product_id ORDER BY rating DESC) AS rating_rank
FROM customers.reviews
ORDER BY product_id, rating_rank
LIMIT 50;

/* Q60. */
WITH ranked AS (
  SELECT product_id, product_name, price,
         RANK() OVER (ORDER BY price DESC) AS price_rank
  FROM products.products
)
SELECT product_id, product_name, price, price_rank
FROM ranked
WHERE product_id = (SELECT MIN(product_id) FROM products.products);

/* Q61. */
SELECT ticket_id, status, priority, created_date,
       RANK() OVER (PARTITION BY status ORDER BY created_date) AS priority_rank
FROM support.tickets
ORDER BY status, priority_rank
LIMIT 50;

/* Q62. */
SELECT COUNT(DISTINCT salary_level) AS distinct_salary_levels
FROM (
  SELECT DENSE_RANK() OVER (ORDER BY salary DESC) AS salary_level
  FROM stores.employees
) x;

/* Q63. */
SELECT order_id, store_id, order_date,
       RANK() OVER (PARTITION BY store_id ORDER BY order_date) AS order_seq_rank
FROM sales.orders
ORDER BY store_id, order_seq_rank
LIMIT 50;

/* Q64. */
WITH brand_counts AS (
  SELECT brand_id, COUNT(*) AS product_count
  FROM products.products
  GROUP BY brand_id
)
SELECT brand_id, product_count,
       DENSE_RANK() OVER (ORDER BY product_count DESC) AS count_rank
FROM brand_counts
ORDER BY count_rank
LIMIT 50;

/* Q65. */
SELECT call_id, agent_id, call_duration_seconds,
       RANK() OVER (PARTITION BY agent_id ORDER BY call_duration_seconds DESC) AS duration_rank
FROM call_center.calls
ORDER BY agent_id, duration_rank
LIMIT 50;

/* Q66. */
SELECT review_id, product_id, rating,
       RANK() OVER (PARTITION BY product_id ORDER BY rating DESC) AS rating_rank
FROM customers.reviews
WHERE product_id = (SELECT product_id FROM customers.reviews GROUP BY product_id HAVING COUNT(DISTINCT rating) < COUNT(*) LIMIT 1)
ORDER BY rating_rank
LIMIT 20;

/* Q67. */
SELECT p.product_id, p.product_name, cat.category_name, p.cost_price,
       RANK() OVER (PARTITION BY cat.category_id ORDER BY p.cost_price DESC) AS cost_rank
FROM products.products p
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
ORDER BY cat.category_id, cost_rank
LIMIT 50;

/* Q68. */
SELECT customer_id, points_balance,
       DENSE_RANK() OVER (ORDER BY points_balance DESC) AS points_rank
FROM loyalty.members
ORDER BY points_rank
LIMIT 50;

/* Q69. */
SELECT shipment_id, courier_name, delivered_date - shipped_date AS delivery_days,
       RANK() OVER (PARTITION BY courier_name ORDER BY (delivered_date - shipped_date) DESC) AS delivery_rank
FROM sales.shipments
WHERE delivered_date IS NOT NULL
ORDER BY courier_name, delivery_rank
LIMIT 50;

/* Q70. */
SELECT pay_slip_id, employee_id, salary_year, net_salary,
       RANK() OVER (PARTITION BY salary_year ORDER BY net_salary DESC) AS salary_rank
FROM payroll.pay_slips
ORDER BY salary_year, salary_rank
LIMIT 50;

/* Q71. */
WITH ranked AS (
  SELECT product_id, product_name, brand_id, price,
         RANK() OVER (PARTITION BY brand_id ORDER BY price DESC) AS price_rank
  FROM products.products
)
SELECT brand_id, product_id, product_name, price, price_rank
FROM ranked
WHERE price_rank = 1
ORDER BY brand_id
LIMIT 50;

/* Q72. */
WITH status_counts AS (
  SELECT order_status, COUNT(*) AS status_count
  FROM sales.orders
  GROUP BY order_status
)
SELECT order_status, status_count,
       DENSE_RANK() OVER (ORDER BY status_count DESC) AS frequency_rank
FROM status_counts
ORDER BY frequency_rank;

/* Q73. */
WITH region_counts AS (
  SELECT region_id, COUNT(*) AS store_count
  FROM stores.stores
  GROUP BY region_id
)
SELECT region_id, store_count,
       RANK() OVER (ORDER BY store_count DESC) AS region_rank
FROM region_counts
ORDER BY region_rank;

/* Q74. */
WITH ranked AS (
  SELECT employee_id, dept_id, first_name, last_name, salary,
         RANK() OVER (PARTITION BY dept_id ORDER BY salary DESC) AS salary_rank
  FROM stores.employees
)
SELECT dept_id, employee_id, first_name, last_name, salary, salary_rank
FROM ranked
WHERE salary_rank <= 3
ORDER BY dept_id, salary_rank;

/* Q75. */
SELECT customer_id, tier,
       RANK() OVER (ORDER BY tier) AS tier_rank,
       DENSE_RANK() OVER (ORDER BY tier) AS tier_dense_rank
FROM customers.customers
ORDER BY tier_rank
LIMIT 50;

/* SECTION D: NTILE & TOP-N (25) */

/* Q76. */
SELECT product_id, product_name, price,
       NTILE(4) OVER (ORDER BY price) AS price_quartile
FROM products.products
ORDER BY price_quartile, price
LIMIT 50;

/* Q77. */
WITH customer_spend AS (
  SELECT cust_id, SUM(net_total) AS total_spend
  FROM sales.orders
  WHERE order_status NOT IN ('Cancelled', 'Failed')
  GROUP BY cust_id
)
SELECT cust_id, total_spend,
       NTILE(10) OVER (ORDER BY total_spend) AS spend_decile
FROM customer_spend
ORDER BY spend_decile, total_spend
LIMIT 50;

/* Q78. */
SELECT employee_id, first_name, last_name, salary,
       NTILE(3) OVER (ORDER BY salary) AS salary_band
FROM stores.employees
ORDER BY salary_band, salary
LIMIT 50;

/* Q79. */
SELECT product_id, product_name, price,
       NTILE(4) OVER (ORDER BY price) AS bucket_num,
       CASE NTILE(4) OVER (ORDER BY price)
         WHEN 1 THEN 'Q1' WHEN 2 THEN 'Q2' WHEN 3 THEN 'Q3' ELSE 'Q4' END AS price_quartile_label
FROM products.products
ORDER BY bucket_num, price
LIMIT 50;

/* Q80. */
WITH bucketed AS (
  SELECT order_id, net_total,
         NTILE(5) OVER (ORDER BY net_total) AS bucket
  FROM sales.orders
)
SELECT bucket, MIN(net_total) AS bucket_min, MAX(net_total) AS bucket_max, COUNT(*) AS orders
FROM bucketed
GROUP BY bucket
ORDER BY bucket;

/* Q81. */
WITH ranked AS (
  SELECT employee_id, dept_id, first_name, last_name, salary,
         ROW_NUMBER() OVER (PARTITION BY dept_id ORDER BY salary DESC) AS rn
  FROM stores.employees
)
SELECT dept_id, employee_id, first_name, last_name, salary
FROM ranked
WHERE rn <= 3
ORDER BY dept_id, salary DESC;

/* Q82. */
WITH ranked AS (
  SELECT product_id, product_name, brand_id, price,
         ROW_NUMBER() OVER (PARTITION BY brand_id ORDER BY price DESC) AS rn
  FROM products.products
)
SELECT brand_id, product_id, product_name, price
FROM ranked
WHERE rn <= 3
ORDER BY brand_id, price DESC
LIMIT 60;

/* Q83. */
WITH ranked AS (
  SELECT order_id, cust_id, order_date,
         ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date DESC) AS rn
  FROM sales.orders
)
SELECT cust_id, order_id, order_date
FROM ranked
WHERE rn <= 2
ORDER BY cust_id, order_date DESC
LIMIT 60;

/* Q84. */
WITH store_revenue AS (
  SELECT s.store_id, s.store_name, s.region_id, SUM(o.net_total) AS revenue
  FROM stores.stores s
  JOIN sales.orders o ON o.store_id = s.store_id AND o.order_status NOT IN ('Cancelled', 'Failed')
  GROUP BY s.store_id, s.store_name, s.region_id
),
ranked AS (
  SELECT store_id, store_name, region_id, revenue,
         ROW_NUMBER() OVER (PARTITION BY region_id ORDER BY revenue DESC) AS rn
  FROM store_revenue
)
SELECT region_id, store_id, store_name, revenue
FROM ranked
WHERE rn <= 5
ORDER BY region_id, revenue DESC;

/* Q85. */
WITH ranked AS (
  SELECT product_id, product_name, brand_id, price,
         ROW_NUMBER() OVER (PARTITION BY brand_id ORDER BY price ASC) AS rn
  FROM products.products
)
SELECT brand_id, product_id, product_name, price
FROM ranked
WHERE rn <= 3
ORDER BY brand_id, price ASC
LIMIT 60;

/* Q86. */
SELECT customer_id, registration_date,
       NTILE(4) OVER (ORDER BY registration_date) AS signup_quartile
FROM customers.customers
ORDER BY signup_quartile, registration_date
LIMIT 50;

/* Q87. */
WITH ranked AS (
  SELECT product_id, product_name, price,
         ROW_NUMBER() OVER (ORDER BY price DESC) AS rn
  FROM products.products
)
SELECT product_id, product_name, price
FROM ranked
WHERE rn = 2;

/* Q88. */
WITH ranked AS (
  SELECT employee_id, dept_id, first_name, last_name, salary,
         ROW_NUMBER() OVER (PARTITION BY dept_id ORDER BY salary DESC) AS rn
  FROM stores.employees
)
SELECT dept_id, employee_id, first_name, last_name, salary
FROM ranked
WHERE rn = 2
ORDER BY dept_id;

/* Q89. */
SELECT order_id, net_total,
       NTILE(100) OVER (ORDER BY net_total) AS percentile_bucket
FROM sales.orders
ORDER BY percentile_bucket
LIMIT 50;

/* Q90. */
WITH ranked AS (
  SELECT review_id, product_id, rating, review_date,
         ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY rating DESC, review_date DESC) AS rn
  FROM customers.reviews
)
SELECT product_id, review_id, rating, review_date
FROM ranked
WHERE rn = 1
ORDER BY product_id
LIMIT 50;

/* Q91. */
SELECT product_id, product_name, brand_id, cost_price,
       NTILE(4) OVER (PARTITION BY brand_id ORDER BY cost_price) AS cost_quartile
FROM products.products
ORDER BY brand_id, cost_quartile
LIMIT 50;

/* Q92. */
WITH ranked AS (
  SELECT call_id, agent_id, call_duration_seconds,
         ROW_NUMBER() OVER (PARTITION BY agent_id ORDER BY call_duration_seconds DESC) AS rn
  FROM call_center.calls
)
SELECT agent_id, call_id, call_duration_seconds
FROM ranked
WHERE rn <= 3
ORDER BY agent_id, call_duration_seconds DESC
LIMIT 60;

/* Q93. */
WITH ranked AS (
  SELECT product_id, product_name, brand_id, price,
         ROW_NUMBER() OVER (PARTITION BY brand_id ORDER BY price DESC, product_id) AS rn
  FROM products.products
)
SELECT brand_id, product_id, product_name, price
FROM ranked
WHERE rn <= 3
ORDER BY brand_id, price DESC
LIMIT 60;

/* Q94. */
SELECT order_id, net_total,
       NTILE(2) OVER (ORDER BY net_total) AS half
FROM sales.orders
ORDER BY half, net_total
LIMIT 50;

/* Q95. */
SELECT customer_id, points_balance,
       ROW_NUMBER() OVER (ORDER BY points_balance DESC) AS rn
FROM loyalty.members
ORDER BY points_balance DESC
LIMIT 10;

/* Q96. */
SELECT store_id, store_name, square_ft,
       NTILE(4) OVER (ORDER BY square_ft) AS size_tier
FROM stores.stores
ORDER BY size_tier, square_ft
LIMIT 50;

/* Q97. */
WITH brand_counts AS (
  SELECT brand_id, COUNT(*) AS product_count
  FROM products.products
  GROUP BY brand_id
)
SELECT brand_id, product_count,
       ROW_NUMBER() OVER (ORDER BY product_count DESC) AS rn
FROM brand_counts
ORDER BY product_count DESC
LIMIT 3;

/* Q98. */
SELECT employee_id, store_id, salary,
       NTILE(4) OVER (PARTITION BY store_id ORDER BY salary) AS salary_quartile
FROM stores.employees
ORDER BY store_id, salary_quartile
LIMIT 50;

/* Q99. */
WITH ranked AS (
  SELECT product_id, product_name, brand_id, price,
         ROW_NUMBER() OVER (PARTITION BY brand_id ORDER BY price DESC) AS rn
  FROM products.products
)
SELECT brand_id, product_id, product_name, price
FROM ranked
WHERE rn = 3
ORDER BY brand_id
LIMIT 50;

/* Q100. */
WITH customer_spend AS (
  SELECT cust_id, SUM(net_total) AS total_spend
  FROM sales.orders
  WHERE order_status NOT IN ('Cancelled', 'Failed')
  GROUP BY cust_id
)
SELECT cust_id, total_spend,
       NTILE(4) OVER (ORDER BY total_spend DESC) AS spend_quartile,
       CASE NTILE(4) OVER (ORDER BY total_spend DESC)
         WHEN 1 THEN 'Q1 - Top Spenders' WHEN 2 THEN 'Q2' WHEN 3 THEN 'Q3' ELSE 'Q4 - Lowest Spenders' END AS rfm_monetary_label
FROM customer_spend
ORDER BY spend_quartile, total_spend DESC
LIMIT 50;

/* ============================================================
   END OF ANSWER KEY - EASY LEVEL (100/100)
============================================================ */
