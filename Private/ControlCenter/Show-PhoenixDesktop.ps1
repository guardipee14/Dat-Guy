function Show-PhoenixDesktop {

    [CmdletBinding()]
    param()

    if (-not $IsWindows) {
        throw 'The Phoenix desktop interface requires Windows.'
    }

    if (
        [Threading.Thread]::CurrentThread.ApartmentState -ne
            [Threading.ApartmentState]::STA
    ) {
        throw (
            'The Phoenix desktop interface requires an STA PowerShell process. ' +
            'Use Phoenix.cmd or Start-PhoenixControlCenter.ps1.'
        )
    }

    Add-Type `
        -AssemblyName PresentationFramework `
        -ErrorAction Stop

    Add-Type `
        -AssemblyName PresentationCore `
        -ErrorAction Stop

    [string]$xamlPath =
        Join-Path `
            $PSScriptRoot `
            'PhoenixControlCenter.xaml'

    [xml]$xaml =
        Get-Content `
            -LiteralPath $xamlPath `
            -Raw `
            -ErrorAction Stop

    $reader =
        [Xml.XmlNodeReader]::new($xaml)

    $window =
        [System.Windows.Markup.XamlReader]::Load(
            $reader
        )

    $controls = @{}

    foreach (
        $controlName in @(
            'NavigationColumn'
            'OverviewNavButton'
            'ApplicationsNavButton'
            'DriversNavButton'
            'ActivityNavButton'
            'CustomizeNavButton'
            'HeaderSubtitle'
            'RefreshAllButton'
            'OverviewPage'
            'ApplicationsPage'
            'DriversPage'
            'ActivityPage'
            'CustomizePage'
            'EditLayoutButton'
            'SaveLayoutButton'
            'ResetLayoutButton'
            'DashboardCanvas'
            'SystemTile'
            'SystemTileDragThumb'
            'SystemTileResizeThumb'
            'SystemSummaryText'
            'InventoryTile'
            'InventoryTileDragThumb'
            'InventoryTileResizeThumb'
            'InventorySummaryText'
            'QuickActionsTile'
            'QuickActionsTileDragThumb'
            'QuickActionsTileResizeThumb'
            'OpenAppsFromDashboardButton'
            'OpenDriversFromDashboardButton'
            'OpenCustomizeFromDashboardButton'
            'ProvidersTile'
            'ProvidersTileDragThumb'
            'ProvidersTileResizeThumb'
            'WarningsTile'
            'WarningsTileDragThumb'
            'WarningsTileResizeThumb'
            'InventoryWarningsText'
            'ProviderGrid'
            'ApplicationGrid'
            'RefreshAppUpdatesButton'
            'ViewAppUpdateDetailsButton'
            'ApplicationDetailsText'
            'OpenApplicationReleaseUrlButton'
            'UpdateSelectedAppsButton'
            'UpdateAllAppsButton'
            'RepairSelectedAppsButton'
            'RepairAllAppsButton'
            'UninstallSelectedAppsButton'
            'AppSearchText'
            'SearchAppsButton'
            'InstallSelectedSearchButton'
            'InstallAllSearchButton'
            'SearchResultGrid'
            'DriverGrid'
            'RepairSelectedDriversButton'
            'UninstallSelectedDriversButton'
            'RepairProblemDriversButton'
            'ScanDriverUpdatesButton'
            'InstallSelectedDriversButton'
            'UpdateAllDriversButton'
            'DriverUpdateGrid'
            'DriverDetailsText'
            'OpenDriverReleaseUrlButton'
            'ActivityText'
            'ThemePresetCombo'
            'ApplyThemeButton'
            'InstallThemeButton'
            'OpenThemeStudioButton'
            'ColorRoleCombo'
            'ColorPreview'
            'SelectedColorText'
            'RedColorSlider'
            'GreenColorSlider'
            'BlueColorSlider'
            'RedValueText'
            'GreenValueText'
            'BlueValueText'
            'BackgroundColorText'
            'SurfaceColorText'
            'CardColorText'
            'AccentColorText'
            'TextColorText'
            'MutedColorText'
            'FontFamilyCombo'
            'FontSizeSlider'
            'CornerRadiusSlider'
            'SpacingSlider'
            'NavigationWidthSlider'
            'ShowSystemTileCheck'
            'ShowInventoryTileCheck'
            'ShowQuickActionsTileCheck'
            'ShowProvidersTileCheck'
            'ShowWarningsTileCheck'
            'ApplyAppearanceButton'
            'SaveAppearanceButton'
            'ResetAppearanceButton'
            'StatusText'
            'OperationPanel'
            'OperationText'
            'OperationProgress'
            'CancelOperationButton'
            'RecoveryPanel'
            'RecoveryTitleText'
            'RecoveryMessageText'
            'RecoveryRetryButton'
            'RecoveryDetailsButton'
            'RecoveryDismissButton'
        )
    ) {
        $controls[$controlName] =
            $window.FindName($controlName)

        if ($null -eq $controls[$controlName]) {
            throw (
                "Phoenix UI control '$controlName' was not found."
            )
        }
    }

    $getUiConfigurationCommand =
        ${function:Get-PhoenixUiConfiguration}

    $newUiConfigurationCommand =
        ${function:New-PhoenixUiDefaultConfiguration}

    $saveUiConfigurationCommand =
        ${function:Save-PhoenixUiConfiguration}

    $setUiAppearanceCommand =
        ${function:Set-PhoenixUiAppearance}

    $uiConfiguration =
        & $getUiConfigurationCommand

    try {
        & $setUiAppearanceCommand `
            -Window $window `
            -Appearance $uiConfiguration.Appearance
    }
    catch {
        Write-Warning (
            'Phoenix UI appearance was invalid; defaults will be used: {0}' -f
            $_.Exception.Message
        )

        $uiConfiguration =
            & $newUiConfigurationCommand

        & $setUiAppearanceCommand `
            -Window $window `
            -Appearance $uiConfiguration.Appearance
    }

    $window.Width =
        [Math]::Max(
            $window.MinWidth,
            [double]$uiConfiguration.Window.Width
        )

    $window.Height =
        [Math]::Max(
            $window.MinHeight,
            [double]$uiConfiguration.Window.Height
        )

    if ([bool]$uiConfiguration.Window.Maximized) {
        $window.WindowState =
            [System.Windows.WindowState]::Maximized
    }

    $controls.NavigationColumn.Width =
        [System.Windows.GridLength]::new(
            [double]$uiConfiguration.Appearance.NavigationWidth
        )

    $state = @{
        Inventory    = $null
        SearchResult = @()
        DriverUpdate = @()
        UiConfiguration = $uiConfiguration
        EditMode       = $false
        Themes         = @()
        ActiveOperation = $null
        OperationQueue =
            [System.Collections.Generic.Queue[PhoenixBackgroundOperation]]::new()
        StartOperation = $null
        StartNextOperation = $null
        RefreshInventory = $null
        ColorEditorLoading = $false
        ApplicationReleaseUrl = ''
        DriverReleaseUrl = ''
        RefreshApplicationUpdates = $null
        LastFailure     = $null
        RecoveryAction  = $null
        DispatcherFailureCount = 0
    }

    $getContextCommand =
        ${function:Get-PhoenixContext}

    $getInventoryCommand =
        ${function:Get-PhoenixControlCenterInventory}

    $searchPackageCommand =
        ${function:Search-PhoenixControlCenterPackage}

    $packageActionCommand =
        ${function:Invoke-PhoenixControlCenterPackageAction}

    $driverActionCommand =
        ${function:Invoke-PhoenixControlCenterDriverAction}

    $getThemeCommand =
        ${function:Get-PhoenixTheme}

    $installThemeCommand =
        ${function:Install-PhoenixTheme}

    $newControlCenterFailureCommand =
        ${function:New-PhoenixControlCenterFailure}

    $writeControlCenterFailureCommand =
        ${function:Write-PhoenixControlCenterFailure}

    $invokeControlCenterBoundaryCommand =
        ${function:Invoke-PhoenixControlCenterBoundary}

    $phoenixModule =
        $ExecutionContext.SessionState.Module

    if ($null -eq $phoenixModule) {
        throw (
            'The Phoenix module session is unavailable for background ' +
            'operation callbacks.'
        )
    }

    $newBackgroundOperationCommand =
        $phoenixModule.NewBoundScriptBlock({
            [CmdletBinding()]
            param(
                [Parameter(Mandatory)]
                [string]$Action,

                [Parameter()]
                [AllowNull()]
                [object]$Parameters,

                [Parameter(Mandatory)]
                [string]$Component,

                [Parameter(Mandatory)]
                [string]$Description,

                [Parameter(Mandatory)]
                [scriptblock]$Completion,

                [Parameter(Mandatory)]
                [string]$ProjectRoot
            )

            New-PhoenixBackgroundOperation `
                @PSBoundParameters
        })

    $startBackgroundOperationCommand =
        $phoenixModule.NewBoundScriptBlock({
            [CmdletBinding()]
            param(
                [Parameter(Mandatory)]
                [object]$Operation,

                [Parameter(Mandatory)]
                [string]$ProjectRoot,

                [Parameter()]
                [AllowNull()]
                [string]$WorkerPath,

                [Parameter()]
                [AllowNull()]
                [string]$PowerShellPath
            )

            Start-PhoenixBackgroundOperation `
                @PSBoundParameters
        })

    $receiveBackgroundOperationCommand =
        $phoenixModule.NewBoundScriptBlock({
            [CmdletBinding()]
            param(
                [Parameter(Mandatory)]
                [object]$Operation
            )

            Receive-PhoenixBackgroundOperation `
                @PSBoundParameters
        })

    $stopBackgroundOperationCommand =
        $phoenixModule.NewBoundScriptBlock({
            [CmdletBinding()]
            param(
                [Parameter(Mandatory)]
                [object]$Operation,

                [Parameter()]
                [bool]$KillTree = $true
            )

            Stop-PhoenixBackgroundOperation `
                @PSBoundParameters
        })

    $removeBackgroundOperationCommand =
        $phoenixModule.NewBoundScriptBlock({
            [CmdletBinding()]
            param(
                [Parameter(Mandatory)]
                [object]$Operation
            )

            Remove-PhoenixBackgroundOperation `
                @PSBoundParameters
        })

    $pageMap = [ordered]@{
        Overview = [pscustomobject]@{
            Page   = $controls.OverviewPage
            Button = $controls.OverviewNavButton
        }
        Applications = [pscustomobject]@{
            Page   = $controls.ApplicationsPage
            Button = $controls.ApplicationsNavButton
        }
        Drivers = [pscustomobject]@{
            Page   = $controls.DriversPage
            Button = $controls.DriversNavButton
        }
        Activity = [pscustomobject]@{
            Page   = $controls.ActivityPage
            Button = $controls.ActivityNavButton
        }
        Customize = [pscustomobject]@{
            Page   = $controls.CustomizePage
            Button = $controls.CustomizeNavButton
        }
    }

    $showPage = {
        param(
            [Parameter(Mandatory)]
            [string]$Name
        )

        foreach ($pageName in $pageMap.Keys) {

            [bool]$isSelected =
                $pageName -eq $Name

            $pageMap[$pageName].Page.Visibility = if ($isSelected) {
                [System.Windows.Visibility]::Visible
            }
            else {
                [System.Windows.Visibility]::Collapsed
            }

            $pageMap[$pageName].Button.Background = if ($isSelected) {
                $window.Resources['PhoenixAccentBrush']
            }
            else {
                [System.Windows.Media.Brushes]::Transparent
            }

            $pageMap[$pageName].Button.Foreground = if ($isSelected) {
                [System.Windows.Media.Brushes]::White
            }
            else {
                $window.Resources['PhoenixMutedBrush']
            }
        }
    }.GetNewClosure()

    $tileMap = [ordered]@{
        System = [pscustomobject]@{
            Element   = $controls.SystemTile
            DragThumb = $controls.SystemTileDragThumb
            SizeThumb = $controls.SystemTileResizeThumb
            MinimumWidth  = 340.0
            MinimumHeight = 200.0
        }
        Inventory = [pscustomobject]@{
            Element   = $controls.InventoryTile
            DragThumb = $controls.InventoryTileDragThumb
            SizeThumb = $controls.InventoryTileResizeThumb
            MinimumWidth  = 250.0
            MinimumHeight = 200.0
        }
        QuickActions = [pscustomobject]@{
            Element   = $controls.QuickActionsTile
            DragThumb = $controls.QuickActionsTileDragThumb
            SizeThumb = $controls.QuickActionsTileResizeThumb
            MinimumWidth  = 230.0
            MinimumHeight = 220.0
        }
        Providers = [pscustomobject]@{
            Element   = $controls.ProvidersTile
            DragThumb = $controls.ProvidersTileDragThumb
            SizeThumb = $controls.ProvidersTileResizeThumb
            MinimumWidth  = 430.0
            MinimumHeight = 240.0
        }
        Warnings = [pscustomobject]@{
            Element   = $controls.WarningsTile
            DragThumb = $controls.WarningsTileDragThumb
            SizeThumb = $controls.WarningsTileResizeThumb
            MinimumWidth  = 260.0
            MinimumHeight = 200.0
        }
    }

    $getTileConfiguration = {
        param(
            [Parameter(Mandatory)]
            [string]$Id
        )

        return (
            $state.UiConfiguration.Dashboard.Tiles |
                Where-Object {
                    $_.Id -eq $Id
                } |
                Select-Object -First 1
        )
    }.GetNewClosure()

    $applyTileLayout = {

        [double]$canvasWidth =
            [Math]::Max(
                800.0,
                [double]$state.UiConfiguration.Dashboard.CanvasWidth
            )

        [double]$canvasHeight =
            [Math]::Max(
                500.0,
                [double]$state.UiConfiguration.Dashboard.CanvasHeight
            )

        $controls.DashboardCanvas.Width =
            $canvasWidth

        $controls.DashboardCanvas.Height =
            $canvasHeight

        foreach ($tileId in $tileMap.Keys) {

            $tileConfiguration =
                & $getTileConfiguration $tileId

            if ($null -eq $tileConfiguration) {
                continue
            }

            $tileDefinition =
                $tileMap[$tileId]

            [double]$tileWidth =
                [Math]::Min(
                    $canvasWidth,
                    [Math]::Max(
                        $tileDefinition.MinimumWidth,
                        [double]$tileConfiguration.Width
                    )
                )

            [double]$tileHeight =
                [Math]::Min(
                    $canvasHeight,
                    [Math]::Max(
                        $tileDefinition.MinimumHeight,
                        [double]$tileConfiguration.Height
                    )
                )

            [double]$tileX =
                [Math]::Max(
                    0.0,
                    [Math]::Min(
                        [double]$tileConfiguration.X,
                        $canvasWidth - $tileWidth
                    )
                )

            [double]$tileY =
                [Math]::Max(
                    0.0,
                    [Math]::Min(
                        [double]$tileConfiguration.Y,
                        $canvasHeight - $tileHeight
                    )
                )

            $tileDefinition.Element.Width =
                $tileWidth

            $tileDefinition.Element.Height =
                $tileHeight

            [System.Windows.Controls.Canvas]::SetLeft(
                $tileDefinition.Element,
                $tileX
            )

            [System.Windows.Controls.Canvas]::SetTop(
                $tileDefinition.Element,
                $tileY
            )

            $tileDefinition.Element.Visibility = if (
                [bool]$tileConfiguration.Visible
            ) {
                [System.Windows.Visibility]::Visible
            }
            else {
                [System.Windows.Visibility]::Collapsed
            }
        }
    }.GetNewClosure()

    $captureTileLayout = {

        foreach ($tileId in $tileMap.Keys) {

            $tileConfiguration =
                & $getTileConfiguration $tileId

            if ($null -eq $tileConfiguration) {
                continue
            }

            $tileElement =
                $tileMap[$tileId].Element

            [double]$tileX =
                [System.Windows.Controls.Canvas]::GetLeft(
                    $tileElement
                )

            [double]$tileY =
                [System.Windows.Controls.Canvas]::GetTop(
                    $tileElement
                )

            if ([double]::IsNaN($tileX)) {
                $tileX = 0
            }

            if ([double]::IsNaN($tileY)) {
                $tileY = 0
            }

            $tileConfiguration.X = $tileX
            $tileConfiguration.Y = $tileY
            $tileConfiguration.Width =
                [double]$tileElement.Width

            $tileConfiguration.Height =
                [double]$tileElement.Height

            $tileConfiguration.Visible =
                $tileElement.Visibility -eq
                    [System.Windows.Visibility]::Visible
        }
    }.GetNewClosure()

    $loadThemes = {

        $state.Themes = @(
            & $getThemeCommand
        )

        $themeItems = @(
            foreach ($theme in $state.Themes) {
                [pscustomobject]@{
                    DisplayName = if ($theme.BuiltIn) {
                        "$($theme.Name) (built in)"
                    }
                    else {
                        "$($theme.Name) — $($theme.Author)"
                    }
                    Theme = $theme
                }
            }
        )

        $controls.ThemePresetCombo.ItemsSource =
            $themeItems

        $controls.ThemePresetCombo.SelectedItem =
            $themeItems |
                Where-Object {
                    $_.Theme.Id -ieq
                        [string]$state.UiConfiguration.ThemeId
                } |
                Select-Object -First 1

        if (
            $null -eq
            $controls.ThemePresetCombo.SelectedItem -and
            $themeItems.Count -gt 0
        ) {
            $controls.ThemePresetCombo.SelectedIndex = 0
        }
    }.GetNewClosure()

    $loadCustomizationControls = {

        $appearance =
            $state.UiConfiguration.Appearance

        $controls.BackgroundColorText.Text =
            [string]$appearance.Background

        $controls.SurfaceColorText.Text =
            [string]$appearance.Surface

        $controls.CardColorText.Text =
            [string]$appearance.Card

        $controls.AccentColorText.Text =
            [string]$appearance.Accent

        $controls.TextColorText.Text =
            [string]$appearance.Text

        $controls.MutedColorText.Text =
            [string]$appearance.MutedText

        $controls.FontSizeSlider.Value =
            [double]$appearance.FontSize

        $controls.CornerRadiusSlider.Value =
            [double]$appearance.CornerRadius

        $controls.SpacingSlider.Value =
            [double]$appearance.Spacing

        $controls.NavigationWidthSlider.Value =
            [double]$appearance.NavigationWidth

        foreach ($fontItem in $controls.FontFamilyCombo.Items) {
            if (
                [string]$fontItem.Content -eq
                [string]$appearance.FontFamily
            ) {
                $controls.FontFamilyCombo.SelectedItem =
                    $fontItem

                break
            }
        }

        $tileVisibilityControls = [ordered]@{
            System       = $controls.ShowSystemTileCheck
            Inventory    = $controls.ShowInventoryTileCheck
            QuickActions = $controls.ShowQuickActionsTileCheck
            Providers    = $controls.ShowProvidersTileCheck
            Warnings     = $controls.ShowWarningsTileCheck
        }

        foreach ($tileId in $tileVisibilityControls.Keys) {

            $tileConfiguration =
                & $getTileConfiguration $tileId

            $tileVisibilityControls[$tileId].IsChecked =
                [bool]$tileConfiguration.Visible
        }

        if ($controls.ColorRoleCombo.SelectedIndex -lt 0) {
            $controls.ColorRoleCombo.SelectedIndex = 0
        }
    }.GetNewClosure()

    $applyCustomization = {

        $current =
            $state.UiConfiguration.Appearance

        [string]$fontFamily =
            [string]$current.FontFamily

        if (
            $null -ne
            $controls.FontFamilyCombo.SelectedItem
        ) {
            $fontFamily =
                [string]$controls.FontFamilyCombo.SelectedItem.Content
        }

        $candidate = [pscustomobject]@{
            Background = $controls.BackgroundColorText.Text.Trim()
            Surface = $controls.SurfaceColorText.Text.Trim()
            SurfaceAlt = [string]$current.SurfaceAlt
            Card = $controls.CardColorText.Text.Trim()
            Border = [string]$current.Border
            Text = $controls.TextColorText.Text.Trim()
            MutedText = $controls.MutedColorText.Text.Trim()
            Accent = $controls.AccentColorText.Text.Trim()
            AccentHover = $controls.AccentColorText.Text.Trim()
            Success = [string]$current.Success
            Warning = [string]$current.Warning
            Danger = [string]$current.Danger
            FontFamily = $fontFamily
            FontSize = [double]$controls.FontSizeSlider.Value
            CornerRadius = [double]$controls.CornerRadiusSlider.Value
            Spacing = [double]$controls.SpacingSlider.Value
            NavigationWidth = [double]$controls.NavigationWidthSlider.Value
            BackgroundImage = [string]$current.BackgroundImage
            BrandImage = [string]$current.BrandImage
            FontFile = [string]$current.FontFile
        }

        & $setUiAppearanceCommand `
            -Window $window `
            -Appearance $candidate

        $state.UiConfiguration.Appearance =
            $candidate

        $state.UiConfiguration.ThemeId =
            'custom'

        $controls.NavigationColumn.Width =
            [System.Windows.GridLength]::new(
                [double]$candidate.NavigationWidth
            )

        $visibilityValues = [ordered]@{
            System       = $controls.ShowSystemTileCheck.IsChecked
            Inventory    = $controls.ShowInventoryTileCheck.IsChecked
            QuickActions = $controls.ShowQuickActionsTileCheck.IsChecked
            Providers    = $controls.ShowProvidersTileCheck.IsChecked
            Warnings     = $controls.ShowWarningsTileCheck.IsChecked
        }

        foreach ($tileId in $visibilityValues.Keys) {
            $tileConfiguration =
                & $getTileConfiguration $tileId

            $tileConfiguration.Visible =
                [bool]$visibilityValues[$tileId]
        }

        & $applyTileLayout
    }.GetNewClosure()

    $colorControlMap = [ordered]@{
        Background = $controls.BackgroundColorText
        Surface    = $controls.SurfaceColorText
        Card       = $controls.CardColorText
        Accent     = $controls.AccentColorText
        Text       = $controls.TextColorText
        MutedText  = $controls.MutedColorText
    }

    $loadColorEditor = {

        if (
            $null -eq
            $controls.ColorRoleCombo.SelectedItem
        ) {
            return
        }

        [string]$role =
            [string]$controls.ColorRoleCombo.SelectedItem.Tag

        if (-not $colorControlMap.Contains($role)) {
            return
        }

        [string]$hex =
            [string]$colorControlMap[$role].Text

        try {
            $color =
                [System.Windows.Media.ColorConverter]::ConvertFromString(
                    $hex
                )

            $state.ColorEditorLoading = $true
            $controls.RedColorSlider.Value = $color.R
            $controls.GreenColorSlider.Value = $color.G
            $controls.BlueColorSlider.Value = $color.B
            $controls.SelectedColorText.Text = $hex
            $controls.RedValueText.Text = "Red: $($color.R)"
            $controls.GreenValueText.Text = "Green: $($color.G)"
            $controls.BlueValueText.Text = "Blue: $($color.B)"

            $previewBrush =
                [System.Windows.Media.SolidColorBrush]::new(
                    $color
                )

            $previewBrush.Freeze()
            $controls.ColorPreview.Background =
                $previewBrush
        }
        finally {
            $state.ColorEditorLoading = $false
        }
    }.GetNewClosure()

    $updateColorEditor = {

        if (
            $state.ColorEditorLoading -or
            $null -eq
            $controls.ColorRoleCombo.SelectedItem
        ) {
            return
        }

        [string]$role =
            [string]$controls.ColorRoleCombo.SelectedItem.Tag

        if (-not $colorControlMap.Contains($role)) {
            return
        }

        [int]$red =
            [Math]::Round(
                $controls.RedColorSlider.Value
            )

        [int]$green =
            [Math]::Round(
                $controls.GreenColorSlider.Value
            )

        [int]$blue =
            [Math]::Round(
                $controls.BlueColorSlider.Value
            )

        [string]$hex = (
            '#{0:X2}{1:X2}{2:X2}' -f
            $red,
            $green,
            $blue
        )

        $colorControlMap[$role].Text = $hex
        $controls.SelectedColorText.Text = $hex
        $controls.RedValueText.Text = "Red: $red"
        $controls.GreenValueText.Text = "Green: $green"
        $controls.BlueValueText.Text = "Blue: $blue"

        $previewColor =
            [System.Windows.Media.Color]::FromRgb(
                [byte]$red,
                [byte]$green,
                [byte]$blue
            )

        $previewBrush =
            [System.Windows.Media.SolidColorBrush]::new(
                $previewColor
            )

        $previewBrush.Freeze()
        $controls.ColorPreview.Background =
            $previewBrush
    }.GetNewClosure()

    $appendActivity = {
        param(
            [string]$Message
        )

        $controls.ActivityText.AppendText(
            (
                '[{0}] {1}{2}' -f
                (
                    Get-Date `
                        -Format 'HH:mm:ss'
                ),
                $Message,
                [Environment]::NewLine
            )
        )

        $controls.ActivityText.ScrollToEnd()
    }.GetNewClosure()

    $setStatus = {
        param(
            [string]$Message
        )

        $controls.StatusText.Text = $Message
        & $appendActivity $Message
    }.GetNewClosure()

    $hideRecovery = {
        $controls.RecoveryPanel.Visibility =
            [System.Windows.Visibility]::Collapsed

        $state.LastFailure = $null
        $state.RecoveryAction = $null
    }.GetNewClosure()

    $showRecovery = {
        param(
            [Parameter(Mandatory)]
            [object]$Failure,

            [Parameter()]
            [AllowNull()]
            [scriptblock]$RetryAction
        )

        $state.LastFailure = $Failure
        $state.RecoveryAction = $RetryAction

        $controls.RecoveryTitleText.Text = (
            '{0} was isolated' -f
            [string]$Failure.Data.Component
        )

        $controls.RecoveryMessageText.Text =
            [string]$Failure.Message

        $controls.RecoveryRetryButton.IsEnabled =
            $null -ne $RetryAction

        $controls.RecoveryPanel.Visibility =
            [System.Windows.Visibility]::Visible

        & $appendActivity (
            '[{0}] {1} (failure {2})' -f
            $Failure.Code,
            $Failure.Message,
            $Failure.Data.FailureId
        )

        $controls.StatusText.Text = (
            'Phoenix isolated an interface error. Other pages remain available.'
        )
    }.GetNewClosure()

    $invokeSafeUiAction = {
        param(
            [Parameter(Mandatory)]
            [string]$Component,

            [Parameter(Mandatory)]
            [string]$Operation,

            [Parameter(Mandatory)]
            [scriptblock]$Action,

            [Parameter()]
            [AllowNull()]
            [scriptblock]$RetryAction
        )

        $boundaryShowRecovery = $showRecovery
        $boundaryRetryAction = $RetryAction

        return (
            & $invokeControlCenterBoundaryCommand `
                -Component $Component `
                -Operation $Operation `
                -Action $Action `
                -OnFailure {
                    param($failure)

                    & $boundaryShowRecovery `
                        $failure `
                        $boundaryRetryAction
                }.GetNewClosure()
        )
    }.GetNewClosure()

    $dispatcherShowRecovery = $showRecovery
    $dispatcherNewFailure =
        $newControlCenterFailureCommand

    $dispatcherWriteFailure =
        $writeControlCenterFailureCommand

    $dispatcherState = $state

    $dispatcherExceptionScriptBlock = {
            param(
                $sender,
                $eventArgs
            )

            try {
                $dispatcherState.DispatcherFailureCount++

                $failure =
                    & $dispatcherNewFailure `
                        -Component 'DesktopEvent' `
                        -Operation 'DispatcherCallback' `
                        -Exception $eventArgs.Exception

                $null =
                    & $dispatcherWriteFailure `
                        -Failure $failure

                & $dispatcherShowRecovery `
                    $failure `
                    $null

                $eventArgs.Handled = $true
            }
            catch {
                # Even if the recovery surface cannot render, keep the
                # dispatcher exception contained so the desktop stays open.
                $eventArgs.Handled = $true
            }
        }.GetNewClosure()

    $dispatcherExceptionHandler =
        [System.Windows.Threading.DispatcherUnhandledExceptionEventHandler](
            $dispatcherExceptionScriptBlock
        )

    $window.Dispatcher.add_UnhandledException(
        $dispatcherExceptionHandler
    )

    $setOperationUi = {
        param(
            [bool]$Busy,
            [string]$Message = '',
            [int]$Percent = 0
        )

        $controls.OperationPanel.Visibility = if ($Busy) {
            [System.Windows.Visibility]::Visible
        }
        else {
            [System.Windows.Visibility]::Collapsed
        }

        $controls.OperationText.Text = $Message
        $controls.OperationProgress.Value = $Percent
    }.GetNewClosure()

    $startOperation = {
        param(
            [Parameter(Mandatory)]
            [string]$Action,

            [Parameter(Mandatory)]
            [object]$Parameters,

            [Parameter(Mandatory)]
            [string]$Description,

            [Parameter(Mandatory)]
            [scriptblock]$Completed,

            [Parameter()]
            [switch]$QueueIfBusy,

            [Parameter()]
            [AllowNull()]
            [PhoenixBackgroundOperation]$Operation
        )

        if (
            $null -ne $state.ActiveOperation -and
            -not $QueueIfBusy
        ) {
            [void][System.Windows.MessageBox]::Show(
                $window,
                (
                    'Phoenix is already running an operation. ' +
                    'You can keep navigating or open Activity to watch it.'
                ),
                'Phoenix operation in progress',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            )

            return
        }

        [string]$projectRoot =
            Split-Path `
                -Path (
                    Split-Path `
                        -Path $PSScriptRoot `
                        -Parent
                ) `
                -Parent

        $operation = $Operation

        if ($null -eq $operation) {
            $operation =
                & $newBackgroundOperationCommand `
                    -Action $Action `
                    -Parameters $Parameters `
                    -Component 'ControlCenter' `
                    -Description $Description `
                    -Completion $Completed `
                    -ProjectRoot $projectRoot
        }

        if ($null -ne $state.ActiveOperation) {
            $operation.MarkQueued()
            $state.OperationQueue.Enqueue(
                $operation
            )

            [int]$queuePosition =
                $state.OperationQueue.Count

            & $appendActivity (
                'Queued application operation {0}: {1}' -f
                $queuePosition,
                $operation.Description
            )

            & $setStatus (
                'Application operation queued in position {0}.' -f
                $queuePosition
            )

            return
        }

        try {
            $null =
                & $startBackgroundOperationCommand `
                    -Operation $operation `
                    -ProjectRoot $projectRoot
        }
        catch {
            $null =
                & $removeBackgroundOperationCommand `
                    -Operation $operation

            throw
        }

        $timer =
            [System.Windows.Threading.DispatcherTimer]::new()

        $timer.Interval =
            [TimeSpan]::FromMilliseconds(
                350
            )

        $operation.Timer =
            $timer

        $state.ActiveOperation =
            $operation

        & $setOperationUi `
            $true `
            $Description `
            0

        & $setStatus $Description

        # GetNewClosure captures variables from the current invocation scope.
        # Copy the shared UI references into local aliases before creating the
        # DispatcherTimer handler so PowerShell does not bind $state to the
        # dispatcher's own callback state.
        $timerState = $state
        $timerSetOperationUi = $setOperationUi
        $timerSetStatus = $setStatus
        $timerAppendActivity = $appendActivity
        $timerNewFailure = $newControlCenterFailureCommand
        $timerWriteFailure = $writeControlCenterFailureCommand
        $timerShowRecovery = $showRecovery
        $timerStartNextOperation =
            $timerState.StartNextOperation
        $timerReceiveBackgroundOperation =
            $receiveBackgroundOperationCommand
        $timerRemoveBackgroundOperation =
            $removeBackgroundOperationCommand

        $timer.Add_Tick({

            try {
                $received =
                    & $timerReceiveBackgroundOperation `
                        -Operation $operation

                if ($received.ProgressChanged) {
                    & $timerSetOperationUi `
                        $true `
                        ([string]$received.Message) `
                        ([int]$received.Percent)

                    & $timerAppendActivity (
                        [string]$received.Message
                    )
                }

                if (-not $received.IsCompleted) {
                    return
                }

                $operation.Timer.Stop()

                if (
                    $timerState.ActiveOperation -eq
                    $operation
                ) {
                    $timerState.ActiveOperation = $null
                }

                & $timerSetOperationUi $false

                $null =
                    & $timerRemoveBackgroundOperation `
                        -Operation $operation

                if (-not [bool]$received.Success) {
                    & $timerSetStatus (
                        "Operation failed: $($received.Error)"
                    )

                    $failure =
                        & $timerNewFailure `
                            -Component 'BackgroundOperation' `
                            -Operation $operation.Description `
                            -Message ([string]$received.Error)

                    $null =
                        & $timerWriteFailure `
                            -Failure $failure

                    & $timerShowRecovery `
                        $failure `
                        $null

                    if (
                        $operation.Action -eq 'PackageAction' -and
                        $timerState.OperationQueue.Count -eq 0
                    ) {
                        $refreshInventoryCommand =
                            $timerState.RefreshInventory

                        if (
                            $refreshInventoryCommand -is
                            [scriptblock]
                        ) {
                            & $refreshInventoryCommand
                        }
                    }

                    if (
                        $timerStartNextOperation -is
                        [scriptblock]
                    ) {
                        & $timerStartNextOperation
                    }

                    return
                }

                $completionCommand =
                    $operation.Completion

                if ($completionCommand -isnot [scriptblock]) {
                    throw (
                        'The operation completion callback is not a script block.'
                    )
                }

                & $completionCommand $received.Data

                if (
                    $timerStartNextOperation -is
                    [scriptblock]
                ) {
                    & $timerStartNextOperation
                }
            }
            catch {
                if (
                    $timerState.ActiveOperation -eq
                    $operation
                ) {
                    $timerState.ActiveOperation = $null
                }

                & $timerSetOperationUi $false

                $null =
                    & $timerRemoveBackgroundOperation `
                        -Operation $operation

                [string]$callbackError = (
                    'Control Center operation callback failed: {0}' -f
                    $_.Exception.Message
                )

                & $timerSetStatus $callbackError

                $failure =
                    & $timerNewFailure `
                        -Component 'OperationCallback' `
                        -Operation $operation.Description `
                        -ErrorRecord $_

                $null =
                    & $timerWriteFailure `
                        -Failure $failure

                & $timerShowRecovery `
                    $failure `
                    $null

                if (
                    $timerStartNextOperation -is
                    [scriptblock]
                ) {
                    & $timerStartNextOperation
                }
            }
        }.GetNewClosure())

        $timer.Start()
    }.GetNewClosure()

    $state.StartOperation =
        $startOperation

    $startNextOperation = {
        while (
            $null -eq $state.ActiveOperation -and
            $state.OperationQueue.Count -gt 0
        ) {
            $nextOperation =
                $state.OperationQueue.Dequeue()

            try {
                & $appendActivity (
                    'Starting queued application operation: {0}' -f
                    $nextOperation.Description
                )

                $startOperationCommand =
                    $state.StartOperation

                if (
                    $startOperationCommand -isnot
                    [scriptblock]
                ) {
                    throw (
                        'The queued operation scheduler is unavailable.'
                    )
                }

                & $startOperationCommand `
                    -Action $nextOperation.Action `
                    -Parameters $nextOperation.Parameters `
                    -Description $nextOperation.Description `
                    -Completed $nextOperation.Completion `
                    -Operation $nextOperation

                return
            }
            catch {
                $null =
                    & $removeBackgroundOperationCommand `
                        -Operation $nextOperation

                [string]$queueError = (
                    'Queued application operation failed to start: {0}' -f
                    $_.Exception.Message
                )

                & $appendActivity $queueError
                & $setStatus $queueError

                if ($state.OperationQueue.Count -eq 0) {
                    $refreshInventoryCommand =
                        $state.RefreshInventory

                    if (
                        $refreshInventoryCommand -is
                        [scriptblock]
                    ) {
                        & $refreshInventoryCommand
                    }
                }
            }
        }
    }.GetNewClosure()

    $state.StartNextOperation =
        $startNextOperation

    $confirmAction = {
        param(
            [string]$Message
        )

        return (
            [System.Windows.MessageBox]::Show(
                $window,
                $Message,
                'Phoenix confirmation',
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Warning
            ) -eq [System.Windows.MessageBoxResult]::Yes
        )
    }.GetNewClosure()

    $showResults = {
        param(
            [string]$Action,
            [object[]]$Results,
            [bool]$ShowDialog = $true
        )

        [int]$successCount = @(
            $Results |
                Where-Object Success
        ).Count

        [int]$failureCount =
            $Results.Count - $successCount

        & $appendActivity (
            '{0}: {1} succeeded, {2} failed.' -f
            $Action,
            $successCount,
            $failureCount
        )

        foreach ($result in $Results) {
            & $appendActivity (
                '  [{0}] {1} - {2}' -f
                $result.Code,
                $result.Success,
                $result.Message
            )
        }

        if ($ShowDialog) {
            [void][System.Windows.MessageBox]::Show(
                $window,
                (
                    "{0}`n`nSucceeded: {1}`nFailed: {2}" -f
                    $Action,
                    $successCount,
                    $failureCount
                ),
                'Phoenix result',
                [System.Windows.MessageBoxButton]::OK,
                $(if ($failureCount -eq 0) {
                    [System.Windows.MessageBoxImage]::Information
                }
                else {
                    [System.Windows.MessageBoxImage]::Warning
                })
            )
        }
    }.GetNewClosure()

    $refreshInventory = {

        $inventoryState = $state
        $inventoryControls = $controls
        $inventorySetStatus = $setStatus
        $inventoryGetContext = $getContextCommand

        & $startOperation `
            -Action 'Inventory' `
            -Parameters ([pscustomobject]@{}) `
            -Description (
                'Collecting hardware, Windows, applications, and drivers...'
            ) `
            -Completed {
                param($inventory)

                $inventoryState.Inventory = $inventory

                $context =
                    & $inventoryGetContext `
                        -RequireInitialized

                foreach (
                    $providerStatus in @(
                        $inventoryState.Inventory.Providers
                    )
                ) {
                    $provider =
                        $context.Providers |
                            Where-Object {
                                $_.Name -eq $providerStatus.Name
                            } |
                            Select-Object -First 1

                    if ($null -eq $provider) {
                        continue
                    }

                    $provider.Available =
                        [bool]$providerStatus.Available

                    if (
                        -not [string]::IsNullOrWhiteSpace(
                            [string]$providerStatus.Version
                        )
                    ) {
                        $provider.Version =
                            [string]$providerStatus.Version
                    }
                }

                $summary = $inventoryState.Inventory.Summary

                $inventoryControls.HeaderSubtitle.Text = (
                    '{0} | {1} | Administrator: {2}' -f
                    $summary.ComputerName,
                    $summary.OperatingSystem,
                    $summary.Administrator
                )

                $inventoryControls.SystemSummaryText.Text = (
                    @(
                        "Computer     : $($summary.ComputerName)"
                        "Manufacturer : $($summary.Manufacturer)"
                        "Model        : $($summary.Model)"
                        "Processor    : $($summary.Processor)"
                        "Memory       : $($summary.MemoryGB) GB"
                        "Windows      : $($summary.OperatingSystem)"
                        "Version      : $($summary.OsVersion)"
                        "Build        : $($summary.OsBuild)"
                        "Architecture : $($summary.Architecture)"
                    ) -join [Environment]::NewLine
                )

                [int]$actionableCount = @(
                    @($inventoryState.Inventory.Applications) |
                        Where-Object Actionable
                ).Count

                [int]$problemDriverCount = @(
                    @($inventoryState.Inventory.Drivers) |
                        Where-Object HasProblem
                ).Count

                $inventoryControls.InventorySummaryText.Text = (
                    @(
                        "Phoenix state      : $($inventoryState.Inventory.Lifecycle.State)"
                        "Context generation : $($inventoryState.Inventory.Lifecycle.Generation)"
                        "Session            : $($inventoryState.Inventory.Lifecycle.SessionId.Substring(0, 8))"
                        "Runtime recovery   : $($inventoryState.Inventory.Lifecycle.RecoveryCode)"
                        "Recovered items    : $($inventoryState.Inventory.Lifecycle.RecoveryItemCount)"
                        "Last repair (UTC)  : $($inventoryState.Inventory.Lifecycle.LastRecoveryAtUtc)"
                        "Applications       : $(@($inventoryState.Inventory.Applications).Count)"
                        "Actionable apps    : $actionableCount"
                        "Installed drivers  : $(@($inventoryState.Inventory.Drivers).Count)"
                        "Problem drivers    : $problemDriverCount"
                        "Providers          : $(@($inventoryState.Inventory.Providers).Count)"
                        "Collected (UTC)     : $($inventoryState.Inventory.CollectedAtUtc)"
                    ) -join [Environment]::NewLine
                )

                $inventoryControls.InventoryWarningsText.Text =
                    @($inventoryState.Inventory.Warnings) -join
                        [Environment]::NewLine

                $inventoryControls.ProviderGrid.ItemsSource =
                    @($inventoryState.Inventory.Providers)

                $inventoryControls.ApplicationGrid.ItemsSource =
                    @($inventoryState.Inventory.Applications)

                $inventoryControls.DriverGrid.ItemsSource =
                    @($inventoryState.Inventory.Drivers)

                & $inventorySetStatus 'Inventory refresh completed.'

                $refreshUpdatesCommand =
                    $inventoryState.RefreshApplicationUpdates

                if ($refreshUpdatesCommand -is [scriptblock]) {
                    & $refreshUpdatesCommand
                }
            }.GetNewClosure()
    }.GetNewClosure()

    $state.RefreshInventory =
        $refreshInventory

    $getCheckedItems = {
        param(
            [object]$Grid
        )

        $selected = @(
            $Grid.ItemsSource |
                Where-Object IsSelected
        )

        if ($selected.Count -eq 0) {
            $selected = @($Grid.SelectedItems)
        }

        return @($selected)
    }.GetNewClosure()

    $runApplicationAction = {
        param(
            [string]$Action,
            [bool]$All
        )

        $items = if ($All) {
            @(
                $state.Inventory.Applications |
                    Where-Object {
                        $_.Actionable -and
                        (
                            $Action -ne 'Update' -or
                            $_.UpdateAvailable
                        )
                    }
            )
        }
        else {
            @(
                & $getCheckedItems $controls.ApplicationGrid |
                    Where-Object {
                        $_.Actionable -and
                        (
                            $Action -ne 'Update' -or
                            $_.UpdateAvailable
                        )
                    }
            )
        }

        if ($items.Count -eq 0) {
            [void][System.Windows.MessageBox]::Show(
                $window,
                'Select at least one actionable application.',
                'Phoenix applications',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            )

            return
        }

        if ($Action -eq 'Uninstall') {

            $protectedApplicationIds = @(
                'chocolatey'
                'chocolatey-compatibility.extension'
                'chocolatey-core.extension'
                'Microsoft.AppInstaller'
            )

            $protectedApplications = @(
                $items |
                    Where-Object {
                        [string]$_.Id -in
                            $protectedApplicationIds
                    }
            )

            if ($protectedApplications.Count -gt 0) {
                [void][System.Windows.MessageBox]::Show(
                    $window,
                    (
                        'Phoenix cannot uninstall its package-manager ' +
                        "components:`n`n" +
                        (
                            @($protectedApplications.Name) -join
                            [Environment]::NewLine
                        )
                    ),
                    'Protected Phoenix components',
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Warning
                )

                return
            }
        }

        [string]$applicationConfirmation =
            if ($Action -eq 'Uninstall') {
                (
                    "Uninstall $($items.Count) selected application(s)?`n`n" +
                    'This removes the applications and may remove ' +
                    'provider-managed dependencies.'
                )
            }
            else {
                "$Action $($items.Count) application(s)?"
            }

        if (
            -not (
                & $confirmAction $applicationConfirmation
            )
        ) {
            return
        }

        $packageDescriptors = @(
            foreach ($item in $items) {
                [pscustomobject]@{
                    Name         = $item.Name
                    Id           = $item.Id
                    Version      = $item.Version
                    Provider     = $item.Provider
                    Source       = $item.Source
                    Architecture = $item.Architecture
                }
            }
        )

        $applicationActionShowResults = $showResults
        $applicationActionRefreshInventory = $refreshInventory
        $applicationActionQueue = $state.OperationQueue

        & $startOperation `
            -Action 'PackageAction' `
            -QueueIfBusy `
            -Parameters ([pscustomobject]@{
                PackageAction = $Action
                Packages      = $packageDescriptors
            }) `
            -Description (
                "$Action is running for $($items.Count) application(s)..."
            ) `
            -Completed {
                param($results)

                [bool]$queueDrained =
                    $applicationActionQueue.Count -eq 0

                & $applicationActionShowResults `
                    "$Action applications" `
                    @($results) `
                    $queueDrained

                if ($queueDrained) {
                    & $applicationActionRefreshInventory
                }
            }.GetNewClosure()
    }.GetNewClosure()

    $refreshApplicationUpdates = {

        if ($null -eq $state.Inventory) {
            return
        }

        $applicationUpdateState = $state
        $applicationUpdateControls = $controls
        $applicationUpdateSetStatus = $setStatus

        & $startOperation `
            -Action 'ApplicationUpdates' `
            -Parameters ([pscustomobject]@{}) `
            -Description (
                'Checking WinGet and Chocolatey for application updates...'
            ) `
            -Completed {
                param($updates)

                $updatesByKey = @{}

                foreach ($update in @($updates)) {
                    [string]$key = (
                        '{0}|{1}' -f
                        [string]$update.Provider,
                        [string]$update.Id
                    )

                    $updatesByKey[$key] = $update
                }

                foreach (
                    $application in @(
                        $applicationUpdateState.Inventory.Applications
                    )
                ) {
                    [string]$key = (
                        '{0}|{1}' -f
                        [string]$application.Provider,
                        [string]$application.Id
                    )

                    $application.UpdateAvailable = $false
                    $application.AvailableVersion = ''
                    $application.UpdateStatus = 'Current'

                    if ($updatesByKey.ContainsKey($key)) {
                        $update = $updatesByKey[$key]
                        $application.UpdateAvailable = $true
                        $application.AvailableVersion =
                            [string]$update.AvailableVersion

                        $application.UpdateStatus =
                            [string]$update.UpdateStatus
                    }
                }

                $applicationUpdateControls.ApplicationGrid.Items.Refresh()

                [int]$updateCount = @(
                    @($applicationUpdateState.Inventory.Applications) |
                        Where-Object UpdateAvailable
                ).Count

                & $applicationUpdateSetStatus (
                    "Application update check completed: $updateCount update(s) available."
                )
            }.GetNewClosure()
    }.GetNewClosure()

    $state.RefreshApplicationUpdates =
        $refreshApplicationUpdates

    $showApplicationSelection = {

        $application =
            $controls.ApplicationGrid.SelectedItem

        $state.ApplicationReleaseUrl = ''
        $controls.OpenApplicationReleaseUrlButton.IsEnabled =
            $false

        if ($null -eq $application) {
            $controls.ApplicationDetailsText.Text =
                'Select an application to see update information.'

            return
        }

        $controls.ApplicationDetailsText.Text = (
            @(
                "Application: $($application.Name)"
                "Installed: $($application.Version)"
                "Available: $(if ($application.UpdateAvailable) { $application.AvailableVersion } else { 'No update found' })"
                "Provider: $($application.Provider)"
                "Metadata: $($application.MetadataStatus)"
                ''
                $(if (
                    [string]::IsNullOrWhiteSpace(
                        [string]$application.ReleaseNotes
                    )
                ) {
                    'Release details have not been loaded.'
                }
                else {
                    [string]$application.ReleaseNotes
                })
            ) -join [Environment]::NewLine
        )

        if (
            -not [string]::IsNullOrWhiteSpace(
                [string]$application.ReleaseNotesUrl
            )
        ) {
            $state.ApplicationReleaseUrl =
                [string]$application.ReleaseNotesUrl

            $controls.OpenApplicationReleaseUrlButton.IsEnabled =
                $true
        }
    }.GetNewClosure()

    $loadApplicationRelease = {

        $application =
            $controls.ApplicationGrid.SelectedItem

        if (
            $null -eq $application -or
            -not [bool]$application.UpdateAvailable
        ) {
            [void][System.Windows.MessageBox]::Show(
                $window,
                'Select an application that has an available update.',
                'Phoenix update details',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            )

            return
        }

        $releaseShowApplicationSelection =
            $showApplicationSelection

        $releaseControls = $controls
        $releaseSetStatus = $setStatus

        & $startOperation `
            -Action 'PackageRelease' `
            -Parameters ([pscustomobject]@{
                Id       = $application.Id
                Provider = $application.Provider
                Version  = $application.AvailableVersion
            }) `
            -Description (
                "Loading publisher update details for '$($application.Name)'..."
            ) `
            -Completed {
                param($release)

                $application.MetadataStatus =
                    [string]$release.MetadataStatus

                $application.ReleaseNotes =
                    if (
                        -not [string]::IsNullOrWhiteSpace(
                            [string]$release.ReleaseNotes
                        )
                    ) {
                        [string]$release.ReleaseNotes
                    }
                    elseif (
                        -not [string]::IsNullOrWhiteSpace(
                            [string]$release.ProviderMetadata
                        )
                    ) {
                        [string]$release.ProviderMetadata
                    }
                    else {
                        'Not provided by publisher.'
                    }

                $application.ReleaseNotesUrl =
                    [string]$release.ReleaseNotesUrl

                & $releaseShowApplicationSelection
                $releaseControls.ApplicationGrid.Items.Refresh()

                & $releaseSetStatus (
                    "Publisher metadata loaded for '$($application.Name)'."
                )
            }.GetNewClosure()
    }.GetNewClosure()

    $setEditMode = {
        param(
            [bool]$Enabled
        )

        $state.EditMode = $Enabled

        foreach ($tileId in $tileMap.Keys) {
            $tileMap[$tileId].SizeThumb.Visibility = if ($Enabled) {
                [System.Windows.Visibility]::Visible
            }
            else {
                [System.Windows.Visibility]::Collapsed
            }

            $tileMap[$tileId].DragThumb.Cursor = if ($Enabled) {
                [System.Windows.Input.Cursors]::SizeAll
            }
            else {
                [System.Windows.Input.Cursors]::Arrow
            }

            $tileMap[$tileId].Element.BorderBrush = if ($Enabled) {
                $window.Resources['PhoenixAccentBrush']
            }
            else {
                $window.Resources['PhoenixBorderBrush']
            }
        }

        $controls.EditLayoutButton.Visibility = if ($Enabled) {
            [System.Windows.Visibility]::Collapsed
        }
        else {
            [System.Windows.Visibility]::Visible
        }

        $controls.SaveLayoutButton.Visibility = if ($Enabled) {
            [System.Windows.Visibility]::Visible
        }
        else {
            [System.Windows.Visibility]::Collapsed
        }

        $controls.ResetLayoutButton.Visibility = if ($Enabled) {
            [System.Windows.Visibility]::Visible
        }
        else {
            [System.Windows.Visibility]::Collapsed
        }

        & $setStatus $(if ($Enabled) {
            'Layout editing enabled. Drag tile headers and use the corner handles to resize.'
        }
        else {
            'Layout editing finished.'
        })
    }.GetNewClosure()

    $saveUiConfiguration = {

        & $captureTileLayout

        $state.UiConfiguration.Window.Maximized =
            $window.WindowState -eq
                [System.Windows.WindowState]::Maximized

        if (
            $window.WindowState -eq
            [System.Windows.WindowState]::Normal
        ) {
            $state.UiConfiguration.Window.Width =
                [double]$window.Width

            $state.UiConfiguration.Window.Height =
                [double]$window.Height
        }

        return (
            & $saveUiConfigurationCommand `
                -Configuration $state.UiConfiguration `
                -Confirm:$false
        )
    }.GetNewClosure()

    foreach ($pageName in $pageMap.Keys) {
        $resolvedPageName = $pageName

        $pageMap[$pageName].Button.Add_Click({
            & $showPage $resolvedPageName
        }.GetNewClosure())
    }

    $controls.OpenAppsFromDashboardButton.Add_Click({
        & $showPage 'Applications'
    }.GetNewClosure())

    $controls.OpenDriversFromDashboardButton.Add_Click({
        & $showPage 'Drivers'
    }.GetNewClosure())

    $controls.OpenCustomizeFromDashboardButton.Add_Click({
        & $showPage 'Customize'
    }.GetNewClosure())

    foreach ($tileId in $tileMap.Keys) {

        $resolvedTileId = $tileId
        $tileDefinition = $tileMap[$tileId]

        $tileDefinition.DragThumb.Add_DragDelta({
            param(
                $sender,
                $event
            )

            if (-not $state.EditMode) {
                return
            }

            $resolvedTile =
                $tileMap[$resolvedTileId].Element

            [double]$left =
                [System.Windows.Controls.Canvas]::GetLeft(
                    $resolvedTile
                )

            [double]$top =
                [System.Windows.Controls.Canvas]::GetTop(
                    $resolvedTile
                )

            if ([double]::IsNaN($left)) {
                $left = 0
            }

            if ([double]::IsNaN($top)) {
                $top = 0
            }

            [double]$snapSize =
                [Math]::Max(
                    1.0,
                    [double]$state.UiConfiguration.Dashboard.SnapSize
                )

            [double]$newLeft =
                [Math]::Round(
                    (
                        $left +
                        [double]$event.HorizontalChange
                    ) / $snapSize
                ) * $snapSize

            [double]$newTop =
                [Math]::Round(
                    (
                        $top +
                        [double]$event.VerticalChange
                    ) / $snapSize
                ) * $snapSize

            $newLeft =
                [Math]::Max(
                    0.0,
                    [Math]::Min(
                        $newLeft,
                        $controls.DashboardCanvas.Width -
                            $resolvedTile.Width
                    )
                )

            $newTop =
                [Math]::Max(
                    0.0,
                    [Math]::Min(
                        $newTop,
                        $controls.DashboardCanvas.Height -
                            $resolvedTile.Height
                    )
                )

            [System.Windows.Controls.Canvas]::SetLeft(
                $resolvedTile,
                $newLeft
            )

            [System.Windows.Controls.Canvas]::SetTop(
                $resolvedTile,
                $newTop
            )
        }.GetNewClosure())

        $tileDefinition.SizeThumb.Add_DragDelta({
            param(
                $sender,
                $event
            )

            if (-not $state.EditMode) {
                return
            }

            $resolvedDefinition =
                $tileMap[$resolvedTileId]

            $resolvedTile =
                $resolvedDefinition.Element

            [double]$left =
                [System.Windows.Controls.Canvas]::GetLeft(
                    $resolvedTile
                )

            [double]$top =
                [System.Windows.Controls.Canvas]::GetTop(
                    $resolvedTile
                )

            if ([double]::IsNaN($left)) {
                $left = 0
            }

            if ([double]::IsNaN($top)) {
                $top = 0
            }

            [double]$snapSize =
                [Math]::Max(
                    1.0,
                    [double]$state.UiConfiguration.Dashboard.SnapSize
                )

            [double]$newWidth =
                [Math]::Round(
                    (
                        $resolvedTile.Width +
                        [double]$event.HorizontalChange
                    ) / $snapSize
                ) * $snapSize

            [double]$newHeight =
                [Math]::Round(
                    (
                        $resolvedTile.Height +
                        [double]$event.VerticalChange
                    ) / $snapSize
                ) * $snapSize

            $resolvedTile.Width =
                [Math]::Max(
                    $resolvedDefinition.MinimumWidth,
                    [Math]::Min(
                        $newWidth,
                        $controls.DashboardCanvas.Width -
                            $left
                    )
                )

            $resolvedTile.Height =
                [Math]::Max(
                    $resolvedDefinition.MinimumHeight,
                    [Math]::Min(
                        $newHeight,
                        $controls.DashboardCanvas.Height -
                            $top
                    )
                )
        }.GetNewClosure())
    }

    $controls.EditLayoutButton.Add_Click({
        & $setEditMode $true
    }.GetNewClosure())

    $controls.SaveLayoutButton.Add_Click({
        & $captureTileLayout
        [void](& $saveUiConfiguration)
        & $setEditMode $false
        & $setStatus 'Dashboard layout saved.'
    }.GetNewClosure())

    $controls.ResetLayoutButton.Add_Click({

        if (
            -not (
                & $confirmAction (
                    'Reset dashboard tile positions and sizes?'
                )
            )
        ) {
            return
        }

        $defaults =
            & $newUiConfigurationCommand

        $state.UiConfiguration.Dashboard =
            $defaults.Dashboard

        & $applyTileLayout
        & $loadCustomizationControls
        & $setStatus 'Dashboard layout reset. Select Save layout to keep it.'
    }.GetNewClosure())

    $controls.ColorRoleCombo.Add_SelectionChanged({
        & $loadColorEditor
    }.GetNewClosure())

    foreach (
        $colorSlider in @(
            $controls.RedColorSlider
            $controls.GreenColorSlider
            $controls.BlueColorSlider
        )
    ) {
        $colorSlider.Add_ValueChanged({
            & $updateColorEditor
        }.GetNewClosure())
    }

    $controls.ApplyThemeButton.Add_Click({

        try {
            $themeItem =
                $controls.ThemePresetCombo.SelectedItem

            if ($null -eq $themeItem) {
                return
            }

            $state.UiConfiguration.ThemeId =
                [string]$themeItem.Theme.Id

            $state.UiConfiguration.Appearance =
                $themeItem.Theme.Appearance

            & $setUiAppearanceCommand `
                -Window $window `
                -Appearance $state.UiConfiguration.Appearance

            $controls.NavigationColumn.Width =
                [System.Windows.GridLength]::new(
                    [double]$state.UiConfiguration.Appearance.NavigationWidth
                )

            & $loadCustomizationControls
            & $loadColorEditor
            [void](& $saveUiConfiguration)

            & $setStatus (
                "Theme '$($themeItem.Theme.Name)' applied and saved."
            )
        }
        catch {
            [void][System.Windows.MessageBox]::Show(
                $window,
                $_.Exception.Message,
                'Phoenix theme error',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error
            )
        }
    }.GetNewClosure())

    $controls.InstallThemeButton.Add_Click({

        $dialog =
            [Microsoft.Win32.OpenFileDialog]::new()

        $dialog.Title = 'Install a Phoenix theme'
        $dialog.Filter =
            'Phoenix themes (*.phxtheme)|*.phxtheme'

        if ($dialog.ShowDialog($window)) {
            try {
                $result =
                    & $installThemeCommand `
                        -LiteralPath $dialog.FileName `
                        -Confirm:$false

                & $loadThemes

                $controls.ThemePresetCombo.SelectedItem =
                    @($controls.ThemePresetCombo.ItemsSource) |
                        Where-Object {
                            $_.Theme.Id -ieq
                                [string]$result.Id
                        } |
                        Select-Object -First 1

                & $setStatus (
                    "Theme '$($result.Name)' installed. Select Apply theme to use it."
                )
            }
            catch {
                [void][System.Windows.MessageBox]::Show(
                    $window,
                    $_.Exception.Message,
                    'Phoenix theme installation failed',
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Error
                )
            }
        }
    }.GetNewClosure())

    $controls.OpenThemeStudioButton.Add_Click({

        [string]$projectRoot =
            Split-Path `
                -Path (
                    Split-Path `
                        -Path $PSScriptRoot `
                        -Parent
                ) `
                -Parent

        [string]$studioPath =
            Join-Path `
                $projectRoot `
                'Tools\Open-PhoenixThemeStudio.ps1'

        [string]$powerShellPath =
            (Get-Process -Id $PID).Path

        Start-Process `
            -FilePath $powerShellPath `
            -WorkingDirectory $projectRoot `
            -ArgumentList (
                '-NoLogo -NoProfile -ExecutionPolicy Bypass -STA ' +
                "-File `"$studioPath`""
            ) `
            -ErrorAction Stop
    }.GetNewClosure())

    $controls.ApplyAppearanceButton.Add_Click({
        try {
            & $applyCustomization
            & $setStatus 'Customization preview applied.'
        }
        catch {
            [void][System.Windows.MessageBox]::Show(
                $window,
                $_.Exception.Message,
                'Phoenix customization error',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error
            )
        }
    }.GetNewClosure())

    $controls.SaveAppearanceButton.Add_Click({
        try {
            & $applyCustomization
            [void](& $saveUiConfiguration)
            & $setStatus 'Interface customization saved.'
        }
        catch {
            [void][System.Windows.MessageBox]::Show(
                $window,
                $_.Exception.Message,
                'Phoenix customization error',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error
            )
        }
    }.GetNewClosure())

    $controls.ResetAppearanceButton.Add_Click({

        if (
            -not (
                & $confirmAction (
                    'Reset Phoenix colors, typography, and spacing?'
                )
            )
        ) {
            return
        }

        $defaults =
            & $newUiConfigurationCommand

        $state.UiConfiguration.Appearance =
            $defaults.Appearance

        $state.UiConfiguration.ThemeId =
            $defaults.ThemeId

        & $setUiAppearanceCommand `
            -Window $window `
            -Appearance $state.UiConfiguration.Appearance

        $controls.NavigationColumn.Width =
            [System.Windows.GridLength]::new(
                [double]$state.UiConfiguration.Appearance.NavigationWidth
            )

        & $loadCustomizationControls
        [void](& $saveUiConfiguration)
        & $setStatus 'Interface appearance reset and saved.'
    }.GetNewClosure())

    $controls.RefreshAllButton.Add_Click({
        $null =
            & $invokeSafeUiAction `
                -Component 'Inventory' `
                -Operation 'Refresh' `
                -Action $refreshInventory `
                -RetryAction $refreshInventory
    }.GetNewClosure())

    $controls.RefreshAppUpdatesButton.Add_Click({
        $null =
            & $invokeSafeUiAction `
                -Component 'ApplicationUpdates' `
                -Operation 'Refresh' `
                -Action $refreshApplicationUpdates `
                -RetryAction $refreshApplicationUpdates
    }.GetNewClosure())

    $controls.ViewAppUpdateDetailsButton.Add_Click({
        $null =
            & $invokeSafeUiAction `
                -Component 'ApplicationDetails' `
                -Operation 'LoadReleaseMetadata' `
                -Action $loadApplicationRelease `
                -RetryAction $loadApplicationRelease
    }.GetNewClosure())

    $controls.ApplicationGrid.Add_SelectionChanged({
        & $showApplicationSelection
    }.GetNewClosure())

    $controls.OpenApplicationReleaseUrlButton.Add_Click({
        if (
            $state.ApplicationReleaseUrl -match
            '^https?://'
        ) {
            Start-Process `
                -FilePath $state.ApplicationReleaseUrl `
                -ErrorAction Stop
        }
    }.GetNewClosure())

    $controls.UpdateSelectedAppsButton.Add_Click({
        & $runApplicationAction 'Update' $false
    }.GetNewClosure())

    $controls.UpdateAllAppsButton.Add_Click({
        & $runApplicationAction 'Update' $true
    }.GetNewClosure())

    $controls.RepairSelectedAppsButton.Add_Click({
        & $runApplicationAction 'Repair' $false
    }.GetNewClosure())

    $controls.RepairAllAppsButton.Add_Click({
        & $runApplicationAction 'Repair' $true
    }.GetNewClosure())

    $controls.UninstallSelectedAppsButton.Add_Click({
        & $runApplicationAction 'Uninstall' $false
    }.GetNewClosure())

    $controls.SearchAppsButton.Add_Click({

        [string]$query =
            $controls.AppSearchText.Text

        if ([string]::IsNullOrWhiteSpace($query)) {
            return
        }

        $searchState = $state
        $searchControls = $controls
        $searchSetStatus = $setStatus

        & $startOperation `
            -Action 'SearchPackages' `
            -Parameters ([pscustomobject]@{
                Query = $query
            }) `
            -Description (
                "Searching WinGet and Chocolatey for '$query'..."
            ) `
            -Completed {
                param($results)

                $searchState.SearchResult = @($results)

                foreach ($result in $searchState.SearchResult) {
                    if (
                        $null -eq $result.PSObject.Properties[
                            'IsSelected'
                        ]
                    ) {
                        $result |
                            Add-Member `
                                -MemberType NoteProperty `
                                -Name IsSelected `
                                -Value $false
                    }
                }

                $searchControls.SearchResultGrid.ItemsSource =
                    @($searchState.SearchResult)

                & $searchSetStatus (
                    "Application search returned $($searchState.SearchResult.Count) result(s)."
                )
            }.GetNewClosure()
    }.GetNewClosure())

    $installSearchResults = {
        param(
            [bool]$All
        )

        $items = if ($All) {
            @($state.SearchResult)
        }
        else {
            @(
                & $getCheckedItems $controls.SearchResultGrid
            )
        }

        if ($items.Count -eq 0) {
            [void][System.Windows.MessageBox]::Show(
                $window,
                'Select at least one search result.',
                'Phoenix application search',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            )

            return
        }

        if (
            -not (
                & $confirmAction (
                    "Install $($items.Count) application(s)?"
                )
            )
        ) {
            return
        }

        $packageDescriptors = @(
            foreach ($item in $items) {
                [pscustomobject]@{
                    Name         = $item.Name
                    Id           = $item.Id
                    Version      = $item.Version
                    Provider     = $item.Provider
                    Source       = $item.Source
                    Architecture = $item.Architecture
                }
            }
        )

        $searchInstallShowResults = $showResults
        $searchInstallRefreshInventory = $refreshInventory
        $searchInstallQueue = $state.OperationQueue

        & $startOperation `
            -Action 'PackageAction' `
            -QueueIfBusy `
            -Parameters ([pscustomobject]@{
                PackageAction = 'Install'
                Packages      = $packageDescriptors
            }) `
            -Description (
                "Installing $($items.Count) application(s)..."
            ) `
            -Completed {
                param($results)

                [bool]$queueDrained =
                    $searchInstallQueue.Count -eq 0

                & $searchInstallShowResults `
                    'Install applications' `
                    @($results) `
                    $queueDrained

                if ($queueDrained) {
                    & $searchInstallRefreshInventory
                }
            }.GetNewClosure()
    }.GetNewClosure()

    $controls.InstallSelectedSearchButton.Add_Click({
        & $installSearchResults $false
    }.GetNewClosure())

    $controls.InstallAllSearchButton.Add_Click({
        & $installSearchResults $true
    }.GetNewClosure())

    $controls.ScanDriverUpdatesButton.Add_Click({

        $driverScanState = $state
        $driverScanControls = $controls
        $driverScanSetStatus = $setStatus

        & $startOperation `
            -Action 'DriverAction' `
            -Parameters ([pscustomobject]@{
                DriverAction = 'ScanUpdates'
                UpdateId     = @()
                InfName      = @()
            }) `
            -Description (
                'Scanning Windows Update for applicable drivers...'
            ) `
            -Completed {
                param($results)

                $scanResult =
                    @($results) |
                        Select-Object -Last 1

                $driverScanState.DriverUpdate = @(
                    foreach (
                        $update in @(
                            $scanResult.Data.Updates
                        )
                    ) {
                        if (
                            [string]::IsNullOrWhiteSpace(
                                [string]$update.UpdateId
                            )
                        ) {
                            continue
                        }

                        $installedDriver =
                            @($driverScanState.Inventory.Drivers) |
                                Where-Object {
                                    -not [string]::IsNullOrWhiteSpace(
                                        [string]$update.DriverModel
                                    ) -and
                                    (
                                        [string]$_.Name -like
                                        "*$($update.DriverModel)*"
                                    )
                                } |
                                Select-Object -First 1

                        [pscustomobject]@{
                            IsSelected = $false
                            Title = $update.Title
                            UpdateId = $update.UpdateId
                            RevisionNumber = $update.RevisionNumber
                            DriverClass = $update.DriverClass
                            DriverManufacturer = $update.DriverManufacturer
                            DriverModel = $update.DriverModel
                            InstalledVersion = if (
                                $null -ne $installedDriver
                            ) {
                                [string]$installedDriver.Version
                            }
                            else {
                                'Not correlated'
                            }
                            AvailableVersion = if (
                                -not [string]::IsNullOrWhiteSpace(
                                    [string]$update.DriverVersion
                                )
                            ) {
                                [string]$update.DriverVersion
                            }
                            else {
                                'See update title'
                            }
                            DriverVersionDate = $update.DriverVersionDate
                            Description = $update.Description
                            ReleaseNotes = $update.ReleaseNotes
                            SupportUrl = $update.SupportUrl
                            MoreInfoUrls = @($update.MoreInfoUrls)
                            KBArticleIds = @($update.KBArticleIds)
                            PublishedAtUtc = $update.PublishedAtUtc
                            PublishedDisplay = if (
                                [string]::IsNullOrWhiteSpace(
                                    [string]$update.PublishedAtUtc
                                )
                            ) {
                                ''
                            }
                            else {
                                ([datetime]$update.PublishedAtUtc).ToString(
                                    'yyyy-MM-dd'
                                )
                            }
                            MinimumDownloadSize = $update.MinimumDownloadSize
                            MaximumDownloadSize = $update.MaximumDownloadSize
                            MetadataStatus = $update.MetadataStatus
                            Status = $update.Status
                        }
                    }
                )

                $driverScanControls.DriverUpdateGrid.ItemsSource =
                    @($driverScanState.DriverUpdate)

                & $driverScanSetStatus (
                    "Driver scan found $($driverScanState.DriverUpdate.Count) applicable update(s)."
                )
            }.GetNewClosure()
    }.GetNewClosure())

    $showDriverSelection = {

        $update =
            $controls.DriverUpdateGrid.SelectedItem

        $state.DriverReleaseUrl = ''
        $controls.OpenDriverReleaseUrlButton.IsEnabled =
            $false

        if ($null -eq $update) {
            $controls.DriverDetailsText.Text =
                'Select a Windows Update driver to see publisher details.'

            return
        }

        [string]$notes = if (
            -not [string]::IsNullOrWhiteSpace(
                [string]$update.ReleaseNotes
            )
        ) {
            [string]$update.ReleaseNotes
        }
        elseif (
            -not [string]::IsNullOrWhiteSpace(
                [string]$update.Description
            )
        ) {
            [string]$update.Description
        }
        else {
            'Not provided by publisher.'
        }

        [string]$url =
            [string]$update.SupportUrl

        if (
            [string]::IsNullOrWhiteSpace($url)
        ) {
            $url =
                @($update.MoreInfoUrls) |
                    Where-Object {
                        $_ -match '^https?://'
                    } |
                    Select-Object -First 1
        }

        $controls.DriverDetailsText.Text = (
            @(
                "Update: $($update.Title)"
                "Manufacturer: $($update.DriverManufacturer)"
                "Model: $($update.DriverModel)"
                "Class: $($update.DriverClass)"
                "Installed version: $($update.InstalledVersion)"
                "Available version: $($update.AvailableVersion)"
                "Published: $($update.PublishedDisplay)"
                "KB article(s): $(@($update.KBArticleIds) -join ', ')"
                "Metadata: $($update.MetadataStatus)"
                ''
                $notes
            ) -join [Environment]::NewLine
        )

        if (
            -not [string]::IsNullOrWhiteSpace($url)
        ) {
            $state.DriverReleaseUrl = $url
            $controls.OpenDriverReleaseUrlButton.IsEnabled =
                $true
        }
    }.GetNewClosure()

    $controls.DriverUpdateGrid.Add_SelectionChanged({
        & $showDriverSelection
    }.GetNewClosure())

    $controls.OpenDriverReleaseUrlButton.Add_Click({
        if ($state.DriverReleaseUrl -match '^https?://') {
            Start-Process `
                -FilePath $state.DriverReleaseUrl `
                -ErrorAction Stop
        }
    }.GetNewClosure())

    $controls.InstallSelectedDriversButton.Add_Click({

        $items = @(
            & $getCheckedItems $controls.DriverUpdateGrid
        )

        if ($items.Count -eq 0) {
            [void][System.Windows.MessageBox]::Show(
                $window,
                'Select at least one driver update.',
                'Phoenix drivers',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            )

            return
        }

        if (
            -not (
                & $confirmAction (
                    "Install $($items.Count) selected driver update(s)?"
                )
            )
        ) {
            return
        }

        $selectedDriverShowResults = $showResults
        $selectedDriverRefreshInventory = $refreshInventory

        & $startOperation `
            -Action 'DriverAction' `
            -Parameters ([pscustomobject]@{
                DriverAction = 'InstallSelected'
                UpdateId     = @($items.UpdateId)
                InfName      = @()
            }) `
            -Description 'Installing selected driver updates...' `
            -Completed {
                param($results)

                & $selectedDriverShowResults `
                    'Install selected driver updates' `
                    @($results)

                & $selectedDriverRefreshInventory
            }.GetNewClosure()
    }.GetNewClosure())

    $controls.UpdateAllDriversButton.Add_Click({

        if (
            -not (
                & $confirmAction (
                    'Install every applicable Windows Update driver?'
                )
            )
        ) {
            return
        }

        $allDriverShowResults = $showResults
        $allDriverRefreshInventory = $refreshInventory

        & $startOperation `
            -Action 'DriverAction' `
            -Parameters ([pscustomobject]@{
                DriverAction = 'UpdateAll'
                UpdateId     = @()
                InfName      = @()
            }) `
            -Description (
                'Installing all applicable driver updates...'
            ) `
            -Completed {
                param($results)

                & $allDriverShowResults `
                    'Update all drivers' `
                    @($results)

                & $allDriverRefreshInventory
            }.GetNewClosure()
    }.GetNewClosure())

    $controls.RepairSelectedDriversButton.Add_Click({

        $items = @(
            & $getCheckedItems $controls.DriverGrid
        )

        if ($items.Count -eq 0) {
            [void][System.Windows.MessageBox]::Show(
                $window,
                'Select at least one installed driver.',
                'Phoenix drivers',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            )

            return
        }

        if (
            -not (
                & $confirmAction (
                    "Reinstall $($items.Count) selected driver package(s)?"
                )
            )
        ) {
            return
        }

        $repairSelectedDriverShowResults = $showResults
        $repairSelectedDriverRefreshInventory = $refreshInventory

        & $startOperation `
            -Action 'DriverAction' `
            -Parameters ([pscustomobject]@{
                DriverAction = 'RepairSelected'
                UpdateId     = @()
                InfName      = @($items.InfName)
            }) `
            -Description 'Repairing selected driver packages...' `
            -Completed {
                param($results)

                & $repairSelectedDriverShowResults `
                    'Repair selected drivers' `
                    @($results)

                & $repairSelectedDriverRefreshInventory
            }.GetNewClosure()
    }.GetNewClosure())

    $controls.UninstallSelectedDriversButton.Add_Click({

        $items = @(
            & $getCheckedItems $controls.DriverGrid
        )

        if ($items.Count -eq 0) {
            [void][System.Windows.MessageBox]::Show(
                $window,
                'Select at least one installed driver.',
                'Phoenix drivers',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            )

            return
        }

        $protectedDrivers = @(
            $items |
                Where-Object {
                    [string]$_.InfName -notmatch
                        '^(?i:oem\d+\.inf)$'
                }
        )

        if ($protectedDrivers.Count -gt 0) {
            [void][System.Windows.MessageBox]::Show(
                $window,
                (
                    'Phoenix only uninstalls third-party oem#.inf ' +
                    'packages. Deselect built-in or unrecognized drivers.'
                ),
                'Protected Windows drivers',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Warning
            )

            return
        }

        $selectedInfNames = @(
            $items.InfName |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace($_)
                } |
                Sort-Object -Unique
        )

        if (
            -not (
                & $confirmAction (
                    (
                        "Uninstall $($selectedInfNames.Count) selected " +
                        "driver package(s)?`n`n" +
                        'Devices using these packages may temporarily stop ' +
                        'working. Phoenix will not force-remove a driver ' +
                        'that Windows reports is still required.'
                    )
                )
            )
        ) {
            return
        }

        $removeDriverShowResults = $showResults
        $removeDriverRefreshInventory = $refreshInventory

        & $startOperation `
            -Action 'DriverAction' `
            -Parameters ([pscustomobject]@{
                DriverAction = 'RemoveSelected'
                UpdateId     = @()
                InfName      = @($selectedInfNames)
            }) `
            -Description (
                "Uninstalling $($selectedInfNames.Count) driver package(s)..."
            ) `
            -Completed {
                param($results)

                & $removeDriverShowResults `
                    'Uninstall selected drivers' `
                    @($results)

                & $removeDriverRefreshInventory
            }.GetNewClosure()
    }.GetNewClosure())

    $controls.RepairProblemDriversButton.Add_Click({

        $problemCount = @(
            $state.Inventory.Drivers |
                Where-Object HasProblem
        ).Count

        if ($problemCount -eq 0) {
            [void][System.Windows.MessageBox]::Show(
                $window,
                'No problem drivers were detected.',
                'Phoenix drivers',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            )

            return
        }

        if (
            -not (
                & $confirmAction (
                    "Repair all $problemCount problem driver(s)?"
                )
            )
        ) {
            return
        }

        $repairProblemDriverShowResults = $showResults
        $repairProblemDriverRefreshInventory = $refreshInventory

        & $startOperation `
            -Action 'DriverAction' `
            -Parameters ([pscustomobject]@{
                DriverAction = 'RepairProblems'
                UpdateId     = @()
                InfName      = @()
            }) `
            -Description 'Repairing problem drivers...' `
            -Completed {
                param($results)

                & $repairProblemDriverShowResults `
                    'Repair problem drivers' `
                    @($results)

                & $repairProblemDriverRefreshInventory
            }.GetNewClosure()
    }.GetNewClosure())

    $controls.RecoveryRetryButton.Add_Click({

        $retryAction =
            $state.RecoveryAction

        $failure =
            $state.LastFailure

        if (
            $null -eq $retryAction -or
            $null -eq $failure
        ) {
            return
        }

        $retryResult =
            & $invokeSafeUiAction `
                -Component (
                    [string]$failure.Data.Component
                ) `
                -Operation (
                    'Retry{0}' -f
                    [string]$failure.Data.Operation
                ) `
                -Action $retryAction `
                -RetryAction $retryAction

        if ([bool]$retryResult.Success) {
            & $hideRecovery
            & $setStatus 'The Control Center component recovered successfully.'
        }
    }.GetNewClosure())

    $controls.RecoveryDetailsButton.Add_Click({

        $failure =
            $state.LastFailure

        if ($null -eq $failure) {
            return
        }

        [string]$details = (
            @(
                "Code: $($failure.Code)"
                "Failure ID: $($failure.Data.FailureId)"
                "Time (UTC): $($failure.Data.TimestampUtc)"
                "Component: $($failure.Data.Component)"
                "Operation: $($failure.Data.Operation)"
                "Exception: $($failure.Data.ExceptionType)"
                ''
                [string]$failure.Message
                ''
                [string]$failure.Data.PositionMessage
                [string]$failure.Data.ScriptStackTrace
                ''
                "Journal: $($failure.Data.JournalPath)"
            ) -join [Environment]::NewLine
        ).Trim()

        [void][System.Windows.MessageBox]::Show(
            $window,
            $details,
            'Phoenix recovery details',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning
        )
    }.GetNewClosure())

    $controls.RecoveryDismissButton.Add_Click({
        & $hideRecovery
        & $setStatus 'The isolated interface error was dismissed.'
    }.GetNewClosure())

    $controls.CancelOperationButton.Add_Click({

        $operation =
            $state.ActiveOperation

        if ($null -eq $operation) {
            return
        }

        if (
            -not (
                & $confirmAction (
                    "Cancel '$($operation.Description)'?"
                )
            )
        ) {
            return
        }

        try {
            $null =
                & $stopBackgroundOperationCommand `
                    -Operation $operation
        }
        catch {
            & $appendActivity (
                'Worker stop notice: {0}' -f
                $_.Exception.Message
            )
        }
        finally {
            $state.ActiveOperation = $null
            & $setOperationUi $false

            $null =
                & $removeBackgroundOperationCommand `
                    -Operation $operation

            if (
                $operation.State.ToString() -eq
                'Cancelled'
            ) {
                & $setStatus 'The active operation was cancelled.'
            }
            else {
                & $setStatus (
                    'The active operation could not be cancelled cleanly.'
                )
            }

            if (
                $operation.Action -eq 'PackageAction' -and
                $state.OperationQueue.Count -eq 0
            ) {
                $refreshInventoryCommand =
                    $state.RefreshInventory

                if (
                    $refreshInventoryCommand -is
                    [scriptblock]
                ) {
                    & $refreshInventoryCommand
                }
            }

            $startNextOperationCommand =
                $state.StartNextOperation

            if (
                $startNextOperationCommand -is
                [scriptblock]
            ) {
                & $startNextOperationCommand
            }
        }
    }.GetNewClosure())

    $controls.AppSearchText.Add_KeyDown({
        param(
            $sender,
            $event
        )

        if ($event.Key -eq 'Enter') {
            $controls.SearchAppsButton.RaiseEvent(
                [System.Windows.RoutedEventArgs]::new(
                    [System.Windows.Controls.Button]::ClickEvent
                )
            )
        }
    }.GetNewClosure())

    & $loadThemes
    & $applyTileLayout
    & $loadCustomizationControls
    & $loadColorEditor
    & $showPage 'Overview'

    foreach ($tileId in $tileMap.Keys) {
        $tileMap[$tileId].DragThumb.Cursor =
            [System.Windows.Input.Cursors]::Arrow
    }

    $window.Add_ContentRendered({
        $null =
            & $invokeSafeUiAction `
                -Component 'Inventory' `
                -Operation 'InitialRefresh' `
                -Action $refreshInventory `
                -RetryAction $refreshInventory
    }.GetNewClosure())

    $window.Add_Closing({
        param(
            $sender,
            $event
        )

        if ($null -ne $state.ActiveOperation) {
            $closingOperation =
                $state.ActiveOperation

            try {
                $null =
                    & $stopBackgroundOperationCommand `
                        -Operation $closingOperation
            }
            catch {
                Write-Warning (
                    'The active Control Center worker could not be stopped: {0}' -f
                    $_.Exception.Message
                )
            }
            finally {
                $null =
                    & $removeBackgroundOperationCommand `
                        -Operation $closingOperation

                $state.ActiveOperation = $null
            }
        }

        while ($state.OperationQueue.Count -gt 0) {
            $queuedOperation =
                $state.OperationQueue.Dequeue()

            try {
                if (-not $queuedOperation.IsTerminal()) {
                    $queuedOperation.MarkCancelled()
                }
            }
            catch {
                Write-Warning (
                    'A queued Control Center operation could not be ' +
                    'cancelled cleanly: {0}' -f
                    $_.Exception.Message
                )
            }
            finally {
                $null =
                    & $removeBackgroundOperationCommand `
                        -Operation $queuedOperation
            }
        }

        try {
            [void](& $saveUiConfiguration)
        }
        catch {
            Write-Warning (
                'Phoenix UI settings were not saved: {0}' -f
                $_.Exception.Message
            )
        }
    }.GetNewClosure())

    try {
        [void]$window.ShowDialog()
    }
    finally {
        $window.Dispatcher.remove_UnhandledException(
            $dispatcherExceptionHandler
        )
    }
}
