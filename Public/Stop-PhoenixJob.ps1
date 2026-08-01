using module '..\Classes\Phoenix.Classes.psm1'

function Stop-PhoenixJob {

    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'Medium'
    )]
    [OutputType([PhoenixBackgroundOperation])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNull()]
        [PhoenixBackgroundOperation]$Operation
    )

    process {
        if (-not $PSCmdlet.ShouldProcess(
            $Operation.OperationId,
            'Cancel and clean up Phoenix background job'
        )) {
            return $Operation
        }

        try {
            return (
                Stop-PhoenixBackgroundOperation `
                    -Operation $Operation
            )
        }
        finally {
            $null =
                Remove-PhoenixBackgroundOperation `
                    -Operation $Operation
        }
    }
}
