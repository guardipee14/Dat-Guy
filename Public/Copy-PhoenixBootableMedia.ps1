using module '..\Classes\Phoenix.Classes.psm1'

function Copy-PhoenixBootableMedia {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$WorkspacePath,
        [Parameter(Mandatory)][ValidateRange(0,65535)][int]$DiskNumber,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$DiskUniqueId,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$DiskSerialNumber,
        [Parameter(Mandatory)][ValidateRange(1,[long]::MaxValue)][long]$DiskSize,
        [Parameter(Mandatory)][ValidateSet('USB','SD','MMC')][string]$BusType,
        [Parameter(Mandatory)][string]$ConfirmationText
    )
    $info = Get-PhoenixWinPEWorkspaceOwnedInfo -Path $WorkspacePath
    if ($info.Workspace.State -ne 'Ready') { throw 'Boot media requires a Ready WinPE workspace.' }
    if (-not (Test-PhoenixAdministrator)) { throw 'Administrator privileges are required.' }
    $validateDisk = {
        $current = Get-Disk -Number $DiskNumber -ErrorAction Stop
        if ($current.IsBoot -or $current.IsSystem -or $current.IsReadOnly -or $current.IsOffline) {
            throw 'Boot, system, read-only, and offline disks are blocked.'
        }
        if ($current.Number -ne $DiskNumber -or $current.UniqueId -cne $DiskUniqueId -or
            $current.SerialNumber -cne $DiskSerialNumber -or $current.Size -ne $DiskSize -or
            [string]$current.BusType -ine $BusType) { throw 'The reviewed removable disk identity changed.' }
        return $current
    }
    $null = & $validateDisk
    $requiredConfirmation = "ERASE DISK $DiskNumber $DiskUniqueId $DiskSerialNumber"
    if ($ConfirmationText -cne $requiredConfirmation) { throw "Confirmation must exactly match: $requiredConfirmation" }
    # Refuse any target containing this workspace or either original input.
    foreach ($sourcePath in @($info.RootPath, $info.Workspace.MediaSourcePath, $info.Workspace.SourceWimPath)) {
        $driveRoot = [IO.Path]::GetPathRoot($sourcePath)
        if ($driveRoot -notmatch '^[A-Za-z]:\\$') { throw 'Boot-media sources must resolve to an identified local disk.' }
        $sourcePartitions = @(Get-Partition -DriveLetter $driveRoot.Substring(0,1) -ErrorAction Stop)
        if ($sourcePartitions.Count -ne 1 -or $sourcePartitions[0].DiskNumber -eq $DiskNumber) {
            throw 'The target contains source media or its source disk is ambiguous.'
        }
    }
    $inventory = @(Get-PhoenixBootMediaInventory -MediaPath $info.Workspace.MediaPath)
    if (@($inventory | Where-Object Length -GT 4294967295).Count -gt 0) { throw 'FAT32 cannot hold a file larger than 4 GiB minus one byte.' }
    [long]$partitionBytes = [Math]::Min(30GB, $DiskSize - 2MB)
    [long]$requiredBytes = ($inventory | Measure-Object Length -Sum).Sum + 64MB
    if ($partitionBytes -lt $requiredBytes) { throw 'Insufficient capacity for boot media and filesystem overhead.' }
    $preview = [pscustomobject]@{
        DiskNumber=$DiskNumber; DiskUniqueId=$DiskUniqueId; SerialNumber=$DiskSerialNumber
        DiskSize=$DiskSize; PartitionBytes=$partitionBytes; RequiredBytes=$requiredBytes
        ConfirmationText=$requiredConfirmation; Preview=$true; Staged=$false; VerifiedFiles=0
    }
    if (-not $PSCmdlet.ShouldProcess("disk $DiskNumber ($DiskSerialNumber), $DiskSize bytes", 'Erase and stage Phoenix boot media')) { return $preview }
    # Revalidate after the interactive confirmation and immediately before erasure.
    $null = & $validateDisk
    Clear-Disk -Number $DiskNumber -RemoveData -RemoveOEM -Confirm:$false -ErrorAction Stop
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT -ErrorAction Stop | Out-Null
    $partition = New-Partition -DiskNumber $DiskNumber -Size $partitionBytes -AssignDriveLetter -GptType '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}' -ErrorAction Stop
    if ($partition.DiskNumber -ne $DiskNumber) { throw 'New partition does not belong to the reviewed disk.' }
    $volume = Format-Volume -Partition $partition -FileSystem FAT32 -NewFileSystemLabel 'PHOENIX' -Confirm:$false -Force -ErrorAction Stop
    if ([string]$volume.DriveLetter -notmatch '^[A-Za-z]$') { throw 'Formatted boot partition has no valid drive letter.' }
    $mapped = @(Get-Partition -DriveLetter $volume.DriveLetter -ErrorAction Stop)
    if ($mapped.Count -ne 1 -or $mapped[0].DiskNumber -ne $DiskNumber -or
        $mapped[0].PartitionNumber -ne $partition.PartitionNumber) { throw 'Boot volume no longer maps to the reviewed partition.' }
    $volumeRoot = '{0}:\' -f $volume.DriveLetter
    foreach ($record in $inventory) {
        $source = Join-Path $info.Workspace.MediaPath $record.RelativePath
        if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -cne $record.Sha256) { throw 'Source media changed during staging.' }
        $destination = Join-Path $volumeRoot $record.RelativePath
        [IO.Directory]::CreateDirectory((Split-Path $destination -Parent)) | Out-Null
        Copy-Item -LiteralPath $source -Destination $destination -ErrorAction Stop
        $written = Get-Item -LiteralPath $destination -ErrorAction Stop
        if ($written.Length -ne $record.Length -or (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -cne $record.Sha256) {
            throw "Written boot media failed integrity verification: $($record.RelativePath)"
        }
    }
    $null = & $validateDisk
    $preview.Preview=$false
    $preview.Staged=$true
    $preview.VerifiedFiles=$inventory.Count
    return $preview
}
