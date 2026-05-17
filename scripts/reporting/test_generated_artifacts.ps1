<#
.SYNOPSIS
  Verifies that committed generated documentation and manifests still match their source inputs.

.DESCRIPTION
  Re-renders generated artifacts into a temporary workspace and compares the meaningful
  content against the committed copies. Timestamp-only fields are normalized so routine
  clock changes do not create false positives.

.PARAMETER OperationsMatrixPath
  Committed operations matrix markdown to verify.

.PARAMETER DemoTranscriptPath
  Committed demo transcript markdown to verify.

.PARAMETER ScreenshotManifestPath
  Committed dashboard screenshot manifest JSON to verify.

.EXAMPLE
  .\scripts\reporting\test_generated_artifacts.ps1
#>

[CmdletBinding()]
param(
    [string]$OperationsMatrixPath = '.\docs\operations_matrix.md',
    [string]$DemoTranscriptPath = '.\docs\demo_transcript.md',
    [string]$ScreenshotManifestPath = '.\dashboards\sample_output_screenshot.manifest.json'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("it-automation-generated-artifacts-{0}" -f [guid]::NewGuid().ToString('N'))
$staleArtifacts = New-Object System.Collections.Generic.List[string]

function Get-NormalizedTranscriptContent {
    param([string]$Path)

    $content = Get-Content -Raw -Path $Path
    return $content -replace 'Generated UTC: \d{4}-\d{2}-\d{2}', 'Generated UTC: <date>'
}

function Get-ManifestFingerprint {
    param([string]$Path)

    $manifest = Get-Content -Raw -Path $Path | ConvertFrom-Json
    $lines = @(
        "config|$($manifest.config.path.Replace('\', '/'))|$($manifest.config.sha256.ToUpperInvariant())"
        "screenshot|$($manifest.screenshot.path.Replace('\', '/'))|$($manifest.screenshot.sha256.ToUpperInvariant())"
    )

    foreach ($inputFile in @($manifest.sampleInputs) | Sort-Object path) {
        $lines += "sampleInput|$($inputFile.path.Replace('\', '/'))|$($inputFile.sha256.ToUpperInvariant())"
    }

    return ($lines -join "`n")
}

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

    Push-Location $repoRoot
    try {
        $generatedOperationsMatrix = Join-Path $tempRoot 'operations_matrix.md'
        & .\scripts\reporting\export_workflow_catalog.ps1 -OutputPath $generatedOperationsMatrix
        if ((Get-Content -Raw -Path $OperationsMatrixPath) -ne (Get-Content -Raw -Path $generatedOperationsMatrix)) {
            $staleArtifacts.Add($OperationsMatrixPath)
        }

        $generatedDemoTranscript = Join-Path $tempRoot 'demo_transcript.md'
        & .\scripts\reporting\generate_demo_transcript.ps1 -OutputPath $generatedDemoTranscript -GeneratedUtcDate '2000-01-01'
        if ((Get-NormalizedTranscriptContent -Path $DemoTranscriptPath) -ne (Get-NormalizedTranscriptContent -Path $generatedDemoTranscript)) {
            $staleArtifacts.Add($DemoTranscriptPath)
        }

        $generatedScreenshotManifest = Join-Path $tempRoot 'sample_output_screenshot.manifest.json'
        & .\scripts\reporting\update_dashboard_screenshot_manifest.ps1 -OutputPath $generatedScreenshotManifest
        if ((Get-ManifestFingerprint -Path $ScreenshotManifestPath) -ne (Get-ManifestFingerprint -Path $generatedScreenshotManifest)) {
            $staleArtifacts.Add($ScreenshotManifestPath)
        }
    } finally {
        Pop-Location
    }
} finally {
    if (Test-Path $tempRoot) {
        Remove-Item -Path $tempRoot -Recurse -Force
    }
}

if ($staleArtifacts.Count -gt 0) {
    throw "Generated artifact(s) are stale: $($staleArtifacts -join ', '). Refresh them before committing."
}

Write-Host 'Generated artifacts are up to date.'
