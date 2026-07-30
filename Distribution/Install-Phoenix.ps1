[CmdletBinding(
    SupportsShouldProcess = $true,
    ConfirmImpact = 'Medium'
)]
param(
    [Parameter()]
    [ValidateSet(
        'CurrentUser',
        'AllUsers'
    )]
    [string]$Scope = 'CurrentUser',

    [Parameter()]
    [string]$InstallPath,

    [Parameter()]
    [switch]$NoShortcuts,

    [Parameter()]
    [switch]$Launch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-PhoenixInstallerAdministrator {

    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $identity =
        [Security.Principal.WindowsIdentity]::GetCurrent()

    $principal =
        [Security.Principal.WindowsPrincipal]::new(
            $identity
        )

    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Copy-PhoenixInstallerItem {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Destination
    )

    if (Test-Path -LiteralPath $Source -PathType Container) {
        New-Item `
            -ItemType Directory `
            -Path $Destination `
            -Force |
            Out-Null

        foreach (
            $child in @(
                Get-ChildItem `
                    -LiteralPath $Source `
                    -Force
            )
        ) {
            Copy-Item `
                -LiteralPath $child.FullName `
                -Destination $Destination `
                -Recurse `
                -Force `
                -ErrorAction Stop
        }

        return
    }

    New-Item `
        -ItemType Directory `
        -Path (
            Split-Path `
                -Path $Destination `
                -Parent
        ) `
        -Force |
        Out-Null

    Copy-Item `
        -LiteralPath $Source `
        -Destination $Destination `
        -Force `
        -ErrorAction Stop
}

function New-PhoenixShortcut {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ShortcutPath,

        [Parameter(Mandatory)]
        [string]$TargetPath,

        [Parameter(Mandatory)]
        [string]$WorkingDirectory,

        [Parameter()]
        [string]$Description = 'Phoenix Control Center'
    )

    New-Item `
        -ItemType Directory `
        -Path (
            Split-Path `
                -Path $ShortcutPath `
                -Parent
        ) `
        -Force |
        Out-Null

    $shell =
        New-Object `
            -ComObject WScript.Shell

    $shortcut =
        $shell.CreateShortcut(
            $ShortcutPath
        )

    $shortcut.TargetPath = $TargetPath
    $shortcut.WorkingDirectory = $WorkingDirectory
    $shortcut.Description = $Description
    $shortcut.Save()
}

if (-not $IsWindows) {
    throw 'Phoenix can only be installed on Windows.'
}

if ($PSVersionTable.PSVersion -lt [version]'7.4.0') {
    throw (
        'Phoenix requires PowerShell 7.4 or later. ' +
        "Current version: $($PSVersionTable.PSVersion)"
    )
}

if ([Environment]::OSVersion.Version.Build -lt 10240) {
    throw (
        'Phoenix requires Windows 10, Windows Server 2016, or a ' +
        'newer Windows release.'
    )
}

[string]$payloadRoot =
    Join-Path `
        $PSScriptRoot `
        'Payload'

[string]$releaseManifestPath =
    Join-Path `
        $PSScriptRoot `
        'RELEASE.json'

foreach (
    $requiredPath in @(
        $payloadRoot
        $releaseManifestPath
        (
            Join-Path `
                $PSScriptRoot `
                'Uninstall-Phoenix.ps1'
        )
    )
) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required Phoenix release item was not found: $requiredPath"
    }
}

$release =
    Get-Content `
        -LiteralPath $releaseManifestPath `
        -Raw `
        -ErrorAction Stop |
        ConvertFrom-Json `
            -ErrorAction Stop

[string]$releaseRoot =
    [IO.Path]::GetFullPath(
        $PSScriptRoot
    ).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )

[string]$releaseRootPrefix =
    $releaseRoot +
    [IO.Path]::DirectorySeparatorChar

foreach ($releaseFile in @($release.Files)) {
    [string]$relativeReleasePath =
        [string]$releaseFile.Path

    [string]$releaseFilePath =
        [IO.Path]::GetFullPath(
            (
                Join-Path `
                    $releaseRoot `
                    (
                        $relativeReleasePath.Replace(
                            '/',
                            [IO.Path]::DirectorySeparatorChar
                        )
                    )
            )
        )

    if (
        -not $releaseFilePath.StartsWith(
            $releaseRootPrefix,
            [StringComparison]::OrdinalIgnoreCase
        )
    ) {
        throw (
            "Release manifest path '$relativeReleasePath' escapes " +
            'the extracted Phoenix release directory.'
        )
    }

    if (-not (Test-Path -LiteralPath $releaseFilePath -PathType Leaf)) {
        throw "Release file is missing: $relativeReleasePath"
    }

    [string]$actualHash = (
        Get-FileHash `
            -LiteralPath $releaseFilePath `
            -Algorithm SHA256
    ).Hash

    if (
        $actualHash -ine
        [string]$releaseFile.SHA256
    ) {
        throw (
            "Release integrity verification failed for " +
            "'$relativeReleasePath'."
        )
    }
}

[string]$resolvedInstallPath = if (
    -not [string]::IsNullOrWhiteSpace($InstallPath)
) {
    [IO.Path]::GetFullPath($InstallPath)
}
elseif ($Scope -eq 'AllUsers') {
    Join-Path `
        $env:ProgramFiles `
        'Phoenix'
}
else {
    Join-Path `
        $env:LOCALAPPDATA `
        'Programs\Phoenix'
}

if (
    $Scope -eq 'AllUsers' -and
    -not (Test-PhoenixInstallerAdministrator)
) {
    throw (
        'An AllUsers Phoenix installation requires an ' +
        'Administrator PowerShell window.'
    )
}

if (
    (Test-Path -LiteralPath $resolvedInstallPath) -and
    -not (
        (Test-Path -LiteralPath (
            Join-Path `
                $resolvedInstallPath `
                'Phoenix.psd1'
        )) -or
        (Test-Path -LiteralPath (
            Join-Path `
                $resolvedInstallPath `
                '.phoenix-install.json'
        )) -or
        (Test-Path -LiteralPath (
            Join-Path `
                $resolvedInstallPath `
                '.phoenix-user-data.json'
        ))
    )
) {
    throw (
        "Installation path '$resolvedInstallPath' contains files " +
        'that are not recognized as a Phoenix installation.'
    )
}

if (
    -not $PSCmdlet.ShouldProcess(
        $resolvedInstallPath,
        "Install Phoenix $($release.Version) for $Scope"
    )
) {
    return [pscustomobject]@{
        Success     = $true
        Applied     = $false
        Version     = [string]$release.Version
        Scope       = $Scope
        InstallPath = $resolvedInstallPath
    }
}

[string]$installParent =
    Split-Path `
        -Path $resolvedInstallPath `
        -Parent

New-Item `
    -ItemType Directory `
    -Path $installParent `
    -Force |
    Out-Null

[string]$operationId =
    [guid]::NewGuid().ToString('N')

[string]$stagingPath = (
    '{0}.staging-{1}' -f
    $resolvedInstallPath,
    $operationId
)

[string]$backupPath = (
    '{0}.backup-{1}' -f
    $resolvedInstallPath,
    $operationId
)

[string]$preservationPath =
    Join-Path `
        ([IO.Path]::GetTempPath()) `
        "PhoenixPreserve-$operationId"

$preservePaths = @(
    $release.PreserveOnUpgrade |
        ForEach-Object {
            [string]$_
        }
)

[bool]$upgraded = $false
$shortcutPaths = @()

try {
    New-Item `
        -ItemType Directory `
        -Path $stagingPath `
        -Force |
        Out-Null

    foreach (
        $payloadItem in @(
            Get-ChildItem `
                -LiteralPath $payloadRoot `
                -Force
        )
    ) {
        Copy-Item `
            -LiteralPath $payloadItem.FullName `
            -Destination $stagingPath `
            -Recurse `
            -Force `
            -ErrorAction Stop
    }

    if (Test-Path -LiteralPath $resolvedInstallPath) {
        $upgraded = $true

        foreach ($relativePath in $preservePaths) {
            [string]$existingPath =
                Join-Path `
                    $resolvedInstallPath `
                    $relativePath

            if (-not (Test-Path -LiteralPath $existingPath)) {
                continue
            }

            [string]$preservedPath =
                Join-Path `
                    $preservationPath `
                    $relativePath

            Copy-PhoenixInstallerItem `
                -Source $existingPath `
                -Destination $preservedPath
        }

        foreach ($relativePath in $preservePaths) {
            [string]$preservedPath =
                Join-Path `
                    $preservationPath `
                    $relativePath

            if (-not (Test-Path -LiteralPath $preservedPath)) {
                continue
            }

            [string]$stagedPath =
                Join-Path `
                    $stagingPath `
                    $relativePath

            Copy-PhoenixInstallerItem `
                -Source $preservedPath `
                -Destination $stagedPath
        }
    }

    [string]$stagedSettingsPath =
        Join-Path `
            $stagingPath `
            'Config\Settings.json'

    if (Test-Path -LiteralPath $stagedSettingsPath) {
        $stagedSettings =
            Get-Content `
                -LiteralPath $stagedSettingsPath `
                -Raw |
                ConvertFrom-Json

        $stagedSettings.Version =
            [string]$release.Version

        $stagedSettings |
            ConvertTo-Json `
                -Depth 20 |
            Set-Content `
                -LiteralPath $stagedSettingsPath `
                -Encoding UTF8
    }

    Copy-Item `
        -LiteralPath (
            Join-Path `
                $PSScriptRoot `
                'Uninstall-Phoenix.ps1'
        ) `
        -Destination (
            Join-Path `
                $stagingPath `
                'Uninstall-Phoenix.ps1'
        ) `
        -Force `
        -ErrorAction Stop

    [string]$desktopFolder = if ($Scope -eq 'AllUsers') {
        [Environment]::GetFolderPath(
            'CommonDesktopDirectory'
        )
    }
    else {
        [Environment]::GetFolderPath(
            'Desktop'
        )
    }

    [string]$programsFolder = if ($Scope -eq 'AllUsers') {
        [Environment]::GetFolderPath(
            'CommonPrograms'
        )
    }
    else {
        [Environment]::GetFolderPath(
            'Programs'
        )
    }

    if (-not $NoShortcuts) {
        $shortcutPaths = @(
            (
                Join-Path `
                    $desktopFolder `
                    'Phoenix Control Center.lnk'
            )
            (
                Join-Path `
                    $programsFolder `
                    'Phoenix\Phoenix Control Center.lnk'
            )
            (
                Join-Path `
                    $programsFolder `
                    'Phoenix\Phoenix Theme Studio.lnk'
            )
            (
                Join-Path `
                    $programsFolder `
                    'Phoenix\Uninstall Phoenix.lnk'
            )
        )
    }

    $installationMetadata = [ordered]@{
        Product           = 'Phoenix'
        Version           = [string]$release.Version
        Scope             = $Scope
        InstallPath       = $resolvedInstallPath
        InstalledAtUtc    = (Get-Date).ToUniversalTime().ToString('o')
        LicenseExpression = [string]$release.LicenseExpression
        UserDataPaths     = @($preservePaths)
        Shortcuts         = @($shortcutPaths)
    }

    $installationMetadata |
        ConvertTo-Json `
            -Depth 10 |
        Set-Content `
            -LiteralPath (
                Join-Path `
                    $stagingPath `
                    '.phoenix-install.json'
            ) `
            -Encoding UTF8 `
            -ErrorAction Stop

    if (Test-Path -LiteralPath $resolvedInstallPath) {
        Move-Item `
            -LiteralPath $resolvedInstallPath `
            -Destination $backupPath `
            -ErrorAction Stop
    }

    try {
        Move-Item `
            -LiteralPath $stagingPath `
            -Destination $resolvedInstallPath `
            -ErrorAction Stop
    }
    catch {
        if (
            -not (Test-Path -LiteralPath $resolvedInstallPath) -and
            (Test-Path -LiteralPath $backupPath)
        ) {
            Move-Item `
                -LiteralPath $backupPath `
                -Destination $resolvedInstallPath `
                -ErrorAction SilentlyContinue
        }

        throw
    }

    if (-not $NoShortcuts) {
        New-PhoenixShortcut `
            -ShortcutPath $shortcutPaths[0] `
            -TargetPath (
                Join-Path `
                    $resolvedInstallPath `
                    'Phoenix.cmd'
            ) `
            -WorkingDirectory $resolvedInstallPath

        New-PhoenixShortcut `
            -ShortcutPath $shortcutPaths[1] `
            -TargetPath (
                Join-Path `
                    $resolvedInstallPath `
                    'Phoenix.cmd'
            ) `
            -WorkingDirectory $resolvedInstallPath

        New-PhoenixShortcut `
            -ShortcutPath $shortcutPaths[2] `
            -TargetPath (
                Join-Path `
                    $resolvedInstallPath `
                    'Phoenix-Theme-Studio.cmd'
            ) `
            -WorkingDirectory $resolvedInstallPath `
            -Description 'Phoenix Theme Studio'

        [string]$powerShellPath =
            (Get-Process -Id $PID).Path

        New-PhoenixShortcut `
            -ShortcutPath $shortcutPaths[3] `
            -TargetPath $powerShellPath `
            -WorkingDirectory $resolvedInstallPath `
            -Description 'Uninstall Phoenix'

        $shell =
            New-Object `
                -ComObject WScript.Shell

        $uninstallShortcut =
            $shell.CreateShortcut(
                $shortcutPaths[3]
            )

        $uninstallShortcut.Arguments = (
            '-NoLogo -NoProfile -ExecutionPolicy Bypass ' +
            "-File `"$resolvedInstallPath\Uninstall-Phoenix.ps1`""
        )

        $uninstallShortcut.Save()
    }

    [string]$uninstallRegistryPath = if ($Scope -eq 'AllUsers') {
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Phoenix'
    }
    else {
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Phoenix'
    }

    New-Item `
        -Path $uninstallRegistryPath `
        -Force |
        Out-Null

    [string]$uninstallCommand = (
        '"{0}" -NoLogo -NoProfile -ExecutionPolicy Bypass ' +
        '-File "{1}"'
    ) -f
        (Get-Process -Id $PID).Path,
        (
            Join-Path `
                $resolvedInstallPath `
                'Uninstall-Phoenix.ps1'
        )

    $uninstallValues = [ordered]@{
        DisplayName          = 'Phoenix'
        DisplayVersion       = [string]$release.Version
        DisplayIcon          = (
            Join-Path `
                $resolvedInstallPath `
                'Phoenix.cmd'
        )
        Publisher            = 'Donaven Guardipee'
        InstallLocation      = $resolvedInstallPath
        UninstallString      = $uninstallCommand
        QuietUninstallString = (
            "$uninstallCommand -Confirm:`$false"
        )
        NoModify             = 1
        NoRepair             = 1
    }

    foreach ($entry in $uninstallValues.GetEnumerator()) {
        [string]$propertyType =
            if ($entry.Value -is [int]) {
                'DWord'
            }
            else {
                'String'
            }

        New-ItemProperty `
            -LiteralPath $uninstallRegistryPath `
            -Name $entry.Key `
            -Value $entry.Value `
            -PropertyType $propertyType `
            -Force |
            Out-Null
    }

    if (Test-Path -LiteralPath $backupPath) {
        Remove-Item `
            -LiteralPath $backupPath `
            -Recurse `
            -Force `
            -ErrorAction Stop
    }
}
catch {
    if (
        -not (Test-Path -LiteralPath $resolvedInstallPath) -and
        (Test-Path -LiteralPath $backupPath)
    ) {
        Move-Item `
            -LiteralPath $backupPath `
            -Destination $resolvedInstallPath `
            -ErrorAction SilentlyContinue
    }

    throw
}
finally {
    foreach (
        $temporaryPath in @(
            $stagingPath
            $preservationPath
        )
    ) {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item `
                -LiteralPath $temporaryPath `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }
}

if ($Launch) {
    Start-Process `
        -FilePath (
            Join-Path `
                $resolvedInstallPath `
                'Phoenix.cmd'
        ) `
        -WorkingDirectory $resolvedInstallPath
}

return [pscustomobject]@{
    Success           = $true
    Applied           = $true
    Upgraded          = $upgraded
    Version           = [string]$release.Version
    Scope             = $Scope
    InstallPath       = $resolvedInstallPath
    LicenseExpression = [string]$release.LicenseExpression
    ShortcutCount     = $shortcutPaths.Count
    Launched          = [bool]$Launch
}
