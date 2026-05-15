<#
.SYNOPSIS
  Generates an HTML IT audit dashboard from existing CSV reports.

.DESCRIPTION
  Reads various CSV outputs (inactive users, local admins, compliance, licenses, etc.)
  and produces a single HTML dashboard page.

.PARAMETER OutputPath
  HTML file to generate.

.PARAMETER Reports
  Hashtable mapping section titles to CSV paths.

.PARAMETER ConfigPath
  Optional JSON file with report title/path pairs. Defaults to config/dashboard_reports.json when present.

.PARAMETER MaxRows
  Maximum rows to display per report section. Default: 100.

.EXAMPLE
  .\generate_it_audit_dashboard.ps1 -OutputPath .\reports\it_audit_dashboard.html
#>

[CmdletBinding()]
param(
    [string]$OutputPath = ".\reports\it_audit_dashboard.html",

    [string]$ConfigPath,

    [hashtable]$Reports = @{
        "Inactive Users"        = ".\reports\inactive_users.csv";
        "Local Administrators"  = ".\reports\local_admins.csv";
        "Intune Compliance"     = ".\reports\intune_compliance.csv";
        "M365 License Audit"    = ".\reports\m365_license_audit.csv";
        "SSL Certificate Status"= ".\reports\ssl_expiry.csv"
    },

    [int]$MaxRows = 100
)

begin {
    $ErrorActionPreference = 'Stop'

    function Get-CsvHeaders {
        param([Parameter(Mandatory=$true)][string]$Path)

        $parser = [Microsoft.VisualBasic.FileIO.TextFieldParser]::new((Resolve-Path -LiteralPath $Path).Path)
        try {
            $parser.TextFieldType = [Microsoft.VisualBasic.FileIO.FieldType]::Delimited
            $parser.SetDelimiters(',')
            return @($parser.ReadFields())
        } finally {
            $parser.Close()
        }
    }

    $dir = Split-Path $OutputPath
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $sectionsHtml = @()
    $summaryRows = @()
    $missingReports = @()
    $reportDefinitions = @()

    if (-not $ConfigPath -and -not $PSBoundParameters.ContainsKey('Reports')) {
        $defaultConfig = ".\config\dashboard_reports.json"
        if (Test-Path $defaultConfig) { $ConfigPath = $defaultConfig }
    }

    if ($ConfigPath) {
        if (-not (Test-Path $ConfigPath)) { throw "Dashboard config not found: $ConfigPath" }
        $config = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json
        foreach ($report in $config.reports) {
            if (-not $report.title -or -not $report.path) {
                throw "Each dashboard report config item must include title and path."
            }
            $reportDefinitions += [pscustomobject]@{
                Title   = $report.title
                Path    = $report.path
                Columns = @($report.columns)
            }
        }
    } else {
        foreach ($title in ($Reports.Keys | Sort-Object)) {
            $reportDefinitions += [pscustomobject]@{
                Title   = $title
                Path    = $Reports[$title]
                Columns = @()
            }
        }
    }
}

process {
    foreach ($reportDefinition in $reportDefinitions) {
        $key = $reportDefinition.Title
        $path = $reportDefinition.Path
        if (-not (Test-Path $path)) {
            Write-Warning "Report not found for '$key': $path"
            $missingReports += [pscustomobject]@{
                Title = $key
                Path = $path
            }
            continue
        }

        Write-Verbose "Loading $key from $path ..."
        $data = Import-Csv -Path $path
        $rowCount = @($data).Count
        $requiredColumns = @($reportDefinition.Columns | Where-Object { $_ })

        if ($requiredColumns.Count -gt 0) {
            $availableColumns = @(Get-CsvHeaders -Path $path)

            $missingColumns = @($requiredColumns | Where-Object { $_ -notin $availableColumns })
            if ($missingColumns.Count -gt 0) {
                throw "Report '$key' is missing required column(s): $($missingColumns -join ', ')."
            }

            $data = $data | Select-Object -Property $requiredColumns
        }

        $summaryRows += [pscustomobject]@{
            Report = $key
            Rows = $rowCount
            Path = $path
        }

        $table = $data |
            Select-Object -First $MaxRows |
            ConvertTo-Html -As Table -PreContent "<h2>$key</h2><p class='meta'>$rowCount rows found. Showing up to $MaxRows.</p>" -Fragment
        $sectionsHtml += $table
    }
}

end {
    $summaryHtml = if ($summaryRows.Count -gt 0) {
        $summaryRows | ConvertTo-Html -As Table -PreContent "<h2>Report Summary</h2>" -Fragment
    } else {
        "<h2>Report Summary</h2><p>No report files were found.</p>"
    }

    $missingHtml = if ($missingReports.Count -gt 0) {
        $missingReports | ConvertTo-Html -As Table -PreContent "<h2>Missing Reports</h2><p class='warning'>These configured report files were not found.</p>" -Fragment
    } else {
        "<h2>Missing Reports</h2><p>None.</p>"
    }

    $body = @"
<style>
body { font-family: Segoe UI, Arial, sans-serif; margin: 32px; color: #1f2933; }
h1 { margin-bottom: 0; }
h2 { margin-top: 32px; border-bottom: 1px solid #d9e2ec; padding-bottom: 6px; }
table { border-collapse: collapse; width: 100%; margin: 12px 0 24px; font-size: 13px; }
th { background: #f0f4f8; text-align: left; }
th, td { border: 1px solid #d9e2ec; padding: 8px; vertical-align: top; }
.meta { color: #52606d; }
.warning { color: #9a3412; font-weight: 600; }
</style>
<h1>IT Audit Dashboard</h1>
<p>Generated: $(Get-Date)</p>
<hr/>
$summaryHtml
$missingHtml
$($sectionsHtml -join "`n")
"@

    $html = ConvertTo-Html -Title "IT Audit Dashboard" -Body $body
    $html | Out-File -FilePath $OutputPath -Encoding UTF8

    Write-Host "IT audit dashboard saved to $OutputPath"
}
