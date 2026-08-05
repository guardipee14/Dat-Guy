function Resolve-PhoenixDeploymentDecision {

    [CmdletBinding()]
    [OutputType([PhoenixDeploymentDecision])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PhoenixDeploymentCapability]$Capability,

        [Parameter()]
        [AllowEmptyString()]
        [string]$Target = '',

        [Parameter(Mandatory)]
        [PhoenixPrivilegeLevel]$CurrentPrivilege,

        [Parameter()]
        [bool]$Eligible = $true,

        [Parameter()]
        [switch]$Protected,

        [Parameter()]
        [switch]$ApprovalGranted,

        [Parameter()]
        [switch]$TargetIdentityConfirmed,

        [Parameter()]
        [switch]$CanElevate,

        [Parameter()]
        [AllowEmptyString()]
        [string]$IneligibleReason = '',

        [Parameter()]
        [AllowEmptyCollection()]
        [string[]]$Warnings = @()
    )

    [PhoenixDeploymentDecision]$decision =
        [PhoenixDeploymentDecision]::new()

    $decision.Name = $Capability.Name
    $decision.Operation = $Capability.Operation
    $decision.Target = $Target
    $decision.Supported = $Capability.Supported
    $decision.Available = $Capability.Available
    $decision.Eligible = $Eligible
    $decision.Protected = [bool]$Protected
    $decision.RequiresApproval = (
        $Capability.IsDestructive -or
        [bool]$Protected
    )
    $decision.ApprovalGranted =
        [bool]$ApprovalGranted
    $decision.RequiresTargetIdentity = (
        $Capability.RequiresTargetIdentity -or
        $Capability.IsDestructive
    )
    $decision.TargetIdentityConfirmed =
        [bool]$TargetIdentityConfirmed
    $decision.RequiredPrivilege =
        $Capability.RequiredPrivilege
    $decision.CurrentPrivilege =
        $CurrentPrivilege
    $decision.RequiresElevation = (
        [int]$CurrentPrivilege -lt
        [int]$Capability.RequiredPrivilege
    )
    $decision.CanElevate =
        [bool]$CanElevate
    $decision.Warnings = @(
        $Warnings |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace($_)
            }
    )
    $decision.Safe = $true

    if (-not $Capability.Supported) {
        $decision.Safe = $false
        $decision.Code =
            'PHX_DEPLOYMENT_UNSUPPORTED'
        $decision.Reason = (
            "$($Capability.Operation) is not supported by " +
            "deployment capability '$($Capability.Name)'."
        )
        return $decision
    }

    if (-not $Capability.Available) {
        $decision.Safe = $false
        $decision.Code =
            'PHX_DEPLOYMENT_UNAVAILABLE'
        $decision.Reason = if (
            [string]::IsNullOrWhiteSpace(
                $Capability.Message
            )
        ) {
            (
                "Deployment capability '$($Capability.Name)' " +
                'is unavailable.'
            )
        }
        else {
            $Capability.Message
        }
        return $decision
    }

    if (
        $Capability.IsMutating -and
        -not $Capability.SupportsShouldProcess
    ) {
        $decision.Safe = $false
        $decision.Code =
            'PHX_DEPLOYMENT_SHOULD_PROCESS_REQUIRED'
        $decision.Reason = (
            "Mutating deployment capability '$($Capability.Name)' " +
            'does not declare ShouldProcess support.'
        )
        return $decision
    }

    if (
        $Capability.RequiresExclusiveAccess -and
        [string]::IsNullOrWhiteSpace(
            $Capability.ConcurrencyKey
        )
    ) {
        $decision.Safe = $false
        $decision.Code =
            'PHX_DEPLOYMENT_CONCURRENCY_KEY_REQUIRED'
        $decision.Reason = (
            "Deployment capability '$($Capability.Name)' requires " +
            'exclusive access but has no concurrency key.'
        )
        return $decision
    }

    if (-not $Eligible) {
        $decision.Safe = $false
        $decision.Code =
            'PHX_DEPLOYMENT_INELIGIBLE'
        $decision.Reason = if (
            [string]::IsNullOrWhiteSpace(
                $IneligibleReason
            )
        ) {
            'The deployment target is not eligible for this operation.'
        }
        else {
            $IneligibleReason
        }
        return $decision
    }

    if (
        $decision.RequiresTargetIdentity -and
        [string]::IsNullOrWhiteSpace($Target)
    ) {
        $decision.Safe = $false
        $decision.Code =
            'PHX_DEPLOYMENT_TARGET_REQUIRED'
        $decision.Reason = (
            'An exact deployment target is required before this ' +
            'operation can be evaluated.'
        )
        return $decision
    }

    if (
        $decision.RequiresTargetIdentity -and
        -not $decision.TargetIdentityConfirmed
    ) {
        $decision.Code =
            'PHX_DEPLOYMENT_TARGET_IDENTITY_REQUIRED'
        $decision.Reason = (
            "The identity of deployment target '$Target' must be " +
            'confirmed before this operation can continue.'
        )
        return $decision
    }

    if (
        $decision.RequiresApproval -and
        -not $decision.ApprovalGranted
    ) {
        $decision.Code =
            'PHX_DEPLOYMENT_APPROVAL_REQUIRED'
        $decision.Reason = if ($decision.Protected) {
            (
                "Protected deployment target '$Target' requires " +
                'explicit approval.'
            )
        }
        else {
            (
                "Destructive deployment operation '$($Capability.Operation)' " +
                'requires explicit approval.'
            )
        }
        return $decision
    }

    if (
        $decision.RequiresElevation -and
        -not $decision.CanElevate
    ) {
        $decision.Code =
            'PHX_DEPLOYMENT_ELEVATION_UNAVAILABLE'
        $decision.Reason = (
            "$($Capability.RequiredPrivilege) privilege is required, " +
            'but no approved elevation path is available.'
        )
        return $decision
    }

    if ($decision.RequiresElevation) {
        $decision.Code =
            'PHX_DEPLOYMENT_ELEVATION_REQUIRED'
        $decision.Reason = (
            "$($Capability.RequiredPrivilege) privilege is required. " +
            'The operation may continue through the approved elevation path.'
        )
        return $decision
    }

    $decision.Code =
        'PHX_DEPLOYMENT_ALLOWED'
    $decision.Reason =
        'The deployment operation is allowed under the current policy.'

    return $decision
}
