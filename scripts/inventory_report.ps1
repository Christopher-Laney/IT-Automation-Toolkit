\
    <#
      .SYNOPSIS
        Generates a basic inventory CSV of installed software (Windows example).
    #>

    param(
        [string]$ExportPath = ".\reports\inventory.csv"
    )

    if (!(Test-Path (Split-Path $ExportPath))) { New-Item -ItemType Directory -Path (Split-Path $ExportPath) | Out-Null }

    $apps = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
            Select-Object DisplayName, DisplayVersion, Publisher, InstallDate

    $apps | Where-Object { $_.DisplayName } | Export-Csv -NoTypeInformation -Path $ExportPath
    Write-Host "Inventory exported to $ExportPath"
