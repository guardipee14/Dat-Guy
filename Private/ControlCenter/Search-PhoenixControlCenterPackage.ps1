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
            'Scoop'
        )]
        [string[]]$Provider = @(
            'WinGet',
            'Chocolatey',
            'Scoop'
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

                    [pscustomobject]@{
                        IsSelected      = $false
                        Name            = $package.Name
                        Id              = $package.Id
                        Version         = $package.Version
                        Provider        = $package.Provider
                        Source          = $package.Source
                        Architecture    = $package.Architecture
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
