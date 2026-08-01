class DISMPackageDefinition : Package {
    [string]$ServicingType
    [string]$State
    [string]$SourcePath

    DISMPackageDefinition() {
        $this.Provider = 'DISM'
        $this.Source = 'Online Windows Image'
        $this.RequiresElevation = $true
    }
}
