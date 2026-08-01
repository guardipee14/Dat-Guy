class EXEPackageDefinition : Package {
    [string]$InstallCommand
    [string]$UninstallCommand
    [string]$QuietUninstallCommand
    [string]$RepairCommand
    [int[]]$SuccessExitCodes
    [int[]]$RebootExitCodes

    EXEPackageDefinition() {
        $this.InstallerType = 'EXE'
        $this.SuccessExitCodes = @(0)
        $this.RebootExitCodes = @(1641, 3010)
    }
}
