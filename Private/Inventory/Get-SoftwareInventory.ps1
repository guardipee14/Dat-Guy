function Get-SoftwareInventory {

    [CmdletBinding()]
    param()

    [ordered]@{
        OperatingSystem = Get-CimInstance Win32_OperatingSystem
        PowerShell      = $PSVersionTable
        DotNet          = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse -ErrorAction SilentlyContinue
        InstalledApps   = Get-PhoenixPackage
    }

}