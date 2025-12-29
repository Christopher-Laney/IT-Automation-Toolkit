<#
.SYNOPSIS
  Runs a baseline set of IT health checks and automation scripts.

.DESCRIPTION
  Wrapper/orchestrator around multiple scripts in the IT-Automation-Toolkit.
  Intended to be scheduled (daily/weekly) and later wired into Teams/email alerts.

.PARAMETER RunCompliance
  Include compliance-related scripts (Intune, inactive users, licenses).

.PARAMETER RunOps
  Include operational scripts (system health, failed services, log cleanup).

.PARAMETER TeamsWebhook
  Optional Teams webhook URL to send a summary notification.

.EXAMPLE
  .\invoke_it_baseline_checks.ps1 -RunCompliance -RunOps -TeamsWebhook "https://outlook.office.com/webhook/..."
#>

[CmdletBinding()]
param(
    [switch]$RunCompliance,
    [switch]$RunOps,
    [string]$TeamsWebhook
)

begin {
    $ErrorActionPreference = 'Stop'
    $results = @()
}

process {
    $scriptsPath = Split-Path -Parent $MyInvocation.MyCommand.Path

    if ($RunCompliance) {
        Write-Host "[COMPLIANCE] Running inactive_user_report..." -ForegroundColor Cyan
        & "$scriptsPath\inactive_user_report.ps1" -Mode AzureAD -InactiveDays 45 -ExportPath ".\reports\inactive_users.csv"
        $results += "Inactive user report completed."

        Write-Host "[COMPLIANCE] Running m365_license_audit..." -ForegroundColor Cyan
        & "$scriptsPath\m365_license_audit.ps1" -RequiredSkuPartNumber "SPE_E3" -ExportPath ".\reports\m365_license_audit.csv"
        $results += "M365 license audit completed."

        Write-Host "[COMPLIANCE] Running intune_device_compliance_audit..." -ForegroundColor Cyan
        & "$scriptsPath\intune_device_compliance_audit.ps1" -ExportPath ".\reports\intune_compliance.csv"
        $results += "Intune compliance audit completed."
    }

    if ($RunOps) {
        Write-Host "[OPS] Running system_health_report..." -ForegroundColor Cyan
        & "$scriptsPath\system_health_report.ps1" -ComputerList ".\config\servers.txt" -ExportCsv ".\reports\system_health.csv"
        $results += "System health report completed."

        Write-Host "[OPS] Running restart_failed_services..." -ForegroundColor Cyan
        & "$scriptsPath\restart_failed_services.ps1" -ComputerName (Get-Content .\config\servers.txt) -ReportPath ".\reports\restart_failed_services.csv"
        $results += "Restart failed services run completed."

        Write-Host "[OPS] Running log_cleanup (dry run)..." -ForegroundColor Cyan
        & "$scriptsPath\log_cleanup.ps1" -Paths "C:\Windows\Temp","C:\Logs" -DaysOld 30 -ExportPath ".\reports\log_cleanup.csv"
        $results += "Log cleanup (dry-run) completed."
    }

    # Generate dashboard
    & "$scriptsPath\generate_it_audit_dashboard.ps1" -OutputPath ".\reports\it_audit_dashboard.html"
    $results += "IT audit dashboard generated."
}

end {
    $summary = $results -join "`n"

    Write-Host "`n=== Baseline Checks Summary ===" -ForegroundColor Green
    Write-Host $summary

    if ($TeamsWebhook) {
        Write-Host "[INFO] Sending summary to Teams..." -ForegroundColor Cyan
        & "$scriptsPath\teams_webhook_alert.ps1" `
            -WebhookUrl $TeamsWebhook `
            -Title "IT Baseline Checks Completed" `
            -Message ("```" + $summary + "```") `
            -Severity "Info"
    }
}
