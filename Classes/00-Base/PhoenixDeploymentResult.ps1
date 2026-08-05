class PhoenixDeploymentResult {

    [string]$Name
    [PhoenixDeploymentOperation]$Operation
    [string]$Target
    [bool]$Success
    [string]$Code
    [string]$Message
    [object]$Data
    [string[]]$Warnings
    [string[]]$Errors
    [PhoenixDeploymentDecision]$Decision
    [PhoenixPrivilegeLevel]$RequiredPrivilege
    [bool]$RequiresRestart
    [bool]$TimedOut
    [bool]$Cancelled
    [bool]$HasExitCode
    [int]$ExitCode
    [bool]$CleanupRequired
    [bool]$CleanupSucceeded
    [datetime]$StartedAtUtc
    [datetime]$CompletedAtUtc
    [timespan]$Duration

    PhoenixDeploymentResult() {

        $this.Name = ''
        $this.Operation =
            [PhoenixDeploymentOperation]::Unknown
        $this.Target = ''
        $this.Success = $false
        $this.Code = 'PHX_DEPLOYMENT_NOT_STARTED'
        $this.Message =
            'Deployment operation has not started.'
        $this.Warnings = @()
        $this.Errors = @()
        $this.RequiredPrivilege =
            [PhoenixPrivilegeLevel]::User
        $this.RequiresRestart = $false
        $this.TimedOut = $false
        $this.Cancelled = $false
        $this.HasExitCode = $false
        $this.ExitCode = 0
        $this.CleanupRequired = $false
        $this.CleanupSucceeded = $false
        $this.StartedAtUtc = [datetime]::UtcNow
        $this.CompletedAtUtc = [datetime]::MinValue
        $this.Duration = [timespan]::Zero
    }

    [void] Complete(
        [bool]$Succeeded,
        [string]$ResultCode,
        [string]$ResultMessage
    ) {

        $this.Success = $Succeeded
        $this.Code = $ResultCode
        $this.Message = $ResultMessage
        $this.CompletedAtUtc = [datetime]::UtcNow
        $this.Duration =
            $this.CompletedAtUtc - $this.StartedAtUtc

        if (
            -not $Succeeded -and
            $this.Errors.Count -eq 0 -and
            -not [string]::IsNullOrWhiteSpace(
                $ResultMessage
            )
        ) {
            $this.Errors = @($ResultMessage)
        }
    }

    [bool] IsComplete() {

        return (
            $this.CompletedAtUtc -gt
            [datetime]::MinValue
        )
    }
}
