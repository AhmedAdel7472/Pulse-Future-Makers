# Lab 02 - Transformation, Cleansing and Reject Handling

**Difficulty:** Intermediate (2 of 5)  |  **Estimated effort:** 5 hours  |  **Mode:** hands-on in Visual Studio (SSIS); T-SQL only where the lab says so

## 1. Business scenario

A new vendor feed arrives with typical real-world dirt: stray spaces, priority labels such as P1 or 'URGENT', impossible dates, negative costs, orphan references and repeated rows. The warehouse must not fail and must not silently load rubbish: every bad row has to be detected, redirected, logged WITH a reason, and the good rows must continue. At the end the counts must reconcile: rows read = rows accepted + rows rejected.

## 2. Learning objectives

- Trim, normalise and standardise text with Derived Column expressions
- Detect blank, non-numeric, non-date and out-of-range values and redirect them (not fail)
- Use Lookup transformations against reference tables, including the no-match output
- Detect duplicate business keys and keep the first occurrence
- Merge several reject streams with Union All and write one reject log (etl.ETL_Rejects) with reason codes
- Summarise rejects with Aggregate and reconcile all counts

## 3. Prerequisites

- Lab 1 finished (connections, parameters, staging pattern)
- Reject codes and precedence of docs/04_Target_Model_and_Rules.md read
- `etl.ref_PriorityMap` is empty at the start: you load it in step 1

## 4. Input files / sources

- data/reference_data/priority_label_map.csv
- data/invalid_examples/customers_dirty.csv
- data/invalid_examples/tickets_dirty.csv
- data/invalid_examples/ticket_breakdown_dirty.csv
- data/invalid_examples/customer_stability_observations_dirty.csv
- data/invalid_examples/ticket_status_history_dirty.csv
- data/invalid_examples/batch_manifest.csv (batch 99)

## 5. Source and destination

- **Source:** Flat files (dirty fixture, treated as batch 99) + reference tables
- **Destination:** TechnicalSupport_DW: etl.ref_PriorityMap, stg.* (accepted rows, batch_id = 99), etl.ETL_Rejects, etl.ETL_BatchLog

## 6. Required operations (exactly what you must build)

### 1. Reference data

- Load `priority_label_map.csv` into `etl.ref_PriorityMap` (small data flow; make it re-runnable).
- Reference tables for the existence checks of THIS lab: use the BASELINE tables in `TechnicalSupport_Source` (`dbo.customers`, `dbo.tickets`, `dbo.support_agents`), because the warehouse dimensions are not loaded yet. Stability labels: `etl.ref_StabilityLevel`.

### 2. Stage-1 checks (one data flow per file)

- Read every column as text (`DT_WSTR`). Derived Column: trim every text column, collapse repeated inner spaces in names/components to ONE space, turn empty strings into NULL, upper-case a copy of `priority` for the lookup.
- Conditional Split `BLANK_REQUIRED`: any required column that is NULL/empty (see the Required column of the Student Mapping workbook).
- Data Conversion for the numeric columns with its ERROR OUTPUT redirected -> reason `INVALID_NUMBER`. A SECOND Data Conversion for date/timestamp columns with error output redirected -> `INVALID_DATE` (two steps, so the reason is unambiguous).
- Priority: Lookup `UPPER(priority)` in `etl.ref_PriorityMap`; no match -> `UNSUPPORTED_VALUE`; match -> use the mapped canonical priority (P1 becomes Critical). Remember that a full-cache Lookup compares case-sensitively.
- Conditional Split for domain rules: segment, region, channel (list checks) -> `UNSUPPORTED_VALUE`; `effort_minutes <= 0` or `cost_egp < 0` -> `NEGATIVE_VALUE`; stability label (Lookup on `etl.ref_StabilityLevel`, no match) -> `INVALID_STABILITY`; `ended_at <= started_at` -> `BAD_INTERVAL` where that column exists.
- Accepted rows continue to the staging table of the file with `batch_id = 99` and `source_file` filled in (OLE DB Destination).

### 3. Stage-2 checks (references and duplicates)

- For the accepted rows of tickets, status events, breakdowns and observations: Lookup the referenced customer / ticket / agent in the reference tables; the no-match output is a reject with `UNKNOWN_CUSTOMER`, `UNKNOWN_TICKET` or `UNKNOWN_AGENT`. A status event with NULL `changed_by_agent_id` is valid.
- Duplicates: the second and later occurrences of a business key inside one file are rejected with `DUPLICATE_KEY`; the first occurrence is kept. (`stg.*.source_row_number` gives you the arrival order. Use a source query with `ROW_NUMBER()` or a Sort/Aggregate pattern - your choice, be ready to explain it.) Business keys: customer_id; ticket_id; breakdown_id; status_event_id; (customer_id, snapshot_date).
- Apply the precedence of docs/04: a row is logged ONCE, with the FIRST rule it fails.

### 4. One reject log

- Every reject branch goes through a Derived Column that sets `batch_id`, `source_file`, `business_key` (text; for observations `customer_id|snapshot_date`), `reason_code` and `raw_row` (the original text of the row), then a Union All, then ONE OLE DB Destination into `etl.ETL_Rejects`.
- Use a Multicast + Row Count to count accepted and rejected rows per file into variables.

### 5. Summary and audit

- A final data flow reads `etl.ETL_Rejects` for batch 99 and uses Aggregate (GROUP BY `source_file`, `reason_code`, COUNT) to produce a summary you can show (grid viewer or table of your choice).
- Write one row into `etl.ETL_BatchLog` for the package run (batch_id 99, package name, start/end, status, source/inserted/rejected counts, error summary) with an Execute SQL Task at the end.

## 7. Expected output structure

etl.ETL_Rejects with one row per rejected source row (batch_id, source_file, business_key, reason_code, raw_row, rejected_at); stg.* holding only accepted rows for batch 99; etl.ETL_BatchLog with one row; the Aggregate summary.

## 8. Acceptance criteria

- [ ] For EVERY dirty file: rows read = rows accepted + rows rejected (show the table)
- [ ] The package never fails because of a bad row, and continues loading the good rows
- [ ] All eight defect classes are detected and logged with the correct reason code: blank required field, invalid date, missing customer reference, duplicate key, invalid number, unsupported priority, negative effort/cost, invalid stability
- [ ] Priority aliases (P1..P4, different case, surrounding spaces) are normalised to Low/Medium/High/Critical in the accepted rows; names have no leading/trailing/double spaces
- [ ] No row appears twice in etl.ETL_Rejects; every reject has a reason code, a source file and a business key
- [ ] Running the package twice gives identical counts (clean batch 99 first)

## 9. SSIS components used (and why)

| Component | Meaningful use in this lab |
|---|---|
| Flat File Source | Read every CSV as text so that bad values reach YOUR validation instead of failing inside the source |
| Derived Column | Trim/collapse text, blank -> NULL, add batch_id, source_file, reason_code, computed keys and minutes |
| Data Conversion | Convert text to INT / DATE / DATETIME / DECIMAL; its error output feeds INVALID_NUMBER / INVALID_DATE rejects |
| Lookup | Priority map, stability labels, customer / ticket / agent existence, surrogate keys and point-in-time lookups |
| Conditional Split | Route rows to accepted / rejected / NEW / TYPE-2 / TYPE-1 / UNCHANGED outputs |
| Union All | Combine the reject branches of several checks into one reject stream |
| Multicast | Send the same rows to two destinations (accepted rows + audit counting / summary) |
| Row Count | Capture source / loaded / rejected counts into variables for reconciliation and logging |
| Aggregate | DISTINCT ticket types, reject summary by reason, per-ticket MIN/MAX/COUNT of status events |
| OLE DB Destination | Fast-load staging, dimension, fact, history and reject tables |
| Error Output / Reject destination | Redirect bad rows (not fail the package) and log the reason to etl.ETL_Rejects |
| Execute SQL Task | Clean a batch before reloading, read manifest/watermark, set-based SCD updates, advance the watermark, write the audit log |

## 10. Hints (not answers)

- Redirect, do not ignore: set the Error output of Data Conversion to 'Redirect row'. 'Ignore failure' would load NULLs.
- The Lookup 'no match' behaviour must be 'Redirect rows to no match output' (default is 'Fail component').
- `ERROR_CODE`/`ERROR_COLUMN` columns of an error output are numbers; you do not need to translate them - the reason code comes from the branch you are on.
- Keep the original text of the row for `raw_row` BEFORE you change anything.

## 11. Submission checklist

- [ ] Project with `Lab02_*` packages
- [ ] Reconciliation table: file | rows read | accepted | rejected | check
- [ ] Query result: rejects by file and reason
- [ ] Short answer: which rule did you test first and why does the order matter?
