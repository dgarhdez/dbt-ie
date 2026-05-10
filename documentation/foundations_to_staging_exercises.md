# Foundations to Staging Exercises

This exercise suite takes the project from local raw data files to a complete dbt staging layer.
Stop when every source table has a corresponding `stg_*` model that builds cleanly.

Do not build intermediate or mart models in this exercise set.

---

## Starting Point

You should have:

- A working Python environment from `uv sync`.
- The project open at the repository root.
- The Parquet files available under `data/`.
- dbt dependencies installed with `dbt deps` or `uv run dbt deps`.

Use `uv run` before commands if your virtual environment is not activated.

---

## Exercise 1: Create the DuckDB Database

**Goal:** Load every Parquet file in `data/` into a local DuckDB database.

Run:

```bash
uv run python create_db.py
```

This should create:

```text
my_database.duckdb
```

Verify the database file exists:

```bash
ls -lh my_database.duckdb
```

Check the loaded tables:

```bash
duckdb my_database.duckdb -c "show tables"
```

Expected raw tables:

```text
categories
customer_addresses
customers
inventory
marketing_campaigns
order_items
orders
payments
products
returns
reviews
shipping
suppliers
website_sessions
```

Checkpoint:

- [ ] `my_database.duckdb` exists.
- [ ] DuckDB shows 14 raw tables.
- [ ] The table names match the Parquet filenames in `data/`.

---

## Exercise 2: Confirm dbt Can Connect

**Goal:** Verify that dbt can find the local profile and connect to DuckDB.

Run:

```bash
uv run dbt debug --profiles-dir .
```

Checkpoint:

- [ ] dbt uses `profiles.yml` from the project root.
- [ ] The adapter is `duckdb`.
- [ ] The database path is `my_database.duckdb`.
- [ ] The connection test passes.

If this fails, fix the connection before writing models.

---

## Exercise 3: Register Raw Tables as dbt Sources

**Goal:** Make dbt aware of the raw DuckDB tables.

Open:

```text
models/sources.yml
```

Make sure it contains one source named `raw`, using schema `main`, with all 14 raw tables listed:

```yaml
version: 2

sources:
  - name: raw
    schema: main
    tables:
      - name: categories
      - name: customer_addresses
      - name: customers
      - name: inventory
      - name: marketing_campaigns
      - name: order_items
      - name: orders
      - name: payments
      - name: products
      - name: returns
      - name: reviews
      - name: shipping
      - name: suppliers
      - name: website_sessions
```

Verify that dbt can see the sources:

```bash
uv run dbt ls --select source:* --profiles-dir .
```

Checkpoint:

- [ ] `dbt ls` returns 14 sources.
- [ ] Every source is named like `source:dbt_ie.raw.<table_name>`.

---

## Exercise 4: Inspect the Raw Schemas

**Goal:** Understand the columns before writing staging models.

Run a few examples:

```bash
duckdb my_database.duckdb -c "describe customers"
duckdb my_database.duckdb -c "describe orders"
duckdb my_database.duckdb -c "describe order_items"
```

Then inspect the remaining tables:

```bash
duckdb my_database.duckdb -c "describe products"
duckdb my_database.duckdb -c "describe categories"
duckdb my_database.duckdb -c "describe payments"
```

Checkpoint:

- [ ] You can identify the likely primary key for each table.
- [ ] You can identify foreign keys like `customer_id`, `order_id`, `product_id`, and `supplier_id`.
- [ ] You have noted which date columns are currently strings.

---

## Exercise 5: Build the First Staging Model

**Goal:** Build one clean staging model from a dbt source.

Open:

```text
models/staging/stg_customers.sql
```

It should read from the source, not directly from `main.customers`:

```sql
select
    customer_id,
    first_name,
    last_name,
    email,
    country,
    customer_segment
from {{ source('raw', 'customers') }}
```

Build it:

```bash
uv run dbt build --select stg_customers --profiles-dir .
```

Inspect the compiled SQL:

```bash
sed -n '1,120p' target/compiled/dbt_ie/models/staging/stg_customers.sql
```

Checkpoint:

- [ ] `stg_customers` builds successfully.
- [ ] The model uses `{{ source('raw', 'customers') }}`.
- [ ] The compiled SQL points to the DuckDB `main.customers` table.

---

## Exercise 6: Create the Remaining Staging Models

**Goal:** Create one staging model per raw source table.

Create these files under `models/staging/`:

```text
stg_categories.sql
stg_customer_addresses.sql
stg_inventory.sql
stg_marketing_campaigns.sql
stg_order_items.sql
stg_orders.sql
stg_payments.sql
stg_products.sql
stg_returns.sql
stg_reviews.sql
stg_shipping.sql
stg_suppliers.sql
stg_website_sessions.sql
```

Keep `stg_customers.sql` as the existing customer staging model.

Use this pattern for each file:

```sql
select
    *
from {{ source('raw', '<source_table_name>') }}
```

Examples:

```sql
-- models/staging/stg_orders.sql
select
    *
from {{ source('raw', 'orders') }}
```

```sql
-- models/staging/stg_order_items.sql
select
    *
from {{ source('raw', 'order_items') }}
```

```sql
-- models/staging/stg_website_sessions.sql
select
    *
from {{ source('raw', 'website_sessions') }}
```

Checkpoint:

- [ ] There are 14 staging SQL files.
- [ ] Each staging model maps 1:1 to one source table.
- [ ] Every staging model uses `source()`, not a hardcoded table name.
- [ ] There are no joins.
- [ ] There are no aggregations.

---

## Exercise 7: Build the Full Staging Layer

**Goal:** Confirm every staging model compiles and runs.

Run:

```bash
uv run dbt build --select staging --profiles-dir .
```

List the active dbt nodes:

```bash
uv run dbt ls --select staging --profiles-dir .
```

Checkpoint:

- [ ] dbt finds all 14 staging models.
- [ ] `dbt build --select staging` completes successfully.
- [ ] All staging models are created as views unless explicitly configured otherwise.

---

## Exercise 8: Add Basic Staging Tests

**Goal:** Add first-pass data tests for staging primary keys.

Create:

```text
models/staging/_staging__models.yml
```

Start with this structure:

```yaml
version: 2

models:
  - name: stg_customers
    columns:
      - name: customer_id
        tests:
          - unique
          - not_null

  - name: stg_orders
    columns:
      - name: order_id
        tests:
          - unique
          - not_null

  - name: stg_order_items
    columns:
      - name: order_item_id
        tests:
          - unique
          - not_null
```

Then add the remaining likely primary keys:

| Staging model | Primary key to test |
| --- | --- |
| `stg_categories` | `category_id` |
| `stg_customer_addresses` | `address_id` |
| `stg_inventory` | composite grain: `product_id`, `warehouse` |
| `stg_marketing_campaigns` | `campaign_id` |
| `stg_payments` | `payment_id` |
| `stg_products` | `product_id` |
| `stg_returns` | `return_id` |
| `stg_reviews` | `review_id` |
| `stg_shipping` | `order_id` |
| `stg_suppliers` | `supplier_id` |
| `stg_website_sessions` | `session_id` |

For `stg_inventory`, do not add `unique` to `product_id` alone because the table is at product plus warehouse grain. For now, add `not_null` to both `product_id` and `warehouse`.

Run:

```bash
uv run dbt test --select staging --profiles-dir .
```

Checkpoint:

- [ ] Every staging model has at least one basic test.
- [ ] Primary keys have `unique` and `not_null` where the grain supports it.
- [ ] `stg_inventory` has `not_null` tests on both grain columns.
- [ ] Staging tests pass, or any failures are documented with the reason.

---

## Exercise 9: Final Staging Check

**Goal:** Stop at a clean, complete staging layer.

Run:

```bash
uv run dbt build --select staging --profiles-dir .
```

Then run:

```bash
uv run dbt ls --profiles-dir .
```

Expected project shape at this checkpoint:

- 14 raw sources.
- 14 staging models.
- Seeds are optional for this exercise set; they are not needed to complete staging.
- Intermediate models are out of scope for this exercise set.
- Mart models are out of scope for this exercise set.

Final checkpoint:

- [ ] Raw data is loaded into DuckDB.
- [ ] dbt can connect to DuckDB.
- [ ] Sources are declared in `models/sources.yml`.
- [ ] Every source has a `stg_*` model.
- [ ] Staging models build successfully.
- [ ] Basic staging tests exist and pass or have known, explained failures.

Stop here.
