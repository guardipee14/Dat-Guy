class PowerShellGalleryProvider : PhoenixProvider {
    PowerShellGalleryProvider() {
        $this.Name = 'PowerShell Gallery'
        $this.Type = 'PowerShell Resource'
        $this.Priority = 65
        $this.RequiredPrivilege = [PhoenixPrivilegeLevel]::User
        $this.SupportsSearch = $true
        $this.SupportsInventory = $true
        $this.SupportsInstall = $true
        $this.SupportsUpdate = $true
        $this.SupportsRemove = $true
        $this.SupportsRepair = $false
        $this.SupportsSilentInstall = $true
        $this.SupportsInteractiveInstall = $true
        $this.SupportsExport = $true
        $this.SupportsRestore = $true
        $this.Available = $this.TestAvailable()
    }

    [bool] TestAvailable() {
        return (
            $null -ne (Get-Command Find-PSResource -ErrorAction SilentlyContinue) -or
            $null -ne (Get-Command Find-Module -ErrorAction SilentlyContinue)
        )
    }

    [Result] InstallProvider() {
        if ($this.TestAvailable()) {
            $result = [Result]::Success()
            $result.Code = 'PHX_PROVIDER_AVAILABLE'
            $result.Message = 'A PowerShell Gallery client is already available.'
            $result.Provider = $this.Name
            $result.Operation = 'InstallProvider'
            return $result
        }
        return $this.NewFailure(
            'Install Microsoft.PowerShell.PSResourceGet or PowerShellGet to use the Gallery provider.',
            'PHX_PROVIDER_INSTALL_REQUIRED'
        )
    }

    [Result] UpdateProvider() {
        return $this.InstallProvider()
    }

    [Package[]] GetInstalledPackages() {
        $packages = [System.Collections.Generic.List[Package]]::new()
        if ($null -ne (Get-Command Get-InstalledPSResource -ErrorAction SilentlyContinue)) {
            foreach ($resource in @(
                Get-InstalledPSResource -ErrorAction SilentlyContinue
            )) {
                $packages.Add($this.ConvertResourceToPackage(
                    $resource,
                    [string]$resource.Type,
                    $true
                ))
            }
            return $packages.ToArray()
        }

        foreach ($module in @(
            Get-InstalledModule -ErrorAction SilentlyContinue
        )) {
            $packages.Add($this.ConvertResourceToPackage(
                $module,
                'Module',
                $true
            ))
        }
        foreach ($script in @(
            Get-InstalledScript -ErrorAction SilentlyContinue
        )) {
            $packages.Add($this.ConvertResourceToPackage(
                $script,
                'Script',
                $true
            ))
        }
        return $packages.ToArray()
    }

    [Package[]] SearchPackage([string]$Name) {
        if ([string]::IsNullOrWhiteSpace($Name) -or -not $this.TestAvailable()) {
            return @()
        }

        $packages = [System.Collections.Generic.List[Package]]::new()
        $installedVersions = @{}
        foreach ($installed in @($this.GetInstalledPackages())) {
            $installedVersions["$($installed.InstallerType)|$($installed.Id)"] =
                $installed.Version
        }

        try {
            if ($null -ne (Get-Command Find-PSResource -ErrorAction SilentlyContinue)) {
                foreach ($resource in @(
                    Find-PSResource `
                        -Name $Name `
                        -Repository PSGallery `
                        -ErrorAction Stop
                )) {
                    [string]$resourceType = [string]$resource.Type
                    $package = $this.ConvertResourceToPackage(
                        $resource,
                        $resourceType,
                        $false
                    )
                    $key = "$($package.InstallerType)|$($package.Id)"
                    if ($installedVersions.ContainsKey($key)) {
                        $package.Installed = $true
                        $package.InstalledVersion =
                            [string]$installedVersions[$key]
                    }
                    $packages.Add($package)
                }
                return $packages.ToArray()
            }

            foreach ($resourceType in @('Module', 'Script')) {
                $commandName = if ($resourceType -eq 'Module') {
                    'Find-Module'
                }
                else {
                    'Find-Script'
                }
                foreach ($resource in @(
                    & $commandName `
                        -Name $Name `
                        -Repository PSGallery `
                        -ErrorAction Stop
                )) {
                    $package = $this.ConvertResourceToPackage(
                        $resource,
                        $resourceType,
                        $false
                    )
                    $key = "$($package.InstallerType)|$($package.Id)"
                    if ($installedVersions.ContainsKey($key)) {
                        $package.Installed = $true
                        $package.InstalledVersion =
                            [string]$installedVersions[$key]
                    }
                    $packages.Add($package)
                }
            }
        }
        catch {
            return $packages.ToArray()
        }
        return $packages.ToArray()
    }

    [Result] InstallPackageSilent([Package]$Package) {
        return $this.InvokeGalleryOperation($Package, 'Install')
    }

    [Result] InstallPackageInteractive([Package]$Package) {
        return $this.InvokeGalleryOperation($Package, 'Install')
    }

    [Result] UpdatePackage([Package]$Package) {
        return $this.InvokeGalleryOperation($Package, 'Update')
    }

    [Result] RemovePackage([Package]$Package) {
        return $this.InvokeGalleryOperation($Package, 'Remove')
    }

    [Result] ExportPackages() {
        $inventory = $this.GetInstalledPackages()
        $result = [Result]::Success($inventory)
        $result.Code = 'PHX_EXPORTED'
        $result.Message = "Exported $($inventory.Count) PowerShell Gallery resources."
        $result.Provider = $this.Name
        $result.Operation = 'Export'
        $result.Target = 'PSGallery'
        return $result
    }

    [Result[]] RestorePackages([Package[]]$Packages) {
        $results = [System.Collections.Generic.List[Result]]::new()
        foreach ($package in @($Packages)) {
            $results.Add($this.InstallPackageSilent($package))
        }
        return $results.ToArray()
    }

    hidden [PowerShellGalleryPackageDefinition] ConvertResourceToPackage(
        [object]$Resource,
        [string]$ResourceType,
        [bool]$Installed
    ) {
        $package = [PowerShellGalleryPackageDefinition]::new()
        $package.Name = [string]$Resource.Name
        $package.Id = [string]$Resource.Name
        $package.Version = [string]$Resource.Version
        $package.ResourceType = if (
            $ResourceType -match '(?i)script'
        ) { 'Script' } else { 'Module' }
        $package.InstallerType = "PowerShell$($package.ResourceType)"
        $package.Description = [string]$Resource.Description
        $package.Installed = $Installed
        if ($Installed) {
            $package.InstalledVersion = $package.Version
        }
        return $package
    }

    hidden [string] GetResourceType([Package]$Package) {
        if ($null -ne $Package) {
            $property = $Package.PSObject.Properties['ResourceType']
            if ($null -ne $property -and [string]$property.Value -match '(?i)script') {
                return 'Script'
            }
            if ($Package.InstallerType -match '(?i)script') {
                return 'Script'
            }
        }
        return 'Module'
    }

    hidden [Result] InvokeGalleryOperation(
        [Package]$Package,
        [string]$Operation
    ) {
        if (
            $null -eq $Package -or
            [string]::IsNullOrWhiteSpace($Package.Id)
        ) {
            return $this.NewFailure(
                'A PowerShell Gallery package ID is required.',
                'PHX_INVALID_PACKAGE'
            )
        }
        if (-not $this.TestAvailable()) {
            return $this.NewFailure(
                'No PowerShell Gallery client is available.',
                'PHX_PROVIDER_UNAVAILABLE'
            )
        }

        [string]$resourceType = $this.GetResourceType($Package)
        try {
            if ($null -ne (Get-Command Install-PSResource -ErrorAction SilentlyContinue)) {
                $parameters = @{
                    Name = $Package.Id
                    Scope = 'CurrentUser'
                    ErrorAction = 'Stop'
                }
                if ($Operation -in @('Install', 'Update')) {
                    $parameters.Repository = 'PSGallery'
                    $parameters.TrustRepository = $true
                    $parameters.Quiet = $true
                    $parameters.AcceptLicense = $true
                    if (-not [string]::IsNullOrWhiteSpace($Package.Version)) {
                        $parameters.Version = $Package.Version
                    }
                }
                switch ($Operation) {
                    'Install' { Install-PSResource @parameters }
                    'Update' { Update-PSResource @parameters }
                    'Remove' { Uninstall-PSResource @parameters }
                }
            }
            else {
                $noun = if ($resourceType -eq 'Script') { 'Script' } else { 'Module' }
                $commandName = switch ($Operation) {
                    'Install' { "Install-$noun" }
                    'Update' { "Update-$noun" }
                    'Remove' { "Uninstall-$noun" }
                }
                $parameters = @{
                    Name = $Package.Id
                    ErrorAction = 'Stop'
                }
                if ($Operation -in @('Install', 'Update')) {
                    $parameters.Scope = 'CurrentUser'
                    $parameters.Force = $true
                    $parameters.AcceptLicense = $true
                }
                if (
                    $Operation -in @('Install', 'Update') -and
                    -not [string]::IsNullOrWhiteSpace($Package.Version)
                ) {
                    $parameters.RequiredVersion = $Package.Version
                }
                & $commandName @parameters
            }

            $result = [Result]::Success()
            $result.Code = switch ($Operation) {
                'Install' { 'PHX_INSTALLED' }
                'Update' { 'PHX_UPDATED' }
                'Remove' { 'PHX_REMOVED' }
            }
            $result.Message = "$Operation completed for '$($Package.Id)'."
            $result.Provider = $this.Name
            $result.Operation = $Operation
            $result.Target = $Package.Id
            $result.Data = $Package
            $Package.Installed = $Operation -ne 'Remove'
            return $result
        }
        catch {
            $result = $this.NewFailure(
                "PowerShell Gallery $Operation failed: $($_.Exception.Message)",
                "PHX_$($Operation.ToUpperInvariant())_FAILED"
            )
            $result.Provider = $this.Name
            $result.Operation = $Operation
            $result.Target = $Package.Id
            $result.Data = $Package
            return $result
        }
    }
}
