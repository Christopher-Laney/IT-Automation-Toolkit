<#
.SYNOPSIS
  Exports Azure AD group memberships for audit and review.

.DESCRIPTION
  Uses Microsoft Graph to pull all groups and members, then exports a flat CSV
  that can be filtered by group, user, or role. Useful for quarterly reviews,
  SOX-style attestations, or access cleanup.

.REQUIREMENTS
  - Microsoft.Graph module
  - Permissions: Group.Read.All, User.Read.All

.PARAMETER ExportPath
  Path to the CSV report.

.EXAMPLE
  .\group_membership_audit.ps1 -ExportPath .\reports\aad_group_memberships.csv
#>

[CmdletBinding()]
param(
    [string]$ExportPath = ".\reports\aad_group_memberships.csv"
)

begin {
    $ErrorActionPreference = 'Stop'

    $directory = Split-Path -Path $ExportPath
    if ($directory -and -not (Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    Write-Host "[INFO] Connecting to Microsoft Graph..." -ForegroundColor Cyan
    try {
        # Connect-MgGraph -Scopes "Group.Read.All","User.Read.All"
        # Select-MgProfile -Name "v1.0"
        Write-Host "[INFO] (Graph connect commented out for safety; enable in production.)" -ForegroundColor Yellow
    }
    catch {
        Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
        return
    }

    $results = New-Object System.Collections.Generic.List[object]
}

process {
    Write-Host "[INFO] Fetching groups..." -ForegroundColor Cyan

    # In production: uncomment the Graph call:
    # $groups = Get-MgGroup -All
    # Demo placeholder list for structure:
    $groups = @(
        [pscustomobject]@{ Id = 'demo-group-1'; DisplayName = 'Demo-Group-1'; MailEnabled = $false; SecurityEnabled = $true },
        [pscustomobject]@{ Id = 'demo-group-2'; DisplayName = 'Demo-Group-2'; MailEnabled = $true; SecurityEnabled = $true }
    )

    foreach ($g in $groups) {
        Write-Host "[INFO] Processing group: $($g.DisplayName)" -ForegroundColor DarkCyan

        try {
            # In production:
            # $members = Get-MgGroupMember -GroupId $g.Id -All
            # Placeholder:
            $members = @(
                [pscustomobject]@{ Id = 'user1'; UserPrincipalName = 'user1@contoso.com'; DisplayName = 'User One'; OdataType = '#microsoft.graph.user' }
            )

            foreach ($m in $members) {
                $results.Add([pscustomobject]@{
                    GroupName        = $g.DisplayName
                    GroupId          = $g.Id
                    MailEnabled      = $g.MailEnabled
                    SecurityEnabled  = $g.SecurityEnabled
                    MemberId         = $m.Id
                    MemberUPN        = $m.UserPrincipalName
                    MemberDisplay    = $m.DisplayName
                    MemberType       = $m.OdataType
                    RetrievedOn      = (Get-Date)
                })
            }
        }
        catch {
            Write-Warning "Failed to get members for group $($g.DisplayName): $($_.Exception.Message)"
        }
    }
}

end {
    $results | Export-Csv -NoTypeInformation -Path $ExportPath
    Write-Host "[SUCCESS] Group membership audit saved to: $ExportPath" -ForegroundColor Green
}
