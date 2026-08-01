using module '..\Classes\Phoenix.Classes.psm1'

function Remove-PhoenixPackage {

    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'High',
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
            'Chocolatey',
            'Scoop',
            'MSI'
        )]
        [string]$Provider
    )

    process {

    try {
        $context =
            Resolve-PhoenixContext `
                -ErrorAction Stop
    }
    catch {

        [Result]$result = [Result]::Failure(
            "Phoenix initialization failed: $($_.Exception.Message)"
        )

        $result.Code = 'PHX_INITIALIZATION_FAILED'

        return $result
    }

    [Package]$resolvedPackage = $null
    [string]$providerName = $Provider

    if ($PSCmdlet.ParameterSetName -eq 'ById') {

        $resolvedPackage = [Package]::new()
        $resolvedPackage.Id = $Id
        $resolvedPackage.Name = $Id
        $resolvedPackage.Provider = $Provider
    }
    else {

        $resolvedPackage = $Package

        if (-not [string]::IsNullOrWhiteSpace($Provider)) {
            $resolvedPackage.Provider = $Provider
        }

        $providerName = $resolvedPackage.Provider
    }

    if (
        $null -eq $resolvedPackage -or
        [string]::IsNullOrWhiteSpace($resolvedPackage.Id)
    ) {

        [Result]$result = [Result]::Failure(
            'A valid package ID is required.'
        )

        $result.Code = 'PHX_INVALID_PACKAGE'

        return $result
    }

    if ([string]::IsNullOrWhiteSpace($resolvedPackage.Name)) {
        $resolvedPackage.Name = $resolvedPackage.Id
    }

    if ([string]::IsNullOrWhiteSpace($providerName)) {

        [Result]$result = [Result]::Failure(
            'A package provider is required.'
        )

        $result.Code = 'PHX_PROVIDER_REQUIRED'

        return $result
    }

    [PhoenixProvider]$resolvedProvider = @(
        $context.Providers |
            Where-Object {
                $_.Name -ieq $providerName
            } |
            Sort-Object Priority -Descending
    ) |
        Select-Object -First 1

    if ($null -eq $resolvedProvider) {

        [Result]$result = [Result]::Failure(
            "Phoenix provider '$providerName' was not found."
        )

        $result.Code = 'PHX_PROVIDER_NOT_FOUND'

        return $result
    }

    if (-not $resolvedProvider.Available) {

        [Result]$result = [Result]::Failure(
            "Phoenix provider '$providerName' is unavailable."
        )

        $result.Code = 'PHX_PROVIDER_UNAVAILABLE'

        return $result
    }

[string]$target = (
    "{0} package '{1}'" -f
    $resolvedProvider.Name,
    $resolvedPackage.Id
)

[string]$operation = 'Remove package'

if (-not $PSCmdlet.ShouldProcess($target, $operation)) {

    [Result]$result = [Result]::Success()

    $result.Code = 'PHX_REMOVE_SKIPPED'
    $result.Message = (
        "Removal was skipped for '$($resolvedPackage.Id)'."
    )
    $result.Data = $resolvedPackage

    return $result
}

if (
    -not (
        Test-PhoenixPrivilege `
            -RequiredPrivilege $resolvedProvider.RequiredPrivilege
    )
) {

    [hashtable]$elevationParameters = @{
        Id       = $resolvedPackage.Id
        Provider = $resolvedProvider.Name
        Confirm  = $false
    }

    [bool]$elevationStarted =
        Request-PhoenixElevation `
            -RequiredPrivilege $resolvedProvider.RequiredPrivilege `
            -CommandName 'Remove-PhoenixPackage' `
            -CommandParameters $elevationParameters `
            -Reason (
                "Remove $($resolvedPackage.Id) using $($resolvedProvider.Name)"
            )

    if ($elevationStarted) {

        [Result]$result = [Result]::Success()

        $result.Code = 'PHX_ELEVATION_REQUESTED'
        $result.Message = (
            'Administrator approval was requested. The removal will continue in the elevated Phoenix window.'
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

try {

    [Result]$result =
        $resolvedProvider.RemovePackage(
            $resolvedPackage
        )

    if ($null -eq $result) {

        $result = [Result]::Failure(
            "$($resolvedProvider.Name) returned no removal result."
        )

        $result.Code = 'PHX_REMOVE_NO_RESULT'
    }

    return $result
}
catch {

    [Result]$result = [Result]::Failure(
        "Removal failed: $($_.Exception.Message)"
    )

    $result.Code = 'PHX_REMOVE_COMMAND_FAILED'
    $result.Errors = @($_.Exception.Message)

    return $result
}
}
}
