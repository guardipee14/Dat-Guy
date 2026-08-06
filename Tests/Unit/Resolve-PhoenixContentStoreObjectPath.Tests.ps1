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

Describe 'Resolve-PhoenixContentStoreObjectPath' -Tag @(
    'Unit'
    'OfflineBundle'
    'ContentStore'
    'Path'
) {
    It 'resolves the canonical sharded object path' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            [string]$digest =
                'ab' + ('c' * 62)

            $address =
                [PhoenixContentAddress]::new(
                    $digest
                )

            [string]$actualPath =
                Resolve-PhoenixContentStoreObjectPath `
                    -StoreRoot $TestRoot `
                    -Address $address

            [string]$expectedPath =
                [IO.Path]::GetFullPath(
                    [IO.Path]::Combine(
                        $TestRoot,
                        'objects',
                        'sha256',
                        'ab',
                        ('c' * 62)
                    )
                )

            ($actualPath -ceq $expectedPath) |
                Should-BeTrue

            [IO.Path]::IsPathRooted(
                $actualPath
            ) |
                Should-BeTrue
        }
    }

    It 'does not create the store root or object path' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            [string]$storeRoot =
                Join-Path `
                    $TestRoot `
                    'missing-content-store'

            $address =
                [PhoenixContentAddress]::new(
                    ('1' * 64)
                )

            [string]$objectPath =
                Resolve-PhoenixContentStoreObjectPath `
                    -StoreRoot $storeRoot `
                    -Address $address

            Test-Path `
                -LiteralPath $storeRoot |
                Should-BeFalse

            Test-Path `
                -LiteralPath $objectPath |
                Should-BeFalse
        }
    }

    It 'accepts a store root with a trailing separator' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            [string]$storeRoot =
                $TestRoot.TrimEnd(
                    [char[]]@(
                        '\'
                        '/'
                    )
                ) +
                [IO.Path]::DirectorySeparatorChar

            $address =
                [PhoenixContentAddress]::new(
                    ('2' * 64)
                )

            [string]$actualPath =
                Resolve-PhoenixContentStoreObjectPath `
                    -StoreRoot $storeRoot `
                    -Address $address

            [string]$expectedPath =
                [IO.Path]::GetFullPath(
                    [IO.Path]::Combine(
                        $TestRoot,
                        'objects',
                        'sha256',
                        '22',
                        ('2' * 62)
                    )
                )

            ($actualPath -ceq $expectedPath) |
                Should-BeTrue
        }
    }

    It 'rejects an invalid content address' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            $invalidAddress =
                [PhoenixContentAddress]::new()

            {
                Resolve-PhoenixContentStoreObjectPath `
                    -StoreRoot $TestRoot `
                    -Address $invalidAddress
            } |
                Should-Throw
        }
    }

    It 'rejects a tampered relative object path' {
        InModuleScope Phoenix -Parameters @{
            TestRoot = $TestDrive
        } {
            param(
                [string]$TestRoot
            )

            $address =
                [PhoenixContentAddress]::new(
                    ('3' * 64)
                )

            $address.RelativePath =
                '../outside'

            {
                Resolve-PhoenixContentStoreObjectPath `
                    -StoreRoot $TestRoot `
                    -Address $address
            } |
                Should-Throw
        }
    }
}