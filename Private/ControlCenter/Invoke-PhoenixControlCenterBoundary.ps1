function New-PhoenixControlCenterFailure {

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Component,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Operation,

        [Parameter()]
        [AllowNull()]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,

        [Parameter()]
        [AllowNull()]
        [System.Exception]$Exception,

        [Parameter()]
        [AllowEmptyString()]
        [string]$Message = '',

        [Parameter()]
        [switch]$Startup
    )

    if (
        $null -eq $Exception -and
        $null -ne $ErrorRecord
    ) {
        $Exception = $ErrorRecord.Exception
    }

    if ([string]::IsNullOrWhiteSpace($Message)) {
        $Message = if ($null -ne $Exception) {
            $Exception.Message
        }
        else {
            'An unknown Control Center error occurred.'
        }
    }

    [string]$exceptionType = ''
    [string]$scriptStackTrace = ''
    [string]$positionMessage = ''

    if ($null -ne $Exception) {
        $exceptionType = $Exception.GetType().FullName
    }

    if ($null -ne $ErrorRecord) {
        $scriptStackTrace =
            [string]$ErrorRecord.ScriptStackTrace

        if ($null -ne $ErrorRecord.InvocationInfo) {
            $positionMessage =
                [string]$ErrorRecord.InvocationInfo.PositionMessage
        }
    }

    [string]$failureId =
        [guid]::NewGuid().ToString('N')

    [string]$code = if ($Startup) {
        'PHX_DESKTOP_STARTUP_FAILED'
    }
    else {
        'PHX_UI_COMPONENT_FAILED'
    }

    return [pscustomobject]@{
        Success = $false
        Code    = $code
        Message = (
            "{0} failed during {1}: {2}" -f
            $Component,
            $Operation,
            $Message
        )
        Data    = [pscustomobject]@{
            Stage            = 'ControlCenter'
            FailureId        = $failureId
            TimestampUtc     = [datetime]::UtcNow.ToString('o')
            Component        = $Component
            Operation        = $Operation
            Recoverable      = $true
            Startup          = [bool]$Startup
            ExceptionType    = $exceptionType
            PositionMessage  = $positionMessage
            ScriptStackTrace = $scriptStackTrace
            ThreadId         = (
                [Threading.Thread]::CurrentThread.ManagedThreadId
            )
            JournalPath      = ''
        }
        Errors  = @(
            $Message
        )
    }
}

function Write-PhoenixControlCenterFailure {

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]$Failure,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ProjectRoot = (
            Split-Path `
                -Path (
                    Split-Path `
                        -Path $PSScriptRoot `
                        -Parent
                ) `
                -Parent
        ),

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$RetentionCount = 20
    )

    try {
        [string]$cacheRoot =
            Join-Path `
                $ProjectRoot `
                'Cache\ControlCenter'

        [string]$failureDirectory =
            Join-Path `
                $cacheRoot `
                'Failures'

        New-Item `
            -ItemType Directory `
            -Path $failureDirectory `
            -Force `
            -ErrorAction Stop |
            Out-Null

        [string]$timestamp =
            [datetime]::UtcNow.ToString(
                'yyyyMMdd-HHmmss-fff'
            )

        [string]$failureId =
            [string]$Failure.Data.FailureId

        [string]$failurePath =
            Join-Path `
                $failureDirectory `
                (
                    'PhoenixUiFailure-{0}-{1}.json' -f
                    $timestamp,
                    $failureId.Substring(
                        0,
                        [Math]::Min(
                            8,
                            $failureId.Length
                        )
                    )
                )

        [string]$lastFailurePath =
            Join-Path `
                $cacheRoot `
                'LastFailure.json'

        if (
            $null -ne $Failure.Data.PSObject.Properties[
                'JournalPath'
            ]
        ) {
            $Failure.Data.JournalPath = $lastFailurePath
        }

        foreach (
            $targetPath in @(
                $failurePath
                $lastFailurePath
            )
        ) {
            [string]$temporaryPath = (
                '{0}.{1}.tmp' -f
                $targetPath,
                [guid]::NewGuid().ToString('N')
            )

            try {
                $Failure |
                    ConvertTo-Json `
                        -Depth 20 |
                    Set-Content `
                        -LiteralPath $temporaryPath `
                        -Encoding UTF8 `
                        -ErrorAction Stop

                Move-Item `
                    -LiteralPath $temporaryPath `
                    -Destination $targetPath `
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

        @(
            Get-ChildItem `
                -LiteralPath $failureDirectory `
                -Filter 'PhoenixUiFailure-*.json' `
                -File `
                -ErrorAction SilentlyContinue |
                Sort-Object `
                    -Property LastWriteTimeUtc `
                    -Descending |
                Select-Object `
                    -Skip $RetentionCount
        ) |
            Remove-Item `
                -Force `
                -ErrorAction SilentlyContinue

        try {
            Write-PhoenixLog `
                -Level Error `
                -Message (
                    '[{0}] {1}' -f
                    $Failure.Code,
                    $Failure.Message
                )
        }
        catch {
            # Failure journaling must not fail because logging is unavailable.
        }

        return [pscustomobject]@{
            Success = $true
            Code    = 'PHX_UI_FAILURE_RECORDED'
            Message = 'The Control Center failure was recorded.'
            Data    = [pscustomobject]@{
                Stage           = 'ControlCenterRecovery'
                FailurePath     = $failurePath
                LastFailurePath = $lastFailurePath
                RetentionCount  = $RetentionCount
            }
            Errors  = @()
        }
    }
    catch {
        return [pscustomobject]@{
            Success = $false
            Code    = 'PHX_UI_FAILURE_RECORD_FAILED'
            Message = (
                'The Control Center failure could not be recorded: {0}' -f
                $_.Exception.Message
            )
            Data    = [pscustomobject]@{
                Stage = 'ControlCenterRecovery'
            }
            Errors  = @(
                $_.Exception.Message
            )
        }
    }
}

function Get-PhoenixControlCenterLastFailure {

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ProjectRoot = (
            Split-Path `
                -Path (
                    Split-Path `
                        -Path $PSScriptRoot `
                        -Parent
                ) `
                -Parent
        )
    )

    [string]$lastFailurePath =
        Join-Path `
            $ProjectRoot `
            'Cache\ControlCenter\LastFailure.json'

    if (-not (Test-Path -LiteralPath $lastFailurePath)) {
        return $null
    }

    try {
        return (
            Get-Content `
                -LiteralPath $lastFailurePath `
                -Raw `
                -ErrorAction Stop |
                ConvertFrom-Json `
                    -ErrorAction Stop
        )
    }
    catch {
        return $null
    }
}

function Invoke-PhoenixControlCenterBoundary {

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Component,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Operation,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [scriptblock]$Action,

        [Parameter()]
        [AllowNull()]
        [object[]]$ArgumentList = @(),

        [Parameter()]
        [AllowNull()]
        [scriptblock]$OnFailure,

        [Parameter()]
        [switch]$Startup,

        [Parameter()]
        [switch]$Rethrow
    )

    try {
        $actionResult =
            & $Action @ArgumentList

        return [pscustomobject]@{
            Success = $true
            Code    = 'PHX_UI_COMPONENT_COMPLETE'
            Message = (
                "{0} completed {1}." -f
                $Component,
                $Operation
            )
            Data    = $actionResult
            Errors  = @()
        }
    }
    catch {
        $failure =
            New-PhoenixControlCenterFailure `
                -Component $Component `
                -Operation $Operation `
                -ErrorRecord $_ `
                -Startup:$Startup

        $null =
            Write-PhoenixControlCenterFailure `
                -Failure $failure

        if ($null -ne $OnFailure) {
            try {
                & $OnFailure $failure
            }
            catch {
                # The boundary must not become a second failure source.
            }
        }

        if ($Rethrow) {
            throw
        }

        return $failure
    }
}

function Reset-PhoenixControlCenterUiConfiguration {

    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param()

    [string]$configurationPath =
        Get-PhoenixUiConfigurationPath

    if (
        -not $PSCmdlet.ShouldProcess(
            $configurationPath,
            'Reset Phoenix Control Center layout and appearance'
        )
    ) {
        return [pscustomobject]@{
            Success = $true
            Code    = 'PHX_UI_RESET_SKIPPED'
            Message = 'The Control Center reset was skipped.'
            Data    = [pscustomobject]@{
                Stage = 'ControlCenterRecovery'
                Path  = $configurationPath
            }
            Errors  = @()
        }
    }

    [string]$backupPath = ''

    if (Test-Path -LiteralPath $configurationPath) {
        [string]$recoveryDirectory =
            Join-Path `
                (
                    Split-Path `
                        -Path $configurationPath `
                        -Parent
                ) `
                'Recovery'

        New-Item `
            -ItemType Directory `
            -Path $recoveryDirectory `
            -Force `
            -ErrorAction Stop |
            Out-Null

        $backupPath =
            Join-Path `
                $recoveryDirectory `
                (
                    'Phoenix.UI.desktop-recovery-{0}.json' -f
                    [datetime]::UtcNow.ToString(
                        'yyyyMMdd-HHmmss-fff'
                    )
                )

        Copy-Item `
            -LiteralPath $configurationPath `
            -Destination $backupPath `
            -Force `
            -ErrorAction Stop
    }

    $defaults =
        New-PhoenixUiDefaultConfiguration

    [string]$savedPath =
        Save-PhoenixUiConfiguration `
            -Configuration $defaults `
            -Confirm:$false

    return [pscustomobject]@{
        Success = $true
        Code    = 'PHX_UI_RESET_COMPLETE'
        Message = (
            'The Control Center layout and appearance were reset safely.'
        )
        Data    = [pscustomobject]@{
            Stage      = 'ControlCenterRecovery'
            Path       = $savedPath
            BackupPath = $backupPath
        }
        Errors  = @()
    }
}
