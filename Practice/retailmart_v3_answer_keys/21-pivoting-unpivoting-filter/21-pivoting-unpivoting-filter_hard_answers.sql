/* ============================================================
   ANSWER KEY - Pivoting, Unpivoting & FILTER (HARD LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1.  Approaches: (1) a plain pivot plus a UNION ALL "grand total" row/window SUM for margins, or (2) GROUP BY GROUPING SETS ((row,col),(row),(col),()) in one query, letting GROUPING() flag which level each output row represents. */
/* Q2.  GROUPING SETS is one query producing every requested grouping level with NULLs marking rolled-up columns, computed in a single pass; UNION ALL requires writing (and re-scanning the source for) one SELECT per subtotal level, more verbose but sometimes clearer to a reader unfamiliar with GROUPING SETS. */
/* Q3.  ROLLUP(region, store) produces detail rows (region, store), region subtotals (region, NULL), and a grand total (NULL, NULL) - a hierarchical drill-up matching the region->store containment. */
/* Q4.  CUBE(a, b) produces every possible combination of grouping - (a,b), (a), (b), and () - appropriate when you need subtotals along every dimension independently, not just a strict hierarchy. */
/* Q5.  GROUPING(col) returns 1 when that column was rolled up (aggregated away) in the current output row and 0 when it holds a real detail value - useful to label a row as "subtotal" vs "detail" or to sort subtotals to the bottom. */
/* Q6.  Percent-of-row divides a cell by the sum across that row's other columns (same GROUP BY key); percent-of-column divides by the sum down that column across all rows; percent-of-grand-total divides by the sum of the entire matrix. */
/* Q7.  Derived ratios (return rate, conversion) usually belong as their own column computed from two already-pivoted columns (e.g. returned_units / NULLIF(delivered_units,0)), placed after the raw counts so the sheet reads counts-then-rate left to right. */
/* Q8.  Each FILTER stays attached to its own aggregate on one line, so a reader can scan straight down a multi-metric SELECT list; nested CASE expressions bury multiple conditions inside each other, making it much easier to misplace a THEN/END or double-count a row. */
/* Q9.  Dynamic pivot is unavoidable when the categories aren't known at query-writing time and can grow (e.g. an open-ended set of promo codes) - crosstab() or application code must be used instead of a fixed FILTER/CASE column list. */
/* Q10. jsonb_object_agg(key, value) builds one JSON object per group mapping each key to its value, giving a dynamic "pivot" whose keys are decided from the data itself rather than written into the SQL (full JSON mechanics are Day 24). */
/* Q11. UNION ALL is explicit and simple to audit column-by-column; LATERAL (VALUES ...) inlines the (label,value) pairs per row in one compact join, often faster to write for many columns but requires understanding LATERAL to read. */
/* Q12. A fan-out join (e.g. orders joined to multiple order_items) multiplies each order's row before it reaches the pivot's aggregates - always aggregate at the correct grain (pre-aggregate order-level facts in a CTE) before pivoting, or use COUNT(DISTINCT ...) where appropriate. */
/* Q13. Wrap every FILTERed aggregate in COALESCE(..., 0) (or leave deliberately NULL for "no data") so a category that had zero rows in a particular period still renders a stable cell instead of silently vanishing or producing an inconsistent column set. */
/* Q14. A pivot's percent-of-row/column column can be computed with a plain window SUM(...) OVER (PARTITION BY row_key) alongside the pivoted cells in the same SELECT, since window functions run after the GROUP BY aggregates are computed. */
/* Q15. ROLLUP outputs detail rows first, then progressively higher subtotal rows, with NULL in each rolled-up column - ORDER BY the GROUPING() flags (or the row key with NULLS LAST) to keep subtotals visually grouped at the bottom of each section. */
/* Q16. Pivoting over a CTE that has already aggregated facts down to the exact grain needed is much cheaper than pivoting directly over raw fact rows, since the FILTERed aggregates then scan a much smaller, pre-summarized intermediate result. */
/* Q17. Pivot in SQL when the category set is small, fixed, and the same matrix is reused by multiple consumers; ship long format to the BI layer when categories are numerous, change often, or different viewers want to pivot on different axes themselves. */
/* Q18. Include both a COUNT(...) and a SUM(...) FILTERed on the same condition in one SELECT list and one GROUP BY - both aggregates read the same grouped rows, so counts and revenue for the same category come out of a single pass. */
/* Q19. bool_or(condition) can be pivoted into a "Yes"/"No" capability-flag column via CASE WHEN bool_or(...) THEN 'Yes' ELSE 'No' END, showing whether any row in the group ever satisfied that condition. */
/* Q20. Reshape by first unpivoting the existing wide result into (key, category, value) rows (UNION ALL or unnest), then pivoting that long form again on a different category column - the long form is the flexible intermediate that supports any target axis. */
/* Q21. Wrap the denominator in NULLIF(denominator, 0) so dividing by zero returns NULL instead of raising a division-by-zero error, letting a genuinely empty category show as NULL/blank rather than crashing the query. */
/* Q22. Sum the row-total column across all rows and confirm it equals the separately-computed grand total (e.g. via a UNION ALL check or GROUPING SETS grand-total row) - any mismatch signals a double-count or a missed filter. */
/* Q23. GROUPING SETS can produce detail-plus-several-subtotal-levels in one scan of the source table, replacing several separate UNION ALL queries (each of which would otherwise re-scan/re-aggregate the same data from scratch). */
/* Q24. Keep row and column labels as plain, human-readable text, round numeric columns to a sensible precision, order rows/columns predictably, and include explicit total rows/columns - so the result reads correctly the moment it's pasted into Excel/Sheets. */
/* Q25. Checklist: correct grain before aggregating; every FILTER/CASE condition scoped to the right column; COALESCE/NULLIF decisions deliberate; row/column/grand totals reconcile; and GROUPING()-based subtotal rows are clearly labeled and sorted sensibly. */

/* ============================================================
   SECTION B: PIVOT REPORTS WITH TOTALS (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT r.region_name, pm.mode_name,
       SUM(o.net_total) AS revenue,
       GROUPING(r.region_name) AS is_region_subtotal,
       GROUPING(pm.mode_name) AS is_mode_subtotal
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
JOIN finance.payment_modes pm ON pm.mode_id = o.payment_mode_id
GROUP BY GROUPING SETS ((r.region_name, pm.mode_name), (r.region_name), (pm.mode_name), ())
ORDER BY r.region_name NULLS LAST, pm.mode_name NULLS LAST;
/* Q27. */
SELECT store_id, EXTRACT(QUARTER FROM order_date) AS quarter, SUM(net_total) AS revenue
FROM sales.orders
WHERE EXTRACT(YEAR FROM order_date) = 2025
GROUP BY GROUPING SETS ((store_id, EXTRACT(QUARTER FROM order_date)), (store_id))
ORDER BY store_id, quarter NULLS LAST;
/* Q28. */
SELECT cat.category_name, EXTRACT(MONTH FROM o.order_date) AS month, SUM(oi.quantity) AS units
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
WHERE EXTRACT(YEAR FROM o.order_date) = 2025
GROUP BY GROUPING SETS ((cat.category_name, month), (cat.category_name), (month))
ORDER BY cat.category_name NULLS LAST, month NULLS LAST;
/* Q29. */
SELECT r.region_name, o.order_status, COUNT(*) AS order_count
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY GROUPING SETS ((r.region_name, o.order_status), ())
ORDER BY r.region_name NULLS LAST, o.order_status NULLS LAST;
/* Q30. */
SELECT brand_id,
       CASE WHEN price < 1000 THEN 'value' WHEN price BETWEEN 1000 AND 5000 THEN 'mid' ELSE 'premium' END AS price_band,
       COUNT(*) AS product_count
FROM products.products
GROUP BY GROUPING SETS ((brand_id, CASE WHEN price < 1000 THEN 'value' WHEN price BETWEEN 1000 AND 5000 THEN 'mid' ELSE 'premium' END), (brand_id))
ORDER BY brand_id, price_band NULLS LAST;
/* Q31. */
SELECT agent_id, priority, COUNT(*) AS ticket_count
FROM support.tickets
GROUP BY GROUPING SETS ((agent_id, priority), (agent_id), ())
ORDER BY agent_id NULLS LAST, priority NULLS LAST;
/* Q32. */
SELECT r.region_name, c.tier, SUM(o.net_total) AS revenue
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
JOIN customers.customers c ON c.customer_id = o.cust_id
GROUP BY ROLLUP (r.region_name, c.tier)
ORDER BY r.region_name NULLS LAST, c.tier NULLS LAST;
/* Q33. */
SELECT product_id, rating, COUNT(*) AS review_count
FROM customers.reviews
GROUP BY GROUPING SETS ((product_id, rating), (product_id))
ORDER BY product_id, rating NULLS LAST;
/* Q34. */
SELECT dept_id, role, COUNT(*) AS headcount
FROM stores.employees
GROUP BY GROUPING SETS ((dept_id, role), (dept_id), ())
ORDER BY dept_id NULLS LAST, role NULLS LAST;
/* Q35. */
SELECT courier_name, EXTRACT(MONTH FROM shipped_date) AS month,
       ROUND(AVG(delivered_date - shipped_date), 2) AS avg_delivery_days
FROM sales.shipments
WHERE delivered_date IS NOT NULL AND shipped_date IS NOT NULL
GROUP BY GROUPING SETS ((courier_name, month), ())
ORDER BY courier_name NULLS LAST, month NULLS LAST;
/* Q36. */
SELECT r.region_name, s.store_id, SUM(o.net_total) AS revenue
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY ROLLUP (r.region_name, s.store_id)
ORDER BY r.region_name NULLS LAST, s.store_id NULLS LAST;
/* Q37. */
SELECT cat.category_name, b.brand_name, SUM(oi.net_amount) AS revenue
FROM sales.order_items oi
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
GROUP BY ROLLUP (cat.category_name, b.brand_name)
ORDER BY cat.category_name NULLS LAST, b.brand_name NULLS LAST;
/* Q38. */
SELECT date_trunc('month', order_date)::date AS month, order_status, SUM(net_total) AS revenue
FROM sales.orders
GROUP BY CUBE (date_trunc('month', order_date)::date, order_status)
ORDER BY month NULLS LAST, order_status NULLS LAST;
/* Q39. */
SELECT platform, EXTRACT(QUARTER FROM spend_date) AS quarter, SUM(amount) AS spend
FROM marketing.ads_spend
GROUP BY GROUPING SETS ((platform, quarter), (platform))
ORDER BY platform NULLS LAST, quarter NULLS LAST;
/* Q40. */
SELECT store_id,
       CASE WHEN EXTRACT(DOW FROM order_date) IN (0,6) THEN 'weekend' ELSE 'weekday' END AS day_type,
       SUM(net_total) AS revenue
FROM sales.orders
GROUP BY GROUPING SETS ((store_id, CASE WHEN EXTRACT(DOW FROM order_date) IN (0,6) THEN 'weekend' ELSE 'weekday' END), (store_id))
ORDER BY store_id NULLS LAST, day_type NULLS LAST;
/* Q41. */
SELECT ws.warehouse_id, cat.category_name, SUM(s.quantity_on_hand) AS stock
FROM supply_chain.inventory_snapshots s
JOIN supply_chain.warehouses ws ON ws.warehouse_id = s.warehouse_id
JOIN products.products p ON p.product_id = s.product_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
GROUP BY GROUPING SETS ((ws.warehouse_id, cat.category_name), (ws.warehouse_id))
ORDER BY ws.warehouse_id, cat.category_name NULLS LAST;
/* Q42. */
SELECT EXTRACT(YEAR FROM c.registration_date) AS cohort_year,
       EXTRACT(YEAR FROM o.order_date) AS order_year,
       COUNT(DISTINCT o.cust_id) AS customer_count
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY GROUPING SETS ((cohort_year, order_year), (cohort_year))
ORDER BY cohort_year NULLS LAST, order_year NULLS LAST;
/* Q43. */
SELECT a.city, c.tier, COUNT(*) AS customer_count
FROM customers.customers c
JOIN customers.addresses a ON a.customer_id = c.customer_id
GROUP BY GROUPING SETS ((a.city, c.tier), (a.city))
ORDER BY a.city, c.tier NULLS LAST;
/* Q44. */
SELECT r.region_name,
       CASE WHEN EXTRACT(MONTH FROM o.order_date) IN (3,4,5) THEN 'Spring'
            WHEN EXTRACT(MONTH FROM o.order_date) IN (6,7,8) THEN 'Summer'
            WHEN EXTRACT(MONTH FROM o.order_date) IN (9,10,11) THEN 'Autumn'
            ELSE 'Winter' END AS season,
       SUM(o.net_total) AS revenue,
       GROUPING(r.region_name) AS region_rolled_up,
       GROUPING(CASE WHEN EXTRACT(MONTH FROM o.order_date) IN (3,4,5) THEN 'Spring'
                     WHEN EXTRACT(MONTH FROM o.order_date) IN (6,7,8) THEN 'Summer'
                     WHEN EXTRACT(MONTH FROM o.order_date) IN (9,10,11) THEN 'Autumn'
                     ELSE 'Winter' END) AS season_rolled_up
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY GROUPING SETS ((r.region_name, season), ())
ORDER BY r.region_name NULLS LAST, season NULLS LAST;
/* Q45. */
SELECT b.brand_name, c.tier, SUM(oi.net_amount) AS revenue
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
JOIN customers.customers c ON c.customer_id = o.cust_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
GROUP BY GROUPING SETS ((b.brand_name, c.tier), (b.brand_name), ())
ORDER BY b.brand_name NULLS LAST, c.tier NULLS LAST;
/* Q46. */
SELECT order_status, date_trunc('month', order_date)::date AS month, COUNT(*) AS order_count
FROM sales.orders
GROUP BY GROUPING SETS ((order_status, month), (order_status))
ORDER BY order_status, month NULLS LAST;
/* Q47. */
SELECT p.product_id, EXTRACT(QUARTER FROM o.order_date) AS quarter, SUM(oi.net_amount) AS revenue
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
JOIN products.products p ON p.product_id = oi.prod_id
WHERE EXTRACT(YEAR FROM o.order_date) = 2025
GROUP BY GROUPING SETS ((p.product_id, quarter), (p.product_id))
ORDER BY p.product_id, quarter NULLS LAST;
/* Q48. */
SELECT r.region_name, pm.mode_name,
       COUNT(*) AS order_count,
       SUM(o.net_total) AS revenue
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
JOIN finance.payment_modes pm ON pm.mode_id = o.payment_mode_id
GROUP BY GROUPING SETS ((r.region_name, pm.mode_name), (r.region_name), ())
ORDER BY r.region_name NULLS LAST, pm.mode_name NULLS LAST;
/* Q49. */
WITH by_status AS (
  SELECT order_status, SUM(net_total) AS revenue FROM sales.orders GROUP BY order_status
),
grand AS (
  SELECT SUM(net_total) AS total_revenue FROM sales.orders
)
SELECT (SELECT SUM(revenue) FROM by_status) AS sum_of_rows,
       (SELECT total_revenue FROM grand) AS grand_total,
       (SELECT SUM(revenue) FROM by_status) = (SELECT total_revenue FROM grand) AS reconciled;
/* Q50. */
SELECT r.region_name, date_trunc('month', o.order_date)::date AS month, SUM(o.net_total) AS revenue
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY GROUPING SETS ((r.region_name, month), (r.region_name), (month), ())
ORDER BY r.region_name NULLS LAST, month NULLS LAST;

/* ============================================================
   SECTION C: RATIOS & GROUPING SETS (25)
   ------------------------------------------------------------ */
/* Q51. */
SELECT r.region_name, o.order_status, COUNT(*) AS cnt,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY r.region_name), 2) AS pct_of_region
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name, o.order_status
ORDER BY r.region_name, o.order_status;
/* Q52. */
SELECT r.region_name, o.order_status, COUNT(*) AS cnt,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY o.order_status), 2) AS pct_of_status
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name, o.order_status
ORDER BY r.region_name, o.order_status;
/* Q53. */
SELECT cat.category_name, EXTRACT(MONTH FROM o.order_date) AS month, SUM(oi.quantity) AS units,
       ROUND(100.0 * SUM(oi.quantity) / SUM(SUM(oi.quantity)) OVER (), 2) AS pct_of_grand_total
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
WHERE EXTRACT(YEAR FROM o.order_date) = 2025
GROUP BY cat.category_name, month
ORDER BY cat.category_name, month;
/* Q54. */
SELECT cat.category_name, EXTRACT(MONTH FROM o.order_date) AS month,
       SUM(oi.quantity) FILTER (WHERE EXISTS (SELECT 1 FROM sales.returns r WHERE r.order_id = oi.order_id AND r.prod_id = oi.prod_id)) AS returned_units,
       SUM(oi.quantity) FILTER (WHERE o.order_status = 'Delivered') AS delivered_units,
       ROUND(100.0 * SUM(oi.quantity) FILTER (WHERE EXISTS (SELECT 1 FROM sales.returns r WHERE r.order_id = oi.order_id AND r.prod_id = oi.prod_id))
             / NULLIF(SUM(oi.quantity) FILTER (WHERE o.order_status = 'Delivered'), 0), 2) AS return_rate_pct
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
GROUP BY cat.category_name, month
ORDER BY cat.category_name, month;
/* Q55. */
SELECT r.region_name, c.tier,
       COUNT(DISTINCT o.order_id) AS order_count,
       COUNT(DISTINCT c.customer_id) AS customer_count,
       ROUND(COUNT(DISTINCT o.order_id)::numeric / NULLIF(COUNT(DISTINCT c.customer_id), 0), 2) AS orders_per_customer
FROM customers.customers c
JOIN customers.addresses a ON a.customer_id = c.customer_id
JOIN core.dim_region r ON r.state = a.state
LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY r.region_name, c.tier
ORDER BY r.region_name, c.tier;
/* Q56. */
SELECT store_id,
       SUM(net_total) FILTER (WHERE EXTRACT(QUARTER FROM order_date) = 1) AS q1,
       SUM(net_total) FILTER (WHERE EXTRACT(QUARTER FROM order_date) = 2) AS q2,
       ROUND(100.0 * SUM(net_total) FILTER (WHERE EXTRACT(QUARTER FROM order_date) = 2)
             / NULLIF(SUM(net_total) FILTER (WHERE EXTRACT(QUARTER FROM order_date) = 1), 0), 2) AS q2_index_to_q1
FROM sales.orders
WHERE EXTRACT(YEAR FROM order_date) = 2025
GROUP BY store_id
ORDER BY store_id;
/* Q57. */
SELECT brand_id,
       CASE WHEN price < 1000 THEN 'value' WHEN price BETWEEN 1000 AND 5000 THEN 'mid' ELSE 'premium' END AS price_band,
       COUNT(*) AS cnt,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY brand_id), 2) AS pct_of_brand,
       SUM(COUNT(*)) OVER (PARTITION BY brand_id) AS brand_total
FROM products.products
GROUP BY brand_id, price_band
ORDER BY brand_id, price_band;
/* Q58. */
SELECT agent_id, priority, COUNT(*) AS cnt,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY agent_id), 2) AS pct_of_agent
FROM support.tickets
GROUP BY agent_id, priority
ORDER BY agent_id, priority;
/* Q59. */
SELECT r.region_name, c.tier, SUM(o.net_total) AS revenue,
       ROUND(100.0 * SUM(o.net_total) / SUM(SUM(o.net_total)) OVER (PARTITION BY r.region_name), 2) AS pct_of_region,
       ROUND(100.0 * SUM(o.net_total) / SUM(SUM(o.net_total)) OVER (), 2) AS pct_of_company
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
JOIN customers.customers c ON c.customer_id = o.cust_id
GROUP BY r.region_name, c.tier
ORDER BY r.region_name, c.tier;
/* Q60. */
SELECT r.region_name, s.store_id, SUM(o.net_total) AS revenue,
       GROUPING(s.store_id) AS is_region_subtotal,
       ROUND(100.0 * SUM(o.net_total) / SUM(SUM(o.net_total)) OVER (PARTITION BY r.region_name), 2) AS pct_of_region
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY ROLLUP (r.region_name, s.store_id)
ORDER BY r.region_name NULLS LAST, s.store_id NULLS LAST;
/* Q61. */
SELECT r.region_name, o.order_status, COUNT(*) AS cnt,
       GROUPING(r.region_name) AS region_rolled_up,
       GROUPING(o.order_status) AS status_rolled_up
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY GROUPING SETS ((r.region_name, o.order_status), (r.region_name), ())
ORDER BY r.region_name NULLS LAST, o.order_status NULLS LAST;
/* Q62. */
SELECT r.region_name, o.order_status, COUNT(*) AS cnt,
       GROUPING(r.region_name) AS region_rolled_up,
       GROUPING(o.order_status) AS status_rolled_up
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY CUBE (r.region_name, o.order_status)
ORDER BY r.region_name NULLS LAST, o.order_status NULLS LAST;
/* Q63. */
SELECT product_id, rating, COUNT(*) AS cnt,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY product_id), 2) AS pct_of_product,
       ROUND(AVG(rating) OVER (PARTITION BY product_id), 2) AS avg_rating
FROM customers.reviews
GROUP BY product_id, rating
ORDER BY product_id, rating;
/* Q64. */
SELECT courier_name, EXTRACT(MONTH FROM shipped_date) AS month,
       ROUND(100.0 * COUNT(*) FILTER (WHERE delivered_date - shipped_date <= 3) / COUNT(*), 2) AS pct_on_time
FROM sales.shipments
WHERE delivered_date IS NOT NULL AND shipped_date IS NOT NULL
GROUP BY courier_name, month
ORDER BY courier_name, month;
/* Q65. */
SELECT cat.category_name,
       SUM(oi.quantity) FILTER (WHERE EXISTS (SELECT 1 FROM sales.returns r WHERE r.order_id = oi.order_id AND r.prod_id = oi.prod_id)) AS returned_units,
       SUM(oi.quantity) FILTER (WHERE o.order_status = 'Delivered') AS delivered_units,
       ROUND(100.0 * SUM(oi.quantity) FILTER (WHERE EXISTS (SELECT 1 FROM sales.returns r WHERE r.order_id = oi.order_id AND r.prod_id = oi.prod_id))
             / NULLIF(SUM(oi.quantity) FILTER (WHERE o.order_status = 'Delivered'), 0), 2) AS return_rate_pct
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
GROUP BY cat.category_name
ORDER BY cat.category_name;
/* Q66. */
SELECT date_trunc('month', order_date)::date AS month, order_status, COUNT(*) AS cnt,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY date_trunc('month', order_date)::date), 2) AS pct_of_month,
       SUM(COUNT(*)) OVER (ORDER BY date_trunc('month', order_date)::date, order_status) AS running_cumulative
FROM sales.orders
GROUP BY month, order_status
ORDER BY month, order_status;
/* Q67. */
SELECT r.region_name, c.tier,
       COUNT(DISTINCT c.customer_id) AS customer_count,
       SUM(o.net_total) AS revenue,
       ROUND(SUM(o.net_total) / NULLIF(COUNT(DISTINCT c.customer_id), 0), 2) AS revenue_per_customer
FROM customers.customers c
JOIN customers.addresses a ON a.customer_id = c.customer_id
JOIN core.dim_region r ON r.state = a.state
LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY r.region_name, c.tier
ORDER BY r.region_name, c.tier;
/* Q68. */
SELECT platform, EXTRACT(QUARTER FROM spend_date) AS quarter, SUM(amount) AS spend,
       ROUND(100.0 * SUM(amount) / SUM(SUM(amount)) OVER (PARTITION BY platform), 2) AS pct_of_platform,
       ROUND(100.0 * SUM(amount) / SUM(SUM(amount)) OVER (), 2) AS pct_of_total
FROM marketing.ads_spend
GROUP BY platform, quarter
ORDER BY platform, quarter;
/* Q69. */
SELECT store_id,
       COUNT(*) FILTER (WHERE EXTRACT(DOW FROM order_date) IN (0,6)) AS weekend_orders,
       COUNT(*) AS total_orders,
       ROUND(100.0 * COUNT(*) FILTER (WHERE EXTRACT(DOW FROM order_date) IN (0,6)) / COUNT(*), 2) AS pct_weekend
FROM sales.orders
GROUP BY store_id
ORDER BY store_id;
/* Q70. */
SELECT r.region_name, s.store_id, SUM(o.net_total) AS revenue,
       GROUPING(s.store_id) AS is_subtotal
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY ROLLUP (r.region_name, s.store_id)
ORDER BY r.region_name NULLS LAST, s.store_id NULLS LAST;
/* Q71. */
SELECT dept_id, role, COUNT(*) AS headcount,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY dept_id), 2) AS pct_of_dept,
       SUM(COUNT(*)) OVER () AS company_headcount
FROM stores.employees
GROUP BY dept_id, role
ORDER BY dept_id, role;
/* Q72. */
SELECT EXTRACT(YEAR FROM c.registration_date) AS cohort_year,
       EXTRACT(YEAR FROM o.order_date) AS order_year,
       COUNT(DISTINCT o.cust_id) AS returning_customers,
       ROUND(100.0 * COUNT(DISTINCT o.cust_id) / SUM(COUNT(DISTINCT o.cust_id)) OVER (PARTITION BY EXTRACT(YEAR FROM c.registration_date)), 2) AS pct_of_cohort_orders
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY cohort_year, order_year
ORDER BY cohort_year, order_year;
/* Q73. */
SELECT ws.warehouse_id, cat.category_name, SUM(s.quantity_on_hand) AS stock,
       ROUND(100.0 * SUM(s.quantity_on_hand) / SUM(SUM(s.quantity_on_hand)) OVER (PARTITION BY ws.warehouse_id), 2) AS pct_of_warehouse,
       ROUND(100.0 * SUM(s.quantity_on_hand) / SUM(SUM(s.quantity_on_hand)) OVER (), 2) AS pct_of_company
FROM supply_chain.inventory_snapshots s
JOIN supply_chain.warehouses ws ON ws.warehouse_id = s.warehouse_id
JOIN products.products p ON p.product_id = s.product_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
GROUP BY ws.warehouse_id, cat.category_name
ORDER BY ws.warehouse_id, cat.category_name;
/* Q74. */
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
/* Q75. */
SELECT r.region_name, o.order_status, COUNT(*) AS cnt,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY r.region_name), 2) AS pct_of_region,
       GROUPING(o.order_status) AS is_region_subtotal
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY GROUPING SETS ((r.region_name, o.order_status), (r.region_name), ())
ORDER BY r.region_name NULLS LAST, o.order_status NULLS LAST;

/* ============================================================
   SECTION D: UNPIVOT & RESHAPE (25)
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
)
SELECT store_id AS entity, 'revenue' AS metric, 'Q1' AS period, q1 AS value FROM wide
UNION ALL SELECT store_id, 'revenue', 'Q2', q2 FROM wide
UNION ALL SELECT store_id, 'revenue', 'Q3', q3 FROM wide
UNION ALL SELECT store_id, 'revenue', 'Q4', q4 FROM wide
ORDER BY entity, period;
/* Q77. */
WITH components AS (
  SELECT pay_slip_id, 'basic_salary' AS component, basic_salary AS amount, gross_salary FROM payroll.pay_slips
  UNION ALL SELECT pay_slip_id, 'hra', hra, gross_salary FROM payroll.pay_slips
  UNION ALL SELECT pay_slip_id, 'other_allowances', other_allowances, gross_salary FROM payroll.pay_slips
)
SELECT pay_slip_id, SUM(amount) AS sum_of_components, MAX(gross_salary) AS gross_salary,
       SUM(amount) = MAX(gross_salary) AS matches_gross
FROM components
GROUP BY pay_slip_id
ORDER BY pay_slip_id;
/* Q78. */
SELECT summary_date, 'total_revenue' AS metric, total_revenue AS value FROM finance.revenue_summary
UNION ALL SELECT summary_date, 'total_orders', total_orders::numeric FROM finance.revenue_summary
UNION ALL SELECT summary_date, 'avg_order_value', avg_order_value FROM finance.revenue_summary
ORDER BY summary_date, metric;
/* Q79. */
WITH funnel AS (
  SELECT campaign_id, 'sent' AS stage, emails_sent AS cnt FROM marketing.email_clicks
  UNION ALL SELECT campaign_id, 'opened', emails_opened FROM marketing.email_clicks
  UNION ALL SELECT campaign_id, 'clicked', emails_clicked FROM marketing.email_clicks
)
SELECT campaign_id,
       SUM(cnt) FILTER (WHERE stage = 'sent') AS sent,
       SUM(cnt) FILTER (WHERE stage = 'opened') AS opened,
       SUM(cnt) FILTER (WHERE stage = 'clicked') AS clicked,
       SUM(cnt) FILTER (WHERE stage = 'sent') - SUM(cnt) FILTER (WHERE stage = 'opened') AS drop_sent_to_open,
       SUM(cnt) FILTER (WHERE stage = 'opened') - SUM(cnt) FILTER (WHERE stage = 'clicked') AS drop_open_to_click
FROM funnel
GROUP BY campaign_id
ORDER BY campaign_id;
/* Q80. */
SELECT order_id, gross_total, discount_amount, net_total,
       gross_total - discount_amount = net_total AS reconciles
FROM sales.orders
LIMIT 1000;
/* Q81. */
WITH piv AS (
  SELECT r.region_name, o.order_status, COUNT(*) AS cnt
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  JOIN core.dim_region r ON r.region_id = s.region_id
  GROUP BY r.region_name, o.order_status
),
unpiv AS (
  SELECT region_name, order_status, cnt FROM piv
)
SELECT (SELECT SUM(cnt) FROM piv) AS pivot_total, (SELECT SUM(cnt) FROM unpiv) AS unpivot_total,
       (SELECT SUM(cnt) FROM piv) = (SELECT SUM(cnt) FROM unpiv) AS round_trip_matches;
/* Q82. */
WITH wide AS (
  SELECT store_id,
    SUM(net_total) FILTER (WHERE EXTRACT(MONTH FROM order_date) = 1) AS m1,
    SUM(net_total) FILTER (WHERE EXTRACT(MONTH FROM order_date) = 2) AS m2,
    SUM(net_total) FILTER (WHERE EXTRACT(MONTH FROM order_date) = 3) AS m3
  FROM sales.orders WHERE EXTRACT(YEAR FROM order_date) = 2025
  GROUP BY store_id
)
SELECT w.store_id, v.month, v.revenue
FROM wide w
CROSS JOIN LATERAL (VALUES ('Jan', w.m1), ('Feb', w.m2), ('Mar', w.m3)) AS v(month, revenue)
ORDER BY w.store_id, v.month;
/* Q83. */
SELECT product_id, 'price' AS kind, price AS amount FROM products.products
UNION ALL SELECT product_id, 'cost_price', cost_price FROM products.products
UNION ALL SELECT product_id, 'margin', price - cost_price FROM products.products
ORDER BY product_id, kind;
/* Q84. */
SELECT min_salary, 'min_salary' AS field, min_salary AS value FROM payroll.tax_brackets
UNION ALL SELECT min_salary, 'max_salary', max_salary FROM payroll.tax_brackets
UNION ALL SELECT min_salary, 'tax_rate', tax_rate FROM payroll.tax_brackets
ORDER BY min_salary, field;
/* Q85. */
SELECT campaign_id, 'amount' AS metric, amount AS value FROM marketing.ads_spend
ORDER BY campaign_id;
/* Q86. */
SELECT customer_id, 'email' AS attribute, email AS value FROM customers.customers
UNION ALL SELECT customer_id, 'phone', phone FROM customers.customers
UNION ALL SELECT customer_id, 'tier', tier FROM customers.customers
ORDER BY customer_id, attribute;
/* Q87. */
SELECT order_id, 'shipped' AS event_type, shipped_date AS event_date FROM sales.shipments
UNION ALL SELECT order_id, 'delivered', delivered_date FROM sales.shipments
ORDER BY order_id, event_type;
/* Q88. */
WITH piv AS (
  SELECT r.region_name, o.order_status, COUNT(*) AS cnt
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  JOIN core.dim_region r ON r.region_id = s.region_id
  GROUP BY r.region_name, o.order_status
)
SELECT region_name, order_status, cnt FROM piv ORDER BY region_name, order_status;
/* Q89. */
WITH funnel AS (
  SELECT campaign_id, 'sent' AS stage, emails_sent AS cnt, 1 AS stage_order FROM marketing.email_clicks
  UNION ALL SELECT campaign_id, 'opened', emails_opened, 2 FROM marketing.email_clicks
  UNION ALL SELECT campaign_id, 'clicked', emails_clicked, 3 FROM marketing.email_clicks
)
SELECT campaign_id, stage, cnt,
       ROUND(100.0 * cnt / NULLIF(FIRST_VALUE(cnt) OVER (PARTITION BY campaign_id ORDER BY stage_order), 0), 2) AS pct_of_sent
FROM funnel
ORDER BY campaign_id, stage_order;
/* Q90. */
SELECT tier_id, 'min_points' AS field, min_points AS value FROM loyalty.tiers
UNION ALL SELECT tier_id, 'max_points', max_points FROM loyalty.tiers
ORDER BY tier_id, field;
/* Q91. */
WITH wide AS (
  SELECT store_id,
    SUM(net_total) FILTER (WHERE EXTRACT(QUARTER FROM order_date) = 1) AS q1,
    SUM(net_total) FILTER (WHERE EXTRACT(QUARTER FROM order_date) = 2) AS q2,
    SUM(net_total) FILTER (WHERE EXTRACT(QUARTER FROM order_date) = 3) AS q3,
    SUM(net_total) FILTER (WHERE EXTRACT(QUARTER FROM order_date) = 4) AS q4
  FROM sales.orders WHERE EXTRACT(YEAR FROM order_date) = 2025
  GROUP BY store_id
),
long_form AS (
  SELECT store_id, 'Q1' AS quarter, q1 AS revenue FROM wide
  UNION ALL SELECT store_id, 'Q2', q2 FROM wide
  UNION ALL SELECT store_id, 'Q3', q3 FROM wide
  UNION ALL SELECT store_id, 'Q4', q4 FROM wide
)
SELECT store_id, SUM(revenue) AS year_total FROM long_form GROUP BY store_id ORDER BY store_id;
/* Q92. */
SELECT o.order_id, k, v
FROM sales.orders o,
     UNNEST(ARRAY['gross_total', 'discount_amount', 'net_total'],
            ARRAY[o.gross_total, o.discount_amount, o.net_total]) AS t(k, v)
LIMIT 1000;
/* Q93. */
WITH long_form AS (
  SELECT order_id, 'gross_total' AS kind, gross_total AS amount FROM sales.orders
  UNION ALL SELECT order_id, 'net_total', net_total FROM sales.orders
)
SELECT kind, SUM(amount) AS total FROM long_form GROUP BY kind ORDER BY kind;
/* Q94. */
SELECT store_id, 'revenue' AS metric, SUM(net_total) AS value FROM sales.orders GROUP BY store_id
UNION ALL
SELECT store_id, 'order_count', COUNT(*) FROM sales.orders GROUP BY store_id
UNION ALL
SELECT store_id, 'aov', ROUND(AVG(net_total), 2) FROM sales.orders GROUP BY store_id
ORDER BY store_id, metric;
/* Q95. */
WITH long_form AS (
  SELECT order_id, 'gross_total' AS kind, gross_total AS amount FROM sales.orders
  UNION ALL SELECT order_id, 'net_total', net_total FROM sales.orders
)
SELECT (SELECT SUM(amount) FROM long_form WHERE kind = 'net_total') AS long_form_net_sum,
       (SELECT SUM(net_total) FROM sales.orders) AS wide_form_net_sum,
       (SELECT SUM(amount) FROM long_form WHERE kind = 'net_total') = (SELECT SUM(net_total) FROM sales.orders) AS matches;
/* Q96. */
WITH region_quarter AS (
  SELECT r.region_name, EXTRACT(QUARTER FROM o.order_date) AS quarter, SUM(o.net_total) AS revenue
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  JOIN core.dim_region r ON r.region_id = s.region_id
  WHERE EXTRACT(YEAR FROM o.order_date) = 2025
  GROUP BY r.region_name, quarter
)
SELECT region_name, quarter, revenue FROM region_quarter ORDER BY region_name, quarter;
/* Q97. */
WITH piv AS (
  SELECT r.region_name,
         SUM(o.net_total) FILTER (WHERE EXTRACT(QUARTER FROM o.order_date) = 1) AS q1,
         SUM(o.net_total) FILTER (WHERE EXTRACT(QUARTER FROM o.order_date) = 2) AS q2
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  JOIN core.dim_region r ON r.region_id = s.region_id
  WHERE EXTRACT(YEAR FROM o.order_date) = 2025
  GROUP BY r.region_name
)
SELECT region_name, 'Q1' AS quarter, q1 AS revenue FROM piv
UNION ALL SELECT region_name, 'Q2', q2 FROM piv
ORDER BY region_name, quarter;
/* Q98. */
SELECT store_id, 'revenue' AS metric, SUM(net_total) AS value FROM sales.orders GROUP BY store_id
UNION ALL SELECT store_id, 'order_count', COUNT(*) FROM sales.orders GROUP BY store_id
UNION ALL SELECT store_id, 'aov', ROUND(AVG(net_total), 2) FROM sales.orders GROUP BY store_id
UNION ALL SELECT store_id, 'returned_count', COUNT(*) FILTER (WHERE order_status = 'Returned') FROM sales.orders GROUP BY store_id
UNION ALL SELECT store_id, 'cancelled_count', COUNT(*) FILTER (WHERE order_status = 'Cancelled') FROM sales.orders GROUP BY store_id
UNION ALL SELECT store_id, 'delivered_revenue', SUM(net_total) FILTER (WHERE order_status = 'Delivered') FROM sales.orders GROUP BY store_id
ORDER BY store_id, metric;
/* Q99. crosstab() (from tablefunc, accio_NN) is needed whenever the dynamic-column case shows up - when the pivot's categories aren't fixed/known ahead of time and must be discovered from the data itself. */
/* Q100. */
WITH piv AS (
  SELECT r.region_name,
         SUM(o.net_total) FILTER (WHERE EXTRACT(QUARTER FROM o.order_date) = 1) AS q1,
         SUM(o.net_total) FILTER (WHERE EXTRACT(QUARTER FROM o.order_date) = 2) AS q2,
         SUM(o.net_total) FILTER (WHERE EXTRACT(QUARTER FROM o.order_date) = 3) AS q3,
         SUM(o.net_total) FILTER (WHERE EXTRACT(QUARTER FROM o.order_date) = 4) AS q4,
         SUM(o.net_total) AS year_total
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  JOIN core.dim_region r ON r.region_id = s.region_id
  WHERE EXTRACT(YEAR FROM o.order_date) = 2025
  GROUP BY r.region_name
)
SELECT * FROM piv ORDER BY region_name;

/* ============================================================
   END OF ANSWER KEY - Pivoting, Unpivoting & FILTER - HARD LEVEL (100/100)
   ============================================================ */
