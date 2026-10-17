{% macro convert_binary_to_bool(column_name) %}

CASE 
    WHEN column_name = 't' THEN true 
    WHEN column_name = 'f' THEN false 
END

{% endmacro %}

{{ convert_binary_to_bool() }}