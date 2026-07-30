[CmdletBinding(
    SupportsShouldProcess = $true,
    ConfirmImpact = 'Medium'
)]
param(
    [Parameter()]
    [ValidatePattern(
        '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$'
    )]
    [string]$Version,

    [Parameter()]
    [string]$OutputPath,

    [Parameter()]
    [switch]$SkipValidation,

    [Parameter()]
    [switch]$AllowDirty,

    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [switch]$PublishGitHub,

    [Parameter()]
    [switch]$Prerelease,

    [Parameter()]
    [string]$Repository = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-PhoenixReleaseExcludedFile {

    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string[]]$Pattern
    )

    foreach ($excludedPattern in $Pattern) {
        if ($Name -like $excludedPattern) {
            return $true
        }
    }

    return $false
}

function Copy-PhoenixReleasePath {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot,

        [Parameter(Mandatory)]
        [string]$RelativePath,

        [Parameter(Mandatory)]
        [string]$PayloadRoot,

        [Parameter(Mandatory)]
        [string[]]$ExcludedPattern
    )

    [string]$sourcePath =
        Join-Path `
            $ProjectRoot `
            $RelativePath

    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Required runtime path was not found: $sourcePath"
    }

    if (Test-Path -LiteralPath $sourcePath -PathType Leaf) {
        if (
            Test-PhoenixReleaseExcludedFile `
                -Name (
                    Split-Path `
                        -Path $sourcePath `
                        -Leaf
                ) `
                -Pattern $ExcludedPattern
        ) {
            return
        }

        [string]$destinationPath =
            Join-Path `
                $PayloadRoot `
                $RelativePath

        New-Item `
            -ItemType Directory `
            -Path (
                Split-Path `
                    -Path $destinationPath `
                    -Parent
            ) `
            -Force |
            Out-Null

        Copy-Item `
            -LiteralPath $sourcePath `
            -Destination $destinationPath `
            -Force `
            -ErrorAction Stop

        return
    }

    foreach (
        $sourceFile in @(
            Get-ChildItem `
                -LiteralPath $sourcePath `
                -File `
                -Recurse `
                -Force
        )
    ) {
        if (
            Test-PhoenixReleaseExcludedFile `
                -Name $sourceFile.Name `
                -Pattern $ExcludedPattern
        ) {
            continue
        }

        [string]$sourceRelativePath =
            $sourceFile.FullName.Substring(
                $ProjectRoot.Length
            ).TrimStart(
                [IO.Path]::DirectorySeparatorChar,
                [IO.Path]::AltDirectorySeparatorChar
            )

        [string]$destinationPath =
            Join-Path `
                $PayloadRoot `
                $sourceRelativePath

        New-Item `
            -ItemType Directory `
            -Path (
                Split-Path `
                    -Path $destinationPath `
                    -Parent
            ) `
            -Force |
            Out-Null

        Copy-Item `
            -LiteralPath $sourceFile.FullName `
            -Destination $destinationPath `
            -Force `
            -ErrorAction Stop
    }
}

function Get-PhoenixReleaseGitValue {

    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot,

        [Parameter(Mandatory)]
        [string[]]$Argument
    )

    $gitCommand =
        Get-Command `
            -Name git `
            -ErrorAction SilentlyContinue

    if ($null -eq $gitCommand) {
        return ''
    }

    $output = @(
        & $gitCommand.Source `
            -C $ProjectRoot `
            @Argument `
            2>$null
    )

    if ($LASTEXITCODE -ne 0) {
        return ''
    }

    return (
        $output -join
            [Environment]::NewLine
    ).Trim()
}

[string]$projectRoot =
    [IO.Path]::GetFullPath(
        (
            Join-Path `
                $PSScriptRoot `
                '..'
        )
    )

[string]$moduleManifestPath =
    Join-Path `
        $projectRoot `
        'Phoenix.psd1'

[string]$releaseConfigurationPath =
    Join-Path `
        $PSScriptRoot `
        'Phoenix.Release.psd1'

foreach (
    $requiredPath in @(
        $moduleManifestPath
        $releaseConfigurationPath
        (
            Join-Path `
                $projectRoot `
                'Distribution\Install-Phoenix.ps1'
        )
        (
            Join-Path `
                $projectRoot `
                'Distribution\Uninstall-Phoenix.ps1'
        )
    )
) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required Phoenix release file was not found: $requiredPath"
    }
}

$moduleManifest =
    Import-PowerShellDataFile `
        -LiteralPath $moduleManifestPath

$releaseConfiguration =
    Import-PowerShellDataFile `
        -LiteralPath $releaseConfigurationPath

[string]$resolvedVersion = if (
    [string]::IsNullOrWhiteSpace($Version)
) {
    $moduleManifest.ModuleVersion.ToString()
}
else {
    $Version
}

if (
    $resolvedVersion -notmatch
        '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$'
) {
    throw (
        "Release version '$resolvedVersion' is not a three-part " +
        'semantic version.'
    )
}

[string]$resolvedOutputPath = if (
    [string]::IsNullOrWhiteSpace($OutputPath)
) {
    Join-Path `
        $projectRoot `
        'Artifacts\Releases'
}
elseif ([IO.Path]::IsPathRooted($OutputPath)) {
    [IO.Path]::GetFullPath($OutputPath)
}
else {
    [IO.Path]::GetFullPath(
        (
            Join-Path `
                $projectRoot `
                $OutputPath
        )
    )
}

[string]$gitStatus =
    Get-PhoenixReleaseGitValue `
        -ProjectRoot $projectRoot `
        -Argument @(
            'status'
            '--short'
        )

[bool]$workingTreeDirty =
    -not [string]::IsNullOrWhiteSpace($gitStatus)

if ($workingTreeDirty -and -not $AllowDirty) {
    throw (
        'Phoenix releases require a clean Git working tree. ' +
        'Commit the current work or use -AllowDirty for local testing.'
    )
}

if ($PublishGitHub -and $workingTreeDirty) {
    throw 'GitHub releases cannot be published from a dirty working tree.'
}

if (-not $SkipValidation) {
    [string]$buildScript =
        Join-Path `
            $projectRoot `
            'Build.ps1'

    $buildResult =
        & $buildScript

    if (
        $null -eq $buildResult -or
        -not [bool]$buildResult.Success
    ) {
        throw 'Phoenix validation did not complete successfully.'
    }
}

[string]$releaseName =
    "Phoenix-$resolvedVersion"

[string]$archivePath =
    Join-Path `
        $resolvedOutputPath `
        "$releaseName.zip"

[string]$checksumPath =
    "$archivePath.sha256"

foreach (
    $existingOutput in @(
        $archivePath
        $checksumPath
    )
) {
    if (
        (Test-Path -LiteralPath $existingOutput) -and
        -not $Force
    ) {
        throw (
            "Release output already exists: $existingOutput. " +
            'Use -Force to replace it.'
        )
    }
}

if (
    -not $PSCmdlet.ShouldProcess(
        $archivePath,
        "Build Phoenix $resolvedVersion release"
    )
) {
    return [pscustomobject]@{
        Success      = $true
        Created      = $false
        Version      = $resolvedVersion
        ArchivePath  = $archivePath
        ChecksumPath = $checksumPath
        Published    = $false
    }
}

New-Item `
    -ItemType Directory `
    -Path $resolvedOutputPath `
    -Force |
    Out-Null

[string]$stagingParent =
    Join-Path `
        ([IO.Path]::GetTempPath()) `
        (
            'PhoenixRelease-{0}' -f
            [guid]::NewGuid().ToString('N')
        )

[string]$releaseRoot =
    Join-Path `
        $stagingParent `
        $releaseName

[string]$payloadRoot =
    Join-Path `
        $releaseRoot `
        'Payload'

try {
    New-Item `
        -ItemType Directory `
        -Path $payloadRoot `
        -Force |
        Out-Null

    foreach (
        $runtimePath in @(
            $releaseConfiguration.RuntimePaths
        )
    ) {
        Copy-PhoenixReleasePath `
            -ProjectRoot $projectRoot `
            -RelativePath ([string]$runtimePath) `
            -PayloadRoot $payloadRoot `
            -ExcludedPattern @(
                $releaseConfiguration.ExcludedFilePatterns
            )
    }

    foreach (
        $distributionFile in @(
            'Install-Phoenix.cmd'
            'Install-Phoenix.ps1'
            'Uninstall-Phoenix.ps1'
        )
    ) {
        Copy-Item `
            -LiteralPath (
                Join-Path `
                    $projectRoot `
                    "Distribution\$distributionFile"
            ) `
            -Destination (
                Join-Path `
                    $releaseRoot `
                    $distributionFile
            ) `
            -Force `
            -ErrorAction Stop
    }

    [string]$stagedModuleManifestPath =
        Join-Path `
            $payloadRoot `
            'Phoenix.psd1'

    [string]$stagedManifestContent =
        Get-Content `
            -LiteralPath $stagedModuleManifestPath `
            -Raw

    $versionPattern =
        [regex]::new(
            "(?m)^ModuleVersion\s*=\s*'[^']+'"
        )

    $stagedManifestContent =
        $versionPattern.Replace(
            $stagedManifestContent,
            "ModuleVersion = '$resolvedVersion'",
            1
        )

    Set-Content `
        -LiteralPath $stagedModuleManifestPath `
        -Value $stagedManifestContent `
        -Encoding UTF8

    [string]$stagedSettingsPath =
        Join-Path `
            $payloadRoot `
            'Config\Settings.json'

    if (Test-Path -LiteralPath $stagedSettingsPath) {
        $settings =
            Get-Content `
                -LiteralPath $stagedSettingsPath `
                -Raw |
                ConvertFrom-Json

        $settings.Version = $resolvedVersion

        $settings |
            ConvertTo-Json `
                -Depth 20 |
            Set-Content `
                -LiteralPath $stagedSettingsPath `
                -Encoding UTF8
    }

    Test-ModuleManifest `
        -Path $stagedModuleManifestPath `
        -ErrorAction Stop |
        Out-Null

    [string]$powerShellPath =
        (Get-Process -Id $PID).Path

    [string]$validationScriptPath =
        Join-Path `
            $stagingParent `
            'Test-PhoenixReleaseImport.ps1'

    @'
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ManifestPath
)

$ErrorActionPreference = 'Stop'
Import-Module -Name $ManifestPath -Force -ErrorAction Stop 6>$null

if ($null -eq (Get-Module -Name Phoenix)) {
    throw 'Phoenix release module was not imported.'
}
'@ |
        Set-Content `
            -LiteralPath $validationScriptPath `
            -Encoding UTF8

    $validationOutput = @(
        & $powerShellPath `
            -NoLogo `
            -NoProfile `
            -NonInteractive `
            -File $validationScriptPath `
            -ManifestPath $stagedModuleManifestPath `
            2>&1
    )

    if ($LASTEXITCODE -ne 0) {
        throw (
            "Packaged module import validation failed.`n{0}" -f
            (
                $validationOutput -join
                    [Environment]::NewLine
            )
        )
    }

    [string]$gitBranch =
        Get-PhoenixReleaseGitValue `
            -ProjectRoot $projectRoot `
            -Argument @(
                'branch'
                '--show-current'
            )

    [string]$gitCommit =
        Get-PhoenixReleaseGitValue `
            -ProjectRoot $projectRoot `
            -Argument @(
                'rev-parse'
                'HEAD'
            )

    $releaseFiles = @(
        Get-ChildItem `
            -LiteralPath $releaseRoot `
            -File `
            -Recurse |
            Sort-Object FullName |
            ForEach-Object {
                [string]$relativePath =
                    $_.FullName.Substring(
                        $releaseRoot.Length
                    ).TrimStart(
                        [IO.Path]::DirectorySeparatorChar,
                        [IO.Path]::AltDirectorySeparatorChar
                    )

                [ordered]@{
                    Path   = $relativePath.Replace('\', '/')
                    Bytes  = $_.Length
                    SHA256 = (
                        Get-FileHash `
                            -LiteralPath $_.FullName `
                            -Algorithm SHA256
                    ).Hash.ToLowerInvariant()
                }
            }
    )

    $releaseManifest = [ordered]@{
        SchemaVersion        = '1.0'
        Product              = 'Phoenix'
        Version              = $resolvedVersion
        CreatedAtUtc         = (
            Get-Date
        ).ToUniversalTime().ToString('o')
        MinimumPowerShell    = [string]$releaseConfiguration.MinimumPowerShellVersion
        MinimumWindowsBuild  = [int]$releaseConfiguration.MinimumWindowsBuild
        LicenseExpression    = [string]$releaseConfiguration.LicenseExpression
        PreserveOnUpgrade    = @(
            $releaseConfiguration.PreserveOnUpgrade
        )
        GitBranch            = $gitBranch
        GitCommit            = $gitCommit
        DirtyWorkingTree     = $workingTreeDirty
        RuntimeFileCount     = $releaseFiles.Count
        Files                = $releaseFiles
    }

    $releaseManifest |
        ConvertTo-Json `
            -Depth 20 |
        Set-Content `
            -LiteralPath (
                Join-Path `
                    $releaseRoot `
                    'RELEASE.json'
            ) `
            -Encoding UTF8

    foreach (
        $existingOutput in @(
            $archivePath
            $checksumPath
        )
    ) {
        if (Test-Path -LiteralPath $existingOutput) {
            Remove-Item `
                -LiteralPath $existingOutput `
                -Force `
                -ErrorAction Stop
        }
    }

    Compress-Archive `
        -Path $releaseRoot `
        -DestinationPath $archivePath `
        -CompressionLevel Optimal `
        -Force

    $archiveHash =
        Get-FileHash `
            -LiteralPath $archivePath `
            -Algorithm SHA256

    (
        '{0} *{1}' -f
        $archiveHash.Hash.ToLowerInvariant(),
        (
            Split-Path `
                -Path $archivePath `
                -Leaf
        )
    ) |
        Set-Content `
            -LiteralPath $checksumPath `
            -Encoding ascii

    [bool]$published = $false

    if ($PublishGitHub) {
        $ghCommand =
            Get-Command `
                -Name gh `
                -ErrorAction SilentlyContinue

        if ($null -eq $ghCommand) {
            throw (
                'GitHub CLI was not found. Install gh and authenticate ' +
                'before using -PublishGitHub.'
            )
        }

        if (
            $PSCmdlet.ShouldProcess(
                "v$resolvedVersion",
                'Create GitHub release and upload Phoenix artifacts'
            )
        ) {
            $releaseArguments = @(
                'release'
                'create'
                "v$resolvedVersion"
                $archivePath
                $checksumPath
                '--title'
                "Phoenix $resolvedVersion"
                '--generate-notes'
            )

            if ($Prerelease) {
                $releaseArguments += '--prerelease'
            }

            if (-not [string]::IsNullOrWhiteSpace($Repository)) {
                $releaseArguments += @(
                    '--repo'
                    $Repository
                )
            }

            $publishOutput = @(
                & $ghCommand.Source `
                    @releaseArguments `
                    2>&1
            )

            if ($LASTEXITCODE -ne 0) {
                throw (
                    "GitHub release creation failed.`n{0}" -f
                    (
                        $publishOutput -join
                            [Environment]::NewLine
                    )
                )
            }

            $published = $true
        }
    }

    return [pscustomobject]@{
        Success           = $true
        Created           = $true
        Version           = $resolvedVersion
        ArchivePath       = $archivePath
        ChecksumPath      = $checksumPath
        SHA256            = $archiveHash.Hash.ToLowerInvariant()
        ArchiveBytes      = (
            Get-Item `
                -LiteralPath $archivePath
        ).Length
        RuntimeFileCount  = $releaseFiles.Count
        LicenseExpression = [string]$releaseConfiguration.LicenseExpression
        GitBranch         = $gitBranch
        GitCommit         = $gitCommit
        DirtyWorkingTree  = $workingTreeDirty
        Published         = $published
    }
}
finally {
    if (Test-Path -LiteralPath $stagingParent) {
        Remove-Item `
            -LiteralPath $stagingParent `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }
}
