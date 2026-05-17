Describe 'Identity change packet exporter' {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent $PSScriptRoot
        $script:PacketScript = Join-Path $script:RepoRoot 'scripts/identity/export_identity_change_packet.ps1'
    }

    It 'builds an onboarding packet with source and related artifact fingerprints' {
        $approvalPath = Join-Path $TestDrive 'approval.json'
        @'
{
  "ticketId": "RITM0012345",
  "approvedBy": "it-manager@contoso.com",
  "approvedActions": [ "LicenseAssignment" ]
}
'@ | Set-Content -Path $approvalPath -Encoding UTF8

        $relatedPath = Join-Path $TestDrive 'onboarding_from_ticket.csv'
        'DisplayName,UserPrincipalName' | Set-Content -Path $relatedPath -Encoding UTF8
        $outputPath = Join-Path $TestDrive 'identity_change_packet.json'

        Push-Location $script:RepoRoot
        try {
            $packet = & $script:PacketScript `
                -WorkflowType Onboarding `
                -TicketPath (Join-Path $script:RepoRoot 'config/servicenow_onboarding_ticket.sample.json') `
                -ApprovalRecordPath $approvalPath `
                -RelatedArtifactPaths $relatedPath `
                -OutputPath $outputPath `
                -PassThru
        } finally {
            Pop-Location
        }

        Test-Path $outputPath | Should -BeTrue
        $packet.ticketId | Should -Be 'RITM0012345'
        $packet.workflowType | Should -Be 'Onboarding'
        $packet.approval.approvedBy | Should -Be 'it-manager@contoso.com'
        $packet.relatedArtifacts.Count | Should -Be 1
        $packet.sourceArtifacts.ticketExport.sha256 | Should -Not -BeNullOrEmpty
    }

    It 'rejects mismatched ticket and approval identifiers' {
        $approvalPath = Join-Path $TestDrive 'mismatch_approval.json'
        @'
{
  "ticketId": "RITM0099999",
  "approvedBy": "it-manager@contoso.com",
  "approvedActions": [ "LicenseAssignment" ]
}
'@ | Set-Content -Path $approvalPath -Encoding UTF8

        {
            Push-Location $script:RepoRoot
            try {
                & $script:PacketScript `
                    -WorkflowType Onboarding `
                    -TicketPath (Join-Path $script:RepoRoot 'config/servicenow_onboarding_ticket.sample.json') `
                    -ApprovalRecordPath $approvalPath `
                    -OutputPath (Join-Path $TestDrive 'unused.json')
            } finally {
                Pop-Location
            }
        } | Should -Throw "*Ticket ID mismatch*"
    }
}
