# 03 \- Data Dictionary

Generated from the setup scripts (`sql_setup/02..04`). Column types are those of the tables you will load. The meaning column comes from the business description; the **transformation rules** are for you to discover (see the Student Mapping workbook).

## A. Target warehouse \- TechnicalSupport\_DW

### dim.DimDate

**Grain:** one row per calendar date.

| Column | Type | Null | SCD class | Meaning |
| :---- | :---- | :---- | :---- | :---- |
| date\_key | INT | NO |  |  |
| full\_date | DATE | NO |  |  |
| year | SMALLINT | NO |  |  |
| quarter | TINYINT | NO |  |  |
| month | TINYINT | NO |  |  |
| month\_name | VARCHAR(12) | NO |  |  |
| day\_of\_month | TINYINT | NO |  |  |

### dim.DimCustomer

**Grain:** one row per customer VERSION (SCD).

| Column | Type | Null | SCD class | Meaning |
| :---- | :---- | :---- | :---- | :---- |
| customer\_key | INT | NO | Surrogate key | Key used by the facts |
| customer\_id | INT | NO | Business key | Identifies the customer across all versions |
| customer\_name | NVARCHAR(100) | NO | Type 1 (overwrite) | A name correction is not a business change: history is not kept |
| customer\_segment | VARCHAR(20) | NO | Type 2 (history) | Segment drives service levels: facts must keep the segment valid when they happened |
| region | VARCHAR(20) | NO | Type 2 (history) | Region drives staffing and reporting |
| onboarding\_date | DATE | NO | Fixed attribute | The day the customer joined never changes |
| effective\_from | DATE | NO | Type 2 control column | First day the version is valid (inclusive) |
| effective\_to | DATE | NO | Type 2 control column | First day the version is NO LONGER valid (exclusive) |
| is\_current | BIT | NO | Type 2 control column | Convenience flag for current-state reports |
| version\_number | INT | NO | Type 2 control column | Order of the versions of one customer |

### dim.DimAgent

**Grain:** one row per support agent.

| Column | Type | Null | SCD class | Meaning |
| :---- | :---- | :---- | :---- | :---- |
| agent\_key | INT | NO | Surrogate key | Key used by the facts |
| agent\_id | INT | NO | Business key | Identifies the agent |
| agent\_name | NVARCHAR(100) | NO |  |  |
| team | VARCHAR(30) | NO |  |  |
| region | VARCHAR(20) | NO |  |  |

### dim.DimTicketType

**Grain:** one row per ticket type (+ Unknown member key \-1).

| Column | Type | Null | SCD class | Meaning |
| :---- | :---- | :---- | :---- | :---- |
| ticket\_type\_key | INT | NO | Surrogate key | Tickets with no ticket\_details row must still load |
| ticket\_type | VARCHAR(30) | NO | Type 1 / static | Reporting category of the ticket |

### fact.FactTicket

**Grain:** one row per ticket.

| Column | Type | Null | SCD class | Meaning |
| :---- | :---- | :---- | :---- | :---- |
| ticket\_id | INT | NO | Degenerate / business key | Grain: one row per ticket |
| customer\_key | INT | NO | Type 2 lookup | The customer as it was when the ticket was created |
| ticket\_type\_key | INT | NO | \- | Type of the ticket |
| created\_date\_key | INT | NO | \- | Date dimension key |
| created\_at | DATETIME2(0) | NO | \- | When the ticket was created |
| priority | VARCHAR(10) | NO | Type 1 (overwrite) | Current urgency of the ticket |
| channel | VARCHAR(10) | NO | Type 1 (overwrite) | Arrival channel |
| severity | VARCHAR(10) | NO | Type 1 (overwrite) | Technical severity |
| latest\_status | VARCHAR(20) | NO | \- | Where the ticket stands at the cutoff |
| first\_resolution\_at | DATETIME2(0) | YES | \- | First time the customer problem was solved |
| last\_resolution\_at | DATETIME2(0) | YES | \- | A reopened ticket can be resolved again |
| final\_closed\_at | DATETIME2(0) | YES | \- | When the ticket was finally closed |
| resolution\_minutes | DECIMAL(12,2) | YES | \- | Time to first resolution (reopened time is not added) |
| reopen\_count | INT | NO | \- | How often the ticket was reopened |
| is\_resolved | BIT | NO | \- | Resolved right now (a reopened ticket is 0 again) |
| etl\_batch\_id | INT | NO | \- | Audit |

### fact.FactTicketStatusEvent

**Grain:** one row per status event.

| Column | Type | Null | SCD class | Meaning |
| :---- | :---- | :---- | :---- | :---- |
| status\_event\_id | INT | NO |  |  |
| ticket\_id | INT | NO |  |  |
| status | VARCHAR(20) | NO |  |  |
| status\_at | DATETIME2(0) | NO |  |  |
| status\_date\_key | INT | NO | \- | Date dimension key |
| changed\_by\_agent\_key | INT | YES | \- | Who made the change |
| status\_reason | VARCHAR(100) | YES |  |  |
| etl\_batch\_id | INT | NO |  |  |

### fact.FactTicketBreakdown

**Grain:** one row per breakdown event.

| Column | Type | Null | SCD class | Meaning |
| :---- | :---- | :---- | :---- | :---- |
| breakdown\_id | INT | NO | Business key | Grain: one row per breakdown event |
| ticket\_id | INT | NO | \- | Ticket the work was done for |
| customer\_key | INT | NO | Type 2 lookup | Segment/region as they were when the work happened |
| agent\_key | INT | YES | \- | Who owned the ticket when the work was done |
| event\_date\_key | INT | NO | \- | Date dimension key |
| occurred\_at | DATETIME2(0) | NO |  |  |
| breakdown\_category | VARCHAR(30) | NO |  |  |
| component\_name | VARCHAR(60) | NO |  |  |
| effort\_minutes | INT | NO | \- | Work effort |
| cost\_egp | DECIMAL(12,2) | NO | \- | Cost of the work |
| ticket\_status\_at\_event | VARCHAR(20) | YES | \- | What the ticket's status was when the work happened |
| customer\_stability\_at\_event | VARCHAR(20) | YES | \- | How stable the customer was when the work happened |
| etl\_batch\_id | INT | NO |  |  |

### hist.HistCustomerStability

**Grain:** one row per customer observation (customer\_id, snapshot\_date).

| Column | Type | Null | SCD class | Meaning |
| :---- | :---- | :---- | :---- | :---- |
| customer\_id | INT | NO |  |  |
| snapshot\_date | DATE | NO |  |  |
| stability\_status | VARCHAR(20) | NO |  |  |
| stability\_rank | TINYINT | NO | \- | Allows ordering and trend reports |
| etl\_batch\_id | INT | NO |  |  |

### hist.HistAgentAssignment

**Grain:** one row per ownership interval (assignment\_id).

| Column | Type | Null | SCD class | Meaning |
| :---- | :---- | :---- | :---- | :---- |
| assignment\_id | INT | NO |  |  |
| ticket\_id | INT | NO |  |  |
| agent\_key | INT | NO |  |  |
| started\_at | DATETIME2(0) | NO |  |  |
| ended\_at | DATETIME2(0) | YES |  |  |
| etl\_batch\_id | INT | NO |  |  |

### Reporting views (schema rpt)

| View | Grain | Purpose |
| :---- | :---- | :---- |
| rpt.vw\_TicketOperations | one row per ticket | ticket attributes \+ customer version at creation \+ lifecycle measures, with breakdown effort/cost **pre-aggregated** (no fan-out) |
| rpt.vw\_BreakdownAnalysis | one row per breakdown event | breakdown \+ customer version, ticket status, stability and owner at the event time |
| rpt.vw\_CustomerMonthlyPerformance | customer (business key) x month | monthly tickets, resolved tickets, effort, cost per customer, across all versions |

## B. Staging and control tables (schemas stg, etl)

### stg.customer\_snapshot

| Column | Type | Null | SCD class | Meaning |
| :---- | :---- | :---- | :---- | :---- |
| customer\_id | INT | YES |  |  |
| customer\_name | NVARCHAR(100) | YES |  |  |
| customer\_segment | VARCHAR(20) | YES |  |  |
| region | VARCHAR(20) | YES |  |  |
| onboarding\_date | DATE | YES |  |  |
| effective\_date | DATE | YES |  |  |
| batch\_id | INT | NO |  |  |
| source\_file | VARCHAR(100) | NO |  |  |
| source\_row\_number | INT | NO |  |  |

### stg.support\_agents

| Column | Type | Null | SCD class | Meaning |
| :---- | :---- | :---- | :---- | :---- |
| agent\_id | INT | YES |  |  |
| agent\_name | NVARCHAR(100) | YES |  |  |
| team | VARCHAR(30) | YES |  |  |
| region | VARCHAR(20) | YES |  |  |
| hire\_date | DATE | YES |  |  |
| batch\_id | INT | NO |  |  |
| source\_file | VARCHAR(100) | NO |  |  |
| source\_row\_number | INT | NO |  |  |

### stg.tickets

| Column | Type | Null | SCD class | Meaning |
| :---- | :---- | :---- | :---- | :---- |
| ticket\_id | INT | YES |  |  |
| customer\_id | INT | YES |  |  |
| created\_at | DATETIME2(0) | YES |  |  |
| priority | VARCHAR(10) | YES |  |  |
| channel | VARCHAR(10) | YES |  |  |
| batch\_id | INT | NO |  |  |
| source\_file | VARCHAR(100) | NO |  |  |
| source\_row\_number | INT | NO |  |  |

### stg.ticket\_details

| Column | Type | Null | SCD class | Meaning |
| :---- | :---- | :---- | :---- | :---- |
| ticket\_id | INT | YES |  |  |
| ticket\_name | NVARCHAR(200) | YES |  |  |
| ticket\_type | VARCHAR(30) | YES |  |  |
| severity | VARCHAR(10) | YES |  |  |
| description | NVARCHAR(500) | YES |  |  |
| batch\_id | INT | NO |  |  |
| source\_file | VARCHAR(100) | NO |  |  |
| source\_row\_number | INT | NO |  |  |

### stg.ticket\_status\_history

| Column | Type | Null | SCD class | Meaning |
| :---- | :---- | :---- | :---- | :---- |
| status\_event\_id | INT | YES |  |  |
| ticket\_id | INT | YES |  |  |
| status | VARCHAR(20) | YES |  |  |
| status\_at | DATETIME2(0) | YES |  |  |
| changed\_by\_agent\_id | INT | YES |  |  |
| status\_reason | VARCHAR(100) | YES |  |  |
| batch\_id | INT | NO |  |  |
| source\_file | VARCHAR(100) | NO |  |  |
| source\_row\_number | INT | NO |  |  |

### stg.ticket\_breakdown

| Column | Type | Null | SCD class | Meaning |
| :---- | :---- | :---- | :---- | :---- |
| breakdown\_id | INT | YES |  |  |
| ticket\_id | INT | YES |  |  |
| occurred\_at | DATETIME2(0) | YES |  |  |
| breakdown\_category | VARCHAR(30) | YES |  |  |
| component\_name | VARCHAR(60) | YES |  |  |
| effort\_minutes | INT | YES |  |  |
| cost\_egp | DECIMAL(12,2) | YES |  |  |
| breakdown\_description | NVARCHAR(300) | YES |  |  |
| batch\_id | INT | NO |  |  |
| source\_file | VARCHAR(100) | NO |  |  |
| source\_row\_number | INT | NO |  |  |

### stg.customer\_stability\_observations

| Column | Type | Null | SCD class | Meaning |
| :---- | :---- | :---- | :---- | :---- |
| customer\_id | INT | YES |  |  |
| snapshot\_date | DATE | YES |  |  |
| stability\_status | VARCHAR(20) | YES |  |  |
| batch\_id | INT | NO |  |  |
| source\_file | VARCHAR(100) | NO |  |  |
| source\_row\_number | INT | NO |  |  |

### stg.ticket\_agent\_assignments

| Column | Type | Null | SCD class | Meaning |
| :---- | :---- | :---- | :---- | :---- |
| assignment\_id | INT | YES |  |  |
| ticket\_id | INT | YES |  |  |
| agent\_id | INT | YES |  |  |
| started\_at | DATETIME2(0) | YES |  |  |
| ended\_at | DATETIME2(0) | YES |  |  |
| batch\_id | INT | NO |  |  |
| source\_file | VARCHAR(100) | NO |  |  |
| source\_row\_number | INT | NO |  |  |

### etl.ref\_PriorityMap

| Column | Type | Null | SCD class | Meaning |
| :---- | :---- | :---- | :---- | :---- |
| label\_key | VARCHAR(20) | NO |  |  |
| priority | VARCHAR(10) | NO |  |  |

### etl.ref\_StabilityLevel

| Column | Type | Null | SCD class | Meaning |
| :---- | :---- | :---- | :---- | :---- |
| stability\_status | VARCHAR(20) | NO |  |  |
| stability\_rank | TINYINT | NO |  |  |

### etl.ETL\_BatchManifest

| Column | Type | Null | SCD class | Meaning |
| :---- | :---- | :---- | :---- | :---- |
| batch\_id | INT | NO |  |  |
| file\_name | VARCHAR(100) | NO |  |  |
| source\_row\_count | INT | NO |  |  |
| processing\_date | DATE | NO |  |  |
| window\_start | DATETIME2(0) | NO |  |  |
| window\_end\_exclusive | DATETIME2(0) | NO |  |  |
| cutoff\_ts | DATETIME2(0) | NO |  |  |

### etl.ETL\_Watermark

| Column | Type | Null | SCD class | Meaning |
| :---- | :---- | :---- | :---- | :---- |
| pipeline\_name | VARCHAR(50) | NO |  |  |
| last\_batch\_id | INT | NO |  |  |
| last\_cutoff\_ts | DATETIME2(0) | NO |  |  |
| updated\_at | DATETIME2(0) | NO |  |  |

### etl.ETL\_BatchLog

| Column | Type | Null | SCD class | Meaning |
| :---- | :---- | :---- | :---- | :---- |
| batch\_log\_id | INT | NO |  |  |
| batch\_id | INT | NO |  |  |
| package\_name | VARCHAR(100) | NO |  |  |
| start\_time | DATETIME2(0) | NO |  |  |
| end\_time | DATETIME2(0) | YES |  |  |
| status | VARCHAR(20) | NO |  |  |
| source\_rows | INT | YES |  |  |
| inserted\_rows | INT | YES |  |  |
| updated\_rows | INT | YES |  |  |
| rejected\_rows | INT | YES |  |  |
| error\_summary | NVARCHAR(2000) | YES |  |  |

### etl.ETL\_Rejects

| Column | Type | Null | SCD class | Meaning |
| :---- | :---- | :---- | :---- | :---- |
| reject\_id | INT | NO |  |  |
| batch\_id | INT | NO |  |  |
| source\_file | VARCHAR(100) | NO |  |  |
| business\_key | VARCHAR(100) | YES |  |  |
| reason\_code | VARCHAR(30) | NO |  |  |
| raw\_row | NVARCHAR(2000) | YES |  |  |
| rejected\_at | DATETIME2(0) | NO |  |  |

## C. Operational source \- TechnicalSupport\_Source (dbo)

Same structure as the original SQL Case Study. Subset: about 60 customers and 500+ tickets (Batch 0).

| Table | Column | Type | Null | Key | Description |
| :---- | :---- | :---- | :---- | :---- | :---- |
| customers | customer\_id | INT | NO | PK | Unique customer identifier (integer 1..200). |
| customers | customer\_name | NVARCHAR(100) | NO |  | Fictional company name. |
| customers | customer\_segment | VARCHAR(20) | NO |  | Enterprise, Large, Medium or Small. |
| customers | region | VARCHAR(20) | NO |  | Cairo, Giza, Alexandria, Delta or Upper Egypt. |
| customers | onboarding\_date | DATE | NO |  | Date the customer was onboarded. Tickets are never created before this date. |
| tickets | ticket\_id | INT | NO | PK | Unique ticket identifier. |
| tickets | customer\_id | INT | NO | FK \-\> customers | Customer that raised the ticket. |
| tickets | created\_at | DATETIME2(0) | NO |  | Creation timestamp (UTC). Equals the 'Created' status event. |
| tickets | priority | VARCHAR(10) | NO |  | Low, Medium, High or Critical. |
| tickets | channel | VARCHAR(10) | NO |  | Email, Portal, Phone or API. |
| ticket\_details | ticket\_id | INT | NO | PK, FK \-\> tickets | Ticket (0..1 details row per ticket; metadata is incomplete for some tickets). |
| ticket\_details | ticket\_name | NVARCHAR(200) | NO |  | Short title of the issue. |
| ticket\_details | ticket\_type | VARCHAR(30) | NO |  | Network, Software, Hardware, Database, Security, Access Management, Integration or Performance. |
| ticket\_details | severity | VARCHAR(10) | NO |  | Sev1 (most severe) .. Sev4. Correlated with, but not identical to, priority. |
| ticket\_details | description | NVARCHAR(500) | NO |  | Free-text description. |
| ticket\_status\_history | status\_event\_id | INT | NO | PK | Unique status event identifier (assigned in chronological feed order). |
| ticket\_status\_history | ticket\_id | INT | NO | FK \-\> tickets | Ticket the event belongs to. |
| ticket\_status\_history | status | VARCHAR(20) | NO |  | Created, Assigned, In Progress, Pending Customer, Escalated, Resolved, Closed, Reopened or Cancelled. |
| ticket\_status\_history | status\_at | DATETIME2(0) | NO |  | Moment the ticket entered this status (UTC). Strictly increasing per ticket. |
| ticket\_status\_history | changed\_by\_agent\_id | INT | YES | FK \-\> support\_agents | Agent who made the change; NULL for system / customer driven events. |
| ticket\_status\_history | status\_reason | VARCHAR(100) | YES |  | Optional reason text. |
| ticket\_breakdown | breakdown\_id | INT | NO | PK | Unique breakdown (technical work) event. |
| ticket\_breakdown | ticket\_id | INT | NO | FK \-\> tickets | Ticket the work was performed for. |
| ticket\_breakdown | occurred\_at | DATETIME2(0) | NO |  | Exact moment of the work event (UTC). |
| ticket\_breakdown | breakdown\_category | VARCHAR(30) | NO |  | Investigation, Diagnosis, Configuration, Repair, Replacement, Testing, Customer Communication, Escalation Work or Monitoring. |
| ticket\_breakdown | component\_name | VARCHAR(60) | NO |  | Affected component. |
| ticket\_breakdown | effort\_minutes | INT | NO |  | Effort in minutes (\> 0). |
| ticket\_breakdown | cost\_egp | DECIMAL(12,2) | NO |  | Synthetic cost in Egyptian pounds (\>= 0). |
| ticket\_breakdown | breakdown\_description | NVARCHAR(300) | NO |  | Free-text description of the work. |
| stability\_levels | stability\_status | VARCHAR(20) | NO | PK | very stable, stable, natural, unstable, very unstable ('natural' is intentional). |
| stability\_levels | stability\_rank | TINYINT | NO |  | 1 (best) .. 5 (worst). Higher rank \= worse stability. |
| customer\_stability\_observations | customer\_id | INT | NO | PK (part), FK \-\> customers | Customer observed. |
| customer\_stability\_observations | snapshot\_date | DATE | NO | PK (part) | Observation date; effective from 00:00:00 UTC of that date. Sparse: not every day has a row. |
| customer\_stability\_observations | stability\_status | VARCHAR(20) | NO | FK \-\> stability\_levels | Observed stability on that date. |
| support\_agents | agent\_id | INT | NO | PK | Unique agent identifier. |
| support\_agents | agent\_name | NVARCHAR(100) | NO |  | Fictional agent name. |
| support\_agents | team | VARCHAR(30) | NO |  | L1 Support, L2 Support, Network Operations, Database Operations, Security Operations or Escalation Team. |
| support\_agents | region | VARCHAR(20) | NO |  | Agent's home region. |
| support\_agents | hire\_date | DATE | NO |  | Hire date; no assignment starts before it. |
| ticket\_agent\_assignments | assignment\_id | INT | NO | PK | Unique ownership interval. |
| ticket\_agent\_assignments | ticket\_id | INT | NO | FK \-\> tickets | Ticket owned. |
| ticket\_agent\_assignments | agent\_id | INT | NO | FK \-\> support\_agents | Owning agent (primary owner). |
| ticket\_agent\_assignments | started\_at | DATETIME2(0) | NO |  | Start of ownership (inclusive). |
| ticket\_agent\_assignments | ended\_at | DATETIME2(0) | YES |  | End of ownership (exclusive). NULL \= still active at the analytical cutoff. |

### Relationships

| Relationship | Cardinality | Explanation |
| :---- | :---- | :---- |
| customers \-\> tickets | 1 : N (0..N) | A customer can have zero, one or many tickets; every ticket has exactly one customer. |
| tickets \-\> ticket\_details | 1 : 0..1 | A ticket has at most one details row. Some tickets have none (incomplete metadata ingestion). |
| tickets \-\> ticket\_status\_history | 1 : N (1..N) | Every ticket has at least the initial 'Created' event; statuses can repeat. |
| tickets \-\> ticket\_breakdown | 1 : 0..N | A ticket can have many breakdown events; some have none. |
| tickets \-\> ticket\_agent\_assignments | 1 : 0..N | A ticket can have several ownership intervals over time; some tickets are never assigned. |
| support\_agents \-\> ticket\_agent\_assignments | 1 : 0..N | An agent can own many tickets (also at the same time); some agents never receive tickets. |
| support\_agents \-\> ticket\_status\_history (changed\_by\_agent\_id) | 1 : 0..N (optional) | Status events may be performed by an agent or by the system (NULL). |
| customers \-\> customer\_stability\_observations | 1 : N | Sparse daily observations; at most one per customer per date. |
| stability\_levels \-\> customer\_stability\_observations | 1 : N | Lookup of the five stability labels and their ranks. |

## D. Flat file layouts

Files of a batch folder have the same column names as the source tables of section C, in the order of their header row. `customer_snapshot.csv` (delta batches) adds `effective_date`; in Batch 0 the file is called `customers.csv` and has no `effective_date`. Every folder contains `batch_manifest.csv` (columns: batch\_id, batch\_name, batch\_label, processing\_date, window\_start, window\_end\_exclusive, cutoff\_ts, file\_name, source\_row\_count).