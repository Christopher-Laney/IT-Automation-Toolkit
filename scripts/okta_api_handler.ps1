<#
.SYNOPSIS
  Okta API utility for IT Automation Toolkit.

.DESCRIPTION
  Uses ./config/okta_api_config.json for configuration.
  - Resolves secrets from environment or Azure Key Vault, falling back to config.
  - Handles rate limiting, retries (401/429/5xx), pagination.
  - Provides helper cmdlets: Get-OktaUsers, Get-OktaUserByLogin, Create/Activate/Deactivate user,
    Add/Remove user to/from group, Get-OktaGroups, Get-OktaEvents, etc.
  - Supports -WhatIf on operations that change state.

.REQUIREMENTS
  PowerShell 7+ recommended.
  For Azure Key Vault support: Az.Accounts, Az.KeyVault (optional).
  Okta token should be stored in:
    1) $env:OKTA_API_TOKEN   (recommended), or
    2) Azure Key Vault (if configured), or
    3) config file (as last resort for dev only).

.EXAMPLES
  # List first 100 users
  .\okta_api_handler.ps1; Get-OktaUsers -Limit 100

  # Find a user by login/email
  .\okta_api_handler.ps1; Get-OktaUserByLogin -Login "jane.doe@contoso.com"

  # Create + Activate new user (dry-run)
  .\okta_api_handler.ps1; New-OktaUser -Profile @{firstName='Jane';lastName='Doe';email='jane.doe@contoso.com';login='jane.doe@contoso.com'} -Activate -WhatIf

  # Deactivate user
  .\okta_api_handler.ps1; Disable-OktaUser -UserId "00u1abcdXYZ123"

  # Group ops
  .\okta_api_handler.ps1; Add-OktaUserToGroup -UserId "00u1abcdXYZ123" -GroupId "00g9groupABC"
#>

[CmdletBinding()]
param(
  [string]$ConfigPath = ".\config\okta_api_config.json"
)

# ---------------------------
# Internal: load configuration
# ---------------------------
function Get-OktaConfig {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    throw "Okta config not found: $Path"
  }
  $cfg = Get-Content -Raw -Path $Path | ConvertFrom-Json -AsHashtable

  # Resolve token preference: ENV → KeyVault → config
  $token = $env:OKTA_API_TOKEN
  if (-not $token -and $cfg.auth.secureStorage -match 'KeyVault|AzureKeyVault') {
    try {
      if (-not (Get-Module Az.KeyVault -ListAvailable)) { Import-Module Az.KeyVault -ErrorAction Stop }
      # Expect a secret name 'OktaApiToken' unless overridden by env or config
      $secretName = $env:OKTA_API_TOKEN_SECRET_NAME
      if (-not $secretName) { $secretName = "OktaApiToken" }
      $kvName = $env:AZURE_KEYVAULT_NAME
      if (-not $kvName) { $kvName = $cfg.auth.keyVaultName }
      if ($kvName) {
        $secret = Get-AzKeyVaultSecret -VaultName $kvName -Name $secretName -ErrorAction Stop
        $token = $secret.SecretValueText
      }
    } catch {
      Write-Warning "Azure Key Vault token retrieval failed: $($_.Exception.Message)"
    }
  }
  if (-not $token) { $token = $cfg.apiToken } # dev fallback

  if (-not $token -or $token -eq "REPLACE_ME_WITH_SECURE_SECRET_REFERENCE") {
    throw "Okta API token not resolved. Set `OKTA_API_TOKEN` env var or configure Key Vault/okta_api_config.json."
  }

  # Build base headers
  $headers = @{
    "Accept"        = "application/json"
    "Content-Type"  = "application/json"
    ($cfg.auth.tokenHeader) = "$($cfg.auth.tokenPrefix) $token"
  }

  # Normalize baseUrl and API version
  $baseUrl = $cfg.baseUrl.TrimEnd('/')
  $apiVer  = if ($cfg.apiVersion) { $cfg.apiVersion } else { "v1" }

  # Rate limit bucket
  $rate = @{
    rateLimitPerMinute = [int]($cfg.rateLimitPerMinute | ForEach-Object { $_ }) 
    lastTick           = [DateTime]::UtcNow.AddMinutes(-1)
    count              = 0
  }

  return @{
    cfg      = $cfg
    headers  = $headers
    baseUrl  = $baseUrl
    apiVer   = $apiVer
    rate     = $rate
    logger   = $cfg.logging
  }
}

# ---------------------------
# Logging utility
# ---------------------------
function Write-OktaLog {
  param(
    [string]$Message,
    [ValidateSet('Debug','Info','Warn','Error')] [string]$Level = 'Info'
  )
  if ($script:CTX.logger.enabled -ne $true) { return }
  $targetLevel = $script:CTX.cfg.logging.logLevel
  $levels = @('Debug','Info','Warn','Error')
  if ($levels.IndexOf($Level) -lt $levels.IndexOf($targetLevel)) { return }

  $line = "[{0}] [{1}] {2}" -f (Get-Date -Format o), $Level, $Message
  $file = $script:CTX.cfg.logging.logFile
  try {
    $dir = Split-Path -Parent $file
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    Add-Content -LiteralPath $file -Value $line
  } catch {
    Write-Verbose "Log write failed: $($_.Exception.Message)"
  }
}

# ---------------------------
# Rate limiter
# ---------------------------
function Invoke-RateLimit {
  $limit = [math]::Max(1, $script:CTX.rate.rateLimitPerMinute)
  $window = 60
  $now = [DateTime]::UtcNow

  # reset window every minute
  if (($now - $script:CTX.rate.lastTick).TotalSeconds -ge $window) {
    $script:CTX.rate.lastTick = $now
    $script:CTX.rate.count = 0
  }

  if ($script:CTX.rate.count -ge $limit) {
    $sleep = [int]([math]::Ceiling($window - ($now - $script:CTX.rate.lastTick).TotalSeconds))
    if ($sleep -gt 0) {
      Write-OktaLog "Rate limit reached ($limit/min). Sleeping $sleep seconds..." 'Warn'
      Start-Sleep -Seconds $sleep
      $script:CTX.rate.lastTick = [DateTime]::UtcNow
      $script:CTX.rate.count = 0
    }
  }
  $script:CTX.rate.count++
}

# ---------------------------
# Core HTTP with retry/paging
# ---------------------------
function Invoke-OktaApi {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][ValidateSet('GET','POST','PUT','DELETE')][string]$Method,
    [Parameter(Mandatory=$true)][string]$Path,
    [hashtable]$Query,
    [object]$Body,
    [switch]$Paginate,
    [switch]$WhatIf
  )

  $uriBuilder = [System.UriBuilder]("{0}{1}" -f $script:CTX.baseUrl, $Path)
  if ($Query) {
    $qs = ($Query.GetEnumerator() | ForEach-Object { "{0}={1}" -f [uri]::EscapeDataString($_.Key), [uri]::EscapeDataString([string]$_.Value) }) -join "&"
    $uriBuilder.Query = $qs
  }
  $uri = $uriBuilder.Uri.AbsoluteUri

  $maxRetries = 5
  $attempt = 0
  $results = @()
  $nextLink = $null

  do {
    $attempt++
    Invoke-RateLimit

    if ($PSBoundParameters.ContainsKey('Body') -and $Body -ne $null) {
      $payload = if ($Body -is [string]) { $Body } else { ($Body | ConvertTo-Json -Depth 12) }
    } else { $payload = $null }

    $msg = "$Method $uri"
    if ($payload) { $msg += " (body length: $($payload.Length))" }
    Write-OktaLog $msg 'Debug'

    try {
      if ($WhatIf) {
        Write-Host "[WhatIf] $Method $uri"
        if ($payload) { Write-Host "[WhatIf] Body: $payload" }
        return @()
      }

      $resp = Invoke-WebRequest -Method $Method -Uri $uri -Headers $script:CTX.headers -TimeoutSec $script:CTX.cfg.timeouts.readTimeoutSeconds -Body $payload -ErrorAction Stop

      # collect page
      if ($Paginate) {
        if ($resp.Content) {
          $chunk = $resp.Content | ConvertFrom-Json
          if ($chunk -is [System.Collections.IEnumerable]) {
            $results += $chunk
          } else {
            $results += ,$chunk
          }
        }
        # Okta pagination: Link header with rel="next"
        $nextLink = $null
        if ($resp.Headers["Link"]) {
          $links = $resp.Headers["Link"] -split ","
          foreach ($l in $links) {
            if ($l -match '<([^>]+)>;\s*rel="next"') {
              $nextLink = $matches[1]
              break
            }
          }
        }
        if ($nextLink) {
          $uri = $nextLink
          continue
        } else {
          break
        }
      } else {
        if ($resp.Content) { return ($resp.Content | ConvertFrom-Json) }
        return $null
      }
    }
    catch {
      $status = $_.Exception.Response.StatusCode.Value__
      $rid = $_.Exception.Response.Headers["x-okta-request-id"]
      Write-OktaLog "HTTP error $status ($rid): $($_.Exception.Message)" 'Warn'

      # Auth retry on 401, if configured
      if ($status -eq 401 -and $script:CTX.cfg.auth.retryOn401 -eq $true -and $attempt -lt $maxRetries) {
        Start-Sleep -Seconds ([int][math]::Min(30, [math]::Pow(2, $attempt)))
        continue
      }

      # Backoff on 429/5xx
      if (($status -eq 429 -or $status -ge 500) -and $attempt -lt $maxRetries) {
        $delay = [int][math]::Min(60, [math]::Pow(2, $attempt))
        Write-OktaLog "Retrying in $delay sec (attempt $attempt of $maxRetries)..." 'Warn'
        Start-Sleep -Seconds $delay
        continue
      }

      throw
    }
  } while ($true)

  return $results
}

# ---------------------------
# Public helper cmdlets
# ---------------------------

function Get-OktaUsers {
  [CmdletBinding()]
  param(
    [int]$Limit = 200,
    [int]$MaxPages = 10
  )
  $q = @{ limit = $Limit }
  $items = Invoke-OktaApi -Method GET -Path $script:CTX.cfg.endpoints.users -Query $q -Paginate
  if ($MaxPages -gt 0 -and $items.Count -gt ($Limit * $MaxPages)) {
    return $items[0..(($Limit * $MaxPages)-1)]
  }
  return $items
}

function Get-OktaUserByLogin {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][string]$Login
  )
  $q = @{ q = $Login; limit = 1 }
  $res = Invoke-OktaApi -Method GET -Path $script:CTX.cfg.endpoints.users -Query $q -Paginate:$false
  if ($res -is [System.Collections.IEnumerable]) {
    return ($res | Where-Object { $_.profile.login -eq $Login } | Select-Object -First 1)
  }
  return $null
}

function New-OktaUser {
  [CmdletBinding(SupportsShouldProcess=$true)]
  param(
    [Parameter(Mandatory=$true)][hashtable]$Profile,
    [hashtable]$Credentials,
    [switch]$Activate,
    [switch]$WhatIf
  )

  $body = @{
    profile = $Profile
  }
  if ($Credentials) { $body.credentials = $Credentials }

  if ($PSCmdlet.ShouldProcess($Profile.login, "Create Okta user")) {
    $user = Invoke-OktaApi -Method POST -Path $script:CTX.cfg.endpoints.users -Body $body -WhatIf:$WhatIf
    if ($Activate -and $user.id) {
      Enable-OktaUser -UserId $user.id -WhatIf:$WhatIf | Out-Null
    }
    return $user
  }
}

function Enable-OktaUser {
  [CmdletBinding(SupportsShouldProcess=$true)]
  param(
    [Parameter(Mandatory=$true)][string]$UserId,
    [switch]$WhatIf
  )
  $path = $script:CTX.cfg.endpoints.activateUser.Replace("{userId}", $UserId)
  if ($PSCmdlet.ShouldProcess($UserId, "Activate Okta user")) {
    return Invoke-OktaApi -Method POST -Path $path -Body @{} -WhatIf:$WhatIf
  }
}

function Disable-OktaUser {
  [CmdletBinding(SupportsShouldProcess=$true)]
  param(
    [Parameter(Mandatory=$true)][string]$UserId,
    [switch]$WhatIf
  )
  $path = $script:CTX.cfg.endpoints.deactivateUser.Replace("{userId}", $UserId)
  if ($PSCmdlet.ShouldProcess($UserId, "Deactivate Okta user")) {
    return Invoke-OktaApi -Method POST -Path $path -Body @{} -WhatIf:$WhatIf
  }
}

function Get-OktaGroups {
  [CmdletBinding()]
  param(
    [int]$Limit = 200
  )
  $q = @{ limit = $Limit }
  Invoke-OktaApi -Method GET -Path $script:CTX.cfg.endpoints.groups -Query $q -Paginate
}

function Add-OktaUserToGroup {
  [CmdletBinding(SupportsShouldProcess=$true)]
  param(
    [Parameter(Mandatory=$true)][string]$UserId,
    [Parameter(Mandatory=$true)][string]$GroupId,
    [switch]$WhatIf
  )
  $path = "{0}/{1}/users/{2}" -f $script:CTX.cfg.endpoints.groups, $GroupId, $UserId
  if ($PSCmdlet.ShouldProcess("$UserId → $GroupId", "Add user to group")) {
    Invoke-OktaApi -Method PUT -Path $path -Body $null -WhatIf:$WhatIf | Out-Null
    Write-Host "Added user $UserId to group $GroupId"
  }
}

function Remove-OktaUserFromGroup {
  [CmdletBinding(SupportsShouldProcess=$true)]
  param(
    [Parameter(Mandatory=$true)][string]$UserId,
    [Parameter(Mandatory=$true)][string]$GroupId,
    [switch]$WhatIf
  )
  $path = "{0}/{1}/users/{2}" -f $script:CTX.cfg.endpoints.groups, $GroupId, $UserId
  if ($PSCmdlet.ShouldProcess("$UserId × $GroupId", "Remove user from group")) {
    Invoke-OktaApi -Method DELETE -Path $path -WhatIf:$WhatIf | Out-Null
    Write-Host "Removed user $UserId from group $GroupId"
  }
}

function Get-OktaEvents {
  [CmdletBinding()]
  param(
    [string]$Since,  # ISO 8601
    [int]$Limit = 200
  )
  $q = @{ limit = $Limit }
  if ($Since) { $q.since = $Since }
  Invoke-OktaApi -Method GET -Path $script:CTX.cfg.endpoints.events -Query $q -Paginate
}

# ---------------------------
# Initialize context on import
# ---------------------------
$script:CTX = Get-OktaConfig -Path $ConfigPath
Write-OktaLog "okta_api_handler initialized for $($script:CTX.baseUrl)" 'Info'
