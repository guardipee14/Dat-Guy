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

        $this.SupportsCleanup = $true
        $this.CleanupAfterInstall = $true
        $this.CleanupOnFailure = $false

    }

#endregion 20-Providers\PhoenixProvider\PhoenixProvider.Header.ps1

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
