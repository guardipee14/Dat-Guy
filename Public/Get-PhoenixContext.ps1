function Get-PhoenixContext {

    [CmdletBinding()]
    [OutputType([PhoenixContext])]
    param(
        [Parameter()]
        [switch]$RequireInitialized
    )

    $context = $script:PhoenixContext

    if (
        $RequireInitialized -and
        -not (
            Test-PhoenixContext `
                -Context $context
        )
    ) {

        [string]$details =
            $script:PhoenixLastInitializationError

        if ([string]::IsNullOrWhiteSpace($details)) {
            $details = 'Start-Phoenix has not completed successfully.'
        }

        throw (
            'Phoenix context is not initialized. {0}' -f
            $details
        )
    }

    return $context
}
