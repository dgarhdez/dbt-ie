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

customer_segments as (
    select
        segment_id,
        customer_segment
    from {{ ref('segments') }}
),

merged as (
    select
        customers.customer_id,
        customers.first_name,
        customers.last_name,
        customers.email,
        customers.country,
        customers.customer_segment,
        customer_segments.segment_id
    from customers
    left join customer_segments using (customer_segment)
)

select * from merged