class PhoenixOfflineDriverPackage {

    [string]$PackageId
    [string]$InfName
    [string]$Provider
    [string]$Version
    [datetime]$DriverDate
    [string]$Class
    [string]$ClassGuid
    [string]$Architecture
    [string[]]$HardwareIds
    [string[]]$CompatibleIds
    [PhoenixContentObject[]]$Files
    [hashtable]$Metadata

    PhoenixOfflineDriverPackage() {
        $this.PackageId = ''
        $this.InfName = ''
        $this.Provider = ''
        $this.Version = ''
        $this.DriverDate = [datetime]::MinValue
        $this.Class = ''
        $this.ClassGuid = ''
        $this.Architecture = 'Unknown'
        $this.HardwareIds = @()
        $this.CompatibleIds = @()
        $this.Files = @()
        $this.Metadata = @{}
    }

    [void] SetMatchIdentifiers(
        [string[]]$HardwareIdentifiers,
        [string[]]$CompatibleIdentifiers
    ) {
        $identity = [PhoenixDriverHardwareIdentity]::new()
        $identity.SetHardwareIds($HardwareIdentifiers)
        $identity.SetCompatibleIds($CompatibleIdentifiers)
        $this.HardwareIds = @($identity.HardwareIds)
        $this.CompatibleIds = @($identity.CompatibleIds)
    }

    [void] AddFile([PhoenixContentObject]$ContentObject) {
        if ($null -eq $ContentObject) {
            throw 'A Phoenix content object is required.'
        }

        if (-not $ContentObject.IsValid()) {
            throw 'The Phoenix content object is invalid.'
        }

        foreach ($existingObject in $this.Files) {
            if ($existingObject.ObjectId -ceq $ContentObject.ObjectId) {
                if ($existingObject.Length -ne $ContentObject.Length) {
                    throw (
                        "Driver package content object '$($ContentObject.ObjectId)' " +
                        'has a conflicting byte length.'
                    )
                }

                return
            }
        }

        $copy = [PhoenixContentObject]::new()
        $copy.ObjectId = $ContentObject.ObjectId
        $copy.Algorithm = $ContentObject.Algorithm
        $copy.Digest = $ContentObject.Digest
        $copy.RelativePath = $ContentObject.RelativePath
        $copy.Length = $ContentObject.Length

        $this.Files = @(
            $this.Files
            $copy
        )
    }

    [bool] HasMatchIdentifiers() {
        return (
            $this.HardwareIds.Count -gt 0 -or
            $this.CompatibleIds.Count -gt 0
        )
    }

    [bool] IsValid() {
        if ([string]::IsNullOrWhiteSpace($this.PackageId)) {
            return $false
        }

        if (
            [string]::IsNullOrWhiteSpace($this.InfName) -or
            -not $this.InfName.EndsWith('.inf', [StringComparison]::OrdinalIgnoreCase)
        ) {
            return $false
        }

        if ([string]::IsNullOrWhiteSpace($this.Provider)) {
            return $false
        }

        if ([string]::IsNullOrWhiteSpace($this.Version)) {
            return $false
        }

        if ([string]::IsNullOrWhiteSpace($this.Architecture)) {
            return $false
        }

        if ($null -eq $this.HardwareIds -or $null -eq $this.CompatibleIds) {
            return $false
        }

        $identity = [PhoenixDriverHardwareIdentity]::new()
        $identity.SetHardwareIds($this.HardwareIds)
        $identity.SetCompatibleIds($this.CompatibleIds)

        if (
            -not $identity.HasMatchIdentifiers() -or
            $identity.HardwareIds.Count -ne $this.HardwareIds.Count -or
            $identity.CompatibleIds.Count -ne $this.CompatibleIds.Count
        ) {
            return $false
        }

        for ($index = 0; $index -lt $this.HardwareIds.Count; $index++) {
            if ($identity.HardwareIds[$index] -cne $this.HardwareIds[$index]) {
                return $false
            }
        }

        for ($index = 0; $index -lt $this.CompatibleIds.Count; $index++) {
            if ($identity.CompatibleIds[$index] -cne $this.CompatibleIds[$index]) {
                return $false
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($this.ClassGuid)) {
            [guid]$parsedClassGuid = [guid]::Empty

            if (
                -not [guid]::TryParse($this.ClassGuid, [ref]$parsedClassGuid) -or
                $parsedClassGuid -eq [guid]::Empty
            ) {
                return $false
            }
        }

        if ($null -eq $this.Files -or $this.Files.Count -eq 0) {
            return $false
        }

        $objectIds = [System.Collections.Generic.HashSet[string]]::new(
            [StringComparer]::Ordinal
        )

        foreach ($contentObject in $this.Files) {
            if ($null -eq $contentObject -or -not $contentObject.IsValid()) {
                return $false
            }

            if (-not $objectIds.Add($contentObject.ObjectId)) {
                return $false
            }
        }

        if ($null -eq $this.Metadata) {
            return $false
        }

        return $true
    }
}
