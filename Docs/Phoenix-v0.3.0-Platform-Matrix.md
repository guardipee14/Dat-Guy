# Phoenix v0.3.0 platform matrix

This document defines the supported execution boundary for Phoenix v0.3.0.

The baseline was established during Phoenix v0.2.2 after successful standard-user
and administrator-token Windows VM smoke validation.

Last reviewed: 2026-08-05

## Status definitions

- **Validated**: Passed the applicable live Phoenix gates on the listed platform.
- **Supported**: Inside the v0.3.0 execution boundary, with validation still required.
- **Detect only**: Phoenix may inventory and report the platform but must not perform
  deployment, image-servicing, disk-writing, or removable-media execution.
- **Rejected**: Phoenix must stop before acquisition, mounting, servicing, formatting,
  media writing, or deployment execution.

## Windows host and target matrix

| Platform | Architecture | Phoenix status | Validation status |
| --- | --- | --- | --- |
| Windows 11 25H2 | x64 | Validated primary platform | Standard and administrator VM smoke gates passed |
| Windows 11 24H2 | x64 | Supported | Full lifecycle and deployment validation pending |
| Windows 10 Enterprise LTSC 2021 | x64 | Transitional support while Microsoft-supported | Validation pending |
| Windows 11 26H1, build 28000 | Any | Detect only | Outside the Phoenix v0.3.0 x64 ADK boundary |
| Windows 10 general-availability releases | Any | Rejected | Microsoft servicing has ended |
| Windows Server | Any | Detect only | Not a v0.3.0 host or deployment target |
| Non-Windows operating systems | Any | Rejected | Outside project scope |

Windows support also requires the exact edition and release to remain inside its
Microsoft servicing lifecycle. Phoenix must not treat an expired Windows release
as supported merely because its build number is recognized.

## PowerShell matrix

| Runtime | Architecture | Phoenix status |
| --- | --- | --- |
| PowerShell 7.6 LTS, latest servicing update | x64 | Required execution host |
| Other PowerShell 7 versions | Any | Detect and report; mutation blocked until explicitly validated |
| Windows PowerShell 5.1 | Any | Bootstrap or diagnostics only; deployment execution rejected |
| PowerShell preview releases | Any | Rejected for release validation and production execution |
| Any 32-bit PowerShell process | x86 | Rejected |

Phoenix v0.3.0 release validation must use the latest supported servicing update
from the PowerShell 7.6 LTS family.

## Architecture matrix

| Component | Required architecture |
| --- | --- |
| Phoenix host process | x64 |
| Windows host | x64 |
| Windows deployment target | x64 |
| Windows PE workspace and media | x64 |
| Offline Windows image | x64 |

Arm64 and x86 systems, images, deployment kits, and Windows PE media may be
identified and reported but are not v0.3.0 execution targets.

## Firmware and disk requirements

| Capability | Requirement |
| --- | --- |
| Firmware | UEFI required for deployment execution |
| System and target disk style | GPT required |
| Legacy BIOS | Detect only |
| MBR deployment target | Rejected |
| Secure Boot state | Detected and reported; not modified by Phoenix |
| Secure Boot key management | Outside v0.3.0 |
| Exact target-disk identity | Required before destructive execution |
| System-disk protection | Required |
| Typed confirmation | Required before formatting or media writing |

An unknown Secure Boot state does not by itself change the UEFI/GPT platform
classification. Phoenix must still report that the Secure Boot state could not
be determined.

## Windows ADK and WinPE matrix

### Required x64 baseline

- Windows ADK `10.1.26100.2454`.
- Matching Windows PE add-on for ADK `10.1.26100.2454`.
- Windows ADK patch `KB5079391` or a later applicable servicing patch.
- x64 deployment tools and x64 Windows PE.
- ADK and WinPE components from the same version family.

This baseline supports the Phoenix v0.3.0 Windows 11 24H2 and 25H2 x64
deployment boundary and earlier Windows releases that remain supported.

### Unsupported deployment-kit combinations

- ADK installations older than `10.1.26100.2454`.
- ADK `10.1.26100.2454` without `KB5079391` or a later applicable patch.
- Missing Windows PE add-on when a WinPE operation is requested.
- ADK and Windows PE components from different version families.
- ADK `10.1.28000.1` and its Windows 11 26H1 Arm64 WinPE add-on.
- x86 Windows PE.
- Preview or Insider ADK builds.

Missing ADK or WinPE components must produce a readiness result and remediation
guidance. Phoenix must not begin downloading, mounting, servicing, or writing
media until the complete required toolchain is present.

## v0.2.2 validation record

The current validation environment produced the following record:

| Property | Result |
| --- | --- |
| Computer | `TESTWINDOWS` |
| Hypervisor | VirtualBox |
| Windows edition | Windows 11 Pro |
| Windows version | 25H2 |
| Windows build | `26200.8894` |
| Architecture | x64 |
| PowerShell | `7.6.4` Core |
| Firmware | UEFI |
| System disk | GPT |
| ADK installed | No |
| Windows PE add-on installed | No |
| Secure Boot state | Indeterminate in the standard-user probe |

Both privilege scenarios passed against the same source tree:

| Gate | Standard token | Administrator token |
| --- | ---: | ---: |
| Phoenix context reached `Ready` | Yes | Yes |
| Expected token matched | Yes | Yes |
| Runtime controls resolved | 139 | 139 |
| Control Center pages measured | 6 | 6 |
| Providers bound | 10 | 10 |
| Applications bound | 91 | 91 |
| Drivers bound | 70 | 70 |
| OEM adapters bound | 6 | 6 |
| Privilege policy matched | Yes | Yes |

The administrator scenario confirmed that administrator operations are allowed
without requesting another elevation. The standard scenario confirmed that user
operations remain available while administrator operations require elevation.

## Enforcement policy

Before any deployment operation becomes executable, Phoenix must evaluate and
return structured readiness for:

1. Supported Windows release and edition.
2. x64 operating system and x64 PowerShell process.
3. Supported PowerShell 7.6 LTS servicing release.
4. UEFI firmware and GPT target requirements.
5. Supported and patched Windows ADK.
6. Matching Windows PE add-on.
7. Exact source, image, media, and disk identity.
8. Required administrator token.
9. Preview and typed confirmation.
10. Any operation-specific safety requirements.

A failed or unknown required check must stop execution before Phoenix changes
the host, target image, disk, or removable media.

## Microsoft references

- Windows 11 release information:
  https://learn.microsoft.com/windows/release-health/windows11-release-information
- Download and install the Windows ADK:
  https://learn.microsoft.com/windows-hardware/get-started/adk-install
- PowerShell support lifecycle:
  https://learn.microsoft.com/powershell/scripting/install/powershell-support-lifecycle
- Windows 10 Enterprise LTSC 2021 lifecycle:
  https://learn.microsoft.com/lifecycle/products/windows-10-enterprise-ltsc-2021
