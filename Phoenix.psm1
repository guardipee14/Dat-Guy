using module '.\Classes\Phoenix.Classes.psm1'

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:PhoenixContext = $null
$script:PhoenixContextGeneration = 0
$script:PhoenixLastInitializationError = ''

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
    'Get-PhoenixRestoreCheckpoint'
    'Get-PhoenixPackages'
    'Get-PhoenixProviders'
    'Install-PhoenixPackage'
    'Import-PhoenixRestorePlan'
    'Invoke-PhoenixRestorePlan'
    'New-PhoenixRestorePlan'
    'New-PhoenixRestoreCheckpoint'
    'Repair-PhoenixPackage'
    'Receive-PhoenixJob'
    'Restore-Phoenix'
    'Resume-PhoenixRestore'
    'Save-PhoenixRestorePlan'
    'Save-PhoenixRestoreCheckpoint'
    'Start-Phoenix'
    'Start-PhoenixRestoreJob'
    'Stop-PhoenixJob'
    'Test-PhoenixRestoreVerification'
    'Update-Phoenix'
    'Remove-PhoenixPackage'
    'Update-PhoenixPackage'
    'Open-Phoenix'
    'Get-PhoenixTheme'
    'Install-PhoenixTheme'
    'Export-PhoenixTheme'
)
