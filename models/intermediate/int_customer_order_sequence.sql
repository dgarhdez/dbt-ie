with orders as (
    select
        order_id,
        customer_id,
        order_date,
        status
    from {{ ref('stg_orders') }}
),

sequenced as (
    select
        order_id,
        customer_id,
        order_date,
        status,
        row_number() over (
            partition by customer_id
            order by order_date, order_id
        ) as customer_order_number,
        lag(order_date) over (
            partition by customer_id
            order by order_date, order_id
        ) as previous_order_date
    from orders
),

final as (
    select
        order_id,
        customer_id,
        order_date,
        status,
        customer_order_number,
        case when customer_order_number = 1 then true else false end as is_first_order,
        previous_order_date,
        datediff(
            'day',
            cast(previous_order_date as date),
            cast(order_date as date)
        ) as days_since_previous_order
    from sequenced
)

select
    order_id,
    customer_id,
    order_date,
    status,
    customer_order_number,
    is_first_order,
    previous_order_date,
    days_since_previous_order
from final
