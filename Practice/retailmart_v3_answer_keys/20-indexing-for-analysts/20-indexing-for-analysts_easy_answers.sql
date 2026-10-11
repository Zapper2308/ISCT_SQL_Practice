/* ============================================================
   ANSWER KEY - Indexing for Analysts (EASY LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1.  An index is a separate on-disk structure that maps column values to row locations, letting the engine jump straight to matching rows instead of scanning the whole table. */
/* Q2.  B-Tree (Balanced Tree) is PostgreSQL's default index type. */
/* Q3.  A B-Tree can serve =, <, <=, >, >=, BETWEEN, IN, IS NULL, and ORDER BY on the indexed column(s). */
/* Q4.  Every INSERT/UPDATE/DELETE must also update each index on that table, so more indexes mean slower writes. */
/* Q5.  A full-table aggregate must read every row anyway, so there's no subset to jump to - the index adds overhead with no benefit (though an Index Only Scan can still help if the column is covered). */
/* Q6.  CREATE INDEX name ON schema.table (column); */
/* Q7.  IF NOT EXISTS skips creation (with a notice, not an error) if an index of that name already exists. */
/* Q8.  DROP INDEX schema.index_name; */
/* Q9.  Run EXPLAIN (or EXPLAIN ANALYZE) on the query and look for "Index Scan"/"Index Only Scan"/"Bitmap Index Scan" instead of "Seq Scan". */
/* Q10. A primary key automatically gets a unique B-Tree index created to enforce uniqueness. */
/* Q11. Yes - PostgreSQL automatically builds a unique B-Tree index to enforce a UNIQUE constraint. */
/* Q12. Selectivity is the fraction of rows a filter matches; a highly selective filter (few matching rows) benefits most because the index lets the planner skip almost all the table. */
/* Q13. A low-cardinality column (few distinct values, e.g. gender) matches a large fraction of rows per value, so an Index Scan reads nearly as much as a Seq Scan while adding lookup overhead - the planner usually ignores it. */
/* Q14. An Index Only Scan answers the query using just the index's own data, without visiting the underlying table (heap) at all, because every needed column is present in the index. */
/* Q15. SELECT * FROM pg_indexes WHERE tablename = 'orders'; */
/* Q16. A plain index on col stores the raw values, not LOWER(col); the planner can't use it for a function-wrapped predicate unless a matching expression index exists. */
/* Q17. CREATE INDEX CONCURRENTLY builds the index without taking the heavy lock that blocks concurrent writes, at the cost of a slower, two-pass build. */
/* Q18. The planner may judge (from table statistics) that a Seq Scan is actually cheaper - e.g. the filter isn't selective enough, or the table is small. */
/* Q19. A composite (multi-column) index is a single B-Tree built over two or more columns together, ordered by the first column, then the second, etc. */
/* Q20. A partial index only indexes the rows matching a WHERE predicate, making it smaller and more targeted than a full-table index. */
/* Q21. ANALYZE refreshes the table's statistics (row counts, value distributions) so the planner can accurately judge whether the new index is worth using. */
/* Q22. Roughly the size of the indexed column(s) times the row count, plus B-Tree overhead - often comparable to or larger than a narrow table itself. */
/* Q23. Skip indexing columns that are rarely filtered on, have low selectivity, or sit on a write-heavy table where the extra write cost outweighs the rare read benefit. */
/* Q24. A clustered index physically stores table rows in index order (one per table); a non-clustered index is a separate structure pointing back to rows - PostgreSQL only has non-clustered indexes (CLUSTER is a one-time manual reorder, not maintained automatically). */
/* Q25. "Show me this customer's orders" (WHERE cust_id=?) and "orders placed in the last 30 days" (WHERE order_date >= ?) both benefit from an index on the filtered column. */

/* ============================================================
   SECTION B: CREATE SINGLE-COLUMN INDEXES (25)
   ------------------------------------------------------------ */
/* Q26. */
CREATE INDEX idx_orders_custid ON sales.orders (cust_id);
/* Q27. */
CREATE INDEX idx_orders_orderdate ON sales.orders (order_date);
/* Q28. */
CREATE INDEX idx_customers_email ON customers.customers (email);
/* Q29. */
CREATE INDEX idx_products_brandid ON products.products (brand_id);
/* Q30. */
CREATE INDEX idx_orderitems_prodid ON sales.order_items (prod_id);
/* Q31. */
CREATE INDEX idx_tickets_customerid ON support.tickets (customer_id);
/* Q32. */
CREATE INDEX idx_reviews_productid ON customers.reviews (product_id);
/* Q33. */
CREATE INDEX idx_employees_storeid ON stores.employees (store_id);
/* Q34. */
CREATE INDEX idx_orders_storeid ON sales.orders (store_id);
/* Q35. */
CREATE INDEX idx_pageviews_sessionid ON web_events.page_views (session_id);
/* Q36. */
CREATE INDEX idx_calls_customerid ON call_center.calls (customer_id);
/* Q37. */
CREATE INDEX idx_shipments_orderid ON sales.shipments (order_id);
/* Q38. */
CREATE INDEX idx_products_price ON products.products (price);
/* Q39. */
CREATE INDEX idx_members_tierid ON loyalty.members (tier_id);
/* Q40. */
CREATE INDEX idx_addresses_customerid ON customers.addresses (customer_id);
/* Q41. */
CREATE INDEX IF NOT EXISTS idx_orders_orderstatus ON sales.orders (order_status);
/* Q42. */
CREATE INDEX idx_payslips_employeeid ON payroll.pay_slips (employee_id);
/* Q43. */
CREATE INDEX idx_adsspend_campaignid ON marketing.ads_spend (campaign_id);
/* Q44. */
CREATE INDEX idx_invsnap_productid ON supply_chain.inventory_snapshots (product_id);
/* Q45. */
CREATE INDEX idx_customers_regdate ON customers.customers (registration_date);
/* Q46. */
CREATE INDEX idx_returns_orderid ON sales.returns (order_id);
/* Q47. */
CREATE INDEX idx_orders_custid_named ON sales.orders (cust_id);
/* Q48. */
CREATE INDEX idx_employees_salary ON stores.employees (salary);
/* Q49. */
CREATE INDEX idx_tickets_agentid ON support.tickets (agent_id);
/* Q50. */
DROP INDEX sales.idx_orders_custid_named;

/* ============================================================
   SECTION C: VERIFY WITH EXPLAIN (25)
   ------------------------------------------------------------ */
/* Q51. */
EXPLAIN SELECT * FROM sales.orders WHERE cust_id = 1234;
/* Q52. */
CREATE INDEX idx_v_orders_custid ON sales.orders (cust_id);
ANALYZE sales.orders;
EXPLAIN SELECT * FROM sales.orders WHERE cust_id = 1234;
/* Q53. */
EXPLAIN SELECT * FROM sales.orders WHERE order_date BETWEEN DATE '2025-01-01' AND DATE '2025-01-31';
/* Q54. */
EXPLAIN SELECT * FROM customers.customers WHERE email = 'someone@example.com';
/* Q55. */
EXPLAIN SELECT * FROM customers.customers WHERE LOWER(email) = 'someone@example.com';
/* Q56. */
EXPLAIN SELECT o.order_id FROM sales.orders o JOIN customers.customers c ON c.customer_id = o.cust_id WHERE c.customer_id = 1234;
/* Q57. */
EXPLAIN SELECT * FROM sales.orders ORDER BY order_date LIMIT 10;
/* Q58. */
EXPLAIN SELECT COUNT(*) FROM sales.orders;
/* Q59. */
EXPLAIN SELECT * FROM products.products WHERE brand_id = 10;
/* Q60. */
EXPLAIN SELECT * FROM sales.orders WHERE order_status = 'Delivered';
/* Q61. */
EXPLAIN SELECT oi.order_item_id FROM sales.order_items oi JOIN products.products p ON p.product_id = oi.prod_id WHERE p.product_id = 500;
/* Q62. */
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE cust_id = 1234;
/* Q63. */
EXPLAIN SELECT cust_id FROM sales.orders WHERE cust_id = 1234;
/* Q64. */
EXPLAIN SELECT * FROM sales.orders WHERE cust_id = 1234;
/* Q65. */
EXPLAIN SELECT * FROM sales.orders WHERE order_date BETWEEN DATE '2025-06-01' AND DATE '2025-06-30';
/* Q66. */
EXPLAIN SELECT * FROM customers.customers WHERE email LIKE '%gmail.com';
/* Q67. */
EXPLAIN SELECT * FROM customers.customers WHERE email LIKE 'a%';
/* Q68. */
EXPLAIN SELECT * FROM products.products WHERE price > 10000;
/* Q69. */
EXPLAIN SELECT * FROM sales.orders WHERE order_status = 'Delivered';
/* Q70. */
EXPLAIN SELECT * FROM customers.reviews WHERE customer_id = 1234;
/* Q71. */
EXPLAIN SELECT * FROM sales.orders WHERE cust_id = 1234;
/* Q72. */
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM sales.orders WHERE cust_id = 1234;
/* Q73. */
EXPLAIN SELECT * FROM sales.orders WHERE store_id = 10;
/* Q74. */
ANALYZE sales.orders;
/* Q75. */
EXPLAIN SELECT * FROM sales.orders WHERE store_id = 10 AND order_status = 'Delivered';
DROP INDEX sales.idx_v_orders_custid;

/* ============================================================
   SECTION D: INVENTORY & CLEANUP (25)
   ------------------------------------------------------------ */
/* Q76. */
SELECT indexname, indexdef FROM pg_indexes WHERE schemaname = 'sales' AND tablename = 'orders';
/* Q77. */
SELECT tablename, indexname, indexdef FROM pg_indexes WHERE schemaname = 'sales' ORDER BY tablename, indexname;
/* Q78. */
SELECT schemaname, tablename, COUNT(*) AS index_count FROM pg_indexes GROUP BY schemaname, tablename ORDER BY index_count DESC;
/* Q79. */
SELECT indexdef FROM pg_indexes WHERE indexname = 'orders_pkey';
/* Q80. */
SELECT indexname, indexdef FROM pg_indexes WHERE schemaname = 'customers' AND tablename = 'customers';
/* Q81. */
SELECT indexname, indexdef FROM pg_indexes WHERE schemaname = 'sales' AND tablename = 'orders';
/* Q82. */
SELECT tablename FROM pg_tables t WHERE schemaname = 'sales' AND NOT EXISTS (SELECT 1 FROM pg_indexes i WHERE i.schemaname = t.schemaname AND i.tablename = t.tablename AND i.indexname NOT LIKE '%_pkey');
/* Q83. */
SELECT indexname, indexdef, indexdef LIKE '%UNIQUE%' AS is_unique FROM pg_indexes WHERE schemaname = 'sales' AND tablename = 'orders';
/* Q84. */
SELECT indexname, pg_size_pretty(pg_relation_size((schemaname || '.' || indexname)::regclass)) AS index_size FROM pg_indexes WHERE schemaname = 'sales' AND tablename = 'orders';
/* Q85. */
SELECT tablename, LEFT(indexdef, POSITION('(' IN indexdef)) AS lead_expr, COUNT(*) FROM pg_indexes WHERE schemaname = 'sales' GROUP BY tablename, lead_expr HAVING COUNT(*) > 1;
/* Q86. */
DROP INDEX IF EXISTS sales.idx_orders_custid;
/* Q87. */
DROP INDEX IF EXISTS sales.idx_orders_custid;
DROP INDEX IF EXISTS sales.idx_orders_orderdate;
DROP INDEX IF EXISTS customers.idx_customers_email;
DROP INDEX IF EXISTS products.idx_products_brandid;
DROP INDEX IF EXISTS sales.idx_orderitems_prodid;
DROP INDEX IF EXISTS support.idx_tickets_customerid;
DROP INDEX IF EXISTS customers.idx_reviews_productid;
DROP INDEX IF EXISTS stores.idx_employees_storeid;
DROP INDEX IF EXISTS sales.idx_orders_storeid;
DROP INDEX IF EXISTS web_events.idx_pageviews_sessionid;
DROP INDEX IF EXISTS call_center.idx_calls_customerid;
DROP INDEX IF EXISTS sales.idx_shipments_orderid;
DROP INDEX IF EXISTS products.idx_products_price;
DROP INDEX IF EXISTS loyalty.idx_members_tierid;
DROP INDEX IF EXISTS customers.idx_addresses_customerid;
DROP INDEX IF EXISTS sales.idx_orders_orderstatus;
DROP INDEX IF EXISTS payroll.idx_payslips_employeeid;
DROP INDEX IF EXISTS marketing.idx_adsspend_campaignid;
DROP INDEX IF EXISTS supply_chain.idx_invsnap_productid;
DROP INDEX IF EXISTS customers.idx_customers_regdate;
DROP INDEX IF EXISTS sales.idx_returns_orderid;
DROP INDEX IF EXISTS stores.idx_employees_salary;
DROP INDEX IF EXISTS support.idx_tickets_agentid;
/* Q88. */
SELECT indexname, indexdef FROM pg_indexes WHERE schemaname = 'sales' AND tablename = 'orders';
/* Q89. */
SELECT indexname, indexdef FROM pg_indexes WHERE schemaname = 'products' AND tablename = 'products';
/* Q90. */
SELECT indexname, indexdef FROM pg_indexes WHERE schemaname = 'sales' AND tablename = 'orders' AND indexdef LIKE '%pkey%';
/* Q91. */
SELECT schemaname, relname AS tablename, indexrelname AS indexname, pg_size_pretty(pg_relation_size(indexrelid)) AS index_size FROM pg_stat_user_indexes ORDER BY pg_relation_size(indexrelid) DESC LIMIT 10;
/* Q92. */
SELECT indexname, indexdef FROM pg_indexes WHERE schemaname = 'sales' AND tablename = 'order_items';
/* Q93. */
SELECT tc.tbl, tc.column_name FROM (SELECT 'sales.order_items' AS tbl, 'prod_id' AS column_name) tc WHERE NOT EXISTS (SELECT 1 FROM pg_indexes i WHERE i.schemaname = 'sales' AND i.tablename = 'order_items' AND i.indexdef LIKE '%prod_id%');
/* Q94. */
SELECT indexname, indexdef FROM pg_indexes WHERE schemaname NOT IN ('pg_catalog') AND indexdef LIKE '%WHERE%';
/* Q95. */
SELECT indexname, indexdef FROM pg_indexes WHERE schemaname NOT IN ('pg_catalog') AND indexdef ~ '\(\w+\([^)]*\)\)';
/* Q96. Dropping an index never changes query results - it only removes the shortcut the planner used to fetch them, so the same rows come back, just via a (possibly slower) scan. */
/* Q97. */
CREATE INDEX idx_sales_orders_custid ON sales.orders (cust_id);
DROP INDEX sales.idx_sales_orders_custid;
/* Q98. */
SELECT * FROM pg_indexes WHERE schemaname = 'sales' AND tablename = 'orders';
/* Q99. */
SELECT schemaname, tablename, COUNT(*) AS index_count, COUNT(*) > 5 AS flagged FROM pg_indexes GROUP BY schemaname, tablename ORDER BY index_count DESC;
/* Q100. */
SELECT tablename, indexname, indexdef, pg_size_pretty(pg_relation_size((schemaname || '.' || indexname)::regclass)) AS index_size FROM pg_indexes WHERE schemaname = 'sales' ORDER BY tablename, indexname;

/* ============================================================
   END OF ANSWER KEY - Indexing for Analysts - EASY LEVEL (100/100)
   ============================================================ */
