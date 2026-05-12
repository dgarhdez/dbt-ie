select
    category_id,
    category_name,
    parent_category_id,
    description,
    is_active
from {{ source('raw', 'categories') }}
