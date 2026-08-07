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

Describe 'Phoenix package acquisition result contract' -Tag @(
    'Unit'
    'OfflineBundle'
    'ApplicationAcquisition'
    'Contract'
) {
    It 'publishes the exact acquisition result properties' {
        InModuleScope Phoenix {
            $result =
                [PhoenixPackageAcquisitionResult]::new()

            $expectedProperties =
                @(
                    'AcquisitionId'
                    'Package'
                    'Status'
                    'Success'
                    'Code'
                    'Message'
                    'Provider'
                    'Source'
                    'SourceUri'
                    'FileName'
                    'MediaType'
                    'ContentObject'
                    'Metadata'
                    'Warnings'
                    'Errors'
                    'StartedAtUtc'
                    'CompletedAtUtc'
                    'Duration'
                )

            $actualProperties =
                @(
                    $result.PSObject.Properties.Name
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

    It 'starts with a unique incomplete invalid identity' {
        InModuleScope Phoenix {
            $first =
                [PhoenixPackageAcquisitionResult]::new()

            $second =
                [PhoenixPackageAcquisitionResult]::new()

            (
                $first.AcquisitionId -cne
                    $second.AcquisitionId
            ) |
                Should-BeTrue

            $first.Status |
                Should-Be (
                    [PhoenixPackageAcquisitionStatus]::Unknown
                )

            $first.Success |
                Should-BeFalse

            $first.Code |
                Should-Be 'PHX_PACKAGE_ACQUISITION_NOT_STARTED'

            $first.Metadata.Count |
                Should-Be 0

            $first.Warnings.Count |
                Should-Be 0

            $first.Errors.Count |
                Should-Be 0

            $first.IsComplete() |
                Should-BeFalse

            $first.IsSuccessful() |
                Should-BeFalse

            $first.IsValid() |
                Should-BeFalse
        }
    }

    It 'binds an identifiable package and copies provider metadata' {
        InModuleScope Phoenix {
            $package =
                [Package]::new()

            $package.Id = 'Example.Package'
            $package.Name = 'Example Package'
            $package.Provider = 'ExampleProvider'
            $package.Source = 'ExampleSource'

            $result =
                [PhoenixPackageAcquisitionResult]::new()

            $result.SetPackage($package)

            [object]::ReferenceEquals(
                $result.Package,
                $package
            ) |
                Should-BeTrue

            $result.Provider |
                Should-Be 'ExampleProvider'

            $result.Source |
                Should-Be 'ExampleSource'
        }
    }

    It 'rejects a null or unidentified package record' {
        InModuleScope Phoenix {
            $result =
                [PhoenixPackageAcquisitionResult]::new()

            {
                $result.SetPackage($null)
            } |
                Should-Throw

            $package =
                [Package]::new()

            {
                $result.SetPackage($package)
            } |
                Should-Throw
        }
    }

    It 'copies a valid content object and rejects invalid objects' {
        InModuleScope Phoenix {
            $address =
                [PhoenixContentAddress]::new(
                    ('a' * 64)
                )

            $contentObject =
                [PhoenixContentObject]::new(
                    $address,
                    42
                )

            $result =
                [PhoenixPackageAcquisitionResult]::new()

            $result.SetContentObject($contentObject)

            [object]::ReferenceEquals(
                $result.ContentObject,
                $contentObject
            ) |
                Should-BeFalse

            $result.ContentObject.ObjectId |
                Should-Be $contentObject.ObjectId

            $result.ContentObject.Length |
                Should-Be 42

            {
                $result.SetContentObject($null)
            } |
                Should-Throw

            {
                $result.SetContentObject(
                    [PhoenixContentObject]::new()
                )
            } |
                Should-Throw
        }
    }

    It 'completes an acquired artifact successfully' {
        InModuleScope Phoenix {
            $package =
                [Package]::new()

            $package.Id = 'Example.Acquired'
            $package.Provider = 'ExampleProvider'

            $address =
                [PhoenixContentAddress]::new(
                    ('b' * 64)
                )

            $contentObject =
                [PhoenixContentObject]::new(
                    $address,
                    64
                )

            $result =
                [PhoenixPackageAcquisitionResult]::new()

            $result.SetPackage($package)
            $result.SetContentObject($contentObject)
            $result.Complete(
                [PhoenixPackageAcquisitionStatus]::Acquired,
                'PHX_PACKAGE_ACQUIRED',
                'The package artifact was acquired.'
            )

            $result.Status |
                Should-Be (
                    [PhoenixPackageAcquisitionStatus]::Acquired
                )

            $result.Success |
                Should-BeTrue

            $result.IsComplete() |
                Should-BeTrue

            $result.IsSuccessful() |
                Should-BeTrue

            $result.IsValid() |
                Should-BeTrue
        }
    }

    It 'completes a reused artifact successfully' {
        InModuleScope Phoenix {
            $package =
                [Package]::new()

            $package.Name = 'Reused Package'
            $package.Provider = 'ExampleProvider'

            $address =
                [PhoenixContentAddress]::new(
                    ('c' * 64)
                )

            $contentObject =
                [PhoenixContentObject]::new(
                    $address,
                    128
                )

            $result =
                [PhoenixPackageAcquisitionResult]::new()

            $result.SetPackage($package)
            $result.SetContentObject($contentObject)
            $result.Complete(
                [PhoenixPackageAcquisitionStatus]::Reused,
                'PHX_PACKAGE_REUSED',
                'The existing content object was reused.'
            )

            $result.Status |
                Should-Be (
                    [PhoenixPackageAcquisitionStatus]::Reused
                )

            $result.IsSuccessful() |
                Should-BeTrue

            $result.IsValid() |
                Should-BeTrue
        }
    }

    It 'enforces artifact and non-artifact completion boundaries' {
        InModuleScope Phoenix {
            $package =
                [Package]::new()

            $package.Id = 'Example.Boundary'
            $package.Provider = 'ExampleProvider'

            $withoutObject =
                [PhoenixPackageAcquisitionResult]::new()

            $withoutObject.SetPackage($package)

            {
                $withoutObject.Complete(
                    [PhoenixPackageAcquisitionStatus]::Acquired,
                    'PHX_PACKAGE_ACQUIRED',
                    'The package artifact was acquired.'
                )
            } |
                Should-Throw

            $address =
                [PhoenixContentAddress]::new(
                    ('d' * 64)
                )

            $withObject =
                [PhoenixPackageAcquisitionResult]::new()

            $withObject.SetPackage($package)
            $withObject.SetContentObject(
                [PhoenixContentObject]::new(
                    $address,
                    256
                )
            )

            {
                $withObject.Complete(
                    [PhoenixPackageAcquisitionStatus]::Unsupported,
                    'PHX_PACKAGE_UNSUPPORTED',
                    'The package provider is unsupported.'
                )
            } |
                Should-Throw
        }
    }

    It 'represents every terminal no-artifact outcome consistently' {
        InModuleScope Phoenix {
            $statuses =
                @(
                    [PhoenixPackageAcquisitionStatus]::UserSuppliedRequired
                    [PhoenixPackageAcquisitionStatus]::Unavailable
                    [PhoenixPackageAcquisitionStatus]::NotRedistributable
                    [PhoenixPackageAcquisitionStatus]::InteractiveOnly
                    [PhoenixPackageAcquisitionStatus]::SourceRestricted
                    [PhoenixPackageAcquisitionStatus]::Unsupported
                    [PhoenixPackageAcquisitionStatus]::Failed
                    [PhoenixPackageAcquisitionStatus]::Cancelled
                )

            foreach ($status in $statuses) {
                $package =
                    [Package]::new()

                $package.Id =
                    "Example.$status"

                $package.Provider =
                    'ExampleProvider'

                $result =
                    [PhoenixPackageAcquisitionResult]::new()

                $result.SetPackage($package)
                $result.Complete(
                    $status,
                    "PHX_PACKAGE_$status".ToUpperInvariant(),
                    "Package acquisition completed as $status."
                )

                $result.Success |
                    Should-BeFalse

                $result.IsComplete() |
                    Should-BeTrue

                $result.IsSuccessful() |
                    Should-BeFalse

                $result.IsValid() |
                    Should-BeTrue

                if (
                    $status -eq
                        [PhoenixPackageAcquisitionStatus]::Failed
                ) {
                    $result.Errors.Count |
                        Should-Be 1
                }
            }
        }
    }

    It 'detects tampered identity success and completion fields' {
        InModuleScope Phoenix {
            $package =
                [Package]::new()

            $package.Id = 'Example.Tamper'
            $package.Provider = 'ExampleProvider'

            $address =
                [PhoenixContentAddress]::new(
                    ('e' * 64)
                )

            $result =
                [PhoenixPackageAcquisitionResult]::new()

            $result.SetPackage($package)
            $result.SetContentObject(
                [PhoenixContentObject]::new(
                    $address,
                    512
                )
            )

            $result.Complete(
                [PhoenixPackageAcquisitionStatus]::Acquired,
                'PHX_PACKAGE_ACQUIRED',
                'The package artifact was acquired.'
            )

            $result.AcquisitionId = 'not-a-guid'

            $result.IsValid() |
                Should-BeFalse

            $result.AcquisitionId =
                [guid]::NewGuid().ToString('D')

            $result.Success = $false

            $result.IsValid() |
                Should-BeFalse

            $result.Success = $true
            $result.Code = ''

            $result.IsValid() |
                Should-BeFalse

            $result.Code = 'PHX_PACKAGE_ACQUIRED'
            $result.Duration = [timespan]::Zero

            $result.IsValid() |
                Should-BeFalse
        }
    }
}
