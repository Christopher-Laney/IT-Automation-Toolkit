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

        $restorePath = Join-Path $script:CaseRoot 'restore'
        & $script:RestoreScript -BackupPath $zip.FullName -ManifestPath $manifestPath -DestinationPath $restorePath

        Test-Path (Join-Path $restorePath 'root.txt') | Should -BeTrue
        Test-Path (Join-Path $restorePath 'nested/data.csv') | Should -BeTrue
        Test-Path (Join-Path $restorePath 'skip/secret.txt') | Should -BeFalse
        Test-Path (Join-Path $restorePath 'cache-data/cache.txt') | Should -BeFalse
        Test-Path (Join-Path $restorePath 'scratch.tmp') | Should -BeFalse
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
}
