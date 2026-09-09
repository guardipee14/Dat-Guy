function Get-PhoenixWinPEWorkspaceOwnedInfo {

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    [IO.DirectoryInfo]$root =
        Get-Item -LiteralPath $Path -Force -ErrorAction Stop

    if ($root -isnot [IO.DirectoryInfo] -or ($root.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "WinPE workspace root must be a regular directory: $Path"
    }

    [string]$markerPath = Join-Path $root.FullName '.phoenix-winpe-workspace'
    [string]$metadataPath = Join-Path $root.FullName 'workspace.json'

    if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
        throw "The directory is not marked as a Phoenix WinPE workspace: $($root.FullName)"
    }

    try {
        $marker = Get-Content -LiteralPath $markerPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $rawWorkspace = Get-Content -LiteralPath $metadataPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Phoenix WinPE workspace metadata is invalid: $($_.Exception.Message)"
    }

    if (
        [string]$marker.Schema -cne 'PhoenixWinPEWorkspaceOwnership' -or
        [string]$marker.WorkspaceId -cne [string]$rawWorkspace.WorkspaceId
    ) {
        throw 'WinPE workspace ownership and metadata identities do not match.'
    }

    $workspace = New-Object -TypeName PhoenixWinPEWorkspace
    foreach ($name in @(
        'Schema', 'SchemaVersion', 'WorkspaceId', 'RootPath', 'Architecture',
        'SourceWimPath', 'SourceWimSha256', 'MediaSourcePath', 'MediaPath',
        'MountPath', 'State', 'CreatedAtUtc', 'UpdatedAtUtc'
    )) {
        $workspace.$name = $rawWorkspace.$name
    }

    if (-not $workspace.IsValid()) {
        throw 'Phoenix WinPE workspace metadata failed contract validation.'
    }

    if (-not [string]::Equals($workspace.RootPath, $root.FullName, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Phoenix WinPE workspace metadata does not identify its current root.'
    }

    return [pscustomobject]@{
        RootPath = $root.FullName
        MarkerPath = $markerPath
        MetadataPath = $metadataPath
        Workspace = $workspace
    }
}

function Save-PhoenixWinPEWorkspaceMetadata {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PhoenixWinPEWorkspace]$Workspace
    )

    if (-not $Workspace.IsValid()) {
        throw 'A valid Phoenix WinPE workspace is required.'
    }

    [string]$metadataPath = Join-Path $Workspace.RootPath 'workspace.json'
    [string]$temporaryPath = "$metadataPath.$([guid]::NewGuid().ToString('N')).tmp"

    try {
        $Workspace | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $temporaryPath -Encoding utf8 -ErrorAction Stop
        Move-Item -LiteralPath $temporaryPath -Destination $metadataPath -Force -ErrorAction Stop
    }
    finally {
        Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
    }
}

function Test-PhoenixRegularDirectoryTree {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    [IO.DirectoryInfo]$root = Get-Item -LiteralPath $Path -Force -ErrorAction Stop

    if (
        $root -isnot [IO.DirectoryInfo] -or
        ($root.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
    ) {
        throw "Expected a regular directory: $Path"
    }

    foreach ($item in @(Get-ChildItem -LiteralPath $root.FullName -Force -Recurse -ErrorAction Stop)) {
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Directory trees containing reparse points are not accepted: $($item.FullName)"
        }
    }
}
