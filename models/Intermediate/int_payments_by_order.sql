{{ config(materialized='view') }}
-- It tells dbt how to materialize (store) this model in the database as a View. no data is stored, it just saves the SQL query and runs it fresh every time you query it.

with payments as (
    select
        payment_id,
        order_id,
        customer_id,
        payment_date,
        payment_method,
        amount,
        currency,
        status,
        transaction_id,
        card_last_four,
        payment_processor
    from {{ ref('stg_payments') }}
                 ),
final as (
    select
        order_id,
        count(payment_id) as payment_count,
        count(case when status = 'completed' then 1 end) as successful_payment_count,
        sum(case when status = 'completed' then amount else 0 end) as total_paid_amount,
        max(payment_method) as primary_payment_method,

        case
            when count(case when status = 'completed' then 1 end) > 0
            then true
            else false
        end as has_successful_payment,

        case
            when count(case when status = 'completed' then 1 end) = count(payment_id)
                then 'paid'
            when count(case when status = 'completed' then 1 end) = 0
                and count(payment_id) > 0
                then 'unpaid'
            when count(case when status = 'completed' then 1 end) > 0
                and count(case when status = 'completed' then 1 end) < count(payment_id)
                then 'partially_paid'
            when count(payment_id) = 0
                then 'unknown'
            else 'payment_issue'
        end as payment_status_summary

    from payments
    group by order_id
)

select * from final


--- Question 1: Which raw payment statuses count as successful?
-- select distinct status from payments

-- completed

--- Question 2: Can an order have more than one payment?
-- Yes, the raw stg_payments table can have multiple payment rows per order 

--- Question 3: Should refunded or failed payments count toward total_paid_amount?
-- No, only completed payments should count toward total_paid_amount. 
-- Only payments where money actually landed count toward total_paid_amount.

-- sum(case when status = 'completed' then amount else 0 end) sas total_paid_amount