function Read-PhoenixManifest {

    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$LiteralPath
    )

    if (
        -not (
            Test-Path `
                -LiteralPath $LiteralPath `
                -PathType Leaf
        )
    ) {
        throw "Phoenix restore manifest was not found: $LiteralPath"
    }

    [string]$resolvedPath =
        (Resolve-Path -LiteralPath $LiteralPath).Path

    [string]$manifestJson =
        Get-Content `
            -LiteralPath $resolvedPath `
            -Raw `
            -ErrorAction Stop

    if ([string]::IsNullOrWhiteSpace($manifestJson)) {
        throw "Phoenix restore manifest is empty: $resolvedPath"
    }

    try {
        $manifest =
            $manifestJson |
                ConvertFrom-Json `
                    -ErrorAction Stop
    }
    catch {
        throw "Phoenix restore manifest is not valid JSON: $($_.Exception.Message)"
    }

    if ($null -eq $manifest) {
        throw 'Phoenix restore manifest did not contain an object.'
    }

    [string]$schemaName = [string](
        Get-PhoenixPropertyValue `
            -InputObject $manifest `
            -Name 'Schema' `
            -DefaultValue ''
    )

    if (
        -not [string]::IsNullOrWhiteSpace($schemaName) -and
        $schemaName -ne 'PhoenixRestoreManifest'
    ) {
        throw "Unsupported Phoenix manifest schema '$schemaName'."
    }

    [string]$schemaVersion = [string](
        Get-PhoenixPropertyValue `
            -InputObject $manifest `
            -Name 'SchemaVersion' `
            -DefaultValue ''
    )

    if ([string]::IsNullOrWhiteSpace($schemaVersion)) {

        $metadata =
            Get-PhoenixPropertyValue `
                -InputObject $manifest `
                -Name 'Metadata'

        $schemaVersion = [string](
            Get-PhoenixPropertyValue `
                -InputObject $metadata `
                -Name 'Version' `
                -DefaultValue '1.0'
        )
    }

    $packagesProperty =
        $manifest.PSObject.Properties['Packages']

    $driversProperty =
        $manifest.PSObject.Properties['Drivers']

    if (
        $null -eq $packagesProperty -and
        $null -eq $driversProperty
    ) {
        throw 'Phoenix restore manifest does not contain Packages or Drivers.'
    }

    return [pscustomobject]@{
        Path          = $resolvedPath
        Schema        = if (
            [string]::IsNullOrWhiteSpace($schemaName)
        ) {
            'PhoenixRestoreManifest'
        }
        else {
            $schemaName
        }
        SchemaVersion = $schemaVersion
        Metadata      = Get-PhoenixPropertyValue `
            -InputObject $manifest `
            -Name 'Metadata'
        Inventory     = Get-PhoenixPropertyValue `
            -InputObject $manifest `
            -Name 'Inventory'
        Drivers       = @(
            Get-PhoenixPropertyValue `
                -InputObject $manifest `
                -Name 'Drivers' `
                -DefaultValue @()
        )
        Packages      = @(
            Get-PhoenixPropertyValue `
                -InputObject $manifest `
                -Name 'Packages' `
                -DefaultValue @()
        )
        Providers     = @(
            Get-PhoenixPropertyValue `
                -InputObject $manifest `
                -Name 'Providers' `
                -DefaultValue @()
        )
        Raw           = $manifest
    }
}
