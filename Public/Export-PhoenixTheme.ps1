function Export-PhoenixTheme {

    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'Medium'
    )]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({
            Test-Path -LiteralPath $_ -PathType Container
        })]
        [string]$ThemeDirectory,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationPath
    )

    [string]$resolvedThemeDirectory =
        (Resolve-Path -LiteralPath $ThemeDirectory).Path

    [string]$manifestPath =
        Join-Path `
            $resolvedThemeDirectory `
            'theme.json'

    if (-not (Test-Path -LiteralPath $manifestPath)) {
        throw (
            "Theme source '$resolvedThemeDirectory' does not contain theme.json."
        )
    }

    $manifest =
        Get-Content `
            -LiteralPath $manifestPath `
            -Raw `
            -ErrorAction Stop |
            ConvertFrom-Json `
                -ErrorAction Stop

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

    $files = @(
        Get-ChildItem `
            -LiteralPath $resolvedThemeDirectory `
            -File `
            -Recurse
    )

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

    if ($files.Count -gt 128) {
        throw 'Phoenix themes may contain no more than 128 files.'
    }

    [long]$totalLength = 0

    foreach ($file in $files) {
        $totalLength += [long]$file.Length

        if ($file.Length -gt 8MB) {
            throw (
                "Theme file '$($file.Name)' exceeds the 8 MB per-file limit."
            )
        }

        if (
            $file.Extension.ToLowerInvariant() -notin
            $allowedExtensions
        ) {
            throw (
                "Theme file type '$($file.Extension)' is not allowed."
            )
        }
    }

    if ($totalLength -gt 25MB) {
        throw (
            'The extracted Phoenix theme may not exceed 25 MB.'
        )
    }

    [string]$resolvedDestination =
        [IO.Path]::GetFullPath(
            $DestinationPath
        )

    if (
        [IO.Path]::GetExtension($resolvedDestination) -ine
        '.phxtheme'
    ) {
        $resolvedDestination += '.phxtheme'
    }

    if (
        -not $PSCmdlet.ShouldProcess(
            $resolvedDestination,
            "Export Phoenix theme '$($manifest.Id)'"
        )
    ) {
        return [pscustomobject]@{
            Success = $true
            Applied = $false
            Path    = $resolvedDestination
        }
    }

    [string]$destinationDirectory =
        Split-Path `
            -Path $resolvedDestination `
            -Parent

    if (
        -not [string]::IsNullOrWhiteSpace(
            $destinationDirectory
        )
    ) {
        New-Item `
            -ItemType Directory `
            -Path $destinationDirectory `
            -Force |
            Out-Null
    }

    if (Test-Path -LiteralPath $resolvedDestination) {
        Remove-Item `
            -LiteralPath $resolvedDestination `
            -Force `
            -ErrorAction Stop
    }

    Add-Type `
        -AssemblyName System.IO.Compression.FileSystem `
        -ErrorAction SilentlyContinue

    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        $resolvedThemeDirectory,
        $resolvedDestination,
        [System.IO.Compression.CompressionLevel]::Optimal,
        $false
    )

    return [pscustomobject]@{
        Success           = $true
        Applied           = $true
        Id                = [string]$manifest.Id
        Path              = $resolvedDestination
        FileCount         = $files.Count
        UncompressedBytes = $totalLength
    }
}
