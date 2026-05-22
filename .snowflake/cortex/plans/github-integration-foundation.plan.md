# GitHub Integration — Plan

## Context
- Repo: `https://github.com/sfc-gh-kburns/dark_star_electronics.git` (private)
- Snowflake GitHub user: `sfc-gh-kburns`
- Snowflake GIT REPOSITORY FQN: `CODE_DB.INTEGRATIONS.GITHUB_DARK_STAR`
- PAT will be supplied via cortex secret (`github_pat`).
- CI/CD scope (today): **PR plan job for DEV / TEST / PROD only** — no auto-deploy yet.

---

## 1. Snowflake-side objects

### 1a. Schema for integrations
```sql
CREATE SCHEMA IF NOT EXISTS CODE_DB.INTEGRATIONS
  COMMENT = 'API integrations, secrets, and git repositories';
```

### 1b. API integration for github.com
```sql
CREATE OR REPLACE API INTEGRATION GITHUB_API_INTEGRATION
  API_PROVIDER = GIT_HTTPS_API
  API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-kburns/')
  ALLOWED_AUTHENTICATION_SECRETS = ALL
  ENABLED = TRUE
  COMMENT = 'GitHub HTTPS API integration for sfc-gh-kburns repos';
```

### 1c. Secret holding the PAT
```sql
CREATE OR REPLACE SECRET CODE_DB.INTEGRATIONS.GITHUB_PAT
  TYPE = PASSWORD
  USERNAME = 'sfc-gh-kburns'
  PASSWORD = '<from cortex secret github_pat>'
  COMMENT = 'GitHub PAT for cloning private repos into Snowflake';
```

### 1d. GIT REPOSITORY object
```sql
CREATE OR REPLACE GIT REPOSITORY CODE_DB.INTEGRATIONS.GITHUB_DARK_STAR
  API_INTEGRATION = GITHUB_API_INTEGRATION
  GIT_CREDENTIALS = CODE_DB.INTEGRATIONS.GITHUB_PAT
  ORIGIN = 'https://github.com/sfc-gh-kburns/dark_star_electronics.git'
  COMMENT = 'Dark Star Electronics source-of-truth repo';

ALTER GIT REPOSITORY CODE_DB.INTEGRATIONS.GITHUB_DARK_STAR FETCH;
```

### 1e. Verification
```sql
SHOW GIT BRANCHES IN CODE_DB.INTEGRATIONS.GITHUB_DARK_STAR;
LS @CODE_DB.INTEGRATIONS.GITHUB_DARK_STAR/branches/main/;
```

> The PAT will be injected via `secret_env` (`{"PASSWORD": "github_pat"}`) so the value never appears in the conversation or command history.

---

## 2. Local repo → GitHub push

```bash
cd /Users/kburns/Documents/GitHub/DarkStarElectronics
git status                 # confirm clean / show what will commit
git add -A
git commit -m "feat: initial DCM foundation for Dark Star Electronics"
git remote add origin https://github.com/sfc-gh-kburns/dark_star_electronics.git
git branch -M main
git push -u origin main
```

If the remote already exists locally, swap `add` → `set-url`. Push will use the same PAT (configured in your local git credential helper or supplied at prompt).

---

## 3. GitHub Actions — PR plan workflow (seed)

File: `.github/workflows/dcm_plan.yml`

What it does:
- Triggered on `pull_request` against `main`.
- For each target (DEV, TEST, PROD): install Snowflake CLI, configure the connection from GitHub secrets, run `snow dcm raw-analyze` then `snow dcm plan --save-output`.
- Uploads `out/plan/plan_result.json` as a build artifact for review.
- **Read-only** — no deploy yet.

Required GitHub repo secrets (you create these in the repo settings):
- `SNOWFLAKE_ACCOUNT` — `SFSENORTHAMERICA-DEMO462`
- `SNOWFLAKE_USER` — service user (recommend creating a dedicated `DCM_DEPLOYER` user with key-pair auth, but for today this can be `kburns`)
- `SNOWFLAKE_PASSWORD` or `SNOWFLAKE_PRIVATE_KEY` — auth credential
- `SNOWFLAKE_ROLE` — `ACCOUNTADMIN` (or a least-privilege role we can create later)
- `SNOWFLAKE_WAREHOUSE` — `D4B_WH`

The workflow will assemble a `~/.snowflake/connections.toml` from those secrets at runtime.

---

## 4. New backlog items added to `docs/development_log.md`

- [ ] Create dedicated `DCM_DEPLOYER` Snowflake user + role (key-pair auth) for CI.
- [ ] Add auto-deploy DEV on merge to main (next iteration).
- [ ] Add manual `workflow_dispatch` PROD deploy with required reviewer.

---

## 5. What I will NOT do in this iteration

- No auto-deploy workflow (`snow dcm deploy` in Actions) — explicitly deferred per your CI/CD scope answer.
- No GitHub repo secret values — you set those in the repo's Settings → Secrets after the workflow file lands.
- No service user creation today.

---

## Required to proceed

1. Confirm you've stored the PAT: `cortex secret store github_pat` (or tell me you have).
2. Approval of this plan, then I'll switch back to agent mode and execute it.