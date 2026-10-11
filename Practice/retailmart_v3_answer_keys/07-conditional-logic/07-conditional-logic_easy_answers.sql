/* ============================================================
   ANSWER KEY - Conditional Logic & Derived Columns (EASY LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* Q1.  Simple CASE compares one expression to literal values by equality (`CASE tier WHEN 'Gold' THEN ... END`); Searched CASE evaluates independent boolean conditions in each WHEN (`CASE WHEN price > 1000 THEN ... END`), so it can test different columns/operators per branch. */
/* Q2.  If no WHEN matches and there's no ELSE, the CASE expression returns NULL. */
/* Q3.  No - all WHEN branches (and ELSE) must resolve to a single compatible result type, since the whole CASE expression has one overall type; mismatched, non-castable types raise an error. */
/* Q4.  Searched CASE evaluates WHEN clauses top-to-bottom and stops at the FIRST one that's TRUE, so if multiple conditions could match the same row, the order of the WHEN clauses decides which result wins. */
/* Q5.  COALESCE returns the first non-NULL value among its arguments; NULLIF returns NULL if its two arguments are equal, otherwise it returns the first argument. */
/* Q6.  It returns the first of a, b, c that is not NULL - and if all three are NULL, it falls through to the literal 'default'. */
/* Q7.  NULLIF(x, 0) turns a zero into NULL, so `something / NULLIF(x, 0)` returns NULL instead of raising a "division by zero" error - it solves safe division when the denominator can legitimately be zero. */
/* Q8.  Yes, they are fully equivalent - CAST(x AS INT) is SQL-standard syntax, x::INT is PostgreSQL's own shorthand syntax for the identical operation. */
/* Q9.  INT can only hold whole numbers, and '12.5' is not a valid integer literal - PostgreSQL refuses to silently drop the fractional part on a text-to-int cast; you'd cast to NUMERIC/FLOAT first (which can then round when cast to INT). */
/* Q10. ::TEXT converts a number into its text representation; while `||` can implicitly coerce many types, casting explicitly avoids ambiguity/errors when concatenating a number into a larger string and gives predictable formatting. */

/* Q11. */
SELECT customer_id, tier,
       CASE tier
         WHEN 'Platinum' THEN 'VIP'
         WHEN 'Gold' THEN 'Preferred'
         WHEN 'Silver' THEN 'Standard'
         WHEN 'Bronze' THEN 'Basic'
       END AS tier_label
FROM customers.customers;

/* Q12. */
SELECT product_id, price,
       CASE WHEN price < 100 THEN 'Cheap'
            WHEN price < 1000 THEN 'Mid'
            ELSE 'Premium' END AS price_band
FROM products.products;

/* Q13. */
SELECT order_id, net_total,
       CASE WHEN net_total < 500 THEN 'Small'
            WHEN net_total < 5000 THEN 'Medium'
            ELSE 'Large' END AS order_size
FROM sales.orders;

/* Q14. */
SELECT employee_id, salary,
       CASE WHEN salary < 30000 THEN 'Junior'
            WHEN salary < 60000 THEN 'Mid'
            ELSE 'Senior' END AS band
FROM stores.employees;

/* Q15. */
SELECT ticket_id, priority,
       CASE priority
         WHEN 'Critical' THEN 4
         WHEN 'High' THEN 3
         WHEN 'Medium' THEN 2
         WHEN 'Low' THEN 1
       END AS urgency_score
FROM support.tickets;

/* Q16. */
SELECT order_id, order_status,
       CASE WHEN order_status IN ('Pending', 'Processing', 'Shipped', 'Out for Delivery') THEN 'Active'
            ELSE 'Closed' END AS status_group
FROM sales.orders;

/* Q17. */
SELECT review_id, rating,
       CASE WHEN rating >= 4 THEN 'Positive'
            WHEN rating = 3 THEN 'Neutral'
            ELSE 'Negative' END AS sentiment
FROM customers.reviews;

/* Q18. */
SELECT pay_slip_id, income_tax,
       CASE WHEN income_tax > 10000 THEN 'High Tax'
            WHEN income_tax > 5000 THEN 'Mid'
            ELSE 'Low' END AS tax_band
FROM payroll.pay_slips;

/* Q19. */
SELECT attendance_id, check_in,
       CASE WHEN check_in IS NULL THEN 'Absent' ELSE 'Present' END AS attendance_status
FROM hr.attendance;

/* Q20. */
SELECT view_id, device_type,
       CASE WHEN device_type IN ('Mobile', 'Tablet') THEN 'Touch'
            WHEN device_type = 'Desktop' THEN 'Desktop' END AS device_group
FROM web_events.page_views;

/* Q21. */
SELECT campaign_id, budget,
       CASE WHEN budget < 50000 THEN 'Small'
            WHEN budget < 200000 THEN 'Medium'
            ELSE 'Large' END AS budget_band
FROM marketing.campaigns;

/* Q22. */
SELECT call_id, call_duration_seconds,
       CASE WHEN call_duration_seconds < 60 THEN 'Short'
            WHEN call_duration_seconds < 300 THEN 'Medium'
            ELSE 'Long' END AS duration_band
FROM call_center.calls;

/* Q23. */
SELECT customer_id, points_balance,
       CASE WHEN points_balance < 500 THEN 'Starter'
            WHEN points_balance < 2000 THEN 'Engaged'
            ELSE 'VIP' END AS member_band
FROM loyalty.members;

/* Q24. */
SELECT request_id, status_code,
       CASE WHEN status_code BETWEEN 200 AND 299 THEN 'OK'
            WHEN status_code BETWEEN 300 AND 399 THEN 'Redirect'
            WHEN status_code BETWEEN 400 AND 499 THEN 'Client Error'
            WHEN status_code BETWEEN 500 AND 599 THEN 'Server Error' END AS status_group
FROM audit.api_requests;

/* Q25. */
SELECT log_id, level,
       CASE WHEN level IN ('ERROR', 'FATAL') THEN 'Alert'
            WHEN level = 'WARN' THEN 'Caution'
            ELSE 'Info' END AS log_group
FROM audit.application_logs;

/* Q26. */
SELECT product_id, brand_id,
       CASE WHEN brand_id IN (1, 2, 3, 4, 5) THEN 'Made by Top Brand' ELSE 'Other' END AS brand_flag
FROM products.products;

/* Q27. */
SELECT customer_id, registration_date,
       CASE WHEN registration_date >= CURRENT_DATE - 30 THEN 'New' ELSE 'Existing' END AS customer_status
FROM customers.customers;

/* Q28. */
SELECT order_id, order_date,
       CASE WHEN EXTRACT(MONTH FROM order_date) BETWEEN 1 AND 3 THEN 'Q1'
            WHEN EXTRACT(MONTH FROM order_date) BETWEEN 4 AND 6 THEN 'Q2'
            WHEN EXTRACT(MONTH FROM order_date) BETWEEN 7 AND 9 THEN 'Q3'
            ELSE 'Q4' END AS quarter_label
FROM sales.orders;

/* Q29. */
SELECT order_id, order_date,
       CASE WHEN EXTRACT(DOW FROM order_date) IN (0, 6) THEN 'Weekend' ELSE 'Weekday' END AS day_type
FROM sales.orders;

/* Q30. */
SELECT shipment_id, delivered_date,
       CASE WHEN delivered_date IS NULL THEN 'In Transit' ELSE 'Delivered' END AS shipment_status
FROM sales.shipments;

/* Q31. */
SELECT ticket_id, resolved_date,
       CASE WHEN resolved_date IS NULL THEN 'Open' ELSE 'Resolved' END AS resolution_status
FROM support.tickets;

/* Q32. */
SELECT employee_id, store_id,
       CASE WHEN store_id IS NOT NULL THEN 'In-Store' ELSE 'HQ' END AS location_type
FROM stores.employees;

/* Q33. */
SELECT work_order_id, quantity_produced,
       CASE WHEN quantity_produced < 500 THEN 'Small Batch'
            WHEN quantity_produced < 2000 THEN 'Mid'
            ELSE 'Large' END AS batch_size
FROM manufacture.work_orders;

/* Q34. */
SELECT expense_id, amount,
       CASE WHEN amount > 100000 THEN 'Major'
            WHEN amount > 10000 THEN 'Standard'
            ELSE 'Minor' END AS expense_tag
FROM finance.expenses;

/* Q35. */
SELECT order_id, order_date,
       CASE WHEN EXTRACT(DOW FROM order_date) IN (0, 6) THEN TRUE ELSE FALSE END AS is_weekend
FROM sales.orders;

/* Q36. */
SELECT customer_id, tier,
       CASE tier
         WHEN 'Platinum' THEN 4
         WHEN 'Gold' THEN 3
         WHEN 'Silver' THEN 2
         WHEN 'Bronze' THEN 1
       END AS tier_rank
FROM customers.customers;

/* Q37. */
SELECT product_id, CASE WHEN price > 5000 THEN TRUE ELSE FALSE END AS is_premium
FROM products.products;

/* Q38. */
SELECT attendance_id, check_in,
       CASE WHEN EXTRACT(HOUR FROM check_in) < 9 THEN 'Early'
            WHEN EXTRACT(HOUR FROM check_in) < 12 THEN 'Morning'
            WHEN EXTRACT(HOUR FROM check_in) < 17 THEN 'Afternoon'
            ELSE 'Late' END AS check_in_band
FROM hr.attendance
WHERE check_in IS NOT NULL;

/* Q39. */
SELECT view_id, view_timestamp,
       CASE WHEN EXTRACT(HOUR FROM view_timestamp) < 6 THEN 'Night'
            WHEN EXTRACT(HOUR FROM view_timestamp) < 12 THEN 'Morning'
            WHEN EXTRACT(HOUR FROM view_timestamp) < 18 THEN 'Afternoon'
            ELSE 'Evening' END AS time_of_day
FROM web_events.page_views;

/* Q40. */
SELECT order_id, net_total, CASE WHEN net_total > 1000 THEN net_total ELSE 1000 END AS floored_total
FROM sales.orders;

/* Q41. */
SELECT customer_id, COALESCE(phone, 'NOT PROVIDED') AS phone FROM customers.customers;

/* Q42. */
SELECT ticket_id, COALESCE(resolved_date, '0001-01-01') AS resolved_date FROM support.tickets;

/* Q43. */
SELECT shipment_id, COALESCE(delivered_date::TEXT, 'PENDING') AS delivered_date FROM sales.shipments;

/* Q44. */
SELECT customer_id, COALESCE(email, 'no-email@retailmart.com') AS email FROM customers.customers;

/* Q45. */
SELECT employee_id, COALESCE(store_id, 0) AS store_id FROM stores.employees;

/* Q46. */
SELECT shipment_id, COALESCE(delivered_date, shipped_date) AS effective_date FROM sales.shipments;

/* Q47. */
SELECT customer_id, COALESCE(tier_updated_at, registration_date::timestamp) AS effective_change_date
FROM customers.customers;

/* Q48. */
SELECT ticket_id, COALESCE(resolved_date, created_date + INTERVAL '7 days') AS estimated_resolution
FROM support.tickets;

/* Q49. */
SELECT request_id, COALESCE(user_agent, 'unknown') AS user_agent FROM audit.api_requests;

/* Q50. */
SELECT view_id, COALESCE(customer_id::TEXT, 'anonymous') AS customer_label FROM web_events.page_views;

/* Q51. */
SELECT product_id, NULLIF(price, 0) AS safe_price FROM products.products;

/* Q52. */
SELECT call_id, NULLIF(call_duration_seconds, 0) AS safe_duration FROM call_center.calls;

/* Q53. */
SELECT order_item_id, 100.0 * quantity / NULLIF(unit_price, 0) AS safe_pct FROM sales.order_items;

/* Q54. */
SELECT product_id, (price - cost_price) / NULLIF(price, 0) AS margin FROM products.products;

/* Q55. */
SELECT ticket_id, (CASE WHEN resolved_date IS NOT NULL THEN 1 ELSE 0 END)::numeric / NULLIF(1, 0) AS resolved_flag
FROM support.tickets;

/* Q56. */
SELECT customer_id, COALESCE(phone, email, 'NO_CONTACT') AS display_contact FROM customers.customers;

/* Q57. */
SELECT customer_id, COALESCE(points_balance, 0) AS points_balance FROM loyalty.members;

/* Q58. */
SELECT review_id, COALESCE(rating, 0) AS rating FROM customers.reviews;

/* Q59. */
SELECT return_id, COALESCE(refund_amount, 0) AS refund_amount FROM sales.returns;

/* Q60. */
SELECT campaign_id, COALESCE(end_date, '2099-12-31') AS end_date FROM marketing.campaigns;

/* Q61. */
SELECT shipment_id, COALESCE((delivered_date - shipped_date)::TEXT, 'N/A') AS duration FROM sales.shipments;

/* Q62. */
SELECT ticket_id, COALESCE(subject, '(empty subject)') AS subject FROM support.tickets;

/* Q63. */
SELECT order_id, COALESCE(payment_mode_id, -1) AS payment_mode_id FROM sales.orders;

/* Q64. */
SELECT expense_id, COALESCE(description, 'No description provided') AS description FROM finance.expenses;

/* Q65. */
SELECT product_id, COALESCE(supplier_id, 0) AS supplier_id FROM products.products;

/* Q66. */
SELECT ticket_id, NULLIF(TRIM(subject), '') AS subject_clean FROM support.tickets;

/* Q67. */
SELECT customer_id, COALESCE(NULLIF(TRIM(first_name), ''), 'Unknown') AS first_name_clean FROM customers.customers;

/* Q68. */
SELECT view_id, 1.0 / NULLIF(customer_id, 0) AS safe_div FROM web_events.page_views;

/* Q69. */
SELECT product_id, COALESCE(price, cost_price, 0) AS effective_price FROM products.products;

/* Q70. */
SELECT shipment_id, COALESCE(courier_name, 'Unknown Courier') AS courier_name FROM sales.shipments;

/* Q71. */
SELECT 'Order ' || order_id::TEXT FROM sales.orders;

/* Q72. */
SELECT product_id, price::INT AS price_rounded FROM products.products;

/* Q73. */
SELECT order_id, net_total::NUMERIC(10,2) AS net_total_2dp FROM sales.orders;

/* Q74. */
SELECT customer_id, TO_CHAR(registration_date, 'YYYY-MM-DD') AS reg_date_text FROM customers.customers;

/* Q75. */
SELECT '2025-01-15'::DATE AS parsed_date;

/* Q76. */
SELECT '12.50'::NUMERIC AS amount;

/* Q77. */
SELECT '12.50'::NUMERIC(10,2) AS amount;

/* Q78. */
SELECT event_id, event_type::TEXT AS event_type_text FROM web_events.events;

/* Q79. */
SELECT request_id, status_code::TEXT || ' ' || method AS label FROM audit.api_requests;

/* Q80. */
SELECT call_id, (call_duration_seconds || ' seconds')::INTERVAL AS duration_interval FROM call_center.calls;

/* Q81. */
SELECT work_order_id, quantity_produced::NUMERIC / 100 AS batches FROM manufacture.work_orders;

/* Q82. */
SELECT expense_id, amount::INT AS amount_rounded FROM finance.expenses;

/* Q83. */
SELECT view_id, view_timestamp::DATE AS view_date FROM web_events.page_views;

/* Q84. */
SELECT attendance_id, check_in::TIME AS check_in_time FROM hr.attendance WHERE check_in IS NOT NULL;

/* Q85. */
SELECT attendance_id, check_in::DATE AS check_in_date FROM hr.attendance WHERE check_in IS NOT NULL;

/* Q86. */
SELECT 'true'::BOOLEAN AS flag;

/* Q87. */
SELECT TO_CHAR(0.85, '0.00%') AS pct_display;

/* Q88. */
SELECT product_id, price::BIGINT AS price_whole FROM products.products;

/* Q89. */
SELECT CAST('100' AS INT) AS n;

/* Q90. */
SELECT product_id, TO_CHAR(price, 'FM99,99,999') AS price_grouped FROM products.products;

/* Q91. */
SELECT '99.99'::NUMERIC + 0.01 AS total;

/* Q92. */
SELECT TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS') AS now_text;

/* Q93. */
SELECT review_id, review_date::TEXT AS review_date_text FROM customers.reviews;

/* Q94. */
SELECT customer_id, LPAD(customer_id::TEXT, 8, '0') AS padded_id FROM customers.customers;

/* Q95. */
SELECT employee_id, salary::INT AS salary_int FROM stores.employees;

/* Q96. */
SELECT order_id, 'Rs' || net_total::INT AS label FROM sales.orders;

/* Q97. */
SELECT '{"role": "admin"}'::JSONB AS payload;

/* Q98. */
SELECT gen_random_uuid()::TEXT AS uuid_text;

/* Q99. */
SELECT '2025'::INT AS year_num;

/* Q100. */
SELECT order_id::TEXT || ' (' || TO_CHAR(net_total, 'FM"Rs"99,99,999') || ')' AS invoice_label
FROM sales.orders;

/* ============================================================
   END OF ANSWER KEY - EASY LEVEL (100/100)
============================================================ */
