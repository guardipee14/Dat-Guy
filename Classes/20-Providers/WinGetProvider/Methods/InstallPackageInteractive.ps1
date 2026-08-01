##########################################################
## Method: InstallPackageInteractive
##########################################################

[Result] InstallPackageInteractive([Package]$Package) {

    if ($null -eq $Package -or [string]::IsNullOrWhiteSpace($Package.Id)) {
        return $this.NewFailure(
            'A package with an ID is required.',
            'PHX_INVALID_PACKAGE'
        )
    }

    if (-not $this.TestAvailable()) {
        return $this.NewFailure(
            'WinGet is not available.',
            'PHX_PROVIDER_UNAVAILABLE'
        )
    }

    try {
        $command = Get-Command winget.exe -ErrorAction SilentlyContinue

        if ($null -eq $command) {
            return $this.NewFailure(
                'winget.exe could not be located.',
                'PHX_PROVIDER_UNAVAILABLE'
            )
        }

        $wingetOutput = @()

        & $command.Source `
            install `
            --id $Package.Id `
            --exact `
            --source winget `
            --interactive `
            --accept-package-agreements `
            --accept-source-agreements `
            --no-upgrade `
            2>&1 |
            Tee-Object -Variable wingetOutput |
            Out-Host

        [int]$exitCode = $LASTEXITCODE
        [bool]$alreadyInstalled =
            $exitCode -eq -1978335135
        [bool]$rebootRequired =
            $exitCode -in @(1641, 3010)

        $result = if (
            $exitCode -eq 0 -or
            $alreadyInstalled -or
            $rebootRequired
        ) {
            [Result]::Success()
        }
        else {
            [Result]::Failure(
                "Interactive WinGet installation failed with exit code $exitCode."
            )
        }

        $result.Provider = $this.Name
        $result.Operation = 'Install'
        $result.Target = $Package.Id
        $result.HasExitCode = $true
        $result.ExitCode = $exitCode
        $result.RebootRequired = $rebootRequired
        $result.Data = $Package

        if ($result.Success) {
            $Package.Installed = $true
            $result.Code = if ($alreadyInstalled) {
                'PHX_ALREADY_INSTALLED'
            }
            elseif ($rebootRequired) {
                'PHX_INSTALLED_RESTART_REQUIRED'
            }
            else {
                'PHX_INSTALLED_INTERACTIVE'
            }
            $result.Message =
                "Installed '$($Package.Id)' interactively."
        }
        else {
            $result.Code = 'PHX_INSTALL_FAILED'
            $result.Errors = @(
                $wingetOutput |
                    ForEach-Object { $_.ToString() }
            )
        }

        return $result
    }
    catch {
        return $this.NewFailure(
            "Interactive WinGet installation failed: $($_.Exception.Message)",
            'PHX_INSTALL_FAILED'
        )
    }
}
