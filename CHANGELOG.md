# Changelog

All notable changes to Phoenix are documented in this file.

## [Unreleased]

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

