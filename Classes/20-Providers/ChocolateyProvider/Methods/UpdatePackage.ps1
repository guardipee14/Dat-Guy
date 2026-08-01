##########################################################
## Method: UpdatePackage
##########################################################

[Result] UpdatePackage([Package]$Package) {

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
            '--no-progress'
            '--fail-on-unfound'
            '--fail-on-not-installed'
            "--cache-location=$workingDirectory"
        )

        Write-Host (
            "Updating $($Package.Name) [$($Package.Id)] silently..."
        ) -ForegroundColor Cyan

        & $chocoExecutable @arguments |
            Out-Host

        [int]$exitCode = $LASTEXITCODE

        if ($exitCode -eq 2) {

            $Package.Installed = $true

            [Result]$result = [Result]::Success()

            $result.Code = 'PHX_ALREADY_CURRENT'
            $result.Message = (
                "$($Package.Id) is already current."
            )
            $result.Data = $Package

            return $this.CompleteChocolateyResult(
                $result,
                $Package,
                'Update',
                $exitCode
            )
        }

        if ($exitCode -in @(1641, 3010)) {

            $Package.Installed = $true

            [Result]$result = [Result]::Success()

            $result.Code =
                'PHX_UPDATED_REBOOT_REQUIRED'

            $result.Message = (
                "Updated $($Package.Id); a reboot is required."
            )
            $result.Data = $Package

            return $this.CompleteChocolateyResult(
                $result,
                $Package,
                'Update',
                $exitCode
            )
        }

        if ($exitCode -ne 0) {

            $result = $this.NewFailure(
                "Chocolatey update failed with exit code $exitCode.",
                'PHX_UPDATE_FAILED'
            )

            return $this.CompleteChocolateyResult(
                $result,
                $Package,
                'Update',
                $exitCode
            )
        }

        $Package.Installed = $true

        [Result]$result = [Result]::Success()

        $result.Code = 'PHX_UPDATED'
        $result.Message = (
            "Updated $($Package.Id) successfully."
        )
        $result.Data = $Package

        return $this.CompleteChocolateyResult(
            $result,
            $Package,
            'Update',
            $exitCode
        )
    }
    catch {

        return $this.NewFailure(
            "Chocolatey update failed: $($_.Exception.Message)",
            'PHX_UPDATE_FAILED'
        )
    }
}
