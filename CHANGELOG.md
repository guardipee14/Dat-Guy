# Changelog

All notable changes to Phoenix are documented in this file.

## [Unreleased]

## [0.1.16] - 2026-08-01

### Added
- native Windows Installer package support
  - Inventory installed MSI products and product codes from both native and
    32-bit registry views without invoking `Win32_Product`.
  - Install local MSI packages silently or interactively and repair or remove
    installed product-code records.
  - Normalize Windows Installer success, failure, exit-code, and restart
    results through the common provider contract.
  - Register MSI capabilities, health, inventory, and capability-aware actions
    in the Control Center.
  - Add MSI provider and UI-routing tests.

## [0.1.15] - 2026-08-01

### Added
- Scoop provider integration
  - Detect Scoop without requiring administrator privileges.
  - Implement JSON-backed installed inventory, search, install, update, and
    removal with normalized Phoenix results.
  - Export Scoop state and restore typed package selections.
  - Require explicit user installation of Scoop instead of silently running a
    remote bootstrap script.
  - Register Scoop in provider initialization, application search, inventory,
    restore eligibility, health, and capability-aware UI actions.
  - Add Scoop contract and integration tests.

## [0.1.14] - 2026-08-01

### Added
- complete Chocolatey application behavior
  - Decorate install, update, repair, and removal results with the common
    provider, operation, target, exit-code, and reboot contract.
  - Treat Chocolatey restart exit codes as successful restart-required
    operations across silent and interactive paths.
  - De-duplicate Chocolatey search and installed-package records.
  - Reject failed provider metadata commands with structured lookup details.
  - Add Chocolatey contract, action-path, and Control Center tests.

## [0.1.13] - 2026-08-01

### Added
- complete WinGet application behavior
  - Add the missing interactive installation implementation.
  - De-duplicate search and installed-package correlation keys.
  - Preserve provider, operation, target, exit-code, and restart metadata on
    shared Phoenix results for install, update, repair, and removal.
  - Treat successful WinGet restart exit codes as successful operations that
    require a restart.
  - Add WinGet capability, normalized-result, method, and UI-path tests.

## [0.1.12] - 2026-08-01

### Added
- a common provider capability, availability, and result contract
  - Describe search, inventory, install, update, repair, remove, export, and
    restore support through `PhoenixProviderCapability`.
  - Normalize provider data and `Result` envelopes through
    `PhoenixProviderResult`, including privilege, restart, timeout,
    cancellation, exit-code, warnings, errors, and stable Phoenix codes.
  - Publish capability snapshots from the provider base class for both
    currently registered providers.
  - Show provider availability, operations, privilege, and health in the
    Control Center provider grid.
  - Disable application update, repair, remove, search, and install actions
    when the selected provider or result does not support them.
  - Add simulated availability and result coverage for WinGet, Chocolatey,
    and every common provider operation.

## [0.1.11] - 2026-08-01

### Added
- control and inspect jobs from the Activity Center
  - Cancel the active worker through the shared cancellation path or remove a
    selected queued application operation without disturbing FIFO order.
  - Retry terminal operations from their preserved action, parameters,
    description, and completion callback.
  - Clear terminal Activity records while preserving queued and running work.
  - Show bounded structured details for result data, Phoenix result codes,
    warnings, errors, progress, timing, provider, and target.
  - Normalize restart flags from `RequiresRestart`, `RebootRequired`, and
    `RestartRequired` result fields.
  - Preserve grid selection during live polling and enable controls according
    to the selected operation lifecycle.
  - Add Activity control, result-normalization, and UI regression coverage.

## [0.1.10] - 2026-08-01

### Added
- display live Control Center jobs in the Activity Center
  - Add a typed `PhoenixActivityRecord` model for lifecycle, target, provider,
    progress, start time, elapsed time, and retained result data.
  - Show queued, running, completed, cancelled, and failed operations in a
    live Activity grid while retaining the timestamped event log.
  - Derive useful targets and providers for inventory, search, package,
    driver, release-metadata, update, and restore actions.
  - Refresh running elapsed time and progress from the existing dispatcher
    polling loop without blocking the WPF interface thread.
  - Preserve operation history while navigating among Control Center pages.
  - Add Activity model lifecycle tests and UI binding regression guards.

## [0.1.9] - 2026-08-01

### Added
- run restore work through the shared cancellable background-job lifecycle
  - Add `Start-PhoenixRestoreJob`, `Receive-PhoenixJob`, and
    `Stop-PhoenixJob` public commands.
  - Route restore requests through an isolated `RestoreAction` worker with
    atomic request, progress, and result files.
  - Preserve provider filters, driver and package selection, reinstall,
    stop-on-error, and unattended restore options across the worker boundary.
  - Cancel the worker process tree and remove temporary operation files
    deterministically.
  - Add safe fake-worker tests for completion, cancellation, cleanup, and
    invalid workload selection without changing packages or drivers.

## [0.1.8] - 2026-08-01

### Added
- queue Control Center application operations in the background
  - Add a queued state to the shared background-operation lifecycle.
  - Schedule application install, update, repair, and removal operations in
    first-in, first-out order when another operation is active.
  - Continue the queue after successful, failed, or cancelled workers.
  - Report queue position and queued-operation startup in the activity log.
  - Suppress intermediate result dialogs and refresh application inventory
    after the queue drains.
  - Cancel and clean up pending operations when the Control Center closes.
  - Keep driver and restore serialization reserved for their later roadmap
    milestones.
  - Add lifecycle, worker, and Control Center queue regression coverage.

## [0.1.7] - 2026-08-01

### Changed
- keep fresh Control Center startup responsive during provider initialization
  - Defer missing-provider availability and installation checks when the
    desktop creates its initial Phoenix context.
  - Run provider bootstrap inside the existing isolated inventory worker
    before inventory collection begins.
  - Synchronize worker-reported provider availability back into the desktop
    context after inventory completes.
  - Preserve synchronous provider bootstrap for console and command-line
    startup.
  - Add lifecycle and Control Center regression coverage for the deferred
    desktop path.

## [0.1.6] - 2026-07-31

### Added
- add a shared Phoenix background-operation lifecycle contract
  - Define created, starting, running, cancellation-requested, cancelled,
    completed, and failed lifecycle states.
  - Track operation identity, component, action, parameters, timestamps,
    progress, worker state, cancellation, results, and errors.
  - Add reusable functions to create, start, receive, stop, and remove
    background operations.

### Changed
- move Control Center process operations onto the shared lifecycle
  - Run operations through isolated child PowerShell processes.
  - Exchange atomic request, progress, and result JSON files.
  - Use module-bound adapters when WPF callbacks invoke private Phoenix
    lifecycle functions.
  - Detect workers that exit without publishing a result.
  - Centralize cancellation and deterministic process and temporary-file
    cleanup.
  - Add focused lifecycle unit and Control Center regression coverage.

## [0.1.5] - 2026-07-31

### Changed
- use portable release separators
  - Replace Unicode roadmap separators with plain ASCII hyphens.
  - Prevent roadmap milestone text from becoming corrupted in Windows terminals.
  - Synchronize the repository roadmap and GitHub roadmap issue.


### Fixed
- isolate Control Center exceptions and recover the desktop
  - Catch unhandled WPF dispatcher exceptions before they terminate the
    Control Center window.
  - Normalize component and startup exceptions into structured Phoenix
    failure results with stable result codes.
  - Display retry, diagnostic details, and dismissal controls in a persistent
    in-app recovery surface.
  - Offer retry, safe-layout reset, console, and close actions when the main
    desktop cannot finish starting.
  - Record the latest failure and retain the newest 20 Control Center
    diagnostics under `Cache\ControlCenter`.
  - Preserve Control Center recovery data across upgrades.
  - Add focused recovery unit tests and Control Center regression coverage.

## [0.1.4] - 2026-07-30

### Fixed
- recover required Phoenix runtime state automatically
  - Create configuration, theme, cache, checkpoint, driver, log, and working
    directories before constructing a Phoenix context.
  - Recreate missing configuration files from safe defaults.
  - Back up malformed or incomplete configuration before repairing it.
  - Merge missing defaults without discarding custom settings or theme tiles.
  - Preserve one-item dashboard tile arrays while restoring missing default
    tiles.
  - Normalize unsafe logging, concurrency, UI color, and path settings.
  - Record the last successful recovery in a persistent runtime journal.
  - Preserve recovery history, checkpoints, logs, and installed themes during
    upgrades.
  - Display recovery status, repaired-item counts, and the last repair time in
    the Control Center.
  - Add focused recovery, configuration, lifecycle, UI, and release tests.

## [0.1.3] - 2026-07-30

### Fixed
- make Phoenix context initialization reliable and recoverable
  - Initialize module-scoped context state safely under StrictMode.
  - Build configuration, providers, and logging before publishing a context.
  - Restore the previous ready context when forced initialization fails.
  - Reuse one ready session during repeated starts and refreshes.
  - Add `Start-Phoenix -Force` for an explicit new context generation.
  - Record ready, failed, resumed, generation, and initialization metadata.
  - Route context consumers through one recovery helper.
  - Display lifecycle state, generation, and session information in the
    Control Center inventory tile.
  - Add focused lifecycle and Control Center regression coverage.

## [0.1.2] - 2026-07-30

### Changed
- publish the Phoenix v0.2.0 roadmap
  - Add a public checkbox-based roadmap for Phoenix v0.2.0.
  - Track runtime stability, background jobs, and Activity Center work.
  - Track completion and UI integration for every planned provider.
  - Track OEM driver support for Dell, HP, Lenovo, Intel, AMD, and NVIDIA.
  - Track restore planning, checkpoints, resume, and verification.
  - Define the automated testing and Windows VM release requirements.
  - Preserve the roadmap link through generated README updates.
- establish a 33-release Phoenix v0.2.0 development train
  - Publish 32 independently validated v0.1.x milestone releases.
  - Complete the development cycle with Phoenix v0.2.0.
  - Require backend, Control Center, test, documentation, checksum, tag, and
    GitHub release verification for every milestone.
  - Include the public roadmap in Phoenix release archives.

## [0.1.1] - 2026-07-30

### Fixed
- add a double-clickable Windows installer launcher
  - Launch the existing PowerShell installer through PowerShell 7.
  - Require PowerShell 7.4 or later and show an actionable requirement message.
  - Use a process-only execution-policy override without changing permanent policy.
  - Keep the installer window open so success or failure remains visible.
  - Include the launcher in every runtime release archive.
  - Add regression coverage for launcher requirements and release packaging.
  - Verify Explorer double-click installation, module version, Apps registration, shortcuts, and complete cleanup.

## [0.1.0] - 2026-07-30

### Release
- Publish the first Phoenix release baseline.
  - Package only runtime files in a versioned ZIP archive.
  - Generate archive and per-file SHA-256 integrity metadata.
  - Support CurrentUser and AllUsers installation, upgrades, shortcuts, and Windows installed-app registration.
  - Preserve configuration and installed themes during upgrades and by-default uninstallation.
  - Add optional GitHub release publication.
  - Add the complete v0.1.0 development-history document to the release.
  - License Phoenix under MIT OR Apache-2.0 OR GPL-3.0-or-later.
  - Verify checksum, clean installation, upgrade preservation, default uninstall preservation, recovery reinstall, and complete removal.

### Fixed
- filter and retain session logs
  - Create log files lazily only when a message passes the configured level.
  - Support Debug, Verbose, Info, Success, Warning, and Error filtering.
  - Keep only the newest 20 timestamped Phoenix session logs by default.
  - Preserve unrelated and non-session files in the log directory.
  - Remove the duplicate Phoenix startup entry.
  - Add Pester regression coverage for filtering, reuse, retention, ownership, and startup logging.
- require a supported Pester version
  - Require Pester 6.0.0 or later instead of accepting the built-in Pester 3.4.0.
  - Select the highest installed module version that satisfies each requirement.
  - Use one canonical developer-tools task with a compatibility loader.
  - Support WhatIf and forced installation or updates.
  - Verify installed modules and return version and status details.
- separate inventory from restorable packages
  - Preserve the complete detected software inventory under Inventory.Software.
  - Emit only restorable WinGet and Chocolatey records under Packages.
  - Use one shared eligibility rule for backup and restore.
  - Correct installed-package key formatting during elevated restore.
- description of the change
- make README generation idempotent
  - Prevent trailing blank lines from accumulating.
  - Avoid rewriting README.md when generated content is unchanged.
  - Report whether README documentation actually changed.

### Changed
- integrate PSScriptAnalyzer validation
  - Run PSScriptAnalyzer automatically during normal Phoenix builds.
  - Require PSScriptAnalyzer 1.25.0 or later.
  - Block analyzer errors and security-rule findings while reporting existing warnings.
  - Support strict analysis and an explicit analysis skip switch.
  - Write complete JSON findings and include analysis metadata in build results.
- automate validation and regression tests
  - Delegate class generation to the validated composite-class builder.
  - Validate Phoenix module imports in an isolated PowerShell process.
  - Run Pester regression tests automatically during normal builds.
  - Support optional coverage, skipped tests, retained generated files, and configurable test output.
  - Report build results with test, coverage, Git, and duration metadata.
- add Pester regression coverage
  - Add a Pester 6 runner with NUnit test reports and optional Cobertura coverage.
  - Test restore-package eligibility for WinGet, Chocolatey, ARP, MSIX, and unsupported providers.
  - Guard manifest inventory separation, installed-package key formatting, and WinGet already-installed handling.
  - Enforce a 90 percent focused coverage baseline.
- automate Phoenix capability and repository documentation
  - Generate the README capability and command sections.
  - Document current Phoenix limitations.
  - Refresh repository documentation during commits.

### Added
- add customizable desktop management interface
  - Add automatic, desktop, and console launch modes with responsive background operations.
  - Add application search, update metadata, install, repair, and protected uninstall workflows.
  - Add driver update metadata, selected installation, repair, and constrained non-forced uninstall workflows.
  - Add persistent theme presets, graphical color controls, movable and resizable dashboard tiles, and Theme Studio.
  - Add declarative size-limited theme packages and comprehensive Control Center regression coverage.
  - Prevent UI freezes by using atomic worker results and correctly scoped asynchronous callbacks.
- restore drivers and packages from a Phoenix manifest
  - Create a versioned and restorable backup manifest.
  - Restore Windows Update drivers before packages.
  - Reinstall missing WinGet and Chocolatey packages.
  - Add preview, provider filtering, progress, and structured restore summaries.
- install applicable drivers through Windows Update
  - Search Windows Update for applicable driver updates.
  - Support scan-only and unattended driver workflows.
  - Download and install drivers before package updates.
  - Return structured driver, reboot, and failure results.
  - Refresh installed-driver inventory after each search.
- Automate README capability documentation and GitHub repository description updates during commits.
  - Generate the exported-command table and current capability list from the Phoenix project.
  - Preserve content outside the managed README section.
  - Refresh the GitHub description through GitHub CLI after successful pushes.
- add Phoenix deployment module and elevated update workflow
  - Add WinGet and Chocolatey package management.
  - Add elevated install, remove, repair, and update operations.
  - Run driver scanning before package updates.
  - Return elevated driver and package results to the original window.
  - Display separate driver and package completion summaries.
- Add controlled installer-technology migration handling for package updates.
  - Prompt before uninstalling and reinstalling eligible packages.
  - Skip unapproved migrations safely in unattended mode.
  - Protect Microsoft Edge and other system-managed packages unless explicitly forced.
  - Report migrated, protected, skipped, and failed migrations separately.

