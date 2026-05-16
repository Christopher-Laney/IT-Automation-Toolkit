# Power BI Dashboard Source Guide

This folder documents a safe starter model for a Power BI report built from the toolkit's CSV outputs.

Use the sanitized files in `samples/reports` while designing the report. Swap the source folder to `reports` only after the report shape is reviewed and no credentials or tenant-specific data will be committed.

## Source Tables

| Power BI Table | Sample CSV | Production CSV | Grain |
|---|---|---|---|
| InactiveUsers | `samples/reports/inactive_users.csv` | `reports/inactive_users.csv` | One user |
| LocalAdmins | `samples/reports/local_admins.csv` | `reports/local_admins.csv` | One local admin finding |
| IntuneCompliance | `samples/reports/intune_compliance.csv` | `reports/intune_compliance.csv` | One device |
| M365LicenseAudit | `samples/reports/m365_license_audit.csv` | `reports/m365_license_audit.csv` | One license SKU |
| SslExpiry | `samples/reports/ssl_expiry.csv` | `reports/ssl_expiry.csv` | One certificate endpoint |
| SystemHealth | `samples/reports/system_health.csv` | `reports/system_health.csv` | One server |

## Recommended Pages

1. **Executive Overview**
   - KPI cards: inactive users, noncompliant devices, local admin findings, licenses available, SSL certs expiring, unhealthy systems.
   - Small table for top action items sorted by severity or days remaining.

2. **Identity Risk**
   - Inactive users by department.
   - Local admin findings by device and account.
   - Drill-through table with owner, last logon, and recommended action.

3. **Device And Compliance**
   - Intune compliance by platform.
   - Noncompliant device list with owner and reason.
   - System health by server and service state.

4. **License And Certificate Operations**
   - License usage by SKU.
   - Available license count and utilization percentage.
   - SSL certificate expiry timeline.

## Build Steps

1. Copy `power_query_sample.m` into a blank query named `ToolkitTables`, then create reference queries from each record field such as `ToolkitTables[InactiveUsers]`.
2. Set `SourceRoot` to the repository root or to a parameter named `ToolkitRoot`.
3. Load all six source tables.
4. Add the measures from `measures.dax`.
5. Import `theme.json`.
6. Build visuals from the recommended pages above.
7. Use `template_build_spec.json` as the lightweight source-of-truth checklist for the template shape.
8. Follow `docs/powerbi_template_build.md` when exporting a sanitized `.pbit` template.

## Commit Safety

- Prefer committing `.pbit` templates, screenshots, and docs over `.pbix` files.
- Remove credentials, gateways, tenant IDs, production paths, and cached data before committing.
- Keep production report exports in `reports` or another ignored path.
- Refresh screenshots only from sanitized sample data.
- For the HTML dashboard screenshot workflow, follow `docs/dashboard_guidance.md` and regenerate `dashboards/sample_output_screenshot.manifest.json` after every refresh.
