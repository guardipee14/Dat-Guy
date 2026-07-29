##########################################################
## Method: CleanupPackage
## Legacy source line: 184
##########################################################

[Result] CleanupPackage([Package]$Package) {

    if ($null -eq $Package) {

        return $this.NewFailure(
            'A package object is required for cleanup.',
            'PHX_INVALID_PACKAGE'
        )
    }

    if ($Package.PreserveDownloads) {

        $result = [Result]::Success(
            'Package downloads were preserved.'
        )

        $result.Code = 'PHX_CLEANUP_SKIPPED'

        return $result
    }

    $cleanupErrors =
        [System.Collections.Generic.List[string]]::new()

    [string[]]$paths = @(
        $Package.CleanupPaths
    ) |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace($_)
        } |
        Sort-Object Length -Descending -Unique

    foreach ($path in $paths) {

        if (-not $this.IsPhoenixManagedPath($path)) {

            $cleanupErrors.Add(
                "Refused to delete a non-Phoenix path: $path"
            )

            continue
        }

        try {

            if (Test-Path -LiteralPath $path) {

                Remove-Item `
                    -LiteralPath $path `
                    -Recurse `
                    -Force `
                    -ErrorAction Stop
            }
        }
        catch {

            $cleanupErrors.Add(
                "Failed to remove '$path': $($_.Exception.Message)"
            )
        }
    }

    $Package.WorkingDirectory = ''
    $Package.DownloadedFile = ''
    $Package.CleanupPaths = @()

    if ($cleanupErrors.Count -gt 0) {

        $result = $this.NewFailure(
            'One or more cleanup operations failed.',
            'PHX_CLEANUP_FAILED'
        )

        $result.Errors = $cleanupErrors.ToArray()

        return $result
    }

    $result = [Result]::Success(
        "Cleanup completed for '$($Package.Id)'."
    )

    $result.Code = 'PHX_CLEANUP_COMPLETE'

    return $result
}

