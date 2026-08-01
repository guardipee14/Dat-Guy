class WSUSProvider : PhoenixProvider {
    WSUSProvider() {
        $this.Name = 'WSUS'
        $this.Type = 'Managed Windows Update'
        $this.Priority = 50
        $this.RequiredPrivilege = [PhoenixPrivilegeLevel]::Administrator
        $this.SupportsSearch = $true
        $this.SupportsInventory = $true
        $this.SupportsInstall = $true
        $this.SupportsUpdate = $true
        $this.SupportsRemove = $false
        $this.SupportsRepair = $false
        $this.SupportsSilentInstall = $true
        $this.SupportsInteractiveInstall = $false
        $this.SupportsExport = $false
        $this.SupportsRestore = $false
        $this.Available = $this.TestAvailable()
    }

    [bool] TestAvailable() {
        return Test-Path `
            -LiteralPath (Join-Path $env:SystemRoot 'System32\wuapi.dll') `
            -PathType Leaf
    }

    [Result] InstallProvider() {
        $result = [Result]::Success()
        $result.Code = 'PHX_PROVIDER_BUILT_IN'
        $result.Message = 'Windows Update Agent is built into Windows.'
        $result.Provider = $this.Name
        $result.Operation = 'InstallProvider'
        return $result
    }

    [Result] UpdateProvider() {
        return $this.InstallProvider()
    }

    [Package[]] GetInstalledPackages() {
        return $this.SearchWindowsUpdates('IsInstalled=1', '')
    }

    [Package[]] SearchPackage([string]$Name) {
        return $this.SearchWindowsUpdates(
            'IsInstalled=0 and IsHidden=0',
            $Name
        )
    }

    [Result] InstallPackageSilent([Package]$Package) {
        return $this.InstallManagedUpdate($Package)
    }

    [Result] InstallPackageInteractive([Package]$Package) {
        return $this.NewFailure(
            'Managed update installation is unattended by Windows Update Agent.',
            'PHX_INTERACTIVE_UNAVAILABLE'
        )
    }

    [Result] UpdatePackage([Package]$Package) {
        return $this.InstallManagedUpdate($Package)
    }

    [Result] RemovePackage([Package]$Package) {
        return $this.NewFailure(
            'Windows Update Agent does not provide general update removal.',
            'PHX_REMOVE_UNAVAILABLE'
        )
    }

    hidden [hashtable] GetUpdatePolicy() {
        $policy = @{
            Managed = $false
            WUServer = ''
            StatusServer = ''
            Source = 'Microsoft Update'
        }
        $windowsUpdatePath =
            'HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate'
        $auPath = Join-Path $windowsUpdatePath 'AU'
        $settings = Get-ItemProperty `
            -LiteralPath $windowsUpdatePath `
            -ErrorAction SilentlyContinue
        $au = Get-ItemProperty `
            -LiteralPath $auPath `
            -ErrorAction SilentlyContinue
        if ($null -ne $settings) {
            $policy.WUServer = [string]$settings.WUServer
            $policy.StatusServer = [string]$settings.WUStatusServer
        }
        $policy.Managed =
            $null -ne $au -and
            [int]$au.UseWUServer -eq 1 -and
            -not [string]::IsNullOrWhiteSpace($policy.WUServer)
        if ($policy.Managed) {
            $policy.Source = $policy.WUServer
        }
        return $policy
    }

    hidden [object] NewUpdateSearcher([object]$Session) {
        $searcher = $Session.CreateUpdateSearcher()
        $policy = $this.GetUpdatePolicy()
        if ($policy.Managed) {
            $searcher.ServerSelection = 1
        }
        else {
            $searcher.ServerSelection = 2
        }
        return $searcher
    }

    hidden [Package[]] SearchWindowsUpdates(
        [string]$Criteria,
        [string]$NameFilter
    ) {
        $packages = [System.Collections.Generic.List[Package]]::new()
        if (-not $this.TestAvailable()) { return @() }
        try {
            $session = New-Object -ComObject Microsoft.Update.Session
            $searcher = $this.NewUpdateSearcher($session)
            $searchResult = $searcher.Search($Criteria)
            $policy = $this.GetUpdatePolicy()
            foreach ($update in @($searchResult.Updates)) {
                [string]$kbText = @($update.KBArticleIDs) -join ', '
                if (
                    -not [string]::IsNullOrWhiteSpace($NameFilter) -and
                    [string]$update.Title -notlike "*$NameFilter*" -and
                    $kbText -notlike "*$NameFilter*"
                ) { continue }

                $package = [WSUSPackageDefinition]::new()
                $package.Name = [string]$update.Title
                $package.Id = [string]$update.Identity.UpdateID
                $package.UpdateId = $package.Id
                $package.RevisionNumber = [int]$update.Identity.RevisionNumber
                $package.Version = [string]$package.RevisionNumber
                $package.KBArticleIds = [string[]]@($update.KBArticleIDs)
                $package.Source = [string]$policy.Source
                $package.ApprovalStatus = if ($update.IsMandatory) {
                    'Mandatory'
                }
                elseif ($update.AutoSelectOnWebSites) {
                    'Approved or auto-selected'
                }
                else { 'Offered by managed source' }
                $package.Applicable = -not [bool]$update.IsInstalled
                $package.Downloaded = [bool]$update.IsDownloaded
                $package.Mandatory = [bool]$update.IsMandatory
                $package.Installed = [bool]$update.IsInstalled
                $packages.Add($package)
            }
        }
        catch {
            return $packages.ToArray()
        }
        return $packages.ToArray()
    }

    hidden [string] GetUpdateId([Package]$Package) {
        if ($null -eq $Package) { return '' }
        $property = $Package.PSObject.Properties['UpdateId']
        if ($null -ne $property -and
            -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
            return [string]$property.Value
        }
        return $Package.Id
    }

    hidden [Result] InstallManagedUpdate([Package]$Package) {
        [string]$updateId = $this.GetUpdateId($Package)
        if ($updateId -notmatch '^[0-9A-Fa-f-]{36}$') {
            return $this.NewFailure(
                'A valid Windows Update identity is required.',
                'PHX_INVALID_PACKAGE'
            )
        }
        try {
            $session = New-Object -ComObject Microsoft.Update.Session
            $searcher = $this.NewUpdateSearcher($session)
            $searchResult = $searcher.Search(
                "UpdateID='$updateId' and IsInstalled=0 and IsHidden=0"
            )
            if ($searchResult.Updates.Count -eq 0) {
                return $this.NewFailure(
                    'The update is not applicable or is no longer offered.',
                    'PHX_UPDATE_NOT_APPLICABLE'
                )
            }
            $update = $searchResult.Updates.Item(0)
            if (-not $update.EulaAccepted) { $update.AcceptEula() }
            $collection = New-Object -ComObject Microsoft.Update.UpdateColl
            $null = $collection.Add($update)

            if (-not $update.IsDownloaded) {
                $downloader = $session.CreateUpdateDownloader()
                $downloader.Updates = $collection
                $downloadResult = $downloader.Download()
                if ([int]$downloadResult.ResultCode -notin @(2, 3)) {
                    return $this.NewUpdateFailure(
                        $Package,
                        'Download',
                        [int]$downloadResult.HResult,
                        'The managed update download failed.'
                    )
                }
            }

            $installer = $session.CreateUpdateInstaller()
            $installer.Updates = $collection
            $installResult = $installer.Install()
            [int]$resultCode = [int]$installResult.ResultCode
            [bool]$success = $resultCode -in @(2, 3)
            if (-not $success) {
                return $this.NewUpdateFailure(
                    $Package,
                    'Install',
                    [int]$installResult.HResult,
                    "Managed update installation returned result code $resultCode."
                )
            }
            $result = [Result]::Success()
            $result.Code = if ($installResult.RebootRequired) {
                'PHX_INSTALL_RESTART_REQUIRED'
            }
            else { 'PHX_INSTALLED' }
            $result.Message = "Installed managed update '$($Package.Name)'."
            $result.Provider = $this.Name
            $result.Operation = 'Install'
            $result.Target = $updateId
            $result.HasExitCode = $true
            $result.ExitCode = [int]$installResult.HResult
            $result.RebootRequired = [bool]$installResult.RebootRequired
            $result.Data = $Package
            $Package.Installed = $true
            return $result
        }
        catch {
            return $this.NewUpdateFailure(
                $Package,
                'Install',
                $_.Exception.HResult,
                $_.Exception.Message
            )
        }
    }

    hidden [Result] NewUpdateFailure(
        [Package]$Package,
        [string]$Operation,
        [int]$HResult,
        [string]$Message
    ) {
        $result = $this.NewFailure($Message, "PHX_$($Operation.ToUpperInvariant())_FAILED")
        $result.Provider = $this.Name
        $result.Operation = $Operation
        $result.Target = if ($null -ne $Package) { $Package.Id } else { '' }
        $result.HasExitCode = $true
        $result.ExitCode = $HResult
        $result.Data = $Package
        return $result
    }
}
