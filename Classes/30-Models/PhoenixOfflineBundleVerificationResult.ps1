class PhoenixOfflineBundleVerificationResult {

    [string]$BundleId
    [string]$Policy
    [bool]$Success
    [bool]$ManifestValid
    [bool]$IntegrityValid
    [bool]$ProvenanceValid
    [bool]$LicenseValid
    [bool]$TrustValid
    [int]$CheckedObjectCount
    [datetime]$CheckedAtUtc
    [string[]]$Errors
    [string[]]$Warnings

    PhoenixOfflineBundleVerificationResult() {
        $this.BundleId = ''
        $this.Policy = 'IntegrityOnly'
        $this.Success = $false
        $this.ManifestValid = $false
        $this.IntegrityValid = $false
        $this.ProvenanceValid = $false
        $this.LicenseValid = $false
        $this.TrustValid = $false
        $this.CheckedObjectCount = 0
        $this.CheckedAtUtc = [datetime]::MinValue
        $this.Errors = @()
        $this.Warnings = @()
    }

    [void] AddError([string]$Message) {
        if ([string]::IsNullOrWhiteSpace($Message)) {
            return
        }

        $this.Errors = @($this.Errors + $Message.Trim())
    }

    [void] AddWarning([string]$Message) {
        if ([string]::IsNullOrWhiteSpace($Message)) {
            return
        }

        $this.Warnings = @($this.Warnings + $Message.Trim())
    }

    [void] Complete() {
        $this.CheckedAtUtc = [datetime]::UtcNow
        $this.Success = (
            $this.ManifestValid -and
            $this.IntegrityValid -and
            $this.ProvenanceValid -and
            $this.LicenseValid -and
            $this.TrustValid -and
            $this.Errors.Count -eq 0
        )
    }

    [bool] IsValid() {
        return (
            -not [string]::IsNullOrWhiteSpace($this.Policy) -and
            $this.CheckedObjectCount -ge 0 -and
            $this.CheckedAtUtc -ne [datetime]::MinValue -and
            $null -ne $this.Errors -and
            $null -ne $this.Warnings -and
            (
                -not $this.Success -or
                (
                    $this.ManifestValid -and
                    $this.IntegrityValid -and
                    $this.ProvenanceValid -and
                    $this.LicenseValid -and
                    $this.TrustValid -and
                    $this.Errors.Count -eq 0
                )
            )
        )
    }
}
