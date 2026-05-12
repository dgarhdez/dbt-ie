select
    session_id,
    customer_id,
    session_date,
    device_type,
    browser,
    source,
    landing_page,
    page_views,
    session_duration_seconds,
    is_bounce,
    converted,
    ip_address
from {{ source('raw', 'website_sessions') }}
