function Add-PhoenixContentStoreObject {

    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'Medium'
    )]
    [OutputType([PhoenixContentObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$StoreRoot,

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
        [string]$resolvedSourcePath =
            (
                Resolve-Path `
                    -LiteralPath $LiteralPath `
                    -ErrorAction Stop
            ).Path

        $contentObject =
            Get-PhoenixContentObjectFromFile `
                -LiteralPath $resolvedSourcePath

        $address =
            [PhoenixContentAddress]::new(
                $contentObject.Digest
            )

        [string]$objectPath =
            Resolve-PhoenixContentStoreObjectPath `
                -StoreRoot $StoreRoot `
                -Address $address

        if (
            Test-Path `
                -LiteralPath $objectPath
        ) {
            if (
                Test-PhoenixContentStoreObject `
                    -StoreRoot $StoreRoot `
                    -ContentObject $contentObject
            ) {
                return $contentObject
            }

            throw (
                'An existing content-store object failed ' +
                "verification: $objectPath"
            )
        }

        if (
            -not $PSCmdlet.ShouldProcess(
                $objectPath,
                (
                    'Add Phoenix content object {0}' -f
                    $contentObject.ObjectId
                )
            )
        ) {
            return $contentObject
        }

        [string]$resolvedRoot =
            [IO.Path]::GetFullPath(
                $StoreRoot
            )

        if (
            Test-Path `
                -LiteralPath $resolvedRoot
        ) {
            $rootItem =
                Get-Item `
                    -LiteralPath $resolvedRoot `
                    -Force `
                    -ErrorAction Stop

            if (
                $rootItem -isnot
                    [IO.DirectoryInfo]
            ) {
                throw (
                    'The content-store root is not a ' +
                    "directory: $resolvedRoot"
                )
            }

            if (
                (
                    $rootItem.Attributes -band
                        [IO.FileAttributes]::ReparsePoint
                ) -ne 0
            ) {
                throw (
                    'The content-store root cannot be a ' +
                    "reparse point: $resolvedRoot"
                )
            }
        }
        else {
            $null =
                New-Item `
                    -ItemType Directory `
                    -Path $resolvedRoot `
                    -Force `
                    -ErrorAction Stop
        }

        [int]$lastSeparator =
            $address.RelativePath.LastIndexOf(
                [char]'/'
            )

        if ($lastSeparator -le 0) {
            throw (
                'The content address does not contain a ' +
                'valid parent directory.'
            )
        }

        [string]$relativeDirectory =
            $address.RelativePath.Substring(
                0,
                $lastSeparator
            )

        [string[]]$directorySegments =
            @(
                $relativeDirectory -split '/'
            )

        [string]$currentDirectory =
            $resolvedRoot

        foreach ($segment in $directorySegments) {
            if (
                [string]::IsNullOrWhiteSpace(
                    $segment
                ) -or
                $segment -eq '.' -or
                $segment -eq '..'
            ) {
                throw (
                    'The content address contains an invalid ' +
                    "directory segment: $segment"
                )
            }

            [string]$nextDirectory =
                Join-Path `
                    -Path $currentDirectory `
                    -ChildPath $segment

            if (
                Test-Path `
                    -LiteralPath $nextDirectory
            ) {
                $directoryItem =
                    Get-Item `
                        -LiteralPath $nextDirectory `
                        -Force `
                        -ErrorAction Stop

                if (
                    $directoryItem -isnot
                        [IO.DirectoryInfo]
                ) {
                    throw (
                        'A content-store path component is not ' +
                        "a directory: $nextDirectory"
                    )
                }

                if (
                    (
                        $directoryItem.Attributes -band
                            [IO.FileAttributes]::ReparsePoint
                    ) -ne 0
                ) {
                    throw (
                        'A content-store path component cannot ' +
                        "be a reparse point: $nextDirectory"
                    )
                }
            }
            else {
                $null =
                    New-Item `
                        -ItemType Directory `
                        -Path $nextDirectory `
                        -ErrorAction Stop
            }

            $currentDirectory =
                $nextDirectory
        }

        [string]$objectParent =
            Split-Path `
                -Path $objectPath `
                -Parent

        if (
            -not (
                [IO.Path]::GetFullPath(
                    $currentDirectory
                )
            ).Equals(
                [IO.Path]::GetFullPath(
                    $objectParent
                ),
                [StringComparison]::OrdinalIgnoreCase
            )
        ) {
            throw (
                'The resolved content-store directory does not ' +
                'match the canonical object path.'
            )
        }

        [string]$objectLeaf =
            Split-Path `
                -Path $objectPath `
                -Leaf

        [string]$temporaryPath =
            Join-Path `
                -Path $objectParent `
                -ChildPath (
                    '.{0}.{1}.tmp' -f
                    $objectLeaf,
                    [guid]::NewGuid().ToString('N')
                )

        try {
            Copy-Item `
                -LiteralPath $resolvedSourcePath `
                -Destination $temporaryPath `
                -ErrorAction Stop

            $stagedObject =
                Get-PhoenixContentObjectFromFile `
                    -LiteralPath $temporaryPath

            if (
                $stagedObject.ObjectId -cne
                    $contentObject.ObjectId -or
                $stagedObject.Length -ne
                    $contentObject.Length
            ) {
                throw (
                    'The source file changed while the content ' +
                    'object was being staged.'
                )
            }

            if (
                Test-Path `
                    -LiteralPath $objectPath
            ) {
                if (
                    Test-PhoenixContentStoreObject `
                        -StoreRoot $StoreRoot `
                        -ContentObject $contentObject
                ) {
                    return $contentObject
                }

                throw (
                    'A conflicting content-store object appeared ' +
                    "while staging: $objectPath"
                )
            }

            try {
                Move-Item `
                    -LiteralPath $temporaryPath `
                    -Destination $objectPath `
                    -ErrorAction Stop
            }
            catch {
                if (
                    (
                        Test-Path `
                            -LiteralPath $objectPath `
                            -PathType Leaf
                    ) -and
                    (
                        Test-PhoenixContentStoreObject `
                            -StoreRoot $StoreRoot `
                            -ContentObject $contentObject
                    )
                ) {
                    return $contentObject
                }

                throw
            }

            if (
                -not (
                    Test-PhoenixContentStoreObject `
                        -StoreRoot $StoreRoot `
                        -ContentObject $contentObject
                )
            ) {
                throw (
                    'The published content-store object failed ' +
                    "verification: $objectPath"
                )
            }

            return $contentObject
        }
        finally {
            Remove-Item `
                -LiteralPath $temporaryPath `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }
}