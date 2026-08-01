class NuGetPackageDefinition : Package {
    [string]$FeedUrl
    [string]$DownloadUri
    [string]$InstalledVersion
    [string]$Description
    [string]$Authors

    NuGetPackageDefinition() {
        $this.Provider = 'NuGet'
        $this.InstallerType = 'NuGet'
        $this.RequiresElevation = $false
    }
}
