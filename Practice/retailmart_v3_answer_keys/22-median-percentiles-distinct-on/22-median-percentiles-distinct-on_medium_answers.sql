/* ============================================================
   ANSWER KEY - Median, Percentiles & DISTINCT ON (MEDIUM LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1. CONT treats the sorted data as continuous and linearly interpolates between the two bracketing values when the target rank is fractional; DISC treats it as discrete and always jumps to (snaps to) the nearest actual row's value, never interpolating. */
/* Q2. For {10,20,30,40}: PERCENTILE_CONT(0.5) = 25 (interpolated halfway between 20 and 30); PERCENTILE_DISC(0.5) = 20 (the actual row at/after the 50% cumulative-distribution cutoff). */
/* Q3. Because the median is defined as the 50th percentile, and PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY x) computes exactly that value (interpolated) from x's distribution. */
/* Q4. Pass an array literal as the fraction argument, e.g. PERCENTILE_CONT(ARRAY[0.5,0.9,0.95]) WITHIN GROUP (ORDER BY x) - PostgreSQL computes all three cut points in a single aggregate pass over the data. */
/* Q5. Wrap the call in UNNEST(...) (optionally WITH ORDINALITY) to expand the returned array into one row per percentile value, or index into it directly with array subscript syntax, e.g. (PERCENTILE_CONT(ARRAY[0.5,0.9]) WITHIN GROUP (ORDER BY x))[1]. */
/* Q6. WHERE filters individual rows before any aggregation happens, but PERCENTILE_CONT is an aggregate that needs the whole (grouped) set of rows to compute a result - aggregates belong in SELECT/HAVING, not WHERE, the same restriction that applies to SUM/AVG/COUNT. */
/* Q7. Ties are broken by any additional ORDER BY columns listed after the DISTINCT ON key(s) - the first row in that full sort order is the one DISTINCT ON keeps. */
/* Q8. Without a deterministic tiebreaker, two rows with an identical ORDER BY value (e.g. same order_date) could non-deterministically swap which one "wins" between runs, making the query's output unstable/unrepeatable. */
/* Q9. DISTINCT ON is cleaner for a plain "latest/first per group, full row" report done directly in the FROM clause; ROW_NUMBER() OVER(...) is cleaner when you need the rank number itself, want to keep multiple ranks (not just #1), or need portable (non-PostgreSQL) SQL. */
/* Q10. Because DISTINCT ON groups rows by matching the leading ORDER BY expressions to its column list - if the DISTINCT ON columns weren't first, PostgreSQL could not guarantee which row is "first" within each such group. */
/* Q11. DISTINCT ON scans the table once with a single sort/index scan to skip to the next group; a correlated subquery instead re-executes (conceptually) once per outer row, which is typically far more expensive without a very well-tuned index. */
/* Q12. Yes conceptually, but PostgreSQL's ordered-set aggregates (PERCENTILE_CONT/DISC) cannot be used with an OVER() window clause directly in standard PostgreSQL - they must be computed in a GROUP BY aggregate and then joined/broadcast back if a per-row window-style result is needed. */
/* Q13. If two values tie for the highest frequency, mode() WITHIN GROUP returns one of them arbitrarily (implementation-defined which one) since it does not have a tiebreak rule. */
/* Q14. Same as any aggregate: append FILTER (WHERE condition) after the WITHIN GROUP clause, e.g. PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY x) FILTER (WHERE y = 'A'), to compute the percentile only over rows matching the condition. */
/* Q15. A per-group median must combine many rows into one summary number per group, which is exactly what GROUP BY does; DISTINCT ON instead keeps one original row per group untouched, so no aggregation/grouping mechanism is needed. */
/* Q16. NTILE(4) assigns each row to one of 4 roughly-equal-sized buckets (bucket number 1-4) based on row count, not value; PERCENTILE_CONT gives the actual data VALUE at the 25/50/75% cut points - NTILE buckets can have uneven boundary values while PERCENTILE_CONT gives exact interpolated cut values. */
/* Q17. percent_rank() = (rank - 1) / (total_rows - 1), giving 0 for the first row and 1 for the last; cume_dist() = (rows with value <= current row's value) / total_rows, giving the cumulative fraction of rows at or below the current row. */
/* Q18. NTILE(2) splits rows into two equal-COUNT halves regardless of value gaps, so its boundary is just "the row after the halfway count"; PERCENTILE_CONT(0.5) instead interpolates the true midpoint VALUE, which can differ whenever the data isn't evenly spaced around the count-based split. */
/* Q19. IQR = PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY x) - PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY x). */
/* Q20. You need P25 and P75 (the IQR itself) - the lower fence is P25 - 1.5*IQR and the upper fence is P75 + 1.5*IQR. */
/* Q21. Because DISTINCT ON's purpose is "pick the representative row for this group", and an analyst usually needs the other columns of that row (e.g. order_id, status) alongside the key, not just the grouping key by itself. */
/* Q22. Wrap the query in a CTE/subquery that computes ROW_NUMBER() OVER (PARTITION BY group_col ORDER BY tiebreak_col DESC) AS rn, then filter the outer query to WHERE rn = 1 - this is the portable, standard-SQL equivalent of DISTINCT ON. */
/* Q23. Compute the expression (e.g. delivered_date - order_date) either inline inside PERCENTILE_CONT's ORDER BY argument, or first materialize it as a column/CTE and then take PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY that_expression). */
/* Q24. Ordered-set aggregates ignore NULLs in the ordering input by default, the same as most other aggregates - NULLs are excluded from the sorted set before the percentile position is computed. */
/* Q25. A single median is misleading for a bimodal distribution (two separate clusters of typical values, e.g. "budget shoppers" and "premium shoppers") because the median falls in the gap between the clusters and represents neither group well. */

/* ============================================================
   SECTION B: PERCENTILES WITH JOINS & GROUPS (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT r.region_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_net_total,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_net_total
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q27. */
SELECT w.warehouse_id, w.name AS warehouse_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sh.delivered_date - o.order_date) AS median_delivery_days
FROM sales.orders o
JOIN sales.shipments sh ON sh.order_id = o.order_id
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
JOIN supply_chain.warehouses w ON w.region = r.region_name
WHERE o.order_status = 'Delivered' AND sh.delivered_date IS NOT NULL
GROUP BY w.warehouse_id, w.name
ORDER BY w.warehouse_id;
/* Q28. */
SELECT s.store_id,
       PERCENTILE_CONT(ARRAY[0.5, 0.9, 0.95]) WITHIN GROUP (ORDER BY o.net_total) AS median_p90_p95
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
GROUP BY s.store_id
ORDER BY s.store_id;
/* Q29. */
SELECT r.region_name,
       PERCENTILE_CONT(ARRAY[0.25, 0.5, 0.75]) WITHIN GROUP (ORDER BY o.net_total) AS p25_p50_p75
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q30. */
SELECT r.region_name,
       PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY o.net_total) - PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY o.net_total) AS iqr_net_total
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q31. */
SELECT c.category_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY oi.unit_price) AS median_unit_price
FROM sales.order_items oi
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category c ON c.category_id = b.category_id
GROUP BY c.category_name
ORDER BY c.category_name;
/* Q32. */
WITH basket AS (
    SELECT order_id, COUNT(*) AS item_count
    FROM sales.order_items
    GROUP BY order_id
)
SELECT s.store_id,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY b.item_count) AS median_basket_size
FROM basket b
JOIN sales.orders o ON o.order_id = b.order_id
JOIN stores.stores s ON s.store_id = o.store_id
GROUP BY s.store_id
ORDER BY s.store_id;
/* Q33. */
SELECT c.tier,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_order_value
FROM sales.orders o
JOIN customers.customers c ON c.customer_id = o.cust_id
GROUP BY c.tier
HAVING COUNT(DISTINCT c.customer_id) > 1000
ORDER BY c.tier;
/* Q34. */
SELECT b.brand_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY r.rating) AS median_rating
FROM customers.reviews r
JOIN products.products p ON p.product_id = r.product_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
GROUP BY b.brand_name
ORDER BY b.brand_name;
/* Q35. */
SELECT agent_id,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY call_duration_seconds) AS median_call_duration_sec
FROM call_center.calls
GROUP BY agent_id
HAVING COUNT(*) > 50
ORDER BY agent_id;
/* Q36. */
SELECT priority,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600.0) AS p95_resolution_hours
FROM support.tickets
WHERE resolved_date IS NOT NULL
GROUP BY priority
ORDER BY priority;
/* Q37. */
SELECT d.dept_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ps.net_salary) AS median_net_salary,
       COUNT(DISTINCT e.employee_id) AS headcount
FROM payroll.pay_slips ps
JOIN stores.employees e ON e.employee_id = ps.employee_id
JOIN core.dim_department d ON d.dept_id = e.dept_id
GROUP BY d.dept_name
ORDER BY d.dept_name;
/* Q38. */
WITH gaps AS (
    SELECT cust_id, order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date) AS gap_days
    FROM sales.orders
)
SELECT cust_id, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY gap_days) AS median_gap_days
FROM gaps
WHERE gap_days IS NOT NULL
GROUP BY cust_id
ORDER BY cust_id;
/* Q39. */
WITH monthly AS (
    SELECT r.region_name, date_trunc('month', o.order_date)::date AS month, SUM(o.net_total) AS revenue
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_name, month
)
SELECT region_name, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY revenue) AS median_monthly_revenue
FROM monthly
GROUP BY region_name
ORDER BY region_name;
/* Q40. */
SELECT platform, EXTRACT(QUARTER FROM spend_date) AS quarter,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount) AS median_spend
FROM marketing.ads_spend
GROUP BY platform, quarter
ORDER BY platform, quarter;
/* Q41. */
SELECT r.region_name,
       PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY sh.delivered_date - o.order_date) AS p90_delivery_days
FROM sales.orders o
JOIN sales.shipments sh ON sh.order_id = o.order_id
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
WHERE o.order_status NOT IN ('Cancelled', 'Failed') AND sh.delivered_date IS NOT NULL
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q42. */
SELECT t.tier_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY m.points_balance) AS median_points_balance,
       COUNT(*) AS member_count
FROM loyalty.members m
JOIN loyalty.tiers t ON t.tier_id = m.tier_id
GROUP BY t.tier_name
ORDER BY t.tier_name;
/* Q43. */
SELECT c.category_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ret.refund_amount) AS median_refund_amount
FROM sales.returns ret
JOIN products.products p ON p.product_id = ret.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category c ON c.category_id = b.category_id
GROUP BY c.category_name
ORDER BY c.category_name;
/* Q44. */
SELECT TRIM(TO_CHAR(order_date, 'Day')) AS weekday,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total) AS median_order_value
FROM sales.orders
GROUP BY weekday, EXTRACT(ISODOW FROM order_date)
ORDER BY EXTRACT(ISODOW FROM order_date);
/* Q45. */
WITH ranked AS (
    SELECT cust_id, order_id, net_total,
           ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date) AS rn
    FROM sales.orders
)
SELECT CASE WHEN rn = 1 THEN 'new' ELSE 'returning' END AS customer_type,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total) AS median_order_value
FROM ranked
GROUP BY CASE WHEN rn = 1 THEN 'new' ELSE 'returning' END;
/* Q46. */
SELECT c.category_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY oi.net_amount - oi.quantity * p.cost_price) AS median_gross_margin
FROM sales.order_items oi
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category c ON c.category_id = b.category_id
GROUP BY c.category_name
ORDER BY c.category_name;
/* Q47. */
WITH first_order AS (
    SELECT cust_id, MIN(order_date) AS first_order_date
    FROM sales.orders
    GROUP BY cust_id
)
SELECT EXTRACT(YEAR FROM c.registration_date) AS cohort_year,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY fo.first_order_date - c.registration_date) AS median_days_to_first_order
FROM customers.customers c
JOIN first_order fo ON fo.cust_id = c.customer_id
GROUP BY cohort_year
ORDER BY cohort_year;
/* Q48. */
WITH store_medians AS (
    SELECT s.store_id,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_net_total
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    GROUP BY s.store_id
)
SELECT store_id, median_net_total,
       RANK() OVER (ORDER BY median_net_total DESC) AS rnk
FROM store_medians
ORDER BY rnk
LIMIT 10;
/* Q49. */
SELECT r.region_name,
       ROUND(AVG(o.net_total), 2) AS mean_net_total,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_net_total,
       ROUND((AVG(o.net_total) - PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total))::numeric, 2) AS spread,
       ROUND(100.0 * (AVG(o.net_total) - PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total))::numeric
             / NULLIF(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total)::numeric, 0), 2) AS pct_diff
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q50. */
SELECT pm.mode_name,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_net_total,
       COUNT(*) AS order_count
FROM sales.orders o
JOIN finance.payment_modes pm ON pm.mode_id = o.payment_mode_id
GROUP BY pm.mode_name
ORDER BY pm.mode_name;

/* ============================================================
   SECTION C: DISTINCT ON ACROSS TABLES (25)
   ------------------------------------------------------------ */
/* Q51. */
SELECT DISTINCT ON (o.cust_id) o.cust_id, o.order_id, o.order_date, o.net_total, o.order_status, s.store_name
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
ORDER BY o.cust_id, o.order_date DESC;
/* Q52. */
SELECT DISTINCT ON (r.product_id) r.product_id, r.review_id, r.rating, r.review_date, c.first_name, c.last_name
FROM customers.reviews r
JOIN customers.customers c ON c.customer_id = r.customer_id
ORDER BY r.product_id, r.review_date DESC;
/* Q53. */
SELECT DISTINCT ON (t.customer_id) t.customer_id, t.ticket_id, t.priority, t.subject, t.created_date
FROM support.tickets t
ORDER BY t.customer_id, t.created_date DESC;
/* Q54. */
SELECT DISTINCT ON (p.order_id) p.order_id, p.payment_id, p.payment_date, p.payment_mode, p.amount
FROM sales.payments p
ORDER BY p.order_id, p.payment_date DESC;
/* Q55. */
SELECT DISTINCT ON (warehouse_id, product_id) warehouse_id, product_id, snapshot_date, quantity_on_hand
FROM supply_chain.inventory_snapshots
ORDER BY warehouse_id, product_id, snapshot_date DESC;
/* Q56. */
SELECT DISTINCT ON (sh.employee_id) sh.employee_id, sh.amount, sh.payment_date, d.dept_name
FROM hr.salary_history sh
JOIN stores.employees e ON e.employee_id = sh.employee_id
JOIN core.dim_department d ON d.dept_id = e.dept_id
ORDER BY sh.employee_id, sh.payment_date DESC;
/* Q57. */
SELECT DISTINCT ON (oi.prod_id) oi.prod_id, o.order_date, oi.unit_price
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
ORDER BY oi.prod_id, o.order_date DESC;
/* Q58. */
SELECT DISTINCT ON (cust_id) cust_id, order_id, order_date,
       CURRENT_DATE - order_date AS days_since_order
FROM sales.orders
ORDER BY cust_id, order_date DESC;
/* Q59. */
WITH first_o AS (
    SELECT DISTINCT ON (cust_id) cust_id, order_id AS first_order_id, order_date AS first_order_date
    FROM sales.orders
    ORDER BY cust_id, order_date ASC
),
latest_o AS (
    SELECT DISTINCT ON (cust_id) cust_id, order_id AS latest_order_id, order_date AS latest_order_date
    FROM sales.orders
    ORDER BY cust_id, order_date DESC
)
SELECT f.cust_id, f.first_order_id, f.first_order_date, l.latest_order_id, l.latest_order_date
FROM first_o f
JOIN latest_o l ON l.cust_id = f.cust_id
ORDER BY f.cust_id;
/* Q60. */
SELECT DISTINCT ON (cust_id) cust_id, order_id, order_date, net_total
FROM sales.orders
WHERE order_status = 'Delivered'
ORDER BY cust_id, order_date DESC;
/* Q61. */
SELECT DISTINCT ON (agent_id) agent_id, call_id, call_start_time, call_duration_seconds
FROM call_center.calls
ORDER BY agent_id, call_start_time DESC;
/* Q62. */
SELECT DISTINCT ON (a.city) a.city, c.customer_id, c.first_name, c.last_name, c.registration_date
FROM customers.customers c
JOIN customers.addresses a ON a.customer_id = c.customer_id
ORDER BY a.city, c.registration_date DESC;
/* Q63. */
SELECT DISTINCT ON (customer_id) customer_id, redemption_id, reward_name, points_redeemed, redemption_date
FROM loyalty.redemptions
ORDER BY customer_id, redemption_date DESC;
/* Q64. */
SELECT DISTINCT ON (store_id) store_id, store_expense_id, expense_type, amount, expense_date
FROM stores.expenses
ORDER BY store_id, expense_date DESC;
/* Q65. */
SELECT DISTINCT ON (customer_id) customer_id, view_id, page_url, view_timestamp
FROM web_events.page_views
WHERE customer_id IS NOT NULL
ORDER BY customer_id, view_timestamp DESC;
/* Q66. */
SELECT DISTINCT ON (product_id) product_id, review_id, rating, review_date
FROM customers.reviews
ORDER BY product_id, rating DESC, review_date DESC;
/* Q67. */
SELECT DISTINCT ON (store_id) store_id, order_id, order_date, net_total, order_status
FROM sales.orders
ORDER BY store_id, order_date DESC;
/* Q68. */
SELECT DISTINCT ON (line_id) line_id, work_order_id, product_id, start_timestamp, status
FROM manufacture.work_orders
ORDER BY line_id, start_timestamp DESC;
/* Q69. */
SELECT DISTINCT ON (employee_id) employee_id, attendance_id, attendance_date, check_in, check_out
FROM hr.attendance
ORDER BY employee_id, attendance_date DESC;
/* Q70. */
SELECT DISTINCT ON (r.region_name) r.region_name, o.order_id, o.order_date, o.net_total
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
ORDER BY r.region_name, o.order_date DESC;
/* Q71. */
SELECT DISTINCT ON (platform) platform, spend_id, spend_date, amount
FROM marketing.ads_spend
ORDER BY platform, spend_date DESC;
/* Q72. */
SELECT DISTINCT ON (order_id) order_id, shipment_id, status, shipped_date, delivered_date
FROM sales.shipments
ORDER BY order_id, shipped_date DESC;
/* Q73. */
SELECT DISTINCT ON (cust_id) cust_id, order_id, order_date, net_total
FROM sales.orders
ORDER BY cust_id, net_total DESC;
/* Q74. */
SELECT DISTINCT ON (from_account) from_account, transfer_id, to_account, amount, transferred_at
FROM finance.transfer_log
ORDER BY from_account, transferred_at DESC;
/* Q75. */
SELECT DISTINCT ON (agent_id) agent_id, ticket_id, category, priority, status, created_date
FROM support.tickets
WHERE agent_id IS NOT NULL
ORDER BY agent_id, created_date DESC;

/* ============================================================
   SECTION D: PERCENTILE + PIVOT / WINDOW INTEGRATION (25)
   ------------------------------------------------------------ */
/* Q76. */
SELECT r.region_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) FILTER (WHERE EXTRACT(QUARTER FROM o.order_date) = 1) AS median_q1,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) FILTER (WHERE EXTRACT(QUARTER FROM o.order_date) = 2) AS median_q2,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) FILTER (WHERE EXTRACT(QUARTER FROM o.order_date) = 3) AS median_q3,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) FILTER (WHERE EXTRACT(QUARTER FROM o.order_date) = 4) AS median_q4
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q77. */
SELECT r.region_name, date_trunc('month', o.order_date)::date AS month,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_net_total
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name, month
ORDER BY r.region_name, month;
/* Q78. */
SELECT r.region_name, EXTRACT(QUARTER FROM o.order_date) AS quarter,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sh.delivered_date - o.order_date) AS median_delivery_days
FROM sales.orders o
JOIN sales.shipments sh ON sh.order_id = o.order_id
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
WHERE o.order_status = 'Delivered' AND sh.delivered_date IS NOT NULL
GROUP BY r.region_name, quarter
ORDER BY r.region_name, quarter;
/* Q79. */
WITH ranked AS (
    SELECT cust_id, order_id, order_date, net_total,
           PERCENT_RANK() OVER (ORDER BY net_total) AS pct_rank
    FROM sales.orders
)
SELECT DISTINCT ON (cust_id) cust_id, order_id, order_date, net_total, pct_rank
FROM ranked
ORDER BY cust_id, order_date DESC;
/* Q80. */
WITH region_p90 AS (
    SELECT r.region_id, PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY o.net_total) AS p90_net_total
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_id
)
SELECT o.order_id, o.net_total, r.region_name, rp.p90_net_total,
       (o.net_total > rp.p90_net_total) AS above_p90
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
JOIN region_p90 rp ON rp.region_id = r.region_id
ORDER BY o.order_id;
/* Q81. */
WITH quarterly AS (
    SELECT r.region_name, EXTRACT(YEAR FROM o.order_date) AS yr, EXTRACT(QUARTER FROM o.order_date) AS quarter,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_order_value
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_name, yr, quarter
)
SELECT region_name, yr, quarter, median_order_value,
       AVG(median_order_value) OVER (PARTITION BY region_name ORDER BY yr, quarter ROWS BETWEEN 1 PRECEDING AND CURRENT ROW) AS rolling_2q_avg_median
FROM quarterly
ORDER BY region_name, yr, quarter;
/* Q82. */
WITH cust_median AS (
    SELECT cust_id, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total) AS median_order_value
    FROM sales.orders
    GROUP BY cust_id
),
latest_order AS (
    SELECT DISTINCT ON (cust_id) cust_id, net_total AS latest_net_total
    FROM sales.orders
    ORDER BY cust_id, order_date DESC
)
SELECT l.cust_id, l.latest_net_total, cm.median_order_value
FROM latest_order l
JOIN cust_median cm ON cm.cust_id = l.cust_id
WHERE l.latest_net_total > cm.median_order_value
ORDER BY l.cust_id;
/* Q83. */
WITH store_medians AS (
    SELECT s.store_id,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_net_total
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    GROUP BY s.store_id
)
SELECT store_id, median_net_total,
       RANK() OVER (ORDER BY median_net_total DESC) AS rnk
FROM store_medians
ORDER BY rnk;
/* Q84. */
WITH region_median AS (
    SELECT r.region_id, r.region_name,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS region_median
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_id, r.region_name
),
store_median AS (
    SELECT s.store_id, s.region_id,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS store_median
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    GROUP BY s.store_id, s.region_id
)
SELECT sm.store_id, rm.region_name, sm.store_median, rm.region_median,
       sm.store_median - rm.region_median AS gap_to_region
FROM store_median sm
JOIN region_median rm ON rm.region_id = sm.region_id
ORDER BY sm.store_id;
/* Q85. */
WITH decile AS (
    SELECT net_total, NTILE(10) OVER (ORDER BY net_total) AS decile_bucket
    FROM sales.orders
)
SELECT decile_bucket, MIN(net_total) AS decile_min_value, MAX(net_total) AS decile_max_value
FROM decile
GROUP BY decile_bucket
ORDER BY decile_bucket;
/* Q86. */
WITH latest_price AS (
    SELECT DISTINCT ON (p.product_id) p.product_id, oi.unit_price AS latest_selling_price
    FROM sales.order_items oi
    JOIN sales.orders o ON o.order_id = oi.order_id
    JOIN products.products p ON p.product_id = oi.prod_id
    ORDER BY p.product_id, o.order_date DESC
)
SELECT c.category_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY p.price) AS median_price,
       ROUND(AVG(lp.latest_selling_price), 2) AS avg_latest_selling_price
FROM products.products p
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category c ON c.category_id = b.category_id
JOIN latest_price lp ON lp.product_id = p.product_id
GROUP BY c.category_name
ORDER BY c.category_name;
/* Q87. */
WITH latest_ticket AS (
    SELECT DISTINCT ON (agent_id) agent_id, status AS latest_status
    FROM support.tickets
    WHERE agent_id IS NOT NULL
    ORDER BY agent_id, created_date DESC
)
SELECT t.agent_id,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (t.resolved_date - t.created_date)) / 3600.0) AS median_resolution_hours,
       MAX(lt.latest_status) AS latest_status
FROM support.tickets t
JOIN latest_ticket lt ON lt.agent_id = t.agent_id
WHERE t.resolved_date IS NOT NULL
GROUP BY t.agent_id
ORDER BY t.agent_id;
/* Q88. */
SELECT r.region_name,
       COUNT(*) AS order_count,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_order_value,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_order_value
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q89. */
WITH basket AS (
    SELECT o.order_id, s.store_id, EXTRACT(QUARTER FROM o.order_date) AS quarter, COUNT(oi.order_item_id) AS item_count
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN sales.order_items oi ON oi.order_id = o.order_id
    GROUP BY o.order_id, s.store_id, quarter
)
SELECT store_id,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY item_count) FILTER (WHERE quarter = 1) AS median_basket_q1,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY item_count) FILTER (WHERE quarter = 2) AS median_basket_q2,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY item_count) FILTER (WHERE quarter = 3) AS median_basket_q3,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY item_count) FILTER (WHERE quarter = 4) AS median_basket_q4
FROM basket
GROUP BY store_id
ORDER BY store_id;
/* Q90. */
WITH global_p95 AS (
    SELECT PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY net_total) AS p95 FROM sales.orders
),
latest AS (
    SELECT DISTINCT ON (cust_id) cust_id, net_total, order_status
    FROM sales.orders
    ORDER BY cust_id, order_date DESC
)
SELECT l.cust_id, l.net_total, l.order_status
FROM latest l, global_p95 g
WHERE l.net_total > g.p95 AND l.order_status = 'Returned'
ORDER BY l.cust_id;
/* Q91. */
WITH region_median AS (
    SELECT r.region_id, r.region_name,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_order_value
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_id, r.region_name
)
SELECT rm.region_name, rm.median_order_value,
       ROUND(100.0 * COUNT(*) FILTER (WHERE o.net_total > rm.median_order_value) / COUNT(*), 2) AS pct_above_median
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN region_median rm ON rm.region_id = s.region_id
GROUP BY rm.region_name, rm.median_order_value
ORDER BY rm.region_name;
/* Q92. */
WITH region_iqr AS (
    SELECT r.region_id,
           PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY o.net_total) AS p25,
           PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY o.net_total) AS p75
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_id
)
SELECT o.order_id, r.region_name, o.net_total
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
JOIN region_iqr ri ON ri.region_id = r.region_id
WHERE o.net_total > ri.p75 + 1.5 * (ri.p75 - ri.p25)
ORDER BY o.order_id;
/* Q93. */
WITH monthly AS (
    SELECT r.region_name, date_trunc('month', o.order_date)::date AS month, SUM(o.net_total) AS revenue
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    GROUP BY r.region_name, month
),
region_stats AS (
    SELECT region_name, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY revenue) AS median_monthly_revenue, MAX(month) AS latest_month
    FROM monthly
    GROUP BY region_name
)
SELECT m.region_name, m.month, m.revenue, rs.median_monthly_revenue,
       (m.month = rs.latest_month) AS is_latest_month
FROM monthly m
JOIN region_stats rs ON rs.region_name = m.region_name
ORDER BY m.region_name, m.month;
/* Q94. */
WITH latest AS (
    SELECT DISTINCT ON (cust_id) cust_id, order_id AS latest_order_id, order_date AS latest_order_date, net_total AS latest_net_total
    FROM sales.orders
    ORDER BY cust_id, order_date DESC
)
SELECT c.tier,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_order_value,
       MAX(l.latest_order_date) AS most_recent_order_date
FROM sales.orders o
JOIN customers.customers c ON c.customer_id = o.cust_id
JOIN latest l ON l.cust_id = o.cust_id
GROUP BY c.tier
ORDER BY c.tier;
/* Q95. */
SELECT r.region_name,
       PERCENTILE_CONT(ARRAY[0.9, 0.95, 0.99]) WITHIN GROUP (ORDER BY o.net_total) AS p90_p95_p99
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;
/* Q96. */
WITH latest_snapshot AS (
    SELECT DISTINCT ON (warehouse_id) warehouse_id, quantity_on_hand AS latest_snapshot_qty
    FROM supply_chain.inventory_snapshots
    ORDER BY warehouse_id, snapshot_date DESC
)
SELECT w.warehouse_id, w.name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sh.delivered_date - o.order_date) AS median_delivery_days,
       MAX(ls.latest_snapshot_qty) AS latest_snapshot_qty
FROM sales.orders o
JOIN sales.shipments sh ON sh.order_id = o.order_id
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
JOIN supply_chain.warehouses w ON w.region = r.region_name
LEFT JOIN latest_snapshot ls ON ls.warehouse_id = w.warehouse_id
WHERE o.order_status = 'Delivered' AND sh.delivered_date IS NOT NULL
GROUP BY w.warehouse_id, w.name
ORDER BY w.warehouse_id;
/* Q97. */
SELECT r.region_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_order_value,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_order_value,
       RANK() OVER (ORDER BY PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) DESC) AS rnk
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY rnk;
/* Q98. */
SELECT pm.mode_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) FILTER (WHERE r.region_name = 'North') AS median_north,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) FILTER (WHERE r.region_name = 'South') AS median_south,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) FILTER (WHERE r.region_name = 'East') AS median_east,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) FILTER (WHERE r.region_name = 'West') AS median_west
FROM sales.orders o
JOIN finance.payment_modes pm ON pm.mode_id = o.payment_mode_id
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY pm.mode_name
ORDER BY pm.mode_name;
/* Q99. */
SELECT EXTRACT(YEAR FROM c.registration_date) AS cohort_year,
       EXTRACT(YEAR FROM o.order_date) AS order_year,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_net_total
FROM sales.orders o
JOIN customers.customers c ON c.customer_id = o.cust_id
GROUP BY cohort_year, order_year
ORDER BY cohort_year, order_year;
/* Q100. */
WITH latest AS (
    SELECT DISTINCT ON (r.region_name) r.region_name, o.order_date AS latest_order_date
    FROM sales.orders o
    JOIN stores.stores s ON s.store_id = o.store_id
    JOIN core.dim_region r ON r.region_id = s.region_id
    ORDER BY r.region_name, o.order_date DESC
)
SELECT r.region_name,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_order_value,
       PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY o.net_total) AS p90_order_value,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_order_value,
       MAX(l.latest_order_date) AS latest_order_date
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
JOIN latest l ON l.region_name = r.region_name
GROUP BY r.region_name
ORDER BY r.region_name;
