function Get-PhoenixTheme {

    [CmdletBinding()]
    [OutputType([pscustomobject[]])]
    param(
        [Parameter()]
        [string]$Id
    )

    [string]$projectRoot =
        Split-Path `
            -Path $PSScriptRoot `
            -Parent

    $themeFiles = @(
        Get-ChildItem `
            -LiteralPath (
                Join-Path `
                    $projectRoot `
                    'Themes\BuiltIn'
            ) `
            -Filter '*.json' `
            -File `
            -ErrorAction SilentlyContinue

        Get-ChildItem `
            -LiteralPath (
                Join-Path `
                    $projectRoot `
                    'Themes\Installed'
            ) `
            -Filter 'theme.json' `
            -File `
            -Recurse `
            -ErrorAction SilentlyContinue
    )

    $defaults =
        New-PhoenixUiDefaultConfiguration

    $themes = @(
        foreach ($themeFile in $themeFiles) {
            try {
                $manifest =
                    Get-Content `
                        -LiteralPath $themeFile.FullName `
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
                    continue
                }

                $appearance = [pscustomobject]@{}

                foreach (
                    $propertyName in @(
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
                        'FontFamily'
                        'FontSize'
                        'CornerRadius'
                        'Spacing'
                        'NavigationWidth'
                    )
                ) {
                    $property =
                        $manifest.Appearance.PSObject.Properties[
                            $propertyName
                        ]

                    $value = if ($null -ne $property) {
                        $property.Value
                    }
                    else {
                        $defaults.Appearance.$propertyName
                    }

                    $appearance |
                        Add-Member `
                            -MemberType NoteProperty `
                            -Name $propertyName `
                            -Value $value
                }

                [string]$themeDirectory =
                    $themeFile.Directory.FullName

                foreach (
                    $assetProperty in @(
                        'BackgroundImage'
                        'BrandImage'
                        'FontFile'
                    )
                ) {
                    [string]$assetPath = ''

                    if (
                        $null -ne $manifest.PSObject.Properties[
                            'Assets'
                        ] -and
                        $null -ne
                        $manifest.Assets.PSObject.Properties[
                            $assetProperty
                        ] -and
                        -not [string]::IsNullOrWhiteSpace(
                            [string]$manifest.Assets.$assetProperty
                        )
                    ) {
                        [string]$candidatePath =
                            [IO.Path]::GetFullPath(
                                (
                                    Join-Path `
                                        $themeDirectory `
                                        ([string]$manifest.Assets.$assetProperty)
                                )
                            )

                        [string]$themeRoot =
                            [IO.Path]::GetFullPath(
                                $themeDirectory
                            ).TrimEnd(
                                [IO.Path]::DirectorySeparatorChar
                            ) +
                            [IO.Path]::DirectorySeparatorChar

                        if (
                            $candidatePath.StartsWith(
                                $themeRoot,
                                [StringComparison]::OrdinalIgnoreCase
                            ) -and
                            (
                                Test-Path `
                                    -LiteralPath $candidatePath `
                                    -PathType Leaf
                            )
                        ) {
                            $assetPath = $candidatePath
                        }
                    }

                    $appearance |
                        Add-Member `
                            -MemberType NoteProperty `
                            -Name $assetProperty `
                            -Value $assetPath
                }

                [pscustomobject]@{
                    Id          = [string]$manifest.Id
                    Name        = [string]$manifest.Name
                    Version     = [string]$manifest.Version
                    Author      = [string]$manifest.Author
                    Description = [string]$manifest.Description
                    BuiltIn     = (
                        $themeFile.Directory.Name -eq 'BuiltIn'
                    )
                    Appearance  = $appearance
                    Directory   = $themeDirectory
                    Manifest    = $manifest
                }
            }
            catch {
                Write-Warning (
                    "Theme '$($themeFile.FullName)' was skipped: " +
                    $_.Exception.Message
                )
            }
        }
    )

    if (-not [string]::IsNullOrWhiteSpace($Id)) {
        return @(
            $themes |
                Where-Object {
                    $_.Id -ieq $Id
                }
        )
    }

    return @(
        $themes |
            Sort-Object `
                -Property BuiltIn, Name `
                -Descending
    )
}
