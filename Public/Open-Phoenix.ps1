function Open-Phoenix {

    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateSet(
            'Auto',
            'Desktop',
            'Console'
        )]
        [string]$Mode = 'Auto',

        [Parameter()]
        [switch]$NoFallback
    )

    [bool]$isSta =
        (
            [Threading.Thread]::CurrentThread.ApartmentState -eq
                [Threading.ApartmentState]::STA
        )

    [bool]$desktopAvailable =
        $IsWindows -and
        $isSta

    [string]$resolvedMode = $Mode

    if ($Mode -eq 'Auto') {
        $resolvedMode = if ($IsWindows) {
            'Desktop'
        }
        else {
            'Console'
        }
    }

    if (
        $resolvedMode -eq 'Desktop' -and
        $IsWindows -and
        -not $isSta
    ) {

        [string]$projectRoot =
            Split-Path `
                -Path $PSScriptRoot `
                -Parent

        [string]$launcherPath =
            Join-Path `
                $projectRoot `
                'Tools\Start-PhoenixControlCenter.ps1'

        if (Test-Path -LiteralPath $launcherPath) {

            [string]$powerShellPath =
                (Get-Process -Id $PID).Path

            [string]$argumentString = (
                '-NoLogo -NoProfile -ExecutionPolicy Bypass -STA ' +
                "-File `"$launcherPath`" -Mode Desktop"
            )

            if ($NoFallback) {
                $argumentString += ' -NoFallback'
            }

            Start-Process `
                -FilePath $powerShellPath `
                -WorkingDirectory $projectRoot `
                -ArgumentList $argumentString `
                -ErrorAction Stop

            return
        }
    }

    if (
        $resolvedMode -eq 'Desktop' -and
        -not $desktopAvailable
    ) {

        if ($NoFallback) {
            throw (
                'The Phoenix desktop interface requires Windows ' +
                'and an STA PowerShell process.'
            )
        }

        Write-Warning (
            'The desktop interface is unavailable; ' +
            'opening the console interface instead.'
        )

        $resolvedMode = 'Console'
    }

    $null =
        Resolve-PhoenixContext `
            -SkipProviderBootstrap:(
                $resolvedMode -eq 'Desktop'
            ) `
            -ErrorAction Stop

    Write-PhoenixLog `
        -Level Info `
        -Message (
            "Opening Phoenix control center in $resolvedMode mode."
        )

    $showConsoleFallback = {
        $null =
            Start-Phoenix `
                -EnsureProviderBootstrap `
                -ErrorAction Stop

        Show-PhoenixConsole
    }

    switch ($resolvedMode) {
        'Desktop' {

            [int]$desktopAttempt = 0
            [int]$maximumDesktopAttempts = 3

            while ($true) {
                $desktopAttempt++

                try {
                    Show-PhoenixDesktop
                    return
                }
                catch {
                    $failure =
                        New-PhoenixControlCenterFailure `
                            -Component 'Desktop' `
                            -Operation 'Startup' `
                            -ErrorRecord $_ `
                            -Startup

                    $null =
                        Write-PhoenixControlCenterFailure `
                            -Failure $failure

                    if ($NoFallback) {
                        throw
                    }

                    [string]$recoveryAction = 'Console'

                    try {
                        $recoveryAction =
                            Show-PhoenixDesktopRecovery `
                                -Failure $failure
                    }
                    catch {
                        Write-Warning (
                            'Phoenix desktop recovery could not open: {0}' -f
                            $_.Exception.Message
                        )

                        $recoveryAction = 'Console'
                    }

                    switch ($recoveryAction) {
                        'Retry' {
                            if (
                                $desktopAttempt -lt
                                $maximumDesktopAttempts
                            ) {
                                continue
                            }

                            Write-Warning (
                                'Phoenix reached the desktop retry limit. ' +
                                'Opening the console interface instead.'
                            )

                            & $showConsoleFallback
                            return
                        }

                        'Reset' {
                            try {
                                $resetResult =
                                    Reset-PhoenixControlCenterUiConfiguration `
                                        -Confirm:$false

                                Write-PhoenixLog `
                                    -Level Warning `
                                    -Message $resetResult.Message
                            }
                            catch {
                                Write-Warning (
                                    'Phoenix could not reset the desktop layout: {0}' -f
                                    $_.Exception.Message
                                )
                            }

                            if (
                                $desktopAttempt -lt
                                $maximumDesktopAttempts
                            ) {
                                continue
                            }

                            & $showConsoleFallback
                            return
                        }

                        'Console' {
                            & $showConsoleFallback
                            return
                        }

                        default {
                            return
                        }
                    }
                }
            }
        }

        'Console' {
            Show-PhoenixConsole
        }
    }
}
