class PhoenixContext {

    [string]$Version
    [string]$SessionID
    [datetime]$StartTime

    [string]$ProjectRoot
    [string]$CacheRoot
    [string]$WorkingRoot
    [string]$ComputerName
    [string]$UserName

    [bool]$IsAdministrator
    [PhoenixPrivilegeLevel]$PrivilegeLevel

    [PhoenixConfiguration]$Configuration
    [PhoenixLogger]$Logger
    [PhoenixBuild]$Build
    [PhoenixInventory]$Inventory

    [System.Collections.Generic.List[PhoenixProvider]]$Providers

    PhoenixContext([string]$ProjectRoot) {

        $this.Version      = '0.1.0'
        $this.SessionID    = [guid]::NewGuid().ToString()
        $this.StartTime    = Get-Date
        $this.ProjectRoot  = $ProjectRoot
        $this.CacheRoot = Join-Path `
        $this.ProjectRoot `
            'Cache'

        $this.WorkingRoot = Join-Path `
            $this.CacheRoot `
            'Working'

        if (-not (Test-Path -LiteralPath $this.WorkingRoot)) {

            New-Item `
            -ItemType Directory `
            -Path $this.WorkingRoot `
            -Force |
            Out-Null
}
        $this.ComputerName = $env:COMPUTERNAME
        $this.UserName     = $env:USERNAME

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
        $this.Logger        = [PhoenixLogger]::new($ProjectRoot)
        $this.Build         = [PhoenixBuild]::new()
        $this.Inventory     = [PhoenixInventory]::new()

        $this.Providers =
            [System.Collections.Generic.List[PhoenixProvider]]::new()
    }
}