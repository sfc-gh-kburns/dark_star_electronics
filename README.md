# Dark Star Electronics — DCM Project

Snowflake infrastructure-as-code for **Dark Star Electronics** (retailer / electronics) managed via **DCM (Database Change Management)**.

## Layout

```
DarkStarElectronics/
├── manifest.yml                       # DEV / TEST / PROD targets + Jinja templating
├── sources/
│   ├── definitions/
│   │   ├── 00_infrastructure.sql      # database, schemas, warehouse
│   │   ├── 10_access.sql              # database roles + warehouse account role
│   │   ├── 20_dimensions.sql          # DIM_DATE / CUSTOMER / PRODUCT / STORE / EMPLOYEE
│   │   ├── 30_facts.sql               # FACT_SALES / INVENTORY / RETURNS
│   │   └── 40_views.sql               # SERVE.VW_* consumption views
│   └── macros/
│       └── persona_grants.sql         # reusable per-schema grant macro
└── .gitignore
```

## Environments

| Target | Database         | Warehouse              | Size     | Retention |
| ------ | ---------------- | ---------------------- | -------- | --------- |
| DEV    | `DARK_STAR_DEV`  | `DARK_STAR_DEV_WH`     | XSMALL   | 1 day     |
| TEST   | `DARK_STAR_TEST` | `DARK_STAR_TEST_WH`    | SMALL    | 3 days    |
| PROD   | `DARK_STAR_PROD` | `DARK_STAR_PROD_WH`    | MEDIUM   | 7 days    |

All environments live in `SANDBOX.KB.DARK_STAR_PROJECT_<ENV>` DCM project objects on the same account; switch accounts later by changing `account_identifier` per target in `manifest.yml`.

## Personas (per environment)

Database roles (scoped to the env database):
- `ADMIN` — full DDL/DML
- `ENGINEER` — RW on RAW/STAGING/ANALYTICS, R on SERVE
- `ANALYST` — read-only on SERVE/ANALYTICS
- `LOADER` — service role: write into RAW only
- `DATA_SCIENTIST` — read-all + CREATE in ANALYTICS

Account role:
- `DARK_STAR_<ENV>_WAREHOUSE_USER` — holds `USAGE ON WAREHOUSE` (database roles can't)

## Common Commands

```bash
# Analyze (validates + dependency/lineage)
snow dcm raw-analyze SANDBOX.KB.DARK_STAR_PROJECT_DEV  -c kb_demo --target DEV

# Plan (preview only — review before deploy)
snow dcm plan SANDBOX.KB.DARK_STAR_PROJECT_DEV -c kb_demo --target DEV --save-output

# Deploy (DESTRUCTIVE — use with --alias for traceability)
snow dcm deploy SANDBOX.KB.DARK_STAR_PROJECT_DEV -c kb_demo --target DEV --alias "v0.1.0"
```

Swap `_DEV` / `--target DEV` for `_TEST` or `_PROD` for the other environments.

## Status

- DCM project objects: **created** in Snowflake (DEV/TEST/PROD)
- Definitions: **authored**
- `raw-analyze` against DEV: **PASSED** (no errors)
- `plan` against DEV: **24 entities — 23 to CREATE, 1 to ALTER (SYSADMIN role), 0 to DROP**
- Deployment: **NOT YET RUN** — pending explicit user approval

## Next Steps

1. Review the plan, then run `snow dcm deploy ... --target DEV --alias <release>` for first deploy.
2. Repeat analyze/plan/deploy for `--target TEST` and `--target PROD`.
3. **GitHub integration (follow-up)** — choose one:
   - **Snowflake `GIT REPOSITORY` integration**: create `API INTEGRATION` for github.com, then `CREATE GIT REPOSITORY` pointing at this repo so DCM commands can run from Snowsight.
   - **GitHub Actions CI/CD**: workflow that runs `snow dcm plan` on PR and `snow dcm deploy` on merge to `main`, with separate jobs/credentials per target.


THE END