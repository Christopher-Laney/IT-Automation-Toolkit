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

.PARAMETER UseSampleData
  Generate the baseline dashboard from sanitized sample CSVs without running live compliance or operations checks.

.PARAMETER DashboardOutputPath
  HTML dashboard file to generate.

.EXAMPLE
  .\invoke_it_baseline_checks.ps1 -RunCompliance -RunOps -TeamsWebhook "https://outlook.office.com/webhook/..."

.EXAMPLE
  .\invoke_it_baseline_checks.ps1 -UseSampleData -DashboardOutputPath ".\reports\sample_it_audit_dashboard.html"
#>

[CmdletBinding()]
param(
    [switch]$RunCompliance,
    [switch]$RunOps,
    [string]$TeamsWebhook,
    [switch]$UseSampleData,
    [string]$DashboardOutputPath = ".\reports\it_audit_dashboard.html"
)

begin {
    $ErrorActionPreference = 'Stop'
    $results = @()

    if ($UseSampleData -and ($RunCompliance -or $RunOps)) {
        throw "UseSampleData cannot be combined with RunCompliance or RunOps. Run sample data separately from live checks."
    }
}

process {
    $automationPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    $scriptsRoot = Split-Path -Parent $automationPath
    $identityPath = Join-Path $scriptsRoot 'identity'
    $reportingPath = Join-Path $scriptsRoot 'reporting'
    $compliancePath = Join-Path $scriptsRoot 'compliance'
    $notificationsPath = Join-Path $scriptsRoot 'notifications'
    $configRoot = Join-Path (Split-Path -Parent $scriptsRoot) 'config'
    $serverList = Join-Path $configRoot 'servers.txt'
    $dashboardScript = Join-Path $reportingPath 'generate_it_audit_dashboard.ps1'

    if ($RunCompliance) {
        Write-Host "[COMPLIANCE] Running inactive_user_report..." -ForegroundColor Cyan
        & (Join-Path $identityPath 'inactive_user_report.ps1') -Mode AzureAD -InactiveDays 45 -ExportPath ".\reports\inactive_users.csv"
        $results += "Inactive user report completed."

        Write-Host "[COMPLIANCE] Running m365_license_audit..." -ForegroundColor Cyan
        & (Join-Path $reportingPath 'm365_license_audit.ps1') -RequiredSkuPartNumber "SPE_E3" -ExportPath ".\reports\m365_license_audit.csv"
        $results += "M365 license audit completed."

        Write-Host "[COMPLIANCE] Running intune_device_compliance_audit..." -ForegroundColor Cyan
        & (Join-Path $compliancePath 'intune_device_compliance_audit.ps1') -ExportPath ".\reports\intune_compliance.csv"
        $results += "Intune compliance audit completed."
    }

    if ($RunOps) {
        if (-not (Test-Path $serverList)) {
            throw "Server list not found: $serverList. Create config\servers.txt or run compliance-only checks."
        }

        Write-Host "[OPS] Running system_health_report..." -ForegroundColor Cyan
        & (Join-Path $reportingPath 'system_health_report.ps1') -ComputerList $serverList -ExportCsv ".\reports\system_health.csv"
        $results += "System health report completed."

        Write-Host "[OPS] Running restart_failed_services..." -ForegroundColor Cyan
        & (Join-Path $automationPath 'restart_failed_services.ps1') -ComputerName (Get-Content $serverList) -ReportPath ".\reports\restart_failed_services.csv"
        $results += "Restart failed services run completed."

        Write-Host "[OPS] Running log_cleanup (dry run)..." -ForegroundColor Cyan
        & (Join-Path $automationPath 'log_cleanup.ps1') -Paths "C:\Windows\Temp","C:\Logs" -DaysOld 30 -ExportPath ".\reports\log_cleanup.csv"
        $results += "Log cleanup (dry-run) completed."
    }

    # Generate dashboard
    if ($UseSampleData) {
        $sampleDashboardConfig = Join-Path $configRoot 'dashboard_reports.sample.json'
        & $dashboardScript -ConfigPath $sampleDashboardConfig -OutputPath $DashboardOutputPath
        $results += "Sample IT audit dashboard generated from sanitized reports."
    } else {
        & $dashboardScript -OutputPath $DashboardOutputPath
        $results += "IT audit dashboard generated."
    }
}

end {
    $summary = $results -join "`n"

    Write-Host "`n=== Baseline Checks Summary ===" -ForegroundColor Green
    Write-Host $summary

    if ($TeamsWebhook) {
        Write-Host "[INFO] Sending summary to Teams..." -ForegroundColor Cyan
        & (Join-Path $notificationsPath 'teams_webhook_alert.ps1') `
            -WebhookUrl $TeamsWebhook `
            -Title "IT Baseline Checks Completed" `
            -Message ('```' + $summary + '```') `
            -Severity "Info" `
            -Category "Automation" `
            -CardFormat "AdaptiveCard"
    }
}
