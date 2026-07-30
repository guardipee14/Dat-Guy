[CmdletBinding(
    SupportsShouldProcess = $true,
    ConfirmImpact = 'High'
)]
param(
    [Parameter()]
    [string]$InstallPath = $PSScriptRoot,

    [Parameter()]
    [switch]$RemoveUserData
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-PhoenixUninstallerAdministrator {

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

function Copy-PhoenixUninstallerItem {

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

if (-not $IsWindows) {
    throw 'Phoenix can only be uninstalled on Windows.'
}

[string]$resolvedInstallPath =
    [IO.Path]::GetFullPath(
        $InstallPath
    )

[string]$metadataPath =
    Join-Path `
        $resolvedInstallPath `
        '.phoenix-install.json'

if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
    throw (
        "Phoenix installation metadata was not found under " +
        "'$resolvedInstallPath'."
    )
}

$metadata =
    Get-Content `
        -LiteralPath $metadataPath `
        -Raw `
        -ErrorAction Stop |
        ConvertFrom-Json `
            -ErrorAction Stop

if (
    [string]$metadata.Scope -eq 'AllUsers' -and
    -not (Test-PhoenixUninstallerAdministrator)
) {
    throw (
        'Uninstalling an AllUsers Phoenix installation requires an ' +
        'Administrator PowerShell window.'
    )
}

[string]$operation = if ($RemoveUserData) {
    'Uninstall Phoenix and remove configuration and installed themes'
}
else {
    'Uninstall Phoenix and preserve configuration and installed themes'
}

if (
    -not $PSCmdlet.ShouldProcess(
        $resolvedInstallPath,
        $operation
    )
) {
    return [pscustomobject]@{
        Success           = $true
        Applied           = $false
        InstallPath       = $resolvedInstallPath
        UserDataPreserved = -not [bool]$RemoveUserData
    }
}

foreach ($shortcutPath in @($metadata.Shortcuts)) {
    if (
        -not [string]::IsNullOrWhiteSpace(
            [string]$shortcutPath
        ) -and
        (Test-Path -LiteralPath $shortcutPath)
    ) {
        Remove-Item `
            -LiteralPath $shortcutPath `
            -Force `
            -ErrorAction SilentlyContinue
    }
}

$programFolderCandidates = @(
    [Environment]::GetFolderPath('Programs')
    [Environment]::GetFolderPath('CommonPrograms')
) |
    Where-Object {
        -not [string]::IsNullOrWhiteSpace($_)
    } |
    ForEach-Object {
        Join-Path `
            $_ `
            'Phoenix'
    }

foreach ($programFolder in $programFolderCandidates) {
    if (
        (Test-Path -LiteralPath $programFolder) -and
        @(
            Get-ChildItem `
                -LiteralPath $programFolder `
                -Force `
                -ErrorAction SilentlyContinue
        ).Count -eq 0
    ) {
        Remove-Item `
            -LiteralPath $programFolder `
            -Force `
            -ErrorAction SilentlyContinue
    }
}

[string]$uninstallRegistryPath = if (
    [string]$metadata.Scope -eq 'AllUsers'
) {
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Phoenix'
}
else {
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Phoenix'
}

if (Test-Path -LiteralPath $uninstallRegistryPath) {
    Remove-Item `
        -LiteralPath $uninstallRegistryPath `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue
}

[string]$preservationPath =
    Join-Path `
        ([IO.Path]::GetTempPath()) `
        (
            'PhoenixUninstall-{0}' -f
            [guid]::NewGuid().ToString('N')
        )

$preservePaths = if (
    $null -ne $metadata.PSObject.Properties[
        'UserDataPaths'
    ]
) {
    @(
        $metadata.UserDataPaths |
            ForEach-Object {
                [string]$_
            }
    )
}
else {
    @(
        'Config\Phoenix.json'
        'Config\Phoenix.UI.json'
        'Config\Settings.json'
        'Themes\Installed'
    )
}

[bool]$preservedAnything = $false

try {
    if (-not $RemoveUserData) {
        foreach ($relativePath in $preservePaths) {
            [string]$sourcePath =
                Join-Path `
                    $resolvedInstallPath `
                    $relativePath

            if (-not (Test-Path -LiteralPath $sourcePath)) {
                continue
            }

            [string]$preservedPath =
                Join-Path `
                    $preservationPath `
                    $relativePath

            Copy-PhoenixUninstallerItem `
                -Source $sourcePath `
                -Destination $preservedPath

            $preservedAnything = $true
        }
    }

    Set-Location `
        -LiteralPath (
            [IO.Path]::GetTempPath()
        )

    Remove-Item `
        -LiteralPath $resolvedInstallPath `
        -Recurse `
        -Force `
        -ErrorAction Stop

    if ($preservedAnything) {
        New-Item `
            -ItemType Directory `
            -Path $resolvedInstallPath `
            -Force |
            Out-Null

        foreach ($relativePath in $preservePaths) {
            [string]$preservedPath =
                Join-Path `
                    $preservationPath `
                    $relativePath

            if (-not (Test-Path -LiteralPath $preservedPath)) {
                continue
            }

            [string]$destinationPath =
                Join-Path `
                    $resolvedInstallPath `
                    $relativePath

            Copy-PhoenixUninstallerItem `
                -Source $preservedPath `
                -Destination $destinationPath
        }

        [ordered]@{
            Product        = 'Phoenix'
            State          = 'UninstalledUserDataPreserved'
            PreviousVersion = [string]$metadata.Version
            Scope          = [string]$metadata.Scope
            UninstalledAtUtc = (
                Get-Date
            ).ToUniversalTime().ToString('o')
        } |
            ConvertTo-Json `
                -Depth 5 |
            Set-Content `
                -LiteralPath (
                    Join-Path `
                        $resolvedInstallPath `
                        '.phoenix-user-data.json'
                ) `
                -Encoding UTF8
    }
}
finally {
    if (Test-Path -LiteralPath $preservationPath) {
        Remove-Item `
            -LiteralPath $preservationPath `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }
}

return [pscustomobject]@{
    Success           = $true
    Applied           = $true
    Version           = [string]$metadata.Version
    Scope             = [string]$metadata.Scope
    InstallPath       = $resolvedInstallPath
    UserDataPreserved = $preservedAnything
    RemovedUserData   = [bool]$RemoveUserData
}
