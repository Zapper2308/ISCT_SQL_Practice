/* ============================================================
   ANSWER KEY - JOINs Part 2 (Advanced) (HARD LEVEL)
   Curriculum:   RetailMart V3
   Note: this database has NO indexes on foreign-key columns, so
   LATERAL/correlated patterns whose driving table is large (orders,
   customers, order_items, page_views) are restricted to a bounded
   sample where noted; the same pattern is correct unrestricted, just
   slower on this unindexed practice copy.
   ============================================================ */

/* ============================================================
   SECTION A: ADVANCED JOIN PART 2 - CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1.  LATERAL is planned as a repeated (re-evaluated) subquery execution: for every row produced by the FROM items to its left, PostgreSQL substitutes that row's column values into the LATERAL subquery and runs it fresh - conceptually a Nested Loop where the inner side is parameterized per outer row. */
/* Q2.  Both return "one row per group, the latest one"; LATERAL LIMIT 1 (ORDER BY ... DESC LIMIT 1 in a correlated subquery/JOIN) is flexible for pulling several columns and works naturally inside any FROM clause; DISTINCT ON (group_col) ORDER BY group_col, tiebreaker DESC is more concise for a single table but less flexible when the "latest" needs a join first. */
/* Q3.  Required whenever the two sides' key columns can independently be NULL for unmatched rows (the normal FULL OUTER JOIN case) and downstream code needs one non-NULL identifier; optional when you only ever read the two key columns separately (never need a single unified key) or when a NOT NULL constraint on one side's key guarantees it's always populated for matched pairs. */
/* Q4.  CROSS JOIN LATERAL generate_series(1, n) FROM parent lets `n` be an expression referencing the parent row itself (not a fixed constant), producing however many rows THAT specific parent row calls for - each parent row triggers its own independent generate_series() call, i.e. true per-row explosion. */
/* Q5.  A self-join computing "previous row per group" scans/joins the whole table against itself (cost scales with group sizes squared in the worst case); a window function like LAG() makes one single ordered pass over the data with no join at all - almost always faster and simpler for the exact same result. */
/* Q6.  UNION ALL takes multiple independent result sets and stacks their rows one after another (a vertical concatenation, same columns, more rows); JOIN combines two result sets side-by-side by matching keys (a horizontal combination, more columns per row) - fundamentally different shapes of combination. */
/* Q7.  INTERSECT uses Hash Aggregate when the inputs are unsorted and small/medium enough to fit a hash table of one side in memory; it falls back to Sort + Merge when inputs are already sorted (e.g. from an index) or too large for an efficient hash build, letting it compare pre-sorted streams instead. */
/* Q8.  EXCEPT (NOT NOT EXISTS) does a single whole-row set-subtraction pass and naturally treats NULL-vs-NULL in a column as a match; NOT EXISTS becomes tricky and error-prone across MANY columns (you'd need an explicit multi-column, NULL-safe correlated condition) - EXCEPT is often clearer and less bug-prone for "are these two full rows/records identical" comparisons. */
/* Q9.  "Every X who has ALL Ys" (relational division): count how many DISTINCT Ys each X is associated with, and keep only Xs where that count equals the total number of Ys that exist - e.g. suppliers who shipped to every warehouse: GROUP BY supplier_id HAVING COUNT(DISTINCT warehouse_id) = (SELECT COUNT(*) FROM warehouses). */
/* Q10. Because reconciliation's core question - "what exists on side A but not B, what exists on B but not A, and what matches on both" - is EXACTLY what FULL OUTER JOIN computes in one pass; no other single join type surfaces all three categories together. */
/* Q11. FULL OUTER JOIN a a LEFT b b ON a.key=b.key: rows where BOTH a.key and b.key are non-NULL are "both"; rows where a.key is non-NULL and b.key IS NULL are "only-left"; rows where a.key IS NULL and b.key is non-NULL are "only-right" - the 4th bucket (neither) doesn't apply to a two-table FULL OUTER JOIN, since every output row came from at least one side by definition. */
/* Q12. A self-join a.x=b.x AND a.y<b.y directly compares each row to every OTHER matching row in one join step, producing all qualifying pairs at once; a correlated subquery (WHERE b.y = (SELECT ... WHERE inner.x=outer.x AND inner.y>outer.y ...)) runs a fresh lookup PER outer row - same logical result, but the self-join can be planned as one big hash/sort operation while the correlated subquery is inherently row-by-row. */
/* Q13. UNION ALL keeps every duplicate row because it does no comparison work at all - just concatenates; UNION must compare every row against every other row (via sort or hash) to find and remove duplicates, which costs extra CPU/memory proportional to the combined row count - hence UNION ALL being cheaper whenever duplicates are fine to keep. */
/* Q14. Self-join the table to itself on the grouping key with a "greater than" ordering condition (b.event_time > a.event_time), then use NOT EXISTS to exclude any candidate b that isn't the immediate next one (i.e., exclude b if some other c exists strictly between a and b) - equivalent to, but more verbose than, LEAD(). */
/* Q15. Because a CROSS JOIN of dim x dim x dim has no join condition to filter anything, and PostgreSQL cannot know how many result rows are "wanted" per combination without an explicit aggregate - ARRAY_AGG lets you collapse the exploded grid back into one row per outer dimension holding an array of the inner dimension's values, keeping the grid compact and readable. */
/* Q16. small x small x small (e.g. 20 regions x 10 categories x 4 tiers = 800 rows) is trivial and instant; huge x huge (e.g. 50,000 customers x 50,000 customers) produces 2.5 BILLION rows - a performance cliff where the output size alone (before any filtering) becomes computationally and physically infeasible. */
/* Q17. CROSS JOIN a full date/dimension grid against every possible key combination, then LEFT JOIN the real fact data onto that grid and wrap every measure in COALESCE(measure, 0) - guarantees every cell of the report exists (dense), even for combinations with zero real activity, instead of silently omitting them (sparse). */
/* Q18. Because a plain (non-LATERAL) subquery in FROM is evaluated once, independently, with no access to sibling FROM items' columns - "for each parent, get its own top-N children" inherently needs the child subquery to know WHICH parent it's fetching for, which only LATERAL (or an equivalent correlated construct) can provide. */
/* Q19. When BOTH the equality key AND a range/inequality condition are combined (a.x=b.x AND a.y<b.y) - this is common for "find the next/previous row within the same group" patterns, letting PostgreSQL hash on the equality part while still filtering with the inequality per matching bucket. */
/* Q20. UNION performs a dedup pass that discards rows it considers exact duplicates, so any legitimate repeated real-world event that happens to produce identical column values gets silently reduced to one row - that's desirable only when true duplicates genuinely represent the SAME fact (like combining two overlapping mailing lists), not when each row is a distinct event. */
/* Q21. When you're comparing on EVERY selected column between two independently-built result sets with the SAME shape - INTERSECT can replace INNER JOIN ON col1=col1 AND col2=col2 AND ... (all columns) + DISTINCT, since that's literally what INTERSECT computes as whole-row set matching. */
/* Q22. CROSS JOIN unnest(array_col) inside a FROM clause expands the array once as an independent virtual table, joined to everything else; unnest(array_col) used directly in the SELECT list instead returns a SET (multiple output rows) from a single expression, implicitly behaving like a lateral expansion tied to that specific row - same expansion, different syntactic placement and how explicit the row-multiplication is. */
/* Q23. A PIVOT reshapes long/tall data (one row per category) into wide data (one column per category value) - in PostgreSQL you simulate it with GROUP BY plus one aggregate-with-FILTER expression per target column, e.g. COUNT(*) FILTER (WHERE status='Open') AS open_count, COUNT(*) FILTER (WHERE status='Closed') AS closed_count. */
/* Q24. An UNPIVOT reshapes wide data (many measure columns) back into long/tall data (one row per measure) - simulated in PostgreSQL with UNION ALL, one SELECT per original column, each labeling which metric it came from: SELECT id,'col_a' AS metric,col_a AS value UNION ALL SELECT id,'col_b',col_b ... */
/* Q25. Identify each session's landing page and first-touch source via LATERAL (grabbing the earliest page_view per session), then use set operations (UNION ALL of "converted" and "not converted" cohorts, or EXCEPT to find sessions with no matching order) to attribute the session's outcome - a realistic funnel query typically layers both techniques together. */

/* ============================================================
   SECTION B: LATERAL DEEP (25)
   ------------------------------------------------------------ */
/* Q26. Restricted to a customer sample since the driving table (50,000 customers) has no supporting index for a per-row correlated lookup on this practice database. */
SELECT c.customer_id, lo.order_id, lo.order_date, lo.net_total
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT o.order_id, o.order_date, o.net_total FROM sales.orders o
  WHERE o.cust_id = c.customer_id ORDER BY o.order_date DESC LIMIT 5
) lo
WHERE c.customer_id <= 100;

/* Q27. Restricted to a product sample since reviews has no index on product_id for a per-row correlated lookup on this practice database. */
SELECT p.product_id, lr.review_id, lr.rating, lr.review_date
FROM products.products p
CROSS JOIN LATERAL (
  SELECT r.review_id, r.rating, r.review_date FROM customers.reviews r
  WHERE r.product_id = p.product_id ORDER BY r.review_date DESC LIMIT 3
) lr
WHERE p.product_id <= 300;

/* Q28. */
SELECT r.region_name, ts.store_name, ts.revenue
FROM core.dim_region r
CROSS JOIN LATERAL (
  SELECT s.store_name, SUM(o.net_total) AS revenue
  FROM stores.stores s JOIN sales.orders o ON o.store_id = s.store_id
  WHERE s.region_id = r.region_id
  GROUP BY s.store_name ORDER BY SUM(o.net_total) DESC LIMIT 5
) ts;

/* Q29. */
SELECT cat.category_name, tp.product_name, tp.units_sold
FROM core.dim_category cat
CROSS JOIN LATERAL (
  SELECT p.product_name, SUM(oi.quantity) AS units_sold
  FROM products.products p
  JOIN core.dim_brand b ON p.brand_id = b.brand_id
  JOIN sales.order_items oi ON oi.prod_id = p.product_id
  WHERE b.category_id = cat.category_id
  GROUP BY p.product_name ORDER BY SUM(oi.quantity) DESC LIMIT 3
) tp;

/* Q30. */
SELECT e.employee_id, lt.ticket_id, lt.resolved_date
FROM stores.employees e
CROSS JOIN LATERAL (
  SELECT t.ticket_id, t.resolved_date FROM support.tickets t
  WHERE t.agent_id = e.employee_id AND t.resolved_date IS NOT NULL
  ORDER BY t.resolved_date DESC LIMIT 5
) lt;

/* Q31. */
SELECT a.platform, tc.campaign_id, tc.total_spend
FROM (SELECT DISTINCT platform FROM marketing.ads_spend) a
CROSS JOIN LATERAL (
  SELECT ads.campaign_id, SUM(ads.amount) AS total_spend
  FROM marketing.ads_spend ads
  WHERE ads.platform = a.platform
  GROUP BY ads.campaign_id ORDER BY SUM(ads.amount) DESC LIMIT 3
) tc;

/* Q32. */
SELECT w.warehouse_id, os.product_id, os.snapshot_date
FROM supply_chain.warehouses w
CROSS JOIN LATERAL (
  SELECT product_id, snapshot_date FROM supply_chain.inventory_snapshots isn
  WHERE isn.warehouse_id = w.warehouse_id ORDER BY isn.snapshot_date ASC LIMIT 1
) os;

/* Q33. */
SELECT sup.supplier_id, rs.shipment_id, rs.shipped_date
FROM products.suppliers sup
CROSS JOIN LATERAL (
  SELECT shipment_id, shipped_date FROM supply_chain.shipments sh
  WHERE sh.supplier_id = sup.supplier_id ORDER BY sh.shipped_date DESC LIMIT 3
) rs;

/* Q34. */
SELECT cr.call_reason, lc.call_id, lc.call_duration_seconds
FROM (SELECT DISTINCT call_reason FROM call_center.calls) cr
CROSS JOIN LATERAL (
  SELECT call_id, call_duration_seconds FROM call_center.calls c
  WHERE c.call_reason = cr.call_reason ORDER BY c.call_duration_seconds DESC LIMIT 1
) lc;

/* Q35. */
SELECT d.dept_id, he.employee_id, he.salary
FROM core.dim_department d
CROSS JOIN LATERAL (
  SELECT employee_id, salary FROM stores.employees e
  WHERE e.dept_id = d.dept_id ORDER BY e.salary DESC LIMIT 1
) he;

/* Q36. */
SELECT o.order_id, gs.installment_no, ROUND(o.net_total / 3, 2) AS installment_amount
FROM sales.orders o
CROSS JOIN LATERAL GENERATE_SERIES(1, 3) AS gs(installment_no)
WHERE o.order_id <= 1000
ORDER BY o.order_id, gs.installment_no;

/* Q37. */
SELECT sh.shipment_id, step.step_name
FROM sales.shipments sh
CROSS JOIN LATERAL (VALUES ('shipped'), ('in-transit'), ('delivered')) AS step(step_name)
WHERE sh.shipment_id <= 1000
ORDER BY sh.shipment_id;

/* Q38. */
SELECT c.customer_id, mon.month_start
FROM customers.customers c
CROSS JOIN LATERAL GENERATE_SERIES(DATE_TRUNC('month', c.registration_date), DATE_TRUNC('month', c.registration_date) + INTERVAL '11 months', '1 month') AS mon(month_start)
WHERE c.customer_id <= 20
ORDER BY c.customer_id, mon.month_start;

/* Q39. Restricted to a bounded sample of products, since a per-product correlated scan of the unindexed 375,000-row order_items table doesn't scale to all 6,036 products on this practice database. */
SELECT p.product_id, db.distinct_buyers
FROM products.products p
CROSS JOIN LATERAL (
  SELECT COUNT(DISTINCT o.cust_id) AS distinct_buyers
  FROM sales.order_items oi JOIN sales.orders o ON oi.order_id = o.order_id
  WHERE oi.prod_id = p.product_id
) db
WHERE p.product_id <= 100;

/* Q40. */
SELECT t.ticket_id, t.customer_id, pt.ticket_id AS previous_ticket_id
FROM support.tickets t
CROSS JOIN LATERAL (
  SELECT ticket_id FROM support.tickets t2
  WHERE t2.customer_id = t.customer_id AND t2.created_date < t.created_date
  ORDER BY t2.created_date DESC LIMIT 1
) pt
LIMIT 200;

/* Q41. */
SELECT c.customer_id, jo.orders_json
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT JSON_AGG(JSON_BUILD_OBJECT('order_id', o.order_id, 'order_date', o.order_date, 'net_total', o.net_total)) AS orders_json
  FROM sales.orders o WHERE o.cust_id = c.customer_id
) jo
WHERE c.customer_id <= 50;

/* Q42. Restricted to an early view_id band since page_views has no index on session_id and each match needs a per-session correlated scan. */
SELECT pv.session_id, pv.view_id AS checkout_view_id, prev.view_id AS page_before_checkout
FROM web_events.page_views pv
CROSS JOIN LATERAL (
  SELECT view_id FROM web_events.page_views p2
  WHERE p2.session_id = pv.session_id AND p2.view_timestamp < pv.view_timestamp
  ORDER BY p2.view_timestamp DESC LIMIT 1
) prev
WHERE pv.page_url ILIKE '%checkout%'
  AND pv.view_id <= 5000
LIMIT 200;

/* Q43. */
SELECT c.customer_id, lo.order_id, fi.prod_id, p.product_name
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY o.order_date DESC LIMIT 1
) lo
CROSS JOIN LATERAL (
  SELECT prod_id FROM sales.order_items oi WHERE oi.order_id = lo.order_id ORDER BY oi.order_item_id LIMIT 1
) fi
JOIN products.products p ON p.product_id = fi.prod_id
WHERE c.customer_id <= 100;

/* Q44. Restricted to an order_id band since sales.payments has no index on order_id for a per-row correlated lookup. */
SELECT o.order_id, lp.payment_id
FROM sales.orders o
CROSS JOIN LATERAL (
  SELECT payment_id FROM sales.payments p WHERE p.order_id = o.order_id AND p.amount = o.net_total LIMIT 1
) lp
WHERE o.order_id <= 500
LIMIT 200;

/* Q45. */
SELECT c.customer_id, lo.order_id
FROM customers.customers c
LEFT JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY o.order_date DESC LIMIT 1
) lo ON TRUE
WHERE c.customer_id <= 200;

/* Q46. */
SELECT c.customer_id, big.order_id
FROM customers.customers c
LEFT JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.cust_id = c.customer_id AND o.net_total > 1000000 LIMIT 0
) big ON TRUE
WHERE c.customer_id <= 50;

/* Q47. */
SELECT c.customer_id, has_order.exists_flag
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT EXISTS(SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id) AS exists_flag
) has_order
WHERE c.customer_id <= 200;

/* Q48. */
SELECT c.campaign_id, c.start_date, gs.bucket_date
FROM marketing.campaigns c
CROSS JOIN LATERAL GENERATE_SERIES(c.start_date, c.end_date, INTERVAL '7 days') AS gs(bucket_date)
LIMIT 200;

/* Q49. */
SELECT cat.category_name, tp.product_name, tp.units_sold
FROM core.dim_category cat
CROSS JOIN LATERAL (
  SELECT p.product_name, SUM(oi.quantity) AS units_sold
  FROM products.products p
  JOIN core.dim_brand b ON p.brand_id = b.brand_id
  JOIN sales.order_items oi ON oi.prod_id = p.product_id
  WHERE b.category_id = cat.category_id
  GROUP BY p.product_name ORDER BY SUM(oi.quantity) DESC LIMIT 3
) tp;

/* Q50. Restricted to a small order_id band since order_items has no index on order_id for a per-row correlated lookup. */
SELECT o.order_id, ti.order_item_id, ti.net_amount
FROM sales.orders o
CROSS JOIN LATERAL (
  SELECT order_item_id, net_amount FROM sales.order_items oi
  WHERE oi.order_id = o.order_id ORDER BY oi.net_amount DESC LIMIT 3
) ti
WHERE o.order_id <= 100;

/* ============================================================
   SECTION C: SELF-JOIN ADVANCED (25)
   ------------------------------------------------------------ */
/* Q51. */
SELECT o1.order_id AS this_order, o1.order_date AS this_date, np.order_id AS next_order,
       np.order_date - o1.order_date AS gap_days
FROM sales.orders o1
CROSS JOIN LATERAL (
  SELECT order_id, order_date FROM sales.orders o2
  WHERE o2.cust_id = o1.cust_id AND o2.order_date > o1.order_date
  ORDER BY o2.order_date ASC LIMIT 1
) np
WHERE o1.cust_id <= 500;

/* Q52. */
SELECT cust_id, order_date, COUNT(*) AS orders_that_day
FROM sales.orders
GROUP BY cust_id, order_date
HAVING COUNT(*) >= 2;

/* Q53. */
SELECT o1.cust_id, o1.order_id AS order1, o2.order_id AS order2, oi1.prod_id
FROM sales.orders o1
JOIN sales.order_items oi1 ON oi1.order_id = o1.order_id
JOIN sales.orders o2 ON o2.cust_id = o1.cust_id AND o2.order_date > o1.order_date + 30
JOIN sales.order_items oi2 ON oi2.order_id = o2.order_id AND oi2.prod_id = oi1.prod_id
WHERE o1.cust_id <= 500
LIMIT 200;

/* Q54. */
SELECT t1.ticket_id, nt.ticket_id AS next_ticket_id
FROM support.tickets t1
CROSS JOIN LATERAL (
  SELECT ticket_id FROM support.tickets t2
  WHERE t2.customer_id = t1.customer_id AND t2.created_date > t1.created_date
  ORDER BY t2.created_date ASC LIMIT 1
) nt
LIMIT 200;

/* Q55. */
SELECT i1.product_id, i1.warehouse_id AS warehouse1, i2.warehouse_id AS warehouse2, i1.snapshot_date, i2.snapshot_date
FROM supply_chain.inventory_snapshots i1
JOIN supply_chain.inventory_snapshots i2
  ON i1.product_id = i2.product_id AND i1.warehouse_id < i2.warehouse_id
 AND i1.quantity_on_hand < 10 AND i2.quantity_on_hand < 10
 AND i2.snapshot_date BETWEEN i1.snapshot_date AND i1.snapshot_date + 7
LIMIT 200;

/* Q56. */
SELECT c.customer_id, c.registration_date, fo.order_date AS first_purchase_date,
       fo.order_date - c.registration_date AS days_to_first_purchase
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_date FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY o.order_date ASC LIMIT 1
) fo
WHERE c.customer_id <= 500;

/* Q57. */
SELECT p1.product_id AS cheaper_id, p1.price AS cheaper_price, p2.product_id AS pricier_id, p2.price AS pricier_price
FROM products.products p1
JOIN products.products p2 ON p1.brand_id = p2.brand_id AND p2.price > p1.price
LIMIT 200;

/* Q58. */
SELECT c1.campaign_id AS campaign1, c2.campaign_id AS campaign2
FROM marketing.campaigns c1
JOIN marketing.campaigns c2
  ON c1.campaign_id < c2.campaign_id
 AND c1.start_date <= c2.end_date AND c2.start_date <= c1.end_date;

/* Q59. */
SELECT r.order_id, r.prod_id, r.return_date, o.order_date
FROM sales.returns r
JOIN sales.orders o ON r.order_id = o.order_id
WHERE r.return_date <= o.order_date + 7;

/* Q60. */
SELECT customer_id, COUNT(*) AS open_ticket_count
FROM support.tickets
WHERE status = 'Open'
GROUP BY customer_id
HAVING COUNT(*) >= 2;

/* Q61. */
SELECT e1.employee_id AS emp1, e2.employee_id AS emp2, e1.store_id
FROM stores.employees e1
JOIN stores.employees e2 ON e1.store_id = e2.store_id AND e1.employee_id < e2.employee_id
LIMIT 200;

/* Q62. */
SELECT p1.product_id AS product1, p2.product_id AS product2, b.category_id
FROM products.products p1
JOIN core.dim_brand b ON p1.brand_id = b.brand_id
JOIN products.products p2 ON p2.product_id > p1.product_id
JOIN core.dim_brand b2 ON p2.brand_id = b2.brand_id AND b2.category_id = b.category_id
LIMIT 200;

/* Q63. */
SELECT e1.employee_id AS emp1, e2.employee_id AS emp2, e1.store_id
FROM stores.employees e1
JOIN stores.employees e2
  ON e1.store_id = e2.store_id AND e1.employee_id < e2.employee_id
 AND ABS(e2.joining_date - e1.joining_date) <= 30
LIMIT 200;

/* Q64. */
SELECT order_id, COUNT(*) AS return_count
FROM sales.returns
GROUP BY order_id
HAVING COUNT(*) >= 2;

/* Q65. */
SELECT DATE_TRUNC('month', registration_date) AS reg_month, COUNT(*) AS new_customers
FROM customers.customers
GROUP BY DATE_TRUNC('month', registration_date)
ORDER BY reg_month;

/* Q66. */
SELECT session_id, COUNT(*) AS path_length
FROM web_events.page_views
GROUP BY session_id
ORDER BY path_length DESC
LIMIT 20;

/* Q67. */
SELECT w.warehouse_id, w.name, COUNT(DISTINCT isn.product_id) AS product_count
FROM supply_chain.warehouses w
LEFT JOIN supply_chain.inventory_snapshots isn ON isn.warehouse_id = w.warehouse_id
GROUP BY w.warehouse_id, w.name;

/* Q68. */
SELECT sup.supplier_id, sup.supplier_name, COUNT(*) AS shipment_count
FROM products.suppliers sup
LEFT JOIN supply_chain.shipments sh ON sh.supplier_id = sup.supplier_id
GROUP BY sup.supplier_id, sup.supplier_name;

/* Q69. */
SELECT role, store_id, COUNT(*) AS headcount
FROM stores.employees
GROUP BY role, store_id;

/* Q70. Co-purchase self-join restricted to a single sample customer to bound the pair explosion. */
SELECT DISTINCT o2.cust_id AS co_purchaser
FROM sales.orders o1
JOIN sales.order_items oi1 ON oi1.order_id = o1.order_id
JOIN sales.order_items oi2 ON oi2.prod_id = oi1.prod_id
JOIN sales.orders o2 ON o2.order_id = oi2.order_id AND o2.cust_id <> o1.cust_id
WHERE o1.cust_id = 1
LIMIT 200;

/* Q71. */
SELECT cust_id, order_id, net_total,
       RANK() OVER (PARTITION BY cust_id ORDER BY net_total DESC) AS value_rank_within_customer
FROM sales.orders
WHERE cust_id <= 500
ORDER BY cust_id, value_rank_within_customer;

/* Q72. */
SELECT email, COUNT(*) AS occurrences
FROM customers.customers
GROUP BY email
HAVING COUNT(*) >= 2;

/* Q73. */
SELECT subject, COUNT(*) AS occurrences
FROM support.tickets
GROUP BY subject
HAVING COUNT(*) >= 2
LIMIT 200;

/* Q74. */
SELECT product_id, warehouse_id, snapshot_date, quantity_on_hand,
       MAX(quantity_on_hand) OVER (PARTITION BY product_id, snapshot_date) - MIN(quantity_on_hand) OVER (PARTITION BY product_id, snapshot_date) AS spread
FROM supply_chain.inventory_snapshots
WHERE snapshot_date = (SELECT MAX(snapshot_date) FROM supply_chain.inventory_snapshots)
ORDER BY spread DESC
LIMIT 50;

/* Q75. */
SELECT o1.order_id AS order1, o2.order_id AS order2, o1.cust_id, o1.net_total, o1.order_date
FROM sales.orders o1
JOIN sales.orders o2
  ON o1.cust_id = o2.cust_id AND o1.net_total = o2.net_total
 AND o1.order_date = o2.order_date AND o1.order_id < o2.order_id
LIMIT 200;

/* ============================================================
   SECTION D: SET OPS + RECONCILIATION (25)
   ------------------------------------------------------------ */
/* Q76. */
SELECT o.cust_id, c.customer_id
FROM sales.orders o
FULL OUTER JOIN customers.customers c ON o.cust_id = c.customer_id
WHERE o.cust_id IS NULL OR c.customer_id IS NULL
LIMIT 200;

/* Q77. */
SELECT DISTINCT product_id FROM products.inventory
EXCEPT
SELECT DISTINCT prod_id FROM sales.order_items;

/* Q78. */
SELECT cust_id AS customer_id, order_id::text AS ref_id, 'order' AS source FROM sales.orders
UNION ALL
SELECT customer_id, ticket_id::text, 'ticket' FROM support.tickets
UNION ALL
SELECT customer_id, review_id::text, 'review' FROM customers.reviews
UNION ALL
SELECT customer_id, call_id::text, 'call' FROM call_center.calls;

/* Q79. High-spend = top-quartile lifetime spend; active-reviewer = 2+ reviews. */
WITH spend AS (SELECT cust_id, SUM(net_total) AS total_spend FROM sales.orders GROUP BY cust_id),
threshold AS (SELECT PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total_spend) AS p75 FROM spend)
SELECT cust_id FROM spend, threshold WHERE total_spend >= p75
INTERSECT
SELECT customer_id FROM customers.reviews GROUP BY customer_id HAVING COUNT(*) >= 2;

/* Q80. */
SELECT cust_id AS customer_id FROM sales.orders
EXCEPT
SELECT customer_id FROM customers.reviews;

/* Q81. Churn definitions: (a) no order in 90 days, (b) tier never upgraded, (c) closed all support interactions with negative sentiment - combined via UNION ALL with a label for each definition. */
WITH ref AS (SELECT MAX(order_date) AS today FROM sales.orders)
SELECT cust_id AS customer_id, 'no_recent_order' AS churn_definition
FROM sales.orders, ref GROUP BY cust_id HAVING MAX(order_date) < MAX(ref.today) - 90
UNION ALL
SELECT customer_id, 'never_upgraded_tier'
FROM customers.customers WHERE tier = 'Bronze' AND registration_date < (SELECT today FROM ref) - 365;

/* Q82. */
SELECT r.region_name, SUM(o.net_total) AS revenue
FROM sales.orders o JOIN stores.stores s ON o.store_id = s.store_id JOIN core.dim_region r ON s.region_id = r.region_id
GROUP BY r.region_name
UNION ALL
SELECT 'GRAND TOTAL', SUM(net_total) FROM sales.orders;

/* Q83. */
SELECT DISTINCT cust_id FROM sales.orders WHERE order_status = 'Delivered'
INTERSECT
SELECT DISTINCT cust_id FROM sales.orders WHERE EXTRACT(YEAR FROM order_date) = 2025;

/* Q84. */
SELECT cust_id FROM sales.orders WHERE cust_id = 1
EXCEPT ALL
SELECT cust_id FROM sales.orders WHERE cust_id = 2;

/* Q85. */
WITH report_a AS (SELECT order_status, COUNT(*) AS cnt FROM sales.orders WHERE order_date < '2025-06-01' GROUP BY order_status),
report_b AS (SELECT order_status, COUNT(*) AS cnt FROM sales.orders WHERE order_date >= '2025-06-01' GROUP BY order_status)
SELECT COALESCE(a.order_status, b.order_status) AS order_status, a.cnt AS before_count, b.cnt AS after_count
FROM report_a a FULL OUTER JOIN report_b b ON a.order_status = b.order_status;

/* Q86. */
SELECT
  CASE WHEN o.cust_id IS NOT NULL AND r.customer_id IS NOT NULL THEN 'both'
       WHEN o.cust_id IS NOT NULL THEN 'only_orders'
       WHEN r.customer_id IS NOT NULL THEN 'only_reviews'
       ELSE 'neither' END AS bucket,
  COUNT(*) AS customer_count
FROM customers.customers c
LEFT JOIN (SELECT DISTINCT cust_id FROM sales.orders) o ON o.cust_id = c.customer_id
LEFT JOIN (SELECT DISTINCT customer_id FROM customers.reviews) r ON r.customer_id = c.customer_id
GROUP BY bucket;

/* Q87. */
SELECT DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS amount, 'revenue' AS metric FROM sales.orders GROUP BY DATE_TRUNC('month', order_date)
UNION ALL
SELECT DATE_TRUNC('month', spend_date), SUM(amount), 'ad_cost' FROM marketing.ads_spend GROUP BY DATE_TRUNC('month', spend_date)
ORDER BY month, metric;

/* Q88. */
SELECT order_status, revenue, DENSE_RANK() OVER (ORDER BY revenue DESC) AS revenue_rank
FROM (
  SELECT order_status, SUM(net_total) AS revenue FROM sales.orders GROUP BY order_status
) x;

/* Q89. */
SELECT DISTINCT cust_id FROM sales.orders WHERE EXTRACT(YEAR FROM order_date) = 2025
EXCEPT
SELECT DISTINCT cust_id FROM sales.orders WHERE EXTRACT(YEAR FROM order_date) = 2024;

/* Q90. */
SELECT DISTINCT cust_id FROM sales.orders
INTERSECT
SELECT DISTINCT cust_id FROM finance.payments;

/* Q91. */
SELECT customer_id FROM customers.customers
EXCEPT
SELECT DISTINCT cust_id FROM sales.orders WHERE cust_id IS NOT NULL;

/* Q92. */
SELECT tier,
  COUNT(*) FILTER (WHERE tier = 'Bronze')   AS bronze,
  COUNT(*) FILTER (WHERE tier = 'Silver')   AS silver,
  COUNT(*) FILTER (WHERE tier = 'Gold')     AS gold,
  COUNT(*) FILTER (WHERE tier = 'Platinum') AS platinum
FROM customers.customers
GROUP BY tier;

/* Q93. */
SELECT order_item_id, 'gross_amount' AS metric, gross_amount AS value FROM sales.order_items WHERE order_item_id <= 100
UNION ALL
SELECT order_item_id, 'discount_amount', discount_amount FROM sales.order_items WHERE order_item_id <= 100
UNION ALL
SELECT order_item_id, 'net_amount', net_amount FROM sales.order_items WHERE order_item_id <= 100
ORDER BY order_item_id, metric;

/* Q94. */
SELECT DISTINCT cust_id FROM sales.orders WHERE store_id = 1
INTERSECT
SELECT DISTINCT cust_id FROM sales.orders WHERE store_id = 2;

/* Q95. */
SELECT DISTINCT cust_id FROM sales.orders
INTERSECT
SELECT DISTINCT customer_id FROM customers.reviews
INTERSECT
SELECT DISTINCT customer_id FROM support.tickets;

/* Q96. */
SELECT campaign_id FROM marketing.campaigns WHERE start_date >= (SELECT MAX(start_date) FROM marketing.campaigns) - 30
EXCEPT
SELECT campaign_id FROM marketing.campaigns WHERE start_date < (SELECT MAX(start_date) FROM marketing.campaigns) - 30;

/* Q97. */
SELECT customer_id FROM customers.customers WHERE customer_id <= 100
EXCEPT
SELECT DISTINCT cust_id FROM sales.orders WHERE cust_id <= 100;

/* Q98. */
SELECT DISTINCT product_id FROM products.inventory
EXCEPT
SELECT DISTINCT prod_id FROM sales.order_items;

/* Q99. */
SELECT c.customer_id, src.source, src.ref_id
FROM customers.customers c
CROSS JOIN LATERAL (
  (SELECT 'order' AS source, order_id AS ref_id FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY o.order_date DESC LIMIT 1)
  UNION ALL
  (SELECT 'review', review_id FROM customers.reviews r WHERE r.customer_id = c.customer_id ORDER BY r.review_date DESC LIMIT 1)
  UNION ALL
  (SELECT 'ticket', ticket_id FROM support.tickets t WHERE t.customer_id = c.customer_id ORDER BY t.created_date DESC LIMIT 1)
  UNION ALL
  (SELECT 'call', call_id FROM call_center.calls cl WHERE cl.customer_id = c.customer_id ORDER BY cl.call_start_time DESC LIMIT 1)
) src
WHERE c.customer_id <= 50;

/* Q100. */
SELECT customer_id, 'order' AS source, order_date::timestamp AS event_time FROM sales.orders o JOIN customers.customers c ON o.cust_id = c.customer_id WHERE c.customer_id <= 200
UNION ALL
SELECT customer_id, 'review', review_date::timestamp FROM customers.reviews WHERE customer_id <= 200
UNION ALL
SELECT customer_id, 'ticket', created_date FROM support.tickets WHERE customer_id <= 200
UNION ALL
SELECT customer_id, 'call', call_start_time FROM call_center.calls WHERE customer_id <= 200
ORDER BY customer_id, event_time;

/* ============================================================
   END OF ANSWER KEY - JOINs Part 2 (Advanced) - HARD LEVEL (100/100)
============================================================ */
