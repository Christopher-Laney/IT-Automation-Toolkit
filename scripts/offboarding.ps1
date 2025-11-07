\
    <#
      .SYNOPSIS
        Securely offboards a user: disables sign-in, revokes sessions, and archives data.
    #>

    param(
        [Parameter(Mandatory=$true)]
        [string]$UserPrincipalName
    )

    # Import-Module Microsoft.Graph.Users -ErrorAction Stop

    Write-Host "Disabling $UserPrincipalName (simulation)..."
    # Update-MgUser -UserId $UserPrincipalName -AccountEnabled:$false

    Write-Host "Revoking sign-in sessions (simulation)..."
    # Revoke-MgUserSignInSession -UserId $UserPrincipalName

    Write-Host "Archiving mailbox / OneDrive (simulation)..."
    # TODO: Implement export/archive procedures

    Write-Host "Offboarding complete (simulation)."
