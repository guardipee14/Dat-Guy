# Phoenix distribution

Phoenix releases are runtime-only ZIP archives created by
`Build\New-PhoenixRelease.ps1`.

## Build a local release

Run the normal validation pipeline and create a versioned archive:

```powershell
$releaseResult =
    .\Build\New-PhoenixRelease.ps1 `
        -Version '0.2.0'

$releaseResult | Format-List
```

The archive and its SHA-256 checksum are written to
`Artifacts\Releases`.

The release payload includes the full public documentation set, complete
v0.2.0 development history, and public roadmap.

Use `-AllowDirty` only while testing uncommitted release changes:

```powershell
.\Build\New-PhoenixRelease.ps1 `
    -Version '0.2.0' `
    -AllowDirty
```

## Install

Extract the release archive, enter its versioned directory, and double-click:

```text
Install-Phoenix.cmd
```

The launcher finds PowerShell 7, verifies that version 7.4 or later is
available, runs the PowerShell installer for the current user, displays the
result, and waits for a key press before closing. It uses a process-only
execution-policy override and does not change the user's permanent PowerShell
execution policy.

For scripted installation, run:

```powershell
$installResult =
    .\Install-Phoenix.ps1

$installResult | Format-List
```

The default installation is per-user under
`$env:LOCALAPPDATA\Programs\Phoenix`.

For a machine-wide installation, use an Administrator PowerShell window:

```powershell
.\Install-Phoenix.ps1 `
    -Scope AllUsers
```

Both installation scopes support `-NoShortcuts`, `-Launch`, `-WhatIf`, and a
custom `-InstallPath`.

Upgrades preserve:

- `Config\Phoenix.json`
- `Config\Phoenix.UI.json`
- `Config\Settings.json`
- `Config\Recovery`
- `Cache\ControlCenter`
- `Cache\Recovery`
- `Checkpoints`
- `Logs`
- `Themes\Installed`

## Uninstall

Phoenix appears in Windows installed applications and includes an uninstaller
shortcut.

By default, uninstall preserves configuration and installed themes:

```powershell
.\Uninstall-Phoenix.ps1
```

Remove the application and all user data:

```powershell
.\Uninstall-Phoenix.ps1 `
    -RemoveUserData
```

## Verify a release

Independently verify a locally built archive before publication:

```powershell
.\Build\Test-PhoenixReleaseArchive.ps1 `
    -ArchivePath .\Artifacts\Releases\Phoenix-0.2.0.zip
```

On Windows, run the complete installed-product lifecycle gate:

```powershell
.\Build\Invoke-PhoenixInstallLifecycleSmoke.ps1 `
    -ArchivePath .\Artifacts\Releases\Phoenix-0.2.0.zip
```

The lifecycle gate uses an isolated temporary CurrentUser installation and
removes it completely when validation finishes.

## Publish a GitHub release

After committing and pushing a clean working tree:

```powershell
.\Build\New-PhoenixRelease.ps1 `
    -Version '0.2.0' `
    -PublishGitHub
```

This creates the `v0.2.0` GitHub release and uploads both the ZIP and checksum.
Use `-Prerelease` when the GitHub release should be marked as a prerelease.

## License

Phoenix is available under:

```text
MIT OR Apache-2.0 OR GPL-3.0-or-later
```

Each recipient may choose any one of those licenses. Complete texts are
included in `LICENSES`.
