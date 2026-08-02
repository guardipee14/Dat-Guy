# Phoenix troubleshooting

## Phoenix does not start

Confirm Windows is running PowerShell 7.4 or later:

```powershell
pwsh -NoProfile -Command '$PSVersionTable.PSVersion'
```

Run `Phoenix-Desktop.cmd` to bypass the mode chooser. If elevation is not
available, start the desktop directly with:

```powershell
pwsh -NoProfile -Sta -File .\Tools\Start-PhoenixControlCenter.ps1 `
    -Mode Desktop -NoElevation
```

Phoenix recreates missing runtime directories and repairs damaged generated
configuration while preserving a backup and recovery journal.

## A provider is unavailable

Open Applications and inspect its provider status. Availability, health,
scope, elevation, and supported actions are reported separately. A disabled
button means the selected record or provider does not support that action; it
is not a UI failure.

WinGet and Chocolatey can be initialized by Phoenix when policy permits.
Scoop is user-scoped. MSI and registered EXE actions depend on discoverable
product metadata. DISM, WSUS, some driver operations, and AllUsers changes
require an administrator token.

## An operation is queued, times out, or fails

Phoenix serializes Control Center operations. Open Activity to see queue
position, progress, elapsed time, warnings, result codes, restart state, and
errors. Cancel affects only the selected active or queued operation.

A timeout stops the exact worker process and records a failed operation.
Retry is available only for failed work with retry budget remaining. Review
the error first; repeated installer, policy, network, or elevation failures
usually require correcting the underlying condition.

## A restore cannot resume

Phoenix rejects stale manifests, incompatible checkpoint schemas, and
checkpoints from a different computer by default. Keep the original manifest
unchanged and use the matching checkpoint session. A restart-pending record
may require Windows to restart before verification can complete.

## Installation or upgrade fails integrity checks

Keep the ZIP and `.sha256` file together and extract a fresh copy. Verify the
download from a repository checkout:

```powershell
.\Build\Test-PhoenixReleaseArchive.ps1 `
    -ArchivePath .\Artifacts\Releases\Phoenix-0.2.0.zip
```

The installer also verifies every runtime file against `RELEASE.json` before
changing an existing installation. It rolls back from its staging backup if
an upgrade cannot complete.

## Diagnostics

Phoenix logs are under the installed `Logs` directory. Activity details retain
provider result codes, warnings, errors, and restart requirements. Repository
validation is run with:

```powershell
.\Build.ps1 -TestOutput Normal
```
