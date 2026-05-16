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

    It 'requires temporary-password handoff path and key path together' {
        $csvPath = Join-Path $script:RepoRoot 'config/new_users.csv'

        {
            & $script:OnboardingScript `
                -UserList $csvPath `
                -TemporaryPasswordHandoffPath (Join-Path $TestDrive 'handoff.json') `
                -ValidateOnly
        } | Should -Throw '*TemporaryPasswordHandoffPath and TemporaryPasswordKeyPath must be provided together*'
    }

    It 'validates temporary-password handoff key files before Graph calls' {
        $csvPath = Join-Path $script:RepoRoot 'config/new_users.csv'
        $invalidKeyPath = Join-Path $TestDrive 'invalid.key'
        Set-Content -Path $invalidKeyPath -Value 'not-base64' -Encoding UTF8

        {
            & $script:OnboardingScript `
                -UserList $csvPath `
                -TemporaryPasswordHandoffPath (Join-Path $TestDrive 'handoff.json') `
                -TemporaryPasswordKeyPath $invalidKeyPath `
                -ValidateOnly
        } | Should -Throw '*must contain a base64-encoded AES key*'
    }

    It 'accepts valid temporary-password handoff key files during validation' {
        $csvPath = Join-Path $script:RepoRoot 'config/new_users.csv'
        $keyPath = Join-Path $TestDrive 'handoff.key'
        [Convert]::ToBase64String([byte[]](1..32)) | Set-Content -Path $keyPath -Encoding UTF8

        $output = & $script:OnboardingScript `
            -UserList $csvPath `
            -TemporaryPasswordHandoffPath (Join-Path $TestDrive 'handoff.json') `
            -TemporaryPasswordKeyPath $keyPath `
            -ValidateOnly 6>&1

        ($output | Out-String) | Should -Match 'CSV validation passed: 2 user row\(s\)'
    }
}
