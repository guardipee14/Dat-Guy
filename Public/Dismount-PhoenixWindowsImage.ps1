using module '..\Classes\Phoenix.Classes.psm1'

function Dismount-PhoenixWindowsImage {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([PhoenixWindowsImageWorkspace])]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$WorkspacePath,
        [Parameter(Mandatory)][ValidateSet('Commit', 'Discard')][string]$Mode,
        [string]$DismPath = ''
    )
    $info = Get-PhoenixWindowsImageWorkspaceOwnedInfo -Path $WorkspacePath
    if (-not (Test-PhoenixAdministrator)) { throw 'Administrator privileges are required to dismount Windows images.' }
    $dism = Resolve-PhoenixDismPath -Path $DismPath
    if ($info.Workspace.State -notin @('Mounted', 'Servicing', 'Failed')) { throw 'Windows-image workspace is not mounted.' }
    if ($info.Workspace.ReadOnly -and $Mode -eq 'Commit') { throw 'A read-only image mount cannot be committed.' }
    Assert-PhoenixWindowsImageMount -Workspace $info.Workspace
    if (-not $PSCmdlet.ShouldProcess($info.Workspace.MountPath, "$Mode Phoenix-owned Windows image mount")) { return $info.Workspace }
    return Invoke-PhoenixWindowsImageWorkspaceLock -WorkspacePath $info.RootPath -Action {
        $info = Get-PhoenixWindowsImageWorkspaceOwnedInfo -Path $WorkspacePath
        if ($info.Workspace.State -notin @('Mounted', 'Servicing', 'Failed')) { throw 'Mount state changed before dismount.' }
        if ($info.Workspace.ReadOnly -and $Mode -eq 'Commit') { throw 'A read-only image mount cannot be committed.' }
        if ($info.Workspace.State -eq 'Failed' -and $Mode -eq 'Commit') { throw 'Failed transactions must be inspected and discarded, not committed.' }
        Assert-PhoenixWindowsImageMount -Workspace $info.Workspace
        $info.Workspace.SetState('Failed')
        $info.Workspace.AddOperation("Dismount $Mode intent recorded.")
        Save-PhoenixWindowsImageWorkspaceMetadata -Workspace $info.Workspace
        $result = Invoke-PhoenixExternalTool -FilePath $dism -ArgumentList @('/English', '/Unmount-Image', "/MountDir:$($info.Workspace.MountPath)", "/$Mode")
        if ($result.ExitCode -ne 0) { throw "DISM dismount failed with exit code $($result.ExitCode); workspace retained." }
        Assert-PhoenixWindowsImageMount -Workspace $info.Workspace -Absent
        Assert-PhoenixWindowsImageMetadata -Path $info.Workspace.WorkingImagePath -Index $info.Workspace.ImageIndex
        $info.Workspace.WorkingImageSha256 = (Get-FileHash -LiteralPath $info.Workspace.WorkingImagePath -Algorithm SHA256).Hash.ToLowerInvariant()
        $info.Workspace.ReadOnly = $false
        $info.Workspace.SetState('Ready')
        $info.Workspace.AddOperation("Dismounted image using $Mode.")
        Save-PhoenixWindowsImageWorkspaceMetadata -Workspace $info.Workspace
        return $info.Workspace
    }
}
