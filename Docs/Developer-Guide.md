# Phoenix developer guide

Phoenix is a PowerShell 7 module for Windows. Public commands live in `Public`;
internal lifecycle, inventory, provider, driver, restore, and Control Center
functions live in `Private`. Source classes are composed into
`Classes\Phoenix.Classes.psm1` by the build and must not be edited only in the
generated file.

## Validate a change

Run the repository gate from its root:

```powershell
.\Build.ps1 -TestOutput Normal
```

The gate rebuilds the class module, parses PowerShell, runs PSScriptAnalyzer,
and executes unit, integration, and regression tests. Add tests at the lowest
appropriate layer and retain regression coverage for UI bindings and exported
commands.

Long Control Center work must use `New-PhoenixBackgroundOperation`,
`Start-PhoenixBackgroundOperation`, and
`Receive-PhoenixBackgroundOperation`. Supply a bounded timeout, a meaningful
concurrency key, a structured completion callback, and a retry limit. Never
block the WPF dispatcher with provider, inventory, driver, restore, or network
work. Worker results are published atomically and cleanup must target only the
operation's unique temporary directory and exact child process.

Provider code must expose availability separately from capabilities, return
normalized structured results, preserve `ShouldProcess`, surface elevation
and restart needs, and visibly disable unsupported UI actions. Mock external
commands or services in automated tests; reserve mutation for explicit VM
validation.

## Release validation

```powershell
.\Build\New-PhoenixRelease.ps1 -Version 0.2.0 -AllowDirty -Force
.\Build\Test-PhoenixReleaseArchive.ps1 `
    -ArchivePath .\Artifacts\Releases\Phoenix-0.2.0.zip
.\Build\Invoke-PhoenixInstallLifecycleSmoke.ps1 `
    -ArchivePath .\Artifacts\Releases\Phoenix-0.2.0.zip
```

Only publish from a clean commit. `New-PhoenixRelease.ps1 -PublishGitHub`
creates the version tag/release and uploads both the archive and checksum.
Confirm the remote tag, commit, assets, and checksum after publication.
