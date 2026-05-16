Describe 'Slack webhook alert sender' {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent $PSScriptRoot
        $script:SlackAlertScript = Join-Path $script:RepoRoot 'scripts/notifications/slack_webhook_alert.ps1'
    }

    It 'builds a plain-text payload and posts it as JSON' {
        Mock Invoke-RestMethod {}

        $payload = & $script:SlackAlertScript `
            -WebhookUrl 'https://example.test/slack' `
            -Title 'Backup Warning' `
            -Message 'Backup completed with warnings.' `
            -Severity Warning `
            -PassThru

        $payload.text | Should -Match 'Backup Warning'
        $payload.text | Should -Match 'Severity: Warning'
        $payload.text | Should -Match 'Category: General'

        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'Post' -and
            $Uri -eq 'https://example.test/slack' -and
            $ContentType -eq 'application/json' -and
            (($Body | ConvertFrom-Json).text -match 'Backup Warning')
        }
    }

    It 'builds a Block Kit payload for richer alerts' {
        Mock Invoke-RestMethod {}

        $payload = & $script:SlackAlertScript `
            -WebhookUrl 'https://example.test/slack' `
            -Title 'Compliance Failure' `
            -Message 'Immediate review required.' `
            -Severity Critical `
            -Category Compliance `
            -PayloadFormat BlockKit `
            -PassThru

        $payload.blocks[0].type | Should -Be 'header'
        $payload.blocks[0].text.text | Should -Match 'Compliance Failure'
        $payload.blocks[2].fields[0].text | Should -Match 'Critical'
        $payload.blocks[2].fields[1].text | Should -Match 'Compliance'

        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            (($Body | ConvertFrom-Json).blocks[0].type -eq 'header') -and
            (($Body | ConvertFrom-Json).blocks[2].fields[1].text -match 'Compliance')
        }
    }

    It 'previews the payload with WhatIf without posting to Slack' {
        Mock Invoke-RestMethod {}

        $payload = & $script:SlackAlertScript `
            -WebhookUrl 'https://example.test/slack' `
            -Title 'Preview' `
            -Message 'Do not send.' `
            -Severity Info `
            -WhatIf `
            -PassThru

        $payload.text | Should -Match 'Preview'
        Should -Invoke Invoke-RestMethod -Times 0 -Exactly
    }

    It 'surfaces webhook failures to callers' {
        Mock Invoke-RestMethod { throw 'network unavailable' }

        {
            & $script:SlackAlertScript `
                -WebhookUrl 'https://example.test/slack' `
                -Title 'Failure' `
                -Message 'This should fail.' `
                -Severity Critical
        } | Should -Throw '*Failed to send Slack alert: network unavailable*'
    }
}
