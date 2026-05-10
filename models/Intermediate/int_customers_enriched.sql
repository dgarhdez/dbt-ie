-- {{ config(materialized='view') }}
-- It tells dbt how to materialize (store) this model in the database as a View. no data is stored, it just saves the SQL query and runs it fresh every time you query it.

with customers as (
    select
            customer_id,
            first_name,
            last_name,
            email,
            country,
            customer_segment
    from {{ ref('stg_customers') }}
                  ),
segments as (
    select 
        segment_id,
        customer_segment
    from {{ref("segments")}}
            ),
final as (
    select
        customers.customer_id,
        customers.first_name,
        customers.last_name,
        customers.first_name || ' ' || customers.last_name as full_name,
        customers.email,
        split_part(customers.email, '@' , 2) as email_domain,
        customers.country,
        customers.customer_segment,
        segments.segment_id
    from customers
    left join segments using (customer_segment)
         )

select
    *
from final


--- Question 1: Does every customer have a valid segment?

-- select
--     *
-- from final
-- where segment_id is NULL   --- to check if there are any null values


--- Question 2: What should happen if a customer segment is missing from the seed?

-- Usually we would flag those missing values and add the needed mapping manually. Another choice is to drop the rows, but we will lose the information and data will become inconsistent.


--- Question 3: Is this model still one row per customer after the join?

-- select 
--     count(*) as total_rows,
--     count(DISTINCT customer_id) as distinct_customer_id,
--     cast(total_rows as int) - cast(distinct_customer_id as int) as difference
-- from final