# Phoenix v0.2.0 Development History

**Release:** v0.2.0

**Date:** 2026-08-01
**Objective:** deliver a stable, non-blocking Windows Control Center with
complete provider integration and a planned, resumable, verified restore
workflow.

## Release train

Phoenix v0.2.0 was developed as 33 independently validated public releases
after the v0.1.1 installer hotfix:

| Version | Completed milestone |
|---|---|
| v0.1.2 | Public v0.2.0 roadmap and incremental release workflow |
| v0.1.3 | Recoverable, idempotent context lifecycle |
| v0.1.4 | Directory, configuration, and runtime recovery |
| v0.1.5 | Control Center exception isolation and recovery |
| v0.1.6 | Shared background-job contract |
| v0.1.7 | Background inventory, provider initialization, and search |
| v0.1.8 | FIFO application-operation queue |
| v0.1.9 | Cancellable background driver and restore work |
| v0.1.10 | Live Activity operation display |
| v0.1.11 | Activity cancel, retry, clear, and details |
| v0.1.12 | Common provider capability and result contract |
| v0.1.13 | Complete WinGet behavior and UI coverage |
| v0.1.14 | Complete Chocolatey behavior and UI coverage |
| v0.1.15 | Scoop provider and UI integration |
| v0.1.16 | MSI provider and UI integration |
| v0.1.17 | Declarative EXE provider and UI integration |
| v0.1.18 | GitHub Releases provider |
| v0.1.19 | PowerShell Gallery provider |
| v0.1.20 | NuGet v3 provider and Phoenix package store |
| v0.1.21 | Online DISM capability and package management |
| v0.1.22 | WSUS policy, discovery, and installation |
| v0.1.23 | Provider orchestration, selection, and fallback |
| v0.1.24 | Shared OEM driver-adapter framework |
| v0.1.25 | Dell and HP driver adapters |
| v0.1.26 | Lenovo and Intel driver adapters |
| v0.1.27 | AMD and NVIDIA driver adapters |
| v0.1.28 | Non-mutating restore planning engine |
| v0.1.29 | Restore Plan UI, selection, and alternatives |
| v0.1.30 | Versioned restore-checkpoint storage |
| v0.1.31 | Resume, retry, interruption, and reboot state |
| v0.1.32 | Post-restore verification engine and UI |
| v0.1.33 | Complete live UI binding and Windows VM smoke gate |
| v0.2.0 | Final operation hardening, docs, packaging, and lifecycle validation |

The train began from v0.1.0, the first public module release, and v0.1.1, the
PowerShell 7 double-click installer correction. Each intermediate version was
tested, committed, pushed, packaged, checksummed, tagged, and published before
the next milestone began.

## Final architecture

Phoenix initializes one recoverable context, isolates provider and desktop
component failures, and keeps long work in child PowerShell processes. The
Control Center serializes operations through a FIFO scheduler. Each operation
has a timeout, concurrency classification, cancellation state, bounded retry
budget, atomic progress/result files, and exact process/directory cleanup.

Ten application and Windows-management providers share availability,
capability, privilege, safety, progress, result-code, error, timeout,
cancellation, and restart semantics. Six OEM driver adapters share hardware
applicability and utility-approval behavior with Windows Update fallback.

Restore work is planned before mutation, can be filtered and edited, saves
versioned checkpoints around every operation, resumes without repeating
successful work, and verifies the final application and driver state.

## Release evidence

The v0.2.0 gate rebuilds generated classes, parses and analyzes the module,
runs the complete automated suite, loads all six WPF pages and every runtime
control in a real Windows VM, and confirms that the live desktop remains
responsive while inventory runs outside the dispatcher.

The final candidate passed 237 of 237 automated tests with zero analyzer
errors and zero blocking findings. Its standard-user VM pass resolved 138
controls and all six pages with live rows from 10 providers, 92 applications,
70 drivers, and six OEM adapters. The environment did not provide UAC consent
for the separate administrator-token smoke; that operator-run pass remains
explicitly unclaimed.

The runtime ZIP is produced from an allowlist. `RELEASE.json` records each
file's length and SHA-256 hash plus module, Git, license, Windows, and
PowerShell metadata. A separate verifier checks the outer checksum, extracts
the archive to an isolated directory, validates every manifest entry, and
imports the packaged module in a clean child process.

The install lifecycle gate uses only a uniquely named temporary CurrentUser
path. It verifies clean installation, in-place upgrade and user-data
preservation, a responsive installed Control Center process, normal uninstall
with preserved data, reinstall, and complete removal with `-RemoveUserData`.

## Scope boundary

Phoenix v0.2.0 manages the running Windows installation. Offline recovery
bundles, bootable USB media, WinPE, Windows image deployment, unattended OS
installation, pre-OS driver injection, disk layout, answer files, and full
bare-metal deployment remain planned after v0.2.0.
