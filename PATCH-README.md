# Phoenix Windows Update Driver Patch

This patch was built from the current `main` branch of `guardipee14/Dat-Guy`.

## Files

- `Private/Drivers/Invoke-PhoenixWindowsUpdateDriver.ps1` (new)
- `Private/Drivers/Update-PhoenixDriver.ps1`
- `Public/Update-Phoenix.ps1`
- `Tools/Update-PhoenixReadme.ps1`

## Behavior

`Update-Phoenix` now searches Windows Update for applicable driver updates, downloads and installs them before package updates, refreshes installed-driver inventory, reports per-stage counts, and returns the structured driver result to the original non-admin window.

Use `-ScanDriversOnly` to search without downloading or installing.

## Safe first test

```powershell
Set-Location C:\Dev\PhoenixDeploy

Remove-Module Phoenix -Force -ErrorAction SilentlyContinue
Import-Module '.\Phoenix.psd1' -Force
Start-Phoenix

$result = Update-Phoenix `
    -ScanDriversOnly `
    -SkipPackages `
    -Confirm:$false
```

## Installation test

```powershell
$result = Update-Phoenix `
    -SkipPackages `
    -Unattended `
    -Confirm:$false
```

## Commit

```powershell
.\Tools\Save-PhoenixChange.ps1 `
    -Type feat `
    -Scope drivers `
    -Summary 'install applicable drivers through Windows Update' `
    -Details @(
        'Search Windows Update Agent for applicable driver updates.',
        'Download and install drivers before package updates.',
        'Add scan-only, unattended, progress, reboot, and structured-result handling.',
        'Refresh generated README capabilities and limitations.'
    ) `
    -Push
```
