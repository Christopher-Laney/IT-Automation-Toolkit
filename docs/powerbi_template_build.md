# Power BI Template Build

The repository includes a sanitized Power BI source pack under `dashboards/powerbi`:

- `power_query_sample.m`
- `measures.dax`
- `theme.json`
- `template_build_spec.json`

Use those files to build and export a data-free `.pbit` template from Power BI Desktop.

## Build Sequence

1. Open Power BI Desktop and start a blank report.
2. Create a text parameter named `ToolkitRoot` that points at the repository root.
3. Create a blank query named `ToolkitTables`, then paste in `dashboards/powerbi/power_query_sample.m`.
4. Create reference queries from each record field:
   - `InactiveUsers`
   - `LocalAdmins`
   - `IntuneCompliance`
   - `M365LicenseAudit`
   - `SslExpiry`
   - `SystemHealth`
5. Add the measures from `dashboards/powerbi/measures.dax`.
6. Import `dashboards/powerbi/theme.json`.
7. Build the four report pages listed in `template_build_spec.json`.
8. Save the working report locally, then export it as a Power BI template (`.pbit`).

## Sanitization Checklist

Before committing a template file:

- keep `ToolkitRoot` pointed at sanitized sample data
- verify the template opens without cached production rows
- remove credentials, gateway references, tenant IDs, and live file paths
- confirm every source table can refresh from `samples/reports`
- capture screenshots only from sanitized sample data

## Expected Outcome

The exported template should open with the report layout, measures, queries, and model structure intact while remaining free of embedded production data.
