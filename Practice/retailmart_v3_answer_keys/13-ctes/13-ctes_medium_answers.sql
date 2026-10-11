/* ============================================================
   ANSWER KEY - CTEs (WITH, non-recursive) (MEDIUM LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: DEEPER CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1.  Inlining helps when the CTE is used once and outer predicates can be pushed down into it (smaller scan); it hurts when the CTE is expensive and referenced multiple times, since inlining recomputes it fully for every reference instead of once. */
/* Q2.  Forcing MATERIALIZED avoids recomputing an expensive CTE's logic for every reference - PostgreSQL pays the cost once and reads the buffered rows for each subsequent use. */
/* Q3.  It re-executes (recomputes) an inlined CTE (auto-inlined or NOT MATERIALIZED) once per reference in the outer query, because inlining literally substitutes the CTE's SQL wherever it appears. */
/* Q4.  An index on a base table still applies inside a CTE's inner SELECT, or after inlining, in the outer query, exactly as in a plain query; a materialized CTE's own buffered rows have no index of their own. */
/* Q5.  A materialized CTE acts as an optimization fence - outer WHERE predicates cannot be pushed down into it, so it always computes its full result first, which can be much slower than pushdown would allow. */
/* Q6.  A CTE chain names each intermediate step top-to-bottom in the order you think about the problem; nested subqueries force reading inside-out - the CTE chain is far easier for another analyst to follow and debug. */
/* Q7.  EXPLAIN ANALYZE on a query with CTEs shows either "CTE Scan" nodes with their own cost/time when materialized, or the CTE's logic folded directly into the surrounding plan with no separate node when inlined. */
/* Q8.  The auto_explain extension automatically logs the full plan (including any CTE Scan nodes) for slow queries without a manual EXPLAIN, useful for catching a badly-materializing CTE in production. */
/* Q9.  A stored procedure/function body can contain full WITH ... AS (...) statements just like ad-hoc SQL; the CTE's scope is still just that one statement inside the procedure. */
/* Q10. Inside a function, a CTE's inner SELECT can reference the function's parameters directly (e.g. WHERE cust_id = p_cust_id), and PostgreSQL treats them as ordinary bound values for planning. */
/* Q11. A CREATE VIEW definition can start with WITH ... AS (...) before its final SELECT; the CTE re-runs every time the view is queried since the view itself isn't materialized. */
/* Q12. A CTE doesn't go "inside" a window function, but it commonly sits underneath one - compute a CTE first, then apply window functions to it in the outer SELECT (or a CTE that itself computes a window function feeds a simpler outer query). */
/* Q13. WITH RECURSIVE can itself contain the same non-recursive CTE patterns in its anchor or recursive term, and additional plain CTEs can be chained alongside a WITH RECURSIVE clause in the same overall WITH. */
/* Q14. A CTE can use array_agg(...) to produce one array-valued row per group, which the outer query can then unnest or pass along as a single column. */
/* Q15. A CTE can use json_agg(...) or jsonb_build_object(...) to produce JSON-shaped output rows that the outer query or an application can consume directly. */
/* Q16. A CTE can wrap a UNION/INTERSECT/EXCEPT query so the combined set gets a name the outer query can filter, join, or aggregate further. */
/* Q17. A CTE can pre-aggregate rows into one row per entity, and the outer query then uses conditional aggregates (SUM(CASE WHEN ... END)) to "pivot" category values into columns. */
/* Q18. A CTE can UNION ALL several single-column selects (one per source column) to turn multiple columns of one row into multiple rows of one column - the "unpivot" pattern. */
/* Q19. A CTE can stage raw rows, trim/cast/coalesce bad values, and hand the cleaned rows to the next CTE, so each cleansing rule lives in its own clearly named step. */
/* Q20. A CTE assigns each customer to a signup-month cohort, a second CTE finds their order activity, and the outer query groups by cohort and period-since-signup to measure retention. */
/* Q21. A CTE computes each customer's Recency (days since last order), Frequency (order count) and Monetary (total spend), and the outer query buckets/scores those three CTE columns into RFM segments. */
/* Q22. A CTE classifies each rating into promoter/passive/detractor buckets, and the outer query computes (%promoters - %detractors) as the NPS score from those bucketed rows. */
/* Q23. Each CTE represents one funnel stage (e.g. viewed, added_to_cart, ordered) as a set of ids, and the outer query LEFT JOINs the stages in order to count how many carried through each step. */
/* Q24. A CTE computes a baseline (mean/stddev or a moving average) per group, and the outer query flags rows whose value deviates from that baseline by more than a threshold. */
/* Q25. A CTE truncates a timestamp to the desired grain (day/week/month) and aggregates; the outer query can roll that up further (e.g. a daily CTE rolled to weekly in the outer SELECT) or present it directly. */

/* ============================================================
   SECTION B: CHAIN PATTERNS (25)
   ------------------------------------------------------------ */
/* Q26. */
WITH facts AS (
  SELECT order_id, order_date, net_total FROM sales.orders
),
daily AS (
  SELECT order_date, SUM(net_total) AS daily_revenue FROM facts GROUP BY order_date
),
weekly AS (
  SELECT date_trunc('week', order_date) AS week_start, SUM(daily_revenue) AS weekly_revenue
  FROM daily GROUP BY date_trunc('week', order_date)
)
SELECT * FROM weekly ORDER BY week_start;

/* Q27. */
WITH facts AS (
  SELECT order_id, order_date, net_total FROM sales.orders
),
daily AS (
  SELECT order_date, SUM(net_total) AS daily_revenue FROM facts GROUP BY order_date
),
weekly AS (
  SELECT date_trunc('week', order_date) AS week_start, SUM(daily_revenue) AS weekly_revenue
  FROM daily GROUP BY date_trunc('week', order_date)
),
monthly AS (
  SELECT date_trunc('month', week_start) AS month_start, SUM(weekly_revenue) AS monthly_revenue
  FROM weekly GROUP BY date_trunc('month', week_start)
)
SELECT * FROM monthly ORDER BY month_start;

/* Q28. */
WITH facts AS (
  SELECT order_id, order_date, net_total FROM sales.orders
),
daily AS (
  SELECT order_date, SUM(net_total) AS daily_revenue FROM facts GROUP BY order_date
),
weekly AS (
  SELECT date_trunc('week', order_date) AS week_start, SUM(daily_revenue) AS weekly_revenue
  FROM daily GROUP BY date_trunc('week', order_date)
),
monthly AS (
  SELECT date_trunc('month', week_start) AS month_start, SUM(weekly_revenue) AS monthly_revenue
  FROM weekly GROUP BY date_trunc('month', week_start)
),
yearly AS (
  SELECT date_trunc('year', month_start) AS year_start, SUM(monthly_revenue) AS yearly_revenue
  FROM monthly GROUP BY date_trunc('year', month_start)
)
SELECT * FROM yearly ORDER BY year_start;

/* Q29. */
WITH orders_agg AS (
  SELECT cust_id, SUM(net_total) AS total_spend FROM sales.orders GROUP BY cust_id
),
reviews_agg AS (
  SELECT customer_id, AVG(rating) AS avg_rating FROM customers.reviews GROUP BY customer_id
)
SELECT c.customer_id, o.total_spend, r.avg_rating
FROM customers.customers c
LEFT JOIN orders_agg o ON o.cust_id = c.customer_id
LEFT JOIN reviews_agg r ON r.customer_id = c.customer_id
ORDER BY o.total_spend DESC NULLS LAST
LIMIT 100;

/* Q30. */
WITH source AS (
  SELECT * FROM sales.orders
),
branch_paid AS (
  SELECT o.cust_id, COUNT(*) AS paid_orders
  FROM source o JOIN finance.payments p ON p.order_id = o.order_id
  WHERE p.status = 'Completed'
  GROUP BY o.cust_id
),
branch_returned AS (
  SELECT o.cust_id, COUNT(*) AS returned_orders
  FROM source o JOIN sales.returns r ON r.order_id = o.order_id
  GROUP BY o.cust_id
)
SELECT bp.cust_id, bp.paid_orders, COALESCE(br.returned_orders, 0) AS returned_orders
FROM branch_paid bp
LEFT JOIN branch_returned br ON br.cust_id = bp.cust_id
ORDER BY bp.paid_orders DESC
LIMIT 100;

/* Q31. */
WITH base AS (
  SELECT order_id, net_total,
         CASE WHEN net_total > 20000 THEN 'high' WHEN net_total > 5000 THEN 'medium' ELSE 'low' END AS value_band
  FROM sales.orders
)
SELECT value_band, COUNT(*) AS order_count, SUM(net_total) AS total_revenue
FROM base
GROUP BY value_band
ORDER BY total_revenue DESC;

/* Q32. */
WITH region_month AS (
  SELECT r.region_name, date_trunc('month', o.order_date) AS month, SUM(o.net_total) AS revenue
  FROM sales.orders o
  JOIN stores.stores s ON o.store_id = s.store_id
  JOIN core.dim_region r ON s.region_id = r.region_id
  GROUP BY ROLLUP (r.region_name, date_trunc('month', o.order_date))
)
SELECT * FROM region_month ORDER BY region_name NULLS LAST, month NULLS LAST;

/* Q33. */
WITH region_tier AS (
  SELECT r.region_name, c.tier, SUM(o.net_total) AS revenue
  FROM sales.orders o
  JOIN stores.stores s ON o.store_id = s.store_id
  JOIN core.dim_region r ON s.region_id = r.region_id
  JOIN customers.customers c ON c.customer_id = o.cust_id
  GROUP BY CUBE (r.region_name, c.tier)
)
SELECT * FROM region_tier ORDER BY region_name NULLS LAST, tier NULLS LAST;

/* Q34. */
WITH ranked_orders AS (
  SELECT order_id, cust_id, net_total,
         ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY net_total DESC) AS rn
  FROM sales.orders
)
SELECT * FROM ranked_orders WHERE rn = 1 ORDER BY net_total DESC LIMIT 100;

/* Q35. */
WITH sample_customers AS (
  SELECT customer_id FROM customers.customers ORDER BY customer_id LIMIT 200
),
top_orders AS (
  SELECT c.customer_id, o.order_id, o.net_total
  FROM sample_customers c
  CROSS JOIN LATERAL (
    SELECT order_id, net_total FROM sales.orders o WHERE o.cust_id = c.customer_id ORDER BY net_total DESC LIMIT 1
  ) o
)
SELECT * FROM top_orders ORDER BY net_total DESC LIMIT 100;

/* Q36. */
WITH cancelled AS (
  SELECT cust_id FROM sales.orders WHERE order_status = 'Cancelled'
),
returned AS (
  SELECT DISTINCT o.cust_id FROM sales.orders o JOIN sales.returns r ON r.order_id = o.order_id
),
problem_customers AS (
  SELECT cust_id FROM cancelled
  INTERSECT
  SELECT cust_id FROM returned
)
SELECT * FROM problem_customers LIMIT 100;

/* Q37. */
WITH order_percentiles AS (
  SELECT
    percentile_cont(0.25) WITHIN GROUP (ORDER BY net_total) AS p25,
    percentile_cont(0.50) WITHIN GROUP (ORDER BY net_total) AS p50,
    percentile_cont(0.75) WITHIN GROUP (ORDER BY net_total) AS p75,
    percentile_cont(0.90) WITHIN GROUP (ORDER BY net_total) AS p90
  FROM sales.orders
)
SELECT * FROM order_percentiles;

/* Q38. */
WITH order_stats AS (
  SELECT cust_id,
         COUNT(*) FILTER (WHERE order_status = 'Delivered') AS delivered_count,
         COUNT(*) FILTER (WHERE order_status = 'Cancelled') AS cancelled_count,
         COUNT(*) AS total_orders
  FROM sales.orders
  GROUP BY cust_id
)
SELECT * FROM order_stats ORDER BY total_orders DESC LIMIT 100;

/* Q39. */
WITH typed AS (
  SELECT order_id, order_date::timestamp AS order_ts, net_total::float8 AS net_total_f
  FROM sales.orders
)
SELECT * FROM typed ORDER BY order_id LIMIT 100;

/* Q40. */
WITH cleaned AS (
  SELECT customer_id, COALESCE(phone, 'UNKNOWN') AS phone, NULLIF(email, '') AS email
  FROM customers.customers
)
SELECT * FROM cleaned WHERE email IS NULL LIMIT 100;

/* Q41. */
WITH normalized AS (
  SELECT DISTINCT customer_id, lower(email) AS email_lower
  FROM customers.customers
)
SELECT * FROM normalized ORDER BY customer_id LIMIT 100;

/* Q42. */
WITH region_lookup AS (
  SELECT region_id, region_name FROM core.dim_region
)
SELECT s.store_id, s.store_name, rl.region_name
FROM stores.stores s
JOIN region_lookup rl ON rl.region_id = s.region_id
ORDER BY s.store_id;

/* Q43. */
WITH brand_dim AS (
  SELECT b.brand_id, b.brand_name, c.category_name
  FROM core.dim_brand b JOIN core.dim_category c ON c.category_id = b.category_id
)
SELECT p.product_id, p.product_name, bd.brand_name, bd.category_name
FROM products.products p
JOIN brand_dim bd ON bd.brand_id = p.brand_id
ORDER BY p.product_id LIMIT 100;

/* Q44. */
WITH kpi AS (
  SELECT COUNT(*) AS total_orders, SUM(net_total) AS total_revenue, AVG(net_total) AS avg_order_value
  FROM sales.orders
)
SELECT * FROM kpi;

/* Q45. */
WITH cust_summary AS (
  SELECT cust_id, COUNT(*) AS order_count, SUM(net_total) AS total_spend
  FROM sales.orders GROUP BY cust_id
)
SELECT cust_id, json_build_object('order_count', order_count, 'total_spend', total_spend) AS summary_json
FROM cust_summary
ORDER BY total_spend DESC
LIMIT 20;

/* Q46. */
WITH cust_summary AS (
  SELECT cust_id, COUNT(*) AS order_count, SUM(net_total) AS total_spend
  FROM sales.orders GROUP BY cust_id
)
SELECT cust_id || ',' || order_count || ',' || total_spend AS csv_row
FROM cust_summary
ORDER BY cust_id
LIMIT 20;

/* Q47. */
WITH daily_rev AS (
  SELECT order_date, SUM(net_total) AS revenue FROM sales.orders GROUP BY order_date
),
stats AS (
  SELECT AVG(revenue) AS avg_rev, STDDEV(revenue) AS sd_rev FROM daily_rev
)
SELECT d.order_date, d.revenue
FROM daily_rev d, stats s
WHERE ABS(d.revenue - s.avg_rev) > 2 * s.sd_rev
ORDER BY d.order_date;

/* Q48. */
WITH ranked AS (
  SELECT cust_id, SUM(net_total) AS total_spend,
         RANK() OVER (ORDER BY SUM(net_total) DESC) AS spend_rank
  FROM sales.orders GROUP BY cust_id
)
SELECT * FROM ranked WHERE spend_rank <= 20;

/* Q49. */
WITH cohort AS (
  SELECT customer_id, date_trunc('month', registration_date) AS cohort_month FROM customers.customers
),
activity AS (
  SELECT cust_id, date_trunc('month', order_date) AS order_month FROM sales.orders
)
SELECT c.cohort_month, COUNT(DISTINCT a.cust_id) AS active_customers
FROM cohort c
JOIN activity a ON a.cust_id = c.customer_id
GROUP BY c.cohort_month
ORDER BY c.cohort_month;

/* Q50. */
WITH rfm AS (
  SELECT cust_id,
         (SELECT MAX(order_date) FROM sales.orders) - MAX(order_date) AS recency_days,
         COUNT(*) AS frequency,
         SUM(net_total) AS monetary
  FROM sales.orders GROUP BY cust_id
)
SELECT cust_id, recency_days, frequency, monetary,
       CASE WHEN frequency >= 10 AND monetary > 50000 THEN 'Champion'
            WHEN recency_days > 180 THEN 'At Risk'
            ELSE 'Regular' END AS segment
FROM rfm
ORDER BY monetary DESC
LIMIT 100;

/* ============================================================
   SECTION C: CTE + WINDOW (25)
   ------------------------------------------------------------ */
/* Q51. */
WITH numbered AS (
  SELECT order_id, cust_id, order_date, ROW_NUMBER() OVER (ORDER BY order_date) AS rn
  FROM sales.orders
)
SELECT * FROM numbered ORDER BY rn LIMIT 20;

/* Q52. */
WITH ranked AS (
  SELECT cust_id, SUM(net_total) AS total_spend, RANK() OVER (ORDER BY SUM(net_total) DESC) AS spend_rank
  FROM sales.orders GROUP BY cust_id
)
SELECT * FROM ranked ORDER BY spend_rank LIMIT 20;

/* Q53. */
WITH product_rank AS (
  SELECT product_id, price, DENSE_RANK() OVER (ORDER BY price DESC) AS price_rank
  FROM products.products
)
SELECT * FROM product_rank WHERE price_rank <= 10 ORDER BY price_rank;

/* Q54. */
WITH quartiles AS (
  SELECT cust_id, SUM(net_total) AS total_spend, NTILE(4) OVER (ORDER BY SUM(net_total)) AS spend_quartile
  FROM sales.orders GROUP BY cust_id
)
SELECT spend_quartile, COUNT(*) AS customers, MIN(total_spend) AS min_spend, MAX(total_spend) AS max_spend
FROM quartiles GROUP BY spend_quartile ORDER BY spend_quartile;

/* Q55. */
WITH monthly_rev AS (
  SELECT date_trunc('month', order_date) AS month, SUM(net_total) AS revenue
  FROM sales.orders GROUP BY date_trunc('month', order_date)
)
SELECT month, revenue,
       LAG(revenue) OVER (ORDER BY month) AS prev_month_revenue,
       LEAD(revenue) OVER (ORDER BY month) AS next_month_revenue
FROM monthly_rev ORDER BY month;

/* Q56. */
WITH daily_rev AS (
  SELECT order_date, SUM(net_total) AS revenue FROM sales.orders GROUP BY order_date
)
SELECT order_date, revenue, SUM(revenue) OVER (ORDER BY order_date) AS running_total
FROM daily_rev ORDER BY order_date LIMIT 100;

/* Q57. */
WITH daily_rev AS (
  SELECT order_date, SUM(net_total) AS revenue FROM sales.orders GROUP BY order_date
)
SELECT order_date, revenue,
       AVG(revenue) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7d
FROM daily_rev ORDER BY order_date LIMIT 100;

/* Q58. */
WITH by_brand AS (
  SELECT p.brand_id, oi.net_amount FROM sales.order_items oi JOIN products.products p ON oi.prod_id = p.product_id
)
SELECT brand_id, percentile_cont(0.5) WITHIN GROUP (ORDER BY net_amount) AS median_amount
FROM by_brand GROUP BY brand_id ORDER BY brand_id LIMIT 20;

/* Q59. */
WITH cust_orders AS (
  SELECT cust_id, order_id, order_date, net_total,
         FIRST_VALUE(net_total) OVER (PARTITION BY cust_id ORDER BY order_date) AS first_order_value
  FROM sales.orders
)
SELECT * FROM cust_orders ORDER BY cust_id, order_date LIMIT 100;

/* Q60. */
WITH cust_orders AS (
  SELECT cust_id, order_id, order_date, net_total,
         LAST_VALUE(net_total) OVER (PARTITION BY cust_id ORDER BY order_date
           ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_order_value
  FROM sales.orders
)
SELECT * FROM cust_orders ORDER BY cust_id, order_date LIMIT 100;

/* Q61. */
WITH ranked AS (
  SELECT cust_id, order_id, net_total, ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY net_total DESC) AS rn
  FROM sales.orders
)
SELECT * FROM ranked WHERE rn <= 3 ORDER BY cust_id, rn LIMIT 100;

/* Q62. */
WITH order_analysis AS (
  SELECT cust_id, order_id, net_total,
         ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY net_total DESC) AS rn_by_value,
         RANK() OVER (ORDER BY net_total DESC) AS overall_rank,
         SUM(net_total) OVER (PARTITION BY cust_id) AS cust_total_spend
  FROM sales.orders
)
SELECT * FROM order_analysis ORDER BY overall_rank LIMIT 100;

/* Q63. */
WITH store_orders AS (
  SELECT store_id, order_id, order_date, net_total,
         ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY order_date DESC) AS rn
  FROM sales.orders
)
SELECT * FROM store_orders WHERE rn = 1 ORDER BY store_id;

/* Q64. */
WITH orders_win AS (
  SELECT cust_id, order_id, net_total,
         SUM(net_total) OVER w AS cust_total,
         AVG(net_total) OVER w AS cust_avg
  FROM sales.orders
  WINDOW w AS (PARTITION BY cust_id)
)
SELECT * FROM orders_win ORDER BY cust_id LIMIT 100;

/* Q65. */
WITH daily_rev AS (
  SELECT order_date, SUM(net_total) AS revenue FROM sales.orders GROUP BY order_date
)
SELECT order_date, revenue,
       SUM(revenue) OVER (ORDER BY order_date RANGE BETWEEN '3 days' PRECEDING AND CURRENT ROW) AS trailing_4day_sum
FROM daily_rev ORDER BY order_date LIMIT 100;

/* Q66. */
WITH cust_days AS (
  SELECT cust_id, order_date,
         order_date - (ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date))::int AS grp
  FROM (SELECT DISTINCT cust_id, order_date FROM sales.orders) d
)
SELECT cust_id, MIN(order_date) AS streak_start, MAX(order_date) AS streak_end, COUNT(*) AS streak_len
FROM cust_days
GROUP BY cust_id, grp
HAVING COUNT(*) > 1
ORDER BY streak_len DESC
LIMIT 50;

/* Q67. */
WITH status_seq AS (
  SELECT order_id, order_status, order_date,
         LAG(order_status) OVER (ORDER BY order_date) AS prev_status
  FROM sales.orders
)
SELECT * FROM status_seq WHERE order_status = prev_status ORDER BY order_date LIMIT 100;

/* Q68. */
WITH pv AS (
  SELECT customer_id, view_timestamp,
         LAG(view_timestamp) OVER (PARTITION BY customer_id ORDER BY view_timestamp) AS prev_view
  FROM web_events.page_views
  WHERE customer_id IS NOT NULL
),
sessioned AS (
  SELECT *, CASE WHEN prev_view IS NULL OR view_timestamp - prev_view > INTERVAL '30 minutes' THEN 1 ELSE 0 END AS new_session
  FROM pv
)
SELECT customer_id, view_timestamp, SUM(new_session) OVER (PARTITION BY customer_id ORDER BY view_timestamp) AS session_id
FROM sessioned
ORDER BY customer_id, view_timestamp
LIMIT 100;

/* Q69. */
WITH cohort AS (
  SELECT customer_id, date_trunc('month', registration_date) AS cohort_month FROM customers.customers
),
orders_month AS (
  SELECT cust_id, date_trunc('month', order_date) AS order_month FROM sales.orders
),
cohort_activity AS (
  SELECT c.cohort_month, o.order_month, COUNT(DISTINCT o.cust_id) AS active_customers
  FROM cohort c JOIN orders_month o ON o.cust_id = c.customer_id
  GROUP BY c.cohort_month, o.order_month
)
SELECT cohort_month, order_month, active_customers,
       active_customers::float / FIRST_VALUE(active_customers) OVER (PARTITION BY cohort_month ORDER BY order_month) AS retention_ratio
FROM cohort_activity
ORDER BY cohort_month, order_month
LIMIT 100;

/* Q70. */
WITH monthly_rev AS (
  SELECT date_trunc('month', order_date) AS month, SUM(net_total) AS revenue
  FROM sales.orders GROUP BY date_trunc('month', order_date)
)
SELECT month, revenue, SUM(revenue) OVER (ORDER BY month) AS cumulative_revenue
FROM monthly_rev ORDER BY month;

/* Q71. */
WITH monthly_rev AS (
  SELECT date_trunc('month', order_date) AS month, SUM(net_total) AS revenue
  FROM sales.orders GROUP BY date_trunc('month', order_date)
)
SELECT month, revenue,
       AVG(revenue) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS moving_avg_3mo
FROM monthly_rev ORDER BY month;

/* Q72. */
WITH monthly_rev AS (
  SELECT date_trunc('month', order_date) AS month, SUM(net_total) AS revenue
  FROM sales.orders GROUP BY date_trunc('month', order_date)
)
SELECT month, revenue,
       LAG(revenue, 12) OVER (ORDER BY month) AS revenue_last_year,
       revenue - LAG(revenue, 12) OVER (ORDER BY month) AS yoy_change
FROM monthly_rev ORDER BY month;

/* Q73. */
WITH ranked_products AS (
  SELECT p.brand_id, oi.prod_id, SUM(oi.net_amount) AS revenue,
         ROW_NUMBER() OVER (PARTITION BY p.brand_id ORDER BY SUM(oi.net_amount) DESC) AS rn
  FROM sales.order_items oi JOIN products.products p ON oi.prod_id = p.product_id
  GROUP BY p.brand_id, oi.prod_id
)
SELECT * FROM ranked_products WHERE rn <= 3 ORDER BY brand_id, rn LIMIT 100;

/* Q74. */
WITH cust_spend AS (
  SELECT cust_id, SUM(net_total) AS total_spend FROM sales.orders GROUP BY cust_id
)
SELECT cust_id, total_spend, PERCENT_RANK() OVER (ORDER BY total_spend) AS spend_percentile
FROM cust_spend ORDER BY total_spend DESC LIMIT 100;

/* Q75. */
WITH cust_orders AS (
  SELECT cust_id, order_id, order_date, net_total,
         FIRST_VALUE(net_total) OVER (PARTITION BY cust_id ORDER BY order_date) AS first_value
  FROM sales.orders
)
SELECT cust_id, order_id, order_date, net_total, net_total - first_value AS delta_vs_first
FROM cust_orders ORDER BY cust_id, order_date LIMIT 100;

/* ============================================================
   SECTION D: CTE FOR ETL (25)
   NOTE: Q87-Q100 involve inserts/updates/deletes, so they run
   against session-local TEMP tables seeded from the real tables -
   the writeable-CTE / ETL syntax is genuinely tested with no side
   effects on the shared database.
   ------------------------------------------------------------ */
/* Q76. */
WITH staging AS (
  SELECT customer_id, email, phone, tier FROM customers.customers
),
cleaned AS (
  SELECT customer_id, lower(trim(email)) AS email, COALESCE(phone, 'UNKNOWN') AS phone, tier
  FROM staging
  WHERE email IS NOT NULL
)
SELECT * FROM cleaned ORDER BY customer_id LIMIT 100;

/* Q77. */
WITH deduped AS (
  SELECT DISTINCT ON (order_id) order_id, prod_id, quantity, net_amount
  FROM sales.order_items
  ORDER BY order_id, order_item_id
)
SELECT * FROM deduped ORDER BY order_id LIMIT 100;

/* Q78. */
WITH cast_attempt AS (
  SELECT product_id, price,
         CASE WHEN price::text ~ '^[0-9]+(\.[0-9]+)?$' THEN price ELSE NULL END AS price_validated
  FROM products.products
)
SELECT * FROM cast_attempt WHERE price_validated IS NULL LIMIT 100;

/* Q79. */
WITH null_fixed AS (
  SELECT customer_id, COALESCE(phone, 'N/A') AS phone, COALESCE(email, 'unknown@retailmart.com') AS email
  FROM customers.customers
)
SELECT * FROM null_fixed WHERE phone = 'N/A' OR email = 'unknown@retailmart.com' LIMIT 100;

/* Q80. */
WITH stats AS (
  SELECT AVG(net_total) AS mean_total, STDDEV(net_total) AS sd_total FROM sales.orders
),
cleaned AS (
  SELECT o.* FROM sales.orders o, stats s
  WHERE ABS(o.net_total - s.mean_total) <= 3 * s.sd_total
)
SELECT COUNT(*) AS clean_row_count FROM cleaned;

/* Q81. */
WITH enriched AS (
  SELECT o.order_id, o.net_total, c.tier, c.first_name, c.last_name
  FROM sales.orders o
  JOIN customers.customers c ON c.customer_id = o.cust_id
)
SELECT * FROM enriched ORDER BY order_id LIMIT 100;

/* Q82. */
WITH agg AS (
  SELECT cust_id, COUNT(*) AS order_count, SUM(net_total) AS total_spend
  FROM sales.orders GROUP BY cust_id
)
SELECT * FROM agg ORDER BY total_spend DESC LIMIT 100;

/* Q83. */
WITH split_items AS (
  SELECT o.order_id, oi.prod_id, oi.quantity, oi.net_amount
  FROM sales.orders o
  JOIN sales.order_items oi ON oi.order_id = o.order_id
)
SELECT * FROM split_items ORDER BY order_id LIMIT 100;

/* Q84. */
WITH merged AS (
  SELECT o.order_id, o.net_total, p.status AS payment_status, sh.status AS shipment_status
  FROM sales.orders o
  LEFT JOIN finance.payments p ON p.order_id = o.order_id
  LEFT JOIN sales.shipments sh ON sh.order_id = o.order_id
)
SELECT * FROM merged ORDER BY order_id LIMIT 100;

/* Q85. */
WITH support_contacts AS (
  SELECT customer_id, 'ticket' AS source, created_date::date AS contact_date FROM support.tickets
),
call_contacts AS (
  SELECT customer_id, 'call' AS source, call_start_time::date AS contact_date FROM call_center.calls
),
all_contacts AS (
  SELECT * FROM support_contacts
  UNION ALL
  SELECT * FROM call_contacts
)
SELECT * FROM all_contacts ORDER BY contact_date DESC LIMIT 100;

/* Q86. */
WITH reviewers AS (
  SELECT DISTINCT customer_id FROM customers.reviews
)
SELECT c.customer_id, c.first_name, c.last_name
FROM customers.customers c
WHERE NOT EXISTS (SELECT 1 FROM reviewers r WHERE r.customer_id = c.customer_id)
LIMIT 100;

CREATE TEMP TABLE tmp2_orders AS SELECT * FROM sales.orders LIMIT 500;
CREATE TEMP TABLE tmp2_audit_log (log_id SERIAL PRIMARY KEY, action TEXT, ref_id INT, logged_at TIMESTAMP DEFAULT now());
CREATE TEMP TABLE tmp2_order_archive (LIKE sales.orders INCLUDING ALL);
CREATE TEMP TABLE tmp2_fact_orders (LIKE sales.orders INCLUDING ALL);
CREATE TEMP TABLE tmp2_customers AS SELECT * FROM customers.customers LIMIT 500;
CREATE TEMP TABLE tmp2_customer_dim (customer_id INT PRIMARY KEY, tier TEXT, valid_from DATE, valid_to DATE, is_current BOOLEAN);
CREATE TEMP TABLE tmp2_customer_scd (scd_id SERIAL PRIMARY KEY, customer_id INT, tier TEXT, valid_from DATE, valid_to DATE, is_current BOOLEAN);
CREATE TEMP TABLE tmp2_cdc_log (log_id SERIAL PRIMARY KEY, op TEXT, order_id INT, changed_at TIMESTAMP DEFAULT now());
CREATE TEMP TABLE tmp2_dq_flags (order_id INT, flag TEXT);
CREATE TEMP TABLE tmp2_dim_brand (LIKE core.dim_brand INCLUDING ALL);
INSERT INTO tmp2_customer_scd (customer_id, tier, valid_from, valid_to, is_current)
SELECT customer_id, tier, registration_date, NULL, TRUE FROM tmp2_customers LIMIT 20;

/* Q87. */
WITH new_orders AS (
  INSERT INTO tmp2_fact_orders SELECT * FROM tmp2_orders WHERE order_status = 'Delivered' RETURNING order_id
)
INSERT INTO tmp2_audit_log (action, ref_id) SELECT 'fact_load', order_id FROM new_orders;

/* Q88. */
WITH updated AS (
  UPDATE tmp2_orders SET order_status = 'Delivered' WHERE order_status = 'Shipped' RETURNING order_id
)
INSERT INTO tmp2_audit_log (action, ref_id) SELECT 'status_updated', order_id FROM updated;

/* Q89. */
WITH removed AS (
  DELETE FROM tmp2_orders WHERE order_status = 'Cancelled' RETURNING *
)
INSERT INTO tmp2_order_archive SELECT * FROM removed;

/* Q90. */
WITH src AS (
  SELECT customer_id, tier FROM tmp2_customers LIMIT 20
)
INSERT INTO tmp2_customer_dim (customer_id, tier, valid_from, valid_to, is_current)
SELECT customer_id, tier, CURRENT_DATE, NULL, TRUE FROM src
ON CONFLICT (customer_id) DO UPDATE SET tier = EXCLUDED.tier, valid_from = EXCLUDED.valid_from;

/* Q91. */
WITH watermark AS (
  SELECT MAX(order_date) - INTERVAL '7 days' AS since FROM tmp2_orders
),
incremental AS (
  SELECT o.* FROM sales.orders o, watermark w WHERE o.order_date > w.since
)
SELECT COUNT(*) AS new_rows FROM incremental;

/* Q92. */
WITH changed AS (
  UPDATE tmp2_orders SET order_status = 'Returned'
  WHERE order_status = 'Delivered' AND order_id IN (SELECT order_id FROM tmp2_orders ORDER BY order_id LIMIT 5)
  RETURNING order_id
)
INSERT INTO tmp2_cdc_log (op, order_id) SELECT 'UPDATE', order_id FROM changed;

/* Q93. */
WITH snapshot AS (
  SELECT store_id, product_id, quantity_on_hand, CURRENT_DATE AS snapshot_date
  FROM products.inventory
)
SELECT * FROM snapshot ORDER BY store_id, product_id LIMIT 100;

/* Q94. */
WITH dim_rows AS (
  SELECT brand_id, brand_name, category_id FROM core.dim_brand
)
INSERT INTO tmp2_dim_brand SELECT * FROM dim_rows
ON CONFLICT (brand_id) DO UPDATE SET brand_name = EXCLUDED.brand_name;

/* Q95. */
WITH fact_rows AS (
  SELECT * FROM tmp2_orders WHERE order_status IN ('Delivered', 'Shipped')
)
INSERT INTO tmp2_fact_orders SELECT * FROM fact_rows
ON CONFLICT (order_id) DO NOTHING;

/* Q96. */
WITH closing AS (
  UPDATE tmp2_customer_scd
  SET valid_to = CURRENT_DATE, is_current = FALSE
  WHERE is_current = TRUE AND customer_id IN (SELECT customer_id FROM tmp2_customer_scd LIMIT 5)
  RETURNING customer_id, tier
)
INSERT INTO tmp2_customer_scd (customer_id, tier, valid_from, valid_to, is_current)
SELECT customer_id, tier, CURRENT_DATE, NULL, TRUE FROM closing;

/* Q97. */
WITH inserts AS (
  SELECT order_id, 'INSERT' AS op FROM tmp2_orders WHERE order_id IN (SELECT order_id FROM tmp2_orders ORDER BY order_id DESC LIMIT 3)
),
deletes AS (
  SELECT order_id, 'DELETE' AS op FROM tmp2_order_archive
),
stream AS (
  SELECT * FROM inserts
  UNION ALL
  SELECT * FROM deletes
)
INSERT INTO tmp2_cdc_log (op, order_id) SELECT op, order_id FROM stream;

/* Q98. */
WITH flagged AS (
  SELECT order_id,
         CASE WHEN net_total IS NULL THEN 'missing_total'
              WHEN net_total < 0 THEN 'negative_total'
              WHEN cust_id IS NULL THEN 'missing_customer'
         END AS flag
  FROM tmp2_orders
  WHERE net_total IS NULL OR net_total < 0 OR cust_id IS NULL
)
INSERT INTO tmp2_dq_flags (order_id, flag) SELECT order_id, flag FROM flagged;

/* Q99. */
WITH all_changes AS (
  SELECT log_id, action, ref_id, logged_at FROM tmp2_audit_log
)
SELECT COUNT(*) AS audit_row_count, MIN(logged_at) AS earliest, MAX(logged_at) AS latest FROM all_changes;

/* Q100. */
WITH step1_raw AS (
  SELECT * FROM sales.orders
),
step2_filtered AS (
  SELECT * FROM step1_raw WHERE order_status <> 'Cancelled'
),
step3_typed AS (
  SELECT order_id, cust_id, store_id, order_date::date AS order_date, net_total::numeric AS net_total
  FROM step2_filtered
),
step4_deduped AS (
  SELECT DISTINCT ON (order_id) * FROM step3_typed ORDER BY order_id
),
step5_enriched AS (
  SELECT d.*, c.tier FROM step4_deduped d JOIN customers.customers c ON c.customer_id = d.cust_id
),
step6_aggregated AS (
  SELECT cust_id, tier, COUNT(*) AS order_count, SUM(net_total) AS total_spend
  FROM step5_enriched GROUP BY cust_id, tier
),
step7_ranked AS (
  SELECT *, RANK() OVER (PARTITION BY tier ORDER BY total_spend DESC) AS tier_rank
  FROM step6_aggregated
),
step8_top AS (
  SELECT * FROM step7_ranked WHERE tier_rank <= 5
),
step9_labeled AS (
  SELECT *, CASE WHEN total_spend > 50000 THEN 'VIP' ELSE 'Regular' END AS segment
  FROM step8_top
),
step10_final AS (
  SELECT cust_id, tier, order_count, total_spend, tier_rank, segment
  FROM step9_labeled
)
SELECT * FROM step10_final ORDER BY tier, tier_rank;

/* ============================================================
   END OF CTEs (WITH, non-recursive) - MEDIUM LEVEL (100 QUESTIONS)
============================================================ */
