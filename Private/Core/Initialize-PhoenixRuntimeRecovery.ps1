function Test-PhoenixRecoveryObject {

    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$InputObject
    )

    if ($null -eq $InputObject) {
        return $false
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        return $true
    }

    return (
        $InputObject -is [pscustomobject]
    )
}

function Get-PhoenixRecoveryPropertyNames {

    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]$InputObject
    )

    if ($InputObject -is [System.Collections.IDictionary]) {
        return @(
            $InputObject.Keys |
                ForEach-Object {
                    [string]$_
                }
        )
    }

    return @(
        $InputObject.PSObject.Properties.Name
    )
}

function Get-PhoenixRecoveryPropertyValue {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    if ($InputObject -is [System.Collections.IDictionary]) {
        return $InputObject[$Name]
    }

    $property =
        $InputObject.PSObject.Properties[$Name]

    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Merge-PhoenixRecoveryConfiguration {

    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Stored,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]$Defaults
    )

    if (
        Test-PhoenixRecoveryObject `
            -InputObject $Defaults
    ) {
        if (
            -not (
                Test-PhoenixRecoveryObject `
                    -InputObject $Stored
            )
        ) {
            $Stored = [pscustomobject]@{}
        }

        $merged = [ordered]@{}

        $defaultPropertyNames = @(
            Get-PhoenixRecoveryPropertyNames `
                -InputObject $Defaults
        )

        $storedPropertyNames = @(
            Get-PhoenixRecoveryPropertyNames `
                -InputObject $Stored
        )

        foreach ($propertyName in $defaultPropertyNames) {
            $defaultValue =
                Get-PhoenixRecoveryPropertyValue `
                    -InputObject $Defaults `
                    -Name $propertyName

            if ($storedPropertyNames -contains $propertyName) {
                $storedValue =
                    Get-PhoenixRecoveryPropertyValue `
                        -InputObject $Stored `
                        -Name $propertyName

                if ($null -eq $storedValue) {
                    $merged[$propertyName] = $defaultValue
                }
                elseif (
                    (
                        Test-PhoenixRecoveryObject `
                            -InputObject $defaultValue
                    ) -and
                    (
                        Test-PhoenixRecoveryObject `
                            -InputObject $storedValue
                    )
                ) {
                    $merged[$propertyName] =
                        Merge-PhoenixRecoveryConfiguration `
                            -Stored $storedValue `
                            -Defaults $defaultValue
                }
                elseif ($defaultValue -is [array]) {
                    $merged[$propertyName] =
                        Merge-PhoenixRecoveryConfiguration `
                            -Stored @($storedValue) `
                            -Defaults $defaultValue
                }
                else {
                    $merged[$propertyName] = $storedValue
                }
            }
            else {
                $merged[$propertyName] = $defaultValue
            }
        }

        foreach ($propertyName in $storedPropertyNames) {
            if ($defaultPropertyNames -notcontains $propertyName) {
                $merged[$propertyName] =
                    Get-PhoenixRecoveryPropertyValue `
                        -InputObject $Stored `
                        -Name $propertyName
            }
        }

        return [pscustomobject]$merged
    }

    if (
        $Defaults -is [array] -and
        $Stored -is [System.Collections.IEnumerable] -and
        $Stored -isnot [string]
    ) {
        $defaultItems = @($Defaults)
        $storedItems = @($Stored)

        [bool]$identifiedObjects = (
            $defaultItems.Count -gt 0 -and
            (
                Test-PhoenixRecoveryObject `
                    -InputObject $defaultItems[0]
            ) -and
            (
                @(
                    Get-PhoenixRecoveryPropertyNames `
                        -InputObject $defaultItems[0]
                ) -contains 'Id'
            )
        )

        if (-not $identifiedObjects) {
            return @($storedItems)
        }

        $mergedItems =
            [System.Collections.Generic.List[object]]::new()

        $mergedIds =
            [System.Collections.Generic.HashSet[string]]::new(
                [StringComparer]::OrdinalIgnoreCase
            )

        foreach ($defaultItem in $defaultItems) {
            [string]$defaultId =
                Get-PhoenixRecoveryPropertyValue `
                    -InputObject $defaultItem `
                    -Name 'Id'

            $storedItem =
                $storedItems |
                    Where-Object {
                        (
                            Test-PhoenixRecoveryObject `
                                -InputObject $_
                        ) -and
                        (
                            [string](
                                Get-PhoenixRecoveryPropertyValue `
                                    -InputObject $_ `
                                    -Name 'Id'
                            )
                        ) -ieq $defaultId
                    } |
                    Select-Object -First 1

            if ($null -eq $storedItem) {
                $storedItem = $defaultItem
            }

            $mergedItems.Add(
                (
                    Merge-PhoenixRecoveryConfiguration `
                        -Stored $storedItem `
                        -Defaults $defaultItem
                )
            )

            $null = $mergedIds.Add($defaultId)
        }

        foreach ($storedItem in $storedItems) {
            if (
                -not (
                    Test-PhoenixRecoveryObject `
                        -InputObject $storedItem
                )
            ) {
                continue
            }

            [string]$storedId =
                Get-PhoenixRecoveryPropertyValue `
                    -InputObject $storedItem `
                    -Name 'Id'

            if (
                -not [string]::IsNullOrWhiteSpace($storedId) -and
                $mergedIds.Add($storedId)
            ) {
                $mergedItems.Add($storedItem)
            }
        }

        return @($mergedItems)
    }

    if ($null -eq $Stored) {
        return $Defaults
    }

    return $Stored
}

function Write-PhoenixRecoveryJson {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]$InputObject
    )

    [string]$parentPath =
        Split-Path `
            -Path $Path `
            -Parent

    if (-not (Test-Path -LiteralPath $parentPath)) {
        New-Item `
            -ItemType Directory `
            -Path $parentPath `
            -Force `
            -ErrorAction Stop |
            Out-Null
    }

    [string]$temporaryPath = (
        '{0}.{1}.tmp' -f
        $Path,
        [guid]::NewGuid().ToString('N')
    )

    try {
        $InputObject |
            ConvertTo-Json `
                -Depth 100 |
            Set-Content `
                -LiteralPath $temporaryPath `
                -Encoding UTF8 `
                -ErrorAction Stop

        Move-Item `
            -LiteralPath $temporaryPath `
            -Destination $Path `
            -Force `
            -ErrorAction Stop
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item `
                -LiteralPath $temporaryPath `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }
}

function Backup-PhoenixRecoveryConfiguration {

    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RecoveryRoot,

        [Parameter()]
        [switch]$Corrupt
    )

    [string]$fileName =
        [IO.Path]::GetFileNameWithoutExtension($Path)

    [string]$extension =
        [IO.Path]::GetExtension($Path)

    [string]$backupType =
        if ($Corrupt) {
            'corrupt'
        }
        else {
            'backup'
        }

    [string]$backupName = (
        '{0}.{1}-{2}-{3}{4}' -f
        $fileName,
        $backupType,
        (
            Get-Date `
                -Format 'yyyyMMdd-HHmmss-fff'
        ),
        [guid]::NewGuid().ToString('N').Substring(0, 8),
        $extension
    )

    [string]$backupPath =
        Join-Path `
            $RecoveryRoot `
            $backupName

    Copy-Item `
        -LiteralPath $Path `
        -Destination $backupPath `
        -Force `
        -ErrorAction Stop

    return $backupPath
}

function Repair-PhoenixJsonConfiguration {

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]$Defaults,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RecoveryRoot,

        [Parameter()]
        [scriptblock]$Normalize
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        $normalizedDefaults =
            if ($null -ne $Normalize) {
                & $Normalize $Defaults
            }
            else {
                $Defaults
            }

        Write-PhoenixRecoveryJson `
            -Path $Path `
            -InputObject $normalizedDefaults

        return [pscustomobject]@{
            Changed    = $true
            Path       = $Path
            Action     = 'Created'
            Reason     = 'Configuration file was missing.'
            BackupPath = ''
        }
    }

    $stored = $null
    [bool]$corrupt = $false
    [string]$readError = ''

    try {
        $stored =
            Get-Content `
                -LiteralPath $Path `
                -Raw `
                -ErrorAction Stop |
            ConvertFrom-Json `
                -Depth 100 `
                -ErrorAction Stop

        if (
            -not (
                Test-PhoenixRecoveryObject `
                    -InputObject $stored
            )
        ) {
            throw 'The root JSON value must be an object.'
        }
    }
    catch {
        $corrupt = $true
        $readError = $_.Exception.Message
    }

    if ($corrupt) {
        [string]$backupPath =
            Backup-PhoenixRecoveryConfiguration `
                -Path $Path `
                -RecoveryRoot $RecoveryRoot `
                -Corrupt

        $replacement =
            if ($null -ne $Normalize) {
                & $Normalize $Defaults
            }
            else {
                $Defaults
            }

        Write-PhoenixRecoveryJson `
            -Path $Path `
            -InputObject $replacement

        return [pscustomobject]@{
            Changed    = $true
            Path       = $Path
            Action     = 'Replaced'
            Reason     = (
                'Configuration JSON was invalid: {0}' -f
                $readError
            )
            BackupPath = $backupPath
        }
    }

    $merged =
        Merge-PhoenixRecoveryConfiguration `
            -Stored $stored `
            -Defaults $Defaults

    if ($null -ne $Normalize) {
        $merged = & $Normalize $merged
    }

    [string]$storedJson =
        $stored |
            ConvertTo-Json `
                -Depth 100 `
                -Compress

    [string]$mergedJson =
        $merged |
            ConvertTo-Json `
                -Depth 100 `
                -Compress

    if ($storedJson -eq $mergedJson) {
        return [pscustomobject]@{
            Changed    = $false
            Path       = $Path
            Action     = 'None'
            Reason     = ''
            BackupPath = ''
        }
    }

    [string]$backupPath =
        Backup-PhoenixRecoveryConfiguration `
            -Path $Path `
            -RecoveryRoot $RecoveryRoot

    Write-PhoenixRecoveryJson `
        -Path $Path `
        -InputObject $merged

    return [pscustomobject]@{
        Changed    = $true
        Path       = $Path
        Action     = 'Repaired'
        Reason     = (
            'Missing or invalid values were restored from safe defaults.'
        )
        BackupPath = $backupPath
    }
}

function Initialize-PhoenixRuntimeRecovery {

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ProjectRoot
    )

    [datetime]$startedAtUtc =
        (Get-Date).ToUniversalTime()

    [string]$resolvedProjectRoot =
        [IO.Path]::GetFullPath($ProjectRoot)

    $createdDirectories =
        [System.Collections.Generic.List[string]]::new()

    $repairedFiles =
        [System.Collections.Generic.List[object]]::new()

    $backups =
        [System.Collections.Generic.List[string]]::new()

    $warnings =
        [System.Collections.Generic.List[string]]::new()

    $errors =
        [System.Collections.Generic.List[string]]::new()

    [string]$configurationRecoveryRoot =
        Join-Path `
            $resolvedProjectRoot `
            'Config\Recovery'

    [string]$runtimeRecoveryRoot =
        Join-Path `
            $resolvedProjectRoot `
            'Cache\Recovery'

    [string]$journalPath =
        Join-Path `
            $runtimeRecoveryRoot `
            'LastRecovery.json'

    $lastRecovery = $null

    try {
        foreach (
            $relativeDirectory in @(
                'Config'
                'Config\Recovery'
                'Logs'
                'Cache'
                'Cache\Working'
                'Cache\Packages'
                'Cache\ControlCenter'
                'Cache\ControlCenter\Jobs'
                'Cache\Recovery'
                'Checkpoints'
                'Drivers'
                'Themes'
                'Themes\BuiltIn'
                'Themes\Installed'
            )
        ) {
            [string]$directoryPath =
                Join-Path `
                    $resolvedProjectRoot `
                    $relativeDirectory

            if (-not (Test-Path -LiteralPath $directoryPath)) {
                New-Item `
                    -ItemType Directory `
                    -Path $directoryPath `
                    -Force `
                    -ErrorAction Stop |
                    Out-Null

                $createdDirectories.Add($relativeDirectory)
            }
        }

        if (Test-Path -LiteralPath $journalPath) {
            try {
                $lastRecovery =
                    Get-Content `
                        -LiteralPath $journalPath `
                        -Raw `
                        -ErrorAction Stop |
                    ConvertFrom-Json `
                        -Depth 100 `
                        -ErrorAction Stop
            }
            catch {
                $warnings.Add(
                    (
                        'The previous Phoenix recovery journal could not ' +
                        "be read: $($_.Exception.Message)"
                    )
                )

                [string]$journalBackupPath =
                    Backup-PhoenixRecoveryConfiguration `
                        -Path $journalPath `
                        -RecoveryRoot $runtimeRecoveryRoot `
                        -Corrupt

                $backups.Add($journalBackupPath)

                $repairedFiles.Add(
                    [pscustomobject]@{
                        Changed    = $true
                        Path       = $journalPath
                        Action     = 'Replaced'
                        Reason     = (
                            'The previous recovery journal was invalid.'
                        )
                        BackupPath = $journalBackupPath
                    }
                )

                Remove-Item `
                    -LiteralPath $journalPath `
                    -Force `
                    -ErrorAction Stop
            }
        }

        $phoenixDefaults = [pscustomobject][ordered]@{
            LogLevel       = 'Info'
            MaximumLogFiles = 20
            Provider       = 'WinGet'
            OfflineMode    = $false
        }

        $normalizePhoenix = {
            param($configuration)

            if (
                [string]$configuration.LogLevel -notin @(
                    'Debug'
                    'Verbose'
                    'Info'
                    'Warning'
                    'Error'
                )
            ) {
                $configuration.LogLevel = 'Info'
            }

            [int]$maximumLogFiles = 0

            if (
                -not [int]::TryParse(
                    [string]$configuration.MaximumLogFiles,
                    [ref]$maximumLogFiles
                ) -or
                $maximumLogFiles -lt 1 -or
                $maximumLogFiles -gt 1000
            ) {
                $maximumLogFiles = 20
            }

            $configuration.MaximumLogFiles =
                $maximumLogFiles

            if (
                [string]::IsNullOrWhiteSpace(
                    [string]$configuration.Provider
                )
            ) {
                $configuration.Provider = 'WinGet'
            }

            if ($configuration.OfflineMode -isnot [bool]) {
                $configuration.OfflineMode = $false
            }

            return $configuration
        }

        $settingsDefaults = [pscustomobject][ordered]@{
            Version                 = '0.1.5'
            MaxParallelJobs         = 4
            AutoReboot              = $true
            PreferredPackageManager = 'Auto'
            OfflineMode             = $false
            LogLevel                = 'Info'
            CachePath               = 'Cache'
            DriverPath              = 'Drivers'
        }

        $normalizeSettings = {
            param($configuration)

            $configuration.Version = '0.1.5'

            [int]$maximumJobs = 0

            if (
                -not [int]::TryParse(
                    [string]$configuration.MaxParallelJobs,
                    [ref]$maximumJobs
                ) -or
                $maximumJobs -lt 1 -or
                $maximumJobs -gt 64
            ) {
                $maximumJobs = 4
            }

            $configuration.MaxParallelJobs = $maximumJobs

            foreach (
                $booleanName in @(
                    'AutoReboot'
                    'OfflineMode'
                )
            ) {
                if ($configuration.$booleanName -isnot [bool]) {
                    $configuration.$booleanName =
                        $settingsDefaults.$booleanName
                }
            }

            foreach (
                $textName in @(
                    'PreferredPackageManager'
                    'LogLevel'
                    'CachePath'
                    'DriverPath'
                )
            ) {
                if (
                    [string]::IsNullOrWhiteSpace(
                        [string]$configuration.$textName
                    )
                ) {
                    $configuration.$textName =
                        $settingsDefaults.$textName
                }
            }

            return $configuration
        }.GetNewClosure()

        $uiDefaults =
            New-PhoenixUiDefaultConfiguration

        $normalizeUi = {
            param($configuration)

            $configuration.SchemaVersion = '2.0'

            if (
                [string]::IsNullOrWhiteSpace(
                    [string]$configuration.ThemeId
                )
            ) {
                $configuration.ThemeId = 'phoenix-dark'
            }

            foreach (
                $colorName in @(
                    'Background'
                    'Surface'
                    'SurfaceAlt'
                    'Card'
                    'Border'
                    'Text'
                    'MutedText'
                    'Accent'
                    'AccentHover'
                    'Success'
                    'Warning'
                    'Danger'
                )
            ) {
                if (
                    [string]$configuration.Appearance.$colorName -notmatch
                    '^#[0-9A-Fa-f]{6}(?:[0-9A-Fa-f]{2})?$'
                ) {
                    $configuration.Appearance.$colorName =
                        $uiDefaults.Appearance.$colorName
                }
            }

            return $configuration
        }.GetNewClosure()

        foreach (
            $configurationDefinition in @(
                [pscustomobject]@{
                    Path = Join-Path `
                        $resolvedProjectRoot `
                        'Config\Phoenix.json'

                    Defaults  = $phoenixDefaults
                    Normalize = $normalizePhoenix
                }
                [pscustomobject]@{
                    Path = Join-Path `
                        $resolvedProjectRoot `
                        'Config\Settings.json'

                    Defaults  = $settingsDefaults
                    Normalize = $normalizeSettings
                }
                [pscustomobject]@{
                    Path = Join-Path `
                        $resolvedProjectRoot `
                        'Config\Phoenix.UI.json'

                    Defaults  = $uiDefaults
                    Normalize = $normalizeUi
                }
            )
        ) {
            $repair =
                Repair-PhoenixJsonConfiguration `
                    -Path $configurationDefinition.Path `
                    -Defaults $configurationDefinition.Defaults `
                    -RecoveryRoot $configurationRecoveryRoot `
                    -Normalize $configurationDefinition.Normalize

            if ($repair.Changed) {
                $repairedFiles.Add($repair)

                if (
                    -not [string]::IsNullOrWhiteSpace(
                        [string]$repair.BackupPath
                    )
                ) {
                    $backups.Add(
                        [string]$repair.BackupPath
                    )
                }
            }
        }

        [bool]$recovered = (
            $createdDirectories.Count -gt 0 -or
            $repairedFiles.Count -gt 0
        )

        [datetime]$completedAtUtc =
            (Get-Date).ToUniversalTime()

        if ($recovered) {
            [string]$code =
                'PHX_RUNTIME_RECOVERED'

            $lastRecovery = [pscustomobject]@{
                SchemaVersion         = '1.0'
                Code                  = $code
                ProjectRoot           = $resolvedProjectRoot
                StartedAtUtc          = $startedAtUtc
                CompletedAtUtc        = $completedAtUtc
                CreatedDirectoryCount = $createdDirectories.Count
                RepairedFileCount     = $repairedFiles.Count
                BackupCount           = $backups.Count
                CreatedDirectories    = @($createdDirectories)
                RepairedFiles         = @($repairedFiles)
                Backups               = @($backups)
            }

            Write-PhoenixRecoveryJson `
                -Path $journalPath `
                -InputObject $lastRecovery
        }
        else {
            [string]$code =
                'PHX_RUNTIME_READY'
        }

        [string]$message =
            if ($recovered) {
                (
                    'Phoenix runtime recovery completed: ' +
                    "$($createdDirectories.Count) directories created, " +
                    "$($repairedFiles.Count) configuration files repaired."
                )
            }
            else {
                'Phoenix runtime directories and configuration are ready.'
            }

        return [pscustomobject]@{
            Success            = $true
            Code               = $code
            Message            = $message
            Recovered          = $recovered
            ProjectRoot        = $resolvedProjectRoot
            StartedAtUtc       = $startedAtUtc
            CompletedAtUtc     = $completedAtUtc
            CreatedDirectories = @($createdDirectories)
            RepairedFiles      = @($repairedFiles)
            Backups            = @($backups)
            Warnings           = @($warnings)
            Errors             = @($errors)
            JournalPath        = $journalPath
            LastRecovery       = $lastRecovery
        }
    }
    catch {
        $errors.Add($_.Exception.Message)

        return [pscustomobject]@{
            Success            = $false
            Code               = 'PHX_RUNTIME_RECOVERY_FAILED'
            Message            = (
                'Phoenix runtime recovery failed: {0}' -f
                $_.Exception.Message
            )
            Recovered          = $false
            ProjectRoot        = $resolvedProjectRoot
            StartedAtUtc       = $startedAtUtc
            CompletedAtUtc     = (Get-Date).ToUniversalTime()
            CreatedDirectories = @($createdDirectories)
            RepairedFiles      = @($repairedFiles)
            Backups            = @($backups)
            Warnings           = @($warnings)
            Errors             = @($errors)
            JournalPath        = $journalPath
            LastRecovery       = $lastRecovery
        }
    }
}
