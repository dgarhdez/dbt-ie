select
    order_id,
    customer_id,
    order_date,
    status,
    subtotal,
    tax_amount,
    shipping_cost,
    discount_amount,
    total_amount,
    currency,
    payment_method,
    shipping_address_id,
    billing_address_id,
    coupon_code
from {{ source('raw', 'orders') }}
