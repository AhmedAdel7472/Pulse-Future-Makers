# Submission Checklist

Hand in one ZIP per student (or team): `Surname_SSIS_Submission.zip`, containing the items below. Remove `bin` and `obj` folders from the SSIS project. **Do not include passwords or connection strings with secrets.**

## Always
- [ ] SSIS project (`.sln`, `.dtproj`, `.dtsx`, `.conmgr`, `.params`) - opens without errors
- [ ] `Student_Mapping.xlsx` completed (all columns for every mapped column; example values filled in)
- [ ] `SSIS_Training_Exercises.xlsx` (lab tracker, component checklist, acceptance tracker, reconciliation sheet) filled in
- [ ] A short note listing anything you did **not** finish or could **not** test, and why

## Per lab
| Lab | Hand in |
|---|---|
| 1 | Control-flow + one data-flow screenshot; count comparison table (4 files); answer: why read everything as text first? |
| 2 | Packages; reconciliation table per file (read = accepted + rejected); rejects by file and reason; answer: rule order |
| 3 | Packages and build-order sketch; reconciliation per table; 5 spot checks; answer: dimension loaded after the fact? |
| 4 | Packages; before/after listing per scenario; invariant query output; half-page native SCD vs manual comparison |
| 5 | Packages; one-page design; batch summaries for Batch 1 and Batch 2; rerun and forced-reprocess evidence; watermark paragraph |
| 6 | Master package; exact dtexec command and exit codes; Agent job definition **or** Task Scheduler + wrapper; 3 failure/recovery records; runbook page; "what I did not test" |

## Quality gate (tick before submitting)
- [ ] Every package runs twice in a row without changing any count the second time
- [ ] No literal server names or file paths inside components
- [ ] Every rejected row has a reason code, a file and a business key
- [ ] The watermark moves only after a fully successful batch
- [ ] Every claim in my notes is backed by a query result or a screenshot
