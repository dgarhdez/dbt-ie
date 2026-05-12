# Intermediate Model Logic Brief

This document explains the thinking behind the first intermediate models.
It does not provide the SQL. Your task is to translate each business goal into a dbt model using `ref()`, joins, aggregations, and window functions.

The intermediate layer sits between staging and marts:

```text
sources -> staging -> intermediate -> marts
```

Staging models should stay close to the raw source tables. Intermediate models are where we start adding reusable business logic.

---

## Before You Start

You should already have one staging model per source table:

```text
stg_customers
stg_orders
stg_order_items
stg_shipping
stg_payments
stg_products
stg_categories
stg_suppliers
stg_customer_addresses
stg_inventory
stg_marketing_campaigns
stg_returns
stg_reviews
stg_website_sessions
```

The raw source definitions are in:

```text
models/sources.yml
```

The staging models are in:

```text
models/staging/
```

The seed file for customer segments is in:

```text
seeds/segments.csv
```

Create the intermediate models in:

```text
models/intermediate/
```

---

## General Rule: Know the Grain

Before writing any intermediate model, answer:

> What does one row represent?

Examples:

- One row per customer.
- One row per order.
- One row per order item.
- One row per customer order, ordered over time.

Most modeling mistakes come from joining tables with different grains without thinking about the result.

---

## 1. `int_customers_enriched`

### Desired End Goal

Create a customer-level model that adds useful customer attributes for downstream analysis.

One row should represent:

```text
one customer
```

This model should enrich the customer record with segment information and simple customer descriptors.

### Where to Find the Information

Use:

- `stg_customers`
- `segments`

The customer information comes from the raw `customers` table through `stg_customers`.

The segment lookup comes from:

```text
seeds/segments.csv
```

### Logic to Think Through

For each customer:

- Keep the core customer identifier: `customer_id`.
- Keep useful descriptive fields such as name, email, country, and customer segment.
- Connect each customer segment to the numeric `segment_id` from the seed.
- Consider whether to create a `full_name` field from first and last name.
- Consider whether to extract an `email_domain` from the email address.

### Questions to Answer

- Does every customer have a valid segment?
- What should happen if a customer segment is missing from the seed?
- Is this model still one row per customer after the join?

---

## 2. `int_order_items_summary`

### Desired End Goal

Create an order-level summary of the order item table.

One row should represent:

```text
one order
```

The raw order item table has multiple rows per order. This model reduces it to one row per order so that it can be safely joined to `stg_orders`.

### Where to Find the Information

Use:

- `stg_order_items`

The raw data comes from the `order_items` source table.

### Logic to Think Through

For each order:

- Count how many item rows belong to the order.
- Sum the quantity of products purchased.
- Sum item-level revenue.
- Sum item-level discounts.
- Decide which fields should be named as totals, counts, or amounts.

Useful business measures may include:

- `order_item_count`
- `total_quantity`
- `gross_item_revenue`
- `total_item_discount_amount`
- `net_item_revenue`

### Questions to Answer

- Why is this model grouped by `order_id`?
- What would go wrong if you joined raw `stg_order_items` directly to `stg_orders`?
- Does the model produce exactly one row per order?

---

## 3. `int_orders_with_items`

### Desired End Goal

Create an order-level model that combines order header information with summarized item information.

One row should represent:

```text
one order
```

This model should make it easy to compare what is recorded on the order with what is calculated from the order items.

### Where to Find the Information

Use:

- `stg_orders`
- `int_order_items_summary`

The order header information comes from the raw `orders` table through `stg_orders`.

The item summary comes from the previous intermediate model.

### Logic to Think Through

For each order:

- Keep the order identifier and customer identifier.
- Keep order-level fields such as order date, status, subtotal, tax, shipping cost, discount, total amount, currency, and payment method.
- Add the item-level summary measures from `int_order_items_summary`.
- Consider whether the order has item records.
- Consider whether order totals and item totals tell the same story.

Useful business fields may include:

- `has_order_items`
- `order_item_count`
- `total_quantity`
- `gross_item_revenue`
- `net_item_revenue`
- `total_amount`

### Questions to Answer

- Should every order have at least one order item?
- Which table defines the final row count: orders or order items?
- What is the difference between `subtotal`, `total_amount`, and calculated item revenue?

---

## 4. `int_order_shipping_status`

### Desired End Goal

Create an order-level model that adds shipping timing and delivery status logic.

One row should represent:

```text
one order with shipping information
```

This model should translate raw shipping dates and statuses into business-friendly delivery indicators.

### Where to Find the Information

Use:

- `stg_orders`
- `stg_shipping`

The order date comes from `stg_orders`.

Shipping fields come from `stg_shipping`, including:

- `ship_date`
- `estimated_delivery`
- `actual_delivery`
- `shipping_status`
- `carrier`
- `shipping_method`

### Logic to Think Through

For each order:

- Compare the order date with the ship date.
- Compare estimated delivery with actual delivery.
- Decide when an order should be considered late.
- Create a simple shipping performance category.

Useful business fields may include:

- `days_to_ship`
- `days_late`
- `is_late`
- `shipping_performance_bucket`

Example performance buckets:

- `not_shipped`
- `early`
- `on_time`
- `late`
- `unknown`

### Questions to Answer

- What should happen when shipping dates are missing?
- Should pending shipments be considered late?
- Is the definition of late based on ship date or delivery date?

---

## 5. `int_payments_by_order`

### Desired End Goal

Create an order-level payment summary.

One row should represent:

```text
one order
```

The payment table can contain payment transaction records. This model should summarize those records into payment status and payment amount indicators for each order.

### Where to Find the Information

Use:

- `stg_payments`

The raw data comes from the `payments` source table.

### Logic to Think Through

For each order:

- Count how many payment records exist.
- Sum successful payment amounts.
- Count completed payments.
- Count failed, cancelled, or non-completed payments if those statuses exist.
- Decide how to choose or label the main payment method.
- Create a business-level payment status.

Useful business fields may include:

- `payment_count`
- `successful_payment_count`
- `total_paid_amount`
- `primary_payment_method`
- `has_successful_payment`
- `payment_status_summary`

Example payment status summaries:

- `paid`
- `unpaid`
- `partially_paid`
- `payment_issue`
- `unknown`

### Questions to Answer

- Which raw payment statuses count as successful?
- Can an order have more than one payment?
- Should refunded or failed payments count toward `total_paid_amount`?

---

## 6. `int_orders_enriched`

### Desired End Goal

Create a reusable enriched order model that combines order, item, shipping, and payment logic.

One row should represent:

```text
one order
```

This is the main order-level intermediate model. It should be useful for future fact tables and business analysis.

### Where to Find the Information

Use:

- `int_orders_with_items`
- `int_order_shipping_status`
- `int_payments_by_order`

Depending on your design, you may also use:

- `stg_orders`

### Logic to Think Through

For each order:

- Keep the core order fields.
- Add item summary fields.
- Add shipping status and timing fields.
- Add payment summary fields.
- Add useful business flags.

Useful business flags may include:

- `is_completed_order`
- `is_cancelled_order`
- `is_refunded_order`
- `is_paid`
- `is_late`
- `has_order_items`

This model should centralize order-level business logic so that future marts do not repeat the same joins and `case when` statements.

### Questions to Answer

- Is the final model still one row per order?
- Which upstream model controls the grain?
- Which fields are raw facts, and which fields are business logic?
- What logic would become repetitive if this model did not exist?

---

## 7. `int_customer_order_sequence`

### Desired End Goal

Create a model that shows the sequence of each customer's orders over time.

One row should represent:

```text
one customer order
```

This model introduces window functions. It should help answer questions about first orders, repeat orders, and time between purchases.

### Where to Find the Information

Use:

- `stg_orders`

You may also use:

- `int_orders_enriched`

Use `int_orders_enriched` if you want the sequence to include payment, shipping, or item-based order logic. Use `stg_orders` if you want to focus only on order timing.

### Logic to Think Through

For each customer:

- Sort their orders by order date.
- Number each order in sequence.
- Identify whether an order is the customer's first order.
- Find the previous order date.
- Calculate the number of days since the previous order.

Useful business fields may include:

- `customer_order_number`
- `is_first_order`
- `previous_order_date`
- `days_since_previous_order`

### Questions to Answer

- How do you order two customer orders that happen on the same date?
- Should cancelled orders be included in the sequence?
- Should the sequence use all orders or only completed orders?
- What does a null `previous_order_date` mean?

---

## Suggested Build Order

Build the models in this order:

```text
int_customers_enriched
int_order_items_summary
int_orders_with_items
int_order_shipping_status
int_payments_by_order
int_orders_enriched
int_customer_order_sequence
```

After each model, run a focused build:

```bash
dbt build --select <model_name>
```

After all seven are complete, run:

```bash
dbt build --select intermediate
```

---

## Final Checkpoint

You are done when:

- Each intermediate model has a clear grain.
- Each model uses `ref()` to read from staging or previous intermediate models.
- Joins do not accidentally duplicate rows.
- Aggregations produce the expected row count.
- Window functions are used only where row-by-row sequence matters.
- Business logic is centralized and reusable.

Do not build marts yet. The goal here is to create clean, reusable building blocks.
