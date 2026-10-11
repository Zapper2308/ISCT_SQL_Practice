/* ============================================================
   ANSWER KEY - Introduction to SQL & Databases (EASY LEVEL)
   Curriculum:   RetailMart V3
   Note: Day 1 is concept-only, so these are short reference
   answers (no queries to run/verify) matching each question.
   ============================================================ */

/* Q1.  Data is raw facts (e.g. "150000"); information is data given context/meaning (e.g. "150,000 orders placed in March"). */
/* Q2.  SQL (Structured Query Language) is the standard language used to store, retrieve, and manage data in a relational database. */
/* Q3.  Excel slows to a crawl and can silently drop/truncate data well before 1M rows (its row cap), has no real concurrency control, and no query optimizer - a database stays fast and correct at that scale. */
/* Q4.  Declarative means you state WHAT result you want (SELECT ... WHERE ...) and the engine decides HOW to get it; imperative code (a for-loop) spells out each step. */
/* Q5.  Mostly yes - both write SELECT/JOIN/GROUP BY - but engineers write more DDL/ETL/pipeline SQL while analysts write more ad-hoc analytical SELECTs. */
/* Q6.  Data Analyst (reporting/dashboards), Data Engineer (building pipelines), Backend Developer (app queries) - all query/manage data daily. */
/* Q7.  Yes - AI tools generate SQL from prompts, but someone still needs to read the schema, judge correctness, and validate the output; SQL literacy is what lets you trust and fix AI-written queries. */
/* Q8.  Even NoSQL-heavy stacks use SQL-speaking analytics layers (BigQuery, Redshift) for reporting, and most companies run both a relational OLTP store and a NoSQL store side by side. */
/* Q9.  A query is simply a question you ask the database, written in SQL, that returns matching rows of data. */
/* Q10. Because SQL is the universal, well-understood interface for asking questions of structured data, so BI tools translate their charts/filters into SQL under the hood. */
/* Q11. Rows and columns give every value a predictable position and type, which lets the database index, filter, and aggregate reliably - free text has no such structure to query on. */
/* Q12. It means SQL is the common language nearly every database, tool, and data professional understands, regardless of underlying vendor. */
/* Q13. SQL: fast, set-based operations on data that lives in a database; pandas: flexible in-memory transformations and stats within Python code. */
/* Q14. SQL, Excel, BI tool, Python - SQL first because almost every data task starts by pulling/shaping data from a database; Excel for quick ad-hoc checks; a BI tool to communicate results; Python for anything beyond SQL's reach (stats/ML). */
/* Q15. The database engine works directly on optimized, indexed, on-disk data in a compiled query engine, while a Python loop pulls all rows into memory and processes them one at a time. */
/* Q16. Structured data fits a fixed rows/columns schema (a customers table); unstructured data has no fixed shape (a folder of support-call audio files). */
/* Q17. SQL is needed to actually get data out of the systems every company runs on, and it's the one skill that transfers across every BI tool, warehouse, and role. */
/* Q18. ChatGPT doesn't know your schema, your data quality issues, or whether the result is actually correct - you still need SQL knowledge to verify and adapt what it writes. */
/* Q19. Banking/fintech, e-commerce/retail, healthcare, and telecom all run core operations on SQL databases daily. */
/* Q20. Core syntax (SELECT, JOIN, GROUP BY, WHERE) stays constant across all of them; what changes is vendor-specific functions, data types, and some dialect quirks. */
/* Q21. The basics (SELECT/WHERE/JOIN) are easy to pick up quickly; what's hard is query performance, complex joins/window functions, and reasoning about large real-world schemas. */
/* Q22. Because the training data itself usually has to be pulled, joined, and cleaned from databases with SQL before any modeling can begin. */
/* Q23. Excel has no real concurrency control (two people editing corrupts data) and no way to enforce data integrity/types at scale, unlike a database. */
/* Q24. Data engineering is building and maintaining the pipelines/infrastructure that move and prepare data for use; SQL is the primary language used to transform and load that data. */
/* Q25. Enforcing types/constraints, joining large tables, deduplicating millions of rows, running fast aggregations, and handling concurrent multi-user access are all easy in SQL, painful in Excel. */

/* Q26. DBMS = Database Management System - software that stores, organizes, secures, and lets you query data, sitting between the raw files on disk and the user/application. */
/* Q27. "Relational" means data is organized into related tables (relations) linked by common key columns, rather than one flat structure. */
/* Q28. Oracle, MySQL (via various Indian IT/product firms), and PostgreSQL are all widely used relational databases in Indian companies. */
/* Q29. MongoDB, Redis, and Cassandra are well-known non-relational (NoSQL) databases. */
/* Q30. A "database" is the actual stored data; the "DBMS" is the software (like PostgreSQL) used to create, manage, and query that data. */
/* Q31. Enforcing a schema up front guarantees every row has the expected columns/types, preventing bad or inconsistent data from ever being stored. */
/* Q32. Storing unstructured/rapidly-changing data (like flexible JSON documents) and needing massive horizontal write scale (like a global activity feed) both favor NoSQL. */
/* Q33. ACID = Atomicity, Consistency, Isolation, Durability - it guarantees a bank transfer either fully completes or fully fails, never leaving money "lost" mid-transaction. */
/* Q34. A large enterprise may already have deep Oracle-specific tooling, support contracts, and legacy systems that make switching costlier than the license fee. */
/* Q35. Many users read and write data at the same time, and the RDBMS must keep every transaction correct and isolated so they don't corrupt or overwrite each other's changes. */
/* Q36. OLTP (primary database) handles fast day-to-day transactions (placing an order); OLAP (data warehouse) is optimized for large analytical queries over historical data. */
/* Q37. Accounting needs strict ACID transactions and strong consistency guarantees that a document-store like MongoDB doesn't enforce by default. */
/* Q38. Amazon RDS, Google Cloud SQL, and Azure Database for PostgreSQL are common cloud-managed RDBMS services. */
/* Q39. SQL is the query language; MySQL is one specific RDBMS product that implements (a dialect of) SQL. */
/* Q40. PostgreSQL has richer analytical features (window functions, CTEs, JSONB) and better standards compliance than MySQL, which analytics/data science workloads rely on heavily. */
/* Q41. PostgreSQL - because it supports concurrent multi-user access and scales beyond SQLite's single-file, single-writer design as the app grows. */
/* Q42. The database server holds and manages the data; client applications (like pgAdmin or your app) send it queries over a connection and receive results back. */
/* Q43. The RDBMS uses locking and transaction isolation (e.g. MVCC in PostgreSQL) so concurrent reads/writes are coordinated safely without corrupting data. */
/* Q44. No - an Excel file has no enforced schema, no concurrent multi-user write safety, and no query engine; it's just a structured file, not a database. */
/* Q45. Regular backups, Write-Ahead Logging (WAL) for crash recovery, and replication to standby servers all protect against data loss. */
/* Q46. Replication continuously copies data to one or more standby servers; banks use it so a failed primary server doesn't mean lost or unavailable data. */
/* Q47. Vertical scaling means adding more power (CPU/RAM) to one server; horizontal scaling means adding more servers to share the load. */
/* Q48. Columnar databases store data by column instead of row, letting analytical queries scan only the columns they need across millions of rows - far faster for aggregations. */
/* Q49. A key-value store saves data as simple key -> value pairs with no fixed schema, optimized for very fast lookups by key. */
/* Q50. Graph databases model data as nodes and relationships directly, making it natural and fast to query things like "friends of friends" or "linked fraud rings." */

/* Q51. DDL (Data Definition Language) defines structures (CREATE/ALTER/DROP); DML (Data Manipulation Language) changes data (INSERT/UPDATE/DELETE); DCL (Data Control Language) manages permissions (GRANT/REVOKE); TCL (Transaction Control Language) manages transactions (COMMIT/ROLLBACK). */
/* Q52. DDL. */
/* Q53. DML. */
/* Q54. DML. */
/* Q55. DML. */
/* Q56. DDL. */
/* Q57. DDL. */
/* Q58. DDL. */
/* Q59. DCL. */
/* Q60. DCL. */
/* Q61. TCL. */
/* Q62. TCL. */
/* Q63. TCL. */
/* Q64. SELECT is technically DQL (Data Query Language), often grouped loosely under DML. */
/* Q65. No - DROP TABLE is DDL and auto-commits; without a prior backup or a transaction-capable setup, the table and its data are gone for good. */
/* Q66. TRUNCATE deallocates whole data pages at once instead of deleting/logging row-by-row like DELETE, but it can't be selectively filtered with WHERE and resets identity columns. */
/* Q67. DROP TABLE removes the table structure and all its data permanently; DELETE FROM table only removes rows, keeping the table structure intact. */
/* Q68. BEGIN/COMMIT/ROLLBACK ensure the debit from one account and the credit to another happen as a single atomic unit - either both succeed or neither does. */
/* Q69. No - SELECT is read-only and doesn't change data, so there's nothing to commit (PostgreSQL still wraps it in an implicit transaction, but no explicit COMMIT is needed). */
/* Q70. GRANT/REVOKE control exactly which users/roles can read, write, or modify specific data, solving the real-world need to limit access by job function. */
/* Q71. GRANT SELECT ON table TO analytics_role. */
/* Q72. ALTER TABLE ... ADD COLUMN. */
/* Q73. DELETE FROM customers WHERE ... . */
/* Q74. DROP TABLE. */
/* Q75. DELETE removes rows one at a time (can be filtered, is logged, and is rollback-able); TRUNCATE instantly empties the whole table and is much faster but less granular. */

/* Q76. A database is an organized, structured collection of related data stored so it can be efficiently accessed, managed, and updated. */
/* Q77. A schema is a named namespace/grouping of tables (and other objects) within a database, used to organize related tables together; a database can contain many schemas. */
/* Q78. A table is a structured collection of rows and columns holding one type of entity's data; the smallest meaningful unit inside it is a single cell (one column's value in one row). */
/* Q79. A row is one record (e.g. one customer); a column is one attribute of every record (e.g. customer_name). */
/* Q80. It means the RetailMart database is organized into 16 separate logical groupings of related tables (like sales, customers, hr), not one giant flat set of tables. */
/* Q81. Splitting by schema keeps related tables organized, makes permissions easier to manage per business area, and avoids one huge cluttered namespace. */
/* Q82. It lets you grant HR staff access to hr data without exposing customer data, and vice versa - separating sensitive domains for security and compliance. */
/* Q83. sales, customers, products, stores, hr (any 5 of the 16 schemas, e.g. finance, marketing, loyalty, support, web_events, audit). */
/* Q84. Dimension tables hold descriptive, slowly-changing attributes (brand names, regions) while fact tables hold high-volume transactional events (orders); separating them avoids repeating descriptive text millions of times. */
/* Q85. A fact table records events/transactions (an order); a dimension table describes the "who/what/where" context around those events (a product, a region). */
/* Q86. A primary key uniquely identifies each row in a table, e.g. customer_id in customers.customers - no two rows can share the same value. */
/* Q87. A foreign key is a column that references another table's primary key; sales.orders.cust_id references customers.customers' primary key, linking each order to its customer. */
/* Q88. A schema-qualified name (customers.customers) explicitly states which schema a table lives in; it's needed because the same table name could exist in multiple schemas. */
/* Q89. The schema name is missing - PostgreSQL needs sales.orders (or the schema must be on your search_path) if orders isn't in the default schema. */
/* Q90. Case-sensitivity matters for quoted identifiers ("Customer" != "customer") and string comparisons in WHERE clauses (unless using ILIKE or lower()); unquoted identifiers are folded to lowercase automatically. */
/* Q91. NULL represents "value is unknown/missing"; an empty string is an actual known value (zero-length text) - conflating the two would make missing data look like real data. */
/* Q92. You can JOIN across related entities, enforce referential integrity, run consistent multi-table reports, keep data normalized, and query subsets instantly - none of which a single Excel sheet supports well. */
/* Q93. 16 distinct schemas - e.g. sales, customers, products, hr, finance. */
/* Q94. An index is like a book's index page - it lets the database jump straight to the rows you want instead of reading every page (row) one by one. */
/* Q95. A database is the whole organized collection of data (and its schemas); a table is one structured grid of rows/columns within it holding one type of record. */
/* Q96. SELECT * pulls every column for every one of the 50 million rows across the network/disk, which is far more data movement than a targeted SELECT with specific columns and a WHERE filter. */
/* Q97. Newer PostgreSQL versions bring performance improvements (better query planner, parallelism) and modern features (improved JSON handling, security patches) over much older releases. */
/* Q98. RetailMart V3 is the third iteration of the practice dataset/schema, refined and expanded from V1/V2 with more schemas, tables, and realistic complexity. */
/* Q99. No - pgAdmin is just a client/GUI tool used to connect to and manage a PostgreSQL database; PostgreSQL itself is the actual database server. */
/* Q100. What a database/schema/table is, how RetailMart's schemas are organized (16 schemas, 55 tables), and the difference between DDL/DML/DCL/TCL. */

/* ============================================================
   END OF ANSWER KEY - EASY LEVEL (100/100)
============================================================ */
