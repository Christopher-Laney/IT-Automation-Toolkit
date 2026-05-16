# Azure DevOps Pipeline Examples

This repository includes copyable Azure DevOps YAML starters under `samples/pipelines`.
They are samples rather than live pipelines so they will not run until you import or copy them into your own Azure DevOps project.

## Included Samples

| Sample | Purpose |
|---|---|
| `azure-devops-validation.yml` | Run Pester and PSScriptAnalyzer for pushes and pull requests targeting `main`. |
| `azure-devops-scheduled-dashboard.yml` | Generate the sanitized sample HTML dashboard weekly and publish it as a pipeline artifact. |

## Validation Pipeline

Use `samples/pipelines/azure-devops-validation.yml` when you want Azure DevOps to mirror this repository's GitHub Actions quality gate.

The sample:

- runs on `windows-latest`
- installs Pester and PSScriptAnalyzer from PSGallery
- executes `Invoke-Pester -Path ./tests -CI`
- executes `Invoke-ScriptAnalyzer -Path ./scripts -Recurse -Settings ./PSScriptAnalyzerSettings.psd1 -Severity Error`

Start here for forks that are hosted primarily in Azure DevOps or for organizations that require Azure DevOps build evidence before deployment.

## Scheduled Dashboard Pipeline

Use `samples/pipelines/azure-devops-scheduled-dashboard.yml` for a safe reporting demo.
It intentionally uses `config/dashboard_reports.sample.json`, so the generated artifact is based on sanitized CSV files under `samples/reports`.

The sample:

- disables normal push and pull-request triggers
- runs on a weekly Monday schedule
- generates `reports/sample_it_audit_dashboard.html`
- publishes the dashboard as the `sample-it-audit-dashboard` pipeline artifact

For production reporting, copy the sample and replace the sample-data inputs only after you have confirmed permissions, data handling, and retention requirements.

## Secrets And Service Connections

- Store tenant IDs, webhook URLs, storage keys, and API tokens in Azure DevOps variable groups, secret variables, or Azure Key Vault integrations.
- Use service connections or managed identities for Azure access instead of embedding credentials in YAML.
- Keep public demo pipelines on sanitized inputs and publish only artifacts that are safe to share.
- Review artifact retention before publishing reports that may contain operational or identity data.

## Suggested Rollout

1. Import the validation pipeline first and make it required for `main`.
2. Run the scheduled dashboard sample unchanged and inspect the artifact.
3. Move production-only inputs into secret variables or service connections.
4. Add approvals or environment checks before introducing scripts that modify identities, licenses, policies, or backups.
