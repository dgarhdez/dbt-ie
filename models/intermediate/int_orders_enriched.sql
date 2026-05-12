with orders_with_items as (
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
        has_order_items,
        order_item_count,
        total_quantity,
        gross_item_revenue,
        net_item_revenue
    from {{ ref('int_orders_with_items') }}
),

shipping as (
    select
        order_id,
        carrier,
        shipping_method,
        shipping_status,
        days_to_ship,
        days_late,
        is_late,
        shipping_performance_bucket
    from {{ ref('int_order_shipping_status') }}
),

payments as (
    select
        order_id,
        total_paid_amount,
        primary_payment_method,
        has_successful_payment,
        payment_status_summary
    from {{ ref('int_payments_by_order') }}
),

enriched as (
    select
        orders_with_items.order_id,
        orders_with_items.customer_id,
        orders_with_items.order_date,
        orders_with_items.status,
        orders_with_items.subtotal,
        orders_with_items.tax_amount,
        orders_with_items.shipping_cost,
        orders_with_items.discount_amount,
        orders_with_items.total_amount,
        orders_with_items.currency,
        orders_with_items.payment_method,
        orders_with_items.has_order_items,
        orders_with_items.order_item_count,
        orders_with_items.total_quantity,
        orders_with_items.gross_item_revenue,
        orders_with_items.net_item_revenue,
        shipping.carrier,
        shipping.shipping_method,
        shipping.shipping_status,
        shipping.days_to_ship,
        shipping.days_late,
        shipping.is_late,
        shipping.shipping_performance_bucket,
        payments.total_paid_amount,
        payments.primary_payment_method,
        payments.payment_status_summary,
        case when orders_with_items.status = 'completed' then true else false end as is_completed_order,
        case when orders_with_items.status = 'cancelled' then true else false end as is_cancelled_order,
        case when orders_with_items.status = 'refunded' then true else false end as is_refunded_order,
        payments.has_successful_payment as is_paid
    from orders_with_items
    left join shipping using (order_id)
    left join payments using (order_id)
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
    has_order_items,
    order_item_count,
    total_quantity,
    gross_item_revenue,
    net_item_revenue,
    carrier,
    shipping_method,
    shipping_status,
    days_to_ship,
    days_late,
    is_late,
    shipping_performance_bucket,
    total_paid_amount,
    primary_payment_method,
    payment_status_summary,
    is_completed_order,
    is_cancelled_order,
    is_refunded_order,
    is_paid
from enriched
