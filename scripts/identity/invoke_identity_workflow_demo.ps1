<#
.SYNOPSIS
  Runs a no-tenant identity workflow demo from sanitized sample inputs.

.DESCRIPTION
  Demonstrates ticket intake, approval validation, onboarding CSV generation,
  and review-packet export without connecting to Microsoft Graph.

.PARAMETER OutputDirectory
  Directory where demo artifacts will be written.

.PARAMETER PassThru
  Return a summary object after the demo completes.

.EXAMPLE
  .\invoke_identity_workflow_demo.ps1 -OutputDirectory .\reports\identity-demo
#>

[CmdletBinding()]
param(
    [string]$OutputDirectory = '.\reports\identity-demo',
    [switch]$PassThru
)

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$ticketPath = Join-Path $repoRoot 'config/servicenow_onboarding_ticket.sample.json'
$approvalPath = Join-Path $repoRoot 'config/servicenow_onboarding_approval.sample.json'
$converterScript = Join-Path $PSScriptRoot 'convert_identity_ticket.ps1'
$onboardingScript = Join-Path $PSScriptRoot 'onboarding.ps1'
$packetScript = Join-Path $PSScriptRoot 'export_identity_change_packet.ps1'

if (-not (Test-Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

$onboardingCsvPath = Join-Path $OutputDirectory 'onboarding_from_ticket.csv'
$packetPath = Join-Path $OutputDirectory 'identity_change_packet.json'

& $converterScript `
    -Provider ServiceNow `
    -Path $ticketPath `
    -OutputPath $onboardingCsvPath

& $onboardingScript `
    -UserList $onboardingCsvPath `
    -ApprovalRecordPath $approvalPath `
    -ValidateOnly

& $packetScript `
    -WorkflowType Onboarding `
    -TicketPath $ticketPath `
    -ApprovalRecordPath $approvalPath `
    -RelatedArtifactPaths $onboardingCsvPath `
    -OutputPath $packetPath

$summary = [pscustomobject]@{
    ticketPath        = $ticketPath
    approvalPath      = $approvalPath
    onboardingCsvPath = $onboardingCsvPath
    packetPath        = $packetPath
}

Write-Host 'Identity workflow demo complete.'
Write-Host "  Onboarding CSV: $onboardingCsvPath"
Write-Host "  Change packet:  $packetPath"

if ($PassThru) {
    $summary
}
