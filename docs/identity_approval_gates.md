# Identity Approval Gates

`scripts/identity/onboarding.ps1` and `scripts/identity/offboarding.ps1` can require a reviewable JSON approval record before they perform high-impact identity changes.

Use the sample file at `config/approval_record.sample.json` as a starting point:

```json
{
  "ticketId": "CHG-1001",
  "approvedBy": "it-manager@contoso.com",
  "approvedUtc": "2030-01-10T18:30:00Z",
  "expiresUtc": "2030-01-11T18:30:00Z",
  "approvedActions": [
    "LicenseAssignment",
    "PrivilegedGroupMembership",
    "DestructiveOffboarding"
  ]
}
```

## Onboarding

Any batch with a non-empty `LicenseSku` value requires `LicenseAssignment`.

Pass `-PrivilegedGroupNames` to name groups that require the additional `PrivilegedGroupMembership` approval:

```powershell
.\scripts\identity\onboarding.ps1 `
  -UserList .\config\new_users.csv `
  -PrivilegedGroupNames 'Privileged-Admins','Finance-Approvers' `
  -ApprovalRecordPath .\config\approval_record.json `
  -ValidateOnly
```

## Offboarding

Offboarding requires `DestructiveOffboarding` when the selected action plan includes sign-in blocking, password reset, session revocation, group removal, or license removal. The default offboarding plan includes destructive actions, so approval is required by default.

```powershell
.\scripts\identity\offboarding.ps1 `
  -UserPrincipalName jane.doe@contoso.com `
  -TicketId CHG-1001 `
  -ApprovalRecordPath .\config\approval_record.json `
  -ValidateOnly
```

`-ValidateOnly` checks the approval artifact before any Microsoft Graph connection is attempted.
