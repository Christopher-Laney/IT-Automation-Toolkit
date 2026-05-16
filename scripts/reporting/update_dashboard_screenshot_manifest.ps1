<#
.SYNOPSIS
  Writes a refresh manifest for the committed sample dashboard screenshot.

.DESCRIPTION
  Captures the dashboard config, sanitized sample CSV hashes, and screenshot hash
  so maintainers can tell which source inputs were used when the screenshot was
  last refreshed.

.PARAMETER ConfigPath
  Dashboard config used for the screenshot.

.PARAMETER ScreenshotPath
  Screenshot file to describe.

.PARAMETER OutputPath
  JSON manifest to write.

.PARAMETER PassThru
  Return the generated manifest object after writing it.

.EXAMPLE
  .\update_dashboard_screenshot_manifest.ps1 `
    -ConfigPath .\config\dashboard_reports.sample.json `
    -ScreenshotPath .\dashboards\sample_output_screenshot.png `
    -OutputPath .\dashboards\sample_output_screenshot.manifest.json
#>

[CmdletBinding()]
param(
    [string]$ConfigPath = '.\config\dashboard_reports.sample.json',
    [string]$ScreenshotPath = '.\dashboards\sample_output_screenshot.png',
    [string]$OutputPath = '.\dashboards\sample_output_screenshot.manifest.json',
    [switch]$PassThru
)

function Get-RelativePath {
    param([string]$Path)

    $resolved = (Resolve-Path -LiteralPath $Path).Path
    $root = (Resolve-Path -LiteralPath '.').Path
    if ($resolved.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $resolved.Substring($root.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar)
    }
    return $resolved
}

function Get-FileFingerprint {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "Required file not found: $Path"
    }

    $hash = Get-FileHash -Path $Path -Algorithm SHA256
    [pscustomobject]@{
        path   = Get-RelativePath -Path $Path
        sha256 = $hash.Hash
    }
}

if (-not (Test-Path $ConfigPath)) {
    throw "Dashboard config not found: $ConfigPath"
}

$config = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json
$sampleInputs = @(
    foreach ($report in $config.reports) {
        if (-not $report.path) {
            throw 'Each dashboard report config item must include path.'
        }
        Get-FileFingerprint -Path $report.path
    }
)

$outputDirectory = Split-Path -Parent $OutputPath
if ($outputDirectory -and -not (Test-Path $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$manifest = [pscustomobject]@{
    generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    config       = Get-FileFingerprint -Path $ConfigPath
    screenshot   = Get-FileFingerprint -Path $ScreenshotPath
    sampleInputs = $sampleInputs
}

$manifest | ConvertTo-Json -Depth 6 | Set-Content -Path $OutputPath -Encoding UTF8
Write-Host "Dashboard screenshot manifest written to $OutputPath"

if ($PassThru) {
    $manifest
}
