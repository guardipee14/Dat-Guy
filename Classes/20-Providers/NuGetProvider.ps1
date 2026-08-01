class NuGetProvider : PhoenixProvider {
    NuGetProvider() {
        $this.Name = 'NuGet'
        $this.Type = 'NuGet v3 Package'
        $this.Priority = 60
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
            $null -ne (Get-Command Invoke-RestMethod -ErrorAction SilentlyContinue) -and
            $null -ne (Get-Command Invoke-WebRequest -ErrorAction SilentlyContinue)
        )
    }

    [Result] InstallProvider() {
        $result = [Result]::Success()
        $result.Code = 'PHX_PROVIDER_BUILT_IN'
        $result.Message = 'NuGet v3 support is built into Phoenix.'
        $result.Provider = $this.Name
        $result.Operation = 'InstallProvider'
        return $result
    }

    [Result] UpdateProvider() {
        return $this.InstallProvider()
    }

    [Package[]] GetInstalledPackages() {
        $packages = [System.Collections.Generic.List[Package]]::new()
        [string]$storeRoot = $this.GetStoreRoot()
        if (-not (Test-Path -LiteralPath $storeRoot -PathType Container)) {
            return @()
        }
        foreach ($idDirectory in @(
            Get-ChildItem -LiteralPath $storeRoot -Directory -ErrorAction SilentlyContinue
        )) {
            foreach ($versionDirectory in @(
                Get-ChildItem -LiteralPath $idDirectory.FullName -Directory -ErrorAction SilentlyContinue
            )) {
                $package = [NuGetPackageDefinition]::new()
                $package.Name = $idDirectory.Name
                $package.Id = $idDirectory.Name
                $package.Version = $versionDirectory.Name
                $package.InstalledVersion = $versionDirectory.Name
                $package.Source = 'Phoenix NuGet Store'
                $package.Installed = $true
                $package.WorkingDirectory = $versionDirectory.FullName
                $packages.Add($package)
            }
        }
        return $packages.ToArray()
    }

    [Package[]] SearchPackage([string]$Name) {
        if ([string]::IsNullOrWhiteSpace($Name)) {
            return @()
        }
        $packages = [System.Collections.Generic.List[Package]]::new()
        $installedVersions = @{}
        foreach ($installed in @($this.GetInstalledPackages())) {
            $installedVersions[$installed.Id] = $installed.Version
        }

        foreach ($feed in $this.GetConfiguredFeeds()) {
            try {
                $index = Invoke-RestMethod -Uri $feed -Method Get -ErrorAction Stop
                $searchResource = @(
                    $index.resources |
                        Where-Object {
                            [string]$_.'@type' -match '^SearchQueryService'
                        }
                ) | Select-Object -First 1
                $baseResource = @(
                    $index.resources |
                        Where-Object {
                            [string]$_.'@type' -match '^PackageBaseAddress'
                        }
                ) | Select-Object -First 1
                if ($null -eq $searchResource -or $null -eq $baseResource) {
                    continue
                }
                [string]$query = [uri]::EscapeDataString($Name)
                [string]$searchUri = "$( $searchResource.'@id' )?q=$query&prerelease=false&take=20"
                $response = Invoke-RestMethod -Uri $searchUri -Method Get -ErrorAction Stop
                foreach ($item in @($response.data)) {
                    $package = [NuGetPackageDefinition]::new()
                    $package.Name = [string]$item.title
                    $package.Id = [string]$item.id
                    $package.Version = [string]$item.version
                    $package.FeedUrl = $feed
                    $package.Source = $feed
                    $package.Description = [string]$item.description
                    $package.Authors = [string]($item.authors -join ', ')
                    [string]$idLower = $package.Id.ToLowerInvariant()
                    [string]$versionLower = $package.Version.ToLowerInvariant()
                    [string]$baseAddress = ([string]$baseResource.'@id').TrimEnd('/')
                    $package.DownloadUri =
                        "$baseAddress/$idLower/$versionLower/$idLower.$versionLower.nupkg"
                    if ($installedVersions.ContainsKey($package.Id)) {
                        $package.Installed = $true
                        $package.InstalledVersion =
                            [string]$installedVersions[$package.Id]
                    }
                    $packages.Add($package)
                }
            }
            catch {
                continue
            }
        }
        return $packages.ToArray()
    }

    [Result] InstallPackageSilent([Package]$Package) {
        return $this.InstallNuGetPackage($Package, 'Install')
    }

    [Result] InstallPackageInteractive([Package]$Package) {
        return $this.InstallNuGetPackage($Package, 'Install')
    }

    [Result] UpdatePackage([Package]$Package) {
        return $this.InstallNuGetPackage($Package, 'Update')
    }

    [Result] RemovePackage([Package]$Package) {
        if (-not $this.TestPackageIdentity($Package)) {
            return $this.NewFailure(
                'A valid NuGet package ID and version are required.',
                'PHX_INVALID_PACKAGE'
            )
        }
        [string]$storeRoot = [IO.Path]::GetFullPath($this.GetStoreRoot())
        [string]$targetPath = [IO.Path]::GetFullPath((Join-Path `
            (Join-Path $storeRoot $Package.Id) $Package.Version))
        if (-not $targetPath.StartsWith(
            $storeRoot.TrimEnd('\') + '\',
            [StringComparison]::OrdinalIgnoreCase
        )) {
            return $this.NewFailure('Unsafe NuGet store path.', 'PHX_UNSAFE_PATH')
        }
        try {
            if (Test-Path -LiteralPath $targetPath) {
                Remove-Item -LiteralPath $targetPath -Recurse -Force
            }
            $result = [Result]::Success()
            $result.Code = 'PHX_REMOVED'
            $result.Message = "Removed NuGet package '$($Package.Id)' $($Package.Version)."
            $result.Provider = $this.Name
            $result.Operation = 'Remove'
            $result.Target = $Package.Id
            $result.Data = $Package
            $Package.Installed = $false
            return $result
        }
        catch {
            return $this.NewFailure(
                "NuGet removal failed: $($_.Exception.Message)",
                'PHX_REMOVE_FAILED'
            )
        }
    }

    [Result] ExportPackages() {
        $inventory = $this.GetInstalledPackages()
        $result = [Result]::Success($inventory)
        $result.Code = 'PHX_EXPORTED'
        $result.Message = "Exported $($inventory.Count) NuGet packages."
        $result.Provider = $this.Name
        $result.Operation = 'Export'
        $result.Target = $this.GetStoreRoot()
        return $result
    }

    [Result[]] RestorePackages([Package[]]$Packages) {
        $results = [System.Collections.Generic.List[Result]]::new()
        foreach ($package in @($Packages)) {
            $results.Add($this.InstallPackageSilent($package))
        }
        return $results.ToArray()
    }

    hidden [string[]] GetConfiguredFeeds() {
        $feeds = [System.Collections.Generic.List[string]]::new()
        if (-not [string]::IsNullOrWhiteSpace($env:PHOENIX_NUGET_FEEDS)) {
            foreach ($feed in $env:PHOENIX_NUGET_FEEDS.Split(';')) {
                if (-not [string]::IsNullOrWhiteSpace($feed)) {
                    $feeds.Add($feed.Trim())
                }
            }
        }
        if (-not $feeds.Contains('https://api.nuget.org/v3/index.json')) {
            $feeds.Add('https://api.nuget.org/v3/index.json')
        }
        return $feeds.ToArray()
    }

    hidden [string] GetStoreRoot() {
        return Join-Path $env:LOCALAPPDATA 'Phoenix\NuGet'
    }

    hidden [bool] TestPackageIdentity([Package]$Package) {
        return (
            $null -ne $Package -and
            $Package.Id -match '^[A-Za-z0-9_.-]+$' -and
            $Package.Version -match '^[A-Za-z0-9_.+-]+$'
        )
    }

    hidden [string] GetPackageValue([Package]$Package, [string]$Name) {
        $property = $Package.PSObject.Properties[$Name]
        if ($null -eq $property) { return '' }
        return [string]$property.Value
    }

    hidden [Result] InstallNuGetPackage(
        [Package]$Package,
        [string]$Operation
    ) {
        if (-not $this.TestPackageIdentity($Package)) {
            return $this.NewFailure(
                'A valid NuGet package ID and version are required.',
                'PHX_INVALID_PACKAGE'
            )
        }
        [string]$downloadUri = $this.GetPackageValue($Package, 'DownloadUri')
        if ([string]::IsNullOrWhiteSpace($downloadUri)) {
            return $this.NewFailure(
                'A NuGet package download URI is required.',
                'PHX_DOWNLOAD_REQUIRED'
            )
        }
        [string]$storeRoot = $this.GetStoreRoot()
        [string]$targetPath = Join-Path (Join-Path $storeRoot $Package.Id) $Package.Version
        [string]$tempPath = Join-Path `
            ([IO.Path]::GetTempPath()) `
            ("Phoenix-NuGet-$([guid]::NewGuid().ToString('N')).nupkg")
        try {
            $null = New-Item -ItemType Directory -Path $targetPath -Force
            Invoke-WebRequest `
                -Uri $downloadUri `
                -OutFile $tempPath `
                -UseBasicParsing `
                -ErrorAction Stop
            $this.ExpandNuGetPackage($tempPath, $targetPath)
            $result = [Result]::Success()
            $result.Code = if ($Operation -eq 'Update') {
                'PHX_UPDATED'
            }
            else { 'PHX_INSTALLED' }
            $result.Message = "$Operation completed for NuGet package '$($Package.Id)'."
            $result.Provider = $this.Name
            $result.Operation = $Operation
            $result.Target = $Package.Id
            $result.Data = $Package
            $Package.Installed = $true
            return $result
        }
        catch {
            return $this.NewFailure(
                "NuGet $Operation failed: $($_.Exception.Message)",
                "PHX_$($Operation.ToUpperInvariant())_FAILED"
            )
        }
        finally {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
    }

    hidden [void] ExpandNuGetPackage(
        [string]$ArchivePath,
        [string]$DestinationPath
    ) {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
        try {
            [string]$root = [IO.Path]::GetFullPath($DestinationPath).
                TrimEnd('\') + '\'
            foreach ($entry in $archive.Entries) {
                [string]$entryPath = [IO.Path]::GetFullPath(
                    (Join-Path $DestinationPath $entry.FullName)
                )
                if (-not $entryPath.StartsWith(
                    $root,
                    [StringComparison]::OrdinalIgnoreCase
                )) {
                    throw 'NuGet package contains an unsafe archive path.'
                }
                if ([string]::IsNullOrEmpty($entry.Name)) {
                    $null = New-Item -ItemType Directory -Path $entryPath -Force
                    continue
                }
                $null = New-Item `
                    -ItemType Directory `
                    -Path ([IO.Path]::GetDirectoryName($entryPath)) `
                    -Force
                [IO.Compression.ZipFileExtensions]::ExtractToFile(
                    $entry,
                    $entryPath,
                    $true
                )
            }
        }
        finally {
            $archive.Dispose()
        }
    }
}
