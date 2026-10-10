{{ 
    config(
        materialized= "view"
    )
}}

SELECT
    listing_id,
    id as reviews_id,
    {{ dbt_utils.generate_surrogate_key (['id', 'date']) }} as surrogate_key,
    CAST("date" AS DATE) AS "date",
    reviewer_id,
    comments
FROM {{source('data_25_09_23', 'reviews')}}