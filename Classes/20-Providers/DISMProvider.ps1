class DISMProvider : PhoenixProvider {
    DISMProvider() {
        $this.Name = 'DISM'
        $this.Type = 'Online Windows Servicing'
        $this.Priority = 55
        $this.RequiredPrivilege = [PhoenixPrivilegeLevel]::Administrator
        $this.SupportsSearch = $true
        $this.SupportsInventory = $true
        $this.SupportsInstall = $true
        $this.SupportsUpdate = $false
        $this.SupportsRemove = $true
        $this.SupportsRepair = $false
        $this.SupportsSilentInstall = $true
        $this.SupportsInteractiveInstall = $false
        $this.SupportsExport = $false
        $this.SupportsRestore = $false
        $this.Available = $this.TestAvailable()
    }

    [bool] TestAvailable() {
        return (
            $null -ne (Get-Command Get-WindowsCapability -ErrorAction SilentlyContinue) -and
            $null -ne (Get-Command Get-WindowsOptionalFeature -ErrorAction SilentlyContinue) -and
            $null -ne (Get-Command Get-WindowsPackage -ErrorAction SilentlyContinue)
        )
    }

    [Result] InstallProvider() {
        $result = [Result]::Success()
        $result.Code = 'PHX_PROVIDER_BUILT_IN'
        $result.Message = 'Online DISM servicing is built into Windows.'
        $result.Provider = $this.Name
        $result.Operation = 'InstallProvider'
        return $result
    }

    [Result] UpdateProvider() {
        return $this.InstallProvider()
    }

    [Package[]] GetInstalledPackages() {
        $packages = [System.Collections.Generic.List[Package]]::new()
        try {
            foreach ($item in @(
                Get-WindowsCapability -Online -ErrorAction Stop |
                    Where-Object State -eq 'Installed'
            )) {
                $packages.Add($this.ConvertServicingItem(
                    $item.Name, [string]$item.State, 'Capability'
                ))
            }
            foreach ($item in @(
                Get-WindowsOptionalFeature -Online -ErrorAction Stop |
                    Where-Object State -eq 'Enabled'
            )) {
                $packages.Add($this.ConvertServicingItem(
                    $item.FeatureName, [string]$item.State, 'Feature'
                ))
            }
            foreach ($item in @(
                Get-WindowsPackage -Online -ErrorAction Stop |
                    Where-Object PackageState -eq 'Installed'
            )) {
                $packages.Add($this.ConvertServicingItem(
                    $item.PackageName, [string]$item.PackageState, 'Package'
                ))
            }
        }
        catch {
            return $packages.ToArray()
        }
        return $packages.ToArray()
    }

    [Package[]] SearchPackage([string]$Name) {
        if ([string]::IsNullOrWhiteSpace($Name)) {
            return @()
        }
        $packages = [System.Collections.Generic.List[Package]]::new()
        try {
            foreach ($item in @(
                Get-WindowsCapability -Online -Name "*$Name*" -ErrorAction Stop
            )) {
                $packages.Add($this.ConvertServicingItem(
                    $item.Name, [string]$item.State, 'Capability'
                ))
            }
            foreach ($item in @(
                Get-WindowsOptionalFeature -Online -ErrorAction Stop |
                    Where-Object FeatureName -like "*$Name*"
            )) {
                $packages.Add($this.ConvertServicingItem(
                    $item.FeatureName, [string]$item.State, 'Feature'
                ))
            }
            foreach ($item in @(
                Get-WindowsPackage -Online -ErrorAction Stop |
                    Where-Object PackageName -like "*$Name*"
            )) {
                $packages.Add($this.ConvertServicingItem(
                    $item.PackageName, [string]$item.PackageState, 'Package'
                ))
            }
        }
        catch {
            return $packages.ToArray()
        }
        return $packages.ToArray()
    }

    [Result] InstallPackageSilent([Package]$Package) {
        return $this.InvokeServicing($Package, 'Install')
    }

    [Result] InstallPackageInteractive([Package]$Package) {
        return $this.NewFailure(
            'DISM servicing does not provide an interactive installer mode.',
            'PHX_INTERACTIVE_UNAVAILABLE'
        )
    }

    [Result] UpdatePackage([Package]$Package) {
        return $this.NewFailure(
            'Use install/enable for an applicable online servicing item.',
            'PHX_UPDATE_UNAVAILABLE'
        )
    }

    [Result] RemovePackage([Package]$Package) {
        return $this.InvokeServicing($Package, 'Remove')
    }

    hidden [DISMPackageDefinition] ConvertServicingItem(
        [string]$Name,
        [string]$State,
        [string]$ServicingType
    ) {
        $package = [DISMPackageDefinition]::new()
        $package.Name = $Name
        $package.Id = $Name
        $package.Version = if ($Name -match '~([0-9.]+)$') {
            $Matches[1]
        }
        else { '' }
        $package.ServicingType = $ServicingType
        $package.InstallerType = "DISM$ServicingType"
        $package.State = $State
        $package.Installed = $State -in @('Installed', 'Enabled')
        return $package
    }

    hidden [string] GetServicingType([Package]$Package) {
        if ($null -eq $Package) { return '' }
        $property = $Package.PSObject.Properties['ServicingType']
        if ($null -ne $property) { return [string]$property.Value }
        if ($Package.InstallerType -match '^DISM(.+)$') {
            return $Matches[1]
        }
        return ''
    }

    hidden [string] GetSourcePath([Package]$Package) {
        if ($null -eq $Package) { return '' }
        $property = $Package.PSObject.Properties['SourcePath']
        if ($null -ne $property -and
            -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
            return [string]$property.Value
        }
        return $Package.DownloadedFile
    }

    hidden [Result] InvokeServicing(
        [Package]$Package,
        [string]$Operation
    ) {
        if ($null -eq $Package -or [string]::IsNullOrWhiteSpace($Package.Id)) {
            return $this.NewFailure(
                'A DISM servicing item is required.',
                'PHX_INVALID_PACKAGE'
            )
        }
        [string]$servicingType = $this.GetServicingType($Package)
        if ($servicingType -notin @('Capability', 'Feature', 'Package')) {
            return $this.NewFailure(
                'The DISM servicing type is unsupported.',
                'PHX_SERVICING_TYPE_UNSUPPORTED'
            )
        }

        try {
            $response = switch ("$Operation|$servicingType") {
                'Install|Capability' {
                    Add-WindowsCapability -Online -Name $Package.Id -ErrorAction Stop
                }
                'Remove|Capability' {
                    Remove-WindowsCapability -Online -Name $Package.Id -ErrorAction Stop
                }
                'Install|Feature' {
                    Enable-WindowsOptionalFeature `
                        -Online -FeatureName $Package.Id -All -NoRestart -ErrorAction Stop
                }
                'Remove|Feature' {
                    Disable-WindowsOptionalFeature `
                        -Online -FeatureName $Package.Id -NoRestart -ErrorAction Stop
                }
                'Install|Package' {
                    [string]$sourcePath = $this.GetSourcePath($Package)
                    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
                        throw 'A local CAB or MSU package source is required.'
                    }
                    Add-WindowsPackage `
                        -Online -PackagePath $sourcePath -NoRestart -ErrorAction Stop
                }
                'Remove|Package' {
                    Remove-WindowsPackage `
                        -Online -PackageName $Package.Id -NoRestart -ErrorAction Stop
                }
            }
            [bool]$restartNeeded =
                [string]$response.RestartNeeded -match '^(?i:yes|true)$'
            $result = [Result]::Success()
            $result.Code = if ($restartNeeded) {
                "PHX_$($Operation.ToUpperInvariant())_RESTART_REQUIRED"
            }
            elseif ($Operation -eq 'Install') { 'PHX_INSTALLED' }
            else { 'PHX_REMOVED' }
            $result.Message = "$Operation completed for online $servicingType '$($Package.Id)'."
            $result.Provider = $this.Name
            $result.Operation = $Operation
            $result.Target = $Package.Id
            $result.HasExitCode = $true
            $result.ExitCode = 0
            $result.RebootRequired = $restartNeeded
            $result.Data = $Package
            $Package.Installed = $Operation -eq 'Install'
            return $result
        }
        catch {
            $result = $this.NewFailure(
                "DISM $Operation failed: $($_.Exception.Message)",
                "PHX_$($Operation.ToUpperInvariant())_FAILED"
            )
            $result.Provider = $this.Name
            $result.Operation = $Operation
            $result.Target = $Package.Id
            $result.HasExitCode = $true
            $result.ExitCode = $_.Exception.HResult
            $result.Data = $Package
            return $result
        }
    }
}
