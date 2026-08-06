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

Describe 'Phoenix package acquisition status contract' -Tag @(
    'Unit'
    'OfflineBundle'
    'ApplicationAcquisition'
    'Contract'
) {
    It 'assigns stable persisted values to every status' {
        InModuleScope Phoenix {
            $expectedValues =
                [ordered]@{
                    Unknown              = 0
                    Acquired             = 1
                    Reused               = 2
                    UserSuppliedRequired = 3
                    Unavailable          = 4
                    NotRedistributable   = 5
                    InteractiveOnly      = 6
                    SourceRestricted     = 7
                    Unsupported          = 8
                    Failed               = 9
                    Cancelled            = 10
                }

            foreach ($entry in $expectedValues.GetEnumerator()) {
                $status =
                    [enum]::Parse(
                        [PhoenixPackageAcquisitionStatus],
                        [string]$entry.Key
                    )

                [int]$status |
                    Should-Be ([int]$entry.Value)
            }
        }
    }

    It 'contains only the defined acquisition outcomes' {
        InModuleScope Phoenix {
            $expectedNames =
                @(
                    'Unknown'
                    'Acquired'
                    'Reused'
                    'UserSuppliedRequired'
                    'Unavailable'
                    'NotRedistributable'
                    'InteractiveOnly'
                    'SourceRestricted'
                    'Unsupported'
                    'Failed'
                    'Cancelled'
                )

            $actualNames =
                [enum]::GetNames(
                    [PhoenixPackageAcquisitionStatus]
                )

            $actualNames.Count |
                Should-Be $expectedNames.Count

            for (
                $index = 0
                $index -lt $expectedNames.Count
                $index++
            ) {
                (
                    $actualNames[$index] -ceq
                        $expectedNames[$index]
                ) |
                    Should-BeTrue
            }
        }
    }
}
