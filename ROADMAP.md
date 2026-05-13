# Roadmap

## Reliability

- Expand Pester coverage beyond syntax checks into parameter and dry-run behavior.
- Add PSScriptAnalyzer settings once project-specific style rules settle.
- Add sample data for reports, dashboards, and baseline checks.
- Add tests for backup retention, exclusion matching, manifest validation, and restore behavior.

## Identity Automation

- Add ServiceNow or Jira ticket intake for onboarding and offboarding.
- Add approval gates for license assignment, privileged groups, and destructive offboarding actions.
- Add rollback/export artifacts for group and license changes.
- Add secure temporary-password handoff options, such as encrypted export or vault-backed storage.

## Compliance And Reporting

- Add Power BI template documentation and sample dashboard source guidance.
- Add report normalization so dashboard generation can consume consistent CSV schemas.
- Add scheduled run examples for Task Scheduler, Azure Automation, and GitHub Actions.
- Expand Intune template validation into Pester tests and optional JSON schema checks.
- Add generated screenshot refresh guidance for dashboard sample data.

## Notifications

- Add Teams adaptive-card formatting for high-signal operational alerts.
- Add notification routing by severity and script category.
- Add optional Slack webhook payload support.
