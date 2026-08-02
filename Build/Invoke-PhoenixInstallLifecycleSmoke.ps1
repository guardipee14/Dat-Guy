[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ArchivePath,

    [Parameter()]
    [AllowEmptyString()]
    [string]$ChecksumPath = '',

    [Parameter()]
    [ValidateRange(5, 120)]
    [int]$LaunchTimeoutSeconds = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $IsWindows) {
    throw 'The Phoenix installation lifecycle smoke test requires Windows.'
}

[string]$projectRoot = Split-Path -Parent $PSScriptRoot
[string]$verifierPath =
    Join-Path $PSScriptRoot 'Test-PhoenixReleaseArchive.ps1'

$verificationParameters = @{
    ArchivePath = $ArchivePath
}

if (-not [string]::IsNullOrWhiteSpace($ChecksumPath)) {
    $verificationParameters.ChecksumPath = $ChecksumPath
}

$archiveVerification = & $verifierPath @verificationParameters

[string]$lifecycleRoot = Join-Path (
    [IO.Path]::GetTempPath()
) ('PhoenixInstallLifecycle-' + [guid]::NewGuid().ToString('N'))

[string]$expandedRoot = Join-Path $lifecycleRoot 'Expanded'
[string]$installPath = Join-Path $lifecycleRoot 'Installed'
[object]$launchProcess = $null

try {
    New-Item -ItemType Directory -Path $expandedRoot -Force |
        Out-Null

    Expand-Archive `
        -LiteralPath $archiveVerification.ArchivePath `
        -DestinationPath $expandedRoot `
        -Force

    $releaseManifests = @(
        Get-ChildItem `
            -LiteralPath $expandedRoot `
            -Filter 'RELEASE.json' `
            -File `
            -Recurse
    )

    if ($releaseManifests.Count -ne 1) {
        throw (
            'The archive must contain exactly one RELEASE.json; found {0}.' -f
            $releaseManifests.Count
        )
    }

    $releaseManifest = $releaseManifests[0]

    [string]$releaseRoot = $releaseManifest.Directory.FullName
    [string]$installerPath =
        Join-Path $releaseRoot 'Install-Phoenix.ps1'

    $installResult =
        & $installerPath `
            -Scope CurrentUser `
            -InstallPath $installPath `
            -NoShortcuts `
            -Confirm:$false

    if (-not $installResult.Success -or $installResult.Upgraded) {
        throw 'The clean CurrentUser installation did not report success.'
    }

    [string]$themeDirectory =
        Join-Path $installPath 'Themes\Installed'

    New-Item -ItemType Directory -Path $themeDirectory -Force |
        Out-Null

    [string]$preservationMarker =
        Join-Path $themeDirectory 'v0.2.0-lifecycle.marker'

    Set-Content `
        -LiteralPath $preservationMarker `
        -Value 'Phoenix lifecycle preservation marker' `
        -Encoding UTF8

    $upgradeResult =
        & $installerPath `
            -Scope CurrentUser `
            -InstallPath $installPath `
            -NoShortcuts `
            -Confirm:$false

    if (-not $upgradeResult.Success -or -not $upgradeResult.Upgraded) {
        throw 'The in-place upgrade did not report success.'
    }

    if (-not (Test-Path -LiteralPath $preservationMarker -PathType Leaf)) {
        throw 'The in-place upgrade did not preserve installed user data.'
    }

    [string]$powerShellPath = (Get-Process -Id $PID).Path
    [string]$launcherPath =
        Join-Path $installPath 'Tools\Start-PhoenixControlCenter.ps1'

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $powerShellPath
    $startInfo.WorkingDirectory = $installPath
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $false

    foreach ($argument in @(
        '-NoLogo'
        '-NoProfile'
        '-ExecutionPolicy'
        'Bypass'
        '-STA'
        '-File'
        $launcherPath
        '-Mode'
        'Desktop'
        '-NoElevation'
        '-NoFallback'
    )) {
        $startInfo.ArgumentList.Add($argument)
    }

    $launchProcess =
        [System.Diagnostics.Process]::Start($startInfo)

    [datetime]$launchDeadline =
        [datetime]::UtcNow.AddSeconds($LaunchTimeoutSeconds)

    [bool]$responsive = $false

    while ([datetime]::UtcNow -lt $launchDeadline) {
        Start-Sleep -Milliseconds 250
        $launchProcess.Refresh()

        if ($launchProcess.HasExited) {
            throw (
                'The installed Control Center exited before its window ' +
                "became responsive. Exit code: $($launchProcess.ExitCode)."
            )
        }

        if (
            $launchProcess.MainWindowHandle -ne [IntPtr]::Zero -and
            $launchProcess.Responding
        ) {
            $responsive = $true
            break
        }
    }

    if (-not $responsive) {
        throw (
            'The installed Control Center did not expose a responsive ' +
            "window within $LaunchTimeoutSeconds seconds."
        )
    }

    $null = $launchProcess.CloseMainWindow()

    if (-not $launchProcess.WaitForExit(10000)) {
        $launchProcess.Kill($true)
        $null = $launchProcess.WaitForExit(5000)
    }

    $launchProcess = $null

    [string]$uninstallerPath =
        Join-Path $installPath 'Uninstall-Phoenix.ps1'

    $preservedUninstall =
        & $uninstallerPath `
            -InstallPath $installPath `
            -Confirm:$false

    if (
        -not $preservedUninstall.Success -or
        -not $preservedUninstall.UserDataPreserved -or
        -not (Test-Path -LiteralPath $preservationMarker -PathType Leaf)
    ) {
        throw 'The preserved-data uninstall contract failed.'
    }

    $reinstallResult =
        & $installerPath `
            -Scope CurrentUser `
            -InstallPath $installPath `
            -NoShortcuts `
            -Confirm:$false

    if (
        -not $reinstallResult.Success -or
        -not (Test-Path -LiteralPath $preservationMarker -PathType Leaf)
    ) {
        throw 'Reinstallation did not restore preserved user data.'
    }

    $completeUninstallerPath =
        Join-Path $installPath 'Uninstall-Phoenix.ps1'

    $completeUninstall =
        & $completeUninstallerPath `
            -InstallPath $installPath `
            -RemoveUserData `
            -Confirm:$false

    if (
        -not $completeUninstall.Success -or
        -not $completeUninstall.RemovedUserData -or
        (Test-Path -LiteralPath $installPath)
    ) {
        throw 'The complete-removal uninstall contract failed.'
    }

    return [pscustomobject][ordered]@{
        Success                 = $true
        Version                 = $archiveVerification.Version
        ArchiveSHA256           = $archiveVerification.SHA256
        Install                 = 'Passed'
        Upgrade                 = 'Passed'
        ResponsiveLaunch        = 'Passed'
        PreservedDataUninstall  = 'Passed'
        Reinstall               = 'Passed'
        CompleteRemoval         = 'Passed'
    }
}
finally {
    if ($null -ne $launchProcess) {
        try {
            $launchProcess.Refresh()

            if (-not $launchProcess.HasExited) {
                $launchProcess.Kill($true)
                $null = $launchProcess.WaitForExit(5000)
            }
        }
        catch {
            Write-Warning (
                'The lifecycle launch process could not be stopped: {0}' -f
                $_.Exception.Message
            )
        }
    }

    Set-Location -LiteralPath $projectRoot

    if (Test-Path -LiteralPath $lifecycleRoot) {
        Remove-Item `
            -LiteralPath $lifecycleRoot `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }
}
