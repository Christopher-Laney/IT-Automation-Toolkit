<#
.SYNOPSIS
  Report users inactive for N days (Azure AD via Graph or on-prem AD).

.DESCRIPTION
  - AzureAD mode: queries Graph for sign-in activity (requires Graph permissions).
  - AD mode: queries on-prem AD via LastLogonTimestamp (domain-joined runspace).

.PARAMETER Mode
  'AzureAD' or 'AD'. Default: AzureAD.

.PARAMETER InactiveDays
  Threshold in days for inactivity. Default: 30.

.PARAMETER ExportPath
  Path to CSV export. Default: .\reports\inactive_users.csv

.PARAMETER FilterGuests
  Exclude guest/B2B users (AzureAD mode). Default: $true

.EXAMPLE
  .\inactive_user_report.ps1 -Mode AzureAD -InactiveDays 45 -ExportPath .\reports\inactive_azure.csv

.EXAMPLE
  .\inactive_user_report.ps1 -Mode AD -InactiveDays 60 -ExportPath .\reports\inactive_onprem.csv
#>

[CmdletBinding()]
param(
  [ValidateSet('AzureAD','AD')]
  [string]$Mode = 'AzureAD',

  [int]$InactiveDays = 30,

  [string]$ExportPath = ".\reports\inactive_users.csv",

  [bool]$FilterGuests = $true
)

begin {
  $ErrorActionPreference = 'Stop'
  $null = New-Item -ItemType Directory -Path (Split-Path $ExportPath) -Force -ErrorAction SilentlyContinue
}

process {
  $cutoff = (Get-Date).AddDays(-$InactiveDays)

  switch ($Mode) {
    'AzureAD' {
      try {
        # Requires: Microsoft.Graph.Users (and Directory) with consent for signInActivity
        # Connect-MgGraph -Scopes "User.Read.All","AuditLog.Read.All"
        # Select beta profile only if needed for signInActivity in your tenant:
        # Select-MgProfile -Name "beta"

        Write-Verbose "Querying Microsoft Graph for users with sign-in activity..."
        $users = Get-MgUser -All -Property "id,displayName,userPrincipalName,createdDateTime,userType,signInActivity"

        if ($FilterGuests) {
          $users = $users | Where-Object { $_.UserType -ne 'Guest' }
        }

        $rows = foreach ($u in $users) {
          # signInActivity.LastSignInDateTime may be $null (never signed in)
          $last = $u.AdditionalProperties.signInActivity.lastSignInDateTime
          $lastParsed = if ($last) { [datetime]$last } else { $null }
          [pscustomobject]@{
            DisplayName         = $u.DisplayName
            UserPrincipalName   = $u.UserPrincipalName
            UserType            = $u.UserType
            CreatedDateTime     = $u.CreatedDateTime
            LastSignInDateTime  = $lastParsed
            InactiveDays        = if ($lastParsed) { (New-TimeSpan -Start $lastParsed -End (Get-Date)).Days } else { [int]::MaxValue }
            Status              = if (-not $lastParsed -or $lastParsed -lt $cutoff) { 'Inactive' } else { 'Active' }
          }
        }

        $report = $rows | Where-Object { $_.Status -eq 'Inactive' }
      }
      catch {
        Write-Error "AzureAD mode failed: $($_.Exception.Message)"
        return
      }
    }

    'AD' {
      try {
        # Requires: ActiveDirectory module on a domain-joined machine
        # Import-Module ActiveDirectory
        Write-Verbose "Querying on-prem AD for LastLogonTimestamp..."
        $adUsers = Get-ADUser -Filter * -Properties DisplayName,mail,LastLogonTimestamp,whenCreated,Enabled

        $rows = foreach ($u in $adUsers) {
          $last = if ($u.LastLogonTimestamp) { [DateTime]::FromFileTime($u.LastLogonTimestamp) } else { $null }
          [pscustomobject]@{
            DisplayName        = $u.DisplayName
            UserPrincipalName  = $u.UserPrincipalName
            Mail               = $u.mail
            Enabled            = $u.Enabled
            CreatedDateTime    = $u.whenCreated
            LastLogonDateTime  = $last
            InactiveDays       = if ($last) { (New-TimeSpan -Start $last -End (Get-Date)).Days } else { [int]::MaxValue }
            Status             = if (-not $last -or $last -lt $cutoff) { 'Inactive' } else { 'Active' }
          }
        }

        $report = $rows | Where-Object { $_.Status -eq 'Inactive' -and $_.Enabled -eq $true }
      }
      catch {
        Write-Error "AD mode failed: $($_.Exception.Message)"
        return
      }
    }
  }

  $report | Sort-Object InactiveDays -Descending | Export-Csv -NoTypeInformation -Path $ExportPath
  Write-Host "Inactive user report saved to $ExportPath"
}
