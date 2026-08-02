BeforeAll {

    $projectRoot = (
        Resolve-Path (
            Join-Path `
                $PSScriptRoot `
                '..\..'
        )
    ).Path

    $releasePowerShellFiles = @(
        Get-Item `
            -LiteralPath @(
                (
                    Join-Path `
                        $projectRoot `
                        'Build\New-PhoenixRelease.ps1'
                )
                (
                    Join-Path `
                        $projectRoot `
                        'Build\Phoenix.Release.psd1'
                )
                (
                    Join-Path `
                        $projectRoot `
                        'Build\Test-PhoenixReleaseArchive.ps1'
                )
                (
                    Join-Path `
                        $projectRoot `
                        'Build\Invoke-PhoenixInstallLifecycleSmoke.ps1'
                )
                (
                    Join-Path `
                        $projectRoot `
                        'Distribution\Install-Phoenix.ps1'
                )
                (
                    Join-Path `
                        $projectRoot `
                        'Distribution\Uninstall-Phoenix.ps1'
                )
            )
    )
}

Describe 'Phoenix release packaging' -Tag @(
    'Regression'
    'Release'
) {

    It 'keeps all release PowerShell files syntactically valid' {

        $allErrors =
            [System.Collections.Generic.List[object]]::new()

        foreach ($file in $releasePowerShellFiles) {
            $tokens = $null
            $parseErrors = $null

            [System.Management.Automation.Language.Parser]::ParseFile(
                $file.FullName,
                [ref]$tokens,
                [ref]$parseErrors
            ) |
                Out-Null

            foreach ($parseError in @($parseErrors)) {
                $allErrors.Add(
                    [pscustomobject]@{
                        File    = $file.FullName
                        Line    = $parseError.Extent.StartLineNumber
                        Column  = $parseError.Extent.StartColumnNumber
                        Message = $parseError.Message
                    }
                )
            }
        }

        if ($allErrors.Count -gt 0) {
            [string]$parseSummary = @(
                $allErrors |
                    ForEach-Object {
                        '{0}:{1}:{2}: {3}' -f
                            $_.File,
                            $_.Line,
                            $_.Column,
                            $_.Message
                    }
            ) -join [Environment]::NewLine

            throw (
                "Release PowerShell syntax validation failed:" +
                [Environment]::NewLine +
                $parseSummary
            )
        }

        $allErrors.Count |
            Should-Be 0
    }

    It 'ships the confirmed tri-license and matching module metadata' {

        [string]$licenseExpression =
            'MIT OR Apache-2.0 OR GPL-3.0-or-later'

        [string]$licenseNotice =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'LICENSE.txt'
                ) `
                -Raw

        $moduleManifest =
            Import-PowerShellDataFile `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Phoenix.psd1'
                )

        $licenseNotice.Contains(
            "SPDX-License-Identifier: $licenseExpression"
        ) |
            Should-BeTrue

        $moduleManifest.PrivateData.LicenseExpression |
            Should-Be $licenseExpression

        $moduleManifest.Copyright |
            Should-Be (
                'Copyright (c) 2026 Donaven Guardipee'
            )

        [string]$moduleVersion =
            $moduleManifest.ModuleVersion.ToString()

        ($moduleVersion -match '^\d+\.\d+\.\d+$') |
            Should-BeTrue

        [string]$changelog =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'CHANGELOG.md'
                ) `
                -Raw

        $changelog.Contains(
            "## [$moduleVersion] - "
        ) |
            Should-BeTrue

        [string]$developmentHistory =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Docs\Phoenix-v0.2.0-Development-History.md'
                ) `
                -Raw

        $developmentHistory.Contains(
            '# Phoenix v0.2.0 Development History'
        ) |
            Should-BeTrue

        $developmentHistory.Contains(
            '**Release:** v0.2.0'
        ) |
            Should-BeTrue

        foreach (
            $licenseFile in @(
                'MIT.txt'
                'Apache-2.0.txt'
                'GPL-3.0-or-later.txt'
            )
        ) {
            (
                Get-Item `
                    -LiteralPath (
                        Join-Path `
                            $projectRoot `
                            "LICENSES\$licenseFile"
                    )
            ).Length -gt 500 |
                Should-BeTrue
        }
    }

    It 'keeps development content out of the runtime payload' {

        $releaseConfiguration =
            Import-PowerShellDataFile `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Build\Phoenix.Release.psd1'
                )

        foreach (
            $developmentRoot in @(
                'Tests'
                'Build'
                'Distribution'
                'Artifacts'
                '.git'
            )
        ) {
            @(
                $releaseConfiguration.RuntimePaths |
                    Where-Object {
                        [string]$_ -eq $developmentRoot -or
                        [string]$_ -like "$developmentRoot\*"
                    }
            ).Count |
                Should-Be 0
        }

        @(
            $releaseConfiguration.RuntimePaths |
                Where-Object {
                    [string]$_ -eq 'LICENSES'
                }
        ).Count |
            Should-Be 1

        @(
            $releaseConfiguration.RuntimePaths |
                Where-Object {
                    [string]$_ -eq 'Docs'
                }
        ).Count |
            Should-Be 1

        @(
            $releaseConfiguration.RuntimePaths |
                Where-Object {
                    [string]$_ -eq 'ROADMAP.md'
                }
        ).Count |
            Should-Be 1

        (
            Get-Item `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Docs\Phoenix-v0.2.0-Development-History.md'
                )
        ).Length -gt 1000 |
            Should-BeTrue
    }

    It 'ships the complete 33-release Phoenix v0.2.0 train' {

        [string]$developmentHistory =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Docs\Phoenix-v0.2.0-Development-History.md'
                ) `
                -Raw

        [string[]]$expectedVersions = @(
            2..33 |
                ForEach-Object {
                    "0.1.$_"
                }

            '0.2.0'
        )

        foreach ($expectedVersion in $expectedVersions) {

            $developmentHistory.Contains(
                "| v$expectedVersion |"
            ) |
                Should-BeTrue
        }
    }

    It 'plans the complete Phoenix v0.3.0 release train' {

        [string]$roadmap =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'ROADMAP.md'
                ) `
                -Raw

        [string[]]$expectedVersions = @(
            1..18 |
                ForEach-Object {
                    "0.2.$_"
                }

            '0.3.0'
        )

        foreach ($expectedVersion in $expectedVersions) {
            $versionPattern =
                '(?m)^- \[ \] `v{0}`' -f
                [regex]::Escape($expectedVersion)

            [regex]::IsMatch(
                $roadmap,
                $versionPattern
            ) |
                Should-BeTrue
        }

        [regex]::Matches(
            $roadmap,
            '(?m)^- \[ \] `v(?:0\.2\.(?:[1-9]|1[0-8])|0\.3\.0)`'
        ).Count |
            Should-Be 19

        foreach ($requiredSafetyText in @(
            'Windows 10 and Windows 11 x64'
            'UEFI/GPT'
            'typed confirmation'
            'Block the current system disk'
            'disposable snapshot-backed VMs'
        )) {
            $roadmap.Contains($requiredSafetyText) |
                Should-BeTrue
        }
    }

    It 'builds versioned archives checksums and optional GitHub releases' {

        [string]$builderSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Build\New-PhoenixRelease.ps1'
                ) `
                -Raw

        foreach (
            $requiredText in @(
                'Compress-Archive'
                'Get-FileHash'
                'Test-ModuleManifest'
                'DirtyWorkingTree'
                "'PublishGitHub'"
                "'--generate-notes'"
            )
        ) {
            $builderSource.Contains(
                $requiredText.Trim("'")
            ) |
                Should-BeTrue
        }
    }

    It 'independently verifies archives and the Windows install lifecycle' {
        [string]$verifierSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Build\Test-PhoenixReleaseArchive.ps1'
                ) `
                -Raw

        foreach ($requiredText in @(
            'Archive checksum mismatch'
            'Release file checksum mismatch'
            'Runtime file count mismatch'
            'Import-Module'
        )) {
            $verifierSource.Contains($requiredText) |
                Should-BeTrue
        }

        [string]$lifecycleSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Build\Invoke-PhoenixInstallLifecycleSmoke.ps1'
                ) `
                -Raw

        foreach ($requiredText in @(
            'Test-PhoenixReleaseArchive.ps1'
            'Upgraded'
            'MainWindowHandle'
            'UserDataPreserved'
            'RemovedUserData'
        )) {
            $lifecycleSource.Contains($requiredText) |
                Should-BeTrue
        }
    }

    It 'previews a release without writing an archive' {

        $preview =
            & (
                Join-Path `
                    $projectRoot `
                    'Build\New-PhoenixRelease.ps1'
            ) `
                -Version '9.9.9' `
                -OutputPath $TestDrive `
                -SkipValidation `
                -AllowDirty `
                -WhatIf

        $preview.Success |
            Should-BeTrue

        $preview.Created |
            Should-BeFalse

        $preview.Version |
            Should-Be '9.9.9'
    }

    It 'supports scoped installs shortcuts upgrades and Apps registration' {

        [string]$installerSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Distribution\Install-Phoenix.ps1'
                ) `
                -Raw

        foreach (
            $requiredText in @(
                "'CurrentUser'"
                "'AllUsers'"
                'Programs\Phoenix'
                'release.PreserveOnUpgrade'
                'WScript.Shell'
                'CurrentVersion\Uninstall\Phoenix'
                '.phoenix-install.json'
                '.phoenix-user-data.json'
                'release.Files'
                'Release integrity verification failed'
            )
        ) {
            $installerSource.Contains(
                $requiredText
            ) |
                Should-BeTrue
        }
    }

    It 'preserves recovery data checkpoints logs and installed themes' {

        $releaseConfiguration =
            Import-PowerShellDataFile `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Build\Phoenix.Release.psd1'
                )

        foreach (
            $preservedPath in @(
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
        ) {
            @($releaseConfiguration.PreserveOnUpgrade) |
                Should-ContainCollection $preservedPath
        }
    }

    It 'ships a double-clickable PowerShell 7 installer launcher' {

        [string]$launcherPath =
            Join-Path `
                $projectRoot `
                'Distribution\Install-Phoenix.cmd'

        Test-Path `
            -LiteralPath $launcherPath `
            -PathType Leaf |
            Should-BeTrue

        [string]$launcherSource =
            Get-Content `
                -LiteralPath $launcherPath `
                -Raw

        foreach (
            $requiredText in @(
                'pwsh.exe'
                'PowerShell\7\pwsh.exe'
                'Install-Phoenix.ps1'
                '-ExecutionPolicy Bypass'
                "[version]'7.4.0'"
                'pause'
            )
        ) {
            $launcherSource.Contains(
                $requiredText
            ) |
                Should-BeTrue
        }

        [string]$builderSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Build\New-PhoenixRelease.ps1'
                ) `
                -Raw

        $builderSource.Contains(
            "'Install-Phoenix.cmd'"
        ) |
            Should-BeTrue
    }

    It 'preserves user data by default and supports complete removal' {

        [string]$uninstallerSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Distribution\Uninstall-Phoenix.ps1'
                ) `
                -Raw

        $uninstallerSource.Contains(
            '[switch]$RemoveUserData'
        ) |
            Should-BeTrue

        $uninstallerSource.Contains(
            'UninstalledUserDataPreserved'
        ) |
            Should-BeTrue

        $uninstallerSource.Contains(
            'Themes\Installed'
        ) |
            Should-BeTrue

        $uninstallerSource.Contains(
            'Config\Phoenix.UI.json'
        ) |
            Should-BeTrue
    }
}
