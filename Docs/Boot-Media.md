# Bootable media

Create a workspace from installed Windows ADK/WinPE inputs, then build an ISO:

```powershell
$ready = Get-PhoenixDeploymentPrerequisite
$workspace = New-PhoenixWinPEWorkspace -Path .\Work\WinPE -Prerequisite $ready
New-PhoenixBootableIso -WorkspacePath $workspace.RootPath -OutputPath .\Phoenix.iso -WhatIf
```

Remove `-WhatIf` after reviewing the output path. The ISO output must be new and
outside the source workspace. BIOS/UEFI boot sectors are read from workspace
`fwfiles` when present or from the ADK Oscdimg directory. This copies WinPE;
it does not automatically add Phoenix or PowerShell to the base image.

`Copy-PhoenixBootableMedia` erases a reviewed disk and creates a GPT EFI/FAT32
partition, capped at 30 GiB. It requires `DiskNumber`, `DiskUniqueId`,
`DiskSerialNumber`, `DiskSize`, `BusType` and the case-sensitive confirmation
`ERASE DISK <number> <unique-id> <serial>`. Always review `-WhatIf` first.
System disks and disks containing the workspace or original inputs are blocked.
Files over 4 GiB minus one byte and insufficient capacity are refused. Each
written file is hashed before the command reports success. Erasure cannot be
rolled back; a copy failure leaves incomplete media and must be reported as such.

Release validation used the installed ADK on DONAVEN: ISO SHA-256
`341D2911CF2618636B95A8044930D3A341429B2601D848D1B85E98384A1A22B9`,
395,714,560 bytes, 191 independently compared payload files. This is validation
evidence, not a distributed Windows image. The new ISO was inspected read-only,
not boot-tested. Physical USB erasure/writing was not performed; storage refusal
and device-swap cases use mocks. Use only disposable lab media until that gate
is recorded complete.
