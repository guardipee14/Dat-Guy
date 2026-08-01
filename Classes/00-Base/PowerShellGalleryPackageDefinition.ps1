class PowerShellGalleryPackageDefinition : Package {
    [string]$ResourceType
    [string]$Repository
    [string]$InstalledVersion
    [string]$Description

    PowerShellGalleryPackageDefinition() {
        $this.Provider = 'PowerShell Gallery'
        $this.Source = 'PSGallery'
        $this.Repository = 'PSGallery'
        $this.RequiresElevation = $false
    }
}
