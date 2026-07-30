function Get-PhoenixInventory {

    [CmdletBinding()]
    param()

    $context =
        Resolve-PhoenixContext

    Write-PhoenixLog -Level Info -Message "Collecting inventory."

    $inventory = [PhoenixInventory]::new()

    #
    # Hardware
    #

    $inventory.Hardware["CPU"] =
        Get-CimInstance Win32_Processor

    $inventory.Hardware["Motherboard"] =
        Get-CimInstance Win32_BaseBoard

    $inventory.Hardware["BIOS"] =
        Get-CimInstance Win32_BIOS

    $inventory.Hardware["Memory"] =
        Get-CimInstance Win32_PhysicalMemory

    $inventory.Hardware["Disk"] =
        Get-CimInstance Win32_DiskDrive

    #
    # Software
    #

    $inventory.Software["OperatingSystem"] =
        Get-CimInstance Win32_OperatingSystem

    $inventory.Software["PowerShell"] =
        $PSVersionTable

    #
    # Providers
    #

    $inventory.Providers = $context.Providers

    #
    # Drivers
    #

    $inventory.Drivers["Installed"] =
        Get-PhoenixDriver

    #
    # Packages
    #

    $inventory.Packages["Installed"] =
        Get-PhoenixPackage

    return $inventory

}
