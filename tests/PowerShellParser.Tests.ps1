Describe 'PowerShell script health' {
    It 'parses every PowerShell script without syntax errors' {
        $repoRoot = Split-Path -Parent $PSScriptRoot
        $scripts = Get-ChildItem -Path (Join-Path $repoRoot 'scripts') -Filter '*.ps1' -Recurse

        $parseFailures = foreach ($script in $scripts) {
            $tokens = $null
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile(
                $script.FullName,
                [ref] $tokens,
                [ref] $errors
            ) | Out-Null

            foreach ($errorRecord in $errors) {
                [pscustomobject]@{
                    File    = $script.FullName.Substring($repoRoot.Length + 1)
                    Line    = $errorRecord.Extent.StartLineNumber
                    Message = $errorRecord.Message
                }
            }
        }

        $parseFailures | Should -BeNullOrEmpty
    }
}
