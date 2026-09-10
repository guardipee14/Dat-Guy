using module '..\Classes\Phoenix.Classes.psm1'

function Mount-PhoenixWindowsImage {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PhoenixWindowsImageWorkspace])]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$WorkspacePath,
        [switch]$ReadOnly,
        [string]$DismPath = ''
    )
    $info = Get-PhoenixWindowsImageWorkspaceOwnedInfo -Path $WorkspacePath
    if (-not (Test-PhoenixAdministrator)) { throw 'Administrator privileges are required to mount Windows images.' }
    $dism = Resolve-PhoenixDismPath -Path $DismPath
    if ($info.Workspace.State -ne 'Ready') { throw 'Windows-image workspace must be Ready before mounting.' }
    Assert-PhoenixWindowsImageMount -Workspace $info.Workspace -Absent
    if (-not $PSCmdlet.ShouldProcess($info.Workspace.MountPath, "Mount Windows image index $($info.Workspace.ImageIndex)")) { return $info.Workspace }
    $mountReadOnly = [bool]$ReadOnly
    return Invoke-PhoenixWindowsImageWorkspaceLock -WorkspacePath $info.RootPath -Action {
        $info = Get-PhoenixWindowsImageWorkspaceOwnedInfo -Path $WorkspacePath
        if ($info.Workspace.State -ne 'Ready') { throw 'Windows-image workspace state changed before mounting.' }
        Assert-PhoenixWindowsImageMount -Workspace $info.Workspace -Absent
        if (@(Get-ChildItem -LiteralPath $info.Workspace.MountPath -Force).Count) { throw 'Mount directory is not empty.' }
        if ((Get-FileHash -LiteralPath $info.Workspace.WorkingImagePath -Algorithm SHA256).Hash -ine $info.Workspace.WorkingImageSha256) {
            throw 'Working image hash changed since staging or dismount.'
        }
        Assert-PhoenixWindowsImageMetadata -Path $info.Workspace.WorkingImagePath -Index $info.Workspace.ImageIndex
        $info.Workspace.ReadOnly = $mountReadOnly
        # Persist intent before DISM. A crash leaves Failed, never an apparently safe Ready workspace.
        $info.Workspace.SetState('Failed')
        $info.Workspace.AddOperation('Mount intent recorded; live identity required for recovery.')
        Save-PhoenixWindowsImageWorkspaceMetadata -Workspace $info.Workspace
        $arguments = @('/English', '/Mount-Image', "/ImageFile:$($info.Workspace.WorkingImagePath)",
            "/Index:$($info.Workspace.ImageIndex)", "/MountDir:$($info.Workspace.MountPath)", '/CheckIntegrity')
        if ($mountReadOnly) { $arguments += '/ReadOnly' }
        $result = Invoke-PhoenixExternalTool -FilePath $dism -ArgumentList $arguments
        if ($result.ExitCode -ne 0) { throw "DISM mount failed with exit code $($result.ExitCode); workspace retained for inspection." }
        Assert-PhoenixWindowsImageMount -Workspace $info.Workspace
        $info.Workspace.SetState('Mounted')
        $info.Workspace.AddOperation("Mounted image index $($info.Workspace.ImageIndex).")
        Save-PhoenixWindowsImageWorkspaceMetadata -Workspace $info.Workspace
        return $info.Workspace
    }
}
