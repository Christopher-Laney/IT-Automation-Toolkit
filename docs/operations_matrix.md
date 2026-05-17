# Operations Matrix

This matrix summarizes the main workflows, what starts them, what they consume, what they produce, and the safest first command to run.

| Workflow | Category | Trigger | Inputs | Outputs | Evidence | Safe First Run |
|---|---|---|---|---|---|---|
| Identity workflow demo | Identity | Portfolio demo | Sanitized ServiceNow ticket and matching approval sample | Converted onboarding CSV and identity change packet | SHA256-fingerprinted packet JSON | `.\scripts\identity\invoke_identity_workflow_demo.ps1 -OutputDirectory .\reports\identity-demo` |
| Onboarding batch | Identity | Approved joiner request | User CSV, approval record, optional password handoff key | Users, license assignments, group membership, run report | Run report, rollback artifact, change packet | `.\scripts\identity\onboarding.ps1 -UserList .\config\new_users.csv -ApprovalRecordPath .\config\approval_record.sample.json -ValidateOnly` |
| Offboarding plan | Identity | Approved leaver request | User principal name or Jira-derived plan plus approval record | Disabled access, revoked sessions, removed groups/licenses | Logs, converted plan, change packet | `.\scripts\identity\offboarding.ps1 -UserPrincipalName jane.doe@contoso.com -ApprovalRecordPath .\config\approval_record.sample.json -ValidateOnly` |
| Baseline reporting | Reporting | Daily or weekly schedule | Tenant/report access or sanitized sample data | CSV reports and HTML dashboard | Generated reports, dashboard artifact, screenshot manifest for sample refreshes | `.\scripts\automation\invoke_it_baseline_checks.ps1 -UseSampleData -DashboardOutputPath .\reports\sample_it_audit_dashboard.html` |
| Intune policy deployment | Compliance | Approved policy rollout | Validated Intune JSON template | Graph policy payload/application | Template source and validation output | `.\scripts\compliance\apply_intune_policy.ps1 -Path .\config\intune_policy_template.json -ValidateOnly` |
| Backup and restore | Automation | Daily protection or recovery event | Source path, destination, retention, optional encryption key | ZIP or encrypted backup plus manifest | SHA256 manifest and restore validation | `.\scripts\automation\backup_automation.ps1 -SourcePath .\samples -DestinationPath .\reports\backup-demo -WhatIf` |

Use this page with `docs/scheduling.md` when deciding which workflows should remain operator-driven and which are safe to schedule.
