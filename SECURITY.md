# Security Policy

## Supported Use

This toolkit is designed for IT automation labs, demos, and carefully reviewed enterprise workflows. Always test scripts with sample data and `-WhatIf` before running them against production users, devices, groups, storage, or policies.

## Secrets

Do not commit real API tokens, webhook URLs, client secrets, storage connection strings, passwords, tenant IDs that should remain private, or exported production logs.

Recommended secret locations:

- Environment variables for local runs.
- Azure Key Vault or an enterprise vault for shared automation.
- GitHub Actions secrets for CI/CD workflows.

## Reporting Security Issues

If you find a security issue, open a private advisory when available or contact the repository owner directly before opening a public issue.

Include:

- A short description of the risk.
- The affected script or config file.
- Steps to reproduce using sample data.
- Suggested mitigation, if known.

## Production Checklist

- Run with `-WhatIf` first.
- Confirm least-privilege permissions for Graph, Intune, Exchange, Azure, and Okta.
- Review all exported reports for sensitive data before sharing.
- Rotate any secret that may have been exposed in terminal output, logs, reports, or commits.
