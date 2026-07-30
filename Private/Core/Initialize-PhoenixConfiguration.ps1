function Initialize-PhoenixConfiguration {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PhoenixContext]$Context
    )

    if ($null -eq $Context.Configuration) {
        $Context.Configuration =
            [PhoenixConfiguration]::new(
                $Context.ProjectRoot
            )
    }

    $Context.Configuration.Load()
}
