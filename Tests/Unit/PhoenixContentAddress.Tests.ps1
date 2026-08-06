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

Describe 'Phoenix content address contract' -Tag @(
    'Unit'
    'OfflineBundle'
    'ContentStore'
    'Contract'
) {
    It 'starts invalid until a digest is assigned' {
        InModuleScope Phoenix {
            $address =
                [PhoenixContentAddress]::new()

            $address.Algorithm |
                Should-Be 'SHA256'

            $address.Digest |
                Should-Be ''

            $address.ObjectId |
                Should-Be ''

            $address.RelativePath |
                Should-Be ''

            $address.IsValid() |
                Should-BeFalse
        }
    }

    It 'normalizes an uppercase SHA-256 digest' {
        InModuleScope Phoenix {
            [string]$inputDigest =
                'ABCDEF0123456789ABCDEF0123456789' +
                'ABCDEF0123456789ABCDEF0123456789'

            [string]$expectedDigest =
                $inputDigest.ToLowerInvariant()

            $address =
                [PhoenixContentAddress]::new(
                    $inputDigest
                )

            ($address.Digest -ceq $expectedDigest) |
                Should-BeTrue

            (
                $address.ObjectId -ceq
                    "sha256:$expectedDigest"
            ) |
                Should-BeTrue

            $address.IsValid() |
                Should-BeTrue
        }
    }

    It 'creates the canonical sharded object path' {
        InModuleScope Phoenix {
            [string]$digest =
                'ab' + ('c' * 62)

            $address =
                [PhoenixContentAddress]::new(
                    $digest
                )

            $address.RelativePath |
                Should-Be (
                    'objects/sha256/ab/{0}' -f
                        ('c' * 62)
                )

            $address.RelativePath.Contains('\') |
                Should-BeFalse

            $address.IsValid() |
                Should-BeTrue
        }
    }

    It 'refreshes all derived values when the digest changes' {
        InModuleScope Phoenix {
            $address =
                [PhoenixContentAddress]::new(
                    ('0' * 64)
                )

            $address.SetDigest(
                ('f' * 64)
            )

            $address.Digest |
                Should-Be ('f' * 64)

            $address.ObjectId |
                Should-Be (
                    'sha256:{0}' -f
                        ('f' * 64)
                )

            $address.RelativePath |
                Should-Be (
                    'objects/sha256/ff/{0}' -f
                        ('f' * 62)
                )

            $address.IsValid() |
                Should-BeTrue
        }
    }

    It 'rejects blank malformed and nonhexadecimal digests' {
        InModuleScope Phoenix {
            $invalidDigests = @(
                ''
                '   '
                ('a' * 63)
                ('a' * 65)
                ('g' * 64)
                'not-a-sha256-digest'
            )

            foreach ($invalidDigest in $invalidDigests) {
                {
                    [void][PhoenixContentAddress]::new(
                        $invalidDigest
                    )
                } |
                    Should-Throw
            }
        }
    }

    It 'detects altered derived address fields' {
        InModuleScope Phoenix {
            [string]$digest =
                '0123456789abcdef0123456789abcdef' +
                '0123456789abcdef0123456789abcdef'

            $address =
                [PhoenixContentAddress]::new(
                    $digest
                )

            $address.ObjectId =
                'sha256:' + ('f' * 64)

            $address.IsValid() |
                Should-BeFalse

            $address.SetDigest(
                $digest
            )

            $address.RelativePath =
                'objects/sha256/00/tampered'

            $address.IsValid() |
                Should-BeFalse

            $address.SetDigest(
                $digest
            )

            $address.Algorithm =
                'sha256'

            $address.IsValid() |
                Should-BeFalse
        }
    }
}