Set-StrictMode -Version 2

function Get-AEMOService
{
    $rand = Get-Random
    switch ($rand % 3)
    {
        0
        {
            return @{test = $true}
        }
        1
        {
            throw "Access is denied"
        }
        2
        {
            throw "other"
        }
    }
}

function Test-Connection
{
    # return @{test = $true}
    $rand = Get-Random
    if ($rand % 2 -eq 0)
    {
        return @{}
    }
    else
    {
        throw "not found"
    }
}

function Test-ServicesConfigFile
{
    [CmdletBinding()]
    param (
        # Config files to check
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]]
        $ConfigPath,
        # Schema file to check the config files against
        [Parameter()]
        [string]
        $SchemaPath,
        [Parameter()]
        [switch]
        $Full
    )

    begin
    {
    }

    process
    {
        # TODO: Check config files against schema

        $rpt = @()
        foreach ($config in $ConfigPath)
        {
            $cfg = Get-Content -Path $config | ConvertFrom-Json
            $domain = $cfg.domain

            $cfgRpt = @{
                Path  = $config
                Hosts = @()
            }
            foreach ($host in $cfg.hosts)
            {
                $hostRpt = $null
                try
                {
                    $conn = Test-Connection -ComputerName $host.name
                    if ($null -ne $conn)
                    {
                        $hostRpt = [PSCustomObject]@{
                            HostName      = $host.name
                            HostAvailable = $true
                            Services      = @()
                        }
                        foreach ($displayName in $host.ServiceDisplayNames)
                        {
                            $serviceRpt = @{
                                ServiceDisplayName = $displayName
                            }
                            try
                            {
                                Get-AEMOService -DisplayNamePattern $displayName -HostPattern $host.name -Domain $domain | Out-Null
                                $serviceRpt.ServiceAvailable = $true
                            }
                            catch
                            {
                                $serviceRpt.ServiceAvailable = $false
                                if ($PSItem.Exception.Message.ToLower().Contains("Access is denied".ToLower()))
                                {
                                    $serviceRpt.Reason = "Access is denied"
                                }
                                else
                                {
                                    $serviceRpt.Reason = "Service does not exist"
                                }
                            }
                            $hostRpt.Services += [pscustomobject]$serviceRpt
                        }
                    }
                }
                catch
                {
                    $hostRpt = [PSCustomObject]@{
                        HostName      = $host.name
                        HostAvailable = $false
                    }
                }
                $cfgRpt.Hosts += $hostRpt

            }
            $rpt += $cfgRpt
        }

        foreach ($cfgRpt in $rpt)
        {
            $hostsCount = 0
            $hostIssuesCount = 0
            $servicesCount = 0
            $serviceIssuesCount = 0

            Write-Host "Config: $($cfgRpt.Path)"
            foreach ($hostRpt in $cfgRpt.Hosts)
            {
                if (-not $hostRpt.HostAvailable)
                {
                    Write-Host "    [-] $($hostRpt.HostName): Not found" -ForegroundColor Red
                    $hostIssuesCount += 1
                    continue
                }
                else
                {
                    $hostsCount += 1
                }

                $hostOk = ($null -eq ($hostRpt.Services | Where-Object { -not $_.ServiceAvailable }))

                if (-not $hostOk)
                {
                    $totalServices = $hostRpt.Services.Length
                    $issuesCount = ($hostRpt.Services | Where-Object { -not $_.ServiceAvailable } | Measure-Object).Count
                    Write-Host "    [-] $($hostRpt.HostName): $issuesCount/$totalServices issues found" -ForegroundColor Red
                    foreach ($serviceRpt in $hostRpt.Services)
                    {
                        if ($serviceRpt.ServiceAvailable)
                        {
                            if ($Full)
                            {
                                Write-Host "        [+] $($serviceRpt.ServiceDisplayName)" -ForegroundColor Green
                            }
                            $servicesCount += 1
                        }
                        else
                        {
                            Write-Host "        [-] $($serviceRpt.ServiceDisplayName): $($serviceRpt.Reason)" -ForegroundColor Red
                            $serviceIssuesCount += 1
                        }
                    }
                }
            }

            Write-Host "Hosts: $hostsCount available, $hostIssuesCount unavailable"
            Write-Host "Services: $servicesCount available, $serviceIssuesCount unavailable"
        }
    }

    end
    {
    }
}