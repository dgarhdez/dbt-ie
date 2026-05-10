-- {{ config(materialized='view') }}
-- It tells dbt how to materialize (store) this model in the database as a View. no data is stored, it just saves the SQL query and runs it fresh every time you query it.

with orders as (
    select
        order_id,
        customer_id,
        order_date,
        status
    from {{ ref('stg_orders') }}
),

final as (
    select
        order_id,
        customer_id,
        order_date,
        status,

        row_number() over (
            partition by customer_id
            order by order_date, order_id
        ) as customer_order_number,

        case
            when row_number() over (
                partition by customer_id
                order by order_date, order_id
            ) = 1 then true
            else false
        end as is_first_order,

        lag(order_date) over (
            partition by customer_id
            order by order_date, order_id
        ) as previous_order_date,

        datediff(
            'day',
            lag(order_date) over (
                partition by customer_id
                order by order_date, order_id
            )::date,
            order_date::date
        ) as days_since_previous_order

    from orders
)

select * from final


--- Question 1: How do you order two customer orders that happen on the same date?
-- You use order_id as a tiebreaker:

-- order by order_date, order_id
-- If two orders share the same order_date, the one with the lower order_id gets the earlier sequence number. 
   --This guarantees the ordering is always deterministic — the same result every time you run the query.

-- Without the tiebreaker, two same-date orders could swap positions randomly on each run.

--- Question 2: Should cancelled orders be included in the sequence?
-- It depends on the business question, but including them is the safer default for an intermediate model.

-- If you exclude cancelled orders here, any mart that needs the full order history can't get it back
-- If you include them, downstream marts can always filter with where status != 'cancelled' if they need to

--- Question 3: Should the sequence use all orders or only completed orders?
-- Same answer as before, all orders in the intermediate layer.

-- The sequence number means something different depending on what you include:

-- All orders: customer_order_number = 1 means their very first attempt
-- Completed only: customer_order_number = 1 means their first successful purchase

--- Question 4: What does a null previous_order_date mean?
-- It means that order is the customer's first order — there is no previous order to look back at.

-- lag() returns NULL when there is no preceding row in the partition. So previous_order_date IS NULL is equivalent 
   -- to is_first_order = true.

-- Consequently, days_since_previous_order will also be NULL for the first order — which is correct, since 
-- there's no previous purchase to measure from.
