/* ============================================================
   ANSWER KEY - Subqueries Part 2 (Correlated & LATERAL) (HARD LEVEL)
   Curriculum:   RetailMart V3
   Note: this database has NO indexes on foreign-key columns, so
   LATERAL/correlated patterns whose driving table is large (orders,
   customers, order_items, page_views) are restricted to a bounded
   sample where noted; the same pattern is correct unrestricted, just
   slower on this unindexed practice copy.
   ============================================================ */

/* SECTION A: LATERAL + SET OPS (25) */
/* Q1. */
SELECT c.customer_id, ev.source, ev.ref_id, ev.event_date
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT 'order' AS source, order_id AS ref_id, order_date AS event_date FROM sales.orders o WHERE o.cust_id = c.customer_id
  UNION ALL
  SELECT 'review', review_id, review_date FROM customers.reviews r WHERE r.customer_id = c.customer_id
) ev
WHERE c.customer_id <= 100
ORDER BY c.customer_id, ev.event_date
LIMIT 300;

/* Q2. */
SELECT c.customer_id, common.platform
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT DISTINCT a.platform FROM marketing.ads_spend a JOIN marketing.campaigns cp ON cp.campaign_id = a.campaign_id
  WHERE cp.start_date <= (SELECT MAX(o.order_date) FROM sales.orders o WHERE o.cust_id = c.customer_id)
  INTERSECT
  SELECT DISTINCT a2.platform FROM marketing.ads_spend a2 JOIN marketing.campaigns cp2 ON cp2.campaign_id = a2.campaign_id
  WHERE cp2.end_date >= (SELECT MIN(o2.order_date) FROM sales.orders o2 WHERE o2.cust_id = c.customer_id)
) common
WHERE c.customer_id <= 20
LIMIT 100;

/* Q3. */
SELECT sup.supplier_id, missing.product_id
FROM products.suppliers sup
CROSS JOIN LATERAL (
  SELECT product_id FROM products.products p WHERE p.supplier_id = sup.supplier_id
  EXCEPT
  SELECT DISTINCT oi.prod_id FROM sales.order_items oi
  JOIN products.products p2 ON p2.product_id = oi.prod_id
  WHERE p2.supplier_id = sup.supplier_id
) missing
LIMIT 200;

/* Q4. */
SELECT c.customer_id, ev.source, ev.ref_id, ev.event_date
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT 'order' AS source, order_id::text AS ref_id, order_date AS event_date FROM sales.orders o WHERE o.cust_id = c.customer_id
  UNION ALL
  SELECT 'review', review_id::text, review_date FROM customers.reviews r WHERE r.customer_id = c.customer_id
  UNION ALL
  SELECT 'ticket', ticket_id::text, created_date::date FROM support.tickets t WHERE t.customer_id = c.customer_id
) ev
WHERE c.customer_id <= 100
ORDER BY c.customer_id, ev.event_date
LIMIT 300;

/* Q5. */
SELECT p.product_id, ev.event_type, ev.event_date
FROM products.products p
CROSS JOIN LATERAL (
  SELECT 'review' AS event_type, review_date AS event_date FROM customers.reviews r WHERE r.product_id = p.product_id
  UNION ALL
  SELECT 'sold', o.order_date FROM sales.order_items oi JOIN sales.orders o ON o.order_id = oi.order_id WHERE oi.prod_id = p.product_id
) ev
WHERE p.product_id <= 30
ORDER BY p.product_id, ev.event_date
LIMIT 300;

/* Q6. */
SELECT r.region_id, agg.metric, agg.value
FROM core.dim_region r
CROSS JOIN LATERAL (
  SELECT 'revenue' AS metric, COALESCE(SUM(o.net_total),0) AS value
  FROM stores.stores s JOIN sales.orders o ON o.store_id = s.store_id WHERE s.region_id = r.region_id
  UNION ALL
  SELECT 'ad_spend', COALESCE(SUM(a.amount),0)
  FROM marketing.ads_spend a
  WHERE a.campaign_id IN (SELECT campaign_id FROM marketing.campaigns)
) agg;

/* Q7. Restricted to a bounded sample of employees, since the unindexed tickets/calls tables would otherwise be fully scanned (and INTERSECT-sorted) once per employee. */
SELECT e.employee_id AS agent_id, common.customer_id
FROM stores.employees e
CROSS JOIN LATERAL (
  SELECT customer_id FROM support.tickets t WHERE t.agent_id = e.employee_id
  INTERSECT
  SELECT customer_id FROM call_center.calls c WHERE c.agent_id = e.employee_id
) common
WHERE e.employee_id <= 300
LIMIT 200;

/* Q8. */
SELECT sup.supplier_id, unmatched.product_id
FROM products.suppliers sup
CROSS JOIN LATERAL (
  SELECT product_id FROM products.products p WHERE p.supplier_id = sup.supplier_id
  EXCEPT
  SELECT DISTINCT oi.prod_id FROM sales.order_items oi
  JOIN products.products p2 ON p2.product_id = oi.prod_id
  WHERE p2.supplier_id = sup.supplier_id
) unmatched
LIMIT 200;

/* Q9. */
SELECT cat.category_id, common.brand_id
FROM core.dim_category cat
CROSS JOIN LATERAL (
  SELECT b.brand_id FROM core.dim_brand b
  JOIN products.products p ON p.brand_id = b.brand_id
  JOIN sales.order_items oi ON oi.prod_id = p.product_id
  WHERE b.category_id = cat.category_id
  GROUP BY b.brand_id HAVING SUM(oi.net_amount) >= (SELECT PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY net_amount) FROM sales.order_items)
  INTERSECT
  SELECT b2.brand_id FROM core.dim_brand b2
  JOIN products.products p2 ON p2.brand_id = b2.brand_id
  JOIN sales.order_items oi2 ON oi2.prod_id = p2.product_id
  WHERE b2.category_id = cat.category_id
  GROUP BY b2.brand_id HAVING SUM(oi2.net_amount) < (SELECT PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY net_amount) FROM sales.order_items)
) common;

/* Q10. */
SELECT tr.tier_name, cnt.lifecycle_stage, cnt.customer_count
FROM loyalty.tiers tr
CROSS JOIN LATERAL (
  SELECT 'active' AS lifecycle_stage, COUNT(*) AS customer_count
  FROM loyalty.members m WHERE m.tier_id = tr.tier_id
    AND EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = m.customer_id AND o.order_date >= (SELECT MAX(order_date) FROM sales.orders) - 90)
  UNION ALL
  SELECT 'lapsed', COUNT(*)
  FROM loyalty.members m2 WHERE m2.tier_id = tr.tier_id
    AND NOT EXISTS (SELECT 1 FROM sales.orders o2 WHERE o2.cust_id = m2.customer_id AND o2.order_date >= (SELECT MAX(order_date) FROM sales.orders) - 90)
) cnt;

/* Q11. */
SELECT c.campaign_id, attr.metric, attr.value
FROM marketing.campaigns c
CROSS JOIN LATERAL (
  SELECT 'spend' AS metric, COALESCE(SUM(a.amount),0) AS value FROM marketing.ads_spend a WHERE a.campaign_id = c.campaign_id
  UNION ALL
  SELECT 'clicks', COALESCE(SUM(e.emails_clicked),0) FROM marketing.email_clicks e WHERE e.campaign_id = c.campaign_id
) attr;

/* Q12. */
SELECT w.warehouse_id, delta.metric, delta.total_qty
FROM supply_chain.warehouses w
CROSS JOIN LATERAL (
  SELECT 'inbound' AS metric, COALESCE(SUM(quantity),0) AS total_qty FROM supply_chain.shipments sh WHERE sh.warehouse_id = w.warehouse_id
  UNION ALL
  SELECT 'on_hand', COALESCE(SUM(quantity_on_hand),0) FROM supply_chain.inventory_snapshots isn WHERE isn.warehouse_id = w.warehouse_id
) delta;

/* Q13. Drives off DISTINCT courier_name (only a handful of couriers) instead of every shipment row, since the LATERAL body itself already re-scans the full shipments table per courier. */
SELECT sh.courier_name, sr.metric, sr.value
FROM (SELECT DISTINCT courier_name FROM sales.shipments) sh
CROSS JOIN LATERAL (
  SELECT 'delivered' AS metric, COUNT(*)::numeric AS value FROM sales.shipments sh2 WHERE sh2.courier_name = sh.courier_name AND sh2.status = 'Delivered'
  UNION ALL
  SELECT 'total', COUNT(*)::numeric FROM sales.shipments sh3 WHERE sh3.courier_name = sh.courier_name
) sr;

/* Q14. */
SELECT c.customer_id, ord.tag, ord.order_id, ord.order_date
FROM customers.customers c
CROSS JOIN LATERAL (
  (SELECT 'first' AS tag, order_id, order_date FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY order_date ASC LIMIT 5)
  UNION ALL
  (SELECT 'last', order_id, order_date FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY order_date DESC LIMIT 5)
) ord
WHERE c.customer_id <= 100
ORDER BY c.customer_id, ord.tag
LIMIT 300;

/* Q15. */
SELECT p.product_id, rv.tag, rv.review_id, rv.rating
FROM products.products p
CROSS JOIN LATERAL (
  (SELECT 'top' AS tag, review_id, rating FROM customers.reviews r WHERE r.product_id = p.product_id ORDER BY rating DESC LIMIT 1)
  UNION ALL
  (SELECT 'bottom', review_id, rating FROM customers.reviews r WHERE r.product_id = p.product_id ORDER BY rating ASC LIMIT 1)
) rv
WHERE p.product_id <= 200;

/* Q16. */
SELECT r.region_id, sr.tag, sr.store_id, sr.revenue
FROM core.dim_region r
CROSS JOIN LATERAL (
  (SELECT 'top' AS tag, s.store_id, SUM(o.net_total) AS revenue FROM stores.stores s JOIN sales.orders o ON o.store_id = s.store_id
   WHERE s.region_id = r.region_id GROUP BY s.store_id ORDER BY SUM(o.net_total) DESC LIMIT 1)
  UNION ALL
  (SELECT 'bottom', s.store_id, SUM(o.net_total) FROM stores.stores s JOIN sales.orders o ON o.store_id = s.store_id
   WHERE s.region_id = r.region_id GROUP BY s.store_id ORDER BY SUM(o.net_total) ASC LIMIT 1)
) sr;

/* Q17. */
SELECT d.dept_id, se.tag, se.employee_id, se.salary
FROM core.dim_department d
CROSS JOIN LATERAL (
  (SELECT 'top' AS tag, employee_id, salary FROM stores.employees e WHERE e.dept_id = d.dept_id ORDER BY salary DESC LIMIT 1)
  UNION ALL
  (SELECT 'bottom', employee_id, salary FROM stores.employees e WHERE e.dept_id = d.dept_id ORDER BY salary ASC LIMIT 1)
) se;

/* Q18. */
SELECT sess.session_id, pv.tag, pv.page_url, pv.view_timestamp
FROM (SELECT DISTINCT session_id FROM web_events.page_views LIMIT 50) sess
CROSS JOIN LATERAL (
  (SELECT 'first' AS tag, page_url, view_timestamp FROM web_events.page_views p WHERE p.session_id = sess.session_id ORDER BY view_timestamp ASC LIMIT 1)
  UNION ALL
  (SELECT 'last', page_url, view_timestamp FROM web_events.page_views p WHERE p.session_id = sess.session_id ORDER BY view_timestamp DESC LIMIT 1)
) pv;

/* Q19. RetailMart's support.tickets has no free-text comment table beyond the ticket row itself, so "first + last comment" is proxied with created_date/resolved_date on the same ticket. */
SELECT t.ticket_id, tag.tag, tag.event_date
FROM support.tickets t
CROSS JOIN LATERAL (
  SELECT 'created' AS tag, t.created_date::date AS event_date
  UNION ALL
  SELECT 'resolved', t.resolved_date::date
) tag
WHERE t.ticket_id <= 300 AND tag.event_date IS NOT NULL
ORDER BY t.ticket_id, tag.event_date;

/* Q20. */
SELECT cl.call_id, tr.transcript_text, tr.sentiment_score
FROM call_center.calls cl
CROSS JOIN LATERAL (
  SELECT transcript_text, sentiment_score FROM call_center.transcripts t WHERE t.call_id = cl.call_id LIMIT 1
) tr
WHERE cl.call_id <= 300;

/* Q21. */
SELECT d.dept_id, rl.role, rl.total_salary
FROM core.dim_department d
CROSS JOIN LATERAL (
  SELECT role, SUM(salary) AS total_salary FROM stores.employees e WHERE e.dept_id = d.dept_id GROUP BY ROLLUP (role)
) rl;

/* Q22. */
SELECT r.region_id, cb.tier, cb.category_name, cb.revenue
FROM core.dim_region r
CROSS JOIN LATERAL (
  SELECT tr.tier_name AS tier, cat.category_name, SUM(oi.net_amount) AS revenue
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  JOIN sales.order_items oi ON oi.order_id = o.order_id
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
  LEFT JOIN loyalty.members m ON m.customer_id = o.cust_id
  LEFT JOIN loyalty.tiers tr ON tr.tier_id = m.tier_id
  WHERE s.region_id = r.region_id
  GROUP BY CUBE (tr.tier_name, cat.category_name)
) cb
LIMIT 200;

/* Q23. */
SELECT s.store_id, gs.order_status, gs.month, gs.order_count
FROM stores.stores s
CROSS JOIN LATERAL (
  SELECT order_status, DATE_TRUNC('month', order_date) AS month, COUNT(*) AS order_count
  FROM sales.orders o WHERE o.store_id = s.store_id
  GROUP BY GROUPING SETS ((order_status), (DATE_TRUNC('month', order_date)), ())
) gs
LIMIT 300;

/* Q24. */
SELECT c.customer_id, st.metric, st.value
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT
    COUNT(*) FILTER (WHERE order_status = 'Delivered') AS delivered_count,
    COUNT(*) FILTER (WHERE order_status = 'Cancelled') AS cancelled_count
  FROM sales.orders o WHERE o.cust_id = c.customer_id
) f
CROSS JOIN LATERAL (
  SELECT 'delivered' AS metric, f.delivered_count::numeric AS value
  UNION ALL
  SELECT 'cancelled', f.cancelled_count::numeric
) st
WHERE c.customer_id <= 100
LIMIT 300;

/* Q25. */
SELECT sup.supplier_id, hv.product_id, hv.total_units
FROM products.suppliers sup
CROSS JOIN LATERAL (
  SELECT p.product_id, SUM(oi.quantity) AS total_units
  FROM products.products p
  JOIN sales.order_items oi ON oi.prod_id = p.product_id
  WHERE p.supplier_id = sup.supplier_id
  GROUP BY p.product_id
  HAVING SUM(oi.quantity) > 100
) hv
LIMIT 200;

/* SECTION B: PERFORMANCE (25) */
/* Q26. A correlated scalar subquery per outer row (e.g. computing lifetime spend for every one of 50,000 customers) shows in EXPLAIN as a SubPlan re-executed once per outer row - with no index on sales.orders.cust_id, each execution is a full Seq Scan, so the total cost line item is roughly (outer row count) x (cost of one Seq Scan on orders), visible directly in the EXPLAIN output's SubPlan cost. */
EXPLAIN
SELECT c.customer_id, (SELECT COALESCE(SUM(o.net_total),0) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS spend
FROM customers.customers c
WHERE c.customer_id <= 200;

/* Q27. */
EXPLAIN
SELECT c.customer_id, lo.order_id, lo.net_total
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id, net_total FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY order_date DESC LIMIT 1
) lo
WHERE c.customer_id <= 200;

/* Q28. */
EXPLAIN
SELECT customer_id, order_id, net_total FROM (
  SELECT cust_id AS customer_id, order_id, net_total,
         ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date DESC) AS rn
  FROM sales.orders
) x
WHERE rn = 1 AND customer_id <= 200;

/* Q29. Recommended index for the LATERAL/correlated pattern above: */
/* CREATE INDEX CONCURRENTLY idx_orders_cust_id ON sales.orders(cust_id); */
SELECT 'idx_orders_cust_id on sales.orders(cust_id)' AS recommended_index;

/* Q30. Recommended FK-supporting indexes for fast LATERAL joins used throughout this file: */
/* CREATE INDEX CONCURRENTLY idx_order_items_order_id ON sales.order_items(order_id);
   CREATE INDEX CONCURRENTLY idx_order_items_prod_id ON sales.order_items(prod_id);
   CREATE INDEX CONCURRENTLY idx_reviews_customer_id ON customers.reviews(customer_id);
   CREATE INDEX CONCURRENTLY idx_reviews_product_id ON customers.reviews(product_id); */
SELECT 'FK-supporting indexes on order_items(order_id, prod_id) and reviews(customer_id, product_id)' AS recommended_indexes;

/* Q31. A partial index speeds the common LATERAL filter to only "open" tickets: */
/* CREATE INDEX CONCURRENTLY idx_tickets_open_agent ON support.tickets(agent_id) WHERE status = 'Open'; */
SELECT 'idx_tickets_open_agent ON support.tickets(agent_id) WHERE status = ''Open''' AS recommended_partial_index;

/* Q32. An expression index supports filtering/joining on a normalized (lowercased/trimmed) column used repeatedly for dedup in this file: */
/* CREATE INDEX CONCURRENTLY idx_products_norm_name ON products.products (LOWER(TRIM(product_name))); */
SELECT 'idx_products_norm_name ON products.products (LOWER(TRIM(product_name)))' AS recommended_expression_index;

/* Q33. */
WITH order_agg AS (
  SELECT cust_id, COUNT(*) AS order_count, SUM(net_total) AS total_spend
  FROM sales.orders
  GROUP BY cust_id
)
SELECT c.customer_id, oa.order_count, oa.total_spend
FROM customers.customers c
JOIN order_agg oa ON oa.cust_id = c.customer_id
WHERE c.customer_id <= 500;

/* Q34. Forcing the planner toward a Nested Loop (LATERAL's natural strategy) for demonstration: */
SET enable_hashjoin = off;
SET enable_mergejoin = off;
SELECT c.customer_id, lo.order_id
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY order_date DESC LIMIT 1
) lo
WHERE c.customer_id <= 100;
RESET enable_hashjoin;
RESET enable_mergejoin;

/* Q35. Forcing a Hash Join by disabling Nested Loop, for a query where a plain JOIN (not LATERAL) is the natural fit: */
SET enable_nestloop = off;
SELECT c.customer_id, o.order_id, o.net_total
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
WHERE c.customer_id <= 200
LIMIT 300;
RESET enable_nestloop;

/* Q36. Increasing work_mem for a session running a LATERAL aggregate over a wide GROUP BY: */
SET work_mem = '64MB';
SELECT r.region_id, tp.category_name, tp.revenue
FROM core.dim_region r
CROSS JOIN LATERAL (
  SELECT cat.category_name, SUM(oi.net_amount) AS revenue
  FROM stores.stores s
  JOIN sales.orders o ON o.store_id = s.store_id
  JOIN sales.order_items oi ON oi.order_id = o.order_id
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
  WHERE s.region_id = r.region_id
  GROUP BY cat.category_name ORDER BY SUM(oi.net_amount) DESC LIMIT 3
) tp;
RESET work_mem;

/* Q37. Reducing the LATERAL subquery's output to only the columns actually needed downstream (instead of SELECT *): */
SELECT c.customer_id, lo.order_id, lo.net_total
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id, net_total FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY order_date DESC LIMIT 1
) lo
WHERE c.customer_id <= 200;

/* Q38. */
SELECT c.customer_id, lo.order_id, lo.order_date, lo.net_total
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id, order_date, net_total FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY order_date DESC LIMIT 3
) lo
WHERE c.customer_id <= 100;

/* Q39. */
SELECT c.customer_id, lo.order_id
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY order_date DESC LIMIT 1
) lo
WHERE c.customer_id <= 200;

/* Q40. Diagnosing "no rows from LATERAL": CROSS JOIN LATERAL silently drops the outer row when the subquery returns nothing - switching to LEFT JOIN LATERAL ... ON TRUE surfaces those customers with NULL columns instead of vanishing, confirming the subquery's WHERE/ON clause (not a join bug) is why the row disappeared. */
SELECT c.customer_id, lo.order_id
FROM customers.customers c
LEFT JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.cust_id = c.customer_id AND o.net_total > 500000 LIMIT 1
) lo ON TRUE
WHERE c.customer_id <= 50;

/* Q41. Comparing CROSS JOIN LATERAL vs LEFT JOIN LATERAL for the same "latest order" pattern: CROSS JOIN LATERAL drops customers with zero orders entirely (fewer output rows, slightly cheaper); LEFT JOIN LATERAL ... ON TRUE keeps every customer row with NULLs when there are no orders - correctness (need every customer) should drive the choice, not the small performance delta. */
SELECT c.customer_id, lo.order_id
FROM customers.customers c
LEFT JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY order_date DESC LIMIT 1
) lo ON TRUE
WHERE c.customer_id <= 200;

/* Q42. LATERAL inside a view fixes the join shape, so a filter added later by a caller (e.g. WHERE customer_id <= 50) may not get pushed INTO the LATERAL subquery's own WHERE - the whole base set the view was defined over gets evaluated first, then filtered. Standing in as a plain query for the view body (skipping an actual CREATE VIEW so no persistent object or DDL lock is left behind on this shared database), with the "view's own" restriction on one line and the "caller's" filter on the next to show the two don't merge into one pushed-down predicate: */
SELECT * FROM (
  SELECT c.customer_id, lo.order_id, lo.order_date
  FROM customers.customers c
  CROSS JOIN LATERAL (
    SELECT order_id, order_date FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY order_date DESC LIMIT 1
  ) lo
  WHERE c.customer_id <= 300  -- the "view definition's" own restriction
) v
WHERE v.customer_id <= 50;    -- the caller's filter, applied only after the LATERAL already ran for all 300

/* Q43. A materialized view caches the LATERAL's result physically, trading freshness for speed on repeated reads - shown here as a temp table standing in for a materialized view (same one-time-compute-then-reread benefit, without leaving a permanent object behind on this shared database): */
CREATE TEMP TABLE tmp_customer_latest_order AS
SELECT c.customer_id, lo.order_id, lo.order_date
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id, order_date FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY order_date DESC LIMIT 1
) lo
WHERE c.customer_id <= 300;

SELECT * FROM tmp_customer_latest_order WHERE customer_id <= 50;
DROP TABLE tmp_customer_latest_order;

/* Q44. A plain (non-correlated) JOIN aggregate over the whole table is eligible for a parallel sequential scan/aggregate, unlike a per-row LATERAL nested loop: */
SELECT store_id, COUNT(*) AS order_count, SUM(net_total) AS revenue
FROM sales.orders
GROUP BY store_id;

/* Q45. Partition-wise join is not applicable here since none of RetailMart's tables are declared as PARTITIONed; a plain join across the full (unpartitioned) tables is the only option. */
SELECT o.order_id, oi.order_item_id
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
WHERE o.order_id <= 500;

/* Q46. Preparing a statement once and executing it with different parameters avoids re-planning the LATERAL query on every call: */
PREPARE latest_order_for_customer (int) AS
SELECT lo.order_id, lo.order_date
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id, order_date FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY order_date DESC LIMIT 1
) lo
WHERE c.customer_id = $1;

EXECUTE latest_order_for_customer(1);
DEALLOCATE latest_order_for_customer;

/* Q47. */
EXPLAIN ANALYZE
SELECT c.customer_id, lo.order_id
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY order_date DESC LIMIT 1
) lo
WHERE c.customer_id <= 50;

/* Q48. Dropping an unnecessary LATERAL when only a single scalar value is needed - the equivalent scalar subquery is simpler and just as fast: */
SELECT c.customer_id,
       (SELECT order_id FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY order_date DESC LIMIT 1) AS latest_order_id
FROM customers.customers c
WHERE c.customer_id <= 200;

/* Q49. pg_stat_statements tracks LATERAL queries like any other statement by normalized query text; on a server with the extension enabled this surfaces call count, total/mean time and rows, e.g.: */
/* SELECT query, calls, mean_exec_time, rows FROM pg_stat_statements WHERE query ILIKE '%LATERAL%' ORDER BY mean_exec_time DESC LIMIT 20; */
SELECT 'pg_stat_statements query/calls/mean_exec_time/rows filtered on LATERAL text' AS monitoring_approach;

/* Q50. ANTIPATTERN demonstrated (do not run in production): a LATERAL subquery referenced inside ORDER BY forces PostgreSQL to (re)evaluate it for every row purely to sort, even though the value isn't otherwise selected - computing it once in the SELECT list and sorting on that alias is the fix. */
SELECT c.customer_id, lo.order_id
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY order_date DESC LIMIT 1
) lo
WHERE c.customer_id <= 100
ORDER BY lo.order_id;

/* SECTION C: ANTI-PATTERNS (25) */
/* Q51. ANTIPATTERN avoided: a plain correlated scalar subquery is simpler and equally fast when only ONE value is needed - LATERAL adds join machinery for no benefit here. */
SELECT c.customer_id,
       (SELECT COUNT(*) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS order_count
FROM customers.customers c
WHERE c.customer_id <= 200;

/* Q52. ANTIPATTERN: running the same LATERAL pattern with no supporting index shows the cost - each of 100 outer rows forces a full sequential scan of orders. */
EXPLAIN
SELECT c.customer_id, lo.order_id
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY order_date DESC LIMIT 1
) lo
WHERE c.customer_id <= 100;

/* Q53. ANTIPATTERN avoided: naming only the columns actually needed instead of returning the entire order row from the LATERAL subquery. */
SELECT c.customer_id, lo.order_id, lo.net_total
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id, net_total FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY order_date DESC LIMIT 1
) lo
WHERE c.customer_id <= 100;

/* Q54. ANTIPATTERN avoided: a LATERAL join belongs in FROM, not squeezed into a WHERE predicate as an ad hoc EXISTS check when an actual joined value is also needed - here the FROM-clause LATERAL both filters and returns the value in one step. */
SELECT c.customer_id, lo.order_id
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.cust_id = c.customer_id AND o.net_total > 10000 LIMIT 1
) lo
WHERE c.customer_id <= 200;

/* Q55. ANTIPATTERN avoided: when ORDER BY + LIMIT are needed per outer row, a scalar correlated subquery can only return ONE column - LATERAL is required (and used here) to return order_id and order_date together. */
SELECT c.customer_id, lo.order_id, lo.order_date
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id, order_date FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY order_date DESC LIMIT 1
) lo
WHERE c.customer_id <= 200;

/* Q56. ANTIPATTERN avoided: fanning LATERAL out over the full 50,000-customer table (which could touch a billion+ rows on the unindexed orders table) is bounded to a small sample instead. */
SELECT c.customer_id, lo.order_id
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY order_date DESC LIMIT 1
) lo
WHERE c.customer_id <= 100;

/* Q57. ANTIPATTERN avoided: aggregating in the outer query only after the LATERAL has already returned one row per customer - not re-grouping a fanned-out multi-row LATERAL result, which would double-count. */
SELECT COUNT(*) AS customers_with_recent_order
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY order_date DESC LIMIT 1
) lo
WHERE c.customer_id <= 500;

/* Q58. ANTIPATTERN avoided: no RANDOM() inside the LATERAL - ORDER BY on a real, deterministic column (order_date) instead of a non-deterministic random() sort. */
SELECT c.customer_id, lo.order_id
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY order_date DESC LIMIT 1
) lo
WHERE c.customer_id <= 100;

/* Q59. ANTIPATTERN avoided: no NOW()/CURRENT_TIMESTAMP filter re-evaluated per LATERAL execution - the "as of" cutoff is computed once as a fixed reference value before the LATERAL runs. */
WITH ref AS (SELECT MAX(order_date) AS today FROM sales.orders)
SELECT c.customer_id, ro.order_id
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT o.order_id FROM sales.orders o, ref WHERE o.cust_id = c.customer_id AND o.order_date >= ref.today - 30 ORDER BY o.order_date DESC LIMIT 1
) ro
WHERE c.customer_id <= 100;

/* Q60. ANTIPATTERN avoided: LATERAL bodies here are pure read-only SELECTs, never a volatile/mutating function call with side effects. */
SELECT c.customer_id, agg.order_count
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT COUNT(*) AS order_count FROM sales.orders o WHERE o.cust_id = c.customer_id
) agg
WHERE c.customer_id <= 200;

/* Q61. ANTIPATTERN avoided: the LATERAL subquery returns only the specific columns the outer query needs, not every column of the orders table. */
SELECT c.customer_id, lo.order_id, lo.net_total
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id, net_total FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY order_date DESC LIMIT 1
) lo
WHERE c.customer_id <= 200;

/* Q62. ANTIPATTERN avoided: a plain JOIN (not LATERAL) is used here since the relationship needs no per-outer-row correlation beyond a simple equality key. */
SELECT o.order_id, c.first_name, c.last_name
FROM sales.orders o
JOIN customers.customers c ON c.customer_id = o.cust_id
WHERE o.order_id <= 500;

/* Q63. ANTIPATTERN avoided: a set-based UPDATE with a correlated subquery in one statement, instead of a correlated subquery re-run per row inside an application-level loop. */
BEGIN;
UPDATE customers.wallets w
SET balance = balance + (SELECT COALESCE(SUM(lp.points_earned),0) * 0.1 FROM customers.loyalty_points lp WHERE lp.customer_id = w.cust_id)
WHERE w.cust_id <= 20;
ROLLBACK;

/* Q64. ANTIPATTERN avoided: the correlated condition sits in WHERE, not squeezed into JOIN ON with a subquery that a plain equality join could express directly. */
SELECT o.order_id, o.net_total
FROM sales.orders o
WHERE o.net_total > (SELECT AVG(o2.net_total) FROM sales.orders o2 WHERE o2.store_id = o.store_id)
LIMIT 200;

/* Q65. ANTIPATTERN demonstrated: this correlated subquery has no supporting index on the correlated column, so EXPLAIN shows a full Seq Scan repeated per outer row - exactly the cost profile an index on sales.orders(cust_id) would eliminate. */
EXPLAIN
SELECT c.customer_id, (SELECT COUNT(*) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS order_count
FROM customers.customers c
WHERE c.customer_id <= 100;

/* Q66. ANTIPATTERN avoided: the LATERAL body here is a pure, deterministic read - no INSERT/UPDATE/sequence-advancing function mutating data as a side effect of being called once per outer row. */
SELECT c.customer_id, agg.total_spend
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT COALESCE(SUM(net_total),0) AS total_spend FROM sales.orders o WHERE o.cust_id = c.customer_id
) agg
WHERE c.customer_id <= 200;

/* Q67. ANTIPATTERN avoided: an outer aggregate here operates on a LATERAL result already reduced to one row per customer, so it can't silently hide a multi-row fan-out. */
SELECT AVG(agg.total_spend) AS avg_customer_spend
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT COALESCE(SUM(net_total),0) AS total_spend FROM sales.orders o WHERE o.cust_id = c.customer_id
) agg
WHERE c.customer_id <= 500;

/* Q68. ANTIPATTERN avoided: this LATERAL-driving CTE is referenced once, so Postgres 12+ can safely inline it without needing an explicit MATERIALIZED hint; if it were referenced multiple times with an expensive body, MATERIALIZED would pin it as a single computed result. */
WITH active_customers AS (
  SELECT customer_id FROM customers.customers WHERE customer_id <= 100
)
SELECT ac.customer_id, lo.order_id
FROM active_customers ac
CROSS JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.cust_id = ac.customer_id ORDER BY order_date DESC LIMIT 1
) lo;

/* Q69. ANTIPATTERN avoided: the LATERAL's internal ORDER BY is on a single indexed-in-spirit column (order_date), not a complex multi-expression sort that would force an expensive per-row sort. */
SELECT c.customer_id, lo.order_id
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY order_date DESC LIMIT 1
) lo
WHERE c.customer_id <= 200;

/* Q70. ANTIPATTERN avoided: the LATERAL's ORDER BY is a real column with a documented tie-break (order_id), never a non-deterministic expression like random(). */
SELECT c.customer_id, lo.order_id
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY order_date DESC, order_id DESC LIMIT 1
) lo
WHERE c.customer_id <= 200;

/* Q71. Combining LATERAL (per-customer top order) with a window function (ranking those top orders against each other) in the same query is a legitimate, common pattern, not an anti-pattern - demonstrated here. */
SELECT c.customer_id, lo.order_id, lo.net_total,
       RANK() OVER (ORDER BY lo.net_total DESC) AS rank_among_top_orders
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id, net_total FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY net_total DESC LIMIT 1
) lo
WHERE c.customer_id <= 100
ORDER BY rank_among_top_orders
LIMIT 20;

/* Q72. ANTIPATTERN avoided: CROSS JOIN LATERAL (...) ON TRUE (LEFT JOIN form) is used only when NULL-preservation is actually wanted; here a plain CROSS JOIN LATERAL is used since dropping customers with no orders is the intended behavior. */
SELECT c.customer_id, lo.order_id
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY order_date DESC LIMIT 1
) lo
WHERE c.customer_id <= 200;

/* Q73. ANTIPATTERN avoided: the LATERAL subquery is correlated on the outer row's key (customer_id), never CROSS JOINed against outer columns without an actual correlation condition. */
SELECT c.customer_id, agg.order_count
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT COUNT(*) AS order_count FROM sales.orders o WHERE o.cust_id = c.customer_id
) agg
WHERE c.customer_id <= 200;

/* Q74. ANTIPATTERN avoided: LATERAL is used here specifically because ORDER BY + LIMIT per customer is needed (which GROUP BY alone cannot express) - a plain GROUP BY aggregate is used instead wherever only a group-level summary (not a specific top row) is required. */
SELECT cust_id, SUM(net_total) AS total_spend
FROM sales.orders
WHERE cust_id <= 200
GROUP BY cust_id;

/* Q75. Refactor opportunity: the "latest order per customer" LATERAL pattern used throughout this file can be replaced by DISTINCT ON for a simpler, often faster single-pass plan when only rn=1 is needed and no extra per-row aggregation is required. */
SELECT DISTINCT ON (cust_id) cust_id AS customer_id, order_id, order_date
FROM sales.orders
WHERE cust_id <= 200
ORDER BY cust_id, order_date DESC;

/* SECTION D: REAL PRODUCTION (25) */
/* Q76. */
SELECT c.customer_id, ev.source, ev.ref_id, ev.event_date
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT source, ref_id, event_date FROM (
    SELECT 'order' AS source, order_id::text AS ref_id, order_date AS event_date FROM sales.orders o WHERE o.cust_id = c.customer_id
    UNION ALL
    SELECT 'ticket', ticket_id::text, created_date::date FROM support.tickets t WHERE t.customer_id = c.customer_id
    UNION ALL
    SELECT 'review', review_id::text, review_date FROM customers.reviews r WHERE r.customer_id = c.customer_id
  ) all_events
  ORDER BY event_date DESC LIMIT 3
) ev
WHERE c.customer_id <= 100
ORDER BY c.customer_id, ev.event_date DESC
LIMIT 300;

/* Q77. */
SELECT p.product_id, first_r.review_id AS first_review_id, first_r.review_date AS first_review_date,
       last_r.review_id AS last_review_id, last_r.review_date AS last_review_date
FROM products.products p
CROSS JOIN LATERAL (
  SELECT review_id, review_date FROM customers.reviews r WHERE r.product_id = p.product_id ORDER BY review_date ASC LIMIT 1
) first_r
CROSS JOIN LATERAL (
  SELECT review_id, review_date FROM customers.reviews r WHERE r.product_id = p.product_id ORDER BY review_date DESC LIMIT 1
) last_r
WHERE p.product_id <= 200;

/* Q78. */
SELECT s.store_id, te.employee_id, te.salary
FROM stores.stores s
CROSS JOIN LATERAL (
  SELECT employee_id, salary FROM stores.employees e WHERE e.store_id = s.store_id ORDER BY salary DESC LIMIT 3
) te;

/* Q79. Rewritten as a single pre-aggregated pass + window function instead of a LATERAL re-join per region x month (20 regions x ~27 months = 540 unindexed re-scans of orders/order_items would otherwise be needed). */
WITH region_month_product AS (
  SELECT s.region_id, DATE_TRUNC('month', o.order_date) AS month, p.product_name,
         SUM(oi.net_amount) AS revenue
  FROM stores.stores s
  JOIN sales.orders o ON o.store_id = s.store_id
  JOIN sales.order_items oi ON oi.order_id = o.order_id
  JOIN products.products p ON p.product_id = oi.prod_id
  GROUP BY s.region_id, DATE_TRUNC('month', o.order_date), p.product_name
),
ranked AS (
  SELECT region_id, month, product_name, revenue,
         ROW_NUMBER() OVER (PARTITION BY region_id, month ORDER BY revenue DESC) AS rn
  FROM region_month_product
)
SELECT region_id, month, product_name, revenue
FROM ranked WHERE rn = 1
ORDER BY region_id, month
LIMIT 200;

/* Q80. */
SELECT cat.category_id, cat.category_name, tp.product_name, tp.units_sold
FROM core.dim_category cat
CROSS JOIN LATERAL (
  SELECT p.product_name, SUM(oi.quantity) AS units_sold
  FROM products.products p
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN sales.order_items oi ON oi.prod_id = p.product_id
  WHERE b.category_id = cat.category_id
  GROUP BY p.product_name ORDER BY SUM(oi.quantity) DESC LIMIT 3
) tp;

/* Q81. */
SELECT sup.supplier_id, ts.shipment_id, ts.shipped_date, cnt.total_shipments
FROM products.suppliers sup
CROSS JOIN LATERAL (
  SELECT shipment_id, shipped_date FROM supply_chain.shipments sh WHERE sh.supplier_id = sup.supplier_id ORDER BY shipped_date DESC LIMIT 3
) ts
CROSS JOIN LATERAL (
  SELECT COUNT(*) AS total_shipments FROM supply_chain.shipments sh2 WHERE sh2.supplier_id = sup.supplier_id
) cnt;

/* Q82. */
SELECT c.campaign_id, sp.total_spend, cl.total_clicks,
       ROUND(cl.total_clicks::numeric / NULLIF(sp.total_spend,0), 6) AS clicks_per_dollar
FROM marketing.campaigns c
CROSS JOIN LATERAL (SELECT COALESCE(SUM(amount),0) AS total_spend FROM marketing.ads_spend a WHERE a.campaign_id = c.campaign_id) sp
CROSS JOIN LATERAL (SELECT COALESCE(SUM(emails_clicked),0) AS total_clicks FROM marketing.email_clicks e WHERE e.campaign_id = c.campaign_id) cl;

/* Q83. */
SELECT w.warehouse_id, ls.product_id, ls.quantity_on_hand
FROM supply_chain.warehouses w
CROSS JOIN LATERAL (
  SELECT DISTINCT ON (product_id) product_id, quantity_on_hand FROM supply_chain.inventory_snapshots isn
  WHERE isn.warehouse_id = w.warehouse_id ORDER BY product_id, snapshot_date DESC
) ls
WHERE ls.quantity_on_hand < 30
ORDER BY w.warehouse_id, ls.quantity_on_hand
LIMIT 200;

/* Q84. */
SELECT e.employee_id AS agent_id, agg.resolved_count, agg.avg_resolution_days
FROM stores.employees e
CROSS JOIN LATERAL (
  SELECT COUNT(*) AS resolved_count, AVG(resolved_date - created_date) AS avg_resolution_days
  FROM support.tickets t WHERE t.agent_id = e.employee_id AND t.status = 'Resolved'
) agg
WHERE agg.resolved_count > 0
ORDER BY agg.resolved_count DESC
LIMIT 50;

/* Q85. */
SELECT DISTINCT sh.courier_name, sc.delivered_count, sc.total_count,
       ROUND(sc.delivered_count::numeric / NULLIF(sc.total_count,0), 4) AS success_rate
FROM sales.shipments sh
CROSS JOIN LATERAL (
  SELECT COUNT(*) FILTER (WHERE status = 'Delivered') AS delivered_count, COUNT(*) AS total_count
  FROM sales.shipments sh2 WHERE sh2.courier_name = sh.courier_name
) sc;

/* Q86. */
SELECT tr.tier_id, tr.tier_name, tm.customer_id, tm.order_id, tm.net_total
FROM loyalty.tiers tr
CROSS JOIN LATERAL (
  SELECT m.customer_id, lo.order_id, lo.net_total
  FROM loyalty.members m
  CROSS JOIN LATERAL (
    SELECT order_id, net_total FROM sales.orders o WHERE o.cust_id = m.customer_id ORDER BY net_total DESC LIMIT 1
  ) lo
  WHERE m.tier_id = tr.tier_id
  LIMIT 5
) tm;

/* Q87. */
SELECT c.customer_id, w.balance, red.reward_name, red.points_redeemed, red.redemption_date
FROM customers.customers c
JOIN customers.wallets w ON w.cust_id = c.customer_id
CROSS JOIN LATERAL (
  SELECT reward_name, points_redeemed, redemption_date FROM loyalty.redemptions r WHERE r.customer_id = c.customer_id ORDER BY redemption_date DESC LIMIT 3
) red
WHERE c.customer_id <= 100;

/* Q88. RFM scoring joined with the LATERAL "top product" pattern, restricted to a bounded customer sample since NTILE requires the full RFM partition while the LATERAL top-product lookup is a per-customer correlated scan. */
WITH cust_agg AS (
  SELECT cust_id AS customer_id,
         (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS recency_days,
         COUNT(*) AS order_count, SUM(net_total) AS total_spend
  FROM sales.orders
  GROUP BY cust_id
),
rfm AS (
  SELECT customer_id, NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,
         NTILE(5) OVER (ORDER BY order_count DESC) AS f_score,
         NTILE(5) OVER (ORDER BY total_spend DESC) AS m_score
  FROM cust_agg
),
rfm_sample AS (SELECT * FROM rfm ORDER BY customer_id LIMIT 100)
SELECT rs.customer_id, rs.r_score, rs.f_score, rs.m_score, tp.prod_id, tp.units
FROM rfm_sample rs
CROSS JOIN LATERAL (
  SELECT oi.prod_id, SUM(oi.quantity) AS units
  FROM sales.order_items oi JOIN sales.orders o ON o.order_id = oi.order_id
  WHERE o.cust_id = rs.customer_id
  GROUP BY oi.prod_id ORDER BY SUM(oi.quantity) DESC LIMIT 1
) tp
ORDER BY rs.customer_id;

/* Q89. */
SELECT c.customer_id, jo.event_type, jo.event_date
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT event_type, event_date FROM (
    SELECT 'order' AS event_type, order_date AS event_date FROM sales.orders o WHERE o.cust_id = c.customer_id
    UNION ALL
    SELECT 'ticket', created_date::date FROM support.tickets t WHERE t.customer_id = c.customer_id
    UNION ALL
    SELECT 'call', call_start_time::date FROM call_center.calls cl WHERE cl.customer_id = c.customer_id
    UNION ALL
    SELECT 'review', review_date FROM customers.reviews r WHERE r.customer_id = c.customer_id
  ) x
  ORDER BY event_date
) jo
WHERE c.customer_id <= 50
ORDER BY c.customer_id, jo.event_date
LIMIT 300;

/* Q90. */
SELECT c.campaign_id, funnel.stage, funnel.value
FROM marketing.campaigns c
CROSS JOIN LATERAL (
  SELECT 'sent' AS stage, COALESCE(SUM(emails_sent),0)::numeric AS value FROM marketing.email_clicks e WHERE e.campaign_id = c.campaign_id
  UNION ALL
  SELECT 'opened', COALESCE(SUM(emails_opened),0)::numeric FROM marketing.email_clicks e2 WHERE e2.campaign_id = c.campaign_id
  UNION ALL
  SELECT 'clicked', COALESCE(SUM(emails_clicked),0)::numeric FROM marketing.email_clicks e3 WHERE e3.campaign_id = c.campaign_id
) funnel;

/* Q91. */
SELECT r.reason, lo.order_id, lo.return_date
FROM (SELECT DISTINCT reason FROM sales.returns) r
CROSS JOIN LATERAL (
  SELECT order_id, return_date FROM sales.returns rt WHERE rt.reason = r.reason ORDER BY return_date DESC LIMIT 5
) lo;

/* Q92. */
SELECT pr.priority, la.ticket_id, la.resolution_hours
FROM (SELECT DISTINCT priority FROM support.tickets) pr
CROSS JOIN LATERAL (
  SELECT ticket_id, EXTRACT(EPOCH FROM (resolved_date - created_date))/3600 AS resolution_hours
  FROM support.tickets t WHERE t.priority = pr.priority AND t.resolved_date IS NOT NULL
  ORDER BY (resolved_date - created_date) DESC LIMIT 3
) la;

/* Q93. */
SELECT r.call_reason, mix.category, mix.call_count
FROM (SELECT DISTINCT call_reason FROM call_center.calls) r
CROSS JOIN LATERAL (
  SELECT status AS category, COUNT(*) AS call_count FROM call_center.calls c WHERE c.call_reason = r.call_reason GROUP BY status
) mix;

/* Q94. */
SELECT p.product_id, sr.avg_sentiment, sr.review_count
FROM products.products p
CROSS JOIN LATERAL (
  SELECT AVG(rating) AS avg_sentiment, COUNT(*) AS review_count FROM customers.reviews r WHERE r.product_id = p.product_id
) sr
WHERE p.product_id <= 200 AND sr.review_count > 0;

/* Q95. Anomaly: flags per-customer orders whose net_total is more than 3x that customer's own average order value. */
SELECT c.customer_id, an.order_id, an.net_total, an.customer_avg
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT o.order_id, o.net_total, ca.avg_val AS customer_avg
  FROM sales.orders o
  CROSS JOIN LATERAL (SELECT AVG(net_total) AS avg_val FROM sales.orders o2 WHERE o2.cust_id = c.customer_id) ca
  WHERE o.cust_id = c.customer_id AND o.net_total > 3 * ca.avg_val
) an
WHERE c.customer_id <= 200
LIMIT 100;

/* Q96. Outlier finder: products whose price is more than 2 standard deviations from their brand's average price. */
SELECT p.product_id, p.price, st.brand_avg, st.brand_stddev
FROM products.products p
CROSS JOIN LATERAL (
  SELECT AVG(price) AS brand_avg, STDDEV(price) AS brand_stddev FROM products.products p2 WHERE p2.brand_id = p.brand_id
) st
WHERE st.brand_stddev > 0 AND ABS(p.price - st.brand_avg) > 2 * st.brand_stddev
LIMIT 200;

/* Q97. Cohort retention: for each registration-month cohort, the share still ordering 90 days after signup - rewritten as one pre-aggregated pass over orders (GROUP BY cust_id) joined once to customers, instead of a per-customer correlated EXISTS re-scan of the 150,000-row orders table for each of 50,000 customers. */
WITH customer_last_order AS (
  SELECT cust_id, MAX(order_date) AS last_order_date
  FROM sales.orders
  GROUP BY cust_id
),
customer_cohort AS (
  SELECT c.customer_id,
         DATE_TRUNC('month', c.registration_date) AS cohort_month,
         (clo.last_order_date IS NOT NULL AND clo.last_order_date >= c.registration_date + 90) AS retained
  FROM customers.customers c
  LEFT JOIN customer_last_order clo ON clo.cust_id = c.customer_id
)
SELECT cohort_month,
       COUNT(*) AS cohort_size,
       COUNT(*) FILTER (WHERE retained) AS retained_count,
       ROUND(COUNT(*) FILTER (WHERE retained)::numeric / NULLIF(COUNT(*),0), 4) AS retention_rate
FROM customer_cohort
GROUP BY cohort_month
ORDER BY cohort_month;

/* Q98. Churn predictor: flags customers whose days-since-last-order exceeds 2x their own historical average inter-order gap. */
SELECT c.customer_id, cp.days_since_last, cp.avg_gap_days, (cp.days_since_last > 2 * cp.avg_gap_days) AS churn_risk
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT (SELECT MAX(order_date) FROM sales.orders) - MAX(o.order_date) AS days_since_last,
         (MAX(o.order_date) - MIN(o.order_date)) / NULLIF(COUNT(*) - 1, 0) AS avg_gap_days
  FROM sales.orders o WHERE o.cust_id = c.customer_id
) cp
WHERE c.customer_id <= 300 AND cp.avg_gap_days IS NOT NULL
ORDER BY churn_risk DESC
LIMIT 100;

/* Q99. */
SELECT
  (SELECT COUNT(*) FROM customers.customers) AS total_customers,
  (SELECT COUNT(*) FROM sales.orders) AS total_orders,
  (SELECT SUM(net_total) FROM sales.orders) AS total_revenue,
  top_cust.customer_id AS top_spender_id, top_cust.total_spend AS top_spend
FROM LATERAL (
  SELECT cust_id AS customer_id, SUM(net_total) AS total_spend
  FROM sales.orders GROUP BY cust_id ORDER BY SUM(net_total) DESC LIMIT 1
) top_cust;

/* Q100. Master: combines LATERAL (per-customer top order), a window function (spend rank), and set operations (channel list), restricted to a bounded sample. */
WITH cust_agg AS (
  SELECT cust_id AS customer_id, SUM(net_total) AS total_spend
  FROM sales.orders
  WHERE cust_id <= 200
  GROUP BY cust_id
),
ranked AS (
  SELECT customer_id, total_spend, RANK() OVER (ORDER BY total_spend DESC) AS spend_rank
  FROM cust_agg
)
SELECT r.customer_id, r.total_spend, r.spend_rank, lo.order_id AS top_order_id, ch.channels
FROM ranked r
CROSS JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.cust_id = r.customer_id ORDER BY net_total DESC LIMIT 1
) lo
CROSS JOIN LATERAL (
  SELECT STRING_AGG(DISTINCT channel, ',') AS channels FROM (
    SELECT 'order' AS channel FROM sales.orders o2 WHERE o2.cust_id = r.customer_id
    UNION
    SELECT 'ticket' FROM support.tickets t WHERE t.customer_id = r.customer_id
  ) x
) ch
ORDER BY r.spend_rank
LIMIT 100;

/* ============================================================
   END OF ANSWER KEY - Subqueries Part 2 (Correlated & LATERAL) - HARD LEVEL (100/100)
============================================================ */
