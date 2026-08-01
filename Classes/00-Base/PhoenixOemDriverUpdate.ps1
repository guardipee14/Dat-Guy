class PhoenixOemDriverUpdate : Driver {
    [string]$Id
    [string]$Adapter
    [string[]]$HardwareIds
    [string]$InstalledVersion
    [string]$AvailableVersion
    [string]$Source
    [datetime]$ReleaseDate
    [string]$ReleaseNotes
    [string]$SupportUrl
    [string]$DownloadUri
    [bool]$Applicable
    [bool]$RebootRequired

    PhoenixOemDriverUpdate() {
        $this.HardwareIds = @()
        $this.Applicable = $false
    }
}
