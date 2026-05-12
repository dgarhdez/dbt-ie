---
title: "feat: Build intermediate layer models for session exercise"
type: feat
status: active
date: 2026-05-12
origin: documentation/intermediate_model_logic_brief.md
---

# feat: Build intermediate layer models for session exercise

## Overview

Create the 12 missing staging models and 7 intermediate models described in the exercise brief. The existing `int_customers.sql` is renamed to `int_customers_enriched.sql` and extended. This gives students a working reference implementation and gives the instructor runnable models to demo during today's session.

## Problem Frame

The exercise brief (`documentation/intermediate_model_logic_brief.md`) describes 7 intermediate models for students to build. Currently, only `stg_customers.sql` and a partial `int_customers.sql` exist. The session needs a complete, runnable solution in the repo so the instructor can demonstrate each model and verify the final DAG with `dbt build`.

## Requirements Trace

- R1. One staging model per source table (13 total, `stg_customers` already done)
- R2. Seven intermediate models in the correct build order with clear grain
- R3. All models use `ref()` — no direct `source()` calls in intermediate layer
- R4. `int_customers.sql` renamed to `int_customers_enriched.sql` and extended with `full_name` and `email_domain`
- R5. Window functions used in `int_customer_order_sequence` to demonstrate `row_number()` and `lag()`
- R6. All SQL follows project conventions: lowercase keywords, identifiers, functions, literals (enforced by `.sqlfluff`)

## Scope Boundaries

- No mart models in this task — the brief explicitly says "do not build marts yet"
- No YAML docs files for this iteration (add in a separate task)
- No dbt tests (generic tests) — add in a separate task aligned with session 09
- `int_customers_enriched` does not change the existing join logic, only adds `full_name` and `email_domain` derived fields

### Deferred to Separate Tasks

- YAML schema files with column descriptions and tests: aligned with session 09 (Testing & Docs)
- Mart models: next exercise layer

## Context & Research

### Relevant Code and Patterns

- `models/staging/stg_customers.sql` — canonical staging pattern: thin `select` directly from `{{ source('raw', ...) }}`
- `models/intermediate/int_customers.sql` — existing CTE pattern with `customers`, `customer_segments`, `merged` CTEs; use this structure as the template
- `seeds/segments.csv` — `segment_id, customer_segment` (Bronze/Silver/Gold/Platinum)
- `models/sources.yml` — all 14 source tables defined under `raw` schema

### Schema notes (from source inspection)

- `orders`: 14 columns — `order_id`, `customer_id`, `order_date`, `status` (pending/cancelled/completed/shipped/refunded), `subtotal`, `tax_amount`, `shipping_cost`, `discount_amount`, `total_amount`, `currency`, `payment_method`, `shipping_address_id`, `billing_address_id`, `coupon_code`
- `order_items`: `order_item_id`, `order_id`, `product_id`, `quantity`, `unit_price`, `discount_amount`, `total_price` — **4 315 rows for 2 125 distinct orders** (multi-row grain)
- `shipping`: `order_id`, `carrier`, `tracking_number`, `shipping_method`, `shipping_cost`, `ship_date`, `estimated_delivery`, `actual_delivery`, `shipping_status` (pending/shipped/in_transit/delivered/returned) — **1 row per order** (already order-grain)
- `payments`: `payment_id`, `order_id`, `customer_id`, `payment_date`, `payment_method`, `amount`, `currency`, `status` — **only `completed` status in the data; 1 row per order** — aggregation is structurally correct but data is simple
- `customers`: 15 columns; `customer_segment` is free-text matching the seed

### Institutional Learnings

- No prior `docs/solutions/` entries for this project yet.

## Key Technical Decisions

- **Staging models are thin wrappers**: `select *` (or explicit column list matching the source) from `{{ source('raw', 'tablename') }}`. No transformations, no type casts, no joins. Matches existing `stg_customers.sql`.
- **CTE style in intermediate models**: Each intermediate model uses named CTEs (`with source as (...), final as (...) select * from final`). Follows the pattern in `int_customers.sql`.
- **`int_customers_enriched` replaces `int_customers`**: Rename the file and add `full_name` (concat of first + last) and `email_domain` (substring after `@`). The join logic is unchanged.
- **`int_order_items_summary` aggregates to order-grain**: Groups `stg_order_items` by `order_id`, computing counts and sums. This is the only pure aggregation model.
- **`int_order_shipping_status` uses a LEFT JOIN from orders to shipping**: Shipping has one row per order, so it's a flat join. The lateness logic uses `case when` on date comparison (`actual_delivery > estimated_delivery`). Null-safe: if `actual_delivery` is null, status is `not_shipped` or `unknown` depending on `shipping_status`.
- **`int_payments_by_order` is mostly flag logic**: Payments are already 1 per order with only `completed` status in the dataset. The model adds business flags (`has_successful_payment`, `payment_status_summary`) using `case when`. This teaches the pattern even though aggregation is trivial here.
- **`int_orders_enriched` is a pure join model**: Joins `int_orders_with_items`, `int_order_shipping_status`, and `int_payments_by_order` on `order_id`. Adds boolean flags for order states (`is_completed_order`, etc.).
- **`int_customer_order_sequence` uses window functions only**: `row_number()` for sequence and `lag()` for previous date, both `partition by customer_id order by order_date`. Includes all orders regardless of status (students can discuss the tradeoff in class).
- **No `dbt_project.yml` materialization changes needed**: Staging models default to views (already configured); intermediate layer can also stay as views for now.

## Open Questions

### Resolved During Planning

- **Should `int_customers_enriched` replace `int_customers.sql` or coexist?**: Replace — rename the file. The brief uses the `_enriched` name and there are no downstream refs yet.
- **Should `int_payments_by_order` aggregate even though data is 1:1?**: Yes — write it as a proper aggregation (group by order_id). This teaches the correct pattern and future data may have multiple payments per order.
- **Which model drives `int_customer_order_sequence`?**: Use `stg_orders` (simpler, focuses the lesson on window functions without noise from upstream joins).
- **Should `int_order_shipping_status` LEFT JOIN from orders?**: Yes — we want every order in the output, including those with no shipping record yet.

### Deferred to Implementation

- Exact column alias choices for `net_item_revenue` in `int_order_items_summary` — implementer should verify `total_price - discount_amount` vs `unit_price * quantity - discount_amount` against source semantics.
- Whether `int_customer_order_sequence` should include `int_orders_enriched` fields — defer until the student exercise discussion reveals a preference.

## Implementation Units

- [ ] **Unit 1: Create 12 missing staging models**

**Goal:** One thin staging view per remaining source table so the intermediate layer has clean `ref()` targets.

**Requirements:** R1, R6

**Dependencies:** None (source tables already in DuckDB via `create_db.py`)

**Files:**
- Create: `models/staging/stg_orders.sql`
- Create: `models/staging/stg_order_items.sql`
- Create: `models/staging/stg_shipping.sql`
- Create: `models/staging/stg_payments.sql`
- Create: `models/staging/stg_products.sql`
- Create: `models/staging/stg_categories.sql`
- Create: `models/staging/stg_suppliers.sql`
- Create: `models/staging/stg_customer_addresses.sql`
- Create: `models/staging/stg_inventory.sql`
- Create: `models/staging/stg_marketing_campaigns.sql`
- Create: `models/staging/stg_returns.sql`
- Create: `models/staging/stg_reviews.sql`
- Create: `models/staging/stg_website_sessions.sql`

**Approach:**
- Each model is a single `select` of all columns from `{{ source('raw', '<table_name>') }}`
- No joins, no aggregations, no type casts — match `stg_customers.sql` exactly
- Column list can be explicit (`select col1, col2, ...`) or `select *` — explicit preferred for teaching clarity

**Patterns to follow:**
- `models/staging/stg_customers.sql`

**Test scenarios:**
- Happy path: `dbt build --select staging` produces 13 views with row counts matching source tables
- Test expectation: no behavioral logic — these are identity views. Verification is row count parity with source.

**Verification:**
- `dbt run --select staging` succeeds with no errors
- Row count of each staging view matches the corresponding source table

---

- [ ] **Unit 2: Rename and extend `int_customers_enriched`**

**Goal:** Rename `int_customers.sql` to `int_customers_enriched.sql` and add `full_name` and `email_domain` derived fields.

**Requirements:** R2, R4, R6

**Dependencies:** Unit 1 (stg_customers already exists)

**Files:**
- Delete/rename: `models/intermediate/int_customers.sql` → `models/intermediate/int_customers_enriched.sql`
- Modify: `models/intermediate/int_customers_enriched.sql`

**Approach:**
- Keep existing CTE structure (`customers`, `customer_segments`, `merged`)
- In the `customers` CTE, add two derived fields:
  - `full_name`: concatenation of `first_name || ' ' || last_name`
  - `email_domain`: substring of `email` after the `@` character (DuckDB: `split_part(email, '@', 2)`)
- Carry both new fields through `merged` and the final `select *`
- Join logic (LEFT JOIN on `customer_segment`) is unchanged

**Patterns to follow:**
- `models/intermediate/int_customers.sql` (existing CTE structure)

**Test scenarios:**
- Happy path: every row has a non-null `full_name` (assuming first/last name are present in source)
- Happy path: `email_domain` correctly extracts the domain portion (e.g. `gmail.com` from `user@gmail.com`)
- Edge case: customers with no matching segment get `null` `segment_id` (LEFT JOIN behaviour — expected)
- Grain check: row count of `int_customers_enriched` equals row count of `stg_customers`

**Verification:**
- `dbt build --select int_customers_enriched` succeeds
- `select count(*) from int_customers_enriched` equals `select count(*) from stg_customers`
- `select full_name, email_domain from int_customers_enriched limit 5` returns sensible values

---

- [ ] **Unit 3: `int_order_items_summary`**

**Goal:** Aggregate `stg_order_items` to one row per order, computing item counts and revenue totals.

**Requirements:** R2, R6

**Dependencies:** Unit 1 (stg_order_items)

**Files:**
- Create: `models/intermediate/int_order_items_summary.sql`

**Approach:**
- Single CTE `order_items` from `{{ ref('stg_order_items') }}`
- Group by `order_id`
- Compute:
  - `order_item_count` — `count(*)` or `count(order_item_id)`
  - `total_quantity` — `sum(quantity)`
  - `gross_item_revenue` — `sum(unit_price * quantity)`
  - `total_item_discount_amount` — `sum(discount_amount)`
  - `net_item_revenue` — `sum(total_price)` (already discounted in source) or `gross_item_revenue - total_item_discount_amount`
- The final select outputs `order_id` plus the five measures above

**Patterns to follow:**
- `models/intermediate/int_customers.sql` CTE style
- Source column definitions from `order_items` schema

**Test scenarios:**
- Happy path: output has exactly 2 125 rows (one per distinct order_id in source)
- Happy path: `sum(total_quantity)` across all rows equals `sum(quantity)` from raw `stg_order_items`
- Grain check: `count(*) = count(distinct order_id)` on the output — no duplicate orders
- Aggregation check: for a spot-checked `order_id`, `order_item_count` matches the actual number of line items in `stg_order_items`

**Verification:**
- `dbt build --select int_order_items_summary` succeeds
- Row count is 2 125

---

- [ ] **Unit 4: `int_orders_with_items`**

**Goal:** Join order header fields from `stg_orders` with item summary from `int_order_items_summary` to produce one enriched row per order.

**Requirements:** R2, R3, R6

**Dependencies:** Unit 1 (stg_orders), Unit 3 (int_order_items_summary)

**Files:**
- Create: `models/intermediate/int_orders_with_items.sql`

**Approach:**
- Two CTEs: `orders` from `{{ ref('stg_orders') }}`, `order_items_summary` from `{{ ref('int_order_items_summary') }}`
- LEFT JOIN `order_items_summary` onto `orders` using `order_id` — orders drive the grain, not items
- Add a boolean flag `has_order_items`: `case when order_items_summary.order_id is not null then true else false end`
- Bring forward all `stg_orders` columns plus the five item summary measures

**Patterns to follow:**
- Join pattern from `int_customers.sql`

**Test scenarios:**
- Happy path: row count equals row count of `stg_orders` (orders drive the grain)
- Happy path: `has_order_items = true` for all orders that appear in `stg_order_items`
- Edge case: if any order has no items in `stg_order_items`, `has_order_items = false` and item measures are `null` (LEFT JOIN behaviour)
- Grain check: `count(*) = count(distinct order_id)` on the output

**Verification:**
- `dbt build --select int_orders_with_items` succeeds
- Row count equals `stg_orders` row count

---

- [ ] **Unit 5: `int_order_shipping_status`**

**Goal:** Add shipping timing and delivery performance fields to each order using a LEFT JOIN from orders to shipping.

**Requirements:** R2, R3, R6

**Dependencies:** Unit 1 (stg_orders, stg_shipping)

**Files:**
- Create: `models/intermediate/int_order_shipping_status.sql`

**Approach:**
- Two CTEs: `orders` from `{{ ref('stg_orders') }}`, `shipping` from `{{ ref('stg_shipping') }}`
- LEFT JOIN shipping to orders on `order_id`
- Compute:
  - `days_to_ship`: `datediff('day', cast(order_date as date), cast(ship_date as date))` — null if `ship_date` is null
  - `days_late`: `datediff('day', cast(estimated_delivery as date), cast(actual_delivery as date))` — null if either date is missing; positive means late, negative means early
  - `is_late`: `case when actual_delivery > estimated_delivery then true else false end` — null-safe (null → false)
  - `shipping_performance_bucket`:
    - `'not_shipped'` when `ship_date` is null
    - `'early'` when `actual_delivery < estimated_delivery`
    - `'on_time'` when `actual_delivery = estimated_delivery`
    - `'late'` when `actual_delivery > estimated_delivery`
    - `'unknown'` otherwise (e.g. shipped but not yet delivered)
- Keep `carrier`, `shipping_method`, `shipping_status` from the shipping CTE
- Orders with no matching shipping row: all shipping fields are null, performance bucket is `'not_shipped'`

**Patterns to follow:**
- LEFT JOIN approach from `int_customers.sql`
- DuckDB date functions (`datediff`, `cast(... as date)`)

**Test scenarios:**
- Happy path: row count equals `stg_orders` row count (LEFT JOIN from orders)
- Happy path: orders with `shipping_status = 'delivered'` have a non-null `actual_delivery`
- Edge case: orders with null `ship_date` produce `shipping_performance_bucket = 'not_shipped'`
- Edge case: orders with `ship_date` but null `actual_delivery` produce `shipping_performance_bucket = 'unknown'`
- Logic check: `is_late = true` only when `actual_delivery > estimated_delivery`

**Verification:**
- `dbt build --select int_order_shipping_status` succeeds
- Row count equals `stg_orders` row count

---

- [ ] **Unit 6: `int_payments_by_order`**

**Goal:** Summarise payment records to one row per order, adding business-level payment status flags.

**Requirements:** R2, R3, R6

**Dependencies:** Unit 1 (stg_payments)

**Files:**
- Create: `models/intermediate/int_payments_by_order.sql`

**Approach:**
- Single CTE `payments` from `{{ ref('stg_payments') }}`
- Group by `order_id`
- Compute:
  - `payment_count`: `count(*)`
  - `successful_payment_count`: `count(case when status = 'completed' then 1 end)` (only `completed` exists in current data, but write the logic explicitly)
  - `total_paid_amount`: `sum(case when status = 'completed' then amount else 0 end)`
  - `primary_payment_method`: `max(payment_method)` — a simple deterministic pick; pedagogically fine
  - `has_successful_payment`: `case when sum(case when status = 'completed' then 1 else 0 end) > 0 then true else false end`
  - `payment_status_summary`:
    - `'paid'` when `successful_payment_count = payment_count` (all completed)
    - `'partially_paid'` when `successful_payment_count > 0 and successful_payment_count < payment_count`
    - `'unpaid'` when `successful_payment_count = 0 and payment_count > 0`
    - `'unknown'` when `payment_count = 0`

**Patterns to follow:**
- Aggregation pattern from `int_order_items_summary`

**Test scenarios:**
- Happy path: row count equals 2 125 (one row per order; current data is 1:1)
- Happy path: all rows have `payment_status_summary = 'paid'` (all current records are `completed`)
- Happy path: `total_paid_amount` is non-null and positive for all rows
- Grain check: `count(*) = count(distinct order_id)` on the output
- Logic check: `has_successful_payment = true` for all rows in current data

**Verification:**
- `dbt build --select int_payments_by_order` succeeds
- Row count is 2 125

---

- [ ] **Unit 7: `int_orders_enriched`**

**Goal:** Combine `int_orders_with_items`, `int_order_shipping_status`, and `int_payments_by_order` into a single enriched order model with boolean business flags.

**Requirements:** R2, R3, R6

**Dependencies:** Unit 4, Unit 5, Unit 6

**Files:**
- Create: `models/intermediate/int_orders_enriched.sql`

**Approach:**
- Three CTEs: `orders_with_items`, `shipping_status`, `payment_summary` from their respective intermediate models
- JOIN all three on `order_id` — LEFT JOINs from `orders_with_items` (keeps all orders as the base)
- Add boolean flags using `case when`:
  - `is_completed_order`: `status = 'completed'`
  - `is_cancelled_order`: `status = 'cancelled'`
  - `is_refunded_order`: `status = 'refunded'`
  - `is_paid`: derived from `payment_summary.has_successful_payment`
  - `is_late`: from `shipping_status.is_late`
  - `has_order_items`: from `orders_with_items.has_order_items`
- Select a curated set of fields — not `select *` — to show intentional field curation

**Patterns to follow:**
- Multi-CTE join pattern; all refs to intermediate models

**Test scenarios:**
- Happy path: row count equals `stg_orders` row count (grain preserved through joins)
- Happy path: `is_completed_order` is true for orders with `status = 'completed'`
- Happy path: `is_paid = true` for rows where `payment_summary.has_successful_payment = true`
- Grain check: `count(*) = count(distinct order_id)` on the output
- Integration: joining `int_orders_enriched` to `int_customers_enriched` on `customer_id` should produce one row per order (no fan-out)

**Verification:**
- `dbt build --select int_orders_enriched` succeeds
- Row count equals `stg_orders` row count

---

- [ ] **Unit 8: `int_customer_order_sequence`**

**Goal:** Add order sequence numbers and inter-order timing using window functions, one row per customer-order.

**Requirements:** R2, R3, R5, R6

**Dependencies:** Unit 1 (stg_orders)

**Files:**
- Create: `models/intermediate/int_customer_order_sequence.sql`

**Approach:**
- Single CTE `orders` from `{{ ref('stg_orders') }}`
- Apply window functions in the final select (or a second CTE `sequenced`):
  - `customer_order_number`: `row_number() over (partition by customer_id order by order_date)`
  - `is_first_order`: `case when row_number() over (...) = 1 then true else false end` — or derive from `customer_order_number = 1`
  - `previous_order_date`: `lag(order_date) over (partition by customer_id order by order_date)`
  - `days_since_previous_order`: `datediff('day', cast(previous_order_date as date), cast(order_date as date))` — null for first order
- Includes ALL orders regardless of status (instructor note: discuss with students whether cancelled orders should be excluded)
- Tiebreaker for same-date orders: add `order_id` as a secondary sort key to ensure deterministic numbering

**Patterns to follow:**
- DuckDB window function syntax: `function() over (partition by ... order by ...)`

**Test scenarios:**
- Happy path: `customer_order_number = 1` for the earliest order per customer
- Happy path: `is_first_order = true` only when `customer_order_number = 1`
- Happy path: `previous_order_date` is null when `customer_order_number = 1`
- Happy path: `days_since_previous_order` is null for first orders, positive for subsequent orders
- Grain check: row count equals `stg_orders` row count (one row per order, not per customer)
- Window function check: for a customer with 3 orders, `customer_order_number` takes values 1, 2, 3

**Verification:**
- `dbt build --select int_customer_order_sequence` succeeds
- Row count equals `stg_orders` row count
- `select customer_id, count(*) from int_customer_order_sequence group by 1 order by 2 desc limit 5` shows customers with multiple orders, all correctly sequenced

## System-Wide Impact

- **Interaction graph:** No marts or exposures yet — changes are purely additive to the DAG
- **Error propagation:** Staging failures will cascade to all intermediate models downstream
- **Unchanged invariants:** `stg_customers.sql` and `seeds/segments.csv` are not modified; `int_customers_enriched` is a rename + extend, not a rewrite
- **Build order:** Must follow `dbt_project.yml` DAG — staging before intermediate; within intermediate, unit build order in this plan is the correct dependency sequence

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| DuckDB date functions differ from other adapters | Use DuckDB-native `datediff`, `cast(... as date)`, `split_part` — tested against `my_database.duckdb` |
| Payments data only has `completed` status — `int_payments_by_order` logic looks trivial | Write the aggregation and `case when` status logic explicitly anyway; explain to students this is the correct pattern for production data |
| Shipping is already 1:1 with orders — students may question why `int_order_shipping_status` is needed | Teaching point: intermediate models add computed business logic, not just normalization |
| `int_customers.sql` rename may confuse git history | Delete the old file and create the new one; commit message should call out the rename |

## Sources & References

- **Origin document:** [documentation/intermediate_model_logic_brief.md](documentation/intermediate_model_logic_brief.md)
- Source schema: inspected via `DESCRIBE <table>` on `my_database.duckdb`
- Existing pattern: `models/staging/stg_customers.sql`, `models/intermediate/int_customers.sql`
- dbt docs: `ref()` and `source()` usage conventions
