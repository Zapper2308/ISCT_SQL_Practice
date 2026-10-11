/* ============================================================
   ANSWER KEY - Installation & RetailMart Onboarding (MEDIUM LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* Q1.  \dt+ adds the physical size on disk and the table's description/comment column, in addition to the schema/name/type/owner that plain \dt shows. */
/* Q2.  \dt *.* lists every table across every schema in the current database in one command. */
/* Q3.  Toggle it with \x (or \x auto); it's useful when a row has many columns and a normal horizontal table would wrap unreadably - expanded mode prints one column per line instead. */
/* Q4.  \timing turns on (or \timing on) - psql then prints the elapsed execution time after every query. */
/* Q5.  \o filename.txt redirects all subsequent query output to that file (\o with no argument sends it back to the screen). */
/* Q6.  Check that the PostgreSQL service is actually running, that the host/port in the connection match the server, and that pg_hba.conf allows a connection from that host/user. */
/* Q7.  \i /path/to/file.sql loads and executes a SQL file from disk inside the current psql session. */
/* Q8.  \df lists all functions (name, schema, result type, argument types) available in the database. */
/* Q9.  \d table_name (or schema.table_name) describes a specific table's columns, types, and constraints. */
/* Q10. \q exits psql cleanly. */
/* Q11. The connection is pointed at the wrong database, the search_path doesn't include RetailMart's schemas, or the connection user lacks privileges on those schemas. */
/* Q12. The '#' means the connected role is a superuser; a regular (non-superuser) role would show '>' instead. */
/* Q13. ALTER ROLE postgres WITH PASSWORD 'newpassword'; run from within psql. */
/* Q14. It stores the history of commands typed in past psql sessions, letting you use the up-arrow/history search; by default it lives at ~/.psql_history. */
/* Q15. psql -U user -d dbname -c "SQL statement" runs one command directly from the shell without opening an interactive session. */
/* Q16. The installer likely installed only the server package (not the client-tools/contrib package that ships psql), or the client binaries directory was never added to PATH. */
/* Q17. SELECT datname, pg_size_pretty(pg_database_size(datname)) FROM pg_database ORDER BY pg_database_size(datname) DESC; (or \l+ in psql). */
/* Q18. SELECT tableowner FROM pg_tables WHERE schemaname = 'customers' AND tablename = 'customers'; */
/* Q19. \d+ sales.orders (or SELECT pg_get_tabledef... via \d) shows the columns, types, constraints, and indexes that make up its structure. */
/* Q20. SHOW shared_buffers; */

/* Q21. */
SELECT table_schema, count(*) AS table_count
FROM information_schema.tables
WHERE table_schema NOT IN ('pg_catalog','information_schema')
GROUP BY table_schema
ORDER BY table_count DESC
LIMIT 10;

/* Q22. */
SELECT table_schema, count(*) AS table_count
FROM information_schema.tables
WHERE table_schema NOT IN ('pg_catalog','information_schema')
GROUP BY table_schema
ORDER BY table_count DESC;

/* Q23. */
SELECT table_schema, table_name, column_name
FROM information_schema.columns
WHERE data_type = 'numeric'
ORDER BY table_schema, table_name, column_name;

/* Q24. */
SELECT table_schema, table_name, column_name
FROM information_schema.columns
WHERE data_type = 'date'
ORDER BY table_schema, table_name, column_name;

/* Q25. */
SELECT table_schema, table_name, column_name
FROM information_schema.columns
WHERE data_type = 'jsonb'
ORDER BY table_schema, table_name, column_name;

/* Q26. */
SELECT table_schema, table_name
FROM information_schema.columns
WHERE column_name = 'cust_id'
ORDER BY table_schema, table_name;

/* Q27. */
SELECT table_schema, table_name
FROM information_schema.columns
WHERE column_name = 'customer_id'
ORDER BY table_schema, table_name;

/* Q28. */
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_name LIKE '%log%'
ORDER BY table_schema, table_name;

/* Q29. */
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_name LIKE '%order%'
ORDER BY table_schema, table_name;

/* Q30. */
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'customers' AND table_name = 'customers'
ORDER BY ordinal_position;

/* Q31. */
SELECT column_name, data_type, character_maximum_length
FROM information_schema.columns
WHERE table_schema = 'sales' AND table_name = 'orders'
ORDER BY ordinal_position;

/* Q32. */
SELECT table_schema, table_name, constraint_name
FROM information_schema.table_constraints
WHERE constraint_type = 'PRIMARY KEY'
ORDER BY table_schema, table_name;

/* Q33. */
SELECT table_schema, table_name, constraint_name
FROM information_schema.table_constraints
WHERE constraint_type = 'FOREIGN KEY'
ORDER BY table_schema, table_name;

/* Q34. */
SELECT table_schema, table_name, constraint_name
FROM information_schema.table_constraints
WHERE constraint_type = 'CHECK'
ORDER BY table_schema, table_name;

/* Q35. */
SELECT table_schema, table_name, constraint_name
FROM information_schema.table_constraints
WHERE constraint_type = 'UNIQUE'
ORDER BY table_schema, table_name;

/* Q36. */
SELECT table_name, count(*) AS column_count
FROM information_schema.columns
WHERE table_schema = 'sales'
GROUP BY table_name
ORDER BY table_name;

/* Q37. */
SELECT table_schema, table_name
FROM information_schema.columns
WHERE column_name = 'email'
ORDER BY table_schema, table_name;

/* Q38. */
SELECT table_schema, table_name, column_name
FROM information_schema.columns
WHERE column_name LIKE '%date%'
ORDER BY table_schema, table_name, column_name;

/* Q39. */
SELECT table_schema, table_name, column_name
FROM information_schema.columns
WHERE column_name LIKE '%amount%'
ORDER BY table_schema, table_name, column_name;

/* Q40. */
SELECT sequence_schema, sequence_name
FROM information_schema.sequences
ORDER BY sequence_schema, sequence_name;

/* Q41. */
SELECT table_schema, table_name
FROM information_schema.views
ORDER BY table_schema, table_name;

/* Q42. */
SELECT data_type
FROM information_schema.columns
WHERE table_schema = 'customers' AND table_name = 'customers' AND column_name = 'tier';

/* Q43. */
SELECT table_schema, table_name, column_name, character_maximum_length
FROM information_schema.columns
WHERE character_maximum_length IS NOT NULL
ORDER BY character_maximum_length DESC
LIMIT 1;

/* Q44. */
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'core'
ORDER BY table_name;

/* Q45. */
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'audit'
ORDER BY table_name;

/* Q46. */
SELECT version(), current_database(), current_user;

/* Q47. */
SELECT datname, pg_size_pretty(pg_database_size(datname))
FROM pg_database
WHERE datname IN ('isct_retailmart')
ORDER BY datname;

/* Q48. */
SELECT count(*) FROM pg_stat_activity WHERE datname = current_database();

/* Q49. */
SELECT current_setting('cluster_name');

/* Q50. */
SELECT extname, extversion FROM pg_extension ORDER BY extname;

/* Q51. */
SELECT count(*) FROM customers.customers WHERE tier = 'Gold';

/* Q52. */
SELECT count(*) FROM customers.customers WHERE tier = 'Platinum';

/* Q53. */
SELECT count(*) FROM products.products WHERE price > 5000;

/* Q54. */
SELECT count(*) FROM sales.orders WHERE order_status = 'Cancelled';

/* Q55. */
SELECT count(*) FROM support.tickets WHERE priority = 'Critical';

/* Q56. */
SELECT count(*) FROM support.tickets WHERE status = 'Open';

/* Q57. */
SELECT count(*) FROM support.tickets WHERE status = 'In Progress';

/* Q58. */
SELECT count(*) FROM support.tickets WHERE resolved_date IS NULL;

/* Q59. */
SELECT count(*) FROM sales.shipments WHERE delivered_date IS NULL;

/* Q60. */
SELECT count(*) FROM web_events.page_views WHERE customer_id IS NULL;

/* Q61. */
SELECT count(*) FROM sales.orders WHERE EXTRACT(YEAR FROM order_date) = 2025;

/* Q62. */
SELECT count(*) FROM sales.orders WHERE order_date BETWEEN '2025-01-01' AND '2025-03-31';

/* Q63. */
SELECT count(*) FROM customers.customers WHERE EXTRACT(YEAR FROM registration_date) = 2024;

/* Q64. */
SELECT count(DISTINCT city) FROM customers.addresses;

/* Q65. */
SELECT count(DISTINCT city) FROM stores.stores;

/* Q66. */
SELECT count(DISTINCT courier_name) FROM sales.shipments;

/* Q67. */
SELECT count(DISTINCT call_reason) FROM call_center.calls;

/* Q68. */
SELECT count(DISTINCT category) FROM support.tickets;

/* Q69. */
SELECT count(DISTINCT brand_id) FROM products.products WHERE brand_id IS NOT NULL;

/* Q70. */
SELECT count(DISTINCT payment_mode) FROM sales.payments;

/* Q71. */
SELECT count(*) FROM marketing.ads_spend WHERE platform = 'Google';

/* Q72. */
SELECT count(*) FROM marketing.ads_spend WHERE platform = 'Meta';

/* Q73. */
SELECT count(*) FROM stores.employees WHERE role = 'Store Manager';

/* Q74. */
SELECT count(*) FROM stores.employees WHERE role = 'Cashier';

/* Q75. */
SELECT count(*) FROM audit.api_requests WHERE status_code = 500;

/* Q76. */
SELECT count(*) FROM audit.api_requests WHERE status_code = 200;

/* Q77. */
SELECT count(*) FROM audit.application_logs WHERE level = 'ERROR';

/* Q78. */
SELECT count(*) FROM audit.application_logs WHERE level = 'FATAL';

/* Q79. */
SELECT count(*) FROM web_events.page_views WHERE device_type = 'Mobile';

/* Q80. */
SELECT count(*) FROM call_center.calls WHERE call_duration_seconds = 60;

/* Q81. */
SELECT * FROM sales.orders WHERE net_total IS NULL;

/* Q82. */
SELECT * FROM customers.customers WHERE first_name IS NULL;

/* Q83. */
SELECT * FROM products.products WHERE brand_id IS NULL;

/* Q84. */
SELECT * FROM stores.employees WHERE dept_id IS NULL;

/* Q85. */
SELECT * FROM customers.reviews WHERE rating IS NULL;

/* Q86. */
SELECT * FROM sales.orders WHERE order_date > CURRENT_DATE;

/* Q87. */
SELECT * FROM sales.shipments WHERE delivered_date < shipped_date;

/* Q88. */
SELECT * FROM support.tickets WHERE resolved_date < created_date;

/* Q89. */
SELECT * FROM products.products WHERE price <= 0;

/* Q90. */
SELECT * FROM stores.employees WHERE salary <= 0;

/* Q91. */
SELECT min(order_date), max(order_date) FROM sales.orders;

/* Q92. */
SELECT min(attendance_date), max(attendance_date) FROM hr.attendance;

/* Q93. */
SELECT min(view_timestamp), max(view_timestamp) FROM web_events.page_views;

/* Q94. */
SELECT min(start_date), max(start_date) FROM marketing.campaigns;

/* Q95. */
SELECT count(DISTINCT cust_id) FROM sales.orders;

/* Q96. */
SELECT count(DISTINCT prod_id) FROM sales.order_items;

/* Q97. */
SELECT count(DISTINCT employee_id) FROM hr.attendance;

/* Q98. */
SELECT count(DISTINCT brand_id) FROM products.products;

/* Q99. */
SELECT count(DISTINCT customer_id) FROM support.tickets;

/* Q100. */
SELECT count(DISTINCT campaign_id) FROM marketing.ads_spend;

/* ============================================================
   END OF ANSWER KEY - MEDIUM LEVEL (100/100)
============================================================ */
