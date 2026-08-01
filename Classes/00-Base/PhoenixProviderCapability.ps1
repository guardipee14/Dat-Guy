class PhoenixProviderCapability {

    [string]$ProviderName
    [string]$ProviderVersion
    [PhoenixProviderAvailability]$Availability
    [bool]$Available
    [PhoenixPrivilegeLevel]$RequiredPrivilege
    [bool]$SupportsSearch
    [bool]$SupportsInventory
    [bool]$SupportsInstall
    [bool]$SupportsUpdate
    [bool]$SupportsRepair
    [bool]$SupportsRemove
    [bool]$SupportsExport
    [bool]$SupportsRestore
    [string[]]$SupportedOperations
    [string]$HealthMessage
    [datetime]$CheckedAtUtc

    PhoenixProviderCapability() {

        $this.ProviderName = ''
        $this.ProviderVersion = ''
        $this.Availability =
            [PhoenixProviderAvailability]::Unknown
        $this.Available = $false
        $this.RequiredPrivilege =
            [PhoenixPrivilegeLevel]::User
        $this.SupportedOperations = @()
        $this.HealthMessage = 'Provider health has not been checked.'
        $this.CheckedAtUtc = [datetime]::UtcNow
    }

    [bool] Supports(
        [PhoenixProviderOperation]$Operation
    ) {

        if ($Operation -eq [PhoenixProviderOperation]::Search) {
            return $this.SupportsSearch
        }

        if ($Operation -eq [PhoenixProviderOperation]::Inventory) {
            return $this.SupportsInventory
        }

        if ($Operation -eq [PhoenixProviderOperation]::Install) {
            return $this.SupportsInstall
        }

        if ($Operation -eq [PhoenixProviderOperation]::Update) {
            return $this.SupportsUpdate
        }

        if ($Operation -eq [PhoenixProviderOperation]::Repair) {
            return $this.SupportsRepair
        }

        if ($Operation -eq [PhoenixProviderOperation]::Remove) {
            return $this.SupportsRemove
        }

        if ($Operation -eq [PhoenixProviderOperation]::Export) {
            return $this.SupportsExport
        }

        if ($Operation -eq [PhoenixProviderOperation]::Restore) {
            return $this.SupportsRestore
        }

        return $false
    }
}
