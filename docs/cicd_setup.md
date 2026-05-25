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

> **Critical: encode the private key as base64 before pasting.** GitHub Actions can mangle multi-line secret values. Encode each key once with `base64 -i keys/dcm_deployer_<env>.p8 | pbcopy`, then paste the resulting single-line string. The workflows decode it back to PEM at runtime via `base64 -d`.

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
| `SNOWFLAKE_PRIVATE_KEY` | output of `base64 -i keys/dcm_deployer_dev.p8 \| pbcopy` (single line) |

### `test`
| Secret | Value |
|---|---|
| `SNOWFLAKE_USER` | `DCM_DEPLOYER_TEST` |
| `SNOWFLAKE_ROLE` | `DCM_DEPLOYER_TEST_ROLE` |
| `SNOWFLAKE_WAREHOUSE` | `DARK_STAR_TEST_WH` |
| `SNOWFLAKE_PRIVATE_KEY` | output of `base64 -i keys/dcm_deployer_test.p8 \| pbcopy` |

### `prod`
| Secret | Value |
|---|---|
| `SNOWFLAKE_USER` | `DCM_DEPLOYER_PROD` |
| `SNOWFLAKE_ROLE` | `DCM_DEPLOYER_PROD_ROLE` |
| `SNOWFLAKE_WAREHOUSE` | `DARK_STAR_PROD_WH` |
| `SNOWFLAKE_PRIVATE_KEY` | output of `base64 -i keys/dcm_deployer_prod.p8 \| pbcopy` |

---

## 3. Add **Repository-level** secrets (REQUIRED — for the PR plan workflow)

The `dcm_plan.yml` workflow runs on PRs without an `environment:` block, so it can **only see repository-level secrets**, not environment ones. Without this step, the PR plan check will fail with `Private key provided is not in PKCS#8 format` (because the secret resolves to empty).

Go to **Settings → Secrets and variables → Actions → Repository secrets → New repository secret** and add the same five secrets, **pointing at the DEV deployer** (least privilege — plan is read-only):

| Secret | Value |
|---|---|
| `SNOWFLAKE_ACCOUNT` | `SFSENORTHAMERICA-DEMO462` |
| `SNOWFLAKE_USER` | `DCM_DEPLOYER_DEV` |
| `SNOWFLAKE_ROLE` | `DCM_DEPLOYER_DEV_ROLE` |
| `SNOWFLAKE_WAREHOUSE` | `DARK_STAR_DEV_WH` |
| `SNOWFLAKE_PRIVATE_KEY` | output of `base64 -i keys/dcm_deployer_dev.p8 \| pbcopy` (same value as the `dev` env secret) |

Direct URL: `https://github.com/sfc-gh-kburns/dark_star_electronics/settings/secrets/actions`

> **Why both?** Environment secrets are scoped to jobs that declare `environment:`. Repository secrets are visible to every workflow. The deploy workflows pull from environments (least-privilege per env). The PR plan workflow falls back to repo-level (DEV credentials only).

---

## 4. Branch protection on `main`

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

## 5. After secrets are saved

1. Commit and push these workflow files (we'll do this from the CLI).
2. Open a small no-op PR (e.g., add a comment to `README.md`) to trigger `dcm_plan.yml` and verify the matrix runs cleanly across DEV/TEST/PROD.
3. Merge to `main` → DEV deploys → TEST deploys → PROD waits for your approval in the **Actions** tab.

---

## 6. Sanity check — smoke test from your laptop

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

## 7. Key safekeeping

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

---

## 8. Network policy / IP allowlist

If your Snowflake account has a network policy that restricts inbound IPs, GitHub Actions runners (Azure-hosted, dynamic IPs) will be blocked with:

```
250001 (08001): Failed to connect to DB: ***.snowflakecomputing.com:443.
Incoming request with IP/Token x.x.x.x is not allowed to access Snowflake.
```

Two production-grade options:

**A. Allowlist GitHub-hosted runner ranges** (simplest, but a large IP range)
- GitHub publishes its runner IP ranges at `https://api.github.com/meta` (the `actions` array).
- Create/extend a `NETWORK_RULE` and attach to the deployer users:
  ```sql
  CREATE NETWORK RULE GITHUB_ACTIONS_RUNNERS
    TYPE = IPV4 MODE = INGRESS
    VALUE_LIST = ('4.x.x.x/16', '20.x.x.x/16', ...);    -- from api.github.com/meta
  ```
  Keep it refreshed on a schedule (GitHub publishes updates).

**B. Self-hosted runners on a known IP** (recommended long-term)
- Run a small VM (e.g. EC2/Azure VM) inside your network with a static egress IP.
- Add **only that IP** to the Snowflake network policy.
- Far smaller attack surface.

**Quick interim**: ask your account admin to attach the `EXISTING_NETWORK_POLICY` to a less-restrictive variant for the three deployer users only, or temporarily remove network policy enforcement for those service users while you finalize the long-term plan.
