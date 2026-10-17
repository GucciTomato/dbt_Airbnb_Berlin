{% macro calculate_rate(column_name) %}

    CASE 
        WHEN column_name = 'N/A' THEN NULL 
        ELSE (CAST(REPLACE(column_name, '%', '') AS INT) * 0.01) 
    END

{% endmacro %}