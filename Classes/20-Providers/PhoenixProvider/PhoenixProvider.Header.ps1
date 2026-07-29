##########################################################
## PhoenixProvider composite class header
## Generated from the validated legacy provider
##########################################################

class PhoenixProvider {

    ##########################################################
    ## Properties
    ##########################################################

[string]$Name
[string]$Version
[string]$Type
[int]$Priority
[bool]$Available
[PhoenixPrivilegeLevel]$RequiredPrivilege
[bool]$SupportsInstall
[bool]$SupportsUpdate
[bool]$SupportsRemove
[bool]$SupportsExport
[bool]$SupportsOfflineCache
[bool]$SupportsDependencies
[bool]$SupportsSilentInstall
[bool]$SupportsInteractiveInstall
[bool]$SupportsRepair
[bool]$SupportsSilentRepair
[bool]$SupportsInteractiveRepair
[bool]$SupportsCleanup
[bool]$CleanupAfterInstall
[bool]$CleanupOnFailure

    ##########################################################
    ## Constructor
    ##########################################################

PhoenixProvider() {

        $this.Name      = ""
        $this.Version   = ""
        $this.Type      = ""

        $this.Priority  = 0
        $this.Available = $false

        $this.SupportsInstall      = $true
        $this.SupportsUpdate       = $true
        $this.SupportsRemove       = $true
        $this.SupportsExport       = $false
        $this.SupportsOfflineCache = $false
        $this.SupportsDependencies = $false
        $this.SupportsSilentInstall      = $false
        $this.SupportsInteractiveInstall = $false
        $this.RequiredPrivilege = [PhoenixPrivilegeLevel]::User
        $this.SupportsRepair = $false
        $this.SupportsSilentRepair = $false
        $this.SupportsInteractiveRepair = $false

        $this.SupportsCleanup = $true
        $this.CleanupAfterInstall = $true
        $this.CleanupOnFailure = $false

    }

