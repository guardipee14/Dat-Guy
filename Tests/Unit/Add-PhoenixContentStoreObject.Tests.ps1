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

Describe 'Add-PhoenixContentStoreObject' -Tag @(
    'Unit'
    'OfflineBundle'
    'ContentStore'
    'Mutation'
) {
    It 'returns the prospective object without creating files under WhatIf' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            [string]$sourcePath =
                Join-Path `
                    $TestRoot `
                    'preview-source.bin'

            [string]$storeRoot =
                Join-Path `
                    $TestRoot `
                    'preview-store'

            [byte[]]$sourceBytes =
                [Text.Encoding]::UTF8.GetBytes(
                    'Phoenix content-store preview'
                )

            [IO.File]::WriteAllBytes(
                $sourcePath,
                $sourceBytes
            )

            $expectedObject =
                Get-PhoenixContentObjectFromFile `
                    -LiteralPath $sourcePath

            $previewObject =
                Add-PhoenixContentStoreObject `
                    -StoreRoot $storeRoot `
                    -LiteralPath $sourcePath `
                    -WhatIf

            $previewObject.IsValid() |
                Should-BeTrue

            (
                $previewObject.ObjectId -ceq
                    $expectedObject.ObjectId
            ) |
                Should-BeTrue

            $previewObject.Length |
                Should-Be $sourceBytes.LongLength

            Test-Path `
                -LiteralPath $storeRoot |
                Should-BeFalse
        }
    }

    It 'publishes content at its canonical address and verifies it' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            [string]$sourcePath =
                Join-Path `
                    $TestRoot `
                    'publish-source.bin'

            [string]$storeRoot =
                Join-Path `
                    $TestRoot `
                    'publish-store'

            [byte[]]$sourceBytes =
                [Text.Encoding]::UTF8.GetBytes(
                    'Published Phoenix object'
                )

            [IO.File]::WriteAllBytes(
                $sourcePath,
                $sourceBytes
            )

            $contentObject =
                Add-PhoenixContentStoreObject `
                    -StoreRoot $storeRoot `
                    -LiteralPath $sourcePath `
                    -Confirm:$false

            $address =
                [PhoenixContentAddress]::new(
                    $contentObject.Digest
                )

            [string]$objectPath =
                Resolve-PhoenixContentStoreObjectPath `
                    -StoreRoot $storeRoot `
                    -Address $address

            Test-Path `
                -LiteralPath $objectPath `
                -PathType Leaf |
                Should-BeTrue

            Test-PhoenixContentStoreObject `
                -StoreRoot $storeRoot `
                -ContentObject $contentObject |
                Should-BeTrue

            [byte[]]$storedBytes =
                [IO.File]::ReadAllBytes(
                    $objectPath
                )

            (
                [Convert]::ToHexString($storedBytes) -ceq
                    [Convert]::ToHexString($sourceBytes)
            ) |
                Should-BeTrue

            $storedFiles =
                @(
                    Get-ChildItem `
                        -LiteralPath $storeRoot `
                        -File `
                        -Recurse `
                        -Force
                )

            $storedFiles.Count |
                Should-Be 1

            @(
                $storedFiles |
                    Where-Object {
                        $_.Name.EndsWith(
                            '.tmp',
                            [StringComparison]::OrdinalIgnoreCase
                        )
                    }
            ).Count |
                Should-Be 0
        }
    }

    It 'deduplicates matching content without rewriting the stored object' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            [string]$sourcePath =
                Join-Path `
                    $TestRoot `
                    'duplicate-source.bin'

            [string]$storeRoot =
                Join-Path `
                    $TestRoot `
                    'duplicate-store'

            [IO.File]::WriteAllText(
                $sourcePath,
                'Deduplicated Phoenix object'
            )

            $firstObject =
                Add-PhoenixContentStoreObject `
                    -StoreRoot $storeRoot `
                    -LiteralPath $sourcePath `
                    -Confirm:$false

            $address =
                [PhoenixContentAddress]::new(
                    $firstObject.Digest
                )

            [string]$objectPath =
                Resolve-PhoenixContentStoreObjectPath `
                    -StoreRoot $storeRoot `
                    -Address $address

            [IO.FileInfo]$storedFile =
                Get-Item `
                    -LiteralPath $objectPath

            $storedFile.LastWriteTimeUtc =
                [datetime]::new(
                    2020,
                    1,
                    2,
                    3,
                    4,
                    6,
                    [DateTimeKind]::Utc
                )

            [datetime]$baselineWriteTime =
                (
                    Get-Item `
                        -LiteralPath $objectPath
                ).LastWriteTimeUtc

            $duplicateObject =
                Add-PhoenixContentStoreObject `
                    -StoreRoot $storeRoot `
                    -LiteralPath $sourcePath `
                    -Confirm:$false

            [datetime]$finalWriteTime =
                (
                    Get-Item `
                        -LiteralPath $objectPath
                ).LastWriteTimeUtc

            (
                $duplicateObject.ObjectId -ceq
                    $firstObject.ObjectId
            ) |
                Should-BeTrue

            $finalWriteTime |
                Should-Be $baselineWriteTime

            @(
                Get-ChildItem `
                    -LiteralPath $storeRoot `
                    -File `
                    -Recurse `
                    -Force
            ).Count |
                Should-Be 1
        }
    }

    It 'rejects corrupt existing content without overwriting it' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            [string]$sourcePath =
                Join-Path `
                    $TestRoot `
                    'corruption-source.bin'

            [string]$storeRoot =
                Join-Path `
                    $TestRoot `
                    'corruption-store'

            [byte[]]$sourceBytes =
                [Text.Encoding]::UTF8.GetBytes(
                    'AAAA'
                )

            [byte[]]$corruptBytes =
                [Text.Encoding]::UTF8.GetBytes(
                    'BBBB'
                )

            [IO.File]::WriteAllBytes(
                $sourcePath,
                $sourceBytes
            )

            $contentObject =
                Add-PhoenixContentStoreObject `
                    -StoreRoot $storeRoot `
                    -LiteralPath $sourcePath `
                    -Confirm:$false

            $address =
                [PhoenixContentAddress]::new(
                    $contentObject.Digest
                )

            [string]$objectPath =
                Resolve-PhoenixContentStoreObjectPath `
                    -StoreRoot $storeRoot `
                    -Address $address

            [IO.File]::WriteAllBytes(
                $objectPath,
                $corruptBytes
            )

            {
                Add-PhoenixContentStoreObject `
                    -StoreRoot $storeRoot `
                    -LiteralPath $sourcePath `
                    -Confirm:$false
            } |
                Should-Throw

            [byte[]]$remainingBytes =
                [IO.File]::ReadAllBytes(
                    $objectPath
                )

            (
                [Convert]::ToHexString($remainingBytes) -ceq
                    [Convert]::ToHexString($corruptBytes)
            ) |
                Should-BeTrue

            @(
                Get-ChildItem `
                    -LiteralPath $storeRoot `
                    -File `
                    -Recurse `
                    -Force |
                    Where-Object {
                        $_.Name.EndsWith(
                            '.tmp',
                            [StringComparison]::OrdinalIgnoreCase
                        )
                    }
            ).Count |
                Should-Be 0
        }
    }

    It 'accepts FileInfo objects from the pipeline' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            [string]$sourcePath =
                Join-Path `
                    $TestRoot `
                    'pipeline-source.bin'

            [string]$storeRoot =
                Join-Path `
                    $TestRoot `
                    'pipeline-store'

            [IO.File]::WriteAllText(
                $sourcePath,
                'Pipeline Phoenix object'
            )

            $contentObject =
                Get-Item `
                    -LiteralPath $sourcePath |
                    Add-PhoenixContentStoreObject `
                        -StoreRoot $storeRoot `
                        -Confirm:$false

            $contentObject.IsValid() |
                Should-BeTrue

            Test-PhoenixContentStoreObject `
                -StoreRoot $storeRoot `
                -ContentObject $contentObject |
                Should-BeTrue
        }
    }

    It 'rejects a store root that is an existing file' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            [string]$sourcePath =
                Join-Path `
                    $TestRoot `
                    'invalid-root-source.bin'

            [string]$storeRoot =
                Join-Path `
                    $TestRoot `
                    'store-is-a-file'

            [IO.File]::WriteAllText(
                $sourcePath,
                'Phoenix invalid root source'
            )

            [IO.File]::WriteAllText(
                $storeRoot,
                'preserve this root file'
            )

            {
                Add-PhoenixContentStoreObject `
                    -StoreRoot $storeRoot `
                    -LiteralPath $sourcePath `
                    -Confirm:$false
            } |
                Should-Throw

            Test-Path `
                -LiteralPath $storeRoot `
                -PathType Leaf |
                Should-BeTrue

            [IO.File]::ReadAllText(
                $storeRoot
            ) |
                Should-Be 'preserve this root file'
        }
    }
}