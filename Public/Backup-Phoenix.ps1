using module '..\Classes\Phoenix.Classes.psm1'

function Backup-Phoenix {

    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'Medium'
    )]
    [OutputType([Result])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter()]
        [switch]$SkipDrivers,

        [Parameter()]
        [switch]$SkipPackages
    )

    $context = $null

    try {
        $context = Get-PhoenixContext -ErrorAction Stop
    }
    catch {
        $context = $null
    }

    if ($null -eq $context) {

        try {
            Start-Phoenix
            $context = Get-PhoenixContext -ErrorAction Stop
        }
        catch {

            [Result]$result = [Result]::Failure(
                "Phoenix initialization failed: $($_.Exception.Message)"
            )

            $result.Code = 'PHX_INITIALIZATION_FAILED'

            return $result
        }
    }

    try {

        [string]$resolvedOutputPath = $OutputPath

        if (-not [IO.Path]::IsPathRooted($resolvedOutputPath)) {
            $resolvedOutputPath =
                Join-Path `
                    (Get-Location).Path `
                    $resolvedOutputPath
        }

        $resolvedOutputPath =
            [IO.Path]::GetFullPath($resolvedOutputPath)

        if (
            -not $PSCmdlet.ShouldProcess(
                $resolvedOutputPath,
                'Create Phoenix restore manifest'
            )
        ) {

            [Result]$result = [Result]::Success()
            $result.Code = 'PHX_BACKUP_SKIPPED'
            $result.Message = 'Phoenix backup was skipped.'
            $result.Data = [pscustomobject]@{
                Stage = 'Backup'
                Path  = $resolvedOutputPath
            }

            return $result
        }

        [string]$parentPath =
            Split-Path `
                -Path $resolvedOutputPath `
                -Parent

        if (
            -not [string]::IsNullOrWhiteSpace($parentPath) -and
            -not (Test-Path -LiteralPath $parentPath)
        ) {
            New-Item `
                -ItemType Directory `
                -Path $parentPath `
                -Force |
                Out-Null
        }

        Write-PhoenixLog `
            -Level Info `
            -Message 'Creating Phoenix restore manifest.'

        [Package[]]$packages = @()

        if (-not $SkipPackages) {
            $packages = @(
                Get-PhoenixPackages |
                    Where-Object {
                        -not [string]::IsNullOrWhiteSpace($_.Id) -and
                        -not [string]::IsNullOrWhiteSpace($_.Provider)
                    }
            )
        }

        [Driver[]]$drivers = @()

        if (-not $SkipDrivers) {
            $drivers = @(
                Get-PhoenixDriver
            )
        }

        $providerRecords = @(
            $context.Providers |
                ForEach-Object {
                    [ordered]@{
                        Name                       = $_.Name
                        Version                    = $_.Version
                        Type                       = $_.Type
                        Priority                   = $_.Priority
                        Available                  = $_.Available
                        RequiredPrivilege          = $_.RequiredPrivilege.ToString()
                        SupportsInstall            = $_.SupportsInstall
                        SupportsUpdate             = $_.SupportsUpdate
                        SupportsRemove             = $_.SupportsRemove
                        SupportsExport             = $_.SupportsExport
                        SupportsOfflineCache       = $_.SupportsOfflineCache
                        SupportsDependencies       = $_.SupportsDependencies
                        SupportsSilentInstall      = $_.SupportsSilentInstall
                        SupportsInteractiveInstall = $_.SupportsInteractiveInstall
                        SupportsRepair             = $_.SupportsRepair
                    }
                }
        )

        [Package[]]$uniquePackages = @(
            $packages |
                Sort-Object Provider, Id -Unique
        )

        [scriptblock]$convertPackageRecord = {
            [ordered]@{
                Name          = $_.Name
                Id            = $_.Id
                Version       = $_.Version
                Provider      = $_.Provider
                InstallerType = $_.InstallerType
                Source        = $_.Source
                Architecture  = $_.Architecture
            }
        }

        $softwareRecords = @(
            $uniquePackages |
                ForEach-Object $convertPackageRecord
        )

        $packageRecords = @(
            $uniquePackages |
                Where-Object {
                    Test-PhoenixRestorePackage `
                        -InputObject $_
                } |
                ForEach-Object $convertPackageRecord
        )

        $driverRecords = @(
            $drivers |
                Sort-Object Manufacturer, Name, Version -Unique |
                ForEach-Object {
                    [ordered]@{
                        Name         = $_.Name
                        Manufacturer = $_.Manufacturer
                        Version      = $_.Version
                        Class        = $_.Class
                        Provider     = $_.Provider
                        InfName      = $_.InfName
                        Present      = $_.Present
                    }
                }
        )

        $hardwareInventory = $null
        $networkInventory = $null
        $operatingSystem = $null

        try {
            $hardwareInventory = Get-HardwareInventory
        }
        catch {
            Write-Warning (
                "Hardware inventory was not collected: $($_.Exception.Message)"
            )
        }

        try {
            $networkInventory = Get-NetworkInventory
        }
        catch {
            Write-Warning (
                "Network inventory was not collected: $($_.Exception.Message)"
            )
        }

        try {
            $operatingSystem =
                Get-CimInstance `
                    Win32_OperatingSystem `
                    -ErrorAction Stop
        }
        catch {
            Write-Warning (
                "Operating-system inventory was not collected: $($_.Exception.Message)"
            )
        }

        $module = Get-Module Phoenix

        [string]$phoenixVersion = if ($null -ne $module) {
            $module.Version.ToString()
        }
        else {
            $context.Version
        }

        $manifest = [ordered]@{
            Schema        = 'PhoenixRestoreManifest'
            SchemaVersion = '2.0'
            Metadata      = [ordered]@{
                ManifestId      = [guid]::NewGuid().ToString()
                CreatedAtUtc    = (Get-Date).ToUniversalTime().ToString('o')
                ComputerName    = $env:COMPUTERNAME
                UserName        = $env:USERNAME
                PhoenixVersion  = $phoenixVersion
                PowerShell      = $PSVersionTable.PSVersion.ToString()
                OperatingSystem = [Environment]::OSVersion.VersionString
            }
            Options       = [ordered]@{
                DriversIncluded           = -not [bool]$SkipDrivers
                PackagesIncluded          = -not [bool]$SkipPackages
                SoftwareInventoryIncluded = -not [bool]$SkipPackages
            }
            Inventory     = [ordered]@{
                Hardware        = $hardwareInventory
                Network         = $networkInventory
                OperatingSystem = $operatingSystem
                PowerShell      = $PSVersionTable
                Software        = $softwareRecords
            }
            Drivers       = $driverRecords
            Packages      = $packageRecords
            Providers     = $providerRecords
        }

        $manifest |
            ConvertTo-Json -Depth 30 |
            Set-Content `
                -LiteralPath $resolvedOutputPath `
                -Encoding UTF8

        [Result]$result = [Result]::Success()
        $result.Code = 'PHX_BACKUP_COMPLETE'
        $result.Message = (
            "Phoenix restore manifest saved to '$resolvedOutputPath'."
        )
        $result.Data = [pscustomobject]@{
            Stage         = 'Backup'
            Path          = $resolvedOutputPath
            SchemaVersion = '2.0'
            SoftwareCount = $softwareRecords.Count
            PackageCount  = $packageRecords.Count
            DriverCount   = $driverRecords.Count
            ProviderCount = $providerRecords.Count
        }

        Write-PhoenixLog `
            -Level Success `
            -Message $result.Message

        return $result
    }
    catch {

        [Result]$result = [Result]::Failure(
            "Phoenix backup failed: $($_.Exception.Message)"
        )

        $result.Code = 'PHX_BACKUP_FAILED'
        $result.Errors = @(
            $_.Exception.Message
        )

        return $result
    }
}