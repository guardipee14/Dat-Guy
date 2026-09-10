function Get-PhoenixWindowsImageContentFiles {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path, [switch]$SingleFile)
    Test-PhoenixPathAncestors -Path $Path
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    $base = if ($SingleFile) { $item.DirectoryName } else { $item.FullName }
    if ($SingleFile -and $item -isnot [IO.FileInfo]) { throw 'A regular input file is required.' }
    if (-not $SingleFile) { Test-PhoenixRegularDirectoryTree -Path $base }
    $files = @(if ($SingleFile) { $item } else { Get-ChildItem -LiteralPath $base -File -Force -Recurse -ErrorAction Stop })
    if (-not $files.Count) { throw 'Servicing source contains no files.' }
    foreach ($file in $files) {
        [pscustomobject]@{
            Path=$file.FullName; RelativePath=[IO.Path]::GetRelativePath($base,$file.FullName)
            Length=$file.Length; SHA256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    }
}

function Get-PhoenixWindowsImageContentPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][PhoenixWindowsImageWorkspace]$Workspace,
        [Parameter(Mandatory)][ValidateSet('Driver','Package','Capability')][string]$Type,
        [Parameter(Mandatory)][string]$Value,
        [string]$SourcePath=''
    )
    Assert-PhoenixWindowsImageMount -Workspace $Workspace
    $mountPath=$Workspace.MountPath
    if (@(Get-WindowsPackage -Path $mountPath -ErrorAction Stop | Where-Object { [string]$_.PackageState -like '*Pending*' }).Count) {
        throw 'Pending packages require commit and first-boot validation before additional servicing.'
    }
    $identity=''; $installed=$false; $bootCritical=$false
    switch ($Type) {
        'Package' {
            $item=Get-Item -LiteralPath $Value -ErrorAction Stop
            if ($item -isnot [IO.FileInfo] -or $item.Extension -ine '.cab') {
                throw 'Package/update inputs must be CAB files; inspect and extract MSU containers separately.'
            }
            $files=@(Get-PhoenixWindowsImageContentFiles -Path $item.FullName -SingleFile)
            $details=@(Get-WindowsPackage -Path $mountPath -PackagePath $item.FullName -ErrorAction Stop)
            if ($details.Count -ne 1 -or -not $details[0].PackageName) { throw 'Package identity is ambiguous.' }
            $identity=[string]$details[0].PackageName
            $installed=[string]$details[0].PackageState -eq 'Installed'
            if (-not $installed -and -not $details[0].Applicable) { throw "Package is not applicable: $identity" }
            if ([string]$details[0].PackageState -like '*Pending*') { throw 'Pending package state requires first-boot validation before further servicing.' }
            $Value=$item.FullName
        }
        'Driver' {
            $item=Get-Item -LiteralPath $Value -ErrorAction Stop
            if ($item -isnot [IO.FileInfo] -or $item.Extension -ine '.inf') { throw 'Select explicit INF files, not directories or installers.' }
            $files=@(Get-PhoenixWindowsImageContentFiles -Path $item.DirectoryName)
            $details=@(Get-WindowsDriver -Path $mountPath -Driver $item.FullName -ErrorAction Stop)
            if (-not $details.Count) { throw 'Driver metadata is unavailable.' }
            foreach ($detail in $details) {
                if ([string]$detail.Architecture -notin @('9','x64','amd64') -or [string]$detail.DriverSignature -ne 'Signed') {
                    throw 'Only DISM-verified signed x64 driver packages are accepted.'
                }
                if ($detail.BootCritical) { $bootCritical=$true }
            }
            $identity=$item.Name
            $sourceHash=(Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
            $installed=Test-PhoenixInstalledImageDriver -MountPath $mountPath -InfName $identity -SHA256 $sourceHash
            $Value=$item.FullName
        }
        'Capability' {
            if ($Value -notmatch '^[A-Za-z0-9._~+-]+$' -or -not $SourcePath) { throw 'An exact capability name and offline source directory are required.' }
            $files=@(Get-PhoenixWindowsImageContentFiles -Path $SourcePath)
            $details=@(Get-WindowsCapability -Path $mountPath -Name $Value -LimitAccess -ErrorAction Stop)
            if ($details.Count -ne 1 -or [string]$details[0].Name -cne $Value) { throw 'Capability identity is unavailable or ambiguous.' }
            $identity=$Value
            $installed=[string]$details[0].State -eq 'Installed'
            if (-not $installed -and [string]$details[0].State -ne 'NotPresent') { throw 'Capability state is not serviceable.' }
        }
    }
    return [pscustomobject]@{
        Type=$Type; Value=$Value; Identity=$identity; SourcePath=$SourcePath
        AlreadyInstalled=$installed; BootCritical=$bootCritical; Files=$files
        Bytes=[long](($files | Measure-Object -Property Length -Sum).Sum)
    }
}

function Test-PhoenixInstalledImageDriver {
    [CmdletBinding()]
    param([string]$MountPath,[string]$InfName,[string]$SHA256)
    foreach ($driver in @(Get-WindowsDriver -Path $MountPath -ErrorAction Stop)) {
        if ([IO.Path]::GetFileName($driver.OriginalFileName) -ine $InfName) { continue }
        $installedPath=[IO.Path]::GetFullPath($driver.OriginalFileName)
        if (-not $installedPath.StartsWith($MountPath.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) { continue }
        if ((Test-Path -LiteralPath $installedPath -PathType Leaf) -and
            (Get-FileHash -LiteralPath $installedPath -Algorithm SHA256).Hash -ieq $SHA256) { return $true }
    }
    return $false
}

function Test-PhoenixWindowsImageContentApplied {
    [CmdletBinding()]
    param([PhoenixWindowsImageWorkspace]$Workspace, [pscustomobject]$Plan)
    Assert-PhoenixWindowsImageMount -Workspace $Workspace
    switch ($Plan.Type) {
        'Package' {
            $rows=@(Get-WindowsPackage -Path $Workspace.MountPath -PackageName $Plan.Identity -ErrorAction Stop)
            if ($rows.Count -ne 1 -or $rows[0].PackageName -cne $Plan.Identity -or
                [string]$rows[0].PackageState -notin @('Installed','InstallPending')) { throw 'Package post-verification failed.' }
            return [string]$rows[0].PackageState
        }
        'Capability' {
            $rows=@(Get-WindowsCapability -Path $Workspace.MountPath -Name $Plan.Identity -LimitAccess -ErrorAction Stop)
            if ($rows.Count -ne 1 -or $rows[0].Name -cne $Plan.Identity -or
                [string]$rows[0].State -notin @('Installed','InstallPending')) { throw 'Capability post-verification failed.' }
            return [string]$rows[0].State
        }
        'Driver' {
            $hash=(Get-FileHash -LiteralPath $Plan.Value -Algorithm SHA256).Hash
            if (-not (Test-PhoenixInstalledImageDriver -MountPath $Workspace.MountPath -InfName $Plan.Identity -SHA256 $hash)) {
                throw 'Installed driver INF hash verification failed.'
            }
            return 'Installed'
        }
    }
}
