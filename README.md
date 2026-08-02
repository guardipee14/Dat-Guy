<!-- PHOENIX:GENERATED:START -->
# PhoenixDeploy

PowerShell deployment and recovery framework for Windows application and driver management, inventory, backup and restore, elevated updates, and a customizable desktop Control Center.

**Current module version:** `0.2.0`

**Repository:** [https://github.com/guardipee14/Dat-Guy](https://github.com/guardipee14/Dat-Guy)

**Development history:** [Phoenix v0.2.0](Docs/Phoenix-v0.2.0-Development-History.md)

**Roadmap:** [Phoenix v0.2.0 roadmap](ROADMAP.md)

## What Phoenix can currently do

- Detect and initialize WinGet and Chocolatey package providers, including installation checks for missing providers.
- Install, remove, repair, and update individual packages through a consistent public command layer.
- Run bulk updates with drivers first, package progress reporting, elapsed time, and separate completion summaries.
- Request UAC once, run privileged work in an elevated process, and return structured results to the original window.
- Scan Windows for hardware changes and refresh the installed-driver inventory with visible progress and result codes.
- Search, download, and install applicable driver updates through Windows Update before package updates, with scan-only and reboot reporting.
- Handle installer-technology changes with interactive approval, unattended policy switches, and protected-package safeguards.
- Create a versioned JSON restore manifest containing Phoenix metadata, hardware and network inventory, drivers, packages, and provider capabilities.
- Restore drivers first and reinstall missing WinGet or Chocolatey packages from a versioned Phoenix manifest, with preview, provider filtering, progress, and structured results.
- Collect hardware, network, software, Windows, package, and driver inventory through private inventory engines.
- Keep the desktop responsive while provider checks, inventory, searches, application operations, and driver operations run in isolated workers.
- Queue application install, update, repair, and removal operations in FIFO order when another Control Center operation is active.
- Serialize every Control Center operation through a bounded FIFO scheduler, terminate workers that exceed their timeout, and permit only configured failed-operation retries.
- Start, poll, wait for, or cancel restore work through the shared isolated background-job lifecycle.
- Monitor queued, running, completed, cancelled, and failed Control Center operations in a live Activity grid.
- Filter installed applications by provider, search one provider or every available provider, and review source, installed/available versions, alternatives, update metadata, release notes, support links, and capability-aware actions.
- Cancel, retry, clear, and inspect Activity jobs with result codes, warnings, errors, and restart details.
- Inspect provider availability, health, privilege, and supported operations through one shared contract; unsupported application actions remain disabled.
- Normalize provider results across search, inventory, install, update, repair, remove, export, and restore, including exit, restart, timeout, and cancellation metadata.
- Use complete WinGet search, inventory, silent or interactive install, update, repair, removal, metadata, exit-code, and restart-aware UI flows.
- Use Chocolatey search, inventory, install, update, repair, removal, metadata, privilege, exit-code, and reboot-aware results through the common provider contract.
- Discover and manage Scoop applications with user-scope search, inventory, install, update, removal, export, restore, provider health, and Control Center support.
- Inventory native Windows Installer products without `Win32_Product`, install local MSI packages, and repair or remove product-code records with normalized exit and restart results.
- Model declarative EXE installers, discover registered executable applications, and run supported install, repair, or uninstall commands with vendor-specific success and restart codes.
- Discover GitHub repositories and latest releases, select Windows installer assets by architecture, verify publisher checksums, and delegate installation to the MSI or EXE engine with release notes in the UI.
- Search and inventory PowerShell Gallery modules and scripts, compare installed versions, install/update/remove through PSResourceGet or PowerShellGet, and export or restore resource selections.
- Search configured NuGet v3 feeds, resolve and safely extract packages into a Phoenix-owned user store, and update, remove, export, or restore source-aware package records.
- Inventory and manage online Windows capabilities, optional features, and packages through DISM with administrator policy, stable result codes, and restart-aware UI actions.
- Detect Windows Update/WSUS policy, discover applicable managed updates, and download/install them through Windows Update Agent with source, approval, HRESULT, applicability, and reboot details.
- Select providers through a shared orchestration policy with explicit fallback, capability, elevation, protected-package safety, restore alternatives, and normalized CLI/UI results.
- Use a common OEM driver-adapter contract with manufacturer/hardware applicability, utility approval, Windows Update fallback, version/release/support metadata, and isolated background operations for Dell, HP, Lenovo, Intel, AMD, and NVIDIA.
- Inspect installed driver providers, Windows Update sources and versions, plus live applicability and utility status for all six OEM adapters directly in the Drivers page.
- Build a non-mutating restore plan before execution with per-record actions, installed/requested/available versions, provider alternatives, elevation, safety, dependency, and restart metadata.
- Review restore plans in a dedicated background-powered Control Center page with selection, type/provider/action filters, provider alternatives, and atomic save/reload support.
- Persist restore sessions in versioned checkpoints with manifest/computer identity, immutable history snapshots, atomic current state, per-operation status, retry, timestamp, result, and reboot fields.
- Execute reviewed plans with a checkpoint before and after each operation, resume without repeating completed work, retry eligible failures, recover interrupted records, reject stale manifests, and preserve restart-pending state.
- Verify completed restores by rescanning applications and drivers, classifying per-record outcomes, preserving provider/version/failure details, and showing complete, partial, failed, or restart-pending results in the Control Center.
- Run the repeatable STA Windows VM/WPF smoke gate in `Build\Invoke-PhoenixWindowsVmSmoke.ps1`; see `Docs\Windows-VM-Testing.md` for the standard and administrator test matrix.
- Independently verify release checksums, file manifests, and module imports, then exercise installation, upgrade, responsive launch, preserved-data uninstall, reinstall, and complete removal from the built archive.
- Write Phoenix operational logs with structured severity levels.
- Recover missing runtime directories and damaged configuration automatically while preserving backups, custom values, and a visible recovery journal.
- Isolate Control Center component failures, keep the desktop available, offer retry and safe-layout recovery, and retain structured failure diagnostics.

## Available commands

| Command | Status | Purpose |
|---|---|---|
| `Backup-Phoenix` | Available | Create a versioned JSON restore manifest containing inventory, installed drivers, packages, and provider metadata. |
| `Get-PhoenixContext` | Available | Return the active Phoenix runtime context and optionally require a ready lifecycle. |
| `Get-PhoenixPackages` | Available | Enumerate installed packages reported by active providers. |
| `Get-PhoenixProviders` | Available | List active Phoenix package providers. |
| `Install-PhoenixPackage` | Available | Install a package through WinGet or Chocolatey with elevation and install-mode handling. |
| `Repair-PhoenixPackage` | Available | Repair a supported package using silent or interactive provider behavior. |
| `Receive-PhoenixJob` | Available | Poll or wait for a Phoenix background job and clean up its worker resources. |
| `Restore-Phoenix` | Available | Restore drivers first and reinstall missing WinGet or Chocolatey packages from a Phoenix manifest. |
| `Start-Phoenix` | Available | Create or reuse a ready Phoenix context; use -Force for a new lifecycle generation. |
| `Start-PhoenixRestoreJob` | Available | Start a cancellable restore in an isolated Phoenix worker process. |
| `Stop-PhoenixJob` | Available | Cancel a Phoenix background job and remove its temporary worker resources. |
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

Phoenix first recovers required runtime directories and configuration, then initializes its context, logging, WinGet provider, Chocolatey provider, and missing-provider checks. The desktop defers provider checks to its initial background inventory worker so the interface can render first. Repeated calls reuse the active context; use `Start-Phoenix -Force` only when a new context generation is required.

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

## Supported package providers

- WinGet
- Chocolatey

## Current limitations

- Phoenix is currently Windows-only and is under active development.
- Driver installation supports Windows Update Agent plus Dell, HP, Lenovo, Intel, AMD, and NVIDIA utilities; offline driver packs are not implemented yet.
- Manifest restore reinstalls supported packages and Windows Update drivers; it does not yet restore application data, user profiles, Windows settings, or offline driver packages.
- Package manifests record installed versions for reference, but restore currently installs the provider-current version instead of pinning an exact historical version.
- Protected packages such as Microsoft Edge are not removed unless -ForceProtectedMigration is explicitly supplied.

## Documentation

- [User guide](Docs/User-Guide.md)
- [Troubleshooting](Docs/Troubleshooting.md)
- [Provider guide](Docs/Providers.md)
- [Developer guide](Docs/Developer-Guide.md)
- [Windows VM validation](Docs/Windows-VM-Testing.md)
- [v0.2.0 development history](Docs/Phoenix-v0.2.0-Development-History.md)

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
