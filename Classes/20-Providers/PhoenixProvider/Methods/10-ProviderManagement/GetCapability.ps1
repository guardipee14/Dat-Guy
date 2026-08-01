##########################################################
## Method: GetCapability
##########################################################

[PhoenixProviderCapability] GetCapability() {

    $capability = [PhoenixProviderCapability]::new()
    $capability.ProviderName = $this.Name
    $capability.ProviderVersion = $this.Version
    $capability.Available = $this.Available
    $capability.RequiredPrivilege = $this.RequiredPrivilege
    $capability.SupportsSearch = $this.SupportsSearch
    $capability.SupportsInventory = $this.SupportsInventory
    $capability.SupportsInstall = $this.SupportsInstall
    $capability.SupportsUpdate = $this.SupportsUpdate
    $capability.SupportsRepair = $this.SupportsRepair
    $capability.SupportsRemove = $this.SupportsRemove
    $capability.SupportsExport = $this.SupportsExport
    $capability.SupportsRestore = $this.SupportsRestore
    $capability.CheckedAtUtc = [datetime]::UtcNow

    if ($this.Available) {
        $capability.Availability =
            [PhoenixProviderAvailability]::Available
        $capability.HealthMessage = 'Ready'
    }
    else {
        $capability.Availability =
            [PhoenixProviderAvailability]::Unavailable
        $capability.HealthMessage =
            'Executable or service was not detected.'
    }

    $operationNames =
        [System.Collections.Generic.List[string]]::new()

    foreach (
        $operation in @(
            [PhoenixProviderOperation]::Search
            [PhoenixProviderOperation]::Inventory
            [PhoenixProviderOperation]::Install
            [PhoenixProviderOperation]::Update
            [PhoenixProviderOperation]::Repair
            [PhoenixProviderOperation]::Remove
            [PhoenixProviderOperation]::Export
            [PhoenixProviderOperation]::Restore
        )
    ) {
        if ($this.SupportsOperation($operation)) {
            $operationNames.Add($operation.ToString())
        }
    }

    $capability.SupportedOperations =
        $operationNames.ToArray()

    return $capability
}
