# 04 - Target Model, Grains and Business Rules

## 1. Star schema (TechnicalSupport_DW)
See `diagrams/target_star_schema.png` (source: `target_star_schema.mmd`).

| Table | Type | Grain (one row per ...) | Business key / key |
|---|---|---|---|
| dim.DimDate | dimension | calendar date | date_key = yyyymmdd |
| dim.DimCustomer | dimension, **SCD** | customer **version** | surrogate customer_key; business key customer_id + version_number |
| dim.DimAgent | dimension, Type 1 | agent | agent_key; business key agent_id |
| dim.DimTicketType | dimension | ticket type (+ the Unknown member, key -1) | ticket_type_key |
| fact.FactTicket | fact | **ticket** | ticket_id |
| fact.FactTicketStatusEvent | fact (event) | **status event** | status_event_id |
| fact.FactTicketBreakdown | fact (event) | **breakdown event** | breakdown_id |
| hist.HistCustomerStability | history | customer observation (customer_id, snapshot_date) | (customer_id, snapshot_date) |
| hist.HistAgentAssignment | history | ownership interval | assignment_id |
| rpt.vw_TicketOperations | view | ticket (same grain as FactTicket) | |
| rpt.vw_BreakdownAnalysis | view | breakdown event (same grain as FactTicketBreakdown) | |
| rpt.vw_CustomerMonthlyPerformance | view | customer **business key** x month | |

**Costs and effort exist only in FactTicketBreakdown.** FactTicket carries lifecycle measures (resolution minutes, reopen count ...) but never a copy of cost - otherwise a ticket with many breakdowns would double count when the tables are joined (fan-out). Aggregate a child table to the ticket grain *before* joining it to ticket level data.

## 2. Temporal rules (apply to every fact row that is resolved "as of" a time T)
| Attribute at time T | Rule |
|---|---|
| Ticket status | the **latest status event of that ticket with status_at <= T** (an event at exactly T already applies; tie -> higher status_event_id) |
| Customer stability | the **latest observation of that customer with snapshot_date <= CAST(T AS DATE)**. If none exists the value is **NULL / Unknown** - never a future observation, never a default such as 'very stable' |
| Owning agent | the assignment whose half-open interval contains T: **started_at <= T AND (ended_at IS NULL OR ended_at > T)**. No match = NULL (the ticket was unowned) |
| Customer version | the version with **effective_from <= CAST(T AS DATE) < effective_to** |
| Repeated values | the same status or stability appearing again is **not a change** |
| Time ranges | always half-open: `>= start AND < end`; avoid BETWEEN on timestamps |
| Unknown ticket type | a ticket without a details row gets ticket_type_key = -1 ("Unknown") and severity 'Unknown' |

## 3. Ticket lifecycle measures (FactTicket) - "as of the batch cutoff"
- Only status events with `status_at < cutoff` of the batch are considered (the cutoff is the batch's `cutoff_ts`; never the clock).
- `latest_status` = status of the latest event before the cutoff.
- `first_resolution_at` = earliest 'Resolved' event, `last_resolution_at` = latest 'Resolved' event. **They differ for reopened tickets.** Never invent a date: a ticket never resolved has NULL for both.
- `resolution_minutes` = minutes from `created_at` to the **first** resolution, NULL when never resolved.
- `reopen_count` = number of 'Reopened' events. `is_resolved` = latest status is Resolved or Closed. `final_closed_at` = time of the latest event when that event is 'Closed', otherwise NULL.

## 4. Slowly changing dimension rules (DimCustomer)
| Attribute | Class | Behaviour |
|---|---|---|
| customer_id | business key | identifies the customer across versions |
| customer_name | **Type 1** | corrections overwrite the value in **all** versions; no new version |
| customer_segment | **Type 2** | a change closes the current version and opens a new one |
| region | **Type 2** | same |
| onboarding_date | fixed | never changes; copied to every version |
Intervals are **half-open** `[effective_from, effective_to)`. The old version's `effective_to` equals the new version's `effective_from` exactly. The open version has `effective_to = 9999-12-31` and `is_current = 1`; there is **at most one current row per customer** (the database enforces it with a filtered unique index). `effective_from` of the first version is the onboarding date; later versions start on the **effective date given in the file** (never the system date).
Scenarios you must be able to handle: A new customer; B no change; C name only; D region change; E segment change; F name and region/segment together; G the same batch processed twice.
**Facts always use the version valid at the event date**, not the current version.

## 5. Reject codes and precedence
A bad row is **logged once** with the **first** rule it fails (highest precedence first):

`BLANK_REQUIRED` > `INVALID_NUMBER` > `INVALID_DATE` > `NEGATIVE_VALUE` / `UNSUPPORTED_VALUE` / `INVALID_STABILITY` / `BAD_INTERVAL` > `UNKNOWN_CUSTOMER` / `UNKNOWN_TICKET` / `UNKNOWN_AGENT` > `DUPLICATE_KEY`

| Code | Meaning |
|---|---|
| BLANK_REQUIRED | a required column is empty after trimming |
| INVALID_NUMBER | a numeric column cannot be converted (ids, effort_minutes, cost_egp) |
| INVALID_DATE | a date/timestamp column cannot be converted |
| NEGATIVE_VALUE | effort_minutes <= 0 or cost_egp < 0 |
| UNSUPPORTED_VALUE | value outside the allowed list (priority after mapping, segment, region, channel, ticket type, severity, team, status) |
| INVALID_STABILITY | stability label not in the five allowed labels |
| BAD_INTERVAL | an interval ends before or at its start |
| UNKNOWN_CUSTOMER / UNKNOWN_TICKET / UNKNOWN_AGENT | referenced key does not exist in the reference set of the load |
| DUPLICATE_KEY | second or later occurrence of a business key in the same delivery (first occurrence is kept) |
| STALE_SNAPSHOT | (SCD) a customer snapshot effective before the start of the current version |

A repeated row that is **identical to what the warehouse already holds** (a later delivery of an unchanged record) is **not** a reject: it is "unchanged".

## 6. Batch calendar (explicit, never the clock)
| Batch | Name | Window (start incl. - end excl.) | Processing date | Cutoff |
|---|---|---|---|---|
| 0 | Initial load | 2025-01-01 - 2025-07-01 | 2025-07-01 | 2025-07-01 00:00:00 |
| 1 | First incremental | 2025-07-01 - 2025-07-09 | 2025-07-09 | 2025-07-09 00:00:00 |
| 2 | Second incremental | 2025-07-09 - 2025-07-16 | 2025-07-16 | 2025-07-16 00:00:00 |
| 99 | Dirty fixture (Lab 2 only) | n/a | see its manifest | see its manifest |
The values come from each folder's `batch_manifest.csv`.
