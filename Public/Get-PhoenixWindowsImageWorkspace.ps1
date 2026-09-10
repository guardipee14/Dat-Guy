using module '..\Classes\Phoenix.Classes.psm1'

function Get-PhoenixWindowsImageWorkspace {
    [CmdletBinding()]
    [OutputType([PhoenixWindowsImageWorkspace])]
    param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path)
    return (Get-PhoenixWindowsImageWorkspaceOwnedInfo -Path $Path).Workspace
}
