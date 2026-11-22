# 02 - Setup Guide

> **Version note.** Installers, extension names, supported Visual Studio versions and edition feature lists change over time. Everything in this guide about Microsoft products is written from general knowledge, was **not** tested against your machine, and should be checked against the current Microsoft documentation before you install. Where a statement matters, it is marked **(check)**.

## 1. What you need
| Item | Notes |
|---|---|
| SQL Server (Database Engine) | SQL Server 2019 or later is the intended target. The **Developer** edition is free for development/training and has the full feature set **(check current licence terms)**. Express edition can host the databases but **does not include SQL Server Agent** and **does not run SSIS packages on the server** **(check the current edition feature comparison)** - you can still develop and run packages from Visual Studio if the SSIS runtime components are installed. |
| SQL Server Management Studio (SSMS) | To run the scripts and queries. |
| Visual Studio + SSIS project extension | The Integration Services project type is added by the extension "SQL Server Integration Services Projects" **(check the exact name and the Visual Studio versions it supports)**. Choose the extension version that matches the SQL Server version you target. |
| OLE DB provider | Packages in this course use the OLE DB provider for SQL Server (MSOLEDBSQL or the older SQLNCLI/SQLOLEDB). If a connection fails with "provider not registered" install the current Microsoft OLE DB Driver **(check)**. |
| Disk | The whole data set is a few MB. |

Do not install anything you do not understand on a work computer; use a personal or training VM.

## 2. Create the databases (one-time)
1. Unzip the package, e.g. to `C:\SSIS_Training\`.
2. Open `sql_setup\00_one_time_setup_all.sql` in SSMS, connected to your instance, and execute it once. It runs scripts 01-05 and 07: databases `TechnicalSupport_Source` and `TechnicalSupport_DW`, schemas (`dim`, `fact`, `hist`, `stg`, `etl`, `rpt`, `dbo`), empty tables with keys and constraints, DimDate, the Unknown ticket type, stability reference data and the reporting views. It is **re-runnable** (existing objects are kept).
   - If you prefer to go step by step, run `01_...` to `05_...`, then `07_...` in order.
   - Data file/log paths use the server defaults. If your server forbids that, change the `CREATE DATABASE` statements in script 01.
3. Seed the **source** database with the baseline (needed from Lab 3): run `sql_setup\06_seed_source_batch0.sql`. It deletes and reloads the 9 source tables, so it is also re-runnable.
4. To start a lab from scratch: `sql_setup\90_reset_dw_for_lab.sql` (read its header; choose the reset level). It only empties the warehouse database.

Check: in SSMS, `SELECT name FROM sys.databases WHERE name LIKE 'TechnicalSupport%'` returns two rows, and `SELECT COUNT(*) FROM TechnicalSupport_Source.dbo.customers` returns a non-zero number after step 3. You are expected to compare these numbers with the files yourself.

## 3. Unpack the data
Keep the `data` folder as delivered, in a path without exotic characters, e.g. `C:\SSIS_Training\data\`. Folders:
- `batch_00_initial` - baseline (Batch 0), 9 files + `batch_manifest.csv`
- `batch_01_delta`, `batch_02_delta` - two incremental batches (8 data files + manifest)
- `invalid_examples` - the dirty fixture for Lab 2 (5 files + manifest, batch id 99)
- `reference_data` - `priority_label_map.csv`
- `full_dataset_optional` - the complete original data (about 200 customers) if you want to test performance. The labs and checks are written for the training subset.

File format: UTF-8, comma separated, header row, CRLF line ends, double quote as text qualifier, dates `YYYY-MM-DD`, timestamps `YYYY-MM-DD HH:MM:SS` (UTC).

## 4. Create the SSIS project
Visual Studio > New Project > *Integration Services Project* > name `TechSupport_SSIS` (project deployment model is the default **(check)**). Add project parameters in Lab 1 (`ServerName`, `DataRoot`). Never hard-code your server name or paths.

## 5. Troubleshooting the setup
| Symptom | Likely cause |
|---|---|
| Script 01 fails on `CREATE DATABASE` | Insufficient permission, or a file path not allowed. Use an account with `dbcreator`, or edit the file paths. |
| "Login failed" from SSIS | The connection manager uses Windows authentication with a different account than SSMS - align the account or use SQL authentication in your training instance. |
| Flat file column truncated | Column width in the Flat File connection manager is too small - see Lab 1. |
| Provider not registered | Install the OLE DB driver; also check 32/64-bit run mode (`Run64BitRuntime` project property) **(check)**. |
| Package cannot find the CSV | The path expression uses the wrong parameter; print the evaluated `ConnectionString` while debugging. |

## 6. Honesty note about what was tested
The SQL scripts in `sql_setup` were syntax-checked with a parser and the logic of the views was exercised in a different SQL engine (DuckDB) by the course author. They were **not** run on SQL Server by the author, because none was available while this material was produced. If a script fails on your server, tell your instructor - it is a defect in the material, not in your setup.
