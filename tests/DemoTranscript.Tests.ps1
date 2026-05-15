Describe 'Demo transcript generation' {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent $PSScriptRoot
        $script:TranscriptScript = Join-Path $script:RepoRoot 'scripts/reporting/generate_demo_transcript.ps1'
    }

    It 'generates a sanitized walkthrough transcript' {
        $outputPath = Join-Path $TestDrive 'demo_transcript.md'

        Push-Location $script:RepoRoot
        try {
            & $script:TranscriptScript -OutputPath $outputPath
        } finally {
            Pop-Location
        }

        Test-Path $outputPath | Should -BeTrue
        $content = Get-Content -Raw -Path $outputPath

        $content | Should -Match '# Demo Transcript'
        $content | Should -Match 'Validate Onboarding Input'
        $content | Should -Match 'CSV validation passed: 2 user row\(s\)\.'
        $content | Should -Match 'Validate Intune Template'
        $content | Should -Match 'Sample IT audit dashboard generated from sanitized reports'
        $content | Should -Match 'Backup preview complete'
        $content | Should -Match '\(no output\)'
        $content | Should -Not -Match [regex]::Escape($script:RepoRoot)
    }
}
