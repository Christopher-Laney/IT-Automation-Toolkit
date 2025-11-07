<#
.SYNOPSIS
  Create/update a baseline Conditional Access policy from JSON.

.DESCRIPTION
  Reads ./config/conditional_access_baseline.json and applies it via Microsoft Graph.
  Idempotent: updates existing policy by name; creates if missing.

.REQUIREMENTS
  Install-Module Microsoft.Graph -Scope CurrentUser
  Connect-MgGraph -Scopes "Policy.Read.All","Policy.ReadWrite.ConditionalAccess","Directory.Read.All"

.PARAMETER Path
  Path to the JSON file. Defaults to ./config/conditional_access_baseline.json

.PARAMETER WhatIf
  Show what would happen without making changes.

.EXAMPLE
  .\set_conditional_access_policy.ps1
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [string]$Path = ".\config\conditional_access_baseline.json"
)

function Ensure-Graph {
  if (-not (Get-Module Microsoft.Graph -ListAvailable)) {
    Write-Verbose "Installing Microsoft.Graph..."
    Install-Module Microsoft.Graph -Scope CurrentUser -Force
  }
  if (-not (Get-MgContext)) {
    Write-Host "Connecting to Microsoft Graph..."
    Connect-MgGraph -Scopes "Policy.Read.All","Policy.ReadWrite.ConditionalAccess","Directory.Read.All"
  }
  Select-MgProfile -Name "v1.0" | Out-Null
}

function Get-CaPolicyByDisplayName {
  param([string]$DisplayName)
  $uri = "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies`?$filter=displayName eq '$($DisplayName.Replace("'","''"))'"
  (Invoke-MgGraphRequest -Method GET -Uri $uri).value
}

function NewOrUpdate-CaPolicy {
  param(
    [hashtable]$Model,
    [hashtable]$Existing # may be $null
  )

  # Build Graph body from our friendly JSON
  $displayName = $Model.policy
  $state       = $Model.state
  $desc        = $Model.description

  # conditions
  $cond = $Model.conditions

  # Users
  $users = @{
    includeUsers  = @()
    excludeUsers  = @()
    includeGroups = @()
    excludeGroups = @()
    includeRoles  = @()
    excludeRoles  = @()
  }
  if ($cond.users.includeGroups) { $users.includeGroups = $cond.users.includeGroups }
  if ($cond.users.excludeGroups) { $users.excludeGroups = $cond.users.excludeGroups }

  # Applications
  $apps = @{
    includeApplications = @()
    excludeApplications = @()
  }
  if ($cond.applications.includeApps) { $apps.includeApplications = $cond.applications.includeApps }
  if ($cond.applications.excludeApps) { $apps.excludeApplications = $cond.applications.excludeApps }

  # Locations
  $locs = @{
    includeLocations = @()
    excludeLocations = @()
  }
  if ($cond.locations.includeLocations) { $locs.includeLocations = $cond.locations.includeLocations }
  if ($cond.locations.excludeLocations) { $locs.excludeLocations = $cond.locations.excludeLocations }

  # Device platforms, client app types, sign-in risk
  $devPlatforms = @{ includePlatforms = @(); excludePlatforms = @() }
  if ($cond.devicePlatforms.includePlatforms) { $devPlatforms.includePlatforms = $cond.devicePlatforms.includePlatforms }
  if ($cond.devicePlatforms.excludePlatforms) { $devPlatforms.excludePlatforms = $cond.devicePlatforms.excludePlatforms }

  $clientAppTypes = $cond.clientAppTypes
  $signInRiskLevels = $cond.signInRiskLevels

  # Device States (compliant / unknown)
  $deviceStates = $null
  if ($cond.deviceStates) {
    $deviceStates = @{
      includeStates = $cond.deviceStates.includeStates
      excludeStates = $cond.deviceStates.excludeStates
    }
  }

  # grant controls
  $grantControls = @{
    operator        = $Model.grantControls.operator
    builtInControls = $Model.grantControls.builtInControls
    customAuthenticationFactors = @()
    termsOfUse      = @()
  }

  # session controls
  $sessionControls = @{}
  if ($Model.sessionControls.signInFrequency.isEnabled) {
    $sessionControls.signInFrequency = @{
      isEnabled = $true
      value     = $Model.sessionControls.signInFrequency.value
      type      = $Model.sessionControls.signInFrequency.unit  # hours or days per Graph docs
    }
  }
  if ($Model.sessionControls.persistentBrowser) {
    $sessionControls.persistentBrowser = @{
      mode = $Model.sessionControls.persistentBrowser.mode  # always/never
    }
  }
  if ($Model.sessionControls.appEnforcedRestrictions.isEnabled) {
    $sessionControls.applicationEnforcedRestrictions = @{ isEnabled = $true }
  }
  if ($Model.sessionControls.cloudAppSecurity.isEnabled) {
    $sessionControls.cloudAppSecurity = @{
      isEnabled = $true
      cloudAppSecurityType = if ($Model.sessionControls.cloudAppSecurity.mode -eq 'monitorOnly') { 'mcasMonitor' } else { 'mcasBlock' }
    }
  }

  $body = @{
    displayName = $displayName
    state       = $state
    conditions  = @{
      users          = $users
      applications   = $apps
      locations      = $locs
      platforms      = $devPlatforms
      clientAppTypes = $clientAppTypes
      signInRiskLevels = $signInRiskLevels
    }
    grantControls   = $grantControls
    sessionControls = $sessionControls
  }
  if ($desc) { $body.description = $desc }
  if ($deviceStates) { $body.conditions.deviceStates = $deviceStates }

  if ($Existing) {
    $uri = "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies/$($Existing.id)"
    if ($PSCmdlet.ShouldProcess($displayName, "Update Conditional Access policy")) {
      Invoke-MgGraphRequest -Method PATCH -Uri $uri -Body ($body | ConvertTo-Json -Depth 10)
      Write-Host "Updated Conditional Access policy: $displayName"
    }
  } else {
    $uri = "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies"
    if ($PSCmdlet.ShouldProcess($displayName, "Create Conditional Access policy")) {
      Invoke-MgGraphRequest -Method POST -Uri $uri -Body ($body | ConvertTo-Json -Depth 10)
      Write-Host "Created Conditional Access policy: $displayName"
    }
  }
}

# --- main ---
if (-not (Test-Path $Path)) { throw "JSON not found: $Path" }
$json = Get-Content -Raw -Path $Path | ConvertFrom-Json -AsHashtable
Ensure-Graph

$existing = Get-CaPolicyByDisplayName -DisplayName $json.policy | Select-Object -First 1
NewOrUpdate-CaPolicy -Model $json -Existing $existing
