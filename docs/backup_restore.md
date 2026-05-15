# Backup And Restore Guide

This guide covers `scripts/automation/backup_automation.ps1` and `scripts/automation/restore_backup.ps1`.

## Safe Preview

Start with `-WhatIf` to confirm the source, destination, retention, and exclusions:

```powershell
.\scripts\automation\backup_automation.ps1 `
  -SourcePath "D:\Data" `
  -DestinationPath "E:\Backups" `
  -ExcludeExtensions ".tmp",".log" `
  -RetentionDays 14 `
  -WhatIf
```

`-ExcludeDirs` compares each directory path segment against the supplied values, so both exact names and wildcards work across platforms. For example, `-ExcludeDirs "node_modules","cache*"` excludes any folder named `node_modules` and any folder whose name starts with `cache`.

## Local Backup

```powershell
.\scripts\automation\backup_automation.ps1 `
  -SourcePath "D:\Data" `
  -DestinationPath "E:\Backups" `
  -Tag "file-share" `
  -RetentionDays 30
```

The script writes:

- `backup-YYYYMMDD-HHMMSS[-tag].zip`
- `backup-YYYYMMDD-HHMMSS[-tag].json`
- A log file under the backup destination unless `-LogPath` is provided.

## Encrypted Backup

Generate and protect a 32-byte key outside the repository:

```powershell
$key = New-Object byte[] 32
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($key)
[System.IO.File]::WriteAllBytes("C:\Keys\backup.key", $key)
```

Run the encrypted backup:

```powershell
.\scripts\automation\backup_automation.ps1 `
  -SourcePath "D:\Data" `
  -DestinationPath "E:\Backups" `
  -EncryptKeyFile "C:\Keys\backup.key"
```

The encrypted file uses the repository's documented `AES256` header followed by a 16-byte IV and AES-256-CBC encrypted ZIP content. Keep the key in a vault or protected key location. Do not commit it.

The current encrypted format does not embed an authentication tag in the `.enc` file. Always keep the manifest with the encrypted artifact and restore with `-ManifestPath` so `restore_backup.ps1` verifies `encryptedSha256` before decrypting and verifies `sha256` before extraction.

## Manifest Fields

The manifest includes:

- `archive`: ZIP filename.
- `sha256`: SHA256 hash of the ZIP.
- `bytes`: ZIP size in bytes.
- `encryptedFile`: encrypted backup filename when encryption is used.
- `encryptedSha256`: SHA256 hash of the encrypted file.
- `encryptedBytes`: encrypted file size in bytes.
- `encryption`: encryption format note.
- `createdUtc`: UTC timestamp.
- `sourcePath`: resolved backup source path.
- `excludedDirs` and `excludedExtensions`: exclusions used.
- `itemsBackedUp`: selected file count.
- `fileInventory`: relative path, byte size, and SHA256 for each backed-up file.
- `version`: manifest format version.

See `samples/backups/backup-20260514-000000-sample.json` for a sanitized manifest example. The sample hashes are placeholders so the file is useful for documentation and tooling checks without implying a real backup artifact exists.

## Restore A Plain ZIP

Preview first:

```powershell
.\scripts\automation\restore_backup.ps1 `
  -BackupPath "E:\Backups\backup-20260513-010203.zip" `
  -ManifestPath "E:\Backups\backup-20260513-010203.json" `
  -DestinationPath "D:\Restore" `
  -WhatIf
```

Restore:

```powershell
.\scripts\automation\restore_backup.ps1 `
  -BackupPath "E:\Backups\backup-20260513-010203.zip" `
  -ManifestPath "E:\Backups\backup-20260513-010203.json" `
  -DestinationPath "D:\Restore"
```

When the manifest includes `fileInventory`, restore also verifies that the restored tree has the same relative paths, byte sizes, and SHA256 hashes recorded at backup time. This catches missing files, unexpected files, and restored-content drift after extraction.

## Restore An Encrypted Backup

```powershell
.\scripts\automation\restore_backup.ps1 `
  -BackupPath "E:\Backups\backup-20260513-010203.enc" `
  -ManifestPath "E:\Backups\backup-20260513-010203.json" `
  -EncryptKeyFile "C:\Keys\backup.key" `
  -DestinationPath "D:\Restore"
```

By default, the temporary decrypted ZIP is removed after extraction. Add `-KeepDecryptedZip` only when you need to inspect it during a controlled recovery process.

## Azure Blob Upload

Use a connection string from an environment variable or managed automation secret:

```powershell
.\scripts\automation\backup_automation.ps1 `
  -SourcePath "D:\Data" `
  -DestinationPath "E:\Backups" `
  -AzureConnectionString $env:AZURE_STORAGE_CONNECTION_STRING `
  -AzureContainer "backups"
```

Do not put storage connection strings in scripts, config files, logs, or issue comments.
Provide `-AzureConnectionString` and `-AzureContainer` together; the backup script treats either value on its own as a configuration error instead of silently skipping upload.
