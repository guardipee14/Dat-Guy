class PhoenixWinPEWorkspace {

    [string]$Schema
    [string]$SchemaVersion
    [string]$WorkspaceId
    [string]$RootPath
    [string]$Architecture
    [string]$SourceWimPath
    [string]$SourceWimSha256
    [string]$MediaSourcePath
    [string]$MediaPath
    [string]$MountPath
    [string]$State
    [datetime]$CreatedAtUtc
    [datetime]$UpdatedAtUtc

    PhoenixWinPEWorkspace() {
        $this.Schema = 'PhoenixWinPEWorkspace'
        $this.SchemaVersion = '1.0'
        $this.WorkspaceId = [guid]::NewGuid().ToString()
        $this.RootPath = ''
        $this.Architecture = 'x64'
        $this.SourceWimPath = ''
        $this.SourceWimSha256 = ''
        $this.MediaSourcePath = ''
        $this.MediaPath = ''
        $this.MountPath = ''
        $this.State = 'Planning'
        $this.CreatedAtUtc = [datetime]::UtcNow
        $this.UpdatedAtUtc = $this.CreatedAtUtc
    }

    [void] SetState([string]$State) {
        if ($State -notin @('Planning', 'Staging', 'Ready', 'Mounted', 'Failed')) {
            throw "Unsupported WinPE workspace state '$State'."
        }

        $this.State = $State
        $this.UpdatedAtUtc = [datetime]::UtcNow
    }

    [bool] IsValid() {
        [guid]$workspaceGuid = [guid]::Empty

        return (
            $this.Schema -ceq 'PhoenixWinPEWorkspace' -and
            $this.SchemaVersion -ceq '1.0' -and
            [guid]::TryParse($this.WorkspaceId, [ref]$workspaceGuid) -and
            $workspaceGuid -ne [guid]::Empty -and
            -not [string]::IsNullOrWhiteSpace($this.RootPath) -and
            $this.Architecture -ceq 'x64' -and
            $this.SourceWimSha256 -cmatch '^[0-9a-f]{64}$' -and
            -not [string]::IsNullOrWhiteSpace($this.MediaPath) -and
            -not [string]::IsNullOrWhiteSpace($this.MountPath) -and
            $this.State -in @('Staging', 'Ready', 'Mounted', 'Failed') -and
            $this.UpdatedAtUtc -ge $this.CreatedAtUtc
        )
    }
}
