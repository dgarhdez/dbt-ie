select
    order_id,
    carrier,
    tracking_number,
    shipping_method,
    shipping_cost,
    ship_date,
    estimated_delivery,
    actual_delivery,
    shipping_status,
    weight_kg
from {{ source('raw', 'shipping') }}
