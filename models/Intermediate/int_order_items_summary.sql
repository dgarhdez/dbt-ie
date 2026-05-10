-- {{ config(materialized='view') }} 
-- It tells dbt how to materialize (store) this model in the database as a View. no data is stored, it just saves the SQL query and runs it fresh every time you query it.

with order_items as (
    SELECT
        order_item_id,
        order_id,
        product_id,
        quantity,
        unit_price,
        discount_amount,
        total_price
    from {{ ref('stg_order_items')}}
                    ),
final as (
    SELECT
        order_items.order_id,
        count(order_item_id) as order_item_count,
        sum(quantity) as total_quantity,
        sum(unit_price * quantity) as gross_item_revenue,
        sum(discount_amount) as total_item_discount_amount,
        sum(total_price) as net_item_revenue
    FROM order_items    
    GROUP BY order_items.order_id
         )

select * from final


--- Question 1: Why is this model grouped by order_id?
-- Because group by defines the grain, and grain is what does one row represent.

--- Question 2: What would go wrong if you joined raw stg_order_items directly to stg_orders?
-- We would get douplicate rows and calculations

--- Question 3: Does the model produce exactly one row per order?

-- select 
--     count(*) as total_rows, 
--     count(distinct order_id) as unique_orders,
--     cast(total_rows as int) - cast(unique_orders as int) as difference
-- from final