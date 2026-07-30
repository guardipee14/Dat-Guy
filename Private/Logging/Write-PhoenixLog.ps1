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

    $context =
        Get-PhoenixContext

    if (
        $null -eq $context -or
        $null -eq $context.Logger
    ) {
        throw 'Phoenix logging has not been initialized.'
    }

    $context.Logger.Write(
        $Level,
        $Message
    )
}
