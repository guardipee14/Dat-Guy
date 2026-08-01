function Get-PhoenixOemHardwareIdentity {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $computerSystem = Get-CimInstance `
        -ClassName Win32_ComputerSystem `
        -ErrorAction SilentlyContinue
    $hardwareIds = @(
        Get-CimInstance `
            -ClassName Win32_PnPEntity `
            -ErrorAction SilentlyContinue |
            ForEach-Object { @($_.HardwareID) } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )

    return [pscustomobject]@{
        Manufacturer = [string]$computerSystem.Manufacturer
        Model = [string]$computerSystem.Model
        HardwareIds = $hardwareIds
    }
}

function Get-PhoenixOemDriverAdapter {
    [CmdletBinding()]
    [OutputType([PhoenixOemDriverAdapter[]])]
    param()

    return @(
        [DellOemDriverAdapter]::new()
        [HpOemDriverAdapter]::new()
        [LenovoOemDriverAdapter]::new()
        [IntelOemDriverAdapter]::new()
    )
}

function Get-PhoenixOemAdapterStatus {
    [CmdletBinding()]
    [OutputType([pscustomobject[]])]
    param()

    $identity = Get-PhoenixOemHardwareIdentity
    return @(
        foreach ($adapter in @(Get-PhoenixOemDriverAdapter)) {
            $adapter.Applicable = $adapter.TestApplicable(
                $identity.Manufacturer,
                $identity.HardwareIds
            )
            $adapter.GetStatus()
        }
    )
}

function Invoke-PhoenixOemDriverAction {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Scan','Install')]
        [string]$Action,

        [Parameter()]
        [AllowEmptyString()]
        [string]$AdapterName = '',

        [Parameter()]
        [AllowEmptyString()]
        [string]$UpdateId = '',

        [Parameter()]
        [switch]$ApproveUtility
    )

    $identity = Get-PhoenixOemHardwareIdentity
    $adapter = @(
        Get-PhoenixOemDriverAdapter |
            Where-Object Name -IEQ $AdapterName
    ) | Select-Object -First 1

    if (
        $null -eq $adapter -or
        -not $adapter.TestApplicable(
            $identity.Manufacturer,
            $identity.HardwareIds
        )
    ) {
        return @(
            Invoke-PhoenixControlCenterDriverAction `
                -Action ScanUpdates `
                -Unattended
        )
    }

    if (
        $adapter.RequiresUtilityApproval -and
        -not $adapter.UtilityAvailable -and
        -not $ApproveUtility
    ) {
        $result = [Result]::Failure(
            "Approval is required before installing $($adapter.UtilityName)."
        )
        $result.Code = 'PHX_OEM_UTILITY_APPROVAL_REQUIRED'
        $result.Provider = $adapter.Name
        $result.Operation = $Action
        $result.Target = $adapter.UtilityName
        return @($result)
    }

    $updates = @($adapter.Scan($identity))
    if ($Action -eq 'Scan') { return $updates }

    $update = @($updates | Where-Object Id -EQ $UpdateId) |
        Select-Object -First 1
    if ($null -eq $update) {
        $result = [Result]::Failure('The selected OEM driver update was not found.')
        $result.Code = 'PHX_OEM_UPDATE_NOT_FOUND'
        $result.Provider = $adapter.Name
        $result.Operation = 'InstallDriver'
        $result.Target = $UpdateId
        return @($result)
    }
    return @($adapter.Install($update))
}

function Start-PhoenixOemDriverOperation {
    [CmdletBinding()]
    [OutputType([PhoenixBackgroundOperation])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Scan','Install')]
        [string]$Action,

        [Parameter()]
        [string]$AdapterName = '',

        [Parameter()]
        [string]$UpdateId = '',

        [Parameter()]
        [switch]$ApproveUtility,

        [Parameter(Mandatory)]
        [string]$ProjectRoot,

        [Parameter()]
        [scriptblock]$Completion = {}
    )

    $operation = New-PhoenixBackgroundOperation `
        -Action OemDriverAction `
        -Parameters ([pscustomobject]@{
            OemAction = $Action
            AdapterName = $AdapterName
            UpdateId = $UpdateId
            ApproveUtility = [bool]$ApproveUtility
        }) `
        -Component Drivers `
        -Description "$Action OEM drivers with $AdapterName" `
        -Completion $Completion `
        -ProjectRoot $ProjectRoot

    return Start-PhoenixBackgroundOperation `
        -Operation $operation `
        -ProjectRoot $ProjectRoot
}
