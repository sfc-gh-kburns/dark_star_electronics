-- ============================================================================
-- 00_infrastructure.sql
-- Database, schemas, and per-environment warehouse for Dark Star Electronics.
-- ============================================================================

DEFINE DATABASE {{ db_name }}
    DATA_RETENTION_TIME_IN_DAYS = {{ retention_days }}
    COMMENT = 'Dark Star Electronics - {{ env }} environment';

DEFINE SCHEMA {{ db_name }}.RAW
    COMMENT = 'Raw landed source data';

DEFINE SCHEMA {{ db_name }}.STAGING
    COMMENT = 'Cleansed/conformed staging layer';

DEFINE SCHEMA {{ db_name }}.ANALYTICS
    COMMENT = 'Dim/fact star schema';

DEFINE SCHEMA {{ db_name }}.SERVE
    COMMENT = 'Consumption views for BI/analytics';

DEFINE WAREHOUSE DARK_STAR_{{ env }}_WH
    WITH
        WAREHOUSE_SIZE = '{{ wh_size }}'
        AUTO_SUSPEND = {{ wh_auto_suspend }}
        AUTO_RESUME = TRUE
        INITIALLY_SUSPENDED = TRUE
        COMMENT = 'Dark Star Electronics {{ env }} compute';
