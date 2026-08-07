function New-PhoenixBuiltInPackageAcquisitionAdapter {

    [CmdletBinding()]
    [OutputType([PhoenixPackageAcquisitionAdapter])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Provider,

        [Parameter(Mandatory)]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$Priority,

        [Parameter()]
        [AllowEmptyCollection()]
        [string[]]$SupportedSource = @(),

        [Parameter()]
        [AllowEmptyCollection()]
        [string[]]$SupportedInstallerType = @(),

        [Parameter()]
        [switch]$SupportsInteractive,

        [Parameter()]
        [switch]$SupportsForceRefresh,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SourcePolicy,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$AcquisitionMode,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ProviderClass,

        [Parameter()]
        [switch]$RequiresUserSuppliedMedia
    )

    $adapter =
        [PhoenixPackageAcquisitionAdapter]::new()

    $adapter.SetIdentity(
        $Name,
        $Provider
    )

    $adapter.Priority =
        $Priority

    $adapter.SupportsInteractive =
        $SupportsInteractive.IsPresent

    $adapter.SupportsForceRefresh =
        $SupportsForceRefresh.IsPresent

    foreach ($source in @($SupportedSource)) {
        $adapter.AddSupportedSource(
            $source
        )
    }

    foreach (
        $installerType in
        @($SupportedInstallerType)
    ) {
        $adapter.AddSupportedInstallerType(
            $installerType
        )
    }

    $adapter.Metadata['CatalogId'] =
        'Phoenix.BuiltIn.PackageAcquisition'

    $adapter.Metadata['CatalogVersion'] =
        '1.0'

    $adapter.Metadata['ImplementationStatus'] =
        'Declared'

    $adapter.Metadata['SourcePolicy'] =
        $SourcePolicy

    $adapter.Metadata['AcquisitionMode'] =
        $AcquisitionMode

    $adapter.Metadata['ProviderClass'] =
        $ProviderClass

    $adapter.Metadata['RequiresUserSuppliedMedia'] =
        $RequiresUserSuppliedMedia.IsPresent

    if (-not $adapter.IsValid()) {
        throw (
            "The built-in acquisition adapter '$Name' is invalid."
        )
    }

    return $adapter
}

function Get-PhoenixBuiltInPackageAcquisitionAdapters {

    [CmdletBinding()]
    [OutputType([PhoenixPackageAcquisitionAdapter[]])]
    param()

    [PhoenixPackageAcquisitionAdapter[]]$adapters =
        @(
            New-PhoenixBuiltInPackageAcquisitionAdapter `
                -Name 'NuGet Package Acquisition' `
                -Provider 'NuGet' `
                -Priority 600 `
                -SupportedInstallerType @(
                    'NuGet'
                ) `
                -SupportsForceRefresh `
                -SourcePolicy 'AnyConfiguredFeed' `
                -AcquisitionMode 'RemotePackage' `
                -ProviderClass 'NuGetProvider'

            New-PhoenixBuiltInPackageAcquisitionAdapter `
                -Name 'PowerShell Gallery Acquisition' `
                -Provider 'PowerShell Gallery' `
                -Priority 550 `
                -SupportedSource @(
                    'PSGallery'
                ) `
                -SupportedInstallerType @(
                    'Module'
                    'Script'
                ) `
                -SupportsForceRefresh `
                -SourcePolicy 'NamedRepository' `
                -AcquisitionMode 'RemoteResource' `
                -ProviderClass 'PowerShellGalleryProvider'

            New-PhoenixBuiltInPackageAcquisitionAdapter `
                -Name 'Scoop Package Acquisition' `
                -Provider 'Scoop' `
                -Priority 500 `
                -SupportedInstallerType @(
                    'Scoop'
                ) `
                -SupportsForceRefresh `
                -SourcePolicy 'AnyConfiguredBucket' `
                -AcquisitionMode 'PackageManagerExport' `
                -ProviderClass 'ScoopProvider'

            New-PhoenixBuiltInPackageAcquisitionAdapter `
                -Name 'GitHub Release Acquisition' `
                -Provider 'GitHub' `
                -Priority 450 `
                -SupportedInstallerType @(
                    'EXE'
                    'MSI'
                    'MSIX'
                    'ZIP'
                ) `
                -SupportsForceRefresh `
                -SourcePolicy 'GitHubRepositoryOrRelease' `
                -AcquisitionMode 'ReleaseAsset' `
                -ProviderClass 'GitHubProvider'

            New-PhoenixBuiltInPackageAcquisitionAdapter `
                -Name 'MSI Installer Acquisition' `
                -Provider 'MSI' `
                -Priority 300 `
                -SupportedInstallerType @(
                    'MSI'
                ) `
                -SupportsInteractive `
                -SourcePolicy 'LocalPathOrDirectUri' `
                -AcquisitionMode 'InstallerMedia' `
                -ProviderClass 'MSIProvider' `
                -RequiresUserSuppliedMedia

            New-PhoenixBuiltInPackageAcquisitionAdapter `
                -Name 'EXE Installer Acquisition' `
                -Provider 'EXE' `
                -Priority 250 `
                -SupportedInstallerType @(
                    'EXE'
                ) `
                -SupportsInteractive `
                -SourcePolicy 'LocalPathOrDirectUri' `
                -AcquisitionMode 'InstallerMedia' `
                -ProviderClass 'EXEProvider' `
                -RequiresUserSuppliedMedia
        )

    return $adapters
}
