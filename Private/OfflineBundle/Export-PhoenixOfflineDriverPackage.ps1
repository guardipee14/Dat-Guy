function Export-PhoenixOfflineDriverPackage {

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PhoenixOfflineDriverPackage[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ContentStoreRoot,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [object[]]$Driver = @(
            Get-CimInstance `
                -ClassName Win32_PnPSignedDriver `
                -ErrorAction Stop
        ),

        [Parameter()]
        [ValidateSet('x64', 'x86', 'arm64', 'Unknown')]
        [string]$Architecture = 'x64'
    )

    $pnputil =
        Get-Command `
            -Name pnputil.exe `
            -CommandType Application `
            -ErrorAction SilentlyContinue

    if ($null -eq $pnputil) {
        throw 'PnPUtil is required to export installed driver packages.'
    }

    $packages =
        [Collections.Generic.List[PhoenixOfflineDriverPackage]]::new()

    foreach ($driverRecord in $Driver) {
        [string]$infName =
            [string](
                Get-PhoenixDriverPropertyValue `
                    -InputObject $driverRecord `
                    -Name @('InfName', 'PublishedName')
            )

        if ($infName -notmatch '^(?i:oem\d+\.inf)$') {
            continue
        }

        [string]$driverRoot =
            Join-Path `
                $DestinationPath `
                ([IO.Path]::GetFileNameWithoutExtension($infName))

        if (
            -not $PSCmdlet.ShouldProcess(
                $infName,
                "Export installed driver package to '$driverRoot'"
            )
        ) {
            continue
        }

        $null =
            New-Item `
                -ItemType Directory `
                -Path $driverRoot `
                -Force `
                -ErrorAction Stop

        $LASTEXITCODE = 0
        [string[]]$output =
            @(
                & $pnputil.Source `
                    /export-driver `
                    $infName `
                    $driverRoot `
                    2>&1
            )

        if ($LASTEXITCODE -ne 0) {
            throw (
                "PnPUtil could not export '$infName': " +
                ($output -join [Environment]::NewLine)
            )
        }

        $contentObjects =
            [Collections.Generic.List[PhoenixContentObject]]::new()

        foreach (
            $exportedFile in @(
                Get-ChildItem `
                    -LiteralPath $driverRoot `
                    -File `
                    -Recurse `
                    -Force `
                    -ErrorAction Stop
            )
        ) {
            $contentObject =
                Add-PhoenixContentStoreObject `
                    -StoreRoot $ContentStoreRoot `
                    -LiteralPath $exportedFile.FullName `
                    -Confirm:$false

            $contentObjects.Add($contentObject)
        }

        if ($contentObjects.Count -eq 0) {
            throw "Driver export '$infName' did not produce any files."
        }

        $packages.Add(
            (
                ConvertTo-PhoenixOfflineDriverPackage `
                    -InputObject $driverRecord `
                    -File @($contentObjects) `
                    -Architecture $Architecture
            )
        )
    }

    return @($packages)
}
