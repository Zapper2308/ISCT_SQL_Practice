/* ============================================================
   ANSWER KEY - Installation & RetailMart Onboarding (EASY LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* Q1.  PostgreSQL is the database server that actually stores and processes data; pgAdmin is just a GUI client that connects to it and sends it SQL - it holds no data of its own. */
/* Q2.  psql is PostgreSQL's official command-line client for connecting to a database and running SQL interactively or from scripts. */
/* Q3.  PostgreSQL (the server) runs the database and executes queries; pgAdmin runs as a client app on your machine/browser; your queries are sent from the client, executed by the server, and results are returned to the client. */
/* Q4.  Port 5432 - it matters because that's the port clients (psql, pgAdmin, your app) must target to reach the server, and it can conflict with another local Postgres instance if already in use. */
/* Q5.  You need PostgreSQL to actually store/run the data, and a client (pgAdmin or psql) to talk to it - PostgreSQL has no built-in GUI, so you can't use just the server alone for visual work. */
/* Q6.  PostgreSQL client tools aren't installed/aren't on the system PATH, or the terminal wasn't restarted after installation so the PATH change hasn't taken effect. */
/* Q7.  The installer needs an initial admin account to create the first database cluster and manage roles/permissions before any other user exists, so it creates the 'postgres' superuser by default. */
/* Q8.  'public' is the default schema every new database starts with; it's NOT one of RetailMart's 16 business schemas (sales, customers, etc.) - those were created explicitly by the setup script. */
/* Q9.  DBeaver, DataGrip, and TablePlus/Postico are common SQL clients besides pgAdmin. */
/* Q10. pgAdmin gives a visual browser for schemas/tables/data and query results; VS Code (with a SQL extension) is better for writing/version-controlling longer scripts alongside other project files. */
/* Q11. \dt lists all tables in the current schema (or search_path) - table name, schema, type, and owner. */
/* Q12. \l lists all databases on the connected PostgreSQL server, with owner, encoding, and access privileges. */
/* Q13. \dn lists all schemas in the current database. */
/* Q14. \c some_db switches (connects) your current psql session to a different database on the same server. */
/* Q15. Git tracks the SQL scripts, practice files, and answer keys themselves as versioned code - the database's data isn't in Git, but the SQL you write to interact with it absolutely is, so history/collaboration still matter. */
/* Q16. It creates the RetailMart V3 schemas and tables and loads them with the course's sample data, in one repeatable script. */
/* Q17. \copy runs client-side (reads the CSV from YOUR machine through psql) so it works with local file permissions, whereas server-side COPY requires the file to already exist on the database server's filesystem. */
/* Q18. \q exits psql cleanly. */
/* Q19. No - running as sudo is unnecessary and risky (broader OS privileges than needed); use your normal OS user and authenticate to Postgres with its own login/password instead. */
/* Q20. PostgreSQL has richer window-function/CTE/JSONB support and stricter standards compliance than MySQL, both of which matter heavily for analytical SQL taught in this course. */
/* Q21. TCP connects over the network stack (even to localhost, using host/port) and can be used remotely; a Unix-socket connection is a local, file-based IPC channel to a server on the same machine, typically faster and used when no host is specified. */
/* Q22. A connection string bundles all connection details into one URI; the typical Postgres format is postgresql://user:password@host:port/dbname. */
/* Q23. Stop the server, restart it in single-user mode (or edit pg_hba.conf to trust local connections temporarily), reset the password with ALTER ROLE, then restore the original pg_hba.conf. */
/* Q24. accio_NN is your personal sandbox for DDL/DML practice (safe to break), while RetailMart V3 is a shared, read-only reference dataset everyone in the batch queries against - keeping them separate protects the shared data. */
/* Q25. SELECT version(); SELECT current_database(); and SELECT count(*) FROM information_schema.tables; (or a simple SELECT * FROM some_table LIMIT 5;) confirm the server responds, you're in the right DB, and you can actually read data. */

/* Q26. */
SELECT version();

/* Q27. */
SELECT current_database();

/* Q28. */
SELECT current_user;

/* Q29. */
SELECT current_date;

/* Q30. */
SELECT current_timestamp;

/* Q31. */
SELECT inet_server_addr();

/* Q32. */
SELECT current_schema();

/* Q33. */
SELECT schema_name FROM information_schema.schemata ORDER BY schema_name;

/* Q34. */
SELECT count(*) FROM information_schema.schemata;

/* Q35. */
SELECT table_name FROM information_schema.tables WHERE table_schema = 'sales' ORDER BY table_name;

/* Q36. */
SELECT table_name FROM information_schema.tables WHERE table_schema = 'customers' ORDER BY table_name;

/* Q37. */
SELECT table_name FROM information_schema.tables WHERE table_schema = 'core' ORDER BY table_name;

/* Q38. */
SELECT count(*) FROM information_schema.tables WHERE table_schema = 'sales';

/* Q39. */
SELECT count(*) FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog','information_schema');

/* Q40. */
SELECT pg_size_pretty(pg_database_size(current_database()));

/* Q41. */
SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = 'customers' AND table_name = 'customers' ORDER BY ordinal_position;

/* Q42. */
SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = 'sales' AND table_name = 'orders' ORDER BY ordinal_position;

/* Q43. */
SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = 'products' AND table_name = 'products' ORDER BY ordinal_position;

/* Q44. */
SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = 'stores' AND table_name = 'employees' ORDER BY ordinal_position;

/* Q45. */
SELECT count(DISTINCT schemaname) FROM pg_tables WHERE tableowner = 'postgres';

/* Q46. */
SELECT table_schema, table_name FROM information_schema.tables WHERE table_name LIKE 'order%' ORDER BY table_schema, table_name;

/* Q47. */
SELECT table_schema, table_name FROM information_schema.tables WHERE table_name LIKE '%employee%' ORDER BY table_schema, table_name;

/* Q48. */
SELECT schema_name FROM information_schema.schemata ORDER BY schema_name ASC;

/* Q49. */
SHOW search_path;

/* Q50. */
SHOW timezone;

/* Q51. */
SELECT count(*) FROM customers.customers;

/* Q52. */
SELECT count(*) FROM sales.orders;

/* Q53. */
SELECT count(*) FROM sales.order_items;

/* Q54. */
SELECT count(*) FROM products.products;

/* Q55. */
SELECT count(*) FROM stores.stores;

/* Q56. */
SELECT count(*) FROM stores.employees;

/* Q57. */
SELECT count(*) FROM core.dim_brand;

/* Q58. */
SELECT count(*) FROM core.dim_category;

/* Q59. */
SELECT count(*) FROM core.dim_region;

/* Q60. */
SELECT count(*) FROM core.dim_department;

/* Q61. */
SELECT count(*) FROM support.tickets;

/* Q62. */
SELECT count(*) FROM marketing.campaigns;

/* Q63. */
SELECT count(*) FROM hr.attendance;

/* Q64. */
SELECT count(*) FROM finance.expenses;

/* Q65. */
SELECT count(*) FROM payroll.pay_slips;

/* Q66. */
SELECT count(*) FROM loyalty.members;

/* Q67. */
SELECT count(*) FROM audit.application_logs;

/* Q68. */
SELECT count(*) FROM audit.api_requests;

/* Q69. */
SELECT count(*) FROM web_events.page_views;

/* Q70. */
SELECT count(*) FROM call_center.calls;

/* Q71. */
SELECT count(*) FROM manufacture.work_orders;

/* Q72. */
SELECT count(*) FROM supply_chain.warehouses;

/* Q73. */
SELECT count(*) FROM sales.returns;

/* Q74. */
SELECT count(*) FROM sales.shipments;

/* Q75. */
SELECT count(*) FROM customers.reviews;

/* Q76. */
SELECT * FROM customers.customers LIMIT 5;

/* Q77. */
SELECT * FROM sales.orders LIMIT 5;

/* Q78. */
SELECT * FROM products.products LIMIT 5;

/* Q79. */
SELECT * FROM stores.employees LIMIT 5;

/* Q80. */
SELECT * FROM stores.stores LIMIT 5;

/* Q81. */
SELECT * FROM core.dim_brand LIMIT 5;

/* Q82. */
SELECT * FROM core.dim_category LIMIT 5;

/* Q83. */
SELECT * FROM core.dim_region LIMIT 5;

/* Q84. */
SELECT * FROM support.tickets LIMIT 5;

/* Q85. */
SELECT * FROM marketing.campaigns LIMIT 5;

/* Q86. */
SELECT * FROM hr.attendance LIMIT 5;

/* Q87. */
SELECT * FROM finance.expenses LIMIT 5;

/* Q88. */
SELECT * FROM payroll.pay_slips LIMIT 5;

/* Q89. */
SELECT * FROM loyalty.members LIMIT 5;

/* Q90. */
SELECT * FROM loyalty.tiers LIMIT 5;

/* Q91. */
SELECT * FROM audit.application_logs LIMIT 5;

/* Q92. */
SELECT * FROM audit.api_requests LIMIT 5;

/* Q93. */
SELECT * FROM web_events.page_views LIMIT 5;

/* Q94. */
SELECT * FROM call_center.calls LIMIT 5;

/* Q95. */
SELECT * FROM manufacture.work_orders LIMIT 5;

/* Q96. */
SELECT * FROM supply_chain.warehouses LIMIT 5;

/* Q97. */
SELECT * FROM supply_chain.shipments LIMIT 5;

/* Q98. */
SELECT * FROM customers.addresses LIMIT 5;

/* Q99. */
SELECT * FROM customers.reviews LIMIT 5;

/* Q100. */
SELECT * FROM customers.wallets LIMIT 5;

/* ============================================================
   END OF ANSWER KEY - EASY LEVEL (100/100)
============================================================ */
