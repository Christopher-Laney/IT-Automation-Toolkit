# Identity Workflow Demo

Run a safe end-to-end identity demo without connecting to Microsoft Graph:

```powershell
.\scripts\identity\invoke_identity_workflow_demo.ps1 `
  -OutputDirectory .\reports\identity-demo
```

The demo uses sanitized files already in the repository to show one coherent workflow:

1. convert a ServiceNow onboarding ticket export into an onboarding CSV
2. validate the approval-gated onboarding input without tenant access
3. export an identity change packet that binds the ticket, approval record, and generated CSV together

It uses `config/servicenow_onboarding_approval.sample.json`, whose `ticketId` matches the ServiceNow sample request so the evidence chain is internally consistent.

## Generated Artifacts

After the run, inspect:

- `reports/identity-demo/onboarding_from_ticket.csv`
- `reports/identity-demo/identity_change_packet.json`

This is a strong short demo for reviewers because it shows the repo's workflow design, safety controls, and audit trail without requiring live credentials.
