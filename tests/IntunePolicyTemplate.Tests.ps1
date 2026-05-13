Describe 'Intune policy template validation' {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent $PSScriptRoot
        $script:IntuneScript = Join-Path $script:RepoRoot 'scripts/compliance/apply_intune_policy.ps1'
    }

    It 'validates the root Intune policy template without connecting to Graph' {
        $templatePath = Join-Path $script:RepoRoot 'config/intune_policy_template.json'

        Push-Location $script:RepoRoot
        try {
            $output = & $script:IntuneScript -Path $templatePath -ValidateOnly 6>&1
        } finally {
            Pop-Location
        }

        ($output | Out-String) | Should -Match 'Template validation passed'
    }

    It 'validates the compliance script template without connecting to Graph' {
        $templatePath = Join-Path $script:RepoRoot 'scripts/compliance/intune_policy_template.json'

        Push-Location $script:RepoRoot
        try {
            $output = & $script:IntuneScript -Path $templatePath -ValidateOnly 6>&1
        } finally {
            Pop-Location
        }

        ($output | Out-String) | Should -Match 'Template validation passed'
    }

    It 'rejects unsupported platforms before connecting to Graph' {
        $templatePath = Join-Path $script:RepoRoot 'config/intune_policy_template.json'
        $invalidTemplate = Get-Content -Raw -Path $templatePath | ConvertFrom-Json -AsHashtable
        $invalidTemplate.platforms = @('Windows95')
        $invalidPath = Join-Path $TestDrive 'invalid_intune_policy_template.json'
        $invalidTemplate | ConvertTo-Json -Depth 10 | Set-Content -Path $invalidPath -Encoding UTF8

        Push-Location $script:RepoRoot
        try {
            { & $script:IntuneScript -Path $invalidPath -ValidateOnly } |
                Should -Throw -ExpectedMessage "*Unsupported platform 'Windows95'*"
        } finally {
            Pop-Location
        }
    }
}
