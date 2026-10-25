{{
 config(
 materialized = "table"
 )
}}

WITH monthly AS (
    SELECT
        listings_id,
        review_month,
        COUNT(*) AS reviews_count,
        COUNT(DISTINCT reviewer_id) AS distinct_reviewers,
        MIN(review_date) AS first_review_in_month,
        MAX(review_date) AS last_review_in_month,
        AVG(comment_length)::numeric(10,1) AS avg_comment_length
    FROM {{ ref('fct_airbnb_reviews') }}
    GROUP BY listings_id, review_month
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['listings_id', 'review_month']) }} AS review_month_key,
    listings_id,
    review_month,
    reviews_count,
    distinct_reviewers,
    first_review_in_month,
    last_review_in_month,
    avg_comment_length,
    SUM(reviews_count) OVER (
    PARTITION BY listings_id
    ORDER BY review_month
    ) AS reviews_cumulative,
    LAG(review_month) OVER (PARTITION BY listings_id ORDER BY review_month ) AS prev_review_month
FROM monthly