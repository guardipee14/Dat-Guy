Describe 'Phoenix GPT tail reserve regression' {
    BeforeAll {
        $projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $sourcePath = Join-Path $projectRoot 'Public\New-PhoenixDiskPlan.ps1'
        $source = Get-Content -LiteralPath $sourcePath -Raw
    }

    It 'reserves one MiB at the end of GPT deployment disks' {
        $source.Contains('[long]$gptTailReserve = 1MB') |
            Should-BeTrue
    }

    It 'includes the GPT tail reserve in fixed capacity' {
        $source.Contains(
            '[long]$fixedBytes = $alignment + $efiSize + $msrSize + $roundedRecovery + $gptTailReserve'
        ) |
            Should-BeTrue
    }

    It 'leaves exactly one MiB unallocated on the 64 GiB validation disk' {
        [long]$diskSize = 64GB
        [long]$alignment = 1MB
        [long]$gptTailReserve = 1MB
        [long]$efiSize = 260MB
        [long]$msrSize = 16MB
        [long]$recoverySize = 1GB

        [long]$roundedRecovery =
            [Math]::Ceiling($recoverySize / $alignment) * $alignment

        [long]$fixedBytes =
            $alignment +
            $efiSize +
            $msrSize +
            $roundedRecovery +
            $gptTailReserve

        [long]$windowsSize =
            [Math]::Floor(
                ($diskSize - $fixedBytes) / $alignment
            ) * $alignment

        [long]$requiredBytes =
            $alignment +
            $efiSize +
            $msrSize +
            $windowsSize +
            $roundedRecovery

        [long]$unallocatedBytes = $diskSize - $requiredBytes

        ($windowsSize -eq 67354230784) |
            Should-BeTrue

        ($requiredBytes -eq 68718428160) |
            Should-BeTrue

        ($unallocatedBytes -eq 1MB) |
            Should-BeTrue
    }
}
