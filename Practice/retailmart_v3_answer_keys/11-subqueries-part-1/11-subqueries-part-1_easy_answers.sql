/* ============================================================
   ANSWER KEY - Subqueries Part 1 (EASY LEVEL)
   Curriculum:   RetailMart V3
   ============================================================ */

/* ============================================================
   SECTION A: SUBQUERIES - CONCEPTUAL (25)
   ------------------------------------------------------------ */
/* Q1.  A subquery is a SELECT nested inside another query (no name); a CTE (WITH x AS (...)) is a named, top-level query that can be referenced by name and reused. */
/* Q2.  A scalar subquery returns exactly one row and one column, so it can be used anywhere a single value is expected (SELECT list, WHERE, comparisons). */
/* Q3.  IN (subquery) compares a value against a list of values; EXISTS (subquery) only checks whether any row is returned - EXISTS is often faster since it can stop at the first match and ignores the subquery's columns. */
/* Q4.  If the NOT IN subquery returns even one NULL, every comparison becomes UNKNOWN and the whole WHERE NOT IN clause matches zero rows - a classic silent bug. */
/* Q5.  A correlated subquery references a column from the outer query, so it must (conceptually) be re-evaluated once per outer row. */
/* Q6.  = ANY(subquery) and IN (subquery) are equivalent for equality comparisons - IN is just shorthand for = ANY. */
/* Q7.  > ALL(subquery) and > (SELECT MAX(...)) return the same rows, but > ALL fails with an error if the subquery ever returns more than the planner expects only when misused as scalar - as ALL it handles multiple rows fine, just less readable than MAX. */
/* Q8.  No - a subquery used in the SELECT list must return a single row (scalar), or Postgres raises "more than one row returned by a subquery used as an expression". */
/* Q9.  Only with IN/ANY/ALL/EXISTS; with a plain = comparison, a WHERE subquery must return at most one row or it errors. */
/* Q10. WHERE col = (subquery) requires the subquery return exactly one row (or NULL); WHERE col IN (subquery) accepts any number of rows and matches if col equals any of them. */
/* Q11. It returns a single numeric value (or NULL if the table is empty) - Postgres treats it as type numeric, matching net_total's column type. */
/* Q12. A subquery in FROM (a derived table) is required when you need to filter, join, or reference an already-aggregated/derived result set as if it were a table. */
/* Q13. Postgres requires every derived table to have an alias because internally every relation in FROM must have a name to qualify its columns by. */
/* Q14. Both can produce the same result column; SELECT (subquery) is single-value-per-row and easy to read for one metric, while a JOIN can return multiple related columns/rows at once and lets the planner pick a join strategy. */
/* Q15. A semi-join returns each outer row at most once if a match exists in the subquery, without duplicating it per match; EXISTS implements exactly this - it checks existence and stops at the first hit. */
/* Q16. An anti-join returns outer rows that have NO match in the subquery; NOT EXISTS implements this directly and safely (unlike NOT IN with NULLs). */
/* Q17. NOT EXISTS only checks for row existence via a correlated boolean test, so a NULL value inside the subquery's rows never poisons the comparison the way NOT IN's list-membership check does. */
/* Q18. A WHERE subquery filters individual rows before grouping; a HAVING subquery filters after GROUP BY, typically comparing an aggregate to another aggregate. */
/* Q19. Yes - that's exactly what makes it a correlated subquery; an uncorrelated subquery cannot see the outer query's columns. */
/* Q20. A correlated subquery returns one computed value per outer row without duplicating it; a LEFT JOIN can duplicate outer rows if there are multiple matches, so it needs aggregation to get the same single-value result. */
/* Q21. The planner can rewrite an uncorrelated IN/EXISTS subquery into a semi-join/anti-join whenever doing so preserves the same result set, usually for simple, non-correlated predicates. */
/* Q22. Some engines cache repeated subquery results across executions; PostgreSQL has no such subquery result cache - each execution re-runs unless the planner materializes/inlines it itself. */
/* Q23. An uncorrelated subquery is planned and executed once, its result reused for every outer row; a correlated subquery is conceptually (or literally, if not rewritten) re-evaluated once per outer row. */
/* Q24. It happens when a subquery meant to return one value (used with =, in SELECT, or in CASE) actually returns multiple rows, because the WHERE inside it wasn't selective enough. */
/* Q25. Subqueries in WHERE can often be rewritten by the planner into a join/semi-join, which is usually efficient; subqueries in SELECT are evaluated per output row and can't be turned into a join, so they tend to be slower on large result sets. */

/* ============================================================
   SECTION B: IN / NOT IN / EXISTS / NOT EXISTS (25)
   ------------------------------------------------------------ */
/* Q26. */
SELECT * FROM sales.orders
WHERE cust_id IN (
  SELECT cust_id FROM sales.orders GROUP BY cust_id ORDER BY SUM(net_total) DESC LIMIT 10
);

/* Q27. */
SELECT * FROM customers.customers
WHERE customer_id IN (SELECT cust_id FROM sales.orders WHERE cust_id IS NOT NULL);

/* Q28. */
SELECT * FROM customers.customers
WHERE customer_id NOT IN (SELECT customer_id FROM loyalty.members WHERE customer_id IS NOT NULL);

/* Q29. */
SELECT * FROM products.products
WHERE product_id IN (SELECT prod_id FROM sales.order_items WHERE prod_id IS NOT NULL);

/* Q30. */
SELECT * FROM support.tickets
WHERE customer_id IN (
  SELECT cust_id FROM sales.orders GROUP BY cust_id HAVING SUM(net_total) > 100000
);

/* Q31. */
SELECT * FROM stores.employees
WHERE store_id IN (SELECT store_id FROM stores.stores WHERE city = 'Mumbai');

/* Q32. */
SELECT * FROM sales.orders
WHERE order_status IN ('Delivered','Cancelled','Returned');

/* Q33. */
SELECT * FROM products.products
WHERE brand_id IN (
  SELECT brand_id FROM core.dim_brand
  WHERE category_id = (SELECT category_id FROM core.dim_category WHERE category_name = 'Electronics')
);

/* Q34. */
SELECT * FROM sales.shipments
WHERE order_id IN (
  SELECT o.order_id FROM sales.orders o
  JOIN customers.customers c ON c.customer_id = o.cust_id
  WHERE c.tier = 'Gold'
);

/* Q35. */
SELECT * FROM payroll.pay_slips
WHERE employee_id IN (
  SELECT employee_id FROM stores.employees
  WHERE dept_id = (SELECT dept_id FROM core.dim_department WHERE dept_name = 'Sales')
);

/* Q36. */
SELECT * FROM customers.customers c
WHERE EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id);

/* Q37. */
SELECT * FROM products.products p
WHERE EXISTS (SELECT 1 FROM customers.reviews r WHERE r.product_id = p.product_id);

/* Q38. */
SELECT * FROM stores.stores s
WHERE EXISTS (SELECT 1 FROM stores.employees e WHERE e.store_id = s.store_id);

/* Q39. */
SELECT * FROM supply_chain.warehouses w
WHERE EXISTS (SELECT 1 FROM supply_chain.inventory_snapshots i WHERE i.warehouse_id = w.warehouse_id);

/* Q40. */
SELECT * FROM marketing.campaigns c
WHERE EXISTS (SELECT 1 FROM marketing.ads_spend a WHERE a.campaign_id = c.campaign_id);

/* Q41. */
SELECT * FROM customers.customers c
WHERE NOT EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id);

/* Q42. */
SELECT * FROM products.products p
WHERE NOT EXISTS (SELECT 1 FROM customers.reviews r WHERE r.product_id = p.product_id);

/* Q43. */
SELECT * FROM core.dim_brand b
WHERE NOT EXISTS (SELECT 1 FROM products.products p WHERE p.brand_id = b.brand_id);

/* Q44. */
SELECT * FROM stores.employees e
WHERE NOT EXISTS (SELECT 1 FROM payroll.pay_slips ps WHERE ps.employee_id = e.employee_id);

/* Q45. */
SELECT * FROM sales.orders o
WHERE NOT EXISTS (SELECT 1 FROM sales.shipments s WHERE s.order_id = o.order_id);

/* Q46. */
SELECT c.*
FROM customers.customers c
WHERE EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id)
  AND c.customer_id IN (
    SELECT cust_id FROM sales.orders GROUP BY cust_id HAVING COUNT(*) > 5
  );

/* Q47. */
SELECT p.*
FROM products.products p
WHERE NOT EXISTS (
  SELECT 1 FROM customers.reviews r WHERE r.product_id = p.product_id AND r.rating = 5
);

/* Q48. LEFT JOIN ... WHERE right.key IS NULL finds unmatched rows by joining then filtering nulls (can produce duplicates before filtering, and confuses multi-column joins); NOT EXISTS is a direct existence check, clearer intent, and safer with multi-column or NULL-bearing join conditions - Postgres usually plans both the same way (Anti Join). */
/* Q49. */
SELECT c.customer_id,
       EXISTS (SELECT 1 FROM sales.orders o WHERE o.cust_id = c.customer_id) AS has_ordered
FROM customers.customers c;

/* Q50. */
SELECT c.customer_id,
       CASE WHEN EXISTS (SELECT 1 FROM loyalty.members m WHERE m.customer_id = c.customer_id)
            THEN 'Loyalty Member' ELSE 'Guest' END AS member_status
FROM customers.customers c;

/* ============================================================
   SECTION C: ANY / SOME / ALL (25)
   ------------------------------------------------------------ */
/* Q51. */
SELECT * FROM products.products
WHERE price > ANY (
  SELECT p2.price FROM products.products p2
  JOIN core.dim_brand b ON b.brand_id = p2.brand_id
  JOIN core.dim_category cat ON cat.category_id = b.category_id
  WHERE cat.category_name = 'Electronics'
);

/* Q52. */
SELECT * FROM sales.orders
WHERE net_total > ALL (SELECT net_total FROM sales.orders WHERE store_id = 1);

/* Q53. */
SELECT * FROM loyalty.members
WHERE tier_id = ANY (SELECT tier_id FROM loyalty.tiers WHERE min_points > 1000);

/* Q54. */
SELECT * FROM stores.employees
WHERE salary > ALL (SELECT salary FROM stores.employees WHERE role = 'Sales Executive');

/* Q55. */
SELECT * FROM customers.reviews
WHERE rating < ANY (SELECT rating FROM customers.reviews WHERE product_id = 1);

/* Q56. */
SELECT * FROM support.tickets
WHERE priority = ANY (ARRAY['Critical','High']);

/* Q57. */
SELECT * FROM products.products
WHERE brand_id <> ALL (SELECT brand_id FROM core.dim_brand WHERE category_id = 1);

/* Q58. */
SELECT * FROM sales.orders
WHERE net_total = (SELECT MAX(net_total) FROM sales.orders);

/* Q59. */
SELECT * FROM products.products
WHERE price = (SELECT MIN(price) FROM products.products);

/* Q60. */
SELECT * FROM stores.employees
WHERE salary = (SELECT MAX(salary) FROM stores.employees WHERE dept_id = 1);

/* Q61. */
SELECT * FROM sales.orders
WHERE net_total > (SELECT AVG(net_total) FROM sales.orders);

/* Q62. */
SELECT * FROM loyalty.members
WHERE tier_id > (SELECT MIN(tier_id) FROM loyalty.members);

/* Q63. */
SELECT * FROM payroll.pay_slips
WHERE gross_salary > (SELECT AVG(gross_salary) FROM payroll.pay_slips);

/* Q64. */
SELECT * FROM sales.shipments
WHERE delivered_date IS NULL
  AND shipped_date < (SELECT MIN(shipped_date) + INTERVAL '7 days' FROM sales.shipments);

/* Q65. */
SELECT * FROM products.products
WHERE supplier_id = ANY (SELECT supplier_id FROM products.suppliers WHERE city = 'Mumbai');

/* Q66. = ANY(subquery) and IN (subquery) are exactly equivalent for equality - the parser treats IN as sugar for = ANY. */
/* Q67. <> ALL(subquery) and NOT IN (subquery) are equivalent for non-NULL data, but <> ALL still returns UNKNOWN (not TRUE) for a subquery row that is NULL, same NULL-trap as NOT IN. */
/* Q68. > ANY(subquery) means the value is greater than at least one row returned by the subquery (greater than the minimum). */
/* Q69. > ALL(subquery) means the value is greater than every row returned by the subquery (greater than the maximum). */
/* Q70. < ANY(subquery) means the value is less than at least one row returned (less than the maximum). */
/* Q71. < ALL(subquery) means the value is less than every row returned (less than the minimum). */
/* Q72. SOME is just a synonym for ANY in the SQL standard and in Postgres - = SOME(...) behaves identically to = ANY(...). */
/* Q73. */
SELECT * FROM sales.orders WHERE store_id = ANY (ARRAY[1,2,3]);

/* Q74. ANY with a subquery returning 0 rows is always FALSE, regardless of the comparison operator - there is nothing to be "greater/less/equal than at least one of". */
/* Q75. ALL with a subquery returning 0 rows is always TRUE (vacuous truth) - the condition holds for "every row of an empty set" by definition. */

/* ============================================================
   SECTION D: SCALAR SUBQUERIES IN SELECT (25)
   ------------------------------------------------------------ */
/* Q76. */
SELECT order_id, net_total,
       (SELECT AVG(net_total) FROM sales.orders) AS overall_avg
FROM sales.orders;

/* Q77. */
SELECT c.customer_id,
       (SELECT COUNT(*) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS orders
FROM customers.customers c
LIMIT 200;

/* Q78. */
SELECT p.product_id,
       (SELECT AVG(r.rating) FROM customers.reviews r WHERE r.product_id = p.product_id) AS avg_rating
FROM products.products p
LIMIT 500;

/* Q79. */
SELECT s.store_id,
       (SELECT COUNT(*) FROM stores.employees e WHERE e.store_id = s.store_id) AS emp_count
FROM stores.stores s;

/* Q80. */
SELECT c.campaign_id,
       (SELECT SUM(a.amount) FROM marketing.ads_spend a WHERE a.campaign_id = c.campaign_id) AS total_spend
FROM marketing.campaigns c;

/* Q81. */
SELECT r.region_id, r.region_name,
       (SELECT COUNT(*) FROM stores.stores s WHERE s.region_id = r.region_id) AS store_count
FROM core.dim_region r;

/* Q82. */
SELECT c.customer_id,
       (SELECT MAX(o.order_date) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS last_order_date
FROM customers.customers c
LIMIT 200;

/* Q83. */
SELECT p.product_id,
       (SELECT MAX(r.review_date) FROM customers.reviews r WHERE r.product_id = p.product_id) AS last_review_date
FROM products.products p
LIMIT 500;

/* Q84. */
SELECT e.employee_id,
       (SELECT ps.salary_month FROM payroll.pay_slips ps
        WHERE ps.employee_id = e.employee_id ORDER BY ps.payment_date DESC LIMIT 1) AS last_pay_month
FROM stores.employees e;

/* Q85. */
SELECT t.ticket_id, t.customer_id,
       (SELECT COUNT(*) FROM support.tickets t2
        WHERE t2.customer_id = t.customer_id AND t2.ticket_id <> t.ticket_id) AS other_tickets_by_customer
FROM support.tickets t
LIMIT 500;

/* Q86. */
SELECT c.customer_id,
       (SELECT tr.tier_name FROM loyalty.members m
        JOIN loyalty.tiers tr ON tr.tier_id = m.tier_id
        WHERE m.customer_id = c.customer_id) AS loyalty_tier_name
FROM customers.customers c;

/* Q87. */
SELECT o.order_id,
       (SELECT c.first_name || ' ' || c.last_name FROM customers.customers c WHERE c.customer_id = o.cust_id) AS customer_name
FROM sales.orders o;

/* Q88. */
SELECT o.order_id,
       (SELECT r.region_name FROM stores.stores s
        JOIN core.dim_region r ON r.region_id = s.region_id
        WHERE s.store_id = o.store_id) AS region_name
FROM sales.orders o;

/* Q89. */
SELECT t.ticket_id,
       (SELECT e.first_name || ' ' || e.last_name FROM stores.employees e WHERE e.employee_id = t.agent_id) AS agent_name
FROM support.tickets t;

/* Q90. */
SELECT s.shipment_id,
       (SELECT c.email FROM sales.orders o
        JOIN customers.customers c ON c.customer_id = o.cust_id
        WHERE o.order_id = s.order_id) AS customer_email
FROM sales.shipments s;

/* Q91. */
SELECT * FROM sales.orders
WHERE net_total > (SELECT AVG(net_total) FROM sales.orders);

/* Q92. */
SELECT cust_id, SUM(net_total) AS total_spend
FROM sales.orders
GROUP BY cust_id
HAVING SUM(net_total) > (SELECT AVG(net_total) FROM sales.orders);

/* Q93. */
SELECT p.product_id, p.product_name, p.price
FROM products.products p
WHERE p.product_id <= 1000
ORDER BY (SELECT AVG(r.rating) FROM customers.reviews r WHERE r.product_id = p.product_id) DESC NULLS LAST;

/* Q94. */
SELECT order_id, net_total,
       CASE WHEN net_total > (SELECT AVG(net_total) FROM sales.orders)
            THEN 'Above Average' ELSE 'Below/Equal Average' END AS spend_flag
FROM sales.orders;

/* Q95. */
SELECT c.customer_id,
       (SELECT COUNT(*) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS order_count,
       (SELECT COALESCE(SUM(o.net_total),0) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS total_spend,
       (SELECT MAX(o.order_date) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS last_order_date,
       (SELECT COUNT(*) FROM support.tickets t WHERE t.customer_id = c.customer_id) AS ticket_count,
       (SELECT COUNT(*) FROM customers.reviews r WHERE r.customer_id = c.customer_id) AS review_count
FROM customers.customers c
LIMIT 200;

/* Q96. */
SELECT r.region_id, r.region_name,
       (SELECT COALESCE(SUM(o.net_total),0) FROM sales.orders o
        JOIN stores.stores s ON s.store_id = o.store_id WHERE s.region_id = r.region_id) AS region_revenue,
       ROUND(100.0 * (SELECT COALESCE(SUM(o.net_total),0) FROM sales.orders o
              JOIN stores.stores s ON s.store_id = o.store_id WHERE s.region_id = r.region_id)
             / (SELECT SUM(net_total) FROM sales.orders), 2) AS pct_of_total_revenue
FROM core.dim_region r;

/* Q97. */
SELECT c.customer_id,
       (SELECT COUNT(*) + 1 FROM (SELECT cust_id, SUM(net_total) AS total FROM sales.orders GROUP BY cust_id) x
        WHERE x.total > (SELECT COALESCE(SUM(net_total),0) FROM sales.orders o WHERE o.cust_id = c.customer_id)) AS spend_rank
FROM customers.customers c
WHERE c.customer_id <= 20;

/* Q98. */
SELECT order_id, net_total,
       net_total > (SELECT AVG(net_total) FROM sales.orders) AS is_above_average
FROM sales.orders;

/* Q99. */
SELECT order_id, net_total,
       (SELECT MAX(net_total) FROM sales.orders) - net_total AS distance_from_max
FROM sales.orders;

/* Q100. */
SELECT c.customer_id,
       (SELECT COUNT(*) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS order_count,
       (SELECT COALESCE(SUM(o.net_total),0) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS total_spend,
       (SELECT COALESCE(AVG(o.net_total),0) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS avg_order_value,
       (SELECT MIN(o.order_date) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS first_order_date,
       (SELECT MAX(o.order_date) FROM sales.orders o WHERE o.cust_id = c.customer_id) AS last_order_date,
       (SELECT COUNT(*) FROM customers.reviews r WHERE r.customer_id = c.customer_id) AS review_count,
       (SELECT COALESCE(AVG(r.rating),0) FROM customers.reviews r WHERE r.customer_id = c.customer_id) AS avg_rating_given,
       (SELECT COUNT(*) FROM support.tickets t WHERE t.customer_id = c.customer_id) AS ticket_count,
       (SELECT COUNT(*) FROM sales.returns rt JOIN sales.orders o ON o.order_id = rt.order_id WHERE o.cust_id = c.customer_id) AS return_count,
       (SELECT m.points_balance FROM loyalty.members m WHERE m.customer_id = c.customer_id) AS loyalty_points
FROM customers.customers c
LIMIT 100;

/* ============================================================
   END OF ANSWER KEY - Subqueries Part 1 - EASY LEVEL (100/100)
============================================================ */
