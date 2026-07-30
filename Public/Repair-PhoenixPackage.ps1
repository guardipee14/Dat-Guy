using module '..\Classes\Phoenix.Classes.psm1'

function Repair-PhoenixPackage {

    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'Medium',
        DefaultParameterSetName = 'ById'
    )]
    [OutputType([Result])]
    param(
        [Parameter(
            Mandatory,
            Position = 0,
            ParameterSetName = 'ById'
        )]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ParameterSetName = 'ByPackage'
        )]
        [ValidateNotNull()]
        [Package]$Package,

        [Parameter(
            Mandatory,
            ParameterSetName = 'ById'
        )]
        [Parameter(
            ParameterSetName = 'ByPackage'
        )]
        [ValidateSet(
            'WinGet',
            'Chocolatey'
        )]
        [string]$Provider,

        [Parameter()]
        [PhoenixInstallMode]$Mode =
            [PhoenixInstallMode]::SilentPreferred,

        [Parameter()]
        [switch]$PreserveDownloads
    )

    process {

        ##########################################################
        ## Ensure Phoenix is initialized
        ##########################################################

        try {
            $context =
                Resolve-PhoenixContext `
                    -ErrorAction Stop
        }
        catch {

            [Result]$initializationResult =
                [Result]::Failure(
                    "Phoenix initialization failed: $($_.Exception.Message)"
                )

            $initializationResult.Code =
                'PHX_INITIALIZATION_FAILED'

            return $initializationResult
        }

        if ($null -eq $context) {

            [Result]$contextResult =
                [Result]::Failure(
                    'Phoenix context is unavailable.'
                )

            $contextResult.Code =
                'PHX_CONTEXT_UNAVAILABLE'

            return $contextResult
        }

        ##########################################################
        ## Resolve the package
        ##########################################################

        [Package]$resolvedPackage = $null
        [string]$providerName = ''

        if ($PSCmdlet.ParameterSetName -eq 'ById') {

            $resolvedPackage = [Package]::new()

            $resolvedPackage.Id = $Id
            $resolvedPackage.Name = $Id
            $resolvedPackage.Provider = $Provider

            $providerName = $Provider
        }
        else {

            $resolvedPackage = $Package

            if (
                -not [string]::IsNullOrWhiteSpace(
                    $Provider
                )
            ) {

                $resolvedPackage.Provider =
                    $Provider
            }

            $providerName =
                $resolvedPackage.Provider
        }

        if ($null -eq $resolvedPackage) {

            [Result]$packageResult =
                [Result]::Failure(
                    'A package object is required.'
                )

            $packageResult.Code =
                'PHX_INVALID_PACKAGE'

            return $packageResult
        }

        if (
            [string]::IsNullOrWhiteSpace(
                $resolvedPackage.Id
            )
        ) {

            [Result]$packageIdResult =
                [Result]::Failure(
                    'The package ID is required.'
                )

            $packageIdResult.Code =
                'PHX_INVALID_PACKAGE'

            return $packageIdResult
        }

        if (
            [string]::IsNullOrWhiteSpace(
                $resolvedPackage.Name
            )
        ) {

            $resolvedPackage.Name =
                $resolvedPackage.Id
        }

        if (
            [string]::IsNullOrWhiteSpace(
                $providerName
            )
        ) {

            [Result]$providerNameResult =
                [Result]::Failure(
                    'A package provider is required.'
                )

            $providerNameResult.Code =
                'PHX_PROVIDER_REQUIRED'

            return $providerNameResult
        }

        if ($PreserveDownloads) {

            $resolvedPackage.PreserveDownloads =
                $true
        }

        ##########################################################
        ## Resolve the provider
        ##########################################################

        [PhoenixProvider]$resolvedProvider = @(
            $context.Providers |
                Where-Object {
                    $_.Name -ieq $providerName
                } |
                Sort-Object Priority -Descending
        ) |
            Select-Object -First 1

        if ($null -eq $resolvedProvider) {

            [Result]$providerResult =
                [Result]::Failure(
                    "Phoenix provider '$providerName' was not found."
                )

            $providerResult.Code =
                'PHX_PROVIDER_NOT_FOUND'

            return $providerResult
        }

        if (-not $resolvedProvider.Available) {

            [Result]$availabilityResult =
                [Result]::Failure(
                    "Phoenix provider '$($resolvedProvider.Name)' is unavailable."
                )

            $availabilityResult.Code =
                'PHX_PROVIDER_UNAVAILABLE'

            return $availabilityResult
        }

        if (-not $resolvedProvider.SupportsRepair) {

            [Result]$supportResult =
                [Result]::Failure(
                    "$($resolvedProvider.Name) does not support package repair."
                )

            $supportResult.Code =
                'PHX_REPAIR_UNAVAILABLE'

            return $supportResult
        }

        ##########################################################
        ## WhatIf / confirmation
        ##########################################################

        [string]$target = (
            "{0} package '{1}'" -f
            $resolvedProvider.Name,
            $resolvedPackage.Id
        )

        [string]$operation = (
            "Repair using mode '$Mode'"
        )

        if (
            -not $PSCmdlet.ShouldProcess(
                $target,
                $operation
            )
        ) {

            [Result]$skippedResult =
                [Result]::Success()

            $skippedResult.Message =
                "Repair was skipped for '$($resolvedPackage.Id)'."

            $skippedResult.Code =
                'PHX_REPAIR_SKIPPED'

            $skippedResult.Data =
                $resolvedPackage

            return $skippedResult
        }

        ##########################################################
        ## Privilege check
        ##########################################################

        if (
    -not (
        Test-PhoenixPrivilege `
            -RequiredPrivilege $resolvedProvider.RequiredPrivilege
    )
) {

    [hashtable]$elevationParameters = @{
        Id                = $resolvedPackage.Id
        Provider          = $resolvedProvider.Name
        Mode              = $Mode.ToString()
        PreserveDownloads = [bool]$resolvedPackage.PreserveDownloads
        Confirm           = $false
    }

    [bool]$elevationStarted =
        Request-PhoenixElevation `
            -RequiredPrivilege $resolvedProvider.RequiredPrivilege `
            -CommandName 'Repair-PhoenixPackage' `
            -CommandParameters $elevationParameters `
            -Reason (
                "Repair $($resolvedPackage.Id) using $($resolvedProvider.Name)"
            )

    if ($elevationStarted) {

        [Result]$result = [Result]::Success()

        $result.Code = 'PHX_ELEVATION_REQUESTED'
        $result.Message = (
            'Administrator approval was requested. The repair will continue in the elevated Phoenix window.'
        )
        $result.Data = $resolvedPackage

        return $result
    }

    [Result]$result = [Result]::Failure(
        'Administrator approval was cancelled or elevation failed.'
    )

    $result.Code = 'PHX_ELEVATION_FAILED'
    $result.Data = $resolvedPackage

    return $result
}

        ##########################################################
        ## Execute repair
        ##########################################################

        try {

            try {

                Write-PhoenixLog `
                    -Level Info `
                    -Message (
                        "Repair requested: Provider={0}; Package={1}; Mode={2}" -f
                        $resolvedProvider.Name,
                        $resolvedPackage.Id,
                        $Mode
                    )
            }
            catch {

                Write-Verbose (
                    "Phoenix logging was unavailable: $($_.Exception.Message)"
                )
            }

            [Result]$repairResult =
                $resolvedProvider.RepairPackage(
                    $resolvedPackage,
                    $Mode
                )

            if ($null -eq $repairResult) {

                $repairResult = [Result]::Failure(
                    (
                        "{0} returned no repair result for '{1}'." -f
                        $resolvedProvider.Name,
                        $resolvedPackage.Id
                    )
                )

                $repairResult.Code =
                    'PHX_REPAIR_NO_RESULT'
            }

            try {

                if ($repairResult.Success) {

                    Write-PhoenixLog `
                        -Level Success `
                        -Message (
                            "Repair completed: Provider={0}; Package={1}; Code={2}" -f
                            $resolvedProvider.Name,
                            $resolvedPackage.Id,
                            $repairResult.Code
                        )
                }
                else {

                    Write-PhoenixLog `
                        -Level Error `
                        -Message (
                            "Repair failed: Provider={0}; Package={1}; Code={2}; Message={3}" -f
                            $resolvedProvider.Name,
                            $resolvedPackage.Id,
                            $repairResult.Code,
                            $repairResult.Message
                        )
                }
            }
            catch {

                Write-Verbose (
                    "Phoenix result logging was unavailable: $($_.Exception.Message)"
                )
            }

            return $repairResult
        }
        catch {

            [Result]$exceptionResult =
                [Result]::Failure(
                    (
                        "Repair-PhoenixPackage failed for '{0}': {1}" -f
                        $resolvedPackage.Id,
                        $_.Exception.Message
                    )
                )

            $exceptionResult.Code =
                'PHX_REPAIR_COMMAND_FAILED'

            $exceptionResult.Errors = @(
                $_.Exception.Message
            )

            return $exceptionResult
        }
    }
}
