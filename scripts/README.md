# 🧰 IT Automation Scripts

This folder contains modular PowerShell scripts designed for IT operations, automation, reporting, and compliance enforcement across Azure AD / Entra ID, Microsoft 365, Intune, Okta, and Windows environments.

Use these individually, or integrate them into scheduled tasks, pipelines, or automated workflows.


## 📄 Script Index

| Script Name | Purpose | Suggested Schedule |
|------------|----------|-------------------|
| **onboarding.ps1** | Creates new users from CSV, prepares Graph payloads for account provisioning. | On-demand / HR request |
| **offboarding.ps1** | Disables account, revokes sessions, placeholder for mailbox/archive workflows. | On-demand / termination |
| **backup_automation.ps1** | Compresses backup source, timestamps archive, generates SHA-256 hash for integrity. | Daily / nightly job |
| **inventory_report.ps1** | Exports installed software inventory to CSV for asset tracking/security review. | Weekly or monthly |
| **conditional_access_baseline.json** | Baseline policy config reference for MFA/CA automation. | Reference / reusable |
| **intune_policy_template.json** | Example compliance policy definition for Intune enrollment baselines. | Reference / reusable |
| **okta_api_config.json** | Central config for Okta API automation (tokens, rate limits, org URL). | Reference / reusable |
| **okta_api_handler.ps1** | Generic Okta REST wrapper for user/group API automation. | On-demand / script dependency |
| **inactive_user_report.ps1** | Detect users inactive for X days in Azure AD or On-Prem AD. | Weekly or monthly review |
| **azure_resource_tagging.ps1** | Ensures required Azure tags exist, applies missing tags automatically. | Monthly or after resource creation |
| **system_health_report.ps1** | CPU/MEM/disk snapshot across servers/workstations. Exports CSV + optional HTML. | Daily or weekly |
| **restart_failed_services.ps1** | Detects and restarts failed automatic services with retry logic. | Daily or hourly for servers |
| **group_membership_audit.ps1** | Exports group memberships for least privilege/access review. | Quarterly or security audits |
| **m365_license_audit.ps1** | Lists license usage and missing assignments for required SKU baseline. | Weekly or monthly |
| **intune_device_compliance_audit.ps1** | Reports compliance, OS versions, stale devices, last check-in. | Weekly or monthly |
| **teams_webhook_alert.ps1** | Unified alert notifier for Teams, importable by other scripts. | Triggered by automation events |


## 🏗 Integration Ideas

- Add these to a **server automation schedule** via Task Scheduler / Azure Automation / Runbooks  
- Build pipelines through **GitHub Actions** or **Azure DevOps**  
- Centralize notifications using **Teams Webhooks** (included)  
- Combine multiple scripts into **IT monthly compliance rollups**  
- Use onboarding/offboarding scripts to **standardize HR → IT workflows**
