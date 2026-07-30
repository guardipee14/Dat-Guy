function Resolve-PhoenixContext {

    [CmdletBinding()]
    [OutputType([PhoenixContext])]
    param()

    $context =
        Get-PhoenixContext

    if (
        -not (
            Test-PhoenixContext `
                -Context $context
        )
    ) {
        $null =
            Start-Phoenix `
                -ErrorAction Stop

        $context =
            Get-PhoenixContext `
                -RequireInitialized `
                -ErrorAction Stop
    }

    return $context
}
