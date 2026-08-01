using module '..\Classes\Phoenix.Classes.psm1'

function Receive-PhoenixJob {

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNull()]
        [PhoenixBackgroundOperation]$Operation,

        [Parameter()]
        [switch]$Wait,

        [Parameter()]
        [ValidateRange(50, 5000)]
        [int]$PollIntervalMilliseconds = 250,

        [Parameter()]
        [switch]$Keep
    )

    process {
        $received = $null

        do {
            $received =
                Receive-PhoenixBackgroundOperation `
                    -Operation $Operation

            if (
                $Wait -and
                -not $received.IsCompleted
            ) {
                Start-Sleep `
                    -Milliseconds $PollIntervalMilliseconds
            }
        }
        while (
            $Wait -and
            -not $received.IsCompleted
        )

        if (
            $received.IsCompleted -and
            -not $Keep
        ) {
            $null =
                Remove-PhoenixBackgroundOperation `
                    -Operation $Operation
        }

        return $received
    }
}
