-- ============================================================================
-- 30_facts.sql
-- Fact tables for Dark Star Electronics retail star schema.
-- ============================================================================

DEFINE TABLE {{ db_name }}.ANALYTICS.FACT_SALES (
    SALE_KEY            NUMBER          NOT NULL,
    ORDER_ID            VARCHAR(50)     NOT NULL,
    ORDER_LINE_NUMBER   NUMBER,
    DATE_KEY            NUMBER(9,0)     NOT NULL,
    CUSTOMER_KEY        NUMBER,
    PRODUCT_KEY         NUMBER          NOT NULL,
    STORE_KEY           NUMBER          NOT NULL,
    EMPLOYEE_KEY        NUMBER,
    QUANTITY            NUMBER(10,0),
    UNIT_PRICE          NUMBER(12,2),
    DISCOUNT_AMOUNT     NUMBER(12,2),
    TAX_AMOUNT          NUMBER(12,2),
    GROSS_AMOUNT        NUMBER(14,2),
    NET_AMOUNT          NUMBER(14,2),
    PAYMENT_METHOD      VARCHAR(50),
    LOAD_TIMESTAMP      TIMESTAMP_NTZ
)
CHANGE_TRACKING = TRUE
COMMENT = 'Sales transaction grain (one row per order line)';

DEFINE TABLE {{ db_name }}.ANALYTICS.FACT_INVENTORY (
    SNAPSHOT_DATE_KEY   NUMBER(9,0)     NOT NULL,
    PRODUCT_KEY         NUMBER          NOT NULL,
    STORE_KEY           NUMBER          NOT NULL,
    ON_HAND_QTY         NUMBER(10,0),
    ON_ORDER_QTY        NUMBER(10,0),
    RESERVED_QTY        NUMBER(10,0),
    REORDER_POINT       NUMBER(10,0),
    INVENTORY_VALUE     NUMBER(14,2),
    LOAD_TIMESTAMP      TIMESTAMP_NTZ
)
CHANGE_TRACKING = TRUE
COMMENT = 'Daily inventory snapshot fact';

DEFINE TABLE {{ db_name }}.ANALYTICS.FACT_RETURNS (
    RETURN_KEY          NUMBER          NOT NULL,
    SALE_KEY            NUMBER,
    DATE_KEY            NUMBER(9,0)     NOT NULL,
    PRODUCT_KEY         NUMBER          NOT NULL,
    CUSTOMER_KEY        NUMBER,
    STORE_KEY           NUMBER,
    QUANTITY            NUMBER(10,0),
    REFUND_AMOUNT       NUMBER(12,2),
    RETURN_REASON       VARCHAR(255),
    CONDITION           VARCHAR(50),
    LOAD_TIMESTAMP      TIMESTAMP_NTZ
)
CHANGE_TRACKING = TRUE
COMMENT = 'Returns fact, links back to FACT_SALES via SALE_KEY';
