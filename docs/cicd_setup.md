# GitHub Actions — Setup Instructions

This page tells you exactly what to click in the GitHub UI so the CI/CD workflows run.

> The **Snowflake-side setup is already done** (deployer users, roles, ownership, key-pairs registered). What's left is purely GitHub configuration — secrets, Environments, and branch protection.

---

## 1. Create three GitHub Environments

Go to **Settings → Environments → New environment** and create:

| Environment | Required reviewers | Deployment branch rule |
| --- | --- | --- |
| `dev` | none | `main` only |
| `test` | none | `main` only |
| `prod` | **1 (yourself)** | `main` only |

For `prod`, also enable an optional **wait timer** (e.g., 5 minutes) for a fast-rollback window.

---

## 2. Add **Environment** secrets

For **each** of the three environments (`dev`, `test`, `prod`), add the following secrets in the Environment's "Environment secrets" section.

Fixed values (same across all envs):
| Secret | Value |
|---|---|
| `SNOWFLAKE_ACCOUNT` | `SFSENORTHAMERICA-DEMO462` |

Per-environment values:

### `dev`
| Secret | Value |
|---|---|
| `SNOWFLAKE_USER` | `DCM_DEPLOYER_DEV` |
| `SNOWFLAKE_ROLE` | `DCM_DEPLOYER_DEV_ROLE` |
| `SNOWFLAKE_WAREHOUSE` | `DARK_STAR_DEV_WH` |
| `SNOWFLAKE_PRIVATE_KEY` | **paste the entire contents of `keys/dcm_deployer_dev.p8`** (including the BEGIN/END lines) |

### `test`
| Secret | Value |
|---|---|
| `SNOWFLAKE_USER` | `DCM_DEPLOYER_TEST` |
| `SNOWFLAKE_ROLE` | `DCM_DEPLOYER_TEST_ROLE` |
| `SNOWFLAKE_WAREHOUSE` | `DARK_STAR_TEST_WH` |
| `SNOWFLAKE_PRIVATE_KEY` | **paste contents of `keys/dcm_deployer_test.p8`** |

### `prod`
| Secret | Value |
|---|---|
| `SNOWFLAKE_USER` | `DCM_DEPLOYER_PROD` |
| `SNOWFLAKE_ROLE` | `DCM_DEPLOYER_PROD_ROLE` |
| `SNOWFLAKE_WAREHOUSE` | `DARK_STAR_PROD_WH` |
| `SNOWFLAKE_PRIVATE_KEY` | **paste contents of `keys/dcm_deployer_prod.p8`** |

> The `dcm_plan.yml` workflow runs **without** an `environment:` block (it's read-only on PRs), so add the same five `SNOWFLAKE_*` secrets at the **repo-level** as well (Settings → Secrets and variables → Actions → Secrets → New repository secret), pointing at the **DEV deployer** (least privilege for plan).

---

## 3. Branch protection on `main`

Settings → Branches → Add rule for `main`:

- ☑ Require a pull request before merging
- ☑ Require approvals (1)
- ☑ Require status checks to pass before merging
  - Required checks (after the first successful run, you'll see them in the dropdown):
    - `snow dcm plan (DEV)`
    - `snow dcm plan (TEST)`
    - `snow dcm plan (PROD)`
- ☑ Require linear history
- ☑ Do not allow bypassing the above settings

---

## 4. After secrets are saved

1. Commit and push these workflow files (we'll do this from the CLI).
2. Open a small no-op PR (e.g., add a comment to `README.md`) to trigger `dcm_plan.yml` and verify the matrix runs cleanly across DEV/TEST/PROD.
3. Merge to `main` → DEV deploys → TEST deploys → PROD waits for your approval in the **Actions** tab.

---

## 5. Sanity check — smoke test from your laptop

We already verified each deployer works:

```bash
SNOWFLAKE_PRIVATE_KEY_PATH=keys/dcm_deployer_dev.p8 \
  snow dcm plan CODE_DB.DCM.DARK_STAR_PROJECT_DEV \
  --target DEV --user DCM_DEPLOYER_DEV --role DCM_DEPLOYER_DEV_ROLE \
  --warehouse DARK_STAR_DEV_WH --account SFSENORTHAMERICA-DEMO462 \
  --authenticator SNOWFLAKE_JWT --temporary-connection --save-output
```

Identical commands with `_test` and `_prod` keys also work — done during setup.

---

## 6. Key safekeeping

The `keys/` directory is **already in `.gitignore`**. After you've copied the private keys into GitHub secrets:

```bash
# Optional: move keys to a secure long-term store
mv keys/ ~/secure-vault/dark_star_keys/
```

If you ever need to rotate, regenerate with:
```bash
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out new.p8 -nocrypt
openssl rsa -in new.p8 -pubout -out new.pub
# Then ALTER USER ... SET RSA_PUBLIC_KEY = '...';
```
