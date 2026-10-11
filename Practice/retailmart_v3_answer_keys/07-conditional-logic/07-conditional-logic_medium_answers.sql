/* ============================================================
   ANSWER KEY - Conditional Logic & Derived Columns (MEDIUM LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* Q1.  CASE in WHERE builds a dynamic filtering condition (used sparingly - it often defeats index usage); CASE in SELECT computes a derived, per-row display/label column, which is by far the more common use. */
/* Q2.  Simple CASE compares one expression to literal values by equality (`CASE tier WHEN 'Gold' THEN ...`); Searched CASE evaluates independent boolean conditions per branch (`CASE WHEN price > 1000 THEN ...`), so different columns/operators can be tested in each WHEN. */
/* Q3.  No - every WHEN branch (and ELSE) must resolve to one common, compatible result type, since the whole CASE expression itself has a single type; incompatible, non-castable types raise an error. */
/* Q4.  It computes a conditional (filtered) sum: net_total is added only for rows where the condition is TRUE; rows where it's FALSE/doesn't match contribute an implicit NULL to the CASE, and SUM() simply ignores NULLs. */
/* Q5.  They're equivalent for a plain "first non-NULL wins" fallback chain; COALESCE is shorter and clearer for that specific case, while the CASE form is only needed when the fallback logic needs extra conditions beyond simple NULL-checking. */
/* Q6.  Because it converts a zero denominator into NULL first, so `numerator / NULLIF(x, 0)` returns NULL instead of PostgreSQL raising a "division by zero" runtime error. */
/* Q7.  Yes - identical result; CAST('12.5' AS INT) and '12.5'::INT both fail the same way, since INT cannot silently hold a fractional value from a text cast (you'd cast to NUMERIC/FLOAT first, then to INT to round). */
/* Q8.  `::` is PostgreSQL's own shorthand cast operator; `CAST(x AS TYPE)` is the SQL-standard, portable syntax - functionally identical, but CAST works unchanged if you ever move to another database. */
/* Q9.  Because 13 is not a valid month (1-12) - DATE validates each of its components, and PostgreSQL raises an error for an out-of-range field rather than silently wrapping it into the next year. */
/* Q10. If the branches are truly incompatible with no implicit conversion path, PostgreSQL raises an error rather than guessing; if one side has an implicit cast to the other (e.g. an integer literal into a compatible numeric-ish text context), it silently promotes to the common type. */
/* Q11. CASE evaluates its WHEN clauses top-to-bottom and stops at the FIRST one that's TRUE - it does not evaluate every branch, so later branches' conditions/subqueries never even run once an earlier one matches. */
/* Q12. Because `x = NULL` always evaluates to UNKNOWN (never TRUE), so that WHEN branch can never fire even for rows where x genuinely is NULL - use `WHEN x IS NULL THEN 'a'` instead. */
/* Q13. COALESCE(a, b) returns the first non-NULL VALUE of the two; `a IS DISTINCT FROM b` returns a NULL-safe boolean comparing whether they differ - they're related in that both treat NULL specially (never propagating UNKNOWN), but one produces a value, the other a TRUE/FALSE. */
/* Q14. Because an empty string is a common "looks empty but technically isn't NULL" sentinel; `NULLIF(col, '')` converts it into a genuine NULL so downstream COALESCE/IS NULL logic treats blank and missing consistently. */
/* Q15. Two examples: comparing a numeric column to an untyped literal like `WHERE int_col = '5'` (the text literal is implicitly cast to match int_col's type), and inserting a numeric literal into a column of a different but compatible numeric type (e.g. an integer literal assigned into a NUMERIC(10,2) column). */
/* Q16. `col IS NULL` is a dedicated existence test that correctly identifies NULL rows; `col = NULL` always evaluates to UNKNOWN (excluded from WHERE) because NULL means "unknown", not a comparable value - so it never matches, even for actual NULLs. */
/* Q17. CAST(x AS TEXT)/x::TEXT give the type's plain default text representation with no formatting control; TO_CHAR(x, format) lets you dictate the exact display format (currency grouping, padding, custom date layout) - use CAST/:: for a quick raw conversion, TO_CHAR whenever presentation matters. */
/* Q18. It's NULL - a CASE with all-NULL branches and no ELSE still just falls through to NULL, exactly as if nothing matched at all. */
/* Q19. GREATEST(a, b, c) picks the largest of a fixed, explicit LIST of scalar expressions within a single row; MAX() is an aggregate that finds the largest VALUE across many ROWS within a group - same "biggest wins" idea, but one works across columns in a row, the other across rows. */
/* Q20. Yes - e.g. classify customers as "Premium" (outer CASE, tier-based) and then, only within that Premium branch, split further into "Loyal" vs "New Premium" by registration tenure (inner CASE) - nesting layers a second decision inside just one outcome of the first. */
/* Q21. PostgreSQL tries to promote all COALESCE arguments to one common type if an implicit cast path exists (e.g. INT alongside NUMERIC becomes NUMERIC); if the types are genuinely incompatible with no implicit conversion, it raises an error. */
/* Q22. CAST truncates silently when narrowing a value that still numerically fits (NUMERIC 12.99 -> INT drops the decimal to 12, no error); it raises an error when the source simply cannot be parsed/represented as the target type at all (TEXT 'abc' -> INT, or a NUMERIC value too large for INT's range). */
/* Q23. Because NULLIF(a, b) only returns NULL when a actually EQUALS b; here a is NULL and b is 0, and `NULL = 0` is UNKNOWN (never TRUE) - so the "equal" condition never holds, and NULLIF just passes its first argument through unchanged (still NULL). */
/* Q24. For a plain "first non-NULL wins" fallback chain, COALESCE reads far more clearly and concisely; reach for CASE only when the fallback logic needs conditions beyond simple NULL-checking. */
/* Q25. `CAST(price AS NUMERIC)` with no precision/scale keeps the value's FULL exact precision, which can carry more decimal places than expected or behave inconsistently across rows; `NUMERIC(10, 2)` pins down a fixed, predictable precision and scale appropriate for money, so results are consistent and bounded. */

/* Q26. */
SELECT customer_id, tier, registration_date,
       CASE WHEN tier IN ('Gold', 'Platinum') THEN
              CASE WHEN registration_date <= CURRENT_DATE - INTERVAL '3 years' THEN 'Loyal'
                   ELSE 'New Premium' END
            ELSE 'Standard' END AS segment
FROM customers.customers;

/* Q27. */
SELECT order_id, net_total, order_status,
       CASE WHEN net_total > 10000 AND order_status = 'Delivered' THEN 'A'
            WHEN net_total > 10000 THEN 'B'
            WHEN order_status = 'Delivered' THEN 'C'
            ELSE 'D' END AS bucket
FROM sales.orders;

/* Q28. */
SELECT product_id, brand_id, price,
       CASE WHEN brand_id IS NULL THEN 'Unknown brand'
            WHEN price < 100 THEN 'Cheap'
            WHEN price < 1000 THEN 'Mid'
            ELSE 'Premium' END AS bucket
FROM products.products;

/* Q29. */
SELECT employee_id, role,
       CASE WHEN role LIKE '%Manager%' THEN 'Mgr'
            WHEN role LIKE '%Engineer%' THEN 'Eng'
            ELSE 'Other' END AS role_group
FROM stores.employees;

/* Q30. */
SELECT order_id, order_date,
       CASE WHEN EXTRACT(DOW FROM order_date) IN (0, 6) THEN 'Weekend'
            ELSE TO_CHAR(order_date, 'FMDay') END AS day_label
FROM sales.orders;

/* Q31. */
WITH order_counts AS (
  SELECT cust_id, COUNT(*) AS n FROM sales.orders GROUP BY cust_id
)
SELECT c.customer_id,
       CASE WHEN c.tier IN ('Gold', 'Platinum')
                 AND c.registration_date <= CURRENT_DATE - INTERVAL '2 years'
                 AND COALESCE(oc.n, 0) > 10 THEN 'Champion'
            WHEN c.registration_date >= CURRENT_DATE - INTERVAL '90 days' THEN 'New'
            ELSE 'Regular' END AS lifecycle_stage
FROM customers.customers c
LEFT JOIN order_counts oc ON oc.cust_id = c.customer_id;

/* Q32. */
SELECT ticket_id, priority,
       CASE priority WHEN 'Critical' THEN 4 WHEN 'High' THEN 3 WHEN 'Medium' THEN 2 WHEN 'Low' THEN 1 ELSE 0 END AS severity_score
FROM support.tickets;

/* Q33. */
SELECT order_id, order_status, order_date,
       CASE WHEN order_status = 'Delivered' THEN 'Done'
            WHEN order_status = 'Processing' AND CURRENT_DATE - order_date > 7 THEN 'Urgent'
            WHEN order_status = 'Processing' THEN 'OK'
            ELSE 'Track' END AS urgency_label
FROM sales.orders;

/* Q34. */
SELECT SUM(CASE WHEN order_status = 'Delivered' THEN net_total END) AS delivered_revenue FROM sales.orders;

/* Q35. */
SELECT COUNT(CASE WHEN rating = 5 THEN 1 END) AS five_stars FROM customers.reviews;

/* Q36. */
SELECT employee_id, salary,
       CASE WHEN salary < 30000 THEN 'Junior'
            WHEN salary < 60000 THEN 'Mid'
            WHEN salary < 100000 THEN 'Senior'
            ELSE 'Executive' END AS bracket
FROM stores.employees;

/* Q37. */
SELECT shipment_id,
       CASE WHEN delivered_date IS NULL THEN 1
            WHEN delivered_date - shipped_date = 0 THEN 5
            WHEN delivered_date - shipped_date <= 2 THEN 4
            WHEN delivered_date - shipped_date <= 7 THEN 3
            ELSE 2 END AS safety_score
FROM sales.shipments;

/* Q38. */
SELECT review_id, rating, LENGTH(review_text) AS review_len,
       CASE WHEN rating = 5 AND LENGTH(review_text) > 50 THEN 'Detailed praise'
            WHEN rating = 5 THEN 'Quick like'
            WHEN rating <= 2 AND LENGTH(review_text) > 50 THEN 'Detailed complaint'
            WHEN rating <= 2 THEN 'Quick complaint'
            ELSE 'Neutral' END AS review_bucket
FROM customers.reviews;

/* Q39. */
SELECT SUM(CASE WHEN EXTRACT(DOW FROM order_date) IN (0, 6) THEN net_total END) AS weekend_revenue FROM sales.orders;

/* Q40. */
SELECT * FROM support.tickets
ORDER BY CASE priority WHEN 'Critical' THEN 1 WHEN 'High' THEN 2 WHEN 'Medium' THEN 3 WHEN 'Low' THEN 4 ELSE 5 END;

/* Q41. */
SELECT customer_id, tier,
       CASE tier WHEN 'Bronze' THEN 1 WHEN 'Silver' THEN 2 WHEN 'Gold' THEN 3 WHEN 'Platinum' THEN 4 END AS tier_rank
FROM customers.customers;

/* Q42. */
SELECT customer_id, tier || '-' || EXTRACT(YEAR FROM registration_date) AS label FROM customers.customers;

/* Q43. */
SELECT order_id, order_date,
       CASE WHEN EXTRACT(MONTH FROM order_date) BETWEEN 1 AND 3 THEN 'Q1'
            WHEN EXTRACT(MONTH FROM order_date) BETWEEN 4 AND 6 THEN 'Q2'
            WHEN EXTRACT(MONTH FROM order_date) BETWEEN 7 AND 9 THEN 'Q3'
            ELSE 'Q4' END AS quarter_label
FROM sales.orders;

/* Q44. */
WITH ship_min AS (
  SELECT order_id, MIN(delivered_date) AS min_delivered FROM sales.shipments GROUP BY order_id
)
SELECT o.order_id,
       CASE WHEN o.order_status = 'Delivered' THEN sm.min_delivered - o.order_date
            ELSE CURRENT_DATE - o.order_date END AS days_to_action
FROM sales.orders o
LEFT JOIN ship_min sm ON sm.order_id = o.order_id;

/* Q45. */
WITH paid AS (
  SELECT order_id, COALESCE(SUM(amount), 0) AS paid_amt FROM sales.payments GROUP BY order_id
)
SELECT o.order_id, o.net_total,
       CASE WHEN COALESCE(p.paid_amt, 0) >= o.net_total THEN 'Paid in Full'
            WHEN COALESCE(p.paid_amt, 0) > 0 THEN 'Partial'
            ELSE 'Unpaid' END AS paid_status
FROM sales.orders o
LEFT JOIN paid p ON p.order_id = o.order_id;

/* Q46. */
SELECT product_id, price, cost_price, GREATEST(price, cost_price, 100) AS greatest_val FROM products.products;

/* Q47. */
SELECT product_id, price, cost_price, LEAST(price, cost_price, 100) AS least_val FROM products.products;

/* Q48. */
WITH first_order AS (
  SELECT cust_id, MIN(order_id) AS first_id FROM sales.orders GROUP BY cust_id
)
SELECT o.order_id, o.cust_id,
       CASE WHEN o.order_id = fo.first_id THEN 'Y' ELSE 'N' END AS is_first_order
FROM sales.orders o
JOIN first_order fo ON fo.cust_id = o.cust_id;

/* Q49. */
SELECT attendance_id, check_in,
       CASE WHEN EXTRACT(HOUR FROM check_in) < 6 THEN 'Night'
            WHEN EXTRACT(HOUR FROM check_in) < 12 THEN 'Morning'
            WHEN EXTRACT(HOUR FROM check_in) < 18 THEN 'Day'
            ELSE 'Evening' END AS shift_label
FROM hr.attendance WHERE check_in IS NOT NULL;

/* Q50. */
SELECT ticket_id,
       CASE WHEN resolved_date IS NULL THEN NULL
            WHEN resolved_date - created_date <= INTERVAL '1 hour' THEN 'Fast'
            WHEN resolved_date::date = created_date::date THEN 'Same Day'
            ELSE 'Slow' END AS resolution_speed
FROM support.tickets;

/* Q51. */
SELECT customer_id, COALESCE(phone, email, 'NO CONTACT') AS contact FROM customers.customers;

/* Q52. */
SELECT shipment_id, COALESCE(delivered_date, shipped_date + 5, CURRENT_DATE) AS effective_date FROM sales.shipments;

/* Q53. */
SELECT m.customer_id, m.points_balance,
       COALESCE((SELECT MIN(t.min_points) FROM loyalty.tiers t WHERE t.min_points > m.points_balance), m.points_balance) AS next_tier_threshold
FROM loyalty.members m;

/* Q54. */
SELECT ticket_id, NULLIF(LENGTH(TRIM(subject)), 0) AS subject_len FROM support.tickets;

/* Q55. */
SELECT product_id, (price - cost_price) / NULLIF(price, 0) AS margin FROM products.products;

/* Q56. */
SELECT 100.0 * COUNT(*) FILTER (WHERE order_status = 'Delivered') / NULLIF(COUNT(*), 0) AS pct_delivered
FROM sales.orders;

/* Q57. */
SELECT customer_id, COALESCE(email, 'no-reply@retailmart.com') AS preferred_email FROM customers.customers;

/* Q58. */
SELECT NULLIF(TRIM(first_name), '') AS first_name, NULLIF(TRIM(last_name), '') AS last_name, NULLIF(TRIM(email), '') AS email
FROM customers.customers;

/* Q59. */
SELECT c.customer_id, COALESCE(t.tier_name, 'No Tier') AS effective_tier
FROM customers.customers c
LEFT JOIN loyalty.members m ON m.customer_id = c.customer_id
LEFT JOIN loyalty.tiers t ON t.tier_id = m.tier_id;

/* Q60. */
SELECT return_id, COALESCE(refund_amount, 0) AS refund_amount FROM sales.returns;

/* Q61. */
SELECT customer_id, COALESCE(tier, 'Standard') AS effective_tier FROM customers.customers;

/* Q62. */
SELECT SUM(COALESCE(refund_amount, 0)) AS total_refunds FROM sales.returns;

/* Q63. */
SELECT campaign_id, NULLIF(end_date, '9999-12-31') AS end_date FROM marketing.campaigns;

/* Q64. */
SELECT proc_name, COALESCE(input_params ->> 'city', 'unknown') AS city FROM audit.procedure_calls;

/* Q65. */
WITH first_store_city AS (
  SELECT DISTINCT ON (o.cust_id) o.cust_id, s.city
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  ORDER BY o.cust_id, o.order_id
)
SELECT c.customer_id, COALESCE(a.city, fsc.city, 'India') AS city
FROM customers.customers c
LEFT JOIN customers.addresses a ON a.customer_id = c.customer_id
LEFT JOIN first_store_city fsc ON fsc.cust_id = c.customer_id;

/* Q66. */
SELECT 'Hello ' || COALESCE(first_name, last_name, email, 'Guest') || '!' AS greeting FROM customers.customers;

/* Q67. */
SELECT customer_id, NULLIF(TRIM(email), '') AS email_clean FROM customers.customers;

/* Q68. */
SELECT payment_id, COALESCE(amount, 0) AS amount FROM sales.payments;

/* Q69. */
SELECT employee_id, COALESCE(store_id::TEXT, 'HQ') AS store_label FROM stores.employees;

/* Q70. */
SELECT customer_id, COALESCE(tier_updated_at, registration_date::timestamp) AS effective_change_date FROM customers.customers;

/* Q71. */
SELECT shipment_id, COALESCE(status, CASE WHEN shipped_date IS NOT NULL THEN 'In Transit' ELSE 'Unknown' END) AS effective_status
FROM sales.shipments;

/* Q72. */
SELECT ticket_id, COALESCE(category, 'General') AS effective_category FROM support.tickets;

/* Q73. */
SELECT expense_id, COALESCE(description, 'No description') AS description FROM finance.expenses;

/* Q74. */
SELECT request_id, COALESCE(user_agent, 'unknown') AS ua FROM audit.api_requests;

/* Q75. */
SELECT customer_id, COALESCE(NULLIF(TRIM(first_name), ''), 'Unknown') AS clean_first FROM customers.customers;

/* Q76. */
SELECT 'Order #' || order_id::TEXT || ' (Rs' || net_total::TEXT || ')' AS invoice_string FROM sales.orders;

/* Q77. */
SELECT product_id, price::NUMERIC(10,2) AS price_2dp FROM products.products;

/* Q78. */
SELECT view_timestamp::DATE AS view_date, COUNT(*) FROM web_events.page_views GROUP BY view_date ORDER BY view_date;

/* Q79. */
SELECT call_id, ('300 seconds')::INTERVAL AS demo_interval FROM call_center.calls;

/* Q80. */
SELECT attendance_id, check_in::DATE AS check_date, check_in::TIME AS check_time FROM hr.attendance WHERE check_in IS NOT NULL;

/* Q81. */
SELECT product_id, TO_CHAR(price, 'FM"Rs"99,99,999.00') AS price_display FROM products.products;

/* Q82. */
SELECT order_id, TO_CHAR(order_date, 'FMDay, DD Mon YYYY') AS friendly_date FROM sales.orders;

/* Q83. */
SELECT employee_id, EXTRACT(YEAR FROM AGE(joining_date))::INT AS age_in_years FROM stores.employees;

/* Q84. */
SELECT customer_id, COALESCE(NULLIF(TRIM(first_name || ' ' || last_name), ''), email, 'Customer #' || customer_id) AS display_name
FROM customers.customers;

/* Q85. */
SELECT product_id, price,
       CASE WHEN price < 100 THEN 'Cheap ($' || price::TEXT || ')'
            WHEN price < 1000 THEN 'Mid ($' || price::TEXT || ')'
            ELSE 'Premium ($' || price::TEXT || ')' END AS labeled_bucket
FROM products.products;

/* Q86. */
SELECT p.product_id,
       'PRODUCT-' || p.product_id::TEXT || ': ' || p.product_name || ' is ' ||
       CASE WHEN EXISTS (SELECT 1 FROM products.inventory i WHERE i.product_id = p.product_id AND i.quantity_on_hand > 0)
            THEN 'IN STOCK' ELSE 'OUT' END AS stock_line
FROM products.products p;

/* Q87. */
SELECT o.order_id, INITCAP(c.first_name || ' ' || c.last_name) AS customer_name,
       TO_CHAR(o.net_total, 'FM"Rs"99,99,999.00') AS net_total_fmt,
       UPPER(o.order_status) AS status,
       TO_CHAR(o.order_date, 'DD-Mon-YYYY') AS order_date_fmt
FROM sales.orders o
JOIN customers.customers c ON c.customer_id = o.cust_id;

/* Q88. */
SELECT 'AGING ' || (CURRENT_DATE - created_date::DATE)::TEXT || ' DAYS - PRIORITY ' || UPPER(priority) AS banner
FROM support.tickets WHERE resolved_date IS NULL;

/* Q89. */
SELECT c.customer_id, COALESCE(c.tier, 'Standard') AS tier,
       EXTRACT(YEAR FROM AGE(c.registration_date)) AS tenure_years,
       m.points_balance / NULLIF(EXTRACT(YEAR FROM AGE(c.registration_date)), 0) AS points_per_year
FROM customers.customers c
LEFT JOIN loyalty.members m ON m.customer_id = c.customer_id;

/* Q90. */
SELECT shipment_id,
       CASE WHEN delivered_date IS NULL AND CURRENT_DATE - shipped_date > 14 THEN 'HIGH RISK' ELSE 'OK' END AS risk_flag
FROM sales.shipments;

/* Q91. */
SELECT customer_id, points_balance::BIGINT AS points_balance_big FROM loyalty.members;

/* Q92. */
SELECT payment_id, COALESCE(amount, 0) AS amount,
       CASE WHEN payment_mode IN ('Cash', 'Credit Card', 'Debit Card') THEN 'In-Store' ELSE 'Online' END AS mode_group,
       TO_CHAR(payment_date, 'DD-Mon-YYYY') AS payment_date_fmt
FROM sales.payments;

/* Q93. */
SELECT return_id, CASE WHEN refund_amount IS NULL THEN CURRENT_DATE - return_date ELSE NULL END AS pending_days
FROM sales.returns;

/* Q94. */
WITH spend AS (
  SELECT cust_id, SUM(net_total) AS total_spend FROM sales.orders GROUP BY cust_id
)
SELECT c.customer_id,
       CASE WHEN COALESCE(s.total_spend, 0) > 100000 THEN 'High'
            WHEN COALESCE(s.total_spend, 0) > 20000 THEN 'Mid'
            ELSE 'Low' END AS spend_tier
FROM customers.customers c
LEFT JOIN spend s ON s.cust_id = c.customer_id;

/* Q95. */
SELECT a.employee_id, a.attendance_date,
       CASE WHEN a.check_in IS NULL THEN 'Absent'
            WHEN EXTRACT(HOUR FROM a.check_in) < 6 THEN 'Night'
            WHEN EXTRACT(HOUR FROM a.check_in) < 12 THEN 'Morning'
            WHEN EXTRACT(HOUR FROM a.check_in) < 18 THEN 'Day'
            ELSE 'Evening' END AS shift
FROM hr.attendance a;

/* Q96. */
SELECT product_id, ROUND(100.0 * (price - cost_price) / NULLIF(price, 0), 2) AS margin_pct FROM products.products;

/* Q97. */
SELECT pay_slip_id,
       ROUND(100.0 * basic_salary / NULLIF(gross_salary, 0), 2) AS basic_pct,
       ROUND(100.0 * hra / NULLIF(gross_salary, 0), 2) AS hra_pct,
       ROUND(100.0 * other_allowances / NULLIF(gross_salary, 0), 2) AS allowances_pct,
       ROUND(100.0 * (pf + professional_tax + income_tax) / NULLIF(gross_salary, 0), 2) AS taxes_pct,
       ROUND(100.0 * net_salary / NULLIF(gross_salary, 0), 2) AS net_pct
FROM payroll.pay_slips;

/* Q98. */
SELECT log_id, level,
       CASE level WHEN 'FATAL' THEN 5 WHEN 'ERROR' THEN 4 WHEN 'WARN' THEN 3 WHEN 'INFO' THEN 2 ELSE 1 END AS severity_int
FROM audit.application_logs;

/* Q99. */
SELECT request_id, status_code,
       CASE WHEN status_code BETWEEN 200 AND 299 THEN '2xx'
            WHEN status_code BETWEEN 300 AND 399 THEN '3xx'
            WHEN status_code BETWEEN 400 AND 499 THEN '4xx'
            WHEN status_code BETWEEN 500 AND 599 THEN '5xx' END AS status_category
FROM audit.api_requests;

/* Q100. */
SELECT o.order_id,
       INITCAP(COALESCE(c.first_name, '') || ' ' || COALESCE(c.last_name, '')) AS customer_name,
       TO_CHAR(o.net_total, 'FM"Rs"99,99,999.00') AS net_total_fmt,
       UPPER(COALESCE(o.order_status, 'UNKNOWN')) AS status,
       (CURRENT_DATE - o.order_date)::INT AS days_since
FROM sales.orders o
LEFT JOIN customers.customers c ON c.customer_id = o.cust_id;

/* ============================================================
   END OF ANSWER KEY - MEDIUM LEVEL (100/100)
============================================================ */
