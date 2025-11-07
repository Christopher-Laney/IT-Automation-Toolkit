\
    <#
      .SYNOPSIS
        Automates new user onboarding across Azure AD / M365.

      .PARAMETER UserList
        Path to CSV with headers: DisplayName, UserPrincipalName, UsageLocation, LicenseSku

      .EXAMPLE
        .\onboarding.ps1 -UserList ..\config\new_users.csv
    #>

    param(
        [Parameter(Mandatory=$true)]
        [string]$UserList
    )

    Import-Module Microsoft.Graph.Users -ErrorAction Stop

    $users = Import-Csv -Path $UserList
    foreach ($u in $users) {
        Write-Host "Creating user $($u.DisplayName) <$($u.UserPrincipalName)>..."

        # Example payload (replace with your org settings)
        $passwordProfile = @{
            forceChangePasswordNextSignIn = $true
            password = ([System.Web.Security.Membership]::GeneratePassword(16,3))
        }

        $body = @{
            accountEnabled    = $true
            displayName       = $u.DisplayName
            mailNickname      = ($u.DisplayName -replace '\s','')
            userPrincipalName = $u.UserPrincipalName
            usageLocation     = $u.UsageLocation
            passwordProfile   = $passwordProfile
        }

        # New-MgUser -BodyParameter $body  # Uncomment after configuring Graph auth
        Write-Host "User payload prepared (Graph call commented for safety)."

        # TODO: Assign license, add to groups, trigger Intune enrollment
    }

    Write-Host "Onboarding complete (simulation)."
