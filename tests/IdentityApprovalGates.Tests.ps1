Describe 'Identity approval gates' {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent $PSScriptRoot
        $script:OnboardingScript = Join-Path $script:RepoRoot 'scripts/identity/onboarding.ps1'
        $script:OffboardingScript = Join-Path $script:RepoRoot 'scripts/identity/offboarding.ps1'
        $script:ApprovalRecordPath = Join-Path $script:RepoRoot 'config/approval_record.sample.json'
    }

    It 'requires onboarding approval for license assignment before Graph calls' {
        {
            & $script:OnboardingScript `
                -UserList (Join-Path $script:RepoRoot 'config/new_users.csv') `
                -ValidateOnly
        } | Should -Throw '*ApprovalRecordPath is required for action(s): LicenseAssignment*'
    }

    It 'accepts approved onboarding batches during validation' {
        $output = & $script:OnboardingScript `
            -UserList (Join-Path $script:RepoRoot 'config/new_users.csv') `
            -ApprovalRecordPath $script:ApprovalRecordPath `
            -ValidateOnly 6>&1

        ($output | Out-String) | Should -Match 'CSV validation passed: 2 user row\(s\)'
    }

    It 'requires privileged group approval when configured privileged groups are requested' {
        $approvalPath = Join-Path $TestDrive 'license_only_approval.json'
        @'
{
  "ticketId": "CHG-2001",
  "approvedBy": "it-manager@contoso.com",
  "approvedActions": [ "LicenseAssignment" ]
}
'@ | Set-Content -Path $approvalPath -Encoding UTF8

        {
            & $script:OnboardingScript `
                -UserList (Join-Path $script:RepoRoot 'config/new_users.csv') `
                -PrivilegedGroupNames 'All-Employees' `
                -ApprovalRecordPath $approvalPath `
                -ValidateOnly
        } | Should -Throw '*Approval record is missing approved action(s): PrivilegedGroupMembership*'
    }

    It 'requires offboarding approval before destructive action validation can pass' {
        {
            & $script:OffboardingScript `
                -UserPrincipalName 'jane.doe@contoso.com' `
                -ValidateOnly
        } | Should -Throw '*ApprovalRecordPath is required for action(s): DestructiveOffboarding*'
    }

    It 'accepts approved offboarding plans without connecting to Graph' {
        $output = & $script:OffboardingScript `
            -UserPrincipalName 'jane.doe@contoso.com' `
            -ApprovalRecordPath $script:ApprovalRecordPath `
            -ValidateOnly 6>&1

        ($output | Out-String) | Should -Match 'Approval validation passed for action\(s\): DestructiveOffboarding'
    }
}
