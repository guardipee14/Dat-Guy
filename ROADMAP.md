# Phoenix roadmap

This roadmap tracks the work planned for Phoenix v0.3.0.

Phoenix v0.2.0 established a stable, non-blocking Control Center, normalized
application and driver providers, planned and resumable restore operations,
post-restore verification, and independently verified Windows packaging. The
complete v0.2.0 record is preserved in
`Docs/Phoenix-v0.2.0-Development-History.md`.

## Status

- `[x]` Completed and merged
- `[ ]` Planned or in progress

An item is checked only after its backend behavior, safety policy, Control
Center integration, automated tests, Windows VM validation, and documentation
are complete. Destructive deployment features remain unavailable until their
planning, preview, identity, confirmation, rollback, and VM gates pass.
Every public Phoenix release must update both `ROADMAP.md` and GitHub issue #2
with the exact version, completion status, and released scope before packaging
or GitHub publication. The release builder verifies the checked repository
entry and synchronizes the GitHub roadmap during publication.

## Phoenix v0.3.0

### Release objective

Deliver a safe offline recovery and Windows deployment foundation that can
build verified recovery bundles, create bootable WinPE media, service offline
Windows images, generate unattended setup inputs, and execute reviewed
deployment plans in isolated Windows virtual machines.

### Supported v0.3.0 boundary

- Windows 10 and Windows 11 x64 hosts and targets.
- UEFI/GPT as the required deployment path; legacy BIOS/MBR is detected and
  reported but is not a v0.3.0 execution target.
- Microsoft-supported Windows ADK and WinPE add-on discovery.
- Locally attached ISO, WIM/ESD, folder, and removable-media sources.
- Offline application and driver bundles built from explicit selections.
- Offline image servicing through supported Windows tools and mounted-image
  transactions.
- Destructive disk or media actions only after exact target identity,
  non-system-disk policy, preview, typed confirmation, and administrator
  checks succeed.

Production PXE/WDS hosting, fleet orchestration, remote wipe, firmware
flashing, Secure Boot key management, domain-secret storage, user-profile
migration, and non-Windows targets remain outside v0.3.0.

### Release train

Phoenix v0.3.0 will be developed through 19 public `0.2.x` releases followed
by the final v0.3.0 release. Every milestone must pass its focused backend,
Control Center, automated-test, roadmap, packaging, checksum, tag, and GitHub
release gates before the next milestone begins.

- [x] `v0.2.1` - Control Center recovery, restore-manifest creation, automatic
      Scoop installation, and existing Scoop shim detection
- [x] `v0.2.2` - Complete elevated-token VM validation and define the v0.3.0
      platform matrix
- [x] `v0.2.3` - Deployment capability, privilege, safety, and result contracts
- [x] `v0.2.4` - Versioned offline-bundle schema and content-addressed store
- [ ] `v0.2.5` - Offline application acquisition and provider export adapters
- [ ] `v0.2.6` - Offline driver export, cataloging, and hardware matching
- [ ] `v0.2.7` - Bundle integrity, provenance, licensing, and trust verification
- [ ] `v0.2.8` - Offline-bundle build, update, inspect, and verify commands
- [ ] `v0.2.9` - Offline-bundle Control Center workflow with resume and cleanup
- [ ] `v0.2.10` - Windows ADK and WinPE prerequisite discovery and diagnostics
- [ ] `v0.2.11` - Transactional WinPE workspace and image construction
- [ ] `v0.2.12` - Bootable ISO creation and guarded removable-media staging
- [ ] `v0.2.13` - Transactional offline Windows-image mount and servicing engine
- [ ] `v0.2.14` - Offline driver, package, capability, and update injection
- [ ] `v0.2.15` - Typed unattended answer-file generation and secret policy
- [ ] `v0.2.16` - Disk-layout planning, validation, preview, and target identity
- [ ] `v0.2.17` - Guarded deployment execution in disposable Windows VMs
- [ ] `v0.2.18` - Deployment checkpoints, reboot resume, rollback, and diagnostics
- [ ] `v0.2.19` - End-to-end recovery-media and new-PC workflow validation
- [ ] `v0.3.0` - Final hardening, documentation, packaging, and public release

## 1. Carry-forward validation and platform policy

- [x] Complete the live administrator-token Control Center smoke gate left
      unclaimed by the v0.2.0 release environment.
- [ ] Record standard-user, administrator, clean-install, upgrade, and complete
      removal results for every supported host version.
- [x] Define supported Windows host and target builds, PowerShell versions,
      architectures, UEFI/GPT requirements, ADK versions, and WinPE versions.
- [ ] Reject unsupported combinations before downloading, mounting, writing,
      formatting, or servicing anything.
- [ ] Expose platform readiness and missing prerequisites in PowerShell and the
      Control Center.

## 2. Deployment architecture and safety contract

- [ ] Define typed source, target, media, image, bundle, disk-plan, deployment,
      checkpoint, progress, result, warning, error, and reboot models.
- [ ] Separate discovery and planning from acquisition, servicing, media
      writing, and deployment execution.
- [ ] Require `SupportsShouldProcess` and meaningful `-WhatIf` behavior for
      every mutating public command.
- [ ] Centralize administrator, target-identity, system-disk, removable-media,
      mount-state, free-space, power, and reboot safety policy.
- [ ] Require exact disk number, stable hardware identity, size, bus type, and
      serial confirmation before a destructive action can be enabled.
- [ ] Block the current system disk and ambiguous targets by default without a
      hidden or unattended bypass.
- [ ] Run acquisition, hashing, mounting, servicing, media creation, and
      deployment through bounded background operations.
- [ ] Serialize DISM, mount, driver injection, media write, disk, and reboot
      operations with explicit concurrency keys.
- [ ] Guarantee exact-process and exact-workspace cleanup after success,
      cancellation, timeout, failure, or application shutdown.

## 3. Offline recovery bundles

- [ ] Define a versioned bundle manifest with Phoenix, Windows, hardware,
      provider, source, package, driver, dependency, license, and provenance
      metadata.
- [ ] Store payloads by SHA-256 identity and deduplicate identical content.
- [ ] Acquire eligible WinGet, Chocolatey, Scoop, MSI, EXE, GitHub Releases,
      PowerShell Gallery, and NuGet payloads through provider adapters.
- [ ] Export installed applications only when their provider can produce a
      redistributable or user-supplied offline artifact.
- [ ] Record unavailable, non-redistributable, interactive-only, or
      source-restricted items instead of silently omitting them.
- [ ] Export third-party drivers with INF, catalog, binary, provider, class,
      version, architecture, hardware IDs, and signature details.
- [ ] Match exported drivers to target hardware without installing them.
- [ ] Verify every payload length and hash before sealing a bundle and again
      before consuming it.
- [ ] Record publisher signatures when available and make trust policy visible.
- [ ] Generate a software bill of materials and third-party license inventory.
- [ ] Support incremental bundle refresh without rebuilding unchanged content.
- [ ] Support cancellation, retry, checkpoint resume, and safe partial cleanup.
- [ ] Add PowerShell commands and a Control Center workflow to build, inspect,
      update, verify, export, and remove Phoenix-owned bundles.

## 4. Windows ADK, WinPE, and bootable media

- [ ] Discover the Windows ADK, WinPE add-on, DISM, Oscdimg, optional component
      sources, architectures, and supported version pairings.
- [ ] Provide actionable installation diagnostics without automatically
      downloading the ADK unless the user explicitly approves it.
- [ ] Create an isolated, versioned WinPE workspace without modifying source
      media.
- [ ] Mount and unmount WinPE images transactionally with abandoned-mount
      detection and recovery.
- [ ] Add Phoenix runtime files, PowerShell requirements, storage/network
      support, selected drivers, optional components, and startup scripts.
- [ ] Keep secrets and machine-specific answer files out of reusable base
      images by default.
- [ ] Build a reproducible bootable ISO and independently inspect its contents.
- [ ] Stage bootable removable media only after target identity, system-disk
      blocking, preview, typed confirmation, elevation, and free-space checks.
- [ ] Never select removable media by drive letter alone.
- [ ] Verify written media structure and payload hashes after creation.

## 5. Offline Windows-image servicing

- [ ] Read WIM, ESD, ISO, folder, and mounted-image metadata without mutation.
- [ ] Select image indexes explicitly and reject ambiguous editions or
      architectures.
- [ ] Copy read-only source images into Phoenix-owned workspaces before any
      operation that requires a writable image.
- [ ] Model mount, inspect, service, validate, commit, discard, export, and
      cleanup as checkpointed transactions.
- [ ] Detect and recover Phoenix-owned abandoned mounts without touching
      foreign DISM mounts.
- [ ] Inject applicable signed drivers and report skipped, unsigned,
      incompatible, boot-critical, and duplicate packages.
- [ ] Add or remove supported Windows packages, capabilities, features, and
      cumulative updates in dependency-safe order.
- [ ] Validate servicing-stack and cumulative-update applicability before
      mutation.
- [ ] Preserve source artifacts and commit to a distinct output image.
- [ ] Verify output image metadata, indexes, packages, drivers, file hashes,
      and bootability inputs after servicing.

## 6. Unattended setup and disk planning

- [ ] Define typed, versioned models for regional settings, edition, image
      index, product-key policy, local accounts, privacy choices, network,
      partition layout, and first-boot actions.
- [ ] Generate and schema-validate `autounattend.xml` and `unattend.xml` from
      explicit configuration.
- [ ] Separate reusable configuration from secrets and default to interactive
      secret entry at deployment time.
- [ ] Never log plaintext passwords, product keys, tokens, recovery keys, or
      wireless secrets.
- [ ] Redact secrets from reports, checkpoints, errors, and diagnostic bundles.
- [ ] Validate generated answer files with Windows Setup tools where available.
- [ ] Define UEFI/GPT disk plans with EFI, Microsoft Reserved, Windows,
      recovery, and optional data partitions.
- [ ] Calculate sizes and alignment deterministically from the exact target
      disk and configuration.
- [ ] Preview the complete partition and format plan before execution.
- [ ] Require administrator state, exact target identity, non-system-disk
      policy, typed confirmation, and a recent preview token before execution.
- [ ] Reject plans that would target the running OS, contain overlapping or
      invalid partitions, exceed capacity, or omit required boot partitions.
- [ ] Keep disk-plan execution disabled outside disposable VM validation until
      the full destructive-operation test matrix passes.

## 7. Deployment execution, checkpoints, and recovery

- [ ] Build a reviewed deployment plan before changing a target disk or image.
- [ ] Stage source validation, disk preparation, image application, boot-file
      creation, recovery configuration, answer-file placement, bundle restore,
      and first-boot verification as explicit operations.
- [ ] Save a checkpoint before and after every mutating operation.
- [ ] Resume only when source, target, disk, image, plan, and machine identity
      still match the checkpoint.
- [ ] Never repeat completed destructive operations during resume.
- [ ] Preserve restart-pending, first-boot, verification, and rollback state.
- [ ] Distinguish retryable acquisition failures from non-retryable identity,
      integrity, safety, partition, and image failures.
- [ ] Capture DISM, Windows Setup, BCDBoot, disk, WinPE, provider, and Phoenix
      diagnostics in a redacted support bundle.
- [ ] Provide an explicit rollback or safe-stop result for every phase; do not
      claim rollback where the underlying Windows action is irreversible.
- [ ] Verify boot configuration, partitions, applied image, drivers, packages,
      Phoenix bundle state, and first-boot completion.

## 8. Control Center experience

- [ ] Add a Recovery Bundle page for selection, size estimation, acquisition,
      trust review, build progress, verification, and export.
- [ ] Add Deployment Media and Windows Image pages for prerequisite status,
      source/index selection, servicing plans, WinPE options, and output paths.
- [ ] Add an Unattended Setup editor with validation and secret-safe fields.
- [ ] Add a Disk Plan preview that names the exact target and makes destructive
      consequences unambiguous.
- [ ] Add a Deployment Activity view with phase, operation, target, checkpoint,
      elapsed time, warnings, errors, restart state, and diagnostics.
- [ ] Keep every long-running action off the WPF dispatcher.
- [ ] Disable every unavailable, unsafe, unsupported, or insufficiently
      reviewed action instead of allowing a late failure.
- [ ] Preserve navigation, details, logs, cancellation, and safe recovery while
      background work is active.

## 9. Testing, security, and release gate

- [ ] Add unit tests for every schema, planner, validator, safety rule,
      serializer, provider export adapter, and result classification.
- [ ] Add malicious-manifest, archive traversal, symlink/reparse-point,
      signature, tamper, stale-checkpoint, path-boundary, and secret-redaction
      tests.
- [ ] Add mocked ADK, DISM, Oscdimg, Windows Setup, BCDBoot, storage, mount,
      package, driver, and removable-media adapter tests.
- [ ] Add cancellation, timeout, retry, concurrency, cleanup, abandoned-mount,
      insufficient-space, and interrupted-servicing tests.
- [ ] Add static regression guards preventing system-disk overrides, drive-
      letter-only targeting, plaintext secret logging, and unreviewed mutation.
- [ ] Run non-destructive host tests as standard user and administrator.
- [ ] Run destructive disk, media, servicing, unattended-setup, reboot-resume,
      and first-boot tests only in disposable snapshot-backed VMs.
- [ ] Cover Windows 10 and Windows 11 x64 targets, supported ADK/WinPE pairs,
      clean disks, existing partitions, insufficient disks, mismatched images,
      network loss, cancellation, and reboot interruption.
- [ ] Verify a created ISO boots, enters Phoenix recovery, detects storage and
      network, reads its bundle, and produces diagnostics.
- [ ] Verify an end-to-end new-PC VM reaches Windows first boot, restores the
      selected bundle, resumes checkpoints, and passes post-deployment checks.
- [ ] Keep `Build.ps1` green with zero analyzer errors and zero blocking
      findings at every release.
- [x] Require a checked, scope-accurate `ROADMAP.md` entry for every public
      release and synchronize GitHub issue #2 during publication.
- [ ] Independently verify every archive, checksum, tag, GitHub release, bundle,
      image, and boot-media artifact.
- [ ] Publish user, administrator, bundle, WinPE, image-servicing, unattended,
      deployment, troubleshooting, provider, security, and developer docs.
- [ ] Publish the complete Phoenix v0.3.0 development-history document.

## Definition of done for v0.3.0

- [x] The carried-forward administrator-token VM gate passes.
- [ ] Offline bundles are deterministic, deduplicated, inspectable, resumable,
      license-aware, provenance-aware, and independently hash verified.
- [ ] Unsupported or unavailable offline application artifacts are reported
      accurately and never represented as captured.
- [ ] Exported drivers retain applicability, catalog, signature, provider,
      version, and hardware identity.
- [ ] Phoenix builds and verifies a bootable WinPE ISO from supported ADK
      inputs without modifying source media.
- [ ] Removable-media staging cannot target the running system disk and requires
      exact identity, preview, confirmation, elevation, and post-write checks.
- [ ] Offline servicing preserves source media, uses Phoenix-owned mounts, and
      produces a separately verified output image.
- [ ] Answer files validate successfully and no plaintext secret appears in
      logs, reports, checkpoints, or support bundles.
- [ ] Disk plans are deterministic, capacity-valid, previewed, and blocked from
      unsafe targets.
- [ ] Interrupted deployment resumes without repeating completed destructive
      work or accepting changed identities.
- [ ] A disposable Windows 10 VM and Windows 11 VM complete the supported
      deployment workflow and pass first-boot verification.
- [ ] The Control Center stays responsive through acquisition, hashing,
      mounting, servicing, media creation, and deployment.
- [ ] Automated tests pass with zero failures.
- [ ] PSScriptAnalyzer reports zero errors and zero blocking findings.
- [ ] Installation, upgrade, launch, normal uninstall, and complete removal pass
      on every supported host matrix entry.
- [ ] The repository, release archive, checksum, tag, GitHub release, bundle,
      ISO, serviced image, and validation records are independently verified.

## Planned after v0.3.0

- [ ] Production PXE, WDS, or iPXE deployment services
- [ ] Multi-computer fleet orchestration and remote deployment
- [ ] Remote wipe or decommission workflows
- [ ] Firmware, BIOS, or Secure Boot key management
- [ ] BitLocker recovery-key escrow and enterprise secret integration
- [ ] Active Directory or cloud directory enrollment automation
- [ ] User-profile and application-data migration
- [ ] ARM64 deployment and non-Windows targets
- [ ] Physical-hardware destructive certification beyond documented lab tests
