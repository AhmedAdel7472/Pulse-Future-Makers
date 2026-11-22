# 05 - Incremental Loading Design (one strategy)

The strategy has three ingredients: **a batch manifest**, **a watermark**, and **unique business keys**.

## What identifies what
| Question | Answer |
|---|---|
| What identifies a **batch**? | `batch_id` + folder + the manifest rows (`etl.ETL_BatchManifest`): file name, announced row count, window, processing date, cutoff |
| What identifies a **row**? | its business key: customer_id; ticket_id; ticket_id (details); status_event_id; breakdown_id; (customer_id, snapshot_date); assignment_id; agent_id |
| How is a **new** row recognised? | its business key is not in the warehouse yet |
| How is a **changed** row recognised? | the key exists and a *tracked attribute* differs (priority/channel of a ticket, the end of an assignment interval, segment/region/name of a customer) |
| How is a **repeated** row recognised? | the key exists and nothing tracked differs -> counted as *unchanged*; this is normal, not an error |
| What is a **duplicate**? | the same key twice inside one delivery -> first kept, later ones rejected (`DUPLICATE_KEY`) |

## Control tables
- `etl.ETL_BatchManifest` - what the batch announces.
- `etl.ETL_Watermark` - one row per pipeline: the **last batch that was loaded completely** and its cutoff.
- `etl.ETL_BatchLog` - one row per package run: batch, package, start/end, status (Running / Succeeded / Failed / Skipped), source / inserted / updated / rejected counts, error summary.
- `etl.ETL_Rejects` - one row per rejected source row with batch, file, business key, reason code and the raw row.

## The load of one batch (order matters)
1. **Pre-checks.** If `watermark >= batch_id` -> log *Skipped*, end successfully. If `watermark < batch_id - 1` -> fail (a batch is missing).
2. **Clean the batch's own leftovers**: staging rows, rejects and manifest rows of this `batch_id` (so a rerun starts clean).
3. **Stage** all files with stage-1 validation; reconcile each file with the manifest.
4. **Load** in dependency order, each step "make it so" (insert if missing, update if different, otherwise leave): agents -> customers (SCD) -> tickets -> details/types -> status events -> observations -> assignments -> breakdowns -> recompute the ticket lifecycle measures for the batch cutoff.
5. **Log** success with counts.
6. **Advance the watermark** - the very last task, and only if every task above succeeded.

## Failure and rerun
- A failure at any step leaves the watermark where it was. The batch is therefore still "pending".
- Because step 2 cleans the batch's leftovers and step 4 never blindly inserts, the batch can simply be **started again** - there is no manual repair.
- A processed batch that is started again is **skipped** by the pre-check. To force a reprocess for testing, move the watermark back by one batch; the result must be identical (idempotence).
- **When may the watermark advance?** Only after all dependent loads succeeded. If it moved first and the load then failed, the batch would never be retried: data would be lost silently.

## What "late-arriving" means here
Later batches can contain rows that belong to earlier time (a status event or a breakdown for a ticket created weeks ago; ticket details that arrive after the ticket). They are loaded normally; point-in-time lookups use the *event* time, not the arrival time.

## Per-batch reconciliation (you produce this table in Lab 5)
Classify **every source row exactly once** as *rejected*, *new*, *changed* or *unchanged*:

`source rows = rejected + new + changed + unchanged`

This is a count of **source rows**, not of database operations. One Type 2 customer change is one *changed* source row, even though it causes an UPDATE (expire the old version) and an INSERT (new version) in the dimension. Distinct-value dimensions (ticket types) and recomputed measures (lifecycle columns of FactTicket) are reconciled differently - say how you did it. If the equation does not hold, find the missing rows before going further.
