{{ 
    config(
        materialized= "view"
    )
}}

SELECT
    listing_id,
    id,
    "date",
    reviewer_id
    reviewer_name,
    comments
FROM {{source('data_25_09_23', 'reviews')}}