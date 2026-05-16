# Dashboard Guidance

The toolkit supports lightweight HTML dashboards through `scripts/reporting/generate_it_audit_dashboard.ps1`.

## Source Strategy

Generated CSV and HTML reports are ignored by git. Keep dashboard source guidance, sample screenshots, and report configuration in the repository, but avoid committing production exports.

Recommended tracked assets:

- `config/dashboard_reports.json`: dashboard report map.
- `config/dashboard_reports.sample.json`: sample-data dashboard report map.
- `dashboards/powerbi`: Power BI source guidance, starter queries, and measures.
- `docs/dashboard_guidance.md`: dashboard instructions and expected schemas.
- `dashboards/sample_output_screenshot.png`: representative screenshot.
- `dashboards/sample_output_screenshot.manifest.json`: screenshot refresh manifest.
- `samples/reports/*.csv`: sanitized sample report data for demos.

Avoid committing:

- Production `.csv`, `.xlsx`, `.html`, or `.pbix` exports with tenant data.
- Reports containing user, device, license, or vulnerability details.
- Power BI files that embed credentials or production data.

## Generate The HTML Dashboard

Run reporting scripts first, then generate the dashboard:

```powershell
.\scripts\reporting\generate_it_audit_dashboard.ps1 `
  -ConfigPath .\config\dashboard_reports.json `
  -OutputPath .\reports\it_audit_dashboard.html
```

The dashboard includes:

- A report summary with row counts.
- A missing-report table for configured CSV files that do not exist yet.
- Up to `-MaxRows` rows per report section.

## Generate A Demo Dashboard

Use the included sanitized sample data to preview the dashboard without connecting to Microsoft 365, Intune, or Windows hosts:

```powershell
.\scripts\reporting\generate_it_audit_dashboard.ps1 `
  -ConfigPath .\config\dashboard_reports.sample.json `
  -OutputPath .\reports\sample_it_audit_dashboard.html
```

This uses CSV files in `samples/reports`. The sample data is intentionally fictional and safe to commit.

## Refresh The Sample Screenshot

Use only sanitized sample data when refreshing `dashboards/sample_output_screenshot.png`.

1. Generate the sample dashboard:

```powershell
.\scripts\reporting\generate_it_audit_dashboard.ps1 `
  -ConfigPath .\config\dashboard_reports.sample.json `
  -OutputPath .\reports\sample_it_audit_dashboard.html
```

2. Open `reports/sample_it_audit_dashboard.html` in a browser and capture a representative screenshot at a stable desktop viewport.
3. Replace `dashboards/sample_output_screenshot.png`.
4. Regenerate the screenshot manifest:

```powershell
.\scripts\reporting\update_dashboard_screenshot_manifest.ps1 `
  -ConfigPath .\config\dashboard_reports.sample.json `
  -ScreenshotPath .\dashboards\sample_output_screenshot.png `
  -OutputPath .\dashboards\sample_output_screenshot.manifest.json
```

Refresh the screenshot whenever `samples/reports/*.csv`, `config/dashboard_reports.sample.json`, or the dashboard layout changes. The manifest records the exact source hashes used for the last committed screenshot so reviewers can see whether the image and sample inputs were refreshed together.

## Configure Report Inputs

Edit `config/dashboard_reports.json` to add or remove report sections:

```json
{
  "reports": [
    {
      "title": "Inactive Users",
      "path": ".\\reports\\inactive_users.csv"
    }
  ]
}
```

Each item must include:

- `title`: section heading in the dashboard.
- `path`: CSV path to import.
- `columns`: expected CSV headers in the order they should appear in the dashboard.

When `columns` are configured, the dashboard generator validates that every required header is present, renders columns in the configured order, and omits extra source columns. This keeps live reports and sample reports visually consistent while still catching schema drift early.

## Expected CSV Inputs

The dashboard can render any CSV, but these are the expected report files for the current toolkit:

| Dashboard Section | Expected Path | Producing Script |
|---|---|---|
| Inactive Users | `.\reports\inactive_users.csv` | `scripts/identity/inactive_user_report.ps1` |
| Local Administrators | `.\reports\local_admins.csv` | `scripts/identity/local_admin_audit.ps1` |
| Intune Compliance | `.\reports\intune_compliance.csv` | `scripts/compliance/intune_device_compliance_audit.ps1` |
| M365 License Audit | `.\reports\m365_license_audit.csv` | `scripts/reporting/m365_license_audit.ps1` |
| SSL Certificate Status | `.\reports\ssl_expiry.csv` | `scripts/reporting/ssl_certificate_expiry_report.ps1` |
| System Health | `.\reports\system_health.csv` | `scripts/reporting/system_health_report.ps1` |

For demo data, use the matching files under `samples/reports`.

## Power BI Guidance

If you add Power BI assets, prefer a sanitized `.pbit` template or documentation over a production `.pbix`.

Use `dashboards/powerbi/README.md` as the starter source guide. It maps toolkit CSV outputs to Power BI tables, recommends report pages, and includes starter Power Query and DAX files.
For the repeatable `.pbit` build sequence, use [powerbi_template_build.md](powerbi_template_build.md).

Before committing Power BI files:

- Remove embedded credentials.
- Use sample or anonymized data.
- Document refresh steps and required CSV inputs.
- Add screenshots so users can preview the intended result without opening Power BI.
