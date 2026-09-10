class PhoenixDiskIdentity {

    [int]$DiskNumber
    [string]$UniqueId
    [string]$SerialNumber
    [long]$Size
    [string]$BusType
    [bool]$IsBoot
    [bool]$IsSystem
    [bool]$IsReadOnly
    [bool]$IsOffline
    [string]$Fingerprint

    PhoenixDiskIdentity() {
        $this.DiskNumber = -1
        $this.UniqueId = ''
        $this.SerialNumber = ''
        $this.Size = 0
        $this.BusType = ''
        $this.IsBoot = $false
        $this.IsSystem = $false
        $this.IsReadOnly = $false
        $this.Fingerprint = ''
    }

    [string] ComputeFingerprint() {
        [string]$identity = @(
            $this.DiskNumber
            $this.UniqueId.Trim().ToUpperInvariant()
            $this.SerialNumber.Trim().ToUpperInvariant()
            $this.Size
            $this.BusType.Trim().ToUpperInvariant()
        ) -join '|'

        [byte[]]$digest = [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($identity))
        return [Convert]::ToHexString($digest).ToLowerInvariant()
    }

    [void] RefreshFingerprint() {
        $this.Fingerprint = $this.ComputeFingerprint()
    }

    [bool] IsValid() {
        if (
            $this.DiskNumber -lt 0 -or $this.DiskNumber -gt 65535 -or
            [string]::IsNullOrWhiteSpace($this.UniqueId) -or
            [string]::IsNullOrWhiteSpace($this.SerialNumber) -or
            $this.Size -le 0 -or
            $this.BusType -notin @('SATA','ATA','SAS','SCSI','USB','NVMe','RAID','Virtual','File Backed Virtual','FileBackedVirtual','SD','MMC') -or
            $this.Fingerprint -cnotmatch '^[0-9a-f]{64}$'
        ) {
            return $false
        }

        return $this.ComputeFingerprint() -ceq $this.Fingerprint
    }
}

class PhoenixDiskPartitionPlan {

    [string]$Name
    [string]$Role
    [long]$Offset
    [long]$Size
    [string]$FileSystem
    [string]$GptType
    [bool]$UseRemainingSpace

    PhoenixDiskPartitionPlan() {
        $this.Name = ''
        $this.Role = ''
        $this.Offset = 0
        $this.Size = 0
        $this.FileSystem = ''
        $this.GptType = ''
        $this.UseRemainingSpace = $false
    }

    [bool] IsValid() {
        [guid]$gptGuid = [guid]::Empty

        return (
            -not [string]::IsNullOrWhiteSpace($this.Name) -and
            $this.Role -in @('EFI', 'MSR', 'Windows', 'Recovery', 'Data') -and
            $this.Offset -ge 1048576 -and
            $this.Offset % 1048576 -eq 0 -and
            $this.Size -gt 0 -and
            $this.Size % 1048576 -eq 0 -and
            [guid]::TryParse($this.GptType, [ref]$gptGuid) -and
            $gptGuid -ne [guid]::Empty
        )
    }
}

class PhoenixDiskPlan {

    [string]$Schema
    [string]$SchemaVersion
    [string]$PlanId
    [PhoenixDiskIdentity]$Target
    [PhoenixDiskPartitionPlan[]]$Partitions
    [long]$RequiredBytes
    [long]$UnallocatedBytes
    [long]$MinimumWindowsSize = 32GB
    [string]$PreviewToken
    [string]$PreviewDigest
    [datetime]$PreviewedAtUtc
    [datetime]$PreviewExpiresAtUtc
    [datetime]$CreatedAtUtc

    PhoenixDiskPlan() {
        $this.Schema = 'PhoenixDiskPlan'
        $this.SchemaVersion = '1.0'
        $this.PlanId = [guid]::NewGuid().ToString()
        $this.Target = $null
        $this.Partitions = @()
        $this.RequiredBytes = 0
        $this.UnallocatedBytes = 0
        $this.PreviewToken = ''
        $this.PreviewedAtUtc = [datetime]::MinValue
        $this.PreviewExpiresAtUtc = [datetime]::MinValue
        $this.CreatedAtUtc = [datetime]::UtcNow
    }

    [void] SetPreview([int]$LifetimeMinutes) {
        if (-not $this.IsValid()) {
            throw 'A valid disk plan is required before preview.'
        }

        if ($LifetimeMinutes -lt 1 -or $LifetimeMinutes -gt 30) {
            throw 'Disk-plan preview lifetime must be between 1 and 30 minutes.'
        }

        $this.PreviewedAtUtc = [datetime]::UtcNow
        $this.PreviewExpiresAtUtc = $this.PreviewedAtUtc.AddMinutes($LifetimeMinutes)
        [string]$tokenInput = @(
            $this.PlanId
            $this.Target.Fingerprint
            $this.RequiredBytes
            $this.PreviewExpiresAtUtc.ToString('O')
            [guid]::NewGuid().ToString('N')
        ) -join '|'
        [byte[]]$digest = [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($tokenInput))
        $this.PreviewToken = [Convert]::ToHexString($digest).ToLowerInvariant()
        $this.PreviewDigest = $this.ComputePreviewDigest()
    }

    [string] ComputePreviewDigest() {
        # Canonical, ordered content includes every layout and target field, not just capacity.
        [object[]]$content = @(
            $this.Schema, $this.SchemaVersion, $this.PlanId, $this.CreatedAtUtc.ToString('O'),
            $this.Target.DiskNumber, $this.Target.UniqueId, $this.Target.SerialNumber,
            $this.Target.Size, $this.Target.BusType, $this.Target.IsBoot, $this.Target.IsSystem,
            $this.Target.IsReadOnly, $this.Target.IsOffline, $this.Target.Fingerprint,
            $this.RequiredBytes, $this.UnallocatedBytes, $this.MinimumWindowsSize,
            $this.PreviewToken, $this.PreviewedAtUtc.ToString('O'), $this.PreviewExpiresAtUtc.ToString('O')
        )
        foreach ($partition in $this.Partitions) {
            $content += @($partition.Name, $partition.Role, $partition.Offset, $partition.Size,
                $partition.FileSystem, $partition.GptType, $partition.UseRemainingSpace)
        }
        [string]$json = ConvertTo-Json -InputObject $content -Depth 4 -Compress
        [byte[]]$digest = [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($json))
        return [Convert]::ToHexString($digest).ToLowerInvariant()
    }

    [bool] HasCurrentPreview() {
        return (
            $this.IsValid() -and
            $this.PreviewToken -cmatch '^[0-9a-f]{64}$' -and
            $this.PreviewDigest -cmatch '^[0-9a-f]{64}$' -and
            $this.PreviewedAtUtc.Kind -eq [DateTimeKind]::Utc -and
            $this.PreviewExpiresAtUtc.Kind -eq [DateTimeKind]::Utc -and
            $this.PreviewedAtUtc -ge $this.CreatedAtUtc -and
            $this.PreviewedAtUtc -le [datetime]::UtcNow -and
            $this.PreviewExpiresAtUtc -gt $this.PreviewedAtUtc -and
            ($this.PreviewExpiresAtUtc - $this.PreviewedAtUtc).TotalMinutes -le 30 -and
            $this.PreviewDigest -ceq $this.ComputePreviewDigest() -and
            [datetime]::UtcNow -le $this.PreviewExpiresAtUtc
        )
    }

    [bool] IsValid() {
        [guid]$planGuid = [guid]::Empty

        if (
            $this.Schema -cne 'PhoenixDiskPlan' -or
            $this.SchemaVersion -cne '1.0' -or
            -not [guid]::TryParse($this.PlanId, [ref]$planGuid) -or
            $planGuid -eq [guid]::Empty -or
            $null -eq $this.Target -or
            -not $this.Target.IsValid() -or
            $this.Target.IsBoot -or
            $this.Target.IsSystem -or
            $this.Target.IsReadOnly -or
            $this.Target.IsOffline -or
            $this.CreatedAtUtc.Kind -ne [DateTimeKind]::Utc -or
            $this.CreatedAtUtc -gt [datetime]::UtcNow -or
            $this.MinimumWindowsSize -lt 20GB -or
            $this.Partitions.Count -ne 4 -or
            $this.RequiredBytes -le 0 -or
            $this.RequiredBytes -gt $this.Target.Size -or
            $this.UnallocatedBytes -ne ($this.Target.Size - $this.RequiredBytes) -or
            $this.UnallocatedBytes -lt 1MB -or $this.UnallocatedBytes -ge 2MB
        ) {
            return $false
        }

        [long]$previousEnd = 1MB
        [string[]]$roles = @('EFI', 'MSR', 'Windows', 'Recovery')
        [string[]]$formats = @('FAT32', '', 'NTFS', 'NTFS')
        [string[]]$types = @('c12a7328-f81f-11d2-ba4b-00a0c93ec93b', 'e3c9e316-0b5c-4db8-817d-f92df00215ae',
            'ebd0a0a2-b9e5-4433-87c0-68b6b72699c7', 'de94bba4-06d1-4d40-a16a-bfd50179d6ac')
        [int]$index = 0

        foreach ($partition in $this.Partitions) {
            if ($null -eq $partition -or -not $partition.IsValid() -or $partition.Offset -ne $previousEnd -or
                $partition.Role -cne $roles[$index] -or $partition.FileSystem -cne $formats[$index] -or
                [guid]$partition.GptType -ne [guid]$types[$index] -or $partition.UseRemainingSpace -or
                $partition.Offset -gt $this.Target.Size -or $partition.Size -gt ($this.Target.Size - $partition.Offset)) {
                return $false
            }
            $previousEnd = $partition.Offset + $partition.Size
            $index++
        }

        return ($previousEnd -eq $this.RequiredBytes -and $this.Partitions[0].Size -eq 260MB -and
            $this.Partitions[1].Size -eq 16MB -and $this.Partitions[2].Size -ge $this.MinimumWindowsSize -and
            $this.Partitions[3].Size -ge 512MB -and $this.Partitions[3].Size -le 16GB)
    }
}
