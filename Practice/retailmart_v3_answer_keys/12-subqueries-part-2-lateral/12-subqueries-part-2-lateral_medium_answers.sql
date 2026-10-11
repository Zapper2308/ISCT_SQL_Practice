/* ============================================================
   ANSWER KEY - Subqueries Part 2 (Correlated & LATERAL) (MEDIUM LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: DEEPER CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1.  Only for simple, non-aggregated correlated predicates (equality/IN/EXISTS with a single-column correlation and no volatile functions) can Postgres flatten a correlated subquery into a semi/anti-join; anything with aggregates, LIMIT, or multi-step logic inside stays a genuine per-row SubPlan. */
/* Q2.  LATERAL is a join by definition - if its subquery returns more than one row for a given outer row, that outer row is repeated once per matching lateral row, exactly like any other join with multiple matches. */
/* Q3.  A LATERAL subquery can reference any FROM item listed before it, including two separate earlier tables/CTEs at once, correlating on both simultaneously in its WHERE clause. */
/* Q4.  LEFT JOIN LATERAL (...) ON TRUE and CROSS JOIN LATERAL (...) behave identically when the subquery returns rows; they diverge only when it returns zero rows - ON TRUE keeps the outer row with NULLs, CROSS JOIN LATERAL drops it. */
/* Q5.  Embedding LATERAL inside a view fixes that join's shape and order permanently; a later query against the view with an additional filter may not get that filter pushed down into the lateral subquery as efficiently as if it had been written directly. */
/* Q6.  Because LATERAL is inherently "for each outer row, run this," the natural execution strategy is a Nested Loop where the inner side is (re-)planned and executed once per outer row using that row's values. */
/* Q7.  LATERAL is PostgreSQL's/standard-SQL equivalent of SQL Server's CROSS APPLY (inner-join semantics) and OUTER APPLY (left-join semantics) - same correlated-derived-table concept, different keyword. */
/* Q8.  Each LATERAL execution behaves like a subquery with the outer row's column values bound as parameters, conceptually similar to a prepared statement re-executed with new parameters per outer row. */
/* Q9.  A LATERAL subquery can reference the output columns of an earlier LATERAL subquery in the same FROM clause, letting you build a multi-step, per-row pipeline where each stage drives the next. */
/* Q10. GROUP BY in the outer query operates on the already-joined, possibly fanned-out result including the LATERAL's columns, so if the LATERAL returned multiple rows per outer row, grouping afterward re-aggregates across all of them - order of operations matters. */
/* Q11. Yes - a LATERAL subquery can itself be a full subquery in FROM with its own nested FROM/JOIN/WHERE, as long as its correlation still only reaches earlier FROM items of the outer query. */
/* Q12. RETURNING is only valid on the top-level DML statement, not inside a LATERAL subquery - LATERAL is purely a SELECT/FROM-clause construct with no RETURNING of its own. */
/* Q13. A LATERAL subquery returns genuine multi-column, multi-row output joined into the query; a scalar subquery returning a composite type packs a whole row into one value that must then be decomposed (e.g. (subq).col) to use individual fields. */
/* Q14. A set-returning function used with LATERAL produces one row per element it returns, correlated to whichever outer row drove that call - functionally the same join shape as a lateral subquery. */
/* Q15. Without an index on the correlated join column inside the lateral subquery, every outer row triggers a full sequential scan of the inner table - a per-row cost that should be a fast lookup becomes a full scan multiplied by the outer row count. */
/* Q16. A window function can run inside the LATERAL subquery's own SELECT, computed only over the rows that subquery pulls for that one outer row - e.g. "rank within just this customer's own orders." */
/* Q17. LATERAL + ORDER BY + LIMIT 1 and DISTINCT ON both give "one row per group"; DISTINCT ON is simpler/faster for exactly one row, while LATERAL is more flexible (any N rows, extra per-row aggregates, multi-column correlation). */
/* Q18. Semantically, Postgres evaluates the LATERAL subquery once per row produced by the FROM items preceding it - the driving row count, not the number of tables joined, is what determines how many times it conceptually runs. */
/* Q19. An ORDER BY inside a LATERAL subquery only controls that subquery's own internal row order (e.g. which rows a LIMIT keeps) - it has no effect on the outer query's final row order, which needs its own top-level ORDER BY. */
/* Q20. A LATERAL subquery's SELECT can construct and return ROW(...) as a single composite-typed column, though returning the individual columns directly is more common and more useful downstream. */
/* Q21. A LATERAL subquery's body can be a UNION ALL of multiple SELECTs, letting one lateral join combine rows from different sources per outer row (e.g. "this customer's orders UNION ALL this customer's returns"). */
/* Q22. EXISTS can appear inside a LATERAL subquery's SELECT list or WHERE clause exactly as in any subquery, evaluated fresh with that particular lateral execution's correlated values. */
/* Q23. NOT EXISTS works the same way inside a LATERAL subquery, letting you compute a per-outer-row "no match" flag alongside other lateral-derived columns in the same joined row. */
/* Q24. A LATERAL subquery's SELECT can include a CASE expression whose condition or branches reference the outer row, so exactly what gets returned can vary per outer row. */
/* Q25. Yes - a LATERAL subquery can contain its own WITH RECURSIVE block, letting each outer row drive an independent recursive computation (e.g. a hierarchy walk starting from that specific row). */

/* ============================================================
   SECTION B: CORRELATED DEEPER (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT c.customer_id,
       (SELECT COUNT(*) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS orders,
       (SELECT COALESCE(SUM(o.net_total),0) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS spend,
       (SELECT COUNT(*) FROM customers.reviews r WHERE r.customer_id = c.customer_id) AS reviews,
       (SELECT COUNT(*) FROM support.tickets t WHERE t.customer_id = c.customer_id) AS tickets,
       (SELECT MAX(o.order_date) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS last_order
FROM customers.customers c
LIMIT 200;

/* Q27. */
SELECT c.customer_id,
       (SELECT MIN(o.net_total) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS min_order,
       (SELECT MAX(o.net_total) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS max_order
FROM customers.customers c
LIMIT 200;

/* Q28. */
SELECT s.store_id,
       (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o2.net_total) FROM sales.orders o2 WHERE o2.store_id = s.store_id) AS median_order
FROM stores.stores s
LIMIT 200;

/* Q29. */
SELECT c.customer_id,
       (SELECT COUNT(*) FILTER (WHERE o.order_status = 'Cancelled') FROM sales.orders o WHERE o.cust_id = c.customer_id) AS cancelled_orders
FROM customers.customers c
LIMIT 200;

/* Q30. */
SELECT s.warehouse_id, s.product_id,
       (SELECT quantity FROM supply_chain.shipments sh WHERE sh.warehouse_id = s.warehouse_id AND sh.product_id = s.product_id ORDER BY shipped_date DESC LIMIT 1) AS last_shipment_qty
FROM supply_chain.inventory_snapshots s
LIMIT 200;

/* Q31. */
SELECT * FROM (
  SELECT c.customer_id,
         (SELECT COUNT(*) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS orders
  FROM customers.customers c
  LIMIT 200
) cust_view;

/* Q32. */
SELECT * FROM products.products p
WHERE EXISTS (SELECT 1 FROM sales.order_items oi WHERE oi.prod_id = p.product_id)
  AND EXISTS (SELECT 1 FROM customers.reviews r WHERE r.product_id = p.product_id)
LIMIT 200;

/* Q33. */
SELECT * FROM products.products p
WHERE NOT EXISTS (SELECT 1 FROM sales.order_items oi WHERE oi.prod_id = p.product_id)
  AND NOT EXISTS (SELECT 1 FROM customers.reviews r WHERE r.product_id = p.product_id);

/* Q34. */
SELECT o.store_id, SUM(o.net_total) AS revenue
FROM sales.orders o
GROUP BY o.store_id
HAVING SUM(o.net_total) > (SELECT COUNT(*) FROM stores.employees e WHERE e.store_id = o.store_id) * 100000;

/* Q35. */
SELECT p.product_id, p.product_name
FROM products.products p
WHERE p.product_id <= 500
ORDER BY (SELECT COUNT(*) FROM customers.reviews r WHERE r.product_id = p.product_id) DESC;

/* Q36. */
SELECT * FROM (SELECT * FROM customers.customers LIMIT 300) c
WHERE (SELECT COUNT(*) FROM loyalty.members m WHERE m.customer_id = c.customer_id) = 1;

/* Q37. */
SELECT c.customer_id,
       (SELECT ARRAY_AGG(o.order_id) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS order_ids
FROM customers.customers c
LIMIT 200;

/* Q38. */
SELECT c.customer_id,
       (SELECT jsonb_agg(jsonb_build_object('order_id', o.order_id, 'net_total', o.net_total)) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS orders_json
FROM customers.customers c
LIMIT 200;

/* Q39. */
SELECT c.customer_id,
       (SELECT o FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY o.order_date DESC LIMIT 1) AS latest_order_row
FROM customers.customers c
LIMIT 200;

/* Q40. */
SELECT o.order_id, o.cust_id, o.order_date,
       (SELECT MAX(o2.order_date) FROM sales.orders o2 WHERE o2.cust_id = o.cust_id AND o2.order_date < o.order_date) AS prior_order_date
FROM (SELECT * FROM sales.orders LIMIT 300) o;

/* Q41. */
SELECT o.order_id, o.cust_id, o.order_date,
       (SELECT MIN(o2.order_date) FROM sales.orders o2 WHERE o2.cust_id = o.cust_id AND o2.order_date > o.order_date) AS next_order_date
FROM (SELECT * FROM sales.orders LIMIT 300) o;

/* Q42. */
SELECT c.customer_id,
       EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id AND o.order_date >= (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '90 days') AS is_active
FROM customers.customers c
LIMIT 300;

/* Q43. */
SELECT c.customer_id,
       EXISTS (SELECT 1 FROM finance.payments p WHERE p.cust_id = c.customer_id AND p.status = 'Failed') AS is_delinquent
FROM customers.customers c
LIMIT 300;

/* Q44. */
SELECT c.customer_id,
       (SELECT COUNT(*) FROM sales.orders o WHERE o.cust_id = c.customer_id AND o.order_date >= (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '7 days') > 3 AS is_fraud_risk
FROM customers.customers c
LIMIT 300;

/* Q45. */
SELECT m.customer_id,
       m.points_balance >= (SELECT min_points FROM loyalty.tiers WHERE tier_id = m.tier_id + 1) AS upgrade_eligible
FROM loyalty.members m
WHERE m.tier_id < 4
LIMIT 300;

/* Q46. */
SELECT c.customer_id,
       (SELECT MAX(o.order_date) FROM sales.orders o WHERE o.cust_id = c.customer_id) < (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '120 days' AS churn_risk
FROM customers.customers c
LIMIT 300;

/* Q47. */
SELECT c.customer_id,
       EXISTS (SELECT 1 FROM loyalty.members m WHERE m.customer_id = c.customer_id) AS is_loyalty_member
FROM customers.customers c
LIMIT 300;

/* Q48. */
SELECT c.customer_id,
       CASE
         WHEN (SELECT COUNT(*) FROM sales.orders o WHERE o.cust_id = c.customer_id) = 0 THEN 'Prospect'
         WHEN (SELECT MAX(o.order_date) FROM sales.orders o WHERE o.cust_id = c.customer_id) >= (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '90 days' THEN 'Active'
         ELSE 'Lapsed'
       END AS lifetime_stage
FROM customers.customers c
LIMIT 300;

/* Q49. */
SELECT c.customer_id,
       c.tier IN ('Gold','Platinum') AS is_premium
FROM customers.customers c
LIMIT 300;

/* Q50. */
SELECT c.customer_id,
       (SELECT s.region_id FROM customers.addresses a JOIN stores.stores s ON s.city = a.city WHERE a.customer_id = c.customer_id LIMIT 1) AS geo_zone_region_id
FROM customers.customers c
LIMIT 300;

/* ============================================================
   SECTION C: LATERAL CHAINS (25)
   ------------------------------------------------------------ */
/* Q51. */
SELECT c.customer_id, lo.order_id, li.items_count
FROM (SELECT * FROM customers.customers LIMIT 100) c
CROSS JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY order_date DESC LIMIT 1
) lo
CROSS JOIN LATERAL (
  SELECT COUNT(*) AS items_count FROM sales.order_items oi WHERE oi.order_id = lo.order_id
) li;

/* Q52. */
SELECT c.customer_id, lo.order_id, li.prod_id, lp.product_name
FROM (SELECT * FROM customers.customers LIMIT 50) c
CROSS JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY order_date DESC LIMIT 1
) lo
CROSS JOIN LATERAL (
  SELECT prod_id FROM sales.order_items oi WHERE oi.order_id = lo.order_id LIMIT 1
) li
CROSS JOIN LATERAL (
  SELECT product_name FROM products.products p WHERE p.product_id = li.prod_id
) lp;

/* Q53. */
SELECT r.region_id, s.store_id, e.employee_count
FROM core.dim_region r
CROSS JOIN LATERAL (
  SELECT store_id FROM stores.stores st WHERE st.region_id = r.region_id ORDER BY store_id LIMIT 1
) s
CROSS JOIN LATERAL (
  SELECT COUNT(*) AS employee_count FROM stores.employees emp WHERE emp.store_id = s.store_id
) e;

/* Q54. */
SELECT c.customer_id, oc.order_count, rc.review_count
FROM customers.customers c
CROSS JOIN LATERAL (SELECT COUNT(*) AS order_count FROM sales.orders o WHERE o.cust_id = c.customer_id) oc
CROSS JOIN LATERAL (SELECT COUNT(*) AS review_count FROM customers.reviews r WHERE r.customer_id = c.customer_id) rc
LIMIT 300;

/* Q55. */
SELECT c.customer_id, seg.label
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT CASE WHEN COUNT(*) = 0 THEN 'No Orders' WHEN COUNT(*) < 5 THEN 'Light' ELSE 'Heavy' END AS label
  FROM sales.orders o WHERE o.cust_id = c.customer_id
) seg
LIMIT 300;

/* Q56. */
SELECT c.customer_id, t.total
FROM customers.customers c
CROSS JOIN LATERAL (
  WITH cust_orders AS (SELECT * FROM sales.orders o WHERE o.cust_id = c.customer_id)
  SELECT COALESCE(SUM(net_total),0) AS total FROM cust_orders
) t
LIMIT 300;

/* Q57. */
SELECT c.customer_id, ev.source
FROM (SELECT * FROM customers.customers LIMIT 100) c
CROSS JOIN LATERAL (
  SELECT 'order' AS source FROM sales.orders o WHERE o.cust_id = c.customer_id
  UNION
  SELECT 'ticket' FROM support.tickets t WHERE t.customer_id = c.customer_id
) ev;

/* Q58. */
SELECT c.customer_id, ranked.order_id, ranked.rn
FROM (SELECT * FROM customers.customers LIMIT 100) c
CROSS JOIN LATERAL (
  SELECT order_id, ROW_NUMBER() OVER (ORDER BY net_total DESC) AS rn
  FROM sales.orders o WHERE o.cust_id = c.customer_id
) ranked
WHERE ranked.rn <= 2;

/* Q59. */
SELECT c.customer_id, by_status.order_status, by_status.cnt
FROM (SELECT * FROM customers.customers LIMIT 100) c
CROSS JOIN LATERAL (
  SELECT order_status, COUNT(*) AS cnt FROM sales.orders o WHERE o.cust_id = c.customer_id GROUP BY order_status
) by_status;

/* Q60. */
SELECT c.customer_id, flag.has_review
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT CASE WHEN EXISTS (SELECT 1 FROM customers.reviews r WHERE r.customer_id = c.customer_id) THEN 'Yes' ELSE 'No' END AS has_review
) flag
LIMIT 300;

/* Q61. */
SELECT c.campaign_id, cal.day
FROM (SELECT * FROM marketing.campaigns LIMIT 5) c
CROSS JOIN LATERAL generate_series(c.start_date, c.end_date, INTERVAL '1 day') AS cal(day);

/* Q62. */
SELECT w.warehouse_id, ds.d
FROM supply_chain.warehouses w
CROSS JOIN LATERAL generate_series('2026-01-01'::date, '2026-01-07'::date, INTERVAL '1 day') AS ds(d);

/* Q63. */
SELECT c.customer_id, agg.order_ids
FROM (SELECT * FROM customers.customers LIMIT 100) c
CROSS JOIN LATERAL (
  SELECT ARRAY_AGG(order_id ORDER BY order_date DESC) AS order_ids FROM sales.orders o WHERE o.cust_id = c.customer_id
) agg;

/* Q64. */
SELECT c.customer_id, agg.status_counts
FROM (SELECT * FROM customers.customers LIMIT 100) c
CROSS JOIN LATERAL (
  SELECT jsonb_object_agg(order_status, cnt) AS status_counts
  FROM (SELECT order_status, COUNT(*) AS cnt FROM sales.orders o WHERE o.cust_id = c.customer_id GROUP BY order_status) s
) agg;

/* Q65. */
SELECT c.customer_id, t.order_id
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.cust_id = c.customer_id
  ORDER BY net_total DESC, order_date ASC LIMIT 1
) t
LIMIT 300;

/* Q66. */
SELECT c.customer_id, t.order_id, t.net_total, tot.total_spend
FROM (SELECT * FROM customers.customers LIMIT 100) c
CROSS JOIN LATERAL (
  SELECT order_id, net_total FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY net_total DESC LIMIT 3
) t
CROSS JOIN LATERAL (
  SELECT COALESCE(SUM(net_total),0) AS total_spend FROM sales.orders o2 WHERE o2.cust_id = c.customer_id
) tot;

/* Q67. */
SELECT c.customer_id, fnn.contact
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT COALESCE(c.email, c.phone, 'unknown') AS contact
) fnn
LIMIT 300;

/* Q68. */
SELECT c.customer_id, t.last_order_date
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT COALESCE(MAX(o.order_date), '1900-01-01'::date) AS last_order_date
  FROM sales.orders o WHERE o.cust_id = c.customer_id
) t
LIMIT 300;

/* Q69. */
SELECT c.customer_id, cmp.above_avg
FROM customers.customers c
CROSS JOIN LATERAL (
  SELECT COALESCE(SUM(o.net_total),0) > (SELECT AVG(net_total) FROM sales.orders) AS above_avg
  FROM sales.orders o WHERE o.cust_id = c.customer_id
) cmp
LIMIT 300;

/* Q70. */
SELECT o.order_id, se.store_name, se.region_name
FROM (SELECT * FROM sales.orders LIMIT 300) o
CROSS JOIN LATERAL (
  SELECT s.store_name, r.region_name
  FROM stores.stores s JOIN core.dim_region r ON r.region_id = s.region_id
  WHERE s.store_id = o.store_id
) se;

/* Q71. */
SELECT p.product_id, missing.metric
FROM (SELECT * FROM products.products LIMIT 100) p
CROSS JOIN LATERAL (
  SELECT 'no_reviews' AS metric
  EXCEPT
  SELECT 'no_reviews' WHERE EXISTS (SELECT 1 FROM customers.reviews r WHERE r.product_id = p.product_id)
) missing;

/* Q72. */
SELECT c.customer_id, act.activity
FROM (SELECT * FROM customers.customers LIMIT 100) c
CROSS JOIN LATERAL (
  SELECT 'has_orders' AS activity WHERE EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id)
  UNION
  SELECT 'has_reviews' WHERE EXISTS (SELECT 1 FROM customers.reviews r WHERE r.customer_id = c.customer_id)
) act;

/* Q73. */
SELECT c.customer_id, big_months.month, big_months.spend
FROM (SELECT * FROM customers.customers LIMIT 100) c
CROSS JOIN LATERAL (
  SELECT DATE_TRUNC('month', o.order_date) AS month, SUM(o.net_total) AS spend
  FROM sales.orders o WHERE o.cust_id = c.customer_id
  GROUP BY DATE_TRUNC('month', o.order_date)
  HAVING SUM(o.net_total) > 10000
) big_months;

/* Q74. */
SELECT c.customer_id, rl.order_status, rl.total
FROM (SELECT * FROM customers.customers LIMIT 50) c
CROSS JOIN LATERAL (
  SELECT order_status, SUM(net_total) AS total
  FROM sales.orders o WHERE o.cust_id = c.customer_id
  GROUP BY ROLLUP (order_status)
) rl;

/* Q75. */
SELECT s.store_id, pct.median_order
FROM stores.stores s
CROSS JOIN LATERAL (
  SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total) AS median_order
  FROM sales.orders o WHERE o.store_id = s.store_id
) pct;

/* ============================================================
   SECTION D: LATERAL + WINDOW COMBO (25)
   ------------------------------------------------------------ */
/* Q76. */
SELECT c.customer_id, t.order_id, t.rn
FROM (SELECT * FROM customers.customers LIMIT 100) c
CROSS JOIN LATERAL (
  SELECT order_id, ROW_NUMBER() OVER (ORDER BY order_date DESC) AS rn FROM sales.orders o WHERE o.cust_id = c.customer_id
) t
WHERE t.rn <= 3;

/* Q77. */
SELECT c.customer_id, t.order_id, t.rnk
FROM (SELECT * FROM customers.customers LIMIT 100) c
CROSS JOIN LATERAL (
  SELECT order_id, RANK() OVER (ORDER BY net_total DESC) AS rnk FROM sales.orders o WHERE o.cust_id = c.customer_id
) t
WHERE t.rnk = 1;

/* Q78. */
SELECT c.customer_id, t.order_id, t.bucket
FROM (SELECT * FROM customers.customers LIMIT 100) c
CROSS JOIN LATERAL (
  SELECT order_id, NTILE(4) OVER (ORDER BY net_total) AS bucket FROM sales.orders o WHERE o.cust_id = c.customer_id
) t;

/* Q79. */
SELECT c.customer_id, t.order_id, t.order_date, t.prev_date
FROM (SELECT * FROM customers.customers LIMIT 100) c
CROSS JOIN LATERAL (
  SELECT order_id, order_date, LAG(order_date) OVER (ORDER BY order_date) AS prev_date
  FROM sales.orders o WHERE o.cust_id = c.customer_id
) t;

/* Q80. */
SELECT c.customer_id, t.order_id, t.first_order, t.last_order
FROM (SELECT * FROM customers.customers LIMIT 100) c
CROSS JOIN LATERAL (
  SELECT order_id,
         FIRST_VALUE(order_id) OVER (ORDER BY order_date) AS first_order,
         LAST_VALUE(order_id) OVER (ORDER BY order_date ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_order
  FROM sales.orders o WHERE o.cust_id = c.customer_id
) t;

/* Q81. */
SELECT c.customer_id, t.order_id, t.pct_rank
FROM (SELECT * FROM customers.customers LIMIT 100) c
CROSS JOIN LATERAL (
  SELECT order_id, PERCENT_RANK() OVER (ORDER BY net_total) AS pct_rank FROM sales.orders o WHERE o.cust_id = c.customer_id
) t;

/* Q82. */
SELECT c.customer_id, t.order_id, t.cume_dist
FROM (SELECT * FROM customers.customers LIMIT 100) c
CROSS JOIN LATERAL (
  SELECT order_id, CUME_DIST() OVER (ORDER BY net_total) AS cume_dist FROM sales.orders o WHERE o.cust_id = c.customer_id
) t;

/* Q83. */
SELECT c.customer_id, t.order_id, t.order_date, t.running_total
FROM (SELECT * FROM customers.customers LIMIT 100) c
CROSS JOIN LATERAL (
  SELECT order_id, order_date, SUM(net_total) OVER (ORDER BY order_date ROWS UNBOUNDED PRECEDING) AS running_total
  FROM sales.orders o WHERE o.cust_id = c.customer_id
) t;

/* Q84. */
SELECT c.customer_id, t.order_id, t.order_date, t.running_avg
FROM (SELECT * FROM customers.customers LIMIT 100) c
CROSS JOIN LATERAL (
  SELECT order_id, order_date, AVG(net_total) OVER (ORDER BY order_date ROWS UNBOUNDED PRECEDING) AS running_avg
  FROM sales.orders o WHERE o.cust_id = c.customer_id
) t;

/* Q85. */
SELECT c.customer_id, t.order_id, t.order_date, t.moving_avg_3
FROM (SELECT * FROM customers.customers LIMIT 100) c
CROSS JOIN LATERAL (
  SELECT order_id, order_date,
         AVG(net_total) OVER (ORDER BY order_date ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS moving_avg_3
  FROM sales.orders o WHERE o.cust_id = c.customer_id
) t;

/* Q86. */
SELECT c.customer_id, t.order_id, t.order_status, t.rn_in_status
FROM (SELECT * FROM customers.customers LIMIT 100) c
CROSS JOIN LATERAL (
  SELECT order_id, order_status,
         ROW_NUMBER() OVER (PARTITION BY order_status ORDER BY order_date DESC) AS rn_in_status
  FROM sales.orders o WHERE o.cust_id = c.customer_id
) t;

/* Q87. */
SELECT c.customer_id, t.order_id, t.order_date
FROM (SELECT * FROM customers.customers LIMIT 100) c
CROSS JOIN LATERAL (
  SELECT order_id, order_date FROM sales.orders o
  WHERE o.cust_id = c.customer_id
    AND o.order_date >= (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '90 days'
  ORDER BY order_date ASC LIMIT 1
) t;

/* Q88. */
SELECT c.customer_id, t.order_id
FROM (SELECT * FROM customers.customers LIMIT 100) c
CROSS JOIN LATERAL (
  SELECT order_id FROM sales.orders o WHERE o.cust_id = c.customer_id
  ORDER BY order_date ASC OFFSET 1 LIMIT 1
) t;

/* Q89. */
SELECT c.customer_id, t.order_id, t.order_date
FROM (SELECT * FROM customers.customers LIMIT 100) c
CROSS JOIN LATERAL (
  SELECT order_id, order_date FROM sales.orders o
  WHERE o.cust_id = c.customer_id
    AND o.order_date >= (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '90 days'
  ORDER BY order_date DESC LIMIT 1
) t;

/* Q90. */
SELECT c.customer_id, t.order_id, t.net_total, t.net_total - t.prev_total AS delta_vs_prev
FROM (SELECT * FROM customers.customers LIMIT 100) c
CROSS JOIN LATERAL (
  SELECT order_id, net_total, LAG(net_total) OVER (ORDER BY order_date) AS prev_total
  FROM sales.orders o WHERE o.cust_id = c.customer_id
) t;

/* Q91. */
SELECT c.customer_id, t.order_id, t.net_total,
       t.net_total - FIRST_VALUE(t.net_total) OVER (ORDER BY t.order_date) AS delta_vs_first
FROM (SELECT * FROM customers.customers LIMIT 100) c
CROSS JOIN LATERAL (
  SELECT order_id, order_date, net_total FROM sales.orders o WHERE o.cust_id = c.customer_id
) t;

/* Q92. */
SELECT p.product_id, t.rnk
FROM (SELECT * FROM products.products LIMIT 200) p
CROSS JOIN LATERAL (
  SELECT COUNT(*) + 1 AS rnk FROM products.products p2 WHERE p2.brand_id = p.brand_id AND p2.price > p.price
) t;

/* Q93. */
SELECT m.customer_id, t.rnk
FROM (SELECT * FROM loyalty.members LIMIT 200) m
CROSS JOIN LATERAL (
  SELECT COUNT(*) + 1 AS rnk
  FROM loyalty.members m2
  WHERE m2.tier_id = m.tier_id AND m2.points_balance > m.points_balance
) t;

/* Q94. */
SELECT c.customer_id, t.pct_rank
FROM (SELECT * FROM customers.customers LIMIT 100) c
CROSS JOIN LATERAL (
  SELECT PERCENT_RANK() OVER (ORDER BY spend) AS pct_rank
  FROM (
    SELECT c2.customer_id, COALESCE(SUM(o.net_total),0) AS spend
    FROM customers.customers c2
    LEFT JOIN sales.orders o ON o.cust_id = c2.customer_id
    WHERE DATE_TRUNC('month', c2.registration_date) = DATE_TRUNC('month', c.registration_date)
    GROUP BY c2.customer_id
  ) cohort
  WHERE cohort.customer_id = c.customer_id
) t;

/* Q95. */
SELECT c.customer_id, t.this_year, t.last_year
FROM (SELECT * FROM customers.customers LIMIT 100) c
CROSS JOIN LATERAL (
  SELECT
    SUM(net_total) FILTER (WHERE EXTRACT(YEAR FROM order_date) = 2025) AS this_year,
    SUM(net_total) FILTER (WHERE EXTRACT(YEAR FROM order_date) = 2024) AS last_year
  FROM sales.orders o WHERE o.cust_id = c.customer_id
) t;

/* Q96. */
SELECT c.customer_id, t.month, t.spend, t.prev_month_spend
FROM (SELECT * FROM customers.customers LIMIT 50) c
CROSS JOIN LATERAL (
  SELECT month, spend, LAG(spend) OVER (ORDER BY month) AS prev_month_spend
  FROM (
    SELECT DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS spend
    FROM sales.orders o WHERE o.cust_id = c.customer_id
    GROUP BY DATE_TRUNC('month', order_date)
  ) m
) t;

/* Q97. */
SELECT c.customer_id, t.order_date, t.rolling_7d_total
FROM (SELECT * FROM customers.customers LIMIT 50) c
CROSS JOIN LATERAL (
  SELECT order_date,
         SUM(net_total) OVER (ORDER BY order_date RANGE BETWEEN INTERVAL '6 days' PRECEDING AND CURRENT ROW) AS rolling_7d_total
  FROM sales.orders o WHERE o.cust_id = c.customer_id
) t;

/* Q98. */
SELECT c.customer_id, t.order_date, t.rolling_30d_total
FROM (SELECT * FROM customers.customers LIMIT 50) c
CROSS JOIN LATERAL (
  SELECT order_date,
         SUM(net_total) OVER (ORDER BY order_date RANGE BETWEEN INTERVAL '29 days' PRECEDING AND CURRENT ROW) AS rolling_30d_total
  FROM sales.orders o WHERE o.cust_id = c.customer_id
) t;

/* Q99. */
SELECT c.customer_id, t.order_date, t.rolling_90d_total
FROM (SELECT * FROM customers.customers LIMIT 50) c
CROSS JOIN LATERAL (
  SELECT order_date,
         SUM(net_total) OVER (ORDER BY order_date RANGE BETWEEN INTERVAL '89 days' PRECEDING AND CURRENT ROW) AS rolling_90d_total
  FROM sales.orders o WHERE o.cust_id = c.customer_id
) t;

/* Q100. */
SELECT c.customer_id, t.orders, t.spend, t.avg_order, t.reviews, t.tickets
FROM (SELECT * FROM customers.customers LIMIT 100) c
CROSS JOIN LATERAL (
  SELECT
    (SELECT COUNT(*) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS orders,
    (SELECT COALESCE(SUM(o.net_total),0) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS spend,
    (SELECT COALESCE(AVG(o.net_total),0) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS avg_order,
    (SELECT COUNT(*) FROM customers.reviews r WHERE r.customer_id = c.customer_id) AS reviews,
    (SELECT COUNT(*) FROM support.tickets tk WHERE tk.customer_id = c.customer_id) AS tickets
) t;

/* ============================================================
   END OF ANSWER KEY - Subqueries Part 2 (Correlated & LATERAL) - MEDIUM LEVEL (100/100)
============================================================ */
