/* ============================================================
   ANSWER KEY - Aggregate Functions & Grouping (EASY LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: AGGREGATE / GROUP BY - CONCEPTUAL (10)
   ------------------------------------------------------------ */
/* Q1.  COUNT(*) counts every row regardless of NULLs; COUNT(column_name) counts only rows where that column is NOT NULL. */
/* Q2.  COUNT(DISTINCT col) returns the number of unique non-NULL values in that column, ignoring duplicates. */
/* Q3.  No - AVG only divides by the count of non-NULL values, so NULLs are skipped entirely from both the sum and the denominator, which can make the average look higher/lower than expected if NULLs are common. */
/* Q4.  SUM returns NULL on an empty result set (no rows to sum), not 0 - COUNT is the only aggregate guaranteed to return 0. */
/* Q5.  WHERE filters individual rows BEFORE grouping (e.g. WHERE order_status = 'Delivered'); HAVING filters grouped results AFTER aggregation (e.g. HAVING COUNT(*) > 100). */
/* Q6.  Because WHERE is evaluated before GROUP BY runs, so COUNT(*) doesn't exist yet at that stage - HAVING exists specifically to filter on aggregate results. */
/* Q7.  Because every other row in that group could have a different value for a non-aggregated, non-grouped column, so SQL has no single deterministic value to return for it. */
/* Q8.  STRING_AGG(column, separator) concatenates all values in a group into one delimited string - useful for turning many rows into a single readable summary column. */
/* Q9.  No, by default STRING_AGG has no guaranteed order; you control it with STRING_AGG(col, ',' ORDER BY col). */
/* Q10. MIN/MAX just compare values using an ordering (numeric, alphabetical, or chronological), and dates/strings are all fully orderable types, not just numbers. */

/* ============================================================
   SECTION B: SINGLE-NUMBER AGGREGATES (NO GROUP BY) (30)
   ------------------------------------------------------------ */
/* Q11. */
SELECT COUNT(*) AS customer_count FROM customers.customers;

/* Q12. */
SELECT COUNT(*) AS total_orders FROM sales.orders;

/* Q13. */
SELECT COUNT(*) AS delivered_orders FROM sales.orders WHERE order_status = 'Delivered';

/* Q14. */
SELECT COUNT(*) AS review_count FROM customers.reviews;

/* Q15. */
SELECT COUNT(DISTINCT city) AS distinct_cities FROM stores.stores;

/* Q16. */
SELECT COUNT(DISTINCT order_status) AS distinct_statuses FROM sales.orders;

/* Q17. */
SELECT COUNT(DISTINCT tier) AS distinct_tiers FROM customers.customers;

/* Q18. */
SELECT COUNT(*) AS products_over_1000 FROM products.products WHERE price > 1000;

/* Q19. */
SELECT COUNT(*) AS open_tickets FROM support.tickets WHERE status = 'Open';

/* Q20. */
SELECT COUNT(*) AS never_resolved FROM support.tickets WHERE resolved_date IS NULL;

/* Q21. */
SELECT SUM(net_total) AS total_delivered_revenue FROM sales.orders WHERE order_status = 'Delivered';

/* Q22. */
SELECT AVG(net_total) AS avg_order_value FROM sales.orders;

/* Q23. */
SELECT AVG(salary) AS avg_salary FROM stores.employees;

/* Q24. */
SELECT AVG(price) AS avg_product_price FROM products.products;

/* Q25. */
SELECT AVG(rating) AS avg_rating FROM customers.reviews;

/* Q26. */
SELECT MAX(salary) AS highest_salary FROM stores.employees;

/* Q27. */
SELECT MIN(salary) AS lowest_salary FROM stores.employees;

/* Q28. */
SELECT MAX(price) AS most_expensive_price FROM products.products;

/* Q29. */
SELECT MIN(price) AS cheapest_price FROM products.products WHERE price > 0;

/* Q30. */
SELECT MAX(order_date) AS latest_order_date FROM sales.orders;

/* Q31. */
SELECT MIN(order_date) AS earliest_order_date FROM sales.orders;

/* Q32. */
SELECT AVG(call_duration_seconds) AS avg_call_duration FROM call_center.calls;

/* Q33. */
SELECT MAX(refund_amount) AS max_refund FROM sales.returns;

/* Q34. */
SELECT SUM(budget) AS total_campaign_budget FROM marketing.campaigns;

/* Q35. */
SELECT AVG(amount) AS avg_expense FROM finance.expenses;

/* Q36. */
SELECT SUM(amount) AS total_expenses_2025 FROM finance.expenses WHERE EXTRACT(YEAR FROM expense_date) = 2025;

/* Q37. */
SELECT SUM(net_salary) AS total_salary_payout FROM payroll.pay_slips;

/* Q38. */
SELECT MAX(points_balance) AS max_points_balance FROM loyalty.members;

/* Q39. */
SELECT MIN(points_balance) AS min_points_balance FROM loyalty.members;

/* Q40. */
SELECT COUNT(net_total) AS cnt, SUM(net_total) AS sum_total, AVG(net_total) AS avg_total,
       MIN(net_total) AS min_total, MAX(net_total) AS max_total
FROM sales.orders;

/* ============================================================
   SECTION C: GROUP BY - SINGLE COLUMN (30)
   ------------------------------------------------------------ */
/* Q41. */
SELECT order_status, COUNT(*) AS order_count FROM sales.orders GROUP BY order_status;

/* Q42. */
SELECT tier, COUNT(*) AS customer_count FROM customers.customers GROUP BY tier;

/* Q43. */
SELECT priority, COUNT(*) AS ticket_count FROM support.tickets GROUP BY priority;

/* Q44. */
SELECT status, COUNT(*) AS ticket_count FROM support.tickets GROUP BY status;

/* Q45. */
SELECT device_type, COUNT(*) AS view_count FROM web_events.page_views GROUP BY device_type;

/* Q46. */
SELECT level, COUNT(*) AS log_count FROM audit.application_logs GROUP BY level;

/* Q47. */
SELECT method, COUNT(*) AS request_count FROM audit.api_requests GROUP BY method;

/* Q48. */
SELECT status_code, COUNT(*) AS request_count FROM audit.api_requests GROUP BY status_code ORDER BY status_code;

/* Q49. */
SELECT role, COUNT(*) AS employee_count FROM stores.employees GROUP BY role;

/* Q50. */
SELECT city, COUNT(*) AS store_count FROM stores.stores GROUP BY city;

/* Q51. */
SELECT brand_id, COUNT(*) AS product_count FROM products.products GROUP BY brand_id;

/* Q52. */
SELECT rating, COUNT(*) AS review_count FROM customers.reviews GROUP BY rating ORDER BY rating;

/* Q53. */
SELECT reason, COUNT(*) AS return_count FROM sales.returns GROUP BY reason;

/* Q54. */
SELECT platform, COUNT(*) AS spend_rows FROM marketing.ads_spend GROUP BY platform;

/* Q55. */
SELECT order_status, SUM(net_total) AS total_revenue FROM sales.orders GROUP BY order_status;

/* Q56. */
SELECT role, SUM(salary) AS total_salary FROM stores.employees GROUP BY role;

/* Q57. */
SELECT order_status, AVG(net_total) AS avg_net_total FROM sales.orders GROUP BY order_status;

/* Q58. */
SELECT dept_id, AVG(salary) AS avg_salary FROM stores.employees GROUP BY dept_id;

/* Q59. */
SELECT category, AVG(CASE WHEN priority = 'Critical' THEN 1 WHEN priority = 'High' THEN 2
                          WHEN priority = 'Medium' THEN 3 ELSE 4 END) AS avg_priority_rank
FROM support.tickets GROUP BY category;

/* Q60. */
SELECT DATE_TRUNC('month', start_date) AS campaign_month, SUM(budget) AS total_budget
FROM marketing.campaigns GROUP BY DATE_TRUNC('month', start_date) ORDER BY campaign_month;

/* Q61. */
SELECT DATE_TRUNC('month', order_date) AS order_month, COUNT(*) AS order_count
FROM sales.orders GROUP BY DATE_TRUNC('month', order_date) ORDER BY order_month;

/* Q62. */
SELECT EXTRACT(YEAR FROM registration_date) AS reg_year, COUNT(*) AS customer_count
FROM customers.customers GROUP BY EXTRACT(YEAR FROM registration_date) ORDER BY reg_year;

/* Q63. */
SELECT call_reason, COUNT(*) AS call_count FROM call_center.calls GROUP BY call_reason;

/* Q64. */
SELECT agent_id, SUM(call_duration_seconds) AS total_duration
FROM call_center.calls GROUP BY agent_id ORDER BY total_duration DESC;

/* Q65. */
SELECT employee_id, COUNT(*) AS attendance_count FROM hr.attendance GROUP BY employee_id;

/* Q66. */
SELECT customer_id, COUNT(*) AS ticket_count FROM support.tickets GROUP BY customer_id;

/* Q67. */
SELECT reason, SUM(refund_amount) AS total_refunds FROM sales.returns GROUP BY reason;

/* Q68. */
SELECT exp_cat_id, SUM(amount) AS total_amount FROM finance.expenses GROUP BY exp_cat_id;

/* Q69. */
SELECT dept_id, MAX(salary) AS max_salary FROM stores.employees GROUP BY dept_id;

/* Q70. */
SELECT brand_id, MIN(price) AS min_price FROM products.products GROUP BY brand_id;

/* ============================================================
   SECTION D: HAVING + STRING_AGG (30)
   ------------------------------------------------------------ */
/* Q71. */
SELECT order_status, COUNT(*) AS order_count
FROM sales.orders GROUP BY order_status HAVING COUNT(*) > 1000;

/* Q72. */
SELECT city, COUNT(*) AS store_count
FROM stores.stores GROUP BY city HAVING COUNT(*) > 5;

/* Q73. */
SELECT tier, COUNT(*) AS customer_count
FROM customers.customers GROUP BY tier HAVING COUNT(*) > 5000;

/* Q74. */
SELECT brand_id, COUNT(*) AS product_count
FROM products.products GROUP BY brand_id HAVING COUNT(*) > 100;

/* Q75. */
SELECT role, COUNT(*) AS employee_count
FROM stores.employees GROUP BY role HAVING COUNT(*) > 50;

/* Q76. */
SELECT rating, COUNT(*) AS review_count
FROM customers.reviews GROUP BY rating HAVING COUNT(*) >= 1000;

/* Q77. */
SELECT call_reason, COUNT(*) AS call_count
FROM call_center.calls GROUP BY call_reason HAVING COUNT(*) > 500;

/* Q78. */
SELECT device_type, COUNT(*) AS view_count
FROM web_events.page_views GROUP BY device_type HAVING COUNT(*) > 100000;

/* Q79. */
SELECT method, COUNT(*) AS request_count
FROM audit.api_requests GROUP BY method HAVING COUNT(*) > 1000;

/* Q80. */
SELECT priority, COUNT(*) AS ticket_count
FROM support.tickets GROUP BY priority HAVING COUNT(*) >= 1000;

/* Q81. */
SELECT role, AVG(salary) AS avg_salary
FROM stores.employees GROUP BY role HAVING AVG(salary) > 50000;

/* Q82. */
SELECT brand_id, AVG(price) AS avg_price
FROM products.products GROUP BY brand_id HAVING AVG(price) > 1000;

/* Q83. */
SELECT order_status, SUM(net_total) AS total_revenue
FROM sales.orders GROUP BY order_status HAVING SUM(net_total) > 1000000;

/* Q84. */
SELECT EXTRACT(YEAR FROM registration_date) AS reg_year, COUNT(*) AS new_customers
FROM customers.customers GROUP BY EXTRACT(YEAR FROM registration_date) HAVING COUNT(*) > 5000;

/* Q85. */
SELECT DATE_TRUNC('month', order_date) AS order_month, COUNT(*) AS order_count
FROM sales.orders GROUP BY DATE_TRUNC('month', order_date) HAVING COUNT(*) > 5000;

/* Q86. */
SELECT dept_id, SUM(salary) AS total_salary
FROM stores.employees GROUP BY dept_id HAVING SUM(salary) > 10000000;

/* Q87. */
SELECT DATE_TRUNC('month', start_date) AS campaign_month, SUM(budget) AS total_budget
FROM marketing.campaigns GROUP BY DATE_TRUNC('month', start_date) HAVING SUM(budget) > 1000000;

/* Q88. */
SELECT platform, SUM(amount) AS total_spend
FROM marketing.ads_spend GROUP BY platform HAVING SUM(amount) > 1000000;

/* Q89. */
SELECT category, COUNT(*) AS ticket_count
FROM support.tickets GROUP BY category HAVING COUNT(*) > 500;

/* Q90. */
SELECT exp_cat_id, SUM(amount) AS total_amount
FROM finance.expenses GROUP BY exp_cat_id HAVING SUM(amount) > 5000000;

/* Q91. */
SELECT STRING_AGG(DISTINCT order_status, ', ') AS statuses FROM sales.orders;

/* Q92. */
SELECT STRING_AGG(DISTINCT city, ', ') AS cities FROM stores.stores;

/* Q93. */
SELECT STRING_AGG(DISTINCT tier, ', ' ORDER BY tier) AS tiers FROM customers.customers;

/* Q94. */
SELECT role, STRING_AGG(first_name, ', ') AS employee_names
FROM stores.employees GROUP BY role;

/* Q95. */
SELECT call_reason, STRING_AGG(DISTINCT status, ', ') AS statuses
FROM call_center.calls GROUP BY call_reason;

/* Q96. */
SELECT priority, STRING_AGG(subject, ' | ') AS subjects
FROM support.tickets WHERE priority = 'Critical' GROUP BY priority;

/* Q97. */
SELECT device_type, STRING_AGG(DISTINCT os, ', ') AS os_list
FROM web_events.page_views GROUP BY device_type;

/* Q98. */
SELECT dept_id, STRING_AGG(first_name, ', ' ORDER BY first_name) AS employee_names
FROM stores.employees GROUP BY dept_id;

/* Q99. */
SELECT brand_id, STRING_AGG(product_name, ', ') AS product_names
FROM products.products WHERE brand_id = 1 GROUP BY brand_id;

/* Q100. */
SELECT category, STRING_AGG(subject, ' | ' ORDER BY created_date) AS subjects_by_date
FROM support.tickets GROUP BY category;

/* ============================================================
   END OF ANSWER KEY - Aggregate Functions & Grouping - EASY LEVEL (100/100)
============================================================ */
