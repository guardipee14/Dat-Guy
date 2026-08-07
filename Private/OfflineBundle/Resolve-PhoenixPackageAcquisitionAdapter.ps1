function Resolve-PhoenixPackageAcquisitionAdapter {

    [CmdletBinding()]
    [OutputType([PhoenixPackageAcquisitionRoute])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PhoenixPackageAcquisitionRequest]$Request,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PhoenixPackageAcquisitionAdapter[]]$Adapter,

        [Parameter()]
        [switch]$AllowFallback
    )

    if (-not $Request.IsValid()) {
        throw 'A valid package-acquisition request is required.'
    }

    [PhoenixPackageAcquisitionAdapter[]]$exactMatches =
        @()

    [PhoenixPackageAcquisitionAdapter[]]$fallbackMatches =
        @()

    foreach ($candidate in @($Adapter)) {
        if (
            $null -eq $candidate -or
            -not $candidate.IsValid() -or
            -not $candidate.Enabled
        ) {
            continue
        }

        if (
            -not $candidate.IsFallback -and
            $candidate.CanHandle(
                $Request,
                $false
            )
        ) {
            $exactMatches =
                @($exactMatches) +
                @($candidate)

            continue
        }

        if (
            $AllowFallback -and
            $candidate.IsFallback -and
            $candidate.CanHandle(
                $Request,
                $true
            )
        ) {
            $fallbackMatches =
                @($fallbackMatches) +
                @($candidate)
        }
    }

    [PhoenixPackageAcquisitionAdapter[]]$selectedMatches =
        @()

    [bool]$usedFallback =
        $false

    if ($exactMatches.Count -gt 0) {
        $selectedMatches =
            @($exactMatches)
    }
    elseif (
        $AllowFallback -and
        $fallbackMatches.Count -gt 0
    ) {
        $selectedMatches =
            @($fallbackMatches)

        $usedFallback =
            $true
    }

    $route =
        [PhoenixPackageAcquisitionRoute]::new()

    if ($selectedMatches.Count -eq 0) {
        $route.CompleteUnresolved(
            $Request,
            (
                "No eligible acquisition adapter was found for " +
                "provider '$($Request.Package.Provider)'."
            )
        )

        return $route
    }

    [PhoenixPackageAcquisitionAdapter[]]$orderedMatches =
        @(
            $selectedMatches |
                Sort-Object `
                    -Property @(
                        @{
                            Expression = {
                                $_.Priority
                            }
                            Descending = $true
                        }
                        @{
                            Expression = {
                                $_.Name
                            }
                            Ascending = $true
                        }
                        @{
                            Expression = {
                                $_.AdapterId
                            }
                            Ascending = $true
                        }
                    )
        )

    [PhoenixPackageAcquisitionAdapter]$selectedAdapter =
        $orderedMatches[0]

    [PhoenixPackageAcquisitionAdapter[]]$alternatives =
        @()

    for (
        $index = 1
        $index -lt $orderedMatches.Count
        $index++
    ) {
        $alternatives =
            @($alternatives) +
            @($orderedMatches[$index])
    }

    $route.CompleteResolved(
        $Request,
        $selectedAdapter,
        $alternatives,
        $usedFallback
    )

    return $route
}
