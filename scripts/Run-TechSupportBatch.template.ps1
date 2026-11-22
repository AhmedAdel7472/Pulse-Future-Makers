<#
 Run-TechSupportBatch.template.ps1   --  TEMPLATE FOR LAB 06 (student)  --  NOT TESTED, NOT COMPLETE.
 Purpose : start the master package for the NEXT pending batch when a complete batch folder has arrived.
 Rules   : the batch folder is "complete" only when batch_manifest.csv exists (it is written LAST by the provider).
           SSIS event handlers are NOT used to detect file arrival.
 You     : replace every TODO. Read the documentation of dtexec for YOUR SQL Server version before filling in the call.
#>
param(
    [Parameter(Mandatory)] [string] $ServerName,     # SQL Server instance
    [Parameter(Mandatory)] [string] $DropRoot,       # folder that contains one sub-folder per batch
    [string] $PackagePath = "TODO: path to the master package or SSISDB path",
    [string] $LogFile = (Join-Path $PSScriptRoot "run_log.txt")
)

function Write-Log([string]$msg) { "{0}  {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg | Add-Content -Path $LogFile }

# 1. TODO: find the watermark (last processed batch id) from etl.ETL_Watermark.
#    Options: Invoke-Sqlcmd (module "SqlServer") or sqlcmd.exe. Decide which one is available on your machine.
$lastBatch = $null   # TODO

# 2. TODO: list candidate batch folders that already contain batch_manifest.csv; read the batch_id from the manifest (first data row).
$candidates = @()    # TODO: objects with BatchId and Folder

# 3. TODO: choose the smallest BatchId greater than the watermark. If none -> log "nothing to do" and exit 0.

# 4. TODO: start dtexec with the parameters of the package (ServerName, DataRoot, BatchId).
#    Capture $LASTEXITCODE. Write it to the log. Exit with it.

Write-Log "TODO: not implemented"
exit 2
