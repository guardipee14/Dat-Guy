function Get-PhoenixContentObjectFromFile {

    [CmdletBinding()]
    [OutputType([PhoenixContentObject])]
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
                "Content source file was not found: " +
                $LiteralPath
            )
        }

        [string]$resolvedPath =
            (
                Resolve-Path `
                    -LiteralPath $LiteralPath `
                    -ErrorAction Stop
            ).Path

        $sourceItem =
            Get-Item `
                -LiteralPath $resolvedPath `
                -Force `
                -ErrorAction Stop

        if (
            $sourceItem -isnot
                [IO.FileInfo]
        ) {
            throw (
                "Content source is not a filesystem file: " +
                $resolvedPath
            )
        }

        [IO.FileInfo]$sourceFile =
            $sourceItem

        if (
            (
                $sourceFile.Attributes -band
                    [IO.FileAttributes]::ReparsePoint
            ) -ne 0
        ) {
            throw (
                "Content source cannot be a reparse point: " +
                $resolvedPath
            )
        }

        [IO.FileStream]$sourceStream =
            $null

        [Security.Cryptography.SHA256]$sha256 =
            $null

        [long]$length =
            0

        [string]$digest =
            ''

        try {
            $sourceStream =
                [IO.File]::Open(
                    $resolvedPath,
                    [IO.FileMode]::Open,
                    [IO.FileAccess]::Read,
                    [IO.FileShare]::Read
                )

            $length =
                $sourceStream.Length

            $sha256 =
                [Security.Cryptography.SHA256]::Create()

            [byte[]]$digestBytes =
                $sha256.ComputeHash(
                    $sourceStream
                )

            $digest =
                [Convert]::ToHexString(
                    $digestBytes
                ).ToLowerInvariant()
        }
        finally {
            if ($null -ne $sha256) {
                $sha256.Dispose()
            }

            if ($null -ne $sourceStream) {
                $sourceStream.Dispose()
            }
        }

        $address =
            [PhoenixContentAddress]::new(
                $digest
            )

        $contentObject =
            [PhoenixContentObject]::new(
                $address,
                $length
            )

        if (-not $contentObject.IsValid()) {
            throw (
                "Failed to create a valid Phoenix content " +
                "object for: $resolvedPath"
            )
        }

        return $contentObject
    }
}