/* ============================================================================
   02_create_source_tables.sql
   TechnicalSupport_Source : the operational (OLTP-style) source database. Typed tables, primary and foreign keys.
   It is seeded with the baseline (Batch 0) by 06_seed_source_batch0.sql.
   Re-runnable: every object is created only when it does not exist yet (data is never dropped here).
   ============================================================================ */
USE TechnicalSupport_Source;
GO
SET NOCOUNT ON;
GO
IF OBJECT_ID(N'dbo.customers', N'U') IS NULL
CREATE TABLE dbo.customers (
    customer_id       INT           NOT NULL,
    customer_name     NVARCHAR(100) NOT NULL,
    customer_segment  VARCHAR(20)   NOT NULL,
    region            VARCHAR(20)   NOT NULL,
    onboarding_date   DATE          NOT NULL,
    CONSTRAINT PK_src_customers PRIMARY KEY CLUSTERED (customer_id)
);
GO
IF OBJECT_ID(N'dbo.stability_levels', N'U') IS NULL
CREATE TABLE dbo.stability_levels (
    stability_status  VARCHAR(20)   NOT NULL,
    stability_rank    TINYINT       NOT NULL,
    CONSTRAINT PK_src_stability_levels PRIMARY KEY CLUSTERED (stability_status)
);
GO
IF OBJECT_ID(N'dbo.support_agents', N'U') IS NULL
CREATE TABLE dbo.support_agents (
    agent_id          INT           NOT NULL,
    agent_name        NVARCHAR(100) NOT NULL,
    team              VARCHAR(30)   NOT NULL,
    region            VARCHAR(20)   NOT NULL,
    hire_date         DATE          NOT NULL,
    CONSTRAINT PK_src_support_agents PRIMARY KEY CLUSTERED (agent_id)
);
GO
IF OBJECT_ID(N'dbo.tickets', N'U') IS NULL
CREATE TABLE dbo.tickets (
    ticket_id         INT           NOT NULL,
    customer_id       INT           NOT NULL,
    created_at        DATETIME2(0)  NOT NULL,
    priority          VARCHAR(10)   NOT NULL,
    channel           VARCHAR(10)   NOT NULL,
    CONSTRAINT PK_src_tickets PRIMARY KEY CLUSTERED (ticket_id),
    CONSTRAINT FK_src_tickets_customers FOREIGN KEY (customer_id) REFERENCES dbo.customers (customer_id)
);
GO
IF OBJECT_ID(N'dbo.ticket_details', N'U') IS NULL
CREATE TABLE dbo.ticket_details (
    ticket_id         INT           NOT NULL,
    ticket_name       NVARCHAR(200) NOT NULL,
    ticket_type       VARCHAR(30)   NOT NULL,
    severity          VARCHAR(10)   NOT NULL,
    description       NVARCHAR(500) NOT NULL,
    CONSTRAINT PK_src_ticket_details PRIMARY KEY CLUSTERED (ticket_id),
    CONSTRAINT FK_src_ticket_details_tickets FOREIGN KEY (ticket_id) REFERENCES dbo.tickets (ticket_id)
);
GO
IF OBJECT_ID(N'dbo.ticket_status_history', N'U') IS NULL
CREATE TABLE dbo.ticket_status_history (
    status_event_id     INT          NOT NULL,
    ticket_id           INT          NOT NULL,
    status              VARCHAR(20)  NOT NULL,
    status_at           DATETIME2(0) NOT NULL,
    changed_by_agent_id INT          NULL,
    status_reason       VARCHAR(100) NULL,
    CONSTRAINT PK_src_ticket_status_history PRIMARY KEY CLUSTERED (status_event_id),
    CONSTRAINT FK_src_status_tickets FOREIGN KEY (ticket_id) REFERENCES dbo.tickets (ticket_id),
    CONSTRAINT FK_src_status_agents FOREIGN KEY (changed_by_agent_id) REFERENCES dbo.support_agents (agent_id)
);
GO
IF OBJECT_ID(N'dbo.ticket_breakdown', N'U') IS NULL
CREATE TABLE dbo.ticket_breakdown (
    breakdown_id          INT           NOT NULL,
    ticket_id             INT           NOT NULL,
    occurred_at           DATETIME2(0)  NOT NULL,
    breakdown_category    VARCHAR(30)   NOT NULL,
    component_name        VARCHAR(60)   NOT NULL,
    effort_minutes        INT           NOT NULL,
    cost_egp              DECIMAL(12,2) NOT NULL,
    breakdown_description NVARCHAR(300) NOT NULL,
    CONSTRAINT PK_src_ticket_breakdown PRIMARY KEY CLUSTERED (breakdown_id),
    CONSTRAINT FK_src_breakdown_tickets FOREIGN KEY (ticket_id) REFERENCES dbo.tickets (ticket_id)
);
GO
IF OBJECT_ID(N'dbo.customer_stability_observations', N'U') IS NULL
CREATE TABLE dbo.customer_stability_observations (
    customer_id       INT           NOT NULL,
    snapshot_date     DATE          NOT NULL,
    stability_status  VARCHAR(20)   NOT NULL,
    CONSTRAINT PK_src_customer_stability_observations PRIMARY KEY CLUSTERED (customer_id, snapshot_date),
    CONSTRAINT FK_src_obs_customers FOREIGN KEY (customer_id) REFERENCES dbo.customers (customer_id),
    CONSTRAINT FK_src_obs_levels FOREIGN KEY (stability_status) REFERENCES dbo.stability_levels (stability_status)
);
GO
IF OBJECT_ID(N'dbo.ticket_agent_assignments', N'U') IS NULL
CREATE TABLE dbo.ticket_agent_assignments (
    assignment_id     INT           NOT NULL,
    ticket_id         INT           NOT NULL,
    agent_id          INT           NOT NULL,
    started_at        DATETIME2(0)  NOT NULL,
    ended_at          DATETIME2(0)  NULL,          -- NULL = still active at the batch cutoff; half-open interval [started_at, ended_at)
    CONSTRAINT PK_src_ticket_agent_assignments PRIMARY KEY CLUSTERED (assignment_id),
    CONSTRAINT FK_src_asg_tickets FOREIGN KEY (ticket_id) REFERENCES dbo.tickets (ticket_id),
    CONSTRAINT FK_src_asg_agents FOREIGN KEY (agent_id) REFERENCES dbo.support_agents (agent_id)
);
GO
SELECT t.name AS table_name, COUNT(c.column_id) AS column_count
FROM sys.tables AS t JOIN sys.columns AS c ON c.object_id = t.object_id
WHERE SCHEMA_NAME(t.schema_id) = 'dbo' GROUP BY t.name ORDER BY t.name;
GO
