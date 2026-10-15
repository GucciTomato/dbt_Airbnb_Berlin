{{ 
    config(
        materialized = "view"
    )
}}

SELECT *
FROM {{ ref('int_airbnb_cleaned__listings') }}
WHERE rn = 1