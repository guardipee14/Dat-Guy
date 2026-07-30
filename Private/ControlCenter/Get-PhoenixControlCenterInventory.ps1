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

                    [pscustomobject]@{
                        IsSelected     = $false
                        Name           = $_.Name
                        Id             = $_.Id
                        Version        = $_.Version
                        Provider       = $_.Provider
                        Source         = $_.Source
                        Architecture   = $_.Architecture
                        Installed      = [bool]$_.Installed
                        Actionable     = [bool](
                            Test-PhoenixRestorePackage `
                                -InputObject $_
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
                [pscustomobject]@{
                    Name           = $_.Name
                    Version        = $_.Version
                    Available      = [bool]$_.Available
                    Priority       = [int]$_.Priority
                    Install        = [bool]$_.SupportsInstall
                    Update         = [bool]$_.SupportsUpdate
                    Repair         = [bool]$_.SupportsRepair
                    Remove         = [bool]$_.SupportsRemove
                    Privilege      = (
                        $_.RequiredPrivilege.ToString()
                    )
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
