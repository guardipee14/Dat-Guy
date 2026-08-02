# Phoenix user guide

Phoenix 0.2.0 is a Windows application, driver, inventory, backup, restore,
and recovery tool. Its desktop Control Center keeps long work outside the WPF
interface thread and reports progress in Activity.

## Install and start

Extract `Phoenix-0.2.0.zip`, open its `Phoenix-0.2.0` directory, and run
`Install-Phoenix.cmd`. The launcher requires PowerShell 7.4 or later and
installs for the current user by default. Start Phoenix from its Start menu
shortcut or run `Phoenix.cmd`.

For a scripted install:

```powershell
.\Install-Phoenix.ps1 -Scope CurrentUser
```

Use an elevated PowerShell window with `-Scope AllUsers` for a machine-wide
installation. Upgrades preserve configuration, recovery state, caches,
checkpoints, logs, and installed themes.

## Control Center

Applications shows installed and available versions, providers, sources,
alternatives, metadata, and only the actions each provider supports. Search
one provider or all searchable providers. Review the confirmation prompt
before an install, update, repair, or removal.

Drivers combines installed Windows drivers, Windows Update candidates, and
Dell, HP, Lenovo, Intel, AMD, and NVIDIA adapter status. Phoenix checks
hardware applicability and requires approval before adding OEM utilities.

Restore Plan imports a Phoenix backup, classifies proposed work, shows
provider alternatives and safety requirements, and lets you select operations
before execution. Checkpoints allow interrupted work to resume; verification
rescans the computer after execution.

Activity shows queued, running, completed, cancelled, and failed operations.
Phoenix runs one Control Center operation at a time. A worker that exceeds its
configured timeout is stopped and reported as failed. Failed operations can be
retried only while their retry budget remains.

Themes changes the built-in appearance or installs a custom Phoenix theme.

## Backup and restore from PowerShell

```powershell
Import-Module .\Phoenix.psd1 -Force
Start-Phoenix
Backup-Phoenix -OutputPath .\PhoenixBackup.json
Restore-Phoenix -ManifestPath .\PhoenixBackup.json -WhatIf
Restore-Phoenix -ManifestPath .\PhoenixBackup.json -Confirm:$false
```

Use `-WhatIf` first. Phoenix restores supported applications and drivers; it
does not restore user files, application data, profiles, or Windows settings.

## Uninstall

The normal uninstaller preserves configuration and installed themes. Select
the Phoenix uninstall entry in Windows Settings or run:

```powershell
.\Uninstall-Phoenix.ps1
```

For complete removal, including Phoenix user data:

```powershell
.\Uninstall-Phoenix.ps1 -RemoveUserData
```
