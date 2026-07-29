##########################################################
## WinGetProvider composite class header
## Generated from the validated legacy provider
##########################################################

class WinGetProvider : PhoenixProvider {

    ##########################################################
    ## Constructor
    ##########################################################

WinGetProvider() {

        $this.Name     = "WinGet"
        $this.Version  = ""
        $this.Type     = "Package Manager"

        $this.Priority = 95

        $this.SupportsDependencies = $true

        $this.Available = $this.TestAvailable()
        $this.SupportsSilentInstall = $true
        $this.SupportsInteractiveInstall = $true
        $this.SupportsRepair = $true
        $this.SupportsSilentRepair = $true
        $this.SupportsInteractiveRepair = $true

    }

