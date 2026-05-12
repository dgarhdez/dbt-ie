select
    supplier_id,
    supplier_name,
    contact_email,
    contact_phone,
    country,
    city,
    rating,
    lead_time_days,
    is_active,
    contract_start_date
from {{ source('raw', 'suppliers') }}
