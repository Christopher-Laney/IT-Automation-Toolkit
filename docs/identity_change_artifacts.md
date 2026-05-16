# Identity Change Artifacts

Use `scripts/identity/export_identity_change_artifact.ps1` to turn an onboarding run report into a JSON ledger for review and rollback planning.

## Why This Exists

Onboarding can create users, add licenses, and add group memberships in a single run.
The CSV report is useful for humans, but a structured artifact is easier to archive, compare, and use during follow-up review.

## Build An Artifact

```powershell
.\scripts\identity\onboarding.ps1 `
  -UserList .\config\new_users.csv `
  -ApprovalRecordPath .\config\approval_record.sample.json `
  -ReportPath .\logs\onboarding_run.csv

.\scripts\identity\export_identity_change_artifact.ps1 `
  -ReportPath .\logs\onboarding_run.csv `
  -OutputPath .\logs\onboarding_change_artifact.json
```

The artifact records:

- users created during the run
- license SKU IDs added
- group memberships added
- suggested rollback commands for operator review

## Important Notes

- Treat rollback commands as reviewable guidance, not as an unattended undo script.
- Group rollback commands intentionally keep `GroupId` and `DirectoryObjectId` placeholders because the onboarding report stores display names and user principal names, not immutable IDs.
- Keep artifacts with your ticket or change record when you need audit evidence for a batch onboarding run.
- Continue to use `-WhatIf` before making live changes.
