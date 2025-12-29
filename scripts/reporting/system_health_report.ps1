<#
.SYNOPSIS
  System health snapshot across Windows hosts (CPU, Memory, Disk).

.DESCRIPTION
  Uses CIM/WMI to query a list of computers and generates a health report.
  Optionally builds a simple HTML summary.

.PARAMETER ComputerList
  Path to a text file with one hostname per line, or an array of names.

.PARAMETER ExportCsv
  CSV path for the raw report.

.PARAMETER ExportHtml
  Optional HTML path for a human-friendly view.

.PARAMETER TimeoutSec
  CIM timeout per host. Default: 5

.EXAMPLE
  .\system_health_report.ps1 -ComputerList .\config\servers.txt -ExportCsv .\reports\health.csv -ExportHtml .\reports\health.html
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [Alias('Computers')]
  [object]$ComputerList,

  [string]$ExportCsv = ".\reports\system_health.csv",

  [string]$ExportHtml,

  [int]$TimeoutSec = 5
)

begin {
  $ErrorActionPreference = 'Stop'
  $null = New-Item -ItemType Directory -Path (Split-Path $ExportCsv) -Force -ErrorAction SilentlyContinue

  if ($ComputerList -is [string] -and (Test-Path $ComputerList)) {
    $computers = Get-Content -Path $ComputerList | Where-Object { $_ -and $_.Trim() -ne '' } | Select-Object -Unique
  } elseif ($ComputerList -is [System.Collections.IEnumerable]) {
    $computers = $ComputerList
  } else {
    throw "ComputerList must be a path to a file or an array of hostnames."
  }

  $results = New-Object System.Collections.Generic.List[object]
}

process {
  foreach ($c in $computers) {
    Write-Verbose "Querying $c ..."
    try {
      $opt = New-CimSessionOption -Protocol DCOM
      $sess = New-CimSession -ComputerName $c -SessionOption $opt -OperationTimeoutSec $TimeoutSec

      $os   = Get-CimInstance -CimSession $sess -ClassName Win32_OperatingSystem
      $cs   = Get-CimInstance -CimSession $sess -ClassName Win32_ComputerSystem
      $disks= Get-CimInstance -CimSession $sess -ClassName Win32_LogicalDisk -Filter "DriveType=3"

      $memTotalGB = [math]::Round($cs.TotalPhysicalMemory/1GB,2)
      $memFreeGB  = [math]::Round($os.FreePhysicalMemory/1MB,2)
      $memUsedPct = if ($memTotalGB -gt 0) { [math]::Round((($memTotalGB - $memFreeGB)/$memTotalGB)*100,2) } else { 0 }

      $diskInfo = ($disks | ForEach-Object {
        $sizeGB = [math]::Round($_.Size/1GB,2)
        $freeGB = [math]::Round($_.FreeSpace/1GB,2)
        $usedPct = if ($sizeGB -gt 0) { [math]::Round((($sizeGB - $freeGB)/$sizeGB)*100,2) } else { 0 }
        "{0}:{1}GB total/{2}GB free ({3}% used)" -f $_.DeviceID,$sizeGB,$freeGB,$usedPct
      }) -join " | "

      # Quick CPU sample via WMI class (Processor load); for more accurate use perf counters sampled over time.
      $cpuLoads = Get-CimInstance -CimSession $sess -ClassName Win32_Processor | Select-Object -ExpandProperty LoadPercentage
      $cpuAvg   = if ($cpuLoads) { [math]::Round(($cpuLoads | Measure-Object -Average).Average,2) } else { 0 }

      $results.Add([pscustomobject]@{
        ComputerName = $c
        OS           = $os.Caption
        LastBoot     = $os.LastBootUpTime
        CPU_LoadPct  = $cpuAvg
        Mem_TotalGB  = $memTotalGB
        Mem_UsedPct  = $memUsedPct
        Disks        = $diskInfo
        Timestamp    = (Get-Date)
      })
      Remove-CimSession -CimSession $sess
    }
    catch {
      $results.Add([pscustomobject]@{
        ComputerName = $c
        OS           = $null
        LastBoot     = $null
        CPU_LoadPct  = $null
        Mem_TotalGB  = $null
        Mem_UsedPct  = $null
        Disks        = "ERROR: $($_.Exception.Message)"
        Timestamp    = (Get-Date)
      })
    }
  }

  $results | Export-Csv -NoTypeInformation -Path $ExportCsv
  Write-Host "Health report saved to $ExportCsv"

  if ($ExportHtml) {
    $html = $results | ConvertTo-Html -Title "System Health Report" -PreContent "<h2>System Health Report</h2><p>$(Get-Date)</p>"
    $html | Out-File -FilePath $ExportHtml -Encoding UTF8
    Write-Host "HTML summary saved to $ExportHtml"
  }
}
