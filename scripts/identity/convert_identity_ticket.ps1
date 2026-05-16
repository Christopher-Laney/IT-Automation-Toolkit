<#
.SYNOPSIS
  Converts exported ServiceNow or Jira identity tickets into runnable workflow inputs.

.DESCRIPTION
  Supports two starter intake shapes:
    - ServiceNow onboarding request items exported as JSON
    - Jira offboarding issues exported as JSON

  Onboarding tickets become CSV files compatible with onboarding.ps1.
  Offboarding tickets become JSON execution-plan files for operator review.

.PARAMETER Provider
  Ticket provider. Supported values: ServiceNow, Jira.

.PARAMETER Path
  Path to the exported ticket JSON.

.PARAMETER OutputPath
  Path for the generated CSV or JSON artifact.

.PARAMETER PassThru
  Return the generated object after writing it.

.EXAMPLE
  .\convert_identity_ticket.ps1 `
    -Provider ServiceNow `
    -Path .\config\servicenow_onboarding_ticket.sample.json `
    -OutputPath .\logs\onboarding_from_ticket.csv

.EXAMPLE
  .\convert_identity_ticket.ps1 `
    -Provider Jira `
    -Path .\config\jira_offboarding_ticket.sample.json `
    -OutputPath .\logs\offboarding_plan.json
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('ServiceNow', 'Jira')]
    [string]$Provider,

    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [switch]$PassThru
)

function Ensure-OutputDirectory {
    param([string]$TargetPath)

    $directory = Split-Path -Parent $TargetPath
    if ($directory -and -not (Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
}

function Import-TicketJson {
    param([string]$TicketPath)

    if (-not (Test-Path $TicketPath)) {
        throw "Ticket export not found: $TicketPath"
    }

    try {
        Get-Content -Raw -Path $TicketPath | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw 'Ticket export must be valid JSON.'
    }
}

function Assert-RequiredFields {
    param(
        [hashtable]$Values,
        [string[]]$RequiredFields
    )

    $missing = @($RequiredFields | Where-Object { -not $Values[$_] })
    if ($missing) {
        throw "Ticket export is missing required field(s): $($missing -join ', ')."
    }
}

function Convert-ServiceNowTicket {
    param([object]$Ticket)

    $values = @{
        TicketId                 = $Ticket.number
        RequestType              = $Ticket.u_request_type
        DisplayName              = $Ticket.requested_for.name
        UserPrincipalName        = $Ticket.requested_for.email
        UsageLocation            = $Ticket.u_usage_location
        LicenseSku               = $Ticket.u_license_sku
        Groups                   = $Ticket.u_groups
        Department               = $Ticket.u_department
        ManagerUserPrincipalName = $Ticket.u_manager_upn
        StartDate                = $Ticket.u_start_date
    }

    Assert-RequiredFields -Values $values -RequiredFields @(
        'TicketId',
        'RequestType',
        'DisplayName',
        'UserPrincipalName',
        'UsageLocation'
    )

    if ($values.RequestType -ne 'Onboarding') {
        throw "Unsupported ServiceNow request type: $($values.RequestType)."
    }

    [pscustomobject]@{
        TicketId                 = $values.TicketId
        DisplayName              = $values.DisplayName
        UserPrincipalName        = $values.UserPrincipalName
        UsageLocation            = $values.UsageLocation
        LicenseSku               = $values.LicenseSku
        Groups                   = $values.Groups
        Department               = $values.Department
        ManagerUserPrincipalName = $values.ManagerUserPrincipalName
        StartDate                = $values.StartDate
    }
}

function Convert-JiraTicket {
    param([object]$Ticket)

    $values = @{
        TicketId          = $Ticket.key
        RequestType       = $Ticket.fields.customfield_request_type
        UserPrincipalName = $Ticket.fields.customfield_user_upn
    }

    Assert-RequiredFields -Values $values -RequiredFields @(
        'TicketId',
        'RequestType',
        'UserPrincipalName'
    )

    if ($values.RequestType -ne 'Offboarding') {
        throw "Unsupported Jira request type: $($values.RequestType)."
    }

    [pscustomobject]@{
        ticketId              = $values.TicketId
        userPrincipalName     = $values.UserPrincipalName
        blockSignIn           = [bool]$Ticket.fields.customfield_block_sign_in
        resetPassword         = [bool]$Ticket.fields.customfield_reset_password
        revokeSessions        = [bool]$Ticket.fields.customfield_revoke_sessions
        removeFromGroups      = [bool]$Ticket.fields.customfield_remove_from_groups
        removeLicenses        = [bool]$Ticket.fields.customfield_remove_licenses
        exchangeConvertToShared = [bool]$Ticket.fields.customfield_exchange_convert_to_shared
        exchangeLitigationHold  = [bool]$Ticket.fields.customfield_exchange_litigation_hold
        oneDriveLock          = [bool]$Ticket.fields.customfield_one_drive_lock
        transferOneDriveTo    = $Ticket.fields.customfield_transfer_one_drive_to
    }
}

$ticket = Import-TicketJson -TicketPath $Path
Ensure-OutputDirectory -TargetPath $OutputPath

switch ($Provider) {
    'ServiceNow' {
        $artifact = Convert-ServiceNowTicket -Ticket $ticket
        $artifact | Select-Object `
            DisplayName,
            UserPrincipalName,
            UsageLocation,
            LicenseSku,
            Groups,
            Department,
            ManagerUserPrincipalName,
            StartDate |
            Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        Write-Host "Onboarding CSV written to $OutputPath from ticket $($artifact.TicketId)"
    }
    'Jira' {
        $artifact = Convert-JiraTicket -Ticket $ticket
        $artifact | ConvertTo-Json -Depth 5 | Set-Content -Path $OutputPath -Encoding UTF8
        Write-Host "Offboarding plan written to $OutputPath from ticket $($artifact.ticketId)"
    }
}

if ($PassThru) {
    $artifact
}
