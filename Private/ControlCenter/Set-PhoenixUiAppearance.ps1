function ConvertTo-PhoenixUiBrush {

    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern(
            '^#[0-9A-Fa-f]{6}$|^#[0-9A-Fa-f]{8}$'
        )]
        [string]$Color
    )

    $converter =
        [System.Windows.Media.BrushConverter]::new()

    return (
        $converter.ConvertFromString($Color)
    )
}

function Set-PhoenixUiAppearance {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]$Window,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]$Appearance
    )

    $brushResources = [ordered]@{
        PhoenixBackgroundBrush = $Appearance.Background
        PhoenixSurfaceBrush    = $Appearance.Surface
        PhoenixSurfaceAltBrush = $Appearance.SurfaceAlt
        PhoenixCardBrush       = $Appearance.Card
        PhoenixBorderBrush     = $Appearance.Border
        PhoenixTextBrush       = $Appearance.Text
        PhoenixMutedBrush      = $Appearance.MutedText
        PhoenixAccentBrush     = $Appearance.Accent
        PhoenixAccentHoverBrush = $Appearance.AccentHover
        PhoenixSuccessBrush    = $Appearance.Success
        PhoenixWarningBrush    = $Appearance.Warning
        PhoenixDangerBrush     = $Appearance.Danger
    }

    foreach ($resourceName in $brushResources.Keys) {
        $Window.Resources[$resourceName] =
            ConvertTo-PhoenixUiBrush `
                -Color $brushResources[$resourceName]
    }

    $fontFamily = $null

    if (
        $null -ne $Appearance.PSObject.Properties[
            'FontFile'
        ] -and
        -not [string]::IsNullOrWhiteSpace(
            [string]$Appearance.FontFile
        ) -and
        (
            Test-Path `
                -LiteralPath ([string]$Appearance.FontFile) `
                -PathType Leaf
        )
    ) {
        try {
            [string]$fontDirectory =
                Split-Path `
                    -Path ([string]$Appearance.FontFile) `
                    -Parent

            $fontBaseUri =
                [uri]::new(
                    (
                        $fontDirectory.TrimEnd(
                            [IO.Path]::DirectorySeparatorChar
                        ) +
                        [IO.Path]::DirectorySeparatorChar
                    )
                )

            $fontFamily =
                [System.Windows.Media.FontFamily]::new(
                    $fontBaseUri,
                    (
                        './#{0}' -f
                        [string]$Appearance.FontFamily
                    )
                )
        }
        catch {
            $fontFamily = $null
        }
    }

    if ($null -eq $fontFamily) {
        $fontFamily =
            [System.Windows.Media.FontFamily]::new(
                [string]$Appearance.FontFamily
            )
    }

    $Window.FontFamily = $fontFamily
    $Window.FontSize = [double]$Appearance.FontSize

    $Window.Resources['PhoenixCornerRadius'] =
        [System.Windows.CornerRadius]::new(
            [double]$Appearance.CornerRadius
        )

    $Window.Resources['PhoenixSpacing'] =
        [System.Windows.Thickness]::new(
            [double]$Appearance.Spacing
        )

    foreach (
        $imageDefinition in @(
            [pscustomobject]@{
                PropertyName = 'BackgroundImage'
                ControlName  = 'ThemeBackgroundImage'
            }
            [pscustomobject]@{
                PropertyName = 'BrandImage'
                ControlName  = 'BrandLogoImage'
            }
        )
    ) {
        $imageControl =
            $Window.FindName(
                $imageDefinition.ControlName
            )

        if ($null -eq $imageControl) {
            continue
        }

        [string]$imagePath = ''

        if (
            $null -ne $Appearance.PSObject.Properties[
                $imageDefinition.PropertyName
            ]
        ) {
            $imagePath = [string](
                $Appearance.PSObject.Properties[
                    $imageDefinition.PropertyName
                ].Value
            )
        }

        if (
            -not [string]::IsNullOrWhiteSpace($imagePath) -and
            (
                Test-Path `
                    -LiteralPath $imagePath `
                    -PathType Leaf
            )
        ) {
            $bitmap =
                [System.Windows.Media.Imaging.BitmapImage]::new()

            $bitmap.BeginInit()
            $bitmap.CacheOption =
                [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad

            $bitmap.UriSource =
                [uri]::new(
                    (Resolve-Path -LiteralPath $imagePath).Path
                )

            $bitmap.EndInit()
            $bitmap.Freeze()

            $imageControl.Source = $bitmap
            $imageControl.Visibility =
                [System.Windows.Visibility]::Visible
        }
        else {
            $imageControl.Source = $null
            $imageControl.Visibility =
                [System.Windows.Visibility]::Collapsed
        }
    }

    $brandLetter =
        $Window.FindName(
            'BrandLetterText'
        )

    $brandImage =
        $Window.FindName(
            'BrandLogoImage'
        )

    if (
        $null -ne $brandLetter -and
        $null -ne $brandImage
    ) {
        $brandLetter.Visibility = if (
            $brandImage.Visibility -eq
            [System.Windows.Visibility]::Visible
        ) {
            [System.Windows.Visibility]::Collapsed
        }
        else {
            [System.Windows.Visibility]::Visible
        }
    }
}
