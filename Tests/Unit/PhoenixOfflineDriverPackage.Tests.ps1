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

Describe 'Phoenix offline driver package contract' -Tag @(
    'Unit'
    'Driver'
    'OfflineBundle'
    'ContentStore'
    'Contract'
) {
    It 'starts invalid before catalog identity and content are assigned' {
        InModuleScope Phoenix {
            $package =
                [PhoenixOfflineDriverPackage]::new()

            $package.Architecture |
                Should-Be 'Unknown'

            $package.Files.Count |
                Should-Be 0

            $package.IsValid() |
                Should-BeFalse
        }
    }

    It 'represents a complete offline driver package using content-store objects' {
        InModuleScope Phoenix {
            [string]$digest =
                '0123456789abcdef0123456789abcdef' +
                '0123456789abcdef0123456789abcdef'

            $contentObject =
                [PhoenixContentObject]::new(
                    [PhoenixContentAddress]::new(
                        $digest
                    ),
                    4096
                )

            $package =
                [PhoenixOfflineDriverPackage]::new()

            $package.PackageId =
                'driver-package:test-display-1'

            $package.InfName =
                'oem42.inf'

            $package.Provider =
                'Contoso'

            $package.Version =
                '31.0.15.1234'

            $package.DriverDate =
                [datetime]'2026-08-01'

            $package.Class =
                'Display'

            $package.ClassGuid =
                '{4d36e968-e325-11ce-bfc1-08002be10318}'

            $package.Architecture =
                'x64'

            $package.SetMatchIdentifiers(
                @(
                    'pci\ven_1234&dev_abcd'
                    'PCI\VEN_1234&DEV_ABCD'
                ),
                @(
                    'pci\ven_1234'
                )
            )

            $package.AddFile(
                $contentObject
            )

            $package.HardwareIds.Count |
                Should-Be 1

            $package.HardwareIds[0] |
                Should-Be 'PCI\VEN_1234&DEV_ABCD'

            $package.CompatibleIds[0] |
                Should-Be 'PCI\VEN_1234'

            $package.Files.Count |
                Should-Be 1

            $package.Files[0].ObjectId |
                Should-Be $contentObject.ObjectId

            $package.IsValid() |
                Should-BeTrue
        }
    }

    It 'deduplicates identical stored files by content identity' {
        InModuleScope Phoenix {
            [string]$digest =
                'ab' + ('c' * 62)

            $contentObject =
                [PhoenixContentObject]::new(
                    [PhoenixContentAddress]::new(
                        $digest
                    ),
                    2048
                )

            $package =
                [PhoenixOfflineDriverPackage]::new()

            $package.AddFile(
                $contentObject
            )

            $package.AddFile(
                $contentObject
            )

            $package.Files.Count |
                Should-Be 1
        }
    }

    It 'rejects conflicting byte lengths for one content identity' {
        InModuleScope Phoenix {
            [string]$digest =
                'f' * 64

            $firstObject =
                [PhoenixContentObject]::new(
                    [PhoenixContentAddress]::new(
                        $digest
                    ),
                    100
                )

            $secondObject =
                [PhoenixContentObject]::new(
                    [PhoenixContentAddress]::new(
                        $digest
                    ),
                    200
                )

            $package =
                [PhoenixOfflineDriverPackage]::new()

            $package.AddFile(
                $firstObject
            )

            {
                $package.AddFile(
                    $secondObject
                )
            } |
                Should-Throw
        }
    }

    It 'copies content metadata instead of retaining the mutable source object' {
        InModuleScope Phoenix {
            [string]$digest =
                '1' * 64

            $contentObject =
                [PhoenixContentObject]::new(
                    [PhoenixContentAddress]::new(
                        $digest
                    ),
                    512
                )

            $package =
                [PhoenixOfflineDriverPackage]::new()

            $package.AddFile(
                $contentObject
            )

            $contentObject.Length =
                999

            $package.Files[0].Length |
                Should-Be 512
        }
    }

    It 'requires at least one match identifier and one valid stored file' {
        InModuleScope Phoenix {
            [string]$digest =
                '2' * 64

            $contentObject =
                [PhoenixContentObject]::new(
                    [PhoenixContentAddress]::new(
                        $digest
                    ),
                    128
                )

            $package =
                [PhoenixOfflineDriverPackage]::new()

            $package.PackageId =
                'driver-package:test'

            $package.InfName =
                'driver.inf'

            $package.Provider =
                'Contoso'

            $package.Version =
                '1.0.0.0'

            $package.AddFile(
                $contentObject
            )

            $package.IsValid() |
                Should-BeFalse

            $package.SetMatchIdentifiers(
                @(
                    'PCI\VEN_1234&DEV_ABCD'
                ),
                @()
            )

            $package.IsValid() |
                Should-BeTrue
        }
    }
}
