{{ 
    config(
        materialized = "view"
    )
}}

WITH first_last_seen AS (
    SELECT
        listings_id,
        MIN(TO_DATE(data_cohort, 'YY.MM.DD')) AS first_seen,
        MAX(TO_DATE(data_cohort, 'YY.MM.DD')) AS last_seen
    FROM {{ ref('int_airbnb_history__listings') }}
    GROUP BY listings_id
),
host_since_by_host AS (
 SELECT
 host_id,
 MIN(host_since) AS host_since -- exists only in 25.09.23 data
 FROM {{ ref('int_airbnb_history__listings') }}
 WHERE host_since IS NOT NULL
 GROUP BY host_id
)

SELECT
    hist.listings_id,
    hist.surrogate_key,
    hist.last_scraped,
    hist.listings_name,
    hist.host_id,
    hist.host_name,
    hostsince.host_since,
    hist.host_location,
    hist.host_response_time,
    hist.host_response_rate,
    hist.host_acceptance_rate,
    CASE WHEN hist.host_is_superhost = 't' THEN true WHEN hist.host_is_superhost = 'f' THEN false END AS host_is_superhost,
    hist.host_neighbourhood,
    hist.host_listings_count,
    hist.host_total_listings_count,
    hist.host_verifications,
    CASE WHEN hist.host_has_profile_pic = 't' THEN true WHEN hist.host_has_profile_pic = 'f' THEN false END AS host_has_profile_pic,
    CASE WHEN hist.host_identity_verified = 't' THEN true WHEN hist.host_identity_verified = 'f' THEN false END AS host_identity_verified,
    hist.neighbourhood_cleansed,
    hist.neighbourhood_group_cleansed,
    hist.property_type,
    hist.room_type,
    hist.accommodates,
    NULLIF(REGEXP_REPLACE(hist.bathrooms_text, '[^0-9\.]', '', 'g'), '')::numeric AS number_of_bathrooms,
    CASE WHEN hist.bathrooms_text IS NOT NULL THEN hist.bathrooms_text ILIKE '%shared%' END AS has_shared_bathroom,
    hist.bedrooms,
    hist.beds,
    ARRAY(SELECT json_array_elements_text(hist.amenities)) AS amenities,
    COALESCE(hist.price, hist.price_quote_price_per_night)::numeric(10,2) AS price,
    CASE 
        WHEN hist.price IS NOT NULL THEN 'listing_price'
        WHEN hist.price_quote_price_per_night IS NOT NULL THEN 'price_quote'
    END AS price_source,
    hist.minimum_nights,
    hist.maximum_nights,
    CASE
        WHEN hist.minimum_nights IS NULL THEN NULL
        WHEN hist.minimum_nights < 7  THEN 'short_term'
        WHEN hist.minimum_nights < 30 THEN 'weekly'
        WHEN hist.minimum_nights < 90 THEN 'monthly'
        ELSE 'long_term'
    END AS stay_type,
    hist.minimum_minimum_nights,
    hist.maximum_minimum_nights,
    hist.minimum_maximum_nights,
    hist.maximum_maximum_nights,
    CASE WHEN hist.has_availability = 't' THEN true WHEN hist.has_availability = 'f' THEN false END AS has_availability,
    hist.availability_30,
    hist.availability_365,
    hist.calendar_last_scraped,
    hist.number_of_reviews,
    hist.number_of_reviews_l30d,
    hist.availability_eoy,
    hist.estimated_occupancy_l365d::NUMERIC,
    hist.estimated_revenue_l365d,
    hist.first_review,
    hist.last_review,
    hist.review_scores_rating,
    hist.review_scores_accuracy,
    hist.review_scores_cleanliness,
    hist.review_scores_checkin,
    hist.review_scores_communication,
    hist.review_scores_location,
    hist.review_scores_value,
    CASE WHEN hist.license ~ '^(?![0-9]{2})' THEN NULL ELSE hist.license END AS license,
    CASE WHEN hist.instant_bookable = 't' THEN true WHEN hist.instant_bookable = 'f' THEN false END AS instant_bookable,
    hist.reviews_per_month,
    hist.hosts_time_as_host_months,
    hist.hosts_time_as_host_years,
    hist.hosts_time_as_user_months,
    hist.hosts_time_as_user_years,
    hist.price_quote_checkout_date - hist.price_quote_checkin_date AS quote_nights,
    fl.first_seen,
    fl.last_seen,
    fl.last_seen = MAX(fl.last_seen) OVER () AS is_active_in_latest,
    hist.data_cohort,
    TO_DATE(hist.data_cohort, 'YY.MM.DD') AS cohort_date,
    ROW_NUMBER() OVER (
        PARTITION BY hist.listings_id
        ORDER BY TO_DATE(hist.data_cohort, 'YY.MM.DD') DESC
    ) AS rn
FROM {{ ref('int_airbnb_history__listings') }} hist
LEFT JOIN first_last_seen fl ON hist.listings_id = fl.listings_id
LEFT JOIN host_since_by_host hostsince ON hist.host_id = hostsince.host_id