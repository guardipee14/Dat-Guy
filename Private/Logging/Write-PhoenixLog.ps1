function Write-PhoenixLog {

    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet(
            'Debug',
            'Verbose',
            'Info',
            'Success',
            'Warning',
            'Error'
        )]
        [string]$Level = 'Info',

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Message
    )

    if (
        $null -eq $script:PhoenixContext -or
        $null -eq $script:PhoenixContext.Logger
    ) {
        throw 'Phoenix logging has not been initialized.'
    }

    $script:PhoenixContext.Logger.Write(
        $Level,
        $Message
    )
}