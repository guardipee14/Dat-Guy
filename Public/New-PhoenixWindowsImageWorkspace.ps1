using module '..\Classes\Phoenix.Classes.psm1'

function New-PhoenixWindowsImageWorkspace {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PhoenixWindowsImageWorkspace])]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$SourceImagePath,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path,
        [Parameter(Mandatory)][ValidateRange(1, 999)][int]$ImageIndex,
        [string]$DismPath = ''
    )
    Test-PhoenixPathAncestors -Path $SourceImagePath
    $sourceImage = Get-Item -LiteralPath $SourceImagePath -Force -ErrorAction Stop
    if ($sourceImage -isnot [IO.FileInfo] -or $sourceImage.Extension -notin @('.wim', '.esd')) {
        throw 'The source image must be a regular WIM or ESD file.'
    }
    $rootPath = [IO.Path]::GetFullPath($Path)
    Test-PhoenixPathAncestors -Path $rootPath
    if (Test-Path -LiteralPath $rootPath) { throw "Windows-image workspace destination already exists: $rootPath" }
    Assert-PhoenixWindowsImageMetadata -Path $sourceImage.FullName -Index $ImageIndex
    $workspace = [PhoenixWindowsImageWorkspace]::new()
    $workspace.RootPath = $rootPath
    $workspace.SourceImagePath = $sourceImage.FullName
    $workspace.SourceImageSha256 = (Get-FileHash -LiteralPath $sourceImage.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $workspace.WorkingImagePath = Join-Path $rootPath 'images\working.wim'
    $workspace.WorkingImageSha256 = $workspace.SourceImageSha256
    $workspace.MountPath = Join-Path $rootPath 'mount'
    $workspace.SourceImageIndex = $ImageIndex
    $workspace.ImageIndex = $ImageIndex
    $workspace.SetState('Staging')
    $exportEsd = $sourceImage.Extension -ieq '.esd'
    if ($exportEsd) {
        if (-not (Test-PhoenixAdministrator)) { throw 'Administrator privileges are required to export ESD images.' }
        $DismPath = Resolve-PhoenixDismPath -Path $DismPath
        $workspace.ImageIndex = 1
    }
    if (-not $PSCmdlet.ShouldProcess($rootPath, "Create source-preserving Windows-image workspace for index $ImageIndex")) { return $workspace }
    $created = $false
    try {
        # No Force: an existing/racing destination is never adopted or removed.
        $null = New-Item -ItemType Directory -Path $rootPath -ErrorAction Stop
        $created = $true
        $null = New-Item -ItemType Directory -Path (Join-Path $rootPath 'images') -ErrorAction Stop
        $null = New-Item -ItemType Directory -Path $workspace.MountPath -ErrorAction Stop
        if ($exportEsd) {
            $result = Invoke-PhoenixExternalTool -FilePath $DismPath -ArgumentList @(
                '/English', '/Export-Image', "/SourceImageFile:$($sourceImage.FullName)",
                "/SourceIndex:$ImageIndex", "/DestinationImageFile:$($workspace.WorkingImagePath)",
                '/Compress:max', '/CheckIntegrity'
            )
            if ($result.ExitCode -ne 0) { throw "ESD export failed with exit code $($result.ExitCode)." }
        }
        else {
            Copy-Item -LiteralPath $sourceImage.FullName -Destination $workspace.WorkingImagePath -ErrorAction Stop
            (Get-Item -LiteralPath $workspace.WorkingImagePath).IsReadOnly = $false
        }
        $workspace.WorkingImageSha256 = (Get-FileHash -LiteralPath $workspace.WorkingImagePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ((Get-FileHash -LiteralPath $sourceImage.FullName -Algorithm SHA256).Hash -ine $workspace.SourceImageSha256 -or
            (-not $exportEsd -and $workspace.WorkingImageSha256 -cne $workspace.SourceImageSha256)) {
            throw 'Source or copied image changed during staging.'
        }
        Assert-PhoenixWindowsImageMetadata -Path $workspace.WorkingImagePath -Index $workspace.ImageIndex
        $workspace.SetState('Ready')
        $workspace.AddOperation('Staged and verified source-preserving working WIM.')
        [pscustomobject]@{
            Schema = 'PhoenixWindowsImageWorkspaceOwnership'; SchemaVersion = '1.0'; WorkspaceId = $workspace.WorkspaceId
        } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $rootPath '.phoenix-windows-image-workspace') -Encoding utf8 -ErrorAction Stop
        Save-PhoenixWindowsImageWorkspaceMetadata -Workspace $workspace
        return $workspace
    }
    catch {
        if ($created) {
            Test-PhoenixRegularDirectoryTree -Path $rootPath
            Remove-Item -LiteralPath $rootPath -Recurse -Force -ErrorAction Stop
        }
        throw
    }
}
