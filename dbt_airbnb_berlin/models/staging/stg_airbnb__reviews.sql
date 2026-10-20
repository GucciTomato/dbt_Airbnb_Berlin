{{ 
    config(
        materialized= "view"
    )
}}

SELECT
    listing_id::BIGINT AS listing_id,
    id::BIGINT as reviews_id,
    {{ dbt_utils.generate_surrogate_key (['id', 'date']) }} as surrogate_key,
    CAST("date" AS DATE) AS "date",
    reviewer_id::BIGINT AS reviewer_id,
    comments,
   '26.06.26' AS data_cohort
FROM {{source('airbnb_raw_data', 'reviews')}}