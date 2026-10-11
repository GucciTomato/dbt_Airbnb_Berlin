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
   '26.06.26' AS data_cohort
FROM {{source('data_26_06_26', 'calendar')}}