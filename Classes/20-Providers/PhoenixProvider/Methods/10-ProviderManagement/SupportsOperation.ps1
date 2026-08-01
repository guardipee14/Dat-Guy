##########################################################
## Method: SupportsOperation
##########################################################

[bool] SupportsOperation(
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
