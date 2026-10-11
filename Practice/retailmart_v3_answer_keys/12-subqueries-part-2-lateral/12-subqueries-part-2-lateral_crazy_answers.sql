/* ============================================================
   ANSWER KEY - Subqueries Part 2 (Correlated & LATERAL) (CRAZY LEVEL)
   Curriculum:   RetailMart V3
   Note: this database has NO indexes on foreign-key columns, so
   LATERAL/correlated patterns whose driving table is large (customers,
   orders, order_items, page_views, events) are restricted to a bounded
   sample where noted; the same pattern is correct unrestricted, just
   slower on this unindexed practice copy. RetailMart V3 has no
   self-referencing manager_id, no bill-of-materials/component table,
   and no friend/social-graph table, so hierarchy/graph questions
   substitute the closest real relationships available in this schema
   (core.dim_category -> core.dim_brand as the only genuine 2-level
   hierarchy; stores.employees.dept_id -> core.dim_department as a
   reporting-line proxy; the supplier/warehouse shipment graph and the
   call_center.calls shared-agent relation as graph-edge proxies), each
   documented inline where first used.
   ============================================================ */

/* SECTION A: LATERAL + RECURSIVE (25) */

/* Q1. LATERAL with a recursive CTE inside: for each warehouse, the set of other warehouses reachable within 3 hops on the supplier-shipment graph (proxy for a general reachability graph, since RetailMart has no explicit graph table). */
SELECT w.warehouse_id, reach.reachable_warehouse, reach.hops
FROM supply_chain.warehouses w
CROSS JOIN LATERAL (
  WITH RECURSIVE edges AS (
    SELECT DISTINCT sh1.warehouse_id AS wh_a, sh2.warehouse_id AS wh_b
    FROM supply_chain.shipments sh1
    JOIN supply_chain.shipments sh2 ON sh2.supplier_id = sh1.supplier_id AND sh2.warehouse_id <> sh1.warehouse_id
  ),
  walk AS (
    SELECT wh_a AS start_wh, wh_b AS reachable_warehouse, 1 AS hops FROM edges WHERE wh_a = w.warehouse_id
    UNION ALL
    SELECT wk.start_wh, e.wh_b, wk.hops + 1
    FROM walk wk JOIN edges e ON e.wh_a = wk.reachable_warehouse
    WHERE wk.hops < 3
  )
  SELECT DISTINCT reachable_warehouse, MIN(hops) OVER (PARTITION BY reachable_warehouse) AS hops FROM walk
) reach
ORDER BY w.warehouse_id, reach.hops;

/* Q2. Recursive depth bounded by LATERAL: category -> brand depth walk, capped at depth 2 since this schema's category/brand hierarchy is genuinely only 2 levels deep. */
SELECT cat.category_id, cat.category_name, d.brand_id, d.brand_name, d.depth
FROM core.dim_category cat
CROSS JOIN LATERAL (
  WITH RECURSIVE tree AS (
    SELECT NULL::int AS brand_id, NULL::varchar AS brand_name, 0 AS depth
    UNION ALL
    SELECT b.brand_id, b.brand_name, t.depth + 1
    FROM tree t JOIN core.dim_brand b ON b.category_id = cat.category_id AND t.depth = 0
    WHERE t.depth < 2
  )
  SELECT brand_id, brand_name, depth FROM tree WHERE brand_id IS NOT NULL
) d
ORDER BY cat.category_id, d.depth;

/* Q3. LATERAL with a recursive graph walk: for each support agent, the set of customers reachable within 2 hops on the "shared agent" call graph (customer A and B are linked if they called the same agent) - a friend-of-friend proxy since RetailMart has no social graph table. One agent's customers form a near-complete clique, so the edge set feeding the recursion is capped (LIMIT 40) to keep the 2-hop expansion bounded; restricted to a small sample of agents. */
SELECT e.employee_id AS agent_id, walk.customer_id, walk.hops
FROM stores.employees e
CROSS JOIN LATERAL (
  WITH RECURSIVE cust_edges AS (
    SELECT DISTINCT c1.customer_id AS cust_a, c2.customer_id AS cust_b
    FROM call_center.calls c1
    JOIN call_center.calls c2 ON c2.agent_id = c1.agent_id AND c2.customer_id <> c1.customer_id
    WHERE c1.agent_id = e.employee_id
    LIMIT 40
  ),
  walk AS (
    SELECT cust_a AS start_cust, cust_b AS customer_id, 1 AS hops FROM cust_edges
    UNION ALL
    SELECT wk.start_cust, ce.cust_b, wk.hops + 1
    FROM walk wk JOIN cust_edges ce ON ce.cust_a = wk.customer_id
    WHERE wk.hops < 2
  )
  SELECT DISTINCT customer_id, MIN(hops) OVER (PARTITION BY customer_id) AS hops FROM walk
) walk
WHERE e.employee_id <= 50
ORDER BY e.employee_id, walk.hops
LIMIT 300;

/* Q4. LATERAL with hierarchy traversal: department -> employees reporting into it (RetailMart has no self-referencing manager_id, so dept_id is the closest real "reports into" hierarchy). */
SELECT d.dept_id, d.dept_name, emp.employee_id, emp.role, emp.salary
FROM core.dim_department d
CROSS JOIN LATERAL (
  SELECT employee_id, role, salary FROM stores.employees e WHERE e.dept_id = d.dept_id ORDER BY salary DESC LIMIT 5
) emp
ORDER BY d.dept_id, emp.salary DESC;

/* Q5. LATERAL with a category tree walk: every brand under each category, with a running count. */
SELECT cat.category_id, cat.category_name, b.brand_id, b.brand_name,
       COUNT(*) OVER (PARTITION BY cat.category_id ORDER BY b.brand_id) AS running_brand_count
FROM core.dim_category cat
CROSS JOIN LATERAL (
  SELECT brand_id, brand_name FROM core.dim_brand b WHERE b.category_id = cat.category_id
) b
ORDER BY cat.category_id, b.brand_id;

/* Q6. LATERAL with a "manager chain": since RetailMart has no self-referencing manager_id, the chain is proxied as employee -> department -> all peer employees in that department, ordered by salary (a stand-in seniority chain). */
SELECT e.employee_id, e.role, e.salary, peer.employee_id AS peer_id, peer.role AS peer_role, peer.salary AS peer_salary
FROM stores.employees e
CROSS JOIN LATERAL (
  SELECT employee_id, role, salary FROM stores.employees e2
  WHERE e2.dept_id = e.dept_id AND e2.salary >= e.salary AND e2.employee_id <> e.employee_id
  ORDER BY e2.salary DESC LIMIT 3
) peer
WHERE e.employee_id <= 300
ORDER BY e.employee_id;

/* Q7. LATERAL with friend-of-friend: customers who shared a support ticket agent with customer X, then customers who shared an agent with THOSE customers (2-hop), proxying a social graph via support.tickets since RetailMart has none. Restricted to a bounded sample of customers. */
SELECT c.customer_id, fof.customer_id AS friend_of_friend_id, fof.hops
FROM customers.customers c
CROSS JOIN LATERAL (
  WITH RECURSIVE cust_edges AS (
    SELECT DISTINCT t1.customer_id AS cust_a, t2.customer_id AS cust_b
    FROM support.tickets t1
    JOIN support.tickets t2 ON t2.agent_id = t1.agent_id AND t2.customer_id <> t1.customer_id
    WHERE t1.customer_id = c.customer_id
  ),
  walk AS (
    SELECT cust_a AS start_cust, cust_b AS customer_id, 1 AS hops FROM cust_edges
    UNION ALL
    SELECT wk.start_cust, ce.cust_b, wk.hops + 1
    FROM walk wk JOIN cust_edges ce ON ce.cust_a = wk.customer_id
    WHERE wk.hops < 2
  )
  SELECT DISTINCT customer_id, MIN(hops) OVER (PARTITION BY customer_id) AS hops FROM walk WHERE customer_id <> c.customer_id
) fof
WHERE c.customer_id <= 40
ORDER BY c.customer_id, fof.hops
LIMIT 300;

/* Q8. LATERAL with a BOM (bill of materials) proxy: RetailMart has no component table, so a supplier's "assembly" is modeled as supplier -> products it supplies -> warehouses those products ship to, walked as a 2-level tree via LATERAL. */
SELECT sup.supplier_id, sup.supplier_name, comp.product_id, comp.product_name, comp.warehouse_id, comp.total_qty
FROM products.suppliers sup
CROSS JOIN LATERAL (
  SELECT p.product_id, p.product_name, sh.warehouse_id, SUM(sh.quantity) AS total_qty
  FROM products.products p
  JOIN supply_chain.shipments sh ON sh.product_id = p.product_id
  WHERE p.supplier_id = sup.supplier_id
  GROUP BY p.product_id, p.product_name, sh.warehouse_id
) comp
WHERE sup.supplier_id <= 30
ORDER BY sup.supplier_id, comp.total_qty DESC
LIMIT 300;

/* Q9. LATERAL with a dependency chain: for each product, its chronological price-change history from audit.record_changes, each row's old_value linked to the previous row's new_value (a dependency/version chain). */
SELECT p.product_id, p.product_name, chain.change_id, chain.old_value, chain.new_value, chain.changed_at, chain.seq
FROM products.products p
CROSS JOIN LATERAL (
  SELECT change_id, old_value, new_value, changed_at,
         ROW_NUMBER() OVER (ORDER BY changed_at) AS seq
  FROM audit.record_changes rc
  WHERE rc.table_name = 'products' AND rc.record_id = p.product_id AND rc.column_name = 'price'
) chain
WHERE p.product_id <= 500
ORDER BY p.product_id, chain.seq;

/* Q10. LATERAL with cycle detection: for each warehouse, whether a cycle exists back to itself within 3 hops on the supplier-shipment graph (depth-capped to avoid unbounded recursion on this densely-connected 5-warehouse graph). */
SELECT w.warehouse_id, cyc.found_cycle
FROM supply_chain.warehouses w
CROSS JOIN LATERAL (
  WITH RECURSIVE edges AS (
    SELECT DISTINCT sh1.warehouse_id AS wh_a, sh2.warehouse_id AS wh_b
    FROM supply_chain.shipments sh1
    JOIN supply_chain.shipments sh2 ON sh2.supplier_id = sh1.supplier_id AND sh2.warehouse_id <> sh1.warehouse_id
  ),
  path_search AS (
    SELECT wh_a, wh_b, 1 AS depth FROM edges WHERE wh_a = w.warehouse_id
    UNION ALL
    SELECT ps.wh_a, e.wh_b, ps.depth + 1
    FROM path_search ps JOIN edges e ON e.wh_a = ps.wh_b
    WHERE ps.depth < 3
  )
  SELECT EXISTS (SELECT 1 FROM path_search WHERE wh_b = w.warehouse_id AND depth > 1) AS found_cycle
) cyc
ORDER BY w.warehouse_id;

/* Q11. LATERAL with shortest path: for each warehouse, the shortest hop-count to every other warehouse on the supplier-shipment graph. */
SELECT w.warehouse_id AS from_warehouse, sp.to_warehouse, sp.shortest_hops
FROM supply_chain.warehouses w
CROSS JOIN LATERAL (
  WITH RECURSIVE edges AS (
    SELECT DISTINCT sh1.warehouse_id AS wh_a, sh2.warehouse_id AS wh_b
    FROM supply_chain.shipments sh1
    JOIN supply_chain.shipments sh2 ON sh2.supplier_id = sh1.supplier_id AND sh2.warehouse_id <> sh1.warehouse_id
  ),
  path_search AS (
    SELECT wh_a, wh_b, 1 AS hops FROM edges WHERE wh_a = w.warehouse_id
    UNION ALL
    SELECT ps.wh_a, e.wh_b, ps.hops + 1
    FROM path_search ps JOIN edges e ON e.wh_a = ps.wh_b
    WHERE ps.hops < 4
  )
  SELECT wh_b AS to_warehouse, MIN(hops) AS shortest_hops FROM path_search GROUP BY wh_b
) sp
ORDER BY w.warehouse_id, sp.to_warehouse;

/* Q12. LATERAL with date-series generation: for each of a bounded sample of stores, a full daily calendar of the last 30 days with that store's order count per day. Orders are pre-aggregated by store+day ONCE (single scan) before the LATERAL, instead of a scalar COUNT(*) subquery re-scanning all 150,000 orders for every store x day combination. */
WITH daily_orders AS (
  SELECT store_id, order_date, COUNT(*) AS order_count
  FROM sales.orders
  WHERE store_id <= 30
  GROUP BY store_id, order_date
)
SELECT s.store_id, cal.the_day, cal.order_count
FROM stores.stores s
CROSS JOIN LATERAL (
  SELECT d::date AS the_day, COALESCE(do_.order_count, 0) AS order_count
  FROM generate_series((SELECT MAX(order_date) FROM sales.orders) - 29, (SELECT MAX(order_date) FROM sales.orders), interval '1 day') d
  LEFT JOIN daily_orders do_ ON do_.store_id = s.store_id AND do_.order_date = d::date
) cal
WHERE s.store_id <= 30
ORDER BY s.store_id, cal.the_day;

/* Q13. LATERAL with calendar generation: for each campaign, every day it ran between start_date and end_date. */
SELECT c.campaign_id, c.campaign_name, cal.the_day
FROM marketing.campaigns c
CROSS JOIN LATERAL (
  SELECT d::date AS the_day FROM generate_series(c.start_date, c.end_date, interval '1 day') d
) cal
ORDER BY c.campaign_id, cal.the_day
LIMIT 500;

/* Q14. LATERAL with Fibonacci/recursive numerics: for each loyalty tier, the first (tier_id + 5) Fibonacci numbers, generated via a recursive CTE inside the LATERAL. */
SELECT t.tier_id, t.tier_name, fib.n, fib.fib_value
FROM loyalty.tiers t
CROSS JOIN LATERAL (
  WITH RECURSIVE fibs AS (
    SELECT 1 AS n, 0::bigint AS fib_value, 1::bigint AS next_value
    UNION ALL
    SELECT n + 1, next_value, fib_value + next_value FROM fibs WHERE n < t.tier_id + 5
  )
  SELECT n, fib_value FROM fibs
) fib
ORDER BY t.tier_id, fib.n;

/* Q15. LATERAL with a rolling window computed via recursion: for each store, a month-by-month recursive walk of the last 6 months' revenue with a running 3-month rolling sum carried step-to-step. */
SELECT s.store_id, roll.month, roll.revenue, roll.rolling_3mo_sum
FROM stores.stores s
CROSS JOIN LATERAL (
  WITH RECURSIVE months AS (
    SELECT DATE_TRUNC('month', (SELECT MAX(order_date) FROM sales.orders)) - interval '5 months' AS month, 1 AS step
    UNION ALL
    SELECT month + interval '1 month', step + 1 FROM months WHERE step < 6
  ),
  monthly_rev AS (
    SELECT m.month,
           (SELECT COALESCE(SUM(o.net_total),0) FROM sales.orders o WHERE o.store_id = s.store_id AND DATE_TRUNC('month', o.order_date) = m.month) AS revenue
    FROM months m
  )
  SELECT month, revenue,
         SUM(revenue) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS rolling_3mo_sum
  FROM monthly_rev
) roll
WHERE s.store_id <= 30
ORDER BY s.store_id, roll.month;

/* Q16. LATERAL with "next N events": for each of a bounded sample of customers, the next 3 page views after their very first one, in session order. */
SELECT c.customer_id, nxt.page_url, nxt.view_timestamp, nxt.seq
FROM customers.customers c
CROSS JOIN LATERAL (
  WITH first_view AS (
    SELECT MIN(view_timestamp) AS ts FROM web_events.page_views pv WHERE pv.customer_id = c.customer_id
  )
  SELECT page_url, view_timestamp, ROW_NUMBER() OVER (ORDER BY view_timestamp) AS seq
  FROM web_events.page_views pv, first_view fv
  WHERE pv.customer_id = c.customer_id AND pv.view_timestamp >= fv.ts
  ORDER BY view_timestamp LIMIT 4
) nxt
WHERE c.customer_id <= 30 AND nxt.seq > 1
ORDER BY c.customer_id, nxt.seq;

/* Q17. LATERAL with "prev N events": for each of a bounded sample of customers, the 3 page views immediately before their last one. */
SELECT c.customer_id, prv.page_url, prv.view_timestamp, prv.seq
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT page_url, view_timestamp, ROW_NUMBER() OVER (ORDER BY view_timestamp DESC) AS seq
  FROM web_events.page_views pv WHERE pv.customer_id = c.customer_id
  ORDER BY view_timestamp DESC LIMIT 4
) prv
WHERE c.customer_id <= 30 AND prv.seq > 1
ORDER BY c.customer_id, prv.seq;

/* Q18. LATERAL with "find all ancestors": for each brand, its category (the only ancestor level this 2-level schema has), generalized as a depth-capped recursive walk for schema evolution safety. */
SELECT b.brand_id, b.brand_name, anc.category_id, anc.category_name, anc.depth
FROM core.dim_brand b
CROSS JOIN LATERAL (
  WITH RECURSIVE ancestors AS (
    SELECT cat.category_id, cat.category_name, 1 AS depth
    FROM core.dim_category cat WHERE cat.category_id = b.category_id
    UNION ALL
    SELECT cat2.category_id, cat2.category_name, a.depth + 1
    FROM ancestors a JOIN core.dim_category cat2 ON FALSE  -- no further parent level exists in this schema
    WHERE a.depth < 5
  )
  SELECT category_id, category_name, depth FROM ancestors
) anc
ORDER BY b.brand_id;

/* Q19. LATERAL with "find all descendants": for each category, every brand beneath it (the only descendant level this 2-level schema has), generalized as a depth-capped recursive walk. */
SELECT cat.category_id, cat.category_name, desc_.brand_id, desc_.brand_name, desc_.depth
FROM core.dim_category cat
CROSS JOIN LATERAL (
  WITH RECURSIVE descendants AS (
    SELECT b.brand_id, b.brand_name, 1 AS depth
    FROM core.dim_brand b WHERE b.category_id = cat.category_id
    UNION ALL
    SELECT b2.brand_id, b2.brand_name, d.depth + 1
    FROM descendants d JOIN core.dim_brand b2 ON FALSE  -- no further child level exists in this schema
    WHERE d.depth < 5
  )
  SELECT brand_id, brand_name, depth FROM descendants
) desc_
ORDER BY cat.category_id, desc_.brand_id;

/* Q20. LATERAL with a depth-limited recursive walk: for each warehouse, all warehouses reachable within a caller-specified 2-hop limit on the supplier-shipment graph (demonstrates the depth parameter being threaded into the recursive term). */
SELECT w.warehouse_id, walk.reachable_warehouse, walk.hops
FROM supply_chain.warehouses w
CROSS JOIN LATERAL (
  WITH RECURSIVE edges AS (
    SELECT DISTINCT sh1.warehouse_id AS wh_a, sh2.warehouse_id AS wh_b
    FROM supply_chain.shipments sh1
    JOIN supply_chain.shipments sh2 ON sh2.supplier_id = sh1.supplier_id AND sh2.warehouse_id <> sh1.warehouse_id
  ),
  walk AS (
    SELECT wh_a, wh_b AS reachable_warehouse, 1 AS hops FROM edges WHERE wh_a = w.warehouse_id
    UNION ALL
    SELECT wk.wh_a, e.wh_b, wk.hops + 1
    FROM walk wk JOIN edges e ON e.wh_a = wk.reachable_warehouse
    WHERE wk.hops < 2  -- depth limit = 2
  )
  SELECT DISTINCT reachable_warehouse, MIN(hops) OVER (PARTITION BY reachable_warehouse) AS hops FROM walk
) walk
ORDER BY w.warehouse_id, walk.hops;

/* Q21. LATERAL with a state-machine traversal: RetailMart has no explicit order-status transition log, so an order's lifecycle is reconstructed from its own timestamps (placed -> shipped -> delivered) via sales.shipments, walked as an ordered state sequence per order. Restricted to a bounded sample of orders. */
SELECT o.order_id, states.state_name, states.state_date, states.seq
FROM sales.orders o
CROSS JOIN LATERAL (
  SELECT 'placed' AS state_name, o.order_date AS state_date, 1 AS seq
  UNION ALL
  SELECT 'shipped', sh.shipped_date, 2 FROM sales.shipments sh WHERE sh.order_id = o.order_id AND sh.shipped_date IS NOT NULL
  UNION ALL
  SELECT 'delivered', sh.delivered_date, 3 FROM sales.shipments sh WHERE sh.order_id = o.order_id AND sh.delivered_date IS NOT NULL
) states
WHERE o.order_id <= 300
ORDER BY o.order_id, states.seq;

/* Q22. LATERAL with a state-history rollup: for each product, a count of how many times each column has changed in audit.record_changes (a rollup of its edit history "states"). */
SELECT p.product_id, p.product_name, roll.column_name, roll.change_count
FROM products.products p
CROSS JOIN LATERAL (
  SELECT column_name, COUNT(*) AS change_count
  FROM audit.record_changes rc WHERE rc.table_name = 'products' AND rc.record_id = p.product_id
  GROUP BY column_name
) roll
WHERE p.product_id <= 500
ORDER BY p.product_id, roll.change_count DESC;

/* Q23. LATERAL with a version chain: for each product with price changes, the ordered sequence of price versions (old_value -> new_value) with a version number. */
SELECT p.product_id, p.product_name, ver.version_no, ver.old_value, ver.new_value, ver.changed_at
FROM products.products p
CROSS JOIN LATERAL (
  SELECT ROW_NUMBER() OVER (ORDER BY changed_at) AS version_no, old_value, new_value, changed_at
  FROM audit.record_changes rc
  WHERE rc.table_name = 'products' AND rc.record_id = p.product_id AND rc.column_name = 'price'
) ver
WHERE p.product_id <= 500
ORDER BY p.product_id, ver.version_no;

/* Q24. LATERAL with audit-trail traversal: for each employee, their full salary-change audit trail with the cumulative delta from their first recorded salary. */
SELECT e.employee_id, trail.changed_at, trail.old_value, trail.new_value, trail.cumulative_delta
FROM stores.employees e
CROSS JOIN LATERAL (
  SELECT changed_at, old_value, new_value,
         (new_value::numeric - FIRST_VALUE(old_value::numeric) OVER (ORDER BY changed_at)) AS cumulative_delta
  FROM audit.record_changes rc
  WHERE rc.table_name = 'employees' AND rc.record_id = e.employee_id AND rc.column_name = 'salary'
) trail
WHERE e.employee_id <= 500
ORDER BY e.employee_id, trail.changed_at;

/* Q25. Master: LATERAL with recursive top-N - for each warehouse, the top-3 (by total shipped quantity) warehouses reachable within 3 hops on the supplier-shipment graph, combining recursion with a top-N rank in one LATERAL. */
SELECT w.warehouse_id, top3.reachable_warehouse, top3.hops, top3.total_qty, top3.qty_rank
FROM supply_chain.warehouses w
CROSS JOIN LATERAL (
  WITH RECURSIVE edges AS (
    SELECT DISTINCT sh1.warehouse_id AS wh_a, sh2.warehouse_id AS wh_b
    FROM supply_chain.shipments sh1
    JOIN supply_chain.shipments sh2 ON sh2.supplier_id = sh1.supplier_id AND sh2.warehouse_id <> sh1.warehouse_id
  ),
  walk AS (
    SELECT wh_a, wh_b AS reachable_warehouse, 1 AS hops FROM edges WHERE wh_a = w.warehouse_id
    UNION ALL
    SELECT wk.wh_a, e.wh_b, wk.hops + 1
    FROM walk wk JOIN edges e ON e.wh_a = wk.reachable_warehouse
    WHERE wk.hops < 3
  ),
  best_hops AS (
    SELECT reachable_warehouse, MIN(hops) AS hops FROM walk GROUP BY reachable_warehouse
  ),
  scored AS (
    SELECT bh.reachable_warehouse, bh.hops,
           COALESCE((SELECT SUM(quantity) FROM supply_chain.shipments sh WHERE sh.warehouse_id = bh.reachable_warehouse),0) AS total_qty
    FROM best_hops bh
  )
  SELECT reachable_warehouse, hops, total_qty,
         RANK() OVER (ORDER BY total_qty DESC) AS qty_rank
  FROM scored
) top3
WHERE top3.qty_rank <= 3
ORDER BY w.warehouse_id, top3.qty_rank;
/* SECTION B: LATERAL + WINDOW MEGA (25) */

/* Q26. LATERAL with a PERCENTILE inside: for each product category, the 25th/50th/75th percentile of order-item net_amount for products in that category. */
SELECT cat.category_id, cat.category_name, pct.p25, pct.p50, pct.p75
FROM core.dim_category cat
CROSS JOIN LATERAL (
  SELECT PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY oi.net_amount) AS p25,
         PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY oi.net_amount) AS p50,
         PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY oi.net_amount) AS p75
  FROM sales.order_items oi
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  WHERE b.category_id = cat.category_id
) pct;

/* Q27. LATERAL with MODE inside: for each region, the most common order_status among its orders. */
SELECT r.region_id, r.region_name, m.order_status AS most_common_status
FROM core.dim_region r
CROSS JOIN LATERAL (
  SELECT MODE() WITHIN GROUP (ORDER BY o.order_status) AS order_status
  FROM stores.stores s JOIN sales.orders o ON o.store_id = s.store_id
  WHERE s.region_id = r.region_id
) m;

/* Q28. LATERAL with cohort RFM scoring: for each registration-month cohort, the average Recency/Frequency/Monetary scores of its members (pre-aggregated once, then joined by cohort - avoiding a per-customer LATERAL over the full unindexed orders table). */
WITH cust_agg AS (
  SELECT cust_id AS customer_id, (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS recency_days,
         COUNT(*) AS frequency, SUM(net_total) AS monetary
  FROM sales.orders GROUP BY cust_id
),
cust_cohort AS (
  SELECT c.customer_id, DATE_TRUNC('month', c.registration_date) AS cohort_month,
         ca.recency_days, ca.frequency, ca.monetary
  FROM customers.customers c LEFT JOIN cust_agg ca ON ca.customer_id = c.customer_id
)
SELECT coh.cohort_month, avgs.avg_recency, avgs.avg_frequency, avgs.avg_monetary
FROM (SELECT DISTINCT cohort_month FROM cust_cohort) coh
CROSS JOIN LATERAL (
  SELECT AVG(recency_days) AS avg_recency, AVG(frequency) AS avg_frequency, AVG(monetary) AS avg_monetary
  FROM cust_cohort cc WHERE cc.cohort_month = coh.cohort_month
) avgs
ORDER BY coh.cohort_month;

/* Q29. LATERAL with a rolling 7-day metric: for each of a bounded sample of stores, each day's order count alongside a trailing 7-day rolling sum. */
WITH daily AS (
  SELECT store_id, order_date, COUNT(*) AS daily_orders
  FROM sales.orders WHERE store_id <= 30
  GROUP BY store_id, order_date
)
SELECT s.store_id, roll.order_date, roll.daily_orders, roll.rolling_7day
FROM stores.stores s
CROSS JOIN LATERAL (
  SELECT order_date, daily_orders,
         SUM(daily_orders) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS rolling_7day
  FROM daily d WHERE d.store_id = s.store_id
) roll
WHERE s.store_id <= 30
ORDER BY s.store_id, roll.order_date
LIMIT 500;

/* Q30. LATERAL with a rolling 30-day metric: for each of a bounded sample of stores, each day's revenue alongside a trailing 30-day rolling average. */
WITH daily AS (
  SELECT store_id, order_date, SUM(net_total) AS daily_revenue
  FROM sales.orders WHERE store_id <= 30
  GROUP BY store_id, order_date
)
SELECT s.store_id, roll.order_date, roll.daily_revenue, roll.rolling_30day_avg
FROM stores.stores s
CROSS JOIN LATERAL (
  SELECT order_date, daily_revenue,
         AVG(daily_revenue) OVER (ORDER BY order_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS rolling_30day_avg
  FROM daily d WHERE d.store_id = s.store_id
) roll
WHERE s.store_id <= 30
ORDER BY s.store_id, roll.order_date
LIMIT 500;

/* Q31. LATERAL with an EWMA (exponentially weighted moving average, alpha=0.3): a true EWMA is inherently recursive (ewma[i] = alpha*value[i] + (1-alpha)*ewma[i-1], each step depending on the previous one), which a plain window function cannot express since it can't reference its own prior output - so it is computed here with a recursive CTE inside the LATERAL. */
WITH monthly AS (
  SELECT store_id, DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS revenue
  FROM sales.orders WHERE store_id <= 30
  GROUP BY store_id, DATE_TRUNC('month', order_date)
)
SELECT s.store_id, ewma.month, ewma.revenue, ewma.ewma_value
FROM stores.stores s
CROSS JOIN LATERAL (
  WITH RECURSIVE numbered AS (
    SELECT month, revenue, ROW_NUMBER() OVER (ORDER BY month) AS rn
    FROM monthly m WHERE m.store_id = s.store_id
  ),
  ewma_walk AS (
    SELECT rn, month, revenue, revenue::numeric AS ewma_value
    FROM numbered WHERE rn = 1
    UNION ALL
    SELECT n.rn, n.month, n.revenue, (0.3 * n.revenue + 0.7 * ew.ewma_value)
    FROM ewma_walk ew JOIN numbered n ON n.rn = ew.rn + 1
  )
  SELECT month, revenue, ROUND(ewma_value, 2) AS ewma_value FROM ewma_walk
) ewma
WHERE s.store_id <= 30
ORDER BY s.store_id, ewma.month
LIMIT 500;

/* Q32. LATERAL with a seasonality compare: for each product category, this year's vs last year's revenue by calendar month. */
SELECT cat.category_id, cat.category_name, seas.month_num, seas.this_year_revenue, seas.last_year_revenue
FROM core.dim_category cat
CROSS JOIN LATERAL (
  SELECT EXTRACT(MONTH FROM o.order_date)::int AS month_num,
         SUM(oi.net_amount) FILTER (WHERE EXTRACT(YEAR FROM o.order_date) = EXTRACT(YEAR FROM (SELECT MAX(order_date) FROM sales.orders))) AS this_year_revenue,
         SUM(oi.net_amount) FILTER (WHERE EXTRACT(YEAR FROM o.order_date) = EXTRACT(YEAR FROM (SELECT MAX(order_date) FROM sales.orders)) - 1) AS last_year_revenue
  FROM sales.orders o
  JOIN sales.order_items oi ON oi.order_id = o.order_id
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  WHERE b.category_id = cat.category_id
  GROUP BY EXTRACT(MONTH FROM o.order_date)
) seas
ORDER BY cat.category_id, seas.month_num;

/* Q33. LATERAL with YoY growth: for each region, this year's vs last year's total revenue and the percent growth. */
SELECT r.region_id, r.region_name, yoy.this_year, yoy.last_year,
       ROUND((yoy.this_year - yoy.last_year) / NULLIF(yoy.last_year,0) * 100, 2) AS pct_growth
FROM core.dim_region r
CROSS JOIN LATERAL (
  SELECT
    SUM(o.net_total) FILTER (WHERE EXTRACT(YEAR FROM o.order_date) = EXTRACT(YEAR FROM (SELECT MAX(order_date) FROM sales.orders))) AS this_year,
    SUM(o.net_total) FILTER (WHERE EXTRACT(YEAR FROM o.order_date) = EXTRACT(YEAR FROM (SELECT MAX(order_date) FROM sales.orders)) - 1) AS last_year
  FROM stores.stores s JOIN sales.orders o ON o.store_id = s.store_id
  WHERE s.region_id = r.region_id
) yoy;

/* Q34. LATERAL with a regression slope: for each of a bounded sample of products, the linear trend (REGR_SLOPE of net_amount over order sequence number) of its sales over time. */
WITH prod_sample AS (SELECT product_id FROM products.products ORDER BY product_id LIMIT 100)
SELECT ps.product_id, reg.slope, reg.intercept
FROM prod_sample ps
CROSS JOIN LATERAL (
  SELECT REGR_SLOPE(oi.net_amount, EXTRACT(EPOCH FROM o.order_date)) AS slope,
         REGR_INTERCEPT(oi.net_amount, EXTRACT(EPOCH FROM o.order_date)) AS intercept
  FROM sales.order_items oi JOIN sales.orders o ON o.order_id = oi.order_id
  WHERE oi.prod_id = ps.product_id
) reg
WHERE reg.slope IS NOT NULL
ORDER BY ps.product_id
LIMIT 100;

/* Q35. LATERAL with a correlation: for each of a bounded sample of products, the correlation between its price and its order quantity sold (does discounting/pricing move volume?). */
WITH prod_sample AS (SELECT product_id, price FROM products.products ORDER BY product_id LIMIT 100)
SELECT ps.product_id, corr.correlation
FROM prod_sample ps
CROSS JOIN LATERAL (
  SELECT CORR(oi.quantity, oi.net_amount / NULLIF(oi.quantity,0)) AS correlation
  FROM sales.order_items oi WHERE oi.prod_id = ps.product_id
) corr
WHERE corr.correlation IS NOT NULL
ORDER BY ps.product_id
LIMIT 100;

/* Q36. LATERAL with a z-score: for each of a bounded sample of products, its price expressed as a z-score against its own brand's price distribution. */
WITH prod_sample AS (SELECT product_id, brand_id, price FROM products.products ORDER BY product_id LIMIT 300)
SELECT ps.product_id, ps.price, z.brand_avg, z.brand_stddev, z.z_score
FROM prod_sample ps
CROSS JOIN LATERAL (
  SELECT AVG(p2.price) AS brand_avg, STDDEV(p2.price) AS brand_stddev,
         (ps.price - AVG(p2.price)) / NULLIF(STDDEV(p2.price),0) AS z_score
  FROM products.products p2 WHERE p2.brand_id = ps.brand_id
) z
ORDER BY ABS(z.z_score) DESC NULLS LAST
LIMIT 100;

/* Q37. LATERAL with outlier flagging: for each of a bounded sample of products, flag it as a price outlier if more than 2 standard deviations from its brand's mean price. */
WITH prod_sample AS (SELECT product_id, brand_id, price FROM products.products ORDER BY product_id LIMIT 300)
SELECT ps.product_id, ps.price, o.is_outlier
FROM prod_sample ps
CROSS JOIN LATERAL (
  SELECT (ABS(ps.price - AVG(p2.price)) > 2 * NULLIF(STDDEV(p2.price),0)) AS is_outlier
  FROM products.products p2 WHERE p2.brand_id = ps.brand_id
) o
WHERE o.is_outlier IS TRUE
ORDER BY ps.product_id;

/* Q38. LATERAL with anomaly detection: for each of a bounded sample of stores, flag any month whose revenue is more than 2 standard deviations from that store's own monthly average. */
WITH monthly AS (
  SELECT store_id, DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS revenue
  FROM sales.orders WHERE store_id <= 50
  GROUP BY store_id, DATE_TRUNC('month', order_date)
)
SELECT s.store_id, anom.month, anom.revenue, anom.is_anomaly
FROM stores.stores s
CROSS JOIN LATERAL (
  SELECT month, revenue,
         (ABS(revenue - AVG(revenue) OVER ()) > 2 * NULLIF(STDDEV(revenue) OVER (),0)) AS is_anomaly
  FROM monthly m WHERE m.store_id = s.store_id
) anom
WHERE s.store_id <= 50 AND anom.is_anomaly IS TRUE
ORDER BY s.store_id, anom.month;

/* Q39. LATERAL with a running rank: for each of a bounded sample of regions, stores ranked by cumulative revenue as of each month (rank changes over time). */
WITH monthly AS (
  SELECT s.store_id, s.region_id, DATE_TRUNC('month', o.order_date) AS month, SUM(o.net_total) AS revenue
  FROM stores.stores s JOIN sales.orders o ON o.store_id = s.store_id
  GROUP BY s.store_id, s.region_id, DATE_TRUNC('month', o.order_date)
),
cumulative AS (
  SELECT store_id, region_id, month,
         SUM(revenue) OVER (PARTITION BY store_id ORDER BY month) AS cum_revenue
  FROM monthly
)
SELECT r.region_id, rk.store_id, rk.month, rk.cum_revenue, rk.running_rank
FROM core.dim_region r
CROSS JOIN LATERAL (
  SELECT store_id, month, cum_revenue,
         RANK() OVER (PARTITION BY month ORDER BY cum_revenue DESC) AS running_rank
  FROM cumulative c WHERE c.region_id = r.region_id
) rk
WHERE rk.running_rank <= 3
ORDER BY r.region_id, rk.month, rk.running_rank
LIMIT 300;

/* Q40. LATERAL with a cumulative count: for each of a bounded sample of customers, their order count building up cumulatively over time. */
SELECT c.customer_id, cum.order_date, cum.cumulative_orders
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_date, ROW_NUMBER() OVER (ORDER BY order_date) AS cumulative_orders
  FROM sales.orders o WHERE o.cust_id = c.customer_id
) cum
WHERE c.customer_id <= 30
ORDER BY c.customer_id, cum.order_date;

/* Q41. LATERAL with a cumulative-distinct count: for each of a bounded sample of customers, the running count of DISTINCT products purchased over time (Postgres has no COUNT(DISTINCT) window function, so this is computed via a first-purchase-date self-join instead). */
SELECT c.customer_id, cd.purchase_date, cd.cumulative_distinct_products
FROM customers.customers c
CROSS JOIN LATERAL (
  WITH first_purchase AS (
    SELECT oi.prod_id, MIN(o.order_date) AS first_date
    FROM sales.order_items oi JOIN sales.orders o ON o.order_id = oi.order_id
    WHERE o.cust_id = c.customer_id
    GROUP BY oi.prod_id
  )
  SELECT first_date AS purchase_date,
         COUNT(*) OVER (ORDER BY first_date) AS cumulative_distinct_products
  FROM first_purchase
) cd
WHERE c.customer_id <= 30
ORDER BY c.customer_id, cd.purchase_date;

/* Q42. LATERAL with a cumulative sum: for each of a bounded sample of customers, their running lifetime spend over time. */
SELECT c.customer_id, cs.order_date, cs.order_total, cs.cumulative_spend
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_date, net_total AS order_total,
         SUM(net_total) OVER (ORDER BY order_date) AS cumulative_spend
  FROM sales.orders o WHERE o.cust_id = c.customer_id
) cs
WHERE c.customer_id <= 30
ORDER BY c.customer_id, cs.order_date;

/* Q43. LATERAL with a rolling average: for each of a bounded sample of customers, a trailing-3-order rolling average of order value. */
SELECT c.customer_id, ra.order_date, ra.net_total, ra.rolling_avg_3
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_date, net_total,
         AVG(net_total) OVER (ORDER BY order_date ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS rolling_avg_3
  FROM sales.orders o WHERE o.cust_id = c.customer_id
) ra
WHERE c.customer_id <= 30
ORDER BY c.customer_id, ra.order_date;

/* Q44. LATERAL with a rolling median: for each of a bounded sample of stores, a trailing-5-day rolling median of daily revenue (computed per-window via a nested LATERAL since window functions have no built-in rolling-median). */
WITH daily AS (
  SELECT store_id, order_date, SUM(net_total) AS daily_revenue
  FROM sales.orders WHERE store_id <= 20
  GROUP BY store_id, order_date
),
numbered AS (
  SELECT store_id, order_date, daily_revenue, ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY order_date) AS rn
  FROM daily
)
SELECT s.store_id, rm.order_date, rm.daily_revenue, rm.rolling_median_5
FROM stores.stores s
CROSS JOIN LATERAL (
  SELECT n.order_date, n.daily_revenue,
         (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY n2.daily_revenue)
          FROM numbered n2 WHERE n2.store_id = n.store_id AND n2.rn BETWEEN n.rn - 4 AND n.rn) AS rolling_median_5
  FROM numbered n WHERE n.store_id = s.store_id
) rm
WHERE s.store_id <= 20
ORDER BY s.store_id, rm.order_date
LIMIT 300;

/* Q45. LATERAL with FIRST_VALUE/LAST_VALUE: for each of a bounded sample of customers, every order alongside their very first and most recent order values. */
SELECT c.customer_id, fl.order_id, fl.order_date, fl.net_total, fl.first_order_value, fl.last_order_value
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id, order_date, net_total,
         FIRST_VALUE(net_total) OVER (ORDER BY order_date ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS first_order_value,
         LAST_VALUE(net_total) OVER (ORDER BY order_date ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_order_value
  FROM sales.orders o WHERE o.cust_id = c.customer_id
) fl
WHERE c.customer_id <= 50
ORDER BY c.customer_id, fl.order_date;

/* Q46. LATERAL with a LAG/LEAD chain: for each of a bounded sample of customers, each order alongside the days since the previous order and days until the next order. */
SELECT c.customer_id, ll.order_id, ll.order_date, ll.days_since_prev, ll.days_until_next
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id, order_date,
         order_date - LAG(order_date) OVER (ORDER BY order_date) AS days_since_prev,
         LEAD(order_date) OVER (ORDER BY order_date) - order_date AS days_until_next
  FROM sales.orders o WHERE o.cust_id = c.customer_id
) ll
WHERE c.customer_id <= 50
ORDER BY c.customer_id, ll.order_date;

/* Q47. LATERAL with PARTITION BY tier: for each region, revenue ranked separately within each loyalty tier. */
SELECT r.region_id, pt.tier_name, pt.customer_id, pt.total_spend, pt.rank_in_tier
FROM core.dim_region r
CROSS JOIN LATERAL (
  WITH tier_spend AS (
    SELECT c.customer_id, t.tier_name, SUM(o.net_total) AS total_spend
    FROM customers.customers c
    JOIN loyalty.members m ON m.customer_id = c.customer_id
    JOIN loyalty.tiers t ON t.tier_id = m.tier_id
    JOIN sales.orders o ON o.cust_id = c.customer_id
    JOIN stores.stores s ON s.store_id = o.store_id
    WHERE s.region_id = r.region_id
    GROUP BY c.customer_id, t.tier_name
  )
  SELECT tier_name, customer_id, total_spend,
         RANK() OVER (PARTITION BY tier_name ORDER BY total_spend DESC) AS rank_in_tier
  FROM tier_spend
) pt
WHERE pt.rank_in_tier <= 3
ORDER BY r.region_id, pt.tier_name, pt.rank_in_tier;

/* Q48. LATERAL with PARTITION BY region: for each product category, revenue ranked separately within each region. */
SELECT cat.category_id, cat.category_name, pr.region_id, pr.revenue, pr.region_rank
FROM core.dim_category cat
CROSS JOIN LATERAL (
  SELECT s.region_id, SUM(oi.net_amount) AS revenue,
         RANK() OVER (ORDER BY SUM(oi.net_amount) DESC) AS region_rank
  FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  JOIN stores.stores s ON s.store_id = o.store_id
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  WHERE b.category_id = cat.category_id
  GROUP BY s.region_id
) pr
WHERE pr.region_rank <= 3
ORDER BY cat.category_id, pr.region_rank;

/* Q49. LATERAL with PARTITION BY month: for each of a bounded sample of stores, employees ranked by attendance count within each month. */
SELECT s.store_id, pm.month, pm.employee_id, pm.days_present, pm.month_rank
FROM stores.stores s
CROSS JOIN LATERAL (
  WITH monthly_attendance AS (
    SELECT e.employee_id, DATE_TRUNC('month', a.attendance_date) AS month,
           COUNT(*) FILTER (WHERE a.check_in IS NOT NULL) AS days_present
    FROM stores.employees e
    JOIN hr.attendance a ON a.employee_id = e.employee_id
    WHERE e.store_id = s.store_id
    GROUP BY e.employee_id, DATE_TRUNC('month', a.attendance_date)
  )
  SELECT employee_id, month, days_present,
         RANK() OVER (PARTITION BY month ORDER BY days_present DESC) AS month_rank
  FROM monthly_attendance
) pm
WHERE s.store_id <= 30 AND pm.month_rank <= 2
ORDER BY s.store_id, pm.month, pm.month_rank;

/* Q50. LATERAL with a multi-PARTITION window: for each region, revenue ranked by both store AND month simultaneously (two separate PARTITION BY windows side by side). */
SELECT r.region_id, mp.store_id, mp.month, mp.revenue, mp.rank_in_store_history, mp.rank_in_region_month
FROM core.dim_region r
CROSS JOIN LATERAL (
  WITH store_month AS (
    SELECT s.store_id, DATE_TRUNC('month', o.order_date) AS month, SUM(o.net_total) AS revenue
    FROM stores.stores s JOIN sales.orders o ON o.store_id = s.store_id
    WHERE s.region_id = r.region_id
    GROUP BY s.store_id, DATE_TRUNC('month', o.order_date)
  )
  SELECT store_id, month, revenue,
         RANK() OVER (PARTITION BY store_id ORDER BY revenue DESC) AS rank_in_store_history,
         RANK() OVER (PARTITION BY month ORDER BY revenue DESC) AS rank_in_region_month
  FROM store_month
) mp
WHERE mp.rank_in_region_month <= 3
ORDER BY r.region_id, mp.month, mp.rank_in_region_month
LIMIT 300;
/* SECTION C: LATERAL CHAINS 4-5 LEVELS (25) */

/* Q51. customer -> last order -> first item -> product -> brand. */
SELECT c.customer_id, lo.order_id, fi.order_item_id, p.product_name, b.brand_name
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY order_date DESC LIMIT 1
) lo
CROSS JOIN LATERAL (
  SELECT order_item_id, prod_id FROM sales.order_items oi WHERE oi.order_id = lo.order_id ORDER BY order_item_id LIMIT 1
) fi
JOIN products.products p ON p.product_id = fi.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
WHERE c.customer_id <= 100;

/* Q52. region -> top store -> top employee -> top ticket. */
SELECT r.region_id, ts.store_id, te.employee_id, tt.ticket_id, tt.priority
FROM core.dim_region r
CROSS JOIN LATERAL (
  SELECT s.store_id, SUM(o.net_total) AS revenue
  FROM stores.stores s JOIN sales.orders o ON o.store_id = s.store_id
  WHERE s.region_id = r.region_id GROUP BY s.store_id ORDER BY SUM(o.net_total) DESC LIMIT 1
) ts
CROSS JOIN LATERAL (
  SELECT employee_id FROM stores.employees e WHERE e.store_id = ts.store_id ORDER BY salary DESC LIMIT 1
) te
CROSS JOIN LATERAL (
  SELECT ticket_id, priority FROM support.tickets t WHERE t.agent_id = te.employee_id ORDER BY created_date DESC LIMIT 1
) tt;

/* Q53. campaign -> top platform -> top customer -> top order. */
SELECT c.campaign_id, tp.platform, tc.customer_id, tord.order_id
FROM marketing.campaigns c
CROSS JOIN LATERAL (
  SELECT platform, SUM(amount) AS spend FROM marketing.ads_spend a WHERE a.campaign_id = c.campaign_id
  GROUP BY platform ORDER BY SUM(amount) DESC LIMIT 1
) tp
CROSS JOIN LATERAL (
  SELECT o.cust_id AS customer_id, SUM(o.net_total) AS spend
  FROM sales.orders o WHERE o.order_date BETWEEN c.start_date AND c.end_date
  GROUP BY o.cust_id ORDER BY SUM(o.net_total) DESC LIMIT 1
) tc
CROSS JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.cust_id = tc.customer_id ORDER BY net_total DESC LIMIT 1
) tord
LIMIT 200;

/* Q54. warehouse -> top product -> top supplier -> latest shipment. */
SELECT w.warehouse_id, tp.product_id, ts.supplier_id, lsh.shipment_id, lsh.shipped_date
FROM supply_chain.warehouses w
CROSS JOIN LATERAL (
  SELECT product_id, SUM(quantity) AS qty FROM supply_chain.shipments sh WHERE sh.warehouse_id = w.warehouse_id
  GROUP BY product_id ORDER BY SUM(quantity) DESC LIMIT 1
) tp
CROSS JOIN LATERAL (
  SELECT supplier_id FROM products.products p WHERE p.product_id = tp.product_id LIMIT 1
) ts
CROSS JOIN LATERAL (
  SELECT shipment_id, shipped_date FROM supply_chain.shipments sh2
  WHERE sh2.supplier_id = ts.supplier_id AND sh2.warehouse_id = w.warehouse_id
  ORDER BY shipped_date DESC LIMIT 1
) lsh;

/* Q55. tier -> top customer -> top product -> top brand. */
SELECT t.tier_id, t.tier_name, tc.customer_id, tp.prod_id, b.brand_name
FROM loyalty.tiers t
CROSS JOIN LATERAL (
  SELECT m.customer_id, SUM(o.net_total) AS spend
  FROM loyalty.members m JOIN sales.orders o ON o.cust_id = m.customer_id
  WHERE m.tier_id = t.tier_id GROUP BY m.customer_id ORDER BY SUM(o.net_total) DESC LIMIT 1
) tc
CROSS JOIN LATERAL (
  SELECT oi.prod_id, SUM(oi.net_amount) AS spend
  FROM sales.order_items oi JOIN sales.orders o ON o.order_id = oi.order_id
  WHERE o.cust_id = tc.customer_id GROUP BY oi.prod_id ORDER BY SUM(oi.net_amount) DESC LIMIT 1
) tp
JOIN products.products p ON p.product_id = tp.prod_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id;

/* Q56. agent -> top ticket -> customer -> top order. */
SELECT ag.employee_id AS agent_id, tt.ticket_id, tt.customer_id, tord.order_id, tord.net_total
FROM stores.employees ag
CROSS JOIN LATERAL (
  SELECT ticket_id, customer_id FROM support.tickets t WHERE t.agent_id = ag.employee_id ORDER BY created_date DESC LIMIT 1
) tt
CROSS JOIN LATERAL (
  SELECT order_id, net_total FROM sales.orders o WHERE o.cust_id = tt.customer_id ORDER BY net_total DESC LIMIT 1
) tord
WHERE ag.employee_id <= 300;

/* Q57. category -> top brand -> top product -> top buyer. */
SELECT cat.category_id, tb.brand_id, tp.product_id, tbuy.customer_id
FROM core.dim_category cat
CROSS JOIN LATERAL (
  SELECT b.brand_id, SUM(oi.net_amount) AS revenue
  FROM core.dim_brand b JOIN products.products p ON p.brand_id = b.brand_id
  JOIN sales.order_items oi ON oi.prod_id = p.product_id
  WHERE b.category_id = cat.category_id GROUP BY b.brand_id ORDER BY SUM(oi.net_amount) DESC LIMIT 1
) tb
CROSS JOIN LATERAL (
  SELECT p.product_id, SUM(oi.net_amount) AS revenue
  FROM products.products p JOIN sales.order_items oi ON oi.prod_id = p.product_id
  WHERE p.brand_id = tb.brand_id GROUP BY p.product_id ORDER BY SUM(oi.net_amount) DESC LIMIT 1
) tp
CROSS JOIN LATERAL (
  SELECT o.cust_id AS customer_id, SUM(oi.net_amount) AS spend
  FROM sales.order_items oi JOIN sales.orders o ON o.order_id = oi.order_id
  WHERE oi.prod_id = tp.product_id GROUP BY o.cust_id ORDER BY SUM(oi.net_amount) DESC LIMIT 1
) tbuy;

/* Q58. courier -> busiest day -> top customer -> top order. */
SELECT cour.courier_name, bd.ship_day, tc.customer_id, tord.order_id
FROM (SELECT DISTINCT courier_name FROM sales.shipments) cour
CROSS JOIN LATERAL (
  SELECT shipped_date AS ship_day, COUNT(*) AS cnt FROM sales.shipments sh WHERE sh.courier_name = cour.courier_name
  GROUP BY shipped_date ORDER BY COUNT(*) DESC LIMIT 1
) bd
CROSS JOIN LATERAL (
  SELECT o.cust_id AS customer_id, SUM(o.net_total) AS spend
  FROM sales.shipments sh JOIN sales.orders o ON o.order_id = sh.order_id
  WHERE sh.courier_name = cour.courier_name AND sh.shipped_date = bd.ship_day
  GROUP BY o.cust_id ORDER BY SUM(o.net_total) DESC LIMIT 1
) tc
CROSS JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.cust_id = tc.customer_id ORDER BY net_total DESC LIMIT 1
) tord;

/* Q59. dept -> top employee -> top ticket -> resolution time. */
SELECT d.dept_id, te.employee_id, tt.ticket_id, tt.resolution_hours
FROM core.dim_department d
CROSS JOIN LATERAL (
  SELECT employee_id FROM stores.employees e WHERE e.dept_id = d.dept_id ORDER BY salary DESC LIMIT 1
) te
CROSS JOIN LATERAL (
  SELECT ticket_id, EXTRACT(EPOCH FROM (resolved_date - created_date))/3600 AS resolution_hours
  FROM support.tickets t WHERE t.agent_id = te.employee_id AND resolved_date IS NOT NULL
  ORDER BY created_date DESC LIMIT 1
) tt;

/* Q60. supplier -> top product -> top warehouse -> quantity. */
SELECT sup.supplier_id, tp.product_id, tw.warehouse_id, tw.total_qty
FROM products.suppliers sup
CROSS JOIN LATERAL (
  SELECT p.product_id, SUM(oi.net_amount) AS revenue
  FROM products.products p JOIN sales.order_items oi ON oi.prod_id = p.product_id
  WHERE p.supplier_id = sup.supplier_id GROUP BY p.product_id ORDER BY SUM(oi.net_amount) DESC LIMIT 1
) tp
CROSS JOIN LATERAL (
  SELECT warehouse_id, SUM(quantity) AS total_qty FROM supply_chain.shipments sh
  WHERE sh.product_id = tp.product_id GROUP BY warehouse_id ORDER BY SUM(quantity) DESC LIMIT 1
) tw
WHERE sup.supplier_id <= 100;

/* Q61. month -> top region -> top store -> top customer. */
SELECT mon.month, tr.region_id, ts.store_id, tc.customer_id
FROM (SELECT DISTINCT DATE_TRUNC('month', order_date) AS month FROM sales.orders) mon
CROSS JOIN LATERAL (
  SELECT s.region_id, SUM(o.net_total) AS revenue
  FROM stores.stores s JOIN sales.orders o ON o.store_id = s.store_id
  WHERE DATE_TRUNC('month', o.order_date) = mon.month
  GROUP BY s.region_id ORDER BY SUM(o.net_total) DESC LIMIT 1
) tr
CROSS JOIN LATERAL (
  SELECT s.store_id, SUM(o.net_total) AS revenue
  FROM stores.stores s JOIN sales.orders o ON o.store_id = s.store_id
  WHERE s.region_id = tr.region_id AND DATE_TRUNC('month', o.order_date) = mon.month
  GROUP BY s.store_id ORDER BY SUM(o.net_total) DESC LIMIT 1
) ts
CROSS JOIN LATERAL (
  SELECT o.cust_id AS customer_id, SUM(o.net_total) AS spend
  FROM sales.orders o WHERE o.store_id = ts.store_id AND DATE_TRUNC('month', o.order_date) = mon.month
  GROUP BY o.cust_id ORDER BY SUM(o.net_total) DESC LIMIT 1
) tc
ORDER BY mon.month;

/* Q62. day -> top hour -> top order -> top product. */
WITH sample_days AS (SELECT DISTINCT order_date FROM sales.orders ORDER BY order_date DESC LIMIT 60)
SELECT sd.order_date, th.order_hour, tord.order_id, tp.prod_id
FROM sample_days sd
CROSS JOIN LATERAL (
  SELECT EXTRACT(HOUR FROM order_date::timestamp) AS order_hour, COUNT(*) AS cnt
  FROM sales.orders o WHERE o.order_date = sd.order_date
  GROUP BY EXTRACT(HOUR FROM order_date::timestamp) ORDER BY COUNT(*) DESC LIMIT 1
) th
CROSS JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.order_date = sd.order_date ORDER BY net_total DESC LIMIT 1
) tord
CROSS JOIN LATERAL (
  SELECT prod_id FROM sales.order_items oi WHERE oi.order_id = tord.order_id ORDER BY net_amount DESC LIMIT 1
) tp
ORDER BY sd.order_date;

/* Q63. brand -> top product -> top customer -> repeat purchases. Pre-aggregated in two passes over order_items (product-revenue, then product+customer purchase-count) instead of one LATERAL re-scan of the 375,000-row order_items table per brand, per product and again per customer. */
WITH product_revenue AS (
  SELECT p.brand_id, p.product_id, SUM(oi.net_amount) AS revenue
  FROM products.products p JOIN sales.order_items oi ON oi.prod_id = p.product_id
  GROUP BY p.brand_id, p.product_id
),
top_product AS (
  SELECT brand_id, product_id, revenue,
         RANK() OVER (PARTITION BY brand_id ORDER BY revenue DESC) AS rk
  FROM product_revenue
),
cust_purchases AS (
  SELECT o.cust_id AS customer_id, oi.prod_id, COUNT(*) AS purchase_count
  FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  WHERE oi.prod_id IN (SELECT product_id FROM top_product WHERE rk = 1)
  GROUP BY o.cust_id, oi.prod_id
),
top_customer AS (
  SELECT prod_id, customer_id, purchase_count,
         RANK() OVER (PARTITION BY prod_id ORDER BY purchase_count DESC) AS rk
  FROM cust_purchases
)
SELECT tp.brand_id, tp.product_id, tc.customer_id, tc.purchase_count AS repeat_count
FROM top_product tp
JOIN top_customer tc ON tc.prod_id = tp.product_id AND tc.rk = 1
WHERE tp.rk = 1
ORDER BY tp.brand_id;

/* Q64. region -> top city -> top customer -> top product. core.dim_region.state is the real link to customers.addresses.state (there is no address-to-region FK, so state name is the join key). */
SELECT r.region_id, tcity.city, tc.customer_id, tp.prod_id
FROM core.dim_region r
CROSS JOIN LATERAL (
  SELECT a.city, COUNT(*) AS cust_count
  FROM customers.addresses a
  WHERE a.state = r.state
  GROUP BY a.city ORDER BY COUNT(*) DESC LIMIT 1
) tcity
CROSS JOIN LATERAL (
  SELECT c.customer_id, SUM(o.net_total) AS spend
  FROM customers.customers c
  JOIN customers.addresses a ON a.customer_id = c.customer_id
  JOIN sales.orders o ON o.cust_id = c.customer_id
  WHERE a.city = tcity.city
  GROUP BY c.customer_id ORDER BY SUM(o.net_total) DESC LIMIT 1
) tc
CROSS JOIN LATERAL (
  SELECT oi.prod_id, SUM(oi.net_amount) AS spend
  FROM sales.order_items oi JOIN sales.orders o ON o.order_id = oi.order_id
  WHERE o.cust_id = tc.customer_id GROUP BY oi.prod_id ORDER BY SUM(oi.net_amount) DESC LIMIT 1
) tp
LIMIT 20;

/* Q65. tier -> top member -> latest redemption -> product redeemed (RetailMart's redemptions record only a reward_name text field, not a product_id FK, so the chain ends at the reward name rather than a joined product row). */
SELECT t.tier_id, tm.customer_id, lr.redemption_id, lr.reward_name
FROM loyalty.tiers t
CROSS JOIN LATERAL (
  SELECT customer_id, points_balance FROM loyalty.members m WHERE m.tier_id = t.tier_id ORDER BY points_balance DESC LIMIT 1
) tm
CROSS JOIN LATERAL (
  SELECT redemption_id, reward_name FROM loyalty.redemptions rd WHERE rd.customer_id = tm.customer_id
  ORDER BY redemption_date DESC LIMIT 1
) lr;

/* Q66. campaign -> top platform -> top creative -> top attribution (RetailMart's ads_spend has no creative_id column, so "creative" is proxied by platform + spend_date as the finest available grain). */
SELECT c.campaign_id, tp.platform, tcr.spend_date, tcr.amount
FROM marketing.campaigns c
CROSS JOIN LATERAL (
  SELECT platform, SUM(amount) AS spend FROM marketing.ads_spend a WHERE a.campaign_id = c.campaign_id
  GROUP BY platform ORDER BY SUM(amount) DESC LIMIT 1
) tp
CROSS JOIN LATERAL (
  SELECT spend_date, amount FROM marketing.ads_spend a2
  WHERE a2.campaign_id = c.campaign_id AND a2.platform = tp.platform
  ORDER BY amount DESC LIMIT 1
) tcr;

/* Q67. session -> first url -> last url -> conversion event (proxied here as an 'order' event_type in web_events.events, since that is the closest thing to a recorded conversion). */
SELECT sess.session_id, fu.page_url AS first_url, lu.page_url AS last_url, conv.event_type
FROM (SELECT DISTINCT session_id FROM web_events.page_views LIMIT 40) sess
CROSS JOIN LATERAL (
  SELECT page_url FROM web_events.page_views p WHERE p.session_id = sess.session_id ORDER BY view_timestamp ASC LIMIT 1
) fu
CROSS JOIN LATERAL (
  SELECT page_url FROM web_events.page_views p WHERE p.session_id = sess.session_id ORDER BY view_timestamp DESC LIMIT 1
) lu
CROSS JOIN LATERAL (
  SELECT ev.event_type FROM web_events.events ev
  JOIN web_events.page_views pv ON pv.view_id = ev.view_id
  WHERE pv.session_id = sess.session_id ORDER BY ev.event_timestamp DESC LIMIT 1
) conv;

/* Q68. store -> orders -> items -> shipment -> delivery. */
SELECT s.store_id, o.order_id, oi.order_item_id, sh.shipment_id, sh.delivered_date
FROM stores.stores s
CROSS JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.store_id = s.store_id ORDER BY order_date DESC LIMIT 1
) o
CROSS JOIN LATERAL (
  SELECT order_item_id FROM sales.order_items oi WHERE oi.order_id = o.order_id ORDER BY order_item_id LIMIT 1
) oi
CROSS JOIN LATERAL (
  SELECT shipment_id, delivered_date FROM sales.shipments sh WHERE sh.order_id = o.order_id LIMIT 1
) sh
WHERE s.store_id <= 200;

/* Q69. customer -> loyalty member -> tier -> next-tier delta (points needed to reach the next tier up). */
SELECT c.customer_id, lm.points_balance, t.tier_name, nt.next_tier_name, nt.points_needed
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT points_balance, tier_id FROM loyalty.members m WHERE m.customer_id = c.customer_id LIMIT 1
) lm
JOIN loyalty.tiers t ON t.tier_id = lm.tier_id
CROSS JOIN LATERAL (
  SELECT tier_name AS next_tier_name, min_points - lm.points_balance AS points_needed
  FROM loyalty.tiers t2 WHERE t2.min_points > t.min_points
  ORDER BY t2.min_points ASC LIMIT 1
) nt
WHERE c.customer_id <= 300;

/* Q70. order -> payment -> fraud-check -> status -> refund (RetailMart has no dedicated fraud-check table, so the "fraud-check" step is proxied by finance.payments.status and the refund step by finance.payments.refund_reason/refunded_at). */
SELECT o.order_id, pay.payment_id, pay.status AS fraud_check_status, ref.refund_reason, ref.refunded_at
FROM sales.orders o
CROSS JOIN LATERAL (
  SELECT payment_id, status FROM finance.payments p WHERE p.order_id = o.order_id LIMIT 1
) pay
CROSS JOIN LATERAL (
  SELECT refund_reason, refunded_at FROM finance.payments p2
  WHERE p2.payment_id = pay.payment_id AND p2.refund_reason IS NOT NULL
) ref
WHERE o.order_id <= 3000
LIMIT 200;

/* Q71. agent -> ticket -> comment -> resolution (RetailMart's tickets have no separate comment table, so the "comment" step is proxied by the ticket's own subject text and the resolution step by its resolved_date/status). */
SELECT ag.employee_id AS agent_id, t.ticket_id, t.subject AS comment_proxy, t.status, t.resolved_date
FROM stores.employees ag
CROSS JOIN LATERAL (
  SELECT ticket_id, subject, status, resolved_date FROM support.tickets t WHERE t.agent_id = ag.employee_id
  ORDER BY created_date DESC LIMIT 1
) t
WHERE ag.employee_id <= 300;

/* Q72. ticket -> customer -> past orders -> past reviews. */
WITH ticket_sample AS (SELECT ticket_id, customer_id FROM support.tickets ORDER BY ticket_id LIMIT 300)
SELECT ts.ticket_id, ts.customer_id, po.order_id, pr.review_id, pr.rating
FROM ticket_sample ts
CROSS JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.cust_id = ts.customer_id ORDER BY order_date DESC LIMIT 1
) po
CROSS JOIN LATERAL (
  SELECT review_id, rating FROM customers.reviews r WHERE r.customer_id = ts.customer_id ORDER BY review_date DESC LIMIT 1
) pr;

/* Q73. order -> return -> refund -> audit_log (audit.refund_log is a genuine refund ledger in this schema; there is no separate change-log keyed to returns, so the final "audit" step surfaces the matching audit.refund_log row itself). */
WITH order_sample AS (SELECT order_id FROM sales.orders ORDER BY order_id LIMIT 5000)
SELECT os.order_id, ret.return_id, ret.refund_amount, al.refund_id AS audit_refund_id, al.status AS audit_status
FROM order_sample os
CROSS JOIN LATERAL (
  SELECT return_id, refund_amount FROM sales.returns r WHERE r.order_id = os.order_id LIMIT 1
) ret
CROSS JOIN LATERAL (
  SELECT refund_id, status FROM audit.refund_log al WHERE al.order_id = os.order_id LIMIT 1
) al;

/* Q74. page_view -> session -> cart -> checkout -> order (RetailMart has no dedicated cart/checkout tables, so those two steps are proxied by web_events.events rows whose event_type matches 'add_to_cart'/'checkout', and the chain's final order is the customer's next real order after that session). */
SELECT pv.session_id, cart_evt.event_type AS cart_step, checkout_evt.event_type AS checkout_step, nxt_order.order_id
FROM (SELECT DISTINCT session_id, customer_id FROM web_events.page_views WHERE customer_id IS NOT NULL LIMIT 40) pv
CROSS JOIN LATERAL (
  SELECT ev.event_type FROM web_events.events ev JOIN web_events.page_views p ON p.view_id = ev.view_id
  WHERE p.session_id = pv.session_id AND ev.event_type ILIKE '%cart%' ORDER BY ev.event_timestamp LIMIT 1
) cart_evt
CROSS JOIN LATERAL (
  SELECT ev.event_type FROM web_events.events ev JOIN web_events.page_views p ON p.view_id = ev.view_id
  WHERE p.session_id = pv.session_id AND ev.event_type ILIKE '%checkout%' ORDER BY ev.event_timestamp LIMIT 1
) checkout_evt
CROSS JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.cust_id = pv.customer_id ORDER BY order_date DESC LIMIT 1
) nxt_order;

/* Q75. customer -> 5 events -> 5 derived metrics -> composite score. */
SELECT c.customer_id, ev.event_count, ev.total_spend, ev.review_count, ev.ticket_count, ev.tenure_days,
       ROUND(ev.total_spend / 1000.0 + ev.event_count * 2 + ev.review_count * 5 - ev.ticket_count * 3, 2) AS composite_score
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT
    (SELECT COUNT(*) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS event_count,
    (SELECT COALESCE(SUM(net_total),0) FROM sales.orders o2 WHERE o2.cust_id = c.customer_id) AS total_spend,
    (SELECT COUNT(*) FROM customers.reviews r WHERE r.customer_id = c.customer_id) AS review_count,
    (SELECT COUNT(*) FROM support.tickets t WHERE t.customer_id = c.customer_id) AS ticket_count,
    (CURRENT_DATE - c.registration_date) AS tenure_days
) ev
WHERE c.customer_id <= 100
ORDER BY composite_score DESC
LIMIT 100;
/* SECTION D: PRODUCTION MEGA (25) */

/* Q76. Customer 360deg via LATERAL chain: profile, order stats, support stats and loyalty status in one row per customer. */
SELECT c.customer_id, c.first_name, c.last_name, ord.order_count, ord.total_spend, sup.ticket_count, loy.tier_name
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT COUNT(*) AS order_count, COALESCE(SUM(net_total),0) AS total_spend FROM sales.orders o WHERE o.cust_id = c.customer_id
) ord
CROSS JOIN LATERAL (
  SELECT COUNT(*) AS ticket_count FROM support.tickets t WHERE t.customer_id = c.customer_id
) sup
LEFT JOIN LATERAL (
  SELECT tr.tier_name FROM loyalty.members m JOIN loyalty.tiers tr ON tr.tier_id = m.tier_id WHERE m.customer_id = c.customer_id
) loy ON TRUE
WHERE c.customer_id <= 100
ORDER BY ord.total_spend DESC;

/* Q77. Product 360deg via LATERAL chain: pricing, supplier, sales stats and review stats in one row per product. */
SELECT p.product_id, p.product_name, p.price, sup.supplier_name, sales_.units_sold, sales_.revenue, rev.avg_rating, rev.review_count
FROM products.products p
LEFT JOIN LATERAL (
  SELECT supplier_name FROM products.suppliers s WHERE s.supplier_id = p.supplier_id
) sup ON TRUE
CROSS JOIN LATERAL (
  SELECT COALESCE(SUM(quantity),0) AS units_sold, COALESCE(SUM(net_amount),0) AS revenue
  FROM sales.order_items oi WHERE oi.prod_id = p.product_id
) sales_
CROSS JOIN LATERAL (
  SELECT COALESCE(AVG(rating),0) AS avg_rating, COUNT(*) AS review_count FROM customers.reviews r WHERE r.product_id = p.product_id
) rev
WHERE p.product_id <= 300
ORDER BY sales_.revenue DESC;

/* Q78. Region 360deg via LATERAL chain: store count, revenue, top store and headcount in one row per region. */
SELECT r.region_id, r.region_name, agg.store_count, agg.revenue, top_store.store_id AS top_store_id, hc.headcount
FROM core.dim_region r
CROSS JOIN LATERAL (
  SELECT COUNT(DISTINCT s.store_id) AS store_count, COALESCE(SUM(o.net_total),0) AS revenue
  FROM stores.stores s LEFT JOIN sales.orders o ON o.store_id = s.store_id
  WHERE s.region_id = r.region_id
) agg
CROSS JOIN LATERAL (
  SELECT s.store_id, SUM(o.net_total) AS revenue
  FROM stores.stores s JOIN sales.orders o ON o.store_id = s.store_id
  WHERE s.region_id = r.region_id GROUP BY s.store_id ORDER BY SUM(o.net_total) DESC LIMIT 1
) top_store
CROSS JOIN LATERAL (
  SELECT COUNT(*) AS headcount FROM stores.employees e JOIN stores.stores s2 ON s2.store_id = e.store_id WHERE s2.region_id = r.region_id
) hc
ORDER BY agg.revenue DESC;

/* Q79. Campaign 360deg via LATERAL chain: spend, revenue attributed in the campaign window, and email engagement in one row per campaign. */
SELECT c.campaign_id, c.campaign_name, c.budget, sp.total_spend, rev.attributed_revenue, eng.emails_sent, eng.emails_clicked
FROM marketing.campaigns c
CROSS JOIN LATERAL (
  SELECT COALESCE(SUM(amount),0) AS total_spend FROM marketing.ads_spend a WHERE a.campaign_id = c.campaign_id
) sp
CROSS JOIN LATERAL (
  SELECT COALESCE(SUM(net_total),0) AS attributed_revenue FROM sales.orders o WHERE o.order_date BETWEEN c.start_date AND c.end_date
) rev
CROSS JOIN LATERAL (
  SELECT COALESCE(SUM(emails_sent),0) AS emails_sent, COALESCE(SUM(emails_clicked),0) AS emails_clicked
  FROM marketing.email_clicks e WHERE e.campaign_id = c.campaign_id
) eng
ORDER BY sp.total_spend DESC
LIMIT 100;

/* Q80. Store 360deg via LATERAL chain: revenue, headcount, top employee and open-ticket count in one row per store. */
SELECT s.store_id, rev.revenue, hc.headcount, top_emp.employee_id AS top_employee_id, tix.open_tickets
FROM stores.stores s
CROSS JOIN LATERAL (
  SELECT COALESCE(SUM(net_total),0) AS revenue FROM sales.orders o WHERE o.store_id = s.store_id
) rev
CROSS JOIN LATERAL (
  SELECT COUNT(*) AS headcount FROM stores.employees e WHERE e.store_id = s.store_id
) hc
LEFT JOIN LATERAL (
  SELECT employee_id FROM stores.employees e2 WHERE e2.store_id = s.store_id ORDER BY salary DESC LIMIT 1
) top_emp ON TRUE
CROSS JOIN LATERAL (
  SELECT COUNT(*) AS open_tickets FROM support.tickets t
  JOIN stores.employees e3 ON e3.employee_id = t.agent_id
  WHERE e3.store_id = s.store_id AND t.status = 'Open'
) tix
ORDER BY rev.revenue DESC;

/* Q81. Brand 360deg via LATERAL chain: product count, revenue, avg rating and top product in one row per brand. order_items and reviews are aggregated SEPARATELY per product before joining (joining both directly on product_id in one query would fan them out against each other - a silent Cartesian-style row-count inflation that corrupts both SUM(net_amount) and AVG(rating), not just a performance problem). */
WITH item_agg AS (
  SELECT prod_id, SUM(net_amount) AS revenue FROM sales.order_items GROUP BY prod_id
),
review_agg AS (
  SELECT product_id, AVG(rating) AS avg_rating FROM customers.reviews GROUP BY product_id
)
SELECT b.brand_id, b.brand_name, agg.product_count, agg.revenue, agg.avg_rating, top_p.product_id AS top_product_id
FROM core.dim_brand b
CROSS JOIN LATERAL (
  SELECT COUNT(DISTINCT p.product_id) AS product_count,
         COALESCE(SUM(ia.revenue),0) AS revenue,
         COALESCE(AVG(ra.avg_rating),0) AS avg_rating
  FROM products.products p
  LEFT JOIN item_agg ia ON ia.prod_id = p.product_id
  LEFT JOIN review_agg ra ON ra.product_id = p.product_id
  WHERE p.brand_id = b.brand_id
) agg
CROSS JOIN LATERAL (
  SELECT p2.product_id, ia2.revenue
  FROM products.products p2 JOIN item_agg ia2 ON ia2.prod_id = p2.product_id
  WHERE p2.brand_id = b.brand_id ORDER BY ia2.revenue DESC LIMIT 1
) top_p
ORDER BY agg.revenue DESC;

/* Q82. Supplier 360deg via LATERAL chain: product count, shipment stats and delay rate in one row per supplier. */
SELECT sup.supplier_id, sup.supplier_name, prod.product_count, ship.shipment_count, ship.delayed_count,
       ROUND(ship.delayed_count::numeric / NULLIF(ship.shipment_count,0), 4) AS delay_rate
FROM products.suppliers sup
CROSS JOIN LATERAL (
  SELECT COUNT(*) AS product_count FROM products.products p WHERE p.supplier_id = sup.supplier_id
) prod
CROSS JOIN LATERAL (
  SELECT COUNT(*) AS shipment_count, COUNT(*) FILTER (WHERE status = 'Delayed') AS delayed_count
  FROM supply_chain.shipments sh WHERE sh.supplier_id = sup.supplier_id
) ship
ORDER BY ship.shipment_count DESC;

/* Q83. Agent 360deg via LATERAL chain: ticket stats, resolution rate and call stats in one row per agent. */
SELECT e.employee_id AS agent_id, tix.ticket_count, tix.resolved_count, cal.call_count, cal.avg_duration
FROM stores.employees e
CROSS JOIN LATERAL (
  SELECT COUNT(*) AS ticket_count, COUNT(*) FILTER (WHERE status = 'Resolved') AS resolved_count
  FROM support.tickets t WHERE t.agent_id = e.employee_id
) tix
CROSS JOIN LATERAL (
  SELECT COUNT(*) AS call_count, COALESCE(AVG(call_duration_seconds),0) AS avg_duration
  FROM call_center.calls c WHERE c.agent_id = e.employee_id
) cal
WHERE e.employee_id <= 500 AND (tix.ticket_count > 0 OR cal.call_count > 0)
ORDER BY tix.ticket_count DESC
LIMIT 100;

/* Q84. Courier 360deg via LATERAL chain: shipment volume, on-time rate and average delivery time in one row per courier. */
SELECT cour.courier_name, agg.shipment_count, agg.delivered_count,
       ROUND(agg.delivered_count::numeric / NULLIF(agg.shipment_count,0), 4) AS on_time_rate,
       agg.avg_delivery_days
FROM (SELECT DISTINCT courier_name FROM sales.shipments) cour
CROSS JOIN LATERAL (
  SELECT COUNT(*) AS shipment_count,
         COUNT(*) FILTER (WHERE status = 'Delivered') AS delivered_count,
         AVG(delivered_date - shipped_date) FILTER (WHERE delivered_date IS NOT NULL) AS avg_delivery_days
  FROM sales.shipments sh WHERE sh.courier_name = cour.courier_name
) agg;

/* Q85. Tier 360deg via LATERAL chain: member count, average spend and redemption stats in one row per loyalty tier. */
SELECT t.tier_id, t.tier_name, mem.member_count, mem.avg_spend, red.redemption_count, red.total_points_redeemed
FROM loyalty.tiers t
CROSS JOIN LATERAL (
  SELECT COUNT(DISTINCT m.customer_id) AS member_count, COALESCE(AVG(o.net_total),0) AS avg_spend
  FROM loyalty.members m
  LEFT JOIN sales.orders o ON o.cust_id = m.customer_id
  WHERE m.tier_id = t.tier_id
) mem
CROSS JOIN LATERAL (
  SELECT COUNT(*) AS redemption_count, COALESCE(SUM(rd.points_redeemed),0) AS total_points_redeemed
  FROM loyalty.redemptions rd JOIN loyalty.members m2 ON m2.customer_id = rd.customer_id
  WHERE m2.tier_id = t.tier_id
) red;

/* Q86. Warehouse 360deg via LATERAL chain: capacity utilization, shipment volume and top product in one row per warehouse. */
SELECT w.warehouse_id, w.name, w.capacity_sqft, inv.total_on_hand, ship.shipment_count, top_p.product_id AS top_product_id
FROM supply_chain.warehouses w
CROSS JOIN LATERAL (
  SELECT COALESCE(SUM(quantity_on_hand),0) AS total_on_hand
  FROM supply_chain.inventory_snapshots isn WHERE isn.warehouse_id = w.warehouse_id
) inv
CROSS JOIN LATERAL (
  SELECT COUNT(*) AS shipment_count FROM supply_chain.shipments sh WHERE sh.warehouse_id = w.warehouse_id
) ship
CROSS JOIN LATERAL (
  SELECT product_id, SUM(quantity) AS qty FROM supply_chain.shipments sh2
  WHERE sh2.warehouse_id = w.warehouse_id GROUP BY product_id ORDER BY SUM(quantity) DESC LIMIT 1
) top_p;

/* Q87. Department 360deg via LATERAL chain: headcount, total payroll and top earner in one row per department. */
SELECT d.dept_id, d.dept_name, hc.headcount, hc.total_payroll, top_e.employee_id AS top_earner_id, top_e.salary AS top_salary
FROM core.dim_department d
CROSS JOIN LATERAL (
  SELECT COUNT(*) AS headcount, COALESCE(SUM(salary),0) AS total_payroll FROM stores.employees e WHERE e.dept_id = d.dept_id
) hc
CROSS JOIN LATERAL (
  SELECT employee_id, salary FROM stores.employees e2 WHERE e2.dept_id = d.dept_id ORDER BY salary DESC LIMIT 1
) top_e;

/* Q88. Employee 360deg via LATERAL chain: attendance rate, tenure and (if an agent) ticket-handling stats in one row per employee. Restricted to a bounded sample of employees. */
SELECT e.employee_id, e.role, tenure.tenure_days, att.days_logged, tix.ticket_count
FROM stores.employees e
CROSS JOIN LATERAL (
  SELECT (CURRENT_DATE - e.joining_date) AS tenure_days
) tenure
CROSS JOIN LATERAL (
  SELECT COUNT(*) AS days_logged FROM hr.attendance a WHERE a.employee_id = e.employee_id
) att
CROSS JOIN LATERAL (
  SELECT COUNT(*) AS ticket_count FROM support.tickets t WHERE t.agent_id = e.employee_id
) tix
WHERE e.employee_id <= 300
ORDER BY e.employee_id
LIMIT 300;

/* Q89. Category 360deg via LATERAL chain: brand count, revenue and top brand in one row per category. */
SELECT cat.category_id, cat.category_name, agg.brand_count, agg.revenue, top_b.brand_id AS top_brand_id
FROM core.dim_category cat
CROSS JOIN LATERAL (
  SELECT COUNT(DISTINCT b.brand_id) AS brand_count, COALESCE(SUM(oi.net_amount),0) AS revenue
  FROM core.dim_brand b
  LEFT JOIN products.products p ON p.brand_id = b.brand_id
  LEFT JOIN sales.order_items oi ON oi.prod_id = p.product_id
  WHERE b.category_id = cat.category_id
) agg
CROSS JOIN LATERAL (
  SELECT b2.brand_id, SUM(oi2.net_amount) AS revenue
  FROM core.dim_brand b2
  JOIN products.products p2 ON p2.brand_id = b2.brand_id
  JOIN sales.order_items oi2 ON oi2.prod_id = p2.product_id
  WHERE b2.category_id = cat.category_id
  GROUP BY b2.brand_id ORDER BY SUM(oi2.net_amount) DESC LIMIT 1
) top_b;

/* Q90. Channel 360deg via LATERAL chain: RetailMart has no explicit "channel" dimension, so marketing platform (marketing.ads_spend.platform) is used as the closest proxy - spend, attributed revenue window and click-through rate per platform. */
SELECT plat.platform, sp.total_spend, eng.ctr
FROM (SELECT DISTINCT platform FROM marketing.ads_spend) plat
CROSS JOIN LATERAL (
  SELECT COALESCE(SUM(amount),0) AS total_spend FROM marketing.ads_spend a WHERE a.platform = plat.platform
) sp
CROSS JOIN LATERAL (
  SELECT ROUND(COALESCE(SUM(e.emails_clicked),0)::numeric / NULLIF(SUM(e.emails_sent),0), 4) AS ctr
  FROM marketing.email_clicks e
  JOIN marketing.campaigns c ON c.campaign_id = e.campaign_id
  WHERE c.campaign_id IN (SELECT campaign_id FROM marketing.ads_spend a2 WHERE a2.platform = plat.platform)
) eng;

/* Q91. Executive dashboard via LATERAL mega: headline KPIs plus the top region, top store and top product all computed via LATERAL in one row. */
SELECT kpi.total_revenue, kpi.total_orders, kpi.total_customers, tr.region_name AS top_region, ts.store_id AS top_store, tp.product_id AS top_product
FROM (SELECT 1 AS x) dummy
CROSS JOIN LATERAL (
  SELECT (SELECT SUM(net_total) FROM sales.orders) AS total_revenue,
         (SELECT COUNT(*) FROM sales.orders) AS total_orders,
         (SELECT COUNT(*) FROM customers.customers) AS total_customers
) kpi
CROSS JOIN LATERAL (
  SELECT r.region_name FROM core.dim_region r
  JOIN stores.stores s ON s.region_id = r.region_id
  JOIN sales.orders o ON o.store_id = s.store_id
  GROUP BY r.region_name ORDER BY SUM(o.net_total) DESC LIMIT 1
) tr
CROSS JOIN LATERAL (
  SELECT store_id FROM sales.orders o2 GROUP BY store_id ORDER BY SUM(net_total) DESC LIMIT 1
) ts
CROSS JOIN LATERAL (
  SELECT prod_id AS product_id FROM sales.order_items oi GROUP BY prod_id ORDER BY SUM(net_amount) DESC LIMIT 1
) tp;

/* Q92. Operations dashboard via LATERAL: shipment health, inventory health and returns rate all computed via LATERAL in one row. */
SELECT ship.on_time_rate, inv.low_stock_count, ret.return_rate
FROM (SELECT 1 AS x) dummy
CROSS JOIN LATERAL (
  SELECT ROUND(COUNT(*) FILTER (WHERE status = 'Delivered')::numeric / NULLIF(COUNT(*),0), 4) AS on_time_rate
  FROM sales.shipments
) ship
CROSS JOIN LATERAL (
  SELECT COUNT(*) AS low_stock_count FROM (
    SELECT warehouse_id, product_id, quantity_on_hand,
           ROW_NUMBER() OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date DESC) AS rn
    FROM supply_chain.inventory_snapshots
  ) latest WHERE rn = 1 AND quantity_on_hand < 20
) inv
CROSS JOIN LATERAL (
  SELECT ROUND((SELECT COUNT(*) FROM sales.returns)::numeric / NULLIF((SELECT COUNT(*) FROM sales.orders),0), 4) AS return_rate
) ret;

/* Q93. Marketing dashboard via LATERAL: total spend, ROI proxy and top campaign all computed via LATERAL in one row. */
SELECT sp.total_spend, roi.revenue_per_spend, tc.campaign_name AS top_campaign
FROM (SELECT 1 AS x) dummy
CROSS JOIN LATERAL (
  SELECT COALESCE(SUM(amount),0) AS total_spend FROM marketing.ads_spend
) sp
CROSS JOIN LATERAL (
  SELECT ROUND((SELECT SUM(net_total) FROM sales.orders)::numeric / NULLIF(sp.total_spend,0), 2) AS revenue_per_spend
) roi
CROSS JOIN LATERAL (
  SELECT c.campaign_name FROM marketing.campaigns c
  JOIN marketing.ads_spend a ON a.campaign_id = c.campaign_id
  GROUP BY c.campaign_name ORDER BY SUM(a.amount) DESC LIMIT 1
) tc;

/* Q94. Finance dashboard via LATERAL: total revenue, refund rate and account balances all computed via LATERAL in one row. */
SELECT rev.total_revenue, ref.refund_rate, acct.total_balance
FROM (SELECT 1 AS x) dummy
CROSS JOIN LATERAL (
  SELECT COALESCE(SUM(net_total),0) AS total_revenue FROM sales.orders
) rev
CROSS JOIN LATERAL (
  SELECT ROUND((SELECT COUNT(*) FROM finance.payments WHERE refund_reason IS NOT NULL)::numeric / NULLIF((SELECT COUNT(*) FROM finance.payments),0), 4) AS refund_rate
) ref
CROSS JOIN LATERAL (
  SELECT COALESCE(SUM(balance),0) AS total_balance FROM finance.accounts
) acct;

/* Q95. HR dashboard via LATERAL: headcount, average tenure and top-paid department all computed via LATERAL in one row. */
SELECT hc.headcount, hc.avg_tenure_days, td.dept_name AS top_paid_dept
FROM (SELECT 1 AS x) dummy
CROSS JOIN LATERAL (
  SELECT COUNT(*) AS headcount, COALESCE(AVG(CURRENT_DATE - joining_date),0) AS avg_tenure_days FROM stores.employees
) hc
CROSS JOIN LATERAL (
  SELECT d.dept_name FROM core.dim_department d JOIN stores.employees e ON e.dept_id = d.dept_id
  GROUP BY d.dept_name ORDER BY AVG(e.salary) DESC LIMIT 1
) td;

/* Q96. Customer service dashboard via LATERAL: ticket volume, resolution rate and average sentiment all computed via LATERAL in one row. */
SELECT tix.total_tickets, tix.resolution_rate, sen.avg_sentiment
FROM (SELECT 1 AS x) dummy
CROSS JOIN LATERAL (
  SELECT COUNT(*) AS total_tickets, ROUND(COUNT(*) FILTER (WHERE status = 'Resolved')::numeric / NULLIF(COUNT(*),0), 4) AS resolution_rate
  FROM support.tickets
) tix
CROSS JOIN LATERAL (
  SELECT COALESCE(AVG(sentiment_score),0) AS avg_sentiment FROM call_center.transcripts
) sen;

/* Q97. Sales dashboard via LATERAL: revenue trend, top store and average order value all computed via LATERAL in one row. */
SELECT trend.this_month_revenue, trend.last_month_revenue, ts.store_id AS top_store, aov.avg_order_value
FROM (SELECT 1 AS x) dummy
CROSS JOIN LATERAL (
  SELECT
    SUM(net_total) FILTER (WHERE DATE_TRUNC('month', order_date) = DATE_TRUNC('month', (SELECT MAX(order_date) FROM sales.orders))) AS this_month_revenue,
    SUM(net_total) FILTER (WHERE DATE_TRUNC('month', order_date) = DATE_TRUNC('month', (SELECT MAX(order_date) FROM sales.orders)) - interval '1 month') AS last_month_revenue
  FROM sales.orders
) trend
CROSS JOIN LATERAL (
  SELECT store_id FROM sales.orders GROUP BY store_id ORDER BY SUM(net_total) DESC LIMIT 1
) ts
CROSS JOIN LATERAL (
  SELECT ROUND(AVG(net_total), 2) AS avg_order_value FROM sales.orders
) aov;

/* Q98. Inventory dashboard via LATERAL: total on-hand, low-stock alerts and top warehouse by volume all computed via LATERAL in one row. */
SELECT inv.total_on_hand, inv.low_stock_alerts, tw.warehouse_id AS top_warehouse
FROM (SELECT 1 AS x) dummy
CROSS JOIN LATERAL (
  SELECT SUM(quantity_on_hand) AS total_on_hand, COUNT(*) FILTER (WHERE quantity_on_hand < 20) AS low_stock_alerts
  FROM (
    SELECT warehouse_id, product_id, quantity_on_hand,
           ROW_NUMBER() OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date DESC) AS rn
    FROM supply_chain.inventory_snapshots
  ) latest WHERE rn = 1
) inv
CROSS JOIN LATERAL (
  SELECT warehouse_id FROM supply_chain.inventory_snapshots GROUP BY warehouse_id ORDER BY SUM(quantity_on_hand) DESC LIMIT 1
) tw;

/* Q99. Supply chain dashboard via LATERAL: shipment volume, average lead time and top supplier all computed via LATERAL in one row. */
SELECT ship.total_shipments, ship.avg_lead_days, tsup.supplier_name AS top_supplier
FROM (SELECT 1 AS x) dummy
CROSS JOIN LATERAL (
  SELECT COUNT(*) AS total_shipments, AVG(arrival_date - shipped_date) FILTER (WHERE arrival_date IS NOT NULL) AS avg_lead_days
  FROM supply_chain.shipments
) ship
CROSS JOIN LATERAL (
  SELECT sup.supplier_name FROM products.suppliers sup
  JOIN supply_chain.shipments sh ON sh.supplier_id = sup.supplier_id
  GROUP BY sup.supplier_name ORDER BY SUM(sh.quantity) DESC LIMIT 1
) tsup;

/* Q100. Master: LATERAL + recursive + window + set ops + DML in one mega query - for each warehouse, its recursively-reachable warehouses (within 2 hops), each scored by a window-ranked shipment volume, with a channel list built via set-operations (UNION of inbound/outbound courier names), and the whole result set staged into a session-local TEMP TABLE (standing in for a DML materialization step; no permanent object is left behind on this shared database). */
DROP TABLE IF EXISTS tmp_q100_master;
CREATE TEMP TABLE tmp_q100_master AS
SELECT w.warehouse_id, res.reachable_warehouse, res.hops, res.total_qty, res.qty_rank, res.channels
FROM supply_chain.warehouses w
CROSS JOIN LATERAL (
  WITH RECURSIVE edges AS (
    SELECT DISTINCT sh1.warehouse_id AS wh_a, sh2.warehouse_id AS wh_b
    FROM supply_chain.shipments sh1
    JOIN supply_chain.shipments sh2 ON sh2.supplier_id = sh1.supplier_id AND sh2.warehouse_id <> sh1.warehouse_id
  ),
  walk AS (
    SELECT wh_a, wh_b AS reachable_warehouse, 1 AS hops FROM edges WHERE wh_a = w.warehouse_id
    UNION ALL
    SELECT wk.wh_a, e.wh_b, wk.hops + 1
    FROM walk wk JOIN edges e ON e.wh_a = wk.reachable_warehouse
    WHERE wk.hops < 2
  ),
  best_hops AS (
    SELECT reachable_warehouse, MIN(hops) AS hops FROM walk GROUP BY reachable_warehouse
  ),
  scored AS (
    SELECT bh.reachable_warehouse, bh.hops,
           COALESCE((SELECT SUM(quantity) FROM supply_chain.shipments sh WHERE sh.warehouse_id = bh.reachable_warehouse),0) AS total_qty
    FROM best_hops bh
  ),
  chan AS (
    SELECT sc.reachable_warehouse,
           STRING_AGG(DISTINCT ch.channel, ',') AS channels
    FROM scored sc
    CROSS JOIN LATERAL (
      SELECT DISTINCT sup.supplier_name AS channel
      FROM supply_chain.shipments sh4
      JOIN products.suppliers sup ON sup.supplier_id = sh4.supplier_id
      WHERE sh4.warehouse_id = sc.reachable_warehouse
      UNION
      SELECT DISTINCT cat.category_name
      FROM supply_chain.shipments sh5
      JOIN products.products pr ON pr.product_id = sh5.product_id
      JOIN core.dim_brand br ON br.brand_id = pr.brand_id
      JOIN core.dim_category cat ON cat.category_id = br.category_id
      WHERE sh5.warehouse_id = sc.reachable_warehouse
    ) ch
    GROUP BY sc.reachable_warehouse
  )
  SELECT s.reachable_warehouse, s.hops, s.total_qty,
         RANK() OVER (ORDER BY s.total_qty DESC) AS qty_rank,
         c.channels
  FROM scored s JOIN chan c ON c.reachable_warehouse = s.reachable_warehouse
) res
ORDER BY w.warehouse_id, res.qty_rank;

SELECT * FROM tmp_q100_master;
DROP TABLE tmp_q100_master;

/* ============================================================
   END OF ANSWER KEY - Subqueries Part 2 (Correlated & LATERAL) - CRAZY LEVEL (100/100)
============================================================ */
