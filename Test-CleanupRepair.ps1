using module '.\Classes\Phoenix.Classes.psm1'

Import-Module '.\Phoenix.psd1' -Force

class PhoenixCleanupTestProvider : PhoenixProvider {

    [bool]$ShouldSucceed
    [string]$LastWorkingDirectory

    PhoenixCleanupTestProvider() {

        $this.Name = 'PhoenixCleanupTest'
        $this.Available = $true

        $this.SupportsSilentInstall = $true
        $this.SupportsInteractiveInstall = $false

        $this.SupportsRepair = $true
        $this.SupportsSilentRepair = $true
        $this.SupportsInteractiveRepair = $false

        $this.SupportsCleanup = $true
        $this.CleanupAfterInstall = $true
        $this.CleanupOnFailure = $false

        $this.ShouldSucceed = $true
        $this.LastWorkingDirectory = ''
    }

    hidden [string] CreateTestDownload(
        [Package]$Package,
        [string]$FileName
    ) {

        [string]$workingDirectory =
            $this.NewPackageWorkingDirectory(
                $Package
            )

        [string]$downloadPath = Join-Path `
            $workingDirectory `
            $FileName

        [IO.File]::WriteAllText(
            $downloadPath,
            'Phoenix temporary download test.'
        )

        $Package.DownloadedFile = $downloadPath
        $this.LastWorkingDirectory = $workingDirectory

        return $downloadPath
    }

    [Result] InstallPackageSilent(
        [Package]$Package
    ) {

        $null = $this.CreateTestDownload(
            $Package,
            'test-installer.exe'
        )

        if ($this.ShouldSucceed) {

            $Package.Installed = $true

            [Result]$result = [Result]::Success(
                'Simulated installation completed.'
            )

            $result.Code = 'PHX_INSTALLED'

            return $result
        }

        return $this.NewFailure(
            'Simulated installation failure.',
            'PHX_INSTALL_FAILED'
        )
    }

    [Result] RepairPackageSilent(
        [Package]$Package
    ) {

        $null = $this.CreateTestDownload(
            $Package,
            'test-repair-installer.exe'
        )

        [Result]$result = [Result]::Success(
            'Simulated repair completed.'
        )

        $result.Code = 'PHX_REPAIRED'

        return $result
    }
}

function New-PhoenixCleanupTestPackage {

    param(
        [Parameter(Mandatory)]
        [string]$Id
    )

    [Package]$package = [Package]::new()

    $package.Id = $Id
    $package.Name = $Id
    $package.Provider = 'PhoenixCleanupTest'

    return $package
}

Start-Phoenix

$context = Get-PhoenixContext

if ($null -eq $context) {
    throw 'Phoenix context was not initialized.'
}

$provider = [PhoenixCleanupTestProvider]::new()

$testResults =
    [System.Collections.Generic.List[object]]::new()

##########################################################
## Test 1: Successful installation cleanup
##########################################################

$provider.ShouldSucceed = $true
$provider.CleanupOnFailure = $false

$package1 = New-PhoenixCleanupTestPackage `
    -Id 'cleanup.success'

$result1 = $provider.InstallPackage(
    $package1,
    [PhoenixInstallMode]::SilentOnly
)

$path1 = $provider.LastWorkingDirectory
$removed1 = -not (Test-Path -LiteralPath $path1)

$testResults.Add(
    [pscustomobject]@{
        Test = 'Successful install cleanup'
        Success = $result1.Success
        Code = $result1.Code
        PathRemoved = $removed1
        Passed = (
            $result1.Success -and
            $removed1
        )
    }
)

##########################################################
## Test 2: Failed installation preserves files
##########################################################

$provider.ShouldSucceed = $false
$provider.CleanupOnFailure = $false

$package2 = New-PhoenixCleanupTestPackage `
    -Id 'cleanup.failure.preserved'

$result2 = $provider.InstallPackage(
    $package2,
    [PhoenixInstallMode]::SilentOnly
)

$path2 = $provider.LastWorkingDirectory
$preserved2 = Test-Path -LiteralPath $path2

$manualCleanupResult =
    $provider.CleanupPackage(
        $package2
    )

$removedAfterManualCleanup =
    -not (Test-Path -LiteralPath $path2)

$testResults.Add(
    [pscustomobject]@{
        Test = 'Failed install preserved'
        Success = $result2.Success
        Code = $result2.Code
        PathRemoved = -not $preserved2
        Passed = (
            (-not $result2.Success) -and
            $preserved2 -and
            $manualCleanupResult.Success -and
            $removedAfterManualCleanup
        )
    }
)

##########################################################
## Test 3: Cleanup after failure
##########################################################

$provider.ShouldSucceed = $false
$provider.CleanupOnFailure = $true

$package3 = New-PhoenixCleanupTestPackage `
    -Id 'cleanup.failure.removed'

$result3 = $provider.InstallPackage(
    $package3,
    [PhoenixInstallMode]::SilentOnly
)

$path3 = $provider.LastWorkingDirectory
$removed3 = -not (Test-Path -LiteralPath $path3)

$testResults.Add(
    [pscustomobject]@{
        Test = 'Cleanup on failure'
        Success = $result3.Success
        Code = $result3.Code
        PathRemoved = $removed3
        Passed = (
            (-not $result3.Success) -and
            $removed3
        )
    }
)

##########################################################
## Test 4: Successful repair cleanup
##########################################################

$provider.CleanupOnFailure = $false

$package4 = New-PhoenixCleanupTestPackage `
    -Id 'cleanup.repair.success'

$result4 = $provider.RepairPackage(
    $package4,
    [PhoenixInstallMode]::SilentOnly
)

$path4 = $provider.LastWorkingDirectory
$removed4 = -not (Test-Path -LiteralPath $path4)

$testResults.Add(
    [pscustomobject]@{
        Test = 'Successful repair cleanup'
        Success = $result4.Success
        Code = $result4.Code
        PathRemoved = $removed4
        Passed = (
            $result4.Success -and
            $removed4
        )
    }
)

Write-Host ''
Write-Host 'Cleanup and repair test results:' `
    -ForegroundColor Cyan

$testResults |
    Format-Table `
        Test,
        Success,
        Code,
        PathRemoved,
        Passed `
        -AutoSize

if ($testResults.Passed -notcontains $false) {

    Write-Host ''
    Write-Host (
        'All cleanup and repair tests passed.'
    ) -ForegroundColor Green
}
else {

    Write-Host ''
    Write-Warning (
        'One or more cleanup or repair tests failed.'
    )

    exit 1
}
