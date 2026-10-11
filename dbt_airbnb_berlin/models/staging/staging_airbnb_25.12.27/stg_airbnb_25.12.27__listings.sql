{{ 
    config(
        materialized= "view"
    )
}}

SELECT 
   id as listings_id,
   {{ dbt_utils.generate_surrogate_key (['id', 'last_scraped']) }} as surrogate_key,
   last_scraped,
   "name" as listings_name,
   "description",
   neighborhood_overview,
   host_id,
   host_name, -- secondary validation of host besides host_id for later when merging with other models
   host_since,
   host_location,
   host_about,
   host_response_time,
    CASE 
        WHEN host_response_rate = 'N/A' THEN NULL 
        ELSE (CAST(REPLACE(host_response_rate, '%', '') AS INT) * 0.01) 
    END AS host_response_rate,
    CASE 
        WHEN host_acceptance_rate = 'N/A' THEN NULL 
        ELSE (CAST(REPLACE(host_acceptance_rate, '%', '') AS INT) * 0.01) 
    END AS host_acceptance_rate,
   host_is_superhost,
   host_neighbourhood,
   CAST(host_listings_count AS INT) AS host_listings_count,
   CAST(host_total_listings_count AS INT) AS host_total_listings_count,
   host_verifications,
   host_has_profile_pic,
   host_identity_verified,
   neighbourhood_cleansed,
   neighbourhood_group_cleansed,
   property_type,
   room_type,
   accommodates,
   bathrooms,
   bathrooms_text,
   bedrooms,
   beds,
   amenities,
   CAST(ROUND(CAST(REPLACE(price, '$', '') AS FLOAT)) AS INT) AS price,
   minimum_nights,
   maximum_nights,
   minimum_minimum_nights,
   maximum_minimum_nights,
   minimum_maximum_nights,
   maximum_maximum_nights,
   minimum_nights_avg_ntm,
   maximum_nights_avg_ntm,
   calendar_updated,
   has_availability,
   availability_30,
   availability_60,
   availability_90,
   availability_365,
   calendar_last_scraped,
   number_of_reviews,
   number_of_reviews_ltm,
   number_of_reviews_l30d,
   availability_eoy,
   number_of_reviews_ly,
   estimated_occupancy_l365d,
   estimated_revenue_l365d,
   first_review,
   last_review,
   CAST(review_scores_rating AS FLOAT) AS review_scores_rating,
   CAST(review_scores_accuracy AS FLOAT) AS review_scores_accuracy,
   CAST(review_scores_cleanliness AS FLOAT) AS review_scores_cleanliness,
   CAST(review_scores_checkin AS FLOAT) AS review_scores_checkin,
   CAST(review_scores_communication AS FLOAT) AS review_scores_communication,
   CAST(review_scores_location AS FLOAT) AS review_scores_location,
   CAST(review_scores_value AS FLOAT) AS review_scores_value,
   license, -- secondary validation of host besides host_id for later
   instant_bookable,
   calculated_host_listings_count,
   reviews_per_month,
   CAST(hosts_time_as_host_months AS INT) AS hosts_time_as_host_months, -- present in data from 25.12.27 onwards
   CAST(hosts_time_as_host_years AS INT) AS hosts_time_as_host_years, -- present in data from 25.12.27 onwards
   CAST(hosts_time_as_user_months AS INT) AS hosts_time_as_user_months, -- present in data from 25.12.27 onwards
   CAST(hosts_time_as_user_years AS INT) AS hosts_time_as_user_years, -- present in data from 25.12.27 onwards
   '25.12.27' AS data_cohort
FROM {{source('data_25_12_27', 'listings')}}