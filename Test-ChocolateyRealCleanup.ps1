using module '.\Classes\Phoenix.Classes.psm1'

[CmdletBinding()]
param(
    [Parameter()]
    [string]$PreferredPackageId = 'jq',

    [Parameter()]
    [switch]$KeepInstalled
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module '.\Phoenix.psd1' -Force

function Test-IsAdministrator {

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()

    $principal = [Security.Principal.WindowsPrincipal]::new(
        $identity
    )

    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Get-ChocolateyExecutable {

    $command = Get-Command `
        choco.exe `
        -ErrorAction SilentlyContinue

    if ($null -ne $command) {
        return $command.Source
    }

    $fallback = Join-Path `
        $env:ProgramData `
        'chocolatey\bin\choco.exe'

    if (Test-Path -LiteralPath $fallback) {
        return $fallback
    }

    throw 'Chocolatey executable could not be found.'
}

function Test-ChocolateyPackageInstalled {

    param(
        [Parameter(Mandatory)]
        [string]$ChocolateyExecutable,

        [Parameter(Mandatory)]
        [string]$PackageId
    )

    $output = @(
        & $ChocolateyExecutable `
            list `
            --exact `
            $PackageId `
            --limit-output `
            2>&1
    )

    $pattern = '^{0}\|' -f [regex]::Escape($PackageId)

    return @(
        $output |
            Where-Object {
                $_ -match $pattern
            }
    ).Count -gt 0
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

    [string[]]$beforeEntries = @(
        $Before
    )

    [string[]]$afterEntries = @(
        $After
    )

    [string[]]$newEntries = @(
        $afterEntries |
            Where-Object {
                $_ -notin $beforeEntries
            }
    )

    return $newEntries
}

function New-TestPackage {

    param(
        [Parameter(Mandatory)]
        [string]$PackageId
    )

    [Package]$package = [Package]::new()

    $package.Id = $PackageId
    $package.Name = $PackageId
    $package.Provider = 'Chocolatey'

    return $package
}

if (-not (Test-IsAdministrator)) {

    throw (
        'This real Chocolatey test must run from an ' +
        'Administrator PowerShell process.'
    )
}

Start-Phoenix

$provider = @(
    Get-PhoenixProviders |
        Where-Object {
            $_.Name -eq 'Chocolatey'
        }
) | Select-Object -First 1

if ($null -eq $provider) {
    throw 'ChocolateyProvider was not initialized.'
}

if (-not $provider.Available) {
    throw 'ChocolateyProvider is not available.'
}

$context = Get-PhoenixContext

if ($null -eq $context) {
    throw 'PhoenixContext was not initialized.'
}

$chocoExecutable = Get-ChocolateyExecutable

$candidates = @(
    $PreferredPackageId
    'jq'
    'yq'
) |
    Select-Object -Unique

$packageId = $null

foreach ($candidate in $candidates) {

    if (
        -not (
            Test-ChocolateyPackageInstalled `
                -ChocolateyExecutable $chocoExecutable `
                -PackageId $candidate
        )
    ) {

        $packageId = $candidate
        break
    }
}

if ([string]::IsNullOrWhiteSpace($packageId)) {

    throw (
        'All disposable test candidates are already installed. ' +
        'No existing package was modified.'
    )
}

$workingRoot = $context.WorkingRoot

if (-not (Test-Path -LiteralPath $workingRoot)) {

    $null = New-Item `
        -ItemType Directory `
        -Path $workingRoot `
        -Force
}

$installedByTest = $false
$installPackage = $null
$repairPackage = $null

$testResults =
    [System.Collections.Generic.List[object]]::new()

try {

    Write-Host ''
    Write-Host (
        "Selected disposable package: $packageId"
    ) -ForegroundColor Cyan

    ##########################################################
    ## Real installation and cleanup test
    ##########################################################

    $installPackage = New-TestPackage `
        -PackageId $packageId

    [string[]]$beforeInstall = @(
    Get-PhoenixWorkingEntries `
        -WorkingRoot $workingRoot
)

    Write-Host ''
    Write-Host 'Running real silent installation...' `
        -ForegroundColor Cyan

    $installResult = $provider.InstallPackage(
        $installPackage,
        [PhoenixInstallMode]::SilentOnly
    )
    $installedByTest = $installResult.Success

    [string[]]$afterInstall = @(
    Get-PhoenixWorkingEntries `
        -WorkingRoot $workingRoot
)

    [string[]]$beforeRepair = @(
    Get-PhoenixWorkingEntries `
        -WorkingRoot $workingRoot
)

    [string[]]$afterRepair = @(
    Get-PhoenixWorkingEntries `
        -WorkingRoot $workingRoot
)

    [string[]]$installLeftovers = @(
    Get-NewWorkingEntries `
        -Before $beforeInstall `
        -After $afterInstall
)

    $packageDetected = Test-ChocolateyPackageInstalled `
        -ChocolateyExecutable $chocoExecutable `
        -PackageId $packageId

    $installedByTest = (
        $installResult.Success -and
        $packageDetected
    )

    $testResults.Add(
        [pscustomobject]@{
            Test = 'Real Chocolatey installation'
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
            Test = 'Install download cleanup'
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

        throw (
            "Installation failed: $($installResult.Message)"
        )
    }

    if (-not $packageDetected) {

        throw (
            'Chocolatey did not report the test package as installed.'
        )
    }

    ##########################################################
    ## Real repair and cleanup test
    ##########################################################

    $repairPackage = New-TestPackage `
        -PackageId $packageId

    $beforeRepair = Get-PhoenixWorkingEntries `
        -WorkingRoot $workingRoot

    Write-Host ''
    Write-Host 'Running real silent repair...' `
        -ForegroundColor Cyan

    $repairResult = $provider.RepairPackage(
        $repairPackage,
        [PhoenixInstallMode]::SilentOnly
    )

    $afterRepair = Get-PhoenixWorkingEntries `
        -WorkingRoot $workingRoot

    [string[]]$repairLeftovers = @(
    Get-NewWorkingEntries `
        -Before $beforeRepair `
        -After $afterRepair
)

    $testResults.Add(
        [pscustomobject]@{
            Test = 'Real Chocolatey repair'
            Success = $repairResult.Success
            Code = $repairResult.Code
            Passed = $repairResult.Success
        }
    )

    $testResults.Add(
        [pscustomobject]@{
            Test = 'Repair download cleanup'
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

        Write-Warning 'Install cleanup left these paths:'

        $installLeftovers |
            ForEach-Object {
                Write-Warning "  $_"
            }
    }

    if (@($repairLeftovers).Count -gt 0) {

        Write-Warning 'Repair cleanup left these paths:'

        $repairLeftovers |
            ForEach-Object {
                Write-Warning "  $_"
            }
    }
}
finally {

    # Remove any Phoenix working paths preserved after a failure.
    foreach ($package in @(
        $installPackage
        $repairPackage
    )) {

        if ($null -ne $package) {

            $null = $provider.CleanupPackage(
                $package
            )
        }
    }

    if (
        $installedByTest -and
        (-not $KeepInstalled)
    ) {

        Write-Host ''
        Write-Host (
            "Removing disposable package '$packageId'..."
        ) -ForegroundColor Yellow

        & $chocoExecutable `
            uninstall `
            $packageId `
            --yes `
            --no-progress |
            Out-Host

        if ($LASTEXITCODE -ne 0) {

            Write-Warning (
                "Chocolatey uninstall returned exit code " +
                "$LASTEXITCODE."
            )
        }
    }
}

Write-Host ''
Write-Host 'Real Chocolatey test results:' `
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
        'One or more real Chocolatey tests failed.'
    )

    exit 1
}

Write-Host ''
Write-Host (
    'All real Chocolatey install, repair, and cleanup tests passed.'
) -ForegroundColor Green

