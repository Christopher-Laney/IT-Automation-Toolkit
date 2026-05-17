Describe 'Architecture decision records' {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent $PSScriptRoot
        $script:AdrRoot = Join-Path $script:RepoRoot 'docs/adr'
    }

    It 'ships the expected ADR set' {
        Test-Path (Join-Path $script:AdrRoot '0001-file-based-workflow-contracts.md') | Should -BeTrue
        Test-Path (Join-Path $script:AdrRoot '0002-approval-gated-identity-changes.md') | Should -BeTrue
        Test-Path (Join-Path $script:AdrRoot '0003-sanitized-sample-data-demos.md') | Should -BeTrue
    }

    It 'keeps ADRs structured with the standard headings' {
        Get-ChildItem -Path $script:AdrRoot -Filter '*.md' | ForEach-Object {
            $content = Get-Content -Raw -Path $_.FullName
            $content | Should -Match '# 000'
            $content | Should -Match '## Context'
            $content | Should -Match '## Decision'
            $content | Should -Match '## Consequences'
        }
    }
}
