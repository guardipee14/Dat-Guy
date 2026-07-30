function Test-PhoenixContext {

    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Context
    )

    if ($null -eq $Context) {
        return $false
    }

    foreach (
        $requiredProperty in @(
            'IsInitialized'
            'LifecycleState'
            'ProjectRoot'
            'Configuration'
            'Logger'
            'Providers'
        )
    ) {
        if (
            $null -eq
                $Context.PSObject.Properties[$requiredProperty]
        ) {
            return $false
        }
    }

    if (
        -not [bool]$Context.IsInitialized -or
        [string]$Context.LifecycleState -ne 'Ready' -or
        [string]::IsNullOrWhiteSpace(
            [string]$Context.ProjectRoot
        ) -or
        $null -eq $Context.Configuration -or
        $null -eq $Context.Logger -or
        $null -eq $Context.Providers
    ) {
        return $false
    }

    return $true
}
