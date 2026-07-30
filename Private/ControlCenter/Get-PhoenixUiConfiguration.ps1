function Get-PhoenixUiConfigurationPath {

    [CmdletBinding()]
    [OutputType([string])]
    param()

    [string]$projectRoot =
        Split-Path `
            -Path (
                Split-Path `
                    -Path $PSScriptRoot `
                    -Parent
            ) `
            -Parent

    return (
        Join-Path `
            $projectRoot `
            'Config\Phoenix.UI.json'
    )
}

function New-PhoenixUiDefaultConfiguration {

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    return [pscustomobject]@{
        SchemaVersion = '2.0'
        ThemeId       = 'phoenix-dark'
        Appearance    = [pscustomobject]@{
            Background   = '#0B1220'
            Surface      = '#111B2E'
            SurfaceAlt   = '#18243A'
            Card         = '#142035'
            Border       = '#2A3A55'
            Text         = '#F5F7FB'
            MutedText    = '#9FB0C9'
            Accent       = '#2F80ED'
            AccentHover  = '#4C95F5'
            Success      = '#22A06B'
            Warning      = '#D99A2B'
            Danger       = '#D64545'
            FontFamily   = 'Segoe UI'
            FontSize     = 13.0
            CornerRadius = 10.0
            Spacing      = 12.0
            NavigationWidth = 220.0
            BackgroundImage = ''
            BrandImage      = ''
            FontFile        = ''
        }
        Window        = [pscustomobject]@{
            Width     = 1320.0
            Height    = 860.0
            Maximized = $false
        }
        Dashboard     = [pscustomobject]@{
            CanvasWidth  = 1160.0
            CanvasHeight = 720.0
            SnapSize     = 10.0
            Tiles        = @(
                [pscustomobject]@{
                    Id      = 'System'
                    X       = 0.0
                    Y       = 0.0
                    Width   = 550.0
                    Height  = 260.0
                    Visible = $true
                }
                [pscustomobject]@{
                    Id      = 'Inventory'
                    X       = 570.0
                    Y       = 0.0
                    Width   = 280.0
                    Height  = 260.0
                    Visible = $true
                }
                [pscustomobject]@{
                    Id      = 'QuickActions'
                    X       = 870.0
                    Y       = 0.0
                    Width   = 290.0
                    Height  = 260.0
                    Visible = $true
                }
                [pscustomobject]@{
                    Id      = 'Providers'
                    X       = 0.0
                    Y       = 280.0
                    Width   = 760.0
                    Height  = 410.0
                    Visible = $true
                }
                [pscustomobject]@{
                    Id      = 'Warnings'
                    X       = 780.0
                    Y       = 280.0
                    Width   = 380.0
                    Height  = 410.0
                    Visible = $true
                }
            )
        }
    }
}

function Get-PhoenixUiConfigurationValue {

    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [AllowNull()]
        [object]$DefaultValue
    )

    if ($null -eq $InputObject) {
        return $DefaultValue
    }

    $property =
        $InputObject.PSObject.Properties[$Name]

    if ($null -eq $property) {
        return $DefaultValue
    }

    if ($null -eq $property.Value) {
        return $DefaultValue
    }

    return $property.Value
}

function Get-PhoenixUiConfiguration {

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $defaults =
        New-PhoenixUiDefaultConfiguration

    [string]$configurationPath =
        Get-PhoenixUiConfigurationPath

    $stored = $null

    if (Test-Path -LiteralPath $configurationPath) {

        try {
            $stored =
                Get-Content `
                    -LiteralPath $configurationPath `
                    -Raw `
                    -ErrorAction Stop |
                    ConvertFrom-Json `
                        -ErrorAction Stop
        }
        catch {
            Write-Warning (
                'Phoenix UI configuration could not be read; ' +
                "defaults will be used: $($_.Exception.Message)"
            )
        }
    }

    if ($null -eq $stored) {
        return $defaults
    }

    $storedAppearance =
        Get-PhoenixUiConfigurationValue `
            -InputObject $stored `
            -Name 'Appearance' `
            -DefaultValue $defaults.Appearance

    $storedWindow =
        Get-PhoenixUiConfigurationValue `
            -InputObject $stored `
            -Name 'Window' `
            -DefaultValue $defaults.Window

    $storedDashboard =
        Get-PhoenixUiConfigurationValue `
            -InputObject $stored `
            -Name 'Dashboard' `
            -DefaultValue $defaults.Dashboard

    $appearance = [pscustomobject]@{}

    foreach (
        $name in @(
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
            'BackgroundImage'
            'BrandImage'
            'FontFile'
        )
    ) {
        $appearance |
            Add-Member `
                -MemberType NoteProperty `
                -Name $name `
                -Value (
                    Get-PhoenixUiConfigurationValue `
                        -InputObject $storedAppearance `
                        -Name $name `
                        -DefaultValue $defaults.Appearance.$name
                )
    }

    $windowConfiguration = [pscustomobject]@{
        Width = Get-PhoenixUiConfigurationValue `
            -InputObject $storedWindow `
            -Name 'Width' `
            -DefaultValue $defaults.Window.Width

        Height = Get-PhoenixUiConfigurationValue `
            -InputObject $storedWindow `
            -Name 'Height' `
            -DefaultValue $defaults.Window.Height

        Maximized = Get-PhoenixUiConfigurationValue `
            -InputObject $storedWindow `
            -Name 'Maximized' `
            -DefaultValue $defaults.Window.Maximized
    }

    $storedTiles = @(
        Get-PhoenixUiConfigurationValue `
            -InputObject $storedDashboard `
            -Name 'Tiles' `
            -DefaultValue $defaults.Dashboard.Tiles
    )

    $tiles = @(
        foreach ($defaultTile in $defaults.Dashboard.Tiles) {

            $storedTile =
                $storedTiles |
                    Where-Object {
                        $_.Id -eq $defaultTile.Id
                    } |
                    Select-Object -First 1

            if ($null -eq $storedTile) {
                $storedTile = $defaultTile
            }

            [pscustomobject]@{
                Id = $defaultTile.Id
                X = Get-PhoenixUiConfigurationValue `
                    -InputObject $storedTile `
                    -Name 'X' `
                    -DefaultValue $defaultTile.X

                Y = Get-PhoenixUiConfigurationValue `
                    -InputObject $storedTile `
                    -Name 'Y' `
                    -DefaultValue $defaultTile.Y

                Width = Get-PhoenixUiConfigurationValue `
                    -InputObject $storedTile `
                    -Name 'Width' `
                    -DefaultValue $defaultTile.Width

                Height = Get-PhoenixUiConfigurationValue `
                    -InputObject $storedTile `
                    -Name 'Height' `
                    -DefaultValue $defaultTile.Height

                Visible = Get-PhoenixUiConfigurationValue `
                    -InputObject $storedTile `
                    -Name 'Visible' `
                    -DefaultValue $defaultTile.Visible
            }
        }
    )

    return [pscustomobject]@{
        SchemaVersion = '2.0'
        ThemeId = Get-PhoenixUiConfigurationValue `
            -InputObject $stored `
            -Name 'ThemeId' `
            -DefaultValue $defaults.ThemeId

        Appearance    = $appearance
        Window        = $windowConfiguration
        Dashboard     = [pscustomobject]@{
            CanvasWidth = Get-PhoenixUiConfigurationValue `
                -InputObject $storedDashboard `
                -Name 'CanvasWidth' `
                -DefaultValue $defaults.Dashboard.CanvasWidth

            CanvasHeight = Get-PhoenixUiConfigurationValue `
                -InputObject $storedDashboard `
                -Name 'CanvasHeight' `
                -DefaultValue $defaults.Dashboard.CanvasHeight

            SnapSize = Get-PhoenixUiConfigurationValue `
                -InputObject $storedDashboard `
                -Name 'SnapSize' `
                -DefaultValue $defaults.Dashboard.SnapSize

            Tiles = $tiles
        }
    }
}
