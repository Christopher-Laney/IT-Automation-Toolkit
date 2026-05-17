# 15-Minute Demo Guide

This walkthrough shows the toolkit's safest high-value workflows without connecting to a production tenant or changing systems. It is designed for portfolio reviews, stakeholder demos, and first-time contributors.

See `docs/demo_transcript.md` for a generated sample transcript.

To refresh the sanitized markdown transcript after running the walkthrough, use:

```powershell
.\scripts\reporting\generate_demo_transcript.ps1 -OutputPath .\docs\demo_transcript.md
```

## What This Demonstrates

- End-to-end identity intake, approval, and audit packet generation.
- CSV validation before onboarding users.
- Intune template validation before Graph deployment.
- Dashboard generation from sanitized sample data.
- Backup dry-run safety and manifest documentation.
- Local test and analyzer commands.

## Prerequisites

- PowerShell 7 or later.
- Repository cloned locally.
- No Microsoft Graph, Azure, Okta, or server credentials are required for this demo.

```powershell
git clone https://github.com/Christopher-Laney/IT-Automation-Toolkit.git
cd IT-Automation-Toolkit
```

## 1. Validate The Repository

Run the parser-only check. This requires no extra modules:

```powershell
Get-ChildItem .\scripts,.\tests -Recurse -Filter *.ps1 | ForEach-Object {
  $tokens = $null
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors) | Out-Null
  $errors | ForEach-Object {
    "{0}:{1}: {2}" -f $_.Extent.File, $_.Extent.StartLineNumber, $_.Message
  }
}
```

Expected result: no output.

## 2. Run The Identity Workflow Demo

Run the sanitized identity workflow from ticket intake through review packet export:

```powershell
.\scripts\identity\invoke_identity_workflow_demo.ps1 `
  -OutputDirectory .\reports\identity-demo
```

Expected result: `reports/identity-demo/onboarding_from_ticket.csv` and `reports/identity-demo/identity_change_packet.json` are created without connecting to Microsoft Graph.

## 3. Validate Onboarding Input

Validate the sample onboarding CSV without connecting to Microsoft Graph:

```powershell
.\scripts\identity\onboarding.ps1 `
  -UserList .\config\new_users.csv `
  -ApprovalRecordPath .\config\approval_record.sample.json `
  -ValidateOnly
```

Expected result: `CSV validation passed`.

## 4. Validate Intune Templates

Validate the canonical Intune template:

```powershell
.\scripts\compliance\apply_intune_policy.ps1 `
  -Path .\config\intune_policy_template.json `
  -ValidateOnly
```

Validate one platform-specific example:

```powershell
.\scripts\compliance\apply_intune_policy.ps1 `
  -Path .\config\intune_policy_examples\windows_compliance_policy.json `
  -ValidateOnly
```

Expected result: `Template validation passed`.

## 5. Generate A Sample Dashboard

Generate an HTML dashboard from sanitized sample CSVs:

```powershell
New-Item -ItemType Directory -Path .\reports -Force | Out-Null

.\scripts\reporting\generate_it_audit_dashboard.ps1 `
  -ConfigPath .\config\dashboard_reports.sample.json `
  -OutputPath .\reports\sample_it_audit_dashboard.html
```

Expected result: `reports/sample_it_audit_dashboard.html` is created and includes sample identity, device, license, certificate, and system-health sections.

You can run the same sample dashboard through the baseline orchestrator:

```powershell
.\scripts\automation\invoke_it_baseline_checks.ps1 `
  -UseSampleData `
  -DashboardOutputPath .\reports\sample_it_audit_dashboard.html
```

Expected result: the baseline summary reports that a sample IT audit dashboard was generated from sanitized reports.

## 6. Preview Backup Safety

Run a backup preview. Replace paths with local demo folders if needed:

```powershell
.\scripts\automation\backup_automation.ps1 `
  -SourcePath .\samples `
  -DestinationPath .\reports\backup-demo `
  -ExcludeExtensions ".tmp",".log" `
  -RetentionDays 14 `
  -WhatIf
```

Expected result: PowerShell shows planned actions and no archive is created.

Review the sanitized manifest example:

```powershell
Get-Content .\samples\backups\backup-20260514-000000-sample.json
```

## 7. Optional Full Local Tests

Install local test tools only if you want to run the full suite outside GitHub Actions:

```powershell
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module Pester -Scope CurrentUser -Force -SkipPublisherCheck
Install-Module PSScriptAnalyzer -Scope CurrentUser -Force -SkipPublisherCheck
```

Run the same checks used by CI:

```powershell
Invoke-Pester -Path .\tests -CI
Invoke-ScriptAnalyzer -Path .\scripts -Recurse -Settings .\PSScriptAnalyzerSettings.psd1 -Severity Error
```

## Where To Go Next

- Refresh `docs/demo_transcript.md` when you want an updated shareable record of the walkthrough.
- Read `docs/identity_workflow_demo.md` for the focused end-to-end identity storyline.
- Read `docs/quickstart.md` for a broader local walkthrough.
- Read `docs/scheduling.md` for Task Scheduler, Azure Automation, and GitHub Actions examples.
- Read `docs/backup_restore.md` before running real backups or restores.
- Read `docs/intune_policy_templates.md` before deploying Intune policies.
