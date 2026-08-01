class GitHubProvider : PhoenixProvider {
    GitHubProvider() {
        $this.Name = 'GitHub Releases'
        $this.Type = 'Release Asset'
        $this.Priority = 70
        $this.RequiredPrivilege = [PhoenixPrivilegeLevel]::User
        $this.SupportsSearch = $true
        $this.SupportsInventory = $false
        $this.SupportsInstall = $true
        $this.SupportsUpdate = $true
        $this.SupportsRemove = $false
        $this.SupportsRepair = $false
        $this.SupportsSilentInstall = $true
        $this.SupportsInteractiveInstall = $true
        $this.SupportsExport = $false
        $this.SupportsRestore = $false
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
        $result.Message = 'GitHub Releases support is built into Phoenix.'
        $result.Provider = $this.Name
        $result.Operation = 'InstallProvider'
        return $result
    }

    [Result] UpdateProvider() {
        return $this.InstallProvider()
    }

    [Package[]] GetInstalledPackages() {
        return @()
    }

    [Package[]] SearchPackage([string]$Name) {
        if ([string]::IsNullOrWhiteSpace($Name)) {
            return @()
        }

        $repositories = [System.Collections.Generic.List[object]]::new()
        if ($Name -match '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
            try {
                $repositories.Add(
                    $this.InvokeGitHubApi("/repos/$Name")
                )
            }
            catch {
                return @()
            }
        }
        else {
            try {
                $encoded = [uri]::EscapeDataString("$Name in:name")
                $search = $this.InvokeGitHubApi(
                    "/search/repositories?q=$encoded&per_page=10"
                )
                foreach ($repository in @($search.items)) {
                    $repositories.Add($repository)
                }
            }
            catch {
                return @()
            }
        }

        $packages = [System.Collections.Generic.List[Package]]::new()
        foreach ($repository in $repositories) {
            try {
                $release = $this.InvokeGitHubApi(
                    "/repos/$($repository.full_name)/releases/latest"
                )
                $package = $this.NewReleasePackage($repository, $release, '')
                if ($null -ne $package) {
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
        return $this.InstallReleasePackage($Package, $true, 'Install')
    }

    [Result] InstallPackageInteractive([Package]$Package) {
        return $this.InstallReleasePackage($Package, $false, 'Install')
    }

    [Result] UpdatePackage([Package]$Package) {
        return $this.InstallReleasePackage($Package, $true, 'Update')
    }

    [Result] RemovePackage([Package]$Package) {
        return $this.NewFailure(
            'Remove the installed package through its MSI or EXE inventory record.',
            'PHX_REMOVE_UNAVAILABLE'
        )
    }

    hidden [object] InvokeGitHubApi([string]$Path) {
        $headers = @{
            Accept = 'application/vnd.github+json'
            'User-Agent' = 'PhoenixDeploy'
            'X-GitHub-Api-Version' = '2022-11-28'
        }
        if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) {
            $headers.Authorization = "Bearer $($env:GITHUB_TOKEN)"
        }
        return Invoke-RestMethod `
            -Uri "https://api.github.com$Path" `
            -Headers $headers `
            -Method Get `
            -ErrorAction Stop
    }

    hidden [GitHubReleasePackageDefinition] NewReleasePackage(
        [object]$Repository,
        [object]$Release,
        [string]$AssetPattern
    ) {
        $asset = $this.SelectReleaseAsset(@($Release.assets), $AssetPattern)
        if ($null -eq $asset) {
            return $null
        }

        $package = [GitHubReleasePackageDefinition]::new()
        $package.Name = [string]$Repository.name
        $package.Id = [string]$Repository.full_name
        $package.Repository = [string]$Repository.full_name
        $package.ReleaseTag = [string]$Release.tag_name
        $package.ReleaseName = [string]$Release.name
        $package.Version = ([string]$Release.tag_name).TrimStart('v', 'V')
        $package.AssetName = [string]$asset.name
        $package.AssetPattern = $AssetPattern
        $package.DownloadUri = [string]$asset.browser_download_url
        $package.ReleaseNotes = [string]$Release.body
        $package.ReleaseNotesUrl = [string]$Release.html_url
        $package.PublishedAtUtc = [datetime]$Release.published_at
        $package.Architecture = $this.GetWindowsArchitecture()
        $package.InstallerType = [IO.Path]::GetExtension($package.AssetName).
            TrimStart('.').ToUpperInvariant()
        $package.DetectionDisplayName = [string]$Repository.name
        $package.InstalledVersion = $this.FindInstalledVersion(
            $package.DetectionDisplayName
        )
        $package.Installed =
            -not [string]::IsNullOrWhiteSpace($package.InstalledVersion)

        foreach ($candidate in @($Release.assets)) {
            [string]$candidateName = [string]$candidate.name
            if (
                $candidateName -ieq "$($package.AssetName).sha256" -or
                $candidateName -match '(?i)^(checksums?|sha256sums?)(\.txt)?$'
            ) {
                $package.ChecksumUri = [string]$candidate.browser_download_url
                break
            }
        }
        return $package
    }

    hidden [object] SelectReleaseAsset(
        [object[]]$Assets,
        [string]$AssetPattern
    ) {
        $supported = @(
            $Assets |
                Where-Object {
                    [string]$_.name -match '(?i)\.(msi|exe)$' -and
                    [string]$_.name -notmatch '(?i)(symbols?|debug|checksum|sha256)'
                }
        )
        if (-not [string]::IsNullOrWhiteSpace($AssetPattern)) {
            $supported = @(
                $supported |
                    Where-Object { [string]$_.name -match $AssetPattern }
            )
        }
        if ($supported.Count -eq 0) {
            return $null
        }

        [string]$architecture = $this.GetWindowsArchitecture()
        [string]$architecturePattern = switch ($architecture) {
            'arm64' { '(?i)(arm64|aarch64)' }
            'x86' { '(?i)(x86|i[3-6]86|win32)' }
            default { '(?i)(x64|amd64|win64)' }
        }
        $architectureAsset = @(
            $supported |
                Where-Object { [string]$_.name -match $architecturePattern }
        ) | Select-Object -First 1
        if ($null -ne $architectureAsset) {
            return $architectureAsset
        }
        return $supported | Select-Object -First 1
    }

    hidden [string] GetWindowsArchitecture() {
        [string]$architecture =
            [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.
                ToString().ToLowerInvariant()
        if ($architecture -eq 'x64') {
            return 'x64'
        }
        if ($architecture -eq 'arm64') {
            return 'arm64'
        }
        return 'x86'
    }

    hidden [string] FindInstalledVersion([string]$DisplayName) {
        foreach ($registryPath in @(
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )) {
            $match = Get-ItemProperty $registryPath -ErrorAction SilentlyContinue |
                Where-Object {
                    ([string]$_.DisplayName).IndexOf(
                        $DisplayName,
                        [StringComparison]::OrdinalIgnoreCase
                    ) -ge 0 -and
                    -not [string]::IsNullOrWhiteSpace([string]$_.DisplayVersion)
                } |
                Select-Object -First 1
            if ($null -ne $match) {
                return [string]$match.DisplayVersion
            }
        }
        return ''
    }

    hidden [Result] InstallReleasePackage(
        [Package]$Package,
        [bool]$Silent,
        [string]$Operation
    ) {
        if ($null -eq $Package) {
            return $this.NewFailure(
                'A GitHub release package definition is required.',
                'PHX_INVALID_PACKAGE'
            )
        }
        [string]$downloadUri = $this.GetPackageValue($Package, 'DownloadUri')
        [string]$assetName = $this.GetPackageValue($Package, 'AssetName')
        if (
            [string]::IsNullOrWhiteSpace($downloadUri) -or
            [string]::IsNullOrWhiteSpace($assetName)
        ) {
            return $this.NewFailure(
                'The GitHub release asset definition is incomplete.',
                'PHX_RELEASE_ASSET_REQUIRED'
            )
        }

        [string]$downloadRoot = Join-Path `
            ([IO.Path]::GetTempPath()) `
            ('Phoenix-GitHub-{0}' -f [guid]::NewGuid().ToString('N'))
        [string]$downloadPath = Join-Path $downloadRoot $assetName
        try {
            $null = New-Item -ItemType Directory -Path $downloadRoot -Force
            Invoke-WebRequest `
                -Uri $downloadUri `
                -OutFile $downloadPath `
                -UseBasicParsing `
                -ErrorAction Stop

            [string]$expectedHash = $this.GetPackageValue($Package, 'SHA256')
            [string]$checksumUri = $this.GetPackageValue($Package, 'ChecksumUri')
            if (
                [string]::IsNullOrWhiteSpace($expectedHash) -and
                -not [string]::IsNullOrWhiteSpace($checksumUri)
            ) {
                [string]$checksumText = Invoke-RestMethod `
                    -Uri $checksumUri `
                    -Method Get `
                    -ErrorAction Stop
                $escapedAsset = [regex]::Escape($assetName)
                if ($checksumText -match "(?im)^([0-9a-f]{64})\s+\*?$escapedAsset\s*$") {
                    $expectedHash = $Matches[1]
                }
            }
            if (-not [string]::IsNullOrWhiteSpace($expectedHash)) {
                [string]$actualHash = (Get-FileHash `
                    -LiteralPath $downloadPath `
                    -Algorithm SHA256).Hash
                if ($actualHash -ine $expectedHash) {
                    return $this.NewFailure(
                        'The downloaded GitHub release asset failed SHA-256 verification.',
                        'PHX_HASH_MISMATCH'
                    )
                }
            }

            $Package.DownloadedFile = $downloadPath
            $Package.CleanupPaths = @($downloadRoot)
            [string]$extension = [IO.Path]::GetExtension($assetName)
            [Result]$engineResult = if ($extension -ieq '.msi') {
                $engine = [MSIProvider]::new()
                if ($Silent) {
                    $engine.InstallPackageSilent($Package)
                }
                else {
                    $engine.InstallPackageInteractive($Package)
                }
            }
            elseif ($extension -ieq '.exe') {
                $engine = [EXEProvider]::new()
                if ($Silent) {
                    $engine.InstallPackageSilent($Package)
                }
                else {
                    $engine.InstallPackageInteractive($Package)
                }
            }
            else {
                $this.NewFailure(
                    "The release asset type '$extension' is not installable.",
                    'PHX_INSTALLER_TYPE_UNSUPPORTED'
                )
            }
            $engineResult.Provider = $this.Name
            $engineResult.Operation = $Operation
            $engineResult.Target = $Package.Id
            return $engineResult
        }
        catch {
            $result = $this.NewFailure(
                "GitHub release $Operation failed: $($_.Exception.Message)",
                "PHX_$($Operation.ToUpperInvariant())_FAILED"
            )
            $result.Provider = $this.Name
            $result.Operation = $Operation
            $result.Target = $Package.Id
            return $result
        }
        finally {
            if (
                -not $Package.PreserveDownloads -and
                (Test-Path -LiteralPath $downloadRoot)
            ) {
                Remove-Item `
                    -LiteralPath $downloadRoot `
                    -Recurse `
                    -Force `
                    -ErrorAction SilentlyContinue
            }
        }
    }

    hidden [string] GetPackageValue(
        [Package]$Package,
        [string]$PropertyName
    ) {
        $property = $Package.PSObject.Properties[$PropertyName]
        if ($null -eq $property) {
            return ''
        }
        return [string]$property.Value
    }
}
