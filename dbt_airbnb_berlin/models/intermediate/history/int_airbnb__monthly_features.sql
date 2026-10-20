{{
 config(
 materialized = "table"
 )
}}

WITH bounds AS (
 SELECT
 MIN(cohort_date) AS min_cohort,
 MAX(cohort_date) AS max_cohort
 FROM {{ ref('int_airbnb_cleaned__listings') }}
),

months AS (
 SELECT GENERATE_SERIES(
 DATE_TRUNC('month', (SELECT min_cohort FROM bounds)),
 DATE_TRUNC('month', (SELECT max_cohort FROM bounds)) - INTERVAL '1 month',
 INTERVAL '1 month')::date AS target_month
),

listing_life AS (
 SELECT
 listings_id,
 first_seen,
 last_seen
 FROM {{ ref('dim_airbnb_listings') }}
)

SELECT
 {{ dbt_utils.generate_surrogate_key(['l.listings_id', 'm.target_month']) }} AS month_key,
 l.listings_id,
 m.target_month
FROM listing_life l
CROSS JOIN months m
WHERE m.target_month >= DATE_TRUNC('month', l.first_seen)
AND m.target_month <= DATE_TRUNC('month', l.last_seen)