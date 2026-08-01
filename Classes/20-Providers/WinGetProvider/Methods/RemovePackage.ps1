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
            'WinGet is unavailable.',
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
            "Removing $($Package.Name) [$($Package.Id)] silently..."
        ) -ForegroundColor Yellow

        & $command.Source `
            uninstall `
            --id $Package.Id `
            --exact `
            --source winget `
            --silent `
            --disable-interactivity `
            --accept-source-agreements |
            Out-Host

        [int]$exitCode = $LASTEXITCODE

        if ($exitCode -ne 0) {

            $result = $this.NewFailure(
                "WinGet removal failed with exit code $exitCode.",
                'PHX_REMOVE_FAILED'
            )
            $result.Provider = $this.Name
            $result.Operation = 'Remove'
            $result.Target = $Package.Id
            $result.HasExitCode = $true
            $result.ExitCode = $exitCode
            $result.Data = $Package

            return $result
        }

        $Package.Installed = $false

        [Result]$result = [Result]::Success(
            "Removed $($Package.Id) successfully."
        )

        $result.Code = 'PHX_REMOVED'
        $result.Provider = $this.Name
        $result.Operation = 'Remove'
        $result.Target = $Package.Id
        $result.HasExitCode = $true
        $result.ExitCode = $exitCode
        $result.Data = $Package

        return $result
    }
    catch {

        return $this.NewFailure(
            "WinGet removal failed: $($_.Exception.Message)",
            'PHX_REMOVE_FAILED'
        )
    }
}
