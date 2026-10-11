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
    comments,
   '25.12.27' AS data_cohort
FROM {{source('data_25_12_27', 'reviews')}}