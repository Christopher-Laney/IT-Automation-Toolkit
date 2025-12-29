<#
.SYNOPSIS
  Sends a formatted alert message to a Microsoft Teams channel via webhook.

.DESCRIPTION
  Wraps the standard Incoming Webhook connector format so other scripts
  (backups, health checks, compliance audits) can post status messages
  into an IT or NOC channel.

.PARAMETER WebhookUrl
  Teams incoming webhook URL.

.PARAMETER Title
  Short title for the card (e.g. "Backup Job Failed").

.PARAMETER Message
  Main message body.

.PARAMETER Severity
  Text severity level: Info, Warning, Critical.

.EXAMPLE
  .\teams_webhook_alert.ps1 -WebhookUrl "https://outlook.office.com/webhook/..." `
    -Title "Backup Warning" `
    -Message "Backup job SRV01 completed with warnings." `
    -Severity "Warning"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$WebhookUrl,

    [Parameter(Mandatory=$true)]
    [string]$Title,

    [Parameter(Mandatory=$true)]
    [string]$Message,

    [ValidateSet('Info','Warning','Critical')]
    [string]$Severity = 'Info'
)

begin {
    $ErrorActionPreference = 'Stop'
}

process {
    $color = switch ($Severity) {
        'Info'     { '0078D7' }   # blue
        'Warning'  { 'FFC300' }   # yellow
        'Critical' { 'D13438' }   # red
    }

    $payload = @{
        "@type"    = "MessageCard"
        "@context" = "http://schema.org/extensions"
        summary    = $Title
        themeColor = $color
        title      = $Title
        text       = $Message
        sections   = @(
            @{
                facts = @(
                    @{ name = "Severity"; value = $Severity },
                    @{ name = "Timestamp"; value = (Get-Date).ToString("u") }
                )
            }
        )
    }

    try {
        $json = $payload | ConvertTo-Json -Depth 5
        $resp = Invoke-RestMethod -Method Post -Uri $WebhookUrl -Body $json -ContentType "application/json"
        Write-Host "[SUCCESS] Alert sent to Teams." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to send Teams alert: $($_.Exception.Message)"
    }
}

end { }
