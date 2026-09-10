function Resolve-PhoenixDismPath {
    [CmdletBinding()]
    param([string]$Path = '')
    if ([string]::IsNullOrWhiteSpace($Path)) {
        $readiness = Get-PhoenixDeploymentPrerequisite
        $tool = @($readiness.Tools | Where-Object { $_.Name -eq 'ADK DISM' -and $_.Available })
        if ($tool.Count -ne 1) { throw 'An installed x64 ADK DISM is required.' }
        $Path = $tool[0].Path
    }
    Test-PhoenixPathAncestors -Path $Path
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if ($item -isnot [IO.FileInfo] -or $item.Extension -ine '.exe') { throw 'DISM must be a regular executable.' }
    return $item.FullName
}

function Assert-PhoenixWindowsImageMount {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][PhoenixWindowsImageWorkspace]$Workspace,
        [switch]$Absent
    )
    # Query the servicing registry, not just our metadata. Failure is not "no mounts".
    $mounts = @(Get-WindowsImage -Mounted -ErrorAction Stop)
    $related = @($mounts | Where-Object {
        [IO.Path]::GetFullPath($_.Path).TrimEnd('\') -ieq $Workspace.MountPath.TrimEnd('\') -or
        [IO.Path]::GetFullPath($_.ImagePath) -ieq $Workspace.WorkingImagePath
    })
    if ($Absent) {
        if ($related.Count) { throw 'A live or abandoned DISM mount still references this workspace.' }
        return
    }
    if ($related.Count -ne 1) { throw 'Exactly one matching Windows mount is required.' }
    $mounted = $related[0]
    $expectedMode = if ($Workspace.ReadOnly) { 'ReadOnly' } else { 'ReadWrite' }
    if ([IO.Path]::GetFullPath($mounted.Path).TrimEnd('\') -ine $Workspace.MountPath.TrimEnd('\') -or
        [IO.Path]::GetFullPath($mounted.ImagePath) -ine $Workspace.WorkingImagePath -or
        [int]$mounted.ImageIndex -ne $Workspace.ImageIndex -or
        [string]$mounted.MountMode -ine $expectedMode -or
        [string]$mounted.MountStatus -ine 'Ok') {
        throw 'Live mount image, index, mode, path, or health differs from the owned workspace.'
    }
}

function Assert-PhoenixWindowsImageMetadata {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][int]$Index)
    $images = @(Get-WindowsImage -ImagePath $Path -Index $Index -ErrorAction Stop)
    if ($images.Count -ne 1 -or [int]$images[0].ImageIndex -ne $Index -or
        [string]$images[0].Architecture -notin @('9', 'x64', 'amd64')) {
        throw 'An explicit valid x64 image index is required.'
    }
}
