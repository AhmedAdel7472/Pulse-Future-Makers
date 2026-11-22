/* ============================================================================
   80_create_scd_wizard_scratch.sql        (Lab 04, Part A - exploration only)
   Creates dim.DimCustomer_SCD_Scratch: a COPY of the structure of dim.DimCustomer that the native
   "Slowly Changing Dimension" transformation can write to without touching the real dimension.
   Re-runnable: it drops and recreates the scratch table. It never touches dim.DimCustomer.
   ============================================================================ */
USE TechnicalSupport_DW;
GO
IF OBJECT_ID(N'dim.DimCustomer_SCD_Scratch', N'U') IS NOT NULL DROP TABLE dim.DimCustomer_SCD_Scratch;
GO
CREATE TABLE dim.DimCustomer_SCD_Scratch (
    customer_key      INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    customer_id       INT           NOT NULL,            -- business key
    customer_name     NVARCHAR(100) NOT NULL,            -- changing attribute (Type 1)
    customer_segment  VARCHAR(20)   NOT NULL,            -- historical attribute (Type 2)
    region            VARCHAR(20)   NOT NULL,            -- historical attribute (Type 2)
    onboarding_date   DATE          NOT NULL,            -- fixed attribute
    effective_from    DATE          NOT NULL,
    effective_to      DATE          NULL,                -- the wizard can use NULL or a far date for the open row: record what it does
    is_current        BIT           NOT NULL
);
GO
-- Start Part A from the same state as dim.DimCustomer: one version-1 row per customer (copy, do not alter the original).
INSERT INTO dim.DimCustomer_SCD_Scratch (customer_id, customer_name, customer_segment, region, onboarding_date, effective_from, effective_to, is_current)
SELECT customer_id, customer_name, customer_segment, region, onboarding_date, effective_from, effective_to, is_current
FROM dim.DimCustomer
WHERE is_current = 1;
GO
SELECT COUNT(*) AS scratch_rows FROM dim.DimCustomer_SCD_Scratch;
GO
