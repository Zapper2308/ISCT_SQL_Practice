/* ============================================================
   ANSWER KEY - Conditional Logic & Derived Columns (CRAZY LEVEL)
   Curriculum:   RetailMart V3
   Note: several Section A questions describe dimensions that have no
   backing columns in this schema (weight/distance, ip_country/velocity,
   review scores, lead source/pages, contract/support-level, etc.) -
   those are answered with clearly-labeled synthetic VALUES() demo data
   to demonstrate the decision-table technique honestly, rather than
   inventing fake columns on real tables.
   ============================================================ */

/* ============================================================
   SECTION A: DECISION TABLES (25)
   ------------------------------------------------------------ */

/* Q1. */
WITH order_counts AS (
  SELECT cust_id, COUNT(*) AS lifetime_orders
  FROM sales.orders
  GROUP BY cust_id
)
SELECT m.customer_id, m.points_balance, COALESCE(oc.lifetime_orders, 0) AS lifetime_orders,
  CASE
    WHEN m.points_balance >= 5000 AND COALESCE(oc.lifetime_orders, 0) >= 20 THEN 'Platinum'
    WHEN m.points_balance >= 2000 AND COALESCE(oc.lifetime_orders, 0) >= 10 THEN 'Gold'
    WHEN m.points_balance >= 500  AND COALESCE(oc.lifetime_orders, 0) >= 3  THEN 'Silver'
    ELSE 'Bronze'
  END AS computed_tier
FROM loyalty.members m
LEFT JOIN order_counts oc ON oc.cust_id = m.customer_id;

/* Q2. */
SELECT b.brand_name, r.region_name, t.tier_level,
  CASE t.tier_level
    WHEN 'Platinum' THEN 15
    WHEN 'Gold' THEN 10
    WHEN 'Silver' THEN 5
    ELSE 0
  END AS discount_pct
FROM core.dim_brand b
CROSS JOIN core.dim_region r
CROSS JOIN (VALUES ('Platinum'), ('Gold'), ('Silver'), ('Bronze')) AS t(tier_level);

/* Q3. */
-- weight/distance are not real columns in this schema; demo data below
SELECT weight_kg, distance_km, tier,
  CASE
    WHEN tier = 'Platinum' THEN 0
    WHEN weight_kg <= 2 AND distance_km <= 100 THEN 40
    WHEN weight_kg <= 2 THEN 70
    WHEN weight_kg <= 10 AND distance_km <= 100 THEN 90
    ELSE 150
  END AS shipping_cost
FROM (VALUES (1.5, 50, 'Bronze'), (1.5, 500, 'Silver'), (8, 50, 'Gold'), (8, 800, 'Bronze'), (0.5, 20, 'Platinum'))
  AS demo(weight_kg, distance_km, tier);

/* Q4. */
SELECT r.return_id, r.refund_amount,
  (CURRENT_DATE - c.registration_date) AS tenure_days, c.tier,
  CASE
    WHEN r.refund_amount <= 1000 AND (CURRENT_DATE - c.registration_date) > 180 THEN 'Auto-Approve'
    WHEN c.tier IN ('Gold', 'Platinum') AND r.refund_amount <= 5000 THEN 'Auto-Approve'
    ELSE 'Manual Review'
  END AS approval_decision
FROM sales.returns r
JOIN sales.orders o ON o.order_id = r.order_id
JOIN customers.customers c ON c.customer_id = o.cust_id;

/* Q5. */
-- ip_country/velocity are not real columns in this schema; demo data below
SELECT order_amount, ip_country, orders_last_hour,
  CASE
    WHEN orders_last_hour >= 5 THEN 'Block'
    WHEN ip_country <> 'India' AND order_amount > 20000 THEN 'Review'
    WHEN order_amount > 50000 THEN 'Review'
    ELSE 'Allow'
  END AS fraud_decision
FROM (VALUES (1500, 'India', 1), (75000, 'USA', 1), (2000, 'India', 6), (30000, 'UK', 2))
  AS demo(order_amount, ip_country, orders_last_hour);

/* Q6. */
WITH spend AS (
  SELECT cust_id, SUM(net_total) AS total_spend
  FROM sales.orders
  GROUP BY cust_id
)
SELECT m.customer_id, s.total_spend, t.tier_name,
  ROUND(s.total_spend *
    CASE t.tier_name
      WHEN 'Platinum' THEN 0.05
      WHEN 'Gold' THEN 0.03
      WHEN 'Silver' THEN 0.02
      ELSE 0.01
    END) AS bonus_points
FROM loyalty.members m
JOIN loyalty.tiers t ON t.tier_id = m.tier_id
JOIN spend s ON s.cust_id = m.customer_id;

/* Q7. */
WITH monthly AS (
  SELECT cust_id, DATE_TRUNC('month', order_date) AS order_month,
         COUNT(*) AS monthly_orders, AVG(net_total) AS avg_basket
  FROM sales.orders
  GROUP BY cust_id, DATE_TRUNC('month', order_date)
)
SELECT cust_id, order_month, monthly_orders, avg_basket,
  CASE
    WHEN monthly_orders >= 4 AND avg_basket >= 3000 THEN 'Premium Plan'
    WHEN monthly_orders >= 2 THEN 'Standard Plan'
    ELSE 'Basic Plan'
  END AS suggested_plan
FROM monthly;

/* Q8. */
-- tickets have no linked product_id/price; demo data below combines a real-shaped scenario
SELECT customer_tier, product_price, urgency,
  CASE
    WHEN urgency = 'High' AND customer_tier IN ('Gold', 'Platinum') THEN 'Critical'
    WHEN urgency = 'High' THEN 'High'
    WHEN product_price > 20000 THEN 'High'
    WHEN customer_tier IN ('Gold', 'Platinum') THEN 'Medium'
    ELSE 'Low'
  END AS computed_priority
FROM (VALUES ('Platinum', 25000, 'High'), ('Bronze', 500, 'Low'), ('Gold', 1200, 'Medium'), ('Silver', 30000, 'Low'))
  AS demo(customer_tier, product_price, urgency);

/* Q9. */
-- geo/season are not tracked in marketing.ads_spend; demo data below
SELECT platform, geo, season,
  CASE
    WHEN platform = 'Google' AND season = 'Festive' THEN 45.00
    WHEN platform = 'Google' THEN 25.00
    WHEN platform = 'Facebook' AND geo = 'Metro' THEN 30.00
    WHEN platform = 'Facebook' THEN 18.00
    ELSE 12.00
  END AS suggested_bid
FROM (VALUES ('Google', 'Metro', 'Festive'), ('Google', 'Rural', 'Regular'),
             ('Facebook', 'Metro', 'Regular'), ('Instagram', 'Metro', 'Festive'))
  AS demo(platform, geo, season);

/* Q10. */
WITH velocity AS (
  SELECT oi.prod_id, SUM(oi.quantity) AS units_sold_90d
  FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  WHERE o.order_date >= CURRENT_DATE - INTERVAL '90 days'
  GROUP BY oi.prod_id
)
SELECT i.store_id, i.product_id, i.quantity_on_hand, COALESCE(v.units_sold_90d, 0) AS units_sold_90d,
  CASE
    WHEN COALESCE(v.units_sold_90d, 0) > 100 AND i.quantity_on_hand < i.reorder_level THEN i.reorder_level * 3
    WHEN COALESCE(v.units_sold_90d, 0) > 50  AND i.quantity_on_hand < i.reorder_level THEN i.reorder_level * 2
    WHEN i.quantity_on_hand < i.reorder_level THEN i.reorder_level
    ELSE 0
  END AS suggested_restock_qty
FROM products.inventory i
LEFT JOIN velocity v ON v.prod_id = i.product_id;

/* Q11. */
-- employee review scores are not tracked in this schema; demo data below
SELECT review_score, tenure_years, dept_name,
  CASE
    WHEN review_score >= 4.5 AND tenure_years >= 3 THEN 20
    WHEN review_score >= 4.0 THEN 12
    WHEN review_score >= 3.0 THEN 6
    ELSE 0
  END AS bonus_pct
FROM (VALUES (4.8, 5, 'Sales'), (3.5, 1, 'IT'), (4.2, 4, 'Operations'), (2.5, 2, 'Finance'))
  AS demo(review_score, tenure_years, dept_name);

/* Q12. */
-- revenue_generated/violations are not tracked per employee; deterministic demo values derived below
SELECT e.employee_id, e.first_name, e.last_name,
  EXTRACT(YEAR FROM AGE(CURRENT_DATE, e.joining_date))::int AS tenure_years,
  (e.employee_id % 10) * 100000 AS demo_revenue_generated,
  (e.employee_id % 3) AS demo_violations,
  CASE
    WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, e.joining_date)) >= 2
         AND (e.employee_id % 10) * 100000 > 500000
         AND (e.employee_id % 3) = 0 THEN 'Eligible'
    ELSE 'Not Eligible'
  END AS promotion_flag
FROM stores.employees e;

/* Q13. */
SELECT p.employee_id, p.gross_salary, tb.tax_rate AS base_rate,
  CASE
    WHEN (p.employee_id % 4) >= 2 THEN tb.tax_rate - 2   -- demo dependents discount, dependents not tracked
    ELSE tb.tax_rate
  END AS effective_rate
FROM payroll.pay_slips p
JOIN payroll.tax_brackets tb
  ON p.gross_salary BETWEEN tb.min_salary AND tb.max_salary;

/* Q14. */
-- sales-rep commission structure is not tracked in this schema; demo data below
SELECT sales_amount, employee_level, product_category,
  ROUND(sales_amount *
    CASE
      WHEN employee_level = 'Senior' AND product_category = 'Electronics' THEN 0.08
      WHEN employee_level = 'Senior' THEN 0.05
      WHEN employee_level = 'Junior' THEN 0.03
      ELSE 0.02
    END, 2) AS commission
FROM (VALUES (50000, 'Senior', 'Electronics'), (20000, 'Junior', 'Apparel'), (80000, 'Senior', 'Grocery'))
  AS demo(sales_amount, employee_level, product_category);

/* Q15. */
-- lead-generation data is not tracked in this schema; demo data below
SELECT source, pages_viewed, actions_taken,
  (CASE source WHEN 'Organic' THEN 20 WHEN 'Paid' THEN 10 ELSE 5 END)
  + pages_viewed * 2 + actions_taken * 5 AS lead_score
FROM (VALUES ('Organic', 8, 2), ('Paid', 3, 0), ('Referral', 15, 4))
  AS demo(source, pages_viewed, actions_taken);

/* Q16. */
WITH last_order AS (
  SELECT cust_id, MAX(order_date) AS last_order_date
  FROM sales.orders GROUP BY cust_id
),
ticket_counts AS (
  SELECT customer_id, COUNT(*) AS ticket_count
  FROM support.tickets GROUP BY customer_id
)
SELECT c.customer_id, lo.last_order_date, COALESCE(tc.ticket_count, 0) AS ticket_count, c.tier,
  CASE
    WHEN lo.last_order_date IS NULL THEN 'No Orders'
    WHEN CURRENT_DATE - lo.last_order_date > 180 AND COALESCE(tc.ticket_count, 0) >= 3 THEN 'High Risk'
    WHEN CURRENT_DATE - lo.last_order_date > 90 THEN 'Medium Risk'
    ELSE 'Low Risk'
  END AS churn_risk_band
FROM customers.customers c
LEFT JOIN last_order lo ON lo.cust_id = c.customer_id
LEFT JOIN ticket_counts tc ON tc.customer_id = c.customer_id;

/* Q17. */
WITH spend AS (
  SELECT cust_id, SUM(net_total) AS total_spend FROM sales.orders GROUP BY cust_id
),
engagement AS (
  SELECT customer_id, COUNT(*) AS page_view_count FROM web_events.page_views GROUP BY customer_id
)
SELECT c.customer_id, COALESCE(s.total_spend, 0) AS total_spend, COALESCE(e.page_view_count, 0) AS page_view_count,
  (CURRENT_DATE - c.registration_date) AS tenure_days,
  CASE
    WHEN COALESCE(s.total_spend, 0) > 100000 AND COALESCE(e.page_view_count, 0) > 50 THEN 'VIP Platinum'
    WHEN COALESCE(s.total_spend, 0) > 50000 THEN 'VIP Gold'
    WHEN COALESCE(s.total_spend, 0) > 10000 THEN 'VIP Silver'
    ELSE 'Standard'
  END AS vip_level
FROM customers.customers c
LEFT JOIN spend s ON s.cust_id = c.customer_id
LEFT JOIN engagement e ON e.customer_id = c.customer_id;

/* Q18. */
WITH ltv AS (
  SELECT cust_id, SUM(net_total) AS lifetime_value FROM sales.orders GROUP BY cust_id
)
SELECT r.return_id, r.refund_amount, r.reason, COALESCE(l.lifetime_value, 0) AS ltv,
  CASE
    WHEN r.refund_amount <= 2000 THEN 'Auto-Approve'
    WHEN COALESCE(l.lifetime_value, 0) > 50000 AND r.refund_amount <= 10000 THEN 'Auto-Approve'
    WHEN r.reason ILIKE '%defect%' THEN 'Auto-Approve'
    ELSE 'Manual Review'
  END AS decision
FROM sales.returns r
JOIN sales.orders o ON o.order_id = r.order_id
LEFT JOIN ltv l ON l.cust_id = o.cust_id;

/* Q19. */
SELECT c.customer_id, c.tier, (CURRENT_DATE - c.registration_date) AS history_days, a.state,
  CASE c.tier
    WHEN 'Platinum' THEN 200000
    WHEN 'Gold' THEN 100000
    WHEN 'Silver' THEN 50000
    ELSE 20000
  END
  + CASE WHEN (CURRENT_DATE - c.registration_date) > 730 THEN 20000 ELSE 0 END AS credit_limit
FROM customers.customers c
LEFT JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = TRUE;

/* Q20. */
-- performance-review scores are not tracked in this schema; deterministic demo score derived below
SELECT e.employee_id, e.salary, EXTRACT(YEAR FROM AGE(CURRENT_DATE, e.joining_date))::int AS tenure_years,
  (e.employee_id % 5) AS demo_performance_score,
  CASE
    WHEN (e.employee_id % 5) >= 4 AND EXTRACT(YEAR FROM AGE(CURRENT_DATE, e.joining_date)) >= 1 THEN 'Eligible'
    ELSE 'Not Eligible'
  END AS bonus_eligible
FROM stores.employees e;

/* Q21. */
-- time-of-day/device are not tracked on orders in this schema; demo data below
SELECT order_amount, hour_of_day, device,
  (CASE WHEN order_amount > 50000 THEN 30 ELSE 5 END)
  + (CASE WHEN hour_of_day BETWEEN 0 AND 5 THEN 25 ELSE 0 END)
  + (CASE WHEN device = 'Unknown' THEN 20 ELSE 0 END) AS risk_score
FROM (VALUES (75000, 3, 'Unknown'), (1500, 14, 'Mobile'), (2000, 2, 'Desktop'))
  AS demo(order_amount, hour_of_day, device);

/* Q22. This needs customer interest/browsing-preference data (e.g. viewed categories) and a recommendation-affinity model, neither of which exists in this schema beyond raw page_views/order rows, so it can't be answered as a real query here. */

/* Q23. */
WITH order_stats AS (
  SELECT cust_id, COUNT(*) AS order_count
  FROM sales.orders GROUP BY cust_id
)
SELECT c.customer_id, c.tier, a.state, COALESCE(os.order_count, 0) AS order_count,
  CASE
    WHEN c.tier IN ('Gold', 'Platinum') AND COALESCE(os.order_count, 0) >= 10 THEN 'High-Value Loyalist'
    WHEN COALESCE(os.order_count, 0) >= 10 THEN 'Frequent Bargain Shopper'
    WHEN COALESCE(os.order_count, 0) = 0 THEN 'Prospect'
    ELSE 'Occasional Shopper'
  END AS marketing_segment
FROM customers.customers c
LEFT JOIN customers.addresses a ON a.customer_id = c.customer_id AND a.is_default = TRUE
LEFT JOIN order_stats os ON os.cust_id = c.customer_id;

/* Q24. */
-- contract/support-level/ticket-volume tiers are not tracked in this schema; demo data below
SELECT contract_type, support_level, monthly_ticket_volume,
  CASE
    WHEN support_level = 'Premium' THEN '1 hour'
    WHEN contract_type = 'Enterprise' AND monthly_ticket_volume > 50 THEN '2 hours'
    WHEN contract_type = 'Enterprise' THEN '4 hours'
    ELSE '24 hours'
  END AS sla_response_time
FROM (VALUES ('Enterprise', 'Standard', 80), ('SMB', 'Basic', 5), ('Enterprise', 'Premium', 20))
  AS demo(contract_type, support_level, monthly_ticket_volume);

/* Q25. */
SELECT g1.a AS dimension_1, g2.b AS dimension_2,
  CASE
    WHEN g1.a <= 3 AND g2.b <= 3 THEN 'Rule Group 1'
    WHEN g1.a <= 3 AND g2.b BETWEEN 4 AND 7 THEN 'Rule Group 2'
    WHEN g1.a <= 3 THEN 'Rule Group 3'
    WHEN g1.a BETWEEN 4 AND 7 AND g2.b <= 3 THEN 'Rule Group 4'
    WHEN g1.a BETWEEN 4 AND 7 AND g2.b BETWEEN 4 AND 7 THEN 'Rule Group 5'
    WHEN g1.a BETWEEN 4 AND 7 THEN 'Rule Group 6'
    WHEN g2.b <= 3 THEN 'Rule Group 7'
    WHEN g2.b BETWEEN 4 AND 7 THEN 'Rule Group 8'
    ELSE 'Rule Group 9'
  END AS matched_rule
FROM generate_series(1, 10) AS g1(a)
CROSS JOIN generate_series(1, 10) AS g2(b)
ORDER BY g1.a, g2.b;

/* ============================================================
   SECTION B: RFM, NPS, COHORTS (25)
   ------------------------------------------------------------ */

/* Q26. */
SELECT cust_id, MAX(order_date) AS last_order_date,
       CURRENT_DATE - MAX(order_date) AS recency_days
FROM sales.orders
GROUP BY cust_id;

/* Q27. */
SELECT cust_id, COUNT(*) AS frequency_365d
FROM sales.orders
WHERE order_date >= CURRENT_DATE - INTERVAL '365 days'
GROUP BY cust_id;

/* Q28. */
SELECT cust_id, SUM(net_total) AS monetary_lifetime
FROM sales.orders
GROUP BY cust_id;

/* Q29. */
WITH recency AS (
  SELECT cust_id, CURRENT_DATE - MAX(order_date) AS recency_days
  FROM sales.orders GROUP BY cust_id
)
SELECT cust_id, recency_days,
       NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score
FROM recency;

/* Q30. */
WITH frequency AS (
  SELECT cust_id, COUNT(*) AS order_count
  FROM sales.orders GROUP BY cust_id
)
SELECT cust_id, order_count,
       NTILE(5) OVER (ORDER BY order_count ASC) AS f_score
FROM frequency;

/* Q31. */
WITH monetary AS (
  SELECT cust_id, SUM(net_total) AS total_spend
  FROM sales.orders GROUP BY cust_id
)
SELECT cust_id, total_spend,
       NTILE(5) OVER (ORDER BY total_spend ASC) AS m_score
FROM monetary;

/* Q32. */
WITH rfm AS (
  SELECT o.cust_id,
         CURRENT_DATE - MAX(o.order_date) AS recency_days,
         COUNT(*) AS order_count,
         SUM(o.net_total) AS total_spend
  FROM sales.orders o
  GROUP BY o.cust_id
),
scored AS (
  SELECT cust_id,
         NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
         NTILE(5) OVER (ORDER BY order_count ASC) AS f_score,
         NTILE(5) OVER (ORDER BY total_spend ASC) AS m_score
  FROM rfm
)
SELECT cust_id, r_score, f_score, m_score,
       r_score::text || f_score::text || m_score::text AS rfm_code
FROM scored
ORDER BY rfm_code DESC;

/* Q33. */
WITH rfm AS (
  SELECT o.cust_id,
         CURRENT_DATE - MAX(o.order_date) AS recency_days,
         COUNT(*) AS order_count,
         SUM(o.net_total) AS total_spend
  FROM sales.orders o GROUP BY o.cust_id
),
scored AS (
  SELECT cust_id,
         NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
         NTILE(5) OVER (ORDER BY order_count ASC) AS f_score,
         NTILE(5) OVER (ORDER BY total_spend ASC) AS m_score
  FROM rfm
)
SELECT cust_id, r_score, f_score, m_score,
  CASE
    WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
    WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
    WHEN r_score <= 2 AND f_score >= 3 THEN 'At-Risk'
    WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost'
    ELSE 'Potential Loyalist'
  END AS rfm_segment
FROM scored;

/* Q34. */
-- ratings (1-5) used as an NPS proxy: 5=promoter, 4=passive, <=3=detractor
SELECT
  ROUND(100.0 * (COUNT(*) FILTER (WHERE rating = 5) - COUNT(*) FILTER (WHERE rating <= 3))
        / NULLIF(COUNT(*), 0), 2) AS nps_score
FROM customers.reviews;

/* Q35. */
-- a customer's "region" is derived from the store of their most recent order
WITH cust_region AS (
  SELECT DISTINCT ON (o.cust_id) o.cust_id, s.region_id
  FROM sales.orders o
  JOIN stores.stores s ON s.store_id = o.store_id
  ORDER BY o.cust_id, o.order_date DESC
)
SELECT r.region_name,
  ROUND(100.0 * (COUNT(*) FILTER (WHERE rv.rating = 5) - COUNT(*) FILTER (WHERE rv.rating <= 3))
        / NULLIF(COUNT(*), 0), 2) AS nps_score
FROM customers.reviews rv
JOIN cust_region cr ON cr.cust_id = rv.customer_id
JOIN core.dim_region r ON r.region_id = cr.region_id
GROUP BY r.region_name
ORDER BY nps_score DESC;

/* Q36. */
SELECT p.product_id, p.product_name,
  ROUND(100.0 * (COUNT(*) FILTER (WHERE rv.rating = 5) - COUNT(*) FILTER (WHERE rv.rating <= 3))
        / NULLIF(COUNT(*), 0), 2) AS nps_score,
  COUNT(*) AS review_count
FROM customers.reviews rv
JOIN products.products p ON p.product_id = rv.product_id
GROUP BY p.product_id, p.product_name
HAVING COUNT(*) >= 5
ORDER BY nps_score DESC;

/* Q37. */
-- a customer's "ticket category" is derived from their most recent ticket
WITH cust_ticket_cat AS (
  SELECT DISTINCT ON (customer_id) customer_id, category
  FROM support.tickets
  ORDER BY customer_id, created_date DESC
)
SELECT tc.category,
  ROUND(100.0 * (COUNT(*) FILTER (WHERE rv.rating = 5) - COUNT(*) FILTER (WHERE rv.rating <= 3))
        / NULLIF(COUNT(*), 0), 2) AS nps_score
FROM customers.reviews rv
JOIN cust_ticket_cat tc ON tc.customer_id = rv.customer_id
GROUP BY tc.category
ORDER BY nps_score DESC;

/* Q38. */
SELECT DATE_TRUNC('month', review_date)::date AS review_month,
  ROUND(100.0 * (COUNT(*) FILTER (WHERE rating = 5) - COUNT(*) FILTER (WHERE rating <= 3))
        / NULLIF(COUNT(*), 0), 2) AS nps_score,
  COUNT(*) AS review_count
FROM customers.reviews
GROUP BY DATE_TRUNC('month', review_date)
ORDER BY review_month;

/* Q39. */
WITH cohort AS (
  SELECT customer_id, DATE_TRUNC('month', registration_date)::date AS cohort_month
  FROM customers.customers
),
activity AS (
  SELECT o.cust_id, DATE_TRUNC('month', o.order_date)::date AS order_month
  FROM sales.orders o
  GROUP BY o.cust_id, DATE_TRUNC('month', o.order_date)
)
SELECT c.cohort_month,
  (EXTRACT(YEAR FROM a.order_month) - EXTRACT(YEAR FROM c.cohort_month)) * 12
    + (EXTRACT(MONTH FROM a.order_month) - EXTRACT(MONTH FROM c.cohort_month)) AS month_n,
  COUNT(DISTINCT a.cust_id) AS active_customers
FROM cohort c
JOIN activity a ON a.cust_id = c.customer_id
GROUP BY c.cohort_month, month_n
ORDER BY c.cohort_month, month_n;

/* Q40. */
WITH first_order AS (
  SELECT cust_id, MIN(order_date) AS first_order_date
  FROM sales.orders GROUP BY cust_id
),
order_counts AS (
  SELECT cust_id, COUNT(*) AS total_orders
  FROM sales.orders GROUP BY cust_id
)
SELECT DATE_TRUNC('month', fo.first_order_date)::date AS cohort_month,
  COUNT(*) AS cohort_size,
  COUNT(*) FILTER (WHERE oc.total_orders > 1) AS repeat_customers,
  ROUND(100.0 * COUNT(*) FILTER (WHERE oc.total_orders > 1) / COUNT(*), 2) AS repeat_rate_pct
FROM first_order fo
JOIN order_counts oc ON oc.cust_id = fo.cust_id
GROUP BY DATE_TRUNC('month', fo.first_order_date)
ORDER BY cohort_month;

/* Q41. There is no table linking a customer or order to the campaign that acquired/activated them, so a real per-campaign activation rate cannot be computed here - only aggregate campaign spend/email metrics exist (marketing.ads_spend, marketing.email_clicks), with no attribution back to individual customers. */

/* Q42. */
WITH first_order AS (
  SELECT cust_id, MIN(order_date) AS first_order_date
  FROM sales.orders GROUP BY cust_id
),
ltv AS (
  SELECT cust_id, SUM(net_total) AS lifetime_value
  FROM sales.orders GROUP BY cust_id
)
SELECT DATE_TRUNC('month', fo.first_order_date)::date AS cohort_month,
  COUNT(*) AS cohort_size,
  ROUND(AVG(l.lifetime_value), 2) AS avg_ltv,
  ROUND(SUM(l.lifetime_value), 2) AS total_cohort_revenue
FROM first_order fo
JOIN ltv l ON l.cust_id = fo.cust_id
GROUP BY DATE_TRUNC('month', fo.first_order_date)
ORDER BY cohort_month;

/* Q43. */
WITH monthly_activity AS (
  SELECT DISTINCT cust_id, DATE_TRUNC('month', order_date)::date AS order_month
  FROM sales.orders
),
with_next AS (
  SELECT cust_id, order_month,
         LEAD(order_month) OVER (PARTITION BY cust_id ORDER BY order_month) AS next_active_month
  FROM monthly_activity
)
SELECT order_month AS active_month,
  COUNT(*) AS active_customers,
  COUNT(*) FILTER (
    WHERE next_active_month IS NULL OR next_active_month <> order_month + INTERVAL '1 month'
  ) AS churned_next_month,
  ROUND(100.0 * COUNT(*) FILTER (
    WHERE next_active_month IS NULL OR next_active_month <> order_month + INTERVAL '1 month'
  ) / COUNT(*), 2) AS churn_rate_pct
FROM with_next
GROUP BY order_month
ORDER BY order_month;

/* Q44. */
WITH last_order AS (
  SELECT cust_id, MAX(order_date) AS last_order_date
  FROM sales.orders GROUP BY cust_id
)
SELECT c.customer_id, c.first_name, c.last_name, c.email, lo.last_order_date,
  CURRENT_DATE - lo.last_order_date AS days_since_last_order
FROM customers.customers c
JOIN last_order lo ON lo.cust_id = c.customer_id
WHERE lo.last_order_date < CURRENT_DATE - INTERVAL '180 days'
ORDER BY lo.last_order_date;

/* Q45. */
WITH visits AS (
  SELECT customer_id, COUNT(*) AS visit_count FROM web_events.page_views GROUP BY customer_id
),
purchases AS (
  SELECT cust_id, COUNT(*) AS purchase_count FROM sales.orders GROUP BY cust_id
),
reviews AS (
  SELECT customer_id, COUNT(*) AS review_count FROM customers.reviews GROUP BY customer_id
)
SELECT c.customer_id,
  COALESCE(v.visit_count, 0) AS visit_count,
  COALESCE(p.purchase_count, 0) AS purchase_count,
  COALESCE(r.review_count, 0) AS review_count,
  NTILE(10) OVER (
    ORDER BY COALESCE(v.visit_count, 0) + COALESCE(p.purchase_count, 0) * 5 + COALESCE(r.review_count, 0) * 3
  ) AS engagement_decile
FROM customers.customers c
LEFT JOIN visits v ON v.customer_id = c.customer_id
LEFT JOIN purchases p ON p.cust_id = c.customer_id
LEFT JOIN reviews r ON r.customer_id = c.customer_id;

/* Q46. */
WITH orders_cnt AS (
  SELECT cust_id, COUNT(*) AS order_count FROM sales.orders GROUP BY cust_id
),
returns_cnt AS (
  SELECT o.cust_id, COUNT(*) AS return_count
  FROM sales.returns r JOIN sales.orders o ON o.order_id = r.order_id
  GROUP BY o.cust_id
),
tickets_cnt AS (
  SELECT customer_id, COUNT(*) AS ticket_count FROM support.tickets GROUP BY customer_id
)
SELECT c.customer_id,
  COALESCE(oc.order_count, 0) AS order_count,
  COALESCE(rc.return_count, 0) AS return_count,
  COALESCE(tc.ticket_count, 0) AS ticket_count,
  NTILE(10) OVER (
    ORDER BY
      (COALESCE(rc.return_count, 0)::numeric / NULLIF(oc.order_count, 0)
       + COALESCE(tc.ticket_count, 0)::numeric / NULLIF(oc.order_count, 0)) DESC NULLS LAST
  ) AS risk_decile
FROM customers.customers c
LEFT JOIN orders_cnt oc ON oc.cust_id = c.customer_id
LEFT JOIN returns_cnt rc ON rc.cust_id = c.customer_id
LEFT JOIN tickets_cnt tc ON tc.customer_id = c.customer_id;

/* Q47. */
WITH rfm AS (
  SELECT o.cust_id,
         CURRENT_DATE - MAX(o.order_date) AS recency_days,
         COUNT(*) AS order_count,
         SUM(o.net_total) AS total_spend
  FROM sales.orders o GROUP BY o.cust_id
),
scored AS (
  SELECT cust_id,
         NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
         NTILE(5) OVER (ORDER BY order_count ASC) AS f_score,
         NTILE(5) OVER (ORDER BY total_spend ASC) AS m_score
  FROM rfm
),
cust_nps AS (
  SELECT customer_id, AVG(CASE WHEN rating = 5 THEN 100 WHEN rating <= 3 THEN -100 ELSE 0 END) AS nps_component
  FROM customers.reviews GROUP BY customer_id
)
SELECT s.cust_id,
  ROUND(0.4 * COALESCE(n.nps_component, 0) / 100 * 5
        + 0.2 * s.r_score + 0.2 * s.f_score + 0.2 * s.m_score, 2) AS health_score
FROM scored s
LEFT JOIN cust_nps n ON n.customer_id = s.cust_id;

/* Q48. */
WITH monthly AS (
  SELECT DATE_TRUNC('month', order_date)::date AS order_month, COUNT(*) AS order_count
  FROM sales.orders
  GROUP BY DATE_TRUNC('month', order_date)
),
numbered AS (
  SELECT order_month, order_count,
         ROW_NUMBER() OVER (ORDER BY order_month) AS month_index
  FROM monthly
)
SELECT REGR_SLOPE(order_count, month_index) AS orders_trend_slope_per_month,
       REGR_INTERCEPT(order_count, month_index) AS intercept
FROM numbered;

/* Q49. */
WITH daily AS (
  SELECT order_date, COUNT(DISTINCT cust_id) AS daily_active
  FROM sales.orders GROUP BY order_date
),
monthly AS (
  SELECT DATE_TRUNC('month', order_date)::date AS order_month, COUNT(DISTINCT cust_id) AS monthly_active
  FROM sales.orders GROUP BY DATE_TRUNC('month', order_date)
)
SELECT m.order_month,
  ROUND(AVG(d.daily_active), 2) AS avg_daily_active,
  m.monthly_active,
  ROUND(100.0 * AVG(d.daily_active) / m.monthly_active, 2) AS stickiness_pct
FROM monthly m
JOIN daily d ON DATE_TRUNC('month', d.order_date) = m.order_month
GROUP BY m.order_month, m.monthly_active
ORDER BY m.order_month;

/* Q50. */
WITH rfm AS (
  SELECT o.cust_id,
         CURRENT_DATE - MAX(o.order_date) AS recency_days,
         COUNT(*) AS order_count,
         SUM(o.net_total) AS total_spend,
         MIN(o.order_date) AS first_order_date
  FROM sales.orders o GROUP BY o.cust_id
),
scored AS (
  SELECT cust_id, recency_days, order_count, total_spend, first_order_date,
         NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
         NTILE(5) OVER (ORDER BY order_count ASC) AS f_score,
         NTILE(5) OVER (ORDER BY total_spend ASC) AS m_score
  FROM rfm
),
cust_nps AS (
  SELECT customer_id,
         COUNT(*) FILTER (WHERE rating = 5) AS promoters,
         COUNT(*) FILTER (WHERE rating <= 3) AS detractors,
         COUNT(*) AS review_count
  FROM customers.reviews GROUP BY customer_id
)
SELECT s.cust_id,
  DATE_TRUNC('month', s.first_order_date)::date AS cohort_month,
  s.r_score, s.f_score, s.m_score,
  s.r_score::text || s.f_score::text || s.m_score::text AS rfm_code,
  CASE
    WHEN s.r_score >= 4 AND s.f_score >= 4 AND s.m_score >= 4 THEN 'Champions'
    WHEN s.r_score <= 2 AND s.f_score <= 2 THEN 'Lost'
    ELSE 'Middle'
  END AS segment,
  COALESCE(n.review_count, 0) AS review_count,
  CASE WHEN COALESCE(n.review_count, 0) > 0
       THEN ROUND(100.0 * (n.promoters - n.detractors) / n.review_count, 2)
       ELSE NULL END AS customer_nps
FROM scored s
LEFT JOIN cust_nps n ON n.customer_id = s.cust_id
ORDER BY s.m_score DESC, s.r_score DESC;

/* ============================================================
   SECTION C: STATE MACHINES & WORKFLOWS (25)
   ------------------------------------------------------------ */

/* Q51. */
SELECT order_id, order_status,
  CASE order_status
    WHEN 'Processing' THEN 1
    WHEN 'Shipped' THEN 2
    WHEN 'Out for Delivery' THEN 3
    WHEN 'Delivered' THEN 4
    WHEN 'Cancelled' THEN -1
    WHEN 'Returned' THEN -2
    WHEN 'Failed' THEN -3
    ELSE 0
  END AS state_order
FROM sales.orders;

/* Q52. */
-- actual ticket states in this schema are Open / In Progress / Resolved / Closed (no separate "Assigned" state)
SELECT ticket_id, status,
  CASE status
    WHEN 'Open' THEN 1
    WHEN 'In Progress' THEN 2
    WHEN 'Resolved' THEN 3
    WHEN 'Closed' THEN 4
    ELSE 0
  END AS state_order
FROM support.tickets;

/* Q53. */
SELECT shipment_id, status,
  CASE status
    WHEN 'Shipped' THEN 1
    WHEN 'Delivered' THEN 2
    WHEN 'Returned' THEN -1
    ELSE 0
  END AS state_order
FROM sales.shipments;

/* Q54. */
WITH last_order AS (
  SELECT cust_id, MAX(order_date) AS last_order_date, COUNT(*) AS order_count
  FROM sales.orders GROUP BY cust_id
)
SELECT c.customer_id, c.registration_date, lo.last_order_date, COALESCE(lo.order_count, 0) AS order_count,
  CASE
    WHEN lo.last_order_date IS NULL THEN 'New'
    WHEN CURRENT_DATE - lo.last_order_date <= 90 THEN 'Active'
    WHEN CURRENT_DATE - lo.last_order_date <= 365 THEN 'Dormant'
    ELSE 'Churned'
  END AS lifecycle_stage
FROM customers.customers c
LEFT JOIN last_order lo ON lo.cust_id = c.customer_id;

/* Q55. There is no subscription table in this schema (no plan/trial/paused/cancelled state anywhere), so a subscription state machine can't be built against real data here. */

/* Q56. */
-- refund_amount IS NULL is used as a proxy for "Requested but not yet decided"
SELECT return_id, order_id, refund_amount,
  CASE
    WHEN refund_amount IS NULL THEN 'Requested'
    WHEN refund_amount = 0 THEN 'Denied'
    ELSE 'Approved'
  END AS refund_state
FROM sales.returns;

/* Q57. */
SELECT campaign_id, campaign_name, start_date, end_date,
  CASE
    WHEN CURRENT_DATE < start_date THEN 'Draft'
    WHEN CURRENT_DATE BETWEEN start_date AND end_date THEN 'Active'
    WHEN CURRENT_DATE > end_date AND CURRENT_DATE <= end_date + INTERVAL '90 days' THEN 'Ended'
    ELSE 'Archived'
  END AS campaign_state
FROM marketing.campaigns;

/* Q58. Employees only have a single joining_date column - there is no application/interview/hire pipeline data (application date, interview stage, offer status) to model an onboarding state machine against. */

/* Q59. audit.record_changes only logs field-level changes to employees.salary and products.price (table_name, column_name, old_value, new_value) - it holds no order_status or ticket_status transition history, so invalid-transition detection can't be built as a real query against this schema. */

/* Q60. */
SELECT ticket_id, status, created_date,
  CASE
    WHEN status IN ('Resolved', 'Closed') THEN resolved_date - created_date
    ELSE (CURRENT_TIMESTAMP - created_date)
  END AS time_in_current_state
FROM support.tickets;

/* Q61. */
SELECT ticket_id, priority, status, created_date,
  CASE
    WHEN status NOT IN ('Resolved', 'Closed')
     AND CURRENT_TIMESTAMP - created_date > CASE priority
           WHEN 'Critical' THEN INTERVAL '4 hours'
           WHEN 'High' THEN INTERVAL '24 hours'
           WHEN 'Medium' THEN INTERVAL '72 hours'
           ELSE INTERVAL '7 days'
         END
    THEN TRUE ELSE FALSE
  END AS is_sla_breached
FROM support.tickets;

/* Q62. Auto-advancing states on a schedule is an external scheduling/orchestration mechanism (e.g. pg_cron or an app-side job), not something expressible as a single SQL query. */

/* Q63. */
SELECT status,
  AVG(resolved_date - created_date) AS avg_time_to_resolution
FROM support.tickets
WHERE resolved_date IS NOT NULL
GROUP BY status;

/* Q64. */
SELECT
  COUNT(*) AS total_orders,
  COUNT(*) FILTER (WHERE order_status NOT IN ('Cancelled')) AS reached_processing,
  ROUND(100.0 * COUNT(*) FILTER (WHERE order_status IN ('Shipped', 'Out for Delivery', 'Delivered')) / COUNT(*), 2) AS pct_shipped,
  ROUND(100.0 * COUNT(*) FILTER (WHERE order_status IN ('Out for Delivery', 'Delivered')) / COUNT(*), 2) AS pct_out_for_delivery,
  ROUND(100.0 * COUNT(*) FILTER (WHERE order_status = 'Delivered') / COUNT(*), 2) AS pct_delivered
FROM sales.orders;

/* Q65. */
SELECT $$graph LR
  Processing --> Shipped
  Shipped --> OutForDelivery
  OutForDelivery --> Delivered
  Processing --> Cancelled
  Shipped --> Returned
  Delivered --> Returned
  Processing --> Failed$$ AS mermaid_diagram;

/* Q66. Same limitation as Q59 - audit.record_changes only tracks employees/products price and salary field edits, not order or ticket status history, so there is no transition log here to reverse-engineer states from. */

/* Q67. */
SELECT ticket_id, status, created_date, CURRENT_TIMESTAMP - created_date AS age
FROM support.tickets
WHERE status NOT IN ('Resolved', 'Closed')
  AND CURRENT_TIMESTAMP - created_date > INTERVAL '14 days'
ORDER BY age DESC;

/* Q68. A generic workflow-engine DSL (arbitrary states/transitions/guards defined and executed entirely in SQL) is a database-design/architecture exercise, not something expressible as one runnable query against this schema. */

/* Q69. This schema has no manager/finance/legal approval-chain columns or table (no approver roles or approval-status history), so multi-actor approval logic can't be built as a real query here. */

/* Q70. */
SELECT ticket_id, priority, status, created_date,
  CASE
    WHEN status NOT IN ('Resolved', 'Closed')
     AND CURRENT_TIMESTAMP - created_date > INTERVAL '48 hours'
     AND priority <> 'Critical'
    THEN CASE priority WHEN 'High' THEN 'Critical' WHEN 'Medium' THEN 'High' ELSE 'Medium' END
    ELSE priority
  END AS elevated_priority
FROM support.tickets;

/* Q71. */
SELECT ticket_id, priority, status, agent_id,
  CASE
    WHEN priority = 'Critical' AND status = 'Open'
     AND CURRENT_TIMESTAMP - created_date > INTERVAL '2 hours' THEN 'Escalate to Manager'
    WHEN status = 'Open' AND CURRENT_TIMESTAMP - created_date > INTERVAL '7 days' THEN 'Escalate to Manager'
    ELSE 'No Escalation'
  END AS escalation_action
FROM support.tickets;

/* Q72. Defining rollback rules (which states can legally revert to which prior states) is a design/policy decision, and there is no transition-history table in this schema to validate or query such rules against. */

/* Q73. */
SELECT order_id, order_status,
  CASE order_status
    WHEN 'Processing' THEN 'Shipped'
    WHEN 'Shipped' THEN 'Out for Delivery'
    WHEN 'Out for Delivery' THEN 'Delivered'
    WHEN 'Delivered' THEN NULL
    WHEN 'Cancelled' THEN NULL
    WHEN 'Returned' THEN NULL
    WHEN 'Failed' THEN 'Processing'
    ELSE NULL
  END AS next_state
FROM sales.orders;

/* Q74. */
SELECT DISTINCT c.customer_id, c.first_name, c.last_name
FROM customers.customers c
WHERE EXISTS (
  SELECT 1 FROM support.tickets t
  WHERE t.customer_id = c.customer_id AND t.status NOT IN ('Resolved', 'Closed')
)
AND EXISTS (
  SELECT 1 FROM sales.orders o
  WHERE o.cust_id = c.customer_id AND o.order_status NOT IN ('Delivered', 'Cancelled', 'Returned', 'Failed')
);

/* Q75. */
WITH ship AS (
  SELECT order_id, shipped_date, delivered_date FROM sales.shipments
)
SELECT o.order_status,
  COUNT(*) AS order_count,
  ROUND(AVG(CURRENT_DATE - o.order_date), 1) AS avg_age_days,
  ROUND(AVG(s.delivered_date - s.shipped_date) FILTER (WHERE s.delivered_date IS NOT NULL), 1) AS avg_ship_to_delivery_days
FROM sales.orders o
LEFT JOIN ship s ON s.order_id = o.order_id
GROUP BY o.order_status
ORDER BY order_count DESC;

/* ============================================================
   SECTION D: 360deg DASHBOARDS (25)
   ------------------------------------------------------------ */

/* Q76. */
WITH order_stats AS (
  SELECT cust_id, COUNT(*) AS order_count, SUM(net_total) AS total_spend,
         MAX(order_date) AS last_order_date, MIN(order_date) AS first_order_date
  FROM sales.orders GROUP BY cust_id
),
return_stats AS (
  SELECT o.cust_id, COUNT(*) AS return_count, SUM(r.refund_amount) AS total_refunded
  FROM sales.returns r JOIN sales.orders o ON o.order_id = r.order_id
  GROUP BY o.cust_id
),
ticket_stats AS (
  SELECT customer_id, COUNT(*) AS ticket_count,
         COUNT(*) FILTER (WHERE status NOT IN ('Resolved', 'Closed')) AS open_tickets
  FROM support.tickets GROUP BY customer_id
),
review_stats AS (
  SELECT customer_id, COUNT(*) AS review_count, AVG(rating) AS avg_rating
  FROM customers.reviews GROUP BY customer_id
)
SELECT c.customer_id, c.first_name, c.last_name, c.tier, c.registration_date,
  COALESCE(os.order_count, 0) AS order_count,
  COALESCE(os.total_spend, 0) AS total_spend,
  os.first_order_date, os.last_order_date,
  COALESCE(rs.return_count, 0) AS return_count,
  COALESCE(rs.total_refunded, 0) AS total_refunded,
  COALESCE(ts.ticket_count, 0) AS ticket_count,
  COALESCE(ts.open_tickets, 0) AS open_tickets,
  COALESCE(rv.review_count, 0) AS review_count,
  ROUND(rv.avg_rating, 2) AS avg_rating,
  CASE WHEN os.last_order_date IS NULL THEN NULL
       ELSE CURRENT_DATE - os.last_order_date END AS days_since_last_order
FROM customers.customers c
LEFT JOIN order_stats os ON os.cust_id = c.customer_id
LEFT JOIN return_stats rs ON rs.cust_id = c.customer_id
LEFT JOIN ticket_stats ts ON ts.customer_id = c.customer_id
LEFT JOIN review_stats rv ON rv.customer_id = c.customer_id;

/* Q77. */
WITH sales_stats AS (
  SELECT prod_id, SUM(quantity) AS units_sold, SUM(net_amount) AS revenue
  FROM sales.order_items GROUP BY prod_id
),
return_stats AS (
  SELECT prod_id, COUNT(*) AS return_count, SUM(refund_amount) AS total_refunded
  FROM sales.returns GROUP BY prod_id
),
inv_stats AS (
  SELECT product_id, SUM(quantity_on_hand) AS total_stock
  FROM products.inventory GROUP BY product_id
),
review_stats AS (
  SELECT product_id, COUNT(*) AS review_count, AVG(rating) AS avg_rating
  FROM customers.reviews GROUP BY product_id
)
SELECT p.product_id, p.product_name, p.price,
  COALESCE(s.units_sold, 0) AS units_sold,
  COALESCE(s.revenue, 0) AS revenue,
  COALESCE(r.return_count, 0) AS return_count,
  COALESCE(r.total_refunded, 0) AS total_refunded,
  COALESCE(i.total_stock, 0) AS total_stock,
  COALESCE(rv.review_count, 0) AS review_count,
  ROUND(rv.avg_rating, 2) AS avg_rating
FROM products.products p
LEFT JOIN sales_stats s ON s.prod_id = p.product_id
LEFT JOIN return_stats r ON r.prod_id = p.product_id
LEFT JOIN inv_stats i ON i.product_id = p.product_id
LEFT JOIN review_stats rv ON rv.product_id = p.product_id;

/* Q78. */
-- returns joined via the order's store are used as a "complaints" proxy (no dedicated complaints table)
WITH order_stats AS (
  SELECT store_id, COUNT(*) AS order_count, SUM(net_total) AS revenue
  FROM sales.orders GROUP BY store_id
),
emp_stats AS (
  SELECT store_id, COUNT(*) AS employee_count
  FROM stores.employees GROUP BY store_id
),
inv_stats AS (
  SELECT store_id, SUM(quantity_on_hand) AS total_stock
  FROM products.inventory GROUP BY store_id
),
complaint_stats AS (
  SELECT o.store_id, COUNT(*) AS complaint_count
  FROM sales.returns r JOIN sales.orders o ON o.order_id = r.order_id
  GROUP BY o.store_id
)
SELECT st.store_id, st.store_name, st.city,
  COALESCE(os.order_count, 0) AS order_count,
  COALESCE(os.revenue, 0) AS revenue,
  COALESCE(es.employee_count, 0) AS employee_count,
  COALESCE(inv.total_stock, 0) AS total_stock,
  COALESCE(cs.complaint_count, 0) AS complaint_count
FROM stores.stores st
LEFT JOIN order_stats os ON os.store_id = st.store_id
LEFT JOIN emp_stats es ON es.store_id = st.store_id
LEFT JOIN inv_stats inv ON inv.store_id = st.store_id
LEFT JOIN complaint_stats cs ON cs.store_id = st.store_id;

/* Q79. */
-- assumes support.tickets.agent_id / call_center.calls.agent_id share the stores.employees.employee_id space
-- (not enforced by a foreign key in this schema); attendance/bonus are not tracked at all
WITH ticket_stats AS (
  SELECT agent_id, COUNT(*) AS ticket_count,
         COUNT(*) FILTER (WHERE status IN ('Resolved', 'Closed')) AS resolved_count
  FROM support.tickets GROUP BY agent_id
),
call_stats AS (
  SELECT agent_id, COUNT(*) AS call_count, AVG(call_duration_seconds) AS avg_call_duration
  FROM call_center.calls GROUP BY agent_id
)
SELECT e.employee_id, e.first_name, e.last_name, e.role, e.salary,
  COALESCE(ts.ticket_count, 0) AS ticket_count,
  COALESCE(ts.resolved_count, 0) AS resolved_count,
  COALESCE(cs.call_count, 0) AS call_count,
  ROUND(cs.avg_call_duration, 1) AS avg_call_duration_seconds
FROM stores.employees e
LEFT JOIN ticket_stats ts ON ts.agent_id = e.employee_id
LEFT JOIN call_stats cs ON cs.agent_id = e.employee_id;

/* Q80. */
WITH store_region AS (
  SELECT store_id, region_id FROM stores.stores
),
order_region AS (
  SELECT o.order_id, o.cust_id, o.net_total, sr.region_id
  FROM sales.orders o JOIN store_region sr ON sr.store_id = o.store_id
)
SELECT r.region_id, r.region_name, r.country,
  (SELECT COUNT(*) FROM stores.stores s2 WHERE s2.region_id = r.region_id) AS store_count,
  (SELECT COUNT(DISTINCT ora.cust_id) FROM order_region ora WHERE ora.region_id = r.region_id) AS customer_count,
  (SELECT COALESCE(SUM(ora.net_total), 0) FROM order_region ora WHERE ora.region_id = r.region_id) AS revenue,
  COALESCE((SELECT COUNT(*) FROM sales.returns rt JOIN order_region ora2 ON ora2.order_id = rt.order_id
            WHERE ora2.region_id = r.region_id), 0) AS complaint_count
FROM core.dim_region r;

/* Q81. */
-- true campaign attribution/conversion data does not exist in this schema; spend and email engagement are used instead
WITH spend_stats AS (
  SELECT campaign_id, SUM(amount) AS total_spend
  FROM marketing.ads_spend GROUP BY campaign_id
),
email_stats AS (
  SELECT campaign_id, SUM(emails_sent) AS emails_sent, SUM(emails_opened) AS emails_opened, SUM(emails_clicked) AS emails_clicked
  FROM marketing.email_clicks GROUP BY campaign_id
)
SELECT c.campaign_id, c.campaign_name, c.budget, c.start_date, c.end_date,
  COALESCE(s.total_spend, 0) AS total_spend,
  COALESCE(e.emails_sent, 0) AS emails_sent,
  COALESCE(e.emails_opened, 0) AS emails_opened,
  COALESCE(e.emails_clicked, 0) AS emails_clicked,
  ROUND(c.budget - COALESCE(s.total_spend, 0), 2) AS budget_remaining
FROM marketing.campaigns c
LEFT JOIN spend_stats s ON s.campaign_id = c.campaign_id
LEFT JOIN email_stats e ON e.campaign_id = c.campaign_id;

/* Q82. */
WITH ship_stats AS (
  SELECT supplier_id, COUNT(*) AS shipment_count, SUM(quantity) AS total_units_shipped
  FROM supply_chain.shipments GROUP BY supplier_id
),
product_stats AS (
  SELECT supplier_id, COUNT(*) AS product_count, AVG(cost_price) AS avg_cost_price
  FROM products.products GROUP BY supplier_id
)
SELECT s.supplier_id, s.supplier_name, s.city,
  COALESCE(ss.shipment_count, 0) AS shipment_count,
  COALESCE(ss.total_units_shipped, 0) AS total_units_shipped,
  COALESCE(ps.product_count, 0) AS product_count,
  ROUND(ps.avg_cost_price, 2) AS avg_cost_price
FROM products.suppliers s
LEFT JOIN ship_stats ss ON ss.supplier_id = s.supplier_id
LEFT JOIN product_stats ps ON ps.supplier_id = s.supplier_id;

/* Q83. */
WITH sales_stats AS (
  SELECT p.brand_id, SUM(oi.quantity) AS units_sold, SUM(oi.net_amount) AS revenue
  FROM sales.order_items oi JOIN products.products p ON p.product_id = oi.prod_id
  GROUP BY p.brand_id
),
return_stats AS (
  SELECT p.brand_id, COUNT(*) AS return_count
  FROM sales.returns r JOIN products.products p ON p.product_id = r.prod_id
  GROUP BY p.brand_id
),
review_stats AS (
  SELECT p.brand_id, COUNT(*) AS review_count, AVG(rv.rating) AS avg_rating
  FROM customers.reviews rv JOIN products.products p ON p.product_id = rv.product_id
  GROUP BY p.brand_id
)
SELECT b.brand_id, b.brand_name,
  COUNT(DISTINCT p.product_id) AS product_count,
  COALESCE(ss.units_sold, 0) AS units_sold,
  COALESCE(ss.revenue, 0) AS revenue,
  COALESCE(rs.return_count, 0) AS return_count,
  COALESCE(rv.review_count, 0) AS review_count,
  ROUND(rv.avg_rating, 2) AS avg_rating
FROM core.dim_brand b
LEFT JOIN products.products p ON p.brand_id = b.brand_id
LEFT JOIN sales_stats ss ON ss.brand_id = b.brand_id
LEFT JOIN return_stats rs ON rs.brand_id = b.brand_id
LEFT JOIN review_stats rv ON rv.brand_id = b.brand_id
GROUP BY b.brand_id, b.brand_name, ss.units_sold, ss.revenue, rs.return_count, rv.review_count, rv.avg_rating;

/* Q84. */
WITH prod_revenue AS (
  SELECT p.brand_id, SUM(oi.net_amount) AS revenue
  FROM sales.order_items oi JOIN products.products p ON p.product_id = oi.prod_id
  GROUP BY p.brand_id
),
brand_cat AS (
  SELECT b.brand_id, b.category_id, COALESCE(pr.revenue, 0) AS brand_revenue
  FROM core.dim_brand b
  LEFT JOIN prod_revenue pr ON pr.brand_id = b.brand_id
)
SELECT cat.category_id, cat.category_name,
  COUNT(DISTINCT bc.brand_id) AS brand_count,
  (SELECT COUNT(*) FROM products.products p2 JOIN core.dim_brand b2 ON b2.brand_id = p2.brand_id
    WHERE b2.category_id = cat.category_id) AS product_count,
  COALESCE(SUM(bc.brand_revenue), 0) AS total_revenue
FROM core.dim_category cat
LEFT JOIN brand_cat bc ON bc.category_id = cat.category_id
GROUP BY cat.category_id, cat.category_name;

/* Q85. */
WITH member_spend AS (
  SELECT m.customer_id, m.tier_id, SUM(o.net_total) AS total_spend, COUNT(o.order_id) AS order_count
  FROM loyalty.members m
  LEFT JOIN sales.orders o ON o.cust_id = m.customer_id
  GROUP BY m.customer_id, m.tier_id
)
SELECT t.tier_id, t.tier_name,
  COUNT(ms.customer_id) AS member_count,
  ROUND(AVG(ms.total_spend), 2) AS avg_spend_per_member,
  SUM(ms.total_spend) AS total_tier_revenue,
  ROUND(AVG(ms.order_count), 2) AS avg_orders_per_member
FROM loyalty.tiers t
LEFT JOIN member_spend ms ON ms.tier_id = t.tier_id
GROUP BY t.tier_id, t.tier_name;

/* Q86. */
WITH ship_stats AS (
  SELECT warehouse_id, COUNT(*) AS shipment_count, SUM(quantity) AS total_units_received
  FROM supply_chain.shipments GROUP BY warehouse_id
),
snapshot_stats AS (
  SELECT warehouse_id, COUNT(DISTINCT product_id) AS distinct_products, SUM(quantity_on_hand) AS total_on_hand
  FROM supply_chain.inventory_snapshots
  WHERE snapshot_date = (SELECT MAX(snapshot_date) FROM supply_chain.inventory_snapshots)
  GROUP BY warehouse_id
)
SELECT w.warehouse_id, w.name, w.region, w.capacity_sqft,
  COALESCE(ss.shipment_count, 0) AS shipment_count,
  COALESCE(ss.total_units_received, 0) AS total_units_received,
  COALESCE(sn.distinct_products, 0) AS distinct_products_on_hand,
  COALESCE(sn.total_on_hand, 0) AS total_units_on_hand
FROM supply_chain.warehouses w
LEFT JOIN ship_stats ss ON ss.warehouse_id = w.warehouse_id
LEFT JOIN snapshot_stats sn ON sn.warehouse_id = w.warehouse_id;

/* Q87. */
SELECT s.courier_name,
  COUNT(*) AS shipment_count,
  COUNT(*) FILTER (WHERE s.status = 'Delivered') AS delivered_count,
  COUNT(*) FILTER (WHERE s.status = 'Returned') AS returned_count,
  ROUND(AVG(s.delivered_date - s.shipped_date) FILTER (WHERE s.delivered_date IS NOT NULL), 2) AS avg_delivery_days
FROM sales.shipments s
GROUP BY s.courier_name
ORDER BY shipment_count DESC;

/* Q88. */
-- call_center.transcripts.sentiment_score is used as a ratings proxy for agents (no direct agent-rating column exists)
WITH ticket_stats AS (
  SELECT agent_id, COUNT(*) AS ticket_count,
         COUNT(*) FILTER (WHERE status IN ('Resolved', 'Closed')) AS resolved_count
  FROM support.tickets GROUP BY agent_id
),
call_stats AS (
  SELECT c.agent_id, COUNT(*) AS call_count,
         SUM(c.call_duration_seconds) AS total_call_seconds,
         AVG(t.sentiment_score) AS avg_sentiment
  FROM call_center.calls c
  LEFT JOIN call_center.transcripts t ON t.call_id = c.call_id
  GROUP BY c.agent_id
)
SELECT e.employee_id, e.first_name, e.last_name,
  COALESCE(ts.ticket_count, 0) AS ticket_count,
  COALESCE(ts.resolved_count, 0) AS resolved_count,
  COALESCE(cs.call_count, 0) AS call_count,
  ROUND(COALESCE(cs.total_call_seconds, 0) / 3600.0, 2) AS total_call_hours,
  ROUND(cs.avg_sentiment, 3) AS avg_sentiment_score
FROM stores.employees e
LEFT JOIN ticket_stats ts ON ts.agent_id = e.employee_id
LEFT JOIN call_stats cs ON cs.agent_id = e.employee_id;

/* Q89. */
SELECT rv.customer_id,
  COUNT(*) AS review_count,
  ROUND(AVG(rv.rating), 2) AS avg_rating,
  COUNT(DISTINCT rv.product_id) AS products_covered,
  MIN(rv.review_date) AS first_review_date,
  MAX(rv.review_date) AS last_review_date
FROM customers.reviews rv
GROUP BY rv.customer_id
ORDER BY review_count DESC;

/* Q90. */
WITH return_stats AS (
  SELECT o.cust_id, COUNT(*) AS return_count, SUM(r.refund_amount) AS total_refunded
  FROM sales.returns r JOIN sales.orders o ON o.order_id = r.order_id
  GROUP BY o.cust_id
)
SELECT c.customer_id, c.first_name, c.last_name, rs.return_count, rs.total_refunded
FROM return_stats rs
JOIN customers.customers c ON c.customer_id = rs.cust_id
ORDER BY rs.total_refunded DESC
LIMIT 20;

/* Q91. */
-- scoped to a representative set of real KPIs rather than a literal 30
SELECT
  (SELECT COUNT(*) FROM customers.customers) AS total_customers,
  (SELECT COUNT(*) FROM sales.orders) AS total_orders,
  (SELECT ROUND(SUM(net_total), 2) FROM sales.orders) AS total_revenue,
  (SELECT ROUND(AVG(net_total), 2) FROM sales.orders) AS avg_order_value,
  (SELECT COUNT(*) FROM products.products) AS total_products,
  (SELECT COUNT(*) FROM sales.returns) AS total_returns,
  (SELECT COUNT(*) FROM support.tickets WHERE status NOT IN ('Resolved', 'Closed')) AS open_tickets,
  (SELECT ROUND(AVG(rating), 2) FROM customers.reviews) AS avg_review_rating,
  (SELECT COUNT(*) FROM stores.stores) AS total_stores,
  (SELECT COUNT(*) FROM stores.employees) AS total_employees;

/* Q92. */
SELECT
  COUNT(*) AS total_sku_locations,
  COUNT(*) FILTER (WHERE quantity_on_hand = 0) AS out_of_stock,
  COUNT(*) FILTER (WHERE quantity_on_hand > 0 AND quantity_on_hand < reorder_level) AS low_stock,
  COUNT(*) FILTER (WHERE quantity_on_hand >= reorder_level) AS healthy_stock
FROM products.inventory;

/* Q93. */
-- CAC/ROAS are approximated against total company revenue/customers since no per-order marketing attribution exists
SELECT
  (SELECT ROUND(SUM(amount), 2) FROM marketing.ads_spend) AS total_ad_spend,
  (SELECT ROUND(SUM(net_total), 2) FROM sales.orders) AS total_revenue,
  (SELECT COUNT(*) FROM customers.customers) AS total_customers,
  ROUND((SELECT SUM(amount) FROM marketing.ads_spend)
        / NULLIF((SELECT COUNT(*) FROM customers.customers), 0), 2) AS approx_cac,
  ROUND((SELECT SUM(net_total) FROM sales.orders)
        / NULLIF((SELECT SUM(amount) FROM marketing.ads_spend), 0), 2) AS approx_roas;

/* Q94. */
SELECT
  (SELECT COUNT(*) FROM sales.orders WHERE order_date >= CURRENT_DATE - INTERVAL '30 days') AS orders_last_30d,
  (SELECT ROUND(AVG(delivered_date - shipped_date), 2) FROM sales.shipments WHERE delivered_date IS NOT NULL) AS avg_ship_to_delivery_days,
  (SELECT COUNT(*) FROM sales.orders WHERE order_status = 'Failed') AS failed_orders,
  (SELECT COUNT(*) FROM sales.shipments WHERE status = 'Returned') AS failed_shipments,
  (SELECT COUNT(*) FROM support.tickets WHERE status NOT IN ('Resolved', 'Closed')) AS open_support_backlog;

/* Q95. */
WITH item_costs AS (
  SELECT oi.order_id, oi.net_amount, p.cost_price * oi.quantity AS item_cost
  FROM sales.order_items oi
  JOIN products.products p ON p.product_id = oi.prod_id
)
SELECT
  ROUND(SUM(net_amount), 2) AS total_revenue,
  ROUND(SUM(item_cost), 2) AS total_cogs,
  ROUND(SUM(net_amount) - SUM(item_cost), 2) AS gross_profit,
  ROUND(100.0 * (SUM(net_amount) - SUM(item_cost)) / NULLIF(SUM(net_amount), 0), 2) AS gross_margin_pct
FROM item_costs;

/* Q96. */
-- attrition is dropped: no termination/exit-date column exists to compute it from
SELECT
  (SELECT COUNT(*) FROM stores.employees) AS headcount,
  (SELECT COUNT(DISTINCT dept_id) FROM stores.employees) AS dept_count,
  (SELECT ROUND(AVG(salary), 2) FROM stores.employees) AS avg_salary,
  (SELECT ROUND(SUM(net_salary), 2) FROM payroll.pay_slips WHERE salary_year = EXTRACT(YEAR FROM CURRENT_DATE)::int) AS ytd_payroll_cost;

/* Q97. */
-- CSAT is approximated via call sentiment; FCR is approximated as tickets resolved same-day as created (no reopen history exists to detect true repeat contacts)
SELECT
  (SELECT COUNT(*) FROM support.tickets) AS total_tickets,
  (SELECT COUNT(*) FROM support.tickets WHERE status NOT IN ('Resolved', 'Closed')) AS open_tickets,
  (SELECT ROUND(EXTRACT(EPOCH FROM AVG(resolved_date - created_date)) / 86400, 2) FROM support.tickets WHERE resolved_date IS NOT NULL) AS avg_resolution_days,
  (SELECT ROUND(AVG(sentiment_score), 3) FROM call_center.transcripts) AS approx_csat_sentiment,
  (SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE resolved_date::date = created_date::date) / NULLIF(COUNT(*), 0), 2)
     FROM support.tickets WHERE resolved_date IS NOT NULL) AS approx_first_contact_resolution_pct;

/* Q98. */
-- true conversion rate is approximated as distinct buyers over distinct page-viewing customers (no session/funnel tracking exists)
WITH repeat_stats AS (
  SELECT cust_id, COUNT(*) AS order_count FROM sales.orders GROUP BY cust_id
)
SELECT
  (SELECT COUNT(*) FROM sales.orders) AS total_orders,
  (SELECT ROUND(AVG(net_total), 2) FROM sales.orders) AS avg_order_value,
  (SELECT COUNT(DISTINCT cust_id) FROM sales.orders) AS distinct_buyers,
  (SELECT COUNT(*) FROM repeat_stats WHERE order_count > 1) AS repeat_buyers,
  ROUND(100.0 * (SELECT COUNT(*) FROM repeat_stats WHERE order_count > 1)
        / NULLIF((SELECT COUNT(*) FROM repeat_stats), 0), 2) AS repeat_rate_pct,
  ROUND(100.0 * (SELECT COUNT(DISTINCT cust_id) FROM sales.orders)
        / NULLIF((SELECT COUNT(DISTINCT customer_id) FROM web_events.page_views), 0), 2) AS approx_conversion_rate_pct;

/* Q99. */
-- scoped to a representative cross-domain KPI set rather than a literal 50
SELECT
  (SELECT COUNT(*) FROM customers.customers) AS total_customers,
  (SELECT COUNT(*) FROM sales.orders) AS total_orders,
  (SELECT ROUND(SUM(net_total), 2) FROM sales.orders) AS total_revenue,
  (SELECT ROUND(AVG(net_total), 2) FROM sales.orders) AS avg_order_value,
  (SELECT COUNT(*) FROM products.products) AS total_skus,
  (SELECT COUNT(*) FROM stores.stores) AS total_stores,
  (SELECT COUNT(*) FROM stores.employees) AS total_employees,
  (SELECT COUNT(*) FROM sales.returns) AS total_returns,
  (SELECT ROUND(SUM(refund_amount), 2) FROM sales.returns) AS total_refunded,
  (SELECT COUNT(*) FROM support.tickets WHERE status NOT IN ('Resolved', 'Closed')) AS open_tickets,
  (SELECT ROUND(AVG(rating), 2) FROM customers.reviews) AS avg_review_rating,
  (SELECT ROUND(SUM(amount), 2) FROM marketing.ads_spend) AS total_marketing_spend,
  (SELECT COUNT(*) FROM loyalty.members) AS loyalty_members,
  (SELECT COUNT(DISTINCT cust_id) FROM sales.orders WHERE order_date >= CURRENT_DATE - INTERVAL '30 days') AS active_customers_30d;

/* Q100. */
WITH profit AS (
  SELECT SUM(oi.net_amount) AS revenue, SUM(p.cost_price * oi.quantity) AS cogs
  FROM sales.order_items oi JOIN products.products p ON p.product_id = oi.prod_id
)
SELECT
  (SELECT ROUND(SUM(net_total), 2) FROM sales.orders) AS total_revenue,
  (SELECT COUNT(*) FROM sales.orders) AS total_orders,
  (SELECT ROUND(AVG(net_total), 2) FROM sales.orders) AS avg_order_value,
  (SELECT COUNT(*) FROM customers.customers) AS total_customers,
  (SELECT COUNT(DISTINCT cust_id) FROM sales.orders WHERE order_date >= CURRENT_DATE - INTERVAL '30 days') AS active_customers_30d,
  (SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE order_status = 'Returned') / COUNT(*), 2) FROM sales.orders) AS return_rate_pct,
  (SELECT ROUND(AVG(rating), 2) FROM customers.reviews) AS avg_customer_rating,
  (SELECT COUNT(*) FROM support.tickets WHERE status NOT IN ('Resolved', 'Closed')) AS open_support_tickets,
  (SELECT ROUND(p.revenue - p.cogs, 2) FROM profit p) AS approx_gross_profit,
  (SELECT COUNT(*) FROM stores.stores) AS total_stores;

/* ============================================================
   END OF ANSWER KEY
   ============================================================ */
