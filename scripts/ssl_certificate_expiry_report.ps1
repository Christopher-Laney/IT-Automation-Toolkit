<#
.SYNOPSIS
  Checks SSL/TLS certificate expiration for one or more HTTPS endpoints.

.DESCRIPTION
  Reads a list of URLs/hostnames, opens an SSL connection, and reports
  certificate subject, issuer, and days until expiration.

.PARAMETER EndpointList
  Path to a text file with URLs/hosts, or an array of URLs.

.PARAMETER Port
  TCP port for SSL. Default: 443.

.PARAMETER ExportPath
  CSV path for the report.

.PARAMETER WarnDays
  Number of days before expiry to flag as "Warning".

.EXAMPLE
  .\ssl_certificate_expiry_report.ps1 -EndpointList .\config\ssl_endpoints.txt -ExportPath .\reports\ssl_expiry.csv -WarnDays 30
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [object]$EndpointList,

    [int]$Port = 443,

    [string]$ExportPath = ".\reports\ssl_expiry.csv",

    [int]$WarnDays = 30
)

begin {
    $ErrorActionPreference = 'Stop'

    $dir = Split-Path $ExportPath
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    if ($EndpointList -is [string] -and (Test-Path $EndpointList)) {
        $targets = Get-Content -Path $EndpointList | Where-Object { $_ -and $_.Trim() -ne '' } | Select-Object -Unique
    }
    elseif ($EndpointList -is [System.Collections.IEnumerable]) {
        $targets = $EndpointList
    }
    else {
        throw "EndpointList must be a path to a file or an array of URLs/hostnames."
    }

    $list = New-Object System.Collections.Generic.List[object]
}

process {
    foreach ($t in $targets) {
        $host = $t
        if ($t -match "^https?://(.+?)(/|$)") {
            $host = $Matches[1]
        }

        Write-Verbose "Checking $host:$Port ..."

        try {
            $tcpClient = New-Object System.Net.Sockets.TcpClient($host, $Port)
            try {
                $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false, ({ $true }))
                $sslStream.AuthenticateAsClient($host)
                $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $sslStream.RemoteCertificate

                $expires = $cert.NotAfter
                $daysLeft = (New-TimeSpan -Start (Get-Date) -End $expires).Days

                $status = if ($daysLeft -lt 0) { 'Expired' }
                          elseif ($daysLeft -le $WarnDays) { 'Warning' }
                          else { 'OK' }

                $list.Add([pscustomobject]@{
                    Endpoint     = $t
                    Host         = $host
                    Port         = $Port
                    Subject      = $cert.Subject
                    Issuer       = $cert.Issuer
                    NotBefore    = $cert.NotBefore
                    NotAfter     = $cert.NotAfter
                    DaysUntilExp = $daysLeft
                    Status       = $status
                })
            }
            finally {
                $tcpClient.Close()
            }
        }
        catch {
            $list.Add([pscustomobject]@{
                Endpoint     = $t
                Host         = $host
                Port         = $Port
                Subject      = ''
                Issuer       = ''
                NotBefore    = $null
                NotAfter     = $null
                DaysUntilExp = $null
                Status       = "ERROR: $($_.Exception.Message)"
            })
        }
    }
}

end {
    $list | Export-Csv -NoTypeInformation -Path $ExportPath
    Write-Host "SSL certificate report saved to $ExportPath"
}
