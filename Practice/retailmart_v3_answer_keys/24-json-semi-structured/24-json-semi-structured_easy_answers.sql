/* ============================================================
   ANSWER KEY - JSON & Semi-Structured Data (EASY LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1. JSON stores an exact text copy (preserves whitespace, key order, duplicate keys) and is re-parsed on every read; JSONB stores a parsed binary form (no whitespace, dedups keys keeping the last, no guaranteed key order) that's faster to query and can be GIN-indexed. */
/* Q2. -> returns the value as jsonb (keeps it JSON-typed, chainable); ->> returns the value as text (ready for casting/string comparison, but no longer chainable with -> ). */
/* Q3. Use ->> when you need the actual scalar value (to cast to numeric/date, compare in WHERE, or display as text); use -> when you need to keep navigating into a nested object/array or return raw JSON. */
/* Q4. #> takes an array of keys/indexes and returns the value at that nested path as jsonb; #>> does the same but returns it as text. */
/* Q5. @> tests whether the left JSONB value contains the right JSONB value as a subset (all its keys/values, or array elements, are present). */
/* Q6. ? tests whether a given string exists as a top-level key in a JSON object (or as an element in a top-level JSON array). */
/* Q7. jsonb_array_elements expands a JSONB array into a set of rows, one row per array element (as jsonb), used in a FROM/LATERAL clause. */
/* Q8. jsonb_array_elements returns each element as jsonb (keeps JSON typing); jsonb_array_elements_text returns each element as plain text. */
/* Q9. jsonb_build_object(k1,v1,k2,v2,...) constructs a JSONB object from alternating key/value arguments, e.g. jsonb_build_object('id',1,'name','A') -> {"id":1,"name":"A"}. */
/* Q10. to_jsonb(value) converts any SQL value, or an entire row, into its JSONB representation - a whole row becomes a JSON object keyed by column name. */
/* Q11. jsonb_agg(expr) is an aggregate that collects the expr value from every row in the group into one JSONB array. */
/* Q12. to_jsonb(row) produces a single JSON object whose keys are the row's column names and whose values are that row's column values. */
/* Q13. Because ->> always returns text regardless of the underlying JSON value's type, so PostgreSQL can't do numeric math on it until you explicitly cast it (e.g. ::numeric). */
/* Q14. jsonb_object_keys returns the set of top-level key names of a JSON object, one row per key - useful for discovering a document's dynamic fields. */
/* Q15. jsonb_path_query runs a JSONPath expression against a JSONB value and returns matching values as a set - lets you filter/navigate with predicates in one expression rather than chained operators. */
/* Q16. JSONB is pre-parsed binary, so it doesn't need re-parsing on every read, supports fast operators (@>, ?, ->) and GIN indexing, and dedups keys - all far more efficient than storing the same data as plain text. */
/* Q17. Nested JSON typically arrives from external APIs (a vendor's REST response), event streams (Kafka/webhook payloads), or application logs - all producing variable, nested structures rather than fixed relational rows. */
/* Q18. Flattening means turning nested JSON (objects/arrays) into plain relational rows and columns - e.g. exploding an "items" array into one row per item - so the data can be joined/grouped/aggregated normally. */
/* Q19. A GIN index on a JSONB column lets containment (@>) and key-existence (?) queries jump straight to matching rows instead of scanning and parsing every document, which matters once a table has many JSON rows. */
/* Q20. audit.procedure_calls.input_params (shape {"id": <int>}) is RetailMart's one real JSONB column; everywhere else, JSON is simulated by building it from ordinary relational rows with to_jsonb/jsonb_build_object. */
/* Q21. jsonb_build_array(v1, v2, ...) constructs a JSONB array from its arguments, e.g. jsonb_build_array(1,2,3) -> [1,2,3]. */
/* Q22. A JSON object {} is an unordered set of key-value pairs (like a map/record); a JSON array [] is an ordered list of values (like a list) - objects are navigated by key, arrays by position. */
/* Q23. A SQL NULL and a JSON null are different: a SQL NULL means "no value stored" (the column/expression is absent), while a JSON null is an actual JSON value meaning "this key exists and its value is null" - jsonb_build_object with a NULL argument produces a real JSON null, not a missing key. */
/* Q24. jsonb_each expands a JSON object into (key, value) row pairs with the value as jsonb; jsonb_each_text does the same but returns the value as text. */
/* Q25. Because JSON's semantics treat a missing key the same way SQL treats an unmatched value - it's simply absent, so PostgreSQL returns NULL (consistent with how SQL represents "no value") rather than throwing an error. */

/* ============================================================
   SECTION B: EXTRACT & BUILD BASICS (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT call_id, input_params ->> 'id' AS id_text
FROM audit.procedure_calls
ORDER BY call_id
LIMIT 100;

/* Q27. */
SELECT call_id, call_id + (input_params ->> 'id')::int AS call_id_plus_id
FROM audit.procedure_calls
ORDER BY call_id
LIMIT 100;

/* Q28. */
SELECT count(*) AS calls_with_id_key
FROM audit.procedure_calls
WHERE input_params ? 'id';

/* Q29. */
SELECT pc.call_id, pc.proc_name, (pc.input_params ->> 'id')::int AS extracted_id, p.product_name
FROM audit.procedure_calls pc
JOIN products.products p ON p.product_id = (pc.input_params ->> 'id')::int
ORDER BY pc.call_id
LIMIT 100;

/* Q30. */
SELECT jsonb_build_object('order_id', order_id, 'net_total', net_total, 'status', order_status) AS order_json
FROM sales.orders
ORDER BY order_id
LIMIT 10;

/* Q31. */
SELECT to_jsonb(o.*) AS order_doc
FROM sales.orders o
ORDER BY order_id
LIMIT 10;

/* Q32. */
SELECT order_id, (to_jsonb(o.*) ->> 'order_status') AS status
FROM sales.orders o
ORDER BY order_id
LIMIT 10;

/* Q33. */
SELECT jsonb_build_object('method', method, 'status_code', status_code, 'latency_ms', response_time_ms, 'user_agent', user_agent) AS api_json
FROM audit.api_requests
LIMIT 10;

/* Q34. */
SELECT api_json ->> 'method' AS method, (api_json ->> 'status_code')::int AS status_code
FROM (
  SELECT jsonb_build_object('method', method, 'status_code', status_code) AS api_json
  FROM audit.api_requests
  LIMIT 10
) x;

/* Q35. */
SELECT sum((order_json ->> 'net_total')::numeric) AS total_revenue
FROM (
  SELECT jsonb_build_object('order_id', order_id, 'net_total', net_total) AS order_json
  FROM sales.orders
) x;

/* Q36. */
SELECT jsonb_build_object('id', customer_id, 'name', first_name || ' ' || last_name, 'tier', tier) AS customer_json
FROM customers.customers
ORDER BY customer_id
LIMIT 10;

/* Q37. */
SELECT customer_json ->> 'tier' AS tier, count(*) AS customers
FROM (
  SELECT jsonb_build_object('id', customer_id, 'tier', tier) AS customer_json
  FROM customers.customers
) x
GROUP BY 1
ORDER BY 1;

/* Q38. */
SELECT (product_json ->> 'prod_id')::int AS prod_id,
       (product_json ->> 'price')::numeric - (product_json ->> 'cost')::numeric AS margin
FROM (
  SELECT jsonb_build_object('prod_id', product_id, 'price', price, 'cost', cost_price) AS product_json
  FROM products.products
) x
ORDER BY 1
LIMIT 20;

/* Q39. */
SELECT jsonb_build_object('store_id', s.store_id, 'name', s.store_name,
       'address', jsonb_build_object('city', s.city, 'region_id', s.region_id)) AS store_json
FROM stores.stores s
ORDER BY s.store_id
LIMIT 10;

/* Q40. */
SELECT order_json
FROM (
  SELECT jsonb_build_object('order_id', order_id, 'status', order_status) AS order_json
  FROM sales.orders
) x
WHERE order_json ->> 'status' = 'Delivered'
LIMIT 20;

/* Q41. */
SELECT (review_json ->> 'rating')::int AS rating
FROM (
  SELECT jsonb_build_object('rating', rating, 'date', review_date) AS review_json
  FROM customers.reviews
) x
ORDER BY rating
LIMIT 20;

/* Q42. */
SELECT jsonb_build_object('id', 1, 'value', NULL::text) AS doc_with_null;

/* Q43. */
SELECT order_json, COALESCE(order_json ->> 'discount', '0') AS discount_or_default
FROM (
  SELECT jsonb_build_object('order_id', order_id, 'status', order_status) AS order_json
  FROM sales.orders
) x
LIMIT 20;

/* Q44. */
SELECT order_json #>> '{status}' AS status_via_path
FROM (
  SELECT jsonb_build_object('order_id', order_id, 'status', order_status) AS order_json
  FROM sales.orders
) x
LIMIT 20;

/* Q45. */
SELECT count(DISTINCT (api_json ->> 'method')) AS distinct_methods
FROM (
  SELECT jsonb_build_object('method', method) AS api_json
  FROM audit.api_requests
) x;

/* Q46. */
SELECT ticket_json ->> 'priority' AS priority, count(*) AS tickets
FROM (
  SELECT jsonb_build_object('priority', priority, 'subject', subject) AS ticket_json
  FROM support.tickets
) x
GROUP BY 1
ORDER BY 1;

/* Q47. */
SELECT (order_json ->> 'status') || ' - ' || (order_json ->> 'order_id') AS label
FROM (
  SELECT jsonb_build_object('order_id', order_id, 'status', order_status) AS order_json
  FROM sales.orders
) x
LIMIT 20;

/* Q48. */
SELECT employee_json
FROM (
  SELECT jsonb_build_object('name', first_name || ' ' || last_name, 'dept', dept_id) AS employee_json
  FROM stores.employees
) x
WHERE (employee_json ->> 'dept')::int = 1
LIMIT 20;

/* Q49. */
SELECT customer_id, (to_jsonb(c.*) ->> 'customer_id')::int AS roundtrip_id,
       customer_id = (to_jsonb(c.*) ->> 'customer_id')::int AS matches
FROM customers.customers c
ORDER BY customer_id
LIMIT 20;

/* Q50. */
SELECT order_json, order_json ? 'discount' AS has_discount_key
FROM (
  SELECT jsonb_build_object('order_id', order_id, 'status', order_status) AS order_json
  FROM sales.orders
) x
LIMIT 20;

/* ============================================================
   SECTION C: ARRAYS & NESTING (25)
   ------------------------------------------------------------ */
/* Q51. */
SELECT order_id, jsonb_agg(jsonb_build_object('prod_id', prod_id, 'qty', quantity, 'net_amount', net_amount)) AS items_json
FROM sales.order_items
GROUP BY order_id
ORDER BY order_id
LIMIT 10;

/* Q52. */
SELECT jsonb_build_object('order_id', order_id, 'items', jsonb_agg(jsonb_build_object('prod_id', prod_id, 'qty', quantity))) AS order_doc
FROM sales.order_items
GROUP BY order_id
ORDER BY order_id
LIMIT 10;

/* Q53. */
SELECT order_id, item
FROM (
  SELECT order_id, jsonb_agg(jsonb_build_object('prod_id', prod_id, 'qty', quantity)) AS items
  FROM sales.order_items
  GROUP BY order_id
  LIMIT 10
) x
CROSS JOIN LATERAL jsonb_array_elements(items) AS item;

/* Q54. */
SELECT order_id, jsonb_array_length(items) AS item_count
FROM (
  SELECT order_id, jsonb_agg(jsonb_build_object('prod_id', prod_id)) AS items
  FROM sales.order_items
  GROUP BY order_id
) x
ORDER BY order_id
LIMIT 20;

/* Q55. */
SELECT jsonb_build_object('customer_id', c.customer_id, 'orders', jsonb_agg(jsonb_build_object('order_id', o.order_id, 'net_total', o.net_total))) AS customer_doc
FROM customers.customers c
JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY c.customer_id
ORDER BY c.customer_id
LIMIT 10;

/* Q56. */
SELECT order_id, items -> 0 AS first_item
FROM (
  SELECT order_id, jsonb_agg(jsonb_build_object('prod_id', prod_id)) AS items
  FROM sales.order_items
  GROUP BY order_id
) x
ORDER BY order_id
LIMIT 10;

/* Q57. */
SELECT tag
FROM (SELECT jsonb_build_array('electronics', 'sale', 'featured') AS tags) t
CROSS JOIN LATERAL jsonb_array_elements_text(tags) AS tag;

/* Q58. */
SELECT (item ->> 'prod_id')::int AS prod_id, count(*) AS occurrences
FROM (
  SELECT order_id, jsonb_agg(jsonb_build_object('prod_id', prod_id)) AS items
  FROM sales.order_items
  GROUP BY order_id
) x
CROSS JOIN LATERAL jsonb_array_elements(items) AS item
GROUP BY 1
ORDER BY occurrences DESC
LIMIT 20;

/* Q59. */
SELECT jsonb_build_object('region', r.region_name, 'stores', jsonb_agg(jsonb_build_object('store_id', s.store_id, 'city', s.city))) AS region_doc
FROM core.dim_region r
JOIN stores.stores s ON s.region_id = r.region_id
GROUP BY r.region_name
ORDER BY r.region_name
LIMIT 10;

/* Q60. */
SELECT order_id, sum((item ->> 'qty')::int) AS total_qty
FROM (
  SELECT order_id, jsonb_agg(jsonb_build_object('qty', quantity)) AS items
  FROM sales.order_items
  GROUP BY order_id
) x
CROSS JOIN LATERAL jsonb_array_elements(items) AS item
GROUP BY order_id
ORDER BY order_id
LIMIT 20;

/* Q61. */
SELECT product_id, avg((r ->> 'rating')::numeric) AS avg_rating
FROM (
  SELECT product_id, jsonb_agg(jsonb_build_object('rating', rating)) AS reviews
  FROM customers.reviews
  GROUP BY product_id
) x
CROSS JOIN LATERAL jsonb_array_elements(reviews) AS r
GROUP BY product_id
ORDER BY product_id
LIMIT 20;

/* Q62. */
SELECT doc #> '{address,city}' AS city_jsonb
FROM (SELECT jsonb_build_object('name', 'Store A', 'address', jsonb_build_object('city', 'Mumbai', 'pincode', '400001')) AS doc) x;

/* Q63. */
SELECT doc #>> '{address,city}' AS city_text
FROM (SELECT jsonb_build_object('name', 'Store A', 'address', jsonb_build_object('city', 'Mumbai', 'pincode', '400001')) AS doc) x;

/* Q64. */
SELECT jsonb_build_object('region', r.region_name,
       'store', jsonb_build_object('store_id', s.store_id, 'count', 1)) #>> '{store,count}' AS deep_count
FROM core.dim_region r
JOIN stores.stores s ON s.region_id = r.region_id
LIMIT 10;

/* Q65. */
SELECT order_json
FROM (
  SELECT jsonb_build_object('order_id', order_id, 'status', order_status) AS order_json
  FROM sales.orders
) x
WHERE order_json @> '{"status":"Delivered"}'::jsonb
LIMIT 20;

/* Q66. */
SELECT order_json ? 'status' AS has_status_key
FROM (
  SELECT jsonb_build_object('order_id', order_id, 'status', order_status) AS order_json
  FROM sales.orders
) x
LIMIT 20;

/* Q67. */
SELECT jsonb_object_keys(jsonb_build_object('order_id', order_id, 'net_total', net_total, 'status', order_status)) AS key_name
FROM sales.orders
LIMIT 1;

/* Q68. */
SELECT jsonb_agg(DISTINCT mode_name) AS payment_modes_json
FROM finance.payment_modes;

/* Q69. */
SELECT elem
FROM (
  SELECT jsonb_agg(jsonb_build_object('month', month, 'revenue', revenue)) AS monthly_json
  FROM (
    SELECT date_trunc('month', order_date)::date AS month, sum(net_total) AS revenue
    FROM sales.orders
    WHERE extract(year FROM order_date) = 2025
    GROUP BY 1
  ) m
) sub
CROSS JOIN LATERAL jsonb_array_elements(monthly_json) AS elem
LIMIT 20;

/* Q70. */
SELECT doc, (doc ->> 'total')::numeric AS total_for_sort
FROM (
  SELECT jsonb_build_object('customer', c.customer_id, 'order_count', count(o.order_id), 'total', sum(o.net_total)) AS doc
  FROM customers.customers c
  JOIN sales.orders o ON o.cust_id = c.customer_id
  GROUP BY c.customer_id
) x
ORDER BY total_for_sort DESC
LIMIT 20;

/* Q71. */
SELECT category_name, jsonb_agg(product_name ORDER BY price DESC) AS top_products
FROM (
  SELECT cat.category_name, p.product_name, p.price,
         row_number() OVER (PARTITION BY cat.category_name ORDER BY p.price DESC) AS rn
  FROM products.products p
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
) ranked
WHERE rn <= 5
GROUP BY category_name
ORDER BY category_name;

/* Q72. */
SELECT jsonb_build_object('brand', b.brand_name,
       'products', jsonb_agg(jsonb_build_object('prod_id', p.product_id, 'price', p.price))) AS brand_doc
FROM core.dim_brand b
JOIN products.products p ON p.brand_id = b.brand_id
GROUP BY b.brand_name
ORDER BY b.brand_name
LIMIT 5;

/* Q73. */
SELECT jsonb_agg(order_id ORDER BY order_date) AS order_ids_by_date
FROM sales.orders
WHERE cust_id = (SELECT min(customer_id) FROM customers.customers);

/* Q74. */
SELECT cust_id AS customer_id, jsonb_agg(order_date ORDER BY order_date) AS order_dates_json
FROM sales.orders
GROUP BY cust_id
ORDER BY cust_id
LIMIT 10;

/* Q75. */
SELECT order_id, count(*) AS key_count
FROM (
  SELECT order_id, jsonb_build_object('order_id', order_id, 'net_total', net_total, 'status', order_status) AS doc
  FROM sales.orders
  LIMIT 5
) x
CROSS JOIN LATERAL jsonb_object_keys(doc)
GROUP BY order_id;

/* ============================================================
   SECTION D: COMBINED / PIPELINES (25)
   ------------------------------------------------------------ */
/* Q76. */
SELECT jsonb_build_object(
  'order', jsonb_build_object('order_id', o.order_id, 'status', o.order_status, 'net_total', o.net_total),
  'items', (SELECT jsonb_agg(jsonb_build_object('prod_id', oi.prod_id, 'qty', oi.quantity)) FROM sales.order_items oi WHERE oi.order_id = o.order_id),
  'payment', (SELECT jsonb_build_object('mode', pay.payment_mode, 'amount', pay.amount) FROM sales.payments pay WHERE pay.order_id = o.order_id LIMIT 1)
) AS order_export
FROM sales.orders o
ORDER BY o.order_id
LIMIT 10;

/* Q77. */
SELECT (doc -> 'order' ->> 'order_id')::int AS order_id,
       (doc -> 'order' ->> 'status') AS status,
       (item ->> 'prod_id')::int AS prod_id,
       (item ->> 'qty')::int AS qty
FROM (
  SELECT jsonb_build_object('order', jsonb_build_object('order_id', o.order_id, 'status', o.order_status),
         'items', (SELECT jsonb_agg(jsonb_build_object('prod_id', oi.prod_id, 'qty', oi.quantity)) FROM sales.order_items oi WHERE oi.order_id = o.order_id)) AS doc
  FROM sales.orders o
  LIMIT 10
) x
CROSS JOIN LATERAL jsonb_array_elements(doc -> 'items') AS item;

/* Q78. */
SELECT jsonb_build_object(
  'customer_id', c.customer_id,
  'name', c.first_name || ' ' || c.last_name,
  'tier', c.tier,
  'order_count', count(o.order_id),
  'latest_order', max(o.order_date)
) AS customer_360
FROM customers.customers c
LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.tier
ORDER BY c.customer_id
LIMIT 20;

/* Q79. */
SELECT customer_id, orders_json
FROM (
  SELECT cust_id AS customer_id, jsonb_agg(jsonb_build_object('order_id', order_id, 'net_total', net_total)) AS orders_json, count(*) AS n
  FROM sales.orders
  GROUP BY cust_id
) x
WHERE n > 5
ORDER BY customer_id
LIMIT 20;

/* Q80. */
SELECT CASE WHEN (api_json ->> 'status_code')::int >= 400 THEN 'error' ELSE 'ok' END AS category, count(*) AS requests
FROM (
  SELECT jsonb_build_object('status_code', status_code) AS api_json
  FROM audit.api_requests
) x
GROUP BY 1;

/* Q81. */
SELECT api_json ->> 'method' AS method,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY (api_json ->> 'latency')::numeric) AS median_latency
FROM (
  SELECT jsonb_build_object('method', method, 'latency', response_time_ms) AS api_json
  FROM audit.api_requests
) x
GROUP BY 1
ORDER BY 1;

/* Q82. */
SELECT extract(hour FROM (event_json ->> 'ts')::timestamp)::int AS hour_of_day, count(*) AS events
FROM (
  SELECT jsonb_build_object('event_type', event_type, 'ts', event_timestamp) AS event_json
  FROM web_events.events
) x
GROUP BY 1
ORDER BY 1;

/* Q83. */
SELECT sum((item ->> 'net_amount')::numeric) AS resummed_total, (SELECT sum(net_total) FROM sales.orders) AS original_total
FROM (
  SELECT jsonb_agg(jsonb_build_object('net_amount', net_amount)) AS items
  FROM sales.order_items
) x
CROSS JOIN LATERAL jsonb_array_elements(items) AS item;

/* Q84. */
SELECT jsonb_object_agg(to_char(month, 'YYYY-MM'), revenue) AS monthly_revenue_obj
FROM (
  SELECT date_trunc('month', order_date)::date AS month, sum(net_total) AS revenue
  FROM sales.orders
  WHERE extract(year FROM order_date) = 2025
  GROUP BY 1
) m;

/* Q85. */
SELECT monthly_revenue_obj -> '2025-06' AS june_revenue, monthly_revenue_obj -> '2025-07' AS july_revenue
FROM (
  SELECT jsonb_object_agg(to_char(month, 'YYYY-MM'), revenue) AS monthly_revenue_obj
  FROM (
    SELECT date_trunc('month', order_date)::date AS month, sum(net_total) AS revenue
    FROM sales.orders
    WHERE extract(year FROM order_date) = 2025
    GROUP BY 1
  ) m
) x;

/* Q86. */
SELECT jsonb_build_object('region', r.region_name,
       'metrics', jsonb_build_object(
         'median_order_value', percentile_cont(0.5) WITHIN GROUP (ORDER BY o.net_total),
         'p95_order_value', percentile_cont(0.95) WITHIN GROUP (ORDER BY o.net_total)
       )) AS region_doc
FROM core.dim_region r
JOIN stores.stores s ON s.region_id = r.region_id
JOIN sales.orders o ON o.store_id = s.store_id
GROUP BY r.region_name
ORDER BY r.region_name;

/* Q87. */
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

/* Q88. */
SELECT ticket_json
FROM (
  SELECT jsonb_build_object('priority', priority, 'subject', subject) AS ticket_json
  FROM support.tickets
) x
WHERE ticket_json ->> 'priority' = 'Critical'
LIMIT 20;

/* Q89. */
SELECT jsonb_agg(jsonb_build_object('customer_id', customer_id, 'total_spend', total_spend) ORDER BY total_spend DESC) AS top10_customers
FROM (
  SELECT cust_id AS customer_id, sum(net_total) AS total_spend
  FROM sales.orders
  GROUP BY cust_id
  ORDER BY total_spend DESC
  LIMIT 10
) x;

/* Q90. */
SELECT jsonb_build_object('prod_id', p.product_id, 'name', p.product_name, 'price', p.price,
       'in_promo', EXISTS (SELECT 1 FROM products.promotions pr WHERE pr.active = true)) AS catalog_json
FROM products.products p
ORDER BY p.product_id
LIMIT 10;

/* Q91. */
SELECT doc
FROM (
  SELECT jsonb_build_object('order_id', o.order_id, 'items', jsonb_agg(jsonb_build_object('prod_id', oi.prod_id))) AS doc
  FROM sales.orders o
  JOIN sales.order_items oi ON oi.order_id = o.order_id
  GROUP BY o.order_id
) x
WHERE doc @> jsonb_build_object('items', jsonb_build_array(jsonb_build_object('prod_id', (SELECT min(product_id) FROM products.products))))
LIMIT 20;

/* Q92. */
SELECT (store_doc ->> 'store_id')::int AS store_id, jsonb_array_length(store_doc -> 'employees') AS employee_count
FROM (
  SELECT jsonb_build_object('store_id', s.store_id, 'employees', jsonb_agg(jsonb_build_object('emp_id', e.employee_id))) AS store_doc
  FROM stores.stores s
  JOIN stores.employees e ON e.store_id = s.store_id
  GROUP BY s.store_id
) x
ORDER BY 1
LIMIT 20;

/* Q93. */
SELECT order_id, sum((item ->> 'net_amount')::numeric) AS reconstructed_total
FROM (
  SELECT order_id, jsonb_agg(jsonb_build_object('net_amount', net_amount)) AS items
  FROM sales.order_items
  GROUP BY order_id
) x
CROSS JOIN LATERAL jsonb_array_elements(items) AS item
GROUP BY order_id
ORDER BY order_id
LIMIT 20;

/* Q94. */
SELECT jsonb_object_agg(day::text, revenue) AS time_series_payload
FROM (
  SELECT d.day::date::text AS day, coalesce(sum(o.net_total), 0) AS revenue
  FROM generate_series((SELECT max(order_date) FROM sales.orders) - interval '29 days',
                        (SELECT max(order_date) FROM sales.orders), interval '1 day') AS d(day)
  LEFT JOIN sales.orders o ON o.order_date = d.day::date
  GROUP BY d.day
) x;

/* Q95. */
SELECT jsonb_build_object('customer_id', c.customer_id, 'tier', c.tier,
       'latest_order', (SELECT jsonb_build_object('order_id', o2.order_id, 'order_date', o2.order_date, 'net_total', o2.net_total)
                         FROM sales.orders o2 WHERE o2.cust_id = c.customer_id ORDER BY o2.order_date DESC LIMIT 1)
) AS profile_doc
FROM customers.customers c
ORDER BY c.customer_id
LIMIT 20;

/* Q96. */
SELECT prod_doc
FROM (
  SELECT jsonb_build_object('prod_id', product_id, 'margin', round(((price - cost_price) / NULLIF(price, 0))::numeric, 3)) AS prod_doc
  FROM products.products
) x
WHERE (prod_doc ->> 'margin')::numeric < 0.2
LIMIT 20;

/* Q97. */
SELECT region_revenue, (SELECT key FROM jsonb_each_text(region_revenue) ORDER BY value::numeric DESC LIMIT 1) AS max_revenue_region
FROM (
  SELECT jsonb_object_agg(r.region_name, region_totals.revenue) AS region_revenue
  FROM (
    SELECT s.region_id, sum(o.net_total) AS revenue
    FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id
    GROUP BY s.region_id
  ) region_totals
  JOIN core.dim_region r ON r.region_id = region_totals.region_id
) x;

/* Q98. */
SELECT jsonb_build_object('table', table_name, 'column', column_name, 'old', old_value, 'new', new_value) AS change_doc
FROM audit.record_changes
ORDER BY change_id
LIMIT 20;

/* Q99. */
SELECT pc.call_id, (pc.input_params ->> 'id')::int AS extracted_id,
       jsonb_build_object('call_id', pc.call_id, 'proc_name', pc.proc_name, 'product_name', p.product_name) AS enriched_json
FROM audit.procedure_calls pc
JOIN products.products p ON p.product_id = (pc.input_params ->> 'id')::int
ORDER BY pc.call_id
LIMIT 20;

/* Q100. */
SELECT jsonb_agg(jsonb_build_object('region', region_name, 'median_aov', median_aov, 'p95_aov', p95_aov, 'orders', orders)) AS exec_export
FROM (
  SELECT r.region_name,
         percentile_cont(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov,
         percentile_cont(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_aov,
         count(*) AS orders
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  JOIN core.dim_region r ON r.region_id = s.region_id
  GROUP BY r.region_name
) x;

/* ============================================================
   END OF ANSWER KEY - EASY LEVEL (100/100)
============================================================ */
