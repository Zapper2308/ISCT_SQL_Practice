/* ============================================================
   ANSWER KEY - Indexing for Analysts (HARD LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1.  (a, b, c) - a first (equality dive), then b (range, still index-ordered within each a), then c so the trailing ORDER BY needs no separate Sort; b being a range means c can't drive further index ordering across different b values, but Postgres still avoids a full Sort for the common single-a-value case. */
/* Q2.  Equality narrows to a single, precise branch of the tree; the range column must come right after so the B-Tree can still binary-search a contiguous slice; a trailing sort column then lines up with the index's own order within that slice. */
/* Q3.  INCLUDE beats extending the key when the extra columns are only needed for output/covering (Index Only Scan), not for filtering or sorting - putting them in the key would bloat every internal B-Tree entry and could break intended sort order. */
/* Q4.  Compare pg_indexes definitions per table: if one index's leading columns are an exact prefix of another's (e.g. (a) vs (a,b)), the shorter one is redundant for equality/prefix lookups. */
/* Q5.  Every index must be updated on every INSERT/UPDATE/DELETE, so a write-heavy table pays that cost repeatedly while the read benefit may be rare - too many indexes turn cheap writes into expensive ones. */
/* Q6.  When the predicate matches a large fraction of the table's rows (low selectivity) - the planner estimates a Seq Scan will touch about as much data anyway, cheaper than index lookups plus random heap fetches. */
/* Q7.  Pick a predicate that isolates a small, frequently-queried subset (e.g. WHERE status='Open') - narrow enough to stay small, but matching real, common query filters so it actually gets used. */
/* Q8.  Every column the query needs must be in the index (key or INCLUDE), and the visibility map must show the relevant heap pages as all-visible (recently VACUUMed) so Postgres can skip the heap entirely. */
/* Q9.  CONCURRENTLY avoids the SHARE lock that blocks writes during a normal build, at the cost of a slower two-pass, non-transactional build; if it's interrupted or fails, it leaves behind an unusable INVALID index that must be dropped and rebuilt. */
/* Q10. BitmapAnd wins when two independently useful single-column indexes exist and neither predicate alone is selective enough; a single composite wins when the same two columns are filtered together often enough to justify one dedicated, more efficient index. */
/* Q11. Postgres matches expression indexes by comparing the parsed expression tree, not by string similarity, so LOWER(email) vs UPPER(email) or a differently-cast argument won't match even though they're conceptually related. */
/* Q12. Build one composite (a,b) - the leftmost-prefix rule means it serves both WHERE a=? (prefix) and WHERE a=? AND b=? without needing a second index on (a) alone. */
/* Q13. When the ORDER BY column's DESC/ASC direction matches the index's declared direction (after equality-filtered leading columns), so Postgres can walk the index in the needed order and skip a Sort node, which matters most with LIMIT (avoids sorting the whole result). */
/* Q14. Index the foreign-key column on the "many" side of the join (e.g. order_items.prod_id), since that's the side Postgres must repeatedly probe once per row from the other side. */
/* Q15. A high-cardinality GROUP BY key produces nearly as many distinct groups as there are rows, so an index doesn't meaningfully narrow anything - Postgres still has to visit nearly every row either way (often via a HashAggregate over a Seq Scan). */
/* Q16. n_distinct tells the planner how many distinct values a column has (affecting expected group/row counts); the MCV (most common values) list and its frequencies let it estimate exactly how selective a given equality filter really is, beyond a generic uniform-distribution guess. */
/* Q17. A wide covering index costs more disk space and more per-write maintenance, but pays it back by letting matching SELECTs become pure Index Only Scans with no heap access - worth it for hot, read-heavy queries, wasteful for rarely-run ones. */
/* Q18. pg_stat_user_indexes.idx_scan tells you how many times an index has actually been used since the stats were last reset - a persistent 0 across real workload time signals a candidate for dropping. */
/* Q19. When two columns are correlated in a way single-column statistics can't capture (e.g. city implies state), CREATE STATISTICS lets the planner estimate their combined selectivity correctly without needing an index at all. */
/* Q20. Rewriting a bad query (removing a function wrapper, avoiding needless subqueries, fixing a join) can eliminate the need for a new index entirely and helps every future query on that table, not just one. */
/* Q21. Partial + covering: WHERE status='Open' as the partial predicate, with the report's displayed columns in INCLUDE - the index stays small (few open rows) while still answering the "open tickets list" query as a pure Index Only Scan. */
/* Q22. A very selective leading column (few rows per value) lets the composite narrow sharply before the next column is even considered; a low-selectivity leading column leaves so many rows that the trailing columns barely help. */
/* Q23. REINDEX rebuilds an index from scratch to remove bloat (dead entries from updates/deletes); it's needed when pg_stat/pgstattuple shows significant bloat or an index has become unusably large relative to the table. */
/* Q24. Every join and every DELETE/UPDATE on the referencing table has to scan the whole child table for matches without an index on the FK column, turning what should be a fast lookup into a full scan each time. */
/* Q25. Rewrite the query first -> check/update statistics (ANALYZE, extended stats) -> add a targeted index if still needed -> if the same expensive aggregate keeps recomputing, push it into a materialized view (Day 25). */

/* ============================================================
   SECTION B: DESIGN THE INDEX FOR A QUERY (25)
   ------------------------------------------------------------ */
/* Q26. */
CREATE INDEX idx_h_orders_cust_date_desc ON sales.orders (cust_id, order_date DESC);
EXPLAIN SELECT * FROM sales.orders WHERE cust_id = 1234 ORDER BY order_date DESC LIMIT 20;
/* Q27. */
CREATE INDEX idx_h_orders_store_date ON sales.orders (store_id, order_date);
EXPLAIN SELECT * FROM sales.orders WHERE store_id = 10 AND order_date >= DATE '2025-01-01';
/* Q28. */
CREATE INDEX idx_h_products_brand_price ON products.products (brand_id, price);
EXPLAIN SELECT * FROM products.products WHERE brand_id = 10 AND price BETWEEN 100 AND 5000;
/* Q29. */
CREATE INDEX idx_h_orderitems_prodid ON sales.order_items (prod_id);
EXPLAIN SELECT * FROM sales.order_items oi JOIN products.products p ON p.product_id = oi.prod_id WHERE oi.prod_id = 500;
/* Q30. */
CREATE INDEX idx_h_orders_cancelled_date ON sales.orders (order_date) WHERE order_status = 'Cancelled';
EXPLAIN SELECT * FROM sales.orders WHERE order_status = 'Cancelled' AND order_date >= DATE '2025-01-01';
/* Q31. */
CREATE INDEX idx_h_reviews_prod_date_desc ON customers.reviews (product_id, review_date DESC);
EXPLAIN SELECT DISTINCT ON (product_id) * FROM customers.reviews WHERE product_id = 500 ORDER BY product_id, review_date DESC;
/* Q32. */
CREATE INDEX idx_h_tickets_agent_status ON support.tickets (agent_id, status);
EXPLAIN SELECT * FROM support.tickets WHERE agent_id = 10 AND status = 'Open';
/* Q33. */
CREATE INDEX idx_h_orders_nettotal_desc ON sales.orders (net_total DESC);
EXPLAIN SELECT * FROM sales.orders ORDER BY net_total DESC LIMIT 10;
/* Q34. */
CREATE INDEX idx_h_reviews_customerid ON customers.reviews (customer_id);
EXPLAIN SELECT * FROM customers.reviews WHERE customer_id = 1234;
/* Q35. */
CREATE INDEX idx_h_stores_region ON stores.stores (region_id);
EXPLAIN SELECT r.region_name, SUM(o.net_total) FROM sales.orders o JOIN stores.stores s ON s.store_id = o.store_id JOIN core.dim_region r ON r.region_id = s.region_id GROUP BY r.region_name;
/* Q36. */
CREATE INDEX idx_h_customers_lower_email ON customers.customers (LOWER(email));
EXPLAIN SELECT * FROM customers.customers WHERE LOWER(email) = 'someone@example.com';
/* Q37. */
CREATE INDEX idx_h_orders_ordermonth ON sales.orders ((date_trunc('month', order_date::timestamp)));
EXPLAIN SELECT * FROM sales.orders WHERE date_trunc('month', order_date::timestamp) = DATE '2025-06-01';
/* Q38. */
CREATE INDEX idx_h_orders_highvalue ON sales.orders (net_total) WHERE net_total > 50000;
EXPLAIN SELECT * FROM sales.orders WHERE net_total > 50000;
/* Q39. */
CREATE INDEX idx_h_invsnap_wh_prod_date ON supply_chain.inventory_snapshots (warehouse_id, product_id, snapshot_date);
EXPLAIN SELECT * FROM supply_chain.inventory_snapshots WHERE warehouse_id = 1 AND product_id = 500 AND snapshot_date = DATE '2025-06-01';
/* Q40. */
CREATE INDEX idx_h_adsspend_campaign_date ON marketing.ads_spend (campaign_id, spend_date);
EXPLAIN SELECT * FROM marketing.ads_spend WHERE campaign_id = 10 AND spend_date >= DATE '2025-01-01';
/* Q41. */
CREATE INDEX idx_h_employees_store_salary ON stores.employees (store_id, salary DESC);
EXPLAIN SELECT * FROM stores.employees WHERE store_id = 10 ORDER BY salary DESC;
/* Q42. */
CREATE INDEX idx_h_tickets_unresolved ON support.tickets (created_date) WHERE resolved_date IS NULL;
EXPLAIN SELECT * FROM support.tickets WHERE resolved_date IS NULL;
/* Q43. */
CREATE INDEX idx_h_orders_cust_date_inc ON sales.orders (cust_id, order_date) INCLUDE (net_total);
EXPLAIN SELECT cust_id, order_date, net_total FROM sales.orders WHERE cust_id = 1234;
/* Q44. */
CREATE INDEX idx_h_calls_reason_starttime ON call_center.calls (call_reason, call_start_time);
EXPLAIN SELECT * FROM call_center.calls WHERE call_reason = 'Billing Issue' AND call_start_time >= TIMESTAMP '2025-01-01';
/* Q45. */
CREATE INDEX idx_h_addresses_pincode ON customers.addresses (pincode);
EXPLAIN SELECT * FROM customers.addresses WHERE pincode = '400001';
/* Q46. */
CREATE INDEX idx_h_orders_recent ON sales.orders (order_date) WHERE order_date >= DATE '2025-01-01';
EXPLAIN SELECT * FROM sales.orders WHERE order_date >= DATE '2025-06-01';
/* Q47. */
CREATE INDEX idx_h_products_brand_price_top ON products.products (brand_id, price DESC);
EXPLAIN SELECT * FROM products.products WHERE brand_id = 10 ORDER BY price DESC LIMIT 5;
/* Q48. */
CREATE INDEX idx_h_customers_phone_digits ON customers.customers ((regexp_replace(phone, '\D', '', 'g')));
EXPLAIN SELECT * FROM customers.customers WHERE regexp_replace(phone, '\D', '', 'g') = '9876543210';
/* Q49. */
EXPLAIN SELECT * FROM sales.orders WHERE cust_id = 1234 ORDER BY order_date DESC LIMIT 20;
/* Q50. */
DROP INDEX IF EXISTS sales.idx_h_orders_cust_date_desc;
DROP INDEX IF EXISTS sales.idx_h_orders_store_date;
DROP INDEX IF EXISTS products.idx_h_products_brand_price;
DROP INDEX IF EXISTS sales.idx_h_orderitems_prodid;
DROP INDEX IF EXISTS sales.idx_h_orders_cancelled_date;
DROP INDEX IF EXISTS customers.idx_h_reviews_prod_date_desc;
DROP INDEX IF EXISTS support.idx_h_tickets_agent_status;
DROP INDEX IF EXISTS sales.idx_h_orders_nettotal_desc;
DROP INDEX IF EXISTS customers.idx_h_reviews_customerid;
DROP INDEX IF EXISTS stores.idx_h_stores_region;
DROP INDEX IF EXISTS customers.idx_h_customers_lower_email;
DROP INDEX IF EXISTS sales.idx_h_orders_ordermonth;
DROP INDEX IF EXISTS sales.idx_h_orders_highvalue;
DROP INDEX IF EXISTS supply_chain.idx_h_invsnap_wh_prod_date;
DROP INDEX IF EXISTS marketing.idx_h_adsspend_campaign_date;
DROP INDEX IF EXISTS stores.idx_h_employees_store_salary;
DROP INDEX IF EXISTS support.idx_h_tickets_unresolved;
DROP INDEX IF EXISTS sales.idx_h_orders_cust_date_inc;
DROP INDEX IF EXISTS call_center.idx_h_calls_reason_starttime;
DROP INDEX IF EXISTS customers.idx_h_addresses_pincode;
DROP INDEX IF EXISTS sales.idx_h_orders_recent;
DROP INDEX IF EXISTS products.idx_h_products_brand_price_top;
DROP INDEX IF EXISTS customers.idx_h_customers_phone_digits;

/* ============================================================
   SECTION C: COVERING & PARTIAL IN PRACTICE (25)
   ------------------------------------------------------------ */
/* Q51. */
CREATE INDEX idx_h_orders_history_cover ON sales.orders (cust_id, order_date DESC) INCLUDE (net_total, order_status);
/* Q52. */
VACUUM ANALYZE sales.orders;
EXPLAIN (ANALYZE) SELECT cust_id, order_date, net_total, order_status FROM sales.orders WHERE cust_id = 1234 ORDER BY order_date DESC;
/* Q53. */
CREATE INDEX idx_h_tickets_open_partial ON support.tickets (agent_id) WHERE resolved_date IS NULL;
SELECT pg_size_pretty(pg_relation_size('support.idx_h_tickets_open_partial'::regclass)) AS partial_size;
/* Q54. */
CREATE INDEX idx_h_orders_cancelled_partial ON sales.orders (order_date) WHERE order_status = 'Cancelled';
EXPLAIN SELECT * FROM sales.orders WHERE order_status = 'Cancelled' AND order_date >= DATE '2025-01-01';
EXPLAIN SELECT * FROM sales.orders WHERE order_status = 'Delivered' AND order_date >= DATE '2025-01-01';
/* Q55. */
CREATE INDEX idx_h_orders_store_list_cover ON sales.orders (store_id, order_date DESC) INCLUDE (net_total, order_status, cust_id);
/* Q56. */
CREATE INDEX idx_h_orders_highvalue_cover ON sales.orders (net_total DESC) INCLUDE (cust_id, store_id, order_date) WHERE net_total > 50000;
/* Q57. */
CREATE INDEX idx_h_customers_lower_email_platinum ON customers.customers (LOWER(email)) WHERE tier = 'Platinum';
/* Q58. */
CREATE INDEX idx_h_orderitems_prodid_cover ON sales.order_items (prod_id) INCLUDE (quantity, net_amount);
EXPLAIN SELECT prod_id, quantity, net_amount FROM sales.order_items WHERE prod_id = 500;
/* Q59. */
CREATE INDEX idx_h_reviews_recent ON customers.reviews (review_date) WHERE review_date >= DATE '2025-01-01';
/* Q60. */
CREATE INDEX idx_h_orders_cust_cover_sum ON sales.orders (cust_id) INCLUDE (net_total);
EXPLAIN SELECT cust_id, SUM(net_total) FROM sales.orders WHERE cust_id = 1234 GROUP BY cust_id;
/* Q61. */
CREATE INDEX idx_h_reviews_negative ON customers.reviews (product_id) WHERE rating <= 2;
EXPLAIN SELECT * FROM customers.reviews WHERE rating <= 2;
/* Q62. */
CREATE INDEX idx_h_products_margin ON products.products ((price - cost_price));
EXPLAIN SELECT * FROM products.products WHERE (price - cost_price) > 1000;
/* Q63. */
CREATE INDEX idx_h_orders_cust_date_desc_cover ON sales.orders (cust_id, order_date DESC) INCLUDE (order_status, net_total);
EXPLAIN SELECT DISTINCT ON (cust_id) * FROM sales.orders WHERE cust_id = 1234 ORDER BY cust_id, order_date DESC;
/* Q64. */
CREATE INDEX idx_h_customers_recent_reg ON customers.customers (registration_date) WHERE registration_date >= DATE '2025-01-01';
/* Q65. */
EXPLAIN SELECT cust_id, order_date, net_total, order_status FROM sales.orders WHERE cust_id = 1234;
EXPLAIN SELECT * FROM sales.orders WHERE cust_id = 1234;
/* Q66. INCLUDE columns are stored in the leaf pages purely for retrieval - they're never used to order the B-Tree or to satisfy an equality/range predicate, so adding them doesn't change which rows an index scan visits or in what order, it only lets more SELECT lists be answered without a heap fetch. */
/* Q67. */
EXPLAIN SELECT * FROM sales.orders WHERE order_status = 'Cancelled' AND order_date >= DATE '2025-01-01';
EXPLAIN SELECT * FROM sales.orders WHERE order_status = 'Shipped' AND order_date >= DATE '2025-01-01';
/* Q68. */
CREATE INDEX idx_h_adsspend_platform_date_cover ON marketing.ads_spend (platform, spend_date) INCLUDE (amount);
/* Q69. */
CREATE INDEX idx_h_orders_unshipped ON sales.orders (order_date) WHERE order_status IN ('Processing', 'Out for Delivery');
/* Q70. */
SELECT pg_size_pretty(pg_relation_size('sales.idx_h_orders_store_list_cover'::regclass)) AS covering_size,
       pg_size_pretty(pg_relation_size('sales.idx_h_orders_cust_date_desc_cover'::regclass)) AS other_size;
/* Q71. */
EXPLAIN SELECT * FROM sales.orders WHERE order_status = 'Delivered' AND order_date >= DATE '2025-01-01';
/* Q72. */
CREATE INDEX idx_h_payslips_emp_year_cover ON payroll.pay_slips (employee_id, salary_year) INCLUDE (net_salary);
EXPLAIN SELECT employee_id, salary_year, net_salary FROM payroll.pay_slips WHERE employee_id = 100 AND salary_year = 2025;
/* Q73. */
CREATE INDEX idx_h_customers_lower_email_platinum2 ON customers.customers (LOWER(email)) INCLUDE (tier, registration_date) WHERE tier = 'Platinum';
/* Q74. */
EXPLAIN ANALYZE SELECT prod_id, quantity, net_amount FROM sales.order_items WHERE prod_id = 500;
/* Q75. */
DROP INDEX IF EXISTS sales.idx_h_orders_history_cover;
DROP INDEX IF EXISTS support.idx_h_tickets_open_partial;
DROP INDEX IF EXISTS sales.idx_h_orders_cancelled_partial;
DROP INDEX IF EXISTS sales.idx_h_orders_store_list_cover;
DROP INDEX IF EXISTS sales.idx_h_orders_highvalue_cover;
DROP INDEX IF EXISTS customers.idx_h_customers_lower_email_platinum;
DROP INDEX IF EXISTS sales.idx_h_orderitems_prodid_cover;
DROP INDEX IF EXISTS customers.idx_h_reviews_recent;
DROP INDEX IF EXISTS sales.idx_h_orders_cust_cover_sum;
DROP INDEX IF EXISTS customers.idx_h_reviews_negative;
DROP INDEX IF EXISTS products.idx_h_products_margin;
DROP INDEX IF EXISTS sales.idx_h_orders_cust_date_desc_cover;
DROP INDEX IF EXISTS customers.idx_h_customers_recent_reg;
DROP INDEX IF EXISTS marketing.idx_h_adsspend_platform_date_cover;
DROP INDEX IF EXISTS sales.idx_h_orders_unshipped;
DROP INDEX IF EXISTS payroll.idx_h_payslips_emp_year_cover;
DROP INDEX IF EXISTS customers.idx_h_customers_lower_email_platinum2;

/* ============================================================
   SECTION D: REDUNDANCY, LIMITS & WHEN-NOT-TO-INDEX (25)
   ------------------------------------------------------------ */
/* Q76. (a) and (a,b) are both redundant once (a,b,c) exists - any equality/prefix lookup on a alone or (a,b) is already served by the leftmost-prefix rule of the widest composite; only (a,b,c) needs to be kept. */
/* Q77. */
SELECT i1.indexname AS narrow_index, i2.indexname AS wider_index
FROM pg_indexes i1
JOIN pg_indexes i2 ON i1.schemaname = i2.schemaname AND i1.tablename = i2.tablename AND i1.indexname <> i2.indexname
WHERE i1.schemaname = 'sales' AND i1.tablename = 'orders'
  AND i2.indexdef LIKE regexp_replace(i1.indexdef, '.*USING btree \(([^)]*)\).*', '%\1%');
/* Q78. */
EXPLAIN SELECT SUM(net_total) FROM sales.orders;
/* Q79. */
CREATE INDEX idx_h_orders_status_demo ON sales.orders (order_status);
EXPLAIN SELECT * FROM sales.orders WHERE order_status = 'Delivered';
DROP INDEX IF EXISTS sales.idx_h_orders_status_demo;
/* Q80. */
EXPLAIN SELECT cust_id, COUNT(*) FROM sales.orders GROUP BY cust_id;
/* Q81. Keep: an index whose leading column matches a frequent, selective WHERE clause (e.g. cust_id on orders). Drop: a single-column index that's a strict prefix of a wider composite already on the same table, an index on a rarely-filtered column, and an index whose predicate never matches any real query's WHERE clause. */
/* Q82. */
CREATE STATISTICS IF NOT EXISTS stat_h_stores_region_city (dependencies) ON region_id, city FROM stores.stores;
ANALYZE stores.stores;
EXPLAIN SELECT * FROM stores.stores WHERE region_id = 10 AND city = 'Mumbai';
DROP STATISTICS IF EXISTS stat_h_stores_region_city;
/* Q83. */
EXPLAIN SELECT customer_id, MAX(order_date) FROM sales.orders o JOIN customers.customers c ON c.customer_id = o.cust_id GROUP BY customer_id;
/* Q84. Adding 3 indexes to a hot table roughly triples the per-row write cost for every INSERT/UPDATE/DELETE (each index needs its own B-Tree entry written and WAL-logged), which can turn a table that handled thousands of writes/sec comfortably into one that struggles, even though reads get faster. */
/* Q85. */
SELECT schemaname, tablename, indexname, indexdef FROM pg_indexes WHERE schemaname = 'sales' ORDER BY tablename, indexname;
/* Q86. */
CREATE INDEX idx_h_orders_wide_cover ON sales.orders (cust_id, order_date, store_id) INCLUDE (net_total, order_status, gross_total, discount_amount, payment_mode_id);
SELECT pg_size_pretty(pg_relation_size('sales.idx_h_orders_wide_cover'::regclass)) AS wide_index_size;
DROP INDEX IF EXISTS sales.idx_h_orders_wide_cover;
/* Q87. */
CREATE INDEX idx_h_orders_store_solo ON sales.orders (store_id);
CREATE INDEX idx_h_orders_status_solo ON sales.orders (order_status);
EXPLAIN SELECT * FROM sales.orders WHERE store_id = 10 AND order_status = 'Shipped';
DROP INDEX IF EXISTS sales.idx_h_orders_store_solo;
DROP INDEX IF EXISTS sales.idx_h_orders_status_solo;
/* Q88. An index whose name/columns never appear in any of the query patterns the team actually runs (checked against a saved query log or the app's known access patterns) is a strong candidate for being unused - pair this reasoning with pg_stat_user_indexes.idx_scan over a real observation window to confirm. */
/* Q89. CONCURRENTLY skips the SHARE lock that a plain CREATE INDEX holds for the whole build, so ongoing INSERT/UPDATE/DELETE on the table keep running instead of queueing behind the index build - the tradeoff is a slower, two-pass, non-atomic build that can leave an INVALID index if interrupted. */
/* Q90. When the predicate matches most of the table's rows (say order_status = 'Delivered' where the majority of orders end up Delivered) - the resulting index would still need to fetch nearly every row, giving little benefit over a Seq Scan while still costing space and write overhead. */
/* Q91. A leading-wildcard search like LIKE '%foo%' can't use a plain B-Tree at all (no fixed prefix to seek from); it needs a trigram GIN/GiST index (pg_trgm extension) instead, which isn't installed on RetailMart by default - flagged for accio_NN. */
/* Q92. ORDER BY random() picks a fresh random order every row, unrelated to any column's stored value, so no index (which is ordered by column value) can help; TABLESAMPLE reads a random subset of pages directly instead of sorting the whole table. */
/* Q93. */
SELECT tc.table_schema, tc.table_name, kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu ON kcu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_schema = 'sales'
  AND NOT EXISTS (
    SELECT 1 FROM pg_indexes i
    WHERE i.schemaname = tc.table_schema AND i.tablename = tc.table_name
      AND i.indexdef LIKE '%' || kcu.column_name || '%'
  );
/* Q94. There's no fixed universal threshold - it depends on table size and row width, but as a rule of thumb once a filter is expected to return more than roughly 5-10% of a table's rows, a Seq Scan usually beats an Index Scan because of the extra random heap-page fetches an index incurs. */
/* Q95. An expensive, repeatedly-run aggregate over a large, slow-changing dataset (e.g. a nightly revenue rollup) is better served by a materialized view refreshed on a schedule; a simple filtered lookup that changes with every new row is better served by a live index. */
/* Q96. */
SELECT i1.schemaname, i1.tablename, i1.indexname AS redundant_index
FROM pg_indexes i1
JOIN pg_indexes i2 ON i1.schemaname = i2.schemaname AND i1.tablename = i2.tablename AND i1.indexname <> i2.indexname
WHERE i1.indexname NOT LIKE '%pkey%'
  AND i2.indexdef LIKE '%' || split_part(split_part(i1.indexdef, '(', 2), ')', 1) || ',%';
/* Q97. Create: sales.orders(cust_id, order_date DESC) for the order-history panel, support.tickets(customer_id) for the support panel, customers.reviews(customer_id) for the reviews panel - the three FK-side single/composite indexes that back the dashboard's three most common per-customer lookups. */
/* Q98. */
CREATE INDEX idx_h_orders_dashboard ON sales.orders (cust_id, order_date DESC);
EXPLAIN SELECT * FROM sales.orders WHERE cust_id = 1234 ORDER BY order_date DESC LIMIT 20;
DROP INDEX IF EXISTS sales.idx_h_orders_dashboard;
/* Q99. Indexing policy: only index columns that appear in a real, frequent WHERE/JOIN/ORDER BY; prefer one well-chosen composite over several single-column indexes; verify every new index with EXPLAIN before keeping it; review pg_stat_user_indexes quarterly and drop anything with idx_scan=0; always build with CONCURRENTLY in production. */
/* Q100. */
SELECT tablename, COUNT(*) AS index_count, array_agg(indexname) AS index_names
FROM pg_indexes WHERE schemaname = 'sales'
GROUP BY tablename
ORDER BY tablename;

/* ============================================================
   END OF ANSWER KEY - Indexing for Analysts - HARD LEVEL (100/100)
   ============================================================ */
