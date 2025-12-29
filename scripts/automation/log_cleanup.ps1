<#
.SYNOPSIS
  Cleans up temp files and old logs to reclaim disk space.

.DESCRIPTION
  Deletes files older than a specified age from known temp/log locations.
  Runs in report-only mode by default unless -Force is specified.

.PARAMETER Paths
  One or more directories to clean.

.PARAMETER DaysOld
  Only delete files older than this many days. Default: 30.

.PARAMETER Force
  Actually delete files (otherwise run in dry-run mode).

.PARAMETER ExportPath
  CSV path for the cleanup report.

.EXAMPLE
  .\log_cleanup.ps1 -Paths "C:\Windows\Temp","C:\Logs" -DaysOld 14 -Force -ExportPath .\reports\log_cleanup.csv
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string[]]$Paths = @("C:\Windows\Temp","C:\Temp","C:\Logs"),

    [int]$DaysOld = 30,

    [switch]$Force,

    [string]$ExportPath = ".\reports\log_cleanup.csv"
)

begin {
    $ErrorActionPreference = 'Stop'

    $dir = Split-Path $ExportPath
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $cutoff = (Get-Date).AddDays(-$DaysOld)
    $results = New-Object System.Collections.Generic.List[object]
}

process {
    foreach ($p in $Paths) {
        if (-not (Test-Path $p)) {
            Write-Warning "Path not found: $p"
            continue
        }

        Write-Verbose "Scanning $p for files older than $DaysOld days..."

        Get-ChildItem -Path $p -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoff } |
            ForEach-Object {
                $action = if ($Force) { 'Delete' } else { 'DryRun' }

                if ($Force -and $PSCmdlet.ShouldProcess($_.FullName, "Delete old file")) {
                    try {
                        Remove-Item -Path $_.FullName -Force -ErrorAction Stop
                        $status = 'Deleted'
                    }
                    catch {
                        $status = "Error: $($_.Exception.Message)"
                    }
                }
                else {
                    $status = 'Skipped (dry-run)'
                }

                $results.Add([pscustomobject]@{
                    Path           = $_.FullName
                    SizeKB         = [math]::Round($_.Length / 1KB,2)
                    LastWriteTime  = $_.LastWriteTime
                    Action         = $action
                    Result         = $status
                    Timestamp      = (Get-Date)
                })
            }
    }
}

end {
    $results | Export-Csv -NoTypeInformation -Path $ExportPath
    Write-Host "Log cleanup report saved to $ExportPath"
    if (-not $Force) {
        Write-Host "NOTE: No files were deleted. Run again with -Force to apply changes."
    }
}
