[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ArchivePath,

    [Parameter()]
    [AllowEmptyString()]
    [string]$ChecksumPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

[string]$resolvedArchivePath = (
    Resolve-Path -LiteralPath $ArchivePath -ErrorAction Stop
).Path

if ([string]::IsNullOrWhiteSpace($ChecksumPath)) {
    $ChecksumPath = "$resolvedArchivePath.sha256"
}

[string]$resolvedChecksumPath = (
    Resolve-Path -LiteralPath $ChecksumPath -ErrorAction Stop
).Path

[string]$checksumText = (
    Get-Content -LiteralPath $resolvedChecksumPath -Raw
).Trim()

if ($checksumText -notmatch '^(?<Hash>[0-9a-fA-F]{64})\s+\*?.+$') {
    throw "The checksum file is not in SHA256 format: $resolvedChecksumPath"
}

[string]$expectedArchiveHash = $Matches.Hash.ToLowerInvariant()
[string]$actualArchiveHash = (
    Get-FileHash -LiteralPath $resolvedArchivePath -Algorithm SHA256
).Hash.ToLowerInvariant()

if ($actualArchiveHash -ne $expectedArchiveHash) {
    throw (
        "Archive checksum mismatch. Expected $expectedArchiveHash; " +
        "found $actualArchiveHash."
    )
}

[string]$verificationRoot = Join-Path (
    [IO.Path]::GetTempPath()
) ('PhoenixReleaseVerification-' + [guid]::NewGuid().ToString('N'))

try {
    New-Item -ItemType Directory -Path $verificationRoot -Force |
        Out-Null

    Expand-Archive `
        -LiteralPath $resolvedArchivePath `
        -DestinationPath $verificationRoot `
        -Force

    $releaseManifests = @(
        Get-ChildItem `
            -LiteralPath $verificationRoot `
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

    [string]$releaseRoot = $releaseManifests[0].Directory.FullName
    $release =
        Get-Content `
            -LiteralPath $releaseManifests[0].FullName `
            -Raw |
        ConvertFrom-Json

    if ([string]$release.Product -ne 'Phoenix') {
        throw 'The release manifest product is not Phoenix.'
    }

    [string]$releaseRootPrefix =
        $releaseRoot.TrimEnd(
            [IO.Path]::DirectorySeparatorChar,
            [IO.Path]::AltDirectorySeparatorChar
        ) + [IO.Path]::DirectorySeparatorChar

    [int]$verifiedFileCount = 0

    foreach ($file in @($release.Files)) {
        [string]$relativePath =
            ([string]$file.Path).Replace(
                '/',
                [IO.Path]::DirectorySeparatorChar
            )

        [string]$candidatePath = [IO.Path]::GetFullPath(
            (Join-Path $releaseRoot $relativePath)
        )

        if (-not $candidatePath.StartsWith(
            $releaseRootPrefix,
            [StringComparison]::OrdinalIgnoreCase
        )) {
            throw "Release manifest path escapes the archive root: $relativePath"
        }

        if (-not (Test-Path -LiteralPath $candidatePath -PathType Leaf)) {
            throw "Release manifest file is missing: $relativePath"
        }

        $candidate = Get-Item -LiteralPath $candidatePath

        if ([long]$candidate.Length -ne [long]$file.Bytes) {
            throw "Release file length mismatch: $relativePath"
        }

        [string]$candidateHash = (
            Get-FileHash -LiteralPath $candidatePath -Algorithm SHA256
        ).Hash.ToLowerInvariant()

        if ($candidateHash -ne ([string]$file.SHA256).ToLowerInvariant()) {
            throw "Release file checksum mismatch: $relativePath"
        }

        $verifiedFileCount++
    }

    if ($verifiedFileCount -ne [int]$release.RuntimeFileCount) {
        throw (
            'Runtime file count mismatch. Manifest declares {0}; verified {1}.' -f
            $release.RuntimeFileCount,
            $verifiedFileCount
        )
    }

    $moduleManifestEntry = @(
        $release.Files |
            Where-Object {
                ([string]$_.Path).Replace('\', '/') -match
                    '(^|/)Phoenix\.psd1$'
            }
    )

    if ($moduleManifestEntry.Count -ne 1) {
        throw (
            'The release manifest must identify exactly one Phoenix.psd1; ' +
            "found $($moduleManifestEntry.Count)."
        )
    }

    [string]$moduleManifest = Join-Path $releaseRoot (
        ([string]$moduleManifestEntry[0].Path).Replace(
            '/',
            [IO.Path]::DirectorySeparatorChar
        )
    )

    $moduleData =
        Import-PowerShellDataFile `
            -LiteralPath $moduleManifest

    if ([string]$moduleData.ModuleVersion -ne [string]$release.Version) {
        throw (
            'Packaged module version does not match RELEASE.json: {0} != {1}' -f
            $moduleData.ModuleVersion,
            $release.Version
        )
    }

    [string]$powerShellPath = (Get-Process -Id $PID).Path
    $importOutput = @(
        & $powerShellPath `
            -NoLogo `
            -NoProfile `
            -NonInteractive `
            -Command (
                '& { param([string]$Path) ' +
                'Import-Module -Name $Path -Force -ErrorAction Stop; ' +
                '(Get-Module -Name Phoenix).Version.ToString() }'
            ) `
            $moduleManifest `
            2>&1
    )

    if ($LASTEXITCODE -ne 0) {
        throw (
            'The packaged module failed independent import validation: {0}' -f
            ($importOutput -join [Environment]::NewLine)
        )
    }

    return [pscustomobject][ordered]@{
        Success           = $true
        Version           = [string]$release.Version
        ArchivePath       = $resolvedArchivePath
        SHA256            = $actualArchiveHash
        RuntimeFileCount  = $verifiedFileCount
        ModuleImport      = 'Passed'
        DirtyWorkingTree  = [bool]$release.DirtyWorkingTree
        GitCommit         = [string]$release.GitCommit
    }
}
finally {
    if (Test-Path -LiteralPath $verificationRoot) {
        Remove-Item `
            -LiteralPath $verificationRoot `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }
}
