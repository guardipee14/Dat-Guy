function Initialize-PhoenixLogging {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PhoenixContext]$Context
    )

    [string]$minimumLevel = 'Info'
    [int]$maximumLogFiles = 20

    if ($null -ne $Context.Configuration) {

        $configuredLevel =
            $Context.Configuration.Get(
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
            $Context.Configuration.Get(
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

    if ($null -eq $Context.Logger) {

        $Context.Logger =
            [PhoenixLogger]::new(
                $Context.ProjectRoot
            )
    }

    $Context.Logger.Configure(
        $minimumLevel,
        $maximumLogFiles
    )
}
