{{
 config(
 materialized = "table"
 )
}}

SELECT DISTINCT ON (reviews_id, listing_id)
    reviews_id,
    surrogate_key,
    listing_id as listings_id,
    reviewer_id,
    "date" AS review_date,
    DATE_TRUNC('month', "date")::date AS review_month,
    EXTRACT(YEAR FROM "date")::int AS review_year,
    comments,
    LENGTH(comments) AS comment_length,
    comments IS NULL OR LENGTH(TRIM(comments)) = 0 AS is_empty_comment,
    TO_DATE(data_cohort, 'YY.MM.DD') AS first_seen_cohort,
    data_cohort
FROM {{ ref('stg_airbnb__reviews') }}
ORDER BY reviews_id, TO_DATE(data_cohort, 'YY.MM.DD')