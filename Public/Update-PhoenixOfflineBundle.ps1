using module '..\Classes\Phoenix.Classes.psm1'

function Update-PhoenixOfflineBundle {

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PhoenixOfflineBundleManifest])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$InputFile
    )

    $bundle = Get-PhoenixOfflineBundleOwnedInfo -Path $Path
    $manifest = $bundle.Manifest

    foreach ($sourcePath in $InputFile) {
        [IO.FileInfo]$sourceFile = Get-Item -LiteralPath $sourcePath -Force -ErrorAction Stop

        if ($sourceFile -isnot [IO.FileInfo] -or ($sourceFile.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Offline-bundle input must be a regular file: $sourcePath"
        }

        $prospectiveObject = Get-PhoenixContentObjectFromFile -LiteralPath $sourceFile.FullName

        if ($manifest.ContainsObject($prospectiveObject.ObjectId)) {
            continue
        }

        if (-not $PSCmdlet.ShouldProcess($bundle.RootPath, "Add '$($sourceFile.Name)' to Phoenix offline bundle")) {
            $manifest.AddObject($prospectiveObject)
            continue
        }

        $contentObject = Add-PhoenixContentStoreObject -StoreRoot $bundle.RootPath -LiteralPath $sourceFile.FullName -Confirm:$false
        $manifest.AddObject($contentObject)
        $manifest.Provenance = @(
            $manifest.Provenance
            ConvertTo-PhoenixOfflineBundleProvenanceRecord -LiteralPath $sourceFile.FullName -ContentObject $contentObject
        )
    }

    if ($PSCmdlet.ShouldProcess($bundle.ManifestPath, 'Publish updated Phoenix offline-bundle manifest')) {
        Save-PhoenixOfflineBundleManifest -Manifest $manifest -LiteralPath $bundle.ManifestPath -Confirm:$false | Out-Null

        $verification = Test-PhoenixOfflineBundle -Path $bundle.RootPath

        if (-not $verification.Success) {
            throw ('The updated bundle failed integrity verification: ' + ($verification.Errors -join '; '))
        }
    }

    return $manifest
}
