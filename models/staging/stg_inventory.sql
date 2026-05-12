select
    product_id,
    warehouse,
    current_stock,
    reorder_point,
    max_stock,
    last_updated,
    supplier_id
from {{ source('raw', 'inventory') }}
