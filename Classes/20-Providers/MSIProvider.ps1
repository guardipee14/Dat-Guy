class MSIProvider : PhoenixProvider {

    MSIProvider() {
        $this.Name = 'MSI'
        $this.Type = 'Native Installer'
        $this.Priority = 80
        $this.RequiredPrivilege =
            [PhoenixPrivilegeLevel]::Administrator
        $this.SupportsSearch = $false
        $this.SupportsInventory = $true
        $this.SupportsInstall = $true
        $this.SupportsUpdate = $false
        $this.SupportsRemove = $true
        $this.SupportsRepair = $true
        $this.SupportsSilentInstall = $true
        $this.SupportsInteractiveInstall = $true
        $this.SupportsSilentRepair = $true
        $this.SupportsInteractiveRepair = $true
        $this.SupportsExport = $false
        $this.SupportsRestore = $false
        $this.Available = $this.TestAvailable()
    }

    [bool] TestAvailable() {
        return $null -ne (
            Get-Command msiexec.exe -ErrorAction SilentlyContinue
        )
    }

    [Result] InstallProvider() {
        $result = [Result]::Success()
        $result.Code = 'PHX_PROVIDER_BUILT_IN'
        $result.Message = 'Windows Installer is built into Windows.'
        $result.Provider = $this.Name
        $result.Operation = 'InstallProvider'
        return $result
    }

    [Result] UpdateProvider() {
        return $this.InstallProvider()
    }

    [Package[]] GetInstalledPackages() {
        $packages = [System.Collections.Generic.List[Package]]::new()
        $seenProductCodes =
            [System.Collections.Generic.HashSet[string]]::new(
                [StringComparer]::OrdinalIgnoreCase
            )

        foreach ($registryPath in @(
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )) {
            foreach ($entry in @(Get-ItemProperty $registryPath -ErrorAction SilentlyContinue)) {
                [string]$productCode = [string]$entry.PSChildName

                if (
                    $productCode -notmatch '^\{[0-9A-Fa-f-]{36}\}$' -and
                    [string]$entry.UninstallString -match '(?i)msiexec(?:\.exe)?\s+/(?:I|X)\s*\{([0-9A-F-]{36})\}'
                ) {
                    $productCode = "{$($Matches[1])}"
                }

                if (
                    $productCode -notmatch '^\{[0-9A-Fa-f-]{36}\}$' -or
                    -not $seenProductCodes.Add($productCode) -or
                    [string]::IsNullOrWhiteSpace([string]$entry.DisplayName)
                ) {
                    continue
                }

                $package = [Package]::new()
                $package.Name = [string]$entry.DisplayName
                $package.Id = $productCode
                $package.Version = [string]$entry.DisplayVersion
                $package.Provider = $this.Name
                $package.InstallerType = 'MSI'
                $package.Source = 'Windows Installer'
                $package.Architecture = if (
                    [string]$entry.PSPath -match 'WOW6432Node'
                ) { 'x86' } else { 'x64' }
                $package.Installed = $true
                $package.RequiresElevation = $true
                $packages.Add($package)
            }
        }

        return $packages.ToArray()
    }

    [Package[]] SearchPackage([string]$Name) {
        return @()
    }

    [Result] InstallPackageSilent([Package]$Package) {
        return $this.InvokeMsiPackage(
            $Package,
            'Install',
            $true
        )
    }

    [Result] InstallPackageInteractive([Package]$Package) {
        return $this.InvokeMsiPackage(
            $Package,
            'Install',
            $false
        )
    }

    [Result] RepairPackageSilent([Package]$Package) {
        return $this.InvokeMsiPackage(
            $Package,
            'Repair',
            $true
        )
    }

    [Result] RepairPackageInteractive([Package]$Package) {
        return $this.InvokeMsiPackage(
            $Package,
            'Repair',
            $false
        )
    }

    [Result] UpdatePackage([Package]$Package) {
        return $this.NewFailure(
            'MSI updates require a newer installer definition.',
            'PHX_UPDATE_UNAVAILABLE'
        )
    }

    [Result] RemovePackage([Package]$Package) {
        return $this.InvokeMsiPackage(
            $Package,
            'Remove',
            $true
        )
    }

    hidden [Result] InvokeMsiPackage(
        [Package]$Package,
        [string]$Operation,
        [bool]$Silent
    ) {
        if ($null -eq $Package) {
            return $this.NewFailure(
                'An MSI package definition is required.',
                'PHX_INVALID_PACKAGE'
            )
        }

        [string]$target = $Package.Id
        $arguments = [System.Collections.Generic.List[string]]::new()

        if ($Operation -eq 'Install') {
            [string]$installerPath = if (
                -not [string]::IsNullOrWhiteSpace($Package.DownloadedFile)
            ) { $Package.DownloadedFile } else { $Package.Id }

            if (
                [string]::IsNullOrWhiteSpace($installerPath) -or
                -not (Test-Path -LiteralPath $installerPath -PathType Leaf)
            ) {
                return $this.NewFailure(
                    'The local MSI installer file was not found.',
                    'PHX_INSTALLER_NOT_FOUND'
                )
            }

            $target = $installerPath
            $arguments.Add('/i')
            $arguments.Add(('"{0}"' -f $installerPath))
        }
        elseif ($Package.Id -match '^\{[0-9A-Fa-f-]{36}\}$') {
            [string]$productAction = if ($Operation -eq 'Repair') {
                '/fa'
            }
            else {
                '/x'
            }
            $arguments.Add($productAction)
            $arguments.Add($Package.Id)
        }
        else {
            return $this.NewFailure(
                'A valid MSI product code is required.',
                'PHX_INVALID_PRODUCT_CODE'
            )
        }

        [string]$uiArgument = if ($Silent) { '/qn' } else { '/passive' }
        $arguments.Add($uiArgument)
        $arguments.Add('/norestart')

        try {
            $process = Start-Process `
                -FilePath 'msiexec.exe' `
                -ArgumentList $arguments.ToArray() `
                -Wait `
                -PassThru `
                -ErrorAction Stop

            [int]$exitCode = $process.ExitCode
            [bool]$success =
                $exitCode -in @(0, 1605, 1614, 1641, 3010)
            $result = if ($success) {
                [Result]::Success()
            }
            else {
                [Result]::Failure(
                    "Windows Installer exited with code $exitCode."
                )
            }
            $result.Provider = $this.Name
            $result.Operation = $Operation
            $result.Target = $target
            $result.HasExitCode = $true
            $result.ExitCode = $exitCode
            $result.RebootRequired = $exitCode -in @(1641, 3010)
            $result.Data = $Package
            $result.Code = if ($success) {
                if ($result.RebootRequired) {
                    "PHX_$($Operation.ToUpperInvariant())_RESTART_REQUIRED"
                }
                else {
                    "PHX_$($Operation.ToUpperInvariant())_SUCCEEDED"
                }
            }
            else {
                "PHX_$($Operation.ToUpperInvariant())_FAILED"
            }

            if ($success) {
                $Package.Installed = $Operation -ne 'Remove'
                $result.Message = "$Operation completed for '$target'."
            }

            return $result
        }
        catch {
            return $this.NewFailure(
                "MSI $Operation failed: $($_.Exception.Message)",
                "PHX_$($Operation.ToUpperInvariant())_FAILED"
            )
        }
    }
}
