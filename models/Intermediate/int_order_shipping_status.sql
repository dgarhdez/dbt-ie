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
        payment_method,
        shipping_address_id,
        billing_address_id,
        coupon_code
    from {{ref('stg_orders')}}
               ),

shipping as (
    select
        order_id,
        carrier,
        tracking_number,
        shipping_method,
        shipping_cost,
        ship_date,
        estimated_delivery,
        actual_delivery,
        shipping_status,
        weight_kg,
    from {{ref('stg_shipping')}}
            ),

final as (
    select 
        orders.order_id,
        orders.order_date,
        shipping.carrier,
        shipping.shipping_method,
        shipping.shipping_status,
        shipping.ship_date,
        shipping.estimated_delivery,
        shipping.actual_delivery,

        datediff('day', orders.order_date:: date, shipping.ship_date:: date) as days_to_ship,
        datediff('day', cast(shipping.estimated_delivery as date), cast(shipping.actual_delivery as date)) as days_late,

        case 
            when shipping.actual_delivery is null then FALSE
            when shipping.actual_delivery > shipping.estimated_delivery then TRUE
            else FALSE
        end as is_late,

        case
            when shipping.ship_date is null then 'not_shipped'
            when shipping.actual_delivery is null then 'not_shipped'
            when shipping.actual_delivery > shipping.estimated_delivery then 'late'
            when shipping.actual_delivery <= shipping.estimated_delivery then 'on_time'
            else 'unknown'
        end as shipping_performance_bucket

    from orders
    left join shipping using (order_id)
         )

select * from final



--- Question 1: What should happen when shipping dates are missing?
-- With my current left join, when shipping dates are missing they become NULL. The case when already handles this correctly
-- when shipping.ship_date is null then 'not_shipped'
-- when shipping.actual_delivery is null then 'not_shipped'

--- Question 2: Should pending shipments be considered late?
-- No — a pending shipment hasn't been delivered yet, so you can't know if it will be late.
-- when shipping.ship_date is null then 'not_shipped'
-- when shipping.actual_delivery is null then 'not_shipped'

-- If there's no actual_delivery yet, it falls into not_shipped — it never reaches the late check. 
   --So pending shipments are never marked as late, which is the right business logic.

--- Question 3: Is the definition of late based on ship date or delivery date?
-- It is based on delivery date, specifically comparing actual_delivery - estimated_delivery:
-- when shipping.actual_delivery > shipping.estimated_delivery then 'late'

-- Ship date is only used to calculate days_to_ship (how long it took to dispatch the order),
   -- but it has nothing to do with whether the order is considered late or not.