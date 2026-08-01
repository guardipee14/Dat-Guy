##########################################################
## Method: RepairPackageSilent
## Legacy source line: 507
##########################################################

[Result] RepairPackageSilent([Package]$Package) {

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
            "Repairing $($Package.Name) silently..."
        ) -ForegroundColor Cyan

        & $command.Source `
            repair `
            --id $Package.Id `
            --exact `
            --source winget `
            --silent `
            --disable-interactivity `
            --accept-package-agreements `
            --accept-source-agreements |
            Out-Host

        [int]$exitCode = $LASTEXITCODE

        if ($exitCode -ne 0 -and $exitCode -notin @(1641, 3010)) {

            $result = $this.NewFailure(
                "WinGet repair failed with exit code $exitCode.",
                'PHX_REPAIR_FAILED'
            )
            $result.Provider = $this.Name
            $result.Operation = 'Repair'
            $result.Target = $Package.Id
            $result.HasExitCode = $true
            $result.ExitCode = $exitCode
            $result.Data = $Package

            return $result
        }

        $result = [Result]::Success(
            "Repaired $($Package.Id) silently."
        )

        $result.Code = 'PHX_REPAIRED'
        $result.Provider = $this.Name
        $result.Operation = 'Repair'
        $result.Target = $Package.Id
        $result.HasExitCode = $true
        $result.ExitCode = $exitCode
        $result.RebootRequired =
            $exitCode -in @(1641, 3010)
        $result.Data = $Package

        if ($result.RebootRequired) {
            $result.Code = 'PHX_REPAIRED_RESTART_REQUIRED'
        }

        return $result
    }
    catch {

        return $this.NewFailure(
            "WinGet repair failed: $($_.Exception.Message)",
            'PHX_REPAIR_FAILED'
        )
    }
}

