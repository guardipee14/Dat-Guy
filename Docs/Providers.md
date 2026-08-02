# Phoenix provider guide

Phoenix normalizes provider availability, capabilities, privilege, progress,
exit codes, timeouts, cancellation, warnings, errors, and restart state. The
Control Center enables an action only when both the provider and selected
record support it.

| Provider | Primary scope | Supported behavior |
|---|---|---|
| WinGet | Applications | Search, inventory, install, update, repair, remove, export, restore, metadata |
| Chocolatey | Applications | Search, inventory, install, update, repair, remove, export, restore |
| Scoop | Applications | User-scope search, inventory, install, update, remove, export, restore |
| MSI | Applications | Product-code inventory, local install, repair, removal, restart codes |
| EXE | Applications | Declarative install, registered inventory, supported repair/removal commands |
| GitHub Releases | Applications | Repository discovery, release metadata, architecture assets, checksum verification, delegated install |
| PowerShell Gallery | Applications | Module/script search, inventory, install, update, remove, export, restore |
| NuGet | Applications | Configured v3 feeds, safe extraction to the Phoenix store, update/remove/export/restore |
| DISM | Windows components | Online capabilities, optional features, packages, enable/install/disable/remove |
| WSUS / Windows Update | Managed updates | Policy/source discovery, applicability, download, install, reboot reporting |

The orchestration layer selects eligible providers, applies protected-package
and elevation policy, exposes alternatives, and returns one normalized result
to both PowerShell and the Control Center. A fallback is used only when its
capability and safety contract match the requested action.

Driver support uses a parallel adapter contract. Windows Update is the common
fallback; Dell, HP, Lenovo, Intel, AMD, and NVIDIA adapters report hardware and
manufacturer applicability, utility state, versions, release/support links,
and restart requirements. Phoenix asks before installing an OEM utility.

Provider-current versions are used during restore when an exact historical
version is unavailable. Offline package feeds, offline driver packs, WinPE,
image servicing, and bare-metal deployment are outside the 0.2.0 scope.

Provider implementations live under `Private\Providers`; adapter contracts
and concrete implementations live under `Private\Drivers`. New providers must
implement the shared capability/result contract, remain safe when unavailable,
and include mocked tests plus Control Center integration coverage.
