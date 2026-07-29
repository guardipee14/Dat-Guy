using module '.\Classes\Phoenix.Classes.psm1'

[CmdletBinding()]
param(
    [Parameter()]
    [string]$PackageId = 'Microsoft.WingetCreate',

    [Parameter()]
    [switch]$KeepInstalled
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module '.\Phoenix.psd1' -Force

function Get-WinGetExecutable {

    $command = Get-Command `
        winget.exe `
        -ErrorAction SilentlyContinue

    if ($null -eq $command) {
        throw 'winget.exe could not be located.'
    }

    return $command.Source
}

function Test-WinGetPackageAvailable {

    param(
        [Parameter(Mandatory)]
        [string]$WinGetExecutable,

        [Parameter(Mandatory)]
        [string]$Id
    )

    $null = & $WinGetExecutable `
        show `
        --id $Id `
        --exact `
        --source winget `
        --accept-source-agreements `
        --disable-interactivity `
        2>&1

    return ($LASTEXITCODE -eq 0)
}

function Test-WinGetPackageInstalled {

    param(
        [Parameter(Mandatory)]
        [string]$WinGetExecutable,

        [Parameter(Mandatory)]
        [string]$Id
    )

    [string[]]$output = @(
        & $WinGetExecutable `
            list `
            --id $Id `
            --exact `
            --source winget `
            --accept-source-agreements `
            --disable-interactivity `
            2>&1 |
        ForEach-Object {
            $_.ToString()
        }
    )

    if ($LASTEXITCODE -ne 0) {
        return $false
    }

    [string]$escapedId = [regex]::Escape($Id)

    return (
        @(
            $output |
                Where-Object {
                    $_ -match $escapedId
                }
        ).Count -gt 0
    )
}

function Get-PhoenixWorkingEntries {

    param(
        [Parameter(Mandatory)]
        [string]$WorkingRoot
    )

    return @(
        Get-ChildItem `
            -LiteralPath $WorkingRoot `
            -Force `
            -ErrorAction SilentlyContinue |
        ForEach-Object {
            $_.FullName
        }
    )
}

function Get-NewWorkingEntries {

    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$Before = @(),

        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$After = @()
    )

    [string[]]$beforeEntries = @($Before)
    [string[]]$afterEntries = @($After)

    return @(
        $afterEntries |
            Where-Object {
                $_ -notin $beforeEntries
            }
    )
}

function New-WinGetTestPackage {

    param(
        [Parameter(Mandatory)]
        [string]$Id
    )

    [Package]$package = [Package]::new()

    $package.Id = $Id
    $package.Name = $Id
    $package.Provider = 'WinGet'
    $package.Source = 'winget'

    return $package
}

Start-Phoenix

$provider = @(
    Get-PhoenixProviders |
        Where-Object {
            $_.Name -eq 'WinGet'
        }
) | Select-Object -First 1

if ($null -eq $provider) {
    throw 'WinGetProvider was not initialized.'
}

if (-not $provider.Available) {
    throw 'WinGetProvider is unavailable.'
}

if (-not $provider.SupportsRepair) {
    throw 'WinGetProvider repair support is disabled.'
}

$context = Get-PhoenixContext

if ($null -eq $context) {
    throw 'PhoenixContext was not initialized.'
}

$wingetExecutable = Get-WinGetExecutable
$workingRoot = $context.WorkingRoot

if (-not (Test-Path -LiteralPath $workingRoot)) {

    $null = New-Item `
        -ItemType Directory `
        -Path $workingRoot `
        -Force
}

if (
    -not (
        Test-WinGetPackageAvailable `
            -WinGetExecutable $wingetExecutable `
            -Id $PackageId
    )
) {

    throw (
        "The WinGet test package '$PackageId' was not found " +
        'in the winget source.'
    )
}

if (
    Test-WinGetPackageInstalled `
        -WinGetExecutable $wingetExecutable `
        -Id $PackageId
) {

    throw (
        "'$PackageId' is already installed. " +
        'The test stopped without modifying it.'
    )
}

$installedByTest = $false
$installPackage = $null
$repairPackage = $null

$testResults =
    [System.Collections.Generic.List[object]]::new()

try {

    Write-Host ''
    Write-Host (
        "Selected disposable package: $PackageId"
    ) -ForegroundColor Cyan

    ##########################################################
    ## Real silent installation
    ##########################################################

    $installPackage = New-WinGetTestPackage `
        -Id $PackageId

    [string[]]$beforeInstall = @(
        Get-PhoenixWorkingEntries `
            -WorkingRoot $workingRoot
    )

    Write-Host ''
    Write-Host 'Running real WinGet silent installation...' `
        -ForegroundColor Cyan

    [Result]$installResult = $provider.InstallPackage(
        $installPackage,
        [PhoenixInstallMode]::SilentOnly
    )

    $installedByTest = $installResult.Success

    [string[]]$afterInstall = @(
        Get-PhoenixWorkingEntries `
            -WorkingRoot $workingRoot
    )

    [string[]]$installLeftovers = @(
        Get-NewWorkingEntries `
            -Before $beforeInstall `
            -After $afterInstall
    )

    [bool]$packageDetected =
        Test-WinGetPackageInstalled `
            -WinGetExecutable $wingetExecutable `
            -Id $PackageId

    $installedByTest = (
        $installResult.Success -and
        $packageDetected
    )

    $testResults.Add(
        [pscustomobject]@{
            Test = 'Real WinGet installation'
            Success = $installResult.Success
            Code = $installResult.Code
            Passed = (
                $installResult.Success -and
                $packageDetected
            )
        }
    )

    $testResults.Add(
        [pscustomobject]@{
            Test = 'Install Phoenix cleanup'
            Success = (@($installLeftovers).Count -eq 0)
            Code = if (@($installLeftovers).Count -eq 0) {
                'PHX_CLEANUP_COMPLETE'
            }
            else {
                'PHX_CLEANUP_LEFTOVERS'
            }
            Passed = (@($installLeftovers).Count -eq 0)
        }
    )

    if (-not $installResult.Success) {
        throw "WinGet installation failed: $($installResult.Message)"
    }

    if (-not $packageDetected) {
        throw 'WinGet did not report the test package as installed.'
    }

    ##########################################################
    ## Real silent repair
    ##########################################################

    $repairPackage = New-WinGetTestPackage `
        -Id $PackageId

    [string[]]$beforeRepair = @(
        Get-PhoenixWorkingEntries `
            -WorkingRoot $workingRoot
    )

    Write-Host ''
    Write-Host 'Running real WinGet silent repair...' `
        -ForegroundColor Cyan

    [Result]$repairResult = $provider.RepairPackage(
        $repairPackage,
        [PhoenixInstallMode]::SilentOnly
    )

    [string[]]$afterRepair = @(
        Get-PhoenixWorkingEntries `
            -WorkingRoot $workingRoot
    )

    [string[]]$repairLeftovers = @(
        Get-NewWorkingEntries `
            -Before $beforeRepair `
            -After $afterRepair
    )

    $testResults.Add(
        [pscustomobject]@{
            Test = 'Real WinGet repair'
            Success = $repairResult.Success
            Code = $repairResult.Code
            Passed = $repairResult.Success
        }
    )

    $testResults.Add(
        [pscustomobject]@{
            Test = 'Repair Phoenix cleanup'
            Success = (@($repairLeftovers).Count -eq 0)
            Code = if (@($repairLeftovers).Count -eq 0) {
                'PHX_CLEANUP_COMPLETE'
            }
            else {
                'PHX_CLEANUP_LEFTOVERS'
            }
            Passed = (@($repairLeftovers).Count -eq 0)
        }
    )

    if (@($installLeftovers).Count -gt 0) {

        Write-Warning 'Install cleanup left these Phoenix paths:'

        $installLeftovers |
            ForEach-Object {
                Write-Warning "  $_"
            }
    }

    if (@($repairLeftovers).Count -gt 0) {

        Write-Warning 'Repair cleanup left these Phoenix paths:'

        $repairLeftovers |
            ForEach-Object {
                Write-Warning "  $_"
            }
    }
}
finally {

    foreach ($package in @(
        $installPackage
        $repairPackage
    )) {

        if ($null -ne $package) {
            $null = $provider.CleanupPackage($package)
        }
    }

    if (
        $installedByTest -and
        (-not $KeepInstalled)
    ) {

        Write-Host ''
        Write-Host (
            "Removing disposable package '$PackageId' through Phoenix..."
        ) -ForegroundColor Yellow

        [Result]$removeResult =
            $provider.RemovePackage($installPackage)

        $testResults.Add(
            [pscustomobject]@{
                Test = 'Real WinGet removal'
                Success = $removeResult.Success
                Code = $removeResult.Code
                Passed = $removeResult.Success
            }
        )

        if (-not $removeResult.Success) {

            Write-Warning (
                "Phoenix removal failed: $($removeResult.Message)"
            )

            Write-Warning (
                'Attempting direct WinGet cleanup fallback.'
            )

            & $wingetExecutable `
                uninstall `
                --id $PackageId `
                --exact `
                --source winget `
                --silent `
                --disable-interactivity `
                --accept-source-agreements |
                Out-Host
        }
    }
}

Write-Host ''
Write-Host 'Real WinGet test results:' `
    -ForegroundColor Cyan

$testResults |
    Format-Table `
        Test,
        Success,
        Code,
        Passed `
        -AutoSize

if ($testResults.Passed -contains $false) {

    Write-Warning (
        'One or more real WinGet tests failed.'
    )

    exit 1
}

Write-Host ''
Write-Host (
    'All real WinGet install, repair, cleanup, and removal tests passed.'
) -ForegroundColor Green

