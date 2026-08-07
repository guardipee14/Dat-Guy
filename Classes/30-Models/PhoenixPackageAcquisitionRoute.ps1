class PhoenixPackageAcquisitionRoute {

    [string]$RequestId
    [bool]$Resolved
    [bool]$UsedFallback
    [PhoenixPackageAcquisitionAdapter]$SelectedAdapter
    [PhoenixPackageAcquisitionAdapter[]]$Alternatives
    [string]$Code
    [string]$Message
    [datetime]$ResolvedAtUtc

    PhoenixPackageAcquisitionRoute() {

        $this.RequestId = ''
        $this.Resolved = $false
        $this.UsedFallback = $false
        $this.Alternatives = @()
        $this.Code =
            'PHX_PACKAGE_ACQUISITION_ROUTE_NOT_RESOLVED'

        $this.Message =
            'A package-acquisition route has not been resolved.'

        $this.ResolvedAtUtc =
            [datetime]::MinValue
    }

    [void] CompleteResolved(
        [PhoenixPackageAcquisitionRequest]$Request,
        [PhoenixPackageAcquisitionAdapter]$Selected,
        [PhoenixPackageAcquisitionAdapter[]]$OrderedAlternatives,
        [bool]$Fallback
    ) {

        if (
            $null -eq $Request -or
            -not $Request.IsValid()
        ) {
            throw 'A valid package-acquisition request is required.'
        }

        if (
            $null -eq $Selected -or
            -not $Selected.IsValid() -or
            -not $Selected.CanHandle(
                $Request,
                $Fallback
            )
        ) {
            throw 'A compatible selected acquisition adapter is required.'
        }

        [string[]]$seenAdapterIds =
            @($Selected.AdapterId)

        foreach ($alternative in @($OrderedAlternatives)) {
            if (
                $null -eq $alternative -or
                -not $alternative.IsValid() -or
                -not $alternative.CanHandle(
                    $Request,
                    $Fallback
                )
            ) {
                throw 'Every alternative acquisition adapter must be compatible.'
            }

            foreach ($seenAdapterId in $seenAdapterIds) {
                if (
                    [string]::Equals(
                        $seenAdapterId,
                        $alternative.AdapterId,
                        [StringComparison]::OrdinalIgnoreCase
                    )
                ) {
                    throw 'Acquisition routes cannot contain duplicate adapters.'
                }
            }

            $seenAdapterIds =
                @($seenAdapterIds) +
                @($alternative.AdapterId)
        }

        $this.RequestId =
            $Request.RequestId

        $this.Resolved = $true
        $this.UsedFallback = $Fallback
        $this.SelectedAdapter = $Selected
        $this.Alternatives =
            @($OrderedAlternatives)

        if ($Fallback) {
            $this.Code =
                'PHX_PACKAGE_ACQUISITION_FALLBACK_ROUTE_RESOLVED'

            $this.Message =
                "Fallback acquisition adapter '$($Selected.Name)' was selected."
        }
        else {
            $this.Code =
                'PHX_PACKAGE_ACQUISITION_ROUTE_RESOLVED'

            $this.Message =
                "Acquisition adapter '$($Selected.Name)' was selected."
        }

        $this.ResolvedAtUtc =
            [datetime]::UtcNow
    }

    [void] CompleteUnresolved(
        [PhoenixPackageAcquisitionRequest]$Request,
        [string]$ResultMessage
    ) {

        if (
            $null -eq $Request -or
            -not $Request.IsValid()
        ) {
            throw 'A valid package-acquisition request is required.'
        }

        if ([string]::IsNullOrWhiteSpace($ResultMessage)) {
            throw 'An unresolved route message is required.'
        }

        $this.RequestId =
            $Request.RequestId

        $this.Resolved = $false
        $this.UsedFallback = $false
        $this.SelectedAdapter = $null
        $this.Alternatives = @()
        $this.Code =
            'PHX_PACKAGE_ACQUISITION_ROUTE_UNAVAILABLE'

        $this.Message =
            $ResultMessage

        $this.ResolvedAtUtc =
            [datetime]::UtcNow
    }

    [bool] IsValid() {

        [guid]$parsedRequestId =
            [guid]::Empty

        if (
            -not [guid]::TryParse(
                $this.RequestId,
                [ref]$parsedRequestId
            ) -or
            $parsedRequestId -eq [guid]::Empty
        ) {
            return $false
        }

        if (
            $this.ResolvedAtUtc -le
                [datetime]::MinValue -or
            $this.ResolvedAtUtc.Kind -ne
                [DateTimeKind]::Utc -or
            [string]::IsNullOrWhiteSpace($this.Code) -or
            [string]::IsNullOrWhiteSpace($this.Message) -or
            $null -eq $this.Alternatives
        ) {
            return $false
        }

        if ($this.Resolved) {
            if (
                $null -eq $this.SelectedAdapter -or
                -not $this.SelectedAdapter.IsValid()
            ) {
                return $false
            }

            if (
                $this.UsedFallback -and
                -not $this.SelectedAdapter.IsFallback
            ) {
                return $false
            }

            if (
                -not $this.UsedFallback -and
                $this.SelectedAdapter.IsFallback
            ) {
                return $false
            }

            [string[]]$seenAdapterIds =
                @($this.SelectedAdapter.AdapterId)

            foreach ($alternative in @($this.Alternatives)) {
                if (
                    $null -eq $alternative -or
                    -not $alternative.IsValid()
                ) {
                    return $false
                }

                foreach ($seenAdapterId in $seenAdapterIds) {
                    if (
                        [string]::Equals(
                            $seenAdapterId,
                            $alternative.AdapterId,
                            [StringComparison]::OrdinalIgnoreCase
                        )
                    ) {
                        return $false
                    }
                }

                $seenAdapterIds =
                    @($seenAdapterIds) +
                    @($alternative.AdapterId)
            }

            return $true
        }

        return (
            -not $this.UsedFallback -and
            $null -eq $this.SelectedAdapter -and
            $this.Alternatives.Count -eq 0 -and
            $this.Code -eq
                'PHX_PACKAGE_ACQUISITION_ROUTE_UNAVAILABLE'
        )
    }
}
