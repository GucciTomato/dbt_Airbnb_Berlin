{{ 
    config(
        materialized= "view"
    )
}}

WITH first_last_seen AS (
    SELECT
        reviews_id,
        MIN(TO_DATE(data_cohort, 'YY.MM.DD')) AS first_seen,
        MAX(TO_DATE(data_cohort, 'YY.MM.DD')) AS last_seen
    FROM {{ ref('int_airbnb_history__reviews') }}
    GROUP BY reviews_id
)

SELECT 
    listing_id,
    reviews_id,
    surrogate_key,
    "date",
    reviewer_id,
    comments,
    data_cohort,
    fl.last_seen = MAX(fl.last_seen) OVER () AS is_active_in_latest
FROM {{ ref('int_airbnb_history__reviews') }} hist
LEFT JOIN first_last_seen fl ON hist.reviews_id = fl.reviews_id
