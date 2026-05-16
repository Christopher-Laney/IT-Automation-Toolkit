# Notifications Guide

The toolkit includes `scripts/notifications/teams_webhook_alert.ps1` as a reusable Teams webhook sender for backups, health checks, and baseline summaries.

## Teams Card Formats

| Format | Best For |
|---|---|
| `MessageCard` | Broad compatibility with simple webhook integrations and older flows. |
| `AdaptiveCard` | Higher-signal operational alerts where title, severity, and timestamps should scan cleanly in Teams. |

`MessageCard` remains the default so existing callers keep the same payload shape.
Use `AdaptiveCard` when you want a more modern alert presentation.

## Examples

Preview the default payload without posting:

```powershell
.\scripts\notifications\teams_webhook_alert.ps1 `
  -WebhookUrl "https://example.invalid/webhook" `
  -Title "Backup Warning" `
  -Message "Backup completed with warnings." `
  -Severity Warning `
  -WhatIf `
  -PassThru
```

Send an adaptive card:

```powershell
.\scripts\notifications\teams_webhook_alert.ps1 `
  -WebhookUrl $env:TEAMS_WEBHOOK_URL `
  -Title "IT Baseline Checks Completed" `
  -Message "Compliance and operations checks completed." `
  -Severity Info `
  -CardFormat AdaptiveCard
```

`scripts/automation/invoke_it_baseline_checks.ps1` uses the adaptive-card format for its Teams summary alerts.

## Routing

Use `config/notification_routes.sample.json` as a starter route map when different Teams channels should receive different alerts.
Routes reference environment-variable names rather than storing live webhook URLs in source control.

The sender resolves routes in this order:

1. exact `category + severity`
2. category default
3. severity default
4. global default

Example route-driven send:

```powershell
.\scripts\notifications\teams_webhook_alert.ps1 `
  -RoutingConfigPath .\config\notification_routes.json `
  -Category Compliance `
  -Title "Intune Compliance Drift" `
  -Message "Three devices need review." `
  -Severity Critical `
  -CardFormat AdaptiveCard
```

Copy the sample config to an ignored local file or secret-managed deployment location, then populate the referenced environment variables in your scheduler, pipeline, or automation account.

## Operational Guidance

- Keep webhook URLs in environment variables, secret stores, or scheduler-managed secrets.
- Use `Info` for successful runs, `Warning` when operator review is useful, and `Critical` when immediate action is expected.
- Use routing when operational ownership differs by script category or when critical alerts need a separate escalation channel.
- Start with `-WhatIf -PassThru` when wiring a new alert into an automation path.
- Prefer concise alert titles and put supporting detail in the message body or linked report output.
