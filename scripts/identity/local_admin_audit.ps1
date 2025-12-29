<#
.SYNOPSIS
  Audits local Administrators group membership on one or more Windows systems.

.DESCRIPTION
  Connects to each specified computer, enumerates the local Administrators group,
  and exports results for security review.

.PARAMETER ComputerList
  Path to a text file with hostnames, or an array of hostnames.

.PARAMETER ExportPath
  CSV path for the audit report.

.EXAMPLE
  .\local_admin_audit.ps1 -ComputerList .\config\computers.txt -ExportPath .\reports\local_admins.csv
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [object]$ComputerList,

    [string]$ExportPath = ".\reports\local_admins.csv"
)

begin {
    $ErrorActionPreference = 'Stop'

    $dir = Split-Path $ExportPath
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    if ($ComputerList -is [string] -and (Test-Path $ComputerList)) {
        $computers = Get-Content -Path $ComputerList | Where-Object { $_ -and $_.Trim() -ne '' } | Select-Object -Unique
    }
    elseif ($ComputerList -is [System.Collections.IEnumerable]) {
        $computers = $ComputerList
    }
    else {
        throw "ComputerList must be a path to a file or an array of hostnames."
    }

    $results = New-Object System.Collections.Generic.List[object]
}

process {
    foreach ($c in $computers) {
        Write-Verbose "Auditing local admins on $c..."

        try {
            $session = New-PSSession -ComputerName $c -ErrorAction Stop
            $admins = Invoke-Command -Session $session -ScriptBlock {
                try {
                    $group = [ADSI]"WinNT://./Administrators,group"
                    $members = @()
                    $group.psbase.Invoke('Members') | ForEach-Object {
                        $obj = $_.GetType().InvokeMember('Name','GetProperty',$null,$_,$null)
                        $path = $_.GetType().InvokeMember('AdsPath','GetProperty',$null,$_,$null)
                        [pscustomobject]@{
                            Name = $obj
                            AdsPath = $path
                        }
                    }
                }
                catch {
                    Write-Error "Failed to read Administrators group: $($_.Exception.Message)"
                }
            }

            if ($admins) {
                foreach ($a in $admins) {
                    $results.Add([pscustomobject]@{
                        ComputerName = $c
                        AccountName  = $a.Name
                        AdsPath      = $a.AdsPath
                        Timestamp    = (Get-Date)
                    })
                }
            }
            else {
                $results.Add([pscustomobject]@{
                    ComputerName = $c
                    AccountName  = ''
                    AdsPath      = ''
                    Timestamp    = (Get-Date)
                })
            }

            Remove-PSSession $session
        }
        catch {
            $results.Add([pscustomobject]@{
                ComputerName = $c
                AccountName  = 'ERROR'
                AdsPath      = $_.Exception.Message
                Timestamp    = (Get-Date)
            })
        }
    }
}

end {
    $results | Export-Csv -NoTypeInformation -Path $ExportPath
    Write-Host "Local admin audit saved to $ExportPath"
}
