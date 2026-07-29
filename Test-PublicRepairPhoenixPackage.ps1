using module '.\Classes\Phoenix.Classes.psm1'

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module '.\Phoenix.psd1' -Force

Start-Phoenix

[string]$packageId = 'Microsoft.WingetCreate'

[PhoenixProvider]$provider = @(
    Get-PhoenixProviders |
        Where-Object {
            $_.Name -eq 'WinGet'
        }
) | Select-Object -First 1

if ($null -eq $provider) {
    throw 'WinGetProvider was not initialized.'
}

[Package]$package = [Package]::new()

$package.Id = $packageId
$package.Name = $packageId
$package.Provider = 'WinGet'
$package.Source = 'winget'

$installedByTest = $false
$installResult = $null
$repairResult = $null
$removeResult = $null

try {

    Write-Host ''
    Write-Host 'Installing the test package...' `
        -ForegroundColor Cyan

    [Result]$installResult =
        $provider.InstallPackage(
            $package,
            [PhoenixInstallMode]::SilentOnly
        )

    $installedByTest = $installResult.Success

    if (-not $installResult.Success) {

        throw (
            "Installation failed: $($installResult.Message)"
        )
    }

    Write-Host ''
    Write-Host 'Calling public Repair-PhoenixPackage...' `
        -ForegroundColor Cyan

    [Result]$repairResult =
        Repair-PhoenixPackage `
            -Id $packageId `
            -Provider WinGet `
            -Mode SilentOnly

    if (-not $repairResult.Success) {

        throw (
            "Repair failed: $($repairResult.Message)"
        )
    }
}
finally {

    if ($installedByTest) {

        Write-Host ''
        Write-Host 'Removing the test package...' `
            -ForegroundColor Yellow

        [Result]$removeResult =
            $provider.RemovePackage(
                $package
            )
    }
}

Write-Host ''
Write-Host 'Public repair command test:' `
    -ForegroundColor Cyan

@(
    [pscustomobject]@{
        Operation = 'Install'
        Success = $installResult.Success
        Code = $installResult.Code
        Message = $installResult.Message
    }

    [pscustomobject]@{
        Operation = 'Public repair'
        Success = $repairResult.Success
        Code = $repairResult.Code
        Message = $repairResult.Message
    }

    [pscustomobject]@{
        Operation = 'Remove'
        Success = $removeResult.Success
        Code = $removeResult.Code
        Message = $removeResult.Message
    }
) |
    Format-Table `
        Operation,
        Success,
        Code,
        Message `
        -AutoSize

if (
    -not $installResult.Success -or
    -not $repairResult.Success -or
    -not $removeResult.Success
) {

    exit 1
}

Write-Host ''
Write-Host (
    'Public Repair-PhoenixPackage test passed.'
) -ForegroundColor Green
