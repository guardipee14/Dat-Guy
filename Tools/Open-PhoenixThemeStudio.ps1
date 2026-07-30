[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $IsWindows) {
    throw 'Phoenix Theme Studio requires Windows.'
}

if (
    [Threading.Thread]::CurrentThread.ApartmentState -ne
    [Threading.ApartmentState]::STA
) {
    throw (
        'Phoenix Theme Studio requires an STA PowerShell process. ' +
        'Use Phoenix-Theme-Studio.cmd.'
    )
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[string]$projectRoot =
    [IO.Path]::GetFullPath(
        (
            Join-Path `
                $PSScriptRoot `
                '..'
        )
    )

Import-Module `
    -Name (
        Join-Path `
            $projectRoot `
            'Phoenix.psd1'
    ) `
    -Force `
    -ErrorAction Stop `
    6>$null

$form =
    [System.Windows.Forms.Form]::new()

$form.Text = 'Phoenix Theme Studio'
$form.Width = 760
$form.Height = 720
$form.MinimumSize =
    [Drawing.Size]::new(
        720,
        640
    )

$form.StartPosition =
    [System.Windows.Forms.FormStartPosition]::CenterScreen

$form.Font =
    [Drawing.Font]::new(
        'Segoe UI',
        10
    )

$table =
    [System.Windows.Forms.TableLayoutPanel]::new()

$table.Dock =
    [System.Windows.Forms.DockStyle]::Fill

$table.Padding =
    [System.Windows.Forms.Padding]::new(
        18
    )

$table.ColumnCount = 3
$table.ColumnStyles.Add(
    [System.Windows.Forms.ColumnStyle]::new(
        [System.Windows.Forms.SizeType]::Absolute,
        160
    )
)

$table.ColumnStyles.Add(
    [System.Windows.Forms.ColumnStyle]::new(
        [System.Windows.Forms.SizeType]::Percent,
        100
    )
)

$table.ColumnStyles.Add(
    [System.Windows.Forms.ColumnStyle]::new(
        [System.Windows.Forms.SizeType]::Absolute,
        110
    )
)

$form.Controls.Add($table)

function Add-PhoenixThemeStudioField {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter(Mandatory)]
        [System.Windows.Forms.Control]$Control,

        [Parameter()]
        [System.Windows.Forms.Control]$ActionControl
    )

    [int]$row = $table.RowCount
    $table.RowCount++
    $table.RowStyles.Add(
        [System.Windows.Forms.RowStyle]::new(
            [System.Windows.Forms.SizeType]::AutoSize
        )
    )

    $labelControl =
        [System.Windows.Forms.Label]::new()

    $labelControl.Text = $Label
    $labelControl.AutoSize = $true
    $labelControl.Anchor =
        [System.Windows.Forms.AnchorStyles]::Left

    $Control.Dock =
        [System.Windows.Forms.DockStyle]::Fill

    $table.Controls.Add(
        $labelControl,
        0,
        $row
    )

    $table.Controls.Add(
        $Control,
        1,
        $row
    )

    if ($null -ne $ActionControl) {
        $ActionControl.Dock =
            [System.Windows.Forms.DockStyle]::Fill

        $table.Controls.Add(
            $ActionControl,
            2,
            $row
        )
    }
}

function New-PhoenixThemeStudioTextBox {

    [CmdletBinding()]
    [OutputType([System.Windows.Forms.TextBox])]
    param(
        [Parameter()]
        [string]$Text = ''
    )

    $textBox =
        [System.Windows.Forms.TextBox]::new()

    $textBox.Text = $Text
    $textBox.Margin =
        [System.Windows.Forms.Padding]::new(
            4,
            6,
            4,
            6
        )

    return $textBox
}

$nameText =
    New-PhoenixThemeStudioTextBox `
        -Text 'My Phoenix Theme'

$idText =
    New-PhoenixThemeStudioTextBox `
        -Text 'my-phoenix-theme'

$authorText =
    New-PhoenixThemeStudioTextBox `
        -Text $env:USERNAME

$descriptionText =
    New-PhoenixThemeStudioTextBox `
        -Text 'A custom Phoenix theme.'

$fontFamilyText =
    New-PhoenixThemeStudioTextBox `
        -Text 'Segoe UI'

Add-PhoenixThemeStudioField `
    -Label 'Theme name' `
    -Control $nameText

Add-PhoenixThemeStudioField `
    -Label 'Theme ID' `
    -Control $idText

Add-PhoenixThemeStudioField `
    -Label 'Author' `
    -Control $authorText

Add-PhoenixThemeStudioField `
    -Label 'Description' `
    -Control $descriptionText

Add-PhoenixThemeStudioField `
    -Label 'Font family name' `
    -Control $fontFamilyText

$colorDefaults = [ordered]@{
    Background = '#0B1220'
    Surface    = '#111B2E'
    Card       = '#142035'
    Border     = '#2A3A55'
    Text       = '#F5F7FB'
    MutedText  = '#9FB0C9'
    Accent     = '#2F80ED'
    Success    = '#22A06B'
    Warning    = '#D99A2B'
    Danger     = '#D64545'
}

$colorButtons = @{}

foreach ($colorName in $colorDefaults.Keys) {
    $colorButton =
        [System.Windows.Forms.Button]::new()

    $colorButton.Text =
        $colorDefaults[$colorName]

    $colorButton.Tag =
        $colorDefaults[$colorName]

    $colorButton.BackColor =
        [Drawing.ColorTranslator]::FromHtml(
            $colorDefaults[$colorName]
        )

    $colorButton.ForeColor = if (
        $colorButton.BackColor.GetBrightness() -gt 0.55
    ) {
        [Drawing.Color]::Black
    }
    else {
        [Drawing.Color]::White
    }

    $colorButton.Add_Click({
        param($sender)

        $dialog =
            [System.Windows.Forms.ColorDialog]::new()

        $dialog.FullOpen = $true
        $dialog.Color = $sender.BackColor

        if (
            $dialog.ShowDialog() -eq
            [System.Windows.Forms.DialogResult]::OK
        ) {
            [string]$hex = (
                '#{0:X2}{1:X2}{2:X2}' -f
                $dialog.Color.R,
                $dialog.Color.G,
                $dialog.Color.B
            )

            $sender.Tag = $hex
            $sender.Text = $hex
            $sender.BackColor = $dialog.Color
            $sender.ForeColor = if (
                $dialog.Color.GetBrightness() -gt 0.55
            ) {
                [Drawing.Color]::Black
            }
            else {
                [Drawing.Color]::White
            }
        }

        $dialog.Dispose()
    })

    $colorButtons[$colorName] = $colorButton

    Add-PhoenixThemeStudioField `
        -Label $colorName `
        -Control $colorButton
}

$assetPaths = [ordered]@{
    BrandImage      = ''
    BackgroundImage = ''
    FontFile        = ''
    PreviewImage    = ''
}

foreach ($assetName in $assetPaths.Keys) {
    $assetText =
        New-PhoenixThemeStudioTextBox

    $assetText.ReadOnly = $true

    $browseButton =
        [System.Windows.Forms.Button]::new()

    $browseButton.Text = 'Browse...'
    $browseButton.Tag =
        [pscustomobject]@{
            Name    = $assetName
            TextBox = $assetText
        }

    $browseButton.Add_Click({
        param($sender)

        $definition = $sender.Tag
        $dialog =
            [System.Windows.Forms.OpenFileDialog]::new()

        $dialog.Filter = if (
            $definition.Name -eq 'FontFile'
        ) {
            'Font files (*.ttf;*.otf)|*.ttf;*.otf'
        }
        else {
            'Image files (*.png;*.jpg;*.jpeg;*.bmp;*.ico)|*.png;*.jpg;*.jpeg;*.bmp;*.ico'
        }

        if (
            $dialog.ShowDialog() -eq
            [System.Windows.Forms.DialogResult]::OK
        ) {
            $assetPaths[$definition.Name] =
                $dialog.FileName

            $definition.TextBox.Text =
                $dialog.FileName
        }

        $dialog.Dispose()
    }.GetNewClosure())

    Add-PhoenixThemeStudioField `
        -Label $assetName `
        -Control $assetText `
        -ActionControl $browseButton
}

$note =
    [System.Windows.Forms.Label]::new()

$note.AutoSize = $true
$note.Text = (
    'Phoenix themes are data-only. Packages cannot contain scripts, ' +
    'XAML, executables, or libraries and are capped at 25 MB extracted.'
)

$note.ForeColor =
    [Drawing.Color]::DimGray

$table.RowCount++
$table.Controls.Add(
    $note,
    0,
    $table.RowCount - 1
)

$table.SetColumnSpan(
    $note,
    3
)

$buttonPanel =
    [System.Windows.Forms.FlowLayoutPanel]::new()

$buttonPanel.AutoSize = $true
$buttonPanel.Dock =
    [System.Windows.Forms.DockStyle]::Fill

$buttonPanel.FlowDirection =
    [System.Windows.Forms.FlowDirection]::RightToLeft

$createButton =
    [System.Windows.Forms.Button]::new()

$createButton.Text = 'Create theme package'
$createButton.AutoSize = $true

$installButton =
    [System.Windows.Forms.Button]::new()

$installButton.Text = 'Install existing package'
$installButton.AutoSize = $true

$buttonPanel.Controls.Add($createButton)
$buttonPanel.Controls.Add($installButton)

$table.RowCount++
$table.Controls.Add(
    $buttonPanel,
    0,
    $table.RowCount - 1
)

$table.SetColumnSpan(
    $buttonPanel,
    3
)

$installButton.Add_Click({
    $dialog =
        [System.Windows.Forms.OpenFileDialog]::new()

    $dialog.Filter =
        'Phoenix themes (*.phxtheme)|*.phxtheme'

    if (
        $dialog.ShowDialog() -eq
        [System.Windows.Forms.DialogResult]::OK
    ) {
        try {
            $result =
                Install-PhoenixTheme `
                    -LiteralPath $dialog.FileName `
                    -Confirm:$false

            [void][System.Windows.Forms.MessageBox]::Show(
                "Installed '$($result.Name)'. Restart the Control Center to select it.",
                'Phoenix Theme Studio',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }
        catch {
            [void][System.Windows.Forms.MessageBox]::Show(
                $_.Exception.Message,
                'Theme installation failed',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    }

    $dialog.Dispose()
})

$createButton.Add_Click({
    if (
        [string]::IsNullOrWhiteSpace($nameText.Text) -or
        [string]::IsNullOrWhiteSpace($idText.Text)
    ) {
        [void][System.Windows.Forms.MessageBox]::Show(
            'Enter a theme name and ID.',
            'Phoenix Theme Studio'
        )

        return
    }

    $dialog =
        [System.Windows.Forms.SaveFileDialog]::new()

    $dialog.Filter =
        'Phoenix themes (*.phxtheme)|*.phxtheme'

    $dialog.FileName =
        "$($idText.Text).phxtheme"

    if (
        $dialog.ShowDialog() -ne
        [System.Windows.Forms.DialogResult]::OK
    ) {
        $dialog.Dispose()
        return
    }

    [string]$sourceDirectory =
        Join-Path `
            ([IO.Path]::GetTempPath()) `
            (
                'PhoenixThemeStudio-{0}' -f
                [guid]::NewGuid().ToString('N')
            )

    try {
        New-Item `
            -ItemType Directory `
            -Path $sourceDirectory `
            -Force |
            Out-Null

        [string]$assetDirectory =
            Join-Path `
                $sourceDirectory `
                'Assets'

        New-Item `
            -ItemType Directory `
            -Path $assetDirectory `
            -Force |
            Out-Null

        $assets = [ordered]@{}

        foreach ($assetName in $assetPaths.Keys) {
            [string]$sourcePath =
                [string]$assetPaths[$assetName]

            if (
                [string]::IsNullOrWhiteSpace($sourcePath)
            ) {
                continue
            }

            [string]$destinationName = (
                '{0}{1}' -f
                $assetName,
                [IO.Path]::GetExtension($sourcePath)
            )

            Copy-Item `
                -LiteralPath $sourcePath `
                -Destination (
                    Join-Path `
                        $assetDirectory `
                        $destinationName
                ) `
                -Force `
                -ErrorAction Stop

            $assets[$assetName] =
                "Assets/$destinationName"
        }

        $appearance = [ordered]@{
            Background = [string]$colorButtons.Background.Tag
            Surface = [string]$colorButtons.Surface.Tag
            SurfaceAlt = [string]$colorButtons.Surface.Tag
            Card = [string]$colorButtons.Card.Tag
            Border = [string]$colorButtons.Border.Tag
            Text = [string]$colorButtons.Text.Tag
            MutedText = [string]$colorButtons.MutedText.Tag
            Accent = [string]$colorButtons.Accent.Tag
            AccentHover = [string]$colorButtons.Accent.Tag
            Success = [string]$colorButtons.Success.Tag
            Warning = [string]$colorButtons.Warning.Tag
            Danger = [string]$colorButtons.Danger.Tag
            FontFamily = $fontFamilyText.Text
            FontSize = 13.0
            CornerRadius = 10.0
            Spacing = 12.0
            NavigationWidth = 220.0
        }

        $manifest = [ordered]@{
            SchemaVersion = '1.0'
            Id = $idText.Text.Trim().ToLowerInvariant()
            Name = $nameText.Text.Trim()
            Version = '1.0.0'
            Author = $authorText.Text.Trim()
            Description = $descriptionText.Text.Trim()
            Appearance = $appearance
            Assets = $assets
        }

        $manifest |
            ConvertTo-Json `
                -Depth 8 |
            Set-Content `
                -LiteralPath (
                    Join-Path `
                        $sourceDirectory `
                        'theme.json'
                ) `
                -Encoding UTF8 `
                -ErrorAction Stop

        $result =
            Export-PhoenixTheme `
                -ThemeDirectory $sourceDirectory `
                -DestinationPath $dialog.FileName `
                -Confirm:$false

        [void][System.Windows.Forms.MessageBox]::Show(
            "Theme package created:`n$($result.Path)",
            'Phoenix Theme Studio',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    }
    catch {
        [void][System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message,
            'Theme creation failed',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
    finally {
        if (Test-Path -LiteralPath $sourceDirectory) {
            Remove-Item `
                -LiteralPath $sourceDirectory `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue
        }

        $dialog.Dispose()
    }
})

[void]$form.ShowDialog()
