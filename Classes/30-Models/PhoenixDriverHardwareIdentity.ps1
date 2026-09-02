class PhoenixDriverHardwareIdentity {

    [string]$DeviceInstanceId
    [string[]]$HardwareIds
    [string[]]$CompatibleIds
    [string]$Class
    [string]$ClassGuid
    [string]$Manufacturer

    PhoenixDriverHardwareIdentity() {
        $this.DeviceInstanceId = ''
        $this.HardwareIds = @()
        $this.CompatibleIds = @()
        $this.Class = ''
        $this.ClassGuid = ''
        $this.Manufacturer = ''
    }

    [string[]] NormalizeIdentifiers([string[]]$Identifiers) {
        if ($null -eq $Identifiers) {
            return @()
        }

        $seen = [System.Collections.Generic.HashSet[string]]::new(
            [StringComparer]::OrdinalIgnoreCase
        )
        $normalized = [System.Collections.Generic.List[string]]::new()

        foreach ($identifier in $Identifiers) {
            if ([string]::IsNullOrWhiteSpace($identifier)) {
                continue
            }

            [string]$value = $identifier.Trim().ToUpperInvariant()

            if ($seen.Add($value)) {
                $normalized.Add($value)
            }
        }

        return @($normalized)
    }

    [void] SetDeviceInstanceId([string]$InstanceId) {
        if ([string]::IsNullOrWhiteSpace($InstanceId)) {
            $this.DeviceInstanceId = ''
            return
        }

        $this.DeviceInstanceId = $InstanceId.Trim().ToUpperInvariant()
    }

    [void] SetHardwareIds([string[]]$Identifiers) {
        $this.HardwareIds = $this.NormalizeIdentifiers($Identifiers)
    }

    [void] SetCompatibleIds([string[]]$Identifiers) {
        $this.CompatibleIds = $this.NormalizeIdentifiers($Identifiers)
    }

    [bool] IdentifiersAreNormalized([string[]]$Identifiers) {
        if ($null -eq $Identifiers) {
            return $false
        }

        $seen = [System.Collections.Generic.HashSet[string]]::new(
            [StringComparer]::OrdinalIgnoreCase
        )

        foreach ($identifier in $Identifiers) {
            if ([string]::IsNullOrWhiteSpace($identifier)) {
                return $false
            }

            [string]$normalized = $identifier.Trim().ToUpperInvariant()

            if ($identifier -cne $normalized) {
                return $false
            }

            if (-not $seen.Add($identifier)) {
                return $false
            }
        }

        return $true
    }

    [bool] HasMatchIdentifiers() {
        return (
            $this.HardwareIds.Count -gt 0 -or
            $this.CompatibleIds.Count -gt 0
        )
    }

    [bool] IsValid() {
        if ($null -eq $this.HardwareIds -or $null -eq $this.CompatibleIds) {
            return $false
        }

        if (-not $this.IdentifiersAreNormalized($this.HardwareIds)) {
            return $false
        }

        if (-not $this.IdentifiersAreNormalized($this.CompatibleIds)) {
            return $false
        }

        if (-not $this.HasMatchIdentifiers()) {
            return $false
        }

        if (
            -not [string]::IsNullOrWhiteSpace($this.DeviceInstanceId) -and
            $this.DeviceInstanceId -cne $this.DeviceInstanceId.Trim().ToUpperInvariant()
        ) {
            return $false
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

        return $true
    }
}
