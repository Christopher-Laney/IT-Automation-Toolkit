# Workflow Overview

This document describes the high-level flow across onboarding, offboarding, backups, and reporting.

1. **Onboarding**: Create user → assign license → add to groups → enroll device via Intune → verify MFA/CA.
2. **Offboarding**: Disable account → revoke sessions → archive data → remove device access → notify stakeholders.
3. **Backups**: Compress & store → verify hash → rotate retention.
4. **Reporting**: Export inventory → publish to Power BI or CSV for audits.

## Baseline Check Orchestration

`scripts/automation/invoke_it_baseline_checks.ps1` coordinates scripts across the `identity`, `compliance`, `reporting`, `automation`, and `notifications` folders.

- Compliance checks generate inactive-user, license, and Intune reports.
- Operational checks use `config/servers.txt` for server health and service checks.
- Dashboard generation runs after selected checks so the latest report files can be summarized.
- Teams notifications are optional, should use a webhook stored outside source control, and can use adaptive-card formatting for clearer operational summaries.
