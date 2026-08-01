class EXEProvider : PhoenixProvider {
    EXEProvider() {
        $this.Name = 'EXE'
        $this.Type = 'Executable Installer'
        $this.Priority = 75
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
            Get-Command Start-Process -ErrorAction SilentlyContinue
        )
    }

    [Result] InstallProvider() {
        $result = [Result]::Success()
        $result.Code = 'PHX_PROVIDER_BUILT_IN'
        $result.Message = 'Executable installer support is built into Phoenix.'
        $result.Provider = $this.Name
        $result.Operation = 'InstallProvider'
        return $result
    }

    [Result] UpdateProvider() {
        return $this.InstallProvider()
    }

    [Package[]] GetInstalledPackages() {
        $packages = [System.Collections.Generic.List[Package]]::new()
        $seen = [System.Collections.Generic.HashSet[string]]::new(
            [StringComparer]::OrdinalIgnoreCase
        )

        foreach ($registryPath in @(
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )) {
            foreach ($entry in @(
                Get-ItemProperty $registryPath -ErrorAction SilentlyContinue
            )) {
                [string]$uninstallCommand = [string]$entry.UninstallString
                [string]$quietCommand = [string]$entry.QuietUninstallString
                [string]$identity = '{0}|{1}' -f $entry.PSPath, $entry.PSChildName

                if (
                    [string]::IsNullOrWhiteSpace([string]$entry.DisplayName) -or
                    [int]$entry.WindowsInstaller -eq 1 -or
                    $uninstallCommand -match '(?i)\bmsiexec(?:\.exe)?\b' -or
                    -not $seen.Add($identity)
                ) {
                    continue
                }

                $package = [EXEPackageDefinition]::new()
                $package.Name = [string]$entry.DisplayName
                $package.Id = [string]$entry.PSChildName
                $package.Version = [string]$entry.DisplayVersion
                $package.Provider = $this.Name
                $package.Source = [string]$entry.Publisher
                $package.Architecture = if (
                    [string]$entry.PSPath -match 'WOW6432Node'
                ) { 'x86' } else { 'x64' }
                $package.Installed = $true
                $package.RequiresElevation =
                    [string]$entry.PSPath -match 'HKEY_LOCAL_MACHINE'
                $package.UninstallCommand = $uninstallCommand
                $package.QuietUninstallCommand = $quietCommand
                $package.RepairCommand = [string]$entry.ModifyPath
                $packages.Add($package)
            }
        }

        return $packages.ToArray()
    }

    [Package[]] SearchPackage([string]$Name) {
        return @()
    }

    [Result] InstallPackageSilent([Package]$Package) {
        return $this.InvokeInstall($Package, $true)
    }

    [Result] InstallPackageInteractive([Package]$Package) {
        return $this.InvokeInstall($Package, $false)
    }

    [Result] RepairPackageSilent([Package]$Package) {
        return $this.InvokeDefinitionCommand(
            $Package,
            'Repair',
            $this.GetDefinitionValue($Package, 'RepairCommand'),
            @()
        )
    }

    [Result] RepairPackageInteractive([Package]$Package) {
        return $this.RepairPackageSilent($Package)
    }

    [Result] UpdatePackage([Package]$Package) {
        return $this.NewFailure(
            'EXE updates require a newer declarative package definition.',
            'PHX_UPDATE_UNAVAILABLE'
        )
    }

    [Result] RemovePackage([Package]$Package) {
        [string]$command =
            $this.GetDefinitionValue($Package, 'QuietUninstallCommand')
        if ([string]::IsNullOrWhiteSpace($command)) {
            $command = $this.GetDefinitionValue($Package, 'UninstallCommand')
        }
        return $this.InvokeDefinitionCommand(
            $Package,
            'Remove',
            $command,
            @()
        )
    }

    hidden [Result] InvokeInstall([Package]$Package, [bool]$Silent) {
        if ($null -eq $Package) {
            return $this.NewFailure(
                'An EXE package definition is required.',
                'PHX_INVALID_PACKAGE'
            )
        }

        [string]$command = $this.GetDefinitionValue(
            $Package,
            'InstallCommand'
        )
        if ([string]::IsNullOrWhiteSpace($command)) {
            $command = if (
                -not [string]::IsNullOrWhiteSpace($Package.DownloadedFile)
            ) { $Package.DownloadedFile } else { $Package.Id }
        }

        if (-not (Test-Path -LiteralPath $command -PathType Leaf)) {
            return $this.NewFailure(
                'The executable installer file was not found.',
                'PHX_INSTALLER_NOT_FOUND'
            )
        }

        [string[]]$arguments = if ($Silent) {
            $Package.SilentArguments
        }
        else {
            $Package.InteractiveArguments
        }

        return $this.InvokeDefinitionCommand(
            $Package,
            'Install',
            ('"{0}"' -f $command),
            $arguments
        )
    }

    hidden [string] GetDefinitionValue(
        [Package]$Package,
        [string]$PropertyName
    ) {
        if ($null -eq $Package) {
            return ''
        }
        $property = $Package.PSObject.Properties[$PropertyName]
        if ($null -eq $property) {
            return ''
        }
        return [string]$property.Value
    }

    hidden [int[]] GetDefinitionExitCodes(
        [Package]$Package,
        [string]$PropertyName,
        [int[]]$Default
    ) {
        if ($null -ne $Package) {
            $property = $Package.PSObject.Properties[$PropertyName]
            if ($null -ne $property -and @($property.Value).Count -gt 0) {
                return [int[]]@($property.Value)
            }
        }
        return $Default
    }

    hidden [Result] InvokeDefinitionCommand(
        [Package]$Package,
        [string]$Operation,
        [string]$CommandLine,
        [string[]]$AdditionalArguments
    ) {
        if ([string]::IsNullOrWhiteSpace($CommandLine)) {
            return $this.NewFailure(
                "No $Operation command is defined for this executable package.",
                "PHX_$($Operation.ToUpperInvariant())_UNAVAILABLE"
            )
        }

        [string]$executable = ''
        [string]$registeredArguments = ''
        [string]$trimmed = $CommandLine.Trim()

        if ($trimmed -match '^"([^"]+)"\s*(.*)$') {
            $executable = $Matches[1]
            $registeredArguments = $Matches[2]
        }
        elseif ($trimmed -match '^(.*?\.exe)\s*(.*)$') {
            $executable = $Matches[1]
            $registeredArguments = $Matches[2]
        }
        else {
            $executable = $trimmed
        }

        $arguments = [System.Collections.Generic.List[string]]::new()
        if (-not [string]::IsNullOrWhiteSpace($registeredArguments)) {
            $arguments.Add($registeredArguments)
        }
        foreach ($argument in @($AdditionalArguments)) {
            if (-not [string]::IsNullOrWhiteSpace($argument)) {
                $arguments.Add($argument)
            }
        }

        try {
            $processParameters = @{
                FilePath = $executable
                ArgumentList = $arguments.ToArray()
                Wait = $true
                PassThru = $true
                ErrorAction = 'Stop'
            }
            if (
                $null -ne $Package -and
                -not [string]::IsNullOrWhiteSpace($Package.WorkingDirectory)
            ) {
                $processParameters.WorkingDirectory = $Package.WorkingDirectory
            }

            $process = Start-Process @processParameters
            [int]$exitCode = $process.ExitCode
            [int[]]$successCodes = $this.GetDefinitionExitCodes(
                $Package,
                'SuccessExitCodes',
                @(0)
            )
            [int[]]$rebootCodes = $this.GetDefinitionExitCodes(
                $Package,
                'RebootExitCodes',
                @(1641, 3010)
            )
            [bool]$rebootRequired = $exitCode -in $rebootCodes
            [bool]$success = $exitCode -in $successCodes -or $rebootRequired
            $result = if ($success) {
                [Result]::Success()
            }
            else {
                [Result]::Failure(
                    "Executable installer exited with code $exitCode."
                )
            }
            $result.Provider = $this.Name
            $result.Operation = $Operation
            $result.Target = if ($null -ne $Package) { $Package.Id } else { $executable }
            $result.HasExitCode = $true
            $result.ExitCode = $exitCode
            $result.RebootRequired = $rebootRequired
            $result.Data = $Package
            $result.Code = if ($success) {
                if ($rebootRequired) {
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
                $result.Message = "$Operation completed for '$($result.Target)'."
                if ($null -ne $Package) {
                    $Package.Installed = $Operation -ne 'Remove'
                }
            }
            return $result
        }
        catch {
            $result = $this.NewFailure(
                "EXE $Operation failed: $($_.Exception.Message)",
                "PHX_$($Operation.ToUpperInvariant())_FAILED"
            )
            $result.Provider = $this.Name
            $result.Operation = $Operation
            $result.Target = if ($null -ne $Package) { $Package.Id } else { $executable }
            return $result
        }
    }
}
