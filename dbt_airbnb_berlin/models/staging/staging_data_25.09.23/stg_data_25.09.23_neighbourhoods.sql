{{ 
    config(
        materialized= "view"
    )
}}

SELECT *
FROM {{source('data_25_09_23', 'neighbourhoods')}} 
LIMIT 10;