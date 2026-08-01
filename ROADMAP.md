# Phoenix roadmap

This roadmap tracks the work planned for Phoenix v0.2.0.

Phoenix is a PowerShell deployment and recovery framework for Windows
application management, driver management, inventory, backup and restore,
elevated updates, and a customizable desktop Control Center.

## Status

- `[x]` Completed and merged
- `[ ]` Planned or in progress

Roadmap items may be refined as implementation and Windows VM testing reveal
new requirements. An item is checked only after its backend behavior, Control
Center integration, automated tests, and documentation are complete.

## Earlier releases

- [x] Phoenix v0.1.0 - First public release
- [x] Phoenix v0.1.1 - Double-click Windows installer hotfix

## Phoenix v0.2.0

### Release objective

Deliver a stable, non-blocking Control Center with complete provider
integration and a planned, resumable, verified restore workflow.

### Release train

Phoenix v0.2.0 will be developed through 33 public, independently validated
releases after v0.1.1. Each release must pass its backend, Control Center,
automated-test, packaging, checksum, tag, and GitHub publication gates.

- [x] `v0.1.2` - Publish the v0.2.0 roadmap and incremental release workflow
- [x] `v0.1.3` - Reliable Phoenix context initialization and lifecycle
- [x] `v0.1.4` - Automatic directory, configuration, and runtime recovery
- [x] `v0.1.5` - Control Center exception isolation and desktop recovery
- [x] `v0.1.6` - Shared background-job contract
- [x] `v0.1.7` - Background inventory, provider initialization, and searches
- [x] `v0.1.8` - Background application operation queue
- [x] `v0.1.9` - Background driver and restore jobs with cancellation
- [x] `v0.1.10` - Activity Center live job display
- [x] `v0.1.11` - Activity cancellation, retry, clearing, and result details
- [x] `v0.1.12` - Common provider capability and result contract
- [x] `v0.1.13` - Complete WinGet behavior and UI verification
- [x] `v0.1.14` - Complete Chocolatey behavior and UI verification
- [x] `v0.1.15` - Implement Scoop and connect it to the UI
- [x] `v0.1.16` - Implement MSI packages and connect them to the UI
- [x] `v0.1.17` - Implement EXE package definitions and UI operations
- [x] `v0.1.18` - Implement the GitHub Releases provider
- [x] `v0.1.19` - Implement the PowerShell Gallery provider
- [x] `v0.1.20` - Implement the NuGet provider
- [x] `v0.1.21` - Implement online DISM capability and package management
- [x] `v0.1.22` - Implement WSUS policy, discovery, and installation support
- [x] `v0.1.23` - Phoenix provider orchestration, selection, and fallback
- [x] `v0.1.24` - Common OEM driver-adapter framework
- [x] `v0.1.25` - Dell and HP driver integration
- [x] `v0.1.26` - Lenovo and Intel driver integration
- [x] `v0.1.27` - AMD and NVIDIA driver integration
- [x] `v0.1.28` - Restore planning engine
- [x] `v0.1.29` - Restore Plan UI, selection, and provider alternatives
- [x] `v0.1.30` - Versioned restore-checkpoint storage
- [x] `v0.1.31` - Restore resume, retry, interruption, and reboot state
- [x] `v0.1.32` - Restore verification engine and UI results
- [ ] `v0.1.33` - Complete UI integration and end-to-end Windows VM testing
- [ ] `v0.2.0` - Final hardening, documentation, packaging, and public release

### 1. Runtime stability

- [x] Make Phoenix context initialization idempotent and recoverable.
- [x] Automatically create required configuration, theme, cache, checkpoint,
      and working directories.
- [x] Prevent a failed component from closing the desktop interface.
- [x] Add UI-safe exception boundaries with structured Phoenix results.
- [x] Prevent duplicate state during repeated starts, refreshes, and provider
      initialization.
- [ ] Validate administrator and standard-user behavior.
- [x] Add regression tests for initialization, recovery, missing directories,
      and repeated startup.

### 2. Background job system

- [x] Define a common Phoenix background-job contract.
- [x] Move inventory collection off the WPF interface thread.
- [x] Move provider initialization off the desktop startup path.
- [x] Move package searches off the WPF interface thread.
- [x] Move application operations off the WPF interface thread.
- [x] Move driver operations off the WPF interface thread.
- [x] Move OEM driver operations off the WPF interface thread.
- [x] Move restore planning, execution, and verification off the WPF interface
      thread.
- [x] Add created, starting, running, cancellation-requested, cancelled,
      completed, and failed lifecycle states.
- [x] Add queued state and queue scheduling.
- [x] Add cancellation and deterministic process and file cleanup.
- [ ] Add retry, timeout, and concurrency controls.
- [ ] Serialize drivers, reboots, protected packages, and conflicting
      installers when required.
- [x] Return structured progress and results to the Control Center.
- [x] Detect workers that exit without publishing a result.
- [x] Add regression guards that long operations use background workers and
      avoid synchronous dispatcher calls.
- [ ] Validate live Control Center responsiveness during long operations in a
      Windows VM.

### 3. Activity Center

- [x] Display queued and running jobs.
- [x] Display completed, cancelled, and failed jobs.
- [x] Show target, action, provider, start time, and elapsed time.
- [x] Show determinate or indeterminate progress.
- [x] Show warnings, errors, exit codes, and Phoenix result codes.
- [x] Show restart requirements.
- [x] Add cancel, retry, and clear-completed controls.
- [x] Preserve running work when the user changes tabs.
- [x] Add Activity Center UI-binding and lifecycle tests.

### 4. Provider completion

#### Common provider behavior

- [x] Define a shared provider capability and availability contract.
- [x] Normalize search, inventory, install, update, repair, remove, export, and
      restore results.
- [x] Disable unsupported UI actions instead of presenting nonfunctional
      controls.
- [x] Normalize privilege, reboot, timeout, cancellation, and exit-code
      reporting.
- [x] Add provider health and capability information to the Control Center.
- [x] Test every provider with mocked external commands or services.

#### WinGet

- [x] Strengthen search and installed-package correlation.
- [x] Strengthen install, update, repair, and uninstall handling.
- [x] Normalize metadata, release details, reboot results, and error codes.
- [x] Verify all supported WinGet actions from the Applications tab.

#### Chocolatey

- [x] Align Chocolatey operations with the common provider contract.
- [x] Normalize search, inventory, install, update, repair, and uninstall
      results.
- [x] Verify all supported Chocolatey actions from the Applications tab.

#### Scoop

- [x] Implement availability and installation checks.
- [x] Implement search and installed-package inventory.
- [x] Implement install, update, and uninstall.
- [x] Implement export and restore support.
- [x] Add Scoop selection, status, and results to the Applications tab.

#### MSI

- [x] Detect MSI product codes and installed versions.
- [x] Implement silent and interactive installation.
- [x] Implement repair and uninstall.
- [x] Normalize MSI success, failure, and reboot exit codes.
- [x] Add MSI package definitions and results to the Applications tab.

#### EXE

- [x] Define declarative EXE installer metadata.
- [x] Implement silent and interactive installation.
- [x] Detect installed versions and registered uninstall commands.
- [x] Implement repair and uninstall when supported.
- [x] Normalize vendor exit codes and restart requirements.
- [x] Add EXE package definitions and results to the Applications tab.

#### GitHub Releases

- [x] Implement repository and release discovery.
- [x] Select assets by Windows architecture and package definition.
- [x] Compare installed and available versions.
- [x] Verify downloaded asset hashes when publishers provide them.
- [x] Install supported release assets through the appropriate package engine.
- [x] Display release notes and links in the Applications tab.

#### PowerShell Gallery

- [x] Implement module and script search.
- [x] Implement installed-item inventory and version comparison.
- [x] Implement install, update, and removal.
- [x] Implement export and restore support.
- [x] Add PowerShell Gallery actions and results to the Applications tab.

#### NuGet

- [x] Support configured NuGet feeds.
- [x] Implement package search and version resolution.
- [x] Implement download, install, update, and removal where applicable.
- [x] Implement export and restore support.
- [x] Add NuGet source and result information to the Applications tab.

#### DISM

- [x] Detect applicable online Windows capabilities, features, and packages.
- [x] Implement supported enable, install, disable, and removal operations.
- [x] Report restart requirements and DISM result codes.
- [x] Add capability-aware DISM actions to the Applications tab.
- [x] Keep offline Windows-image servicing outside the v0.2.0 scope.

#### WSUS

- [x] Detect configured Windows Update and WSUS policy.
- [x] Discover applicable updates from the managed update source.
- [x] Implement download and installation through the managed source.
- [x] Report approval, applicability, failure, and reboot status.
- [x] Display WSUS source and operation details in the Control Center.

#### Phoenix orchestration provider

- [x] Coordinate provider selection and fallback.
- [x] Apply eligibility, elevation, and safety policies consistently.
- [x] Expose provider alternatives during restore planning.
- [x] Return one normalized result model to the CLI and Control Center.

### 5. OEM driver support

- [x] Define a common OEM driver-adapter contract.
- [x] Detect manufacturer and applicable hardware before enabling an adapter.
- [x] Add Dell integration.
- [x] Add HP integration.
- [x] Add Lenovo integration.
- [x] Add Intel integration.
- [x] Add AMD integration.
- [x] Add NVIDIA integration.
- [x] Require approval before installing an OEM utility.
- [x] Use Windows Update when no applicable OEM source is available.
- [x] Show installed and available driver versions.
- [x] Show driver source, release information, support links, and restart
      requirements.
- [x] Route every OEM scan and operation through the background job system.
- [x] Verify OEM information and actions in the Drivers and Activity tabs.
- [ ] Add mocked adapter tests and real Windows VM validation.

### 6. Restore planning

- [x] Build a restore plan before making system changes.
- [x] Classify every driver and application action.
- [x] Show installed, requested, and available versions.
- [x] Show the selected provider and provider alternatives.
- [x] Show privilege, dependency, safety, and restart information.
- [x] Allow individual and grouped selection.
- [x] Allow filtering by provider, record type, and planned action.
- [x] Allow eligible application records to change providers.
- [x] Save and reload restore plans.
- [x] Support `-WhatIf`, interactive, and unattended execution.
- [x] Add a Restore Plan view to the Control Center.

### 7. Restore checkpoints and resume

- [x] Define a versioned checkpoint schema.
- [x] Assign restore-session and operation identifiers.
- [x] Save progress after every meaningful restore action.
- [x] Record completed, pending, skipped, failed, and retryable records.
- [x] Record manifest identity, computer identity, timestamps, and reboot state.
- [x] Resume without repeating successful work.
- [x] Detect incompatible or stale checkpoints safely.
- [x] Display checkpoint and resume status in the Control Center.
- [x] Add interruption, failure, retry, and resume regression tests.

### 8. Restore verification

- [x] Rescan applications and drivers after restoration.
- [x] Classify records as verified, version mismatch, already satisfied,
      skipped, restart pending, missing, failed, no longer applicable, or
      unable to verify.
- [x] Show verification results in the Control Center.
- [x] Return structured verification results to PowerShell.
- [x] Include provider, version, and failure details.
- [x] Add complete, partial, failed, and restart-pending verification tests.

### 9. Control Center integration

- [ ] Add provider columns and filters to the Applications tab.
- [ ] Allow searches against one provider or all providers.
- [ ] Show installed and available application versions.
- [ ] Show update availability, metadata, release notes, and support links.
- [ ] Show provider alternatives and capability-aware action buttons.
- [ ] Show provider and OEM sources in the Drivers tab.
- [ ] Show installed and available driver versions.
- [ ] Show planned action and verification status.
- [ ] Connect application, driver, provider, activity, checkpoint, and
      verification data to live background jobs.
- [ ] Test every statically referenced control and data binding.
- [ ] Perform manual end-to-end testing in Windows virtual machines.

### 10. Build, testing, and release gate

- [ ] Keep `Build.ps1` as the required validation gate.
- [ ] Add unit tests for every completed provider.
- [ ] Add mocked provider and OEM integration tests.
- [ ] Add background-job cancellation, timeout, and retry tests.
- [x] Add restore planning, checkpoint, resume, and verification tests.
- [ ] Add Control Center lifecycle and binding tests.
- [ ] Complete administrator and standard-user VM testing.
- [ ] Update user, troubleshooting, provider, and developer documentation.
- [ ] Create the complete Phoenix v0.2.0 development-history document.
- [ ] Produce and independently verify the v0.2.0 release archive.

## Definition of done for v0.2.0

- [ ] The Control Center remains responsive during every long-running action.
- [ ] Every included provider reports availability and capabilities accurately.
- [ ] Every supported provider action is available and tested through the UI.
- [ ] Unsupported provider actions are visibly disabled.
- [ ] OEM driver information and operations appear in the Drivers and Activity
      tabs.
- [ ] Restore plans can be reviewed before execution.
- [ ] Interrupted restores can resume from checkpoints.
- [x] Completed restores produce verification results.
- [ ] Automated tests pass with zero failures.
- [ ] PSScriptAnalyzer reports zero blocking findings.
- [ ] Installation, upgrade, launch, and complete removal pass Windows VM
      testing.
- [ ] The repository, release archive, checksum, tag, and GitHub release are
      verified.

## Planned after v0.2.0

The following remain part of Phoenix's longer-term direction but are not
required for v0.2.0:

- [ ] Offline application and driver recovery bundles
- [ ] Bootable Phoenix USB creation
- [ ] WinPE integration
- [ ] Windows image deployment
- [ ] Unattended Windows installation
- [ ] Pre-OS driver injection
- [ ] Disk partitioning and formatting
- [ ] Windows answer-file generation
- [ ] Full bare-metal new-PC deployment
