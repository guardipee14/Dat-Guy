BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    Import-Module (Join-Path $projectRoot 'Phoenix.psd1') -Force 6>$null
}

AfterAll {
    Remove-Module Phoenix -Force -ErrorAction SilentlyContinue
}

Describe 'Phoenix UEFI/GPT disk planning' -Tag @('Unit', 'Deployment', 'DiskPlan', 'Safety') {
    BeforeEach {
        $script:testDisk = [pscustomobject]@{
            Number = 7
            UniqueId = 'USB-PHOENIX-0007'
            SerialNumber = 'SERIAL-0007'
            Size = 128GB
            BusType = 'USB'
            IsBoot = $false
            IsSystem = $false
            IsReadOnly = $false
            IsOffline = $false
        }
    }

    It 'creates a deterministic aligned UEFI/GPT layout' {
        $first = New-PhoenixDiskPlan -InputObject $script:testDisk
        $second = New-PhoenixDiskPlan -InputObject $script:testDisk

        $first.IsValid() | Should-BeTrue
        $first.Target.Fingerprint | Should-Be $second.Target.Fingerprint
        ($first.Partitions.Role -join '|') | Should-Be 'EFI|MSR|Windows|Recovery'
        @($first.Partitions | Where-Object { $_.Offset % 1MB -ne 0 -or $_.Size % 1MB -ne 0 }).Count | Should-Be 0
        $first.RequiredBytes | Should-Be ($first.Target.Size - 1MB)
        $first.UnallocatedBytes | Should-Be 1MB
    }

    It 'issues a short-lived preview tied to exact disk identity' {
        $plan = New-PhoenixDiskPlan -InputObject $script:testDisk
        $preview = Show-PhoenixDiskPlan -Plan $plan -PreviewLifetimeMinutes 5

        $plan.HasCurrentPreview() | Should-BeTrue
        $preview.PreviewToken | Should-MatchString '^[0-9a-f]{64}$'
        $preview.DiskIdentity | Should-Be $plan.Target.Fingerprint
        $preview.Warning | Should-MatchString 'erase disk 7'
    }

    It 'permanently rejects the running boot or system disk' {
        $script:testDisk.IsBoot = $true

        { New-PhoenixDiskPlan -InputObject $script:testDisk } | Should-Throw
    }

    It 'rejects insufficient disk capacity before producing a plan' {
        $script:testDisk.Size = 24GB

        { New-PhoenixDiskPlan -InputObject $script:testDisk -MinimumWindowsSize 32GB } | Should-Throw
    }

    It 'rejects every unsafe live flag and non-Boolean flag value' {
        foreach ($flag in @('IsBoot','IsSystem','IsReadOnly','IsOffline')) {
            $disk = $script:testDisk.PSObject.Copy()
            $disk.$flag = $true
            { New-PhoenixDiskPlan -InputObject $disk } | Should-Throw
            $disk.$flag = 'false'
            { New-PhoenixDiskPlan -InputObject $disk } | Should-Throw
        }
    }

    It 'requires every identity property and rejects ambiguous serials and buses' {
        foreach ($property in $script:testDisk.PSObject.Properties.Name) {
            $disk = $script:testDisk.PSObject.Copy()
            $disk.PSObject.Properties.Remove($property)
            { New-PhoenixDiskPlan -InputObject $disk } | Should-Throw
        }
        foreach ($property in @('UniqueId','SerialNumber','BusType')) {
            $disk = $script:testDisk.PSObject.Copy()
            $disk.$property = ' '
            { New-PhoenixDiskPlan -InputObject $disk } | Should-Throw
        }
        $script:testDisk.BusType = 'Unknown'
        { New-PhoenixDiskPlan -InputObject $script:testDisk } | Should-Throw
    }

    It 'requires exactly one disk and integer number and size fields' {
        { New-PhoenixDiskPlan -InputObject @($script:testDisk,$script:testDisk) } | Should-Throw
        foreach ($property in @('Number','Size')) {
            $disk = $script:testDisk.PSObject.Copy()
            $disk.$property = 7.5
            { New-PhoenixDiskPlan -InputObject $disk } | Should-Throw
        }
    }

    It 'does not repair or mutate a mismatched fingerprint on repeated validation' {
        $plan = New-PhoenixDiskPlan -InputObject $script:testDisk
        $original = $plan.Target.Fingerprint
        $plan.Target.SerialNumber = 'CHANGED'
        $plan.Target.IsValid() | Should-BeFalse
        $plan.Target.IsValid() | Should-BeFalse
        $plan.Target.Fingerprint | Should-Be $original
    }

    It 'preserves the established VirtualBox fingerprint format' {
        $disk = [pscustomobject]@{Number=0;UniqueId='     ATAVBOX HARDDISK';SerialNumber='VB899afbd4-cafc4d89';Size=64GB;BusType='SATA';IsBoot=$false;IsSystem=$false;IsReadOnly=$false;IsOffline=$false}
        $plan = New-PhoenixDiskPlan -InputObject $disk
        $plan.Target.Fingerprint | Should-Be '4d6dabca546541626634989fe1e6da4861c1df8f02acbec47d130f8e616bfd9f'
    }

    It 'reports exact identity and explicitly disables execution' {
        $preview = New-PhoenixDiskPlan -InputObject $script:testDisk | Show-PhoenixDiskPlan
        $preview.SerialNumber | Should-Be 'SERIAL-0007'
        $preview.BusType | Should-Be 'USB'
        $preview.GptTailReserveBytes | Should-Be 1MB
        $preview.ExecutionEnabled | Should-BeFalse
    }

    It 'invalidates previews after otherwise valid layout-name or raw identity edits' {
        $plan = New-PhoenixDiskPlan -InputObject $script:testDisk
        $null = Show-PhoenixDiskPlan -Plan $plan
        $plan.Partitions[2].Name = 'Renamed'
        $plan.IsValid() | Should-BeTrue
        $plan.HasCurrentPreview() | Should-BeFalse
        $null = Show-PhoenixDiskPlan -Plan $plan
        $plan.Target.UniqueId = ' ' + $plan.Target.UniqueId
        $plan.Target.IsValid() | Should-BeTrue
        $plan.HasCurrentPreview() | Should-BeFalse
    }

    It 'rejects expired, future-dated, extended, and token-altered previews' {
        foreach ($change in @('Expired','Future','Extended','Token')) {
            $plan = New-PhoenixDiskPlan -InputObject $script:testDisk
            $null = Show-PhoenixDiskPlan -Plan $plan
            switch ($change) {
                'Expired' { $plan.PreviewExpiresAtUtc = [datetime]::UtcNow.AddSeconds(-1) }
                'Future' { $plan.PreviewedAtUtc = [datetime]::UtcNow.AddMinutes(1) }
                'Extended' { $plan.PreviewExpiresAtUtc = $plan.PreviewedAtUtc.AddHours(24) }
                'Token' { $plan.PreviewToken = 'a' * 64 }
            }
            $plan.HasCurrentPreview() | Should-BeFalse
        }
    }

    It 'rejects previews outside the explicit lifetime bounds' {
        $plan = New-PhoenixDiskPlan -InputObject $script:testDisk
        { $plan.SetPreview(0) } | Should-Throw
        { $plan.SetPreview(31) } | Should-Throw
        $plan.HasCurrentPreview() | Should-BeFalse
    }

    It 'rejects wrong roles, filesystems, GPT types, and unresolved remaining-space flags' {
        foreach ($change in @('Role','FileSystem','GptType','UseRemainingSpace')) {
            $plan = New-PhoenixDiskPlan -InputObject $script:testDisk
            switch ($change) {
                'Role' { $plan.Partitions[0].Role = 'Data' }
                'FileSystem' { $plan.Partitions[0].FileSystem = 'NTFS' }
                'GptType' { $plan.Partitions[0].GptType = [guid]::NewGuid().ToString() }
                'UseRemainingSpace' { $plan.Partitions[2].UseRemainingSpace = $true }
            }
            $plan.IsValid() | Should-BeFalse
        }
    }

    It 'rejects overlaps, gaps, misalignment, missing partitions, and mismatched totals' {
        foreach ($change in @('Overlap','Gap','Alignment','Missing','Required')) {
            $plan = New-PhoenixDiskPlan -InputObject $script:testDisk
            switch ($change) {
                'Overlap' { $plan.Partitions[2].Offset -= 1MB }
                'Gap' { $plan.Partitions[2].Offset += 1MB }
                'Alignment' { $plan.Partitions[2].Size -= 1 }
                'Missing' { $plan.Partitions = $plan.Partitions[0..2] }
                'Required' { $plan.RequiredBytes -= 1MB; $plan.UnallocatedBytes += 1MB }
            }
            $plan.IsValid() | Should-BeFalse
        }
    }

    It 'refuses consuming the GPT tail or overflowing capacity' {
        $plan = New-PhoenixDiskPlan -InputObject $script:testDisk
        $plan.Partitions[3].Size += 1MB
        $plan.RequiredBytes += 1MB
        $plan.UnallocatedBytes = 0
        $plan.IsValid() | Should-BeFalse
        $plan = New-PhoenixDiskPlan -InputObject $script:testDisk
        $plan.Partitions[3].Size = [long]::MaxValue - ([long]::MaxValue % 1MB)
        $plan.IsValid() | Should-BeFalse
    }

    It 'handles maximum integer capacity without floating-point rounding overflow' {
        $script:testDisk.Size = [long]::MaxValue
        $plan = New-PhoenixDiskPlan -InputObject $script:testDisk
        $plan.IsValid() | Should-BeTrue
        $plan.UnallocatedBytes | Should-Be (2MB - 1)
    }

    It 'retains sub-MiB disk remainder and rounds recovery upward deterministically' {
        $script:testDisk.Size = 64GB + 123
        $plan = New-PhoenixDiskPlan -InputObject $script:testDisk -RecoverySize (1GB + 1)
        $plan.IsValid() | Should-BeTrue
        $plan.Partitions[3].Size | Should-Be (1GB + 1MB)
        $plan.UnallocatedBytes | Should-Be (1MB + 123)
    }

    It 'revalidates unsafe flags and minimum sizes on an existing plan' {
        $plan = New-PhoenixDiskPlan -InputObject $script:testDisk
        $plan.Target.IsOffline = $true
        $plan.IsValid() | Should-BeFalse
        $plan.Target.IsOffline = $false
        $plan.MinimumWindowsSize = $plan.Target.Size
        $plan.IsValid() | Should-BeFalse
    }

    It 'queries only the exact disk number and rejects a mismatched storage result' {
        InModuleScope Phoenix {
            Mock Get-Disk { [pscustomobject]@{Number=8;UniqueId='FIXTURE';SerialNumber='FIXTURE';Size=64GB;BusType='SATA';IsBoot=$false;IsSystem=$false;IsReadOnly=$false;IsOffline=$false} }
            { New-PhoenixDiskPlan -DiskNumber 7 } | Should-Throw
            Should-Invoke Get-Disk -Exactly -Times 1 -ParameterFilter { $Number -eq 7 }
        }
    }
}
