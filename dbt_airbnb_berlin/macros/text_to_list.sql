{% macro text_to_list(relation, column_name) %}

ALTER TABLE relation
ALTER COLUMN {{ column_name }} TYPE text[]
USING string_to_array(trim(BOTH '[]' FROM {{ column_name }}), ',')

{% endmacro %}