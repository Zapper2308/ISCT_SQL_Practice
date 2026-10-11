/* ============================================================
   ANSWER KEY - Scalar Functions (String & Date) (CRAZY LEVEL)
   Curriculum:   RetailMart V3
   Note: this RetailMart DB has only the built-in `plpgsql` extension
   enabled. Questions the question file itself flags as needing
   pg_trgm / fuzzystrmatch / pgcrypto / a persisted tsvector+GIN index
   ("(accio_NN)") are answered conceptually - they are not runnable
   on this shared, extension-free, read-mostly database.
   ============================================================ */

/* Q1. */
SELECT email FROM customers.customers
WHERE email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$';

/* Q2. */
SELECT email, (regexp_match(email, '@(.+)$'))[1] AS domain FROM customers.customers;

/* Q3. */
SELECT phone, (regexp_match(phone, '^\+(\d{1,3})'))[1] AS country_code FROM customers.customers;

/* Q4. */
SELECT customer_id, regexp_split_to_array(first_name || ' ' || last_name, '\s+') AS tokens
FROM customers.customers;

/* Q5. */
SELECT review_id, regexp_matches(review_text, '#(\w+)', 'g') AS hashtag FROM customers.reviews;

/* Q6. */
SELECT * FROM customers.customers WHERE (first_name || last_name) ~ '([a-zA-Z])\1';

/* Q7. */
SELECT phone, regexp_replace(phone, '\D', '', 'g') AS digits_only FROM customers.customers;

/* Q8. */
SELECT phone, regexp_replace(phone, '^(.{3})(.*)(.{2})$', '\1***\3') AS masked FROM customers.customers;

/* Q9. */
SELECT * FROM customers.customers WHERE split_part(email, '@', 1) ~ '\d';

/* Q10. */
SELECT * FROM customers.customers WHERE email !~ '\.(com|net|org|in)$';

/* Q11. */
SELECT * FROM customers.customers WHERE first_name SIMILAR TO '[A-Z][a-z]*';

/* Q12. */
SELECT subject, LOWER(regexp_replace(subject, '\W+', '-', 'g')) AS slug FROM support.tickets;

/* Q13. */
SELECT * FROM support.tickets WHERE subject ~ '\m(\w+)\M.*\1';

/* Q14. */
SELECT first_name, LENGTH(first_name) - LENGTH(regexp_replace(first_name, '[aeiouAEIOU]', '', 'g')) AS vowel_count
FROM customers.customers;

/* Q15. */
SELECT split_part(first_name || ' ' || last_name, ' ', 1) AS first_token FROM customers.customers;

/* Q16. */
SELECT v, v = REVERSE(v) AS is_palindrome FROM (VALUES ('madam'), ('hello'), ('level'), ('retailmart')) AS t(v);

/* Q17. */
SELECT * FROM customers.customers WHERE (first_name || last_name) ~ '[^\x00-\x7F]';

/* Q18. */
SELECT * FROM customers.addresses WHERE pincode ~ '^\d{6}$';

/* Q19. */
SELECT email, SUBSTRING(email FROM '@(.*)$') AS domain FROM customers.customers;

/* Q20. */
SELECT UPPER(LEFT(first_name, 1)) || SUBSTRING(first_name FROM 2) AS capitalized FROM customers.customers;

/* Q21. */
SELECT * FROM customers.reviews WHERE review_text ~* 'quality';

/* Q22. */
SELECT review_id, array_length(regexp_split_to_array(review_text, '\s+'), 1) AS word_count FROM customers.reviews;

/* Q23. */
SELECT expense_id, regexp_matches(description, '\d+', 'g') AS numbers FROM finance.expenses;

/* Q24. */
SELECT * FROM sales.orders
WHERE order_status ~ '^(Pending|Processing|Shipped|Delivered|Cancelled|Returned|Failed|Out for Delivery)$';

/* Q25. */
SELECT * FROM products.products WHERE product_name <> TRIM(product_name);

/* Q26. */
SELECT concat_ws(' ', NULLIF(first_name, ''), NULLIF(last_name, '')) AS display_name FROM customers.customers;

/* Q27. */
SELECT format('Customer %s (%s) registered on %s', customer_id, email, registration_date) AS log_line
FROM customers.customers;

/* Q28. */
SELECT LPAD(order_id::TEXT, 10, '0') AS padded_id FROM sales.orders;

/* Q29. */
SELECT phone, TRANSLATE(phone, '()-. ', '') AS stripped FROM customers.customers;

/* Q30. */
SELECT email, OVERLAY(email PLACING '***' FROM 3 FOR 3) AS masked_email FROM customers.customers;

/* Q31. */
SELECT city, INITCAP(LOWER(city)) AS city_norm FROM customers.addresses;

/* Q32. */
SELECT email, LEFT(email, 5) AS head, RIGHT(email, 5) AS tail FROM customers.customers;

/* Q33. */
SELECT email, split_part(email, '@', 2) AS domain FROM customers.customers;

/* Q34. */
SELECT first_name || ' ' || last_name AS original,
       array_to_string(string_to_array(first_name || ' ' || last_name, ' '), '-') AS round_trip
FROM customers.customers;

/* Q35. */
SELECT encode('hello'::bytea, 'hex') AS hex_encoded,
       convert_from(decode(encode('hello'::bytea, 'hex'), 'hex'), 'UTF8') AS round_trip;

/* Q36. */
SELECT encode('hello'::bytea, 'base64') AS b64_encoded,
       convert_from(decode(encode('hello'::bytea, 'base64'), 'base64'), 'UTF8') AS round_trip;

/* Q37. */
SELECT TRANSLATE(encode('hello world'::bytea, 'base64'), '+/', '-_') AS url_safe_b64;

/* Q38. */
SELECT customer_id, MD5(email) AS email_fingerprint FROM customers.customers;

/* Q39. */
SELECT product_id, TO_CHAR(price, 'FM99,99,999.00') AS price_display FROM products.products;

/* Q40. */
SELECT store_id, COUNT(*) AS n, REPEAT('#', (COUNT(*) / 50)::int) AS bar
FROM sales.orders
GROUP BY store_id
ORDER BY store_id;

/* Q41. */
SELECT ASCII('A') AS code_of_a, CHR(65) AS char_of_65;

/* Q42. */
SELECT * FROM customers.customers WHERE STARTS_WITH(email, 'a') AND LENGTH(email) > 15;

/* Q43. */
SELECT BTRIM('  hi  ') AS bt, LTRIM('  hi  ') AS lt, RTRIM('  hi  ') AS rt;

/* Q44. */
SELECT email, REVERSE(split_part(REVERSE(split_part(email, '@', 2)), '.', 1)) AS tld
FROM customers.customers;

/* Q45. */
SELECT email, POSITION('@' IN email) AS at_pos FROM customers.customers;

/* Q46. */
SELECT phone, '+91' || RIGHT(regexp_replace(phone, '\D', '', 'g'), 10) AS phone_std FROM customers.customers;

/* Q47. */
SELECT INITCAP(regexp_replace(TRIM(first_name || ' ' || last_name), '\s+', ' ', 'g')) AS clean_name
FROM customers.customers;

/* Q48. */
SELECT order_id, TO_CHAR(order_date, 'FMDD Month YYYY') AS human_date FROM sales.orders;

/* Q49. */
SELECT LOWER(first_name || ' ' || last_name || ' ' || email) AS search_blob FROM customers.customers;

/* Q50. */
SELECT first_name, CHAR_LENGTH(first_name) AS chars, OCTET_LENGTH(first_name) AS bytes FROM customers.customers;

/* Q51. */
SELECT call_start_time, (call_start_time AT TIME ZONE 'Asia/Kolkata') AT TIME ZONE 'Asia/Kolkata' AS round_trip
FROM call_center.calls;

/* Q52. */
SELECT '2025-01-01 12:00:00+00'::timestamptz AT TIME ZONE 'America/New_York' AS ny_wall_clock;

/* Q53. */
WITH m AS (SELECT (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day')::date AS last_day)
SELECT last_day - CASE WHEN EXTRACT(DOW FROM last_day) = 0 THEN 2
                        WHEN EXTRACT(DOW FROM last_day) = 6 THEN 1
                        ELSE 0 END AS last_business_day
FROM m;

/* Q54. */
SELECT EXTRACT(QUARTER FROM CURRENT_DATE - INTERVAL '3 months') AS quarter_3mo_ago;

/* Q55. */
SELECT TO_CHAR(CURRENT_DATE, 'IW') AS iso_week, TO_CHAR(CURRENT_DATE, 'WW') AS us_week;

/* Q56. */
SELECT to_timestamp(1700000000.123456) AS ts_from_epoch;

/* Q57. */
SELECT DATE_TRUNC('month', order_date) AS month,
       SUM(net_total) FILTER (WHERE order_status = 'Delivered') AS delivered_revenue
FROM sales.orders
GROUP BY month
ORDER BY month;

/* Q58. */
SELECT make_date(2025, 6, 15) AS d, make_timestamp(2025, 6, 15, 10, 30, 0) AS ts;

/* Q59. */
SELECT justify_interval(INTERVAL '90 days') AS justified;

/* Q60. */
SELECT d::int AS yr, (d % 4 = 0 AND (d % 100 <> 0 OR d % 400 = 0)) AS is_leap
FROM (VALUES (2024), (2025), (2000), (1900)) AS t(d);

/* Q61. */
SELECT TO_CHAR(INTERVAL '5 hours 23 minutes 10 seconds', 'HH24"h" MI"m" SS"s"') AS formatted;

/* Q62. */
SELECT view_id, DATE_TRUNC('hour', view_timestamp) + (FLOOR(EXTRACT(MINUTE FROM view_timestamp) / 15) * 15 || ' minutes')::interval AS bucket_15min
FROM web_events.page_views;

/* Q63. */
SELECT view_timestamp, to_timestamp(ROUND(EXTRACT(EPOCH FROM view_timestamp) / 300) * 300) AS rounded_5min
FROM web_events.page_views;

/* Q64. */
SELECT '2025-03-08 12:00:00-05'::timestamptz + INTERVAL '1 day' AS next_day_instant;

/* Q65. */
SELECT order_id, order_date, order_date::timestamp AT TIME ZONE 'Asia/Kolkata' AS zoned FROM sales.orders;

/* Q66. */
SELECT '2025-01-01 12:00:00+00'::timestamptz = '2025-01-01 17:30:00+05:30'::timestamptz AS same_instant;

/* Q67. */
SELECT COUNT(*) AS business_days
FROM generate_series('2025-06-01'::date, '2025-06-30'::date, '1 day') d
WHERE EXTRACT(DOW FROM d) NOT IN (0, 6);

/* Q68. */
SELECT generate_series('2025-01-01'::date, '2025-12-31'::date, '1 day')::date AS d;

/* Q69. */
SELECT CURRENT_DATE + (((8 - EXTRACT(ISODOW FROM CURRENT_DATE)::int) % 7)) AS next_monday;

/* Q70. */
SELECT CURRENT_DATE - (((EXTRACT(ISODOW FROM CURRENT_DATE)::int - 5 + 7) % 7)) AS previous_friday;

/* Q71. */
SELECT generate_series('2025-01-01'::date, '2025-10-01'::date, '3 months')::date AS quarter_start;

/* Q72. */
SELECT customer_id, EXTRACT(YEAR FROM AGE(registration_date)) * 12 + EXTRACT(MONTH FROM AGE(registration_date)) AS age_months
FROM customers.customers;

/* Q73. */
SELECT ticket_id,
       (SELECT COUNT(*) FROM generate_series(created_date::date, COALESCE(resolved_date::date, CURRENT_DATE), '1 day') d
        WHERE EXTRACT(DOW FROM d) NOT IN (0, 6)) AS business_days_open
FROM support.tickets;

/* Q74. */
SELECT '2025-01-31'::date + INTERVAL '1 month' AS safe_month_add;

/* Q75. */
SELECT AGE('2025-03-01'::date, '2025-01-30'::date) AS calendar_aware,
       '2025-03-01'::date - '2025-01-30'::date AS exact_days;

/* Q76. */
SELECT to_tsvector('english', 'running runs ran') AS stemmed;

/* Q77. */
SELECT * FROM customers.reviews
WHERE to_tsvector('english', review_text) @@ to_tsquery('english', 'phone & repair');

/* Q78. */
SELECT review_id, ts_rank(to_tsvector('english', review_text), to_tsquery('english', 'phone')) AS rank
FROM customers.reviews
WHERE to_tsvector('english', review_text) @@ to_tsquery('english', 'phone')
ORDER BY rank DESC;

/* Q79. */
SELECT review_id, ts_headline('english', review_text, to_tsquery('english', 'phone')) AS highlighted
FROM customers.reviews
WHERE to_tsvector('english', review_text) @@ to_tsquery('english', 'phone');

/* Q80. */
SELECT * FROM customers.reviews WHERE to_tsvector('english', review_text) @@ to_tsquery('english', 'phon:*');

/* Q81. */
SELECT * FROM customers.reviews WHERE to_tsvector('english', review_text) @@ to_tsquery('english', 'phone & !repair');

/* Q82. */
SELECT * FROM customers.reviews WHERE to_tsvector('english', review_text) @@ phraseto_tsquery('english', 'great product');

/* Q83. */
SELECT * FROM customers.reviews
WHERE to_tsvector('english', review_text) @@ websearch_to_tsquery('english', '"great product" -bad');

/* Q84. */
SELECT plainto_tsquery('english', 'running fast') AS plain, to_tsquery('english', 'running & fast') AS explicit;

/* Q85. */
SELECT ticket_id, setweight(to_tsvector('english', subject), 'A') AS weighted_vector FROM support.tickets;

/* Q86. */
SELECT * FROM customers.reviews
WHERE to_tsvector('english', review_text) @@ to_tsquery('english', 'phone') AND rating >= 4;

/* Q87. */
SELECT to_tsvector('english', 'running') AS english_config, to_tsvector('simple', 'running') AS simple_config;

/* Q88. */
SELECT gen_random_uuid() AS token;

/* Q89. Would persist a generated tsvector column (`ADD COLUMN search_vec tsvector GENERATED ALWAYS AS (to_tsvector('english', review_text)) STORED`) plus a GIN index on it for fast search - persisting new schema/indexes is a Day-20 (indexing) task best done in your own accio_NN sandbox database, not this shared RetailMart. */
/* Q90. Would create a custom text-search configuration (`CREATE TEXT SEARCH CONFIGURATION ...`) layered with the `unaccent` extension so accented characters are normalized before stemming - both the extension and this DDL belong in your own accio_NN sandbox, not this shared RetailMart. */
/* Q91. Would use `similarity(a, b)` and the `%` operator from the pg_trgm extension to score/filter fuzzy string matches - not runnable here because pg_trgm isn't installed on this shared RetailMart database. */
/* Q92. Would order results by trigram distance (`ORDER BY col <-> 'query'`) backed by a GiST index from pg_trgm, for fast nearest-match fuzzy search - not runnable here because pg_trgm isn't installed. */
/* Q93. Would use `levenshtein(a, b)` from the fuzzystrmatch extension to compute a numeric edit-distance between two strings - not runnable here because fuzzystrmatch isn't installed. */
/* Q94. Would use `soundex(a)`, `metaphone(a, len)` or `dmetaphone(a)` from fuzzystrmatch to compare how two strings SOUND rather than how they're spelled - not runnable here because fuzzystrmatch isn't installed. */
/* Q95. Would use pgcrypto's `digest(data, 'sha256')` for a SHA-256 hash and `hmac(data, key, 'sha256')` for a keyed HMAC - not runnable here because pgcrypto isn't installed on this shared RetailMart database. */
/* Q96. Would use pgcrypto's `crypt(password, gen_salt('bf'))` to bcrypt-hash a password (and the same `crypt()` call to verify a login) - not runnable here because pgcrypto isn't installed. */
/* Q97. Would use pgcrypto's `pgp_sym_encrypt(data, passphrase)` / `pgp_sym_decrypt(data, passphrase)` for symmetric encryption of sensitive column data - not runnable here because pgcrypto isn't installed. */
/* Q98. A fuzzy near-duplicate detection pipeline: normalize each string (lowercase, trim, strip punctuation), compute a trigram signature or hash, bucket candidates by a cheap blocking key (e.g. same first 3 chars or same domain), then only run the expensive similarity()/levenshtein() comparison within each small bucket rather than all-pairs across the whole table. */
/* Q99. A search-bar fallback pattern: run the query first as full-text search (to_tsvector @@ to_tsquery / websearch_to_tsquery) for fast, relevance-ranked results; if that returns zero rows (likely a typo or unusual term), fall back to a pg_trgm similarity/trigram-distance search to catch near-matches the stemmed FTS index missed. */

/* Q100. */
SELECT customer_id,
       MD5(email) AS email_hash,
       encode(CONVERT_TO(first_name, 'UTF8'), 'base64') AS first_name_b64
FROM customers.customers;

/* ============================================================
   END OF ANSWER KEY - CRAZY LEVEL (100/100)
============================================================ */
