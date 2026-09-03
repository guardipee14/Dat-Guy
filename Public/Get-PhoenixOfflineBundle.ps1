using module '..\Classes\Phoenix.Classes.psm1'

function Get-PhoenixOfflineBundle {

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter()]
        [switch]$IncludeManifest
    )

    process {
        $bundle = Get-PhoenixOfflineBundleOwnedInfo -Path $Path
        $verification = Test-PhoenixOfflineBundle -Path $bundle.RootPath

        return [pscustomobject]@{
            Path = $bundle.RootPath
            BundleId = $bundle.Manifest.BundleId
            Name = $bundle.Manifest.Name
            Description = $bundle.Manifest.Description
            UpdatedAtUtc = $bundle.Manifest.UpdatedAtUtc
            ObjectCount = $bundle.Manifest.ObjectCount
            TotalBytes = $bundle.Manifest.TotalBytes
            IntegrityValid = $verification.IntegrityValid
            Warnings = @($verification.Warnings)
            Manifest = if ($IncludeManifest) { $bundle.Manifest } else { $null }
        }
    }
}
