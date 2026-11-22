# Lab 05 - Incremental Loading and Reprocessing

**Difficulty:** Expert (5 of 5)  |  **Estimated effort:** 10 hours  |  **Mode:** hands-on in Visual Studio (SSIS); T-SQL only where the lab says so

## 1. Business scenario

Operations now sends small batches (Batch 1 for July 1-8 and Batch 2 for July 9-15). The warehouse has to take each batch exactly once and in order, insert new rows, update the rows that changed, reject invalid rows, survive a rerun, and never move its watermark unless the whole batch succeeded.

## 2. Learning objectives

- Design an incremental load from a batch manifest, a watermark and unique business keys
- Insert new rows and update changed ones (priority changes, closed intervals, new status events, late arrivals)
- Loop over pending batches with a Foreach Loop and process them in order
- Skip an already processed batch and prove that a forced reprocess creates no duplicates
- Advance the watermark only after every dependent load succeeded
- Reconcile each batch by classifying every SOURCE row exactly once: rejected, new, changed or unchanged

## 3. Prerequisites

- Labs 1-4 finished (staging, cleansing, initial load, SCD)
- DW loaded with Batch 0 (Lab 3) and `etl.ETL_Watermark` containing the row `pipeline_name = 'TechnicalSupport'`, `last_batch_id = 0`, `last_cutoff_ts` = the cutoff of batch 0 (you insert it yourself at the end of Lab 3, as the last task, once every load of batch 0 succeeded)
- docs/05_Incremental_Loading_Design.md read

## 4. Input files / sources

- data/batch_01_delta/*.csv (9 files incl. manifest)
- data/batch_02_delta/*.csv (9 files incl. manifest)

## 5. Source and destination

- **Source:** Delta batch folders
- **Destination:** All dimensions, facts, history tables, etl.ETL_BatchManifest, etl.ETL_BatchLog, etl.ETL_Rejects, etl.ETL_Watermark

## 6. Required operations (exactly what you must build)

### 1. Design (write it down first)

- What identifies a ROW (business key per table) and what identifies a BATCH (batch_id from the manifest, folder, cutoff)? How is a new row told from a changed row from a repeated row? What happens if the package fails halfway? What happens on a rerun? When does the watermark advance? Put your answers in one page - you will be asked to defend it.

### 2. Child package `Lab05_LoadBatch` (parameter BatchId)

- Pre-checks (Execute SQL Task + precedence expressions): batch already processed (watermark >= BatchId) -> log 'Skipped' and end successfully; previous batch not done (watermark < BatchId - 1) -> fail with a clear message.
- Read the batch definition from the manifest: folder, `processing_date`, `cutoff_ts` (variables). Clean this batch's rows from `stg.*`, `etl.ETL_Rejects` and the manifest rows (rerun safety).
- Stage all eight data files with the stage-1 cleansing of Lab 2 (parameterise: folder from the batch, file name per data flow). Reconcile each file against the manifest (staged + stage-1 rejects = source_row_count).
- Load in dependency order: DimAgent (Type 1 upsert), DimCustomer (Lab 4 pattern; effective dates from the file), tickets header (new -> insert with the customer version valid on the creation date; existing with a different priority/channel -> update only these columns), ticket details (+ new ticket types), status events (insert new), observations (insert new), assignments (new -> insert; an open interval that now has an end -> update), breakdowns (insert new with the point-in-time lookups of Lab 3), then recompute the lifecycle measures of FactTicket for the cutoff of the batch (only rows whose values changed are updated).
- Stage-2 rejects (unknown customer/ticket/agent, duplicates) go to `etl.ETL_Rejects`; late-arriving rows (status events/breakdowns/metadata for earlier dates) are loaded normally.
- Last tasks: success log row with counts; advance the watermark (ONLY after all loads succeeded).

### 3. Parent package `Lab05_Master`

- Foreach Loop Container (ADO.NET/ADO enumerator or Foreach Item) over `SELECT batch_id FROM etl.ETL_BatchManifest GROUP BY batch_id HAVING batch_id > (watermark) ORDER BY batch_id`, mapping the value to `User::BatchId`; inside it an Execute Package Task runs the child with the BatchId parameter. (Make the manifests of batches 1 and 2 available in `etl.ETL_BatchManifest` first - from the batch folders.)

### 4. Test sequence (do all of it)

- Run for Batch 1 and check the reconciliation. Run for Batch 2. Check every table against your expectations (new tickets, updated priorities, reopened tickets, late metadata, repeated rows ignored).
- RERUN the master package: the already processed batches must be skipped and logged 'Skipped'.
- FORCED reprocess: set the watermark back by one batch, run again: row counts of every table, the number of customer versions and the total cost must be identical before and after.
- Write down the batch summary for both batches: source / rejected / new / changed / unchanged per entity.

## 7. Expected output structure

Warehouse state after Batch 1 and after Batch 2; per-batch summary; etl.ETL_BatchLog with Succeeded/Skipped rows; etl.ETL_Watermark = last processed batch.

## 8. Acceptance criteria

- [ ] For each batch and each file: source rows = rejected + new + changed + unchanged (your own table; every source row is classified once. A Type 2 customer change is ONE changed row even though it causes one UPDATE and one INSERT in the dimension)
- [ ] Invalid rows of the batches are rejected and logged; valid rows around them are loaded
- [ ] Existing tickets receive their updates (priority, status, resolutions, reopen count) without creating duplicates; fact keys never change
- [ ] Type 2 history for customers is created at the effective dates; earlier facts keep the old version
- [ ] Rerun of a processed batch: skipped. Forced reprocess: NO change in any count, no duplicate keys, no extra customer versions, same total cost/effort
- [ ] The watermark advances only after a successful batch and never moves backwards by itself; a failed batch can simply be rerun

## 9. SSIS components used (and why)

| Component | Meaningful use in this lab |
|---|---|
| Foreach Loop Container | Process every pending batch listed in the manifest table, in order |
| Execute SQL Task | Clean a batch before reloading, read manifest/watermark, set-based SCD updates, advance the watermark, write the audit log |
| Precedence Constraints | Success / failure / expression constraints: reconcile counts, skip an already processed batch, advance the watermark last |
| Variables | BatchId, CutoffTs, folder/file names, row counts, flags used in expressions |
| Parameters | Project/package parameters: ServerName, DataRoot, BatchId - nothing environment specific is hard-coded |
| Flat File Source | Read every CSV as text so that bad values reach YOUR validation instead of failing inside the source |
| Lookup | Priority map, stability labels, customer / ticket / agent existence, surrogate keys and point-in-time lookups |
| Conditional Split | Route rows to accepted / rejected / NEW / TYPE-2 / TYPE-1 / UNCHANGED outputs |
| Row Count | Capture source / loaded / rejected counts into variables for reconciliation and logging |
| OLE DB Destination | Fast-load staging, dimension, fact, history and reject tables |
| Error Output / Reject destination | Redirect bad rows (not fail the package) and log the reason to etl.ETL_Rejects |
| Derived Column | Trim/collapse text, blank -> NULL, add batch_id, source_file, reason_code, computed keys and minutes |

## 10. Hints (not answers)

- Make every step a 'make it so' statement (insert if missing, update if different) instead of a blind insert - then a rerun is naturally harmless.
- Clean the staging rows of the batch FIRST, always.
- A repeated row in a later batch is not an error: it is 'unchanged'.
- Batch 2 contains data that belongs to earlier time (late arrivals) and rows that change existing tickets.

## 11. Submission checklist

- [ ] Project with `Lab05_*` packages
- [ ] Design page (step 1)
- [ ] Batch summaries (Batch 1, Batch 2) and the rerun / forced-reprocess evidence (counts before/after)
- [ ] A paragraph: what would break if the watermark were advanced at the START of the load?
