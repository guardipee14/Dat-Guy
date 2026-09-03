using module '..\Classes\Phoenix.Classes.psm1'

function Remove-PhoenixOfflineBundle {

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    process {
        $bundle = Get-PhoenixOfflineBundleOwnedInfo -Path $Path

        if (
            $PSCmdlet.ShouldProcess(
                $bundle.RootPath,
                "Remove Phoenix offline bundle '$($bundle.Manifest.BundleId)'"
            )
        ) {
            Remove-Item -LiteralPath $bundle.RootPath -Recurse -Force -ErrorAction Stop
        }
    }
}
