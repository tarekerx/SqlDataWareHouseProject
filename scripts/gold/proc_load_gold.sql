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
