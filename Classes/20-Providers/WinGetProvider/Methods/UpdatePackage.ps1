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
            "Updating $($Package.Name) [$($Package.Id)] silently..."
        ) -ForegroundColor Cyan

$wingetOutput = @()

& $command.Source `
    upgrade `
    --id $Package.Id `
    --exact `
    --source winget `
    --silent `
    --disable-interactivity `
    --accept-package-agreements `
    --accept-source-agreements `
    2>&1 |
    Tee-Object -Variable wingetOutput |
    Out-Host

[int]$exitCode = $LASTEXITCODE

[string]$outputText = (
    $wingetOutput |
        ForEach-Object {
            $_.ToString()
        }
) -join [Environment]::NewLine

if (
    $outputText -match
        'install technology is different'
) {

    [Result]$result = [Result]::Failure(
        (
            "A newer version of '$($Package.Id)' was found, " +
            'but WinGet cannot upgrade it because the installer technology changed.'
        )
    )

    $result.Code = 'PHX_UPDATE_MIGRATION_REQUIRED'
    $result.Message = (
        "$($Package.Id) requires an uninstall and reinstall migration."
    )
    $result.Data = $Package
    $result.Provider = $this.Name
    $result.Operation = 'Update'
    $result.Target = $Package.Id
    $result.HasExitCode = $true
    $result.ExitCode = $exitCode
    $result.Errors = @(
        $wingetOutput |
            ForEach-Object {
                $_.ToString()
            }
    )

    return $result
}

if ($exitCode -eq -1978335189) {

    [Result]$result = [Result]::Success()

    $result.Code = 'PHX_ALREADY_CURRENT'
    $result.Message = (
        "$($Package.Id) is already current."
    )
    $result.Data = $Package
    $result.Provider = $this.Name
    $result.Operation = 'Update'
    $result.Target = $Package.Id
    $result.HasExitCode = $true
    $result.ExitCode = $exitCode

    return $result
}

if ($exitCode -ne 0 -and $exitCode -notin @(1641, 3010)) {

    [Result]$result = [Result]::Failure(
        "WinGet update failed with exit code $exitCode."
    )

    $result.Code = 'PHX_UPDATE_FAILED'
    $result.Data = $Package
    $result.Provider = $this.Name
    $result.Operation = 'Update'
    $result.Target = $Package.Id
    $result.HasExitCode = $true
    $result.ExitCode = $exitCode
    $result.Errors = @(
        $wingetOutput |
            ForEach-Object {
                $_.ToString()
            }
    )

    return $result
}

        $Package.Installed = $true

        [Result]$result = [Result]::Success()

        $result.Code = 'PHX_UPDATED'
        $result.Message = (
            "Updated $($Package.Id) successfully."
        )
        $result.Data = $Package
        $result.Provider = $this.Name
        $result.Operation = 'Update'
        $result.Target = $Package.Id
        $result.HasExitCode = $true
        $result.ExitCode = $exitCode
        $result.RebootRequired =
            $exitCode -in @(1641, 3010)

        return $result
    }
    catch {

        return $this.NewFailure(
            "WinGet update failed: $($_.Exception.Message)",
            'PHX_UPDATE_FAILED'
        )
    }
}
