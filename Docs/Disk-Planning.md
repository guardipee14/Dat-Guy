# Read-only disk planning

Phoenix v0.2.16 calculates and previews a UEFI/GPT layout. It does not erase,
partition, format, apply Windows, or invoke deployment. Administrator rights
are not an approval substitute, and a preview token is not authorization.

```powershell
# Replace 7 only after identifying the intended disposable target.
$plan = New-PhoenixDiskPlan -DiskNumber 7
$preview = Show-PhoenixDiskPlan -Plan $plan
$preview.Partitions | Format-Table
$plan.HasCurrentPreview()
```

The Disk Preview Control Center page requires an explicit disk number, reads
only that disk's metadata in a background worker, and displays the serial,
unique ID, bus, exact byte capacity, fingerprint, and complete partition list.
It has no deployment button and never automatically selects Disk 0.

The required layout is exactly EFI (260 MiB FAT32), Microsoft Reserved
(16 MiB), Windows (NTFS, at least 32 GiB by default), and Windows RE (1 GiB
NTFS by default). Every offset and partition size is aligned to 1 MiB.
One MiB plus any sub-MiB capacity remainder stays unallocated at the end for
GPT metadata. Existing partitions would be erased by a future execution;
this command neither inspects their contents nor preserves them in its plan.
Optional data partitions and legacy BIOS/MBR are not implemented here.

Missing or malformed identity fields and safety flags, unknown bus types,
missing serials, boot/system disks, offline disks, and read-only disks are
rejected. Validation checks required roles, GPT types, filesystems, sizes,
contiguous offsets, capacity, and arithmetic boundaries without changing the
fingerprint. A fingerprint detects changes; it is not proof a disk is safe
to erase or a VM is disposable.

Previews last 1–30 minutes (default 10). Their digest covers the entire plan,
target, token, and time window. Edits or expiry invalidate the preview.
These are in-memory consistency checks, not signed authorization records.
Future execution must independently re-read live identities and enforce its
own confirmation and disposable-VM gates. `-InputObject` is intended for
offline fixtures/planning and does not attest a real target.

Tests use synthetic disks, including system-disk and identity failures. UI
smoke tests cover bindings and layout; no raw-disk, Windows Setup, or boot
validation is claimed by this milestone.
