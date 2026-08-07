BeforeAll {
    $projectRoot =
        (
            Resolve-Path `
                (Join-Path $PSScriptRoot '..\..')
        ).Path

    Import-Module `
        (Join-Path $projectRoot 'Phoenix.psd1') `
        -Force `
        6>$null
}

AfterAll {
    Remove-Module `
        Phoenix `
        -Force `
        -ErrorAction SilentlyContinue
}

Describe 'Phoenix built-in package acquisition adapter catalog' -Tag @(
    'Unit'
    'OfflineBundle'
    'ApplicationAcquisition'
    'Adapter'
    'Catalog'
) {
    It 'returns the six built-in adapters in stable priority order' {
        InModuleScope Phoenix {
            $adapters =
                @(
                    Get-PhoenixBuiltInPackageAcquisitionAdapters
                )

            $adapters.Count |
                Should-Be 6

            $actualNames =
                $adapters.Name -join '|'

            $actualNames |
                Should-Be (
                    @(
                        'NuGet Package Acquisition'
                        'PowerShell Gallery Acquisition'
                        'Scoop Package Acquisition'
                        'GitHub Release Acquisition'
                        'MSI Installer Acquisition'
                        'EXE Installer Acquisition'
                    ) -join '|'
                )

            $actualPriorities =
                $adapters.Priority -join '|'

            $actualPriorities |
                Should-Be '600|550|500|450|300|250'
        }
    }

    It 'publishes the exact Phoenix provider identities' {
        InModuleScope Phoenix {
            $adapters =
                @(
                    Get-PhoenixBuiltInPackageAcquisitionAdapters
                )

            ($adapters.Provider -join '|') |
                Should-Be (
                    'NuGet|PowerShell Gallery|Scoop|' +
                    'GitHub|MSI|EXE'
                )
        }
    }

    It 'returns valid enabled nonfallback declarations with unique identities' {
        InModuleScope Phoenix {
            $adapters =
                @(
                    Get-PhoenixBuiltInPackageAcquisitionAdapters
                )

            $adapterIds =
                @(
                    $adapters.AdapterId |
                        Sort-Object -Unique
                )

            $adapterIds.Count |
                Should-Be 6

            foreach ($adapter in $adapters) {
                $adapter.IsValid() |
                    Should-BeTrue

                $adapter.Enabled |
                    Should-BeTrue

                $adapter.IsFallback |
                    Should-BeFalse

                $adapter.Metadata['ImplementationStatus'] |
                    Should-Be 'Declared'
            }
        }
    }

    It 'declares exact installer-type capabilities' {
        InModuleScope Phoenix {
            $byProvider = @{}

            foreach (
                $adapter in
                @(
                    Get-PhoenixBuiltInPackageAcquisitionAdapters
                )
            ) {
                $byProvider[$adapter.Provider] =
                    $adapter
            }

            (
                $byProvider['NuGet'].
                    SupportedInstallerTypes -join '|'
            ) |
                Should-Be 'NuGet'

            (
                $byProvider['PowerShell Gallery'].
                    SupportedInstallerTypes -join '|'
            ) |
                Should-Be 'Module|Script'

            (
                $byProvider['Scoop'].
                    SupportedInstallerTypes -join '|'
            ) |
                Should-Be 'Scoop'

            (
                $byProvider['GitHub'].
                    SupportedInstallerTypes -join '|'
            ) |
                Should-Be 'EXE|MSI|MSIX|ZIP'

            (
                $byProvider['MSI'].
                    SupportedInstallerTypes -join '|'
            ) |
                Should-Be 'MSI'

            (
                $byProvider['EXE'].
                    SupportedInstallerTypes -join '|'
            ) |
                Should-Be 'EXE'
        }
    }

    It 'declares source filters and source policies without narrowing dynamic sources' {
        InModuleScope Phoenix {
            $byProvider = @{}

            foreach (
                $adapter in
                @(
                    Get-PhoenixBuiltInPackageAcquisitionAdapters
                )
            ) {
                $byProvider[$adapter.Provider] =
                    $adapter
            }

            (
                $byProvider['PowerShell Gallery'].
                    SupportedSources -join '|'
            ) |
                Should-Be 'PSGallery'

            foreach (
                $provider in @(
                    'NuGet'
                    'Scoop'
                    'GitHub'
                    'MSI'
                    'EXE'
                )
            ) {
                $byProvider[$provider].
                    SupportedSources.Count |
                    Should-Be 0
            }

            $byProvider['NuGet'].
                Metadata['SourcePolicy'] |
                Should-Be 'AnyConfiguredFeed'

            $byProvider['Scoop'].
                Metadata['SourcePolicy'] |
                Should-Be 'AnyConfiguredBucket'

            $byProvider['GitHub'].
                Metadata['SourcePolicy'] |
                Should-Be 'GitHubRepositoryOrRelease'

            $byProvider['MSI'].
                Metadata['SourcePolicy'] |
                Should-Be 'LocalPathOrDirectUri'

            $byProvider['EXE'].
                Metadata['SourcePolicy'] |
                Should-Be 'LocalPathOrDirectUri'
        }
    }

    It 'declares refresh support only for remotely refreshed providers' {
        InModuleScope Phoenix {
            $byProvider = @{}

            foreach (
                $adapter in
                @(
                    Get-PhoenixBuiltInPackageAcquisitionAdapters
                )
            ) {
                $byProvider[$adapter.Provider] =
                    $adapter
            }

            foreach (
                $provider in @(
                    'NuGet'
                    'PowerShell Gallery'
                    'Scoop'
                    'GitHub'
                )
            ) {
                $byProvider[$provider].
                    SupportsForceRefresh |
                    Should-BeTrue
            }

            foreach (
                $provider in @(
                    'MSI'
                    'EXE'
                )
            ) {
                $byProvider[$provider].
                    SupportsForceRefresh |
                    Should-BeFalse
            }
        }
    }

    It 'declares interaction and user-supplied-media boundaries' {
        InModuleScope Phoenix {
            $byProvider = @{}

            foreach (
                $adapter in
                @(
                    Get-PhoenixBuiltInPackageAcquisitionAdapters
                )
            ) {
                $byProvider[$adapter.Provider] =
                    $adapter
            }

            foreach (
                $provider in @(
                    'NuGet'
                    'PowerShell Gallery'
                    'Scoop'
                    'GitHub'
                )
            ) {
                $byProvider[$provider].
                    SupportsInteractive |
                    Should-BeFalse

                $byProvider[$provider].
                    Metadata['RequiresUserSuppliedMedia'] |
                    Should-BeFalse
            }

            foreach (
                $provider in @(
                    'MSI'
                    'EXE'
                )
            ) {
                $byProvider[$provider].
                    SupportsInteractive |
                    Should-BeTrue

                $byProvider[$provider].
                    Metadata['RequiresUserSuppliedMedia'] |
                    Should-BeTrue
            }
        }
    }

    It 'returns fresh adapter objects on every catalog request' {
        InModuleScope Phoenix {
            $first =
                @(
                    Get-PhoenixBuiltInPackageAcquisitionAdapters
                )

            $second =
                @(
                    Get-PhoenixBuiltInPackageAcquisitionAdapters
                )

            [object]::ReferenceEquals(
                $first[0],
                $second[0]
            ) |
                Should-BeFalse

            (
                $first[0].AdapterId -cne
                    $second[0].AdapterId
            ) |
                Should-BeTrue
        }
    }

    It 'routes NuGet PowerShell Gallery Scoop and GitHub requests exactly' {
        InModuleScope Phoenix {
            $catalog =
                @(
                    Get-PhoenixBuiltInPackageAcquisitionAdapters
                )

            $cases =
                @(
                    @{
                        Provider = 'NuGet'
                        Source = 'https://api.nuget.org/v3/index.json'
                        InstallerType = 'NuGet'
                        Expected = 'NuGet Package Acquisition'
                    }
                    @{
                        Provider = 'PowerShell Gallery'
                        Source = 'PSGallery'
                        InstallerType = 'Module'
                        Expected = 'PowerShell Gallery Acquisition'
                    }
                    @{
                        Provider = 'Scoop'
                        Source = 'main'
                        InstallerType = 'Scoop'
                        Expected = 'Scoop Package Acquisition'
                    }
                    @{
                        Provider = 'GitHub'
                        Source = 'owner/repository'
                        InstallerType = 'MSI'
                        Expected = 'GitHub Release Acquisition'
                    }
                )

            [string]$storeRoot =
                [IO.Path]::GetTempPath()

            foreach ($case in $cases) {
                $package =
                    [Package]::new()

                $package.Id =
                    "Example.$($case.Provider)"

                $package.Provider =
                    [string]$case.Provider

                $package.Source =
                    [string]$case.Source

                $package.InstallerType =
                    [string]$case.InstallerType

                $request =
                    [PhoenixPackageAcquisitionRequest]::new()

                $request.SetPackage($package)
                $request.SetContentStoreRoot(
                    $storeRoot
                )

                $route =
                    Resolve-PhoenixPackageAcquisitionAdapter `
                        -Request $request `
                        -Adapter $catalog

                $route.Resolved |
                    Should-BeTrue

                $route.UsedFallback |
                    Should-BeFalse

                $route.SelectedAdapter.Name |
                    Should-Be (
                        [string]$case.Expected
                    )
            }
        }
    }

    It 'routes MSI and EXE declarations without creating fallback adapters' {
        InModuleScope Phoenix {
            $catalog =
                @(
                    Get-PhoenixBuiltInPackageAcquisitionAdapters
                )

            [string]$storeRoot =
                [IO.Path]::GetTempPath()

            foreach (
                $provider in @(
                    'MSI'
                    'EXE'
                )
            ) {
                $package =
                    [Package]::new()

                $package.Id =
                    "Example.$provider"

                $package.Provider =
                    $provider

                $package.Source =
                    'C:\Installers'

                $package.InstallerType =
                    $provider

                $request =
                    [PhoenixPackageAcquisitionRequest]::new()

                $request.SetPackage($package)
                $request.SetContentStoreRoot(
                    $storeRoot
                )

                $route =
                    Resolve-PhoenixPackageAcquisitionAdapter `
                        -Request $request `
                        -Adapter $catalog

                $route.Resolved |
                    Should-BeTrue

                $route.UsedFallback |
                    Should-BeFalse

                $route.SelectedAdapter.Provider |
                    Should-Be $provider
            }

            @(
                $catalog |
                    Where-Object {
                        $_.IsFallback
                    }
            ).Count |
                Should-Be 0
        }
    }
}
