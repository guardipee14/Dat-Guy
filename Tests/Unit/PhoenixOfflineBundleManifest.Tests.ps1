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

Describe 'Phoenix offline bundle manifest contract' -Tag @(
    'Unit'
    'OfflineBundle'
    'Manifest'
    'Contract'
) {
    It 'creates a valid versioned empty manifest' {
        InModuleScope Phoenix {
            $manifest =
                [PhoenixOfflineBundleManifest]::new()

            $manifest.Schema |
                Should-Be 'PhoenixOfflineBundleManifest'

            $manifest.SchemaVersion |
                Should-Be '1.0'

            $manifest.ContentStoreVersion |
                Should-Be '1.0'

            $parsedBundleId =
                [guid]::Parse(
                    $manifest.BundleId
                )

            ($parsedBundleId -ne [guid]::Empty) |
                Should-BeTrue

            $manifest.CreatedAtUtc.Kind |
                Should-Be ([DateTimeKind]::Utc)

            $manifest.UpdatedAtUtc.Kind |
                Should-Be ([DateTimeKind]::Utc)

            $manifest.ObjectCount |
                Should-Be 0

            $manifest.TotalBytes |
                Should-Be 0

            $manifest.IsValid() |
                Should-BeTrue
        }
    }

    It 'initializes reserved metadata sections safely' {
        InModuleScope Phoenix {
            $manifest =
                [PhoenixOfflineBundleManifest]::new()

            ($null -eq $manifest.Phoenix) |
                Should-BeTrue

            ($null -eq $manifest.Windows) |
                Should-BeTrue

            ($null -eq $manifest.Hardware) |
                Should-BeTrue

            @($manifest.Providers).Count |
                Should-Be 0

            @($manifest.Sources).Count |
                Should-Be 0

            @($manifest.Packages).Count |
                Should-Be 0

            @($manifest.Drivers).Count |
                Should-Be 0

            @($manifest.Dependencies).Count |
                Should-Be 0

            @($manifest.Licenses).Count |
                Should-Be 0

            @($manifest.Provenance).Count |
                Should-Be 0

            @($manifest.Objects).Count |
                Should-Be 0
        }
    }

    It 'adds content objects and refreshes its summary' {
        InModuleScope Phoenix {
            $firstObject =
                [PhoenixContentObject]::new(
                    [PhoenixContentAddress]::new(
                        ('1' * 64)
                    ),
                    1024
                )

            $secondObject =
                [PhoenixContentObject]::new(
                    [PhoenixContentAddress]::new(
                        ('2' * 64)
                    ),
                    2048
                )

            $manifest =
                [PhoenixOfflineBundleManifest]::new()

            $manifest.AddObject(
                $firstObject
            )

            $manifest.AddObject(
                $secondObject
            )

            $manifest.Objects.Count |
                Should-Be 2

            $manifest.ObjectCount |
                Should-Be 2

            $manifest.TotalBytes |
                Should-Be 3072

            $manifest.IsValid() |
                Should-BeTrue
        }
    }

    It 'deduplicates matching content identities' {
        InModuleScope Phoenix {
            $address =
                [PhoenixContentAddress]::new(
                    ('a' * 64)
                )

            $firstObject =
                [PhoenixContentObject]::new(
                    $address,
                    512
                )

            $duplicateObject =
                [PhoenixContentObject]::new(
                    $address,
                    512
                )

            $manifest =
                [PhoenixOfflineBundleManifest]::new()

            $manifest.AddObject(
                $firstObject
            )

            $manifest.AddObject(
                $duplicateObject
            )

            $manifest.Objects.Count |
                Should-Be 1

            $manifest.ObjectCount |
                Should-Be 1

            $manifest.TotalBytes |
                Should-Be 512

            $manifest.IsValid() |
                Should-BeTrue
        }
    }

    It 'rejects conflicting lengths for one content identity' {
        InModuleScope Phoenix {
            $address =
                [PhoenixContentAddress]::new(
                    ('b' * 64)
                )

            $firstObject =
                [PhoenixContentObject]::new(
                    $address,
                    1024
                )

            $conflictingObject =
                [PhoenixContentObject]::new(
                    $address,
                    2048
                )

            $manifest =
                [PhoenixOfflineBundleManifest]::new()

            $manifest.AddObject(
                $firstObject
            )

            {
                $manifest.AddObject(
                    $conflictingObject
                )
            } |
                Should-Throw

            $manifest.ObjectCount |
                Should-Be 1

            $manifest.TotalBytes |
                Should-Be 1024

            $manifest.IsValid() |
                Should-BeTrue
        }
    }

    It 'uses exact canonical object identity for lookup' {
        InModuleScope Phoenix {
            $contentObject =
                [PhoenixContentObject]::new(
                    [PhoenixContentAddress]::new(
                        ('c' * 64)
                    ),
                    256
                )

            $manifest =
                [PhoenixOfflineBundleManifest]::new()

            $manifest.AddObject(
                $contentObject
            )

            $manifest.ContainsObject(
                $contentObject.ObjectId
            ) |
                Should-BeTrue

            $manifest.ContainsObject(
                $contentObject.ObjectId.ToUpperInvariant()
            ) |
                Should-BeFalse

            $manifest.ContainsObject(
                'sha256:' + ('d' * 64)
            ) |
                Should-BeFalse

            $manifest.ContainsObject('   ') |
                Should-BeFalse
        }
    }

    It 'rejects null and invalid content objects' {
        InModuleScope Phoenix {
            $manifest =
                [PhoenixOfflineBundleManifest]::new()

            {
                $manifest.AddObject(
                    $null
                )
            } |
                Should-Throw

            $invalidObject =
                [PhoenixContentObject]::new()

            {
                $manifest.AddObject(
                    $invalidObject
                )
            } |
                Should-Throw

            $manifest.ObjectCount |
                Should-Be 0

            $manifest.TotalBytes |
                Should-Be 0

            $manifest.IsValid() |
                Should-BeTrue
        }
    }

    It 'detects altered versions summaries and duplicate records' {
        InModuleScope Phoenix {
            $firstObject =
                [PhoenixContentObject]::new(
                    [PhoenixContentAddress]::new(
                        ('e' * 64)
                    ),
                    4096
                )

            $manifest =
                [PhoenixOfflineBundleManifest]::new()

            $manifest.AddObject(
                $firstObject
            )

            $manifest.ObjectCount = 99

            $manifest.IsValid() |
                Should-BeFalse

            $manifest.RefreshSummary()

            $manifest.IsValid() |
                Should-BeTrue

            $manifest.TotalBytes = 1

            $manifest.IsValid() |
                Should-BeFalse

            $manifest.RefreshSummary()

            $manifest.SchemaVersion = '2.0'

            $manifest.IsValid() |
                Should-BeFalse

            $manifest.SchemaVersion = '1.0'
            $manifest.ContentStoreVersion = '2.0'

            $manifest.IsValid() |
                Should-BeFalse

            $manifest.ContentStoreVersion = '1.0'

            $manifest.Objects = @(
                $firstObject
                $firstObject
            )

            $manifest.RefreshSummary()

            $manifest.IsValid() |
                Should-BeFalse
        }
    }
}