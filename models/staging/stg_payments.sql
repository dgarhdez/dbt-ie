select
    payment_id,
    order_id,
    customer_id,
    payment_date,
    payment_method,
    amount,
    currency,
    status,
    transaction_id,
    card_last_four,
    payment_processor
from {{ source('raw', 'payments') }}
