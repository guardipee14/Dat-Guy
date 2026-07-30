using module '.\Classes\Phoenix.Classes.psm1'

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Folders = @(
    'Private\Config'
    'Private\Core'
    'Private\Logging'
    'Private\ControlCenter'
    'Private\Providers'
    'Private\Drivers'
    'Private\Inventory'
    'Private\Packages'
    'Public'
)

foreach ($Folder in $Folders) {

    $Path = Join-Path $PSScriptRoot $Folder

    if (-not (Test-Path $Path)) {
        continue
    }

  Get-ChildItem $Path -Filter *.ps1 -File |
    Sort-Object Name |
    ForEach-Object {

        Write-Host "Loading $($_.Name)"

        . $_.FullName
    }

}


Export-ModuleMember -Function @(
    'Backup-Phoenix'
    'Get-PhoenixContext'
    'Get-PhoenixPackages'
    'Get-PhoenixProviders'
    'Install-PhoenixPackage'
    'Repair-PhoenixPackage'
    'Restore-Phoenix'
    'Start-Phoenix'
    'Update-Phoenix'
    'Remove-PhoenixPackage'
    'Update-PhoenixPackage'
    'Open-Phoenix'
    'Get-PhoenixTheme'
    'Install-PhoenixTheme'
    'Export-PhoenixTheme'
)
