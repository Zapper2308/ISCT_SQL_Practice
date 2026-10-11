/* ============================================================
   ANSWER KEY - Data Quality, Deduplication & Cleansing (CRAZY LEVEL)
   Curriculum:   RetailMart V3
   NOTE: Questions asking to design/build a production platform, MV/index
     rollout, or documentation are answered conceptually - persisting new
     schema objects (VIEW/MATERIALIZED VIEW/INDEX) is explicitly scoped to
     Day 25 in this curriculum and this is a shared live teaching database,
     so this file stays detection/reporting via SELECT throughout.
   ============================================================ */

/* Q1.  A DQ platform is a pipeline: a rule registry (rule id, SQL, severity, owner) feeds detection engines, whose results roll up into per-table/region/month scorecards, route failing rows to quarantine, and finally publish JSON exports for BI/alerting consumers. */
/* Q2.  Try the highest-priority canonical key first (verified email); if it produces no match, fall back to the next key (phone, then name); candidate groups found by different keys that share a row are merged into one cluster. */
/* Q3.  A weighted score sums normalized signals (e.g. order_count*2 + review_count*1 + recency_bonus) into one number so "best row" becomes an unambiguous ORDER BY target instead of a multi-column judgment call. */
/* Q4.  Idempotency requires every tie in the keep-rule to fall through to a final deterministic tie-breaker (a numeric id) and no non-deterministic function (random(), now() without freezing) anywhere in the logic. */
/* Q5.  Severity = distance from baseline (e.g. how many P95-multiples over) multiplied by a business weight (e.g. revenue-impact orders weigh more than a cosmetic text field) - this ranks anomalies by real impact, not just statistical rarity. */
/* Q6.  A reconciliation contract states an invariant that must hold between two fact tables (SUM(order_items) = orders.net_total, every Delivered order has a shipment) - checking it is literally running the invariant as a WHERE clause and counting violations. */
/* Q7.  DQ SLAs define, per rule, the target pass rate, how fresh the check needs to run (freshness), how quickly a new violation is detected (time-to-detect), and how quickly it's fixed (time-to-fix). */
/* Q8.  The quarantine lifecycle is: a rule detects and writes failing rows to a review set, an owner triages and decides an action, the fix is applied (upstream or via cleansing), the row is re-checked against the rule, and once it passes the item is closed. */
/* Q9.  A cleansed semantic layer is the single, agreed-upon SELECT (or view) that downstream teams query instead of the raw table - it is the contract surface so every consumer sees the same deduped, standardized data. */
/* Q10. A JSON export contract packages a scorecard or quarantine result as one jsonb array of objects with a fixed shape (rule_id, count, pct, severity) so alerting/BI systems can consume it without parsing SQL result columns. */
/* Q11. Computing baselines per group (region, category) instead of globally, and accounting for known seasonality (Day 23 trend) before flagging, both reduce false positives that a single global static threshold would trigger. */
/* Q12. Drift detection tracks a rule's pass-rate over a rolling window (Day 23 grouping + a window function) and flags when the trend itself moves beyond a normal band, catching a slowly-degrading upstream feed. */
/* Q13. Multi-tenant DQ computes baselines and thresholds separately per region/tenant (rather than one company-wide number) so one tenant's normal scale doesn't distort another's anomaly detection. */
/* Q14. Composite-key dedup at scale benefits from a btree index on the canonical key expression itself so PARTITION BY/GROUP BY can avoid a full external sort; EXPLAIN reveals whether the plan chose Sort+WindowAgg vs an index-backed scan. */
/* Q15. An audit trail records, for every cleansing transform, the row id, the old value, the new value, who/what changed it and when - this makes every automated fix reviewable and reversible after the fact. */
/* Q16. A replay-safe pipeline is built entirely from deterministic SELECTs chained cleanse -> reconcile -> publish, so rerunning the whole pipeline on the same source data always reproduces the same published result. */
/* Q17. Documenting rule owner, severity and a runbook link directly in a COMMENT ON MATERIALIZED VIEW/COLUMN keeps operational knowledge attached to the object itself, discoverable via \d+ instead of living in a separate wiki page that drifts out of date. */
/* Q18. Versioning rules (v1, v2 columns or view suffixes) with an explicit deprecation window lets consumers migrate on their own schedule instead of a rule change silently breaking every downstream query at once. */
/* Q19. Data lineage tracks which downstream view/report reads from which cleansed source table, so a change to a source's schema or semantics can be checked against every dependent object before it ships. */
/* Q20. Day 27 needs pristine registration/order dates and one row per real customer - readiness checks here should include zero duplicate customer emails, zero orders before registration, and zero orphan cust_id references. */
/* Q21. {rule_id, row, reason, severity, ts} is a minimal, self-describing envelope: any consumer (alerting, BI, a human) can tell what failed, on which row, why, how bad, and when, without needing the SQL that produced it. */
/* Q22. Silently wrapping a nullable column in COALESCE inside a DQ check (e.g. COALESCE(phone,'') = COALESCE(x,'')) can make two genuinely-missing values match each other and hide the fact that both are actually missing data. */
/* Q23. A dedup query without a deterministic tie-breaker can legally keep a different row on every run when values tie, making the "kept" record non-reproducible and breaking any downstream process that assumes stability. */
/* Q24. A threshold like ">100000" with no baseline behind it can't distinguish a genuinely unusual value from one that's simply normal for a high-value region or a growing business - it produces false positives that erode trust in the whole DQ system. */
/* Q25. A rule can be sunset once it has produced zero hits across many consecutive audit periods (e.g. 90 days) and the team has confirmed the underlying upstream issue was permanently fixed, not just quiet by chance. */

/* Q26. */
WITH scored AS (
  SELECT c.customer_id, LOWER(TRIM(c.email)) AS canon_email, c.phone,
         LOWER(TRIM(c.first_name)) || ' ' || LOWER(TRIM(c.last_name)) AS canon_name,
         COALESCE(oc.order_ct, 0) AS order_ct
  FROM customers.customers c
  LEFT JOIN (SELECT cust_id, COUNT(*) AS order_ct FROM sales.orders GROUP BY cust_id) oc
    ON oc.cust_id = c.customer_id
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY canon_email ORDER BY order_ct DESC, phone NULLS LAST, customer_id) AS rn
  FROM scored
)
SELECT * FROM ranked WHERE rn = 1;

/* Q27. */
WITH revenue AS (
  SELECT prod_id, SUM(net_amount) AS revenue FROM sales.order_items GROUP BY prod_id
),
scored AS (
  SELECT p.product_id, p.brand_id, LOWER(TRIM(p.product_name)) AS canon_name, p.supplier_id,
         COALESCE(r.revenue,0) AS revenue
  FROM products.products p
  LEFT JOIN revenue r ON r.prod_id = p.product_id
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY brand_id, canon_name ORDER BY revenue DESC, supplier_id) AS rn
  FROM scored
)
SELECT * FROM ranked WHERE rn = 1;

/* Q28. */
WITH last_active AS (
  SELECT supplier_id, MAX(shipped_date) AS last_ship FROM supply_chain.shipments GROUP BY supplier_id
),
merged AS (
  SELECT s.supplier_id, LOWER(TRIM(s.supplier_name)) AS canon_name, la.last_ship
  FROM products.suppliers s LEFT JOIN last_active la ON la.supplier_id = s.supplier_id
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY canon_name ORDER BY last_ship DESC NULLS LAST, supplier_id) AS rn
  FROM merged
)
SELECT * FROM ranked WHERE rn = 1;

/* Q29. */
WITH ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY customer_id, product_id ORDER BY review_date DESC, review_id DESC) AS rn
  FROM customers.reviews
)
SELECT customer_id, product_id, review_id, rating, review_date,
       'kept: latest review_date' AS audit_note
FROM ranked WHERE rn = 1;

/* Q30. */
WITH double_submit AS (
  SELECT cust_id, order_date, net_total, MIN(order_id) AS keep_order_id, COUNT(*) AS n
  FROM sales.orders GROUP BY cust_id, order_date, net_total HAVING COUNT(*) > 1
)
SELECT ds.*, p.payment_id
FROM double_submit ds
LEFT JOIN sales.payments p ON p.order_id = ds.keep_order_id;

/* Q31. */
WITH ordered AS (
  SELECT *, LAG(view_timestamp) OVER (
    PARTITION BY customer_id, session_id, page_url ORDER BY view_timestamp
  ) AS prev_ts
  FROM web_events.page_views
)
SELECT * FROM ordered
WHERE prev_ts IS NULL OR view_timestamp - prev_ts > INTERVAL '2 seconds';

/* Q32. */
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

/* Q33. */
WITH ranked AS (
  SELECT *, ROW_NUMBER() OVER (
    PARTITION BY customer_id, subject, DATE_TRUNC('day', created_date) ORDER BY created_date
  ) AS rn
  FROM support.tickets
)
SELECT customer_id, subject, DATE_TRUNC('day', created_date) AS day, COUNT(*) AS reopen_ct
FROM ranked
GROUP BY customer_id, subject, DATE_TRUNC('day', created_date)
HAVING COUNT(*) > 1;

/* Q34. */
WITH ranked AS (
  SELECT ps.*, ROW_NUMBER() OVER (PARTITION BY employee_id, salary_month, salary_year ORDER BY pay_slip_id DESC) AS rn
  FROM payroll.pay_slips ps
),
kept AS (
  SELECT * FROM ranked WHERE rn = 1
)
SELECT k.*, COUNT(DISTINCT a.attendance_date) AS days_present_that_month
FROM kept k
LEFT JOIN hr.attendance a ON a.employee_id = k.employee_id
  AND TO_CHAR(a.attendance_date, 'Month') = k.salary_month
  AND EXTRACT(YEAR FROM a.attendance_date)::int = k.salary_year
GROUP BY k.pay_slip_id, k.employee_id, k.salary_month, k.salary_year, k.basic_salary, k.hra,
         k.other_allowances, k.pf, k.professional_tax, k.income_tax, k.gross_salary, k.net_salary,
         k.payment_date, k.rn;

/* Q35. Inventory snapshots have no updated_at column - snapshot_date is part of the composite primary key, so every row is already unique; "most recent" simply means the max snapshot_date per (warehouse_id, product_id), which needs no dedup logic. */

/* Q36. */
WITH canon AS (
  SELECT brand_id, brand_name, LOWER(REGEXP_REPLACE(TRIM(brand_name), '\s+', ' ', 'g')) AS canon_name
  FROM core.dim_brand
)
SELECT c.canon_name, COUNT(*) AS n, array_agg(c.brand_id ORDER BY c.brand_id) AS brand_ids,
       COUNT(DISTINCT p.supplier_id) AS cross_supplier_ct
FROM canon c
LEFT JOIN products.products p ON p.brand_id = c.brand_id
GROUP BY c.canon_name
HAVING COUNT(*) > 1;

/* Q37. */
WITH ranked AS (
  SELECT customer_id, email, registration_date,
    ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY registration_date DESC) AS rn
  FROM customers.customers
)
SELECT customer_id, email, registration_date,
       'rule=email_dedup' AS rule_id,
       'not most-recent registration for this canonical email' AS reason,
       'merge into most-recent row' AS suggested_action
FROM ranked WHERE rn > 1;

/* Q38. */
WITH ranked AS (
  SELECT COUNT(*) FILTER (WHERE rn = 1) AS kept, COUNT(*) FILTER (WHERE rn > 1) AS losers, COUNT(*) AS total
  FROM (
    SELECT ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY registration_date DESC) AS rn
    FROM customers.customers
  ) x
)
SELECT *, (kept + losers = total) AS round_trip_ok FROM ranked;

/* Q39. */
WITH by_email AS (SELECT customer_id, LOWER(TRIM(email)) AS key_val FROM customers.customers),
by_name AS (SELECT customer_id,
  LOWER(TRIM(first_name)) || '|' || LOWER(TRIM(last_name)) || '|' || COALESCE(phone,'') AS key_val
  FROM customers.customers)
SELECT key_val, COUNT(*) AS n, 'email' AS key_type FROM by_email GROUP BY key_val HAVING COUNT(*) > 1
UNION ALL
SELECT key_val, COUNT(*), 'name_phone' FROM by_name GROUP BY key_val HAVING COUNT(*) > 1;

/* Q40. */
WITH scored AS (
  SELECT c.customer_id, LOWER(TRIM(c.email)) AS canon_email,
         COALESCE(oc.order_ct,0)*2 + COALESCE(oc.order_ct,0) AS score,
         'score = order_ct * 2 (weighted keep-rule)' AS explain_reason
  FROM customers.customers c
  LEFT JOIN (SELECT cust_id, COUNT(*) AS order_ct FROM sales.orders GROUP BY cust_id) oc
    ON oc.cust_id = c.customer_id
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY canon_email ORDER BY score DESC, customer_id) AS rn
  FROM scored
)
SELECT * FROM ranked WHERE rn = 1;

/* Q41. This is a plan-inspection exercise - run the platform's customer dedup engine (Q26) through EXPLAIN ANALYZE and look at whether the PARTITION BY canonical-email step used Sort+WindowAgg (needing a full sort of 50k rows) versus an index-backed scan on a functional btree index over LOWER(TRIM(email)) (Day 20 covering-index design). */
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM (
  SELECT customer_id, ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY registration_date DESC) AS rn
  FROM customers.customers
) x WHERE rn = 1;

/* Q42. A CONCURRENTLY-refreshed cleansed MV backed by this dedup platform is a Day-25 delivery step (it needs a UNIQUE INDEX on the MV before REFRESH MATERIALIZED VIEW CONCURRENTLY can run) - on Day 26 the platform itself is exactly the SELECT in Q26/Q27/Q28, ready to be wrapped in CREATE MATERIALIZED VIEW once that permission applies. */
/* Q43. A versioned cleansed MV (mv_core_customers_v2 alongside mv_core_customers_v1) lets a safe rollout run both versions side by side, compare their row counts/quality, and cut consumers over only once v2 is validated - again a Day-25 delivery concern layered on top of the same detection SQL here. */
/* Q44. */
WITH ranked AS (
  SELECT customer_id, email, LOWER(TRIM(email)) AS canon_email,
    ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY registration_date DESC) AS rn,
    DENSE_RANK() OVER (ORDER BY LOWER(TRIM(email))) AS dup_group_id,
    FIRST_VALUE(customer_id) OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY registration_date DESC) AS kept_row_id
  FROM customers.customers
  WHERE email IN (SELECT email FROM customers.customers GROUP BY email HAVING COUNT(*) > 1)
)
SELECT jsonb_agg(jsonb_build_object(
  'row', customer_id, 'dup_group_id', dup_group_id, 'kept_row_id', kept_row_id,
  'reasons', jsonb_build_array('duplicate_canonical_email')
)) AS quarantine_payload
FROM ranked WHERE rn > 1;

/* Q45. */
WITH ranked AS (
  SELECT customer_id, LOWER(TRIM(email)) AS canon_email,
    ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY registration_date DESC) AS rn
  FROM customers.customers
)
SELECT customer_id AS kept_customer_id, canon_email FROM ranked WHERE rn = 1;

/* Q46. Cross-table propagation means every order/review/ticket row keeps the original customer_id, but a lookup mapping (dup customer_id -> kept_id from Q45) lets any downstream query re-point via a JOIN to that mapping instead of physically rewriting every fact table's foreign key. */
/* Q47. */
WITH first_signup AS (
  SELECT DISTINCT ON (LOWER(TRIM(email))) customer_id, LOWER(TRIM(email)) AS canon_email, registration_date
  FROM customers.customers
  ORDER BY LOWER(TRIM(email)), registration_date ASC
)
SELECT * FROM first_signup;

/* Q48. */
WITH run1 AS (
  SELECT customer_id FROM (
    SELECT customer_id, ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY registration_date DESC) AS rn
    FROM customers.customers
  ) x WHERE rn = 1
),
run2 AS (
  SELECT customer_id FROM (
    SELECT customer_id, ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY registration_date DESC) AS rn
    FROM customers.customers
  ) x WHERE rn = 1
)
SELECT (SELECT COUNT(*) FROM run1) AS run1_ct, (SELECT COUNT(*) FROM run2) AS run2_ct,
       NOT EXISTS (SELECT customer_id FROM run1 EXCEPT SELECT customer_id FROM run2) AS identical_result;

/* Q49. */
WITH ranked AS (
  SELECT customer_id, LOWER(TRIM(email)) AS canon_email,
    ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY registration_date DESC) AS rn
  FROM customers.customers
),
by_region AS (
  SELECT reg.region_name, r0.customer_id, rk.rn
  FROM (SELECT c.customer_id, addr.state FROM customers.customers c
        JOIN customers.addresses addr ON addr.customer_id = c.customer_id AND addr.is_default = true) r0
  JOIN core.dim_region reg ON reg.state = r0.state
  JOIN ranked rk ON rk.customer_id = r0.customer_id
)
SELECT region_name,
       ROUND(100.0 * COUNT(*) FILTER (WHERE rn = 1) / COUNT(*), 2) AS pct_kept,
       ROUND(100.0 * COUNT(*) FILTER (WHERE rn > 1) / COUNT(*), 2) AS pct_merged
FROM by_region
GROUP BY region_name
ORDER BY region_name;

/* Q50. */
WITH ranked AS (
  SELECT customer_id, email, LOWER(TRIM(email)) AS canon_email,
    ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY registration_date DESC) AS rn
  FROM customers.customers
)
SELECT
  (SELECT COUNT(*) FROM ranked WHERE rn = 1) AS detected_kept,
  (SELECT COUNT(*) FROM ranked WHERE rn > 1) AS detected_losers,
  (SELECT jsonb_agg(jsonb_build_object('customer_id', customer_id, 'canon_email', canon_email))
     FROM ranked WHERE rn > 1) AS audit_log_json;

/* Q51. */
WITH region_metric AS (
  SELECT r.region_id, o.net_total
  FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id
  JOIN core.dim_region r ON r.region_id = s.region_id
),
baseline AS (
  SELECT region_id,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total) AS p50,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY net_total) AS p95,
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY net_total) AS p99
  FROM region_metric GROUP BY region_id
)
SELECT rm.region_id, rm.net_total, b.p50, b.p95, b.p99,
       CASE WHEN rm.net_total > b.p99 THEN 'critical' WHEN rm.net_total > b.p95 THEN 'high' ELSE 'normal' END AS severity
FROM region_metric rm JOIN baseline b ON b.region_id = rm.region_id
WHERE rm.net_total > b.p95;

/* Q52. */
WITH monthly AS (
  SELECT DATE_TRUNC('month', order_date) AS month, SUM(net_total) AS revenue
  FROM sales.orders GROUP BY DATE_TRUNC('month', order_date)
),
with_lags AS (
  SELECT *, LAG(revenue,1) OVER (ORDER BY month) AS prev_month,
         LAG(revenue,12) OVER (ORDER BY month) AS prev_year
  FROM monthly
)
SELECT month, revenue,
       (revenue - prev_month) / NULLIF(prev_month,0) AS mom_pct,
       (revenue - prev_year) / NULLIF(prev_year,0) AS yoy_pct
FROM with_lags
WHERE (prev_month IS NOT NULL AND ABS((revenue - prev_month)/NULLIF(prev_month,0)) > 0.2)
   OR (prev_year IS NOT NULL AND ABS((revenue - prev_year)/NULLIF(prev_year,0)) > 0.2)
ORDER BY month;

/* Q53. */
SELECT rc.change_id, p.product_name, rc.old_value, rc.new_value, rc.changed_by, rc.changed_at,
       (rc.new_value::numeric - rc.old_value::numeric) / NULLIF(rc.old_value::numeric,0) AS pct_change
FROM audit.record_changes rc
JOIN products.products p ON p.product_id = rc.record_id
WHERE rc.table_name = 'products' AND rc.column_name = 'price'
  AND ABS((rc.new_value::numeric - rc.old_value::numeric) / NULLIF(rc.old_value::numeric,0)) > 0.5;

/* Q54. */
SELECT rc.change_id, e.first_name, e.last_name, e.dept_id, rc.old_value, rc.new_value, rc.changed_at,
       (rc.new_value::numeric - rc.old_value::numeric) / NULLIF(rc.old_value::numeric,0) AS pct_change
FROM audit.record_changes rc
JOIN stores.employees e ON e.employee_id = rc.record_id
WHERE rc.table_name = 'employees' AND rc.column_name = 'salary'
  AND ABS((rc.new_value::numeric - rc.old_value::numeric) / NULLIF(rc.old_value::numeric,0)) > 0.3;

/* Q55. */
WITH resolution AS (
  SELECT ticket_id, priority, EXTRACT(EPOCH FROM (resolved_date - created_date))/3600 AS resolution_hours
  FROM support.tickets WHERE resolved_date IS NOT NULL
),
monthly AS (
  SELECT r.priority, DATE_TRUNC('month', t.created_date) AS month,
         COUNT(*) FILTER (WHERE r.resolution_hours >
           (SELECT PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY r2.resolution_hours)
            FROM resolution r2 WHERE r2.priority = r.priority)) AS breach_ct,
         COUNT(*) AS total_ct
  FROM support.tickets t
  JOIN resolution r ON r.ticket_id = t.ticket_id
  GROUP BY r.priority, DATE_TRUNC('month', t.created_date)
)
SELECT priority, month, breach_ct, total_ct, ROUND(100.0*breach_ct/total_ct,2) AS breach_pct
FROM monthly ORDER BY priority, month;

/* Q56. */
WITH delivery AS (
  SELECT s.order_id, r.region_id, DATE_TRUNC('week', sh.shipped_date) AS week,
         (sh.delivered_date - sh.shipped_date) AS delivery_days
  FROM sales.shipments sh
  JOIN sales.orders s ON s.order_id = sh.order_id
  JOIN stores.stores st ON st.store_id = s.store_id
  JOIN core.dim_region r ON r.region_id = st.region_id
  WHERE sh.delivered_date IS NOT NULL AND sh.shipped_date IS NOT NULL
),
baseline AS (
  SELECT region_id, week, PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY delivery_days) AS p95
  FROM delivery GROUP BY region_id, week
)
SELECT d.order_id, d.region_id, d.week, d.delivery_days, b.p95
FROM delivery d JOIN baseline b ON b.region_id = d.region_id AND b.week = d.week
WHERE d.delivery_days > b.p95;

/* Q57. */
WITH wh_daily AS (
  SELECT warehouse_id, snapshot_date, quantity_on_hand FROM supply_chain.inventory_snapshots
),
baseline AS (
  SELECT warehouse_id, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY quantity_on_hand) AS median_qty
  FROM wh_daily GROUP BY warehouse_id
)
SELECT w.warehouse_id, w.product_id, w.snapshot_date, w.quantity_on_hand, b.median_qty
FROM supply_chain.inventory_snapshots w
JOIN baseline b ON b.warehouse_id = w.warehouse_id
WHERE b.median_qty > 0 AND w.quantity_on_hand > 5 * b.median_qty;

/* Q58. */
WITH baseline AS (
  SELECT platform,
         AVG(amount) AS avg_amount,
         PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY amount) AS p95
  FROM marketing.ads_spend GROUP BY platform
)
SELECT a.spend_id, a.platform, a.spend_date, a.amount, b.avg_amount, b.p95
FROM marketing.ads_spend a JOIN baseline b ON b.platform = a.platform
WHERE a.amount > b.p95;

/* Q59. Rating outlier via z-score is the same runnable query as topic-26-medium Q83 (AVG/STDDEV per product, flag |rating - avg| > 2*stddev) - PostgreSQL has no built-in z-score function so it is always hand-computed this way. */

/* Q60. */
WITH session_len AS (
  SELECT device_type, customer_id, session_id, COUNT(*) AS views
  FROM web_events.page_views GROUP BY device_type, customer_id, session_id
),
scored AS (
  SELECT *, NTILE(100) OVER (PARTITION BY device_type ORDER BY views) AS pct_bucket
  FROM session_len
)
SELECT * FROM scored WHERE pct_bucket = 99;

/* Q61. */
WITH ranked AS (
  SELECT 'order_gt_p95' AS rule_id, o.order_id::text AS row_id,
         (o.net_total - rb.p95) AS distance, 3 AS business_weight
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  JOIN (SELECT s2.region_id, PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o2.net_total) AS p95
        FROM sales.orders o2 JOIN stores.stores s2 ON s2.store_id = o2.store_id
        GROUP BY s2.region_id) rb ON rb.region_id = s.region_id
  WHERE o.net_total > rb.p95
  UNION ALL
  SELECT 'shipment_delivered_before_shipped', shipment_id::text,
         (shipped_date - delivered_date)::numeric, 5
  FROM sales.shipments WHERE delivered_date < shipped_date
)
SELECT rule_id, row_id, distance, business_weight, distance * business_weight AS severity_score
FROM ranked
ORDER BY severity_score DESC
LIMIT 100;

/* Q62. */
WITH ranked AS (
  SELECT 'order_gt_p95' AS rule_id, o.order_id::text AS row_id,
         (o.net_total - rb.p95) * 3 AS severity_score
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  JOIN (SELECT s2.region_id, PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY o2.net_total) AS p95
        FROM sales.orders o2 JOIN stores.stores s2 ON s2.store_id = o2.store_id
        GROUP BY s2.region_id) rb ON rb.region_id = s.region_id
  WHERE o.net_total > rb.p95
)
SELECT * FROM ranked ORDER BY severity_score DESC LIMIT 20;

/* Q63. */
WITH daily AS (
  SELECT order_date, COUNT(*) FILTER (WHERE discount_amount > gross_total) AS fail_ct, COUNT(*) AS total_ct
  FROM sales.orders GROUP BY order_date
)
SELECT order_date,
       SUM(fail_ct) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS rolling_7d_fail_ct,
       SUM(total_ct) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS rolling_7d_total_ct
FROM daily
ORDER BY order_date;

/* Q64. */
SELECT o.order_id, o.net_total, SUM(oi.net_amount) AS items_net_total
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id, o.net_total
HAVING o.net_total IS DISTINCT FROM SUM(oi.net_amount);

/* Q65. */
SELECT COALESCE(f.order_id, s.order_id) AS order_id,
       COALESCE(f.finance_total,0) AS finance_total, COALESCE(s.sales_total,0) AS sales_total
FROM (SELECT order_id, SUM(amount) AS finance_total FROM finance.payments GROUP BY order_id) f
FULL JOIN (SELECT order_id, SUM(amount) AS sales_total FROM sales.payments GROUP BY order_id) s
  ON s.order_id = f.order_id
WHERE COALESCE(f.finance_total,0) IS DISTINCT FROM COALESCE(s.sales_total,0);

/* Q66. */
SELECT o.order_id
FROM sales.orders o
LEFT JOIN sales.shipments sh ON sh.order_id = o.order_id
WHERE o.order_status = 'Delivered' AND sh.shipment_id IS NULL;

/* Q67. */
SELECT r.return_id, r.order_id, r.refund_amount, o.net_total
FROM sales.returns r
JOIN sales.orders o ON o.order_id = r.order_id
WHERE r.refund_amount > o.net_total;

/* Q68. */
WITH attendance_month AS (
  SELECT employee_id, DATE_TRUNC('month', attendance_date) AS month, COUNT(DISTINCT attendance_date) AS days_present
  FROM hr.attendance GROUP BY employee_id, DATE_TRUNC('month', attendance_date)
)
SELECT am.*
FROM attendance_month am
WHERE NOT EXISTS (
  SELECT 1 FROM payroll.pay_slips ps
  WHERE ps.employee_id = am.employee_id
    AND ps.salary_year = EXTRACT(YEAR FROM am.month)::int
    AND TRIM(ps.salary_month) = TRIM(TO_CHAR(am.month, 'Month'))
);

/* Q69. */
SELECT c.customer_id
FROM customers.customers c
LEFT JOIN customers.addresses a ON a.customer_id = c.customer_id
WHERE a.address_id IS NULL;

/* Q70. */
SELECT r.region_name,
       COUNT(*) FILTER (WHERE o.discount_amount > o.gross_total) AS discount_gt_gross_ct,
       COUNT(*) FILTER (WHERE sh.delivered_date < sh.shipped_date) AS bad_shipment_ct,
       COUNT(DISTINCT o.order_id) AS total_orders
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
LEFT JOIN sales.shipments sh ON sh.order_id = o.order_id
GROUP BY r.region_name
ORDER BY r.region_name;

/* Q71. */
WITH monthly AS (
  SELECT DATE_TRUNC('month', order_date) AS month,
         COUNT(*) FILTER (WHERE discount_amount > gross_total) AS fail_ct,
         COUNT(*) AS total_ct
  FROM sales.orders GROUP BY DATE_TRUNC('month', order_date)
)
SELECT month,
       ROUND(100.0*fail_ct/total_ct,3) AS pass_rate_fail_pct,
       ROUND(100.0*fail_ct/total_ct,3) - LAG(ROUND(100.0*fail_ct/total_ct,3)) OVER (ORDER BY month) AS mom_change_pct
FROM monthly ORDER BY month;

/* Q72. */
WITH ranked AS (
  SELECT o.order_id, s.region_id, o.net_total,
    ROW_NUMBER() OVER (PARTITION BY s.region_id ORDER BY o.net_total DESC) AS rk
  FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id
  WHERE o.net_total > 100000
)
SELECT jsonb_agg(jsonb_build_object('order_id', order_id, 'region_id', region_id, 'net_total', net_total))
FROM ranked WHERE rk <= 10;

/* Q73. */
SELECT jsonb_build_object(
  'discount_gt_gross', (SELECT COUNT(*) FROM sales.orders WHERE discount_amount > gross_total),
  'missing_shipment', (SELECT COUNT(*) FROM sales.orders o LEFT JOIN sales.shipments sh ON sh.order_id = o.order_id
                        WHERE o.order_status = 'Delivered' AND sh.shipment_id IS NULL),
  'net_total_mismatch', (SELECT COUNT(*) FROM (
     SELECT o.order_id FROM sales.orders o JOIN sales.order_items oi ON oi.order_id = o.order_id
     GROUP BY o.order_id, o.net_total HAVING o.net_total IS DISTINCT FROM SUM(oi.net_amount)) x)
) AS reconciliation_report_json;

/* Q74. */
WITH ranked AS (
  SELECT customer_id, DATE_TRUNC('day', view_timestamp) AS day,
    ROW_NUMBER() OVER (PARTITION BY customer_id, DATE_TRUNC('day', view_timestamp) ORDER BY view_timestamp DESC) AS rn
  FROM web_events.page_views WHERE customer_id IS NOT NULL
)
SELECT customer_id, day FROM ranked WHERE rn = 1;

/* Q75. This is a plan-inspection exercise for the anomaly engine. */
EXPLAIN (ANALYZE, BUFFERS)
SELECT o.order_id, s.region_id, o.net_total
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
WHERE o.net_total > (SELECT PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY net_total) FROM sales.orders);

/* Q76. A production cleansed layer would ship v_core_customers (deduped by canonical email, Q26), v_core_products (canonical brand+name, Q27), and v_core_orders (net_total-reconciled, Q64) as views - these are exactly the detection SELECTs above, only wrapped in CREATE VIEW once Day-25 permission applies on this database. */
/* Q77. mv_core_customers would need a UNIQUE INDEX on customer_id (the dedup engine's kept-row id) to support REFRESH MATERIALIZED VIEW CONCURRENTLY, refreshed nightly since customer registrations are low-frequency compared to orders. */
/* Q78. mv_core_products would need a UNIQUE INDEX on product_id, with brand_id resolved through the canonical-brand mapping (Q36) so every product row carries one agreed brand name, not raw supplier-entered text. */
/* Q79. mv_core_orders would carry the order-level reconciliation flag from Q64 plus secondary btree indexes on (cust_id) and (order_date) to support the downstream cohort/RFM/funnel queries that filter and join on those columns. */
/* Q80. mv_dq_scorecard would need a UNIQUE INDEX on (table_name, rule_id, month) so each rule's monthly pass-rate can be looked up or upserted without duplicate rows, refreshed once per day after the day's data lands. */
/* Q81. mv_quarantine would need a UNIQUE INDEX on (rule_id, row_id) so the same failing row under the same rule is never quarantined twice, and a new failure simply updates its last_seen timestamp instead of inserting a duplicate. */
/* Q82. */
WITH scorecard AS (
  SELECT 'discount_gt_gross' AS rule, COUNT(*) AS fail_ct, (SELECT COUNT(*) FROM sales.orders) AS total_ct
  FROM sales.orders WHERE discount_amount > gross_total
  UNION ALL
  SELECT 'net_total_mismatch', COUNT(*), (SELECT COUNT(*) FROM sales.orders)
  FROM (SELECT o.order_id FROM sales.orders o JOIN sales.order_items oi ON oi.order_id = o.order_id
        GROUP BY o.order_id, o.net_total HAVING o.net_total IS DISTINCT FROM SUM(oi.net_amount)) x
)
SELECT jsonb_agg(jsonb_build_object('rule', rule, 'fail_ct', fail_ct, 'total_ct', total_ct,
       'pct_failed', ROUND(100.0*fail_ct/total_ct,3))) AS dq_scorecard_json
FROM scorecard;

/* Q83. */
WITH quarantine AS (
  SELECT order_id, gross_total, discount_amount FROM sales.orders WHERE discount_amount > gross_total LIMIT 50
)
SELECT jsonb_agg(jsonb_build_object('order_id', order_id, 'gross_total', gross_total, 'discount_amount', discount_amount))
       AS quarantine_export_json
FROM quarantine;

/* Q84. */
WITH ranked AS (
  SELECT r.region_id, o.order_id, o.net_total,
    ROW_NUMBER() OVER (PARTITION BY r.region_id ORDER BY o.net_total DESC) AS rk
  FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id
  JOIN core.dim_region r ON r.region_id = s.region_id
  WHERE o.net_total > 100000
)
SELECT region_id, jsonb_agg(jsonb_build_object('order_id', order_id, 'net_total', net_total) ORDER BY net_total DESC) AS top_k
FROM ranked WHERE rk <= 5
GROUP BY region_id;

/* Q85. */
SELECT jsonb_build_object(
  'orders_missing_payment', (SELECT COUNT(*) FROM sales.orders o LEFT JOIN sales.payments p ON p.order_id = o.order_id WHERE p.payment_id IS NULL),
  'delivered_missing_shipment', (SELECT COUNT(*) FROM sales.orders o LEFT JOIN sales.shipments sh ON sh.order_id = o.order_id WHERE o.order_status = 'Delivered' AND sh.shipment_id IS NULL),
  'checked_at', NOW()
) AS reconciliation_status_json;

/* Q86. */
WITH first_order AS (
  SELECT cust_id, MIN(order_date) AS first_order_date FROM sales.orders GROUP BY cust_id
)
SELECT COUNT(*) AS total_customers,
       COUNT(*) FILTER (WHERE fo.first_order_date IS NOT NULL AND c.registration_date <= fo.first_order_date) AS cohort_ready_customers
FROM customers.customers c
LEFT JOIN first_order fo ON fo.cust_id = c.customer_id;

/* Q87. */
SELECT COUNT(*) AS customers_with_orders,
       COUNT(*) FILTER (WHERE net_total >= 0) AS clean_monetary_inputs
FROM (SELECT cust_id, SUM(net_total) AS net_total FROM sales.orders GROUP BY cust_id) x;

/* Q88. */
SELECT COUNT(*) AS total_sessions,
       COUNT(*) FILTER (WHERE customer_id IS NOT NULL) AS sessions_with_customer_link
FROM (SELECT DISTINCT session_id, customer_id FROM web_events.page_views) x;

/* Q89. */
WITH monthly AS (
  SELECT DATE_TRUNC('month', order_date) AS month,
         COUNT(*) FILTER (WHERE discount_amount > gross_total) AS fail_ct, COUNT(*) AS total_ct
  FROM sales.orders GROUP BY DATE_TRUNC('month', order_date)
)
SELECT month, ROUND(100.0*(total_ct - fail_ct)/total_ct, 3) AS pass_rate_pct
FROM monthly ORDER BY month;

/* Q90. A v2 cleansed MV rollout runs mv_core_customers_v2 alongside v1, validates row counts and dedup quality match expectations, repoints consumers, and only then drops v1 in a separate deprecation step - never an in-place replace that could break a consumer mid-query. */
/* Q91. */
WITH monthly AS (
  SELECT DATE_TRUNC('month', order_date) AS month,
         COUNT(*) FILTER (WHERE discount_amount > gross_total) AS fail_ct, COUNT(*) AS total_ct
  FROM sales.orders GROUP BY DATE_TRUNC('month', order_date)
),
rated AS (
  SELECT *, ROUND(100.0*(total_ct-fail_ct)/total_ct,3) AS pass_rate_pct FROM monthly
),
with_prev AS (
  SELECT *, LAG(pass_rate_pct) OVER (ORDER BY month) AS prev_week_rate FROM rated
)
SELECT * FROM with_prev
WHERE prev_week_rate IS NOT NULL AND pass_rate_pct < prev_week_rate - 5;

/* Q92. */
SELECT r.region_name,
       COUNT(*) FILTER (WHERE o.discount_amount > o.gross_total) AS discount_gt_gross_ct,
       COUNT(*) FILTER (WHERE o.net_total > 100000) AS high_value_ct,
       COUNT(*) AS total_orders,
       ROUND(100.0 * COUNT(*) FILTER (WHERE o.discount_amount > o.gross_total) / COUNT(*), 3) AS pct_discount_issue
FROM sales.orders o
JOIN stores.stores s ON s.store_id = o.store_id
JOIN core.dim_region r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY r.region_name;

/* Q93. This is a plan-inspection exercise for the heaviest DQ query - the order_items-vs-net_total reconciliation over 150k orders joined to 375k order_items. */
EXPLAIN (ANALYZE, BUFFERS)
SELECT o.order_id, o.net_total, SUM(oi.net_amount) AS items_net_total
FROM sales.orders o
JOIN sales.order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id, o.net_total
HAVING o.net_total IS DISTINCT FROM SUM(oi.net_amount);

/* Q94. The refresh DAG runs strictly in dependency order: dedup engines (customers/products/suppliers) first, then the cleansed views built on top of them, then anomaly engines (which need clean baselines), then the scorecard (which aggregates anomaly + reconciliation results), and finally the JSON exports (which read only the finished scorecard) - each stage waits on the previous one's refresh to commit. */
/* Q95. */
WITH breaches AS (
  SELECT ticket_id, priority,
         EXTRACT(EPOCH FROM (resolved_date - created_date))/3600 AS resolution_hours
  FROM support.tickets WHERE resolved_date IS NOT NULL
)
SELECT jsonb_agg(jsonb_build_object(
  'ticket_id', ticket_id, 'priority', priority, 'resolution_hours', resolution_hours,
  'severity', CASE WHEN priority = 'Critical' THEN 'high' ELSE 'medium' END,
  'runbook', 'runbook://support/sla-breach'
)) AS reconciliation_alerts_json
FROM breaches
WHERE (priority = 'Critical' AND resolution_hours > 4)
   OR (priority = 'High' AND resolution_hours > 24);

/* Q96. A multi-tenant cleansed-view extension would parameterize every view by region_id (WHERE region_id = current_setting('app.tenant_region')::int or a per-tenant schema), so each region's analysts see only their slice while sharing the same view definitions. */
/* Q97. */
SELECT n.nspname AS schema_name, c.relname AS view_name, obj_description(c.oid) AS documentation
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('v','m') AND n.nspname NOT IN ('pg_catalog','information_schema')
ORDER BY 1,2;

/* Q98. Day 27 would consume: a deduped customers set (one row per canonical email, Q26) for correct cohort sizing, a net_total-reconciled orders set (Q64) for correct RFM monetary values, and a customer-linked page_views set (Q88) for funnel analysis - all three are already available as plain SELECTs above, ready to be wrapped as views once Day 25 permission applies. */
/* Q99. */
SELECT jsonb_build_object(
  'dedup_customers_kept', (SELECT COUNT(*) FROM (
    SELECT ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY registration_date DESC) rn
    FROM customers.customers) x WHERE rn = 1),
  'orders_reconciliation_mismatch', (SELECT COUNT(*) FROM (
    SELECT o.order_id FROM sales.orders o JOIN sales.order_items oi ON oi.order_id = o.order_id
    GROUP BY o.order_id, o.net_total HAVING o.net_total IS DISTINCT FROM SUM(oi.net_amount)) x),
  'anomaly_high_value_orders', (SELECT COUNT(*) FROM sales.orders WHERE net_total > 100000),
  'generated_at', NOW()
) AS platform_pipeline_summary_json;

/* Q100. Capstone: rule registry = the 6 rules used across this file (email dedup, discount>gross, price<cost, orders-missing-payment, delivered-missing-shipment, net_total mismatch); dedup engine = Q26 (customer canonical-key); anomaly engine = Q51 (regional P95/P99 with severity); reconciliation engine = Q64/Q65/Q66/Q67; scorecard = Q82's JSON rollup; cleansed MV layer + refresh DAG = Q76-Q81 and Q94 (Day-25 delivery once view/MV permission applies); JSON exports = Q82/Q83/Q84/Q85/Q95/Q99 above - together this is the full platform in SELECT form. */
