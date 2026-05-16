# Scheduling Guide

This guide shows safe starting points for running toolkit workflows on a schedule. Keep secrets in the scheduler, automation account, or GitHub repository secrets. Do not commit live tenant IDs, webhook URLs, storage connection strings, or access tokens.

## Recommended Schedule Pattern

| Workflow | Suggested Frequency | Safe First Command |
|---|---:|---|
| Onboarding CSV validation | Before each onboarding batch | `.\scripts\identity\onboarding.ps1 -UserList .\config\new_users.csv -ApprovalRecordPath .\config\approval_record.sample.json -ValidateOnly` |
| Intune template validation | Before policy deployment | `.\scripts\compliance\apply_intune_policy.ps1 -Path .\config\intune_policy_template.json -ValidateOnly` |
| Baseline reporting | Daily or weekly | `.\scripts\automation\invoke_it_baseline_checks.ps1 -RunCompliance` |
| Server operations checks | Daily | `.\scripts\automation\invoke_it_baseline_checks.ps1 -RunOps` |
| Local backup preview | Before backup rollout | `.\scripts\automation\backup_automation.ps1 -SourcePath D:\Data -DestinationPath E:\Backups -WhatIf` |
| Local backup | Daily | `.\scripts\automation\backup_automation.ps1 -SourcePath D:\Data -DestinationPath E:\Backups -RetentionDays 30` |

## Windows Task Scheduler

Use `samples/schedules/register_task_scheduler_baseline.ps1` as a local starting point. It registers a daily PowerShell task that runs the baseline check orchestrator from the repository root.

Preview the command first:

```powershell
.\samples\schedules\register_task_scheduler_baseline.ps1 `
  -RepositoryRoot "C:\Repos\IT-Automation-Toolkit" `
  -TaskName "IT Automation Toolkit Baseline" `
  -At "06:00" `
  -WhatIf
```

Register it after review:

```powershell
.\samples\schedules\register_task_scheduler_baseline.ps1 `
  -RepositoryRoot "C:\Repos\IT-Automation-Toolkit" `
  -TaskName "IT Automation Toolkit Baseline" `
  -At "06:00"
```

## Azure Automation

Use `samples/schedules/azure_automation_baseline_runbook.ps1` as a runbook starter. Import it into an Automation Account, then add schedules and variables in Azure.

Recommended Automation Account variables:

- `RepositoryRoot`: path where the toolkit is available to the Hybrid Runbook Worker.
- `RunCompliance`: `true` or `false`.
- `RunOps`: `true` or `false`.
- `TeamsWebhookUrl`: optional webhook URL stored as an encrypted variable.

Prefer a Hybrid Runbook Worker when scripts need local server access, file shares, or Windows-only modules.

## GitHub Actions

Use `samples/schedules/github-actions-scheduled-dashboard.yml` as a copyable workflow example. It is stored under `samples` so it will not run until copied into `.github/workflows`.

Before enabling a scheduled workflow:

- Confirm the script can run without production-only modules or local network access.
- Store webhook URLs, storage keys, and tenant-specific values in GitHub Secrets.
- Prefer sample-data or validation-only workflows for public repositories.
- Keep generated reports as short-lived workflow artifacts unless they are sanitized.

## Azure DevOps Pipelines

Use the samples under `samples/pipelines` when your organization runs CI or reporting jobs in Azure DevOps instead of GitHub Actions.

- `azure-devops-validation.yml` mirrors the repository validation workflow with Pester and PSScriptAnalyzer.
- `azure-devops-scheduled-dashboard.yml` generates the sanitized sample dashboard on a weekly schedule and publishes it as a pipeline artifact.

See [azure_devops_pipelines.md](azure_devops_pipelines.md) for setup notes, secret-handling guidance, and a suggested rollout sequence.

## Operational Notes

- Start every new schedule with validation or `-WhatIf`.
- Send reports and logs to ignored paths such as `reports` and `logs`.
- Review scheduler identities and Graph permissions separately from interactive admin accounts.
- Document each production schedule in your change-management system, including owner, frequency, secrets used, and rollback steps.
