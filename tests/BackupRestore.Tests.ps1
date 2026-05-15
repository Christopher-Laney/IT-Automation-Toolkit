Describe 'Backup and restore automation' {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent $PSScriptRoot
        $script:BackupScript = Join-Path $script:RepoRoot 'scripts/automation/backup_automation.ps1'
        $script:RestoreScript = Join-Path $script:RepoRoot 'scripts/automation/restore_backup.ps1'
    }

    BeforeEach {
        $script:CaseRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:SourcePath = Join-Path $script:CaseRoot 'source'
        $script:BackupPath = Join-Path $script:CaseRoot 'backups'
        New-Item -ItemType Directory -Path $script:SourcePath, $script:BackupPath | Out-Null

        New-Item -ItemType Directory -Path (Join-Path $script:SourcePath 'nested') | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:SourcePath 'skip') | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:SourcePath 'cache-data') | Out-Null

        Set-Content -Path (Join-Path $script:SourcePath 'root.txt') -Value 'keep root'
        Set-Content -Path (Join-Path $script:SourcePath 'nested/data.csv') -Value 'name,status'
        Set-Content -Path (Join-Path $script:SourcePath 'skip/secret.txt') -Value 'do not back up'
        Set-Content -Path (Join-Path $script:SourcePath 'cache-data/cache.txt') -Value 'cache'
        Set-Content -Path (Join-Path $script:SourcePath 'scratch.tmp') -Value 'temporary'
    }

    It 'creates a manifest and restores only included files' {
        & $script:BackupScript `
            -SourcePath $script:SourcePath `
            -DestinationPath $script:BackupPath `
            -ExcludeDirs 'skip', 'cache*' `
            -ExcludeExtensions '.tmp' `
            -Tag 'pester'

        $archives = @(Get-ChildItem -Path $script:BackupPath -Filter 'backup-*-pester.zip')
        $archives | Should -HaveCount 1
        $zip = $archives[0]
        $manifestPath = [System.IO.Path]::ChangeExtension($zip.FullName, '.json')
        Test-Path $manifestPath | Should -BeTrue

        $manifest = Get-Content -Raw -Path $manifestPath | ConvertFrom-Json
        $manifest.itemsBackedUp | Should -Be 2
        $manifest.excludedDirs | Should -Contain 'skip'
        $manifest.excludedDirs | Should -Contain 'cache*'
        $manifest.excludedExtensions | Should -Contain '.tmp'
        $manifest.sha256 | Should -Be (Get-FileHash -Path $zip.FullName -Algorithm SHA256).Hash
        $manifest.fileInventory | Should -HaveCount 2
        $manifest.fileInventory.relativePath | Should -Contain 'root.txt'
        $manifest.fileInventory.relativePath | Should -Contain 'nested/data.csv'

        $restorePath = Join-Path $script:CaseRoot 'restore'
        & $script:RestoreScript -BackupPath $zip.FullName -ManifestPath $manifestPath -DestinationPath $restorePath

        Test-Path (Join-Path $restorePath 'root.txt') | Should -BeTrue
        Test-Path (Join-Path $restorePath 'nested/data.csv') | Should -BeTrue
        Test-Path (Join-Path $restorePath 'skip/secret.txt') | Should -BeFalse
        Test-Path (Join-Path $restorePath 'cache-data/cache.txt') | Should -BeFalse
        Test-Path (Join-Path $restorePath 'scratch.tmp') | Should -BeFalse
    }

    It 'keeps the sample backup manifest parseable and documented' {
        $sampleManifestPath = Join-Path $script:RepoRoot 'samples/backups/backup-20260514-000000-sample.json'

        Test-Path $sampleManifestPath | Should -BeTrue
        $manifest = Get-Content -Raw -Path $sampleManifestPath | ConvertFrom-Json

        $manifest.archive | Should -Be 'backup-20260514-000000-sample.zip'
        $manifest.encryptedFile | Should -Be 'backup-20260514-000000-sample.enc'
        $manifest.encryption | Should -Match 'AES-256-CBC'
        $manifest.excludedDirs | Should -Contain 'cache*'
        $manifest.excludedExtensions | Should -Contain '.tmp'
        $manifest.itemsBackedUp | Should -BeGreaterThan 0
        $manifest.fileInventory | Should -Not -BeNullOrEmpty
        $manifest.fileInventory[0].relativePath | Should -Be 'Finance/quarterly.xlsx'
        $manifest.version | Should -Be '1.3'
    }

    It 'stops restore when the manifest hash does not match the backup' {
        & $script:BackupScript `
            -SourcePath $script:SourcePath `
            -DestinationPath $script:BackupPath `
            -Tag 'tamper'

        $archives = @(Get-ChildItem -Path $script:BackupPath -Filter 'backup-*-tamper.zip')
        $archives | Should -HaveCount 1
        $zip = $archives[0]
        $manifestPath = [System.IO.Path]::ChangeExtension($zip.FullName, '.json')
        Add-Content -LiteralPath $zip.FullName -Value 'tamper'

        {
            & $script:RestoreScript `
                -BackupPath $zip.FullName `
                -ManifestPath $manifestPath `
                -DestinationPath (Join-Path $script:CaseRoot 'tampered-restore')
        } | Should -Throw -ExpectedMessage '*SHA256 mismatch*'
    }

    It 'stops restore when the restored inventory does not match the manifest' {
        & $script:BackupScript `
            -SourcePath $script:SourcePath `
            -DestinationPath $script:BackupPath `
            -Tag 'inventory'

        $archives = @(Get-ChildItem -Path $script:BackupPath -Filter 'backup-*-inventory.zip')
        $archives | Should -HaveCount 1
        $zip = $archives[0]
        $manifestPath = [System.IO.Path]::ChangeExtension($zip.FullName, '.json')
        $manifest = Get-Content -Raw -Path $manifestPath | ConvertFrom-Json
        $manifest.fileInventory[0].sha256 = ('0' * 64)
        $manifest | ConvertTo-Json -Depth 8 | Set-Content -Path $manifestPath

        {
            & $script:RestoreScript `
                -BackupPath $zip.FullName `
                -ManifestPath $manifestPath `
                -DestinationPath (Join-Path $script:CaseRoot 'inventory-restore')
        } | Should -Throw -ExpectedMessage '*Restored inventory hash mismatch*'
    }

    It 'restores encrypted backups and removes the temporary decrypted ZIP' {
        $keyPath = Join-Path $script:CaseRoot 'backup.key'
        [System.IO.File]::WriteAllBytes($keyPath, [byte[]](0..31))

        & $script:BackupScript `
            -SourcePath $script:SourcePath `
            -DestinationPath $script:BackupPath `
            -EncryptKeyFile $keyPath `
            -Tag 'encrypted'

        $archives = @(Get-ChildItem -Path $script:BackupPath -Filter 'backup-*-encrypted.zip')
        $encryptedArchives = @(Get-ChildItem -Path $script:BackupPath -Filter 'backup-*-encrypted.enc')
        $archives | Should -HaveCount 1
        $encryptedArchives | Should -HaveCount 1

        $zip = $archives[0]
        $encryptedArchive = $encryptedArchives[0]
        $manifestPath = [System.IO.Path]::ChangeExtension($zip.FullName, '.json')
        $manifest = Get-Content -Raw -Path $manifestPath | ConvertFrom-Json

        $manifest.encryptedFile | Should -Be $encryptedArchive.Name
        $manifest.encryptedSha256 | Should -Be (Get-FileHash -Path $encryptedArchive.FullName -Algorithm SHA256).Hash
        $manifest.encryption | Should -Match 'AES-256-CBC'

        $restorePath = Join-Path $script:CaseRoot 'encrypted-restore'
        & $script:RestoreScript `
            -BackupPath $encryptedArchive.FullName `
            -ManifestPath $manifestPath `
            -EncryptKeyFile $keyPath `
            -DestinationPath $restorePath

        Test-Path (Join-Path $restorePath 'root.txt') | Should -BeTrue
        Test-Path (Join-Path $restorePath 'nested/data.csv') | Should -BeTrue
        Test-Path ([System.IO.Path]::ChangeExtension($encryptedArchive.FullName, '.decrypted.zip')) | Should -BeFalse
    }

    It 'removes expired backup artifacts during retention cleanup' {
        foreach ($extension in 'zip', 'enc', 'json') {
            $oldPath = Join-Path $script:BackupPath "backup-20000101-000000-old.$extension"
            Set-Content -Path $oldPath -Value 'old backup artifact'
            (Get-Item -Path $oldPath).LastWriteTime = (Get-Date).AddDays(-10)
        }

        $unrelatedPath = Join-Path $script:BackupPath 'notes.txt'
        Set-Content -Path $unrelatedPath -Value 'do not remove'
        (Get-Item -Path $unrelatedPath).LastWriteTime = (Get-Date).AddDays(-10)

        & $script:BackupScript `
            -SourcePath $script:SourcePath `
            -DestinationPath $script:BackupPath `
            -RetentionDays 1 `
            -Tag 'retention'

        @(Get-ChildItem -Path $script:BackupPath -Filter 'backup-20000101-000000-old.*') | Should -BeNullOrEmpty
        Test-Path $unrelatedPath | Should -BeTrue
        @(Get-ChildItem -Path $script:BackupPath -Filter 'backup-*-retention.zip') | Should -HaveCount 1
        @(Get-ChildItem -Path $script:BackupPath -Filter 'backup-*-retention.json') | Should -HaveCount 1
    }

    It 'previews backup work with WhatIf without creating an archive' {
        & $script:BackupScript `
            -SourcePath $script:SourcePath `
            -DestinationPath $script:BackupPath `
            -ExcludeExtensions '.tmp' `
            -Tag 'preview' `
            -WhatIf

        Get-ChildItem -Path $script:BackupPath -Filter 'backup-*-preview.zip' | Should -BeNullOrEmpty
        Get-ChildItem -Path $script:BackupPath -Filter 'backup-*-preview.json' | Should -BeNullOrEmpty
    }

    It 'previews backup work to a new destination without retention warnings' {
        $newBackupPath = Join-Path $script:CaseRoot 'new-backup-destination'

        $output = & $script:BackupScript `
            -SourcePath $script:SourcePath `
            -DestinationPath $newBackupPath `
            -Tag 'new-preview' `
            -WhatIf 6>&1 3>&1 2>&1

        ($output | Out-String) | Should -Match 'Backup preview complete'
        ($output | Out-String) | Should -Not -Match 'Cannot find path'
        Test-Path $newBackupPath | Should -BeFalse
    }
}
