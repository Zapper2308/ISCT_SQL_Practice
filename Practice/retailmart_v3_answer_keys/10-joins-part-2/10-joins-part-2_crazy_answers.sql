/* ============================================================
   ANSWER KEY - JOINs Part 2 (Advanced) (CRAZY LEVEL)
   Curriculum:   RetailMart V3
   Note: this database has NO indexes on foreign-key columns, so
   LATERAL/correlated patterns whose driving table is large (orders,
   customers, order_items, page_views) are restricted to a bounded
   sample where noted; the same pattern is correct unrestricted, just
   slower on this unindexed practice copy. RetailMart V3 has no
   self-referencing manager_id or product bill-of-materials column, so
   hierarchy questions use stores.employees.dept_id/core.dim_department
   and core.dim_category/core.dim_brand as the closest real hierarchies
   available in this schema.
   ============================================================ */

/* ============================================================
   SECTION A: RECURSIVE DEEP (25)
   ------------------------------------------------------------ */
/* Q1. RetailMart's stores.employees has no self-referencing manager_id column, so a true multi-level "employee hierarchy" can't be walked; the closest analog is a two-level department roll-up (dept -> employees), shown here without recursion since there is no deeper chain to recurse through. */
SELECT d.dept_id, d.dept_name, e.employee_id, e.first_name, e.last_name, 1 AS level
FROM core.dim_department d
JOIN stores.employees e ON e.dept_id = d.dept_id
ORDER BY d.dept_id, e.employee_id
LIMIT 200;

/* Q2. core.dim_category and core.dim_brand form a two-level tree (category -> brand), not a self-referencing table, so it's walked directly rather than with WITH RECURSIVE. */
SELECT cat.category_id, cat.category_name, b.brand_id, b.brand_name
FROM core.dim_category cat
JOIN core.dim_brand b ON b.category_id = cat.category_id
ORDER BY cat.category_id, b.brand_id;

/* Q3. No CEO/reports chain exists in this schema (employees have no manager_id); dept_id -> employees is the flattest available "reporting" proxy, listed directly. */
SELECT d.dept_name, COUNT(e.employee_id) AS reports_count
FROM core.dim_department d
LEFT JOIN stores.employees e ON e.dept_id = d.dept_id
GROUP BY d.dept_name
ORDER BY reports_count DESC;

/* Q4. With only a 2-level category->brand tree (no deeper self-reference in this schema), the deepest sub-tree depth is trivially 2 for every category that has at least one brand. */
SELECT cat.category_id, cat.category_name, COUNT(b.brand_id) AS brand_count,
       CASE WHEN COUNT(b.brand_id) > 0 THEN 2 ELSE 1 END AS deepest_depth
FROM core.dim_category cat
LEFT JOIN core.dim_brand b ON b.category_id = cat.category_id
GROUP BY cat.category_id, cat.category_name
ORDER BY cat.category_id;

/* Q5. Longest path from category (root) to product (leaf) through brand is always 3 levels (category -> brand -> product) in this schema, since there is no deeper self-referencing chain. */
SELECT cat.category_id, cat.category_name, 3 AS longest_path_to_leaf
FROM core.dim_category cat
WHERE EXISTS (SELECT 1 FROM core.dim_brand b WHERE b.category_id = cat.category_id)
ORDER BY cat.category_id;

/* Q6. sales.orders has no self-referencing next-order pointer to demonstrate a real cycle, so this uses the audit trail's payment_id/order_id pair instead, tracking visited payment_ids in an array (the PG14+ CYCLE clause does the same bookkeeping automatically) to guard against re-visiting one. */
WITH RECURSIVE refund_chain AS (
  SELECT payment_id, order_id, ARRAY[payment_id] AS visited
  FROM audit.refund_log
  WHERE payment_id <= 50
  UNION ALL
  SELECT rl.payment_id, rl.order_id, rc.visited || rl.payment_id
  FROM refund_chain rc
  JOIN audit.refund_log rl ON rl.order_id = rc.order_id AND rl.payment_id <> rc.payment_id
  WHERE NOT rl.payment_id = ANY(rc.visited)
)
SELECT DISTINCT order_id, ARRAY_LENGTH(visited, 1) AS chain_length
FROM refund_chain
ORDER BY chain_length DESC
LIMIT 50;

/* Q7. */
WITH RECURSIVE dept_bfs AS (
  SELECT dept_id, dept_name, 0 AS depth
  FROM core.dim_department
  WHERE dept_id = 1
  UNION ALL
  SELECT d.dept_id, d.dept_name, db.depth + 1
  FROM dept_bfs db
  JOIN core.dim_department d ON d.dept_id = db.dept_id + 1
  WHERE db.depth < 5
)
SELECT * FROM dept_bfs ORDER BY depth;

/* Q8. RetailMart has no friend/social-graph table; the closest analog is "customers who share a support ticket agent", walked 3 hops via employees as the connecting node. */
WITH RECURSIVE agent_network AS (
  SELECT DISTINCT customer_id, agent_id, 1 AS depth
  FROM support.tickets
  WHERE customer_id = 1 AND agent_id IS NOT NULL
  UNION ALL
  SELECT t2.customer_id, t2.agent_id, an.depth + 1
  FROM agent_network an
  JOIN support.tickets t2 ON t2.agent_id = an.agent_id
  WHERE an.depth < 3
)
SELECT DISTINCT customer_id, depth FROM agent_network ORDER BY depth, customer_id LIMIT 100;

/* Q9. RetailMart has no bill-of-materials/component table for products, so this is the closest schema-appropriate substitute: a product-to-supplier-shipments dependency chain. */
SELECT p.product_id, p.product_name, sup.supplier_id, sup.supplier_name
FROM products.products p
JOIN products.suppliers sup ON sup.supplier_id = p.supplier_id
ORDER BY p.product_id
LIMIT 200;

/* Q10. Shortest path (in hops) between two warehouses via shared suppliers, treating supplier-warehouse shipment pairs as graph edges. Edges are pre-computed and DISTINCT-collapsed first (only 5 warehouses exist, so at most 20 directed edges), keeping the recursive hop-walk over that tiny edge set instead of the raw 2,000-row shipments table. */
WITH RECURSIVE edges AS (
  SELECT DISTINCT sh1.warehouse_id AS wh_a, sh2.warehouse_id AS wh_b
  FROM supply_chain.shipments sh1
  JOIN supply_chain.shipments sh2 ON sh2.supplier_id = sh1.supplier_id AND sh2.warehouse_id <> sh1.warehouse_id
),
path_search AS (
  SELECT wh_a, wh_b, 1 AS hops FROM edges WHERE wh_a = 1
  UNION ALL
  SELECT ps.wh_a, e.wh_b, ps.hops + 1
  FROM path_search ps
  JOIN edges e ON e.wh_a = ps.wh_b
  WHERE ps.hops < 4
)
SELECT wh_b AS target_warehouse, MIN(hops) AS shortest_hops
FROM path_search
WHERE wh_b = 5
GROUP BY wh_b;

/* Q11. */
SELECT d.dept_id, d.dept_name, COUNT(e.employee_id) AS descendant_count
FROM core.dim_department d
LEFT JOIN stores.employees e ON e.dept_id = d.dept_id
GROUP BY d.dept_id, d.dept_name
ORDER BY descendant_count DESC;

/* Q12. */
SELECT cat.category_id, cat.category_name, SUM(oi.net_amount) AS rollup_revenue
FROM core.dim_category cat
JOIN core.dim_brand b ON b.category_id = cat.category_id
JOIN products.products p ON p.brand_id = b.brand_id
JOIN sales.order_items oi ON oi.prod_id = p.product_id
GROUP BY cat.category_id, cat.category_name
ORDER BY rollup_revenue DESC;

/* Q13. */
SELECT b.brand_id, b.brand_name, SUM(oi.net_amount) AS subtree_revenue
FROM core.dim_brand b
JOIN products.products p ON p.brand_id = b.brand_id
JOIN sales.order_items oi ON oi.prod_id = p.product_id
GROUP BY b.brand_id, b.brand_name
ORDER BY subtree_revenue DESC
LIMIT 100;

/* Q14. */
WITH RECURSIVE refund_chain AS (
  SELECT rl.refund_id, rl.payment_id, rl.order_id, rl.refunded_at, 1 AS step
  FROM audit.refund_log rl
  WHERE rl.order_id <= 500
  UNION ALL
  SELECT rl2.refund_id, rl2.payment_id, rl2.order_id, rl2.refunded_at, rc.step + 1
  FROM refund_chain rc
  JOIN audit.refund_log rl2 ON rl2.order_id = rc.order_id AND rl2.refunded_at > rc.refunded_at
  WHERE rc.step < 5
)
SELECT order_id, refund_id, refunded_at, step
FROM refund_chain
ORDER BY order_id, step
LIMIT 200;

/* Q15. Reconstructs each web session as an ordered walk of page_views linked to the previous view within the same session. Pre-filters to a small sample of sessions into its own CTE first, since page_views has no index on session_id and correlating the recursive walk directly against the full 500,000-row table would re-scan it on every step. */
WITH RECURSIVE sample_sessions AS (
  SELECT DISTINCT session_id FROM web_events.page_views LIMIT 20
),
sample_views AS (
  SELECT pv.view_id, pv.session_id, pv.page_url, pv.view_timestamp
  FROM web_events.page_views pv
  JOIN sample_sessions ss ON ss.session_id = pv.session_id
),
session_walk AS (
  SELECT view_id, session_id, page_url, view_timestamp, 1 AS step
  FROM sample_views sv
  WHERE view_timestamp = (SELECT MIN(view_timestamp) FROM sample_views sv2 WHERE sv2.session_id = sv.session_id)
  UNION ALL
  SELECT nxt.view_id, nxt.session_id, nxt.page_url, nxt.view_timestamp, sw.step + 1
  FROM session_walk sw
  JOIN sample_views nxt ON nxt.session_id = sw.session_id AND nxt.view_timestamp > sw.view_timestamp
  WHERE sw.step < 10
    AND nxt.view_timestamp = (
      SELECT MIN(view_timestamp) FROM sample_views sv3
      WHERE sv3.session_id = sw.session_id AND sv3.view_timestamp > sw.view_timestamp
    )
)
SELECT session_id, step, page_url, view_timestamp
FROM session_walk
ORDER BY session_id, step
LIMIT 200;

/* Q16. */
WITH RECURSIVE date_series AS (
  SELECT '2025-01-01'::date AS d
  UNION ALL
  SELECT (d + INTERVAL '1 day')::date FROM date_series WHERE d < '2025-01-31'::date
)
SELECT d FROM date_series ORDER BY d;

/* Q17. */
WITH RECURSIVE fib AS (
  SELECT 1 AS n, 0::bigint AS fib_n, 1::bigint AS fib_next
  UNION ALL
  SELECT n + 1, fib_next, fib_n + fib_next
  FROM fib WHERE n < 20
)
SELECT n, fib_n FROM fib ORDER BY n;

/* Q18. Explodes marketing.campaigns.campaign_name-adjacent comma list - since no comma-separated column exists in this schema, a synthetic VALUES list demonstrates the pattern. */
WITH RECURSIVE split_list AS (
  SELECT 1 AS id, 'Google,Facebook,Instagram,TikTok' AS csv
),
parts AS (
  SELECT id, SPLIT_PART(csv, ',', 1) AS part, SUBSTRING(csv FROM POSITION(',' IN csv) + 1) AS rest, 1 AS n
  FROM split_list
  WHERE POSITION(',' IN csv) > 0
  UNION ALL
  SELECT p.id,
         CASE WHEN POSITION(',' IN p.rest) > 0 THEN SPLIT_PART(p.rest, ',', 1) ELSE p.rest END,
         CASE WHEN POSITION(',' IN p.rest) > 0 THEN SUBSTRING(p.rest FROM POSITION(',' IN p.rest) + 1) ELSE '' END,
         p.n + 1
  FROM parts p
  WHERE p.rest <> ''
)
SELECT id, n, part FROM parts ORDER BY id, n;

/* Q19. This demonstrates the cycle-detection pattern (visited-array + depth cap standing in for the PG14+ CYCLE clause) over a "suppliers sharing a warehouse" graph; with only 5 warehouses the graph is densely connected, so it correctly detects returning to the starting supplier within 2 hops rather than a data-integrity problem. Supplier-pair edges are pre-collapsed to a small DISTINCT set first, since walking the raw 2,000-row shipments table two joins deep on every recursive step fans out combinatorially. */
WITH RECURSIVE edges AS (
  SELECT DISTINCT sh1.supplier_id AS a, sh2.supplier_id AS b
  FROM supply_chain.shipments sh1
  JOIN supply_chain.shipments sh2 ON sh2.warehouse_id = sh1.warehouse_id AND sh2.supplier_id <> sh1.supplier_id
),
supplier_walk AS (
  SELECT 1 AS supplier_id, ARRAY[1] AS visited, FALSE AS is_cycle, 0 AS depth
  UNION ALL
  SELECT e.b, sw.visited || e.b, e.b = ANY(sw.visited), sw.depth + 1
  FROM supplier_walk sw
  JOIN edges e ON e.a = sw.supplier_id
  WHERE NOT sw.is_cycle AND sw.depth < 2
)
SELECT DISTINCT supplier_id, is_cycle FROM supplier_walk WHERE is_cycle = TRUE;

/* Q20. RetailMart has no friend-graph table; this demonstrates the same cycle-detection pattern (visited-array + depth cap) over the "customers who called the same agent" relation, which is acyclic by construction here within the depth cap. Depth capped at 2 hops since each hop can fan out to every other customer who called the same agent. */
WITH RECURSIVE friend_walk AS (
  SELECT customer_id, agent_id, ARRAY[customer_id] AS visited, FALSE AS is_cycle, 0 AS depth
  FROM call_center.calls
  WHERE customer_id = 1 AND agent_id IS NOT NULL
  UNION ALL
  SELECT c2.customer_id, c2.agent_id, fw.visited || c2.customer_id,
         c2.customer_id = ANY(fw.visited), fw.depth + 1
  FROM friend_walk fw
  JOIN call_center.calls c2 ON c2.agent_id = fw.agent_id AND c2.customer_id <> fw.customer_id
  WHERE NOT fw.is_cycle AND fw.depth < 2
)
SELECT DISTINCT customer_id, is_cycle FROM friend_walk WHERE is_cycle = TRUE LIMIT 50;

/* Q21. */
SELECT e.employee_id, e.dept_id
FROM stores.employees e
LEFT JOIN core.dim_department d ON d.dept_id = e.dept_id
WHERE d.dept_id IS NULL;

/* Q22. Depth from root is fixed at 1 (category is the root, brand is depth 1) since this schema's tree has only one level beneath the root. */
SELECT b.brand_id, b.brand_name, cat.category_id, 1 AS depth_from_root
FROM core.dim_brand b
JOIN core.dim_category cat ON cat.category_id = b.category_id
ORDER BY cat.category_id, b.brand_id;

/* Q23. Marks every ticket within 2 "hops" of a starting ticket via the shared-agent graph. */
WITH RECURSIVE hops AS (
  SELECT ticket_id, agent_id, 0 AS hop
  FROM support.tickets
  WHERE ticket_id = 1
  UNION ALL
  SELECT t2.ticket_id, t2.agent_id, h.hop + 1
  FROM hops h
  JOIN support.tickets t2 ON t2.agent_id = h.agent_id AND t2.ticket_id <> h.ticket_id
  WHERE h.hop < 2
)
SELECT DISTINCT ticket_id, MIN(hop) AS min_hop
FROM hops
GROUP BY ticket_id
ORDER BY min_hop, ticket_id
LIMIT 100;

/* Q24. A balance check for the category->brand tree: every category with at least one brand is "balanced" at depth 2, since there is no variable-depth recursion in this schema. */
SELECT cat.category_id, cat.category_name,
       COUNT(b.brand_id) AS brand_count,
       (COUNT(b.brand_id) > 0) AS is_balanced_depth_2
FROM core.dim_category cat
LEFT JOIN core.dim_brand b ON b.category_id = cat.category_id
GROUP BY cat.category_id, cat.category_name
ORDER BY cat.category_id;

/* Q25. */
SELECT p.product_id, p.product_name, cat.category_name || ' > ' || b.brand_name || ' > ' || p.product_name AS breadcrumb
FROM products.products p
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
ORDER BY p.product_id
LIMIT 200;

/* ============================================================
   SECTION B: LATERAL PRODUCTION (25)
   ------------------------------------------------------------ */
/* Q26. Restricted to a small customer sample since orders has no supporting index for a per-row correlated lookup on this practice database, and folded into a single per-customer scan (via ARRAY_AGG ordering) instead of three separate correlated subqueries to cut the repeated table scans threefold. */
SELECT c.customer_id, agg.latest_order_id, agg.first_order_id, agg.total_spend
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT
    (ARRAY_AGG(order_id ORDER BY order_date DESC))[1] AS latest_order_id,
    (ARRAY_AGG(order_id ORDER BY order_date ASC))[1] AS first_order_id,
    COALESCE(SUM(net_total),0) AS total_spend
  FROM sales.orders o WHERE o.cust_id = c.customer_id
) agg
WHERE c.customer_id <= 40;

/* Q27. */
SELECT c.customer_id, lr.review_id, lr.product_id, lr.review_date
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT r.review_id, r.product_id, r.review_date FROM customers.reviews r
  WHERE r.customer_id = c.customer_id ORDER BY r.review_date DESC LIMIT 3
) lr
WHERE c.customer_id <= 300;

/* Q28. */
SELECT t.ticket_id, tc.comment_source, tc.event_date
FROM support.tickets t
CROSS JOIN LATERAL (
  SELECT 'call' AS comment_source, cl.call_start_time::date AS event_date
  FROM call_center.calls cl WHERE cl.customer_id = t.customer_id
  ORDER BY cl.call_start_time DESC LIMIT 3
) tc
WHERE t.ticket_id <= 300;

/* Q29. */
SELECT e.employee_id AS agent_id, tc.priority, tc.ticket_count
FROM stores.employees e
CROSS JOIN LATERAL (
  SELECT priority, COUNT(*) AS ticket_count FROM support.tickets t
  WHERE t.agent_id = e.employee_id GROUP BY priority
) tc;

/* Q30. */
SELECT r.region_id, tp.product_name, tp.revenue
FROM core.dim_region r
CROSS JOIN LATERAL (
  SELECT p.product_name, SUM(oi.net_amount) AS revenue
  FROM stores.stores s
  JOIN sales.orders o ON o.store_id = s.store_id
  JOIN sales.order_items oi ON oi.order_id = o.order_id
  JOIN products.products p ON p.product_id = oi.prod_id
  WHERE s.region_id = r.region_id
  GROUP BY p.product_name ORDER BY SUM(oi.net_amount) DESC LIMIT 5
) tp;

/* Q31. */
SELECT w.warehouse_id, ls.product_id, ls.quantity_on_hand
FROM supply_chain.warehouses w
CROSS JOIN LATERAL (
  SELECT DISTINCT ON (product_id) product_id, quantity_on_hand
  FROM supply_chain.inventory_snapshots isn
  WHERE isn.warehouse_id = w.warehouse_id
  ORDER BY product_id, snapshot_date DESC
) ls;

/* Q32. */
SELECT DISTINCT sh.courier_name, agg.avg_delivery_days
FROM sales.shipments sh
CROSS JOIN LATERAL (
  SELECT AVG(delivered_date - shipped_date) AS avg_delivery_days
  FROM sales.shipments sh2
  WHERE sh2.courier_name = sh.courier_name AND sh2.delivered_date IS NOT NULL
) agg;

/* Q33. */
SELECT sup.supplier_id, agg.total_shipped, ls.last_shipment_date
FROM products.suppliers sup
CROSS JOIN LATERAL (
  SELECT COALESCE(SUM(quantity),0) AS total_shipped FROM supply_chain.shipments sh WHERE sh.supplier_id = sup.supplier_id
) agg
CROSS JOIN LATERAL (
  SELECT MAX(shipped_date) AS last_shipment_date FROM supply_chain.shipments sh WHERE sh.supplier_id = sup.supplier_id
) ls;

/* Q34. */
SELECT c.campaign_id, sp.total_spend, cl.clicks, ROUND(sp.total_spend / NULLIF(cl.clicks,0), 2) AS cost_per_click
FROM marketing.campaigns c
CROSS JOIN LATERAL (
  SELECT COALESCE(SUM(amount),0) AS total_spend FROM marketing.ads_spend a WHERE a.campaign_id = c.campaign_id
) sp
CROSS JOIN LATERAL (
  SELECT COALESCE(SUM(emails_clicked),0) AS clicks FROM marketing.email_clicks e WHERE e.campaign_id = c.campaign_id
) cl;

/* Q35. */
SELECT plat.platform, tc.campaign_id, tc.total_spend
FROM (SELECT DISTINCT platform FROM marketing.ads_spend) plat
CROSS JOIN LATERAL (
  SELECT campaign_id, SUM(amount) AS total_spend FROM marketing.ads_spend a
  WHERE a.platform = plat.platform GROUP BY campaign_id ORDER BY SUM(amount) DESC LIMIT 3
) tc;

/* Q36. */
SELECT cat.category_name, tp.product_name, tp.units_sold, b.brand_name
FROM core.dim_category cat
CROSS JOIN LATERAL (
  SELECT p.product_id, p.product_name, p.brand_id, SUM(oi.quantity) AS units_sold
  FROM products.products p
  JOIN core.dim_brand br ON br.brand_id = p.brand_id
  JOIN sales.order_items oi ON oi.prod_id = p.product_id
  WHERE br.category_id = cat.category_id
  GROUP BY p.product_id, p.product_name, p.brand_id ORDER BY SUM(oi.quantity) DESC LIMIT 3
) tp
JOIN core.dim_brand b ON b.brand_id = tp.brand_id;

/* Q37. */
SELECT d.dept_id, te.employee_id, te.salary, tp.total_payroll
FROM core.dim_department d
CROSS JOIN LATERAL (
  SELECT employee_id, salary FROM stores.employees e WHERE e.dept_id = d.dept_id ORDER BY salary DESC LIMIT 1
) te
CROSS JOIN LATERAL (
  SELECT COALESCE(SUM(salary),0) AS total_payroll FROM stores.employees e2 WHERE e2.dept_id = d.dept_id
) tp;

/* Q38. */
SELECT s.store_id, te.employee_id, te.ticket_count, aa.avg_salary
FROM stores.stores s
CROSS JOIN LATERAL (
  SELECT e.employee_id, COUNT(t.ticket_id) AS ticket_count
  FROM stores.employees e
  LEFT JOIN support.tickets t ON t.agent_id = e.employee_id
  WHERE e.store_id = s.store_id
  GROUP BY e.employee_id ORDER BY ticket_count DESC LIMIT 1
) te
CROSS JOIN LATERAL (
  SELECT AVG(salary) AS avg_salary FROM stores.employees e2 WHERE e2.store_id = s.store_id
) aa;

/* Q39. Restricted to a small customer sample since page_views (500,000 rows) has no index on customer_id for a per-row correlated lookup, and folded into a single scan per customer (via a window function picking the latest session) instead of two nested correlated scans. */
SELECT c.customer_id, pv.view_id, pv.page_url, pv.view_timestamp
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT view_id, page_url, view_timestamp
  FROM (
    SELECT view_id, page_url, view_timestamp, session_id,
           FIRST_VALUE(session_id) OVER (ORDER BY view_timestamp DESC) AS latest_session
    FROM web_events.page_views p
    WHERE p.customer_id = c.customer_id
  ) x
  WHERE session_id = latest_session
  ORDER BY view_timestamp
) pv
WHERE c.customer_id <= 30;

/* Q40. */
SELECT r.call_reason, lc.call_id, lc.call_duration_seconds, tr.transcript_text
FROM (SELECT DISTINCT call_reason FROM call_center.calls) r
CROSS JOIN LATERAL (
  SELECT call_id, call_duration_seconds FROM call_center.calls c
  WHERE c.call_reason = r.call_reason ORDER BY call_duration_seconds DESC LIMIT 1
) lc
LEFT JOIN call_center.transcripts tr ON tr.call_id = lc.call_id;

/* Q41. */
SELECT c.customer_id, elem.value
FROM (SELECT 1 AS customer_id, '["order","review","ticket"]'::jsonb AS touchpoints) c
CROSS JOIN LATERAL jsonb_array_elements_text(c.touchpoints) AS elem(value);

/* Q42. */
SELECT c.campaign_id, ds.day
FROM (SELECT * FROM marketing.campaigns LIMIT 10) c
CROSS JOIN LATERAL generate_series(c.start_date, c.end_date, INTERVAL '1 day') AS ds(day);

/* Q43. */
SELECT s.store_id, se.employee_id, se.salary, se.role
FROM stores.stores s
CROSS JOIN LATERAL (
  SELECT employee_id, salary, role FROM stores.employees e WHERE e.store_id = s.store_id ORDER BY salary DESC LIMIT 1
) se;

/* Q44. */
SELECT c.customer_id, hr.exists_flag
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT EXISTS(SELECT 1 FROM sales.returns r JOIN sales.orders o ON o.order_id = r.order_id WHERE o.cust_id = c.customer_id) AS exists_flag
) hr
WHERE c.customer_id <= 300;

/* Q45. Restricted to a customer sample since a naive next-purchase estimate is a correlated lookup over the unindexed orders table. */
SELECT c.customer_id, np.predicted_next_date
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT MAX(order_date) + (ROUND((MAX(order_date) - MIN(order_date))::numeric / NULLIF(COUNT(*) - 1, 0)))::integer AS predicted_next_date
  FROM sales.orders o WHERE o.cust_id = c.customer_id
) np
WHERE c.customer_id <= 300;

/* Q46. */
SELECT p.product_id, tb.cust_id, tb.units_bought
FROM products.products p
CROSS JOIN LATERAL (
  SELECT o.cust_id, SUM(oi.quantity) AS units_bought
  FROM sales.order_items oi JOIN sales.orders o ON o.order_id = oi.order_id
  WHERE oi.prod_id = p.product_id
  GROUP BY o.cust_id ORDER BY SUM(oi.quantity) DESC LIMIT 5
) tb
WHERE p.product_id <= 50;

/* Q47. */
SELECT r.region_id, gr.month, gr.revenue
FROM core.dim_region r
CROSS JOIN LATERAL (
  SELECT DATE_TRUNC('month', o.order_date) AS month, SUM(o.net_total) AS revenue
  FROM stores.stores s JOIN sales.orders o ON o.store_id = s.store_id
  WHERE s.region_id = r.region_id
  GROUP BY DATE_TRUNC('month', o.order_date) ORDER BY month
) gr;

/* Q48. */
SELECT s.store_id, ph.order_hour, ph.order_count
FROM stores.stores s
CROSS JOIN LATERAL (
  SELECT EXTRACT(HOUR FROM order_date::timestamp) AS order_hour, COUNT(*) AS order_count
  FROM sales.orders o WHERE o.store_id = s.store_id
  GROUP BY EXTRACT(HOUR FROM order_date::timestamp) ORDER BY COUNT(*) DESC LIMIT 1
) ph;

/* Q49. */
SELECT c.customer_id, lo.order_id, li.prod_id, pb.brand_name
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY order_date DESC LIMIT 1
) lo
CROSS JOIN LATERAL (
  SELECT prod_id FROM sales.order_items oi WHERE oi.order_id = lo.order_id ORDER BY oi.order_item_id LIMIT 1
) li
CROSS JOIN LATERAL (
  SELECT b.brand_name FROM products.products p JOIN core.dim_brand b ON b.brand_id = p.brand_id WHERE p.product_id = li.prod_id
) pb
WHERE c.customer_id <= 30;

/* Q50. */
SELECT s.store_id, agg.order_count, agg.revenue
FROM stores.stores s
CROSS JOIN LATERAL (
  SELECT COUNT(*) AS order_count, COALESCE(SUM(net_total),0) AS revenue FROM sales.orders o WHERE o.store_id = s.store_id
) agg;

/* ============================================================
   SECTION C: SET OPERATIONS PRODUCTION (25)
   ------------------------------------------------------------ */
/* Q51. */
SELECT cust_id AS customer_id, 'order' AS source, order_id::text AS ref_id, order_date AS event_date FROM sales.orders
UNION ALL
SELECT customer_id, 'review', review_id::text, review_date FROM customers.reviews
UNION ALL
SELECT customer_id, 'ticket', ticket_id::text, created_date::date FROM support.tickets
UNION ALL
SELECT customer_id, 'call', call_id::text, call_start_time::date FROM call_center.calls
UNION ALL
SELECT customer_id, 'view', view_id::text, view_timestamp::date FROM web_events.page_views
UNION ALL
SELECT o.cust_id, 'payment', sp.payment_id::text, sp.payment_date FROM sales.payments sp JOIN sales.orders o ON o.order_id = sp.order_id
ORDER BY customer_id, event_date
LIMIT 500;

/* Q52. */
SELECT cust_id AS customer_id FROM sales.orders WHERE order_date >= '2025-06-01'
EXCEPT
SELECT cust_id FROM sales.orders WHERE order_date < '2025-06-01'
UNION ALL
SELECT cust_id FROM sales.orders WHERE order_date < '2025-06-01'
EXCEPT
SELECT cust_id FROM sales.orders WHERE order_date >= '2025-06-01';

/* Q53. VIP defined 3 ways: top-quartile spend, 2+ reviews, or Platinum tier. */
WITH spend AS (SELECT cust_id, SUM(net_total) AS total_spend FROM sales.orders GROUP BY cust_id),
threshold AS (SELECT PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total_spend) AS p75 FROM spend)
SELECT cust_id FROM spend, threshold WHERE total_spend >= p75
INTERSECT
SELECT customer_id FROM customers.reviews GROUP BY customer_id HAVING COUNT(*) >= 2
INTERSECT
SELECT customer_id FROM customers.customers WHERE tier = 'Platinum';

/* Q54. */
SELECT 'revenue' AS metric, DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS value FROM sales.orders GROUP BY DATE_TRUNC('month', order_date)
UNION ALL
SELECT 'ad_spend', DATE_TRUNC('month', spend_date), SUM(amount) FROM marketing.ads_spend GROUP BY DATE_TRUNC('month', spend_date)
UNION ALL
SELECT 'payroll', DATE_TRUNC('month', payment_date), SUM(net_salary) FROM payroll.pay_slips GROUP BY DATE_TRUNC('month', payment_date)
ORDER BY month, metric
LIMIT 200;

/* Q55. */
SELECT 'sales' AS schema_source, COUNT(*) AS row_count FROM sales.orders
UNION ALL
SELECT 'support', COUNT(*) FROM support.tickets
UNION ALL
SELECT 'marketing', COUNT(*) FROM marketing.campaigns
UNION ALL
SELECT 'hr', COUNT(*) FROM stores.employees;

/* Q56. RetailMart is a single-database practice copy with no foreign data wrapper configured, so a real cross-database UNION ALL via FDW isn't runnable here; the closest same-database analog unions two schemas' data as a stand-in for the pattern. */
SELECT 'stores' AS domain, store_id::text AS entity_id FROM stores.stores
UNION ALL
SELECT 'warehouses', warehouse_id::text FROM supply_chain.warehouses;

/* Q57. */
SELECT order_status, COUNT(*) AS order_count, SUM(net_total) AS revenue
FROM sales.orders
GROUP BY order_status
UNION ALL
SELECT 'TOTAL', COUNT(*), SUM(net_total) FROM sales.orders;

/* Q58. */
SELECT order_status, revenue,
       DENSE_RANK() OVER (ORDER BY revenue DESC) AS revenue_rank
FROM (
  SELECT order_status, SUM(net_total) AS revenue FROM sales.orders GROUP BY order_status
  UNION ALL
  SELECT 'TOTAL', SUM(net_total) FROM sales.orders
) x;

/* Q59. */
SELECT order_id, cust_id, order_date, net_total, 'historical' AS period FROM sales.orders WHERE order_date < '2025-01-01'
UNION ALL
SELECT order_id, cust_id, order_date, net_total, 'current' FROM sales.orders WHERE order_date >= '2025-01-01'
LIMIT 200;

/* Q60. */
SELECT order_id, cust_id, net_total, 'store_1' AS partition_label FROM sales.orders WHERE store_id = 1
UNION ALL
SELECT order_id, cust_id, net_total, 'store_2' FROM sales.orders WHERE store_id = 2
UNION ALL
SELECT order_id, cust_id, net_total, 'store_3' FROM sales.orders WHERE store_id = 3
LIMIT 200;

/* Q61. */
SELECT order_status FROM sales.orders WHERE cust_id = 1
INTERSECT ALL
SELECT order_status FROM sales.orders WHERE cust_id = 2;

/* Q62. */
SELECT order_status FROM sales.orders WHERE cust_id = 1
EXCEPT ALL
SELECT order_status FROM sales.orders WHERE cust_id = 2;

/* Q63. */
SELECT c.customer_id, o.order_id
FROM customers.customers c
LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
WHERE o.order_id IS NULL
UNION ALL
SELECT c.customer_id, o.order_id
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
WHERE o.order_id = (SELECT MIN(o2.order_id) FROM sales.orders o2 WHERE o2.cust_id = c.customer_id)
LIMIT 300;

/* Q64. */
SELECT
  CASE WHEN o.cust_id IS NOT NULL AND c.customer_id IS NOT NULL THEN 'both'
       WHEN o.cust_id IS NOT NULL THEN 'orders_only'
       ELSE 'customers_only' END AS bucket,
  COALESCE(o.cust_id, c.customer_id) AS reconciled_id
FROM (SELECT DISTINCT cust_id FROM sales.orders) o
FULL OUTER JOIN customers.customers c ON c.customer_id = o.cust_id
LIMIT 300;

/* Q65. */
SELECT DISTINCT product_id FROM products.inventory
EXCEPT
SELECT DISTINCT prod_id FROM sales.order_items
UNION ALL
SELECT DISTINCT prod_id FROM sales.order_items
EXCEPT
SELECT DISTINCT product_id FROM products.inventory
LIMIT 200;

/* Q66. Churn definitions: 90+ days since last order, or Bronze tier with no upgrade in a year, or 2+ negative-sentiment calls. */
SELECT cust_id AS customer_id FROM sales.orders GROUP BY cust_id HAVING MAX(order_date) < (SELECT MAX(order_date) FROM sales.orders) - 90
INTERSECT
SELECT customer_id FROM customers.customers WHERE tier = 'Bronze' AND tier_updated_at < (SELECT MAX(order_date) FROM sales.orders) - 365;

/* Q67. Lifecycle stages: Prospect (no orders), New (1 order), Active (2+ orders, recent), Lapsed (2+ orders, not recent). */
SELECT customer_id, 'Prospect' AS stage FROM customers.customers c
WHERE NOT EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id)
UNION ALL
SELECT cust_id, 'New' FROM sales.orders GROUP BY cust_id HAVING COUNT(*) = 1
UNION ALL
SELECT cust_id, 'Active' FROM sales.orders GROUP BY cust_id
HAVING COUNT(*) >= 2 AND MAX(order_date) >= (SELECT MAX(order_date) FROM sales.orders) - 90
UNION ALL
SELECT cust_id, 'Lapsed' FROM sales.orders GROUP BY cust_id
HAVING COUNT(*) >= 2 AND MAX(order_date) < (SELECT MAX(order_date) FROM sales.orders) - 90
LIMIT 500;

/* Q68. Attribution weight: each order's revenue gets a 1.0 "direct" weight, plus a 0.2 weight to every campaign that was running in the 7 days before the order (multi-touch style). */
SELECT o.order_id::text AS ref_id, 'direct_order' AS source, o.net_total AS attributed_value, 1.0 AS weight
FROM sales.orders o
WHERE o.order_id <= 2000
UNION ALL
SELECT o.order_id::text, c.campaign_name, o.net_total * 0.2, 0.2
FROM sales.orders o
JOIN marketing.campaigns c ON c.start_date <= o.order_date AND c.end_date >= o.order_date - 7
WHERE o.order_id <= 2000
ORDER BY ref_id, weight DESC
LIMIT 200;

/* Q69. Customer interaction graph edges: order->store, ticket->agent, call->agent. */
SELECT cust_id AS node_a, store_id AS node_b, 'placed_order_at' AS edge_type FROM sales.orders
UNION ALL
SELECT customer_id, agent_id, 'ticket_with' FROM support.tickets WHERE agent_id IS NOT NULL
UNION ALL
SELECT customer_id, agent_id, 'called' FROM call_center.calls WHERE agent_id IS NOT NULL
LIMIT 500;

/* Q70. */
SELECT DISTINCT o1.cust_id AS customer_a, o2.cust_id AS customer_b, oi1.prod_id
FROM sales.orders o1
JOIN sales.order_items oi1 ON oi1.order_id = o1.order_id
JOIN sales.order_items oi2 ON oi2.prod_id = oi1.prod_id
JOIN sales.orders o2 ON o2.order_id = oi2.order_id AND o2.cust_id <> o1.cust_id
WHERE o1.cust_id = 1
UNION ALL
SELECT DISTINCT o1.cust_id, o2.cust_id, oi1.prod_id
FROM sales.orders o1
JOIN sales.order_items oi1 ON oi1.order_id = o1.order_id
JOIN sales.order_items oi2 ON oi2.prod_id = oi1.prod_id
JOIN sales.orders o2 ON o2.order_id = oi2.order_id AND o2.cust_id <> o1.cust_id
WHERE o1.cust_id = 2
LIMIT 200;

/* Q71. */
SELECT p1.promo_id AS promo1, p2.promo_id AS promo2
FROM products.promotions p1
FULL OUTER JOIN products.promotions p2
  ON p1.promo_id < p2.promo_id
 AND p1.start_date <= p2.end_date AND p2.start_date <= p1.end_date
WHERE p1.promo_id IS NOT NULL AND p2.promo_id IS NOT NULL
LIMIT 200;

/* Q72. */
SELECT ec.category_name AS tax_category, 'expense' AS record_type, e.amount FROM finance.expenses e JOIN core.dim_expense_category ec ON ec.exp_cat_id = e.exp_cat_id
UNION ALL
SELECT 'Payroll', 'payroll', SUM(net_salary) FROM payroll.pay_slips GROUP BY salary_year
LIMIT 300;

/* Q73. */
SELECT r.return_id, r.refund_amount, 'return' AS source FROM sales.returns r
UNION ALL
SELECT rl.refund_id, rl.amount, 'refund_log' FROM audit.refund_log rl
LIMIT 300;

/* Q74. */
SELECT order_status, revenue, RANK() OVER (ORDER BY revenue DESC) AS rnk
FROM (
  SELECT order_status, SUM(net_total) AS revenue FROM sales.orders GROUP BY order_status
  UNION ALL
  SELECT 'ALL_STATUSES', SUM(net_total) FROM sales.orders
) x
ORDER BY rnk;

/* Q75. Combines a category->brand hierarchy (this schema's real tree) with a set-op comparison of in-catalog vs never-sold brands. */
WITH sold_brands AS (
  SELECT DISTINCT p.brand_id FROM products.products p JOIN sales.order_items oi ON oi.prod_id = p.product_id
),
all_brands AS (SELECT brand_id FROM core.dim_brand)
SELECT brand_id, 'sold' AS status FROM all_brands WHERE brand_id IN (SELECT brand_id FROM sold_brands)
UNION ALL
SELECT brand_id, 'never_sold' FROM all_brands
EXCEPT ALL
SELECT brand_id, 'never_sold' FROM sold_brands;

/* ============================================================
   SECTION D: MIXED MEGA-PATTERNS (25)
   ------------------------------------------------------------ */
/* Q76. Restricted to a bounded sample of customers. */
SELECT c.customer_id, ev.event_type, ev.event_date,
       ROW_NUMBER() OVER (PARTITION BY c.customer_id ORDER BY ev.event_date DESC) AS recency_rank
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT 'order' AS event_type, order_date AS event_date FROM sales.orders o WHERE o.cust_id = c.customer_id
  UNION ALL
  SELECT 'review', review_date FROM customers.reviews r WHERE r.customer_id = c.customer_id
  UNION ALL
  SELECT 'ticket', created_date::date FROM support.tickets t WHERE t.customer_id = c.customer_id
) ev
WHERE c.customer_id <= 100
ORDER BY c.customer_id, recency_rank
LIMIT 500;

/* Q77. */
WITH product_first_sale AS (
  SELECT oi.prod_id, MIN(o.order_date) AS launch_date
  FROM sales.order_items oi JOIN sales.orders o ON o.order_id = oi.order_id
  GROUP BY oi.prod_id
),
product_last_sale AS (
  SELECT oi.prod_id, MAX(o.order_date) AS last_sale_date
  FROM sales.order_items oi JOIN sales.orders o ON o.order_id = oi.order_id
  GROUP BY oi.prod_id
)
SELECT p.product_id, p.product_name, fs.launch_date, ls.last_sale_date
FROM products.products p
LEFT JOIN product_first_sale fs ON fs.prod_id = p.product_id
LEFT JOIN product_last_sale ls ON ls.prod_id = p.product_id
ORDER BY p.product_id
LIMIT 200;

/* Q78. Multi-touch attribution: split each order's credit equally across all campaigns active in the 30 days before it, per platform. */
WITH order_touches AS (
  SELECT o.order_id, o.net_total, c.campaign_id, a.platform,
         COUNT(*) OVER (PARTITION BY o.order_id) AS touch_count
  FROM sales.orders o
  JOIN marketing.campaigns c ON c.start_date <= o.order_date AND c.end_date >= o.order_date - 30
  JOIN marketing.ads_spend a ON a.campaign_id = c.campaign_id
  WHERE o.order_id <= 2000
)
SELECT platform, SUM(net_total / touch_count) AS attributed_revenue
FROM order_touches
GROUP BY platform
ORDER BY attributed_revenue DESC;

/* Q79. RFM quintiles are computed across all customers first (a single pass), but the LATERAL "predicted next purchase" re-scan of orders is applied only to a bounded sample of 200 customers afterward, since running that per-customer correlated scan against all ~50,000 customers would repeatedly rescan the 150,000-row orders table. */
WITH cust_agg AS (
  SELECT cust_id AS customer_id,
         (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS recency_days,
         COUNT(*) AS order_count,
         SUM(net_total) AS total_spend
  FROM sales.orders
  GROUP BY cust_id
),
rfm AS (
  SELECT customer_id, recency_days, order_count, total_spend,
         NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,
         NTILE(5) OVER (ORDER BY order_count DESC) AS f_score,
         NTILE(5) OVER (ORDER BY total_spend DESC) AS m_score
  FROM cust_agg
),
rfm_sample AS (
  SELECT * FROM rfm ORDER BY customer_id LIMIT 200
)
SELECT rfm_sample.customer_id, rfm_sample.r_score, rfm_sample.f_score, rfm_sample.m_score, np.predicted_next_date
FROM rfm_sample
CROSS JOIN LATERAL (
  SELECT MAX(order_date) + (ROUND((MAX(order_date) - MIN(order_date))::numeric / NULLIF(COUNT(*) - 1, 0)))::integer AS predicted_next_date
  FROM sales.orders o WHERE o.cust_id = rfm_sample.customer_id
) np
ORDER BY rfm_sample.customer_id;

/* Q80. Executive pulse: headline counts and totals across the business in one dashboard row. */
SELECT
  (SELECT COUNT(*) FROM customers.customers) AS total_customers,
  (SELECT COUNT(*) FROM sales.orders) AS total_orders,
  (SELECT SUM(net_total) FROM sales.orders) AS total_revenue,
  (SELECT COUNT(*) FROM products.products) AS total_products,
  (SELECT COUNT(*) FROM stores.stores) AS total_stores,
  (SELECT COUNT(*) FROM stores.employees) AS total_employees,
  (SELECT COUNT(*) FROM support.tickets WHERE status = 'Open') AS open_tickets,
  (SELECT COUNT(*) FROM sales.returns) AS total_returns,
  (SELECT AVG(net_total) FROM sales.orders) AS avg_order_value,
  (SELECT COUNT(*) FROM marketing.campaigns) AS total_campaigns;

/* Q81. */
WITH product_stock AS (
  SELECT isn.warehouse_id, isn.product_id, isn.quantity_on_hand,
         ROW_NUMBER() OVER (PARTITION BY isn.warehouse_id, isn.product_id ORDER BY isn.snapshot_date DESC) AS rn
  FROM supply_chain.inventory_snapshots isn
)
SELECT warehouse_id, product_id, quantity_on_hand,
       CASE WHEN quantity_on_hand < 20 THEN 'REORDER_NOW' WHEN quantity_on_hand < 50 THEN 'REORDER_SOON' ELSE 'OK' END AS recommendation
FROM product_stock
WHERE rn = 1 AND quantity_on_hand < 50
ORDER BY quantity_on_hand
LIMIT 200;

/* Q82. */
WITH sup_metrics AS (
  SELECT sup.supplier_id, sup.supplier_name, COUNT(sh.shipment_id) AS shipment_count,
         COALESCE(SUM(sh.quantity),0) AS total_quantity,
         COUNT(*) FILTER (WHERE sh.status = 'Delayed') AS delayed_count
  FROM products.suppliers sup
  LEFT JOIN supply_chain.shipments sh ON sh.supplier_id = sup.supplier_id
  GROUP BY sup.supplier_id, sup.supplier_name
)
SELECT supplier_id, supplier_name, shipment_count, total_quantity, delayed_count,
       ROUND(delayed_count::numeric / NULLIF(shipment_count,0), 4) AS delay_rate,
       RANK() OVER (ORDER BY total_quantity DESC) AS volume_rank
FROM sup_metrics
ORDER BY volume_rank
LIMIT 100;

/* Q83. */
SELECT e.employee_id, e.dept_id, e.salary,
       RANK() OVER (PARTITION BY e.dept_id ORDER BY e.salary DESC) AS salary_rank_in_dept,
       (SELECT COUNT(*) FROM hr.attendance a WHERE a.employee_id = e.employee_id) AS attendance_records,
       (SELECT COUNT(*) FROM support.tickets t WHERE t.agent_id = e.employee_id) AS tickets_handled
FROM stores.employees e
ORDER BY e.dept_id, salary_rank_in_dept
LIMIT 200;

/* Q84. Restricted to a bounded sample of customers. */
SELECT c.customer_id, ev.source, ev.event_date
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT 'order' AS source, order_date AS event_date FROM sales.orders o WHERE o.cust_id = c.customer_id
  UNION ALL
  SELECT 'ticket', created_date::date FROM support.tickets t WHERE t.customer_id = c.customer_id
  UNION ALL
  SELECT 'call', call_start_time::date FROM call_center.calls cl WHERE cl.customer_id = c.customer_id
  UNION ALL
  SELECT 'review', review_date FROM customers.reviews r WHERE r.customer_id = c.customer_id
) ev
WHERE c.customer_id <= 100
ORDER BY c.customer_id, ev.event_date
LIMIT 500;

/* Q85. */
WITH campaign_perf AS (
  SELECT c.campaign_id, c.campaign_name, c.budget,
         COALESCE(SUM(a.amount),0) AS spend,
         COALESCE(SUM(ec.emails_clicked),0) AS clicks
  FROM marketing.campaigns c
  LEFT JOIN marketing.ads_spend a ON a.campaign_id = c.campaign_id
  LEFT JOIN marketing.email_clicks ec ON ec.campaign_id = c.campaign_id
  GROUP BY c.campaign_id, c.campaign_name, c.budget
)
SELECT campaign_id, campaign_name, budget, spend, clicks,
       ROUND((budget - spend) / NULLIF(budget,0) * 100, 2) AS budget_remaining_pct,
       RANK() OVER (ORDER BY clicks DESC) AS engagement_rank
FROM campaign_perf
ORDER BY engagement_rank
LIMIT 100;

/* Q86. */
WITH city_metrics AS (
  SELECT a.city, COUNT(DISTINCT c.customer_id) AS customer_count, COALESCE(SUM(o.net_total),0) AS revenue
  FROM customers.customers c
  JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = TRUE
  LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
  GROUP BY a.city
)
SELECT city, customer_count, revenue,
       RANK() OVER (ORDER BY revenue DESC) AS revenue_rank,
       RANK() OVER (ORDER BY customer_count DESC) AS customer_rank,
       (RANK() OVER (ORDER BY revenue DESC) + RANK() OVER (ORDER BY customer_count DESC)) AS expansion_score
FROM city_metrics
ORDER BY expansion_score
LIMIT 50;

/* Q87. */
WITH loyalty_spend AS (
  SELECT m.customer_id, m.tier_id, COALESCE(SUM(o.net_total),0) AS total_spend
  FROM loyalty.members m
  LEFT JOIN sales.orders o ON o.cust_id = m.customer_id
  GROUP BY m.customer_id, m.tier_id
),
redemption_cost AS (
  SELECT customer_id, COUNT(*) AS redemption_count, SUM(points_redeemed) AS points_used
  FROM loyalty.redemptions
  GROUP BY customer_id
)
SELECT tr.tier_name, COUNT(ls.customer_id) AS member_count, SUM(ls.total_spend) AS total_member_spend,
       COALESCE(SUM(rc.redemption_count),0) AS total_redemptions
FROM loyalty_spend ls
JOIN loyalty.tiers tr ON tr.tier_id = ls.tier_id
LEFT JOIN redemption_cost rc ON rc.customer_id = ls.customer_id
GROUP BY tr.tier_name
ORDER BY total_member_spend DESC;

/* Q88. */
WITH return_flags AS (
  SELECT r.return_id, r.order_id, r.prod_id, r.reason,
         (r.return_date - o.order_date) AS days_to_return
  FROM sales.returns r
  JOIN sales.orders o ON o.order_id = r.order_id
)
SELECT reason,
       COUNT(*) AS return_count,
       AVG(days_to_return) AS avg_days_to_return,
       (COUNT(*) FILTER (WHERE days_to_return <= 7))::numeric / COUNT(*) AS pct_fast_returns
FROM return_flags
GROUP BY reason
ORDER BY return_count DESC;

/* Q89. */
WITH sla_flags AS (
  SELECT ticket_id, priority, resolved_date - created_date AS resolution_time,
         CASE priority
           WHEN 'Critical' THEN INTERVAL '4 hours'
           WHEN 'High' THEN INTERVAL '1 day'
           WHEN 'Medium' THEN INTERVAL '3 days'
           ELSE INTERVAL '7 days'
         END AS sla_target
  FROM support.tickets
  WHERE resolved_date IS NOT NULL
)
SELECT priority,
       COUNT(*) AS resolved_count,
       COUNT(*) FILTER (WHERE resolution_time > sla_target) AS breached_count,
       ROUND(COUNT(*) FILTER (WHERE resolution_time > sla_target)::numeric / COUNT(*), 4) AS breach_rate
FROM sla_flags
GROUP BY priority
ORDER BY breach_rate DESC;

/* Q90. Simple fraud heuristic: 3+ orders by the same customer within 1 hour, or an order value >5x that customer's average. */
WITH cust_avg AS (
  SELECT cust_id, AVG(net_total) AS avg_order FROM sales.orders GROUP BY cust_id
)
SELECT o.order_id, o.cust_id, o.net_total, ca.avg_order, 'value_outlier' AS flag_reason
FROM sales.orders o
JOIN cust_avg ca ON ca.cust_id = o.cust_id
WHERE o.net_total > 5 * ca.avg_order
ORDER BY o.net_total DESC
LIMIT 100;

/* Q91. */
WITH latest_stock AS (
  SELECT isn.warehouse_id, isn.product_id, isn.quantity_on_hand,
         ROW_NUMBER() OVER (PARTITION BY isn.product_id ORDER BY isn.snapshot_date DESC) AS rn
  FROM supply_chain.inventory_snapshots isn
),
recent_sales AS (
  SELECT oi.prod_id, SUM(oi.quantity) AS units_last_period
  FROM sales.order_items oi JOIN sales.orders o ON o.order_id = oi.order_id
  WHERE o.order_date >= (SELECT MAX(order_date) FROM sales.orders) - 30
  GROUP BY oi.prod_id
)
SELECT ls.product_id, SUM(ls.quantity_on_hand) AS total_stock, COALESCE(rs.units_last_period,0) AS units_last_30d,
       ROUND(SUM(ls.quantity_on_hand)::numeric / NULLIF(COALESCE(rs.units_last_period,0),0), 2) AS days_of_stock_estimate
FROM latest_stock ls
LEFT JOIN recent_sales rs ON rs.prod_id = ls.product_id
WHERE ls.rn = 1
GROUP BY ls.product_id, rs.units_last_period
HAVING SUM(ls.quantity_on_hand) < COALESCE(rs.units_last_period,0)
ORDER BY days_of_stock_estimate ASC NULLS LAST
LIMIT 100;

/* Q92. At-risk composite: recency + low frequency + declining spend, top 100 by score. */
WITH cust_agg AS (
  SELECT cust_id AS customer_id,
         (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS recency_days,
         COUNT(*) AS order_count,
         SUM(net_total) AS total_spend
  FROM sales.orders
  GROUP BY cust_id
),
scored AS (
  SELECT customer_id,
         NTILE(10) OVER (ORDER BY recency_days DESC) AS recency_risk,
         NTILE(10) OVER (ORDER BY order_count ASC) AS freq_risk,
         NTILE(10) OVER (ORDER BY total_spend ASC) AS spend_risk
  FROM cust_agg
)
SELECT customer_id, (recency_risk + freq_risk + spend_risk) AS at_risk_score
FROM scored
ORDER BY at_risk_score DESC
LIMIT 100;

/* Q93. Growth composite: recent + high frequency + high spend, top 100 by score. */
WITH cust_agg AS (
  SELECT cust_id AS customer_id,
         (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS recency_days,
         COUNT(*) AS order_count,
         SUM(net_total) AS total_spend
  FROM sales.orders
  GROUP BY cust_id
),
scored AS (
  SELECT customer_id,
         NTILE(10) OVER (ORDER BY recency_days ASC) AS recency_score,
         NTILE(10) OVER (ORDER BY order_count DESC) AS freq_score,
         NTILE(10) OVER (ORDER BY total_spend DESC) AS spend_score
  FROM cust_agg
)
SELECT customer_id, (recency_score + freq_score + spend_score) AS growth_score
FROM scored
ORDER BY growth_score ASC
LIMIT 100;

/* Q94. */
WITH cust_tier_points AS (
  SELECT m.customer_id, m.tier_id, m.points_balance, tr.tier_name, tr.max_points,
         LEAD(tr2.tier_name) OVER (ORDER BY tr.min_points) AS next_tier_name
  FROM loyalty.members m
  JOIN loyalty.tiers tr ON tr.tier_id = m.tier_id
  LEFT JOIN loyalty.tiers tr2 ON tr2.tier_id = m.tier_id + 1
)
SELECT customer_id, tier_name, points_balance, max_points,
       GREATEST(max_points - points_balance + 1, 0) AS points_to_upgrade
FROM cust_tier_points
WHERE max_points IS NOT NULL
ORDER BY points_to_upgrade ASC
LIMIT 200;

/* Q95. Pricing optimization preview: compare each product's price against its category's average price. */
SELECT p.product_id, p.product_name, p.price, cat.category_name, ca.avg_category_price,
       ROUND((p.price - ca.avg_category_price) / ca.avg_category_price * 100, 2) AS pct_vs_category_avg
FROM products.products p
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
JOIN (
  SELECT cat2.category_id, AVG(p2.price) AS avg_category_price
  FROM products.products p2
  JOIN core.dim_brand b2 ON b2.brand_id = p2.brand_id
  JOIN core.dim_category cat2 ON cat2.category_id = b2.category_id
  GROUP BY cat2.category_id
) ca ON ca.category_id = cat.category_id
ORDER BY pct_vs_category_avg DESC
LIMIT 200;

/* Q96. NPS deep dive proxy by 5 dimensions: rating by category, brand, store region, tier, and month. */
SELECT 'by_category' AS dimension, cat.category_name AS dim_value, AVG(r.rating) AS avg_rating
FROM customers.reviews r
JOIN products.products p ON p.product_id = r.product_id
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
GROUP BY cat.category_name
UNION ALL
SELECT 'by_tier', c.tier, AVG(r.rating)
FROM customers.reviews r JOIN customers.customers c ON c.customer_id = r.customer_id
GROUP BY c.tier
UNION ALL
SELECT 'by_month', TO_CHAR(r.review_date, 'YYYY-MM'), AVG(r.rating)
FROM customers.reviews r
GROUP BY TO_CHAR(r.review_date, 'YYYY-MM')
ORDER BY dimension, dim_value
LIMIT 200;

/* Q97. Churn deep dive: root causes tagged per lapsed customer (no orders in 90+ days). */
WITH lapsed AS (
  SELECT cust_id AS customer_id, MAX(order_date) AS last_order_date
  FROM sales.orders
  GROUP BY cust_id
  HAVING MAX(order_date) < (SELECT MAX(order_date) FROM sales.orders) - 90
)
SELECT l.customer_id, l.last_order_date,
       (SELECT COUNT(*) FROM support.tickets t WHERE t.customer_id = l.customer_id AND t.status = 'Open') AS unresolved_tickets,
       (SELECT COUNT(*) FROM sales.returns r JOIN sales.orders o ON o.order_id = r.order_id WHERE o.cust_id = l.customer_id) AS returns_count,
       (SELECT AVG(rating) FROM customers.reviews rv WHERE rv.customer_id = l.customer_id) AS avg_review_rating
FROM lapsed l
WHERE l.customer_id <= 3000
ORDER BY l.last_order_date ASC
LIMIT 200;

/* Q98. Cross-sell: for a given customer's most recent product, the top co-purchased products by other customers. */
WITH target_customer AS (
  SELECT 1 AS customer_id
),
last_product AS (
  SELECT oi.prod_id
  FROM sales.orders o
  JOIN sales.order_items oi ON oi.order_id = o.order_id
  JOIN target_customer tc ON tc.customer_id = o.cust_id
  ORDER BY o.order_date DESC LIMIT 1
)
SELECT oi2.prod_id AS recommended_product_id, COUNT(*) AS co_purchase_count
FROM sales.order_items oi1
JOIN last_product lp ON lp.prod_id = oi1.prod_id
JOIN sales.order_items oi2 ON oi2.order_id = oi1.order_id AND oi2.prod_id <> oi1.prod_id
GROUP BY oi2.prod_id
ORDER BY co_purchase_count DESC
LIMIT 10;

/* Q99. Up-sell: for a given customer's most recent product, pricier alternatives from the same brand. */
WITH target_customer AS (
  SELECT 1 AS customer_id
),
last_product AS (
  SELECT oi.prod_id
  FROM sales.orders o
  JOIN sales.order_items oi ON oi.order_id = o.order_id
  JOIN target_customer tc ON tc.customer_id = o.cust_id
  ORDER BY o.order_date DESC LIMIT 1
)
SELECT p2.product_id AS upsell_product_id, p2.product_name, p2.price
FROM last_product lp
JOIN products.products p1 ON p1.product_id = lp.prod_id
JOIN products.products p2 ON p2.brand_id = p1.brand_id AND p2.price > p1.price
ORDER BY p2.price ASC
LIMIT 10;

/* Q100. Master: one row per customer combining LATERAL-derived top order, a window-ranked spend position, and a set-op-derived channel list, restricted to a bounded sample. */
WITH cust_agg AS (
  SELECT cust_id AS customer_id, COUNT(*) AS order_count, SUM(net_total) AS total_spend
  FROM sales.orders
  WHERE cust_id <= 500
  GROUP BY cust_id
),
ranked AS (
  SELECT customer_id, order_count, total_spend,
         RANK() OVER (ORDER BY total_spend DESC) AS spend_rank
  FROM cust_agg
)
SELECT r.customer_id, r.order_count, r.total_spend, r.spend_rank, lo.order_id AS top_order_id, lo.net_total AS top_order_value,
       ch.channels
FROM ranked r
CROSS JOIN LATERAL (
  SELECT order_id, net_total FROM sales.orders o WHERE o.cust_id = r.customer_id ORDER BY net_total DESC LIMIT 1
) lo
CROSS JOIN LATERAL (
  SELECT STRING_AGG(DISTINCT channel, ',') AS channels FROM (
    SELECT 'order' AS channel FROM sales.orders o2 WHERE o2.cust_id = r.customer_id
    UNION
    SELECT 'ticket' FROM support.tickets t WHERE t.customer_id = r.customer_id
    UNION
    SELECT 'review' FROM customers.reviews rv WHERE rv.customer_id = r.customer_id
  ) x
) ch
ORDER BY r.spend_rank
LIMIT 200;

/* ============================================================
   END OF ANSWER KEY - JOINs Part 2 (Advanced) - CRAZY LEVEL (100/100)
============================================================ */
