{{
 config(
 materialized = "table"
 )
}}

SELECT
    {{ dbt_utils.generate_surrogate_key([
        's.cohort_date', 'l.neighbourhood_group_cleansed', 's.room_type'
    ]) }} AS market_key,
    s.cohort_date,
    s.cohort_index,
    l.neighbourhood_group_cleansed,
    s.room_type,
    COUNT(*) AS listings_count,
    COUNT(DISTINCT s.host_id) AS hosts_count,
    COUNT(*) FILTER (WHERE s.is_first_cohort) AS new_listings,
    COUNT(*) FILTER (WHERE s.is_reappearance) AS reappeared_listings,
    -- listing seen for the last time in this cohort and not active in the latest one
    COUNT(*) FILTER (WHERE s.cohort_date = l.last_seen AND NOT l.is_active_in_latest) AS exited_listings,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY s.price) AS median_price,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY s.price) AS p25_price,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY s.price) AS p75_price,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY s.price_per_person) AS median_price_per_person,
    AVG(s.availability_365)::numeric(10,1) AS avg_availability_365,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY s.minimum_nights) AS median_minimum_nights,
    AVG((s.stay_type = 'short_term')::int)::numeric(10,3) AS share_short_term,
    (SUM(s.review_scores_rating * s.number_of_reviews) / NULLIF(SUM(s.number_of_reviews) FILTER (WHERE s.review_scores_rating IS NOT NULL), 0))::numeric(10,3) AS weighted_avg_rating,
    SUM(s.new_reviews) AS new_reviews,
    AVG(COALESCE(s.has_license, FALSE)::int)::numeric(10,3) AS share_with_license,
    --PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY s.estimated_occupancy_l365d) AS median_estimated_occupancy,
    --PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY s.estimated_revenue_l365d) AS median_estimated_revenue
    AVG(s.host_is_superhost::int)::numeric(10,3) AS share_superhost
FROM {{ ref('fct_airbnb_listing_snapshots') }} s
INNER JOIN {{ ref('dim_airbnb_listings') }} l ON s.listings_id = l.listings_id
GROUP BY s.cohort_date, s.cohort_index, l.neighbourhood_group_cleansed, s.room_type