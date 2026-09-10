# Windows image workspaces

Phoenix v0.2.13 provides a source-preserving x64 image transaction layer.
Use the Windows Image page in the Control Center or these PowerShell commands
from PowerShell 7 on Windows with the x64 ADK installed:

```powershell
$workspace = New-PhoenixWindowsImageWorkspace -SourceImagePath C:\Media\install.wim -ImageIndex 6 -Path C:\PhoenixWork\Image
Get-PhoenixWindowsImageWorkspace -Path $workspace.RootPath
Mount-PhoenixWindowsImage -WorkspacePath $workspace.RootPath -ReadOnly
Dismount-PhoenixWindowsImage -WorkspacePath $workspace.RootPath -Mode Discard
Remove-PhoenixWindowsImageWorkspace -Path $workspace.RootPath -WhatIf
```

Choose the index from your own media; the example index is not an edition
recommendation. WIM indexes retain their source number. ESD staging exports only
the explicitly selected source index into working WIM index 1. The source path,
source hash, source index, and current working-image hash are recorded separately.
Select a local WIM/ESD file; direct ISO selection is not part of this command.

Mount without `-ReadOnly` to allow edits to the isolated copy. Commit saves changes
only to `images\working.wim`; discard abandons uncommitted changes. Phoenix does
not modify the original image. v0.2.14 adds the content-injection workflow below.
Commands support `-WhatIf`; mounting and dismounting require elevation.
The Control Center does not silently elevate or install the ADK.

Before each transaction Phoenix validates ownership, regular non-reparse paths,
state, and the Windows servicing registry. Dismount requires one healthy mount
with the exact working WIM, index, mount directory, and read/write mode. Cleanup
also queries Windows and refuses a live or abandoned mount even if metadata says
Ready. Workspace operation locks prevent concurrent Phoenix transactions.

Intent is persisted before DISM. A crash, cancellation, timeout, or failed tool
call leaves evidence rather than an apparently clean Ready workspace. Do not
delete it manually or run global DISM cleanup. Inspect `workspace.json` and
`Get-WindowsImage -Mounted`. A healthy exact owned mount may be explicitly
discarded; an invalid/mismatched mount stops for administrator investigation.
An interrupted transaction cannot be committed as though it succeeded.

Validation distinguishes mocked safety tests and real private-copy mount,
commit, and discard tests from boot tests. This release does not certify a
serviced image's bootability and never requires writing a physical USB disk.

## v0.2.13 validation record

The September 9, 2026 release gate passed 462 automated tests with zero analyzer
errors or blocking findings (397 warnings). The Windows 11 standard-token UI
smoke resolved 162 controls and measured all eight pages. Real ADK testing on
the physical validation host confirmed writable/read-only mounts, persistence
after commit, removal after discard, and zero remaining mounts. Original WinPE
WIM SHA-256 remained
`FBCBDB1C6651AB3A69384E9D4F95F2C02321318603849453B252E21E827C8197`.
A separate real recovery-compressed ESD export, working-WIM mount, source
preservation, and owned cleanup also passed. No VMs were changed in these tests.

The commands follow Microsoft's documented
[DISM image-management operations](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/dism-image-management-command-line-options-s14).

## Offline content injection (v0.2.14)

Mount a working copy writable, then preview explicit selections:

```powershell
Add-PhoenixWindowsImageContent -WorkspacePath C:\PhoenixWork\Image -Type Driver -Value C:\Drivers\Network\device.inf -WhatIf
Add-PhoenixWindowsImageContent -WorkspacePath C:\PhoenixWork\Image -Type Package -Value C:\Packages\update.cab -WhatIf
Add-PhoenixWindowsImageContent -WorkspacePath C:\PhoenixWork\Image -Type Capability -Value 'OpenSSH.Client~~~~0.0.1.0' -SourcePath C:\Media\FeaturesOnDemand -WhatIf
```

Choose media compatible with your image. Remove `-WhatIf` to request injection;
commit remains a separate explicit action. The Windows Image page exposes the
same preview and add commands. Driver selections must be explicit INF files
with DISM reporting signed x64 metadata. Driver installers and directory-wide
automatic selection are not accepted. A package selection must be an applicable
CAB; updates distributed as MSU containers require separate inspection and
extraction. This release does not resolve arbitrary MSU dependency chains.

Supply dependencies in their required order and confirm each is applicable to
the current image. Phoenix will not ignore applicability errors or force an
unsigned driver. Capabilities always require an offline source and LimitAccess;
there is no automatic Windows Update fallback. Capability support depends on
the image and its servicing stack; WinPE is not a full-Windows capability test.

Inputs are hashed before staging, copied into a unique workspace subdirectory,
rehashed, and re-inspected before DISM. The driver package's parent directory is
staged with its catalog and binaries. Inputs inside the image workspace are
rejected. Keep enough free disk space for staging and servicing scratch data.
No input file or host driver installation is changed by injection.

The servicing directory retains operation JSON and DISM logs. A successful
operation must pass installed-package/capability state or installed-driver INF
hash verification. Already-installed items are reported as skipped. A restart
result stops the batch and reports later inputs as not run; no reboot occurs.
InstallPending means first-boot verification is still needed, not that final
validation is complete. Failed mutations keep workspace state Failed, preventing
an unreviewed commit; inspect the records and explicitly discard the owned mount.

Real-image validation added WinPE-WMI and its en-US package, plus signed
VBoxNetAdp6.inf, to a private WinPE copy on DONAVEN. All persisted after commit
and read-only remount, the duplicate package was skipped, original inputs were
preserved, and no mounts remained. Capability injection and failure policies
have automated mock coverage; this release does not claim live full-Windows
capability or serviced-image boot certification.
