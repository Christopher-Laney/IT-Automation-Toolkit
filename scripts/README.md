# 🧰 IT Automation Scripts

This directory contains production-ready PowerShell scripts used for automation, auditing, reporting, compliance enforcement, backups, and IT operations management across **Azure AD / Entra ID**, **Microsoft 365**, **Intune**, **Okta**, and Windows environments.

Scripts are grouped logically so the toolkit is easy to navigate and adopt into real IT workflows.

Use these individually, or integrate them into scheduled tasks, pipelines, or automated workflows.


## 📄 Script Index and Suggested Run Cadence

| Category | Script | Purpose | Schedule |
|---|---|---|---|
| **Identity** | onboarding.ps1 | Create new users from CSV. | On-demand |
|  | offboarding.ps1 | Disable accounts & revoke sessions. | On-demand |
|  | inactive_user_report.ps1 | Find inactive accounts. | Weekly / Monthly |
|  | group_membership_audit.ps1 | Export group membership for audits. | Quarterly |
|  | okta_api_handler.ps1 | Reusable Okta API wrapper. | Dependency / On-demand |
|  | okta_api_config.json | API config template for Okta scripts. | Config template |
| **Compliance** | intune_device_compliance_audit.ps1 | Compliance, OS, stale device reporting. | Weekly / Monthly |
|  | intune_policy_template.json | Baseline compliance JSON. | Config template |
|  | conditional_access_baseline.json | Baseline CA policy JSON. | Config template |
|  | apply_intune_policy.ps1 | Apply Intune policy from template. | On-demand / Change mgmt |
|  | set_conditional_access_policy.ps1 | Deploy Conditional Access rules. | On-demand / Security rollout |
| **Reporting** | inventory_report.ps1 | Installed software export. | Monthly |
|  | m365_license_audit.ps1 | License usage + missing allocation. | Weekly / Monthly |
|  | ssl_certificate_expiry_report.ps1 | Cert age/status monitoring. | Weekly / Monthly |
|  | generate_it_audit_dashboard.ps1 | Build HTML dashboard of reports. | Weekly / Monthly |
|  | system_health_report.ps1 | CPU/RAM/Disk status snapshot. | Daily / Weekly |
|  | local_admin_audit.ps1 | List local admins (security). | Monthly / Audits |
| **Automation** | backup_automation.ps1 | Backup + hashing verification. | Daily |
|  | restart_failed_services.ps1 | Auto fix failed services. | Daily / Hourly for servers |
|  | azure_resource_tagging.ps1 | Enforce tag standards. | Monthly / On resource creation |
|  | log_cleanup.ps1 | Safe cleanup of logs/temp files. | Monthly |
|  | invoke_it_baseline_checks.ps1 | Master orchestration run. | Weekly / Daily |
| **Notifications** | teams_webhook_alert.ps1 | Reusable Teams alert sender. | Called by other scripts |


## 🔥 Usage Examples

```powershell
# Run a weekly security baseline
.\automation\invoke_it_baseline_checks.ps1 -RunCompliance -RunOps

# Generate dashboard after reports exist
.\reporting\generate_it_audit_dashboard.ps1

# Deploy baseline Conditional Access settings
.\compliance\set_conditional_access_policy.ps1 -Config ".\config\conditional_access_baseline.json"

# Audit Intune device compliance
.\compliance\intune_device_compliance_audit.ps1 -ExportPath ".\reports\intune.csv"


## 🏗 Integration Ideas

- Add these to a **server automation schedule** via Task Scheduler / Azure Automation / Runbooks  
- Build pipelines through **GitHub Actions** or **Azure DevOps**  
- Centralize notifications using **Teams Webhooks** (included)  
- Combine multiple scripts into **IT monthly compliance rollups**  
- Use onboarding/offboarding scripts to **standardize HR → IT workflows**
