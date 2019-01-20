function Test-ServicesConfigFile
{
    [CmdletBinding()]
    param (
        # Config files to check
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]]
        $ConfigPath,
        # Schema file to check the config files against
        [Parameter(Mandatory)]
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
            $cfg = Get-Content -Path $config | ConvertTo-Json -Depth 3
            $domain = $cfg.domain

            $cfgRpt = @{
                Path  = $config
                Hosts = @()
            }
            foreach ($host in $cfg.hosts)
            {
                $hostRpt = $null
                $conn = Test-Connection -ComputerName $host.name
                if ($null -ne $conn)
                {
                    $hostRpt = [PSCustomObject]@{
                        HostName      = $host.name
                        HostAvailable = $true
                        Servies       = @()
                    }
                    foreach ($displayName in $host.ServiceDisplayNames)
                    {
                        $serviceRpt = @{
                            ServiceDisplayName = $service.DisplayName
                        }
                        try
                        {
                            $service = Get-AEMOService -DisplayNamePattern $displayName -HostPattern $host.name -Domain $domain
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
                else
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
            $hostsCount = $cfgRpt.Length
            $servicesCount = 0
            $issuesCount = 0

            Write-Host "Config: $($cfgRpt.Path)"
            foreach ($hostRpt in $cfgRpt.Hosts)
            {
                $hostOk = ($null -eq ($hostRpt.Services | Where-Object { -not $_.ServiceAvailable }))
                $serviceCount = $hostRpt.Servies.Length
                $issuesCount = ($hostRpt.Services | Where-Object { -not $_.ServiceAvailable }).Length

                $servicesCount += $hostRpt.Services.Length

                if (-not $hostOk)
                {
                    Write-Host "    [-] $($hostRpt.HostName): $issuesCount/$serviceCount issues found" -ForegroundColor Red
                    foreach ($serviceRpt in $hostRpt.Services)
                    {
                        if ($serviceRpt.ServiceAvailable -and $Full)
                        {
                            Write-Host "        [+] $($serviceRpt.ServiceDisplayName)" -ForegroundColor Green
                        }
                        else
                        {
                            Write-Host "        [-] $($serviceRpt.ServiceDisplayName): $($serviceRpt.Reason)" -ForegroundColor Red
                            $issuesCount += 1
                        }
                    }
                }
            }

            Write-Host "Hosts: $hostsCount, Services: $servicesCount, Issues: $issuesCount"
        }
    }

    end
    {
    }
}