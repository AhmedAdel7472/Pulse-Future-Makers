/* ============================================================================
   04_create_staging_and_audit_tables.sql
   TechnicalSupport_DW : staging tables (stg), ETL control / audit tables (etl) and reference data.
   Staging tables are typed landing tables WITHOUT primary keys on purpose: duplicate business keys must be DETECTED by the
   ETL (and logged), not silently blocked by the database. Every staging row keeps batch_id, source_file and source_row_number
   (source_row_number is assigned by the database in ARRIVAL order - map only the other columns in the OLE DB Destination; it is used as the tie-breaker
   'first occurrence wins' when duplicate business keys are detected).
   Re-runnable: tables are only created when missing.
   ============================================================================ */
USE TechnicalSupport_DW;
GO
SET NOCOUNT ON;
GO
/* ---------------------------------------------------------------- staging (one table per source file) */
IF OBJECT_ID(N'stg.customer_snapshot', N'U') IS NULL
CREATE TABLE stg.customer_snapshot (
    customer_id INT NULL, customer_name NVARCHAR(100) NULL, customer_segment VARCHAR(20) NULL, region VARCHAR(20) NULL,
    onboarding_date DATE NULL, effective_date DATE NULL,
    batch_id INT NOT NULL, source_file VARCHAR(100) NOT NULL, source_row_number INT IDENTITY(1,1) NOT NULL);
GO
IF OBJECT_ID(N'stg.support_agents', N'U') IS NULL
CREATE TABLE stg.support_agents (
    agent_id INT NULL, agent_name NVARCHAR(100) NULL, team VARCHAR(30) NULL, region VARCHAR(20) NULL, hire_date DATE NULL,
    batch_id INT NOT NULL, source_file VARCHAR(100) NOT NULL, source_row_number INT IDENTITY(1,1) NOT NULL);
GO
IF OBJECT_ID(N'stg.tickets', N'U') IS NULL
CREATE TABLE stg.tickets (
    ticket_id INT NULL, customer_id INT NULL, created_at DATETIME2(0) NULL, priority VARCHAR(10) NULL, channel VARCHAR(10) NULL,
    batch_id INT NOT NULL, source_file VARCHAR(100) NOT NULL, source_row_number INT IDENTITY(1,1) NOT NULL);
GO
IF OBJECT_ID(N'stg.ticket_details', N'U') IS NULL
CREATE TABLE stg.ticket_details (
    ticket_id INT NULL, ticket_name NVARCHAR(200) NULL, ticket_type VARCHAR(30) NULL, severity VARCHAR(10) NULL, description NVARCHAR(500) NULL,
    batch_id INT NOT NULL, source_file VARCHAR(100) NOT NULL, source_row_number INT IDENTITY(1,1) NOT NULL);
GO
IF OBJECT_ID(N'stg.ticket_status_history', N'U') IS NULL
CREATE TABLE stg.ticket_status_history (
    status_event_id INT NULL, ticket_id INT NULL, [status] VARCHAR(20) NULL, status_at DATETIME2(0) NULL, changed_by_agent_id INT NULL, status_reason VARCHAR(100) NULL,
    batch_id INT NOT NULL, source_file VARCHAR(100) NOT NULL, source_row_number INT IDENTITY(1,1) NOT NULL);
GO
IF OBJECT_ID(N'stg.ticket_breakdown', N'U') IS NULL
CREATE TABLE stg.ticket_breakdown (
    breakdown_id INT NULL, ticket_id INT NULL, occurred_at DATETIME2(0) NULL, breakdown_category VARCHAR(30) NULL, component_name VARCHAR(60) NULL,
    effort_minutes INT NULL, cost_egp DECIMAL(12,2) NULL, breakdown_description NVARCHAR(300) NULL,
    batch_id INT NOT NULL, source_file VARCHAR(100) NOT NULL, source_row_number INT IDENTITY(1,1) NOT NULL);
GO
IF OBJECT_ID(N'stg.customer_stability_observations', N'U') IS NULL
CREATE TABLE stg.customer_stability_observations (
    customer_id INT NULL, snapshot_date DATE NULL, stability_status VARCHAR(20) NULL,
    batch_id INT NOT NULL, source_file VARCHAR(100) NOT NULL, source_row_number INT IDENTITY(1,1) NOT NULL);
GO
IF OBJECT_ID(N'stg.ticket_agent_assignments', N'U') IS NULL
CREATE TABLE stg.ticket_agent_assignments (
    assignment_id INT NULL, ticket_id INT NULL, agent_id INT NULL, started_at DATETIME2(0) NULL, ended_at DATETIME2(0) NULL,
    batch_id INT NOT NULL, source_file VARCHAR(100) NOT NULL, source_row_number INT IDENTITY(1,1) NOT NULL);
GO
/* ---------------------------------------------------------------- reference data */
IF OBJECT_ID(N'etl.ref_PriorityMap', N'U') IS NULL
CREATE TABLE etl.ref_PriorityMap (label_key VARCHAR(20) NOT NULL PRIMARY KEY, priority VARCHAR(10) NOT NULL);   -- loaded from data/reference_data/priority_label_map.csv (Lab 2)
GO
IF OBJECT_ID(N'etl.ref_StabilityLevel', N'U') IS NULL
CREATE TABLE etl.ref_StabilityLevel (stability_status VARCHAR(20) NOT NULL PRIMARY KEY, stability_rank TINYINT NOT NULL);
GO
/* ---------------------------------------------------------------- control / audit */
-- One row per batch file as announced by the manifest (what SHOULD arrive)
IF OBJECT_ID(N'etl.ETL_BatchManifest', N'U') IS NULL
CREATE TABLE etl.ETL_BatchManifest (
    batch_id INT NOT NULL, file_name VARCHAR(100) NOT NULL, source_row_count INT NOT NULL,
    processing_date DATE NOT NULL, window_start DATETIME2(0) NOT NULL, window_end_exclusive DATETIME2(0) NOT NULL, cutoff_ts DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ETL_BatchManifest PRIMARY KEY (batch_id, file_name));
GO
-- Watermark: ONE row per pipeline. Advanced only after every dependent load of the batch has succeeded.
IF OBJECT_ID(N'etl.ETL_Watermark', N'U') IS NULL
CREATE TABLE etl.ETL_Watermark (
    pipeline_name VARCHAR(50) NOT NULL PRIMARY KEY,
    last_batch_id INT NOT NULL, last_cutoff_ts DATETIME2(0) NOT NULL, updated_at DATETIME2(0) NOT NULL);
GO
-- Audit: one row per package execution
IF OBJECT_ID(N'etl.ETL_BatchLog', N'U') IS NULL
CREATE TABLE etl.ETL_BatchLog (
    batch_log_id   INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    batch_id       INT           NOT NULL,
    package_name   VARCHAR(100)  NOT NULL,
    start_time     DATETIME2(0)  NOT NULL,
    end_time       DATETIME2(0)  NULL,
    status         VARCHAR(20)   NOT NULL,          -- Running | Succeeded | Failed | Skipped
    source_rows    INT           NULL,
    inserted_rows  INT           NULL,
    updated_rows   INT           NULL,
    rejected_rows  INT           NULL,
    error_summary  NVARCHAR(2000) NULL,
    CONSTRAINT CK_ETL_BatchLog_status CHECK (status IN ('Running', 'Succeeded', 'Failed', 'Skipped')));
GO
-- Rejected rows: one row per rejected source row
IF OBJECT_ID(N'etl.ETL_Rejects', N'U') IS NULL
CREATE TABLE etl.ETL_Rejects (
    reject_id     INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    batch_id      INT            NOT NULL,
    source_file   VARCHAR(100)   NOT NULL,
    business_key  VARCHAR(100)   NULL,
    reason_code   VARCHAR(30)    NOT NULL,
    raw_row       NVARCHAR(2000) NULL,
    rejected_at   DATETIME2(0)   NOT NULL CONSTRAINT DF_ETL_Rejects_at DEFAULT (SYSDATETIME()));
GO
SELECT SCHEMA_NAME(t.schema_id) AS [schema], t.name AS table_name FROM sys.tables t WHERE SCHEMA_NAME(t.schema_id) IN ('stg','etl') ORDER BY 1, 2;
GO
