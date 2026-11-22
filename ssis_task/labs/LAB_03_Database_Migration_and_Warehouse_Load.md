# Lab 03 - Database Migration and Warehouse Load (Initial Load)

**Difficulty:** Advanced (3 of 5)  |  **Estimated effort:** 8 hours  |  **Mode:** hands-on in Visual Studio (SSIS); T-SQL only where the lab says so

## 1. Business scenario

The operational database `TechnicalSupport_Source` holds the baseline. Build the star schema in `TechnicalSupport_DW`: dimensions first, then the ticket fact with its lifecycle measures, the status-event fact, the history tables and finally the breakdown fact whose three attributes (customer version, ticket status, customer stability, owner) must be resolved AS OF THE MOMENT of each breakdown.

## 2. Learning objectives

- Migrate relational data with OLE DB Source/Destination and surrogate-key lookups
- Load dimensions (Type 1 agents, ticket types, initial customer versions) and the Unknown member
- Resolve dimension versions by DATE RANGE with a parameterised Lookup
- Derive lifecycle measures with Aggregate, Sort and Merge Join (first vs last resolution, reopen count)
- Implement point-in-time lookups (status, stability, agent) and avoid fan-out / double counting
- Reconcile source to target (counts, cost, effort) and understand why load order matters

## 3. Prerequisites

- Labs 1 and 2 finished
- Script 06 run (`TechnicalSupport_Source` seeded with Batch 0)
- `etl.ETL_BatchManifest` contains batch 0 (Lab 1; reload it if you used the reset script) - the cutoff comes from it
- docs/04_Target_Model_and_Rules.md read (temporal rules, grains)

## 4. Input files / sources

- Database `TechnicalSupport_Source` (9 tables, Batch 0)

## 5. Source and destination

- **Source:** TechnicalSupport_Source (OLE DB)
- **Destination:** TechnicalSupport_DW: dim.DimAgent, dim.DimCustomer, dim.DimTicketType, fact.FactTicket, fact.FactTicketStatusEvent, hist.HistCustomerStability, hist.HistAgentAssignment, fact.FactTicketBreakdown

## 6. Required operations (exactly what you must build)

### 0. Control

- Package `Lab03_Initial_Load` with parameter `BatchId` (0). Execute SQL Task: read `cutoff_ts` for the batch from `etl.ETL_BatchManifest` into variable `CutoffTs` (DateTime). The cutoff is NEVER taken from the computer clock.
- Make the whole package re-runnable: first task deletes all DW data of the batch (fact/hist tables first, dimensions last) or you use the level-2 reset script between runs.

### 1. Dimensions

- DimAgent: source `dbo.support_agents` -> destination (hire_date is not loaded). Lookup on agent_id so a rerun updates instead of duplicating.
- DimTicketType: DISTINCT `ticket_type` from `dbo.ticket_details` (Aggregate GROUP BY, or Sort with duplicate removal) -> insert only types not yet present. Keep the Unknown member (-1).
- DimCustomer: one VERSION-1 row per customer: `effective_from` = onboarding_date, `effective_to` = 9999-12-31, `is_current` = 1, `version_number` = 1.

### 2. FactTicket header

- Source `dbo.tickets`. Lookup the customer VERSION valid on the creation date: Lookup (no cache or partial cache) with a SQL command `SELECT customer_key ... WHERE customer_id = ? AND effective_from <= ? AND ? < effective_to` and parameters mapped to customer_id, the created DATE (Derived Column) and the same DATE. Derive `created_date_key` (yyyymmdd) with Derived Column. Initially set the lifecycle columns to their neutral values (status 'Created', NULL dates, 0).
- Ticket type and severity from `dbo.ticket_details` (0..1 per ticket): Lookup on ticket_id; no match -> type key -1 and severity 'Unknown'. (A Merge Join is also possible.)

### 3. Status events and history

- FactTicketStatusEvent from `dbo.ticket_status_history` (lookup the agent key; NULL agent stays NULL; `status_date_key` yyyymmdd).
- HistCustomerStability from `dbo.customer_stability_observations` (+ rank from `etl.ref_StabilityLevel`). HistAgentAssignment from `dbo.ticket_agent_assignments` (agent key lookup).

### 4. Lifecycle measures of FactTicket (as of the cutoff)

- Read `fact.FactTicketStatusEvent` events with `status_at < CutoffTs`. Derived Column: `resolved_at` = status 'Resolved' ? status_at : NULL, `reopen_flag` = status 'Reopened' ? 1 : 0. Aggregate per ticket: MIN(resolved_at) = first, MAX(resolved_at) = last, SUM(reopen_flag), MAX(status_at). Latest status: join the per-ticket MAX(status_at) back to the events (Sort + Merge Join on ticket_id + status_at) to read the status of the latest event.
- Merge Join the result with the ticket header (both inputs Sorted by ticket_id, IsSorted/SortKeyPosition set): compute `resolution_minutes` = minutes from created_at to FIRST resolution (NULL when none; two decimals), `is_resolved` (latest status Resolved or Closed), `final_closed_at` (status_at of the latest event only when it is 'Closed'). Update the fact rows (OLE DB Command, or write to a work table and finish with ONE set-based UPDATE in an Execute SQL Task).
- Never invent a date: a ticket that was never resolved has NULL first/last resolution and NULL resolution_minutes.

### 5. FactTicketBreakdown (point-in-time)

- Source `dbo.ticket_breakdown`. For the breakdown at time T: (a) customer version: customer of the ticket, version valid on date(T); (b) ticket status = latest status event with status_at <= T (tie: higher status_event_id); (c) customer stability = latest observation with snapshot_date <= date(T), NULL when none; (d) owner agent = assignment with started_at <= T and (ended_at IS NULL or ended_at > T), NULL when none.
- Implement (b), (c), (d) with Lookup transformations in no-cache/partial-cache mode whose SQL command takes parameters (for example a `SELECT TOP 1 ... ORDER BY ... DESC` for 'latest'), or with Merge Join + Aggregate. Whatever you choose, the result must not multiply rows: the output row count equals the input row count.
- Insert into `fact.FactTicketBreakdown`; `effort_minutes` and `cost_egp` are stored here and nowhere else.

### 6. Reconcile

- Per table: source rows = target rows (+ rejected). Totals: SUM(cost_egp) and SUM(effort_minutes) in the source = in the fact. No orphan keys. Query the reporting views (`rpt.vw_*`) and check that their row counts equal the fact tables and that costs add up (no double counting).

## 7. Expected output structure

Dimension, fact and history tables filled as described in docs/03_Data_Dictionary.md (grain of each table is documented there). Surrogate keys are assigned by the database.

## 8. Acceptance criteria

- [ ] Source-to-target counts reconcile for every table; SUM(cost_egp) and SUM(effort_minutes) are equal in source and fact
- [ ] Every customer has exactly one current DimCustomer row (version 1) and FactTicket.customer_key points to a version valid on the creation date
- [ ] Tickets without a details row have ticket_type_key = -1 and severity 'Unknown'
- [ ] first_resolution_at <= last_resolution_at; tickets never resolved have NULL for both and for resolution_minutes; reopened tickets show reopen_count > 0
- [ ] FactTicketBreakdown: one row per source breakdown; unknown stability is NULL (the views show 'Unknown'); no future observation is used; a breakdown happening exactly at a status change takes the NEW status
- [ ] The three views return the same number of rows as their facts and the same total cost
- [ ] The package can be run twice without duplicates (the second run starts from a cleaned warehouse or is idempotent)

## 9. SSIS components used (and why)

| Component | Meaningful use in this lab |
|---|---|
| OLE DB Source | Read the operational database (Lab 3) and staging/dimension rows with a SQL command (Labs 4-5) |
| OLE DB Destination | Fast-load staging, dimension, fact, history and reject tables |
| Lookup | Priority map, stability labels, customer / ticket / agent existence, surrogate keys and point-in-time lookups |
| Derived Column | Trim/collapse text, blank -> NULL, add batch_id, source_file, reason_code, computed keys and minutes |
| Aggregate | DISTINCT ticket types, reject summary by reason, per-ticket MIN/MAX/COUNT of status events |
| Sort | Order both inputs of the Merge Join (and optionally remove exact duplicates) |
| Merge Join | Join per-ticket status aggregates back to the ticket header (lifecycle measures) |
| Conditional Split | Route rows to accepted / rejected / NEW / TYPE-2 / TYPE-1 / UNCHANGED outputs |
| Union All | Combine the reject branches of several checks into one reject stream |
| Multicast | Send the same rows to two destinations (accepted rows + audit counting / summary) |
| Execute SQL Task | Clean a batch before reloading, read manifest/watermark, set-based SCD updates, advance the watermark, write the audit log |
| Variables | BatchId, CutoffTs, folder/file names, row counts, flags used in expressions |
| Parameters | Project/package parameters: ServerName, DataRoot, BatchId - nothing environment specific is hard-coded |

## 10. Hints (not answers)

- Load order: dimensions -> FactTicket header -> status events/history -> lifecycle measures -> breakdowns. Foreign keys tell you the order.
- Merge Join needs BOTH inputs sorted on the join key; set `IsSorted = True` and `SortKeyPosition` on the source output if the query already sorts.
- Lookup parameters are only available with partial or no cache; full cache cannot do a range or 'latest' lookup.
- A breakdown with `occurred_at` equal to a status change time: the event is already effective (`<=`).

## 11. Submission checklist

- [ ] Project with the `Lab03_*` packages and a build-order sketch
- [ ] Reconciliation table per target table
- [ ] Results of 5 spot checks of your choice (one reopened ticket, one ticket without details, one breakdown at a status change, one breakdown with unknown stability, one breakdown without an owner)
- [ ] Short answer: what happens to a fact load if the dimension is loaded afterwards?
