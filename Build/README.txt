Phoenix Composite Provider Build System

Files:
- Build-PhoenixClasses.ps1
- Set-PhoenixCompositeProvider.ps1

Installation:
1. Back up your current Build\Build-PhoenixClasses.ps1.
2. Copy Build-PhoenixClasses.ps1 into the Build folder.
3. Copy Set-PhoenixCompositeProvider.ps1 into the Build folder.

Behavior:
- Without a .composite-ready marker, a provider is built from:
  Classes\20-Providers\<ProviderName>.ps1
- With the marker, it is built from:
  Classes\20-Providers\<ProviderName>\<ProviderName>.Header.ps1
  Classes\20-Providers\<ProviderName>\Methods\*.ps1
  Classes\20-Providers\<ProviderName>\<ProviderName>.Footer.ps1

Enable a migrated provider:
.\Build\Set-PhoenixCompositeProvider.ps1 -ProviderName PhoenixProvider

Disable it and return to the legacy file:
.\Build\Set-PhoenixCompositeProvider.ps1 -ProviderName PhoenixProvider -Disable

Build:
.\Build\Build-PhoenixClasses.ps1

The builder maps generated parse errors back to the original source fragment
and writes per-provider snapshots under Classes\Generated.
