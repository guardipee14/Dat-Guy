function Get-NetworkInventory {

    [CmdletBinding()]
    param()

    [ordered]@{
        Adapters  = Get-NetAdapter -ErrorAction SilentlyContinue
        IPConfig  = Get-NetIPConfiguration -ErrorAction SilentlyContinue
        Routes    = Get-NetRoute -ErrorAction SilentlyContinue
        Firewall  = Get-NetFirewallProfile -ErrorAction SilentlyContinue
    }

}