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

Describe 'Phoenix content object contract' -Tag @(
    'Unit'
    'OfflineBundle'
    'ContentStore'
    'Contract'
) {
    It 'starts invalid until address and length are assigned' {
        InModuleScope Phoenix {
            $contentObject =
                [PhoenixContentObject]::new()

            $contentObject.Algorithm |
                Should-Be 'SHA256'

            $contentObject.Length |
                Should-Be -1

            $contentObject.IsValid() |
                Should-BeFalse
        }
    }

    It 'copies a valid address and content length' {
        InModuleScope Phoenix {
            [string]$digest =
                '0123456789abcdef0123456789abcdef' +
                '0123456789abcdef0123456789abcdef'

            $address =
                [PhoenixContentAddress]::new(
                    $digest
                )

            $contentObject =
                [PhoenixContentObject]::new(
                    $address,
                    4096
                )

            $contentObject.ObjectId |
                Should-Be "sha256:$digest"

            $contentObject.Algorithm |
                Should-Be 'SHA256'

            $contentObject.Digest |
                Should-Be $digest

            $contentObject.RelativePath |
                Should-Be (
                    'objects/sha256/01/{0}' -f
                        $digest.Substring(2)
                )

            $contentObject.Length |
                Should-Be 4096

            $contentObject.IsValid() |
                Should-BeTrue
        }
    }

    It 'uses the content address as the deduplication identity' {
        InModuleScope Phoenix {
            [string]$digest =
                'ab' + ('c' * 62)

            $address =
                [PhoenixContentAddress]::new(
                    $digest
                )

            $firstObject =
                [PhoenixContentObject]::new(
                    $address,
                    1024
                )

            $secondObject =
                [PhoenixContentObject]::new(
                    $address,
                    1024
                )

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
        }
    }

    It 'accepts zero-length content' {
        InModuleScope Phoenix {
            $address =
                [PhoenixContentAddress]::new(
                    ('0' * 64)
                )

            $contentObject =
                [PhoenixContentObject]::new(
                    $address,
                    0
                )

            $contentObject.Length |
                Should-Be 0

            $contentObject.IsValid() |
                Should-BeTrue
        }
    }

    It 'rejects missing invalid addresses and negative lengths' {
        InModuleScope Phoenix {
            {
                [void][PhoenixContentObject]::new(
                    $null,
                    1
                )
            } |
                Should-Throw

            $invalidAddress =
                [PhoenixContentAddress]::new()

            {
                [void][PhoenixContentObject]::new(
                    $invalidAddress,
                    1
                )
            } |
                Should-Throw

            $validAddress =
                [PhoenixContentAddress]::new(
                    ('f' * 64)
                )

            {
                [void][PhoenixContentObject]::new(
                    $validAddress,
                    -1
                )
            } |
                Should-Throw
        }
    }

    It 'copies address values instead of retaining mutable state' {
        InModuleScope Phoenix {
            [string]$originalDigest =
                '1' * 64

            $address =
                [PhoenixContentAddress]::new(
                    $originalDigest
                )

            $contentObject =
                [PhoenixContentObject]::new(
                    $address,
                    512
                )

            $address.SetDigest(
                ('2' * 64)
            )

            $contentObject.Digest |
                Should-Be $originalDigest

            $contentObject.ObjectId |
                Should-Be "sha256:$originalDigest"

            $contentObject.IsValid() |
                Should-BeTrue
        }
    }

    It 'detects altered identity fields' {
        InModuleScope Phoenix {
            [string]$digest =
                'abcdef0123456789abcdef0123456789' +
                'abcdef0123456789abcdef0123456789'

            $address =
                [PhoenixContentAddress]::new(
                    $digest
                )

            $contentObject =
                [PhoenixContentObject]::new(
                    $address,
                    2048
                )

            $contentObject.RelativePath =
                'objects/sha256/00/tampered'

            $contentObject.IsValid() |
                Should-BeFalse

            $contentObject.SetAddress(
                $address
            )

            $contentObject.ObjectId =
                'sha256:' + ('0' * 64)

            $contentObject.IsValid() |
                Should-BeFalse

            $contentObject.SetAddress(
                $address
            )

            $contentObject.Algorithm =
                'sha256'

            $contentObject.IsValid() |
                Should-BeFalse
        }
    }
}