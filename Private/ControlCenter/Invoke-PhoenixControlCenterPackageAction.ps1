function Invoke-PhoenixControlCenterPackageAction {

    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([Result[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet(
            'Install',
            'Update',
            'Repair',
            'Uninstall'
        )]
        [string]$Action,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [object[]]$Package,

        [Parameter()]
        [switch]$Unattended,

        [Parameter()]
        [switch]$AllowMigration
    )

    $results =
        [System.Collections.Generic.List[Result]]::new()

    foreach ($inputPackage in $Package) {

        [Package]$resolvedPackage = $null

        if ($null -eq $inputPackage) {

            [Result]$result = [Result]::Failure(
                'A selected application record was null.'
            )

            $result.Code =
                'PHX_CONTROL_CENTER_PACKAGE_UNSUPPORTED'

            $results.Add($result)
            continue
        }

        $originalPackageProperty =
            $inputPackage.PSObject.Properties[
                'OriginalPackage'
            ]

        if (
            $null -ne $originalPackageProperty -and
            $originalPackageProperty.Value -is [Package]
        ) {
            $resolvedPackage =
                $originalPackageProperty.Value
        }
        elseif ($inputPackage -is [Package]) {
            $resolvedPackage = $inputPackage
        }
        else {

            $resolvedPackage = [Package]::new()

            foreach (
                $propertyName in @(
                    'Name'
                    'Id'
                    'Version'
                    'Provider'
                    'InstallerType'
                    'Source'
                    'Architecture'
                )
            ) {

                $property =
                    $inputPackage.PSObject.Properties[
                        $propertyName
                    ]

                if ($null -ne $property) {
                    $resolvedPackage.$propertyName =
                        [string]$property.Value
                }
            }
        }

        if (
            $null -eq $resolvedPackage -or
            [string]::IsNullOrWhiteSpace($resolvedPackage.Id) -or
            [string]::IsNullOrWhiteSpace($resolvedPackage.Provider)
        ) {

            [Result]$result = [Result]::Failure(
                'The selected application is not actionable through Phoenix.'
            )

            $result.Code =
                'PHX_CONTROL_CENTER_PACKAGE_UNSUPPORTED'

            $result.Data = $inputPackage
            $results.Add($result)
            continue
        }

        [PhoenixProvider]$actionProvider = $null

        try {
            $context = Resolve-PhoenixContext -ErrorAction Stop
            $actionProvider = @(
                $context.Providers |
                    Where-Object {
                        $_.Name -ieq $resolvedPackage.Provider
                    } |
                    Sort-Object Priority -Descending
            ) | Select-Object -First 1
        }
        catch {
            $actionProvider = $null
        }

        [bool]$actionSupported =
            $null -ne $actionProvider -and
            $actionProvider.Available -and
            $(switch ($Action) {
                'Install' { $actionProvider.SupportsInstall }
                'Update' { $actionProvider.SupportsUpdate }
                'Repair' { $actionProvider.SupportsRepair }
                'Uninstall' { $actionProvider.SupportsRemove }
            })

        if (-not $actionSupported) {
            [Result]$result = [Result]::Failure(
                "The selected provider does not support $Action for this application."
            )
            $result.Code =
                'PHX_CONTROL_CENTER_PACKAGE_UNSUPPORTED'
            $result.Data = $resolvedPackage
            $results.Add($result)
            continue
        }

        if (
            $Action -eq 'Uninstall' -and
            [string]$resolvedPackage.Id -in @(
                'chocolatey'
                'chocolatey-compatibility.extension'
                'chocolatey-core.extension'
                'Microsoft.AppInstaller'
            )
        ) {

            [Result]$result = [Result]::Failure(
                (
                    "Phoenix package-manager component " +
                    "'$($resolvedPackage.Id)' cannot be uninstalled " +
                    'from Control Center.'
                )
            )

            $result.Code =
                'PHX_CONTROL_CENTER_PACKAGE_PROTECTED'

            $result.Data = $resolvedPackage
            $results.Add($result)
            continue
        }

        [string]$target = (
            "{0} package '{1}'" -f
            $resolvedPackage.Provider,
            $resolvedPackage.Id
        )

        if (-not $PSCmdlet.ShouldProcess($target, $Action)) {

            [Result]$result = [Result]::Success()
            $result.Code =
                'PHX_CONTROL_CENTER_ACTION_SKIPPED'
            $result.Message = (
                "$Action was skipped for '$($resolvedPackage.Id)'."
            )
            $result.Data = $resolvedPackage
            $results.Add($result)
            continue
        }

        [Result]$result = $null

        try {

            $result = switch ($Action) {
                'Install' {
                    Install-PhoenixPackage `
                        -Package $resolvedPackage `
                        -Confirm:$false
                }

                'Update' {
                    Update-PhoenixPackage `
                        -Package $resolvedPackage `
                        -AllowMigration:$AllowMigration `
                        -Unattended:$Unattended `
                        -Confirm:$false
                }

                'Repair' {
                    Repair-PhoenixPackage `
                        -Package $resolvedPackage `
                        -Confirm:$false
                }

                'Uninstall' {
                    Remove-PhoenixPackage `
                        -Package $resolvedPackage `
                        -Confirm:$false
                }
            }
        }
        catch {

            $result = [Result]::Failure(
                "$Action failed for '$($resolvedPackage.Id)': $($_.Exception.Message)"
            )

            $result.Code =
                'PHX_CONTROL_CENTER_PACKAGE_ACTION_FAILED'

            $result.Errors = @(
                $_.Exception.Message
            )
        }

        if ($null -eq $result) {

            $result = [Result]::Failure(
                "$Action returned no result for '$($resolvedPackage.Id)'."
            )

            $result.Code =
                'PHX_CONTROL_CENTER_NO_RESULT'
        }

        $results.Add($result)
    }

    return $results.ToArray()
}
