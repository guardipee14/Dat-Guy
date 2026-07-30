# Phoenix v0.1.0 Development History

**Project:** PhoenixDeploy / Phoenix

**Release:** v0.1.0

**Release date:** July 30, 2026

**Author:** Donaven Guardipee

**Repository:** https://github.com/guardipee14/Dat-Guy

**License:** `MIT OR Apache-2.0 OR GPL-3.0-or-later`

## Purpose of this document

This document preserves the development history, design decisions, completed
work, major fixes, verification milestones, and release contract that brought
Phoenix from its original concept to the v0.1.0 release.

It is the historical baseline for v0.1.0. Work completed after this release
will be recorded separately for v0.2.0 so that each release has a permanent,
version-specific development record.

## 1. Original vision

Phoenix began as a Windows deployment and recovery project intended to make it
easier to prepare, repair, update, back up, and restore Windows computers.

The original goals were to:

- collect a list of installed applications and drivers;
- reinstall applications from that list;
- support common Windows installer and package-management technologies;
- use WinGet, Chocolatey, and other providers where practical;
- choose an appropriate provider for a package;
- install or update drivers before applications;
- support both interactive and unattended operation;
- request elevation only when privileged work is required;
- continue or resume work around reboot requirements;
- cache packages where supported;
- provide update and repair workflows in addition to installation;
- provide a dry-run mode before making changes;
- record timestamps, results, exit codes, and failures;
- support both command-line automation and an approachable graphical
  interface;
- remain usable on lower-specification Windows computers.

Not every part of the long-term vision is complete in v0.1.0. The first
release establishes the architecture and delivers a usable Windows application,
driver, inventory, backup, restore, logging, testing, and Control Center
foundation.

## 2. Core design principles

The following principles guided v0.1.0:

1. **Drivers first.** Driver discovery and applicable Windows Update driver
   installation run before package updates and manifest package restoration.
2. **Structured results.** Public operations return `Result` objects with
   success state, codes, messages, data, and errors instead of depending only
   on console text.
3. **Safe elevation.** Phoenix requests administrative rights for privileged
   work and returns elevated results to the original PowerShell session.
4. **Preview before change.** State-changing workflows use `ShouldProcess`,
   `-WhatIf`, confirmations, or explicit unattended policy.
5. **Provider consistency.** WinGet and Chocolatey operations are exposed
   through a common Phoenix command layer.
6. **Inventory is not the same as restore intent.** Phoenix preserves a
   complete detected software inventory while placing only eligible,
   restorable package records in the manifest package list.
7. **Generated code must be reproducible.** Composite provider classes and the
   Phoenix class module are assembled and validated by the build system.
8. **The graphical interface must remain responsive.** Long-running inventory,
   installation, update, repair, removal, and metadata operations run outside
   the WPF interface thread.
9. **User configuration survives upgrades.** Release installation preserves
   configuration and installed themes by default.
10. **Release artifacts are verifiable.** Phoenix release archives include
    checksums and per-file integrity metadata.

## 3. Project and module foundation

Phoenix was established as a PowerShell module rooted at:

```text
C:\Dev\PhoenixDeploy
```

The primary module files are:

- `Phoenix.psd1` — module manifest and exported-command metadata;
- `Phoenix.psm1` — module loader;
- `Classes\Phoenix.Classes.psm1` — generated composite class module.

The initial public workflow centered on:

- `Start-Phoenix`
- `Backup-Phoenix`
- `Restore-Phoenix`
- `Update-Phoenix`

The public surface later expanded to include:

- provider and package discovery;
- package installation, removal, repair, and update;
- the Control Center launcher;
- theme discovery, installation, and export.

Early module work resolved several foundational problems:

- missing or incorrectly exported public functions;
- class types loading after functions that depended on them;
- unresolved `Package`, `PhoenixProvider`, and context types;
- missing initialization and logging functions;
- incomplete module braces and syntax errors;
- a missing or uninitialized script-scoped Phoenix context;
- inconsistent private-function loading.

The final loader order ensures that generated classes are available before the
private and public functions that use them.

## 4. Class and provider architecture

Phoenix uses source class fragments that are composed into a validated class
module. The architecture includes:

- base result, package, and driver models;
- Phoenix build, configuration, context, and logger classes;
- package and inventory models;
- provider base behavior;
- WinGet and Chocolatey provider implementations;
- generated provider snapshots.

`Build\Build-PhoenixClasses.ps1` became the canonical class builder. It:

- assembles composite providers;
- generates provider snapshots;
- writes `Classes\Phoenix.Classes.psm1`;
- validates the assembled class module;
- prevents generated output from drifting away from its source methods.

This replaced fragile manual class concatenation and made class generation part
of every normal build.

## 5. Package management

Phoenix v0.1.0 detects and initializes:

- WinGet
- Chocolatey

The package command layer supports:

- installed-package enumeration;
- package search for new applications;
- installation;
- removal;
- repair where supported;
- individual updates;
- bulk updates;
- silent and interactive install behavior;
- elevation for privileged operations;
- structured success and failure reporting.

### Installer migration safeguards

Phoenix detects cases where an application update would cross installer
technologies or package identities. It can:

- request interactive approval before uninstalling and reinstalling;
- skip an unapproved migration safely;
- apply explicit unattended migration policy;
- protect Microsoft Edge and other system-managed packages unless protected
  migration is explicitly forced;
- classify migrated, protected, skipped, and failed results separately.

### Already-installed handling

Restore and package operations were corrected so that:

- provider output is correlated using one correctly formatted package key;
- WinGet's already-installed exit behavior is normalized as success;
- existing packages do not cause false restore failures;
- uncorrelated inventory-only records do not become restore actions.

## 6. Driver-first update engine

Phoenix implements driver discovery and installation through the Windows Update
Agent interfaces available on supported Windows versions.

The v0.1.0 driver workflow can:

- scan Windows for hardware changes;
- query applicable Windows Update driver updates;
- return scan-only results;
- select updates by update identity;
- download applicable drivers;
- install selected or all applicable drivers;
- report search, download, installation, partial, skipped, and failure counts;
- report reboot requirements;
- refresh installed-driver inventory after a search or installation;
- run before package updates.

The Control Center additionally exposes:

- selected driver installation;
- update-all behavior;
- repair for problem devices;
- constrained, non-forced driver removal;
- driver descriptions, release notes, and support links when available.

Phoenix does not yet integrate OEM-specific update tools, vendor catalogs, or
offline driver packs. Those remain candidates for later releases.

## 7. Inventory

Phoenix collects the information needed to understand and recover a Windows
computer, including:

- computer manufacturer and model;
- processor;
- physical memory;
- Windows edition, version, build, and architecture;
- hardware inventory;
- network inventory;
- installed software;
- installed and problem drivers;
- active Phoenix providers and provider capabilities;
- PowerShell and Phoenix version information.

The inventory implementation was corrected to fall back to total physical
memory when individual memory-module rows are unavailable. This prevented the
Control Center from failing or displaying an incorrect zero-memory result in
some virtual machines.

## 8. Backup manifest

`Backup-Phoenix` creates a JSON restore manifest using:

```text
Schema: PhoenixRestoreManifest
SchemaVersion: 2.0
```

The manifest records:

- a unique manifest identifier;
- UTC creation time;
- computer and user metadata;
- Phoenix and PowerShell versions;
- operating-system information;
- hardware, network, software, and PowerShell inventory;
- drivers;
- eligible packages;
- provider capabilities;
- options describing which inventory sections were included.

Backup supports:

- relative or absolute output paths;
- automatic parent-directory creation;
- `ShouldProcess` and `-WhatIf`;
- skipping drivers;
- skipping packages;
- structured completion, skipped, initialization-failure, and backup-failure
  results.

### Inventory and restorable package separation

An important v0.1.0 correction separated:

- the complete detected software list under `Inventory.Software`; and
- only supported restore candidates under `Packages`.

The shared eligibility rule:

- accepts WinGet community-source packages;
- accepts Chocolatey packages;
- matches provider and source names without case sensitivity;
- rejects WinGet ARP inventory records;
- rejects WinGet MSIX inventory records;
- rejects WinGet records from unsupported sources;
- rejects unsupported providers;
- rejects records without an identifier.

This reduced a detected 71-application inventory to the 17 applications that
were actually restorable on the test system, without losing the complete
inventory record.

## 9. Restore workflow

`Restore-Phoenix` grew from an initial placeholder into a working manifest
restore engine.

The v0.1.0 implementation:

- reads and validates a Phoenix restore manifest;
- supports preview with `-WhatIf`;
- restores applicable Windows Update drivers before packages;
- supports skipping drivers or packages;
- filters package work by provider;
- supports unattended execution;
- can stop on the first failure;
- reinstalls missing WinGet and Chocolatey packages;
- classifies already-installed packages as successful;
- reports manifest and selected counts;
- emits structured package results and restore summaries.

Validation milestones included:

- a schema 2.0 backup with 71 detected applications, 17 restorable packages,
  55 drivers, and two providers;
- a restore preview that made no changes;
- a 71-record restore test with 71 successful results before inventory and
  restore eligibility were separated;
- a post-separation restore with 17
  `PHX_RESTORE_ALREADY_INSTALLED` results and zero failures.

Restore intentionally installs the provider-current package version. It does
not yet pin every package to the exact historical version recorded in the
manifest.

## 10. Logging

Phoenix logging was redesigned to keep operational history useful without
creating excessive files.

The logger now:

- supports Debug, Verbose, Info, Success, Warning, and Error levels;
- creates a log file lazily only after a message passes the configured level;
- reuses one timestamped log file for a Phoenix session;
- avoids duplicating the startup entry;
- recognizes Phoenix-owned session-log filenames;
- preserves unrelated files in the log directory;
- retains only the newest 20 Phoenix session logs by default;
- removes older Phoenix-owned session logs automatically.

A runtime verification confirmed:

- 20 Phoenix log files retained;
- one unrelated file preserved;
- one startup line in the newest log.

## 11. Documentation and Git workflow

Phoenix gained automated repository documentation and change management.

`Tools\Update-PhoenixReadme.ps1`:

- discovers exported commands;
- documents current capabilities and limitations;
- generates the managed README section;
- preserves content outside the generated section;
- avoids repeated trailing blank lines;
- avoids rewriting `README.md` when content is unchanged.

`Tools\Save-PhoenixChange.ps1`:

- updates the changelog;
- refreshes generated README content;
- validates standalone PowerShell files;
- validates the module import;
- stages the intended changes;
- creates a conventional commit;
- optionally pushes it;
- updates the GitHub repository description after a successful push.

This workflow made validation, documentation, commit messages, pushes, and the
repository description part of the same repeatable operation.

## 12. Developer tools

Phoenix standardizes its developer dependencies:

- PSScriptAnalyzer 1.25.0 or later;
- Pester 6.0.0 or later;
- platyPS.

The developer-tools task:

- selects the highest installed version that meets each requirement;
- does not accept the built-in Pester 3.4.0 as sufficient;
- supports `-WhatIf`;
- supports forced installation or updates;
- verifies installed tools;
- returns module version and availability details;
- uses one canonical implementation with a compatibility loader.

## 13. Pester regression testing

Pester 6 regression coverage was added to protect the behaviors that had caused
real failures during development.

The test runner:

- discovers the Phoenix test files;
- writes NUnit test reports;
- optionally writes Cobertura coverage;
- returns structured test results;
- throws when a regression fails;
- reports passed, failed, and skipped counts.

Focused coverage was established at 100 percent for the initial restore
eligibility helpers, with a 90 percent minimum baseline to prevent regression.

By the v0.1.0 release checkpoint, Phoenix had:

```text
48 tests passed
0 tests failed
0 tests skipped
```

The regression suite covers:

- restore-related PowerShell syntax;
- manifest inventory separation;
- restore eligibility;
- installed-package key formatting;
- WinGet already-installed normalization;
- logger filtering and retention;
- Control Center loading, layout, controls, and operations;
- asynchronous UI worker behavior;
- application and driver uninstall protections;
- themes and Theme Studio;
- release packaging;
- tri-license metadata;
- installer upgrade preservation;
- release integrity;
- uninstallation and user-data preservation.

## 14. PSScriptAnalyzer integration

Static analysis became part of the normal build.

The analysis runner:

- requires PSScriptAnalyzer 1.25.0 or later;
- analyzes the Phoenix PowerShell source set;
- excludes generated migration backups;
- blocks analyzer errors and selected security-rule findings;
- reports existing warnings without blocking a normal build;
- supports strict mode;
- supports an explicit analysis skip;
- writes full JSON findings;
- includes analysis counts in the build result.

At the v0.1.0 release checkpoint:

```text
95 files analyzed
322 findings
0 errors
0 blocking findings
```

The remaining findings are non-blocking technical-debt warnings, dominated by
legacy `Write-Host` usage.

## 15. Automated build pipeline

The original build script was replaced with a complete validation pipeline.

`Build.ps1` now:

1. identifies the project root;
2. builds the composite Phoenix class module;
3. validates module import in an isolated PowerShell process;
4. runs PSScriptAnalyzer;
5. runs the Pester regression suite;
6. optionally collects code coverage;
7. reports Git branch and commit metadata;
8. returns a structured build result with duration and validation counts.

The v0.1.0 release checkpoint completed successfully with:

- class generation successful;
- module import validation successful;
- static analysis successful;
- 48 of 48 tests passing;
- zero blocking analyzer findings.

## 16. Phoenix Control Center

Phoenix v0.1.0 added a launchable management interface with automatic, desktop,
and console modes.

Entry points include:

- `Phoenix.cmd`
- `Phoenix-Desktop.cmd`
- `Phoenix-Console.cmd`
- `Open-Phoenix`

Automatic mode can attempt the desktop interface and fall back to the console
interface when desktop mode is unavailable.

### Overview

The Overview area displays:

- system identity and operating-system information;
- processor and memory information;
- inventory counts;
- provider capabilities;
- warnings and activity status.

### Applications

The Applications area supports:

- installed-application inventory;
- provider and installed-version display;
- detection and display of an available update version;
- release and publisher metadata when a provider exposes it;
- package release details and links when available;
- application search;
- installation of a searched application;
- selected install, update, repair, and uninstall actions;
- install-all, update-all, and repair-all workflows where supported;
- confirmation before uninstallation.

Provider metadata is not guaranteed to contain full release notes. When the
provider does not expose them, Phoenix reports that release details are not
available instead of inventing them.

### Drivers

The Drivers area supports:

- installed and problem-driver inventory;
- available Windows Update driver metadata;
- selected installation;
- update-all behavior;
- repair of problem devices;
- constrained selected-driver removal;
- descriptions, release notes, and support links when available.

Driver removal is intentionally non-forced and constrained because removing the
wrong active driver can make hardware or Windows unusable.

### Activity and responsiveness

Long-running work originally caused WPF to stop responding. The final v0.1.0
implementation moved those operations to background workers and corrected:

- dispatcher calls from timer callbacks;
- process-state polling;
- worker result transfer;
- callback invocation as script blocks;
- dependency scope captured by asynchronous operations;
- invalid invocation through the PowerShell call operator;
- missing control registrations;
- missing runtime state properties;
- desktop fallback diagnostics.

The Activity area remains available while background work runs, allowing the
user to observe progress instead of waiting on a frozen window.

## 17. Modern and customizable interface

The first Control Center layout was functional but visually resembled older
Windows interfaces. It was redesigned with a Windows 10/11-era appearance and
persistent customization.

The v0.1.0 interface includes:

- built-in theme presets;
- graphical color controls and live color previews;
- user-configurable colors and shades;
- font customization;
- movable dashboard tiles;
- resizable dashboard tiles;
- saved tile layout and appearance settings;
- a Theme Studio utility;
- lightweight declarative theme packages;
- theme import, discovery, installation, and export;
- size limits for installed theme packages;
- support for theme assets such as permitted images and fonts.

Built-in themes include:

- Phoenix Dark;
- Phoenix Light;
- Windows 11;
- High Contrast.

Theme packages remain declarative and size-limited so customization does not
turn the Control Center into a heavy application that excludes lower-spec
computers.

## 18. Major Control Center problems resolved

The following real failures were diagnosed and corrected during v0.1.0:

| Problem | Resolution |
|---|---|
| Inventory failed because a `Sum` property was unavailable | Added a total-physical-memory fallback |
| Theme preview could not find `ConvertTo-PhoenixUiBrush` | Made color conversion available independently of fragile module scope |
| Desktop launch failed with an invalid `&` pipeline expression | Passed valid script blocks and commands through the asynchronous invocation path |
| The desktop interface froze during application installation | Moved long operations off the WPF UI thread |
| Timer callbacks could deadlock or synchronously invoke the dispatcher | Switched to safe asynchronous UI updates |
| Worker polling lost or delayed operation results | Used an atomic worker-result contract |
| Callback and dependency variables disappeared across scopes | Pinned required callbacks and dependencies into the invocation scope |
| A referenced uninstall button did not exist | Registered and validated every statically referenced desktop control |
| Missing runtime properties stopped desktop startup | Initialized and guarded desktop operation state |
| Application uninstall was absent | Added selected application uninstall with confirmation |
| Driver uninstall was absent | Added constrained, non-forced selected-driver removal |
| Provider metadata lacked release notes | Displayed available metadata and an explicit not-available state |

## 19. Release packaging and installation

Phoenix v0.1.0 adds a runtime-only release pipeline.

`Build\New-PhoenixRelease.ps1`:

- accepts a semantic version;
- normally requires a clean Git working tree;
- can allow dirty builds explicitly for local testing;
- runs the normal Phoenix validation pipeline unless explicitly skipped;
- stages only runtime files;
- writes the release version into the staged module;
- validates the packaged module;
- writes `RELEASE.json`;
- records a SHA-256 hash for every packaged file;
- creates a versioned ZIP archive;
- creates a ZIP SHA-256 checksum file;
- can optionally create a GitHub release through GitHub CLI;
- supports prerelease publication.

The installer supports:

- CurrentUser scope;
- AllUsers scope;
- the default per-user location
  `%LOCALAPPDATA%\Programs\Phoenix`;
- optional custom installation paths;
- Desktop and Start Menu shortcuts;
- Windows installed-app registration;
- package-integrity verification before installation;
- upgrade staging;
- preservation of configuration and installed themes;
- `-WhatIf`;
- optional launch after installation.

The uninstaller:

- removes Phoenix application files, shortcuts, and installed-app registration;
- preserves configuration and installed themes by default;
- supports complete removal with `-RemoveUserData`;
- records enough installation metadata to distinguish runtime files from
  preserved user data.

## 20. Licensing

Phoenix v0.1.0 is released under:

```text
MIT OR Apache-2.0 OR GPL-3.0-or-later
```

The `OR` expression means a recipient may choose any one of the three licenses
when using, modifying, or distributing Phoenix.

The release contains:

- `LICENSE.txt` — the license-choice notice and SPDX expression;
- `LICENSES\MIT.txt` — the complete MIT license;
- `LICENSES\Apache-2.0.txt` — the complete Apache License 2.0;
- `LICENSES\GPL-3.0-or-later.txt` — the complete GNU GPL v3-or-later terms.

The module manifest contains the same expression, license URL, project URL, and:

```text
Copyright (c) 2026 Donaven Guardipee
```

## 21. Important Git milestones

The following commits mark the principal later-stage v0.1.0 milestones:

| Commit | Milestone |
|---|---|
| `69c7e08` | Automated Phoenix capability and repository documentation |
| `c78048d` | Made README generation idempotent |
| `f33f31d` | Installed applicable drivers through Windows Update |
| `455a1e2` | Restored drivers and packages from a Phoenix manifest |
| `30d19c4` | Handled existing and uncorrelated restore packages |
| `ff93038` | Separated full software inventory from restorable packages |
| `b1745e0` | Added Pester restore regression coverage |
| `42429c3` | Automated build validation and regression testing |
| `23fe3eb` | Required a supported Pester version |
| `54341d2` | Integrated PSScriptAnalyzer validation |
| `cd0e340` | Filtered and retained Phoenix session logs |
| `c992210` | Added the customizable desktop Control Center |

Release packaging, the tri-license, distribution scripts, this historical
record, and the final v0.1.0 release commit follow those milestones.

## 22. v0.1.0 verification baseline

The v0.1.0 source and release candidate completed all of the following:

- `Build.ps1` completes successfully;
- generated classes validate;
- `Phoenix.psd1` imports in an isolated PowerShell process;
- PSScriptAnalyzer reports no blocking findings;
- all 48 Pester tests pass;
- the release manifest and all release scripts parse successfully;
- module and license metadata use version `0.1.0`;
- the release runtime payload contains this `Docs` directory;
- `RELEASE.json` contains per-file integrity hashes;
- the release ZIP checksum is generated;
- a clean installation is tested;
- an upgrade preserves configuration and installed themes;
- default uninstall preserves user data;
- complete uninstall removes user data when explicitly requested.

### Completed release-candidate smoke test

The runtime-only `Phoenix-0.1.0.zip` candidate contained 94 runtime files. Its
generated SHA-256 checksum matched an independent `Get-FileHash` calculation.

The extracted release then passed this end-to-end installation matrix:

1. **Clean CurrentUser installation**
   - installed successfully into an isolated custom location;
   - exposed module version `0.1.0`;
   - included this development-history document;
   - included the packaged uninstaller.
2. **In-place upgrade**
   - recognized the existing installation;
   - preserved a custom `Phoenix.UI.json` marker;
   - preserved the complete configuration-file hash;
   - preserved an installed-theme marker and its hash.
3. **Default uninstall**
   - removed the Phoenix runtime and uninstaller;
   - removed Windows installed-app registration;
   - retained the installation directory only for preserved user data;
   - preserved configuration and installed-theme markers;
   - created `.phoenix-user-data.json`.
4. **Recovery reinstall**
   - recognized the preserved-data directory;
   - restored the runtime and uninstaller;
   - restored installation metadata;
   - retained the configuration and installed-theme markers;
   - replaced the old preservation marker with active installation metadata.
5. **Complete uninstall**
   - applied successfully with `-RemoveUserData`;
   - did not preserve configuration or installed themes;
   - removed the complete installation directory;
   - removed Windows installed-app registration.

The history and changelog were updated after this smoke test. Therefore, the
final v0.1.0 archive and checksum are regenerated once more before publication;
the tested installer, uninstaller, module, and runtime code are unchanged.

## 23. Known v0.1.0 limitations

Phoenix v0.1.0 is a Windows-only first release.

Known limitations include:

- driver delivery uses Windows Update rather than OEM-specific tools or
  offline driver packs;
- package availability and metadata depend on WinGet and Chocolatey;
- some providers do not expose complete release notes or patch details;
- manifest restore installs provider-current package versions instead of
  guaranteeing exact historical versions;
- manifest restore does not restore application data, user profiles, or all
  Windows settings;
- theme packages are deliberately restricted to declarative, size-limited
  content;
- existing non-blocking PSScriptAnalyzer warnings remain technical debt;
- broader package caching, dependency orchestration, parallel installation,
  reboot-resume automation, offline restoration, and pre-OS deployment remain
  future work.

## 24. v0.1.0 release statement

Phoenix v0.1.0 establishes a tested and releasable foundation for Windows
application and driver management. It combines:

- a PowerShell automation module;
- driver-first update and restore behavior;
- WinGet and Chocolatey package management;
- hardware, software, network, operating-system, package, and driver inventory;
- schema-versioned backup and restore manifests;
- safe elevation and structured results;
- filtered, retained logging;
- a responsive and customizable desktop Control Center;
- application search and lifecycle actions;
- driver lifecycle actions;
- theme presets and Theme Studio;
- automated class generation, static analysis, tests, coverage, and builds;
- runtime-only release packaging;
- verified installation, upgrade, and uninstallation workflows;
- a confirmed tri-license.

This document closes the v0.1.0 development cycle. The next development-history
document will begin with work performed after the v0.1.0 release and will be
published with v0.2.0.
