using module '..\Classes\Phoenix.Classes.psm1'

function Remove-PhoenixWindowsImageWorkspace {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path)
    $info = Get-PhoenixWindowsImageWorkspaceOwnedInfo -Path $Path
    if ($info.Workspace.State -in @('Mounted', 'Servicing')) { throw 'A mounted or servicing Windows-image workspace cannot be removed.' }
    Assert-PhoenixWindowsImageMount -Workspace $info.Workspace -Absent
    if (-not $PSCmdlet.ShouldProcess($info.RootPath, "Remove Phoenix Windows-image workspace '$($info.Workspace.WorkspaceId)'")) { return }
    $rootPath = $info.RootPath
    Invoke-PhoenixWindowsImageWorkspaceLock -WorkspacePath $rootPath -Action {
        $info = Get-PhoenixWindowsImageWorkspaceOwnedInfo -Path $rootPath
        if ($info.Workspace.State -in @('Mounted', 'Servicing')) { throw 'Workspace became mounted before cleanup.' }
        Assert-PhoenixWindowsImageMount -Workspace $info.Workspace -Absent
        Test-PhoenixRegularDirectoryTree -Path $rootPath
        # Remove ownership first while locked: another operation cannot adopt a partially removed workspace.
        Remove-Item -LiteralPath $info.MarkerPath -Force -ErrorAction Stop
        foreach ($child in @(Get-ChildItem -LiteralPath $rootPath -Force | Where-Object { $_.Name -ne '.phoenix-image.lock' })) {
            Remove-Item -LiteralPath $child.FullName -Recurse -Force -ErrorAction Stop
        }
    }
    Remove-Item -LiteralPath (Join-Path $rootPath '.phoenix-image.lock') -Force -ErrorAction Stop
    # Nonrecursive: unexpected new content is retained, never swept up.
    [IO.Directory]::Delete($rootPath, $false)
}
