Describe 'Identity workflow demo' {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent $PSScriptRoot
        $script:DemoScript = Join-Path $script:RepoRoot 'scripts/identity/invoke_identity_workflow_demo.ps1'
    }

    It 'runs a no-tenant onboarding workflow and writes demo artifacts' {
        $outputDirectory = Join-Path $TestDrive 'identity-demo'

        Push-Location $script:RepoRoot
        try {
            $summary = & $script:DemoScript -OutputDirectory $outputDirectory -PassThru 6>&1
        } finally {
            Pop-Location
        }

        Test-Path (Join-Path $outputDirectory 'onboarding_from_ticket.csv') | Should -BeTrue
        Test-Path (Join-Path $outputDirectory 'identity_change_packet.json') | Should -BeTrue
        ($summary | Out-String) | Should -Match 'Identity workflow demo complete'

        $packet = Get-Content -Raw -Path (Join-Path $outputDirectory 'identity_change_packet.json') | ConvertFrom-Json
        $packet.ticketId | Should -Be 'RITM0012345'
        $packet.relatedArtifacts.Count | Should -Be 1
    }
}
