{{ 
    config(
        materialized= "view"
    )
}}

SELECT
    listing_id,
    "date",
    available,
    price,
    adjusted_price,
    minimum_nights,
    maximum_nights,
   '25.09.23' AS data_cohort
FROM {{source('data_25_09_23', 'calendar')}}