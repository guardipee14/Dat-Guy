function Invoke-PhoenixControlCenterDriverAction {

    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([Result[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet(
            'ScanUpdates',
            'InstallSelected',
            'UpdateAll',
            'RepairSelected',
            'RepairProblems',
            'RemoveSelected'
        )]
        [string]$Action,

        [Parameter()]
        [string[]]$UpdateId = @(),

        [Parameter()]
        [string[]]$InfName = @(),

        [Parameter()]
        [switch]$Unattended
    )

    if ($Action -eq 'ScanUpdates') {
        return @(
            Update-PhoenixDriver `
                -ScanOnly `
                -Unattended:$Unattended
        )
    }

    $resolvedUpdateIds = @(
        $UpdateId |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace($_)
            } |
            Sort-Object -Unique
    )

    $resolvedInfNames = @(
        $InfName |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace($_)
            } |
            Sort-Object -Unique
    )

    if (
        $Action -eq 'InstallSelected' -and
        $resolvedUpdateIds.Count -eq 0
    ) {

        [Result]$result = [Result]::Failure(
            'Select at least one driver update.'
        )

        $result.Code =
            'PHX_CONTROL_CENTER_DRIVER_SELECTION_REQUIRED'

        return @($result)
    }

    if (
        $Action -in @(
            'RepairSelected'
            'RemoveSelected'
        ) -and
        $resolvedInfNames.Count -eq 0
    ) {

        [Result]$result = [Result]::Failure(
            'Select at least one installed driver.'
        )

        $result.Code =
            'PHX_CONTROL_CENTER_DRIVER_SELECTION_REQUIRED'

        return @($result)
    }

    if (
        -not $PSCmdlet.ShouldProcess(
            $env:COMPUTERNAME,
            $Action
        )
    ) {

        [Result]$result = [Result]::Success()
        $result.Code =
            'PHX_CONTROL_CENTER_ACTION_SKIPPED'
        $result.Message =
            "Driver action '$Action' was skipped."

        return @($result)
    }

    try {

        switch ($Action) {
            'InstallSelected' {
                return @(
                    Update-PhoenixDriver `
                        -UpdateId $resolvedUpdateIds `
                        -Unattended:$Unattended
                )
            }

            'UpdateAll' {
                return @(
                    Update-PhoenixDriver `
                        -Unattended:$Unattended
                )
            }

            'RepairSelected' {
                return @(
                    Repair-PhoenixDriver `
                        -InfName $resolvedInfNames `
                        -Confirm:$false
                )
            }

            'RepairProblems' {
                return @(
                    Repair-PhoenixDriver `
                        -ProblemOnly `
                        -Confirm:$false
                )
            }

            'RemoveSelected' {
                return @(
                    Remove-PhoenixDriver `
                        -InfName $resolvedInfNames `
                        -Confirm:$false
                )
            }
        }
    }
    catch {

        [Result]$result = [Result]::Failure(
            "Driver action '$Action' failed: $($_.Exception.Message)"
        )

        $result.Code =
            'PHX_CONTROL_CENTER_DRIVER_ACTION_FAILED'

        $result.Errors = @(
            $_.Exception.Message
        )

        return @($result)
    }
}
