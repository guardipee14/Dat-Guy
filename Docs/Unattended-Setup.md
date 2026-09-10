# Unattended setup

Phoenix v0.2.15 generates x64 Windows answer files; generation does not run
Windows Setup, create accounts, or modify disks. Use PowerShell 7 on Windows.

```powershell
$configuration = New-PhoenixUnattendConfiguration -ComputerName 'PhoenixLab' -Locale en-US -TimeZone 'Mountain Standard Time'
New-PhoenixUnattendFile -Configuration $configuration -Path C:\PhoenixWork\autounattend.xml -WhatIf
New-PhoenixUnattendFile -Configuration $configuration -Path C:\PhoenixWork\autounattend.xml
```

The Unattended Setup page provides the same secret-free generation workflow.
Computer names, locale/time-zone identifiers, account-name rules, namespaces,
and component identities are checked. Files contain windowsPE, specialize, and
oobeSystem settings. The defaults retain EULA presentation and protection
settings; no automatic logon, disk partitioning, custom script execution,
network bypass, or built-in administrator password is generated.

## Secret policy

No passwords or product keys are stored in the typed configuration. An optional
account in a secret-free configuration is **deferred**: no LocalAccount element
is written and no blank-password account is implicitly requested. The result
reports the deferred account count. New accounts default to the Users group;
administrator membership must be selected explicitly.

For one deployment-specific account, provide its password interactively:

```powershell
$configuration = New-PhoenixUnattendConfiguration -LocalAccountName 'PhoenixUser'
$password = Read-Host 'Deployment account password' -AsSecureString
New-PhoenixUnattendFile -Configuration $configuration -Path C:\PhoenixWork\deployment-only.xml -LocalAccountPassword $password -IncludeSecrets
$password.Dispose()
```

The API accepts exactly one account when sharing a single password parameter;
it does not silently reuse a password across multiple accounts. A product key
requires ProvidedAtDeployment policy plus an explicit SecureString. Prompt and
Firmware policies omit the key and leave normal Windows Setup/media/firmware
behavior in control; they do not force an interactive prompt or override a
firmware key. The UI exposes no secret inputs, and worker requests contain none.

Explicit secrets are **plaintext in the answer file**, not encrypted by
SecureString or obscured encoding. Keep such files out of reusable ISOs, bundles,
source control, and diagnostic exports. Files are created atomically with
current-user and SYSTEM-only access and without inherited permissions. Existing
outputs and reparse-point paths are rejected. Filesystems without Windows ACL
support fail closed. Copying a file to another filesystem may lose its ACL;
protect transferred media separately. Restricted permissions are not encryption.

WhatIf does not convert SecureStrings to plaintext. Results do not return the
configuration or secret text. Serialization failures return a generic safe
message; a newly created partial file can remain access-restricted for inspection.
Choose a new path or explicitly handle that file before retrying. Phoenix does
not promise secure erasure of plaintext from memory or storage.

## Validation boundary

The result explicitly reports StructureOnly and RequiresWindowsSimValidation.
Validate against the exact Windows image/catalog in Windows System Image Manager
before deploying; structural tests are not Windows Setup acceptance or first-boot
certification. Matching language packs, settings, edition, licensing, and password
policy remain image-dependent. Tests cover namespaces, component attributes,
account actions, default omission, ACLs, overwrite protection, and error redaction
using synthetic secrets. No real account or deployment is used by these tests.

See Microsoft's [answer-file guidance](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/update-windows-settings-and-scripts-create-your-own-answer-file-sxs)
and [sensitive-data warning](https://learn.microsoft.com/en-us/windows-hardware/customize/desktop/wsim/hide-sensitive-data-in-an-answer-file).
