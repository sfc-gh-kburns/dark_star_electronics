# Dark Star Electronics — DCM Foundation Plan

## Goals
1. DCM project deployable to **DEV / TEST / PROD** via Jinja templating
2. **Persona roles** per environment: Admin, Engineer, Analyst, Loader, Data Scientist
3. Starter **dim/fact retail data model**
4. **GitHub integration** scoped as a follow-up

---

## 1. DCM Project Identifier

- Project: `SANDBOX.KB.DARK_STAR_PROJECT`
- Parent `SANDBOX.KB` already exists (current connection schema). Cannot `DEFINE` these.
- Three targets share one account but each has a **unique `project_name`** to avoid overwrite:
  - `DARK_STAR_PROJECT_DEV`
  - `DARK_STAR_PROJECT_TEST`
  - `DARK_STAR_PROJECT_PROD`

> Note: When ready for true env isolation, swap `account_identifier` per target. For now we use one account with separate databases.

---

## 2. Directory Structure

```
DarkStarElectronics/
├── manifest.yml
├── README.md
├── .gitignore                 (out/, __pycache__/, *.pyc)
└── sources/
    ├── definitions/
    │   ├── 00_infrastructure.sql   # databases, schemas, warehouses
    │   ├── 10_access.sql           # roles + grants
    │   ├── 20_dimensions.sql       # dim_* tables
    │   ├── 30_facts.sql            # fact_* tables
    │   └── 40_views.sql            # serve-layer views
    └── macros/
        └── persona_grants.sql      # macro for repeated role grant patterns
```

---

## 3. manifest.yml (sketch)

```yaml
manifest_version: 2
type: DCM_PROJECT
default_target: 'DEV'

targets:
  DEV:
    account_identifier: SFSENORTHAMERICA-DEMO462
    project_name: 'SANDBOX.KB.DARK_STAR_PROJECT_DEV'
    project_owner: ACCOUNTADMIN
    templating_config: 'DEV'
  TEST:
    account_identifier: SFSENORTHAMERICA-DEMO462
    project_name: 'SANDBOX.KB.DARK_STAR_PROJECT_TEST'
    project_owner: ACCOUNTADMIN
    templating_config: 'TEST'
  PROD:
    account_identifier: SFSENORTHAMERICA-DEMO462
    project_name: 'SANDBOX.KB.DARK_STAR_PROJECT_PROD'
    project_owner: ACCOUNTADMIN
    templating_config: 'PROD'

templating:
  defaults:
    env: 'DEV'
    db_name: 'DARK_STAR_DEV'
    wh_size: 'XSMALL'
    wh_auto_suspend: 60
    retention_days: 1
  configurations:
    DEV:
      env: 'DEV'
      db_name: 'DARK_STAR_DEV'
      wh_size: 'XSMALL'
      wh_auto_suspend: 60
      retention_days: 1
    TEST:
      env: 'TEST'
      db_name: 'DARK_STAR_TEST'
      wh_size: 'SMALL'
      wh_auto_suspend: 120
      retention_days: 3
    PROD:
      env: 'PROD'
      db_name: 'DARK_STAR_PROD'
      wh_size: 'MEDIUM'
      wh_auto_suspend: 300
      retention_days: 7
```

---

## 4. Infrastructure (00_infrastructure.sql)

- `DEFINE DATABASE {{ db_name }}` (DEV/TEST/PROD swap via Jinja)
- Schemas: `RAW`, `STAGING`, `ANALYTICS`, `SERVE`
- Warehouse: `DEFINE WAREHOUSE DARK_STAR_{{ env }}_WH WITH WAREHOUSE_SIZE='{{ wh_size }}' AUTO_SUSPEND={{ wh_auto_suspend }} AUTO_RESUME=TRUE INITIALLY_SUSPENDED=TRUE`

---

## 5. Roles & Grants (10_access.sql)

**Per-env database roles** (auto-scoped to `{{ db_name }}`):
- `{{ db_name }}.ADMIN` — DDL + full DML
- `{{ db_name }}.ENGINEER` — DML on RAW/STAGING/ANALYTICS, SELECT on SERVE
- `{{ db_name }}.ANALYST` — SELECT on SERVE/ANALYTICS only
- `{{ db_name }}.LOADER` — INSERT/UPDATE on RAW only (service)
- `{{ db_name }}.DATA_SCIENTIST` — SELECT all + CREATE in ANALYTICS

**Account roles** (warehouse access — required, db roles can't hold WH grants):
- `DARK_STAR_{{ env }}_WAREHOUSE_USER` — `USAGE ON WAREHOUSE DARK_STAR_{{ env }}_WH`

**Hierarchy**: ANALYST ⊂ DATA_SCIENTIST ⊂ ENGINEER ⊂ ADMIN; LOADER standalone; ADMIN → SYSADMIN.

A Jinja macro `persona_grants(db, schema)` will fan out the per-schema USAGE/SELECT/etc. grants to avoid repetition across the four schemas.

---

## 6. Starter Dim/Fact Model

**Dimensions** (`{{ db_name }}.ANALYTICS.*`):
- `DIM_CUSTOMER` (customer_key, customer_id, name, email, segment, address, city, state, postal_code, country, signup_date)
- `DIM_PRODUCT` (product_key, sku, name, category, subcategory, brand, unit_cost, list_price)
- `DIM_STORE` (store_key, store_id, name, type [online/physical], region, city, state, country)
- `DIM_DATE` (date_key, date, day, month, quarter, year, day_of_week, is_weekend, is_holiday)
- `DIM_EMPLOYEE` (employee_key, employee_id, name, role, store_key, hire_date)

**Facts**:
- `FACT_SALES` (sale_key, date_key, customer_key, product_key, store_key, employee_key, order_id, quantity, unit_price, discount_amount, tax_amount, total_amount)
- `FACT_INVENTORY` (snapshot_date_key, product_key, store_key, on_hand_qty, on_order_qty, reorder_point)
- `FACT_RETURNS` (return_key, sale_key, date_key, product_key, customer_key, return_reason, refund_amount)

All keys `NUMBER`, descriptive cols `VARCHAR`, monetary `NUMBER(12,2)`. `CHANGE_TRACKING = TRUE` on facts. `DATA_RETENTION_TIME_IN_DAYS = {{ retention_days }}`.

**Serve layer views (40_views.sql)**: `VW_DAILY_SALES`, `VW_PRODUCT_PERFORMANCE`, `VW_INVENTORY_SNAPSHOT`.

---

## 7. Validation

1. `snow dcm create SANDBOX.KB.DARK_STAR_PROJECT_DEV -c default`
   (and `_TEST`, `_PROD`)
2. `snow dcm raw-analyze SANDBOX.KB.DARK_STAR_PROJECT_DEV -c default --target DEV` — read output, fix any errors
3. `snow dcm plan SANDBOX.KB.DARK_STAR_PROJECT_DEV -c default --target DEV --save-output` — review `out/plan/plan_result.json`
4. **Stop and present plan to user** — do not deploy without explicit approval

---

## 8. GitHub Integration (Follow-up)

Deferred. After foundation is approved we'll set up either:
- `snow git` integration with a Snowflake `GIT REPOSITORY` object pointing at this repo, OR
- GitHub Actions workflow running `snow dcm plan/deploy` on push to main (with separate workflow per target)

---

## Open Items / Confirmations Needed Before Implementation

1. Confirm connection name to use (default appears to be `default`/current). Will use the active connection.
2. Confirm I should `snow dcm create` all three project objects up front (vs. just DEV).
3. Confirm `ACCOUNTADMIN` as `project_owner` is acceptable for now (production typically uses a dedicated deployer role).
4. After plan is approved, switch back to agent mode to implement.