[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$ProjectRoot = (
        Resolve-Path (
            Join-Path $PSScriptRoot '..'
        )
    ).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$providersRoot = Join-Path `
    $ProjectRoot `
    'Classes\20-Providers'

$files = @(

    ##########################################################
    ## PhoenixProvider
    ##########################################################

    'PhoenixProvider\PhoenixProvider.Header.ps1'

    'PhoenixProvider\Methods\10-ProviderManagement\TestAvailable.ps1'
    'PhoenixProvider\Methods\10-ProviderManagement\InstallProvider.ps1'
    'PhoenixProvider\Methods\10-ProviderManagement\UpdateProvider.ps1'

    'PhoenixProvider\Methods\20-Discovery\GetInstalledPackages.ps1'
    'PhoenixProvider\Methods\20-Discovery\SearchPackage.ps1'

    'PhoenixProvider\Methods\30-Installation\NewFailure.ps1'
    'PhoenixProvider\Methods\30-Installation\CanInstallSilently.ps1'
    'PhoenixProvider\Methods\30-Installation\InstallPackage.ps1'
    'PhoenixProvider\Methods\30-Installation\InstallPackageWithMode.ps1'
    'PhoenixProvider\Methods\30-Installation\InstallPackageCore.ps1'
    'PhoenixProvider\Methods\30-Installation\InstallPackageSilent.ps1'
    'PhoenixProvider\Methods\30-Installation\InstallPackageInteractive.ps1'

    'PhoenixProvider\Methods\40-Cleanup\NewPackageWorkingDirectory.ps1'
    'PhoenixProvider\Methods\40-Cleanup\IsPhoenixManagedPath.ps1'
    'PhoenixProvider\Methods\40-Cleanup\CleanupPackage.ps1'

    'PhoenixProvider\Methods\50-Repair\CanRepairSilently.ps1'
    'PhoenixProvider\Methods\50-Repair\RepairPackage.ps1'
    'PhoenixProvider\Methods\50-Repair\RepairPackageWithMode.ps1'
    'PhoenixProvider\Methods\50-Repair\RepairPackageSilent.ps1'
    'PhoenixProvider\Methods\50-Repair\RepairPackageInteractive.ps1'

    'PhoenixProvider\Methods\60-PackageManagement\UpdatePackage.ps1'
    'PhoenixProvider\Methods\60-PackageManagement\RemovePackage.ps1'

    'PhoenixProvider\PhoenixProvider.Footer.ps1'

    ##########################################################
    ## WinGetProvider
    ##########################################################

    'WinGetProvider\WinGetProvider.Header.ps1'

    'WinGetProvider\Methods\TestAvailable.ps1'
    'WinGetProvider\Methods\InstallProvider.ps1'
    'WinGetProvider\Methods\UpdateProvider.ps1'

    'WinGetProvider\Methods\GetInstalledPackages.ps1'
    'WinGetProvider\Methods\SearchPackage.ps1'

    'WinGetProvider\Methods\InstallPackageSilent.ps1'
    'WinGetProvider\Methods\InstallPackageInteractive.ps1'

    'WinGetProvider\Methods\RepairPackageSilent.ps1'
    'WinGetProvider\Methods\RepairPackageInteractive.ps1'

    'WinGetProvider\Methods\UpdatePackage.ps1'
    'WinGetProvider\Methods\RemovePackage.ps1'

    'WinGetProvider\WinGetProvider.Footer.ps1'

    ##########################################################
    ## ChocolateyProvider
    ##########################################################

    'ChocolateyProvider\ChocolateyProvider.Header.ps1'

    'ChocolateyProvider\Methods\TestAvailable.ps1'
    'ChocolateyProvider\Methods\InstallProvider.ps1'
    'ChocolateyProvider\Methods\UpdateProvider.ps1'

    'ChocolateyProvider\Methods\GetInstalledPackages.ps1'
    'ChocolateyProvider\Methods\SearchPackage.ps1'

    'ChocolateyProvider\Methods\InstallPackageSilent.ps1'
    'ChocolateyProvider\Methods\InstallPackageInteractive.ps1'

    'ChocolateyProvider\Methods\RepairPackageSilent.ps1'
    'ChocolateyProvider\Methods\RepairPackageInteractive.ps1'

    'ChocolateyProvider\Methods\UpdatePackage.ps1'
    'ChocolateyProvider\Methods\RemovePackage.ps1'

    'ChocolateyProvider\ChocolateyProvider.Footer.ps1'
)

function New-PhoenixDirectory {

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (Test-Path -LiteralPath $Path) {
        return
    }

    if ($PSCmdlet.ShouldProcess($Path, 'Create directory')) {

        $null = New-Item `
            -ItemType Directory `
            -Path $Path `
            -Force

        Write-Host "Created directory: $Path" `
            -ForegroundColor DarkGray
    }
}

function New-PhoenixFragmentFile {

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    if (Test-Path -LiteralPath $Path) {

        Write-Host "Preserved existing file: $RelativePath" `
            -ForegroundColor DarkYellow

        return
    }

    $fileName = Split-Path $Path -Leaf

    $placeholder = @"
##########################################################
## Phoenix composite class fragment
## File: $RelativePath
##########################################################

# TODO:
# Move the corresponding code from the existing provider
# class into this file.
#
# Do not add a class declaration to method files.
# Do not add the final class-closing brace to method files.

"@

    if ($fileName -like '*.Header.ps1') {

        $placeholder = @"
##########################################################
## Phoenix composite class header
## File: $RelativePath
##########################################################

# TODO:
# Move the class declaration, properties, and constructor
# into this file.
#
# This header opens the class but does not close it.

"@
    }
    elseif ($fileName -like '*.Footer.ps1') {

        $placeholder = @"
##########################################################
## Phoenix composite class footer
## File: $RelativePath
##########################################################

# TODO:
# This file will contain the single brace that closes
# the composite provider class.

"@
    }

    if ($PSCmdlet.ShouldProcess($Path, 'Create fragment file')) {

        Set-Content `
            -LiteralPath $Path `
            -Value $placeholder `
            -Encoding utf8

        Write-Host "Created file: $RelativePath" `
            -ForegroundColor Green
    }
}

Write-Host ''
Write-Host 'Creating Phoenix provider structure...' `
    -ForegroundColor Cyan

Write-Host "Project root: $ProjectRoot"
Write-Host "Provider root: $providersRoot"
Write-Host ''

New-PhoenixDirectory -Path $providersRoot

foreach ($relativePath in $files) {

    $fullPath = Join-Path `
        $providersRoot `
        $relativePath

    $directoryPath = Split-Path `
        $fullPath `
        -Parent

    New-PhoenixDirectory `
        -Path $directoryPath

    New-PhoenixFragmentFile `
        -Path $fullPath `
        -RelativePath $relativePath
}

Write-Host ''
Write-Host 'Provider structure created successfully.' `
    -ForegroundColor Green

Write-Host "Files requested: $($files.Count)"
Write-Host ''
Write-Host (
    'The existing monolithic provider files and build script were not changed.'
) -ForegroundColor Yellow