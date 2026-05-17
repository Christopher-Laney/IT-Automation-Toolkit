<#
.SYNOPSIS
  Renders the workflow catalog JSON into a markdown operations matrix.

.PARAMETER CatalogPath
  Path to the workflow catalog JSON.

.PARAMETER OutputPath
  Markdown file to generate.

.EXAMPLE
  .\export_workflow_catalog.ps1 `
    -CatalogPath .\config\workflow_catalog.json `
    -OutputPath .\docs\operations_matrix.md
#>

[CmdletBinding()]
param(
    [string]$CatalogPath = '.\config\workflow_catalog.json',
    [string]$OutputPath = '.\docs\operations_matrix.md'
)

if (-not (Test-Path $CatalogPath)) {
    throw "Workflow catalog not found: $CatalogPath"
}

$catalog = Get-Content -Raw -Path $CatalogPath | ConvertFrom-Json
$rows = @($catalog.workflows)
if (-not $rows) {
    throw 'Workflow catalog contains no workflows.'
}

$requiredFields = @('name', 'category', 'trigger', 'inputs', 'outputs', 'evidence', 'safeFirstRun')
foreach ($workflow in $rows) {
    $missing = $requiredFields | Where-Object { -not $workflow.$_ }
    if ($missing) {
        throw "Workflow '$($workflow.name)' is missing required field(s): $($missing -join ', ')."
    }
}

$lines = @(
    '# Operations Matrix',
    '',
    'This matrix summarizes the main workflows, what starts them, what they consume, what they produce, and the safest first command to run.',
    '',
    '| Workflow | Category | Trigger | Inputs | Outputs | Evidence | Safe First Run |',
    '|---|---|---|---|---|---|---|'
)

foreach ($workflow in $rows) {
    $lines += "| $($workflow.name) | $($workflow.category) | $($workflow.trigger) | $($workflow.inputs) | $($workflow.outputs) | $($workflow.evidence) | ``$($workflow.safeFirstRun)`` |"
}

$lines += @(
    '',
    'Use this page with `docs/scheduling.md` when deciding which workflows should remain operator-driven and which are safe to schedule.'
)

$directory = Split-Path -Parent $OutputPath
if ($directory -and -not (Test-Path $directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}

$lines | Set-Content -Path $OutputPath -Encoding UTF8
Write-Host "Workflow operations matrix written to $OutputPath"
