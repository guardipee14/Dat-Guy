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

Describe 'Phoenix driver hardware identity contract' -Tag @(
    'Unit'
    'Driver'
    'OfflineBundle'
    'Contract'
) {
    It 'starts invalid until a hardware or compatible identifier is assigned' {
        InModuleScope Phoenix {
            $identity =
                [PhoenixDriverHardwareIdentity]::new()

            $identity.HardwareIds.Count |
                Should-Be 0

            $identity.CompatibleIds.Count |
                Should-Be 0

            $identity.IsValid() |
                Should-BeFalse
        }
    }

    It 'normalizes and deduplicates hardware and compatible identifiers' {
        InModuleScope Phoenix {
            $identity =
                [PhoenixDriverHardwareIdentity]::new()

            $identity.SetDeviceInstanceId(
                ' pci\ven_1234&dev_abcd\1 '
            )

            $identity.SetHardwareIds(
                @(
                    ' pci\ven_1234&dev_abcd '
                    'PCI\VEN_1234&DEV_ABCD'
                    ''
                )
            )

            $identity.SetCompatibleIds(
                @(
                    'pci\ven_1234'
                    ' PCI\VEN_1234 '
                )
            )

            $identity.DeviceInstanceId |
                Should-Be 'PCI\VEN_1234&DEV_ABCD\1'

            $identity.HardwareIds.Count |
                Should-Be 1

            $identity.HardwareIds[0] |
                Should-Be 'PCI\VEN_1234&DEV_ABCD'

            $identity.CompatibleIds.Count |
                Should-Be 1

            $identity.CompatibleIds[0] |
                Should-Be 'PCI\VEN_1234'

            $identity.IsValid() |
                Should-BeTrue
        }
    }

    It 'accepts a compatible identifier when no hardware identifier is available' {
        InModuleScope Phoenix {
            $identity =
                [PhoenixDriverHardwareIdentity]::new()

            $identity.SetCompatibleIds(
                @(
                    'usb\class_03'
                )
            )

            $identity.IsValid() |
                Should-BeTrue
        }
    }

    It 'rejects an invalid class GUID' {
        InModuleScope Phoenix {
            $identity =
                [PhoenixDriverHardwareIdentity]::new()

            $identity.SetHardwareIds(
                @(
                    'PCI\VEN_1234&DEV_ABCD'
                )
            )

            $identity.ClassGuid =
                'not-a-guid'

            $identity.IsValid() |
                Should-BeFalse
        }
    }

    It 'detects direct unnormalized identifier mutation' {
        InModuleScope Phoenix {
            $identity =
                [PhoenixDriverHardwareIdentity]::new()

            $identity.HardwareIds =
                @(
                    ' pci\ven_1234&dev_abcd '
                )

            $identity.IsValid() |
                Should-BeFalse
        }
    }
}
