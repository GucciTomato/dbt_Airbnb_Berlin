{{
 config(
 materialized = "table"
 )
}}

WITH amenity_flags AS (
 SELECT
 listings_id,
 cohort_date,
 CARDINALITY(amenities) AS amenities_count,
 amenities && ARRAY['Wifi'] AS has_wifi,
 amenities && ARRAY['Kitchen'] AS has_kitchen,
 amenities && ARRAY['Washer'] AS has_washer,
 amenities && ARRAY['Air conditioning'] AS has_air_conditioning,
 amenities && ARRAY['Free parking on premises'] AS has_free_parking,
 amenities && ARRAY['Elevator'] AS has_elevator,
 amenities && ARRAY['Pets allowed'] AS allows_pets
 FROM {{ ref('int_airbnb_cleaned__listings') }}
)

SELECT
 s.snapshot_key,
 s.listings_id,
 s.cohort_date,
 s.cohort_index,

 -- Ziel bzw. Hauptvariable
 s.price,
 s.price_per_person,
 s.price_source,
 s.price_change_pct,
 s.price_change_is_comparable,

 -- Objekt
 s.room_type,
 s.property_type,
 s.accommodates,
 l.bathrooms,
 l.has_shared_bathroom,
 l.bedrooms,
 l.beds,
 a.amenities_count,
 a.has_wifi,
 a.has_kitchen,
 a.has_washer,
 a.has_air_conditioning,
 a.has_free_parking,
 a.has_elevator,
 a.allows_pets,

 -- Lage
 l.neighbourhood_group_cleansed,
 l.neighbourhood_cleansed,
 l.neighbourhood_key,

 -- Buchungsbedingungen
 s.minimum_nights,
 s.maximum_nights,
 s.stay_type,
 s.instant_bookable,
 s.has_license,
 s.availability_30,
 s.availability_365,
 s.has_availability,

 -- Reviews
 s.number_of_reviews,
 s.reviews_per_month,
 s.review_scores_rating,
 s.review_scores_accuracy,
 s.review_scores_cleanliness,
 s.review_scores_checkin,
 s.review_scores_communication,
 s.review_scores_location,
 s.review_scores_value,
 (s.cohort_date - s.last_review) AS days_since_last_review,
 (s.cohort_date - s.first_review) AS days_since_first_review,

 -- Host
 s.host_is_superhost,
 s.host_response_time,
 s.host_response_rate,
 s.host_acceptance_rate,
 s.host_listings_count,
 h.listings_in_dataset AS host_listings_observed,
 h.is_multi_listing_host,
 CASE
 WHEN h.host_since IS NOT NULL
 THEN (s.cohort_date - h.host_since) / 365.25
 END AS host_tenure_years,

 -- Historie des Listings
 s.is_first_cohort,
 s.is_last_cohort,
 s.cohorts_since_previous,
 (s.cohort_date - l.first_seen) AS days_since_first_seen,

 -- Segmentierung fürs Training
 s.cohort_index = MAX(s.cohort_index) OVER () AS is_latest_cohort
FROM {{ ref('fct_airbnb_listing_snapshots') }} s
INNER JOIN {{ ref('dim_airbnb_listings') }} l ON s.listings_id = l.listings_id
LEFT JOIN {{ ref('dim_airbnb_hosts') }} h ON s.host_id = h.host_id
LEFT JOIN amenity_flags a
 ON s.listings_id = a.listings_id
 AND s.cohort_date = a.cohort_date