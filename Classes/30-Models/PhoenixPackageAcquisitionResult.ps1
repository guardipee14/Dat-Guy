class PhoenixPackageAcquisitionResult {

    [string]$AcquisitionId
    [Package]$Package
    [PhoenixPackageAcquisitionStatus]$Status
    [bool]$Success
    [string]$Code
    [string]$Message
    [string]$Provider
    [string]$Source
    [string]$SourceUri
    [string]$FileName
    [string]$MediaType
    [PhoenixContentObject]$ContentObject
    [hashtable]$Metadata
    [string[]]$Warnings
    [string[]]$Errors
    [datetime]$StartedAtUtc
    [datetime]$CompletedAtUtc
    [timespan]$Duration

    PhoenixPackageAcquisitionResult() {

        $this.AcquisitionId =
            [guid]::NewGuid().ToString('D')

        $this.Status =
            [PhoenixPackageAcquisitionStatus]::Unknown

        $this.Success = $false
        $this.Code =
            'PHX_PACKAGE_ACQUISITION_NOT_STARTED'

        $this.Message =
            'Package acquisition has not started.'

        $this.Provider = ''
        $this.Source = ''
        $this.SourceUri = ''
        $this.FileName = ''
        $this.MediaType = ''
        $this.Metadata = @{}
        $this.Warnings = @()
        $this.Errors = @()
        $this.StartedAtUtc = [datetime]::UtcNow
        $this.CompletedAtUtc = [datetime]::MinValue
        $this.Duration = [timespan]::Zero
    }

    [void] SetPackage(
        [Package]$PackageRecord
    ) {

        if ($null -eq $PackageRecord) {
            throw 'A Phoenix package record is required.'
        }

        if (
            [string]::IsNullOrWhiteSpace(
                $PackageRecord.Id
            ) -and
            [string]::IsNullOrWhiteSpace(
                $PackageRecord.Name
            )
        ) {
            throw (
                'The Phoenix package record requires an ID or name.'
            )
        }

        $this.Package = $PackageRecord
        $this.Provider = $PackageRecord.Provider
        $this.Source = $PackageRecord.Source
    }

    [void] SetContentObject(
        [PhoenixContentObject]$StoredObject
    ) {

        if ($null -eq $StoredObject) {
            throw 'A Phoenix content object is required.'
        }

        if (-not $StoredObject.IsValid()) {
            throw 'The Phoenix content object is invalid.'
        }

        $objectCopy =
            [PhoenixContentObject]::new()

        $objectCopy.ObjectId =
            $StoredObject.ObjectId

        $objectCopy.Algorithm =
            $StoredObject.Algorithm

        $objectCopy.Digest =
            $StoredObject.Digest

        $objectCopy.RelativePath =
            $StoredObject.RelativePath

        $objectCopy.Length =
            $StoredObject.Length

        $this.ContentObject = $objectCopy
    }

    [bool] HasArtifactStatus(
        [PhoenixPackageAcquisitionStatus]$AcquisitionStatus
    ) {

        return (
            $AcquisitionStatus -eq
                [PhoenixPackageAcquisitionStatus]::Acquired -or
            $AcquisitionStatus -eq
                [PhoenixPackageAcquisitionStatus]::Reused
        )
    }

    [void] Complete(
        [PhoenixPackageAcquisitionStatus]$AcquisitionStatus,
        [string]$ResultCode,
        [string]$ResultMessage
    ) {

        if (
            $AcquisitionStatus -eq
                [PhoenixPackageAcquisitionStatus]::Unknown
        ) {
            throw 'An acquisition completion status is required.'
        }

        if ([string]::IsNullOrWhiteSpace($ResultCode)) {
            throw 'An acquisition result code is required.'
        }

        if ([string]::IsNullOrWhiteSpace($ResultMessage)) {
            throw 'An acquisition result message is required.'
        }

        [bool]$artifactStatus =
            $this.HasArtifactStatus(
                $AcquisitionStatus
            )

        if (
            $artifactStatus -and
            (
                $null -eq $this.ContentObject -or
                -not $this.ContentObject.IsValid()
            )
        ) {
            throw (
                'A successful acquisition requires a valid ' +
                'Phoenix content object.'
            )
        }

        if (
            -not $artifactStatus -and
            $null -ne $this.ContentObject
        ) {
            throw (
                'A non-artifact acquisition outcome cannot retain ' +
                'a Phoenix content object.'
            )
        }

        $this.Status = $AcquisitionStatus
        $this.Success = $artifactStatus
        $this.Code = $ResultCode
        $this.Message = $ResultMessage
        $this.CompletedAtUtc = [datetime]::UtcNow
        $this.Duration =
            $this.CompletedAtUtc - $this.StartedAtUtc

        if (
            $AcquisitionStatus -eq
                [PhoenixPackageAcquisitionStatus]::Failed -and
            $this.Errors.Count -eq 0
        ) {
            $this.Errors = @($ResultMessage)
        }
    }

    [bool] IsComplete() {

        return (
            $this.CompletedAtUtc -gt
                [datetime]::MinValue
        )
    }

    [bool] IsSuccessful() {

        if (-not $this.IsComplete()) {
            return $false
        }

        if (-not $this.Success) {
            return $false
        }

        if (-not $this.HasArtifactStatus($this.Status)) {
            return $false
        }

        return (
            $null -ne $this.ContentObject -and
            $this.ContentObject.IsValid()
        )
    }

    [bool] IsValid() {

        [guid]$parsedAcquisitionId =
            [guid]::Empty

        if (
            -not [guid]::TryParse(
                $this.AcquisitionId,
                [ref]$parsedAcquisitionId
            ) -or
            $parsedAcquisitionId -eq [guid]::Empty
        ) {
            return $false
        }

        if ($null -eq $this.Package) {
            return $false
        }

        if (
            [string]::IsNullOrWhiteSpace(
                $this.Package.Id
            ) -and
            [string]::IsNullOrWhiteSpace(
                $this.Package.Name
            )
        ) {
            return $false
        }

        if ([string]::IsNullOrWhiteSpace($this.Provider)) {
            return $false
        }

        if (
            $this.Status -eq
                [PhoenixPackageAcquisitionStatus]::Unknown
        ) {
            return $false
        }

        if (-not $this.IsComplete()) {
            return $false
        }

        if (
            [string]::IsNullOrWhiteSpace($this.Code) -or
            [string]::IsNullOrWhiteSpace($this.Message)
        ) {
            return $false
        }

        if (
            $this.CompletedAtUtc -lt
                $this.StartedAtUtc
        ) {
            return $false
        }

        if (
            $this.Duration -ne
                (
                    $this.CompletedAtUtc -
                    $this.StartedAtUtc
                )
        ) {
            return $false
        }

        if (
            $null -eq $this.Metadata -or
            $null -eq $this.Warnings -or
            $null -eq $this.Errors
        ) {
            return $false
        }

        [bool]$artifactStatus =
            $this.HasArtifactStatus(
                $this.Status
            )

        if ($this.Success -ne $artifactStatus) {
            return $false
        }

        if ($artifactStatus) {
            return (
                $null -ne $this.ContentObject -and
                $this.ContentObject.IsValid()
            )
        }

        if ($null -ne $this.ContentObject) {
            return $false
        }

        if (
            $this.Status -eq
                [PhoenixPackageAcquisitionStatus]::Failed -and
            $this.Errors.Count -eq 0
        ) {
            return $false
        }

        return $true
    }
}
