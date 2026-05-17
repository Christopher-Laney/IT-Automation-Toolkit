# 0003: Prefer Sanitized Sample Data For Demo Workflows

- Status: Accepted
- Date: 2026-05-16

## Context

The repository is both an automation toolkit and a portfolio project. Reviewers should be able to evaluate its workflows without production credentials or tenant data.

## Decision

Provide sanitized sample data, copyable pipeline examples, generated demo transcripts, and safe no-tenant workflows alongside the live automation scripts.

## Consequences

- reviewers can exercise meaningful flows quickly and safely
- documentation stays closer to executable reality
- screenshots and Power BI source guidance can be refreshed from known-safe inputs
- sample artifacts must remain clearly separated from production outputs
