using module '..\Classes\Phoenix.Classes.psm1'

function New-PhoenixDiskPlan {

    [CmdletBinding()]
    [OutputType([PhoenixDiskPlan])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Number')]
        [ValidateRange(0, 65535)]
        [int]$DiskNumber,

        [Parameter(Mandatory, ParameterSetName = 'InputObject')]
        [ValidateNotNull()]
        [object]$InputObject,

        [Parameter()]
        [ValidateRange(20GB, [long]::MaxValue)]
        [long]$MinimumWindowsSize = 32GB,

        [Parameter()]
        [ValidateRange(512MB, 16GB)]
        [long]$RecoverySize = 1GB
    )

    $disk =
        if ($PSCmdlet.ParameterSetName -eq 'Number') {
            Get-Disk -Number $DiskNumber -ErrorAction Stop
        }
        else {
            $InputObject
        }

    if (@($disk).Count -ne 1) { throw 'Exactly one disk identity is required.' }
    foreach ($property in @('Number','UniqueId','SerialNumber','Size','BusType','IsBoot','IsSystem','IsReadOnly','IsOffline')) {
        if ($property -notin $disk.PSObject.Properties.Name -or $null -eq $disk.$property) {
            throw "Disk identity is missing required property: $property."
        }
    }
    foreach ($property in @('IsBoot','IsSystem','IsReadOnly','IsOffline')) {
        if ($disk.$property -isnot [bool]) { throw "Disk safety flag $property must be Boolean." }
    }
    foreach ($property in @('Number','Size')) {
        if ($disk.$property -isnot [int] -and $disk.$property -isnot [uint32] -and
            $disk.$property -isnot [long] -and $disk.$property -isnot [uint64]) {
            throw "Disk $property must be an integer."
        }
    }
    if ($PSCmdlet.ParameterSetName -eq 'Number' -and $disk.Number -ne $DiskNumber) { throw 'Storage returned a different disk number.' }

    $identity = New-Object -TypeName PhoenixDiskIdentity
    $identity.DiskNumber = [int]$disk.Number
    $identity.UniqueId = [string]$disk.UniqueId
    $identity.SerialNumber = [string]$disk.SerialNumber
    $identity.Size = [long]$disk.Size
    $identity.BusType = [string]$disk.BusType
    $identity.IsBoot = [bool]$disk.IsBoot
    $identity.IsSystem = [bool]$disk.IsSystem
    $identity.IsReadOnly = [bool]$disk.IsReadOnly
    $identity.IsOffline = [bool]$disk.IsOffline
    $identity.RefreshFingerprint()

    if (-not $identity.IsValid()) {
        throw 'The target disk does not have a complete, stable hardware identity.'
    }

    if ($identity.IsBoot -or $identity.IsSystem) {
        throw "Disk $($identity.DiskNumber) is the running boot or system disk and cannot be planned."
    }

    if ($identity.IsReadOnly) {
        throw "Disk $($identity.DiskNumber) is read-only."
    }
    if ($identity.IsOffline) { throw "Disk $($identity.DiskNumber) is offline." }

    [long]$alignment = 1MB
    [long]$gptTailReserve = 1MB
    [long]$efiSize = 260MB
    [long]$msrSize = 16MB
    [long]$roundedRecovery = $RecoverySize + (($alignment - ($RecoverySize % $alignment)) % $alignment)
    [long]$fixedBytes = $alignment + $efiSize + $msrSize + $roundedRecovery + $gptTailReserve
    if ($identity.Size -le $fixedBytes) { throw 'Disk capacity cannot hold the required boot and recovery partitions.' }
    [long]$availableWindows = $identity.Size - $fixedBytes
    [long]$windowsSize = $availableWindows - ($availableWindows % $alignment)

    if ($windowsSize -lt $MinimumWindowsSize) {
        throw "Disk $($identity.DiskNumber) does not have enough capacity for the minimum Windows partition."
    }

    $plan = New-Object -TypeName PhoenixDiskPlan
    $plan.Target = $identity
    $plan.MinimumWindowsSize = $MinimumWindowsSize
    $partitions = [Collections.Generic.List[PhoenixDiskPartitionPlan]]::new()
    [long]$offset = $alignment

    foreach ($definition in @(
        [pscustomobject]@{ Name = 'System'; Role = 'EFI'; Size = $efiSize; FileSystem = 'FAT32'; GptType = '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}'; Remaining = $false }
        [pscustomobject]@{ Name = 'Microsoft reserved'; Role = 'MSR'; Size = $msrSize; FileSystem = ''; GptType = '{e3c9e316-0b5c-4db8-817d-f92df00215ae}'; Remaining = $false }
        [pscustomobject]@{ Name = 'Windows'; Role = 'Windows'; Size = $windowsSize; FileSystem = 'NTFS'; GptType = '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}'; Remaining = $false }
        [pscustomobject]@{ Name = 'Windows RE tools'; Role = 'Recovery'; Size = $roundedRecovery; FileSystem = 'NTFS'; GptType = '{de94bba4-06d1-4d40-a16a-bfd50179d6ac}'; Remaining = $false }
    )) {
        $partition = New-Object -TypeName PhoenixDiskPartitionPlan
        $partition.Name = $definition.Name
        $partition.Role = $definition.Role
        $partition.Offset = $offset
        $partition.Size = [long]$definition.Size
        $partition.FileSystem = $definition.FileSystem
        $partition.GptType = $definition.GptType
        $partition.UseRemainingSpace = [bool]$definition.Remaining
        $partitions.Add($partition)
        $offset += $partition.Size
    }

    $plan.Partitions = @($partitions)
    $plan.RequiredBytes = $offset
    $plan.UnallocatedBytes = $identity.Size - $plan.RequiredBytes

    if (-not $plan.IsValid()) {
        throw 'Phoenix could not produce a valid, non-overlapping UEFI/GPT disk plan.'
    }

    return $plan
}
