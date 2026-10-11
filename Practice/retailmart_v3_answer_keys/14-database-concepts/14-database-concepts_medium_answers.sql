/* ============================================================
   ANSWER KEY - Database Concepts (MEDIUM LEVEL)
   Curriculum:   RetailMart V3
   Note: Day 14 is concept-only, so these are short reference
   answers (no queries to run/verify) matching each question.
   ============================================================ */

/* Q1.  It breaks 1NF - item1/item2/item3 is a repeating group of the same kind of fact crammed into separate columns instead of separate rows. */
/* Q2.  Orders(order_id, customer_name) plus a child table OrderItems(order_id, item) with one row per item, joined on order_id. */
/* Q3.  1NF is fine, but 2NF is violated: product_name depends only on product_id (part of the key), not on the whole (order_id, product_id) key - a partial dependency. */
/* Q4.  Split into Sales(order_id, product_id, qty) and Products(product_id, product_name); Sales' key is (order_id, product_id), Products' key is product_id. */
/* Q5.  A partial dependency - student_name depends on only student_id, part of the composite key (student_id, course_id), not the whole key. */
/* Q6.  Split into Students(student_id, student_name) and Enrollment(student_id, course_id, grade), keyed by student_id and (student_id, course_id) respectively. */
/* Q7.  A transitive dependency (emp_id -> dept_id -> dept_name); it violates 3NF since dept_name depends on dept_id, a non-key column, not directly on emp_id. */
/* Q8.  Split into Employee(emp_id, dept_id) and Department(dept_id, dept_name), each keyed by its own id, joined via dept_id. */
/* Q9.  It breaks 1NF (two phone numbers in one cell); fix it with a child table Phones(customer_id, phone_number) holding one row per number. */
/* Q10. Technically the column itself is atomic (a single JSON string), so it can be argued 1NF-compliant, but it hides structure the database can't query/index/join efficiently - bad for analytics, better to explode into a proper items table. */
/* Q11. customer_gstin depends only on customer_id, part of the (invoice_id, line_no) key - that's the partial dependency. */
/* Q12. With a single-column key, every non-key column automatically depends on the "whole" key (there's no smaller part of it to partially depend on), so 2NF partial-dependency violations can't occur. */
/* Q13. It breaks 3NF (a transitive dependency through region_id); it can be acceptable in a denormalized reporting table where read speed matters more than avoiding redundancy. */
/* Q14. publisher_city depends on publisher_id, not directly on book_id - a transitive dependency (book_id -> publisher_id -> publisher_city). */
/* Q15. It violates 3NF (gst_rate depends transitively on category_id, not prod_id); fix by moving gst_rate into a Category(category_id, category_name, gst_rate) table. */
/* Q16. No, it's not atomic - it bundles street, city, pincode and state into one value; normalizing splits it into separate columns, trading some storage/complexity for far easier filtering and aggregation by city/state. */
/* Q17. An inconsistency/update anomaly risk - the same city is spelled two ways; normalizing with a lookup table of canonical city names (or an FK to a cities dimension) prevents free-text drift. */
/* Q18. It risks massive data redundancy (repeating customer/product details on every row) and update anomalies (a single name change requiring edits across millions of rows). */
/* Q19. coupon_discount_pct is transitively dependent on coupon_code, not directly on order_id - it violates 3NF and should live in its own Coupons table. */
/* Q20. Students(student_id, ...), Courses(course_id, ...), Enrollments(student_id, course_id, ...) with student_id and course_id as foreign keys and (student_id, course_id) as Enrollments' composite primary key. */
/* Q21. courier_phone depends on courier_name, not directly on shipment_id - a transitive dependency; fix by moving courier details into a Couriers(courier_name, courier_phone) table. */
/* Q22. Yes - a table can satisfy 1NF (atomic values) yet still repeat non-key facts across rows, e.g. repeating a product's price on every order line, so updating the price means updating every row. */
/* Q23. Orders(order_id, product_id, product_name, customer_id) keyed by order_id is 2NF but not 3NF since product_name depends on product_id, not order_id; 3NF splits out Products(product_id, product_name). */
/* Q24. They hit the classic normalization-vs-performance tradeoff - maximal integrity/no redundancy came at the cost of query complexity and JOIN overhead for simple reports. */
/* Q25. Identify the natural key, split out repeating groups into child tables (1NF), remove partial dependencies on composite keys (2NF), then remove transitive dependencies between non-key columns (3NF), verifying each step preserves all original facts. */

/* Q26. order_id -> customer_id (each order belongs to exactly one customer). */
/* Q27. order_id -> customer_id and order_id -> order_date. */
/* Q28. A fully functional dependency means a non-key column depends on the entire composite key; a partial dependency means it depends on only part of that key. */
/* Q29. A -> D is partial, since D depends on only A, which is part of the (A,B) composite key, not the whole key. */
/* Q30. A determinant is the column (or columns) on the left side of a functional dependency that determines the value on the right; here product_id is the determinant of product_name. */
/* Q31. You can infer A -> C by transitivity; this inference rule is called transitivity (one of Armstrong's axioms). */
/* Q32. Because C ends up indirectly dependent on the key A through the non-key column B, meaning a non-key column (B) is determining another non-key column (C) - exactly what 3NF forbids. */
/* Q33. Split into R(emp_id, project_id, hours) and Employee(emp_id, emp_name), since emp_name depends only on emp_id, not the full (emp_id, project_id) key. */
/* Q34. A lossless decomposition is one where joining the resulting tables back together (via their keys) exactly reconstructs the original table, with no extra or missing rows. */
/* Q35. If rejoining produces spurious rows or loses information, queries built on the decomposed tables can silently return wrong or fabricated results - the decomposition must be verifiably lossless. */
/* Q36. roll_no and email are both candidate keys, since email is stated to be unique and roll_no is presumably unique too; either could serve as the primary key. */
/* Q37. Third Normal Form (3NF) is guaranteed, since that's the exact rule 3NF captures - full dependency on the whole key and nothing but the key. */
/* Q38. BCNF states that for every non-trivial functional dependency X -> Y, X must be a candidate key (a "super key"); it's stricter than 3NF because 3NF allows some exceptions when Y is itself part of a candidate key. */
/* Q39. A table like Courses(student_id, subject, teacher) where each teacher teaches only one subject: subject depends on the whole key, satisfying 3NF, but teacher -> subject also holds and teacher isn't a candidate key, violating BCNF. */
/* Q40. Because functional dependencies explain why certain columns are redundant or why a query returns duplicate/incorrect aggregates, helping analysts choose the right GROUP BY keys and spot bad joins. */
/* Q41. It's a redundant/derived-value problem - age can be computed from date_of_birth, so storing both risks them drifting apart; the fix is to store only date_of_birth and compute age when needed. */
/* Q42. The composite key (order_id, prod_id) is the determinant - it determines qty. */
/* Q43. It means every other column's value can be uniquely derived just by knowing the primary key's value - no two rows with the same key can differ in any other column. */
/* Q44. instructor_email depends on instructor, not directly on course_id - a transitive dependency that violates 3NF. */
/* Q45. List the composite primary key's parts, then check every non-key column: if any non-key column depends on only part of that composite key (not the whole thing), 2NF is violated. */
/* Q46. For every non-key column, ask whether it depends directly on the primary key or actually depends on another non-key column instead; if the latter, that's a transitive dependency and 3NF is violated. */
/* Q47. A surrogate key gives every row a unique id regardless of content, which can mask the fact that some non-key columns still functionally depend on each other rather than on the true business key. */
/* Q48. (store_id, product_id) -> stock is a full dependency on the whole composite key; store_id -> store_region is a partial dependency, since store_region depends on only part of the key. */
/* Q49. Split into Stock(store_id, product_id, stock) and Stores(store_id, store_region), removing the partial dependency by moving store_region to its own table keyed by store_id. */
/* Q50. Every column (or set of columns) that determines other columns must itself be able to uniquely identify a row - if it can predict other values, it must qualify as a key. */

/* Q51. BEGIN; INSERT INTO sales.orders (...) VALUES (...); INSERT INTO sales.order_items (...) VALUES (...), (...), (...); COMMIT; - all four inserts happen inside one transaction block. */
/* Q52. The whole transaction should be rolled back automatically, undoing the order insert and any successful item inserts too, so no partial/incomplete order is ever left behind. */
/* Q53. That single INSERT statement fails and is rejected (and the whole transaction is typically aborted unless it explicitly handles the error), because the CHECK constraint rejects quantity = 0. */
/* Q54. Isolation - the system must ensure the two concurrent sales don't both succeed in selling a unit that only exists once. */
/* Q55. A dirty read is when one transaction reads another transaction's uncommitted change - e.g. reading a discounted price a colleague is still mid-way through updating, which then gets rolled back. */
/* Q56. A non-repeatable read is when a transaction reads the same row twice and gets different values because another transaction committed a change in between - e.g. re-reading an order's status and finding it changed. */
/* Q57. A phantom read is when a transaction re-runs the same filtered query and sees new rows that weren't there before, because another transaction inserted matching rows in between - e.g. a COUNT(*) of today's orders changing mid-report. */
/* Q58. The table is left in a consistent state as of before the transaction started - the whole update is rolled back (atomicity), so no rows show the partial change; none of the 500,000 rows keep the update. */
/* Q59. Smaller batches reduce lock contention and transaction log/bloat, allow progress to be checkpointed, and limit the blast radius (and rollback cost) if something fails partway through. */
/* Q60. A deadlock is when two transactions each hold a lock the other needs and are both waiting on each other forever; the database detects the cycle and automatically kills (rolls back) one of them. */
/* Q61. Consistency (enforcing the FK constraint keeps the database in a valid state); it also supports referential integrity, a component of consistency. */
/* Q62. No - atomicity guarantees the refund's debit and credit either both apply or neither does, so the books can never be left half-updated/out of balance. */
/* Q63. ROLLBACK is safe because the transaction's changes are still only pending/uncommitted; once COMMIT runs, the changes are made permanent and durable, so there's nothing left to undo. */
/* Q64. A SAVEPOINT marks a point inside a transaction you can roll back to without undoing the entire transaction, letting you undo just part of the work. */
/* Q65. Long-running transactions hold locks and prevent cleanup (vacuum) for longer, blocking or slowing other transactions that need the same rows or system resources. */
/* Q66. Typically just the offending statement fails/is rejected, but by default the whole transaction is marked as aborted and must be rolled back - none of its work can be committed until then. */
/* Q67. The UNIQUE constraint is checked at the index level, so even if two inserts happen "simultaneously," the database serializes the check and rejects whichever one arrives second as a duplicate. */
/* Q68. If any one of those writes succeeds without the others, you get inventory reduced with no order recorded, or a payment charged with no order - so all three must be wrapped in one atomic transaction. */
/* Q69. They weakened Consistency, risking invalid data (like negative quantities or orphaned foreign keys) silently entering the database during the load. */
/* Q70. Optimistic concurrency assumes conflicts are rare, lets transactions proceed and only checks for conflicts at commit time; pessimistic concurrency locks the data up front to prevent any conflicting access at all. */
/* Q71. SELECT-only queries don't modify data, so there's nothing to make atomic or roll back - Postgres still wraps them in an implicit transaction, but no coordination with other writers is needed. */
/* Q72. READ UNCOMMITTED, READ COMMITTED, REPEATABLE READ, SERIALIZABLE. */
/* Q73. READ COMMITTED. */
/* Q74. SERIALIZABLE. */
/* Q75. Stronger isolation reduces concurrency and throughput (more locking/blocking), so it's reserved for workloads that truly need it rather than applied by default to everything. */

/* Q76. Today, region comes from stores.stores.region_id joining to core.dim_region; denormalizing it onto every order would speed up region-based reports but risk drift if a store's region ever changes and historical orders aren't updated. */
/* Q77. Recomputing SUM(order_items.net_amount) is safer whenever the stored net_total might be stale (e.g. after a late item edit, return, or a bug in the update logic) - the items are the source of truth. */
/* Q78. It duplicates city (already derivable via customers.addresses), risking two conflicting values per customer and violating 3NF's "no derivable/redundant data" principle for a minor join-avoidance convenience. */
/* Q79. A normalized alternative is a customers.tiers dimension table (tier_id, tier_name, benefits) with customers.customers holding a tier_id foreign key; pro: consistent tier names and easy benefit lookups; con: an extra join for simple tier filters. */
/* Q80. It resolves the many-to-many relationship between orders and products, holding a foreign key to each; its likely composite/natural key is (order_id, prod_id), though it actually uses a surrogate order_item_id. */
/* Q81. Every order_items.order_id value must exist as a primary key value in sales.orders.order_id - no order_items row may reference a non-existent order. */
/* Q82. A return is inherently tied to a specific order (and its items), and the customer can always be derived by following order_id back to sales.orders.cust_id, avoiding storing customer_id redundantly in two places. */
/* Q83. It avoids repeating day/month/year/quarter calculations in every query, guarantees consistent calendar logic (holidays, fiscal periods) across reports, and lets analysts join once instead of using date functions repeatedly. */
/* Q84. If brand_name/category_name text drifts (typos, renames) across rows, the same brand could show up under two spellings, and any global rename would require updating every row instead of one dimension row - a transitive-dependency risk. */
/* Q85. Names naturally split (sorting by last_name, formal salutations, systems expecting distinct fields) and storing them separately avoids parsing a combined string - each holds one atomic fact per 1NF. */
/* Q86. It implies a one-to-one relationship - each customer has at most one loyalty membership record, keyed directly by customer_id rather than a separate surrogate member_id. */
/* Q87. Add a self-referencing manager_id column to stores.employees that references employee_id, letting each employee point to their manager's row in the same table. */
/* Q88. Because no single attribute uniquely identifies a snapshot - it's inherently the combination of warehouse, product, and date that's unique, so a composite key matches the natural grain of the data. */
/* Q89. New payment modes can be added by inserting one row into finance.payment_modes rather than hoping every order's free-text value is spelled identically, preventing typos and inconsistent reporting groupings. */
/* Q90. First join products -> core.dim_brand on brand_id to get brand_name, then join core.dim_brand -> core.dim_category on category_id to get category_name. */
/* Q91. For: dashboards load faster and are simpler for non-SQL users. Against: it duplicates data that can drift from the source tables and adds maintenance/refresh burden - best implemented as a materialized view, not a hand-maintained table. */
/* Q92. The Compliance Officer must weigh legal/audit needs to retain order history against customer data-deletion requests; typically RESTRICT (or anonymize) is safer than CASCADE, since deleting orders would corrupt financial and inventory history. */
/* Q93. Fact tables: sales.orders and sales.order_items (high-volume transactional events). Dimension tables: core.dim_region and core.dim_brand (descriptive, slowly-changing reference data). */
/* Q94. Product names can change or be renamed for marketing, and multiple products could momentarily share a similar name, so a stable surrogate id avoids breaking every foreign key reference on a rename. */
/* Q95. A genuine 1:1 relationship could exist between customers.customers and loyalty.members (each customer has at most one loyalty record); it's modeled by making customer_id both the primary key and a foreign key in loyalty.members. */
/* Q96. Foreign keys ensure orders can't reference non-existent customers, order_items can't reference non-existent orders or products, and returns can't reference non-existent orders - keeping every domain's data mutually consistent. */
/* Q97. customer_id and product_id on customers.reviews - both are foreign keys linking a review to the customer who wrote it and the product it's about. */
/* Q98. Because analysts run repeated, similar aggregate queries, and precomputing/flattening joins into views or materialized views trades a bit of redundancy for much faster, simpler read performance without touching the normalized base tables. */
/* Q99. Updating a customer's address only requires changing one row in customers.addresses, instead of updating the same address text embedded on every one of that customer's orders. */
/* Q100. customers.customers - 3NF (each column is a direct customer attribute, no redundancy). sales.order_items - 3NF (a clean junction/fact row). sales.orders - intentionally denormalized (net_total is a cached derived sum kept for read speed). */

/* ============================================================
   END OF ANSWER KEY - MEDIUM LEVEL (100/100)
============================================================ */
