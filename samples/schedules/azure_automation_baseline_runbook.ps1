<#
.SYNOPSIS
  Azure Automation runbook starter for IT Automation Toolkit baseline checks.

.DESCRIPTION
  Import this sample as a PowerShell runbook. It expects the toolkit to be
  available on the runbook worker. Use a Hybrid Runbook Worker for local server
  checks, file shares, or Windows-only dependencies.
#>

param(
  [string]$RepositoryRoot = (Get-AutomationVariable -Name 'RepositoryRoot'),
  [bool]$RunCompliance = [bool](Get-AutomationVariable -Name 'RunCompliance'),
  [bool]$RunOps = [bool](Get-AutomationVariable -Name 'RunOps')
)

if (-not $RepositoryRoot) {
  throw "Automation variable 'RepositoryRoot' is required."
}

$baselineScript = Join-Path $RepositoryRoot 'scripts/automation/invoke_it_baseline_checks.ps1'
if (-not (Test-Path $baselineScript)) {
  throw "Baseline script not found: $baselineScript"
}

$arguments = @{}
if ($RunCompliance) { $arguments.RunCompliance = $true }
if ($RunOps) { $arguments.RunOps = $true }
if (-not $RunCompliance -and -not $RunOps) { $arguments.RunCompliance = $true }

Push-Location $RepositoryRoot
try {
  & $baselineScript @arguments
} finally {
  Pop-Location
}
