Describe 'Identity ticket intake converter' {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent $PSScriptRoot
        $script:ConverterScript = Join-Path $script:RepoRoot 'scripts/identity/convert_identity_ticket.ps1'
    }

    It 'converts a ServiceNow onboarding export into an onboarding CSV' {
        $outputPath = Join-Path $TestDrive 'onboarding_from_ticket.csv'

        $artifact = & $script:ConverterScript `
            -Provider ServiceNow `
            -Path (Join-Path $script:RepoRoot 'config/servicenow_onboarding_ticket.sample.json') `
            -OutputPath $outputPath `
            -PassThru

        Test-Path $outputPath | Should -BeTrue
        $row = Import-Csv -Path $outputPath
        $row.UserPrincipalName | Should -Be 'jane.doe@contoso.com'
        $row.LicenseSku | Should -Be 'ENTERPRISEPACK;POWER_BI_PRO'
        $artifact.TicketId | Should -Be 'RITM0012345'
    }

    It 'converts a Jira offboarding export into a reviewed plan JSON' {
        $outputPath = Join-Path $TestDrive 'offboarding_plan.json'

        $artifact = & $script:ConverterScript `
            -Provider Jira `
            -Path (Join-Path $script:RepoRoot 'config/jira_offboarding_ticket.sample.json') `
            -OutputPath $outputPath `
            -PassThru

        Test-Path $outputPath | Should -BeTrue
        $plan = Get-Content -Raw -Path $outputPath | ConvertFrom-Json
        $plan.ticketId | Should -Be 'IT-204'
        $plan.userPrincipalName | Should -Be 'john.smith@contoso.com'
        $plan.removeLicenses | Should -BeTrue
        $artifact.transferOneDriveTo | Should -Be 'manager@contoso.com'
    }

    It 'rejects ServiceNow exports missing required fields' {
        $ticketPath = Join-Path $TestDrive 'invalid_servicenow.json'
        @'
{
  "number": "RITM0099999",
  "u_request_type": "Onboarding",
  "requested_for": {
    "name": "Jane Doe"
  }
}
'@ | Set-Content -Path $ticketPath -Encoding UTF8

        {
            & $script:ConverterScript `
                -Provider ServiceNow `
                -Path $ticketPath `
                -OutputPath (Join-Path $TestDrive 'unused.csv')
        } | Should -Throw '*missing required field(s): UserPrincipalName, UsageLocation*'
    }

    It 'rejects unsupported Jira request types' {
        $ticketPath = Join-Path $TestDrive 'invalid_jira.json'
        @'
{
  "key": "IT-999",
  "fields": {
    "customfield_request_type": "Onboarding",
    "customfield_user_upn": "jane.doe@contoso.com"
  }
}
'@ | Set-Content -Path $ticketPath -Encoding UTF8

        {
            & $script:ConverterScript `
                -Provider Jira `
                -Path $ticketPath `
                -OutputPath (Join-Path $TestDrive 'unused.json')
        } | Should -Throw '*Unsupported Jira request type: Onboarding*'
    }
}
