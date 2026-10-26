{% macro clean_price(column_name) %}

    NULLIF(
        REPLACE(REPLACE({{ column_name }}, '$', ''), ',', '' ),''
    )::numeric(10,2)

{% endmacro %}