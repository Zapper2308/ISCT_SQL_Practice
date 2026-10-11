/* ============================================================
   ANSWER KEY - Subqueries Part 1 (MEDIUM LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: SUBQUERIES DEEPER - CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1.  A correlated subquery is conceptually re-run once per outer row (it references the outer row's columns), while an uncorrelated subquery runs once total - so correlated versions do more total work unless the planner can flatten them into a join. */
/* Q2.  The planner rewrites a subquery to a JOIN (semi/anti-join) when it's an uncorrelated or simply-correlated IN/EXISTS/NOT EXISTS predicate whose result doesn't change the row multiplicity of the outer query. */
/* Q3.  A derived table (FROM subquery) and a CTE can express the same logic; a CTE is named once and can be referenced by that name multiple times in the outer query, while a derived table's definition must be repeated (or joined once) inline. */
/* Q4.  It's common because `=` requires exactly one row back; a WHERE clause inside the subquery that isn't selective enough (or a JOIN inside it that fans out) silently returns multiple rows and PostgreSQL errors at execution time. */
/* Q5.  LIMIT 1 is needed whenever the subquery could naturally return more than one row but only one value is needed by the outer expression (e.g. one "most recent" row per group). */
/* Q6.  ORDER BY is required before LIMIT 1 so the "one" row returned is deterministically the desired one (e.g. the latest date) rather than an arbitrary row the planner happens to pick first. */
/* Q7.  An uncorrelated (constant) EXISTS is evaluated once and its boolean result reused for every outer row; a correlated EXISTS must consider the outer row's values and is evaluated (or converted to a semi-join) per row. */
/* Q8.  WHERE x IN (...) checks membership in a subquery's result set; WHERE x = ANY(VALUES (...)) explicitly builds a row set via VALUES and compares - functionally similar, but VALUES is handy for literal in-line lists with multiple columns. */
/* Q9.  Both can return the same rows, but IN (subquery) is typically planned as a semi-join while an explicit JOIN can return duplicate outer rows if the inner side has multiple matches (unless DISTINCT/aggregation is added), so their result sets can diverge when the child table isn't unique per parent. */
/* Q10. NOT IN returns 0 rows surprisingly whenever the subquery's result set contains even a single NULL, because comparing anything against NULL yields UNKNOWN, and UNKNOWN AND'd across the whole NOT IN list makes every row fail. */
/* Q11. NOT EXISTS is NULL-safe because it only checks row existence via a correlated equality test per row - a NULL in an unrelated column of the subquery's rows never affects the boolean existence check. */
/* Q12. A scalar subquery returns one value per outer row with no duplication; a JOIN to an aggregate (GROUP BY) can fan out the outer row if not properly aggregated first, so care is needed to keep row counts stable when switching between the two styles. */
/* Q13. It's called a "derived table" because its rows are derived (computed) from other tables, and an "inline view" because it behaves exactly like a view defined inline, scoped only to that one query. */
/* Q14. A LATERAL subquery can reference columns from earlier FROM items and re-evaluate per outer row (enabling correlated joins in FROM); a plain "subquery in FROM" cannot see any outer row - it's a fixed, independently-computed derived table. */
/* Q15. A HAVING filter (WHERE-style) applies a fixed value/condition to grouped aggregates; a HAVING subquery instead compares the aggregate to a dynamically-computed value (e.g. another aggregate), so the threshold isn't hardcoded. */
/* Q16. Postgres requires derived tables to have an alias so every column in the outer query can be unambiguously qualified back to its source relation, the same rule as for any other FROM item. */
/* Q17. HAVING SUM(x) > (subquery) recomputes/compares live against another aggregate every time; pre-aggregating in a CTE/derived table first (WHERE on the pre-aggregated result) can be clearer and sometimes cheaper if the pre-aggregate is reused elsewhere. */
/* Q18. "Subquery flattening" is the planner's transformation of a subquery in WHERE/FROM into an equivalent join whenever that preserves the query's meaning, avoiding a separate nested execution step. */
/* Q19. WHERE filters individual rows before any grouping happens, so an aggregate function (which needs a whole group of rows to compute) isn't defined yet at that stage - that's precisely why HAVING exists, to filter after aggregation. */
/* Q20. A scalar subquery in SELECT adds one extra computed value per existing row without changing the query's grouping; adding a column to GROUP BY changes what counts as one "row" for aggregation, which can multiply the output row count and change every aggregate's result. */
/* Q21. "Subquery factoring" is Oracle's term for exactly what Postgres calls a CTE (WITH clause) - naming a subquery once so it can be referenced by name. */
/* Q22. Each row's SELECT-list subquery logically re-runs a full round of execution per outer row, mirroring the classic N+1 pattern (1 query to list rows, N to fetch each row's extra data) even though it's expressed as a single SQL statement. */
/* Q23. WHERE col = (subquery) expects a single value and errors if more than one row is returned; WHERE col IN (set) is designed to accept any number of values from the subquery and matches on any of them. */
/* Q24. Because computing ORDER BY (subquery) means evaluating that subquery once for every row before the sort can even begin (there's no way to sort without a computed key for every row), unlike a WHERE subquery which can sometimes be turned into an efficient join/filter first. */
/* Q25. The planner picks a Hash Semi Join (build a hash table of the subquery's distinct keys, probe once per outer row) when the subquery's result set is large/cheap to hash and no useful index exists; it prefers a Nested Loop (often with an index) when the outer set is small or an index on the inner correlated column makes per-row lookups cheap. */

/* ============================================================
   SECTION B: IN / EXISTS DEEPER (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT * FROM customers.customers c
WHERE EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id)
  AND EXISTS (SELECT 1 FROM customers.reviews r WHERE r.customer_id = c.customer_id);

/* Q27. */
SELECT * FROM customers.customers c
WHERE EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id)
  AND NOT EXISTS (SELECT 1 FROM customers.reviews r WHERE r.customer_id = c.customer_id);

/* Q28. */
SELECT * FROM customers.customers c
WHERE EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id AND EXTRACT(YEAR FROM o.order_date) = 2024)
  AND EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id AND EXTRACT(YEAR FROM o.order_date) = 2025);

/* Q29. */
SELECT * FROM products.products p
WHERE p.price > 1000
  AND EXISTS (
    SELECT 1 FROM customers.reviews r
    WHERE r.product_id = p.product_id
      AND r.review_date >= (SELECT MAX(review_date) FROM customers.reviews) - INTERVAL '30 days'
  );

/* Q30. */
SELECT * FROM stores.stores s
WHERE EXISTS (SELECT 1 FROM stores.employees e WHERE e.store_id = s.store_id)
  AND EXISTS (SELECT 1 FROM sales.orders o WHERE o.store_id = s.store_id)
  AND EXISTS (SELECT 1 FROM products.inventory i WHERE i.store_id = s.store_id);

/* Q31. */
SELECT DISTINCT b1.brand_name
FROM core.dim_brand b1
JOIN core.dim_category c1 ON c1.category_id = b1.category_id AND c1.category_name = 'Electronics'
WHERE EXISTS (
  SELECT 1 FROM core.dim_brand b2
  JOIN core.dim_category c2 ON c2.category_id = b2.category_id AND c2.category_name = 'Fashion'
  WHERE b2.brand_name = b1.brand_name
);

/* Q32. */
SELECT DISTINCT c.*
FROM customers.customers c
JOIN customers.addresses a ON a.customer_id = c.customer_id
WHERE EXISTS (SELECT 1 FROM stores.stores s WHERE s.city = a.city);

/* Q33. */
SELECT * FROM products.products p
WHERE EXISTS (SELECT 1 FROM products.suppliers s WHERE s.supplier_id = p.supplier_id AND s.city = 'Mumbai')
  AND EXISTS (
    SELECT 1 FROM supply_chain.shipments sh
    WHERE sh.product_id = p.product_id
      AND sh.shipped_date >= (SELECT MAX(shipped_date) FROM supply_chain.shipments) - INTERVAL '60 days'
  );

/* Q34. */
SELECT * FROM support.tickets t
WHERE t.customer_id IN (SELECT cust_id FROM sales.orders GROUP BY cust_id HAVING COUNT(*) > 5);

/* Q35. */
SELECT * FROM payroll.pay_slips ps
WHERE ps.employee_id IN (
  SELECT employee_id FROM stores.employees
  WHERE store_id IN (SELECT store_id FROM stores.employees GROUP BY store_id HAVING COUNT(*) > 10)
);

/* Q36. */
SELECT * FROM sales.orders o WHERE o.cust_id IN (SELECT customer_id FROM loyalty.members);

/* Q37. */
SELECT * FROM sales.orders o WHERE o.cust_id NOT IN (SELECT customer_id FROM loyalty.members WHERE customer_id IS NOT NULL);

/* Q38. */
SELECT * FROM products.products p
WHERE p.brand_id IN (
  SELECT b.brand_id FROM core.dim_brand b
  WHERE b.category_id IN (
    SELECT b2.category_id FROM products.products p2
    JOIN core.dim_brand b2 ON b2.brand_id = p2.brand_id
    GROUP BY b2.category_id HAVING COUNT(*) > 100
  )
);

/* Q39. */
SELECT * FROM products.products p
WHERE p.brand_id IN (SELECT brand_id FROM products.products GROUP BY brand_id HAVING AVG(price) > 5000);

/* Q40. */
SELECT DISTINCT c.*
FROM customers.customers c
JOIN loyalty.members m ON m.customer_id = c.customer_id
WHERE m.tier_id IN (SELECT tier_id FROM loyalty.members GROUP BY tier_id HAVING COUNT(*) > 1000);

/* Q41. */
SELECT o.* FROM sales.orders o
WHERE o.order_id IN (
  SELECT s.order_id FROM sales.shipments s
  WHERE s.courier_name IN (
    SELECT courier_name FROM sales.shipments
    WHERE delivered_date IS NOT NULL
    GROUP BY courier_name
    HAVING AVG(delivered_date - shipped_date) < 3
  )
);

/* Q42. */
SELECT * FROM marketing.ads_spend a
WHERE a.campaign_id IN (
  SELECT campaign_id FROM marketing.campaigns
  WHERE start_date <= '2025-03-31' AND end_date >= '2025-03-01'
);

/* Q43. */
SELECT * FROM customers.reviews r
WHERE r.product_id IN (SELECT prod_id FROM sales.order_items GROUP BY prod_id HAVING COUNT(*) > 5);

/* Q44. */
SELECT * FROM support.tickets t
WHERE t.customer_id IN (
  SELECT o.cust_id FROM sales.returns rt JOIN sales.orders o ON o.order_id = rt.order_id
);

/* Q45. */
SELECT * FROM call_center.calls c
WHERE c.customer_id IN (
  SELECT customer_id FROM customers.reviews
  WHERE product_id IN (SELECT product_id FROM customers.reviews GROUP BY product_id HAVING AVG(rating) < 3)
);

/* Q46. */
SELECT * FROM web_events.page_views pv
WHERE pv.session_id IN (SELECT session_id FROM web_events.page_views WHERE page_url = '/checkout');

/* Q47. */
SELECT * FROM supply_chain.inventory_snapshots s
WHERE EXISTS (
  SELECT 1 FROM supply_chain.shipments sh
  WHERE sh.warehouse_id = s.warehouse_id AND sh.product_id = s.product_id
);

/* Q48. */
SELECT * FROM products.products p
WHERE NOT EXISTS (
  SELECT 1 FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  WHERE oi.prod_id = p.product_id AND o.order_status = 'Delivered'
);

/* Q49. */
SELECT * FROM customers.customers c
WHERE EXISTS (
  SELECT 1 FROM customers.reviews r
  WHERE r.customer_id = c.customer_id
    AND EXISTS (
      SELECT 1 FROM sales.returns rt
      JOIN sales.orders o ON o.order_id = rt.order_id
      WHERE o.cust_id = c.customer_id AND rt.prod_id = r.product_id
    )
);

/* Q50. EXISTS already returns each outer row at most once (it's a boolean test, not a row multiplier), so adding DISTINCT after an EXISTS/NOT EXISTS filter is redundant - it can never produce duplicates that weren't already in the outer table. */

/* ============================================================
   SECTION C: SUBQUERY IN FROM (DERIVED TABLE) (25)
   ------------------------------------------------------------ */
/* Q51. */
SELECT * FROM (SELECT cust_id, SUM(net_total) AS total FROM sales.orders GROUP BY cust_id) AS s
LIMIT 100;

/* Q52. */
SELECT * FROM (SELECT cust_id, SUM(net_total) AS total FROM sales.orders GROUP BY cust_id) AS s
WHERE s.total > 50000;

/* Q53. */
SELECT c.customer_id, c.first_name, c.last_name, s.total
FROM customers.customers c
JOIN (SELECT cust_id, SUM(net_total) AS total FROM sales.orders GROUP BY cust_id) s ON s.cust_id = c.customer_id;

/* Q54. */
SELECT o.cust_id, o.total AS order_total, r.review_count, t.ticket_count
FROM (SELECT cust_id, SUM(net_total) AS total FROM sales.orders GROUP BY cust_id) o
JOIN (SELECT customer_id, COUNT(*) AS review_count FROM customers.reviews GROUP BY customer_id) r ON r.customer_id = o.cust_id
JOIN (SELECT customer_id, COUNT(*) AS ticket_count FROM support.tickets GROUP BY customer_id) t ON t.customer_id = o.cust_id;

/* Q55. */
SELECT * FROM (SELECT cust_id, SUM(net_total) AS total FROM sales.orders GROUP BY cust_id ORDER BY total DESC LIMIT 10) s;

/* Q56. */
SELECT * FROM (
  SELECT store_id, SUM(net_total) AS revenue FROM sales.orders GROUP BY store_id HAVING SUM(net_total) > 500000
) s;

/* Q57. */
SELECT * FROM (
  SELECT order_id, cust_id, net_total, RANK() OVER (PARTITION BY cust_id ORDER BY net_total DESC) AS rnk
  FROM sales.orders
) x
WHERE x.rnk = 1
LIMIT 100;

/* Q58. */
SELECT * FROM (
  SELECT 'order' AS src, order_id AS id, order_date AS event_date FROM sales.orders
  UNION ALL
  SELECT 'return' AS src, return_id AS id, return_date AS event_date FROM sales.returns
) x
ORDER BY event_date DESC
LIMIT 100;

/* Q59. */
SELECT * FROM (
  SELECT customer_id FROM customers.customers
  EXCEPT
  SELECT DISTINCT cust_id FROM sales.orders WHERE cust_id IS NOT NULL
) x;

/* Q60. */
SELECT * FROM (
  SELECT cust_id, COUNT(*) AS order_count, SUM(net_total) AS total_spend, AVG(net_total) AS avg_order
  FROM sales.orders GROUP BY cust_id
) s
LIMIT 100;

/* Q61. */
SELECT * FROM (
  SELECT DISTINCT ON (cust_id) cust_id, order_id, order_date, net_total
  FROM sales.orders
  ORDER BY cust_id, order_date DESC
) latest
LIMIT 100;

/* Q62. */
SELECT c.customer_id,
       CASE WHEN s.total > 100000 THEN 'High Value'
            WHEN s.total > 20000 THEN 'Mid Value'
            ELSE 'Low Value' END AS segment
FROM customers.customers c
LEFT JOIN (SELECT cust_id, SUM(net_total) AS total FROM sales.orders GROUP BY cust_id) s ON s.cust_id = c.customer_id
LIMIT 200;

/* Q63. */
SELECT (SELECT MAX(total) FROM (SELECT cust_id, SUM(net_total) AS total FROM sales.orders GROUP BY cust_id) s) AS max_customer_spend;

/* Q64. */
SELECT s1.cust_id, s1.total, s1.total - s2.avg_total AS diff_from_avg
FROM (SELECT cust_id, SUM(net_total) AS total FROM sales.orders GROUP BY cust_id) s1
CROSS JOIN (SELECT AVG(total) AS avg_total FROM (SELECT cust_id, SUM(net_total) AS total FROM sales.orders GROUP BY cust_id) t) s2
LIMIT 200;

/* Q65. */
SELECT * FROM (
  SELECT * FROM (
    SELECT cust_id, SUM(net_total) AS total FROM sales.orders GROUP BY cust_id
  ) inner_s
  WHERE inner_s.total > 10000
) outer_s
ORDER BY outer_s.total DESC
LIMIT 20;

/* Q66. */
SELECT * FROM (
  SELECT product_id, product_name, price FROM products.products ORDER BY price DESC LIMIT 10
) top_products;

/* Q67. */
SELECT c.customer_id, s.total
FROM customers.customers c
LEFT JOIN (SELECT cust_id, SUM(net_total) AS total FROM sales.orders GROUP BY cust_id) s ON s.cust_id = c.customer_id
LIMIT 200;

/* Q68. */
SELECT s.cust_id, s.total, c.first_name
FROM customers.customers c
RIGHT JOIN (SELECT cust_id, SUM(net_total) AS total FROM sales.orders GROUP BY cust_id) s ON s.cust_id = c.customer_id
LIMIT 200;

/* Q69. */
SELECT c.customer_id, s.total
FROM customers.customers c
FULL OUTER JOIN (SELECT cust_id, SUM(net_total) AS total FROM sales.orders GROUP BY cust_id) s ON s.cust_id = c.customer_id
LIMIT 200;

/* Q70. */
SELECT cust_id, total_spend FROM (
  SELECT cust_id, SUM(net_total) AS total_spend FROM sales.orders GROUP BY cust_id
) AS agg(cust_id, total_spend)
LIMIT 100;

/* Q71. */
SELECT s.cust_id, s.total, RANK() OVER (ORDER BY s.total DESC) AS overall_rank
FROM (SELECT cust_id, SUM(net_total) AS total FROM sales.orders GROUP BY cust_id) s
LIMIT 50;

/* Q72. */
SELECT * FROM (SELECT COUNT(*) AS total_orders, SUM(net_total) AS total_revenue FROM sales.orders) x;

/* Q73. */
WITH agg AS (
  SELECT cust_id, SUM(net_total) AS total FROM sales.orders GROUP BY cust_id
)
SELECT * FROM agg WHERE total > 10000 ORDER BY total DESC LIMIT 20;

/* Q74. */
SELECT * FROM (
  SELECT order_id, jsonb_build_object('order_id', order_id, 'net_total', net_total, 'status', order_status) AS order_json
  FROM sales.orders
) j
LIMIT 20;

/* Q75. */
SELECT * FROM (
  SELECT 'ticket' AS source, customer_id, created_date::date AS event_date FROM support.tickets
  UNION ALL
  SELECT 'call' AS source, customer_id, call_start_time::date AS event_date FROM call_center.calls
) touchpoints
LIMIT 100;

/* ============================================================
   SECTION D: HAVING WITH SUBQUERY (25)
   ------------------------------------------------------------ */
/* Q76. */
SELECT store_id, SUM(net_total) AS revenue
FROM sales.orders
GROUP BY store_id
HAVING SUM(net_total) > (
  SELECT AVG(store_total) FROM (SELECT SUM(net_total) AS store_total FROM sales.orders GROUP BY store_id) t
);

/* Q77. */
SELECT cust_id, COUNT(*) AS order_count
FROM sales.orders
GROUP BY cust_id
HAVING COUNT(*) > (
  SELECT AVG(cnt) FROM (SELECT COUNT(*) AS cnt FROM sales.orders GROUP BY cust_id) t
);

/* Q78. */
SELECT prod_id, SUM(quantity) AS total_qty
FROM sales.order_items
GROUP BY prod_id
HAVING SUM(quantity) > 10 * (
  SELECT AVG(qty) FROM (SELECT SUM(quantity) AS qty FROM sales.order_items GROUP BY prod_id) t
);

/* Q79. */
SELECT o.store_id,
       SUM(o.net_total) FILTER (WHERE EXTRACT(YEAR FROM o.order_date) = 2025) AS rev_2025,
       SUM(o.net_total) FILTER (WHERE EXTRACT(YEAR FROM o.order_date) = 2024) AS rev_2024
FROM sales.orders o
GROUP BY o.store_id
HAVING SUM(o.net_total) FILTER (WHERE EXTRACT(YEAR FROM o.order_date) = 2025)
     > 2 * COALESCE(SUM(o.net_total) FILTER (WHERE EXTRACT(YEAR FROM o.order_date) = 2024), 0);

/* Q80. */
SELECT cust_id, COUNT(*) AS order_count
FROM sales.orders o
GROUP BY cust_id
HAVING EXISTS (SELECT 1 FROM loyalty.members m WHERE m.customer_id = o.cust_id);

/* Q81. */
SELECT cust_id, COUNT(*) AS order_count
FROM sales.orders o
GROUP BY cust_id
HAVING NOT EXISTS (SELECT 1 FROM loyalty.members m WHERE m.customer_id = o.cust_id);

/* Q82. */
SELECT o.store_id, SUM(o.net_total) AS store_revenue
FROM sales.orders o
GROUP BY o.store_id
HAVING SUM(o.net_total) > (
  SELECT AVG(rev) FROM (
    SELECT o2.store_id, SUM(o2.net_total) AS rev
    FROM sales.orders o2
    JOIN stores.stores s2 ON s2.store_id = o2.store_id
    WHERE s2.region_id = (SELECT region_id FROM stores.stores s3 WHERE s3.store_id = o.store_id)
    GROUP BY o2.store_id
  ) region_group
);

/* Q83. */
SELECT c.category_name, COUNT(*) AS product_count
FROM products.products p
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category c ON c.category_id = b.category_id
GROUP BY c.category_name
HAVING COUNT(*) > (SELECT AVG(cnt) FROM (SELECT COUNT(*) AS cnt FROM core.dim_brand GROUP BY category_id) t);

/* Q84. */
SELECT store_id, COUNT(*) AS order_count, SUM(net_total) AS revenue
FROM sales.orders
GROUP BY store_id
HAVING COUNT(*) > 500 AND (SUM(net_total) > 30000000 OR AVG(net_total) > 50000);

/* Q85. */
SELECT store_id, SUM(net_total) AS gross, SUM(discount_amount) AS discount
FROM sales.orders
GROUP BY store_id
HAVING SUM(discount_amount) > 0.1 * SUM(net_total);

/* Q86. */
SELECT s.region_id, SUM(o.net_total) AS region_revenue
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
GROUP BY s.region_id
HAVING SUM(o.net_total) > (
  SELECT AVG(rev) FROM (
    SELECT s2.region_id, SUM(o2.net_total) AS rev
    FROM sales.orders o2 JOIN stores.stores s2 ON s2.store_id = o2.store_id
    GROUP BY s2.region_id
  ) t
);

/* Q87. */
SELECT c.category_name, AVG(p.price) AS avg_price
FROM products.products p
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category c ON c.category_id = b.category_id
GROUP BY c.category_name
HAVING AVG(p.price) > (SELECT AVG(price) FROM products.products);

/* Q88. */
SELECT store_id, COUNT(CASE WHEN order_status = 'Delivered' THEN 1 END) AS delivered_count
FROM sales.orders
GROUP BY store_id
HAVING COUNT(CASE WHEN order_status = 'Delivered' THEN 1 END) > 300;

/* Q89. */
SELECT cust_id, SUM(net_total) AS total_spend
FROM sales.orders
GROUP BY cust_id
HAVING SUM(net_total) > (
  SELECT AVG(t.total) + 3 * STDDEV(t.total) FROM (SELECT cust_id, SUM(net_total) AS total FROM sales.orders GROUP BY cust_id) t
);

/* Q90. */
SELECT prod_id, SUM(quantity) FILTER (WHERE unit_price > 500) AS premium_qty
FROM sales.order_items
GROUP BY prod_id
HAVING SUM(quantity) FILTER (WHERE unit_price > 500) > 50;

/* Q91. */
SELECT cust_id, COUNT(*) AS recent_orders
FROM sales.orders
WHERE order_date >= (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '90 days'
GROUP BY cust_id
HAVING COUNT(*) >= 2;

/* Q92. */
SELECT s.region_id, o.store_id, SUM(o.net_total) AS revenue
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
GROUP BY ROLLUP (s.region_id, o.store_id)
HAVING SUM(o.net_total) > 100000;

/* Q93. */
SELECT s.region_id, o.order_status, SUM(o.net_total) AS revenue
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
GROUP BY CUBE (s.region_id, o.order_status)
HAVING SUM(o.net_total) > 50000;

/* Q94. */
SELECT store_id,
       COUNT(CASE WHEN order_status IN ('Cancelled','Returned') THEN 1 END) AS bad_orders,
       COUNT(*) AS total_orders
FROM sales.orders
GROUP BY store_id
HAVING COUNT(CASE WHEN order_status IN ('Cancelled','Returned') THEN 1 END)::numeric / COUNT(*) > 0.2;

/* Q95. */
SELECT cust_id, SUM(net_total) AS total_spend
FROM sales.orders
GROUP BY cust_id
HAVING SUM(net_total) > (
  SELECT PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY t.total)
  FROM (SELECT cust_id, SUM(net_total) AS total FROM sales.orders GROUP BY cust_id) t
);

/* Q96. */
SELECT cust_id, SUM(net_total) AS total_spend
FROM sales.orders
GROUP BY cust_id
HAVING SUM(net_total) < (
  SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY t.total)
  FROM (SELECT cust_id, SUM(net_total) AS total FROM sales.orders GROUP BY cust_id) t
);

/* Q97. */
SELECT cust_id, SUM(net_total) AS total_spend
FROM sales.orders
GROUP BY cust_id
HAVING SUM(net_total) = (
  SELECT MAX(t.total) FROM (SELECT cust_id, SUM(net_total) AS total FROM sales.orders GROUP BY cust_id) t
);

/* Q98. */
SELECT cust_id, SUM(net_total) AS total_spend
FROM sales.orders
GROUP BY cust_id
HAVING SUM(net_total) = (
  SELECT MIN(t.total) FROM (SELECT cust_id, SUM(net_total) AS total FROM sales.orders GROUP BY cust_id) t
);

/* Q99. */
SELECT cust_id, COUNT(DISTINCT store_id) AS distinct_stores
FROM sales.orders
GROUP BY cust_id
HAVING COUNT(DISTINCT store_id) > 2;

/* Q100. */
SELECT s.region_id, o.store_id, SUM(o.net_total) AS revenue,
       RANK() OVER (PARTITION BY s.region_id ORDER BY SUM(o.net_total) DESC) AS store_rank_in_region
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
GROUP BY s.region_id, o.store_id
HAVING SUM(o.net_total) > (SELECT AVG(net_total) FROM sales.orders) * 10;

/* ============================================================
   END OF ANSWER KEY - Subqueries Part 1 - MEDIUM LEVEL (100/100)
============================================================ */
