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

Describe 'Get-PhoenixContentObjectFromFile' -Tag @(
    'Unit'
    'OfflineBundle'
    'ContentStore'
    'Hashing'
) {
    It 'creates a valid content object from a file' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            [string]$sourcePath =
                Join-Path `
                    $TestRoot `
                    'source.bin'

            [byte[]]$sourceBytes =
                [Text.Encoding]::UTF8.GetBytes(
                    'Phoenix content object test'
                )

            [IO.File]::WriteAllBytes(
                $sourcePath,
                $sourceBytes
            )

            [string]$expectedDigest =
                (
                    Get-FileHash `
                        -LiteralPath $sourcePath `
                        -Algorithm SHA256
                ).Hash.ToLowerInvariant()

            $contentObject =
                Get-PhoenixContentObjectFromFile `
                    -LiteralPath $sourcePath

            $contentObject.IsValid() |
                Should-BeTrue

            ($contentObject.Digest -ceq $expectedDigest) |
                Should-BeTrue

            (
                $contentObject.ObjectId -ceq
                    "sha256:$expectedDigest"
            ) |
                Should-BeTrue

            $contentObject.Algorithm |
                Should-Be 'SHA256'

            $contentObject.Length |
                Should-Be $sourceBytes.LongLength

            $contentObject.RelativePath |
                Should-Be (
                    'objects/sha256/{0}/{1}' -f
                    $expectedDigest.Substring(0, 2),
                    $expectedDigest.Substring(2)
                )
        }
    }

    It 'supports an empty file' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            [string]$sourcePath =
                Join-Path `
                    $TestRoot `
                    'empty.bin'

            [IO.File]::WriteAllBytes(
                $sourcePath,
                [byte[]]::new(0)
            )

            $contentObject =
                Get-PhoenixContentObjectFromFile `
                    -LiteralPath $sourcePath

            $contentObject.IsValid() |
                Should-BeTrue

            $contentObject.Length |
                Should-Be 0

            $contentObject.Digest |
                Should-Be (
                    'e3b0c44298fc1c149afbf4c8996fb924' +
                    '27ae41e4649b934ca495991b7852b855'
                )
        }
    }

    It 'assigns identical content the same object identity' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            [byte[]]$sourceBytes =
                [Text.Encoding]::UTF8.GetBytes(
                    'deduplicated Phoenix content'
                )

            [string]$firstPath =
                Join-Path `
                    $TestRoot `
                    'first.bin'

            [string]$secondPath =
                Join-Path `
                    $TestRoot `
                    'second.bin'

            [IO.File]::WriteAllBytes(
                $firstPath,
                $sourceBytes
            )

            [IO.File]::WriteAllBytes(
                $secondPath,
                $sourceBytes
            )

            $firstObject =
                Get-PhoenixContentObjectFromFile `
                    -LiteralPath $firstPath

            $secondObject =
                Get-PhoenixContentObjectFromFile `
                    -LiteralPath $secondPath

            (
                $firstObject.ObjectId -ceq
                    $secondObject.ObjectId
            ) |
                Should-BeTrue

            (
                $firstObject.RelativePath -ceq
                    $secondObject.RelativePath
            ) |
                Should-BeTrue

            $firstObject.Length |
                Should-Be $secondObject.Length
        }
    }

    It 'assigns different content different object identities' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            [string]$firstPath =
                Join-Path `
                    $TestRoot `
                    'different-first.bin'

            [string]$secondPath =
                Join-Path `
                    $TestRoot `
                    'different-second.bin'

            [IO.File]::WriteAllText(
                $firstPath,
                'first Phoenix object'
            )

            [IO.File]::WriteAllText(
                $secondPath,
                'second Phoenix object'
            )

            $firstObject =
                Get-PhoenixContentObjectFromFile `
                    -LiteralPath $firstPath

            $secondObject =
                Get-PhoenixContentObjectFromFile `
                    -LiteralPath $secondPath

            (
                $firstObject.ObjectId -cne
                    $secondObject.ObjectId
            ) |
                Should-BeTrue
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

            [byte[]]$sourceBytes =
                [Text.Encoding]::UTF8.GetBytes(
                    'pipeline content'
                )

            [IO.File]::WriteAllBytes(
                $sourcePath,
                $sourceBytes
            )

            $contentObject =
                Get-Item `
                    -LiteralPath $sourcePath |
                    Get-PhoenixContentObjectFromFile

            $contentObject.IsValid() |
                Should-BeTrue

            $contentObject.Length |
                Should-Be $sourceBytes.LongLength
        }
    }

    It 'rejects a missing file and a directory' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            {
                Get-PhoenixContentObjectFromFile `
                    -LiteralPath (
                        Join-Path `
                            $TestRoot `
                            'missing.bin'
                    )
            } |
                Should-Throw

            {
                Get-PhoenixContentObjectFromFile `
                    -LiteralPath $TestRoot
            } |
                Should-Throw
        }
    }
}