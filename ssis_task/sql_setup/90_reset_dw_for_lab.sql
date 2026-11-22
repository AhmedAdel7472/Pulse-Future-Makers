/* ============================================================================
   90_reset_dw_for_lab.sql
   Empties the DATA of TechnicalSupport_DW so a lab can be started again from scratch. It keeps databases, schemas, tables, constraints,
   DimDate, the 'Unknown' ticket type and etl.ref_StabilityLevel. It does NOT touch TechnicalSupport_Source.
   Choose ONE reset level by setting @level:
       1 = facts + history + staging + audit/control only (dimensions are kept; use it to repeat the fact loads)
       2 = EVERYTHING loaded (dimensions too)  -> start Lab 3 again
   etl.ref_PriorityMap (loaded in Lab 2) is kept at both levels.
   Re-runnable. Run it only on your own training server.
   ============================================================================ */
USE TechnicalSupport_DW;
GO
SET NOCOUNT ON;
GO
DECLARE @level INT = 2;

DELETE FROM fact.FactTicketBreakdown;
DELETE FROM hist.HistAgentAssignment;
DELETE FROM fact.FactTicketStatusEvent;
DELETE FROM hist.HistCustomerStability;
DELETE FROM fact.FactTicket;
DELETE FROM stg.customer_snapshot;      DELETE FROM stg.support_agents;           DELETE FROM stg.tickets;                 DELETE FROM stg.ticket_details;
DELETE FROM stg.ticket_status_history;  DELETE FROM stg.ticket_breakdown;         DELETE FROM stg.customer_stability_observations;   DELETE FROM stg.ticket_agent_assignments;
DELETE FROM etl.ETL_Rejects;  DELETE FROM etl.ETL_BatchLog;  DELETE FROM etl.ETL_Watermark;  DELETE FROM etl.ETL_BatchManifest;

IF @level >= 2
BEGIN
    DELETE FROM dim.DimCustomer;
    DELETE FROM dim.DimAgent;
    DELETE FROM dim.DimTicketType WHERE ticket_type_key <> -1;
    DBCC CHECKIDENT ('dim.DimCustomer', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dim.DimAgent', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dim.DimTicketType', RESEED, 0) WITH NO_INFOMSGS;
END
DBCC CHECKIDENT ('etl.ETL_BatchLog', RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('etl.ETL_Rejects', RESEED, 0) WITH NO_INFOMSGS;
PRINT 'Reset level ' + CAST(@level AS VARCHAR(1)) + ' done.';
GO
SELECT 'dim.DimCustomer' AS table_name, COUNT(*) AS row_count FROM dim.DimCustomer UNION ALL SELECT 'dim.DimTicketType', COUNT(*) FROM dim.DimTicketType
UNION ALL SELECT 'fact.FactTicket', COUNT(*) FROM fact.FactTicket UNION ALL SELECT 'etl.ETL_Rejects', COUNT(*) FROM etl.ETL_Rejects UNION ALL SELECT 'dim.DimDate', COUNT(*) FROM dim.DimDate;
GO
