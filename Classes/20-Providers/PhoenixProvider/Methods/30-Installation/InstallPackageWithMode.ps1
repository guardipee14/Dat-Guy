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

