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
    maximum_nights
FROM {{source('data_26_03_28', 'calendar')}}