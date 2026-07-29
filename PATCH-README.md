# Phoenix manifest restore patch

Extract this archive into `C:\Dev\PhoenixDeploy` and allow it to replace the existing files.

## Added

- Versioned `PhoenixRestoreManifest` schema (`2.0`).
- Reliable package, driver, provider, hardware, network, and OS backup records.
- Manifest validation and compatibility with the earlier top-level manifest layout.
- One-time UAC elevation for the complete restore.
- Driver-first restore using the existing Windows Update driver workflow.
- Missing-package restoration through WinGet and Chocolatey.
- Installed-package detection to avoid unnecessary reinstalls.
- `-WhatIf`, provider filtering, scan-only drivers, unattended mode, stop-on-error, and reinstall switches.
- Structured restore results and a parent-window completion summary.
- README automation updates for the completed restore command.

## Safe validation sequence

```powershell
Set-Location C:\Dev\PhoenixDeploy

$tokens = $null
$parseErrors = $null

$paths = @(
    '.\Private\Core\Get-PhoenixPropertyValue.ps1'
    '.\Private\Core\Read-PhoenixManifest.ps1'
    '.\Private\Core\Request-PhoenixElevation.ps1'
    '.\Private\Core\Write-PhoenixRestoreSummary.ps1'
    '.\Private\Packages\ConvertTo-PhoenixRestorePackage.ps1'
    '.\Private\Packages\New-PhoenixRestorePackageResult.ps1'
    '.\Public\Backup-Phoenix.ps1'
    '.\Public\Restore-Phoenix.ps1'
    '.\Tools\Update-PhoenixReadme.ps1'
)

foreach ($path in $paths) {
    $tokens = $null
    $parseErrors = $null

    [System.Management.Automation.Language.Parser]::ParseFile(
        (Resolve-Path $path).Path,
        [ref]$tokens,
        [ref]$parseErrors
    ) | Out-Null

    $parseErrors |
        Select-Object `
            @{Name = 'File'; Expression = { $path }},
            @{Name = 'Line'; Expression = {
                $_.Extent.StartLineNumber
            }},
            Message
}
```

No output means the changed PowerShell files parsed successfully.

## Create a fresh manifest

```powershell
Remove-Module Phoenix -Force -ErrorAction SilentlyContinue
Import-Module '.\Phoenix.psd1' -Force
Start-Phoenix

$backup = Backup-Phoenix `
    -OutputPath '.\PhoenixManifest\PhoenixBackup.json' `
    -Confirm:$false

$backup |
    Format-List Success, Code, Message, Data, Errors
```

Expected result code: `PHX_BACKUP_COMPLETE`.

## Preview the restore

```powershell
$preview = Restore-Phoenix `
    -ManifestPath '.\PhoenixManifest\PhoenixBackup.json' `
    -WhatIf

$preview |
    Format-List Success, Code, Message, Data
```

Expected result code: `PHX_RESTORE_PREVIEW`. No UAC or installation should occur.

## Safe same-machine package test

This skips drivers and should classify the manifest packages as already installed rather than reinstalling them.

```powershell
$result = Restore-Phoenix `
    -ManifestPath '.\PhoenixManifest\PhoenixBackup.json' `
    -SkipDrivers `
    -Unattended `
    -Confirm:$false
```

Approve UAC, then inspect the returned results:

```powershell
$result |
    Select-Object `
        @{Name = 'Stage'; Expression = { $_.Data.Stage }},
        @{Name = 'Item'; Expression = {
            if ($_.Data.Stage -eq 'Driver') {
                'Windows Update drivers'
            }
            else {
                $_.Data.Id
            }
        }},
        Success,
        Code,
        Message |
    Format-Table -AutoSize
```

Expected package code on the original computer: `PHX_RESTORE_ALREADY_INSTALLED`.

## Driver scan plus package test

```powershell
$result = Restore-Phoenix `
    -ManifestPath '.\PhoenixManifest\PhoenixBackup.json' `
    -ScanDriversOnly `
    -Unattended `
    -Confirm:$false
```

This searches for driver updates without installing them and restores only missing packages.

## Actual restore on a rebuilt computer

```powershell
$result = Restore-Phoenix `
    -ManifestPath 'D:\Backups\PhoenixBackup.json' `
    -Unattended `
    -Confirm:$false
```

Phoenix processes Windows Update drivers first, then reinstalls missing WinGet and Chocolatey packages.

## Current restore boundaries

- Package versions are recorded, but restore currently installs the provider-current version.
- Application data, user profiles, Windows settings, and credentials are not restored.
- Driver restore uses Windows Update; OEM tools and offline driver packs are not yet supported.

## Commit after validation

```powershell
.\Tools\Save-PhoenixChange.ps1 `
    -Type feat `
    -Scope restore `
    -Summary 'restore drivers and packages from a Phoenix manifest' `
    -Details @(
        'Create a versioned and restorable backup manifest.',
        'Restore Windows Update drivers before packages.',
        'Reinstall missing WinGet and Chocolatey packages.',
        'Add preview, provider filtering, progress, and structured restore summaries.'
    ) `
    -Push
```
