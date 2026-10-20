{{
 config(
 materialized = "table"
 )
}}

WITH feature_cohort AS (
    SELECT 
        DISTINCT ON (sp.listings_id, sp.target_month)
        sp.month_key,
        sp.listings_id,
        sp.target_month,
        s.snapshot_key AS feature_snapshot_key,
        s.cohort_date AS feature_cohort_date
    FROM {{ ref('int_airbnb__monthly_features') }} sp
    INNER JOIN {{ ref('fct_airbnb_listing_snapshots') }} s
    ON s.listings_id = sp.listings_id
    AND s.cohort_date < sp.target_month
    ORDER BY sp.listings_id, sp.target_month, s.cohort_date DESC
),
assembled AS (
    SELECT 
        f.month_key,
        f.listings_id,
        f.target_month,
        f.feature_cohort_date,
        f.target_month - f.feature_cohort_date AS feature_lag_days,
        COALESCE(rm.reviews_count, 0) AS new_reviews,  -- target
        s.room_type,
        s.property_type,
        s.accommodates,
        l.bathrooms,
        l.bedrooms,
        l.beds,
        l.neighbourhood_group_cleansed,
        l.neighbourhood_cleansed,
        s.price,  
        s.price_per_person,
        s.price_source,
        s.minimum_nights,
        s.stay_type,
        s.instant_bookable,
        s.has_license,
        s.availability_30,
        s.availability_365,
        s.has_availability,
        s.number_of_reviews AS reviews_before,
        s.review_scores_rating AS rating_before,
        s.review_scores_cleanliness AS cleanliness_before,
        s.review_scores_location AS location_before,
        s.host_is_superhost,
        s.host_response_time,
        s.host_acceptance_rate,
        s.host_listings_count,
        EXTRACT(MONTH FROM f.target_month)::int AS month_of_year
    FROM feature_cohort f
    INNER JOIN {{ ref('fct_airbnb_listing_snapshots') }} s
    ON s.snapshot_key = f.feature_snapshot_key
    INNER JOIN {{ ref('dim_airbnb_listings') }} l
    ON l.listings_id = f.listings_id
    LEFT JOIN {{ ref('fct_airbnb_reviews_monthly') }} rm
    ON rm.listings_id = f.listings_id
    AND rm.review_month = f.target_month
)

SELECT 
    a.*,
    LAG(a.new_reviews, 1) OVER w AS new_reviews_lag_1,
    LAG(a.new_reviews, 2) OVER w AS new_reviews_lag_2,
    LAG(a.new_reviews, 3) OVER w AS new_reviews_lag_3,
    LAG(a.new_reviews, 12) OVER w AS new_reviews_lag_12,
    AVG(a.new_reviews) OVER (
        PARTITION BY a.listings_id ORDER BY a.target_month ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING
    ) AS new_reviews_avg_prev_3
FROM assembled a
WINDOW w AS (PARTITION BY a.listings_id ORDER BY a.target_month)