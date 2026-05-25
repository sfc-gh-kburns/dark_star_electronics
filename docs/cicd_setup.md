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

## 3. Repository-level secrets — NOT NEEDED

Earlier versions of these workflows fell back to repo-level secrets for the PR plan job. As of `b2c35de`, every job in every workflow declares `environment: dev|test|prod`, so **repo-level secrets are not used**.

If you previously added them, you can delete them: **Settings → Secrets and variables → Actions → Repository secrets**, remove all five `SNOWFLAKE_*` entries. Cleaner security posture (no idle DEV-deployer key sitting at repo scope).

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

**A. Allowlist GitHub-hosted runner ranges** — fully automated via a Snowflake task

A self-refreshing implementation lives in [`sql/network_policy/github_actions_network_policy.sql`](../sql/network_policy/github_actions_network_policy.sql). It creates everything in `CODE_DB.INTEGRATIONS`:

| Object | Purpose |
|---|---|
| `NETWORK RULE GITHUB_API_EGRESS` | lets the procedure call `api.github.com` |
| `EXTERNAL ACCESS INTEGRATION GITHUB_API_ACCESS` | wraps the egress rule |
| `NETWORK RULE GITHUB_ACTIONS_RUNNERS` | the ingress allowlist (auto-populated) |
| `NETWORK POLICY GITHUB_ACTIONS_POLICY` | what gets attached to users |
| `PROCEDURE REFRESH_GITHUB_ACTIONS_IPS()` | fetches `api.github.com/meta`, parses `.actions`, replaces the rule's `VALUE_LIST` |
| `TASK TASK_REFRESH_GITHUB_ACTIONS_IPS` | runs the procedure daily at 08:00 UTC (created **suspended**) |

**Run once** (as `ACCOUNTADMIN`):

```bash
snow sql -f sql/network_policy/github_actions_network_policy.sql -c kb_demo
```

The script also runs `CALL REFRESH_GITHUB_ACTIONS_IPS()` once and attaches `GITHUB_ACTIONS_POLICY` to all three deployer users — so the pipeline is unblocked the moment it finishes.

**Resume the daily refresh task when you're ready:**

```sql
ALTER TASK CODE_DB.INTEGRATIONS.TASK_REFRESH_GITHUB_ACTIONS_IPS RESUME;
```

**Manual refresh anytime:**

```sql
CALL CODE_DB.INTEGRATIONS.REFRESH_GITHUB_ACTIONS_IPS();
```

**To remove later** (e.g., switching to self-hosted runners):

```sql
ALTER USER DCM_DEPLOYER_DEV  UNSET NETWORK_POLICY;
ALTER USER DCM_DEPLOYER_TEST UNSET NETWORK_POLICY;
ALTER USER DCM_DEPLOYER_PROD UNSET NETWORK_POLICY;
DROP TASK             CODE_DB.INTEGRATIONS.TASK_REFRESH_GITHUB_ACTIONS_IPS;
DROP PROCEDURE        CODE_DB.INTEGRATIONS.REFRESH_GITHUB_ACTIONS_IPS();
DROP NETWORK POLICY   GITHUB_ACTIONS_POLICY;
DROP NETWORK RULE     CODE_DB.INTEGRATIONS.GITHUB_ACTIONS_RUNNERS;
DROP EXTERNAL ACCESS INTEGRATION GITHUB_API_ACCESS;
DROP NETWORK RULE     CODE_DB.INTEGRATIONS.GITHUB_API_EGRESS;
```

**B. Self-hosted runners on a known IP** (recommended long-term)
- Run a small VM (e.g. EC2/Azure VM) inside your network with a static egress IP.
- Add **only that IP** to the Snowflake network policy.
- Far smaller attack surface.

**Quick interim**: ask your account admin to attach the `EXISTING_NETWORK_POLICY` to a less-restrictive variant for the three deployer users only, or temporarily remove network policy enforcement for those service users while you finalize the long-term plan.
