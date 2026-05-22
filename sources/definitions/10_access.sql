-- ============================================================================
-- 10_access.sql
-- Persona database roles + warehouse access account role for Dark Star.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Database roles (scoped to the {{ env }} database)
-- ---------------------------------------------------------------------------
DEFINE DATABASE ROLE {{ db_name }}.ADMIN
    COMMENT = 'Dark Star {{ env }} - full DDL/DML control';

DEFINE DATABASE ROLE {{ db_name }}.ENGINEER
    COMMENT = 'Dark Star {{ env }} - read/write data engineer';

DEFINE DATABASE ROLE {{ db_name }}.ANALYST
    COMMENT = 'Dark Star {{ env }} - read-only analyst';

DEFINE DATABASE ROLE {{ db_name }}.LOADER
    COMMENT = 'Dark Star {{ env }} - service role that loads RAW';

DEFINE DATABASE ROLE {{ db_name }}.DATA_SCIENTIST
    COMMENT = 'Dark Star {{ env }} - read-all + create in ANALYTICS';

-- ---------------------------------------------------------------------------
-- Account role for warehouse access (db roles cannot hold WH grants)
-- ---------------------------------------------------------------------------
DEFINE ROLE DARK_STAR_{{ env }}_WAREHOUSE_USER
    COMMENT = 'Dark Star {{ env }} warehouse access role';

-- ---------------------------------------------------------------------------
-- Role hierarchy
-- ---------------------------------------------------------------------------
GRANT DATABASE ROLE {{ db_name }}.ANALYST TO DATABASE ROLE {{ db_name }}.DATA_SCIENTIST;
GRANT DATABASE ROLE {{ db_name }}.ANALYST TO DATABASE ROLE {{ db_name }}.ENGINEER;
GRANT DATABASE ROLE {{ db_name }}.ENGINEER TO DATABASE ROLE {{ db_name }}.ADMIN;
GRANT DATABASE ROLE {{ db_name }}.LOADER  TO DATABASE ROLE {{ db_name }}.ADMIN;
GRANT DATABASE ROLE {{ db_name }}.ADMIN   TO ROLE SYSADMIN;
GRANT ROLE DARK_STAR_{{ env }}_WAREHOUSE_USER TO ROLE SYSADMIN;

-- ---------------------------------------------------------------------------
-- Warehouse usage (account role only)
-- ---------------------------------------------------------------------------
GRANT USAGE ON WAREHOUSE DARK_STAR_{{ env }}_WH TO ROLE DARK_STAR_{{ env }}_WAREHOUSE_USER;

-- ---------------------------------------------------------------------------
-- Database usage to all personas
-- ---------------------------------------------------------------------------
GRANT USAGE ON DATABASE {{ db_name }} TO DATABASE ROLE {{ db_name }}.ANALYST;
GRANT USAGE ON DATABASE {{ db_name }} TO DATABASE ROLE {{ db_name }}.DATA_SCIENTIST;
GRANT USAGE ON DATABASE {{ db_name }} TO DATABASE ROLE {{ db_name }}.ENGINEER;
GRANT USAGE ON DATABASE {{ db_name }} TO DATABASE ROLE {{ db_name }}.LOADER;
GRANT USAGE ON DATABASE {{ db_name }} TO DATABASE ROLE {{ db_name }}.ADMIN;

-- ---------------------------------------------------------------------------
-- Per-schema USAGE + SELECT for readers (via macro)
-- ---------------------------------------------------------------------------
{% for schema in ['RAW', 'STAGING', 'ANALYTICS', 'SERVE'] %}
{{ grant_persona_access(db_name, schema) }}
{% endfor %}

-- ---------------------------------------------------------------------------
-- Engineer write access on RAW / STAGING / ANALYTICS
-- ---------------------------------------------------------------------------
{% for schema in ['RAW', 'STAGING', 'ANALYTICS'] %}
GRANT INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA {{ db_name }}.{{ schema }} TO DATABASE ROLE {{ db_name }}.ENGINEER;
{% endfor %}

-- ---------------------------------------------------------------------------
-- Loader: write only into RAW
-- ---------------------------------------------------------------------------
GRANT INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA {{ db_name }}.RAW TO DATABASE ROLE {{ db_name }}.LOADER;

-- ---------------------------------------------------------------------------
-- Data Scientist: CREATE in ANALYTICS for experimentation
-- ---------------------------------------------------------------------------
GRANT CREATE TABLE, CREATE VIEW ON SCHEMA {{ db_name }}.ANALYTICS TO DATABASE ROLE {{ db_name }}.DATA_SCIENTIST;

-- ---------------------------------------------------------------------------
-- Admin: full DDL across all schemas
-- ---------------------------------------------------------------------------
{% for schema in ['RAW', 'STAGING', 'ANALYTICS', 'SERVE'] %}
GRANT CREATE TABLE, CREATE VIEW, CREATE DYNAMIC TABLE, CREATE TASK, CREATE STAGE, CREATE SEQUENCE, CREATE PROCEDURE, CREATE FUNCTION
    ON SCHEMA {{ db_name }}.{{ schema }} TO DATABASE ROLE {{ db_name }}.ADMIN;
GRANT INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA {{ db_name }}.{{ schema }} TO DATABASE ROLE {{ db_name }}.ADMIN;
{% endfor %}
