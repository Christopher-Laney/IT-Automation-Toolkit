Describe 'IT baseline checks orchestration' {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent $PSScriptRoot
        $script:BaselineScript = Join-Path $script:RepoRoot 'scripts/automation/invoke_it_baseline_checks.ps1'
    }

    It 'generates a dashboard from sanitized sample data without live checks' {
        $outputPath = Join-Path $TestDrive 'sample_baseline_dashboard.html'

        Push-Location $script:RepoRoot
        try {
            $output = & $script:BaselineScript -UseSampleData -DashboardOutputPath $outputPath 6>&1 3>&1 2>&1
        } finally {
            Pop-Location
        }

        Test-Path $outputPath | Should -BeTrue
        $html = Get-Content -Raw -Path $outputPath

        $html | Should -Match 'Report Summary'
        $html | Should -Match 'System Health'
        $html | Should -Match 'Alex Rivera'
        ($output -join "`n") | Should -Match 'Sample IT audit dashboard generated from sanitized reports'
    }

    It 'keeps sample data runs separate from live compliance and ops checks' {
        {
            & $script:BaselineScript -UseSampleData -RunOps -DashboardOutputPath (Join-Path $TestDrive 'unused.html')
        } | Should -Throw 'UseSampleData cannot be combined with RunCompliance or RunOps*'
    }
}
