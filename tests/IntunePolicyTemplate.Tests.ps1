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

    It 'keeps the root template schema reference resolvable' {
        $templatePath = Join-Path $script:RepoRoot 'config/intune_policy_template.json'
        $template = Get-Content -Raw -Path $templatePath | ConvertFrom-Json
        $schemaPath = Join-Path (Split-Path -Parent $templatePath) $template.'$schema'

        Test-Path $schemaPath | Should -BeTrue
        { Get-Content -Raw -Path $schemaPath | ConvertFrom-Json } | Should -Not -Throw
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

    It 'keeps the compliance script template schema reference resolvable' {
        $templatePath = Join-Path $script:RepoRoot 'scripts/compliance/intune_policy_template.json'
        $template = Get-Content -Raw -Path $templatePath | ConvertFrom-Json
        $schemaPath = Join-Path (Split-Path -Parent $templatePath) $template.'$schema'

        Test-Path $schemaPath | Should -BeTrue
    }

    It 'validates every platform example template without connecting to Graph' {
        $examplesPath = Join-Path $script:RepoRoot 'config/intune_policy_examples'
        $examples = @(Get-ChildItem -Path $examplesPath -Filter '*.json')
        $examples | Should -HaveCount 4

        Push-Location $script:RepoRoot
        try {
            foreach ($example in $examples) {
                $output = & $script:IntuneScript -Path $example.FullName -ValidateOnly 6>&1
                ($output | Out-String) | Should -Match 'Template validation passed'
            }
        } finally {
            Pop-Location
        }
    }

    It 'allows required boolean settings to be false' {
        $templatePath = Join-Path $script:RepoRoot 'config/intune_policy_examples/macos_compliance_policy.json'

        Push-Location $script:RepoRoot
        try {
            $output = & $script:IntuneScript -Path $templatePath -ValidateOnly 6>&1
        } finally {
            Pop-Location
        }

        ($output | Out-String) | Should -Match 'Template validation passed'
    }

    It 'keeps every platform example schema reference resolvable' {
        $examplesPath = Join-Path $script:RepoRoot 'config/intune_policy_examples'
        $examples = @(Get-ChildItem -Path $examplesPath -Filter '*.json')

        foreach ($example in $examples) {
            $template = Get-Content -Raw -Path $example.FullName | ConvertFrom-Json
            $schemaPath = Join-Path $example.DirectoryName $template.'$schema'
            Test-Path $schemaPath | Should -BeTrue
        }
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
