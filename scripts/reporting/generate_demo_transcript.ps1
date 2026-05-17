<#
.SYNOPSIS
  Generates a sanitized markdown transcript for the no-tenant demo walkthrough.

.DESCRIPTION
  Runs the safe demo commands used by docs/demo_guide.md, captures their output,
  normalizes machine-specific paths and timestamps, and writes a reusable markdown transcript.

.PARAMETER OutputPath
  Markdown file to generate.

.PARAMETER GeneratedUtcDate
  UTC date string to include in the transcript header. Defaults to the current UTC date.

.EXAMPLE
  .\scripts\reporting\generate_demo_transcript.ps1 -OutputPath .\reports\demo_transcript.md
#>

[CmdletBinding()]
param(
    [string]$OutputPath = ".\reports\demo_transcript.md",
    [string]$GeneratedUtcDate = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')
)

begin {
    $ErrorActionPreference = 'Stop'
    $repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
    $outputDir = Split-Path -Parent $OutputPath
    if ($outputDir -and -not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    function Normalize-DemoOutput {
        param([string]$Text)

        if ([string]::IsNullOrWhiteSpace($Text)) {
            return "(no output)"
        }

        $normalized = $Text.Trim()
        $normalized = $normalized -replace [regex]::Escape($repoRoot), '.'
        $normalized = $normalized -replace '\\', '/'
        $normalized = $normalized -replace '\d{8}-\d{6}', '<timestamp>'
        $normalized = $normalized -replace '\[\d{4}-\d{2}-\d{2}T[^\]]+\]', '[<timestamp>]'
        return $normalized
    }

    function Invoke-DemoStep {
        param(
            [Parameter(Mandatory=$true)][string]$Title,
            [Parameter(Mandatory=$true)][string]$Command,
            [Parameter(Mandatory=$true)][scriptblock]$ScriptBlock
        )

        $output = try {
            Push-Location $repoRoot
            & $ScriptBlock 6>&1 3>&1 2>&1 | Out-String
        } finally {
            Pop-Location
        }

        [pscustomobject]@{
            Title   = $Title
            Command = $Command
            Output  = Normalize-DemoOutput -Text $output
        }
    }
}

process {
    $steps = @(
        Invoke-DemoStep `
            -Title 'Validate Repository Syntax' `
            -Command 'Get-ChildItem .\scripts,.\tests -Recurse -Filter *.ps1 | ForEach-Object { <parser check> }' `
            -ScriptBlock {
                $errorsFound = @()
                Get-ChildItem .\scripts,.\tests -Recurse -Filter *.ps1 | ForEach-Object {
                    $tokens = $null
                    $errors = $null
                    [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors) | Out-Null
                    foreach ($err in $errors) {
                        $errorsFound += "{0}:{1}: {2}" -f $err.Extent.File, $err.Extent.StartLineNumber, $err.Message
                    }
                }
                $errorsFound
            }
        Invoke-DemoStep `
            -Title 'Validate Onboarding Input' `
            -Command '.\scripts\identity\onboarding.ps1 -UserList .\config\new_users.csv -ApprovalRecordPath .\config\approval_record.sample.json -ValidateOnly' `
            -ScriptBlock {
                & .\scripts\identity\onboarding.ps1 -UserList .\config\new_users.csv -ApprovalRecordPath .\config\approval_record.sample.json -ValidateOnly
            }
        Invoke-DemoStep `
            -Title 'Validate Intune Template' `
            -Command '.\scripts\compliance\apply_intune_policy.ps1 -Path .\config\intune_policy_template.json -ValidateOnly' `
            -ScriptBlock {
                & .\scripts\compliance\apply_intune_policy.ps1 -Path .\config\intune_policy_template.json -ValidateOnly
            }
        Invoke-DemoStep `
            -Title 'Generate Sample Dashboard' `
            -Command '.\scripts\automation\invoke_it_baseline_checks.ps1 -UseSampleData -DashboardOutputPath .\reports\sample_it_audit_dashboard.html' `
            -ScriptBlock {
                & .\scripts\automation\invoke_it_baseline_checks.ps1 -UseSampleData -DashboardOutputPath .\reports\sample_it_audit_dashboard.html
            }
        Invoke-DemoStep `
            -Title 'Preview Backup Safety' `
            -Command '.\scripts\automation\backup_automation.ps1 -SourcePath .\samples -DestinationPath .\reports\backup-demo -ExcludeExtensions ".tmp",".log" -RetentionDays 14 -WhatIf' `
            -ScriptBlock {
                & .\scripts\automation\backup_automation.ps1 `
                    -SourcePath .\samples `
                    -DestinationPath .\reports\backup-demo `
                    -ExcludeExtensions ".tmp", ".log" `
                    -RetentionDays 14 `
                    -WhatIf
            }
    )
}

end {
    $lines = @(
        '# Demo Transcript'
        ''
        'Generated from the safe no-tenant walkthrough in `docs/demo_guide.md`.'
        ''
        "Generated UTC: $GeneratedUtcDate"
        ''
    )

    foreach ($step in $steps) {
        $lines += "## $($step.Title)"
        $lines += ''
        $lines += '```powershell'
        $lines += $step.Command
        $lines += '```'
        $lines += ''
        $lines += '```text'
        $lines += $step.Output
        $lines += '```'
        $lines += ''
    }

    $lines | Out-File -FilePath $OutputPath -Encoding utf8
    Write-Host "Demo transcript saved to $OutputPath"
}
