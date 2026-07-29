# -----------------------------------------------------------------
# AUTO-GENERATED FILE
# DO NOT EDIT
# -----------------------------------------------------------------

#region 00-Base\Result.ps1
class Result {

    [bool]$Success
    [string]$Message
    [string]$Code
    [object]$Data
    [datetime]$Timestamp

    Result() {
        $this.Timestamp = Get-Date
    }

    static [Result] Success([string]$Message) {
        $r = [Result]::new()
        $r.Success = $true
        $r.Message = $Message
        return $r
    }

    static [Result] Failure([string]$Message) {
        $r = [Result]::new()
        $r.Success = $false
        $r.Message = $Message
        return $r
    }
}
#endregion

#region 00-Base\Package.ps1
class Package {

    [string]$Name
    [string]$Id
    [string]$Version
    [string]$Provider
    [string]$InstallerType
    [string]$Source
    [string]$Architecture
    [bool]$Installed

    Package() { }

}
#endregion

#region 00-Base\Driver.ps1
class Driver {

    [string]$Name
    [string]$Manufacturer
    [string]$Version
    [string]$Class
    [string]$Provider
    [string]$InfName
    [bool]$Present

    Driver() { }

}
#endregion

#region 10-Core\PhoenixLogger.ps1
class PhoenixLogger {

    [string]$LogDirectory
    [string]$LogFile

    PhoenixLogger([string]$ProjectRoot) {

        $this.LogDirectory = Join-Path $ProjectRoot 'Logs'

        if (-not (Test-Path $this.LogDirectory)) {
            New-Item -ItemType Directory `
                -Path $this.LogDirectory `
                -Force | Out-Null
        }

        $this.LogFile = Join-Path $this.LogDirectory (
            "Phoenix-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss')
        )
    }

    [void] Write(
        [string]$Level,
        [string]$Message
    ) {

        $Line = "[{0}] [{1}] {2}" -f `
            (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),
            $Level.ToUpper(),
            $Message

        Add-Content -Path $this.LogFile -Value $Line
    }
}
#endregion

#region 10-Core\PhoenixConfiguration.ps1
class PhoenixConfiguration {

    [string]$ConfigDirectory
    [string]$ConfigFile
    [hashtable]$Settings

    PhoenixConfiguration([string]$ProjectRoot) {

        $this.ConfigDirectory = Join-Path $ProjectRoot 'Config'
        $this.ConfigFile      = Join-Path $this.ConfigDirectory 'Phoenix.json'
        $this.Settings        = @{}

    }

    [void] Load() {

        # Load Phoenix.json

    }

    [void] Save() {

        # Save Phoenix.json

    }

    [object] Get([string]$Name) {

    return $this.Settings[$Name]

}


    [void] Set(
        [string]$Name,
        [object]$Value
    ) {

        # Update a setting

    }

}
#endregion

#region 10-Core\PhoenixBuild.ps1
class PhoenixBuild {

    [datetime]$StartTime
    [datetime]$EndTime

    [string]$Version
    [string]$Status

    PhoenixBuild() {

        $this.StartTime = Get-Date
        $this.Version = '0.1.0-alpha'
        $this.Status = 'Running'

    }

    [void] Finish() {

        $this.EndTime = Get-Date
        $this.Status = 'Completed'

    }

}
#endregion

#region 20-Providers\PhoenixProvider.ps1
class PhoenixProvider {

    [string]$Name
    [string]$Version
    [string]$Type

    [int]$Priority

    [bool]$Available
    [bool]$SupportsInstall
    [bool]$SupportsUpdate
    [bool]$SupportsRemove
    [bool]$SupportsExport
    [bool]$SupportsOfflineCache
    [bool]$SupportsDependencies

    PhoenixProvider() {

        $this.Priority = 0
        $this.Available = $false

        $this.SupportsInstall = $true
        $this.SupportsUpdate = $true
        $this.SupportsRemove = $true
        $this.SupportsExport = $false
        $this.SupportsOfflineCache = $false
        $this.SupportsDependencies = $false

    }

}
#endregion

#region 20-Providers\ChocolateyProvider.ps1
class ChocolateyProvider : PhoenixProvider {

    ChocolateyProvider() {

        $this.Name = "Chocolatey"
        $this.Priority = 90
        $this.Available = $this.TestAvailable()

    }

    [bool] TestAvailable() {

        return $null -ne (Get-Command choco -ErrorAction SilentlyContinue)

    }

}
#endregion

#region 20-Providers\DriverProvider.ps1
#endregion

#region 20-Providers\EXEProvider.ps1
#endregion

#region 20-Providers\MSIProvider.ps1
class MSIProvider : PhoenixProvider {

    MSIProvider() {

        $this.Name = "MSI"
        $this.Priority = 50
        $this.Available = $true

    }

    [bool] TestAvailable() {
        return $true
    }

    [object] SearchPackage([string]$Name) {
        return $null
    }

    [void] InstallPackage([Package]$Package) {
        throw "MSI installation not implemented."
    }

    [void] UpdatePackage([Package]$Package) {
        throw "MSI update not implemented."
    }

    [void] RemovePackage([Package]$Package) {
        throw "MSI removal not implemented."
    }

}
#endregion

#region 20-Providers\ScoopProvider.ps1
#endregion

#region 20-Providers\WinGetProvider.ps1
class WinGetProvider : PhoenixProvider {

    WinGetProvider() {

        $this.Name = "WinGet"
        $this.Priority = 100
        $this.Available = $this.TestAvailable()

    }

    [bool] TestAvailable() {

        return $null -ne (Get-Command winget -ErrorAction SilentlyContinue)

    }

    [Package[]] GetInstalledPackages() {

        $packages = @()

        return $packages

    }

    [Package[]] SearchPackage([string]$Name) {

        $packages = @()

        return $packages

    }

    [Result] InstallPackage([Package]$Package) {

        winget install `
            --id $Package.Id `
            --accept-package-agreements `
            --accept-source-agreements

        return [Result]::Success()

    }

    [Result] UpdatePackage([Package]$Package) {

        winget upgrade --id $Package.Id

        return [Result]::Success()

    }

    [Result] RemovePackage([Package]$Package) {

        winget uninstall --id $Package.Id

        return [Result]::Success()

    }

}
#endregion

#region 30-Models\PhoenixApplication.ps1
class PhoenixApplication {

    [string]$Name
    [string]$Version
    [string]$Build
    [datetime]$StartTime

    PhoenixApplication() {

        $this.Name = "Phoenix Deploy"

        $this.Version = "0.1.0-alpha"

        $this.Build = "0001"

        $this.StartTime = Get-Date

    }

}
#endregion

#region 30-Models\PhoenixInventory.ps1
class PhoenixInventory {

    [datetime]$Timestamp

    [string]$ComputerName

    [string]$UserName

    [hashtable]$Hardware

    [hashtable]$Software

    [hashtable]$Drivers

    [hashtable]$Packages

    [hashtable]$Providers

    PhoenixInventory() {

        $this.Timestamp    = Get-Date
        $this.ComputerName = $env:COMPUTERNAME
        $this.UserName     = $env:USERNAME

        $this.Hardware = @{}
        $this.Software = @{}
        $this.Drivers  = @{}
        $this.Packages = @{}
        $this.Providers = @{}

    }

}
#endregion

#region 30-Models\PackageCandidate.ps1
class PackageCandidate {

    [Package]$Package

    [PhoenixProvider]$Provider

    [double]$Score

    [string]$Reason

}
#endregion

#region 30-Models\PhoenixManifest.ps1
#endregion

#region 10-Core\PhoenixContext.ps1
class PhoenixContext {

    [string]$Version
    [string]$SessionID
    [datetime]$StartTime

    [string]$ProjectRoot
    [string]$ComputerName
    [string]$UserName

    [bool]$IsAdministrator

    [PhoenixConfiguration]$Configuration
    [PhoenixLogger]$Logger
    [PhoenixBuild]$Build
    [PhoenixInventory]$Inventory

    [System.Collections.Generic.List[PhoenixProvider]]$Providers

    PhoenixContext([string]$ProjectRoot) {

        $this.Version       = "0.1.0"
        $this.SessionID     = [guid]::NewGuid().ToString()
        $this.StartTime     = Get-Date

        $this.ProjectRoot   = $ProjectRoot
        $this.ComputerName  = $env:COMPUTERNAME
        $this.UserName      = $env:USERNAME

        $Principal = [Security.Principal.WindowsPrincipal]::new(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)

$this.IsAdministrator = $Principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

        $this.Configuration = [PhoenixConfiguration]::new($ProjectRoot)
        $this.Logger        = [PhoenixLogger]::new($ProjectRoot)
        $this.Build         = [PhoenixBuild]::new()
        $this.Inventory     = [PhoenixInventory]::new()

        $this.Providers = [System.Collections.Generic.List[PhoenixProvider]]::new()
    }

}
#endregion

