/* ============================================================
   ANSWER KEY - Subqueries Part 1 (HARD LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: SUBQUERY REWRITES (25)
   ------------------------------------------------------------ */
/* Q1. */
SELECT DISTINCT o.*
FROM sales.orders o
JOIN (SELECT cust_id FROM sales.orders GROUP BY cust_id ORDER BY SUM(net_total) DESC LIMIT 10) top ON top.cust_id = o.cust_id;

/* Q2. */
SELECT * FROM customers.customers c
WHERE NOT EXISTS (SELECT 1 FROM loyalty.members m WHERE m.customer_id = c.customer_id);

/* Q3. */
SELECT c.customer_id, COALESCE(o.order_count, 0) AS order_count
FROM customers.customers c
LEFT JOIN (SELECT cust_id, COUNT(*) AS order_count FROM sales.orders GROUP BY cust_id) o ON o.cust_id = c.customer_id
LIMIT 200;

/* Q4. */
SELECT o.order_id, c.first_name || ' ' || c.last_name AS customer_name
FROM sales.orders o
LEFT JOIN customers.customers c ON c.customer_id = o.cust_id
LIMIT 200;

/* Q5. */
SELECT DISTINCT c.*
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id;

/* Q6. */
WITH cust_stats AS (
  SELECT cust_id, COUNT(*) AS order_count, SUM(net_total) AS total_spend
  FROM sales.orders GROUP BY cust_id
)
SELECT c.customer_id, s.order_count, s.total_spend
FROM customers.customers c
LEFT JOIN cust_stats s ON s.cust_id = c.customer_id
LIMIT 200;

/* Q7. */
SELECT order_id, cust_id, net_total,
       MAX(net_total) OVER (PARTITION BY cust_id) AS max_order_for_customer
FROM sales.orders
LIMIT 200;

/* Q8. */
SELECT DISTINCT ON (cust_id) cust_id, order_id, order_date, net_total
FROM sales.orders
ORDER BY cust_id, net_total DESC;

/* Q9. */
SELECT c.customer_id, top_o.order_id, top_o.net_total
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id, net_total FROM sales.orders o WHERE o.cust_id = c.customer_id
  ORDER BY net_total DESC LIMIT 3
) top_o
LIMIT 200;

/* Q10. */
WITH cust_totals AS (
  SELECT cust_id, SUM(net_total) AS total FROM sales.orders GROUP BY cust_id
)
SELECT * FROM cust_totals WHERE total > (SELECT AVG(total) FROM cust_totals);

/* Q11. */
WITH orders_agg AS (
  SELECT cust_id, SUM(net_total) AS total FROM sales.orders GROUP BY cust_id
),
above_avg AS (
  SELECT * FROM orders_agg WHERE total > (SELECT AVG(total) FROM orders_agg)
)
SELECT c.customer_id, a.total
FROM customers.customers c
JOIN above_avg a ON a.cust_id = c.customer_id;

/* Q12. */
SELECT order_id, cust_id,
       COUNT(*) OVER (PARTITION BY cust_id) AS orders_by_this_customer
FROM sales.orders
LIMIT 200;

/* Q13. */
SELECT order_id, cust_id, net_total,
       MAX(net_total) OVER (PARTITION BY cust_id) AS customer_max_order
FROM sales.orders
LIMIT 200;

/* Q14. */
SELECT order_id, cust_id, COUNT(*) OVER (PARTITION BY cust_id) AS same_customer_count
FROM sales.orders
LIMIT 200;

/* Q15. */
SELECT DISTINCT ON (cust_id) cust_id, order_id, order_date
FROM sales.orders
ORDER BY cust_id, order_date DESC;

/* Q16. */
SELECT DISTINCT c.*
FROM customers.customers c
LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
WHERE o.order_id IS NOT NULL;

/* Q17. */
SELECT c.*
FROM customers.customers c
LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
WHERE o.order_id IS NULL;

/* Q18. */
SELECT * FROM sales.orders WHERE order_status = 'Cancelled'
UNION
SELECT * FROM sales.orders WHERE order_status = 'Returned';

/* Q19. */
SELECT DISTINCT c.*
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
JOIN customers.reviews r ON r.customer_id = c.customer_id;

/* Q20. */
SELECT c.category_name, top_p.product_id, top_p.product_name, top_p.price
FROM core.dim_category c
CROSS JOIN LATERAL (
  SELECT p.product_id, p.product_name, p.price
  FROM products.products p
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  WHERE b.category_id = c.category_id
  ORDER BY p.price DESC LIMIT 3
) top_p;

/* Q21. */
SELECT * FROM (
  SELECT *, COUNT(*) OVER (PARTITION BY email) AS email_count
  FROM customers.customers
) x
WHERE x.email_count > 1;

/* Q22. */
SELECT order_date,
       order_date - LAG(order_date) OVER (ORDER BY order_date) AS gap_from_prev_date
FROM (SELECT DISTINCT order_date FROM sales.orders) d
LIMIT 200;

/* Q23. */
SELECT order_date,
       order_date - (ROW_NUMBER() OVER (ORDER BY order_date))::int AS island_group
FROM (SELECT DISTINCT order_date FROM sales.orders) d
LIMIT 200;

/* Q24. */
WITH cust_order_dates AS (
  SELECT DISTINCT cust_id, order_date FROM sales.orders
)
SELECT cust_id, order_date,
       order_date - (ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date))::int AS run_group
FROM cust_order_dates
LIMIT 200;

/* Q25. */
SELECT store_id, SUM(net_total) AS revenue,
       ROUND(100.0 * SUM(net_total) / SUM(SUM(net_total)) OVER (), 2) AS pct_of_total
FROM sales.orders
GROUP BY store_id;

/* ============================================================
   SECTION B: PERFORMANCE FORENSICS (25)
   ------------------------------------------------------------ */
/* Q26. */
EXPLAIN ANALYZE
SELECT c.customer_id,
       (SELECT COUNT(*) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS order_count
FROM customers.customers c
LIMIT 200;

/* Q27. */
EXPLAIN ANALYZE
SELECT c.customer_id, COALESCE(o.order_count, 0) AS order_count
FROM customers.customers c
LEFT JOIN (SELECT cust_id, COUNT(*) AS order_count FROM sales.orders GROUP BY cust_id) o ON o.cust_id = c.customer_id;

/* Q28. */
EXPLAIN
SELECT * FROM sales.orders WHERE cust_id IN (SELECT customer_id FROM loyalty.members);

/* Q29. */
EXPLAIN
SELECT order_id, (SELECT c.tier FROM customers.customers c WHERE c.customer_id = o.cust_id) AS tier
FROM sales.orders o
LIMIT 200;

/* Q30. */
EXPLAIN
SELECT order_id, (SELECT MAX(net_total) FROM sales.orders o2 WHERE o2.cust_id = o.cust_id) AS max_for_cust
FROM sales.orders o
LIMIT 200;

/* Q31. */
EXPLAIN
SELECT * FROM sales.orders WHERE net_total > (SELECT AVG(net_total) FROM sales.orders);

/* Q32. */
EXPLAIN
SELECT * FROM customers.customers WHERE customer_id IN (SELECT cust_id FROM sales.orders);

/* Q33. */
EXPLAIN
SELECT * FROM customers.customers c WHERE NOT EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id);

/* Q34. Recommended DDL (run in a transaction so this answer key leaves RetailMart untouched): */
BEGIN;
CREATE INDEX idx_orders_cust_id ON sales.orders (cust_id);
ROLLBACK;

/* Q35. */
BEGIN;
CREATE INDEX idx_order_items_order_prod ON sales.order_items (order_id, prod_id);
ROLLBACK;

/* Q36. */
BEGIN;
CREATE INDEX idx_customers_lower_email ON customers.customers (LOWER(email));
ROLLBACK;

/* Q37. */
WITH cust_totals AS (
  SELECT cust_id, SUM(net_total) AS total FROM sales.orders GROUP BY cust_id
)
SELECT c.customer_id, ct.total
FROM customers.customers c
JOIN cust_totals ct ON ct.cust_id = c.customer_id
WHERE ct.total > 50000;

/* Q38. */
WITH cust_totals AS MATERIALIZED (
  SELECT cust_id, SUM(net_total) AS total FROM sales.orders GROUP BY cust_id
)
SELECT * FROM cust_totals WHERE total > 50000;

/* Q39. */
SELECT c.customer_id, recent.order_id, recent.order_date
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id, order_date FROM sales.orders o WHERE o.cust_id = c.customer_id
  ORDER BY order_date DESC LIMIT 1
) recent
LIMIT 200;

/* Q40. */
SELECT order_id, cust_id, net_total,
       AVG(net_total) OVER (PARTITION BY cust_id) AS cust_avg_order
FROM sales.orders
LIMIT 200;

/* Q41. */
SET enable_nestloop = off;
EXPLAIN SELECT * FROM sales.orders WHERE cust_id IN (SELECT customer_id FROM loyalty.members);
SET enable_nestloop = on;

/* Q42. */
SET random_page_cost = 1.1;
EXPLAIN SELECT * FROM sales.orders WHERE order_id = 100;
RESET random_page_cost;

/* Q43. */
SET work_mem = '64MB';
EXPLAIN SELECT cust_id, SUM(net_total) FROM sales.orders GROUP BY cust_id;
RESET work_mem;

/* Q44. Fix: make the subquery provably single-row with ORDER BY + LIMIT 1 (or an aggregate) instead of a bare filter that can match many rows. */
SELECT * FROM sales.orders
WHERE net_total = (SELECT net_total FROM sales.orders ORDER BY net_total DESC LIMIT 1);

/* Q45. */
SELECT c.customer_id,
       (SELECT o.order_id FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY o.order_date DESC LIMIT 1) AS latest_order_id
FROM customers.customers c
LIMIT 200;

/* Q46. Fix: make sure the subquery's SELECT list has exactly one column (drop the extras or pick the one needed). */
SELECT order_id FROM sales.orders WHERE cust_id = (SELECT customer_id FROM customers.customers WHERE customer_id = 5);

/* Q47. Fix: every derived table (subquery in FROM) needs an alias, even if you never reference it by name. */
SELECT * FROM (SELECT cust_id, SUM(net_total) AS total FROM sales.orders GROUP BY cust_id) AS s;

/* Q48. */
SELECT * FROM sales.orders WHERE cust_id IN (SELECT customer_id FROM loyalty.members);

/* Q49. N+1 shows up in app logs as one broad query followed by a burst of near-identical parameterized queries (e.g. many "SELECT ... FROM orders WHERE cust_id = $1") fired in a tight loop right after it - grep/aggregate the log by normalized query text and look for suspiciously high per-request call counts. */
/* Q50. This environment has no pg_stat_statements loaded (it requires shared_preload_libraries and a server restart); when available, the audit query is SELECT query, calls, total_exec_time, mean_exec_time FROM pg_stat_statements WHERE query ILIKE '%SELECT%' ORDER BY total_exec_time DESC LIMIT 10, filtered to statements containing a nested SELECT. */

/* ============================================================
   SECTION C: ANTI-PATTERN CATALOG (25)
   ------------------------------------------------------------ */
/* Q51. NOT IN silently returns zero rows if the subquery's result contains any NULL; always use NOT EXISTS (or filter the subquery with `col IS NOT NULL`) when the column can be NULL. */
/* Q52. A scalar subquery in SELECT is a SubPlan re-evaluated per output row; over a huge table this multiplies a small per-row cost by millions - rewrite as a JOIN to a pre-aggregated derived table or a window function instead. */
/* Q53. A correlated subquery forces (or strongly encourages) a nested-loop, per-row plan; the planner often can't flatten it the way it can a plain JOIN, so an equivalent JOIN is usually faster and easier to index. */
/* Q54. Issuing one subquery-style lookup per item inside an application loop is the same N+1 problem restated in ORM code; fetch everything in one query with a JOIN or a single IN (...) instead of looping. */
/* Q55. A subquery filtering on an unindexed foreign key forces a full sequential scan of the child table for every outer row; add an index on the correlated column to turn that into a fast lookup. */
/* Q56. ORDER BY (subquery) must evaluate the subquery for every row before it can sort anything; precompute the value once (CTE/window/join) so the sort key is already sitting on the row. */
/* Q57. EXISTS already returns each outer row at most once (it's a boolean test, not a row multiplier); a DISTINCT stacked on top just adds a wasted sort/hash step with no effect on the result. */
/* Q58. EXISTS (SELECT col FROM ...) discards the SELECT list entirely - only row existence is checked - so the specific column named there is pure noise; SELECT 1 (or SELECT *) is the idiomatic, equally-fast form. */
/* Q59. A literal IN-list with 100k hardcoded values bloats the query text and plan; the semi-join optimizer works far better against a real subquery, a VALUES list, or a temp table join. */
/* Q60. WHERE col IN (SELECT col FROM same_table) is often a sign the author actually just wants unique values - if there's no extra filtering happening in the subquery, `SELECT DISTINCT col FROM same_table` says the same thing more directly. */
/* Q61. A triple-nested correlated subquery is hard to read, hard to index, and hard for the planner to optimize as a unit; flatten it into a chain of CTEs or a single multi-table JOIN with GROUP BY. */
/* Q62. A subquery producing an ORDER BY'd result with no LIMIT sorts the entire set even though only a handful of rows (or none, if just used for EXISTS) are ever consumed - add LIMIT wherever only a "top few" are actually needed. */
/* Q63. Forcing materialization of a CTE that's only referenced once (and would benefit from predicate pushdown) prevents the planner from folding its filters into the outer query; NOT MATERIALIZED lets it inline back into a single efficient plan. */
/* Q64. An accidental missing join condition inside a NOT EXISTS subquery creates a cross product between its tables, inflating the number of rows it has to check per outer row far beyond what was intended. */
/* Q65. A HAVING subquery that re-scans a large table for every group (instead of comparing against a single pre-computed aggregate) turns an O(groups) query into something closer to O(groups * table size); pre-aggregate once in a CTE first. */
/* Q66. Pulling back an entire JSON/JSONB document via a scalar subquery when only one key is needed wastes I/O and serialization; extract just the needed field (e.g. with ->> ) inside the subquery instead. */
/* Q67. A hardcoded IN (1,2,3,...) list that mirrors real rows in a lookup table should be a JOIN (or IN (subquery)) to that table, so it stays correct automatically as the lookup table changes. */
/* Q68. A subquery embedded inside a CASE expression is re-evaluated for every branch check, once per row; compute it once beforehand (CTE, join, or window function) and reference the precomputed value in the CASE. */
/* Q69. Selecting an entire row via a scalar subquery (which Postgres allows as a composite-type value) is wasteful and awkward to consume; either select only the specific columns needed, or use a proper JOIN. */
/* Q70. Combining GROUP BY, a correlated subquery, and a window function to answer a question that only needs one of the three makes the query slower and much harder to reason about; pick the single simplest technique that answers the question. */
/* Q71. SELECT * inside a subquery pulls every column through the whole plan (serialization, memory, sometimes TOAST fetches) even though the outer query only needs one or two of them; select only the needed columns. */
/* Q72. Wrapping a derived table inside another derived table inside another, each with its own alias, just to pass columns through unchanged adds noise without changing the result; flatten with CTEs or drop the redundant layers. */
/* Q73. WHERE x = ANY(subquery) can only express "matches something"; it has no way to express "matches nothing" (an anti-join) - use NOT IN/NOT EXISTS for that instead. */
/* Q74. A subquery correctly narrows down which rows to touch, but if the DELETE/UPDATE statement itself is missing (or the subquery predicate is wrong) it's easy to accidentally hit every row - always preview the affected rows with a plain SELECT ... WHERE (same predicate) first. */
/* Q75. A subquery with LIMIT 1 but no ORDER BY returns whatever row the planner happens to scan first (undefined, and it can change between runs/plans) - always ORDER BY the column that defines "the one row you want" before LIMIT 1. */

/* ============================================================
   SECTION D: REAL-WORLD PRODUCTION PATTERNS (25)
   ------------------------------------------------------------ */
/* Q76. */
SELECT email, COUNT(*) AS cnt
FROM customers.customers
GROUP BY email
HAVING COUNT(*) > 1;

/* Q77. */
SELECT oi.* FROM sales.order_items oi
WHERE NOT EXISTS (SELECT 1 FROM sales.orders o WHERE o.order_id = oi.order_id);

/* Q78. */
SELECT s.* FROM sales.shipments s
WHERE s.delivered_date IS NOT NULL
  AND s.delivered_date - s.shipped_date > (
    SELECT AVG(delivered_date - shipped_date) FROM sales.shipments WHERE delivered_date IS NOT NULL
  );

/* Q79. */
SELECT cust_id, SUM(net_total) AS total_spend
FROM sales.orders
GROUP BY cust_id
HAVING SUM(net_total) > (
  SELECT AVG(t.total) FROM (SELECT cust_id, SUM(net_total) AS total FROM sales.orders GROUP BY cust_id) t
);

/* Q80. */
SELECT * FROM sales.orders
WHERE net_total < (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total) FROM sales.orders)
LIMIT 200;

/* Q81. */
SELECT cust_id, SUM(net_total) AS ltv
FROM sales.orders
GROUP BY cust_id
HAVING SUM(net_total) > (
  SELECT PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY t.total) FROM (SELECT cust_id, SUM(net_total) AS total FROM sales.orders GROUP BY cust_id) t
);

/* Q82. */
SELECT prod_id, SUM(quantity) AS units_sold
FROM sales.order_items
GROUP BY prod_id
HAVING SUM(quantity) < (
  SELECT AVG(qty) FROM (SELECT SUM(quantity) AS qty FROM sales.order_items GROUP BY prod_id) t
);

/* Q83. */
SELECT * FROM support.tickets
WHERE priority IN ('Critical','High') AND status NOT IN ('Resolved','Closed');

/* Q84. */
SELECT m.customer_id, m.points_balance
FROM loyalty.members m
WHERE m.tier_id = (SELECT tier_id FROM loyalty.tiers WHERE tier_name = 'Gold')
  AND m.points_balance > (SELECT min_points FROM loyalty.tiers WHERE tier_name = 'Platinum');

/* Q85. */
SELECT * FROM supply_chain.inventory_snapshots s
WHERE s.snapshot_date < (SELECT MAX(snapshot_date) FROM supply_chain.inventory_snapshots) - INTERVAL '180 days'
LIMIT 200;

/* Q86. */
SELECT cust_id, last_order_date
FROM (SELECT cust_id, MAX(order_date) AS last_order_date FROM sales.orders GROUP BY cust_id) x
WHERE last_order_date < (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '180 days';

/* Q87. */
SELECT cust_id, SUM(net_total) AS total_spend
FROM sales.orders o
WHERE NOT EXISTS (SELECT 1 FROM loyalty.members m WHERE m.customer_id = o.cust_id)
GROUP BY cust_id
HAVING SUM(net_total) > 50000;

/* Q88. */
SELECT cust_id, COUNT(*) AS orders_last_30d, SUM(net_total) AS spend_last_30d
FROM sales.orders
WHERE order_date >= (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '30 days'
GROUP BY cust_id
HAVING COUNT(*) > 5 AND SUM(net_total) > 100000;

/* Q89. */
SELECT agent_id, COUNT(*) AS resolved_count
FROM support.tickets
WHERE status = 'Resolved'
GROUP BY agent_id
ORDER BY resolved_count DESC
LIMIT 10;

/* Q90. */
SELECT s.* FROM products.suppliers s
WHERE NOT EXISTS (
  SELECT 1 FROM supply_chain.shipments sh
  WHERE sh.supplier_id = s.supplier_id
    AND sh.shipped_date >= (SELECT MAX(shipped_date) FROM supply_chain.shipments) - INTERVAL '90 days'
);

/* Q91. */
SELECT c.campaign_id, c.campaign_name,
       (SELECT SUM(amount) FROM marketing.ads_spend a WHERE a.campaign_id = c.campaign_id) AS total_spend,
       (SELECT SUM(emails_clicked) FROM marketing.email_clicks e WHERE e.campaign_id = c.campaign_id) AS total_clicks
FROM marketing.campaigns c;

/* Q92. */
SELECT w.warehouse_id, w.name,
       (SELECT MAX(snapshot_date) FROM supply_chain.inventory_snapshots s WHERE s.warehouse_id = w.warehouse_id) AS latest_snapshot
FROM supply_chain.warehouses w;

/* Q93. */
SELECT courier_name,
       COUNT(*) AS total_shipments,
       COUNT(*) FILTER (WHERE delivered_date - shipped_date > 5) AS late_shipments
FROM sales.shipments
WHERE delivered_date IS NOT NULL
GROUP BY courier_name;

/* Q94. */
SELECT DATE_TRUNC('month', o.order_date) AS month, c.category_name, SUM(oi.net_amount) AS revenue
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category c ON c.category_id = b.category_id
GROUP BY DATE_TRUNC('month', o.order_date), c.category_name
ORDER BY month, c.category_name
LIMIT 200;

/* Q95. */
SELECT b.brand_name,
       SUM(oi.net_amount) FILTER (WHERE o.order_date >= (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '90 days') AS recent_revenue,
       SUM(oi.net_amount) FILTER (WHERE o.order_date < (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '90 days') AS prior_revenue
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
JOIN products.products p ON p.product_id = oi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
GROUP BY b.brand_name;

/* Q96. */
SELECT tier, COUNT(*) AS customers_updated_recently
FROM customers.customers
WHERE tier_updated_at >= (SELECT MAX(tier_updated_at) FROM customers.customers) - INTERVAL '90 days'
GROUP BY tier;

/* Q97. */
SELECT m.customer_id
FROM loyalty.members m
WHERE NOT EXISTS (
  SELECT 1 FROM sales.orders o
  WHERE o.cust_id = m.customer_id
    AND o.order_date >= (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '180 days'
);

/* Q98. */
SELECT
  (SELECT COUNT(*) FROM sales.orders) AS total_orders,
  (SELECT SUM(net_total) FROM sales.orders) AS total_revenue,
  (SELECT COUNT(*) FROM customers.customers) AS total_customers,
  (SELECT COUNT(*) FROM products.products) AS total_products,
  (SELECT COUNT(*) FROM stores.stores) AS total_stores,
  (SELECT COUNT(*) FROM support.tickets WHERE status = 'Open') AS open_tickets,
  (SELECT AVG(net_total) FROM sales.orders) AS avg_order_value,
  (SELECT COUNT(*) FROM sales.returns) AS total_returns,
  (SELECT SUM(refund_amount) FROM sales.returns) AS total_refunded,
  (SELECT COUNT(*) FROM loyalty.members) AS loyalty_members,
  (SELECT COUNT(*) FROM marketing.campaigns) AS total_campaigns,
  (SELECT SUM(amount) FROM marketing.ads_spend) AS total_ad_spend,
  (SELECT COUNT(*) FROM stores.employees) AS total_employees,
  (SELECT COUNT(*) FROM sales.shipments WHERE status = 'Delivered') AS delivered_shipments,
  (SELECT COUNT(DISTINCT cust_id) FROM sales.orders) AS active_ordering_customers,
  (SELECT AVG(rating) FROM customers.reviews) AS avg_review_rating,
  (SELECT COUNT(*) FROM customers.reviews) AS total_reviews,
  (SELECT COUNT(*) FROM call_center.calls) AS total_calls,
  (SELECT COUNT(*) FROM supply_chain.warehouses) AS total_warehouses,
  (SELECT COUNT(*) FROM products.suppliers) AS total_suppliers;

/* Q99. */
SELECT 'customers.customers.email' AS column_ref, COUNT(*) AS null_count FROM customers.customers WHERE email IS NULL
UNION ALL
SELECT 'customers.customers.phone', COUNT(*) FROM customers.customers WHERE phone IS NULL
UNION ALL
SELECT 'sales.orders.payment_mode_id', COUNT(*) FROM sales.orders WHERE payment_mode_id IS NULL
UNION ALL
SELECT 'products.products.supplier_id', COUNT(*) FROM products.products WHERE supplier_id IS NULL;

/* Q100. */
SELECT order_id, net_total,
       (net_total - (SELECT AVG(net_total) FROM sales.orders)) / (SELECT STDDEV(net_total) FROM sales.orders) AS z_score
FROM sales.orders
WHERE ABS((net_total - (SELECT AVG(net_total) FROM sales.orders)) / (SELECT STDDEV(net_total) FROM sales.orders)) > 3
LIMIT 200;

/* ============================================================
   END OF ANSWER KEY - Subqueries Part 1 - HARD LEVEL (100/100)
============================================================ */
