function Update-PhoenixDriver {

    [CmdletBinding()]
    [OutputType([Result])]
    param()

    [datetime]$startedAt = Get-Date
    [string]$progressActivity =
        'Phoenix driver stage'

    $ProgressPreference = 'Continue'

    Write-Progress `
        -Id 2 `
        -Activity $progressActivity `
        -Status '0% complete - Preparing driver scan...' `
        -PercentComplete 0

    Write-Host (
        '[  0%] Preparing driver scan...'
    ) -ForegroundColor Cyan

    try {

        [string]$pnputilPath =
            Join-Path `
                $env:WINDIR `
                'System32\pnputil.exe'

        if (
            -not (
                Test-Path `
                    -LiteralPath $pnputilPath
            )
        ) {

            [Result]$result = [Result]::Failure(
                "PnPUtil was not found: $pnputilPath"
            )

            $result.Code =
                'PHX_DRIVER_TOOL_NOT_FOUND'

            return $result
        }

        Write-PhoenixLog `
            -Level Info `
            -Message 'Scanning for device changes.'

        Write-Progress `
            -Id 2 `
            -Activity $progressActivity `
            -Status '25% complete - Scanning devices...' `
            -CurrentOperation 'PnPUtil device scan' `
            -PercentComplete 25

        Write-Host (
            '[ 25%] Scanning devices for hardware changes...'
        ) -ForegroundColor Cyan

        $scanOutput = @(
            & $pnputilPath `
                /scan-devices `
                2>&1
        )

        [int]$exitCode =
            $LASTEXITCODE

        $scanOutput |
            ForEach-Object {
                Write-Host $_
            }

        if ($exitCode -notin @(0, 1641, 3010)) {

            [timespan]$elapsed =
                (Get-Date) - $startedAt

            [Result]$result = [Result]::Failure(
                "Driver scan failed with exit code $exitCode."
            )

            $result.Code =
                'PHX_DRIVER_SCAN_FAILED'

            $result.Errors = @(
                $scanOutput |
                    ForEach-Object {
                        $_.ToString()
                    }
            )

            $result.Data = [pscustomobject]@{
                Stage          = 'Driver'
                ExitCode       = $exitCode
                DriverCount    = 0
                PresentCount   = 0
                ElapsedSeconds = [Math]::Round(
                    $elapsed.TotalSeconds,
                    2
                )
            }

            return $result
        }

        Write-Progress `
            -Id 2 `
            -Activity $progressActivity `
            -Status '70% complete - Refreshing driver inventory...' `
            -CurrentOperation 'Enumerating installed drivers' `
            -PercentComplete 70

        Write-Host (
            '[ 70%] Refreshing installed-driver inventory...'
        ) -ForegroundColor Cyan

        [Driver[]]$drivers = @(
            Get-PhoenixDriver
        )

        [int]$driverCount =
            $drivers.Count

        [int]$presentCount = @(
            $drivers |
                Where-Object {
                    $_.Present
                }
        ).Count

        [timespan]$elapsed =
            (Get-Date) - $startedAt

        Write-Progress `
            -Id 2 `
            -Activity $progressActivity `
            -Status '100% complete - Driver stage finished.' `
            -CurrentOperation (
                "$driverCount drivers detected"
            ) `
            -PercentComplete 100

        Write-Host (
            '[100%] Driver scan and inventory refresh complete.'
        ) -ForegroundColor Green

        Write-Host ''
        Write-Host 'Phoenix driver summary' `
            -ForegroundColor Cyan

        Write-Host '----------------------'

        Write-Host (
            'Drivers detected : {0}' -f
            $driverCount
        )

        Write-Host (
            'Present drivers  : {0}' -f
            $presentCount
        )

        Write-Host (
            'Scan exit code   : {0}' -f
            $exitCode
        )

        Write-Host (
            'Elapsed time     : {0}' -f
            $elapsed.ToString(
                'hh\:mm\:ss'
            )
        )

        [Result]$result =
            [Result]::Success()

        if ($exitCode -in @(1641, 3010)) {

            $result.Code =
                'PHX_DRIVER_SCAN_REBOOT_REQUIRED'

            $result.Message = (
                'Driver scan completed; a reboot is required.'
            )
        }
        else {

            $result.Code =
                'PHX_DRIVER_SCAN_COMPLETE'

            $result.Message = (
                'Driver scan and inventory refresh completed successfully.'
            )
        }

        $result.Data = [pscustomobject]@{
            Stage          = 'Driver'
            ExitCode       = $exitCode
            DriverCount    = $driverCount
            PresentCount   = $presentCount
            ElapsedSeconds = [Math]::Round(
                $elapsed.TotalSeconds,
                2
            )
        }

        return $result
    }
    catch {

        [timespan]$elapsed =
            (Get-Date) - $startedAt

        [Result]$result = [Result]::Failure(
            "Driver stage failed: $($_.Exception.Message)"
        )

        $result.Code =
            'PHX_DRIVER_SCAN_FAILED'

        $result.Errors = @(
            $_.Exception.Message
        )

        $result.Data = [pscustomobject]@{
            Stage          = 'Driver'
            ExitCode       = $null
            DriverCount    = 0
            PresentCount   = 0
            ElapsedSeconds = [Math]::Round(
                $elapsed.TotalSeconds,
                2
            )
        }

        return $result
    }
    finally {

        Start-Sleep -Milliseconds 500

        Write-Progress `
            -Id 2 `
            -Activity $progressActivity `
            -Completed
    }
}