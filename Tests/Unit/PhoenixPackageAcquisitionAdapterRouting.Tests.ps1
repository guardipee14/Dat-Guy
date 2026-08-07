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

Describe 'Phoenix package acquisition adapter routing contract' -Tag @(
    'Unit'
    'OfflineBundle'
    'ApplicationAcquisition'
    'Adapter'
    'Routing'
) {
    It 'publishes the exact adapter properties' {
        InModuleScope Phoenix {
            $adapter =
                [PhoenixPackageAcquisitionAdapter]::new()

            $expectedProperties =
                @(
                    'AdapterId'
                    'Name'
                    'Provider'
                    'Priority'
                    'Enabled'
                    'IsFallback'
                    'SupportedSources'
                    'SupportedInstallerTypes'
                    'SupportsInteractive'
                    'SupportsForceRefresh'
                    'Metadata'
                )

            $actualProperties =
                @(
                    $adapter.PSObject.Properties.Name
                )

            $actualProperties.Count |
                Should-Be $expectedProperties.Count

            for (
                $index = 0
                $index -lt $expectedProperties.Count
                $index++
            ) {
                (
                    $actualProperties[$index] -ceq
                        $expectedProperties[$index]
                ) |
                    Should-BeTrue
            }
        }
    }

    It 'starts enabled but invalid until it has an identity' {
        InModuleScope Phoenix {
            $adapter =
                [PhoenixPackageAcquisitionAdapter]::new()

            $adapter.Enabled |
                Should-BeTrue

            $adapter.IsFallback |
                Should-BeFalse

            $adapter.Priority |
                Should-Be 0

            $adapter.SupportedSources.Count |
                Should-Be 0

            $adapter.SupportedInstallerTypes.Count |
                Should-Be 0

            $adapter.IsValid() |
                Should-BeFalse
        }
    }

    It 'normalizes identity and deduplicates capability filters' {
        InModuleScope Phoenix {
            $adapter =
                [PhoenixPackageAcquisitionAdapter]::new()

            $adapter.SetIdentity(
                '  NuGet Adapter  ',
                '  NuGet  '
            )

            $adapter.AddSupportedSource('NuGet.org')
            $adapter.AddSupportedSource('nuget.ORG')
            $adapter.AddSupportedInstallerType('Nupkg')
            $adapter.AddSupportedInstallerType('NUPKG')

            $adapter.Name |
                Should-Be 'NuGet Adapter'

            $adapter.Provider |
                Should-Be 'NuGet'

            $adapter.SupportedSources.Count |
                Should-Be 1

            $adapter.SupportedInstallerTypes.Count |
                Should-Be 1

            $adapter.IsValid() |
                Should-BeTrue
        }
    }

    It 'matches provider source and installer type without case sensitivity' {
        InModuleScope Phoenix {
            $package =
                [Package]::new()

            $package.Id = 'Example.Package'
            $package.Provider = 'nuget'
            $package.Source = 'NUGET.ORG'
            $package.InstallerType = 'NUPKG'

            $request =
                [PhoenixPackageAcquisitionRequest]::new()

            $request.SetPackage($package)
            $request.SetContentStoreRoot(
                [IO.Path]::GetTempPath()
            )

            $adapter =
                [PhoenixPackageAcquisitionAdapter]::new()

            $adapter.SetIdentity(
                'NuGet Adapter',
                'NuGet'
            )

            $adapter.AddSupportedSource('nuget.org')
            $adapter.AddSupportedInstallerType('nupkg')

            $adapter.CanHandle($request) |
                Should-BeTrue
        }
    }

    It 'requires force-refresh support only when the request asks for it' {
        InModuleScope Phoenix {
            $package =
                [Package]::new()

            $package.Id = 'Example.Refresh'
            $package.Provider = 'NuGet'

            $request =
                [PhoenixPackageAcquisitionRequest]::new()

            $request.SetPackage($package)
            $request.SetContentStoreRoot(
                [IO.Path]::GetTempPath()
            )

            $adapter =
                [PhoenixPackageAcquisitionAdapter]::new()

            $adapter.SetIdentity(
                'NuGet Adapter',
                'NuGet'
            )

            $request.ForceRefresh = $true

            $adapter.CanHandle($request) |
                Should-BeFalse

            $adapter.SupportsForceRefresh = $true

            $adapter.CanHandle($request) |
                Should-BeTrue
        }
    }

    It 'permits wildcard fallback only through explicit fallback matching' {
        InModuleScope Phoenix {
            $package =
                [Package]::new()

            $package.Id = 'Example.Fallback'
            $package.Provider = 'UnknownProvider'

            $request =
                [PhoenixPackageAcquisitionRequest]::new()

            $request.SetPackage($package)
            $request.SetContentStoreRoot(
                [IO.Path]::GetTempPath()
            )

            $adapter =
                [PhoenixPackageAcquisitionAdapter]::new()

            $adapter.SetIdentity(
                'User Supplied Adapter',
                '*'
            )

            $adapter.IsFallback = $true

            $adapter.IsValid() |
                Should-BeTrue

            $adapter.CanHandle($request) |
                Should-BeFalse

            $adapter.CanHandle(
                $request,
                $true
            ) |
                Should-BeTrue
        }
    }

    It 'returns a typed unsupported result before an adapter implements acquisition' {
        InModuleScope Phoenix {
            $package =
                [Package]::new()

            $package.Id = 'Example.Pending'
            $package.Provider = 'NuGet'

            $request =
                [PhoenixPackageAcquisitionRequest]::new()

            $request.SetPackage($package)
            $request.SetContentStoreRoot(
                [IO.Path]::GetTempPath()
            )

            $adapter =
                [PhoenixPackageAcquisitionAdapter]::new()

            $adapter.SetIdentity(
                'NuGet Adapter',
                'NuGet'
            )

            $result =
                $adapter.Acquire($request)

            $result.Status |
                Should-Be (
                    [PhoenixPackageAcquisitionStatus]::Unsupported
                )

            $result.Success |
                Should-BeFalse

            $result.Code |
                Should-Be 'PHX_PACKAGE_ACQUISITION_NOT_IMPLEMENTED'

            $result.Metadata['AdapterId'] |
                Should-Be $adapter.AdapterId

            $result.Metadata['RequestId'] |
                Should-Be $request.RequestId

            $result.IsValid() |
                Should-BeTrue
        }
    }

    It 'publishes the exact route properties and unresolved defaults' {
        InModuleScope Phoenix {
            $route =
                [PhoenixPackageAcquisitionRoute]::new()

            $expectedProperties =
                @(
                    'RequestId'
                    'Resolved'
                    'UsedFallback'
                    'SelectedAdapter'
                    'Alternatives'
                    'Code'
                    'Message'
                    'ResolvedAtUtc'
                )

            $actualProperties =
                @(
                    $route.PSObject.Properties.Name
                )

            $actualProperties.Count |
                Should-Be $expectedProperties.Count

            for (
                $index = 0
                $index -lt $expectedProperties.Count
                $index++
            ) {
                (
                    $actualProperties[$index] -ceq
                        $expectedProperties[$index]
                ) |
                    Should-BeTrue
            }

            $route.Resolved |
                Should-BeFalse

            $route.UsedFallback |
                Should-BeFalse

            $route.IsValid() |
                Should-BeFalse
        }
    }

    It 'selects the highest-priority exact adapter and exposes alternatives' {
        InModuleScope Phoenix {
            $package =
                [Package]::new()

            $package.Id = 'Example.Priority'
            $package.Provider = 'NuGet'

            $request =
                [PhoenixPackageAcquisitionRequest]::new()

            $request.SetPackage($package)
            $request.SetContentStoreRoot(
                [IO.Path]::GetTempPath()
            )

            $low =
                [PhoenixPackageAcquisitionAdapter]::new()

            $low.SetIdentity(
                'Low Priority',
                'NuGet'
            )

            $low.Priority = 10

            $high =
                [PhoenixPackageAcquisitionAdapter]::new()

            $high.SetIdentity(
                'High Priority',
                'NuGet'
            )

            $high.Priority = 100

            $route =
                Resolve-PhoenixPackageAcquisitionAdapter `
                    -Request $request `
                    -Adapter @(
                        $low
                        $high
                    )

            $route.Resolved |
                Should-BeTrue

            $route.UsedFallback |
                Should-BeFalse

            $route.SelectedAdapter.Name |
                Should-Be 'High Priority'

            $route.Alternatives.Count |
                Should-Be 1

            $route.Alternatives[0].Name |
                Should-Be 'Low Priority'

            $route.IsValid() |
                Should-BeTrue
        }
    }

    It 'breaks equal-priority ties deterministically by adapter name' {
        InModuleScope Phoenix {
            $package =
                [Package]::new()

            $package.Id = 'Example.Tie'
            $package.Provider = 'Scoop'

            $request =
                [PhoenixPackageAcquisitionRequest]::new()

            $request.SetPackage($package)
            $request.SetContentStoreRoot(
                [IO.Path]::GetTempPath()
            )

            $zulu =
                [PhoenixPackageAcquisitionAdapter]::new()

            $zulu.SetIdentity(
                'Zulu Adapter',
                'Scoop'
            )

            $zulu.Priority = 50

            $alpha =
                [PhoenixPackageAcquisitionAdapter]::new()

            $alpha.SetIdentity(
                'Alpha Adapter',
                'Scoop'
            )

            $alpha.Priority = 50

            $route =
                Resolve-PhoenixPackageAcquisitionAdapter `
                    -Request $request `
                    -Adapter @(
                        $zulu
                        $alpha
                    )

            $route.SelectedAdapter.Name |
                Should-Be 'Alpha Adapter'

            $route.Alternatives[0].Name |
                Should-Be 'Zulu Adapter'
        }
    }

    It 'does not use a fallback adapter unless fallback is explicit' {
        InModuleScope Phoenix {
            $package =
                [Package]::new()

            $package.Id = 'Example.NoFallback'
            $package.Provider = 'UnknownProvider'

            $request =
                [PhoenixPackageAcquisitionRequest]::new()

            $request.SetPackage($package)
            $request.SetContentStoreRoot(
                [IO.Path]::GetTempPath()
            )

            $fallback =
                [PhoenixPackageAcquisitionAdapter]::new()

            $fallback.SetIdentity(
                'User Supplied Adapter',
                '*'
            )

            $fallback.IsFallback = $true

            $blockedRoute =
                Resolve-PhoenixPackageAcquisitionAdapter `
                    -Request $request `
                    -Adapter @($fallback)

            $blockedRoute.Resolved |
                Should-BeFalse

            $blockedRoute.Code |
                Should-Be 'PHX_PACKAGE_ACQUISITION_ROUTE_UNAVAILABLE'

            $allowedRoute =
                Resolve-PhoenixPackageAcquisitionAdapter `
                    -Request $request `
                    -Adapter @($fallback) `
                    -AllowFallback

            $allowedRoute.Resolved |
                Should-BeTrue

            $allowedRoute.UsedFallback |
                Should-BeTrue

            $allowedRoute.SelectedAdapter.Name |
                Should-Be 'User Supplied Adapter'

            $allowedRoute.Code |
                Should-Be 'PHX_PACKAGE_ACQUISITION_FALLBACK_ROUTE_RESOLVED'

            $allowedRoute.IsValid() |
                Should-BeTrue
        }
    }

    It 'ignores disabled and invalid adapters and returns a valid unresolved route' {
        InModuleScope Phoenix {
            $package =
                [Package]::new()

            $package.Id = 'Example.Unresolved'
            $package.Provider = 'NuGet'

            $request =
                [PhoenixPackageAcquisitionRequest]::new()

            $request.SetPackage($package)
            $request.SetContentStoreRoot(
                [IO.Path]::GetTempPath()
            )

            $disabled =
                [PhoenixPackageAcquisitionAdapter]::new()

            $disabled.SetIdentity(
                'Disabled Adapter',
                'NuGet'
            )

            $disabled.Enabled = $false

            $invalid =
                [PhoenixPackageAcquisitionAdapter]::new()

            $route =
                Resolve-PhoenixPackageAcquisitionAdapter `
                    -Request $request `
                    -Adapter @(
                        $disabled
                        $invalid
                    )

            $route.Resolved |
                Should-BeFalse

            $route.SelectedAdapter -eq $null |
                Should-BeTrue

            $route.Alternatives.Count |
                Should-Be 0

            $route.IsValid() |
                Should-BeTrue
        }
    }
}
