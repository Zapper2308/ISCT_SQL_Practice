/* ============================================================
   ANSWER KEY - Pivoting, Unpivoting & FILTER (EASY LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1.  Pivoting reshapes data so distinct values of one column become separate output columns, turning many rows into fewer, wider rows. */
/* Q2.  FILTER (WHERE ...) restricts which rows a single aggregate function sees, without affecting the other aggregates or the query's overall row set. */
/* Q3.  SUM(x) FILTER (WHERE c) */
/* Q4.  FILTER keeps the condition attached directly to its aggregate, so each column's logic is easy to scan, instead of burying WHEN/THEN branches inside a SUM/CASE nested expression. */
/* Q5.  Conditional aggregation means using CASE or FILTER inside an aggregate function so each aggregate only summarizes rows matching a specific condition. */
/* Q6.  Plain SQL has no way to generate column names at query-plan time from data values, so every pivot column must be named explicitly in the SELECT list up front. */
/* Q7.  crosstab() (from the tablefunc extension) builds a pivot with column names determined at query time from a second "category" query; it needs the extension because this isn't built into core SQL. */
/* Q8.  Unpivoting reshapes data so several columns become rows of (label, value) pairs, turning wide rows into more, narrower rows. */
/* Q9.  Each SELECT in the UNION ALL picks one source column and re-labels it with a literal string, and stacking those SELECTs with UNION ALL turns the wide row into one row per original column. */
/* Q10. Pivot in SQL when the category set is small and fixed (a handful of known statuses); leave it to the BI tool when categories are numerous, unknown in advance, or change often. */
/* Q11. FILTER only lets the aggregate itself see matching rows, and COUNT(*) simply counts however many rows reach it - so COUNT(*) FILTER (WHERE c) counts exactly the rows satisfying c. */
/* Q12. The GROUP BY key becomes the row label - each distinct combination of GROUP BY values becomes one output row in the pivot. */
/* Q13. COALESCE(SUM(x) FILTER (WHERE c), 0) - when no rows match a condition, SUM/COUNT can return NULL for that cell instead of 0, so wrapping in COALESCE gives a clean zero. */
/* Q14. Yes - GROUP BY still defines the row grain, and each FILTERed aggregate becomes one pivoted column per group. */
/* Q15. SUM(x) FILTER (WHERE c) only sums x for rows matching c within the current group; SUM(x) WHERE c isn't valid syntax at all - WHERE filters rows before any aggregation, affecting every aggregate in the SELECT list, not just one. */
/* Q16. unnest() expands an array into one row per element, so an array column can be turned into (row, element) pairs - a basic building block for unpivoting array-shaped data. */
/* Q17. It combines two dimensions (a time period and a category) into one matrix, which is exactly the shape a pivot produces - one row per period, one column per category. */
/* Q18. A pivot of N categories produces N output columns (plus any row-label columns from the GROUP BY). */
/* Q19. A high-cardinality column pivoted into columns could produce hundreds or thousands of columns, which is unwieldy in SQL and usually a sign the BI tool should handle it instead. */
/* Q20. Pivoting a count uses COUNT(*) FILTER (WHERE category=?, or CASE WHEN category=? THEN 1 END); pivoting a sum uses SUM(value) FILTER (WHERE category=?) - same shape, different aggregate function. */
/* Q21. Each FILTER clause is evaluated independently for its own aggregate, so different columns in the same SELECT can filter on completely unrelated conditions without interfering with each other. */
/* Q22. Use the literal string naming the source column as the label value in each UNION ALL branch, e.g. SELECT 'gross_total' AS metric, gross_total AS value. */
/* Q23. GROUPING SETS/ROLLUP is a better fit when you need several levels of subtotal (detail + group + grand total) in one result, rather than a fixed matrix of categories-as-columns. */
/* Q24. A "revenue by month per store" report and a "ticket count by priority per agent" report are pivots; a "wide KPI export turned into one row per metric" and "unpivoting pay_slip components" are unpivots. */
/* Q25. Pivots: "revenue by month per store" and "ticket count by priority per agent". Unpivots: "a wide KPI export turned into one row per metric" and "pay_slip components (basic/hra/pf/tax) turned into (component, amount) rows". */

/* ============================================================
   SECTION B: FILTER CLAUSE (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT COUNT(*) FILTER (WHERE order_status = 'Delivered') AS delivered_count,
       COUNT(*) FILTER (WHERE order_status = 'Cancelled') AS cancelled_count
FROM sales.orders;
/* Q27. */
SELECT SUM(net_total) FILTER (WHERE order_status = 'Delivered') AS delivered_revenue
FROM sales.orders;
/* Q28. */
SELECT store_id,
       COUNT(*) FILTER (WHERE order_status = 'Processing') AS processing,
       COUNT(*) FILTER (WHERE order_status = 'Shipped') AS shipped,
       COUNT(*) FILTER (WHERE order_status = 'Delivered') AS delivered,
       COUNT(*) FILTER (WHERE order_status = 'Cancelled') AS cancelled,
       COUNT(*) FILTER (WHERE order_status = 'Returned') AS returned
FROM sales.orders
GROUP BY store_id
ORDER BY store_id;
/* Q29. */
SELECT cust_id,
       COUNT(*) AS order_count,
       COUNT(*) FILTER (WHERE order_status = 'Returned') AS returned_count
FROM sales.orders
GROUP BY cust_id;
/* Q30. */
SELECT product_id,
       COUNT(*) FILTER (WHERE rating = 5) AS five_star,
       COUNT(*) FILTER (WHERE rating = 1) AS one_star
FROM customers.reviews
GROUP BY product_id;
/* Q31. */
SELECT agent_id,
       COUNT(*) FILTER (WHERE status = 'Open') AS open_count,
       COUNT(*) FILTER (WHERE status = 'Resolved') AS resolved_count
FROM support.tickets
GROUP BY agent_id;
/* Q32. */
SELECT r.region_name,
       SUM(o.net_total) AS total_revenue,
       SUM(o.net_total) FILTER (WHERE c.tier IN ('Gold', 'Platinum')) AS goldplatinum_revenue
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
JOIN customers.customers c ON c.customer_id = o.cust_id
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q33. */
SELECT date_trunc('month', order_date)::date AS month,
       SUM(net_total) FILTER (WHERE order_date >= DATE '2025-01-01') AS revenue_2025_onward,
       COUNT(*) FILTER (WHERE order_date >= DATE '2025-01-01') AS orders_2025_onward
FROM sales.orders
GROUP BY month
ORDER BY month;
/* Q34. */
SELECT COUNT(*) FILTER (WHERE phone IS NOT NULL) AS with_phone,
       COUNT(*) FILTER (WHERE phone IS NULL) AS without_phone
FROM customers.customers;
/* Q35. */
SELECT brand_id,
       COUNT(*) FILTER (WHERE price > 5000) AS above_5000,
       COUNT(*) FILTER (WHERE price <= 5000) AS at_or_below_5000
FROM products.products
GROUP BY brand_id;
/* Q36. */
SELECT store_id,
       SUM(net_total) FILTER (WHERE EXTRACT(YEAR FROM order_date) = 2025) AS revenue_2025,
       SUM(net_total) FILTER (WHERE EXTRACT(YEAR FROM order_date) = 2024) AS revenue_2024
FROM sales.orders
GROUP BY store_id
ORDER BY store_id;
/* Q37. */
SELECT courier_name,
       COUNT(*) FILTER (WHERE delivered_date - shipped_date <= 3) AS on_time,
       COUNT(*) FILTER (WHERE delivered_date - shipped_date > 3) AS late
FROM sales.shipments
WHERE delivered_date IS NOT NULL AND shipped_date IS NOT NULL
GROUP BY courier_name;
/* Q38. */
SELECT dept_id,
       COUNT(*) FILTER (WHERE salary > 50000) AS high_earners
FROM stores.employees
GROUP BY dept_id
ORDER BY dept_id;
/* Q39. */
SELECT platform,
       SUM(amount) FILTER (WHERE EXTRACT(QUARTER FROM spend_date) = 1) AS q1_spend,
       SUM(amount) FILTER (WHERE EXTRACT(QUARTER FROM spend_date) = 2) AS q2_spend
FROM marketing.ads_spend
GROUP BY platform;
/* Q40. */
SELECT cust_id,
       COUNT(*) FILTER (WHERE net_total < 1000) AS low_value,
       COUNT(*) FILTER (WHERE net_total BETWEEN 1000 AND 5000) AS mid_value,
       COUNT(*) FILTER (WHERE net_total > 5000) AS high_value
FROM sales.orders
GROUP BY cust_id;
/* Q41. */
SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE order_status = 'Delivered') / COUNT(*), 2) AS pct_delivered
FROM sales.orders;
/* Q42. */
SELECT cat.category_name,
       SUM(oi.net_amount) AS revenue,
       SUM(oi.quantity) AS units,
       SUM(oi.quantity) FILTER (WHERE EXISTS (
           SELECT 1 FROM sales.returns r WHERE r.order_id = oi.order_id AND r.prod_id = oi.prod_id
       )) AS returned_units
FROM sales.order_items oi
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
GROUP BY cat.category_name
ORDER BY cat.category_name;
/* Q43. */
SELECT r.region_name,
       COUNT(*) FILTER (WHERE s.opening_date < DATE '2023-01-01') AS before_2023,
       COUNT(*) FILTER (WHERE s.opening_date >= DATE '2023-01-01') AS from_2023
FROM stores.stores s
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q44. */
SELECT product_id,
       ROUND(AVG(rating), 2) AS avg_rating,
       COUNT(*) FILTER (WHERE rating <= 2) AS negative_reviews
FROM customers.reviews
GROUP BY product_id;
/* Q45. */
SELECT store_id,
       SUM(net_total) FILTER (WHERE EXTRACT(DOW FROM order_date) BETWEEN 1 AND 5) AS weekday_revenue,
       SUM(net_total) FILTER (WHERE EXTRACT(DOW FROM order_date) IN (0, 6)) AS weekend_revenue
FROM sales.orders
GROUP BY store_id
ORDER BY store_id;
/* Q46. */
SELECT COUNT(*) FILTER (WHERE payment_mode = 'Cash') AS cash,
       COUNT(*) FILTER (WHERE payment_mode = 'UPI') AS upi,
       COUNT(*) FILTER (WHERE payment_mode = 'Credit Card') AS credit_card,
       COUNT(*) FILTER (WHERE payment_mode = 'Debit Card') AS debit_card,
       COUNT(*) FILTER (WHERE payment_mode = 'Net Banking') AS net_banking,
       COUNT(*) FILTER (WHERE payment_mode = 'Wallet') AS wallet,
       COUNT(*) FILTER (WHERE payment_mode = 'EMI') AS emi,
       COUNT(*) FILTER (WHERE payment_mode = 'Gift Card') AS gift_card,
       COUNT(*) FILTER (WHERE payment_mode = 'Buy Now Pay Later') AS bnpl
FROM sales.payments;
/* Q47. */
SELECT agent_id,
       COUNT(*) FILTER (WHERE call_duration_seconds < 60) AS short_calls,
       COUNT(*) FILTER (WHERE call_duration_seconds > 300) AS long_calls
FROM call_center.calls
GROUP BY agent_id;
/* Q48. */
SELECT cust_id,
       SUM(net_total) FILTER (WHERE order_status = 'Delivered') AS delivered_spend,
       SUM(net_total) FILTER (WHERE order_status = 'Returned') AS returned_spend
FROM sales.orders
GROUP BY cust_id;
/* Q49. */
SELECT date_trunc('month', registration_date)::date AS month,
       COUNT(*) AS new_customers
FROM customers.customers
GROUP BY month
ORDER BY month;
/* Q50. */
SELECT store_id,
       COUNT(*) AS total_orders,
       COUNT(*) FILTER (WHERE order_status = 'Delivered') AS delivered,
       COUNT(*) FILTER (WHERE order_status = 'Cancelled') AS cancelled,
       COUNT(*) FILTER (WHERE order_status = 'Returned') AS returned,
       SUM(net_total) AS total_revenue
FROM sales.orders
GROUP BY store_id
ORDER BY store_id;

/* ============================================================
   SECTION C: CASE-BASED PIVOT (25)
   ------------------------------------------------------------ */
/* Q51. */
SELECT date_trunc('month', o.order_date)::date AS month,
       SUM(o.net_total) FILTER (WHERE pm.mode_name = 'Cash') AS cash,
       SUM(o.net_total) FILTER (WHERE pm.mode_name = 'UPI') AS upi,
       SUM(o.net_total) FILTER (WHERE pm.mode_name = 'Credit Card') AS credit_card,
       SUM(o.net_total) FILTER (WHERE pm.mode_name = 'Debit Card') AS debit_card,
       SUM(o.net_total) FILTER (WHERE pm.mode_name = 'Net Banking') AS net_banking
FROM sales.orders o
JOIN finance.payment_modes pm ON pm.mode_id = o.payment_mode_id
GROUP BY month
ORDER BY month;
/* Q52. */
SELECT r.region_name,
       COUNT(CASE WHEN o.order_status = 'Processing' THEN 1 END) AS processing,
       COUNT(CASE WHEN o.order_status = 'Shipped' THEN 1 END) AS shipped,
       COUNT(CASE WHEN o.order_status = 'Delivered' THEN 1 END) AS delivered,
       COUNT(CASE WHEN o.order_status = 'Cancelled' THEN 1 END) AS cancelled,
       COUNT(CASE WHEN o.order_status = 'Returned' THEN 1 END) AS returned
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q53. */
SELECT brand_id,
       COUNT(CASE WHEN price < 1000 THEN 1 END) AS value_band,
       COUNT(CASE WHEN price BETWEEN 1000 AND 5000 THEN 1 END) AS mid_band,
       COUNT(CASE WHEN price > 5000 THEN 1 END) AS premium_band
FROM products.products
GROUP BY brand_id;
/* Q54. */
SELECT store_id,
       SUM(CASE WHEN EXTRACT(QUARTER FROM order_date) = 1 THEN net_total END) AS q1,
       SUM(CASE WHEN EXTRACT(QUARTER FROM order_date) = 2 THEN net_total END) AS q2,
       SUM(CASE WHEN EXTRACT(QUARTER FROM order_date) = 3 THEN net_total END) AS q3,
       SUM(CASE WHEN EXTRACT(QUARTER FROM order_date) = 4 THEN net_total END) AS q4
FROM sales.orders
GROUP BY store_id
ORDER BY store_id;
/* Q55. */
SELECT cat.category_name,
       SUM(CASE WHEN EXTRACT(MONTH FROM o.order_date) = 1 THEN oi.quantity END) AS jan,
       SUM(CASE WHEN EXTRACT(MONTH FROM o.order_date) = 2 THEN oi.quantity END) AS feb,
       SUM(CASE WHEN EXTRACT(MONTH FROM o.order_date) = 3 THEN oi.quantity END) AS mar,
       SUM(CASE WHEN EXTRACT(MONTH FROM o.order_date) = 4 THEN oi.quantity END) AS apr,
       SUM(CASE WHEN EXTRACT(MONTH FROM o.order_date) = 5 THEN oi.quantity END) AS may,
       SUM(CASE WHEN EXTRACT(MONTH FROM o.order_date) = 6 THEN oi.quantity END) AS jun,
       SUM(CASE WHEN EXTRACT(MONTH FROM o.order_date) = 7 THEN oi.quantity END) AS jul,
       SUM(CASE WHEN EXTRACT(MONTH FROM o.order_date) = 8 THEN oi.quantity END) AS aug,
       SUM(CASE WHEN EXTRACT(MONTH FROM o.order_date) = 9 THEN oi.quantity END) AS sep,
       SUM(CASE WHEN EXTRACT(MONTH FROM o.order_date) = 10 THEN oi.quantity END) AS oct,
       SUM(CASE WHEN EXTRACT(MONTH FROM o.order_date) = 11 THEN oi.quantity END) AS nov,
       SUM(CASE WHEN EXTRACT(MONTH FROM o.order_date) = 12 THEN oi.quantity END) AS dec
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
WHERE EXTRACT(YEAR FROM o.order_date) = 2025
GROUP BY cat.category_name
ORDER BY cat.category_name;
/* Q56. */
SELECT agent_id,
       COUNT(CASE WHEN priority = 'Critical' THEN 1 END) AS critical,
       COUNT(CASE WHEN priority = 'High' THEN 1 END) AS high,
       COUNT(CASE WHEN priority = 'Medium' THEN 1 END) AS medium,
       COUNT(CASE WHEN priority = 'Low' THEN 1 END) AS low
FROM support.tickets
GROUP BY agent_id;
/* Q57. */
SELECT r.region_name,
       COUNT(CASE WHEN c.tier = 'Bronze' THEN 1 END) AS bronze,
       COUNT(CASE WHEN c.tier = 'Silver' THEN 1 END) AS silver,
       COUNT(CASE WHEN c.tier = 'Gold' THEN 1 END) AS gold,
       COUNT(CASE WHEN c.tier = 'Platinum' THEN 1 END) AS platinum
FROM customers.customers c
JOIN customers.addresses a ON a.customer_id = c.customer_id
JOIN core.dim_region r ON r.state = a.state
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q58. */
SELECT product_id,
       COUNT(CASE WHEN rating = 1 THEN 1 END) AS r1,
       COUNT(CASE WHEN rating = 2 THEN 1 END) AS r2,
       COUNT(CASE WHEN rating = 3 THEN 1 END) AS r3,
       COUNT(CASE WHEN rating = 4 THEN 1 END) AS r4,
       COUNT(CASE WHEN rating = 5 THEN 1 END) AS r5
FROM customers.reviews
GROUP BY product_id;
/* Q59. */
SELECT courier_name,
       COUNT(CASE WHEN status = 'Delivered' THEN 1 END) AS delivered,
       COUNT(CASE WHEN status = 'Shipped' THEN 1 END) AS shipped,
       COUNT(CASE WHEN status = 'Returned' THEN 1 END) AS returned
FROM sales.shipments
GROUP BY courier_name;
/* Q60. */
SELECT dept_id,
       COUNT(CASE WHEN role = 'Store Manager' THEN 1 END) AS store_manager,
       COUNT(CASE WHEN role = 'Store Associate' THEN 1 END) AS store_associate,
       COUNT(CASE WHEN role = 'Cashier' THEN 1 END) AS cashier,
       COUNT(CASE WHEN role = 'Sales Executive' THEN 1 END) AS sales_executive,
       COUNT(CASE WHEN role = 'Assistant Manager' THEN 1 END) AS assistant_manager
FROM stores.employees
GROUP BY dept_id
ORDER BY dept_id;
/* Q61. */
SELECT store_id,
       COUNT(CASE WHEN EXTRACT(DOW FROM order_date) = 1 THEN 1 END) AS mon,
       COUNT(CASE WHEN EXTRACT(DOW FROM order_date) = 2 THEN 1 END) AS tue,
       COUNT(CASE WHEN EXTRACT(DOW FROM order_date) = 3 THEN 1 END) AS wed,
       COUNT(CASE WHEN EXTRACT(DOW FROM order_date) = 4 THEN 1 END) AS thu,
       COUNT(CASE WHEN EXTRACT(DOW FROM order_date) = 5 THEN 1 END) AS fri,
       COUNT(CASE WHEN EXTRACT(DOW FROM order_date) = 6 THEN 1 END) AS sat,
       COUNT(CASE WHEN EXTRACT(DOW FROM order_date) = 0 THEN 1 END) AS sun
FROM sales.orders
GROUP BY store_id
ORDER BY store_id;
/* Q62. */
SELECT platform,
       SUM(CASE WHEN EXTRACT(QUARTER FROM spend_date) = 1 THEN amount END) AS q1,
       SUM(CASE WHEN EXTRACT(QUARTER FROM spend_date) = 2 THEN amount END) AS q2,
       SUM(CASE WHEN EXTRACT(QUARTER FROM spend_date) = 3 THEN amount END) AS q3,
       SUM(CASE WHEN EXTRACT(QUARTER FROM spend_date) = 4 THEN amount END) AS q4
FROM marketing.ads_spend
GROUP BY platform;
/* Q63. */
SELECT r.region_name,
       SUM(CASE WHEN pm.mode_name = 'Cash' THEN o.net_total END) AS cash,
       SUM(CASE WHEN pm.mode_name = 'UPI' THEN o.net_total END) AS upi,
       SUM(CASE WHEN pm.mode_name = 'Credit Card' THEN o.net_total END) AS credit_card,
       SUM(CASE WHEN pm.mode_name = 'Debit Card' THEN o.net_total END) AS debit_card
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
JOIN finance.payment_modes pm ON pm.mode_id = o.payment_mode_id
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q64. */
SELECT date_trunc('month', order_date)::date AS month,
       COUNT(CASE WHEN order_status = 'Processing' THEN 1 END) AS processing,
       COUNT(CASE WHEN order_status = 'Shipped' THEN 1 END) AS shipped,
       COUNT(CASE WHEN order_status = 'Delivered' THEN 1 END) AS delivered,
       COUNT(CASE WHEN order_status = 'Cancelled' THEN 1 END) AS cancelled,
       COUNT(CASE WHEN order_status = 'Returned' THEN 1 END) AS returned
FROM sales.orders
GROUP BY month
ORDER BY month;
/* Q65. */
SELECT b.brand_name,
       SUM(CASE WHEN c.tier = 'Bronze' THEN oi.net_amount END) AS bronze_revenue,
       SUM(CASE WHEN c.tier = 'Silver' THEN oi.net_amount END) AS silver_revenue,
       SUM(CASE WHEN c.tier = 'Gold' THEN oi.net_amount END) AS gold_revenue,
       SUM(CASE WHEN c.tier = 'Platinum' THEN oi.net_amount END) AS platinum_revenue
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
JOIN customers.customers c ON c.customer_id = o.cust_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
GROUP BY b.brand_name
ORDER BY b.brand_name;
/* Q66. */
SELECT ws.warehouse_id,
       SUM(CASE WHEN cat.category_name = cat.category_name THEN s.quantity_on_hand END) AS total_stock
FROM supply_chain.inventory_snapshots s
JOIN products.products p ON p.product_id = s.product_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
JOIN supply_chain.warehouses ws ON ws.warehouse_id = s.warehouse_id
GROUP BY ws.warehouse_id
ORDER BY ws.warehouse_id;
/* Q67. */
SELECT EXTRACT(YEAR FROM c.registration_date) AS cohort_year,
       COUNT(CASE WHEN EXTRACT(YEAR FROM o.order_date) = EXTRACT(YEAR FROM c.registration_date) + 1 THEN 1 END) AS orders_next_year
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY cohort_year
ORDER BY cohort_year;
/* Q68. */
SELECT store_id,
       SUM(CASE WHEN EXTRACT(YEAR FROM order_date) = 2025 THEN net_total END) AS revenue_2025,
       SUM(CASE WHEN EXTRACT(YEAR FROM order_date) = 2024 THEN net_total END) AS revenue_2024
FROM sales.orders
GROUP BY store_id
ORDER BY store_id;
/* Q69. */
SELECT cat.category_name,
       SUM(CASE WHEN EXISTS (SELECT 1 FROM sales.returns r WHERE r.order_id = oi.order_id AND r.prod_id = oi.prod_id) THEN oi.quantity END) AS returned_units,
       SUM(CASE WHEN o.order_status = 'Delivered' THEN oi.quantity END) AS delivered_units
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
GROUP BY cat.category_name
ORDER BY cat.category_name;
/* Q70. */
SELECT store_id,
       COALESCE(COUNT(CASE WHEN order_status = 'Cancelled' THEN 1 END), 0) AS cancelled,
       COALESCE(SUM(CASE WHEN order_status = 'Cancelled' THEN net_total END), 0) AS cancelled_revenue
FROM sales.orders
GROUP BY store_id
ORDER BY store_id;
/* Q71. */
SELECT r.region_name,
       ROUND(AVG(CASE WHEN EXTRACT(QUARTER FROM o.order_date) = 1 THEN o.net_total END), 2) AS q1_aov,
       ROUND(AVG(CASE WHEN EXTRACT(QUARTER FROM o.order_date) = 2 THEN o.net_total END), 2) AS q2_aov,
       ROUND(AVG(CASE WHEN EXTRACT(QUARTER FROM o.order_date) = 3 THEN o.net_total END), 2) AS q3_aov,
       ROUND(AVG(CASE WHEN EXTRACT(QUARTER FROM o.order_date) = 4 THEN o.net_total END), 2) AS q4_aov
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q72. */
SELECT oi.prod_id,
       SUM(CASE WHEN EXTRACT(MONTH FROM o.order_date) IN (3,4,5) THEN oi.quantity END) AS spring,
       SUM(CASE WHEN EXTRACT(MONTH FROM o.order_date) IN (6,7,8) THEN oi.quantity END) AS summer,
       SUM(CASE WHEN EXTRACT(MONTH FROM o.order_date) IN (9,10,11) THEN oi.quantity END) AS autumn,
       SUM(CASE WHEN EXTRACT(MONTH FROM o.order_date) IN (12,1,2) THEN oi.quantity END) AS winter
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
GROUP BY oi.prod_id;
/* Q73. */
SELECT agent_id,
       ROUND(AVG(CASE WHEN priority = 'Critical' THEN EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600 END), 2) AS critical_avg_hrs,
       ROUND(AVG(CASE WHEN priority = 'High' THEN EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600 END), 2) AS high_avg_hrs,
       ROUND(AVG(CASE WHEN priority = 'Medium' THEN EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600 END), 2) AS medium_avg_hrs,
       ROUND(AVG(CASE WHEN priority = 'Low' THEN EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600 END), 2) AS low_avg_hrs
FROM support.tickets
WHERE resolved_date IS NOT NULL
GROUP BY agent_id;
/* Q74. */
SELECT store_id,
       COUNT(CASE WHEN net_total < 1000 THEN 1 END) AS low_band,
       COUNT(CASE WHEN net_total BETWEEN 1000 AND 5000 THEN 1 END) AS mid_band,
       COUNT(CASE WHEN net_total > 5000 THEN 1 END) AS high_band,
       COUNT(*) AS row_total
FROM sales.orders
GROUP BY store_id
ORDER BY store_id;
/* Q75. */
SELECT order_status,
       COUNT(CASE WHEN EXTRACT(MONTH FROM order_date) = 1 THEN 1 END) AS jan,
       COUNT(CASE WHEN EXTRACT(MONTH FROM order_date) = 2 THEN 1 END) AS feb,
       COUNT(CASE WHEN EXTRACT(MONTH FROM order_date) = 3 THEN 1 END) AS mar,
       COUNT(CASE WHEN EXTRACT(MONTH FROM order_date) = 4 THEN 1 END) AS apr,
       COUNT(CASE WHEN EXTRACT(MONTH FROM order_date) = 5 THEN 1 END) AS may,
       COUNT(CASE WHEN EXTRACT(MONTH FROM order_date) = 6 THEN 1 END) AS jun
FROM sales.orders
WHERE EXTRACT(YEAR FROM order_date) = 2025
GROUP BY order_status
ORDER BY order_status;

/* ============================================================
   SECTION D: UNPIVOT & PERCENT-OF-ROW (25)
   ------------------------------------------------------------ */
/* Q76. */
WITH q AS (
  SELECT
    SUM(CASE WHEN EXTRACT(QUARTER FROM order_date) = 1 THEN net_total END) AS q1,
    SUM(CASE WHEN EXTRACT(QUARTER FROM order_date) = 2 THEN net_total END) AS q2,
    SUM(CASE WHEN EXTRACT(QUARTER FROM order_date) = 3 THEN net_total END) AS q3,
    SUM(CASE WHEN EXTRACT(QUARTER FROM order_date) = 4 THEN net_total END) AS q4
  FROM sales.orders WHERE EXTRACT(YEAR FROM order_date) = 2025
)
SELECT 'Q1' AS quarter, q1 AS revenue FROM q
UNION ALL SELECT 'Q2', q2 FROM q
UNION ALL SELECT 'Q3', q3 FROM q
UNION ALL SELECT 'Q4', q4 FROM q;
/* Q77. */
SELECT summary_date, 'total_revenue' AS metric, total_revenue AS value FROM finance.revenue_summary
UNION ALL SELECT summary_date, 'total_orders', total_orders::numeric FROM finance.revenue_summary
UNION ALL SELECT summary_date, 'avg_order_value', avg_order_value FROM finance.revenue_summary
ORDER BY summary_date, metric;
/* Q78. */
SELECT pay_slip_id, 'basic_salary' AS component, basic_salary AS amount FROM payroll.pay_slips
UNION ALL SELECT pay_slip_id, 'hra', hra FROM payroll.pay_slips
UNION ALL SELECT pay_slip_id, 'other_allowances', other_allowances FROM payroll.pay_slips
UNION ALL SELECT pay_slip_id, 'pf', pf FROM payroll.pay_slips
UNION ALL SELECT pay_slip_id, 'professional_tax', professional_tax FROM payroll.pay_slips
UNION ALL SELECT pay_slip_id, 'income_tax', income_tax FROM payroll.pay_slips
ORDER BY pay_slip_id, component;
/* Q79. */
WITH q AS (
  SELECT
    SUM(CASE WHEN EXTRACT(QUARTER FROM o.order_date) = 1 THEN o.net_total END) AS q1,
    SUM(CASE WHEN EXTRACT(QUARTER FROM o.order_date) = 2 THEN o.net_total END) AS q2,
    SUM(CASE WHEN EXTRACT(QUARTER FROM o.order_date) = 3 THEN o.net_total END) AS q3,
    SUM(CASE WHEN EXTRACT(QUARTER FROM o.order_date) = 4 THEN o.net_total END) AS q4
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  JOIN core.dim_region r ON r.region_id = s.region_id
  WHERE r.region_name = 'North' AND EXTRACT(YEAR FROM o.order_date) = 2025
)
SELECT 'Q1' AS quarter, q1 AS revenue FROM q
UNION ALL SELECT 'Q2', q2 FROM q
UNION ALL SELECT 'Q3', q3 FROM q
UNION ALL SELECT 'Q4', q4 FROM q;
/* Q80. */
SELECT email_id, 'sent' AS stage, emails_sent AS count FROM marketing.email_clicks
UNION ALL SELECT email_id, 'opened', emails_opened FROM marketing.email_clicks
UNION ALL SELECT email_id, 'clicked', emails_clicked FROM marketing.email_clicks
ORDER BY email_id, stage;
/* Q81. */
SELECT product_id, 'price' AS kind, price AS amount FROM products.products
UNION ALL SELECT product_id, 'cost_price', cost_price FROM products.products
ORDER BY product_id, kind;
/* Q82. */
SELECT order_id, 'gross_total' AS kind, gross_total AS amount FROM sales.orders
UNION ALL SELECT order_id, 'discount_amount', discount_amount FROM sales.orders
UNION ALL SELECT order_id, 'net_total', net_total FROM sales.orders
ORDER BY order_id, kind;
/* Q83. */
SELECT store_id,
       COUNT(CASE WHEN order_status = 'Delivered' THEN 1 END) AS delivered,
       COUNT(*) AS total,
       ROUND(100.0 * COUNT(CASE WHEN order_status = 'Delivered' THEN 1 END) / COUNT(*), 2) AS pct_delivered
FROM sales.orders
GROUP BY store_id
ORDER BY store_id;
/* Q84. */
SELECT r.region_name,
       ROUND(100.0 * COUNT(CASE WHEN o.order_status = 'Delivered' THEN 1 END) / COUNT(*), 2) AS pct_delivered,
       ROUND(100.0 * COUNT(CASE WHEN o.order_status = 'Cancelled' THEN 1 END) / COUNT(*), 2) AS pct_cancelled,
       ROUND(100.0 * COUNT(CASE WHEN o.order_status = 'Returned' THEN 1 END) / COUNT(*), 2) AS pct_returned
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q85. */
SELECT pm.mode_name AS payment_mode,
       SUM(o.net_total) AS revenue,
       ROUND(100.0 * SUM(o.net_total) / SUM(SUM(o.net_total)) OVER (), 2) AS pct_of_total
FROM sales.orders o
JOIN finance.payment_modes pm ON pm.mode_id = o.payment_mode_id
GROUP BY pm.mode_name
ORDER BY pm.mode_name;
/* Q86. */
SELECT date_trunc('month', summary_date)::date AS month, 'total_revenue' AS metric, SUM(total_revenue) AS value
FROM finance.revenue_summary GROUP BY month
UNION ALL
SELECT date_trunc('month', summary_date)::date, 'total_orders', SUM(total_orders)
FROM finance.revenue_summary GROUP BY date_trunc('month', summary_date)::date
ORDER BY month, metric;
/* Q87. */
SELECT o.order_id, k, v
FROM sales.orders o,
     UNNEST(ARRAY['gross_total', 'discount_amount', 'net_total'],
            ARRAY[o.gross_total, o.discount_amount, o.net_total]) AS t(k, v);
/* Q88. */
SELECT order_id, 'shipped' AS event, shipped_date AS event_date FROM sales.shipments
UNION ALL SELECT order_id, 'delivered', delivered_date FROM sales.shipments
ORDER BY order_id, event;
/* Q89. */
SELECT brand_id,
       ROUND(100.0 * COUNT(CASE WHEN price < 1000 THEN 1 END) / COUNT(*), 2) AS pct_value,
       ROUND(100.0 * COUNT(CASE WHEN price BETWEEN 1000 AND 5000 THEN 1 END) / COUNT(*), 2) AS pct_mid,
       ROUND(100.0 * COUNT(CASE WHEN price > 5000 THEN 1 END) / COUNT(*), 2) AS pct_premium
FROM products.products
GROUP BY brand_id;
/* Q90. */
SELECT customer_id, 'email' AS channel, email AS value FROM customers.customers
UNION ALL SELECT customer_id, 'phone', phone FROM customers.customers
ORDER BY customer_id, channel;
/* Q91. */
SELECT date_trunc('week', order_date)::date AS week,
       COUNT(CASE WHEN order_status = 'Delivered' THEN 1 END) AS delivered,
       COUNT(*) AS total,
       ROUND(100.0 * COUNT(CASE WHEN order_status = 'Delivered' THEN 1 END) / COUNT(*), 2) AS pct_delivered
FROM sales.orders
GROUP BY week
ORDER BY week;
/* Q92. */
SELECT min_salary, 'min_salary' AS field, min_salary AS value FROM payroll.tax_brackets
UNION ALL SELECT min_salary, 'max_salary', max_salary FROM payroll.tax_brackets
UNION ALL SELECT min_salary, 'tax_rate', tax_rate FROM payroll.tax_brackets
ORDER BY min_salary, field;
/* Q93. */
SELECT r.region_name,
       COUNT(CASE WHEN o.order_status = 'Delivered' THEN 1 END) AS delivered_count,
       ROUND(100.0 * COUNT(CASE WHEN o.order_status = 'Delivered' THEN 1 END)
             / SUM(COUNT(CASE WHEN o.order_status = 'Delivered' THEN 1 END)) OVER (), 2) AS pct_of_all_delivered
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q94. */
WITH q AS (
  SELECT store_id,
    SUM(CASE WHEN EXTRACT(QUARTER FROM order_date) = 1 THEN net_total END) AS q1,
    SUM(CASE WHEN EXTRACT(QUARTER FROM order_date) = 2 THEN net_total END) AS q2,
    SUM(CASE WHEN EXTRACT(QUARTER FROM order_date) = 3 THEN net_total END) AS q3,
    SUM(CASE WHEN EXTRACT(QUARTER FROM order_date) = 4 THEN net_total END) AS q4
  FROM sales.orders WHERE EXTRACT(YEAR FROM order_date) = 2025
  GROUP BY store_id
)
SELECT store_id, 'Q1' AS quarter, q1 AS revenue FROM q
UNION ALL SELECT store_id, 'Q2', q2 FROM q
UNION ALL SELECT store_id, 'Q3', q3 FROM q
UNION ALL SELECT store_id, 'Q4', q4 FROM q
ORDER BY store_id, quarter;
/* Q95. */
SELECT r.region_name,
       COUNT(CASE WHEN c.tier = 'Gold' THEN 1 END) AS gold_count,
       ROUND(100.0 * COUNT(CASE WHEN c.tier = 'Gold' THEN 1 END) / COUNT(*), 2) AS pct_gold
FROM customers.customers c
JOIN customers.addresses a ON a.customer_id = c.customer_id
JOIN core.dim_region r ON r.state = a.state
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q96. */
WITH pivoted AS (
  SELECT store_id,
         COUNT(CASE WHEN order_status = 'Delivered' THEN 1 END) AS delivered,
         COUNT(CASE WHEN order_status = 'Cancelled' THEN 1 END) AS cancelled
  FROM sales.orders
  GROUP BY store_id
),
unpivoted AS (
  SELECT store_id, 'Delivered' AS order_status, delivered AS cnt FROM pivoted
  UNION ALL SELECT store_id, 'Cancelled', cancelled FROM pivoted
)
SELECT store_id, order_status, SUM(cnt) AS cnt
FROM unpivoted
GROUP BY store_id, order_status
ORDER BY store_id, order_status;
/* Q97. */
SELECT 'total_customers' AS metric, COUNT(*)::numeric AS value FROM customers.customers
UNION ALL SELECT 'total_orders', COUNT(*)::numeric FROM sales.orders
UNION ALL SELECT 'total_revenue', SUM(net_total) FROM sales.orders
UNION ALL SELECT 'total_products', COUNT(*)::numeric FROM products.products;
/* Q98. */
SELECT s.store_id,
       COUNT(*) FILTER (WHERE o.order_status = 'Delivered') AS delivered,
       COUNT(*) FILTER (WHERE o.order_status = 'Cancelled') AS cancelled,
       COUNT(*) AS row_total
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
GROUP BY GROUPING SETS ((s.store_id), ())
ORDER BY s.store_id NULLS LAST;
/* Q99. crosstab() (from the tablefunc extension) is the way to get truly dynamic pivot columns - when the categories aren't known/fixed at query-writing time (e.g. an ever-changing list of promo codes) - but tablefunc isn't installed on RetailMart, so that pattern is deferred to accio_NN. */
/* Q100. */
SELECT cat.category_name,
       SUM(CASE WHEN EXTRACT(QUARTER FROM o.order_date) = 1 THEN oi.net_amount END) AS q1,
       SUM(CASE WHEN EXTRACT(QUARTER FROM o.order_date) = 2 THEN oi.net_amount END) AS q2,
       SUM(CASE WHEN EXTRACT(QUARTER FROM o.order_date) = 3 THEN oi.net_amount END) AS q3,
       SUM(CASE WHEN EXTRACT(QUARTER FROM o.order_date) = 4 THEN oi.net_amount END) AS q4,
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
   END OF ANSWER KEY - Pivoting, Unpivoting & FILTER - EASY LEVEL (100/100)
   ============================================================ */
