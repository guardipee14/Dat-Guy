function Initialize-PhoenixLogging {

    [CmdletBinding()]
    param()

    $script:PhoenixContext.Logger =
        [PhoenixLogger]::new(
            $script:PhoenixContext.ProjectRoot
        )
}