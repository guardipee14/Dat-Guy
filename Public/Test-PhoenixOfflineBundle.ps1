using module '..\Classes\Phoenix.Classes.psm1'

function Get-PhoenixOfflineBundleRecordValue {

    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [Collections.IDictionary]) {
        foreach ($key in $InputObject.Keys) {
            if ([string]::Equals([string]$key, $Name, [StringComparison]::OrdinalIgnoreCase)) {
                return $InputObject[$key]
            }
        }
    }
    else {
        $property = $InputObject.PSObject.Properties[$Name]

        if ($null -ne $property) {
            return $property.Value
        }
    }

    return $null
}

function Test-PhoenixOfflineBundle {

    [CmdletBinding()]
    [OutputType([PhoenixOfflineBundleVerificationResult])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter()]
        [ValidateSet('IntegrityOnly', 'ProvenanceRequired', 'Redistributable', 'TrustedPublisher')]
        [string]$Policy = 'IntegrityOnly'
    )

    process {
        $result =
            [PhoenixOfflineBundleVerificationResult]::new()

        $result.Policy = $Policy

        try {
            [string]$rootPath =
                [IO.Path]::GetFullPath($Path)

            [string]$manifestPath =
                if (Test-Path -LiteralPath $rootPath -PathType Leaf) {
                    $rootPath
                }
                else {
                    Join-Path $rootPath 'manifest.json'
                }

            [string]$bundleRoot =
                Split-Path -Path $manifestPath -Parent

            $manifest =
                Read-PhoenixOfflineBundleManifest `
                    -LiteralPath $manifestPath

            $result.BundleId = $manifest.BundleId
            $result.ManifestValid = $manifest.IsValid()

            if (-not $result.ManifestValid) {
                $result.AddError('The offline-bundle manifest contract is invalid.')
            }

            [bool]$integrityValid = $true

            foreach ($contentObject in $manifest.Objects) {
                $result.CheckedObjectCount++

                if (
                    -not (
                        Test-PhoenixContentStoreObject `
                            -StoreRoot $bundleRoot `
                            -ContentObject $contentObject
                    )
                ) {
                    $integrityValid = $false
                    $result.AddError(
                        "Content object '$($contentObject.ObjectId)' failed length or SHA-256 verification."
                    )
                }
            }

            $result.IntegrityValid = $integrityValid

            $provenanceByObject = @{}

            foreach ($record in @($manifest.Provenance)) {
                [string]$objectId =
                    [string](Get-PhoenixOfflineBundleRecordValue -InputObject $record -Name 'ObjectId')

                [string]$source =
                    [string](Get-PhoenixOfflineBundleRecordValue -InputObject $record -Name 'Source')

                if ([string]::IsNullOrWhiteSpace($objectId) -or [string]::IsNullOrWhiteSpace($source)) {
                    $result.AddError('A provenance record is missing ObjectId or Source.')
                    continue
                }

                $provenanceByObject[$objectId] = $record
            }

            [bool]$requireProvenance =
                $Policy -ne 'IntegrityOnly'

            [bool]$provenanceValid = $true

            foreach ($contentObject in $manifest.Objects) {
                if (-not $provenanceByObject.ContainsKey($contentObject.ObjectId)) {
                    if ($requireProvenance) {
                        $provenanceValid = $false
                        $result.AddError("Content object '$($contentObject.ObjectId)' has no provenance record.")
                    }
                    else {
                        $result.AddWarning("Content object '$($contentObject.ObjectId)' has no provenance record.")
                    }
                }
            }

            $result.ProvenanceValid = $provenanceValid

            [bool]$licenseValid = $true
            [bool]$requireLicense =
                $Policy -in @('Redistributable', 'TrustedPublisher')

            foreach ($packageRecord in @($manifest.Packages)) {
                [string]$packageId =
                    [string](Get-PhoenixOfflineBundleRecordValue -InputObject $packageRecord -Name 'PackageId')

                if ([string]::IsNullOrWhiteSpace($packageId)) {
                    $packageId =
                        [string](Get-PhoenixOfflineBundleRecordValue -InputObject $packageRecord -Name 'Id')
                }

                $licenseRecord = @(
                    $manifest.Licenses |
                        Where-Object {
                            [string]::Equals(
                                [string](Get-PhoenixOfflineBundleRecordValue -InputObject $_ -Name 'PackageId'),
                                $packageId,
                                [StringComparison]::OrdinalIgnoreCase
                            )
                        }
                ) | Select-Object -First 1

                if ($null -eq $licenseRecord) {
                    if ($requireLicense) {
                        $licenseValid = $false
                        $result.AddError("Package '$packageId' has no license record.")
                    }
                    else {
                        $result.AddWarning("Package '$packageId' has no license record.")
                    }

                    continue
                }

                if ($requireLicense) {
                    [object]$redistributable =
                        Get-PhoenixOfflineBundleRecordValue -InputObject $licenseRecord -Name 'Redistributable'

                    if ($redistributable -isnot [bool] -or -not [bool]$redistributable) {
                        $licenseValid = $false
                        $result.AddError("Package '$packageId' is not explicitly approved for redistribution.")
                    }
                }
            }

            $result.LicenseValid = $licenseValid

            [bool]$trustValid = $true

            if ($Policy -eq 'TrustedPublisher') {
                foreach ($contentObject in $manifest.Objects) {
                    $record = $provenanceByObject[$contentObject.ObjectId]
                    [string]$signatureStatus =
                        [string](Get-PhoenixOfflineBundleRecordValue -InputObject $record -Name 'SignatureStatus')
                    [string]$publisher =
                        [string](Get-PhoenixOfflineBundleRecordValue -InputObject $record -Name 'Publisher')

                    if ($signatureStatus -cne 'Valid' -or [string]::IsNullOrWhiteSpace($publisher)) {
                        $trustValid = $false
                        $result.AddError("Content object '$($contentObject.ObjectId)' does not have a valid trusted-publisher record.")
                    }
                }
            }

            $result.TrustValid = $trustValid
        }
        catch {
            $result.AddError($_.Exception.Message)
        }

        $result.Complete()
        return $result
    }
}
