{{
    config(
        materialized = "table"
    )
}}

SELECT
    {{ dbt_utils.generate_surrogate_key([
        'neighbourhood_group_cleansed', 'neighbourhood_cleansed'
    ]) }} AS neighbourhood_key,
    neighbourhood_group_cleansed,
    neighbourhood_cleansed,
    COUNT(*) AS listings_in_dataset,
    COUNT(*) FILTER (WHERE is_active_in_latest) AS active_listings
FROM {{ ref('dim_airbnb_listings') }}
WHERE neighbourhood_cleansed IS NOT NULL
GROUP BY neighbourhood_group_cleansed, neighbourhood_cleansed