<#
.SYNOPSIS
  Comprehensive software inventory for Windows with optional extras.

.DESCRIPTION
  - Collects installed software from:
      * HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall (64-bit)
      * HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall (32-bit)
      * HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall (per-user)
    (Avoids Win32_Product to prevent MSI reconfiguration.)
  - Optional: UWP/AppX, winget list, Chocolatey packages, Windows Updates.
  - Adds system metadata: ComputerName, Username, OS build, TimestampUTC.
  - Exports CSV and/or JSON. Creates directories if missing.

.PARAMETER ExportPath
  CSV file path. Default .\reports\inventory.csv

.PARAMETER JsonPath
  Optional JSON output path.

.PARAMETER IncludeAppx
  Include UWP/AppX packages.

.PARAMETER IncludeWinget
  Include packages reported by 'winget list' (if available).

.PARAMETER IncludeChoco
  Include Chocolatey packages (if choco.exe available).

.PARAMETER IncludeUpdates
  Include Windows Updates (Get-HotFix).

.PARAMETER Append
  Append to an existing CSV instead of overwriting (schema must match).

.EXAMPLE
  .\inventory_report.ps1

.EXAMPLE
  .\inventory_report.ps1 -IncludeAppx -IncludeWinget -IncludeChoco -IncludeUpdates `
    -ExportPath ".\reports\inventory.csv" -JsonPath ".\reports\inventory.json"
#>

[CmdletBinding()]
param(
  [string]$ExportPath = ".\reports\inventory.csv",
  [string]$JsonPath,
  [switch]$IncludeAppx,
  [switch]$IncludeWinget,
  [switch]$IncludeChoco,
  [switch]$IncludeUpdates,
  [switch]$Append
)

# ----------------- helpers -----------------
function Ensure-Dir([string]$Path) {
  $dir = Split-Path -Parent (Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue)
  if (-not $dir) { $dir = Split-Path -Parent $Path }
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
}

function Normalize-Date($val) {
  # Registry InstallDate often stored as yyyymmdd or yyyymm format
  if (-not $val) { return $null }
  $s = "$val".Trim()
  if ($s -match '^\d{8}$') {
    return [datetime]::ParseExact($s,'yyyyMMdd',$null).ToString('yyyy-MM-dd')
  }
  if ($s -match '^\d{6}$') {
    return [datetime]::ParseExact($s,'yyyyMM',$null).ToString('yyyy-MM')
  }
  # Sometimes already a date
  try { return ([datetime]$s).ToString('yyyy-MM-dd') } catch { return $s }
}

function Read-UninstallKey([string]$Root) {
  if (-not (Test-Path $Root)) { return @() }
  Get-ChildItem -LiteralPath $Root -ErrorAction SilentlyContinue | ForEach-Object {
    try {
      $p = Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction Stop
      [pscustomobject]@{
        Source          = 'Registry'
        HivePath        = $Root
        Name            = $p.DisplayName
        Version         = $p.DisplayVersion
        Publisher       = $p.Publisher
        InstallDate     = Normalize-Date $p.InstallDate
        UninstallString = $p.UninstallString
        InstallLocation = $p.InstallLocation
        DisplayIcon     = $p.DisplayIcon
        EstimatedSizeMB = if ($p.EstimatedSize) { [math]::Round($p.EstimatedSize/1024,2) } else { $null }
        Language        = $p.Language
        HelpLink        = $p.HelpLink
        URLInfoAbout    = $p.URLInfoAbout
        PSChildName     = $_.PSChildName
      }
    } catch { }
  } | Where-Object { $_.Name -and $_.Name.Trim() -ne '' }
}

function Get-UwpPackages {
  try {
    Get-AppxPackage | Select-Object @{
      n='Source';e={'AppX'}
    }, @{n='HivePath';e={'N/A'}}, @{n='Name';e={$_.Name}}, @{n='Version';e={$_.Version}},
       @{n='Publisher';e={$_.Publisher}}, @{n='InstallDate';e={$_.InstallLocation}},
       @{n='UninstallString';e={'appx'}}, @{n='InstallLocation';e={$_.InstallLocation}},
       @{n='DisplayIcon';e={$null}}, @{n='EstimatedSizeMB';e={$null}},
       @{n='Language';e={$null}}, @{n='HelpLink';e={$null}}, @{n='URLInfoAbout';e={$null}},
       @{n='PSChildName';e={$_.PackageFullName}}
  } catch { @() }
}

function Get-WingetPackages {
  $winget = Get-Command winget -ErrorAction SilentlyContinue
  if (-not $winget) { return @() }
  $args = @('list','--source','winget','--accept-source-agreements','--disable-interactivity')
  $raw = winget @args 2>$null
  if (-not $raw) { return @() }
  # Parse columns; winget output columns vary, but typical: Name, Id, Version, Available, Source
  $lines = $raw | Where-Object { $_ -and -not ($_ -match '^-+$') }
  $data = @()
  foreach ($ln in $lines) {
    # naive split; keeps name intact by splitting from the end
    $parts = $ln -split '\s{2,}'
    if ($parts.Count -ge 3 -and $parts[-1] -match 'winget|msstore') {
      $name = $parts[0]
      $version = $parts[2]
      $publisher = $parts[1]
      $data += [pscustomobject]@{
        Source='winget'; HivePath='N/A'
        Name=$name; Version=$version; Publisher=$publisher
        InstallDate=$null; UninstallString='winget'
        InstallLocation=$null; DisplayIcon=$null; EstimatedSizeMB=$null
        Language=$null; HelpLink=$null; URLInfoAbout=$null; PSChildName=$parts[1]
      }
    }
  }
  $data
}

function Get-ChocoPackages {
  $choco = Get-Command choco -ErrorAction SilentlyContinue
  if (-not $choco) { return @() }
  try {
    choco list --local-only --limit-output 2>$null |
      ForEach-Object {
        $n,$v = $_ -split '\|',2
        [pscustomobject]@{
          Source='choco'; HivePath='N/A'
          Name=$n; Version=$v; Publisher=$null
          InstallDate=$null; UninstallString='choco'
          InstallLocation=$null; DisplayIcon=$null; EstimatedSizeMB=$null
          Language=$null; HelpLink=$null; URLInfoAbout=$null; PSChildName=$n
        }
      }
  } catch { @() }
}

function Get-WindowsUpdates {
  try {
    Get-HotFix | Select-Object @{
      n='Source';e={'HotFix'}
    }, @{n='HivePath';e={'N/A'}}, @{n='Name';e={$_.HotFixID}}, @{n='Version';e={$_.Description}},
       @{n='Publisher';e={$_.InstalledBy}}, @{n='InstallDate';e={($_.InstalledOn).ToString('yyyy-MM-dd')}},
       @{n='UninstallString';e={$null}}, @{n='InstallLocation';e={$null}},
       @{n='DisplayIcon';e={$null}}, @{n='EstimatedSizeMB';e={$null}},
       @{n='Language';e={$null}}, @{n='HelpLink';e={$null}}, @{n='URLInfoAbout';e={$null}},
       @{n='PSChildName';e={$_.HotFixID}}
  } catch { @() }
}

# ----------------- collect -----------------
$meta = [ordered]@{
  ComputerName = $env:COMPUTERNAME
  Username     = $env:USERNAME
  OSVersion    = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue).ReleaseId
  OSBuild      = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue).CurrentBuild
  TimestampUTC = (Get-Date).ToUniversalTime().ToString('o')
}

$rows = @()

# HKLM (64-bit)
$rows += Read-UninstallKey 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
# HKLM WOW6432 (32-bit)
$rows += Read-UninstallKey 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
# HKCU (current user)
$rows += Read-UninstallKey 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'

if ($IncludeAppx)    { $rows += Get-UwpPackages }
if ($IncludeWinget)  { $rows += Get-WingetPackages }
if ($IncludeChoco)   { $rows += Get-ChocoPackages }
if ($IncludeUpdates) { $rows += Get-WindowsUpdates }

# Normalize & add metadata columns to each row
$rows = $rows | ForEach-Object {
  [pscustomobject]@{
    ComputerName    = $meta.ComputerName
    Username        = $meta.Username
    OSVersion       = $meta.OSVersion
    OSBuild         = $meta.OSBuild
    TimestampUTC    = $meta.TimestampUTC

    Source          = $_.Source
    Name            = $_.Name
    Version         = $_.Version
    Publisher       = $_.Publisher
    InstallDate     = $_.InstallDate
    UninstallString = $_.UninstallString
    InstallLocation = $_.InstallLocation
    EstimatedSizeMB = $_.EstimatedSizeMB
    DisplayIcon     = $_.DisplayIcon
    Language        = $_.Language
    HelpLink        = $_.HelpLink
    URLInfoAbout    = $_.URLInfoAbout
    KeyOrId         = $_.PSChildName
    HivePath        = $_.HivePath
  }
} | Sort-Object Name, Version

# ----------------- export -----------------
if (-not $rows) {
  Write-Host "No inventory data found."
  return
}

Ensure-Dir $ExportPath
if ($Append -and (Test-Path $ExportPath)) {
  $rows | Export-Csv -Path $ExportPath -Append -NoTypeInformation -Encoding UTF8
} else {
  $rows | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
}
Write-Host "Inventory CSV exported to $ExportPath"

if ($JsonPath) {
  Ensure-Dir $JsonPath
  $rows | ConvertTo-Json -Depth 6 | Out-File -LiteralPath $JsonPath -Encoding UTF8
  Write-Host "Inventory JSON exported to $JsonPath"
}
