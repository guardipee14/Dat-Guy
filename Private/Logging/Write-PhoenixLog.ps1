function Write-PhoenixLog {

    [CmdletBinding()]
    param(
        [ValidateSet('Info','Success','Warning','Error')]
        [string]$Level = 'Info',

        [Parameter(Mandatory)]
        [string]$Message
    )

    if (-not $script:PhoenixContext.Logger) {
        throw "Phoenix logging has not been initialized."
    }

    $script:PhoenixContext.Logger.Write(
        $Level,
        $Message
    )
}