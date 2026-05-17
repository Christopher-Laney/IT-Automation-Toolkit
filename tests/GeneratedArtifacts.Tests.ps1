Describe 'Generated artifact verification' {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent $PSScriptRoot
        $script:VerifierScript = Join-Path $script:RepoRoot 'scripts/reporting/test_generated_artifacts.ps1'
        $script:OperationsMatrixPath = Join-Path $script:RepoRoot 'docs/operations_matrix.md'
        $script:DemoTranscriptPath = Join-Path $script:RepoRoot 'docs/demo_transcript.md'
        $script:ScreenshotManifestPath = Join-Path $script:RepoRoot 'dashboards/sample_output_screenshot.manifest.json'
    }

    It 'accepts the committed generated artifacts' {
        {
            Push-Location $script:RepoRoot
            try {
                & $script:VerifierScript
            } finally {
                Pop-Location
            }
        } | Should -Not -Throw
    }

    It 'rejects a stale generated artifact' {
        $staleOperationsMatrixPath = Join-Path $TestDrive 'operations_matrix.md'
        Copy-Item -Path $script:OperationsMatrixPath -Destination $staleOperationsMatrixPath
        Add-Content -Path $staleOperationsMatrixPath -Value 'stale'

        {
            Push-Location $script:RepoRoot
            try {
                & $script:VerifierScript `
                    -OperationsMatrixPath $staleOperationsMatrixPath `
                    -DemoTranscriptPath $script:DemoTranscriptPath `
                    -ScreenshotManifestPath $script:ScreenshotManifestPath
            } finally {
                Pop-Location
            }
        } | Should -Throw '*Generated artifact(s) are stale*'
    }
}
