/* ============================================================
   ANSWER KEY - Constraints & DML (EASY LEVEL)
   Curriculum:   RetailMart V3
   Note: Section B/C/D run in YOUR accio_NN practice DB, on the
   day_03_practice tables built on Day 3 - NOT against RetailMart
   V3. Scaffolding below recreates that Day 3 state so this file
   also runs standalone.
   ============================================================ */

/* Q1.  PRIMARY KEY enforces that every value in the column(s) is unique and NOT NULL; it implicitly creates a unique B-tree index backing that constraint. */
/* Q2.  A table can have only one PRIMARY KEY, but that one PK can be composite (span multiple columns) - PostgreSQL rejects a second PRIMARY KEY constraint on the same table outright. */
/* Q3.  A FOREIGN KEY forces every value in the referencing column to already exist in the referenced table's key column (or be NULL), rejecting any INSERT/UPDATE that would violate that link. */
/* Q4.  ON DELETE CASCADE automatically deletes child rows when their parent row is deleted; the risk is silently losing far more data than intended if you delete a parent row without realizing how many children cascade with it. */
/* Q5.  ON DELETE RESTRICT (the default, same as NO ACTION) blocks deleting a parent row outright while any child row still references it. */
/* Q6.  ON DELETE SET NULL sets the child's FK column to NULL instead of deleting the child; use it when the child record should survive on its own even after its parent is gone (e.g. a review outliving a deleted customer account). */
/* Q7.  UNIQUE just enforces no-duplicate values; PRIMARY KEY is UNIQUE + NOT NULL + marks the column as the table's main identifying key (and only one PK is allowed per table, while multiple UNIQUE constraints can coexist). */
/* Q8.  Yes - a UNIQUE column can hold multiple NULLs (NULLs aren't considered duplicates of each other by default); a PRIMARY KEY column can never be NULL. */
/* Q9.  NOT NULL only forbids NULL values; a CHECK constraint can enforce any boolean expression on the value (a range, a pattern, a relationship between columns), so it's a strictly more general validation tool. */
/* Q10. DEFAULT supplies a value automatically for a column when an INSERT doesn't explicitly provide one; it's applied at insert time, not retroactively to existing rows. */
/* Q11. INSERT INTO ... VALUES (...) is the basic form for writing one or a few literal rows by hand; INSERT ... SELECT is useful whenever the rows to insert come from querying existing data (copying, transforming, or archiving rows from another table). */
/* Q12. UPDATE without a WHERE clause changes every row in the table - the danger is silently overwriting the whole table's data with no way to target just the rows you meant to change. */
/* Q13. DELETE without a WHERE clause removes every row in the table - the danger is wiping out all the data with a single accidental keystroke, with no filter to limit the damage. */
/* Q14. DELETE removes rows one at a time, can be filtered with WHERE, fires triggers, and is fully rollback-able; TRUNCATE instantly deallocates all the table's data pages at once, cannot be filtered, and (though also rollback-able in Postgres if run inside an open transaction) resets identity columns by default. */
/* Q15. TRUNCATE is faster because it deallocates whole data pages directly instead of scanning and deleting/logging each row individually the way DELETE does. */
/* Q16. Yes - in PostgreSQL, TRUNCATE is transactional like any other DDL/DML statement and can be rolled back if it's still inside an open transaction that hasn't committed. */
/* Q17. Yes - DELETE is a normal DML statement and can be rolled back with ROLLBACK as long as the transaction containing it hasn't been committed yet. */
/* Q18. Referential integrity means every foreign key value in a table must correspond to an existing (or NULL) value in the table it references - the database never allows "dangling" references to rows that don't exist. */
/* Q19. The INSERT is rejected with a foreign key violation error, because the referenced parent value doesn't exist in the parent table. */
/* Q20. No, not while child rows still reference it (DROP fails with a dependency error); the safe way is DROP TABLE parent CASCADE (which also drops the dependent FK constraints/child data as applicable) or first dropping/altering the child FK constraints yourself before dropping the parent. */
/* Q21. Constraints are checked at write time (INSERT/UPDATE/DELETE) because that's the only point the database can guarantee the data is still valid before it's committed to storage - checking only at query time would let invalid data sit in the table indefinitely. */
/* Q22. A CHECK constraint is a simple declarative boolean expression evaluated automatically on every write with no custom code; a TRIGGER is arbitrary procedural code that can run on any event, access other tables, and perform side effects - triggers are far more powerful but harder to reason about and maintain. */
/* Q23. NOT NULL catches missing data as early as possible (at write time) rather than letting incomplete rows silently propagate into reports/joins/calculations later, where a NULL can produce confusing or wrong downstream results. */
/* Q24. BEGIN starts a new transaction block; COMMIT permanently saves every change made since BEGIN; ROLLBACK discards every change made since BEGIN, restoring the data to how it was before the transaction started. */
/* Q25. After ROLLBACK, the row was "never inserted" from the database's perspective - the whole transaction (including that INSERT) is undone as if it had never run, so nothing about it is visible to any other session. */

/* ============================================================
   SECTION B: ADD CONSTRAINTS TO YOUR TABLES (25)
   ------------------------------------------------------------ */
DROP SCHEMA IF EXISTS day_03_practice CASCADE;
CREATE SCHEMA IF NOT EXISTS day_03_practice;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE day_03_practice.customers (
    cust_id SERIAL PRIMARY KEY,
    email VARCHAR(100),
    phone VARCHAR(20),
    is_active BOOLEAN,
    created_at TIMESTAMP
);
CREATE TABLE day_03_practice.products (
    product_id SERIAL PRIMARY KEY,
    name VARCHAR(150),
    price NUMERIC(12,2),
    in_stock BOOLEAN
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
    opened_on DATE
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
CREATE TABLE day_03_practice.events_log (
    event_id BIGSERIAL PRIMARY KEY,
    payload JSONB,
    occurred_at TIMESTAMPTZ
);
CREATE TABLE day_03_practice.sessions (
    session_id UUID PRIMARY KEY,
    user_id INT,
    started TIMESTAMPTZ,
    ended TIMESTAMPTZ
);
CREATE TABLE day_03_practice.brands (
    brand_id SERIAL PRIMARY KEY,
    brand_name VARCHAR(100),
    country VARCHAR(50)
);
CREATE TABLE day_03_practice.cities (
    city_id SERIAL PRIMARY KEY,
    city_name VARCHAR(50),
    state VARCHAR(50)
);
CREATE TABLE day_03_practice.payment_modes (
    mode_id SERIAL PRIMARY KEY,
    mode_name VARCHAR(30),
    is_active BOOLEAN
);
CREATE TABLE day_03_practice.login_log (
    log_id BIGSERIAL PRIMARY KEY,
    user_id INT,
    login_time TIMESTAMP,
    ip_address VARCHAR(45)
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

/* Q26. */
ALTER TABLE day_03_practice.customers ADD CONSTRAINT uq_customers_email UNIQUE (email);

/* Q27. */
ALTER TABLE day_03_practice.customers ALTER COLUMN email SET NOT NULL;

/* Q28. */
ALTER TABLE day_03_practice.products ADD CONSTRAINT chk_products_price_positive CHECK (price > 0);

/* Q29. */
ALTER TABLE day_03_practice.product_reviews ADD CONSTRAINT chk_reviews_rating CHECK (rating BETWEEN 1 AND 5);

/* Q30. */
ALTER TABLE day_03_practice.orders_demo ADD CONSTRAINT fk_orders_demo_cust
  FOREIGN KEY (cust_id) REFERENCES day_03_practice.customers(cust_id);

/* Q31. */
ALTER TABLE day_03_practice.orders_demo DROP CONSTRAINT fk_orders_demo_cust;
ALTER TABLE day_03_practice.orders_demo ADD CONSTRAINT fk_orders_demo_cust
  FOREIGN KEY (cust_id) REFERENCES day_03_practice.customers(cust_id) ON DELETE CASCADE;

/* Q32. */
ALTER TABLE day_03_practice.products ALTER COLUMN name SET NOT NULL;

/* Q33. */
ALTER TABLE day_03_practice.products ALTER COLUMN in_stock SET DEFAULT FALSE;

/* Q34. */
ALTER TABLE day_03_practice.customers ALTER COLUMN created_at SET DEFAULT NOW();

/* Q35. */
ALTER TABLE day_03_practice.tier_master ADD CONSTRAINT uq_tier_master_name UNIQUE (tier_name);

/* Q36. */
ALTER TABLE day_03_practice.employees ADD CONSTRAINT chk_employees_salary CHECK (salary >= 0);

/* Q37. */
ALTER TABLE day_03_practice.transactions ADD CONSTRAINT fk_transactions_from
  FOREIGN KEY (from_account) REFERENCES day_03_practice.bank_accounts(account_id);

/* Q38. */
ALTER TABLE day_03_practice.transactions ADD CONSTRAINT fk_transactions_to
  FOREIGN KEY (to_account) REFERENCES day_03_practice.bank_accounts(account_id);

/* Q39. */
ALTER TABLE day_03_practice.bank_accounts ADD CONSTRAINT chk_bank_accounts_balance CHECK (balance >= 0);

/* Q40. */
ALTER TABLE day_03_practice.bank_accounts ADD CONSTRAINT uq_bank_accounts_holder_opened UNIQUE (holder, opened_on);

/* Q41. */
SELECT conname FROM pg_constraint
WHERE conrelid = 'day_03_practice.products'::regclass AND contype = 'c';
ALTER TABLE day_03_practice.products DROP CONSTRAINT chk_products_price_positive;

/* Q42. */
ALTER TABLE day_03_practice.customers DROP CONSTRAINT uq_customers_email;

/* Q43. */
ALTER TABLE day_03_practice.orders_demo DROP CONSTRAINT fk_orders_demo_cust;

/* Q44. */
ALTER TABLE day_03_practice.feedback ALTER COLUMN rating SET NOT NULL;

/* Q45. */
ALTER TABLE day_03_practice.feedback ADD CONSTRAINT chk_feedback_rating CHECK (rating BETWEEN 1 AND 5);

/* Q46. */
ALTER TABLE day_03_practice.orders_demo ADD COLUMN status TEXT;
ALTER TABLE day_03_practice.orders_demo ALTER COLUMN status SET DEFAULT 'pending';

/* Q47. */
CREATE TABLE day_03_practice.scores (
    score_id SERIAL PRIMARY KEY,
    score INT CHECK (score BETWEEN 0 AND 100)
);

/* Q48. */
CREATE TABLE day_03_practice.employees_with_fk (
    emp_id SERIAL PRIMARY KEY,
    full_name VARCHAR(100),
    tier_id INT,
    CONSTRAINT fk_employees_with_fk_tier FOREIGN KEY (tier_id) REFERENCES day_03_practice.tier_master(tier_id)
);

/* Q49. */
ALTER TABLE day_03_practice.employees_with_fk DROP CONSTRAINT fk_employees_with_fk_tier;
ALTER TABLE day_03_practice.employees_with_fk ADD CONSTRAINT fk_employees_with_fk_tier
  FOREIGN KEY (tier_id) REFERENCES day_03_practice.tier_master(tier_id) ON DELETE SET NULL;

/* Q50. */
ALTER TABLE day_03_practice.transactions ADD CONSTRAINT uq_transactions_from_time UNIQUE (from_account, txn_time);

/* ============================================================
   SECTION C: INSERT DATA (25)
   ------------------------------------------------------------ */

/* Q51. */
INSERT INTO day_03_practice.customers (email, phone, is_active, created_at)
VALUES ('aarav@example.com', '+91 9000000001', TRUE, NOW());

/* Q52. */
INSERT INTO day_03_practice.customers (email) VALUES ('priya@example.com');

/* Q53. */
INSERT INTO day_03_practice.tier_master (tier_id, tier_name, min_points) VALUES
  (1, 'Bronze', 0),
  (2, 'Silver', 100),
  (3, 'Gold', 500);

/* Q54. */
INSERT INTO day_03_practice.products (name, price, in_stock) VALUES ('Mango Juice', 80.00, TRUE);

/* Q55. */
INSERT INTO day_03_practice.products (name, price) VALUES ('Premium Tea', 350.00);

/* Q56. Inserting an order with cust_id = 99999 (no such customer) fails with a foreign key violation: ERROR: insert or update on table "orders_demo" violates foreign key constraint "fk_orders_demo_cust" - since the FK from Q30/Q31 requires cust_id to already exist in customers. */

/* Q57. */
INSERT INTO day_03_practice.orders_demo (cust_id, total, order_date)
VALUES (1, 2500.00, CURRENT_DATE);

/* Q58. */
INSERT INTO day_03_practice.employees (full_name, salary, joined) VALUES
  ('Rahul Sharma', 45000, '2023-01-10'),
  ('Sneha Rao', 52000, '2023-02-15'),
  ('Vikram Singh', 48000, '2023-03-01'),
  ('Anita Desai', 61000, '2023-04-20'),
  ('Karan Mehta', NULL, '2023-05-05');

/* Q59. */
INSERT INTO day_03_practice.bank_accounts (holder, balance, opened_on)
VALUES ('Rahul Sharma', 50000, '2024-01-15');

/* Q60. */
INSERT INTO day_03_practice.bank_accounts (holder, balance, opened_on) VALUES
  ('Sneha Rao', 30000, '2024-02-01'),
  ('Vikram Singh', 75000, '2024-02-10'),
  ('Anita Desai', 20000, '2024-03-05');

/* Q61. */
INSERT INTO day_03_practice.transactions (from_account, to_account, amount, txn_time)
VALUES (1, 2, 5000, NOW());

/* Q62. Inserting a transaction with from_account = 99999 fails with a foreign key violation: ERROR: insert or update on table "transactions" violates foreign key constraint "fk_transactions_from" - because 99999 doesn't exist in bank_accounts. */

/* Q63. Inserting a customer with NULL email fails with: ERROR: null value in column "email" of relation "customers" violates not-null constraint - because of the NOT NULL added in Q27. */

/* Q64. Inserting a product with price = -100 fails with: ERROR: new row for relation "products" violates check constraint "chk_products_price_positive" - because -100 is not > 0. */

/* Q65. */
INSERT INTO day_03_practice.feedback (customer_id, rating, freeform)
VALUES (1, 5, 'Loved it!');

/* Q66. Inserting feedback with rating = 7 fails with: ERROR: new row for relation "feedback" violates check constraint "chk_feedback_rating" - because 7 is outside the BETWEEN 1 AND 5 range. */

/* Q67. */
INSERT INTO day_03_practice.events_log (payload, occurred_at)
VALUES ('{"event":"signup","city":"Mumbai"}', NOW());

/* Q68. */
INSERT INTO day_03_practice.sessions (session_id, user_id, started, ended)
VALUES (gen_random_uuid(), 1, NOW(), NULL);

/* Q69. */
INSERT INTO day_03_practice.brands (brand_name, country) VALUES ('AccioSnacks', 'India');

/* Q70. */
INSERT INTO day_03_practice.cities (city_name, state) VALUES
  ('Mumbai', 'MH'),
  ('Delhi', 'DL'),
  ('Bengaluru', 'KA');

/* Q71. */
INSERT INTO day_03_practice.payment_modes (mode_name, is_active) VALUES
  ('UPI', TRUE),
  ('COD', TRUE);

/* Q72. */
INSERT INTO day_03_practice.employees_with_fk (full_name, tier_id) VALUES ('Test User', 2);

/* Q73. Inserting a second row with an email already present in customers fails with: ERROR: duplicate key value violates unique constraint "uq_customers_email" - as long as that UNIQUE constraint from Q26 is still in place (it was dropped in Q42, so re-add it first if testing this after that step). */

/* Q74. */
CREATE TABLE day_03_practice.brands_copy (LIKE day_03_practice.brands INCLUDING ALL);
INSERT INTO day_03_practice.brands_copy SELECT * FROM day_03_practice.brands;

/* Q75. Inserting a transaction that repeats an existing (from_account, txn_time) pair fails with: ERROR: duplicate key value violates unique constraint "uq_transactions_from_time" - the UNIQUE constraint added in Q50 rejects the exact-duplicate transfer. */

/* ============================================================
   SECTION D: UPDATE / DELETE / TRUNCATE / TRANSACTIONS (25)
   ------------------------------------------------------------ */

/* Q76. */
UPDATE day_03_practice.customers SET is_active = FALSE WHERE cust_id = 1;

/* Q77. */
UPDATE day_03_practice.products SET in_stock = TRUE;

/* Q78. */
UPDATE day_03_practice.products SET price = price * 1.10;

/* Q79. */
UPDATE day_03_practice.employees SET salary = 50000 WHERE salary IS NULL;

/* Q80. */
UPDATE day_03_practice.customers SET phone = '+91 9999999999' WHERE email = 'aarav@example.com';

/* Q81. */
UPDATE day_03_practice.bank_accounts SET balance = balance - 1000 WHERE account_id = 1;

/* Q82. */
UPDATE day_03_practice.bank_accounts SET balance = balance + 1000 WHERE account_id = 2;

/* Q83. */
DELETE FROM day_03_practice.customers WHERE cust_id = 1;

/* Q84. */
DELETE FROM day_03_practice.products WHERE price < 50;

/* Q85. */
DELETE FROM day_03_practice.feedback WHERE rating < 3;

/* Q86. */
DELETE FROM day_03_practice.customers WHERE cust_id = 2;

/* Q87. */
TRUNCATE day_03_practice.feedback;

/* Q88. */
TRUNCATE day_03_practice.events_log RESTART IDENTITY;

/* Q89. */
BEGIN;
UPDATE day_03_practice.bank_accounts SET balance = balance - 5000 WHERE account_id = 1;
UPDATE day_03_practice.bank_accounts SET balance = balance + 5000 WHERE account_id = 2;
COMMIT;

/* Q90. */
BEGIN;
UPDATE day_03_practice.bank_accounts SET balance = 0;
ROLLBACK;
SELECT account_id, balance FROM day_03_practice.bank_accounts;

/* Q91. */
UPDATE day_03_practice.products SET name = INITCAP(name);

/* Q92. */
UPDATE day_03_practice.employees SET dept_name = 'Engineering' WHERE dept_name IS NULL;

/* Q93. */
DELETE FROM day_03_practice.notifications WHERE sent_at < CURRENT_DATE - INTERVAL '30 days';

/* Q94. */
UPDATE day_03_practice.subscriptions SET auto_renew = FALSE WHERE ends < CURRENT_DATE;

/* Q95. */
DELETE FROM day_03_practice.login_log WHERE login_time < CURRENT_DATE - INTERVAL '90 days';

/* Q96. */
TRUNCATE day_03_practice.notifications;

/* Q97. */
DELETE FROM day_03_practice.sessions WHERE ended IS NOT NULL;

/* Q98. */
UPDATE day_03_practice.orders_demo SET total = 0 WHERE total IS NULL;

/* Q99. Inside a transaction, INSERT INTO day_03_practice.customers (email) VALUES ('temp@example.com'); then ROLLBACK; - after the ROLLBACK, SELECT * FROM day_03_practice.customers WHERE email = 'temp@example.com'; returns no rows, because the whole transaction (including that INSERT) was undone as if it never ran. */

/* Q100. */
TRUNCATE day_03_practice.customers CASCADE;

/* ============================================================
   END OF ANSWER KEY - EASY LEVEL (100/100)
============================================================ */
