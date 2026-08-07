<!-- PHOENIX:GENERATED:START -->
# PhoenixDeploy

PowerShell deployment and recovery framework for Windows applications, drivers, updates, restore workflows, offline recovery, and a desktop Control Center.

**Current release:** `v0.2.5`

**Repository:** [https://github.com/guardipee14/Dat-Guy](https://github.com/guardipee14/Dat-Guy)

**Latest release:** [Phoenix v0.2.5](https://github.com/guardipee14/Dat-Guy/releases/tag/v0.2.5)

**Development history:** [Phoenix v0.2.0](Docs/Phoenix-v0.2.0-Development-History.md)

**Roadmap:** [Phoenix v0.3.0 roadmap](ROADMAP.md)

## What Phoenix can currently do

### Applications and package management

- Discover, install, update, repair, and remove applications through a common Phoenix interface.
- Work with WinGet, Chocolatey, Scoop, MSI, EXE, GitHub Releases, PowerShell Gallery, and NuGet sources.
- Compare installed and available versions, inspect provider metadata, and choose supported actions from the Control Center.
- Handle installer changes and protected applications with explicit safety and approval policies.
- Normalize provider results so command-line and Control Center workflows report success, failure, restart, timeout, and cancellation consistently.

### Drivers and Windows updates

- Inventory installed drivers and scan Windows for hardware changes.
- Search for and install applicable driver updates through Windows Update.
- Detect Windows Update and WSUS policy and manage applicable Windows updates.
- Inspect OEM driver information for Dell, HP, Lenovo, Intel, AMD, and NVIDIA through a shared adapter model.
- Run driver work before application updates when performing a full Phoenix update.

### Backup, restore, and recovery

- Create versioned Phoenix restore manifests containing hardware, network, application, driver, and provider information.
- Build a restore plan before making changes so actions, versions, providers, dependencies, elevation requirements, and restart state can be reviewed.
- Restore drivers first and reinstall supported applications from a Phoenix manifest.
- Save restore checkpoints before and after operations and resume interrupted restores without repeating completed work.
- Verify completed restores by rescanning applications and drivers and reporting complete, partial, failed, or restart-pending results.

### Offline recovery foundations

- Store recovery content by SHA-256 identity and automatically reuse identical content.
- Use a versioned offline-bundle manifest and content-addressed object store.
- Acquire eligible application content from NuGet, PowerShell Gallery, Scoop, GitHub Releases, MSI, and EXE sources.
- Acquire content from local files, file URIs, HTTPS sources, provider caches, and direct installer media.
- Validate optional SHA-256 hashes, block insecure HTTP by default, and isolate temporary acquisition workspaces.
- Report unavailable, unsupported, failed, reused, acquired, and user-supplied-media requirements explicitly instead of silently skipping content.

### Control Center and background work

- Keep the desktop responsive by running provider checks, inventory, searches, restore work, and application or driver operations in isolated workers.
- Queue operations through a bounded FIFO scheduler instead of allowing conflicting work to run at the same time.
- Monitor queued, running, completed, cancelled, and failed operations from the Activity view.
- Cancel, retry, clear, and inspect jobs with detailed results, warnings, errors, restart information, and elapsed time.
- Keep unsupported or unavailable actions disabled rather than allowing unsafe operations to fail late.
- Recover from Control Center component failures and damaged runtime configuration while preserving diagnostic information.

### Safety, diagnostics, and release validation

- Request elevation only when privileged work is required and return structured results to the original Phoenix process.
- Write structured operational logs and preserve recovery and failure diagnostics.
- Validate module generation, module imports, static analysis, and Pester tests during development and release builds.
- Run repeatable Windows VM and WPF smoke tests for supported workflows.
- Build versioned release archives with file manifests and SHA-256 verification.
- Independently verify published archives, checksums, installation, upgrades, uninstall behavior, and complete removal.

> Phoenix v0.2.5 includes offline application acquisition and content-store foundations. Additional offline-recovery work is tracked in [ROADMAP.md](ROADMAP.md).

## Available commands

| Command | Status | Purpose |
|---|---|---|
| `Backup-Phoenix` | Available | Create a versioned JSON restore manifest containing inventory, installed drivers, packages, and provider metadata. |
| `Get-PhoenixContext` | Available | Return the active Phoenix runtime context and optionally require a ready lifecycle. |
| `Get-PhoenixRestoreCheckpoint` | Available | Exported Phoenix command. |
| `Get-PhoenixPackages` | Available | Enumerate installed packages reported by active providers. |
| `Get-PhoenixProviders` | Available | List active Phoenix package providers. |
| `Install-PhoenixPackage` | Available | Install a package through WinGet or Chocolatey with elevation and install-mode handling. |
| `Import-PhoenixRestorePlan` | Available | Exported Phoenix command. |
| `Invoke-PhoenixRestorePlan` | Available | Exported Phoenix command. |
| `New-PhoenixRestorePlan` | Available | Exported Phoenix command. |
| `New-PhoenixRestoreCheckpoint` | Available | Exported Phoenix command. |
| `Repair-PhoenixPackage` | Available | Repair a supported package using silent or interactive provider behavior. |
| `Receive-PhoenixJob` | Available | Exported Phoenix command. |
| `Restore-Phoenix` | Available | Restore drivers first and reinstall missing WinGet or Chocolatey packages from a Phoenix manifest. |
| `Resume-PhoenixRestore` | Available | Exported Phoenix command. |
| `Save-PhoenixRestorePlan` | Available | Exported Phoenix command. |
| `Save-PhoenixRestoreCheckpoint` | Available | Exported Phoenix command. |
| `Start-Phoenix` | Available | Create or reuse a ready Phoenix context; use -Force for a new lifecycle generation. |
| `Start-PhoenixRestoreJob` | Available | Exported Phoenix command. |
| `Stop-PhoenixJob` | Available | Exported Phoenix command. |
| `Test-PhoenixRestoreVerification` | Available | Exported Phoenix command. |
| `Update-Phoenix` | Available | Install applicable Windows Update drivers first, then update packages, and return structured results. |
| `Remove-PhoenixPackage` | Available | Uninstall a package through WinGet or Chocolatey with elevation support. |
| `Update-PhoenixPackage` | Available | Update one package and safely classify installer-technology migrations. |
| `Open-Phoenix` | Available | Exported Phoenix command. |
| `Get-PhoenixTheme` | Available | Exported Phoenix command. |
| `Install-PhoenixTheme` | Available | Exported Phoenix command. |
| `Export-PhoenixTheme` | Available | Exported Phoenix command. |

## Quick start

```powershell
Set-Location C:\Dev\PhoenixDeploy
Import-Module .\Phoenix.psd1 -Force
Start-Phoenix
```

Phoenix first recovers required runtime directories and configuration, then initializes its runtime context, logging, configured providers, and background services. The Control Center keeps provider checks and inventory work off the desktop thread so the interface can remain responsive. Repeated calls reuse the active context; use `Start-Phoenix -Force` only when a new context generation is required.

## Common examples

```powershell
# Inspect active providers and installed packages
Get-PhoenixProviders
Get-PhoenixPackages

# Install one package
Install-PhoenixPackage -Id '7zip.7zip' -Provider WinGet -Confirm:$false

# Install applicable Windows Update drivers first, then update packages
Update-Phoenix -Provider WinGet -Confirm:$false

# Discover driver updates without installing them
Update-Phoenix -ScanDriversOnly -SkipPackages -Confirm:$false

# Permit eligible non-protected migrations in unattended mode
Update-Phoenix -Provider WinGet -AllowMigration -Unattended -Confirm:$false

# Export a recovery manifest
Backup-Phoenix -OutputPath '.\PhoenixManifest\PhoenixBackup.json'

# Preview a restore without changing the computer
Restore-Phoenix -ManifestPath '.\PhoenixManifest\PhoenixBackup.json' -WhatIf

# Restore drivers first and reinstall missing packages
Restore-Phoenix -ManifestPath '.\PhoenixManifest\PhoenixBackup.json' -Unattended -Confirm:$false
```

## Application and package sources

- WinGet
- Chocolatey
- Scoop
- Local MSI and EXE installers
- GitHub Releases
- PowerShell Gallery
- NuGet v3 feeds

## Current limitations

- Phoenix is currently Windows-only and is under active development.
- Offline recovery and deployment capabilities are being delivered incrementally; see [ROADMAP.md](ROADMAP.md) for the current milestone status.
- Restore does not currently include user profiles, application data, or complete Windows settings migration.
- Destructive deployment, disk, WinPE, and boot-media workflows remain unavailable until their roadmap safety and VM-validation gates are complete.

## Project layout

```text
PhoenixDeploy/
|-- Build/         Class, analysis, test, and release automation
|-- Classes/       PowerShell classes and generated class module
|-- Config/        Phoenix configuration files
|-- Distribution/  Installer, uninstaller, and release instructions
|-- Docs/          Versioned development history and project documentation
|-- Private/       Internal core, logging, provider, driver, inventory, and package functions
|-- Public/        Exported Phoenix commands
|-- Tests/         Pester unit and regression coverage
|-- Themes/        Built-in and installed Control Center themes
|-- Tools/         Git, changelog, README, and release automation
|-- Phoenix.psd1   Module manifest
`-- Phoenix.psm1   Module loader and exports
```

## Git and documentation workflow

The save helper refreshes this generated README section, updates `CHANGELOG.md`, validates Phoenix, creates a Git commit, and can push it to GitHub.

```powershell
.\Tools\Save-PhoenixChange.ps1 `
    -Type feat `
    -Scope update `
    -Summary 'Describe the completed change.' `
    -Push
```

To change the project and GitHub description during a commit:

```powershell
.\Tools\Save-PhoenixChange.ps1 `
    -Type docs `
    -Scope readme `
    -Summary 'Refresh project documentation.' `
    -ProjectDescription 'A new concise project description.' `
    -Push
```
<!-- PHOENIX:GENERATED:END -->
