select
    return_id,
    order_id,
    order_item_id,
    product_id,
    customer_id,
    return_date,
    return_reason,
    return_quantity,
    refund_amount,
    return_status,
    processing_fee
from {{ source('raw', 'returns') }}
