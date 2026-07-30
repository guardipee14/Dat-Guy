function Install-PhoenixDeveloperTools {

    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'Low'
    )]
    [OutputType([object[]])]
    param(
        [Parameter()]
        [ValidateNotNull()]
        [version]$MinimumPesterVersion =
            [version]'6.0.0',

        [Parameter()]
        [switch]$Force
    )

    $requirements = @(
        [pscustomobject]@{
            Name           = 'PSScriptAnalyzer'
            MinimumVersion = $null
        }

        [pscustomobject]@{
            Name           = 'Pester'
            MinimumVersion = $MinimumPesterVersion
        }

        [pscustomobject]@{
            Name           = 'platyPS'
            MinimumVersion = $null
        }
    )

    $results =
        [System.Collections.Generic.List[object]]::new()

    foreach ($requirement in $requirements) {

        [string]$moduleName =
            $requirement.Name

        $minimumVersion =
            $requirement.MinimumVersion

        [string]$requirementLabel = if (
            $null -eq $minimumVersion
        ) {
            'an installed version'
        }
        else {
            'version {0} or later' -f
            $minimumVersion
        }

        Write-Host (
            'Checking {0} ({1})...' -f
            $moduleName,
            $requirementLabel
        ) -ForegroundColor Cyan

        $availableModules = @(
            Get-Module `
                -Name $moduleName `
                -ListAvailable |
                Sort-Object Version -Descending
        )

        $compatibleModule = if (
            $null -eq $minimumVersion
        ) {
            $availableModules |
                Select-Object -First 1
        }
        else {
            $availableModules |
                Where-Object {
                    $_.Version -ge $minimumVersion
                } |
                Select-Object -First 1
        }

        [bool]$installationRequired =
            $Force -or
            $null -eq $compatibleModule

        [string]$status = 'Available'

        if ($installationRequired) {

            [string]$action = if ($Force) {
                'Install or update developer module'
            }
            else {
                'Install required developer module'
            }

            if (
                -not $PSCmdlet.ShouldProcess(
                    $moduleName,
                    $action
                )
            ) {
                $status = 'Skipped'
            }
            else {

                $installParameters = @{
                    Name         = $moduleName
                    Scope        = 'CurrentUser'
                    Force        = $true
                    AllowClobber = $true
                    ErrorAction  = 'Stop'
                }

                if ($null -ne $minimumVersion) {
                    $installParameters.MinimumVersion =
                        $minimumVersion
                }

                try {
                    Install-Module @installParameters
                }
                catch {
                    throw (
                        "Failed to install $moduleName`: " +
                        $_.Exception.Message
                    )
                }

                $compatibleModule = @(
                    Get-Module `
                        -Name $moduleName `
                        -ListAvailable |
                        Where-Object {
                            $null -eq $minimumVersion -or
                            $_.Version -ge $minimumVersion
                        } |
                        Sort-Object Version -Descending
                ) |
                    Select-Object -First 1

                if ($null -eq $compatibleModule) {
                    throw (
                        "Installation completed, but $moduleName " +
                        "$requirementLabel was not found."
                    )
                }

                $status = 'Installed'
            }
        }

        [string]$installedVersion = if (
            $null -ne $compatibleModule
        ) {
            $compatibleModule.Version.ToString()
        }
        else {
            ''
        }

        [string]$installedPath = if (
            $null -ne $compatibleModule
        ) {
            $compatibleModule.Path
        }
        else {
            ''
        }

        [string]$requiredVersionText = if (
            $null -eq $minimumVersion
        ) {
            ''
        }
        else {
            $minimumVersion.ToString()
        }

        if ($status -eq 'Skipped') {
            Write-Host (
                '{0} installation was skipped.' -f
                $moduleName
            ) -ForegroundColor DarkYellow
        }
        else {
            Write-Host (
                '{0} {1} is available.' -f
                $moduleName,
                $installedVersion
            ) -ForegroundColor Green
        }

        $results.Add(
            [pscustomobject]@{
                Name              = $moduleName
                MinimumVersion    = $requiredVersionText
                InstalledVersion  = $installedVersion
                Status            = $status
                Path              = $installedPath
            }
        )
    }

    return $results.ToArray()
}