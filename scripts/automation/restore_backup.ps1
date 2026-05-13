<#
.SYNOPSIS
  Restores ZIP or encrypted backups created by backup_automation.ps1.

.DESCRIPTION
  - Validates manifest SHA256 values when a manifest is provided.
  - Decrypts .enc files produced by backup_automation.ps1 using the same 32-byte key format.
  - Extracts the ZIP into a destination folder.
  - Supports -WhatIf for restore previews.

.PARAMETER BackupPath
  Path to the .zip or .enc backup file.

.PARAMETER DestinationPath
  Folder where backup contents should be restored.

.PARAMETER ManifestPath
  Optional manifest JSON produced by backup_automation.ps1.

.PARAMETER EncryptKeyFile
  Required for .enc backups. Path to the 32-byte raw or base64 key file.

.PARAMETER KeepDecryptedZip
  If set, leaves the temporary decrypted ZIP next to the encrypted backup.

.EXAMPLE
  .\restore_backup.ps1 -BackupPath E:\Backups\backup-20260513-010203.zip -DestinationPath D:\Restore -ManifestPath E:\Backups\backup-20260513-010203.json -WhatIf

.EXAMPLE
  .\restore_backup.ps1 -BackupPath E:\Backups\backup-20260513-010203.enc -DestinationPath D:\Restore -ManifestPath E:\Backups\backup-20260513-010203.json -EncryptKeyFile C:\Keys\bk.key
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [Parameter(Mandatory=$true)][string]$BackupPath,
  [Parameter(Mandatory=$true)][string]$DestinationPath,
  [string]$ManifestPath,
  [string]$EncryptKeyFile,
  [switch]$KeepDecryptedZip
)

function Read-KeyFile32 {
  param([string]$Path)
  if (-not (Test-Path $Path)) { throw "Key file not found: $Path" }
  $bytes = [System.IO.File]::ReadAllBytes($Path)
  if ($bytes.Length -eq 32) { return $bytes }

  $text = Get-Content -Raw -Path $Path
  try {
    $b64 = [Convert]::FromBase64String($text.Trim())
    if ($b64.Length -eq 32) { return $b64 }
  } catch { }

  throw "Key file must be 32 raw bytes or base64 string of 32 bytes."
}

function Unprotect-FileWithAes {
  param(
    [Parameter(Mandatory=$true)][string]$InputPath,
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [Parameter(Mandatory=$true)][byte[]]$Key
  )

  $inStream = [System.IO.File]::OpenRead($InputPath)
  $outStream = [System.IO.File]::Open($OutputPath, [System.IO.FileMode]::Create)
  $aes = [System.Security.Cryptography.Aes]::Create()
  $crypto = $null
  try {
    $header = New-Object byte[] 6
    $readHeader = $inStream.Read($header, 0, $header.Length)
    $headerText = [Text.Encoding]::ASCII.GetString($header)
    if ($readHeader -ne 6 -or $headerText -ne "AES256") {
      throw "Encrypted file header is invalid or unsupported."
    }

    $iv = New-Object byte[] 16
    $readIv = $inStream.Read($iv, 0, $iv.Length)
    if ($readIv -ne 16) { throw "Encrypted file is missing the IV." }

    $aes.Key = $Key
    $aes.IV = $iv
    $aes.Mode = 'CBC'
    $aes.Padding = 'PKCS7'

    $crypto = New-Object System.Security.Cryptography.CryptoStream($inStream, $aes.CreateDecryptor(), [System.Security.Cryptography.CryptoStreamMode]::Read)
    $crypto.CopyTo($outStream)
  } finally {
    if ($crypto) { $crypto.Dispose() }
    $outStream.Dispose()
    $inStream.Dispose()
    $aes.Dispose()
  }
}

function Assert-ManifestHash {
  param(
    [Parameter(Mandatory=$true)][object]$Manifest,
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$true)][string]$PropertyName
  )

  $expected = $Manifest.$PropertyName
  if (-not $expected) { return }

  $actual = (Get-FileHash -Path $Path -Algorithm SHA256).Hash
  if ($actual -ne $expected) {
    throw "SHA256 mismatch for $Path. Expected $expected, got $actual."
  }
}

try {
  if (-not (Test-Path $BackupPath)) { throw "Backup not found: $BackupPath" }

  $manifest = $null
  if ($ManifestPath) {
    if (-not (Test-Path $ManifestPath)) { throw "Manifest not found: $ManifestPath" }
    $manifest = Get-Content -Raw -Path $ManifestPath | ConvertFrom-Json
  }

  $backupItem = Get-Item -LiteralPath $BackupPath
  $isEncrypted = $backupItem.Extension -eq '.enc'
  $zipToRestore = $backupItem.FullName
  $decryptedZip = $null

  if ($isEncrypted) {
    if (-not $EncryptKeyFile) { throw "EncryptKeyFile is required for encrypted backups." }
    if ($manifest) { Assert-ManifestHash -Manifest $manifest -Path $backupItem.FullName -PropertyName 'encryptedSha256' }

    $key = Read-KeyFile32 -Path $EncryptKeyFile
    $decryptedZip = [System.IO.Path]::ChangeExtension($backupItem.FullName, ".decrypted.zip")
    if ($PSCmdlet.ShouldProcess($decryptedZip, "Decrypt backup")) {
      Unprotect-FileWithAes -InputPath $backupItem.FullName -OutputPath $decryptedZip -Key $key
    }
    $zipToRestore = $decryptedZip
  }

  if ($manifest -and (Test-Path $zipToRestore)) {
    Assert-ManifestHash -Manifest $manifest -Path $zipToRestore -PropertyName 'sha256'
  }

  if ($PSCmdlet.ShouldProcess($DestinationPath, "Restore backup contents")) {
    if (-not (Test-Path $DestinationPath)) { New-Item -ItemType Directory -Path $DestinationPath | Out-Null }
    Expand-Archive -LiteralPath $zipToRestore -DestinationPath $DestinationPath -Force
  }

  if ($decryptedZip -and -not $KeepDecryptedZip -and (Test-Path $decryptedZip)) {
    Remove-Item -LiteralPath $decryptedZip -Force
  }

  Write-Host "Restore complete: $DestinationPath"
}
catch {
  Write-Error $_.Exception.Message
  exit 1
}
