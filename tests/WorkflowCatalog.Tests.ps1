Describe 'Workflow catalog' {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent $PSScriptRoot
        $script:CatalogPath = Join-Path $script:RepoRoot 'config/workflow_catalog.json'
        $script:ExportScript = Join-Path $script:RepoRoot 'scripts/reporting/export_workflow_catalog.ps1'
    }

    It 'contains the expected major workflows' {
        $catalog = Get-Content -Raw -Path $script:CatalogPath | ConvertFrom-Json
        $names = @($catalog.workflows.name)

        $names | Should -Contain 'Identity workflow demo'
        $names | Should -Contain 'Onboarding batch'
        $names | Should -Contain 'Offboarding plan'
        $names | Should -Contain 'Baseline reporting'
        $names | Should -Contain 'Intune policy deployment'
        $names | Should -Contain 'Backup and restore'
    }

    It 'renders a markdown operations matrix' {
        $outputPath = Join-Path $TestDrive 'operations_matrix.md'

        Push-Location $script:RepoRoot
        try {
            & $script:ExportScript -OutputPath $outputPath
        } finally {
            Pop-Location
        }

        $content = Get-Content -Raw -Path $outputPath
        $content | Should -Match '# Operations Matrix'
        $content | Should -Match 'Identity workflow demo'
        $content | Should -Match 'Safe First Run'
    }
}
