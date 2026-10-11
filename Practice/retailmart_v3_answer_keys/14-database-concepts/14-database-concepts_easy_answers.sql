/* ============================================================
   ANSWER KEY - Database Concepts (EASY LEVEL)
   Curriculum:   RetailMart V3
   Note: Day 14 is concept-only, so these are short reference
   answers (no queries to run/verify) matching each question.
   ============================================================ */

/* Q1.  A primary key is the column (or columns) that uniquely identifies each row in a table; its values must always be unique and never NULL. */
/* Q2.  A foreign key is a column that stores another table's primary key value, enforcing that every referencing row points to a row that actually exists (referential integrity). */
/* Q3.  A table can have only one PRIMARY KEY (which also disallows NULLs), but it can have many UNIQUE constraints, and UNIQUE columns may allow NULL. */
/* Q4.  A composite primary key uses two or more columns together to uniquely identify a row, e.g. products.inventory's (store_id, product_id) - neither column alone is unique. */
/* Q5.  A natural key is a real-world unique value already in the data (email); a surrogate key is an artificial generated id with no business meaning (customer_id). */
/* Q6.  Auto-generated ids never change, are guaranteed unique, and are small/fast to index and join on, unlike real-world values that can change or collide. */
/* Q7.  Yes - sales.orders has both cust_id (referencing customers.customers) and store_id (referencing stores.stores) as separate foreign keys. */
/* Q8.  A candidate key is any column (or column set) that could validly serve as the primary key; the primary key is the one candidate key actually chosen to identify rows. */
/* Q9.  One customer can place many orders, but each order belongs to exactly one customer - customers.customer_id is referenced by many rows in sales.orders. */
/* Q10. One student can enroll in many courses and one course can have many students, so a junction table (enrollments) with both student_id and course_id resolves the many-to-many link. */
/* Q11. A one-to-one relationship means each row in table A matches at most one row in table B; e.g. one customer having exactly one loyalty.members record. */
/* Q12. Referential integrity means every foreign key value in a child table must match an existing primary key value in its parent table (or be NULL). */
/* Q13. The database should either block the delete (if orders reference that customer) or cascade/nullify per the defined ON DELETE rule - it should never leave orphaned orders. */
/* Q14. ON DELETE CASCADE automatically deletes the dependent child rows too; ON DELETE RESTRICT blocks the parent delete while child rows still exist. */
/* Q15. NULL means "no value," and a primary key must uniquely identify every row - a NULL couldn't be compared or guaranteed unique, so it would break identification. */
/* Q16. Yes, a foreign key column can be NULL (unless also marked NOT NULL); it typically means "not yet linked to a parent," e.g. an order with no payment_mode_id assigned yet. */
/* Q17. The "parent" table holds the primary key being referenced (customers.customers); the "child" table holds the foreign key pointing back to it (sales.orders). */
/* Q18. You create a junction (bridge) table holding a foreign key to each of the two related tables, with a composite key made of both, like sales.order_items linking orders and products. */
/* Q19. Emails can change or be reused/reset, but customer_id is stable and guaranteed unique for the life of the record, making it a safer, permanent identifier for all other tables to reference. */
/* Q20. A self-referencing foreign key is a column in a table that points back to the same table's primary key, e.g. an employees.manager_id column referencing employees.employee_id. */
/* Q21. A lookup (dimension) table stores a small, relatively static set of reference values other tables point to, like core.dim_region (region_id, region_name). */
/* Q22. Surrogate keys are just sequential numbers with no business meaning, so they never need to change even if the customer's email, phone, or name changes. */
/* Q23. A key defines which column(s) uniquely identify or link rows (a rule about the data's structure); an index is a separate physical structure built to speed up lookups on any column. */
/* Q24. An orphan row is a child row whose foreign key points to a parent row that no longer exists; a FOREIGN KEY constraint (with an appropriate ON DELETE rule) prevents this. */
/* Q25. Splitting data avoids repeating the same facts on every row (redundancy), keeps each table focused on one entity, and makes updates and constraints simpler and safer to manage. */

/* Q26. Normalizing means organizing tables and columns so each fact is stored in exactly one place, using keys to link related data instead of repeating it. */
/* Q27. Normalization prevents data redundancy (the same fact stored many times) and the update/insert/delete anomalies that redundancy causes. */
/* Q28. Data redundancy is storing the same fact in multiple rows/tables; it's risky because an update can fix it in one place but leave stale, contradictory copies elsewhere. */
/* Q29. An update anomaly: if a product's name is repeated on every order_items row, changing the name requires updating every single row or the data becomes inconsistent. */
/* Q30. An insertion anomaly: you can't add a new product that has never been ordered if product details only exist embedded inside the order_items table. */
/* Q31. A deletion anomaly: deleting the only order that references a product would also erase all knowledge of that product if its details weren't stored separately. */
/* Q32. 1NF requires that every column hold a single, atomic value (no repeating groups or lists crammed into one cell) and each row be uniquely identifiable. */
/* Q33. A column storing "9876543210, 9123456780" (two phone numbers in one cell) violates 1NF because it isn't a single atomic value. */
/* Q34. Atomic means the value can't be meaningfully broken down further for the database's purposes - one phone number, not a list of several. */
/* Q35. 2NF requires 1NF plus every non-key column depends on the WHOLE primary key, not just part of a composite key. */
/* Q36. A partial dependency is when a non-key column depends on only part of a composite primary key rather than the full combination. */
/* Q37. 3NF requires 2NF plus no non-key column depends on another non-key column (no transitive dependencies) - every non-key column must depend only on the key. */
/* Q38. A transitive dependency is when column A determines column B, and B in turn determines column C, so C indirectly depends on A through B rather than directly on the key. */
/* Q39. It means every non-key column must depend on the full primary key ("the whole key") and on nothing else besides the key ("nothing but the key"). */
/* Q40. A -> B means that knowing the value of A always tells you exactly one corresponding value of B, e.g. product_id -> product_name. */
/* Q41. True - the normal forms are cumulative, so satisfying the stricter rules of 3NF automatically means the table also satisfies 2NF and 1NF. */
/* Q42. If region can be derived from city/state/pincode, storing it separately risks the two becoming inconsistent (e.g. pincode says Pune but region says South). */
/* Q43. Updating a customer's address in one system but not four others (billing, shipping, CRM, support) left the customer with mismatched addresses across teams. */
/* Q44. Denormalization means deliberately reintroducing redundancy (e.g. storing a total or repeating a lookup value) to simplify or speed up reads, trading some integrity for performance. */
/* Q45. A legitimate reason is read performance - avoiding expensive joins for a dashboard that is queried far more often than the underlying data changes. */
/* Q46. Reporting tables are read far more often than written, so precomputing/flattening joins trades a little redundancy for much faster, simpler queries. */
/* Q47. No - normalization should stop once it satisfies the business's integrity needs; over-normalizing can hurt readability and query performance without real benefit. */
/* Q48. A repeating group is multiple similar values crammed into one row (item1, item2, item3 columns); 1NF forbids it. */
/* Q49. Because each type of fact gets moved into its own table connected by keys, instead of being duplicated inline, which naturally produces more, smaller tables. */
/* Q50. Since related facts now live in separate normalized tables, reconstructing a full picture (e.g. order + customer + product) requires JOINing those tables back together. */

/* Q51. A transaction is a group of one or more database operations treated as a single unit of work that either all succeed together or all fail together. */
/* Q52. COMMIT permanently saves all the changes made in the current transaction to the database. */
/* Q53. ROLLBACK undoes all the changes made in the current (uncommitted) transaction, returning the data to its state before the transaction began. */
/* Q54. Atomicity, Consistency, Isolation, Durability. */
/* Q55. Atomicity means debiting account A and crediting account B happen as one all-or-nothing unit - if the credit fails, the debit is undone too, so money is never lost. */
/* Q56. Consistency means a transaction can only move the database from one valid state to another, never violating its constraints and business rules. */
/* Q57. Isolation means concurrently running transactions don't see each other's uncommitted, in-progress changes, as if each ran alone. */
/* Q58. Durability means once a transaction is committed, its changes are permanently saved and will survive a crash or power failure. */
/* Q59. Because the money can't exist in both accounts or neither - the debit and credit must succeed or fail together, which is exactly what atomicity guarantees. */
/* Q60. Durability - a committed transaction's changes are guaranteed to survive the crash because they were already written durably (e.g. via the write-ahead log). */
/* Q61. Isolation. */
/* Q62. An operation where either every step completes successfully, or none of them take effect at all - there's no partially-done state. */
/* Q63. Inserting a new order into sales.orders and its matching rows into sales.order_items should happen in one transaction, so you never end up with an order that has no items or items with no order. */
/* Q64. BEGIN starts a new transaction block, so subsequent statements are grouped together and not permanently saved until a COMMIT. */
/* Q65. No - once COMMIT has run, the changes are permanent; ROLLBACK only works on an active, uncommitted transaction. */
/* Q66. A constraint violation (like a CHECK or FOREIGN KEY failure) partway through the transaction causes it to be automatically rolled back. */
/* Q67. A partial update is when only some of a multi-step change gets applied (e.g. inventory reduced but order not created); it's dangerous because it leaves the data in an inconsistent, half-done state. */
/* Q68. In auto-commit mode, every individual statement is committed immediately on its own; in an explicit transaction, multiple statements are grouped and only saved together at COMMIT. */
/* Q69. A constraint is a rule the database enforces on the data (NOT NULL, UNIQUE, FOREIGN KEY, CHECK); it supports Consistency by refusing to let a transaction leave the data in an invalid state. */
/* Q70. A NOT NULL constraint stops a required column from ever being left empty, guaranteeing every row has that piece of data. */
/* Q71. A CHECK constraint enforces a custom condition on a column's value, e.g. CHECK (quantity > 0) stops negative or zero quantities from ever being stored. */
/* Q72. A UNIQUE constraint guarantees no two rows can have the same value in that column, e.g. preventing two customers from registering with the same email. */
/* Q73. Checkout involves multiple linked writes (order, order items, payment, inventory) that must all succeed or all fail together, or the customer could be charged without an order, or vice versa. */
/* Q74. Durability promises that once "payment successful" is shown, that transaction's data is permanently saved and won't be lost even if the server crashes immediately after. */
/* Q75. Analysts mainly run read-only SELECT queries to explore and report on data, which don't modify anything, so there's rarely a transaction to manage or commit. */

/* Q76. customer_id. */
/* Q77. customers.addresses holds them, connected via the customer_id foreign key referencing customers.customers.customer_id. */
/* Q78. customers.addresses holds city; you connect the two tables by joining on customer_id. */
/* Q79. sales.orders (via order_id) and products.products (via prod_id, referencing product_id). */
/* Q80. It points to products.products.product_id, identifying which product was ordered. */
/* Q81. Join sales.returns to sales.orders on order_id, then join sales.orders to customers.customers on cust_id to find the customer. */
/* Q82. One-to-many - one order in sales.orders can have many line items in sales.order_items. */
/* Q83. It points to core.dim_region.region_id, the region the store is located in. */
/* Q84. Storing an id avoids repeating the text "North" thousands of times, keeps it consistent (no typos like "North"/"north"), and lets the region name be updated in one place. */
/* Q85. It's mildly a normalization smell - the tier label is stored as free text rather than referencing a dedicated loyalty.tiers dimension table, but it's small and low-risk in practice. */
/* Q86. It's stored as two separate columns, first_name and last_name; a "full name" would be derived by concatenating them, not stored redundantly. */
/* Q87. customer_id links loyalty.members back to customers.customers. */
/* Q88. product_id is the primary key of products.products; sales.order_items references it via its prod_id column. */
/* Q89. sales.orders to sales.order_items is one-to-many: sales.orders.order_id (primary key) is referenced by sales.order_items.order_id (foreign key). */
/* Q90. sales.order_items resolves it, holding a foreign key to both the order and the product. */
/* Q91. Brands and categories are independent, reusable descriptive facts shared across many products, so keeping them in their own dimension tables avoids repeating that text on every product row. */
/* Q92. It represents a one-to-many relationship: one customer can raise many support tickets. */
/* Q93. dept_id links an employee to their department, referencing core.dim_department.dept_id. */
/* Q94. It's stored once on the order (sales.orders.order_date) - that's the correct design, since the date applies to the whole order, not each individual line item. */
/* Q95. Yes, it's a form of denormalization (a derived/cached sum); it's safe as long as it's kept consistent with the underlying order_items, e.g. recalculated whenever items change. */
/* Q96. customers.customers and products.products both look well-normalized 3NF - each holds only attributes describing its one entity (a customer or a product) with no repeating groups or derivable text columns. */
/* Q97. sales.orders.net_total is denormalized (a stored, derivable sum of order_items); the tradeoff is faster reads of order totals versus the risk of it drifting out of sync with the actual line items. */
/* Q98. Add a junction table promotions_products(promo_id, product_id) with a composite primary key, each column a foreign key to products.promotions and products.products respectively. */
/* Q99. customer_id never changes even if the customer updates or replaces their email address, so using it as the primary key keeps every other table's foreign key references stable. */
/* Q100. sales.order_items: primary key order_item_id, foreign key order_id referencing sales.orders, and it models one purchased product line within a customer's order. */

/* ============================================================
   END OF ANSWER KEY - EASY LEVEL (100/100)
============================================================ */
