Describe 'Dashboard screenshot manifest' {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent $PSScriptRoot
        $script:ManifestScript = Join-Path $script:RepoRoot 'scripts/reporting/update_dashboard_screenshot_manifest.ps1'
    }

    It 'captures the sample dashboard config, screenshot, and source CSV hashes' {
        $outputPath = Join-Path $TestDrive 'sample_output_screenshot.manifest.json'

        Push-Location $script:RepoRoot
        try {
            $manifest = & $script:ManifestScript -OutputPath $outputPath -PassThru
        } finally {
            Pop-Location
        }

        Test-Path $outputPath | Should -BeTrue
        $manifest.config.path | Should -Be 'config/dashboard_reports.sample.json'
        $manifest.screenshot.path | Should -Be 'dashboards/sample_output_screenshot.png'
        $manifest.sampleInputs.Count | Should -Be 6
        @($manifest.sampleInputs.path) | Should -Contain 'samples/reports/inactive_users.csv'
        @($manifest.sampleInputs.sha256 | Where-Object { $_ }) | Should -HaveCount 6
    }

    It 'normalizes text fingerprints across line endings' {
        $lfPath = Join-Path $TestDrive 'sample-lf.csv'
        $crlfPath = Join-Path $TestDrive 'sample-crlf.csv'
        "Header`nValue`n" | Set-Content -NoNewline -Path $lfPath
        "Header`r`nValue`r`n" | Set-Content -NoNewline -Path $crlfPath

        $configPath = Join-Path $TestDrive 'line-ending-dashboard-config.json'
        @{
            reports = @(
                @{
                    title = 'LF'
                    path  = $lfPath
                },
                @{
                    title = 'CRLF'
                    path  = $crlfPath
                }
            )
        } | ConvertTo-Json -Depth 4 | Set-Content -Path $configPath

        Push-Location $script:RepoRoot
        try {
            $manifest = & $script:ManifestScript `
                -ConfigPath $configPath `
                -OutputPath (Join-Path $TestDrive 'line-ending-manifest.json') `
                -PassThru
        } finally {
            Pop-Location
        }

        @($manifest.sampleInputs.sha256 | Select-Object -Unique) | Should -HaveCount 1
    }

    It 'rejects configs that omit report paths' {
        $configPath = Join-Path $TestDrive 'broken_dashboard_config.json'
        @{
            reports = @(
                @{
                    title = 'Broken'
                }
            )
        } | ConvertTo-Json -Depth 4 | Set-Content -Path $configPath

        {
            Push-Location $script:RepoRoot
            try {
                & $script:ManifestScript `
                    -ConfigPath $configPath `
                    -OutputPath (Join-Path $TestDrive 'unused.json')
            } finally {
                Pop-Location
            }
        } | Should -Throw '*Each dashboard report config item must include path*'
    }
}
