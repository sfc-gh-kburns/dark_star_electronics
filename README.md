# Dark Star Electronics — DCM Project

Snowflake infrastructure-as-code for a fictional retailer, managed via **DCM (Database Change Management)** with a multi-environment GitHub Actions CI/CD pipeline.

## Layout

```
DarkStarElectronics/
├── manifest.yml                       # DEV / TEST / PROD targets + Jinja templating
├── sources/
│   ├── definitions/                   # 00_infrastructure → 40_views
│   └── macros/persona_grants.sql      # reusable per-schema grant macro
├── .github/workflows/                 # plan (PR), deploy DEV/TEST/PROD, drift
├── sql/network_policy/                # GitHub Actions IP allowlist + auto-refresh
└── docs/                              # development log + HTML recap
```

## Environments

| Target | Database         | Warehouse           | Size   | Retention |
| ------ | ---------------- | ------------------- | ------ | --------- |
| DEV    | `DARK_STAR_DEV`  | `DARK_STAR_DEV_WH`  | XSMALL | 1 day     |
| TEST   | `DARK_STAR_TEST` | `DARK_STAR_TEST_WH` | SMALL  | 3 days    |
| PROD   | `DARK_STAR_PROD` | `DARK_STAR_PROD_WH` | MEDIUM | 7 days    |

DCM project objects live at `CODE_DB.DCM.DARK_STAR_PROJECT_<ENV>`.

## Personas (per environment)

Database roles scoped to the env database: `ADMIN`, `ENGINEER`, `ANALYST`, `LOADER`, `DATA_SCIENTIST`.
Account role `DARK_STAR_<ENV>_WAREHOUSE_USER` holds the warehouse `USAGE` grant (database roles can't).

## CI/CD

- **PR → `main`**: `dcm_plan.yml` runs analyze + plan against all three targets and posts a summary comment.
- **Merge → `main`**: `dcm_deploy_dev.yml` deploys DEV → on success, TEST → on success, PROD.
- **Daily**: `dcm_drift.yml` runs plan against PROD and opens an issue on drift.
- Each target uses its own service user + key-pair JWT, scoped via GitHub Environments.

See `docs/cicd_setup.md` for setup details.

## Common Commands

```bash
snow dcm plan   CODE_DB.DCM.DARK_STAR_PROJECT_DEV -c <conn> --target DEV --save-output
snow dcm deploy CODE_DB.DCM.DARK_STAR_PROJECT_DEV -c <conn> --target DEV --alias "v0.1.0"
```

Swap `_DEV` / `--target DEV` for `TEST` or `PROD`.

## Notes

This is a demo / reference project. Service-user keys are not committed (see `.gitignore`); secrets live in GitHub Environments and Snowflake.
