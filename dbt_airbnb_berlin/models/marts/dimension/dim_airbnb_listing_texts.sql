{{
 config(
 materialized = "table"
 )
}}

WITH latest_texts AS (
 SELECT DISTINCT ON (hist.listings_id)
 hist.listings_id,
 hist."description",
 hist.neighborhood_overview,
 NULLIF(REGEXP_REPLACE(
 hist.host_about, '^[^a-zA-Z0-9]+|[^a-zA-Z0-9]+$', '', 'g'
 ), '') AS host_about,
 hist.host_id,
 TO_DATE(hist.data_cohort, 'YY.MM.DD') AS cohort_date
 FROM {{ ref('stg_airbnb__listings') }} hist
 ORDER BY hist.listings_id, TO_DATE(hist.data_cohort, 'YY.MM.DD') DESC
)

SELECT
 listings_id,
 host_id,
 cohort_date AS text_from_cohort,
 "description",
 neighborhood_overview,
 host_about,
 LENGTH("description") AS description_length,
 LENGTH(neighborhood_overview) AS neighborhood_overview_length,
 LENGTH(host_about) AS host_about_length,
 "description" IS NOT NULL AS has_description,
 neighborhood_overview IS NOT NULL AS has_neighborhood_overview,
 host_about IS NOT NULL AS has_host_about
FROM latest_texts