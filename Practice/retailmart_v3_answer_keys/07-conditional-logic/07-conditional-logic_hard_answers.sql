/* ============================================================
   ANSWER KEY - Conditional Logic & Derived Columns (HARD LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* Q1.  Simple CASE compares one expression to literal values by equality (`CASE val WHEN X THEN ...`); Searched CASE evaluates a fully independent boolean condition per branch (`CASE WHEN cond THEN ...`), so it can mix columns/operators freely. */
/* Q2.  CASE evaluates its WHEN clauses strictly top-to-bottom and returns the result of the FIRST one that's TRUE - later branches (and their conditions/subqueries) are never evaluated once a match is found. */
/* Q3.  Because wrapping the column in CASE turns it into an opaque expression the planner can't map back to a direct index range scan on the raw column - it's the same non-sargable problem as wrapping a column in any function. */
/* Q4.  Yes - as long as every branch's type (and ELSE's) is the same or can be implicitly coerced to one common type, since the overall CASE expression must resolve to a single type. */
/* Q5.  NULL. */
/* Q6.  The first non-NULL value among a, b, c, d, scanned left to right - if all four are NULL, COALESCE itself returns NULL. */
/* Q7.  PostgreSQL promotes all the arguments to a single common type via implicit coercion, if one exists among their types; if no implicit conversion path exists across all of them, it raises a type error. */
/* Q8.  Wrap it in one more COALESCE with a literal default: `COALESCE(a, b, c, default_value)` - if a, b, c are all NULL, the result falls through to default_value instead of staying NULL. */
/* Q9.  The prime use case is guarding a DIVISION denominator: `x / NULLIF(denom, 0)` returns NULL instead of a runtime "division by zero" error when denom happens to be 0. */
/* Q10. Exactly for that reason - converting a zero into NULL makes it something the division operator treats as "no meaningful result" (NULL) rather than an illegal operation. */
/* Q11. Yes, identical result either way - CAST(x AS numeric) is the SQL-standard spelling, x::numeric is PostgreSQL's shorthand for the same cast. */
/* Q12. PostgreSQL raises a runtime error identifying the offending input value and the target type it couldn't be parsed into (e.g. "invalid input syntax for type integer"). */
/* Q13. Because CAST(col AS type) wraps the column in a conversion, turning it into a computed expression the planner can no longer map directly onto a plain index over the raw column - same non-sargable issue as any other function wrapping. */
/* Q14. Implicit casting happens automatically whenever PostgreSQL finds a safe, unambiguous conversion path (e.g. comparing an untyped text literal to a numeric column); it fails/requires an explicit cast when the conversion could be ambiguous, lossy, or there's no registered implicit cast between the two types at all. */
/* Q15. It does NOT fail in PostgreSQL - `'1' + 1` actually works because PostgreSQL resolves the untyped string literal '1' to an integer automatically in that numeric context (implicit coercion); stricter-typed dialects refuse this and demand an explicit cast. */
/* Q16. TRUE, FALSE, and UNKNOWN (what a NULL boolean effectively represents) - any expression touching a NULL typically evaluates to UNKNOWN rather than a definite TRUE/FALSE. */
/* Q17. If col1 is NULL, `NOT col1` is NULL, so `col AND NOT col1` becomes `col AND NULL` - that's NULL if col is TRUE or NULL, but FALSE if col is itself FALSE (FALSE AND anything is always FALSE, since AND short-circuits to FALSE once one side is known FALSE). */
/* Q18. `IS TRUE`/`IS FALSE` are definite three-valued-safe tests that never themselves return UNKNOWN (a NULL column IS TRUE evaluates to FALSE, not NULL); `IS UNKNOWN` specifically tests whether the boolean expression itself evaluated to NULL - needed when a row's NULL boolean state must be branched on explicitly rather than silently filtered out by WHERE. */
/* Q19. In PostgreSQL, GREATEST/LEAST simply SKIP NULL arguments and return the greatest/least of whatever non-NULL values remain, only returning NULL if every argument is NULL - so GREATEST(NULL, 5) is 5, not NULL; other dialects can differ and let one NULL argument poison the whole result. */
/* Q20. Neither sits "above" the other - COALESCE is really shorthand for one very common, specific CASE pattern (return the first non-NULL); CASE is the fully general tool that can express COALESCE's behavior plus arbitrarily more complex branching logic. */
/* Q21. `SUM(CASE WHEN cond THEN expr END)` turns each row into either a value (summed) or an implicit NULL (ignored by SUM) depending on the condition - stacking several of these side by side in one SELECT computes multiple different filtered totals in a single pass over the data. */
/* Q22. `ORDER BY CASE ... END` lets you assign a custom numeric sort rank per row based on arbitrary business logic (e.g. Critical=1, High=2, Medium=3), producing a priority order that a plain alphabetical or numeric sort on the raw column could never express. */
/* Q23. CASE in SELECT is evaluated per individual row, before any grouping; CASE (or a condition) in HAVING is evaluated after GROUP BY has collapsed rows into groups, so it can reference/filter on aggregate results like SUM() or COUNT() that don't exist at the per-row level. */
/* Q24. BOOL_AND and BOOL_OR are aggregate functions that reduce a whole group of boolean values to one TRUE/FALSE: BOOL_AND is TRUE only if EVERY row in the group is TRUE, BOOL_OR is TRUE if AT LEAST ONE row is TRUE. */
/* Q25. `CASE NULL WHEN NULL THEN ...` is a Simple CASE, which compares using `=` internally, and `NULL = NULL` evaluates to UNKNOWN (never TRUE) just like any other NULL comparison - it never matches, mirroring the general "x = NULL never works" rule; use a Searched CASE with `WHEN x IS NULL THEN ...` instead. */

/* Q26. */
SELECT order_id, net_total,
       CASE WHEN net_total < 100 THEN 'tiny'
            WHEN net_total < 500 THEN 'small'
            WHEN net_total < 2000 THEN 'medium'
            ELSE 'large' END AS size_bucket
FROM sales.orders;

/* Q27. */
SELECT ticket_id, priority, status,
       CASE WHEN priority = 'Critical' AND status = 'Open' THEN '1-act-now'
            WHEN priority = 'Critical' THEN '2-critical-other'
            WHEN priority = 'High' AND status = 'Open' THEN '3-high-open'
            WHEN status = 'Open' THEN '4-open-other'
            ELSE '5-handled' END AS action_queue
FROM support.tickets;

/* Q28. */
SELECT c.customer_id, m.tier_id, a.city,
       CASE WHEN m.tier_id >= 3 AND a.city = ANY (ARRAY['Mumbai', 'Delhi', 'New Delhi', 'Bengaluru', 'Chennai', 'Kolkata', 'Hyderabad']) THEN 'VIP-metro'
            WHEN a.city = ANY (ARRAY['Mumbai', 'Delhi', 'New Delhi', 'Bengaluru', 'Chennai', 'Kolkata', 'Hyderabad']) THEN 'Mid-metro'
            ELSE 'Other' END AS segment
FROM customers.customers c
LEFT JOIN loyalty.members m ON m.customer_id = c.customer_id
LEFT JOIN customers.addresses a ON a.customer_id = c.customer_id;

/* Q29. */
WITH brand_avg AS (SELECT brand_id, AVG(price) AS avg_price FROM products.products GROUP BY brand_id)
SELECT p.product_id, p.price, ba.avg_price,
       CASE WHEN p.price < 500 THEN 'Budget-' WHEN p.price < 5000 THEN 'Mid-' ELSE 'Premium-' END ||
       CASE WHEN ba.avg_price > 20000 THEN 'TopBrand' ELSE 'RegularBrand' END AS segment
FROM products.products p
JOIN brand_avg ba ON ba.brand_id = p.brand_id;

/* Q30. */
SELECT employee_id, role, joining_date,
       CASE WHEN EXTRACT(YEAR FROM AGE(joining_date)) >= 5 AND role LIKE '%Manager%' THEN 'Senior Leadership'
            WHEN EXTRACT(YEAR FROM AGE(joining_date)) >= 5 THEN 'Senior Staff'
            WHEN role LIKE '%Manager%' THEN 'Junior Leadership'
            ELSE 'Staff' END AS seniority_level
FROM stores.employees;

/* Q31. */
SELECT call_id, call_duration_seconds,
       CASE WHEN call_duration_seconds < 30 THEN 'short'
            WHEN call_duration_seconds < 180 THEN 'medium'
            ELSE 'long' END AS duration_bucket
FROM call_center.calls;

/* Q32. */
SELECT view_id, page_url,
       CASE WHEN page_url = '/home' THEN 'landing'
            WHEN page_url LIKE '/product/%' THEN 'product'
            WHEN page_url = '/checkout' THEN 'checkout'
            ELSE 'other' END AS visit_type
FROM web_events.page_views;

/* Q33. */
SELECT shipment_id,
       CASE WHEN delivered_date IS NULL THEN 'pending'
            WHEN delivered_date - shipped_date <= 3 THEN 'on_time'
            WHEN delivered_date - shipped_date <= 7 THEN 'late'
            ELSE 'very_late' END AS delivery_age
FROM sales.shipments;

/* Q34. */
SELECT pay_slip_id, basic_salary, net_salary,
       CASE WHEN net_salary > 1.1 * basic_salary THEN 'Eligible' ELSE 'Not Eligible' END AS bonus_eligibility
FROM payroll.pay_slips;

/* Q35. */
WITH spend_totals AS (SELECT campaign_id, SUM(amount) AS total_spend FROM marketing.ads_spend GROUP BY campaign_id)
SELECT c.campaign_id, c.budget, st.total_spend,
       CASE WHEN st.total_spend IS NULL OR st.total_spend = 0 THEN 'unknown'
            WHEN c.budget / NULLIF(st.total_spend, 0) > 2 THEN 'high'
            WHEN c.budget / NULLIF(st.total_spend, 0) > 1 THEN 'med'
            ELSE 'low' END AS roi_band
FROM marketing.campaigns c
LEFT JOIN spend_totals st ON st.campaign_id = c.campaign_id;

/* Q36. */
SELECT review_id, rating, LENGTH(review_text) AS review_len,
       CASE WHEN rating >= 4 AND LENGTH(review_text) > 50 THEN 'Detailed Positive'
            WHEN rating >= 4 THEN 'Positive'
            WHEN rating <= 2 AND LENGTH(review_text) > 50 THEN 'Detailed Negative'
            WHEN rating <= 2 THEN 'Negative'
            ELSE 'Neutral' END AS sentiment
FROM customers.reviews;

/* Q37. */
SELECT warehouse_id, product_id, snapshot_date, quantity_on_hand,
       CASE WHEN quantity_on_hand < 50 THEN 'low'
            WHEN quantity_on_hand < 500 THEN 'healthy'
            ELSE 'excess' END AS stock_status
FROM supply_chain.inventory_snapshots;

/* Q38. */
SELECT m.customer_id, t.tier_name,
       CASE WHEN t.tier_name = 'Bronze' AND m.join_date >= CURRENT_DATE - 90 THEN 'Bronze new'
            WHEN t.tier_name = 'Bronze' THEN 'Bronze active'
            WHEN t.tier_name = 'Silver' THEN 'Silver active'
            WHEN t.tier_name = 'Gold' THEN 'Gold active'
            WHEN t.tier_name = 'Platinum' THEN 'Platinum elite' END AS member_status
FROM loyalty.members m
JOIN loyalty.tiers t ON t.tier_id = m.tier_id;

/* Q39. */
SELECT campaign_id, start_date, end_date,
       CASE WHEN start_date > CURRENT_DATE THEN 'planning'
            WHEN end_date >= CURRENT_DATE THEN 'active'
            WHEN end_date >= CURRENT_DATE - 30 THEN 'completed'
            ELSE 'closed' END AS lifecycle
FROM marketing.campaigns;

/* Q40. */
WITH reorder AS (SELECT product_id, AVG(reorder_level) AS avg_reorder FROM products.inventory GROUP BY product_id)
SELECT s.warehouse_id, s.product_id, s.snapshot_date, s.quantity_on_hand,
       CASE WHEN s.quantity_on_hand < COALESCE(r.avg_reorder, 0) THEN 'risk' ELSE 'ok' END AS risk_flag
FROM supply_chain.inventory_snapshots s
LEFT JOIN reorder r ON r.product_id = s.product_id;

/* Q41. */
WITH last_order AS (SELECT cust_id, MAX(order_date) AS last_order_date FROM sales.orders GROUP BY cust_id)
SELECT c.customer_id, lo.last_order_date,
       CASE WHEN lo.last_order_date IS NULL THEN 'never_ordered'
            WHEN lo.last_order_date >= CURRENT_DATE - 30 THEN 'active'
            WHEN lo.last_order_date >= CURRENT_DATE - 90 THEN 'dormant'
            ELSE 'churned' END AS lifecycle_stage
FROM customers.customers c
LEFT JOIN last_order lo ON lo.cust_id = c.customer_id;

/* Q42. */
WITH cust_store AS (
  SELECT DISTINCT ON (o.cust_id) o.cust_id, s.region_id, s.city
  FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id
  ORDER BY o.cust_id, o.order_id DESC
)
SELECT c.customer_id, r.region_name, cs.city, c.tier,
       CASE WHEN r.region_name = 'North' THEN
              CASE WHEN cs.city = 'Delhi' THEN
                     CASE WHEN c.tier = 'Platinum' THEN 'North-Delhi-Platinum' ELSE 'North-Delhi-Other' END
                   ELSE 'North-Other-City' END
            ELSE 'Other-Region' END AS nested_label
FROM customers.customers c
LEFT JOIN cust_store cs ON cs.cust_id = c.customer_id
LEFT JOIN core.dim_region r ON r.region_id = cs.region_id;

/* Q43. */
SELECT return_id, reason,
       CASE WHEN reason = 'Defective' THEN 'product issue'
            WHEN reason = 'Size issue' THEN 'product issue'
            WHEN reason = 'Wrong Item' THEN 'wrong item'
            ELSE 'other' END AS reason_category
FROM sales.returns;

/* Q44. */
SELECT call_id, call_start_time,
       CASE WHEN EXTRACT(HOUR FROM call_start_time) < 6 THEN 'night'
            WHEN EXTRACT(HOUR FROM call_start_time) < 12 THEN 'morning'
            WHEN EXTRACT(HOUR FROM call_start_time) < 18 THEN 'afternoon'
            ELSE 'evening' END AS shift
FROM call_center.calls;

/* Q45. */
SELECT order_id, order_date,
       CASE WHEN EXTRACT(MONTH FROM order_date) IN (10, 11, 12) THEN 'Festive'
            WHEN EXTRACT(MONTH FROM order_date) IN (4, 5, 6) THEN 'Summer'
            ELSE 'Regular' END AS seasonality
FROM sales.orders;

/* Q46. */
SELECT c.call_id, t.ticket_id
FROM call_center.calls c
JOIN support.tickets t ON t.customer_id = c.customer_id
 AND CASE WHEN c.call_reason = 'Complaint' THEN t.category = 'Product Defect' ELSE TRUE END;

/* Q47. */
SELECT * FROM support.tickets
ORDER BY CASE priority WHEN 'Critical' THEN 1 WHEN 'High' THEN 2 WHEN 'Medium' THEN 3 WHEN 'Low' THEN 4 ELSE 5 END;

/* Q48. */
SELECT CASE WHEN net_total < 1000 THEN 'small' WHEN net_total < 10000 THEN 'medium' ELSE 'large' END AS revenue_bucket,
       COUNT(*), SUM(net_total)
FROM sales.orders
GROUP BY revenue_bucket;

/* Q49. */
SELECT SUM(CASE WHEN order_status = 'Delivered' THEN net_total END) AS delivered_total FROM sales.orders;

/* Q50. */
SELECT order_id,
       CASE WHEN net_total > 10000 THEN jsonb_build_object('tier', 'high', 'order_id', order_id)
            ELSE jsonb_build_object('tier', 'normal', 'order_id', order_id) END AS order_json
FROM sales.orders;

/* Q51. */
SELECT c.customer_id, COALESCE(m.tier_id, 0) AS effective_tier_id
FROM customers.customers c
LEFT JOIN loyalty.members m ON m.customer_id = c.customer_id;

/* Q52. */
SELECT c.customer_id, COALESCE(a.city, 'Unknown') AS city
FROM customers.customers c
LEFT JOIN customers.addresses a ON a.customer_id = c.customer_id;

/* Q53. */
WITH units AS (SELECT order_id, SUM(quantity) AS total_units FROM sales.order_items GROUP BY order_id)
SELECT o.order_id, o.net_total / NULLIF(u.total_units, 0) AS avg_unit_value
FROM sales.orders o
LEFT JOIN units u ON u.order_id = o.order_id;

/* Q54. */
SELECT
  (SELECT COUNT(*) FROM web_events.page_views) AS visits,
  (SELECT COUNT(*) FROM sales.orders) AS orders,
  (SELECT COUNT(*) FROM web_events.page_views)::numeric / NULLIF((SELECT COUNT(*) FROM sales.orders), 0) AS visits_per_order;

/* Q55. */
SELECT customer_id, COALESCE(phone, 'No phone') AS contact_phone FROM customers.customers;

/* Q56. */
SELECT c.customer_id,
       COALESCE(m.tier_id, CASE c.tier WHEN 'Bronze' THEN 1 WHEN 'Silver' THEN 2 WHEN 'Gold' THEN 3 WHEN 'Platinum' THEN 4 END, 1) AS effective_tier_id
FROM customers.customers c
LEFT JOIN loyalty.members m ON m.customer_id = c.customer_id;

/* Q57. */
SELECT customer_id, COALESCE(EXTRACT(YEAR FROM AGE(registration_date)), 0) AS tenure_years FROM customers.customers;

/* Q58. */
SELECT v, CASE WHEN v ~ '^\d{4}-\d{2}-\d{2}$' THEN v::date ELSE NULL END AS parsed
FROM (VALUES ('2025-01-15'), ('not-a-date'), ('2025/01/15')) AS t(v);

/* Q59. */
SELECT v, REGEXP_REPLACE(v, '[^0-9.]', '', 'g')::NUMERIC AS parsed_price
FROM (VALUES ('$1,234.50'), ('Rs999.00'), ('45.00')) AS t(v);

/* Q60. */
SELECT v, CASE WHEN v ~ '^\d{1,3}(\.\d{1,3}){3}$' THEN v::inet ELSE NULL END AS parsed_ip
FROM (VALUES ('192.168.1.1'), ('not-an-ip'), ('10.0.0.5')) AS t(v);

/* Q61. */
SELECT c.customer_id, o.order_id
FROM customers.customers c
LEFT JOIN sales.orders o ON (CASE WHEN o.order_status IN ('Processing', 'Shipped') THEN o.cust_id END) = c.customer_id;

/* Q62. */
SELECT * FROM customers.customers WHERE tier_updated_at IS DISTINCT FROM registration_date::timestamp;

/* Q63. */
SELECT * FROM sales.shipments WHERE delivered_date IS NOT DISTINCT FROM shipped_date;

/* Q64. */
SELECT store_id, BOOL_OR(order_status = 'Delivered') AS any_delivered FROM sales.orders GROUP BY store_id;

/* Q65. */
SELECT product_id, BOOL_AND(rating >= 3) AS all_good_reviews FROM customers.reviews GROUP BY product_id;

/* Q66. */
SELECT 100.0 * COUNT(*) FILTER (WHERE order_status = 'Delivered') / NULLIF(COUNT(*), 0) AS pct_delivered FROM sales.orders;

/* Q67. */
SELECT ticket_id, NULLIF(subject, '') AS subject FROM support.tickets;

/* Q68. */
SELECT product_id, price / NULLIF(cost_price, 0) AS price_to_cost_ratio FROM products.products;

/* Q69. */
SELECT v, CASE WHEN v ~ '^-?\d+(\.\d+)?$' THEN v::numeric ELSE NULL END AS parsed
FROM (VALUES ('123'), ('123abc'), ('45.6')) AS t(v);

/* Q70. */
SELECT employee_id, salary, GREATEST(salary, 15000) AS floored_salary FROM stores.employees;

/* Q71. */
SELECT promo_id, end_date, LEAST(end_date, '2026-12-31'::date) AS capped_end_date FROM products.promotions;

/* Q72. */
SELECT BOOL_AND(v) AS all_true FROM (VALUES (TRUE), (NULL)) AS t(v);

/* Q73. */
SELECT * FROM customers.customers WHERE (tier = 'Gold') IS NOT TRUE;

/* Q74. */
SELECT ticket_id, NULLIF(NULLIF(subject, ''), 'N/A') AS subject_clean FROM support.tickets;

/* Q75. */
SELECT GREATEST(NULL::int, 5) AS greatest_result;

/* Q76. */
WITH stats AS (SELECT cust_id, COUNT(*) AS lifetime_orders FROM sales.orders GROUP BY cust_id)
SELECT c.customer_id, m.points_balance, COALESCE(s.lifetime_orders, 0) AS lifetime_orders, m.tier_id,
       COALESCE(m.points_balance, 0) * 0.5 + COALESCE(s.lifetime_orders, 0) * 1 + COALESCE(m.tier_id, 0) * 100 AS vip_score
FROM customers.customers c
LEFT JOIN loyalty.members m ON m.customer_id = c.customer_id
LEFT JOIN stats s ON s.cust_id = c.customer_id;

/* Q77. */
WITH stats AS (SELECT cust_id, COUNT(*) AS lifetime_orders FROM sales.orders GROUP BY cust_id)
SELECT c.customer_id,
       CASE WHEN COALESCE(m.points_balance, 0) > 1000 AND COALESCE(s.lifetime_orders, 0) > 20 THEN 'Gold'
            ELSE COALESCE(c.tier, 'Bronze') END AS suggested_tier
FROM customers.customers c
LEFT JOIN loyalty.members m ON m.customer_id = c.customer_id
LEFT JOIN stats s ON s.cust_id = c.customer_id;

/* Q78. */
SELECT ticket_id, GREATEST(100 - EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600 * 5, 0) AS risk_score
FROM support.tickets WHERE resolved_date IS NOT NULL;

/* Q79. */
SELECT o.order_id, o.net_total, c.registration_date,
       CASE WHEN o.net_total > 50000 AND c.registration_date >= o.order_date - 30 THEN 'FLAG' ELSE 'OK' END AS fraud_flag
FROM sales.orders o
JOIN customers.customers c ON c.customer_id = o.cust_id;

/* Q80. */
WITH last_order AS (SELECT cust_id, MAX(order_date) AS last_order_date FROM sales.orders GROUP BY cust_id)
SELECT c.customer_id,
       CASE WHEN lo.last_order_date < CURRENT_DATE - 90 AND c.tier = 'Bronze' THEN 'High Churn Risk' ELSE 'OK' END AS churn_risk
FROM customers.customers c
LEFT JOIN last_order lo ON lo.cust_id = c.customer_id;

/* Q81. */
WITH velocity AS (
  SELECT oi.prod_id, SUM(oi.quantity) / 4.0 AS weekly_velocity
  FROM sales.order_items oi JOIN sales.orders o ON o.order_id = oi.order_id
  WHERE o.order_date >= CURRENT_DATE - 28
  GROUP BY oi.prod_id
), stock AS (
  SELECT product_id, SUM(quantity_on_hand) AS total_stock FROM products.inventory GROUP BY product_id
)
SELECT p.product_id,
       CASE WHEN COALESCE(s.total_stock, 0) < 50 AND COALESCE(v.weekly_velocity, 0) > 5 THEN 'Reorder' ELSE 'OK' END AS reorder_flag
FROM products.products p
LEFT JOIN stock s ON s.product_id = p.product_id
LEFT JOIN velocity v ON v.prod_id = p.product_id;

/* Q82. */
WITH perf AS (
  SELECT agent_id,
         COUNT(*) FILTER (WHERE status = 'Resolved') AS tickets_resolved,
         COUNT(*) FILTER (WHERE status = 'Open') AS open_tickets
  FROM support.tickets GROUP BY agent_id
)
SELECT agent_id, tickets_resolved, open_tickets, tickets_resolved * 2 - open_tickets * 3 AS performance_score
FROM perf;

/* Q83. */
SELECT shipment_id, GREATEST(100 - (delivered_date - shipped_date) * 10, 0) AS efficiency_score
FROM sales.shipments WHERE delivered_date IS NOT NULL;

/* Q84. */
WITH spend AS (SELECT campaign_id, SUM(amount) AS total_spend FROM marketing.ads_spend GROUP BY campaign_id)
SELECT c.campaign_id, c.budget, s.total_spend,
       (c.budget - COALESCE(s.total_spend, 0)) / NULLIF(s.total_spend, 0) AS roi,
       CASE WHEN (c.budget - COALESCE(s.total_spend, 0)) / NULLIF(s.total_spend, 0) > 1 THEN 'high'
            WHEN (c.budget - COALESCE(s.total_spend, 0)) / NULLIF(s.total_spend, 0) > 0 THEN 'med'
            ELSE 'low' END AS roi_bucket
FROM marketing.campaigns c
LEFT JOIN spend s ON s.campaign_id = c.campaign_id;

/* Q85. */
WITH o AS (SELECT cust_id, COUNT(*) AS n FROM sales.orders GROUP BY cust_id),
     r AS (SELECT customer_id, COUNT(*) AS n FROM customers.reviews GROUP BY customer_id),
     t AS (SELECT customer_id, COUNT(*) AS n FROM support.tickets GROUP BY customer_id)
SELECT c.customer_id, COALESCE(o.n, 0) * 2 + COALESCE(r.n, 0) * 1 - COALESCE(t.n, 0) * 1 AS health_index
FROM customers.customers c
LEFT JOIN o ON o.cust_id = c.customer_id
LEFT JOIN r ON r.customer_id = c.customer_id
LEFT JOIN t ON t.customer_id = c.customer_id;

/* Q86. */
SELECT product_id, (price - cost_price) / NULLIF(cost_price, 0) AS profitability,
       CASE WHEN (price - cost_price) / NULLIF(cost_price, 0) > 1 THEN 'high'
            WHEN (price - cost_price) / NULLIF(cost_price, 0) > 0.3 THEN 'med'
            ELSE 'low' END AS profitability_tier
FROM products.products;

/* Q87. */
WITH store_stats AS (
  SELECT o.store_id, SUM(o.net_total) AS revenue, COUNT(DISTINCT o.order_id) AS orders
  FROM sales.orders o GROUP BY o.store_id
),
store_reviews AS (
  SELECT o.store_id, AVG(r.rating) AS avg_review
  FROM sales.orders o
  JOIN sales.order_items oi ON oi.order_id = o.order_id
  JOIN customers.reviews r ON r.product_id = oi.prod_id
  GROUP BY o.store_id
)
SELECT s.store_id, ss.revenue, ss.orders, sr.avg_review,
       ss.revenue * 0.5 + ss.orders * 0.3 + COALESCE(sr.avg_review, 0) * 100 AS performance_index
FROM stores.stores s
LEFT JOIN store_stats ss ON ss.store_id = s.store_id
LEFT JOIN store_reviews sr ON sr.store_id = s.store_id;

/* Q88. */
WITH cogs AS (
  SELECT oi.prod_id, SUM(oi.quantity * p.cost_price) AS total_cogs
  FROM sales.order_items oi JOIN products.products p ON p.product_id = oi.prod_id
  GROUP BY oi.prod_id
), inv AS (
  SELECT product_id, AVG(quantity_on_hand) AS avg_inventory FROM products.inventory GROUP BY product_id
)
SELECT p.product_id, c.total_cogs, i.avg_inventory,
       c.total_cogs / NULLIF(i.avg_inventory, 0) AS turnover_ratio,
       CASE WHEN c.total_cogs / NULLIF(i.avg_inventory, 0) < 1 THEN 'slow-moving'
            WHEN c.total_cogs / NULLIF(i.avg_inventory, 0) > 10 THEN 'fast-moving-risk-stockout'
            ELSE 'healthy' END AS turnover_health
FROM products.products p
LEFT JOIN cogs c ON c.prod_id = p.product_id
LEFT JOIN inv i ON i.product_id = p.product_id;

/* Q89. */
SELECT agent_id,
       COUNT(*) FILTER (WHERE status = 'Open') AS open_tickets,
       COUNT(*) FILTER (WHERE status = 'Open' AND priority IN ('High', 'Critical')) AS urgent_tickets,
       COUNT(*) FILTER (WHERE status = 'Open') + COUNT(*) FILTER (WHERE status = 'Open' AND priority IN ('High', 'Critical')) * 3 AS workload_score
FROM support.tickets
GROUP BY agent_id;

/* Q90. */
WITH o AS (SELECT cust_id, COUNT(*) AS n FROM sales.orders GROUP BY cust_id),
     r AS (SELECT customer_id, COUNT(*) AS n FROM customers.reviews GROUP BY customer_id),
     t AS (SELECT customer_id, COUNT(*) AS n FROM support.tickets GROUP BY customer_id),
     cl AS (SELECT customer_id, COUNT(*) AS n FROM call_center.calls GROUP BY customer_id)
SELECT c.customer_id,
       COALESCE(o.n, 0) * 3 + COALESCE(r.n, 0) * 2 + COALESCE(t.n, 0) * 1 + COALESCE(cl.n, 0) * 1 AS engagement_score
FROM customers.customers c
LEFT JOIN o ON o.cust_id = c.customer_id
LEFT JOIN r ON r.customer_id = c.customer_id
LEFT JOIN t ON t.customer_id = c.customer_id
LEFT JOIN cl ON cl.customer_id = c.customer_id;

/* Q91. */
WITH last_order AS (SELECT cust_id, MAX(order_date) AS last_order_date FROM sales.orders GROUP BY cust_id),
     open_t AS (SELECT customer_id, COUNT(*) AS n FROM support.tickets WHERE resolved_date IS NULL GROUP BY customer_id)
SELECT c.customer_id,
       CASE WHEN lo.last_order_date < CURRENT_DATE - 90 THEN 'call'
            WHEN COALESCE(ot.n, 0) > 2 THEN 'support'
            ELSE 'none' END AS next_best_action
FROM customers.customers c
LEFT JOIN last_order lo ON lo.cust_id = c.customer_id
LEFT JOIN open_t ot ON ot.customer_id = c.customer_id;

/* Q92. */
SELECT employee_id, CASE WHEN EXTRACT(YEAR FROM AGE(joining_date)) >= 3 AND salary < 80000 THEN 'Eligible' ELSE 'Not Eligible' END AS promotion_eligibility
FROM stores.employees;

/* Q93. */
SELECT m.customer_id, m.points_balance,
       GREATEST((SELECT MIN(min_points) FROM loyalty.tiers WHERE min_points > m.points_balance) - m.points_balance, 0) AS points_to_next_tier
FROM loyalty.members m;

/* Q94. */
WITH ltv AS (SELECT cust_id, SUM(net_total) AS total_spend FROM sales.orders GROUP BY cust_id)
SELECT r.return_id, o.cust_id, l.total_spend,
       CASE WHEN l.total_spend > 50000 AND r.refund_amount < 5000 THEN 'auto-approve' ELSE 'manual-review' END AS refund_decision
FROM sales.returns r
JOIN sales.orders o ON o.order_id = r.order_id
LEFT JOIN ltv l ON l.cust_id = o.cust_id;

/* Q95. */
SELECT o.order_id, c.tier, oi.unit_price,
       CASE WHEN c.tier IN ('Gold', 'Platinum') THEN 2
            WHEN oi.unit_price > 5000 THEN 3
            ELSE 5 END AS sla_days
FROM sales.orders o
JOIN customers.customers c ON c.customer_id = o.cust_id
JOIN sales.order_items oi ON oi.order_id = o.order_id;

/* Q96. */
SELECT order_id, net_total,
       CASE WHEN net_total > 20000 THEN '15%'
            WHEN net_total > 10000 THEN '10%'
            WHEN net_total > 5000 THEN '5%'
            ELSE '0%' END AS discount_tier
FROM sales.orders;

/* Q97. */
SELECT store_id, city,
       CASE WHEN city = ANY (ARRAY['Mumbai', 'Delhi', 'New Delhi', 'Bengaluru', 'Chennai', 'Kolkata', 'Hyderabad']) THEN 50
            ELSE 100 END AS shipping_cost
FROM stores.stores;

/* Q98. */
WITH monthly AS (
  SELECT cust_id,
         COUNT(*) / GREATEST(EXTRACT(MONTH FROM AGE(MAX(order_date), MIN(order_date))) + 1, 1) AS avg_monthly_orders,
         AVG(net_total) AS avg_basket
  FROM sales.orders GROUP BY cust_id
)
SELECT cust_id, avg_monthly_orders, avg_basket,
       CASE WHEN avg_monthly_orders > 3 AND avg_basket > 5000 THEN 'Premium'
            WHEN avg_monthly_orders > 1 THEN 'Standard'
            ELSE 'Basic' END AS subscription_tier
FROM monthly;

/* Q99. */
WITH stats AS (
  SELECT o.cust_id, COUNT(DISTINCT o.order_id) AS orders, COUNT(DISTINCT r.return_id) AS refunds
  FROM sales.orders o LEFT JOIN sales.returns r ON r.order_id = o.order_id
  GROUP BY o.cust_id
)
SELECT cust_id, orders, refunds, orders::numeric / NULLIF(refunds, 0) AS order_refund_ratio,
       CASE WHEN refunds = 0 THEN 'Excellent'
            WHEN orders::numeric / NULLIF(refunds, 0) > 5 THEN 'Good'
            ELSE 'Poor' END AS credit_equivalent
FROM stats;

/* Q100. */
WITH o AS (SELECT cust_id, COUNT(*) AS n, SUM(net_total) AS rev, MAX(order_date) AS last_order FROM sales.orders GROUP BY cust_id),
     r AS (SELECT customer_id, COUNT(*) AS n, AVG(rating) AS avg_rating FROM customers.reviews GROUP BY customer_id),
     t AS (SELECT customer_id, COUNT(*) AS n FROM support.tickets GROUP BY customer_id)
SELECT c.customer_id, c.tier,
       COALESCE(o.n, 0) AS total_orders,
       COALESCE(o.rev, 0) AS total_revenue,
       CASE WHEN o.last_order >= CURRENT_DATE - 30 THEN 'Active' ELSE 'Inactive' END AS activity_status,
       COALESCE(r.n, 0) AS review_count,
       COALESCE(r.avg_rating, 0) AS avg_rating,
       COALESCE(t.n, 0) AS ticket_count,
       CASE WHEN COALESCE(o.rev, 0) > 100000 THEN 'High Value' WHEN COALESCE(o.rev, 0) > 20000 THEN 'Mid Value' ELSE 'Low Value' END AS value_segment,
       CASE WHEN c.tier IN ('Gold', 'Platinum') THEN 'Premium' ELSE 'Standard' END AS tier_segment
FROM customers.customers c
LEFT JOIN o ON o.cust_id = c.customer_id
LEFT JOIN r ON r.customer_id = c.customer_id
LEFT JOIN t ON t.customer_id = c.customer_id;

/* ============================================================
   END OF ANSWER KEY - HARD LEVEL (100/100)
============================================================ */
