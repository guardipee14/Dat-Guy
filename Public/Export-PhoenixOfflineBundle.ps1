using module '..\Classes\Phoenix.Classes.psm1'

function Export-PhoenixOfflineBundle {

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationPath
    )

    $bundle = Get-PhoenixOfflineBundleOwnedInfo -Path $Path
    $verification = Test-PhoenixOfflineBundle -Path $bundle.RootPath

    if (-not $verification.Success) {
        throw ('The source bundle failed integrity verification: ' + ($verification.Errors -join '; '))
    }

    [string]$destinationRoot = [IO.Path]::GetFullPath($DestinationPath)

    if (Test-Path -LiteralPath $destinationRoot) {
        $destinationItem = Get-Item -LiteralPath $destinationRoot -Force -ErrorAction Stop

        if ($destinationItem -isnot [IO.DirectoryInfo] -or ($destinationItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Offline-bundle export destination must be a regular directory: $destinationRoot"
        }

        if (@(Get-ChildItem -LiteralPath $destinationRoot -Force).Count -gt 0) {
            throw "Offline-bundle export destination must be empty: $destinationRoot"
        }
    }

    if (-not $PSCmdlet.ShouldProcess($destinationRoot, "Export verified Phoenix offline bundle '$($bundle.Manifest.BundleId)'")) {
        return $destinationRoot
    }

    $null = New-Item -ItemType Directory -Path $destinationRoot -Force -ErrorAction Stop

    try {
        foreach ($contentObject in $bundle.Manifest.Objects) {
            $address = [PhoenixContentAddress]::new($contentObject.Digest)
            $sourceObjectPath = Resolve-PhoenixContentStoreObjectPath -StoreRoot $bundle.RootPath -Address $address
            $destinationObjectPath = Resolve-PhoenixContentStoreObjectPath -StoreRoot $destinationRoot -Address $address
            $null = New-Item -ItemType Directory -Path (Split-Path -Path $destinationObjectPath -Parent) -Force -ErrorAction Stop
            Copy-Item -LiteralPath $sourceObjectPath -Destination $destinationObjectPath -Force -ErrorAction Stop
        }

        Copy-Item -LiteralPath $bundle.ManifestPath -Destination (Join-Path $destinationRoot 'manifest.json') -Force -ErrorAction Stop
        Copy-Item -LiteralPath $bundle.MarkerPath -Destination (Join-Path $destinationRoot '.phoenix-offline-bundle') -Force -ErrorAction Stop

        $destinationVerification = Test-PhoenixOfflineBundle -Path $destinationRoot

        if (-not $destinationVerification.Success) {
            throw ('The exported bundle failed verification: ' + ($destinationVerification.Errors -join '; '))
        }

        return $destinationRoot
    }
    catch {
        Remove-Item -LiteralPath $destinationRoot -Recurse -Force -ErrorAction SilentlyContinue
        throw
    }
}
