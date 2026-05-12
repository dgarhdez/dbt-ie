select
    address_id,
    customer_id,
    address_type,
    street_address,
    city,
    state,
    postal_code,
    country,
    is_default
from {{ source('raw', 'customer_addresses') }}
