class PhoenixDeploymentToolStatus {

    [string]$Name
    [string]$Path
    [string]$Version
    [bool]$Required
    [bool]$Available
    [string]$Message

    PhoenixDeploymentToolStatus() {
        $this.Name = ''
        $this.Path = ''
        $this.Version = ''
        $this.Required = $true
        $this.Available = $false
        $this.Message = ''
    }

    [bool] IsValid() {
        return (
            -not [string]::IsNullOrWhiteSpace($this.Name) -and
            (
                -not $this.Available -or
                -not [string]::IsNullOrWhiteSpace($this.Path)
            )
        )
    }
}

class PhoenixDeploymentReadiness {

    [string]$Architecture
    [string]$HostArchitecture
    [bool]$HostSupported
    [string]$AdkRoot
    [string]$WinPERoot
    [PhoenixDeploymentToolStatus[]]$Tools
    [string[]]$MissingPrerequisites
    [string[]]$Warnings
    [bool]$Ready
    [datetime]$CheckedAtUtc

    PhoenixDeploymentReadiness() {
        $this.Architecture = 'x64'
        $this.HostArchitecture = ''
        $this.HostSupported = $false
        $this.AdkRoot = ''
        $this.WinPERoot = ''
        $this.Tools = @()
        $this.MissingPrerequisites = @()
        $this.Warnings = @()
        $this.Ready = $false
        $this.CheckedAtUtc = [datetime]::MinValue
    }

    [void] AddTool([PhoenixDeploymentToolStatus]$Tool) {
        if ($null -eq $Tool -or -not $Tool.IsValid()) {
            throw 'A valid deployment-tool status is required.'
        }

        $this.Tools = @($this.Tools + $Tool)
    }

    [void] Complete() {
        $missing = [Collections.Generic.List[string]]::new()

        if (-not $this.HostSupported) {
            $missing.Add("Supported x64 Windows host (detected '$($this.HostArchitecture)')")
        }

        foreach ($tool in $this.Tools) {
            if ($tool.Required -and -not $tool.Available) {
                $missing.Add($tool.Name)
            }
        }

        $this.MissingPrerequisites = @($missing)
        $this.Ready = $this.MissingPrerequisites.Count -eq 0
        $this.CheckedAtUtc = [datetime]::UtcNow
    }

    [bool] IsValid() {
        if (
            [string]::IsNullOrWhiteSpace($this.Architecture) -or
            [string]::IsNullOrWhiteSpace($this.HostArchitecture) -or
            $this.CheckedAtUtc -eq [datetime]::MinValue -or
            $null -eq $this.Tools -or
            $null -eq $this.MissingPrerequisites -or
            $null -eq $this.Warnings
        ) {
            return $false
        }

        foreach ($tool in $this.Tools) {
            if ($null -eq $tool -or -not $tool.IsValid()) {
                return $false
            }
        }

        return (
            -not $this.Ready -or
            (
                $this.HostSupported -and
                $this.MissingPrerequisites.Count -eq 0
            )
        )
    }
}
