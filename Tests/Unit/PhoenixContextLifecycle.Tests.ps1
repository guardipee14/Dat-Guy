BeforeAll {

    $projectRoot = (
        Resolve-Path (
            Join-Path `
                $PSScriptRoot `
                '..\..'
        )
    ).Path

    Import-Module `
        -Name (
            Join-Path `
                $projectRoot `
                'Phoenix.psd1'
        ) `
        -Force `
        -ErrorAction Stop `
        6>$null
}

AfterAll {
    Remove-Module `
        -Name Phoenix `
        -Force `
        -ErrorAction SilentlyContinue
}

Describe 'Phoenix context lifecycle' -Tag @(
    'Unit'
    'Lifecycle'
) {

    BeforeEach {
        InModuleScope Phoenix {
            $script:PhoenixContext = $null
            $script:PhoenixContextGeneration = 0
            $script:PhoenixLastInitializationError = ''

            Mock Install-MissingProviders {}
            Mock Write-PhoenixLog {}
        }
    }

    It 'returns null safely before Phoenix is started' {
        InModuleScope Phoenix {
            $context = Get-PhoenixContext

            ($null -eq $context) |
                Should-BeTrue
        }
    }

    It 'publishes a ready initialized context' {
        InModuleScope Phoenix {
            $null = Start-Phoenix

            $context =
                Get-PhoenixContext `
                    -RequireInitialized

            $context.IsInitialized |
                Should-BeTrue

            $context.LifecycleState |
                Should-Be 'Ready'

            $context.Generation |
                Should-Be 1

            $context.Version |
                Should-Be '0.1.3'

            ($context.InitializedAtUtc -gt [datetime]::MinValue) |
                Should-BeTrue
        }
    }

    It 'reuses one context during repeated starts' {
        InModuleScope Phoenix {
            $null = Start-Phoenix
            $firstContext = Get-PhoenixContext

            $null = Start-Phoenix
            $secondContext = Get-PhoenixContext

            $secondContext.SessionID |
                Should-Be $firstContext.SessionID

            $secondContext.Generation |
                Should-Be $firstContext.Generation

            $secondContext.Providers.Count |
                Should-Be $firstContext.Providers.Count
        }
    }

    It 'creates a new generation only when forced' {
        InModuleScope Phoenix {
            $null = Start-Phoenix
            $firstContext = Get-PhoenixContext

            $null =
                Start-Phoenix `
                    -Force

            $secondContext = Get-PhoenixContext

            ($secondContext.SessionID -ne $firstContext.SessionID) |
                Should-BeTrue

            $secondContext.Generation |
                Should-Be 2
        }
    }

    It 'records an elevated-process resume' {
        InModuleScope Phoenix {
            $null =
                Start-Phoenix `
                    -Resume

            $context = Get-PhoenixContext

            $context.IsResumed |
                Should-BeTrue

            $context.LifecycleState |
                Should-Be 'Ready'
        }
    }

    It 'keeps the previous ready context when forced initialization fails' {
        InModuleScope Phoenix {
            $null = Start-Phoenix
            $readyContext = Get-PhoenixContext

            Mock Initialize-PhoenixProviders {
                throw 'Simulated provider initialization failure.'
            }

            $capturedError = $null

            try {
                $null =
                    Start-Phoenix `
                        -Force `
                        -ErrorAction Stop
            }
            catch {
                $capturedError = $_
            }

            ($null -ne $capturedError) |
                Should-BeTrue

            $restoredContext = Get-PhoenixContext

            $restoredContext.SessionID |
                Should-Be $readyContext.SessionID

            $restoredContext.LifecycleState |
                Should-Be 'Ready'
        }
    }

    It 'recovers automatically from an incomplete context' {
        InModuleScope Phoenix {
            $moduleRoot =
                Split-Path `
                    -Path (
                        Get-Module `
                            -Name Phoenix
                    ).Path `
                    -Parent

            $script:PhoenixContext =
                [PhoenixContext]::new(
                    $moduleRoot
                )

            $script:PhoenixContext.LifecycleState |
                Should-Be 'Created'

            $resolvedContext =
                Resolve-PhoenixContext

            $resolvedContext.LifecycleState |
                Should-Be 'Ready'

            $resolvedContext.IsInitialized |
                Should-BeTrue
        }
    }
}
