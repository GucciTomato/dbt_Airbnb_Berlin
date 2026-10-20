{{ 
    config(
        materialized= "view"
    )
}}

  SELECT DISTINCT ON (reviews_id)
      listing_id,
      reviews_id,
      "date",
      reviewer_id,
      comments,
      TO_DATE(data_cohort, 'YY.MM.DD') AS review_first_seen_cohort
  FROM {{ ref('stg_airbnb__reviews') }}
  ORDER BY reviews_id, TO_DATE(data_cohort, 'YY.MM.DD')