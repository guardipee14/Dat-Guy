function Save-PhoenixOfflineBundleManifest {

    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'Medium'
    )]
    [OutputType([string])]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline
        )]
        [PhoenixOfflineBundleManifest]$Manifest,

        [Parameter(Mandatory)]
        [Alias('Path')]
        [ValidateNotNullOrEmpty()]
        [string]$LiteralPath
    )

    process {
        if ($null -eq $Manifest) {
            throw 'A Phoenix offline-bundle manifest is required.'
        }

        if (-not $Manifest.IsValid()) {
            throw 'The Phoenix offline-bundle manifest is invalid.'
        }

        [string]$resolvedPath =
            if (
                [IO.Path]::IsPathRooted(
                    $LiteralPath
                )
            ) {
                [IO.Path]::GetFullPath(
                    $LiteralPath
                )
            }
            else {
                [IO.Path]::GetFullPath(
                    (
                        Join-Path `
                            -Path (Get-Location).Path `
                            -ChildPath $LiteralPath
                    )
                )
            }

        if (
            Test-Path `
                -LiteralPath $resolvedPath
        ) {
            $existingItem =
                Get-Item `
                    -LiteralPath $resolvedPath `
                    -Force `
                    -ErrorAction Stop

            if (
                $existingItem -isnot
                    [IO.FileInfo]
            ) {
                throw (
                    'The manifest destination is not a file: ' +
                    $resolvedPath
                )
            }

            if (
                (
                    $existingItem.Attributes -band
                        [IO.FileAttributes]::ReparsePoint
                ) -ne 0
            ) {
                throw (
                    'The manifest destination cannot be a ' +
                    "reparse point: $resolvedPath"
                )
            }
        }

        if (
            -not $PSCmdlet.ShouldProcess(
                $resolvedPath,
                (
                    'Save Phoenix offline-bundle manifest {0}' -f
                    $Manifest.BundleId
                )
            )
        ) {
            return $resolvedPath
        }

        [string]$parentPath =
            Split-Path `
                -Path $resolvedPath `
                -Parent

        if (
            Test-Path `
                -LiteralPath $parentPath
        ) {
            $parentItem =
                Get-Item `
                    -LiteralPath $parentPath `
                    -Force `
                    -ErrorAction Stop

            if (
                $parentItem -isnot
                    [IO.DirectoryInfo]
            ) {
                throw (
                    'The manifest parent path is not a ' +
                    "directory: $parentPath"
                )
            }

            if (
                (
                    $parentItem.Attributes -band
                        [IO.FileAttributes]::ReparsePoint
                ) -ne 0
            ) {
                throw (
                    'The manifest parent directory cannot be a ' +
                    "reparse point: $parentPath"
                )
            }
        }
        else {
            $null =
                New-Item `
                    -ItemType Directory `
                    -Path $parentPath `
                    -Force `
                    -ErrorAction Stop
        }

        [string]$leafName =
            Split-Path `
                -Path $resolvedPath `
                -Leaf

        [string]$temporaryPath =
            Join-Path `
                -Path $parentPath `
                -ChildPath (
                    '.{0}.{1}.tmp' -f
                    $leafName,
                    [guid]::NewGuid().ToString('N')
                )

        try {
            [string]$json =
                $Manifest |
                    ConvertTo-Json `
                        -Depth 50 `
                        -ErrorAction Stop

            [IO.File]::WriteAllText(
                $temporaryPath,
                $json,
                [Text.UTF8Encoding]::new($false)
            )

            $stagedManifest =
                Get-Content `
                    -LiteralPath $temporaryPath `
                    -Raw `
                    -ErrorAction Stop |
                    ConvertFrom-Json `
                        -ErrorAction Stop

            if (
                [string]$stagedManifest.Schema -cne
                    $Manifest.Schema -or
                [string]$stagedManifest.SchemaVersion -cne
                    $Manifest.SchemaVersion -or
                [string]$stagedManifest.ContentStoreVersion -cne
                    $Manifest.ContentStoreVersion -or
                [string]$stagedManifest.BundleId -cne
                    $Manifest.BundleId
            ) {
                throw (
                    'The staged offline-bundle manifest failed ' +
                    'identity validation.'
                )
            }

            Move-Item `
                -LiteralPath $temporaryPath `
                -Destination $resolvedPath `
                -Force `
                -ErrorAction Stop

            if (
                -not (
                    Test-Path `
                        -LiteralPath $resolvedPath `
                        -PathType Leaf
                )
            ) {
                throw (
                    'The offline-bundle manifest was not ' +
                    "published: $resolvedPath"
                )
            }

            return $resolvedPath
        }
        finally {
            Remove-Item `
                -LiteralPath $temporaryPath `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }
}