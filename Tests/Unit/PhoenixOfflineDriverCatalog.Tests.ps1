BeforeAll {
    $projectRoot =
        (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

    Import-Module (Join-Path $projectRoot 'Phoenix.psd1') -Force 6>$null
}

AfterAll {
    Remove-Module Phoenix -Force -ErrorAction SilentlyContinue
}

Describe 'Phoenix offline driver catalog and matching' -Tag @(
    'Unit'
    'Driver'
    'OfflineBundle'
) {
    It 'creates a deterministic valid package from signed-driver metadata' {
        InModuleScope Phoenix {
            $content = [PhoenixContentObject]::new(
                [PhoenixContentAddress]::new(('a' * 64)),
                1024
            )

            $record = [pscustomobject]@{
                InfName = 'oem12.inf'
                DriverProviderName = 'Contoso'
                DriverVersion = '3.2.1.0'
                DriverDate = '2026-08-01'
                DeviceClass = 'Net'
                ClassGuid = '{4d36e972-e325-11ce-bfc1-08002be10318}'
                HardwareID = @(' pci\ven_1234&dev_abcd ', 'PCI\VEN_1234&DEV_ABCD')
                CompatibleID = @('pci\ven_1234')
                DeviceName = 'Contoso network adapter'
                IsSigned = $true
            }

            $first = ConvertTo-PhoenixOfflineDriverPackage -InputObject $record -File $content -Architecture x64
            $second = ConvertTo-PhoenixOfflineDriverPackage -InputObject $record -File $content -Architecture x64

            $first.IsValid() | Should-BeTrue
            $first.PackageId | Should-Be $second.PackageId
            $first.PackageId |
                Should-MatchString '^driver-package:sha256:[0-9a-f]{64}$'
            $first.HardwareIds.Count | Should-Be 1
            $first.Metadata['IsSigned'] | Should-BeTrue
        }
    }

    It 'ranks exact hardware matches above compatible matches' {
        InModuleScope Phoenix {
            function New-TestDriverPackage {
                param([string]$Digest, [string[]]$HardwareId, [string[]]$CompatibleId)

                $content = [PhoenixContentObject]::new(
                    [PhoenixContentAddress]::new($Digest),
                    10
                )

                $record = [pscustomobject]@{
                    InfName = ('oem{0}.inf' -f $Digest.Substring(0, 2))
                    DriverProviderName = 'Contoso'
                    DriverVersion = '1.0.0.0'
                    HardwareID = $HardwareId
                    CompatibleID = $CompatibleId
                }

                ConvertTo-PhoenixOfflineDriverPackage -InputObject $record -File $content
            }

            $exact = New-TestDriverPackage -Digest ('b' * 64) -HardwareId @('PCI\VEN_1234&DEV_ABCD') -CompatibleId @()
            $compatible = New-TestDriverPackage -Digest ('c' * 64) -HardwareId @('PCI\VEN_9999&DEV_0001') -CompatibleId @('PCI\VEN_1234')

            $target = [PhoenixDriverHardwareIdentity]::new()
            $target.SetHardwareIds(@('PCI\VEN_1234&DEV_ABCD'))
            $target.SetCompatibleIds(@('PCI\VEN_1234'))

            $matches = @(Find-PhoenixOfflineDriverMatch -Package @($compatible, $exact) -TargetIdentity $target)

            $matches.Count | Should-Be 2
            $matches[0].PackageId | Should-Be $exact.PackageId
            $matches[0].MatchType | Should-Be 'HardwareId'
            $matches[1].MatchType | Should-Be 'CompatibleId'
        }
    }

    It 'rejects an invalid target identity' {
        InModuleScope Phoenix {
            $target = [PhoenixDriverHardwareIdentity]::new()

            {
                Find-PhoenixOfflineDriverMatch -Package @([PhoenixOfflineDriverPackage]::new()) -TargetIdentity $target
            } | Should-Throw
        }
    }

    It 'does not create export directories under WhatIf' {
        InModuleScope Phoenix -Parameters @{ TestRoot = $TestDrive } {
            param([string]$TestRoot)

            Mock Get-Command {
                [pscustomobject]@{ Source = 'C:\Windows\System32\pnputil.exe' }
            } -ParameterFilter { $Name -eq 'pnputil.exe' }

            $record = [pscustomobject]@{
                InfName = 'oem42.inf'
                DriverProviderName = 'Contoso'
                DriverVersion = '1.0.0.0'
                HardwareID = @('PCI\VEN_1234&DEV_ABCD')
            }

            $destination = Join-Path $TestRoot 'drivers'

            $result = @(Export-PhoenixOfflineDriverPackage -DestinationPath $destination -ContentStoreRoot (Join-Path $TestRoot 'store') -Driver @($record) -WhatIf)

            $result.Count | Should-Be 0
            Test-Path -LiteralPath $destination | Should-BeFalse
        }
    }
}
