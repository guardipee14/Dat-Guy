##########################################################
## ChocolateyProvider composite class header
## Generated from the validated legacy provider
##########################################################

class ChocolateyProvider : PhoenixProvider {

    ##########################################################
    ## Constructor
    ##########################################################

ChocolateyProvider() {

        $this.Name     = "Chocolatey"
        $this.Version  = ""
        $this.Type     = "Package Manager"

        $this.Priority = 90

        $this.SupportsDependencies = $true

        $this.Available = $this.TestAvailable()

        $this.RequiredPrivilege = [PhoenixPrivilegeLevel]::Administrator
        $this.SupportsSilentInstall = $true
        $this.SupportsInteractiveInstall = $true
        $this.SupportsRepair = $true
        $this.SupportsSilentRepair = $true
        $this.SupportsInteractiveRepair = $true

    }

