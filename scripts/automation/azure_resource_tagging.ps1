<#
.SYNOPSIS
  Enforce required tags on Azure resources.

.DESCRIPTION
  Audits resources in given subscriptions/resource groups, sets missing tags,
  and outputs a change report.

.PARAMETER SubscriptionId
  Optional single subscription. If omitted, uses current context.

.PARAMETER ResourceGroup
  Optional RG filter. If omitted, processes all RGs.

.PARAMETER RequiredTags
  Hashtable of required tags and default values.

.PARAMETER ReportPath
  CSV path for audit/change report.

.EXAMPLE
  .\azure_resource_tagging.ps1 -SubscriptionId xxxxx -ResourceGroup RG-App \
    -RequiredTags @{ Owner='it@company.com'; Environment='Prod'; CostCenter='1234' } \
    -ReportPath .\reports\tag_audit.csv

#>

[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$SubscriptionId,
  [string]$ResourceGroup,
  [hashtable]$RequiredTags = @{ Owner='unknown@org.local'; Environment='Unknown'; CostCenter='0000' },
  [string]$ReportPath = ".\reports\azure_tag_audit.csv"
)

begin {
  $ErrorActionPreference = 'Stop'
  $null = New-Item -ItemType Directory -Path (Split-Path $ReportPath) -Force -ErrorAction SilentlyContinue

  # Requires: Az.Accounts, Az.Resources
  # Connect-AzAccount
  if ($SubscriptionId) {
    Select-AzSubscription -SubscriptionId $SubscriptionId | Out-Null
  }
}

process {
  $filter = @{}
  if ($ResourceGroup) { $filter['ResourceGroupName'] = $ResourceGroup }

  Write-Verbose "Fetching Azure resources..."
  $resources = Get-AzResource @filter

  $changes = New-Object System.Collections.Generic.List[object]

  foreach ($r in $resources) {
    $current = @{}
    if ($r.Tags) { $current = @{} + $r.Tags } # clone

    $missing = @{}
    foreach ($k in $RequiredTags.Keys) {
      if (-not $current.ContainsKey($k) -or [string]::IsNullOrWhiteSpace($current[$k])) {
        $missing[$k] = $RequiredTags[$k]
      }
    }

    if ($missing.Count -gt 0) {
      $newTags = $current + $missing
      if ($PSCmdlet.ShouldProcess("$($r.ResourceType)/$($r.Name)", "Set tags: $($missing.Keys -join ', ')")) {
        try {
          Set-AzResource -ResourceId $r.ResourceId -Tag $newTags -Force -ErrorAction Stop | Out-Null
          $status = 'Updated'
        }
        catch {
          $status = "Failed: $($_.Exception.Message)"
        }
      } else {
        $status = 'WhatIf'
      }
    } else {
      $status = 'Compliant'
    }

    $changes.Add([pscustomobject]@{
      Name          = $r.Name
      Type          = $r.ResourceType
      ResourceGroup = $r.ResourceGroupName
      Location      = $r.Location
      Status        = $status
      MissingTags   = ($missing.Keys -join ';')
    })
  }

  $changes | Export-Csv -NoTypeInformation -Path $ReportPath
  Write-Host "Tag audit saved to $ReportPath"
}
