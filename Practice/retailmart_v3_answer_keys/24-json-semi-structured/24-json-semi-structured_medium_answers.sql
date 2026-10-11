/* ============================================================
   ANSWER KEY - JSON & Semi-Structured Data (MEDIUM LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1. JSON preserves exact key order and duplicate keys (re-parsed on every access, no operator/GIN support); JSONB discards whitespace and duplicate keys (keeping the last) and stores a parsed binary form, which queries and indexes much faster - JSONB is almost always the right choice. */
/* Q2. -> returns the child value as jsonb (single-level, chainable); ->> returns it as text (single-level, terminal); #> returns a nested value by path array as jsonb (chainable/multi-level); #>> returns a nested value by path array as text (terminal, multi-level). */
/* Q3. @> tests whether the left document CONTAINS the right document/structure as a subset; ? tests a single top-level key's existence; ?| tests whether ANY of a given array of keys exists; ?& tests whether ALL of a given array of keys exist. */
/* Q4. jsonb_array_elements multiplies row counts whenever it's used in a FROM/LATERAL/CROSS JOIN clause against an array with more than one element - each source row becomes as many output rows as there are array elements (a genuine one-to-many unnest). */
/* Q5. ->> is defined to return the extracted value as PostgreSQL's text type regardless of the original JSON value's type (number, boolean, string), so any numeric comparison or arithmetic needs an explicit cast (e.g. ::numeric) to reinterpret that text as a number. */
/* Q6. jsonb_build_object is for hand-picking specific fields (and renaming/nesting them) into a custom-shaped document; to_jsonb(row) is for a quick, complete dump of every column in a row (or table alias) with the column names as keys, when you want the whole row as-is. */
/* Q7. jsonb_agg collects the aggregated expression into a JSON ARRAY (order-preservable with ORDER BY, duplicates allowed); jsonb_object_agg collects a (key, value) pair per row into a JSON OBJECT (keys should be unique, last value wins on collision). */
/* Q8. jsonb_ops is the default GIN operator class supporting @>, ?, ?|, ?& and is larger; jsonb_path_ops is smaller/faster and supports only @> (and JSONPath's @@ / @?) but not the ? key-existence operators - pick jsonb_path_ops when your workload is purely containment queries. */
/* Q9. A GIN index on JSONB accelerates the containment operator @> and the key-existence operators ? / ?| / ?& - it does not directly accelerate ->>/->/# > extraction or equality on an extracted scalar (those need a separate expression index). */
/* Q10. jsonb_path_query(doc, jsonpath) evaluates a JSONPath expression (a small query language for navigating/filtering JSON, e.g. '$.items[*] ? (@.qty > 5)') against a document and returns matching values as a set - more expressive than chained -> operators for predicates. */
/* Q11. Flatten nested arrays by putting jsonb_array_elements(doc -> 'array_field') in a LATERAL join against the source rows, then extract scalars from each resulting element with ->>/# >> - this turns one nested doc into many flat rows, ready to GROUP BY/aggregate normally. */
/* Q12. A SQL NULL means the column/expression itself has no value; a JSON 'null' is an actual stored JSON value meaning the key is present but its value is null; a missing key means the key was never included in the object at all - `doc->>'k'` returns SQL NULL in both the JSON-null and missing-key cases, so `doc ? 'k'` is needed to tell them apart. */
/* Q13. COALESCE(doc ->> 'field', 'default_value') supplies a fallback whenever the extraction returns NULL (whether from a JSON null or an absent key), so downstream code never has to special-case a missing field. */
/* Q14. JSONB event payloads are flexible (schema can evolve without a migration, nested/variable shapes fit naturally) but sacrifice type safety, query planner statistics, and easy indexing on individual fields compared to dedicated wide columns, which are strongly typed, easily indexed, and cheap to aggregate. */
/* Q15. Round-tripping means converting relational rows to JSON (to_jsonb) and back to relational (->>/#>> extraction with casts) without losing information - achievable as long as every needed field is included in the JSON and each type-cast on the way back matches the original column type. */
/* Q16. jsonb_set(doc, path, new_value) replaces (or inserts) a value at a path; the || operator concatenates/merges two JSONB objects (or appends array elements); both MODIFY a document rather than just read it, so in RetailMart these are conceptual - any actual write happens in your own accio_NN sandbox database, not the shared read-only dataset. */
/* Q17. CREATE INDEX ON tbl ((doc->>'k')) builds a btree on the extracted text value; the planner can then use it for equality/range predicates on doc->>'k' the same way it would for a plain column index - but only if the query's WHERE clause uses that EXACT expression. */
/* Q18. Deeply nested JSON (many levels of objects-within-arrays-within-objects) requires long, hard-to-read path chains to extract anything, and each extra level of jsonb_array_elements is another row-multiplying join - both readability and performance degrade as nesting grows. */
/* Q19. Validate shape in SQL by checking `doc ?& array['key1','key2']` for required keys, `jsonb_typeof(doc->'field') = 'number'` for type, and `(doc->>'field') IN (...)` for an enum - combining these in a WHERE or CASE flags malformed documents before they're trusted. */
/* Q20. jsonb_strip_nulls(doc) removes every key whose value is JSON null throughout a document, which shrinks API payloads (no point shipping "field": null over the wire) and simplifies downstream "is this key present" checks. */
/* Q21. jsonb_agg(expr) (or jsonb_object_agg for a keyed shape) run as a GROUP BY aggregate collapse every row in a group into one array/object value in a single output row - the standard way to build a "parent with children" document from a normalized child table. */
/* Q22. jsonb_pretty(doc) reformats a JSONB value with indentation and line breaks for human-readable debugging output - purely a display convenience, it doesn't change the underlying value. */
/* Q23. Extract several fields with ->> into separate expressions, then either SELECT them as distinct columns directly, or use them as the value expressions inside a Day-21-style CASE/FILTER pivot to turn dynamic JSON keys into fixed output columns. */
/* Q24. JSON-extracted scalars behave like any other expression, so they can be fed straight into window functions - e.g. RANK() OVER (ORDER BY (doc->>'net_total')::numeric DESC) ranks rows by a JSON-derived value exactly like it would a plain column. */
/* Q25. Push JSON parsing to ETL (a nightly job that flattens payloads into typed columns) when the same fields are queried repeatedly and performance/indexing matters; parse live at query time for ad-hoc/rare exploratory queries or when the schema is still in flux and a fixed ETL contract isn't worth building yet. */

/* ============================================================
   SECTION B: EXTRACT, CAST & AGGREGATE (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT pc.proc_name, p.product_name, p.price
FROM audit.procedure_calls pc
JOIN products.products p ON p.product_id = (pc.input_params ->> 'id')::int
ORDER BY pc.call_id
LIMIT 50;

/* Q27. */
SELECT (input_params ->> 'id')::int AS extracted_id, count(*) AS calls
FROM audit.procedure_calls
GROUP BY 1
ORDER BY calls DESC
LIMIT 10;

/* Q28. */
SELECT CASE WHEN (api_json ->> 'status_code')::int BETWEEN 200 AND 299 THEN '2xx'
            WHEN (api_json ->> 'status_code')::int BETWEEN 400 AND 499 THEN '4xx'
            WHEN (api_json ->> 'status_code')::int BETWEEN 500 AND 599 THEN '5xx'
            ELSE 'other' END AS status_band,
       count(*) AS requests
FROM (SELECT jsonb_build_object('status_code', status_code) AS api_json FROM audit.api_requests) x
GROUP BY 1
ORDER BY 1;

/* Q29. */
SELECT api_json ->> 'method' AS method,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY (api_json ->> 'latency')::numeric) AS median_latency,
       percentile_cont(0.95) WITHIN GROUP (ORDER BY (api_json ->> 'latency')::numeric) AS p95_latency
FROM (SELECT jsonb_build_object('method', method, 'latency', response_time_ms) AS api_json FROM audit.api_requests) x
GROUP BY 1
ORDER BY 1;

/* Q30. */
SELECT order_json ->> 'status' AS status, sum((order_json ->> 'net_total')::numeric) AS revenue
FROM (SELECT jsonb_build_object('status', order_status, 'net_total', net_total) AS order_json FROM sales.orders) x
GROUP BY 1
ORDER BY 1;

/* Q31. */
SELECT customer_json ->> 'tier' AS tier, count(*) AS customers,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY (customer_json ->> 'spend')::numeric) AS median_spend
FROM (
  SELECT jsonb_build_object('tier', c.tier, 'spend', coalesce(o.total_spend, 0)) AS customer_json
  FROM customers.customers c
  LEFT JOIN (SELECT cust_id, sum(net_total) AS total_spend FROM sales.orders GROUP BY cust_id) o ON o.cust_id = c.customer_id
) x
GROUP BY 1
ORDER BY 1;

/* Q32. */
SELECT cat.category_name, avg((prod_json ->> 'price')::numeric - (prod_json ->> 'cost')::numeric) AS avg_margin
FROM (
  SELECT p.brand_id, jsonb_build_object('price', p.price, 'cost', p.cost_price) AS prod_json
  FROM products.products p
) x
JOIN core.dim_brand b ON b.brand_id = x.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
GROUP BY cat.category_name
ORDER BY cat.category_name;

/* Q33. */
SELECT monthly_obj -> '2025-03' AS march, monthly_obj -> '2025-04' AS april
FROM (
  SELECT jsonb_object_agg(to_char(month, 'YYYY-MM'), revenue) AS monthly_obj
  FROM (SELECT date_trunc('month', order_date)::date AS month, sum(net_total) AS revenue FROM sales.orders WHERE extract(year FROM order_date) = 2025 GROUP BY 1) m
) x;

/* Q34. */
SELECT product_id, avg((review_json ->> 'rating')::numeric) AS avg_rating
FROM (SELECT product_id, jsonb_build_object('rating', rating) AS review_json FROM customers.reviews) x
GROUP BY product_id
HAVING avg((review_json ->> 'rating')::numeric) > 4
ORDER BY avg_rating DESC
LIMIT 20;

/* Q35. */
SELECT extract(hour FROM (event_json ->> 'ts')::timestamp)::int AS hour_of_day, count(*) AS events
FROM (SELECT jsonb_build_object('ts', event_timestamp) AS event_json FROM web_events.events) x
GROUP BY 1
ORDER BY 1;

/* Q36. */
SELECT customer_json #>> '{address,city}' AS city, count(*) AS customers
FROM (
  SELECT jsonb_build_object('id', c.customer_id, 'address', jsonb_build_object('city', a.city)) AS customer_json
  FROM customers.customers c
  JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = true
) x
GROUP BY 1
ORDER BY customers DESC
LIMIT 20;

/* Q37. */
SELECT ticket_json ->> 'priority' AS priority,
       round(100.0 * count(*) FILTER (WHERE (ticket_json ->> 'resolved_hours')::numeric <= 24) / NULLIF(count(*), 0), 2) AS sla_pct
FROM (
  SELECT jsonb_build_object('priority', priority, 'resolved_hours', extract(epoch FROM (resolved_date - created_date)) / 3600.0) AS ticket_json
  FROM support.tickets
  WHERE resolved_date IS NOT NULL
) x
GROUP BY 1
ORDER BY 1;

/* Q38. */
SELECT count(*) AS mobile_requests
FROM (SELECT jsonb_build_object('user_agent', user_agent) AS api_json FROM audit.api_requests) x
WHERE (api_json ->> 'user_agent') LIKE '%Mobile%';

/* Q39. */
SELECT (store_json ->> 'store_id')::int AS store_id, (store_json ->> 'revenue')::numeric AS revenue,
       rank() OVER (ORDER BY (store_json ->> 'revenue')::numeric DESC) AS revenue_rank
FROM (
  SELECT jsonb_build_object('store_id', s.store_id, 'revenue', coalesce(sum(o.net_total), 0)) AS store_json
  FROM stores.stores s
  LEFT JOIN sales.orders o ON o.store_id = s.store_id
  GROUP BY s.store_id
) x
ORDER BY revenue_rank
LIMIT 20;

/* Q40. */
SELECT (doc ->> 'net_total')::numeric / NULLIF((doc ->> 'gross_total')::numeric, 0) AS net_to_gross_ratio
FROM (SELECT jsonb_build_object('net_total', net_total, 'gross_total', gross_total) AS doc FROM sales.orders) x
WHERE (doc ->> 'net_total')::numeric / NULLIF((doc ->> 'gross_total')::numeric, 0) < 0.9
LIMIT 20;

/* Q41. */
SELECT count(*) FILTER (WHERE api_json ->> 'method' = 'GET') AS get_count,
       count(*) FILTER (WHERE api_json ->> 'method' = 'POST') AS post_count,
       count(*) FILTER (WHERE api_json ->> 'method' = 'PUT') AS put_count,
       count(*) FILTER (WHERE api_json ->> 'method' = 'DELETE') AS delete_count,
       count(*) FILTER (WHERE api_json ->> 'method' = 'PATCH') AS patch_count
FROM (SELECT jsonb_build_object('method', method) AS api_json FROM audit.api_requests) x;

/* Q42. */
SELECT order_id, doc #>> '{payment,mode}' AS payment_mode
FROM (
  SELECT o.order_id, jsonb_build_object('order_id', o.order_id, 'payment', jsonb_build_object('mode', pay.payment_mode)) AS doc
  FROM sales.orders o
  JOIN sales.payments pay ON pay.order_id = o.order_id
) x
ORDER BY order_id
LIMIT 20;

/* Q43. */
SELECT cust_id, order_dates -> -1 AS last_order_date
FROM (SELECT cust_id, jsonb_agg(order_date ORDER BY order_date) AS order_dates FROM sales.orders GROUP BY cust_id) x
ORDER BY cust_id
LIMIT 20;

/* Q44. */
SELECT cust_id, (order_dates ->> i)::date - lag((order_dates ->> i)::date) OVER (PARTITION BY cust_id ORDER BY i) AS gap_days
FROM (SELECT cust_id, jsonb_agg(order_date ORDER BY order_date) AS order_dates FROM sales.orders GROUP BY cust_id) x
CROSS JOIN LATERAL generate_series(0, jsonb_array_length(order_dates) - 1) AS i
ORDER BY cust_id, i
LIMIT 50;

/* Q45. */
SELECT r.region_name, (jsonb_build_object('kpi', jsonb_build_object('median_aov', percentile_cont(0.5) WITHIN GROUP (ORDER BY o.net_total))) #>> '{kpi,median_aov}')::numeric AS median_aov
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;

/* Q46. */
SELECT count(*) AS docs_with_discount
FROM (SELECT jsonb_build_object('order_id', order_id, 'discount', discount_amount) AS doc FROM sales.orders) x
WHERE doc ? 'discount';

/* Q47. */
SELECT array_len, count(*) AS customers
FROM (
  SELECT jsonb_array_length(orders_json) AS array_len
  FROM (SELECT cust_id, jsonb_agg(order_id) AS orders_json FROM sales.orders GROUP BY cust_id) x
) y
GROUP BY array_len
ORDER BY array_len;

/* Q48. */
SELECT (SELECT count(*) FROM jsonb_object_keys(before_doc)) AS keys_before,
       (SELECT count(*) FROM jsonb_object_keys(jsonb_strip_nulls(before_doc))) AS keys_after
FROM (SELECT jsonb_build_object('id', 1, 'discount', NULL::numeric, 'status', 'Delivered') AS before_doc) x;

/* Q49. */
SELECT api_json ->> 'method' AS method,
       CASE WHEN (api_json ->> 'status_code')::int >= 500 THEN '5xx'
            WHEN (api_json ->> 'status_code')::int >= 400 THEN '4xx'
            ELSE 'ok' END AS status_band,
       count(*) AS requests
FROM (SELECT jsonb_build_object('method', method, 'status_code', status_code) AS api_json FROM audit.api_requests) x
GROUP BY 1, 2
ORDER BY 1, 2;

/* Q50. */
SELECT doc, COALESCE(doc ->> 'campaign_source', 'direct') AS source_or_default
FROM (SELECT jsonb_build_object('order_id', order_id) AS doc FROM sales.orders) x
LIMIT 20;

/* ============================================================
   SECTION C: ARRAYS, NESTING & FLATTENING (25)
   ------------------------------------------------------------ */
/* Q51. */
SELECT (item ->> 'prod')::int AS prod_id, sum((item ->> 'amt')::numeric) AS revenue
FROM (
  SELECT o.order_id, jsonb_agg(jsonb_build_object('prod', oi.prod_id, 'qty', oi.quantity, 'amt', oi.net_amount)) AS items
  FROM sales.orders o
  JOIN sales.order_items oi ON oi.order_id = o.order_id
  GROUP BY o.order_id
) x
CROSS JOIN LATERAL jsonb_array_elements(items) AS item
GROUP BY 1
ORDER BY revenue DESC
LIMIT 20;

/* Q52. */
SELECT count(*) AS unnested_order_count, (SELECT count(*) FROM sales.orders) AS base_order_count
FROM (
  SELECT c.customer_id, jsonb_agg(jsonb_build_object('order_id', o.order_id)) AS orders
  FROM customers.customers c
  JOIN sales.orders o ON o.cust_id = c.customer_id
  GROUP BY c.customer_id
) x
CROSS JOIN LATERAL jsonb_array_elements(orders) AS ord;

/* Q53. */
SELECT r.region_name, s.store_id, count(o.order_id) AS orders
FROM core.dim_region r
JOIN stores.stores s ON s.region_id = r.region_id
LEFT JOIN sales.orders o ON o.store_id = s.store_id
GROUP BY r.region_name, s.store_id
ORDER BY r.region_name, s.store_id
LIMIT 50;

/* Q54. */
SELECT category_name, jsonb_agg(jsonb_build_object('prod_id', product_id, 'price', price) ORDER BY price DESC) AS top_products
FROM (
  SELECT cat.category_name, p.product_id, p.price,
         row_number() OVER (PARTITION BY cat.category_name ORDER BY p.price DESC) AS rn
  FROM products.products p
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
) ranked
WHERE rn <= 5
GROUP BY category_name
ORDER BY category_name;

/* Q55. */
SELECT (item ->> 'prod')::int AS prod_id, sum((item ->> 'qty')::int) AS total_qty
FROM (
  SELECT order_id, jsonb_agg(jsonb_build_object('prod', prod_id, 'qty', quantity)) AS items
  FROM sales.order_items
  GROUP BY order_id
) x
CROSS JOIN LATERAL jsonb_array_elements(items) AS item
GROUP BY 1
ORDER BY 1
LIMIT 20;

/* Q56. */
SELECT doc
FROM (
  SELECT jsonb_build_object('order_id', o.order_id, 'items', jsonb_agg(jsonb_build_object('prod_id', oi.prod_id))) AS doc
  FROM sales.orders o
  JOIN sales.order_items oi ON oi.order_id = o.order_id
  GROUP BY o.order_id
) x
WHERE doc @> jsonb_build_object('items', jsonb_build_array(jsonb_build_object('prod_id', (SELECT product_id FROM products.products ORDER BY product_id LIMIT 1))))
LIMIT 20;

/* Q57. */
SELECT doc
FROM (SELECT jsonb_build_object('order_id', order_id, 'status', order_status, 'net_total', net_total) AS doc FROM sales.orders) x
WHERE doc ?& array['order_id', 'status', 'net_total']
LIMIT 20;

/* Q58. */
SELECT order_id, jsonb_array_length(doc -> 'items') AS item_count
FROM (
  SELECT o.order_id, jsonb_build_object('items', jsonb_agg(jsonb_build_object('prod_id', oi.prod_id))) AS doc
  FROM sales.orders o
  JOIN sales.order_items oi ON oi.order_id = o.order_id
  GROUP BY o.order_id
) x
ORDER BY order_id
LIMIT 20;

/* Q59. */
SELECT b.brand_name, jsonb_agg(jsonb_build_object('prod_id', p.product_id, 'rating', pr.avg_rating)) #>> '{0,rating}' AS sample_rating
FROM core.dim_brand b
JOIN products.products p ON p.brand_id = b.brand_id
JOIN (SELECT product_id, avg(rating) AS avg_rating FROM customers.reviews GROUP BY product_id) pr ON pr.product_id = p.product_id
GROUP BY b.brand_name
ORDER BY b.brand_name
LIMIT 10;

/* Q60. */
SELECT idx, item
FROM (SELECT order_id, jsonb_agg(jsonb_build_object('prod_id', prod_id)) AS items FROM sales.order_items GROUP BY order_id ORDER BY order_id LIMIT 3) x
CROSS JOIN LATERAL jsonb_array_elements(items) WITH ORDINALITY AS t(item, idx);

/* Q61. */
SELECT key AS month, sum(value::numeric) AS revenue
FROM (
  SELECT jsonb_object_agg(to_char(month, 'YYYY-MM'), revenue) AS monthly_obj
  FROM (SELECT date_trunc('month', order_date)::date AS month, sum(net_total) AS revenue FROM sales.orders WHERE extract(year FROM order_date) = 2025 GROUP BY 1) m
) x
CROSS JOIN LATERAL jsonb_each_text(monthly_obj)
GROUP BY key
ORDER BY key;

/* Q62. */
SELECT tag, count(*) AS customers
FROM (
  SELECT jsonb_build_array(
    CASE WHEN tier = 'Gold' THEN 'high_value' ELSE 'standard' END,
    CASE WHEN registration_date > current_date - interval '1 year' THEN 'new' ELSE 'established' END
  ) AS tags
  FROM customers.customers
) x
CROSS JOIN LATERAL jsonb_array_elements_text(tags) AS tag
GROUP BY tag
ORDER BY tag;

/* Q63. */
SELECT sum((item ->> 'amt')::numeric) AS resummed, (SELECT sum(net_amount) FROM sales.order_items) AS original
FROM (SELECT jsonb_agg(jsonb_build_object('amt', net_amount)) AS items FROM sales.order_items) x
CROSS JOIN LATERAL jsonb_array_elements(items) AS item;

/* Q64. */
SELECT doc #>> '{store,address,city}' AS deep_city
FROM (SELECT jsonb_build_object('store', jsonb_build_object('address', jsonb_build_object('city', 'Delhi'))) AS doc) x;

/* Q65. */
SELECT doc
FROM (SELECT jsonb_build_object('order_id', order_id, 'net_total', net_total) AS doc FROM sales.orders) x
WHERE (doc ->> 'net_total')::numeric > 5000
LIMIT 20;

/* Q66. */
SELECT prod_qty_map -> '1' AS qty_for_prod_1
FROM (SELECT order_id, jsonb_object_agg(prod_id::text, quantity) AS prod_qty_map FROM sales.order_items GROUP BY order_id) x
LIMIT 20;

/* Q67. */
SELECT jsonb_build_object(
  'customer_id', c.customer_id,
  'orders', (SELECT jsonb_agg(jsonb_build_object('order_id', o.order_id)) FROM sales.orders o WHERE o.cust_id = c.customer_id),
  'reviews', (SELECT jsonb_agg(jsonb_build_object('review_id', r.review_id)) FROM customers.reviews r WHERE r.customer_id = c.customer_id),
  'tickets', (SELECT jsonb_agg(jsonb_build_object('ticket_id', t.ticket_id)) FROM support.tickets t WHERE t.customer_id = c.customer_id),
  'order_count', (SELECT count(*) FROM sales.orders o WHERE o.cust_id = c.customer_id),
  'review_count', (SELECT count(*) FROM customers.reviews r WHERE r.customer_id = c.customer_id),
  'ticket_count', (SELECT count(*) FROM support.tickets t WHERE t.customer_id = c.customer_id)
) AS customer_360
FROM customers.customers c
ORDER BY c.customer_id
LIMIT 10;

/* Q68. */
SELECT c.customer_id, ord.value AS order_json, rev.value AS review_json
FROM customers.customers c
CROSS JOIN LATERAL (SELECT jsonb_agg(jsonb_build_object('order_id', o.order_id)) AS value FROM sales.orders o WHERE o.cust_id = c.customer_id) ord
CROSS JOIN LATERAL (SELECT jsonb_agg(jsonb_build_object('review_id', r.review_id)) AS value FROM customers.reviews r WHERE r.customer_id = c.customer_id) rev
ORDER BY c.customer_id
LIMIT 10;

/* Q69. */
SELECT region_name, month, revenue,
       round(100.0 * (revenue - lag(revenue) OVER (PARTITION BY region_name ORDER BY month)) / NULLIF(lag(revenue) OVER (PARTITION BY region_name ORDER BY month), 0), 2) AS mom_pct
FROM (
  SELECT r.region_name, (item ->> 'month') AS month, (item ->> 'revenue')::numeric AS revenue
  FROM (
    SELECT r.region_name, jsonb_agg(jsonb_build_object('month', month, 'revenue', revenue) ORDER BY month) AS months_json
    FROM (SELECT s.region_id, date_trunc('month', o.order_date)::date AS month, sum(o.net_total) AS revenue
          FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id GROUP BY 1, 2) m
    JOIN core.dim_region r ON r.region_id = m.region_id
    GROUP BY r.region_name
  ) r
  CROSS JOIN LATERAL jsonb_array_elements(months_json) AS item
) x
ORDER BY region_name, month;

/* Q70. */
SELECT doc
FROM (SELECT jsonb_build_object('id', customer_id, 'tier', tier) AS doc FROM customers.customers) x
WHERE doc @> '{"tier":"Gold"}'::jsonb
LIMIT 20;

/* Q71. */
SELECT DISTINCT jsonb_object_keys(jsonb_build_object('order_id', order_id, 'status', order_status, 'net_total', net_total)) AS dynamic_key
FROM sales.orders
LIMIT 5;

/* Q72. */
SELECT (api_json ->> 'method') AS method, (api_json ->> 'status_code')::int AS status_code,
       (api_json ->> 'latency')::int AS latency_ms, (api_json ->> 'user_agent') AS user_agent
FROM (SELECT jsonb_build_object('method', method, 'status_code', status_code, 'latency', response_time_ms, 'user_agent', user_agent) AS api_json FROM audit.api_requests) x
LIMIT 50;

/* Q73. */
SELECT order_id,
       sum((item ->> 'amt')::numeric) FILTER (WHERE cat.category_name = 'Electronics') AS electronics,
       sum((item ->> 'amt')::numeric) FILTER (WHERE cat.category_name = 'Fashion') AS fashion,
       sum((item ->> 'amt')::numeric) FILTER (WHERE cat.category_name = 'Groceries') AS groceries
FROM (
  SELECT o.order_id, jsonb_agg(jsonb_build_object('prod', oi.prod_id, 'amt', oi.net_amount)) AS items
  FROM sales.orders o JOIN sales.order_items oi ON oi.order_id = o.order_id
  GROUP BY o.order_id
) x
CROSS JOIN LATERAL jsonb_array_elements(items) AS item
JOIN products.products p ON p.product_id = (item ->> 'prod')::int
JOIN core.dim_brand b ON b.brand_id = p.brand_id
JOIN core.dim_category cat ON cat.category_id = b.category_id
GROUP BY order_id
ORDER BY order_id
LIMIT 20;

/* Q74. */
SELECT order_id, avg((item ->> 'amt')::numeric) AS avg_item_amount
FROM (SELECT order_id, jsonb_agg(jsonb_build_object('amt', net_amount)) AS items FROM sales.order_items GROUP BY order_id) x
CROSS JOIN LATERAL jsonb_array_elements(items) AS item
GROUP BY order_id
ORDER BY order_id
LIMIT 20;

/* Q75. */
SELECT o.order_id, o.net_total, reconstructed.total, o.net_total = reconstructed.total AS reconciled
FROM sales.orders o
JOIN (
  SELECT order_id, sum((item ->> 'amt')::numeric) AS total
  FROM (SELECT order_id, jsonb_agg(jsonb_build_object('amt', net_amount)) AS items FROM sales.order_items GROUP BY order_id) x
  CROSS JOIN LATERAL jsonb_array_elements(items) AS item
  GROUP BY order_id
) reconstructed ON reconstructed.order_id = o.order_id
ORDER BY o.order_id
LIMIT 20;

/* ============================================================
   SECTION D: PIPELINES & APPLIED (25)
   ------------------------------------------------------------ */
/* Q76. */
SELECT jsonb_build_object(
  'order', jsonb_build_object('order_id', o.order_id, 'status', o.order_status, 'net_total', o.net_total),
  'items', (SELECT jsonb_agg(jsonb_build_object('prod_id', oi.prod_id, 'qty', oi.quantity)) FROM sales.order_items oi WHERE oi.order_id = o.order_id),
  'payment', (SELECT jsonb_build_object('mode', pay.payment_mode, 'amount', pay.amount) FROM sales.payments pay WHERE pay.order_id = o.order_id LIMIT 1),
  'customer', jsonb_build_object('customer_id', c.customer_id, 'name', c.first_name || ' ' || c.last_name)
) AS order_export
FROM sales.orders o
JOIN customers.customers c ON c.customer_id = o.cust_id
ORDER BY o.order_id
LIMIT 10;

/* Q77. */
SELECT count(*) AS flattened_items,
       (SELECT count(*) FROM sales.order_items oi JOIN sales.orders o2 ON o2.order_id = oi.order_id) AS base_join_items
FROM (
  SELECT jsonb_build_object('items', jsonb_agg(jsonb_build_object('prod_id', oi.prod_id))) AS doc
  FROM sales.orders o
  JOIN sales.order_items oi ON oi.order_id = o.order_id
  GROUP BY o.order_id
) x
CROSS JOIN LATERAL jsonb_array_elements(x.doc -> 'items') AS item;

/* Q78. */
SELECT jsonb_build_object(
  'customer_id', c.customer_id,
  'latest_order', (SELECT jsonb_build_object('order_id', o2.order_id, 'order_date', o2.order_date) FROM sales.orders o2 WHERE o2.cust_id = c.customer_id ORDER BY o2.order_date DESC LIMIT 1),
  'median_spend', (SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY o3.net_total) FROM sales.orders o3 WHERE o3.cust_id = c.customer_id)
) AS customer_doc
FROM customers.customers c
ORDER BY c.customer_id
LIMIT 20;

/* Q79. */
SELECT r.region_name, jsonb_object_agg(to_char(m.month, 'YYYY-MM'), m.revenue ORDER BY m.month) AS monthly_revenue_obj
FROM (SELECT s.region_id, date_trunc('month', o.order_date)::date AS month, sum(o.net_total) AS revenue
      FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id
      WHERE extract(year FROM o.order_date) = 2025 GROUP BY 1, 2) m
JOIN core.dim_region r ON r.region_id = m.region_id
GROUP BY r.region_name
ORDER BY r.region_name;

/* Q80. */
SELECT jsonb_object_agg(day::text, revenue) AS time_series
FROM (
  SELECT d.day::date::text AS day, coalesce(sum(o.net_total), 0) AS revenue
  FROM generate_series((SELECT max(order_date) FROM sales.orders) - interval '89 days',
                        (SELECT max(order_date) FROM sales.orders), interval '1 day') AS d(day)
  LEFT JOIN sales.orders o ON o.order_date = d.day::date
  GROUP BY d.day
) x;

/* Q81. */
SELECT api_json ->> 'endpoint' AS endpoint,
       round(100.0 * count(*) FILTER (WHERE (api_json ->> 'status_code')::int >= 400) / count(*), 2) AS error_pct
FROM (SELECT jsonb_build_object('endpoint', endpoint, 'status_code', status_code) AS api_json FROM audit.api_requests) x
GROUP BY 1
ORDER BY 1;

/* Q82. */
SELECT jsonb_object_agg(method, jsonb_build_object('p50', p50, 'p95', p95, 'p99', p99)) AS latency_slo
FROM (
  SELECT method,
         percentile_cont(0.5) WITHIN GROUP (ORDER BY response_time_ms) AS p50,
         percentile_cont(0.95) WITHIN GROUP (ORDER BY response_time_ms) AS p95,
         percentile_cont(0.99) WITHIN GROUP (ORDER BY response_time_ms) AS p99
  FROM audit.api_requests
  GROUP BY method
) x;

/* Q83. */
SELECT jsonb_agg(jsonb_build_object('rank', rn, 'customer_id', cust_id, 'total_spend', total_spend) ORDER BY rn) AS top_customers
FROM (
  SELECT cust_id, sum(net_total) AS total_spend, rank() OVER (ORDER BY sum(net_total) DESC) AS rn
  FROM sales.orders
  GROUP BY cust_id
  ORDER BY total_spend DESC
  LIMIT 10
) x;

/* Q84. */
SELECT jsonb_build_object('prod_id', p.product_id, 'price', p.price,
       'in_promo', EXISTS (SELECT 1 FROM products.promotions pr WHERE pr.active = true),
       'margin', round(((p.price - p.cost_price) / NULLIF(p.price, 0))::numeric, 3)) AS catalog_doc
FROM products.products p
ORDER BY p.product_id
LIMIT 20;

/* Q85. */
SELECT jsonb_build_object('table', table_name, 'column', column_name, 'old', old_value, 'new', new_value) AS change_doc,
       abs((new_value::numeric - old_value::numeric) / NULLIF(old_value::numeric, 0)) AS pct_change
FROM audit.record_changes
WHERE column_name = 'price'
  AND old_value ~ '^[0-9.]+$' AND new_value ~ '^[0-9.]+$'
  AND abs((new_value::numeric - old_value::numeric) / NULLIF(old_value::numeric, 0)) > 0.5
ORDER BY pct_change DESC
LIMIT 20;

/* Q86. */
SELECT jsonb_build_object('region', r.region_name,
       'kpis', jsonb_build_object(
         'median_order_value', percentile_cont(0.5) WITHIN GROUP (ORDER BY o.net_total),
         'p95_order_value', percentile_cont(0.95) WITHIN GROUP (ORDER BY o.net_total),
         'order_count', count(*)
       )) AS region_doc
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;

/* Q87. */
SELECT jsonb_build_object(
  'page_views', (SELECT count(*) FROM web_events.page_views),
  'events', (SELECT count(*) FROM web_events.events),
  'orders', (SELECT count(*) FROM sales.orders)
) AS funnel_counts;

/* Q88. */
SELECT cat.category_name, jsonb_agg(units ORDER BY month_num) AS monthly_units
FROM (
  SELECT cat.category_name, extract(month FROM o.order_date)::int AS month_num, sum(oi.quantity) AS units
  FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
  WHERE extract(year FROM o.order_date) = 2025
  GROUP BY cat.category_name, month_num
) cat
GROUP BY category_name
ORDER BY category_name;

/* Q89. */
SELECT order_id, doc, doc ?& array['order_id', 'status'] AS is_valid
FROM (SELECT order_id, jsonb_build_object('order_id', order_id, 'status', order_status) AS doc FROM sales.orders) x
ORDER BY order_id
LIMIT 20;

/* Q90. */
SELECT doc
FROM (SELECT jsonb_build_object('order_id', order_id, 'status', order_status, 'store_id', store_id) AS doc FROM sales.orders) x
WHERE doc @> jsonb_build_object('status', 'Delivered', 'store_id', (SELECT min(store_id) FROM stores.stores))
LIMIT 20;

/* Q91. */
SELECT cust_id AS customer_id,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY gap_days) AS median_gap_days
FROM (SELECT cust_id, order_date - lag(order_date) OVER (PARTITION BY cust_id ORDER BY order_date) AS gap_days FROM sales.orders) x
WHERE gap_days IS NOT NULL
GROUP BY cust_id
ORDER BY cust_id
LIMIT 20;

/* Q92. */
SELECT jsonb_agg(jsonb_build_object('metric', metric, 'value', value)) AS kpi_array
FROM (
  SELECT 'total_orders' AS metric, count(*)::numeric AS value FROM sales.orders
  UNION ALL
  SELECT 'total_revenue', sum(net_total) FROM sales.orders
  UNION ALL
  SELECT 'total_customers', count(*)::numeric FROM customers.customers
) kpis;

/* Q93. */
SELECT hour_of_day, count(*) FILTER (WHERE (api_json ->> 'status_code')::int >= 400) AS errors
FROM (SELECT jsonb_build_object('status_code', status_code, 'ts', timestamp) AS api_json, extract(hour FROM timestamp)::int AS hour_of_day FROM audit.api_requests) x
GROUP BY hour_of_day
ORDER BY hour_of_day;

/* Q94. */
SELECT jsonb_agg(jsonb_build_object('rank', rn, 'store_id', store_id, 'median_order_value', median_val) ORDER BY rn) AS leaderboard
FROM (
  SELECT o.store_id, percentile_cont(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_val,
         rank() OVER (ORDER BY percentile_cont(0.5) WITHIN GROUP (ORDER BY o.net_total) DESC) AS rn
  FROM sales.orders o
  GROUP BY o.store_id
  ORDER BY median_val DESC
  LIMIT 10
) x;

/* Q95. */
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

/* Q96. */
SELECT doc
FROM (
  SELECT jsonb_build_object('order_id', o.order_id, 'items', jsonb_agg(jsonb_build_object('prod_id', oi.prod_id))) AS doc
  FROM sales.orders o
  JOIN sales.order_items oi ON oi.order_id = o.order_id
  GROUP BY o.order_id
) x
WHERE EXISTS (
  SELECT 1 FROM sales.returns r WHERE r.order_id = (x.doc ->> 'order_id')::int
)
LIMIT 20;

/* Q97. */
SELECT jsonb_object_agg(slot_start::text, page_views) AS slot_counts_json
FROM (
  SELECT date_trunc('hour', view_timestamp) + floor(extract(minute FROM view_timestamp) / 15) * interval '15 min' AS slot_start,
         count(*) AS page_views
  FROM web_events.page_views
  WHERE view_timestamp >= '2025-06-02' AND view_timestamp < '2025-06-03'
  GROUP BY 1
) x;

/* Q98. */
SELECT (SELECT sum((item ->> 'net_total')::numeric) FROM (SELECT jsonb_agg(jsonb_build_object('net_total', net_total)) AS items FROM sales.orders) j CROSS JOIN LATERAL jsonb_array_elements(items) AS item) AS json_total,
       (SELECT sum(net_total) FROM sales.orders) AS sql_total;

/* Q99. */
SELECT jsonb_build_object(
  'data', (SELECT jsonb_agg(jsonb_build_object('order_id', order_id, 'net_total', net_total)) FROM sales.orders WHERE order_id BETWEEN 1 AND 20),
  'meta', jsonb_build_object('count', 20, 'page', 1)
) AS api_response;

/* Q100. */
SELECT jsonb_agg(jsonb_build_object(
  'region', region_name, 'median_aov', median_aov, 'p95', p95, 'orders', orders, 'latest_order', latest_order
)) AS exec_dashboard
FROM (
  SELECT r.region_name,
         percentile_cont(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov,
         percentile_cont(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95,
         count(*) AS orders,
         max(o.order_date) AS latest_order
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  JOIN core.dim_region r ON r.region_id = s.region_id
  GROUP BY r.region_name
) x;

/* ============================================================
   END OF ANSWER KEY - MEDIUM LEVEL (100/100)
============================================================ */
