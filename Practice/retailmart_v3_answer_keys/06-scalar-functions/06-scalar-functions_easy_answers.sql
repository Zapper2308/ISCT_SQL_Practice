/* ============================================================
   ANSWER KEY - Scalar Functions (String & Date) (EASY LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* Q1.  UPPER makes every letter uppercase ('hi' -> 'HI'), LOWER makes every letter lowercase ('HI' -> 'hi'), INITCAP capitalizes just the first letter of each word ('hi there' -> 'Hi There'). */
/* Q2.  LENGTH(NULL) returns NULL, not 0 - NULL propagates through nearly every scalar function. */
/* Q3.  Use SUBSTRING when you need characters by position/length or a regex match; use SPLIT_PART when the string has a known delimiter (like '@' in an email) and you want a specific delimited piece. */
/* Q4.  `||` returns NULL if ANY operand is NULL (NULL "poisons" the whole expression); CONCAT() treats NULL arguments as empty strings and simply skips them. */
/* Q5.  By default TRIM removes leading and trailing SPACE characters (whitespace) from a string. */
/* Q6.  NOW() (an alias for CURRENT_TIMESTAMP) returns the current date AND time; CURRENT_DATE returns only today's date with no time component. */
/* Q7.  Subtracting two DATE/TIMESTAMP values isn't a simple count - the result can carry both days and time components, so PostgreSQL represents it as an INTERVAL; casting date-only columns to DATE and subtracting gives a plain integer number of days, or you can use EXTRACT(DAY FROM interval) or EXTRACT(EPOCH FROM interval)/86400. */
/* Q8.  DATE_TRUNC rounds a date/timestamp DOWN to a given precision (month, week, hour) and returns a date/timestamp; EXTRACT pulls out a single numeric field (year, month, hour) as a number - use DATE_TRUNC to bucket/group, EXTRACT to filter/compute on one component. */
/* Q9.  'Day' is a fixed-width, blank-padded format (to fit the longest day name, "Wednesday"); prefixing with 'FM' (fill mode), e.g. TO_CHAR(date,'FMDay'), suppresses the padding. */
/* Q10. AGE() with a single argument compares that date to TODAY (CURRENT_DATE) - it's shorthand for AGE(CURRENT_DATE, that_date). */

/* Q11. */
SELECT customer_id, UPPER(first_name) AS first_name, UPPER(last_name) AS last_name
FROM customers.customers;

/* Q12. */
SELECT LOWER(first_name) FROM customers.customers;

/* Q13. */
SELECT INITCAP(first_name || ' ' || last_name) AS full_name FROM customers.customers;

/* Q14. */
SELECT UPPER(product_name) FROM products.products;

/* Q15. */
SELECT product_name, LENGTH(product_name) FROM products.products;

/* Q16. */
SELECT email, LENGTH(email) FROM customers.customers;

/* Q17. */
SELECT LEFT(product_name, 5) FROM products.products;

/* Q18. */
SELECT RIGHT(phone, 4) FROM customers.customers;

/* Q19. */
SELECT SUBSTRING(product_name FROM 1 FOR 3) FROM products.products;

/* Q20. */
SELECT SPLIT_PART(email, '@', 2) FROM customers.customers;

/* Q21. */
SELECT SPLIT_PART(email, '@', 1) FROM customers.customers;

/* Q22. */
SELECT POSITION('@' IN email) FROM customers.customers;

/* Q23. */
SELECT REPLACE(product_name, '  ', ' ') FROM products.products;

/* Q24. */
SELECT TRIM(subject) FROM support.tickets;

/* Q25. */
SELECT first_name || ' ' || last_name AS full_name FROM customers.customers;

/* Q26. */
SELECT first_name || ' ' || last_name || ' - ' || role AS name_role FROM stores.employees;

/* Q27. */
SELECT LOWER(email) FROM customers.customers;

/* Q28. */
SELECT 'Order #' || order_id::TEXT FROM sales.orders;

/* Q29. */
SELECT 'CUST-' || customer_id::TEXT FROM customers.customers;

/* Q30. */
SELECT 'PRODUCT: ' || product_name FROM products.products;

/* Q31. */
SELECT * FROM stores.employees WHERE role LIKE '%Manager%';

/* Q32. */
SELECT SUBSTRING(product_name FROM POSITION(' ' IN product_name) + 1) FROM products.products;

/* Q33. */
SELECT SPLIT_PART(product_name, ' ', 1) FROM products.products;

/* Q34. */
SELECT LEFT(email, 2) || 'XXX' || SUBSTRING(email FROM POSITION('@' IN email)) FROM customers.customers;

/* Q35. */
SELECT first_name, LENGTH(first_name) FROM customers.customers;

/* Q36. */
SELECT UPPER(TRIM(subject)) FROM support.tickets;

/* Q37. */
SELECT TRIM(role) FROM stores.employees;

/* Q38. */
SELECT SPLIT_PART(email, '@', 2) FROM customers.customers;

/* Q39. */
SELECT city || ', India' FROM stores.stores;

/* Q40. */
SELECT 'Hi ' || first_name || '!' FROM customers.customers;

/* Q41. */
SELECT CURRENT_DATE;

/* Q42. */
SELECT CURRENT_TIMESTAMP;

/* Q43. */
SELECT customer_id, EXTRACT(YEAR FROM registration_date) AS reg_year FROM customers.customers;

/* Q44. */
SELECT order_id, EXTRACT(MONTH FROM order_date) AS order_month FROM sales.orders;

/* Q45. */
SELECT order_id, EXTRACT(DAY FROM order_date) AS order_day FROM sales.orders;

/* Q46. */
SELECT order_id, EXTRACT(DOW FROM order_date) AS order_dow FROM sales.orders;

/* Q47. */
SELECT order_id, EXTRACT(QUARTER FROM order_date) AS order_quarter FROM sales.orders;

/* Q48. */
SELECT order_id, DATE_TRUNC('month', order_date) AS order_month FROM sales.orders;

/* Q49. */
SELECT order_id, DATE_TRUNC('week', order_date) AS order_week FROM sales.orders;

/* Q50. */
SELECT order_id, DATE_TRUNC('year', order_date) AS order_year FROM sales.orders;

/* Q51. */
SELECT order_id, TO_CHAR(order_date, 'DD-Mon-YYYY') FROM sales.orders;

/* Q52. */
SELECT customer_id, TO_CHAR(registration_date, 'YYYY-MM-DD') FROM customers.customers;

/* Q53. */
SELECT order_id, TO_CHAR(order_date, 'FMDay') FROM sales.orders;

/* Q54. */
SELECT order_id, TO_CHAR(order_date, 'FMMonth') FROM sales.orders;

/* Q55. */
SELECT order_id, CURRENT_DATE - order_date AS days_ago FROM sales.orders;

/* Q56. */
SELECT customer_id, AGE(registration_date) AS account_age FROM customers.customers;

/* Q57. */
SELECT customer_id, EXTRACT(YEAR FROM AGE(registration_date)) AS account_age_years FROM customers.customers;

/* Q58. */
SELECT shipment_id, CURRENT_DATE - shipped_date AS days_since_shipment
FROM sales.shipments WHERE shipped_date IS NOT NULL;

/* Q59. */
SELECT shipment_id, delivered_date - shipped_date AS delivery_duration
FROM sales.shipments WHERE delivered_date IS NOT NULL;

/* Q60. */
SELECT ticket_id, resolved_date - created_date AS resolution_time
FROM support.tickets WHERE resolved_date IS NOT NULL;

/* Q61. */
SELECT * FROM sales.orders WHERE order_date >= CURRENT_DATE - INTERVAL '30 days';

/* Q62. */
SELECT * FROM sales.orders WHERE order_date >= CURRENT_DATE - INTERVAL '7 days';

/* Q63. */
SELECT * FROM customers.customers WHERE registration_date >= CURRENT_DATE - INTERVAL '90 days';

/* Q64. */
SELECT * FROM support.tickets WHERE created_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours';

/* Q65. */
SELECT order_id, TO_CHAR(DATE_TRUNC('month', order_date), 'Mon YYYY') AS order_month
FROM sales.orders;

/* Q66. */
SELECT * FROM sales.shipments WHERE shipped_date >= '2025-01-01' AND shipped_date < '2026-01-01';

/* Q67. */
SELECT * FROM call_center.calls WHERE call_start_time >= '2025-01-01' AND call_start_time < '2025-02-01';

/* Q68. */
SELECT * FROM hr.attendance WHERE EXTRACT(DOW FROM attendance_date) = 6;

/* Q69. */
SELECT * FROM payroll.pay_slips WHERE payment_date >= '2025-01-01' AND payment_date < '2025-04-01';

/* Q70. */
SELECT customer_id, EXTRACT(YEAR FROM AGE(registration_date)) AS tenure_years FROM customers.customers;

/* Q71. */
SELECT '#' || order_id || ' on ' || TO_CHAR(order_date, 'DD-Mon-YYYY') AS order_label FROM sales.orders;

/* Q72. */
SELECT INITCAP(first_name || ' ' || last_name) || ' registered on ' || TO_CHAR(registration_date, 'DD-Mon-YYYY') AS label
FROM customers.customers;

/* Q73. */
SELECT first_name || ' ' || last_name || ' joined on ' || TO_CHAR(joining_date, 'Mon YYYY') AS label
FROM stores.employees;

/* Q74. */
SELECT UPPER(product_name) || ' - Rs' || price AS label FROM products.products;

/* Q75. */
SELECT INITCAP(TRIM(subject)) || ' (created ' || TO_CHAR(created_date, 'DD-Mon HH24:MI') || ')' AS label
FROM support.tickets;

/* Q76. */
SELECT INITCAP(store_name) || ' in ' || city AS label FROM stores.stores;

/* Q77. */
SELECT 'Hi ' || INITCAP(first_name) || ', you joined us ' || EXTRACT(YEAR FROM AGE(joining_date)) || ' years ago.' AS greeting
FROM stores.employees;

/* Q78. */
SELECT 'Thank you ' || INITCAP(first_name) || '! Member since ' || EXTRACT(YEAR FROM registration_date) AS label
FROM customers.customers;

/* Q79. */
SELECT 'Order ' || order_id || ' placed on ' || TO_CHAR(order_date, 'FMDay, DD Mon YYYY') AS label FROM sales.orders;

/* Q80. */
SELECT TO_CHAR(EXTRACT(YEAR FROM AGE(registration_date)), 'FM00') || ' years' AS tenure_bucket
FROM customers.customers;

/* Q81. */
SELECT UPPER(courier_name) || ' - ' || TO_CHAR(shipped_date, 'DD/MM/YYYY') AS label FROM sales.shipments;

/* Q82. */
SELECT 'Call ' || call_id || ': ' || call_duration_seconds || 's' AS label FROM call_center.calls;

/* Q83. */
SELECT INITCAP(campaign_name) || ' (Rs' || TO_CHAR(budget, 'FM99,99,999') || ')' AS label FROM marketing.campaigns;

/* Q84. */
SELECT LOWER(email) AS email_lc, SPLIT_PART(email, '@', 2) AS domain, LENGTH(email) AS email_len
FROM customers.customers;

/* Q85. */
SELECT product_name, LENGTH(product_name) AS name_len, LEFT(product_name, 3) AS first3
FROM products.products;

/* Q86. */
SELECT 'EMP-' || employee_id::TEXT || ': ' || first_name || ' (' || EXTRACT(YEAR FROM AGE(joining_date)) || ' yrs)' AS label
FROM stores.employees;

/* Q87. */
SELECT '#' || order_id || ' in ' || TO_CHAR(order_date, 'FMMonth YYYY') AS label FROM sales.orders;

/* Q88. */
SELECT 'TICKET-' || ticket_id || ' ' || INITCAP(TRIM(subject)) AS label FROM support.tickets;

/* Q89. */
SELECT shipment_id, (CURRENT_DATE - shipped_date)::TEXT || ' days ago' AS activity
FROM sales.shipments WHERE shipped_date IS NOT NULL;

/* Q90. */
SELECT customer_id,
       EXTRACT(YEAR FROM AGE(registration_date)) || ' years ' || EXTRACT(MONTH FROM AGE(registration_date)) || ' months' AS account_age
FROM customers.customers;

/* Q91. */
SELECT 'Order from store ' || store_id || ' on ' || TO_CHAR(order_date, 'YYYY-MM-DD') AS label FROM sales.orders;

/* Q92. */
SELECT 'Session ' || session_id || ' viewed ' || page_url || ' at ' || TO_CHAR(view_timestamp, 'HH24:MI:SS') AS label
FROM web_events.page_views;

/* Q93. */
SELECT 'Call #' || call_id || ' by agent ' || agent_id || ' at ' || TO_CHAR(call_start_time, 'DD-Mon HH24:MI') AS label
FROM call_center.calls;

/* Q94. */
SELECT customer_id, tier_id, 'joined ' || EXTRACT(YEAR FROM AGE(join_date)) || ' years ago' AS label
FROM loyalty.members;

/* Q95. */
SELECT customer_id, INITCAP(first_name || ' ' || last_name) AS full_name,
       EXTRACT(YEAR FROM AGE(registration_date)) || ' yrs as customer' AS tenure
FROM customers.customers;

/* Q96. */
SELECT 'WO-' || work_order_id || ' produced ' || quantity_produced || ' units on ' || TO_CHAR(end_timestamp, 'DD-Mon-YYYY') AS label
FROM manufacture.work_orders;

/* Q97. */
SELECT 'Exp #' || expense_id || ' - Rs' || amount || ' on ' || TO_CHAR(expense_date, 'DD-Mon-YYYY') AS label
FROM finance.expenses;

/* Q98. */
SELECT 'REVIEW ' || review_id || ': ' || rating || '* on ' || TO_CHAR(review_date, 'DD-Mon-YYYY') AS label
FROM customers.reviews;

/* Q99. */
SELECT status_code || ' ' || method || ' ' || endpoint || ' at ' || TO_CHAR(timestamp, 'HH24:MI:SS') AS label
FROM audit.api_requests;

/* Q100. */
SELECT (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day') - CURRENT_DATE AS days_remaining;

/* ============================================================
   END OF ANSWER KEY - EASY LEVEL (100/100)
============================================================ */
