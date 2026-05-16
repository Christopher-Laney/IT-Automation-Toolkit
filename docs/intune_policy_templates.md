# Intune Policy Templates

This project includes Intune compliance policy templates for use with `scripts/compliance/apply_intune_policy.ps1`.

## Validate Before Deployment

Always validate the template before connecting to Microsoft Graph or changing policies:

```powershell
.\scripts\compliance\apply_intune_policy.ps1 `
  -Path .\config\intune_policy_template.json `
  -ValidateOnly
```

Validation checks:

- Required top-level fields: `policyName`, `description`, `platforms`, `complianceSettings`, and `remediationActions`.
- Supported platforms: `Windows10`, `Windows11`, `macOS`, `iOS`, and `Android`.
- Required compliance settings used by the deployment payload.
- Required remediation actions `1` and `2`, including `gracePeriodHours`.

## Editor Schema Support

The canonical template includes a `$schema` reference to `config/intune_policy_template.schema.json`. Editors such as VS Code can use this schema for autocomplete, platform enum validation, and early warnings while you customize policy settings.

If you copy the template to another folder, either keep the schema reference pointed at the repo copy or update `$schema` to a reachable path.

## Deploy With Preview

Use `-WhatIf` after validation to preview policy creation or updates:

```powershell
.\scripts\compliance\apply_intune_policy.ps1 `
  -Path .\config\intune_policy_template.json `
  -WhatIf
```

Use `-PreviewPayload` when you want to inspect the generated per-platform Graph bodies without connecting to Graph:

```powershell
.\scripts\compliance\apply_intune_policy.ps1 `
  -Path .\config\intune_policy_examples\ios_compliance_policy.json `
  -PreviewPayload
```

## Deploy

Connect with the required Microsoft Graph permissions, then run without `-WhatIf`:

```powershell
Connect-MgGraph -Scopes `
  "DeviceManagementConfiguration.ReadWrite.All",`
  "DeviceManagementManagedDevices.Read.All",`
  "Directory.Read.All"

.\scripts\compliance\apply_intune_policy.ps1 `
  -Path .\config\intune_policy_template.json
```

Required permissions:

- `DeviceManagementConfiguration.ReadWrite.All`: create or update compliance policies.
- `DeviceManagementManagedDevices.Read.All`: inspect managed device context used by Intune policy workflows.
- `Directory.Read.All`: resolve directory and group context for policy targeting.

## Template Locations

- `config/intune_policy_template.json`: canonical repo-root template used by quickstart examples.
- `scripts/compliance/intune_policy_template.json`: same schema colocated with compliance scripts for script-folder workflows.
- `config/intune_policy_examples/*.json`: platform-focused examples for safer customization.

Keep both files aligned if you intentionally maintain both examples.

## Platform Examples

Use the example templates as starting points when you want to tune one device family at a time:

| Example | Platforms | Focus |
|---|---|---|
| `config/intune_policy_examples/windows_compliance_policy.json` | `Windows10`, `Windows11` | BitLocker, firewall, Defender, Secure Boot, code integrity, password controls |
| `config/intune_policy_examples/macos_compliance_policy.json` | `macOS` | Password controls, firewall, Gatekeeper, system integrity protection |
| `config/intune_policy_examples/ios_compliance_policy.json` | `iOS` | Passcode strength, minimum OS version, jailbreak detection |
| `config/intune_policy_examples/android_compliance_policy.json` | `Android` | Passcode strength, storage encryption, minimum OS version, jailbreak/root detection |

Validate any example before deployment:

```powershell
.\scripts\compliance\apply_intune_policy.ps1 `
  -Path .\config\intune_policy_examples\windows_compliance_policy.json `
  -ValidateOnly
```

## Supported Fields

Required `complianceSettings` fields:

- `requireBitLocker`
- `firewallEnabled`
- `passwordRequired`
- `passwordMinimumLength`
- `passwordExpirationDays`
- `passwordPreviousPasswordBlockCount`
- `osMinimumVersion`
- `jailbreakDetectionEnabled`
- `secureBootEnabled`
- `codeIntegrityEnabled`
- `deviceThreatProtectionRequiredSecurityLevel`
- `antivirusRequired`

Optional sections such as `scope`, `deviceHealthAttestation`, `conditionalAccessIntegration`, `reporting`, and `metadata` are useful for documentation and future workflow expansion, but are not all mapped into the current Graph payload.

The deployment script now maps platform-specific settings into each generated payload:

- Windows: encryption, firewall, Secure Boot, code integrity, minimum and maximum OS version, and threat-protection level.
- macOS: password history and expiry, minimum and maximum OS version, storage encryption, firewall, system integrity protection, and threat-protection level.
- iOS: passcode history and expiry, minimum and maximum OS version, jailbreak blocking, and threat-protection level.
- Android: password history and expiry, minimum and maximum OS version, encryption, rooted-device blocking, and threat-protection level.

The JSON Schema intentionally allows additional compliance settings so new Intune payload fields can be documented before the deployment script maps them.
