<!-- PHOENIX:GENERATED:START -->
# PhoenixDeploy

PowerShell deployment and recovery framework for Windows applications, drivers, updates, restore workflows, offline recovery, and a desktop Control Center.

**Current release:** `v0.2.15`

**Repository:** [https://github.com/guardipee14/Dat-Guy](https://github.com/guardipee14/Dat-Guy)

**Latest release:** [Phoenix v0.2.15](https://github.com/guardipee14/Dat-Guy/releases/tag/v0.2.15)

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
- Export installed third-party driver packages into the content-addressed store and catalog normalized hardware identities, provider, class, version, architecture, date, and signing state.
- Rank compatible offline driver packages deterministically against target hardware without installing them.
- Verify bundle hashes, provenance, redistributable-license approval, and trusted-publisher records through explicit fail-closed policies.
- Build, inspect, incrementally update, export, and ownership-safely remove Phoenix offline bundles while reusing unchanged content.
- Capture source provenance, Authenticode status, and publisher identity for eligible bundle payloads.

### WinPE prerequisites and workspaces

- Discover the Windows Kits root and supported x64 Windows ADK and WinPE locations without changing the host.
- Report ADK DISM, Oscdimg, the WinPE base WIM, media tree, and optional-component availability with exact paths.
- Return typed readiness results containing host architecture support, missing requirements, warnings, versions, and check time.
- Create versioned Phoenix-owned WinPE workspaces without modifying source media or the base WIM.
- Preview creation, roll back partial staging failures, and remove only exact, unmounted, ownership-verified workspaces.

### Control Center and background work

- Generate restricted, secret-free Windows answer files from the Unattended Setup page.
- Use explicit SecureString inputs through PowerShell for one deployment-specific local account or product key; reusable files never create blank-password accounts.
- See [Unattended setup](Docs/Unattended-Setup.md) for secret handling and the required image-specific Windows SIM validation.

- Create and inspect source-preserving x64 image workspaces on the Windows Image page.
- Mount private WIM copies read-only or writable, then explicitly commit or discard with live mount-identity checks.
- Export an explicitly selected ESD index into a working WIM and retain source and working-image hashes.
- See [Windows image servicing](Docs/Windows-Image-Servicing.md) for commands, prerequisites, and failed-transaction handling.
- Preview and inject signed x64 INF drivers, applicable CAB packages/updates, and explicitly sourced offline capabilities into private mounted images.
- Hash and stage servicing inputs, record each operation, verify installed state, skip duplicates, and stop on failure or a required restart.

- Build or resume, inspect, verify, and safely clean up recovery bundles from a dedicated Control Center page.
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

> Phoenix v0.2.12 adds ADK bootable ISO creation and guarded removable-media staging. The ISO was built and its payload verified on DONAVEN. Physical USB writing has not been certified; see [boot-media guidance](Docs/Boot-Media.md).

## Available commands

| Command | Status | Purpose |
|---|---|---|
| `Backup-Phoenix` | Available | Create a versioned JSON restore manifest containing inventory, installed drivers, packages, and provider metadata. |
| `New-PhoenixBootableIso` | Available | Build a bootable ISO from a Ready workspace using ADK Oscdimg. |
| `Copy-PhoenixBootableMedia` | Lab validation | Preview and stage verified media to an explicitly identified removable disk. |
| `Export-PhoenixOfflineBundle` | Available | Copy a verified Phoenix offline bundle to a new destination. |
| `Get-PhoenixContext` | Available | Return the active Phoenix runtime context and optionally require a ready lifecycle. |
| `Get-PhoenixDeploymentPrerequisite` | Available | Discover supported x64 Windows ADK and WinPE prerequisites without changing the host. |
| `Get-PhoenixOfflineBundle` | Available | Inspect a Phoenix-owned offline bundle and its integrity summary. |
| `Get-PhoenixRestoreCheckpoint` | Available | Exported Phoenix command. |
| `Get-PhoenixPackages` | Available | Enumerate installed packages reported by active providers. |
| `Get-PhoenixProviders` | Available | List active Phoenix package providers. |
| `Install-PhoenixPackage` | Available | Install a package through WinGet or Chocolatey with elevation and install-mode handling. |
| `Import-PhoenixRestorePlan` | Available | Exported Phoenix command. |
| `Invoke-PhoenixRestorePlan` | Available | Exported Phoenix command. |
| `New-PhoenixOfflineBundle` | Available | Build a Phoenix-owned content-addressed offline bundle from selected files. |
| `New-PhoenixRestorePlan` | Available | Exported Phoenix command. |
| `New-PhoenixWinPEWorkspace` | Available | Create a transactional Phoenix-owned WinPE workspace from preserved source inputs. |
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
| `Test-PhoenixOfflineBundle` | Available | Verify bundle integrity and optionally enforce provenance, redistribution, and publisher-trust policy. |
| `Update-Phoenix` | Available | Install applicable Windows Update drivers first, then update packages, and return structured results. |
| `Remove-PhoenixPackage` | Available | Uninstall a package through WinGet or Chocolatey with elevation support. |
| `Remove-PhoenixOfflineBundle` | Available | Remove only a verified Phoenix-owned offline-bundle root. |
| `Remove-PhoenixWinPEWorkspace` | Available | Remove only an exact, unmounted, ownership-verified WinPE workspace. |
| `Update-PhoenixPackage` | Available | Update one package and safely classify installer-technology migrations. |
| `Update-PhoenixOfflineBundle` | Available | Incrementally add selected content while reusing unchanged objects. |
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

# Discover Windows ADK and WinPE readiness without changing the host
$readiness = Get-PhoenixDeploymentPrerequisite

# Preview a transactional WinPE workspace without writing it
New-PhoenixWinPEWorkspace -Path '.\Work\WinPE' -Prerequisite $readiness -WhatIf
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
- Windows-image servicing and deployment workflows remain on the roadmap. Physical removable-media writing remains subject to the documented lab-validation boundary.

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
