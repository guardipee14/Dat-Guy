function Get-PhoenixControlCenterInventory {

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $context =
        Resolve-PhoenixContext `
            -ErrorAction Stop

    $warnings =
        [System.Collections.Generic.List[string]]::new()

    foreach (
        $initializationWarning in @(
            $context.InitializationWarnings
        )
    ) {
        if (
            -not [string]::IsNullOrWhiteSpace(
                [string]$initializationWarning
            )
        ) {
            $warnings.Add(
                [string]$initializationWarning
            )
        }
    }

    $runtimeRecovery =
        $context.RuntimeRecovery

    if ($null -ne $runtimeRecovery) {
        foreach (
            $recoveryWarning in @(
                $runtimeRecovery.Warnings
            )
        ) {
            if (
                -not [string]::IsNullOrWhiteSpace(
                    [string]$recoveryWarning
                ) -and
                -not $warnings.Contains(
                    [string]$recoveryWarning
                )
            ) {
                $warnings.Add(
                    [string]$recoveryWarning
                )
            }
        }
    }

    $providerCapabilities = @{}

    foreach ($provider in @($context.Providers)) {
        $providerCapabilities[[string]$provider.Name] =
            $provider.GetCapability()
    }

    $hardware = [ordered]@{}
    $network = [ordered]@{}
    $operatingSystem = $null

    try {
        $hardware = Get-HardwareInventory
    }
    catch {
        $warnings.Add(
            "Hardware inventory failed: $($_.Exception.Message)"
        )
    }

    try {
        $network = Get-NetworkInventory
    }
    catch {
        $warnings.Add(
            "Network inventory failed: $($_.Exception.Message)"
        )
    }

    try {
        $operatingSystem =
            Get-CimInstance `
                -ClassName Win32_OperatingSystem `
                -ErrorAction Stop
    }
    catch {
        $warnings.Add(
            "Operating-system inventory failed: $($_.Exception.Message)"
        )
    }

    $applications = @()

    try {

        $applications = @(
            Get-PhoenixPackages |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace($_.Id)
                } |
                Sort-Object `
                    -Property @(
                        'Provider'
                        'Id'
                    ) `
                    -Unique |
                ForEach-Object {

                    $providerCapability =
                        $providerCapabilities[
                            [string]$_.Provider
                        ]

                    [bool]$providerAvailable =
                        $null -ne $providerCapability -and
                        $providerCapability.Available

                    [bool]$restorable =
                        Test-PhoenixRestorePackage `
                            -InputObject $_

                    [bool]$packageSupportsRepair = $true
                    [bool]$packageSupportsRemove = $true

                    if ($_.Provider -eq 'EXE') {
                        $repairProperty =
                            $_.PSObject.Properties['RepairCommand']
                        $uninstallProperty =
                            $_.PSObject.Properties['UninstallCommand']
                        $quietUninstallProperty =
                            $_.PSObject.Properties['QuietUninstallCommand']

                        $packageSupportsRepair =
                            $null -ne $repairProperty -and
                            -not [string]::IsNullOrWhiteSpace(
                                [string]$repairProperty.Value
                            )
                        $packageSupportsRemove =
                            ($null -ne $uninstallProperty -and
                                -not [string]::IsNullOrWhiteSpace(
                                    [string]$uninstallProperty.Value
                                )) -or
                            ($null -ne $quietUninstallProperty -and
                                -not [string]::IsNullOrWhiteSpace(
                                    [string]$quietUninstallProperty.Value
                                ))
                    }

                    [pscustomobject]@{
                        IsSelected     = $false
                        Name           = $_.Name
                        Id             = $_.Id
                        Version        = $_.Version
                        Provider       = $_.Provider
                        Source         = $_.Source
                        Architecture   = $_.Architecture
                        Installed      = [bool]$_.Installed
                        ProviderAvailable = $providerAvailable
                        SupportsUpdate = [bool](
                            $providerAvailable -and
                            $providerCapability.SupportsUpdate
                        )
                        SupportsRepair = [bool](
                            $providerAvailable -and
                            $providerCapability.SupportsRepair -and
                            $packageSupportsRepair
                        )
                        SupportsRemove = [bool](
                            $providerAvailable -and
                            $providerCapability.SupportsRemove -and
                            $packageSupportsRemove
                        )
                        ProviderHealth = if (
                            $null -ne $providerCapability
                        ) {
                            $providerCapability.HealthMessage
                        }
                        else {
                            'Provider is not registered.'
                        }
                        Restorable     = $restorable
                        Actionable     = [bool](
                            $providerAvailable -and
                            (
                                $providerCapability.SupportsUpdate -or
                                $providerCapability.SupportsRepair -or
                                $providerCapability.SupportsRemove
                            )
                        )
                        UpdateAvailable = $false
                        AvailableVersion = ''
                        UpdateStatus     = 'Not checked'
                        MetadataStatus   = 'Not loaded'
                        ReleaseNotes     = ''
                        ReleaseNotesUrl  = ''
                        OriginalPackage = $_
                    }
                }
        )
    }
    catch {
        $warnings.Add(
            "Application inventory failed: $($_.Exception.Message)"
        )
    }

    $drivers = @()

    try {

        $deviceStatusById = @{}

        Get-CimInstance `
            -ClassName Win32_PnPEntity `
            -ErrorAction Stop |
            ForEach-Object {

                [string]$deviceId = $_.DeviceID

                if (
                    -not [string]::IsNullOrWhiteSpace(
                        $deviceId
                    )
                ) {

                    $deviceStatusById[$deviceId] =
                        [pscustomobject]@{
                            Status      = [string]$_.Status
                            ProblemCode = (
                                [int]$_.ConfigManagerErrorCode
                            )
                        }
                }
            }

        $drivers = @(
            Get-CimInstance `
                -ClassName Win32_PnPSignedDriver `
                -ErrorAction Stop |
                ForEach-Object {

                    [string]$deviceId = $_.DeviceID
                    $deviceStatus = $null

                    if (
                        -not [string]::IsNullOrWhiteSpace(
                            $deviceId
                        ) -and
                        $deviceStatusById.ContainsKey(
                            $deviceId
                        )
                    ) {
                        $deviceStatus =
                            $deviceStatusById[$deviceId]
                    }

                    [int]$problemCode = 0
                    [string]$status = ''

                    if ($null -ne $deviceStatus) {
                        $problemCode =
                            [int]$deviceStatus.ProblemCode

                        $status =
                            [string]$deviceStatus.Status
                    }

                    [pscustomobject]@{
                        IsSelected  = $false
                        Name        = [string]$_.DeviceName
                        Manufacturer = [string]$_.Manufacturer
                        Version     = [string]$_.DriverVersion
                        Class       = [string]$_.DeviceClass
                        Provider    = [string]$_.DriverProviderName
                        InfName     = [string]$_.InfName
                        DeviceId    = $deviceId
                        Status      = $status
                        ProblemCode = $problemCode
                        HasProblem  = ($problemCode -ne 0)
                    }
                } |
                Sort-Object `
                    -Property @(
                        'Class'
                        'Manufacturer'
                        'Name'
                    )
        )
    }
    catch {
        $warnings.Add(
            "Driver inventory failed: $($_.Exception.Message)"
        )
    }

    $providers = @(
        $context.Providers |
            Sort-Object Priority -Descending |
            ForEach-Object {
                $capability =
                    $providerCapabilities[
                        [string]$_.Name
                    ]

                [pscustomobject]@{
                    Name           = $_.Name
                    Version        = $_.Version
                    Available      = [bool]$_.Available
                    Availability   =
                        $capability.Availability.ToString()
                    Priority       = [int]$_.Priority
                    Search         = [bool]$capability.SupportsSearch
                    Inventory      = [bool]$capability.SupportsInventory
                    Install        = [bool]$_.SupportsInstall
                    Update         = [bool]$_.SupportsUpdate
                    Repair         = [bool]$_.SupportsRepair
                    Remove         = [bool]$_.SupportsRemove
                    Export         = [bool]$capability.SupportsExport
                    Restore        = [bool]$capability.SupportsRestore
                    Operations     =
                        $capability.SupportedOperations -join ', '
                    Privilege      = (
                        $_.RequiredPrivilege.ToString()
                    )
                    Health         = $capability.HealthMessage
                    CheckedAtUtc   = $capability.CheckedAtUtc
                }
            }
    )

    $computerSystem = @(
        $hardware['Computer']
    ) |
        Select-Object -First 1

    $processor = @(
        $hardware['Processor']
    ) |
        Select-Object -First 1

    [double]$memoryBytes = 0

    foreach (
        $memoryDevice in @(
            $hardware['Memory']
        )
    ) {
        if (
            $null -ne $memoryDevice -and
            $null -ne $memoryDevice.PSObject.Properties[
                'Capacity'
            ]
        ) {
            $memoryBytes +=
                [double]$memoryDevice.Capacity
        }
    }

    if (
        $memoryBytes -le 0 -and
        $null -ne $computerSystem -and
        $null -ne $computerSystem.PSObject.Properties[
            'TotalPhysicalMemory'
        ]
    ) {
        $memoryBytes =
            [double]$computerSystem.TotalPhysicalMemory
    }

    [string]$operatingSystemName =
        [Environment]::OSVersion.VersionString

    [string]$operatingSystemVersion = ''
    [string]$operatingSystemBuild = ''
    [string]$operatingSystemArchitecture = ''

    if ($null -ne $operatingSystem) {
        $operatingSystemName =
            [string]$operatingSystem.Caption

        $operatingSystemVersion =
            [string]$operatingSystem.Version

        $operatingSystemBuild =
            [string]$operatingSystem.BuildNumber

        $operatingSystemArchitecture =
            [string]$operatingSystem.OSArchitecture
    }

    [string]$manufacturer = ''
    [string]$model = ''
    [string]$processorName = ''

    if ($null -ne $computerSystem) {
        $manufacturer =
            [string]$computerSystem.Manufacturer

        $model =
            [string]$computerSystem.Model
    }

    if ($null -ne $processor) {
        $processorName =
            [string]$processor.Name
    }

    $summary = [pscustomobject]@{
        ComputerName = $env:COMPUTERNAME
        Manufacturer = $manufacturer
        Model        = $model
        Processor    = $processorName
        MemoryGB     = [Math]::Round(
            $memoryBytes / (
                1024 * 1024 * 1024
            ),
            2
        )
        OperatingSystem = $operatingSystemName
        OsVersion       = $operatingSystemVersion
        OsBuild         = $operatingSystemBuild
        Architecture    = $operatingSystemArchitecture
        Administrator = [bool]$context.IsAdministrator
    }

    [string]$recoveryCode =
        'PHX_RUNTIME_UNKNOWN'

    [bool]$runtimeRecovered = $false
    [int]$recoveryItemCount = 0
    [string]$lastRecoveryAtUtc = 'None recorded'
    [string]$recoveryJournalPath = ''

    if ($null -ne $runtimeRecovery) {
        $recoveryCode =
            [string]$runtimeRecovery.Code

        $runtimeRecovered =
            [bool]$runtimeRecovery.Recovered

        $recoveryItemCount = (
            @(
                $runtimeRecovery.CreatedDirectories
            ).Count +
            @(
                $runtimeRecovery.RepairedFiles
            ).Count
        )

        $recoveryJournalPath =
            [string]$runtimeRecovery.JournalPath

        if (
            $null -ne $runtimeRecovery.LastRecovery -and
            $null -ne
                $runtimeRecovery.LastRecovery.PSObject.Properties[
                    'CompletedAtUtc'
                ]
        ) {
            $lastRecoveryAtUtc =
                [string]$runtimeRecovery.LastRecovery.CompletedAtUtc
        }
    }

    $lifecycle = [pscustomobject]@{
        State            = [string]$context.LifecycleState
        SessionId        = [string]$context.SessionID
        Generation       = [int]$context.Generation
        StartedAtUtc     = $context.StartTime.ToUniversalTime()
        InitializedAtUtc = $context.InitializedAtUtc
        IsResumed        = [bool]$context.IsResumed
        WarningCount     = @(
            $context.InitializationWarnings
        ).Count
        RecoveryCode       = $recoveryCode
        RuntimeRecovered   = $runtimeRecovered
        RecoveryItemCount  = $recoveryItemCount
        LastRecoveryAtUtc  = $lastRecoveryAtUtc
        RecoveryJournalPath = $recoveryJournalPath
    }

    return [pscustomobject]@{
        CollectedAtUtc  = (Get-Date).ToUniversalTime()
        Context         = $context
        Lifecycle       = $lifecycle
        Summary         = $summary
        Hardware        = $hardware
        Network         = $network
        OperatingSystem = $operatingSystem
        Applications    = @($applications)
        Drivers         = @($drivers)
        DriverUpdates   = @()
        Providers       = @($providers)
        Warnings        = @($warnings)
    }
}
