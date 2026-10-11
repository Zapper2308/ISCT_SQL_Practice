/* ============================================================
   ANSWER KEY - DDL & Data Types (HARD LEVEL)
   Curriculum:   RetailMart V3
   Note: Section B/C/D run in YOUR accio_NN practice DB, using a
   day_03_practice schema - NOT against RetailMart V3.
   ============================================================ */

/* Q1.  A GENERATED ALWAYS AS column is computed automatically from other columns in the same row; use cases: order_items.net_amount from gross-discount, a full_name from first+last, or a lower(email) column for case-insensitive lookups. */
/* Q2.  STORED generated columns are computed on write and physically saved on disk (readable/indexable like a normal column); VIRTUAL ones would be computed on every read instead and never stored - PostgreSQL currently only implements STORED. */
/* Q3.  Time-series queries almost always filter/aggregate by a date range, so RANGE partitioning on order_date lets the planner prune (skip) every partition outside that range and lets old months be dropped or archived as whole cheap-to-remove partitions. */
/* Q4.  Choose RANGE for continuous, ordered data like dates or numeric ranges; LIST when rows fall into a small set of discrete known categories (region_id, priority); HASH when you just need to spread rows evenly for parallelism/size management and there's no natural range or category to split on. */
/* Q5.  Partition pruning is the planner skipping partitions that can't contain matching rows; it needs the partition key literally in the WHERE clause (as a constant or comparable expression) at plan time so it can statically eliminate partitions before execution even begins. */
/* Q6.  Legacy inheritance uses manually-written CHECK constraints and triggers/rules to route rows and is never partition-pruning-aware by default; declarative PARTITIONING (PG10+) is a first-class feature with automatic row routing, built-in pruning, and simpler DDL (ATTACH/DETACH PARTITION). */
/* Q7.  A DOMAIN wraps a base type with a reusable named CHECK (e.g. positive_money AS numeric CHECK (VALUE > 0)); it's cleaner than repeating the same CHECK on every table/column that needs that rule, since you define the validation once and reuse the type everywhere. */
/* Q8.  A COMPOSITE type groups several fields into one reusable structured type, e.g. CREATE TYPE address AS (street text, city text, zip varchar(10)) used as a single column type instead of three separate columns repeated across tables. */
/* Q9.  Use ENUM for a small, truly fixed set of values that rarely changes and is core to the domain model (order_status); use a lookup table when the set of values might grow, need extra metadata, or must be queried/joined like normal data. */
/* Q10. ALTER TYPE ... ADD VALUE historically couldn't run inside the same transaction as using that new value, and reordering/removing values isn't supported at all - any of those changes require careful migrations, unlike a lookup table where adding a row is a trivial INSERT. */
/* Q11. A regex CHECK like email ~ '^[^@]+@[^@]+\.[^@]+$' validates format at write time; avoid doing this in DDL when the rule needs to change often or vary by business logic - application-level or trigger-based validation is easier to evolve than a CHECK baked into the schema. */
/* Q12. An EXCLUSION constraint generalizes UNIQUE to arbitrary operators - e.g. EXCLUDE USING gist (room WITH =, during WITH &&) rejects inserting a new booking for the same room whose time range (&&) overlaps any existing booking for that room. */
/* Q13. ON DELETE CASCADE when child rows are meaningless without the parent (order_items when the order is deleted); SET NULL when the child should survive but lose the reference (a review whose customer account is deleted); RESTRICT when deleting the parent while children exist should be blocked outright (protecting financial records). */
/* Q14. A DEFERRABLE constraint can be checked at COMMIT instead of immediately after each statement; INITIALLY DEFERRED is useful for circular or mutually-referencing FKs where you must insert both rows before either one can satisfy the other's constraint. */
/* Q15. Postgres requires the partition key to be part of (or fully included in) any UNIQUE/PK constraint on a partitioned table because uniqueness can only be enforced per-partition - without the partition key in the key, two different partitions could each independently allow the "same" duplicate value. */
/* Q16. ATTACH PARTITION adds an existing, already-populated table as a partition (near-instant if its constraints already match the target range, since Postgres just updates catalog metadata); DETACH PARTITION removes a partition from the parent, again as a fast metadata operation, leaving the data still fully queryable as its own standalone table. */
/* Q17. Sub-partitioning partitions a partition again by another key (e.g. RANGE by year then LIST by month); most setups avoid it because it multiplies the number of physical partitions (and per-partition indexes/constraints) rapidly, adding planning overhead that often outweighs the pruning benefit. */
/* Q18. A GENERATED column is maintained automatically by Postgres itself on every INSERT/UPDATE with guaranteed consistency and no extra round trip; a trigger-based computed column gives more flexibility (can reference other tables) but adds trigger overhead and risks drifting out of sync if the trigger logic has a bug. */
/* Q19. A "default partition" catches any row whose partition key doesn't match any explicitly defined range/list; without one, an INSERT for an out-of-range value is rejected outright with a "no partition of relation found for row" error. */
/* Q20. HASH partitioning distributes rows pseudo-randomly across partitions by hashing the key, so a time-range query has no way to know which partitions might contain matching rows - every partition must be scanned, defeating the whole point of pruning. */
/* Q21. Since PG12, a FOREIGN KEY can reference a partitioned parent table directly (the constraint is enforced logically across all its partitions), though the referenced columns must be covered by the parent's partition key plus its primary/unique key. */
/* Q22. "Constraint exclusion" was the legacy (pre-PG10) planner optimization that inferred prunability from manually-written CHECK constraints on inherited tables; "partition pruning" is the modern, built-in mechanism for declared partitioned tables that's faster and doesn't depend on hand-written CHECKs. */
/* Q23. CREATE TABLE new_tbl (LIKE old_tbl INCLUDING ALL) copies column definitions, defaults, NOT NULL, CHECK constraints, and indexes (depending on the INCLUDING options chosen) but copies no data and, by default, no foreign keys/triggers unless explicitly included. */
/* Q24. CREATE TABLE AS SELECT copies data but NOT constraints/indexes/defaults from the source; CREATE TABLE (matching DDL) + INSERT INTO ... SELECT preserves whatever constraints you explicitly declare in the CREATE TABLE, giving you full control over what's enforced going forward. */
/* Q25. ALTER TYPE ... ADD VALUE must commit its catalog change immediately so the new enum label is visible for any subsequent statement in the same session/transaction; historically Postgres disallowed it inside a transaction block entirely to guarantee that visibility rule, though modern versions relax this as long as the new value isn't used in the same transaction that added it. */

/* ============================================================
   SECTION B: PARTITIONED TABLES (25)
   ------------------------------------------------------------ */
DROP SCHEMA IF EXISTS day_03_practice CASCADE;
CREATE SCHEMA IF NOT EXISTS day_03_practice;

/* Q26. */
CREATE TABLE day_03_practice.orders_p (
    order_id BIGSERIAL,
    cust_id INT,
    order_date DATE NOT NULL,
    net_total NUMERIC(12,2)
) PARTITION BY RANGE (order_date);

DO $$
DECLARE
  m DATE;
BEGIN
  FOR m IN SELECT generate_series('2024-01-01'::date, '2025-12-01'::date, interval '1 month') LOOP
    EXECUTE format(
      'CREATE TABLE day_03_practice.orders_p_%s PARTITION OF day_03_practice.orders_p FOR VALUES FROM (%L) TO (%L)',
      to_char(m,'YYYY_MM'), m, m + interval '1 month'
    );
  END LOOP;
END $$;

/* Q27. */
CREATE TABLE day_03_practice.orders_p_default PARTITION OF day_03_practice.orders_p DEFAULT;

/* Q28. */
DO $$
DECLARE
  m DATE;
BEGIN
  FOR m IN SELECT generate_series('2026-01-01'::date, '2026-12-01'::date, interval '1 month') LOOP
    EXECUTE format(
      'CREATE TABLE day_03_practice.orders_p_%s PARTITION OF day_03_practice.orders_p FOR VALUES FROM (%L) TO (%L)',
      to_char(m,'YYYY_MM'), m, m + interval '1 month'
    );
  END LOOP;
END $$;

/* Q29. */
CREATE TABLE day_03_practice.orders_p_2027_01 (
    order_id BIGINT NOT NULL,
    cust_id INT,
    order_date DATE NOT NULL,
    net_total NUMERIC(12,2)
);
ALTER TABLE day_03_practice.orders_p ATTACH PARTITION day_03_practice.orders_p_2027_01
  FOR VALUES FROM ('2027-01-01') TO ('2027-02-01');

/* Q30. */
ALTER TABLE day_03_practice.orders_p DETACH PARTITION day_03_practice.orders_p_2027_01;
SELECT count(*) FROM day_03_practice.orders_p_2027_01;

/* Q31. */
CREATE TABLE day_03_practice.customer_events (
    event_id BIGSERIAL,
    customer_id INT NOT NULL,
    event_type VARCHAR(30)
) PARTITION BY HASH (customer_id);

DO $$
BEGIN
  FOR i IN 0..7 LOOP
    EXECUTE format('CREATE TABLE day_03_practice.customer_events_%s PARTITION OF day_03_practice.customer_events FOR VALUES WITH (MODULUS 8, REMAINDER %s)', i, i);
  END LOOP;
END $$;

/* Q32. */
CREATE TABLE day_03_practice.regional_orders (
    order_id BIGSERIAL,
    region_id INT NOT NULL,
    net_total NUMERIC(12,2)
) PARTITION BY LIST (region_id);

CREATE TABLE day_03_practice.regional_orders_r1 PARTITION OF day_03_practice.regional_orders FOR VALUES IN (1);
CREATE TABLE day_03_practice.regional_orders_r2 PARTITION OF day_03_practice.regional_orders FOR VALUES IN (2);

/* Q33. */
INSERT INTO day_03_practice.orders_p (cust_id, order_date, net_total)
SELECT (random()*1000)::int, d, (random()*5000)::numeric(12,2)
FROM generate_series('2024-01-01'::date, '2024-12-01'::date, interval '1 month') d,
     generate_series(1,5);

/* Q34. */
SELECT count(*) FROM ONLY day_03_practice.orders_p_2024_03;

/* Q35. */
EXPLAIN SELECT * FROM day_03_practice.orders_p WHERE order_date BETWEEN '2024-03-01' AND '2024-03-31';

/* Q36. */
CREATE INDEX idx_orders_p_2024_03_cust ON day_03_practice.orders_p_2024_03(cust_id);

/* Q37. */
CREATE INDEX idx_orders_p_cust ON day_03_practice.orders_p(cust_id);

/* Q38. */
DROP TABLE day_03_practice.orders_p_2024_01;

/* Q39. Archiving a partition: ALTER TABLE day_03_practice.orders_p DETACH PARTITION day_03_practice.orders_p_2024_02; then \copy day_03_practice.orders_p_2024_02 TO '/tmp/orders_2024_02.csv' CSV; then DROP TABLE day_03_practice.orders_p_2024_02; - detach makes it a normal standalone table you can export before dropping. */

/* Q40. */
SELECT parent.relname AS parent_table, child.relname AS partition_name
FROM pg_inherits i
JOIN pg_class parent ON parent.oid = i.inhparent
JOIN pg_class child ON child.oid = i.inhrelid
WHERE parent.relname = 'orders_p';

/* Q41. DELETE FROM day_03_practice.orders_p WHERE order_date < '2024-06-01'; must scan and delete matching rows one by one with full WAL logging; ALTER TABLE day_03_practice.orders_p DETACH PARTITION day_03_practice.orders_p_2024_03; DROP TABLE day_03_practice.orders_p_2024_03; instead removes an entire month instantly as a metadata-only operation with no row-by-row deletion cost. */

/* Q42. */
ALTER TABLE day_03_practice.orders_p_2024_03 ADD CONSTRAINT chk_2024_03_range
  CHECK (order_date >= '2024-03-01' AND order_date < '2024-04-01');

/* Q43. */
CREATE TABLE day_03_practice.orders_p_2028_01 PARTITION OF day_03_practice.orders_p
  FOR VALUES FROM ('2028-01-01') TO ('2028-02-01');

/* Q44. Without a default partition, INSERT INTO day_03_practice.orders_p (cust_id, order_date, net_total) VALUES (1, '2099-01-01', 100); would fail with "no partition of relation "orders_p" found for row" - the row is rejected outright rather than silently placed anywhere. */

/* Q45. A default partition safely absorbs out-of-range rows first (INSERT works instead of erroring); periodically run a job that SELECTs rows out of the default partition matching a now-known range, INSERTs them into a properly created partition, then DELETEs them from the default - keeping the default partition small over time. */

/* Q46. */
UPDATE day_03_practice.orders_p SET order_date = order_date + INTERVAL '1 month'
WHERE order_date = '2024-05-01';

/* Q47. */
SELECT relname, pg_size_pretty(pg_total_relation_size(oid))
FROM pg_class
WHERE relname LIKE 'orders\_p\_%' ESCAPE '\'
ORDER BY relname;

/* Q48. */
CREATE TABLE day_03_practice.page_views_p (
    view_id BIGSERIAL,
    customer_id INT
) PARTITION BY HASH (customer_id);

DO $$
BEGIN
  FOR i IN 0..15 LOOP
    EXECUTE format('CREATE TABLE day_03_practice.page_views_p_%s PARTITION OF day_03_practice.page_views_p FOR VALUES WITH (MODULUS 16, REMAINDER %s)', i, i);
  END LOOP;
END $$;

/* Q49. */
CREATE TABLE day_03_practice.tickets_p (
    ticket_id BIGSERIAL,
    priority VARCHAR(20) NOT NULL
) PARTITION BY LIST (priority);

CREATE TABLE day_03_practice.tickets_p_critical PARTITION OF day_03_practice.tickets_p FOR VALUES IN ('Critical');
CREATE TABLE day_03_practice.tickets_p_other PARTITION OF day_03_practice.tickets_p FOR VALUES IN ('High','Medium','Low');

/* Q50. */
CREATE TABLE day_03_practice.pay_slips_p (
    pay_slip_id BIGSERIAL,
    salary_year INT NOT NULL,
    salary_month VARCHAR(10) NOT NULL
) PARTITION BY RANGE (salary_year);

CREATE TABLE day_03_practice.pay_slips_p_2025 PARTITION OF day_03_practice.pay_slips_p
  FOR VALUES FROM (2025) TO (2026) PARTITION BY LIST (salary_month);

CREATE TABLE day_03_practice.pay_slips_p_2025_jan PARTITION OF day_03_practice.pay_slips_p_2025 FOR VALUES IN ('January');

/* ============================================================
   SECTION C: CUSTOM TYPES (DOMAINS, ENUMS, COMPOSITES) (25)
   ------------------------------------------------------------ */
CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

/* Q51. */
CREATE DOMAIN day_03_practice.positive_money AS numeric(10,2) CHECK (VALUE > 0);

/* Q52. */
CREATE DOMAIN day_03_practice.us_state AS char(2) CHECK (VALUE ~ '^[A-Z]{2}$');

/* Q53. */
CREATE DOMAIN day_03_practice.email_address AS text CHECK (VALUE ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

/* Q54. */
CREATE TABLE day_03_practice.customers_strict (
    cust_id SERIAL PRIMARY KEY,
    email day_03_practice.email_address
);

/* Q55. */
CREATE TYPE day_03_practice.address AS (street text, city text, state char(2), zip varchar(10));

/* Q56. */
CREATE TABLE day_03_practice.customers_with_addr (
    cust_id SERIAL PRIMARY KEY,
    addr day_03_practice.address
);

/* Q57. */
INSERT INTO day_03_practice.customers_with_addr (addr) VALUES (ROW('123 Main','LA','CA','90001'));

/* Q58. */
SELECT (addr).city FROM day_03_practice.customers_with_addr;

/* Q59. */
CREATE TYPE day_03_practice.order_status AS ENUM ('Placed','Paid','Shipped','Delivered','Cancelled');

/* Q60. */
CREATE TABLE day_03_practice.strict_orders (
    order_id SERIAL PRIMARY KEY,
    status day_03_practice.order_status
);

/* Q61. */
ALTER TYPE day_03_practice.order_status ADD VALUE 'Returned';

/* Q62. */
ALTER TYPE day_03_practice.order_status ADD VALUE 'Refund_Pending' BEFORE 'Cancelled';

/* Q63. An ENUM value is stored internally as a 4-byte OID-like identifier regardless of the label's text length, so it's always smaller and faster to compare than VARCHAR (which stores and compares the full label text); the tradeoff is ENUM's rigid, hard-to-modify value set versus VARCHAR's flexibility. */

/* Q64. */
CREATE DOMAIN day_03_practice.temp_domain AS text;
DROP DOMAIN day_03_practice.temp_domain;
/* Dropping a domain requires no dependents because Postgres can't safely decide what base type/constraint to fall back a column to if the domain is still in use - any column still typed with that domain would become invalid, so you must ALTER those columns to a different type first (or use DROP DOMAIN ... CASCADE to force it, which also drops the dependent columns' constraints). */

/* Q65. */
CREATE DOMAIN day_03_practice.nonneg_int AS int CHECK (VALUE >= 0);
CREATE TYPE day_03_practice.dims AS (length day_03_practice.nonneg_int, width day_03_practice.nonneg_int);
CREATE TABLE day_03_practice.boxes (box_id SERIAL PRIMARY KEY, dims day_03_practice.dims);

/* Q66. Inserting a value that violates a DOMAIN's CHECK raises: ERROR: value for domain email_address violates check constraint "email_address_check" - the same style of error a table-level CHECK would give, just attributed to the domain's constraint name instead of a table constraint. */

/* Q67. */
SELECT '[1,10)'::int4range;

/* Q68. */
CREATE TABLE day_03_practice.citext_emails (id SERIAL PRIMARY KEY, email CITEXT);

/* Q69. */
CREATE TABLE day_03_practice.uuid_demo (id UUID PRIMARY KEY DEFAULT gen_random_uuid());

/* Q70. */
CREATE TABLE day_03_practice.jsonb_objects (id SERIAL PRIMARY KEY, data JSONB CHECK (jsonb_typeof(data) = 'object'));

/* Q71. SERIAL is the older sugar syntax (INT + an implicitly-owned sequence + DEFAULT nextval); BIGSERIAL is the same but BIGINT-backed for higher ranges; GENERATED ALWAYS/BY DEFAULT AS IDENTITY (SQL-standard, PG10+) is the modern replacement for both, preferred because the sequence is a true internal part of the column rather than a separately-visible, independently-droppable object. */

/* Q72. Dropping a domain with CASCADE drops every column, default, and constraint that depends on it across every table using that domain - a single DROP DOMAIN ... CASCADE can silently remove columns from many tables, so it must be used with extreme care in production. */

/* Q73. */
CREATE TABLE day_03_practice.money_demo (id SERIAL PRIMARY KEY, amount NUMERIC(10,2));
ALTER TABLE day_03_practice.money_demo ALTER COLUMN amount TYPE day_03_practice.positive_money;

/* Q74. */
CREATE TYPE day_03_practice.product_dimensions AS (length numeric, width numeric, height numeric);

/* Q75. */
CREATE TABLE day_03_practice.sized_products (
    product_id SERIAL PRIMARY KEY,
    dim day_03_practice.product_dimensions,
    CHECK ((dim).length > 0 AND (dim).width > 0)
);

/* ============================================================
   SECTION D: CONSTRAINT PATTERNS (25)
   ------------------------------------------------------------ */
CREATE EXTENSION IF NOT EXISTS btree_gist;

/* Q76. */
CREATE TABLE day_03_practice.products_strict (
    product_id SERIAL PRIMARY KEY,
    price NUMERIC(12,2),
    discount_pct INT,
    CHECK (price > 0 AND discount_pct BETWEEN 0 AND 100)
);

/* Q77. */
CREATE TABLE day_03_practice.campaigns_strict (
    campaign_id SERIAL PRIMARY KEY,
    start_date DATE,
    end_date DATE,
    CHECK (end_date >= start_date)
);

/* Q78. */
CREATE TABLE day_03_practice.email_test (
    id SERIAL PRIMARY KEY,
    email VARCHAR(100) CHECK (email ~ '^[^@]+@[^@]+\.[^@]+$')
);
INSERT INTO day_03_practice.email_test (email) VALUES ('test@example.com');

/* Q79. */
CREATE TABLE day_03_practice.bookings (
    booking_id SERIAL PRIMARY KEY,
    room INT NOT NULL,
    during TSRANGE NOT NULL,
    EXCLUDE USING gist (room WITH =, during WITH &&)
);

/* Q80. */
CREATE TABLE day_03_practice.shifts (
    shift_id SERIAL PRIMARY KEY,
    employee_id INT NOT NULL,
    during TSRANGE NOT NULL,
    EXCLUDE USING gist (employee_id WITH =, during WITH &&)
);

/* Q81. */
CREATE TABLE day_03_practice.review_unique (
    review_id SERIAL PRIMARY KEY,
    customer_id INT,
    product_id INT,
    review_date DATE,
    UNIQUE (customer_id, product_id, review_date)
);

/* Q82. */
CREATE TABLE day_03_practice.nulls_demo (
    id SERIAL PRIMARY KEY,
    code VARCHAR(20),
    UNIQUE NULLS NOT DISTINCT (code)
);

/* Q83. */
CREATE TABLE day_03_practice.phone_check (
    id SERIAL PRIMARY KEY,
    phone_number VARCHAR(20) CHECK (phone_number ~ '^[0-9]{10}$')
);

/* Q84. */
CREATE TABLE day_03_practice.cust_parent (cust_id SERIAL PRIMARY KEY);
CREATE TABLE day_03_practice.orders_child (order_id SERIAL PRIMARY KEY, cust_id INT REFERENCES day_03_practice.cust_parent(cust_id) ON DELETE CASCADE);
CREATE TABLE day_03_practice.order_items_child (item_id SERIAL PRIMARY KEY, order_id INT REFERENCES day_03_practice.orders_child(order_id) ON DELETE CASCADE);

/* Q85. */
CREATE TABLE day_03_practice.reviews_setnull (
    review_id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES day_03_practice.cust_parent(cust_id) ON DELETE SET NULL
);

/* Q86. */
CREATE TABLE day_03_practice.products_parent (product_id INT PRIMARY KEY);
CREATE TABLE day_03_practice.reviews_onupdate (
    review_id SERIAL PRIMARY KEY,
    product_id INT REFERENCES day_03_practice.products_parent(product_id) ON UPDATE CASCADE
);

/* Q87. */
CREATE TABLE day_03_practice.circ_a (id INT PRIMARY KEY, b_id INT);
CREATE TABLE day_03_practice.circ_b (id INT PRIMARY KEY, a_id INT REFERENCES day_03_practice.circ_a(id) DEFERRABLE INITIALLY DEFERRED);
ALTER TABLE day_03_practice.circ_a ADD CONSTRAINT fk_circ_a_b FOREIGN KEY (b_id) REFERENCES day_03_practice.circ_b(id) DEFERRABLE INITIALLY DEFERRED;

/* Q88. */
CREATE TABLE day_03_practice.fk_target (id INT PRIMARY KEY);
CREATE TABLE day_03_practice.fk_source (id INT PRIMARY KEY, target_id INT);
ALTER TABLE day_03_practice.fk_source ADD CONSTRAINT fk_source_target FOREIGN KEY (target_id) REFERENCES day_03_practice.fk_target(id) NOT VALID;
ALTER TABLE day_03_practice.fk_source VALIDATE CONSTRAINT fk_source_target;

/* Q89. */
CREATE TABLE day_03_practice.nn_demo (id SERIAL PRIMARY KEY, flag BOOLEAN);
ALTER TABLE day_03_practice.nn_demo ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT 'active';

/* Q90. */
CREATE TABLE day_03_practice.gen_name_demo (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50)
);
ALTER TABLE day_03_practice.gen_name_demo ADD COLUMN full_name VARCHAR(101) GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED;

/* Q91. */
CREATE INDEX idx_gen_name_demo_fullname ON day_03_practice.gen_name_demo(full_name);

/* Q92. Yes - a CHECK constraint declared on a partitioned parent is NOT automatically enforced by re-checking every partition's data; each partition is its own physical table, so the same CHECK (or an equivalent one) generally needs to exist on every partition (declaring it on the parent with ONLY-aware DDL propagates it to partitions created afterward, but existing partitions still need it added explicitly). */

/* Q93. A partitioned table's PRIMARY KEY must include the partition key because uniqueness can only be verified within a single partition - if the PK didn't include the partition key, two different partitions could each contain a row with the "same" PK value and Postgres would have no cross-partition way to detect or prevent that duplicate. */

/* Q94. */
CREATE TABLE day_03_practice.orders_part_fk (
    order_id BIGINT NOT NULL,
    order_date DATE NOT NULL,
    PRIMARY KEY (order_id, order_date)
) PARTITION BY RANGE (order_date);

CREATE TABLE day_03_practice.orders_part_fk_2025 PARTITION OF day_03_practice.orders_part_fk
  FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

CREATE TABLE day_03_practice.order_items_part_fk (
    item_id SERIAL PRIMARY KEY,
    order_id BIGINT,
    order_date DATE,
    FOREIGN KEY (order_id, order_date) REFERENCES day_03_practice.orders_part_fk(order_id, order_date)
);

/* Q95. */
CREATE TABLE day_03_practice.employees_selfref (
    employee_id SERIAL PRIMARY KEY,
    manager_id INT REFERENCES day_03_practice.employees_selfref(employee_id) ON DELETE SET NULL
);

/* Q96. */
CREATE TABLE day_03_practice.composite_parent (a INT, b INT, PRIMARY KEY (a,b));
CREATE TABLE day_03_practice.composite_child (
    id SERIAL PRIMARY KEY,
    a INT, b INT,
    FOREIGN KEY (a,b) REFERENCES day_03_practice.composite_parent(a,b)
);

/* Q97. */
CREATE TABLE day_03_practice.partial_unique_demo (
    id SERIAL PRIMARY KEY,
    email VARCHAR(100),
    deleted_at TIMESTAMPTZ
);
CREATE UNIQUE INDEX idx_partial_unique_email ON day_03_practice.partial_unique_demo(email) WHERE deleted_at IS NULL;

/* Q98. */
CREATE TABLE day_03_practice.soft_delete_demo (
    id SERIAL PRIMARY KEY,
    email VARCHAR(100),
    deleted_at TIMESTAMPTZ
);
CREATE UNIQUE INDEX idx_soft_delete_email ON day_03_practice.soft_delete_demo(email) WHERE deleted_at IS NULL;

/* Q99. PostgreSQL rejects a CHECK constraint that references another table (e.g. CHECK (EXISTS (SELECT 1 FROM other_table ...))) because a CHECK must be evaluable purely from the row being written, with no guarantee the referenced table's data stays consistent afterward; the workaround is a trigger (or, for simple cross-table uniqueness, a FOREIGN KEY) that runs the cross-table validation explicitly on INSERT/UPDATE. */

/* Q100. */
CREATE TABLE day_03_practice.employees_rich (
    employee_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email day_03_practice.email_address UNIQUE,
    dept_id INT REFERENCES core.dim_department(dept_id),
    age INT CHECK (age >= 18),
    salary NUMERIC(12,2) CHECK (salary > 0),
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    full_name VARCHAR(101) GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

/* ============================================================
   END OF ANSWER KEY - HARD LEVEL (100/100)
============================================================ */
