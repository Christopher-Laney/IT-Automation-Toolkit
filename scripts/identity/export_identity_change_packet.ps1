<#
.SYNOPSIS
  Builds a compact audit packet for identity workflow review.

.DESCRIPTION
  Combines a ticket export, approval record, and optional generated workflow
  artifacts into one JSON packet with SHA256 fingerprints for later review.

.PARAMETER WorkflowType
  Identity workflow type. Supported values: Onboarding, Offboarding.

.PARAMETER TicketPath
  Path to the source ServiceNow or Jira ticket export JSON.

.PARAMETER ApprovalRecordPath
  Path to the approval record JSON used for the workflow.

.PARAMETER RelatedArtifactPaths
  Optional generated workflow artifacts such as onboarding CSVs, reports,
  rollback ledgers, or offboarding plans.

.PARAMETER OutputPath
  Path to write the packet JSON.

.PARAMETER PassThru
  Return the generated packet after writing it.

.EXAMPLE
  .\export_identity_change_packet.ps1 `
    -WorkflowType Onboarding `
    -TicketPath .\config\servicenow_onboarding_ticket.sample.json `
    -ApprovalRecordPath .\config\approval_record.sample.json `
    -RelatedArtifactPaths .\logs\onboarding_from_ticket.csv `
    -OutputPath .\logs\identity_change_packet.json
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Onboarding', 'Offboarding')]
    [string]$WorkflowType,

    [Parameter(Mandatory = $true)]
    [string]$TicketPath,

    [Parameter(Mandatory = $true)]
    [string]$ApprovalRecordPath,

    [string[]]$RelatedArtifactPaths,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [switch]$PassThru
)

function Import-JsonFile {
    param(
        [string]$Path,
        [string]$Label
    )

    if (-not (Test-Path $Path)) {
        throw "$Label not found: $Path"
    }

    try {
        Get-Content -Raw -Path $Path | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "$Label must be valid JSON."
    }
}

function Get-ArtifactFingerprint {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "Related artifact not found: $Path"
    }

    $resolved = (Resolve-Path -LiteralPath $Path).Path
    $root = (Resolve-Path -LiteralPath '.').Path
    $displayPath = if ($resolved.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        $resolved.Substring($root.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar).Replace('\', '/')
    } else {
        $resolved.Replace('\', '/')
    }

    [pscustomobject]@{
        path   = $displayPath
        sha256 = (Get-FileHash -Path $Path -Algorithm SHA256).Hash
    }
}

function Ensure-OutputDirectory {
    param([string]$Path)

    $directory = Split-Path -Parent $Path
    if ($directory -and -not (Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
}

$ticket = Import-JsonFile -Path $TicketPath -Label 'Ticket export'
$approval = Import-JsonFile -Path $ApprovalRecordPath -Label 'Approval record'

if (-not $approval.ticketId) { throw 'Approval record must include ticketId.' }
if (-not $approval.approvedBy) { throw 'Approval record must include approvedBy.' }
if (-not $approval.approvedActions) { throw 'Approval record must include approvedActions.' }

$ticketId = if ($WorkflowType -eq 'Onboarding') { $ticket.number } else { $ticket.key }
if (-not $ticketId) {
    throw "Ticket export does not include an identifier for workflow type $WorkflowType."
}
if ($ticketId -ne $approval.ticketId) {
    throw "Ticket ID mismatch: ticket export '$ticketId' does not match approval record '$($approval.ticketId)'."
}

$relatedArtifacts = @(
    foreach ($artifactPath in @($RelatedArtifactPaths | Where-Object { $_ })) {
        Get-ArtifactFingerprint -Path $artifactPath
    }
)

$packet = [pscustomobject]@{
    createdUtc       = (Get-Date).ToUniversalTime().ToString('o')
    workflowType     = $WorkflowType
    ticketId         = $ticketId
    approval         = [pscustomobject]@{
        approvedBy      = $approval.approvedBy
        approvedActions = @($approval.approvedActions)
        approvedUtc     = $approval.approvedUtc
        expiresUtc      = $approval.expiresUtc
    }
    sourceArtifacts  = [pscustomobject]@{
        ticketExport   = Get-ArtifactFingerprint -Path $TicketPath
        approvalRecord = Get-ArtifactFingerprint -Path $ApprovalRecordPath
    }
    relatedArtifacts = $relatedArtifacts
}

Ensure-OutputDirectory -Path $OutputPath
$packet | ConvertTo-Json -Depth 8 | Set-Content -Path $OutputPath -Encoding UTF8
Write-Host "Identity change packet written to $OutputPath"

if ($PassThru) {
    $packet
}
