-- =============================================================================
-- github_actions_network_policy.sql
-- =============================================================================
-- Self-refreshing network policy for GitHub-hosted Actions runners.
--
-- One-time bootstrap:
--   1. Egress NETWORK RULE for api.github.com
--   2. EXTERNAL ACCESS INTEGRATION using that rule
--   3. Ingress NETWORK RULE that lists allowed runner CIDRs (initially seeded
--      with a single placeholder; the procedure replaces it on first run)
--   4. NETWORK POLICY wrapping the ingress rule
--   5. Stored procedure that fetches api.github.com/meta and updates the rule
--   6. TASK that calls the procedure daily (created SUSPENDED)
--   7. Attach the policy to the three CI/CD deployer users
--
-- After running this file once, execute:
--     CALL CODE_DB.INTEGRATIONS.REFRESH_GITHUB_ACTIONS_IPS();
-- to populate the real CIDR list. Then resume the task when ready:
--     ALTER TASK CODE_DB.INTEGRATIONS.TASK_REFRESH_GITHUB_ACTIONS_IPS RESUME;
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE CODE_DB;
USE SCHEMA   INTEGRATIONS;

-- -----------------------------------------------------------------------------
-- 1. Egress rule + external access integration so the proc can reach GitHub
-- -----------------------------------------------------------------------------
CREATE OR REPLACE NETWORK RULE GITHUB_API_EGRESS
    TYPE       = HOST_PORT
    MODE       = EGRESS
    VALUE_LIST = ('api.github.com:443')
    COMMENT    = 'Egress to GitHub meta API for runner IP refresh';

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION GITHUB_API_ACCESS
    ALLOWED_NETWORK_RULES = (CODE_DB.INTEGRATIONS.GITHUB_API_EGRESS)
    ENABLED               = TRUE
    COMMENT               = 'Allows callers (procedure) to reach api.github.com';

-- -----------------------------------------------------------------------------
-- 2. Ingress rule (the allowlist itself). Seeded with a placeholder; the
--    procedure replaces VALUE_LIST on each refresh.
-- -----------------------------------------------------------------------------
CREATE NETWORK RULE IF NOT EXISTS GITHUB_ACTIONS_RUNNERS
    TYPE       = IPV4
    MODE       = INGRESS
    VALUE_LIST = ('255.255.255.255/32')   -- placeholder, replaced by procedure
    COMMENT    = 'GitHub-hosted Actions runner egress IPs (auto-refreshed daily)';

-- -----------------------------------------------------------------------------
-- 3. Network policy wrapping the rule
-- -----------------------------------------------------------------------------
CREATE NETWORK POLICY IF NOT EXISTS GITHUB_ACTIONS_POLICY
    ALLOWED_NETWORK_RULE_LIST = ('CODE_DB.INTEGRATIONS.GITHUB_ACTIONS_RUNNERS')
    COMMENT = 'Allow GitHub-hosted Actions runners (CI/CD service users only)';

-- -----------------------------------------------------------------------------
-- 4. Stored procedure: fetch + parse + ALTER NETWORK RULE
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE REFRESH_GITHUB_ACTIONS_IPS()
    RETURNS STRING
    LANGUAGE PYTHON
    RUNTIME_VERSION = '3.11'
    PACKAGES = ('snowflake-snowpark-python', 'requests')
    HANDLER = 'main'
    EXTERNAL_ACCESS_INTEGRATIONS = (GITHUB_API_ACCESS)
AS
$$
import requests

META_URL = "https://api.github.com/meta"
RULE_FQN = "CODE_DB.INTEGRATIONS.GITHUB_ACTIONS_RUNNERS"

def main(session):
    resp = requests.get(META_URL, timeout=30)
    resp.raise_for_status()
    data = resp.json()

    cidrs = sorted(set(data.get("actions", [])))
    if not cidrs:
        return "ERROR: no actions ranges returned by GitHub API"

    # Snowflake VALUE_LIST max size: keep IPv4 only (IPv6 not supported in IPV4 rules)
    ipv4 = [c for c in cidrs if ":" not in c]

    value_list_sql = ", ".join(f"'{c}'" for c in ipv4)
    alter_sql = f"ALTER NETWORK RULE {RULE_FQN} SET VALUE_LIST = ({value_list_sql})"
    session.sql(alter_sql).collect()

    return f"Refreshed {RULE_FQN} with {len(ipv4)} IPv4 CIDR(s)"
$$;

-- -----------------------------------------------------------------------------
-- 5. Daily task (created SUSPENDED — resume manually when ready)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TASK TASK_REFRESH_GITHUB_ACTIONS_IPS
    WAREHOUSE = D4B_WH                                 -- swap for your preferred WH
    SCHEDULE  = 'USING CRON 0 8 * * * UTC'              -- daily 08:00 UTC
    COMMENT   = 'Daily refresh of GitHub Actions runner IP allowlist'
AS
    CALL CODE_DB.INTEGRATIONS.REFRESH_GITHUB_ACTIONS_IPS();
-- Tasks are created suspended by default in 2025+; explicit suspend for safety:
ALTER TASK TASK_REFRESH_GITHUB_ACTIONS_IPS SUSPEND;

-- -----------------------------------------------------------------------------
-- 6. Initial population (run procedure once now)
-- -----------------------------------------------------------------------------
CALL REFRESH_GITHUB_ACTIONS_IPS();

-- -----------------------------------------------------------------------------
-- 7. Attach policy to the three deployer users
-- -----------------------------------------------------------------------------
ALTER USER DCM_DEPLOYER_DEV  SET NETWORK_POLICY = GITHUB_ACTIONS_POLICY;
ALTER USER DCM_DEPLOYER_TEST SET NETWORK_POLICY = GITHUB_ACTIONS_POLICY;
ALTER USER DCM_DEPLOYER_PROD SET NETWORK_POLICY = GITHUB_ACTIONS_POLICY;

-- -----------------------------------------------------------------------------
-- Verify
-- -----------------------------------------------------------------------------
DESCRIBE NETWORK RULE   GITHUB_ACTIONS_RUNNERS;
DESCRIBE NETWORK POLICY GITHUB_ACTIONS_POLICY;
SHOW PARAMETERS LIKE 'NETWORK_POLICY' FOR USER DCM_DEPLOYER_DEV;
SHOW TASKS LIKE 'TASK_REFRESH_GITHUB_ACTIONS_IPS';

-- -----------------------------------------------------------------------------
-- When ready to enable scheduled refresh:
--   ALTER TASK CODE_DB.INTEGRATIONS.TASK_REFRESH_GITHUB_ACTIONS_IPS RESUME;
--
-- To run on demand at any time:
--   CALL CODE_DB.INTEGRATIONS.REFRESH_GITHUB_ACTIONS_IPS();
--
-- To detach the policy later (e.g. switching to self-hosted runners):
--   ALTER USER DCM_DEPLOYER_DEV  UNSET NETWORK_POLICY;
--   ALTER USER DCM_DEPLOYER_TEST UNSET NETWORK_POLICY;
--   ALTER USER DCM_DEPLOYER_PROD UNSET NETWORK_POLICY;
-- =============================================================================
