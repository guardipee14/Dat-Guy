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

Describe 'Read-PhoenixOfflineBundleManifest' -Tag @(
    'Unit'
    'OfflineBundle'
    'Manifest'
    'Persistence'
    'Validation'
) {
    It 'round-trips a typed versioned manifest and its content objects' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            $manifest =
                [PhoenixOfflineBundleManifest]::new()

            $manifest.Name =
                'Phoenix round-trip bundle'

            $manifest.Description =
                'Typed offline-bundle manifest test'

            $manifest.Phoenix =
                [pscustomobject]@{
                    Version = '0.2.4'
                }

            $manifest.Windows =
                [pscustomobject]@{
                    Edition = 'Windows Test'
                }

            $manifest.Hardware =
                [pscustomobject]@{
                    Architecture = 'x64'
                }

            $manifest.Providers =
                [object[]]@(
                    [pscustomobject]@{
                        Name = 'WinGet'
                    }
                )

            $manifest.Sources =
                [object[]]@(
                    [pscustomobject]@{
                        Name = 'winget'
                    }
                )

            [string]$digest =
                'ab' + ('c' * 62)

            $contentObject =
                [PhoenixContentObject]::new(
                    [PhoenixContentAddress]::new(
                        $digest
                    ),
                    123
                )

            $manifest.AddObject(
                $contentObject
            )

            [string]$manifestPath =
                Join-Path `
                    $TestRoot `
                    'round-trip\phoenix-bundle.json'

            Save-PhoenixOfflineBundleManifest `
                -Manifest $manifest `
                -LiteralPath $manifestPath `
                -Confirm:$false |
                Out-Null

            $loadedManifest =
                Read-PhoenixOfflineBundleManifest `
                    -LiteralPath $manifestPath

            ($loadedManifest -is [PhoenixOfflineBundleManifest]) |
                Should-BeTrue

            $loadedManifest.IsValid() |
                Should-BeTrue

            $loadedManifest.Schema |
                Should-Be 'PhoenixOfflineBundleManifest'

            $loadedManifest.SchemaVersion |
                Should-Be '1.0'

            $loadedManifest.ContentStoreVersion |
                Should-Be '1.0'

            ($loadedManifest.BundleId -ceq $manifest.BundleId) |
                Should-BeTrue

            $loadedManifest.Name |
                Should-Be 'Phoenix round-trip bundle'

            $loadedManifest.Description |
                Should-Be 'Typed offline-bundle manifest test'

            $loadedManifest.Phoenix.Version |
                Should-Be '0.2.4'

            $loadedManifest.Windows.Edition |
                Should-Be 'Windows Test'

            $loadedManifest.Hardware.Architecture |
                Should-Be 'x64'

            @($loadedManifest.Providers).Count |
                Should-Be 1

            $loadedManifest.Providers[0].Name |
                Should-Be 'WinGet'

            $loadedManifest.ObjectCount |
                Should-Be 1

            $loadedManifest.TotalBytes |
                Should-Be 123

            ($loadedManifest.Objects[0] -is [PhoenixContentObject]) |
                Should-BeTrue

            $loadedManifest.Objects[0].ObjectId |
                Should-Be "sha256:$digest"

            $loadedManifest.Objects[0].Length |
                Should-Be 123
        }
    }

    It 'accepts a manifest FileInfo object from the pipeline' {
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
                    'pipeline\phoenix-bundle.json'

            Save-PhoenixOfflineBundleManifest `
                -Manifest $manifest `
                -LiteralPath $manifestPath `
                -Confirm:$false |
                Out-Null

            $loadedManifest =
                Get-Item `
                    -LiteralPath $manifestPath |
                    Read-PhoenixOfflineBundleManifest

            ($loadedManifest -is [PhoenixOfflineBundleManifest]) |
                Should-BeTrue

            $loadedManifest.IsValid() |
                Should-BeTrue
        }
    }

    It 'rejects a missing file and malformed JSON' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            {
                Read-PhoenixOfflineBundleManifest `
                    -LiteralPath (
                        Join-Path `
                            $TestRoot `
                            'missing.json'
                    )
            } |
                Should-Throw

            [string]$malformedPath =
                Join-Path `
                    $TestRoot `
                    'malformed.json'

            [IO.File]::WriteAllText(
                $malformedPath,
                '{invalid json',
                [Text.UTF8Encoding]::new($false)
            )

            {
                Read-PhoenixOfflineBundleManifest `
                    -LiteralPath $malformedPath
            } |
                Should-Throw
        }
    }

    It 'rejects unsupported schema and version identifiers' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            function Write-TestJson {
                param(
                    [object]$Value,
                    [string]$Path
                )

                [string]$json =
                    $Value |
                        ConvertTo-Json `
                            -Depth 50

                [IO.File]::WriteAllText(
                    $Path,
                    $json,
                    [Text.UTF8Encoding]::new($false)
                )
            }

            $manifest =
                [PhoenixOfflineBundleManifest]::new()

            [string]$manifestPath =
                Join-Path `
                    $TestRoot `
                    'versions.json'

            Save-PhoenixOfflineBundleManifest `
                -Manifest $manifest `
                -LiteralPath $manifestPath `
                -Confirm:$false |
                Out-Null

            [string]$validJson =
                [IO.File]::ReadAllText(
                    $manifestPath
                )

            $tamperCases =
                @(
                    @{
                        Property = 'Schema'
                        Value    = 'OtherManifest'
                    }
                    @{
                        Property = 'SchemaVersion'
                        Value    = '99.0'
                    }
                    @{
                        Property = 'ContentStoreVersion'
                        Value    = '99.0'
                    }
                )

            foreach ($tamperCase in $tamperCases) {
                $rawManifest =
                    $validJson |
                        ConvertFrom-Json

                $rawManifest.PSObject.Properties[
                    $tamperCase.Property
                ].Value =
                    $tamperCase.Value

                Write-TestJson `
                    -Value $rawManifest `
                    -Path $manifestPath

                {
                    Read-PhoenixOfflineBundleManifest `
                        -LiteralPath $manifestPath
                } |
                    Should-Throw
            }
        }
    }

    It 'rejects missing required properties and null collections' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            function Write-TestJson {
                param(
                    [object]$Value,
                    [string]$Path
                )

                [IO.File]::WriteAllText(
                    $Path,
                    (
                        $Value |
                            ConvertTo-Json `
                                -Depth 50
                    ),
                    [Text.UTF8Encoding]::new($false)
                )
            }

            $manifest =
                [PhoenixOfflineBundleManifest]::new()

            [string]$manifestPath =
                Join-Path `
                    $TestRoot `
                    'required-properties.json'

            Save-PhoenixOfflineBundleManifest `
                -Manifest $manifest `
                -LiteralPath $manifestPath `
                -Confirm:$false |
                Out-Null

            [string]$validJson =
                [IO.File]::ReadAllText(
                    $manifestPath
                )

            $missingPropertyManifest =
                $validJson |
                    ConvertFrom-Json

            $missingPropertyManifest.PSObject.Properties.Remove(
                'Objects'
            )

            Write-TestJson `
                -Value $missingPropertyManifest `
                -Path $manifestPath

            {
                Read-PhoenixOfflineBundleManifest `
                    -LiteralPath $manifestPath
            } |
                Should-Throw

            $nullCollectionManifest =
                $validJson |
                    ConvertFrom-Json

            $nullCollectionManifest.Providers =
                $null

            Write-TestJson `
                -Value $nullCollectionManifest `
                -Path $manifestPath

            {
                Read-PhoenixOfflineBundleManifest `
                    -LiteralPath $manifestPath
            } |
                Should-Throw
        }
    }

    It 'rejects summary values that do not match the object records' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            $manifest =
                [PhoenixOfflineBundleManifest]::new()

            $manifest.AddObject(
                [PhoenixContentObject]::new(
                    [PhoenixContentAddress]::new(
                        ('4' * 64)
                    ),
                    20
                )
            )

            [string]$manifestPath =
                Join-Path `
                    $TestRoot `
                    'summary.json'

            Save-PhoenixOfflineBundleManifest `
                -Manifest $manifest `
                -LiteralPath $manifestPath `
                -Confirm:$false |
                Out-Null

            $rawManifest =
                Get-Content `
                    -LiteralPath $manifestPath `
                    -Raw |
                    ConvertFrom-Json

            $rawManifest.TotalBytes =
                21

            [IO.File]::WriteAllText(
                $manifestPath,
                (
                    $rawManifest |
                        ConvertTo-Json `
                            -Depth 50
                ),
                [Text.UTF8Encoding]::new($false)
            )

            {
                Read-PhoenixOfflineBundleManifest `
                    -LiteralPath $manifestPath
            } |
                Should-Throw
        }
    }

    It 'rejects noncanonical and duplicate content-object records' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            function Write-TestJson {
                param(
                    [object]$Value,
                    [string]$Path
                )

                [IO.File]::WriteAllText(
                    $Path,
                    (
                        $Value |
                            ConvertTo-Json `
                                -Depth 50
                    ),
                    [Text.UTF8Encoding]::new($false)
                )
            }

            $manifest =
                [PhoenixOfflineBundleManifest]::new()

            $manifest.AddObject(
                [PhoenixContentObject]::new(
                    [PhoenixContentAddress]::new(
                        ('5' * 64)
                    ),
                    25
                )
            )

            [string]$manifestPath =
                Join-Path `
                    $TestRoot `
                    'objects.json'

            Save-PhoenixOfflineBundleManifest `
                -Manifest $manifest `
                -LiteralPath $manifestPath `
                -Confirm:$false |
                Out-Null

            [string]$validJson =
                [IO.File]::ReadAllText(
                    $manifestPath
                )

            $noncanonicalManifest =
                $validJson |
                    ConvertFrom-Json

            $noncanonicalManifest.Objects[0].RelativePath =
                'objects/sha256/00/tampered'

            Write-TestJson `
                -Value $noncanonicalManifest `
                -Path $manifestPath

            {
                Read-PhoenixOfflineBundleManifest `
                    -LiteralPath $manifestPath
            } |
                Should-Throw

            $duplicateManifest =
                $validJson |
                    ConvertFrom-Json

            $originalObject =
                $duplicateManifest.Objects[0]

            $duplicateManifest.Objects =
                @(
                    $originalObject
                    $originalObject
                )

            $duplicateManifest.ObjectCount =
                2

            $duplicateManifest.TotalBytes =
                50

            Write-TestJson `
                -Value $duplicateManifest `
                -Path $manifestPath

            {
                Read-PhoenixOfflineBundleManifest `
                    -LiteralPath $manifestPath
            } |
                Should-Throw
        }
    }

    It 'rejects invalid bundle identity and timestamps' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            function Write-TestJson {
                param(
                    [object]$Value,
                    [string]$Path
                )

                [IO.File]::WriteAllText(
                    $Path,
                    (
                        $Value |
                            ConvertTo-Json `
                                -Depth 50
                    ),
                    [Text.UTF8Encoding]::new($false)
                )
            }

            $manifest =
                [PhoenixOfflineBundleManifest]::new()

            [string]$manifestPath =
                Join-Path `
                    $TestRoot `
                    'identity.json'

            Save-PhoenixOfflineBundleManifest `
                -Manifest $manifest `
                -LiteralPath $manifestPath `
                -Confirm:$false |
                Out-Null

            [string]$validJson =
                [IO.File]::ReadAllText(
                    $manifestPath
                )

            $invalidBundleIdManifest =
                $validJson |
                    ConvertFrom-Json

            $invalidBundleIdManifest.BundleId =
                'not-a-guid'

            Write-TestJson `
                -Value $invalidBundleIdManifest `
                -Path $manifestPath

            {
                Read-PhoenixOfflineBundleManifest `
                    -LiteralPath $manifestPath
            } |
                Should-Throw

            $invalidTimestampManifest =
                $validJson |
                    ConvertFrom-Json

            $invalidTimestampManifest.CreatedAtUtc =
                'not-a-timestamp'

            Write-TestJson `
                -Value $invalidTimestampManifest `
                -Path $manifestPath

            {
                Read-PhoenixOfflineBundleManifest `
                    -LiteralPath $manifestPath
            } |
                Should-Throw
        }
    }
}