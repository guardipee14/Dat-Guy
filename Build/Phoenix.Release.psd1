@{
    SchemaVersion = '1.0'

    ProductName = 'Phoenix'

    LicenseExpression = (
        'MIT OR Apache-2.0 OR GPL-3.0-or-later'
    )

    MinimumPowerShellVersion = '7.4.0'
    MinimumWindowsBuild      = 10240

    RuntimePaths = @(
        'Classes\Phoenix.Classes.psm1'
        'Config\Phoenix.json'
        'Config\Phoenix.UI.json'
        'Config\Settings.json'
        'Docs'
        'Private'
        'Public'
        'Themes\BuiltIn'
        'Themes\README.md'
        'Tools\Invoke-PhoenixControlCenterWorker.ps1'
        'Tools\Open-PhoenixThemeStudio.ps1'
        'Tools\Start-PhoenixControlCenter.ps1'
        'Phoenix.psd1'
        'Phoenix.psm1'
        'Phoenix.cmd'
        'Phoenix-Desktop.cmd'
        'Phoenix-Console.cmd'
        'Phoenix-Theme-Studio.cmd'
        'README.md'
        'ROADMAP.md'
        'CHANGELOG.md'
        'LICENSE.txt'
        'LICENSES'
    )

    ExcludedFilePatterns = @(
        '*.disabled'
        '*.tmp'
        '*.bak'
        '*.log'
        '*.clixml'
    )

    PreserveOnUpgrade = @(
        'Config\Phoenix.json'
        'Config\Phoenix.UI.json'
        'Config\Settings.json'
        'Config\Recovery'
        'Cache\ControlCenter'
        'Cache\Recovery'
        'Checkpoints'
        'Logs'
        'Themes\Installed'
    )
}
