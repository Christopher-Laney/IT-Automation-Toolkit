# Quickstart

This guide helps you safely try the toolkit without changing production resources.

For a shorter no-tenant showcase, see `docs/demo_guide.md`.

## 1. Clone And Open The Repo

```powershell
git clone https://github.com/Christopher-Laney/IT-Automation-Toolkit.git
cd IT-Automation-Toolkit
```

## 2. Validate Script Syntax

```powershell
Get-ChildItem .\scripts -Recurse -Filter *.ps1 | ForEach-Object {
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$errors) | Out-Null
  $errors | ForEach-Object { "{0}:{1}: {2}" -f $_.Extent.File, $_.Extent.StartLineNumber, $_.Message }
}
```

No output means no parser errors were found.

## 3. Run A Safe Onboarding Preview

Validate the CSV before connecting to Microsoft Graph:

```powershell
.\scripts\identity\onboarding.ps1 -UserList .\config\new_users.csv -ValidateOnly
```

Then preview tenant changes with `-WhatIf`:

```powershell
.\scripts\identity\onboarding.ps1 -UserList .\config\new_users.csv -WhatIf
```

Review the proposed changes before running without `-WhatIf`.
Generated temporary passwords are omitted from the normal report output by default. For a controlled encrypted handoff path, see [onboarding_password_handoff.md](onboarding_password_handoff.md).
After a live onboarding batch, [identity_change_artifacts.md](identity_change_artifacts.md) shows how to turn the run report into a reviewable rollback ledger.

## 4. Prepare Optional Server Checks

Copy the server list example and replace the sample hostnames:

```powershell
Copy-Item .\config\servers.txt.example .\config\servers.txt
```

Then run operational checks only after the server list is accurate:

```powershell
.\scripts\automation\invoke_it_baseline_checks.ps1 -RunOps
```

## 5. Generate Local Reports

```powershell
.\scripts\reporting\inventory_report.ps1 -ExportPath .\reports\inventory.csv
.\scripts\reporting\generate_it_audit_dashboard.ps1 -ConfigPath .\config\dashboard_reports.json -OutputPath .\reports\it_audit_dashboard.html
```

Generated reports are ignored by git by default.

To preview the dashboard with sanitized sample data:

```powershell
.\scripts\reporting\generate_it_audit_dashboard.ps1 -ConfigPath .\config\dashboard_reports.sample.json -OutputPath .\reports\sample_it_audit_dashboard.html
```

You can also exercise the baseline orchestrator without tenant credentials or server access:

```powershell
.\scripts\automation\invoke_it_baseline_checks.ps1 -UseSampleData -DashboardOutputPath .\reports\sample_it_audit_dashboard.html
```

## 6. Validate An Intune Policy Template

Validate the template before connecting to Microsoft Graph:

```powershell
.\scripts\compliance\apply_intune_policy.ps1 -Path .\config\intune_policy_template.json -ValidateOnly
```

Use `-WhatIf` next when you are ready to preview policy deployment in a tenant.
