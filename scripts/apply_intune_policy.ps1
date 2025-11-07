<#
.SYNOPSIS
  Create/update Intune compliance policies per platform from JSON.

.DESCRIPTION
  Reads ./config/intune_policy_template.json and applies platform-specific
  compliance policies via Microsoft Graph Device Management endpoints.
  Idempotent: updates existing policy by name (per platform); creates if missing.

.REQUIREMENTS
  Install-Module Microsoft.Graph -Scope CurrentUser
  Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All","DeviceManagementManagedDevices.Read.All","Directory.Read.All"

.PARAMETER Path
  Path to the JSON file. Defaults to ./config/intune_policy_template.json

.PARAMETER WhatIf
  Show what would happen without making changes.

.EXAMPLE
  .\apply_intune_policy.ps1
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [string]$Path = ".\config\intune_policy_template.json"
)

function Ensure-Graph {
  if (-not (Get-Module Microsoft.Graph -ListAvailable)) {
    Install-Module Microsoft.Graph -Scope CurrentUser -Force
  }
  if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All","DeviceManagementManagedDevices.Read.All","Directory.Read.All"
  }
  Select-MgProfile -Name "beta" | Out-Null # Many Intune endpoints are more complete in beta. Switch to v1.0 if needed.
}

function Get-CompliancePolicyByName {
  param([string]$Name)
  $uri = "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies`?$filter=displayName eq '$($Name.Replace("'","''"))'"
  (Invoke-MgGraphRequest -Method GET -Uri $uri).value
}

function NewOrUpdate-CompliancePolicy {
  param(
    [hashtable]$Template,
    [string]$Platform,  # Windows10|Windows11|macOS|iOS|Android
    [hashtable]$Existing
  )

  $baseName = $Template.policyName
  $name = "$baseName - $Platform"

  # Map platform → @odata.type and settings
  switch -Regex ($Platform) {
    'Windows(10|11)' {
      $odata = "#microsoft.graph.windows10CompliancePolicy"
      $settings = @{
        passwordRequired                                  = $Template.complianceSettings.passwordRequired
        passwordMinimumLength                             = $Template.complianceSettings.passwordMinimumLength
        passwordExpirationDays                            = $Template.complianceSettings.passwordExpirationDays
        passwordPreviousPasswordBlockCount                = $Template.complianceSettings.passwordPreviousPasswordBlockCount
        requireBitLocker                                  = $Template.complianceSettings.requireBitLocker
        firewallEnabled                                   = $Template.complianceSettings.firewallEnabled
        osMinimumVersion                                  = $Template.complianceSettings.osMinimumVersion
        osMaximumVersion                                  = $Template.complianceSettings.osMaximumVersion
        deviceThreatProtectionRequiredSecurityLevel       = $Template.complianceSettings.deviceThreatProtectionRequiredSecurityLevel
        defenderEnabled                                   = $Template.complianceSettings.antivirusRequired
        windowsFirewallEnabled                            = $Template.complianceSettings.firewallEnabled
        bitLockerEnabled                                  = $Template.complianceSettings.requireBitLocker
        codeIntegrityEnabled                              = $Template.complianceSettings.codeIntegrityEnabled
        secureBootEnabled                                 = $Template.complianceSettings.secureBootEnabled
        deviceCompliancePolicyScriptResults               = @() # placeholder
      }
    }
    'macOS' {
      $odata = "#microsoft.graph.macOSCompliancePolicy"
      $settings = @{
        passwordRequired                    = $Template.complianceSettings.passwordRequired
        passwordMinimumLength               = $Template.complianceSettings.passwordMinimumLength
        osMinimumVersion                    = "12.0" # adjust if needed
        systemIntegrityProtectionEnabled    = $true
        gatekeeperEnabled                   = $true
        firewallEnabled                     = $Template.complianceSettings.firewallEnabled
      }
    }
    'iOS' {
      $odata = "#microsoft.graph.iosCompliancePolicy"
      $settings = @{
        passcodeRequired     = $Template.complianceSettings.passwordRequired
        passcodeMinimumLength= $Template.complianceSettings.passwordMinimumLength
        osMinimumVersion     = "15.0"
        securityBlockJailbrokenDevices = $Template.complianceSettings.jailbreakDetectionEnabled
      }
    }
    'Android' {
      $odata = "#microsoft.graph.androidCompliancePolicy"
      $settings = @{
        passwordRequired     = $Template.complianceSettings.passwordRequired
        passwordMinimumLength= $Template.complianceSettings.passwordMinimumLength
        osMinimumVersion     = "11.0"
        securityBlockJailbrokenDevices = $Template.complianceSettings.jailbreakDetectionEnabled
        storageRequireEncryption = $Template.complianceSettings.requireBitLocker
      }
    }
    default { throw "Unsupported platform: $Platform" }
  }

  $body = @{
    "@odata.type"  = $odata
    displayName    = $name
    description    = $Template.description
    # Non-compliance settings
    roleScopeTagIds = @()  # adjust if you use scope tags
    scheduledActionsForRule = @(
      @{
        ruleName = "PasswordRequired"
        scheduledActionConfigurations = @(
          @{
            actionType = "notification"
            gracePeriodHours = [int]($Template.remediationActions.'1'.gracePeriodHours)
            notificationTemplateId = $null
            notificationMessageCCList = @()
          },
          @{
            actionType = "block"
            gracePeriodHours = [int]($Template.remediationActions.'2'.gracePeriodHours)
            notificationTemplateId = $null
            notificationMessageCCList = @()
          }
        )
      }
    )
  } + $settings

  if ($Existing) {
    $uri = "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies/$($Existing.id)"
    if ($PSCmdlet.ShouldProcess($name, "Update Intune compliance policy")) {
      Invoke-MgGraphRequest -Method PATCH -Uri $uri -Body ($body | ConvertTo-Json -Depth 10)
      Write-Host "Updated Intune compliance policy: $name"
    }
  } else {
    $uri = "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies"
    if ($PSCmdlet.ShouldProcess($name, "Create Intune compliance policy")) {
      Invoke-MgGraphRequest -Method POST -Uri $uri -Body ($body | ConvertTo-Json -Depth 10)
      Write-Host "Created Intune compliance policy: $name"
    }
  }
}

# --- main ---
if (-not (Test-Path $Path)) { throw "JSON not found: $Path" }
$template = Get-Content -Raw -Path $Path | ConvertFrom-Json -AsHashtable

Ensure-Graph

# Loop each platform in the template
foreach ($platform in $template.platforms) {
  $policyName = "$($template.policyName) - $platform"
  $existing = Get-CompliancePolicyByName -Name $policyName | Select-Object -First 1
  NewOrUpdate-CompliancePolicy -Template $template -Platform $platform -Existing $existing
}

Write-Host "Done."
