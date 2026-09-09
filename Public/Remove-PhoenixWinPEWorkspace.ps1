using module '..\Classes\Phoenix.Classes.psm1'

function Remove-PhoenixWinPEWorkspace {

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    process {
        $info = Get-PhoenixWinPEWorkspaceOwnedInfo -Path $Path

        if ($info.Workspace.State -eq 'Mounted') {
            throw 'A mounted WinPE workspace cannot be removed. Dismount it first.'
        }

        Test-PhoenixRegularDirectoryTree -Path $info.RootPath

        if ($PSCmdlet.ShouldProcess($info.RootPath, "Remove Phoenix WinPE workspace '$($info.Workspace.WorkspaceId)'")) {
            Remove-Item -LiteralPath $info.RootPath -Recurse -Force -ErrorAction Stop
        }
    }
}
