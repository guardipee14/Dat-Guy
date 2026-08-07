[CmdletBinding()]
param(
    [Parameter()]
    [string]$RepositoryRoot,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ProjectDescription,

    [Parameter()]
    [switch]$UpdateManifestDescription
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-GitRead {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $output = @(
        & git @Arguments 2>$null
    )

    if ($LASTEXITCODE -ne 0 -or $output.Count -eq 0) {
        return $null
    }

    return [string]$output[0]
}

function Get-PhoenixSourceText {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return ''
    }

    return [string](
        Get-Content `
            -LiteralPath $Path `
            -Raw
    )
}

function Set-PhoenixManifestDescription {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ManifestPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Description
    )

    $manifestText = Get-Content `
        -LiteralPath $ManifestPath `
        -Raw

    if ($manifestText -notmatch "(?m)^Description\s*=\s*'[^']*'") {
        throw 'Description was not found in Phoenix.psd1.'
    }

    $escapedDescription =
        $Description.Replace("'", "''")

    $updatedManifestText = [regex]::Replace(
        $manifestText,
        "(?m)^Description\s*=\s*'[^']*'",
        "Description = '$escapedDescription'",
        1
    )

    if ($updatedManifestText -ceq $manifestText) {
        return
    }

    [System.IO.File]::WriteAllText(
        $ManifestPath,
        $updatedManifestText,
        [System.Text.UTF8Encoding]::new($false)
    )

}

function Get-PhoenixRepositoryUrl {

    [CmdletBinding()]
    param()

    $origin = Invoke-GitRead `
        -Arguments @(
            'remote',
            'get-url',
            'origin'
        )

    if ([string]::IsNullOrWhiteSpace($origin)) {
        return $null
    }

    $origin = $origin.Trim()

    if ($origin -match '^git@github\.com:(.+?)(?:\.git)?$') {
        return "https://github.com/$($Matches[1])"
    }

    if ($origin -match '^https://github\.com/(.+?)(?:\.git)?$') {
        return "https://github.com/$($Matches[1])"
    }

    return $origin.TrimEnd('/')
}

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {

    $RepositoryRoot = Invoke-GitRead `
        -Arguments @(
            'rev-parse',
            '--show-toplevel'
        )
}

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    throw 'Run this script from inside the Phoenix Git repository or provide -RepositoryRoot.'
}

$RepositoryRoot = $RepositoryRoot.Trim()
$manifestPath = Join-Path $RepositoryRoot 'Phoenix.psd1'
$readmePath = Join-Path $RepositoryRoot 'README.md'

if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Phoenix manifest was not found: $manifestPath"
}

$manifest = Import-PowerShellDataFile `
    -LiteralPath $manifestPath

$defaultDescription = (
    'PowerShell deployment and recovery framework for Windows applications, ' +
    'drivers, updates, restore workflows, offline recovery, and a desktop Control Center.'
)

if ([string]::IsNullOrWhiteSpace($ProjectDescription)) {
    $ProjectDescription = [string]$manifest.Description
}

if (
    [string]::IsNullOrWhiteSpace($ProjectDescription) -or
    $ProjectDescription -eq 'Phoenix Deploy Framework'
) {
    $ProjectDescription = $defaultDescription
    $UpdateManifestDescription = $true
}

if ($UpdateManifestDescription) {

    Set-PhoenixManifestDescription `
        -ManifestPath $manifestPath `
        -Description $ProjectDescription

    $manifest = Import-PowerShellDataFile `
        -LiteralPath $manifestPath
}

[string]$version = [string]$manifest.ModuleVersion
[string[]]$commands = @($manifest.FunctionsToExport)
[string]$repositoryUrl = Get-PhoenixRepositoryUrl

[string]$releaseUrl = ''

if (-not [string]::IsNullOrWhiteSpace($repositoryUrl)) {
    $releaseUrl = (
        '{0}/releases/tag/v{1}' -f
            $repositoryUrl.TrimEnd('/'),
            $version
    )
}

$commandDescriptions = @{
    'Backup-Phoenix' = 'Create a versioned JSON restore manifest containing inventory, installed drivers, packages, and provider metadata.'
    'Get-PhoenixContext' = 'Return the active Phoenix runtime context and optionally require a ready lifecycle.'
    'Get-PhoenixPackages' = 'Enumerate installed packages reported by active providers.'
    'Get-PhoenixProviders' = 'List active Phoenix package providers.'
    'Install-PhoenixPackage' = 'Install a package through WinGet or Chocolatey with elevation and install-mode handling.'
    'Remove-PhoenixPackage' = 'Uninstall a package through WinGet or Chocolatey with elevation support.'
    'Repair-PhoenixPackage' = 'Repair a supported package using silent or interactive provider behavior.'
    'Restore-Phoenix' = 'Restore drivers first and reinstall missing WinGet or Chocolatey packages from a Phoenix manifest.'
    'Start-Phoenix' = 'Create or reuse a ready Phoenix context; use -Force for a new lifecycle generation.'
    'Update-Phoenix' = 'Install applicable Windows Update drivers first, then update packages, and return structured results.'
    'Update-PhoenixPackage' = 'Update one package and safely classify installer-technology migrations.'
}

$commandStatus = @{}

$capabilities =
    [System.Collections.Generic.List[string]]::new()

$startPath = Join-Path $RepositoryRoot 'Public\Start-Phoenix.ps1'
$updatePath = Join-Path $RepositoryRoot 'Public\Update-Phoenix.ps1'
$driverPath = Join-Path $RepositoryRoot 'Private\Drivers\Update-PhoenixDriver.ps1'
$windowsUpdateDriverPath = Join-Path $RepositoryRoot 'Private\Drivers\Invoke-PhoenixWindowsUpdateDriver.ps1'
$elevationPath = Join-Path $RepositoryRoot 'Private\Core\Request-PhoenixElevation.ps1'
$providersPath = Join-Path $RepositoryRoot 'Private\Core\Initialize-PhoenixProviders.ps1'
$migrationPath = Join-Path $RepositoryRoot 'Private\Packages\Invoke-PhoenixPackageMigration.ps1'
$backupPath = Join-Path $RepositoryRoot 'Public\Backup-Phoenix.ps1'
$restorePath = Join-Path $RepositoryRoot 'Public\Restore-Phoenix.ps1'
$loggingPath = Join-Path $RepositoryRoot 'Private\Logging\Write-PhoenixLog.ps1'
$inventoryPath = Join-Path $RepositoryRoot 'Private\Inventory'
$runtimeRecoveryPath = Join-Path $RepositoryRoot 'Private\Core\Initialize-PhoenixRuntimeRecovery.ps1'
$controlCenterRecoveryPath = Join-Path $RepositoryRoot 'Private\ControlCenter\Invoke-PhoenixControlCenterBoundary.ps1'

$providersText = Get-PhoenixSourceText -Path $providersPath
$updateText = Get-PhoenixSourceText -Path $updatePath
$driverText = Get-PhoenixSourceText -Path $driverPath
$windowsUpdateDriverText = Get-PhoenixSourceText -Path $windowsUpdateDriverPath
$elevationText = Get-PhoenixSourceText -Path $elevationPath
$migrationText = Get-PhoenixSourceText -Path $migrationPath
$restoreText = Get-PhoenixSourceText -Path $restorePath
$runtimeRecoveryText = Get-PhoenixSourceText -Path $runtimeRecoveryPath
$controlCenterRecoveryText = Get-PhoenixSourceText -Path $controlCenterRecoveryPath

if (
    $providersText -match 'WinGetProvider' -and
    $providersText -match 'ChocolateyProvider'
) {
    $capabilities.Add(
        'Detect and initialize WinGet and Chocolatey package providers, including installation checks for missing providers.'
    )
}

if (
    $commands -contains 'Install-PhoenixPackage' -and
    $commands -contains 'Remove-PhoenixPackage' -and
    $commands -contains 'Repair-PhoenixPackage' -and
    $commands -contains 'Update-PhoenixPackage'
) {
    $capabilities.Add(
        'Install, remove, repair, and update individual packages through a consistent public command layer.'
    )
}

if (
    $updateText -match 'SkipDrivers' -and
    $updateText -match 'SkipPackages' -and
    $updateText -match 'Write-Progress'
) {
    $capabilities.Add(
        'Run bulk updates with drivers first, package progress reporting, elapsed time, and separate completion summaries.'
    )
}

if (
    $elevationText -match 'WaitForCompletion' -and
    $elevationText -match 'Export-Clixml' -and
    $elevationText -match 'Import-Clixml'
) {
    $capabilities.Add(
        'Request UAC once, run privileged work in an elevated process, and return structured results to the original window.'
    )
}

if (
    $driverText -match '/scan-devices' -and
    $driverText -match 'Get-PhoenixDriver'
) {
    $capabilities.Add(
        'Scan Windows for hardware changes and refresh the installed-driver inventory with visible progress and result codes.'
    )
}

if (
    $windowsUpdateDriverText -match 'Microsoft.Update.Session' -and
    $windowsUpdateDriverText -match 'CreateUpdateDownloader' -and
    $windowsUpdateDriverText -match 'CreateUpdateInstaller'
) {
    $capabilities.Add(
        'Search, download, and install applicable driver updates through Windows Update before package updates, with scan-only and reboot reporting.'
    )
}

if (
    (Test-Path -LiteralPath $migrationPath) -and
    $migrationText -match 'PHX_UPDATE_MIGRATION_PROTECTED'
) {
    $capabilities.Add(
        'Handle installer-technology changes with interactive approval, unattended policy switches, and protected-package safeguards.'
    )
}

if (
    (Test-Path -LiteralPath $backupPath) -and
    $commands -contains 'Backup-Phoenix'
) {
    $capabilities.Add(
        'Create a versioned JSON restore manifest containing Phoenix metadata, hardware and network inventory, drivers, packages, and provider capabilities.'
    )
}

if (
    $commands -contains 'Restore-Phoenix' -and
    $restoreText -match 'Read-PhoenixManifest' -and
    $restoreText -match 'Install-PhoenixPackage' -and
    $restoreText -match 'Update-PhoenixDriver'
) {
    $capabilities.Add(
        'Restore drivers first and reinstall missing WinGet or Chocolatey packages from a versioned Phoenix manifest, with preview, provider filtering, progress, and structured results.'
    )
}

if (Test-Path -LiteralPath $inventoryPath) {
    $capabilities.Add(
        'Collect hardware, network, software, Windows, package, and driver inventory through private inventory engines.'
    )
}

if (Test-Path -LiteralPath $loggingPath) {
    $capabilities.Add(
        'Write Phoenix operational logs with structured severity levels.'
    )
}

if (
    $runtimeRecoveryText -match 'PHX_RUNTIME_RECOVERED' -and
    $runtimeRecoveryText -match 'LastRecovery.json'
) {
    $capabilities.Add(
        'Recover missing runtime directories and damaged configuration automatically while preserving backups, custom values, and a visible recovery journal.'
    )
}

if (
    $controlCenterRecoveryText -match 'PHX_UI_COMPONENT_FAILED' -and
    $controlCenterRecoveryText -match 'LastFailure.json'
) {
    $capabilities.Add(
        'Isolate Control Center component failures, keep the desktop available, offer retry and safe-layout recovery, and retain structured failure diagnostics.'
    )
}

$limitations =
    [System.Collections.Generic.List[string]]::new()

$limitations.Add(
    'Phoenix is currently Windows-only and is under active development.'
)

if (
    $windowsUpdateDriverText -match 'Microsoft.Update.Session' -and
    $windowsUpdateDriverText -match 'CreateUpdateInstaller'
) {
    $limitations.Add(
        'Driver installation currently uses Windows Update Agent; OEM-specific update tools, vendor catalogs, and offline driver packs are not implemented yet.'
    )
}
elseif ($driverText -match '/scan-devices') {
    $limitations.Add(
        'The driver stage currently scans for hardware changes and refreshes installed-driver inventory; vendor-specific driver downloading and installation are not implemented yet.'
    )
}

if (
    $commands -contains 'Restore-Phoenix' -and
    $restoreText -match 'Read-PhoenixManifest'
) {
    $limitations.Add(
        'Manifest restore reinstalls supported packages and Windows Update drivers; it does not yet restore application data, user profiles, Windows settings, or offline driver packages.'
    )
}

if (
    $commands -contains 'Restore-Phoenix' -and
    $restoreText -match 'Install-PhoenixPackage'
) {
    $limitations.Add(
        'Package manifests record installed versions for reference, but restore currently installs the provider-current version instead of pinning an exact historical version.'
    )
}

if ($migrationText -match 'ForceProtectedMigration') {
    $limitations.Add(
        'Protected packages such as Microsoft Edge are not removed unless -ForceProtectedMigration is explicitly supplied.'
    )
}

$readmeLines =
    [System.Collections.Generic.List[string]]::new()

$readmeLines.Add('# PhoenixDeploy')
$readmeLines.Add('')
$readmeLines.Add($ProjectDescription)
$readmeLines.Add('')
$readmeLines.Add(
    ('**Current release:** `v{0}`' -f $version)
)

if (-not [string]::IsNullOrWhiteSpace($repositoryUrl)) {
    $readmeLines.Add('')
    $readmeLines.Add(
        ('**Repository:** [{0}]({0})' -f $repositoryUrl)
    )
}

if (-not [string]::IsNullOrWhiteSpace($releaseUrl)) {
    $readmeLines.Add('')
    $readmeLines.Add(
        (
            '**Latest release:** [Phoenix v{0}]({1})' -f
                $version,
                $releaseUrl
        )
    )
}

[version]$parsedVersion = [version]$version

[string]$developmentHistoryBaseline =
    '{0}.{1}.0' -f
        $parsedVersion.Major,
        $parsedVersion.Minor

[string]$developmentHistoryRelativePath =
    'Docs/Phoenix-v{0}-Development-History.md' -f
        $developmentHistoryBaseline

[string]$developmentHistoryPath =
    Join-Path `
        $RepositoryRoot `
        $developmentHistoryRelativePath

[string]$developmentHistoryDisplayVersion =
    $developmentHistoryBaseline

if (-not (Test-Path -LiteralPath $developmentHistoryPath)) {

    $latestDevelopmentHistory =
        Get-ChildItem `
            -LiteralPath (
                Join-Path `
                    $RepositoryRoot `
                    'Docs'
            ) `
            -Filter 'Phoenix-v*-Development-History.md' `
            -File `
            -ErrorAction SilentlyContinue |
            ForEach-Object {

                if (
                    $_.BaseName -match
                        '^Phoenix-v(?<Version>\d+\.\d+\.\d+)-Development-History$'
                ) {
                    [pscustomobject]@{
                        Version      = [version]$Matches.Version
                        Display      = [string]$Matches.Version
                        RelativePath = "Docs/$($_.Name)"
                        FullName     = $_.FullName
                    }
                }
            } |
            Sort-Object Version -Descending |
            Select-Object -First 1

    if ($null -ne $latestDevelopmentHistory) {
        $developmentHistoryDisplayVersion =
            $latestDevelopmentHistory.Display
        $developmentHistoryRelativePath =
            $latestDevelopmentHistory.RelativePath
        $developmentHistoryPath =
            $latestDevelopmentHistory.FullName
    }
}

if (
    -not [string]::IsNullOrWhiteSpace(
        $developmentHistoryRelativePath
    ) -and
    (Test-Path -LiteralPath $developmentHistoryPath)
) {
    $readmeLines.Add('')
    $readmeLines.Add(
        (
            '**Development history:** [Phoenix v{0}]({1})' -f
                $developmentHistoryDisplayVersion,
                $developmentHistoryRelativePath
        )
    )
}

$roadmapPath =
    Join-Path `
        $RepositoryRoot `
        'ROADMAP.md'

if (Test-Path -LiteralPath $roadmapPath) {

    [string]$roadmapText =
        Get-Content `
            -LiteralPath $roadmapPath `
            -Raw

    [string]$roadmapLabel =
        'Phoenix roadmap'

    if (
        $roadmapText -match
            '(?m)^## Phoenix v(?<Version>\d+\.\d+\.\d+)\s*$'
    ) {
        $roadmapLabel =
            'Phoenix v{0} roadmap' -f
                $Matches.Version
    }

    $readmeLines.Add('')
    $readmeLines.Add(
        (
            '**Roadmap:** [{0}](ROADMAP.md)' -f
                $roadmapLabel
        )
    )
}

$readmeLines.Add('')
$readmeLines.Add('## What Phoenix can currently do')
$readmeLines.Add('')

$capabilityGroups = [ordered]@{
    'Applications and package management' = @(
        'Discover, install, update, repair, and remove applications through a common Phoenix interface.'
        'Work with WinGet, Chocolatey, Scoop, MSI, EXE, GitHub Releases, PowerShell Gallery, and NuGet sources.'
        'Compare installed and available versions, inspect provider metadata, and choose supported actions from the Control Center.'
        'Handle installer changes and protected applications with explicit safety and approval policies.'
        'Normalize provider results so command-line and Control Center workflows report success, failure, restart, timeout, and cancellation consistently.'
    )

    'Drivers and Windows updates' = @(
        'Inventory installed drivers and scan Windows for hardware changes.'
        'Search for and install applicable driver updates through Windows Update.'
        'Detect Windows Update and WSUS policy and manage applicable Windows updates.'
        'Inspect OEM driver information for Dell, HP, Lenovo, Intel, AMD, and NVIDIA through a shared adapter model.'
        'Run driver work before application updates when performing a full Phoenix update.'
    )

    'Backup, restore, and recovery' = @(
        'Create versioned Phoenix restore manifests containing hardware, network, application, driver, and provider information.'
        'Build a restore plan before making changes so actions, versions, providers, dependencies, elevation requirements, and restart state can be reviewed.'
        'Restore drivers first and reinstall supported applications from a Phoenix manifest.'
        'Save restore checkpoints before and after operations and resume interrupted restores without repeating completed work.'
        'Verify completed restores by rescanning applications and drivers and reporting complete, partial, failed, or restart-pending results.'
    )

    'Offline recovery foundations' = @(
        'Store recovery content by SHA-256 identity and automatically reuse identical content.'
        'Use a versioned offline-bundle manifest and content-addressed object store.'
        'Acquire eligible application content from NuGet, PowerShell Gallery, Scoop, GitHub Releases, MSI, and EXE sources.'
        'Acquire content from local files, file URIs, HTTPS sources, provider caches, and direct installer media.'
        'Validate optional SHA-256 hashes, block insecure HTTP by default, and isolate temporary acquisition workspaces.'
        'Report unavailable, unsupported, failed, reused, acquired, and user-supplied-media requirements explicitly instead of silently skipping content.'
    )

    'Control Center and background work' = @(
        'Keep the desktop responsive by running provider checks, inventory, searches, restore work, and application or driver operations in isolated workers.'
        'Queue operations through a bounded FIFO scheduler instead of allowing conflicting work to run at the same time.'
        'Monitor queued, running, completed, cancelled, and failed operations from the Activity view.'
        'Cancel, retry, clear, and inspect jobs with detailed results, warnings, errors, restart information, and elapsed time.'
        'Keep unsupported or unavailable actions disabled rather than allowing unsafe operations to fail late.'
        'Recover from Control Center component failures and damaged runtime configuration while preserving diagnostic information.'
    )

    'Safety, diagnostics, and release validation' = @(
        'Request elevation only when privileged work is required and return structured results to the original Phoenix process.'
        'Write structured operational logs and preserve recovery and failure diagnostics.'
        'Validate module generation, module imports, static analysis, and Pester tests during development and release builds.'
        'Run repeatable Windows VM and WPF smoke tests for supported workflows.'
        'Build versioned release archives with file manifests and SHA-256 verification.'
        'Independently verify published archives, checksums, installation, upgrades, uninstall behavior, and complete removal.'
    )
}

foreach ($groupName in $capabilityGroups.Keys) {

    $readmeLines.Add(
        ('### {0}' -f $groupName)
    )
    $readmeLines.Add('')

    foreach ($capability in @($capabilityGroups[$groupName])) {
        $readmeLines.Add("- $capability")
    }

    $readmeLines.Add('')
}

$readmeLines.Add(
    (
        '> Phoenix v{0} includes offline application acquisition and content-store foundations. Additional offline-recovery work is tracked in [ROADMAP.md](ROADMAP.md).' -f
            $version
    )
)

$readmeLines.Add('')
$readmeLines.Add('## Available commands')
$readmeLines.Add('')
$readmeLines.Add('| Command | Status | Purpose |')
$readmeLines.Add('|---|---|---|')

foreach ($command in $commands) {

    $status = 'Available'

    if ($commandStatus.ContainsKey($command)) {
        $status = [string]$commandStatus[$command]
    }

    $purpose = 'Exported Phoenix command.'

    if ($commandDescriptions.ContainsKey($command)) {
        $purpose = [string]$commandDescriptions[$command]
    }

    $readmeLines.Add(
        ('| `{0}` | {1} | {2} |' -f
            $command,
            $status,
            $purpose
        )
    )
}

$readmeLines.Add('')
$readmeLines.Add('## Quick start')
$readmeLines.Add('')
$readmeLines.Add('```powershell')
$readmeLines.Add('Set-Location C:\Dev\PhoenixDeploy')
$readmeLines.Add('Import-Module .\Phoenix.psd1 -Force')
$readmeLines.Add('Start-Phoenix')
$readmeLines.Add('```')
$readmeLines.Add('')
$readmeLines.Add('Phoenix first recovers required runtime directories and configuration, then initializes its runtime context, logging, configured providers, and background services. The Control Center keeps provider checks and inventory work off the desktop thread so the interface can remain responsive. Repeated calls reuse the active context; use `Start-Phoenix -Force` only when a new context generation is required.')
$readmeLines.Add('')
$readmeLines.Add('## Common examples')
$readmeLines.Add('')
$readmeLines.Add('```powershell')
$readmeLines.Add('# Inspect active providers and installed packages')
$readmeLines.Add('Get-PhoenixProviders')
$readmeLines.Add('Get-PhoenixPackages')
$readmeLines.Add('')
$readmeLines.Add('# Install one package')
$readmeLines.Add("Install-PhoenixPackage -Id '7zip.7zip' -Provider WinGet -Confirm:`$false")
$readmeLines.Add('')
$readmeLines.Add('# Install applicable Windows Update drivers first, then update packages')
$readmeLines.Add('Update-Phoenix -Provider WinGet -Confirm:$false')
$readmeLines.Add('')
$readmeLines.Add('# Discover driver updates without installing them')
$readmeLines.Add('Update-Phoenix -ScanDriversOnly -SkipPackages -Confirm:$false')
$readmeLines.Add('')
$readmeLines.Add('# Permit eligible non-protected migrations in unattended mode')
$readmeLines.Add('Update-Phoenix -Provider WinGet -AllowMigration -Unattended -Confirm:$false')
$readmeLines.Add('')
$readmeLines.Add('# Export a recovery manifest')
$readmeLines.Add("Backup-Phoenix -OutputPath '.\PhoenixManifest\PhoenixBackup.json'")
$readmeLines.Add('')
$readmeLines.Add('# Preview a restore without changing the computer')
$readmeLines.Add("Restore-Phoenix -ManifestPath '.\PhoenixManifest\PhoenixBackup.json' -WhatIf")
$readmeLines.Add('')
$readmeLines.Add('# Restore drivers first and reinstall missing packages')
$readmeLines.Add("Restore-Phoenix -ManifestPath '.\PhoenixManifest\PhoenixBackup.json' -Unattended -Confirm:`$false")
$readmeLines.Add('```')
$readmeLines.Add('')
$readmeLines.Add('## Application and package sources')
$readmeLines.Add('')
$readmeLines.Add('- WinGet')
$readmeLines.Add('- Chocolatey')
$readmeLines.Add('- Scoop')
$readmeLines.Add('- Local MSI and EXE installers')
$readmeLines.Add('- GitHub Releases')
$readmeLines.Add('- PowerShell Gallery')
$readmeLines.Add('- NuGet v3 feeds')
$readmeLines.Add('')
$readmeLines.Add('## Current limitations')
$readmeLines.Add('')
$readmeLines.Add('- Phoenix is currently Windows-only and is under active development.')
$readmeLines.Add('- Offline recovery and deployment capabilities are being delivered incrementally; see [ROADMAP.md](ROADMAP.md) for the current milestone status.')
$readmeLines.Add('- Restore does not currently include user profiles, application data, or complete Windows settings migration.')
$readmeLines.Add('- Destructive deployment, disk, WinPE, and boot-media workflows remain unavailable until their roadmap safety and VM-validation gates are complete.')

$readmeLines.Add('')
$readmeLines.Add('## Project layout')
$readmeLines.Add('')
$readmeLines.Add('```text')
$readmeLines.Add('PhoenixDeploy/')
$readmeLines.Add('|-- Build/         Class, analysis, test, and release automation')
$readmeLines.Add('|-- Classes/       PowerShell classes and generated class module')
$readmeLines.Add('|-- Config/        Phoenix configuration files')
$readmeLines.Add('|-- Distribution/  Installer, uninstaller, and release instructions')
$readmeLines.Add('|-- Docs/          Versioned development history and project documentation')
$readmeLines.Add('|-- Private/       Internal core, logging, provider, driver, inventory, and package functions')
$readmeLines.Add('|-- Public/        Exported Phoenix commands')
$readmeLines.Add('|-- Tests/         Pester unit and regression coverage')
$readmeLines.Add('|-- Themes/        Built-in and installed Control Center themes')
$readmeLines.Add('|-- Tools/         Git, changelog, README, and release automation')
$readmeLines.Add('|-- Phoenix.psd1   Module manifest')
$readmeLines.Add('`-- Phoenix.psm1   Module loader and exports')
$readmeLines.Add('```')
$readmeLines.Add('')
$readmeLines.Add('## Git and documentation workflow')
$readmeLines.Add('')
$readmeLines.Add('The save helper refreshes this generated README section, updates `CHANGELOG.md`, validates Phoenix, creates a Git commit, and can push it to GitHub.')
$readmeLines.Add('')
$readmeLines.Add('```powershell')
$readmeLines.Add('.\Tools\Save-PhoenixChange.ps1 `')
$readmeLines.Add('    -Type feat `')
$readmeLines.Add('    -Scope update `')
$readmeLines.Add('    -Summary ''Describe the completed change.'' `')
$readmeLines.Add('    -Push')
$readmeLines.Add('```')
$readmeLines.Add('')
$readmeLines.Add('To change the project and GitHub description during a commit:')
$readmeLines.Add('')
$readmeLines.Add('```powershell')
$readmeLines.Add('.\Tools\Save-PhoenixChange.ps1 `')
$readmeLines.Add('    -Type docs `')
$readmeLines.Add('    -Scope readme `')
$readmeLines.Add('    -Summary ''Refresh project documentation.'' `')
$readmeLines.Add('    -ProjectDescription ''A new concise project description.'' `')
$readmeLines.Add('    -Push')
$readmeLines.Add('```')

$startMarker = '<!-- PHOENIX:GENERATED:START -->'
$endMarker = '<!-- PHOENIX:GENERATED:END -->'
$newLine = [Environment]::NewLine

$managedText = @(
    $startMarker
    $readmeLines
    $endMarker
) -join $newLine

$existingReadme = ''

if (Test-Path -LiteralPath $readmePath) {
    $existingReadme = [System.IO.File]::ReadAllText(
        $readmePath
    )
}

$startIndex = $existingReadme.IndexOf(
    $startMarker,
    [System.StringComparison]::Ordinal
)

$endIndex = $existingReadme.IndexOf(
    $endMarker,
    [System.StringComparison]::Ordinal
)

if ($startIndex -ge 0 -and $endIndex -gt $startIndex) {

    $before = $existingReadme.Substring(
        0,
        $startIndex
    ).TrimEnd("`r", "`n")

    $afterIndex = $endIndex + $endMarker.Length

    $after = $existingReadme.Substring(
        $afterIndex
    ).TrimStart("`r", "`n")

    $readmeSections =
        [System.Collections.Generic.List[string]]::new()

    if (-not [string]::IsNullOrWhiteSpace($before)) {
        $readmeSections.Add($before)
    }

    $readmeSections.Add($managedText)

    if (-not [string]::IsNullOrWhiteSpace($after)) {
        $readmeSections.Add($after)
    }

    $updatedReadme =
        $readmeSections -join ($newLine + $newLine)
}
elseif (
    [string]::IsNullOrWhiteSpace($existingReadme) -or
    $existingReadme.Trim() -eq '# Dat-Guy'
) {
    $updatedReadme = $managedText
}
else {
    $updatedReadme = (
        $existingReadme.TrimEnd("`r", "`n") +
        $newLine +
        $newLine +
        $managedText
    )
}

# Keep exactly one final newline. Set-Content appends another newline on each
# run, which previously made README generation non-idempotent.
$updatedReadme =
    $updatedReadme.TrimEnd("`r", "`n") + $newLine

$normalizedExisting =
    $existingReadme.Replace("`r`n", "`n").Replace("`r", "`n")

$normalizedUpdated =
    $updatedReadme.Replace("`r`n", "`n").Replace("`r", "`n")

[bool]$readmeChanged =
    $normalizedExisting -cne $normalizedUpdated

if ($readmeChanged) {

    [System.IO.File]::WriteAllText(
        $readmePath,
        $updatedReadme,
        [System.Text.UTF8Encoding]::new($false)
    )

    Write-Host 'README.md capability and command documentation updated.' `
        -ForegroundColor Green
}
else {
    Write-Host 'README.md is already current.' `
        -ForegroundColor DarkGray
}

return [pscustomobject]@{
    Changed       = $readmeChanged
    Description   = $ProjectDescription
    ModuleVersion = $version
    ReadmePath    = $readmePath
    RepositoryUrl = $repositoryUrl
    Commands      = $commands
    Capabilities  = @($capabilities)
    Limitations   = @($limitations)
}
