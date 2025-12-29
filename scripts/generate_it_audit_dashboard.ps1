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

.EXAMPLE
  .\generate_it_audit_dashboard.ps1 -OutputPath .\reports\it_audit_dashboard.html
#>

[CmdletBinding()]
param(
    [string]$OutputPath = ".\reports\it_audit_dashboard.html",

    [hashtable]$Reports = @{
        "Inactive Users"        = ".\reports\inactive_users.csv";
        "Local Administrators"  = ".\reports\local_admins.csv";
        "Intune Compliance"     = ".\reports\intune_compliance.csv";
        "M365 License Audit"    = ".\reports\m365_license_audit.csv";
        "SSL Certificate Status"= ".\reports\ssl_expiry.csv"
    }
)

begin {
    $ErrorActionPreference = 'Stop'

    $dir = Split-Path $OutputPath
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $sectionsHtml = @()
}

process {
    foreach ($key in $Reports.Keys) {
        $path = $Reports[$key]
        if (-not (Test-Path $path)) {
            Write-Warning "Report not found for '$key': $path"
            continue
        }

        Write-Verbose "Loading $key from $path ..."
        $data = Import-Csv -Path $path

        $table = $data | Select-Object -First 100 | ConvertTo-Html -As Table -PreContent "<h3>$key</h3>" -Fragment
        $sectionsHtml += $table
    }
}

end {
    $body = @"
<h1>IT Audit Dashboard</h1>
<p>Generated: $(Get-Date)</p>
<hr/>
$($sectionsHtml -join "`n")
"@

    $html = ConvertTo-Html -Title "IT Audit Dashboard" -Body $body
    $html | Out-File -FilePath $OutputPath -Encoding UTF8

    Write-Host "IT audit dashboard saved to $OutputPath"
}
