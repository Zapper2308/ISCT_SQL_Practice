/* ============================================================
   ANSWER KEY - Scalar Functions (String & Date) (MEDIUM LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* Q1.  `NULL || 'abc'` returns NULL - any `||` operand being NULL poisons the whole result; wrap the nullable side in COALESCE(x, '') to avoid it. */
/* Q2.  They are equivalent - SUBSTR is simply an older alias PostgreSQL supports for SUBSTRING; the standard SUBSTRING syntax (with FROM/FOR) is preferred in modern code. */
/* Q3.  Neither is case-insensitive by default - `LIKE` and `~` both match case-sensitively; use `ILIKE` (pattern) or `~*` (regex) for case-insensitive matching. */
/* Q4.  LATERAL lets a FROM-clause subquery reference columns from preceding FROM items in the same query, which a plain (non-LATERAL) subquery cannot do - this is exactly what's needed to expand REGEXP_MATCHES's per-row array result into multiple output rows tied back to that row's other columns. */
/* Q5.  Each `9` is a digit placeholder and `G` is the locale-aware group ("thousands") separator character, so `99G99G999` formats a number with grouped digits, e.g. 1234567 -> "12,34,567" in an Indian locale. */
/* Q6.  'Mon' is already a fixed 3-letter abbreviation, so FM makes no visible difference there; FM matters for variable-width formats like 'Month' or 'Day', where it strips the trailing blank-padding used to align to the longest name. */
/* Q7.  AGE() returns an INTERVAL (with separate year/month/day/time fields), which isn't directly a single number; EXTRACT(EPOCH FROM interval) converts it into one number - total seconds - suitable for arithmetic, comparison, or aggregation. */
/* Q8.  JUSTIFY_INTERVAL normalizes an interval's fields into more natural units, rolling 24-hour blocks into days and ~30-day blocks into months (e.g. 45 days becomes 1 month 15 days). */
/* Q9.  TO_DATE('2025-01-15','YYYY-MM-DD') parses using an explicit format mask, so it works even for unusual/non-ISO layouts; '2025-01-15'::DATE relies on PostgreSQL's default (ISO-friendly) date parsing and can misinterpret or reject non-standard formats. */
/* Q10. NOW() is fixed to the time the enclosing transaction started, so every call to it within that same transaction returns the identical value, guaranteeing consistency across multiple statements. */
/* Q11. CURRENT_TIMESTAMP (same as NOW()) returns the transaction's start time and stays constant all transaction long; STATEMENT_TIMESTAMP() returns the time the CURRENT statement began; CLOCK_TIMESTAMP() returns the actual real-time clock value and can change even within a single statement. */
/* Q12. AGE(d1) computes the interval between d1 and TODAY (CURRENT_DATE); AGE(d1, d2) computes the interval between the two explicit dates given. */
/* Q13. PostgreSQL's DATE_TRUNC('week', date) always starts the week on MONDAY (ISO-8601 convention), which can confuse Indian users who typically think of the week as starting on Sunday. */
/* Q14. INTERVAL '1 month' lands on the "same day next month" regardless of that month's length (Jan 31 + 1 month = Feb 28/29); adding 30 days is a fixed offset that drifts - they differ whenever the traversed month isn't exactly 30 days long. */
/* Q15. TIMEZONE(zone, timestamp) (equivalent to `timestamp AT TIME ZONE zone`) converts a timestamp's displayed wall-clock value into a different timezone - useful for showing a UTC-stored timestamp in a user's local time. */
/* Q16. LPAD('7', 3, '0') pads on the LEFT to reach length 3, giving '007'; RPAD('7', 3, '0') pads on the RIGHT, giving '700'. */
/* Q17. OVERLAY replaces a substring at a given start position/length with new text in a single expression (`OVERLAY(str PLACING new FROM pos FOR len)`); SUBSTRING only extracts a piece - it can't insert/replace in one call. */
/* Q18. REGEXP_REPLACE finds text matching a regex pattern and replaces it with given replacement text - a common cleaning use is stripping all non-digit characters from a phone number: `REGEXP_REPLACE(phone, '\D', '', 'g')`. */
/* Q19. REGEXP_MATCHES is a set-returning function - with the 'g' flag it returns one text[] row per match, so it can produce multiple rows per input; REGEXP_MATCH returns a single text[] for only the first match, never multiple rows. */
/* Q20. REGEXP_SPLIT_TO_TABLE explodes the split pieces into separate output ROWS (use when you want each piece as its own row); REGEXP_SPLIT_TO_ARRAY keeps all pieces together as one ARRAY value in a single row (use when you want to keep them as a unit). */
/* Q21. STRPOS(text, substring) is PostgreSQL's simpler, function-call form of a literal substring search; POSITION(substring IN text) is the SQL-standard syntax for the identical operation - some prefer STRPOS purely for readability/brevity, they are otherwise equivalent. */
/* Q22. FORMAT() builds strings from a template with %s/%I/%L placeholders, where %I safely quotes identifiers and %L safely quotes literal values - this prevents SQL-injection-style bugs when building dynamic SQL, unlike raw string concatenation. */
/* Q23. TO_NUMBER('1,234.50', '9,999.99') parses a formatted string (with thousands separators) into a NUMERIC by following the given format mask; '1234.50'::NUMERIC is a direct cast that only works on an already-plain numeric string with no separators. */
/* Q24. LENGTH() counts CHARACTERS (code points), which is the correct count for multi-byte UTF-8 text (e.g. an accented letter is 1 character); OCTET_LENGTH() returns the raw storage size in BYTES, which is larger whenever multi-byte characters are present. */
/* Q25. Use EXTRACT(WEEK FROM date) or TO_CHAR(date, 'IW') for the ISO week number; 'WW' in TO_CHAR counts simple 7-day blocks starting from January 1st (so the first/last week of the year can be a partial week), while 'IW' gives the true ISO-8601 week (Monday-start, week 1 contains the year's first Thursday) - they can disagree near year boundaries. */

/* Q26. */
SELECT INITCAP(REGEXP_REPLACE(first_name || ' ' || last_name, '\s+', ' ', 'g')) AS full_name
FROM customers.customers;

/* Q27. */
SELECT LEFT(SPLIT_PART(email, '@', 1), 2)
       || REPEAT('X', GREATEST(LENGTH(SPLIT_PART(email, '@', 1)) - 2, 0))
       || '@' || SPLIT_PART(email, '@', 2) AS masked_email
FROM customers.customers;

/* Q28. */
SELECT REGEXP_REPLACE(phone, '(\+91\s*)|[\s-]', '', 'g') AS phone_clean
FROM customers.customers;

/* Q29. */
SELECT SPLIT_PART(email, '@', 1) AS username, SPLIT_PART(email, '@', 2) AS domain
FROM customers.customers;

/* Q30. */
SELECT INITCAP(TRIM(product_name)) FROM products.products;

/* Q31. */
SELECT LOWER(first_name) || '.' || LOWER(last_name) AS email_username
FROM customers.customers;

/* Q32. */
SELECT UPPER(LEFT(product_name, 3)) || '-' || product_id::TEXT AS sku
FROM products.products;

/* Q33. */
SELECT REGEXP_REPLACE(phone, '\D', '', 'g') FROM customers.customers;

/* Q34. */
SELECT REGEXP_REPLACE(subject, '<[^>]*>', '', 'g') FROM support.tickets;

/* Q35. */
SELECT first_name, LENGTH(first_name) - LENGTH(REGEXP_REPLACE(first_name, '[aeiouAEIOU]', '', 'g')) AS vowel_count
FROM customers.customers;

/* Q36. */
SELECT first_name, REVERSE(first_name) FROM customers.customers;

/* Q37. */
SELECT customer_id, email, (SPLIT_PART(email, '@', 2) IN ('gmail.com', 'yahoo.com', 'outlook.com')) AS is_free_provider
FROM customers.customers;

/* Q38. */
SELECT LEFT(first_name, 1) || '.' || LEFT(last_name, 1) || '.' AS initials
FROM customers.customers;

/* Q39. */
SELECT CASE WHEN LENGTH(subject) > 50 THEN LEFT(subject, 50) || '...' ELSE subject END AS subject_trunc
FROM support.tickets;

/* Q40. */
SELECT LOWER(REGEXP_REPLACE(product_name, '[^a-zA-Z0-9]+', '-', 'g')) AS slug
FROM products.products;

/* Q41. */
SELECT * FROM products.products WHERE LENGTH(product_name) > 30;

/* Q42. */
SELECT * FROM customers.customers WHERE LOWER(first_name) = LOWER(last_name);

/* Q43. */
SELECT INITCAP(REPLACE(product_name, '-', ' ')) FROM products.products;

/* Q44. */
SELECT CASE WHEN phone LIKE '+91 %' THEN SUBSTRING(phone FROM 5) ELSE phone END AS phone_no_prefix
FROM customers.customers;

/* Q45. */
SELECT product_id, LEFT(MD5(product_name || product_id::TEXT), 10) AS suffix
FROM products.products;

/* Q46. */
SELECT customer_id, LEFT(MD5(email), 6) AS short_code FROM customers.customers;

/* Q47. */
SELECT * FROM customers.customers
WHERE LENGTH(email) - LENGTH(REPLACE(email, '@', '')) = 1;

/* Q48. */
SELECT * FROM customers.customers WHERE first_name ~ '[^\x00-\x7F]';

/* Q49. */
SELECT phone, SUBSTRING(phone FROM 5 FOR 3) AS area_code FROM customers.customers;

/* Q50. */
SELECT last_name || ', ' || first_name AS display_name FROM customers.customers;

/* Q51. */
SELECT customer_id,
       EXTRACT(YEAR FROM AGE(registration_date)) || ' years ' ||
       EXTRACT(MONTH FROM AGE(registration_date)) || ' months ' ||
       EXTRACT(DAY FROM AGE(registration_date)) || ' days' AS tenure
FROM customers.customers;

/* Q52. */
SELECT order_id, (DATE_TRUNC('month', order_date) + INTERVAL '1 month' - INTERVAL '1 day')::date AS month_end
FROM sales.orders;

/* Q53. */
SELECT order_id, DATE_TRUNC('quarter', order_date)::date AS quarter_start FROM sales.orders;

/* Q54. */
SELECT order_id, EXTRACT(DOY FROM order_date) AS day_of_year FROM sales.orders;

/* Q55. */
SELECT order_id, EXTRACT(WEEK FROM order_date) AS iso_week FROM sales.orders;

/* Q56. */
SELECT customer_id, (join_date + INTERVAL '1 year')::date - CURRENT_DATE AS days_until_renewal
FROM loyalty.members;

/* Q57. */
SELECT shipment_id, (delivered_date - shipped_date) AS delay_days
FROM sales.shipments WHERE delivered_date IS NOT NULL;

/* Q58. */
SELECT ticket_id, EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600 AS resolution_hours
FROM support.tickets WHERE resolved_date IS NOT NULL;

/* Q59. */
SELECT employee_id, first_name,
       CASE WHEN AGE(joining_date) < INTERVAL '1 year' THEN 'New'
            WHEN AGE(joining_date) < INTERVAL '3 years' THEN 'Mid'
            ELSE 'Veteran' END AS tenure_bucket
FROM stores.employees;

/* Q60. */
SELECT * FROM sales.orders
WHERE order_date >= (DATE_TRUNC('month', order_date) + INTERVAL '1 month' - INTERVAL '3 days')::date;

/* Q61. */
SELECT * FROM sales.orders WHERE EXTRACT(DOW FROM order_date) = 5;

/* Q62. */
SELECT * FROM stores.employees WHERE EXTRACT(DAY FROM joining_date) = 1;

/* Q63. */
SELECT * FROM customers.customers WHERE registration_date = (CURRENT_DATE - INTERVAL '5 years')::date;

/* Q64. */
SELECT attendance_id, EXTRACT(HOUR FROM check_in) * 60 + EXTRACT(MINUTE FROM check_in) AS minutes_after_midnight
FROM hr.attendance WHERE check_in IS NOT NULL;

/* Q65. */
SELECT EXTRACT(HOUR FROM timestamp) AS hour_of_day, COUNT(*)
FROM audit.api_requests
GROUP BY hour_of_day
ORDER BY hour_of_day;

/* Q66. */
SELECT order_id, order_date - INTERVAL '1 year' AS same_date_last_year FROM sales.orders;

/* Q67. */
SELECT shipment_id,
       (delivered_date - shipped_date) - 2 * ((delivered_date - shipped_date) / 7) AS approx_working_days
FROM sales.shipments WHERE delivered_date IS NOT NULL;

/* Q68. */
SELECT order_id, 'Q' || EXTRACT(QUARTER FROM order_date) || '-' || EXTRACT(YEAR FROM order_date) AS quarter_label
FROM sales.orders;

/* Q69. */
SELECT * FROM sales.orders WHERE order_date >= '2025-04-01' AND order_date < '2026-04-01';

/* Q70. */
SELECT ticket_id, EXTRACT(EPOCH FROM (resolved_date - created_date)) * 1000 AS diff_ms
FROM support.tickets WHERE resolved_date IS NOT NULL;

/* Q71. */
SELECT order_id, DATE_TRUNC('week', order_date) AS iso_week_start FROM sales.orders;

/* Q72. */
SELECT generate_series((CURRENT_DATE - INTERVAL '29 days')::date, CURRENT_DATE, '1 day')::date AS d;

/* Q73. */
SELECT * FROM support.tickets
WHERE resolved_date IS NOT NULL AND EXTRACT(DOW FROM resolved_date) IN (0, 6);

/* Q74. */
SELECT * FROM manufacture.work_orders WHERE end_timestamp < start_timestamp;

/* Q75. */
SELECT order_id, order_date,
       order_date - to_timestamp(
         (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM order_date)) FROM sales.orders)
       )::date AS days_from_median
FROM sales.orders;

/* Q76. */
SELECT 'Welcome ' || INITCAP(first_name) || '! Your member ID is CUST-' || customer_id AS subject
FROM customers.customers;

/* Q77. */
SELECT 'INVOICE #' || o.order_id || ' - ' || INITCAP(c.first_name || ' ' || c.last_name) || ' - ' || TO_CHAR(o.order_date, 'DD-Mon-YYYY') AS header
FROM sales.orders o
JOIN customers.customers c ON c.customer_id = o.cust_id;

/* Q78. */
SELECT 'Shipment ' || shipment_id || ' from ' || INITCAP(courier_name) || ' - ' ||
       CASE WHEN delivered_date IS NULL THEN 'IN TRANSIT (since ' || TO_CHAR(shipped_date, 'DD Mon') || ')'
            ELSE 'DELIVERED on ' || TO_CHAR(delivered_date, 'DD Mon') END AS status_line
FROM sales.shipments;

/* Q79. */
SELECT 'Hi ' || first_name || ', your loyalty membership renews on ' || TO_CHAR(join_date + INTERVAL '1 year', 'DD Mon YYYY') AS reminder
FROM customers.customers c
JOIN loyalty.members m ON m.customer_id = c.customer_id;

/* Q80. */
SELECT 'Open since ' || EXTRACT(DAY FROM CURRENT_TIMESTAMP - created_date) || ' days' AS aging
FROM support.tickets WHERE resolved_date IS NULL;

/* Q81. */
SELECT 'Net Rs' || TO_CHAR(net_salary, 'FM99,99,999.00') || ' for ' || salary_month || ' ' || salary_year AS slip_line
FROM payroll.pay_slips;

/* Q82. */
SELECT 'Return ' || return_id || ' for Rs' || TO_CHAR(refund_amount, 'FM99,99,999') || ' processed on ' || TO_CHAR(return_date, 'DD-Mon-YYYY') AS notice
FROM sales.returns;

/* Q83. */
SELECT campaign_name || ' (Rs' || TO_CHAR(budget, 'FM99,99,999') || ', ' || TO_CHAR(start_date, 'Mon YYYY') || ')' AS label
FROM marketing.campaigns;

/* Q84. */
SELECT 'Expense ' || expense_id || ': Rs' || TO_CHAR(amount, 'FM99,99,999.00') || ' on ' || TO_CHAR(expense_date, 'DD-Mon-YYYY') || ' - ' || description AS line
FROM finance.expenses;

/* Q85. */
SELECT 'Customer ' || customer_id || ' joined ' || EXTRACT(YEAR FROM AGE(registration_date)) || 'y ' || EXTRACT(MONTH FROM AGE(registration_date)) || 'm ago' AS stamp
FROM customers.customers;

/* Q86. */
SELECT 'Call ' || call_id || ' (' || call_duration_seconds || 's) at ' || TO_CHAR(call_start_time, 'DD-Mon HH24:MI') AS call_log
FROM call_center.calls;

/* Q87. */
SELECT 'PV-' || view_id || ': ' || page_url || ' on ' || device_type || ' (' || os || ')' AS event_line
FROM web_events.page_views;

/* Q88. */
SELECT '*' || REPEAT('*', GREATEST(rating - 1, 0)) || ' on ' || TO_CHAR(review_date, 'DD Mon YYYY') AS summary
FROM customers.reviews;

/* Q89. */
SELECT 'WO#' || work_order_id || ' (' || quantity_produced || ' produced, ' || rejected_quantity || ' rejected)' AS tag
FROM manufacture.work_orders;

/* Q90. */
SELECT CASE WHEN LENGTH(transcript_text) > 100 THEN LEFT(transcript_text, 100) || '...' ELSE transcript_text END AS snippet
FROM call_center.transcripts;

/* Q91. */
SELECT LOWER(REGEXP_REPLACE(product_name, '[^a-zA-Z0-9]+', '-', 'g')) || '-' || product_id AS slug
FROM products.products;

/* Q92. */
SELECT '{"id":' || customer_id || ',"name":"' || first_name || '","tier":"' || tier || '"}' AS json_summary
FROM customers.customers;

/* Q93. */
SELECT c.customer_id, AGE(CURRENT_TIMESTAMP, MAX(pv.view_timestamp)) AS last_seen
FROM customers.customers c
LEFT JOIN web_events.page_views pv ON pv.customer_id = c.customer_id
GROUP BY c.customer_id;

/* Q94. */
SELECT employee_id, (CURRENT_DATE - joining_date) || ' days since hire' AS label FROM stores.employees;

/* Q95. */
SELECT order_id, order_date,
       'FY' || RIGHT((CASE WHEN EXTRACT(MONTH FROM order_date) >= 4
                           THEN EXTRACT(YEAR FROM order_date) + 1
                           ELSE EXTRACT(YEAR FROM order_date) END)::TEXT, 2) AS fiscal_year
FROM sales.orders;

/* Q96. */
SELECT order_id,
       CASE WHEN order_date = CURRENT_DATE THEN 'today'
            WHEN order_date = CURRENT_DATE - 1 THEN 'yesterday'
            WHEN order_date >= DATE_TRUNC('week', CURRENT_DATE)::date THEN 'this_week'
            WHEN order_date >= DATE_TRUNC('month', CURRENT_DATE)::date THEN 'this_month'
            ELSE 'older' END AS date_bucket
FROM sales.orders;

/* Q97. */
SELECT shipment_id, 'Shipped but not delivered for ' || (CURRENT_DATE - shipped_date) || ' days' AS label
FROM sales.shipments WHERE delivered_date IS NULL;

/* Q98. */
SELECT order_id::TEXT || CASE WHEN net_total > 10000 THEN ' [HIGH]' ELSE ' [normal]' END AS flag
FROM sales.orders;

/* Q99. */
SELECT 'Call ' || c.call_id || ' - sentiment ' ||
       CASE WHEN t.sentiment_score >= 0.5 THEN 'positive'
            WHEN t.sentiment_score <= -0.5 THEN 'negative'
            ELSE 'neutral' END AS sentiment_summary
FROM call_center.calls c
JOIN call_center.transcripts t ON t.call_id = c.call_id;

/* Q100. */
SELECT 'Ticket ' || ticket_id || ' open ' || (CURRENT_DATE - created_date::DATE) || ' days; priority ' || priority AS aging
FROM support.tickets WHERE resolved_date IS NULL;

/* ============================================================
   END OF ANSWER KEY - MEDIUM LEVEL (100/100)
============================================================ */
