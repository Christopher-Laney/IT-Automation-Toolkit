<#
.SYNOPSIS
  Audits Microsoft 365 license usage and assignment consistency.

.DESCRIPTION
  - Lists all subscribed SKUs with consumed/available units
  - Lists users missing a required license SKU (e.g. E3, Business Premium)
  Intended for capacity planning and catching mis-licensed accounts.

.REQUIREMENTS
  - Microsoft.Graph module
  - Permissions: Directory.Read.All

.PARAMETER RequiredSkuPartNumber
  License part number that users SHOULD have (e.g. O365_BUSINESS_PREMIUM).

.PARAMETER ExportPath
  CSV path for per-user licensing report.

.EXAMPLE
  .\m365_license_audit.ps1 -RequiredSkuPartNumber "SPE_E3" -ExportPath .\reports\m365_license_audit.csv
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$RequiredSkuPartNumber,

    [string]$ExportPath = ".\reports\m365_license_audit.csv"
)

begin {
    $ErrorActionPreference = 'Stop'

    $directory = Split-Path -Path $ExportPath
    if ($directory -and -not (Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    Write-Host "[INFO] Connecting to Microsoft Graph..." -ForegroundColor Cyan
    try {
        # Connect-MgGraph -Scopes "Directory.Read.All"
        # Select-MgProfile -Name "v1.0"
        Write-Host "[INFO] (Graph connect commented out; enable in production.)" -ForegroundColor Yellow
    }
    catch {
        Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
        return
    }
}

process {
    # --- Tenant SKU overview ---
    Write-Host "[INFO] Fetching subscribed SKUs..." -ForegroundColor Cyan

    # In production:
    # $skus = Get-MgSubscribedSku
    # Demo placeholder:
    $skus = @(
        [pscustomobject]@{
            SkuId        = [guid]::NewGuid()
            SkuPartNumber= $RequiredSkuPartNumber
            PrepaidUnits = @{ Enabled = 100 }
            ConsumedUnits= 87
        }
    )

    foreach ($s in $skus) {
        Write-Host ("[INFO] SKU {0}: {1}/{2} used" -f $s.SkuPartNumber, $s.ConsumedUnits, $s.PrepaidUnits.Enabled) -ForegroundColor DarkCyan
    }

    # --- Per-user detail ---
    Write-Host "[INFO] Fetching users and license details..." -ForegroundColor Cyan

    # In production:
    # $users = Get-MgUser -All -Property "id,displayName,userPrincipalName,assignedLicenses"
    # Demo placeholder:
    $users = @(
        [pscustomobject]@{
            Id               = [guid]::NewGuid()
            DisplayName      = 'User One'
            UserPrincipalName= 'user1@contoso.com'
            AssignedLicenses = @(
                @{ SkuId = $skus[0].SkuId }
            )
        },
        [pscustomobject]@{
            Id               = [guid]::NewGuid()
            DisplayName      = 'User Two'
            UserPrincipalName= 'user2@contoso.com'
            AssignedLicenses = @() # missing required SKU
        }
    )

    # Map SkuId -> SkuPartNumber
    $skuMap = @{}
    foreach ($s in $skus) {
        $skuMap[$s.SkuId.Guid] = $s.SkuPartNumber
    }

    $rows = foreach ($u in $users) {
        $userSkuParts = @()

        foreach ($lic in $u.AssignedLicenses) {
            $id = $lic.SkuId.Guid
            if ($skuMap.ContainsKey($id)) {
                $userSkuParts += $skuMap[$id]
            }
        }

        $hasRequired = $userSkuParts -contains $RequiredSkuPartNumber

        [pscustomobject]@{
            DisplayName       = $u.DisplayName
            UserPrincipalName = $u.UserPrincipalName
            AssignedSkus      = ($userSkuParts -join ';')
            HasRequiredSku    = $hasRequired
        }
    }

    $rows | Export-Csv -NoTypeInformation -Path $ExportPath
    Write-Host "[SUCCESS] License audit saved to: $ExportPath" -ForegroundColor Green

    $missing = $rows | Where-Object { -not $_.HasRequiredSku }
    if ($missing.Count -gt 0) {
        Write-Host "[WARN] Users missing required SKU ($RequiredSkuPartNumber):" -ForegroundColor Yellow
        $missing | Select-Object DisplayName,UserPrincipalName,AssignedSkus | Format-Table -AutoSize
    }
    else {
        Write-Host "[INFO] All users have the required SKU ($RequiredSkuPartNumber)." -ForegroundColor Green
    }
}

end { }
