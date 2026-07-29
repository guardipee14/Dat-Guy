class Package {

    [string]$Name
    [string]$Id
    [string]$Version
    [string]$Provider
    [string]$InstallerType
    [string]$Source
    [string]$Architecture

    [bool]$Installed
    [bool]$RequiresElevation

    # Mainly used by EXE and GitHub-downloaded installers.
    [string[]]$SilentArguments
    [string[]]$InteractiveArguments
    [string]$WorkingDirectory
    [string]$DownloadedFile
    [string[]]$CleanupPaths

    [bool]$PreserveDownloads

    Package() {

        $this.Installed = $false
        $this.RequiresElevation = $false

        $this.SilentArguments = @()
        $this.InteractiveArguments = @()
        $this.WorkingDirectory = ''
        $this.DownloadedFile = ''
        $this.CleanupPaths = @()

        $this.PreserveDownloads = $false
    }
}