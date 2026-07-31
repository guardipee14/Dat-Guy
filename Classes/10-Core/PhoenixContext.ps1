class PhoenixContext {

    [string]$Version
    [string]$SessionID
    [datetime]$StartTime
    [datetime]$InitializedAtUtc

    [string]$LifecycleState
    [string]$InitializationError
    [bool]$IsInitialized
    [bool]$IsResumed
    [int]$Generation

    [string]$ProjectRoot
    [string]$CacheRoot
    [string]$WorkingRoot
    [string]$CheckpointRoot
    [string]$ThemeRoot
    [string]$InstalledThemeRoot
    [string]$RecoveryRoot
    [string]$ComputerName
    [string]$UserName

    [bool]$IsAdministrator
    [PhoenixPrivilegeLevel]$PrivilegeLevel

    [PhoenixConfiguration]$Configuration
    [PhoenixLogger]$Logger
    [PhoenixBuild]$Build
    [PhoenixInventory]$Inventory
    [object]$Scheduler
    [object]$RuntimeRecovery

    [System.Collections.Generic.List[PhoenixProvider]]$Providers
    [System.Collections.Generic.List[string]]$InitializationWarnings

    PhoenixContext([string]$ProjectRoot) {

        $this.Version = '0.1.5'
        $this.SessionID = [guid]::NewGuid().ToString()
        $this.StartTime = Get-Date
        $this.InitializedAtUtc = [datetime]::MinValue
        $this.LifecycleState = 'Created'
        $this.InitializationError = ''
        $this.IsInitialized = $false
        $this.IsResumed = $false
        $this.Generation = 0

        $this.ProjectRoot = [IO.Path]::GetFullPath(
            $ProjectRoot
        )

        $this.CacheRoot = Join-Path `
            $this.ProjectRoot `
            'Cache'

        $this.WorkingRoot = Join-Path `
            $this.CacheRoot `
            'Working'

        $this.CheckpointRoot = Join-Path `
            $this.ProjectRoot `
            'Checkpoints'

        $this.ThemeRoot = Join-Path `
            $this.ProjectRoot `
            'Themes'

        $this.InstalledThemeRoot = Join-Path `
            $this.ThemeRoot `
            'Installed'

        $this.RecoveryRoot = Join-Path `
            $this.CacheRoot `
            'Recovery'

        if (-not (Test-Path -LiteralPath $this.WorkingRoot)) {

            New-Item `
                -ItemType Directory `
                -Path $this.WorkingRoot `
                -Force |
                Out-Null
        }

        $this.ComputerName = $env:COMPUTERNAME
        $this.UserName = $env:USERNAME

        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()

        $principal = [Security.Principal.WindowsPrincipal]::new(
            $identity
        )

        $this.IsAdministrator = $principal.IsInRole(
            [Security.Principal.WindowsBuiltInRole]::Administrator
        )

        if ($this.IsAdministrator) {
            $this.PrivilegeLevel = [PhoenixPrivilegeLevel]::Administrator
        }
        else {
            $this.PrivilegeLevel = [PhoenixPrivilegeLevel]::User
        }

        $this.Configuration = [PhoenixConfiguration]::new($ProjectRoot)
        $this.Logger = [PhoenixLogger]::new($ProjectRoot)
        $this.Build = [PhoenixBuild]::new()
        $this.Inventory = [PhoenixInventory]::new()
        $this.Scheduler = $null
        $this.RuntimeRecovery = $null

        $this.Providers =
            [System.Collections.Generic.List[PhoenixProvider]]::new()

        $this.InitializationWarnings =
            [System.Collections.Generic.List[string]]::new()
    }
}
