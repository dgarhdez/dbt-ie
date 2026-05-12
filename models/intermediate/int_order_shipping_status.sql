with orders as (
    select
        order_id,
        order_date
    from {{ ref('stg_orders') }}
),

shipping as (
    select
        order_id,
        carrier,
        shipping_method,
        shipping_status,
        ship_date,
        estimated_delivery,
        actual_delivery
    from {{ ref('stg_shipping') }}
),

merged as (
    select
        orders.order_id,
        orders.order_date,
        shipping.carrier,
        shipping.shipping_method,
        shipping.shipping_status,
        shipping.ship_date,
        shipping.estimated_delivery,
        shipping.actual_delivery,
        datediff('day', cast(orders.order_date as date), cast(shipping.ship_date as date)) as days_to_ship,
        datediff('day', cast(shipping.estimated_delivery as date), cast(shipping.actual_delivery as date)) as days_late,
        case
            when shipping.actual_delivery > shipping.estimated_delivery then true
            else false
        end as is_late,
        case
            when shipping.ship_date is null then 'not_shipped'
            when shipping.actual_delivery < shipping.estimated_delivery then 'early'
            when shipping.actual_delivery = shipping.estimated_delivery then 'on_time'
            when shipping.actual_delivery > shipping.estimated_delivery then 'late'
            else 'unknown'
        end as shipping_performance_bucket
    from orders
    left join shipping using (order_id)
)

select
    order_id,
    order_date,
    carrier,
    shipping_method,
    shipping_status,
    ship_date,
    estimated_delivery,
    actual_delivery,
    days_to_ship,
    days_late,
    is_late,
    shipping_performance_bucket
from merged
