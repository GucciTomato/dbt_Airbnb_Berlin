{{ 
    config(
        materialized= "view"
    )
}}

SELECT
    source_customer_id,
    customer_number,
    first_name,
    last_name,
    lower(trim(email)) as email,
    phone,
    UPPER(country_code) as country_code,
    marketing_opt_in,
    LOWER(customer_status) as customer_status,
    created_at,
    source_updated_at,
    _loaded_at
FROM {{source('crm', 'customers')}} 
WHERE customer_number IS NOT NULL