/* ============================================================
   ANSWER KEY - JOINs Part 1 (Foundations) (HARD LEVEL)
   Curriculum:   RetailMart V3
   Note: this database intentionally has NO indexes on foreign-key
   columns (only primary keys), so per-row correlated subqueries /
   LATERAL joins over large driving tables (customers, orders,
   order_items, page_views) are restricted to a bounded sample where
   noted - the same query runs correctly, just slower, unrestricted.
   ============================================================ */

/* ============================================================
   SECTION A: JOINs - CONCEPTUAL DEEP (25)
   ------------------------------------------------------------ */
/* Q1.  Hash Join when one side is much smaller (built into an in-memory hash table) with no useful sort order; Merge Join when both sides are already sorted (or cheaply sortable) on the join key; Nested Loop when one side is tiny or an index lets it probe cheaply per outer row. */
/* Q2.  Because ORDER BY on the join key can let the planner reuse an existing sort (or feed a sorted scan) instead of building a hash table, making a Merge Join of two pre-sorted inputs look cheaper in the cost estimate. */
/* Q3.  The planner hashes the SMALLER (or cheaper-to-build) side into memory (the "build" side) and then streams the larger side row-by-row, probing the hash table (the "probe" side) for matches. */
/* Q4.  A "broadcast join" sends a full copy of the smaller table to every worker node in a distributed system (common in Spark/BigQuery); PostgreSQL is single-node by default so it doesn't broadcast across nodes, though parallel workers do share a similar hashed-build-side idea within one machine. */
/* Q5.  In modern engines they produce the identical query plan - PostgreSQL's planner rewrites CROSS JOIN + WHERE a.x=b.y into the same join plan as INNER JOIN ON a.x=b.y, so there's no inherent speed difference; INNER JOIN is just clearer intent. */
/* Q6.  Because a composite index on (x, z) lets PostgreSQL satisfy BOTH conditions from a single index lookup instead of scanning/filtering on one column then re-checking the other - fewer index entries touched, fewer heap fetches. */
/* Q7.  Example: joining marketing.campaigns to sales.orders ON o.order_date BETWEEN c.start_date AND c.end_date - matches an order to every campaign that was actively running on its order date. */
/* Q8.  A GiST index (e.g. on a tsrange/daterange column, or a range type built from two date columns) supports efficient range-overlap lookups; without it, range joins fall back to nested-loop scans comparing every row pair. */
/* Q9.  They express the identical idea - "for each outer row, run this subquery using its columns" - LATERAL is just the JOIN-clause syntax for the same correlated-subquery logic, letting it return multiple columns/rows naturally. */
/* Q10. LEFT JOIN b ON ... WHERE b.key IS NULL keeps outer rows with no match; NOT EXISTS (SELECT 1 FROM b WHERE ...) checks existence directly without joining columns; EXCEPT subtracts one whole result set from another - all three find "rows in A missing from B" but with different readability/performance trade-offs. */
/* Q11. PostgreSQL converts EXISTS (SELECT ... WHERE b.key = a.key) into a semi-join plan when it can prove the subquery only needs to know IF a match exists (not which/how many) - it stops probing after the first match per outer row. */
/* Q12. Fan-out multiplies each outer row once per matching inner row, so any aggregate computed AFTER that join (like SUM on outer-only data) gets inflated - a customer's stated "total spend" repeated once per order_item row, then summed again, double/triple-counts it. */
/* Q13. Compare COUNT(*) of the raw join result to COUNT(DISTINCT outer.key) - if COUNT(*) is much larger, the join fanned out (the right side matched multiple rows per left row). */
/* Q14. Because after a fan-out join, SUM(outer_amount) adds the SAME outer_amount once per matching inner row instead of once per outer entity, inflating the total - the fix is to pre-aggregate the inner side before joining. */
/* Q15. INNER JOINs are associative/commutative, so reordering them never changes the RESULT (only possibly the plan/performance); OUTER JOINs are NOT associative in general, so reordering LEFT/RIGHT/FULL joins can change which rows end up with NULLs. */
/* Q16. join_collapse_limit controls how many explicit JOINs the planner will consider reordering (exploring different join orders) versus taking the written order as-is - past that limit it uses a cheaper heuristic search instead of exhaustive optimization. */
/* Q17. It's when the planner's row-count estimate for an intermediate result is far off from reality (often due to stale statistics or correlated columns); bad estimates lead it to pick the wrong join strategy (e.g. Nested Loop expecting 10 rows that turns out to be 10 million), tanking performance. */
/* Q18. A triangle inequality join (a.x + b.y > c.z) has no equality component at all, so PostgreSQL can't hash or index it efficiently - it typically falls back to a full Nested Loop evaluating the inequality for every combination of rows. */
/* Q19. Because the "fan-out" from the first table to the bridge, and the reverse "fan-in" collapsing rows back per entity on the far side, both happen at once - loyalty.redemptions bridging customers to rewards is one example. */
/* Q20. They are logically equivalent (both require x1=x2 AND y1=y2), but the row-value syntax (a.x,a.y)=(b.x,b.y) is more compact; the planner treats them the same for optimization purposes in modern PostgreSQL. */
/* Q21. Standard SQL evaluates the ON clause's qualifying condition (on the non-preserved side) DURING the join, so unmatched preserved-side rows still appear with NULLs; a WHERE-clause filter runs AFTER the join and removes rows outright, including legitimate outer-join NULL rows. */
/* Q22. Join reordering is the planner trying different orders of executing a chain of JOINs (up to join_collapse_limit) and picking whichever order has the lowest estimated total cost, based on row-count/selectivity statistics for each possible intermediate join. */
/* Q23. Because an index on the join column on ONE side only speeds up looking that side up; if BOTH sides are large, indexing both lets the planner choose a Merge Join (both sorted via index) or an efficient Nested Loop with Index Scan from either direction, whichever is cheaper. */
/* Q24. It's equivalent for producing matched rows (the same INNER JOIN result), but comma-syntax offers no way to express LEFT/RIGHT/FULL OUTER semantics - there is no comma-syntax "keep unmatched rows" option, so it's INNER-only by construction. */
/* Q25. PostgreSQL internally treats FROM a, b WHERE a.x=b.y as an implicit CROSS JOIN followed by a WHERE filter, then the planner rewrites/optimizes it into the same join plan an explicit INNER JOIN ON a.x=b.y would produce. */

/* ============================================================
   SECTION B: NON-EQUI / MULTI-COL JOINS (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT c.campaign_name, COUNT(*) AS orders_during_campaign, SUM(o.net_total) AS revenue_during_campaign
FROM sales.orders o
JOIN marketing.campaigns c ON o.order_date BETWEEN c.start_date AND c.end_date
GROUP BY c.campaign_name
ORDER BY revenue_during_campaign DESC;

/* Q27. */
SELECT pr.promo_name, COUNT(*) AS orders_during_promo, SUM(o.net_total) AS revenue_during_promo
FROM sales.orders o
JOIN products.promotions pr ON o.order_date BETWEEN pr.start_date AND pr.end_date
GROUP BY pr.promo_name
ORDER BY revenue_during_promo DESC;

/* Q28. */
SELECT c.campaign_name, COUNT(*) AS page_views_during_campaign
FROM web_events.page_views pv
JOIN marketing.campaigns c ON pv.view_timestamp::date BETWEEN c.start_date AND c.end_date
GROUP BY c.campaign_name
ORDER BY page_views_during_campaign DESC;

/* Q29. */
SELECT ps.pay_slip_id, ps.employee_id, ps.gross_salary, tb.tax_rate
FROM payroll.pay_slips ps
JOIN payroll.tax_brackets tb ON ps.gross_salary BETWEEN tb.min_salary AND tb.max_salary;

/* Q30. */
SELECT e.employee_id, e.salary, tb.tax_rate
FROM stores.employees e
JOIN payroll.tax_brackets tb ON e.salary BETWEEN tb.min_salary AND tb.max_salary;

/* Q31. */
SELECT oi.order_item_id, o.store_id, oi.prod_id, i.quantity_on_hand
FROM sales.order_items oi
JOIN sales.orders o ON oi.order_id = o.order_id
JOIN products.inventory i ON i.store_id = o.store_id AND i.product_id = oi.prod_id;

/* Q32. */
SELECT ps.pay_slip_id, ps.employee_id, a.attendance_id
FROM payroll.pay_slips ps
JOIN hr.attendance a
  ON a.employee_id = ps.employee_id
 AND EXTRACT(YEAR FROM a.attendance_date) = ps.salary_year;

/* Q33. */
SELECT isn.warehouse_id, isn.product_id, isn.snapshot_date, sh.shipment_id
FROM supply_chain.inventory_snapshots isn
JOIN supply_chain.shipments sh
  ON sh.warehouse_id = isn.warehouse_id
 AND sh.product_id = isn.product_id
 AND sh.shipped_date = isn.snapshot_date;

/* Q34. */
SELECT oi.order_item_id, r.return_id
FROM sales.order_items oi
JOIN sales.returns r ON r.order_id = oi.order_id AND r.prod_id = oi.prod_id;

/* Q35. */
SELECT o.order_id, a.city AS default_address_city
FROM sales.orders o
JOIN customers.addresses a ON a.customer_id = o.cust_id AND a.is_default = TRUE;

/* Q36. */
SELECT oi.order_item_id, oi.unit_price, p.price AS list_price
FROM sales.order_items oi
JOIN products.products p ON oi.prod_id = p.product_id AND oi.unit_price > p.price;

/* Q37. Bundle pricing (products whose two cheaper prices exceed the third) restricted to one brand to keep the 3-way self-join tractable - a full unrestricted cross-brand 6,036^3 self-join is combinatorially prohibitive. */
SELECT p1.product_name AS product_a, p2.product_name AS product_b, p3.product_name AS product_c,
       p1.price, p2.price, p3.price
FROM products.products p1
JOIN products.products p2 ON p2.brand_id = p1.brand_id AND p2.product_id > p1.product_id
JOIN products.products p3 ON p3.brand_id = p1.brand_id AND p3.product_id > p2.product_id
WHERE p1.brand_id = 1
  AND p1.price + p2.price > p3.price;

/* Q38. */
SELECT o.order_id, c.campaign_name
FROM sales.orders o
JOIN marketing.campaigns c
  ON o.order_date BETWEEN c.start_date AND c.start_date + 7
LIMIT 200;

/* Q39. */
SELECT o.order_id, a.city AS customer_city, s.city AS store_city
FROM sales.orders o
JOIN customers.addresses a ON a.customer_id = o.cust_id AND a.is_default = TRUE
JOIN stores.stores s ON o.store_id = s.store_id
WHERE a.city = s.city;

/* Q40. */
WITH clean_addresses AS (
  SELECT customer_id, TRIM(LOWER(city)) AS clean_city
  FROM customers.addresses
  WHERE is_default = TRUE
)
SELECT o.order_id, ca.clean_city
FROM sales.orders o
JOIN clean_addresses ca ON ca.customer_id = o.cust_id;

/* Q41. */
SELECT o1.order_id AS this_order, o1.order_date AS this_date,
       o2.order_id AS next_order, o2.order_date AS next_date
FROM sales.orders o1
JOIN sales.orders o2
  ON o2.cust_id = o1.cust_id
 AND o2.order_date > o1.order_date
WHERE NOT EXISTS (
  SELECT 1 FROM sales.orders o3
  WHERE o3.cust_id = o1.cust_id AND o3.order_date > o1.order_date AND o3.order_date < o2.order_date
);

/* Q42. */
SELECT o.order_id, sh.shipment_id, sh.status
FROM sales.orders o
JOIN sales.shipments sh ON sh.order_id = o.order_id AND sh.status = 'Delivered';

/* Q43. */
SELECT o.order_id, lm.tier_id
FROM sales.orders o
JOIN loyalty.members lm ON lm.customer_id = o.cust_id;

/* Q44. */
SELECT DATE_TRUNC('month', o.order_date) AS order_month, DATE_TRUNC('month', c.spend_date) AS spend_month,
       o.order_id, c.spend_id
FROM sales.orders o
JOIN marketing.ads_spend c ON DATE_TRUNC('month', o.order_date) = DATE_TRUNC('month', c.spend_date)
LIMIT 200;

/* Q45. */
WITH seasons(season, start_month, end_month) AS (
  VALUES ('Winter', 12, 2), ('Spring', 3, 5), ('Summer', 6, 8), ('Autumn', 9, 11)
)
SELECT o.order_id, s.season
FROM sales.orders o
JOIN seasons s
  ON (s.start_month <= s.end_month AND EXTRACT(MONTH FROM o.order_date) BETWEEN s.start_month AND s.end_month)
  OR (s.start_month > s.end_month AND (EXTRACT(MONTH FROM o.order_date) >= s.start_month OR EXTRACT(MONTH FROM o.order_date) <= s.end_month))
LIMIT 200;

/* Q46. Restricted to a bounded order_id range - a full self-join on a derived prefix key over all 150,000 orders would produce an extremely large number of matching pairs. */
SELECT a.order_id AS order_a, b.order_id AS order_b, LEFT(a.order_id::text, 4) AS shared_prefix
FROM sales.orders a
JOIN sales.orders b
  ON LEFT(a.order_id::text, 4) = LEFT(b.order_id::text, 4)
 AND a.order_id < b.order_id
WHERE a.order_id BETWEEN 100000 AND 100999
LIMIT 200;

/* Q47. */
SELECT p1.product_name AS product_a, p2.product_name AS product_b
FROM products.products p1
JOIN products.products p2
  ON LEFT(p1.product_name, 3) = LEFT(p2.product_name, 3)
 AND p1.product_id < p2.product_id
LIMIT 200;

/* Q48. */
SELECT p1.product_name AS product_a, p2.product_name AS product_b, p1.brand_id
FROM products.products p1
JOIN products.products p2 ON p1.brand_id = p2.brand_id AND p1.product_id < p2.product_id
LIMIT 200;

/* Q49. */
SELECT p.product_name, b.brand_name, cat.category_name
FROM products.products p
JOIN core.dim_brand b ON p.brand_id = b.brand_id
JOIN core.dim_category cat ON b.category_id = cat.category_id;

/* Q50. */
SELECT r.review_id, p.product_name, c.first_name AS reviewer_name, r.rating
FROM customers.reviews r
JOIN products.products p ON r.product_id = p.product_id
JOIN customers.customers c ON r.customer_id = c.customer_id;

/* ============================================================
   SECTION C: ANTI-JOIN & SEMI-JOIN PATTERNS (25)
   ------------------------------------------------------------ */
/* Q51. */
SELECT c.customer_id
FROM customers.customers c
LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
WHERE o.order_id IS NULL;
-- equivalent (NOT EXISTS):
-- SELECT c.customer_id FROM customers.customers c
-- WHERE NOT EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id);
-- equivalent (EXCEPT):
-- SELECT customer_id FROM customers.customers EXCEPT SELECT cust_id FROM sales.orders WHERE cust_id IS NOT NULL;

/* Q52. */
SELECT p.product_id
FROM products.products p
WHERE NOT EXISTS (SELECT 1 FROM customers.reviews r WHERE r.product_id = p.product_id);

/* Q53. */
SELECT e.employee_id
FROM stores.employees e
WHERE NOT EXISTS (SELECT 1 FROM support.tickets t WHERE t.agent_id = e.employee_id);

/* Q54. */
SELECT DISTINCT c.customer_id
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
WHERE NOT EXISTS (SELECT 1 FROM loyalty.members m WHERE m.customer_id = c.customer_id);

/* Q55. */
SELECT o.order_id
FROM sales.orders o
WHERE NOT EXISTS (SELECT 1 FROM sales.shipments sh WHERE sh.order_id = o.order_id);

/* Q56. */
SELECT a.spend_id
FROM marketing.ads_spend a
WHERE NOT EXISTS (SELECT 1 FROM marketing.campaigns c WHERE c.campaign_id = a.campaign_id);

/* Q57. */
SELECT isn.warehouse_id, isn.product_id
FROM supply_chain.inventory_snapshots isn
WHERE NOT EXISTS (SELECT 1 FROM products.products p WHERE p.product_id = isn.product_id);

/* Q58. */
SELECT ps.pay_slip_id, ps.employee_id
FROM payroll.pay_slips ps
WHERE NOT EXISTS (SELECT 1 FROM stores.employees e WHERE e.employee_id = ps.employee_id);

/* Q59. */
SELECT t.ticket_id
FROM support.tickets t
WHERE NOT EXISTS (SELECT 1 FROM customers.customers c WHERE c.customer_id = t.customer_id);

/* Q60. */
SELECT w.warehouse_id
FROM supply_chain.warehouses w
WHERE NOT EXISTS (
  SELECT 1 FROM supply_chain.shipments sh
  WHERE sh.warehouse_id = w.warehouse_id
    AND sh.shipped_date >= (SELECT MAX(shipped_date) FROM supply_chain.shipments) - 90
);

/* Q61. */
SELECT DISTINCT c.customer_id
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
JOIN sales.order_items oi ON oi.order_id = o.order_id
WHERE NOT EXISTS (
  SELECT 1 FROM customers.reviews r WHERE r.customer_id = c.customer_id AND r.product_id = oi.prod_id
);

/* Q62. */
SELECT c.customer_id
FROM customers.customers c
WHERE EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id);

/* Q63. */
SELECT p.product_id
FROM products.products p
WHERE EXISTS (SELECT 1 FROM customers.reviews r WHERE r.product_id = p.product_id);

/* Q64. */
SELECT s.store_id
FROM stores.stores s
WHERE EXISTS (SELECT 1 FROM stores.employees e WHERE e.store_id = s.store_id)
  AND EXISTS (SELECT 1 FROM sales.orders o WHERE o.store_id = s.store_id)
  AND EXISTS (SELECT 1 FROM products.inventory i WHERE i.store_id = s.store_id);

/* Q65. */
SELECT e.employee_id
FROM stores.employees e
WHERE EXISTS (SELECT 1 FROM support.tickets t WHERE t.agent_id = e.employee_id)
  AND EXISTS (SELECT 1 FROM call_center.calls cl WHERE cl.agent_id = e.employee_id);

/* Q66. */
SELECT oi.prod_id
FROM sales.order_items oi
JOIN sales.orders o ON oi.order_id = o.order_id
JOIN stores.stores s ON o.store_id = s.store_id
GROUP BY oi.prod_id
HAVING COUNT(DISTINCT s.region_id) > 1;

/* Q67. */
SELECT DISTINCT ro.cust_id
FROM sales.returns r
JOIN sales.orders ro ON r.order_id = ro.order_id
WHERE NOT EXISTS (
  SELECT 1 FROM sales.orders o2
  WHERE o2.cust_id = ro.cust_id AND o2.order_date > r.return_date
);

/* Q68. */
SELECT sh.supplier_id
FROM supply_chain.shipments sh
GROUP BY sh.supplier_id
HAVING COUNT(DISTINCT sh.warehouse_id) = (SELECT COUNT(*) FROM supply_chain.warehouses);

/* Q69. */
SELECT b.brand_id, b.brand_name
FROM core.dim_brand b
WHERE NOT EXISTS (
  SELECT 1 FROM core.dim_region r
  WHERE NOT EXISTS (
    SELECT 1
    FROM sales.order_items oi
    JOIN products.products p ON oi.prod_id = p.product_id
    JOIN sales.orders o ON oi.order_id = o.order_id
    JOIN stores.stores s ON o.store_id = s.store_id
    WHERE p.brand_id = b.brand_id AND s.region_id = r.region_id
  )
);

/* Q70. */
SELECT cust_id
FROM sales.orders
WHERE EXTRACT(YEAR FROM order_date) = 2024
INTERSECT
SELECT cust_id
FROM sales.orders
WHERE EXTRACT(YEAR FROM order_date) = 2025;

/* Q71. */
SELECT i.product_id
FROM products.inventory i
WHERE NOT EXISTS (SELECT 1 FROM sales.order_items oi WHERE oi.prod_id = i.product_id);

/* Q72. */
SELECT ps.pay_slip_id, ps.employee_id, ps.salary_year
FROM payroll.pay_slips ps
WHERE NOT EXISTS (
  SELECT 1 FROM hr.attendance a
  WHERE a.employee_id = ps.employee_id AND EXTRACT(YEAR FROM a.attendance_date) = ps.salary_year
);

/* Q73. */
SELECT c.campaign_id
FROM marketing.campaigns c
WHERE NOT EXISTS (SELECT 1 FROM marketing.ads_spend a WHERE a.campaign_id = c.campaign_id);

/* Q74. */
SELECT e.employee_id
FROM stores.employees e
WHERE NOT EXISTS (
  SELECT 1 FROM call_center.calls cl
  WHERE cl.agent_id = e.employee_id
    AND cl.call_start_time >= (SELECT MAX(call_start_time) FROM call_center.calls) - INTERVAL '30 days'
);

/* Q75. */
SELECT sh.shipment_id
FROM sales.shipments sh
WHERE NOT EXISTS (SELECT 1 FROM sales.orders o WHERE o.order_id = sh.order_id);

/* ============================================================
   SECTION D: MULTI-TABLE CHAINS (3+ TABLES)
   ------------------------------------------------------------ */
/* Q76. */
SELECT o.order_id, oi.order_item_id, p.product_name, b.brand_name, cat.category_name, sup.supplier_name
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
JOIN products.products p ON oi.prod_id = p.product_id
JOIN core.dim_brand b ON p.brand_id = b.brand_id
JOIN core.dim_category cat ON b.category_id = cat.category_id
JOIN products.suppliers sup ON p.supplier_id = sup.supplier_id;

/* Q77. */
SELECT c.customer_id, o.order_id, oi.order_item_id, p.product_name, r.rating
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
JOIN sales.order_items oi ON oi.order_id = o.order_id
JOIN products.products p ON oi.prod_id = p.product_id
LEFT JOIN customers.reviews r ON r.customer_id = c.customer_id AND r.product_id = p.product_id;

/* Q78. */
SELECT e.employee_id, ps.pay_slip_id, d.dept_name, s.store_name
FROM stores.employees e
JOIN payroll.pay_slips ps ON ps.employee_id = e.employee_id
JOIN core.dim_department d ON e.dept_id = d.dept_id
JOIN stores.stores s ON e.store_id = s.store_id;

/* Q79. */
SELECT c.campaign_name, a.amount AS spend, ec.emails_sent, ec.emails_clicked
FROM marketing.campaigns c
LEFT JOIN marketing.ads_spend a ON a.campaign_id = c.campaign_id
LEFT JOIN marketing.email_clicks ec ON ec.campaign_id = c.campaign_id;

/* Q80. */
SELECT isn.warehouse_id, w.name AS warehouse_name, p.product_name, sup.supplier_name, sh.shipment_id
FROM supply_chain.inventory_snapshots isn
JOIN supply_chain.warehouses w ON isn.warehouse_id = w.warehouse_id
JOIN products.products p ON isn.product_id = p.product_id
JOIN products.suppliers sup ON p.supplier_id = sup.supplier_id
LEFT JOIN supply_chain.shipments sh ON sh.warehouse_id = isn.warehouse_id AND sh.product_id = isn.product_id;

/* Q81. */
SELECT t.ticket_id, c.first_name AS customer_name, e.first_name AS agent_name
FROM support.tickets t
JOIN customers.customers c ON t.customer_id = c.customer_id
LEFT JOIN stores.employees e ON t.agent_id = e.employee_id;

/* Q82. */
SELECT
  (SELECT COUNT(*) FROM sales.orders o JOIN sales.order_items oi ON oi.order_id = o.order_id) AS joined_row_count,
  (SELECT COUNT(*) FROM sales.orders) AS distinct_order_count;

/* Q83. */
WITH order_totals AS (
  SELECT order_id, SUM(net_amount) AS items_total, COUNT(*) AS item_count
  FROM sales.order_items GROUP BY order_id
)
SELECT o.order_id, o.net_total, ot.items_total, ot.item_count
FROM sales.orders o
JOIN order_totals ot ON ot.order_id = o.order_id;

/* Q84. */
SELECT COUNT(DISTINCT o.cust_id) AS distinct_customers_with_multi_unit_lines
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
WHERE oi.quantity > 1;

/* Q85. */
SELECT c.customer_id, COUNT(*) AS line_items
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
JOIN sales.order_items oi ON oi.order_id = o.order_id
JOIN products.products p ON oi.prod_id = p.product_id
JOIN core.dim_brand b ON p.brand_id = b.brand_id
GROUP BY c.customer_id;

/* Q86. */
SELECT o.order_id, COUNT(*) AS items_per_order
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id;

/* Q87. */
SELECT r.region_name, SUM(o.net_total) AS revenue
FROM core.dim_region r
JOIN stores.stores s ON s.region_id = r.region_id
JOIN sales.orders o ON o.store_id = s.store_id
GROUP BY r.region_name;

/* Q88. */
SELECT c.customer_id, SUM(o.net_total) AS lifetime_revenue
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY c.customer_id;

/* Q89. */
SELECT o.order_id, o.net_total, SUM(oi.net_amount) AS items_total
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id, o.net_total;

/* Q90. */
SELECT cat.category_name, COUNT(*) AS product_count
FROM core.dim_category cat
JOIN core.dim_brand b ON b.category_id = cat.category_id
JOIN products.products p ON p.brand_id = b.brand_id
GROUP BY cat.category_name;

/* Q91. */
SELECT c.customer_id
FROM customers.customers c
WHERE EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id);

/* Q92. */
SELECT c.customer_id, oc.order_count
FROM customers.customers c
LEFT JOIN (SELECT cust_id, COUNT(*) AS order_count FROM sales.orders GROUP BY cust_id) oc
  ON oc.cust_id = c.customer_id
WHERE oc.order_count > 0;

/* Q93. */
SELECT sup.supplier_id, COUNT(*) AS product_count
FROM products.suppliers sup
JOIN products.products p ON p.supplier_id = sup.supplier_id
GROUP BY sup.supplier_id;

/* Q94. */
WITH item_totals AS MATERIALIZED (
  SELECT order_id, SUM(net_amount) AS items_total
  FROM sales.order_items GROUP BY order_id
)
SELECT o.order_id, o.net_total, it.items_total
FROM sales.orders o
JOIN item_totals it ON it.order_id = o.order_id;

/* Q95. */
SELECT r.return_id, o.order_date, c.first_name AS customer_name
FROM sales.returns r
JOIN sales.orders o ON r.order_id = o.order_id
JOIN customers.customers c ON o.cust_id = c.customer_id;

/* Q96. */
SELECT cl.call_id, c.first_name AS customer_name, e.first_name AS agent_name
FROM call_center.calls cl
JOIN customers.customers c ON cl.customer_id = c.customer_id
JOIN stores.employees e ON cl.agent_id = e.employee_id;

/* Q97. */
SELECT pay.payment_id, o.order_id, c.first_name AS customer_name
FROM sales.payments pay
JOIN sales.orders o ON pay.order_id = o.order_id
JOIN customers.customers c ON o.cust_id = c.customer_id;

/* Q98. */
SELECT s.store_id, s.store_name, COUNT(*) AS order_count
FROM stores.stores s
JOIN sales.orders o ON o.store_id = s.store_id
WHERE o.order_date >= '2025-01-01'
GROUP BY s.store_id, s.store_name;

/* Q99. */
SELECT r.region_name, s.store_name, COUNT(*) AS order_count, SUM(o.net_total) AS revenue
FROM core.dim_region r
JOIN stores.stores s ON s.region_id = r.region_id
JOIN sales.orders o ON o.store_id = s.store_id
GROUP BY r.region_name, s.store_name
ORDER BY r.region_name, revenue DESC;

/* Q100. Restricted to a sample of customers, since correlated subqueries against unindexed FK columns don't scale to all 50,000 rows on this practice database. */
SELECT c.customer_id,
       (SELECT COUNT(*) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS order_count,
       (SELECT COUNT(*) FROM customers.reviews r WHERE r.customer_id = c.customer_id) AS review_count,
       (SELECT COUNT(*) FROM support.tickets t WHERE t.customer_id = c.customer_id) AS ticket_count,
       (SELECT COUNT(*) FROM call_center.calls cl WHERE cl.customer_id = c.customer_id) AS call_count
FROM customers.customers c
WHERE c.customer_id <= 200
ORDER BY c.customer_id;

/* ============================================================
   END OF ANSWER KEY - JOINs Part 1 (Foundations) - HARD LEVEL (100/100)
============================================================ */
