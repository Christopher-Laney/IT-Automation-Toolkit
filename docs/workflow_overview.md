# Workflow Overview

This document describes the high-level flow across onboarding, offboarding, backups, and reporting.

1. **Onboarding**: Intake ticket → validate approval → create user → assign license → add to groups → export rollback artifacts.
2. **Offboarding**: Intake ticket → validate approval → disable account → revoke sessions → remove access → notify stakeholders.
3. **Backups**: Compress & store → verify hash → rotate retention.
4. **Reporting**: Export inventory → publish to Power BI or CSV for audits.

## Baseline Check Orchestration

`scripts/automation/invoke_it_baseline_checks.ps1` coordinates scripts across the `identity`, `compliance`, `reporting`, `automation`, and `notifications` folders.

- Compliance checks generate inactive-user, license, and Intune reports.
- Operational checks use `config/servers.txt` for server health and service checks.
- Dashboard generation runs after selected checks so the latest report files can be summarized.
- Teams and Slack notifications are optional, should use webhooks stored outside source control, and can use richer structured payloads for clearer operational summaries.
- Identity change packets can bind ticket exports, approval records, and generated artifacts into a single reviewable JSON evidence bundle.
