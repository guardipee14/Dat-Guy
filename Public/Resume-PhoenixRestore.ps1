using module '..\Classes\Phoenix.Classes.psm1'

function Resume-PhoenixRestore {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    [OutputType([Result])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$SessionId,

        [Parameter()]
        [AllowEmptyString()]
        [string]$CheckpointRoot = '',

        [Parameter()]
        [switch]$RetryFailed,

        [Parameter()]
        [switch]$StopOnError,

        [Parameter()]
        [switch]$Unattended
    )

    if (-not $PSCmdlet.ShouldProcess(
        $env:COMPUTERNAME,
        "Resume Phoenix restore session $SessionId"
    )) {
        return Invoke-PhoenixRestorePlan `
            -SessionId $SessionId `
            -CheckpointRoot $CheckpointRoot `
            -RetryFailed:$RetryFailed `
            -StopOnError:$StopOnError `
            -Unattended:$Unattended `
            -Confirm:$false `
            -WhatIf
    }

    return Invoke-PhoenixRestorePlan `
        -SessionId $SessionId `
        -CheckpointRoot $CheckpointRoot `
        -RetryFailed:$RetryFailed `
        -StopOnError:$StopOnError `
        -Unattended:$Unattended `
        -Confirm:$false
}
