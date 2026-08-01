class ScoopProvider : PhoenixProvider {

    ScoopProvider() {
        $this.Name = 'Scoop'
        $this.Type = 'Package Manager'
        $this.Priority = 85
        $this.RequiredPrivilege = [PhoenixPrivilegeLevel]::User
        $this.SupportsSilentInstall = $true
        $this.SupportsInteractiveInstall = $false
        $this.SupportsRepair = $false
        $this.SupportsSilentRepair = $false
        $this.SupportsInteractiveRepair = $false
        $this.SupportsExport = $true
        $this.SupportsRestore = $true
        $this.Available = $this.TestAvailable()
    }

    [bool] TestAvailable() {
        return $null -ne (
            Get-Command scoop -ErrorAction SilentlyContinue
        )
    }

    [Result] InstallProvider() {
        $result = [Result]::Failure(
            'Install Scoop from https://scoop.sh, then refresh Phoenix providers.'
        )
        $result.Code = 'PHX_PROVIDER_INSTALL_APPROVAL_REQUIRED'
        $result.Provider = $this.Name
        $result.Operation = 'InstallProvider'

        return $result
    }

    [Result] UpdateProvider() {
        if (-not $this.TestAvailable()) {
            return $this.NewFailure(
                'Scoop is unavailable.',
                'PHX_PROVIDER_UNAVAILABLE'
            )
        }

        return $this.InvokeScoop(
            @('update'),
            'UpdateProvider',
            'Scoop'
        )
    }

    [Package[]] GetInstalledPackages() {
        $packages = [System.Collections.Generic.List[Package]]::new()

        if (-not $this.TestAvailable()) {
            return $packages.ToArray()
        }

        try {
            $command = Get-Command scoop -ErrorAction Stop
            $output = @(& $command.Source export 2>$null)

            if ($LASTEXITCODE -ne 0) {
                return $packages.ToArray()
            }

            $exportData = ($output -join [Environment]::NewLine) |
                ConvertFrom-Json -ErrorAction Stop

            foreach ($app in @($exportData.apps)) {
                if ([string]::IsNullOrWhiteSpace([string]$app.Name)) {
                    continue
                }

                $package = [Package]::new()
                $package.Name = [string]$app.Name
                $package.Id = [string]$app.Name
                $package.Version = [string]$app.Version
                $package.Provider = $this.Name
                $package.InstallerType = 'Scoop'
                $package.Source = if (
                    [string]::IsNullOrWhiteSpace([string]$app.Source)
                ) { 'main' } else { [string]$app.Source }
                $package.Installed = $true
                $packages.Add($package)
            }
        }
        catch {
            return $packages.ToArray()
        }

        return $packages.ToArray()
    }

    [Package[]] SearchPackage([string]$Name) {
        $packages = [System.Collections.Generic.List[Package]]::new()

        if (
            [string]::IsNullOrWhiteSpace($Name) -or
            -not $this.TestAvailable()
        ) {
            return $packages.ToArray()
        }

        try {
            $command = Get-Command scoop -ErrorAction Stop
            $output = @(& $command.Source search $Name 2>$null)
            $seenIds = [System.Collections.Generic.HashSet[string]]::new(
                [StringComparer]::OrdinalIgnoreCase
            )

            foreach ($line in $output) {
                if ([string]$line -notmatch '^\s*([^\s]+)\s+\(([^)]+)\)') {
                    continue
                }

                [string]$id = $Matches[1]

                if (-not $seenIds.Add($id)) {
                    continue
                }

                $package = [Package]::new()
                $package.Name = $id
                $package.Id = $id
                $package.Version = $Matches[2]
                $package.Provider = $this.Name
                $package.InstallerType = 'Scoop'
                $package.Source = 'Scoop'
                $packages.Add($package)
            }
        }
        catch {
            return $packages.ToArray()
        }

        return $packages.ToArray()
    }

    [Result] InstallPackage([Package]$Package) {
        if ($null -eq $Package -or [string]::IsNullOrWhiteSpace($Package.Id)) {
            return $this.NewFailure(
                'A Scoop package ID is required.',
                'PHX_INVALID_PACKAGE'
            )
        }

        $result = $this.InvokeScoop(
            @('install', $Package.Id),
            'Install',
            $Package.Id
        )

        if ($result.Success) {
            $Package.Installed = $true
            $result.Code = 'PHX_INSTALLED'
        }

        $result.Data = $Package
        return $result
    }

    [Result] UpdatePackage([Package]$Package) {
        if ($null -eq $Package -or [string]::IsNullOrWhiteSpace($Package.Id)) {
            return $this.NewFailure(
                'A Scoop package ID is required.',
                'PHX_INVALID_PACKAGE'
            )
        }

        $result = $this.InvokeScoop(
            @('update', $Package.Id),
            'Update',
            $Package.Id
        )
        $result.Data = $Package

        if ($result.Success) {
            $result.Code = 'PHX_UPDATED'
        }

        return $result
    }

    [Result] RemovePackage([Package]$Package) {
        if ($null -eq $Package -or [string]::IsNullOrWhiteSpace($Package.Id)) {
            return $this.NewFailure(
                'A Scoop package ID is required.',
                'PHX_INVALID_PACKAGE'
            )
        }

        $result = $this.InvokeScoop(
            @('uninstall', $Package.Id),
            'Remove',
            $Package.Id
        )
        $result.Data = $Package

        if ($result.Success) {
            $Package.Installed = $false
            $result.Code = 'PHX_REMOVED'
        }

        return $result
    }

    [Result] ExportPackages() {
        if (-not $this.TestAvailable()) {
            return $this.NewFailure(
                'Scoop is unavailable.',
                'PHX_PROVIDER_UNAVAILABLE'
            )
        }

        try {
            $command = Get-Command scoop -ErrorAction Stop
            $output = @(& $command.Source export 2>&1)
            [int]$exitCode = $LASTEXITCODE
            $result = if ($exitCode -eq 0) {
                [Result]::Success($output -join [Environment]::NewLine)
            }
            else {
                [Result]::Failure('Scoop export failed.')
            }
            $result.Code = if ($result.Success) {
                'PHX_EXPORTED'
            } else { 'PHX_EXPORT_FAILED' }
            $result.Provider = $this.Name
            $result.Operation = 'Export'
            $result.Target = 'Scoop'
            $result.HasExitCode = $true
            $result.ExitCode = $exitCode

            return $result
        }
        catch {
            return $this.NewFailure(
                "Scoop export failed: $($_.Exception.Message)",
                'PHX_EXPORT_FAILED'
            )
        }
    }

    [Result[]] RestorePackages([Package[]]$Packages) {
        $results = [System.Collections.Generic.List[Result]]::new()

        foreach ($package in @($Packages)) {
            $results.Add($this.InstallPackage($package))
        }

        return $results.ToArray()
    }

    hidden [Result] InvokeScoop(
        [string[]]$ArgumentList,
        [string]$Operation,
        [string]$Target
    ) {
        if (-not $this.TestAvailable()) {
            return $this.NewFailure(
                'Scoop is unavailable.',
                'PHX_PROVIDER_UNAVAILABLE'
            )
        }

        try {
            $command = Get-Command scoop -ErrorAction Stop
            $output = @(& $command.Source @ArgumentList 2>&1)
            [int]$exitCode = $LASTEXITCODE
            $result = if ($exitCode -eq 0) {
                [Result]::Success()
            }
            else {
                [Result]::Failure(
                    "Scoop $Operation failed with exit code $exitCode."
                )
            }
            $result.Code = if ($result.Success) {
                "PHX_$($Operation.ToUpperInvariant())D"
            }
            else {
                "PHX_$($Operation.ToUpperInvariant())_FAILED"
            }
            $result.Message = $output -join [Environment]::NewLine
            $result.Provider = $this.Name
            $result.Operation = $Operation
            $result.Target = $Target
            $result.HasExitCode = $true
            $result.ExitCode = $exitCode

            if (-not $result.Success) {
                $result.Errors = @($output)
            }

            return $result
        }
        catch {
            return $this.NewFailure(
                "Scoop $Operation failed: $($_.Exception.Message)",
                "PHX_$($Operation.ToUpperInvariant())_FAILED"
            )
        }
    }
}
