{{
    config(
        materialized = "table"
    )
}}

SELECT
    listings_id,
    listings_name,
    host_id,
    neighbourhood_group_cleansed,
    neighbourhood_cleansed,
    property_type,
    room_type,
    accommodates,
    number_of_bathrooms AS bathrooms,
    COALESCE(has_shared_bathroom, false) AS has_shared_bathroom,
    bedrooms,
    beds,
    amenities,
    CARDINALITY(amenities) AS amenities_count,
    license,
    license IS NOT NULL AS has_license,
    first_seen,
    last_seen,
    is_active_in_latest,
    TO_DATE(data_cohort, 'YY.MM.DD') AS latest_cohort_date,
    {{ dbt_utils.generate_surrogate_key([
    'neighbourhood_group_cleansed',
    'neighbourhood_cleansed'
]) }} AS neighbourhood_key
FROM {{ ref('int_airbnb_current__listings') }}