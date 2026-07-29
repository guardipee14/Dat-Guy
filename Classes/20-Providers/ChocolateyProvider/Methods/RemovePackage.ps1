##########################################################
## Method: RemovePackage
##########################################################

[Result] RemovePackage([Package]$Package) {

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

        if ([string]::IsNullOrWhiteSpace($chocoExecutable)) {

            return $this.NewFailure(
                'Chocolatey executable could not be located.',
                'PHX_PROVIDER_UNAVAILABLE'
            )
        }

        Write-Host (
            "Removing $($Package.Name) [$($Package.Id)] silently..."
        ) -ForegroundColor Yellow

        & $chocoExecutable `
            uninstall `
            $Package.Id `
            --yes `
            --no-progress |
            Out-Host

        [int]$exitCode = $LASTEXITCODE

        if ($exitCode -eq 1605) {

            $Package.Installed = $false

            [Result]$result = [Result]::Success()
            $result.Code = 'PHX_ALREADY_REMOVED'
            $result.Message = (
                "$($Package.Id) is not installed."
            )
            $result.Data = $Package

            return $result
        }

        if ($exitCode -in @(1641, 3010)) {

            $Package.Installed = $false

            [Result]$result = [Result]::Success()
            $result.Code = 'PHX_REMOVED_REBOOT_REQUIRED'
            $result.Message = (
                "Removed $($Package.Id); a reboot is required."
            )
            $result.Data = $Package

            return $result
        }

        if ($exitCode -notin @(0, 1614)) {

            return $this.NewFailure(
                "Chocolatey removal failed with exit code $exitCode.",
                'PHX_REMOVE_FAILED'
            )
        }

        $Package.Installed = $false

        [Result]$result = [Result]::Success()
        $result.Code = 'PHX_REMOVED'
        $result.Message = (
            "Removed $($Package.Id) successfully."
        )
        $result.Data = $Package

        return $result
    }
    catch {

        return $this.NewFailure(
            "Chocolatey removal failed: $($_.Exception.Message)",
            'PHX_REMOVE_FAILED'
        )
    }
}