/* ============================================================
   ANSWER KEY - Constraints & DML (MEDIUM LEVEL)
   Curriculum:   RetailMart V3
   Note: Section B/C/D run in YOUR accio_NN practice DB, on the
   day_03_practice tables built on Day 3 - NOT against RetailMart
   V3. Scaffolding below recreates that Day 3 state so this file
   also runs standalone.
   ============================================================ */

/* Q1.  CASCADE fits child rows that are meaningless without the parent (order_items when an order is deleted); SET NULL fits child rows that should outlive the parent but lose the link (a review whose customer is deleted); RESTRICT fits parent rows that must never be deleted while dependents exist (a product still referenced by historical orders). */
/* Q2.  It means the FK check is postponed until COMMIT instead of running right after the statement that violates it; you need it whenever two rows must reference each other (or insert in an order that temporarily violates the FK) within one transaction, such as two mutually-referencing tables. */
/* Q3.  A UNIQUE INDEX is more flexible - it can be built CONCURRENTLY (no long lock), can be partial (WHERE clause) or on an expression, and can back a constraint later; a UNIQUE CONSTRAINT is simpler to declare inline but is really just a UNIQUE INDEX under the hood with less flexibility in how it's created. */
/* Q4.  A PARTIAL UNIQUE index only enforces uniqueness among rows matching a WHERE condition - e.g. CREATE UNIQUE INDEX ON addresses(customer_id) WHERE is_default; in multi-tenant SaaS it's used for "at most one default/active row per tenant" without blocking multiple non-default rows. */
/* Q5.  A CHECK constraint can only reference columns within the SAME row being written, because Postgres can't guarantee the referenced table's data stays valid afterward; cross-table validation instead needs a FOREIGN KEY (for simple existence checks) or a TRIGGER (for arbitrary cross-table business rules). */
/* Q6.  By default ALTER TABLE ADD CHECK scans and validates every existing row immediately (taking a lock for the duration); adding it as NOT VALID skips that initial scan (fast), and a later VALIDATE CONSTRAINT does the check separately, taking only a lighter lock while it runs. */
/* Q7.  INSERT ... ON CONFLICT (upsert) either does nothing (ON CONFLICT DO NOTHING) or updates the existing conflicting row (ON CONFLICT DO UPDATE) instead of erroring on a duplicate key - the two patterns are "skip if it exists" and "merge/overwrite if it exists". */
/* Q8.  RETURNING gives back the actual row(s) affected by an INSERT/UPDATE/DELETE (including auto-generated values like a SERIAL id) in the same round trip, saving a separate SELECT to fetch what was just written. */
/* Q9.  DELETE removes rows selectively (with WHERE), is fully logged/rollback-able, and fires triggers - appropriate for routine row removal; TRUNCATE instantly empties a whole table (no WHERE) - appropriate for wiping staging/scratch tables fast; DROP TABLE removes the table structure and data entirely - appropriate only when the table itself is no longer needed. */
/* Q10. A single UPDATE statement can only target one table's rows because its execution model is "scan and rewrite rows of table X"; updating multiple tables together is done as multiple UPDATE statements inside one transaction, which still commits/rolls back atomically as a unit even though each statement only touches one table. */
/* Q11. The "lost update" problem happens when two transactions read the same row, then each independently writes based on that stale read, so one update silently overwrites the other; SELECT ... FOR UPDATE locks the row on read so the second transaction must wait until the first commits, preventing it from working off stale data. */
/* Q12. Pessimistic locking (SELECT ... FOR UPDATE) blocks other writers up front, assuming conflicts are likely - safest under high contention; optimistic locking (a version/updated_at column checked in the WHERE clause, retrying on mismatch) assumes conflicts are rare and only pays the cost when they actually happen - better under low contention and for long-held UI edits. */
/* Q13. A SAVEPOINT marks a point inside an open transaction you can partially roll back to without discarding everything since BEGIN; it's more useful than a full ROLLBACK/COMMIT whenever you want to abandon just one failed step (like one bad row in a bulk import) while keeping everything already-successful in the same transaction. */
/* Q14. INSERT ... SELECT is common in ETL because it moves/transforms data entirely inside the database in one set-based operation - no round trip to pull rows out, transform in application code, and push them back in one at a time. */
/* Q15. UPDATE ... FROM (a real join) is generally faster than a correlated subquery in SET, because the planner can use an efficient join strategy (hash/merge join) across the whole set at once, whereas a correlated subquery often re-evaluates once per row being updated. */
/* Q16. "Tuple visibility" is Postgres's MVCC rule that each transaction only sees row versions valid as of its own snapshot; a DELETE doesn't free disk space immediately because it just marks the old row version as no-longer-visible (dead), leaving the physical bytes on disk until VACUUM reclaims that space. */
/* Q17. VACUUM scans a table and reclaims space left behind by dead row versions (from UPDATEs/DELETEs) so it can be reused by future writes, and it also updates visibility-map/statistics info the planner and freeze-related bookkeeping rely on; without it, tables would bloat indefinitely. */
/* Q18. autovacuum is PostgreSQL's built-in background process that automatically runs VACUUM (and ANALYZE) on tables once they cross configured dead-tuple/insert thresholds, so DBAs don't have to manually schedule VACUUM themselves. */
/* Q19. A plain literal INSERT is simplest for one-off, ad-hoc statements; a prepared statement (parse/plan once, execute many times with different parameter values) wins whenever the same INSERT shape runs repeatedly at volume, since it skips repeated parsing/planning overhead and helps prevent SQL injection. */
/* Q20. A single INSERT of 1000 rows is dramatically faster than 1000 separate single-row INSERTs (without a transaction) because it avoids 999 extra round trips, per-statement parsing/planning, and (without an explicit transaction) 999 extra implicit commits each forcing their own WAL flush. */
/* Q21. Wrapping bulk INSERTs in one transaction means all-or-nothing semantics (a failure partway through can be rolled back cleanly) and only one commit's worth of WAL-flush overhead at the end, instead of every individual INSERT committing (and flushing) on its own. */
/* Q22. A "phantom read" is when a transaction re-runs the same query and sees NEW rows that match its WHERE clause that weren't there before (inserted by another committed transaction in between); SERIALIZABLE isolation prevents phantom reads (REPEATABLE READ also prevents them in Postgres specifically, though the SQL standard doesn't guarantee that for REPEATABLE READ in general). */
/* Q23. READ COMMITTED (the PostgreSQL default) lets each statement see the latest committed data as of when IT starts, so results can change between statements in the same transaction; SERIALIZABLE makes the whole transaction behave as if it ran alone, detecting and aborting conflicting concurrent transactions rather than letting them silently interleave. */
/* Q24. A TRIGGER automatically fires application logic on a data event (e.g. maintaining an audit log, or enforcing a cross-table rule a CHECK can't express) - the right tool when that behavior must ALWAYS happen regardless of which client writes the data; it's an anti-pattern when it hides significant business logic from developers reading the application code, making behavior hard to trace. */
/* Q25. Many teams avoid triggers in production because they're invisible in application code (a developer reading the app has no idea a write also silently does something else), make debugging and performance profiling harder (extra hidden work per statement), and can create tricky recursive or ordering issues - explicit application-level logic is usually easier to reason about and test. */

/* ============================================================
   SECTION B: ADVANCED CONSTRAINT SCENARIOS (25)
   ------------------------------------------------------------ */
DROP SCHEMA IF EXISTS day_03_practice CASCADE;
CREATE SCHEMA IF NOT EXISTS day_03_practice;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE day_03_practice.customers (
    cust_id SERIAL PRIMARY KEY,
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(20),
    is_active BOOLEAN,
    created_at TIMESTAMP DEFAULT NOW(),
    tier_id INT,
    total_spend NUMERIC(12,2) DEFAULT 0
);
CREATE TABLE day_03_practice.products (
    product_id SERIAL PRIMARY KEY,
    name VARCHAR(150),
    price NUMERIC(12,2),
    in_stock BOOLEAN,
    discount_percent INT,
    brand_id INT,
    sku_code VARCHAR(50),
    tax_rate NUMERIC(5,2),
    status TEXT,
    updated_at TIMESTAMPTZ
);
CREATE TABLE day_03_practice.product_reviews (
    review_id SERIAL PRIMARY KEY,
    rating INT,
    comment TEXT,
    posted_on TIMESTAMPTZ
);
CREATE TABLE day_03_practice.orders_demo (
    order_id BIGSERIAL PRIMARY KEY,
    cust_id INT,
    total NUMERIC(12,2),
    order_date DATE
);
CREATE TABLE day_03_practice.tier_master (
    tier_id INT PRIMARY KEY,
    tier_name VARCHAR(20),
    min_points INT
);
CREATE TABLE day_03_practice.employees (
    emp_id SERIAL PRIMARY KEY,
    full_name VARCHAR(100),
    salary NUMERIC(10,2),
    joined DATE,
    dept_name VARCHAR(50)
);
CREATE TABLE day_03_practice.bank_accounts (
    account_id SERIAL PRIMARY KEY,
    holder VARCHAR(100),
    balance NUMERIC(14,2),
    opened_on DATE,
    account_type VARCHAR(20)
);
CREATE TABLE day_03_practice.transactions (
    txn_id BIGSERIAL PRIMARY KEY,
    from_account INT,
    to_account INT,
    amount NUMERIC(14,2),
    txn_time TIMESTAMPTZ
);
CREATE TABLE day_03_practice.feedback (
    feedback_id SERIAL PRIMARY KEY,
    customer_id INT,
    rating INT,
    freeform TEXT
);
CREATE TABLE day_03_practice.addresses (
    address_id SERIAL PRIMARY KEY,
    customer_id INT,
    is_default BOOLEAN,
    pincode VARCHAR(6)
);
CREATE TABLE day_03_practice.coupons (
    coupon_id SERIAL PRIMARY KEY,
    code VARCHAR(30),
    valid_until DATE,
    uses_count INT DEFAULT 0,
    max_uses INT
);
CREATE TABLE day_03_practice.subscriptions (
    sub_id SERIAL PRIMARY KEY,
    user_id INT,
    plan_name VARCHAR(50),
    starts DATE,
    ends DATE,
    auto_renew BOOLEAN
);
CREATE TABLE day_03_practice.notifications (
    notif_id BIGSERIAL PRIMARY KEY,
    user_id INT,
    channel VARCHAR(20),
    sent_at TIMESTAMPTZ,
    payload JSONB
);
CREATE TABLE day_03_practice.employees_with_fk (
    emp_id SERIAL PRIMARY KEY,
    full_name VARCHAR(100),
    tier_id INT REFERENCES day_03_practice.tier_master(tier_id)
);
ALTER TABLE day_03_practice.orders_demo ADD CONSTRAINT fk_orders_demo_cust
  FOREIGN KEY (cust_id) REFERENCES day_03_practice.customers(cust_id);

/* Q26. */
ALTER TABLE day_03_practice.transactions ADD CONSTRAINT uq_txn_from_to_time UNIQUE (from_account, to_account, txn_time);

/* Q27. */
ALTER TABLE day_03_practice.bank_accounts ADD CONSTRAINT chk_savings_balance
  CHECK (balance = 0 OR balance > 0 OR account_type <> 'Savings');

/* Q28. */
CREATE TABLE day_03_practice.defer_a (id INT PRIMARY KEY, b_id INT);
CREATE TABLE day_03_practice.defer_b (id INT PRIMARY KEY, a_id INT);
ALTER TABLE day_03_practice.defer_a ADD CONSTRAINT fk_defer_a_b
  FOREIGN KEY (b_id) REFERENCES day_03_practice.defer_b(id) DEFERRABLE INITIALLY DEFERRED;

/* Q29. */
CREATE UNIQUE INDEX idx_addresses_one_default ON day_03_practice.addresses(customer_id) WHERE is_default = TRUE;

/* Q30. */
ALTER TABLE day_03_practice.subscriptions ADD CONSTRAINT chk_sub_dates CHECK (ends > starts);

/* Q31. */
ALTER TABLE day_03_practice.products ADD CONSTRAINT chk_discount_range CHECK (discount_percent BETWEEN 0 AND 100);

/* Q32. */
ALTER TABLE day_03_practice.employees ADD CONSTRAINT chk_joined_not_future CHECK (joined <= CURRENT_DATE);

/* Q33. */
ALTER TABLE day_03_practice.product_reviews ADD CONSTRAINT chk_review_low_rating_comment
  CHECK (rating BETWEEN 1 AND 5 AND (rating > 2 OR comment IS NOT NULL));

/* Q34. */
ALTER TABLE day_03_practice.feedback ADD CONSTRAINT chk_feedback_five_star_comment
  CHECK ((rating = 5 AND freeform IS NOT NULL) OR rating < 5);

/* Q35. */
ALTER TABLE day_03_practice.coupons ADD CONSTRAINT chk_coupon_validity
  CHECK (valid_until > CURRENT_DATE OR uses_count >= max_uses);

/* Q36. */
ALTER TABLE day_03_practice.employees_with_fk DROP CONSTRAINT employees_with_fk_tier_id_fkey;
ALTER TABLE day_03_practice.employees_with_fk ADD CONSTRAINT fk_employees_with_fk_tier
  FOREIGN KEY (tier_id) REFERENCES day_03_practice.tier_master(tier_id) ON DELETE SET NULL;

/* Q37. */
ALTER TABLE day_03_practice.transactions ADD CONSTRAINT fk_txn_from_cascade
  FOREIGN KEY (from_account) REFERENCES day_03_practice.bank_accounts(account_id) ON DELETE CASCADE;
/* Risk: deleting a bank account now silently deletes every transaction that ever moved money FROM it, destroying financial history - CASCADE is rarely appropriate for money-movement records; RESTRICT (or a soft-delete flag on the account) is usually the safer choice. */

/* Q38. */
SELECT conname FROM pg_constraint WHERE conrelid = 'day_03_practice.products'::regclass AND contype = 'c';
ALTER TABLE day_03_practice.products DROP CONSTRAINT chk_discount_range;

/* Q39. */
ALTER TABLE day_03_practice.products ADD CONSTRAINT chk_expensive_needs_sku
  CHECK (price <= 10000 OR sku_code IS NOT NULL);

/* Q40. */
ALTER TABLE day_03_practice.subscriptions ADD CONSTRAINT excl_sub_overlap
  EXCLUDE USING gist (user_id WITH =, daterange(starts, ends, '[]') WITH &&);

/* Q41. */
ALTER TABLE day_03_practice.customers ALTER COLUMN created_at SET DEFAULT NOW();
ALTER TABLE day_03_practice.customers ALTER COLUMN created_at SET NOT NULL;

/* Q42. */
ALTER TABLE day_03_practice.customers ALTER COLUMN is_active DROP NOT NULL;

/* Q43. */
ALTER TABLE day_03_practice.products ALTER COLUMN in_stock SET DEFAULT FALSE;

/* Q44. */
ALTER TABLE day_03_practice.products ADD CONSTRAINT chk_price_not_valid CHECK (price > 0) NOT VALID;
ALTER TABLE day_03_practice.products VALIDATE CONSTRAINT chk_price_not_valid;

/* Q45. */
CREATE UNIQUE INDEX idx_customers_lower_email ON day_03_practice.customers (LOWER(email));

/* Q46. */
ALTER TABLE day_03_practice.customers ADD CONSTRAINT chk_customers_email_at CHECK (email ~ '@');

/* Q47. */
ALTER TABLE day_03_practice.customers ADD CONSTRAINT chk_customers_phone_10 CHECK (phone IS NULL OR phone ~ '^[0-9]{10}$');

/* Q48. */
ALTER TABLE day_03_practice.addresses ADD CONSTRAINT chk_addresses_pincode CHECK (pincode ~ '^[0-9]{6}$');

/* Q49. */
ALTER TABLE day_03_practice.products ADD CONSTRAINT chk_net_price_nonneg
  CHECK (price - (price * COALESCE(discount_percent,0) / 100.0) >= 0);

/* Q50. */
SELECT conname, contype, pg_get_constraintdef(oid)
FROM pg_constraint WHERE conrelid = 'day_03_practice.products'::regclass;

/* ============================================================
   SECTION C: BULK DML PATTERNS (25)
   ------------------------------------------------------------ */
INSERT INTO day_03_practice.tier_master (tier_id, tier_name, min_points) VALUES (1,'Bronze',0),(2,'Silver',100),(3,'Gold',500)
ON CONFLICT (tier_id) DO NOTHING;
INSERT INTO day_03_practice.customers (email, is_active) VALUES ('a@example.com', TRUE), ('b@example.com', FALSE);
INSERT INTO day_03_practice.orders_demo (cust_id, total, order_date) VALUES (1, 500, '2023-06-01'), (1, 700, '2025-01-01');
INSERT INTO day_03_practice.bank_accounts (holder, balance) VALUES ('A', 1000), ('B', 2000);

/* Q51. */
INSERT INTO day_03_practice.notifications (user_id, channel, sent_at)
SELECT (n % 5) + 1, 'email', NOW() - (n || ' hours')::interval
FROM generate_series(1, 1000) AS n;

/* Q52. */
CREATE TABLE day_03_practice.archive_orders (LIKE day_03_practice.orders_demo INCLUDING ALL);
INSERT INTO day_03_practice.archive_orders
SELECT * FROM day_03_practice.orders_demo WHERE order_date < '2024-01-01';

/* Q53. */
UPDATE day_03_practice.products SET discount_percent = 0 WHERE discount_percent IS NULL;

/* Q54. */
UPDATE day_03_practice.products SET price = price * 1.10 WHERE brand_id IN (1,2,3);

/* Q55. */
UPDATE day_03_practice.customers c
SET tier_id = m.tier_id
FROM day_03_practice.tier_master m
WHERE m.tier_name = 'Bronze' AND c.tier_id IS NULL;

/* Q56. */
DELETE FROM day_03_practice.notifications
USING day_03_practice.customers
WHERE notifications.user_id = customers.cust_id AND customers.is_active = FALSE;

/* Q57. */
INSERT INTO day_03_practice.products (name, price, in_stock) VALUES
  ('P1', 100, TRUE), ('P2', 200, TRUE), ('P3', 300, TRUE), ('P4', 400, TRUE), ('P5', 500, TRUE),
  ('P6', 600, TRUE), ('P7', 700, TRUE), ('P8', 800, TRUE), ('P9', 900, TRUE), ('P10', 1000, TRUE);

/* Q58. */
INSERT INTO day_03_practice.tier_master VALUES (4, 'Diamond', 1000)
ON CONFLICT (tier_id) DO UPDATE SET tier_name = EXCLUDED.tier_name;

/* Q59. */
INSERT INTO day_03_practice.customers (email) VALUES ('a@example.com')
ON CONFLICT (email) DO NOTHING;

/* Q60. */
INSERT INTO day_03_practice.customers (email) VALUES ('newcust@example.com') RETURNING cust_id;

/* Q61. */
INSERT INTO day_03_practice.orders_demo (cust_id, total, order_date) VALUES (1, 5000, CURRENT_DATE) RETURNING order_id;

/* Q62. */
SELECT phone AS old_phone FROM day_03_practice.customers WHERE cust_id = 1;
UPDATE day_03_practice.customers SET phone = '9999999999' WHERE cust_id = 1 RETURNING phone AS new_phone;

/* Q63. */
DELETE FROM day_03_practice.customers WHERE cust_id = 2 AND is_active = FALSE RETURNING *;

/* Q64. */
CREATE TABLE day_03_practice.products_v2 (LIKE day_03_practice.products INCLUDING ALL);
INSERT INTO day_03_practice.products_v2 SELECT * FROM day_03_practice.products LIMIT 100;

/* Q65. */
UPDATE day_03_practice.products SET status = CASE WHEN price > 1000 THEN 'premium' ELSE 'standard' END;

/* Q66. */
UPDATE day_03_practice.products SET price = price * 1.05, updated_at = NOW();

/* Q67. */
DELETE FROM day_03_practice.notifications WHERE sent_at < NOW() - INTERVAL '90 days';

/* Q68. */
DELETE FROM day_03_practice.notifications
WHERE notif_id IN (SELECT notif_id FROM day_03_practice.notifications LIMIT 1000);

/* Q69. */
INSERT INTO day_03_practice.archive_orders
SELECT * FROM day_03_practice.orders_demo WHERE total > 600;

/* Q70. On a table declared PARTITION BY RANGE(order_date) (like day_03_practice.orders_p from Day 3 Hard), a plain INSERT INTO orders_p (cust_id, order_date, net_total) VALUES (1, '2025-03-15', 500); needs no special syntax at all - PostgreSQL inspects the partition key value in the row and automatically routes it into the matching partition (or the default partition, or raises an error if none matches and there's no default). */

/* Q71. */
TRUNCATE day_03_practice.notifications, day_03_practice.archive_orders;

/* Q72. */
TRUNCATE day_03_practice.products_v2 RESTART IDENTITY;

/* Q73. */
UPDATE day_03_practice.customers c
SET total_spend = (SELECT COALESCE(SUM(o.total), 0) FROM day_03_practice.orders_demo o WHERE o.cust_id = c.cust_id);

/* Q74. */
UPDATE day_03_practice.orders_demo o
SET total = o.total + 10
FROM day_03_practice.customers c
WHERE o.cust_id = c.cust_id AND c.is_active = TRUE;

/* Q75. */
DELETE FROM day_03_practice.archive_orders a
USING day_03_practice.customers c
WHERE a.cust_id = c.cust_id AND c.is_active = FALSE;

/* ============================================================
   SECTION D: TRANSACTIONAL CRUD PATTERNS (25)
   ------------------------------------------------------------ */

/* Q76. */
BEGIN;
UPDATE day_03_practice.bank_accounts SET balance = balance - 100 WHERE account_id = 1;
SELECT * FROM day_03_practice.bank_accounts WHERE account_id = 1;
ROLLBACK;

/* Q77. */
BEGIN;
DELETE FROM day_03_practice.notifications WHERE notif_id > 1000000;
SELECT count(*) FROM day_03_practice.notifications;
COMMIT;

/* Q78. */
BEGIN;
INSERT INTO day_03_practice.orders_demo (cust_id, total) VALUES (1, 500);
INSERT INTO day_03_practice.archive_orders (cust_id, total) VALUES (1, 500);
COMMIT;

/* Q79. */
BEGIN;
UPDATE day_03_practice.bank_accounts SET balance = balance - 50 WHERE account_id = 1;
SAVEPOINT s1;
UPDATE day_03_practice.bank_accounts SET balance = balance - 999999 WHERE account_id = 1;
ROLLBACK TO SAVEPOINT s1;
COMMIT;

/* Q80. Session A: BEGIN; SELECT * FROM day_03_practice.bank_accounts WHERE account_id = 1 FOR UPDATE; (row-locked, transaction left open). Session B, run concurrently: UPDATE day_03_practice.bank_accounts SET balance = balance - 10 WHERE account_id = 1; blocks and waits until session A commits or rolls back, so the two updates can never interleave on the same row. */

/* Q81. */
BEGIN;
UPDATE day_03_practice.bank_accounts SET balance = balance - 200 WHERE account_id = 1;
UPDATE day_03_practice.bank_accounts SET balance = balance + 200 WHERE account_id = 2;
INSERT INTO day_03_practice.orders_demo (cust_id, total) VALUES (1, 0);
COMMIT;

/* Q82. */
BEGIN;
INSERT INTO day_03_practice.customers (email) VALUES ('y1@example.com');
INSERT INTO day_03_practice.customers (email) VALUES ('y2@example.com');
COMMIT;

/* Q83. */
BEGIN;
UPDATE day_03_practice.bank_accounts SET balance = 0;
ROLLBACK;

/* Q84. */
SELECT balance FROM day_03_practice.bank_accounts WHERE account_id = 1;
BEGIN;
UPDATE day_03_practice.bank_accounts SET balance = balance + 10 WHERE account_id = 1;
SELECT balance FROM day_03_practice.bank_accounts WHERE account_id = 1;
COMMIT;

/* Q85. */
BEGIN;
SELECT count(*) FROM day_03_practice.orders_demo;
DELETE FROM day_03_practice.orders_demo WHERE total = 0;
SELECT count(*) FROM day_03_practice.orders_demo;
COMMIT;

/* Q86. */
BEGIN;
INSERT INTO day_03_practice.orders_demo (cust_id, total) VALUES (99999, 100);
ROLLBACK;

/* Q87. */
BEGIN;
SET LOCAL statement_timeout = '5s';
SELECT 1;
COMMIT;
/* LOCAL scopes the setting to just the current transaction - it automatically reverts to the session's previous value at COMMIT/ROLLBACK, unlike a plain SET which stays changed for the rest of the session. */

/* Q88. Once day_03_practice.defer_a/defer_b (Q28) have a DEFERRABLE INITIALLY DEFERRED FK between them, you can: BEGIN; INSERT INTO day_03_practice.defer_a (id, b_id) VALUES (1, 1); INSERT INTO day_03_practice.defer_b (id, a_id) VALUES (1, 1); COMMIT; - each INSERT would violate the FK on its own (the referenced row doesn't exist yet), but because the constraint is deferred, both are allowed to happen first and the FK is only checked once, at COMMIT, by which point both rows exist. */

/* Q89. */
BEGIN;
SELECT * FROM day_03_practice.bank_accounts WHERE account_id = 1 FOR UPDATE NOWAIT;
COMMIT;

/* Q90. */
BEGIN;
SELECT * FROM day_03_practice.orders_demo FOR UPDATE SKIP LOCKED LIMIT 5;
COMMIT;

/* Q91. Session A: BEGIN; UPDATE day_03_practice.bank_accounts SET balance = balance - 100 WHERE account_id = 1; (no COMMIT yet). Session B, at READ COMMITTED (the default): SELECT balance FROM day_03_practice.bank_accounts WHERE account_id = 1; still sees the OLD, pre-update balance, because Postgres's MVCC only shows session B a committed snapshot - A's uncommitted change is invisible to B until A commits. */

/* Q92. */
BEGIN;
ALTER TABLE day_03_practice.customers RENAME COLUMN phone TO phone_number;
SELECT column_name FROM information_schema.columns WHERE table_schema='day_03_practice' AND table_name='customers';
COMMIT;

/* Q93. */
BEGIN;
CREATE TABLE day_03_practice.scratch_tbl (id INT);
INSERT INTO day_03_practice.scratch_tbl VALUES (1);
ROLLBACK;
SELECT to_regclass('day_03_practice.scratch_tbl');

/* Q94. Unlike MySQL (where DDL like CREATE TABLE auto-commits and can't be rolled back), PostgreSQL treats DDL as fully transactional: Q93 above proves it - the CREATE TABLE and INSERT inside that BEGIN/ROLLBACK block are both completely undone, and to_regclass() afterward returns NULL because the table was never really created. */

/* Q95. */
BEGIN;
INSERT INTO day_03_practice.customers (email) VALUES ('etl1@example.com');
SAVEPOINT row_sp;
INSERT INTO day_03_practice.customers (email) VALUES (NULL);
ROLLBACK TO SAVEPOINT row_sp;
COMMIT;

/* Q96. */
BEGIN;
INSERT INTO day_03_practice.customers (email) VALUES ('conflict1@example.com')
ON CONFLICT (email) DO NOTHING;
COMMIT;

/* Q97. */
BEGIN;
UPDATE day_03_practice.bank_accounts SET balance = balance - 100 WHERE account_id = 1;
UPDATE day_03_practice.bank_accounts SET balance = balance + 100 WHERE account_id = 2;
SELECT sum(balance) FROM day_03_practice.bank_accounts;
COMMIT;

/* Q98. */
BEGIN;
DELETE FROM day_03_practice.orders_demo WHERE total < 0;
INSERT INTO day_03_practice.orders_demo (cust_id, total) VALUES (1, 999);
COMMIT;

/* Q99. A transaction left open for an hour (BEGIN; ... no COMMIT) holds back autovacuum: Postgres can't reclaim dead row versions newer than that transaction's snapshot anywhere in the database, because it might still need to see them - so every table with ongoing UPDATE/DELETE activity accumulates dead tuples and bloats for as long as that one transaction stays open, even though it isn't itself touching those tables. */

/* Q100. */
BEGIN READ ONLY;
SELECT count(*) FROM day_03_practice.bank_accounts;
COMMIT;

/* ============================================================
   END OF ANSWER KEY - MEDIUM LEVEL (100/100)
============================================================ */
