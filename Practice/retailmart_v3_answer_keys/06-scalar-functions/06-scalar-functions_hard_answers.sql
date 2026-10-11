/* ============================================================
   ANSWER KEY - Scalar Functions (String & Date) (HARD LEVEL)
   Curriculum:   RetailMart V3
   Note: this RetailMart DB has only the built-in `plpgsql` extension
   enabled (no pgcrypto/unaccent/fuzzystrmatch) - questions that
   genuinely require those extensions are answered conceptually
   instead of as a query that would error here.
   ============================================================ */

/* Q1.  LIKE/ILIKE are simple wildcard patterns (%, _), case-sensitive/insensitive respectively; ~ and ~* are POSIX regex matches, case-sensitive/insensitive respectively; ~~ and ~~* are the underlying operator-name equivalents of LIKE and ILIKE (rarely typed directly, but shown by EXPLAIN/catalogs). */
/* Q2.  regexp_matches returns multiple rows (a SETOF text[]) when the 'g' flag is used; regexp_match always returns a single text[] for only the first match. */
/* Q3.  regexp_split_to_array splits a string by a REGEX pattern; string_to_array splits by a fixed literal delimiter string - use the regex version for variable/complex separators (e.g. runs of whitespace), the literal version for a single known character. */
/* Q4.  `\d` is a valid regex escape that Postgres's regex engine understands directly inside a pattern; if the pattern itself is written as a plain (non-E-prefixed, non-dollar-quoted) SQL string literal, a single backslash can be consumed/altered by string-literal escaping rules, so `\\d+` is sometimes needed to guarantee a literal backslash reaches the regex engine - dollar-quoted or E'' strings avoid this. */
/* Q5.  `SUBSTRING(text FROM pattern)` extracts the first substring of `text` that matches the regex `pattern` directly, in one expression - useful for pulling out one piece (e.g. a domain or number) without needing regexp_match's array wrapper. */
/* Q6.  Both produce a date-only text/value from `now()`; `to_char(now(),'YYYY-MM-DD')` gives full control over the display FORMAT as text, while `::date` is a fast type cast that drops the time component and returns an actual DATE value (not text) for further date arithmetic. */
/* Q7.  AGE(end, start) returns a calendar-aware INTERVAL broken into years/months/days (e.g. "1 year 2 months 3 days"); `end - start` on two dates returns a plain integer count of days with no calendar-unit breakdown. */
/* Q8.  `INTERVAL '1 month'` is a calendar unit that lands on the same day next month regardless of that month's length; `INTERVAL '30 days'` is a fixed span - they differ whenever traversing a month that isn't exactly 30 days (11 of the 12 months). */
/* Q9.  CURRENT_TIMESTAMP is fixed to the moment the enclosing TRANSACTION began (constant for the whole transaction), which guarantees every reference to "now" within it is consistent, unlike a live clock that could tick mid-transaction. */
/* Q10. now() and statement_timestamp() are typically the same (the time the current statement started, both frozen per-transaction for now()/CURRENT_TIMESTAMP but statement_timestamp() updates per statement); clock_timestamp() is the true real-time wall clock, changing even within a single statement's execution. */
/* Q11. `AT TIME ZONE` on a TIMESTAMP WITHOUT time zone ASSIGNS that zone (interpreting the stored wall-clock value as being in that zone) and produces a timestamptz; applied to a TIMESTAMPTZ, it CONVERTS to that zone's local wall-clock time and returns a plain timestamp. */
/* Q12. DATE_TRUNC('week', ts) truncates to the start of the ISO week, which always begins on MONDAY in PostgreSQL, regardless of locale. */
/* Q13. A common approach: generate every date in the range with generate_series(), then count how many have EXTRACT(DOW FROM d) NOT IN (0,6) (excluding Saturday/Sunday) - optionally also excluding a holidays table. */
/* Q14. EXTRACT(EPOCH FROM ts) returns the number of seconds since 1970-01-01 UTC as a single numeric value - useful for numeric comparisons, storing as a plain number, or passing to systems that expect Unix time. */
/* Q15. md5() is a built-in PostgreSQL function needing no extension, producing a 128-bit (32 hex char) hash - fine for checksums/fingerprints but not collision-resistant for security purposes; sha256() (via pgcrypto's digest(data,'sha256')) is cryptographically stronger and used when security/tamper-resistance matters, but requires the pgcrypto extension. */
/* Q16. encode(bytea, 'hex'|'base64') converts raw binary data into a printable hex or base64 TEXT representation; decode(text, format) reverses it, turning that encoded text back into the original bytea. */
/* Q17. PostgreSQL has no built-in URL-encode function - you build one yourself, typically with a PL/pgSQL function that loops over each character (or uses regexp_replace with a callback-like pattern) and percent-encodes any character outside the URL-safe set. */
/* Q18. to_tsvector() parses text into a normalized, stemmed, position-tracked "document" (a tsvector) - it's needed for full-text search because it's what @@ tsquery actually matches against, enabling relevance ranking, stemming ("running"~"run"), and GIN-index acceleration that plain LIKE can't provide. */
/* Q19. A functional index like `CREATE INDEX ON t(lower(email))` stores the pre-computed LOWER(email) values, so a query filtering `WHERE LOWER(email) = 'x'` can use that index directly - without it, wrapping the column in LOWER() defeats any plain index on the raw column, forcing a full scan. */
/* Q20. `CAST(x AS TYPE)` is SQL-standard syntax; `x::TYPE` is PostgreSQL's shorthand - they behave identically and fail the same way (a runtime error) on invalid input; the only real difference is portability (CAST works across databases, `::` is Postgres-specific). */
/* Q21. FORMAT() is preferred when building a string with placeholders, especially when identifiers/literals need safe quoting (%I/%L) to avoid SQL-injection-style bugs in dynamic SQL - plain concatenation has no such safety and is harder to read with many interpolated values. */
/* Q22. STRING_AGG(expr, sep ORDER BY sort_expr) concatenates each group's values into one string in the exact order given by its own ORDER BY clause (independent of the outer query's ordering), producing a deterministic ordered list like "Apple, Banana, Cherry". */
/* Q23. JSON_BUILD_OBJECT lets you hand-pick and alias exactly which key/value pairs go into the JSON object from arbitrary expressions; ROW_TO_JSON converts an entire existing row/record (all its columns, with their original names) into JSON in one call - use BUILD_OBJECT for custom shapes, ROW_TO_JSON for a full row dump. */
/* Q24. `GENERATED ALWAYS AS (lower(email)) STORED` defines a column whose value PostgreSQL always computes and physically stores from an expression over other columns - use it to keep a normalized/derived value (like a lowercased email) permanently in sync with its source column without application-level triggers. */
/* Q25. IMMUTABLE functions always return the same output for the same input (safe to index/precompute); STABLE functions return the same result within a single query/statement but can vary between statements (e.g. depend on now()); VOLATILE functions can change on every call - only IMMUTABLE expressions can be used in a functional index, because the index must never need updating just because the function's answer changed. */

/* Q26. */
SELECT email FROM customers.customers
WHERE email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$';

/* Q27. */
SELECT email, (regexp_match(email, '@(.+)$'))[1] AS domain FROM customers.customers;

/* Q28. */
SELECT phone, regexp_match(phone, '^\+(\d{1,3})') AS country_code FROM customers.customers;

/* Q29. */
SELECT customer_id, regexp_split_to_array(first_name || ' ' || last_name, '\s+') AS name_parts
FROM customers.customers;

/* Q30. */
SELECT * FROM customers.customers WHERE email ~ '\d';

/* Q31. */
SELECT phone, regexp_replace(phone, '\D', '', 'g') AS digits_only FROM customers.customers;

/* Q32. */
SELECT phone, regexp_replace(phone, '(.{3})(.+)(.{2})', '\1***\3') AS masked_phone FROM customers.customers;

/* Q33. */
SELECT review_id, regexp_matches(review_text, '#(\w+)', 'g') AS hashtag FROM customers.reviews;

/* Q34. */
SELECT * FROM customers.customers WHERE (first_name || ' ' || last_name) ~ '([a-zA-Z])\1';

/* Q35. */
SELECT * FROM customers.addresses WHERE pincode ~ '^\d{6}$';

/* Q36. */
SELECT * FROM customers.customers WHERE email !~ '\.(com|net|org|in)$';

/* Q37. */
SELECT regexp_replace(first_name || ' ' || last_name, '\s+', '_', 'g') AS underscored_name
FROM customers.customers;

/* Q38. */
SELECT product_name, regexp_replace(product_name, '[^0-9]', '', 'g') AS digits_only FROM products.products;

/* Q39. */
SELECT * FROM support.tickets WHERE subject ~ '\m(\w+)\M.*\1';

/* Q40. */
SELECT * FROM customers.customers WHERE first_name SIMILAR TO '[A-Z][a-z]+';

/* Q41. */
SELECT subject, LOWER(regexp_replace(subject, '\W+', '-', 'g')) AS slug FROM support.tickets;

/* Q42. */
SELECT subject, split_part(subject, ' ', 3) AS third_word FROM support.tickets;

/* Q43. */
SELECT * FROM customers.customers WHERE LOWER(first_name) = REVERSE(LOWER(first_name));

/* Q44. */
SELECT first_name, char_length(first_name) - char_length(regexp_replace(first_name, '[aeiou]', '', 'gi')) AS vowel_count
FROM customers.customers;

/* Q45. */
SELECT product_name, split_part(product_name, ' ', 1) AS first_word FROM products.products;

/* Q46. */
SELECT * FROM customers.customers WHERE LOWER(email) = 'meera.naidu0@bmw.com';

/* Q47. */
SELECT subject, regexp_replace(subject, ' ', '%20', 'g') AS url_encoded_spaces FROM support.tickets;

/* Q48. */
SELECT INITCAP(LOWER(first_name || ' ' || last_name)) AS title_case_name FROM customers.customers;

/* Q49. Would use `unaccent(col)` to strip diacritics (e.g. 'e' for 'é') - not runnable here because the `unaccent` extension isn't installed on this shared RetailMart database. */

/* Q50. Would use `levenshtein(a, b)` from the fuzzystrmatch extension to get an edit-distance score for fuzzy matching two strings - not runnable here because `fuzzystrmatch` isn't installed on this shared RetailMart database. */

/* Q51. */
SELECT ticket_id, AGE(now(), created_date) AS age FROM support.tickets;

/* Q52. */
SELECT call_id,
       EXTRACT(YEAR FROM call_start_time) AS yr,
       EXTRACT(MONTH FROM call_start_time) AS mo,
       EXTRACT(DAY FROM call_start_time) AS dy,
       EXTRACT(HOUR FROM call_start_time) AS hr
FROM call_center.calls;

/* Q53. */
SELECT customer_id, EXTRACT(YEAR FROM AGE(now(), registration_date)) AS tenure_years FROM customers.customers;

/* Q54. */
SELECT view_id,
       DATE_TRUNC('month', view_timestamp) AS month_start,
       DATE_TRUNC('quarter', view_timestamp) AS quarter_start,
       DATE_TRUNC('year', view_timestamp) AS year_start
FROM web_events.page_views
LIMIT 20;

/* Q55. */
SELECT generate_series('2025-01-01'::date, '2025-12-31'::date, '1 day')::date AS d;

/* Q56. */
SELECT (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day')::date AS last_day_of_month;

/* Q57. */
SELECT (DATE_TRUNC('week', CURRENT_DATE) + INTERVAL '6 days')::date AS end_of_week;

/* Q58. */
SELECT COUNT(*) AS business_days
FROM generate_series('2025-01-01'::date, '2025-01-31'::date, '1 day') d
WHERE EXTRACT(DOW FROM d) NOT IN (0, 6);

/* Q59. */
SELECT now() - INTERVAL '90 days' AS minus_90_days, now() - INTERVAL '3 months' AS minus_3_months;

/* Q60. */
SELECT EXTRACT(HOUR FROM call_start_time) AS hr, COUNT(*)
FROM call_center.calls
GROUP BY hr
ORDER BY hr;

/* Q61. */
SELECT call_id, call_start_time AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Kolkata' AS ist_time
FROM call_center.calls;

/* Q62. */
SELECT DATE_TRUNC('month', CURRENT_DATE)::date
       + ((8 - EXTRACT(ISODOW FROM DATE_TRUNC('month', CURRENT_DATE))::int) % 7) AS first_monday;

/* Q63. */
SELECT order_id, order_date, EXTRACT(DOW FROM order_date) IN (0, 6) AS is_weekend FROM sales.orders;

/* Q64. */
SELECT promo_id, end_date - CURRENT_DATE AS days_to_end FROM products.promotions;

/* Q65. */
SELECT order_id, TO_CHAR(order_date, 'IYYY-IW') AS iso_week FROM sales.orders;

/* Q66. */
SELECT order_id,
       CASE WHEN EXTRACT(MONTH FROM order_date) IN (4, 5, 6) THEN 'Q1'
            WHEN EXTRACT(MONTH FROM order_date) IN (7, 8, 9) THEN 'Q2'
            WHEN EXTRACT(MONTH FROM order_date) IN (10, 11, 12) THEN 'Q3'
            ELSE 'Q4' END AS fiscal_quarter
FROM sales.orders;

/* Q67. */
SELECT view_id,
       DATE_TRUNC('hour', view_timestamp) + (FLOOR(EXTRACT(MINUTE FROM view_timestamp) / 15) * 15 || ' minutes')::interval AS bucket_15min
FROM web_events.page_views;

/* Q68. */
SELECT AGE('2025-12-31'::date, '2025-01-01'::date) AS age_interval,
       '2025-12-31'::date - '2025-01-01'::date AS day_diff;

/* Q69. */
SELECT call_id,
       CASE WHEN EXTRACT(HOUR FROM call_start_time) < 6 THEN 'night'
            WHEN EXTRACT(HOUR FROM call_start_time) < 12 THEN 'morning'
            WHEN EXTRACT(HOUR FROM call_start_time) < 18 THEN 'afternoon'
            ELSE 'evening' END AS time_of_day
FROM call_center.calls;

/* Q70. */
SELECT * FROM audit.api_requests WHERE timestamp >= now() - INTERVAL '30 minutes';

/* Q71. */
SELECT * FROM sales.shipments WHERE shipped_date < CURRENT_DATE - INTERVAL '30 days';

/* Q72. */
SELECT to_timestamp(1700000000);

/* Q73. */
SELECT GREATEST(p.start_date, c.start_date) AS overlap_start, LEAST(p.end_date, c.end_date) AS overlap_end
FROM products.promotions p, marketing.campaigns c
WHERE p.start_date <= c.end_date AND c.start_date <= p.end_date;

/* Q74. */
SELECT work_order_id, EXTRACT(EPOCH FROM (end_timestamp - start_timestamp)) / 3600 AS duration_hours
FROM manufacture.work_orders;

/* Q75. */
SELECT order_id, order_date, order_date - INTERVAL '7 days' AS week_before FROM sales.orders;

/* Q76. */
SELECT LOWER(TRIM(email)) FROM customers.customers;

/* Q77. */
SELECT phone,
       CASE WHEN LEFT(regexp_replace(phone, '\D', '', 'g'), 2) = '91'
              THEN '+' || regexp_replace(phone, '\D', '', 'g')
            ELSE '+91' || regexp_replace(phone, '\D', '', 'g') END AS phone_normalized
FROM customers.customers;

/* Q78. */
SELECT INITCAP(regexp_replace(TRIM(first_name || ' ' || last_name), '\s+', ' ', 'g')) AS full_name_clean
FROM customers.customers;

/* Q79. */
SELECT * FROM customers.customers
WHERE LENGTH(first_name || ' ' || last_name) <> LENGTH(TRIM(first_name || ' ' || last_name));

/* Q80. */
SELECT * FROM customers.customers WHERE (first_name || ' ' || last_name) ~ '  ';

/* Q81. */
SELECT * FROM customers.customers WHERE email NOT LIKE '%@%';

/* Q82. */
SELECT * FROM customers.customers WHERE (first_name || ' ' || last_name) ~ '[^\x00-\x7F]';

/* Q83. */
SELECT * FROM stores.stores WHERE city <> INITCAP(city);

/* Q84. */
SELECT product_name, regexp_replace(product_name, '[^a-zA-Z0-9]', '', 'g') AS code_stripped FROM products.products;

/* Q85. */
SELECT customer_id, md5(email) AS email_hash FROM customers.customers;

/* Q86. Would use `encode(digest(phone, 'sha256'), 'hex')` from pgcrypto for a cryptographic SHA-256 hash - not runnable here because pgcrypto isn't installed on this shared RetailMart database (md5(), which is built in, is the closest usable substitute). */

/* Q87. */
SELECT customer_id, encode(('{"id":' || customer_id || '}')::bytea, 'base64') AS payload_b64
FROM customers.customers;

/* Q88. This RetailMart schema stores all dates/timestamps in real DATE/TIMESTAMP columns (validated at insert time), so there is no free-text date column here to demonstrate unparseable formats on; in a schema with a TEXT-typed date column, you'd find bad rows with `WHERE col !~ '^\d{4}-\d{2}-\d{2}$'` before attempting a cast. */

/* Q89. */
SELECT domain, COUNT(*) FROM (
  SELECT SPLIT_PART(email, '@', 2) AS domain FROM customers.customers
) t
GROUP BY domain
HAVING COUNT(*) < 3;

/* Q90. */
SELECT * FROM customers.customers WHERE registration_date > CURRENT_DATE OR registration_date < '1900-01-01';

/* Q91. RetailMart V3's customers.customers table has no date_of_birth column; if it did, the pattern would be `EXTRACT(YEAR FROM AGE(date_of_birth))` to get whole years of age. */

/* Q92. Not a real technique on this schema (no SSN-equivalent column exists) - conceptually you'd do `LEFT(id_text, 4)::int AS birth_year` if an ID encoded the birth year in its first 4 characters. */

/* Q93. */
SELECT city, INITCAP(city) AS city_fixed FROM stores.stores;

/* Q94. */
SELECT COALESCE(first_name, '') || ' ' || COALESCE(last_name, '') AS full_name FROM customers.customers;

/* Q95. */
SELECT COALESCE(NULLIF(TRIM(first_name || ' ' || last_name), ''), SPLIT_PART(email, '@', 1)) AS display_name
FROM customers.customers;

/* Q96. */
SELECT LOWER(first_name || ' ' || last_name) || ' ' || LOWER(email) || ' ' || phone AS search_blob
FROM customers.customers;

/* Q97. */
ALTER TABLE customers.customers DROP COLUMN IF EXISTS email_normalized;
ALTER TABLE customers.customers
  ADD COLUMN email_normalized TEXT GENERATED ALWAYS AS (LOWER(TRIM(email))) STORED;

/* Q98. A JSONB column can never actually store malformed JSON - PostgreSQL validates and rejects bad JSON at INSERT/UPDATE time; the real-world check is on a raw TEXT column before casting, e.g. `SELECT input_params FROM audit.procedure_calls WHERE input_params IS NOT NULL AND input_params::text !~ '^\{.*\}$'` as a crude pre-check, or wrapping the cast in application-level error handling. */

/* Q99. */
SELECT 'first_name' AS col, COUNT(*) FROM customers.customers WHERE first_name <> TRIM(first_name)
UNION ALL
SELECT 'last_name', COUNT(*) FROM customers.customers WHERE last_name <> TRIM(last_name)
UNION ALL
SELECT 'email', COUNT(*) FROM customers.customers WHERE email <> TRIM(email)
UNION ALL
SELECT 'subject', COUNT(*) FROM support.tickets WHERE subject <> TRIM(subject);

/* Q100. */
SELECT
  (SELECT COUNT(*) FROM customers.customers WHERE email NOT LIKE '%@%.%') AS bad_emails,
  (SELECT COUNT(*) FROM customers.customers WHERE phone IS NULL OR phone = '') AS missing_phones,
  (SELECT COUNT(*) FROM (
     SELECT first_name, last_name FROM customers.customers GROUP BY first_name, last_name HAVING COUNT(*) > 1
   ) d) AS dupe_names;

/* ============================================================
   END OF ANSWER KEY - HARD LEVEL (100/100)
============================================================ */
