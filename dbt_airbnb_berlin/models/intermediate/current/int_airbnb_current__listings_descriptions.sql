{{ 
    config(
        materialized= "view"
    )
}}

SELECT
    hist.listings_id,
    surrogate_key,
    hist."description",
    hist.neighborhood_overview,
    REGEXP_REPLACE(
        hist.host_about, '^[^a-zA-Z0-9]+|[^a-zA-Z0-9]+$', '', 'g'
    ) AS host_about_cleaned
FROM {{ ref('stg_airbnb__listings') }} hist