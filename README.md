# 🧰 IT Automation Toolkit
<p align="center">
  <img src="docs/banner.png" alt="IT Automation Toolkit Banner" width="800">
</p>

![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)
![Platform: PowerShell](https://img.shields.io/badge/Platform-PowerShell-blue)
![Status: Active](https://img.shields.io/badge/Status-Active-success)

A collection of real-world PowerShell scripts, templates, and configurations designed to streamline IT operations and demonstrate practical automation in enterprise environments.

---

## 🚀 Overview

This toolkit highlights how IT managers can automate common administrative workflows, including user onboarding, offboarding, compliance reporting, and scheduled backups, while maintaining visibility through dashboards and audit logs.

The project emphasizes **automation, security, and scalability**, showing how a modern IT department can reduce manual effort and improve consistency.

---

## 🏗️ Features

- **Automated User Onboarding**  
  Creates new users in Azure AD and Okta, applies Intune device policies, and licenses Microsoft 365 accounts automatically.

- **Secure Offboarding Workflow**  
  Disables accounts, removes device access, and archives data to cloud storage with minimal manual steps.

- **Scheduled Backups**  
  Automates server or SharePoint data backups and verifies integrity via hash comparison.

- **Inventory Reporting**  
  Generates up-to-date CSV and Power BI dashboards with device, license, and compliance data.

---

## 🧩 Technologies Used

- **Scripting & Automation:** PowerShell, Python  
- **Cloud & Identity:** Azure AD, Intune, Okta, Microsoft 365  
- **Data & Visualization:** Power BI, Excel, Log Analytics  
- **Security & Compliance:** Conditional Access, MFA, Audit Logging

---

## 🗂️ Project Structure

```
/scripts      → PowerShell scripts for automation
/config       → JSON templates for Intune, Okta, and policies
/docs         → Documentation, architecture diagrams, changelog
/dashboards   → Sample Power BI dashboards
/logs         → Example output and logs
/reports      → Generated CSV/Excel reports (gitignored by default)
```

---

## 🧠 Architecture

![Architecture Diagram](docs/architecture_diagram.png)

**Workflow Summary**
1. Scripts are triggered via scheduled tasks or Azure Automation.
2. API calls manage users, devices, and policies across Azure, Intune, and Okta.
3. Logs and reports are generated for compliance tracking.
4. Power BI visualizes results for IT leadership and audits.

---

## 🧩 Example Commands

```powershell
# Run onboarding workflow
.\scripts\identity\onboarding.ps1 -UserList ".\config\new_users.csv" -ApprovalRecordPath ".\config\approval_record.sample.json" -ValidateOnly
.\scripts\identity\onboarding.ps1 -UserList ".\config\new_users.csv" -ApprovalRecordPath ".\config\approval_record.sample.json" -WhatIf

# Generate inventory report
.\scripts\reporting\inventory_report.ps1 -ExportPath ".\reports\inventory.csv"
```

---

## ⚡ Quickstart

For a no-tenant portfolio or stakeholder walkthrough, start with [docs/demo_guide.md](docs/demo_guide.md).
A generated sample transcript is available at [docs/demo_transcript.md](docs/demo_transcript.md), and you can refresh it with `.\scripts\reporting\generate_demo_transcript.ps1`.

See [docs/quickstart.md](docs/quickstart.md) for a safe local walkthrough, including syntax validation, onboarding preview mode, optional server checks, and report generation.

For backup and restore workflows, see [docs/backup_restore.md](docs/backup_restore.md).

For Intune policy validation and deployment, see [docs/intune_policy_templates.md](docs/intune_policy_templates.md).

For dashboard generation and Power BI source guidance, see [docs/dashboard_guidance.md](docs/dashboard_guidance.md).
The repository also includes sanitized sample CSVs under `samples/reports` for a no-tenant dashboard demo.
Power BI starter source notes, Power Query snippets, and DAX measures live under `dashboards/powerbi`.

For scheduled execution examples across Task Scheduler, Azure Automation, and GitHub Actions, see [docs/scheduling.md](docs/scheduling.md).
For Azure DevOps CI and scheduled reporting starters, see [docs/azure_devops_pipelines.md](docs/azure_devops_pipelines.md).
For Teams and Slack webhook usage examples, see [docs/notifications.md](docs/notifications.md).
For encrypted onboarding credential handoff guidance, see [docs/onboarding_password_handoff.md](docs/onboarding_password_handoff.md).
For onboarding audit and rollback artifacts, see [docs/identity_change_artifacts.md](docs/identity_change_artifacts.md).
For approval-gated onboarding and offboarding, see [docs/identity_approval_gates.md](docs/identity_approval_gates.md).
For exported ServiceNow and Jira ticket intake examples, see [docs/identity_ticket_intake.md](docs/identity_ticket_intake.md).

To exercise the master baseline runner without tenant credentials or server access, use:

```powershell
.\scripts\automation\invoke_it_baseline_checks.ps1 -UseSampleData -DashboardOutputPath .\reports\sample_it_audit_dashboard.html
```

---

## ✅ Validation

This repository includes a GitHub Actions workflow that checks PowerShell syntax, runs Pester parser tests, and runs PSScriptAnalyzer for error-level findings.

See [docs/testing.md](docs/testing.md) for local Pester setup, focused validation commands, and the no-dependency parser check.

You can run the quick parser check locally with:

```powershell
Get-ChildItem .\scripts,.\tests -Recurse -Filter *.ps1 | ForEach-Object {
  $tokens = $null
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors) | Out-Null
  $errors | ForEach-Object { "{0}:{1}: {2}" -f $_.Extent.File, $_.Extent.StartLineNumber, $_.Message }
}
```

---

## 🔐 Safety Notes

- Start with `-WhatIf` on scripts that change users, licenses, groups, policies, or files.
- Onboarding reports omit generated temporary passwords by default. Only enable password export for controlled demos or secure handoff workflows.
- Store secrets in environment variables, Azure Key Vault, or your enterprise vault. Do not commit live tokens, webhook URLs, or connection strings.
- Review permissions before running Graph, Intune, Exchange, Okta, or Azure automation in production tenants.
- Treat sample config files as templates and replace tenant-specific values before use.

---

## 🧱 Future Enhancements
- Bot-driven workflow status updates for real-time collaboration
- API-based license optimization tracking  

---

## 👤 Author

**Claney**  
IT Manager & Consultant | Cloud, Automation, and Infrastructure Design  
🔗 LinkedIn: https://www.linkedin.com/in/christopher-laney-b085a068 
🔗 Linktree: https://linktr.ee/gatica.unlimited

---

## 🪪 License
This project is released under the MIT License. You’re free to use and modify it for learning and demonstration purposes.
