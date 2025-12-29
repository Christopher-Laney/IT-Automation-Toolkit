<#
.SYNOPSIS
  Automated user onboarding for Entra ID / Microsoft 365 with licensing, groups, and logging.

.DESCRIPTION
  Reads a CSV (headers below) and for each row:
    - Creates user if missing; otherwise updates basics (displayName, usageLocation)
    - Sets temp password & force-change-at-next-sign-in (optional)
    - Assigns M365 licenses by SKU part number(s) (idempotent)
    - Adds to groups (comma-separated list or mapped defaults)
    - Adds to an MFA-enforcement group (optional)
    - Adds to an Intune enrollment group (optional)
    - Logs results and emits a summary CSV

.CSV HEADERS (minimum)
  DisplayName,UserPrincipalName,UsageLocation,LicenseSku,Groups
  Examples:
    "Jane Doe","jane.doe@contoso.com","US","ENTERPRISEPACK;POWER_BI_PRO","All-Employees;Finance"
    "John Smith","john.smith@contoso.com","CA","STANDARDWOFFPACK_IW_FACULTY","All-Employees"

.PARAMETER UserList
  Path to CSV with user rows.

.PARAMETER DefaultUsageLocation
  Usage location if CSV field is empty (e.g., US).

.PARAMETER DefaultPasswordLength
  Length of temp password (default 16, 3 non-alphanum).

.PARAMETER SetTempPassword
  If set, a random password is applied with force-change at next sign-in.

.PARAMETER MfaGroup
  Display name or ID of a group that enforces MFA via Conditional Access.

.PARAMETER IntuneEnrollmentGroup
  Display name or ID of group that targets Intune enrollment/autopilot policies.

.PARAMETER ReportPath
  Optional path to write a run report CSV.

.PARAMETER WhatIf
  Show what would happen without changing anything.

.REQUIREMENTS
  Install-Module Microsoft.Graph -Scope CurrentUser
  Connect-MgGraph -Scopes "User.ReadWrite.All","Directory.ReadWrite.All","Group.ReadWrite.All","Directory.AccessAsUser.All","AuditLog.Read.All","Organization.Read.All"
  (For very strict tenants, add "Directory.Read.All" as needed.)

.EXAMPLE
  .\onboarding.ps1 -UserList .\config\new_users.csv -SetTempPassword `
    -MfaGroup "MFA-Users" -IntuneEnrollmentGroup "Intune-AutoEnroll" `
    -ReportPath .\logs\onboarding_run.csv -WhatIf

.EXAMPLE
  .\onboarding.ps1 -UserList .\config\new_users.csv -DefaultUsageLocation US -SetTempPassword
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [Parameter(Mandatory=$true)][string]$UserList,
  [string]$DefaultUsageLocation,
  [int]$DefaultPasswordLength = 16,
  [switch]$SetTempPassword,
  [string]$MfaGroup,
  [string]$IntuneEnrollmentGroup,
  [string]$ReportPath,
  [switch]$WhatIf
)

# ----------------- helpers -----------------
function Ensure-Graph {
  if (-not (Get-Module Microsoft.Graph -ListAvailable)) {
    Write-Host "Installing Microsoft.Graph..." -ForegroundColor Yellow
    Install-Module Microsoft.Graph -Scope CurrentUser -Force
  }
  if (-not (Get-MgContext)) {
    Write-Host "Connecting to Microsoft Graph..."
    Connect-MgGraph -Scopes "User.ReadWrite.All","Directory.ReadWrite.All","Group.ReadWrite.All","AuditLog.Read.All","Organization.Read.All"
  }
  Select-MgProfile -Name "v1.0" | Out-Null
}

function Get-SkuMap {
  # Build a cache of SkuPartNumber → SkuId
  $ten = Get-MgOrganization -ErrorAction Stop
  $subs = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/subscribedSkus"
  $map = @{}
  foreach ($s in $subs.value) {
    $map[$s.skuPartNumber] = $s.skuId
  }
  return $map
}

function Resolve-GroupId {
  param([string]$NameOrId)
  if ($NameOrId -match '^[0-9a-fA-F-]{36}$') { return $NameOrId }
  $g = Get-MgGroup -Filter "displayName eq '$($NameOrId.Replace("'","''"))'" -ConsistencyLevel eventual -CountVariable c -ErrorAction SilentlyContinue
  return $g.Id
}

function Ensure-User {
  param(
    [hashtable]$Row,
    [string]$DefaultUsageLocation,
    [switch]$SetTempPassword,
    [int]$DefaultPasswordLength
  )
  $upn = $Row.UserPrincipalName
  $existing = $null
  try { $existing = Get-MgUser -UserId $upn -ErrorAction Stop } catch {}

  $usage = if ($Row.UsageLocation) { $Row.UsageLocation } elseif ($DefaultUsageLocation) { $DefaultUsageLocation } else { $null }

  if (-not $existing) {
    # create
    $pwd = $null
    if ($SetTempPassword) {
      $pwd = [System.Web.Security.Membership]::GeneratePassword($DefaultPasswordLength,[Math]::Min(4, [int]($DefaultPasswordLength/5)))
    }
    $body = @{
      accountEnabled    = $true
      displayName       = $Row.DisplayName
      mailNickname      = ($Row.DisplayName -replace '\s','')
      userPrincipalName = $upn
    }
    if ($usage) { $body.usageLocation = $usage }
    if ($pwd) {
      $body.passwordProfile = @{
        forceChangePasswordNextSignIn = $true
        password = $pwd
      }
    }

    if ($PSCmdlet.ShouldProcess($upn,"Create user")) {
      $newUser = New-MgUser -BodyParameter $body
      return ,@($newUser, $pwd, "Created")
    } else {
      return ,@($null, $pwd, "WouldCreate")
    }
  } else {
    # update basics
    $updates = @{}
    if ($Row.DisplayName -and $Row.DisplayName -ne $existing.DisplayName) { $updates.displayName = $Row.DisplayName }
    if ($usage -and $usage -ne $existing.UsageLocation) { $updates.usageLocation = $usage }

    if ($updates.Count -gt 0 -and $PSCmdlet.ShouldProcess($upn,"Update user properties")) {
      Update-MgUser -UserId $existing.Id -BodyParameter $updates | Out-Null
    }
    return ,@($existing, $null, "ExistsUpdated")
  }
}

function Assign-Licenses {
  param(
    [Microsoft.Graph.PowerShell.Models.IMicrosoftGraphUser]$User,
    [string[]]$SkuNames,
    [hashtable]$SkuMap
  )
  if (-not $SkuNames -or $SkuNames.Count -eq 0) { return @("NoLicensesRequested", @()) }

  $targetSkuIds = @()
  foreach ($n in $SkuNames) {
    $trim = $n.Trim()
    if ($trim) {
      if ($SkuMap.ContainsKey($trim)) { $targetSkuIds += $SkuMap[$trim] }
      else { Write-Warning "Unknown SkuPartNumber: $trim" }
    }
  }

  if ($targetSkuIds.Count -eq 0) { return @("NoResolvedSkus", @()) }

  # get current assigned SKU IDs
  $current = (Get-MgUserLicenseDetail -UserId $User.Id -All -ErrorAction SilentlyContinue).SkuId
  $toAdd = $targetSkuIds | Where-Object { $current -notcontains $_ }

  if ($toAdd.Count -gt 0 -and $PSCmdlet.ShouldProcess($User.UserPrincipalName,"Assign licenses")) {
    Set-MgUserLicense -UserId $User.Id -AddLicenses (@(@{SkuId = $toAdd[0]}) + ($toAdd | Select-Object -Skip 1 | ForEach-Object { @{SkuId = $_} })) -RemoveLicenses @() | Out-Null
    return @("Assigned", $toAdd)
  }
  return @("AlreadyAssignedOrNone", $toAdd)
}

function Ensure-GroupMemberships {
  param(
    [Microsoft.Graph.PowerShell.Models.IMicrosoftGraphUser]$User,
    [string[]]$Groups
  )
  $added = @()
  if (-not $Groups -or $Groups.Count -eq 0) { return $added }

  # current membership
  $memberOf = Get-MgUserMemberOf -UserId $User.Id -All | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.group' }
  $currentIds = $memberOf.Id

  foreach ($gSpec in $Groups) {
    $gName = $gSpec.Trim()
    if (-not $gName) { continue }
    $gid = Resolve-GroupId -NameOrId $gName
    if (-not $gid) { Write-Warning "Group not found: $gName"; continue }
    if ($currentIds -contains $gid) { continue }

    if ($PSCmdlet.ShouldProcess("$($User.UserPrincipalName) → $gName","Add to group")) {
      New-MgGroupMemberByRef -GroupId $gid -BodyParameter @{ "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($User.Id)" } | Out-Null
      $added += $gName
    }
  }
  return $added
}

function Split-List($value) {
  if (-not $value) { return @() }
  return ($value -split '[;,]' | ForEach-Object { $_.Trim() }) | Where-Object { $_ }
}

function Ensure-ReportDir($path) {
  if (-not $path) { return }
  $dir = Split-Path -Parent $path
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
}

# ----------------- main -----------------
try {
  Ensure-Graph

  if (-not (Test-Path $UserList)) { throw "CSV not found: $UserList" }
  $rows = Import-Csv -Path $UserList

  $skuMap = Get-SkuMap
  $mfaGroupId    = if ($MfaGroup) { Resolve-GroupId -NameOrId $MfaGroup } else { $null }
  $intuneGroupId = if ($IntuneEnrollmentGroup) { Resolve-GroupId -NameOrId $IntuneEnrollmentGroup } else { $null }

  $report = @()

  foreach ($u in $rows) {
    $upn = $u.UserPrincipalName
    $action = "Skipped"
    $pwdOut = $null
    $licenseStatus = "None"
    $licenseAdded  = @()
    $groupsAdded   = @()

    try {
      $user,$pwd,$action = Ensure-User -Row $u -DefaultUsageLocation $DefaultUsageLocation -SetTempPassword:$SetTempPassword -DefaultPasswordLength $DefaultPasswordLength
      if (-not $user) {
        # WhatIf create; still record intended licenses/groups
        $skuNames = Split-List $u.LicenseSku
        $licenseStatus = if ($skuNames.Count -gt 0) { "WouldAssign" } else { "None" }
      } else {
        # Licenses
        $skuNames = Split-List $u.LicenseSku
        $licenseStatus,$licenseAdded = Assign-Licenses -User $user -SkuNames $skuNames -SkuMap $skuMap

        # Groups from CSV row
        $csvGroups = Split-List $u.Groups
        $targets = @()
        if ($csvGroups) { $targets += $csvGroups }
        if ($mfaGroupId) { $targets += $mfaGroupId }
        if ($intuneGroupId) { $targets += $intuneGroupId }

        # Normalize targets back to display names where possible
        $resolvedTargets = @()
        foreach ($tg in $targets) {
          if ($tg -match '^[0-9a-fA-F-]{36}$') { $resolvedTargets += $tg } else { $resolvedTargets += $tg }
        }
        $groupsAdded = Ensure-GroupMemberships -User $user -Groups $resolvedTargets
      }

      $report += [pscustomobject]@{
        TimestampUTC    = (Get-Date).ToUniversalTime().ToString('o')
        UserPrincipalName = $upn
        DisplayName     = $u.DisplayName
        Action          = $action
        TempPasswordSet = [bool]$SetTempPassword
        TempPassword    = $pwd
        LicenseStatus   = $licenseStatus
        LicensesAdded   = ($licenseAdded -join ';')
        GroupsRequested = $u.Groups
        GroupsAdded     = ($groupsAdded -join ';')
        UsageLocation   = ( if ($u.UsageLocation) { $u.UsageLocation } else { $DefaultUsageLocation } )
        Notes           = ""
      }
      Write-Host "✔ $upn: $action; Licenses=$licenseStatus; GroupsAdded=[$($groupsAdded -join ', ')]"
    }
    catch {
      $report += [pscustomobject]@{
        TimestampUTC    = (Get-Date).ToUniversalTime().ToString('o')
        UserPrincipalName = $upn
        DisplayName     = $u.DisplayName
        Action          = "Error"
        TempPasswordSet = [bool]$SetTempPassword
        TempPassword    = $null
        LicenseStatus   = "Error"
        LicensesAdded   = ""
        GroupsRequested = $u.Groups
        GroupsAdded     = ""
        UsageLocation   = ( if ($u.UsageLocation) { $u.UsageLocation } else { $DefaultUsageLocation } )
        Notes           = $_.Exception.Message
      }
      Write-Warning "✖ $upn failed: $($_.Exception.Message)"
    }
  }

  if ($ReportPath) {
    Ensure-ReportDir $ReportPath
    $report | Export-Csv -Path $ReportPath -NoTypeInformation -Encoding UTF8
    Write-Host "Run report written to $ReportPath"
  }

  Write-Host "Onboarding complete."
}
catch {
  Write-Error $_.Exception.Message
  exit 1
}
