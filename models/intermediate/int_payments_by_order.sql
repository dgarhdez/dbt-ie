with payments as (
    select
        payment_id,
        order_id,
        payment_method,
        amount,
        status
    from {{ ref('stg_payments') }}
),

summary as (
    select
        order_id,
        count(payment_id) as payment_count,
        count(case when status = 'completed' then 1 end) as successful_payment_count,
        sum(case when status = 'completed' then amount else 0 end) as total_paid_amount,
        max(payment_method) as primary_payment_method,
        case
            when sum(case when status = 'completed' then 1 else 0 end) > 0 then true
            else false
        end as has_successful_payment,
        case
            when count(payment_id) = 0 then 'unknown'
            when sum(case when status = 'completed' then 1 else 0 end) = count(payment_id) then 'paid'
            when sum(case when status = 'completed' then 1 else 0 end) > 0 then 'partially_paid'
            else 'unpaid'
        end as payment_status_summary
    from payments
    group by order_id
)

select
    order_id,
    payment_count,
    successful_payment_count,
    total_paid_amount,
    primary_payment_method,
    has_successful_payment,
    payment_status_summary
from summary
