/* ============================================================
   ANSWER KEY - DDL & Data Types (CRAZY LEVEL)
   Curriculum:   RetailMart V3
   Note: Section B/C/D run in YOUR accio_NN practice DB, using a
   day_03_practice schema - NOT against RetailMart V3. Several
   questions here (Snowflake IDs, FDW/S3 cold storage, ULID
   generation, read-replica routing) describe architecture that
   needs infrastructure beyond a single Postgres instance, so
   those are answered conceptually with the pattern you'd apply.
   ============================================================ */

/* ============================================================
   SECTION A: SHARDING-READY DESIGN (25)
   ------------------------------------------------------------ */
DROP SCHEMA IF EXISTS day_03_practice CASCADE;
CREATE SCHEMA IF NOT EXISTS day_03_practice;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

/* Q1. */
CREATE TABLE day_03_practice.orders_tenant (
    tenant_id INT NOT NULL,
    order_id BIGINT NOT NULL,
    order_date DATE,
    PRIMARY KEY (tenant_id, order_id)
);

/* Q2. A composite (tenant_id, order_id) PK keeps order_id meaningful only within its tenant (simple, sequential, cheap to index) but requires every query/join to carry tenant_id; a standalone UUID order_id is globally unique on its own (no tenant_id needed to look it up) but is larger, unordered (hurts index locality), and doesn't naturally co-locate a tenant's rows - composite PKs are usually preferred for sharded, tenant-scoped access patterns. */

/* Q3. */
CREATE TABLE day_03_practice.order_items_tenant (
    tenant_id INT NOT NULL,
    item_id BIGSERIAL,
    order_id BIGINT NOT NULL,
    PRIMARY KEY (tenant_id, item_id),
    FOREIGN KEY (tenant_id, order_id) REFERENCES day_03_practice.orders_tenant(tenant_id, order_id)
);

/* Q4. */
CREATE TABLE day_03_practice.uuid_pk_demo (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id INT NOT NULL
);

/* Q5. A "fanout-resistant" customer table avoids one hot row that every other write touches (e.g. a running total updated by thousands of concurrent orders); instead of UPDATE customers SET total_spend = total_spend + x, insert immutable event rows (order totals) and SUM() them on read, or shard the counter into N sub-counters that are summed together. */

/* Q6. Co-locating related tables by tenant_id means every table that belongs to one tenant physically routes to the same shard (via the same partition/shard key), so a tenant's own queries never need a cross-shard join - only cross-tenant analytics would need to fan out. */

/* Q7. Small, slow-changing dimension tables (core.dim_region, core.dim_category) are cheap to fully replicate to every shard rather than sharding them - each shard keeps a complete local copy, so joins against them never cross shard boundaries, at the cost of needing to propagate any update to every replica. */

/* Q8. */
CREATE TABLE day_03_practice.shard_hint_demo (
    tenant_id INT NOT NULL,
    id BIGSERIAL,
    shard_hint INT GENERATED ALWAYS AS (tenant_id % 16) STORED,
    PRIMARY KEY (tenant_id, id)
);

/* Q9. */
CREATE TABLE day_03_practice.shard_map (
    tenant_id INT PRIMARY KEY,
    shard_id INT NOT NULL
);

/* Q10. A Snowflake ID packs a 41-bit millisecond timestamp, a ~10-bit node/worker ID, and a ~12-bit per-millisecond sequence number into one 64-bit integer, generated locally by each node with no central coordination - giving roughly time-sortable, globally-unique IDs without a shared sequence becoming a bottleneck. */

/* Q11. A single global sequence forces every shard/node to coordinate through one counter, becoming a write bottleneck and single point of failure at scale; per-shard sequences (or Snowflake-style node-embedded IDs) let each shard generate IDs independently, trading strict global ordering for horizontal write scalability. */

/* Q12. An audit log needs its own stable, globally-unique key (UUID or Snowflake ID) that doesn't depend on which shard the audited row currently lives on, plus it should record the row's shard/tenant_id at the time of the event, so history stays queryable even after the underlying row is moved during a shard split or merge. */

/* Q13. */
ALTER TABLE day_03_practice.orders_tenant
  ADD COLUMN created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN last_modified TIMESTAMPTZ NOT NULL DEFAULT now();

/* Q14. */
CREATE TABLE day_03_practice.id_sequences (
    shard_id INT PRIMARY KEY,
    next_id BIGINT NOT NULL DEFAULT 1
);
UPDATE day_03_practice.id_sequences SET next_id = next_id + 1 WHERE shard_id = 1 RETURNING next_id;

/* Q15. A "logical replication-ready" primary key is one that's stable and never reused (no recycled surrogate IDs), globally unique across shards (UUID or Snowflake-style, not a per-shard-only SERIAL), and doesn't rely on shard-local sequence state - so a publisher/subscriber pair can replay INSERT/UPDATE/DELETE events by key without ID collisions across sources. */

/* Q16. */
CREATE TABLE day_03_practice.orders_shard1 (LIKE day_03_practice.orders_tenant INCLUDING ALL);
CREATE TABLE day_03_practice.orders_shard2 (LIKE day_03_practice.orders_tenant INCLUDING ALL);
CREATE VIEW day_03_practice.orders_all_shards AS
  SELECT * FROM day_03_practice.orders_shard1
  UNION ALL
  SELECT * FROM day_03_practice.orders_shard2;

/* Q17. */
CREATE TABLE day_03_practice.tickets_hot (
    ticket_id SERIAL PRIMARY KEY,
    status VARCHAR(20),
    tenant_id INT
);
CREATE INDEX idx_tickets_open ON day_03_practice.tickets_hot(tenant_id) WHERE status = 'Open';

/* Q18. */
CREATE TABLE day_03_practice.soft_delete_shard (
    id BIGINT PRIMARY KEY,
    deleted_at TIMESTAMPTZ
);
UPDATE day_03_practice.soft_delete_shard SET deleted_at = COALESCE(deleted_at, now()) WHERE id = 1;

/* Q19. Small reference/dimension data is periodically refreshed into a materialized view on each shard (REFRESH MATERIALIZED VIEW dim_region_mv) rather than queried live from a central source, so every shard keeps a fast, fully-local, eventually-consistent copy for joins without a cross-shard round trip. */

/* Q20. A "shard split" divides one shard's ID/tenant range in half and moves the upper half to a new shard; picking split points on clean, even boundaries (e.g. tenant_id ranges, or hash-bucket halves) up front makes each future split a simple range cut instead of an ad-hoc rebalancing of arbitrary rows. */

/* Q21. A "shard merge" is the reverse: two shards whose key ranges are adjacent (or whose combined size is now small enough) are consolidated back into one, updating the shard_map's range boundaries and moving the smaller shard's rows into the surviving one, usually during a low-traffic maintenance window. */

/* Q22. */
CREATE OR REPLACE FUNCTION day_03_practice.insert_order(p_tenant_id INT, p_order_id BIGINT, p_order_date DATE)
RETURNS VOID AS $$
BEGIN
  INSERT INTO day_03_practice.orders_tenant (tenant_id, order_id, order_date)
  VALUES (p_tenant_id, p_order_id, p_order_date)
  ON CONFLICT (tenant_id, order_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql;

/* Q23. */
CREATE TABLE day_03_practice.shard_1_orders (
    tenant_id INT NOT NULL CHECK (tenant_id = 1),
    order_id BIGINT NOT NULL,
    PRIMARY KEY (tenant_id, order_id)
);

/* Q24. Tier customers by expected data volume: "small" tenants can share a single multi-tenant table with a tenant_id column (cheap, simple); "medium" tenants might get their own partition within a partitioned-by-tenant table; "large" (whale) tenants can be promoted to their own dedicated schema or even dedicated shard/database, isolating their load from everyone else. */

/* Q25. A "zero-FK" design drops database-level FOREIGN KEY constraints entirely and enforces referential integrity in application code instead - chosen at scale because cross-shard FKs can't be enforced by Postgres anyway (the referenced row may live on a different shard/database), so the constraint would be a false promise; the tradeoff is losing the database's own integrity guarantee and needing careful app-level checks and periodic orphan-row audits. */

/* ============================================================
   SECTION B: MULTI-LEVEL PARTITIONING (25)
   ------------------------------------------------------------ */

/* Q26. */
CREATE TABLE day_03_practice.pay_slips_p (
    pay_slip_id BIGSERIAL,
    salary_year INT NOT NULL,
    salary_month VARCHAR(10) NOT NULL
) PARTITION BY RANGE (salary_year);

CREATE TABLE day_03_practice.pay_slips_p_2025 PARTITION OF day_03_practice.pay_slips_p
  FOR VALUES FROM (2025) TO (2026) PARTITION BY LIST (salary_month);

CREATE TABLE day_03_practice.pay_slips_p_2025_jan PARTITION OF day_03_practice.pay_slips_p_2025 FOR VALUES IN ('January');

/* Q27. */
CREATE TABLE day_03_practice.orders_multi (
    tenant_id INT NOT NULL,
    order_date DATE NOT NULL
) PARTITION BY LIST (tenant_id);

CREATE TABLE day_03_practice.orders_multi_t1 PARTITION OF day_03_practice.orders_multi
  FOR VALUES IN (1) PARTITION BY RANGE (order_date);

CREATE TABLE day_03_practice.orders_multi_t1_2025 PARTITION OF day_03_practice.orders_multi_t1
  FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

/* Q28. */
CREATE TABLE day_03_practice.page_views_multi (
    view_date DATE NOT NULL,
    customer_id INT NOT NULL
) PARTITION BY RANGE (view_date);

CREATE TABLE day_03_practice.page_views_multi_q1_2025 PARTITION OF day_03_practice.page_views_multi
  FOR VALUES FROM ('2025-01-01') TO ('2025-04-01') PARTITION BY HASH (customer_id);

CREATE TABLE day_03_practice.page_views_multi_q1_2025_h0 PARTITION OF day_03_practice.page_views_multi_q1_2025
  FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE day_03_practice.page_views_multi_q1_2025_h1 PARTITION OF day_03_practice.page_views_multi_q1_2025
  FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE day_03_practice.page_views_multi_q1_2025_h2 PARTITION OF day_03_practice.page_views_multi_q1_2025
  FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE day_03_practice.page_views_multi_q1_2025_h3 PARTITION OF day_03_practice.page_views_multi_q1_2025
  FOR VALUES WITH (MODULUS 4, REMAINDER 3);

/* Q29. */
CREATE TABLE day_03_practice.events_24m (
    event_id BIGSERIAL,
    occurred_at DATE NOT NULL
) PARTITION BY RANGE (occurred_at);

DO $$
DECLARE m DATE;
BEGIN
  FOR m IN SELECT generate_series('2024-01-01'::date, '2025-12-01'::date, interval '1 month') LOOP
    EXECUTE format('CREATE TABLE day_03_practice.events_24m_%s PARTITION OF day_03_practice.events_24m FOR VALUES FROM (%L) TO (%L)',
      to_char(m,'YYYY_MM'), m, m + interval '1 month');
  END LOOP;
END $$;

/* Q30. */
DO $$
DECLARE d DATE;
BEGIN
  FOR d IN SELECT generate_series(date_trunc('quarter', current_date)::date, (date_trunc('quarter', current_date) + interval '3 months' - interval '1 day')::date, interval '1 day') LOOP
    EXECUTE format('CREATE TABLE day_03_practice.events_24m_d_%s PARTITION OF day_03_practice.events_24m FOR VALUES FROM (%L) TO (%L)',
      to_char(d,'YYYY_MM_DD'), d, d + interval '1 day');
  END LOOP;
END $$;

/* Q31. */
DROP TABLE day_03_practice.events_24m_2024_01;

/* Q32. Attaching a foreign table (e.g. an S3-backed parquet_fdw or postgres_fdw table pointing at a cold-storage database) as a partition needs the same column layout as the parent: CREATE FOREIGN TABLE day_03_practice.events_24m_cold_archive (...) SERVER s3_cold_server OPTIONS (...); ALTER TABLE day_03_practice.events_24m ATTACH PARTITION day_03_practice.events_24m_cold_archive FOR VALUES FROM ('2020-01-01') TO ('2021-01-01'); - queries then transparently reach into cold storage only when that date range is touched. */

/* Q33. */
CREATE UNLOGGED TABLE day_03_practice.hot_staging (id BIGINT, payload JSONB);

/* Q34. Converting a flat table to partitioned (PG12+) is not an in-place ALTER: create a new partitioned parent with the same structure, ATTACH the old flat table as its first partition (Postgres validates or trusts its data matches the bound), then create new partitions going forward and rename the old table into the partitioned structure's naming, or CREATE TABLE ... PARTITION OF and migrate data with INSERT ... SELECT for a true rebuild. */

/* Q35. */
EXPLAIN SELECT * FROM day_03_practice.events_24m WHERE occurred_at = '2024-03-15';

/* Q36. PostgreSQL does not allow partitioning by a generated column at all (CREATE ... PARTITION BY RANGE (generated_col) raises "cannot use generated column in partition key"); the supported alternative is expression partitioning - partition directly by the same expression the generated column would have computed, e.g. PARTITION BY RANGE (created_ts::date) using an IMMUTABLE cast/function. */

/* Q37. */
CREATE TABLE day_03_practice.expr_part_demo (
    id BIGSERIAL,
    ts TIMESTAMP NOT NULL
) PARTITION BY RANGE (date_trunc('day', ts));

CREATE TABLE day_03_practice.expr_part_demo_d1 PARTITION OF day_03_practice.expr_part_demo
  FOR VALUES FROM ('2025-01-01') TO ('2025-01-02');

/* Q38. */
CREATE TABLE day_03_practice.tenant_list_demo (
    tenant_id INT NOT NULL,
    val TEXT
) PARTITION BY LIST (tenant_id);

CREATE TABLE day_03_practice.tenant_list_demo_1 PARTITION OF day_03_practice.tenant_list_demo FOR VALUES IN (1);

/* Q39. */
CREATE TABLE day_03_practice.tickets_priority_p (
    ticket_id BIGSERIAL,
    priority VARCHAR(20) NOT NULL
) PARTITION BY LIST (priority);

CREATE TABLE day_03_practice.tickets_priority_p_critical PARTITION OF day_03_practice.tickets_priority_p FOR VALUES IN ('Critical');

/* Q40. */
CREATE TABLE day_03_practice.big_hash_demo (
    id BIGSERIAL,
    val INT
) PARTITION BY HASH (id);

DO $$
BEGIN
  FOR i IN 0..15 LOOP
    EXECUTE format('CREATE TABLE day_03_practice.big_hash_demo_%s PARTITION OF day_03_practice.big_hash_demo FOR VALUES WITH (MODULUS 16, REMAINDER %s)', i, i);
  END LOOP;
END $$;

/* Q41. */
CREATE INDEX idx_big_hash_demo_0_val ON day_03_practice.big_hash_demo_0(val);

/* Q42. */
ALTER TABLE day_03_practice.big_hash_demo ADD CONSTRAINT uq_big_hash_demo UNIQUE (id);

/* Q43. */
ALTER TABLE day_03_practice.events_24m_2025_06 ADD CONSTRAINT chk_2025_06 CHECK (occurred_at >= '2025-06-01' AND occurred_at < '2025-07-01');

/* Q44. */
CREATE TABLE day_03_practice.events_24m_default PARTITION OF day_03_practice.events_24m DEFAULT;
SELECT pg_size_pretty(pg_total_relation_size('day_03_practice.events_24m_default'));

/* Q45. A "rolling window" scheduler (pg_cron or an external job) runs monthly: it creates next month's partition ahead of time (CREATE TABLE ... PARTITION OF ... FOR VALUES FROM/TO the upcoming month) and, separately, detaches + drops the oldest partition once it's past the retention window - keeping exactly N months of live partitions at all times without manual intervention. */

/* Q46. Sub-partitioning page_views by device_type means partitioning each date-range partition again by LIST(device_type): PARTITION BY RANGE (view_date) at the top level, then each monthly partition declared PARTITION BY LIST (device_type) with sub-partitions for 'Mobile', 'Desktop', 'Tablet' - useful only if device-specific queries are extremely common, since it multiplies the total partition count considerably. */

/* Q47. A partition-wise JOIN lets the planner join two partitioned tables partition-by-partition (matching partitions joined independently, in parallel) instead of joining the whole logical tables at once - it requires enable_partitionwise_join = on and both tables to share compatible partition bounds on the join key; EXPLAIN will show separate Append/Join nodes per partition pair instead of one giant join. */

/* Q48. Partition-wise aggregation (enable_partitionwise_aggregate = on) lets Postgres compute a GROUP BY separately within each partition and then combine the partial results, reducing memory pressure and enabling parallelism; verify it worked by checking EXPLAIN for per-partition Partial Aggregate nodes feeding into a Finalize Aggregate, rather than one aggregate scanning the whole Append output. */

/* Q49. Partition inheritance (the pre-PG10 manual CHECK-constraint-and-trigger style) is now rare because declarative PARTITION BY does everything it did with far less boilerplate and native pruning; it still shows up maintaining very old tables that predate PG10 and haven't been migrated to declarative partitioning yet. */

/* Q50. Detach the partition (ALTER TABLE parent DETACH PARTITION day_03_practice.events_24m_2024_02;), which turns it into a fully standalone ordinary table instantly (metadata-only), then run a normal pg_dump -t day_03_practice.events_24m_2024_02 against it - dumping a live, still-attached partition works too, but detaching first guarantees the data is frozen and isolated from ongoing writes to the parent during the dump. */

/* ============================================================
   SECTION C: TYPE MODELING AT SCALE (25)
   ------------------------------------------------------------ */
CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS hstore;

/* Q51. */
CREATE DOMAIN day_03_practice.nonneg_numeric AS numeric CHECK (VALUE >= 0);

/* Q52. */
CREATE DOMAIN day_03_practice.email_addr AS text CHECK (VALUE ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

/* Q53. */
CREATE DOMAIN day_03_practice.phone_e164 AS text CHECK (VALUE ~ '^\+[1-9][0-9]{7,14}$');

/* Q54. */
CREATE DOMAIN day_03_practice.currency_code AS char(3) CHECK (VALUE ~ '^[A-Z]{3}$');

/* Q55. */
CREATE TYPE day_03_practice.address_t AS (street text, city text, zip text, country text);

/* Q56. */
CREATE TYPE day_03_practice.money_t AS (amount numeric(14,2), currency day_03_practice.currency_code);

/* Q57. */
CREATE TYPE day_03_practice.tier_t AS ENUM ('Bronze','Silver','Gold','Platinum');
/* Adding a new tier later means ALTER TYPE day_03_practice.tier_t ADD VALUE 'Diamond'; which is cheap on its own, but that new value can't be used within the same transaction that adds it, and ENUM values can never be removed or renamed - only appended (optionally with BEFORE/AFTER) - so a genuinely wrong value stays in the type forever unless you rebuild the whole type. */

/* Q58. */
CREATE TYPE day_03_practice.priority_t AS ENUM ('Low','Medium','High','Critical');

/* Q59. */
SELECT '[10,100)'::int4range AS stock_level;

/* Q60. */
CREATE TABLE day_03_practice.validity_demo (id SERIAL PRIMARY KEY, valid_period DATERANGE);

/* Q61. */
CREATE TABLE day_03_practice.shaped_jsonb (id SERIAL PRIMARY KEY, data JSONB CHECK (data ? 'type'));

/* Q62. */
CREATE TABLE day_03_practice.array_tags_demo (id SERIAL PRIMARY KEY, tags TEXT[]);

/* Q63. */
INSERT INTO day_03_practice.array_tags_demo (tags) VALUES (ARRAY['a','b','c']);
SELECT id, unnest(tags) AS tag FROM day_03_practice.array_tags_demo;

/* Q64. */
CREATE TABLE day_03_practice.hstore_demo (id SERIAL PRIMARY KEY, attrs HSTORE);
/* HSTORE is a flat key->text-value map with a lighter storage footprint and simpler operators than JSONB, useful for simple sparse attribute bags; JSONB is the better default whenever values need to be nested, typed (numbers/booleans/arrays), or validated by shape - most new designs pick JSONB and reserve HSTORE for legacy code or genuinely flat key/value needs. */

/* Q65. */
CREATE TABLE day_03_practice.uuidv4_demo (id UUID PRIMARY KEY DEFAULT gen_random_uuid());
/* UUID v4 is fully random, so its index insert pattern is scattered across the whole B-tree (worse cache locality/page splits at high volume); UUID v7 embeds a leading timestamp so values are naturally time-ordered like a SERIAL, giving mostly-sequential inserts while remaining globally unique - PostgreSQL added a native uuidv7() generator in PG18; on PG16 you'd use a small function or extension to build one. */

/* Q66. */
CREATE TABLE day_03_practice.gen_fullname_demo (id SERIAL PRIMARY KEY, first_name TEXT, last_name TEXT, full_name TEXT GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED);

/* Q67. */
CREATE TABLE day_03_practice.gen_lower_demo (id SERIAL PRIMARY KEY, email TEXT, email_lower TEXT GENERATED ALWAYS AS (lower(email)) STORED);

/* Q68. */
CREATE INDEX idx_gen_lower_demo_email ON day_03_practice.gen_lower_demo(email_lower);

/* Q69. */
CREATE TABLE day_03_practice.citext_email_demo (id SERIAL PRIMARY KEY, email CITEXT UNIQUE);

/* Q70. */
CREATE TABLE day_03_practice.tsvector_demo (id SERIAL PRIMARY KEY, description TEXT, description_tsv TSVECTOR GENERATED ALWAYS AS (to_tsvector('english', description)) STORED);
CREATE INDEX idx_tsvector_demo ON day_03_practice.tsvector_demo USING GIN (description_tsv);

/* Q71. */
CREATE DOMAIN day_03_practice.percent_t AS numeric(5,2) CHECK (VALUE BETWEEN 0 AND 100);

/* Q72. */
CREATE DOMAIN day_03_practice.slug_t AS text CHECK (VALUE ~ '^[a-z0-9]+(-[a-z0-9]+)*$');

/* Q73. */
CREATE TYPE day_03_practice.coords_t AS (lat numeric(9,6), lng numeric(9,6));

/* Q74. PostGIS adds real geographic/geometric types (geometry, geography) with spatial indexing (GiST) and functions (ST_Distance, ST_Contains, ST_Within); it's the right upgrade over plain numeric lat/lng pairs once you need true spatial queries like "stores within 5km" or polygon-based delivery-zone lookups, rather than simple two-column coordinate storage. */

/* Q75. */
CREATE TABLE day_03_practice.customers_rich (
    cust_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email day_03_practice.email_addr UNIQUE,
    phone day_03_practice.phone_e164,
    tier day_03_practice.tier_t NOT NULL DEFAULT 'Bronze',
    addr day_03_practice.address_t,
    home_coords day_03_practice.coords_t,
    lifetime_spend day_03_practice.nonneg_numeric NOT NULL DEFAULT 0,
    preferred_currency day_03_practice.currency_code NOT NULL DEFAULT 'INR'
);

/* ============================================================
   SECTION D: SCHEMA EVOLUTION (25)
   ------------------------------------------------------------ */
CREATE TABLE day_03_practice.evo_products (
    id SERIAL PRIMARY KEY,
    price_id INT,
    description TEXT,
    full_name TEXT,
    status_code INT
);

/* Q76. Pre-PG11, ADD COLUMN ... DEFAULT const required an immediate full-table rewrite to backfill every row (long ACCESS EXCLUSIVE lock on huge tables); PG11+ instead stores the default as metadata and computes it lazily on read for old rows, so adding a column with a constant DEFAULT is now a fast, near-instant metadata-only change. */
ALTER TABLE day_03_practice.evo_products ADD COLUMN currency VARCHAR(3) DEFAULT 'INR';

/* Q77. */
ALTER TABLE day_03_practice.evo_products DROP COLUMN status_code;
/* DROP COLUMN itself is metadata-only in Postgres (the column is just marked dropped, not physically removed until a future VACUUM/rewrite), so it briefly takes an ACCESS EXCLUSIVE lock but completes almost instantly even on a huge table - the "lock" risk is really about that brief exclusive lock queueing behind other long-running queries, not a rewrite. */

/* Q78. */
ALTER TABLE day_03_practice.evo_products RENAME COLUMN full_name TO display_name;
/* Renaming a column breaks any app code or view referencing the old name by SELECT full_name; keep the app from breaking by first adding a database VIEW or updating the ORM mapping in the same deploy, or by doing the rename only after all reading code has been updated to use the new name. */

/* Q79. */
ALTER TABLE day_03_practice.evo_products ALTER COLUMN price_id TYPE BIGINT;

/* Q80. */
ALTER TABLE day_03_practice.evo_products ALTER COLUMN description TYPE JSONB USING to_jsonb(description);

/* Q81. */
ALTER TABLE day_03_practice.evo_products ADD CONSTRAINT chk_currency_not_null CHECK (currency IS NOT NULL) NOT VALID;
ALTER TABLE day_03_practice.evo_products VALIDATE CONSTRAINT chk_currency_not_null;

/* Q82. */
CREATE TABLE day_03_practice.evo_categories (id SERIAL PRIMARY KEY);
ALTER TABLE day_03_practice.evo_products ADD COLUMN category_id INT;
ALTER TABLE day_03_practice.evo_products ADD CONSTRAINT fk_evo_category FOREIGN KEY (category_id) REFERENCES day_03_practice.evo_categories(id) NOT VALID;
ALTER TABLE day_03_practice.evo_products VALIDATE CONSTRAINT fk_evo_category;

/* Q83. CREATE INDEX CONCURRENTLY idx_evo_products_category ON day_03_practice.evo_products(category_id); (run outside a transaction block) builds the index without an exclusive table lock; once it succeeds, ALTER TABLE day_03_practice.evo_products ADD CONSTRAINT uq_evo_category UNIQUE USING INDEX idx_evo_products_category; attaches that already-built index as the constraint's backing index almost instantly, avoiding the long lock a plain ADD CONSTRAINT UNIQUE would take while building its own index. */

/* Q84. */
ALTER TABLE day_03_practice.evo_products ADD COLUMN first_word TEXT, ADD COLUMN rest_words TEXT;
UPDATE day_03_practice.evo_products
  SET first_word = split_part(display_name, ' ', 1),
      rest_words = substring(display_name FROM position(' ' IN display_name) + 1);

/* Q85. */
ALTER TABLE day_03_practice.evo_products ADD COLUMN full_display TEXT;
UPDATE day_03_practice.evo_products SET full_display = concat_ws(' ', first_word, rest_words);

/* Q86. */
ALTER TABLE day_03_practice.evo_products RENAME TO evo_products_v2;
CREATE VIEW day_03_practice.evo_products AS SELECT * FROM day_03_practice.evo_products_v2;

/* Q87. */
DROP SCHEMA IF EXISTS day_03_archive2 CASCADE;
CREATE SCHEMA day_03_archive2;
ALTER TABLE day_03_practice.evo_categories SET SCHEMA day_03_archive2;

/* Q88. */
ALTER TABLE day_03_practice.evo_products_v2 SET TABLESPACE pg_default;

/* Q89. */
ALTER TABLE day_03_practice.evo_products_v2 SET UNLOGGED;
/* Converting HEAP to UNLOGGED is only "safe" for tables you can afford to lose entirely on a crash (staging/scratch tables) - UNLOGGED tables skip WAL, so they're not crash-safe, aren't replicated to standbys, and are automatically truncated on an unclean restart. */

/* Q90. */
ALTER TABLE day_03_practice.evo_products_v2 ADD COLUMN price_id_doubled BIGINT GENERATED ALWAYS AS (price_id * 2) STORED;
/* Adding a STORED GENERATED column to an existing huge table is NOT a metadata-only change - Postgres must compute and write the expression for every existing row, so it rewrites the whole table under an ACCESS EXCLUSIVE lock, unlike a plain constant-DEFAULT ADD COLUMN. */

/* Q91. Rebuilding a primary key's backing index online usually means CREATE UNIQUE INDEX CONCURRENTLY new_pk_idx ON tbl(pk_col); (outside a transaction), then ALTER TABLE tbl DROP CONSTRAINT old_pk, ADD CONSTRAINT tbl_pkey PRIMARY KEY USING INDEX new_pk_idx; - pg_repack automates a very similar swap (build a clean copy concurrently, then atomically replace) without ever taking a long lock. */

/* Q92. */
CREATE INDEX idx_evo_products_v2_cat_curr ON day_03_practice.evo_products_v2(category_id, currency);

/* Q93. */
CREATE INDEX idx_evo_products_v2_broad ON day_03_practice.evo_products_v2(category_id);
DROP INDEX day_03_practice.idx_evo_products_v2_broad;
CREATE INDEX idx_evo_products_v2_cat_partial ON day_03_practice.evo_products_v2(category_id) WHERE category_id IS NOT NULL;

/* Q94. Migrating a partitioned table to a different partition strategy (e.g. RANGE to HASH) has no in-place ALTER - create a brand-new parent with the desired PARTITION BY, create its partitions, then INSERT INTO new_parent SELECT * FROM old_parent (or migrate incrementally partition-by-partition), verify row counts match, then rename old/new and drop the old structure once confident. */

/* Q95. A "dual-table write" migration has the application write every change to BOTH the old and new schema/table during the transition (often via a trigger keeping them in sync automatically), backfills historical data separately, then cuts reads over to the new table once the two are verified consistent, and only then stops writing to the old one and drops it. */

/* Q96. Idempotent migration files are written so re-running them produces the same end state with no error: CREATE TABLE IF NOT EXISTS, ADD COLUMN IF NOT EXISTS, DROP ... IF EXISTS, and CREATE INDEX CONCURRENTLY IF NOT EXISTS - each file can be safely re-applied (e.g. after a partial failure) without manual cleanup, which is essential for automated migration tooling. */

/* Q97. */
ALTER TABLE day_03_practice.evo_products_v2 ADD CONSTRAINT chk_price_id_pos CHECK (price_id > 0) NOT VALID;
ALTER TABLE day_03_practice.evo_products_v2 VALIDATE CONSTRAINT chk_price_id_pos;

/* Q98. */
ALTER TABLE day_03_practice.evo_products_v2 ADD COLUMN tenant_id INT NOT NULL DEFAULT 1;

/* Q99. A "shadow table + trigger" migration creates a new table with the target structure, adds a trigger on the old table that mirrors every INSERT/UPDATE/DELETE into the shadow table in real time, backfills historical rows in batches, verifies the two are in sync, then does an atomic rename swap - giving zero-downtime because reads/writes never stop hitting a valid table throughout the whole process. */

/* Q100. A representative 10-step zero-downtime migration plan (e.g. splitting a column): (1) add the new column(s) as nullable; (2) deploy app code that writes to both old and new columns; (3) backfill existing rows into the new column(s) in small batches; (4) verify data parity between old and new; (5) deploy app code that reads from the new column(s) but still writes both; (6) monitor for discrepancies over a soak period; (7) add NOT NULL/CHECK constraints on the new column(s) via NOT VALID + VALIDATE; (8) deploy app code that stops writing the old column; (9) drop the old column in a low-traffic window; (10) drop any now-unused indexes/constraints tied to the old column. */

/* ============================================================
   END OF ANSWER KEY - CRAZY LEVEL (100/100)
============================================================ */
