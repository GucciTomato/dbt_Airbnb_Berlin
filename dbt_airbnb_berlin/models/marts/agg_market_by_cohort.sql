{{
 config(
 materialized = "table"
 )
}}

WITH base AS (
 SELECT
 s.cohort_date,
 s.cohort_index,
 l.neighbourhood_group_cleansed,
 l.neighbourhood_key,
 s.room_type,
 s.listings_id,
 s.price,
 s.price_source,
 s.price_per_person,
 s.availability_365,
 s.availability_30,
 s.minimum_nights,
 s.stay_type,
 s.review_scores_rating,
 s.number_of_reviews,
 s.new_reviews,
 s.has_license,
 s.instant_bookable,
 s.host_id,
 s.host_is_superhost,
 s.is_first_cohort,
 s.is_reappearance,
 s.estimated_occupancy_l365d,
 s.estimated_revenue_l365d
 FROM {{ ref('fct_airbnb_listing_snapshots') }} s
 INNER JOIN {{ ref('dim_airbnb_listings') }} l ON s.listings_id = l.listings_id
),

exits AS (
 -- Listings, die in dieser Kohorte zum letzten Mal zu sehen waren
 SELECT
 s.cohort_date,
 l.neighbourhood_group_cleansed,
 s.room_type,
 COUNT(*) AS exited_listings
 FROM {{ ref('fct_airbnb_listing_snapshots') }} s
 INNER JOIN {{ ref('dim_airbnb_listings') }} l ON s.listings_id = l.listings_id
 WHERE s.cohort_date = l.last_seen
 AND NOT l.is_active_in_latest
 GROUP BY s.cohort_date, l.neighbourhood_group_cleansed, s.room_type
)

SELECT
 {{ dbt_utils.generate_surrogate_key([
 'b.cohort_date',
 'b.neighbourhood_group_cleansed',
 'b.room_type'
 ]) }} AS market_key,
 b.cohort_date,
 b.cohort_index,
 b.neighbourhood_group_cleansed,
 b.room_type,

 -- Bestand
 COUNT(*) AS listings_count,
 COUNT(DISTINCT b.host_id) AS hosts_count,
 COUNT(*) FILTER (WHERE b.is_first_cohort) AS new_listings,
 COUNT(*) FILTER (WHERE b.is_reappearance) AS reappeared_listings,
 COALESCE(e.exited_listings, 0) AS exited_listings,

 -- Preis (Median, da stark rechtsschief)
 PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY b.price) AS median_price,
 PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY b.price) AS p25_price,
 PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY b.price) AS p75_price,
 PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY b.price_per_person) AS median_price_per_person,
 COUNT(b.price) AS listings_with_price,
 COUNT(*) FILTER (WHERE b.price_source = 'listing_price') AS price_from_listing,
 COUNT(*) FILTER (WHERE b.price_source = 'price_quote') AS price_from_quote,

 -- Verfügbarkeit und Aufenthaltsdauer
 AVG(b.availability_365)::numeric(10,1) AS avg_availability_365,
 AVG(b.availability_30)::numeric(10,1) AS avg_availability_30,
 PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY b.minimum_nights) AS median_minimum_nights,
 COUNT(*) FILTER (WHERE b.stay_type = 'short_term')::numeric
 / NULLIF(COUNT(b.stay_type), 0) AS share_short_term,

 -- Bewertungen, gewichtet nach Reviewanzahl
 SUM(b.review_scores_rating * b.number_of_reviews)
 / NULLIF(SUM(b.number_of_reviews) FILTER (WHERE b.review_scores_rating IS NOT NULL), 0) AS weighted_avg_rating,
 AVG(b.review_scores_rating)::numeric(10,3) AS unweighted_avg_rating,
 SUM(b.new_reviews) AS new_reviews,

 -- Anteile
 COUNT(*) FILTER (WHERE b.has_license)::numeric / COUNT(*) AS share_with_license,
 COUNT(*) FILTER (WHERE b.instant_bookable)::numeric
 / NULLIF(COUNT(b.instant_bookable), 0) AS share_instant_bookable,
 COUNT(*) FILTER (WHERE b.host_is_superhost)::numeric
 / NULLIF(COUNT(b.host_is_superhost), 0) AS share_superhost,

 PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY NULLIF(b.estimated_occupancy_l365d, '')::numeric) AS median_estimated_occupancy,
 PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY NULLIF(b.estimated_revenue_l365d, '')::numeric) AS median_estimated_revenue
FROM base b
LEFT JOIN exits e
ON b.cohort_date = e.cohort_date
AND b.neighbourhood_group_cleansed = e.neighbourhood_group_cleansed
AND b.room_type = e.room_type
GROUP BY
 b.cohort_date,
 b.cohort_index,
 b.neighbourhood_group_cleansed,
 b.room_type,
 e.exited_listings