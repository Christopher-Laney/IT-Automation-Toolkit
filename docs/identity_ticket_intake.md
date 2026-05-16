# Identity Ticket Intake

`scripts/identity/convert_identity_ticket.ps1` converts exported ticket JSON into inputs that already fit the identity workflow:

- ServiceNow onboarding exports become CSV files for `onboarding.ps1`
- Jira offboarding exports become reviewed JSON plans for `offboarding.ps1`

This keeps the workflow useful without requiring live ticket-system credentials in the repository. API connectors can later feed the same contract.

## ServiceNow Onboarding

Use `config/servicenow_onboarding_ticket.sample.json` as the starter shape:

```powershell
.\scripts\identity\convert_identity_ticket.ps1 `
  -Provider ServiceNow `
  -Path .\config\servicenow_onboarding_ticket.sample.json `
  -OutputPath .\logs\onboarding_from_ticket.csv

.\scripts\identity\onboarding.ps1 `
  -UserList .\logs\onboarding_from_ticket.csv `
  -ApprovalRecordPath .\config\approval_record.sample.json `
  -ValidateOnly
```

The onboarding export must include a request item number, `Onboarding` request type, requested user name and email, and usage location. Optional fields map into the existing onboarding CSV columns.

## Jira Offboarding

Use `config/jira_offboarding_ticket.sample.json` as the starter shape:

```powershell
.\scripts\identity\convert_identity_ticket.ps1 `
  -Provider Jira `
  -Path .\config\jira_offboarding_ticket.sample.json `
  -OutputPath .\logs\offboarding_plan.json
```

The generated plan is intentionally reviewable JSON. After review, use its values to build the offboarding command and pair it with the approval record:

```powershell
$plan = Get-Content -Raw .\logs\offboarding_plan.json | ConvertFrom-Json

.\scripts\identity\offboarding.ps1 `
  -UserPrincipalName $plan.userPrincipalName `
  -TicketId $plan.ticketId `
  -ApprovalRecordPath .\config\approval_record.sample.json `
  -BlockSignIn:$plan.blockSignIn `
  -ResetPassword:$plan.resetPassword `
  -RevokeSessions:$plan.revokeSessions `
  -RemoveFromGroups:$plan.removeFromGroups `
  -RemoveLicenses:$plan.removeLicenses `
  -ValidateOnly
```

The Jira export requires an issue key, `Offboarding` request type, and user principal name.
