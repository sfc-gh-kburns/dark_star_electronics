# Dark Star Electronics — Development Log

A running journal of every meaningful development task on this repo: **what** was done, **why**, and the **outcome**. Designed to double as raw material for future presentations.

> **Update protocol:** Append a new dated entry whenever a feature, design decision, deployment, or fix occurs. Don't edit history — append corrections as new entries.

---

## Entry Template

```
### YYYY-MM-DD — <Short Title>
**Task:** What was attempted.
**Why:** Business / technical motivation.
**How:** Tools, commands, or files touched.
**Outcome:** Result, metrics, artifacts.
**Notes / Decisions:** Tradeoffs, follow-ups, gotchas.
```

---

## 2026-05-22 — Project kickoff & DCM foundation

**Task:** Stand up the initial Snowflake implementation for Dark Star Electronics (a fictional electronics retailer) using DCM (Database Change Management) as the IaC layer.

**Why:** We need a Snowflake-best-practice foundation that supports separate DEV / TEST / PROD environments, persona-based access control, and a starter retail star schema — all version-controlled in this Git repo so we can iterate safely.

**How:**
- Snowflake CLI 3.18.0 against connection `kb_demo` (account `SFSENORTHAMERICA-DEMO462`).
- Project objects created: `SANDBOX.KB.DARK_STAR_PROJECT_{DEV,TEST,PROD}` (initial), then migrated.
- Authored: `manifest.yml`, `sources/definitions/00_infrastructure.sql`, `10_access.sql`, `20_dimensions.sql`, `30_facts.sql`, `40_views.sql`, `sources/macros/persona_grants.sql`, `.gitignore`, `README.md`.
- Validated with `snow dcm raw-analyze` and previewed with `snow dcm plan --save-output`.

**Outcome:**
- DCM project objects registered for all three environments.
- 24 entities planned per env (23 CREATE + 1 ALTER on SYSADMIN, 0 DROP).
- Analyze passed with zero errors.

**Notes / Decisions:**
- **Per-env separate databases** chosen over single-DB-with-suffixed-objects for cleaner isolation and SHOW-friendly listings.
- **Database roles** for personas (scoped to env DB lifecycle) + a single **account role** `DARK_STAR_<ENV>_WAREHOUSE_USER` to hold warehouse `USAGE` (DCM/Snowflake constraint: db roles cannot hold warehouse grants).
- **Five personas**: ADMIN, ENGINEER, ANALYST, LOADER, DATA_SCIENTIST. Hierarchy: ANALYST ⊂ DATA_SCIENTIST, ANALYST ⊂ ENGINEER ⊂ ADMIN; LOADER standalone; ADMIN → SYSADMIN.
- **Per-env warehouse sizing** via Jinja: XSMALL (DEV) → SMALL (TEST) → MEDIUM (PROD), with retention 1/3/7 days respectively.
- **Macro `persona_grants`** lives under `sources/macros/` so it's auto-imported (DCM does not support Jinja `{% from ... import %}` to a file).
- Star schema chosen as the entry-point model (5 dims, 3 facts, 3 SERVE views) — easy to extend with dynamic tables / tasks later.

---

## 2026-05-22 — Move DCM project objects to `CODE_DB.DCM`

**Task:** Relocate the three DCM project objects from `SANDBOX.KB` to `CODE_DB.DCM`.

**Why:** `SANDBOX.KB` is a personal scratch schema; project objects belong in a curated `CODE_DB.DCM` schema so they're discoverable and managed centrally alongside other DCM projects.

**How:**
- Verified `CODE_DB.DCM` schema exists.
- Created new project objects: `snow dcm create CODE_DB.DCM.DARK_STAR_PROJECT_{DEV,TEST,PROD}`.
- Edited `manifest.yml` to point each target's `project_name` at the new location.
- Re-ran `snow dcm raw-analyze --target DEV` to confirm validity.

**Outcome:** Three new DCM projects registered, manifest updated, analyze still clean. Old `SANDBOX.KB.DARK_STAR_PROJECT_*` objects remain (orphaned) — pending decision to drop.

**Notes / Decisions:**
- Project objects are lightweight (metadata only). Renaming is not supported, so we recreated under the new schema.
- Follow-up: drop the orphaned `SANDBOX.KB.*` projects once we're sure nothing references them.

---

## 2026-05-22 — Suppress Native-App manifest YAML schema warning

**Task:** Silence a false-positive editor warning ("Missing property `artifacts`") on `manifest.yml`.

**Why:** VS Code's YAML extension was matching against the **Snowflake Native Application Package** schema, not the DCM project manifest schema — they're different formats.

**How:** Added `# yaml-language-server: $schema=` directive at the top of `manifest.yml` to disable schema validation for that file.

**Outcome:** Editor warning cleared. DCM tooling unaffected (it ignores comments).

**Notes / Decisions:** Alternative was to scope `yaml.schemas` ignore in VS Code settings — chose the inline comment so the fix travels with the repo.

---

## 2026-05-22 — Initial deployment to DEV / TEST / PROD (alias `v0.1.0`)

**Task:** Deploy the foundation to all three environments.

**Why:** Validate that the IaC produces real, identical infrastructure across envs and unblock downstream work (data loading, dbt models, BI).

**How:**
```bash
snow dcm deploy CODE_DB.DCM.DARK_STAR_PROJECT_DEV  -c kb_demo --target DEV  --alias v0.1.0
snow dcm deploy CODE_DB.DCM.DARK_STAR_PROJECT_TEST -c kb_demo --target TEST --alias v0.1.0
snow dcm deploy CODE_DB.DCM.DARK_STAR_PROJECT_PROD -c kb_demo --target PROD --alias v0.1.0
```

**Outcome:** Each env: **23 created, 1 altered (SYSADMIN), 0 dropped**. All three databases now exist with 4 schemas (RAW / STAGING / ANALYTICS / SERVE), 5 dim tables, 3 fact tables, 3 SERVE views, 5 db roles + 1 account role, and a per-env warehouse.

**Notes / Decisions:**
- Used `--alias v0.1.0` on every deploy so we can roll back / audit by tag.
- The single ALTER on SYSADMIN is from `GRANT ROLE ... TO ROLE SYSADMIN` for the warehouse-access account role and the env ADMIN db role — expected and idempotent.
- DEV/TEST/PROD all live on the **same** Snowflake account today; true isolation (separate accounts) can be enabled later by changing each target's `account_identifier`.

---

## 2026-05-22 — Add development log (this file)

**Task:** Create `docs/` folder and `docs/development_log.md` to track every task, outcome, and rationale.

**Why:** Maintain an authoritative project history for continuity (across context resets) and to feed future presentations / customer share-outs.

**How:** New folder + this file.

**Outcome:** `docs/development_log.md` in place with template + back-filled entries from project kickoff onward.

**Notes / Decisions:** Append-only entries, dated, using the template at the top. Code/SQL artifacts are referenced by path rather than copied in to keep the log readable.

---

## 2026-05-22 — Drop orphaned `SANDBOX.KB` DCM projects

**Task:** Remove the original `SANDBOX.KB.DARK_STAR_PROJECT_{DEV,TEST,PROD}` objects.

**Why:** They were superseded when we relocated the canonical projects to `CODE_DB.DCM`. Keeping unused project objects around is clutter and risks accidental deploys to the wrong target.

**How:**
```bash
snow dcm drop SANDBOX.KB.DARK_STAR_PROJECT_DEV  -c kb_demo
snow dcm drop SANDBOX.KB.DARK_STAR_PROJECT_TEST -c kb_demo
snow dcm drop SANDBOX.KB.DARK_STAR_PROJECT_PROD -c kb_demo
```

**Outcome:** All three dropped successfully. `CODE_DB.DCM.DARK_STAR_PROJECT_*` remain as the only source of truth.

**Notes / Decisions:** Drop only removes the DCM project metadata — the deployed databases, roles, and warehouses created earlier from `CODE_DB.DCM` are unaffected.

---

## 2026-05-22 — GitHub integration foundation

**Task:** Wire the project to a private GitHub repo on both sides — Snowflake `GIT REPOSITORY` object backed by a PAT secret, plus initial push of local source, plus a PR-only GitHub Actions plan workflow.

**Why:** Source-of-truth in Git enables PR review, history, rollback, and CI/CD. The Snowflake `GIT REPOSITORY` makes the same source available inside Snowsight (useful for Streamlit-in-Snowflake / notebooks later). Read-only PR plans give us a safety net before any merge touches infrastructure.

**How:**
- Created `CODE_DB.INTEGRATIONS` schema (already existed).
- Created account-level `GITHUB_API_INTEGRATION` (provider `GIT_HTTPS_API`, prefix `https://github.com/sfc-gh-kburns/`) and authorized the secret via `ALLOWED_AUTHENTICATION_SECRETS`.
- User created `CODE_DB.INTEGRATIONS.GITHUB_PAT_DARKSTAR` as `TYPE = PASSWORD`, username `sfc-gh-kburns` (an earlier `GENERIC_STRING` secret was rejected by `GIT REPOSITORY`).
- Created `CODE_DB.INTEGRATIONS.GITHUB_DARK_STAR` GIT REPOSITORY pointing at `https://github.com/sfc-gh-kburns/dark_star_electronics.git`. First clone failed (PAT scope/auth); succeeded after user re-authorized the PAT.
- `git remote add origin ... && git pull --rebase --allow-unrelated-histories && git push -u origin main` — initial commit `cd0842c`, on `origin/main` after rebase as `82359ed`.
- Added `.github/workflows/dcm_plan.yml`: matrix over DEV/TEST/PROD running `raw-analyze` + `plan --save-output`, uploads `out/plan/` as artifact. Triggers: `pull_request` on `main`, `workflow_dispatch`.

**Outcome:**
- `SHOW GIT BRANCHES IN CODE_DB.INTEGRATIONS.GITHUB_DARK_STAR` returns `main` at `82359ed…` ✅
- Local repo pushed to GitHub.
- CI workflow committed; will start running once required secrets are added.

**Notes / Decisions:**
- `GIT REPOSITORY` requires `TYPE = PASSWORD` secrets — `GENERIC_STRING` is rejected. Worth noting for future onboardings.
- Authentication is a PAT today. Eventually we'll move to a dedicated `DCM_DEPLOYER` Snowflake user with key-pair auth used by Actions, and an OAuth/app-token approach for Snowflake → GitHub if needed.
- CI is **read-only** by design (no deploy yet). Auto-deploy DEV / approved PROD deploys are explicit follow-ups.

**Required GitHub repo secrets** (Settings → Secrets and variables → Actions → New repository secret):

| Secret | Value |
| --- | --- |
| `SNOWFLAKE_ACCOUNT` | `SFSENORTHAMERICA-DEMO462` |
| `SNOWFLAKE_USER` | `kburns` (interim; replace with `DCM_DEPLOYER` later) |
| `SNOWFLAKE_PASSWORD` | (account password / will swap for `SNOWFLAKE_PRIVATE_KEY`) |
| `SNOWFLAKE_ROLE` | `ACCOUNTADMIN` (interim; tighten later) |
| `SNOWFLAKE_WAREHOUSE` | `D4B_WH` |

Verify the workflow:
```bash
# After secrets are added, push a trivial branch and open a PR — Actions tab will show three matrix jobs.
```

---

## Open Items (Backlog)

- [x] Drop orphaned `SANDBOX.KB.DARK_STAR_PROJECT_{DEV,TEST,PROD}` projects. *(2026-05-22)*
- [x] **GitHub integration** — Snowflake `GIT REPOSITORY` + initial push + PR-plan workflow. *(2026-05-22)*
- [ ] Add the five required GitHub repo secrets so the `DCM Plan (PR)` workflow can run.
- [ ] Create dedicated `DCM_DEPLOYER` Snowflake user + role (key-pair auth) for CI; rotate workflow secrets to use it.
- [ ] Add auto-deploy DEV workflow on merge to `main`.
- [ ] Add `workflow_dispatch` PROD deploy with required reviewer.
- [ ] Add seed/sample data loaders for DIM/FACT tables (likely Snowpark or COPY INTO from a public stage).
- [ ] Layer in dynamic tables for STAGING → ANALYTICS transformations.
- [ ] Add data quality expectations (`ATTACH DATA METRIC FUNCTION`) on critical fact columns.
- [ ] Define users and assign persona roles per environment (currently only roles exist).
- [ ] Tag-based masking policies for PII columns in `DIM_CUSTOMER` / `DIM_EMPLOYEE`.
