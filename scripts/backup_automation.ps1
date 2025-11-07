<#
.SYNOPSIS
  Scheduled backup with logging, retention, exclusions, integrity manifest,
  optional AES-256 encryption, optional Azure Blob upload, and webhook notify.

.DESCRIPTION
  - Zips a source directory to timestamped archive(s).
  - Writes SHA256 + file count/size manifest.
  - Deletes old backups by age.
  - Optional AES-256 encrypts the ZIP to .enc using a 32-byte key file.
  - Optional upload to Azure Blob Storage.
  - Optional Teams/Slack-style webhook notification.
  - Supports -WhatIf for dry runs.

.REQUIREMENTS
  PowerShell 7+ recommended (Windows PowerShell works too).
  For Azure upload: Az.Storage (or Az module meta) installed and logged in OR use Connection String.

.PARAMETERS
  -SourcePath            Path to folder you want to back up.
  -DestinationPath       Folder where backups will be written.
  -RetentionDays         Delete backups older than this (default 30).
  -ExcludeDirs           Folder names to exclude (exact or wildcard).
  -ExcludeExtensions     File extensions to exclude (e.g. ".tmp",".log").
  -LogPath               Log file (default: ./logs/backup_automation.log relative to Destination).
  -EncryptKeyFile        Path to a 32-byte key file (raw 32 bytes or base64). If provided -> write .enc.
  -AzureConnectionString Azure Storage connection string (optional).
  -AzureContainer        Azure Blob container name (required if uploading).
  -WebhookUrl            Teams/Slack-compatible webhook URL for a JSON POST notify (optional).
  -Tag                   Optional tag added to archive filename (e.g. "sharepoint" -> backup-YYYYMMDD-HHMMSS-sharepoint.zip).
  -WhatIf                Dry-run.

.EXAMPLES
  .\backup_automation.ps1 -SourcePath "D:\Data" -DestinationPath "E:\Backups" -ExcludeExtensions ".tmp",".log" -RetentionDays 14 -WhatIf
  .\backup_automation.ps1 -SourcePath "D:\Data" -DestinationPath "E:\Backups" -EncryptKeyFile "C:\Keys\bk.key" -WebhookUrl "https://hooks.slack.com/..." 
  .\backup_automation.ps1 -SourcePath "D:\Data" -DestinationPath "E:\Backups" -AzureConnectionString $env:AZURE_STORAGE_CONNECTION_STRING -AzureContainer "backups"
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [Parameter(Mandatory=$true)][string]$SourcePath,
  [Parameter(Mandatory=$true)][string]$DestinationPath,
  [int]$RetentionDays = 30,
  [string[]]$ExcludeDirs,
  [string[]]$ExcludeExtensions,
  [string]$LogPath,
  [string]$EncryptKeyFile,
  [string]$AzureConnectionString,
  [string]$AzureContainer,
  [string]$WebhookUrl,
  [string]$Tag
)

# -------------------- helpers --------------------
function Write-Log {
  param([string]$Message, [ValidateSet('INFO','WARN','ERROR','DEBUG')]$Level='INFO')
  $ts = (Get-Date).ToString('o')
  $line = "[${ts}] [$Level] $Message"
  Write-Host $line
  if ($script:LOG) { Add-Content -LiteralPath $script:LOG -Value $line }
}

function Ensure-Dir { param([string]$Path) if (!(Test-Path $Path)) { New-Item -ItemType Directory -Path $Path | Out-Null } }

function Get-ArchiveName {
  $ts = Get-Date -Format "yyyyMMdd-HHmmss"
  if ($Tag) { return "backup-$ts-$Tag.zip" }
  return "backup-$ts.zip"
}

function Normalize-KeyBytes {
  param([byte[]]$Raw, [switch]$FromBase64)
  if ($FromBase64) { $Raw = [Convert]::FromBase64String([Text.Encoding]::UTF8.GetString($Raw)) }
  if ($Raw.Length -eq 32) { return $Raw }
  throw "Encryption key must be exactly 32 bytes (256-bit)."
}

function Read-KeyFile32 {
  param([string]$Path)
  if (!(Test-Path $Path)) { throw "Key file not found: $Path" }
  $bytes = [System.IO.File]::ReadAllBytes($Path)
  # Accept raw 32 bytes or base64 text representing 32 bytes
  if ($bytes.Length -eq 32) { return $bytes }
  # try base64 path
  $text = Get-Content -Raw -Path $Path
  try {
    $b64 = [Convert]::FromBase64String($text.Trim())
    if ($b64.Length -eq 32) { return $b64 }
  } catch { }
  throw "Key file must be 32 raw bytes or base64 string of 32 bytes."
}

function Protect-FileWithAes {
  param(
    [Parameter(Mandatory=$true)][string]$InputPath,
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [Parameter(Mandatory=$true)][byte[]]$Key
  )
  $iv = New-Object byte[] 16
  [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($iv)
  $aes = [System.Security.Cryptography.Aes]::Create()
  $aes.Key = $Key
  $aes.IV  = $iv
  $aes.Mode = 'CBC'
  $aes.Padding = 'PKCS7'

  $inStream  = [System.IO.File]::OpenRead($InputPath)
  $outStream = [System.IO.File]::Open($OutputPath, [System.IO.FileMode]::Create)
  try {
    # header: "AES256" + IV (16 bytes)
    $header = [Text.Encoding]::ASCII.GetBytes("AES256")
    $outStream.Write($header,0,$header.Length)
    $outStream.Write($iv,0,$iv.Length)

    $crypto = New-Object System.Security.Cryptography.CryptoStream($outStream, $aes.CreateEncryptor(), [System.Security.Cryptography.CryptoStreamMode]::Write)
    $inStream.CopyTo($crypto)
    $crypto.FlushFinalBlock()
  } finally {
    $inStream.Dispose(); $outStream.Dispose(); $aes.Dispose()
  }
}

function New-Manifest {
  param([string]$ArchivePath,[string]$EncPath)
  $hash = Get-FileHash -Path $ArchivePath -Algorithm SHA256
  $size = (Get-Item $ArchivePath).Length
  $obj = [ordered]@{
    archive           = (Split-Path -Leaf $ArchivePath)
    sha256            = $hash.Hash
    bytes             = $size
    encryptedFile     = $(if ($EncPath) { Split-Path -Leaf $EncPath } else { $null })
    createdUtc        = (Get-Date).ToUniversalTime().ToString("o")
    sourcePath        = (Resolve-Path $SourcePath).Path
    excludedDirs      = $ExcludeDirs
    excludedExtensions= $ExcludeExtensions
    itemsBackedUp     = $script:BACKUPCOUNT
    version           = "1.2"
  }
  return ($obj | ConvertTo-Json -Depth 6)
}

function Remove-OldBackups {
  param([string]$Folder,[int]$Days)
  $cutoff = (Get-Date).AddDays(-$Days)
  Get-ChildItem -LiteralPath $Folder -File |
    Where-Object { $_.LastWriteTime -lt $cutoff -and $_.Name -match '^backup-\d{8}-\d{6}.*\.(zip|enc|json)$' } |
    ForEach-Object {
      if ($PSCmdlet.ShouldProcess($_.FullName, "Delete old backup")) {
        Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
        Write-Log "Deleted old backup: $($_.Name)" "INFO"
      }
    }
}

function Post-Webhook {
  param([string]$Url,[hashtable]$Payload)
  try {
    Invoke-RestMethod -Method POST -Uri $Url -Body ($Payload | ConvertTo-Json -Depth 6) -ContentType "application/json" | Out-Null
  } catch {
    Write-Log "Webhook post failed: $($_.Exception.Message)" "WARN"
  }
}

function Upload-AzureBlob {
  param(
    [string]$Conn,
    [string]$Container,
    [string[]]$Paths
  )
  try {
    if (-not (Get-Module Az.Storage -ListAvailable)) {
      Import-Module Az.Storage -ErrorAction Stop
    }
  } catch {
    throw "Az.Storage not installed. Install-Module Az.Storage -Scope CurrentUser"
  }
  $ctx = New-AzStorageContext -ConnectionString $Conn
  foreach ($p in $Paths) {
    $name = Split-Path -Leaf $p
    Write-Log "Uploading to Azure Blob: $name" 'INFO'
    Set-AzStorageBlobContent -File $p -Container $Container -Blob $name -Context $ctx -Force | Out-Null
  }
}

# -------------------- main --------------------
try {
  if (-not (Test-Path $SourcePath)) { throw "Source not found: $SourcePath" }
  Ensure-Dir $DestinationPath

  # Log file default under destination /logs
  if (-not $LogPath) {
    $logsDir = Join-Path $DestinationPath "logs"
    Ensure-Dir $logsDir
    $script:LOG = Join-Path $logsDir "backup_automation.log"
  } else {
    Ensure-Dir (Split-Path -Parent $LogPath)
    $script:LOG = $LogPath
  }
  Write-Log "Starting backup: Source='$SourcePath' Dest='$DestinationPath' Tag='$Tag' RetentionDays=$RetentionDays" 'INFO'

  # Build file list with exclusions
  $allFiles = Get-ChildItem -LiteralPath $SourcePath -Recurse -File -Force -ErrorAction Stop
  if ($ExcludeDirs -and $ExcludeDirs.Count -gt 0) {
    $dirSet = $ExcludeDirs
    $allFiles = $allFiles | Where-Object {
      $parent = $_.DirectoryName
      # exclude if any excluded dir name is part of its path
      -not ($dirSet | Where-Object { $parent -like "*\$_*" -or $parent -like "*/$_/*" })
    }
  }
  if ($ExcludeExtensions -and $ExcludeExtensions.Count -gt 0) {
    $extSet = $ExcludeExtensions | ForEach-Object { $_.ToLower() }
    $allFiles = $allFiles | Where-Object { -not ($extSet -contains $_.Extension.ToLower()) }
  }
  $script:BACKUPCOUNT = ($allFiles | Measure-Object).Count
  if ($script:BACKUPCOUNT -eq 0) { throw "No files to back up after exclusions." }
  Write-Log "Files selected: $script:BACKUPCOUNT" 'INFO'

  # Create archive
  $zipName = Get-ArchiveName
  $zipPath = Join-Path $DestinationPath $zipName

  if ($PSCmdlet.ShouldProcess($zipPath, "Create ZIP archive")) {
    # Compress-Archive doesn't accept exclusions directly; pass explicit file paths:
    # To preserve folder structure, switch to staging Compress-Archive behavior:
    $tempStaging = Join-Path ([System.IO.Path]::GetTempPath()) ("bk_" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempStaging | Out-Null
    try {
      foreach ($f in $allFiles) {
        $rel = Resolve-Path -LiteralPath $f.FullName | ForEach-Object {
          $_.Path.Substring((Resolve-Path $SourcePath).Path.Length).TrimStart('\','/')
        }
        $dest = Join-Path $tempStaging $rel
        Ensure-Dir (Split-Path -Parent $dest)
        Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
      }
      Compress-Archive -Path (Join-Path $tempStaging '*') -DestinationPath $zipPath -Force
    } finally {
      Remove-Item -LiteralPath $tempStaging -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Log "Archive created: $zipPath" 'INFO'
  }

  # Optional encryption -> .enc
  $encPath = $null
  if ($EncryptKeyFile) {
    $key = Read-KeyFile32 -Path $EncryptKeyFile
    $encPath = [System.IO.Path]::ChangeExtension($zipPath, ".enc")
    if ($PSCmdlet.ShouldProcess($encPath, "Encrypt archive with AES-256")) {
      Protect-FileWithAes -InputPath $zipPath -OutputPath $encPath -Key $key
      Write-Log "Encrypted file created: $encPath" 'INFO'
    }
  }

  # Manifest (.json)
  $manifest = New-Manifest -ArchivePath $zipPath -EncPath $encPath
  $manifestPath = [IO.Path]::ChangeExtension($zipPath, ".json")
  if ($PSCmdlet.ShouldProcess($manifestPath, "Write manifest")) {
    $manifest | Out-File -LiteralPath $manifestPath -Encoding utf8 -Force
    Write-Log "Manifest written: $manifestPath" 'INFO'
  }

  # Retention cleanup
  Remove-OldBackups -Folder $DestinationPath -Days $RetentionDays

  # Optional Azure upload
  $uploaded = @()
  if ($AzureConnectionString -and $AzureContainer) {
    if ($PSCmdlet.ShouldProcess("$AzureContainer", "Upload to Azure Blob Storage")) {
      $toUpload = @($zipPath, $manifestPath)
      if ($encPath) { $toUpload += $encPath }
      Upload-AzureBlob -Conn $AzureConnectionString -Container $AzureContainer -Paths $toUpload
      $uploaded = $toUpload
    }
  }

  # Notify (optional)
  if ($WebhookUrl) {
    $payload = @{
      text = "Backup completed"
      summary = "Backup completed"
      attachments = @(
        @{
          title = "IT Automation Toolkit - Backup"
          facts = @(
            @{ name="Archive"; value=(Split-Path -Leaf $zipPath) },
            @{ name="Encrypted"; value= $(if ($encPath) {"Yes"} else {"No"}) },
            @{ name="Files"; value=$script:BACKUPCOUNT },
            @{ name="SHA256"; value=( (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash ) },
            @{ name="Uploaded"; value= $(if ($uploaded.Count -gt 0) {"Yes"} else {"No"}) }
          )
          text = "Destination: $DestinationPath"
        }
      )
    }
    Post-Webhook -Url $WebhookUrl -Payload $payload
  }

  Write-Log "Backup complete." 'INFO'
  Write-Host "Backup complete:`n  ZIP: $zipPath`n  Manifest: $manifestPath`n  Encrypted: $encPath"
  exit 0
}
catch {
  Write-Log "Backup FAILED: $($_.Exception.Message)" 'ERROR'
  if ($WebhookUrl) {
    Post-Webhook -Url $WebhookUrl -Payload @{ text = "Backup FAILED: $($_.Exception.Message)"; summary="Backup FAILED" }
  }
  exit 1
}
