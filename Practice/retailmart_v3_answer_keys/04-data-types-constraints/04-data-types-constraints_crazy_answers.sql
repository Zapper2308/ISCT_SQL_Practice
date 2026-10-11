/* ============================================================
   ANSWER KEY - Constraints & DML (CRAZY LEVEL)
   Curriculum: RetailMart V3
   Topic: 04-data-types-constraints
   Note: Section A/B/C/D build/reuse a day_03_practice scratch
   schema so this file runs standalone. Sections marked conceptual
   involve external systems (Kafka, Debezium, ClickHouse, Snowflake,
   mysql_fdw, pg_bulkload) or genuine multi-session concurrency
   that cannot be demonstrated safely inside a single script.
   ============================================================ */

/* ============================================================
   SECTION A: IDEMPOTENT WRITE PATTERNS (25)
   ------------------------------------------------------------ */
DROP SCHEMA IF EXISTS day_03_practice CASCADE;
CREATE SCHEMA IF NOT EXISTS day_03_practice;

CREATE TABLE IF NOT EXISTS day_03_practice.orders_idem (
    order_id SERIAL PRIMARY KEY,
    idempotency_key VARCHAR(64) UNIQUE,
    cust_id INT,
    total NUMERIC(12,2)
);
CREATE TABLE IF NOT EXISTS day_03_practice.customers_idem (
    cust_id SERIAL PRIMARY KEY,
    email VARCHAR(100) UNIQUE,
    full_name VARCHAR(100),
    tier INT DEFAULT 1,
    fraud_flag BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
INSERT INTO day_03_practice.customers_idem (email, full_name) VALUES ('a@example.com','A One');

CREATE TABLE day_03_practice.processed_tokens (token VARCHAR(64) PRIMARY KEY, processed_at TIMESTAMPTZ DEFAULT NOW());

CREATE TABLE day_03_practice.event_seq_counter (
    counter_name VARCHAR(50) PRIMARY KEY,
    value BIGINT NOT NULL DEFAULT 0,
    last_applied_seq BIGINT NOT NULL DEFAULT 0
);
INSERT INTO day_03_practice.event_seq_counter VALUES ('total_orders', 0, 0);

CREATE TABLE day_03_practice.orders_wf (order_id SERIAL PRIMARY KEY, status VARCHAR(20));
INSERT INTO day_03_practice.orders_wf (status) VALUES ('processing');

CREATE TABLE day_03_practice.loyalty_ledger (
    ledger_id SERIAL PRIMARY KEY,
    event_id VARCHAR(64) UNIQUE,
    cust_id INT,
    points INT
);
CREATE TABLE day_03_practice.payments_demo (
    payment_id SERIAL PRIMARY KEY,
    payment_intent_id VARCHAR(64) UNIQUE,
    amount NUMERIC(12,2)
);
CREATE TABLE day_03_practice.inventory_idem (product_id INT PRIMARY KEY, qty INT);
INSERT INTO day_03_practice.inventory_idem VALUES (1, 100);
CREATE TABLE day_03_practice.inventory_deductions (
    deduction_id SERIAL PRIMARY KEY,
    event_id VARCHAR(64) UNIQUE,
    product_id INT,
    qty INT
);
CREATE TABLE day_03_practice.email_log (
    id SERIAL PRIMARY KEY,
    template VARCHAR(50),
    sent_for_id INT,
    sent_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (template, sent_for_id)
);
CREATE TABLE day_03_practice.webhook_events (
    id SERIAL PRIMARY KEY,
    external_id VARCHAR(64) UNIQUE,
    received_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE day_03_practice.shipments_demo (
    shipment_id SERIAL PRIMARY KEY,
    status VARCHAR(20),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
INSERT INTO day_03_practice.shipments_demo (status) VALUES ('in_transit');
CREATE TABLE day_03_practice.attributions (
    customer_id INT,
    campaign_id INT,
    attributed_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (customer_id, campaign_id)
);
CREATE TABLE day_03_practice.refunds_demo (
    refund_id SERIAL PRIMARY KEY,
    refund_request_id VARCHAR(64) UNIQUE,
    order_id INT,
    amount NUMERIC(12,2)
);
CREATE TABLE day_03_practice.reviews_demo (
    review_id SERIAL PRIMARY KEY,
    customer_id INT,
    product_id INT,
    review_text TEXT,
    UNIQUE (customer_id, product_id)
);
CREATE TABLE day_03_practice.tickets_idem (
    ticket_id SERIAL PRIMARY KEY,
    external_ticket_ref VARCHAR(64) UNIQUE,
    subject VARCHAR(200)
);
CREATE TABLE day_03_practice.ad_spend_idem (
    id SERIAL PRIMARY KEY,
    campaign_id INT,
    spend_date DATE,
    batch_id VARCHAR(64),
    amount NUMERIC(12,2),
    UNIQUE (campaign_id, spend_date, batch_id)
);
CREATE TABLE day_03_practice.push_log (
    id SERIAL PRIMARY KEY,
    device_token VARCHAR(64),
    notification_id VARCHAR(64),
    UNIQUE (device_token, notification_id)
);
CREATE TABLE day_03_practice.idempotency_keys (
    idem_key TEXT PRIMARY KEY,
    response JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

/* Q1. */
INSERT INTO day_03_practice.orders_idem (idempotency_key, cust_id, total)
VALUES ('req-abc-123', 1, 250.00)
ON CONFLICT (idempotency_key) DO NOTHING;

/* Q2. */
INSERT INTO day_03_practice.customers_idem (email, full_name) VALUES ('a@example.com', 'A One')
ON CONFLICT (email) DO UPDATE SET full_name = EXCLUDED.full_name;

/* Q3. */
DELETE FROM day_03_practice.customers_idem WHERE cust_id = 9999;

/* Q4. ON CONFLICT DO NOTHING is idempotent whenever the caller doesn't need updated data reflected on a retry (e.g. a pure "record this event once" insert) - repeated identical requests simply become no-ops after the first. ON CONFLICT DO UPDATE is idempotent whenever you SET columns to the exact values the retry would produce again (e.g. SET total = EXCLUDED.total) - applying the same update twice yields the same final state either way; it becomes non-idempotent only if the SET clause has a side effect that accumulates (like blindly adding to a running total) without also checking that this specific event hasn't already been applied. */

/* Q5. */
WITH inserted AS (
  INSERT INTO day_03_practice.orders_idem (idempotency_key, cust_id, total)
  VALUES ('req-xyz-456', 1, 99.00)
  ON CONFLICT (idempotency_key) DO NOTHING
  RETURNING order_id
)
INSERT INTO day_03_practice.email_log (template, sent_for_id)
SELECT 'order_confirmation', order_id FROM inserted
ON CONFLICT (template, sent_for_id) DO NOTHING;

/* Q6. */
INSERT INTO day_03_practice.processed_tokens (token) VALUES ('evt-001')
ON CONFLICT (token) DO NOTHING
RETURNING token;

/* Q7. */
UPDATE day_03_practice.event_seq_counter
SET value = value + 5, last_applied_seq = 10
WHERE counter_name = 'total_orders' AND last_applied_seq < 10;

/* Q8. */
UPDATE day_03_practice.orders_wf SET status = 'shipped' WHERE order_id = 1 AND status = 'processing';

/* Q9. */
INSERT INTO day_03_practice.loyalty_ledger (event_id, cust_id, points) VALUES ('evt-loy-001', 1, 50)
ON CONFLICT (event_id) DO NOTHING;

/* Q10. */
INSERT INTO day_03_practice.payments_demo (payment_intent_id, amount) VALUES ('pi_001', 100.00)
ON CONFLICT (payment_intent_id) DO NOTHING;

/* Q11. */
WITH deduction AS (
  INSERT INTO day_03_practice.inventory_deductions (event_id, product_id, qty)
  VALUES ('evt-ded-001', 1, 3)
  ON CONFLICT (event_id) DO NOTHING
  RETURNING product_id, qty
)
UPDATE day_03_practice.inventory_idem i
SET qty = i.qty - d.qty
FROM deduction d
WHERE i.product_id = d.product_id;

/* Q12. */
INSERT INTO day_03_practice.email_log (template, sent_for_id) VALUES ('welcome', 1)
ON CONFLICT (template, sent_for_id) DO NOTHING
RETURNING id;

/* Q13. */
INSERT INTO day_03_practice.webhook_events (external_id) VALUES ('wh-001')
ON CONFLICT (external_id) DO NOTHING
RETURNING external_id;

/* Q14. */
UPDATE day_03_practice.shipments_demo SET status = 'delivered', updated_at = NOW()
WHERE shipment_id = 1 AND status <> 'delivered';

/* Q15. */
INSERT INTO day_03_practice.attributions (customer_id, campaign_id) VALUES (1, 5)
ON CONFLICT (customer_id, campaign_id) DO NOTHING;

/* Q16. */
INSERT INTO day_03_practice.customers_idem (email, full_name) VALUES ('a@example.com', 'A One')
ON CONFLICT (email) DO UPDATE SET updated_at = NOW()
RETURNING cust_id;

/* Q17. */
INSERT INTO day_03_practice.orders_idem (idempotency_key, cust_id, total) VALUES ('req-abc-123', 1, 250.00)
ON CONFLICT (idempotency_key) DO UPDATE SET idempotency_key = EXCLUDED.idempotency_key
RETURNING order_id;

/* Q18. */
INSERT INTO day_03_practice.refunds_demo (refund_request_id, order_id, amount) VALUES ('rf-001', 1, 50.00)
ON CONFLICT (refund_request_id) DO NOTHING;

/* Q19. */
INSERT INTO day_03_practice.reviews_demo (customer_id, product_id, review_text) VALUES (1, 1, 'Great product')
ON CONFLICT (customer_id, product_id) DO UPDATE SET review_text = EXCLUDED.review_text;

/* Q20. */
INSERT INTO day_03_practice.tickets_idem (external_ticket_ref, subject) VALUES ('tk-ext-001', 'Login issue')
ON CONFLICT (external_ticket_ref) DO NOTHING
RETURNING ticket_id;

/* Q21. */
UPDATE day_03_practice.customers_idem SET tier = GREATEST(tier, 3) WHERE cust_id = 1;

/* Q22. */
INSERT INTO day_03_practice.ad_spend_idem (campaign_id, spend_date, batch_id, amount) VALUES (1, CURRENT_DATE, 'batch-001', 500)
ON CONFLICT (campaign_id, spend_date, batch_id) DO NOTHING;

/* Q23. */
INSERT INTO day_03_practice.push_log (device_token, notification_id) VALUES ('dev-token-1', 'notif-001')
ON CONFLICT (device_token, notification_id) DO NOTHING;

/* Q24. */
UPDATE day_03_practice.customers_idem SET fraud_flag = TRUE WHERE cust_id = 1 AND fraud_flag IS DISTINCT FROM TRUE;

/* Q25. */
CREATE OR REPLACE FUNCTION day_03_practice.check_idempotency(p_key TEXT, p_response JSONB)
RETURNS JSONB AS $$
DECLARE
  existing JSONB;
BEGIN
  SELECT response INTO existing FROM day_03_practice.idempotency_keys WHERE idem_key = p_key;
  IF FOUND THEN
    RETURN existing;
  END IF;
  INSERT INTO day_03_practice.idempotency_keys (idem_key, response) VALUES (p_key, p_response);
  RETURN p_response;
END;
$$ LANGUAGE plpgsql;
SELECT day_03_practice.check_idempotency('req-999', '{"status":"ok"}'::jsonb);
SELECT day_03_practice.check_idempotency('req-999', '{"status":"ok"}'::jsonb);

/* ============================================================
   SECTION B: CDC, AUDIT, EVENT SOURCING (25)
   ------------------------------------------------------------ */
CREATE TABLE day_03_practice.orders_cdc (order_id SERIAL PRIMARY KEY, cust_id INT, total NUMERIC(12,2), status VARCHAR(20));
CREATE TABLE day_03_practice.orders_insert_audit (id SERIAL PRIMARY KEY, order_id INT, inserted_row JSONB, logged_at TIMESTAMPTZ DEFAULT NOW());

CREATE TABLE day_03_practice.customers_cdc (cust_id SERIAL PRIMARY KEY, email VARCHAR(100), tier INT);
INSERT INTO day_03_practice.customers_cdc (email, tier) VALUES ('a@example.com', 1);
CREATE TABLE day_03_practice.customers_update_audit (id SERIAL PRIMARY KEY, cust_id INT, old_row JSONB, new_row JSONB, changed_at TIMESTAMPTZ DEFAULT NOW());

CREATE TABLE day_03_practice.deletable_rows (id SERIAL PRIMARY KEY, val TEXT);
INSERT INTO day_03_practice.deletable_rows (val) VALUES ('x'),('y');
CREATE TABLE day_03_practice.deletable_rows_audit (id SERIAL PRIMARY KEY, deleted_row JSONB, deleted_at TIMESTAMPTZ DEFAULT NOW());

CREATE TABLE day_03_practice.order_events (
    event_id BIGSERIAL PRIMARY KEY,
    order_id INT,
    event_type VARCHAR(30),
    payload JSONB,
    occurred_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE day_03_practice.change_capture (
    id SERIAL PRIMARY KEY,
    row_id INT,
    diff JSONB,
    captured_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE day_03_practice.watched_tbl (id SERIAL PRIMARY KEY, name TEXT, price NUMERIC(12,2));
INSERT INTO day_03_practice.watched_tbl (name, price) VALUES ('Widget', 100);

CREATE TABLE day_03_practice.bulk_audit_insert (id SERIAL PRIMARY KEY, action TEXT, row_count INT, logged_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE day_03_practice.bulk_src (id SERIAL PRIMARY KEY, val TEXT);

CREATE TABLE day_03_practice.snapshot_before_update (id SERIAL PRIMARY KEY, target_id INT, snapshot JSONB, snapshot_at TIMESTAMPTZ DEFAULT NOW());

CREATE TABLE day_03_practice.record_history (
    history_id SERIAL PRIMARY KEY,
    entity_id INT,
    version INT,
    data JSONB,
    valid_from TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE day_03_practice.entities_versioned (entity_id SERIAL PRIMARY KEY, data JSONB, version INT DEFAULT 1);
INSERT INTO day_03_practice.entities_versioned (data) VALUES ('{"name":"v1"}'::jsonb);

CREATE TABLE day_03_practice.customers_soft_cdc (cust_id SERIAL PRIMARY KEY, email VARCHAR(100), deleted_at TIMESTAMPTZ);
INSERT INTO day_03_practice.customers_soft_cdc (email) VALUES ('softdel@example.com');
CREATE TABLE day_03_practice.customers_soft_audit (id SERIAL PRIMARY KEY, cust_id INT, action TEXT, logged_at TIMESTAMPTZ DEFAULT NOW());

CREATE TABLE day_03_practice.orders_outbox (order_id SERIAL PRIMARY KEY, cust_id INT, total NUMERIC(12,2));
CREATE TABLE day_03_practice.outbox (
    outbox_id BIGSERIAL PRIMARY KEY,
    aggregate_type VARCHAR(30),
    aggregate_id INT,
    event_type VARCHAR(30),
    payload JSONB,
    published BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE day_03_practice.state_changes_stream (id BIGSERIAL PRIMARY KEY, entity TEXT, change JSONB, changed_at TIMESTAMPTZ DEFAULT NOW());

CREATE TABLE day_03_practice.event_store (
    seq BIGSERIAL PRIMARY KEY,
    entity_id INT,
    event_type TEXT,
    payload JSONB,
    occurred_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE day_03_practice.event_snapshots (entity_id INT, up_to_seq BIGINT, state JSONB, snapshotted_at TIMESTAMPTZ DEFAULT NOW());
INSERT INTO day_03_practice.event_store (entity_id, event_type, payload)
SELECT 1, 'tick', ('{"n":' || n || '}')::jsonb FROM generate_series(1, 12) n;

CREATE TABLE day_03_practice.seq_events (seq_no BIGINT PRIMARY KEY, payload TEXT);
INSERT INTO day_03_practice.seq_events VALUES (1,'a'),(2,'b'),(4,'d'),(5,'e');

CREATE TABLE day_03_practice.replay_log (id SERIAL PRIMARY KEY, action TEXT, captured_at TIMESTAMPTZ DEFAULT NOW());

CREATE TABLE day_03_practice.table_stats_history (captured_at TIMESTAMPTZ DEFAULT NOW(), tbl TEXT, row_count BIGINT);

/* Q26. */
CREATE OR REPLACE FUNCTION day_03_practice.audit_orders_insert() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO day_03_practice.orders_insert_audit (order_id, inserted_row) VALUES (NEW.order_id, to_jsonb(NEW));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_audit_orders_insert AFTER INSERT ON day_03_practice.orders_cdc
FOR EACH ROW EXECUTE FUNCTION day_03_practice.audit_orders_insert();
INSERT INTO day_03_practice.orders_cdc (cust_id, total, status) VALUES (1, 250, 'new');

/* Q27. */
CREATE OR REPLACE FUNCTION day_03_practice.audit_customers_update() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO day_03_practice.customers_update_audit (cust_id, old_row, new_row) VALUES (NEW.cust_id, to_jsonb(OLD), to_jsonb(NEW));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_audit_customers_update AFTER UPDATE ON day_03_practice.customers_cdc
FOR EACH ROW EXECUTE FUNCTION day_03_practice.audit_customers_update();
UPDATE day_03_practice.customers_cdc SET tier = 2 WHERE cust_id = 1;

/* Q28. */
CREATE OR REPLACE FUNCTION day_03_practice.audit_delete_full_row() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO day_03_practice.deletable_rows_audit (deleted_row) VALUES (to_jsonb(OLD));
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_audit_delete AFTER DELETE ON day_03_practice.deletable_rows
FOR EACH ROW EXECUTE FUNCTION day_03_practice.audit_delete_full_row();
DELETE FROM day_03_practice.deletable_rows WHERE val = 'x';

/* Q29. */
INSERT INTO day_03_practice.order_events (order_id, event_type, payload) VALUES
(1, 'OrderPlaced', '{"total":250}'::jsonb),
(1, 'OrderPaid', '{"amount":250}'::jsonb),
(1, 'OrderShipped', '{"carrier":"UPS"}'::jsonb);

/* Q30. */
SELECT order_id,
  (SELECT payload->>'carrier' FROM day_03_practice.order_events e2 WHERE e2.order_id = e1.order_id AND event_type = 'OrderShipped') AS carrier,
  bool_or(event_type = 'OrderPaid') AS is_paid,
  max(occurred_at) AS last_event_at
FROM day_03_practice.order_events e1
WHERE order_id = 1
GROUP BY order_id;

/* Q31. */
CREATE OR REPLACE FUNCTION day_03_practice.capture_diff() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO day_03_practice.change_capture (row_id, diff)
  SELECT NEW.id, jsonb_object_agg(key, value)
  FROM jsonb_each(to_jsonb(NEW))
  WHERE to_jsonb(NEW) -> key <> to_jsonb(OLD) -> key;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_capture_diff AFTER UPDATE ON day_03_practice.watched_tbl
FOR EACH ROW EXECUTE FUNCTION day_03_practice.capture_diff();
UPDATE day_03_practice.watched_tbl SET price = 120 WHERE id = 1;

/* Q32. CDC via a logical replication slot reads the WAL's decoded change stream directly: CREATE_REPLICATION_SLOT slot_name LOGICAL wal2json (or pgoutput/test_decoding), then a consumer repeatedly calls SELECT * FROM pg_logical_slot_get_changes('slot_name', NULL, NULL) (or peek variant) to pull each committed INSERT/UPDATE/DELETE as it happens, without polling tables or adding triggers. This is not run against the shared class database here because a replication slot persists server-wide and retains WAL until consumed, which would affect every other session on this instance. */

/* Q33. Debezium is a Kafka Connect source connector that reads a database's write-ahead log (via a logical replication slot, for Postgres) and publishes every row-level change as a structured JSON/Avro event onto a Kafka topic (one topic per table). Downstream consumers subscribe to those topics to get a real-time, ordered change feed without querying the source database at all - the overview pattern is: Postgres WAL -> logical replication slot -> Debezium connector -> Kafka topic -> consumer application/materialized view. */

/* Q34. */
CREATE OR REPLACE FUNCTION day_03_practice.bulk_audit() RETURNS TRIGGER AS $$
DECLARE cnt INT;
BEGIN
  SELECT count(*) INTO cnt FROM new_rows;
  INSERT INTO day_03_practice.bulk_audit_insert (action, row_count) VALUES ('BULK_INSERT', cnt);
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_bulk_audit AFTER INSERT ON day_03_practice.bulk_src
REFERENCING NEW TABLE AS new_rows
FOR EACH STATEMENT EXECUTE FUNCTION day_03_practice.bulk_audit();
INSERT INTO day_03_practice.bulk_src (val) SELECT 'r' || n FROM generate_series(1,50) n;

/* Q35. Trigger overhead scales with how many times the trigger function actually runs, so the way to avoid "one audit row per changed row" is the same REFERENCING ... AS transition-table technique used above (Q34), but on a STATEMENT-level trigger: it fires exactly once per INSERT/UPDATE/DELETE statement regardless of whether that statement touched 1 row or 100,000, and the transition table lets the function summarize (or bulk-copy) all of them in that single invocation - so "N" here means "however many rows the whole statement affected," not a configurable batch size. */

/* Q36. */
CREATE OR REPLACE FUNCTION day_03_practice.snapshot_before() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO day_03_practice.snapshot_before_update (target_id, snapshot) VALUES (OLD.id, to_jsonb(OLD));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_snapshot_before BEFORE UPDATE ON day_03_practice.watched_tbl
FOR EACH ROW EXECUTE FUNCTION day_03_practice.snapshot_before();
UPDATE day_03_practice.watched_tbl SET price = 130 WHERE id = 1;

/* Q37. */
CREATE OR REPLACE FUNCTION day_03_practice.version_row() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO day_03_practice.record_history (entity_id, version, data) VALUES (NEW.entity_id, NEW.version, NEW.data);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_version_row AFTER UPDATE ON day_03_practice.entities_versioned
FOR EACH ROW EXECUTE FUNCTION day_03_practice.version_row();
UPDATE day_03_practice.entities_versioned SET data = '{"name":"v2"}'::jsonb, version = version + 1 WHERE entity_id = 1;

/* Q38. */
WITH soft_deleted AS (
  UPDATE day_03_practice.customers_soft_cdc SET deleted_at = NOW() WHERE cust_id = 1 RETURNING cust_id
)
INSERT INTO day_03_practice.customers_soft_audit (cust_id, action)
SELECT cust_id, 'SOFT_DELETE' FROM soft_deleted;

/* Q39. */
WITH new_order AS (
  INSERT INTO day_03_practice.orders_outbox (cust_id, total) VALUES (1, 300) RETURNING order_id, cust_id, total
)
INSERT INTO day_03_practice.outbox (aggregate_type, aggregate_id, event_type, payload)
SELECT 'order', order_id, 'OrderPlaced', jsonb_build_object('cust_id', cust_id, 'total', total) FROM new_order;

/* Q40. Instead of an application publishing events directly to a message broker (which can fail independently of the database write, losing events), you attach a logical replication slot/publication to the database and let a connector (e.g. Debezium, or a custom consumer calling pg_logical_slot_get_changes) stream every committed row change out to consumers. Because it reads from the WAL after commit, a consumer built this way sees exactly what was durably written - no separate "dual write" step to a queue that could get out of sync with the database. */

/* Q41. */
INSERT INTO day_03_practice.state_changes_stream (entity, change)
VALUES ('order:1', jsonb_build_object('status', 'shipped', 'at', now()));

/* Q42. */
WITH new_evt AS (
  INSERT INTO day_03_practice.event_store (entity_id, event_type, payload) VALUES (1, 'tick', '{"n":13}'::jsonb)
  RETURNING seq, entity_id
)
INSERT INTO day_03_practice.event_snapshots (entity_id, up_to_seq, state)
SELECT entity_id, seq, jsonb_build_object('event_count', seq)
FROM new_evt WHERE seq % 5 = 0;

/* Q43. */
SELECT seq_no, seq_no - LAG(seq_no) OVER (ORDER BY seq_no) AS gap
FROM day_03_practice.seq_events
ORDER BY seq_no;

/* Q44. */
INSERT INTO day_03_practice.replay_log (action)
SELECT event_type || ':' || payload::text FROM day_03_practice.order_events ORDER BY event_id;

/* Q45. */
SELECT seq, entity_id,
  (seq > LAG(seq) OVER (PARTITION BY entity_id ORDER BY seq)) AS is_monotonic
FROM day_03_practice.event_store
ORDER BY seq;

/* Q46. Logical (event) time is a sequence number or vector clock assigned by the system that records "what happened before what" in causal order, independent of any clock; wall-clock time (occurred_at TIMESTAMPTZ) records when an event was physically observed/recorded. Clocks on different machines can drift or go backwards, so two events can have out-of-order wall-clock timestamps even though one truly caused the other - logical ordering (a monotonically increasing sequence column, as used in Q43/Q45) is what you rely on for correctness (gap/order detection), while wall-clock time is kept alongside purely for human-readable auditing/reporting. */

/* Q47. */
UPDATE day_03_practice.outbox SET published = TRUE
WHERE outbox_id IN (
  SELECT outbox_id FROM day_03_practice.outbox WHERE published = FALSE FOR UPDATE SKIP LOCKED LIMIT 10
)
RETURNING outbox_id;

/* Q48. */
INSERT INTO day_03_practice.replay_log (action)
SELECT 'processed:' || event_id FROM day_03_practice.order_events WHERE event_id = 1
ON CONFLICT DO NOTHING;

/* Q49. */
CREATE TABLE day_03_practice.schema_snapshot_now AS
SELECT table_name, column_name, data_type FROM information_schema.columns
WHERE table_schema = 'day_03_practice' AND table_name = 'watched_tbl';
ALTER TABLE day_03_practice.watched_tbl ADD COLUMN new_col TEXT;
SELECT table_name, column_name, data_type FROM information_schema.columns
WHERE table_schema = 'day_03_practice' AND table_name = 'watched_tbl'
EXCEPT
SELECT table_name, column_name, data_type FROM day_03_practice.schema_snapshot_now;

/* Q50. */
INSERT INTO day_03_practice.table_stats_history (tbl, row_count)
SELECT 'day_03_practice.watched_tbl', count(*) FROM day_03_practice.watched_tbl;

/* ============================================================
   SECTION C: CONCURRENT WRITES (25)
   ------------------------------------------------------------ */
CREATE TABLE day_03_practice.shared_row (id INT PRIMARY KEY, val TEXT, version INT DEFAULT 1);
INSERT INTO day_03_practice.shared_row VALUES (1, 'initial', 1);

CREATE TABLE day_03_practice.jobs_cc (job_id SERIAL PRIMARY KEY, status VARCHAR(20) DEFAULT 'pending', payload TEXT);
INSERT INTO day_03_practice.jobs_cc (payload) SELECT 'job' || n FROM generate_series(1,20) n;

CREATE TABLE day_03_practice.accounts (account_id INT PRIMARY KEY, balance NUMERIC(12,2));
INSERT INTO day_03_practice.accounts VALUES (1, 1000), (2, 500);

CREATE TABLE day_03_practice.orders_checkout (order_id SERIAL PRIMARY KEY, cust_id INT, total NUMERIC(12,2), idempotency_key VARCHAR(64) UNIQUE);
CREATE TABLE day_03_practice.inventory_checkout (product_id INT PRIMARY KEY, qty INT);
INSERT INTO day_03_practice.inventory_checkout VALUES (1, 50);
CREATE TABLE day_03_practice.loyalty_checkout (customer_id INT PRIMARY KEY, points INT DEFAULT 0);
INSERT INTO day_03_practice.loyalty_checkout VALUES (1, 100);

CREATE TABLE day_03_practice.leases (job_id INT PRIMARY KEY, leased_by TEXT, leased_until TIMESTAMPTZ);
INSERT INTO day_03_practice.leases VALUES (1, NULL, NULL);

CREATE TABLE day_03_practice.counter_shards (shard INT PRIMARY KEY, value BIGINT DEFAULT 0);
INSERT INTO day_03_practice.counter_shards SELECT n, 0 FROM generate_series(0,9) n;

CREATE TABLE day_03_practice.inventory_sharded (product_id INT, shard INT, qty INT, PRIMARY KEY (product_id, shard));
INSERT INTO day_03_practice.inventory_sharded SELECT 1, n, 10 FROM generate_series(0,9) n;

CREATE TABLE day_03_practice.outbox_cc (outbox_id SERIAL PRIMARY KEY, published BOOLEAN DEFAULT FALSE);
INSERT INTO day_03_practice.outbox_cc (published) SELECT FALSE FROM generate_series(1,20);

CREATE TABLE day_03_practice.demo_ddl_target (id INT);

/* Q51. */
UPDATE day_03_practice.shared_row SET val = 'writer_A' WHERE id = 1;
UPDATE day_03_practice.shared_row SET val = 'writer_B' WHERE id = 1;

/* Q52. */
BEGIN;
SELECT * FROM day_03_practice.shared_row WHERE id = 1 FOR UPDATE;
UPDATE day_03_practice.shared_row SET val = 'serialized_write' WHERE id = 1;
COMMIT;

/* Q53. Under SERIALIZABLE isolation, if two concurrent transactions both read the same data and then write in a way that couldn't have happened in any serial (one-at-a-time) execution order, PostgreSQL's predicate-lock-based conflict detector aborts one of them at COMMIT time with ERROR: could not serialize access due to concurrent update (SQLSTATE 40001) - the surviving transaction commits as if it had run alone, and the aborted one must be retried by the application. This genuinely requires two overlapping sessions to trigger and can't be shown inside one sequential script. */

/* Q54. Two transactions deadlock when Tx1 locks row A then waits to lock row B, while Tx2 has already locked row B and is waiting to lock row A - each holds what the other needs, so both block forever. PostgreSQL's deadlock detector (running every deadlock_timeout, default 1s) finds the wait cycle and aborts one transaction with ERROR: deadlock detected, letting the other proceed; demonstrating it live requires two real concurrent sessions issuing their UPDATEs in that interleaved order, which a single sequential script cannot reproduce. */

/* Q55. */
UPDATE day_03_practice.shared_row SET val = 'ordered_write'
WHERE id IN (SELECT id FROM day_03_practice.shared_row ORDER BY id);

/* Q56. */
UPDATE day_03_practice.shared_row SET val = 'optimistic_v2', version = version + 1
WHERE id = 1 AND version = 1
RETURNING *;

/* Q57. */
SELECT * FROM day_03_practice.shared_row WHERE id = 1 FOR UPDATE;

/* Q58. */
UPDATE day_03_practice.jobs_cc SET status = 'processing' WHERE job_id = 1 AND status = 'pending' RETURNING job_id;

/* Q59. */
UPDATE day_03_practice.counter_shards SET value = value + 1 WHERE shard = 3;

/* Q60. */
BEGIN;
UPDATE day_03_practice.accounts SET balance = balance - 100 WHERE account_id = 1;
UPDATE day_03_practice.accounts SET balance = balance + 100 WHERE account_id = 2;
COMMIT;

/* Q61. */
WITH new_order AS (
  INSERT INTO day_03_practice.orders_checkout (cust_id, total, idempotency_key) VALUES (1, 200, 'chk-001') RETURNING order_id
),
inv_upd AS (
  UPDATE day_03_practice.inventory_checkout SET qty = qty - 1 WHERE product_id = 1 RETURNING product_id
)
UPDATE day_03_practice.loyalty_checkout SET points = points + 20 WHERE customer_id = 1
RETURNING customer_id, points;

/* Q62. */
UPDATE day_03_practice.jobs_cc SET status = 'claimed'
WHERE job_id IN (
  SELECT job_id FROM day_03_practice.jobs_cc WHERE status = 'pending' FOR UPDATE SKIP LOCKED LIMIT 1
)
RETURNING job_id;

/* Q63. */
UPDATE day_03_practice.leases SET leased_by = 'worker-1', leased_until = NOW() + INTERVAL '30 seconds'
WHERE job_id = 1 AND (leased_until IS NULL OR leased_until < NOW())
RETURNING job_id;

/* Q64. */
SELECT pg_try_advisory_lock(918273);
SELECT pg_advisory_unlock(918273);

/* Q65. */
UPDATE day_03_practice.counter_shards SET value = value + 1 WHERE shard = (abs(('x' || md5(random()::text))::bit(32)::int) % 10);
SELECT sum(value) AS distributed_total FROM day_03_practice.counter_shards;

/* Q66. */
INSERT INTO day_03_practice.orders_checkout (cust_id, total, idempotency_key) VALUES (1, 200, 'chk-002')
ON CONFLICT (idempotency_key) DO NOTHING
RETURNING order_id;
INSERT INTO day_03_practice.orders_checkout (cust_id, total, idempotency_key) VALUES (1, 200, 'chk-002')
ON CONFLICT (idempotency_key) DO NOTHING
RETURNING order_id;

/* Q67. */
UPDATE day_03_practice.inventory_sharded SET qty = qty - 1
WHERE product_id = 1 AND shard = (abs(('x' || md5(random()::text))::bit(32)::int) % 10);

/* Q68. */
UPDATE day_03_practice.outbox_cc SET published = TRUE
WHERE outbox_id IN (
  SELECT outbox_id FROM day_03_practice.outbox_cc WHERE published = FALSE FOR UPDATE SKIP LOCKED LIMIT 5
)
RETURNING outbox_id;

/* Q69. A CDC subscriber that pulls faster than it can process risks unbounded memory growth or overwhelming downstream systems, so it should "pace itself" by processing in small batches (LIMIT N per fetch), committing/acknowledging its position (e.g. advancing a checkpoint or confirming the replication slot's LSN) only after each batch is durably handled, and sleeping/backing off between polls when no new changes are found rather than busy-polling - the same batched-checkpoint pattern as the ETL checkpoint in Section D. */

/* Q70. */
DO $$
DECLARE
  retries INT := 0;
BEGIN
  LOOP
    BEGIN
      UPDATE day_03_practice.shared_row SET val = 'retry_demo' WHERE id = 1;
      EXIT;
    EXCEPTION WHEN serialization_failure OR deadlock_detected THEN
      retries := retries + 1;
      IF retries > 5 THEN
        RAISE;
      END IF;
    END;
  END LOOP;
END $$;

/* Q71. A large ETL backfill against a live primary should never run as one giant transaction/scan: batch it into small chunks (e.g. 10,000 rows per commit, as in the Q81-style DELETE loop), add a short sleep between batches to leave headroom for regular traffic, run it during off-peak hours if possible, and monitor replication lag/lock waits (pg_stat_replication, pg_locks) so the job can pause itself automatically if it's starting to impact other workloads. */

/* Q72. Read-only, non-latency-critical or reporting/analytics queries (dashboards, batch reports, ETL reads) should be routed to a read replica via connection string / load balancer / pgbouncer routing rules, so they never compete for I/O or locks with the primary's write traffic; writes and any read that must see the very latest committed data (read-after-write consistency) still go to the primary, since replicas lag behind by some replication delay. */

/* Q73. */
LISTEN order_events_channel;
NOTIFY order_events_channel, 'order:1:placed';

/* Q74. */
SELECT pg_advisory_lock(772211);
ALTER TABLE day_03_practice.demo_ddl_target ADD COLUMN note TEXT;
SELECT pg_advisory_unlock(772211);

/* Q75. */
SELECT pg_try_advisory_lock(500001) AS slot_1_acquired;
SELECT pg_try_advisory_lock(500002) AS slot_2_acquired;
SELECT pg_advisory_unlock(500001);
SELECT pg_advisory_unlock(500002);

/* ============================================================
   SECTION D: BULK LOAD & STREAMING (25)
   Requires /tmp/products_staging.csv with header "id,name,price"
   and two data rows (e.g. 1,Widget,100 / 2,Gadget,200).
   ------------------------------------------------------------ */
CREATE TABLE day_03_practice.bulk_target (id INT, name TEXT, price NUMERIC(12,2));

CREATE TABLE day_03_practice.stdin_raw (id INT, name TEXT, price NUMERIC(12,2));
CREATE TABLE day_03_practice.stdin_transformed (id INT, name_upper TEXT, price_cents INT);

CREATE TABLE day_03_practice.customers_bulk (
    cust_id INT PRIMARY KEY,
    email VARCHAR(100) UNIQUE,
    full_name VARCHAR(100)
);
CREATE TABLE day_03_practice.staging_bulk_customers (cust_id INT, email VARCHAR(100), full_name VARCHAR(100));

CREATE TABLE day_03_practice.bulk_delete_target (id SERIAL PRIMARY KEY, val TEXT);
INSERT INTO day_03_practice.bulk_delete_target (val) SELECT 'row' || n FROM generate_series(1, 25000) n;

CREATE TABLE day_03_practice.merge_source (product_id INT, price NUMERIC(12,2));
INSERT INTO day_03_practice.merge_source SELECT n, n * 1.5 FROM generate_series(1, 100) n;
CREATE TABLE day_03_practice.merge_target (product_id INT PRIMARY KEY, price NUMERIC(12,2));
INSERT INTO day_03_practice.merge_target SELECT n, 0 FROM generate_series(1, 50) n;

CREATE TABLE day_03_practice.main_from_unlogged (id INT, val TEXT);

CREATE TABLE day_03_practice.etl_checkpoints (source TEXT PRIMARY KEY, last_id BIGINT NOT NULL DEFAULT 0);
INSERT INTO day_03_practice.etl_checkpoints VALUES ('orders_feed', 0);
CREATE TABLE day_03_practice.etl_source_sim (id BIGSERIAL PRIMARY KEY, payload TEXT);
INSERT INTO day_03_practice.etl_source_sim (payload) SELECT 'p' || n FROM generate_series(1, 30) n;

CREATE TABLE day_03_practice.dedup_staging (id INT, val TEXT, updated_at TIMESTAMPTZ);
INSERT INTO day_03_practice.dedup_staging VALUES (1,'a', now() - interval '1 hour'), (1,'a-latest', now()), (2,'b', now());
CREATE TABLE day_03_practice.dedup_live (id INT PRIMARY KEY, val TEXT);

CREATE TABLE day_03_practice.orders_fk_check (order_id SERIAL PRIMARY KEY, cust_id INT REFERENCES day_03_practice.customers_bulk(cust_id));
CREATE TABLE day_03_practice.orders_staging_fk (order_id INT, cust_id INT);
INSERT INTO day_03_practice.customers_bulk (cust_id, email, full_name) VALUES (1, 'ok@example.com', 'OK Customer');
INSERT INTO day_03_practice.orders_staging_fk VALUES (101, 1), (102, 9999);
CREATE TABLE day_03_practice.orders_dead_letter (order_id INT, cust_id INT, reason TEXT, failed_at TIMESTAMPTZ DEFAULT NOW());

CREATE TABLE day_03_practice.customers_nn_target (cust_id SERIAL PRIMARY KEY, full_name TEXT NOT NULL DEFAULT 'Unknown');
CREATE TABLE day_03_practice.staging_nn (cust_id INT, full_name TEXT);
INSERT INTO day_03_practice.staging_nn VALUES (1, 'Alice'), (2, NULL);

CREATE TABLE day_03_practice.typed_target (id INT, amount NUMERIC(12,2));
CREATE TABLE day_03_practice.staging_typed (id INT, amount_text TEXT);
INSERT INTO day_03_practice.staging_typed VALUES (1, '100.50'), (2, 'not_a_number');
CREATE TABLE day_03_practice.typed_dead_letter (id INT, amount_text TEXT, failed_at TIMESTAMPTZ DEFAULT NOW());

CREATE TABLE day_03_practice.dup_target (id INT PRIMARY KEY, val TEXT);
INSERT INTO day_03_practice.dup_target VALUES (1, 'existing');
CREATE TABLE day_03_practice.staging_dup (id INT, val TEXT);
INSERT INTO day_03_practice.staging_dup VALUES (1, 'attempted_dup'), (2, 'new_row');

CREATE TABLE day_03_practice.retry_target (id INT PRIMARY KEY, val TEXT);
CREATE TABLE day_03_practice.staging_retry (id INT, val TEXT);
INSERT INTO day_03_practice.staging_retry VALUES (1, 'r1'), (2, 'r2');

CREATE TABLE day_03_practice.gen_series_test (id INT, val TEXT);

CREATE TABLE day_03_practice.etl_final_staging (id SERIAL PRIMARY KEY, val TEXT);
CREATE TABLE day_03_practice.etl_final_target (id INT PRIMARY KEY, val TEXT);
CREATE TABLE day_03_practice.etl_final_archive (id INT, val TEXT, archived_at TIMESTAMPTZ DEFAULT NOW());

/* Q76. */
\copy day_03_practice.bulk_target FROM '/tmp/products_staging.csv' WITH (FORMAT csv, HEADER true)

/* Q77. */
BEGIN;
CREATE TABLE day_03_practice.freeze_demo_crazy (id INT, name TEXT, price NUMERIC(12,2));
\copy day_03_practice.freeze_demo_crazy FROM '/tmp/products_staging.csv' WITH (FORMAT csv, HEADER true, FREEZE true)
COMMIT;

/* Q78. */
\copy day_03_practice.stdin_raw FROM '/tmp/products_staging.csv' WITH (FORMAT csv, HEADER true)
INSERT INTO day_03_practice.stdin_transformed (id, name_upper, price_cents)
SELECT id, upper(name), (price * 100)::int FROM day_03_practice.stdin_raw;

/* Q79. Streaming rows in from another database live (rather than a one-off export/import) uses a Foreign Data Wrapper: CREATE EXTENSION postgres_fdw; CREATE SERVER remote_db FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host '...', dbname '...'); CREATE USER MAPPING ...; IMPORT FOREIGN SCHEMA or CREATE FOREIGN TABLE to expose the remote table locally, then INSERT INTO local_table SELECT * FROM foreign_table reads it as if it were local (query pushdown handles filtering remotely). No real second database is available in this environment to stream from, so this is described rather than executed. */

/* Q80. */
INSERT INTO day_03_practice.staging_bulk_customers (cust_id, email, full_name)
SELECT n, 'cust' || n || '@example.com', 'Customer ' || n FROM generate_series(1, 100000) n;
INSERT INTO day_03_practice.customers_bulk (cust_id, email, full_name)
SELECT cust_id, email, full_name FROM day_03_practice.staging_bulk_customers
ON CONFLICT (cust_id) DO UPDATE SET email = EXCLUDED.email, full_name = EXCLUDED.full_name;

/* Q81. */
DO $$
DECLARE
  deleted_count INT;
BEGIN
  LOOP
    DELETE FROM day_03_practice.bulk_delete_target
    WHERE id IN (SELECT id FROM day_03_practice.bulk_delete_target LIMIT 10000);
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    EXIT WHEN deleted_count = 0;
  END LOOP;
END $$;

/* Q82. */
MERGE INTO day_03_practice.merge_target t
USING day_03_practice.merge_source s
ON t.product_id = s.product_id
WHEN MATCHED THEN UPDATE SET price = s.price
WHEN NOT MATCHED THEN INSERT (product_id, price) VALUES (s.product_id, s.price);

/* Q83. */
CREATE UNLOGGED TABLE day_03_practice.staging_unlogged (id INT, name TEXT, price NUMERIC(12,2));
\copy day_03_practice.staging_unlogged FROM '/tmp/products_staging.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',')
INSERT INTO day_03_practice.main_from_unlogged SELECT id, name FROM day_03_practice.staging_unlogged;

/* Q84. Running COPY jobs for several source files in parallel is an orchestration decision made outside SQL: launch N separate psql/\copy (or client library COPY) processes concurrently, one per file, each targeting the same or partitioned target tables. Each COPY still only takes a ROW EXCLUSIVE lock, so they don't block each other; the main things to manage are staying under max_connections, letting each worker load into its own staging table (or a hash/range-partitioned target) to avoid index contention, and having a single coordinator process wait for all workers to finish before the downstream MERGE/validation step runs. */

/* Q85. pg_bulkload is a third-party extension/CLI tool that bypasses the normal WAL-logged write path for bulk loads (writing heap pages more directly and optionally skipping WAL for an UNLOGGED-style fast load), making it faster than COPY for very large one-time loads - but it requires installing the extension and matching binary on the server, is not part of core PostgreSQL, and is not installed on this instance, so no real query can be run for it here. */

/* Q86. A streaming-ingestion pipeline captures each INSERT's generated id/fields via RETURNING (e.g. INSERT INTO orders (...) VALUES (...) RETURNING order_id, created_at) and immediately publishes that returned row as a message onto a Kafka topic from the application layer right after the insert - giving low-latency "write-then-publish" delivery. The Kafka publish step is an external system not available in this environment, so only the RETURNING half is directly testable; the more reliable variant of this pattern is the outbox pattern (Q39) which avoids the dual-write risk of this simpler approach. */

/* Q87. */
SELECT client_addr, state, coalesce(extract(epoch FROM replay_lag), 0) AS replay_lag_seconds
FROM pg_stat_replication;

/* Q88. */
INSERT INTO day_03_practice.customers_bulk (cust_id, email, full_name) VALUES (1, 'ok@example.com', 'OK Customer Updated')
ON CONFLICT (cust_id) DO UPDATE SET email = EXCLUDED.email, full_name = EXCLUDED.full_name;

/* Q89. */
UPDATE day_03_practice.etl_checkpoints SET last_id = (SELECT max(id) FROM day_03_practice.etl_source_sim)
WHERE source = 'orders_feed';
SELECT last_id FROM day_03_practice.etl_checkpoints WHERE source = 'orders_feed';

/* Q90. */
WITH dedup AS (
  SELECT DISTINCT ON (id) id, val FROM day_03_practice.dedup_staging ORDER BY id, updated_at DESC
)
INSERT INTO day_03_practice.dedup_live (id, val) SELECT id, val FROM dedup
ON CONFLICT (id) DO UPDATE SET val = EXCLUDED.val;

/* Q91. */
INSERT INTO day_03_practice.orders_fk_check (order_id, cust_id)
SELECT s.order_id, s.cust_id FROM day_03_practice.orders_staging_fk s
WHERE EXISTS (SELECT 1 FROM day_03_practice.customers_bulk c WHERE c.cust_id = s.cust_id);
INSERT INTO day_03_practice.orders_dead_letter (order_id, cust_id, reason)
SELECT s.order_id, s.cust_id, 'FK violation: cust_id not found'
FROM day_03_practice.orders_staging_fk s
WHERE NOT EXISTS (SELECT 1 FROM day_03_practice.customers_bulk c WHERE c.cust_id = s.cust_id);

/* Q92. */
INSERT INTO day_03_practice.customers_nn_target (cust_id, full_name)
SELECT cust_id, COALESCE(full_name, 'Unknown') FROM day_03_practice.staging_nn;

/* Q93. */
INSERT INTO day_03_practice.typed_target (id, amount)
SELECT id, amount_text::numeric FROM day_03_practice.staging_typed
WHERE amount_text ~ '^\d+(\.\d+)?$';
INSERT INTO day_03_practice.typed_dead_letter (id, amount_text)
SELECT id, amount_text FROM day_03_practice.staging_typed
WHERE amount_text !~ '^\d+(\.\d+)?$';

/* Q94. */
INSERT INTO day_03_practice.dup_target (id, val)
SELECT id, val FROM day_03_practice.staging_dup
ON CONFLICT (id) DO NOTHING;

/* Q95. */
WITH attempt AS (
  INSERT INTO day_03_practice.retry_target (id, val)
  SELECT id, val FROM day_03_practice.staging_retry
  ON CONFLICT (id) DO UPDATE SET val = EXCLUDED.val
  RETURNING id
)
SELECT count(*) AS rows_applied FROM attempt;

/* Q96. */
INSERT INTO day_03_practice.gen_series_test (id, val)
SELECT n, 'test_row_' || n FROM generate_series(1, 5000) n;

/* Q97. Migrating FROM MySQL uses the mysql_fdw extension: CREATE EXTENSION mysql_fdw; CREATE SERVER mysql_server FOREIGN DATA WRAPPER mysql_fdw OPTIONS (host '...', port '3306'); CREATE USER MAPPING ...; IMPORT FOREIGN SCHEMA remote_schema FROM SERVER mysql_server INTO local_schema; then INSERT INTO local_table SELECT * FROM foreign_table pulls the data through the wrapper. mysql_fdw is a separate extension (not part of core PostgreSQL) and is not installed here, and no real MySQL source is available in this environment, so this is described rather than executed. */

/* Q98. Migrating to ClickHouse typically goes: pg_dump --table=... --format=csv (or a \copy ... TO STDOUT WITH CSV per table) to export data out of Postgres, then loading those CSV files with clickhouse-client --query "INSERT INTO table FORMAT CSV" < file.csv (or the clickhouse-client local file-upload options) on the ClickHouse side - the two systems don't talk to each other directly, so a flat-file (CSV/Parquet) hand-off is the standard bridge. No ClickHouse instance is available here to actually run the load step. */

/* Q99. Migrating to Snowflake typically goes: pg_dump (or \copy) each table out to CSV/Parquet locally, upload those files to a cloud staging bucket (aws s3 cp ... to an S3 bucket, since Snowflake's COPY INTO reads from S3/Azure/GCS external stages), then run Snowflake's COPY INTO my_table FROM @my_s3_stage command to bulk-load from that staged location into the target Snowflake table. No AWS/Snowflake account is available in this environment to actually execute the cloud upload or Snowflake load step. */

/* Q100. */
INSERT INTO day_03_practice.etl_final_staging (val) SELECT 'src' || n FROM generate_series(1, 20) n;
MERGE INTO day_03_practice.etl_final_target t
USING day_03_practice.etl_final_staging s
ON t.id = s.id
WHEN NOT MATCHED THEN INSERT (id, val) VALUES (s.id, s.val)
WHEN MATCHED THEN UPDATE SET val = s.val;
INSERT INTO day_03_practice.etl_final_archive (id, val)
SELECT id, val FROM day_03_practice.etl_final_target t
WHERE EXISTS (SELECT 1 FROM day_03_practice.etl_final_staging s WHERE s.id = t.id);
DROP TABLE day_03_practice.etl_final_staging;
