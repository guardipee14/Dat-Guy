# Phoenix v0.1.1 Development History

**Project:** PhoenixDeploy / Phoenix

**Release:** v0.1.1

**Release date:** July 30, 2026

**Author:** Donaven Guardipee

**Repository:** https://github.com/guardipee14/Dat-Guy

**License:** `MIT OR Apache-2.0 OR GPL-3.0-or-later`

## Purpose

Phoenix v0.1.1 is a focused installation-experience hotfix released after the
v0.1.0 package was tested through Windows Explorer.

The complete architecture, feature, testing, packaging, and release history for
the first Phoenix release remains in
[`Phoenix-v0.1.0-Development-History.md`](Phoenix-v0.1.0-Development-History.md).
This document records only the problem discovered after publication and the
work performed to correct and verify it.

## Problem discovered

The v0.1.0 release included `Install-Phoenix.ps1` as its installer entry point.
The PowerShell installer worked correctly when invoked from PowerShell, and its
clean-install, upgrade, preservation, recovery, and removal behaviors passed
the release smoke test.

However, double-clicking `Install-Phoenix.ps1` in Windows Explorer opened the
Windows **Open with** dialog instead of running the installer.

This was not an error inside `Install-Phoenix.ps1`. Windows intentionally does
not guarantee that `.ps1` files are associated with script execution. The
behavior protects users from accidentally executing downloaded PowerShell
scripts, but it made Phoenix's release package inconvenient for someone who
expected a normal double-click installer.

## Hotfix design

Phoenix v0.1.1 adds:

```text
Install-Phoenix.cmd
```

The CMD launcher is the new double-click entry point. The existing
`Install-Phoenix.ps1` remains the installation engine so command-line
automation and all previously tested installer behavior remain unchanged.

The launcher:

- starts from its own extracted release directory;
- looks for `pwsh.exe` on `PATH`;
- falls back to `%ProgramFiles%\PowerShell\7\pwsh.exe`;
- displays an actionable message when PowerShell 7 is unavailable;
- requires PowerShell 7.4 or later;
- invokes the existing `Install-Phoenix.ps1`;
- uses `ExecutionPolicy Bypass` only for the launched PowerShell process;
- does not change the user's permanent execution policy;
- installs Phoenix for the current Windows user by default;
- reports success or failure and the process exit code;
- waits for a key press so the console result remains visible.

Scripted installation continues to support:

```powershell
.\Install-Phoenix.ps1
```

including CurrentUser and AllUsers scopes, custom paths, shortcut selection,
launch behavior, `ShouldProcess`, and `-WhatIf`.

## Release packaging correction

`Build\New-PhoenixRelease.ps1` now places all three distribution entry files at
the root of every release archive:

- `Install-Phoenix.cmd`
- `Install-Phoenix.ps1`
- `Uninstall-Phoenix.ps1`

The release instructions now lead with double-click installation and retain
the PowerShell example for automation and advanced options.

## Regression coverage

The release regression suite now verifies that:

- `Distribution\Install-Phoenix.cmd` exists;
- the launcher invokes PowerShell 7;
- the standard Program Files fallback is present;
- the launcher invokes `Install-Phoenix.ps1`;
- the process-only execution-policy override is present;
- PowerShell 7.4 or later is required;
- the console waits before closing;
- the release builder includes the CMD launcher.

The Phoenix test baseline increased from 48 to 49 tests.

## Runtime verification

The v0.1.1 release candidate was built with 95 runtime files and tested through
the intended end-user workflow.

The test completed as follows:

1. The release ZIP was extracted.
2. Its folder was opened in Windows Explorer.
3. `Install-Phoenix.cmd` was double-clicked.
4. The launcher displayed:

   ```text
   Phoenix installation completed successfully.
   ```

5. The installed module reported version `0.1.1`.
6. Windows installed-app registration reported version `0.1.1`.
7. The installation location was
   `%LOCALAPPDATA%\Programs\Phoenix`.
8. The Desktop Control Center shortcut was present.
9. The Start Menu Control Center shortcut was present.
10. The Start Menu Theme Studio shortcut was present.
11. The Start Menu uninstall shortcut was present.
12. Complete removal with `-RemoveUserData` succeeded.
13. The installation directory was removed.
14. Windows installed-app registration was removed.
15. Desktop and Start Menu shortcuts were removed.

## Compatibility and release scope

The hotfix does not change:

- package-provider behavior;
- driver behavior;
- inventory;
- backup or restore manifests;
- the Control Center;
- themes;
- logging;
- configuration preservation;
- installer transaction behavior;
- uninstaller behavior;
- the v0.1.0 license choice.

Phoenix remains licensed under:

```text
MIT OR Apache-2.0 OR GPL-3.0-or-later
```

The v0.1.0 release assets and checksum remain unchanged. Phoenix v0.1.1 is a
separate patch release so users and maintainers can verify exactly which
archive contains the double-click installation fix.

## Release statement

Phoenix v0.1.1 corrects the first-run Windows installation experience without
replacing or weakening the tested PowerShell installer. Users can now extract
the release and double-click `Install-Phoenix.cmd`, while administrators and
automation continue to use `Install-Phoenix.ps1` directly.

The next comprehensive development-history document remains planned for
Phoenix v0.2.0.
