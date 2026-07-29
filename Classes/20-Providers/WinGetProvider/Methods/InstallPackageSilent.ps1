##########################################################
## Method: InstallPackageSilent
## Legacy source line: 422
##########################################################

[Result] InstallPackageSilent([Package]$Package) {

    if (-not $this.TestAvailable()) {

        return $this.NewFailure(
            'WinGet is not available.',
            'PHX_PROVIDER_UNAVAILABLE'
        )
    }

    try {

        $command = Get-Command `
            winget.exe `
            -ErrorAction SilentlyContinue

        if ($null -eq $command) {

            return $this.NewFailure(
                'winget.exe could not be located.',
                'PHX_PROVIDER_UNAVAILABLE'
            )
        }

        Write-Host (
            "Installing $($Package.Name) silently..."
        ) -ForegroundColor Cyan

        & $command.Source `
            install `
            --id $Package.Id `
            --exact `
            --source winget `
            --silent `
            --disable-interactivity `
            --accept-package-agreements `
            --accept-source-agreements `
            --no-upgrade |
            Out-Host

        [int]$exitCode = $LASTEXITCODE

        if ($exitCode -eq -1978335135) {

            $Package.Installed = $true

            $result = [Result]::Success()
            $result.Code = 'PHX_ALREADY_INSTALLED'
            $result.Message = (
                "'$($Package.Id)' is already installed."
            )

            return $result
        }

        if ($exitCode -ne 0) {

            return $this.NewFailure(
                "Silent WinGet installation failed with exit code $exitCode.",
                'PHX_INSTALL_FAILED'
            )
        }

        $Package.Installed = $true

        $result = [Result]::Success()
        $result.Code = 'PHX_INSTALLED'
        $result.Message = (
            "Installed '$($Package.Id)' silently."
        )

        return $result
    }
    catch {

        return $this.NewFailure(
            "WinGet installation failed: $($_.Exception.Message)",
            'PHX_INSTALL_FAILED'
        )
    }
}