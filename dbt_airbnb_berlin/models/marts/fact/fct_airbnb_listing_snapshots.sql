{{
    config(
        materialized = "table"
    )
}}

WITH cohorts AS (
    SELECT
        cohort_date,
        DENSE_RANK() OVER (ORDER BY cohort_date) AS cohort_index
    FROM (
        SELECT DISTINCT cohort_date
        FROM {{ ref('int_airbnb_cleaned__listings') }}
    ) c
),
snapshots AS (
    SELECT
        cl.listings_id,
        cl.cohort_date,
        cl.data_cohort,
        co.cohort_index,
        cl.last_scraped,
        cl.calendar_last_scraped,
        cl.price,
        cl.price_source,
        cl.quote_nights,
        cl.minimum_nights,
        cl.maximum_nights,
        cl.stay_type,
        cl.minimum_minimum_nights,
        cl.maximum_minimum_nights,
        cl.minimum_maximum_nights,
        cl.maximum_maximum_nights,
        cl.has_availability,
        cl.availability_30,
        cl.availability_365,
        cl.availability_eoy,
        cl.number_of_reviews,
        cl.number_of_reviews_l30d,
        cl.reviews_per_month,
        cl.first_review,
        cl.last_review,
        cl.review_scores_rating,
        cl.review_scores_accuracy,
        cl.review_scores_cleanliness,
        cl.review_scores_checkin,
        cl.review_scores_communication,
        cl.review_scores_location,
        cl.review_scores_value,
        cl.estimated_occupancy_l365d,
        cl.estimated_revenue_l365d,
        cl.instant_bookable,
        cl.license,
        cl.room_type,
        cl.property_type,
        cl.accommodates,
        cl.host_id,
        cl.host_is_superhost,
        cl.host_response_time,
        cl.host_response_rate,
        cl.host_acceptance_rate,
        cl.host_listings_count,
        cl.host_total_listings_count,
        cl.first_seen,
        cl.last_seen,
        cl.rn
    FROM {{ ref('int_airbnb_cleaned__listings') }} cl
    INNER JOIN cohorts co ON cl.cohort_date = co.cohort_date
),

with_lags AS (
    SELECT
        s.*,
        LAG(cohort_index) OVER w AS prev_cohort_index,
        LAG(cohort_date)OVER w AS prev_cohort_date,
        LAG(price) OVER w AS prev_price,
        LAG(price_source) OVER w AS prev_price_source,
        LAG(number_of_reviews) OVER w AS prev_number_of_reviews,
        LAG(room_type) OVER w AS prev_room_type,
        LAG(minimum_nights) OVER w AS prev_minimum_nights,
        LAG(availability_365) OVER w AS prev_availability_365,
        LAG(host_is_superhost) OVER w AS prev_host_is_superhost,
        LAG(host_id) OVER w AS prev_host_id,
        LAG(license) OVER w AS prev_license,
        LAG(review_scores_rating) OVER w AS prev_review_scores_rating
    FROM snapshots s
    WINDOW w AS (PARTITION BY s.listings_id ORDER BY s.cohort_index)
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['listings_id', 'cohort_date']) }} AS snapshot_key,
    listings_id,
    host_id,
    cohort_date,
    data_cohort,
    cohort_index,

    -- Zustand in dieser Kohorte
    last_scraped,
    calendar_last_scraped,
    price,
    price_source,
    quote_nights,
    CASE WHEN accommodates > 0 THEN price::numeric / accommodates END AS price_per_person,
    minimum_nights,
    maximum_nights,
    stay_type,
    minimum_minimum_nights,
    maximum_minimum_nights,
    minimum_maximum_nights,
    maximum_maximum_nights,
    has_availability,
    availability_30,
    availability_365,
    availability_eoy,
    number_of_reviews,
    number_of_reviews_l30d,
    reviews_per_month,
    first_review,
    last_review,
    review_scores_rating,
    review_scores_accuracy,
    review_scores_cleanliness,
    review_scores_checkin,
    review_scores_communication,
    review_scores_location,
    review_scores_value,
    estimated_occupancy_l365d,
    estimated_revenue_l365d,
    instant_bookable,
    license,
    license IS NOT NULL AS has_license,
    room_type,
    property_type,
    accommodates,
    host_is_superhost,
    host_response_time,
    host_response_rate,
    host_acceptance_rate,
    host_listings_count,
    host_total_listings_count,

    -- Position in der Historie
    cohort_date = first_seen AS is_first_cohort,
    rn = 1 AS is_last_cohort,
    prev_cohort_date,
    cohort_index - prev_cohort_index AS cohorts_since_previous,
    prev_cohort_index IS NOT NULL AND cohort_index - prev_cohort_index > 1 AS is_reappearance,

    -- Veränderungen zur Vorkohorte
    price - prev_price AS price_change_abs,
    (price - prev_price) / NULLIF(prev_price, 0)::numeric AS price_change_pct,
    price_source IS NOT DISTINCT FROM prev_price_source AS price_change_is_comparable,
    GREATEST(number_of_reviews - prev_number_of_reviews, 0) AS new_reviews,
    review_scores_rating - prev_review_scores_rating AS rating_change,
    availability_365 - prev_availability_365 AS availability_365_change,
    room_type IS DISTINCT FROM prev_room_type AS room_type_changed,
    minimum_nights IS DISTINCT FROM prev_minimum_nights AS minimum_nights_changed,
    host_is_superhost IS DISTINCT FROM prev_host_is_superhost AS superhost_changed,
    host_id IS DISTINCT FROM prev_host_id AS host_changed,
    prev_license IS NULL AND license IS NOT NULL AS license_gained,
    prev_license IS NOT NULL AND license IS NULL AS license_lost
FROM with_lags