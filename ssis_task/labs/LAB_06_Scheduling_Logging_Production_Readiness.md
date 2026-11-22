# Lab 06 - Scheduling, Logging and Production Readiness

**Difficulty:** Advanced (4 of 5)  |  **Estimated effort:** 6 hours  |  **Mode:** hands-on in Visual Studio (SSIS); T-SQL only where the lab says so

## 1. Business scenario

The pipeline must run without a developer: on a schedule or when a new batch folder arrives, log every run, fail loudly and safely, and be recoverable by someone who did not write it.

## 2. Learning objectives

- Build one master package that is configured only through parameters
- Log every run (and every failure) to etl.ETL_BatchLog with an OnError event handler
- Run the package from the command line with dtexec
- Describe and set up a SQL Server Agent schedule and a file-arrival wrapper (Task Scheduler + script + dtexec)
- Execute a controlled failure and a clean recovery
- Document the operation (runbook page)

## 3. Prerequisites

- Lab 5 finished and working
- docs/06_Scheduling_and_Operations.md read (edition and version requirements)
- `scripts/Run-TechSupportBatch.template.ps1` (a skeleton with TODO markers)

## 4. Input files / sources

- Batch folders of Lab 5
- `scripts/Run-TechSupportBatch.template.ps1`

## 5. Source and destination

- **Source:** Packages of Lab 5
- **Destination:** Integration Services project deployed (SSISDB) or package files for dtexec; etl.ETL_BatchLog; operations notes

## 6. Required operations (exactly what you must build)

### 1. Master package

- Parameters: `ServerName`, `DataRoot`, `BatchId` (optional: 0 = 'all pending batches'). Remove every literal path/server. The master calls the Lab 5 logic.

### 2. Logging and failure handling

- Execute SQL Task at the start: insert a `Running` row into `etl.ETL_BatchLog` and keep the new `batch_log_id` in a variable. At the end: update to `Succeeded` with the counts. OnError event handler on the package: update the row to `Failed` with `error_summary` = the error description (truncate to 2000). Nothing in the handler may advance the watermark.
- Rejected rows are NOT failures: the run is `Succeeded` and reports the reject count.

### 3. Run it without Visual Studio

- Run the package with `dtexec` (file system or SSISDB). Write down the exact command you used and the exit code you saw. (Check the syntax in the documentation of your SQL Server version - it differs between package and project deployment.)

### 4. Scheduling (set up and document - do not just describe)

- Option 1 - manual: how to run it from SSMS/SSDT/dtexec.
- Option 2 - SQL Server Agent: create a job with an SSIS package step (or a CmdExec step calling dtexec) and a schedule (for example every night). Requires SQL Server Agent: write down which SQL Server editions include it.
- Option 3 - file arrival: complete the PowerShell wrapper (polls the drop folder for a NEW batch folder whose `batch_manifest.csv` exists - the manifest is written LAST and acts as the 'ready' marker; checks the watermark; calls dtexec; returns an exit code) and register it with Windows Task Scheduler to run every few minutes. Event handlers (OnError, OnPreExecute) are NOT triggers for file arrival.
- Explain which option you would choose for this company and why.

### 5. Controlled failure and recovery (all three)

- FAIL-1 (bad input): copy `batch_02_delta` to a new folder, damage ONE data file in a way of your choice (for example rename a header column or delete rows so the manifest count no longer matches). Run the batch. Expected: the run is logged `Failed` with a readable message, the watermark does not move, the warehouse is not left half-loaded for that batch.
- FAIL-2 (failure in the middle): add a task that fails (for example `SELECT 1/0`) AFTER the dimension loads and BEFORE the watermark task. Run, observe, then remove the task and rerun the same batch. Expected: no duplicates, final counts identical to an uninterrupted run.
- FAIL-3 (environment): make the file folder unavailable (rename it) - the package must fail cleanly; restore it and rerun.
- For each failure record: what happened, where you found it (log table/Output), what you did, how you proved the recovery.

### 6. Runbook page

- One page: purpose, parameters, how to run, schedule, how to read the log, what to do on failure, how to reprocess a batch, who to call. Written for a colleague who has never seen the project.

## 7. Expected output structure

A deployable project, a working run command, a documented schedule/wrapper, evidence of three failure/recovery tests, a runbook page.

## 8. Acceptance criteria

- [ ] Every run produces exactly one etl.ETL_BatchLog row with batch id, package name, start/end, status, source/inserted/updated/rejected counts and error summary
- [ ] A failed run is logged Failed with the real error text and does not advance the watermark
- [ ] The command-line run works with parameters and returns exit code 0 on success and non-zero on failure
- [ ] The wrapper script / schedule description does NOT use OnError/OnPreExecute handlers as file-arrival triggers and states the edition/version requirements
- [ ] After each recovery test the table counts equal those of an uninterrupted run (no duplicates, no missing rows)
- [ ] The runbook allows a stranger to rerun a failed batch

## 9. SSIS components used (and why)

| Component | Meaningful use in this lab |
|---|---|
| Event Handlers | OnError writes the failure to ETL_BatchLog; (not a file-arrival trigger) |
| Precedence Constraints | Success / failure / expression constraints: reconcile counts, skip an already processed batch, advance the watermark last |
| Parameters | Project/package parameters: ServerName, DataRoot, BatchId - nothing environment specific is hard-coded |
| Variables | BatchId, CutoffTs, folder/file names, row counts, flags used in expressions |
| Execute SQL Task | Clean a batch before reloading, read manifest/watermark, set-based SCD updates, advance the watermark, write the audit log |
| Row Count | Capture source / loaded / rejected counts into variables for reconciliation and logging |

## 10. Hints (not answers)

- `ETL_BatchLog.status` allows Running, Succeeded, Failed, Skipped.
- An OnError handler runs once per error event: a single failure can fire it several times - write the update so that repeating it is harmless.
- Keep the 'Failed' log update independent of the data flow that failed.

## 11. Submission checklist

- [ ] Project and the exact dtexec command line
- [ ] Agent job definition (screenshots or script) OR Task Scheduler registration + completed wrapper
- [ ] Failure/recovery evidence table (3 tests)
- [ ] Runbook page
- [ ] Statement of what you did NOT test (e.g. no SQL Server Agent available) - be honest
