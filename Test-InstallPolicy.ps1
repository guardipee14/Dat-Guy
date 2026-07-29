using module '.\Classes\Phoenix.Classes.psm1'

class InstallPolicyTestProvider : PhoenixProvider {

    [bool]$ReturnSilentUnavailable
    [string]$LastMethod

    InstallPolicyTestProvider() {

        $this.Name = 'InstallPolicyTest'

        $this.SupportsSilentInstall = $true
        $this.SupportsInteractiveInstall = $true

        $this.ReturnSilentUnavailable = $true
        $this.LastMethod = ''
    }

    [bool] CanInstallSilently([Package]$Package) {

        return $true
    }

    [Result] InstallPackageSilent([Package]$Package) {

        $this.LastMethod = 'Silent'

        if ($this.ReturnSilentUnavailable) {

            $result = [Result]::Failure(
                'No silent installer is available.'
            )

            $result.Code = 'PHX_SILENT_UNAVAILABLE'

            return $result
        }

        $result = [Result]::Failure(
            'The silent installer failed.'
        )

        $result.Code = 'PHX_INSTALL_FAILED'

        return $result
    }

    [Result] InstallPackageInteractive([Package]$Package) {

        $this.LastMethod = 'Interactive'

        $result = [Result]::Success(
            'Interactive fallback selected.'
        )

        $result.Code = 'PHX_INSTALLED_INTERACTIVE'

        return $result
    }
}

$package = [Package]::new()

$package.Name = 'Test Package'
$package.Id = 'test.package'

$provider = [InstallPolicyTestProvider]::new()

Write-Host ''
Write-Host 'Test 1: Silent unavailable should fall back' `
    -ForegroundColor Cyan

$provider.ReturnSilentUnavailable = $true
$provider.LastMethod = ''

$result = $provider.InstallPackage($package)

[pscustomobject]@{
    Test       = 'Silent unavailable'
    Success    = $result.Success
    Code       = $result.Code
    LastMethod = $provider.LastMethod
    Data       = $result.Data
} | Format-List

Write-Host ''
Write-Host 'Test 2: Ordinary failure must not fall back' `
    -ForegroundColor Cyan

$provider.ReturnSilentUnavailable = $false
$provider.LastMethod = ''

$result = $provider.InstallPackage($package)

[pscustomobject]@{
    Test       = 'Silent failed'
    Success    = $result.Success
    Code       = $result.Code
    LastMethod = $provider.LastMethod
    Data       = $result.Data
} | Format-List

Write-Host ''
Write-Host 'Test 3: Forced interactive mode' `
    -ForegroundColor Cyan

$provider.LastMethod = ''

$result = $provider.InstallPackage(
    $package,
    [PhoenixInstallMode]::InteractiveOnly
)

[pscustomobject]@{
    Test       = 'Interactive only'
    Success    = $result.Success
    Code       = $result.Code
    LastMethod = $provider.LastMethod
    Data       = $result.Data
} | Format-List