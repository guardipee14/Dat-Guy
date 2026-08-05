BeforeAll {
    $projectRoot =
        (
            Resolve-Path `
                (Join-Path $PSScriptRoot '..\..')
        ).Path

    Import-Module `
        (Join-Path $projectRoot 'Phoenix.psd1') `
        -Force `
        6>$null
}

AfterAll {
    Remove-Module `
        Phoenix `
        -Force `
        -ErrorAction SilentlyContinue
}

Describe 'Phoenix deployment contracts' -Tag @(
    'Unit'
    'Deployment'
    'Contract'
) {
    It 'defines stable deployment lifecycle operations' {
        InModuleScope Phoenix {
            [int][PhoenixDeploymentOperation]::Unknown |
                Should-Be 0

            [int][PhoenixDeploymentOperation]::Discover |
                Should-Be 1

            [int][PhoenixDeploymentOperation]::Plan |
                Should-Be 2

            [int][PhoenixDeploymentOperation]::Acquire |
                Should-Be 3

            [int][PhoenixDeploymentOperation]::Verify |
                Should-Be 4

            [int][PhoenixDeploymentOperation]::Mount |
                Should-Be 5

            [int][PhoenixDeploymentOperation]::Service |
                Should-Be 6

            [int][PhoenixDeploymentOperation]::WriteMedia |
                Should-Be 7

            [int][PhoenixDeploymentOperation]::Deploy |
                Should-Be 8

            [int][PhoenixDeploymentOperation]::Cleanup |
                Should-Be 9

            [int][PhoenixDeploymentOperation]::Reboot |
                Should-Be 10
        }
    }

    It 'reports capability readiness only when supported and available' {
        InModuleScope Phoenix {
            $capability =
                [PhoenixDeploymentCapability]::new()

            $capability.IsReady() |
                Should-BeFalse

            $capability.Supported = $true

            $capability.IsReady() |
                Should-BeFalse

            $capability.Available = $true

            $capability.IsReady() |
                Should-BeTrue
        }
    }

    It 'blocks an unevaluated deployment decision by default' {
        InModuleScope Phoenix {
            $decision =
                [PhoenixDeploymentDecision]::new()

            $decision.IsAllowed() |
                Should-BeFalse

            $decision.Code |
                Should-Be 'PHX_DEPLOYMENT_NOT_EVALUATED'
        }
    }

    It 'allows an eligible safe and available decision' {
        InModuleScope Phoenix {
            $decision =
                [PhoenixDeploymentDecision]::new()

            $decision.Supported = $true
            $decision.Available = $true
            $decision.Eligible = $true
            $decision.Safe = $true
            $decision.Code = 'PHX_DEPLOYMENT_ALLOWED'
            $decision.Reason = 'Deployment is allowed.'

            $decision.IsAllowed() |
                Should-BeTrue
        }
    }

    It 'requires explicit approval for protected targets' {
        InModuleScope Phoenix {
            $decision =
                [PhoenixDeploymentDecision]::new()

            $decision.Supported = $true
            $decision.Available = $true
            $decision.Eligible = $true
            $decision.Safe = $true
            $decision.Protected = $true
            $decision.RequiresApproval = $true

            $decision.IsAllowed() |
                Should-BeFalse

            $decision.ApprovalGranted = $true

            $decision.IsAllowed() |
                Should-BeTrue
        }
    }

    It 'requires confirmed target identity when requested' {
        InModuleScope Phoenix {
            $decision =
                [PhoenixDeploymentDecision]::new()

            $decision.Supported = $true
            $decision.Available = $true
            $decision.Eligible = $true
            $decision.Safe = $true
            $decision.RequiresTargetIdentity = $true

            $decision.IsAllowed() |
                Should-BeFalse

            $decision.TargetIdentityConfirmed = $true

            $decision.IsAllowed() |
                Should-BeTrue
        }
    }

    It 'requires an available elevation path when elevation is needed' {
        InModuleScope Phoenix {
            $decision =
                [PhoenixDeploymentDecision]::new()

            $decision.Supported = $true
            $decision.Available = $true
            $decision.Eligible = $true
            $decision.Safe = $true
            $decision.RequiresElevation = $true

            $decision.IsAllowed() |
                Should-BeFalse

            $decision.CanElevate = $true

            $decision.IsAllowed() |
                Should-BeTrue
        }
    }

    It 'completes a successful deployment result with timing metadata' {
        InModuleScope Phoenix {
            $result =
                [PhoenixDeploymentResult]::new()

            $result.IsComplete() |
                Should-BeFalse

            $result.Complete(
                $true,
                'PHX_DEPLOYMENT_SUCCEEDED',
                'Deployment completed.'
            )

            $result.Success |
                Should-BeTrue

            $result.Code |
                Should-Be 'PHX_DEPLOYMENT_SUCCEEDED'

            $result.IsComplete() |
                Should-BeTrue

            ($result.Duration -ge [timespan]::Zero) |
                Should-BeTrue
        }
    }

    It 'adds a failure message to an empty error collection' {
        InModuleScope Phoenix {
            $result =
                [PhoenixDeploymentResult]::new()

            $result.Complete(
                $false,
                'PHX_DEPLOYMENT_FAILED',
                'Deployment failed.'
            )

            $result.Success |
                Should-BeFalse

            $result.Errors.Count |
                Should-Be 1

            $result.Errors[0] |
                Should-Be 'Deployment failed.'
        }
    }
}

Describe 'Resolve-PhoenixDeploymentDecision' -Tag @(
    'Unit'
    'Deployment'
    'Safety'
) {
    It 'allows a non-mutating supported available operation' {
        InModuleScope Phoenix {
            $capability =
                [PhoenixDeploymentCapability]::new()

            $capability.Name = 'Discovery'
            $capability.Operation =
                [PhoenixDeploymentOperation]::Discover
            $capability.Supported = $true
            $capability.Available = $true

            $decision =
                Resolve-PhoenixDeploymentDecision `
                    -Capability $capability `
                    -CurrentPrivilege User

            $decision.Code |
                Should-Be 'PHX_DEPLOYMENT_ALLOWED'

            $decision.IsAllowed() |
                Should-BeTrue
        }
    }

    It 'blocks a mutating operation without ShouldProcess support' {
        InModuleScope Phoenix {
            $capability =
                [PhoenixDeploymentCapability]::new()

            $capability.Name = 'Unsafe mutation'
            $capability.Operation =
                [PhoenixDeploymentOperation]::Service
            $capability.Supported = $true
            $capability.Available = $true
            $capability.IsMutating = $true

            $decision =
                Resolve-PhoenixDeploymentDecision `
                    -Capability $capability `
                    -CurrentPrivilege Administrator

            $decision.Code |
                Should-Be 'PHX_DEPLOYMENT_SHOULD_PROCESS_REQUIRED'

            $decision.Safe |
                Should-BeFalse
        }
    }

    It 'blocks exclusive work without a concurrency key' {
        InModuleScope Phoenix {
            $capability =
                [PhoenixDeploymentCapability]::new()

            $capability.Name = 'Mounted image servicing'
            $capability.Operation =
                [PhoenixDeploymentOperation]::Service
            $capability.Supported = $true
            $capability.Available = $true
            $capability.RequiresExclusiveAccess = $true

            $decision =
                Resolve-PhoenixDeploymentDecision `
                    -Capability $capability `
                    -CurrentPrivilege Administrator

            $decision.Code |
                Should-Be 'PHX_DEPLOYMENT_CONCURRENCY_KEY_REQUIRED'

            $decision.IsAllowed() |
                Should-BeFalse
        }
    }

    It 'requires confirmed identity for a destructive target' {
        InModuleScope Phoenix {
            $capability =
                [PhoenixDeploymentCapability]::new()

            $capability.Name = 'Media writer'
            $capability.Operation =
                [PhoenixDeploymentOperation]::WriteMedia
            $capability.Supported = $true
            $capability.Available = $true
            $capability.IsMutating = $true
            $capability.IsDestructive = $true
            $capability.SupportsShouldProcess = $true

            $decision =
                Resolve-PhoenixDeploymentDecision `
                    -Capability $capability `
                    -Target 'Disk 3' `
                    -CurrentPrivilege Administrator `
                    -ApprovalGranted

            $decision.Code |
                Should-Be 'PHX_DEPLOYMENT_TARGET_IDENTITY_REQUIRED'

            $decision.IsAllowed() |
                Should-BeFalse
        }
    }

    It 'requires approval for a protected target' {
        InModuleScope Phoenix {
            $capability =
                [PhoenixDeploymentCapability]::new()

            $capability.Name = 'Protected cleanup'
            $capability.Operation =
                [PhoenixDeploymentOperation]::Cleanup
            $capability.Supported = $true
            $capability.Available = $true

            $decision =
                Resolve-PhoenixDeploymentDecision `
                    -Capability $capability `
                    -Target 'Phoenix workspace' `
                    -CurrentPrivilege User `
                    -Protected

            $decision.Code |
                Should-Be 'PHX_DEPLOYMENT_APPROVAL_REQUIRED'

            $decision.Protected |
                Should-BeTrue

            $decision.IsAllowed() |
                Should-BeFalse
        }
    }

    It 'permits a fully confirmed destructive operation' {
        InModuleScope Phoenix {
            $capability =
                [PhoenixDeploymentCapability]::new()

            $capability.Name = 'Media writer'
            $capability.Operation =
                [PhoenixDeploymentOperation]::WriteMedia
            $capability.Supported = $true
            $capability.Available = $true
            $capability.IsMutating = $true
            $capability.IsDestructive = $true
            $capability.SupportsShouldProcess = $true
            $capability.RequiredPrivilege =
                [PhoenixPrivilegeLevel]::Administrator

            $decision =
                Resolve-PhoenixDeploymentDecision `
                    -Capability $capability `
                    -Target 'Disk 3' `
                    -CurrentPrivilege Administrator `
                    -TargetIdentityConfirmed `
                    -ApprovalGranted

            $decision.Code |
                Should-Be 'PHX_DEPLOYMENT_ALLOWED'

            $decision.IsAllowed() |
                Should-BeTrue
        }
    }

    It 'distinguishes required elevation from unavailable elevation' {
        InModuleScope Phoenix {
            $capability =
                [PhoenixDeploymentCapability]::new()

            $capability.Name = 'Image servicing'
            $capability.Operation =
                [PhoenixDeploymentOperation]::Service
            $capability.Supported = $true
            $capability.Available = $true
            $capability.RequiredPrivilege =
                [PhoenixPrivilegeLevel]::Administrator

            $blocked =
                Resolve-PhoenixDeploymentDecision `
                    -Capability $capability `
                    -CurrentPrivilege User

            $elevatable =
                Resolve-PhoenixDeploymentDecision `
                    -Capability $capability `
                    -CurrentPrivilege User `
                    -CanElevate

            $blocked.Code |
                Should-Be 'PHX_DEPLOYMENT_ELEVATION_UNAVAILABLE'

            $blocked.IsAllowed() |
                Should-BeFalse

            $elevatable.Code |
                Should-Be 'PHX_DEPLOYMENT_ELEVATION_REQUIRED'

            $elevatable.IsAllowed() |
                Should-BeTrue
        }
    }
}
