function Get-HardwareInventory {

    [CmdletBinding()]
    param()

    [ordered]@{
        Processor    = Get-CimInstance Win32_Processor
        Motherboard  = Get-CimInstance Win32_BaseBoard
        BIOS         = Get-CimInstance Win32_BIOS
        Computer     = Get-CimInstance Win32_ComputerSystem
        Memory       = Get-CimInstance Win32_PhysicalMemory
        DiskDrives   = Get-CimInstance Win32_DiskDrive
        Video        = Get-CimInstance Win32_VideoController
        Monitors     = Get-CimInstance Win32_DesktopMonitor
        Batteries    = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
    }

}