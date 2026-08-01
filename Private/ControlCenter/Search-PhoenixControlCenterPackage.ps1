function Search-PhoenixControlCenterPackage {

    [CmdletBinding()]
    [OutputType([pscustomobject[]])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Query,

        [Parameter()]
        [ValidateSet(
            'WinGet',
            'Chocolatey',
            'Scoop',
            'GitHub Releases',
            'PowerShell Gallery'
        )]
        [string[]]$Provider = @(
            'WinGet',
            'Chocolatey',
            'Scoop',
            'GitHub Releases',
            'PowerShell Gallery'
        )
    )

    $context =
        Resolve-PhoenixContext `
            -ErrorAction Stop

    $results = @(
        foreach (
            $resolvedProvider in @(
                $context.Providers |
                    Where-Object {
                        $_.Available -and
                        $_.SupportsInstall -and
                        $_.Name -in $Provider
                    } |
                    Sort-Object Priority -Descending
            )
        ) {

            try {

                foreach (
                    $package in @(
                        $resolvedProvider.SearchPackage(
                            $Query
                        )
                    )
                ) {

                    if (
                        $null -eq $package -or
                        [string]::IsNullOrWhiteSpace(
                            $package.Id
                        )
                    ) {
                        continue
                    }

                    [string]$installedVersion = ''
                    $installedVersionProperty =
                        $package.PSObject.Properties['InstalledVersion']
                    if ($null -ne $installedVersionProperty) {
                        $installedVersion =
                            [string]$installedVersionProperty.Value
                    }
                    elseif ($package.Installed) {
                        $installedVersion = [string]$package.Version
                    }

                    [bool]$updateAvailable = $false
                    if (
                        $package.Installed -and
                        -not [string]::IsNullOrWhiteSpace($installedVersion) -and
                        -not [string]::IsNullOrWhiteSpace(
                            [string]$package.Version
                        )
                    ) {
                        try {
                            $updateAvailable =
                                [Management.Automation.SemanticVersion]$package.Version -gt
                                [Management.Automation.SemanticVersion]$installedVersion
                        }
                        catch {
                            $updateAvailable =
                                [string]$package.Version -ne $installedVersion
                        }
                    }

                    [pscustomobject]@{
                        IsSelected      = $false
                        Name            = $package.Name
                        Id              = $package.Id
                        Version         = $package.Version
                        Provider        = $package.Provider
                        Source          = $package.Source
                        Architecture    = $package.Architecture
                        Installed       = [bool]$package.Installed
                        InstalledVersion = $installedVersion
                        UpdateAvailable = $updateAvailable
                        OriginalPackage = $package
                    }
                }
            }
            catch {
                Write-Warning (
                    "{0} package search failed: {1}" -f
                    $resolvedProvider.Name,
                    $_.Exception.Message
                )
            }
        }
    )

    return @(
        $results |
            Sort-Object `
                -Property @(
                    'Provider'
                    'Id'
                ) `
                -Unique
    )
}
