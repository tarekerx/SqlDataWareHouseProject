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

    IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
    DROP VIEW gold.dim_products;
GO
    
CREATE VIEW gold.dim_products AS
    
SELECT
     ROW_NUMBER() OVER (ORDER BY pn.prd_id)  AS product_key
    ,pn.prd_id                                AS product_id
    ,pn.cat_id                                AS category_id        -- was: categoery_id
    ,pc.CAT                                   AS product_category   -- was: product_categorey
    ,pc.SUBCAT                                AS product_subcategory -- was: product_subcategorey
    ,pc.MAINTENANCE                           AS product_maintenance -- was: product_minataince
    ,pn.prd_key                               AS product_number     -- ⚠ was: product_id (duplicate!)
    ,pn.prd_nm                                AS product_name
    ,pn.prd_cost                              AS product_cost
    ,pn.prd_line                              AS product_line
    ,pn.prd_start_dt                          AS product_start_date
    ,pn.prd_end_dt                            AS product_end_date
FROM [DataWareHouse].[silver].[crm_prd_info] pn
LEFT JOIN silver.erp_px_cat_g1v2 pc
    ON pc.ID = pn.cat_id
WHERE pn.prd_end_dt IS NULL;
