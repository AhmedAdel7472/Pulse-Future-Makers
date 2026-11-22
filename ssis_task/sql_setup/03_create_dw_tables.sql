/* ============================================================================
   03_create_dw_tables.sql
   TechnicalSupport_DW : schemas, EMPTY dimension / fact / history tables and constraints.
   Schemas:  dim (dimensions)  fact (fact tables)  hist (history tables used for point-in-time lookups)
             stg (staging, created in script 04)  etl (control & audit, script 04)  rpt (views, script 07)
   Re-runnable: objects are only created when missing; no data is dropped.
   GRAIN of every table is documented in docs/Data_Dictionary.md and in the comments below.
   ============================================================================ */
USE TechnicalSupport_DW;
GO
SET NOCOUNT ON;
GO
IF SCHEMA_ID(N'dim')  IS NULL EXEC(N'CREATE SCHEMA dim');
IF SCHEMA_ID(N'fact') IS NULL EXEC(N'CREATE SCHEMA fact');
IF SCHEMA_ID(N'hist') IS NULL EXEC(N'CREATE SCHEMA hist');
IF SCHEMA_ID(N'stg')  IS NULL EXEC(N'CREATE SCHEMA stg');
IF SCHEMA_ID(N'etl')  IS NULL EXEC(N'CREATE SCHEMA etl');
IF SCHEMA_ID(N'rpt')  IS NULL EXEC(N'CREATE SCHEMA rpt');
GO

/* ---------------------------------------------------------------- DimDate
   Grain: one row per calendar day (2025-01-01 .. 2025-12-31). date_key = yyyymmdd. */
IF OBJECT_ID(N'dim.DimDate', N'U') IS NULL
CREATE TABLE dim.DimDate (
    date_key      INT          NOT NULL,
    full_date     DATE         NOT NULL,
    [year]        SMALLINT     NOT NULL,
    [quarter]     TINYINT      NOT NULL,
    [month]       TINYINT      NOT NULL,
    month_name    VARCHAR(12)  NOT NULL,
    day_of_month  TINYINT      NOT NULL,
    CONSTRAINT PK_DimDate PRIMARY KEY CLUSTERED (date_key),
    CONSTRAINT UQ_DimDate_full_date UNIQUE (full_date)
);
GO
/* ---------------------------------------------------------------- DimCustomer (SCD)
   Grain: one row per customer VERSION. Business key = customer_id.
   customer_name = Type 1 (overwrite in every version) | customer_segment, region = Type 2 (new version)
   onboarding_date = fixed. Validity interval is half-open: [effective_from, effective_to). Current row: effective_to = 9999-12-31. */
IF OBJECT_ID(N'dim.DimCustomer', N'U') IS NULL
CREATE TABLE dim.DimCustomer (
    customer_key      INT IDENTITY(1,1) NOT NULL,
    customer_id       INT           NOT NULL,
    customer_name     NVARCHAR(100) NOT NULL,
    customer_segment  VARCHAR(20)   NOT NULL,
    region            VARCHAR(20)   NOT NULL,
    onboarding_date   DATE          NOT NULL,
    effective_from    DATE          NOT NULL,
    effective_to      DATE          NOT NULL CONSTRAINT DF_DimCustomer_to DEFAULT ('9999-12-31'),
    is_current        BIT           NOT NULL,
    version_number    INT           NOT NULL,
    CONSTRAINT PK_DimCustomer PRIMARY KEY CLUSTERED (customer_key),
    CONSTRAINT UQ_DimCustomer_version UNIQUE (customer_id, version_number),
    CONSTRAINT CK_DimCustomer_interval CHECK (effective_from < effective_to),
    CONSTRAINT CK_DimCustomer_current CHECK ((is_current = 1 AND effective_to = '9999-12-31') OR (is_current = 0 AND effective_to < '9999-12-31'))
);
GO
-- at most ONE current row per customer (filtered unique index)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_DimCustomer_one_current' AND object_id = OBJECT_ID(N'dim.DimCustomer'))
CREATE UNIQUE NONCLUSTERED INDEX UX_DimCustomer_one_current ON dim.DimCustomer (customer_id) WHERE is_current = 1;
GO
/* ---------------------------------------------------------------- DimAgent  (Type 1)
   Grain: one row per support agent. Business key = agent_id. */
IF OBJECT_ID(N'dim.DimAgent', N'U') IS NULL
CREATE TABLE dim.DimAgent (
    agent_key   INT IDENTITY(1,1) NOT NULL,
    agent_id    INT           NOT NULL,
    agent_name  NVARCHAR(100) NOT NULL,
    team        VARCHAR(30)   NOT NULL,
    region      VARCHAR(20)   NOT NULL,
    CONSTRAINT PK_DimAgent PRIMARY KEY CLUSTERED (agent_key),
    CONSTRAINT UQ_DimAgent_agent_id UNIQUE (agent_id)
);
GO
/* ---------------------------------------------------------------- DimTicketType
   Grain: one row per ticket type + the 'Unknown' member (key -1) used when a ticket has no ticket_details row.
   (ticket_category is NOT modelled: the source has no category column.) */
IF OBJECT_ID(N'dim.DimTicketType', N'U') IS NULL
CREATE TABLE dim.DimTicketType (
    ticket_type_key  INT IDENTITY(1,1) NOT NULL,
    ticket_type      VARCHAR(30) NOT NULL,
    CONSTRAINT PK_DimTicketType PRIMARY KEY CLUSTERED (ticket_type_key),
    CONSTRAINT UQ_DimTicketType_name UNIQUE (ticket_type)
);
GO
/* ---------------------------------------------------------------- FactTicket
   Grain: ONE ROW PER TICKET (business key ticket_id). Header + derived lifecycle measures as of the batch cutoff.
   latest_status = latest status event with status_at < batch cutoff (not the computer clock).
   first_resolution_at = earliest 'Resolved' event, last_resolution_at = latest 'Resolved' event (a reopened ticket can be resolved again).
   final_closed_at = time of the 'Closed' event only when the latest status is 'Closed'. NULL means "not yet": never invent a date. */
IF OBJECT_ID(N'fact.FactTicket', N'U') IS NULL
CREATE TABLE fact.FactTicket (
    ticket_id            INT           NOT NULL,
    customer_key         INT           NOT NULL,
    ticket_type_key      INT           NOT NULL,
    created_date_key     INT           NOT NULL,
    created_at           DATETIME2(0)  NOT NULL,
    priority             VARCHAR(10)   NOT NULL,
    channel              VARCHAR(10)   NOT NULL,
    severity             VARCHAR(10)   NOT NULL,
    latest_status        VARCHAR(20)   NOT NULL,
    first_resolution_at  DATETIME2(0)  NULL,
    last_resolution_at   DATETIME2(0)  NULL,
    final_closed_at      DATETIME2(0)  NULL,
    resolution_minutes   DECIMAL(12,2) NULL,
    reopen_count         INT           NOT NULL,
    is_resolved          BIT           NOT NULL,
    etl_batch_id         INT           NOT NULL,
    CONSTRAINT PK_FactTicket PRIMARY KEY CLUSTERED (ticket_id),
    CONSTRAINT FK_FactTicket_customer FOREIGN KEY (customer_key) REFERENCES dim.DimCustomer (customer_key),
    CONSTRAINT FK_FactTicket_type FOREIGN KEY (ticket_type_key) REFERENCES dim.DimTicketType (ticket_type_key),
    CONSTRAINT FK_FactTicket_date FOREIGN KEY (created_date_key) REFERENCES dim.DimDate (date_key),
    CONSTRAINT CK_FactTicket_priority CHECK (priority IN ('Low', 'Medium', 'High', 'Critical')),
    CONSTRAINT CK_FactTicket_reopen CHECK (reopen_count >= 0)
);
GO
/* ---------------------------------------------------------------- FactTicketStatusEvent
   Grain: ONE ROW PER STATUS EVENT (status_event_id). Supports the point-in-time status lookup. */
IF OBJECT_ID(N'fact.FactTicketStatusEvent', N'U') IS NULL
CREATE TABLE fact.FactTicketStatusEvent (
    status_event_id       INT          NOT NULL,
    ticket_id             INT          NOT NULL,
    [status]              VARCHAR(20)  NOT NULL,
    status_at             DATETIME2(0) NOT NULL,
    status_date_key       INT          NOT NULL,
    changed_by_agent_key  INT          NULL,
    status_reason         VARCHAR(100) NULL,
    etl_batch_id          INT          NOT NULL,
    CONSTRAINT PK_FactTicketStatusEvent PRIMARY KEY CLUSTERED (status_event_id),
    CONSTRAINT FK_FactStatus_ticket FOREIGN KEY (ticket_id) REFERENCES fact.FactTicket (ticket_id),
    CONSTRAINT FK_FactStatus_agent FOREIGN KEY (changed_by_agent_key) REFERENCES dim.DimAgent (agent_key),
    CONSTRAINT FK_FactStatus_date FOREIGN KEY (status_date_key) REFERENCES dim.DimDate (date_key)
);
GO
/* ---------------------------------------------------------------- HistCustomerStability
   Grain: ONE ROW PER CUSTOMER OBSERVATION (customer_id, snapshot_date). Observation effective from 00:00:00 of snapshot_date. */
IF OBJECT_ID(N'hist.HistCustomerStability', N'U') IS NULL
CREATE TABLE hist.HistCustomerStability (
    customer_id      INT         NOT NULL,
    snapshot_date    DATE        NOT NULL,
    stability_status VARCHAR(20) NOT NULL,
    stability_rank   TINYINT     NOT NULL,
    etl_batch_id     INT         NOT NULL,
    CONSTRAINT PK_HistCustomerStability PRIMARY KEY CLUSTERED (customer_id, snapshot_date)
);
GO
/* ---------------------------------------------------------------- HistAgentAssignment
   Grain: ONE ROW PER OWNERSHIP INTERVAL (assignment_id), half-open [started_at, ended_at); ended_at NULL = still open. */
IF OBJECT_ID(N'hist.HistAgentAssignment', N'U') IS NULL
CREATE TABLE hist.HistAgentAssignment (
    assignment_id  INT          NOT NULL,
    ticket_id      INT          NOT NULL,
    agent_key      INT          NOT NULL,
    started_at     DATETIME2(0) NOT NULL,
    ended_at       DATETIME2(0) NULL,
    etl_batch_id   INT          NOT NULL,
    CONSTRAINT PK_HistAgentAssignment PRIMARY KEY CLUSTERED (assignment_id),
    CONSTRAINT FK_HistAsg_ticket FOREIGN KEY (ticket_id) REFERENCES fact.FactTicket (ticket_id),
    CONSTRAINT FK_HistAsg_agent FOREIGN KEY (agent_key) REFERENCES dim.DimAgent (agent_key),
    CONSTRAINT CK_HistAsg_interval CHECK (ended_at IS NULL OR ended_at > started_at)
);
GO
/* ---------------------------------------------------------------- FactTicketBreakdown
   Grain: ONE ROW PER BREAKDOWN EVENT (breakdown_id). effort_minutes and cost_egp are stored ONCE here and never repeated on another table.
   customer_key  = the customer VERSION valid on the event date (not the current version).
   agent_key     = agent whose half-open ownership interval contains occurred_at (NULL when nobody owned the ticket).
   ticket_status_at_event       = latest status event with status_at <= occurred_at.
   customer_stability_at_event  = latest observation with snapshot_date <= CAST(occurred_at AS DATE); NULL = Unknown (never a future value). */
IF OBJECT_ID(N'fact.FactTicketBreakdown', N'U') IS NULL
CREATE TABLE fact.FactTicketBreakdown (
    breakdown_id                 INT           NOT NULL,
    ticket_id                    INT           NOT NULL,
    customer_key                 INT           NOT NULL,
    agent_key                    INT           NULL,
    event_date_key               INT           NOT NULL,
    occurred_at                  DATETIME2(0)  NOT NULL,
    breakdown_category           VARCHAR(30)   NOT NULL,
    component_name               VARCHAR(60)   NOT NULL,
    effort_minutes               INT           NOT NULL,
    cost_egp                     DECIMAL(12,2) NOT NULL,
    ticket_status_at_event       VARCHAR(20)   NULL,
    customer_stability_at_event  VARCHAR(20)   NULL,
    etl_batch_id                 INT           NOT NULL,
    CONSTRAINT PK_FactTicketBreakdown PRIMARY KEY CLUSTERED (breakdown_id),
    CONSTRAINT FK_FactBreakdown_ticket FOREIGN KEY (ticket_id) REFERENCES fact.FactTicket (ticket_id),
    CONSTRAINT FK_FactBreakdown_customer FOREIGN KEY (customer_key) REFERENCES dim.DimCustomer (customer_key),
    CONSTRAINT FK_FactBreakdown_agent FOREIGN KEY (agent_key) REFERENCES dim.DimAgent (agent_key),
    CONSTRAINT FK_FactBreakdown_date FOREIGN KEY (event_date_key) REFERENCES dim.DimDate (date_key),
    CONSTRAINT CK_FactBreakdown_effort CHECK (effort_minutes > 0),
    CONSTRAINT CK_FactBreakdown_cost CHECK (cost_egp >= 0)
);
GO
SELECT SCHEMA_NAME(t.schema_id) AS [schema], t.name AS table_name FROM sys.tables t WHERE SCHEMA_NAME(t.schema_id) IN ('dim','fact','hist') ORDER BY 1, 2;
GO
