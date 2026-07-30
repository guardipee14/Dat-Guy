function Start-Phoenix {

    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Resume,

        [Parameter()]
        [switch]$Force
    )

    $existingContext =
        Get-PhoenixContext

    [bool]$hadReadyContext =
        Test-PhoenixContext `
            -Context $existingContext

    if (
        $Resume -and
        (
            $Force -or
            -not $hadReadyContext
        )
    ) {

        Write-Host ''
        Write-Host 'Resuming Phoenix after elevation...' -ForegroundColor Cyan
        Write-Host ''
    }

    $context =
        Initialize-Phoenix `
            -Resume:$Resume `
            -Force:$Force `
            -ErrorAction Stop

    [bool]$createdContext =
        $Force -or
        -not $hadReadyContext

    if (-not $createdContext) {
        return
    }

    try {
        Install-MissingProviders `
            -Context $context `
            -ErrorAction Stop
    }
    catch {
        [string]$providerWarning = (
            'Provider bootstrap did not complete: {0}' -f
            $_.Exception.Message
        )

        $context.InitializationWarnings.Add(
            $providerWarning
        )

        Write-Warning $providerWarning
    }

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
