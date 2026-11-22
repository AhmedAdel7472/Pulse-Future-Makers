# Lab 04 - Slowly Changing Dimensions - Type 1 and Type 2

**Difficulty:** Advanced (4 of 5)  |  **Estimated effort:** 6 hours  |  **Mode:** hands-on in Visual Studio (SSIS); T-SQL only where the lab says so

## 1. Business scenario

Customers are renamed, move region and change segment. A correction of a name must not create history (Type 1) while a move to another region or segment must (Type 2), and every fact must keep pointing to the customer version that was valid when it happened. You first explore SSIS's native Slowly Changing Dimension transformation, then build the logic yourself with Lookup + Conditional Split + set-based updates and compare the two.

## 2. Learning objectives

- Classify attributes as Type 1, Type 2 or fixed from a business description
- Detect NEW / TYPE-2 / TYPE-1-only / UNCHANGED customers with Lookup + Conditional Split
- Expire the old version and insert the new one using half-open intervals [effective_from, effective_to)
- Overwrite a Type 1 attribute in ALL versions
- Prove the Type 2 invariants and idempotence with queries
- Compare the native SCD transformation with the manual pattern (trade-offs)

## 3. Prerequisites

- Lab 3 finished (DimCustomer holds one version per customer; the facts are loaded)
- `data/batch_01_delta/customer_snapshot.csv`; script `sql_setup/80_create_scd_wizard_scratch.sql` run for Part A

## 4. Input files / sources

- data/batch_01_delta/customer_snapshot.csv
- data/batch_01_delta/batch_manifest.csv

## 5. Source and destination

- **Source:** customer_snapshot.csv -> stg.customer_snapshot (batch 1)
- **Destination:** dim.DimCustomer (Part B); dim.DimCustomer_SCD_Scratch (Part A, exploration only); etl.ETL_Rejects

## 6. Required operations (exactly what you must build)

### 0. Attribute classification (fill in before building)

- customer_id: business key | customer_name: Type 1 | customer_segment, region: Type 2 | onboarding_date: fixed. Version intervals are half-open `[effective_from, effective_to)`; the current version has `effective_to = 9999-12-31`. `effective_date` in the file is the business date a change takes effect (blank for new customers: use onboarding_date). The computer clock is never an effective date.

### Scenarios you must handle

- A - new customer: insert version 1 at onboarding_date.
- B - no change (the row repeats what the warehouse already has, possibly with stray spaces in the name): nothing changes.
- C - name changed only: overwrite the name in every version, no new version.
- D - region changed: expire the current version at the effective date, insert version n+1 (new region).
- E - segment changed (also for a customer that already has a second version: the result has three versions).
- F - name AND region/segment changed in one batch: new version with the new name, the old versions get the new name too.
- G - the same batch is run again: nothing changes (no extra versions, no duplicates).
- Plus: rows that fail validation are rejected and logged (Lab 2 rules) and must not touch the dimension.

### Part A - native SCD transformation (exploration)

- Load `customer_snapshot.csv` (stage 1 cleansing from Lab 2) and feed the accepted rows to the Slowly Changing Dimension transformation (wizard) targeting `dim.DimCustomer_SCD_Scratch`. Business key `customer_id`; Fixed: onboarding_date; Changing (Type 1): customer_name; Historical (Type 2): customer_segment, region. Use the current-flag/start-end-date options.
- Record what the wizard generated (which components, row-by-row OLE DB Commands?), how it decides the dates, and what it does for scenario F. Do not 'fix' the generated flow.

### Part B - Lookup + Conditional Split + set-based (required)

- Stage the file (batch 1) into `stg.customer_snapshot` (re-runnable). Source query: the first occurrence of each customer (`ROW_NUMBER()` by source_row_number).
- Lookup the CURRENT DimCustomer row (`is_current = 1`) by customer_id: no match -> NEW. Conditional Split on the match output: segment or region different -> TYPE2; else name different -> TYPE1; else UNCHANGED (compare after trimming).
- NEW -> insert version 1. TYPE2 -> write the keys and dates to a work table (create it in schema `stg`), then in an Execute SQL Task (in this order): (1) overwrite the name in all versions if it differs, (2) expire the current version (`effective_to` = effective date, `is_current` = 0), (3) insert the new current version (version + 1, onboarding_date carried over). TYPE1 -> work table + one set-based UPDATE of the name in all versions. Reject snapshots effective BEFORE the current version starts (`STALE_SNAPSHOT`).
- Count NEW / TYPE2 / TYPE1 / UNCHANGED / rejected with Row Count and write them to `etl.ETL_BatchLog`.

### Prove it

- Write the queries that show: exactly one current row per customer; no gaps or overlaps between consecutive versions; names identical across versions; onboarding_date identical; every new version differs in segment or region. Show one customer for each of the scenarios A, C, D, E and F before/after.
- Run the package again for the same batch (scenario G): row counts of DimCustomer unchanged. Check that facts loaded earlier still point to the version valid at their date (a fact before the effective date keeps the old key).

## 7. Expected output structure

dim.DimCustomer with additional version rows for Type 2 changes, expired rows closed at the effective date, names updated in all versions; a written comparison of Part A and Part B (half a page).

## 8. Acceptance criteria

- [ ] Each scenario A, C, D, E, F produces exactly the behaviour described; scenario B and G change nothing
- [ ] Exactly one current row per customer; consecutive versions touch without gap or overlap; version numbers are 1..n
- [ ] customer_name is the same in all versions of a customer; onboarding_date never differs
- [ ] Facts loaded before the change keep their old customer_key; no fact points to a version that was not valid on its event date
- [ ] Invalid rows of the file are rejected and logged; the dimension is not touched by them
- [ ] Second run of the same batch: no change in any table (counts + a comparison query)

## 9. SSIS components used (and why)

| Component | Meaningful use in this lab |
|---|---|
| Flat File Source | Read every CSV as text so that bad values reach YOUR validation instead of failing inside the source |
| Lookup | Priority map, stability labels, customer / ticket / agent existence, surrogate keys and point-in-time lookups |
| Conditional Split | Route rows to accepted / rejected / NEW / TYPE-2 / TYPE-1 / UNCHANGED outputs |
| Derived Column | Trim/collapse text, blank -> NULL, add batch_id, source_file, reason_code, computed keys and minutes |
| OLE DB Source | Read the operational database (Lab 3) and staging/dimension rows with a SQL command (Labs 4-5) |
| OLE DB Destination | Fast-load staging, dimension, fact, history and reject tables |
| Execute SQL Task | Clean a batch before reloading, read manifest/watermark, set-based SCD updates, advance the watermark, write the audit log |
| Row Count | Capture source / loaded / rejected counts into variables for reconciliation and logging |
| Error Output / Reject destination | Redirect bad rows (not fail the package) and log the reason to etl.ETL_Rejects |
| Variables | BatchId, CutoffTs, folder/file names, row counts, flags used in expressions |

## 10. Hints (not answers)

- Do the Type 1 name overwrite BEFORE inserting the new version, or insert the new version with the new name and update the rest: be consistent.
- `effective_to` of the old row must equal `effective_from` of the new row exactly.
- Compare trimmed, single-spaced names; compare segment/region exactly as stored.
- The effective date is a column of the file, not a package variable.

## 11. Submission checklist

- [ ] Project with `Lab04_*` packages
- [ ] Before/after listing for one customer per scenario
- [ ] Output of the invariant queries
- [ ] Half-page comparison: native SCD transformation vs manual pattern (performance, control of dates, rerun behaviour, maintainability)
