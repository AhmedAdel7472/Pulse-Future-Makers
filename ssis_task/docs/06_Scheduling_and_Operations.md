# 06 - Scheduling and Operations

> **Not tested here.** This is a set-up guide. Nothing in this package claims that a schedule, a SQL Server Agent job or the wrapper script was run. Command syntax and edition features must be checked in the Microsoft documentation of **your** SQL Server version **(check)**. Do not copy a command without reading what it does.

## 1. Three ways to start the pipeline
| Option | When it fits | What you need |
|---|---|---|
| **A. Manual** | development, one-off reprocess | Visual Studio (F5), SSMS (run a deployed package from the SSISDB catalog), or `dtexec` on a command line |
| **B. SQL Server Agent (time based)** | a batch is expected every night / hour | SQL Server Agent (a service of the Database Engine) and a deployed or file-based package |
| **C. File arrival** | a batch can arrive at any time | A **polling script** (PowerShell) run by Windows Task Scheduler every few minutes that checks the drop folder, then calls `dtexec` |

### Edition and version requirements **(check)**
- **SQL Server Agent**: part of the SQL Server editions that include it (Standard, Enterprise, Developer ...); **not available in Express**. Without Agent, use Windows Task Scheduler + `dtexec` (Option C style).
- **SSIS runtime / SSISDB catalog**: needs an edition that supports Integration Services on the server. Express edition does not run SSIS on the server. Developer edition is intended for development and learning.
- **SSIS project extension for Visual Studio**: version must match the SQL Server version you target.
- **dtexec**: ships with the SSIS runtime; 32-bit and 64-bit versions exist - the right one depends on your data providers.

## 2. Option A - manual runs
1. Visual Studio: right-click the master package > *Execute Package*; set the project parameters (`ServerName`, `DataRoot`, `BatchId`) in the debug configuration.
2. Command line (file system package): use `dtexec` with the file option and parameter overrides. Check the syntax of `/File`, `/Set` and `/Par` for your version **(check)**; write the exact command you used in your Lab 6 submission and the exit code you observed (0 = success, non-zero = failure).
3. Deployed project (SSISDB): the catalog also allows running from SSMS and from T-SQL; use only if you deployed.

## 3. Option B - SQL Server Agent job (time based)
Setup steps (do them on a server that has Agent):
1. Make sure the Agent service is running.
2. SSMS > SQL Server Agent > Jobs > New Job. Name it `TechSupport_LoadBatches`.
3. Step 1: type *SQL Server Integration Services Package* (package source: SSIS catalog or file system) **or** type *Operating system (CmdExec)* calling `dtexec`. Set the parameters here (not inside the package).
4. Run-as account: a proxy/credential with access to the files and databases (least privilege).
5. Schedule: for example daily at an hour after the batch files are normally delivered.
6. Notifications/alerts: at least "write to the Windows event log on failure" and, when your site has Database Mail, an operator email.
7. Document: what the job does, who owns it, what to do on failure.
A time-based job is simple but **blind to arrival**: if the files are late the job runs against nothing (the package's pre-checks must handle this: no new manifest = nothing to do = log *Skipped*).

## 4. Option C - file arrival: polling + Task Scheduler + wrapper + dtexec
**Event handlers are not triggers.** `OnError`, `OnPreExecute` and the other SSIS event handlers run *while a package is already executing*; they cannot start a package when a file appears. File arrival must be detected **outside** the package.

Design:
1. The data provider writes the CSV files of a batch into a new folder under a drop directory and writes `batch_manifest.csv` **last**. The manifest is the *ready marker* - a folder without it is incomplete and must be ignored.
2. A small script (`scripts/Run-TechSupportBatch.template.ps1`) is started by **Windows Task Scheduler** every few minutes. It: (a) lists batch folders that contain a manifest, (b) reads the batch id, (c) asks the database for the watermark and skips batches already processed, (d) starts the master package with `dtexec` for the next batch, (e) returns the exit code and writes a line to a log file.
3. The package itself repeats the safety checks (pre-checks, reconcile with the manifest) - the script is a convenience, never the only safeguard.
4. Alternative: a **FileSystemWatcher**-based service or SSIS's *WMI Event Watcher Task*. They have their own pitfalls (partial files, service lifetime) and are beyond this course; mention them only as alternatives.

Task Scheduler registration (outline): create a basic task > trigger "Daily", repeat every 5 minutes > action "Start a program": `powershell.exe` with arguments `-NoProfile -ExecutionPolicy Bypass -File "C:\SSIS_Training\scripts\Run-TechSupportBatch.ps1" -ServerName ... -DropRoot ...` > run whether the user is logged on or not > a service account with the least rights needed.

## 5. Operations checklist (the runbook you write in Lab 6 covers these)
- How to see whether the last run succeeded (`etl.ETL_BatchLog`; Agent job history; wrapper log file).
- How to see why rows were rejected (`etl.ETL_Rejects` by batch, file and reason).
- How to rerun a failed batch (just start it again - nothing to clean by hand).
- How to reprocess a *succeeded* batch deliberately (move the watermark back by one, run, verify counts are unchanged).
- Who is notified and how fast.
