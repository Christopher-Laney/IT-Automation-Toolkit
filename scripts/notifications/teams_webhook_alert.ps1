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

.PARAMETER CardFormat
  Payload format to send: MessageCard for broad compatibility or AdaptiveCard
  for richer high-signal operational alerts.

.PARAMETER PassThru
  Return the generated payload object for logging, tests, or review workflows.

.EXAMPLE
  .\teams_webhook_alert.ps1 -WebhookUrl "https://outlook.office.com/webhook/..." `
    -Title "Backup Warning" `
    -Message "Backup job SRV01 completed with warnings." `
    -Severity "Warning"

.EXAMPLE
  .\teams_webhook_alert.ps1 -WebhookUrl "https://outlook.office.com/webhook/..." `
    -Title "IT Baseline Checks Completed" `
    -Message "All scheduled checks completed." `
    -Severity "Info" `
    -CardFormat "AdaptiveCard"

.EXAMPLE
  .\teams_webhook_alert.ps1 -WebhookUrl "https://outlook.office.com/webhook/..." `
    -Title "Backup Warning" `
    -Message "Backup job SRV01 completed with warnings." `
    -Severity "Warning" `
    -WhatIf `
    -PassThru
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$WebhookUrl,

    [Parameter(Mandatory = $true)]
    [string]$Title,

    [Parameter(Mandatory = $true)]
    [string]$Message,

    [ValidateSet('Info', 'Warning', 'Critical')]
    [string]$Severity = 'Info',

    [ValidateSet('MessageCard', 'AdaptiveCard')]
    [string]$CardFormat = 'MessageCard',

    [switch]$PassThru
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

    $timestamp = (Get-Date).ToString("u")
    $payload = if ($CardFormat -eq 'AdaptiveCard') {
        $adaptiveColor = switch ($Severity) {
            'Info'     { 'Accent' }
            'Warning'  { 'Warning' }
            'Critical' { 'Attention' }
        }

        @{
            type        = 'message'
            attachments = @(
                @{
                    contentType = 'application/vnd.microsoft.card.adaptive'
                    contentUrl  = $null
                    content     = @{
                        '$schema' = 'http://adaptivecards.io/schemas/adaptive-card.json'
                        type      = 'AdaptiveCard'
                        version   = '1.4'
                        body      = @(
                            @{
                                type   = 'TextBlock'
                                text   = $Title
                                weight = 'Bolder'
                                size   = 'Medium'
                                wrap   = $true
                                color  = $adaptiveColor
                            },
                            @{
                                type = 'TextBlock'
                                text = $Message
                                wrap = $true
                            },
                            @{
                                type  = 'FactSet'
                                facts = @(
                                    @{ title = 'Severity'; value = $Severity },
                                    @{ title = 'Timestamp'; value = $timestamp }
                                )
                            }
                        )
                    }
                }
            )
        }
    } else {
        @{
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
                        @{ name = "Timestamp"; value = $timestamp }
                    )
                }
            )
        }
    }

    if ($PassThru) {
        $payload
    }

    if ($PSCmdlet.ShouldProcess($WebhookUrl, "Send Teams webhook alert")) {
        try {
            $json = $payload | ConvertTo-Json -Depth 10
            Invoke-RestMethod -Method Post -Uri $WebhookUrl -Body $json -ContentType "application/json" | Out-Null
            Write-Host "[SUCCESS] Alert sent to Teams." -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to send Teams alert: $($_.Exception.Message)"
        }
    }
}

end { }
