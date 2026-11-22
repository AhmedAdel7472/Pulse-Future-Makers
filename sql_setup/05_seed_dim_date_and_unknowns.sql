/* ============================================================================
   05_seed_dim_date_and_unknowns.sql
   TechnicalSupport_DW : static reference members that are NOT loaded by the labs
     - dim.DimDate for calendar year 2025 (the training data never leaves 2025)
     - dim.DimTicketType 'Unknown' member (key -1) for tickets without ticket_details
     - etl.ref_StabilityLevel (five stability labels and ranks)
   Re-runnable (inserts only what is missing).
   ============================================================================ */
USE TechnicalSupport_DW;
GO
SET NOCOUNT ON;
GO
;WITH d AS (
    SELECT CAST('2025-01-01' AS DATE) AS dt
    UNION ALL
    SELECT DATEADD(DAY, 1, dt) FROM d WHERE dt < '2025-12-31'
)
INSERT INTO dim.DimDate (date_key, full_date, [year], [quarter], [month], month_name, day_of_month)
SELECT CAST(CONVERT(CHAR(8), dt, 112) AS INT), dt, YEAR(dt), DATEPART(QUARTER, dt), MONTH(dt), FORMAT(dt, 'MMMM', 'en-US'), DAY(dt)
FROM d
WHERE NOT EXISTS (SELECT 1 FROM dim.DimDate x WHERE x.full_date = d.dt)
OPTION (MAXRECURSION 400);
GO
IF NOT EXISTS (SELECT 1 FROM dim.DimTicketType WHERE ticket_type_key = -1)
BEGIN
    SET IDENTITY_INSERT dim.DimTicketType ON;
    INSERT INTO dim.DimTicketType (ticket_type_key, ticket_type) VALUES (-1, 'Unknown');
    SET IDENTITY_INSERT dim.DimTicketType OFF;
END
GO
INSERT INTO etl.ref_StabilityLevel (stability_status, stability_rank)
SELECT v.s, v.r FROM (VALUES ('very stable', 1), ('stable', 2), ('natural', 3), ('unstable', 4), ('very unstable', 5)) AS v (s, r)
WHERE NOT EXISTS (SELECT 1 FROM etl.ref_StabilityLevel x WHERE x.stability_status = v.s);
GO
SELECT (SELECT COUNT(*) FROM dim.DimDate) AS dim_date_rows, (SELECT COUNT(*) FROM dim.DimTicketType) AS ticket_type_rows, (SELECT COUNT(*) FROM etl.ref_StabilityLevel) AS stability_levels;
GO
