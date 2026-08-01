##########################################################
## Method: RepairPackageInteractive
##########################################################

[Result] RepairPackageInteractive(
    [Package]$Package
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

    if (-not $this.TestAvailable()) {

        return $this.NewFailure(
            'Chocolatey is unavailable.',
            'PHX_PROVIDER_UNAVAILABLE'
        )
    }

    try {

        [string]$chocoExecutable =
            $this.GetChocolateyExecutable()

        if (
            [string]::IsNullOrWhiteSpace(
                $chocoExecutable
            )
        ) {

            return $this.NewFailure(
                'Chocolatey executable could not be located.',
                'PHX_PROVIDER_UNAVAILABLE'
            )
        }

        [string]$workingDirectory =
            $this.NewPackageWorkingDirectory(
                $Package
            )

        [string[]]$arguments = @(
            'upgrade'
            $Package.Id
            '--yes'
            '--force'
            '--not-silent'
            '--no-progress'
            '--fail-on-unfound'
            '--fail-on-not-installed'
            "--cache-location=$workingDirectory"
        )

        if (
            -not [string]::IsNullOrWhiteSpace(
                $Package.Version
            )
        ) {

            $arguments +=
                "--version=$($Package.Version)"
        }

        Write-Host (
            "Starting interactive repair for $($Package.Name) [$($Package.Id)]..."
        ) -ForegroundColor Yellow

        & $chocoExecutable @arguments |
            Out-Host

        [int]$exitCode = $LASTEXITCODE

        if ($exitCode -notin @(0, 1641, 3010)) {

            $result = $this.NewFailure(
                "Interactive Chocolatey repair failed with exit code $exitCode.",
                'PHX_REPAIR_FAILED'
            )

            return $this.CompleteChocolateyResult(
                $result,
                $Package,
                'Repair',
                $exitCode
            )
        }

        [Result]$result = [Result]::Success(
            "Repaired $($Package.Id) interactively."
        )

        if ($exitCode -in @(1641, 3010)) {

            $result.Code =
                'PHX_REPAIRED_REBOOT_REQUIRED'
        }
        else {

            $result.Code =
                'PHX_REPAIRED_INTERACTIVE'
        }

        return $this.CompleteChocolateyResult(
            $result,
            $Package,
            'Repair',
            $exitCode
        )
    }
    catch {

        return $this.NewFailure(
            "Interactive Chocolatey repair failed: $($_.Exception.Message)",
            'PHX_REPAIR_FAILED'
        )
    }
}
