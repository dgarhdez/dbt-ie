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
from {{ ref("stg_customer_addresses") }}