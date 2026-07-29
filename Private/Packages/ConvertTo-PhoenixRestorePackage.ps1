function ConvertTo-PhoenixRestorePackage {

    [CmdletBinding()]
    [OutputType([Package])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowNull()]
        [object]$InputObject
    )

    process {

        if ($null -eq $InputObject) {
            return $null
        }

        [string]$name = [string](
            Get-PhoenixPropertyValue `
                -InputObject $InputObject `
                -Name 'Name' `
                -DefaultValue ''
        )

        [string]$id = [string](
            Get-PhoenixPropertyValue `
                -InputObject $InputObject `
                -Name 'Id' `
                -DefaultValue ''
        )

        if ([string]::IsNullOrWhiteSpace($id)) {
            $id = $name
        }

        if ([string]::IsNullOrWhiteSpace($id)) {
            return $null
        }

        [string]$provider = [string](
            Get-PhoenixPropertyValue `
                -InputObject $InputObject `
                -Name 'Provider' `
                -DefaultValue ''
        )

        if ([string]::IsNullOrWhiteSpace($provider)) {
            $provider = [string](
                Get-PhoenixPropertyValue `
                    -InputObject $InputObject `
                    -Name 'InstallerType' `
                    -DefaultValue ''
            )
        }

        switch -Regex ($provider) {
            '^(?i)winget$' {
                $provider = 'WinGet'
            }

            '^(?i)chocolatey$' {
                $provider = 'Chocolatey'
            }
        }

        [Package]$package = [Package]::new()

        $package.Id = $id
        $package.Name = if (
            [string]::IsNullOrWhiteSpace($name)
        ) {
            $id
        }
        else {
            $name
        }

        $package.Version = [string](
            Get-PhoenixPropertyValue `
                -InputObject $InputObject `
                -Name 'Version' `
                -DefaultValue ''
        )

        $package.Provider = $provider

        $package.InstallerType = [string](
            Get-PhoenixPropertyValue `
                -InputObject $InputObject `
                -Name 'InstallerType' `
                -DefaultValue $provider
        )

        $package.Source = [string](
            Get-PhoenixPropertyValue `
                -InputObject $InputObject `
                -Name 'Source' `
                -DefaultValue ''
        )

        $package.Architecture = [string](
            Get-PhoenixPropertyValue `
                -InputObject $InputObject `
                -Name 'Architecture' `
                -DefaultValue ''
        )

        $package.Installed = $false

        return $package
    }
}
