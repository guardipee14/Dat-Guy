class PhoenixPackageAcquisitionAdapter {

    [string]$AdapterId
    [string]$Name
    [string]$Provider
    [int]$Priority
    [bool]$Enabled
    [bool]$IsFallback
    [string[]]$SupportedSources
    [string[]]$SupportedInstallerTypes
    [bool]$SupportsInteractive
    [bool]$SupportsForceRefresh
    [hashtable]$Metadata

    PhoenixPackageAcquisitionAdapter() {

        $this.AdapterId =
            [guid]::NewGuid().ToString('D')

        $this.Name = ''
        $this.Provider = ''
        $this.Priority = 0
        $this.Enabled = $true
        $this.IsFallback = $false
        $this.SupportedSources = @()
        $this.SupportedInstallerTypes = @()
        $this.SupportsInteractive = $false
        $this.SupportsForceRefresh = $false
        $this.Metadata = @{}
    }

    [void] SetIdentity(
        [string]$AdapterName,
        [string]$ProviderName
    ) {

        if ([string]::IsNullOrWhiteSpace($AdapterName)) {
            throw 'An acquisition-adapter name is required.'
        }

        if ([string]::IsNullOrWhiteSpace($ProviderName)) {
            throw 'An acquisition-adapter provider is required.'
        }

        $this.Name = $AdapterName.Trim()
        $this.Provider = $ProviderName.Trim()
    }

    hidden [bool] ContainsValue(
        [string[]]$Values,
        [string]$Candidate
    ) {

        foreach ($value in @($Values)) {
            if (
                [string]::Equals(
                    $value,
                    $Candidate,
                    [StringComparison]::OrdinalIgnoreCase
                )
            ) {
                return $true
            }
        }

        return $false
    }

    [void] AddSupportedSource(
        [string]$Source
    ) {

        if ([string]::IsNullOrWhiteSpace($Source)) {
            throw 'A supported source name is required.'
        }

        [string]$normalizedSource =
            $Source.Trim()

        if (
            -not $this.ContainsValue(
                $this.SupportedSources,
                $normalizedSource
            )
        ) {
            $this.SupportedSources =
                @($this.SupportedSources) +
                @($normalizedSource)
        }
    }

    [void] AddSupportedInstallerType(
        [string]$InstallerType
    ) {

        if (
            [string]::IsNullOrWhiteSpace(
                $InstallerType
            )
        ) {
            throw 'A supported installer type is required.'
        }

        [string]$normalizedInstallerType =
            $InstallerType.Trim()

        if (
            -not $this.ContainsValue(
                $this.SupportedInstallerTypes,
                $normalizedInstallerType
            )
        ) {
            $this.SupportedInstallerTypes =
                @($this.SupportedInstallerTypes) +
                @($normalizedInstallerType)
        }
    }

    hidden [bool] MatchesFilter(
        [string[]]$Values,
        [string]$Candidate
    ) {

        if (@($Values).Count -eq 0) {
            return $true
        }

        if ([string]::IsNullOrWhiteSpace($Candidate)) {
            return $false
        }

        return $this.ContainsValue(
            $Values,
            $Candidate
        )
    }

    [bool] CanHandle(
        [PhoenixPackageAcquisitionRequest]$Request
    ) {

        return $this.CanHandle(
            $Request,
            $false
        )
    }

    [bool] CanHandle(
        [PhoenixPackageAcquisitionRequest]$Request,
        [bool]$AllowFallback
    ) {

        if (
            $null -eq $Request -or
            -not $Request.IsValid() -or
            -not $this.IsValid() -or
            -not $this.Enabled
        ) {
            return $false
        }

        [string]$requestedProvider =
            $Request.Package.Provider

        if ($this.IsFallback) {
            if (
                -not $AllowFallback -or
                $this.Provider -cne '*'
            ) {
                return $false
            }
        }
        elseif (
            -not [string]::Equals(
                $this.Provider,
                $requestedProvider,
                [StringComparison]::OrdinalIgnoreCase
            )
        ) {
            return $false
        }

        if (
            $Request.ForceRefresh -and
            -not $this.SupportsForceRefresh
        ) {
            return $false
        }

        if (
            -not $this.MatchesFilter(
                $this.SupportedSources,
                $Request.Package.Source
            )
        ) {
            return $false
        }

        if (
            -not $this.MatchesFilter(
                $this.SupportedInstallerTypes,
                $Request.Package.InstallerType
            )
        ) {
            return $false
        }

        return $true
    }

    [PhoenixPackageAcquisitionResult] Acquire(
        [PhoenixPackageAcquisitionRequest]$Request
    ) {

        if (
            $null -eq $Request -or
            -not $Request.IsValid()
        ) {
            throw 'A valid package-acquisition request is required.'
        }

        $result =
            [PhoenixPackageAcquisitionResult]::new()

        $result.SetPackage(
            $Request.Package
        )

        $result.Metadata['AdapterId'] =
            $this.AdapterId

        $result.Metadata['AdapterName'] =
            $this.Name

        $result.Metadata['RequestId'] =
            $Request.RequestId

        $result.Complete(
            [PhoenixPackageAcquisitionStatus]::Unsupported,
            'PHX_PACKAGE_ACQUISITION_NOT_IMPLEMENTED',
            (
                "Acquisition adapter '$($this.Name)' " +
                'does not implement artifact acquisition.'
            )
        )

        return $result
    }

    [bool] IsValid() {

        [guid]$parsedAdapterId =
            [guid]::Empty

        if (
            -not [guid]::TryParse(
                $this.AdapterId,
                [ref]$parsedAdapterId
            ) -or
            $parsedAdapterId -eq [guid]::Empty
        ) {
            return $false
        }

        if (
            [string]::IsNullOrWhiteSpace($this.Name) -or
            [string]::IsNullOrWhiteSpace($this.Provider) -or
            $this.Priority -lt 0
        ) {
            return $false
        }

        if (
            $this.IsFallback -and
            $this.Provider -cne '*'
        ) {
            return $false
        }

        if (
            -not $this.IsFallback -and
            $this.Provider -ceq '*'
        ) {
            return $false
        }

        if (
            $null -eq $this.SupportedSources -or
            $null -eq $this.SupportedInstallerTypes -or
            $null -eq $this.Metadata
        ) {
            return $false
        }

        [string[]]$seenSources = @()

        foreach ($source in @($this.SupportedSources)) {
            if (
                [string]::IsNullOrWhiteSpace($source) -or
                $this.ContainsValue(
                    $seenSources,
                    $source
                )
            ) {
                return $false
            }

            $seenSources =
                @($seenSources) +
                @($source)
        }

        [string[]]$seenInstallerTypes = @()

        foreach (
            $installerType in
            @($this.SupportedInstallerTypes)
        ) {
            if (
                [string]::IsNullOrWhiteSpace(
                    $installerType
                ) -or
                $this.ContainsValue(
                    $seenInstallerTypes,
                    $installerType
                )
            ) {
                return $false
            }

            $seenInstallerTypes =
                @($seenInstallerTypes) +
                @($installerType)
        }

        return $true
    }
}
