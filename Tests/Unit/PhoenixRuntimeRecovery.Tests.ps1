BeforeAll {

    $projectRoot = (
        Resolve-Path (
            Join-Path `
                $PSScriptRoot `
                '..\..'
        )
    ).Path

    Import-Module `
        -Name (
            Join-Path `
                $projectRoot `
                'Phoenix.psd1'
        ) `
        -Force `
        -ErrorAction Stop `
        6>$null
}

AfterAll {
    Remove-Module `
        -Name Phoenix `
        -Force `
        -ErrorAction SilentlyContinue
}

Describe 'Phoenix runtime recovery' -Tag @(
    'Unit'
    'Recovery'
) {

    It 'creates every required runtime directory and configuration file' {

        [string]$runtimeRoot =
            Join-Path `
                $TestDrive `
                'MissingRuntime'

        New-Item `
            -ItemType Directory `
            -Path $runtimeRoot `
            -Force |
            Out-Null

        $result =
            InModuleScope Phoenix `
                -Parameters @{
                    RecoveryProjectRoot = $runtimeRoot
                } {
                    param($RecoveryProjectRoot)

                    Initialize-PhoenixRuntimeRecovery `
                        -ProjectRoot $RecoveryProjectRoot
                }

        $result.Success |
            Should-BeTrue

        $result.Recovered |
            Should-BeTrue

        $result.Code |
            Should-Be 'PHX_RUNTIME_RECOVERED'

        foreach (
            $relativePath in @(
                'Config'
                'Config\Recovery'
                'Logs'
                'Cache\Working'
                'Cache\Packages'
                'Cache\ControlCenter\Jobs'
                'Cache\Recovery'
                'Checkpoints'
                'Drivers'
                'Themes\BuiltIn'
                'Themes\Installed'
                'Config\Phoenix.json'
                'Config\Settings.json'
                'Config\Phoenix.UI.json'
            )
        ) {
            Test-Path `
                -LiteralPath (
                    Join-Path `
                        $runtimeRoot `
                        $relativePath
                ) |
                Should-BeTrue
        }
    }

    It 'is idempotent after the runtime is healthy' {

        [string]$runtimeRoot =
            Join-Path `
                $TestDrive `
                'IdempotentRuntime'

        New-Item `
            -ItemType Directory `
            -Path $runtimeRoot `
            -Force |
            Out-Null

        $results =
            InModuleScope Phoenix `
                -Parameters @{
                    RecoveryProjectRoot = $runtimeRoot
                } {
                    param($RecoveryProjectRoot)

                    $first =
                        Initialize-PhoenixRuntimeRecovery `
                            -ProjectRoot $RecoveryProjectRoot

                    $second =
                        Initialize-PhoenixRuntimeRecovery `
                            -ProjectRoot $RecoveryProjectRoot

                    @(
                        $first
                        $second
                    )
                }

        $results[0].Recovered |
            Should-BeTrue

        $results[1].Recovered |
            Should-BeFalse

        $results[1].Code |
            Should-Be 'PHX_RUNTIME_READY'

        @($results[1].CreatedDirectories).Count |
            Should-Be 0

        @($results[1].RepairedFiles).Count |
            Should-Be 0
    }

    It 'backs up malformed JSON before restoring safe defaults' {

        [string]$runtimeRoot =
            Join-Path `
                $TestDrive `
                'CorruptConfiguration'

        [string]$configRoot =
            Join-Path `
                $runtimeRoot `
                'Config'

        New-Item `
            -ItemType Directory `
            -Path $configRoot `
            -Force |
            Out-Null

        '{ invalid JSON' |
            Set-Content `
                -LiteralPath (
                    Join-Path `
                        $configRoot `
                        'Phoenix.json'
                ) `
                -Encoding UTF8

        $result =
            InModuleScope Phoenix `
                -Parameters @{
                    RecoveryProjectRoot = $runtimeRoot
                } {
                    param($RecoveryProjectRoot)

                    Initialize-PhoenixRuntimeRecovery `
                        -ProjectRoot $RecoveryProjectRoot
                }

        $configuration =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $configRoot `
                        'Phoenix.json'
                ) `
                -Raw |
            ConvertFrom-Json

        $configuration.LogLevel |
            Should-Be 'Info'

        @(
            Get-ChildItem `
                -LiteralPath (
                    Join-Path `
                        $configRoot `
                        'Recovery'
                ) `
                -Filter 'Phoenix.corrupt-*.json' `
                -File
        ).Count |
            Should-Be 1

        @($result.Backups).Count |
            Should-Be 1
    }

    It 'fills missing defaults without discarding custom settings' {

        [string]$runtimeRoot =
            Join-Path `
                $TestDrive `
                'PartialConfiguration'

        [string]$configRoot =
            Join-Path `
                $runtimeRoot `
                'Config'

        New-Item `
            -ItemType Directory `
            -Path $configRoot `
            -Force |
            Out-Null

        [pscustomobject]@{
            LogLevel    = 'Debug'
            CustomValue = 'Keep this value'
        } |
            ConvertTo-Json |
            Set-Content `
                -LiteralPath (
                    Join-Path `
                        $configRoot `
                        'Phoenix.json'
                ) `
                -Encoding UTF8

        $null =
            InModuleScope Phoenix `
                -Parameters @{
                    RecoveryProjectRoot = $runtimeRoot
                } {
                    param($RecoveryProjectRoot)

                    Initialize-PhoenixRuntimeRecovery `
                        -ProjectRoot $RecoveryProjectRoot
                }

        $configuration =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $configRoot `
                        'Phoenix.json'
                ) `
                -Raw |
            ConvertFrom-Json

        $configuration.LogLevel |
            Should-Be 'Debug'

        $configuration.MaximumLogFiles |
            Should-Be 20

        $configuration.CustomValue |
            Should-Be 'Keep this value'

        $configuration.Provider |
            Should-Be 'WinGet'
    }

    It 'merges missing dashboard tiles while preserving tile placement' {

        [string]$runtimeRoot =
            Join-Path `
                $TestDrive `
                'PartialUiConfiguration'

        [string]$configRoot =
            Join-Path `
                $runtimeRoot `
                'Config'

        New-Item `
            -ItemType Directory `
            -Path $configRoot `
            -Force |
            Out-Null

        [pscustomobject]@{
            SchemaVersion = '2.0'
            ThemeId       = 'custom-theme'
            Dashboard     = [pscustomobject]@{
                Tiles = @(
                    [pscustomobject]@{
                        Id = 'Inventory'
                        X  = 777.0
                    }
                )
            }
        } |
            ConvertTo-Json `
                -Depth 10 |
            Set-Content `
                -LiteralPath (
                    Join-Path `
                        $configRoot `
                        'Phoenix.UI.json'
                ) `
                -Encoding UTF8

        $null =
            InModuleScope Phoenix `
                -Parameters @{
                    RecoveryProjectRoot = $runtimeRoot
                } {
                    param($RecoveryProjectRoot)

                    Initialize-PhoenixRuntimeRecovery `
                        -ProjectRoot $RecoveryProjectRoot
                }

        $configuration =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $configRoot `
                        'Phoenix.UI.json'
                ) `
                -Raw |
            ConvertFrom-Json

        $inventoryTile =
            $configuration.Dashboard.Tiles |
                Where-Object Id -EQ 'Inventory' |
                Select-Object -First 1

        $configuration.ThemeId |
            Should-Be 'custom-theme'

        @($configuration.Dashboard.Tiles).Count |
            Should-Be 5

        $inventoryTile.X |
            Should-Be 777

        ($inventoryTile.Width -gt 0) |
            Should-BeTrue

        (
            $configuration.Appearance.Accent -match
            '^#[0-9A-Fa-f]{6}$'
        ) |
            Should-BeTrue
    }

    It 'normalizes unsafe runtime values' {

        [string]$runtimeRoot =
            Join-Path `
                $TestDrive `
                'UnsafeValues'

        [string]$configRoot =
            Join-Path `
                $runtimeRoot `
                'Config'

        New-Item `
            -ItemType Directory `
            -Path $configRoot `
            -Force |
            Out-Null

        [pscustomobject]@{
            LogLevel        = 'Everything'
            MaximumLogFiles = -5
            Provider        = ''
            OfflineMode     = 'sometimes'
        } |
            ConvertTo-Json |
            Set-Content `
                -LiteralPath (
                    Join-Path `
                        $configRoot `
                        'Phoenix.json'
                ) `
                -Encoding UTF8

        $null =
            InModuleScope Phoenix `
                -Parameters @{
                    RecoveryProjectRoot = $runtimeRoot
                } {
                    param($RecoveryProjectRoot)

                    Initialize-PhoenixRuntimeRecovery `
                        -ProjectRoot $RecoveryProjectRoot
                }

        $configuration =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $configRoot `
                        'Phoenix.json'
                ) `
                -Raw |
            ConvertFrom-Json

        $configuration.LogLevel |
            Should-Be 'Info'

        $configuration.MaximumLogFiles |
            Should-Be 20

        $configuration.Provider |
            Should-Be 'WinGet'

        $configuration.OfflineMode |
            Should-BeFalse
    }

    It 'records and reloads the last successful recovery journal' {

        [string]$runtimeRoot =
            Join-Path `
                $TestDrive `
                'RecoveryJournal'

        New-Item `
            -ItemType Directory `
            -Path $runtimeRoot `
            -Force |
            Out-Null

        $results =
            InModuleScope Phoenix `
                -Parameters @{
                    RecoveryProjectRoot = $runtimeRoot
                } {
                    param($RecoveryProjectRoot)

                    $recovered =
                        Initialize-PhoenixRuntimeRecovery `
                            -ProjectRoot $RecoveryProjectRoot

                    $ready =
                        Initialize-PhoenixRuntimeRecovery `
                            -ProjectRoot $RecoveryProjectRoot

                    @(
                        $recovered
                        $ready
                    )
                }

        Test-Path `
            -LiteralPath $results[0].JournalPath |
            Should-BeTrue

        $results[1].LastRecovery.Code |
            Should-Be 'PHX_RUNTIME_RECOVERED'

        (
            [datetime]$results[1].LastRecovery.CompletedAtUtc -gt
            [datetime]::MinValue
        ) |
            Should-BeTrue
    }
}
