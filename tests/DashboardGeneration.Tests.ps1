Describe 'IT audit dashboard generation' {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent $PSScriptRoot
        $script:DashboardScript = Join-Path $script:RepoRoot 'scripts/reporting/generate_it_audit_dashboard.ps1'
    }

    It 'generates a complete dashboard from the sample report config' {
        $configPath = Join-Path $script:RepoRoot 'config/dashboard_reports.sample.json'
        $outputPath = Join-Path $TestDrive 'sample_dashboard.html'

        Push-Location $script:RepoRoot
        try {
            & $script:DashboardScript -ConfigPath $configPath -OutputPath $outputPath -MaxRows 10
        } finally {
            Pop-Location
        }

        Test-Path $outputPath | Should -BeTrue
        $html = Get-Content -Raw -Path $outputPath

        $html | Should -Match 'Report Summary'
        $html | Should -Match '<h2>Missing Reports</h2><p>None\.</p>'
        $html | Should -Match 'Alex Rivera'
        $html | Should -Match 'ENTERPRISEPACK'
        $html | Should -Match 'System Health'
    }

    It 'uses explicit report mappings and reports missing CSV files' {
        $csvPath = Join-Path $TestDrive 'custom_report.csv'
        @(
            [pscustomobject]@{
                Name = 'Casey Morgan'
                Status = 'Ready'
            }
        ) | Export-Csv -Path $csvPath -NoTypeInformation

        $missingPath = Join-Path $TestDrive 'missing_report.csv'
        $outputPath = Join-Path $TestDrive 'explicit_dashboard.html'
        $reports = @{
            'Only Report' = $csvPath
            'Missing Report' = $missingPath
        }

        Push-Location $script:RepoRoot
        try {
            & $script:DashboardScript -Reports $reports -OutputPath $outputPath
        } finally {
            Pop-Location
        }

        Test-Path $outputPath | Should -BeTrue
        $html = Get-Content -Raw -Path $outputPath

        $html | Should -Match 'Only Report'
        $html | Should -Match 'Casey Morgan'
        $html | Should -Match 'Missing Report'
        $html | Should -Match ([regex]::Escape($missingPath))
    }

    It 'normalizes configured report columns and rejects schema drift' {
        $csvPath = Join-Path $TestDrive 'unordered_report.csv'
        @(
            [pscustomobject]@{
                Status = 'Ready'
                Name   = 'Casey Morgan'
                Extra  = 'Ignore me'
            }
        ) | Export-Csv -Path $csvPath -NoTypeInformation

        $configPath = Join-Path $TestDrive 'dashboard_config.json'
        @{
            reports = @(
                @{
                    title   = 'Normalized Report'
                    path    = $csvPath
                    columns = @('Name', 'Status')
                }
            )
        } | ConvertTo-Json -Depth 5 | Set-Content -Path $configPath

        $outputPath = Join-Path $TestDrive 'normalized_dashboard.html'

        Push-Location $script:RepoRoot
        try {
            & $script:DashboardScript -ConfigPath $configPath -OutputPath $outputPath
        } finally {
            Pop-Location
        }

        $html = Get-Content -Raw -Path $outputPath
        $html.IndexOf('<th>Name</th>') | Should -BeLessThan $html.IndexOf('<th>Status</th>')
        $html | Should -Not -Match '<th>Extra</th>'

        @{
            reports = @(
                @{
                    title   = 'Broken Report'
                    path    = $csvPath
                    columns = @('Name', 'MissingColumn')
                }
            )
        } | ConvertTo-Json -Depth 5 | Set-Content -Path $configPath

        {
            Push-Location $script:RepoRoot
            try {
                & $script:DashboardScript -ConfigPath $configPath -OutputPath $outputPath
            } finally {
                Pop-Location
            }
        } | Should -Throw "*Report 'Broken Report' is missing required column(s): MissingColumn*"

        $emptyCsvPath = Join-Path $TestDrive 'empty_report.csv'
        'Name,Status' | Set-Content -Path $emptyCsvPath
        @{
            reports = @(
                @{
                    title   = 'Empty Report'
                    path    = $emptyCsvPath
                    columns = @('Name', 'Status')
                }
            )
        } | ConvertTo-Json -Depth 5 | Set-Content -Path $configPath

        {
            Push-Location $script:RepoRoot
            try {
                & $script:DashboardScript -ConfigPath $configPath -OutputPath $outputPath
            } finally {
                Pop-Location
            }
        } | Should -Not -Throw
    }
}
