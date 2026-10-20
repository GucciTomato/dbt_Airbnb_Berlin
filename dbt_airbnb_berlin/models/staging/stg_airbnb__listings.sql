{{ 
    config(
        materialized= "view"
    )
}}

SELECT 
   id::BIGINT as listings_id,
   {{ dbt_utils.generate_surrogate_key (['id', 'last_scraped']) }} as surrogate_key,
   last_scraped::TIMESTAMP AS last_scraped,
   "name" as listings_name,
   "description",
   neighborhood_overview,
   host_id::BIGINT AS host_id,
   host_location,
   host_about,
   host_response_time,
   {{ calculate_rate('host_response_rate') }} AS host_response_rate,
   {{ calculate_rate('host_acceptance_rate') }} AS host_acceptance_rate,
   host_is_superhost::BOOLEAN AS host_is_superhost,
   host_neighbourhood,
   CAST(host_listings_count AS INT) AS host_listings_count,
   CAST(host_total_listings_count AS INT) AS host_total_listings_count,
   host_verifications,
   host_has_profile_pic::BOOLEAN AS host_has_profile_pic,
   host_identity_verified::BOOLEAN AS host_identity_verified,
   neighbourhood_cleansed,
   neighbourhood_group_cleansed,
   property_type,
   room_type,
   accommodates::INT AS accommodates,
   bathrooms::INT AS bathrooms,
   bathrooms_text,
   bedrooms::INT AS bedrooms,
   beds::INT AS beds,
   amenities::JSON as amenities,
   host_since,
   {{ clean_price('price') }} AS price,
   minimum_nights::INT AS minimum_nights,
   maximum_nights::INT AS maximum_nights,
   minimum_minimum_nights::INT AS minimum_minimum_nights,
   maximum_minimum_nights::INT AS maximum_minimum_nights,
   minimum_maximum_nights::INT AS minimum_maximum_nights,
   maximum_maximum_nights::INT AS maximum_maximum_nights,
   minimum_nights_avg_ntm::NUMERIC AS minimum_nights_avg_ntm,
   maximum_nights_avg_ntm::NUMERIC AS maximum_nights_avg_ntm,
   calendar_updated::DATE AS calendar_updated,
   has_availability::BOOLEAN AS has_availability,
   availability_30::INT AS availability_30,
   availability_60::INT AS availability_60,
   availability_90::INT AS availability_90,
   availability_365::INT AS availability_365,
   calendar_last_scraped::DATE AS calendar_last_scraped,
   number_of_reviews::INT AS number_of_reviews,
   number_of_reviews_ltm::INT AS number_of_reviews_ltm,
   number_of_reviews_l30d::INT AS number_of_reviews_l30d,
   availability_eoy::INT AS availability_eoy,
   number_of_reviews_ly::INT AS number_of_reviews_ly,
   estimated_occupancy_l365d,
   estimated_revenue_l365d,
   first_review::DATE AS first_review,
   last_review::DATE AS last_review,
   CAST(review_scores_rating AS FLOAT) AS review_scores_rating,
   CAST(review_scores_accuracy AS FLOAT) AS review_scores_accuracy,
   CAST(review_scores_cleanliness AS FLOAT) AS review_scores_cleanliness,
   CAST(review_scores_checkin AS FLOAT) AS review_scores_checkin,
   CAST(review_scores_communication AS FLOAT) AS review_scores_communication,
   CAST(review_scores_location AS FLOAT) AS review_scores_location,
   CAST(review_scores_value AS FLOAT) AS review_scores_value,
   license,
   instant_bookable::BOOLEAN AS instant_bookable,
   calculated_host_listings_count::INT AS calculated_host_listings_count,
   reviews_per_month::NUMERIC AS reviews_per_month,
   CAST(hosts_time_as_host_months AS INT) AS hosts_time_as_host_months, -- present in data from 25.12.27 onwards
   CAST(hosts_time_as_host_years AS INT) AS hosts_time_as_host_years, -- present in data from 25.12.27 onwards
   CAST(hosts_time_as_user_months AS INT) AS hosts_time_as_user_months, -- present in data from 25.12.27 onwards
   CAST(hosts_time_as_user_years AS INT) AS hosts_time_as_user_years, -- present in data from 25.12.27 onwards
   TO_DATE(price_quote_checkin_date, 'YYYY-MM-DD') AS price_quote_checkin_date, -- present in data from 26.03.28 onwards
   TO_DATE(price_quote_checkout_date, 'YYYY-MM-DD') AS price_quote_checkout_date, -- present in data from 26.03.28 onwards
   CAST(price_quote_price_per_night AS FLOAT) AS price_quote_price_per_night, -- present in data from 26.03.28 onwards
   CAST(price_quote_raw AS FLOAT) AS price_quote_raw, -- present in data from 26.03.28 onwards
   '26.06.26' AS data_cohort
FROM {{source('airbnb_raw_data', 'listings')}}