Describe 'Onboarding CSV validation' {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent $PSScriptRoot
        $script:OnboardingScript = Join-Path $script:RepoRoot 'scripts/identity/onboarding.ps1'
    }

    It 'validates the sample onboarding CSV without connecting to Graph' {
        $csvPath = Join-Path $script:RepoRoot 'config/new_users.csv'

        Push-Location $script:RepoRoot
        try {
            $output = & $script:OnboardingScript -UserList $csvPath -ValidateOnly 6>&1
        } finally {
            Pop-Location
        }

        ($output | Out-String) | Should -Match 'CSV validation passed: 2 user row\(s\)'
    }

    It 'rejects onboarding CSV files missing required headers before Graph calls' {
        $csvPath = Join-Path $TestDrive 'missing_headers.csv'
        @'
DisplayName,UserPrincipalName,UsageLocation,Groups
Jane Doe,jane.doe@contoso.com,US,All-Employees
'@ | Set-Content -Path $csvPath -Encoding UTF8

        {
            & $script:OnboardingScript -UserList $csvPath -ValidateOnly
        } | Should -Throw -ExpectedMessage '*CSV is missing required header(s): LicenseSku*'
    }

    It 'rejects invalid onboarding rows before Graph calls' {
        $csvPath = Join-Path $TestDrive 'invalid_rows.csv'
        @'
DisplayName,UserPrincipalName,UsageLocation,LicenseSku,Groups
Jane Doe,jane.doe,US,ENTERPRISEPACK,All-Employees
'@ | Set-Content -Path $csvPath -Encoding UTF8

        {
            & $script:OnboardingScript -UserList $csvPath -ValidateOnly
        } | Should -Throw -ExpectedMessage '*CSV row 2 failed validation*UserPrincipalName is not a valid email-style UPN*'
    }

    It 'uses DefaultUsageLocation when row usage location is blank' {
        $csvPath = Join-Path $TestDrive 'default_usage_location.csv'
        @'
DisplayName,UserPrincipalName,UsageLocation,LicenseSku,Groups
Jane Doe,jane.doe@contoso.com,,ENTERPRISEPACK,All-Employees
'@ | Set-Content -Path $csvPath -Encoding UTF8

        $output = & $script:OnboardingScript -UserList $csvPath -DefaultUsageLocation US -ValidateOnly 6>&1

        ($output | Out-String) | Should -Match 'CSV validation passed: 1 user row\(s\)'
    }
}
