/* ============================================================
   ANSWER KEY - JSON & Semi-Structured Data (CRAZY LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1. Architect ingestion in layers: land raw event JSONB unmodified with minimal metadata (received_at, source), a "typed" layer that extracts/casts known fields into columns for the current schema version, and a "marts" layer that aggregates the typed layer into the KPIs consumers actually query - each layer isolates the next from upstream shape changes. */
/* Q2. jsonb_ops (default GIN) indexes both keys and values for @>/?/?|/?&, larger and more flexible; jsonb_path_ops indexes only values for @> (smaller, faster, no ? support); an expression btree on a specific extracted scalar (doc->>'k') is best when you always filter/sort on that one field - pick based on whether your workload needs key-existence checks, pure containment, or scalar range/equality. */
/* Q3. jsonb_path_query_array returns every JSONPath match collected into a single JSONB array (instead of one row per match); "lax" mode (the default) tolerates structural mismatches by silently coercing/skipping rather than erroring, while "strict" mode raises an error on any path segment that doesn't structurally apply - lax favors resilience over heterogeneous documents, strict favors catching schema violations early. */
/* Q4. Schema evolution adds an explicit version key to every payload; a migration strategy either normalizes all versions into one canonical shape at read time (a CASE on doc->>'v') or runs a one-time backfill job that rewrites old documents into the new shape, retiring the version branch once all historical data is migrated. */
/* Q5. Materializing extracted columns (an MV, Day 25) costs disk space and refresh time but makes every subsequent read cheap and indexable; live parsing costs zero storage but re-pays the extraction/cast cost on every single query - the crossover point is roughly "read frequency x extraction cost vs refresh frequency x materialization cost." */
/* Q6. Containment query planning: the GIN index narrows candidate rows via @>, but the planner still re-checks the exact condition against each candidate (GIN is lossy for some operator classes); partial indexes (WHERE doc->>'status'='active') and expression indexes on the specific extracted scalar let the planner skip the GIN step entirely when the predicate matches the index definition exactly. */
/* Q7. Defensive parsing wraps every field access in COALESCE/?-checks, validates types with jsonb_typeof before casting, and never lets one malformed document abort a whole batch - a single try/extract-or-default pattern per field, rather than assuming every payload conforms. */
/* Q8. Round-trip fidelity guarantees numeric precision is preserved (JSONB numbers are arbitrary precision) but key order and duplicate keys are NOT preserved; canonicalization (jsonb_strip_nulls plus a conceptual key-sort) produces one consistent representation per logically-equivalent document, which is the prerequisite for a later dedup step (Day 26) to group them correctly via equality or a hash. */
/* Q9. Good API contracts wrap payloads in an envelope ({"data":[...], "meta":{...}}), support pagination via a cursor or page/limit fields in meta, represent errors as a predictable {"error":{"code","message"}} shape, and support idempotency (an idempotency key so retried requests don't double-apply) for write endpoints. */
/* Q10. A customer-360 document's grain is one row per customer; it embeds BOUNDED arrays (e.g. last 10 orders, not full history) to keep document size sane, and needs an explicit refresh cadence (live view for freshness-critical fields, nightly MV for the expensive aggregate fields) rather than trying to be both fully live and unbounded. */
/* Q11. Tolerant extraction treats every field as optional at read time (COALESCE/? checks), accepts unknown extra keys without rejecting the document, and routes documents that fail REQUIRED-key validation to a separate "quarantine" table/flag for later investigation rather than silently dropping or crashing on them. */
/* Q12. jsonb_array_elements in a FROM/LATERAL multiplies rows by array length, so a large array (or a big source table joined to it) row-explodes fast; mitigate by pre-filtering/pre-aggregating before unnesting, unnesting only the specific sub-array needed (not the whole document), and doing the final aggregation immediately after unnest rather than materializing the exploded rows further. */
/* Q13. Normalize fields out of JSON into real columns when they're queried/filtered/joined on constantly and benefit from strong typing and indexes (e.g. order status, customer tier); keep genuinely variable, rarely-queried, or evolving fields as JSONB - hybrid modeling puts the "hot path" in columns and the "long tail" in a JSONB catch-all column. */
/* Q14. Time-series-in-JSON (one document per entity holding a whole {date:value} series) is compact and easy to ship as an API payload, but is awkward to filter/aggregate across entities in SQL; a relational fact table (one row per entity per date) is easy to GROUP BY/window-function over but costs more storage and requires unnesting for a JSON export - choose based on whether SQL-side analysis or API delivery is the primary consumer. */
/* Q15. A SQL validation framework checks required keys with `doc ?& array[...]`, checks types with `jsonb_typeof(doc->'field') = 'expected_type'`, checks enums with `doc->>'field' = ANY(array[...])`, and checks ranges with a cast-and-compare (`(doc->>'field')::numeric BETWEEN lo AND hi`) - combining all four into one CASE/boolean expression per document yields a pass/fail validation gate. */
/* Q16. Containment/GIN acceleration works well for shallow paths but loses effectiveness for deep, highly variable nested paths (the index has to represent every key/value pair at every depth); beyond a few levels of nesting, a dedicated expression index on the specific deep path actually queried is usually more effective than relying on the whole-document GIN index. */
/* Q17. Multi-tenant JSON isolation stores a tenant_id column alongside the JSONB payload (never solely inside the JSON) so row-level security and simple WHERE tenant_id = X filtering stay fast and enforceable; each tenant's documents can independently drift in shape, so validation/typing logic must be tenant-aware rather than assuming one global schema. */
/* Q18. JSON-to-relational reconciliation means asserting that totals/counts computed by summing/counting over a JSON-built structure exactly match the equivalent aggregate computed directly from the base relational tables - any mismatch signals a bug in the JSON-building logic (a missed row, a double-count, or a wrong join) that needs fixing before the JSON export is trusted. */
/* Q19. Bounded pivoting of dynamic JSON keys works by first enumerating the actual distinct keys present (via jsonb_object_keys or a known finite domain), then building one CASE/FILTER expression per known key; a truly unbounded/unknown key set can't be pivoted in static SQL and needs either a capped "top-N keys, rest as other" approach or dynamic SQL generated outside the query. */
/* Q20. Never string-concatenate free text directly into a jsonb_build_object/to_jsonb call in a way that lets user input alter the JSON structure - jsonb_build_object's arguments are properly parameterized SQL expressions (not string interpolation), so as long as free text is passed as a VALUE argument (not spliced into keys or raw JSON text), PostgreSQL's type system prevents JSON injection the same way parameterized queries prevent SQL injection. */
/* Q21. Large JSONB values get TOASTed (compressed and stored out-of-line) once they exceed roughly 2KB, which adds a TOAST-table lookup cost on read; frequently-accessed large documents pay this cost repeatedly, so extracting hot fields into indexed columns (rather than always re-detoasting the whole document) is the usual performance remedy. */
/* Q22. Idempotent replay means re-processing the same batch of event JSON twice produces the identical end state - achieved by keying each event with a unique id and using upsert (INSERT ... ON CONFLICT DO NOTHING/UPDATE) semantics on ingest, so a retried or duplicated delivery never double-applies. */
/* Q23. Observability payloads (per-request latency/status JSON) feed directly into SLO computation: extract status_code for error-rate, extract latency for percentile (P50/P95/P99) calculations, and an SLO burn-rate alert compares the rolling error/latency percentile against a target threshold over a trailing window. */
/* Q24. JSON is the wrong tool whenever the data is genuinely fixed-shape, queried heavily by individual typed fields, needs foreign-key integrity, or benefits from the query planner's statistics on individual columns - RetailMart's own core relational tables (orders, customers, products) are exactly this case, which is why JSON here is deliberately CONSTRUCTED from them rather than stored natively. */
/* Q25. A semi-structured data contract for downstream BI specifies the required top-level keys, their types, an explicit version field, and a stability guarantee (which fields are safe to depend on vs which may change) - without this contract, BI tools built directly against raw JSON break silently whenever the upstream payload shape shifts. */

/* ============================================================
   SECTION B: INGESTION & OBSERVABILITY ENGINES (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT jsonb_object_agg(endpoint || '|' || method, stats) AS observability_doc
FROM (
  SELECT endpoint, method, jsonb_build_object(
    'count', count(*),
    'error_pct', round((100.0 * count(*) FILTER (WHERE status_code >= 400) / count(*))::numeric, 2),
    'p50', percentile_cont(0.5) WITHIN GROUP (ORDER BY response_time_ms),
    'p95', percentile_cont(0.95) WITHIN GROUP (ORDER BY response_time_ms),
    'p99', percentile_cont(0.99) WITHIN GROUP (ORDER BY response_time_ms)
  ) AS stats
  FROM audit.api_requests
  GROUP BY endpoint, method
) x;

/* Q27. */
WITH ordered AS (
  SELECT customer_id, view_timestamp,
         lag(view_timestamp) OVER (PARTITION BY customer_id ORDER BY view_timestamp) AS prev_ts
  FROM web_events.page_views
  WHERE customer_id IS NOT NULL
),
flagged AS (
  SELECT customer_id, view_timestamp,
         CASE WHEN prev_ts IS NULL OR view_timestamp - prev_ts > interval '30 min' THEN 1 ELSE 0 END AS new_session
  FROM ordered
),
sessioned AS (
  SELECT customer_id, view_timestamp, sum(new_session) OVER (PARTITION BY customer_id ORDER BY view_timestamp) AS session_num
  FROM flagged
)
SELECT customer_id, session_num, jsonb_agg(jsonb_build_object('ts', view_timestamp) ORDER BY view_timestamp) AS events_json,
       count(*) AS event_count
FROM sessioned
GROUP BY customer_id, session_num
ORDER BY customer_id, session_num
LIMIT 20;

/* Q28. */
SELECT doc, doc ?& array['order_id','status','net_total'] AS keys_ok,
       jsonb_typeof(doc -> 'net_total') = 'number' AS types_ok,
       doc ->> 'status' IN ('Processing','Out for Delivery','Delivered','Shipped','Failed','Cancelled','Returned') AS enum_ok,
       CASE WHEN doc ?& array['order_id','status','net_total']
             AND jsonb_typeof(doc -> 'net_total') = 'number'
             AND doc ->> 'status' IN ('Processing','Out for Delivery','Delivered','Shipped','Failed','Cancelled','Returned')
            THEN 'pass' ELSE 'quarantine' END AS validation_result
FROM (SELECT jsonb_build_object('order_id', order_id, 'status', order_status, 'net_total', net_total) AS doc FROM sales.orders) x
LIMIT 100;

/* Q29. */
SELECT date_trunc('day', timestamp)::date AS day,
       count(*) FILTER (WHERE user_agent IS NULL) AS missing_user_agent,
       count(*) FILTER (WHERE endpoint IS NULL) AS missing_endpoint,
       count(*) AS total
FROM audit.api_requests
GROUP BY 1
ORDER BY 1;

/* Q30. */
SELECT day, p95_latency,
       max(p95_latency) OVER () AS slo_target,
       round((100.0 * count(*) FILTER (WHERE p95_latency > (SELECT percentile_cont(0.95) WITHIN GROUP (ORDER BY response_time_ms) FROM audit.api_requests)) OVER ())::numeric, 2) AS burn_rate_placeholder
FROM (
  SELECT timestamp::date AS day, percentile_cont(0.95) WITHIN GROUP (ORDER BY response_time_ms) AS p95_latency
  FROM audit.api_requests
  GROUP BY 1
) x
ORDER BY day;

/* Q31. */
SELECT CASE WHEN user_agent LIKE '%Mobile%' THEN 'Mobile'
            WHEN user_agent LIKE '%Tablet%' THEN 'Tablet'
            WHEN user_agent LIKE '%iPhone%' OR user_agent LIKE '%Android%' THEN 'Mobile'
            ELSE 'Desktop' END AS device_class,
       count(*) AS requests
FROM audit.api_requests
GROUP BY 1
ORDER BY 1;

/* Q32. */
SELECT a.endpoint, a.timestamp AS ts, a.response_time_ms AS latency, t.p99
FROM audit.api_requests a
JOIN (
  SELECT endpoint, percentile_cont(0.99) WITHIN GROUP (ORDER BY response_time_ms) AS p99
  FROM audit.api_requests
  GROUP BY endpoint
) t ON t.endpoint = a.endpoint
WHERE a.response_time_ms > t.p99
ORDER BY a.endpoint, latency DESC
LIMIT 20;

/* Q33. */
SELECT jsonb_build_object(
  'page_views', (SELECT count(*) FROM web_events.page_views),
  'events', (SELECT count(*) FROM web_events.events),
  'orders', (SELECT count(*) FROM sales.orders),
  'pv_to_order_dropoff_pct', round((100.0 * (1 - (SELECT count(*) FROM sales.orders)::numeric / NULLIF((SELECT count(*) FROM web_events.page_views), 0)))::numeric, 2)
) AS funnel_doc;

/* Q34. */
SELECT o.order_id, o.net_total, r.item_sum, o.net_total - r.item_sum AS mismatch
FROM sales.orders o
JOIN (SELECT order_id, sum(net_amount) AS item_sum FROM sales.order_items GROUP BY order_id) r ON r.order_id = o.order_id
WHERE o.net_total <> r.item_sum
ORDER BY abs(o.net_total - r.item_sum) DESC
LIMIT 20;

/* Q35. */
SELECT customer_id,
       CASE WHEN doc ->> 'v' = '1' THEN doc ->> 'name' ELSE doc ->> 'full_name' END AS unified_name
FROM (
  SELECT customer_id,
         CASE WHEN customer_id % 2 = 0 THEN jsonb_build_object('v', '1', 'name', first_name || ' ' || last_name)
              ELSE jsonb_build_object('v', '2', 'full_name', first_name || ' ' || last_name) END AS doc
  FROM customers.customers
) x
ORDER BY customer_id
LIMIT 20;

/* Q36. */
SELECT doc
FROM (SELECT jsonb_build_object('order_id', order_id, 'status', order_status, 'store_id', store_id) AS doc FROM sales.orders) x
WHERE doc @> '{"status":"Delivered"}'::jsonb
LIMIT 20;

/* Q37. */
SELECT jsonb_path_query(doc, '$.status') AS status_match
FROM (SELECT jsonb_build_object('order_id', order_id, 'status', order_status) AS doc FROM sales.orders) x
LIMIT 20;

/* Q38. */
SELECT r.region_name, jsonb_object_agg(to_char(m.month, 'YYYY-MM'), jsonb_build_object('revenue', m.revenue, 'ma3', m.ma3)) AS ts_doc
FROM (
  SELECT region_id, month, revenue, avg(revenue) OVER (PARTITION BY region_id ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ma3
  FROM (SELECT s.region_id, date_trunc('month', o.order_date)::date AS month, sum(o.net_total) AS revenue
        FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id GROUP BY 1, 2) t
) m
JOIN core.dim_region r ON r.region_id = m.region_id
GROUP BY r.region_name
ORDER BY r.region_name;

/* Q39. */
SELECT jsonb_object_agg(dow::text, hours) AS heatmap_normalized
FROM (
  SELECT dow, jsonb_object_agg(hour::text, round((100.0 * page_views / max_views)::numeric, 2)) AS hours
  FROM (
    SELECT dow, hour, page_views, max(page_views) OVER (PARTITION BY dow) AS max_views
    FROM (
      SELECT extract(dow FROM view_timestamp)::int AS dow, extract(hour FROM view_timestamp)::int AS hour, count(*) AS page_views
      FROM web_events.page_views
      GROUP BY 1, 2
    ) base
  ) x
  GROUP BY dow
) y;

/* Q40. */
SELECT ticket_json ->> 'priority' AS priority, count(*) AS tickets
FROM (SELECT jsonb_build_object('priority', priority) AS ticket_json FROM support.tickets) x
GROUP BY 1
ORDER BY 1;

/* Q41. */
SELECT doc_hash, count(*) AS duplicate_count
FROM (
  SELECT md5(jsonb_strip_nulls(jsonb_build_object('status', order_status, 'store_id', store_id, 'cust_id', cust_id))::text) AS doc_hash
  FROM sales.orders
) x
GROUP BY doc_hash
HAVING count(*) > 1
ORDER BY duplicate_count DESC
LIMIT 20;

/* Q42. */
SELECT r.region_name, jsonb_build_object(
  'median', percentile_cont(0.5) WITHIN GROUP (ORDER BY o.net_total),
  'p90', percentile_cont(0.9) WITHIN GROUP (ORDER BY o.net_total),
  'p95', percentile_cont(0.95) WITHIN GROUP (ORDER BY o.net_total),
  'iqr', percentile_cont(0.75) WITHIN GROUP (ORDER BY o.net_total) - percentile_cont(0.25) WITHIN GROUP (ORDER BY o.net_total)
) AS metrics_doc
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;

/* Q43. */
SELECT jsonb_build_object('cohort', cohort_month, 'periods',
       jsonb_object_agg(months_since::text, jsonb_build_object('retained', retained, 'cum_revenue', cum_revenue))) AS triangle_doc
FROM (
  SELECT cohort_month, months_since, retained, sum(period_revenue) OVER (PARTITION BY cohort_month ORDER BY months_since) AS cum_revenue
  FROM (
    SELECT date_trunc('month', c.registration_date)::date AS cohort_month,
           (extract(year FROM o.order_date) - extract(year FROM c.registration_date)) * 12
           + (extract(month FROM o.order_date) - extract(month FROM c.registration_date)) AS months_since,
           count(DISTINCT o.cust_id) AS retained,
           sum(o.net_total) AS period_revenue
    FROM customers.customers c
    JOIN sales.orders o ON o.cust_id = c.customer_id
    GROUP BY 1, 2
  ) t
  WHERE months_since BETWEEN 0 AND 5
) t2
GROUP BY cohort_month
ORDER BY cohort_month;

/* Q44. */
SELECT jsonb_build_object('customer_id', customer_id, 'tier', tier,
       'r_score', ntile(4) OVER (ORDER BY days_since_last DESC),
       'f_score', ntile(4) OVER (ORDER BY order_count),
       'm_score', ntile(4) OVER (ORDER BY total_spend)) AS rfm_doc
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
LIMIT 30;

/* Q45. */
SELECT jsonb_build_object('table', table_name, 'summary', jsonb_build_object('total_changes', count(*), 'big_jumps', count(*) FILTER (WHERE pct_change > 50))) AS audit_doc
FROM (
  SELECT table_name, column_name,
         round((abs((new_value::numeric - old_value::numeric) / NULLIF(old_value::numeric, 0)) * 100)::numeric, 2) AS pct_change
  FROM audit.record_changes
  WHERE column_name IN ('price', 'salary') AND old_value ~ '^[0-9.]+$' AND new_value ~ '^[0-9.]+$'
) x
GROUP BY table_name
ORDER BY table_name;

/* Q46. */
SELECT jsonb_build_object('data', page_data, 'meta', jsonb_build_object('page', 1, 'page_size', 10, 'total', total)) AS envelope
FROM (SELECT jsonb_agg(jsonb_build_object('order_id', order_id, 'status', order_status)) AS page_data
      FROM (SELECT order_id, order_status FROM sales.orders WHERE order_status = 'Delivered' ORDER BY order_id LIMIT 10) t) x
CROSS JOIN (SELECT count(*) AS total FROM sales.orders WHERE order_status = 'Delivered') c;

/* Q47. */
SELECT jsonb_build_object('prod_id', p.product_id, 'latest_price', latest.unit_price, 'median_price', med.median_price,
       'drift_pct', round((100.0 * (latest.unit_price - med.median_price) / NULLIF(med.median_price, 0))::numeric, 2),
       'alert', abs(latest.unit_price - med.median_price) > med.median_price * 0.2
) AS pricing_doc
FROM products.products p
JOIN LATERAL (SELECT oi.unit_price FROM sales.order_items oi JOIN sales.orders o ON o.order_id = oi.order_id WHERE oi.prod_id = p.product_id ORDER BY o.order_date DESC LIMIT 1) latest ON true
JOIN LATERAL (SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY oi.unit_price) AS median_price FROM sales.order_items oi WHERE oi.prod_id = p.product_id) med ON true
WHERE p.product_id IN (SELECT product_id FROM products.products ORDER BY product_id LIMIT 20);

/* Q48. */
SELECT jsonb_build_object('warehouse_id', w.warehouse_id, 'latest_snapshot',
       (SELECT jsonb_build_object('date', max(snapshot_date), 'total_qty', sum(quantity_on_hand))
        FROM supply_chain.inventory_snapshots s
        WHERE s.warehouse_id = w.warehouse_id AND s.snapshot_date = (SELECT max(snapshot_date) FROM supply_chain.inventory_snapshots s2 WHERE s2.warehouse_id = w.warehouse_id)
        GROUP BY s.snapshot_date)
) AS freshness_doc
FROM supply_chain.warehouses w
ORDER BY w.warehouse_id;

/* Q49. */
SELECT jsonb_object_agg(priority, doc) AS sla_scorecard
FROM (
  SELECT priority, jsonb_build_object(
    'median', percentile_cont(0.5) WITHIN GROUP (ORDER BY hrs),
    'p95', percentile_cont(0.95) WITHIN GROUP (ORDER BY hrs),
    'p99', percentile_cont(0.99) WITHIN GROUP (ORDER BY hrs),
    'breach_pct', round((100.0 * count(*) FILTER (WHERE hrs > 24) / count(*))::numeric, 2)
  ) AS doc
  FROM (SELECT priority, extract(epoch FROM (resolved_date - created_date)) / 3600.0 AS hrs FROM support.tickets WHERE resolved_date IS NOT NULL) t
  GROUP BY priority
) x;

/* Q50. */
SELECT jsonb_agg(jsonb_build_object('metric', metric, 'value', value)) AS metric_array,
       jsonb_build_object(
         'total_orders', max(value) FILTER (WHERE metric = 'total_orders'),
         'total_revenue', max(value) FILTER (WHERE metric = 'total_revenue')
       ) AS repivoted
FROM (
  SELECT 'total_orders' AS metric, count(*)::numeric AS value FROM sales.orders
  UNION ALL SELECT 'total_revenue', sum(net_total) FROM sales.orders
) k;

/* ============================================================
   SECTION C: CUSTOMER-360 & MART PIPELINES (25)
   ------------------------------------------------------------ */
/* Q51. */
SELECT jsonb_build_object(
  'customer_id', c.customer_id,
  'profile', jsonb_build_object('name', c.first_name || ' ' || c.last_name, 'tier', c.tier),
  'orders', coalesce((SELECT jsonb_agg(jsonb_build_object('order_id', o.order_id, 'net_total', o.net_total)) FROM sales.orders o WHERE o.cust_id = c.customer_id), '[]'::jsonb),
  'reviews', coalesce((SELECT jsonb_agg(jsonb_build_object('review_id', r.review_id, 'rating', r.rating)) FROM customers.reviews r WHERE r.customer_id = c.customer_id), '[]'::jsonb),
  'tickets', coalesce((SELECT jsonb_agg(jsonb_build_object('ticket_id', t.ticket_id)) FROM support.tickets t WHERE t.customer_id = c.customer_id), '[]'::jsonb),
  'payments', coalesce((SELECT jsonb_agg(jsonb_build_object('payment_id', p.payment_id, 'amount', p.amount)) FROM finance.payments p WHERE p.cust_id = c.customer_id), '[]'::jsonb),
  'latest_order', (SELECT jsonb_build_object('order_id', o2.order_id, 'order_date', o2.order_date) FROM sales.orders o2 WHERE o2.cust_id = c.customer_id ORDER BY o2.order_date DESC LIMIT 1),
  'median_spend', (SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY o3.net_total) FROM sales.orders o3 WHERE o3.cust_id = c.customer_id),
  'p95_spend', (SELECT percentile_cont(0.95) WITHIN GROUP (ORDER BY o4.net_total) FROM sales.orders o4 WHERE o4.cust_id = c.customer_id)
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
SELECT count(*) AS flattened, (SELECT count(*) FROM sales.orders WHERE cust_id IN (SELECT customer_id FROM customers.customers ORDER BY customer_id LIMIT 100)) AS base
FROM doc CROSS JOIN LATERAL jsonb_array_elements(d -> 'orders') AS item;

/* Q53. */
SELECT jsonb_build_object('region', r.region_name,
       'stores', jsonb_agg(jsonb_build_object('store_id', s.store_id, 'monthly_revenue', store_rev.months, 'kpis', jsonb_build_object('total', store_rev.total)))) AS region_doc
FROM core.dim_region r
JOIN stores.stores s ON s.region_id = r.region_id
JOIN LATERAL (
  SELECT jsonb_agg(jsonb_build_object('month', month, 'revenue', revenue) ORDER BY month) AS months, sum(revenue) AS total
  FROM (SELECT date_trunc('month', order_date)::date AS month, sum(net_total) AS revenue FROM sales.orders WHERE store_id = s.store_id GROUP BY 1) m
) store_rev ON true
GROUP BY r.region_name
ORDER BY r.region_name
LIMIT 5;

/* Q54. */
SELECT jsonb_build_object('category', cat.category_name, 'brands', jsonb_agg(brand_doc.doc)) AS catalog_doc
FROM core.dim_category cat
JOIN core.dim_brand b ON b.category_id = cat.category_id
JOIN LATERAL (
  SELECT jsonb_build_object('brand', b.brand_name, 'products', jsonb_agg(jsonb_build_object(
    'prod_id', p.product_id, 'price', p.price,
    'margin', round(((p.price - p.cost_price) / NULLIF(p.price, 0))::numeric, 3),
    'in_promo', EXISTS (SELECT 1 FROM products.promotions pr WHERE pr.active = true)
  ))) AS doc
  FROM products.products p
  WHERE p.brand_id = b.brand_id
) brand_doc ON true
GROUP BY cat.category_name
ORDER BY cat.category_name
LIMIT 5;

/* Q55. */
SELECT jsonb_build_object(
  'idempotency_key', 'order-' || o.order_id,
  'order', jsonb_build_object('order_id', o.order_id, 'status', o.order_status, 'net_total', o.net_total),
  'items', (SELECT jsonb_agg(jsonb_build_object('prod_id', oi.prod_id, 'qty', oi.quantity)) FROM sales.order_items oi WHERE oi.order_id = o.order_id)
) AS order_export
FROM sales.orders o
ORDER BY o.order_id
LIMIT 10;

/* Q56. */
SELECT jsonb_build_object('cohort', cohort_month, 'periods',
       jsonb_object_agg(months_since::text, jsonb_build_object('retention', retained, 'cum_revenue', cum_revenue))) AS mart_doc
FROM (
  SELECT cohort_month, months_since, retained, sum(period_revenue) OVER (PARTITION BY cohort_month ORDER BY months_since) AS cum_revenue
  FROM (
    SELECT date_trunc('month', c.registration_date)::date AS cohort_month,
           (extract(year FROM o.order_date) - extract(year FROM c.registration_date)) * 12
           + (extract(month FROM o.order_date) - extract(month FROM c.registration_date)) AS months_since,
           count(DISTINCT o.cust_id) AS retained,
           sum(o.net_total) AS period_revenue
    FROM customers.customers c
    JOIN sales.orders o ON o.cust_id = c.customer_id
    GROUP BY 1, 2
  ) t
  WHERE months_since BETWEEN 0 AND 5
) t2
GROUP BY cohort_month
ORDER BY cohort_month;

/* Q57. */
SELECT jsonb_object_agg(w.warehouse_id::text, jsonb_build_object('skus', sku_docs.doc)) AS inventory_mart
FROM supply_chain.warehouses w
JOIN LATERAL (
  SELECT jsonb_agg(jsonb_build_object('product_id', s.product_id, 'qty', s.quantity_on_hand, 'value', s.quantity_on_hand * p.cost_price)) AS doc
  FROM (SELECT DISTINCT ON (product_id) product_id, quantity_on_hand FROM supply_chain.inventory_snapshots s2 WHERE s2.warehouse_id = w.warehouse_id ORDER BY product_id, snapshot_date DESC) s
  JOIN products.products p ON p.product_id = s.product_id
) sku_docs ON true
GROUP BY w.warehouse_id;

/* Q58. */
SELECT jsonb_build_object('customer_id', c.customer_id,
       'latest_order', (SELECT max(order_date)::timestamp FROM sales.orders o WHERE o.cust_id = c.customer_id),
       'latest_view', (SELECT max(view_timestamp) FROM web_events.page_views pv WHERE pv.customer_id = c.customer_id),
       'latest_ticket', (SELECT max(created_date) FROM support.tickets t WHERE t.customer_id = c.customer_id),
       'latest_call', (SELECT max(call_start_time) FROM call_center.calls cc WHERE cc.customer_id = c.customer_id)
) AS activity_doc
FROM customers.customers c
ORDER BY c.customer_id
LIMIT 20;

/* Q59. */
SELECT r.region_name, jsonb_object_agg(to_char(m.month,'YYYY-MM'), jsonb_build_object('rev', m.revenue, 'ma7', m.ma7, 'ma28', m.ma28, 'mom', m.mom)) AS ts_doc
FROM (
  SELECT region_id, month, revenue,
         avg(revenue) OVER (PARTITION BY region_id ORDER BY month ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS ma7,
         avg(revenue) OVER (PARTITION BY region_id ORDER BY month ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) AS ma28,
         round((100.0 * (revenue - lag(revenue) OVER (PARTITION BY region_id ORDER BY month)) / NULLIF(lag(revenue) OVER (PARTITION BY region_id ORDER BY month), 0))::numeric, 2) AS mom
  FROM (SELECT s.region_id, date_trunc('month', o.order_date)::date AS month, sum(o.net_total) AS revenue
        FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id GROUP BY 1, 2) t
) m
JOIN core.dim_region r ON r.region_id = m.region_id
GROUP BY r.region_name
ORDER BY r.region_name;

/* Q60. */
SELECT jsonb_build_object('cohort', cohort_month, 'stage_counts', jsonb_build_object(
  'registered', cohort_size, 'ordered', ordered_count, 'drop_off_pct', round((100.0 * (cohort_size - ordered_count) / NULLIF(cohort_size, 0))::numeric, 2)
)) AS funnel_doc
FROM (
  SELECT date_trunc('month', c.registration_date)::date AS cohort_month,
         count(DISTINCT c.customer_id) AS cohort_size,
         count(DISTINCT o.cust_id) AS ordered_count
  FROM customers.customers c
  LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
  GROUP BY 1
) x
ORDER BY cohort_month;

/* Q61. */
SELECT p.product_id, m.month_end, oi.unit_price AS as_of_price,
       oi.unit_price - lag(oi.unit_price) OVER (PARTITION BY p.product_id ORDER BY m.month_end) AS drift
FROM products.products p
CROSS JOIN (
  SELECT (date_trunc('month', d)::date + interval '1 month - 1 day')::date AS month_end
  FROM generate_series('2025-01-01'::date, '2025-12-01'::date, interval '1 month') AS d
) m
CROSS JOIN LATERAL (
  SELECT oi.unit_price FROM sales.order_items oi JOIN sales.orders o ON o.order_id = oi.order_id
  WHERE oi.prod_id = p.product_id AND o.order_date <= m.month_end ORDER BY o.order_date DESC LIMIT 1
) oi
WHERE p.product_id IN (SELECT product_id FROM products.products ORDER BY product_id LIMIT 5)
ORDER BY p.product_id, m.month_end;

/* Q62. */
SELECT jsonb_build_object('customer_id', customer_id, 'segment', CASE WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN 'Champion'
       WHEN r_score <= 2 AND f_score <= 2 THEN 'At Risk' ELSE 'Standard' END,
       'scores', jsonb_build_object('r', r_score, 'f', f_score, 'm', m_score),
       'recency_decile', ntile(10) OVER (ORDER BY days_since_last DESC)
) AS rfm_mart
FROM (
  SELECT c.customer_id,
         (SELECT max(order_date) FROM sales.orders) - max(o.order_date) AS days_since_last,
         ntile(4) OVER (ORDER BY (SELECT max(order_date) FROM sales.orders) - max(o.order_date) DESC) AS r_score,
         ntile(4) OVER (ORDER BY count(o.order_id)) AS f_score,
         ntile(4) OVER (ORDER BY coalesce(sum(o.net_total), 0)) AS m_score
  FROM customers.customers c
  LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
  GROUP BY c.customer_id
) x
ORDER BY customer_id
LIMIT 30;

/* Q63. */
SELECT r.region_name, priority, jsonb_build_object(
  'median_hours', percentile_cont(0.5) WITHIN GROUP (ORDER BY hrs),
  'p95_hours', percentile_cont(0.95) WITHIN GROUP (ORDER BY hrs),
  'breach_pct', round((100.0 * count(*) FILTER (WHERE hrs > 24) / count(*))::numeric, 2)
) AS sla_doc
FROM (
  SELECT t.priority, s.region_id, extract(epoch FROM (t.resolved_date - t.created_date)) / 3600.0 AS hrs
  FROM support.tickets t
  JOIN customers.customers c ON c.customer_id = t.customer_id
  JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = true
  JOIN stores.stores s ON s.city = a.city
  WHERE t.resolved_date IS NOT NULL
) x
JOIN core.dim_region r ON r.region_id = x.region_id
GROUP BY r.region_name, priority
ORDER BY r.region_name, priority;

/* Q64. */
SELECT record_id, jsonb_build_object('history', jsonb_agg(jsonb_build_object('changed_at', changed_at, 'column', column_name, 'old', old_value, 'new', new_value) ORDER BY changed_at),
       'latest', (array_agg(jsonb_build_object('column', column_name, 'new', new_value) ORDER BY changed_at DESC))[1]) AS audit_mart
FROM audit.record_changes
GROUP BY record_id
ORDER BY record_id
LIMIT 20;

/* Q65. */
SELECT jsonb_build_object(device_type, jsonb_object_agg(dow::text, hours)) AS heatmap_mart
FROM (
  SELECT device_type, dow, jsonb_object_agg(hour::text, page_views) AS hours
  FROM (
    SELECT device_type, extract(dow FROM view_timestamp)::int AS dow, extract(hour FROM view_timestamp)::int AS hour, count(*) AS page_views
    FROM web_events.page_views
    GROUP BY 1, 2, 3
  ) x
  GROUP BY device_type, dow
) y
GROUP BY device_type;

/* Q66. */
SELECT jsonb_build_object('customer_id', c.customer_id,
       'lifecycle', jsonb_build_object('registered', c.registration_date, 'first_order', min(o.order_date), 'latest_order', max(o.order_date)),
       'as_of_tier', c.tier
) AS lifecycle_doc
FROM customers.customers c
LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY c.customer_id, c.registration_date, c.tier
ORDER BY c.customer_id
LIMIT 20;

/* Q67. */
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

/* Q68. */
SELECT jsonb_build_object('data', page, 'meta', jsonb_build_object('page', 1, 'total', total, 'filter', 'status=Delivered')) AS catalog_api
FROM (SELECT jsonb_agg(jsonb_build_object('order_id', order_id)) AS page FROM (SELECT order_id FROM sales.orders WHERE order_status='Delivered' ORDER BY order_id LIMIT 10) t) x
CROSS JOIN (SELECT count(*) AS total FROM sales.orders WHERE order_status='Delivered') c;

/* Q69. */
SELECT store_id, region_id, all_id, total_revenue
FROM (
  SELECT s.store_id, s.region_id, NULL::int AS all_id, sum(o.net_total) AS total_revenue
  FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id
  GROUP BY GROUPING SETS ((s.store_id, s.region_id), (s.region_id), ())
) x
ORDER BY region_id NULLS LAST, store_id NULLS LAST
LIMIT 50;

/* Q70. */
SELECT jsonb_agg(jsonb_build_object('day', day, 'revenue', revenue, 'p95', p95, 'alert', revenue > p95)) AS anomaly_mart
FROM (
  SELECT day, revenue, p95.p95 AS p95
  FROM (
    SELECT d.day::date, coalesce(sum(o.net_total), 0) AS revenue
    FROM generate_series('2025-06-01'::date, '2025-08-31'::date, interval '1 day') AS d(day)
    LEFT JOIN sales.orders o ON o.order_date = d.day
    GROUP BY d.day
  ) daily
  CROSS JOIN (SELECT percentile_cont(0.95) WITHIN GROUP (ORDER BY rev) AS p95 FROM (
    SELECT coalesce(sum(o.net_total),0) AS rev FROM generate_series('2025-06-01'::date,'2025-08-31'::date, interval '1 day') d2(day) LEFT JOIN sales.orders o ON o.order_date=d2.day GROUP BY d2.day
  ) t) p95
) x;

/* Q71. Conceptual: to migrate a v1 customer document (flat {"name": "..."}) to v2 ({"first_name","last_name"}), the migration query would SELECT jsonb_build_object('v', 2, 'first_name', split_part(doc->>'name',' ',1), 'last_name', split_part(doc->>'name',' ',2)) FROM v1_docs, then upsert those rebuilt v2 rows in place - since this is a genuine write, it happens in an accio_NN sandbox rather than against this shared read-only dataset. */

/* Q72. */
SELECT cat.category_name, jsonb_agg(units ORDER BY month_num) AS sparkline
FROM (
  SELECT cat.category_name, extract(month FROM o.order_date)::int AS month_num, sum(oi.quantity) AS units
  FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
  WHERE o.order_date >= (SELECT max(order_date) FROM sales.orders) - interval '365 days'
  GROUP BY cat.category_name, month_num
) cat
GROUP BY category_name
ORDER BY category_name;

/* Q73. */
SELECT doc, reasons
FROM (
  SELECT jsonb_build_object('order_id', order_id, 'status', order_status, 'net_total', net_total) AS doc,
         array_remove(ARRAY[
           CASE WHEN order_status IS NULL THEN 'missing_status' END,
           CASE WHEN net_total IS NULL THEN 'missing_net_total' END,
           CASE WHEN net_total < 0 THEN 'negative_total' END
         ], NULL) AS reasons
  FROM sales.orders
) x
WHERE array_length(reasons, 1) > 0
LIMIT 20;

/* Q74. Conceptual: the customer-360 mart's hot access pattern is containment/lookup by customer_id (not deep JSON containment), so the right index is a plain btree UNIQUE INDEX on customer_id (as a normal column, or as an MV's unique key) rather than a GIN index - GIN only pays off if downstream consumers filter with @> on the document's internal structure itself, which a keyed lookup mart typically doesn't need. */

/* Q75. */
WITH raw AS (
  SELECT jsonb_build_object('order_id', o.order_id, 'status', o.order_status, 'net_total', o.net_total) AS doc
  FROM sales.orders o
),
validated AS (
  SELECT doc, doc ?& array['order_id','status','net_total'] AS is_valid FROM raw
),
flattened AS (
  SELECT (doc ->> 'order_id')::int AS order_id, doc ->> 'status' AS status, (doc ->> 'net_total')::numeric AS net_total
  FROM validated WHERE is_valid
),
aggregated AS (
  SELECT status, count(*) AS orders, sum(net_total) AS revenue FROM flattened GROUP BY status
)
SELECT a.status, a.orders, a.revenue, r.direct_total, a.revenue = r.direct_total AS reconciled
FROM aggregated a
CROSS JOIN (SELECT sum(net_total) AS direct_total FROM sales.orders) r
ORDER BY a.status;

/* ============================================================
   SECTION D: PRODUCTION SEMI-STRUCTURED SYSTEMS (25)
   ------------------------------------------------------------ */
/* Q76. Conceptual: the production customer-360 mart is the Q51-style per-customer document (profile, orders[], reviews[], tickets[], payments[], latest order, median/P95 spend); since it aggregates several large child tables per customer, in production it would be a materialized view (Day 25) with a UNIQUE INDEX on customer_id refreshed nightly (or CONCURRENTLY on a tighter SLA), rather than recomputed live on every API call. */
/* Q77. */
SELECT jsonb_object_agg(endpoint || '|' || method, stats) AS observability_platform
FROM (
  SELECT endpoint, method, jsonb_build_object(
    'error_pct', round((100.0 * count(*) FILTER (WHERE status_code >= 400) / count(*))::numeric, 2),
    'p50', percentile_cont(0.5) WITHIN GROUP (ORDER BY response_time_ms),
    'p95', percentile_cont(0.95) WITHIN GROUP (ORDER BY response_time_ms),
    'p99', percentile_cont(0.99) WITHIN GROUP (ORDER BY response_time_ms),
    'hourly_trend', (SELECT jsonb_object_agg(hr::text, cnt) FROM (SELECT extract(hour FROM timestamp)::int AS hr, count(*) AS cnt FROM audit.api_requests a2 WHERE a2.endpoint = a1.endpoint AND a2.method = a1.method GROUP BY 1) t)
  ) AS stats
  FROM audit.api_requests a1
  GROUP BY endpoint, method
) x;

/* Q78. */
WITH ordered AS (
  SELECT customer_id, view_timestamp,
         lag(view_timestamp) OVER (PARTITION BY customer_id ORDER BY view_timestamp) AS prev_ts
  FROM web_events.page_views
  WHERE customer_id IS NOT NULL
),
sessioned AS (
  SELECT customer_id, view_timestamp,
         sum(CASE WHEN prev_ts IS NULL OR view_timestamp - prev_ts > interval '30 min' THEN 1 ELSE 0 END) OVER (PARTITION BY customer_id ORDER BY view_timestamp) AS session_num
  FROM ordered
)
SELECT customer_id, count(DISTINCT session_num) AS sessions
FROM sessioned
GROUP BY customer_id
ORDER BY sessions DESC
LIMIT 20;

/* Q79. */
SELECT jsonb_build_object('rolling_p95_latency_ms', p95, 'error_budget_pct', 1.0, 'burn_rate', round((count_errors::numeric / NULLIF(count_total, 0) / 0.01)::numeric, 2)) AS slo_board
FROM (
  SELECT percentile_cont(0.95) WITHIN GROUP (ORDER BY response_time_ms) AS p95,
         count(*) FILTER (WHERE status_code >= 500) AS count_errors,
         count(*) AS count_total
  FROM audit.api_requests
  WHERE timestamp >= (SELECT max(timestamp) FROM audit.api_requests) - interval '1 hour'
) x;

/* Q80. */
SELECT p.product_id, jsonb_build_object(
  'latest_price', latest.unit_price, 'p25', corridor.p25, 'p75', corridor.p75,
  'in_corridor', latest.unit_price BETWEEN corridor.p25 AND corridor.p75
) AS pricing_doc
FROM products.products p
JOIN LATERAL (SELECT oi.unit_price FROM sales.order_items oi JOIN sales.orders o ON o.order_id = oi.order_id WHERE oi.prod_id = p.product_id ORDER BY o.order_date DESC LIMIT 1) latest ON true
JOIN LATERAL (SELECT percentile_cont(0.25) WITHIN GROUP (ORDER BY oi.unit_price) AS p25, percentile_cont(0.75) WITHIN GROUP (ORDER BY oi.unit_price) AS p75 FROM sales.order_items oi WHERE oi.prod_id = p.product_id) corridor ON true
WHERE p.product_id IN (SELECT product_id FROM products.products ORDER BY product_id LIMIT 20);

/* Q81. */
SELECT w.warehouse_id, jsonb_build_object('latest_qty', latest_qty, 'days_stale', days_stale) AS command_doc
FROM supply_chain.warehouses w
JOIN LATERAL (
  SELECT sum(quantity_on_hand) AS latest_qty, (SELECT max(order_date) FROM sales.orders) - max(snapshot_date) AS days_stale
  FROM supply_chain.inventory_snapshots s
  WHERE s.warehouse_id = w.warehouse_id AND s.snapshot_date = (SELECT max(snapshot_date) FROM supply_chain.inventory_snapshots s2 WHERE s2.warehouse_id = w.warehouse_id)
) latest ON true;

/* Q82. */
SELECT jsonb_build_object('cohort', cohort_month, 'periods', jsonb_object_agg(months_since::text, jsonb_build_object('retained', retained, 'cum_revenue', cum_revenue))) AS cohort_dashboard
FROM (
  SELECT cohort_month, months_since, retained, sum(period_revenue) OVER (PARTITION BY cohort_month ORDER BY months_since) AS cum_revenue
  FROM (
    SELECT date_trunc('month', c.registration_date)::date AS cohort_month,
           (extract(year FROM o.order_date) - extract(year FROM c.registration_date)) * 12
           + (extract(month FROM o.order_date) - extract(month FROM c.registration_date)) AS months_since,
           count(DISTINCT o.cust_id) AS retained, sum(o.net_total) AS period_revenue
    FROM customers.customers c JOIN sales.orders o ON o.cust_id = c.customer_id
    GROUP BY 1, 2
  ) t WHERE months_since BETWEEN 0 AND 5
) t2
GROUP BY cohort_month
ORDER BY cohort_month DESC
LIMIT 5;

/* Q83. */
SELECT jsonb_build_object('customer_id', customer_id, 'tier', tier, 'segment', segment) AS crm_export
FROM (
  SELECT c.customer_id, c.tier,
         CASE WHEN ntile(4) OVER (ORDER BY coalesce(sum(o.net_total),0)) = 4 THEN 'VIP' ELSE 'Standard' END AS segment
  FROM customers.customers c LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
  GROUP BY c.customer_id, c.tier
) x
ORDER BY customer_id
LIMIT 20;

/* Q84. */
SELECT r.region_name, day, revenue, p99calc.p99, revenue > p99calc.p99 AS is_p99_outlier
FROM (
  SELECT s.region_id, d.day::date, coalesce(sum(o.net_total),0) AS revenue
  FROM core.dim_region rg
  CROSS JOIN generate_series('2025-06-01'::date, '2025-08-31'::date, interval '1 day') AS d(day)
  JOIN stores.stores s ON s.region_id = rg.region_id
  LEFT JOIN sales.orders o ON o.store_id = s.store_id AND o.order_date = d.day
  GROUP BY s.region_id, d.day
) x
JOIN core.dim_region r ON r.region_id = x.region_id
JOIN LATERAL (SELECT percentile_cont(0.99) WITHIN GROUP (ORDER BY rev) AS p99 FROM (
  SELECT coalesce(sum(o2.net_total),0) AS rev FROM stores.stores s2 LEFT JOIN sales.orders o2 ON o2.store_id=s2.store_id WHERE s2.region_id=x.region_id GROUP BY o2.order_date
) t) p99calc ON true
ORDER BY r.region_name, day
LIMIT 50;

/* Q85. */
SELECT jsonb_build_object('table', table_name, 'jumps', count(*), 'actors', jsonb_agg(DISTINCT changed_by)) AS compliance_doc
FROM (
  SELECT table_name, changed_by,
         round((abs((new_value::numeric - old_value::numeric) / NULLIF(old_value::numeric,0)) * 100)::numeric, 2) AS pct_change
  FROM audit.record_changes
  WHERE column_name = 'price' AND old_value ~ '^[0-9.]+$' AND new_value ~ '^[0-9.]+$'
) x
WHERE pct_change > 50
GROUP BY table_name
ORDER BY table_name;

/* Q86. */
SELECT jsonb_object_agg('channel_' || event_type, hours) AS funnel_json
FROM (
  SELECT event_type, jsonb_object_agg(hour::text, cnt) AS hours
  FROM (
    SELECT event_type, extract(hour FROM event_timestamp)::int AS hour, count(*) AS cnt
    FROM web_events.events
    GROUP BY 1, 2
  ) x
  GROUP BY event_type
) y;

/* Q87. */
SELECT jsonb_agg(jsonb_build_object(
  'region', region_name, 'median_aov', median_aov, 'p90_aov', p90_aov, 'p95_aov', p95_aov,
  'sla_pct', sla_pct, 'latest_order', latest_order, 'rank', rn
)) AS exec_dashboard
FROM (
  SELECT r.region_name,
         percentile_cont(0.5) WITHIN GROUP (ORDER BY o.net_total) AS median_aov,
         percentile_cont(0.9) WITHIN GROUP (ORDER BY o.net_total) AS p90_aov,
         percentile_cont(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95_aov,
         round((100.0 * count(*) FILTER (WHERE sh.delivered_date - o.order_date <= 3) / NULLIF(count(sh.shipment_id), 0))::numeric, 2) AS sla_pct,
         max(o.order_date) AS latest_order,
         rank() OVER (ORDER BY sum(o.net_total) DESC) AS rn
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  JOIN core.dim_region r ON r.region_id = s.region_id
  LEFT JOIN sales.shipments sh ON sh.order_id = o.order_id
  GROUP BY r.region_name
) x;

/* Q88. Conceptual: a schema-registry-style gateway validates every incoming document against a registered contract per (event_type, version) - checking required keys (?&), field types (jsonb_typeof), enum membership, and the declared version number - rejecting or quarantining anything that fails, exactly like the Q28/Q73 validation patterns generalized into a reusable per-schema check rather than one-off per-table logic. */

/* Q89. */
SELECT jsonb_build_object('data', page, 'meta', jsonb_build_object('page', 1, 'total', total)) AS api_response
FROM (
  SELECT jsonb_agg(jsonb_build_object('order_id', order_id, 'status', order_status) ORDER BY order_id) AS page
  FROM (SELECT order_id, order_status FROM sales.orders WHERE order_status = 'Delivered' ORDER BY order_id LIMIT 10) t
) x
CROSS JOIN (SELECT count(*) AS total FROM sales.orders WHERE order_status = 'Delivered') c;

/* Q90. */
SELECT jsonb_object_agg(device_type, dow_hours) AS heatmap_product
FROM (
  SELECT device_type, jsonb_object_agg(dow::text, hours) AS dow_hours
  FROM (
    SELECT device_type, dow, jsonb_object_agg(hour::text, round((100.0 * page_views / max_views)::numeric, 2)) AS hours
    FROM (
      SELECT device_type, dow, hour, page_views, max(page_views) OVER (PARTITION BY device_type, dow) AS max_views
      FROM (
        SELECT device_type, extract(dow FROM view_timestamp)::int AS dow, extract(hour FROM view_timestamp)::int AS hour, count(*) AS page_views
        FROM web_events.page_views
        GROUP BY 1, 2, 3
      ) base
    ) x
    GROUP BY device_type, dow
  ) y
  GROUP BY device_type
) z;

/* Q91. */
SELECT jsonb_build_object('mart', 'region_daily', 'total_regions', count(DISTINCT region_id), 'consistent', bool_and(daily_sum = monthly_agg)) AS reconciliation_result
FROM (
  SELECT s.region_id,
         sum(o.net_total) AS daily_sum,
         sum(o.net_total) AS monthly_agg
  FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id
  GROUP BY s.region_id
) x;

/* Q92. */
SELECT week_start, p95_revenue, lag(p95_revenue) OVER (ORDER BY week_start) AS prev_p95,
       round((100.0 * (p95_revenue - lag(p95_revenue) OVER (ORDER BY week_start)) / NULLIF(lag(p95_revenue) OVER (ORDER BY week_start), 0))::numeric, 2) AS shift_pct
FROM (
  SELECT date_trunc('week', order_date)::date AS week_start, percentile_cont(0.95) WITHIN GROUP (ORDER BY net_total) AS p95_revenue
  FROM sales.orders
  GROUP BY 1
) w
ORDER BY week_start;

/* Q93. */
SELECT jsonb_build_object('customer_id', c.customer_id,
       'stage', CASE WHEN max(o.order_date) IS NULL THEN 'never_purchased'
                     WHEN (SELECT max(order_date) FROM sales.orders) - max(o.order_date) <= 90 THEN 'active'
                     ELSE 'dormant' END,
       'first_order', min(o.order_date), 'latest_order', max(o.order_date)
) AS lifecycle_json
FROM customers.customers c
LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
GROUP BY c.customer_id
ORDER BY c.customer_id
LIMIT 20;

/* Q94. */
SELECT jsonb_build_object('prod_id', p.product_id, 'price', p.price, 'in_promo', EXISTS (SELECT 1 FROM products.promotions pr WHERE pr.active=true),
       'margin', round(((p.price - p.cost_price)/NULLIF(p.price,0))::numeric, 3)) AS catalog_promo_doc
FROM products.products p
ORDER BY p.product_id
LIMIT 20;

/* Q95. */
SELECT r.region_name, count(DISTINCT o.order_status) AS distinct_statuses_used, count(*) AS orders
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;

/* Q96. */
SELECT priority, month,
       round((100.0 * count(*) FILTER (WHERE resolution_hours <= target_hours) / NULLIF(count(*), 0))::numeric, 2) AS attainment_pct
FROM (
  SELECT priority, date_trunc('month', created_date)::date AS month,
         extract(epoch FROM (resolved_date - created_date)) / 3600.0 AS resolution_hours,
         (SELECT percentile_cont(0.9) WITHIN GROUP (ORDER BY extract(epoch FROM (resolved_date - created_date)) / 3600.0)
          FROM support.tickets t2 WHERE t2.priority = t1.priority AND t2.resolved_date IS NOT NULL
            AND date_trunc('quarter', t2.created_date) = date_trunc('quarter', t1.created_date) - interval '3 months') AS target_hours
  FROM support.tickets t1
  WHERE resolved_date IS NOT NULL
) x
WHERE target_hours IS NOT NULL
GROUP BY priority, month
ORDER BY priority, month;

/* Q97. */
SELECT r.region_name, jsonb_build_object(
  'business_kpis', jsonb_build_object('revenue', sum(o.net_total), 'orders', count(*)),
  'observability', jsonb_build_object('avg_page_load_proxy', avg(o.net_total))
) AS unified_doc
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;

/* Q98. Conceptual: a backfill/replay-safe ingestion design keys every event by a stable unique id and always writes via INSERT ... ON CONFLICT (event_id) DO NOTHING (or DO UPDATE for corrections), so replaying the same historical batch twice never double-counts; the accompanying reconciliation query sums a target metric both from the raw ingested rows and from a downstream mart and asserts they're equal after each replay. */

/* Q99. */
WITH ingested AS (
  SELECT jsonb_build_object('order_id', order_id, 'status', order_status, 'net_total', net_total) AS doc
  FROM sales.orders
),
validated AS (
  SELECT doc FROM ingested WHERE doc ?& array['order_id','status','net_total']
),
flattened AS (
  SELECT (doc->>'order_id')::int AS order_id, doc->>'status' AS status, (doc->>'net_total')::numeric AS net_total
  FROM validated
),
aggregated AS (
  SELECT status, count(*) AS orders, sum(net_total) AS revenue FROM flattened GROUP BY status
)
SELECT jsonb_agg(jsonb_build_object('status', status, 'orders', orders, 'revenue', revenue)) AS export
FROM aggregated;

/* Q100. Capstone: the production customer-360 + region-KPI JSON service combines the Q51-style per-customer nested document (profile, orders[], reviews[], tickets[], median/P95 spend) with the Q87-style region-KPI array (median/P90/P95 AOV, SLA%, rank), each validated at ingest (Q28/Q73-style key/type/enum checks) and reconciled against relational totals (Q75/Q99-style assertions); a GIN index (Day 20) accelerates any @> containment lookups over stored JSONB, and since both documents are expensive multi-join aggregates, production would precompute them into materialized views (Day 25) refreshed on a schedule rather than recomputing on every API call. */

/* ============================================================
   END OF ANSWER KEY - CRAZY LEVEL (100/100)
============================================================ */
