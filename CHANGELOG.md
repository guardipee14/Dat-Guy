# Changelog

All notable changes to Phoenix are documented in this file.

## [Unreleased]

### Fixed
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

