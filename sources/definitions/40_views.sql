-- ============================================================================
-- 40_views.sql
-- Consumption-layer views in {{ db_name }}.SERVE.
-- ============================================================================

DEFINE VIEW {{ db_name }}.SERVE.VW_DAILY_SALES
COMMENT = 'Daily sales aggregated by store, product, and date'
AS
SELECT
    d.DATE,
    s.STORE_KEY,
    s.STORE_NAME,
    s.STORE_TYPE,
    p.PRODUCT_KEY,
    p.SKU,
    p.PRODUCT_NAME,
    p.CATEGORY,
    p.BRAND,
    SUM(f.QUANTITY)        AS UNITS_SOLD,
    SUM(f.GROSS_AMOUNT)    AS GROSS_SALES,
    SUM(f.DISCOUNT_AMOUNT) AS DISCOUNTS,
    SUM(f.TAX_AMOUNT)      AS TAX,
    SUM(f.NET_AMOUNT)      AS NET_SALES
FROM {{ db_name }}.ANALYTICS.FACT_SALES   f
JOIN {{ db_name }}.ANALYTICS.DIM_DATE     d ON d.DATE_KEY    = f.DATE_KEY
JOIN {{ db_name }}.ANALYTICS.DIM_STORE    s ON s.STORE_KEY   = f.STORE_KEY
JOIN {{ db_name }}.ANALYTICS.DIM_PRODUCT  p ON p.PRODUCT_KEY = f.PRODUCT_KEY
GROUP BY 1,2,3,4,5,6,7,8,9;

DEFINE VIEW {{ db_name }}.SERVE.VW_PRODUCT_PERFORMANCE
COMMENT = 'Lifetime product sales / returns rollup'
AS
SELECT
    p.PRODUCT_KEY,
    p.SKU,
    p.PRODUCT_NAME,
    p.CATEGORY,
    p.BRAND,
    COALESCE(SUM(f.QUANTITY), 0)        AS UNITS_SOLD,
    COALESCE(SUM(f.NET_AMOUNT), 0)      AS NET_SALES,
    COALESCE(SUM(r.QUANTITY), 0)        AS UNITS_RETURNED,
    COALESCE(SUM(r.REFUND_AMOUNT), 0)   AS REFUND_TOTAL
FROM {{ db_name }}.ANALYTICS.DIM_PRODUCT p
LEFT JOIN {{ db_name }}.ANALYTICS.FACT_SALES   f ON f.PRODUCT_KEY = p.PRODUCT_KEY
LEFT JOIN {{ db_name }}.ANALYTICS.FACT_RETURNS r ON r.PRODUCT_KEY = p.PRODUCT_KEY
GROUP BY 1,2,3,4,5;

DEFINE VIEW {{ db_name }}.SERVE.VW_INVENTORY_SNAPSHOT
COMMENT = 'Latest inventory position by product and store'
AS
SELECT
    d.DATE              AS SNAPSHOT_DATE,
    s.STORE_KEY,
    s.STORE_NAME,
    p.PRODUCT_KEY,
    p.SKU,
    p.PRODUCT_NAME,
    i.ON_HAND_QTY,
    i.ON_ORDER_QTY,
    i.RESERVED_QTY,
    i.REORDER_POINT,
    i.INVENTORY_VALUE
FROM {{ db_name }}.ANALYTICS.FACT_INVENTORY i
JOIN {{ db_name }}.ANALYTICS.DIM_DATE    d ON d.DATE_KEY    = i.SNAPSHOT_DATE_KEY
JOIN {{ db_name }}.ANALYTICS.DIM_STORE   s ON s.STORE_KEY   = i.STORE_KEY
JOIN {{ db_name }}.ANALYTICS.DIM_PRODUCT p ON p.PRODUCT_KEY = i.PRODUCT_KEY;
