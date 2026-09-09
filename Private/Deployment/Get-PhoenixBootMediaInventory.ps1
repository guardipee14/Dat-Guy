function Get-PhoenixBootMediaInventory {
    [CmdletBinding()]
    [OutputType([object[]])]
    param([Parameter(Mandatory)][string]$MediaPath)
    Test-PhoenixRegularDirectoryTree -Path $MediaPath
    $root = (Get-Item -LiteralPath $MediaPath -Force -ErrorAction Stop).FullName
    foreach ($required in @('sources\boot.wim', 'efi\boot\bootx64.efi')) {
        if (-not (Test-Path -LiteralPath (Join-Path $root $required) -PathType Leaf)) {
            throw "Missing required boot media file: $required"
        }
    }
    foreach ($file in @(Get-ChildItem -LiteralPath $root -Recurse -File -Force -ErrorAction Stop | Sort-Object FullName)) {
        [pscustomobject]@{
            RelativePath = [IO.Path]::GetRelativePath($root, $file.FullName)
            Length = $file.Length
            Sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
        }
    }
}
