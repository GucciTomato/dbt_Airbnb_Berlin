{{
 config(
 materialized = "table"
 )
}}

WITH latest_host_row AS (
 -- Hostattribute aus dem zuletzt gesehenen Listing des Hosts
 SELECT DISTINCT ON (host_id)
 host_id,
 host_since,
 host_location,
 host_response_time,
 host_response_rate,
 host_acceptance_rate,
 host_is_superhost,
 host_neighbourhood,
 host_listings_count,
 host_total_listings_count,
 host_verifications,
 host_has_profile_pic,
 host_identity_verified
 FROM {{ ref('int_airbnb_cleaned__listings') }}
 WHERE host_id IS NOT NULL
 ORDER BY host_id, cohort_date DESC, listings_id
),

host_aggregates AS (
 SELECT
 host_id,
 MIN(first_seen) AS first_seen,
 MAX(last_seen) AS last_seen,
 COUNT(DISTINCT listings_id) AS listings_in_dataset,
 COUNT(DISTINCT listings_id) FILTER (WHERE is_active_in_latest) AS active_listings
 FROM {{ ref('int_airbnb_cleaned__listings') }}
 WHERE host_id IS NOT NULL
 GROUP BY host_id
)

SELECT
 h.host_id,
 h.host_since,
 h.host_location,
 h.host_neighbourhood,
 h.host_response_time,
 h.host_response_rate,
 h.host_acceptance_rate,
 h.host_is_superhost,
 h.host_has_profile_pic,
 h.host_identity_verified,
 h.host_verifications,
 h.host_listings_count,
 h.host_total_listings_count,
 a.listings_in_dataset,
 a.active_listings,
 a.active_listings > 0 AS is_active_host,
 a.active_listings > 1 AS is_multi_listing_host,
 a.first_seen,
 a.last_seen
FROM latest_host_row h
INNER JOIN host_aggregates a ON h.host_id = a.host_id