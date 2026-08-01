class PhoenixOemDriverAdapter {
    [string]$Name
    [string[]]$Manufacturers
    [string[]]$HardwareIdPrefixes
    [string]$UtilityName
    [string]$UtilityUri
    [bool]$RequiresUtilityApproval
    [bool]$UtilityAvailable
    [bool]$Applicable

    PhoenixOemDriverAdapter(
        [string]$Name,
        [string[]]$Manufacturers,
        [string[]]$HardwareIdPrefixes
    ) {
        $this.Name = $Name
        $this.Manufacturers = $Manufacturers
        $this.HardwareIdPrefixes = $HardwareIdPrefixes
        $this.RequiresUtilityApproval = $true
    }

    [bool] TestApplicable(
        [string]$Manufacturer,
        [string[]]$HardwareIds
    ) {
        [bool]$manufacturerMatch = $false
        foreach ($candidate in $this.Manufacturers) {
            if ($Manufacturer -like "*$candidate*") {
                $manufacturerMatch = $true
                break
            }
        }
        if (-not $manufacturerMatch) { return $false }
        if ($this.HardwareIdPrefixes.Count -eq 0) { return $true }
        foreach ($hardwareId in @($HardwareIds)) {
            foreach ($prefix in $this.HardwareIdPrefixes) {
                if ($hardwareId.StartsWith(
                    $prefix,
                    [StringComparison]::OrdinalIgnoreCase
                )) { return $true }
            }
        }
        return $false
    }

    [PhoenixOemDriverUpdate[]] Scan([object]$HardwareIdentity) {
        return @()
    }

    [Result] Install([PhoenixOemDriverUpdate]$Update) {
        $result = [Result]::Failure(
            "OEM driver installation is not implemented for $($this.Name)."
        )
        $result.Code = 'PHX_OEM_INSTALL_UNAVAILABLE'
        $result.Provider = $this.Name
        $result.Operation = 'InstallDriver'
        $result.Target = if ($null -ne $Update) { $Update.Id } else { '' }
        return $result
    }

    [object] GetStatus() {
        return [pscustomobject]@{
            Name = $this.Name
            Manufacturers = $this.Manufacturers -join ', '
            UtilityName = $this.UtilityName
            UtilityUri = $this.UtilityUri
            RequiresUtilityApproval = $this.RequiresUtilityApproval
            UtilityAvailable = $this.UtilityAvailable
            Applicable = $this.Applicable
        }
    }
}
