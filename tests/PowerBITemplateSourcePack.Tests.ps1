Describe 'Power BI template source pack' {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent $PSScriptRoot
        $script:PowerBiRoot = Join-Path $script:RepoRoot 'dashboards/powerbi'
    }

    It 'ships the expected template source assets' {
        Test-Path (Join-Path $script:PowerBiRoot 'power_query_sample.m') | Should -BeTrue
        Test-Path (Join-Path $script:PowerBiRoot 'measures.dax') | Should -BeTrue
        Test-Path (Join-Path $script:PowerBiRoot 'theme.json') | Should -BeTrue
        Test-Path (Join-Path $script:PowerBiRoot 'template_build_spec.json') | Should -BeTrue
    }

    It 'describes the expected source tables and report pages' {
        $spec = Get-Content -Raw -Path (Join-Path $script:PowerBiRoot 'template_build_spec.json') | ConvertFrom-Json

        @($spec.expectedTables) | Should -Be @(
            'InactiveUsers',
            'LocalAdmins',
            'IntuneCompliance',
            'M365LicenseAudit',
            'SslExpiry',
            'SystemHealth'
        )
        @($spec.recommendedPages) | Should -Be @(
            'Executive Overview',
            'Identity Risk',
            'Device And Compliance',
            'License And Certificate Operations'
        )
    }

    It 'uses a diversified visual palette rather than a single-hue theme' {
        $theme = Get-Content -Raw -Path (Join-Path $script:PowerBiRoot 'theme.json') | ConvertFrom-Json

        @($theme.dataColors).Count | Should -BeGreaterThan 4
        @($theme.dataColors | Select-Object -Unique).Count | Should -Be @($theme.dataColors).Count
    }
}
