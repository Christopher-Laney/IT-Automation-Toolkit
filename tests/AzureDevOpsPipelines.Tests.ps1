Describe 'Azure DevOps pipeline samples' {
  BeforeAll {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $validationPipelinePath = Join-Path $repoRoot 'samples/pipelines/azure-devops-validation.yml'
    $dashboardPipelinePath = Join-Path $repoRoot 'samples/pipelines/azure-devops-scheduled-dashboard.yml'
  }

  It 'provides a validation pipeline that mirrors repository quality checks' {
    Test-Path $validationPipelinePath | Should -BeTrue

    $content = Get-Content -Raw $validationPipelinePath
    $content | Should -Match 'Invoke-Pester -Path ./tests -CI'
    $content | Should -Match 'Invoke-ScriptAnalyzer -Path ./scripts'
    $content | Should -Match 'PSScriptAnalyzerSettings\.psd1'
  }

  It 'provides a scheduled dashboard pipeline that stays on sanitized sample data' {
    Test-Path $dashboardPipelinePath | Should -BeTrue

    $content = Get-Content -Raw $dashboardPipelinePath
    $content | Should -Match 'trigger: none'
    $content | Should -Match 'pr: none'
    $content | Should -Match 'dashboard_reports\.sample\.json'
    $content | Should -Match 'PublishPipelineArtifact@1'
  }
}
