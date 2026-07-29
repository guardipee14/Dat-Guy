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

