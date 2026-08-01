#region Composite class: PhoenixProvider

#region 20-Providers\PhoenixProvider\PhoenixProvider.Header.ps1
##########################################################
## PhoenixProvider composite class header
## Generated from the validated legacy provider
##########################################################

class PhoenixProvider {

    ##########################################################
    ## Properties
    ##########################################################

[string]$Name
[string]$Version
[string]$Type
[int]$Priority
[bool]$Available
[PhoenixPrivilegeLevel]$RequiredPrivilege
[bool]$SupportsSearch
[bool]$SupportsInventory
[bool]$SupportsInstall
[bool]$SupportsUpdate
[bool]$SupportsRemove
[bool]$SupportsExport
[bool]$SupportsOfflineCache
[bool]$SupportsDependencies
[bool]$SupportsSilentInstall
[bool]$SupportsInteractiveInstall
[bool]$SupportsRepair
[bool]$SupportsSilentRepair
[bool]$SupportsInteractiveRepair
[bool]$SupportsRestore
[bool]$SupportsCleanup
[bool]$CleanupAfterInstall
[bool]$CleanupOnFailure

    ##########################################################
    ## Constructor
    ##########################################################

PhoenixProvider() {

        $this.Name      = ""
        $this.Version   = ""
        $this.Type      = ""

        $this.Priority  = 0
        $this.Available = $false

        $this.SupportsSearch       = $true
        $this.SupportsInventory    = $true
        $this.SupportsInstall      = $true
        $this.SupportsUpdate       = $true
        $this.SupportsRemove       = $true
        $this.SupportsExport       = $false
        $this.SupportsOfflineCache = $false
        $this.SupportsDependencies = $false
        $this.SupportsSilentInstall      = $false
        $this.SupportsInteractiveInstall = $false
        $this.RequiredPrivilege = [PhoenixPrivilegeLevel]::User
        $this.SupportsRepair = $false
        $this.SupportsSilentRepair = $false
        $this.SupportsInteractiveRepair = $false
        $this.SupportsRestore = $true

        $this.SupportsCleanup = $true
        $this.CleanupAfterInstall = $true
        $this.CleanupOnFailure = $false

    }

#endregion 20-Providers\PhoenixProvider\PhoenixProvider.Header.ps1

#region 20-Providers\PhoenixProvider\Methods\10-ProviderManagement\GetCapability.ps1
##########################################################
## Method: GetCapability
##########################################################

[PhoenixProviderCapability] GetCapability() {

    $capability = [PhoenixProviderCapability]::new()
    $capability.ProviderName = $this.Name
    $capability.ProviderVersion = $this.Version
    $capability.Available = $this.Available
    $capability.RequiredPrivilege = $this.RequiredPrivilege
    $capability.SupportsSearch = $this.SupportsSearch
    $capability.SupportsInventory = $this.SupportsInventory
    $capability.SupportsInstall = $this.SupportsInstall
    $capability.SupportsUpdate = $this.SupportsUpdate
    $capability.SupportsRepair = $this.SupportsRepair
    $capability.SupportsRemove = $this.SupportsRemove
    $capability.SupportsExport = $this.SupportsExport
    $capability.SupportsRestore = $this.SupportsRestore
    $capability.CheckedAtUtc = [datetime]::UtcNow

    if ($this.Available) {
        $capability.Availability =
            [PhoenixProviderAvailability]::Available
        $capability.HealthMessage = 'Ready'
    }
    else {
        $capability.Availability =
            [PhoenixProviderAvailability]::Unavailable
        $capability.HealthMessage =
            'Executable or service was not detected.'
    }

    $operationNames =
        [System.Collections.Generic.List[string]]::new()

    foreach (
        $operation in @(
            [PhoenixProviderOperation]::Search
            [PhoenixProviderOperation]::Inventory
            [PhoenixProviderOperation]::Install
            [PhoenixProviderOperation]::Update
            [PhoenixProviderOperation]::Repair
            [PhoenixProviderOperation]::Remove
            [PhoenixProviderOperation]::Export
            [PhoenixProviderOperation]::Restore
        )
    ) {
        if ($this.SupportsOperation($operation)) {
            $operationNames.Add($operation.ToString())
        }
    }

    $capability.SupportedOperations =
        $operationNames.ToArray()

    return $capability
}
#endregion 20-Providers\PhoenixProvider\Methods\10-ProviderManagement\GetCapability.ps1

#region 20-Providers\PhoenixProvider\Methods\10-ProviderManagement\InstallProvider.ps1
##########################################################
## Method: InstallProvider
## Legacy source line: 74
##########################################################

[Result] InstallProvider() {

        return [Result]::Failure(
            "$($this.Name) cannot install itself."
        )

    }

#endregion 20-Providers\PhoenixProvider\Methods\10-ProviderManagement\InstallProvider.ps1

#region 20-Providers\PhoenixProvider\Methods\10-ProviderManagement\NormalizeData.ps1
##########################################################
## Method: NormalizeData
##########################################################

[PhoenixProviderResult] NormalizeData(
    [object]$Data,
    [PhoenixProviderOperation]$Operation,
    [string]$Target
) {

    $sourceResult = [Result]::Success($Data)

    return $this.NormalizeResult(
        $sourceResult,
        $Operation,
        $Target
    )
}
#endregion 20-Providers\PhoenixProvider\Methods\10-ProviderManagement\NormalizeData.ps1

#region 20-Providers\PhoenixProvider\Methods\10-ProviderManagement\NormalizeResult.ps1
##########################################################
## Method: NormalizeResult
##########################################################

[PhoenixProviderResult] NormalizeResult(
    [Result]$Result,
    [PhoenixProviderOperation]$Operation,
    [string]$Target
) {

    $normalized = [PhoenixProviderResult]::new()
    $normalized.ProviderName = $this.Name
    $normalized.Operation = $Operation
    $normalized.Target = $Target
    $normalized.RequiredPrivilege = $this.RequiredPrivilege

    if ($null -eq $Result) {
        $normalized.Success = $false
        $normalized.Code = 'PHX_PROVIDER_RESULT_MISSING'
        $normalized.Message =
            'The provider returned no result.'
        $normalized.Errors = @($normalized.Message)

        return $normalized
    }

    $normalized.Success = $Result.Success
    $normalized.Code = $Result.Code
    $normalized.Message = $Result.Message
    $normalized.Data = $Result.Data

    if ($Result.Timestamp -gt [datetime]::MinValue) {
        $normalized.Timestamp =
            $Result.Timestamp.ToUniversalTime()
    }

    $warningItems =
        [System.Collections.Generic.List[string]]::new()

    foreach ($warning in @($Result.Warnings)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$warning)) {
            $warningItems.Add([string]$warning)
        }
    }

    $errorItems =
        [System.Collections.Generic.List[string]]::new()

    foreach ($resultError in @($Result.Errors)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$resultError)) {
            $errorItems.Add([string]$resultError)
        }
    }

    if (
        -not $Result.Success -and
        $errorItems.Count -eq 0 -and
        -not [string]::IsNullOrWhiteSpace($Result.Message)
    ) {
        $errorItems.Add($Result.Message)
    }

    $metadataCandidates =
        [System.Collections.Generic.List[object]]::new()

    $metadataCandidates.Add($Result)

    if ($null -ne $Result.Data) {
        foreach ($dataItem in @($Result.Data)) {
            if ($null -ne $dataItem) {
                $metadataCandidates.Add($dataItem)
            }
        }
    }

    foreach ($candidate in $metadataCandidates) {
        $exitCodeProperty =
            $candidate.PSObject.Properties['ExitCode']

        if (
            $null -ne $exitCodeProperty -and
            $null -ne $exitCodeProperty.Value
        ) {
            $normalized.ExitCode =
                [int]$exitCodeProperty.Value
            $normalized.HasExitCode = $true
        }

        foreach (
            $restartPropertyName in @(
                'RequiresRestart'
                'RebootRequired'
                'RestartRequired'
            )
        ) {
            $restartProperty =
                $candidate.PSObject.Properties[
                    $restartPropertyName
                ]

            if (
                $null -ne $restartProperty -and
                [bool]$restartProperty.Value
            ) {
                $normalized.RequiresRestart = $true
            }
        }

        foreach (
            $timeoutPropertyName in @(
                'TimedOut'
                'Timeout'
            )
        ) {
            $timeoutProperty =
                $candidate.PSObject.Properties[
                    $timeoutPropertyName
                ]

            if (
                $null -ne $timeoutProperty -and
                [bool]$timeoutProperty.Value
            ) {
                $normalized.TimedOut = $true
            }
        }

        foreach (
            $cancelPropertyName in @(
                'Cancelled'
                'Canceled'
            )
        ) {
            $cancelProperty =
                $candidate.PSObject.Properties[
                    $cancelPropertyName
                ]

            if (
                $null -ne $cancelProperty -and
                [bool]$cancelProperty.Value
            ) {
                $normalized.Cancelled = $true
            }
        }
    }

    $normalized.Warnings = $warningItems.ToArray()
    $normalized.Errors = $errorItems.ToArray()

    if ([string]::IsNullOrWhiteSpace($normalized.Code)) {
        [string]$operationName =
            $Operation.ToString().ToUpperInvariant()

        $normalized.Code = if ($normalized.Success) {
            "PHX_PROVIDER_$($operationName)_SUCCEEDED"
        }
        else {
            "PHX_PROVIDER_$($operationName)_FAILED"
        }
    }

    return $normalized
}
#endregion 20-Providers\PhoenixProvider\Methods\10-ProviderManagement\NormalizeResult.ps1

#region 20-Providers\PhoenixProvider\Methods\10-ProviderManagement\SupportsOperation.ps1
##########################################################
## Method: SupportsOperation
##########################################################

[bool] SupportsOperation(
    [PhoenixProviderOperation]$Operation
) {

    if ($Operation -eq [PhoenixProviderOperation]::Search) {
        return $this.SupportsSearch
    }

    if ($Operation -eq [PhoenixProviderOperation]::Inventory) {
        return $this.SupportsInventory
    }

    if ($Operation -eq [PhoenixProviderOperation]::Install) {
        return $this.SupportsInstall
    }

    if ($Operation -eq [PhoenixProviderOperation]::Update) {
        return $this.SupportsUpdate
    }

    if ($Operation -eq [PhoenixProviderOperation]::Repair) {
        return $this.SupportsRepair
    }

    if ($Operation -eq [PhoenixProviderOperation]::Remove) {
        return $this.SupportsRemove
    }

    if ($Operation -eq [PhoenixProviderOperation]::Export) {
        return $this.SupportsExport
    }

    if ($Operation -eq [PhoenixProviderOperation]::Restore) {
        return $this.SupportsRestore
    }

    return $false
}
#endregion 20-Providers\PhoenixProvider\Methods\10-ProviderManagement\SupportsOperation.ps1

#region 20-Providers\PhoenixProvider\Methods\10-ProviderManagement\TestAvailable.ps1
##########################################################
## Method: TestAvailable
## Legacy source line: 68
##########################################################

[bool] TestAvailable() {

        return $false

    }

#endregion 20-Providers\PhoenixProvider\Methods\10-ProviderManagement\TestAvailable.ps1

#region 20-Providers\PhoenixProvider\Methods\10-ProviderManagement\UpdateProvider.ps1
##########################################################
## Method: UpdateProvider
## Legacy source line: 82
##########################################################

[Result] UpdateProvider() {

        return [Result]::Failure(
            "$($this.Name) cannot update itself."
        )

    }

#endregion 20-Providers\PhoenixProvider\Methods\10-ProviderManagement\UpdateProvider.ps1

#region 20-Providers\PhoenixProvider\Methods\20-Discovery\GetInstalledPackages.ps1
##########################################################
## Method: GetInstalledPackages
## Legacy source line: 94
##########################################################

[Package[]] GetInstalledPackages() {

        return @()

    }

#endregion 20-Providers\PhoenixProvider\Methods\20-Discovery\GetInstalledPackages.ps1

#region 20-Providers\PhoenixProvider\Methods\20-Discovery\SearchPackage.ps1
##########################################################
## Method: SearchPackage
## Legacy source line: 100
##########################################################

[Package[]] SearchPackage([string]$Name) {

        return @()

    }

#endregion 20-Providers\PhoenixProvider\Methods\20-Discovery\SearchPackage.ps1

#region 20-Providers\PhoenixProvider\Methods\30-Installation\CanInstallSilently.ps1
##########################################################
## Method: CanInstallSilently
## Legacy source line: 286
##########################################################

[bool] CanInstallSilently([Package]$Package) {

        return $this.SupportsSilentInstall
    }

#endregion 20-Providers\PhoenixProvider\Methods\30-Installation\CanInstallSilently.ps1

#region 20-Providers\PhoenixProvider\Methods\30-Installation\InstallPackage.ps1
##########################################################
## Method: InstallPackage
## Legacy source line: 307
##########################################################

[Result] InstallPackage([Package]$Package) {

    return $this.InstallPackage(
        $Package,
        [PhoenixInstallMode]::SilentPreferred
    )
}

#endregion 20-Providers\PhoenixProvider\Methods\30-Installation\InstallPackage.ps1

#region 20-Providers\PhoenixProvider\Methods\30-Installation\InstallPackageCore.ps1
##########################################################
## Method: InstallPackageCore
## Legacy source line: 383
##########################################################

hidden [Result] InstallPackageCore(
    [Package]$Package,
    [PhoenixInstallMode]$Mode
) {

    if ($null -eq $Package) {

        return $this.NewFailure(
            'A package object is required.',
            'PHX_INVALID_PACKAGE'
        )
    }

    if ([string]::IsNullOrWhiteSpace($Package.Id)) {

        return $this.NewFailure(
            'The package ID is required.',
            'PHX_INVALID_PACKAGE'
        )
    }

    if ($Mode -eq [PhoenixInstallMode]::InteractiveOnly) {

        if (-not $this.SupportsInteractiveInstall) {

            return $this.NewFailure(
                "$($this.Name) does not support interactive installation.",
                'PHX_INTERACTIVE_UNAVAILABLE'
            )
        }

        return $this.InstallPackageInteractive(
            $Package
        )
    }

    if ($Mode -eq [PhoenixInstallMode]::SilentOnly) {

        if (-not $this.CanInstallSilently($Package)) {

            return $this.NewFailure(
                "No silent installation is available for '$($Package.Id)'.",
                'PHX_SILENT_UNAVAILABLE'
            )
        }

        return $this.InstallPackageSilent(
            $Package
        )
    }

    # SilentPreferred
    if ($this.CanInstallSilently($Package)) {

        [Result]$silentResult = $this.InstallPackageSilent(
            $Package
        )

        if ($silentResult.Success) {
            return $silentResult
        }

        # Only use interactive fallback when silent mode
        # is explicitly unavailable.
        if ($silentResult.Code -ne 'PHX_SILENT_UNAVAILABLE') {
            return $silentResult
        }
    }

    if ($this.SupportsInteractiveInstall) {

        Write-Host (
            "No silent installer is available for '$($Package.Id)'."
        ) -ForegroundColor Yellow

        Write-Host (
            'Starting the interactive installer...'
        ) -ForegroundColor Yellow

        return $this.InstallPackageInteractive(
            $Package
        )
    }

    return $this.NewFailure(
        "Neither silent nor interactive installation is available for '$($Package.Id)'.",
        'PHX_INSTALL_UNAVAILABLE'
    )
}

#endregion 20-Providers\PhoenixProvider\Methods\30-Installation\InstallPackageCore.ps1

#region 20-Providers\PhoenixProvider\Methods\30-Installation\InstallPackageInteractive.ps1
##########################################################
## Method: InstallPackageInteractive
## Legacy source line: 299
##########################################################

[Result] InstallPackageInteractive([Package]$Package) {

        return $this.NewFailure(
            "$($this.Name) does not implement interactive installation.",
            'PHX_INTERACTIVE_UNAVAILABLE'
        )
    }

#endregion 20-Providers\PhoenixProvider\Methods\30-Installation\InstallPackageInteractive.ps1

#region 20-Providers\PhoenixProvider\Methods\30-Installation\InstallPackageSilent.ps1
##########################################################
## Method: InstallPackageSilent
## Legacy source line: 291
##########################################################

[Result] InstallPackageSilent([Package]$Package) {

        return $this.NewFailure(
            "$($this.Name) does not implement silent installation.",
            'PHX_SILENT_UNAVAILABLE'
        )
    }

#endregion 20-Providers\PhoenixProvider\Methods\30-Installation\InstallPackageSilent.ps1

#region 20-Providers\PhoenixProvider\Methods\30-Installation\InstallPackageWithMode.ps1
##########################################################
## Method: InstallPackage
## Legacy source line: 315
##########################################################

[Result] InstallPackage(
    [Package]$Package,
    [PhoenixInstallMode]$Mode
) {

    [Result]$installResult = [Result]::Failure(
        'Package installation did not complete.'
    )

    try {

        $installResult = $this.InstallPackageCore(
            $Package,
            $Mode
        )
    }
    catch {

        $installResult = $this.NewFailure(
            "Package installation failed: $($_.Exception.Message)",
            'PHX_INSTALL_FAILED'
        )
    }
    finally {

        [bool]$shouldCleanup = (
            $null -ne $Package -and
            $this.SupportsCleanup -and
            $this.CleanupAfterInstall -and
            (-not $Package.PreserveDownloads) -and
            (
                $installResult.Success -or
                $this.CleanupOnFailure
            )
        )

        if ($shouldCleanup) {

            [Result]$cleanupResult = $this.CleanupPackage(
                $Package
            )

            if (-not $cleanupResult.Success) {

                $installResult.Warnings = @(
                    $installResult.Warnings
                ) + @(
                    $cleanupResult.Message
                )

                if (
                    $null -ne $cleanupResult.Errors -and
                    $cleanupResult.Errors.Count -gt 0
                ) {

                    $installResult.Warnings = @(
                        $installResult.Warnings
                    ) + @(
                        $cleanupResult.Errors
                    )
                }
            }
        }
    }

    return $installResult
}

#endregion 20-Providers\PhoenixProvider\Methods\30-Installation\InstallPackageWithMode.ps1

#region 20-Providers\PhoenixProvider\Methods\30-Installation\NewFailure.ps1
##########################################################
## Method: NewFailure
## Legacy source line: 275
##########################################################

hidden [Result] NewFailure(
        [string]$Message,
        [string]$Code
    ) {

        $result = [Result]::Failure($Message)
        $result.Code = $Code

        return $result
    }

#endregion 20-Providers\PhoenixProvider\Methods\30-Installation\NewFailure.ps1

#region 20-Providers\PhoenixProvider\Methods\40-Cleanup\CleanupPackage.ps1
##########################################################
## Method: CleanupPackage
## Legacy source line: 184
##########################################################

[Result] CleanupPackage([Package]$Package) {

    if ($null -eq $Package) {

        return $this.NewFailure(
            'A package object is required for cleanup.',
            'PHX_INVALID_PACKAGE'
        )
    }

    if ($Package.PreserveDownloads) {

        $result = [Result]::Success(
            'Package downloads were preserved.'
        )

        $result.Code = 'PHX_CLEANUP_SKIPPED'

        return $result
    }

    $cleanupErrors =
        [System.Collections.Generic.List[string]]::new()

    [string[]]$paths = @(
        $Package.CleanupPaths
    ) |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace($_)
        } |
        Sort-Object Length -Descending -Unique

    foreach ($path in $paths) {

        if (-not $this.IsPhoenixManagedPath($path)) {

            $cleanupErrors.Add(
                "Refused to delete a non-Phoenix path: $path"
            )

            continue
        }

        try {

            if (Test-Path -LiteralPath $path) {

                Remove-Item `
                    -LiteralPath $path `
                    -Recurse `
                    -Force `
                    -ErrorAction Stop
            }
        }
        catch {

            $cleanupErrors.Add(
                "Failed to remove '$path': $($_.Exception.Message)"
            )
        }
    }

    $Package.WorkingDirectory = ''
    $Package.DownloadedFile = ''
    $Package.CleanupPaths = @()

    if ($cleanupErrors.Count -gt 0) {

        $result = $this.NewFailure(
            'One or more cleanup operations failed.',
            'PHX_CLEANUP_FAILED'
        )

        $result.Errors = $cleanupErrors.ToArray()

        return $result
    }

    $result = [Result]::Success(
        "Cleanup completed for '$($Package.Id)'."
    )

    $result.Code = 'PHX_CLEANUP_COMPLETE'

    return $result
}

#endregion 20-Providers\PhoenixProvider\Methods\40-Cleanup\CleanupPackage.ps1

#region 20-Providers\PhoenixProvider\Methods\40-Cleanup\IsPhoenixManagedPath.ps1
##########################################################
## Method: IsPhoenixManagedPath
## Legacy source line: 147
##########################################################

hidden [bool] IsPhoenixManagedPath(
    [string]$Path
) {

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    $context = Get-PhoenixContext

    if ($null -eq $context) {
        return $false
    }

    try {

        [string]$workingRoot = (
            [IO.Path]::GetFullPath(
                $context.WorkingRoot
            ).TrimEnd('\') + '\'
        )

        [string]$candidatePath = (
            [IO.Path]::GetFullPath($Path)
        )

        return $candidatePath.StartsWith(
            $workingRoot,
            [StringComparison]::OrdinalIgnoreCase
        )
    }
    catch {

        return $false
    }
}

#endregion 20-Providers\PhoenixProvider\Methods\40-Cleanup\IsPhoenixManagedPath.ps1

#region 20-Providers\PhoenixProvider\Methods\40-Cleanup\NewPackageWorkingDirectory.ps1
##########################################################
## Method: NewPackageWorkingDirectory
## Legacy source line: 106
##########################################################

hidden [string] NewPackageWorkingDirectory(
    [Package]$Package
) {

    $context = Get-PhoenixContext

    if ($null -eq $context) {
        throw 'Phoenix context is unavailable.'
    }

    [string]$safePackageId = [regex]::Replace(
        $Package.Id,
        '[^a-zA-Z0-9._-]',
        '_'
    )

    [string]$directoryName = '{0}-{1}' -f `
        $safePackageId,
        [guid]::NewGuid().ToString('N')

    [string]$workingDirectory = Join-Path `
        $context.WorkingRoot `
        $directoryName

    New-Item `
        -ItemType Directory `
        -Path $workingDirectory `
        -Force |
        Out-Null

    $Package.WorkingDirectory = $workingDirectory

    $Package.CleanupPaths = @(
        $Package.CleanupPaths
    ) + @(
        $workingDirectory
    )

    return $workingDirectory
}

#endregion 20-Providers\PhoenixProvider\Methods\40-Cleanup\NewPackageWorkingDirectory.ps1

#region 20-Providers\PhoenixProvider\Methods\50-Repair\CanRepairSilently.ps1
##########################################################
## Method: CanRepairSilently
## Legacy source line: 473
##########################################################

[bool] CanRepairSilently([Package]$Package) {

    return $this.SupportsSilentRepair
}

#endregion 20-Providers\PhoenixProvider\Methods\50-Repair\CanRepairSilently.ps1

#region 20-Providers\PhoenixProvider\Methods\50-Repair\RepairPackage.ps1
##########################################################
## Method: RepairPackage
## Legacy source line: 494
##########################################################

[Result] RepairPackage([Package]$Package) {

    return $this.RepairPackage(
        $Package,
        [PhoenixInstallMode]::SilentPreferred
    )
}

#endregion 20-Providers\PhoenixProvider\Methods\50-Repair\RepairPackage.ps1

#region 20-Providers\PhoenixProvider\Methods\50-Repair\RepairPackageInteractive.ps1
##########################################################
## Method: RepairPackageInteractive
## Legacy source line: 486
##########################################################

[Result] RepairPackageInteractive([Package]$Package) {

    return $this.NewFailure(
        "$($this.Name) does not implement interactive repair.",
        'PHX_INTERACTIVE_REPAIR_UNAVAILABLE'
    )
}

#endregion 20-Providers\PhoenixProvider\Methods\50-Repair\RepairPackageInteractive.ps1

#region 20-Providers\PhoenixProvider\Methods\50-Repair\RepairPackageSilent.ps1
##########################################################
## Method: RepairPackageSilent
## Legacy source line: 478
##########################################################

[Result] RepairPackageSilent([Package]$Package) {

    return $this.NewFailure(
        "$($this.Name) does not implement silent repair.",
        'PHX_SILENT_REPAIR_UNAVAILABLE'
    )
}

#endregion 20-Providers\PhoenixProvider\Methods\50-Repair\RepairPackageSilent.ps1

#region 20-Providers\PhoenixProvider\Methods\50-Repair\RepairPackageWithMode.ps1
##########################################################
## Method: RepairPackage
## Legacy source line: 502
##########################################################

[Result] RepairPackage(
    [Package]$Package,
    [PhoenixInstallMode]$Mode
) {

    [Result]$repairResult = [Result]::Failure(
        'Package repair did not complete.'
    )

    try {

        if ($null -eq $Package) {

            $repairResult = $this.NewFailure(
                'A package object is required.',
                'PHX_INVALID_PACKAGE'
            )
        }
        elseif (-not $this.SupportsRepair) {

            $repairResult = $this.NewFailure(
                "$($this.Name) does not support package repair.",
                'PHX_REPAIR_UNAVAILABLE'
            )
        }
        elseif (
            $Mode -eq
            [PhoenixInstallMode]::InteractiveOnly
        ) {

            if (-not $this.SupportsInteractiveRepair) {

                $repairResult = $this.NewFailure(
                    'Interactive repair is unavailable.',
                    'PHX_INTERACTIVE_REPAIR_UNAVAILABLE'
                )
            }
            else {

                $repairResult =
                    $this.RepairPackageInteractive(
                        $Package
                    )
            }
        }
        elseif (
            $Mode -eq
            [PhoenixInstallMode]::SilentOnly
        ) {

            if (-not $this.CanRepairSilently($Package)) {

                $repairResult = $this.NewFailure(
                    'Silent repair is unavailable.',
                    'PHX_SILENT_REPAIR_UNAVAILABLE'
                )
            }
            else {

                $repairResult =
                    $this.RepairPackageSilent(
                        $Package
                    )
            }
        }
        elseif ($this.CanRepairSilently($Package)) {

            $repairResult =
                $this.RepairPackageSilent(
                    $Package
                )

            if (
                (-not $repairResult.Success) -and
                $repairResult.Code -eq
                    'PHX_SILENT_REPAIR_UNAVAILABLE' -and
                $this.SupportsInteractiveRepair
            ) {

                $repairResult =
                    $this.RepairPackageInteractive(
                        $Package
                    )
            }
        }
        elseif ($this.SupportsInteractiveRepair) {

            $repairResult =
                $this.RepairPackageInteractive(
                    $Package
                )
        }
        else {

            $repairResult = $this.NewFailure(
                'No repair method is available.',
                'PHX_REPAIR_UNAVAILABLE'
            )
        }
    }
    catch {

        $repairResult = $this.NewFailure(
            "Package repair failed: $($_.Exception.Message)",
            'PHX_REPAIR_FAILED'
        )
    }
    finally {

        if (
            $null -ne $Package -and
            $this.SupportsCleanup -and
            $this.CleanupAfterInstall -and
            (-not $Package.PreserveDownloads) -and
            (
                $repairResult.Success -or
                $this.CleanupOnFailure
            )
        ) {

            $cleanupResult =
                $this.CleanupPackage($Package)

            if (-not $cleanupResult.Success) {

                $repairResult.Warnings = @(
                    $repairResult.Warnings
                ) + @(
                    $cleanupResult.Message
                )
            }
        }
    }

    return $repairResult
}

#endregion 20-Providers\PhoenixProvider\Methods\50-Repair\RepairPackageWithMode.ps1

#region 20-Providers\PhoenixProvider\Methods\60-PackageManagement\RemovePackage.ps1
##########################################################
## Method: RemovePackage
## Legacy source line: 647
##########################################################

[Result] RemovePackage([Package]$Package) {

        return [Result]::Failure(
            'RemovePackage() is not implemented.'
        )
    }

#endregion 20-Providers\PhoenixProvider\Methods\60-PackageManagement\RemovePackage.ps1

#region 20-Providers\PhoenixProvider\Methods\60-PackageManagement\UpdatePackage.ps1
##########################################################
## Method: UpdatePackage
## Legacy source line: 640
##########################################################

[Result] UpdatePackage([Package]$Package) {

        return [Result]::Failure(
            'UpdatePackage() is not implemented.'
        )
    }

#endregion 20-Providers\PhoenixProvider\Methods\60-PackageManagement\UpdatePackage.ps1

#region 20-Providers\PhoenixProvider\PhoenixProvider.Footer.ps1
##########################################################
## PhoenixProvider composite class footer
##########################################################

}
#endregion 20-Providers\PhoenixProvider\PhoenixProvider.Footer.ps1

#endregion Composite class: PhoenixProvider
