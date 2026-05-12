with order_items as (
    select
        order_item_id,
        order_id,
        quantity,
        unit_price,
        discount_amount,
        total_price
    from {{ ref('stg_order_items') }}
),

summary as (
    select
        order_id,
        count(order_item_id) as order_item_count,
        sum(quantity) as total_quantity,
        sum(unit_price * quantity) as gross_item_revenue,
        sum(discount_amount) as total_item_discount_amount,
        sum(total_price) as net_item_revenue
    from order_items
    group by order_id
)

select
    order_id,
    order_item_count,
    total_quantity,
    gross_item_revenue,
    total_item_discount_amount,
    net_item_revenue
from summary
