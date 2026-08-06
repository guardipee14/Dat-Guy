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

Describe 'Test-PhoenixContentStoreObject' -Tag @(
    'Unit'
    'OfflineBundle'
    'ContentStore'
    'Verification'
) {
    It 'returns false when the expected object is absent' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            [string]$sourcePath =
                Join-Path `
                    $TestRoot `
                    'missing-source.bin'

            [byte[]]$content =
                [Text.Encoding]::UTF8.GetBytes(
                    'missing content object'
                )

            [IO.File]::WriteAllBytes(
                $sourcePath,
                $content
            )

            [string]$digest =
                (
                    Get-FileHash `
                        -LiteralPath $sourcePath `
                        -Algorithm SHA256
                ).Hash.ToLowerInvariant()

            $contentObject =
                [PhoenixContentObject]::new(
                    [PhoenixContentAddress]::new(
                        $digest
                    ),
                    $content.LongLength
                )

            [string]$storeRoot =
                Join-Path `
                    $TestRoot `
                    'missing-store'

            Test-PhoenixContentStoreObject `
                -StoreRoot $storeRoot `
                -ContentObject $contentObject |
                Should-BeFalse
        }
    }

    It 'accepts an object with matching length and SHA-256 digest' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            [string]$sourcePath =
                Join-Path `
                    $TestRoot `
                    'valid-source.bin'

            [byte[]]$content =
                [Text.Encoding]::UTF8.GetBytes(
                    'verified Phoenix content'
                )

            [IO.File]::WriteAllBytes(
                $sourcePath,
                $content
            )

            [string]$digest =
                (
                    Get-FileHash `
                        -LiteralPath $sourcePath `
                        -Algorithm SHA256
                ).Hash.ToLowerInvariant()

            $address =
                [PhoenixContentAddress]::new(
                    $digest
                )

            $contentObject =
                [PhoenixContentObject]::new(
                    $address,
                    $content.LongLength
                )

            [string]$storeRoot =
                Join-Path `
                    $TestRoot `
                    'valid-store'

            [string]$objectPath =
                Resolve-PhoenixContentStoreObjectPath `
                    -StoreRoot $storeRoot `
                    -Address $address

            [string]$objectParent =
                Split-Path `
                    -Path $objectPath `
                    -Parent

            $null =
                New-Item `
                    -ItemType Directory `
                    -Path $objectParent `
                    -Force

            [IO.File]::WriteAllBytes(
                $objectPath,
                $content
            )

            Test-PhoenixContentStoreObject `
                -StoreRoot $storeRoot `
                -ContentObject $contentObject |
                Should-BeTrue
        }
    }

    It 'rejects an object with the wrong byte length' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            [byte[]]$content =
                [Text.Encoding]::UTF8.GetBytes(
                    'length mismatch'
                )

            [string]$sourcePath =
                Join-Path `
                    $TestRoot `
                    'length-source.bin'

            [IO.File]::WriteAllBytes(
                $sourcePath,
                $content
            )

            [string]$digest =
                (
                    Get-FileHash `
                        -LiteralPath $sourcePath `
                        -Algorithm SHA256
                ).Hash.ToLowerInvariant()

            $address =
                [PhoenixContentAddress]::new(
                    $digest
                )

            $contentObject =
                [PhoenixContentObject]::new(
                    $address,
                    $content.LongLength + 1
                )

            [string]$storeRoot =
                Join-Path `
                    $TestRoot `
                    'length-store'

            [string]$objectPath =
                Resolve-PhoenixContentStoreObjectPath `
                    -StoreRoot $storeRoot `
                    -Address $address

            $null =
                New-Item `
                    -ItemType Directory `
                    -Path (
                        Split-Path `
                            -Path $objectPath `
                            -Parent
                    ) `
                    -Force

            [IO.File]::WriteAllBytes(
                $objectPath,
                $content
            )

            Test-PhoenixContentStoreObject `
                -StoreRoot $storeRoot `
                -ContentObject $contentObject |
                Should-BeFalse
        }
    }

    It 'rejects same-length content with a different digest' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            [byte[]]$expectedContent =
                [Text.Encoding]::UTF8.GetBytes(
                    'AAAA'
                )

            [byte[]]$storedContent =
                [Text.Encoding]::UTF8.GetBytes(
                    'BBBB'
                )

            [string]$sourcePath =
                Join-Path `
                    $TestRoot `
                    'digest-source.bin'

            [IO.File]::WriteAllBytes(
                $sourcePath,
                $expectedContent
            )

            [string]$digest =
                (
                    Get-FileHash `
                        -LiteralPath $sourcePath `
                        -Algorithm SHA256
                ).Hash.ToLowerInvariant()

            $address =
                [PhoenixContentAddress]::new(
                    $digest
                )

            $contentObject =
                [PhoenixContentObject]::new(
                    $address,
                    $expectedContent.LongLength
                )

            [string]$storeRoot =
                Join-Path `
                    $TestRoot `
                    'digest-store'

            [string]$objectPath =
                Resolve-PhoenixContentStoreObjectPath `
                    -StoreRoot $storeRoot `
                    -Address $address

            $null =
                New-Item `
                    -ItemType Directory `
                    -Path (
                        Split-Path `
                            -Path $objectPath `
                            -Parent
                    ) `
                    -Force

            [IO.File]::WriteAllBytes(
                $objectPath,
                $storedContent
            )

            Test-PhoenixContentStoreObject `
                -StoreRoot $storeRoot `
                -ContentObject $contentObject |
                Should-BeFalse
        }
    }

    It 'rejects null and invalid content object contracts' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            {
                Test-PhoenixContentStoreObject `
                    -StoreRoot $TestRoot `
                    -ContentObject $null
            } |
                Should-Throw

            $invalidObject =
                [PhoenixContentObject]::new()

            {
                Test-PhoenixContentStoreObject `
                    -StoreRoot $TestRoot `
                    -ContentObject $invalidObject
            } |
                Should-Throw
        }
    }
}