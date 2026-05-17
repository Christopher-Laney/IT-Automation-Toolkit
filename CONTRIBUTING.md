# Contributing

Thanks for helping improve the IT Automation Toolkit. The project favors practical, auditable scripts that are safe to test before production use.

## Development Workflow

1. Create a feature branch from `main`.
2. Keep changes focused on one script, workflow, or documentation area.
3. Add or update examples when parameters or behavior change.
4. Run validation before opening a pull request.

## Validation

Run a parser check before submitting script changes:

```powershell
Get-ChildItem .\scripts -Recurse -Filter *.ps1 | ForEach-Object {
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$errors) | Out-Null
  $errors | ForEach-Object { "{0}:{1}: {2}" -f $_.Extent.File, $_.Extent.StartLineNumber, $_.Message }
}
```

When available, also run:

```powershell
Invoke-Pester -Path .\tests -CI
.\scripts\reporting\test_generated_artifacts.ps1
Invoke-ScriptAnalyzer -Path .\scripts -Recurse -Severity Error
```

## Script Standards

- Use `[CmdletBinding(SupportsShouldProcess=$true)]` for scripts that make changes.
- Prefer explicit parameters over hard-coded tenant, server, or path values.
- Write structured CSV, JSON, or log output for auditability.
- Keep secrets in environment variables, Key Vault, or GitHub Actions secrets.
- Document required modules and Graph/API permissions in comment-based help.
