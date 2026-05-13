# Dashboard Guidance

The toolkit supports lightweight HTML dashboards through `scripts/reporting/generate_it_audit_dashboard.ps1`.

## Source Strategy

Generated CSV and HTML reports are ignored by git. Keep dashboard source guidance, sample screenshots, and report configuration in the repository, but avoid committing production exports.

Recommended tracked assets:

- `config/dashboard_reports.json`: dashboard report map.
- `docs/dashboard_guidance.md`: dashboard instructions and expected schemas.
- `dashboards/sample_output_screenshot.png`: representative screenshot.

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

## Power BI Guidance

If you add Power BI assets, prefer a sanitized `.pbit` template or documentation over a production `.pbix`.

Before committing Power BI files:

- Remove embedded credentials.
- Use sample or anonymized data.
- Document refresh steps and required CSV inputs.
- Add screenshots so users can preview the intended result without opening Power BI.
