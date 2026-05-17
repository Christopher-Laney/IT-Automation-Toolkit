# 0002: Gate High-Impact Identity Changes With Approval Records

- Status: Accepted
- Date: 2026-05-16

## Context

Identity changes such as license assignment, privileged group membership, and destructive offboarding actions carry more risk than ordinary reporting tasks.

## Decision

Require reviewable approval records before selected high-impact actions can proceed. Scripts validate the approval artifact before they connect to Microsoft Graph.

## Consequences

- risky actions declare intent before execution
- approval checks are testable without tenant access
- the workflow can prove both who approved the action and which actions were approved
- callers need to provide the correct approval record as part of normal operations
