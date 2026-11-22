# Lab 01 \- Flat Files into SQL Server

**Difficulty:** Beginner (1 of 5\)  \|  **Estimated effort:** 3 hours  \|  **Mode:** hands-on in Visual Studio (SSIS); T-SQL only where the lab says so

## 1\. Business scenario

The support operations team publishes CSV extracts. Before anything can be analysed, the files of the baseline load (Batch 0\) have to land in typed staging tables in the data warehouse database, and the load has to be provably complete: every row announced by the batch manifest must be accounted for. This is your first SSIS package and the pattern you will reuse in every later lab.

## 2\. Learning objectives

- Create an SSIS project with project parameters and reusable connection managers  
- Configure a Flat File connection correctly (header, text qualifier, UTF-8, row delimiter)  
- Convert text columns to SQL Server data types with Data Conversion  
- Load staging tables with an OLE DB Destination (fast load)  
- Capture row counts with Row Count and compare them with the manifest using a precedence constraint expression  
- Make the load re-runnable (no duplicates when it runs twice)

## 3\. Prerequisites

- SQL Server 2019 or later and SSMS  
- Visual Studio with the SQL Server Integration Services Projects extension (see docs/02\_Setup\_Guide.md)  
- Scripts 01-05 run (`sql_setup/00_one_time_setup_all.sql`); `student/data` unpacked to a folder you can read

## 4\. Input files / sources

- data/batch\_00\_initial/batch\_manifest.csv  
- data/batch\_00\_initial/customers.csv  
- data/batch\_00\_initial/support\_agents.csv  
- data/batch\_00\_initial/tickets.csv  
- data/batch\_00\_initial/ticket\_details.csv

## 5\. Source and destination

- **Source:** Flat files (UTF-8, comma separated, header row, CRLF row delimiter, text qualifier `"`)  
- **Destination:** TechnicalSupport\_DW: etl.ETL\_BatchManifest, stg.customer\_snapshot, stg.support\_agents, stg.tickets, stg.ticket\_details

## 6\. Required operations (exactly what you must build)

### 1\. Project, parameters, connections

- Create the Integration Services project `TechSupport_SSIS`. Add project parameters `ServerName` (String) and `DataRoot` (String, folder that contains `batch_00_initial`, `batch_01_delta`, ...).  
- Create ONE OLE DB connection manager `cm_DW` to `TechnicalSupport_DW` whose server name comes from the parameter (expression on the connection string / ServerName property).  
- Create flat file connection managers (one per file layout). Set: header row \= first row, text qualifier \= `"`, row delimiter \= CRLF, code page 65001 (UTF-8). In the Advanced page set EVERY column to string `DT_WSTR` with a generous length \- you will convert types yourself. Put an expression on `ConnectionString` so the file path is built from `DataRoot` \+ folder variable \+ file name (no literal path in any component).

### 2\. Package `Lab01_Load_Staging`

- Variables: `BatchId` (Int32, value 0), `BatchFolder` (String, `batch_00_initial`), `RowsRead_*` (Int32, one per file), `ManifestRows` (Int32).  
- Task 1 \- Execute SQL Task: delete the rows of this batch from the four staging tables AND from etl.ETL\_BatchManifest (`DELETE ... WHERE batch_id = ?`, parameter mapped to `User::BatchId`). This is what makes the package re-runnable.  
- Task 2 \- Data flow for `batch_manifest.csv` \-\> `etl.ETL_BatchManifest` (convert dates and counts with Data Conversion).  
- Tasks 3-6 \- one Data Flow per data file (`customers.csv` into `stg.customer_snapshot`, `support_agents.csv`, `tickets.csv`, `ticket_details.csv`): Flat File Source \-\> Data Conversion (to the staging data types) \-\> Derived Column (`batch_id` \= `@[User::BatchId]`, `source_file` \= the file name) \-\> Row Count (store in `User::RowsRead_*`) \-\> OLE DB Destination (table or view \- fast load). Map only the data columns plus `batch_id` and `source_file`; do not map `source_row_number` (the database numbers the rows). `customers.csv` has no `effective_date` column: leave it NULL.  
- Task 7 \- Execute SQL Task: read the announced row counts from `etl.ETL_BatchManifest` for this batch (one row per file) into variables.  
- Task 8 \- Precedence constraints with EXPRESSIONS: continue to the final task only when every `RowsRead_*` equals the announced count; otherwise end in a failure path that raises an error with a clear message.

### 3\. Prove it

- Run the package twice. After each run, compare `COUNT(*)` per staging table for `batch_id = 0` with the manifest and with the number of data rows of the file (rows in the file minus the header).  
- Open one of the staged tables and check that dates are DATE/DATETIME values, ids are integers and nothing is truncated (compare the longest customer name in the file with the table).

## 7\. Expected output structure

Five tables filled for batch\_id \= 0: etl.ETL\_BatchManifest (one row per announced file), stg.customer\_snapshot, stg.support\_agents, stg.tickets, stg.ticket\_details. Columns exactly as created by script 04\.

## 8\. Acceptance criteria

- [ ] For each of the four data files: rows in the staging table (batch 0\) \= data rows of the CSV \= `source_row_count` of the manifest  
- [ ] Running the package a second time leaves every count unchanged (no duplicates)  
- [ ] No component contains a hard-coded server name or file path (parameters/expressions only)  
- [ ] A deliberately wrong manifest count makes the package fail with a readable message (try it on a copy and undo it)  
- [ ] All staging columns have the data type declared in script 04 (no implicit conversion warnings left on the Data Conversion steps)

## 9\. SSIS components used (and why)

| Component | Meaningful use in this lab |
| :---- | :---- |
| Flat File Source | Read every CSV as text so that bad values reach YOUR validation instead of failing inside the source |
| Data Conversion | Convert text to INT / DATE / DATETIME / DECIMAL; its error output feeds INVALID\_NUMBER / INVALID\_DATE rejects |
| Derived Column | Trim/collapse text, blank \-\> NULL, add batch\_id, source\_file, reason\_code, computed keys and minutes |
| Row Count | Capture source / loaded / rejected counts into variables for reconciliation and logging |
| OLE DB Destination | Fast-load staging, dimension, fact, history and reject tables |
| Execute SQL Task | Clean a batch before reloading, read manifest/watermark, set-based SCD updates, advance the watermark, write the audit log |
| Variables | BatchId, CutoffTs, folder/file names, row counts, flags used in expressions |
| Parameters | Project/package parameters: ServerName, DataRoot, BatchId \- nothing environment specific is hard-coded |
| Precedence Constraints | Success / failure / expression constraints: reconcile counts, skip an already processed batch, advance the watermark last |

## 10\. Hints (not answers)

- If the Flat File Source reports truncation, increase the column length in the connection manager (Advanced page).  
- `DT_WSTR` \-\> `DT_I4` for ids, `DT_DBTIMESTAMP` for timestamps, `DT_DBDATE` for dates.  
- The OLE DB parameter marker in an Execute SQL Task is `?`; map parameters by ORDINAL on the Parameter Mapping page.

## 11\. Submission checklist

- [ ] Project folder (`.sln`, `.dtsx`, `.conmgr`, `.params`) zipped without `bin`/`obj`  
- [ ] Screenshot of the control flow and of one data flow  
- [ ] Result of the count comparison for the four files (table)  
- [ ] Short answer: why is every flat file column read as text first?