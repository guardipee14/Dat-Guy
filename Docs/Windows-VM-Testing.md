# Phoenix Windows VM testing

Phoenix v0.2.0 includes a repeatable, non-destructive Control Center smoke gate
for Windows virtual machines. It loads the shipped module and WPF XAML, starts
the Phoenix lifecycle with provider installation disabled, collects live
inventory, resolves every runtime control, validates the grid bindings, lays
out every page, and checks the privilege contract.

Run the standard-user scenario from the repository root:

```powershell
pwsh -NoProfile -Sta -File .\Build\Invoke-PhoenixWindowsVmSmoke.ps1 `
    -ExpectedPrivilege Standard
```

Run the administrator scenario from an already elevated PowerShell 7 window:

```powershell
pwsh -NoProfile -Sta -File .\Build\Invoke-PhoenixWindowsVmSmoke.ps1 `
    -ExpectedPrivilege Administrator
```

Add `-ReportPath <path>` to save the structured
`PhoenixWindowsVmSmoke/1.0` JSON report. The smoke test never installs,
updates, repairs, removes, or restores software or drivers.

## v0.2.0 validation gates

The standard-user gate must resolve every shipped runtime control, measure all
six Control Center pages, bind live provider, application, driver, and OEM
rows, and confirm the expected token. The administrator gate runs the same
contract from an already elevated PowerShell 7 session. Neither gate performs
mutating provider or driver actions.

Build and independently verify the release archive, then validate its complete
CurrentUser lifecycle:

```powershell
.\Build\New-PhoenixRelease.ps1 -Version 0.2.0 -AllowDirty -Force
.\Build\Test-PhoenixReleaseArchive.ps1 `
    -ArchivePath .\Artifacts\Releases\Phoenix-0.2.0.zip
.\Build\Invoke-PhoenixInstallLifecycleSmoke.ps1 `
    -ArchivePath .\Artifacts\Releases\Phoenix-0.2.0.zip
```

The lifecycle gate installs only inside a uniquely named temporary directory,
performs an in-place upgrade, confirms an installed Control Center window is
responsive, validates preserved user data, reinstalls, performs complete
removal, and cleans its temporary workspace.

## v0.2.0 validation record

The standard-user pass completed on `TESTWINDOWS` with Windows build 26200 and
PowerShell 7.6.4. It resolved 138 runtime controls, measured all six pages,
and bound 10 providers, 92 applications, 70 drivers, and six OEM adapters.

The packaged lifecycle gate passed clean installation, in-place upgrade,
responsive launch, preserved-data uninstall, reinstall, and complete removal.
Independent verification passed all 127 runtime files and a clean packaged
module import.

The administrator-token launch was attempted from the standard session, but
Windows did not receive UAC consent within the bounded 120-second window. No
elevated smoke process or report remained. The live administrator-token pass
must therefore be run from an already elevated PowerShell 7 window; Phoenix
does not claim that environment-only pass in this record.

The full repository gate remains:

```powershell
pwsh -NoProfile -File .\Build.ps1 -TestOutput Normal
```
