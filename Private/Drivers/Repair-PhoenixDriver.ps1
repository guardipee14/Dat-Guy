function Repair-PhoenixDriver {

    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'High',
        DefaultParameterSetName = 'ByInfName'
    )]
    [OutputType([Result[]])]
    param(
        [Parameter(
            Mandatory,
            Position = 0,
            ParameterSetName = 'ByInfName'
        )]
        [ValidateNotNullOrEmpty()]
        [string[]]$InfName,

        [Parameter(
            Mandatory,
            ParameterSetName = 'ProblemOnly'
        )]
        [switch]$ProblemOnly
    )

    $results =
        [System.Collections.Generic.List[Result]]::new()

    [string[]]$resolvedInfNames = @()

    if ($ProblemOnly) {

        try {

            $problemDeviceIds = @(
                Get-CimInstance `
                    -ClassName Win32_PnPEntity `
                    -ErrorAction Stop |
                    Where-Object {
                        [int]$_.ConfigManagerErrorCode -ne 0
                    } |
                    ForEach-Object {
                        [string]$_.DeviceID
                    }
            )

            if ($problemDeviceIds.Count -gt 0) {

                $resolvedInfNames = @(
                    Get-CimInstance `
                        -ClassName Win32_PnPSignedDriver `
                        -ErrorAction Stop |
                        Where-Object {
                            [string]$_.DeviceID -in
                                $problemDeviceIds
                        } |
                        ForEach-Object {
                            [string]$_.InfName
                        } |
                        Where-Object {
                            -not [string]::IsNullOrWhiteSpace($_)
                        } |
                        Sort-Object -Unique
                )
            }
        }
        catch {

            [Result]$result = [Result]::Failure(
                "Problem-driver discovery failed: $($_.Exception.Message)"
            )

            $result.Code =
                'PHX_DRIVER_REPAIR_DISCOVERY_FAILED'

            $result.Errors = @(
                $_.Exception.Message
            )

            return @($result)
        }
    }
    else {
        $resolvedInfNames = @(
            $InfName |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace($_)
                } |
                Sort-Object -Unique
        )
    }

    if ($resolvedInfNames.Count -eq 0) {

        [Result]$result = [Result]::Success()
        $result.Code = 'PHX_DRIVER_REPAIR_NOT_NEEDED'
        $result.Message = (
            'No driver repair candidates were found.'
        )

        return @($result)
    }

    [string]$pnputilPath =
        Join-Path `
            $env:WINDIR `
            'System32\pnputil.exe'

    if (-not (Test-Path -LiteralPath $pnputilPath)) {

        [Result]$result = [Result]::Failure(
            "PnPUtil was not found: $pnputilPath"
        )

        $result.Code =
            'PHX_DRIVER_TOOL_NOT_FOUND'

        return @($result)
    }

    foreach ($resolvedInfName in $resolvedInfNames) {

        [string]$driverPath =
            Join-Path `
                $env:WINDIR `
                (
                    'INF\{0}' -f
                    $resolvedInfName
                )

        if (-not (Test-Path -LiteralPath $driverPath)) {

            [Result]$result = [Result]::Failure(
                "Driver INF was not found: $driverPath"
            )

            $result.Code = 'PHX_DRIVER_REPAIR_INF_NOT_FOUND'
            $result.Data = [pscustomobject]@{
                Stage   = 'DriverRepair'
                InfName = $resolvedInfName
                Path    = $driverPath
            }

            $results.Add($result)
            continue
        }

        if (
            -not $PSCmdlet.ShouldProcess(
                $resolvedInfName,
                'Reinstall driver package'
            )
        ) {

            [Result]$result = [Result]::Success()
            $result.Code = 'PHX_DRIVER_REPAIR_SKIPPED'
            $result.Message = (
                "Driver repair was skipped for '$resolvedInfName'."
            )
            $result.Data = [pscustomobject]@{
                Stage   = 'DriverRepair'
                InfName = $resolvedInfName
                Path    = $driverPath
            }

            $results.Add($result)
            continue
        }

        Write-PhoenixLog `
            -Level Info `
            -Message (
                "Repairing driver package '$resolvedInfName'."
            )

        $output = @(
            & $pnputilPath `
                /add-driver `
                $driverPath `
                /install `
                2>&1
        )

        [int]$exitCode = $LASTEXITCODE

        if ($exitCode -in @(0, 1641, 3010)) {

            [Result]$result = [Result]::Success()
            $result.Code = if ($exitCode -in @(1641, 3010)) {
                'PHX_DRIVER_REPAIR_REBOOT_REQUIRED'
            }
            else {
                'PHX_DRIVER_REPAIR_COMPLETE'
            }

            $result.Message = (
                "Driver repair completed for '$resolvedInfName'."
            )
        }
        else {

            [Result]$result = [Result]::Failure(
                "Driver repair failed for '$resolvedInfName' with exit code $exitCode."
            )

            $result.Code = 'PHX_DRIVER_REPAIR_FAILED'
            $result.Errors = @(
                $output |
                    ForEach-Object {
                        $_.ToString()
                    }
            )
        }

        $result.Data = [pscustomobject]@{
            Stage          = 'DriverRepair'
            InfName        = $resolvedInfName
            Path           = $driverPath
            ExitCode       = $exitCode
            RebootRequired = $exitCode -in @(1641, 3010)
            Output         = @($output)
        }

        $results.Add($result)
    }

    return $results.ToArray()
}
