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

.PARAMETER ValidateOnly
  Validate the template schema and exit before connecting to Microsoft Graph.

.PARAMETER PreviewPayload
  Validate the template, emit the generated per-platform payloads, and exit
  before connecting to Microsoft Graph.

.EXAMPLE
  .\apply_intune_policy.ps1

.EXAMPLE
  .\apply_intune_policy.ps1 -Path .\config\intune_policy_template.json -ValidateOnly
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [string]$Path = ".\config\intune_policy_template.json",
  [switch]$ValidateOnly,
  [switch]$PreviewPayload
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

function Test-RequiredProperty {
  param(
    [Parameter(Mandatory=$true)][hashtable]$InputObject,
    [Parameter(Mandatory=$true)][string]$Name,
    [Parameter(Mandatory=$true)][string]$Context
  )

  if (
    -not $InputObject.ContainsKey($Name) -or
    $null -eq $InputObject[$Name] -or
    ($InputObject[$Name] -is [string] -and [string]::IsNullOrWhiteSpace($InputObject[$Name]))
  ) {
    throw "$Context is missing required property '$Name'."
  }
}

function Test-IntunePolicyTemplate {
  param([Parameter(Mandatory=$true)][hashtable]$Template)

  Test-RequiredProperty -InputObject $Template -Name 'policyName' -Context 'Template'
  Test-RequiredProperty -InputObject $Template -Name 'description' -Context 'Template'
  Test-RequiredProperty -InputObject $Template -Name 'platforms' -Context 'Template'
  Test-RequiredProperty -InputObject $Template -Name 'complianceSettings' -Context 'Template'
  Test-RequiredProperty -InputObject $Template -Name 'remediationActions' -Context 'Template'

  $supportedPlatforms = @('Windows10','Windows11','macOS','iOS','Android')
  foreach ($platform in @($Template.platforms)) {
    if ($supportedPlatforms -notcontains $platform) {
      throw "Unsupported platform '$platform'. Supported values: $($supportedPlatforms -join ', ')."
    }
  }

  $requiredSettings = @(
    'requireBitLocker',
    'firewallEnabled',
    'passwordRequired',
    'passwordMinimumLength',
    'passwordExpirationDays',
    'passwordPreviousPasswordBlockCount',
    'osMinimumVersion',
    'jailbreakDetectionEnabled',
    'secureBootEnabled',
    'codeIntegrityEnabled',
    'deviceThreatProtectionRequiredSecurityLevel',
    'antivirusRequired'
  )

  foreach ($setting in $requiredSettings) {
    Test-RequiredProperty -InputObject $Template.complianceSettings -Name $setting -Context 'complianceSettings'
  }

  foreach ($actionKey in @('1','2')) {
    if (-not $Template.remediationActions.ContainsKey($actionKey)) {
      throw "remediationActions is missing required action '$actionKey'."
    }
    Test-RequiredProperty -InputObject $Template.remediationActions[$actionKey] -Name 'gracePeriodHours' -Context "remediationActions.$actionKey"
  }
}

function New-CompliancePolicyBody {
  param(
    [hashtable]$Template,
    [string]$Platform  # Windows10|Windows11|macOS|iOS|Android
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
        storageRequireEncryption                          = $Template.complianceSettings.requireBitLocker
        deviceCompliancePolicyScriptResults               = @() # placeholder
      }
    }
    'macOS' {
      $odata = "#microsoft.graph.macOSCompliancePolicy"
      $settings = @{
        passwordRequired                    = $Template.complianceSettings.passwordRequired
        passwordMinimumLength               = $Template.complianceSettings.passwordMinimumLength
        passwordExpirationDays              = $Template.complianceSettings.passwordExpirationDays
        passwordPreviousPasswordBlockCount  = $Template.complianceSettings.passwordPreviousPasswordBlockCount
        osMinimumVersion                    = $Template.complianceSettings.osMinimumVersion
        osMaximumVersion                    = $Template.complianceSettings.osMaximumVersion
        systemIntegrityProtectionEnabled    = $true
        storageRequireEncryption            = $Template.complianceSettings.requireBitLocker
        firewallEnabled                     = $Template.complianceSettings.firewallEnabled
        deviceThreatProtectionRequiredSecurityLevel = $Template.complianceSettings.deviceThreatProtectionRequiredSecurityLevel
      }
    }
    'iOS' {
      $odata = "#microsoft.graph.iosCompliancePolicy"
      $settings = @{
        passcodeRequired                    = $Template.complianceSettings.passwordRequired
        passcodeMinimumLength               = $Template.complianceSettings.passwordMinimumLength
        passcodeExpirationDays              = $Template.complianceSettings.passwordExpirationDays
        passcodePreviousPasscodeBlockCount  = $Template.complianceSettings.passwordPreviousPasswordBlockCount
        osMinimumVersion                    = $Template.complianceSettings.osMinimumVersion
        osMaximumVersion                    = $Template.complianceSettings.osMaximumVersion
        securityBlockJailbrokenDevices = $Template.complianceSettings.jailbreakDetectionEnabled
        deviceThreatProtectionRequiredSecurityLevel = $Template.complianceSettings.deviceThreatProtectionRequiredSecurityLevel
      }
    }
    'Android' {
      $odata = "#microsoft.graph.androidCompliancePolicy"
      $settings = @{
        passwordRequired                    = $Template.complianceSettings.passwordRequired
        passwordMinimumLength               = $Template.complianceSettings.passwordMinimumLength
        passwordExpirationDays              = $Template.complianceSettings.passwordExpirationDays
        passwordPreviousPasswordBlockCount  = $Template.complianceSettings.passwordPreviousPasswordBlockCount
        osMinimumVersion                    = $Template.complianceSettings.osMinimumVersion
        osMaximumVersion                    = $Template.complianceSettings.osMaximumVersion
        securityBlockJailbrokenDevices = $Template.complianceSettings.jailbreakDetectionEnabled
        storageRequireEncryption = $Template.complianceSettings.requireBitLocker
        deviceThreatProtectionRequiredSecurityLevel = $Template.complianceSettings.deviceThreatProtectionRequiredSecurityLevel
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

  return $body
}

function NewOrUpdate-CompliancePolicy {
  param(
    [hashtable]$Template,
    [string]$Platform,
    [hashtable]$Existing
  )

  $baseName = $Template.policyName
  $name = "$baseName - $Platform"
  $body = New-CompliancePolicyBody -Template $Template -Platform $Platform

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
Test-IntunePolicyTemplate -Template $template

if ($ValidateOnly) {
  Write-Host "Template validation passed: $Path"
  return
}

if ($PreviewPayload) {
  foreach ($platform in $template.platforms) {
    New-CompliancePolicyBody -Template $template -Platform $platform
  }
  return
}

Ensure-Graph

# Loop each platform in the template
foreach ($platform in $template.platforms) {
  $policyName = "$($template.policyName) - $platform"
  $existing = Get-CompliancePolicyByName -Name $policyName | Select-Object -First 1
  NewOrUpdate-CompliancePolicy -Template $template -Platform $platform -Existing $existing
}

Write-Host "Done."
