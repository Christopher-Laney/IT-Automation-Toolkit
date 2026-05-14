# Testing Guide

This repository validates PowerShell scripts in GitHub Actions on every pull request. The workflow installs Pester and PSScriptAnalyzer automatically, so contributors do not need local tooling just to open a PR.

Local testing is still useful before larger script changes.

## Install Local Test Tools

Run this once in PowerShell:

```powershell
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module Pester -Scope CurrentUser -Force -SkipPublisherCheck
Install-Module PSScriptAnalyzer -Scope CurrentUser -Force -SkipPublisherCheck
```

## Run The Full Local Suite

From the repository root:

```powershell
Invoke-Pester -Path .\tests -CI
Invoke-ScriptAnalyzer -Path .\scripts -Recurse -Settings .\PSScriptAnalyzerSettings.psd1 -Severity Error
```

## Run The No-Dependency Parser Check

Use this when Pester is not installed:

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

No output means no parser errors were found.

## Useful Focused Checks

Onboarding CSV validation:

```powershell
.\scripts\identity\onboarding.ps1 -UserList .\config\new_users.csv -ValidateOnly
```

Intune template validation:

```powershell
.\scripts\compliance\apply_intune_policy.ps1 -Path .\config\intune_policy_template.json -ValidateOnly
```

Dashboard sample generation:

```powershell
.\scripts\reporting\generate_it_audit_dashboard.ps1 `
  -ConfigPath .\config\dashboard_reports.sample.json `
  -OutputPath .\reports\sample_it_audit_dashboard.html
```

Backup preview:

```powershell
.\scripts\automation\backup_automation.ps1 `
  -SourcePath "D:\Data" `
  -DestinationPath "E:\Backups" `
  -WhatIf
```

## CI Reference

The GitHub Actions workflow lives at `.github/workflows/powershell-validation.yml`.
It runs on the `windows-2025-vs2026` hosted image so validation matches the Windows runner image GitHub is moving `windows-latest` toward in June 2026.

The workflow uses read-only repository permissions and runs:

- `Invoke-Pester -Path ./tests -CI`
- `Invoke-ScriptAnalyzer -Path ./scripts -Recurse -Settings ./PSScriptAnalyzerSettings.psd1 -Severity Error`
