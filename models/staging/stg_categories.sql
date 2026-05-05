select
    category_id,
    category_name,
    parent_category_id,
    description,
    is_active
from {{ source("raw", "categories") }}


"""
select column_name, data_type
from information_schema.columns
where table_name = 'categories'
order by ordinal_position
"""