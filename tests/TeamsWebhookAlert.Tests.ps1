Describe 'Teams webhook alert sender' {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent $PSScriptRoot
        $script:TeamsAlertScript = Join-Path $script:RepoRoot 'scripts/notifications/teams_webhook_alert.ps1'
    }

    It 'builds a default MessageCard payload and posts it as JSON' {
        Mock Invoke-RestMethod {}

        $payload = & $script:TeamsAlertScript `
            -WebhookUrl 'https://example.test/webhook' `
            -Title 'Backup Warning' `
            -Message 'Backup completed with warnings.' `
            -Severity Warning `
            -PassThru

        $payload.summary | Should -Be 'Backup Warning'
        $payload.themeColor | Should -Be 'FFC300'
        $payload.text | Should -Be 'Backup completed with warnings.'
        $payload.sections[0].facts[0].value | Should -Be 'Warning'

        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'Post' -and
            $Uri -eq 'https://example.test/webhook' -and
            $ContentType -eq 'application/json' -and
            (($Body | ConvertFrom-Json).themeColor -eq 'FFC300')
        }
    }

    It 'builds an AdaptiveCard payload for high-signal alerts' {
        Mock Invoke-RestMethod {}

        $payload = & $script:TeamsAlertScript `
            -WebhookUrl 'https://example.test/webhook' `
            -Title 'Baseline Completed' `
            -Message 'All checks completed.' `
            -Severity Critical `
            -CardFormat AdaptiveCard `
            -PassThru

        $payload.type | Should -Be 'message'
        $payload.attachments[0].contentType | Should -Be 'application/vnd.microsoft.card.adaptive'
        $payload.attachments[0].content.type | Should -Be 'AdaptiveCard'
        $payload.attachments[0].content.body[0].text | Should -Be 'Baseline Completed'
        $payload.attachments[0].content.body[0].color | Should -Be 'Attention'
        $payload.attachments[0].content.body[2].facts[0].value | Should -Be 'Critical'
        $payload.attachments[0].content.body[2].facts[1].value | Should -Be 'General'

        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            (($Body | ConvertFrom-Json).attachments[0].content.type -eq 'AdaptiveCard') -and
            (($Body | ConvertFrom-Json).attachments[0].content.body[0].color -eq 'Attention')
        }
    }

    It 'routes alerts by exact category and severity before falling back' {
        Mock Invoke-RestMethod {}

        $env:TEAMS_WEBHOOK_DEFAULT = 'https://example.test/default'
        $env:TEAMS_WEBHOOK_CRITICAL = 'https://example.test/critical'
        $env:TEAMS_WEBHOOK_COMPLIANCE = 'https://example.test/compliance'
        $env:TEAMS_WEBHOOK_COMPLIANCE_CRITICAL = 'https://example.test/compliance-critical'

        $configPath = Join-Path $TestDrive 'routes.json'
        @'
{
  "default": { "environmentVariable": "TEAMS_WEBHOOK_DEFAULT" },
  "severity": {
    "Critical": { "environmentVariable": "TEAMS_WEBHOOK_CRITICAL" }
  },
  "categories": {
    "Compliance": {
      "default": { "environmentVariable": "TEAMS_WEBHOOK_COMPLIANCE" },
      "Critical": { "environmentVariable": "TEAMS_WEBHOOK_COMPLIANCE_CRITICAL" }
    }
  }
}
'@ | Set-Content -Path $configPath

        $payload = & $script:TeamsAlertScript `
            -RoutingConfigPath $configPath `
            -Category Compliance `
            -Title 'Compliance Failure' `
            -Message 'Immediate review required.' `
            -Severity Critical `
            -PassThru

        $payload.sections[0].facts[1].value | Should -Be 'Compliance'
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://example.test/compliance-critical'
        }
    }

    It 'falls back from category default to severity and global default routes' {
        Mock Invoke-RestMethod {}

        $env:TEAMS_WEBHOOK_DEFAULT = 'https://example.test/default'
        $env:TEAMS_WEBHOOK_CRITICAL = 'https://example.test/critical'
        $env:TEAMS_WEBHOOK_AUTOMATION = 'https://example.test/automation'

        $configPath = Join-Path $TestDrive 'fallback-routes.json'
        @'
{
  "default": { "environmentVariable": "TEAMS_WEBHOOK_DEFAULT" },
  "severity": {
    "Critical": { "environmentVariable": "TEAMS_WEBHOOK_CRITICAL" }
  },
  "categories": {
    "Automation": {
      "default": { "environmentVariable": "TEAMS_WEBHOOK_AUTOMATION" }
    }
  }
}
'@ | Set-Content -Path $configPath

        & $script:TeamsAlertScript `
            -RoutingConfigPath $configPath `
            -Category Automation `
            -Title 'Automation Notice' `
            -Message 'Routine run.' `
            -Severity Info

        & $script:TeamsAlertScript `
            -RoutingConfigPath $configPath `
            -Category Identity `
            -Title 'Identity Failure' `
            -Message 'Immediate review required.' `
            -Severity Critical

        & $script:TeamsAlertScript `
            -RoutingConfigPath $configPath `
            -Category Identity `
            -Title 'Identity Notice' `
            -Message 'Routine run.' `
            -Severity Info

        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $Uri -eq 'https://example.test/automation' }
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $Uri -eq 'https://example.test/critical' }
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $Uri -eq 'https://example.test/default' }
    }

    It 'previews the payload with WhatIf without posting to Teams' {
        Mock Invoke-RestMethod {}

        $payload = & $script:TeamsAlertScript `
            -WebhookUrl 'https://example.test/webhook' `
            -Title 'Preview' `
            -Message 'Do not send.' `
            -Severity Info `
            -WhatIf `
            -PassThru

        $payload.themeColor | Should -Be '0078D7'
        Should -Invoke Invoke-RestMethod -Times 0 -Exactly
    }

    It 'surfaces webhook failures to callers' {
        Mock Invoke-RestMethod { throw 'network unavailable' }

        {
            & $script:TeamsAlertScript `
                -WebhookUrl 'https://example.test/webhook' `
                -Title 'Failure' `
                -Message 'This should fail.' `
                -Severity Critical
        } | Should -Throw '*Failed to send Teams alert: network unavailable*'
    }
}
