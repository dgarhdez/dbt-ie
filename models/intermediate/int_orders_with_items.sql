with orders as (
    select
        order_id,
        customer_id,
        order_date,
        status,
        subtotal,
        tax_amount,
        shipping_cost,
        discount_amount,
        total_amount,
        currency,
        payment_method,
        shipping_address_id,
        billing_address_id,
        coupon_code
    from {{ ref('stg_orders') }}
),

order_items_summary as (
    select
        order_id,
        order_item_count,
        total_quantity,
        gross_item_revenue,
        total_item_discount_amount,
        net_item_revenue
    from {{ ref('int_order_items_summary') }}
),

merged as (
    select
        orders.order_id,
        orders.customer_id,
        orders.order_date,
        orders.status,
        orders.subtotal,
        orders.tax_amount,
        orders.shipping_cost,
        orders.discount_amount,
        orders.total_amount,
        orders.currency,
        orders.payment_method,
        orders.shipping_address_id,
        orders.billing_address_id,
        orders.coupon_code,
        case
            when order_items_summary.order_id is not null then true
            else false
        end as has_order_items,
        order_items_summary.order_item_count,
        order_items_summary.total_quantity,
        order_items_summary.gross_item_revenue,
        order_items_summary.total_item_discount_amount,
        order_items_summary.net_item_revenue
    from orders
    left join order_items_summary using (order_id)
)

select
    order_id,
    customer_id,
    order_date,
    status,
    subtotal,
    tax_amount,
    shipping_cost,
    discount_amount,
    total_amount,
    currency,
    payment_method,
    shipping_address_id,
    billing_address_id,
    coupon_code,
    has_order_items,
    order_item_count,
    total_quantity,
    gross_item_revenue,
    total_item_discount_amount,
    net_item_revenue
from merged
