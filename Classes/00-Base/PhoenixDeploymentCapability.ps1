class PhoenixDeploymentCapability {

    [string]$Name
    [PhoenixDeploymentOperation]$Operation
    [bool]$Supported
    [bool]$Available
    [PhoenixPrivilegeLevel]$RequiredPrivilege
    [bool]$IsMutating
    [bool]$IsDestructive
    [bool]$SupportsShouldProcess
    [bool]$RequiresTargetIdentity
    [bool]$RequiresExclusiveAccess
    [string]$ConcurrencyKey
    [string]$Message
    [datetime]$CheckedAtUtc

    PhoenixDeploymentCapability() {

        $this.Name = ''
        $this.Operation =
            [PhoenixDeploymentOperation]::Unknown
        $this.Supported = $false
        $this.Available = $false
        $this.RequiredPrivilege =
            [PhoenixPrivilegeLevel]::User
        $this.IsMutating = $false
        $this.IsDestructive = $false
        $this.SupportsShouldProcess = $false
        $this.RequiresTargetIdentity = $false
        $this.RequiresExclusiveAccess = $false
        $this.ConcurrencyKey = ''
        $this.Message =
            'Deployment capability has not been evaluated.'
        $this.CheckedAtUtc = [datetime]::UtcNow
    }

    [bool] IsReady() {

        return (
            $this.Supported -and
            $this.Available
        )
    }
}
