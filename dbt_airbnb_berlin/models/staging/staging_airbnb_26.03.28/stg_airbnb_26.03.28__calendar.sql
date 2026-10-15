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
   '26.03.28' AS data_cohort
FROM {{source('data_26_03_28', 'calendar')}}