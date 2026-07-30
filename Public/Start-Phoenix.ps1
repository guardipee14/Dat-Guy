function Start-Phoenix {

    [CmdletBinding()]
    param(
        [switch]$Resume
    )

    if ($Resume) {

        Write-Host ''
        Write-Host 'Resuming Phoenix after elevation...' -ForegroundColor Cyan
        Write-Host ''
    }

    Initialize-Phoenix

    Initialize-PhoenixLogging

    if ($Resume) {

        Write-PhoenixLog `
            -Level Info `
            -Message 'Phoenix resumed in an elevated process.'
    }
    else {

        Write-PhoenixLog `
            -Level Info `
            -Message 'Phoenix started.'
    }
}