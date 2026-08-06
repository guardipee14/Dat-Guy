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

Describe 'Save-PhoenixOfflineBundleManifest' -Tag @(
    'Unit'
    'OfflineBundle'
    'Manifest'
    'Persistence'
) {
    It 'returns the resolved path without creating files under WhatIf' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            $manifest =
                [PhoenixOfflineBundleManifest]::new()

            [string]$manifestPath =
                Join-Path `
                    $TestRoot `
                    'preview\phoenix-bundle.json'

            [string]$savedPath =
                Save-PhoenixOfflineBundleManifest `
                    -Manifest $manifest `
                    -LiteralPath $manifestPath `
                    -WhatIf

            ($savedPath -ceq [IO.Path]::GetFullPath($manifestPath)) |
                Should-BeTrue

            Test-Path `
                -LiteralPath (
                    Split-Path `
                        -Path $manifestPath `
                        -Parent
                ) |
                Should-BeFalse
        }
    }

    It 'saves the versioned manifest and content-object summary' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            $manifest =
                [PhoenixOfflineBundleManifest]::new()

            $manifest.Name =
                'Phoenix test bundle'

            $manifest.Description =
                'Versioned offline-bundle manifest test'

            [string]$digest =
                'ab' + ('c' * 62)

            $contentObject =
                [PhoenixContentObject]::new(
                    [PhoenixContentAddress]::new(
                        $digest
                    ),
                    42
                )

            $manifest.AddObject(
                $contentObject
            )

            [string]$manifestPath =
                Join-Path `
                    $TestRoot `
                    'saved\phoenix-bundle.json'

            [string]$savedPath =
                Save-PhoenixOfflineBundleManifest `
                    -Manifest $manifest `
                    -LiteralPath $manifestPath `
                    -Confirm:$false

            Test-Path `
                -LiteralPath $savedPath `
                -PathType Leaf |
                Should-BeTrue

            $savedJson =
                Get-Content `
                    -LiteralPath $savedPath `
                    -Raw |
                    ConvertFrom-Json

            $savedJson.Schema |
                Should-Be 'PhoenixOfflineBundleManifest'

            $savedJson.SchemaVersion |
                Should-Be '1.0'

            $savedJson.ContentStoreVersion |
                Should-Be '1.0'

            ([string]$savedJson.BundleId -ceq $manifest.BundleId) |
                Should-BeTrue

            $savedJson.Name |
                Should-Be 'Phoenix test bundle'

            $savedJson.ObjectCount |
                Should-Be 1

            $savedJson.TotalBytes |
                Should-Be 42

            @($savedJson.Objects).Count |
                Should-Be 1

            $savedJson.Objects[0].ObjectId |
                Should-Be "sha256:$digest"

            $savedJson.Objects[0].Digest |
                Should-Be $digest

            $savedJson.Objects[0].Length |
                Should-Be 42

            [byte[]]$savedBytes =
                [IO.File]::ReadAllBytes(
                    $savedPath
                )

            (
                $savedBytes.Length -ge 3 -and
                $savedBytes[0] -eq 0xEF -and
                $savedBytes[1] -eq 0xBB -and
                $savedBytes[2] -eq 0xBF
            ) |
                Should-BeFalse
        }
    }

    It 'replaces an existing manifest and removes temporary files' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            $manifest =
                [PhoenixOfflineBundleManifest]::new()

            $manifest.Name =
                'First manifest'

            [string]$manifestPath =
                Join-Path `
                    $TestRoot `
                    'replace\phoenix-bundle.json'

            Save-PhoenixOfflineBundleManifest `
                -Manifest $manifest `
                -LiteralPath $manifestPath `
                -Confirm:$false |
                Out-Null

            $manifest.Name =
                'Replacement manifest'

            Save-PhoenixOfflineBundleManifest `
                -Manifest $manifest `
                -LiteralPath $manifestPath `
                -Confirm:$false |
                Out-Null

            $savedJson =
                Get-Content `
                    -LiteralPath $manifestPath `
                    -Raw |
                    ConvertFrom-Json

            $savedJson.Name |
                Should-Be 'Replacement manifest'

            @(
                Get-ChildItem `
                    -LiteralPath (
                        Split-Path `
                            -Path $manifestPath `
                            -Parent
                    ) `
                    -File `
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

    It 'rejects an invalid manifest without changing an existing file' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            $validManifest =
                [PhoenixOfflineBundleManifest]::new()

            $validManifest.Name =
                'Preserved manifest'

            [string]$manifestPath =
                Join-Path `
                    $TestRoot `
                    'preserve\phoenix-bundle.json'

            Save-PhoenixOfflineBundleManifest `
                -Manifest $validManifest `
                -LiteralPath $manifestPath `
                -Confirm:$false |
                Out-Null

            [string]$originalContent =
                [IO.File]::ReadAllText(
                    $manifestPath
                )

            $invalidManifest =
                [PhoenixOfflineBundleManifest]::new()

            $invalidManifest.Schema =
                'TamperedSchema'

            {
                Save-PhoenixOfflineBundleManifest `
                    -Manifest $invalidManifest `
                    -LiteralPath $manifestPath `
                    -Confirm:$false
            } |
                Should-Throw

            [IO.File]::ReadAllText(
                $manifestPath
            ) |
                Should-Be $originalContent
        }
    }

    It 'rejects a directory as the manifest destination' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            $manifest =
                [PhoenixOfflineBundleManifest]::new()

            [string]$directoryPath =
                Join-Path `
                    $TestRoot `
                    'manifest-directory'

            $null =
                New-Item `
                    -ItemType Directory `
                    -Path $directoryPath `
                    -Force

            {
                Save-PhoenixOfflineBundleManifest `
                    -Manifest $manifest `
                    -LiteralPath $directoryPath `
                    -Confirm:$false
            } |
                Should-Throw

            Test-Path `
                -LiteralPath $directoryPath `
                -PathType Container |
                Should-BeTrue
        }
    }

    It 'resolves relative destinations from the current location' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            $manifest =
                [PhoenixOfflineBundleManifest]::new()

            Push-Location `
                -LiteralPath $TestRoot

            try {
                [string]$savedPath =
                    Save-PhoenixOfflineBundleManifest `
                        -Manifest $manifest `
                        -LiteralPath 'relative\phoenix-bundle.json' `
                        -Confirm:$false
            }
            finally {
                Pop-Location
            }

            [string]$expectedPath =
                [IO.Path]::GetFullPath(
                    (
                        Join-Path `
                            $TestRoot `
                            'relative\phoenix-bundle.json'
                    )
                )

            ($savedPath -ceq $expectedPath) |
                Should-BeTrue

            Test-Path `
                -LiteralPath $expectedPath `
                -PathType Leaf |
                Should-BeTrue
        }
    }
}