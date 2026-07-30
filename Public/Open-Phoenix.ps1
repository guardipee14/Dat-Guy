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
            -ErrorAction Stop

    Write-PhoenixLog `
        -Level Info `
        -Message (
            "Opening Phoenix control center in $resolvedMode mode."
        )

    switch ($resolvedMode) {
        'Desktop' {

            try {
                Show-PhoenixDesktop
            }
            catch {

                if ($NoFallback) {
                    throw
                }

                Write-Warning (
                    'Phoenix desktop mode failed: {0}' -f
                    $_.Exception.Message
                )

                Write-Warning (
                    'Opening the console interface instead.'
                )

                Show-PhoenixConsole
            }
        }

        'Console' {
            Show-PhoenixConsole
        }
    }
}
