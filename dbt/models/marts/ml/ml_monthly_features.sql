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
        s.cohort_date AS feature_cohort_date,
        COALESCE(NULLIF(SUBSTRING(
            s.property_type FROM ' in (.*)$'), ''),
            REGEXP_REPLACE(s.property_type, '^(Entire|Private room|Shared room|Room)\s*', '')
        ) AS building_type
    FROM {{ ref('int_airbnb__monthly_features') }} sp
    INNER JOIN {{ ref('fct_airbnb_listing_snapshots') }} s ON s.listings_id = sp.listings_id AND s.cohort_date < sp.target_month
    ORDER BY sp.listings_id, sp.target_month, s.cohort_date DESC
),
building_type_counts AS (
    SELECT
        building_type,
        COUNT(DISTINCT listings_id) AS n
    FROM feature_cohort
    GROUP BY building_type
),
feature_cohort_mapped AS (
    SELECT
        f.*,
        CASE
            WHEN b.n < 100 THEN 'other'
            ELSE f.building_type
        END AS building_type_mapped
    FROM feature_cohort f
    LEFT JOIN building_type_counts b
        ON b.building_type = f.building_type
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
        f.building_type_mapped AS building_type,
        s.accommodates,
        l.number_of_bathrooms as bathrooms,
        l.bedrooms,
        l.beds,
        l.neighbourhood_group_cleansed,
        l.neighbourhood_cleansed,
        s.price,
        s.price IS NULL AS price_is_missing,
        s.price_per_person,
        s.price_source,
        s.minimum_nights,
        s.stay_type,
        --s.instant_bookable, --only in cohort 25.09.23, not avaible in later test data; kept in case of re-occurence
        s.has_license,
        s.availability_30,
        s.availability_365,
        s.has_availability,
        s.number_of_reviews AS reviews_before,
        s.review_scores_rating AS rating_before,
        s.review_scores_cleanliness AS cleanliness_before,
        s.review_scores_location AS location_before,
        s.host_is_superhost,
        --s.host_response_time, --only in cohort 25.09.23, not avaible in later test data; kept in case of re-occurence
        --s.host_acceptance_rate, --only in cohort 25.09.23, not avaible in later test data; kept in case of re-occurence
        s.host_listings_count,
        EXTRACT(MONTH FROM f.target_month)::int AS month_of_year,
        CARDINALITY(l.amenities) AS amenities_count,
        l.amenities && ARRAY['Wifi'] AS has_wifi,
        l.amenities && ARRAY['Kitchen'] AS has_kitchen,
        l.amenities && ARRAY['Washer'] AS has_washer,
        l.amenities && ARRAY['Air conditioning'] AS has_air_conditioning,
        l.amenities && ARRAY['Free parking on premises'] AS has_free_parking,
        l.amenities && ARRAY['Elevator'] AS has_elevator,
        l.amenities && ARRAY['Pets allowed'] AS allows_pets,
        l.amenities && ARRAY['TV'] AS has_tv,
        l.amenities && ARRAY['Self check-in'] AS has_self_check_in,
        l.amenities && ARRAY['Private patio or balcony'] AS has_patio_or_balcony,
        l.has_shared_bathroom,
        s.is_reappearance,
        s.cohorts_since_previous,
        --CASE WHEN h.host_since IS NOT NULL THEN (f.target_month - h.host_since) / 365.25 END AS host_tenure_years --only in cohort 25.09.23, not avaible in later test data; kept in case of re-occurence
        (f.target_month - l.first_seen) AS days_since_first_seen
    FROM feature_cohort_mapped f
    INNER JOIN {{ ref('fct_airbnb_listing_snapshots') }} s ON s.snapshot_key = f.feature_snapshot_key
    INNER JOIN {{ ref('int_airbnb_cleaned__listings') }} l ON l.listings_id = f.listings_id AND l.cohort_date = f.feature_cohort_date
    LEFT JOIN {{ ref('fct_airbnb_reviews_monthly') }} rm ON rm.listings_id = f.listings_id AND rm.review_month = f.target_month 
    --LEFT JOIN {{ ref('dim_airbnb_hosts') }} h ON h.host_id = s.host_id
)

SELECT 
    a.*,
    LAG(a.new_reviews, 1) OVER w AS new_reviews_lag_1,
    AVG(a.new_reviews) OVER (
        PARTITION BY a.listings_id ORDER BY a.target_month ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING
    ) AS new_reviews_avg_prev_3
FROM assembled a
LEFT JOIN building_type_counts b ON b.building_type = a.building_type
WINDOW w AS (PARTITION BY a.listings_id ORDER BY a.target_month)