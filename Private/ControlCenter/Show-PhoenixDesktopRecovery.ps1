function Show-PhoenixDesktopRecovery {

    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]$Failure
    )

    if (-not $IsWindows) {
        return 'Console'
    }

    Add-Type `
        -AssemblyName PresentationFramework `
        -ErrorAction Stop

    [string]$recoveryXaml = @'
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Phoenix Desktop Recovery"
    Width="720"
    Height="460"
    MinWidth="620"
    MinHeight="400"
    WindowStartupLocation="CenterScreen"
    Background="#0B1220"
    Foreground="#F5F7FB"
    FontFamily="Segoe UI"
    FontSize="13">
    <Grid Margin="28">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto" />
            <RowDefinition Height="Auto" />
            <RowDefinition Height="*" />
            <RowDefinition Height="Auto" />
        </Grid.RowDefinitions>
        <TextBlock
            Grid.Row="0"
            Text="Phoenix Desktop Recovery"
            FontSize="28"
            FontWeight="SemiBold" />
        <TextBlock
            Grid.Row="1"
            Margin="0,8,0,18"
            Text="The main Control Center could not finish starting. Phoenix recorded the failure and can recover without changing application, driver, or restore data."
            TextWrapping="Wrap"
            Foreground="#9FB0C9" />
        <Border
            Grid.Row="2"
            Padding="18"
            CornerRadius="10"
            Background="#142035"
            BorderBrush="#2A3A55"
            BorderThickness="1">
            <ScrollViewer VerticalScrollBarVisibility="Auto">
                <TextBlock
                    x:Name="RecoveryDetailsText"
                    TextWrapping="Wrap"
                    FontFamily="Consolas"
                    FontSize="12" />
            </ScrollViewer>
        </Border>
        <WrapPanel
            Grid.Row="3"
            Margin="0,20,0,0"
            HorizontalAlignment="Right">
            <Button
                x:Name="RetryButton"
                MinWidth="105"
                Margin="6,0"
                Padding="14,9"
                Content="Retry desktop" />
            <Button
                x:Name="ResetButton"
                MinWidth="130"
                Margin="6,0"
                Padding="14,9"
                Content="Use safe layout" />
            <Button
                x:Name="ConsoleButton"
                MinWidth="105"
                Margin="6,0"
                Padding="14,9"
                Content="Open console" />
            <Button
                x:Name="CloseButton"
                MinWidth="85"
                Margin="6,0"
                Padding="14,9"
                Content="Close" />
        </WrapPanel>
    </Grid>
</Window>
'@

    $window =
        [System.Windows.Markup.XamlReader]::Parse(
            $recoveryXaml
        )

    $detailsText =
        $window.FindName('RecoveryDetailsText')

    $retryButton =
        $window.FindName('RetryButton')

    $resetButton =
        $window.FindName('ResetButton')

    $consoleButton =
        $window.FindName('ConsoleButton')

    $closeButton =
        $window.FindName('CloseButton')

    $detailsText.Text = (
        @(
            "Code: $($Failure.Code)"
            "Component: $($Failure.Data.Component)"
            "Operation: $($Failure.Data.Operation)"
            "Time (UTC): $($Failure.Data.TimestampUtc)"
            "Failure ID: $($Failure.Data.FailureId)"
            ''
            [string]$Failure.Message
            ''
            [string]$Failure.Data.PositionMessage
            [string]$Failure.Data.ScriptStackTrace
        ) -join [Environment]::NewLine
    ).Trim()

    $recoveryState = [pscustomobject]@{
        Selection = 'Close'
    }

    $retryButton.Add_Click({
        $recoveryState.Selection = 'Retry'
        $window.DialogResult = $true
    }.GetNewClosure())

    $resetButton.Add_Click({
        $recoveryState.Selection = 'Reset'
        $window.DialogResult = $true
    }.GetNewClosure())

    $consoleButton.Add_Click({
        $recoveryState.Selection = 'Console'
        $window.DialogResult = $true
    }.GetNewClosure())

    $closeButton.Add_Click({
        $recoveryState.Selection = 'Close'
        $window.DialogResult = $false
    }.GetNewClosure())

    [void]$window.ShowDialog()

    return [string]$recoveryState.Selection
}
