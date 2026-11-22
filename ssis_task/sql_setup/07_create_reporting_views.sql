/* ============================================================================
   07_create_reporting_views.sql
   TechnicalSupport_DW : reporting layer (schema rpt). Run once the DW tables exist; it is part of the target model you load INTO,
   not an exercise. Re-runnable (CREATE OR ALTER).
   GRAINS
     rpt.vw_TicketOperations             one row per ticket
     rpt.vw_BreakdownAnalysis            one row per breakdown event
     rpt.vw_CustomerMonthlyPerformance   one row per customer x calendar month that has at least one ticket or one breakdown
   The breakdown measures are pre-aggregated per ticket / per customer-month BEFORE they are joined, so no row is multiplied (no fan-out)
   and cost / effort are counted exactly once.
   ============================================================================ */
USE TechnicalSupport_DW;
GO
CREATE OR ALTER VIEW rpt.vw_TicketOperations AS
SELECT  f.ticket_id,
        CAST(f.created_at AS DATE)        AS created_date,
        f.created_at,
        YEAR(f.created_at)                AS [year],
        MONTH(f.created_at)               AS [month],
        c.customer_id,
        c.customer_name,
        c.customer_segment,
        c.region                          AS customer_region,      -- customer version valid when the ticket was created
        t.ticket_type,
        f.severity,
        f.priority,
        f.channel,
        f.latest_status,
        f.first_resolution_at,
        f.last_resolution_at,
        f.final_closed_at,
        f.resolution_minutes,
        f.reopen_count,
        f.is_resolved,
        COALESCE(b.breakdown_count, 0)       AS breakdown_count,
        COALESCE(b.total_effort_minutes, 0)  AS total_effort_minutes,
        COALESCE(b.total_cost_egp, 0)        AS total_cost_egp
FROM fact.FactTicket AS f
JOIN dim.DimCustomer   AS c ON c.customer_key = f.customer_key
JOIN dim.DimTicketType AS t ON t.ticket_type_key = f.ticket_type_key
LEFT JOIN (SELECT ticket_id, COUNT(*) AS breakdown_count, SUM(effort_minutes) AS total_effort_minutes, SUM(cost_egp) AS total_cost_egp
           FROM fact.FactTicketBreakdown GROUP BY ticket_id) AS b ON b.ticket_id = f.ticket_id;
GO
CREATE OR ALTER VIEW rpt.vw_BreakdownAnalysis AS
SELECT  b.breakdown_id,
        b.ticket_id,
        b.occurred_at,
        CAST(b.occurred_at AS DATE)       AS event_date,
        c.customer_id,
        c.customer_name,
        c.customer_segment,
        c.region                          AS customer_region,      -- customer version valid on the event date
        a.agent_id,
        a.agent_name,
        a.team                            AS agent_team,
        t.ticket_type,
        f.priority                        AS ticket_priority,
        b.breakdown_category,
        b.component_name,
        b.ticket_status_at_event,
        COALESCE(b.customer_stability_at_event, 'Unknown') AS customer_stability_at_event,
        b.effort_minutes,
        b.cost_egp
FROM fact.FactTicketBreakdown AS b
JOIN fact.FactTicket   AS f ON f.ticket_id = b.ticket_id
JOIN dim.DimCustomer   AS c ON c.customer_key = b.customer_key
JOIN dim.DimTicketType AS t ON t.ticket_type_key = f.ticket_type_key
LEFT JOIN dim.DimAgent AS a ON a.agent_key = b.agent_key;
GO
CREATE OR ALTER VIEW rpt.vw_CustomerMonthlyPerformance AS
SELECT  m.customer_id,
        cur.customer_name,                                         -- Type 1 attribute: same in every version
        m.[year], m.[month],
        COALESCE(tk.tickets_created, 0)        AS tickets_created,
        COALESCE(bk.breakdown_events, 0)       AS breakdown_events,
        COALESCE(bk.total_effort_minutes, 0)   AS total_effort_minutes,
        COALESCE(bk.total_cost_egp, 0)         AS total_cost_egp
FROM (
        SELECT c.customer_id, YEAR(f.created_at) AS [year], MONTH(f.created_at) AS [month]
        FROM fact.FactTicket f JOIN dim.DimCustomer c ON c.customer_key = f.customer_key
        UNION
        SELECT c.customer_id, YEAR(b.occurred_at), MONTH(b.occurred_at)
        FROM fact.FactTicketBreakdown b JOIN dim.DimCustomer c ON c.customer_key = b.customer_key
     ) AS m
JOIN dim.DimCustomer AS cur ON cur.customer_id = m.customer_id AND cur.is_current = 1
LEFT JOIN (SELECT c.customer_id, YEAR(f.created_at) AS [year], MONTH(f.created_at) AS [month], COUNT(*) AS tickets_created
           FROM fact.FactTicket f JOIN dim.DimCustomer c ON c.customer_key = f.customer_key
           GROUP BY c.customer_id, YEAR(f.created_at), MONTH(f.created_at)) AS tk
       ON tk.customer_id = m.customer_id AND tk.[year] = m.[year] AND tk.[month] = m.[month]
LEFT JOIN (SELECT c.customer_id, YEAR(b.occurred_at) AS [year], MONTH(b.occurred_at) AS [month], COUNT(*) AS breakdown_events,
                  SUM(b.effort_minutes) AS total_effort_minutes, SUM(b.cost_egp) AS total_cost_egp
           FROM fact.FactTicketBreakdown b JOIN dim.DimCustomer c ON c.customer_key = b.customer_key
           GROUP BY c.customer_id, YEAR(b.occurred_at), MONTH(b.occurred_at)) AS bk
       ON bk.customer_id = m.customer_id AND bk.[year] = m.[year] AND bk.[month] = m.[month];
GO
