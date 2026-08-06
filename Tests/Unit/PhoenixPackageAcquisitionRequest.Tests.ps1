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

Describe 'Phoenix package acquisition request contract' -Tag @(
    'Unit'
    'OfflineBundle'
    'ApplicationAcquisition'
    'Contract'
) {
    It 'publishes the exact acquisition request properties' {
        InModuleScope Phoenix {
            $request =
                [PhoenixPackageAcquisitionRequest]::new()

            $expectedProperties =
                @(
                    'RequestId'
                    'Package'
                    'ContentStoreRoot'
                    'WorkingDirectory'
                    'AllowInteractive'
                    'ForceRefresh'
                    'PreserveWorkingDirectory'
                    'Metadata'
                    'CreatedAtUtc'
                )

            $actualProperties =
                @(
                    $request.PSObject.Properties.Name
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

    It 'starts with a unique incomplete request identity' {
        InModuleScope Phoenix {
            $first =
                [PhoenixPackageAcquisitionRequest]::new()

            $second =
                [PhoenixPackageAcquisitionRequest]::new()

            (
                $first.RequestId -cne
                    $second.RequestId
            ) |
                Should-BeTrue

            $first.ContentStoreRoot |
                Should-Be ''

            $first.WorkingDirectory |
                Should-Be ''

            $first.AllowInteractive |
                Should-BeFalse

            $first.ForceRefresh |
                Should-BeFalse

            $first.PreserveWorkingDirectory |
                Should-BeFalse

            $first.Metadata.Count |
                Should-Be 0

            $first.CreatedAtUtc.Kind |
                Should-Be ([DateTimeKind]::Utc)

            $first.IsValid() |
                Should-BeFalse
        }
    }

    It 'binds an identifiable package with a provider' {
        InModuleScope Phoenix {
            $package =
                [Package]::new()

            $package.Id = 'Example.Package'
            $package.Name = 'Example Package'
            $package.Provider = 'ExampleProvider'

            $request =
                [PhoenixPackageAcquisitionRequest]::new()

            $request.SetPackage($package)

            [object]::ReferenceEquals(
                $request.Package,
                $package
            ) |
                Should-BeTrue
        }
    }

    It 'rejects null unidentified and providerless packages' {
        InModuleScope Phoenix {
            $request =
                [PhoenixPackageAcquisitionRequest]::new()

            {
                $request.SetPackage($null)
            } |
                Should-Throw

            $unidentified =
                [Package]::new()

            $unidentified.Provider =
                'ExampleProvider'

            {
                $request.SetPackage($unidentified)
            } |
                Should-Throw

            $providerless =
                [Package]::new()

            $providerless.Id =
                'Example.Providerless'

            {
                $request.SetPackage($providerless)
            } |
                Should-Throw
        }
    }

    It 'normalizes an absolute content-store root without creating it' {
        InModuleScope Phoenix {
            $storeRoot =
                Join-Path `
                    ([IO.Path]::GetTempPath()) `
                    (
                        'PhoenixAcquisitionStore-{0}' -f
                        [guid]::NewGuid().ToString('N')
                    )

            Test-Path `
                -LiteralPath $storeRoot |
                Should-BeFalse

            $request =
                [PhoenixPackageAcquisitionRequest]::new()

            $request.SetContentStoreRoot(
                $storeRoot +
                    [IO.Path]::DirectorySeparatorChar
            )

            $request.ContentStoreRoot |
                Should-Be (
                    [IO.Path]::GetFullPath($storeRoot)
                )

            Test-Path `
                -LiteralPath $storeRoot |
                Should-BeFalse
        }
    }

    It 'sets and clears an optional normalized working directory' {
        InModuleScope Phoenix {
            $workingDirectory =
                Join-Path `
                    ([IO.Path]::GetTempPath()) `
                    (
                        'PhoenixAcquisitionWork-{0}' -f
                        [guid]::NewGuid().ToString('N')
                    )

            $request =
                [PhoenixPackageAcquisitionRequest]::new()

            $request.SetWorkingDirectory(
                $workingDirectory +
                    [IO.Path]::DirectorySeparatorChar
            )

            $request.WorkingDirectory |
                Should-Be (
                    [IO.Path]::GetFullPath(
                        $workingDirectory
                    )
                )

            Test-Path `
                -LiteralPath $workingDirectory |
                Should-BeFalse

            $request.SetWorkingDirectory('')

            $request.WorkingDirectory |
                Should-Be ''
        }
    }

    It 'rejects relative content-store and working paths' {
        InModuleScope Phoenix {
            $request =
                [PhoenixPackageAcquisitionRequest]::new()

            {
                $request.SetContentStoreRoot(
                    '.\relative-store'
                )
            } |
                Should-Throw

            {
                $request.SetWorkingDirectory(
                    '.\relative-work'
                )
            } |
                Should-Throw
        }
    }

    It 'validates policies metadata and canonical request state' {
        InModuleScope Phoenix {
            $package =
                [Package]::new()

            $package.Id = 'Example.Valid'
            $package.Provider = 'ExampleProvider'

            $request =
                [PhoenixPackageAcquisitionRequest]::new()

            $request.SetPackage($package)

            [string]$storeRoot =
                Join-Path `
                    ([IO.Path]::GetTempPath()) `
                    'PhoenixAcquisitionStore'

            [string]$workingDirectory =
                Join-Path `
                    ([IO.Path]::GetTempPath()) `
                    'PhoenixAcquisitionWork'

            $request.SetContentStoreRoot(
                $storeRoot
            )

            $request.SetWorkingDirectory(
                $workingDirectory
            )

            $request.AllowInteractive = $true
            $request.ForceRefresh = $true
            $request.PreserveWorkingDirectory = $true
            $request.Metadata['Channel'] = 'Stable'

            $request.IsValid() |
                Should-BeTrue

            $request.RequestId = 'not-a-guid'

            $request.IsValid() |
                Should-BeFalse

            $request.RequestId =
                [guid]::NewGuid().ToString('D')

            $request.ContentStoreRoot =
                '.\tampered-store'

            $request.IsValid() |
                Should-BeFalse

            $request.SetContentStoreRoot(
                $storeRoot
            )

            $request.Metadata = $null

            $request.IsValid() |
                Should-BeFalse

            $request.Metadata = @{}
            $request.CreatedAtUtc =
                [datetime]::Now

            $request.IsValid() |
                Should-BeFalse
        }
    }
}
