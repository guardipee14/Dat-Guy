function Initialize-Phoenix {

    [CmdletBinding()]
    [OutputType([PhoenixContext])]
    param(
        [Parameter()]
        [switch]$Resume,

        [Parameter()]
        [switch]$Force
    )

    $currentContext =
        Get-PhoenixContext

    if (
        -not $Force -and
        (
            Test-PhoenixContext `
                -Context $currentContext
        )
    ) {
        return $currentContext
    }

    [string]$projectRoot =
        Split-Path `
            -Path $PSScriptRoot `
            -Parent

    $projectRoot =
        Split-Path `
            -Path $projectRoot `
            -Parent

    $candidate = $null

    try {
        $candidate =
            [PhoenixContext]::new(
                $projectRoot
            )

        $candidate.LifecycleState = 'Initializing'
        $candidate.IsResumed = [bool]$Resume
        $candidate.Generation =
            $script:PhoenixContextGeneration + 1

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
