class PhoenixOfflineBundleManifest {

    [string]$Schema
    [string]$SchemaVersion
    [string]$ContentStoreVersion
    [string]$BundleId
    [string]$Name
    [string]$Description
    [datetime]$CreatedAtUtc
    [datetime]$UpdatedAtUtc
    [object]$Phoenix
    [object]$Windows
    [object]$Hardware
    [object[]]$Providers
    [object[]]$Sources
    [object[]]$Packages
    [object[]]$Drivers
    [object[]]$Dependencies
    [object[]]$Licenses
    [object[]]$Provenance
    [PhoenixContentObject[]]$Objects
    [int]$ObjectCount
    [long]$TotalBytes

    PhoenixOfflineBundleManifest() {

        $this.Schema =
            'PhoenixOfflineBundleManifest'

        $this.SchemaVersion =
            '1.0'

        $this.ContentStoreVersion =
            '1.0'

        $this.BundleId =
            [guid]::NewGuid().ToString()

        $this.Name = ''
        $this.Description = ''

        $this.CreatedAtUtc =
            [datetime]::UtcNow

        $this.UpdatedAtUtc =
            $this.CreatedAtUtc

        $this.Phoenix = $null
        $this.Windows = $null
        $this.Hardware = $null
        $this.Providers = @()
        $this.Sources = @()
        $this.Packages = @()
        $this.Drivers = @()
        $this.Dependencies = @()
        $this.Licenses = @()
        $this.Provenance = @()
        $this.Objects = @()
        $this.ObjectCount = 0
        $this.TotalBytes = 0
    }

    [void] AddObject(
        [PhoenixContentObject]$ContentObject
    ) {

        if ($null -eq $ContentObject) {
            throw 'A Phoenix content object is required.'
        }

        if (-not $ContentObject.IsValid()) {
            throw 'The Phoenix content object is invalid.'
        }

        foreach ($existingObject in $this.Objects) {

            if (
                $existingObject.ObjectId -ceq
                    $ContentObject.ObjectId
            ) {

                if (
                    $existingObject.Length -ne
                        $ContentObject.Length
                ) {
                    throw (
                        "Content object '$($ContentObject.ObjectId)' " +
                        'has a conflicting byte length.'
                    )
                }

                return
            }
        }

        $this.Objects =
            @(
                $this.Objects
                $ContentObject
            )

        $this.UpdatedAtUtc =
            [datetime]::UtcNow

        $this.RefreshSummary()
    }

    [bool] ContainsObject(
        [string]$ObjectId
    ) {

        if ([string]::IsNullOrWhiteSpace($ObjectId)) {
            return $false
        }

        foreach ($contentObject in $this.Objects) {

            if (
                $contentObject.ObjectId -ceq
                    $ObjectId
            ) {
                return $true
            }
        }

        return $false
    }

    [void] RefreshSummary() {

        [long]$calculatedBytes = 0

        foreach ($contentObject in $this.Objects) {

            if ($null -ne $contentObject) {
                $calculatedBytes +=
                    $contentObject.Length
            }
        }

        $this.ObjectCount =
            $this.Objects.Count

        $this.TotalBytes =
            $calculatedBytes
    }

    [bool] IsValid() {

        if (
            $this.Schema -cne
                'PhoenixOfflineBundleManifest'
        ) {
            return $false
        }

        if ($this.SchemaVersion -cne '1.0') {
            return $false
        }

        if ($this.ContentStoreVersion -cne '1.0') {
            return $false
        }

        if ([string]::IsNullOrWhiteSpace($this.BundleId)) {
            return $false
        }

        try {
            [void][guid]::Parse(
                $this.BundleId
            )
        }
        catch {
            return $false
        }

        if (
            $this.CreatedAtUtc -eq
                [datetime]::MinValue -or
            $this.UpdatedAtUtc -eq
                [datetime]::MinValue -or
            $this.UpdatedAtUtc -lt
                $this.CreatedAtUtc
        ) {
            return $false
        }

        $objectIds =
            [System.Collections.Generic.HashSet[string]]::new(
                [StringComparer]::Ordinal
            )

        [long]$expectedTotalBytes = 0

        foreach ($contentObject in $this.Objects) {

            if ($null -eq $contentObject) {
                return $false
            }

            if (-not $contentObject.IsValid()) {
                return $false
            }

            if (
                -not $objectIds.Add(
                    $contentObject.ObjectId
                )
            ) {
                return $false
            }

            $expectedTotalBytes +=
                $contentObject.Length
        }

        if (
            $this.ObjectCount -ne
                $this.Objects.Count
        ) {
            return $false
        }

        if (
            $this.TotalBytes -ne
                $expectedTotalBytes
        ) {
            return $false
        }

        return $true
    }
}