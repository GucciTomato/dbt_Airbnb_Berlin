{{ 
    config(
        materialized= "view"
    )
}}

SELECT
    listing_id,
    "date",
    available,
    minimum_nights,
    maximum_nights,
   '25.12.27' AS data_cohort
FROM {{source('data_25_12_27', 'calendar')}}