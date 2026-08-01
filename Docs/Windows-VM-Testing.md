# Phoenix Windows VM testing

Phoenix v0.1.33 includes a repeatable, non-destructive Control Center smoke gate
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

## v0.1.33 validation record

The standard-user pass completed on `TESTWINDOWS` with Windows build 26200 and
PowerShell 7.6.4. It resolved 138 runtime controls, measured all six Control
Center pages, and bound live rows for 10 providers, 92 applications, 70
drivers, and six OEM sources. The administrator-token pass remains part of the
v0.2.0 release gate and must be run from an elevated VM session. A separate
real-process lifecycle check opened the shipped `Phoenix Control Center`
window, confirmed that it remained responsive while live inventory ran in the
background, and closed it cleanly.

The full repository gate remains:

```powershell
pwsh -NoProfile -File .\Build.ps1 -TestOutput Normal
```
