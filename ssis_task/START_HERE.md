# START HERE - Technical Support Operations: SSIS & Data Integration Training

Welcome. This package turns the **Technical Support SQL Case Study** into a hands-on **SSIS / ETL** project. You build the pipelines in Visual Studio (SSIS); T-SQL supports staging, merges and checks. Nothing here is a finished solution: you prove your own work with reconciliation.

## 1. What is in this package
| Folder / file | What it is |
|---|---|
| `docs/01_Business_Case_Study.md` | The business story and what the warehouse must answer |
| `docs/02_Setup_Guide.md` | SQL Server, Visual Studio, databases, data - **read before anything else** |
| `docs/03_Data_Dictionary.md` | Every table (source, staging, warehouse) with types and grains |
| `docs/04_Target_Model_and_Rules.md` | Star schema, grains, temporal rules, SCD rules, reject codes, batch calendar |
| `docs/05_Incremental_Loading_Design.md` | Manifest + watermark + business keys; failure and rerun behaviour |
| `docs/06_Scheduling_and_Operations.md` | Manual, SQL Server Agent, file-arrival wrapper (setup instructions, untested) |
| `labs/LAB_01 ... LAB_06` | The six labs |
| `Student_Mapping.xlsx` | Source-to-target mapping workbook - **partly filled in: you complete it** |
| `SSIS_Training_Exercises.xlsx` | Lab tracker, component checklist, acceptance tracker, reconciliation template |
| `SUBMISSION_CHECKLIST.md` | What to hand in |
| `sql_setup/` | Setup scripts (`00_one_time_setup_all.sql` creates everything), source seed, reset script, SCD scratch table, self-check queries |
| `data/` | Batch 0 (baseline), Batch 1 and 2 (deltas), dirty examples, reference data, optional full data set |
| `diagrams/` | Target star schema, source-to-destination flow, batch load flow (PNG + Mermaid source) |
| `scripts/` | A PowerShell wrapper **template** for Lab 6 |

## 2. First steps (30 minutes)
1. Read `docs/01` and `docs/02`; install what you need.
2. Run `sql_setup/00_one_time_setup_all.sql`, then `sql_setup/06_seed_source_batch0.sql`.
3. Look at `diagrams/source_to_destination.png` and `diagrams/target_star_schema.png`.
4. Skim `docs/04` - you will come back to it in every lab.

## 3. Recommended build order
| Order | Lab | Why in this order |
|---|---|---|
| 1 | **Lab 1** Flat files to SQL Server | Connections, parameters, staging, counts - the pattern for everything else |
| 2 | **Lab 2** Transformation and cleansing | Validation and rejects are used by every later lab |
| 3 | **Lab 3** Database migration and warehouse load | Builds the star schema; point-in-time lookups; reconciliation |
| 4 | **Lab 4** SCD Type 1 / Type 2 | Customer history; needs Lab 3 data |
| 5 | **Lab 5** Incremental loading and reprocessing | Reuses 1-4; manifest, watermark, rerun |
| 6 | **Lab 6** Scheduling, logging, production readiness | Wraps Lab 5 for unattended operation |

Inside a lab: read the whole lab first, build staging/control pieces first, then transformations, then loads, then reconcile.
Load order in the warehouse is dictated by foreign keys: dimensions -> FactTicket header -> status events/history -> lifecycle measures -> breakdowns.

## 4. How you are assessed
Against the **acceptance criteria** at the end of each lab and the **submission checklist**. Correct numbers matter, but so do re-runnability, handling of bad data, and being able to explain why each component is used. There are no hidden "expected counts" for you to copy: reconcile against the files, the manifest and the source database.

## 5. Rules of the road
- Never edit the CSV files. Fix problems in the pipeline.
- No hard-coded servers or paths - use parameters and expressions.
- No system clock for business dates - batch cutoffs and effective dates come from the manifests and files.
- Re-run everything at least twice. A pipeline that only works once is not finished.
- If something in the material looks wrong, tell your instructor - the SQL scripts were not executed on SQL Server by the author (see `docs/02`).

## 6. Getting unstuck
`sql_setup/95_student_selfcheck.sql` has generic sanity checks (zero rows = good). Use the data dictionary, the grains table in `docs/04`, and the hints at the end of each lab.
