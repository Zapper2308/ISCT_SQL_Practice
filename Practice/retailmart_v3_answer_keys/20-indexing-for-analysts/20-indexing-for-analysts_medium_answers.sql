/* ============================================================
   ANSWER KEY - Indexing for Analysts (MEDIUM LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1.  A composite index on (a,b) can only be used to search on b (or skip straight to a range on b) when a is also constrained - the index is ordered by a first, so b is only locally sorted within each a value; a query touching only b can't use that local order. */
/* Q2.  (a,b) is better when queries filter a=? AND b=? or a=? alone; decide by looking at which columns your actual WHERE clauses filter on and in what combination - put the most commonly-filtered-alone / most selective equality column first. */
/* Q3.  Yes to WHERE a=? alone (leftmost prefix); no to WHERE b=? alone (b isn't leftmost, so the index can't be used to jump to matching rows). */
/* Q4.  Column order matters for ORDER BY when the sort columns come after the equality-filtered columns in the same order (and same direction) as the index - then no separate Sort step is needed. */
/* Q5.  A partial index only covers rows matching a WHERE predicate; a good case is indexing just the rare/active subset, e.g. WHERE status='Open', so the index stays small and fast even though most rows are closed. */
/* Q6.  An expression index is built on the result of a function/expression (e.g. LOWER(email)) rather than a raw column, so queries filtering on that exact expression can use it. */
/* Q7.  INCLUDE(cols) stores extra, non-key columns alongside the index's key columns purely for retrieval, so a query selecting only key + INCLUDE columns can be answered from the index alone (Index Only Scan) without touching the table. */
/* Q8.  Equality first lets the B-Tree narrow to one exact branch, after which the range column's local ordering inside that branch can still be searched efficiently; putting the range column first would only narrow to a wide range, losing the benefit of the equality column's precision. */
/* Q9.  A single composite is better when queries commonly filter on both columns together, since one index lookup replaces two separate index scans plus a costly intersection. */
/* Q10. The planner can combine two single-column indexes with BitmapAnd when a query filters on both columns and each index alone is reasonably selective, building bitmaps from each and ANDing them before fetching rows. */
/* Q11. Only the 'Cancelled' rows are indexed, and if that's a small fraction of all orders, the resulting index is tiny compared to indexing every order_status. */
/* Q12. The query's WHERE clause must include a condition that the planner can prove implies the partial index's predicate (ideally the exact same condition). */
/* Q13. Postgres only uses an expression index when it can match the query's expression tree exactly (same function, same arguments, same casts) - a slightly different expression won't match. */
/* Q14. Extra indexes speed up SELECTs that filter on their columns, but every INSERT/UPDATE/DELETE must also update every index on that table, so writes get progressively slower as more indexes are added. */
/* Q15. An index whose leading column(s) exactly duplicate the leading column(s) of a wider composite index - the narrower one adds nothing the composite doesn't already cover for equality/prefix lookups. */
/* Q16. Because (a,b) already serves any query that filters on a alone via the leftmost-prefix rule, so a separate index on just (a) does the same job with no extra benefit. */
/* Q17. INCLUDE helps when you need extra columns purely for output/covering (not for filtering or sorting) - adding them to the key would bloat the key and could change sort order unnecessarily. */
/* Q18. A highly selective leading column narrows the search dramatically before the second column is even considered; a low-selectivity leading column leaves too many rows for the second column to meaningfully help. */
/* Q19. A partial index's predicate must evaluate the same way at query time as it did at index-build time (no volatile functions), so the planner can trust it always matches the same row set. */
/* Q20. (cust_id, order_date DESC) - cust_id for the equality lookup, order_date DESC so "most recent orders for this customer" needs no separate Sort step. */
/* Q21. If the index's column order and direction match the ORDER BY exactly (after any leading equality filters), Postgres can walk the index in order and skip an explicit Sort node entirely. */
/* Q22. Index bloat is wasted space from dead/stale index entries (rows updated or deleted since the last VACUUM) accumulating inside the index pages, caused by heavy UPDATE/DELETE traffic without enough vacuuming. */
/* Q23. CREATE INDEX CONCURRENTLY matters on a live production table where a plain CREATE INDEX's exclusive lock would block writes for the whole build - CONCURRENTLY avoids that lock at the cost of a slower two-pass build. */
/* Q24. ANALYZE refreshes statistics on the expression's values so the planner can estimate selectivity for the new expression index and decide whether it's worth using. */
/* Q25. Index the columns your GROUP BY / WHERE / ORDER BY actually filter or sort on together, as one composite matching that access pattern - not every column separately. */

/* ============================================================
   SECTION B: COMPOSITE INDEXES (25)
   ------------------------------------------------------------ */
/* Q26. */
CREATE INDEX idx_orders_cust_date ON sales.orders (cust_id, order_date);
/* Q27. */
EXPLAIN SELECT * FROM sales.orders WHERE cust_id = 1234 AND order_date >= DATE '2025-01-01';
/* Q28. */
EXPLAIN SELECT * FROM sales.orders WHERE cust_id = 1234;
/* Q29. */
EXPLAIN SELECT * FROM sales.orders WHERE order_date = DATE '2025-06-15';
/* Q30. */
CREATE INDEX idx_orders_store_date ON sales.orders (store_id, order_date);
EXPLAIN SELECT * FROM sales.orders WHERE store_id = 10 AND order_date >= DATE '2025-01-01';
/* Q31. */
CREATE INDEX idx_products_brand_price ON products.products (brand_id, price);
EXPLAIN SELECT * FROM products.products WHERE brand_id = 10 AND price > 500;
/* Q32. Put the equality column first: (supplier_id, price). A leading equality column lets the B-Tree dive straight to one supplier's slice; leading with a range column (price) would only narrow to a broad chunk of the tree, inside which supplier_id couldn't be searched efficiently. */
/* Q33. */
CREATE INDEX idx_orderitems_order_prod ON sales.order_items (order_id, prod_id);
EXPLAIN SELECT * FROM sales.order_items WHERE order_id = 1000 AND prod_id = 500;
/* Q34. */
CREATE INDEX idx_reviews_cust_date ON customers.reviews (customer_id, review_date);
EXPLAIN SELECT DISTINCT ON (customer_id) * FROM customers.reviews WHERE customer_id = 1234 ORDER BY customer_id, review_date DESC;
/* Q35. */
CREATE INDEX idx_tickets_agent_status ON support.tickets (agent_id, status);
EXPLAIN SELECT * FROM support.tickets WHERE agent_id = 10 AND status = 'Open';
/* Q36. */
CREATE INDEX idx_orders_cust_date_desc ON sales.orders (cust_id, order_date DESC);
/* Q37. */
EXPLAIN SELECT * FROM sales.orders WHERE cust_id = 1234 ORDER BY order_date DESC LIMIT 10;
/* Q38. */
CREATE INDEX idx_invsnap_wh_prod_date ON supply_chain.inventory_snapshots (warehouse_id, product_id, snapshot_date);
EXPLAIN SELECT * FROM supply_chain.inventory_snapshots WHERE warehouse_id = 1 AND product_id = 500 AND snapshot_date = DATE '2025-06-01';
/* Q39. */
CREATE INDEX idx_products_brandid_solo ON products.products (brand_id);
CREATE INDEX idx_products_price_solo ON products.products (price);
EXPLAIN SELECT * FROM products.products WHERE brand_id = 10 AND price > 5000;
DROP INDEX IF EXISTS products.idx_products_brandid_solo;
DROP INDEX IF EXISTS products.idx_products_price_solo;
/* Q40. */
CREATE INDEX idx_stores_region_city ON stores.stores (region_id, city);
/* Q41. */
CREATE INDEX idx_adsspend_campaign_date ON marketing.ads_spend (campaign_id, spend_date);
EXPLAIN SELECT * FROM marketing.ads_spend WHERE campaign_id = 10 AND spend_date >= DATE '2025-01-01';
/* Q42. */
CREATE INDEX idx_payslips_emp_year ON payroll.pay_slips (employee_id, salary_year);
EXPLAIN SELECT * FROM payroll.pay_slips WHERE employee_id = 100 AND salary_year = 2025;
/* Q43. */
CREATE INDEX idx_calls_reason_agent ON call_center.calls (call_reason, agent_id);
EXPLAIN SELECT * FROM call_center.calls WHERE call_reason = 'Billing Issue' AND agent_id = 10;
/* Q44. order_status='Delivered'/etc has low cardinality (few distinct values) while order_date>=? is a selective range, but the leftmost column must still be the equality one for the B-Tree dive to work: (order_status, order_date) - even though order_status alone is not very selective, it's the only way to combine an equality test with a range on order_date in one composite; if order_status turns out too low-selectivity to help at all, a partial index per status is often better. */
/* Q45. */
CREATE INDEX idx_orders_cust_ordermonth ON sales.orders (cust_id, (date_trunc('month', order_date::timestamp)));
/* Q46. */
EXPLAIN SELECT cust_id, order_date FROM sales.orders WHERE cust_id = 1234;
/* Q47. */
CREATE INDEX idx_orders_cust_date_inc ON sales.orders (cust_id, order_date) INCLUDE (net_total);
/* Q48. */
EXPLAIN SELECT cust_id, order_date, net_total FROM sales.orders WHERE cust_id = 1234;
/* Q49. */
CREATE INDEX idx_orders_custid_solo ON sales.orders (cust_id);
DROP INDEX IF EXISTS sales.idx_orders_custid_solo;
/* Q50. */
DROP INDEX IF EXISTS sales.idx_orders_cust_date;
DROP INDEX IF EXISTS sales.idx_orders_store_date;
DROP INDEX IF EXISTS products.idx_products_brand_price;
DROP INDEX IF EXISTS sales.idx_orderitems_order_prod;
DROP INDEX IF EXISTS customers.idx_reviews_cust_date;
DROP INDEX IF EXISTS support.idx_tickets_agent_status;
DROP INDEX IF EXISTS sales.idx_orders_cust_date_desc;
DROP INDEX IF EXISTS supply_chain.idx_invsnap_wh_prod_date;
DROP INDEX IF EXISTS stores.idx_stores_region_city;
DROP INDEX IF EXISTS marketing.idx_adsspend_campaign_date;
DROP INDEX IF EXISTS payroll.idx_payslips_emp_year;
DROP INDEX IF EXISTS call_center.idx_calls_reason_agent;
DROP INDEX IF EXISTS sales.idx_orders_cust_ordermonth;
DROP INDEX IF EXISTS sales.idx_orders_cust_date_inc;

/* ============================================================
   SECTION C: PARTIAL & EXPRESSION INDEXES (25)
   ------------------------------------------------------------ */
/* Q51. */
CREATE INDEX idx_orders_cancelled_date ON sales.orders (order_date) WHERE order_status = 'Cancelled';
/* Q52. */
EXPLAIN SELECT * FROM sales.orders WHERE order_status = 'Cancelled' AND order_date >= DATE '2025-01-01';
/* Q53. */
EXPLAIN SELECT * FROM sales.orders WHERE order_status = 'Delivered' AND order_date >= DATE '2025-01-01';
/* Q54. */
CREATE INDEX idx_tickets_unresolved ON support.tickets (created_date) WHERE resolved_date IS NULL;
/* Q55. */
EXPLAIN SELECT * FROM support.tickets WHERE resolved_date IS NULL;
/* Q56. */
CREATE INDEX idx_customers_lower_email ON customers.customers (LOWER(email));
/* Q57. */
EXPLAIN SELECT * FROM customers.customers WHERE LOWER(email) = 'someone@example.com';
/* Q58. */
CREATE INDEX idx_customers_fullname ON customers.customers ((first_name || ' ' || last_name));
/* Q59. */
EXPLAIN SELECT * FROM customers.customers WHERE (first_name || ' ' || last_name) = 'John Smith';
/* Q60. */
CREATE INDEX idx_orders_ordermonth ON sales.orders ((date_trunc('month', order_date::timestamp)));
/* Q61. */
EXPLAIN SELECT * FROM sales.orders WHERE date_trunc('month', order_date::timestamp) = DATE '2025-06-01';
/* Q62. */
CREATE INDEX idx_orders_highvalue ON sales.orders (net_total) WHERE net_total > 50000;
/* Q63. */
EXPLAIN SELECT * FROM sales.orders WHERE net_total > 50000;
/* Q64. */
CREATE INDEX idx_products_margin ON products.products ((price - cost_price));
/* Q65. */
EXPLAIN SELECT * FROM products.products WHERE (price - cost_price) > 1000;
/* Q66. A "partial unique" pattern would be CREATE UNIQUE INDEX ... ON customers.customers(email) WHERE <condition>, but RetailMart V3's customers.customers already has duplicate emails, so a true UNIQUE index (partial or not) on email would fail to build until the duplicates are cleaned up. */
/* Q67. */
CREATE INDEX idx_orders_recent ON sales.orders (order_date) WHERE order_date >= DATE '2025-01-01';
/* Q68. */
EXPLAIN SELECT * FROM sales.orders WHERE order_date >= DATE '2025-06-01';
/* Q69. */
CREATE INDEX idx_orders_orderyear ON sales.orders ((EXTRACT(YEAR FROM order_date)));
/* Q70. A plain range rewrite like order_date >= '2025-01-01' AND order_date < '2026-01-01' can use a normal B-Tree index on order_date directly (including for BETWEEN-style scans across years), while EXTRACT(YEAR FROM order_date) = 2025 only matches an expression index built on that exact expression - the range form is more flexible and often just as fast. */
/* Q71. */
CREATE INDEX idx_reviews_negative ON customers.reviews (product_id) WHERE rating <= 2;
/* Q72. */
EXPLAIN SELECT * FROM customers.reviews WHERE rating <= 2;
/* Q73. */
CREATE INDEX idx_customers_phone_digits ON customers.customers ((regexp_replace(phone, '\D', '', 'g')));
/* Q74. */
EXPLAIN SELECT * FROM customers.customers WHERE regexp_replace(phone, '\D', '', 'g') = '9876543210';
/* Q75. */
DROP INDEX IF EXISTS sales.idx_orders_cancelled_date;
DROP INDEX IF EXISTS support.idx_tickets_unresolved;
DROP INDEX IF EXISTS customers.idx_customers_lower_email;
DROP INDEX IF EXISTS customers.idx_customers_fullname;
DROP INDEX IF EXISTS sales.idx_orders_ordermonth;
DROP INDEX IF EXISTS sales.idx_orders_highvalue;
DROP INDEX IF EXISTS products.idx_products_margin;
DROP INDEX IF EXISTS sales.idx_orders_recent;
DROP INDEX IF EXISTS sales.idx_orders_orderyear;
DROP INDEX IF EXISTS customers.idx_reviews_negative;
DROP INDEX IF EXISTS customers.idx_customers_phone_digits;

/* ============================================================
   SECTION D: VERIFY & MEASURE (25)
   ------------------------------------------------------------ */
/* Q76. */
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE cust_id = 1234;
CREATE INDEX idx_m_orders_custid ON sales.orders (cust_id);
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE cust_id = 1234;
/* Q77. */
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE order_date BETWEEN DATE '2025-01-01' AND DATE '2025-03-31';
CREATE INDEX idx_m_orders_custdate ON sales.orders (cust_id, order_date);
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE cust_id = 1234 AND order_date BETWEEN DATE '2025-01-01' AND DATE '2025-03-31';
/* Q78. */
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM sales.orders WHERE cust_id = 1234;
/* Q79. */
CREATE INDEX idx_m_orders_custdatedesc ON sales.orders (cust_id, order_date DESC);
EXPLAIN SELECT * FROM sales.orders WHERE cust_id = 1234 ORDER BY order_date DESC LIMIT 5;
/* Q80. */
CREATE INDEX idx_m_orders_cover ON sales.orders (cust_id, order_date) INCLUDE (net_total);
EXPLAIN SELECT cust_id, order_date, net_total FROM sales.orders WHERE cust_id = 1234;
/* Q81. */
CREATE INDEX idx_m_orders_cancelled ON sales.orders (order_date) WHERE order_status = 'Cancelled';
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE order_status = 'Cancelled' AND order_date >= DATE '2025-01-01';
/* Q82. */
EXPLAIN SELECT * FROM sales.orders WHERE store_id = 10 AND order_status = 'Shipped';
/* Q83. */
CREATE INDEX idx_m_orders_store_status ON sales.orders (store_id, order_status);
EXPLAIN SELECT * FROM sales.orders WHERE store_id = 10 AND order_status = 'Shipped';
DROP INDEX IF EXISTS sales.idx_m_orders_store_status;
/* Q84. */
CREATE INDEX idx_m_orders_storeid_useless ON sales.orders (store_id);
EXPLAIN SELECT * FROM sales.orders WHERE cust_id = 1234;
DROP INDEX IF EXISTS sales.idx_m_orders_storeid_useless;
/* Q85. */
EXPLAIN SELECT * FROM sales.order_items oi JOIN products.products p ON p.product_id = oi.prod_id WHERE oi.prod_id = 500;
CREATE INDEX idx_m_orderitems_prodid ON sales.order_items (prod_id);
EXPLAIN SELECT * FROM sales.order_items oi JOIN products.products p ON p.product_id = oi.prod_id WHERE oi.prod_id = 500;
/* Q86. */
CREATE INDEX idx_m_customers_lower_email ON customers.customers (LOWER(email));
ANALYZE customers.customers;
EXPLAIN SELECT * FROM customers.customers WHERE LOWER(email) = 'someone@example.com';
/* Q87. */
EXPLAIN SELECT cust_id, order_date, order_status FROM sales.orders WHERE cust_id = 1234;
/* Q88. */
EXPLAIN SELECT * FROM sales.orders WHERE cust_id = 1234;
EXPLAIN SELECT * FROM sales.orders WHERE order_date = DATE '2025-06-15';
/* Q89. */
EXPLAIN SELECT * FROM sales.orders ORDER BY order_date DESC LIMIT 10;
EXPLAIN SELECT * FROM sales.orders WHERE cust_id = 1234 ORDER BY order_date DESC LIMIT 10;
/* Q90. */
CREATE INDEX idx_m_orders_status ON sales.orders (order_status);
EXPLAIN SELECT * FROM sales.orders WHERE order_status = 'Delivered';
DROP INDEX IF EXISTS sales.idx_m_orders_status;
/* Q91. */
CREATE INDEX idx_m_orders_store_solo ON sales.orders (store_id);
CREATE INDEX idx_m_orders_status_solo ON sales.orders (order_status);
EXPLAIN SELECT * FROM sales.orders WHERE store_id = 10 AND order_status = 'Shipped';
DROP INDEX IF EXISTS sales.idx_m_orders_store_solo;
DROP INDEX IF EXISTS sales.idx_m_orders_status_solo;
/* Q92. */
CREATE INDEX idx_m_orders_status_full ON sales.orders (order_status);
CREATE INDEX idx_m_orders_cancelled_partial ON sales.orders (order_status) WHERE order_status = 'Cancelled';
SELECT pg_size_pretty(pg_relation_size('sales.idx_m_orders_status_full'::regclass)) AS full_index_size,
       pg_size_pretty(pg_relation_size('sales.idx_m_orders_cancelled_partial'::regclass)) AS partial_index_size;
DROP INDEX IF EXISTS sales.idx_m_orders_status_full;
DROP INDEX IF EXISTS sales.idx_m_orders_cancelled_partial;
/* Q93. */
EXPLAIN SELECT * FROM sales.orders WHERE cust_id = 1234;
DROP INDEX IF EXISTS sales.idx_m_orders_custid;
EXPLAIN SELECT * FROM sales.orders WHERE cust_id = 1234;
/* Q94. */
VACUUM sales.orders;
EXPLAIN (ANALYZE) SELECT cust_id, order_date, net_total FROM sales.orders WHERE cust_id = 1234;
/* Q95. */
EXPLAIN ANALYZE SELECT cust_id, COUNT(*) FROM sales.orders GROUP BY cust_id;
CREATE INDEX idx_m_orders_custid_group ON sales.orders (cust_id);
EXPLAIN ANALYZE SELECT cust_id, COUNT(*) FROM sales.orders GROUP BY cust_id;
DROP INDEX IF EXISTS sales.idx_m_orders_custid_group;
/* Q96. */
EXPLAIN SELECT * FROM sales.orders WHERE cust_id = 1234 ORDER BY order_date DESC LIMIT 20;
/* Q97. */
CREATE INDEX idx_m_products_brand_price_desc ON products.products (brand_id, price DESC);
EXPLAIN SELECT * FROM products.products WHERE brand_id = 10 ORDER BY price DESC LIMIT 5;
/* Q98. */
EXPLAIN SELECT * FROM products.products WHERE brand_id = 10 ORDER BY price DESC LIMIT 5;
DROP INDEX IF EXISTS products.idx_m_products_brand_price_desc;
/* Q99. */
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE store_id = 10 AND order_status = 'Delivered';
CREATE INDEX idx_m_orders_store_status_measure ON sales.orders (store_id, order_status);
EXPLAIN ANALYZE SELECT * FROM sales.orders WHERE store_id = 10 AND order_status = 'Delivered';
DROP INDEX IF EXISTS sales.idx_m_orders_store_status_measure;
/* Q100. A minimal customer-360 index set: (1) sales.orders(cust_id, order_date DESC) for the order-history panel, (2) customers.reviews(customer_id) for the reviews panel, (3) support.tickets(customer_id) for the support-history panel - three FK-side indexes cover the three most common "everything about this customer" lookups without over-indexing. */
DROP INDEX IF EXISTS sales.idx_m_orders_custdate;
DROP INDEX IF EXISTS sales.idx_m_orders_custdatedesc;
DROP INDEX IF EXISTS sales.idx_m_orders_cover;
DROP INDEX IF EXISTS sales.idx_m_orders_cancelled;
DROP INDEX IF EXISTS sales.idx_m_orderitems_prodid;
DROP INDEX IF EXISTS customers.idx_m_customers_lower_email;

/* ============================================================
   END OF ANSWER KEY - Indexing for Analysts - MEDIUM LEVEL (100/100)
   ============================================================ */
