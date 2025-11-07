\
    <#
      .SYNOPSIS
        Example scheduled backup job with integrity verification.
    #>

    param(
        [Parameter(Mandatory=$true)]
        [string]$SourcePath,
        [Parameter(Mandatory=$true)]
        [string]$DestinationPath
    )

    if (!(Test-Path $DestinationPath)) { New-Item -ItemType Directory -Path $DestinationPath | Out-Null }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $archive = Join-Path $DestinationPath ("backup-" + $timestamp + ".zip")

    Compress-Archive -Path $SourcePath -DestinationPath $archive -Force

    $hash = Get-FileHash -Path $archive -Algorithm SHA256
    Write-Host "Backup complete: $archive"
    Write-Host "SHA256: $($hash.Hash)"
