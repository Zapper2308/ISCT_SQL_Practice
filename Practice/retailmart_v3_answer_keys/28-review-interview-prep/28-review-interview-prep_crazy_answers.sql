/* ============================================================
   ANSWER KEY - Review & Interview Prep (CRAZY LEVEL)
   Curriculum:   RetailMart V3
   Database:     isct_retailmart
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL REVIEW - STAFF ENGINEER LEVEL (25)
   ------------------------------------------------------------ */
/* Q1. NOT IN (SELECT cust_id FROM ...) is evaluated as x<>a AND x<>b AND ... AND x<>NULL for every value the subquery returns; comparing anything to NULL yields UNKNOWN, and UNKNOWN ANDed into the rest means the whole expression can never be definitively TRUE, so NOT IN silently returns zero rows the moment the subquery contains even one NULL. The safe, NULL-proof rewrite uses NOT EXISTS: */
SELECT c.customer_id FROM customers.customers c
WHERE NOT EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id);

/* Q2. ROWS BETWEEN counts a fixed number of physical rows regardless of ties in the ORDER BY; RANGE BETWEEN groups every row sharing the current row's ORDER BY value together as peers and includes/excludes them as a unit. On sales.orders, two orders placed on the identical order_date get the same RANGE-based cumulative SUM (both peers see the same frame boundary) but different ROWS-based cumulative SUMs (each counted strictly in physical/tie-broken sequence) - the two frames diverge exactly when the ordering column has ties. */

/* Q3. Postgres has no MEDIAN() window function because ordered-set aggregates like PERCENTILE_CONT (which need the full sorted input to interpolate) cannot be used with an OVER clause - only plain aggregates support windowing. The workaround is a correlated subquery that re-runs PERCENTILE_CONT ... WITHIN GROUP over the relevant row range for each output row: */
SELECT o1.order_date,
       (SELECT ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o2.net_total)::numeric, 2)
        FROM sales.orders o2 WHERE o2.order_date <= o1.order_date) AS running_median
FROM (SELECT DISTINCT order_date FROM sales.orders ORDER BY order_date DESC LIMIT 20) o1
ORDER BY o1.order_date;

/* Q4. Parse turns SQL text into a parse tree and checks syntax; Rewrite applies rule-system transformations (view expansion, RLS policy injection); Plan (the optimizer) enumerates candidate access paths/join orders and picks the cheapest one using a cost model whose inputs are cardinality (row-count) estimates from pg_statistic at every step; Execute runs the chosen plan node-by-node. Cardinality estimation lives inside the Plan stage - it's the input the cost model compares candidate plans against, so a bad estimate anywhere in that stage can steer the optimizer toward a worse plan even though Execute just faithfully runs whatever plan it was handed. */

/* Q5. Two rewrites: (1) replace the per-customer LATERAL scan with a single-pass window function - JOIN orders to order_items once and use ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY ...) to rank items per customer in one sequential/hash pass instead of 50,000 separate lookups; (2) if LATERAL is still needed (e.g. the inner query needs a real LIMIT-with-early-exit a window function can't give as cheaply), add supporting indexes (orders(cust_id), order_items(order_id)) so each LATERAL call becomes an indexed lookup instead of a full table scan, cutting the per-call cost from O(table size) to O(log n + matching rows). */

/* Q6. A "zombie tuple" is a dead row version left behind by an UPDATE or DELETE under MVCC - the old version isn't removed immediately because other in-flight transactions might still need to see it, so it stays on disk (dead but unreclaimed) until VACUUM cleans it up. Aggressive UPDATEs without VACUUM/autovacuum keeping pace accumulate more dead-but-unreclaimed row versions than get cleaned, bloating the table (and its indexes) far beyond the size of its live data, which slows every scan that has to skip past them. */

/* Q7. Choose BRIN when the indexed column is naturally correlated with physical row order - an append-mostly, roughly-insert-ordered column like a timestamp - because BRIN relies on each physical block already containing a narrow value range; if the data isn't naturally ordered that way (or becomes disordered via random UPDATEs/deletes-and-reinserts), BRIN's per-block min/max summaries stop being selective and it degenerates toward scanning most of the table anyway. */

/* Q8. The 1/15th-size partial index is far cheaper to store and just as fast for queries whose predicate is provably a subset of order_status = 'Processing'; the tradeoff breaks the moment a query's WHERE clause isn't provably implied by that condition - no order_status filter at all, or a different status value - since the planner can't use this index for that query and falls back to a full index or Seq Scan. */

/* Q9. Postgres's EXPLAIN doesn't literally use "inclusive"/"exclusive" hash join - the real distinction is a plain Hash Join (emits a joined row for every matching pair, "inclusive" of duplicates) versus a Hash Semi Join (emits each outer row at most once if any match exists - used for EXISTS/IN) and a Hash Anti Join (emits each outer row only if NO match exists - used for NOT EXISTS/NOT IN, "exclusive" of matches); the semi/anti variants appear whenever the query only needs presence/absence of a match rather than the matched columns themselves. */

/* Q10. A "streaming" (Group) aggregate consumes pre-sorted input and finalizes an aggregate as soon as the grouping key changes, using O(1) memory per group in flight - prefer it when input is already ordered by the GROUP BY columns (via an index) or when there are too many distinct groups to fit in work_mem. A Hash Aggregate builds a full in-memory hash table for every group before emitting anything - prefer it when input isn't sorted and the distinct-group count is expected to fit comfortably in memory, since it avoids paying for an explicit Sort. */

/* Q11. A phantom read is when a query run twice within the same transaction sees a different SET of rows the second time (new rows matching the WHERE clause appeared, committed elsewhere). Postgres's REPEATABLE READ actually prevents this outright (a single consistent snapshot for the whole transaction, stricter than the SQL standard requires) - but it still matters for analytics because a long-running REPEATABLE READ transaction keeps returning data as of its snapshot start, silently missing anything committed after it began, so a multi-query report run inside one such transaction won't reflect concurrent inserts even though "the database has more data now." */

/* Q12. MVCC keeps multiple physical versions of each row, tagging each with the transaction that created and (if superseded) obsoleted it, so every transaction sees a consistent snapshot as of when it started rather than one shared mutable copy. Because a reader simply looks at the version visible to its own snapshot instead of taking a lock on the row, a writer creating a new version doesn't need to block concurrent readers (and vice versa) - reads and writes proceed independently. */

/* Q13. "shared hit=50000" means 50,000 block reads were satisfied directly from shared_buffers (no disk I/O); "read=200" means only 200 blocks had to be fetched from disk (or OS cache). A hit ratio this high (≈99.6%) means the query's working set is almost entirely cache-resident, so cache effectiveness is excellent and disk I/O is not this query's bottleneck. */

/* Q14. REFRESH MATERIALIZED VIEW CONCURRENTLY rebuilds the MV's data into a new copy behind the scenes and only briefly locks it to swap the rows in, so readers keep querying the old data throughout instead of being blocked by the ACCESS EXCLUSIVE lock a plain REFRESH takes; it requires the MV to already have at least one UNIQUE index (covering all rows, no WHERE clause), since Postgres uses that index to compute the differential insert/delete/update set rather than truncating and reloading everything. */

/* Q15. A B-tree index bloats when many UPDATEs/DELETEs leave dead entries pointing at now-invisible or moved row versions, and especially when non-HOT updates insert a fresh entry for every new row version without fully reusing the deleted entries' space - over time the index accumulates far more pages than the live data needs. VACUUM reclaims dead entries for reuse within the index but does not shrink the file; to actually reclaim space (and defragment) you REINDEX (or REINDEX CONCURRENTLY to avoid locking) or VACUUM FULL the table. */

/* Q16. Key columns are part of the index's sort order and usable in WHERE/ORDER BY/equality-range predicates and uniqueness enforcement; INCLUDE columns are carried in the leaf pages purely as payload - not sorted, not usable for search predicates or uniqueness, but readable directly from the index. It matters when a SELECT needs columns it never filters/sorts by (e.g. INCLUDE (net_total) so the value is read from the index without a heap fetch) - adding them as INCLUDE keeps the index's real search key narrow (cheaper unique-constraint checks, better key compression) while still enabling an Index Only Scan for those extra columns. */

/* Q17. A junction table customers_promotions (customer_id FK -> customers.customers, promo_id FK -> products.promotions, PRIMARY KEY (customer_id, promo_id), plus a redeemed_at timestamp) models the many-to-many relationship; the composite primary key itself is a unique index enforcing "a customer can't be linked to the same promotion twice" and gives fast lookups in (customer_id, promo_id) order, while a second index on (promo_id, customer_id) would be added if "which customers used promotion X" needs to be a fast leading-column query, since the PK alone can't serve that direction efficiently. */

/* Q18. Table partitioning splits one logical table into multiple physical child tables based on a partition key, while queries and DML still address the parent table transparently. sales.orders would benefit most from RANGE partitioning on order_date (e.g. monthly) - date-range queries prune to just the relevant partitions, VACUUM/maintenance runs per-partition instead of on one giant table, and old partitions can be dropped/archived as a cheap metadata operation instead of a slow bulk DELETE. */

/* Q19. The planner's statistics show ~99% of rows are NULL in that column, so a plain B-tree index there would store (and Postgres would traverse) a huge number of NULL entries for very little selectivity benefit - the planner correctly estimates a Seq Scan is cheaper than paying for that mostly-useless traversal. A partial index with WHERE column IS NOT NULL excludes the 99% NULL rows entirely and indexes only the meaningful 1%, making it small and genuinely selective. */

/* Q20. ANALYZE samples a subset of a table's rows and refreshes pg_statistic - most-common values and their frequencies, a value-distribution histogram, estimated distinct-value count, and physical/logical correlation - which the cost-based optimizer reads to estimate predicate/join selectivity. A freshly bulk-loaded table has no statistics yet (or stale ones from before the load), so the planner falls back to hardcoded default assumptions that are frequently wrong for the new data's actual distribution, producing bad join orders/methods until an ANALYZE (manual or autovacuum-triggered) runs. */

/* Q21. A correlated subquery references a column from the enclosing query, so naively it would be re-evaluated once per outer row (a nested-loop pattern); a decorrelated subquery is one the planner has rewritten into an equivalent join/semi-join/anti-join (usually a hash or merge join) computing the same result in a single pass without repeated re-execution. Postgres's planner performs this transformation automatically for many common shapes (WHERE EXISTS/IN/scalar-equality correlated subqueries), turning them into semi/anti joins internally when it can prove the rewrite is equivalent - visible in EXPLAIN as a Hash Semi/Anti Join instead of a Nested Loop with a Subquery Scan repeated per row. */

/* Q22. A merge join requires both inputs already sorted (or sorted via an explicit Sort node) on the join key; it then walks both sorted streams in lockstep, advancing whichever side has the smaller current key and emitting matches as it goes - each row from each side is visited a bounded number of times, for an amortized cost of O(n + m) (plus O(n log n)/O(m log m) if a Sort had to be added), versus hash join's O(n + m) with an in-memory build side, or nested loop's O(n*m) with no index. */

/* Q23. Identify the rows to remove first with a read-only CTE that ranks duplicates per business key (ROW_NUMBER() OVER (PARTITION BY business_key ORDER BY updated_at DESC), keeping rn=1) run as a plain SELECT so the row count/sample can be eyeballed before anything is touched; then perform the actual delete in small batches (e.g. repeatedly DELETE ... WHERE ctid IN (SELECT ctid FROM ranked WHERE rn > 1 LIMIT 10000)), each batch its own short transaction, rather than one giant DELETE - so a single long-running statement doesn't hold locks/bloat the table for hours, and a failure partway through only needs to resume, not restart. */

/* Q24. A view is a stored, named, reusable query definition any statement can reference like a table - a plain view's SQL can be inlined by the planner into the outer query for joint optimization. A CTE (WITH clause) is scoped to a single statement and not reusable elsewhere; in Postgres 12+, a non-recursive, side-effect-free CTE referenced only once is inlined like a subquery by default, but it becomes a "CTE fence" (materialized as its own step, not merged into the surrounding plan) when it's referenced multiple times, is recursive, or is explicitly marked MATERIALIZED - at that point the planner optimizes inside and outside the CTE separately, which can block otherwise-available optimizations like predicate pushdown. */

/* Q25. order_status changes frequently (every order transitions through several statuses over its lifetime), so an index on it must be updated on every one of those UPDATEs - extra I/O and WAL, and potential index-page splits, on every write. A low-cardinality column like order_status (a handful of distinct values across 150k rows) also gives little read-side benefit since most values still match a large fraction of the table, so the write cost of keeping the index current usually outweighs the modest read-side gain - a partial index on just the rare/interesting statuses (e.g. 'Processing') is typically the better tradeoff. */

/* ============================================================
   SECTION B: END-TO-END ANALYTICS PIPELINES (25)
   ------------------------------------------------------------ */
/* Q26. */
WITH cust_orders AS (
  SELECT cust_id, COUNT(*) AS total_orders, SUM(net_total) AS total_spend, AVG(net_total) AS avg_order_value, MAX(order_date) AS last_order_date
  FROM sales.orders
  GROUP BY cust_id
),
scored AS (
  SELECT cust_id, total_orders, total_spend, avg_order_value, last_order_date,
         (SELECT MAX(order_date) FROM sales.orders) - last_order_date AS days_since_last_order,
         NTILE(5) OVER (ORDER BY (SELECT MAX(order_date) FROM sales.orders) - last_order_date DESC) AS r_score,
         NTILE(5) OVER (ORDER BY total_orders) AS f_score,
         NTILE(5) OVER (ORDER BY total_spend) AS m_score
  FROM cust_orders
)
SELECT s.cust_id, s.total_orders, ROUND(s.total_spend, 2) AS total_spend, ROUND(s.avg_order_value, 2) AS avg_order_value,
       s.days_since_last_order, c.tier AS loyalty_tier,
       ROUND((s.r_score + s.f_score + s.m_score) / 3.0, 2) AS rfm_score,
       (s.days_since_last_order > 180) AS churn_risk_flag
FROM scored s
JOIN customers.customers c ON c.customer_id = s.cust_id
ORDER BY s.cust_id;

/* Q27. -- marketing.email_clicks has no customer-level identifier (only aggregate campaign send/open/click counts), so a per-customer email-click match to orders isn't derivable; revenue is attributed to a campaign as all order revenue in the 7 days after its launch, alongside that campaign's aggregate email metrics for context. */
WITH campaign_orders AS (
  SELECT mc.campaign_id, mc.campaign_name, mc.start_date, SUM(o.net_total) AS revenue_within_7d
  FROM marketing.campaigns mc
  JOIN sales.orders o ON o.order_date >= mc.start_date AND o.order_date < mc.start_date + 7
  GROUP BY mc.campaign_id, mc.campaign_name, mc.start_date
),
campaign_emails AS (
  SELECT campaign_id, SUM(emails_sent) AS emails_sent, SUM(emails_clicked) AS emails_clicked
  FROM marketing.email_clicks
  GROUP BY campaign_id
)
SELECT co.campaign_id, co.campaign_name, co.start_date, co.revenue_within_7d,
       COALESCE(ce.emails_sent, 0) AS emails_sent, COALESCE(ce.emails_clicked, 0) AS emails_clicked
FROM campaign_orders co
LEFT JOIN campaign_emails ce ON ce.campaign_id = co.campaign_id
ORDER BY co.revenue_within_7d DESC;

/* Q28. */
WITH latest_snap AS (
  SELECT DISTINCT ON (warehouse_id, product_id) warehouse_id, product_id, quantity_on_hand
  FROM supply_chain.inventory_snapshots
  ORDER BY warehouse_id, product_id, snapshot_date DESC
),
avg_daily_orders AS (
  SELECT COUNT(*)::numeric / NULLIF((SELECT MAX(order_date) - MIN(order_date) FROM sales.orders), 0) AS avg_daily_order_count
  FROM sales.orders
),
sla AS (
  SELECT COUNT(*) AS total_shipments, COUNT(*) FILTER (WHERE status = 'Delayed') AS delayed_shipments
  FROM supply_chain.shipments
),
dead_stock AS (
  SELECT ls.warehouse_id, ls.product_id
  FROM latest_snap ls
  WHERE NOT EXISTS (
    SELECT 1 FROM sales.order_items oi JOIN sales.orders o ON o.order_id = oi.order_id
    WHERE oi.prod_id = ls.product_id AND o.order_date >= (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '90 days'
  )
)
SELECT
  (SELECT ROUND(SUM(quantity_on_hand) / NULLIF((SELECT avg_daily_order_count FROM avg_daily_orders), 0), 1) FROM latest_snap) AS inventory_coverage_days,
  (SELECT ROUND(100.0 * delayed_shipments / NULLIF(total_shipments, 0), 2) FROM sla) AS sla_breach_rate_pct,
  (SELECT COUNT(*) FROM dead_stock) AS dead_stock_product_count;

/* Q29. */
WITH cohorts AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS signup_month
  FROM customers.customers
),
activity AS (
  SELECT c.customer_id, c.signup_month,
         (DATE_PART('year', AGE(DATE_TRUNC('month', o.order_date), c.signup_month)) * 12
          + DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), c.signup_month)))::int AS period_index
  FROM cohorts c
  JOIN sales.orders o ON o.cust_id = c.customer_id
),
cohort_size AS (
  SELECT signup_month, COUNT(*) AS cohort_size FROM cohorts GROUP BY signup_month
)
SELECT a.signup_month, a.period_index, cs.cohort_size,
       COUNT(DISTINCT a.customer_id) AS retained_customers,
       ROUND(100.0 * COUNT(DISTINCT a.customer_id) / NULLIF(cs.cohort_size, 0), 2) AS retention_pct
FROM activity a
JOIN cohort_size cs ON cs.signup_month = a.signup_month
WHERE a.period_index BETWEEN 0 AND 6
GROUP BY a.signup_month, a.period_index, cs.cohort_size
ORDER BY a.signup_month, a.period_index;

/* Q30. */
WITH prod_sales AS (
  SELECT p.product_id, p.product_name,
         SUM(oi.quantity * oi.unit_price) AS revenue,
         SUM(oi.quantity * p.cost_price) AS cost,
         COUNT(DISTINCT oi.order_id) AS order_count
  FROM sales.order_items oi
  JOIN products.products p ON p.product_id = oi.prod_id
  GROUP BY p.product_id, p.product_name
),
prod_returns AS (
  SELECT prod_id, COUNT(*) AS return_count FROM sales.returns GROUP BY prod_id
),
combined AS (
  SELECT ps.product_id, ps.product_name, ps.revenue, ps.cost, (ps.revenue - ps.cost) AS gross_margin,
         ps.order_count, COALESCE(pr.return_count, 0) AS return_count,
         ROUND(COALESCE(pr.return_count, 0)::numeric / NULLIF(ps.order_count, 0), 4) AS return_rate
  FROM prod_sales ps
  LEFT JOIN prod_returns pr ON pr.prod_id = ps.product_id
)
SELECT product_id, product_name, revenue, cost, gross_margin, return_rate,
       SUM(revenue) OVER (ORDER BY revenue DESC) AS cumulative_revenue,
       ROUND(100.0 * SUM(revenue) OVER (ORDER BY revenue DESC) / SUM(revenue) OVER (), 2) AS cumulative_pct,
       CASE WHEN ROUND(100.0 * SUM(revenue) OVER (ORDER BY revenue DESC) / SUM(revenue) OVER (), 2) <= 80 THEN 'A'
            WHEN ROUND(100.0 * SUM(revenue) OVER (ORDER BY revenue DESC) / SUM(revenue) OVER (), 2) <= 95 THEN 'B'
            ELSE 'C' END AS abc_class
FROM combined
ORDER BY revenue DESC;

/* Q31. -- support.tickets has no store_id, so a ticket's store is approximated via the customer's most recent order's store. */
WITH ticket_stats AS (
  SELECT customer_id, AVG(EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600) AS avg_resolution_hours
  FROM support.tickets
  WHERE resolved_date IS NOT NULL
  GROUP BY customer_id
),
cust_store AS (
  SELECT DISTINCT ON (cust_id) cust_id, store_id FROM sales.orders ORDER BY cust_id, order_date DESC
),
store_revenue AS (
  SELECT store_id, SUM(net_total) AS total_revenue,
         COUNT(*) FILTER (WHERE order_status = 'Returned') AS returns, COUNT(*) AS total_orders
  FROM sales.orders
  GROUP BY store_id
),
store_top_cat AS (
  SELECT store_id, category_name FROM (
    SELECT o.store_id, cat.category_name, SUM(oi.quantity * oi.unit_price) AS revenue,
           ROW_NUMBER() OVER (PARTITION BY o.store_id ORDER BY SUM(oi.quantity * oi.unit_price) DESC) AS rn
    FROM sales.order_items oi
    JOIN sales.orders o ON o.order_id = oi.order_id
    JOIN products.products p ON p.product_id = oi.prod_id
    JOIN core.dim_brand b ON b.brand_id = p.brand_id
    JOIN core.dim_category cat ON cat.category_id = b.category_id
    GROUP BY o.store_id, cat.category_name
  ) ranked WHERE rn = 1
),
store_emp_count AS (
  SELECT store_id, COUNT(*) AS employee_count FROM stores.employees GROUP BY store_id
),
store_tickets AS (
  SELECT cs.store_id, AVG(ts.avg_resolution_hours) AS avg_ticket_resolution_hours
  FROM cust_store cs
  JOIN ticket_stats ts ON ts.customer_id = cs.cust_id
  GROUP BY cs.store_id
)
SELECT sr.store_id, sr.total_revenue,
       ROUND(st.avg_ticket_resolution_hours, 2) AS avg_ticket_resolution_hours,
       ROUND(100.0 * sr.returns / NULLIF(sr.total_orders, 0), 2) AS return_rate_pct,
       stc.category_name AS top_selling_category,
       se.employee_count
FROM store_revenue sr
LEFT JOIN store_tickets st ON st.store_id = sr.store_id
LEFT JOIN store_top_cat stc ON stc.store_id = sr.store_id
LEFT JOIN store_emp_count se ON se.store_id = sr.store_id
ORDER BY sr.store_id;

/* Q32. */
WITH viewers AS (
  SELECT DISTINCT customer_id FROM web_events.page_views WHERE customer_id IS NOT NULL
),
cart AS (
  SELECT DISTINCT pv.customer_id
  FROM web_events.events ev
  JOIN web_events.page_views pv ON pv.view_id = ev.view_id
  WHERE ev.event_type = 'add_to_cart' AND pv.customer_id IS NOT NULL
),
purchasers AS (
  SELECT DISTINCT cust_id AS customer_id FROM sales.orders
)
SELECT
  (SELECT COUNT(*) FROM viewers) AS step1_visited,
  (SELECT COUNT(*) FROM cart) AS step2_added_to_cart,
  (SELECT COUNT(*) FROM purchasers p JOIN cart c ON c.customer_id = p.customer_id) AS step3_purchased,
  ROUND(100.0 * (SELECT COUNT(*) FROM cart) / NULLIF((SELECT COUNT(*) FROM viewers), 0), 2) AS visit_to_cart_pct,
  ROUND(100.0 * (SELECT COUNT(*) FROM purchasers p JOIN cart c ON c.customer_id = p.customer_id)
        / NULLIF((SELECT COUNT(*) FROM cart), 0), 2) AS cart_to_purchase_pct;

/* Q33. -- no explicit wallet-funding ledger exists in the schema; "expected balance" is approximated as refunds credited (finance.payments where status='Refunded') minus loyalty points redeemed, converted at an assumed 100 points = Rs1. */
WITH refund_credits AS (
  SELECT cust_id, SUM(amount) AS total_refunded
  FROM finance.payments
  WHERE status = 'Refunded'
  GROUP BY cust_id
),
redemption_debits AS (
  SELECT customer_id, SUM(points_redeemed) AS total_points_redeemed
  FROM loyalty.redemptions
  GROUP BY customer_id
)
SELECT w.cust_id, w.balance,
       COALESCE(rc.total_refunded, 0) AS total_refunded,
       COALESCE(rd.total_points_redeemed, 0) AS total_points_redeemed,
       ROUND(COALESCE(rc.total_refunded, 0) - COALESCE(rd.total_points_redeemed, 0) / 100.0, 2) AS expected_balance_approx,
       ROUND(ABS(w.balance - (COALESCE(rc.total_refunded, 0) - COALESCE(rd.total_points_redeemed, 0) / 100.0)), 2) AS discrepancy
FROM customers.wallets w
LEFT JOIN refund_credits rc ON rc.cust_id = w.cust_id
LEFT JOIN redemption_debits rd ON rd.customer_id = w.cust_id
WHERE ABS(w.balance - (COALESCE(rc.total_refunded, 0) - COALESCE(rd.total_points_redeemed, 0) / 100.0)) > 100
ORDER BY discrepancy DESC;

/* Q34. */
WITH pay_slip_monthly AS (
  SELECT employee_id, salary_year, TRIM(salary_month) AS salary_month, gross_salary
  FROM payroll.pay_slips
),
salary_hist_monthly AS (
  SELECT employee_id, EXTRACT(YEAR FROM payment_date)::int AS pay_year, TRIM(TO_CHAR(payment_date, 'Month')) AS pay_month_name, SUM(amount) AS hist_amount
  FROM hr.salary_history
  WHERE status = 'Processed'
  GROUP BY employee_id, EXTRACT(YEAR FROM payment_date), TO_CHAR(payment_date, 'Month')
)
SELECT ps.employee_id, ps.salary_year, ps.salary_month, ps.gross_salary, sh.hist_amount,
       ROUND(100.0 * ABS(ps.gross_salary - sh.hist_amount) / NULLIF(ps.gross_salary, 0), 2) AS pct_diff
FROM pay_slip_monthly ps
JOIN salary_hist_monthly sh ON sh.employee_id = ps.employee_id AND sh.pay_year = ps.salary_year AND sh.pay_month_name = ps.salary_month
WHERE ABS(ps.gross_salary - sh.hist_amount) > 0.05 * ps.gross_salary
ORDER BY pct_diff DESC;

/* Q35. */
WITH email_stats AS (
  SELECT campaign_id, SUM(emails_sent) AS emails_sent, SUM(emails_opened) AS emails_opened, SUM(emails_clicked) AS emails_clicked
  FROM marketing.email_clicks
  GROUP BY campaign_id
),
campaign_orders AS (
  SELECT mc.campaign_id, SUM(o.net_total) AS revenue, COUNT(o.order_id) AS orders_placed
  FROM marketing.campaigns mc
  JOIN sales.orders o ON o.order_date >= mc.start_date AND o.order_date < mc.start_date + 7
  GROUP BY mc.campaign_id
)
SELECT mc.campaign_id, mc.campaign_name,
       COALESCE(es.emails_sent, 0) AS emails_sent,
       ROUND(100.0 * COALESCE(es.emails_opened, 0) / NULLIF(es.emails_sent, 0), 2) AS open_rate_pct,
       ROUND(100.0 * COALESCE(es.emails_clicked, 0) / NULLIF(es.emails_sent, 0), 2) AS click_rate_pct,
       COALESCE(co.orders_placed, 0) AS orders_placed,
       COALESCE(co.revenue, 0) AS revenue,
       ROUND(COALESCE(co.revenue, 0) / NULLIF(es.emails_sent, 0), 4) AS revenue_per_email_sent
FROM marketing.campaigns mc
LEFT JOIN email_stats es ON es.campaign_id = mc.campaign_id
LEFT JOIN campaign_orders co ON co.campaign_id = mc.campaign_id
ORDER BY revenue DESC NULLS LAST;

/* Q36. -- support.tickets has no order_id column, so a return-ticket match is approximated via the same customer on the same calendar day as the return. */
WITH returns_customer AS (
  SELECT r.return_id, r.reason, r.refund_amount, r.return_date, o.cust_id
  FROM sales.returns r
  JOIN sales.orders o ON o.order_id = r.order_id
),
matched AS (
  SELECT rc.*, t.ticket_id
  FROM returns_customer rc
  LEFT JOIN support.tickets t ON t.customer_id = rc.cust_id AND t.created_date::date = rc.return_date
)
SELECT reason,
       COUNT(*) AS volume,
       COUNT(ticket_id) AS with_matching_ticket_count,
       ROUND(AVG(refund_amount), 2) AS avg_refund_amount,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_total_returns
FROM matched
GROUP BY reason
ORDER BY volume DESC;

/* Q37. */
WITH daily AS (
  SELECT view_timestamp::date AS view_date, customer_id
  FROM web_events.page_views
  WHERE customer_id IS NOT NULL
  GROUP BY view_timestamp::date, customer_id
),
daily_active AS (
  SELECT view_date, COUNT(DISTINCT customer_id) AS dau FROM daily GROUP BY view_date
),
weekly AS (
  SELECT DATE_TRUNC('week', view_date)::date AS wk, customer_id FROM daily GROUP BY DATE_TRUNC('week', view_date), customer_id
),
weekly_active AS (
  SELECT wk, COUNT(DISTINCT customer_id) AS wau FROM weekly GROUP BY wk
),
monthly_active AS (
  SELECT DATE_TRUNC('month', view_date)::date AS mth, COUNT(DISTINCT customer_id) AS mau FROM daily GROUP BY DATE_TRUNC('month', view_date)
),
monthly_dau_avg AS (
  SELECT DATE_TRUNC('month', view_date)::date AS mth, AVG(dau) AS avg_dau FROM daily_active GROUP BY DATE_TRUNC('month', view_date)
),
monthly_wau_avg AS (
  SELECT DATE_TRUNC('month', wk)::date AS mth, AVG(wau) AS avg_wau FROM weekly_active GROUP BY DATE_TRUNC('month', wk)
)
SELECT ma.mth, ROUND(da.avg_dau, 2) AS avg_dau, ROUND(wa.avg_wau, 2) AS avg_wau, ma.mau,
       ROUND(da.avg_dau / NULLIF(ma.mau, 0), 4) AS dau_mau_stickiness,
       ROUND(wa.avg_wau / NULLIF(ma.mau, 0), 4) AS wau_mau_stickiness
FROM monthly_active ma
JOIN monthly_dau_avg da ON da.mth = ma.mth
JOIN monthly_wau_avg wa ON wa.mth = ma.mth
ORDER BY ma.mth;

/* Q38. */
WITH first_order AS (
  SELECT cust_id, MIN(order_date) AS first_order_date FROM sales.orders GROUP BY cust_id
)
SELECT DATE_TRUNC('month', o.order_date)::date AS mth,
       SUM(o.net_total) FILTER (WHERE o.order_date = fo.first_order_date) AS new_customer_revenue,
       SUM(o.net_total) FILTER (WHERE o.order_date <> fo.first_order_date) AS repeat_customer_revenue
FROM sales.orders o
JOIN first_order fo ON fo.cust_id = o.cust_id
GROUP BY DATE_TRUNC('month', o.order_date)
ORDER BY mth;

/* Q39. -- condition (b) is dropped per the question's own "(if available)" caveat: customers.addresses has no change timestamp, and audit.record_changes only tracks employees.salary and products.price in this dataset, so no address-change history exists to check. */
WITH cust_avg AS (
  SELECT cust_id, AVG(net_total) AS avg_order FROM sales.orders GROUP BY cust_id
)
SELECT o.order_id, o.cust_id, o.gross_total, ROUND(ca.avg_order, 2) AS avg_order, o.order_status
FROM sales.orders o
JOIN cust_avg ca ON ca.cust_id = o.cust_id
WHERE o.gross_total > 3 * ca.avg_order
  AND o.order_status = 'Processing'
ORDER BY o.gross_total DESC;

/* Q40. */
WITH latest_snap AS (
  SELECT DISTINCT ON (warehouse_id, product_id) warehouse_id, product_id, quantity_on_hand
  FROM supply_chain.inventory_snapshots
  ORDER BY warehouse_id, product_id, snapshot_date DESC
),
sales_30d AS (
  SELECT oi.prod_id, SUM(oi.quantity) / 30.0 AS avg_daily_sales
  FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  WHERE o.order_date >= (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '30 days'
  GROUP BY oi.prod_id
)
SELECT ls.warehouse_id, ls.product_id, ls.quantity_on_hand AS current_qty,
       ROUND(COALESCE(s.avg_daily_sales, 0), 3) AS avg_daily_sales,
       ROUND(ls.quantity_on_hand / NULLIF(s.avg_daily_sales, 0), 1) AS days_of_stock,
       CASE
         WHEN s.avg_daily_sales IS NULL OR s.avg_daily_sales = 0 THEN 'OK'
         WHEN ls.quantity_on_hand / s.avg_daily_sales < 7 THEN 'Critical'
         WHEN ls.quantity_on_hand / s.avg_daily_sales <= 30 THEN 'Low'
         ELSE 'OK'
       END AS reorder_urgency,
       ROUND(ls.quantity_on_hand * p.cost_price, 2) AS value_at_risk
FROM latest_snap ls
JOIN products.products p ON p.product_id = ls.product_id
LEFT JOIN sales_30d s ON s.prod_id = ls.product_id
ORDER BY days_of_stock NULLS LAST;

/* Q41. */
WITH dept_headcount AS (
  SELECT dept_id, COUNT(*) AS headcount, AVG(salary) AS avg_salary
  FROM stores.employees
  GROUP BY dept_id
),
dept_annual AS (
  SELECT dept_id, headcount, avg_salary, headcount * avg_salary * 12 AS total_annual_payroll_approx
  FROM dept_headcount
),
company_total AS (
  SELECT SUM(total_annual_payroll_approx) AS company_payroll FROM dept_annual
),
dept_yearly_hist AS (
  SELECT e.dept_id, EXTRACT(YEAR FROM sh.payment_date)::int AS yr, SUM(sh.amount) AS yearly_amount
  FROM hr.salary_history sh
  JOIN stores.employees e ON e.employee_id = sh.employee_id
  WHERE sh.status = 'Processed'
  GROUP BY e.dept_id, EXTRACT(YEAR FROM sh.payment_date)
),
yoy AS (
  SELECT dept_id, yr, yearly_amount, LAG(yearly_amount) OVER (PARTITION BY dept_id ORDER BY yr) AS prev_yearly_amount
  FROM dept_yearly_hist
)
SELECT da.dept_id, da.headcount, ROUND(da.total_annual_payroll_approx, 2) AS total_annual_payroll,
       ROUND(100.0 * da.total_annual_payroll_approx / ct.company_payroll, 2) AS pct_of_company_payroll,
       y.yr, ROUND(100.0 * (y.yearly_amount - y.prev_yearly_amount) / NULLIF(y.prev_yearly_amount, 0), 2) AS yoy_growth_pct
FROM dept_annual da
CROSS JOIN company_total ct
LEFT JOIN yoy y ON y.dept_id = da.dept_id
ORDER BY da.dept_id, y.yr;

/* Q42. -- audit.record_changes only tracks employees.salary and products.price in this dataset, so "for each table schema" is answered against exactly those two tracked tables. */
WITH change_counts AS (
  SELECT table_name, COUNT(*) AS change_count FROM audit.record_changes GROUP BY table_name
),
base_counts AS (
  SELECT 'employees' AS table_name, COUNT(*) AS row_count FROM stores.employees
  UNION ALL
  SELECT 'products', COUNT(*) FROM products.products
)
SELECT bc.table_name, bc.row_count, COALESCE(cc.change_count, 0) AS change_count,
       ROUND(COALESCE(cc.change_count, 0)::numeric / NULLIF(bc.row_count, 0), 4) AS change_to_row_ratio,
       (COALESCE(cc.change_count, 0)::numeric / NULLIF(bc.row_count, 0)) >= 0.1 AS adequately_audited
FROM base_counts bc
LEFT JOIN change_counts cc ON cc.table_name = bc.table_name;

/* Q43. */
WITH resolved AS (
  SELECT ticket_id, priority,
         EXTRACT(EPOCH FROM (resolved_date - created_date)) / 3600 AS resolution_hours,
         DATE_TRUNC('month', created_date)::date AS mth
  FROM support.tickets
  WHERE resolved_date IS NOT NULL
),
sla_check AS (
  SELECT *,
         CASE priority
           WHEN 'Critical' THEN resolution_hours <= 4
           WHEN 'High' THEN resolution_hours <= 24
           WHEN 'Medium' THEN resolution_hours <= 72
           WHEN 'Low' THEN resolution_hours <= 168
         END AS within_sla
  FROM resolved
),
monthly_priority AS (
  SELECT priority, mth, AVG(resolution_hours) AS avg_resolution_hours,
         ROUND(100.0 * COUNT(*) FILTER (WHERE within_sla) / COUNT(*), 2) AS pct_within_sla
  FROM sla_check
  GROUP BY priority, mth
)
SELECT priority, mth, ROUND(avg_resolution_hours, 2) AS avg_resolution_hours, pct_within_sla,
       pct_within_sla - LAG(pct_within_sla) OVER (PARTITION BY priority ORDER BY mth) AS sla_trend_vs_prior_month
FROM monthly_priority
ORDER BY priority, mth;

/* Q44. */
WITH cust_cat AS (
  SELECT DISTINCT o.cust_id, cat.category_id, cat.category_name
  FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
)
SELECT a.category_name AS category_a, b.category_name AS category_b,
       COUNT(DISTINCT a.cust_id) AS opportunity_customer_count
FROM cust_cat a
CROSS JOIN (SELECT DISTINCT category_id, category_name FROM cust_cat) b
WHERE a.category_id <> b.category_id
  AND NOT EXISTS (SELECT 1 FROM cust_cat cc WHERE cc.cust_id = a.cust_id AND cc.category_id = b.category_id)
GROUP BY a.category_name, b.category_name
ORDER BY opportunity_customer_count DESC;

/* Q45. */
WITH brand_reviews AS (
  SELECT b.brand_id, AVG(r.rating) AS avg_rating, COUNT(r.review_id) AS review_count
  FROM customers.reviews r
  JOIN products.products p ON p.product_id = r.product_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  GROUP BY b.brand_id
),
brand_price AS (
  SELECT brand_id, AVG(price) AS avg_price FROM products.products GROUP BY brand_id
),
brand_revenue AS (
  SELECT b.brand_id, cat.category_id, SUM(oi.quantity * oi.unit_price) AS brand_revenue
  FROM sales.order_items oi
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
  GROUP BY b.brand_id, cat.category_id
),
cat_revenue AS (
  SELECT cat.category_id, SUM(oi.quantity * oi.unit_price) AS category_revenue
  FROM sales.order_items oi
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
  GROUP BY cat.category_id
),
brand_returns AS (
  SELECT b.brand_id, COUNT(r.return_id) AS return_count, COUNT(DISTINCT oi.order_item_id) AS item_count
  FROM sales.order_items oi
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  LEFT JOIN sales.returns r ON r.prod_id = oi.prod_id AND r.order_id = oi.order_id
  GROUP BY b.brand_id
)
SELECT br.brand_id, ROUND(brv.avg_rating, 2) AS avg_review_rating, brv.review_count,
       ROUND(bp.avg_price, 2) AS avg_price,
       ROUND(100.0 * bre.brand_revenue / NULLIF(cr.category_revenue, 0), 2) AS category_revenue_share_pct,
       ROUND(100.0 * bret.return_count / NULLIF(bret.item_count, 0), 2) AS return_rate_pct,
       ROUND(
         COALESCE(brv.avg_rating, 0) * 20 * 0.4
         + LEAST(100, COALESCE(100.0 * bre.brand_revenue / NULLIF(cr.category_revenue, 0), 0)) * 0.4
         - COALESCE(100.0 * bret.return_count / NULLIF(bret.item_count, 0), 0) * 0.2,
       2) AS health_score
FROM core.dim_brand br
LEFT JOIN brand_reviews brv ON brv.brand_id = br.brand_id
LEFT JOIN brand_price bp ON bp.brand_id = br.brand_id
LEFT JOIN brand_revenue bre ON bre.brand_id = br.brand_id
LEFT JOIN cat_revenue cr ON cr.category_id = bre.category_id
LEFT JOIN brand_returns bret ON bret.brand_id = br.brand_id
ORDER BY health_score DESC NULLS LAST;

/* Q46. */
WITH pv_load AS (
  SELECT EXTRACT(DOW FROM view_timestamp)::int AS dow, EXTRACT(HOUR FROM view_timestamp)::int AS hr, COUNT(*) AS pv_count
  FROM web_events.page_views
  GROUP BY EXTRACT(DOW FROM view_timestamp), EXTRACT(HOUR FROM view_timestamp)
),
call_load AS (
  SELECT EXTRACT(DOW FROM call_start_time)::int AS dow, EXTRACT(HOUR FROM call_start_time)::int AS hr, COUNT(*) AS call_count
  FROM call_center.calls
  GROUP BY EXTRACT(DOW FROM call_start_time), EXTRACT(HOUR FROM call_start_time)
)
SELECT p.dow, p.hr, p.pv_count, c.call_count,
       ROUND(p.pv_count::numeric / NULLIF((SELECT MAX(pv_count) FROM pv_load), 0)
             + c.call_count::numeric / NULLIF((SELECT MAX(call_count) FROM call_load), 0), 4) AS combined_load_index
FROM pv_load p
JOIN call_load c ON c.dow = p.dow AND c.hr = p.hr
ORDER BY combined_load_index DESC
LIMIT 5;

/* Q47. -- an employee belongs to exactly one store, so "their stores" is interpreted as every store in that manager's own store's region; punctuality is approximated as % of attendance days checked in by 09:15. */
WITH region_managers AS (
  SELECT e.employee_id, e.first_name, e.last_name, e.store_id, s.region_id
  FROM stores.employees e
  JOIN stores.stores s ON s.store_id = e.store_id
  WHERE e.role = 'Regional Manager'
),
region_revenue AS (
  SELECT s.region_id, SUM(o.net_total) AS total_revenue,
         COUNT(*) FILTER (WHERE o.order_status = 'Returned')::numeric / NULLIF(COUNT(*), 0) AS avg_return_rate
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  GROUP BY s.region_id
),
region_headcount AS (
  SELECT s.region_id, COUNT(*) AS headcount
  FROM stores.employees e
  JOIN stores.stores s ON s.store_id = e.store_id
  GROUP BY s.region_id
),
region_punctuality AS (
  SELECT s.region_id, ROUND(100.0 * COUNT(*) FILTER (WHERE a.check_in::time <= '09:15:00') / NULLIF(COUNT(*), 0), 2) AS punctuality_pct
  FROM hr.attendance a
  JOIN stores.employees e ON e.employee_id = a.employee_id
  JOIN stores.stores s ON s.store_id = e.store_id
  GROUP BY s.region_id
)
SELECT rm.employee_id, rm.first_name, rm.last_name, rm.region_id,
       rr.total_revenue, ROUND(100.0 * rr.avg_return_rate, 2) AS avg_store_return_rate_pct,
       rp.punctuality_pct AS avg_employee_punctuality_pct, rh.headcount
FROM region_managers rm
LEFT JOIN region_revenue rr ON rr.region_id = rm.region_id
LEFT JOIN region_headcount rh ON rh.region_id = rm.region_id
LEFT JOIN region_punctuality rp ON rp.region_id = rm.region_id
ORDER BY rm.employee_id;

/* Q48. */
WITH monthly_sales AS (
  SELECT oi.prod_id, DATE_TRUNC('month', o.order_date)::date AS mth, SUM(oi.quantity * oi.unit_price) AS revenue
  FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  GROUP BY oi.prod_id, DATE_TRUNC('month', o.order_date)
),
trend AS (
  SELECT prod_id, mth, revenue, LAG(revenue) OVER (PARTITION BY prod_id ORDER BY mth) AS prev_revenue
  FROM monthly_sales
),
classified AS (
  SELECT prod_id, mth,
         CASE WHEN prev_revenue IS NULL THEN NULL
              WHEN revenue > prev_revenue THEN 1
              WHEN revenue < prev_revenue THEN -1
              ELSE 0 END AS direction
  FROM trend
)
SELECT prod_id,
       CASE WHEN AVG(direction) > 0.2 THEN 'Growing'
            WHEN AVG(direction) < -0.2 THEN 'Declining'
            ELSE 'Mature' END AS lifecycle_stage
FROM classified
WHERE direction IS NOT NULL
GROUP BY prod_id
ORDER BY prod_id;

/* Q49. */
WITH member_orders AS (
  SELECT m.customer_id, t.tier_name, m.points_balance,
         COUNT(o.order_id) AS order_count, COALESCE(SUM(o.net_total), 0) AS total_spend
  FROM loyalty.members m
  JOIN loyalty.tiers t ON t.tier_id = m.tier_id
  LEFT JOIN sales.orders o ON o.cust_id = m.customer_id
  GROUP BY m.customer_id, t.tier_name, m.points_balance
),
redemption_stats AS (
  SELECT customer_id, COUNT(*) AS redemption_count FROM loyalty.redemptions GROUP BY customer_id
),
tier_summary AS (
  SELECT mo.tier_name,
         AVG(mo.points_balance) AS avg_points_balance,
         AVG(mo.order_count) AS avg_order_frequency,
         AVG(mo.total_spend) AS avg_total_spend,
         AVG(COALESCE(rs.redemption_count, 0)::numeric / NULLIF(mo.order_count, 0)) AS redemption_rate
  FROM member_orders mo
  LEFT JOIN redemption_stats rs ON rs.customer_id = mo.customer_id
  GROUP BY mo.tier_name
),
non_member AS (
  SELECT AVG(oc.order_count) AS avg_order_frequency, AVG(oc.total_spend) AS avg_total_spend
  FROM (
    SELECT c.customer_id, COUNT(o.order_id) AS order_count, COALESCE(SUM(o.net_total), 0) AS total_spend
    FROM customers.customers c
    LEFT JOIN sales.orders o ON o.cust_id = c.customer_id
    WHERE NOT EXISTS (SELECT 1 FROM loyalty.members m WHERE m.customer_id = c.customer_id)
    GROUP BY c.customer_id
  ) oc
)
SELECT ts.tier_name, ROUND(ts.avg_points_balance, 2) AS avg_points_balance,
       ROUND(ts.avg_order_frequency, 2) AS avg_order_frequency,
       ROUND(ts.avg_total_spend, 2) AS avg_total_spend,
       ROUND(ts.redemption_rate, 4) AS redemption_rate,
       ROUND(ts.avg_order_frequency - nm.avg_order_frequency, 2) AS order_freq_delta_vs_non_member,
       ROUND(ts.avg_total_spend - nm.avg_total_spend, 2) AS spend_delta_vs_non_member
FROM tier_summary ts
CROSS JOIN non_member nm
ORDER BY ts.tier_name;

/* Q50. */
WITH bounds AS (
  SELECT MAX(order_date) AS max_date FROM sales.orders
),
this_week AS (
  SELECT SUM(net_total) AS revenue FROM sales.orders, bounds WHERE order_date > bounds.max_date - 7 AND order_date <= bounds.max_date
),
last_week AS (
  SELECT SUM(net_total) AS revenue FROM sales.orders, bounds WHERE order_date > bounds.max_date - 14 AND order_date <= bounds.max_date - 7
),
mtd AS (
  SELECT SUM(net_total) AS revenue FROM sales.orders, bounds WHERE order_date >= DATE_TRUNC('month', bounds.max_date)::date AND order_date <= bounds.max_date
),
ytd AS (
  SELECT SUM(net_total) AS revenue FROM sales.orders, bounds WHERE order_date >= DATE_TRUNC('year', bounds.max_date)::date AND order_date <= bounds.max_date
),
new_cust AS (
  SELECT COUNT(*) AS new_customers FROM customers.customers, bounds WHERE registration_date > bounds.max_date - 7 AND registration_date <= bounds.max_date
),
top_cat AS (
  SELECT cat.category_name
  FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id, bounds
  WHERE o.order_date > bounds.max_date - 7 AND o.order_date <= bounds.max_date
  GROUP BY cat.category_name
  ORDER BY SUM(oi.quantity * oi.unit_price) DESC
  LIMIT 1
),
top_store AS (
  SELECT s.store_name
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id, bounds
  WHERE o.order_date > bounds.max_date - 7 AND o.order_date <= bounds.max_date
  GROUP BY s.store_name
  ORDER BY SUM(o.net_total) DESC
  LIMIT 1
)
SELECT tw.revenue AS this_week_revenue, lw.revenue AS last_week_revenue,
       ROUND(100.0 * (tw.revenue - lw.revenue) / NULLIF(lw.revenue, 0), 2) AS wow_growth_pct,
       mtd.revenue AS mtd_revenue, ytd.revenue AS ytd_revenue,
       nc.new_customers AS new_customers_this_week,
       tc.category_name AS top_category_this_week,
       ts.store_name AS top_store_this_week
FROM this_week tw, last_week lw, mtd, ytd, new_cust nc, top_cat tc, top_store ts;

/* ============================================================
   SECTION C: PRODUCTION ANALYTICS PATTERNS (25)
   ------------------------------------------------------------ */
/* Q51. -- audit.record_changes only tracks employees.salary and products.price in this dataset (no tier history), so the SCD view uses customers.customers.tier / tier_updated_at directly: valid_from is the last change date, and every row is presented as still-current (valid_to NULL) since no prior-tier history exists to close out. */
SELECT customer_id, tier, tier_updated_at AS valid_from, NULL::timestamp AS valid_to
FROM customers.customers
ORDER BY customer_id;

/* Q52. sales.orders has no load/insert timestamp column (only order_date, the business date), and this is a static, once-seeded dataset - so there is no genuine "inserted in the last 24 hours" signal available in-schema (Postgres system columns like xmin identify a transaction id, not wall-clock time, unless track_commit_timestamp is enabled). Conceptually the pattern is: add a real inserted_at/load_timestamp audit column (populated by the ETL job, not the business date), then WHERE inserted_at >= now() - interval '24 hours' AND order_date < current_date - interval '30 days' flags the late-arriving rows, and re-running the monthly SUM(net_total) with and without those rows isolates their effect on already-reported monthly totals. */

/* Q53. -- a fully generic version needs a PL/pgSQL function iterating information_schema.columns per table; this is a representative hand-written version for three key tables. */
WITH customers_completeness AS (
  SELECT 'customers.customers' AS tbl, COUNT(*) AS total_rows,
         COUNT(*) FILTER (WHERE first_name IS NULL OR last_name IS NULL OR email IS NULL OR phone IS NULL OR registration_date IS NULL OR tier IS NULL) AS rows_with_null
  FROM customers.customers
),
orders_completeness AS (
  SELECT 'sales.orders' AS tbl, COUNT(*) AS total_rows,
         COUNT(*) FILTER (WHERE cust_id IS NULL OR store_id IS NULL OR order_date IS NULL OR order_status IS NULL OR gross_total IS NULL OR net_total IS NULL) AS rows_with_null
  FROM sales.orders
),
products_completeness AS (
  SELECT 'products.products' AS tbl, COUNT(*) AS total_rows,
         COUNT(*) FILTER (WHERE product_name IS NULL OR brand_id IS NULL OR supplier_id IS NULL OR price IS NULL OR cost_price IS NULL) AS rows_with_null
  FROM products.products
)
SELECT tbl, total_rows, rows_with_null,
       ROUND(100.0 * rows_with_null / NULLIF(total_rows, 0), 2) AS pct_rows_with_null,
       ROUND(100.0 - 100.0 * rows_with_null / NULLIF(total_rows, 0), 2) AS completeness_score
FROM (
  SELECT * FROM customers_completeness
  UNION ALL SELECT * FROM orders_completeness
  UNION ALL SELECT * FROM products_completeness
) x
ORDER BY completeness_score;

/* Q54. */
WITH daily_sales AS (
  SELECT oi.prod_id, o.order_date, SUM(oi.quantity) AS qty
  FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  GROUP BY oi.prod_id, o.order_date
),
price_events AS (
  SELECT record_id AS product_id, old_value::numeric AS old_price, new_value::numeric AS new_price, changed_at::date AS change_date
  FROM audit.record_changes
  WHERE table_name = 'products' AND column_name = 'price'
)
SELECT pe.product_id, pe.change_date, pe.old_price, pe.new_price,
       ROUND(100.0 * (pe.new_price - pe.old_price) / NULLIF(pe.old_price, 0), 2) AS price_change_pct,
       SUM(ds.qty) FILTER (WHERE ds.order_date >= pe.change_date - 30 AND ds.order_date < pe.change_date) AS volume_pre,
       SUM(ds.qty) FILTER (WHERE ds.order_date >= pe.change_date AND ds.order_date < pe.change_date + 30) AS volume_post
FROM price_events pe
LEFT JOIN daily_sales ds ON ds.prod_id = pe.product_id AND ds.order_date BETWEEN pe.change_date - 30 AND pe.change_date + 30
GROUP BY pe.product_id, pe.change_date, pe.old_price, pe.new_price
ORDER BY pe.product_id, pe.change_date;

/* Q55. */
WITH ticket_resolved_days AS (
  SELECT DISTINCT customer_id, resolved_date::date AS resolved_day FROM support.tickets WHERE resolved_date IS NOT NULL
),
call_match AS (
  SELECT c.agent_id, c.call_id, c.call_duration_seconds, c.call_start_time,
         (trd.customer_id IS NOT NULL) AS has_matching_resolved_ticket
  FROM call_center.calls c
  LEFT JOIN ticket_resolved_days trd ON trd.customer_id = c.customer_id AND trd.resolved_day = c.call_start_time::date
),
agent_summary AS (
  SELECT agent_id,
         AVG(call_duration_seconds) AS avg_call_duration,
         COUNT(*) AS total_calls,
         COUNT(DISTINCT (call_start_time::date, (EXTRACT(HOUR FROM call_start_time)::int / 8))) AS shift_count,
         ROUND(100.0 * COUNT(*) FILTER (WHERE has_matching_resolved_ticket) / COUNT(*), 2) AS pct_same_day_resolved
  FROM call_match
  GROUP BY agent_id
)
SELECT agent_id, ROUND(avg_call_duration, 2) AS avg_call_duration,
       ROUND(total_calls::numeric / NULLIF(shift_count, 0), 2) AS calls_per_shift,
       pct_same_day_resolved,
       ROUND((100 - avg_call_duration / 6.0) * 0.5 + pct_same_day_resolved * 0.5, 2) AS efficiency_score
FROM agent_summary
ORDER BY efficiency_score DESC;

/* Q56. */
WITH store_revenue AS (
  SELECT store_id, SUM(net_total) AS revenue FROM sales.orders GROUP BY store_id
),
ranked AS (
  SELECT store_id, revenue, RANK() OVER (ORDER BY revenue DESC) AS rnk FROM store_revenue
),
top10_cutoff AS (
  SELECT MIN(revenue) AS cutoff FROM ranked WHERE rnk <= 10
),
prior_period AS (
  SELECT store_id, SUM(net_total) AS prior_revenue
  FROM sales.orders
  WHERE order_date < (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '180 days'
  GROUP BY store_id
)
SELECT r.store_id, r.revenue, r.rnk,
       ROUND(100.0 * (r.revenue - COALESCE(pp.prior_revenue, 0)) / NULLIF(pp.prior_revenue, 0), 2) AS growth_rate_pct,
       ROUND(t.cutoff - r.revenue, 2) AS gap_to_top10_cutoff
FROM ranked r
CROSS JOIN top10_cutoff t
LEFT JOIN prior_period pp ON pp.store_id = r.store_id
WHERE r.rnk BETWEEN 11 AND 30
ORDER BY r.rnk;

/* Q57. */
WITH monthly AS (
  SELECT oi.prod_id, DATE_TRUNC('month', o.order_date)::date AS mth, SUM(oi.quantity) AS units_sold
  FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  GROUP BY oi.prod_id, DATE_TRUNC('month', o.order_date)
),
enriched AS (
  SELECT prod_id, mth, units_sold,
         units_sold / 30.0 AS avg_daily_sold,
         AVG(units_sold) OVER (PARTITION BY prod_id ORDER BY mth ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS trailing_3m_avg,
         AVG(units_sold) OVER (PARTITION BY prod_id ORDER BY mth ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS trailing_12m_avg,
         LAG(units_sold, 12) OVER (PARTITION BY prod_id ORDER BY mth) AS units_sold_last_year
  FROM monthly
)
SELECT prod_id, mth, units_sold, ROUND(avg_daily_sold, 3) AS avg_daily_sold,
       ROUND(trailing_3m_avg, 2) AS trailing_3m_avg, ROUND(trailing_12m_avg, 2) AS trailing_12m_avg,
       ROUND(100.0 * (units_sold - units_sold_last_year) / NULLIF(units_sold_last_year, 0), 2) AS yoy_growth_pct,
       ROUND(trailing_3m_avg, 2) AS naive_forecast_next_month
FROM enriched
ORDER BY prod_id, mth;

/* Q58. */
WITH prod_returns AS (
  SELECT p.product_id, cat.category_id,
         COUNT(DISTINCT oi.order_item_id) AS item_count,
         COUNT(DISTINCT r.return_id) AS return_count
  FROM sales.order_items oi
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
  LEFT JOIN sales.returns r ON r.prod_id = oi.prod_id AND r.order_id = oi.order_id
  GROUP BY p.product_id, cat.category_id
),
rates AS (
  SELECT product_id, category_id, return_count::numeric / NULLIF(item_count, 0) AS return_rate
  FROM prod_returns
),
cat_stats AS (
  SELECT category_id, AVG(return_rate) AS mean_rate, STDDEV(return_rate) AS stddev_rate
  FROM rates
  GROUP BY category_id
)
SELECT r.product_id, r.category_id, ROUND(r.return_rate, 4) AS return_rate,
       ROUND(cs.mean_rate, 4) AS category_mean_rate,
       ROUND((r.return_rate - cs.mean_rate) / NULLIF(cs.stddev_rate, 0), 2) AS z_score
FROM rates r
JOIN cat_stats cs ON cs.category_id = r.category_id
WHERE (r.return_rate - cs.mean_rate) / NULLIF(cs.stddev_rate, 0) > 2
ORDER BY z_score DESC;

/* Q59. -- marketing.email_clicks has no customer-level identifier, so "touches" are matched purely on 30-day date proximity between an order and any campaign's send date, across all campaigns. */
WITH campaign_sends AS (
  SELECT DISTINCT campaign_id, sent_date FROM marketing.email_clicks
),
order_campaigns AS (
  SELECT o.order_id, o.net_total, cs.campaign_id
  FROM sales.orders o
  JOIN campaign_sends cs ON cs.sent_date BETWEEN o.order_date - 30 AND o.order_date
),
order_touch_count AS (
  SELECT order_id, COUNT(DISTINCT campaign_id) AS touch_count FROM order_campaigns GROUP BY order_id
)
SELECT oc.order_id, oc.campaign_id, ROUND(oc.net_total / otc.touch_count, 2) AS attributed_revenue
FROM order_campaigns oc
JOIN order_touch_count otc ON otc.order_id = oc.order_id
ORDER BY oc.order_id, oc.campaign_id;

/* Q60. */
WITH city_revenue AS (
  SELECT s.city, SUM(o.net_total) AS revenue
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  GROUP BY s.city
),
shares AS (
  SELECT city, revenue, revenue / SUM(revenue) OVER () AS share FROM city_revenue
)
SELECT ROUND(SUM(POWER(share, 2)) * 10000, 2) AS hhi
FROM shares;

/* Q61. -- customers.customers stores only the CURRENT tier plus tier_updated_at; there is no historical audit trail of tier transitions (audit.record_changes only tracks employees.salary and products.price in this dataset), so a true tier-to-tier flow between consecutive years cannot be reconstructed. The closest derivable proxy is the distribution of customers by (year their tier was last updated, their current tier): */
SELECT EXTRACT(YEAR FROM tier_updated_at)::int AS tier_change_year, tier, COUNT(*) AS customer_count
FROM customers.customers
WHERE tier_updated_at IS NOT NULL
GROUP BY EXTRACT(YEAR FROM tier_updated_at), tier
ORDER BY tier_change_year, tier;

/* Q62. */
WITH weekly_demand AS (
  SELECT oi.prod_id, DATE_TRUNC('week', o.order_date)::date AS wk, SUM(oi.quantity) AS demand_qty
  FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  GROUP BY oi.prod_id, DATE_TRUNC('week', o.order_date)
),
weekly_supply AS (
  SELECT product_id AS prod_id, DATE_TRUNC('week', shipped_date)::date AS wk, SUM(quantity) AS supply_qty
  FROM supply_chain.shipments
  GROUP BY product_id, DATE_TRUNC('week', shipped_date)
),
demand_cv AS (
  SELECT prod_id, STDDEV(demand_qty) / NULLIF(AVG(demand_qty), 0) AS demand_cv FROM weekly_demand GROUP BY prod_id
),
supply_cv AS (
  SELECT prod_id, STDDEV(supply_qty) / NULLIF(AVG(supply_qty), 0) AS supply_cv FROM weekly_supply GROUP BY prod_id
)
SELECT COALESCE(d.prod_id, s.prod_id) AS prod_id,
       ROUND(d.demand_cv, 4) AS demand_cv, ROUND(s.supply_cv, 4) AS supply_cv,
       ROUND(s.supply_cv - d.demand_cv, 4) AS bullwhip_gap
FROM demand_cv d
FULL OUTER JOIN supply_cv s ON s.prod_id = d.prod_id
ORDER BY bullwhip_gap DESC NULLS LAST;

/* Q63. -- order_date is a date (no timestamp), so "last 24 hours" is approximated as orders on the most recent order_date present in the data. */
WITH recent_orders AS (
  SELECT order_id, cust_id, net_total FROM sales.orders WHERE order_date = (SELECT MAX(order_date) FROM sales.orders)
)
SELECT ro.order_id,
       NOT EXISTS (SELECT 1 FROM sales.order_items oi WHERE oi.order_id = ro.order_id) AS missing_items,
       NOT EXISTS (SELECT 1 FROM sales.shipments sh WHERE sh.order_id = ro.order_id) AS missing_shipment,
       NOT EXISTS (SELECT 1 FROM finance.payments p WHERE p.order_id = ro.order_id) AS missing_payment
FROM recent_orders ro
WHERE NOT EXISTS (SELECT 1 FROM sales.order_items oi WHERE oi.order_id = ro.order_id)
   OR NOT EXISTS (SELECT 1 FROM sales.shipments sh WHERE sh.order_id = ro.order_id)
   OR NOT EXISTS (SELECT 1 FROM finance.payments p WHERE p.order_id = ro.order_id)
ORDER BY ro.order_id;

/* Q64. */
WITH target AS (
  SELECT 1001 AS customer_id
),
cust_orders AS (
  SELECT o.order_id, o.order_date, o.net_total
  FROM sales.orders o, target t
  WHERE o.cust_id = t.customer_id
  ORDER BY o.order_date DESC
  LIMIT 3
),
cust_metrics AS (
  SELECT COUNT(*) AS total_orders, SUM(net_total) AS lifetime_value
  FROM sales.orders o, target t WHERE o.cust_id = t.customer_id
),
recent_pv AS (
  SELECT pv.view_id, pv.page_url, pv.view_timestamp
  FROM web_events.page_views pv, target t
  WHERE pv.customer_id = t.customer_id
  ORDER BY pv.view_timestamp DESC
  LIMIT 5
)
SELECT jsonb_build_object(
  'customer_id', c.customer_id, 'name', c.first_name || ' ' || c.last_name, 'email', c.email,
  'loyalty_tier', c.tier,
  'lifetime_value', cm.lifetime_value,
  'total_orders', cm.total_orders,
  'last_3_orders', (SELECT jsonb_agg(jsonb_build_object('order_id', order_id, 'order_date', order_date, 'net_total', net_total)) FROM cust_orders),
  'open_tickets', (SELECT jsonb_agg(jsonb_build_object('ticket_id', ticket_id, 'priority', priority, 'status', status))
                    FROM support.tickets t2, target tg WHERE t2.customer_id = tg.customer_id AND t2.status NOT IN ('Resolved', 'Closed')),
  'recent_web_events', (SELECT jsonb_agg(jsonb_build_object('view_id', view_id, 'page_url', page_url, 'view_timestamp', view_timestamp)) FROM recent_pv)
) AS customer_360_profile
FROM customers.customers c
JOIN target t ON t.customer_id = c.customer_id
CROSS JOIN cust_metrics cm;

/* Q65. -- products.promotions has no product/category linkage column, so "promotion active" is treated system-wide by date range rather than per-product; lift compares avg daily category revenue during vs outside any active promotion window. */
WITH promo_periods AS (
  SELECT promo_id, start_date, end_date FROM products.promotions WHERE active = true
),
order_revenue AS (
  SELECT cat.category_name, o.order_date, SUM(oi.quantity * oi.unit_price) AS revenue
  FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
  GROUP BY cat.category_name, o.order_date
),
flagged AS (
  SELECT orv.category_name, orv.revenue,
         EXISTS (SELECT 1 FROM promo_periods pp WHERE orv.order_date BETWEEN pp.start_date AND pp.end_date) AS during_promo
  FROM order_revenue orv
)
SELECT category_name,
       SUM(revenue) FILTER (WHERE during_promo) AS revenue_during_promo,
       SUM(revenue) FILTER (WHERE NOT during_promo) AS revenue_without_promo,
       ROUND(100.0 * (AVG(revenue) FILTER (WHERE during_promo) - AVG(revenue) FILTER (WHERE NOT during_promo))
             / NULLIF(AVG(revenue) FILTER (WHERE NOT during_promo), 0), 2) AS lift_pct
FROM flagged
GROUP BY category_name
ORDER BY category_name;

/* Q66. -- hr.attendance only has rows for days actually attended (no explicit absent marker), so "% days absent" uses the org-wide set of distinct attendance dates as the expected working calendar. */
WITH calendar AS (
  SELECT COUNT(DISTINCT attendance_date) AS working_days FROM hr.attendance
),
emp_attendance AS (
  SELECT employee_id, COUNT(DISTINCT attendance_date) AS days_present FROM hr.attendance GROUP BY employee_id
),
dept_salary AS (
  SELECT employee_id, dept_id, salary, PERCENT_RANK() OVER (PARTITION BY dept_id ORDER BY salary) AS salary_percentile
  FROM stores.employees
),
salary_growth AS (
  SELECT employee_id, EXTRACT(YEAR FROM payment_date)::int AS yr, SUM(amount) AS yearly_amount
  FROM hr.salary_history
  WHERE status = 'Processed'
  GROUP BY employee_id, EXTRACT(YEAR FROM payment_date)
),
growth_calc AS (
  SELECT employee_id, yr, yearly_amount, LAG(yearly_amount) OVER (PARTITION BY employee_id ORDER BY yr) AS prev_amount
  FROM salary_growth
),
latest_growth AS (
  SELECT DISTINCT ON (employee_id) employee_id,
         ROUND(100.0 * (yearly_amount - prev_amount) / NULLIF(prev_amount, 0), 2) AS salary_growth_rate_pct
  FROM growth_calc
  WHERE prev_amount IS NOT NULL
  ORDER BY employee_id, yr DESC
)
SELECT ea.employee_id,
       ROUND(100.0 * (1 - ea.days_present::numeric / c.working_days), 2) AS pct_days_absent,
       ROUND(ds.salary_percentile::numeric, 4) AS salary_percentile_in_dept,
       lg.salary_growth_rate_pct,
       (100.0 * (1 - ea.days_present::numeric / c.working_days) > 20 AND COALESCE(lg.salary_growth_rate_pct, 0) < 3) AS at_risk_flag
FROM emp_attendance ea
CROSS JOIN calendar c
JOIN dept_salary ds ON ds.employee_id = ea.employee_id
LEFT JOIN latest_growth lg ON lg.employee_id = ea.employee_id
ORDER BY at_risk_flag DESC, pct_days_absent DESC;

/* Q67. */
WITH cust_cat AS (
  SELECT o.cust_id, cat.category_id, COUNT(*) AS purchase_frequency, SUM(oi.quantity * oi.unit_price) AS total_spend
  FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
  GROUP BY o.cust_id, cat.category_id
),
cat_popularity AS (
  SELECT cat.category_id, cat.category_name, SUM(oi.quantity * oi.unit_price) AS category_revenue
  FROM sales.order_items oi
  JOIN products.products p ON p.product_id = oi.prod_id
  JOIN core.dim_brand b ON b.brand_id = p.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
  GROUP BY cat.category_id, cat.category_name
),
not_purchased AS (
  SELECT c.customer_id, cp.category_name, cp.category_revenue,
         ROW_NUMBER() OVER (PARTITION BY c.customer_id ORDER BY cp.category_revenue DESC) AS rn
  FROM customers.customers c
  CROSS JOIN cat_popularity cp
  WHERE NOT EXISTS (SELECT 1 FROM cust_cat cc WHERE cc.cust_id = c.customer_id AND cc.category_id = cp.category_id)
)
SELECT customer_id, category_name AS recommended_category, rn AS recommendation_rank
FROM not_purchased
WHERE rn <= 3
ORDER BY customer_id, rn;

/* Q68. */
WITH daily AS (
  SELECT order_date, COUNT(*) AS order_count, SUM(net_total) AS revenue,
         COUNT(*) FILTER (WHERE order_status = 'Returned') AS returns
  FROM sales.orders
  GROUP BY order_date
),
avg_daily AS (
  SELECT AVG(order_count) AS avg_order_count FROM daily
),
flash_days AS (
  SELECT d.order_date, d.order_count, d.revenue, d.returns
  FROM daily d, avg_daily a
  WHERE d.order_count > 3 * a.avg_order_count
),
ticket_daily AS (
  SELECT created_date::date AS tdate, COUNT(*) AS ticket_count FROM support.tickets GROUP BY created_date::date
)
SELECT fd.order_date, fd.order_count, fd.revenue AS incremental_revenue,
       ROUND(100.0 * fd.returns / NULLIF(fd.order_count, 0), 2) AS return_rate_pct,
       COALESCE(td.ticket_count, 0) AS support_ticket_count
FROM flash_days fd
LEFT JOIN ticket_daily td ON td.tdate = fd.order_date
ORDER BY fd.order_count DESC;

/* Q69. -- supply_chain.shipments has no expected-delivery column, but its status='Delayed' flag is a direct SLA-breach signal. */
WITH supplier_shipments AS (
  SELECT supplier_id, COUNT(*) AS total_shipments,
         COUNT(*) FILTER (WHERE status <> 'Delayed') AS on_time_shipments,
         STDDEV(arrival_date - shipped_date) AS lead_time_stddev
  FROM supply_chain.shipments
  GROUP BY supplier_id
),
supplier_defects AS (
  SELECT p.supplier_id, COUNT(DISTINCT oi.order_item_id) AS item_count, COUNT(DISTINCT r.return_id) AS return_count
  FROM sales.order_items oi
  JOIN products.products p ON p.product_id = oi.prod_id
  LEFT JOIN sales.returns r ON r.prod_id = oi.prod_id AND r.order_id = oi.order_id
  GROUP BY p.supplier_id
)
SELECT sup.supplier_id, sup.supplier_name,
       ROUND(100.0 * ss.on_time_shipments / NULLIF(ss.total_shipments, 0), 2) AS on_time_delivery_rate_pct,
       ROUND(100.0 * sd.return_count / NULLIF(sd.item_count, 0), 2) AS defect_rate_pct,
       ROUND(ss.lead_time_stddev, 2) AS lead_time_variability_days,
       ROUND(
         (100.0 * ss.on_time_shipments / NULLIF(ss.total_shipments, 0)) * 0.5
         - (100.0 * sd.return_count / NULLIF(sd.item_count, 0)) * 0.3
         - COALESCE(ss.lead_time_stddev, 0) * 2,
       2) AS reliability_score
FROM products.suppliers sup
LEFT JOIN supplier_shipments ss ON ss.supplier_id = sup.supplier_id
LEFT JOIN supplier_defects sd ON sd.supplier_id = sup.supplier_id
ORDER BY reliability_score DESC NULLS LAST;

/* Q70. -- no literal 'COD' payment mode exists; 'Cash' is used as the closest proxy per finance.payment_modes. */
SELECT o.order_id, o.cust_id, o.net_total, pm.mode_name
FROM sales.orders o
JOIN finance.payment_modes pm ON pm.mode_id = o.payment_mode_id
WHERE pm.mode_name = 'Cash'
  AND NOT EXISTS (SELECT 1 FROM finance.payments p WHERE p.order_id = o.order_id)
ORDER BY o.order_id;

/* Q71. */
WITH latest_snap AS (
  SELECT DISTINCT ON (warehouse_id, product_id) warehouse_id, product_id, quantity_on_hand
  FROM supply_chain.inventory_snapshots
  ORDER BY warehouse_id, product_id, snapshot_date DESC
)
SELECT ls.warehouse_id, ls.product_id, ls.quantity_on_hand, p.cost_price,
       ROUND(ls.quantity_on_hand * p.cost_price, 2) AS capital_tied_up
FROM latest_snap ls
JOIN products.products p ON p.product_id = ls.product_id
WHERE NOT EXISTS (
  SELECT 1 FROM sales.order_items oi JOIN sales.orders o ON o.order_id = oi.order_id
  WHERE oi.prod_id = ls.product_id AND o.order_date >= (SELECT MAX(order_date) FROM sales.orders) - INTERVAL '120 days'
)
ORDER BY capital_tied_up DESC;

/* Q72. */
WITH campaign_spend AS (
  SELECT campaign_id, SUM(amount) AS total_spend FROM marketing.ads_spend GROUP BY campaign_id
),
campaign_revenue AS (
  SELECT mc.campaign_id, SUM(o.net_total) AS revenue
  FROM marketing.campaigns mc
  JOIN sales.orders o ON o.order_date >= mc.start_date AND o.order_date < mc.start_date + 7
  GROUP BY mc.campaign_id
)
SELECT cr.campaign_id, cs.total_spend, cr.revenue,
       ROUND((cr.revenue - cs.total_spend) / NULLIF(cs.total_spend, 0), 4) AS roi,
       ROUND(cs.total_spend / NULLIF(cr.revenue / 7.0, 0), 1) AS payback_days
FROM campaign_revenue cr
JOIN campaign_spend cs ON cs.campaign_id = cr.campaign_id
ORDER BY roi DESC NULLS LAST;

/* Q73. -- support.tickets has no product/order link, so "per product category" is adapted to the ticket's own category field (Login Issue, Product Defect, etc.), the only category dimension tickets carry. */
SELECT category,
       COUNT(*) AS total_tickets,
       COUNT(*) FILTER (WHERE LENGTH(subject) > 100) AS detailed_tickets,
       ROUND(100.0 * COUNT(*) FILTER (WHERE LENGTH(subject) > 100) / COUNT(*), 2) AS pct_detailed
FROM support.tickets
GROUP BY category
ORDER BY pct_detailed DESC;

/* Q74. */
WITH spend_2024 AS (
  SELECT cust_id, SUM(net_total) AS total_2024
  FROM sales.orders
  WHERE EXTRACT(YEAR FROM order_date) = 2024
  GROUP BY cust_id
  HAVING SUM(net_total) > 10000
),
orders_2025 AS (
  SELECT DISTINCT cust_id FROM sales.orders WHERE EXTRACT(YEAR FROM order_date) = 2025
)
SELECT s.cust_id, s.total_2024
FROM spend_2024 s
WHERE NOT EXISTS (SELECT 1 FROM orders_2025 o2025 WHERE o2025.cust_id = s.cust_id)
ORDER BY s.total_2024 DESC;

/* Q75. */
WITH hourly AS (
  SELECT EXTRACT(HOUR FROM call_start_time)::int AS call_hour,
         COUNT(*) AS total_calls,
         COUNT(*) FILTER (WHERE call_duration_seconds < 30) AS abandoned_calls
  FROM call_center.calls
  GROUP BY EXTRACT(HOUR FROM call_start_time)
)
SELECT call_hour, total_calls, abandoned_calls,
       ROUND(100.0 * abandoned_calls / NULLIF(total_calls, 0), 2) AS abandoned_rate_pct
FROM hourly
ORDER BY abandoned_rate_pct DESC
LIMIT 3;

/* ============================================================
   SECTION D: ARCHITECTURE & SYSTEM DESIGN (25)
   ------------------------------------------------------------ */
/* Q76. Materialize the joins/aggregations that are expensive and queried repeatedly with the same shape: mv_daily_revenue (orders by day/store/region, refreshed daily after close-of-day load), mv_customer_rfm (recency/frequency/monetary scores, refreshed nightly), mv_product_performance (order_items joined to products/category with revenue/margin, refreshed nightly), and mv_cohort_retention (signup-cohort x period matrix, refreshed weekly since cohort cells barely move day to day). Supporting indexes on the base tables target exactly what these MVs' own refresh queries filter/join/group by: sales.orders(order_date), sales.orders(cust_id), sales.order_items(prod_id), stores.stores(region_id). */

/* Q77. Raw layer: v_raw_orders, v_raw_order_items, v_raw_customers - thin 1:1 wrappers over the base tables. Cleansed layer: v_clean_orders (raw orders with invalid/test rows filtered, status normalized), v_clean_customers (dedup'd, malformed emails filtered), v_clean_order_items (joined to v_clean_orders so only valid orders' items remain) - each depends only on its raw-layer counterpart. Aggregated layer: v_agg_monthly_revenue (from v_clean_orders, grouped by month/store), v_agg_customer_metrics (from v_clean_orders, grouped by customer) - each depends on the cleansed layer. Business-metric layer: v_metric_rfm_segments (built on v_agg_customer_metrics), v_metric_store_scorecard (built on v_agg_monthly_revenue joined to stores) - the layer analysts actually query, each depending only on the layer directly beneath it. */

/* Q78. Benefits: date-range queries prune to only the relevant monthly partitions (far less I/O), each partition's indexes stay small and fast to (re)build/vacuum, and old months can be detached/archived as a cheap metadata operation instead of a slow bulk DELETE. Risks: any UNIQUE/PRIMARY KEY constraint must include the partition key (order_date) alongside order_id, foreign keys referencing sales.orders(order_id) from other tables get more complex, and queries that don't filter on order_date at all (a raw order_id lookup) must scan every partition unless a workaround index exists. Existing queries mostly keep working unchanged since the parent table name doesn't change, but anything relying on the old single-relation OID, or doing DDL directly "on the table," needs to account for per-partition objects underneath it now. */

/* Q79. The migration runs in a loop of small batches, each its own short transaction: WITH deleted AS (DELETE FROM sales.orders WHERE order_id IN (SELECT order_id FROM sales.orders WHERE order_date < CURRENT_DATE - INTERVAL '3 years' LIMIT 5000) RETURNING *) INSERT INTO sales.orders_archive SELECT * FROM deleted; - re-invoked repeatedly until a run deletes 0 rows. Batching keeps each transaction's lock time and WAL/rollback-segment growth bounded instead of one multi-hour DELETE that locks the whole table and risks a huge rollback if it fails partway through; because each batch commits independently, a failure only needs to resume from where it left off, not restart the whole migration. (Shown here as an illustrative pattern rather than executed, since it is a real DELETE against a live orders table and sales.orders_archive does not exist in this schema.) */

/* Q80. Any MV that has (or can be given) at least one UNIQUE index covering all its rows - e.g. mv_customer_rfm keyed by customer_id, mv_product_performance keyed by product_id - can use REFRESH MATERIALIZED VIEW CONCURRENTLY, avoiding the ACCESS EXCLUSIVE lock a plain REFRESH takes. MVs that can't have a UNIQUE index - typically ones whose grain includes a non-unique or ranked column (e.g. "top 10 products per category" where the natural key isn't unique across refreshes) - must either be restructured so their SELECT list has a genuinely unique key, or accept the plain-REFRESH lock and schedule it for a low-traffic window, or refresh into a differently-named staging MV and atomically rename it in place of the live one (no lock on the live name until the final rename). */

/* Q81. A recompute is triggered by any event that changes a customer's recency/frequency/monetary inputs - a new row in sales.orders or sales.returns; AFTER INSERT/UPDATE triggers on those two tables don't recompute inline (too slow per-row) but instead INSERT the affected customer_id into a lightweight refresh_queue table (customer_id, queued_at) with ON CONFLICT DO NOTHING so repeated events for the same customer collapse into one pending entry. A separate scheduled job (or a LISTEN/NOTIFY-driven worker) periodically DELETEs a batch of queued customer_ids, recomputes their RFM scores in one set-based UPDATE, and clears them from the queue - decoupling the cheap trigger-time work from the more expensive recompute. */

/* Q82. A nightly job runs a CTE chain: a CTE selecting yesterday's qualifying orders joined to campaigns active in the attribution window, a CTE computing the attributed revenue split per campaign, then INSERT INTO campaign_attribution SELECT ... FROM that final CTE. Idempotency against double-counting on a retried run is enforced either by DELETE FROM campaign_attribution WHERE attribution_date = <yesterday> immediately before the INSERT (a re-run replaces rather than appends), or by a UNIQUE constraint on (campaign_id, order_id, attribution_date) with INSERT ... ON CONFLICT DO NOTHING so a duplicate row from a retried run is silently absorbed instead of double-inserted. */

/* Q83. A data contract for sales.orders: NOT NULL on cust_id, store_id, order_date, order_status (a row missing any of these isn't a valid order); a CHECK constraint restricting order_status to its known enumerated values; CHECK constraints enforcing gross_total >= 0, net_total >= 0, discount_amount >= 0, and net_total <= gross_total (a discounted total can never exceed the pre-discount total); the existing FOREIGN KEY constraints (cust_id -> customers.customers, store_id -> stores.stores, payment_mode_id -> finance.payment_modes) and the order_id PRIMARY KEY already enforce referential integrity and uniqueness, so no additional UNIQUE constraint is needed. Each of these can be added with NOT VALID first (instant) and VALIDATE CONSTRAINT run separately afterward to avoid a long lock while checking 150k existing rows all at once. */

/* Q84. Range-partition web_events.page_views by month on view_timestamp so the daily job's date-range filter prunes to 1-2 partitions instead of scanning the full 500k+ rows; add a BRIN index on view_timestamp within each partition (cheap to maintain on an insert-ordered column, and partition pruning already narrows most of the scan so BRIN's coarse granularity is fine for what's left); and ensure max_parallel_workers_per_gather is high enough (with parallel-safe aggregations) so Postgres can split the remaining per-partition scan/aggregate across worker processes - between partition pruning cutting scanned volume by roughly the partition count and parallel workers dividing what remains, a 45-minute job should drop to a small fraction of that. */

/* Q85. Run EXPLAIN (ANALYZE, BUFFERS) on the full query and look for: (1) any node where "actual rows" wildly diverges from the planner's "rows" estimate - stale statistics driving a bad plan; (2) Nested Loop nodes with a very high loop count feeding a Seq Scan - usually a missing index on the inner side; (3) Sort or Hash nodes reporting disk usage - work_mem too small, spilling; (4) which single node has the largest actual-time delta between its own start and its children's - the true bottleneck, not necessarily the top-level cost. Fixes follow directly: ANALYZE tables with bad estimates, add indexes on the join/filter columns driving loops, or raise work_mem to avoid a disk spill. */

/* Q86. Add a tier_history table (customer_id, tier, valid_from timestamp, valid_to timestamp NULL) rather than overwriting tier in place; on every tier change, UPDATE the current open row SET valid_to = now() WHERE customer_id = X AND valid_to IS NULL, then INSERT a new row (customer_id, new_tier, valid_from = now(), valid_to = NULL), both inside one transaction. Querying "tier as of date D" becomes SELECT tier FROM tier_history WHERE customer_id = X AND valid_from <= D AND (valid_to IS NULL OR valid_to > D). */

/* Q87. -- finance.payments has no date column of its own, so its month is derived via the linked order's order_date; finance.accounts is a general ledger of account holders with no natural per-order/monthly linkage, so it's excluded from this comparison. */
WITH order_totals AS (
  SELECT DATE_TRUNC('month', order_date)::date AS mth, SUM(net_total) AS orders_total
  FROM sales.orders
  GROUP BY DATE_TRUNC('month', order_date)
),
payment_totals AS (
  SELECT DATE_TRUNC('month', o.order_date)::date AS mth, SUM(p.amount) AS payments_total
  FROM finance.payments p
  JOIN sales.orders o ON o.order_id = p.order_id
  WHERE p.status = 'Completed'
  GROUP BY DATE_TRUNC('month', o.order_date)
)
SELECT ot.mth, ot.orders_total, COALESCE(pt.payments_total, 0) AS payments_total,
       ROUND(ot.orders_total - COALESCE(pt.payments_total, 0), 2) AS orders_vs_payments_gap
FROM order_totals ot
LEFT JOIN payment_totals pt ON pt.mth = ot.mth
ORDER BY ot.mth;
/* If discrepancies are found, the standard next step is drilling into the specific order_ids in that month with no matching Completed payment (or vice versa) to classify each as a timing difference, a failed/refunded payment, or a genuine data-integrity gap. */

/* Q88. Five highest-impact indexes for RetailMart's analytics workload: (1) sales.orders(order_date) B-tree - every date-range revenue/report query; (2) sales.orders(cust_id) B-tree - per-customer lookups/joins (RFM, lifetime value, lateral top-N); (3) sales.order_items(order_id) B-tree - the near-universal orders-to-items join; (4) sales.orders(order_date) WHERE order_status = 'Processing' partial B-tree - tiny and fast for frequent "currently processing" operational queries; (5) web_events.page_views(view_timestamp) BRIN - large, naturally insert-ordered by time, typically filtered by a wide date range. */

/* Q89. A stored monthly_revenue table gives instant reads (no join/aggregation at query time) and insulates dashboards from sales.orders growing larger over time, at the cost of a refresh/ETL step that must run reliably and of staleness between refreshes. Computing it on demand from sales.orders is always exactly correct as of "now" with zero maintenance pipeline, but re-pays the full aggregation cost on every query. Pre-aggregation breaks down when consumers need finer granularity than what was pre-aggregated (daily or per-store detail the monthly rollup discarded), when source data can be corrected/backdated after the rollup already ran (it silently goes stale until manually reprocessed), or when so many different slice/dice combinations are needed that maintaining a pre-aggregate for each one costs more than the on-demand query ever would have. */

/* Q90. Without installing pg_stat_statements (an extension), audit.api_requests already captures request_id, timestamp, endpoint, method, status_code and response_time_ms per call - if the application includes the analyst's identity in the endpoint/user_agent (or a dedicated column), that table alone gives a per-analyst audit trail with no extra setup: */
SELECT endpoint, method, COUNT(*) AS request_count, ROUND(AVG(response_time_ms), 2) AS avg_response_time_ms
FROM audit.api_requests
GROUP BY endpoint, method
ORDER BY request_count DESC;
/* If deeper SQL-level tracking is needed (the literal query text, not just the API endpoint), pg_stat_statements does track normalized query text and execution stats, but it's an actual extension (CREATE EXTENSION pg_stat_statements), so it doesn't satisfy the "without installing extensions" constraint - audit.api_requests is the approach available today, at the cost of only knowing which endpoint was hit, not the exact SQL that ran. */

/* Q91. A reset script iterates pg_tables/pg_views/pg_matviews/pg_indexes WHERE schemaname = 'public' only and dynamically DROPs each object CASCADE (via a DO $$ ... EXECUTE 'DROP TABLE IF EXISTS public.' || quote_ident(name) || ' CASCADE' $$ block, similarly for views/matviews/indexes) - scoping everything to schemaname = 'public' means the 16 RetailMart V3 schemas (sales, customers, products, etc.) and their tables/views/indexes are never touched regardless of what a student created there. (Shown here as an illustrative design rather than executed, since running dynamic DROP CASCADE against a live shared database's public schema is exactly the kind of destructive operation this answer key avoids actually performing.) */

/* Q92. Every additional index on sales.order_items means every INSERT (and any UPDATE touching an indexed column) must also write an entry into each index, and every DELETE must eventually clean an entry out of each - so N indexes roughly multiply the write-side I/O/WAL cost of each row change by up to N+1, which matters at 374k-rows-and-growing insert load. The two indexes worth keeping are order_id (needed for practically every orders-to-items join, the single most common access pattern) and prod_id (needed for practically every product-level rollup/analytics query) - any additional index should be justified against this write cost rather than added by default. */

/* Q93. Two approaches: (1) a masking view - v_salary_analysis AS SELECT dept_id, salary FROM stores.employees (deliberately omitting employee_id, first_name, last_name, email) - with the HR analytics role granted SELECT only on the view and direct table access revoked, so no query against it can ever surface an individual's identity. (2) Row-Level Security via CREATE POLICY on stores.employees restricting which rows a role can see (e.g. only their own department), combined with a mandatory column-level restriction since RLS alone doesn't hide columns - RLS suits cases where different roles need different row subsets, while a masking view is simpler and sufficient when the requirement is purely "never expose identity columns," which is the case here. */

/* Q94. A canary query runs a handful of cheap, fast sanity checks in one script: (1) freshness - SELECT MAX(order_date) FROM sales.orders should be yesterday or later, confirming new data arrived; (2) volume sanity - COUNT(*) for yesterday's order_date should fall within a historically expected range (not zero, not 100x a typical day), catching a partial or duplicated load; (3) FK integrity - a quick NOT EXISTS check that every new order's cust_id/store_id exists in customers.customers/stores.stores, catching a load that ran before its dependent dimension tables; (4) a spot NULL check on required columns (net_total, order_status) for yesterday's rows. Any one failing raises an alert before analysts build on top of bad data. */

/* Q95. Investigation sequence: (1) check pg_stat_user_indexes for support.tickets - an index with near-zero scans relative to table size means queries aren't using it; (2) EXPLAIN ANALYZE the actual slow queries to see whether they're doing Seq Scans where an Index Scan would help, and whether row estimates match reality; (3) create the missing index(es) matching the queries' real WHERE/ORDER BY columns (e.g. (customer_id, created_date) if that's the common filter/sort); (4) VACUUM ANALYZE support.tickets afterward so the visibility map and statistics reflect the now-12-months-larger table, letting the planner's estimates (and index-only-scan eligibility) catch up. */

/* Q96. Each tenant gets its own schema (tenant_acme, tenant_globex, ...) holding identical table structures, all sharing one instance/database; a session sets search_path = tenant_acme, public so unqualified table names resolve to that tenant's schema without changing application SQL. Isolation issues: a missing search_path reset on a pooled connection can leak one tenant's session settings into the next tenant's queries (dangerous with connection poolers reusing backend connections across tenants); schema-per-tenant means N schemas of DDL to keep in sync on every migration, and per-tenant statistics/vacuum housekeeping multiplies with tenant count; and search_path is a convenience default, not a security boundary - a role with cross-schema query rights can still reach another tenant's schema by fully qualifying it unless permissions are separately locked down per-schema. */

/* Q97. Adding a NOT NULL column with a constant default is a fast, metadata-only change in Postgres 11+ (no longer rewrites the table), so the classic full-table-rewrite risk is already avoided for a simple constant default; for anything more involved, add the column as nullable with no default first (instant), backfill its value in small batched UPDATEs (each its own short transaction, not locking the whole table), and only once every row is backfilled add the NOT NULL constraint (fast if a NOT VALID CHECK was added and VALIDATEd separately beforehand). "Blue-green" here means the new column stays invisible/unused by the old application version until the rollout flips reads/writes to code that expects it, so old and new code coexist mid-migration without a single long blocking operation. */

/* Q98. pgcrypto (pgp_sym_encrypt/pgp_sym_decrypt) encrypts the value inside the database - simple to retrofit and the key never has to leave Postgres if handled via a secured function, but every query needs to call the decrypt function explicitly (WHERE email = 'x' no longer works directly - equality search needs a separate deterministic hash column), and the key material still lives somewhere the database can reach it, a smaller blast-radius improvement than true end-to-end encryption. Application-level encryption keeps the key entirely outside the database (stronger separation of duties - a DB-only breach doesn't expose plaintext), but requires every service touching email to implement it consistently, complicates ad-hoc SQL/reporting access, and any DB-side use of the column (join, filter, index) needs the same deterministic-hash-column workaround as the pgcrypto approach. */

/* Q99. pg_stat_statements tracks rows (and shared_blks_read/hit) per normalized query, attributable to whichever role executed it if each analyst connects under their own role; a scheduled job periodically sums today's rows across an analyst's queries into a daily_query_usage table (analyst_id, usage_date, rows_scanned) via an UPSERT that adds each interval's delta. Before running a new query, a lightweight check (a login trigger, a connection-pooler hook, or the app layer) looks up today's running total for that analyst and refuses/warns if it's already at or over 10,000,000 - since pg_stat_statements can't pre-emptively block a query from inside SQL itself, real enforcement also typically needs a statement_timeout/row-limit safeguard or an external gatekeeper, with pg_stat_statements as the source of truth for measuring usage rather than the enforcement mechanism itself. */

/* Q100. Ten patterns worth explaining in under 2 minutes each, with the RetailMart query that best demonstrates it: (1) window-function top-N-per-group (ROW_NUMBER/RANK PARTITION BY) - "top 3 products by revenue per category" (this topic, hard Q28); (2) DISTINCT ON for latest-record dedup - latest-payment-status-per-order patterns used throughout topics 22/25; (3) the correlated-subquery-to-JOIN rewrite for performance - mv_customer_360 (topic 25); (4) RFM scoring with NTILE - "full RFM model with segment labels" (this topic, hard Q52); (5) cohort retention with a period-index CTE - "cohort retention matrix" (this topic, Q29/Q62); (6) gaps-and-islands via LAG-based streak detection - mv_inventory_stockout_streaks (topic 25 hard); (7) PERCENTILE_CONT for medians/IQR outlier detection - "IQR outlier flagging per category" (this topic, hard Q56); (8) the NOT IN vs NOT EXISTS NULL trap and its safe rewrite - this topic's Q1/Q3; (9) materialized view + CONCURRENTLY refresh + a supporting unique index, as one coherent unit - topic 25's mv_* pattern; (10) CTE-chain pipelines building raw -> cleaned -> aggregated -> business-metric layers - topic 25's v_raw_/v_core_/v_mart_/v_exec_ semantic layer and this topic's "customer lifecycle dashboard" (Q26). */
