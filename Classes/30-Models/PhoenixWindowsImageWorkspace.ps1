class PhoenixWindowsImageWorkspace {

    [string]$Schema
    [string]$SchemaVersion
    [string]$WorkspaceId
    [string]$RootPath
    [string]$SourceImagePath
    [string]$SourceImageSha256
    [string]$WorkingImagePath
    [string]$WorkingImageSha256
    [int]$SourceImageIndex
    [string]$MountPath
    [int]$ImageIndex
    [string]$State
    [bool]$ReadOnly
    [string[]]$Operations
    [datetime]$CreatedAtUtc
    [datetime]$UpdatedAtUtc

    PhoenixWindowsImageWorkspace() {
        $this.Schema = 'PhoenixWindowsImageWorkspace'
        $this.SchemaVersion = '1.0'
        $this.WorkspaceId = [guid]::NewGuid().ToString()
        $this.RootPath = ''
        $this.SourceImagePath = ''
        $this.SourceImageSha256 = ''
        $this.WorkingImagePath = ''
        $this.WorkingImageSha256 = ''
        $this.SourceImageIndex = 1
        $this.MountPath = ''
        $this.ImageIndex = 1
        $this.State = 'Planning'
        $this.ReadOnly = $false
        $this.Operations = @()
        $this.CreatedAtUtc = [datetime]::UtcNow
        $this.UpdatedAtUtc = $this.CreatedAtUtc
    }

    [void] SetState([string]$State) {
        if ($State -notin @('Planning', 'Staging', 'Ready', 'Mounted', 'Servicing', 'Failed')) {
            throw "Unsupported Windows-image workspace state '$State'."
        }

        $this.State = $State
        $this.UpdatedAtUtc = [datetime]::UtcNow
    }

    [void] AddOperation([string]$Operation) {
        if ([string]::IsNullOrWhiteSpace($Operation)) {
            return
        }

        $this.Operations = @($this.Operations + $Operation.Trim())
        $this.UpdatedAtUtc = [datetime]::UtcNow
    }

    [bool] IsValid() {
        [guid]$workspaceGuid = [guid]::Empty

        return (
            $this.Schema -ceq 'PhoenixWindowsImageWorkspace' -and
            $this.SchemaVersion -ceq '1.0' -and
            [guid]::TryParse($this.WorkspaceId, [ref]$workspaceGuid) -and
            $workspaceGuid -ne [guid]::Empty -and
            -not [string]::IsNullOrWhiteSpace($this.RootPath) -and
            -not [string]::IsNullOrWhiteSpace($this.SourceImagePath) -and
            $this.SourceImageSha256 -cmatch '^[0-9a-f]{64}$' -and
            -not [string]::IsNullOrWhiteSpace($this.WorkingImagePath) -and
            $this.WorkingImageSha256 -cmatch '^[0-9a-f]{64}$' -and
            $this.SourceImageIndex -gt 0 -and
            -not [string]::IsNullOrWhiteSpace($this.MountPath) -and
            $this.ImageIndex -gt 0 -and
            $this.State -in @('Staging', 'Ready', 'Mounted', 'Servicing', 'Failed') -and
            $null -ne $this.Operations -and
            $this.UpdatedAtUtc -ge $this.CreatedAtUtc
        )
    }
}
