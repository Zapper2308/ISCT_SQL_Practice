/* ============================================================
   ANSWER KEY - Filtering & Sorting (EASY LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* Q1.  The WHERE clause filters rows, keeping only those that satisfy the given condition(s). */
/* Q2.  AND has higher precedence than OR, so `a OR b AND c` is evaluated as `a OR (b AND c)` - missing parentheses can silently change the result. */
/* Q3.  Yes - BETWEEN is inclusive on both ends, so BETWEEN 1 AND 10 includes 1 and 10. */
/* Q4.  Use IN when checking a column against many discrete values - it is shorter and clearer than chaining `col = x OR col = y OR ...`. */
/* Q5.  LIKE is case-sensitive, so 'samsung%' does not match 'Samsung...'; they should use ILIKE 'samsung%' for case-insensitive matching. */
/* Q6.  NULL means "unknown", and `= NULL` is never TRUE for any value (even another NULL) - IS NULL must be used to test for missing values. */
/* Q7.  Without ORDER BY, PostgreSQL gives no guarantee about row order - the "sorted" appearance is an accident of storage/scan order that can change any time. */
/* Q8.  ASC (ascending) is the default sort direction. */
/* Q9.  It skips the first 20 rows and returns the next 10 (rows 21-30) - with 10-per-page paging, that is page 3. */
/* Q10. Written order: SELECT, FROM, WHERE, ORDER BY, LIMIT. Execution order: FROM, WHERE, SELECT, ORDER BY, LIMIT. */

/* Q11. */
SELECT * FROM customers.customers;

/* Q12. */
SELECT first_name, email FROM customers.customers;

/* Q13. */
SELECT product_id, product_name, price FROM products.products;

/* Q14. */
SELECT order_id, cust_id, net_total FROM sales.orders;

/* Q15. */
SELECT employee_id, first_name, role FROM stores.employees;

/* Q16. */
SELECT * FROM products.products WHERE price > 500;

/* Q17. */
SELECT * FROM products.products WHERE price < 100;

/* Q18. */
SELECT * FROM products.products WHERE price = 999.99;

/* Q19. */
SELECT * FROM sales.orders WHERE order_status = 'Delivered';

/* Q20. */
SELECT * FROM sales.orders WHERE order_status != 'Cancelled';

/* Q21. */
SELECT * FROM customers.customers WHERE tier = 'Gold';

/* Q22. */
SELECT * FROM customers.customers WHERE tier != 'Bronze';

/* Q23. */
SELECT * FROM stores.employees WHERE salary > 50000;

/* Q24. */
SELECT * FROM stores.employees WHERE salary < 30000;

/* Q25. */
SELECT * FROM stores.stores WHERE city = 'Mumbai';

/* Q26. */
SELECT * FROM stores.stores WHERE city != 'Delhi';

/* Q27. */
SELECT * FROM support.tickets WHERE priority = 'High';

/* Q28. */
SELECT * FROM support.tickets WHERE status = 'Open';

/* Q29. */
SELECT * FROM loyalty.members WHERE points_balance > 1000;

/* Q30. */
SELECT * FROM customers.reviews WHERE rating = 5;

/* Q31. */
SELECT * FROM customers.reviews WHERE rating < 3;

/* Q32. */
SELECT * FROM hr.attendance WHERE attendance_date = '2025-01-15';

/* Q33. */
SELECT * FROM marketing.campaigns WHERE budget > 100000;

/* Q34. */
SELECT * FROM finance.expenses WHERE amount > 50000;

/* Q35. */
SELECT * FROM audit.application_logs WHERE level = 'ERROR';

/* Q36. */
SELECT * FROM audit.api_requests WHERE status_code = 500;

/* Q37. */
SELECT * FROM web_events.page_views WHERE device_type = 'Mobile';

/* Q38. */
SELECT * FROM manufacture.work_orders WHERE status = 'Completed';

/* Q39. */
SELECT * FROM call_center.calls WHERE call_duration_seconds > 300;

/* Q40. */
SELECT * FROM payroll.pay_slips WHERE net_salary > 10000;

/* Q41. */
SELECT * FROM products.products WHERE price BETWEEN 200 AND 1000;

/* Q42. */
SELECT * FROM products.products WHERE price NOT BETWEEN 100 AND 500;

/* Q43. */
SELECT * FROM sales.orders WHERE order_date BETWEEN '2025-01-01' AND '2025-06-30';

/* Q44. */
SELECT * FROM stores.employees WHERE salary BETWEEN 40000 AND 80000;

/* Q45. */
SELECT * FROM customers.customers WHERE tier IN ('Gold', 'Silver');

/* Q46. */
SELECT * FROM customers.customers WHERE tier NOT IN ('Bronze', 'Platinum');

/* Q47. */
SELECT * FROM sales.orders WHERE order_status IN ('Delivered', 'Shipped');

/* Q48. */
SELECT * FROM support.tickets WHERE priority IN ('High', 'Critical');

/* Q49. */
SELECT * FROM products.products WHERE product_name LIKE 'A%';

/* Q50. */
SELECT * FROM products.products WHERE product_name LIKE '%Pro%';

/* Q51. */
SELECT * FROM products.products WHERE product_name LIKE '%Pro';

/* Q52. */
SELECT * FROM customers.customers WHERE email LIKE '%@gmail.com';

/* Q53. */
SELECT * FROM customers.customers WHERE email LIKE '%@yahoo.com';

/* Q54. */
SELECT * FROM stores.employees WHERE role LIKE '%Manager%';

/* Q55. */
SELECT * FROM stores.employees WHERE role LIKE 'Sales%';

/* Q56. */
SELECT * FROM customers.customers WHERE first_name ILIKE 'priya%';

/* Q57. */
SELECT * FROM products.products WHERE product_name ILIKE 'samsung%';

/* Q58. */
SELECT * FROM customers.customers WHERE first_name LIKE '_a%';

/* Q59. */
SELECT * FROM sales.shipments WHERE delivered_date IS NULL;

/* Q60. */
SELECT * FROM sales.shipments WHERE delivered_date IS NOT NULL;

/* Q61. */
SELECT * FROM web_events.page_views WHERE customer_id IS NULL;

/* Q62. */
SELECT * FROM web_events.page_views WHERE customer_id IS NOT NULL;

/* Q63. */
SELECT * FROM support.tickets WHERE resolved_date IS NULL;

/* Q64. */
SELECT * FROM support.tickets WHERE resolved_date IS NOT NULL;

/* Q65. */
SELECT * FROM sales.orders WHERE order_date >= '2025-01-01';

/* Q66. */
SELECT * FROM marketing.campaigns WHERE budget IN (100000, 200000, 500000);

/* Q67. */
SELECT * FROM products.products WHERE brand_id IN (1, 2, 3, 4, 5);

/* Q68. */
SELECT * FROM call_center.calls WHERE call_reason IN ('Complaint', 'Inquiry');

/* Q69. */
SELECT * FROM customers.customers WHERE registration_date BETWEEN '2024-01-01' AND '2024-12-31';

/* Q70. */
SELECT * FROM sales.orders WHERE order_date >= '2025-01-01' AND order_date < '2026-01-01';

/* Q71. */
SELECT * FROM products.products ORDER BY price DESC LIMIT 10;

/* Q72. */
SELECT * FROM products.products ORDER BY price ASC LIMIT 10;

/* Q73. */
SELECT * FROM sales.orders ORDER BY order_date DESC LIMIT 5;

/* Q74. */
SELECT * FROM sales.orders ORDER BY order_date ASC LIMIT 5;

/* Q75. */
SELECT * FROM stores.employees ORDER BY salary DESC LIMIT 10;

/* Q76. */
SELECT * FROM stores.employees ORDER BY salary ASC LIMIT 10;

/* Q77. */
SELECT * FROM customers.customers ORDER BY registration_date DESC;

/* Q78. */
SELECT * FROM customers.customers ORDER BY first_name ASC;

/* Q79. */
SELECT * FROM stores.stores ORDER BY city ASC;

/* Q80. */
SELECT * FROM sales.orders ORDER BY net_total DESC LIMIT 20;

/* Q81. */
SELECT * FROM products.products ORDER BY price DESC, product_name ASC;

/* Q82. */
SELECT * FROM stores.employees ORDER BY salary DESC, first_name ASC;

/* Q83. */
SELECT * FROM call_center.calls ORDER BY call_duration_seconds DESC LIMIT 5;

/* Q84. */
SELECT * FROM web_events.page_views ORDER BY view_timestamp DESC LIMIT 10;

/* Q85. */
SELECT * FROM hr.attendance ORDER BY attendance_date DESC LIMIT 20;

/* Q86. */
SELECT * FROM sales.returns ORDER BY refund_amount DESC LIMIT 10;

/* Q87. */
SELECT * FROM marketing.campaigns ORDER BY budget DESC LIMIT 5;

/* Q88. */
SELECT * FROM manufacture.work_orders ORDER BY quantity_produced DESC LIMIT 10;

/* Q89. */
SELECT * FROM customers.customers ORDER BY registration_date ASC LIMIT 5;

/* Q90. */
SELECT * FROM sales.shipments ORDER BY delivered_date ASC NULLS LAST;

/* Q91. */
SELECT * FROM support.tickets ORDER BY resolved_date ASC NULLS FIRST;

/* Q92. */
SELECT * FROM customers.customers ORDER BY customer_id LIMIT 10 OFFSET 0;

/* Q93. */
SELECT * FROM customers.customers ORDER BY customer_id LIMIT 10 OFFSET 10;

/* Q94. */
SELECT * FROM products.products ORDER BY price DESC LIMIT 20 OFFSET 40;

/* Q95. */
SELECT * FROM sales.orders ORDER BY net_total DESC LIMIT 20 OFFSET 80;

/* Q96. */
SELECT DISTINCT device_type FROM web_events.page_views;

/* Q97. */
SELECT DISTINCT tier FROM customers.customers;

/* Q98. */
SELECT DISTINCT order_status FROM sales.orders;

/* Q99. */
SELECT DISTINCT city FROM stores.stores ORDER BY city;

/* Q100. */
SELECT DISTINCT category FROM support.tickets ORDER BY category;

/* ============================================================
   END OF ANSWER KEY - EASY LEVEL (100/100)
============================================================ */
