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

