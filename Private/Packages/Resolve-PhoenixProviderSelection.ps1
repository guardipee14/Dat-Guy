function Resolve-PhoenixProviderSelection {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [PhoenixContext]$Context,

        [Parameter(Mandatory)]
        [Package]$Package,

        [Parameter(Mandatory)]
        [ValidateSet('Install','Update','Repair','Remove','Restore')]
        [string]$Operation,

        [Parameter()]
        [AllowEmptyString()]
        [string]$PreferredProvider = '',

        [Parameter()]
        [switch]$AllowFallback
    )

    if ([string]::IsNullOrWhiteSpace($PreferredProvider)) {
        $PreferredProvider = $Package.Provider
    }

    $operationProperty = switch ($Operation) {
        'Install' { 'SupportsInstall' }
        'Update' { 'SupportsUpdate' }
        'Repair' { 'SupportsRepair' }
        'Remove' { 'SupportsRemove' }
        'Restore' { 'SupportsRestore' }
    }

    $orderedProviders = @(
        $Context.Providers |
            Sort-Object `
                @{ Expression = {
                    if ($_.Name -ieq $PreferredProvider) { 0 } else { 1 }
                } },
                @{ Expression = 'Priority'; Descending = $true }
    )

    $alternatives = @(
        $orderedProviders |
            Where-Object {
                $_.Name -ine $PreferredProvider -and
                $_.Available -and
                [bool]$_.$operationProperty
            } |
            ForEach-Object {
                [pscustomobject]@{
                    Name = $_.Name
                    Priority = $_.Priority
                    Privilege = $_.RequiredPrivilege.ToString()
                    RequiresElevation = -not (
                        Test-PhoenixPrivilege `
                            -RequiredPrivilege $_.RequiredPrivilege
                    )
                    Safety = 'Provider capability match; package identity must be confirmed.'
                }
            }
    )

    $candidates = if ($AllowFallback) {
        $orderedProviders
    }
    else {
        @($orderedProviders | Where-Object Name -IEQ $PreferredProvider)
    }

    [PhoenixProvider]$selectedProvider = $null
    [string]$code = 'PHX_PROVIDER_NOT_FOUND'
    [string]$message = "Phoenix provider '$PreferredProvider' was not found."

    foreach ($candidate in @($candidates)) {
        if (-not $candidate.Available) {
            $code = 'PHX_PROVIDER_UNAVAILABLE'
            $message = "Phoenix provider '$($candidate.Name)' is unavailable."
            continue
        }
        if (-not [bool]$candidate.$operationProperty) {
            $code = 'PHX_OPERATION_UNAVAILABLE'
            $message = "$($candidate.Name) does not support $Operation."
            continue
        }
        if (
            $Operation -eq 'Remove' -and
            $Package.Id -in @(
                'chocolatey'
                'chocolatey-compatibility.extension'
                'chocolatey-core.extension'
                'Microsoft.AppInstaller'
            )
        ) {
            $code = 'PHX_PROTECTED_PACKAGE'
            $message = "Package '$($Package.Id)' is protected from removal."
            break
        }
        if (
            $Operation -eq 'Restore' -and
            -not (Test-PhoenixRestorePackage -InputObject $Package)
        ) {
            $code = 'PHX_RESTORE_INELIGIBLE'
            $message = "Package '$($Package.Id)' is not restore eligible."
            break
        }
        $selectedProvider = $candidate
        $code = 'PHX_PROVIDER_SELECTED'
        $message = "Selected provider '$($candidate.Name)' for $Operation."
        break
    }

    return [pscustomobject]@{
        Provider = $selectedProvider
        ProviderName = if ($null -ne $selectedProvider) {
            $selectedProvider.Name
        }
        else { '' }
        PreferredProvider = $PreferredProvider
        Operation = $Operation
        Eligible = $null -ne $selectedProvider
        RequiresElevation = [bool](
            $null -ne $selectedProvider -and
            -not (Test-PhoenixPrivilege `
                -RequiredPrivilege $selectedProvider.RequiredPrivilege)
        )
        Safety = if ($code -eq 'PHX_PROTECTED_PACKAGE') {
            'Blocked by protected-package policy.'
        }
        else { 'Eligible under current provider safety policy.' }
        Alternatives = $alternatives
        Code = $code
        Message = $message
    }
}

function ConvertTo-PhoenixOrchestratedResult {
    [CmdletBinding()]
    [OutputType([Result])]
    param(
        [Parameter()]
        [AllowNull()]
        [Result]$Result,

        [Parameter(Mandatory)]
        [string]$Provider,

        [Parameter(Mandatory)]
        [string]$Operation,

        [Parameter(Mandatory)]
        [string]$Target
    )

    if ($null -eq $Result) {
        $Result = [Result]::Failure(
            "$Provider returned no result for $Operation."
        )
        $Result.Code = 'PHX_PROVIDER_NO_RESULT'
    }
    if ([string]::IsNullOrWhiteSpace($Result.Provider)) {
        $Result.Provider = $Provider
    }
    if ([string]::IsNullOrWhiteSpace($Result.Operation)) {
        $Result.Operation = $Operation
    }
    if ([string]::IsNullOrWhiteSpace($Result.Target)) {
        $Result.Target = $Target
    }
    if ([string]::IsNullOrWhiteSpace($Result.Code)) {
        $Result.Code = if ($Result.Success) {
            "PHX_$($Operation.ToUpperInvariant())_SUCCEEDED"
        }
        else {
            "PHX_$($Operation.ToUpperInvariant())_FAILED"
        }
    }
    return $Result
}
