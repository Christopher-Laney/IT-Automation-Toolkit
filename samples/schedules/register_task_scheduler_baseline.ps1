<#
.SYNOPSIS
  Registers a Windows Task Scheduler job for IT Automation Toolkit baseline checks.

.DESCRIPTION
  This sample creates a daily scheduled task that runs invoke_it_baseline_checks.ps1
  from a local repository checkout. Review the generated action and start with
  -WhatIf before registering a production task.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(Mandatory = $true)]
  [string]$RepositoryRoot,

  [string]$TaskName = 'IT Automation Toolkit Baseline',
  [string]$At = '06:00',
  [switch]$RunCompliance,
  [switch]$RunOps
)

$resolvedRoot = (Resolve-Path -Path $RepositoryRoot).Path
$baselineScript = Join-Path $resolvedRoot 'scripts/automation/invoke_it_baseline_checks.ps1'

if (-not (Test-Path $baselineScript)) {
  throw "Baseline script not found: $baselineScript"
}

$arguments = @(
  '-NoLogo',
  '-NoProfile',
  '-ExecutionPolicy',
  'Bypass',
  '-File',
  "`"$baselineScript`""
)

if ($RunCompliance) { $arguments += '-RunCompliance' }
if ($RunOps) { $arguments += '-RunOps' }
if (-not $RunCompliance -and -not $RunOps) { $arguments += '-RunCompliance' }

$action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument ($arguments -join ' ') -WorkingDirectory $resolvedRoot
$trigger = New-ScheduledTaskTrigger -Daily -At $At
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew

if ($PSCmdlet.ShouldProcess($TaskName, 'Register scheduled baseline check task')) {
  Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Description 'Runs IT Automation Toolkit baseline checks.' -Force | Out-Null
  Write-Host "Scheduled task registered: $TaskName"
}
