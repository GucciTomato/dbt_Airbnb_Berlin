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
FROM {{source('data_25_12_27', 'calendar')}}