# Identity Change Packets

`scripts/identity/export_identity_change_packet.ps1` creates a compact audit packet that ties together:

- the original ticket export
- the approval record
- generated workflow artifacts such as converted CSVs, run reports, rollback ledgers, or offboarding plans

Each referenced file is fingerprinted with SHA256 so reviewers can later confirm which exact inputs supported the change.

## Onboarding Example

```powershell
.\scripts\identity\convert_identity_ticket.ps1 `
  -Provider ServiceNow `
  -Path .\config\servicenow_onboarding_ticket.sample.json `
  -OutputPath .\logs\onboarding_from_ticket.csv

.\scripts\identity\export_identity_change_packet.ps1 `
  -WorkflowType Onboarding `
  -TicketPath .\config\servicenow_onboarding_ticket.sample.json `
  -ApprovalRecordPath .\config\approval_record.sample.json `
  -RelatedArtifactPaths .\logs\onboarding_from_ticket.csv `
  -OutputPath .\logs\identity_change_packet.json
```

The exporter rejects packets when the ticket identifier and approval-record `ticketId` do not match.

## Suggested Packet Contents

For a live onboarding change, include:

- converted onboarding CSV
- onboarding run report
- rollback-oriented identity change artifact
- encrypted password handoff artifact when used

For a live offboarding change, include:

- converted offboarding plan
- final operator notes or exported log files
- approval record

Keep the packet with the originating change record when you need a single reviewable bundle of the workflow inputs and generated evidence.
