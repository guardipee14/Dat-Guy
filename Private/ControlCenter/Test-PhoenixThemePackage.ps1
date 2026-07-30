function Test-PhoenixThemeIdentifier {

    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Id
    )

    return (
        $Id -match
        '^[a-z0-9][a-z0-9._-]{1,63}$'
    )
}

function Test-PhoenixThemePackage {

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({
            Test-Path -LiteralPath $_ -PathType Leaf
        })]
        [string]$LiteralPath
    )

    Add-Type `
        -AssemblyName System.IO.Compression `
        -ErrorAction Stop

    Add-Type `
        -AssemblyName System.IO.Compression.FileSystem `
        -ErrorAction SilentlyContinue

    $archive =
        [System.IO.Compression.ZipFile]::OpenRead(
            (Resolve-Path -LiteralPath $LiteralPath).Path
        )

    try {
        [long]$totalLength = 0
        [int]$fileCount = 0
        $allowedExtensions = @(
            '.json'
            '.png'
            '.jpg'
            '.jpeg'
            '.bmp'
            '.ico'
            '.ttf'
            '.otf'
        )

        foreach ($entry in $archive.Entries) {
            [string]$entryName =
                $entry.FullName.Replace('\', '/')

            if ($entryName.EndsWith('/')) {
                continue
            }

            $fileCount++
            $totalLength += [long]$entry.Length

            if ($fileCount -gt 128) {
                throw (
                    'Phoenix themes may contain no more than 128 files.'
                )
            }

            if ($entry.Length -gt 8MB) {
                throw (
                    "Theme file '$entryName' exceeds the 8 MB per-file limit."
                )
            }

            if ($totalLength -gt 25MB) {
                throw (
                    'The extracted Phoenix theme may not exceed 25 MB.'
                )
            }

            if (
                [IO.Path]::IsPathRooted($entryName) -or
                @($entryName -split '/') -contains '..'
            ) {
                throw (
                    "Theme file '$entryName' has an unsafe path."
                )
            }

            [string]$extension =
                [IO.Path]::GetExtension(
                    $entryName
                ).ToLowerInvariant()

            if ($extension -notin $allowedExtensions) {
                throw (
                    "Theme file type '$extension' is not allowed. " +
                    'Themes are declarative and cannot contain scripts, ' +
                    'executables, libraries, or XAML.'
                )
            }
        }

        $manifestEntry =
            $archive.Entries |
                Where-Object {
                    $_.FullName.Replace('\', '/') -eq
                        'theme.json'
                } |
                Select-Object -First 1

        if ($null -eq $manifestEntry) {
            throw (
                "The theme package does not contain 'theme.json'."
            )
        }

        $reader =
            [IO.StreamReader]::new(
                $manifestEntry.Open()
            )

        try {
            $manifest =
                $reader.ReadToEnd() |
                    ConvertFrom-Json `
                        -ErrorAction Stop
        }
        finally {
            $reader.Dispose()
        }

        foreach (
            $requiredProperty in @(
                'Id'
                'Name'
                'Version'
                'Appearance'
            )
        ) {
            if (
                $null -eq
                $manifest.PSObject.Properties[
                    $requiredProperty
                ]
            ) {
                throw (
                    "Theme manifest property '$requiredProperty' is required."
                )
            }
        }

        if (
            -not (
                Test-PhoenixThemeIdentifier `
                    -Id ([string]$manifest.Id)
            )
        ) {
            throw (
                "Theme ID '$($manifest.Id)' is invalid."
            )
        }

        foreach (
            $colorProperty in @(
                'Background'
                'Surface'
                'SurfaceAlt'
                'Card'
                'Border'
                'Text'
                'MutedText'
                'Accent'
                'AccentHover'
                'Success'
                'Warning'
                'Danger'
            )
        ) {
            $property =
                $manifest.Appearance.PSObject.Properties[
                    $colorProperty
                ]

            if (
                $null -eq $property -or
                [string]$property.Value -notmatch
                    '^#[0-9A-Fa-f]{6}$|^#[0-9A-Fa-f]{8}$'
            ) {
                throw (
                    "Theme color '$colorProperty' must be a six- or " +
                    'eight-digit hexadecimal color.'
                )
            }
        }

        return [pscustomobject]@{
            Valid             = $true
            Manifest          = $manifest
            FileCount         = $fileCount
            UncompressedBytes = $totalLength
        }
    }
    finally {
        $archive.Dispose()
    }
}
