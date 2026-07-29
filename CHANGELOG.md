# Changelog

All notable changes to Phoenix are documented in this file.

## [Unreleased]

### Added
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

