/* ============================================================
   ANSWER KEY - JSON & Semi-Structured Data (HARD LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1. JSONB is stored as a decomposed binary tree (not text), so PostgreSQL can walk it directly without re-parsing; that binary structure is what makes @> (containment) and ? (key existence) GIN-indexable, and it's also why key order isn't preserved and duplicate keys collapse to the last occurrence. */
/* Q2. jsonb_ops (the default) indexes every key and value, supporting @>, ?, ?|, ?&, and is larger; jsonb_path_ops indexes only the values needed for @> (and JSONPath containment), producing a smaller, faster index but it doesn't support the ? key-existence operators at all. */
/* Q3. CREATE INDEX ON tbl ((doc->>'k')) builds a btree on that exact text expression; the planner will use it only when a query's WHERE clause contains the identical expression doc->>'k' (same key, same operator chain) - a differently-written extraction won't match. */
/* Q4. jsonb_path_query returns every value matched by a JSONPath expression as a set of rows; jsonb_path_query_first returns just the first match (or NULL); jsonb_path_exists returns a boolean for whether any match exists - JSONPath itself supports wildcards (*), filters (?( )), and array slicing in one compact expression. */
/* Q5. A good event schema fixes a small set of always-required keys (id, timestamp, type) that every consumer can rely on, while treating everything else as optional/nested and including an explicit version key so consumers can branch on schema changes without breaking. */
/* Q6. Schema-on-read (store raw JSON, parse at query time) is maximally flexible for evolving payloads but pushes validation/type-safety costs to every query and complicates indexing; schema-on-write (parse into typed columns at ingest) is faster to query and safer but requires a migration whenever the source shape changes. */
/* Q7. Chain multiple LATERAL jsonb_array_elements calls, one per nesting level, each consuming the previous level's element - no recursion is needed because the nesting depth is known/fixed, so it's just successive flat joins rather than a recursive CTE. */
/* Q8. SQL NULL (the extraction expression itself has no value), JSON null (`doc->>'k'` returns text NULL for a real json null value), and an absent key (`doc->>'k'` also returns NULL) are three different underlying states that all surface as NULL from ->>' - only `doc ? 'k'` combined with `jsonb_typeof(doc->'k')` can distinguish them, and COUNT(doc->>'k') silently skips all three the same way. */
/* Q9. Round-tripping a value through JSON preserves numeric precision (JSONB numbers are arbitrary precision), but discards original key order and collapses duplicate keys to the last one - so a document with meaningful key order or intentional duplicate keys will NOT round-trip identically. */
/* Q10. Materialize extracted columns (via an MV, Day 25) when the same fields are queried repeatedly at volume and staleness of a scheduled refresh is acceptable; parse live when the query is rare/ad-hoc or the data must be up-to-the-second fresh. */
/* Q11. For queries that mix containment (@>) with a scalar range filter (extracted_field > x), combine a GIN index on the JSONB column (for @>) with a separate expression btree index on the extracted scalar - a single index type rarely serves both access patterns well. */
/* Q12. jsonb_set(doc, path, new_val) replaces or inserts a value at a path; || merges two JSON objects (right-hand keys win on conflict) or concatenates arrays; - (minus) removes a key or array element; #- removes a value at a nested path - all are WRITE operations, so in RetailMart they stay conceptual since this dataset is read-only (an accio_NN sandbox is where you'd actually run them). */
/* Q13. Validate a payload in SQL with `doc ?& array[...]` for required-key presence, `jsonb_typeof(doc->'field') = 'number'` (or similar) for type-correctness, and `doc->>'field' = ANY(array[...])` for enum membership - combine all three in a WHERE/CASE to build a pass/fail validation gate. */
/* Q14. When documents in the same table can have different shapes (some fields present in some rows, absent in others), always extract defensively - wrap every ->>'field' access in COALESCE or check `doc ? 'field'` first, rather than assuming every document has every key. */
/* Q15. jsonb_array_elements is a set-returning function used in FROM/LATERAL, so it multiplies the row count by the array length for every source row - on a large table with long arrays this row explosion can be the single biggest cost in a query; pre-filtering/pre-aggregating before unnesting limits the blast radius. */
/* Q16. Pivoting requires the output column LIST to be known at query-planning time, so a genuinely unknown/unbounded key set (e.g. arbitrary user-supplied tags) can't be pivoted directly in one static SQL statement - you either cap it to a known bounded set of keys (CASE/FILTER per key) or build the column list dynamically outside SQL (e.g. in application code). */
/* Q17. JSON-extracted expressions are ordinary SQL expressions, so they slot directly into window function clauses: PARTITION BY / ORDER BY / the frame can reference (doc->>'field')::type exactly as they would a plain column, enabling ranking, running totals, and moving windows over JSON-derived data. */
/* Q18. Good JSON API contracts wrap results in a consistent envelope ({"data": [...], "meta": {...}}), support pagination via a cursor or page/limit in meta, and represent errors as a predictable {"error": {"code":..., "message":...}} shape rather than ad-hoc per-endpoint formats. */
/* Q19. Model event ingestion by storing the raw payload as JSONB plus a few always-present columns (event_id, received_at); tolerate late-arriving or extra fields by never rejecting on unknown keys and by extracting expected fields defensively (COALESCE/? checks) rather than assuming a rigid, exhaustive schema. */
/* Q20. Containment (@>) checks whether one document is a structural SUBSET of another (order-independent for objects, and for arrays checks element presence not exact match); equality (=) requires the two JSONB values to be byte-for-byte identical after normalization - containment is far more forgiving for "does this document match this pattern" queries. */
/* Q21. A partial GIN/btree index (`WHERE doc->>'status' = 'active'`) indexes only the subset of rows matching that predicate, keeping the index small and fast when queries always filter to that same subset - useful when most documents are irrelevant to your hot-path queries. */
/* Q22. `WHERE (doc->>'x')::numeric > 100` requires extracting and casting text on every row before comparison, which is CPU work the planner can't avoid without help; an expression index on `((doc->>'x')::numeric)` lets the planner index that exact cast expression, restoring index-based filtering. */
/* Q23. jsonb_strip_nulls removes null-valued keys and canonicalization (conceptually sorting keys / normalizing formatting) produces a consistent representation for otherwise-equivalent documents, which is what lets a later dedup step (Day 26) group "the same" document together via equality/hashing instead of missing duplicates that merely differ in key order or extra nulls. */
/* Q24. A customer-360 document is grained at one row per customer, embeds bounded arrays (recent orders, reviews, tickets - not unbounded full history) to keep size manageable, and needs a defined refresh cadence (live query vs nightly MV) since it aggregates fast-changing child tables. */
/* Q25. Avoid JSON for data that is genuinely fixed-shape, heavily queried by individual fields, and benefits from strong typing/foreign keys/constraints - i.e. RetailMart's own core tables (orders, customers, products) are exactly the case where plain relational columns beat JSON. */

/* ============================================================
   SECTION B: PARSING & VALIDATION ENGINES (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT api_json ->> 'method' AS method, (api_json ->> 'status_code')::int AS status_code,
       (api_json ->> 'latency')::int AS latency_ms, api_json ->> 'user_agent' AS user_agent
FROM (SELECT jsonb_build_object('method', method, 'status_code', status_code, 'latency', response_time_ms, 'user_agent', user_agent) AS api_json FROM audit.api_requests) x
LIMIT 100;

/* Q27. */
SELECT doc, doc ?& array['order_id', 'status', 'net_total'] AS is_valid
FROM (SELECT jsonb_build_object('order_id', order_id, 'status', order_status, 'net_total', net_total) AS doc FROM sales.orders) x
WHERE NOT (doc ?& array['order_id', 'status', 'net_total'])
LIMIT 20;

/* Q28. */
SELECT api_json
FROM (SELECT jsonb_build_object('status_code', status_code, 'latency', response_time_ms) AS api_json FROM audit.api_requests) x
WHERE jsonb_typeof(api_json -> 'status_code') <> 'number' OR jsonb_typeof(api_json -> 'latency') <> 'number'
LIMIT 20;

/* Q29. */
SELECT CASE WHEN (api_json ->> 'status_code')::int BETWEEN 200 AND 299 THEN '2xx'
            WHEN (api_json ->> 'status_code')::int BETWEEN 300 AND 399 THEN '3xx'
            WHEN (api_json ->> 'status_code')::int BETWEEN 400 AND 499 THEN '4xx'
            WHEN (api_json ->> 'status_code')::int BETWEEN 500 AND 599 THEN '5xx'
            ELSE 'other' END AS status_class,
       count(*) AS requests
FROM (SELECT jsonb_build_object('status_code', status_code) AS api_json FROM audit.api_requests) x
GROUP BY 1
ORDER BY 1;

/* Q30. */
SELECT api_json ->> 'endpoint' AS endpoint,
       count(*) AS requests,
       round(100.0 * count(*) FILTER (WHERE (api_json ->> 'status_code')::int >= 400) / count(*), 2) AS error_pct,
       percentile_cont(0.95) WITHIN GROUP (ORDER BY (api_json ->> 'latency')::numeric) AS p95_latency
FROM (SELECT jsonb_build_object('endpoint', endpoint, 'status_code', status_code, 'latency', response_time_ms) AS api_json FROM audit.api_requests) x
GROUP BY 1
ORDER BY 1;

/* Q31. */
SELECT CASE WHEN api_json ->> 'user_agent' LIKE '%Mobile%' THEN 'Mobile'
            WHEN api_json ->> 'user_agent' LIKE '%Tablet%' THEN 'Tablet'
            ELSE 'Desktop' END AS device_class,
       count(*) AS requests
FROM (SELECT jsonb_build_object('user_agent', user_agent) AS api_json FROM audit.api_requests) x
GROUP BY 1
ORDER BY 1;

/* Q32. */
SELECT doc
FROM (SELECT jsonb_build_object('order_id', order_id, 'status', order_status, 'net_total', net_total) AS doc FROM sales.orders) x
WHERE doc @> '{"status":"Delivered"}'::jsonb
LIMIT 20;

/* Q33. */
SELECT jsonb_path_query(doc, '$.status') AS status_value
FROM (SELECT jsonb_build_object('order_id', order_id, 'status', order_status) AS doc FROM sales.orders) x
LIMIT 20;

/* Q34. */
SELECT order_id, COALESCE(doc #>> '{shipping,address,city}', doc #>> '{address,city}', 'unknown') AS resolved_city
FROM (SELECT order_id, jsonb_build_object('order_id', order_id) AS doc FROM sales.orders) x
LIMIT 20;

/* Q35. */
SELECT date_trunc('month', order_date)::date AS month,
       count(*) FILTER (WHERE NOT (doc ? 'status')) AS missing_status_key
FROM (SELECT order_date, jsonb_build_object('order_id', order_id, 'status', order_status) AS doc FROM sales.orders) x
GROUP BY 1
ORDER BY 1;

/* Q36. */
SELECT o.order_id, o.net_total, reconstructed.item_sum, (o.net_total = reconstructed.item_sum) AS reconciled
FROM sales.orders o
JOIN (
  SELECT order_id, sum(net_amount) AS item_sum
  FROM sales.order_items
  GROUP BY order_id
) reconstructed ON reconstructed.order_id = o.order_id
WHERE o.net_total <> reconstructed.item_sum
ORDER BY o.order_id
LIMIT 20;

/* Q37. */
SELECT api_json ->> 'method' AS method,
       count(*) FILTER (WHERE (api_json ->> 'status_code')::int < 300) AS ok,
       count(*) FILTER (WHERE (api_json ->> 'status_code')::int BETWEEN 400 AND 499) AS client_err,
       count(*) FILTER (WHERE (api_json ->> 'status_code')::int >= 500) AS server_err
FROM (SELECT jsonb_build_object('method', method, 'status_code', status_code) AS api_json FROM audit.api_requests) x
GROUP BY 1
ORDER BY 1;

/* Q38. */
SELECT api_json ->> 'method' AS method, extract(hour FROM ts)::int AS hour_of_day,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY (api_json ->> 'latency')::numeric) AS median_latency,
       percentile_cont(0.95) WITHIN GROUP (ORDER BY (api_json ->> 'latency')::numeric) AS p95_latency
FROM (SELECT jsonb_build_object('method', method, 'latency', response_time_ms) AS api_json, timestamp AS ts FROM audit.api_requests) x
GROUP BY 1, 2
ORDER BY 1, 2;

/* Q39. */
SELECT customer_id,
       (doc -> 'orders' IS NOT NULL AND jsonb_array_length(doc -> 'orders') > 0) AS has_orders
FROM (
  SELECT c.customer_id, jsonb_build_object('orders', coalesce(jsonb_agg(jsonb_build_object('order_id', o.order_id)) FILTER (WHERE o.order_id IS NOT NULL), '[]'::jsonb)) AS doc
  FROM customers.customers c
  LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
  GROUP BY c.customer_id
) x
ORDER BY customer_id
LIMIT 20;

/* Q40. */
SELECT json_totals.prod_id, json_totals.total_qty, direct.relational_qty
FROM (
  SELECT (item ->> 'prod')::int AS prod_id, sum((item ->> 'qty')::int) AS total_qty
  FROM (SELECT order_id, jsonb_agg(jsonb_build_object('prod', prod_id, 'qty', quantity)) AS items FROM sales.order_items GROUP BY order_id) x
  CROSS JOIN LATERAL jsonb_array_elements(items) AS item
  GROUP BY 1
) json_totals
JOIN (SELECT prod_id, sum(quantity) AS relational_qty FROM sales.order_items GROUP BY prod_id) direct
  ON direct.prod_id = json_totals.prod_id
ORDER BY 1
LIMIT 20;

/* Q41. */
SELECT key AS region, sum(value::numeric) AS total_revenue
FROM (
  SELECT jsonb_object_agg(r.region_name, rev.revenue) AS kpi_obj
  FROM (SELECT s.region_id, sum(o.net_total) AS revenue FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id GROUP BY 1) rev
  JOIN core.dim_region r ON r.region_id = rev.region_id
) x
CROSS JOIN LATERAL jsonb_each_text(kpi_obj)
GROUP BY key
ORDER BY total_revenue DESC;

/* Q42. */
SELECT doc
FROM (SELECT jsonb_build_object('region', jsonb_build_object('kpi', jsonb_build_object('revenue', s.region_id))) AS doc FROM stores.stores s LIMIT 5) x
WHERE (doc #>> '{region,kpi,revenue}')::numeric > 0;

/* Q43. */
SELECT versioned_doc, CASE WHEN versioned_doc ->> 'v' = '2' THEN versioned_doc ->> 'full_name' ELSE versioned_doc ->> 'name' END AS resolved_name
FROM (
  SELECT jsonb_build_object('v', 2, 'full_name', first_name || ' ' || last_name) AS versioned_doc
  FROM customers.customers
  LIMIT 10
) x;

/* Q44. */
SELECT order_id, jsonb_strip_nulls(doc) AS canonical_doc
FROM (SELECT order_id, jsonb_build_object('order_id', order_id, 'note', NULL::text, 'status', order_status) AS doc FROM sales.orders) x
ORDER BY order_id
LIMIT 20;

/* Q45. */
SELECT a.order_id AS order_a, b.order_id AS order_b
FROM (SELECT order_id, jsonb_build_object('status', order_status, 'store_id', store_id) AS doc FROM sales.orders) a
JOIN (SELECT order_id, jsonb_build_object('status', order_status, 'store_id', store_id) AS doc FROM sales.orders) b
  ON a.doc @> b.doc AND b.doc @> a.doc AND a.order_id < b.order_id
LIMIT 20;

/* Q46. */
SELECT order_id, idx, item ->> 'prod' AS prod_id
FROM (SELECT order_id, jsonb_agg(jsonb_build_object('prod', prod_id)) AS items FROM sales.order_items GROUP BY order_id ORDER BY order_id LIMIT 5) x
CROSS JOIN LATERAL jsonb_array_elements(items) WITH ORDINALITY AS t(item, idx);

/* Q47. */
SELECT month, revenue, round(100.0 * (revenue - lag(revenue) OVER (ORDER BY month)) / NULLIF(lag(revenue) OVER (ORDER BY month), 0), 2) AS mom_pct
FROM (
  SELECT (item ->> 'month')::date AS month, (item ->> 'revenue')::numeric AS revenue
  FROM (
    SELECT jsonb_agg(jsonb_build_object('month', month, 'revenue', revenue) ORDER BY month) AS ts_json
    FROM (SELECT date_trunc('month', order_date)::date AS month, sum(net_total) AS revenue FROM sales.orders GROUP BY 1) m
  ) x
  CROSS JOIN LATERAL jsonb_array_elements(ts_json) AS item
) y
ORDER BY month;

/* Q48. */
SELECT jsonb_build_object(
  'page_views', pv, 'add_to_cart_proxy_events', ev, 'orders', ords,
  'view_to_order_pct', round(100.0 * ords / NULLIF(pv, 0), 4)
) AS funnel_doc
FROM (SELECT (SELECT count(*) FROM web_events.page_views) AS pv,
             (SELECT count(*) FROM web_events.events) AS ev,
             (SELECT count(*) FROM sales.orders) AS ords) x;

/* Q49. */
SELECT doc
FROM (SELECT jsonb_build_object('order_id', order_id, 'status', order_status) AS doc FROM sales.orders) x
WHERE doc ->> 'status' NOT IN ('Processing','Out for Delivery','Delivered','Shipped','Failed','Cancelled','Returned')
LIMIT 20;

/* Q50. */
SELECT region_name, (kpi_doc #>> '{kpi,median_aov}')::numeric AS median_aov,
       rank() OVER (ORDER BY (kpi_doc #>> '{kpi,median_aov}')::numeric DESC) AS region_rank
FROM (
  SELECT r.region_name, jsonb_build_object('kpi', jsonb_build_object('median_aov', percentile_cont(0.5) WITHIN GROUP (ORDER BY o.net_total))) AS kpi_doc
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  JOIN core.dim_region r ON r.region_id = s.region_id
  GROUP BY r.region_name
) x
ORDER BY region_rank;

/* ============================================================
   SECTION C: NESTED-DOC PIPELINES (25)
   ------------------------------------------------------------ */
/* Q51. */
SELECT jsonb_build_object(
  'customer_id', c.customer_id,
  'profile', jsonb_build_object('name', c.first_name || ' ' || c.last_name, 'tier', c.tier),
  'orders', coalesce((SELECT jsonb_agg(jsonb_build_object('order_id', o.order_id, 'net_total', o.net_total)) FROM sales.orders o WHERE o.cust_id = c.customer_id), '[]'::jsonb),
  'reviews', coalesce((SELECT jsonb_agg(jsonb_build_object('review_id', r.review_id, 'rating', r.rating)) FROM customers.reviews r WHERE r.customer_id = c.customer_id), '[]'::jsonb),
  'tickets', coalesce((SELECT jsonb_agg(jsonb_build_object('ticket_id', t.ticket_id, 'priority', t.priority)) FROM support.tickets t WHERE t.customer_id = c.customer_id), '[]'::jsonb),
  'latest_order', (SELECT jsonb_build_object('order_id', o2.order_id, 'order_date', o2.order_date) FROM sales.orders o2 WHERE o2.cust_id = c.customer_id ORDER BY o2.order_date DESC LIMIT 1)
) AS customer_360
FROM customers.customers c
ORDER BY c.customer_id
LIMIT 10;

/* Q52. */
WITH doc AS (
  SELECT jsonb_build_object(
    'customer_id', c.customer_id,
    'orders', coalesce((SELECT jsonb_agg(jsonb_build_object('order_id', o.order_id)) FROM sales.orders o WHERE o.cust_id = c.customer_id), '[]'::jsonb)
  ) AS d
  FROM customers.customers c
  WHERE c.customer_id IN (SELECT customer_id FROM customers.customers ORDER BY customer_id LIMIT 100)
)
SELECT count(*) AS flattened_orders,
       (SELECT count(*) FROM sales.orders WHERE cust_id IN (SELECT customer_id FROM customers.customers ORDER BY customer_id LIMIT 100)) AS base_orders
FROM doc
CROSS JOIN LATERAL jsonb_array_elements(d -> 'orders') AS item;

/* Q53. */
SELECT jsonb_build_object(
  'order_id', o.order_id,
  'items', (SELECT jsonb_agg(jsonb_build_object('prod_id', oi.prod_id, 'qty', oi.quantity)) FROM sales.order_items oi WHERE oi.order_id = o.order_id),
  'payment', (SELECT jsonb_build_object('mode', p.payment_mode, 'amount', p.amount) FROM sales.payments p WHERE p.order_id = o.order_id LIMIT 1),
  'shipment', (SELECT jsonb_build_object('courier', s.courier_name, 'status', s.status) FROM sales.shipments s WHERE s.order_id = o.order_id LIMIT 1)
) AS order_export
FROM sales.orders o
ORDER BY o.order_id
LIMIT 10;

/* Q54. */
SELECT jsonb_build_object('region', r.region_name,
       'stores', jsonb_agg(jsonb_build_object('store_id', s.store_id, 'monthly_revenue', store_rev.months))) AS region_doc
FROM core.dim_region r
JOIN stores.stores s ON s.region_id = r.region_id
JOIN LATERAL (
  SELECT jsonb_agg(jsonb_build_object('month', month, 'revenue', revenue) ORDER BY month) AS months
  FROM (SELECT date_trunc('month', order_date)::date AS month, sum(net_total) AS revenue FROM sales.orders WHERE store_id = s.store_id GROUP BY 1) m
) store_rev ON true
GROUP BY r.region_name
ORDER BY r.region_name
LIMIT 5;

/* Q55. */
SELECT jsonb_build_object('category', cat.category_name,
       'brands', jsonb_agg(brand_doc.doc)) AS catalog_doc
FROM core.dim_category cat
JOIN core.dim_brand b ON b.category_id = cat.category_id
JOIN LATERAL (
  SELECT jsonb_build_object('brand', b.brand_name, 'products', jsonb_agg(jsonb_build_object('prod_id', p.product_id, 'price', p.price))) AS doc
  FROM products.products p
  WHERE p.brand_id = b.brand_id
) brand_doc ON true
GROUP BY cat.category_name
ORDER BY cat.category_name
LIMIT 5;

/* Q56. */
SELECT sum((prod ->> 'price')::numeric) AS total_from_json,
       (SELECT sum(p.price) FROM products.products p JOIN core.dim_brand b ON b.brand_id = p.brand_id) AS total_direct
FROM (
  SELECT jsonb_build_object('brand', b.brand_name, 'products', jsonb_agg(jsonb_build_object('price', p.price))) AS doc
  FROM core.dim_brand b
  JOIN products.products p ON p.brand_id = b.brand_id
  GROUP BY b.brand_id, b.brand_name
) brand_docs
CROSS JOIN LATERAL jsonb_array_elements(brand_docs.doc -> 'products') AS prod;

/* Q57. */
SELECT order_id, prod_qty_map -> '1' AS qty_for_prod_1
FROM (SELECT order_id, jsonb_object_agg(prod_id::text, quantity) AS prod_qty_map FROM sales.order_items GROUP BY order_id) x
WHERE prod_qty_map ? '1'
LIMIT 20;

/* Q58. */
SELECT nested_map #> array[r.region_name, '2025-06'] AS june_revenue
FROM (
  SELECT jsonb_object_agg(region_name, months) AS nested_map
  FROM (
    SELECT r.region_name, jsonb_object_agg(to_char(m.month,'YYYY-MM'), m.revenue) AS months
    FROM (SELECT s.region_id, date_trunc('month', o.order_date)::date AS month, sum(o.net_total) AS revenue
          FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id GROUP BY 1, 2) m
    JOIN core.dim_region r ON r.region_id = m.region_id
    GROUP BY r.region_name
  ) t
) x
CROSS JOIN core.dim_region r
ORDER BY r.region_name
LIMIT 10;

/* Q59. */
SELECT cat.category_name, jsonb_agg(jsonb_build_object('prod_id', p.product_id, 'price', p.price) ORDER BY p.price DESC) AS top5
FROM (
  SELECT cat.category_name, p.product_id, p.price,
         row_number() OVER (PARTITION BY cat.category_name ORDER BY p.price DESC) AS rn
  FROM products.products p
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
) p
CROSS JOIN core.dim_category cat
WHERE p.category_name = cat.category_name AND p.rn <= 5
GROUP BY cat.category_name
ORDER BY cat.category_name;

/* Q60. */
SELECT (item ->> 'day')::date AS day, (item ->> 'revenue')::numeric AS revenue,
       coalesce((item ->> 'revenue')::numeric, 0) AS gap_filled_revenue
FROM (
  SELECT jsonb_agg(jsonb_build_object('day', d.day::date, 'revenue', o.revenue) ORDER BY d.day) AS series
  FROM generate_series('2025-06-01'::date, '2025-06-10'::date, interval '1 day') AS d(day)
  LEFT JOIN (SELECT order_date, sum(net_total) AS revenue FROM sales.orders GROUP BY order_date) o ON o.order_date = d.day
) x
CROSS JOIN LATERAL jsonb_array_elements(series) AS item;

/* Q61. */
SELECT doc
FROM (SELECT jsonb_build_object('order_id', order_id, 'shipping', jsonb_build_object('store_id', store_id)) AS doc FROM sales.orders) x
WHERE doc @> jsonb_build_object('shipping', jsonb_build_object('store_id', (SELECT min(store_id) FROM stores.stores)))
LIMIT 20;

/* Q62. */
SELECT jsonb_build_object('data', page_data, 'meta', jsonb_build_object('count', 20, 'page', 2)) AS envelope
FROM (SELECT jsonb_agg(jsonb_build_object('order_id', order_id)) AS page_data FROM sales.orders WHERE order_id BETWEEN 21 AND 40) x;

/* Q63. */
SELECT c.category_name, jsonb_agg(units ORDER BY month_num) AS sparkline
FROM (
  SELECT cat.category_name, extract(month FROM o.order_date)::int AS month_num, sum(oi.quantity) AS units
  FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
  WHERE extract(year FROM o.order_date) = 2025
  GROUP BY cat.category_name, month_num
) cat_data
JOIN core.dim_category c ON c.category_name = cat_data.category_name
GROUP BY c.category_name
ORDER BY c.category_name;

/* Q64. Conceptual: || concatenates two JSONB objects, with keys from the RIGHT-hand operand overwriting matching keys from the left (e.g. '{"a":1,"b":2}'::jsonb || '{"b":9}'::jsonb -> {"a":1,"b":9}); for arrays it appends elements rather than merging by key - since this is a write/transform operation it stays conceptual on this read-only dataset. */

/* Q65. */
SELECT (doc ->> 'status') AS status, count(*) AS orders,
       sum((doc ->> 'net_total')::numeric) FILTER (WHERE doc ->> 'status' = 'Delivered') AS delivered_revenue,
       sum((doc ->> 'net_total')::numeric) FILTER (WHERE doc ->> 'status' = 'Cancelled') AS cancelled_revenue
FROM (SELECT jsonb_build_object('status', order_status, 'net_total', net_total) AS doc FROM sales.orders) x
GROUP BY 1
ORDER BY 1;

/* Q66. */
SELECT jsonb_agg(jsonb_build_object('metric', metric, 'value', value)) AS kpi_array
FROM (
  SELECT 'orders' AS metric, count(*)::numeric AS value FROM sales.orders
  UNION ALL SELECT 'revenue', sum(net_total) FROM sales.orders
  UNION ALL SELECT 'customers', count(*)::numeric FROM customers.customers
) k;

/* Q67. */
SELECT jsonb_build_object('cohort', cohort_month,
       'periods', jsonb_object_agg(months_since::text, retained)) AS cohort_doc
FROM (
  SELECT date_trunc('month', c.registration_date)::date AS cohort_month,
         (extract(year FROM o.order_date) - extract(year FROM c.registration_date)) * 12
         + (extract(month FROM o.order_date) - extract(month FROM c.registration_date)) AS months_since,
         count(DISTINCT o.cust_id) AS retained
  FROM customers.customers c
  JOIN sales.orders o ON o.cust_id = c.customer_id
  GROUP BY 1, 2
) t
WHERE months_since BETWEEN 0 AND 5
GROUP BY cohort_month
ORDER BY cohort_month;

/* Q68. */
SELECT jsonb_build_object('customer_id', customer_id, 'tier', tier,
       'recency_score', ntile(4) OVER (ORDER BY days_since_last DESC),
       'frequency_score', ntile(4) OVER (ORDER BY order_count),
       'monetary_score', ntile(4) OVER (ORDER BY total_spend)) AS rfm_doc
FROM (
  SELECT c.customer_id, c.tier,
         (SELECT max(order_date) FROM sales.orders) - max(o.order_date) AS days_since_last,
         count(o.order_id) AS order_count,
         coalesce(sum(o.net_total), 0) AS total_spend
  FROM customers.customers c
  LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
  GROUP BY c.customer_id, c.tier
) x
ORDER BY customer_id
LIMIT 20;

/* Q69. */
SELECT jsonb_build_object('warehouse_id', w.warehouse_id,
       'latest_snapshot', (SELECT jsonb_build_object('date', s.snapshot_date, 'total_qty', sum(s.quantity_on_hand))
                            FROM supply_chain.inventory_snapshots s
                            WHERE s.warehouse_id = w.warehouse_id AND s.snapshot_date = (SELECT max(snapshot_date) FROM supply_chain.inventory_snapshots s2 WHERE s2.warehouse_id = w.warehouse_id)
                            GROUP BY s.snapshot_date)
) AS warehouse_doc
FROM supply_chain.warehouses w
ORDER BY w.warehouse_id;

/* Q70. */
SELECT record_id, jsonb_agg(jsonb_build_object('changed_at', changed_at, 'column_name', column_name, 'old', old_value, 'new', new_value) ORDER BY changed_at) AS change_history,
       jsonb_agg(jsonb_build_object('column_name', column_name, 'new', new_value) ORDER BY changed_at DESC) -> 0 AS latest_change
FROM audit.record_changes
GROUP BY record_id
ORDER BY record_id
LIMIT 20;

/* Q71. */
SELECT doc
FROM (
  SELECT jsonb_build_object('order_id', o.order_id,
         'in_promo', EXISTS (SELECT 1 FROM products.promotions pr WHERE pr.active = true),
         'is_returned', EXISTS (SELECT 1 FROM sales.returns r WHERE r.order_id = o.order_id)) AS doc
  FROM sales.orders o
) x
WHERE (x.doc ->> 'is_returned')::boolean = true
LIMIT 20;

/* Q72. */
WITH order_items_agg AS (
  SELECT order_id, jsonb_agg(jsonb_build_object('amt', net_amount)) AS items
  FROM sales.order_items
  GROUP BY order_id
),
store_docs AS (
  SELECT o.store_id, jsonb_agg(jsonb_build_object('order_id', o.order_id, 'items', oi.items)) AS doc
  FROM sales.orders o
  JOIN order_items_agg oi ON oi.order_id = o.order_id
  GROUP BY o.store_id
)
SELECT sum((prod ->> 'amt')::numeric) AS deep_sum, (SELECT sum(net_amount) FROM sales.order_items) AS direct_sum
FROM store_docs
CROSS JOIN LATERAL jsonb_array_elements(doc) AS ord
CROSS JOIN LATERAL jsonb_array_elements(ord -> 'items') AS prod;

/* Q73. */
SELECT array_len, count(*) AS orders
FROM (SELECT order_id, jsonb_array_length(jsonb_agg(jsonb_build_object('prod', prod_id))) AS array_len FROM sales.order_items GROUP BY order_id) x
GROUP BY array_len
ORDER BY array_len DESC
LIMIT 20;

/* Q74. */
SELECT jsonb_build_object('endpoint', endpoint, 'requests', count(*),
       'p95_latency', percentile_cont(0.95) WITHIN GROUP (ORDER BY response_time_ms),
       'sample_errors', (SELECT jsonb_agg(jsonb_build_object('status', status_code, 'ts', timestamp)) FROM (SELECT status_code, timestamp FROM audit.api_requests a2 WHERE a2.endpoint = a1.endpoint AND a2.status_code >= 400 LIMIT 3) s)
) AS error_report
FROM audit.api_requests a1
GROUP BY endpoint
ORDER BY endpoint;

/* Q75. */
SELECT jsonb_build_object('customer_id', c.customer_id,
       'first_activity', min(o.order_date),
       'latest_activity', max(o.order_date),
       'span_days', max(o.order_date) - min(o.order_date)) AS timeline_doc
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY c.customer_id
ORDER BY c.customer_id
LIMIT 20;

/* ============================================================
   SECTION D: PRODUCTION SEMI-STRUCTURED SYSTEMS (25)
   ------------------------------------------------------------ */
/* Q76. */
SELECT jsonb_build_object(
  'customer_id', c.customer_id,
  'profile', jsonb_build_object('name', c.first_name || ' ' || c.last_name, 'tier', c.tier, 'registered', c.registration_date),
  'orders', coalesce((SELECT jsonb_agg(jsonb_build_object('order_id', o.order_id, 'net_total', o.net_total)) FROM sales.orders o WHERE o.cust_id = c.customer_id), '[]'::jsonb),
  'order_count', (SELECT count(*) FROM sales.orders o WHERE o.cust_id = c.customer_id),
  'median_spend', (SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY o.net_total) FROM sales.orders o WHERE o.cust_id = c.customer_id),
  'is_valid', (c.customer_id IS NOT NULL AND c.tier IS NOT NULL)
) AS customer_360_mart
FROM customers.customers c
ORDER BY c.customer_id
LIMIT 10;

/* Q77. */
SELECT jsonb_object_agg(endpoint, stats) AS observability_doc
FROM (
  SELECT endpoint, jsonb_build_object(
    'error_pct', round(100.0 * count(*) FILTER (WHERE status_code >= 400) / count(*), 2),
    'p50', percentile_cont(0.5) WITHIN GROUP (ORDER BY response_time_ms),
    'p95', percentile_cont(0.95) WITHIN GROUP (ORDER BY response_time_ms),
    'p99', percentile_cont(0.99) WITHIN GROUP (ORDER BY response_time_ms)
  ) AS stats
  FROM audit.api_requests
  GROUP BY endpoint
) x;

/* Q78. */
SELECT extract(hour FROM event_timestamp)::int AS hour_of_day, event_type, count(*) AS events
FROM web_events.events
GROUP BY 1, 2
ORDER BY 1, 2;

/* Q79. */
SELECT jsonb_build_object(
  'order', jsonb_build_object('order_id', o.order_id, 'status', o.order_status, 'net_total', o.net_total),
  'items', (SELECT jsonb_agg(jsonb_build_object('prod_id', oi.prod_id, 'qty', oi.quantity)) FROM sales.order_items oi WHERE oi.order_id = o.order_id),
  'reconciled', o.net_total = (SELECT sum(net_amount) FROM sales.order_items oi WHERE oi.order_id = o.order_id)
) AS order_export
FROM sales.orders o
ORDER BY o.order_id
LIMIT 10;

/* Q80. */
SELECT jsonb_agg(jsonb_build_object(
  'region', region_name, 'median_aov', median_aov, 'p90_aov', p90_aov, 'p95_aov', p95_aov, 'orders', orders, 'latest_order', latest_order
)) AS region_dashboard
FROM (
  SELECT r.region_name,
         percentile_cont(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov,
         percentile_cont(0.9) WITHIN GROUP (ORDER BY o.net_total) AS p90_aov,
         percentile_cont(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_aov,
         count(*) AS orders,
         max(o.order_date) AS latest_order
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  JOIN core.dim_region r ON r.region_id = s.region_id
  GROUP BY r.region_name
) x;

/* Q81. */
SELECT jsonb_build_object('category', cat.category_name,
       'products', jsonb_agg(jsonb_build_object(
         'prod_id', p.product_id, 'price', p.price,
         'margin', round(((p.price - p.cost_price) / NULLIF(p.price, 0))::numeric, 3),
         'in_promo', EXISTS (SELECT 1 FROM products.promotions pr WHERE pr.active = true)
       ))) AS category_doc
FROM core.dim_category cat
JOIN core.dim_brand b ON b.category_id = cat.category_id
JOIN products.products p ON p.brand_id = b.brand_id
GROUP BY cat.category_name
ORDER BY cat.category_name;

/* Q82. */
SELECT jsonb_build_object('cohort', cohort_month, 'periods', jsonb_object_agg(months_since::text, retained)) AS triangle_row
FROM (
  SELECT date_trunc('month', c.registration_date)::date AS cohort_month,
         (extract(year FROM o.order_date) - extract(year FROM c.registration_date)) * 12
         + (extract(month FROM o.order_date) - extract(month FROM c.registration_date)) AS months_since,
         count(DISTINCT o.cust_id) AS retained
  FROM customers.customers c
  JOIN sales.orders o ON o.cust_id = c.customer_id
  GROUP BY 1, 2
) t
WHERE months_since BETWEEN 0 AND 5
GROUP BY cohort_month
ORDER BY cohort_month;

/* Q83. */
SELECT jsonb_build_object('table', table_name, 'column', column_name, 'old', old_value, 'new', new_value, 'pct_change', pct_change) AS change_doc
FROM (
  SELECT table_name, column_name, old_value, new_value,
         round(abs((new_value::numeric - old_value::numeric) / NULLIF(old_value::numeric, 0)) * 100, 2) AS pct_change
  FROM audit.record_changes
  WHERE column_name = 'price' AND old_value ~ '^[0-9.]+$' AND new_value ~ '^[0-9.]+$'
) x
WHERE pct_change > 50
ORDER BY pct_change DESC
LIMIT 20;

/* Q84. */
SELECT jsonb_object_agg(day::text, jsonb_build_object('revenue', revenue, 'ma7', ma7)) AS time_series_doc
FROM (
  SELECT day::date, revenue, avg(revenue) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS ma7
  FROM (
    SELECT d.day::date, coalesce(sum(o.net_total), 0) AS revenue
    FROM generate_series((SELECT max(order_date) FROM sales.orders) - interval '89 days',
                          (SELECT max(order_date) FROM sales.orders), interval '1 day') AS d(day)
    LEFT JOIN sales.orders o ON o.order_date = d.day::date
    GROUP BY d.day
  ) daily
) x;

/* Q85. */
SELECT jsonb_build_object('customer_id', customer_id, 'tier', tier,
       'r_score', ntile(4) OVER (ORDER BY days_since_last DESC),
       'f_score', ntile(4) OVER (ORDER BY order_count),
       'm_score', ntile(4) OVER (ORDER BY total_spend)) AS rfm_export
FROM (
  SELECT c.customer_id, c.tier,
         (SELECT max(order_date) FROM sales.orders) - max(o.order_date) AS days_since_last,
         count(o.order_id) AS order_count,
         coalesce(sum(o.net_total), 0) AS total_spend
  FROM customers.customers c
  LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
  GROUP BY c.customer_id, c.tier
) x
ORDER BY customer_id
LIMIT 20;

/* Q86. */
SELECT jsonb_object_agg(w.warehouse_id::text, snap.doc) AS freshness_doc
FROM supply_chain.warehouses w
JOIN LATERAL (
  SELECT jsonb_build_object('latest_date', max(snapshot_date), 'days_stale', (SELECT max(order_date) FROM sales.orders) - max(snapshot_date)) AS doc
  FROM supply_chain.inventory_snapshots s
  WHERE s.warehouse_id = w.warehouse_id
) snap ON true;

/* Q87. */
SELECT jsonb_build_object(
  'page_views', (SELECT count(*) FROM web_events.page_views),
  'events', (SELECT count(*) FROM web_events.events),
  'orders', (SELECT count(*) FROM sales.orders),
  'view_to_order_pct', round(100.0 * (SELECT count(*) FROM sales.orders) / NULLIF((SELECT count(*) FROM web_events.page_views), 0), 4)
) AS funnel_doc;

/* Q88. */
SELECT jsonb_build_object('prod_id', p.product_id, 'latest_price', latest.unit_price, 'median_price', med.median_price,
       'drift_pct', round((100.0 * (latest.unit_price - med.median_price) / NULLIF(med.median_price, 0))::numeric, 2)) AS pricing_doc
FROM products.products p
JOIN LATERAL (SELECT oi.unit_price FROM sales.order_items oi JOIN sales.orders o ON o.order_id = oi.order_id WHERE oi.prod_id = p.product_id ORDER BY o.order_date DESC LIMIT 1) latest ON true
JOIN LATERAL (SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY oi.unit_price) AS median_price FROM sales.order_items oi WHERE oi.prod_id = p.product_id) med ON true
WHERE p.product_id IN (SELECT product_id FROM products.products ORDER BY product_id LIMIT 20);

/* Q89. */
SELECT doc, doc ?& array['order_id','status','net_total'] AS valid_keys,
       jsonb_typeof(doc -> 'net_total') = 'number' AS valid_types,
       doc ->> 'status' IN ('Processing','Out for Delivery','Delivered','Shipped','Failed','Cancelled','Returned') AS valid_enum
FROM (SELECT jsonb_build_object('order_id', order_id, 'status', order_status, 'net_total', net_total) AS doc FROM sales.orders) x
WHERE NOT (doc ?& array['order_id','status','net_total']) OR NOT (doc ->> 'status' IN ('Processing','Out for Delivery','Delivered','Shipped','Failed','Cancelled','Returned'))
LIMIT 20;

/* Q90. */
SELECT jsonb_build_object('data', page, 'meta', jsonb_build_object('page', 1, 'page_size', 10, 'total', total)) AS response
FROM (SELECT jsonb_agg(jsonb_build_object('order_id', order_id, 'status', order_status)) AS page FROM (SELECT order_id, order_status FROM sales.orders WHERE order_status = 'Delivered' ORDER BY order_id LIMIT 10) t) x
CROSS JOIN (SELECT count(*) AS total FROM sales.orders WHERE order_status = 'Delivered') c;

/* Q91. */
SELECT jsonb_object_agg(dow::text, hours) AS heatmap_doc
FROM (
  SELECT dow, jsonb_object_agg(hour::text, page_views) AS hours
  FROM (
    SELECT extract(dow FROM view_timestamp)::int AS dow, extract(hour FROM view_timestamp)::int AS hour, count(*) AS page_views
    FROM web_events.page_views
    GROUP BY 1, 2
  ) x
  GROUP BY dow
) y;

/* Q92. */
SELECT jsonb_object_agg(priority, doc) AS sla_scorecard
FROM (
  SELECT priority, jsonb_build_object(
    'median_hours', percentile_cont(0.5) WITHIN GROUP (ORDER BY extract(epoch FROM (resolved_date - created_date)) / 3600.0),
    'p95_hours', percentile_cont(0.95) WITHIN GROUP (ORDER BY extract(epoch FROM (resolved_date - created_date)) / 3600.0)
  ) AS doc
  FROM support.tickets
  WHERE resolved_date IS NOT NULL
  GROUP BY priority
) x;

/* Q93. */
SELECT r.region_name, jsonb_build_object('orders', count(*), 'revenue', sum(o.net_total), 'avg_order', avg(o.net_total)) AS region_doc
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;

/* Q94. Conceptual: schema-versioned ingestion stores a {"v": N, ...} envelope on every document; a CASE on doc->>'v' branches extraction logic per version (e.g. v1 has "full_name", v2 splits into "first_name"/"last_name"), normalizing every version into one common output shape so downstream consumers never need to know which version a given row originally arrived as. */

/* Q95. */
SELECT r.region_name, x.json_total, x.relational_total, x.json_total = x.relational_total AS reconciled
FROM (
  SELECT s.region_id,
         (SELECT sum((item ->> 'net_total')::numeric) FROM (SELECT jsonb_agg(jsonb_build_object('net_total', net_total)) AS items FROM sales.orders o2 WHERE o2.store_id = s.store_id) j CROSS JOIN LATERAL jsonb_array_elements(items) AS item) AS json_total,
         sum(o.net_total) AS relational_total
  FROM stores.stores s
  JOIN sales.orders o ON o.store_id = s.store_id
  GROUP BY s.region_id, s.store_id
) x
JOIN core.dim_region r ON r.region_id = x.region_id
LIMIT 20;

/* Q96. */
SELECT jsonb_build_object('customer_id', c.customer_id,
       'latest_order', (SELECT max(order_date) FROM sales.orders o WHERE o.cust_id = c.customer_id),
       'latest_view', (SELECT max(view_timestamp) FROM web_events.page_views pv WHERE pv.customer_id = c.customer_id),
       'latest_ticket', (SELECT max(created_date) FROM support.tickets t WHERE t.customer_id = c.customer_id)
) AS activity_doc
FROM customers.customers c
ORDER BY c.customer_id
LIMIT 20;

/* Q97. */
SELECT jsonb_agg(jsonb_build_object('week', week_start, 'p95', p95_revenue, 'prev_p95', prev_p95, 'shift_pct', shift_pct)) AS movers_alert
FROM (
  SELECT week_start, p95_revenue, lag(p95_revenue) OVER (ORDER BY week_start) AS prev_p95,
         round((100.0 * (p95_revenue - lag(p95_revenue) OVER (ORDER BY week_start)) / NULLIF(lag(p95_revenue) OVER (ORDER BY week_start), 0))::numeric, 2) AS shift_pct
  FROM (
    SELECT date_trunc('week', order_date)::date AS week_start, percentile_cont(0.95) WITHIN GROUP (ORDER BY net_total) AS p95_revenue
    FROM sales.orders
    GROUP BY 1
  ) w
) x
WHERE prev_p95 IS NOT NULL;

/* Q98. Conceptual: a GIN index (CREATE INDEX ON tbl USING gin(doc)) accelerates @>/?/?&/?| containment queries on the whole document by indexing every key/value pair inside it, so the planner can jump directly to matching rows instead of scanning and re-checking every document's JSONB tree - essential once a table storing many such documents grows large and containment filters are common. */

/* Q99. */
WITH raw AS (
  SELECT jsonb_build_object('order_id', o.order_id, 'status', o.order_status, 'net_total', o.net_total) AS doc
  FROM sales.orders o
),
validated AS (
  SELECT doc, doc ?& array['order_id','status','net_total'] AS is_valid
  FROM raw
),
flattened AS (
  SELECT (doc ->> 'order_id')::int AS order_id, doc ->> 'status' AS status, (doc ->> 'net_total')::numeric AS net_total
  FROM validated
  WHERE is_valid
)
SELECT f.status, count(*) AS orders, sum(f.net_total) AS total, r.total_direct
FROM flattened f
CROSS JOIN (SELECT sum(net_total) AS total_direct FROM sales.orders) r
GROUP BY f.status, r.total_direct
ORDER BY f.status;

/* Q100. Capstone: the production customer-360 + region-KPI service combines the Q76-style per-customer document (profile, orders[], median/P95 spend, RFM scores) with the Q80-style per-region KPI array (median/P95 AOV, order counts, latest order) into one JSON export layer; a GIN index (Day 20) on any stored JSONB columns speeds containment lookups, and since both documents are expensive multi-join aggregates recomputed identically on every call, in production they'd be precomputed into a materialized view (Day 25) refreshed on a schedule, with the API simply SELECTing the precomputed doc by customer_id/region_id. */

/* ============================================================
   END OF ANSWER KEY - HARD LEVEL (100/100)
============================================================ */
