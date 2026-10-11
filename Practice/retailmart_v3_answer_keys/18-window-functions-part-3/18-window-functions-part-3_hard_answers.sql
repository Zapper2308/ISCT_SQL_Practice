/* ============================================================
   ANSWER KEY - Window Functions Part 3: LAG / LEAD (HARD LEVEL)
   Curriculum:   RetailMart V3
   Database:     isct_retailmart
   ============================================================ */

/* ============================================================
   SECTION A: CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1. Assign row_number() over the full ordered set and row_number() within each status group; subtract them. Rows in the same consecutive run share the same (date - group_row_number) value, so grouping by that difference isolates each island. */
/* Q2. If a month has zero activity it produces no row, so LAG on the raw grouped rows silently skips it and compares against the wrong "previous" month. Cross-joining a generate_series month spine with the dimension and LEFT JOINing the aggregate guarantees one row per month so LAG(x,1) always compares true neighbors. */
/* Q3. LAG(x,1) on a monthly grain compares to the prior calendar month (MoM); LAG(x,12) compares to the same month one year earlier (YoY). The pitfall is that both need a complete, gap-filled month spine, and YoY needs at least 12 trailing months of history or the first year returns NULL. */
/* Q4. Flag TRUE when the gap since the previous event exceeds the session threshold (or it's the first event); SUM() that boolean as an integer over an ordered window produces a number that only increases at each new session, so every row in the same session shares the same cumulative value - a ready-made session id. */
/* Q5. LEAD(order_date) IS NULL only tells you a customer's most recent order is the last one physically in the table - true for every still-active customer too. Comparing CURRENT_DATE - MAX(order_date) (or last event) to a churn threshold is correct because it measures actual elapsed time, not table position. */
/* Q6. LAG(x) returns the immediately prior row, which is NULL/irrelevant if that row itself has a NULL. The fix is the "last observation carried forward" pattern: MAX(x) FILTER (WHERE x IS NOT NULL) OVER (... ORDER BY ... ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), or the FIRST_VALUE/COUNT groupby trick. */
/* Q7. Build a monthly active flag per customer (1 if they ordered that month), then apply the gaps-and-islands technique (row_number difference or reset-on-gap cumulative sum) partitioned by customer to find each run's length and take the max per customer. */
/* Q8. Two events can share the same date; without a deterministic secondary ORDER BY key (like id) the window's row order - and therefore what LAG returns - is undefined between runs, so results could vary or be non-reproducible even though they look "sorted". */
/* Q9. Compute a moving average with the AVG() ... ROWS BETWEEN frame (Day 17), then compare each actual value (or its LAG) against that average; a value whose deviation from the trailing average exceeds a threshold flags an anomaly rather than a normal period-over-period swing. */
/* Q10. Run two independent LAG/window passes with different PARTITION BY clauses (store, month) and (region, month) inside the same query - typically as sibling CTEs unioned or joined together - since each grain needs its own partition and ordering. */
/* Q11. The first period in any series has no prior row so LAG returns NULL, making the growth % undefined (division context has no denominator). Filtering it out avoids a misleading NULL/blank row, or it can be explicitly labeled "N/A - first period" if the table must show every period. */
/* Q12. A reactivation cohort is the set of customers whose gap between two consecutive orders (current order_date - LAG(order_date)) exceeds 90 days; the order that ends the gap is the reactivation event and its month becomes the cohort. */
/* Q13. Union the event types (e.g. first page view and first purchase) into one timeline per customer, then LEAD the next event's timestamp/type across the ordered stream from the touch event to find the first matching later event and subtract timestamps for latency. */
/* Q14. Flag each period as negative (delta < 0) using LAG, then count the current run of consecutive negative flags (gaps-and-islands or a running counter that resets to 0 whenever the flag is false); N consecutive negatives means the counter reaches N. */
/* Q15. Order rows only exist on days a store actually sold something, so gaps (no orders) are invisible - LAG between two order rows always looks "one step apart" even if 10 real days passed. A generate_series date spine makes every calendar day a row so gaps and streaks are measured in real days. */
/* Q16. LEAD(event_timestamp) OVER (PARTITION BY entity ORDER BY event_timestamp) gives the timestamp of the next state change for that entity; subtracting the current timestamp from it gives how long the current state lasted (using COALESCE with a cutoff like NOW() for the still-open last state). */
/* Q17. Assign a group id via the row_number-difference or cumulative-sum-on-change technique per entity, then GROUP BY that id to collapse each run into one row with MIN(date) as run start, MAX(date) as run end, and COUNT(*) as run length - i.e. run-length encoding. */
/* Q18. A stored "previous" column must be manually kept in sync by application code on every write and can drift, be backfilled incorrectly, or miss out-of-order updates. LAG recomputes the previous value directly from the row order at query time, so it is always consistent with the current data. */
/* Q19. LEAD(order_date) OVER (...) would only show the next order that already exists in the table; for churn you want the gap to a still-open cutoff, so CURRENT_DATE - MAX(order_date) (per customer) or CURRENT_DATE - LAST_VALUE(order_date) with an unbounded-following frame is the correct comparison, not LEAD. */
/* Q20. Compute LAG(x,1), LAG(x,3) and LAG(x,12) as separate columns in the same SELECT (all reading the same ordered window), then derive three growth percentages against the current value in one pass instead of three separate queries. */
/* Q21. Order each product's price history by change date, take LAG(price) as the prior price, and flag every row where price <> LAG(price); the magnitude is price - LAG(price) (or the % via NULLIF-guarded division). */
/* Q22. For each customer compute month_number = (order month - signup month), then for the retention curve mark month_number = 0,1,2,... as "active" wherever a row exists; LAG/LEAD are used to detect first activity and confirm no early gaps distort the cohort's month-0 baseline. */
/* Q23. The gap threshold (e.g. 30 minutes) is a business rule that changes as the team tunes it; defining it once in a CTE (or a single named constant reused via a subquery) means adjusting one number re-derives every downstream session id and metric consistently. */
/* Q24. Use the reset-on-break cumulative counter: increment a counter each row that continues the streak, and reset it to 0 (or 1) whenever the streak condition breaks (via a CASE comparing to LAG); the running counter itself is the "current streak length" at every row. */
/* Q25. Compute each store's most recent MoM growth % with LAG in a CTE, then apply NTILE(4) (or another bucket count) OVER (ORDER BY that growth % DESC) in the outer query to split stores into quartiles of "fastest to slowest growing" - NTILE handles the bucketing, LAG supplies the growth metric it buckets on. */

/* ============================================================
   SECTION B: GROWTH TABLES (25)
   ------------------------------------------------------------ */
/* Q26. */
WITH months AS (
    SELECT generate_series('2024-01-01'::date, '2026-02-01'::date, '1 month'::interval)::date AS month
),
base AS (
    SELECT r.region_id, r.region_name, m.month, COALESCE(SUM(o.net_total), 0) AS revenue
    FROM core.dim_region r
    CROSS JOIN months m
    LEFT JOIN stores.stores s ON s.region_id = r.region_id
    LEFT JOIN sales.orders o ON o.store_id = s.store_id AND DATE_TRUNC('month', o.order_date) = m.month
    GROUP BY r.region_id, r.region_name, m.month
),
growth AS (
    SELECT region_id, region_name, month, revenue,
           LAG(revenue) OVER (PARTITION BY region_id ORDER BY month) AS prev_revenue
    FROM base
)
SELECT region_id, region_name, month, revenue, prev_revenue,
       ROUND(100.0 * (revenue - prev_revenue) / NULLIF(prev_revenue, 0), 2) AS mom_growth_pct,
       CASE WHEN prev_revenue IS NULL THEN 'N/A'
            WHEN revenue > prev_revenue THEN 'UP'
            WHEN revenue < prev_revenue THEN 'DOWN'
            ELSE 'FLAT' END AS flag
FROM growth
ORDER BY region_id, month;

/* Q27. */
WITH months AS (
    SELECT generate_series('2024-01-01'::date, '2026-02-01'::date, '1 month'::interval)::date AS month
),
base AS (
    SELECT s.store_id, m.month, COALESCE(SUM(o.net_total), 0) AS revenue
    FROM stores.stores s
    CROSS JOIN months m
    LEFT JOIN sales.orders o ON o.store_id = s.store_id AND DATE_TRUNC('month', o.order_date) = m.month
    GROUP BY s.store_id, m.month
),
growth AS (
    SELECT store_id, month, revenue,
           LAG(revenue, 12) OVER (PARTITION BY store_id ORDER BY month) AS revenue_last_year
    FROM base
)
SELECT store_id, month, revenue, revenue_last_year,
       ROUND(100.0 * (revenue - revenue_last_year) / NULLIF(revenue_last_year, 0), 2) AS yoy_growth_pct
FROM growth
ORDER BY store_id, month;

/* Q28. */
WITH quarters AS (
    SELECT r.region_id, r.region_name, DATE_TRUNC('quarter', o.order_date)::date AS quarter, SUM(o.net_total) AS revenue
    FROM sales.orders o
    JOIN stores.stores s ON o.store_id = s.store_id
    JOIN core.dim_region r ON s.region_id = r.region_id
    GROUP BY r.region_id, r.region_name, DATE_TRUNC('quarter', o.order_date)
),
growth AS (
    SELECT region_id, region_name, quarter, revenue,
           LAG(revenue) OVER (PARTITION BY region_id ORDER BY quarter) AS prev_revenue
    FROM quarters
)
SELECT region_id, region_name, quarter, revenue, prev_revenue,
       ROUND(100.0 * (revenue - prev_revenue) / NULLIF(prev_revenue, 0), 2) AS qoq_growth_pct,
       CASE WHEN prev_revenue IS NULL THEN 'N/A'
            WHEN revenue > prev_revenue THEN '▲'
            WHEN revenue < prev_revenue THEN '▼'
            ELSE '=' END AS arrow
FROM growth
ORDER BY region_id, quarter;

/* Q29. */
WITH monthly AS (
    SELECT store_id, DATE_TRUNC('month', order_date)::date AS month,
           SUM(net_total) AS revenue, COUNT(*) AS order_count,
           SUM(net_total) / COUNT(*) AS aov
    FROM sales.orders
    GROUP BY store_id, DATE_TRUNC('month', order_date)
)
SELECT store_id, month, aov,
       LAG(aov) OVER (PARTITION BY store_id ORDER BY month) AS prev_aov,
       ROUND(100.0 * (aov - LAG(aov) OVER (PARTITION BY store_id ORDER BY month))
             / NULLIF(LAG(aov) OVER (PARTITION BY store_id ORDER BY month), 0), 2) AS mom_aov_growth_pct
FROM monthly
ORDER BY store_id, month;

/* Q30. */
WITH top_products AS (
    SELECT oi.prod_id AS product_id, SUM(oi.quantity * oi.unit_price) AS total_revenue
    FROM sales.order_items oi
    GROUP BY oi.prod_id
    ORDER BY total_revenue DESC
    LIMIT 10
),
monthly AS (
    SELECT oi.prod_id AS product_id, DATE_TRUNC('month', o.order_date)::date AS month, SUM(oi.quantity) AS units
    FROM sales.order_items oi
    JOIN sales.orders o ON oi.order_id = o.order_id
    WHERE oi.prod_id IN (SELECT product_id FROM top_products)
    GROUP BY oi.prod_id, DATE_TRUNC('month', o.order_date)
)
SELECT product_id, month, units,
       LAG(units) OVER (PARTITION BY product_id ORDER BY month) AS prev_units,
       ROUND(100.0 * (units - LAG(units) OVER (PARTITION BY product_id ORDER BY month))
             / NULLIF(LAG(units) OVER (PARTITION BY product_id ORDER BY month), 0), 2) AS mom_units_growth_pct
FROM monthly
ORDER BY product_id, month;

/* Q31. */
WITH monthly AS (
    SELECT store_id, DATE_TRUNC('month', order_date)::date AS month, SUM(net_total) AS revenue
    FROM sales.orders
    GROUP BY store_id, DATE_TRUNC('month', order_date)
)
SELECT store_id, month, revenue,
       LAG(revenue, 1) OVER (PARTITION BY store_id ORDER BY month) AS rev_1mo_ago,
       LAG(revenue, 3) OVER (PARTITION BY store_id ORDER BY month) AS rev_3mo_ago,
       LAG(revenue, 12) OVER (PARTITION BY store_id ORDER BY month) AS rev_12mo_ago,
       ROUND(100.0 * (revenue - LAG(revenue, 1) OVER (PARTITION BY store_id ORDER BY month)) / NULLIF(LAG(revenue, 1) OVER (PARTITION BY store_id ORDER BY month), 0), 2) AS growth_vs_1mo,
       ROUND(100.0 * (revenue - LAG(revenue, 3) OVER (PARTITION BY store_id ORDER BY month)) / NULLIF(LAG(revenue, 3) OVER (PARTITION BY store_id ORDER BY month), 0), 2) AS growth_vs_3mo,
       ROUND(100.0 * (revenue - LAG(revenue, 12) OVER (PARTITION BY store_id ORDER BY month)) / NULLIF(LAG(revenue, 12) OVER (PARTITION BY store_id ORDER BY month), 0), 2) AS growth_vs_12mo
FROM monthly
ORDER BY store_id, month;

/* Q32. */
WITH first_orders AS (
    SELECT cust_id, MIN(order_date) AS first_order_date FROM sales.orders GROUP BY cust_id
),
new_cust AS (
    SELECT a.city, DATE_TRUNC('month', fo.first_order_date)::date AS month, COUNT(*) AS new_customers
    FROM first_orders fo
    JOIN customers.addresses a ON a.customer_id = fo.cust_id AND a.is_default = TRUE
    GROUP BY a.city, DATE_TRUNC('month', fo.first_order_date)
)
SELECT city, month, new_customers,
       LAG(new_customers) OVER (PARTITION BY city ORDER BY month) AS prev_new_customers,
       ROUND(100.0 * (new_customers - LAG(new_customers) OVER (PARTITION BY city ORDER BY month))
             / NULLIF(LAG(new_customers) OVER (PARTITION BY city ORDER BY month), 0), 2) AS mom_growth_pct
FROM new_cust
ORDER BY city, month;

/* Q33. */
WITH monthly AS (
    SELECT c.category_name, DATE_TRUNC('month', o.order_date)::date AS month,
           COUNT(DISTINCT r.return_id)::numeric / NULLIF(COUNT(DISTINCT oi.order_item_id), 0) AS refund_rate
    FROM sales.order_items oi
    JOIN sales.orders o ON oi.order_id = o.order_id
    JOIN products.products p ON oi.prod_id = p.product_id
    JOIN core.dim_brand b ON p.brand_id = b.brand_id
    JOIN core.dim_category c ON b.category_id = c.category_id
    LEFT JOIN sales.returns r ON r.order_id = o.order_id AND r.prod_id = oi.prod_id
    GROUP BY c.category_name, DATE_TRUNC('month', o.order_date)
)
SELECT category_name, month, ROUND(refund_rate, 4) AS refund_rate,
       ROUND(refund_rate - LAG(refund_rate) OVER (PARTITION BY category_name ORDER BY month), 4) AS mom_refund_rate_change
FROM monthly
ORDER BY category_name, month;

/* Q34. */
WITH weeks AS (
    SELECT r.region_id, r.region_name, DATE_TRUNC('week', o.order_date)::date AS week, COUNT(DISTINCT o.cust_id) AS active_customers
    FROM sales.orders o
    JOIN stores.stores s ON o.store_id = s.store_id
    JOIN core.dim_region r ON s.region_id = r.region_id
    GROUP BY r.region_id, r.region_name, DATE_TRUNC('week', o.order_date)
)
SELECT region_id, region_name, week, active_customers,
       LAG(active_customers) OVER (PARTITION BY region_id ORDER BY week) AS prev_week_active,
       ROUND(100.0 * (active_customers - LAG(active_customers) OVER (PARTITION BY region_id ORDER BY week))
             / NULLIF(LAG(active_customers) OVER (PARTITION BY region_id ORDER BY week), 0), 2) AS wow_growth_pct
FROM weeks
ORDER BY region_id, week;

/* Q35. */
WITH monthly AS (
    SELECT c.category_name, DATE_TRUNC('month', o.order_date)::date AS month, SUM(oi.quantity * oi.unit_price) AS category_revenue
    FROM sales.order_items oi
    JOIN sales.orders o ON oi.order_id = o.order_id
    JOIN products.products p ON oi.prod_id = p.product_id
    JOIN core.dim_brand b ON p.brand_id = b.brand_id
    JOIN core.dim_category c ON b.category_id = c.category_id
    GROUP BY c.category_name, DATE_TRUNC('month', o.order_date)
),
totals AS (
    SELECT month, SUM(category_revenue) AS company_revenue FROM monthly GROUP BY month
),
shares AS (
    SELECT m.category_name, m.month, m.category_revenue, t.company_revenue,
           100.0 * m.category_revenue / NULLIF(t.company_revenue, 0) AS pct_of_company
    FROM monthly m JOIN totals t ON t.month = m.month
)
SELECT category_name, month, ROUND(pct_of_company, 2) AS pct_of_company,
       ROUND(pct_of_company - LAG(pct_of_company) OVER (PARTITION BY category_name ORDER BY month), 2) AS mom_share_shift_pts
FROM shares
ORDER BY category_name, month;

/* Q36. */
WITH monthly AS (
    SELECT b.brand_name, DATE_TRUNC('month', o.order_date)::date AS month,
           SUM(oi.quantity * oi.unit_price) AS revenue,
           SUM(oi.quantity * p.cost_price) AS cost,
           100.0 * (SUM(oi.quantity * oi.unit_price) - SUM(oi.quantity * p.cost_price)) / NULLIF(SUM(oi.quantity * oi.unit_price), 0) AS gross_margin_pct
    FROM sales.order_items oi
    JOIN sales.orders o ON oi.order_id = o.order_id
    JOIN products.products p ON oi.prod_id = p.product_id
    JOIN core.dim_brand b ON p.brand_id = b.brand_id
    GROUP BY b.brand_name, DATE_TRUNC('month', o.order_date)
)
SELECT brand_name, month, ROUND(gross_margin_pct, 2) AS gross_margin_pct,
       ROUND(gross_margin_pct - LAG(gross_margin_pct) OVER (PARTITION BY brand_name ORDER BY month), 2) AS mom_margin_growth_pts
FROM monthly
ORDER BY brand_name, month;

/* Q37. */
WITH monthly AS (
    SELECT store_id, DATE_TRUNC('month', order_date)::date AS month, SUM(net_total) AS revenue
    FROM sales.orders
    GROUP BY store_id, DATE_TRUNC('month', order_date)
),
growth AS (
    SELECT store_id, month, revenue,
           LAG(revenue) OVER (PARTITION BY store_id ORDER BY month) AS prev_revenue,
           ROUND(100.0 * (revenue - LAG(revenue) OVER (PARTITION BY store_id ORDER BY month))
                 / NULLIF(LAG(revenue) OVER (PARTITION BY store_id ORDER BY month), 0), 2) AS mom_growth_pct
    FROM monthly
),
latest AS (
    SELECT store_id, month, mom_growth_pct,
           ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY month DESC) AS rn
    FROM growth
    WHERE mom_growth_pct IS NOT NULL
)
SELECT store_id, month, mom_growth_pct,
       RANK() OVER (ORDER BY mom_growth_pct DESC) AS growth_rank
FROM latest
WHERE rn = 1
ORDER BY growth_rank;

/* Q38. */
WITH monthly_spend AS (
    SELECT platform, DATE_TRUNC('month', spend_date)::date AS month, SUM(amount) AS spend
    FROM marketing.ads_spend
    GROUP BY platform, DATE_TRUNC('month', spend_date)
),
monthly_revenue AS (
    SELECT DATE_TRUNC('month', order_date)::date AS month, SUM(net_total) AS company_revenue
    FROM sales.orders
    GROUP BY DATE_TRUNC('month', order_date)
),
eff AS (
    SELECT s.platform, s.month, s.spend, r.company_revenue,
           r.company_revenue / NULLIF(s.spend, 0) AS revenue_per_spend
    FROM monthly_spend s
    JOIN monthly_revenue r ON r.month = s.month
)
SELECT platform, month, ROUND(revenue_per_spend, 2) AS revenue_per_spend,
       ROUND(revenue_per_spend - LAG(revenue_per_spend) OVER (PARTITION BY platform ORDER BY month), 2) AS mom_efficiency_change
FROM eff
ORDER BY platform, month;

/* Q39. */
WITH monthly AS (
    SELECT priority, DATE_TRUNC('month', created_date)::date AS month, COUNT(*) AS ticket_count
    FROM support.tickets
    GROUP BY priority, DATE_TRUNC('month', created_date)
)
SELECT priority, month, ticket_count,
       LAG(ticket_count) OVER (PARTITION BY priority ORDER BY month) AS prev_ticket_count,
       ROUND(100.0 * (ticket_count - LAG(ticket_count) OVER (PARTITION BY priority ORDER BY month))
             / NULLIF(LAG(ticket_count) OVER (PARTITION BY priority ORDER BY month), 0), 2) AS mom_growth_pct
FROM monthly
ORDER BY priority, month;

/* Q40. */
WITH monthly AS (
    SELECT store_id, DATE_TRUNC('month', order_date)::date AS month, SUM(net_total) AS revenue
    FROM sales.orders
    GROUP BY store_id, DATE_TRUNC('month', order_date)
),
running_peak AS (
    SELECT store_id, month, revenue,
           MAX(revenue) OVER (PARTITION BY store_id ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS prior_peak
    FROM monthly
)
SELECT store_id, MIN(month) AS first_month_exceeded_peak
FROM running_peak
WHERE prior_peak IS NOT NULL AND revenue > prior_peak
GROUP BY store_id
ORDER BY store_id;

/* Q41. */
WITH months AS (
    SELECT generate_series('2025-02-01'::date, '2026-02-01'::date, '1 month'::interval)::date AS month
),
devices AS (
    SELECT DISTINCT device_type FROM web_events.page_views
),
base AS (
    SELECT d.device_type, m.month, COUNT(pv.view_id) AS page_views
    FROM devices d
    CROSS JOIN months m
    LEFT JOIN web_events.page_views pv ON pv.device_type = d.device_type AND DATE_TRUNC('month', pv.view_timestamp) = m.month
    GROUP BY d.device_type, m.month
)
SELECT device_type, month, page_views,
       LAG(page_views) OVER (PARTITION BY device_type ORDER BY month) AS prev_page_views,
       ROUND(100.0 * (page_views - LAG(page_views) OVER (PARTITION BY device_type ORDER BY month))
             / NULLIF(LAG(page_views) OVER (PARTITION BY device_type ORDER BY month), 0), 2) AS mom_growth_pct
FROM base
ORDER BY device_type, month;

/* Q42. */
WITH monthly AS (
    SELECT store_id, DATE_TRUNC('month', order_date)::date AS month, SUM(net_total) AS revenue
    FROM sales.orders
    GROUP BY store_id, DATE_TRUNC('month', order_date)
),
deltas AS (
    SELECT store_id, month, revenue,
           LAG(revenue, 1) OVER (PARTITION BY store_id ORDER BY month) AS m1,
           LAG(revenue, 2) OVER (PARTITION BY store_id ORDER BY month) AS m2,
           LAG(revenue, 3) OVER (PARTITION BY store_id ORDER BY month) AS m3
    FROM monthly
)
SELECT store_id, month,
       ROUND(100.0 * (m1 - m2) / NULLIF(m2, 0), 2) AS growth_2mo_ago_to_1mo_ago,
       ROUND(100.0 * (revenue - m1) / NULLIF(m1, 0), 2) AS growth_1mo_ago_to_now,
       ROUND(100.0 * (revenue - m3) / NULLIF(m3, 0), 2) AS compounded_3mo_growth_pct
FROM deltas
WHERE m3 IS NOT NULL
ORDER BY store_id, month;

/* Q43. */
WITH monthly AS (
    SELECT d.dept_name, ps.salary_year, ps.salary_month, SUM(ps.net_salary) AS dept_cost
    FROM payroll.pay_slips ps
    JOIN stores.employees e ON ps.employee_id = e.employee_id
    JOIN core.dim_department d ON e.dept_id = d.dept_id
    GROUP BY d.dept_name, ps.salary_year, ps.salary_month
),
ordered AS (
    SELECT dept_name, salary_year, salary_month, dept_cost,
           MAKE_DATE(salary_year, CASE salary_month
               WHEN 'January' THEN 1 WHEN 'February' THEN 2 WHEN 'March' THEN 3 WHEN 'April' THEN 4
               WHEN 'May' THEN 5 WHEN 'June' THEN 6 WHEN 'July' THEN 7 WHEN 'August' THEN 8
               WHEN 'September' THEN 9 WHEN 'October' THEN 10 WHEN 'November' THEN 11 ELSE 12 END, 1) AS month_key
    FROM monthly
)
SELECT dept_name, month_key, dept_cost,
       LAG(dept_cost) OVER (PARTITION BY dept_name ORDER BY month_key) AS prev_cost,
       ROUND(100.0 * (dept_cost - LAG(dept_cost) OVER (PARTITION BY dept_name ORDER BY month_key))
             / NULLIF(LAG(dept_cost) OVER (PARTITION BY dept_name ORDER BY month_key), 0), 2) AS mom_cost_growth_pct
FROM ordered
ORDER BY dept_name, month_key;

/* Q44. */
WITH monthly AS (
    SELECT r.region_name, EXTRACT(MONTH FROM o.order_date)::int AS month_num, EXTRACT(YEAR FROM o.order_date)::int AS year_num, SUM(o.net_total) AS revenue
    FROM sales.orders o
    JOIN stores.stores s ON o.store_id = s.store_id
    JOIN core.dim_region r ON s.region_id = r.region_id
    GROUP BY r.region_name, EXTRACT(MONTH FROM o.order_date), EXTRACT(YEAR FROM o.order_date)
)
SELECT region_name, month_num, year_num, revenue,
       LAG(revenue) OVER (PARTITION BY region_name, month_num ORDER BY year_num) AS revenue_same_month_last_year,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (PARTITION BY region_name, month_num ORDER BY year_num))
             / NULLIF(LAG(revenue) OVER (PARTITION BY region_name, month_num ORDER BY year_num), 0), 2) AS yoy_growth_pct
FROM monthly
ORDER BY region_name, year_num, month_num;

/* Q45. */
WITH first_orders AS (
    SELECT cust_id, MIN(order_date) AS first_order_date FROM sales.orders GROUP BY cust_id
),
tagged AS (
    SELECT o.cust_id, o.order_date, o.net_total,
           CASE WHEN o.order_date = fo.first_order_date THEN 'new' ELSE 'returning' END AS customer_type
    FROM sales.orders o
    JOIN first_orders fo ON fo.cust_id = o.cust_id
),
monthly AS (
    SELECT customer_type, DATE_TRUNC('month', order_date)::date AS month, SUM(net_total) AS revenue
    FROM tagged
    GROUP BY customer_type, DATE_TRUNC('month', order_date)
)
SELECT customer_type, month, revenue,
       LAG(revenue) OVER (PARTITION BY customer_type ORDER BY month) AS prev_revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (PARTITION BY customer_type ORDER BY month))
             / NULLIF(LAG(revenue) OVER (PARTITION BY customer_type ORDER BY month), 0), 2) AS mom_growth_pct
FROM monthly
ORDER BY customer_type, month;

/* Q46. */
WITH monthly AS (
    SELECT store_id, DATE_TRUNC('month', order_date)::date AS month, SUM(net_total) AS revenue
    FROM sales.orders
    GROUP BY store_id, DATE_TRUNC('month', order_date)
),
flagged AS (
    SELECT store_id, month, revenue,
           (revenue < LAG(revenue) OVER (PARTITION BY store_id ORDER BY month)) AS is_decline
    FROM monthly
),
with_prev AS (
    SELECT store_id, month, revenue, is_decline,
           LAG(is_decline) OVER (PARTITION BY store_id ORDER BY month) AS prev_was_decline
    FROM flagged
)
SELECT store_id, month, revenue
FROM with_prev
WHERE is_decline AND prev_was_decline
ORDER BY store_id, month;

/* Q47. */
WITH monthly AS (
    SELECT store_id, DATE_TRUNC('month', order_date)::date AS month, SUM(net_total) AS revenue
    FROM sales.orders
    GROUP BY store_id, DATE_TRUNC('month', order_date)
)
SELECT store_id, month, revenue,
       LAG(revenue) OVER (PARTITION BY store_id ORDER BY month) AS prev_revenue,
       revenue - LAG(revenue) OVER (PARTITION BY store_id ORDER BY month) AS absolute_delta,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (PARTITION BY store_id ORDER BY month))
             / NULLIF(LAG(revenue) OVER (PARTITION BY store_id ORDER BY month), 0), 2) AS pct_delta
FROM monthly
ORDER BY store_id, month;

/* Q48. */
WITH top_categories AS (
    SELECT c.category_id, c.category_name, SUM(oi.quantity * oi.unit_price) AS total_revenue
    FROM sales.order_items oi
    JOIN products.products p ON oi.prod_id = p.product_id
    JOIN core.dim_brand b ON p.brand_id = b.brand_id
    JOIN core.dim_category c ON b.category_id = c.category_id
    GROUP BY c.category_id, c.category_name
    ORDER BY total_revenue DESC
    LIMIT 5
),
quarterly AS (
    SELECT c.category_name, DATE_TRUNC('quarter', o.order_date)::date AS quarter, SUM(oi.quantity * oi.unit_price) AS revenue
    FROM sales.order_items oi
    JOIN sales.orders o ON oi.order_id = o.order_id
    JOIN products.products p ON oi.prod_id = p.product_id
    JOIN core.dim_brand b ON p.brand_id = b.brand_id
    JOIN core.dim_category c ON b.category_id = c.category_id
    WHERE c.category_id IN (SELECT category_id FROM top_categories)
    GROUP BY c.category_name, DATE_TRUNC('quarter', o.order_date)
)
SELECT category_name, quarter, revenue,
       LAG(revenue) OVER (PARTITION BY category_name ORDER BY quarter) AS prev_quarter_revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (PARTITION BY category_name ORDER BY quarter))
             / NULLIF(LAG(revenue) OVER (PARTITION BY category_name ORDER BY quarter), 0), 2) AS qoq_growth_pct
FROM quarterly
ORDER BY category_name, quarter;

/* Q49. */
WITH monthly AS (
    SELECT store_id, DATE_TRUNC('month', order_date)::date AS month, SUM(net_total) AS revenue
    FROM sales.orders
    GROUP BY store_id, DATE_TRUNC('month', order_date)
)
SELECT store_id, month, revenue,
       ROUND(100.0 * revenue / NULLIF(FIRST_VALUE(revenue) OVER (PARTITION BY store_id ORDER BY month), 0), 2) AS indexed_to_100
FROM monthly
ORDER BY store_id, month;

/* Q50. */
WITH monthly AS (
    SELECT store_id, DATE_TRUNC('month', order_date)::date AS month, SUM(net_total) AS revenue
    FROM sales.orders
    GROUP BY store_id, DATE_TRUNC('month', order_date)
)
SELECT store_id, month, revenue,
       LAG(revenue, 1) OVER (PARTITION BY store_id ORDER BY month) AS prev_month_revenue,
       ROUND(100.0 * (revenue - LAG(revenue, 1) OVER (PARTITION BY store_id ORDER BY month))
             / NULLIF(LAG(revenue, 1) OVER (PARTITION BY store_id ORDER BY month), 0), 2) AS mom_growth_pct,
       ROUND(100.0 * (revenue - LAG(revenue, 12) OVER (PARTITION BY store_id ORDER BY month))
             / NULLIF(LAG(revenue, 12) OVER (PARTITION BY store_id ORDER BY month), 0), 2) AS yoy_growth_pct,
       CASE WHEN revenue > LAG(revenue, 1) OVER (PARTITION BY store_id ORDER BY month) THEN 'UP'
            WHEN revenue < LAG(revenue, 1) OVER (PARTITION BY store_id ORDER BY month) THEN 'DOWN'
            ELSE 'FLAT/N-A' END AS flag
FROM monthly
ORDER BY store_id, month;

/* ============================================================
   SECTION C: GAPS-AND-ISLANDS (25)
   ------------------------------------------------------------ */
/* Q51. */
WITH monthly AS (
    SELECT cust_id, DATE_TRUNC('month', order_date)::date AS month FROM sales.orders GROUP BY cust_id, DATE_TRUNC('month', order_date)
),
numbered AS (
    SELECT cust_id, month, (EXTRACT(YEAR FROM month) * 12 + EXTRACT(MONTH FROM month))::int AS month_num,
           ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY month) AS rn
    FROM monthly
),
lengths AS (
    SELECT cust_id, (month_num - rn) AS island_key, COUNT(*) AS streak_length
    FROM numbered
    GROUP BY cust_id, (month_num - rn)
)
SELECT cust_id, MAX(streak_length) AS longest_active_month_streak
FROM lengths
GROUP BY cust_id
ORDER BY longest_active_month_streak DESC, cust_id;

/* Q52. */
WITH store_dates AS (
    SELECT DISTINCT store_id, order_date FROM sales.orders
),
numbered AS (
    SELECT store_id, order_date, ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY order_date) AS rn
    FROM store_dates
),
islands AS (
    SELECT store_id, order_date, order_date - (rn || ' days')::interval AS island_key
    FROM numbered
)
SELECT store_id, MIN(order_date) AS streak_start, MAX(order_date) AS streak_end, COUNT(*) AS streak_length_days
FROM islands
GROUP BY store_id, island_key
ORDER BY store_id, streak_start;

/* Q53. */
WITH monthly AS (
    SELECT store_id, DATE_TRUNC('month', order_date)::date AS month FROM sales.orders GROUP BY store_id, DATE_TRUNC('month', order_date)
),
numbered AS (
    SELECT store_id, month, (EXTRACT(YEAR FROM month) * 12 + EXTRACT(MONTH FROM month))::int AS month_num,
           ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY month) AS rn
    FROM monthly
)
SELECT store_id, MIN(month) AS island_start, MAX(month) AS island_end, COUNT(*) AS months_with_revenue
FROM numbered
GROUP BY store_id, (month_num - rn)
ORDER BY store_id, island_start;

/* Q54. */
WITH monthly AS (
    SELECT oi.prod_id AS product_id, DATE_TRUNC('month', o.order_date)::date AS month
    FROM sales.order_items oi JOIN sales.orders o ON oi.order_id = o.order_id
    GROUP BY oi.prod_id, DATE_TRUNC('month', o.order_date)
),
numbered AS (
    SELECT product_id, month, (EXTRACT(YEAR FROM month) * 12 + EXTRACT(MONTH FROM month))::int AS month_num,
           ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY month) AS rn
    FROM monthly
),
lengths AS (
    SELECT product_id, (month_num - rn) AS island_key, COUNT(*) AS streak_length
    FROM numbered
    GROUP BY product_id, (month_num - rn)
)
SELECT product_id, MAX(streak_length) AS longest_continuous_selling_months
FROM lengths
GROUP BY product_id
ORDER BY longest_continuous_selling_months DESC, product_id;

/* Q55. */
WITH weekly AS (
    SELECT cust_id, DATE_TRUNC('week', order_date)::date AS week FROM sales.orders GROUP BY cust_id, DATE_TRUNC('week', order_date)
),
numbered AS (
    SELECT cust_id, week, ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY week) AS rn
    FROM weekly
),
islands AS (
    SELECT cust_id, week, week - (rn || ' weeks')::interval AS island_key
    FROM numbered
)
SELECT cust_id, MIN(week) AS streak_start, MAX(week) AS streak_end, COUNT(*) AS consecutive_weeks
FROM islands
GROUP BY cust_id, island_key
ORDER BY cust_id, streak_start;

/* Q56. */
WITH months AS (
    SELECT generate_series('2024-01-01'::date, '2026-02-01'::date, '1 month'::interval)::date AS month
),
store_months AS (
    SELECT s.store_id, m.month FROM stores.stores s CROSS JOIN months m
),
rev AS (
    SELECT store_id, DATE_TRUNC('month', order_date)::date AS month, SUM(net_total) AS revenue
    FROM sales.orders GROUP BY store_id, DATE_TRUNC('month', order_date)
),
flagged AS (
    SELECT sm.store_id, sm.month, (r.revenue IS NULL) AS is_gap,
           (EXTRACT(YEAR FROM sm.month) * 12 + EXTRACT(MONTH FROM sm.month))::int AS month_num
    FROM store_months sm LEFT JOIN rev r ON r.store_id = sm.store_id AND r.month = sm.month
),
gap_rows AS (
    SELECT store_id, month, month_num,
           month_num - ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY month_num) AS island_key
    FROM flagged WHERE is_gap
)
SELECT store_id, MIN(month) AS gap_start, MAX(month) AS gap_end, COUNT(*) AS gap_length_months
FROM gap_rows
GROUP BY store_id, island_key
ORDER BY store_id, gap_start;

/* Q57. */
WITH ordered AS (
    SELECT product_id, review_id, review_date, rating,
           (rating = 5) AS is_five,
           ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY review_date, review_id) AS rn
    FROM customers.reviews
),
grp AS (
    SELECT *, rn - ROW_NUMBER() OVER (PARTITION BY product_id, is_five ORDER BY rn) AS grp_key
    FROM ordered
)
SELECT product_id, MIN(review_date) AS run_start, MAX(review_date) AS run_end, COUNT(*) AS run_length
FROM grp
WHERE is_five
GROUP BY product_id, grp_key
ORDER BY product_id, run_start;

/* Q58. */
WITH ordered AS (
    SELECT shipment_id, courier_name, shipped_date, delivered_date,
           (delivered_date - shipped_date <= 3) AS on_time,
           ROW_NUMBER() OVER (PARTITION BY courier_name ORDER BY shipped_date, shipment_id) AS rn
    FROM sales.shipments
    WHERE shipped_date IS NOT NULL AND delivered_date IS NOT NULL
),
grp AS (
    SELECT *, rn - ROW_NUMBER() OVER (PARTITION BY courier_name, on_time ORDER BY rn) AS grp_key
    FROM ordered
)
SELECT courier_name, MIN(shipped_date) AS streak_start, MAX(shipped_date) AS streak_end, COUNT(*) AS streak_length
FROM grp
WHERE on_time
GROUP BY courier_name, grp_key
ORDER BY courier_name, streak_start;

/* Q59. */
WITH slips AS (
    SELECT DISTINCT employee_id, salary_year,
           CASE salary_month WHEN 'January' THEN 1 WHEN 'February' THEN 2 WHEN 'March' THEN 3 WHEN 'April' THEN 4
                WHEN 'May' THEN 5 WHEN 'June' THEN 6 WHEN 'July' THEN 7 WHEN 'August' THEN 8
                WHEN 'September' THEN 9 WHEN 'October' THEN 10 WHEN 'November' THEN 11 ELSE 12 END AS month_num_raw
    FROM payroll.pay_slips
),
months AS (
    SELECT employee_id, MAKE_DATE(salary_year, month_num_raw, 1) AS month FROM slips
),
changes AS (
    SELECT record_id AS employee_id, DATE_TRUNC('month', changed_at)::date AS month
    FROM audit.record_changes
    WHERE table_name = 'employees' AND column_name = 'salary'
),
flagged AS (
    SELECT m.employee_id, m.month, (c.month IS NOT NULL) AS changed_this_month,
           (EXTRACT(YEAR FROM m.month) * 12 + EXTRACT(MONTH FROM m.month))::int AS month_num
    FROM months m LEFT JOIN changes c ON c.employee_id = m.employee_id AND c.month = m.month
),
grp AS (
    SELECT employee_id, month, changed_this_month,
           ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY month_num) AS rn,
           ROW_NUMBER() OVER (PARTITION BY employee_id, changed_this_month ORDER BY month_num) AS rn2
    FROM flagged
)
SELECT employee_id, MIN(month) AS streak_start, MAX(month) AS streak_end, COUNT(*) AS months_unchanged
FROM grp
WHERE NOT changed_this_month
GROUP BY employee_id, (rn - rn2)
ORDER BY employee_id, streak_start;

/* Q60. */
WITH ordered AS (
    SELECT warehouse_id, product_id, snapshot_date, quantity_on_hand,
           (quantity_on_hand > 0) AS in_stock,
           ROW_NUMBER() OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date) AS rn
    FROM supply_chain.inventory_snapshots
),
grp AS (
    SELECT *, rn - ROW_NUMBER() OVER (PARTITION BY warehouse_id, product_id, in_stock ORDER BY rn) AS grp_key
    FROM ordered
)
SELECT warehouse_id, product_id, MIN(snapshot_date) AS period_start, MAX(snapshot_date) AS period_end, COUNT(*) AS days_in_stock
FROM grp
WHERE in_stock
GROUP BY warehouse_id, product_id, grp_key
ORDER BY warehouse_id, product_id, period_start;

/* Q61. */
WITH cust_dates AS (
    SELECT DISTINCT customer_id, view_timestamp::date AS view_date FROM web_events.page_views WHERE customer_id IS NOT NULL
),
numbered AS (
    SELECT customer_id, view_date, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY view_date) AS rn
    FROM cust_dates
),
islands AS (
    SELECT customer_id, view_date, view_date - (rn || ' days')::interval AS island_key
    FROM numbered
),
lengths AS (
    SELECT customer_id, island_key, COUNT(*) AS streak_length FROM islands GROUP BY customer_id, island_key
)
SELECT customer_id, MAX(streak_length) AS longest_login_streak_days
FROM lengths
GROUP BY customer_id
ORDER BY longest_login_streak_days DESC, customer_id;

/* Q62. */
WITH monthly AS (
    SELECT o.store_id, DATE_TRUNC('month', o.order_date)::date AS month,
           SUM(oi.quantity * oi.unit_price) - SUM(oi.quantity * p.cost_price) AS profit
    FROM sales.order_items oi
    JOIN sales.orders o ON oi.order_id = o.order_id
    JOIN products.products p ON oi.prod_id = p.product_id
    GROUP BY o.store_id, DATE_TRUNC('month', o.order_date)
),
numbered AS (
    SELECT store_id, month, (profit > 0) AS profitable,
           (EXTRACT(YEAR FROM month) * 12 + EXTRACT(MONTH FROM month))::int AS month_num,
           ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY month) AS rn
    FROM monthly
),
grp AS (
    SELECT *, month_num - ROW_NUMBER() OVER (PARTITION BY store_id, profitable ORDER BY month_num) AS grp_key
    FROM numbered
)
SELECT store_id, MIN(month) AS island_start, MAX(month) AS island_end, COUNT(*) AS months_profitable
FROM grp
WHERE profitable
GROUP BY store_id, grp_key
ORDER BY store_id, island_start;

/* Q63. */
WITH changes AS (
    SELECT record_id AS product_id, changed_at, new_value::numeric AS price,
           LEAD(changed_at) OVER (PARTITION BY record_id ORDER BY changed_at) AS next_change_at
    FROM audit.record_changes
    WHERE table_name = 'products' AND column_name = 'price'
)
SELECT product_id, price AS stable_price, changed_at AS period_start, next_change_at AS period_end,
       COALESCE(next_change_at::date, CURRENT_DATE) - changed_at::date AS days_stable
FROM changes
ORDER BY product_id, period_start;

/* Q64. */
WITH months AS (
    SELECT generate_series('2024-01-01'::date, '2026-02-01'::date, '1 month'::interval)::date AS month
),
base AS (
    SELECT r.region_id, r.region_name, m.month, COALESCE(SUM(o.net_total), 0) AS revenue
    FROM core.dim_region r
    CROSS JOIN months m
    LEFT JOIN stores.stores s ON s.region_id = r.region_id
    LEFT JOIN sales.orders o ON o.store_id = s.store_id AND DATE_TRUNC('month', o.order_date) = m.month
    GROUP BY r.region_id, r.region_name, m.month
),
growth AS (
    SELECT region_id, region_name, month, revenue,
           (revenue > LAG(revenue) OVER (PARTITION BY region_id ORDER BY month)) AS is_positive,
           (EXTRACT(YEAR FROM month) * 12 + EXTRACT(MONTH FROM month))::int AS month_num
    FROM base
),
grp AS (
    SELECT *, month_num - ROW_NUMBER() OVER (PARTITION BY region_id, is_positive ORDER BY month_num) AS grp_key
    FROM growth
)
SELECT region_id, region_name, MIN(month) AS streak_start, MAX(month) AS streak_end, COUNT(*) AS streak_length_months
FROM grp
WHERE is_positive
GROUP BY region_id, region_name, grp_key
ORDER BY region_id, streak_start;

/* Q65. */
WITH ordered AS (
    SELECT order_id, cust_id, order_date, order_status,
           ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS rn
    FROM sales.orders
),
grp AS (
    SELECT *, rn - ROW_NUMBER() OVER (PARTITION BY cust_id, order_status ORDER BY rn) AS grp_key
    FROM ordered
)
SELECT cust_id, order_status, MIN(order_date) AS run_start, MAX(order_date) AS run_end, COUNT(*) AS run_length
FROM grp
GROUP BY cust_id, order_status, grp_key
ORDER BY cust_id, run_start;

/* Q66. */
WITH monthly AS (
    SELECT cust_id, DATE_TRUNC('month', order_date)::date AS month FROM sales.orders GROUP BY cust_id, DATE_TRUNC('month', order_date)
),
numbered AS (
    SELECT cust_id, month, (EXTRACT(YEAR FROM month) * 12 + EXTRACT(MONTH FROM month))::int AS month_num,
           ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY month) AS rn
    FROM monthly
)
SELECT cust_id, MIN(month) AS island_start, MAX(month) AS island_end, COUNT(*) AS months_active
FROM numbered
GROUP BY cust_id, (month_num - rn)
ORDER BY cust_id, island_start;

/* Q67. */
WITH daily AS (
    SELECT product_id, snapshot_date, SUM(quantity_on_hand) AS total_qty
    FROM supply_chain.inventory_snapshots
    GROUP BY product_id, snapshot_date
),
numbered AS (
    SELECT product_id, snapshot_date, (total_qty = 0) AS out_of_stock,
           ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY snapshot_date) AS rn
    FROM daily
),
grp AS (
    SELECT *, rn - ROW_NUMBER() OVER (PARTITION BY product_id, out_of_stock ORDER BY rn) AS grp_key
    FROM numbered
),
gaps AS (
    SELECT product_id, grp_key, COUNT(*) AS gap_length_days
    FROM grp WHERE out_of_stock
    GROUP BY product_id, grp_key
)
SELECT product_id, MAX(gap_length_days) AS longest_out_of_stock_days
FROM gaps
GROUP BY product_id
ORDER BY longest_out_of_stock_days DESC, product_id;

/* Q68. */
WITH quarterly AS (
    SELECT b.brand_name, DATE_TRUNC('quarter', o.order_date)::date AS quarter, SUM(oi.quantity * oi.unit_price) AS revenue
    FROM sales.order_items oi
    JOIN sales.orders o ON oi.order_id = o.order_id
    JOIN products.products p ON oi.prod_id = p.product_id
    JOIN core.dim_brand b ON p.brand_id = b.brand_id
    GROUP BY b.brand_name, DATE_TRUNC('quarter', o.order_date)
),
growth AS (
    SELECT brand_name, quarter, revenue,
           (revenue > LAG(revenue) OVER (PARTITION BY brand_name ORDER BY quarter)) AS is_growth,
           ROW_NUMBER() OVER (PARTITION BY brand_name ORDER BY quarter) AS rn
    FROM quarterly
),
grp AS (
    SELECT *, rn - ROW_NUMBER() OVER (PARTITION BY brand_name, is_growth ORDER BY rn) AS grp_key
    FROM growth
)
SELECT brand_name, MIN(quarter) AS streak_start, MAX(quarter) AS streak_end, COUNT(*) AS consecutive_growth_quarters
FROM grp
WHERE is_growth
GROUP BY brand_name, grp_key
ORDER BY brand_name, streak_start;

/* Q69. */
WITH ordered AS (
    SELECT cust_id, order_date,
           order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date) AS gap_days,
           ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY order_date) AS rn
    FROM sales.orders
),
flagged AS (
    SELECT *, (gap_days IS NULL OR gap_days > 90) AS new_island FROM ordered
),
grp AS (
    SELECT *, SUM(CASE WHEN new_island THEN 1 ELSE 0 END) OVER (PARTITION BY cust_id ORDER BY rn) AS island_id
    FROM flagged
)
SELECT cust_id, island_id, MIN(order_date) AS island_start, MAX(order_date) AS island_end, COUNT(*) AS orders_in_island
FROM grp
GROUP BY cust_id, island_id
ORDER BY cust_id, island_start;

/* Q70. */
WITH weekly AS (
    SELECT campaign_id, DATE_TRUNC('week', spend_date)::date AS week
    FROM marketing.ads_spend
    GROUP BY campaign_id, DATE_TRUNC('week', spend_date)
),
numbered AS (
    SELECT campaign_id, week, ROW_NUMBER() OVER (PARTITION BY campaign_id ORDER BY week) AS rn
    FROM weekly
),
islands AS (
    SELECT campaign_id, week, week - (rn || ' weeks')::interval AS island_key
    FROM numbered
)
SELECT campaign_id, MIN(week) AS streak_start, MAX(week) AS streak_end, COUNT(*) AS consecutive_weeks
FROM islands
GROUP BY campaign_id, island_key
ORDER BY campaign_id, streak_start;

/* Q71. */
SELECT customer_id, tier,
       COALESCE(tier_updated_at::date, registration_date) AS run_start,
       CURRENT_DATE AS run_end,
       CURRENT_DATE - COALESCE(tier_updated_at::date, registration_date) AS run_length_days
FROM customers.customers
ORDER BY customer_id;

/* Q72. */
WITH daily AS (
    SELECT order_date, SUM(net_total) AS revenue FROM sales.orders GROUP BY order_date
),
numbered AS (
    SELECT order_date, revenue,
           (revenue > LAG(revenue) OVER (ORDER BY order_date)) AS is_win,
           ROW_NUMBER() OVER (ORDER BY order_date) AS rn
    FROM daily
),
grp AS (
    SELECT *, rn - ROW_NUMBER() OVER (PARTITION BY is_win ORDER BY rn) AS grp_key
    FROM numbered
)
SELECT MIN(order_date) AS streak_start, MAX(order_date) AS streak_end, COUNT(*) AS winning_streak_days
FROM grp
WHERE is_win
GROUP BY grp_key
ORDER BY streak_start;

/* Q73. */
WITH monthly AS (
    SELECT o.cust_id, DATE_TRUNC('month', r.return_date)::date AS month
    FROM sales.returns r JOIN sales.orders o ON r.order_id = o.order_id
    GROUP BY o.cust_id, DATE_TRUNC('month', r.return_date)
),
numbered AS (
    SELECT cust_id, month, (EXTRACT(YEAR FROM month) * 12 + EXTRACT(MONTH FROM month))::int AS month_num,
           ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY month) AS rn
    FROM monthly
)
SELECT cust_id, MIN(month) AS island_start, MAX(month) AS island_end, COUNT(*) AS months_with_refunds
FROM numbered
GROUP BY cust_id, (month_num - rn)
ORDER BY cust_id, island_start;

/* Q74. */
WITH slips AS (
    SELECT employee_id, salary_year,
           CASE salary_month WHEN 'January' THEN 1 WHEN 'February' THEN 2 WHEN 'March' THEN 3 WHEN 'April' THEN 4
                WHEN 'May' THEN 5 WHEN 'June' THEN 6 WHEN 'July' THEN 7 WHEN 'August' THEN 8
                WHEN 'September' THEN 9 WHEN 'October' THEN 10 WHEN 'November' THEN 11 ELSE 12 END AS month_num_raw
    FROM payroll.pay_slips
    GROUP BY employee_id, salary_year, salary_month
),
numbered AS (
    SELECT employee_id, (salary_year * 12 + month_num_raw) AS month_num,
           ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY salary_year, month_num_raw) AS rn
    FROM slips
),
lengths AS (
    SELECT employee_id, (month_num - rn) AS grp_key, COUNT(*) AS run_length
    FROM numbered
    GROUP BY employee_id, (month_num - rn)
)
SELECT employee_id, MAX(run_length) AS longest_consecutive_payroll_months
FROM lengths
GROUP BY employee_id
ORDER BY longest_consecutive_payroll_months DESC, employee_id;

/* Q75. */
WITH monthly AS (
    SELECT cust_id, DATE_TRUNC('month', order_date)::date AS month FROM sales.orders GROUP BY cust_id, DATE_TRUNC('month', order_date)
),
numbered AS (
    SELECT cust_id, month, (EXTRACT(YEAR FROM month) * 12 + EXTRACT(MONTH FROM month))::int AS month_num,
           ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY month) AS rn
    FROM monthly
)
SELECT cust_id AS customer, MIN(month) AS island_start, MAX(month) AS island_end, COUNT(*) AS length
FROM numbered
GROUP BY cust_id, (month_num - rn)
ORDER BY customer, island_start;

/* ============================================================
   SECTION D: CHURN, SESSIONS & CHANGE DETECTION (25)
   ------------------------------------------------------------ */
/* Q76. */
SELECT cust_id, MAX(order_date) AS last_order_date, CURRENT_DATE - MAX(order_date) AS days_since_last_order
FROM sales.orders
GROUP BY cust_id
HAVING CURRENT_DATE - MAX(order_date) > 90
ORDER BY days_since_last_order DESC;

/* Q77. */
WITH ordered AS (
    SELECT cust_id, order_date,
           order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date) AS gap_days
    FROM sales.orders
)
SELECT cust_id, order_date AS reactivation_date, gap_days
FROM ordered
WHERE gap_days > 90
ORDER BY cust_id, order_date;

/* Q78. */
WITH ordered AS (
    SELECT cust_id, order_date,
           MIN(order_date) OVER (PARTITION BY cust_id) AS first_order_date,
           LEAD(order_date) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS next_order_date
    FROM sales.orders
)
SELECT cust_id, first_order_date, next_order_date AS second_order_date,
       next_order_date - first_order_date AS days_to_second_order
FROM ordered
WHERE order_date = first_order_date
ORDER BY cust_id;

/* Q79. */
WITH ordered AS (
    SELECT customer_id, view_id, view_timestamp,
           EXTRACT(EPOCH FROM (view_timestamp - LAG(view_timestamp) OVER (PARTITION BY customer_id ORDER BY view_timestamp))) / 60 AS gap_minutes
    FROM web_events.page_views
    WHERE customer_id IS NOT NULL
),
flagged AS (
    SELECT *, (gap_minutes IS NULL OR gap_minutes > 30) AS new_session FROM ordered
)
SELECT customer_id, view_id, view_timestamp,
       SUM(CASE WHEN new_session THEN 1 ELSE 0 END) OVER (PARTITION BY customer_id ORDER BY view_timestamp) AS session_id
FROM flagged
ORDER BY customer_id, view_timestamp;

/* Q80. */
WITH ordered AS (
    SELECT customer_id, view_id, view_timestamp,
           EXTRACT(EPOCH FROM (view_timestamp - LAG(view_timestamp) OVER (PARTITION BY customer_id ORDER BY view_timestamp))) / 60 AS gap_minutes
    FROM web_events.page_views
    WHERE customer_id IS NOT NULL
),
flagged AS (
    SELECT *, (gap_minutes IS NULL OR gap_minutes > 30) AS new_session FROM ordered
),
sessioned AS (
    SELECT customer_id, view_id, view_timestamp,
           SUM(CASE WHEN new_session THEN 1 ELSE 0 END) OVER (PARTITION BY customer_id ORDER BY view_timestamp) AS session_id
    FROM flagged
)
SELECT customer_id, session_id,
       MIN(view_timestamp) AS session_start, MAX(view_timestamp) AS session_end,
       EXTRACT(EPOCH FROM (MAX(view_timestamp) - MIN(view_timestamp))) / 60 AS session_duration_minutes,
       COUNT(*) AS view_count
FROM sessioned
GROUP BY customer_id, session_id
ORDER BY customer_id, session_id;

/* Q81. */
SELECT record_id AS product_id, changed_at, old_value::numeric AS old_price, new_value::numeric AS new_price,
       ROUND(100.0 * (new_value::numeric - old_value::numeric) / NULLIF(old_value::numeric, 0), 2) AS pct_change
FROM audit.record_changes
WHERE table_name = 'products' AND column_name = 'price'
ORDER BY product_id, changed_at;

/* Q82. */
WITH changes AS (
    SELECT record_id AS product_id, changed_at, old_value::numeric AS old_price, new_value::numeric AS new_price,
           100.0 * (new_value::numeric - old_value::numeric) / NULLIF(old_value::numeric, 0) AS pct_change
    FROM audit.record_changes
    WHERE table_name = 'products' AND column_name = 'price'
)
SELECT product_id, changed_at, old_price, new_price, ROUND(pct_change, 2) AS pct_change
FROM changes
WHERE ABS(pct_change) > 50
ORDER BY ABS(pct_change) DESC;

/* Q83. */
WITH points_running AS (
    SELECT customer_id, date_earned, loyalty_id,
           SUM(points_earned) OVER (PARTITION BY customer_id ORDER BY date_earned, loyalty_id) AS cumulative_points
    FROM customers.loyalty_points
),
tiered AS (
    SELECT pr.customer_id, pr.date_earned, t.tier_name, t.tier_id
    FROM points_running pr
    JOIN loyalty.tiers t ON pr.cumulative_points BETWEEN t.min_points AND t.max_points
),
changes AS (
    SELECT customer_id, date_earned, tier_name, tier_id,
           LAG(tier_id) OVER (PARTITION BY customer_id ORDER BY date_earned) AS prev_tier_id,
           LAG(tier_name) OVER (PARTITION BY customer_id ORDER BY date_earned) AS prev_tier_name
    FROM tiered
)
SELECT customer_id, date_earned, prev_tier_name, tier_name AS new_tier_name,
       CASE WHEN tier_id > prev_tier_id THEN 'UPGRADE' WHEN tier_id < prev_tier_id THEN 'DOWNGRADE' END AS change_type
FROM changes
WHERE prev_tier_id IS NOT NULL AND tier_id <> prev_tier_id
ORDER BY customer_id, date_earned;

/* Q84. */
WITH ordered AS (
    SELECT warehouse_id, product_id, snapshot_date, quantity_on_hand,
           LAG(quantity_on_hand) OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date) AS prev_qty
    FROM supply_chain.inventory_snapshots
)
SELECT warehouse_id, product_id, snapshot_date, prev_qty, quantity_on_hand,
       CASE WHEN prev_qty > 0 AND quantity_on_hand = 0 THEN 'STOCK_OUT'
            WHEN prev_qty = 0 AND quantity_on_hand > 0 THEN 'RECOVERY' END AS event_type
FROM ordered
WHERE (prev_qty > 0 AND quantity_on_hand = 0) OR (prev_qty = 0 AND quantity_on_hand > 0)
ORDER BY warehouse_id, product_id, snapshot_date;

/* Q85. */
WITH ordered AS (
    SELECT product_id, review_date,
           rating,
           LAG(rating) OVER (PARTITION BY product_id ORDER BY review_date, review_id) AS prev_rating
    FROM customers.reviews
)
SELECT product_id, review_date, prev_rating, rating
FROM ordered
WHERE prev_rating IS NOT NULL AND rating < prev_rating
ORDER BY product_id, review_date;

/* Q86. */
WITH last_orders AS (
    SELECT cust_id, MAX(order_date) AS last_order_date FROM sales.orders GROUP BY cust_id
)
SELECT DATE_TRUNC('month', last_order_date)::date AS churn_cohort_month, COUNT(*) AS customers
FROM last_orders
GROUP BY DATE_TRUNC('month', last_order_date)
ORDER BY churn_cohort_month;

/* Q87. */
WITH monthly AS (
    SELECT store_id, DATE_TRUNC('month', order_date)::date AS month, SUM(net_total) AS revenue
    FROM sales.orders GROUP BY store_id, DATE_TRUNC('month', order_date)
),
flagged AS (
    SELECT store_id, month,
           (revenue < LAG(revenue) OVER (PARTITION BY store_id ORDER BY month)) AS is_decline,
           ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY month) AS rn
    FROM monthly
),
grp AS (
    SELECT *, rn - ROW_NUMBER() OVER (PARTITION BY store_id, is_decline ORDER BY rn) AS grp_key
    FROM flagged
)
SELECT store_id, MIN(month) AS decline_start, MAX(month) AS decline_end, COUNT(*) AS consecutive_declining_months
FROM grp
WHERE is_decline
GROUP BY store_id, grp_key
HAVING COUNT(*) >= 2
ORDER BY store_id, decline_start;

/* Q88. */
WITH ordered AS (
    SELECT customer_id, device_type, view_timestamp,
           EXTRACT(EPOCH FROM (view_timestamp - LAG(view_timestamp) OVER (PARTITION BY customer_id, device_type ORDER BY view_timestamp))) / 60 AS gap_minutes
    FROM web_events.page_views
    WHERE customer_id IS NOT NULL
),
flagged AS (
    SELECT *, (gap_minutes IS NULL OR gap_minutes > 30) AS new_session FROM ordered
),
sessioned AS (
    SELECT customer_id, device_type, view_timestamp,
           SUM(CASE WHEN new_session THEN 1 ELSE 0 END) OVER (PARTITION BY customer_id, device_type ORDER BY view_timestamp) AS session_id
    FROM flagged
),
sessions AS (
    SELECT device_type, view_timestamp::date AS day, customer_id, session_id,
           EXTRACT(EPOCH FROM (MAX(view_timestamp) - MIN(view_timestamp))) / 60 AS session_length_minutes
    FROM sessioned
    GROUP BY device_type, view_timestamp::date, customer_id, session_id
)
SELECT device_type, day, ROUND(AVG(session_length_minutes), 2) AS avg_session_length_minutes
FROM sessions
GROUP BY device_type, day
ORDER BY device_type, day;

/* Q89. */
WITH ordered AS (
    SELECT cust_id, order_id, order_date,
           LEAD(order_date) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS next_order_date
    FROM sales.orders
)
SELECT cust_id, order_date, next_order_date
FROM ordered
WHERE next_order_date IS NOT NULL AND next_order_date - order_date <= 1
ORDER BY cust_id, order_date;

/* Q90. */
SELECT record_id AS employee_id, changed_at, old_value::numeric AS old_salary, new_value::numeric AS new_salary,
       new_value::numeric - old_value::numeric AS change_amount,
       ROUND(100.0 * (new_value::numeric - old_value::numeric) / NULLIF(old_value::numeric, 0), 2) AS pct_change
FROM audit.record_changes
WHERE table_name = 'employees' AND column_name = 'salary'
ORDER BY employee_id, changed_at;

/* Q91. */
WITH events AS (
    SELECT o.order_id, o.order_date AS event_time, 'Placed' AS status FROM sales.orders o
    UNION ALL
    SELECT p.order_id, p.payment_date, 'Paid' FROM sales.payments p WHERE p.payment_date IS NOT NULL
    UNION ALL
    SELECT sh.order_id, sh.shipped_date, 'Shipped' FROM sales.shipments sh WHERE sh.shipped_date IS NOT NULL
    UNION ALL
    SELECT sh.order_id, sh.delivered_date, 'Delivered' FROM sales.shipments sh WHERE sh.delivered_date IS NOT NULL
    UNION ALL
    SELECT r.order_id, r.return_date, 'Returned' FROM sales.returns r WHERE r.return_date IS NOT NULL
),
ordered AS (
    SELECT order_id, event_time, status,
           LEAD(event_time) OVER (PARTITION BY order_id ORDER BY event_time) AS next_event_time
    FROM events
)
SELECT order_id, status, event_time AS status_start,
       COALESCE(next_event_time, CURRENT_DATE) - event_time AS days_in_status
FROM ordered
ORDER BY order_id, status_start;

/* Q92. */
WITH gaps AS (
    SELECT cust_id, order_date,
           order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date) AS gap_days
    FROM sales.orders
),
stats AS (
    SELECT cust_id,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY gap_days) AS median_gap,
           MAX(order_date) AS last_order_date
    FROM gaps WHERE gap_days IS NOT NULL
    GROUP BY cust_id
),
latest_gap AS (
    SELECT g.cust_id, g.gap_days AS latest_gap
    FROM gaps g
    JOIN stats s ON s.cust_id = g.cust_id AND g.order_date = s.last_order_date
)
SELECT lg.cust_id, lg.latest_gap, s.median_gap
FROM latest_gap lg
JOIN stats s ON s.cust_id = lg.cust_id
WHERE lg.latest_gap > 2 * s.median_gap
ORDER BY lg.cust_id;

/* Q93. */
WITH ordered AS (
    SELECT cust_id, order_date, net_total,
           FIRST_VALUE(net_total) OVER (PARTITION BY cust_id ORDER BY order_date, order_id) AS first_order_value,
           LAST_VALUE(net_total) OVER (PARTITION BY cust_id ORDER BY order_date, order_id
               ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_order_value
    FROM sales.orders
)
SELECT DISTINCT cust_id, first_order_value, last_order_value,
       last_order_value - first_order_value AS value_change,
       ROUND(100.0 * (last_order_value - first_order_value) / NULLIF(first_order_value, 0), 2) AS pct_change
FROM ordered
ORDER BY cust_id;

/* Q94. */
WITH monthly AS (
    SELECT campaign_id, DATE_TRUNC('month', spend_date)::date AS month, SUM(amount) AS spend
    FROM marketing.ads_spend GROUP BY campaign_id, DATE_TRUNC('month', spend_date)
),
growth AS (
    SELECT campaign_id, month, spend,
           LAG(spend) OVER (PARTITION BY campaign_id ORDER BY month) AS prev_spend
    FROM monthly
)
SELECT campaign_id, month, prev_spend, spend
FROM growth
WHERE prev_spend IS NOT NULL AND spend >= 2 * prev_spend
ORDER BY campaign_id, month;

/* Q95. */
WITH funnel AS (
    SELECT session_id, page_url, view_timestamp,
           CASE WHEN page_url LIKE '/product/%' THEN 'product'
                WHEN page_url = '/cart' THEN 'cart'
                WHEN page_url = '/checkout' THEN 'checkout' END AS funnel_step
    FROM web_events.page_views
    WHERE page_url LIKE '/product/%' OR page_url IN ('/cart', '/checkout')
),
ordered AS (
    SELECT session_id, funnel_step, view_timestamp,
           LEAD(funnel_step) OVER (PARTITION BY session_id ORDER BY view_timestamp) AS next_step,
           LEAD(view_timestamp) OVER (PARTITION BY session_id ORDER BY view_timestamp) AS next_time
    FROM funnel
)
SELECT session_id, funnel_step, view_timestamp AS step_time, next_step, next_time,
       EXTRACT(EPOCH FROM (next_time - view_timestamp)) / 60 AS minutes_to_next_step
FROM ordered
WHERE (funnel_step = 'product' AND next_step = 'cart') OR (funnel_step = 'cart' AND next_step = 'checkout')
ORDER BY session_id, step_time;

/* Q96. */
WITH monthly AS (
    SELECT cust_id, DATE_TRUNC('month', order_date)::date AS month, SUM(net_total) AS spend
    FROM sales.orders GROUP BY cust_id, DATE_TRUNC('month', order_date)
),
peaks AS (
    SELECT cust_id, month, spend,
           MAX(spend) OVER (PARTITION BY cust_id) AS peak_spend
    FROM monthly
),
peak_month AS (
    SELECT cust_id, MIN(month) AS peak_month FROM peaks WHERE spend = peak_spend GROUP BY cust_id
)
SELECT pm.cust_id, pm.peak_month, mo.spend AS peak_spend
FROM peak_month pm
JOIN monthly mo ON mo.cust_id = pm.cust_id AND mo.month = pm.peak_month
ORDER BY pm.cust_id;

/* Q97. */
WITH ordered AS (
    SELECT customer_id, call_id, call_start_time,
           EXTRACT(EPOCH FROM (call_start_time - LAG(call_start_time) OVER (PARTITION BY customer_id ORDER BY call_start_time))) / 3600 AS gap_hours
    FROM call_center.calls
    WHERE customer_id IS NOT NULL
),
flagged AS (
    SELECT *, (gap_hours IS NULL OR gap_hours > 1) AS new_burst FROM ordered
),
bursts AS (
    SELECT customer_id, call_id, call_start_time,
           SUM(CASE WHEN new_burst THEN 1 ELSE 0 END) OVER (PARTITION BY customer_id ORDER BY call_start_time) AS burst_id
    FROM flagged
)
SELECT customer_id, COUNT(DISTINCT burst_id) AS burst_count
FROM bursts
GROUP BY customer_id
ORDER BY customer_id;

/* Q98. */
WITH ordered AS (
    SELECT warehouse_id, product_id, snapshot_date, quantity_on_hand,
           LAG(quantity_on_hand) OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date) AS prev_qty
    FROM supply_chain.inventory_snapshots
)
SELECT warehouse_id, product_id, snapshot_date, prev_qty, quantity_on_hand,
       quantity_on_hand - prev_qty AS replenishment_size
FROM ordered
WHERE prev_qty IS NOT NULL AND quantity_on_hand > prev_qty
ORDER BY warehouse_id, product_id, snapshot_date;

/* Q99. */
WITH gaps AS (
    SELECT cust_id, order_date,
           order_date - LAG(order_date) OVER (PARTITION BY cust_id ORDER BY order_date) AS gap_to_prev
    FROM sales.orders
),
last_orders AS (
    SELECT cust_id, MAX(order_date) AS last_order_date FROM sales.orders GROUP BY cust_id
),
prior_gap AS (
    SELECT g.cust_id, g.gap_to_prev AS prior_gap
    FROM gaps g JOIN last_orders lo ON lo.cust_id = g.cust_id AND g.order_date = lo.last_order_date
)
SELECT lo.cust_id, lo.last_order_date, CURRENT_DATE - lo.last_order_date AS days_since_last_order,
       (CURRENT_DATE - lo.last_order_date > 90) AS churn_flag, pg.prior_gap
FROM last_orders lo
LEFT JOIN prior_gap pg ON pg.cust_id = lo.cust_id
ORDER BY lo.cust_id;

/* Q100. */
WITH changes AS (
    SELECT record_id AS product_id, changed_at, old_value::numeric AS old_price, new_value::numeric AS new_price,
           100.0 * (new_value::numeric - old_value::numeric) / NULLIF(old_value::numeric, 0) AS pct_change
    FROM audit.record_changes
    WHERE table_name = 'products' AND column_name = 'price'
)
SELECT product_id, changed_at, old_price, new_price, ROUND(pct_change, 2) AS pct_change,
       RANK() OVER (PARTITION BY product_id ORDER BY ABS(pct_change) DESC) AS change_rank
FROM changes
ORDER BY product_id, change_rank;

/* ============================================================
   END OF ANSWER KEY - Window Functions Part 3 - HARD LEVEL (100/100)
============================================================ */
