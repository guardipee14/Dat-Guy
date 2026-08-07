class PhoenixPackageAcquisitionRequest {

    [string]$RequestId
    [Package]$Package
    [string]$ContentStoreRoot
    [string]$WorkingDirectory
    [bool]$AllowInteractive
    [bool]$ForceRefresh
    [bool]$PreserveWorkingDirectory
    [hashtable]$Metadata
    [datetime]$CreatedAtUtc

    PhoenixPackageAcquisitionRequest() {

        $this.RequestId =
            [guid]::NewGuid().ToString('D')

        $this.ContentStoreRoot = ''
        $this.WorkingDirectory = ''
        $this.AllowInteractive = $false
        $this.ForceRefresh = $false
        $this.PreserveWorkingDirectory = $false
        $this.Metadata = @{}
        $this.CreatedAtUtc = [datetime]::UtcNow
    }

    [string] NormalizePath(
        [string]$Path
    ) {

        if ([string]::IsNullOrWhiteSpace($Path)) {
            throw 'A nonempty path is required.'
        }

        if (-not [IO.Path]::IsPathFullyQualified($Path)) {
            throw "The path must be fully qualified: $Path"
        }

        [string]$fullPath =
            [IO.Path]::GetFullPath($Path)

        [string]$pathRoot =
            [IO.Path]::GetPathRoot($fullPath)

        if ($fullPath.Length -gt $pathRoot.Length) {
            $fullPath =
                $fullPath.TrimEnd(
                    [char[]]@(
                        [IO.Path]::DirectorySeparatorChar
                        [IO.Path]::AltDirectorySeparatorChar
                    )
                )
        }

        return $fullPath
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

        if (
            [string]::IsNullOrWhiteSpace(
                $PackageRecord.Provider
            )
        ) {
            throw (
                'The Phoenix package record requires a provider.'
            )
        }

        $this.Package = $PackageRecord
    }

    [void] SetContentStoreRoot(
        [string]$Path
    ) {

        $this.ContentStoreRoot =
            $this.NormalizePath($Path)
    }

    [void] SetWorkingDirectory(
        [string]$Path
    ) {

        if ([string]::IsNullOrWhiteSpace($Path)) {
            $this.WorkingDirectory = ''
            return
        }

        $this.WorkingDirectory =
            $this.NormalizePath($Path)
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

        if (
            [string]::IsNullOrWhiteSpace(
                $this.Package.Provider
            )
        ) {
            return $false
        }

        if (
            [string]::IsNullOrWhiteSpace(
                $this.ContentStoreRoot
            ) -or
            -not [IO.Path]::IsPathFullyQualified(
                $this.ContentStoreRoot
            )
        ) {
            return $false
        }

        [string]$normalizedStoreRoot = ''

        try {
            $normalizedStoreRoot =
                $this.NormalizePath(
                    $this.ContentStoreRoot
                )
        }
        catch {
            return $false
        }

        if (
            -not [string]::Equals(
                $this.ContentStoreRoot,
                $normalizedStoreRoot,
                [StringComparison]::Ordinal
            )
        ) {
            return $false
        }

        if (
            -not [string]::IsNullOrWhiteSpace(
                $this.WorkingDirectory
            )
        ) {
            [string]$normalizedWorkingDirectory = ''

            try {
                $normalizedWorkingDirectory =
                    $this.NormalizePath(
                        $this.WorkingDirectory
                    )
            }
            catch {
                return $false
            }

            if (
                -not [string]::Equals(
                    $this.WorkingDirectory,
                    $normalizedWorkingDirectory,
                    [StringComparison]::Ordinal
                )
            ) {
                return $false
            }
        }

        if ($null -eq $this.Metadata) {
            return $false
        }

        if (
            $this.CreatedAtUtc -le
                [datetime]::MinValue
        ) {
            return $false
        }

        if (
            $this.CreatedAtUtc.Kind -ne
                [DateTimeKind]::Utc
        ) {
            return $false
        }

        return $true
    }
}
