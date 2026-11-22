/* ============================================================================
   95_student_selfcheck.sql
   A SMALL set of generic sanity queries. It contains NO expected row counts, NO answers, and deliberately NOT the checks you are asked to write
   yourself (SCD invariants in Lab 4, point-in-time and lifecycle checks in Lab 3, reconciliation in Labs 3 and 5).
   "Expect 0 rows" = the query lists problems, so an empty result is good. Run each query on its own. Re-runnable, read-only.
   ============================================================================ */
USE TechnicalSupport_DW;
GO
-- S1. Duplicate business keys in the facts (expect 0 rows from each of the three queries)
SELECT ticket_id, COUNT(*) AS n FROM fact.FactTicket GROUP BY ticket_id HAVING COUNT(*) > 1;
SELECT breakdown_id, COUNT(*) AS n FROM fact.FactTicketBreakdown GROUP BY breakdown_id HAVING COUNT(*) > 1;
SELECT status_event_id, COUNT(*) AS n FROM fact.FactTicketStatusEvent GROUP BY status_event_id HAVING COUNT(*) > 1;
GO
-- S2. Breakdowns pointing to a ticket that is not in FactTicket (expect 0 rows)
SELECT b.breakdown_id, b.ticket_id FROM fact.FactTicketBreakdown b LEFT JOIN fact.FactTicket t ON t.ticket_id = b.ticket_id WHERE t.ticket_id IS NULL;
GO
-- S3. Reject log hygiene: every reject has a reason code (expect 0 rows)
SELECT reject_id, batch_id, source_file FROM etl.ETL_Rejects WHERE reason_code IS NULL OR LTRIM(RTRIM(reason_code)) = '';
GO
-- S4. Reconciliation helper: announced rows and logged rejects per batch and file (YOU compare these with what you staged)
SELECT m.batch_id, m.file_name, m.source_row_count,
       (SELECT COUNT(*) FROM etl.ETL_Rejects r WHERE r.batch_id = m.batch_id AND r.source_file = m.file_name) AS rejected_rows
FROM etl.ETL_BatchManifest m ORDER BY m.batch_id, m.file_name;
GO
-- S5. Audit log: runs still marked Running, or Failed (look at them; a finished pipeline normally has no Running row)
SELECT batch_log_id, batch_id, package_name, status, start_time, end_time, error_summary FROM etl.ETL_BatchLog WHERE status IN ('Running', 'Failed');
GO
-- S6. Watermark (one row per pipeline)
SELECT * FROM etl.ETL_Watermark;
GO
