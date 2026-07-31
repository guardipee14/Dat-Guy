function Initialize-Phoenix {

    [CmdletBinding()]
    [OutputType([PhoenixContext])]
    param(
        [Parameter()]
        [switch]$Resume,

        [Parameter()]
        [switch]$Force
    )

    [string]$projectRoot =
        Split-Path `
            -Path $PSScriptRoot `
            -Parent

    $projectRoot =
        Split-Path `
            -Path $projectRoot `
            -Parent

    $currentContext =
        Get-PhoenixContext

    $candidate = $null

    try {
        $runtimeRecovery =
            Initialize-PhoenixRuntimeRecovery `
                -ProjectRoot $projectRoot

        if (-not $runtimeRecovery.Success) {
            throw $runtimeRecovery.Message
        }

        if (
            -not $Force -and
            (
                Test-PhoenixContext `
                    -Context $currentContext
            )
        ) {
            $currentContext.RuntimeRecovery =
                $runtimeRecovery

            foreach (
                $recoveryWarning in @(
                    $runtimeRecovery.Warnings
                )
            ) {
                if (
                    -not [string]::IsNullOrWhiteSpace(
                        [string]$recoveryWarning
                    ) -and
                    -not $currentContext.InitializationWarnings.Contains(
                        [string]$recoveryWarning
                    )
                ) {
                    $currentContext.InitializationWarnings.Add(
                        [string]$recoveryWarning
                    )
                }
            }

            return $currentContext
        }

        $candidate =
            [PhoenixContext]::new(
                $projectRoot
            )

        $candidate.LifecycleState = 'Initializing'
        $candidate.IsResumed = [bool]$Resume
        $candidate.Generation =
            $script:PhoenixContextGeneration + 1
        $candidate.RuntimeRecovery =
            $runtimeRecovery

        foreach (
            $recoveryWarning in @(
                $runtimeRecovery.Warnings
            )
        ) {
            if (
                -not [string]::IsNullOrWhiteSpace(
                    [string]$recoveryWarning
                )
            ) {
                $candidate.InitializationWarnings.Add(
                    [string]$recoveryWarning
                )
            }
        }

        $phoenixModule =
            Get-Module `
                -Name Phoenix |
                Select-Object -First 1

        if ($null -ne $phoenixModule) {
            $candidate.Version =
                $phoenixModule.Version.ToString()
        }

        Initialize-PhoenixConfiguration `
            -Context $candidate

        Initialize-PhoenixProviders `
            -Context $candidate

        Initialize-PhoenixLogging `
            -Context $candidate

        $candidate.InitializedAtUtc =
            (Get-Date).ToUniversalTime()

        $candidate.InitializationError = ''
        $candidate.IsInitialized = $true
        $candidate.LifecycleState = 'Ready'

        $script:PhoenixContext = $candidate
        $script:PhoenixContextGeneration =
            $candidate.Generation

        $script:PhoenixLastInitializationError = ''

        return $candidate
    }
    catch {

        [string]$initializationError =
            $_.Exception.Message

        if ($null -ne $candidate) {
            $candidate.InitializationError =
                $initializationError

            $candidate.IsInitialized = $false
            $candidate.LifecycleState = 'Failed'
        }

        $script:PhoenixLastInitializationError =
            $initializationError

        $script:PhoenixContext = $currentContext

        throw (
            'Phoenix initialization failed: {0}' -f
            $initializationError
        )
    }
}
