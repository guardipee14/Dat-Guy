using module '..\Classes\Phoenix.Classes.psm1'

function New-PhoenixOfflineBundle {

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PhoenixOfflineBundleManifest])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
        [AllowEmptyString()]
        [string]$Description = '',

        [Parameter()]
        [AllowEmptyCollection()]
        [string[]]$InputFile = @()
    )

    [string]$rootPath = [IO.Path]::GetFullPath($Path)
    [bool]$rootExisted = Test-Path -LiteralPath $rootPath

    if ($rootExisted) {
        $rootItem = Get-Item -LiteralPath $rootPath -Force -ErrorAction Stop

        if ($rootItem -isnot [IO.DirectoryInfo]) {
            throw "Offline-bundle destination is not a directory: $rootPath"
        }

        if (($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Offline-bundle destination cannot be a reparse point: $rootPath"
        }

        if (@(Get-ChildItem -LiteralPath $rootPath -Force).Count -gt 0) {
            throw "Offline-bundle destination must be empty: $rootPath"
        }
    }

    $sourceFiles = foreach ($sourcePath in @($InputFile)) {
        [IO.FileInfo]$sourceItem =
            Get-Item -LiteralPath $sourcePath -Force -ErrorAction Stop

        if ($sourceItem -isnot [IO.FileInfo]) {
            throw "Offline-bundle input is not a file: $sourcePath"
        }

        if (($sourceItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Offline-bundle inputs cannot be reparse points: $($sourceItem.FullName)"
        }

        $sourceItem
    }

    $manifest =
        New-Object `
            -TypeName PhoenixOfflineBundleManifest
    $manifest.Name = $Name.Trim()
    $manifest.Description = $Description.Trim()
    $manifest.Phoenix = [pscustomobject]@{
        Version = (Import-PowerShellDataFile (Join-Path $PSScriptRoot '..\Phoenix.psd1')).ModuleVersion.ToString()
    }

    if (-not $PSCmdlet.ShouldProcess($rootPath, "Build Phoenix offline bundle '$Name'")) {
        foreach ($sourceFile in $sourceFiles) {
            $manifest.AddObject((Get-PhoenixContentObjectFromFile -LiteralPath $sourceFile.FullName))
        }

        return $manifest
    }

    try {
        $null = New-Item -ItemType Directory -Path $rootPath -Force -ErrorAction Stop

        foreach ($sourceFile in $sourceFiles) {
            $contentObject =
                Add-PhoenixContentStoreObject `
                    -StoreRoot $rootPath `
                    -LiteralPath $sourceFile.FullName `
                    -Confirm:$false

            $manifest.AddObject($contentObject)
            $manifest.Provenance = @(
                $manifest.Provenance
                ConvertTo-PhoenixOfflineBundleProvenanceRecord -LiteralPath $sourceFile.FullName -ContentObject $contentObject
            )
        }

        [string]$markerPath = Join-Path $rootPath '.phoenix-offline-bundle'
        [string]$markerJson = [pscustomobject]@{
            Schema = 'PhoenixOfflineBundleOwnership'
            SchemaVersion = '1.0'
            BundleId = $manifest.BundleId
            CreatedAtUtc = [datetime]::UtcNow
        } | ConvertTo-Json

        [IO.File]::WriteAllText($markerPath, $markerJson, [Text.UTF8Encoding]::new($false))

        Save-PhoenixOfflineBundleManifest `
            -Manifest $manifest `
            -LiteralPath (Join-Path $rootPath 'manifest.json') `
            -Confirm:$false |
            Out-Null

        $verification = Test-PhoenixOfflineBundle -Path $rootPath

        if (-not $verification.Success) {
            throw ('The new bundle failed integrity verification: ' + ($verification.Errors -join '; '))
        }

        return $manifest
    }
    catch {
        if (-not $rootExisted -and (Test-Path -LiteralPath $rootPath)) {
            Remove-Item -LiteralPath $rootPath -Recurse -Force -ErrorAction SilentlyContinue
        }

        throw
    }
}
