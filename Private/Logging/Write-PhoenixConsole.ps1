function Write-PhoenixConsole {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet(
            'Info',
            'Success',
            'Warning',
            'Error',
            'Verbose'
        )]
        [string]$Level = 'Info',

        [switch]$NoNewLine
    )

    $color = switch ($Level) {
        'Info'    { 'Cyan' }
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error'   { 'Red' }
        'Verbose' { 'DarkGray' }
    }

    if ($NoNewLine) {
        Write-Host $Message -ForegroundColor $color -NoNewline
    }
    else {
        Write-Host $Message -ForegroundColor $color
    }
}