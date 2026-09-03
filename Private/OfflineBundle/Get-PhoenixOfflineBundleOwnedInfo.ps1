function Get-PhoenixOfflineBundleOwnedInfo {

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Phoenix offline bundle was not found: $Path"
    }

    [IO.DirectoryInfo]$rootItem =
        Get-Item -LiteralPath $Path -Force -ErrorAction Stop

    if (($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Phoenix offline-bundle roots cannot be reparse points: $($rootItem.FullName)"
    }

    [string]$manifestPath =
        Join-Path $rootItem.FullName 'manifest.json'

    [string]$markerPath =
        Join-Path $rootItem.FullName '.phoenix-offline-bundle'

    if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
        throw "The directory is not marked as Phoenix-owned: $($rootItem.FullName)"
    }

    [IO.FileInfo]$markerItem =
        Get-Item -LiteralPath $markerPath -Force -ErrorAction Stop

    if (($markerItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw 'The Phoenix offline-bundle ownership marker cannot be a reparse point.'
    }

    try {
        $marker =
            Get-Content -LiteralPath $markerPath -Raw -ErrorAction Stop |
                ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "The Phoenix offline-bundle ownership marker is invalid: $($_.Exception.Message)"
    }

    if ([string]$marker.Schema -cne 'PhoenixOfflineBundleOwnership') {
        throw 'The Phoenix offline-bundle ownership marker schema is invalid.'
    }

    $manifest =
        Read-PhoenixOfflineBundleManifest -LiteralPath $manifestPath

    if ([string]$marker.BundleId -cne $manifest.BundleId) {
        throw 'The ownership marker and manifest bundle identities do not match.'
    }

    return [pscustomobject]@{
        RootPath = $rootItem.FullName
        ManifestPath = $manifestPath
        MarkerPath = $markerPath
        Manifest = $manifest
    }
}

function ConvertTo-PhoenixOfflineBundleProvenanceRecord {

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$LiteralPath,

        [Parameter(Mandatory)]
        [PhoenixContentObject]$ContentObject
    )

    [string]$resolvedPath =
        (Resolve-Path -LiteralPath $LiteralPath -ErrorAction Stop).Path

    [string]$signatureStatus = 'NotApplicable'
    [string]$publisher = ''

    if ([IO.Path]::GetExtension($resolvedPath) -in @('.exe', '.dll', '.msi', '.ps1', '.psm1', '.psd1', '.cat')) {
        try {
            $signature =
                Get-AuthenticodeSignature `
                    -LiteralPath $resolvedPath `
                    -ErrorAction Stop

            $signatureStatus = [string]$signature.Status

            if ($null -ne $signature.SignerCertificate) {
                $publisher = [string]$signature.SignerCertificate.Subject
            }
        }
        catch {
            $signatureStatus = 'UnknownError'
        }
    }

    return [pscustomobject]@{
        ObjectId = $ContentObject.ObjectId
        Source = $resolvedPath
        CapturedAtUtc = [datetime]::UtcNow
        SignatureStatus = $signatureStatus
        Publisher = $publisher
    }
}
