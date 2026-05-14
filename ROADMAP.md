# Roadmap

## Reliability

- Add PSScriptAnalyzer settings once project-specific style rules settle.
- Add tests for Azure upload mocks and webhook notification handling.
- Add sample data for baseline checks.
- Add restore drills that compare generated backup manifests against restored file inventories.

## Identity Automation

- Add ServiceNow or Jira ticket intake for onboarding and offboarding.
- Add approval gates for license assignment, privileged groups, and destructive offboarding actions.
- Add rollback/export artifacts for group and license changes.
- Add secure temporary-password handoff options, such as encrypted export or vault-backed storage.

## Compliance And Reporting

- Add a sanitized Power BI `.pbit` template based on the sample CSV model.
- Add report normalization so dashboard generation can consume consistent CSV schemas.
- Add scheduled run examples for Task Scheduler, Azure Automation, and GitHub Actions.
- Add platform-specific Intune payload mappings for additional compliance settings.
- Add generated screenshot refresh guidance for dashboard sample data.

## Notifications

- Add Teams adaptive-card formatting for high-signal operational alerts.
- Add notification routing by severity and script category.
- Add optional Slack webhook payload support.
