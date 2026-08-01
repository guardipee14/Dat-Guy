function Start-Phoenix {

    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Resume,

        [Parameter()]
        [switch]$Force,

        [Parameter(DontShow)]
        [switch]$SkipProviderBootstrap,

        [Parameter(DontShow)]
        [switch]$EnsureProviderBootstrap
    )

    if ($SkipProviderBootstrap -and $EnsureProviderBootstrap) {
        throw (
            'Provider bootstrap cannot be skipped and ensured ' +
            'during the same Phoenix start.'
        )
    }

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

    if (
        -not $createdContext -and
        -not $EnsureProviderBootstrap
    ) {
        return
    }

    if (-not $SkipProviderBootstrap) {
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
    }

    if (-not $createdContext) {
        return
    }

    if ($Resume) {
        Write-PhoenixLog `
            -Level Info `
            -Message 'Phoenix resumed in an elevated process.'
    }
    else {

        Write-PhoenixLog `
            -Level Info `
            -Message $(if ($SkipProviderBootstrap) {
                'Phoenix started with provider bootstrap deferred.'
            }
            else {
                'Phoenix started.'
            })
    }
}
