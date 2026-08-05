class PhoenixDeploymentDecision {

    [string]$Name
    [PhoenixDeploymentOperation]$Operation
    [string]$Target
    [bool]$Supported
    [bool]$Available
    [bool]$Eligible
    [bool]$Safe
    [bool]$Protected
    [bool]$RequiresApproval
    [bool]$ApprovalGranted
    [bool]$RequiresTargetIdentity
    [bool]$TargetIdentityConfirmed
    [PhoenixPrivilegeLevel]$RequiredPrivilege
    [PhoenixPrivilegeLevel]$CurrentPrivilege
    [bool]$RequiresElevation
    [bool]$CanElevate
    [string]$Code
    [string]$Reason
    [string[]]$Warnings
    [datetime]$EvaluatedAtUtc

    PhoenixDeploymentDecision() {

        $this.Name = ''
        $this.Operation =
            [PhoenixDeploymentOperation]::Unknown
        $this.Target = ''
        $this.Supported = $false
        $this.Available = $false
        $this.Eligible = $false
        $this.Safe = $false
        $this.Protected = $false
        $this.RequiresApproval = $false
        $this.ApprovalGranted = $false
        $this.RequiresTargetIdentity = $false
        $this.TargetIdentityConfirmed = $false
        $this.RequiredPrivilege =
            [PhoenixPrivilegeLevel]::User
        $this.CurrentPrivilege =
            [PhoenixPrivilegeLevel]::User
        $this.RequiresElevation = $false
        $this.CanElevate = $false
        $this.Code = 'PHX_DEPLOYMENT_NOT_EVALUATED'
        $this.Reason =
            'Deployment safety has not been evaluated.'
        $this.Warnings = @()
        $this.EvaluatedAtUtc = [datetime]::UtcNow
    }

    [bool] IsAllowed() {

        if (-not $this.Supported) {
            return $false
        }

        if (-not $this.Available) {
            return $false
        }

        if (-not $this.Eligible) {
            return $false
        }

        if (-not $this.Safe) {
            return $false
        }

        if (
            $this.Protected -and
            (
                -not $this.RequiresApproval -or
                -not $this.ApprovalGranted
            )
        ) {
            return $false
        }

        if (
            $this.RequiresApproval -and
            -not $this.ApprovalGranted
        ) {
            return $false
        }

        if (
            $this.RequiresTargetIdentity -and
            -not $this.TargetIdentityConfirmed
        ) {
            return $false
        }

        if (
            $this.RequiresElevation -and
            -not $this.CanElevate
        ) {
            return $false
        }

        return $true
    }
}
