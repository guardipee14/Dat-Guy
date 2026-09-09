using module '..\Classes\Phoenix.Classes.psm1'

function New-PhoenixWinPEWorkspace {

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PhoenixWinPEWorkspace])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter()]
        [AllowEmptyString()]
        [string]$MediaSourcePath = '',

        [Parameter()]
        [AllowEmptyString()]
        [string]$SourceWimPath = '',

        [Parameter()]
        [AllowNull()]
        [PhoenixDeploymentReadiness]$Prerequisite
    )

    if ($null -eq $Prerequisite) {
        $Prerequisite = Get-PhoenixDeploymentPrerequisite
    }

    if ([string]::IsNullOrWhiteSpace($MediaSourcePath)) {
        $mediaStatus = @($Prerequisite.Tools | Where-Object Name -eq 'WinPE media root') | Select-Object -First 1
        $MediaSourcePath = [string]$mediaStatus.Path
    }

    if ([string]::IsNullOrWhiteSpace($SourceWimPath)) {
        $wimStatus = @($Prerequisite.Tools | Where-Object Name -eq 'WinPE base image') | Select-Object -First 1
        $SourceWimPath = [string]$wimStatus.Path
    }

    Test-PhoenixRegularDirectoryTree -Path $MediaSourcePath
    [IO.FileInfo]$sourceWim = Get-Item -LiteralPath $SourceWimPath -Force -ErrorAction Stop

    if ($sourceWim -isnot [IO.FileInfo] -or ($sourceWim.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "WinPE source WIM must be a regular file: $SourceWimPath"
    }

    [string]$rootPath = [IO.Path]::GetFullPath($Path)

    if (Test-Path -LiteralPath $rootPath) {
        throw "WinPE workspace destination already exists: $rootPath"
    }

    $workspace = New-Object -TypeName PhoenixWinPEWorkspace
    $workspace.RootPath = $rootPath
    $workspace.SourceWimPath = $sourceWim.FullName
    $workspace.SourceWimSha256 = (Get-FileHash -LiteralPath $sourceWim.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $workspace.MediaSourcePath = (Resolve-Path -LiteralPath $MediaSourcePath).Path
    $workspace.MediaPath = Join-Path $rootPath 'media'
    $workspace.MountPath = Join-Path $rootPath 'mount'
    $workspace.SetState('Staging')

    if (-not $PSCmdlet.ShouldProcess($rootPath, 'Create transactional Phoenix WinPE workspace')) {
        return $workspace
    }

    try {
        $null = New-Item -ItemType Directory -Path $workspace.MediaPath -Force -ErrorAction Stop
        $null = New-Item -ItemType Directory -Path $workspace.MountPath -Force -ErrorAction Stop

        foreach ($child in @(Get-ChildItem -LiteralPath $workspace.MediaSourcePath -Force -ErrorAction Stop)) {
            Copy-Item -LiteralPath $child.FullName -Destination $workspace.MediaPath -Recurse -Force -ErrorAction Stop
        }

        [string]$sourcesPath = Join-Path $workspace.MediaPath 'sources'
        $null = New-Item -ItemType Directory -Path $sourcesPath -Force -ErrorAction Stop
        Copy-Item -LiteralPath $sourceWim.FullName -Destination (Join-Path $sourcesPath 'boot.wim') -Force -ErrorAction Stop

        $workspace.SetState('Ready')

        [string]$marker = [pscustomobject]@{
            Schema = 'PhoenixWinPEWorkspaceOwnership'
            SchemaVersion = '1.0'
            WorkspaceId = $workspace.WorkspaceId
        } | ConvertTo-Json

        [IO.File]::WriteAllText((Join-Path $rootPath '.phoenix-winpe-workspace'), $marker, [Text.UTF8Encoding]::new($false))
        Save-PhoenixWinPEWorkspaceMetadata -Workspace $workspace

        return $workspace
    }
    catch {
        Remove-Item -LiteralPath $rootPath -Recurse -Force -ErrorAction SilentlyContinue
        throw
    }
}
