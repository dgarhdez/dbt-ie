-- models/staging/stg_customers.sql
select
    customer_id,
    first_name,
    last_name,
    email,
    country,
    customer_segment
from {{ source('raw', 'customers') }}