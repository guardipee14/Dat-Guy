function Backup-Phoenix {

    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    if (-not $PSCmdlet.ShouldProcess($OutputPath, "Create Phoenix backup")) {
        return
    }

    Write-PhoenixLog -Level Info -Message "Creating Phoenix manifest..."

    $manifest = [ordered]@{
        Metadata = @{
            Version        = "1.0"
            Timestamp      = Get-Date
            ComputerName   = $env:COMPUTERNAME
            PhoenixVersion = "0.1.0-alpha"
        }

        Inventory = Get-PhoenixInventory
        Drivers   = Get-PhoenixDriver
        Packages  = Get-PhoenixPackage
        Providers = $script:PhoenixContext.Providers
    }

    $manifest |
        ConvertTo-Json -Depth 25 |
        Set-Content $OutputPath

    Write-PhoenixLog -Level Success -Message "Manifest saved to '$OutputPath'."
}