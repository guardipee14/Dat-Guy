function Update-PhoenixDriver {

    [CmdletBinding()]
    [OutputType([Result])]
    param(
        [Parameter()]
        [switch]$ScanOnly,

        [Parameter()]
        [switch]$Unattended,

        [Parameter()]
        [string[]]$UpdateId = @()
    )

    [datetime]$startedAt = Get-Date
    [string]$progressActivity =
        'Phoenix driver stage'

    $ProgressPreference = 'Continue'

    Write-Progress `
        -Id 2 `
        -Activity $progressActivity `
        -Status '0% complete - Preparing driver workflow...' `
        -PercentComplete 0

    Write-Host (
        '[  0%] Preparing Phoenix driver workflow...'
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
            -Message 'Scanning for device changes before Windows Update driver discovery.'

        Write-Progress `
            -Id 2 `
            -Activity $progressActivity `
            -Status '10% complete - Scanning devices...' `
            -CurrentOperation 'PnPUtil device scan' `
            -PercentComplete 10

        Write-Host (
            '[ 10%] Scanning devices for hardware changes...'
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
                Stage              = 'Driver'
                Mode               = if ($ScanOnly) { 'ScanOnly' } else { 'Install' }
                ExitCode           = $exitCode
                SearchResultCode   = 0
                DownloadResultCode = 0
                AvailableCount     = 0
                SelectedCount      = 0
                CachedCount        = 0
                DownloadedCount    = 0
                InstalledCount     = 0
                PartialCount       = 0
                SkippedCount       = 0
                FailedCount        = 1
                RebootRequired     = $false
                DriverCount        = 0
                PresentCount       = 0
                ElapsedSeconds     = [Math]::Round(
                    $elapsed.TotalSeconds,
                    2
                )
                Updates            = @()
            }

            return $result
        }

        $windowsUpdateResult =
            Invoke-PhoenixWindowsUpdateDriver `
                -ScanOnly:$ScanOnly `
                -Unattended:$Unattended `
                -UpdateId $UpdateId `
                -ProgressId 2 `
                -ProgressActivity $progressActivity

        Write-Progress `
            -Id 2 `
            -Activity $progressActivity `
            -Status '90% complete - Refreshing driver inventory...' `
            -CurrentOperation 'Enumerating installed drivers' `
            -PercentComplete 90

        Write-Host (
            '[ 90%] Refreshing installed-driver inventory...'
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
                '{0} installed drivers detected' -f
                $driverCount
            ) `
            -PercentComplete 100

        Write-Host (
            '[100%] Phoenix driver workflow complete.'
        ) -ForegroundColor Green

        Write-Host ''
        Write-Host 'Phoenix driver summary' `
            -ForegroundColor Cyan

        Write-Host '----------------------'

        Write-Host (
            'Mode              : {0}' -f
            $(if ($ScanOnly) { 'Scan only' } else { 'Windows Update install' })
        )

        Write-Host (
            'Updates available : {0}' -f
            $windowsUpdateResult.AvailableCount
        )

        Write-Host (
            'Updates selected  : {0}' -f
            $windowsUpdateResult.SelectedCount
        )

        Write-Host (
            'Already cached    : {0}' -f
            $windowsUpdateResult.CachedCount
        )

        Write-Host (
            'Downloaded        : {0}' -f
            $windowsUpdateResult.DownloadedCount
        )

        Write-Host (
            'Installed         : {0}' -f
            $windowsUpdateResult.InstalledCount
        )

        Write-Host (
            'Partial           : {0}' -f
            $windowsUpdateResult.PartialCount
        )

        Write-Host (
            'Skipped           : {0}' -f
            $windowsUpdateResult.SkippedCount
        )

        Write-Host (
            'Failed            : {0}' -f
            $windowsUpdateResult.FailedCount
        )

        Write-Host (
            'Reboot required   : {0}' -f
            $windowsUpdateResult.RebootRequired
        )

        Write-Host (
            'Drivers detected  : {0}' -f
            $driverCount
        )

        Write-Host (
            'Present drivers   : {0}' -f
            $presentCount
        )

        Write-Host (
            'Scan exit code    : {0}' -f
            $exitCode
        )

        Write-Host (
            'Elapsed time      : {0}' -f
            $elapsed.ToString(
                'hh\:mm\:ss'
            )
        )

        [Result]$result = $null

        if (-not $windowsUpdateResult.OperationSucceeded) {

            [string]$failureMessage =
                'The Windows Update driver workflow did not complete successfully.'

            if (
                $windowsUpdateResult.InstalledCount -gt 0 -or
                $windowsUpdateResult.PartialCount -gt 0
            ) {
                $failureMessage =
                    'The Windows Update driver workflow completed with partial results.'
            }

            $result = [Result]::Failure(
                $failureMessage
            )

            if (
                $windowsUpdateResult.InstalledCount -gt 0 -or
                $windowsUpdateResult.PartialCount -gt 0
            ) {
                $result.Code =
                    'PHX_DRIVER_UPDATE_PARTIAL'
            }
            else {
                $result.Code =
                    'PHX_DRIVER_UPDATE_FAILED'
            }
        }
        else {

            $result = [Result]::Success()

            if ($ScanOnly) {
                $result.Code =
                    'PHX_DRIVER_SCAN_COMPLETE'

                $result.Message = (
                    'Windows Update driver discovery and installed-driver inventory refresh completed.'
                )
            }
            elseif ($windowsUpdateResult.AvailableCount -eq 0) {
                $result.Code =
                    'PHX_DRIVER_ALREADY_CURRENT'

                $result.Message =
                    'No applicable Windows Update driver updates were found.'
            }
            elseif (
                $windowsUpdateResult.SkippedCount -gt 0 -and
                $windowsUpdateResult.InstalledCount -eq 0
            ) {
                $result.Code =
                    'PHX_DRIVER_UPDATE_SKIPPED'

                $result.Message =
                    'Applicable driver updates were skipped by the current policy.'
            }
            elseif ($windowsUpdateResult.RebootRequired) {
                $result.Code =
                    'PHX_DRIVER_UPDATE_REBOOT_REQUIRED'

                $result.Message = (
                    'Windows Update driver installation completed; a reboot is required.'
                )
            }
            else {
                $result.Code =
                    'PHX_DRIVER_UPDATE_COMPLETE'

                $result.Message = (
                    'Windows Update driver installation and inventory refresh completed successfully.'
                )
            }
        }

        $result.Warnings = @(
            $windowsUpdateResult.Warnings
        )

        $result.Errors = @(
            $windowsUpdateResult.Errors
        )

        $result.Data = [pscustomobject]@{
            Stage              = 'Driver'
            Mode               = if ($ScanOnly) { 'ScanOnly' } else { 'Install' }
            ExitCode           = $exitCode
            SearchResultCode   = $windowsUpdateResult.SearchResultCode
            DownloadResultCode = $windowsUpdateResult.DownloadResultCode
            AvailableCount     = $windowsUpdateResult.AvailableCount
            SelectedCount      = $windowsUpdateResult.SelectedCount
            CachedCount        = $windowsUpdateResult.CachedCount
            DownloadedCount    = $windowsUpdateResult.DownloadedCount
            InstalledCount     = $windowsUpdateResult.InstalledCount
            PartialCount       = $windowsUpdateResult.PartialCount
            SkippedCount       = $windowsUpdateResult.SkippedCount
            FailedCount        = $windowsUpdateResult.FailedCount
            RebootRequired     = $windowsUpdateResult.RebootRequired
            DriverCount        = $driverCount
            PresentCount       = $presentCount
            ElapsedSeconds     = [Math]::Round(
                $elapsed.TotalSeconds,
                2
            )
            Updates            = @(
                $windowsUpdateResult.Updates
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
            'PHX_DRIVER_UPDATE_FAILED'

        $result.Errors = @(
            $_.Exception.Message
        )

        $result.Data = [pscustomobject]@{
            Stage              = 'Driver'
            Mode               = if ($ScanOnly) { 'ScanOnly' } else { 'Install' }
            ExitCode           = $null
            SearchResultCode   = 0
            DownloadResultCode = 0
            AvailableCount     = 0
            SelectedCount      = 0
            CachedCount        = 0
            DownloadedCount    = 0
            InstalledCount     = 0
            PartialCount       = 0
            SkippedCount       = 0
            FailedCount        = 1
            RebootRequired     = $false
            DriverCount        = 0
            PresentCount       = 0
            ElapsedSeconds     = [Math]::Round(
                $elapsed.TotalSeconds,
                2
            )
            Updates            = @()
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
