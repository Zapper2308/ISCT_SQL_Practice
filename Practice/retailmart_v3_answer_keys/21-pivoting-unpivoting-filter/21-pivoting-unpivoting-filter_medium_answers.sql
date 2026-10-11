/* ============================================================
   ANSWER KEY - Pivoting, Unpivoting & FILTER (MEDIUM LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1.  The row key defines the grain of the output (one row per distinct value), while each pivoted column is its own independent FILTERed/CASE aggregate - so only the row dimension needs a GROUP BY, the column dimension is expressed entirely inside the SELECT list. */
/* Q2.  Add one more aggregate column with no FILTER/CASE condition (e.g. SUM(x) AS row_total) alongside the FILTERed columns - it naturally sums across every category since it isn't restricted. */
/* Q3.  Either UNION ALL an extra query with no GROUP BY (or a literal 'TOTAL' row label) to the pivot, or use GROUP BY GROUPING SETS ((row_key), ()) so the () entry produces the grand-total row in the same result set. */
/* Q4.  Compute the row's total once (e.g. via a window SUM(...) OVER (PARTITION BY row_key)) and divide each pivoted cell by that total. */
/* Q5.  Divide each cell by a column total computed with SUM(cell) OVER () (grand total, no PARTITION BY) or a subquery that sums that one column across all rows. */
/* Q6.  Because FILTER attaches its WHERE clause only to the aggregate it's on, so COUNT(*) FILTER (WHERE a) and SUM(x) FILTER (WHERE b) in the same SELECT evaluate completely separate conditions without interfering. */
/* Q7.  Include both a COUNT(...) FILTER (WHERE cond) and a SUM(x) FILTER (WHERE cond) using the same condition in one SELECT list, grouped by the same row key - both use the row's grain, just different aggregate functions. */
/* Q8.  COALESCE a FILTERed SUM/AVG to 0 when a missing category should read as "zero activity"; leave it NULL (don't COALESCE) when "no data" is meaningfully different from "zero" - e.g. average rating with no reviews should stay NULL, not become a misleading 0. */
/* Q9.  Each UNION ALL branch selects one source column, paired with a literal string naming it, stacked together so N source columns become N rows with a (label, value) shape - the label column comes from the literal, the value column from the actual data. */
/* Q10. UNNEST(ARRAY['a','b'], ARRAY[val_a, val_b]) expands two parallel arrays into paired rows in lock-step, giving a (label, value) row per array position - useful when the labels/values can be built as arrays inline rather than written out as separate UNION ALL branches. */
/* Q11. Dynamic pivot needs crosstab() (tablefunc) or application code because SQL's SELECT list (and thus its column names/count) must be fixed before the query runs - it can't discover new category values from the data mid-query and add columns for them. */
/* Q12. GROUPING SETS produces every requested grouping level (detail, subtotal, grand total) in one query with explicit NULLs marking which columns were rolled up; a manual pivot only produces a fixed matrix of pre-named category columns, with no built-in subtotal rows. */
/* Q13. Compute the pivot's raw columns in a CTE, then add a further SELECT that divides one column by another (e.g. returned_units / NULLIF(delivered_units,0) AS return_rate) referencing the CTE's already-computed columns. */
/* Q14. Because a high-cardinality dimension would need one column per distinct value, quickly producing an unwieldy or even unbuildable SELECT list - a BI tool's pivot table widget handles that dynamically without needing SQL to predict every column. */
/* Q15. Yes - pivoting then unpivoting the exact same categories and aggregate should reconstruct rows whose (key, category, value) triples exactly match a direct GROUP BY on (key, category) over the original data. */
/* Q16. AVG FILTER (WHERE c) averages only the matching rows' values (can be NULL if none match); SUM/COUNT FILTER (WHERE c) total or count only the matching rows (naturally 0 for COUNT, NULL for SUM if none match) - same mechanism, different aggregate semantics for the "no rows matched" case. */
/* Q17. bool_or(condition) returns true if any row in the group satisfies condition (else false/null on 0 rows); bool_and(condition) returns true only if every row does - either can drive a CASE WHEN bool_or(...) THEN 'Yes' ELSE 'No' END yes/no column. */
/* Q18. Wrap the date column in date_trunc('month', col) or EXTRACT(QUARTER FROM col) inside each pivot column's CASE/FILTER condition, so distinct raw dates collapse into the desired period bucket before being counted into a column. */
/* Q19. Postgres requires every output column name to be a plain identifier known at parse time, so a pivot's column names must be literal aliases written in the query text - they can't be computed from data values at runtime. */
/* Q20. Add an explicit COALESCE(..., 0) around each FILTERed aggregate so a category with zero matching rows still emits the column with a 0 instead of a NULL, keeping the schema (and any downstream chart) stable across periods. */
/* Q21. UNION ALL unpivot writes one explicit SELECT per source column (verbose but very clear); a VALUES + JOIN (or LATERAL VALUES) inlines all the (label, value) pairs as a single table expression per row, often more compact for many columns but slightly less obvious to read. */
/* Q22. Divide each cell by SUM(cell) OVER () with no PARTITION BY, which sums that column across every row in the result, giving each cell its share of the whole matrix's total for that column (or nest further for the true grand total across all cells). */
/* Q23. Compute one window SUM(...) OVER (PARTITION BY row_key) for the row % denominator and a separate SUM(...) OVER () (no partition) for the column/grand % denominator, then divide the same cell by each to get two side-by-side percentage columns. */
/* Q24. jsonb_object_agg(category, value) builds a single JSON object per group mapping each category to its value dynamically - the "columns" become JSON keys decided at query time from the data, sidestepping SQL's fixed-column-list limitation (full JSON mechanics are Day 24). */
/* Q25. Checklist: confirm the row grain (GROUP BY key) is correct; every pivot column has an independent, correctly-scoped FILTER/CASE; COALESCE decisions (0 vs NULL) are deliberate; percentages divide by the right denominator (row/column/grand); and totals reconcile against a plain aggregate. */

/* ============================================================
   SECTION B: MULTI-DIMENSIONAL PIVOTS (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT r.region_name,
       COUNT(*) FILTER (WHERE o.order_status = 'Processing') AS processing,
       COUNT(*) FILTER (WHERE o.order_status = 'Shipped') AS shipped,
       COUNT(*) FILTER (WHERE o.order_status = 'Delivered') AS delivered,
       COUNT(*) FILTER (WHERE o.order_status = 'Cancelled') AS cancelled,
       COUNT(*) FILTER (WHERE o.order_status = 'Returned') AS returned
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q27. */
SELECT date_trunc('month', o.order_date)::date AS month,
       SUM(o.net_total) FILTER (WHERE pm.mode_name = 'Cash') AS cash,
       SUM(o.net_total) FILTER (WHERE pm.mode_name = 'UPI') AS upi,
       SUM(o.net_total) FILTER (WHERE pm.mode_name = 'Credit Card') AS credit_card,
       SUM(o.net_total) FILTER (WHERE pm.mode_name = 'Debit Card') AS debit_card
FROM sales.orders o
JOIN finance.payment_modes pm ON pm.mode_id = o.payment_mode_id
GROUP BY month
ORDER BY month;
/* Q28. */
SELECT brand_id,
       COUNT(*) FILTER (WHERE price < 1000) AS value_band,
       COUNT(*) FILTER (WHERE price BETWEEN 1000 AND 5000) AS mid_band,
       COUNT(*) FILTER (WHERE price > 5000) AS premium_band
FROM products.products
GROUP BY brand_id;
/* Q29. */
SELECT store_id,
       SUM(net_total) FILTER (WHERE EXTRACT(QUARTER FROM order_date) = 1) AS q1,
       SUM(net_total) FILTER (WHERE EXTRACT(QUARTER FROM order_date) = 2) AS q2,
       SUM(net_total) FILTER (WHERE EXTRACT(QUARTER FROM order_date) = 3) AS q3,
       SUM(net_total) FILTER (WHERE EXTRACT(QUARTER FROM order_date) = 4) AS q4
FROM sales.orders
WHERE EXTRACT(YEAR FROM order_date) = 2025
GROUP BY store_id
ORDER BY store_id;
/* Q30. */
SELECT cat.category_name,
       SUM(oi.quantity) FILTER (WHERE EXTRACT(MONTH FROM o.order_date) = 1) AS jan,
       SUM(oi.quantity) FILTER (WHERE EXTRACT(MONTH FROM o.order_date) = 2) AS feb,
       SUM(oi.quantity) FILTER (WHERE EXTRACT(MONTH FROM o.order_date) = 3) AS mar,
       SUM(oi.quantity) FILTER (WHERE EXTRACT(MONTH FROM o.order_date) = 4) AS apr,
       SUM(oi.quantity) FILTER (WHERE EXTRACT(MONTH FROM o.order_date) = 5) AS may,
       SUM(oi.quantity) FILTER (WHERE EXTRACT(MONTH FROM o.order_date) = 6) AS jun,
       SUM(oi.quantity) FILTER (WHERE EXTRACT(MONTH FROM o.order_date) = 7) AS jul,
       SUM(oi.quantity) FILTER (WHERE EXTRACT(MONTH FROM o.order_date) = 8) AS aug,
       SUM(oi.quantity) FILTER (WHERE EXTRACT(MONTH FROM o.order_date) = 9) AS sep,
       SUM(oi.quantity) FILTER (WHERE EXTRACT(MONTH FROM o.order_date) = 10) AS oct,
       SUM(oi.quantity) FILTER (WHERE EXTRACT(MONTH FROM o.order_date) = 11) AS nov,
       SUM(oi.quantity) FILTER (WHERE EXTRACT(MONTH FROM o.order_date) = 12) AS dec
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
WHERE EXTRACT(YEAR FROM o.order_date) = 2025
GROUP BY cat.category_name
ORDER BY cat.category_name;
/* Q31. */
SELECT agent_id,
       COUNT(*) FILTER (WHERE priority = 'Critical') AS critical,
       COUNT(*) FILTER (WHERE priority = 'High') AS high,
       COUNT(*) FILTER (WHERE priority = 'Medium') AS medium,
       COUNT(*) FILTER (WHERE priority = 'Low') AS low
FROM support.tickets
GROUP BY agent_id;
/* Q32. */
SELECT r.region_name,
       COUNT(*) FILTER (WHERE c.tier = 'Bronze') AS bronze,
       COUNT(*) FILTER (WHERE c.tier = 'Silver') AS silver,
       COUNT(*) FILTER (WHERE c.tier = 'Gold') AS gold,
       COUNT(*) FILTER (WHERE c.tier = 'Platinum') AS platinum
FROM customers.customers c
JOIN customers.addresses a ON a.customer_id = c.customer_id
JOIN core.dim_region r ON r.state = a.state
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q33. */
SELECT product_id,
       COUNT(*) FILTER (WHERE rating = 1) AS r1,
       COUNT(*) FILTER (WHERE rating = 2) AS r2,
       COUNT(*) FILTER (WHERE rating = 3) AS r3,
       COUNT(*) FILTER (WHERE rating = 4) AS r4,
       COUNT(*) FILTER (WHERE rating = 5) AS r5
FROM customers.reviews
GROUP BY product_id;
/* Q34. */
SELECT courier_name,
       COUNT(*) FILTER (WHERE delivered_date - shipped_date <= 3) AS on_time,
       COUNT(*) FILTER (WHERE delivered_date - shipped_date > 3) AS late
FROM sales.shipments
WHERE delivered_date IS NOT NULL AND shipped_date IS NOT NULL
GROUP BY courier_name;
/* Q35. */
SELECT dept_id,
       COUNT(*) FILTER (WHERE role = 'Store Manager') AS store_manager,
       COUNT(*) FILTER (WHERE role = 'Store Associate') AS store_associate,
       COUNT(*) FILTER (WHERE role = 'Cashier') AS cashier,
       COUNT(*) FILTER (WHERE role = 'Sales Executive') AS sales_executive
FROM stores.employees
GROUP BY dept_id
ORDER BY dept_id;
/* Q36. */
SELECT store_id,
       SUM(net_total) FILTER (WHERE EXTRACT(DOW FROM order_date) = 1) AS mon,
       SUM(net_total) FILTER (WHERE EXTRACT(DOW FROM order_date) = 2) AS tue,
       SUM(net_total) FILTER (WHERE EXTRACT(DOW FROM order_date) = 3) AS wed,
       SUM(net_total) FILTER (WHERE EXTRACT(DOW FROM order_date) = 4) AS thu,
       SUM(net_total) FILTER (WHERE EXTRACT(DOW FROM order_date) = 5) AS fri,
       SUM(net_total) FILTER (WHERE EXTRACT(DOW FROM order_date) = 6) AS sat,
       SUM(net_total) FILTER (WHERE EXTRACT(DOW FROM order_date) = 0) AS sun
FROM sales.orders
GROUP BY store_id
ORDER BY store_id;
/* Q37. */
SELECT r.region_name,
       SUM(o.net_total) FILTER (WHERE pm.mode_name = 'Cash') AS cash,
       SUM(o.net_total) FILTER (WHERE pm.mode_name = 'UPI') AS upi,
       SUM(o.net_total) FILTER (WHERE pm.mode_name = 'Credit Card') AS credit_card,
       SUM(o.net_total) AS row_total
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
JOIN finance.payment_modes pm ON pm.mode_id = o.payment_mode_id
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q38. */
SELECT b.brand_name,
       SUM(oi.net_amount) FILTER (WHERE c.tier = 'Bronze') AS bronze,
       SUM(oi.net_amount) FILTER (WHERE c.tier = 'Silver') AS silver,
       SUM(oi.net_amount) FILTER (WHERE c.tier = 'Gold') AS gold,
       SUM(oi.net_amount) FILTER (WHERE c.tier = 'Platinum') AS platinum
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
JOIN customers.customers c ON c.customer_id = o.cust_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
GROUP BY b.brand_name
ORDER BY b.brand_name;
/* Q39. */
SELECT cat.category_name,
       SUM(oi.quantity) FILTER (WHERE EXISTS (SELECT 1 FROM sales.returns r WHERE r.order_id = oi.order_id AND r.prod_id = oi.prod_id)) AS returned_units,
       SUM(oi.quantity) FILTER (WHERE o.order_status = 'Delivered') AS delivered_units
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
GROUP BY cat.category_name
ORDER BY cat.category_name;
/* Q40. */
SELECT date_trunc('month', order_date)::date AS month,
       COUNT(*) FILTER (WHERE order_status = 'Delivered') AS delivered,
       COUNT(*) FILTER (WHERE order_status = 'Cancelled') AS cancelled,
       COUNT(*) FILTER (WHERE order_status = 'Returned') AS returned,
       COUNT(*) AS grand_total
FROM sales.orders
GROUP BY GROUPING SETS ((date_trunc('month', order_date)::date), ())
ORDER BY month NULLS LAST;
/* Q41. */
SELECT ws.warehouse_id,
       SUM(s.quantity_on_hand) FILTER (WHERE cat.category_name = 'Electronics') AS electronics,
       SUM(s.quantity_on_hand) FILTER (WHERE cat.category_name = 'Apparel') AS apparel,
       SUM(s.quantity_on_hand) AS total_stock
FROM supply_chain.inventory_snapshots s
JOIN supply_chain.warehouses ws ON ws.warehouse_id = s.warehouse_id
JOIN products.products p ON p.product_id = s.product_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
GROUP BY ws.warehouse_id
ORDER BY ws.warehouse_id;
/* Q42. */
SELECT EXTRACT(YEAR FROM c.registration_date) AS cohort_year,
       COUNT(*) FILTER (WHERE EXTRACT(YEAR FROM o.order_date) = EXTRACT(YEAR FROM c.registration_date)) AS same_year_orders,
       COUNT(*) FILTER (WHERE EXTRACT(YEAR FROM o.order_date) = EXTRACT(YEAR FROM c.registration_date) + 1) AS next_year_orders
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY cohort_year
ORDER BY cohort_year;
/* Q43. */
SELECT platform,
       SUM(amount) FILTER (WHERE EXTRACT(QUARTER FROM spend_date) = 1) AS q1,
       SUM(amount) FILTER (WHERE EXTRACT(QUARTER FROM spend_date) = 2) AS q2,
       SUM(amount) FILTER (WHERE EXTRACT(QUARTER FROM spend_date) = 3) AS q3,
       SUM(amount) FILTER (WHERE EXTRACT(QUARTER FROM spend_date) = 4) AS q4
FROM marketing.ads_spend
GROUP BY platform;
/* Q44. */
SELECT r.region_name,
       SUM(o.net_total) FILTER (WHERE EXTRACT(MONTH FROM o.order_date) IN (3,4,5)) AS spring,
       SUM(o.net_total) FILTER (WHERE EXTRACT(MONTH FROM o.order_date) IN (6,7,8)) AS summer,
       SUM(o.net_total) FILTER (WHERE EXTRACT(MONTH FROM o.order_date) IN (9,10,11)) AS autumn,
       SUM(o.net_total) FILTER (WHERE EXTRACT(MONTH FROM o.order_date) IN (12,1,2)) AS winter
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q45. */
SELECT store_id,
       COUNT(*) FILTER (WHERE net_total < 1000) AS low_band,
       COUNT(*) FILTER (WHERE net_total BETWEEN 1000 AND 5000) AS mid_band,
       COUNT(*) FILTER (WHERE net_total > 5000) AS high_band
FROM sales.orders
GROUP BY store_id
ORDER BY store_id;
/* Q46. */
SELECT a.city,
       COUNT(*) FILTER (WHERE c.tier = 'Bronze') AS bronze,
       COUNT(*) FILTER (WHERE c.tier = 'Silver') AS silver,
       COUNT(*) FILTER (WHERE c.tier = 'Gold') AS gold,
       COUNT(*) FILTER (WHERE c.tier = 'Platinum') AS platinum
FROM customers.customers c
JOIN customers.addresses a ON a.customer_id = c.customer_id
GROUP BY a.city
ORDER BY a.city;
/* Q47. */
SELECT p.product_id,
       SUM(oi.net_amount) FILTER (WHERE EXTRACT(MONTH FROM o.order_date) = 1) AS jan,
       SUM(oi.net_amount) FILTER (WHERE EXTRACT(MONTH FROM o.order_date) = 2) AS feb,
       SUM(oi.net_amount) FILTER (WHERE EXTRACT(MONTH FROM o.order_date) = 3) AS mar,
       SUM(oi.net_amount) AS row_total
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
JOIN products.products p ON p.product_id = oi.prod_id
WHERE EXTRACT(YEAR FROM o.order_date) = 2025
GROUP BY p.product_id;
/* Q48. */
SELECT agent_id,
       ROUND(AVG(EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600) FILTER (WHERE status = 'Open'), 2) AS open_avg_hrs,
       ROUND(AVG(EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600) FILTER (WHERE status = 'Resolved'), 2) AS resolved_avg_hrs
FROM support.tickets
GROUP BY agent_id;
/* Q49. */
SELECT r.region_name,
       COUNT(*) FILTER (WHERE o.order_status = 'Delivered') AS delivered_count,
       SUM(o.net_total) FILTER (WHERE o.order_status = 'Delivered') AS delivered_revenue,
       COUNT(*) FILTER (WHERE o.order_status = 'Cancelled') AS cancelled_count,
       SUM(o.net_total) FILTER (WHERE o.order_status = 'Cancelled') AS cancelled_revenue
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q50. */
SELECT cat.category_name,
       SUM(oi.net_amount) FILTER (WHERE EXTRACT(QUARTER FROM o.order_date) = 1) AS q1,
       SUM(oi.net_amount) FILTER (WHERE EXTRACT(QUARTER FROM o.order_date) = 2) AS q2,
       SUM(oi.net_amount) FILTER (WHERE EXTRACT(QUARTER FROM o.order_date) = 3) AS q3,
       SUM(oi.net_amount) FILTER (WHERE EXTRACT(QUARTER FROM o.order_date) = 4) AS q4,
       SUM(oi.net_amount) AS row_total
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
WHERE EXTRACT(YEAR FROM o.order_date) = 2025
GROUP BY GROUPING SETS ((cat.category_name), ())
ORDER BY cat.category_name NULLS LAST;

/* ============================================================
   SECTION C: PERCENT-OF-TOTAL PIVOTS (25)
   ------------------------------------------------------------ */
/* Q51. */
SELECT r.region_name,
       ROUND(100.0 * COUNT(*) FILTER (WHERE o.order_status = 'Delivered') / COUNT(*), 2) AS pct_delivered,
       ROUND(100.0 * COUNT(*) FILTER (WHERE o.order_status = 'Cancelled') / COUNT(*), 2) AS pct_cancelled
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q52. */
SELECT date_trunc('month', o.order_date)::date AS month,
       pm.mode_name,
       SUM(o.net_total) AS revenue,
       ROUND(100.0 * SUM(o.net_total) / SUM(SUM(o.net_total)) OVER (PARTITION BY date_trunc('month', o.order_date)::date), 2) AS pct_of_month
FROM sales.orders o
JOIN finance.payment_modes pm ON pm.mode_id = o.payment_mode_id
GROUP BY month, pm.mode_name
ORDER BY month, pm.mode_name;
/* Q53. */
SELECT brand_id,
       ROUND(100.0 * COUNT(*) FILTER (WHERE price < 1000) / COUNT(*), 2) AS pct_value,
       ROUND(100.0 * COUNT(*) FILTER (WHERE price BETWEEN 1000 AND 5000) / COUNT(*), 2) AS pct_mid,
       ROUND(100.0 * COUNT(*) FILTER (WHERE price > 5000) / COUNT(*), 2) AS pct_premium
FROM products.products
GROUP BY brand_id;
/* Q54. */
SELECT store_id,
       EXTRACT(QUARTER FROM order_date) AS quarter,
       SUM(net_total) AS revenue,
       ROUND(100.0 * SUM(net_total) / SUM(SUM(net_total)) OVER (PARTITION BY store_id), 2) AS pct_of_store_year
FROM sales.orders
WHERE EXTRACT(YEAR FROM order_date) = 2025
GROUP BY store_id, quarter
ORDER BY store_id, quarter;
/* Q55. */
SELECT cat.category_name,
       EXTRACT(MONTH FROM o.order_date) AS month,
       SUM(oi.quantity) AS units,
       ROUND(100.0 * SUM(oi.quantity) / SUM(SUM(oi.quantity)) OVER (PARTITION BY cat.category_name), 2) AS pct_of_category_year
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
WHERE EXTRACT(YEAR FROM o.order_date) = 2025
GROUP BY cat.category_name, month
ORDER BY cat.category_name, month;
/* Q56. */
SELECT agent_id,
       priority,
       COUNT(*) AS ticket_count,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY agent_id), 2) AS pct_of_agent
FROM support.tickets
GROUP BY agent_id, priority
ORDER BY agent_id, priority;
/* Q57. */
SELECT r.region_name,
       c.tier,
       COUNT(*) AS customer_count,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY r.region_name), 2) AS pct_of_region
FROM customers.customers c
JOIN customers.addresses a ON a.customer_id = c.customer_id
JOIN core.dim_region r ON r.state = a.state
GROUP BY r.region_name, c.tier
ORDER BY r.region_name, c.tier;
/* Q58. */
SELECT product_id,
       rating,
       COUNT(*) AS review_count,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY product_id), 2) AS pct_of_product_reviews
FROM customers.reviews
GROUP BY product_id, rating
ORDER BY product_id, rating;
/* Q59. */
SELECT courier_name,
       ROUND(100.0 * COUNT(*) FILTER (WHERE delivered_date - shipped_date <= 3) / COUNT(*), 2) AS pct_on_time
FROM sales.shipments
WHERE delivered_date IS NOT NULL AND shipped_date IS NOT NULL
GROUP BY courier_name;
/* Q60. */
SELECT dept_id,
       role,
       COUNT(*) AS headcount,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY dept_id), 2) AS pct_of_dept
FROM stores.employees
GROUP BY dept_id, role
ORDER BY dept_id, role;
/* Q61. */
SELECT store_id,
       EXTRACT(DOW FROM order_date) AS weekday,
       SUM(net_total) AS revenue,
       ROUND(100.0 * SUM(net_total) / SUM(SUM(net_total)) OVER (PARTITION BY store_id), 2) AS pct_of_store_week
FROM sales.orders
GROUP BY store_id, weekday
ORDER BY store_id, weekday;
/* Q62. */
SELECT r.region_name,
       o.order_status,
       COUNT(*) AS order_count,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_grand_total
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name, o.order_status
ORDER BY r.region_name, o.order_status;
/* Q63. */
SELECT b.brand_name,
       c.tier,
       SUM(oi.net_amount) AS revenue,
       ROUND(100.0 * SUM(oi.net_amount) / SUM(SUM(oi.net_amount)) OVER (PARTITION BY b.brand_name), 2) AS pct_of_brand
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
JOIN customers.customers c ON c.customer_id = o.cust_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
GROUP BY b.brand_name, c.tier
ORDER BY b.brand_name, c.tier;
/* Q64. */
SELECT cat.category_name,
       ROUND(100.0 * SUM(oi.quantity) FILTER (WHERE EXISTS (SELECT 1 FROM sales.returns r WHERE r.order_id = oi.order_id AND r.prod_id = oi.prod_id))
             / NULLIF(SUM(oi.quantity) FILTER (WHERE o.order_status = 'Delivered'), 0), 2) AS return_rate_pct
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
GROUP BY cat.category_name
ORDER BY cat.category_name;
/* Q65. */
SELECT date_trunc('month', order_date)::date AS month,
       order_status,
       COUNT(*) AS cnt,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY date_trunc('month', order_date)::date), 2) AS pct_of_month,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_all_time
FROM sales.orders
GROUP BY month, order_status
ORDER BY month, order_status;
/* Q66. */
SELECT ws.warehouse_id,
       cat.category_name,
       SUM(s.quantity_on_hand) AS stock,
       ROUND(100.0 * SUM(s.quantity_on_hand) / SUM(SUM(s.quantity_on_hand)) OVER (PARTITION BY ws.warehouse_id), 2) AS pct_of_warehouse
FROM supply_chain.inventory_snapshots s
JOIN supply_chain.warehouses ws ON ws.warehouse_id = s.warehouse_id
JOIN products.products p ON p.product_id = s.product_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
GROUP BY ws.warehouse_id, cat.category_name
ORDER BY ws.warehouse_id, cat.category_name;
/* Q67. */
WITH cohort_sizes AS (
  SELECT EXTRACT(YEAR FROM registration_date) AS cohort_year, COUNT(*) AS cohort_size
  FROM customers.customers
  GROUP BY cohort_year
),
returning_cust AS (
  SELECT EXTRACT(YEAR FROM c.registration_date) AS cohort_year, COUNT(DISTINCT o.cust_id) AS returning_customers
  FROM customers.customers c
  JOIN sales.orders o ON o.cust_id = c.customer_id AND EXTRACT(YEAR FROM o.order_date) = EXTRACT(YEAR FROM c.registration_date) + 1
  GROUP BY cohort_year
)
SELECT cs.cohort_year, r.returning_customers,
       ROUND(100.0 * r.returning_customers / cs.cohort_size, 2) AS pct_of_cohort
FROM cohort_sizes cs
JOIN returning_cust r ON r.cohort_year = cs.cohort_year
ORDER BY cs.cohort_year;
/* Q68. */
SELECT platform,
       EXTRACT(QUARTER FROM spend_date) AS quarter,
       SUM(amount) AS spend,
       ROUND(100.0 * SUM(amount) / SUM(SUM(amount)) OVER (PARTITION BY platform), 2) AS pct_of_platform
FROM marketing.ads_spend
GROUP BY platform, quarter
ORDER BY platform, quarter;
/* Q69. */
SELECT r.region_name,
       CASE WHEN EXTRACT(MONTH FROM o.order_date) IN (3,4,5) THEN 'Spring'
            WHEN EXTRACT(MONTH FROM o.order_date) IN (6,7,8) THEN 'Summer'
            WHEN EXTRACT(MONTH FROM o.order_date) IN (9,10,11) THEN 'Autumn'
            ELSE 'Winter' END AS season,
       SUM(o.net_total) AS revenue,
       ROUND(100.0 * SUM(o.net_total) / SUM(SUM(o.net_total)) OVER (PARTITION BY r.region_name), 2) AS pct_of_region_annual
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name, season
ORDER BY r.region_name, season;
/* Q70. */
SELECT store_id,
       CASE WHEN net_total < 1000 THEN 'low' WHEN net_total BETWEEN 1000 AND 5000 THEN 'mid' ELSE 'high' END AS net_total_band,
       COUNT(*) AS cnt,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY store_id), 2) AS pct_of_store
FROM sales.orders
GROUP BY store_id, net_total_band
ORDER BY store_id, net_total_band;
/* Q71. */
SELECT a.city,
       c.tier,
       COUNT(*) AS cnt,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY a.city), 2) AS pct_of_city
FROM customers.customers c
JOIN customers.addresses a ON a.customer_id = c.customer_id
GROUP BY a.city, c.tier
ORDER BY a.city, c.tier;
/* Q72. */
SELECT p.product_id,
       EXTRACT(MONTH FROM o.order_date) AS month,
       SUM(oi.net_amount) AS revenue,
       ROUND(100.0 * SUM(oi.net_amount) / SUM(SUM(oi.net_amount)) OVER (PARTITION BY p.product_id), 2) AS pct_of_product_annual
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
JOIN products.products p ON p.product_id = oi.prod_id
WHERE EXTRACT(YEAR FROM o.order_date) = 2025
GROUP BY p.product_id, month
ORDER BY p.product_id, month;
/* Q73. */
SELECT r.region_name,
       o.order_status,
       COUNT(*) AS cnt,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY r.region_name), 2) AS pct_of_row,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY o.order_status), 2) AS pct_of_column
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name, o.order_status
ORDER BY r.region_name, o.order_status;
/* Q74. */
SELECT cat.category_name,
       EXTRACT(QUARTER FROM o.order_date) AS quarter,
       SUM(oi.net_amount) AS revenue,
       ROUND(100.0 * SUM(oi.net_amount) / SUM(SUM(oi.net_amount)) OVER (), 2) AS pct_of_grand_total
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
WHERE EXTRACT(YEAR FROM o.order_date) = 2025
GROUP BY cat.category_name, quarter
ORDER BY cat.category_name, quarter;
/* Q75. */
SELECT r.region_name,
       o.order_status,
       COUNT(*) AS cnt,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY r.region_name), 2) AS pct_of_region
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name, o.order_status
ORDER BY r.region_name, o.order_status;

/* ============================================================
   SECTION D: UNPIVOT & TIDY (25)
   ------------------------------------------------------------ */
/* Q76. */
SELECT summary_date, 'total_revenue' AS metric, total_revenue AS value FROM finance.revenue_summary
UNION ALL SELECT summary_date, 'total_orders', total_orders::numeric FROM finance.revenue_summary
UNION ALL SELECT summary_date, 'avg_order_value', avg_order_value FROM finance.revenue_summary
ORDER BY summary_date, metric;
/* Q77. */
SELECT pay_slip_id, 'basic_salary' AS component, basic_salary AS amount FROM payroll.pay_slips
UNION ALL SELECT pay_slip_id, 'hra', hra FROM payroll.pay_slips
UNION ALL SELECT pay_slip_id, 'other_allowances', other_allowances FROM payroll.pay_slips
UNION ALL SELECT pay_slip_id, 'pf', pf FROM payroll.pay_slips
UNION ALL SELECT pay_slip_id, 'professional_tax', professional_tax FROM payroll.pay_slips
UNION ALL SELECT pay_slip_id, 'income_tax', income_tax FROM payroll.pay_slips
ORDER BY pay_slip_id, component;
/* Q78. */
WITH piv AS (
  SELECT SUM(net_total) FILTER (WHERE EXTRACT(QUARTER FROM order_date) = 1) AS q1,
         SUM(net_total) FILTER (WHERE EXTRACT(QUARTER FROM order_date) = 2) AS q2,
         SUM(net_total) FILTER (WHERE EXTRACT(QUARTER FROM order_date) = 3) AS q3,
         SUM(net_total) FILTER (WHERE EXTRACT(QUARTER FROM order_date) = 4) AS q4
  FROM sales.orders WHERE EXTRACT(YEAR FROM order_date) = 2025
)
SELECT 'Q1' AS quarter, q1 AS revenue FROM piv
UNION ALL SELECT 'Q2', q2 FROM piv
UNION ALL SELECT 'Q3', q3 FROM piv
UNION ALL SELECT 'Q4', q4 FROM piv;
/* Q79. */
SELECT campaign_id, 'sent' AS stage, emails_sent AS count FROM marketing.email_clicks
UNION ALL SELECT campaign_id, 'opened', emails_opened FROM marketing.email_clicks
UNION ALL SELECT campaign_id, 'clicked', emails_clicked FROM marketing.email_clicks
ORDER BY campaign_id, stage;
/* Q80. */
SELECT order_id, 'gross_total' AS kind, gross_total AS amount FROM sales.orders
UNION ALL SELECT order_id, 'discount_amount', discount_amount FROM sales.orders
UNION ALL SELECT order_id, 'net_total', net_total FROM sales.orders
ORDER BY order_id, kind;
/* Q81. */
SELECT product_id, 'price' AS kind, price AS amount FROM products.products
UNION ALL SELECT product_id, 'cost_price', cost_price FROM products.products
ORDER BY product_id, kind;
/* Q82. */
SELECT 'min_salary' AS field, min_salary AS value, min_salary AS bracket FROM payroll.tax_brackets
UNION ALL SELECT 'max_salary', max_salary, min_salary FROM payroll.tax_brackets
UNION ALL SELECT 'tax_rate', tax_rate, min_salary FROM payroll.tax_brackets
ORDER BY bracket, field;
/* Q83. */
SELECT o.order_id, k, v
FROM sales.orders o,
     UNNEST(ARRAY['gross_total', 'discount_amount', 'net_total'],
            ARRAY[o.gross_total, o.discount_amount, o.net_total]) AS t(k, v);
/* Q84. */
SELECT date_trunc('month', summary_date)::date AS month, 'total_revenue' AS metric, SUM(total_revenue) AS value
FROM finance.revenue_summary GROUP BY month
UNION ALL
SELECT date_trunc('month', summary_date)::date, 'avg_order_value', AVG(avg_order_value)
FROM finance.revenue_summary GROUP BY date_trunc('month', summary_date)::date
ORDER BY month, metric;
/* Q85. */
SELECT customer_id, 'email' AS channel, email AS value FROM customers.customers
UNION ALL SELECT customer_id, 'phone', phone FROM customers.customers
ORDER BY customer_id, channel;
/* Q86. */
SELECT order_id, 'shipped' AS event_type, shipped_date AS event_date FROM sales.shipments
UNION ALL SELECT order_id, 'delivered', delivered_date FROM sales.shipments
ORDER BY order_id, event_type;
/* Q87. */
SELECT store_id, 'opening_date' AS field, opening_date AS event_date FROM stores.stores
ORDER BY store_id;
/* Q88. */
WITH piv AS (
  SELECT r.region_name,
         COUNT(*) FILTER (WHERE o.order_status = 'Delivered') AS delivered,
         COUNT(*) FILTER (WHERE o.order_status = 'Cancelled') AS cancelled
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  JOIN core.dim_region r ON r.region_id = s.region_id
  GROUP BY r.region_name
),
unpiv AS (
  SELECT region_name, 'Delivered' AS order_status, delivered AS cnt FROM piv
  UNION ALL SELECT region_name, 'Cancelled', cancelled FROM piv
)
SELECT region_name, SUM(cnt) AS total_pivot_derived
FROM unpiv GROUP BY region_name
ORDER BY region_name;
/* Q89. */
SELECT session_id, 'page_view' AS funnel_stage, COUNT(*) AS cnt
FROM web_events.page_views
GROUP BY session_id;
/* Q90. */
WITH long_form AS (
  SELECT order_id, 'gross_total' AS kind, gross_total AS amount FROM sales.orders
  UNION ALL SELECT order_id, 'net_total', net_total FROM sales.orders
)
SELECT kind, SUM(amount) AS total FROM long_form GROUP BY kind ORDER BY kind;
/* Q91. */
SELECT campaign_id, 'amount' AS metric, amount AS value FROM marketing.ads_spend
ORDER BY campaign_id;
/* Q92. */
WITH piv AS (
  SELECT store_id,
         SUM(net_total) FILTER (WHERE EXTRACT(MONTH FROM order_date) = 1) AS m1,
         SUM(net_total) FILTER (WHERE EXTRACT(MONTH FROM order_date) = 2) AS m2,
         SUM(net_total) FILTER (WHERE EXTRACT(MONTH FROM order_date) = 3) AS m3
  FROM sales.orders WHERE EXTRACT(YEAR FROM order_date) = 2025
  GROUP BY store_id
)
SELECT store_id, 'Jan' AS month, m1 AS revenue FROM piv
UNION ALL SELECT store_id, 'Feb', m2 FROM piv
UNION ALL SELECT store_id, 'Mar', m3 FROM piv
ORDER BY store_id, month;
/* Q93. */
SELECT o.order_id, v.kind, v.amount
FROM sales.orders o
CROSS JOIN LATERAL (VALUES ('gross_total', o.gross_total), ('discount_amount', o.discount_amount), ('net_total', o.net_total)) AS v(kind, amount);
/* Q94. */
SELECT product_id, 'product_name' AS attribute, product_name AS value FROM products.products
UNION ALL SELECT product_id, 'price', price::text FROM products.products
UNION ALL SELECT product_id, 'cost_price', cost_price::text FROM products.products
ORDER BY product_id, attribute;
/* Q95. */
SELECT r.region_name, 'order_count' AS metric, COUNT(*)::numeric AS value
FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
UNION ALL
SELECT r.region_name, 'revenue', SUM(o.net_total)
FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY region_name, metric;
/* Q96. */
WITH region_status AS (
  SELECT r.region_name, o.order_status, COUNT(*) AS cnt
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  JOIN core.dim_region r ON r.region_id = s.region_id
  GROUP BY r.region_name, o.order_status
)
SELECT order_status,
       SUM(cnt) FILTER (WHERE region_name = 'North') AS north,
       SUM(cnt) FILTER (WHERE region_name = 'South') AS south,
       SUM(cnt) FILTER (WHERE region_name = 'East') AS east,
       SUM(cnt) FILTER (WHERE region_name = 'West') AS west
FROM region_status
GROUP BY order_status
ORDER BY order_status;
/* Q97. Both forms group over the same underlying facts, so they're interchangeable for readability preference - UNION ALL is very explicit and easy for a beginner to trace column-by-column, while unnest with parallel arrays is more compact once a query has many source columns to unpivot at once. */
/* Q98. */
SELECT tier_id, 'min_points' AS field, min_points AS value FROM loyalty.tiers
UNION ALL SELECT tier_id, 'max_points', max_points FROM loyalty.tiers
ORDER BY tier_id, field;
/* Q99. crosstab() (tablefunc, accio_NN) handles the case where the pivot's column set is only known by querying the data itself (e.g. an ever-growing list of promo codes) - static FILTER/CASE pivots require every column name to already be known when the SQL is written. */
/* Q100. */
SELECT date_trunc('month', order_date)::date AS month, 'order_count' AS metric, COUNT(*)::numeric AS value
FROM sales.orders GROUP BY month
UNION ALL
SELECT date_trunc('month', order_date)::date, 'revenue', SUM(net_total)
FROM sales.orders GROUP BY date_trunc('month', order_date)::date
ORDER BY month, metric;

/* ============================================================
   END OF ANSWER KEY - Pivoting, Unpivoting & FILTER - MEDIUM LEVEL (100/100)
   ============================================================ */
