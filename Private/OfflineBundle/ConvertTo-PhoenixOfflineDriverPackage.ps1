function Get-PhoenixDriverPropertyValue {

    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Name
    )

    if ($null -eq $InputObject) {
        return $null
    }

    foreach ($candidateName in $Name) {
        if ($InputObject -is [Collections.IDictionary]) {
            foreach ($key in $InputObject.Keys) {
                if (
                    [string]::Equals(
                        [string]$key,
                        $candidateName,
                        [StringComparison]::OrdinalIgnoreCase
                    )
                ) {
                    return $InputObject[$key]
                }
            }
        }
        else {
            $property =
                $InputObject.PSObject.Properties[$candidateName]

            if ($null -ne $property) {
                return $property.Value
            }
        }
    }

    return $null
}

function ConvertTo-PhoenixDriverIdentifierArray {

    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return @()
    }

    if ($Value -is [string]) {
        return @(
            $Value -split '[\r\n;]+' |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace($_)
                }
        )
    }

    return @($Value)
}

function ConvertTo-PhoenixOfflineDriverPackage {

    [CmdletBinding()]
    [OutputType([PhoenixOfflineDriverPackage])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNull()]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PhoenixContentObject[]]$File,

        [Parameter()]
        [ValidateSet('x64', 'x86', 'arm64', 'Unknown')]
        [string]$Architecture = 'Unknown'
    )

    process {
        $package =
            [PhoenixOfflineDriverPackage]::new()

        [string]$infName =
            [string](
                Get-PhoenixDriverPropertyValue `
                    -InputObject $InputObject `
                    -Name @('InfName', 'PublishedName', 'DriverName')
            )

        [string]$provider =
            [string](
                Get-PhoenixDriverPropertyValue `
                    -InputObject $InputObject `
                    -Name @('DriverProviderName', 'Provider', 'Manufacturer')
            )

        [string]$version =
            [string](
                Get-PhoenixDriverPropertyValue `
                    -InputObject $InputObject `
                    -Name @('DriverVersion', 'Version')
            )

        $hardwareIds =
            ConvertTo-PhoenixDriverIdentifierArray `
                -Value (
                    Get-PhoenixDriverPropertyValue `
                        -InputObject $InputObject `
                        -Name @('HardwareID', 'HardwareIds')
                )

        $compatibleIds =
            ConvertTo-PhoenixDriverIdentifierArray `
                -Value (
                    Get-PhoenixDriverPropertyValue `
                        -InputObject $InputObject `
                        -Name @('CompatibleID', 'CompatibleIds')
                )

        $package.InfName = $infName.Trim()
        $package.Provider = $provider.Trim()
        $package.Version = $version.Trim()
        $package.Class =
            [string](
                Get-PhoenixDriverPropertyValue `
                    -InputObject $InputObject `
                    -Name @('DeviceClass', 'Class')
            )
        $package.ClassGuid =
            [string](
                Get-PhoenixDriverPropertyValue `
                    -InputObject $InputObject `
                    -Name @('ClassGuid')
            )
        $package.Architecture = $Architecture
        $package.SetMatchIdentifiers($hardwareIds, $compatibleIds)

        [object]$driverDate =
            Get-PhoenixDriverPropertyValue `
                -InputObject $InputObject `
                -Name @('DriverDate', 'Date')

        if ($null -ne $driverDate) {
            [datetime]$parsedDate = [datetime]::MinValue

            if ([datetime]::TryParse([string]$driverDate, [ref]$parsedDate)) {
                $package.DriverDate = $parsedDate
            }
        }

        foreach ($contentObject in $File) {
            $package.AddFile($contentObject)
        }

        [string]$identityText =
            @(
                $package.Provider.Trim().ToUpperInvariant()
                $package.InfName.Trim().ToLowerInvariant()
                $package.Version.Trim()
                $package.Architecture.Trim().ToLowerInvariant()
                @($package.HardwareIds)
                @($package.CompatibleIds)
            ) -join "`n"

        [byte[]]$identityBytes =
            [Text.Encoding]::UTF8.GetBytes($identityText)

        [byte[]]$identityHash =
            [Security.Cryptography.SHA256]::HashData($identityBytes)

        $package.PackageId =
            'driver-package:sha256:{0}' -f
                [Convert]::ToHexString($identityHash).ToLowerInvariant()

        $package.Metadata['CatalogSource'] =
            'Win32_PnPSignedDriver'

        $package.Metadata['DeviceName'] =
            [string](
                Get-PhoenixDriverPropertyValue `
                    -InputObject $InputObject `
                    -Name @('DeviceName', 'Name')
            )

        $package.Metadata['IsSigned'] =
            Get-PhoenixDriverPropertyValue `
                -InputObject $InputObject `
                -Name @('IsSigned')

        if (-not $package.IsValid()) {
            throw (
                "Driver '$infName' did not provide a complete, valid " +
                'offline catalog record.'
            )
        }

        return $package
    }
}
