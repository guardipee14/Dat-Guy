function Get-WindowsInventory {

    [CmdletBinding()]
    param()

    [ordered]@{
        Windows      = Get-ComputerInfo
        Features     = Get-WindowsOptionalFeature -Online -ErrorAction SilentlyContinue
        Capabilities = Get-WindowsCapability -Online -ErrorAction SilentlyContinue
        Services     = Get-Service
    }

}