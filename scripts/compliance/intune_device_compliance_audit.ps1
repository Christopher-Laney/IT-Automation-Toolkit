<#
.SYNOPSIS
  Audits Intune device compliance and exports a report.

.DESCRIPTION
  Queries managed devices from Microsoft Graph / Intune and captures:
  - Compliance status
  - OS version
  - Owner/user
  - Last check-in time

.REQUIREMENTS
  - Microsoft.Graph.DeviceManagement
  - Permissions: DeviceManagementManagedDevices.Read.All

.PARAMETER ExportPath
  CSV path for the compliance report.

.EXAMPLE
  .\intune_device_compliance_audit.ps1 -ExportPath .\reports\intune_compliance.csv
#>

[CmdletBinding()]
param(
    [string]$ExportPath = ".\reports\intune_compliance.csv"
)

begin {
    $ErrorActionPreference = 'Stop'

    $directory = Split-Path -Path $ExportPath
    if ($directory -and -not (Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    Write-Host "[INFO] Connecting to Microsoft Graph for Intune..." -ForegroundColor Cyan
    try {
        # Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All"
        # Select-MgProfile -Name "beta"
        Write-Host "[INFO] (Graph connect commented out; enable in production.)" -ForegroundColor Yellow
    }
    catch {
        Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
        return
    }
}

process {
    Write-Host "[INFO] Fetching managed devices..." -ForegroundColor Cyan

    # In production:
    # $devices = Get-MgDeviceManagementManagedDevice -All
    # Demo placeholder sample:
    $devices = @(
        [pscustomobject]@{
            DeviceName          = 'LAPTOP-001'
            UserPrincipalName   = 'user1@contoso.com'
            OperatingSystem     = 'Windows'
            OsVersion           = '10.0.19045'
            ComplianceState     = 'compliant'
            JailBroken          = $false
            LastSyncDateTime    = (Get-Date).AddHours(-3)
            DeviceEnrollmentType= 'Company'
        },
        [pscustomobject]@{
            DeviceName          = 'LAPTOP-002'
            UserPrincipalName   = 'user2@contoso.com'
            OperatingSystem     = 'Windows'
            OsVersion           = '10.0.18363'
            ComplianceState     = 'noncompliant'
            JailBroken          = $false
            LastSyncDateTime    = (Get-Date).AddDays(-5)
            DeviceEnrollmentType= 'Company'
        }
    )

    $rows = foreach ($d in $devices) {
        [pscustomobject]@{
            DeviceName        = $d.DeviceName
            UserPrincipalName = $d.UserPrincipalName
            OperatingSystem   = $d.OperatingSystem
            OsVersion         = $d.OsVersion
            ComplianceState   = $d.ComplianceState
            JailBroken        = $d.JailBroken
            LastSyncDateTime  = $d.LastSyncDateTime
            EnrollmentType    = $d.DeviceEnrollmentType
            DaysSinceLastSync = (New-TimeSpan -Start $d.LastSyncDateTime -End (Get-Date)).Days
        }
    }

    $rows | Export-Csv -NoTypeInformation -Path $ExportPath
    Write-Host "[SUCCESS] Intune compliance audit saved to: $ExportPath" -ForegroundColor Green

    $nonCompliant = $rows | Where-Object { $_.ComplianceState -ne 'compliant' -or $_.DaysSinceLastSync -gt 7 }
    if ($nonCompliant.Count -gt 0) {
        Write-Host "[WARN] Found non-compliant or stale devices:" -ForegroundColor Yellow
        $nonCompliant | Select-Object DeviceName,UserPrincipalName,ComplianceState,DaysSinceLastSync | Format-Table -AutoSize
    }
}

end { }
