<#
.SYNOPSIS
  Sends a formatted alert message to a Slack channel via webhook.

.DESCRIPTION
  Builds either a simple Slack webhook payload or a richer Block Kit payload
  for reusable operational alerts from automation, reporting, and compliance scripts.

.PARAMETER WebhookUrl
  Slack incoming webhook URL.

.PARAMETER Title
  Short alert title.

.PARAMETER Message
  Main message body.

.PARAMETER Severity
  Text severity level: Info, Warning, Critical.

.PARAMETER Category
  Optional script category such as Automation or Compliance.

.PARAMETER PayloadFormat
  Slack payload shape to send: PlainText or BlockKit.

.PARAMETER PassThru
  Return the generated payload object for logging, tests, or review workflows.

.EXAMPLE
  .\slack_webhook_alert.ps1 -WebhookUrl "https://hooks.slack.com/services/..." `
    -Title "Backup Warning" `
    -Message "Backup completed with warnings." `
    -Severity Warning

.EXAMPLE
  .\slack_webhook_alert.ps1 -WebhookUrl "https://hooks.slack.com/services/..." `
    -Title "IT Baseline Checks Completed" `
    -Message "All scheduled checks completed." `
    -Severity Info `
    -Category Automation `
    -PayloadFormat BlockKit `
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

    [string]$Category,

    [ValidateSet('PlainText', 'BlockKit')]
    [string]$PayloadFormat = 'PlainText',

    [switch]$PassThru
)

begin {
    $ErrorActionPreference = 'Stop'
}

process {
    $timestamp = (Get-Date).ToString('u')
    $displayCategory = if ($Category) { $Category } else { 'General' }
    $severityIcon = switch ($Severity) {
        'Info'     { ':information_source:' }
        'Warning'  { ':warning:' }
        'Critical' { ':rotating_light:' }
    }
    $fallbackText = "$severityIcon $Title - $Message"

    $payload = if ($PayloadFormat -eq 'BlockKit') {
        @{
            text   = $fallbackText
            blocks = @(
                @{
                    type = 'header'
                    text = @{
                        type = 'plain_text'
                        text = "$severityIcon $Title"
                    }
                },
                @{
                    type = 'section'
                    text = @{
                        type = 'mrkdwn'
                        text = $Message
                    }
                },
                @{
                    type   = 'section'
                    fields = @(
                        @{ type = 'mrkdwn'; text = "*Severity*`n$Severity" },
                        @{ type = 'mrkdwn'; text = "*Category*`n$displayCategory" },
                        @{ type = 'mrkdwn'; text = "*Timestamp*`n$timestamp" }
                    )
                }
            )
        }
    } else {
        @{
            text = "$fallbackText`nSeverity: $Severity`nCategory: $displayCategory`nTimestamp: $timestamp"
        }
    }

    if ($PassThru) {
        $payload
    }

    if ($PSCmdlet.ShouldProcess($WebhookUrl, 'Send Slack webhook alert')) {
        try {
            $json = $payload | ConvertTo-Json -Depth 10
            Invoke-RestMethod -Method Post -Uri $WebhookUrl -Body $json -ContentType 'application/json' | Out-Null
            Write-Host '[SUCCESS] Alert sent to Slack.' -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to send Slack alert: $($_.Exception.Message)"
        }
    }
}

end { }
