-- =============================================================================
-- View:    gold.dim_customers
-- Layer:   Gold (Dimension)
-- Purpose: Consolidated customer dimension combining CRM and ERP source systems.
--          Resolves gender conflicts by treating CRM as the master source.
-- Updated: 2026-05-04
-- =============================================================================

IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
    DROP VIEW gold.dim_customers;
GO

CREATE VIEW gold.dim_customers AS

SELECT
     ROW_NUMBER() OVER (ORDER BY ci.cst_id)                AS customer_key      -- Surrogate key
    ,ci.[cst_id]                                           AS customer_id        -- Source natural key
    ,ci.[cst_key]                                          AS customer_number
    ,ci.[cst_firstname]                                    AS first_name
    ,ci.[cst_lastname]                                     AS last_name
    ,la.cntry                                              AS country
    ,ci.[cst_marital_status]                               AS marital_status
    ,CASE
        WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr        -- CRM is the master for gender info
        WHEN ca.gen      != 'n/a' THEN ca.gen              -- Fallback to ERP
        ELSE 'n/a'
     END                                                   AS gender
    ,ca.bdate                                              AS birthdate
    ,ci.[cst_create_date]                                  AS create_date

FROM       silver.crm_cust_info  AS ci
LEFT JOIN  silver.erp_cust_az12  AS ca  ON ci.cst_key = ca.cid
LEFT JOIN  silver.erp_loc_a101   AS la  ON ci.cst_key = la.cid;
GO

-- =============================================================================
-- View:    gold.dim_products
-- Layer:   Gold (Dimension)
-- Purpose: Product dimension with category hierarchy from ERP system.
-- Note:    Filters to current products only (prd_end_dt IS NULL)
-- Updated: 2026-05-04
-- =============================================================================

IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
    DROP VIEW gold.dim_products;
GO
    
CREATE VIEW gold.dim_products AS
    
SELECT
     ROW_NUMBER() OVER (ORDER BY pn.prd_id)                AS product_key
    ,pn.prd_id                                             AS product_id
    ,pn.cat_id                                             AS category_id
    ,pc.CAT                                                AS product_category
    ,pc.SUBCAT                                             AS product_subcategory
    ,pc.MAINTENANCE                                        AS product_maintenance
    ,pn.prd_key                                            AS product_number
    ,pn.prd_nm                                             AS product_name
    ,pn.prd_cost                                           AS product_cost
    ,pn.prd_line                                           AS product_line
    ,pn.prd_start_dt                                       AS product_start_date
    ,pn.prd_end_dt                                         AS product_end_date
FROM [DataWareHouse].[silver].[crm_prd_info] pn
LEFT JOIN silver.erp_px_cat_g1v2 pc
    ON pc.ID = pn.cat_id
WHERE pn.prd_end_dt IS NULL;  -- Current products only
GO

-- =============================================================================
-- View:    gold.fact_sales
-- Layer:   Gold (Fact Table)
-- Purpose: Sales fact table joining CRM transactions with product and customer dimensions.
-- Dependencies: gold.dim_products, gold.dim_customers
-- Updated: 2026-05-04
-- =============================================================================

-- Drop view if exists (clean approach)
IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
    DROP VIEW gold.fact_sales;
GO

CREATE VIEW gold.fact_sales AS
SELECT 
    -- Sales order identifiers
    sd.sls_ord_num          AS order_number,
    sd.sls_prd_key          AS source_product_number,  -- Renamed for clarity
    
    -- Business keys from dimension tables
    pr.product_key          AS product_key,
    cu.customer_key         AS customer_key,
    
    -- Date fields
    sd.sls_order_dt         AS order_date,
    sd.sls_ship_dt          AS ship_date,
    sd.sls_due_dt           AS due_date,
    
    -- Sales metrics
    sd.sls_sales            AS sales_amount,
    sd.sls_quantity         AS quantity,
    sd.sls_price            AS unit_price,
    
    -- Metadata
    sd.dwh_create_date      AS dwh_created_date

FROM [DataWareHouse].[silver].[crm_sales_details] sd

LEFT JOIN gold.dim_products pr
    ON sd.sls_prd_key = pr.product_number

LEFT JOIN gold.dim_customers cu
    ON sd.sls_cust_id = cu.customer_id

WHERE 
    sd.sls_ord_num IS NOT NULL;  -- Ensure valid order numbers
GO

-- =============================================================================
-- Validation Queries
-- =============================================================================

-- Verify all views exist
SELECT 
    TABLE_SCHEMA,
    TABLE_NAME,
    TABLE_TYPE
FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'gold'
ORDER BY TABLE_NAME;

-- Check for orphaned fact records (missing dimension keys)
SELECT 
    COUNT(*) AS total_sales,
    SUM(CASE WHEN pr.product_key IS NULL THEN 1 ELSE 0 END) AS missing_product_key,
    SUM(CASE WHEN cu.customer_key IS NULL THEN 1 ELSE 0 END) AS missing_customer_key
FROM gold.fact_sales;
