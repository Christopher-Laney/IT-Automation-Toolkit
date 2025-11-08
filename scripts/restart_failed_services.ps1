<#
.SYNOPSIS
  Detect and restart failed/stopped Automatic services, with logging and retries.

.DESCRIPTION
  Scans local or remote Windows host(s) for services where StartType is Automatic
  but status is not Running. Attempts restart with exponential backoff and logs
  the outcome. Optionally ignores known-problematic services via -Exclude.

.PARAMETER ComputerName
  Single host or list of hosts. Default: localhost.

.PARAMETER Exclude
  Array of service names to skip (e.g., 'Fax','SharedAccess').

.PARAMETER MaxRetries
  Number of restart attempts. Default: 3.

.PARAMETER ReportPath
  CSV path for action log.

.EXAMPLE
  .\restart_failed_services.ps1 -ComputerName server01,server02 -Exclude 'Spooler' -ReportPath .\reports\services_fix.csv
#>

[CmdletBinding(SupportsShouldProcess)]
param(
  [Parameter(ValueFromPipeline=$true)]
  [string[]]$ComputerName = @($env:COMPUTERNAME),

  [string[]]$Exclude = @(),

  [int]$MaxRetries = 3,

  [string]$ReportPath = ".\reports\restart_failed_services.csv"
)

begin {
  $ErrorActionPreference = 'Stop'
  $null = New-Item -ItemType Directory -Path (Split-Path $ReportPath) -Force -ErrorAction SilentlyContinue
  $log = New-Object System.Collections.Generic.List[object]
}

process {
  foreach ($c in $ComputerName) {
    Write-Verbose "Scanning $c for failed/automatic services..."
    try {
      $services = Get-Service -ComputerName $c | Where-Object {
        $_.StartType -eq 'Automatic' -and $_.Status -ne 'Running'
      } | Where-Object { $Exclude -notcontains $_.Name }

      foreach ($svc in $services) {
        $attempt = 0
        $final = 'Unchanged'
        $msg = ''

        if ($PSCmdlet.ShouldProcess("$c::$($svc.Name)", "Restart service")) {
          while ($attempt -lt $MaxRetries) {
            $attempt++
            try {
              Write-Verbose "[$c] Restarting $($svc.Name) (attempt $attempt/$MaxRetries)..."
              Start-Service -InputObject $svc -ErrorAction Stop
              Start-Sleep -Seconds ([math]::Pow(2,$attempt - 1))  # backoff
              $svc.Refresh()
              if ($svc.Status -eq 'Running') {
                $final = 'Restarted'
                break
              } else {
                $msg = "Status: $($svc.Status)"
              }
            }
            catch {
              $msg = $_.Exception.Message
              Start-Sleep -Seconds ([math]::Pow(2,$attempt - 1))
            }
          }
          if ($final -ne 'Restarted') { $final = 'Failed' }
        } else {
          $final = 'WhatIf'
        }

        $log.Add([pscustomobject]@{
          ComputerName = $c
          ServiceName  = $svc.Name
          DisplayName  = $svc.DisplayName
          StartType    = $svc.StartType
          OriginalStatus = $svc.Status
          Result       = $final
          Message      = $msg
          Attempts     = $attempt
          Timestamp    = (Get-Date)
        })
      }
    }
    catch {
      $log.Add([pscustomobject]@{
        ComputerName = $c
        ServiceName  = ''
        DisplayName  = ''
        StartType    = ''
        OriginalStatus = ''
        Result       = 'Error'
        Message      = $_.Exception.Message
        Attempts     = 0
        Timestamp    = (Get-Date)
      })
    }
  }
}

end {
  $log | Export-Csv -NoTypeInformation -Path $ReportPath
  Write-Host "Service restart log saved to $ReportPath"
}
