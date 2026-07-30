function Initialize-PhoenixLogging {

    [CmdletBinding()]
    param()

    if ($null -eq $script:PhoenixContext) {
        throw 'Phoenix context has not been initialized.'
    }

    [string]$minimumLevel = 'Info'
    [int]$maximumLogFiles = 20

    if ($null -ne $script:PhoenixContext.Configuration) {

        $configuredLevel =
            $script:PhoenixContext.Configuration.Get(
                'LogLevel'
            )

        if (
            $null -ne $configuredLevel -and
            -not [string]::IsNullOrWhiteSpace(
                $configuredLevel.ToString()
            )
        ) {
            $minimumLevel = $configuredLevel.ToString()
        }

        $configuredMaximum =
            $script:PhoenixContext.Configuration.Get(
                'MaximumLogFiles'
            )

        [int]$parsedMaximum = 0

        if (
            $null -ne $configuredMaximum -and
            [int]::TryParse(
                $configuredMaximum.ToString(),
                [ref]$parsedMaximum
            ) -and
            $parsedMaximum -ge 1
        ) {
            $maximumLogFiles = $parsedMaximum
        }
    }

    if ($null -eq $script:PhoenixContext.Logger) {

        $script:PhoenixContext.Logger =
            [PhoenixLogger]::new(
                $script:PhoenixContext.ProjectRoot
            )
    }

    $script:PhoenixContext.Logger.Configure(
        $minimumLevel,
        $maximumLogFiles
    )
}