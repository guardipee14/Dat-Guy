using module '..\Classes\Phoenix.Classes.psm1'

function New-PhoenixRestorePlan {
    [CmdletBinding()]
    [OutputType([PhoenixRestorePlan])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [Alias('Path')]
        [ValidateNotNullOrEmpty()]
        [string]$ManifestPath,

        [Parameter()]
        [string[]]$Provider = @(
            'WinGet','Chocolatey','Scoop','PowerShell Gallery','NuGet'
        ),

        [Parameter()]
        [switch]$SkipDrivers,

        [Parameter()]
        [switch]$SkipPackages,

        [Parameter()]
        [switch]$ReinstallInstalled
    )

    $context = Resolve-PhoenixContext `
        -SkipProviderBootstrap `
        -ErrorAction Stop
    $manifest = Read-PhoenixManifest -LiteralPath $ManifestPath
    $plan = [PhoenixRestorePlan]::new()
    $plan.ManifestPath = $manifest.Path
    $plan.ManifestId = [string](
        Get-PhoenixPropertyValue `
            -InputObject $manifest.Metadata `
            -Name 'ManifestId' `
            -DefaultValue ''
    )
    $records = [Collections.Generic.List[PhoenixRestorePlanRecord]]::new()

    $installedByProvider = @{}
    if (-not $SkipPackages) {
        foreach ($providerName in @($Provider)) {
            $providerInstance = @(
                $context.Providers | Where-Object Name -IEQ $providerName
            ) | Select-Object -First 1
            if ($null -eq $providerInstance -or -not $providerInstance.Available) {
                continue
            }
            try {
                foreach ($installed in @($providerInstance.GetInstalledPackages())) {
                    if ($null -eq $installed -or [string]::IsNullOrWhiteSpace($installed.Id)) {
                        continue
                    }
                    $installedByProvider["$($providerInstance.Name)|$($installed.Id)"] =
                        $installed
                }
            }
            catch { }
        }

        foreach ($manifestPackage in @($manifest.Packages)) {
            $record = [PhoenixRestorePlanRecord]::new()
            $record.RecordType = 'Application'
            $record.ManifestRecord = $manifestPackage
            $package = ConvertTo-PhoenixRestorePackage -InputObject $manifestPackage
            if ($null -eq $package) {
                $record.PlannedAction = 'Invalid'
                $record.Reason = 'Manifest package record has no usable identity.'
                $records.Add($record)
                continue
            }
            $record.Id = $package.Id
            $record.Name = $package.Name
            $record.RequestedVersion = $package.Version
            $record.AvailableVersion = $package.Version
            $record.Provider = $package.Provider
            $record.Eligible = Test-PhoenixRestorePackage -InputObject $package
            $selection = Resolve-PhoenixProviderSelection `
                -Context $context `
                -Package $package `
                -Operation Restore `
                -PreferredProvider $package.Provider `
                -AllowFallback
            $record.ProviderAlternatives = @($selection.Alternatives.Name)
            $record.RequiresElevation = [bool]$selection.RequiresElevation
            $record.Safety = [string]$selection.Safety
            $record.Reason = [string]$selection.Message
            if ($selection.Eligible) {
                $record.Provider = $selection.ProviderName
            }
            $installedKey = "$($package.Provider)|$($package.Id)"
            $installed = $installedByProvider[$installedKey]
            if ($null -ne $installed) {
                $record.InstalledVersion = [string]$installed.Version
            }
            if (-not $record.Eligible) {
                $record.PlannedAction = 'SkipNotRestorable'
            }
            elseif (-not $selection.Eligible) {
                $record.Eligible = $false
                $record.PlannedAction = 'Blocked'
            }
            elseif ($null -ne $installed -and -not $ReinstallInstalled) {
                $record.PlannedAction = 'AlreadySatisfied'
                $record.Selected = $false
                $record.Reason = 'The package is already installed.'
            }
            else {
                $record.PlannedAction = 'Install'
                $record.Selected = $true
                $record.Reason = 'The package is eligible for restoration.'
            }
            $records.Add($record)
        }
    }

    if (-not $SkipDrivers) {
        $installedDrivers = @()
        try { $installedDrivers = @(Get-PhoenixDriver) } catch { }
        $oemAlternatives = @()
        try {
            $oemAlternatives = @(
                Get-PhoenixOemAdapterStatus |
                    Where-Object Applicable |
                    Select-Object -ExpandProperty Name
            )
        }
        catch { }
        foreach ($manifestDriver in @($manifest.Drivers)) {
            $record = [PhoenixRestorePlanRecord]::new()
            $record.RecordType = 'Driver'
            $record.ManifestRecord = $manifestDriver
            $record.Id = [string](
                Get-PhoenixPropertyValue -InputObject $manifestDriver -Name 'InfName' -DefaultValue ''
            )
            $record.Name = [string](
                Get-PhoenixPropertyValue -InputObject $manifestDriver -Name 'Name' -DefaultValue $record.Id
            )
            $record.RequestedVersion = [string](
                Get-PhoenixPropertyValue -InputObject $manifestDriver -Name 'Version' -DefaultValue ''
            )
            $record.AvailableVersion = $record.RequestedVersion
            $record.Provider = 'Windows Update'
            $record.ProviderAlternatives = $oemAlternatives
            $record.RequiresElevation = $true
            $record.RebootRequired = $true
            $record.Eligible = -not [string]::IsNullOrWhiteSpace($record.Name)
            $installed = @(
                $installedDrivers | Where-Object {
                    (-not [string]::IsNullOrWhiteSpace($record.Id) -and $_.InfName -ieq $record.Id) -or
                    $_.Name -ieq $record.Name
                }
            ) | Select-Object -First 1
            if ($null -ne $installed) {
                $record.InstalledVersion = [string]$installed.Version
            }
            if (-not $record.Eligible) {
                $record.PlannedAction = 'Invalid'
                $record.Reason = 'Manifest driver record has no usable identity.'
            }
            elseif (
                $null -ne $installed -and
                $record.InstalledVersion -eq $record.RequestedVersion
            ) {
                $record.PlannedAction = 'AlreadySatisfied'
                $record.Reason = 'The requested driver version is already installed.'
            }
            else {
                $record.PlannedAction = if ($null -eq $installed) { 'Install' } else { 'Update' }
                $record.Selected = $true
                $record.Reason = 'Windows Update will evaluate the driver action.'
            }
            $record.Safety = 'Driver operations are serialized and may require restart.'
            $records.Add($record)
        }
    }

    $plan.Records = $records.ToArray()
    $plan.RefreshSummary()
    return $plan
}
