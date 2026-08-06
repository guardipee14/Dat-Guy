function Read-PhoenixOfflineBundleManifest {

    [CmdletBinding()]
    [OutputType([PhoenixOfflineBundleManifest])]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [Alias(
            'Path',
            'FullName'
        )]
        [ValidateNotNullOrEmpty()]
        [string]$LiteralPath
    )

    process {
        if (
            -not (
                Test-Path `
                    -LiteralPath $LiteralPath `
                    -PathType Leaf
            )
        ) {
            throw (
                'Offline-bundle manifest was not found: ' +
                $LiteralPath
            )
        }

        [string]$resolvedPath =
            (
                Resolve-Path `
                    -LiteralPath $LiteralPath `
                    -ErrorAction Stop
            ).Path

        [IO.FileInfo]$manifestFile =
            Get-Item `
                -LiteralPath $resolvedPath `
                -Force `
                -ErrorAction Stop

        if (
            (
                $manifestFile.Attributes -band
                    [IO.FileAttributes]::ReparsePoint
            ) -ne 0
        ) {
            throw (
                'The offline-bundle manifest cannot be a ' +
                "reparse point: $resolvedPath"
            )
        }

        try {
            $rawManifest =
                Get-Content `
                    -LiteralPath $resolvedPath `
                    -Raw `
                    -ErrorAction Stop |
                    ConvertFrom-Json `
                        -ErrorAction Stop
        }
        catch {
            throw (
                'Failed to parse the offline-bundle manifest: ' +
                $_.Exception.Message
            )
        }

        if ($null -eq $rawManifest) {
            throw 'The offline-bundle manifest is empty.'
        }

        [string[]]$requiredProperties =
            @(
                'Schema'
                'SchemaVersion'
                'ContentStoreVersion'
                'BundleId'
                'Name'
                'Description'
                'CreatedAtUtc'
                'UpdatedAtUtc'
                'Phoenix'
                'Windows'
                'Hardware'
                'Providers'
                'Sources'
                'Packages'
                'Drivers'
                'Dependencies'
                'Licenses'
                'Provenance'
                'Objects'
                'ObjectCount'
                'TotalBytes'
            )

        [string[]]$actualPropertyNames =
            @(
                $rawManifest.PSObject.Properties.Name
            )

        foreach ($requiredProperty in $requiredProperties) {
            if (
                -not (
                    $actualPropertyNames -ccontains
                        $requiredProperty
                )
            ) {
                throw (
                    'The offline-bundle manifest is missing ' +
                    "required property: $requiredProperty"
                )
            }
        }

        if (
            [string]$rawManifest.Schema -cne
                'PhoenixOfflineBundleManifest'
        ) {
            throw (
                'Unsupported offline-bundle manifest schema: ' +
                [string]$rawManifest.Schema
            )
        }

        if (
            [string]$rawManifest.SchemaVersion -cne
                '1.0'
        ) {
            throw (
                'Unsupported offline-bundle manifest version: ' +
                [string]$rawManifest.SchemaVersion
            )
        }

        if (
            [string]$rawManifest.ContentStoreVersion -cne
                '1.0'
        ) {
            throw (
                'Unsupported Phoenix content-store version: ' +
                [string]$rawManifest.ContentStoreVersion
            )
        }

        [guid]$bundleGuid =
            [guid]::Empty

        if (
            -not [guid]::TryParse(
                [string]$rawManifest.BundleId,
                [ref]$bundleGuid
            )
        ) {
            throw (
                'Offline-bundle manifest BundleId must be a GUID.'
            )
        }

        try {
            [datetimeoffset]$createdAt =
                [datetimeoffset]$rawManifest.CreatedAtUtc

            [datetimeoffset]$updatedAt =
                [datetimeoffset]$rawManifest.UpdatedAtUtc
        }
        catch {
            throw (
                'Offline-bundle manifest timestamps are invalid.'
            )
        }

        [string[]]$collectionNames =
            @(
                'Providers'
                'Sources'
                'Packages'
                'Drivers'
                'Dependencies'
                'Licenses'
                'Provenance'
                'Objects'
            )

        foreach ($collectionName in $collectionNames) {
            if (
                $null -eq
                    $rawManifest.$collectionName
            ) {
                throw (
                    'Offline-bundle manifest collection cannot ' +
                    "be null: $collectionName"
                )
            }
        }

        $manifest =
            [PhoenixOfflineBundleManifest]::new()

        $manifest.Schema =
            [string]$rawManifest.Schema

        $manifest.SchemaVersion =
            [string]$rawManifest.SchemaVersion

        $manifest.ContentStoreVersion =
            [string]$rawManifest.ContentStoreVersion

        $manifest.BundleId =
            [string]$rawManifest.BundleId

        $manifest.Name =
            [string]$rawManifest.Name

        $manifest.Description =
            [string]$rawManifest.Description

        $manifest.Phoenix =
            $rawManifest.Phoenix

        $manifest.Windows =
            $rawManifest.Windows

        $manifest.Hardware =
            $rawManifest.Hardware

        $manifest.Providers =
            [object[]]@(
                $rawManifest.Providers
            )

        $manifest.Sources =
            [object[]]@(
                $rawManifest.Sources
            )

        $manifest.Packages =
            [object[]]@(
                $rawManifest.Packages
            )

        $manifest.Drivers =
            [object[]]@(
                $rawManifest.Drivers
            )

        $manifest.Dependencies =
            [object[]]@(
                $rawManifest.Dependencies
            )

        $manifest.Licenses =
            [object[]]@(
                $rawManifest.Licenses
            )

        $manifest.Provenance =
            [object[]]@(
                $rawManifest.Provenance
            )

        $objectIds =
            [Collections.Generic.HashSet[string]]::new(
                [StringComparer]::Ordinal
            )

        foreach (
            $rawObject in
                @($rawManifest.Objects)
        ) {
            if ($null -eq $rawObject) {
                throw (
                    'Offline-bundle manifest contains a null ' +
                    'content-object record.'
                )
            }

            [string[]]$requiredObjectProperties =
                @(
                    'ObjectId'
                    'Algorithm'
                    'Digest'
                    'RelativePath'
                    'Length'
                )

            [string[]]$objectPropertyNames =
                @(
                    $rawObject.PSObject.Properties.Name
                )

            foreach (
                $requiredObjectProperty in
                    $requiredObjectProperties
            ) {
                if (
                    -not (
                        $objectPropertyNames -ccontains
                            $requiredObjectProperty
                    )
                ) {
                    throw (
                        'Content-object record is missing ' +
                        "required property: " +
                        $requiredObjectProperty
                    )
                }
            }

            $address =
                [PhoenixContentAddress]::new(
                    [string]$rawObject.Digest
                )

            if (
                [string]$rawObject.Algorithm -cne
                    $address.Algorithm -or
                [string]$rawObject.Digest -cne
                    $address.Digest -or
                [string]$rawObject.ObjectId -cne
                    $address.ObjectId -or
                [string]$rawObject.RelativePath -cne
                    $address.RelativePath
            ) {
                throw (
                    'Content-object record is not in canonical ' +
                    'content-addressed form.'
                )
            }

            [long]$objectLength =
                0

            try {
                $objectLength =
                    [Convert]::ToInt64(
                        $rawObject.Length,
                        [Globalization.CultureInfo]::InvariantCulture
                    )
            }
            catch {
                throw (
                    'Content-object Length must be a valid ' +
                    '64-bit integer.'
                )
            }

            $contentObject =
                [PhoenixContentObject]::new(
                    $address,
                    $objectLength
                )

            if (
                -not $objectIds.Add(
                    $contentObject.ObjectId
                )
            ) {
                throw (
                    'Offline-bundle manifest contains duplicate ' +
                    "content object: $($contentObject.ObjectId)"
                )
            }

            $manifest.AddObject(
                $contentObject
            )
        }

        [int]$declaredObjectCount =
            0

        [long]$declaredTotalBytes =
            0

        try {
            $declaredObjectCount =
                [Convert]::ToInt32(
                    $rawManifest.ObjectCount,
                    [Globalization.CultureInfo]::InvariantCulture
                )

            $declaredTotalBytes =
                [Convert]::ToInt64(
                    $rawManifest.TotalBytes,
                    [Globalization.CultureInfo]::InvariantCulture
                )
        }
        catch {
            throw (
                'Offline-bundle manifest summary values are invalid.'
            )
        }

        if (
            $declaredObjectCount -ne
                $manifest.ObjectCount -or
            $declaredTotalBytes -ne
                $manifest.TotalBytes
        ) {
            throw (
                'Offline-bundle manifest summary does not match ' +
                'its content-object records.'
            )
        }

        $manifest.CreatedAtUtc =
            $createdAt.UtcDateTime

        $manifest.UpdatedAtUtc =
            $updatedAt.UtcDateTime

        if (-not $manifest.IsValid()) {
            throw (
                'The reconstructed Phoenix offline-bundle ' +
                'manifest is invalid.'
            )
        }

        return $manifest
    }
}