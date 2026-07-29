<!-- PHOENIX:GENERATED:START -->
# PhoenixDeploy

PowerShell deployment and recovery framework for Windows package management, driver discovery, inventory, backup, and elevated update workflows.

**Current module version:** `0.1.0`

**Repository:** [https://github.com/guardipee14/Dat-Guy](https://github.com/guardipee14/Dat-Guy)

## What Phoenix can currently do

- Detect and initialize WinGet and Chocolatey package providers, including installation checks for missing providers.
- Install, remove, repair, and update individual packages through a consistent public command layer.
- Run bulk updates with drivers first, package progress reporting, elapsed time, and separate completion summaries.
- Request UAC once, run privileged work in an elevated process, and return structured results to the original window.
- Scan Windows for hardware changes and refresh the installed-driver inventory with visible progress and result codes.
- Search, download, and install applicable driver updates through Windows Update before package updates, with scan-only and reboot reporting.
- Handle installer-technology changes with interactive approval, unattended policy switches, and protected-package safeguards.
- Create a JSON backup manifest containing Phoenix metadata, inventory, drivers, packages, and providers.
- Collect hardware, network, software, Windows, package, and driver inventory through private inventory engines.
- Write Phoenix operational logs with structured severity levels.

## Available commands

| Command | Status | Purpose |
|---|---|---|
| `Backup-Phoenix` | Available | Export system inventory, installed drivers, packages, and provider state to a JSON manifest. |
| `Get-PhoenixContext` | Available | Return the active Phoenix runtime context. |
| `Get-PhoenixPackages` | Available | Enumerate installed packages reported by active providers. |
| `Get-PhoenixProviders` | Available | List active Phoenix package providers. |
| `Install-PhoenixPackage` | Available | Install a package through WinGet or Chocolatey with elevation and install-mode handling. |
| `Repair-PhoenixPackage` | Available | Repair a supported package using silent or interactive provider behavior. |
| `Restore-Phoenix` | Planned | Reserved public restore command; full restore orchestration is not implemented yet. |
| `Start-Phoenix` | Available | Initialize configuration, logging, providers, scheduling, and missing-provider checks. |
| `Update-Phoenix` | Available | Install applicable Windows Update drivers first, then update packages, and return structured results. |
| `Remove-PhoenixPackage` | Available | Uninstall a package through WinGet or Chocolatey with elevation support. |
| `Update-PhoenixPackage` | Available | Update one package and safely classify installer-technology migrations. |

## Quick start

```powershell
Set-Location C:\Dev\PhoenixDeploy
Import-Module .\Phoenix.psd1 -Force
Start-Phoenix
```

Phoenix initializes its runtime context, logging, WinGet provider, Chocolatey provider, and missing-provider checks.

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
```

## Supported package providers

- WinGet
- Chocolatey

## Current limitations

- Phoenix is currently Windows-only and is under active development.
- Driver installation currently uses Windows Update Agent; OEM-specific update tools, vendor catalogs, and offline driver packs are not implemented yet.
- Restore-Phoenix is currently a placeholder; complete manifest-driven restoration is still planned.
- Protected packages such as Microsoft Edge are not removed unless -ForceProtectedMigration is explicitly supplied.

## Project layout

```text
PhoenixDeploy/
|-- Classes/       PowerShell classes and generated class module
|-- Config/        Phoenix configuration files
|-- Private/       Internal core, logging, provider, driver, inventory, and package functions
|-- Public/        Exported Phoenix commands
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
