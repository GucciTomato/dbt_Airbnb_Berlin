{{ 
    config(
        materialized= "view"
    )
}}

SELECT *
FROM {{source('data_25_09_23', 'listings')}} 
LIMIT 10;