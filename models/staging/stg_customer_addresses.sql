select
    *
from {{ source("raw", "customer_addresses") }}


"""
select column_name, data_type
from information_schema.columns
where table_name = 'customer_addresses'
order by ordinal_position
"""