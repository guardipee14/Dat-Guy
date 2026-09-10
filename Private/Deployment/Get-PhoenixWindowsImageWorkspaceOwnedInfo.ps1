function Save-PhoenixWindowsImageWorkspaceMetadata {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PhoenixWindowsImageWorkspace]$Workspace
    )

    if (-not $Workspace.IsValid()) {
        throw 'A valid Phoenix Windows-image workspace is required.'
    }

    [string]$metadataPath = Join-Path $Workspace.RootPath 'workspace.json'
    [string]$temporaryPath = "$metadataPath.$([guid]::NewGuid().ToString('N')).tmp"

    try {
        $Workspace | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $temporaryPath -Encoding utf8 -ErrorAction Stop
        Move-Item -LiteralPath $temporaryPath -Destination $metadataPath -Force -ErrorAction Stop
    }
    finally {
        Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
    }
}

function Get-PhoenixWindowsImageWorkspaceOwnedInfo {

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    Test-PhoenixPathAncestors -Path $Path
    $root = Get-Item -LiteralPath $Path -Force -ErrorAction Stop

    if ($root -isnot [IO.DirectoryInfo] -or ($root.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Windows-image workspace root must be a regular directory: $Path"
    }

    [string]$markerPath = Join-Path $root.FullName '.phoenix-windows-image-workspace'
    [string]$metadataPath = Join-Path $root.FullName 'workspace.json'
    Test-PhoenixPathAncestors -Path $markerPath
    Test-PhoenixPathAncestors -Path $metadataPath

    if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
        throw "The directory is not marked as a Phoenix Windows-image workspace: $($root.FullName)"
    }

    try {
        $marker = Get-Content -LiteralPath $markerPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $raw = Get-Content -LiteralPath $metadataPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Phoenix Windows-image workspace metadata is invalid: $($_.Exception.Message)"
    }

    if (
        [string]$marker.Schema -cne 'PhoenixWindowsImageWorkspaceOwnership' -or
        [string]$marker.SchemaVersion -cne '1.0' -or
        [string]$marker.WorkspaceId -cne [string]$raw.WorkspaceId
    ) {
        throw 'Windows-image workspace ownership and metadata identities do not match.'
    }

    $workspace = New-Object -TypeName PhoenixWindowsImageWorkspace

    foreach ($name in @(
        'Schema', 'SchemaVersion', 'WorkspaceId', 'RootPath', 'SourceImagePath',
        'SourceImageSha256', 'WorkingImagePath', 'WorkingImageSha256', 'SourceImageIndex', 'MountPath', 'ImageIndex',
        'State', 'ReadOnly', 'Operations', 'CreatedAtUtc', 'UpdatedAtUtc'
    )) {
        $workspace.$name = $raw.$name
    }

    if (-not $workspace.IsValid()) {
        throw 'Phoenix Windows-image workspace metadata failed contract validation.'
    }

    if (-not [string]::Equals($workspace.RootPath, $root.FullName, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Windows-image workspace metadata does not identify its current root.'
    }

    if ($workspace.WorkingImagePath -ine (Join-Path $root.FullName 'images\working.wim') -or
        $workspace.MountPath -ine (Join-Path $root.FullName 'mount')) {
        throw 'Workspace image and mount paths must be exact owned children.'
    }
    Test-PhoenixPathAncestors -Path $workspace.WorkingImagePath
    Test-PhoenixPathAncestors -Path $workspace.MountPath
    if (-not (Test-Path -LiteralPath $workspace.WorkingImagePath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $workspace.MountPath -PathType Container)) {
        throw 'Workspace image or mount directory is missing.'
    }

    return [pscustomobject]@{
        RootPath = $root.FullName
        MarkerPath = $markerPath
        MetadataPath = $metadataPath
        Workspace = $workspace
    }
}

function Invoke-PhoenixWindowsImageWorkspaceLock {

    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$WorkspacePath,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [scriptblock]$Action
    )

    [string]$lockPath = Join-Path $WorkspacePath '.phoenix-image.lock'
    Test-PhoenixPathAncestors -Path $lockPath
    $stream = $null

    try {
        try {
            $stream = [IO.File]::Open($lockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        }
        catch [IO.IOException] {
            throw 'Another Phoenix image operation currently owns this workspace.'
        }
        return & $Action
    }
    finally {
        if ($null -ne $stream) {
            $stream.Dispose()
        }

        # Keep the lock file: deleting it after release permits competing locks.
    }
}
