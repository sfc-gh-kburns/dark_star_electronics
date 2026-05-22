-- ============================================================================
-- 20_dimensions.sql
-- Conformed dimensions for Dark Star Electronics retail star schema.
-- ============================================================================

DEFINE TABLE {{ db_name }}.ANALYTICS.DIM_DATE (
    DATE_KEY        NUMBER(9,0)   NOT NULL,
    DATE            DATE          NOT NULL,
    DAY             NUMBER(2,0),
    MONTH           NUMBER(2,0),
    MONTH_NAME      VARCHAR(20),
    QUARTER         NUMBER(1,0),
    YEAR            NUMBER(4,0),
    DAY_OF_WEEK     NUMBER(1,0),
    DAY_NAME        VARCHAR(10),
    IS_WEEKEND      BOOLEAN,
    IS_HOLIDAY      BOOLEAN,
    FISCAL_PERIOD   VARCHAR(10)
)
COMMENT = 'Date dimension';

DEFINE TABLE {{ db_name }}.ANALYTICS.DIM_CUSTOMER (
    CUSTOMER_KEY    NUMBER          NOT NULL,
    CUSTOMER_ID     VARCHAR(50)     NOT NULL,
    FIRST_NAME      VARCHAR(100),
    LAST_NAME       VARCHAR(100),
    EMAIL           VARCHAR(255),
    PHONE           VARCHAR(50),
    SEGMENT         VARCHAR(50),
    LOYALTY_TIER    VARCHAR(20),
    ADDRESS_LINE_1  VARCHAR(255),
    ADDRESS_LINE_2  VARCHAR(255),
    CITY            VARCHAR(100),
    STATE           VARCHAR(50),
    POSTAL_CODE     VARCHAR(20),
    COUNTRY         VARCHAR(50),
    SIGNUP_DATE     DATE,
    EFFECTIVE_FROM  TIMESTAMP_NTZ,
    EFFECTIVE_TO    TIMESTAMP_NTZ,
    IS_CURRENT      BOOLEAN
)
CHANGE_TRACKING = TRUE
COMMENT = 'Customer dimension (SCD2-ready)';

DEFINE TABLE {{ db_name }}.ANALYTICS.DIM_PRODUCT (
    PRODUCT_KEY     NUMBER          NOT NULL,
    SKU             VARCHAR(50)     NOT NULL,
    PRODUCT_NAME    VARCHAR(255),
    CATEGORY        VARCHAR(100),
    SUBCATEGORY     VARCHAR(100),
    BRAND           VARCHAR(100),
    MODEL_NUMBER    VARCHAR(100),
    UNIT_COST       NUMBER(12,2),
    LIST_PRICE      NUMBER(12,2),
    IS_ACTIVE       BOOLEAN,
    LAUNCH_DATE     DATE,
    EFFECTIVE_FROM  TIMESTAMP_NTZ,
    EFFECTIVE_TO    TIMESTAMP_NTZ,
    IS_CURRENT      BOOLEAN
)
CHANGE_TRACKING = TRUE
COMMENT = 'Product dimension (SCD2-ready)';

DEFINE TABLE {{ db_name }}.ANALYTICS.DIM_STORE (
    STORE_KEY       NUMBER          NOT NULL,
    STORE_ID        VARCHAR(50)     NOT NULL,
    STORE_NAME      VARCHAR(255),
    STORE_TYPE      VARCHAR(20),       -- ONLINE / PHYSICAL / OUTLET
    REGION          VARCHAR(50),
    DISTRICT        VARCHAR(50),
    ADDRESS_LINE_1  VARCHAR(255),
    CITY            VARCHAR(100),
    STATE           VARCHAR(50),
    POSTAL_CODE     VARCHAR(20),
    COUNTRY         VARCHAR(50),
    OPEN_DATE       DATE,
    CLOSE_DATE      DATE,
    IS_ACTIVE       BOOLEAN
)
COMMENT = 'Store / channel dimension';

DEFINE TABLE {{ db_name }}.ANALYTICS.DIM_EMPLOYEE (
    EMPLOYEE_KEY    NUMBER          NOT NULL,
    EMPLOYEE_ID     VARCHAR(50)     NOT NULL,
    FIRST_NAME      VARCHAR(100),
    LAST_NAME       VARCHAR(100),
    EMAIL           VARCHAR(255),
    JOB_ROLE        VARCHAR(100),
    STORE_KEY       NUMBER,
    HIRE_DATE       DATE,
    TERM_DATE       DATE,
    IS_ACTIVE       BOOLEAN
)
COMMENT = 'Employee dimension';
