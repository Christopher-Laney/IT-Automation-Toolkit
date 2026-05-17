# 0001: Use File-Based Workflow Contracts

- Status: Accepted
- Date: 2026-05-16

## Context

The toolkit needs to demonstrate automation flows that are useful in real environments while remaining safe to run without tenant credentials during reviews and demos.

## Decision

Use CSV and JSON artifacts as the primary handoff format between workflow stages:

- ticket exports become onboarding CSVs or offboarding plans
- approval records remain explicit JSON files
- reports, rollback ledgers, manifests, and review packets are emitted as files

## Consequences

- workflows stay inspectable, portable, and easy to test offline
- demos can run without live ServiceNow, Jira, Graph, or Power BI dependencies
- future live connectors can feed the same contracts instead of replacing them
- operators must manage artifact retention and storage intentionally
