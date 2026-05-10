select
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price,
    discount_amount,
    total_price
from {{ ref("stg_order_items") }}
