<#
.SYNOPSIS
  Builds a rollback-oriented identity change artifact from an onboarding report.

.DESCRIPTION
  Reads the CSV report emitted by onboarding.ps1 and writes a JSON artifact
  that summarizes created users, added licenses, added groups, and suggested
  rollback commands for operator review.

.PARAMETER ReportPath
  Path to an onboarding run report CSV.

.PARAMETER OutputPath
  Path to write the JSON artifact.

.PARAMETER PassThru
  Return the generated artifact object after writing it.

.EXAMPLE
  .\export_identity_change_artifact.ps1 `
    -ReportPath .\logs\onboarding_run.csv `
    -OutputPath .\logs\onboarding_change_artifact.json
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ReportPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [switch]$PassThru
)

function Split-ArtifactList {
    param([string]$Value)

    if (-not $Value) {
        return @()
    }

    @($Value -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Ensure-OutputDirectory {
    param([string]$Path)

    $directory = Split-Path -Parent $Path
    if ($directory -and -not (Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
}

if (-not (Test-Path $ReportPath)) {
    throw "Onboarding report not found: $ReportPath"
}

$rows = @(Import-Csv -Path $ReportPath)
if (-not $rows) {
    throw 'Onboarding report contains no rows.'
}

$requiredHeaders = @('UserPrincipalName', 'Action', 'LicensesAdded', 'GroupsAdded')
$headers = @($rows[0].PSObject.Properties.Name)
$missing = $requiredHeaders | Where-Object { $headers -notcontains $_ }
if ($missing) {
    throw "Onboarding report is missing required header(s): $($missing -join ', ')."
}

$entries = @(
    foreach ($row in $rows) {
        $licensesAdded = Split-ArtifactList $row.LicensesAdded
        $groupsAdded = Split-ArtifactList $row.GroupsAdded
        $rollbackCommands = @()

        foreach ($group in $groupsAdded) {
            $rollbackCommands += "Remove-MgGroupMemberByRef -GroupId '<resolve:$group>' -DirectoryObjectId '<resolve:$($row.UserPrincipalName)>'"
        }
        foreach ($license in $licensesAdded) {
            $rollbackCommands += "Set-MgUserLicense -UserId '$($row.UserPrincipalName)' -AddLicenses @() -RemoveLicenses '$license'"
        }
        if ($row.Action -eq 'Created') {
            $rollbackCommands += "Remove-MgUser -UserId '$($row.UserPrincipalName)'"
        }

        [pscustomobject]@{
            userPrincipalName = $row.UserPrincipalName
            action            = $row.Action
            licensesAdded     = $licensesAdded
            groupsAdded       = $groupsAdded
            rollbackCommands  = $rollbackCommands
        }
    }
)

$artifact = [pscustomobject]@{
    createdUtc = (Get-Date).ToUniversalTime().ToString('o')
    sourceReport = $ReportPath
    summary = [pscustomobject]@{
        usersCreated  = @($entries | Where-Object { $_.action -eq 'Created' }).Count
        licensesAdded = @($entries | ForEach-Object { $_.licensesAdded }).Count
        groupsAdded   = @($entries | ForEach-Object { $_.groupsAdded }).Count
    }
    entries = $entries
}

Ensure-OutputDirectory -Path $OutputPath
$artifact | ConvertTo-Json -Depth 8 | Set-Content -Path $OutputPath -Encoding UTF8
Write-Host "Identity change artifact written to $OutputPath"

if ($PassThru) {
    $artifact
}
