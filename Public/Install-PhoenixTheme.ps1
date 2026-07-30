function Install-PhoenixTheme {

    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'Medium'
    )]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateScript({
            Test-Path -LiteralPath $_ -PathType Leaf
        })]
        [string]$LiteralPath
    )

    $validation =
        Test-PhoenixThemePackage `
            -LiteralPath $LiteralPath

    [string]$themeId =
        [string]$validation.Manifest.Id

    if (
        @(
            Get-PhoenixTheme |
                Where-Object {
                    $_.BuiltIn -and
                    $_.Id -ieq $themeId
                }
        ).Count -gt 0
    ) {
        throw (
            "The built-in theme ID '$themeId' cannot be replaced."
        )
    }

    [string]$projectRoot =
        Split-Path `
            -Path $PSScriptRoot `
            -Parent

    [string]$installedRoot =
        Join-Path `
            $projectRoot `
            'Themes\Installed'

    [string]$destinationPath =
        Join-Path `
            $installedRoot `
            $themeId

    if (
        -not $PSCmdlet.ShouldProcess(
            $destinationPath,
            "Install Phoenix theme '$themeId'"
        )
    ) {
        return [pscustomobject]@{
            Success = $true
            Applied = $false
            Id      = $themeId
            Path    = $destinationPath
        }
    }

    New-Item `
        -ItemType Directory `
        -Path $installedRoot `
        -Force |
        Out-Null

    [string]$stagingPath =
        Join-Path `
            ([IO.Path]::GetTempPath()) `
            (
                'PhoenixTheme-{0}' -f
                [guid]::NewGuid().ToString('N')
            )

    [string]$backupPath = (
        '{0}.backup-{1}' -f
        $destinationPath,
        [guid]::NewGuid().ToString('N')
    )

    New-Item `
        -ItemType Directory `
        -Path $stagingPath `
        -Force |
        Out-Null

    try {
        $archive =
            [System.IO.Compression.ZipFile]::OpenRead(
                (Resolve-Path -LiteralPath $LiteralPath).Path
            )

        try {
            [string]$stagingRoot =
                [IO.Path]::GetFullPath(
                    $stagingPath
                ).TrimEnd(
                    [IO.Path]::DirectorySeparatorChar
                ) +
                [IO.Path]::DirectorySeparatorChar

            foreach ($entry in $archive.Entries) {
                [string]$entryName =
                    $entry.FullName.Replace(
                        '/',
                        [IO.Path]::DirectorySeparatorChar
                    )

                if (
                    [string]::IsNullOrWhiteSpace(
                        [IO.Path]::GetFileName($entryName)
                    )
                ) {
                    continue
                }

                [string]$entryDestination =
                    [IO.Path]::GetFullPath(
                        (
                            Join-Path `
                                $stagingPath `
                                $entryName
                        )
                    )

                if (
                    -not $entryDestination.StartsWith(
                        $stagingRoot,
                        [StringComparison]::OrdinalIgnoreCase
                    )
                ) {
                    throw (
                        "Theme file '$entryName' escapes the installation directory."
                    )
                }

                [string]$entryDirectory =
                    Split-Path `
                        -Path $entryDestination `
                        -Parent

                New-Item `
                    -ItemType Directory `
                    -Path $entryDirectory `
                    -Force |
                    Out-Null

                $inputStream = $entry.Open()

                try {
                    $outputStream =
                        [IO.File]::Create(
                            $entryDestination
                        )

                    try {
                        $inputStream.CopyTo(
                            $outputStream
                        )
                    }
                    finally {
                        $outputStream.Dispose()
                    }
                }
                finally {
                    $inputStream.Dispose()
                }
            }
        }
        finally {
            $archive.Dispose()
        }

        if (Test-Path -LiteralPath $destinationPath) {
            Move-Item `
                -LiteralPath $destinationPath `
                -Destination $backupPath `
                -ErrorAction Stop
        }

        Move-Item `
            -LiteralPath $stagingPath `
            -Destination $destinationPath `
            -ErrorAction Stop

        if (Test-Path -LiteralPath $backupPath) {
            Remove-Item `
                -LiteralPath $backupPath `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }
    catch {
        if (
            -not (Test-Path -LiteralPath $destinationPath) -and
            (Test-Path -LiteralPath $backupPath)
        ) {
            Move-Item `
                -LiteralPath $backupPath `
                -Destination $destinationPath `
                -ErrorAction SilentlyContinue
        }

        throw
    }
    finally {
        if (Test-Path -LiteralPath $stagingPath) {
            Remove-Item `
                -LiteralPath $stagingPath `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }

    return [pscustomobject]@{
        Success           = $true
        Applied           = $true
        Id                = $themeId
        Name              = [string]$validation.Manifest.Name
        Path              = $destinationPath
        FileCount         = $validation.FileCount
        UncompressedBytes = $validation.UncompressedBytes
    }
}
