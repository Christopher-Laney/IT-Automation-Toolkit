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

## Operational Guidance

- Keep webhook URLs in environment variables, secret stores, or scheduler-managed secrets.
- Use `Info` for successful runs, `Warning` when operator review is useful, and `Critical` when immediate action is expected.
- Start with `-WhatIf -PassThru` when wiring a new alert into an automation path.
- Prefer concise alert titles and put supporting detail in the message body or linked report output.
