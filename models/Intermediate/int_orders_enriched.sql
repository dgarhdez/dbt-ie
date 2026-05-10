-- {{ config(materialized='view') }}
-- It tells dbt how to materialize (store) this model in the database as a View. no data is stored, it just saves the SQL query and runs it fresh every time you query it.

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
        payment_method
    from {{ ref('stg_orders') }}
),

order_items as (
    select
        order_id,
        order_item_count,
        total_quantity,
        gross_item_revenue,
        total_item_discount_amount,
        net_item_revenue
    from {{ ref('int_order_items_summary') }}
),

shipping as (
    select
        order_id,
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
    from {{ ref('int_order_shipping_status') }}
),

payments as (
    select
        order_id,
        payment_count,
        successful_payment_count,
        total_paid_amount,
        primary_payment_method,
        has_successful_payment,
        payment_status_summary
    from {{ ref('int_payments_by_order') }}
),

final as (
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

        order_items.order_item_count,
        order_items.total_quantity,
        order_items.gross_item_revenue,
        order_items.total_item_discount_amount,
        order_items.net_item_revenue,

        shipping.carrier,
        shipping.shipping_method,
        shipping.shipping_status,
        shipping.ship_date,
        shipping.estimated_delivery,
        shipping.actual_delivery,
        shipping.days_to_ship,
        shipping.days_late,
        shipping.is_late,
        shipping.shipping_performance_bucket,

        payments.payment_count,
        payments.successful_payment_count,
        payments.total_paid_amount,
        payments.primary_payment_method,
        payments.has_successful_payment,
        payments.payment_status_summary,

        case when orders.status = 'completed'  then true else false end as is_completed_order,
        case when orders.status = 'cancelled'  then true else false end as is_cancelled_order,
        case when orders.status = 'refunded'   then true else false end as is_refunded_order,
        payments.has_successful_payment                                 as is_paid,
        shipping.is_late,
        case when order_items.order_item_count > 0 then true else false end as has_order_items

    from orders
    left join order_items using (order_id)
    left join shipping   using (order_id)
    left join payments   using (order_id)
)

select * from final


--- Question 1: Is the final model still one row per order?

-- Yes, all four joins use left join, using (order_id), and orders is the driving table (on the left of every join).
-- Since stg_orders is one row per order, and each joined model (int_order_items_summary, 
   --int_order_shipping_status, int_payments_by_order) is also one row per order, no join can fan out rows.

-- select 
--     count(*) as total_rows, 
--     count(distinct order_id) as unique_orders,
--     total_rows - unique_orders as difference
-- from final


--- Question 2: Which upstream model controls the grain?

-- stg_orders controls the grain — it's the driving table in the final join:
-- from orders          -- this is stg_orders
-- left join order_items using (order_id)
-- left join shipping   using (order_id)
-- left join payments   using (order_id)

-- Because it's on the left of every left join, it determines how many rows the final model has. 
-- All other models just add columns to each order row, they never add new rows.


--- Question 3: Which fields are raw facts, and which fields are business logic?

-- Raw facts are    pulled directly from source tables, no transformation:

-- order_id, customer_id, order_date, status
-- subtotal, tax_amount, shipping_cost, discount_amount, total_amount, currency
-- carrier, shipping_method, shipping_status, ship_date, estimated_delivery, actual_delivery
-- payment_count, total_paid_amount, primary_payment_method

-- Business logic are calculated or interpreted fields:

-- days_to_ship, days_late — calculated from date differences
-- is_late, shipping_performance_bucket — interpreted from comparing dates
-- is_completed_order, is_cancelled_order, is_refunded_order — case when on status
-- is_paid — derived from payment records
-- has_order_items — derived from item count
-- payment_status_summary — interpreted from multiple payment records

--- Question 4: 

-- Every mart that needs order data would have to repeat the same joins and case when statements themselves. 
-- For example:

-- mart_orders would need to join stg_orders + int_order_items_summary + int_order_shipping_status + int_payments_by_order 
   -- every time
-- dim_customers would need to recalculate is_completed_order, is_paid, is_late from scratch
-- Any revenue report would need to re-derive total_paid_amount and net_item_revenue
-- So instead of writing this once in int_orders_enriched:


-- case when orders.status = 'completed' then true else false end as is_completed_order
-- You'd write it in 3, 4, or 5 different mart models — and if the business definition of "completed" ever changes, 
   -- you'd have to update it in every single place.

-- int_orders_enriched is the single source of truth for order-level business logic.