##########################################################
## Method: InstallPackageInteractive
## Legacy source line: 541
##########################################################

[Result] InstallPackageInteractive([Package]$Package) {

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
            'Chocolatey is not available.',
            'PHX_PROVIDER_UNAVAILABLE'
        )
    }

    $context = Get-PhoenixContext

    if ($null -eq $context) {

        return $this.NewFailure(
            'Phoenix context is unavailable.',
            'PHX_CONTEXT_UNAVAILABLE'
        )
    }

    if (-not $context.IsAdministrator) {

        return $this.NewFailure(
            'Chocolatey package installation requires administrator privileges.',
            'PHX_ELEVATION_REQUIRED'
        )
    }

    try {

        [string]$installRoot = $env:ChocolateyInstall

        if ([string]::IsNullOrWhiteSpace($installRoot)) {

            $installRoot = Join-Path `
                $env:ProgramData `
                'chocolatey'
        }

        [string]$chocoExecutable = Join-Path `
            $installRoot `
            'bin\choco.exe'

       if (-not (Test-Path -LiteralPath $chocoExecutable)) {

    return $this.NewFailure(
        "Chocolatey executable was not found at '$chocoExecutable'.",
        'PHX_PROVIDER_UNAVAILABLE'
    )
}

# Create a unique cache directory for this package installation.
[string]$workingDirectory =
    $this.NewPackageWorkingDirectory(
        $Package
    )

[string]$cacheArgument =
    "--cache-location=$workingDirectory"

Write-Host (
    "Starting the interactive installer for $($Package.Name) [$($Package.Id)]..."
) -ForegroundColor Yellow

& $chocoExecutable `
    install `
    $Package.Id `
    --yes `
    --not-silent `
    --no-progress `
    $cacheArgument |
    Out-Host

[int]$exitCode = $LASTEXITCODE

        if ($exitCode -notin @(0, 1641, 3010)) {

            $result = $this.NewFailure(
                "Interactive Chocolatey installation failed with exit code $exitCode.",
                'PHX_INSTALL_FAILED'
            )

            return $this.CompleteChocolateyResult(
                $result,
                $Package,
                'Install',
                $exitCode
            )
        }

        $Package.Installed = $true

        $result = [Result]::Success(
            "Installed $($Package.Id) interactively."
        )

        $result.Code = 'PHX_INSTALLED_INTERACTIVE'

        if ($exitCode -in @(1641, 3010)) {
            $result.Code = 'PHX_INSTALLED_REBOOT_REQUIRED'
        }

        return $this.CompleteChocolateyResult(
            $result,
            $Package,
            'Install',
            $exitCode
        )
    }
    catch {

        return $this.NewFailure(
            "Interactive Chocolatey installation failed: $($_.Exception.Message)",
            'PHX_INSTALL_FAILED'
        )
    }
}

