# Demo Transcript

Generated from the safe no-tenant walkthrough in `docs/demo_guide.md`.

Generated UTC: 2026-05-15

## Validate Repository Syntax

```powershell
Get-ChildItem .\scripts,.\tests -Recurse -Filter *.ps1 | ForEach-Object { <parser check> }
```

```text
(no output)
```

## Validate Onboarding Input

```powershell
.\scripts\identity\onboarding.ps1 -UserList .\config\new_users.csv -ValidateOnly
```

```text
CSV validation passed: 2 user row(s).
```

## Validate Intune Template

```powershell
.\scripts\compliance\apply_intune_policy.ps1 -Path .\config\intune_policy_template.json -ValidateOnly
```

```text
Template validation passed: ./config/intune_policy_template.json
```

## Generate Sample Dashboard

```powershell
.\scripts\automation\invoke_it_baseline_checks.ps1 -UseSampleData -DashboardOutputPath .\reports\sample_it_audit_dashboard.html
```

```text
IT audit dashboard saved to ./reports/sample_it_audit_dashboard.html

=== Baseline Checks Summary ===
Sample IT audit dashboard generated from sanitized reports.
```

## Preview Backup Safety

```powershell
.\scripts\automation\backup_automation.ps1 -SourcePath .\samples -DestinationPath .\reports\backup-demo -ExcludeExtensions ".tmp",".log" -RetentionDays 14 -WhatIf
```

```text
[<timestamp>] [INFO] Starting backup: Source='./samples' Dest='./reports/backup-demo' Tag='' RetentionDays=14
[<timestamp>] [INFO] Files selected: 10
[<timestamp>] [INFO] Archive was not created. Skipping encryption, manifest, upload, and notification steps.
Backup preview complete:
  Planned ZIP: ./reports/backup-demo/backup-<timestamp>.zip
```

