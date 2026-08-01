function Test-PhoenixRestorePackage {

    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline
        )]
        [AllowNull()]
        [object]$InputObject
    )

    process {

        if ($null -eq $InputObject) {
            return $false
        }

        [string]$id = [string](
            Get-PhoenixPropertyValue `
                -InputObject $InputObject `
                -Name 'Id' `
                -DefaultValue ''
        )

        [string]$provider = [string](
            Get-PhoenixPropertyValue `
                -InputObject $InputObject `
                -Name 'Provider' `
                -DefaultValue ''
        )

        [string]$source = [string](
            Get-PhoenixPropertyValue `
                -InputObject $InputObject `
                -Name 'Source' `
                -DefaultValue ''
        )

        if (
            [string]::IsNullOrWhiteSpace($id) -or
            [string]::IsNullOrWhiteSpace($provider)
        ) {
            return $false
        }

        if ($provider -iin @(
            'Chocolatey'
            'Scoop'
            'PowerShell Gallery'
            'NuGet'
        )) {
            return $true
        }

        if ($provider -ine 'WinGet') {
            return $false
        }

        return (
            $source -ieq 'winget' -and
            $id -notmatch '^(?i:ARP|MSIX)\\'
        )
    }
}
