# Mart Models: Answering Business Questions

This document gives you business questions to answer using the intermediate models you have already built.
It does not provide the SQL. Your task is to identify the right grain, choose the right sources, and translate each question into a mart model.

The mart layer is the final layer before analytics:

```text
sources -> staging -> intermediate -> marts
```

Intermediate models contain reusable business logic. Mart models answer specific business questions by selecting and organising that logic for a particular audience or use case.

---

## Before You Start

You should have all seven intermediate models building cleanly:

```text
int_customers_enriched
int_order_items_summary
int_orders_with_items
int_order_shipping_status
int_payments_by_order
int_orders_enriched
int_customer_order_sequence
```

Create mart models in:

```text
models/marts/
```

---

## General Rule: Who is asking the question?

Before writing any mart model, answer:

> Who will use this model, and what decision will they make with it?

Examples:

- A finance analyst wants to track monthly revenue trends.
- A logistics team wants to identify late shipments by carrier.
- A CRM team wants to rank customers by lifetime value.

The answer shapes the grain, the fields you include, and the level of aggregation.

---

## 1. `mart_orders`

### Business Question

> What does our order pipeline look like, and what is the status of each order?

### Desired End Goal

Create the main order fact table. One row should represent:

```text
one order
```

This model is a flat, wide table that brings together everything known about an order in one place. It should be the default starting point for any order-level analysis.

### Where to Find the Information

Use:

- `int_orders_enriched`

All the fields you need are already in this model.

### Logic to Think Through

For each order:

- Keep the core order identifiers and dates.
- Keep financial fields: subtotal, tax, shipping cost, discount, total amount.
- Keep item summary fields: item count, quantity, gross and net revenue.
- Keep shipping fields: carrier, days to ship, is late, performance bucket.
- Keep payment fields: total paid, payment status summary.
- Keep business flags: is completed, is cancelled, is refunded, is paid.

This model should not add new logic. Its job is to select and present what already exists in `int_orders_enriched`.

### Questions to Answer

- Should this model include cancelled and refunded orders, or only completed ones?
- Which fields would be most useful for a finance analyst?
- Which fields would be most useful for a logistics analyst?
- Is there any field from `int_orders_enriched` that does not belong in a mart?

---

## 2. `dim_customers`

### Business Question

> Who are our customers, and how valuable are they?

### Desired End Goal

Create a customer dimension that combines customer attributes with their order history metrics. One row should represent:

```text
one customer
```

This model is a dimension table. It should describe each customer as they stand today, enriched with summary metrics derived from their order history.

### Where to Find the Information

Use:

- `int_customers_enriched`
- `int_orders_enriched`

Customer attributes come from `int_customers_enriched`.
Order history metrics need to be aggregated from `int_orders_enriched`.

### Logic to Think Through

For each customer:

- Keep the descriptive fields: full name, email domain, country, segment, segment ID.
- Aggregate order history:
  - Total number of orders placed.
  - Total amount spent across all completed orders.
  - Date of their first order.
  - Date of their most recent order.
  - Average order value.
- Create a flag for whether the customer is a repeat buyer.

Useful business fields may include:

- `total_orders`
- `total_spent`
- `first_order_date`
- `last_order_date`
- `average_order_value`
- `is_repeat_customer`

### Questions to Answer

- Should `total_spent` include cancelled or refunded orders?
- What defines a repeat customer: more than one order placed, or more than one completed order?
- Is the final model still one row per customer after the join and aggregation?
- What happens to customers who have never placed an order?

---

## 3. `mart_monthly_revenue`

### Business Question

> How is our revenue trending over time?

### Desired End Goal

Create a monthly revenue summary. One row should represent:

```text
one calendar month
```

This model should allow a finance team to track revenue performance month over month without querying order-level data directly.

### Where to Find the Information

Use:

- `int_orders_enriched`

### Logic to Think Through

For each month:

- Extract the year and month from `order_date`.
- Count the number of orders.
- Sum the total amount across all orders in that month.
- Sum the total amount for completed orders only.
- Sum the total amount for cancelled or refunded orders.
- Calculate average order value for the month.

Useful business fields may include:

- `order_month` (formatted as `YYYY-MM` or as a date truncated to the first of the month)
- `order_count`
- `gross_revenue`
- `completed_revenue`
- `cancelled_or_refunded_revenue`
- `average_order_value`

### Questions to Answer

- Should `gross_revenue` include all orders regardless of status, or only completed ones?
- How do you extract year and month from a date column in DuckDB?
- How should you sort the output so months appear in chronological order?
- What would you add to this model if you also wanted to break revenue down by customer segment?

---

## 4. `mart_shipping_performance`

### Business Question

> How are our carriers and shipping methods performing?

### Desired End Goal

Create a shipping performance summary grouped by carrier and shipping method. One row should represent:

```text
one carrier and shipping method combination
```

This model should help a logistics team compare carriers and identify where late deliveries are concentrated.

### Where to Find the Information

Use:

- `int_order_shipping_status`

### Logic to Think Through

For each carrier and shipping method combination:

- Count total shipments.
- Count on-time deliveries.
- Count late deliveries.
- Calculate the on-time delivery rate as a percentage.
- Calculate average days to ship.
- Calculate average days late (for late shipments only).

Useful business fields may include:

- `carrier`
- `shipping_method`
- `total_shipments`
- `on_time_count`
- `late_count`
- `on_time_rate`
- `avg_days_to_ship`
- `avg_days_late`

### Questions to Answer

- How do you calculate a percentage in SQL without dividing by zero?
- Should orders with no shipping record be included in this summary?
- What does a high `avg_days_late` tell you compared to a high `late_count`?
- How would you filter this to show only the worst-performing combinations?

---

## 5. `mart_repeat_customers`

### Business Question

> Who are our repeat customers, and how long do they wait between purchases?

### Desired End Goal

Create a customer-level repeat purchase summary. One row should represent:

```text
one customer who has placed more than one order
```

This model should help a CRM or retention team identify loyal customers and understand purchasing cadence.

### Where to Find the Information

Use:

- `int_customer_order_sequence`

### Logic to Think Through

For each customer with more than one order:

- Count the total number of orders.
- Find the average number of days between consecutive orders.
- Find the minimum days between orders (their shortest gap).
- Find the maximum days between orders (their longest gap).
- Find the date of their most recent order.

Useful business fields may include:

- `customer_id`
- `total_orders`
- `avg_days_between_orders`
- `min_days_between_orders`
- `max_days_between_orders`
- `last_order_date`

### Questions to Answer

- How do you exclude first orders when calculating average days between orders? (Hint: think about when `days_since_previous_order` is null.)
- Should cancelled orders count in the sequence?
- What is the difference between this model and the `total_orders` field you might add to `dim_customers`?
- How would you rank customers by average purchase frequency?

---

## Suggested Build Order

Build the models in this order:

```text
mart_orders
dim_customers
mart_monthly_revenue
mart_shipping_performance
mart_repeat_customers
```

After each model, run a focused build:

```bash
dbt build --select <model_name>
```

After all five are complete, run:

```bash
dbt build --select marts
```

---

## Final Checkpoint

You are done when:

- Each mart model has a clear grain.
- Each model reads only from intermediate models (no `source()` calls).
- Aggregations produce the expected row count.
- Business flags and percentages are derived from intermediate logic, not re-computed from raw data.
- A non-technical stakeholder could understand the column names without a data dictionary.

The intermediate layer did the hard work. Mart models should be mostly `select`, `join`, and `group by`.
