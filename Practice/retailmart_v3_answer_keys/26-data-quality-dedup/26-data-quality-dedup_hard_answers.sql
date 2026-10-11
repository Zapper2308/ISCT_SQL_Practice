/* ============================================================
   ANSWER KEY - Data Quality, Deduplication & Cleansing (HARD LEVEL)
   Curriculum:   RetailMart V3
   NOTE: Questions that ask to build a Day-25 view/materialized-view/index
     ("MV candidate", "cleansed view", "plan+index design") are answered
     conceptually here - materialization is explicitly scoped to Day 25
     in this curriculum, and this file only detects/reports via SELECT.
   ============================================================ */

/* Q1.  A canonical-key strategy applies the same deterministic transforms (LOWER, TRIM, collapse internal whitespace, strip punctuation) to every candidate value before comparing, so cosmetically-different values that represent the same entity land on the same key. */
/* Q2.  A soft/fuzzy match is when two rows share the same canonical key but differ in their original verbatim text - reconciliation reports these pairs so a human confirms they really are the same entity. */
/* Q3.  Most-recent favors freshness, most-active favors engagement/volume, highest-quality-score blends several signals into one number - the right rule depends on which row's data you actually trust more for that entity. */
/* Q4.  A tie-breaker (a numeric id, a secondary date) must always be part of the ORDER BY so that when the primary keep-rule ties, the same row wins on every rerun - otherwise the dedup result becomes non-deterministic. */
/* Q5.  Invalid or duplicate rows are written to a separate SELECT result (not deleted or silently fixed) so a human reviewer can confirm the proposed action before anything changes. */
/* Q6.  A percentile baseline (P95/P99) adapts to the actual shape and scale of the data and can be computed per group; a static threshold is a guess that ages badly and ignores that different groups have different normal ranges. */
/* Q7.  Period-over-period drift detection compares a metric this period to LAG(metric) from the prior period (Day 23 grouping + Day 18 LAG), flagging swings beyond a normal band rather than absolute levels. */
/* Q8.  A reconciliation contract states an invariant that must hold between two related facts (every Delivered order has a shipment; SUM(order_items) = orders.net_total) and a violation is itself the data-quality signal. */
/* Q9.  A DQ scorecard pivots (rule x dimension) so pass/fail counts are visible per region or month in one table, making it easy to see where a rule is failing concentratedly. */
/* Q10. A materialized cleansed layer needs an explicit refresh cadence (e.g. hourly/nightly) and an SLA for staleness, because unlike a view it does not reflect new data until it's refreshed. */
/* Q11. At scale, composite-key dedup benefits from a btree index on the canonical key columns so the GROUP BY/PARTITION BY can use an index scan instead of a full sort of the whole table. */
/* Q12. EXPLAIN ANALYZE shows whether the dedup query's window/group step used a Sort or a Hash-based plan, and the actual vs estimated row counts reveal whether statistics are stale. */
/* Q13. A JSON quarantine payload packages each failing row with its rule id, reason and timestamp as a single jsonb object, making it easy to ship to a queue or BI tool without a rigid column schema. */
/* Q14. Free-text classification first narrows candidates with a cheap regex pre-screen (e.g. contains a profanity/URL pattern), then routes only the ambiguous subset to manual/human review instead of reviewing everything. */
/* Q15. Anomaly batching per-region means a national spike doesn't hide a regional problem (and vice versa) - global thresholds average away exactly the local signal you want to catch. */
/* Q16. A multi-rule DQ engine keeps a rule registry (rule id, description, severity) and runs each rule's SELECT to produce a per-rule pass/fail count, so rules can be added or retired independently. */
/* Q17. A data contract says the upstream system guarantees certain invariants (non-null keys, valid ranges) so downstream consumers don't have to re-validate everything themselves - violations are an upstream bug, not a downstream one. */
/* Q18. At scale, silently COALESCE-ing a NULL to a default inside a DQ check hides the very problem the check exists to catch - the check should count/report the NULL, not paper over it. */
/* Q19. Cleansing transforms must be deterministic (same input always produces the same output) and idempotent (running them twice produces the same result as running once), so reruns are always safe. */
/* Q20. "Auditing the auditor" means writing tests for the DQ engine itself - seeding known-bad rows and confirming each rule actually catches them, so a silently broken rule doesn't give false confidence. */
/* Q21. An IQR fence (1.5x the interquartile range) flags true statistical outliers; a P99 threshold just flags the top 1% regardless of whether that top 1% is actually unusual - conflating the two causes false positives. */
/* Q22. Reconciliation drift over time means a contract that used to hold (e.g. shipments always matched Delivered orders) starts failing more often - tracking the fail-rate trend catches a breaking upstream change early. */
/* Q23. A cleansed MV needs known consumers (dashboards, other views) tracked so that when its schema changes, old-named views/objects can be safely deprecated only after those consumers have migrated. */
/* Q24. Day 27 cohort/RFM/funnel analytics assume every customer and order row is trustworthy - a duplicate customer inflates cohort size, and a bad order date shifts them into the wrong period entirely. */
/* Q25. A rule can be retired when it has produced zero hits over many consecutive audit periods and the underlying upstream cause has been permanently fixed, so it's no longer adding signal. */

/* Q26. */
WITH ranked AS (
  SELECT *,
    ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY phone NULLS LAST, registration_date DESC, customer_id) AS rn
  FROM customers.customers
)
SELECT * FROM ranked WHERE rn = 1;

/* Q27. */
WITH stats AS (
  SELECT c.customer_id,
         COUNT(o.order_id) AS order_ct,
         COALESCE(SUM(o.net_total), 0) AS revenue
  FROM customers.customers c
  LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
  GROUP BY c.customer_id
),
ranked AS (
  SELECT c.*, s.order_ct, s.revenue,
    ROW_NUMBER() OVER (
      PARTITION BY LOWER(TRIM(c.email))
      ORDER BY s.order_ct DESC, s.revenue DESC, c.registration_date DESC
    ) AS rn
  FROM customers.customers c
  JOIN stats s ON s.customer_id = c.customer_id
)
SELECT * FROM ranked WHERE rn = 1;

/* Q28. */
WITH revenue AS (
  SELECT prod_id, SUM(net_amount) AS revenue FROM sales.order_items GROUP BY prod_id
),
ranked AS (
  SELECT p.*, COALESCE(r.revenue,0) AS revenue,
    ROW_NUMBER() OVER (PARTITION BY p.brand_id, LOWER(TRIM(p.product_name)) ORDER BY COALESCE(r.revenue,0) DESC) AS rn
  FROM products.products p
  LEFT JOIN revenue r ON r.prod_id = p.product_id
)
SELECT * FROM ranked WHERE rn = 1;

/* Q29. */
WITH last_active AS (
  SELECT supplier_id, MAX(shipped_date) AS last_ship FROM supply_chain.shipments GROUP BY supplier_id
),
ranked AS (
  SELECT s.*, la.last_ship,
    ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(s.supplier_name)) ORDER BY la.last_ship DESC NULLS LAST, s.supplier_id) AS rn
  FROM products.suppliers s
  LEFT JOIN last_active la ON la.supplier_id = s.supplier_id
)
SELECT * FROM ranked WHERE rn = 1;

/* Q30. */
WITH ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY customer_id, product_id ORDER BY review_date DESC, review_id DESC) AS rn
  FROM customers.reviews
)
SELECT * FROM ranked WHERE rn = 1;

/* Q31. */
WITH ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY cust_id, order_date, net_total ORDER BY order_id ASC) AS rn
  FROM sales.orders
)
SELECT * FROM ranked WHERE rn = 1;

/* Q32. */
WITH ordered AS (
  SELECT *,
    LAG(view_timestamp) OVER (PARTITION BY customer_id, session_id, page_url ORDER BY view_timestamp) AS prev_ts
  FROM web_events.page_views
)
SELECT * FROM ordered
WHERE prev_ts IS NULL OR view_timestamp - prev_ts > INTERVAL '2 seconds';

/* Q33. */
WITH canon AS (
  SELECT *, LOWER(TRIM(address_line)) AS canon_line, LOWER(TRIM(city)) AS canon_city,
         REGEXP_REPLACE(pincode, '\D', '', 'g') AS canon_pin
  FROM customers.addresses
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (
    PARTITION BY customer_id, canon_line, canon_city, canon_pin ORDER BY address_id DESC
  ) AS rn
  FROM canon
)
SELECT * FROM ranked WHERE rn = 1;

/* Q34. */
WITH ranked AS (
  SELECT *, ROW_NUMBER() OVER (
    PARTITION BY customer_id, subject, DATE_TRUNC('day', created_date) ORDER BY created_date ASC
  ) AS rn
  FROM support.tickets
)
SELECT * FROM ranked WHERE rn = 1;

/* Q35. */
WITH ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY employee_id, salary_month, salary_year ORDER BY pay_slip_id DESC) AS rn
  FROM payroll.pay_slips
)
SELECT * FROM ranked WHERE rn = 1;

/* Q36. Inventory snapshots have no updated_at column - snapshot_date is part of the composite primary key itself, so every (warehouse_id, product_id, snapshot_date) row is already unique by construction and there is nothing to dedup; keep-most-recent would simply mean keeping the row with the latest snapshot_date per (warehouse_id, product_id). */

/* Q37. */
WITH canon AS (
  SELECT brand_id, brand_name, LOWER(REGEXP_REPLACE(TRIM(brand_name), '\s+', ' ', 'g')) AS canon_name
  FROM core.dim_brand
)
SELECT canon_name, COUNT(*) AS n, array_agg(brand_id ORDER BY brand_id) AS brand_ids
FROM canon
GROUP BY canon_name
HAVING COUNT(*) > 1;

/* Q38. */
WITH rn_method AS (
  SELECT customer_id, email, ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY registration_date DESC) AS rn
  FROM customers.customers
),
distinct_on_method AS (
  SELECT DISTINCT ON (LOWER(TRIM(email))) customer_id, email
  FROM customers.customers
  ORDER BY LOWER(TRIM(email)), registration_date DESC
)
SELECT (SELECT COUNT(*) FROM rn_method WHERE rn = 1) AS row_number_kept,
       (SELECT COUNT(*) FROM distinct_on_method) AS distinct_on_kept;

/* Q39. */
WITH ranked AS (
  SELECT customer_id, email, registration_date,
    ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY registration_date DESC) AS rn
  FROM customers.customers
)
SELECT customer_id, email, registration_date, 'duplicate_email_not_most_recent' AS reason,
       'suggest: merge into most-recent row for this canonical email' AS proposed_action
FROM ranked WHERE rn > 1;

/* Q40. */
WITH rn_method AS (
  SELECT customer_id, LOWER(TRIM(email)) AS canon_email,
    ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY registration_date DESC) AS rn
  FROM customers.customers
),
distinct_on_method AS (
  SELECT DISTINCT ON (LOWER(TRIM(email))) customer_id, LOWER(TRIM(email)) AS canon_email
  FROM customers.customers ORDER BY LOWER(TRIM(email)), registration_date DESC
)
SELECT r.canon_email, r.customer_id AS row_number_winner, d.customer_id AS distinct_on_winner
FROM (SELECT * FROM rn_method WHERE rn = 1) r
JOIN distinct_on_method d ON d.canon_email = r.canon_email
WHERE r.customer_id IS DISTINCT FROM d.customer_id;

/* Q41. */
WITH by_email AS (
  SELECT customer_id, LOWER(TRIM(email)) AS key1 FROM customers.customers
),
by_name_phone AS (
  SELECT customer_id, LOWER(TRIM(first_name)) || '|' || LOWER(TRIM(last_name)) || '|' || COALESCE(phone,'') AS key2
  FROM customers.customers
)
SELECT e1.key1, COUNT(*) AS group_size, 'email_key' AS matched_on
FROM by_email e1 GROUP BY e1.key1 HAVING COUNT(*) > 1
UNION ALL
SELECT n1.key2, COUNT(*), 'name_phone_key'
FROM by_name_phone n1 GROUP BY n1.key2 HAVING COUNT(*) > 1;

/* Q42. */
SELECT city, LOWER(TRIM(store_name)) AS canon_name, COUNT(*) AS n, array_agg(store_id ORDER BY store_id) AS store_ids
FROM stores.stores
GROUP BY city, LOWER(TRIM(store_name))
HAVING COUNT(*) > 1;

/* Q43. */
WITH ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY LOWER(email) ORDER BY store_id ASC) AS rn
  FROM stores.employees
  WHERE email IS NOT NULL
)
SELECT * FROM ranked WHERE rn = 1;

/* Q44. */
WITH scored AS (
  SELECT c.customer_id, c.first_name, c.last_name,
         COUNT(DISTINCT o.order_id) AS order_ct,
         COUNT(DISTINCT r.review_id) AS review_ct,
         COUNT(DISTINCT o.order_id) * 2 + COUNT(DISTINCT r.review_id) AS score
  FROM customers.customers c
  LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
  LEFT JOIN customers.reviews r ON r.customer_id = c.customer_id
  GROUP BY c.customer_id, c.first_name, c.last_name
),
ranked AS (
  SELECT s.*, ROW_NUMBER() OVER (
    PARTITION BY LOWER(TRIM(c.email)) ORDER BY s.score DESC
  ) AS rn
  FROM scored s
  JOIN customers.customers c ON c.customer_id = s.customer_id
)
SELECT * FROM ranked WHERE rn = 1;

/* Q45. */
SELECT DISTINCT ON (LOWER(TRIM(email))) customer_id, email, registration_date
FROM customers.customers
ORDER BY LOWER(TRIM(email)), registration_date ASC;

/* Q46. */
WITH ranked AS (
  SELECT customer_id, LOWER(TRIM(email)) AS canon_email,
    ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY registration_date DESC) AS rn
  FROM customers.customers
)
SELECT
  (SELECT COUNT(*) FROM ranked WHERE rn = 1) AS kept,
  (SELECT COUNT(*) FROM ranked WHERE rn > 1) AS losers,
  (SELECT COUNT(*) FROM ranked) AS total,
  (SELECT COUNT(*) FROM ranked WHERE rn = 1) + (SELECT COUNT(*) FROM ranked WHERE rn > 1)
    = (SELECT COUNT(*) FROM ranked) AS round_trip_ok;

/* Q47. Determinism (a numeric tie-breaker in every ORDER BY) plus using pure, side-effect-free SELECTs (no random(), no now()-dependent logic without freezing the reference time) is what makes a dedup query idempotent - rerunning it on unchanged data always returns the exact same kept/loser split. */

/* Q48. This is a plan-inspection exercise, not a data query - run the customer dedup engine through EXPLAIN ANALYZE and check whether it uses a Sort + WindowAgg (as below) or can instead use an index-backed scan on a functional index over LOWER(TRIM(email)); if the sort dominates the cost, that functional index is the fix (Day 20). */
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY registration_date DESC) AS rn
  FROM customers.customers
) x WHERE rn = 1;

/* Q49. */
SELECT DISTINCT ON (LOWER(TRIM(email))) customer_id, LOWER(TRIM(email)) AS email, phone, registration_date, tier
FROM customers.customers
ORDER BY LOWER(TRIM(email)), registration_date DESC;

/* Q50. */
WITH ranked AS (
  SELECT customer_id, email, registration_date, LOWER(TRIM(email)) AS canon_email,
    ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY registration_date DESC) AS rn,
    DENSE_RANK() OVER (ORDER BY LOWER(TRIM(email))) AS dup_group_id
  FROM customers.customers
  WHERE email IN (SELECT email FROM customers.customers GROUP BY email HAVING COUNT(*) > 1)
)
SELECT jsonb_agg(jsonb_build_object(
  'customer_id', customer_id, 'canon_email', canon_email, 'dup_group_id', dup_group_id
)) AS quarantine_payload
FROM ranked WHERE rn > 1;

/* Q51. */
WITH regional_baseline AS (
  SELECT r.region_id,
         PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o.net_total) AS p95,
         PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY o.net_total) AS p99
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  JOIN core.dim_region r ON r.region_id = s.region_id
  GROUP BY r.region_id
)
SELECT o.order_id, s.region_id, o.net_total, rb.p95, rb.p99,
       CASE WHEN o.net_total > rb.p99 THEN 'severe' WHEN o.net_total > rb.p95 THEN 'moderate' END AS severity
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN regional_baseline rb ON rb.region_id = s.region_id
WHERE o.net_total > rb.p95;

/* Q52. */
WITH regional_iqr AS (
  SELECT r.region_id,
         PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY o.net_total) AS q1,
         PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY o.net_total) AS q3
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  JOIN core.dim_region r ON r.region_id = s.region_id
  GROUP BY r.region_id
)
SELECT o.order_id, s.region_id, o.net_total, ri.q1, ri.q3,
       (ri.q3 - ri.q1) AS iqr,
       ri.q3 + 1.5 * (ri.q3 - ri.q1) AS upper_fence
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN regional_iqr ri ON ri.region_id = s.region_id
WHERE o.net_total > ri.q3 + 1.5 * (ri.q3 - ri.q1)
   OR o.net_total < ri.q1 - 1.5 * (ri.q3 - ri.q1);

/* Q53. */
WITH monthly AS (
  SELECT s.region_id, DATE_TRUNC('month', o.order_date) AS month, SUM(o.net_total) AS revenue
  FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id
  GROUP BY s.region_id, DATE_TRUNC('month', o.order_date)
),
with_prev AS (
  SELECT *, LAG(revenue) OVER (PARTITION BY region_id ORDER BY month) AS prev_revenue
  FROM monthly
)
SELECT region_id, month, revenue, prev_revenue,
       (revenue - prev_revenue) / NULLIF(prev_revenue,0) AS mom_pct
FROM with_prev
WHERE prev_revenue IS NOT NULL AND ABS((revenue - prev_revenue) / NULLIF(prev_revenue,0)) > 0.5;

/* Q54. */
SELECT rc.change_id, p.product_name, rc.old_value, rc.new_value, rc.changed_at,
       (rc.new_value::numeric - rc.old_value::numeric) / NULLIF(rc.old_value::numeric,0) AS pct_change
FROM audit.record_changes rc
JOIN products.products p ON p.product_id = rc.record_id
WHERE rc.table_name = 'products' AND rc.column_name = 'price'
  AND ABS((rc.new_value::numeric - rc.old_value::numeric) / NULLIF(rc.old_value::numeric,0)) > 0.5;

/* Q55. */
SELECT rc.change_id, e.first_name, e.last_name, rc.old_value, rc.new_value, rc.changed_at,
       (rc.new_value::numeric - rc.old_value::numeric) / NULLIF(rc.old_value::numeric,0) AS pct_change
FROM audit.record_changes rc
JOIN stores.employees e ON e.employee_id = rc.record_id
WHERE rc.table_name = 'employees' AND rc.column_name = 'salary'
  AND ABS((rc.new_value::numeric - rc.old_value::numeric) / NULLIF(rc.old_value::numeric,0)) > 0.3;

/* Q56. */
WITH resolution AS (
  SELECT ticket_id, priority, EXTRACT(EPOCH FROM (resolved_date - created_date))/3600 AS resolution_hours
  FROM support.tickets WHERE resolved_date IS NOT NULL
),
baseline AS (
  SELECT priority, PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY resolution_hours) AS p95
  FROM resolution GROUP BY priority
)
SELECT r.ticket_id, r.priority, r.resolution_hours, b.p95
FROM resolution r JOIN baseline b ON b.priority = r.priority
WHERE r.resolution_hours > b.p95;

/* Q57. */
WITH delivery AS (
  SELECT s.order_id, r.region_id, (sh.delivered_date - sh.shipped_date) AS delivery_days
  FROM sales.shipments sh
  JOIN sales.orders s ON s.order_id = sh.order_id
  JOIN stores.stores st ON st.store_id = s.store_id
  JOIN core.dim_region r ON r.region_id = st.region_id
  WHERE sh.delivered_date IS NOT NULL AND sh.shipped_date IS NOT NULL
),
baseline AS (
  SELECT region_id, PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY delivery_days) AS p95
  FROM delivery GROUP BY region_id
)
SELECT d.order_id, d.region_id, d.delivery_days, b.p95
FROM delivery d JOIN baseline b ON b.region_id = d.region_id
WHERE d.delivery_days > b.p95;

/* Q58. */
WITH wh_median AS (
  SELECT warehouse_id, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY quantity_on_hand) AS median_qty
  FROM supply_chain.inventory_snapshots GROUP BY warehouse_id
)
SELECT s.warehouse_id, s.product_id, s.snapshot_date, s.quantity_on_hand, m.median_qty
FROM supply_chain.inventory_snapshots s
JOIN wh_median m ON m.warehouse_id = s.warehouse_id
WHERE m.median_qty > 0 AND s.quantity_on_hand > 5 * m.median_qty;

/* Q59. */
WITH platform_p95 AS (
  SELECT platform, PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY amount) AS p95
  FROM marketing.ads_spend GROUP BY platform
)
SELECT a.spend_id, a.platform, a.spend_date, a.amount, p.p95
FROM marketing.ads_spend a JOIN platform_p95 p ON p.platform = a.platform
WHERE a.amount > p.p95;

/* Q60. Rating anomaly by z-score is a concept-only extension of Q83 (easy): PostgreSQL has no MEDIAN/z-score built-in, so it is computed as (rating - AVG(rating)) / STDDEV(rating) per product and flagged when the absolute value exceeds 2 - the runnable form of this is Q83 in the medium file. */

/* Q61. */
WITH session_len AS (
  SELECT p.customer_id, p.device_type, p.session_id, COUNT(*) AS views
  FROM web_events.page_views p
  GROUP BY p.customer_id, p.device_type, p.session_id
),
scored AS (
  SELECT *, NTILE(100) OVER (PARTITION BY device_type ORDER BY views) AS pct_bucket
  FROM session_len
)
SELECT * FROM scored WHERE pct_bucket = 99;

/* Q62. */
SELECT o.order_id
FROM sales.orders o
LEFT JOIN sales.payments p ON p.order_id = o.order_id
WHERE p.payment_id IS NULL
  AND o.order_date >= (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '90 days';

/* Q63. */
SELECT shipment_id, order_id, shipped_date, delivered_date
FROM sales.shipments
WHERE delivered_date IS NOT NULL AND shipped_date IS NOT NULL AND shipped_date > delivered_date;

/* Q64. */
SELECT t.ticket_id, t.customer_id, t.created_date, c.registration_date
FROM support.tickets t
JOIN customers.customers c ON c.customer_id = t.customer_id
WHERE c.registration_date > t.created_date::date;

/* Q65. */
SELECT 'order_gt_p95' AS rule_id, 'moderate' AS severity, o.order_id::text AS row_id
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN (SELECT s2.region_id, PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o2.net_total) AS p95
      FROM sales.orders o2 JOIN stores.stores s2 ON s2.store_id = o2.store_id
      GROUP BY s2.region_id) rb ON rb.region_id = s.region_id
WHERE o.net_total > rb.p95
UNION ALL
SELECT 'shipment_delivered_before_shipped', 'high', shipment_id::text
FROM sales.shipments WHERE delivered_date < shipped_date
UNION ALL
SELECT 'ticket_before_registration', 'high', ticket_id::text
FROM support.tickets t JOIN customers.customers c ON c.customer_id = t.customer_id
WHERE c.registration_date > t.created_date::date;

/* Q66. */
WITH monthly_orders AS (
  SELECT DATE_TRUNC('month', order_date) AS month, COUNT(*) AS total,
         COUNT(*) FILTER (WHERE discount_amount > gross_total) AS failed
  FROM sales.orders GROUP BY DATE_TRUNC('month', order_date)
)
SELECT month, total, failed, ROUND(100.0*failed/total, 3) AS pct_failed
FROM monthly_orders ORDER BY month;

/* Q67. */
SELECT r.region_name,
       COUNT(*) FILTER (WHERE o.discount_amount > o.gross_total) AS discount_gt_gross,
       COUNT(*) FILTER (WHERE o.net_total > 100000) AS high_value_ct,
       COUNT(*) AS total_orders
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;

/* Q68. */
WITH ranked AS (
  SELECT s.region_id, o.order_id, o.net_total,
         ROW_NUMBER() OVER (PARTITION BY s.region_id ORDER BY o.net_total DESC) AS rk
  FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id
  WHERE o.net_total > 100000
)
SELECT * FROM ranked WHERE rk <= 5;

/* Q69. */
WITH flagged AS (
  SELECT o.order_id, s.region_id, o.net_total,
    ROW_NUMBER() OVER (PARTITION BY s.region_id ORDER BY o.net_total DESC) AS rk
  FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id
  WHERE o.net_total > 100000
)
SELECT jsonb_agg(jsonb_build_object('order_id', order_id, 'region_id', region_id, 'net_total', net_total))
FROM flagged WHERE rk <= 3;

/* Q70. */
SELECT DISTINCT ON (o.order_id::text, DATE_TRUNC('day', o.order_date))
       o.order_id, o.order_date, 'high_value' AS rule_id
FROM sales.orders o
WHERE o.net_total > 100000
ORDER BY o.order_id::text, DATE_TRUNC('day', o.order_date), o.order_id;

/* Q71. */
WITH daily AS (
  SELECT order_date, COUNT(*) FILTER (WHERE discount_amount > gross_total) AS fail_ct
  FROM sales.orders GROUP BY order_date
)
SELECT order_date,
       SUM(fail_ct) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS rolling_7d_fail_ct
FROM daily ORDER BY order_date;

/* Q72. */
WITH low_spend AS (
  SELECT c.customer_id, c.tier, COALESCE(SUM(o.net_total),0) AS lifetime_spend
  FROM customers.customers c LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
  GROUP BY c.customer_id, c.tier
)
SELECT * FROM low_spend
WHERE lifetime_spend < 500 AND tier NOT IN ('Gold','Platinum');

/* Q73. Running any anomaly engine over the Day-25 cleansed view instead of the raw table is a delivery-pattern choice (swap the FROM clause), not a new query shape - since no cleansed view exists yet on Day 26, every engine above already runs directly against the raw RetailMart tables. */

/* Q74. This is a plan-inspection exercise: run the heaviest anomaly engine (the regional P95 order-value scan, Q51) through EXPLAIN ANALYZE and look for a Seq Scan on sales.orders feeding the percentile aggregate - a btree index on (store_id) or a covering index on orders(store_id, net_total) would speed the join+aggregate. */
EXPLAIN (ANALYZE, BUFFERS)
SELECT o.order_id, s.region_id, o.net_total
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
WHERE o.net_total > (SELECT PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY net_total) FROM sales.orders);

/* Q75. */
SELECT 'shipment_delivered_before_shipped' AS rule, COUNT(*) AS fail_ct
FROM sales.shipments WHERE delivered_date < shipped_date
UNION ALL
SELECT 'ticket_before_registration', COUNT(*)
FROM support.tickets t JOIN customers.customers c ON c.customer_id = t.customer_id
WHERE c.registration_date > t.created_date::date
UNION ALL
SELECT 'order_before_registration', COUNT(*)
FROM sales.orders o JOIN customers.customers c ON c.customer_id = o.cust_id
WHERE o.order_date < c.registration_date;

/* Q76. */
SELECT o.order_id, o.net_total, SUM(oi.net_amount) AS items_net_total,
       o.net_total - SUM(oi.net_amount) AS diff
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id, o.net_total
HAVING o.net_total IS DISTINCT FROM SUM(oi.net_amount);

/* Q77. */
SELECT COALESCE(f.order_id, s.order_id) AS order_id,
       COALESCE(f.finance_total,0) AS finance_total, COALESCE(s.sales_total,0) AS sales_total
FROM (SELECT order_id, SUM(amount) AS finance_total FROM finance.payments GROUP BY order_id) f
FULL JOIN (SELECT order_id, SUM(amount) AS sales_total FROM sales.payments GROUP BY order_id) s
  ON s.order_id = f.order_id
WHERE COALESCE(f.finance_total,0) IS DISTINCT FROM COALESCE(s.sales_total,0);

/* Q78. */
SELECT o.order_id
FROM sales.orders o
LEFT JOIN sales.shipments sh ON sh.order_id = o.order_id
WHERE o.order_status = 'Delivered' AND sh.shipment_id IS NULL;

/* Q79. */
SELECT r.return_id, r.order_id, r.refund_amount, o.net_total
FROM sales.returns r
JOIN sales.orders o ON o.order_id = r.order_id
WHERE r.refund_amount > o.net_total;

/* Q80. Inventory snapshots (warehouse-level) have no shared key with sales activity (store-level order_items), so a true per-warehouse delta-vs-sales reconciliation is not possible with this schema; the closest real check is a product-level total: sum of snapshot quantity decline vs sum of units sold over the same window. */

/* Q81. */
WITH attendance_month AS (
  SELECT employee_id, DATE_TRUNC('month', attendance_date) AS month, COUNT(DISTINCT attendance_date) AS days_present
  FROM hr.attendance
  GROUP BY employee_id, DATE_TRUNC('month', attendance_date)
)
SELECT am.*
FROM attendance_month am
WHERE NOT EXISTS (
  SELECT 1 FROM payroll.pay_slips ps
  WHERE ps.employee_id = am.employee_id
    AND ps.salary_year = EXTRACT(YEAR FROM am.month)::int
    AND TRIM(ps.salary_month) = TRIM(TO_CHAR(am.month, 'Month'))
);

/* Q82. */
SELECT c.customer_id
FROM customers.customers c
LEFT JOIN customers.addresses a ON a.customer_id = c.customer_id
WHERE a.address_id IS NULL;

/* Q83. */
WITH first_order AS (
  SELECT cust_id, MIN(order_date) AS first_order_date FROM sales.orders GROUP BY cust_id
)
SELECT c.customer_id, c.registration_date, fo.first_order_date
FROM customers.customers c
JOIN first_order fo ON fo.cust_id = c.customer_id
WHERE c.registration_date > fo.first_order_date;

/* Q84. */
SELECT r.review_id, r.customer_id, r.product_id, r.review_date, o.order_date
FROM customers.reviews r
JOIN sales.order_items oi ON oi.prod_id = r.product_id
JOIN sales.orders o ON o.order_id = oi.order_id AND o.cust_id = r.customer_id
WHERE r.review_date < o.order_date;

/* Q85. */
SELECT t.ticket_id, t.customer_id, t.created_date, c.registration_date
FROM support.tickets t
JOIN customers.customers c ON c.customer_id = t.customer_id
WHERE t.created_date::date < c.registration_date;

/* Q86. */
SELECT r.region_name,
       COUNT(*) FILTER (WHERE sh.delivered_date < sh.shipped_date) AS bad_shipment_ct,
       COUNT(*) FILTER (WHERE o.order_status = 'Delivered' AND sh.shipment_id IS NULL) AS missing_shipment_ct,
       COUNT(DISTINCT o.order_id) AS total_orders
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
LEFT JOIN sales.shipments sh ON sh.order_id = o.order_id
GROUP BY r.region_name
ORDER BY r.region_name;

/* Q87. */
WITH monthly AS (
  SELECT DATE_TRUNC('month', o.order_date) AS month,
         COUNT(*) FILTER (WHERE o.discount_amount > o.gross_total) AS fail_ct,
         COUNT(*) AS total_ct
  FROM sales.orders o GROUP BY DATE_TRUNC('month', o.order_date)
)
SELECT month, fail_ct, total_ct, ROUND(100.0*fail_ct/total_ct,3) AS pct_failed,
       LAG(ROUND(100.0*fail_ct/total_ct,3)) OVER (ORDER BY month) AS prev_pct_failed
FROM monthly ORDER BY month;

/* Q88. */
SELECT DISTINCT ON (LOWER(TRIM(email))) customer_id, LOWER(TRIM(email)) AS canon_email,
       COALESCE(phone,'unknown') AS clean_phone, registration_date, tier
FROM customers.customers
ORDER BY LOWER(TRIM(email)), registration_date DESC;

/* Q89. */
SELECT p.product_id, REGEXP_REPLACE(TRIM(p.product_name), '\s+', ' ', 'g') AS clean_name,
       LOWER(TRIM(b.brand_name)) AS canonical_brand
FROM products.products p
JOIN core.dim_brand b ON b.brand_id = p.brand_id;

/* Q90. */
SELECT jsonb_agg(jsonb_build_object(
  'row_id', order_id, 'rule_id', 'discount_gt_gross', 'first_seen', order_date
)) AS quarantine_payload
FROM sales.orders
WHERE discount_amount > gross_total;

/* Q91. */
WITH scorecard AS (
  SELECT 'discount_gt_gross' AS rule, COUNT(*) AS fail_ct, (SELECT COUNT(*) FROM sales.orders) AS total_ct
  FROM sales.orders WHERE discount_amount > gross_total
  UNION ALL
  SELECT 'orders_missing_payment', COUNT(*), (SELECT COUNT(*) FROM sales.orders)
  FROM sales.orders o LEFT JOIN sales.payments p ON p.order_id = o.order_id WHERE p.payment_id IS NULL
)
SELECT jsonb_agg(jsonb_build_object('rule', rule, 'fail_ct', fail_ct, 'total_ct', total_ct,
       'pct_failed', ROUND(100.0*fail_ct/total_ct,3))) AS dq_scorecard_json
FROM scorecard;

/* Q92. */
SELECT COUNT(*) AS customers_missing_address
FROM customers.customers c
LEFT JOIN customers.addresses a ON a.customer_id = c.customer_id
WHERE a.address_id IS NULL;

/* Q93. */
WITH first_order AS (
  SELECT cust_id, MIN(order_date) AS first_order_date FROM sales.orders GROUP BY cust_id
)
SELECT COUNT(*) FILTER (WHERE c.registration_date <= fo.first_order_date) AS clean_rfm_inputs,
       COUNT(*) AS customers_with_orders
FROM customers.customers c
JOIN first_order fo ON fo.cust_id = c.customer_id;

/* Q94. */
SELECT COUNT(*) AS total_page_views,
       COUNT(DISTINCT customer_id) AS distinct_customers,
       COUNT(*) FILTER (WHERE customer_id IS NULL) AS anonymous_views,
       COUNT(DISTINCT session_id) AS distinct_sessions
FROM web_events.page_views;

/* Q95. */
SELECT jsonb_agg(jsonb_build_object('order_id', order_id, 'net_total', net_total))
FROM sales.orders WHERE net_total > 100000;

/* Q96. */
WITH rules AS (
  SELECT 'orders' AS tbl, 'discount_gt_gross' AS rule, 2 AS weight,
         COUNT(*) FILTER (WHERE discount_amount > gross_total) AS fail_ct, COUNT(*) AS total_ct
  FROM sales.orders
  UNION ALL
  SELECT 'products', 'price_lt_cost', 3,
         COUNT(*) FILTER (WHERE price < cost_price), COUNT(*)
  FROM products.products
)
SELECT tbl, rule, weight, fail_ct, total_ct,
       ROUND(100.0 * fail_ct / total_ct, 3) AS pct_failed,
       ROUND((100 - 100.0*fail_ct/total_ct) * weight, 2) AS weighted_score
FROM rules;

/* Q97. Day-25 will materialize cleansed customers/orders/products as views; on Day 26 the same logic is available directly as a SELECT - e.g. the customer dedup engine (Q26), the canonical-brand product engine (Q89), and the order net_total reconciliation (Q76) already give an analyst the cleansed row set without needing a persisted view object. */

/* Q98. A repeatable cleansing script is just this file's queries run in a fixed order (dedup -> standardize -> reconcile -> scorecard), each one a pure, deterministic SELECT with no side effects - rerunning the whole script against the same data always reproduces the same output. */

/* Q99. This is a plan-inspection exercise over the full 150k-row orders table. */
EXPLAIN (ANALYZE, BUFFERS)
SELECT o.order_id, o.net_total, SUM(oi.net_amount) AS items_net_total
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id, o.net_total
HAVING o.net_total IS DISTINCT FROM SUM(oi.net_amount);

/* Q100. */
WITH scorecard AS (
  SELECT 'discount_gt_gross' AS rule, COUNT(*) AS fail_ct, (SELECT COUNT(*) FROM sales.orders) AS total_ct
  FROM sales.orders WHERE discount_amount > gross_total
  UNION ALL
  SELECT 'orders_missing_payment', COUNT(*), (SELECT COUNT(*) FROM sales.orders)
  FROM sales.orders o LEFT JOIN sales.payments p ON p.order_id = o.order_id WHERE p.payment_id IS NULL
  UNION ALL
  SELECT 'net_total_mismatch_items', COUNT(*), (SELECT COUNT(*) FROM sales.orders)
  FROM (
    SELECT o.order_id FROM sales.orders o JOIN sales.order_items oi ON oi.order_id = o.order_id
    GROUP BY o.order_id, o.net_total HAVING o.net_total IS DISTINCT FROM SUM(oi.net_amount)
  ) x
),
quarantine_sample AS (
  SELECT order_id, gross_total, discount_amount, net_total
  FROM sales.orders WHERE discount_amount > gross_total LIMIT 20
)
SELECT (SELECT jsonb_agg(jsonb_build_object('rule', rule, 'fail_ct', fail_ct, 'total_ct', total_ct,
         'pct_failed', ROUND(100.0*fail_ct/total_ct,3))) FROM scorecard) AS scorecard_json,
       (SELECT jsonb_agg(jsonb_build_object('order_id', order_id, 'gross_total', gross_total,
         'discount_amount', discount_amount, 'net_total', net_total)) FROM quarantine_sample) AS quarantine_json;
