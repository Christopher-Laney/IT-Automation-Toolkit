Describe 'Identity change artifact exporter' {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent $PSScriptRoot
        $script:ArtifactScript = Join-Path $script:RepoRoot 'scripts/identity/export_identity_change_artifact.ps1'
    }

    It 'builds rollback-oriented entries from an onboarding report' {
        $reportPath = Join-Path $TestDrive 'onboarding_run.csv'
        $outputPath = Join-Path $TestDrive 'onboarding_change_artifact.json'
        @'
TimestampUTC,UserPrincipalName,DisplayName,Action,TempPasswordGenerated,TempPassword,LicenseStatus,LicensesAdded,GroupsRequested,GroupsAdded,UsageLocation,Notes
2026-05-16T00:00:00Z,jane.doe@example.com,Jane Doe,Created,False,,Assigned,sku-1;sku-2,All-Employees;Finance,All-Employees;Finance,US,
2026-05-16T00:01:00Z,john.smith@example.com,John Smith,ExistsUpdated,False,,Assigned,sku-3,All-Employees,All-Employees,US,
'@ | Set-Content -Path $reportPath -Encoding UTF8

        $artifact = & $script:ArtifactScript -ReportPath $reportPath -OutputPath $outputPath -PassThru

        Test-Path $outputPath | Should -BeTrue
        $artifact.summary.usersCreated | Should -Be 1
        $artifact.summary.licensesAdded | Should -Be 3
        $artifact.summary.groupsAdded | Should -Be 3
        $artifact.entries[0].rollbackCommands | Should -Contain "Remove-MgUser -UserId 'jane.doe@example.com'"
        $artifact.entries[0].rollbackCommands | Should -Contain "Set-MgUserLicense -UserId 'jane.doe@example.com' -AddLicenses @() -RemoveLicenses 'sku-1'"
        $artifact.entries[1].rollbackCommands | Should -Not -Contain "Remove-MgUser -UserId 'john.smith@example.com'"
    }

    It 'rejects onboarding reports missing required columns' {
        $reportPath = Join-Path $TestDrive 'missing_columns.csv'
        $outputPath = Join-Path $TestDrive 'unused.json'
        @'
UserPrincipalName,Action
jane.doe@example.com,Created
'@ | Set-Content -Path $reportPath -Encoding UTF8

        {
            & $script:ArtifactScript -ReportPath $reportPath -OutputPath $outputPath
        } | Should -Throw '*missing required header(s): LicensesAdded, GroupsAdded*'
    }
}
